package axiom

import "vendor:glfw"
import "core:mem"

// Simple controller abstraction (keyboard only for now)
// Hardcoded defaults: Space=Action, Enter=Select, LeftShift=Sprint, F=Focus

ControllerAction :: enum {
    Action,
    Select,
    Sprint,
    Dodge,
    Cancel,
    Focus,
    Up,
    Down,
    Left,
    Right,
    // Virtual axes
    MoveX,
    MoveY,
}

Binding :: struct{
    key: i32,
}

ControllerState :: struct{
    pressed : map[ControllerAction]bool,
    just_pressed : map[ControllerAction]bool,
    just_released : map[ControllerAction]bool,
    move_axis : vec2f,
    bindings : map[ControllerAction]Binding,
}

g_controller : ControllerState

init_default_bindings :: proc(){
    // lazy init maps
    g_controller.pressed = make(map[ControllerAction]bool)
    g_controller.just_pressed = make(map[ControllerAction]bool)
    g_controller.just_released = make(map[ControllerAction]bool)
    g_controller.bindings = make(map[ControllerAction]Binding)

    // Keyboard defaults
    g_controller.bindings[.Action] = Binding{ key = glfw.KEY_SPACE }
    g_controller.bindings[.Select] = Binding{ key = glfw.KEY_ENTER }
    g_controller.bindings[.Sprint] = Binding{ key = glfw.KEY_LEFT_SHIFT }
    g_controller.bindings[.Dodge] = Binding{ key = glfw.KEY_D }
    g_controller.bindings[.Cancel] = Binding{ key = glfw.KEY_ESCAPE }
    g_controller.bindings[.Focus] = Binding{ key = glfw.KEY_F }

    // Directional bindings are handled as key sets in update
}

// Update controller state from glfw/g_input helpers in window.odin
controller_update_from_window_input :: proc(){
    // ensure bindings exist
    if len(g_controller.bindings) == 0 { init_default_bindings() }

    // clear just_* maps
    for a in g_controller.just_pressed { g_controller.just_pressed[a] = false }
    for a in g_controller.just_released { g_controller.just_released[a] = false }

    // update primary action buttons
    for action, bind in g_controller.bindings {
        kp := is_key_pressed(bind.key)
        kjp := is_key_just_pressed(bind.key)
        kjr := is_key_just_released(bind.key)

        // set maps
        g_controller.pressed[action] = kp
        if kjp { g_controller.just_pressed[action] = true }
        if kjr { g_controller.just_released[action] = true }
    }

    // axis from keys (WASD + arrows)
    left := is_key_pressed(glfw.KEY_A) || is_key_pressed(glfw.KEY_LEFT)
    right := is_key_pressed(glfw.KEY_D) || is_key_pressed(glfw.KEY_RIGHT)
    up := is_key_pressed(glfw.KEY_W) || is_key_pressed(glfw.KEY_UP)
    down := is_key_pressed(glfw.KEY_S) || is_key_pressed(glfw.KEY_DOWN)

    x := f32(0)
    y := f32(0)
    if left && !right { x = -1.0 }
    if right && !left { x = 1.0 }
    if up && !down { y = 1.0 }
    if down && !up { y = -1.0 }
    g_controller.move_axis = vec2f{x, y}

    // also set directional action booleans for convenience
    g_controller.pressed[.Left] = left
    g_controller.pressed[.Right] = right
    g_controller.pressed[.Up] = up
    g_controller.pressed[.Down] = down
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

// Pass-through helpers for legacy direct-key checks (use sparingly)
controller_key_pressed :: proc(key: i32) -> bool {
    return is_key_pressed(key)
}
controller_key_just_pressed :: proc(key: i32) -> bool {
    return is_key_just_pressed(key)
}

