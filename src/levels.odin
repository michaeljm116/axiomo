package game
import "core:mem"
import "axiom"
import queue "core:container/queue"

start_battle1 :: proc(battle : ^Battle, alloc : mem.Allocator = context.allocator)
{
    context.allocator = alloc
    using battle
    // Clear and initialize grid contiguously
    battle.grid = grid_create({10, 10}, alloc)
    grid_set(grid,2,0,.Weapon)
    grid_set(grid,4,3,.Weapon)
    grid_set(grid,5,0,.Wall)

    // Initialize weapons
    db := WeaponsDB
    weapons = make([]Weapon, len(db))
    for i, w in db do weapons[w] = i

    // Initialize Player and Bee
    player = {name = '🧔', pos = vec2i{0,2}, health = 1, weapon = db[.Hand], abilities = {}}
    bees = make([dynamic]Bee, 2)
    bees[0] = Bee{name = '🐝', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}}
    bees[1] = Bee{name = '🍯', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}}

    player.abilities = make([dynamic]Ability, 2)
    player.abilities[0] = Ability{type = .Dodge, use_on = &bees[0], level = 1, uses = 1}
    player.abilities[1] = Ability{type = .Focused, use_on = &bees[1], level = 1, uses = 1}

    //Shuffle bee BeeDeck
    deck_init(&g.battle.deck, 36)
    init_dice(&g.battle.dice)

    init_variants(battle)
    init_battle_queue(battle, alloc)
}

init_variants :: #force_inline proc(battle : ^Battle){
    battle.player.variant = &battle.player
    for &b in battle.bees do b.variant = &b
}

init_battle_queue :: proc(battle : ^Battle, alloc : mem.Allocator)
{
   count := len(battle.bees) + 1
   queue.init(&battle.battle_queue, count, alloc)
   queue.push(&battle.battle_queue, &battle.player.base)
   for &b in battle.bees do queue.push(&battle.battle_queue, &b)
}


// Levels:
// 1. Make Grid
// 2. Initialize weeapons
// 3. Initialize Player
// 4. Initialize Bees
// 5. Initialize Deck
// 6. Initialize Dice

start_battle2 :: proc(battle : ^Battle, alloc : mem.Allocator = context.allocator)
{
    context.allocator = alloc
    // Clear and initialize grid contiguously

    // add somethings to the grid
    battle.grid = grid_create({10, 10}, alloc)
    grid_set(battle.grid,2,0,.Weapon)
    grid_set(battle.grid,4,3,.Weapon)
    grid_set(battle.grid,5,0,.Wall)

    // Initialize weapons
    db := WeaponsDB
    battle.weapons = make([]Weapon, len(db))
    for i, w in db do battle.weapons[w] = i

    // Initialize Player and Bee
    battle.player = {name = '🧔', pos = vec2i{0,2}, health = 1, weapon = db[.Hand], abilities = {}}
    battle.player.abilities = make([dynamic]Ability, 2)

    battle.bees = make([dynamic]Bee, 3)
    battle.bees[0] = Bee{name = '🐝', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    battle.bees[1] = Bee{name = '🍯', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}, entity = load_prefab("Bee")}
    battle.bees[2] = Bee{name = '🐝', pos = vec2i{6,4}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    for b in battle.bees do add_component(b.entity, Cmp_Visual)

    //Shuffle bee BeeDeck
    deck_init(&g.battle.deck, 36)
    init_dice(&g.battle.dice)

}
