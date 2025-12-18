package game
import "core:mem"
import "axiom"

start_level1 :: proc(level : ^Level, alloc : mem.Allocator = context.allocator)
{
    context.allocator = alloc
    using level
    // Clear and initialize grid contiguously
    level.grid = grid_create({10, 10}, alloc)
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
    bees[0] = Bee{name = '🐝', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    bees[1] = Bee{name = '🍯', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}, entity = load_prefab("Bee")}

    player.abilities = make([dynamic]Ability, 2)
    player.abilities[0] = Ability{type = .Dodge, use_on = &bees[0], level = 1, uses = 1}
    player.abilities[1] = Ability{type = .Focused, use_on = &bees[1], level = 1, uses = 1}

    //Shuffle bee BeeDeck
    deck_init(&g.level.deck, 36)

    //Set up visuals over bee
    for b in bees do add_component(b.entity, Cmp_Visual)
    for &dice, i in g.dice{
        dice = Dice{num = i8(i)}//, entity = g_gui["Dice"]}
        dice.time.max = 1.0
        dice.interval.max = 0.16
    }
    g.dice.x.entity = g_gui["Dice1"]
    g.dice.y.entity = g_gui["Dice2"]
    for &d, i in g.dice {
        gc := get_component(d.entity, Cmp_Gui)
        gc.alpha = 0.0
        gc.min.x += (f32(i) * 0.16)
        update_gui(gc)
    }
}

// Levels:
// 1. Make Grid
// 2. Initialize weeapons
// 3. Initialize Player
// 4. Initialize Bees
// 5. Initialize Deck
// 6. Initialize Dice

start_level2 :: proc(level : ^Level, alloc : mem.Allocator = context.allocator)
{
    context.allocator = alloc
    // Clear and initialize grid contiguously

    // add somethings to the grid
    level.grid = grid_create({10, 10}, alloc)
    grid_set(level.grid,2,0,.Weapon)
    grid_set(level.grid,4,3,.Weapon)
    grid_set(level.grid,5,0,.Wall)

    // Initialize weapons
    db := WeaponsDB
    level.weapons = make([]Weapon, len(db))
    for i, w in db do level.weapons[w] = i

    // Initialize Player and Bee
    level.player = {name = '🧔', pos = vec2i{0,2}, health = 1, weapon = db[.Hand], abilities = {}}
    level.player.abilities = make([dynamic]Ability, 2)

    level.bees = make([dynamic]Bee, 3)
    level.bees[0] = Bee{name = '🐝', pos = vec2i{6,2}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    level.bees[1] = Bee{name = '🍯', pos = vec2i{6,3}, target = vec2i{6,3}, health = 100, type = .Normal, flags = {}, entity = load_prefab("Bee")}
    level.bees[2] = Bee{name = '🐝', pos = vec2i{6,4}, target = vec2i{6,2}, health = 100, type = .Aggressive, flags = {}, entity = load_prefab("AggressiveBee")}
    for b in level.bees do add_component(b.entity, Cmp_Visual)


    //Shuffle bee BeeDeck
    deck_init(&g.level.deck, 36)

    //Set up visuals over bee
    for &dice, i in g.dice{
        dice = Dice{num = i8(i)}
        dice.time.max = 1.0
        dice.interval.max = 0.16
    }
    g.dice.x.entity = g_gui["Dice1"]
    g.dice.y.entity = g_gui["Dice2"]
    for &d, i in g.dice {
        gc := get_component(d.entity, Cmp_Gui)
        gc.alpha = 0.0
        gc.min.x += (f32(i) * 0.16)
        update_gui(gc)
    }
}
