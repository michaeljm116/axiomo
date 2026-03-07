#+feature using-stmt
package game
import "core:mem"
import "axiom"
import queue "core:container/queue"
import "core:encoding/json"
import "core:fmt"

BattleSetup :: struct
{
	grid_size : vec2i,
	player : PlayerSetup,
	tiles : []TileSetup,
	bees : []BeeSetup,
}
TileSetup :: struct
{
	pos : vec2i,
	flags : TileFlags
}
PlayerSetup :: struct
{
	pos : vec2i,
	health : i8,
	weapon : WeaponType
}
BeeSetup :: struct
{
	name : rune,
	pos : vec2i,
	health : i8,
	type : BeeType,
	timer : f32
}

battle_setup :: proc(battle: ^Battle, name : BattleName, alloc : mem.Allocator)
{
	// Get Battle Setup
	bdb := BattleDB
	setup := bdb[name]
	//Set up Grid
	battle.grid = grid_create(setup.grid_size, alloc)
	for tile in setup.tiles do grid_set_flags(battle.grid, tile.pos, tile.flags)

	//Set up bees
	battle.bees = make([dynamic]Bee, len(setup.bees), alloc)
	for bee,i in setup.bees{
		battle.bees[i] = Bee{name = bee.name, pos = bee.pos, health = bee.health, type = bee.type}
		battle.bees[i].timer.max = bee.timer
	}

	// Set up Player
	db := WeaponsDB
	battle.player = {
		name = 'p',
		pos = setup.player.pos,
		health = setup.player.health,
		weapon = db[setup.player.weapon],
	}
}

BattleName :: enum
{
	Battle1,
	Battle2,
}

BattleDB :: [BattleName]BattleSetup{
	.Battle1 = BattleSetup{
		grid_size = {7,5},
		tiles = {
			TileSetup{{2,0},{.Weapon}},
			TileSetup{{4,3},{.Weapon}},
			TileSetup{{3,2},{.Obstacle}},
			TileSetup{{1,0},{.Wall}},
			TileSetup{{5,4},{.Wall}},
		},
		bees = {
			BeeSetup{'a', vec2i{6,2}, 100, .Aggressive, 5},
			BeeSetup{'n', vec2i{6,3}, 100, .Normal, 6}
		},
		player = PlayerSetup{vec2i{0,2}, 1, .Hand}
	},
	.Battle2 = BattleSetup{
		grid_size = {7,5},
		tiles = {
			TileSetup{{3,0},{.Weapon}},
			TileSetup{{2,3},{.Weapon}},
			TileSetup{{4,0},{.Wall}},
		},
		bees = {
			BeeSetup{'a', vec2i{6,2}, 100, .Aggressive, 5},
			BeeSetup{'n', vec2i{6,3}, 100, .Normal, 6}
		},
		player = PlayerSetup{vec2i{0,2}, 1, .Hand}
	}
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

save_level :: proc()
{

}


Room :: struct
{
	using entrance : AreaEntry,
	battle_setup : BattleName,
	is_battle : bool,
	flag : RoomFlag
}

RoomFlag :: enum
{
	Locked,
	Open,
	Visited,
	Completed
}

RoomName :: enum u32
{
	FirstRoom = 1,
	SecondRoom = 2,
}

FloorName :: enum u32
{
	FirstFloor = 1,
}

RoomSave :: struct
{
	fn : FloorName,
	rn : RoomName,
	flag : RoomFlag
}

GameSave :: struct
{
	// bees_killed : u32,
	// last_room : RoomSave,
	rooms : [RoomName]RoomSave,
}

// Basically you want a variable length grid to be saved and even t... wait... you do know one thing...
// room number will always be constant, floor names dont really matter at all, only room numbers too
save_inn :: proc(inn : Inn, gs : ^GameSave)
{
	assert(len(gs.rooms) == len(RoomName))
	for k1, floor in inn.floors do for k2, room in floor.rooms{
		gs.rooms[k2] = RoomSave{k1, k2, room.flag}
	}
	data, marshal_err := json.marshal(gs, json.Marshal_Options{pretty = true}, allocator = context.temp_allocator)
	if marshal_err != nil {
		fmt.eprintf("Error Marshaling Levle Prefab '%s', : %v\n", "assets/config/gamesave.json", marshal_err)
	}
}

load_inn :: proc(inn : ^Inn, gs : GameSave)
{
	// json_err := json.unmarshal()
	for rs in gs.rooms{
		fn := transmute(FloorName)rs.fn
		rn := transmute(RoomName)rs.rn
		room := &inn.floors[fn].rooms[rn]
		room.flag = rs.flag
	}
}

Floor :: struct
{
	using entrance : AreaEntry,
	rooms : map[RoomName]Room,
}

Inn :: struct
{
	floors : map[FloorName]Floor,
}

AreaEntry :: struct
{
	entry : AreaTrigger,
	exit : AreaTrigger,
}

AreaTrigger :: struct
{
	dir : Direction,
	can_enter : bool,
	pos : vec2f,
	len : f32,
}
// Direction :: enum{Up,Down,Left,Right}

AreaType :: enum{Inn, Floor, Room}
