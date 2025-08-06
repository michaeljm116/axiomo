package main

import "vendor:glfw"
import "core:math"
import "core:fmt"
import "core:time"
import "core:math/linalg"

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

// Camera entity - will be set by gameplay system
g_camera_entity: Entity = 0

// Initialize the gameplay system
gameplay_init :: proc() {
    g_input = InputState{
        mouse_sensitivity = 0.1,
        movement_speed = 5.0,
        rotation_speed = 2.0,
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
}

// Find the camera entity in the scene
find_camera_entity :: proc() {
    camera_archetypes := query(has(Cmp_Camera), has(Cmp_Transform), has(Cmp_Node))

    for archetype in camera_archetypes {
        entities := archetype.entities
        if len(entities) > 0 {
            g_camera_entity = entities[0]
            fmt.printf("Found camera entity: %d\n", g_camera_entity)
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

    // Clear just pressed/released states
    for i in 0..<len(g_input.keys_just_pressed) {
        g_input.keys_just_pressed[i] = false
        g_input.keys_just_released[i] = false
    }

    update_camera_movement(delta_time)
    update_camera_rotation(delta_time)
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

// Handle camera rotation with mouse
update_camera_rotation :: proc(delta_time: f32) {
    camera_transform := get_component(g_camera_entity, Cmp_Transform)

    if camera_transform == nil {
        return
    }

    // Apply mouse sensitivity
    yaw_delta := -f32(g_input.mouse_delta_x) * g_input.mouse_sensitivity * delta_time * g_input.rotation_speed
    pitch_delta := -f32(g_input.mouse_delta_y) * g_input.mouse_sensitivity * delta_time * g_input.rotation_speed

    // Update euler rotation
    camera_transform.euler_rotation.y += yaw_delta
    camera_transform.euler_rotation.x += pitch_delta

    // Clamp pitch to prevent flipping
    camera_transform.euler_rotation.x = math.clamp(camera_transform.euler_rotation.x, -89.0, 89.0)

    // Convert euler to quaternion
    rotation_matrix := linalg.matrix4_from_euler_angles_xyz_f32(
        math.to_radians(camera_transform.euler_rotation.x),
        math.to_radians(camera_transform.euler_rotation.y),
        math.to_radians(camera_transform.euler_rotation.z)
    )
    camera_transform.local.rot = linalg.quaternion_from_matrix4_f32(rotation_matrix)

    // Reset mouse delta
    g_input.mouse_delta_x = 0
    g_input.mouse_delta_y = 0
}

// Get camera forward vector
get_camera_forward :: proc(transform: ^Cmp_Transform) -> vec3 {
    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform.local.rot)
    return -vec3{rotation_matrix[2][0], rotation_matrix[2][1], rotation_matrix[2][2]}
}

// Get camera right vector
get_camera_right :: proc(transform: ^Cmp_Transform) -> vec3 {
    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform.local.rot)
    return vec3{rotation_matrix[0][0], rotation_matrix[0][1], rotation_matrix[0][2]}
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
}