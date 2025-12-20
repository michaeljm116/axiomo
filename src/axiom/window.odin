package axiom

import "vendor:glfw"
import "core:c"
import "core:log"
import "base:runtime"

//----------------------------------------------------------------------------\\
// /Window
//----------------------------------------------------------------------------\\
window_init :: proc(ctx : runtime.Context)
{
    engine_ctx := engine_context()
    if !glfw.Init()
    {log.panic("glfw: could not be initialized")}

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
    glfw.WindowHint(glfw.DECORATED, glfw.TRUE)

    // Get monitor and set to full screen
    engine_ctx.window.ctx = ctx
    engine_ctx.window.primary_monitor = glfw.GetPrimaryMonitor()
    engine_ctx.window.mode = glfw.GetVideoMode(engine_ctx.window.primary_monitor)
    engine_ctx.window.width = c.int(f64(engine_ctx.window.mode.width) * 0.5)
    engine_ctx.window.height =  c.int(f64(engine_ctx.window.mode.height) * 0.5)
    engine_ctx.window.handle = glfw.CreateWindow(engine_ctx.window.width, engine_ctx.window.height, "Bee Killins Inn", nil, nil)
}

window_renderer_init :: proc()
{
    engine_ctx := engine_context()
    glfw.SetFramebufferSizeCallback(engine_ctx.window.handle, proc "c" (_: glfw.WindowHandle, _, _: i32)
        {
        engine_ctx.renderbase.framebuffer_resized = true
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

window_input_init :: proc()
{
    engine_ctx := engine_context()
    glfw.SetKeyCallback(engine_ctx.window.handle, key_callback)
    glfw.SetCursorPosCallback(engine_ctx.window.handle, mouse_callback)
    glfw.SetMouseButtonCallback(engine_ctx.window.handle, mouse_button_callback)
    glfw.SetInputMode(engine_ctx.window.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)

    g_input = InputState{
        mouse_sensitivity = 0.1,
        movement_speed = 5.0,
        rotation_speed = 20.0,
        first_mouse = true,
    }
}

is_key_pressed :: proc(key: i32) -> bool
{
    engine_ctx := engine_context()
    if key < 0 || key > glfw.KEY_LAST do return false
    return g_input.keys_pressed[key]
}
is_key_just_pressed :: proc(key: i32) -> bool
{
    engine_ctx := engine_context()
    if key < 0 || key > glfw.KEY_LAST do return false
    return g_input.keys_just_pressed[key]
}
is_key_just_released :: proc(key: i32) -> bool
{
    engine_ctx := engine_context()
    if key < 0 || key > glfw.KEY_LAST do return false
    return g_input.keys_just_released[key]
}
is_mouse_button_pressed :: proc(button: i32) -> bool
{
    engine_ctx := engine_context()
    if button < 0 || button > glfw.MOUSE_BUTTON_LAST do return false
    return g_input.mouse_buttons[button]
}

// GLFW Callbacks
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32)
{
    engine_ctx := engine_context()
    context = engine_ctx.window.ctx
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
    if key == glfw.KEY_ESCAPE && action == glfw.PRESS do glfw.SetWindowShouldClose(window, true)

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

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64)
{
    engine_ctx := engine_context()
    context = engine_ctx.window.ctx

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

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32)
{
    engine_ctx := engine_context()
    context = engine_ctx.window.ctx

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
