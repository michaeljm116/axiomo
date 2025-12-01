package game

import "core:fmt"
import "core:mem"
import "core:math"
import "vendor:glfw"
import ax"axiom"
import "axiom/resource"
import "core:log"

//----------------------------------------------------------------------------\\
// /APP - Things needed globally
//----------------------------------------------------------------------------\\
AppState :: enum{
    TitleScreen,
    MainMenu,
    Game,
    Pause,
    GameOver,
    Victory,

}

// Initialize the gameplay system
app_init :: proc() {
    // Set up GLFW callbacks
    glfw.SetKeyCallback(ax.g_renderbase.window, key_callback)
    glfw.SetCursorPosCallback(ax.g_renderbase.window, mouse_callback)
    glfw.SetMouseButtonCallback(ax.g_renderbase.window, mouse_button_callback)
    glfw.SetInputMode(ax.g_renderbase.window, glfw.CURSOR, glfw.CURSOR_DISABLED)
    //setup_physics()
    app_start()
    sys_visual_init(g.mem_game.alloc)
}

app_start :: proc() {
    ax.g_world = create_world()
    add_component(ax.g_world.entity, Cmp_Node{name = "Singleton"})
    ax.tag(ax.tag_root, ax.g_world.entity)
    g.scene = set_new_scene("assets/scenes/Entrance.json")
    // g.scene = set_new_scene("assets/scenes/BeeKillingsInn2.json")
	ax.load_scene(g.scene^, g.mem_game.alloc)
	g.player = ax.load_prefab("Froku", g.mem_game.alloc)
	g.app_state = .MainMenu
    g.input = InputState{
        mouse_sensitivity = 0.1,
        movement_speed = 5.0,
        rotation_speed = 20.0,
        first_mouse = true,
    }

    // Find the camera entity
    find_camera_entity()
    find_light_entity()
    find_player_entity()
    face_left(g.player)

    ////////////////// actual bks init ////////////////
    battle_start()
}

app_restart :: proc(){
    // g.scene = set_new_scene("assets/scenes/BeeKillingsInn.json")
    g.scene = set_new_scene("assets/scenes/Entrance.json")
    restart_world()
    app_start()
}

// Cleanup
app_destroy :: proc() {
    defer destroy_world()
    // Reset callbacks
    glfw.SetKeyCallback(ax.g_renderbase.window, nil)
    glfw.SetCursorPosCallback(ax.g_renderbase.window, nil)
    glfw.SetMouseButtonCallback(ax.g_renderbase.window, nil)

    // Release mouse cursor
    glfw.SetInputMode(ax.g_renderbase.window, glfw.CURSOR, glfw.CURSOR_NORMAL)
}

app_post_init :: proc(){
    // chest := g.level.chests[0]
    // chest2 := g.level.chests[1]
    // move_entity_to_tile(chest, g.level.grid_scale, vec2{2,0})
    // move_entity_to_tile(chest2, g.level.grid_scale, vec2{4,3})
}

// Update input state and camera
app_update :: proc(delta_time: f32) {
    if !ax.entity_exists(g.camera_entity) do find_camera_entity()
    if !ax.entity_exists(g.player) do find_player_entity()

    // handle_ui_edit_mode()
    // handle_player_edit_mode()
    handle_destroy_mode()
    if !edit_mode && !chest_mode && !player_edit_mode && !destroy_mode{
       battle_run(delta_time, &g.app_state)
    }
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

//----------------------------------------------------------------------------\\
// /Input
//----------------------------------------------------------------------------\\
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

is_key_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST do return false
    return g.input.keys_pressed[key]
}
is_key_just_pressed :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST do return false
    return g.input.keys_just_pressed[key]
}
is_key_just_released :: proc(key: i32) -> bool {
    if key < 0 || key > glfw.KEY_LAST do return false
    return g.input.keys_just_released[key]
}
is_mouse_button_pressed :: proc(button: i32) -> bool {
    if button < 0 || button > glfw.MOUSE_BUTTON_LAST do return false
    return g.input.mouse_buttons[button]
}

// GLFW Callbacks
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = ax.g_renderbase.ctx
    if key < 0 || key > glfw.KEY_LAST do return

    switch action {
    case glfw.PRESS:
        if !g.input.keys_pressed[key] do g.input.keys_just_pressed[key] = true
        g.input.keys_pressed[key] = true
    case glfw.RELEASE:
        g.input.keys_just_released[key] = true
        g.input.keys_pressed[key] = false
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
            g.input.first_mouse = true
        }
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = ax.g_renderbase.ctx

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
    context = ax.g_renderbase.ctx

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

//----------------------------------------------------------------------------\\
// /Menu
//----------------------------------------------------------------------------\\
MenuAnimation :: struct{
    timer : f32,
    duration : f32,
}

MenuAnimStatus :: enum{
    Running,
    Finished
}

menu_show_title :: proc()
{
   g.title = g_gui["Title"]
   gc := get_component(g.title, Cmp_Gui)
   gc.alpha = 0.0
   g.titleAnim = MenuAnimation{timer = 0.0, duration = 1.0}
   gc.min = 0.0
   gc.extents = 1.0
}

menu_show_main :: proc()
{
    g.main_menu = g_gui["MainMenu"]
    gc := get_component(g.main_menu, Cmp_Gui)
    gc.alpha = 0.0
    g.main_menuAnim = MenuAnimation{timer = 0.0, duration = 1.0}
    gc.min = 0.0
    gc.extents = 1.0
}

ToggleMenuItem :: proc(entity : Entity, on : bool){
    c := get_component(entity, Cmp_Gui)
    c.alpha = on ? 1.0 : 0.0
    c.update = on ? true : false
}

menu_run_title :: proc(dt : f32, state : ^AppState){
    if is_key_just_pressed(glfw.KEY_ENTER){
        state^ = .MainMenu
    }
}

// menu_run_main :: proc(dt : f32, state : ^AppState)
// {
//     if is_key_just_pressed(glfw.KEY_ENTER) do state^ = .Game
//     // Wait for player to press enter, if so then start the anim and go to GameState
//     if game_started{
//         if menu_run_anim(g.main_menu, &g.main_menuAnim, dt) == .Finished{
//             battle_start()
//             state^ = .Game
//             return
//         }
//     }
// }

menu_run_anim_fade_in :: proc(entity : Entity, anim : ^MenuAnimation, dt : f32) -> MenuAnimStatus
{
    gc := get_component(entity, Cmp_Gui)
    if anim.timer >= anim.duration
    {
        anim.timer = 0.0
        gc.alpha = 1.0
        return .Finished

    }
    anim.timer += dt
    gc.alpha = math.smoothstep(f32(0.0), 1.0, anim.timer / anim.duration)
    return .Running
}

menu_run_anim_fade_out :: proc(entity : Entity, anim : ^MenuAnimation, dt : f32) -> MenuAnimStatus
{
    gc := get_component(entity, Cmp_Gui)
    if anim.timer >= anim.duration
    {
        anim.timer = 0.0
        gc.alpha = 0.0
        return .Finished
    }
    anim.timer += dt
    gc.alpha = math.smoothstep(f32(1.0), 0.0, anim.timer / anim.duration)
    return .Running
}

//----------------------------------------------------------------------------\\
// /UI
//----------------------------------------------------------------------------\\
g_gui  : map[string]Entity
init_GameUI :: proc(game_ui : ^map[string]Entity, alloc : mem.Allocator){
    g.ui_keys = make([dynamic]string, 0, len(resource.ui_prefabs), alloc)
    g_gui = make(map[string]Entity, alloc)
    for key,ui in resource.ui_prefabs{
        cmp := ax.map_gui(ui.gui)
        cmp.alpha = 0.0
        cmp.update = true
        e := ax.add_ui(cmp, key)

        game_ui[key] = e
        append(&g.ui_keys, key)
    }
}

ToggleUI :: proc(name : string, on : bool)
{
    gc := get_component(g_gui[name], Cmp_Gui)
    gc.alpha = on ? 1.0 : 0.0
    gc.update = on
    update_gui(gc)
}

ToggleMenuUI :: proc(state : ^AppState)
{
    switch state^
    {
    case .TitleScreen:
        ToggleUI("Title", true)
    case .MainMenu:
        ToggleUI("Title", true)
        // ToggleUI("BeeKillinsInn", true)
        ToggleUI("Background", true)
        ToggleUI("StartGame", true)
        ToggleUI ("GameOver", false)
        ToggleUI("Victory", false)
        ToggleUI("Paused", false)
    case .Game:
        ToggleUI("Title", false)
        ToggleUI("Background", false)
        ToggleUI("StartGame", false)
        ToggleUI("Paused", false)
    case .Pause:
        ToggleUI("Paused", true)
    case .GameOver:
        ToggleUI ("GameOver", true)
    case .Victory:
        ToggleUI("Victory", true)
    }
}
