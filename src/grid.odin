package game

import "core:mem"

GRID_WIDTH :: 7
GRID_HEIGHT :: 5
grid_size := vec2i{GRID_WIDTH, GRID_HEIGHT}
// g_saftey_bee : Bee
Grid :: struct{
    data : []Tile,
    width : u8,
    height : u8,
    scale : vec2f,
    weapons : [dynamic]WeaponGrid
}

grid_create :: proc(size : [2]u8 , alloc : mem.Allocator , scale := vec2f{1.0, 1.0}) -> ^Grid
{
    grid := new(Grid, alloc)
    grid.width = size.x
    grid.height = size.y
    grid.data = make([]Tile, grid.width * grid.height, alloc)
    grid.scale = scale
    grid.weapons = make([dynamic]WeaponGrid, alloc)
    return grid
}

grid_set :: proc{grid_set_u8, grid_set_vec2i}
grid_set_u8 :: proc(grid : ^Grid, x, y : u8, tile : Tile){
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    grid.data[y * grid.width + x] = tile
}
grid_set_vec2i :: proc(grid : ^Grid, p : vec2i, tile : Tile){
    assert(p.x >= 0 && p.x < i16(grid.width) && p.y >= 0 && p.y < i16(grid.height))
    grid.data[p.y * i16(grid.width) + p.x] = tile
}

grid_get :: proc{grid_get_u8, grid_get_int, grid_get_vec2i, grid_get_no_ptr_u8, grid_get_no_ptr_i16, grid_get_no_ptr_vec2i}

grid_get_u8 :: proc(grid : ^Grid, x, y : u8) -> Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return grid.data[y * grid.width + x]
}

grid_get_int :: proc(grid : ^Grid, x, y : int) -> Tile {
    assert(x >= 0 && x < int(grid.width) && y >= 0 && y < int(grid.height))
    return grid.data[y * int(grid.width) + x]
}
grid_get_vec2i :: proc(grid : ^Grid, p : vec2i) -> Tile {
    assert(p.x >= 0 && p.x < i16(grid.width) && p.y >= 0 && p.y < i16(grid.height))
    return grid.data[p.y * i16(grid.width) + p.x]
}
grid_get_no_ptr_u8 :: proc(grid : Grid, x, y : u8) -> Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return grid.data[y * grid.width + x]
}

grid_get_no_ptr_i16 :: proc(grid : Grid, x, y : i16) -> Tile {
    assert(x >= 0 && x < i16(grid.width) && y >= 0 && y < i16(grid.height))
    return grid.data[y * i16(grid.width) + x]
}

grid_get_no_ptr_vec2i :: proc(grid : Grid, p : vec2i) -> Tile {
    assert(p.x >= 0 && p.x < i16(grid.width) && p.y >= 0 && p.y < i16(grid.height))
    return grid.data[p.y * i16(grid.width) + p.x]
}
