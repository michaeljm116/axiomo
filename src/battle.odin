package game
import "core:mem"
import "vendor:wasm/WebGL"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:math"
import "core:math/rand"
import "core:container/queue"

import "base:intrinsics"
import "vendor:glfw"
import xxh2"axiom/extensions/xxhash2"

import "axiom"
import lex"lexicon"

Battle :: struct
{
    player : Player,
    bees : [dynamic]Bee,
    deck : BeeDeck,
    weapons : []Weapon,
    grid : ^Grid,
    grid_weapons : [dynamic]WeaponGrid,

    state : BattleState,
    // input_state : PlayerInputState,

    current_bee: int,
    attack_bar : AttackBar,
    dodge_qte : DodgeQTE,
    // bee_selection : int,
    bee_is_near : bool,
    battle_queue : queue.Queue(^Character),

    // Per - Turn data
    curr_sel : BattleSelection,
}

//----------------------------------------------------------------------------\\
// /Start UP
//----------------------------------------------------------------------------\\

//TODO: THIS IS SUS, NO MORE DELETES!!
// these should be inactive and invisible
destroy_visuals :: proc(visuals : ^Cmp_Visual) {
     if axiom.entity_exists(visuals.alert) do axiom.delete_parent_node(visuals.alert)
     if axiom.entity_exists(visuals.focus) do axiom.delete_parent_node(visuals.focus)
     if axiom.entity_exists(visuals.dodge) do axiom.delete_parent_node(visuals.dodge)
     if axiom.entity_exists(visuals.select) do axiom.delete_parent_node(visuals.select)
}

destroy_level1 :: proc() {
    app_restart()
    // destroy_world()
    // for b in g.battle.bees {
    //     vc := get_component(b.entity, Cmp_Visual)
    //     if vc != nil do destroy_visuals(vc)
    //     if(axiom.entity_exists(b.entity)) do axiom.delete_parent_node(b.entity)
    // }
    // for gw in g.battle.grid_weapons do axiom.delete_parent_node(gw.chest)

    // assert(axiom.entity_exists(g.floor))
}

battle_start :: proc(){ //NOTE: This doesn't actually start the battle....
    g.battle.state = .Start
    g.battle.current_bee = 0
	load_scene(lex.BEE_KILLINGS_INN)
	g.player = axiom.load_prefab(lex.PREFAB_FROKU, g.mem_game.alloc)
	find_camera_entity()
    find_light_entity()
    find_player_entity()
    face_left(g.player)

    axiom.sys_trans_process_ecs()
}

start_game :: proc(){
    g.battle.state = .Start //NOTE: Why is this in repeat?
    ves_screen_push(&g.ves, .None)
    battle_setup_1(&g.battle,g.mem_game.alloc) //NOTE: The actual initialize of the battle
    g.battle.player.entity = g.player
    init_battle(&g.battle, g.mem_game.alloc)
    init_battle_visuals(&g.battle)
    grid_init_floor(g.battle.grid, find_floor_prim()^)

    set_entity_on_tile(g.battle.grid^, g.player, g.battle, g.battle.player.pos.x, g.battle.player.pos.y, &g.battle.player.ground)
    for &bee in g.battle.bees{
        set_entity_on_tile(g.battle.grid^, bee.entity, g.battle, bee.pos.x, bee.pos.y, &bee.ground)
        face_right(bee.entity)
    }

    place_chest_on_grid(vec2i{2,0}, &g.battle)
    place_chest_on_grid(vec2i{4,3}, &g.battle)
    add_animations()
    create_grid_entities(g.battle.grid^)

    queue.init(&g.ves.event_queue, 16, g.mem_game.alloc)
}

set_game_over :: proc(){
	g.battle.player.health = 0
    // fmt.println("destroying game")
    // g.app_state = .GameOver
    // destroy_level1()
    // load_scene("Empty")
	// ToggleMenuUI(&g.app_state)
}

set_game_victory :: proc(){
	clear(&g.battle.bees)
	// fmt.println("destroying game")
	//     g.app_state = .Victory
	//     destroy_level1()
	//     overworld_start()
	//     load_scene("Overworld")
	// ToggleMenuUI(&g.app_state)
}

set_game_start :: proc(){
    fmt.println(lex.MSG_STARTING_GAME)
    g.app_state = .Game
    ToggleMenuUI(&g.app_state)
    start_game()
}

//----------------------------------------------------------------------------\\
// /Run Game
//----------------------------------------------------------------------------\\
run_battle :: proc(battle : ^Battle, ves : ^VisualEventData)
{
    using battle
    switch state
    {
        case .Start:
            refresh_player_reachability(grid, player.pos)
        	if check_end_condition(battle) do break
         	state = .Continue
        case .Continue:
        	switch v in queue.front(&battle_queue).variant{
         		case ^Player:
        			run_players_turn(battle, ves)
           		case ^Bee:
             		run_bee_turn(v, battle, ves, f32(g.frame.physics_time_step))
             }
        case .End:
	        if check_end_condition(battle) do break
	        curr := queue.pop_front(&battle_queue)
	        if .Dead not_in curr.flags do queue.push(&battle_queue, curr)
			state = .Start
    }
}

// On Players turn, wait for input of 1-3 if any of those then set action to move,attack or ability
// if move then go to movement state and check for wasd movement
// else you're in... select enemy state oops
// after that, if player action = attack, wait for space, else focus or dodge
check_win_condition :: #force_inline proc(battle : ^Battle) -> bool
{
    for b in battle.bees do if .Dead not_in b.flags do return false
    return true
}
check_lose_condition :: #force_inline proc(battle : ^Battle) -> bool
{
    return battle.player.health <= 0
}
check_end_condition :: proc(battle : ^Battle) -> bool
{
    if check_win_condition(battle) || check_lose_condition(battle)
    {
        battle.state = .End
        return true
    }
    return false
}
check_status_effect_player :: proc(player : ^Player)
{
}
check_status_effect_bee :: proc(bee : ^Bee)
{
}

run_players_turn :: proc(battle: ^Battle, ves : ^VisualEventData)//state : ^PlayerInputState, battle_state : ^BattleState, player : ^Player, bees : ^[dynamic]Bee, bee_selection : ^int, bee_is_near : ^bool)
{
    if ves_is_busy(ves) do return
    using battle
    //Check if victory:
    victory := check_win_condition(battle)
    if victory{
        clear(&bees)
        ves_clear_screens(ves)
    }
    top := ves_top_screen(ves)

    switch top{
    	case .None:
	   		ves_screen_push(ves, .SelectCharacter)
	    case .SelectCharacter:
            if game_controller_just_pressed(.Select)
            {
				switch c in curr_sel.character.variant
				{
             		case ^Player:
                        ves_screen_push(ves, .Movement)
               		case ^Bee:
						bee_is_near = bee_near(player, c)
		                ves_screen_push(ves, .Action)
		                show_weapon(player.weapon)
	            }
            }
            else do battle_selection_update(&battle.curr_sel)
	    case .Movement:
        	handle_back_button(ves)
            if game_controller_is_moving() do move_player(&player, game_controller_move_axis(), grid)
        case .Action:
	        handle_back_button(ves)
            if check_action_attack(battle, ves) do return
            else if check_action_focused(battle,ves) do return
            else if check_action_dodged(battle,ves) do return
        case .PlayerAttack:
        case .BeeAttack:
        case .Animating:
            ves_clear_screens(ves)
            return
    }
}

check_action_attack :: proc(battle : ^Battle, ves : ^VisualEventData) -> bool{
    if !battle.bee_is_near || !game_controller_just_pressed(.Select) do return false

	using battle
	hide_weapon(player.weapon)
    // player_attack(player, &curr_sel.character)
    // input_state = .SelectCharacter
    // state^ = .BeesTurn

    ev := VisualEvent{
        type = .AttackQTE,
        state = .Pending,
        character = &battle.player.variant,
        on_finish = proc(ev:^VisualEvent, b: ^Battle){
            b.state = .End
            if .Dead in b.curr_sel.character.flags{
                fmt.printfln("Bee %v is dead", b.curr_sel.character.name)
                ordered_remove(&b.curr_sel.selectables, b.curr_sel.index)
            }
        }
    }
    queue.push(&ves.event_queue, ev)
    return true
}

check_action_focused :: proc(battle : ^Battle, ves : ^VisualEventData) -> bool{
    if !game_controller_just_pressed(.Focus) do return false

	using battle
	hide_weapon(player.weapon)
    if .PlayerFocused in curr_sel.character.flags do curr_sel.character.flags |= {.PlayerHyperFocused}
    curr_sel.character.added |= {.PlayerFocused}
    ves_clear_screens(ves)
    battle.state = .End
    return true
}
check_action_dodged :: proc(battle : ^Battle, ves : ^VisualEventData) -> bool{
    if !game_controller_just_pressed(.Dodge) do return false

	using battle
	hide_weapon(player.weapon)
    if .PlayerDodge in curr_sel.character.flags do curr_sel.character.flags |= {.PlayerHyperAlert}
    curr_sel.character.added |= {.PlayerDodge}
    ves_clear_screens(ves)
    battle.state = .End
    return true
}

run_bee_decision :: proc(bee : ^Bee, deck : ^BeeDeck) -> BeeAction{
    cards : [dynamic]BeeAction
    chosen_card : BeeAction

    switch bee.type {
    case .Aggressive:
        cards = deck_draw(deck, 2)
        chosen_card = deck_choose_card(cards, BeeActionPriority_Aggressive)
    case .Passive:
        cards = deck_draw(deck, 2)
        chosen_card = deck_choose_card(cards, BeeActionPriority_Passive)
    case .Normal:
        chosen_card = deck_draw(deck, 1)[0]
    }
    fmt.printf("Chosen 🎴: %v\n", chosen_card)
    return chosen_card
    // bee_action_perform(chosen_card, bee, &g.battle.player)
}

run_bee_turn :: proc(bee: ^Bee, battle : ^Battle, ves : ^VisualEventData, dt: f32) {
    if ves_is_busy(ves) do return
    using battle
    if .Dead in bee.flags
    {
        set_dead_bee(bee)
        state = .End
        return
    }
    switch bee.state {
    case .Deciding:
        card := run_bee_decision(bee, &deck)  // Selects action, sets state/flags in bee_action_selecperform
        bee.state = .Acting
        bee_action_perform(card, bee, &player, grid^)
    case .Acting:
            bee.state = .Finishing
            if .Attack in bee.flags {
            // if player dodge, first roll dice, if dice is finished then do player attack
                if .PlayerDodge in bee.flags {
                    bee.removed += {.PlayerDodge}
                    // g.ves.dice_state = .Start
                }
            // qte stuff i guess?
            // if g.ves.dice_state == .Finished {
            //     bee_action_attack(bee, &player, dice.x.num + dice.y.num)
            //     bee.state = .Finishing
            // }
            // if g.ves.dice_state == .None {
            //     bee_action_attack(bee, &player, 20)
            //     bee.state = .Finishing
            // }
        }
    case .Finishing:
        bee.state = .Deciding
        bee.removed += {.Attack, .Moving}
        state = .End
        // g.ves.dice_state = .None
    }
}

handle_back_button :: proc(ves : ^VisualEventData){
    if(!game_controller_just_pressed(.Back)) do return
    ves_screen_pop(ves)
}

BattleSelection :: struct
{
	index : int,
	character : ^Character,
	selectables: [dynamic]^Character
}

battle_selection_init :: proc(battle : ^Battle, selection : ^BattleSelection, alloc : mem.Allocator){
	selection.index = 0
	selection.selectables = make([dynamic]^Character, 0, len(battle.bees) + 1, alloc)

	// Add player first, then all bees
	append(&selection.selectables, &battle.player.base)
	for &b in battle.bees do append(&selection.selectables, &b.base)
	selection.character = selection.selectables[selection.index]
}

battle_selection_next :: proc(sel : ^BattleSelection) -> int
{
	prev := sel.index
	sel.index += 1
	if sel.index >= len(sel.selectables) do sel.index = 0
	sel.character = sel.selectables[sel.index]
	return prev
}

battle_selection_prev :: proc(sel : ^BattleSelection) -> int
{
	prev := sel.index
	sel.index -= 1
	if sel.index < 0 do sel.index = len(sel.selectables) - 1
	sel.character = sel.selectables[sel.index]
	return prev
}

//Select enemy via vector position... rottate based off wasd
// TODO: CHANGE TO AXIS
battle_selection_update :: proc(curr : ^BattleSelection)
{
	changed := -1
     if(controller_just_pressed(.PadU) || controller_just_pressed(.PadR)){
        changed = battle_selection_next(curr)
    }
    else if(controller_just_pressed(.PadL) || controller_just_pressed(.PadD)){
         changed = battle_selection_prev(curr)
    }
    // if its a new selection, update visual
    if changed >= 0{
        curr.selectables[curr.index].added += {.PlayerSelected}
        curr.selectables[changed].removed += {.PlayerSelected}
    }
}

start_selection :: proc(battle : ^Battle)
{
	for c in battle.curr_sel.selectables do c.removed += {.PlayerSelected}
}

PlayerInputState :: enum
{
   SelectCharacter,
   Movement,
   Action,
   Attacking,
}

Player :: struct{
    using base : Character,
    weapon : Weapon,
}

AnimationFlag :: enum { Walk, Run, Attack, Dodge, Focus,}
CharacterVariant :: union {^Player, ^Bee}

Character :: struct
{
    name : rune,
    pos : vec2i,
    health : i8,
    target : vec2i,
    ground : f32,
    entity : Entity,

    // Animation related
    anim_flag : AnimationFlag,
    anim : CharacterAnimation,
    move_anim : MovementTimes,
    attack_anim : AttackTimes,

    //visual event related
    flags : GameFlags,
    removed : GameFlags,
    added : GameFlags,
    status : StatusEffects,
    variant : CharacterVariant
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

Ability :: struct
{
   use_on : ^Bee,
   type : AbilityType,
   level : i8,
   uses : i8,
}

AbilityType :: enum
{
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

init_bee_entity :: proc(bee: ^Bee)
{
    switch bee.type {
case .Normal:
            bee.entity = load_prefab(lex.PREFAB_BEE)
        case .Aggressive:
            bee.entity = load_prefab(lex.PREFAB_AGGRESSIVE_BEE)
        case .Passive:
            bee.entity = load_prefab(lex.PREFAB_BEE)
    }
    add_component(bee.entity, Cmp_Visual)
}

Bee :: struct
{
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

alert_all_bees :: proc(battle : ^Battle)
{
	for &bee in battle.bees do bee.added += {.Alert}
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

    temp_deck := make([dynamic]BeeAction, 0, size, context.temp_allocator)

    for i in 0..<deck.FlyTowards.freq do append(&temp_deck, BeeAction.FlyTowards)
    for i in 0..<deck.FlyAway.freq do append(&temp_deck, BeeAction.FlyAway)
    for i in 0..<deck.CrawlTowards.freq do append(&temp_deck, BeeAction.CrawlTowards)
    for i in 0..<deck.CrawlAway.freq do append(&temp_deck, BeeAction.CrawlAway)
    for i in 0..<deck.Sting.freq do append(&temp_deck, BeeAction.Sting)

    queue.init(&deck.deck, size, g.mem_game.alloc)
    queue.init(&deck.discard, size, g.mem_game.alloc)
    deck_shuffle(&temp_deck)
    for c in temp_deck{
        queue.push_front(&deck.deck, c)
    }
}
deck_init_attacky :: proc(deck : ^BeeDeck, size : int = 36)
{
    deck.FlyTowards = BeeActionDeckData{type = .FlyTowards, freq =  2}
    deck.FlyAway = BeeActionDeckData{type = .FlyAway, freq =  2}
    deck.CrawlTowards = BeeActionDeckData{type = .CrawlTowards, freq =  2}
    deck.CrawlAway = BeeActionDeckData{type = .CrawlAway, freq =  2}
    deck.Sting = BeeActionDeckData{type = .Sting, freq =  28}

    temp_deck := make([dynamic]BeeAction, 0, size, context.temp_allocator)

    for i in 0..<deck.FlyTowards.freq do append(&temp_deck, BeeAction.FlyTowards)
    for i in 0..<deck.FlyAway.freq do append(&temp_deck, BeeAction.FlyAway)
    for i in 0..<deck.CrawlTowards.freq do append(&temp_deck, BeeAction.CrawlTowards)
    for i in 0..<deck.CrawlAway.freq do append(&temp_deck, BeeAction.CrawlAway)
    for i in 0..<deck.Sting.freq do append(&temp_deck, BeeAction.Sting)

    queue.init(&deck.deck, size, g.mem_game.alloc)
    queue.init(&deck.discard, size, g.mem_game.alloc)
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

//Draw a card from the bee deck, if the deck is empty, refresh
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
    deck_init_attacky (bd, 36)
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
bee_action_perform :: proc(action : BeeAction, bee : ^Bee, player : ^Player, grid : Grid)
{
    switch action{
        case .Discard: return
        case .FlyTowards:
            // Fly's 2 blocks towards player, if path overlaps player, alert!
            bee.added += {.Flying, .Moving}
            bee_action_move_towards(bee, player, 2, grid)
        case .FlyAway:
            // Fly 2 blocks away from player, try to avoid walls
            bee.added += {.Flying, .Moving}
            bee_action_move_away(bee, player, 2, grid)
        case .CrawlTowards:
            // crawl towards player, if path overlaps player, alert!
            bee.removed += {.Flying}
            bee.added += {.Crawling, .Moving}
            bee_action_move_towards(bee, player, 1, grid)
        case .CrawlAway:
            // crawl away from player, if path overlaps player, alert!
            bee.removed += {.Flying}
            bee.added += {.Crawling, .Moving}
            bee_action_move_away(bee, player, 1, grid)
        case .Sting:
            // If player is near, attack! else do nuffin
            if bee_near(player^, bee) && .Alert in bee.flags{
                bee.added += {.Attack}
            }
            else do bee.state = .Finishing
            // bee_action_attack(bee, player)
    }
    // move_entity_to_tile(bee.entity, g.battle.grid_scale, bee.pos)
    // if bee is hovering player, turn on alert
    if .Moving in bee.added{
        ev := VisualEvent{type = .AnimateMove, state = .Pending, character = &bee.variant}
        queue.push(&g.ves.event_queue, ev)
    }
    if .Attack in bee.added{
        ev := VisualEvent{type = .DodgeQTE, state = .Pending, character = &bee.variant}
        queue.push(&g.ves.event_queue, ev)
    }
}

bee_action_move_towards :: proc(bee : ^Bee, player : ^Player, target_dist : int, grid: Grid){
    assert(target_dist > 0)
    dist := path_dist_grid(bee.pos, player.pos)
    fly_over_obstacles := .Flying in bee.flags
    if dist > target_dist
    {
        path := path_a_star_find(bee.pos, player.pos, {grid.width, grid.height}, grid, fly_over_obstacles)
        // TODO: possibly insecure and bug prone if there's no valid distance due to walls
        if len(path) > target_dist do bee.target = path[target_dist]
        else {if len(path) == target_dist do bee.target = path[target_dist - 1]}
    }
    else // Less than or equal to target distance, alert!
    {
        bee.flags |= {.Alert}

        if dist == target_dist {
            path := path_a_star_find(bee.pos, player.pos, {grid.width, grid.height}, grid, fly_over_obstacles)
            if len(path) > 1 do bee.target = path[1]
        }
    }
}

bee_action_move_away :: proc(bee : ^Bee, player : ^Player, target_dist : int, grid: Grid){
    assert(target_dist > 0)
    current_dist := path_dist_grid(bee.pos, player.pos)
    required_dist := current_dist + target_dist
    fly_over_obstacles := .Flying in bee.flags
    target_path := find_best_target_away(bee, player, required_dist, fly_over_obstacles, grid)
    if len(target_path) > 0 do bee.target = target_path[len(target_path) - 1]
    else{
       best := bee.pos
       bestd := path_dist_grid(bee.pos, player.pos)
       dirs := [4]vec2i{ vec2i{1,0}, vec2i{-1,0}, vec2i{0,1}, vec2i{0,-1} }
       for d in dirs {
            n := vec2i{ bee.pos[0] + d[0], bee.pos[1] + d[1] }
            if !path_in_bounds(n, grid) { continue }
            if !path_is_walkable_internal(n, n, fly_over_obstacles, grid) { continue }
            nd := path_dist_grid(n, player.pos)
            if nd > bestd {
                best = n
                bestd = nd
            }
        }
        bee.target = best
    }
}

bee_action_attack :: proc(bee : ^Bee, player : ^Player, tot : i8){
    dist := path_dist_grid(bee.pos, player.pos)
    if dist <= 1 {
        if tot != 20 {
            acc := 7 + 2 * i8(.PlayerHyperAlert in bee.flags)
            if acc < tot{
                player.health -= 1
                fmt.println(lex.MSG_PLAYER_DIED)
            }
            else do fmt.println(lex.MSG_PLAYER_DODGED)
        }
else {
            player.health -= 1
            fmt.println(lex.MSG_PLAYER_DIED_CAPS)
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
    crawling : Attack,
    range : i8,
    effect : StatusEffects,
    icon : string
}

WeaponGrid :: struct
{
   pos : vec2i,
   chest : Entity,
}

WeaponsDB :: [WeaponType]Weapon{
 .Hand =            Weapon{type = .Hand,            flying = Attack{accuracy = 10, power = 5}, crawling = Attack{accuracy = 9, power = 10}, range = 1, effect = {.None}, icon = lex.ICON_HAND},
 .Shoe =            Weapon{type = .Shoe,            flying = Attack{accuracy =  8, power = 5}, crawling = Attack{accuracy = 9, power = 10}, range = 1, effect = {.None}, icon = lex.ICON_SHOE},
 .SprayCan =        Weapon{type = .SprayCan,        flying = Attack{accuracy =  6, power = 5}, crawling = Attack{accuracy = 5, power = 10}, range = 2, effect = {.None}, icon = lex.ICON_BUGSPRAY},
 .NewsPaper =       Weapon{type = .NewsPaper,       flying = Attack{accuracy =  8, power = 5}, crawling = Attack{accuracy = 8, power = 10}, range = 1, effect = {.None}, icon = lex.ICON_NEWSPAPER},
 .FlySwatter =      Weapon{type = .FlySwatter,      flying = Attack{accuracy =  7, power = 10}, crawling = Attack{accuracy = 7, power = 10}, range = 1, effect = {.None}, icon = lex.ICON_SWATTER},
 .ElectricSwatter = Weapon{type = .ElectricSwatter, flying = Attack{accuracy =  7, power = 10}, crawling = Attack{accuracy = 7, power = 10}, range = 1, effect = {.None}, icon = lex.ICON_SWATTER},
}

pick_up_weapon :: proc(player : ^Player, weaps : []Weapon, db := WeaponsDB)
{
    if len(weaps) == 0 { return }
    idx := int(rand.int31() % i32(len(weaps)))
    wt := weaps[idx].type
    player.weapon = db[wt]
}

adjust_acc_y :: #force_inline proc(n: i8) -> f32
{
    return -0.82 + 0.1 * f32(n - 3)
}

show_weapon :: proc(w : Weapon)
{
    ToggleUI(w.icon, true)
    ToggleUI(lex.WEAPON_STATS_FLYING, true)
    ToggleUI(lex.WEAPON_STATS_ACCURACY, true)
    ToggleUI(lex.WEAPON_STATS_POWER, true)

    gc := get_component(g_gui[lex.WEAPON_STATS_ACCURACY], Cmp_Gui)
    if gc != nil {
        gc.align_min.y = adjust_acc_y(w.flying.accuracy)
        update_gui(gc)
    }
    ac := get_component(g_gui[lex.WEAPON_STATS_POWER], Cmp_Gui)
    if ac != nil {
        ac.align_min.y = .4
        if w.flying.power == 100 do ac.align_min.y = .3
        update_gui(ac)
    }
}

hide_weapon :: proc(w : Weapon)
{
    ToggleUI(w.icon, false)
    ToggleUI(lex.WEAPON_STATS_FLYING, false)
    ToggleUI(lex.WEAPON_STATS_ACCURACY, false)
    ToggleUI(lex.WEAPON_STATS_POWER, false)
}

player_attack :: proc(player : ^Player, bee : ^Bee, acc : i8){
    //begin Animation
    player.added += {.Attack}
    // Player rolls a dice, if its higher than their weapons accuracy, do weapon.damage to the bee
    focus_level := i8(.PlayerFocused in bee.flags) + i8(.PlayerHyperFocused in bee.flags)
    fmt.println("Dice val: ", acc, " Weapon val: ", player.weapon.flying.accuracy , " Focus Val: ", focus_level, " Will Kill: ", acc + focus_level > player.weapon.flying.accuracy)
    bee.added |= {.Alert}

    // if acc + focus_level > player.weapon.flying.accuracy
    // {
    //     bee.health -= player.weapon.flying.power
    //     if bee.health <= 0 do bee.added += {.Dead}
    // }

    luck := acc + focus_level
    if .Flying in bee.flags{
       if player.weapon.flying.accuracy < luck {
           bee.health -= player.weapon.flying.power
           if bee.health <= 0 do bee.flags += {.Dead}
       }
    }
    else {
       if player.weapon.crawling.accuracy < luck {
           bee.health -= player.weapon.crawling.power
           if bee.health <= 0 do bee.flags += {.Dead}
       }
    }
}

place_chest_on_grid :: proc(pos : vec2i, battle : ^Battle)
{
    chest := load_prefab(lex.PREFAB_CHEST)
    context.allocator = g.mem_game.alloc
    f : f32
    set_entity_on_tile(battle.grid^, chest, battle^, pos.x, pos.y, &f)
    append(&battle.grid_weapons, WeaponGrid{pos, chest})
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
	Crawling,
    Flying,
    Moving,
    Alert,
    Dead,
    PlayerFocused,
    PlayerDodge,
    PlayerHyperFocused,
    PlayerHyperAlert,
    PlayerSelected,
    // Animate,
    Attack,
    Running,
    Overlapping,
}
GameFlags :: bit_set[GameFlag; u32]

move_player :: proc(p : ^Player, axis : MoveAxis , grid : ^Grid)
{
    bounds := p.pos + axis.as_int
    if !path_in_bounds(bounds, grid^) do return

    if game_controller_held(.Run){
        bounds = p.pos + 2 * axis.as_int
        if !path_in_bounds(bounds, grid^) do return
        if .Runnable in grid_get(grid, bounds).flags{
            p.target = bounds
            p.anim_flag = .Run
            p.added += {.Running}
        }
    }
    else if .Walkable in grid_get(grid, bounds).flags {
        // Animate Player
        p.target = bounds
        p.anim_flag = .Walk
    }

    ev := VisualEvent{
        type = .AnimateMove,
        state =.Pending,
        character = &p.base.variant,
        on_finish = proc(ev: ^VisualEvent, b: ^Battle){
            player := b.player
            b.state = .End
            if weap_check(player.target, b.grid)
            {
                pick_up_weapon(&player, b.weapons)
                //check for chest
                for weap in b.grid_weapons do if player.target == weap.pos do animate_chest(weap.chest)
            }
        }
    }

    queue.push(&g.ves.event_queue, ev)
}

weap_check :: proc(p : vec2i, grid : ^Grid) -> bool{
    // Tile is a bitset; check membership
    tile := grid_get(grid, p)
    if .Weapon in tile.flags {
        grid_set(grid,p, {})
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

bee_near :: proc(p : Player, bee : ^Bee) -> bool{
    diff_x := math.abs(bee.pos.x - p.pos.x)
    diff_y := math.abs(bee.pos.y - p.pos.y)
    total := i8(diff_x + diff_y)
    if total == 0 {
        bee.added += {.Overlapping}}
    return total <= p.weapon.range
}

BattleState :: enum
{
    Start,
    Continue,
    End
}

find_best_target_away :: proc(bee : ^Bee, player : ^Player, min_dist : int, fly_over_obstacles : bool, grid: Grid) -> [dynamic]vec2i
{
    // iterate all possible tiles, pick reachable tile with dist to player >= min_dist and shortest path length from bee
    best_path := make([dynamic]vec2i, context.temp_allocator)
    best_len := 999999
    for x in 0..<grid.width do for y in 0..<grid.height {
        p := vec2i{i32(x), i32(y)}
        if path_dist_grid(p, player.pos) < min_dist { continue }
        if !path_is_walkable_internal(p, p, fly_over_obstacles, grid) { continue } // p must be a valid standable tile
        path := path_a_star_find(bee.pos, p, {grid.width, grid.height}, grid, fly_over_obstacles)
        if len(path) == 0 { continue }
        if len(path) < best_len {
            best_len = len(path)
            best_path = path
            // if we found a tile that's already minimal distance (i.e., immediate neighbor counted), still continue to find shortest reachable
        }
    }
    return best_path
}

// Sets a player on a tile in the Battle so that they are...
// Flush with the floor and in center of that tile
set_entity_on_tile :: proc(grid : Grid, entity : Entity, battle : Battle, x, y : i32, ground : ^f32)
{
    pt := get_component(entity, Cmp_Transform)

    // Set entity's horizontal position to tile center (preserve w component)
    tile := grid_get(grid,x,y)
    pt.local.pos.x = tile.center.x
    pt.local.pos.z = tile.center.y

    // Now align vertically so the entity's bottom is flush with the floor top.
    entity_bottom := get_bottom_of_entity(entity)

    dy := grid.floor_height - entity_bottom
    pt.local.pos.y += dy
    ground^ = pt.local.pos.y
}

// Move pLayer to block
move_entity_to_tile :: proc(grid : Grid, entity : Entity, pos : vec2i)
{
    pt := get_component(entity, Cmp_Transform)
    assert(pt != nil)
    tile := grid_get(grid, pos.x, pos.y)

    pt.local.pos.x = tile.center.x
    pt.local.pos.z = tile.center.y
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
            center := axiom.primitive_get_center(pc^)
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
        children := axiom.get_children(curr)
        for c in children do queue.push_front(&stackq, c)
    }
    assert(min_y != 999999.0)
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
            center := axiom.primitive_get_center(pc^)
            top_y := center.y + pc^.extents.y
            if top_y > max_y do max_y = top_y
        } else {
            tc := get_component(curr, Cmp_Transform)
            if tc != nil {
                top_y := tc.global.pos.y + tc.global.sca.y
                if top_y > max_y do max_y = top_y
            }
        }
        children := axiom.get_children(curr)
        for c in children {
            queue.push_front(&stackq, c)
        }
    }
    if max_y == -999999.0 do return -999999.0
    return max_y
}

find_player_entity :: proc()
{
    table_nodes := get_table(Cmp_Node)
    for node, i in table_nodes.rows{
        if node.name == lex.ENTITY_FROKU {
            g.player = table_nodes.rid_to_eid[i]
            fmt.println(lex.DEBUG_FOUND_PLAYER)
            return
        }
    }
}

find_floor_entities :: proc() {
    table_nodes := get_table(Cmp_Node)
    for node, i in table_nodes.rows{
        if node.name == lex.ENTITY_FLOOR{
            g.floor = table_nodes.rid_to_eid[i]
            return
        }
    }
    log.error(lex.DEBUG_NO_FLOOR)
}

find_floor_transform :: proc() -> ^Cmp_Transform
{
	table_nodes := get_table(Cmp_Node)
    for node, i in table_nodes.rows{
        if node.name == lex.ENTITY_FLOOR{
            g.floor = table_nodes.rid_to_eid[i]
            return get_component(table_nodes.rid_to_eid[i], Cmp_Transform)
        }
    }
    log.panicf(lex.DEBUG_NO_FLOOR)
}
find_floor_prim :: proc() -> ^Cmp_Primitive
{
	table_nodes := get_table(Cmp_Node)
    for node, i in table_nodes.rows{
        if node.name == lex.ENTITY_FLOOR{
            g.floor = table_nodes.rid_to_eid[i]
            return get_component(table_nodes.rid_to_eid[i], Cmp_Primitive)
        }
    }
    log.panicf(lex.DEBUG_NO_FLOOR)
}

// Find the first light entity in the scene and cache it for orbit updates.
// Looks for entities with Light, Transform, and Node components.
find_light_entity :: proc()
{
    table_light := get_table(Cmp_Light)
    for light, i in table_light.rows{
        g.light_entity = table_light.rid_to_eid[i]
        return
    }
    log.error(lex.DEBUG_NO_LIGHT)
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

AttackTimes :: struct{
    stab_time : f32,
}

set_animation :: proc(ac : ^Cmp_Animation, time : f32, name : string, start : string, end : string, flags : axiom.AnimFlags){
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
    set_animation(ac, m.walk_time, prefab_name, lex.WALK_START, lex.WALK_END, axiom.AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_idle :: proc(ac : ^Cmp_Animation, prefab_name : string, m : MovementTimes ){
    set_animation(ac, m.idle_time, prefab_name, lex.IDLE_START, lex.IDLE_END, axiom.AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_run :: proc(ac : ^Cmp_Animation, prefab_name : string, m : MovementTimes ){
    set_animation(ac, m.run_time, prefab_name, lex.RUN_START, lex.RUN_END, axiom.AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_attack :: proc(ac : ^Cmp_Animation, prefab_name : string, a : AttackTimes ){
    set_animation(ac, a.stab_time, prefab_name, lex.STAB_START, lex.STAB_END, axiom.AnimFlags{loop = true, force_start = true, force_end = false});
}
animate_chest :: proc(chest : Entity){
   axiom.flatten_entity(chest)
   ac := axiom.animation_component_with_names(1,lex.PREFAB_CHEST,"",lex.CHEST_OPEN, axiom.AnimFlags{active = 1, loop = false, force_start = true, force_end = true})
   add_component(chest, ac)
   axiom.sys_anim_add(chest)
}

add_animation :: proc(c : ^Character, prefab : string){
    c.move_anim = MovementTimes{
        idle_time = 1.5,
        walk_time = 0.25,
        run_time = 0.4,
        jump_time = 0.25
    }
    c.attack_anim = AttackTimes{
        stab_time =  0.125
    }

    axiom.flatten_entity(c.entity)
    ac := axiom.animation_component_with_names(2,prefab, lex.IDLE_START, lex.IDLE_END, axiom.AnimFlags{ active = 1, loop = true, force_start = true, force_end = true})
    add_component(c.entity, ac)
    axiom.sys_anim_add(c.entity)
    // animate_idle(&ac, prefab, c.move_anim)
}

add_animations :: proc(){
    add_animation(&g.battle.player.base, lex.PREFAB_FROKU)
    add_animation(&g.battle.bees[0].base, lex.PREFAB_AGGRESSIVE_BEE)
    add_animation(&g.battle.bees[1].base, lex.PREFAB_BEE)
}

// Similar to move_entity_to_tile but just sets the vectors up
set_up_character_anim :: proc(cha : ^Character, grid : Grid){
    ct := get_component(cha.entity, Cmp_Transform)
    assert(ct != nil)

    target_tile := grid_get(grid, cha.target.x, cha.target.y)

    cha.anim.start = ct.local.pos
    cha.anim.end.yw = {cha.ground, cha.anim.start.w}
    cha.anim.end.xz = target_tile.center
    cha.anim.start_rot = ct.local.rot

    if .Flying in cha.flags do cha.anim.end.y = cha.ground + 2.0

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

slerp_character_to_tile :: proc(cha : ^Character, dt : f32){
    if dt < 1 do cha.anim.timer -= dt
    ct := get_component(cha.entity, Cmp_Transform)
    if ct == nil do return
    t := f64(1.0 - cha.anim.timer)
    eased_t := math.smoothstep(0.0,1.0,t)
    ct.local.pos = linalg.lerp(cha.anim.start, cha.anim.end, f32(eased_t))
}

slerp_character_angle :: proc(cha : ^Character, dt : f32){
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
v_visual : ^axiom.View

sys_visual_init :: #force_inline proc(alloc : mem.Allocator){
    axiom.create_table(Cmp_Visual, axiom.g_world)
    v_visual = new(axiom.View, alloc)
    err := axiom.view_init(v_visual, axiom.g_world.db, {get_table(Cmp_Visual), get_table(Cmp_Transform)})
    if err != nil do panic("Failed to initialize visuals view")
}

sys_visual_reset :: #force_inline proc(){axiom.view_rebuild(v_visual)}

sys_visual_process_ecs :: proc(dt : f32)
{
    sys_visual_reset()
    it : axiom.Iterator
    table_visual := axiom.get_table(Cmp_Visual)
    table_transform := axiom.get_table(Cmp_Transform)

    axiom.iterator_init(&it, v_visual)
    for axiom.iterator_next(&it){
        entity := axiom.get_entity(&it)
        v := get_component(table_visual, entity)
        t := get_component(table_transform, entity)
        sys_visual_update(v, t^, dt)
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
        if !axiom.entity_exists(vc.alert) do vc.alert = load_prefab(lex.ICON_ALERT)
        at := get_component(vc.alert, Cmp_Transform)
        if at != nil do at.local.sca = 1 // Assume original scale is 1; adjust if needed
    } else if axiom.entity_exists(vc.alert) {
        hide_entity(vc.alert)
    }

    if .Focus in vc.flags {
        if !axiom.entity_exists(vc.focus) do vc.focus = load_prefab(lex.ICON_FOCUS)
        at := get_component(vc.focus, Cmp_Transform)
        if at != nil do at.local.sca = 1
    } else if axiom.entity_exists(vc.focus) {
        hide_entity(vc.focus)
    }

    if .Dodge in vc.flags {
        if !axiom.entity_exists(vc.dodge) do vc.dodge = load_prefab(lex.ICON_DODGE)
        at := get_component(vc.dodge, Cmp_Transform)
        if at != nil do at.local.sca = 1
    } else if axiom.entity_exists(vc.dodge) {
        hide_entity(vc.dodge)
    }

    if .Select in vc.flags {
        if !axiom.entity_exists(vc.select) do vc.select = load_prefab(lex.ICON_ARROW)
        at := get_component(vc.select, Cmp_Transform)
        if at != nil do at.local.sca = 1
    } else if axiom.entity_exists(vc.select) {
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
        if axiom.entity_exists(ent) do append(&visual_list, ent)
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
    if .Alert  in flags && visuals.alert  != Entity(0) do hide_entity(visuals.alert)
    if .Focus  in flags && visuals.focus  != Entity(0) do hide_entity(visuals.focus)
    if .Dodge  in flags && visuals.dodge  != Entity(0) do hide_entity(visuals.dodge)
    if .Select in flags && visuals.select != Entity(0) do hide_entity(visuals.select)

    // Remove the specified flags from the visual component
    visuals.flags -= flags
}

// curr_max_union
CurrMax :: axiom.CurrMax


//----------------------------------------------------------------------------\\
// /Attack Bar System
//----------------------------------------------------------------------------\\
AttackBar :: struct {
    num : i8,
    time : CurrMax,
    interval : CurrMax,
    bar : ^Cmp_Gui,
    bee : ^Cmp_Gui,
    box : ^Cmp_Gui,
    speed : f32,
    min : f32,
    max : f32,
    center : f32,
}

attack_qte_init :: proc(ab : ^AttackBar, gui_map : ^map[string]Entity)
{
    ab.bar = get_component(gui_map[lex.ATTACK_BAR], Cmp_Gui)
    ab.bee = get_component(gui_map[lex.ATTACK_BAR_BEE], Cmp_Gui)
    ab.box = get_component(gui_map[lex.ATTACK_BAR_SLIDER], Cmp_Gui)
    ab.speed = 1
    assert(ab.bar != nil && ab.bar != nil && ab.box != nil)

    ab.min = ab.bar.min.x
    ab.max = ab.bar.min.x + ab.bar.extents.x
    ab.center = ab.bar.extents.x * f32(0.5) + ab.min
    // Init position and default values
}

attack_qte_start :: proc(bar : ^AttackBar)
{
    using bar
    // Set the Bee at a random distance to the right max = right most bar width
    // Set the Box at a random distance to the left, max = left most bar width
    bee_range := rand.float32_range(center, max)
    box_range := rand.float32_range(min, center)

    box.min.x = box_range
    bee.min.x = bee_range

    // box.extents.x = box.extents.x
    update_gui(box)
    update_gui(bee)
}

attack_qte_update :: proc(bar : ^AttackBar, dt : f32) -> bool
{
    bar.bee.min.x -= dt * bar.speed
    update_gui(bar.box)
    update_gui(bar.bee)

    if game_controller_just_pressed(.Select) do return false
    if bar.bee.min.x < (bar.bar.min.x - bar.bar.extents.x) do return false
    return true
}

attack_qte_finish :: proc(bar : ^AttackBar)
{
    using bar
    if bee.min.x > box.min.x && bee.min.x < (box.min.x + box.extents.x) do fmt.println(lex.MSG_YOU_KILLT_IT)
}

attack_qte_hide :: proc()
{
    ToggleUI(lex.ATTACK_BAR,false)
    ToggleUI(lex.ATTACK_BAR_BEE,false)
    ToggleUI(lex.ATTACK_BAR_SLIDER,false)
}

attack_qte_show :: proc()
{
    ToggleUI(lex.ATTACK_BAR,true)
    ToggleUI(lex.ATTACK_BAR_BEE,true)
    ToggleUI(lex.ATTACK_BAR_SLIDER,true)
}

attack_qte_vis :: proc(ab : ^AttackBar, dt : f32)
{
    if ab == nil { return }
    if ab.bar == nil || ab.box == nil || ab.bee == nil { return }

    // Ensure sensible defaults
    if ab.time.max <= 0.0 { ab.time.max = 1.0 } // seconds to traverse full width
    if ab.num == 0 { ab.num = 1 } // direction sign: 1 -> right, -1 -> left

    // Compute movement bounds inside the bar
    bar_min := ab.bar.min.x
    bar_width := ab.bar.extents.x
    box_width := ab.box.extents.x

    min_x := bar_min
    max_x := bar_min + (bar_width - box_width)
    if max_x < min_x { max_x = min_x }

    // Speed so the slider traverses from min to max in ab.time.max seconds
    speed := (max_x - min_x) / ab.time.max

    // Move the box and clamp / flip direction when hitting bounds
    ab.box.min.x += f32(ab.num) * speed * dt
    if ab.box.min.x <= min_x {
        ab.box.min.x = min_x
        ab.num = 1
    } else if ab.box.min.x >= max_x {
        ab.box.min.x = max_x
        ab.num = -1
    }

    // Keep bee synced with slider (same X); you can offset Y if you want it above the slider
    ab.bee.min.x = ab.box.min.x

    // Push updates to renderer
    update_gui(ab.box)
    update_gui(ab.bee)
}

//----------------------------------------------------------------------------\\
// /Dodge qte System
// Desc, Player presses left or right button to dodge bee
// so it randomly chooses which one to target
//----------------------------------------------------------------------------\\
DodgeQTE :: struct{
   time : CurrMax,
   interval : CurrMax,
   left_arrow : ^Cmp_Gui,
   right_arrow : ^Cmp_Gui,
   count : i32,
   dodges : [dynamic]DodgeDir,
   success : bool

}
DodgeDir :: enum{Left = 0,Right = 1,Pause=2}

dodge_qte_init :: proc(qte : ^DodgeQTE, gui_map : ^map[string]Entity){
    qte.left_arrow = get_component(gui_map[lex.QTE_DODGE_LEFT], Cmp_Gui)
    qte.right_arrow = get_component(gui_map[lex.QTE_DODGE_RIGHT], Cmp_Gui)

    assert(qte.left_arrow != nil && qte.right_arrow != nil)
}

dodge_qte_start :: proc(qte : ^DodgeQTE){
    qte.success = false
    qte.count = rand.int32_range(2,5)
    // 1. Create a stack of random lefts or rights for dodges based on count
    for c in 0..<qte.count{
        dir := transmute(DodgeDir)rand.int_range(0,1)
        append(&qte.dodges, dir)
        append(&qte.dodges,DodgeDir.Pause)
    }
    dodge_qte_pop(qte, 0.5)
}

// 2. Pop the first one, set the interval, update_gui
dodge_qte_pop :: proc(qte : ^DodgeQTE, new_interval : f32) -> bool{
    if len(qte.dodges) <= 0 do return false

    dir := pop_front(&qte.dodges)
    dodge_qte_show(dir)
    qte.interval.curr = 0
    qte.interval.max = new_interval

    switch dir{
    case .Left:
        update_gui(qte.left_arrow)
    case .Right:
        update_gui(qte.right_arrow)
    case .Pause:
        update_gui(qte.left_arrow)
        update_gui(qte.right_arrow)
    }
    return true
}

dodge_qte_update :: proc(qte : ^DodgeQTE, dt : f32) -> bool //Return true if you still want to update
{
    // Detect player controls if match continue, if fail dont

    if len(qte.dodges) > 0 {
	   	qte.success = true
		dodge_qte_hide()
	    return false
    }

    qte.interval.curr += dt
    interval_over := qte.interval.curr > qte.interval.max

    d := qte.dodges[0]
    switch d
    {
    case .Left:
        if game_controller_is_moving(){
            axis := game_controller_move_axis()
            if axis.as_int.x == i32(-1) do dodge_qte_pop(qte, 1.5)
            else do return false}
    case .Right:
        if game_controller_is_moving(){
            axis := game_controller_move_axis()
            if axis.as_int.x == i32(1) do dodge_qte_pop(qte, 1.5)
            else do return false}
    case .Pause:
	    if interval_over do return dodge_qte_handle_pause(qte)
    }

    return !interval_over
}

dodge_qte_handle_pause :: proc(qte : ^DodgeQTE) -> bool
{
    if !dodge_qte_pop(qte, 1.5){
        qte.success = true
        return false
    }
    return true
}

dodge_qte_finish :: proc(qte : ^DodgeQTE)
{
    if qte.success do fmt.println("DODGED")
    clear(&qte.dodges)
}

dodge_qte_hide :: proc(){
   ToggleUI(lex.QTE_DODGE_LEFT, false)
   ToggleUI(lex.QTE_DODGE_RIGHT, false)
}

dodge_qte_show :: proc(dir : DodgeDir)
{
    switch dir{
    case .Left:
        ToggleUI(lex.QTE_DODGE_RIGHT, false)
        ToggleUI(lex.QTE_DODGE_LEFT, true)
    case .Right:
        ToggleUI(lex.QTE_DODGE_LEFT, false)
        ToggleUI(lex.QTE_DODGE_RIGHT, true)
    case .Pause:
        dodge_qte_hide()
    }
}

//----------------------------------------------------------------------------\\
// /ves VISUAL EVENT SYSTEM
//----------------------------------------------------------------------------\\
VES_Screen :: enum
{
    None,
    SelectCharacter,
    Movement,
    Action,
    PlayerAttack,
    Animating,
    BeeAttack,
}

VES_State :: enum
{
    Pending,
    Start,
    Update,
    Finished,
}

VES_Type :: enum
{
    AnimateMove, AttackQTE, DodgeQTE, VisualEffect
}

VisualEvent :: struct
{
    type : VES_Type,
    state : VES_State,
    timer : f32,
    character : ^CharacterVariant,
    on_finish : proc(^VisualEvent, ^Battle),
}

VisualEventData :: struct
{
   anim_state : VES_State,
   screen_stack : [dynamic]VES_Screen,
   event_queue : queue.Queue(VisualEvent)
}

ves_process_queue :: proc(battle: ^Battle, ves : ^VisualEventData, dt: f32){
    if queue.len(ves.event_queue) == 0 do return
    event := queue.front_ptr(&ves.event_queue)
    switch event.state{
    case .Pending:
        ves_event_start(event, ves, battle)
        event.state = .Start
    case .Start:
        event.state = .Update
    case .Update:
        if !ves_event_update(event, battle, dt){
            ves_event_finish(event, ves, battle)
            event.state = .Finished
        }
    case .Finished:
        queue.pop_front(&ves.event_queue)
        if event.on_finish != nil do event.on_finish(event, battle)
    }
}

ves_is_busy :: #force_inline proc(ves: ^VisualEventData) -> bool{
    return queue.len(ves.event_queue) > 0
}

ves_event_start :: proc(event: ^VisualEvent, ves: ^VisualEventData, battle: ^Battle) {
    switch event.type{
    case .AnimateMove:
        ves_screen_push(ves,.Animating)
        switch c in event.character{
  		case ^Player:
            ves_animate_player_start(c)
  		case ^Bee:
            ves_animate_bee_start(c)
        }
    case .AttackQTE:
        ves_screen_push(ves, .PlayerAttack)
        attack_qte_start(&battle.attack_bar)
    case .DodgeQTE:
        ves_screen_push(ves, .BeeAttack)
        dodge_qte_start(&battle.dodge_qte)
    case .VisualEffect:
        break
    }
}

ves_event_update :: proc(event: ^VisualEvent, battle: ^Battle, dt: f32) -> bool {
    switch event.type{
    case .AnimateMove:
        switch c in event.character{
  		case ^Player:
            return ves_animate_player(c, dt)
  		case ^Bee:
            return ves_animate_bee(c, dt)
        }
    case .AttackQTE:
        return attack_qte_update(&battle.attack_bar, dt)
    case .DodgeQTE:
        return dodge_qte_update(&battle.dodge_qte, dt)
    case .VisualEffect:
        break
    }
    return false
}

ves_event_finish :: proc(event: ^VisualEvent, ves: ^VisualEventData, battle: ^Battle) {
    switch event.type {
    case .AnimateMove:
    	switch c in event.character {
	    case ^Player:
		    ves_animate_player_end(c)
	    case ^Bee:
		    ves_animate_bee_end(c)
	    }
		ves_clear_screens(ves)
    case .AttackQTE:
        ves_screen_pop(ves)
	   	attack_qte_finish(&battle.attack_bar)
    case .DodgeQTE:
        ves_screen_pop(ves)
        dodge_qte_finish(&battle.dodge_qte)
    case .VisualEffect:
	    break
    }
}


ves_update_all :: proc(battle : ^Battle, ves : ^VisualEventData, dt : f32)
{
    ves_process_queue(battle, ves, dt)
    ves_update_event(battle)
    ves_update_visuals(battle)
}

ves_cleanup :: proc(battle : ^Battle)
{
    for &b in &battle.bees{
        b.flags += b.added
        b.flags -= b.removed
        b.added = {}
        b.removed = {}
    }
    p := &battle.player
    p.flags += p.added
    p.flags -= p.removed
    p.added = {}
    p.removed = {}
}

ves_update_visuals :: proc(battle : ^Battle)
{
	if len(battle.curr_sel.selectables) < 1 do return
	for c in battle.curr_sel.selectables{
	    // c := queue.get(&battle.battle_queue, i)
        if .PlayerFocused in c.added{
	        vc := get_component(c.entity, Cmp_Visual)
			assert(vc != nil)
            vc.flags += {.Focus}
        }
        if .PlayerFocused in c.removed{
            vc := get_component(c.entity, Cmp_Visual)
            assert(vc != nil)
            vc.flags -= {.Focus}
        }
        if .PlayerDodge in c.added{
            vc := get_component(c.entity, Cmp_Visual)
            assert(vc != nil)
            vc.flags += {.Dodge}
        }
        if .PlayerDodge  in c.removed{
            vc := get_component(c.entity, Cmp_Visual)
            assert(vc != nil)
            vc.flags -= {.Dodge}
        }
        if .Alert in c.added || .Overlapping in c.added{
            vc := get_component(c.entity, Cmp_Visual)
            assert(vc != nil)
            vc.flags += {.Alert}
        }
        if .Alert in c.removed{
            vc := get_component(c.entity, Cmp_Visual)
            vc.flags -= {.Alert}
        }
        if .PlayerSelected in c.added{
            vc := get_component(c.entity, Cmp_Visual)
            assert(vc != nil)
            vc.flags += {.Select}
        }
        if .PlayerSelected in c.removed{
            vc := get_component(c.entity, Cmp_Visual)
            assert(vc != nil)
            vc.flags -= {.Select}
        }
    }
}

ves_update_event :: proc(battle : ^Battle)
{
    if .Running in battle.player.added do alert_all_bees(battle)
}

ves_animate_bee :: #force_inline proc(bee : ^Bee, dt : f32) -> bool
{
    if bee.anim.timer > 0 && .Walk == bee.anim_flag {
        slerp_character_to_tile(bee, dt)
        slerp_character_angle(bee,dt)
        return true
    }
    return false
}

ves_animate_bee_start :: proc(bee: ^Bee){
    bee.anim.timer = 1
    bee.anim.rot_timer = .5
    bee.anim_flag = .Walk
    // bee.state = .Moving
    set_up_character_anim(bee, g.battle.grid^)
}

ves_animate_bee_end :: #force_inline proc(bee : ^Bee)
{
    move_entity_to_tile(g.battle.grid^, bee.entity, bee.target)
    bee.pos = bee.target
    bee.anim.timer = 0
}

ves_animate_player :: #force_inline proc(p : ^Player, dt : f32) -> bool{
    if p.anim.timer > 0 && (.Walk == p.anim_flag || .Run == p.anim_flag) {
        slerp_character_to_tile(p, dt)
        slerp_character_angle(p,dt)
        return true
    }
    return false
}

ves_animate_player_start :: #force_inline proc(p : ^Player){
    if (.Walk == p.anim_flag || .Run == p.anim_flag){
        p.anim.timer = 1
        p.anim.rot_timer = .5
        ac := get_component(p.entity, Cmp_Animation)
        if .Walk == p.anim_flag{
            animate_walk(ac, lex.PREFAB_FROKU, p.move_anim)
        }
        else if .Run == p.anim_flag{
            animate_run(ac, lex.PREFAB_FROKU, p.move_anim)
        }
    }
    else if (.Attack == p.anim_flag){
	    p.anim.timer = 1
        p.anim.rot_timer = .5
    	ac := get_component(p.entity, Cmp_Animation)
	   	animate_attack(ac, lex.PREFAB_FROKU, p.attack_anim)
    }
    set_up_character_anim(&p.base, g.battle.grid^)
}

ves_animate_player_end :: #force_inline proc(p : ^Player){
    move_entity_to_tile(g.battle.grid^, p.entity, p.target)
    p.pos = p.target
    p.anim.timer = 0
    ac := get_component(p.entity, Cmp_Animation)
    animate_idle(ac, lex.PREFAB_FROKU, p.move_anim)
    p.removed +=  {.Running}
    p.removed += {.Attack}
}

// Push proc (your #3–5)
ves_screen_push :: proc(ves: ^VisualEventData, new_screen: VES_Screen) {
    if len(ves.screen_stack) > 0 {
    prev := ves.screen_stack[len(ves.screen_stack)-1]
        if prev == new_screen { return } // No-op if same
        ves_screen_on_exit(ves, prev) // Hide prev UIs (your switch)
    }
    append(&ves.screen_stack, new_screen)
    ves_screen_on_enter(ves, new_screen) // Show new UIs (your switch)
}

// Pop for back (add this)
ves_screen_pop :: proc(ves: ^VisualEventData) {
    if len(ves.screen_stack) <= 1 { return } // Don't pop base
    popped := pop(&ves.screen_stack)
    ves_screen_on_exit(ves, popped)
    top := ves.screen_stack[len(ves.screen_stack)-1]
    ves_screen_on_enter(ves, top) // Re-show previous
}

// on_enter switch (your current "turn new screen" switch)
ves_screen_on_enter :: proc(ves: ^VisualEventData, screen: VES_Screen) {
    #partial switch screen {
    case .None: // Nothing
    case .SelectCharacter:
        ToggleUI(lex.UI_MOVE, true)
        ToggleUI(lex.UI_ENEMY_SELECT, true)
    case .Movement:
        ToggleUI(lex.UI_MOVE_WASD, true)
    case .Action:
        ToggleUI(lex.UI_ATTACK, true)
        ToggleUI(lex.UI_FOCUS, true)
        ToggleUI(lex.UI_DODGE, true)
    case .PlayerAttack:
        attack_qte_show()
    }
}

// on_exit switch (your current "turn off all screen" switch)
ves_screen_on_exit :: proc(ves: ^VisualEventData, screen: VES_Screen) {
    #partial switch screen {
    case .None: // Nothing
    case .SelectCharacter:
        ToggleUI(lex.UI_MOVE, false)
        ToggleUI(lex.UI_ENEMY_SELECT, false)
    case .Movement:
        ToggleUI(lex.UI_MOVE_WASD, false)
    case .Action:
        ToggleUI(lex.UI_ATTACK, false)
        ToggleUI(lex.UI_FOCUS, false)
        ToggleUI(lex.UI_DODGE, false)
    case .PlayerAttack:
        attack_qte_hide()
    }
}

ves_clear_screens :: proc(ves : ^VisualEventData){
	if len(ves.screen_stack) > 0 {
		ves_screen_on_exit(ves, ves.screen_stack[0])
		clear(&ves.screen_stack)
	}
	ves_screen_push(ves,.None)
}

ves_top_screen :: #force_inline proc (ves: ^VisualEventData) -> VES_Screen{
	if len(ves.screen_stack) == 0 { return .None }
    return ves.screen_stack[len(ves.screen_stack)-1]
}

//----------------------------------------------------------------------------\\
// /gen GENERATION SYSTEMS
//----------------------------------------------------------------------------\\
create_grid_entity :: proc(name : string, grid: Grid, tile : Tile)
{
    e := load_prefab(name)
    t := get_component(e, Cmp_Transform)
    bot := get_bottom_of_entity(e)
    dy := grid.floor_height - bot
    t.local.pos.y += dy
    t.local.pos.xz = tile.center.xy
}

create_grid_entities :: proc(grid : Grid)
{
    //TODO CHest
    for t in grid.tiles
    {
        if .Wall in t.flags do create_grid_entity("WoodPillar", grid, t)
        else if .Obstacle in t.flags do create_grid_entity("Barrel", grid, t)
    }
}
