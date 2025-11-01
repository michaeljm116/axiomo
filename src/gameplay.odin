package main

import "core:fmt"
import "core:mem"
import "core:math"
import "core:time"
import "core:math/linalg"
import vmem "core:mem/virtual"
import "core:c"
import "vendor:glfw"
import b2"vendor:box2d"

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

// Initialize the gameplay system
gameplay_init :: proc() {

    g.light_orbit_radius = 5.0
    g.light_orbit_speed = 0.25   // radians per second
    g.light_orbit_angle = 15.0

    g.world = create_world()
	// defer destroy_world()
	load_scene(g.scene^, g.mem_game.alloc)
	added_entity(g.world_ent)
	g.player = load_prefab("Froku")
	g.app_state = .TitleScreen
	init_memory_arena(&g.mem_game, mem.Megabyte)
    g.input = InputState{
        mouse_sensitivity = 0.1,
        movement_speed = 5.0,
        rotation_speed = 20.0,
        first_mouse = true,
    }

    // Set up GLFW callbacks
    glfw.SetKeyCallback(g.rb.window, key_callback)
    glfw.SetCursorPosCallback(g.rb.window, mouse_callback)
    glfw.SetMouseButtonCallback(g.rb.window, mouse_button_callback)

    // Capture mouse cursor
    glfw.SetInputMode(g.rb.window, glfw.CURSOR, glfw.CURSOR_DISABLED)

    // Find the camera entity
    find_camera_entity()
    find_light_entity()
    find_player_entity()
    face_left(g.player)
    //setup_physics()

    ////////////////// actual bks init ////////////////
    app_start()
}

gameplay_post_init :: proc()
{
    // chest := g.level.chests[0]
    // chest2 := g.level.chests[1]
    // move_entity_to_tile(chest, g.level.grid_scale, vec2{2,0})
    // move_entity_to_tile(chest2, g.level.grid_scale, vec2{4,3})
}

// Find the camera entity in the scene
find_camera_entity :: proc() {
    camera_archetypes := query(has(Cmp_Camera), has(Cmp_Transform), has(Cmp_Node))

    for archetype in camera_archetypes {
        entities := archetype.entities
        if len(entities) > 0 {
            g.camera_entity = entities[0]
            ct := get_component(g.camera_entity, Cmp_Transform)
            return
        }
    }

    fmt.println("Warning: No camera entity found!")
}

// Update input state and camera
gameplay_update :: proc(delta_time: f32) {
    if !entity_exists(g.camera_entity) do find_camera_entity()
    if !entity_exists(g.player) do find_player_entity()

    // handle_ui_edit_mode()
    // handle_player_edit_mode()
    // handle_destroy_mode()
    // if !edit_mode && !chest_mode && !player_edit_mode && !destroy_mode{
       app_run(delta_time, &g.app_state)
    // }
    // Clear just pressed/released states
    for i in 0..<len(g.input.keys_just_pressed) {
        g.input.keys_just_pressed[i] = false
        g.input.keys_just_released[i] = false
    }

        // Update light orbit (if a light entity was found)
    // update_light_orbit(delta_time)

    //update_camera_movement(delta_time)
    //update_player_movement(delta_time)
    // update_movables(delta_time)
    // update_physics(delta_time)
}

find_player_entity :: proc() {
    player_archetypes := query(has(Cmp_Transform), has(Cmp_Node), has(Cmp_Root))

    for archetype in player_archetypes {
        nodes := get_table(archetype, Cmp_Node)
        for node, i in nodes {
            if node.name == "Froku" {
                g.player = archetype.entities[i]
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
            if node.name == "Floor" do g.floor = archetype.entities[i]
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
           g.light_entity = entity
           return
       }
    }

    // No light found -> leave g.light_entity as 0
}

// Update the cached light entity so it orbits around a center point.
// If a player exists, orbit around the player's world position; otherwise use world origin.
update_light_orbit :: proc(delta_time: f32) {
    if !entity_exists(g.light_entity) {
        return
    }

    lc := get_component(g.light_entity, Cmp_Light)
    tc := get_component(g.light_entity, Cmp_Transform)
    if tc == nil || lc == nil {
        return
    }

    // Determine orbit center: prefer player position if available
    center := vec3{0.0, 11.5, 0.0}
    if g.player != 0 {
        pc := get_component(g.player, Cmp_Transform)
        if pc != nil {
            center = pc.local.pos.xyz
        }
    }

    // Advance angle
    g.light_orbit_angle += g.light_orbit_speed * delta_time

    // Compute new local position on XZ plane; keep Y relative to center
    new_x := center.x + math.cos(g.light_orbit_angle) * g.light_orbit_radius
    new_z := center.z + math.sin(g.light_orbit_angle) * g.light_orbit_radius
    new_y := center.y + 10.5 // offset above center (tweak as desired)

    // Update transform local position so the transform system will update world matrix
    tc.local.pos.x = new_x
    tc.local.pos.z = new_z
    tc.local.pos.y = new_y

    g.rt.update_flags += {.LIGHT}
}

update_player_movement :: proc(delta_time: f32)
{
    tc := get_component(g.player, Cmp_Transform)
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
    tc.local.rot = linalg.quaternion_angle_axis_f32(89.5, {0,1,0})
}

face_180 :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(179, {0,1,0})
    fmt.println(linalg.angle_axis_from_quaternion(tc.local.rot))
}

face_right :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(-89.5, {0,1,0})
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

//----------------------------------------------------------------------------\\
// /Input
//----------------------------------------------------------------------------\\
is_key_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST {
        return false
    }
    return g.input.keys_pressed[key]
}

is_key_just_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST {
        return false
    }
    return g.input.keys_just_pressed[key]
}

is_key_just_released :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST {
        return false
    }
    return g.input.keys_just_released[key]
}

is_mouse_button_pressed :: proc(button: i32) -> bool {
    if button < 0 || button > glfw.MOUSE_BUTTON_LAST {
        return false
    }
    return g.input.mouse_buttons[button]
}

// GLFW Callbacks
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = g.rb.ctx

    if key < 0 || key > glfw.KEY_LAST {
        return
    }

    switch action {
    case glfw.PRESS:
        if !g.input.keys_pressed[key] {
            g.input.keys_just_pressed[key] = true
        }
        g.input.keys_pressed[key] = true

    case glfw.RELEASE:
        g.input.keys_just_released[key] = true
        g.input.keys_pressed[key] = false

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
            g.input.first_mouse = true
        }
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = g.rb.ctx

    if g.input.first_mouse {
        g.input.last_mouse_x = xpos
        g.input.last_mouse_y = ypos
        g.input.first_mouse = false
    }

    g.input.mouse_delta_x = xpos - g.input.last_mouse_x
    g.input.mouse_delta_y = ypos - g.input.last_mouse_y

    g.input.last_mouse_x = xpos
    g.input.last_mouse_y = ypos
    g.input.mouse_x = xpos
    g.input.mouse_y = ypos
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
    context = g.rb.ctx

    if button < 0 || button > glfw.MOUSE_BUTTON_LAST {
        return
    }

    switch action {
    case glfw.PRESS:
        g.input.mouse_buttons[button] = true

    case glfw.RELEASE:
        g.input.mouse_buttons[button] = false
    }
}

// Cleanup
gameplay_destroy :: proc() {
    defer destroy_world()
    // Reset callbacks
    glfw.SetKeyCallback(g.rb.window, nil)
    glfw.SetCursorPosCallback(g.rb.window, nil)
    glfw.SetMouseButtonCallback(g.rb.window, nil)

    // Release mouse cursor
    glfw.SetInputMode(g.rb.window, glfw.CURSOR, glfw.CURSOR_NORMAL)

    reset_memory_arena(&g.mem_game)
}
