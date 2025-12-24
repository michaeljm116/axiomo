package game_tests

import "core:testing"
import "core:fmt"
import "vendor:glfw"
import "core:container/queue"
import game".."
import ax"../axiom"
vec2 :: game.vec2i

// Helper to clear input state between tests
clear_input :: proc() {
    for i in 0..<len(ax.g_input.keys_just_pressed) {
        ax.g_input.keys_just_pressed[i] = false
        ax.g_input.keys_pressed[i] = false
        ax.g_input.keys_just_released[i] = false
    }
    for i in 0..<len(ax.g_input.mouse_buttons) {
        ax.g_input.mouse_buttons[i] = false
    }
}

// Ensure level is initialized in a known state for each test.
// Uses existing helper from bks.odin
setup_level :: proc() {
    // start_level1 will set game.g.battle, player, bees, deck, etc.
    game.g = new(game.Game_Memory)
    game.g.state = .PlayerTurn
    game.start_level1(&game.g.battle,game.g.mem_game.alloc)
}

// ---------------------------
// Player Turn State Machine
// ---------------------------
@(test)
test_run_players_turn_movement_flow :: proc(t: ^testing.T) {
    setup_level()

    // Use local state variables (game.run_players_turn expects pointers)
    pt := game.PlayerInputState.SelectAction
    gs := game.GameState.PlayerTurn
    bee_sel := 0
    bee_near_local := false

    // Press '1' to enter Movement state
    clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_1] = true
    game.run_players_turn(&pt, &gs, &game.g.battle.player, &game.g.battle.bees, &bee_sel, &bee_near_local)
    testing.expect(t, pt == .Movement, "Pressing KEY_1 from SelectAction should transition to Movement")

    // Now simulate a movement input (D) to move player to the right
    clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true

    prev_pos := game.g.battle.player.pos
    game.run_players_turn(&pt, &gs, &game.g.battle.player, &game.g.battle.bees, &bee_sel, &bee_near_local)

    // After a successful move, player turn state should return to SelectAction and game state -> BeesTurn
    moved_right := game.g.battle.player.pos.x == prev_pos.x + 1
    testing.expect(t, pt == .SelectAction, "After moving, player turn state should return to SelectAction")
    testing.expect(t, gs == .BeesTurn, "After moving, global game state should be set to BeesTurn")
    testing.expect(t, moved_right, "Player X position should increment when pressing 'd' in Movement state")
}

// @(test)
// test_run_players_turn_enemy_selection_and_focus :: proc(t: ^testing.T) {
//     setup_level()

//     pt := game.PlayerInputState.SelectAction
//     gs := game.GameState.PlayerTurn
//     bee_sel := -1
//     bee_near_local := false

//     // Press '2' to enter SelectEnemy
//     clear_input()
//     ax.g_input.keys_just_pressed[glfw.KEY_2] = true
//     game.run_players_turn(&pt, &gs, &game.g.battle.player, &game.g.battle.bees, &bee_sel, &bee_near_local)

//     testing.expect(t, pt == .SelectEnemy, "Pressing KEY_2 should transition to SelectEnemy")
//     testing.expect(t, bee_sel == 0, "Selecting enemy should reset selection to 0")
//     testing.expect(t, bee_near_local == false, "Initial g.bee_is_near should be false after selecting enemy")

//     // Press SPACE to attempt action selection (player not near the bee in start_level1)
//     clear_input()
//     ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
//     game.run_players_turn(&pt, &gs, &game.g.battle.player, &game.g.battle.bees, &bee_sel, &bee_near_local)

//     testing.expect(t, pt == .Action, "Pressing SPACE in SelectEnemy should transition to Action")
//     testing.expect(t, bee_near_local == false, "g.bee_is_near should reflect actual proximity (start_level1 bees are far)")

//     // Press 'F' to apply Focus ability/flag to the selected bee
//     clear_input()
//     ax.g_input.keys_just_pressed[glfw.KEY_F] = true
//     game.run_players_turn(&pt, &gs, &game.g.battle.player, &game.g.battle.bees, &bee_sel, &bee_near_local)

//     // After focusing: selected bee should have PlayerFocused flag, state returns to SelectAction and game state -> BeesTurn
//     testing.expect(t, pt == .SelectAction, "After applying Focus, state should return to SelectAction")
//     testing.expect(t, gs == .BeesTurn, "After applying Focus, game state should transition to BeesTurn")
//     testing.expect(t, .PlayerFocused in game.g.battle.bees[0].flags, "Bee 0 should have PlayerFocused flag after pressing 'F'")
// }

// @(test)
// test_handle_back_button_transitions :: proc(t: ^testing.T) {
//     // Movement -> back should go to SelectAction
//     st := game.PlayerInputState.Movement
//     clear_input()
//     ax.g_input.keys_just_pressed[glfw.KEY_B] = true
//     game.handle_back_button(&st)
//     testing.expect(t, st == .SelectAction, "B from Movement should go back to SelectAction")

//     // SelectEnemy -> back should go to SelectAction
//     st = game.PlayerInputState.SelectEnemy
//     clear_input()
//     ax.g_input.keys_just_pressed[glfw.KEY_B] = true
//     game.handle_back_button(&st)
//     testing.expect(t, st == .SelectAction, "B from SelectEnemy should go back to SelectAction")

//     // Action -> back should go to SelectEnemy
//     st = game.PlayerInputState.Action
//     clear_input()
//     ax.g_input.keys_just_pressed[glfw.KEY_B] = true
//     game.handle_back_button(&st)
//     testing.expect(t, st == .SelectEnemy, "B from Action should go back to SelectEnemy")
// }

// // ---------------------------
// // Bee Turn State Machine
// // ---------------------------

// @(test)
// test_perform_bee_sting_reduces_player_health :: proc(t: ^testing.T) {
//     setup_level()

//     // Place player and a bee adjacent so sting should apply
//     game.g.battle.player.pos = vec2{0, 0}
//     game.g.battle.player.health = 5

//     // Ensure there's at least one bee
//     testing.expect(t, len(game.g.battle.bees) > 0, "Level should have at least one bee for this test")

//     b := &game.g.battle.bees[0]
//     b.pos = vec2{0, 1} // adjacent
//     b.flags ~= {}      // clear flags

//     prev_hp := game.g.battle.player.health
//     // bee_action_select(.Sting, b, &game.g.battle.player)

//     testing.expect(t, game.g.battle.player.health == prev_hp - 1, "Sting action should reduce player health by 1 when player not dodging")
// }

// @(test)
// test_bee_turn_draws_from_deck_and_performs_action :: proc(t: ^testing.T) {
//     setup_level()

//     // Prepare a deterministic game.BeeDeck with known top card = Sting
//     bd : game.BeeDeck
//     queue.init(&bd.deck, 4)
//     queue.init(&bd.discard, 4)
//     // Push items so the front will be Sting
//     // push_front(FlyAway) then push_front(Sting) -> front == Sting
//     queue.push_front(&bd.deck, game.BeeAction.FlyAway)
//     queue.push_front(&bd.deck, game.BeeAction.Sting)

//     // Place player and bee adjacent so Sting will hit
//     game.g.battle.player.pos = vec2{2, 2}
//     game.g.battle.player.health = 4

//     // Ensure we have at least one bee and make it Normal so bee_turn draws 1 card
//     testing.expect(t, len(game.g.battle.bees) > 0, "Level should have bees for this test")
//     b := &game.g.battle.bees[0]
//     b.pos = vec2{2, 3} // adjacent
//     b.type = .Normal
//     b.flags ~= {}

//     prev_hp := game.g.battle.player.health
//     // run_bee_turn(b, &bd)

//     testing.expect(t, game.g.battle.player.health < prev_hp, "bee_turn with Sting drawn should reduce player health")
// }
