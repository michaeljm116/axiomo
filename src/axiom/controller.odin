package axiom

import "vendor:glfw"
import "core:mem"

ButtonTypes :: enum
{
   Action1,
   Action2,
   Action3,
   Action4,
   Shoulder1,
   Shoulder2,
   Trigger1,
   Trigger2,

   Menu1,
   Menu2,
   Extra1,
   Extra2,
   Extra3,
   Extra4,
   Extra5,
   Extra6,
}

// Input type selection
InputType :: enum {
    Keyboard,
    Gamepad,
    Joystick,
    AI,
}

// High-level controller actions (kept for compatibility with game code)
ControllerAction :: enum {
    Action,
    Select,
    Sprint,
    Dodge,
    Cancel,
    Focus,
}

Dir :: enum {
    Left,
    Right,
    Up,
    Down,
}

// Controller button indices matching C++ enum
ControllerButton :: enum {
    Keyboard_Right = 0,
    Keyboard_Up,
    Keyboard_Left,
    Keyboard_Down,
    Keyboard_Forward,
    Keyboard_Backward,
}

// Binding maps an action to a key
Binding :: struct { key: i32 }

// Low-level button with timing/action state (mirrors C++ Button)
Button :: struct {
    key: i32,
    action: int, // -1 released, 0 idle, 1 pressed
    time: f32,
}

NUM_BUTTONS :: len(ButtonTypes)

// Axis value + moving flag
Axis :: struct {
    value : vec2f,
    isMoving : bool,
}

ControllerState :: struct{
    // input type selection
    input_type : InputType,
    
    // high-level maps (semantic actions)
    pressed : map[ControllerAction]bool,
    just_pressed : map[ControllerAction]bool,
    just_released : map[ControllerAction]bool,
    bindings : map[ControllerAction]Binding,

    // low-level button array and axis buttons
    buttons : [NUM_BUTTONS]Button,
    axis_buttons : [6]Button,

    // computed axis / direction helpers
    move_axis : vec2f,
    dir_pressed : map[Dir]bool,

    // analog axes (vec3 to match C++ with x,y,z)
    left_axis : vec3f,
    moving_left_axis : bool,
    right_axis : vec3f,
    moving_right_axis : bool,
    
    // controller index for gamepad support
    gamepad_index : int,
}

g_controller : ControllerState

// Helper function matching C++ handle_button logic
handle_button :: proc(button: ^Button, is_pressed: bool, dt: f32) {
    // Query if key is currently pressed
    if is_pressed {
        // If it has been pressed/continued update it
        if button.time == 0.0 {
            button.action = 1  // GLFW_PRESS equivalent
        }
        button.time += dt
    } else {
        // If it has been released 
        if button.time > 0.0 {
            button.action = -1  // Initial release
        } else {
            button.action = 0   // Blank/continue released
        }
        button.time = 0.0
    }
}

// Helper function matching C++ handle_epsilon for deadzone handling
handle_epsilon :: proc(val: f32) -> f32 {
    if abs(val) < 0.05 {
        return 0.0
    }
    return val
}

handle_gamepad :: proc(dt: f32) {
    state: glfw.GamepadState
    if glfw.GetGamepadState(g_controller.gamepad_index, &state) {
        // Handle gamepad buttons (only use first NUM_BUTTONS)
        for i in 0..<min(NUM_BUTTONS, len(state.buttons)) {
            handle_button(&g_controller.buttons[i], state.buttons[i] == glfw.PRESS, dt)
        }

        // Handle axes with epsilon deadzone
        g_controller.left_axis.x = handle_epsilon(state.axes[0])
        g_controller.left_axis.y = -handle_epsilon(state.axes[1])  // Invert Y like C++
        g_controller.left_axis.z = handle_epsilon(state.axes[4])
        
        g_controller.right_axis.x = handle_epsilon(state.axes[2])
        g_controller.right_axis.y = -handle_epsilon(state.axes[3])  // Invert Y like C++
        g_controller.right_axis.z = handle_epsilon(state.axes[5])

        // Update moving flags based on 2D magnitude (ignoring Z for movement)
        left_mag_sq := g_controller.left_axis.x * g_controller.left_axis.x + g_controller.left_axis.y * g_controller.left_axis.y
        right_mag_sq := g_controller.right_axis.x * g_controller.right_axis.x + g_controller.right_axis.y * g_controller.right_axis.y
        
        g_controller.moving_left_axis = left_mag_sq > 0.0
        g_controller.moving_right_axis = right_mag_sq > 0.0

        // Update move_axis from left stick (2D only)
        g_controller.move_axis.x = g_controller.left_axis.x
        g_controller.move_axis.y = g_controller.left_axis.y
    }
}

handle_keyboard :: proc(dt: f32) {
    // Handle main buttons
    for i in 0..<NUM_BUTTONS {
        btn := &g_controller.buttons[i]
        if btn.key < 0 { continue }
        handle_button(btn, is_key_pressed(btn.key), dt)
    }

    // Handle axis buttons
    for i in 0..<len(g_controller.axis_buttons) {
        ab := &g_controller.axis_buttons[i]
        if ab.key < 0 { continue }
        handle_button(ab, is_key_pressed(ab.key), dt)
    }

    // Create temporary axis using Oneify-like logic from C++
    // Using direct key presses like the C++ Oneify implementation
    right_val := 0
    left_val := 0
    up_val := 0
    down_val := 0
    forward_val := 0
    backward_val := 0
    
    if is_key_pressed(g_controller.axis_buttons[0].key) { right_val = 1 }
    if is_key_pressed(g_controller.axis_buttons[2].key) { left_val = 1 }
    if is_key_pressed(g_controller.axis_buttons[1].key) { up_val = 1 }
    if is_key_pressed(g_controller.axis_buttons[3].key) { down_val = 1 }
    if is_key_pressed(g_controller.axis_buttons[4].key) { forward_val = 1 }
    if is_key_pressed(g_controller.axis_buttons[5].key) { backward_val = 1 }

    // Calculate axis values matching C++ logic
    temp_axis := vec3f{
        -f32(left_val) + f32(right_val),
        f32(up_val) - f32(down_val),
        f32(forward_val) - f32(backward_val)
    }

    g_controller.left_axis = temp_axis
    g_controller.moving_left_axis = (temp_axis.x * temp_axis.x + temp_axis.y * temp_axis.y) != 0.0
    
    // Update move_axis from keyboard input (2D only)
    g_controller.move_axis.x = temp_axis.x
    g_controller.move_axis.y = temp_axis.y
}

init_default_bindings :: proc(){
    // Initialize input type and gamepad index
    g_controller.input_type = .Keyboard
    g_controller.gamepad_index = 0
    
    // initialize defaults
    // lazy init maps
    g_controller.pressed = make(map[ControllerAction]bool)
    g_controller.just_pressed = make(map[ControllerAction]bool)
    g_controller.just_released = make(map[ControllerAction]bool)
    g_controller.bindings = make(map[ControllerAction]Binding)
    g_controller.dir_pressed = make(map[Dir]bool)

    // Keyboard defaults
    g_controller.bindings[.Action] = Binding{ key = glfw.KEY_SPACE }
    g_controller.bindings[.Select] = Binding{ key = glfw.KEY_ENTER }
    g_controller.bindings[.Sprint] = Binding{ key = glfw.KEY_LEFT_SHIFT }
    g_controller.bindings[.Dodge] = Binding{ key = glfw.KEY_D }
    g_controller.bindings[.Cancel] = Binding{ key = glfw.KEY_ESCAPE }
    g_controller.bindings[.Focus] = Binding{ key = glfw.KEY_F }

    // Directional bindings are handled as key sets in update
    // Axis button defaults (+X, +Y, -X, -Y, +Z, -Z) - matching C++ ControllerButton enum
    g_controller.axis_buttons[0] = Button{ key = glfw.KEY_D, action = 0, time = 0.0 }  // +X (Right)
    g_controller.axis_buttons[1] = Button{ key = glfw.KEY_W, action = 0, time = 0.0 }  // +Y (Up)  
    g_controller.axis_buttons[2] = Button{ key = glfw.KEY_A, action = 0, time = 0.0 }  // -X (Left)
    g_controller.axis_buttons[3] = Button{ key = glfw.KEY_S, action = 0, time = 0.0 }  // -Y (Down)
    g_controller.axis_buttons[4] = Button{ key = glfw.KEY_E, action = 0, time = 0.0 }  // +Z (Forward)
    g_controller.axis_buttons[5] = Button{ key = glfw.KEY_Q, action = 0, time = 0.0 }  // -Z (Backward)

    // Initialize low-level buttons array
    for i in 0..<NUM_BUTTONS { g_controller.buttons[i] = Button{ key = -1, action = 0, time = 0.0 } }
    // Map common semantic keys into the low-level button slots (optional)
    g_controller.buttons[0].key = glfw.KEY_SPACE // slot 0 = action
    g_controller.buttons[1].key = glfw.KEY_ENTER // slot 1 = select
    g_controller.buttons[2].key = glfw.KEY_LEFT_SHIFT // slot 2 = sprint
    g_controller.buttons[3].key = glfw.KEY_D // slot 3 = dodge/other
    g_controller.buttons[4].key = glfw.KEY_ESCAPE // slot 4 = cancel
    g_controller.buttons[5].key = glfw.KEY_F // slot 5 = focus
}

// Update controller state from glfw/g_input helpers in window.odin
controller_update_from_window_input :: proc(dt: f32){
    // ensure bindings exist
    if len(g_controller.bindings) == 0 { init_default_bindings() }

    // clear just_* maps
    for a in g_controller.just_pressed { g_controller.just_pressed[a] = false }
    for a in g_controller.just_released { g_controller.just_released[a] = false }

    // Switch between input types
    if g_controller.input_type == .Gamepad {
        handle_gamepad(dt)
    } else {
        handle_keyboard(dt)
    }

    // Update high-level action bindings (only for keyboard mode, gamepad uses different mapping)
    if g_controller.input_type == .Keyboard {
        // update primary action buttons (high-level maps)
        for action, bind in g_controller.bindings {
            kp := is_key_pressed(bind.key)
            kjp := is_key_just_pressed(bind.key)
            kjr := is_key_just_released(bind.key)

            // set maps
            g_controller.pressed[action] = kp
            if kjp { g_controller.just_pressed[action] = true }
            if kjr { g_controller.just_released[action] = true }
        }
    }

    // also set directional pressed booleans (separate from actions)
    g_controller.dir_pressed[.Left] = is_key_pressed(glfw.KEY_A) || is_key_pressed(glfw.KEY_LEFT)
    g_controller.dir_pressed[.Right] = is_key_pressed(glfw.KEY_D) || is_key_pressed(glfw.KEY_RIGHT)
    g_controller.dir_pressed[.Up] = is_key_pressed(glfw.KEY_W) || is_key_pressed(glfw.KEY_UP)
    g_controller.dir_pressed[.Down] = is_key_pressed(glfw.KEY_S) || is_key_pressed(glfw.KEY_DOWN)
}

controller_pressed :: proc(a: ControllerAction) -> bool {
    return g_controller.pressed[a]
}
controller_just_pressed :: proc(a: ControllerAction) -> bool {
    return g_controller.just_pressed[a]
}
controller_just_released :: proc(a: ControllerAction) -> bool {
    return g_controller.just_released[a]
}
controller_axis :: proc() -> vec2f {
    return g_controller.move_axis
}

// Low-level button queries (by slot index)
controller_button_action :: proc(idx: int) -> int {
    if idx < 0 || idx >= NUM_BUTTONS { return 0 }
    return g_controller.buttons[idx].action
}
controller_button_time :: proc(idx: int) -> f32 {
    if idx < 0 || idx >= NUM_BUTTONS { return 0.0 }
    return g_controller.buttons[idx].time
}

// Directions (axes) query
controller_dir_pressed :: proc(d: Dir) -> bool {
    return g_controller.dir_pressed[d]
}

// Pass-through helpers for legacy direct-key checks (use sparingly)
controller_key_pressed :: proc(key: i32) -> bool {
    return is_key_pressed(key)
}
controller_key_just_pressed :: proc(key: i32) -> bool {
    return is_key_just_pressed(key)
}

// Input type management
controller_set_input_type :: proc(input_type: InputType) {
    g_controller.input_type = input_type
}
controller_get_input_type :: proc() -> InputType {
    return g_controller.input_type
}
controller_set_gamepad_index :: proc(index: int) {
    g_controller.gamepad_index = max(0, index)
}

// Analog axis queries
controller_left_axis :: proc() -> vec3f {
    return g_controller.left_axis
}
controller_right_axis :: proc() -> vec3f {
    return g_controller.right_axis
}
controller_moving_left_axis :: proc() -> bool {
    return g_controller.moving_left_axis
}
controller_moving_right_axis :: proc() -> bool {
    return g_controller.moving_right_axis
}

// Button queries by ButtonTypes enum
controller_button_action_by_type :: proc(btn_type: ButtonTypes) -> int {
    idx := int(btn_type)
    if idx < 0 || idx >= NUM_BUTTONS { return 0 }
    return g_controller.buttons[idx].action
}
controller_button_time_by_type :: proc(btn_type: ButtonTypes) -> f32 {
    idx := int(btn_type)
    if idx < 0 || idx >= NUM_BUTTONS { return 0.0 }
    return g_controller.buttons[idx].time
}

// Gamepad connection status
controller_is_gamepad_connected :: proc() -> bool {
    return glfw.JoystickPresent(g_controller.gamepad_index) && glfw.JoystickIsGamepad(g_controller.gamepad_index)
}

