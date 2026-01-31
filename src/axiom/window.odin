package axiom

import "vendor:glfw"
import "core:c"
import "core:log"
import "core:math"
import "base:runtime"

//----------------------------------------------------------------------------\\
// /Window
//----------------------------------------------------------------------------\\
window_init :: proc(ctx : runtime.Context){
    if !glfw.Init() {log.panic("glfw: could not be initialized")}

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
    glfw.WindowHint(glfw.DECORATED, glfw.TRUE)

    // Get monitor and set to full screen
    g_window.ctx = ctx
    g_window.primary_monitor = glfw.GetPrimaryMonitor()
    g_window.mode = glfw.GetVideoMode(g_window.primary_monitor)
    g_window.width = c.int(f64(g_window.mode.width) * 0.5)
    g_window.height =  c.int(f64(g_window.mode.height) * 0.5)
    g_window.handle = glfw.CreateWindow(g_window.width, g_window.height, "Bee Killins Inn", nil, nil)
}

window_renderer_init :: proc(){
    glfw.SetFramebufferSizeCallback(g_window.handle, proc "c" (_: glfw.WindowHandle, _, _: i32) {
        g_renderbase.framebuffer_resized = true
    })
    glfw.SetErrorCallback(glfw_error_callback)
}

//----------------------------------------------------------------------------\\
// /Input
//----------------------------------------------------------------------------\\
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

window_input_init :: proc(){
    glfw.SetKeyCallback(g_window.handle, key_callback)
    glfw.SetCursorPosCallback(g_window.handle, mouse_callback)
    glfw.SetMouseButtonCallback(g_window.handle, mouse_button_callback)
    glfw.SetInputMode(g_window.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)

    g_input = InputState{
        mouse_sensitivity = 0.1,
        movement_speed = 5.0,
        rotation_speed = 20.0,
        first_mouse = true,
    }
}

is_key_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST do return false
    return g_input.keys_pressed[key]
}
is_key_just_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST do return false
    return g_input.keys_just_pressed[key]
}
is_key_just_released :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST do return false
    return g_input.keys_just_released[key]
}
is_mouse_button_pressed :: proc(button: i32) -> bool {
    if button < 0 || button > glfw.MOUSE_BUTTON_LAST do return false
    return g_input.mouse_buttons[button]
}

// GLFW Callbacks
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = g_window.ctx
    if key < 0 || key > glfw.KEY_LAST do return

    switch action {
    case glfw.PRESS:
        if !g_input.keys_pressed[key] do g_input.keys_just_pressed[key] = true
        g_input.keys_pressed[key] = true
    case glfw.RELEASE:
        g_input.keys_just_released[key] = true
        g_input.keys_pressed[key] = false
    case glfw.REPEAT:
        //Repeat Timer ++
    }
    // Handle special keys
    if key == glfw.KEY_GRAVE_ACCENT && action == glfw.PRESS do glfw.SetWindowShouldClose(window, true)

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
    context = g_window.ctx

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
    context = g_window.ctx

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

//----------------------------------------------------------------------------\\
// /Controller
//----------------------------------------------------------------------------\\
ButtonType :: enum
{
   ActionU,
   ActionD,
   ActionL,
   ActionR,

   PadU,
   PadD,
   PadL,
   PadR,

   ShoulderL,
   ShoulderR,
   TriggerL,
   TriggerR,

   MenuL,
   MenuR,

   //Typically a Sprint
   AnalogL,
   AnalogR,
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

InputType :: enum
{
    Keyboard,
    Gamepad,
    Joystick,
    AI,
}

AxisDir :: enum u8 {
    None   = 0,
    Up     = 1 << 0,   // 0001
    Down   = 1 << 1,   // 0010
    Left   = 1 << 2,   // 0100
    Right  = 1 << 3,   // 1000
}

//----------------------------------------------------------------------------\\
// /Structs
//----------------------------------------------------------------------------\\
Button :: struct // 16bytes
{
    key: i32,
    val: i32,
    action: ButtonActions,
    time: CurrMax,
}

// Axis value + moving flag
Axis :: struct {
    using _: vec2f,
    as_int : vec2i,
    isMoving : bool,
    dir : AxisDir,
}

Controller :: struct
{
    type : InputType,
    buttons : [ButtonType]Button,
    left_axis : Axis,
    right_axis : Axis,
}

//----------------------------------------------------------------------------\\
// /Procs
//----------------------------------------------------------------------------\\
controller_handle_button :: proc(button: ^Button, dt: f32) {
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

controller_handle_epsilon :: proc(val: f32) -> f32
{
    return val * math.ceil(abs(val) - 0.05)
}
controller_compute_axis_dir :: proc(axis: ^Axis)
{
    y_bits := (u8(axis.y > 0) << 0) | (u8(axis.y < 0) << 1)
    x_bits := (u8(axis.x > 0) << 3) | (u8(axis.x < 0) << 2)
    axis.dir = transmute(AxisDir)(y_bits | x_bits)
}
controller_handle_keyboard :: proc(kb : ^Controller, dt: f32)
{
    for &b in kb.buttons{
        controller_handle_button(&b, dt)
    }
    kb.left_axis = {
        {f32(-kb.buttons[.PadL].val + kb.buttons[.PadR].val),
        f32(-kb.buttons[.PadD].val + kb.buttons[.PadU].val)},
        {},
        false,
        {}
    }
    kb.left_axis.as_int = {i32(kb.left_axis.x), i32(kb.left_axis.y)}
    kb.left_axis.isMoving = !((kb.left_axis.x * kb.left_axis.x + kb.left_axis.y * kb.left_axis.y) == 0)
    if kb.left_axis.isMoving do controller_compute_axis_dir(&kb.left_axis)
}

controller_init_default_keyboard :: proc(kb : ^Controller)
{
    using kb

    buttons[.PadU].key = glfw.KEY_W
    buttons[.PadD].key = glfw.KEY_S
    buttons[.PadL].key = glfw.KEY_A
    buttons[.PadR].key = glfw.KEY_D

    buttons[.ActionD].key = glfw.KEY_SPACE
    buttons[.ActionU].key = glfw.KEY_E
    buttons[.ActionL].key = glfw.KEY_Q
    buttons[.ActionR].key = glfw.KEY_R

    buttons[.ShoulderL].key = glfw.KEY_LEFT_CONTROL
    buttons[.ShoulderR].key = glfw.KEY_LEFT_ALT
    buttons[.TriggerL].key  = glfw.KEY_LEFT_SHIFT
    buttons[.TriggerR].key  = glfw.KEY_RIGHT_SHIFT

    buttons[.MenuL].key  = glfw.KEY_TAB
    buttons[.MenuR].key  = glfw.KEY_ESCAPE
    buttons[.AnalogL].key = glfw.KEY_1
    buttons[.AnalogR].key = glfw.KEY_2

    for &b in buttons {
        b.val    = 0
        b.action = {.Released}
        b.time.curr = 0
        b.time.max  = 0.4
    }

    // Set initial input type if not already set elsewhere
    kb.type = .Keyboard
    kb.left_axis  = {{0, 0},{},false, {}}
    kb.right_axis = {{0, 0},{},false, {}}
}