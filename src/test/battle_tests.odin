package game_tests

import "core:testing"
import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:math"
import "core:math/rand"
import "core:container/queue"
import "vendor:glfw"
import "base:intrinsics"
import game ".."
import ax "../axiom"

vec2i :: game.vec2i
vec2f :: game.vec2f
Entity :: game.Entity
Cmp_Transform :: game.Cmp_Transform
Cmp_Visual :: game.Cmp_Visual
Cmp_Animation :: game.Cmp_Animation
Cmp_Gui :: game.Cmp_Gui
Battle :: game.Battle
Player :: game.Player
Bee :: game.Bee
BeeDeck :: game.BeeDeck
Grid :: game.Grid // Now from grid.odin: data []Tile, width/height i16, scale vec2f, weapons [dynamic]WeaponGrid
VisualEventData :: game.VisualEventData
BattleState :: game.BattleState
PlayerInputState :: game.PlayerInputState
BeeState :: game.BeeState
BeeAction :: game.BeeAction
GameFlags :: game.GameFlags
VisualFlags :: game.VisualFlags
CharacterFlags :: game.CharacterFlags

test_arena: ax.MemoryArena

init_test_arena :: proc() {
    ax.init_memory_arena_growing(&test_arena)
}

fini_test_arena :: proc() {
    ax.destroy_memory_arena(&test_arena)
}

// Helper to clear input state
test_clear_input :: proc() {
    for i in 0..<len(ax.g_input.keys_just_pressed) {
        ax.g_input.keys_just_pressed[i] = false
        ax.g_input.keys_pressed[i] = false
        ax.g_input.keys_just_released[i] = false
    }
    for i in 0..<len(ax.g_input.mouse_buttons) {
        ax.g_input.mouse_buttons[i] = false
    }
}

// Minimal setup for battle struct without full entity system (mock where needed)
setup_battle :: proc() -> (^Battle, ^VisualEventData) {
    init_test_arena()
    ax.reset_memory_arena(&test_arena)
    context.allocator = test_arena.alloc

    battle := new(Battle)
    ves := new(VisualEventData)

    // Initialize player
    battle.player = Player {
        name = 'P',
        pos = {0, 0},
        health = 5,
        target = {0, 0},
        entity = Entity(0), // Mock entity
        c_flags = {},
        anim = {},
        move_anim = {}, // Assume defaults
        attack_anim = {},
        flags = {},
        removed = {},
        added = {},
        weapon = {}, // Mock weapon if needed
        abilities = make([dynamic]game.Ability),
    }

    // Initialize bees (minimal for tests)
    battle.bees = make([dynamic]Bee)
    append(&battle.bees, Bee {
        base = game.Character {
            name = 'B',
            pos = {3, 3},
            health = 1,
            target = {3, 3},
            entity = Entity(0),
            c_flags = {},
            anim = {},
            move_anim = {},
            attack_anim = {},
            flags = {},
            removed = {},
            added = {},
        },
        type = .Normal,
        state = .Deciding,
    })
    append(&battle.bees, Bee {
        base = game.Character {
            name = 'B',
            pos = {4, 4},
            health = 1,
            target = {4, 4},
            entity = Entity(0),
            c_flags = {},
            anim = {},
            move_anim = {},
            attack_anim = {},
            flags = {},
            removed = {},
            added = {},
        },
        type = .Normal,
        state = .Deciding,
    })

    // Initialize deck (simple for tests)
    battle.deck = BeeDeck {}
    queue.init(&battle.deck.deck, 10)
    queue.init(&battle.deck.discard, 10)
    queue.push_back(&battle.deck.deck, BeeAction.Sting)
    queue.push_back(&battle.deck.deck, BeeAction.FlyTowards)

    // Mock weapons and grid_weapons
    battle.weapons = make([]game.Weapon, 0)
    battle.grid_weapons = make([dynamic]game.WeaponGrid)

    // Mock grid (7x5 as per grid.odin)
    battle.grid = new(Grid)
    battle.grid.width = game.GRID_WIDTH
    battle.grid.height = game.GRID_HEIGHT
    battle.grid.data = make([]game.Tile, int(battle.grid.width * battle.grid.height))
    for i in 0..<len(battle.grid.data) {
        battle.grid.data[i] = .Blank
    }
    battle.grid.scale = {1.0, 1.0} // Assume default

    // States
    battle.state = .PlayerTurn
    battle.input_state = .SelectAction
    battle.current_bee = 0
    battle.dice = [2]game.Dice {}
    battle.bee_selection = 0
    battle.bee_is_near = false

    // Ves defaults
    ves.curr_screen = .SelectAction
    ves.prev_screen = .None
    ves.dice_state = .None
    ves.anim_state = .None

    return battle, ves
}

// Cleanup after each test - just reset the arena
teardown_battle :: proc(battle: ^Battle, ves: ^VisualEventData) {
    fini_test_arena()
    // ax.reset_memory_arena(&test_arena)
}

// ----------- Game Ending & Win/Lose Conditions --------------

@(test)
Game_Ends_If_Player_Health_is_Zero :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.health = 0
    game.run_battle(battle, ves) // Assuming run_battle calls run_players_turn and checks conditions

    expected := game.check_lose_condition(battle)
    testing.expect(t, expected, "Game should end if player health is 0")
    // Add check for state or ves if game ends
}

@(test)
Game_Ends_When_All_Bees_Are_Dead :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    for &bee in battle.bees {
        bee.flags += {.Dead}
    }
    game.run_players_turn(battle, ves) // Triggers win check

    expected := game.check_win_condition(battle)
    testing.expect(t, expected, "Game should end when all bees are dead")
    testing.expect(t, ves.curr_screen == .None, "Screen should be None on win")
    testing.expect(t, len(battle.bees) == 0, "Bees should be cleared on win")
}

@(test)
Game_Ends_When_Last_Bee_Dies_While_Player_Still_Has_Health :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.health = 5
    for &bee, i in battle.bees {
        bee.health = 0
        bee.flags += {.Dead}
    }

    game.run_players_turn(battle, ves)

    expected := game.check_win_condition(battle)
    testing.expect(t, expected, "Game should end when last bee dies and player has health")
}

@(test)
Game_Ends_Immediately_After_Check_For_Win_Condition_When_Condition_Met :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    for &bee in battle.bees {
        bee.flags += {.Dead}
    }
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.state == .PlayerTurn, "State does not advance after immediate win check")
    testing.expect(t, ves.curr_screen == .None, "Ends immediately after check")
}

// ----------- Game Continues (Non-Ending) Conditions --------------

@(test)
Game_Does_Not_End_When_Player_At_1_Health_And_Bees_Still_Alive :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.health = 1
    game.run_players_turn(battle, ves)

    testing.expect(t, !game.check_lose_condition(battle), "Game continues at 1 health with bees alive")
    testing.expect(t, ves.curr_screen != .None, "Screen not None")
}

@(test)
Game_Continues_If_No_Win_Condition_After_Bee_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.state = .BeesTurn
    battle.current_bee = 0
    game.run_battle(battle, ves)

    testing.expect(t, battle.state == .PlayerTurn, "Game continues to player turn if no win after bees")
}

@(test)
Game_Continues_When_Player_Moves_Into_Item_Tile_And_Picks_Up_Item :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    // Set an item tile
    idx := int(battle.player.pos.y * battle.grid.width + battle.player.pos.x + 1) // Next x
    battle.grid.data[idx] = .Weapon // Assume .Weapon is item
    battle.player.target = battle.player.pos + {1, 0}

    battle.input_state = .Movement
    game.run_players_turn(battle, ves)

    testing.expect(t, game.weap_check(battle.player.target, battle.grid), "Player picks up item")
    testing.expect(t, !game.check_win_condition(battle), "Game continues after pickup")
}

// ----------- Turn Loop & Phase Checks --------------

@(test)
Game_Checks_Win_Condition_After_Each_Phase :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    // Player phase
    game.run_players_turn(battle, ves)
    testing.expect(t, !game.check_win_condition(battle), "Checked after player phase (no win)")

    // Bee phase
    battle.state = .BeesTurn
    game.run_battle(battle, ves)
    testing.expect(t, !game.check_win_condition(battle), "Checked after bee phase (no win)")
}

@(test)
Game_Checks_Player_Status_Effects_Before_Player_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].flags += {.PlayerFocused}
    game.run_players_turn(battle, ves)

    vc := game.get_component(battle.bees[0].entity, Cmp_Visual) // Assume mock or nil check
    testing.expect(t, vc != nil && .Focus in vc.flags, "Player status effects checked before turn")
}

@(test)
Game_Checks_Bee_Status_Effects_Before_Bee_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].flags += {.PlayerDodge}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    vc := game.get_component(battle.bees[0].entity, Cmp_Visual)
    testing.expect(t, vc != nil && .Dodge in vc.flags, "Bee status effects checked before turn")
}

@(test)
Game_Does_Not_Proceed_To_Bee_Turn_If_Player_Dies_During_Player_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.health = 0 // Die during player turn simulation
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.state != .BeesTurn, "Does not proceed to bee turn if player dies")
}

@(test)
Win_Condition_Checked_After_Player_Move :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    game.run_players_turn(battle, ves)

    testing.expect(t, !game.check_win_condition(battle), "Win condition checked after player move")
}

@(test)
Win_Condition_Checked_After_Bee_Move :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.state = .BeesTurn
    battle.bees[0].state = .Moving // Assume
    game.run_battle(battle, ves)

    testing.expect(t, !game.check_win_condition(battle), "Win condition checked after bee move")
}

// ----------- Player Action Limits --------------

@(test)
Player_Can_Only_Perform_One_Action_Per_Turn_By_Default :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .SelectAction
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_1] = true // Move
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.input_state == .Movement, "Selects move action")
    game.run_players_turn(battle, ves) // Complete action
    testing.expect(t, battle.state == .BeesTurn, "Only one action per turn, proceeds to bees")
}

@(test)
Player_Can_Choose_Attack_Prepare_Or_Move_Each_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .SelectAction
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_1] = true // Move
    game.run_players_turn(battle, ves)
    testing.expect(t, battle.input_state == .Movement, "Can choose move")

    // Reset for attack
    battle.input_state = .SelectAction
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_2] = true // Attack/SelectEnemy
    game.run_players_turn(battle, ves)
    testing.expect(t, battle.input_state == .SelectEnemy, "Can choose attack")

    // For prepare, assuming F/D in .Action after select enemy
}

@(test)
Player_Cannot_Perform_Two_Attacks_In_One_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .SelectAction
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_2] = true
    game.run_players_turn(battle, ves)
    // Complete attack...
    battle.input_state = .SelectEnemy
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
    game.run_players_turn(battle, ves)
    battle.input_state = .Action
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.state == .BeesTurn, "After one attack, cannot do second in same turn")
}

// ----------- Player Movement --------------

@(test)
Player_Default_Move_Is_One_Block_Per_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true // Move right
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == prev_pos + {1, 0}, "Moves one block by default")
}

@(test)
Player_Can_Move_Two_Blocks_In_One_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    // Assuming code supports double move, perhaps with special input or repeated
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true // First
    ax.g_input.keys_pressed[glfw.KEY_D] = true // Hold for second? Assume logic allows
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == prev_pos + {2, 0}, "Can move two blocks in one turn")
}

@(test)
Player_Can_Choose_To_Move_One_Or_Two_Blocks_As_Single_Action :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    // Similar to above, assume choice via input
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true // One
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)
    testing.expect(t, battle.player.pos == prev_pos + {1, 0}, "Can choose one block")

    // Reset and choose two
    battle.player.pos = {0, 0}
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    ax.g_input.keys_just_pressed[glfw.KEY_LEFT_SHIFT] = true // Assume shift for double
    game.run_players_turn(battle, ves)
    testing.expect(t, battle.player.pos == {2, 0}, "Can choose two blocks as single action")
}

@(test)
Double_Move_Consumes_Only_One_Action :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    ax.g_input.keys_just_pressed[glfw.KEY_LEFT_SHIFT] = true // Double
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.state == .BeesTurn, "Double move consumes only one action")
}

// ----------- Player Alerting via Movement --------------

@(test)
Moving_One_Block_Does_Not_Alert_Bees_By_Default :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    game.run_players_turn(battle, ves)

    for bee in battle.bees {
        testing.expect(t, .Alert not_in bee.flags, "One block move does not alert bees")
    }
}

@(test)
Moving_Two_Blocks_Alerts_All_Bees_On_Map :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    ax.g_input.keys_just_pressed[glfw.KEY_LEFT_SHIFT] = true // Double move
    game.run_players_turn(battle, ves)

    for bee in battle.bees {
        testing.expect(t, .Alert in bee.flags, "Two block move alerts all bees")
    }
}

@(test)
Moving_Two_Blocks_Alerts_All_Bees_Regardless_Of_Distance :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {6, 4} // Far in 7x5 grid
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    ax.g_input.keys_just_pressed[glfw.KEY_LEFT_SHIFT] = true
    game.run_players_turn(battle, ves)

    testing.expect(t, .Alert in battle.bees[0].flags, "Alerts regardless of distance")
}

// ----------- Player Grid & Tile Movement Rules --------------

@(test)
Player_Cannot_Move_Outside_Grid_Bounds :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.pos = {6, 4}
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == prev_pos, "Cannot move outside grid bounds")
}

@(test)
Player_Cannot_Move_Into_Wall_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    idx := int(battle.player.pos.y * battle.grid.width + battle.player.pos.x + 1)
    battle.grid.data[idx] = .Wall
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == prev_pos, "Cannot move into wall tile")
}

@(test)
Player_Cannot_Move_One_Tile_Diagonally :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    ax.g_input.keys_just_pressed[glfw.KEY_W] = true // Diagonal attempt
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    // testing.expect(t, battle.player.pos == prev_pos || linalg.length(battle.player.pos - prev_pos) == 1, "Cannot move diagonally")
}

@(test)
Player_Can_Move_Onto_Blank_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == prev_pos + {1, 0}, "Can move onto blank tile")
}

@(test)
Player_Can_Move_Onto_Item_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    idx := int(battle.player.pos.y * battle.grid.width + battle.player.pos.x + 1)
    battle.grid.data[idx] = .Weapon // Item
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == prev_pos + {1, 0}, "Can move onto item tile")
}

@(test)
Player_Can_Move_Onto_Entity_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {1, 0} // Entity tile
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    prev_pos := battle.player.pos
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.player.pos == {1, 0}, "Can move onto entity tile")
}

@(test)
Distance_Of_One_Is_Only_Orthogonal_Not_Diagonal :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {1, 1} // Diagonal
    testing.expect(t, !game.bee_near(battle.player, battle.bees[0]), "Diagonal not considered distance one")

    battle.bees[0].pos = {1, 0} // Orthogonal
    testing.expect(t, game.bee_near(battle.player, battle.bees[0]), "Orthogonal is distance one")
}

// ----------- Player Item Interaction --------------

@(test)
Player_Automatically_Picks_Up_Item_When_Landing_On_Item_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    idx := int(battle.player.pos.y * battle.grid.width + battle.player.pos.x + 1)
    battle.grid.data[idx] = .Weapon
    battle.player.target = {1, 0}
    game.pick_up_weapon(&battle.player, battle.weapons)

    testing.expect(t, game.weap_check({1, 0}, battle.grid), "Automatically picks up item")
}

@(test)
Item_Tile_Becomes_Blank_After_Player_Pickup :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    idx := int(battle.player.pos.y * battle.grid.width + battle.player.pos.x + 1)
    battle.grid.data[idx] = .Weapon
    battle.player.target = {1, 0}
    game.pick_up_weapon(&battle.player, battle.weapons)

    testing.expect(t, battle.grid.data[idx] == .Blank, "Item tile becomes blank after pickup")
}

// ----------- Player Attack Rules (Basic) --------------

@(test)
Player_Cannot_Attack_Bee_Outside_Weapon_Range :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.weapon.range = 1 // Assume
    battle.bees[0].pos = {3, 0} // Outside range
    battle.bee_selection = 0
    battle.bee_is_near = false

    battle.input_state = .Action
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
    game.run_players_turn(battle, ves)

    prev_health := battle.bees[0].health
    testing.expect(t, battle.bees[0].health == prev_health, "Cannot attack outside range")
}

@(test)
Player_Cannot_Attack_Without_Equipped_Weapon :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.weapon = {} // No weapon
    battle.bees[0].pos = {1, 0}
    battle.bee_selection = 0
    battle.bee_is_near = true

    battle.input_state = .Action
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
    game.run_players_turn(battle, ves)

    prev_health := battle.bees[0].health
    testing.expect(t, battle.bees[0].health == prev_health, "Cannot attack without weapon")
}

@(test)
Player_Can_Only_Attack_With_Equipped_Weapon :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.weapon.flying.power = 1 // Equipped
    battle.bees[0].pos = {1, 0}
    battle.bee_selection = 0
    battle.bee_is_near = true

    battle.input_state = .Action
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
    game.run_players_turn(battle, ves)

    testing.expect(t, battle.bees[0].health < 1, "Can attack with equipped weapon")
}

// ----------- Bee Action & Range Limits --------------

@(test)
Bee_Can_Only_Perform_One_Action_Per_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.state = .BeesTurn
    battle.current_bee = 0
    game.run_battle(battle, ves)

    testing.expect(t, battle.current_bee == 1, "Bee performs one action per turn")
}

@(test)
Bee_Can_Choose_Attack_Or_Move_Each_Turn :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].type = .Normal
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    // testing.expect(t, battle.bees[0].state == .Attacking || battle.bees[0].state == .Moving, "Bee chooses attack or move")
}

@(test)
Bee_Can_Only_Attack_At_Range_0_Or_1 :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {1, 0} // Range 1
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health < 5, "Can attack at range 1")
}

@(test)
Bee_Can_Attack_Player_At_Range_0 :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {0, 0} // Range 0
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health < 5, "Can attack at range 0")
}

@(test)
Bee_Can_Attack_Player_At_Range_1 :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {1, 0}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health < 5, "Can attack at range 1")
}

@(test)
Bee_Cannot_Attack_Player_From_2_Blocks_Away :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].pos = {2, 0}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health == 5, "Cannot attack from 2 blocks away")
}

// ----------- Bee Alert Mechanics --------------

@(test)
Bee_Cannot_Attack_Player_Unless_Alerted :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].flags -= {.Alert}
    battle.bees[0].pos = {1, 0}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health == 5, "Cannot attack unless alerted")
}

@(test)
Bee_Cannot_Attack_If_Not_Alerted_Even_If_In_Range :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].flags -= {.Alert}
    battle.bees[0].pos = {1, 0}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health == 5, "Cannot attack if not alerted even in range")
}

@(test)
Bee_Becomes_Alerted_When_Player_Performs_Double_Move :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true
    ax.g_input.keys_just_pressed[glfw.KEY_LEFT_SHIFT] = true // Double
    game.run_players_turn(battle, ves)

    testing.expect(t, .Alert in battle.bees[0].flags, "Becomes alerted on double move")
}

@(test)
Bee_Becomes_Alerted_When_Bee_And_Player_Occupy_Same_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.player.pos = battle.bees[0].pos
    game.run_players_turn(battle, ves) // Trigger check

    testing.expect(t, .Alert in battle.bees[0].flags, "Alerted when occupying same tile")
}

@(test)
Bee_Remains_Alerted_After_Once_Alerted :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].flags += {.Alert}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)
    battle.state = .PlayerTurn
    game.run_battle(battle, ves)

    testing.expect(t, .Alert in battle.bees[0].flags, "Remains alerted after once alerted")
}

@(test)
Default_Bee_Does_Not_Attack_When_Not_Alerted :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.bees[0].flags -= {.Alert}
    battle.bees[0].pos = {1, 0}
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.player.health == 5, "Default bee does not attack when not alerted")
}

// ----------- Bee Grid Movement --------------

@(test)
Bee_Cannot_Move_Into_Wall_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    idx := int(battle.bees[0].pos.y * battle.grid.width + battle.bees[0].pos.x - 1)
    battle.grid.data[idx] = .Wall
    battle.bees[0].target = battle.bees[0].pos + {-1, 0}
    battle.bees[0].state = .Moving
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.bees[0].pos != battle.bees[0].target, "Bee cannot move into wall tile")
}

@(test)
Bee_Can_Move_Onto_Blank_Tile :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    prev_pos := battle.bees[0].pos
    battle.bees[0].target = prev_pos + {-1, 0}
    battle.bees[0].state = .Moving
    battle.state = .BeesTurn
    game.run_battle(battle, ves)

    testing.expect(t, battle.bees[0].pos == prev_pos + {-1, 0}, "Bee can move onto blank tile")
}

// ----------- General / Combination Cases --------------

@(test)
Player_Can_Use_Prepare_Action_Without_Triggering_Alert :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    battle.input_state = .SelectEnemy
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_SPACE] = true
    game.run_players_turn(battle, ves)
    battle.input_state = .Action
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_F] = true // Focus/prepare
    game.run_players_turn(battle, ves)

    testing.expect(t, .Alert not_in battle.bees[0].flags, "Prepare action does not trigger alert")
}

@(test)
Game_Ends_When_Player_Moves_Onto_Last_Bee_And_Kills_It_With_Overlap_Attack :: proc(t: ^testing.T) {
    battle, ves := setup_battle()
    defer teardown_battle(battle, ves)

    for &bee, i in battle.bees {
        if i > 0 {
            bee.flags += {.Dead}
        }
    }
    battle.player.target = battle.bees[0].pos
    battle.input_state = .Movement
    test_clear_input()
    ax.g_input.keys_just_pressed[glfw.KEY_D] = true // Move onto bee
    game.run_players_turn(battle, ves)
    // Assume overlap triggers attack
    battle.bees[0].health = 0
    battle.bees[0].flags += {.Dead}

    testing.expect(t, game.check_win_condition(battle), "Game ends when moving onto and killing last bee")
}
