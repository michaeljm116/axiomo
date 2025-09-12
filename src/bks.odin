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
import "core:sys/windows"
import "vendor:glfw"

vec2 :: [2]i16
GRID_WIDTH :: 7
GRID_HEIGHT :: 5
s : bufio.Scanner
g_state : GameState = .Start

g_level :Level

Grid :: [][]Tile
Level :: struct
{
    player : Player,
    bees : [dynamic]Bee,
    deck : BeeDeck,
    weapons : []Weapon,
    grid : Grid,
    grid_data : []Tile,
    grid_scale : vec2f
}

bks_main :: proc() {
    windows.SetConsoleOutputCP(windows.CODEPAGE.UTF8)
    track_alloc: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&track_alloc)

	defer {
		fmt.eprintf("\n")
		for _, entry in track_alloc.allocation_map do fmt.eprintf("- %v leaked %v bytes\n", entry.location, entry.size)
		for entry in track_alloc.bad_free_array do fmt.eprintf("- %v bad free\n", entry.location)
		mem.tracking_allocator_destroy(&track_alloc)
		fmt.eprintf("\n")
		free_all(context.temp_allocator)
	}

    bufio.scanner_init(&s, os.stream_from_handle(os.stdin))
    bees := make([dynamic]Bee, 2, context.temp_allocator)
    g_state = .PlayerTurn
    init_level1()
    bufio.scanner_destroy(&s)
}

init_level1 :: proc(alloc : mem.Allocator = context.allocator)
{
    context.allocator = alloc
    using g_level
    g_state = .PlayerTurn
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
    player = {'🧔', vec2{0,2}, 1, db[.Hand], {}}
    bees = make([dynamic]Bee, 2)
    bees[0] = Bee{name = '🐝', pos = vec2{6,2}, health = 2, type = .Aggressive, flags = {}, ent = load_prefab("Bee")}
    bees[1] = Bee{name = '🍯', pos = vec2{6,3}, health = 2, type = .Normal, flags = {}, ent = load_prefab("Bee")}
    player.abilities = make([dynamic]Ability, 2)
    player.abilities[0] = Ability{type = .Dodge, use_on = &bees[0], level = 1, uses = 1}
    player.abilities[1] = Ability{type = .Focused, use_on = &bees[1], level = 1, uses = 1}

    //Shuffle bee BeeDeck
    init_bee_deck(&g_level.deck, 36)
}

run_game :: proc(state : ^GameState, player : ^Player, bees : ^[dynamic]Bee, deck : ^BeeDeck)
{
    switch state^
    {
        case .Start:
            // start_game()
            state^ = .PlayerTurn
            break
        case .PlayerTurn:
            input, moved := get_input()
            if(moved){
                move_player(player, input)
                state^ = .BeesTurn
            }
            break
        case .BeesTurn:
            for &bee in bees do bee_turn(&bee, deck)
            state^ = .PlayerTurn
            break
        case .End:
            // destroy_bee_deck(deck)
            state^ = .Start
            break
        case .Pause:
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

Tile :: enum
{
    Blank,
    Wall,
    Weapon,
    Entity
}

Player :: struct{
    name : rune,
    pos : vec2,
    health : i8,
    weapon : Weapon,
    abilities : [dynamic]Ability,
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

BeeFlag :: enum
{
    Flying,
    Alert,
    Dead
}
BeeFlags :: bit_set[BeeFlag; u8]
Bee :: struct {
    name : rune,
    pos : vec2,
    health : i8,
    type : BeeType,
    flags : BeeFlags,
    ent : Entity
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

//----------------------------------------------------------------------------\\
// /Deck
//----------------------------------------------------------------------------\\
init_bee_deck :: proc(deck : ^BeeDeck, size : int = 36)
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

    queue.init(&deck.deck, 36)
    queue.init(&deck.discard, 36)
    shuffle_deck(&temp_deck)
    for c in temp_deck{
        queue.push_front(&deck.deck, c)
    }
}

shuffle_deck :: proc(deck : ^[dynamic]BeeAction)
{
    for i in 0..<len(deck)
    {
        j := rand.int31() % 36
        deck[i], deck[j] = deck[j], deck[i]
    }
}

//Draw a card from the bee deck, if the deck is blank, refresh
draw_from_bee_deck :: proc(bd : ^BeeDeck, num_cards : int = 1) -> [dynamic]BeeAction
{
    if(queue.len(bd.deck) <= num_cards) do refresh_bee_deck(bd)
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

refresh_bee_deck :: proc(bd : ^BeeDeck){
    queue.clear(&bd.deck)
    queue.destroy(&bd.deck)
    queue.clear(&bd.discard)
    queue.destroy(&bd.discard)
    init_bee_deck(bd, 36)
}

choose_from_mutiple_cards :: proc(cards : [dynamic]BeeAction, priority : [BeeAction]int) -> BeeAction
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
perform_bee_action :: proc(action : BeeAction, bee : ^Bee, player : ^Player)
{
    switch action{
        case .Discard: return
        case .FlyTowards:
            // Fly's 2 blocks towards player, if path overlaps player, alert!
            bee.flags |= {.Flying}
            bee_action_move_towards(bee, player, 2)
        case .FlyAway:
            // Fly 2 blocks away from player, try to avoid walls
            bee.flags |= {.Flying}
            bee_action_move_away(bee, player, 2)
        case .CrawlTowards:
            // crawl towards player, if path overlaps player, alert!
            bee.flags ~= {.Flying}
            bee_action_move_towards(bee, player, 1)
        case .CrawlAway:
            // crawl away from player, if path overlaps player, alert!
            bee.flags ~= {.Flying}
            bee_action_move_away(bee, player, 1)
        case .Sting:
            // If player is near, attack! else do nuffin
            bee_action_attack(bee, player)
    }
    move_entity_to_tile(bee.ent, g_level.grid_scale, bee.pos)
}

bee_action_move_towards :: proc(bee : ^Bee, player : ^Player, target_dist : int){
    assert(target_dist > 0)
    dist := dist_grid(bee.pos, player.pos)
    if dist > target_dist
    {
        path := a_star_find_path(bee.pos, player.pos)
        // TODO: possibly insecure and bug prone if there's no valid distance due to walls
        if len(path) > target_dist do bee.pos = path[target_dist]
        else {if len(path) == target_dist do bee.pos = path[target_dist - 1]}
    }
    else // Less than or equal to target distance, alert!
    {
        bee.flags |= {.Alert}
        if dist == target_dist {
            path := a_star_find_path(bee.pos, player.pos)
            if len(path) > 1 do bee.pos = path[1]
        }
    }
}

bee_action_move_away :: proc(bee : ^Bee, player : ^Player, target_dist : int){
    assert(target_dist > 0)
    target_path := find_best_target_away(bee, player, target_dist, true)
    if len(target_path) > 0 do bee.pos = target_path[len(target_path) - 1]
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
        bee.pos = best
    }
}

bee_action_attack :: proc(bee : ^Bee, player : ^Player){
    dist := dist_grid(bee.pos, player.pos)
    if dist <= 1 {
        player.health -= 1
        fmt.println("PLAYER DIED")
    }
}

bee_turn :: proc(bee : ^Bee, deck : ^BeeDeck){
    if .Dead in bee.flags do return
    cards : [dynamic]BeeAction
    chosen_card : BeeAction

    switch bee.type {
    case .Aggressive:
        cards = draw_from_bee_deck(deck, 2)
        chosen_card = choose_from_mutiple_cards(cards, BeeActionPriority_Aggressive)
    case .Passive:
        draw_from_bee_deck(deck, 2)
        chosen_card = choose_from_mutiple_cards(cards, BeeActionPriority_Passive)
    case .Normal:
        chosen_card = draw_from_bee_deck(deck, 1)[0]
    }

    // fmt.printf("Chosen 🎴: %v\n", chosen_card)
    perform_bee_action(chosen_card, bee, &g_level.player)
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
}

WeaponsDB :: [WeaponType]Weapon{
 .Hand =            Weapon{type = .Hand,            flying = Attack{accuracy = 10, power = 1}, ground = Attack{accuracy = 9, power = 2}, range = 2, effect = {.None}},
 .Shoe =            Weapon{type = .Shoe,            flying = Attack{accuracy =  8, power = 1}, ground = Attack{accuracy = 9, power = 2}, range = 2, effect = {.None}},
 .SprayCan =        Weapon{type = .SprayCan,        flying = Attack{accuracy =  6, power = 2}, ground = Attack{accuracy = 5, power = 2}, range = 3, effect = {.None}},
 .NewsPaper =       Weapon{type = .NewsPaper,       flying = Attack{accuracy =  8, power = 1}, ground = Attack{accuracy = 8, power = 2}, range = 2, effect = {.None}},
 .FlySwatter =      Weapon{type = .FlySwatter,      flying = Attack{accuracy =  7, power = 2}, ground = Attack{accuracy = 7, power = 2}, range = 2, effect = {.None}},
 .ElectricSwatter = Weapon{type = .ElectricSwatter, flying = Attack{accuracy =  7, power = 2}, ground = Attack{accuracy = 7, power = 2}, range = 2, effect = {.None}},
}

pick_up_weapon :: proc(player : ^Player, weaps : []Weapon, db := WeaponsDB)
{
    if len(weaps) == 0 { return }
    idx := int(rand.int31() % i32(len(weaps)))
    wt := weaps[idx].type
    player.weapon = db[wt]
}

player_attack :: proc(player : Player, bee : ^Bee){
    // Player rolls a dice, if its higher than their weapons accuracy, do weapon.damage to the bee
    bee.flags |= {.Alert}
    if .Flying in bee.flags{
       if player.weapon.flying.accuracy < dice_rolls() {
           bee.health -= player.weapon.flying.power
           if bee.health <= 0 do bee.flags += {.Dead}
       }
    }
    else {
       if player.weapon.ground.accuracy < dice_rolls() {
           bee.health -= player.weapon.ground.power
           if bee.health <= 0 do bee.flags += {.Dead}
       }
    }
}

dice_rolls :: proc() -> i8 {
   d1 := rand.int31() % 6 + 1
   d2 := rand.int31() % 6 + 1
   fmt.printf("Dice rolls: %d + %d = %d\n", d1, d2, d1 + d2)
   return i8(d1 + d2)
}

//----------------------------------------------------------------------------\\
// /Game
// Rules:
// 1 action = 1 turn
// Death occurs when health = 0
// Bee's only attack when alerted
//----------------------------------------------------------------------------\\
move_player :: proc(p : ^Player, key : string)
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
        p.pos = bounds
    }
    move_entity_to_tile(g_player, g_level.grid_scale, p.pos)

    if weap_check(p.pos, &g_level.grid) {
        pick_up_weapon(p, g_level.weapons)
    }
    bee_near, b := bee_check(p^, g_level.bees)
    if(bee_near) do player_attack(p^, &g_level.bees[b])
    if .Dead in g_level.bees[b].flags{
        fmt.printfln("Bee %v is dead", g_level.bees[b].name)
        //remove the bee for now
        ordered_remove(&g_level.bees, b)
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

GameState :: enum
{
    Start,
    PlayerTurn,
    BeesTurn,
    End,
    Pause,
}

destroy_level :: proc (scene : ^Level)
{
    queue.destroy(&scene.deck.deck)
    queue.destroy(&scene.deck.discard)
    delete(scene.bees)
    delete(scene.weapons)
    delete(scene.grid_data)
    delete(scene.grid)
    delete(scene.player.abilities)
}

//----------------------------------------------------------------------------\\
// /A-Star Pathfinding
//----------------------------------------------------------------------------\\
pos_equal :: proc(a : vec2, b : vec2) -> bool {
    return a[0] == b[0] && a[1] == b[1]
}

pos_to_index :: proc(p : vec2) -> int {
    return int(p[0]) + int(p[1]) * GRID_WIDTH
}

index_to_pos :: proc(i : int) -> vec2 {
    return vec2{ i16(i % GRID_WIDTH), i16(i / GRID_WIDTH) }
}

in_bounds :: proc(p : vec2) -> bool {
    if p[0] < 0 || p[0] >= i16(GRID_WIDTH) || p[1] < 0 || p[1] >= i16(GRID_HEIGHT) {
        return false
    }
    return true
}

is_walkable :: proc(p : vec2, goal : vec2) -> bool {
    if pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !in_bounds(p) { return false }
    t := g_level.grid[p[0]][p[1]]
    return t == Tile.Blank || t == Tile.Weapon
}

abs_i :: proc(x : int) -> int {
    if x < 0 { return -x }
    return x
}

dist_grid :: proc(a : vec2, b : vec2) -> int {
    dx := abs_i(int(a[0]) - int(b[0]))
    dy := abs_i(int(a[1]) - int(b[1]))
    return dx + dy
}

heuristic :: proc(a : vec2, b : vec2) -> int {
    //Manhattan distance
    return dist_grid(a,b)
}

// Returns path from start to goal as dynamic array of vec2 (start .. goal).
// If no path found, returned array length == 0
total_cells :: GRID_WIDTH * GRID_HEIGHT
a_star_find_path :: proc(start : vec2, goal : vec2) -> [dynamic]vec2 {
    // Static arrays sized for grid
    g_score : [total_cells]int
    f_score : [total_cells]int
    came_from : [total_cells]vec2
    in_open : [total_cells]bool
    closed : [total_cells]bool

    // init
    for i in 0..<total_cells{
        g_score[i] = 999999
        f_score[i] = 999999
        came_from[i] = vec2{-1, -1}
        in_open[i] = false
        closed[i] = false
    }

    start_idx := pos_to_index(start)
    goal_idx := pos_to_index(goal)

    g_score[start_idx] = 0
    f_score[start_idx] = heuristic(start, goal)
    in_open[start_idx] = true

    dirs := [4]vec2{ vec2{1,0}, vec2{-1,0}, vec2{0,1}, vec2{0,-1} }

    // main loop: while any node is in open set
    for {
        // find open node with lowest f_score
        current_idx := -1
        current_f := 999999
        for i in 0..<total_cells {
            if in_open[i] && f_score[i] < current_f {
                current_f = f_score[i]
                current_idx = i
            }
        }
        if current_idx == -1 {
            // open set empty => no path
            path := make([dynamic]vec2, context.temp_allocator)
            return path
        }

        current_pos := index_to_pos(current_idx)

        if current_idx == goal_idx {
            // reconstruct path
            path := make([dynamic]vec2, context.temp_allocator)
            // backtrack
            node_idx := current_idx
            for {
                append(&path, index_to_pos(node_idx))
                if node_idx == start_idx { break }
                parent := came_from[node_idx]
                // if no parent, fail
                if parent[0] == -1 && parent[1] == -1 {
                    // failed reconstruction
                    path = make([dynamic]vec2, context.temp_allocator)
                    return path
                }
                node_idx = pos_to_index(parent)
            }
            // path currently goal..start, reverse to start..goal
            rev := make([dynamic]vec2, context.temp_allocator)
            for i := len(path)-1; i >= 0; i -= 1 {
                append(&rev, path[i])
            }
            return rev
        }

        // move current from open to closed
        in_open[current_idx] = false
        closed[current_idx] = true

        // examine neighbors
        for dir in dirs {
            neighbor := vec2{ current_pos[0] + dir[0], current_pos[1] + dir[1] }
            if !in_bounds(neighbor) { continue }
            if !is_walkable(neighbor, goal) { continue }
            neighbor_idx := pos_to_index(neighbor)
            if closed[neighbor_idx] { continue }

            tentative_g := g_score[current_idx] + 1

            if !in_open[neighbor_idx] || tentative_g < g_score[neighbor_idx] {
                came_from[neighbor_idx] = current_pos
                g_score[neighbor_idx] = tentative_g
                f_score[neighbor_idx] = tentative_g + heuristic(neighbor, goal)
                in_open[neighbor_idx] = true
            }
        }
    }
}

is_walkable_internal :: proc(p : vec2, goal : vec2, allow_through_walls : bool) -> bool {
    if pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !in_bounds(p) { return false }
    t := g_level.grid[p[0]][p[1]]
    if t == Tile.Blank || t == Tile.Weapon { return true }
    if allow_through_walls && t == Tile.Wall { return true }
    return false
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
    if pt == nil do return

    // If we have a floor entity, position relative to the floor so the entity is centered
    // in the tile (and vertically flush with the floor). Otherwise fall back to the
    // simple grid-scale placement.
    ft := get_component(g_floor, Cmp_Transform)
    if ft != nil {
        full_cell_x := 2.0 * scale.x
        full_cell_z := 2.0 * scale.y

        left_x := ft.global.pos.x - ft.global.sca.x
        bottom_z := ft.global.pos.z - ft.global.sca.z

        tile_center_x := left_x + full_cell_x * (f32(pos.x) + 0.5)
        tile_center_z := bottom_z + full_cell_z * (f32(pos.y) + 0.5)

        pt.local.pos.x = tile_center_x
        pt.local.pos.z = tile_center_z

        // Align vertically so the entity's bottom is flush with the floor top.
        floor_top := get_top_of_entity(g_floor)
        entity_bottom := get_bottom_of_entity(entity)

        if entity_bottom != -999999.0 {
            dy := floor_top - entity_bottom
            pt.local.pos.y += dy
        }
    } else {
        // Fallback: previous behavior (scale-only)
        pt.local.pos.x = f32(pos.x) * scale.x
        pt.local.pos.z = f32(pos.y) * scale.y
    }
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
