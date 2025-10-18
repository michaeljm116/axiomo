package main
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

vec2 :: [2]i16
GRID_WIDTH :: 7
GRID_HEIGHT :: 5
s : bufio.Scanner
g_state : GameState = .Start
g_current_bee: int = 0
g_level :Level
g_dice :  [2]Dice
g_saftey_bee : Bee

Grid :: [][]Tile
Level :: struct
{
    player : Player,
    bees : [dynamic]Bee,
    deck : BeeDeck,
    weapons : []Weapon,
    grid : Grid,
    grid_data : []Tile,
    grid_scale : vec2f,
    grid_weapons : [dynamic]WeaponGrid,
}
prestart :: proc()
{
    g_saftey_bee = Bee{name = '🍯', pos = vec2{6,3}, target = vec2{6,3}, health = 2, type = .Normal, flags = {}, entity = load_prefab("Bee")}
    tc := get_component(g_saftey_bee.entity, Cmp_Transform)
    tc.global.pos.y = 100000000000000.0
    add_component(g_saftey_bee.entity, Cmp_Visual{})
}
//----------------------------------------------------------------------------\\
// /Start UP
//----------------------------------------------------------------------------\\
start_level1 :: proc(alloc : mem.Allocator = context.allocator)
{
    context.allocator = alloc
    using g_level
    g_state = .PlayerTurn
    ves.curr_screen = .SelectAction
    // Clear and initialize grid contiguously
    grid_data = make([]Tile, GRID_WIDTH * GRID_HEIGHT)
    grid = make([][]Tile, GRID_WIDTH)
    for i in 0..<GRID_WIDTH {
        start := i * GRID_HEIGHT
        grid[i] = grid_data[start : start + GRID_HEIGHT]
    }
    // add somethings to the grid
    grid[2][0] = .Weapon
    grid[4][3] = .Weapon
    grid[5][0] = .Wall

    // Initialize weapons
    db := WeaponsDB
    weapons = make([]Weapon, len(db))
    for i, w in db do weapons[w] = i

    // Initialize Player and Bee
    player = {name = '🧔', pos = vec2{0,2}, health = 1, weapon = db[.Hand], abilities = {}}
    bees = make([dynamic]Bee, 2)
    bees[0] = Bee{name = '🐝', pos = vec2{6,2}, target = vec2{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    bees[1] = Bee{name = '🍯', pos = vec2{6,3}, target = vec2{6,3}, health = 100, type = .Normal, flags = {}, entity = load_prefab("Bee")}

    player.abilities = make([dynamic]Ability, 2)
    player.abilities[0] = Ability{type = .Dodge, use_on = &bees[0], level = 1, uses = 1}
    player.abilities[1] = Ability{type = .Focused, use_on = &bees[1], level = 1, uses = 1}

    //Shuffle bee BeeDeck
    deck_init(&g_level.deck, 36)

    //Set up visuals over bee
    for b in bees do add_component(b.entity, Cmp_Visual{})
    for &dice, i in g_dice{
        dice = Dice{num = i8(i)}//, entity = gui["Dice"]}
        dice.time.max = 1.0
        dice.interval.max = 0.16
    }
    g_dice.x.entity = gui["Dice1"]
    g_dice.y.entity = gui["Dice2"]
    for &d, i in g_dice {
        gc := get_component(d.entity, Cmp_Gui)
        gc.alpha = 0.0
        gc.min.x += (f32(i) * 0.16)
        update_gui(gc)
    }
}

destroy_visuals :: proc(visuals : ^Cmp_Visual) {
    if entity_exists(visuals.alert) do delete_parent_node(visuals.alert)
    if entity_exists(visuals.focus) do delete_parent_node(visuals.focus)
    if entity_exists(visuals.dodge) do delete_parent_node(visuals.dodge)
    if entity_exists(visuals.select) do delete_parent_node(visuals.select)
}

destroy_level1 :: proc() {
    for b in g_level.bees {
        vc := get_component(b.entity, Cmp_Visual)
        if vc != nil do destroy_visuals(vc)
        if(entity_exists(b.entity)) do delete_parent_node(b.entity)
    }
    for gw in g_level.grid_weapons do delete_parent_node(gw.chest)
    destroy_arenas()
}

//----------------------------------------------------------------------------\\
// /Run Game
//----------------------------------------------------------------------------\\
bee_selection := 0
bee_is_near := false
pt_state : PlayerInputState = .SelectAction
run_game :: proc(state : ^GameState, player : ^Player, bees : ^[dynamic]Bee, deck : ^BeeDeck)
{
    switch state^
    {
        case .Start:
            // start_game()
            state^ = .PlayerTurn
            break
        case .PlayerTurn:
            run_players_turn(&pt_state, state, player, bees, &bee_selection, &bee_is_near)
            break
        case .BeesTurn:
            if g_current_bee >= len(bees) {
                g_current_bee = 0
                state^ = .PlayerTurn
                return
            }
            bee := &bees[g_current_bee]
            update_bee(bee, deck, player, f32(g_frame.physics_time_step))  // New proc (defined below)
            break
        case .End:
            // destroy_bee_deck(deck)
            state^ = .Start
            break
        case .Pause:
    }
}

// On Players turn, wait for input of 1-3 if any of those then set action to move,attack or ability
// if move then go to movement state and check for wasd movement
// else you're in... select enemy state oops
// after that, if player action = attack, wait for space, else focus or dodge
run_players_turn :: proc(state : ^PlayerInputState, game_state : ^GameState, player : ^Player, bees : ^[dynamic]Bee, bee_selection : ^int, bee_is_near : ^bool)
{
    //Check if victory:
    victory := true
    for b in bees{
        if .Dead not_in b.flags do victory = false
    }
    if victory {
        clear(bees)
        ves.curr_screen = .None
    }
    switch state^
    {
        case .SelectAction:
            ves.curr_screen = .SelectAction
            if is_key_just_pressed(glfw.KEY_1){
                ves.anim_state = .Start
                state^ = .Movement
                ves.curr_screen = .Movement
            }
            if is_key_just_pressed(glfw.KEY_2){
                state^ = .SelectEnemy
                ves.curr_screen = .SelectEnemy
                bee_selection^ = 0
                bee_is_near^ = false
                start_bee_selection(bee_selection^, bees)
            }
            break
        case .Movement:
            handle_back_button(state)
            input, moved := get_input()
            if moved{
                move_player(player, input, state)
                ves.curr_screen = .None
            }
            if ves.anim_state == .Finished {
                ves.anim_state = .None
                state^ = .SelectAction
                game_state^ = .BeesTurn

                if weap_check(player.target, &g_level.grid) {
                    pick_up_weapon(player, g_level.weapons)

                    //check for chest
                    for weap in g_level.grid_weapons{
                        if player.target == weap.pos do animate_chest(weap.chest)
                    }
                }
            }
        case .SelectEnemy:
            handle_back_button(state)
            if is_key_just_pressed(glfw.KEY_SPACE) || is_key_just_pressed(glfw.KEY_ENTER){
                bee_is_near^ = bee_near(player^, bees[bee_selection^])
                state^ = .Action
                bees[bee_selection^].removed |= {.PlayerSelected}
                show_weapon(player.weapon)
                // for b in bees{
                //     vc := get_component(b.entity, Cmp_Visual)
                //     if vc != nil do hide_visuals(vc, {.Select})
                // }
            }
            else do enemy_selection(bee_selection, bees^)
        case .Action:
            ves.curr_screen = .Action
            handle_back_button(state)
            if(bee_is_near^ && is_key_just_pressed(glfw.KEY_SPACE)){
                hide_weapon(player.weapon)
                ves.curr_screen = .None
                // player_attack(player^, &bees[bee_selection^])
                // state^ = .SelectAction
                // game_state^ = .BeesTurn
                state^ = .DiceRoll
                ves.dice_state = .Start
                if .Dead in bees[bee_selection^].flags{
                    fmt.printfln("Bee %v is dead", bees[bee_selection^].name)
                    //remove the bee for now
                    ordered_remove(&g_level.bees, bee_selection^)
                }
            }
            else if is_key_just_pressed(glfw.KEY_F){
                hide_weapon(player.weapon)
                if .PlayerFocused in bees[bee_selection^].flags do bees[bee_selection^].flags |= {.PlayerHyperFocused}
                bees[bee_selection^].added |= {.PlayerFocused}
                state^ = .SelectAction
                game_state^ = .BeesTurn

                //display visual
                // vc := get_component(bees[bee_selection^].entity, Cmp_Visual)
                // vc.flags += {.Focus}
            }
            else if is_key_just_pressed(glfw.KEY_D){
                hide_weapon(player.weapon)
                if .PlayerDodge in bees[bee_selection^].flags do bees[bee_selection^].flags |= {.PlayerHyperAlert}
                bees[bee_selection^].added |= {.PlayerDodge}
                state^ = .SelectAction
                game_state^ = .BeesTurn
                // vc := get_component(bees[bee_selection^].entity, Cmp_Visual)
                // vc.flags += {.Dodge}
            }
        case .DiceRoll:
            ves.curr_screen = .DiceRoll
            if ves.dice_state == .Update do return
            if ves.dice_state == .Finished{
                ves.dice_state = .None
                ves.curr_screen = .None
                fmt.println("Dice Num 1: ", g_dice[0].num, " Dice Num 2: ", g_dice[1].num)
                acc := g_dice[0].num + g_dice[1].num
                bee := &bees[bee_selection^]
                player_attack(player^, bee, acc)
                state^ = .SelectAction
                game_state^ = .BeesTurn
                return
            }
        // case .Animate:
        //     TogglePlayerTurnUI(state)
        //     animate_player(player, f32(g_frame.physics_time_step), state)
        //     if state^ == .SelectAction do game_state^ = .BeesTurn
        //     break
    }
}

run_bee_decision :: proc(bee : ^Bee, deck : ^BeeDeck) -> BeeAction{
    cards : [dynamic]BeeAction
    chosen_card : BeeAction

    switch bee.type {
    case .Aggressive:
        cards = deck_draw(deck, 2)
        chosen_card = deck_choose_card(cards, BeeActionPriority_Aggressive)
    case .Passive:
        deck_draw(deck, 2)
        chosen_card = deck_choose_card(cards, BeeActionPriority_Passive)
    case .Normal:
        chosen_card = deck_draw(deck, 1)[0]
    }
    fmt.printf("Chosen 🎴: %v\n", chosen_card)
    return chosen_card
    // bee_action_perform(chosen_card, bee, &g_level.player)
}

update_bee :: proc(bee: ^Bee, deck: ^BeeDeck, player: ^Player, dt: f32) {
    if .Dead in bee.flags
    {
        set_dead_bee(bee)
        g_current_bee += 1
        return
    }
    switch bee.state {
    case .Deciding:
        card := run_bee_decision(bee, deck)  // Selects action, sets state/flags in bee_action_selecperform
        bee.state = .Acting
        bee_action_perform(card, bee, player)
    case .Acting:
        if .Animate in bee.flags do return
        if ves.anim_state == .Finished{
            ves.anim_state = .None
            bee.state = .Finishing
            return
        }
        if .Attack in bee.flags {
            // if player dodge, first roll dice, if dice is finished then do player attack
            if .PlayerDodge in bee.flags {
                bee.removed += {.PlayerDodge}
                ves.dice_state = .Start
            }
            if ves.dice_state == .Finished {
                bee_action_attack(bee, player, g_dice.x.num + g_dice.y.num)
                bee.state = .Finishing
            }
            if ves.dice_state == .None {
                bee_action_attack(bee, player, 20)
                bee.state = .Finishing
            }
        }
    case .Finishing:
        bee.state = .Deciding
        bee.removed += {.Animate, .Attack, .Moving}
        g_current_bee += 1
        ves.anim_state = .None
        ves.dice_state = .None
    }
}

// If B button is pressed, go back to previous menu
handle_back_button :: proc(state : ^PlayerInputState){
    if(!is_key_just_pressed(glfw.KEY_B)) do return
    hide_weapon(g_level.player.weapon)
    g_level.bees[bee_selection].removed |= {.PlayerSelected}
    #partial switch state^ {
        case .Movement:
            state^ = .SelectAction
            ves.curr_screen = .SelectAction
            break
        case .SelectEnemy:
            state^ = .SelectAction
            ves.curr_screen = .SelectAction
            break
        case .Action:
            state^ = .SelectEnemy
            ves.curr_screen = .SelectEnemy
            break
    }
}

//Select enemy via vector position... rottate based off wasd
enemy_selection :: proc(selection : ^int, bees : [dynamic]Bee)
{
    prev_selection := selection^
    num_bees := len(bees)
    assert(num_bees > 0)
    if(num_bees == 1){selection^ = 0}
    else {
        if(is_key_just_pressed(glfw.KEY_W) || is_key_just_pressed(glfw.KEY_D)){
            selection^ = (selection^ + 1) % num_bees
        }
        else if(is_key_just_pressed(glfw.KEY_A) || is_key_just_pressed(glfw.KEY_S)){
            selection^ = math.abs(selection^ - 1) % num_bees
            if selection^ < 0 do selection^ = num_bees
        }
    }

    // if its a new selection, update visual
    if prev_selection != selection^{
        bees[selection^].added += {.PlayerSelected}
        bees[prev_selection].removed += {.PlayerSelected}
    }
}
start_bee_selection :: proc(selection: int, bees : ^[dynamic]Bee)
{
    for &b , i in bees
    {
        if selection == i do b.added += {.PlayerSelected}
        else do b.removed += {.PlayerSelected}
    }
}

get_input :: proc() -> (string, bool)
{
    if is_key_just_pressed(glfw.KEY_W) {
       return "w", true
    }
    else if is_key_just_pressed(glfw.KEY_S) {
       return "s", true
    }
    else if is_key_just_pressed(glfw.KEY_A) {
       return "a", true
    }
    else if is_key_just_pressed(glfw.KEY_D) {
       return "d", true
    }
    return "", false
}

PlayerInputState :: enum
{
   SelectAction,
   Movement,
   SelectEnemy,
   Action,
   DiceRoll,
}

Tile :: enum
{
    Blank,
    Wall,
    Weapon,
    Entity
}

Player :: struct{
    using base : Character,
    weapon : Weapon,
    abilities : [dynamic]Ability,
}

CharacterFlag :: enum { Walk, Run, Attack, Dodge, Focus,}
CharacterFlags :: bit_set[CharacterFlag; u16]

Character :: struct
{
    name : rune,
    pos : vec2,
    health : i8,
    target : vec2,
    entity : Entity,
    c_flags : CharacterFlags,
    anim : CharacterAnimation,
    move_anim : MovementTimes,
    attack_anim : AttackTimes,
    flags : GameFlags,
    removed : GameFlags,
    added : GameFlags,
}

CharacterAnimation :: struct
{
    timer : f32,
    start : vec4,      // position start
    end : vec4,        // position end
    rot_timer : f32,
    start_rot : quat,  // rotation start (quaternion)
    end_rot : quat,    // rotation end (quaternion)
}

Ability :: struct {
   use_on : ^Bee,
   type : AbilityType,
   level : i8,
   uses : i8,
}

AbilityType :: enum{
    Focused,
    Dodge
}

//----------------------------------------------------------------------------\\
// /Bee
//----------------------------------------------------------------------------\\
BeeType :: enum
{
    Normal,
    Aggressive,
    Passive,
}

Bee :: struct {
    using base : Character,
    type : BeeType,

    state: BeeState,
}

BeeAction :: enum
{
    Discard,
    FlyTowards,
    FlyAway,
    CrawlTowards,
    CrawlAway,
    Sting,
}

BeeState :: enum{
    Deciding,
    Acting,
    Finishing,
}

BeeActionPriority_Aggressive :: [BeeAction]int{
    .FlyTowards = 1,
    .CrawlTowards = 2,
    .Sting = 3,
    .CrawlAway = 4,
    .FlyAway = 5,
    .Discard = 10000
}

BeeActionPriority_Passive :: [BeeAction]int{
    .FlyAway = 1,
    .CrawlAway = 2,
    .Sting = 3,
    .CrawlTowards = 4,
    .FlyTowards = 5,
    .Discard = 10000
}

BeeActionDeckData :: struct
{
    type : BeeAction,
    freq : i8
}

BeeDeck :: struct
{
    FlyTowards : BeeActionDeckData,
    FlyAway : BeeActionDeckData,
    CrawlTowards : BeeActionDeckData,
    CrawlAway : BeeActionDeckData,
    Sting : BeeActionDeckData,

    deck : queue.Queue(BeeAction),
    discard : queue.Queue(BeeAction)
}

set_dead_bee :: proc(bee : ^Bee)
{
    bee.removed = {.Alert, .PlayerFocused, .PlayerDodge, .PlayerHyperFocused, .PlayerHyperAlert}
    tc := get_component(bee.entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(179, {0,0,1})
}

//----------------------------------------------------------------------------\\
// /Deck
//----------------------------------------------------------------------------\\
deck_init :: proc(deck : ^BeeDeck, size : int = 36)
{
    deck.FlyTowards = BeeActionDeckData{type = .FlyTowards, freq =  6}
    deck.FlyAway = BeeActionDeckData{type = .FlyAway, freq =  6}
    deck.CrawlTowards = BeeActionDeckData{type = .CrawlTowards, freq =  6}
    deck.CrawlAway = BeeActionDeckData{type = .CrawlAway, freq =  6}
    deck.Sting = BeeActionDeckData{type = .Sting, freq =  12}

    temp_deck := make([dynamic]BeeAction, context.temp_allocator)
    reserve(&temp_deck, 36)

    for i in 0..<deck.FlyTowards.freq do append(&temp_deck, BeeAction.FlyTowards)
    for i in 0..<deck.FlyAway.freq do append(&temp_deck, BeeAction.FlyAway)
    for i in 0..<deck.CrawlTowards.freq do append(&temp_deck, BeeAction.CrawlTowards)
    for i in 0..<deck.CrawlAway.freq do append(&temp_deck, BeeAction.CrawlAway)
    for i in 0..<deck.Sting.freq do append(&temp_deck, BeeAction.Sting)

    queue.init(&deck.deck, 36, level_mem.alloc)
    queue.init(&deck.discard, 36, level_mem.alloc)
    deck_shuffle(&temp_deck)
    for c in temp_deck{
        queue.push_front(&deck.deck, c)
    }
}

deck_shuffle :: proc(deck : ^[dynamic]BeeAction)
{
    for i in 0..<len(deck)
    {
        j := rand.int31() % 36
        deck[i], deck[j] = deck[j], deck[i]
    }
}

//Draw a card from the bee deck, if the deck is blank, refresh
deck_draw :: proc(bd : ^BeeDeck, num_cards : int = 1) -> [dynamic]BeeAction
{
    if(queue.len(bd.deck) <= num_cards) do deck_refesh(bd)
    cards := make([dynamic]BeeAction, context.temp_allocator)
    reserve(&cards, num_cards)
    for i in 0..<num_cards
    {
        card := queue.pop_front(&bd.deck)
        append(&cards, card)
        // fmt.printf("Drawn 🃏: %v\n", cards[i])
        queue.push_front(&bd.discard, card)
    }
    return cards
}

deck_refesh :: proc(bd : ^BeeDeck){
    queue.clear(&bd.deck)
    queue.destroy(&bd.deck)
    queue.clear(&bd.discard)
    queue.destroy(&bd.discard)
    deck_init(bd, 36)
}

deck_choose_card :: proc(cards : [dynamic]BeeAction, priority : [BeeAction]int) -> BeeAction
{
    max_priority := 10000
    chosen_card := BeeAction.Discard

    for card in cards {
        if priority[card] < max_priority {
            max_priority = priority[card]
            chosen_card = card
        }
    }
    return chosen_card
}

//----------------------------------------------------------------------------\\
// /BA Bee Actions
//----------------------------------------------------------------------------\\
bee_action_perform :: proc(action : BeeAction, bee : ^Bee, player : ^Player)
{
    switch action{
        case .Discard: return
        case .FlyTowards:
            // Fly's 2 blocks towards player, if path overlaps player, alert!
            bee.added += {.Flying, .Moving, .Animate}
            bee_action_move_towards(bee, player, 2)
        case .FlyAway:
            // Fly 2 blocks away from player, try to avoid walls
            bee.added += {.Flying, .Moving, .Animate}
            bee_action_move_away(bee, player, 2)
        case .CrawlTowards:
            // crawl towards player, if path overlaps player, alert!
            bee.removed += {.Flying}
            bee.added += {.Animate, .Moving}
            bee_action_move_towards(bee, player, 1)
        case .CrawlAway:
            // crawl away from player, if path overlaps player, alert!
            bee.removed += {.Flying}
            bee.added += {.Animate, .Moving}
            bee_action_move_away(bee, player, 1)
        case .Sting:
            // If player is near, attack! else do nuffin
            if bee_near(player^, bee^) && .Alert in bee.flags{
                bee.added += {.Attack}
                // ves.dice_state = .Start
            }
            else do bee.state = .Finishing
            // bee_action_attack(bee, player)
    }
    // move_entity_to_tile(bee.entity, g_level.grid_scale, bee.pos)
    // if bee is hovering player, turn on alert
}


bee_action_move_towards :: proc(bee : ^Bee, player : ^Player, target_dist : int){
    assert(target_dist > 0)
    dist := dist_grid(bee.pos, player.pos)
    if dist > target_dist
    {
        path := a_star_find_path(bee.pos, player.pos)
        // TODO: possibly insecure and bug prone if there's no valid distance due to walls
        if len(path) > target_dist do bee.target = path[target_dist]
        else {if len(path) == target_dist do bee.target = path[target_dist - 1]}
    }
    else // Less than or equal to target distance, alert!
    {
        vc := get_component(bee.entity, Cmp_Visual)
        vc.flags |= {.Alert}
        bee.flags |= {.Alert}

        if dist == target_dist {
            path := a_star_find_path(bee.pos, player.pos)
            if len(path) > 1 do bee.target = path[1]
        }
    }
}

bee_action_move_away :: proc(bee : ^Bee, player : ^Player, target_dist : int){
    assert(target_dist > 0)
    target_path := find_best_target_away(bee, player, target_dist, true)
    if len(target_path) > 0 do bee.target = target_path[len(target_path) - 1]
    else{
       best := bee.pos
       bestd := dist_grid(bee.pos, player.pos)
       dirs := [4]vec2{ vec2{1,0}, vec2{-1,0}, vec2{0,1}, vec2{0,-1} }
       for d in dirs {
            n := vec2{ bee.pos[0] + d[0], bee.pos[1] + d[1] }
            if !in_bounds(n) { continue }
            if !is_walkable_internal(n, n, true) { continue }
            nd := dist_grid(n, player.pos)
            if nd > bestd {
                best = n
                bestd = nd
            }
        }
        bee.target = best
    }
}

bee_action_attack :: proc(bee : ^Bee, player : ^Player, tot : i8){
    dist := dist_grid(bee.pos, player.pos)
    if dist <= 1 {
        if tot != 20 {
            acc := 7 + 2 * i8(.PlayerHyperAlert in bee.flags)
            if acc < tot{
                player.health -= 1
                fmt.println("Player Died")
            }
            else do fmt.println("Player Dodged")
        }
        else {
            player.health -= 1
            fmt.println("PLAYER DIED")
        }
    }
}

//----------------------------------------------------------------------------\\
// /Weapon
//----------------------------------------------------------------------------\\
WeaponType :: enum
{
    Hand,
    Shoe,
    FlySwatter,
    ElectricSwatter,
    SprayCan,
    NewsPaper,
}

StatusEffect :: enum
{
   None,
   Stunned,
   Angered,
   Dying
}

StatusEffects :: bit_set[StatusEffect; u8]

Attack :: struct
{
    accuracy : i8,
    power : i8
}

Weapon :: struct
{
    type : WeaponType,
    flying : Attack,
    ground : Attack,
    range : i8,
    effect : StatusEffects,
    icon : string
}

WeaponGrid :: struct{
   pos : vec2,
   chest : Entity,
}

WeaponsDB :: [WeaponType]Weapon{
 .Hand =            Weapon{type = .Hand,            flying = Attack{accuracy = 10, power = 50}, ground = Attack{accuracy = 9, power = 100}, range = 1, effect = {.None}, icon = "IconHand"},
 .Shoe =            Weapon{type = .Shoe,            flying = Attack{accuracy =  8, power = 50}, ground = Attack{accuracy = 9, power = 100}, range = 1, effect = {.None}, icon = "IconShoe"},
 .SprayCan =        Weapon{type = .SprayCan,        flying = Attack{accuracy =  6, power = 50}, ground = Attack{accuracy = 5, power = 100}, range = 2, effect = {.None}, icon = "IconBugspray"},
 .NewsPaper =       Weapon{type = .NewsPaper,       flying = Attack{accuracy =  8, power = 50}, ground = Attack{accuracy = 8, power = 100}, range = 1, effect = {.None}, icon = "IconNewspaper"},
 .FlySwatter =      Weapon{type = .FlySwatter,      flying = Attack{accuracy =  7, power = 100}, ground = Attack{accuracy = 7, power = 100}, range = 1, effect = {.None}, icon = "IconSwatter"},
 .ElectricSwatter = Weapon{type = .ElectricSwatter, flying = Attack{accuracy =  7, power = 100}, ground = Attack{accuracy = 7, power = 100}, range = 1, effect = {.None}, icon = "IconSwatter"},
}

pick_up_weapon :: proc(player : ^Player, weaps : []Weapon, db := WeaponsDB)
{
    if len(weaps) == 0 { return }
    idx := int(rand.int31() % i32(len(weaps)))
    wt := weaps[idx].type
    player.weapon = db[wt]
}

adjust_acc_y :: #force_inline proc(n: i8) -> f32 {
    return -0.82 + 0.1 * f32(n - 3)
}

show_weapon :: proc(w : Weapon)
{
    ToggleUI(w.icon, true)
    ToggleUI("WeaponStatsFlying", true)
    ToggleUI("WeaponStatsAccuracy", true)
    ToggleUI("WeaponStatsPower", true)

    gc := get_component(gui["WeaponStatsAccuracy"], Cmp_Gui)
    if gc != nil {
        gc.align_min.y = adjust_acc_y(w.flying.accuracy)
        update_gui(gc)
    }
    ac := get_component(gui["WeaponStatsPower"], Cmp_Gui)
    if ac != nil {
        ac.align_min.y = .4
        if w.flying.power == 100 do ac.align_min.y = .3
        update_gui(ac)
    }
}

hide_weapon :: proc(w : Weapon)
{
    ToggleUI(w.icon, false)
    ToggleUI("WeaponStatsFlying", false)
    ToggleUI("WeaponStatsAccuracy", false)
    ToggleUI("WeaponStatsPower", false)
}

player_attack :: proc(player : Player, bee : ^Bee, acc : i8){
    //begin Animation
    ac := get_component(player.entity, Cmp_Animation)
    animate_attack(ac, "Froku", player.attack_anim)

    // Player rolls a dice, if its higher than their weapons accuracy, do weapon.damage to the bee
    focus_level := i8(.PlayerFocused in bee.flags) + i8(.PlayerHyperFocused in bee.flags)
    fmt.println("Dice val: ", acc, " Weapon val: ", player.weapon.flying.accuracy , " Focus Val: ", focus_level, " Will Kill: ", acc + focus_level > player.weapon.flying.accuracy)
    bee.added |= {.Alert}

    if acc + focus_level > player.weapon.flying.accuracy
    {
        bee.health -= player.weapon.flying.power
        if bee.health <= 0 do bee.added += {.Dead}
    }
    // luck := acc + focus_level
    // if .Flying in bee.flags{
    //    if player.weapon.flying.accuracy < luck {
    //        bee.health -= player.weapon.flying.power
    //        if bee.health <= 0 do bee.flags += {.Dead}
    //    }
    // }
    // else {
    //    if player.weapon.ground.accuracy < luck {
    //        bee.health -= player.weapon.ground.power
    //        if bee.health <= 0 do bee.flags += {.Dead}
    //    }
    // }
}

dice_rolls :: proc() -> i8 {
   d1 := rand.int31() % 6 + 1
   d2 := rand.int31() % 6 + 1
   fmt.printf("Dice rolls: %d + %d = %d\n", d1, d2, d1 + d2)
   return i8(d1 + d2)
}

start_dice_roll :: proc() {
    for &d in g_dice {
        d.time.curr = 0
        d.interval.curr = 0
        d.num = i8(rand.int31() % 6) + 1  // Initial random
        gc := get_component(d.entity, Cmp_Gui)
        if gc != nil {
            gc.alpha = 1.0  // Show dice
            gc.align_min = f32(one_sixth * f64(d.num - 1))  // Set initial face
            update_gui(gc)
        }
    }
}

hide_dice :: proc() {
    for d in g_dice {
        gc := get_component(d.entity, Cmp_Gui)
        if gc != nil { gc.alpha = 0.0 }
        update_gui(gc)
    }
}

place_chest_on_grid :: proc(pos : vec2, lvl : ^Level)
{
    chest := load_prefab("Chest")
    context.allocator = level_mem.alloc
    set_entity_on_tile(g_floor, chest, lvl^, pos.x, pos.y)
    append(&lvl.grid_weapons, WeaponGrid{pos, chest})
}

//----------------------------------------------------------------------------\\
// /Game
// Rules:
// 1 action = 1 turn
// Death occurs when health = 0
// Bee's only attack when alerted
//----------------------------------------------------------------------------\\
GameFlag :: enum
{
    Flying,
    Moving,
    Alert,
    Dead,
    PlayerFocused,
    PlayerDodge,
    PlayerHyperFocused,
    PlayerHyperAlert,
    PlayerSelected,
    Animate,
    Attack,
}
GameFlags :: bit_set[GameFlag; u32]
move_player :: proc(p : ^Player, key : string, state : ^PlayerInputState)
{
    // display_level(g_level)
    dir : vec2
    switch (key)
    {
        case "w":
            dir.y = 1
        case "a":
            dir.x = -1
        case "s":
            dir.y = -1
        case "d":
            dir.x = 1
    }
    bounds := p.pos + dir
    if bounds_check(bounds, g_level.grid) {
        //Animate Player
        p.target = bounds
        p.c_flags = {.Walk}
        p.added += {.Animate}
    }
}

bounds_check :: proc(bounds : vec2, grid : Grid) -> bool
{
    if(bounds.x < 0 || bounds.x >= i16(len(grid)) || bounds.y < 0 || bounds.y >= i16(len(grid[0]))) {
        return false
    }
    if grid[bounds.x][bounds.y] != .Blank && grid[bounds.x][bounds.y] != .Weapon {
        return false
    }
    return true
}

weap_check :: proc(p : vec2, grid : ^Grid) -> bool{
    if grid[p.x][p.y] == .Weapon{
        grid[p.x][p.y] = .Blank
        return true
    }
    return false
}

bee_check :: proc(p : Player, bees : [dynamic]Bee) -> (bool, int) {

    for bee, i in bees{
        diff_x := math.abs(bee.pos.x - p.pos.x)
        diff_y := math.abs(bee.pos.y - p.pos.y)
        total := i8(diff_x + diff_y)
        if total <= p.weapon.range{
            fmt.printf("Bee %v is within range\n", bee.name)
            return true, i
        }
    }
    return false,0
}

bee_near :: proc(p : Player, bee : Bee) -> bool{
    diff_x := math.abs(bee.pos.x - p.pos.x)
    diff_y := math.abs(bee.pos.y - p.pos.y)
    total := i8(diff_x + diff_y)
    return total <= p.weapon.range
}

GameState :: enum
{
    Start,
    PlayerTurn,
    BeesTurn,
    End,
    Pause,
}

find_best_target_away :: proc(bee : ^Bee, player : ^Player, min_dist : int, allow_through_walls : bool) -> [dynamic]vec2
{
    // iterate all possible tiles, pick reachable tile with dist to player >= min_dist and shortest path length from bee
    best_path := make([dynamic]vec2, context.temp_allocator)
    best_len := 999999
    for x in 0..<GRID_WIDTH do for y in 0..<GRID_HEIGHT{
        p := vec2{i16(x), i16(y)}
        if dist_grid(p, player.pos) < min_dist { continue }
        if !is_walkable_internal(p, p, allow_through_walls) { continue } // p must be a valid standable tile
        path := a_star_find_path(bee.pos, p)
        if len(path) == 0 { continue }
        if len(path) < best_len {
            best_len = len(path)
            best_path = path
            // if we found a tile that's already minimal distance (i.e., immediate neighbor counted), still continue to find shortest reachable
        }
    }
    return best_path
}

//----------------------------------------------------------------------------\\
// /Grid
//----------------------------------------------------------------------------\\

//Set the scale of the level to always match the size of the floor
//So lets say you have a 3 x 3 grid but a 90 x 90 level, 1 grid block is 30
set_grid_scale :: proc(floor : Entity, lvl : ^Level)
{
    assert(len(lvl.grid) > 0)
    assert(len(lvl.grid[0]) > 0)

    tc := get_component(floor, Cmp_Transform)
    if tc == nil do return

    lvl.grid_scale.x = tc.global.sca.x / f32(len(lvl.grid))
    lvl.grid_scale.y = tc.global.sca.z / f32(len(lvl.grid[0]))
}

// Sets a player on a tile in the level so that they are...
// Flush with the floor and in center of that tile
set_entity_on_tile :: proc(floor : Entity, entity : Entity, lvl : Level, x, y : i16)
{
    ft := get_component(floor, Cmp_Transform)
    pt := get_component(entity, Cmp_Transform)
    if ft == nil || pt == nil do return

    // Determine tile center in world space.
    // Note: `ft.global.sca` is treated consistently with primitives in the renderer (half-extents).
    full_cell_x := 2.0 * lvl.grid_scale.x
    full_cell_z := 2.0 * lvl.grid_scale.y

    // left / bottom world edges (x and z) of the floor
    left_x := ft.global.pos.x - ft.global.sca.x
    bottom_z := ft.global.pos.z - ft.global.sca.z

    tile_center_x := left_x + full_cell_x * (f32(x) + 0.5)
    tile_center_z := bottom_z + full_cell_z * (f32(y) + 0.5)

    // Set entity's horizontal position to tile center (preserve w component)
    pt.local.pos.x = tile_center_x
    pt.local.pos.z = tile_center_z

    // Now align vertically so the entity's bottom is flush with the floor top.
    floor_top := get_top_of_entity(floor)
    entity_bottom := get_bottom_of_entity(entity)

    if entity_bottom == -999999.0 { return }

    dy := floor_top - entity_bottom
    pt.local.pos.y += dy
}

// Move pLayer to block
move_entity_to_tile :: proc(entity : Entity, scale : vec2f, pos : vec2)
{
    pt := get_component(entity, Cmp_Transform)
    ft := get_component(g_floor, Cmp_Transform)
    if pt == nil || ft == nil do return

    full_cell_x := 2.0 * scale.x
    full_cell_z := 2.0 * scale.y

    left_x := ft.global.pos.x - ft.global.sca.x
    bottom_z := ft.global.pos.z - ft.global.sca.z

    tile_center_x := left_x + full_cell_x * (f32(pos.x) + 0.5)
    tile_center_z := bottom_z + full_cell_z * (f32(pos.y) + 0.5)

    pt.local.pos.x = tile_center_x
    pt.local.pos.z = tile_center_z
}

// Finds the lowest part of an entity in a scene hierarchy
// cycles through the entire entity's transform to find
// .. the lowest extent of the lowest part
get_bottom_of_entity :: proc(e : Entity) -> f32
{
    min_y :f32= 999999.0
    stackq: queue.Queue(Entity)
    queue.init(&stackq, 64)
    defer queue.destroy(&stackq)
    queue.push_front(&stackq, e)

    for queue.len(stackq) > 0 {
        curr := queue.pop_front(&stackq)
        pc := get_component(curr, Cmp_Primitive)
        if pc != nil {
            center := primitive_get_center(pc^)
            bottom_y := center.y - pc^.extents.y
            if bottom_y < min_y do min_y = bottom_y
        }
        else {
            tc := get_component(curr, Cmp_Transform)
            if tc != nil {
                bottom_y := tc.global.pos.y - tc.global.sca.y
                if bottom_y < min_y do min_y = bottom_y
            }
        }
        children := get_children(curr)
        for c in children do queue.push_front(&stackq, c)
    }
    if min_y == 999999.0 do return -999999.0
    return min_y
}

get_top_of_entity :: proc(e : Entity) -> f32
{
    max_y :f32= -999999.0
    stackq: queue.Queue(Entity)
    queue.init(&stackq, 64)
    defer queue.destroy(&stackq)
    queue.push_front(&stackq, e)

    for queue.len(stackq) > 0 {
        curr := queue.pop_front(&stackq)
        pc := get_component(curr, Cmp_Primitive)
        if pc != nil {
            center := primitive_get_center(pc^)
            top_y := center.y + pc^.extents.y
            if top_y > max_y do max_y = top_y
        } else {
            tc := get_component(curr, Cmp_Transform)
            if tc != nil {
                top_y := tc.global.pos.y + tc.global.sca.y
                if top_y > max_y do max_y = top_y
            }
        }
        children := get_children(curr)
        for c in children {
            queue.push_front(&stackq, c)
        }
    }
    if max_y == -999999.0 do return -999999.0
    return max_y
}

//----------------------------------------------------------------------------\\
// /UI
//----------------------------------------------------------------------------\\
gui : map[string]Entity
init_GameUI :: proc(game_ui : ^map[string]Entity, alloc : mem.Allocator)
{
    gui = make(map[string]Entity, alloc)
    for key,ui in g_ui_prefabs{
        cmp := map_gui(ui.gui)
        cmp.alpha = 0.0
        cmp.update = true
        e := add_ui(cmp, key)

        context.allocator = alloc
        game_ui[key] = e
        append(&ui_keys, key)
    }
}
ToggleUI :: proc(name : string, on : bool)
{
    gc := get_component(gui[name], Cmp_Gui)
    gc.alpha = on ? 1.0 : 0.0
    gc.update = on
    update_gui(gc)
}

TogglePlayerTurnUI :: proc(state : ^PlayerInputState)
{
    #partial switch state^{
        case .SelectAction:
            ToggleUI("SelectAction", false)
            ToggleUI("MoveWASD", false)
            ToggleUI("Attack", false)
            ToggleUI("Focus", false)
            ToggleUI("Dodge", false)

            ToggleUI("Move", true)
            ToggleUI("EnemySelect", true)
        case .SelectEnemy:
            ToggleUI("Move", false)
            ToggleUI("EnemySelect", false)
            ToggleUI("ChooseBee", true)
            ToggleUI("SelectAction", true)
        case .Movement:
            ToggleUI("Move", false)
            ToggleUI("EnemySelect", false)
            ToggleUI("MoveWASD", true)
        case .Action:
            ToggleUI("ChooseBee", false)
            ToggleUI("SelectAction", false)
            ToggleUI("Attack", true)
            ToggleUI("Focus", true)
            ToggleUI("Dodge", true)
    }
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

//----------------------------------------------------------------------------\\
// /Animation
//----------------------------------------------------------------------------\\
MovementAnimHash :: enum i32 {
    IdleStart = 728262270,
    WalkStart = -1164222069,
    RunStart  = -1467624261,
    JumpStart = -1767485036,

    IdleEnd   = 1090499610,
    WalkEnd   = -1142104506,
    RunEnd    = 219290937,
    JumpEnd   = -1089428097,
}

MovementTimes :: struct{
    idle_time : f32,
	walk_time : f32,
	run_time : f32,
	jump_time : f32,
}

AttackTimes :: struct
{
    stab_time : f32,
}

set_animation :: proc(ac : ^Cmp_Animation, time : f32, name : string, start : string, end : string, flags : AnimFlags){
    if ac.state != .DEFAULT do return
    ac.trans = xxh2.str_to_u32(start)
    ac.trans_end = xxh2.str_to_u32(end)
    ac.trans_timer = 0
    ac.trans_time = time * 0.25
    ac.time = time * 0.5
    ac.prefab_name = xxh2.str_to_u32(name)
    ac.flags = flags
    ac.state = .TRANSITION
}

animate_walk :: proc(ac : ^Cmp_Animation, prefab_name : string, m : MovementTimes ){
    set_animation(ac, m.walk_time, prefab_name, "walkStart", "walkEnd", AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_idle :: proc(ac : ^Cmp_Animation, prefab_name : string, m : MovementTimes ){
    set_animation(ac, m.idle_time, prefab_name, "idleStart", "idleEnd", AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_run :: proc(ac : ^Cmp_Animation, prefab_name : string, m : MovementTimes ){
    set_animation(ac, m.run_time, prefab_name, "runStart", "runEnd", AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_attack :: proc(ac : ^Cmp_Animation, prefab_name : string, a : AttackTimes ){
    set_animation(ac, a.stab_time, prefab_name, "stabStart", "stabEnd", AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_chest :: proc(chest : Entity){
   flatten_entity(chest)
   display_flattened_entity(chest)
   ac := animation_component_with_names(1,"Chest","","Open", AnimFlags{idPo = 0, loop = false, force_start = true, force_end = true})
   add_component(chest, ac)
   sys_anim_add(chest)
}

add_animation :: proc(c : ^Character, prefab : string)
{
    c.move_anim = MovementTimes{
        idle_time = 1.5,
        walk_time = 0.25,
        run_time = 0.4,
        jump_time = 0.25
    }
    c.attack_anim = AttackTimes{
        stab_time =  0.125
    }

    flatten_entity(c.entity)
    ac := animation_component_with_names(2,prefab, "idleStart", "idleEnd", AnimFlags{ idPo = 0, loop = true, force_start = true, force_end = true})
    add_component(c.entity, ac)
    sys_anim_add(c.entity)
    // animate_idle(&ac, prefab, c.move_anim)
}

add_animations :: proc()
{
    add_animation(&g_level.player.base, "Froku")
    add_animation(&g_level.bees[0].base, "AggressiveBee")
    add_animation(&g_level.bees[1].base, "Bee")
}

// Similar to move_entity_to_tile but just sets the vectors up
set_up_character_anim :: proc(cha : ^Character)
{
    scale := g_level.grid_scale
    pt := get_component(cha.entity, Cmp_Transform)
    ft := get_component(g_floor, Cmp_Transform)
    if pt == nil || ft == nil do return

    full_cell_x := 2.0 * scale.x
    full_cell_z := 2.0 * scale.y

    left_x := ft.global.pos.x - ft.global.sca.x
    bottom_z := ft.global.pos.z - ft.global.sca.z

    tile_center_x := left_x + full_cell_x * (f32(cha.target.x) + 0.5)
    tile_center_z := bottom_z + full_cell_z * (f32(cha.target.y) + 0.5)

    cha.anim.start = pt.local.pos
    cha.anim.end.yw = cha.anim.start.yw
    cha.anim.end.xz = {tile_center_x, tile_center_z}

    // Compute target rotation to face the movement direction
    ct := get_component(cha.entity, Cmp_Transform)
    if ct == nil do return

    cha.anim.start_rot = ct.local.rot

    dir_xz := vec3{cha.anim.end.x - cha.anim.start.x, 0, cha.anim.end.z - cha.anim.start.z}
    dir_len := linalg.length(dir_xz)
    if dir_len > 0 {
        fwd := -linalg.normalize(dir_xz)
        up := vec3{0, 1, 0}
        cha.anim.end_rot = linalg.quaternion_from_forward_and_up(fwd, up) // Assumes quat as vec4
    } else {
        cha.anim.end_rot = cha.anim.start_rot // No movement; no rotation change
    }
}

slerp_character_to_tile :: proc(cha : ^Character, dt : f32)
{
    if dt < 1 do cha.anim.timer -= dt
    ct := get_component(cha.entity, Cmp_Transform)
    if ct == nil do return
    t := f64(1.0 - cha.anim.timer)
    eased_t := math.smoothstep(0.0,1.0,t)
    ct.local.pos = linalg.lerp(cha.anim.start, cha.anim.end, f32(eased_t))
}

slerp_character_angle :: proc(cha : ^Character, dt : f32)
{
    if cha.anim.rot_timer <= 0 do return
    cha.anim.rot_timer -= dt

    ct := get_component(cha.entity, Cmp_Transform)
    if ct == nil do return

    t := f64(1.0 - cha.anim.rot_timer)
    eased_t := math.smoothstep(0.0, 1.0, t)
    // Interpolate rotation (assumes vec4 quaternions; adjust if using quat128)
    ct.local.rot = linalg.quaternion_slerp(cha.anim.start_rot, cha.anim.end_rot, f32(eased_t))
}


//----------------------------------------------------------------------------\\
// /Menu
//----------------------------------------------------------------------------\\
AppState :: enum
{
    TitleScreen,
    MainMenu,
    Game,
    Pause,
    GameOver,
    Victory
}

MenuAnimation :: struct
{
    timer : f32,
    duration : f32,
}
MenuAnimStatus :: enum{
    Running,
    Finished
}

app_start :: proc()
{
    prestart()
    init_GameUI(&gui, game_mem.alloc)
    // start_game()
    ToggleUI("Title", true)
}

start_game :: proc()
{
    start_level1(level_mem.alloc)
    find_floor_entities()
    set_grid_scale(g_floor, &g_level)
    set_entity_on_tile(g_floor, g_player, g_level, g_level.player.pos.x, g_level.player.pos.y)
    for bee in g_level.bees{
        set_entity_on_tile(g_floor, bee.entity, g_level, bee.pos.x, bee.pos.y)
        face_right(bee.entity)
    }

    place_chest_on_grid(vec2{2,0}, &g_level)
    place_chest_on_grid(vec2{4,3}, &g_level)
    g_level.player.entity = g_player
    add_animations()
}

g_app_state := AppState.TitleScreen
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
            state^ = .Game
            ToggleMenuUI(state)
            start_game()
        }
	case .Game:
		run_game(&g_state, &g_level.player, &g_level.bees, &g_level.deck)
		ves_update_all(dt)
		if (g_level.player.health <= 0){
			state^ = .GameOver
            destroy_level1()
			ToggleMenuUI(state)
		}
	    else if (len(g_level.bees) <= 0){
    		state^ = .Victory
            destroy_level1()
            ToggleMenuUI(state)
		}
        else if (is_key_just_pressed(glfw.KEY_P)){
            state^ = .Pause
            ToggleMenuUI(state)
        }
        ves_cleanup(&g_level)
	case .Pause:
        if is_key_just_pressed(glfw.KEY_ENTER){
            state^ = .Game
            ToggleMenuUI(state)
        }
	case .GameOver:
    	if is_key_just_pressed(glfw.KEY_ENTER){
            state^ = .MainMenu
            ToggleMenuUI(state)
        }
	case .Victory:
	    if is_key_just_pressed(glfw.KEY_ENTER){
			state^ = .MainMenu
			ToggleMenuUI(state)
		}
	}

}

set_game_over :: proc(){
    fmt.println("destroying game")
    g_app_state = .GameOver
    destroy_level1()
	ToggleMenuUI(&g_app_state)
}

set_game_start :: proc(){
    fmt.println("starting game")
    g_app_state = .Game
    ToggleMenuUI(&g_app_state)
    start_game()
}

g_title : Entity
g_titleAnim : MenuAnimation
g_main_menu : Entity
g_main_menuAnim : MenuAnimation
menu_show_title :: proc()
{
   g_title = gui["Title"]
   gc := get_component(g_title, Cmp_Gui)
   gc.alpha = 0.0
   g_titleAnim = MenuAnimation{timer = 0.0, duration = 1.0}
   gc.min = 0.0
   gc.extents = 1.0
}
menu_show_main :: proc()
{
    g_main_menu = gui["MainMenu"]
    gc := get_component(g_main_menu, Cmp_Gui)
    gc.alpha = 0.0
    g_main_menuAnim = MenuAnimation{timer = 0.0, duration = 1.0}
    gc.min = 0.0
    gc.extents = 1.0
}
ToggleMenuItem :: proc(entity : Entity, on : bool)
{
    c := get_component(entity, Cmp_Gui)
    c.alpha = on ? 1.0 : 0.0
    c.update = on ? true : false
}

menu_run_title :: proc(dt : f32, state : ^AppState)
{
    if is_key_just_pressed(glfw.KEY_ENTER){
        state^ = .MainMenu
    }
}

game_started := false
// menu_run_main :: proc(dt : f32, state : ^AppState)
// {
//     if is_key_just_pressed(glfw.KEY_ENTER) do state^ = .Game
//     // Wait for player to press enter, if so then start the anim and go to GameState
//     if game_started{
//         if menu_run_anim(g_main_menu, &g_main_menuAnim, dt) == .Finished{
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


//----------------------------------------------------------------------------\\
// /Visulaization
//----------------------------------------------------------------------------\\
Cmp_Visual :: struct
{
    alert : Entity,
    focus : Entity,
    dodge : Entity,
    select : Entity,
    flags : VisualFlags,
    bob_timer : f32,
    spin_angle : f32, // Added for spinning animations
}
VisualFlag :: enum{ Alert,Focus,Dodge,Select }
VisualFlags :: bit_set[VisualFlag;u8]

sys_visual_process_ecs :: proc(dt : f32)
{
    archetypes := query(has(Cmp_Visual), has(Cmp_Transform))
    for archetype in archetypes {
        visual := get_table(archetype, Cmp_Visual)
        transf := get_table(archetype, Cmp_Transform)
        for entity, i in archetype.entities do sys_visual_update(&visual[i], transf[i], dt)
    }
}

spin_entity :: proc(entity: Entity, dt: f32, speed: f32 = 180.0) {
    at := get_component(entity, Cmp_Transform)
    if at != nil {
        delta_angle := speed * f32(glfw.GetTime())
        delta_quat := linalg.quaternion_from_euler_angle_y(f32(math.to_radians(delta_angle)))
        at.local.rot = linalg.quaternion_mul_quaternion(at.local.rot, delta_quat)
    }
}

bob_entity :: proc(entity: Entity, timer: ^f32, dt: f32, amplitude: f32 = 0.5, period: f32 = 1.0) {
    timer^ += dt
    at := get_component(entity, Cmp_Transform)
    if at != nil {
        bob_speed := 2.0 * math.PI / period
        at.local.pos.y += amplitude * math.sin(timer^ * bob_speed)
    }
}

sys_visual_update :: proc(vc : ^Cmp_Visual, tc : Cmp_Transform, dt : f32)
{
    // Define a fixed order for visuals to ensure consistent positioning
    visual_order : []VisualFlag = { .Alert, .Focus, .Dodge, .Select }

    // First, handle creation and visibility (show/hide based on flags)
    if .Alert in vc.flags {
        if !entity_exists(vc.alert) do vc.alert = load_prefab("IconAlert")
        at := get_component(vc.alert, Cmp_Transform)
        if at != nil do at.local.sca = 1 // Assume original scale is 1; adjust if needed
    } else if entity_exists(vc.alert) {
        hide_entity(vc.alert)
    }

    if .Focus in vc.flags {
        if !entity_exists(vc.focus) do vc.focus = load_prefab("IconFocus")
        at := get_component(vc.focus, Cmp_Transform)
        if at != nil do at.local.sca = 1
    } else if entity_exists(vc.focus) {
        hide_entity(vc.focus)
    }

    if .Dodge in vc.flags {
        if !entity_exists(vc.dodge) do vc.dodge = load_prefab("IconDodge")
        at := get_component(vc.dodge, Cmp_Transform)
        if at != nil do at.local.sca = 1
    } else if entity_exists(vc.dodge) {
        hide_entity(vc.dodge)
    }

    if .Select in vc.flags {
        if !entity_exists(vc.select) do vc.select = load_prefab("IconArrow")
        at := get_component(vc.select, Cmp_Transform)
        if at != nil do at.local.sca = 1
    } else if entity_exists(vc.select) {
        hide_entity(vc.select)
    }

    // Collect active visuals in order
    visual_list := make([dynamic]Entity, 0, context.temp_allocator)
    reserve(&visual_list, 4)
    for f in visual_order {
        if f not_in vc.flags do continue
        ent: Entity
        switch f {
        case .Alert:  ent = vc.alert
        case .Focus:  ent = vc.focus
        case .Dodge:  ent = vc.dodge
        case .Select: ent = vc.select
        }
        if entity_exists(ent) do append(&visual_list, ent)
    }

    // Position active visuals side by side if multiple
    count := len(visual_list)
    if count > 0 {

        spacing: f32 = 1.0 // Adjust spacing between icons as needed
        start_offset := -(f32(count - 1) / 2.0) * spacing

        for ent, i in visual_list {
            at := get_component(ent, Cmp_Transform)
            if at != nil {
                set_a_above_b(at, tc, 2.5) // Base height above the model; adjust as needed
                at.local.pos.x += (start_offset + f32(i) * spacing) // Offset horizontally
                bob_entity(ent, &vc.bob_timer, dt)
                spin_entity(ent, dt)
            }
        }
    }
}

set_a_above_b :: proc(a : ^Cmp_Transform, b : Cmp_Transform, h : f32)
{
    a.local = b.local
    a.local.pos.y += h
}

hide_entity :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.sca = 0
}

hide_visuals :: proc(visuals : ^Cmp_Visual, flags : VisualFlags)
{
    if .Alert in flags && visuals.alert != 0 do hide_entity(visuals.alert)
    if .Focus in flags && visuals.focus != 0 do hide_entity(visuals.focus)
    if .Dodge in flags && visuals.dodge != 0 do hide_entity(visuals.dodge)
    if .Select in flags && visuals.select != 0 do hide_entity(visuals.select)

    // Remove the specified flags from the visual component
    visuals.flags -= flags
}
// curr_max_union
cmu :: struct #raw_union{
    using _: struct{
        curr:f32,
        max:f32,
    },
    _: [2]f32,
}

CurrMax :: struct #raw_union {
    using _: [2]f32,
    using _: struct {
        curr: f32,
        max: f32,
    },
}

Dice :: struct {
    num : i8,
    time : cmu,
    interval : cmu,
    entity : Entity,
}
one_sixth := 1.0/6.0

dice_roll_vis :: proc(dice: ^[2]Dice, dt : f32){
    for &d in dice{
        d.time.curr += dt
        d.interval.curr += dt

        // if(d.time.curr > d.time.max)
        // {
        //     // Exit out change state etc...
        //     d.time.curr = 0
        //     return
        // }
        if(d.time.curr > d.time.max) do return
        if(d.interval.curr > d.interval.max)
        {
            //reset interval... switch dice num
            d.interval.curr = 0
            prev_num := d.num
            d.num = i8(rand.int31() % 6 + 1)
            if d.num == prev_num do d.num = ((d.num + 1) % 6) + 1
            assert(d.num > 0 && d.num <= 6)
            //set dice face
            icon := get_component(d.entity, Cmp_Gui)
            icon.align_min.x = f32(one_sixth * f64(d.num - 1))
            icon.align_min.y = 0.0
            update_gui(icon)
        }
    }
}


//----------------------------------------------------------------------------\\
// /ves VISUAL EVENT SYSTEM
//----------------------------------------------------------------------------\\
VES_Screen :: enum
{
    None,
    SelectAction,
    Movement,
    SelectEnemy,
    Action,
    DiceRoll,
}

VES_State :: enum{
    None,
    Start,
    Update,
    Finished,
}

VisualEventData :: struct
{
   curr_screen : VES_Screen,
   prev_screen : VES_Screen,
   dice_state : VES_State,
   anim_state : VES_State
}
ves : VisualEventData

ves_update_all :: proc(dt : f32)
{
    ves_update_dice()
    ves_update_screen()
    ves_update_visuals(&g_level)
    ves_update_animations(&g_level, dt)
}

// When a screen is turned off or on, update it accordingly
ves_update_screen :: proc(){
    if ves.prev_screen != ves.curr_screen{
        //First turn off all screen
        switch ves.prev_screen{
            case .None: break
            case .SelectAction:
                ToggleUI("Move", false)
                ToggleUI("EnemySelect", false)
            case .SelectEnemy:
                ToggleUI("ChooseBee", false)
                ToggleUI("SelectAction", false)
            case .Movement:
                ToggleUI("MoveWASD", false)
            case .Action:
                ToggleUI("Attack", false)
                ToggleUI("Focus", false)
                ToggleUI("Dodge", false)
            case .DiceRoll:
                hide_dice()// ToggleUI("Dice", false)
        }
        //Then turn new screen
        switch ves.curr_screen{
            case .None: break
            case .SelectAction:
                ToggleUI("Move", true)
                ToggleUI("EnemySelect", true)
            case .SelectEnemy:
                ToggleUI("ChooseBee", true)
                ToggleUI("SelectAction", true)
            case .Movement:
                ToggleUI("MoveWASD", true)
            case .Action:
                ToggleUI("Attack", true)
                ToggleUI("Focus", true)
                ToggleUI("Dodge", true)
            case .DiceRoll:
                break// ToggleUI("Dice", true)
        }
        // Finally, make them equal
        ves.prev_screen = ves.curr_screen
    }
}

ves_update_dice :: proc(){
    #partial switch ves.dice_state{
    case .Start:
        start_dice_roll()
        ves.dice_state = .Update
    case .Update:
        dice_roll_vis(&g_dice, f32(g_frame.physics_time_step))
        for d in g_dice {
            if d.time.curr >= d.time.max + 1 do ves.dice_state = .Finished
        }
    case .Finished:
        hide_dice()
        break;
    }
}

ves_update_animations :: proc(lvl : ^Level, dt : f32)
{
    for &b in lvl.bees{
        if .Animate in b.added{
            ves.anim_state = .Start
            ves_animate_bee_start(&b)
        }
        if .Animate in b.flags do if ves_animate_bee(&b,dt){
            ves.anim_state = .Update
        }
        else if .Animate in b.removed{
            ves.anim_state = .Finished
            ves_animate_bee_end(&b)
        }
    }

    // Animate Player
    {
       if .Animate in lvl.player.added{
           ves.anim_state = .Start
           ves_animate_player_start(&lvl.player)
       }
       if .Animate in lvl.player.flags do if ves_animate_player(&lvl.player, dt){
           ves.anim_state = .Update
       }
       else if .Animate in lvl.player.removed {
           ves.anim_state = .Finished
           ves_animate_player_end(&lvl.player)
       }
    }
}

ves_cleanup :: proc(lvl : ^Level)
{
    for &b in &lvl.bees{
        b.flags += b.added
        b.flags -= b.removed
        b.added = {}
        b.removed = {}
    }
    p := &lvl.player
    p.flags += p.added
    p.flags -= p.removed
    p.added = {}
    p.removed = {}
}

ves_update_visuals :: proc(lvl : ^Level)
{
    for &b in lvl.bees{
        if .PlayerFocused in b.added{
            b.added -= {.PlayerFocused}
            b.flags += {.PlayerFocused}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags += {.Focus}
        }
        if .PlayerFocused in b.removed{
            b.removed -= {.PlayerFocused}
            b.flags -= {.PlayerFocused}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags -= {.Focus}
        }
        if .PlayerDodge in b.added{
            b.added -= {.PlayerDodge}
            b.flags += {.PlayerDodge}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags += {.Dodge}
        }
        if .PlayerDodge  in b.removed{
            b.removed -= {.PlayerDodge}
            b.flags -= {.PlayerDodge}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags -= {.Dodge}
        }
        if .Alert in b.added{
            b.added -= {.Alert}
            b.flags += {.Alert}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags += {.Alert}
        }
        if .Alert in b.removed{
            b.removed -= {.Alert}
            b.flags -= {.Alert}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags -= {.Alert}
        }
        if .PlayerSelected in b.added{
            b.added -= {.PlayerSelected}
            b.flags += {.PlayerSelected}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags += {.Select}
        }
        if .PlayerSelected in b.removed{
            b.removed -= {.PlayerSelected}
            b.flags -= {.PlayerSelected}

            vc := get_component(b.entity, Cmp_Visual)
            vc.flags -= {.Select}
        }
    }
}

ves_animate_bee :: #force_inline proc(bee : ^Bee, dt : f32) -> bool
{
    if bee.anim.timer > 0 && .Walk in bee.c_flags {
        slerp_character_to_tile(bee, dt)
        slerp_character_angle(bee,dt)
        return true
    }
    bee.removed += {.Animate}
    return false
}

ves_animate_bee_start :: proc(bee: ^Bee){
    bee.anim.timer = 1
    bee.anim.rot_timer = .5
    bee.c_flags = {.Walk}
    bee.flags += {.Animate}
    // bee.state = .Moving
    set_up_character_anim(bee)
}

ves_animate_bee_end :: #force_inline proc(bee : ^Bee)
{
    move_entity_to_tile(bee.entity, g_level.grid_scale, bee.target)
    bee.pos = bee.target
    bee.anim.timer = 0
}

ves_animate_player :: #force_inline proc(p : ^Player, dt : f32) -> bool{
    if p.anim.timer > 0 && .Walk in p.c_flags {
        slerp_character_to_tile(p, dt)
        slerp_character_angle(p,dt)
        return true
    }
    p.removed += {.Animate}
    return false
}

ves_animate_player_start :: #force_inline proc(p : ^Player){
    if .Walk in p.c_flags{
        p.anim.timer = 1
        p.anim.rot_timer = .5
        ac := get_component(p.entity, Cmp_Animation)
        animate_walk(ac, "Froku", p.move_anim)
    }
    set_up_character_anim(&p.base)
}

ves_animate_player_end :: #force_inline proc(p : ^Player){
    move_entity_to_tile(p.entity, g_level.grid_scale, p.target)
    p.pos = p.target
    p.anim.timer = 0
    ac := get_component(p.entity, Cmp_Animation)
    animate_idle(ac, "Froku", p.move_anim)
}