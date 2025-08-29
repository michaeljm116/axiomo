package main

import "core:fmt"
import "core:mem"
import "core:math"
import "core:time"
import "core:math/linalg"
import vmem "core:mem/virtual"

import "vendor:glfw"
import b2"vendor:box2d"

curr_phase : u8 = 0
distance_arena: [2]vmem.Arena
distance_arena_data: [2][]byte
distance_arena_alloc: [2]mem.Allocator

set_up_arenas :: proc()
{
    for i in 0..<2{
        //distance_arena_data[i] = make([]byte, mem.Megabyte, context.allocator)
        //mem.arena_init(&distance_arena[i], distance_arena_data[i])
        arena_err := vmem.arena_init_growing(&distance_arena[i], mem.Megabyte,)
        assert(arena_err == nil)
        distance_arena_alloc[i] = vmem.arena_allocator(&distance_arena[i])
    }
}

destroy_arenas :: proc()
{
    for i in 0..<2{
        delete(distance_arena_data[i])
        vmem.arena_free_all(&distance_arena[i])
    }
}

// Input state tracking
InputState :: struct {
    keys_pressed: [glfw.KEY_LAST + 1]bool,
    keys_just_pressed: [glfw.KEY_LAST + 1]bool,
    keys_just_released: [glfw.KEY_LAST + 1]bool,

    mouse_x, mouse_y: f64,
    last_mouse_x, last_mouse_y: f64,
    mouse_delta_x, mouse_delta_y: f64,
    first_mouse: bool,

    mouse_buttons: [glfw.MOUSE_BUTTON_LAST + 1]bool,
    mouse_sensitivity: f32,

    // Camera control settings
    movement_speed: f32,
    rotation_speed: f32,
}

// Global input state
g_input: InputState
g_camera_entity: Entity = 0
g_light_entity: Entity = 0

// Orbit parameters (world units / radians)
g_light_orbit_radius: f32 = 5.0
g_light_orbit_speed: f32 = 0.25   // radians per second
g_light_orbit_angle: f32 = 15.0

g_floor : [2]Entity
g_objects : [2][dynamic]Entity

// Initialize the gameplay system
gameplay_init :: proc() {
    set_up_arenas()
    g_input = InputState{
        mouse_sensitivity = 0.1,
        movement_speed = 5.0,
        rotation_speed = 20.0,
        first_mouse = true,
    }

    // Set up GLFW callbacks
    glfw.SetKeyCallback(rb.window, key_callback)
    glfw.SetCursorPosCallback(rb.window, mouse_callback)
    glfw.SetMouseButtonCallback(rb.window, mouse_button_callback)

    // Capture mouse cursor
    glfw.SetInputMode(rb.window, glfw.CURSOR, glfw.CURSOR_DISABLED)

    // Find the camera entity
    find_camera_entity()
    find_light_entity()
    find_player_entity()
    face_left(g_player)
    setup_physics()
}

// Find the camera entity in the scene
find_camera_entity :: proc() {
    camera_archetypes := query(has(Cmp_Camera), has(Cmp_Transform), has(Cmp_Node))

    for archetype in camera_archetypes {
        entities := archetype.entities
        if len(entities) > 0 {
            g_camera_entity = entities[0]
            ct := get_component(g_camera_entity, Cmp_Transform)
            return
        }
    }

    fmt.println("Warning: No camera entity found!")
}

// Update input state and camera
gameplay_update :: proc(delta_time: f32) {
    if g_camera_entity == 0 {
        find_camera_entity()
        return
    }
    if g_player == 0 {
        find_player_entity()
    }

    // Clear just pressed/released states
    for i in 0..<len(g_input.keys_just_pressed) {
        g_input.keys_just_pressed[i] = false
        g_input.keys_just_released[i] = false
    }

    // Update light orbit (if a light entity was found)
    update_light_orbit(delta_time)

    //update_camera_movement(delta_time)
    //update_player_movement(delta_time)
    update_movables(delta_time)
    update_physics(delta_time)
}

find_player_entity :: proc() {
    player_archetypes := query(has(Cmp_Transform), has(Cmp_Node), has(Cmp_Root))

    for archetype in player_archetypes {
        nodes := get_table(archetype, Cmp_Node)
        for node, i in nodes {
            if node.name == "Froku" {
                g_player = archetype.entities[i]
                fmt.println("Found Player")
                return
            }
        }
    }
}

find_floor_entities :: proc() {
    arcs := query(has(Cmp_Transform), has(Cmp_Node), has(Cmp_Root))
    for archetype in arcs {
        nodes := get_table(archetype, Cmp_Node)
        for node, i in nodes {
            if node.name == "Floor1" do g_floor[0] = archetype.entities[i]
            if node.name == "Floor2" do g_floor[1] = archetype.entities[i]
        }
    }
}



// Find the first light entity in the scene and cache it for orbit updates.
// Looks for entities with Light, Transform, and Node components.
find_light_entity :: proc() {
    light_archetypes := query(has(Cmp_Light), has(Cmp_Transform), has(Cmp_Node))

    for archetype in light_archetypes {
       for entity in archetype.entities{
           fmt.println("Light found")
           g_light_entity = entity
           return
       }
    }

    // No light found -> leave g_light_entity as 0
}

// Update the cached light entity so it orbits around a center point.
// If a player exists, orbit around the player's world position; otherwise use world origin.
update_light_orbit :: proc(delta_time: f32) {
    if g_light_entity == 0 {
        return
    }

    lc := get_component(g_light_entity, Cmp_Light)
    tc := get_component(g_light_entity, Cmp_Transform)
    if tc == nil || lc == nil {
        return
    }

    // Determine orbit center: prefer player position if available
    center := vec3{0.0, 1.5, 0.0}
    if g_player != 0 {
        pc := get_component(g_player, Cmp_Transform)
        if pc != nil {
            center = pc.local.pos.xyz
        }
    }

    // Advance angle
    g_light_orbit_angle += g_light_orbit_speed * delta_time

    // Compute new local position on XZ plane; keep Y relative to center
    new_x := center.x + math.cos(g_light_orbit_angle) * g_light_orbit_radius
    new_z := center.z + math.sin(g_light_orbit_angle) * g_light_orbit_radius
    new_y := center.y + 1.5 // offset above center (tweak as desired)

    // Update transform local position so the transform system will update world matrix
    tc.local.pos.x = new_x
    tc.local.pos.z = new_z
    tc.local.pos.y = new_y

    rt.update_flags += {.LIGHT}
}

update_player_movement :: proc(delta_time: f32)
{
    tc := get_component(g_player, Cmp_Transform)
    if tc == nil do return

    move_speed :f32= .10
    if is_key_pressed(glfw.KEY_W) {
        tc.local.pos.z += move_speed
    }
    if is_key_pressed(glfw.KEY_S) {
        tc.local.pos.z -= move_speed
    }
    if is_key_pressed(glfw.KEY_A) {
        tc.local.pos.x -= move_speed
    }
    if is_key_pressed(glfw.KEY_D) {
        tc.local.pos.x += move_speed
    }
    // Verticaltc.local.pos.x
    if is_key_pressed(glfw.KEY_SPACE) {
        tc.local.pos.y += move_speed
    }
    if is_key_pressed(glfw.KEY_LEFT_SHIFT) {
        tc.local.pos.y -= move_speed
    }
}

face_left :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(90, {0,1,0})
}

face_right :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(-90, {0,1,0})
}

// Get camera forward vector
get_camera_forward :: proc(transform: ^Cmp_Transform) -> vec3 {
    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform.local.rot)
    return -vec3{rotation_matrix[0][2], rotation_matrix[1][2], rotation_matrix[2][2]}
}

// Get camera right vector
get_camera_right :: proc(transform: ^Cmp_Transform) -> vec3 {
    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform.local.rot)
    return vec3{rotation_matrix[0][0], rotation_matrix[1][0], rotation_matrix[2][0]}
}

// Input helper functions
is_key_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST {
        return false
    }
    return g_input.keys_pressed[key]
}

is_key_just_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST {
        return false
    }
    return g_input.keys_just_pressed[key]
}

is_key_just_released :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST {
        return false
    }
    return g_input.keys_just_released[key]
}

is_mouse_button_pressed :: proc(button: i32) -> bool {
    if button < 0 || button > glfw.MOUSE_BUTTON_LAST {
        return false
    }
    return g_input.mouse_buttons[button]
}

// GLFW Callbacks
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = rb.ctx

    if key < 0 || key > glfw.KEY_LAST {
        return
    }

    switch action {
    case glfw.PRESS:
        if !g_input.keys_pressed[key] {
            g_input.keys_just_pressed[key] = true
        }
        g_input.keys_pressed[key] = true

    case glfw.RELEASE:
        g_input.keys_just_released[key] = true
        g_input.keys_pressed[key] = false

    case glfw.REPEAT:
        // Keep key pressed state
    }

    // Handle special keys
    if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
        glfw.SetWindowShouldClose(window, true)
    }

    // Toggle mouse capture
    if key == glfw.KEY_TAB && action == glfw.PRESS {
        if glfw.GetInputMode(window, glfw.CURSOR) == glfw.CURSOR_DISABLED {
            glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
        } else {
            glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
            g_input.first_mouse = true
        }
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = rb.ctx

    if g_input.first_mouse {
        g_input.last_mouse_x = xpos
        g_input.last_mouse_y = ypos
        g_input.first_mouse = false
    }

    g_input.mouse_delta_x = xpos - g_input.last_mouse_x
    g_input.mouse_delta_y = ypos - g_input.last_mouse_y

    g_input.last_mouse_x = xpos
    g_input.last_mouse_y = ypos
    g_input.mouse_x = xpos
    g_input.mouse_y = ypos
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
    context = rb.ctx

    if button < 0 || button > glfw.MOUSE_BUTTON_LAST {
        return
    }

    switch action {
    case glfw.PRESS:
        g_input.mouse_buttons[button] = true

    case glfw.RELEASE:
        g_input.mouse_buttons[button] = false
    }
}

// Cleanup
gameplay_destroy :: proc() {
    // Reset callbacks
    glfw.SetKeyCallback(rb.window, nil)
    glfw.SetCursorPosCallback(rb.window, nil)
    glfw.SetMouseButtonCallback(rb.window, nil)

    // Release mouse cursor
    glfw.SetInputMode(rb.window, glfw.CURSOR, glfw.CURSOR_NORMAL)

    destroy_arenas()
}

//----------------------------------------------------------------------------\\
// /Physics System /ps
//----------------------------------------------------------------------------\\
MAX_DYANMIC_OBJECTS :: 1000
g_world_def := b2.DefaultWorldDef()
g_world_id : b2.WorldId
g_b2scale := f32(1)
g_debug_draw : b2.DebugDraw
g_debug_col := false
g_debug_stats := false

ContactDensities :: struct
{
    Player : f32,
    Vax : f32,
    Doctor : f32,
    Projectiles : f32,
    Wall : f32
}

g_contact_identifier := ContactDensities {
	Player      = 9.0,
	Vax         = 50.0,
	Doctor      = 200.0,
	Projectiles = 8.0,
	Wall        = 800.0
}

setup_physics :: proc (){
    fmt.println("Setting up phsyics")
    b2.SetLengthUnitsPerMeter(g_b2scale)
    g_world_id = b2.CreateWorld(g_world_def)
    b2.World_SetGravity(g_world_id, b2.Vec2{0,-9.8})
    //Set Player's body def
    {
        find_player_entity()
        pt := get_component(g_player, Cmp_Transform)

        // Build collision components. Body position is the body origin in world space.
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Capsule,
            flags = {.Player}
        }
        col.bodydef.fixedRotation = true
        col.bodydef.type = .kinematicBody
        col.bodydef.isEnabled = true
        // Place the body origin at the transform world position (pt.world[3] should be the object's world origin)
        col.bodydef.position = {pt.world[3].x, pt.world[3].y}
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

        // Define the capsule in body-local coordinates (centered on the body origin).
        // Use half extents from the transform scale. magic_scale_number still applied to y if needed.
        half_sca := b2.Vec2{pt.global.sca.x * 0.5, pt.global.sca.y}
        top := b2.Vec2{0.0,  half_sca.y}
        bottom := b2.Vec2{0.0, -half_sca.y}
        capsule := b2.Capsule{top, bottom, half_sca.x}

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Player})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Environment, .MovingFloor, .MovingEnvironment})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = g_contact_identifier.Player
        col.shapeid = b2.CreateCapsuleShape(col.bodyid, col.shapedef, capsule)
        add_component(g_player, col)
        //add_component(g_player, capsule)
    }

    fmt.println("Floor created")
    set_floor_entities()
    create_barrel({5, 2})
    create_barrel({3, 2})
}

set_floor_entities :: proc()
{
    //create static floor
    {
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Box
        }
        col.bodydef.fixedRotation = true
        col.bodydef.type = .staticBody
        col.bodydef.position = {0,-1.0}
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
        box := b2.MakeBox(500, .1)

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Player, .MovingEnvironment, .MovingFloor})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = 0
        col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    }

    find_floor_entities()
    for floor, i in g_floor{
        fc := get_component(floor, Cmp_Transform)
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Box,
            flags = {.Movable}
        }
        // move := Cmp_Movable{speed = -2.0}
        col.bodydef.fixedRotation = true
        col.bodydef.type = .dynamicBody
        col.bodydef.position = fc.world[3].xy
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
        box := b2.MakeBox(fc.local.sca.x, fc.local.sca.y)

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingFloor})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Environment, .Player, .MovingEnvironment})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = 1000.0
        col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

        add_component(floor, col)
    }
}

barrel : Entity
create_barrel :: proc(pos : b2.Vec2)
{
    fmt.println("Barrel creating")
    barrel = load_prefab("Barrel")
    fmt.println("Prefab loaded")
    bt := get_component(barrel, Cmp_Transform)
    if bt == nil do return

    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Box,
        flags = CollisionFlags{.Movable}
    }
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    col.bodydef.position = pos

    col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

    box := b2.MakeBox(bt.local.sca.x, bt.local.sca.y)
    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingEnvironment})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player, .Environment, .MovingFloor, .MovingEnvironment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = g_contact_identifier.Player
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    // movable := Cmp_Movable{-1.0}

    fmt.println("Movable component added")
    add_component(barrel, col)
    fmt.println("Collision component added")
    //add_component(barrel, movable)
}

update_movables :: proc(delta_time: f32)
{
    //First just the visible g_floor
    // for i in 0..<2{
    //     fc := get_component(g_floor[i], Cmp_Transform)
    //     fc.local.pos.x -= 1.0 * delta_time

    //     //refresh world if done
    //     if fc.local.pos.x <= -25.0 {
    //         for e in g_objects[curr_phase] do remove_entity(e)
    //         vmem.arena_free_all(&distance_arena[curr_phase])
    //         curr_phase = (curr_phase + 1) % 2
    //     }
    // }
    movables := query(has(Cmp_Collision2D))
    for movable in movables{
        cols := get_table(movable, Cmp_Collision2D)
        for e, i in movable.entities{
            if .Movable in cols[i].flags{
                nc := get_component(e, Cmp_Node)
                tc := get_component(e, Cmp_Transform)
                // fmt.println("movable, ", nc.name)
                // b2.Body_SetLinearVelocity(cols[i].bodyid, {delta_time * -1.0, 0})
                // b2.Body_ApplyLinearImpulse(cols[i].bodyid, {-2.0,0}, {0.5,0.5}, true)
                vel := b2.Body_GetLinearVelocity(cols[i].bodyid)
                vel.x = -1
                b2.Body_SetLinearVelocity(cols[i].bodyid, vel)
                // b2.Body_ApplyLinearImpulseToCenter(cols[i].bodyid, {-2.0,0}, true)
                //fmt.printfln("Entity")
            }
        }
    }
}

update_physics :: proc(delta_time: f32)
{
    update_player_movement_phys(delta_time)
    b2.World_Step(g_world_id, delta_time, 4)
    arcs := query(has(Cmp_Transform), has(Cmp_Collision2D))
    for arc in arcs{
        trans := get_table(arc,Cmp_Transform)
        colis := get_table(arc,Cmp_Collision2D)
        for _, i in arc.entities{
            trans[i].local.pos.xy = b2.Body_GetPosition(colis[i].bodyid)
            trans[i].local.pos.z = 1
        }
    }
}

update_player_movement_phys :: proc(delta_time: f32)
{
    cc := get_component(g_player, Cmp_Collision2D)
    if cc == nil do return
    vel := b2.Vec2{0,0}
    move_speed :f32= 5000.0
    if is_key_pressed(glfw.KEY_SPACE) {
        // vel.y += move_speed
        b2.Body_ApplyLinearImpulse(cc.bodyid, {0,move_speed},{0,0}, true)
        b2.Body_ApplyForce(cc.bodyid, {move_speed,move_speed},{0,0}, true)
        b2.Body_ApplyLinearImpulseToCenter(cc.bodyid, {0,move_speed}, true)
        fmt.println("Entity ", " | Force : ", b2.Body_GetLinearVelocity(cc.bodyid))
    }
}
