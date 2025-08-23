package main

import "core:fmt"
import "core:mem"
import "core:math"
import "core:time"
import "core:math/linalg"

import "vendor:glfw"
import b2"vendor:box2d"

curr_phase : u8 = 0
distance_arena: [2]mem.Arena
distance_arena_data: [2][]byte
distance_arena_alloc: [2]mem.Allocator

set_up_arenas :: proc()
{
    for i in 0..<2{
        distance_arena_data[i] = make([]byte, 1024 * 1024 * 1, context.allocator)
        mem.arena_init(&distance_arena[i], distance_arena_data[i])
    }
}

destroy_arenas :: proc()
{
    for i in 0..<2{
        delete(distance_arena_data[i])
        mem.arena_free_all(&distance_arena[i])
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
    update_camera_rotation(delta_time)
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

// Handle camera movement with WASD
update_camera_movement :: proc(delta_time: f32) {
    camera_transform := get_component(g_camera_entity, Cmp_Transform)
    camera_node := get_component(g_camera_entity, Cmp_Node)

    if camera_transform == nil || camera_node == nil {
        return
    }

    move_speed := g_input.movement_speed * delta_time

    // Get camera forward, right, and up vectors from current rotation
    forward := get_camera_forward(camera_transform)
    right := get_camera_right(camera_transform)
    up := vec3{0, 1, 0} // World up

    movement := vec3{0, 0, 0}

    // WASD movement
    if is_key_pressed(glfw.KEY_W) {
        movement += forward * move_speed
    }
    if is_key_pressed(glfw.KEY_S) {
        movement -= forward * move_speed
    }
    if is_key_pressed(glfw.KEY_A) {
        movement -= right * move_speed
    }
    if is_key_pressed(glfw.KEY_D) {
        movement += right * move_speed
    }

    // Vertical movement
    if is_key_pressed(glfw.KEY_SPACE) {
        movement += up * move_speed
    }
    if is_key_pressed(glfw.KEY_LEFT_SHIFT) {
        movement -= up * move_speed
    }

    // Apply movement
    if linalg.length(movement) > 0 {
        camera_transform.local.pos.xyz += movement
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

// Handle camera rotation with mouse
update_camera_rotation :: proc(delta_time: f32) {
    camera_transform := get_component(g_camera_entity, Cmp_Transform)

    if camera_transform == nil {
        return
    }

    // Apply mouse sensitivity (deltas are treated as degrees). Convert to radians for quaternion math.
    yaw_delta_deg := -f32(g_input.mouse_delta_x) * g_input.mouse_sensitivity * delta_time * g_input.rotation_speed
    pitch_delta_deg := -f32(g_input.mouse_delta_y) * g_input.mouse_sensitivity * delta_time * g_input.rotation_speed

    // Convert deltas to radians immediately
    yaw_r := math.to_radians(yaw_delta_deg)
    pitch_r := math.to_radians(pitch_delta_deg)

    // Extract current pitch from the current orientation quaternion (radians) and clamp the new pitch.
    q_curr := camera_transform.local.rot
    curr_pitch := linalg.pitch_from_quaternion_f32(q_curr) // returns radians
    min_pitch := math.to_radians(f32(-89.0))
    max_pitch := math.to_radians(f32(89.0))

    desired_pitch := math.clamp(curr_pitch + pitch_r, min_pitch, max_pitch)
    actual_pitch_delta := desired_pitch - curr_pitch

    // If nothing to apply, early out and reset deltas
    if yaw_r == 0.0 && actual_pitch_delta == 0.0 {
        g_input.mouse_delta_x = 0
        g_input.mouse_delta_y = 0
        return
    }

    // Use linalg helper to create a delta quaternion from pitch/yaw (pitch, yaw, roll).
    // We'll build a single delta quaternion and apply it to the current orientation.
    // Note: linalg.quaternion_from_pitch_yaw_roll expects angles in radians.
    //
    // We intentionally remove the custom axis-angle helper and rely on the linalg helper
    // for clearer, tested quaternion-from-euler behavior.
    //
    // (Actual delta quaternion will be constructed below where both pitch/yaw deltas are available.)

    quat_mul := proc(a: quat, b: quat) -> quat {
        r: quat
        r.w = a.w*b.w - a.x*b.x - a.y*b.y - a.z*b.z
        r.x = a.w*b.x + a.x*b.w + a.y*b.z - a.z*b.y
        r.y = a.w*b.y - a.x*b.z + a.y*b.w + a.z*b.x
        r.z = a.w*b.z + a.x*b.y - a.y*b.x + a.z*b.w
        return r
    }

    quat_normalize := proc(q: quat) -> quat {
        len := math.sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w)
        if len == 0.0 {
            r: quat
            r.x = 0.0
            r.y = 0.0
            r.z = 0.0
            r.w = 1.0
            return r
        }
        inv := 1.0 / len
        r: quat
        r.x = q.x * inv
        r.y = q.y * inv
        r.z = q.z * inv
        r.w = q.w * inv
        return r
    }

    // Build delta quaternion from pitch & yaw using linalg helper (pitch, yaw, roll).
    // We pass the pitch and yaw deltas (already converted to radians as pitch_r and yaw_r).
    q_delta := linalg.quaternion_from_pitch_yaw_roll_f32(pitch_r, yaw_r, 0.0)

    // Apply delta: q_new = q_delta * q_curr
    q_new := quat_mul(q_delta, q_curr)
    q_new = quat_normalize(q_new)

    camera_transform.local.rot = q_new

    // Reset mouse delta
    g_input.mouse_delta_x = 0
    g_input.mouse_delta_y = 0

    face_left(g_player)
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
    magic_scale_number :f32=1
    b2.World_SetGravity(g_world_id, b2.Vec2{0,-98 * magic_scale_number})
    find_floor_entities()
    //Set Player's body def
    {
        find_player_entity()
        pt := get_component(g_player, Cmp_Transform)
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Capsule
        }
        col.bodydef.fixedRotation = true
        col.bodydef.type = .dynamicBody
        col.bodydef.position = {pt.local.pos.x, pt.local.pos.y + 2}
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
        half_sca := b2.Vec2{pt.global.sca.x * 0.5, pt.global.sca.y * magic_scale_number}
        top := b2.Vec2{pt.world[3].x, 0}// pt.world[3].y + half_sca.y}
        bottom := b2.Vec2{pt.world[3].x,0}// pt.world[3].y - half_sca.y}
        capsule := b2.Capsule{top, bottom, half_sca.x}

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Player})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Environment})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = g_contact_identifier.Player
        col.shapeid = b2.CreateCapsuleShape(col.bodyid, col.shapedef, capsule)
        add_component(g_player, col)
        //add_component(g_player, capsule)
    }
    //create static floor
    {
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Box
        }
        col.bodydef.fixedRotation = true
        col.bodydef.type = .staticBody
        col.bodydef.position = {0,0}
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
        box := b2.MakeBox(1000, .1)
        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = 0
        col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    }

//    create_barrel({1, 2})
}

create_barrel :: proc(pos : b2.Vec2)
{
    barrel := load_prefab2("assets/prefabs/","Barrel", resource_alloc = arena_alloc, ecs_alloc = context.allocator)
    bt := get_component(barrel, Cmp_Transform)

    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Box
    }
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    col.bodydef.position = pos

    col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

    box := b2.MakeBox(1000, .1)
    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Environment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = g_contact_identifier.Player
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    movable : Cmp_Movable

    add_component(barrel, col)
    add_component(barrel, movable)
}

// All objects except the main player will have this
Cmp_Movable :: struct{
}

update_movables :: proc(delta_time: f32)
{
    //First just the visible g_floor
    for i in 0..<2{
        fc := get_component(g_floor[i], Cmp_Transform)
        fc.local.pos.x -= 1.0 * delta_time

        //refresh world if done
        if fc.local.pos.x <= -25.0 {
            for e in g_objects[curr_phase] do remove_entity(e)
            mem.arena_free_all(&distance_arena[curr_phase])
            curr_phase = (curr_phase + 1) % 2
        }
    }
    movables := query(has(Cmp_Movable), has(Cmp_Collision2D))
    for movable in movables{
        cols := get_table(movable, Cmp_Collision2D)
        for e, i in movable.entities{
            nc := get_component(e, Cmp_Node)
            tc := get_component(e, Cmp_Transform)
            if nc.name == "Barrel" do fmt.println("Barrel Pos: ", tc.local.pos.xy)
            b2.Body_SetLinearVelocity(cols[i].bodyid, delta_time * 1)
        }
    }
}

update_physics :: proc(delta_time: f32)
{
    b2.World_Step(g_world_id, delta_time, 4)
    update_player_movement_phys(delta_time)
    arcs := query(has(Cmp_Transform), has(Cmp_Collision2D))
    for arc in arcs{
        trans := get_table(arc,Cmp_Transform)
        colis := get_table(arc,Cmp_Collision2D)
        for _, i in arc.entities{
            trans[i].local.pos.xy = b2.Body_GetPosition(colis[i].bodyid)
        }
    }
}

update_player_movement_phys :: proc(delta_time: f32)
{
    cc := get_component(g_player, Cmp_Collision2D)
    if cc == nil do return
    vel := b2.Vec2{0,0}
    move_speed :f32= 10.0
    if is_key_pressed(glfw.KEY_SPACE) {
        vel.y += move_speed
    }
    b2.Body_SetLinearVelocity(cc.bodyid, delta_time * 50 * vel)
}
