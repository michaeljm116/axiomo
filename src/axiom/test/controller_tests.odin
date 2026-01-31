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

	expectf(t, axiom.ButtonAction.JustPressed in b.action, "Expected JustPressed in action, Result: %v", axiom.ButtonAction.JustPressed in b.action)
    expectf(t, axiom.ButtonAction.Pressed    in b.action, "Expected Pressed in action, Result: %v", axiom.ButtonAction.Pressed in b.action)
    expectf(t, b.val == 1, "Expected button value to be 1, Result: %f", b.val)
    expectf(t, b.time.curr == 0, "Expected time to be 0, Result: %f", b.time.curr)

    // ─── Frame 2: still down, not yet held ───────────
    set_key_state(glfw.KEY_SPACE, true, false, false)
    axiom.controller_handle_button(b, 0.016)

	expectf(t, axiom.ButtonAction.Pressed in b.action, "Expected Pressed in action, Result: %v", axiom.ButtonAction.Pressed in b.action)
    expectf(t, !(axiom.ButtonAction.JustPressed in b.action), "Expected JustPressed not in action, Result: %v", axiom.ButtonAction.JustPressed in b.action)
    expectf(t, !(axiom.ButtonAction.Held in b.action), "Expected Held not in action, Result: %v", axiom.ButtonAction.Held in b.action)
    expectf(t, b.val == 1, "Expected button value to be 1, Result: %f", b.val)
    // expect(t, b.time.curr ≈= 0.016)

    // ─── Many frames: cross hold threshold ───────────
    for i in 0..<30 {
        set_key_state(glfw.KEY_SPACE, true, false, false)
        axiom.controller_handle_button(b, 0.016)
    }

	expectf(t, axiom.ButtonAction.Held    in b.action, "Expected Held in action, Result: %v", axiom.ButtonAction.Held in b.action)
    expectf(t, axiom.ButtonAction.Pressed in b.action, "Expected Pressed in action, Result: %v", axiom.ButtonAction.Pressed in b.action)
    expectf(t, b.time.curr >= 0.35, "Expected time >= 0.35, Result: %f", b.time.curr)

    // ─── Frame N: release ────────────────────────────
    set_key_state(glfw.KEY_SPACE, false, false, true)
    axiom.controller_handle_button(b, 0.016)

	expectf(t, axiom.ButtonAction.JustReleased in b.action, "Expected JustReleased in action, Result: %v", axiom.ButtonAction.JustReleased in b.action)
    expectf(t, axiom.ButtonAction.Released     in b.action, "Expected Released in action, Result: %v", axiom.ButtonAction.Released in b.action)
    expectf(t, b.val == 0, "Expected button value to be 0, Result: %f", b.val)
    expectf(t, b.time.curr == 0, "Expected time to be 0, Result: %f", b.time.curr)
    expectf(t, !(axiom.ButtonAction.Pressed in b.action), "Expected Pressed not in action, Result: %v", axiom.ButtonAction.Pressed in b.action)
    expectf(t, !(axiom.ButtonAction.Held    in b.action), "Expected Held not in action, Result: %v", axiom.ButtonAction.Held in b.action)
}

@(test)
test_just_flags_are_one_frame_only :: proc(t: ^testing.T) {
    using testing

    b := &axiom.g_controller.buttons[axiom.ButtonType.ActionD]
    b.key = glfw.KEY_E

    // Frame 1: press
    set_key_state(glfw.KEY_E, true, true, false)
    axiom.controller_handle_button(b, 0.016)
    expectf(t, axiom.ButtonAction.JustPressed in b.action, "Expected JustPressed in action, Result: %v", axiom.ButtonAction.JustPressed in b.action)

    // Frame 2: hold
    set_key_state(glfw.KEY_E, true, false, false)
    axiom.controller_handle_button(b, 0.016)
	expectf(t, !(axiom.ButtonAction.JustPressed in b.action), "Expected JustPressed not in action, Result: %v", axiom.ButtonAction.JustPressed in b.action)
    expectf(t, axiom.ButtonAction.Pressed in b.action, "Expected Pressed in action, Result: %v", axiom.ButtonAction.Pressed in b.action)

    // Frame 3: release
    set_key_state(glfw.KEY_E, false, false, true)
    axiom.controller_handle_button(b, 0.016)
    expectf(t, axiom.ButtonAction.JustReleased in b.action, "Expected JustReleased in action, Result: %v", axiom.ButtonAction.JustReleased in b.action)

    // Frame 4: idle → JustReleased should be gone
    set_key_state(glfw.KEY_E, false, false, false)
    axiom.controller_handle_button(b, 0.016)
	expectf(t, !(axiom.ButtonAction.JustReleased in b.action), "Expected JustReleased not in action, Result: %v", axiom.ButtonAction.JustReleased in b.action)
    expectf(t, axiom.ButtonAction.Released in b.action, "Expected Released in action, Result: %v", axiom.ButtonAction.Released in b.action)
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

	expectf(t, axiom.g_controller.left_axis.x ==  0, "Expected left_axis.x to be 0, Result: %f", axiom.g_controller.left_axis.x)
    expectf(t, axiom.g_controller.left_axis.y == -1, "Expected left_axis.y to be -1, Result: %f", axiom.g_controller.left_axis.y)   // note your sign flip
    expectf(t, axiom.g_controller.left_axis.isMoving, "Expected isMoving to be true, Result: %v", axiom.g_controller.left_axis.isMoving)

    // A + D → should cancel
    set_key_state(glfw.KEY_A, true)
    set_key_state(glfw.KEY_D, true)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

	expectf(t, axiom.g_controller.left_axis.x == 0, "Expected left_axis.x to be 0, Result: %f", axiom.g_controller.left_axis.x)
    expectf(t, axiom.g_controller.left_axis.y == 0, "Expected left_axis.y to be 0, Result: %f", axiom.g_controller.left_axis.y)    // still from previous W
    expectf(t, !axiom.g_controller.left_axis.isMoving, "Expected isMoving to be false, Result: %v", axiom.g_controller.left_axis.isMoving)

    // Only D → right
    set_key_state(glfw.KEY_A, false)
    set_key_state(glfw.KEY_W, false)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

	expectf(t, axiom.g_controller.left_axis.x ==  1, "Expected left_axis.x to be 1, Result: %f", axiom.g_controller.left_axis.x)
    expectf(t, axiom.g_controller.left_axis.y ==  0, "Expected left_axis.y to be 0, Result: %f", axiom.g_controller.left_axis.y)
    expectf(t, axiom.g_controller.left_axis.isMoving, "Expected isMoving to be true, Result: %v", axiom.g_controller.left_axis.isMoving)
}

@(test)
test_axis_diagonal_and_zero :: proc(t: ^testing.T) {
    using testing

    // W + D → up-right
    set_key_state(glfw.KEY_W, true)
    set_key_state(glfw.KEY_D, true)
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

	expectf(t, axiom.g_controller.left_axis.x ==  1, "Expected x == 1, Result: %f", axiom.g_controller.left_axis.x)
    expectf(t, axiom.g_controller.left_axis.y == -1, "Expected left_axis.y to be -1, Result: %f", axiom.g_controller.left_axis.y)
    expectf(t, axiom.g_controller.left_axis.isMoving, "Expected isMoving to be true, Result: %v", axiom.g_controller.left_axis.isMoving)

    // Release all
    reset_input_state()
    axiom.controller_handle_keyboard(&axiom.g_controller, 0.016)

	expectf(t, axiom.g_controller.left_axis.x == 0, "Expected left_axis.x to be 0, Result: %f", axiom.g_controller.left_axis.x)
    expectf(t, axiom.g_controller.left_axis.y == 0, "Expected left_axis.y to be 0, Result: %f", axiom.g_controller.left_axis.y)
    expectf(t, !axiom.g_controller.left_axis.isMoving, "Expected isMoving to be false, Result: %v", axiom.g_controller.left_axis.isMoving)
}

// ─────────────────────────────────────────────
// Deadzone helper (axiom.controller_handle_epsilon)
// ─────────────────────────────────────────────

@(test)
test_epsilon_deadzone :: proc(t: ^testing.T) {
    using testing
    // using math

	expectf(t, axiom.controller_handle_epsilon(0.00)  == 0.0, "Expected epsilon(0.00) to be 0.0, Result: %f", axiom.controller_handle_epsilon(0.00))
    expectf(t, axiom.controller_handle_epsilon(0.04)  == 0.0, "Expected epsilon(0.04) to be 0.0, Result: %f", axiom.controller_handle_epsilon(0.04))
    expectf(t, axiom.controller_handle_epsilon(0.049) == 0.0, "Expected epsilon(0.049) to be 0.0, Result: %f", axiom.controller_handle_epsilon(0.049))
    expectf(t, axiom.controller_handle_epsilon(0.05)  >  0.0, "Expected epsilon(0.05) to be > 0.0, Result: %f", axiom.controller_handle_epsilon(0.05))
    expectf(t, axiom.controller_handle_epsilon(0.051) >  0.0, "Expected epsilon(0.051) to be > 0.0, Result: %f", axiom.controller_handle_epsilon(0.051))

	expectf(t, axiom.controller_handle_epsilon(-0.07) <  0.0, "Expected epsilon(-0.07) to be < 0.0, Result: %f", axiom.controller_handle_epsilon(-0.07))
    expectf(t, axiom.controller_handle_epsilon(-0.049) == 0.0, "Expected epsilon(-0.049) to be 0.0, Result: %f", axiom.controller_handle_epsilon(-0.049))

    v := f32(0.333)
    expectf(t, axiom.controller_handle_epsilon(v) == v, "Expected epsilon(0.333) to equal 0.333, Result: %f", axiom.controller_handle_epsilon(v))   // > 0.05 → unchanged
}
