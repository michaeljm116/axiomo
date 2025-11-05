package game

import "core:fmt"
import "core:math/linalg"
import "core:bufio"
import "core:os"
import "core:strings"
import "core:slice"
import "core:math"
import "core:math/rand"
import "core:container/queue"
import "core:mem"
import "base:intrinsics"
import "vendor:glfw"
import "core:hash/xxhash"
import xxh2"extensions/xxhash2"

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
//             start_game()
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
