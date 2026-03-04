#+feature using-stmt
package game
import "core:mem"
import "axiom"
import queue "core:container/queue"

battle_setup_1 :: proc(battle : ^Battle, alloc : mem.Allocator = context.allocator)
{
    using battle
    // Clear and initialize grid contiguously
    battle.grid = grid_create({7, 5}, alloc)
    grid_set_flags(grid,2,0,{.Weapon})
    grid_set_flags(grid,4,3,{.Weapon})
    grid_set_flags(grid,3,2,{.Obstacle})
    grid_set_flags(grid,1,0,{.Wall})
    grid_set_flags(grid,5,4,{.Wall})
    // Initialize Player and Bee
    bees = make([dynamic]Bee, 2, alloc)
    player = {name ='p', pos = vec2i{0,2}, health = 1, weapon = WeaponsDB[.Hand], added = {}, removed = {}, flags = {}}
    bees[0] = Bee{name = 'a', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}}
    bees[1] = Bee{name = 'n', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}}

    bees[0].timer.max = 5
    bees[1].timer.max = 6
}

battle_setup_2 :: proc(battle : ^Battle, alloc : mem.Allocator = context.allocator)
{
    // add somethings to the grid
    using battle
    grid = grid_create({7, 5}, alloc)
    grid_set_flags(grid,3,0,{.Weapon})
    grid_set_flags(grid,2,3,{.Weapon})
    grid_set_flags(grid,4,0,{.Wall})

    // Initialize Player and Bee
    player = {name = 'p', pos = vec2i{0,2}, health = 1, weapon = WeaponsDB[.Hand]}
    bees = make([dynamic]Bee, 3)
    bees[0] = Bee{name = 'a', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}}
    bees[1] = Bee{name = 'n', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}}
    bees[0] = Bee{name = '2', pos = vec2i{6,4}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}}
}

init_battle :: proc(battle : ^Battle, alloc : mem.Allocator)
{
	//Shuffle bee BeeDeck
    deck_init_attacky(&battle.deck, 36)

    init_weapons(battle)
    init_variants(battle)
    init_battle_queue(battle, alloc)
    battle_selection_init(battle, &battle.curr_sel, alloc)
}

init_battle_visuals :: proc(battle : ^Battle, alloc : mem.Allocator){
	for &bee in battle.bees do init_bee_entity(&bee, alloc)
    add_component(battle.player.entity, Cmp_Visual)
    attack_qte_init(&battle.attack_qte, &g_gui)
    dodge_qte_init(&battle.dodge_qte, &g_gui)
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
   queue.push(&battle.battle_queue, &battle.player.base)
   for &b in battle.bees{
       queue.push(&battle.battle_queue, &b)
       queue.push(&battle.battle_queue, &b)
   }
}

LevelBit :: enum u64
{
    Level_1,
    Level_2,
    Level_3,
    Level_4,
    Level_5,
    Level_6,
    Level_7,
    Level_8,
    Level_9,
    Level_10,
}
LevelSet :: bit_set[LevelBit; u64]
ComponentFlags :: bit_set[ComponentFlag; u32]

get_level_sum :: proc(ls : LevelSet)
{
    sum := 0
    for i in 0..<size_of(LevelBit)
    {
        sum +=
    }
}

SaveFile :: struct
{
   levels_completed : LevelSet
}
save_level :: proc()
{

}