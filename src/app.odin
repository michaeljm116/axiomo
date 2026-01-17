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
    Overworld
}

app_start :: proc() {
    ax.g_world = create_world()
    sys_visual_init(g.mem_game.alloc)
    load_scene("Empty")

    g.app_state = .TitleScreen
    init_game_ui(&g_gui, g_mem_core.alloc)
    ToggleUI("Title", true)
}

app_restart :: proc(){
    destroy_world()
    create_world()

    sys_visual_init(g.mem_game.alloc)
    init_game_ui(&g_gui, g_mem_core.alloc)
}

// Cleanup
app_destroy :: proc() {
    defer destroy_world()
    // Reset callbacks
    glfw.SetKeyCallback(ax.g_window.handle, nil)
    glfw.SetCursorPosCallback(ax.g_window.handle, nil)
    glfw.SetMouseButtonCallback(ax.g_window.handle, nil)

    // Release mouse cursor
    glfw.SetInputMode(ax.g_window.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
}

app_post_init :: proc(){
    // chest := g.battle.chests[0]
    // chest2 := g.battle.chests[1]
    // move_entity_to_tile(chest, g.battle.grid_scale, vec2{2,0})
    // move_entity_to_tile(chest2, g.battle.grid_scale, vec2{4,3})
}

// Update input state and camera
app_update :: proc(delta_time: f32) {
    if !ax.entity_exists(g.camera_entity) do find_camera_entity()
    if !ax.entity_exists(g.player) do find_player_entity()

    // handle_ui_edit_mode()
    // handle_player_edit_mode()
    handle_destroy_mode()
    if !edit_mode && !chest_mode && !player_edit_mode && !destroy_mode{
       app_run(delta_time, &g.app_state)
    }
    // Clear just pressed/released states
    for i in 0..<len(ax.g_input.keys_just_pressed) {
        ax.g_input.keys_just_pressed[i] = false
        ax.g_input.keys_just_released[i] = false
    }

        // Update light orbit (if a light entity was found)
    // update_light_orbit(delta_time)

    //update_camera_movement(delta_time)
    //update_player_movement(delta_time)
    // update_movables(delta_time)
    // update_physics(delta_time)
}

app_run :: proc(dt: f32, state: ^AppState) {
	// if glfw.WindowShouldClose() do return
	switch state^ {
	case .TitleScreen:
    	if is_key_just_pressed(glfw.KEY_ENTER){
            state^ = .MainMenu
            ToggleMenuUI(state)
        }
	case .MainMenu:
    	if is_key_just_pressed(glfw.KEY_ENTER){
            app_restart()
            state^ = .Game
            ToggleMenuUI(state)
            battle_start()
            start_game()
        }
        else if is_key_just_pressed(glfw.KEY_SPACE){
            app_restart()
            state^ = .Overworld
            ToggleMenuUI(state)
            overworld_start()
        }
	case .Game:
		run_battle(&g.battle, &g.ves)
		ves_update_all(dt)
		if (g.battle.player.health <= 0){
			state^ = .GameOver
            destroy_level1()
			ToggleMenuUI(state)
		}
	    else if (len(g.battle.bees) <= 0){
    		state^ = .Victory
            destroy_level1()
            ToggleMenuUI(state)
		}
        else if (is_key_just_pressed(glfw.KEY_P)){
            state^ = .Pause
            ToggleMenuUI(state)
        }
        ves_cleanup(&g.battle)
	case .Pause:
        if is_key_just_pressed(glfw.KEY_ENTER){
            state^ = .Game
            ToggleMenuUI(state)
        }
	case .GameOver, .Victory:
    	if is_key_just_pressed(glfw.KEY_ENTER){
            state^ = .MainMenu
            ToggleMenuUI(state)
        }
	case .Overworld:
	   overworld_update(dt)
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
init_game_ui :: proc(game_ui : ^map[string]Entity, alloc : mem.Allocator){
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
    case .Game, .Overworld:
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
