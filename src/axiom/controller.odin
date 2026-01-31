package axiom

import "vendor:glfw"
import "core:mem"
import "core:math"
//----------------------------------------------------------------------------\\
// /Enums
//----------------------------------------------------------------------------\\
ButtonType :: enum
{
   ActionU,
   ActionD,
   ActionR,
   ActionL,

   PadU,
   PadD,
   PadR,
   PadL,

   ShoulderL,
   ShoulderR,
   TriggerL,
   TriggerR,

   MenuL,
   MenuR,
   AnalogL,
   AnalogR,
}

InputType :: enum
{
    Keyboard,
    Gamepad,
    Joystick,
    AI,
}

Dir :: enum
{
    Left,
    Right,
    Up,
    Down,
}

ButtonAction :: enum
{
    JustPressed,
    Pressed,
    Held,
    Released,
    JustReleased
}
ButtonActions :: bit_set[ButtonAction;u16]

//----------------------------------------------------------------------------\\
// /Structs
//----------------------------------------------------------------------------\\
Button :: struct // 16bytes
{
    key: i32,
    val: i16,
    action: ButtonActions,
    time: CurrMax,
}

// Axis value + moving flag
Axis :: struct {
    using _ : vec2f,
    isMoving : bool,
}

Cmp_Controller :: struct
{
    type : InputType,
    buttons : [ButtonType]Button,
    left_axis : Axis,
    right_axis : Axis,
}

g_controller : Cmp_Controller


//----------------------------------------------------------------------------\\
// /Procs
//----------------------------------------------------------------------------\\
// Helper function matching C++ handle_button logic
handle_button :: proc(button: ^Button, dt: f32) {
    if is_key_just_pressed(button.key){
        button.time.curr = 0
        button.action = {.JustPressed, .Pressed}
        button.val = 1
    }
    else if is_key_pressed(button.key){
        button.action -= {.JustPressed}
        button.time.curr += dt
        if button.time.curr >= button.time.max do button.action += {.Held}
    }
    else if is_key_just_released(button.key){
        button.time.curr = 0
        button.val = 0
        button.action = {.JustReleased, .Released}
    }
    else {
        button.action -= {.JustReleased}
        button.time.curr += dt
    }
}

// Helper function matching C++ handle_epsilon for deadzone handling
handle_epsilon :: proc(val: f32) -> f32 {
    return val * math.ceil(abs(val) - 0.05)
}

handle_keyboard :: proc(kb : ^Cmp_Controller, dt: f32) {
    for &b in kb.buttons{
        handle_button(&b, dt)
    }
    kb.left_axis = {
        {f32(-kb.buttons[.PadL].val + kb.buttons[.PadR].val),
        f32(-kb.buttons[.PadD].val + kb.buttons[.PadU].val)},
        false
    }
    kb.left_axis.isMoving = !((kb.left_axis.x * kb.left_axis.x + kb.left_axis.y * kb.left_axis.y) == 0)
}

