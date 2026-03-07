#+feature using-stmt
package game
import "core:mem"
import "axiom"
import queue "core:container/queue"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import lex"lexicon"

//----------------------------------------------------------------------------\\
// /Database /db
//----------------------------------------------------------------------------\\
BattleDB :: [BattleName]BattleSetup{
    .None = {},
	.Battle1 = BattleSetup{
	    scene = lex.BEE_KILLINGS_INN,
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
	    scene = lex.BEE_KILLINGS_INN,
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

RoomsDB :: [RoomName]RoomDBColumn{
    .FirstRoom = {
        .FirstFloor,
        .Battle1,
        AreaEntry{
            entry = AreaTrigger{
                dir = .Right,
                can_enter = true,
                pos = {20, 0},
                len = 5
            },
            exit = AreaTrigger{
                dir = .Left,
                can_enter = true,
                pos = {18, 0},
                len = 5
            }
        }
    },
    .SecondRoom = {
        .FirstFloor,
        .Battle2,
        AreaEntry{
            entry = AreaTrigger{
                dir = .Left,
                can_enter = true,
                pos = {-20, 0},
                len = 5
            },
            exit = AreaTrigger{
                dir = .Right,
                can_enter = true,
                pos = {-18, 0},
                len = 5
            }
        }
    }
}

FloorsDB :: [FloorName]FloorDBColumn{
    .FirstFloor = {}
}

//----------------------------------------------------------------------------\\
// /Enums
//----------------------------------------------------------------------------\\
AreaType :: enum{Inn, Floor, Room,}
RoomFlag :: enum u8{Locked,Open,Visited,Completed,}

BattleName :: enum{None, Battle1, Battle2,}
RoomName :: enum u32{FirstRoom = 0, SecondRoom = 1,}
FloorName :: enum u32{FirstFloor,}

//----------------------------------------------------------------------------\\
// /Strcts
//----------------------------------------------------------------------------\\

BattleSetup :: struct
{
	grid_size : vec2i,
	player : PlayerSetup,
	tiles : []TileSetup,
	bees : []BeeSetup,
	scene : string
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
RoomDBColumn :: struct
{
    floor_name : FloorName,
    battle_name : BattleName,
    entrance : AreaEntry,
}
FloorDBColumn :: struct
{
    entrance : AreaEntry
}
Floor :: struct
{
	using entrance : AreaEntry,
	rooms : map[RoomName]Room,
}
Inn :: struct
{
    curr : RoomName,
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
Room :: struct
{
	using entrance : AreaEntry,
	battle_name : BattleName,
	flag : RoomFlag
}

//----------------------------------------------------------------------------\\
// /Setup /Inits
//----------------------------------------------------------------------------\\
setup_battle :: proc(battle: ^Battle, name : BattleName, alloc : mem.Allocator)
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

init_battle_chests :: proc(battle: ^Battle)
{
    for tile, i in battle.grid.tiles{
        if .Weapon in tile.flags
        {
           pos := grid_get_pos(battle.grid^, i)
           create_grid_chest(pos, battle)
        }
    }
}

//----------------------------------------------------------------------------\\
// /Serialize
//----------------------------------------------------------------------------\\
RoomSave :: struct
{
	fn : FloorName,
	rn : RoomName,
	flag : RoomFlag
}
GameSave :: struct{rooms : [RoomName]RoomFlag,}

save_inn :: proc(inn: Inn, filename := "assets/config/gamesave.json")
{
    // Set up gamesave data structure
    gs := GameSave{}
    assert(len(gs.rooms) == len(RoomName))
	for k1, floor in inn.floors  {
	for k2, room  in floor.rooms {
		gs.rooms[k2] = room.flag
	}}

	// Save data to file
    data, err := json.marshal(gs, json.Marshal_Options{pretty = true})
    if err != nil {
        fmt.eprintf("Marshal error: %v\n", err)
        return
    }
    if !os.write_entire_file(filename, data) {
        fmt.eprintf("Failed to write save file\n")
    }
    else do fmt.println("Saved game")
}

load_inn :: proc(inn: ^Inn, filename := "assets/config/gamesave.json")
{
    //Load File
    data, ok := os.read_entire_file(filename)
    if !ok do fmt.panicf("Failed to load save file: %s", filename)
    defer delete(data)

    // Unmarshal json
    gs: GameSave
    if json.unmarshal(data, &gs) != nil do fmt.panicf("Failed to unmarshal save file: %s", filename)

    // Load data into memory
    for saved_flag, saved_room_name in gs.rooms{
        room, _ := find_room_and_floor(inn, saved_room_name)
        if room != nil do room.flag = saved_flag
        else do fmt.printf("Warning: Saved room '%v' not found", saved_room_name)
    }

    //print out floors
    for k,v in inn.floors[.FirstFloor].rooms do fmt.println("Room: ", k, " Flag: ", v.flag )
}

init_inn :: proc(inn: ^Inn, alloc : mem.Allocator) {
    // First make Floors
    inn.floors = make(map[FloorName]Floor, 4, alloc)
    for floor_data, floor_name in FloorsDB {
        inn.floors[floor_name] = Floor{
            entrance = floor_data.entrance,
            rooms    = make(map[RoomName]Room, 8, alloc),
        }
    }

    // Then make rooms on the floors
    for room_data, room_name in RoomsDB {
        if floor, ok := &inn.floors[room_data.floor_name]; ok {
            floor.rooms[room_name] = Room{
                entrance    = room_data.entrance,
                battle_name = room_data.battle_name,
                flag        = room_name == .FirstRoom ? .Open : .Locked,
            }
        }
    }

    for k,v in inn.floors do for rk, rv in v.rooms do fmt.println("Room: ", rk, " Flag: ", rv.flag )
    inn.curr = .FirstRoom
}

RoomAndFloor :: struct {
    floor: ^Floor,
    room:  ^Room,
    found: bool,
}

find_room_and_floor :: proc(inn: ^Inn, room_name: RoomName) -> (^Room, ^Floor) {
    assert(len(inn.floors) == len(FloorName))
    for key, &floor in inn.floors {
        room, ok := &floor.rooms[room_name]
        if ok do return room, &floor
    }
    return nil, nil
}

get_curr_battle_name :: proc(inn: ^Inn) -> BattleName
{
    rd := RoomsDB
    return rd[inn.curr].battle_name
}

unlock_next_room :: proc(inn : ^Inn)
{
   next := transmute(u32)inn.curr + 1
   if next >= len(RoomName) do return

   next_room, floor := find_room_and_floor(inn, transmute(RoomName)next)
   next_room.flag = .Open
}