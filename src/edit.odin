package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "vendor:glfw"
import "axiom"
import "core:container/queue"

//----------------------------------------------------------------------------\\
// /UI - Edit Mode
//----------------------------------------------------------------------------\\
edit_mode: bool = false
selected_ui_index: int = 0
// New separate function in gameplay.odin
// F1 - Enter/Exit Edit Mode
// Tab - Select UI Index
// CTRL + 5 - Save (not CTRL+S)
// WASD - Base movement for adjustments
// No modifier - Adjust min position
// CTRL - Adjust align_min
// SHIFT - Adjust extents
// ALT - Adjust align_extents
// +/- - Adjust alpha
handle_ui_edit_mode :: proc() {
    // Toggle edit mode
    if is_key_just_pressed(glfw.KEY_F1) {  // Or any special key
        edit_mode = !edit_mode
        if edit_mode {
            fmt.println("Entered UI Edit Mode")
            // Make all UIs visible on enter
            for key in g.ui_keys {
                ent := g_gui[key]
                gc := get_component(ent, Cmp_Gui)
                if gc != nil {
                    gc.alpha = 1.0
                    gc.update = true
                    axiom.update_gui(gc)
                }
            }
        } else {
            fmt.println("Exited UI Edit Mode")
            // Restore defaults on exit
            for key in g.ui_keys {
                ent := g_gui[key]
                gc := get_component(ent, Cmp_Gui)
                if gc != nil {
                    gc.alpha = 0.0  // Or restore original
                    gc.update = false
                    axiom.update_gui(gc)
                }
            }
        }
    }

    if !edit_mode {
        return
    }

    // Cycle through UIs
    if is_key_just_pressed(glfw.KEY_TAB) {
        selected_ui_index = (selected_ui_index + 1) % len(g.ui_keys)
        selected_key := g.ui_keys[selected_ui_index]
        fmt.printf("Selected UI: %s\n", selected_key)
    }

    // Tweak the selected UI
    if len(g.ui_keys) > 0 {
        selected_key := g.ui_keys[selected_ui_index]
        selected_ent := g_gui[selected_key]
        tweak_game_UI(selected_ent)

        // Ensure selected is visible/editable
        gc := get_component(selected_ent, Cmp_Gui)
        if gc != nil {
            gc.alpha = 1.0
            gc.update = true
            axiom.update_gui(gc)
        }
    }

    // Save selected UI to JSON (CTRL+S)
    if is_key_pressed(glfw.KEY_LEFT_CONTROL) && is_key_just_pressed(glfw.KEY_5) {
        if len(g.ui_keys) > 0 {
            selected_key := g.ui_keys[selected_ui_index]
            selected_ent := g_gui[selected_key]
            filename := fmt.tprintf("assets/prefabs/ui/%s.json", selected_key)
            axiom.save_ui_prefab(selected_ent, filename)
            fmt.printf("Saved UI prefab: %s\n", filename)
        }
    }
}

tweak_game_UI :: proc(e : Entity) {
    ui := get_component(e, Cmp_Gui)
    if ui == nil {
        fmt.println("nope")
        return
    }

    adjust_speed: f32 = 0.01  // Common adjustment increment

    // Base keys: WASD for movement/adjustment
    dx: f32 = 0
    dy: f32 = 0
    if is_key_pressed(glfw.KEY_D) { dx += adjust_speed }
    if is_key_pressed(glfw.KEY_A) { dx -= adjust_speed }
    if is_key_pressed(glfw.KEY_W) { dy += adjust_speed }
    if is_key_pressed(glfw.KEY_S) { dy -= adjust_speed }

    // No modifier: Adjust align_min
    if !is_key_pressed(glfw.KEY_LEFT_CONTROL) &&
       !is_key_pressed(glfw.KEY_LEFT_SHIFT) &&
       !is_key_pressed(glfw.KEY_LEFT_ALT) {
        ui.min.x += dx
        ui.min.y += dy
    }
    else if is_key_pressed(glfw.KEY_LEFT_CONTROL) {
        ui.align_min.x += dx
        ui.align_min.y += dy
    }
    else if is_key_pressed(glfw.KEY_LEFT_SHIFT) {
        ui.extents.x += dx
        ui.extents.y += dy
    }
    else if is_key_pressed(glfw.KEY_LEFT_ALT) {
        ui.align_ext.x += dx
        ui.align_ext.y += dy
    }

    // Optional: Add more, e.g., for alpha: use +/- keys
    if is_key_pressed(glfw.KEY_EQUAL) {  // + key
        ui.alpha = math.clamp(ui.alpha + 0.05, 0.0, 1.0)
    }
    if is_key_pressed(glfw.KEY_MINUS) {
        ui.alpha = math.clamp(ui.alpha - 0.05, 0.0, 1.0)
    }

    // Apply changes
    axiom.update_gui(ui)
}


chest_mode := false
// chest_index := 0
// selected_chest : Entity
// handle_chest_mode :: proc()
// {
//     if is_key_just_pressed(glfw.KEY_F2) {  // Or any special key
//         chest_mode = !chest_mode
//         if chest_mode do fmt.println("Entered Chest Edit Mode")
//         else do fmt.println("Exited Chest Edit Mode")
//     }
//     if !chest_mode do return

//     if is_key_just_pressed(glfw.KEY_TAB) {
//         chest_index = (chest_index + 1) % len(g.battle.chests)
//         selected_chest = g.battle.chests[chest_index]
//         fmt.printf("Selected Chest: %d\n", chest_index)
//     }
//     tc := get_component(selected_chest, Cmp_Transform)
//     if tc == nil do return
//     move_speed: f32 = 0.1  // Common adjustment increment
//     if is_key_pressed(glfw.KEY_W) do tc.local.pos.z += move_speed
//     if is_key_pressed(glfw.KEY_S) do tc.local.pos.z -= move_speed
//     if is_key_pressed(glfw.KEY_A) do tc.local.pos.x -= move_speed
//     if is_key_pressed(glfw.KEY_D) do tc.local.pos.x += move_speed
//     if is_key_pressed(glfw.KEY_SPACE) do tc.local.pos.y += move_speed
//     if is_key_pressed(glfw.KEY_LEFT_SHIFT) do tc.local.pos.y -= move_speed

//     fmt.println("Chest Position :", tc.local.pos)
// }

player_edit_mode: bool = false
selected_player_part_index: int = 0
handle_player_edit_mode :: proc() {
    if is_key_just_pressed(glfw.KEY_F3) {
        player_edit_mode = !player_edit_mode
        if player_edit_mode do fmt.println("Entered Player Edit Mode")
        else do fmt.println("Exited Player Edit Mode")
    }
    if !player_edit_mode do return
    bfg := get_component(g.battle.player.entity, Cmp_BFGraph)
    if bfg == nil do return
    if is_key_just_pressed(glfw.KEY_TAB) {
        selected_player_part_index = (selected_player_part_index + 1) % int(bfg.len)
        selected_part := bfg.nodes[selected_player_part_index]
        nc := get_component(selected_part, Cmp_Node)
        fmt.printf("Selected Player Part: %s (%d)\n", nc.name if nc != nil else "Unnamed", selected_player_part_index)
    }
    selected_part := bfg.nodes[selected_player_part_index]
    tc := get_component(selected_part, Cmp_Transform)
    if tc == nil do return
    adjust_speed: f32 = 0.1  // For position and scale adjustments
    rot_speed: f32 = 5.0     // Degrees for rotation adjustments
    mode: string
    if is_key_pressed(glfw.KEY_LEFT_CONTROL) {
        // Scale mode
        mode = "Scale"
        if is_key_pressed(glfw.KEY_A) do tc.local.sca.x -= adjust_speed
        if is_key_pressed(glfw.KEY_D) do tc.local.sca.x += adjust_speed
        if is_key_pressed(glfw.KEY_W) do tc.local.sca.y += adjust_speed
        if is_key_pressed(glfw.KEY_S) do tc.local.sca.y -= adjust_speed
        if is_key_pressed(glfw.KEY_Q) do tc.local.sca.z -= adjust_speed
        if is_key_pressed(glfw.KEY_E) do tc.local.sca.z += adjust_speed
    }
    else if is_key_pressed(glfw.KEY_LEFT_ALT) {
        // Rotation mode
        mode = "Rotation"
        delta_rot := vec3{0,0,0}
        if is_key_pressed(glfw.KEY_A) do delta_rot.y -= rot_speed
        if is_key_pressed(glfw.KEY_D) do delta_rot.y += rot_speed
        if is_key_pressed(glfw.KEY_W) do delta_rot.x += rot_speed
        if is_key_pressed(glfw.KEY_S) do delta_rot.x -= rot_speed
        if is_key_pressed(glfw.KEY_Q) do delta_rot.z -= rot_speed
        if is_key_pressed(glfw.KEY_E) do delta_rot.z += rot_speed
        if delta_rot != {0,0,0} {
            tc.euler_rotation += delta_rot
            tc.local.rot = linalg.quaternion_from_euler_angles_f32(
                math.to_radians(tc.euler_rotation.x),
                math.to_radians(tc.euler_rotation.y),
                math.to_radians(tc.euler_rotation.z),
                .XYZ)
        }
    }
    else {
    // Position mode
        mode = "Position"
        if is_key_pressed(glfw.KEY_A) do tc.local.pos.x -= adjust_speed
        if is_key_pressed(glfw.KEY_D) do tc.local.pos.x += adjust_speed
        if is_key_pressed(glfw.KEY_W) do tc.local.pos.z += adjust_speed
        if is_key_pressed(glfw.KEY_S) do tc.local.pos.z -= adjust_speed
        if is_key_pressed(glfw.KEY_SPACE) do tc.local.pos.y += adjust_speed
        if is_key_pressed(glfw.KEY_LEFT_SHIFT) do tc.local.pos.y -= adjust_speed
    }
    // Print current values for feedback
    fmt.printf("%s - Pos: %v, Rot (Euler): %v, Sca: %v\n",
        mode,
        tc.local.pos.xyz,
        tc.euler_rotation,
        tc.local.sca.xyz)
}

destroy_mode := false
selected_destroy : Entity
grid_pos_x :i16= 3
grid_pos_y :i16= 3
handle_destroy_mode :: proc()
{
    if is_key_just_pressed(glfw.KEY_F4) {  // Or any special key
        destroy_mode = !destroy_mode
        if destroy_mode do fmt.println("Entered Destroy Edit Mode")
        else do fmt.println("Exited Destroy Edit Mode")
    }
    if !destroy_mode do return

    if is_key_just_pressed(glfw.KEY_SPACE) {
        set_game_over()
        // for b in g.battle.bees {
        // vc := get_component(b.entity, Cmp_Visual)
        // if vc != nil do destroy_visuals(vc)
        // delete_parent_node(b.entity)
        // }

        // selected_destroy = load_prefab("Froku")
        // set_entity_on_tile(g.floor, selected_destroy, g.battle, grid_pos_x, grid_pos_y)
        // fmt.printf("Placed %s at (%d, %d)\n", selected_destroy, grid_pos_x, grid_pos_y)
    }

    if is_key_just_pressed(glfw.KEY_LEFT_ALT) {
	   	set_game_victory()
    }

    if is_key_just_pressed(glfw.KEY_ENTER)
    {
        set_game_start()
        fc := get_component(g.floor, Cmp_Node)
        fp := get_component(g.floor, Cmp_Primitive)
        ft := get_component(g.floor, Cmp_Primitive)
        fmt.println("Floor: ", fc.name, " T: ", ft.world, " P: ", fp.extents)

        // delete_parent_node(selected_destroy)
        // child := get_component(selected_destroy,Cmp_Node).child
        // child_node := get_component(child,Cmp_Node)
        // child = child_node.child
        // bpc := get_component(child, Cmp_Primitive)
        // if bpc != nil do fmt.println("Primitive Component: ", bpc, "has not been deleted")
        // remove_entity(selected_destroy)
        // fmt.printf("Destroyed %s at (%d, %d)\n", selected_destroy, grid_pos_x, grid_pos_y)
        // pc := get_component(child, Cmp_Primitive)
        // if pc != nil do fmt.println("Primitive Component: ", pc, "has not been deleted")
        // else do fmt.println("Primitive Component: ", bpc, "has been deleted")
        // selected_destroy = 0
        // remove_entity(child)
        // pc = get_component(child, Cmp_Primitive)
        // if pc != nil do fmt.println("Primitive Component: ", pc, "has not been deleted")
        // else do fmt.println("CONTGRATS ITS GONE")
    }

    if is_key_just_pressed(glfw.KEY_A) do g.battle.player.health = 0
    if is_key_just_pressed(glfw.KEY_D) do grid_pos_x += 1
    if is_key_just_pressed(glfw.KEY_W) do grid_pos_y += 1
    if is_key_just_pressed(glfw.KEY_S) do grid_pos_y -= 1
}

battle_cheat_mode: bool = false
handle_battle_cheat_mode :: proc()
{
    if is_key_just_pressed(glfw.KEY_F2) {  // Or any special key
        battle_cheat_mode = !battle_cheat_mode
        if battle_cheat_mode do fmt.println("Entered Battle Cheat Edit Mode")
        else do fmt.println("Exited Battle Cheat Edit Mode")
    }
    if !battle_cheat_mode do return

    // WASD controls for grid texture
    cell_speed :: 0.1
    line_speed :: 0.02
    if is_key_pressed(glfw.KEY_W) {
        g.battle.grid.texture.cell_size += cell_speed
        grid_texture_sync_to_gpu(&g.battle.grid.texture)
        data_texture_update()
        fmt.printf("cell_size: %.3f\n", g.battle.grid.texture.cell_size)
    }
    if is_key_pressed(glfw.KEY_S) {
        g.battle.grid.texture.cell_size = max(0.1, g.battle.grid.texture.cell_size - cell_speed)
        grid_texture_sync_to_gpu(&g.battle.grid.texture)
        data_texture_update()
        fmt.printf("cell_size: %.3f\n", g.battle.grid.texture.cell_size)
    }
    if is_key_pressed(glfw.KEY_D) {
        g.battle.grid.texture.line_thickness += line_speed
        grid_texture_sync_to_gpu(&g.battle.grid.texture)
        data_texture_update()
        fmt.printf("line_thickness: %.3f\n", g.battle.grid.texture.line_thickness)
    }
    if is_key_pressed(glfw.KEY_A) {
        g.battle.grid.texture.line_thickness = max(0.001, g.battle.grid.texture.line_thickness - line_speed)
        grid_texture_sync_to_gpu(&g.battle.grid.texture)
        data_texture_update()
        fmt.printf("line_thickness: %.3f\n", g.battle.grid.texture.line_thickness)
    }

    if is_key_just_pressed(glfw.KEY_SPACE) {
        // g.ves.curr_screen = .None
        // g.battle.input_state = .Attacking
        // g.ves.attack_state = .Start
        ev := VisualEvent{type = .DodgeQTE, state = .Pending, character = &g.battle.bees[0].variant}
        queue.push(&g.ves.event_queue, ev)
    }
}
