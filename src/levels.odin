package game
import "core:mem"
import "axiom"
import queue "core:container/queue"

battle_setup_1 :: proc(battle : ^Battle, alloc : mem.Allocator = context.allocator)
{
    using battle
    // Clear and initialize grid contiguously
    battle.grid = grid_create({10, 10}, alloc)
    grid_set(grid,2,0,.Weapon)
    grid_set(grid,4,3,.Weapon)
    grid_set(grid,5,0,.Wall)

    // Initialize Player and Bee
    bees = make([dynamic]Bee, 2, alloc)
    player = {name = '🧔', pos = vec2i{0,2}, health = 1, weapon = WeaponsDB[.Hand]}
    bees[0] = Bee{name = '🐝', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}}
    bees[1] = Bee{name = '🍯', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}}

    init_battle(battle, alloc)
}

battle_setup_2 :: proc(battle : ^Battle, alloc : mem.Allocator = context.allocator)
{
    // add somethings to the grid
    battle.grid = grid_create({10, 10}, alloc)
    grid_set(battle.grid,2,0,.Weapon)
    grid_set(battle.grid,4,3,.Weapon)
    grid_set(battle.grid,5,0,.Wall)

    // Initialize Player and Bee
    battle.player = {name = '🧔', pos = vec2i{0,2}, health = 1, weapon = WeaponsDB[.Hand]}
    battle.bees = make([dynamic]Bee, 3)
    battle.bees[0] = Bee{name = '🐝', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    battle.bees[1] = Bee{name = '🍯', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}, entity = load_prefab("Bee")}
    battle.bees[2] = Bee{name = '🐝', pos = vec2i{6,4}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}

    init_battle(battle, alloc)
}

init_battle :: proc(battle : ^Battle, alloc : mem.Allocator)
{
	//Shuffle bee BeeDeck
    deck_init(&battle.deck, 36)
    init_dice(&battle.dice)

    init_weapons(battle)
    init_variants(battle)
    init_battle_queue(battle, alloc)

}
init_battle_Visuals :: proc(battle : ^Battle){
	for &bee in battle.bees do init_bee_entity(&bee)
    add_component(battle.player.entity, Cmp_Visual)
    init_dice_entities(&battle.dice)
}

init_weapons :: #force_inline proc(battle : ^Battle){
    db := WeaponsDB
    battle.weapons = make([]Weapon, len(db))
    for i, w in db do battle.weapons[w] = i
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
