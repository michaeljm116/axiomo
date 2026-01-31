// controller_test.odin
package axiom_tests
import axiom".."
import "core:testing"
import "vendor:glfw"
import "core:math"

// Helpers to reset & set input state conveniently
@(private="file")
reset_input_state :: proc() {
    axiom.g_input = axiom.InputState{
        mouse_sensitivity = 0.1,
        movement_speed    = 5.0,
        rotation_speed    = 20.0,
        first_mouse       = true,
    }
}

@(private="file")
set_key_state :: proc(key: i32, pressed: bool, just_pressed: bool = false, just_released: bool = false) {
    if key < 0 || key > glfw.KEY_LAST { return }
    axiom.g_input.keys_pressed[key]      = pressed
    axiom.g_input.keys_just_pressed[key] = just_pressed
    axiom.g_input.keys_just_released[key]= just_released
}

// ─────────────────────────────────────────────
// Setup / Teardown per test
// ─────────────────────────────────────────────
@(test)
setup :: proc(t: ^testing.T) {
    reset_input_state()
    axiom.g_controller = {} // zero out controller
    axiom.controller_init_default_keyboard(&axiom.g_controller)
}

@(test)
teardown :: proc(t: ^testing.T) {
    // optional – most people just let Odin zero globals between runs
}

// ─────────────────────────────────────────────
// Button state machine – single button transitions
// ─────────────────────────────────────────────

@(test)
test_button_press_hold_release :: proc(t: ^testing.T) {
    using testing

    b := &axiom.g_controller.buttons[axiom.ButtonType.ActionU]
    b.key = glfw.KEY_SPACE
    b.time.max = 0.35   // we will cross this threshold

    // ─── Frame 1: Just pressed ───────────────────────
    set_key_state(glfw.KEY_SPACE, true, true, false)
    axiom.controller_handle_button(b, 0.016)

expect(t, axiom.ButtonAction.JustPressed in b.action)
    expect(t, axiom.ButtonAction.Pressed    in b.action)
    expect(t, b.val == 1)
    expect(t, b.time.curr == 0)

    // ─── Frame 2: still down, not yet held ───────────
    set_key_state(glfw.KEY_SPACE, true, false, false)
    axiom.controller_handle_button(b, 0.016)

    expect(t, axiom.ButtonAction.Pressed in b.action)
    expect(t, !(axiom.ButtonAction.JustPressed in b.action))
    expect(t, !(axiom.ButtonAction.Held in b.action))
    expect(t, b.val == 1)
    // expect(t, b.time.curr ≈= 0.016)

    // ─── Many frames: cross hold threshold ───────────
    for i in 0..<30 {
        set_key_state(glfw.KEY_SPACE, true, false, false)
        axiom.controller_handle_button(b, 0.016)
    }

    expect(t, axiom.ButtonAction.Held    in b.action)
    expect(t, axiom.ButtonAction.Pressed in b.action)
    expect(t, b.time.curr >= 0.35)

    // ─── Frame N: release ────────────────────────────
    set_key_state(glfw.KEY_SPACE, false, false, true)
    axiom.controller_handle_button(b, 0.016)

    expect(t, axiom.ButtonAction.JustReleased in b.action)
    expect(t, axiom.ButtonAction.Released     in b.action)
    expect(t, b.val == 0)
    expect(t, b.time.curr == 0)
    expect(t, !(axiom.ButtonAction.Pressed in b.action))
    expect(t, !(axiom.ButtonAction.Held    in b.action))
}

@(test)
test_just_flags_are_one_frame_only :: proc(t: ^testing.T) {
    using testing

    b := &axiom.g_controller.buttons[axiom.ButtonType.ActionD]
    b.key = glfw.KEY_E

    // Frame 1: press
    set_key_state(glfw.KEY_E, true, true, false)
    axiom.controller_handle_button(b, 0.016)
    expect(t, axiom.ButtonAction.JustPressed in b.action)

    // Frame 2: hold
    set_key_state(glfw.KEY_E, true, false, false)
    axiom.controller_handle_button(b, 0.016)
    expect(t, !(axiom.ButtonAction.JustPressed in b.action))
    expect(t, axiom.ButtonAction.Pressed in b.action)

    // Frame 3: release
    set_key_state(glfw.KEY_E, false, false, true)
    axiom.controller_handle_button(b, 0.016)
    expect(t, axiom.ButtonAction.JustReleased in b.action)

    // Frame 4: idle → JustReleased should be gone
    set_key_state(glfw.KEY_E, false, false, false)
    axiom.controller_handle_button(b, 0.016)
    expect(t, !(axiom.ButtonAction.JustReleased in b.action))
    expect(t, axiom.ButtonAction.Released in b.action)
}

// ─────────────────────────────────────────────
// D-Pad → left_axis conversion
// ─────────────────────────────────────────────

@(test)
test_dpad_axis_basic_directions :: proc(t: ^testing.T) {
    using testing

    // W pressed → forward/up
    set_key_state(glfw.KEY_W, true)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

    expect(t, axiom.g_controller.left_axis.x ==  0)
    expect(t, axiom.g_controller.left_axis.y == -1)   // note your sign flip
    expect(t, axiom.g_controller.left_axis.isMoving)

    // A + D → should cancel
    set_key_state(glfw.KEY_A, true)
    set_key_state(glfw.KEY_D, true)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

    expect(t, axiom.g_controller.left_axis.x == 0)
    expect(t, axiom.g_controller.left_axis.y == 0)    // still from previous W
    expect(t, !axiom.g_controller.left_axis.isMoving)

    // Only D → right
    set_key_state(glfw.KEY_A, false)
    set_key_state(glfw.KEY_W, false)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

    expect(t, axiom.g_controller.left_axis.x ==  1)
    expect(t, axiom.g_controller.left_axis.y ==  0)
    expect(t, axiom.g_controller.left_axis.isMoving)
}

@(test)
test_axis_diagonal_and_zero :: proc(t: ^testing.T) {
    using testing

    // W + D → up-right
    set_key_state(glfw.KEY_W, true)
    set_key_state(glfw.KEY_D, true)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

    expect(t, axiom.g_controller.left_axis.x ==  1)
    expect(t, axiom.g_controller.left_axis.y == -1)
    expect(t, axiom.g_controller.left_axis.isMoving)

    // Release all
    reset_input_state()
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

    expect(t, axiom.g_controller.left_axis.x == 0)
    expect(t, axiom.g_controller.left_axis.y == 0)
    expect(t, !axiom.g_controller.left_axis.isMoving)
}

// ─────────────────────────────────────────────
// Deadzone helper (axiom.controller_handle_epsilon)
// ─────────────────────────────────────────────

@(test)
test_epsilon_deadzone :: proc(t: ^testing.T) {
    using testing
    // using math

    expect(t, axiom.controller_handle_epsilon(0.00)  == 0.0)
    expect(t, axiom.controller_handle_epsilon(0.04)  == 0.0)
    expect(t, axiom.controller_handle_epsilon(0.049) == 0.0)
    expect(t, axiom.controller_handle_epsilon(0.05)  >  0.0)
    expect(t, axiom.controller_handle_epsilon(0.051) >  0.0)

    expect(t, axiom.controller_handle_epsilon(-0.07) <  0.0)
    expect(t, axiom.controller_handle_epsilon(-0.049) == 0.0)

    v := f32(0.333)
    expect(t, axiom.controller_handle_epsilon(v) == v)   // > 0.05 → unchanged
}