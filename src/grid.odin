package game

import "core:mem"

//----------------------------------------------------------------------------\\
// /Grid
//----------------------------------------------------------------------------\\
GRID_WIDTH :: 7
GRID_HEIGHT :: 5
grid_size := vec2i{GRID_WIDTH, GRID_HEIGHT}

TileFlag :: enum
{
    Wall,
    Obstacle,
    Weapon,
    Entity,
    Walkable,
    Runnable,
}
TileFlags :: bit_set[TileFlag; u8]
Tile :: struct
{
	flags : TileFlags,
	center : vec2f
}

Grid :: struct{
    tiles : []Tile,
    floor_height : f32,

    width : i32,
    height : i32,
    scale : vec2f,
    weapons : [dynamic]WeaponGrid,
}

grid_create :: proc(size : [2]i32 , alloc : mem.Allocator , scale := vec2f{1.0, 1.0}) -> ^Grid
{
    grid := new(Grid, alloc)
    grid.width = size.x
    grid.height = size.y
    grid.tiles = make([]Tile, grid.width * grid.height, alloc)
    grid.scale = scale
    grid.weapons = make([dynamic]WeaponGrid, alloc)
    return grid
}

// Create tiles from floor
// This will be done by taking the floor's size and dividing it by grid size and calculating fo each
// if floor x = 10 and grid size = 5, each tile is 2 long and center is at 1 aka 0 + .5 tile.size.x
// lets say you're at 3rd tile you'd be at 1..3..5 you'd be at 5 which is (3 - 1) * tile.size.x + .5 tile.size.x
// or maybe 3 * tilesize.x - .5 tile.size.x ?? ultimately just depends where the index starts
// use grid sets to get the actual grid spot since you'll be 0 - size.x then.... yeah
grid_init_floor :: proc(grid : ^Grid, floor_transform : Cmp_Primitive)
{
	floor_pos := floor_transform.world[3].xyz
	floor_ext := floor_transform.extents
    grid.floor_height = floor_pos.y + floor_ext.y
    grid.scale = vec2f{floor_ext.x * 2, floor_ext.z * 2} / vec2f{f32(grid.width), f32(grid.height)}
    tile_interval := grid.scale * 0.5

    // Calculate floor bottom-left corner (floor center - floor extents)
    floor_bottom_left := vec2f{floor_pos.x - floor_ext.x, floor_pos.z - floor_ext.z}

    for x in 0..<grid.width {
    	for y in 0..<grid.height {
      		rc := vec2f{f32(x),f32(y)}
      		center := rc * grid.scale + tile_interval + floor_bottom_left
            grid_get_mut(grid, x, y).center = center

      		// grid_set(grid, x,y, Tile{center = center})
	    }
    }
}

grid_set :: proc{grid_set_i16, grid_set_vec2i}
grid_get :: proc{grid_get_i16, grid_get_vec2i, grid_get_int_p, grid_get_i16_p, grid_get_vec2i_p}
grid_set_flags :: proc{grid_set_flags_i16, grid_set_flags_vec2i}

grid_set_i16 :: proc(grid : ^Grid, x, y : i32, tile : Tile){
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    grid.tiles[y * grid.width + x] = tile
}
grid_set_vec2i :: proc(grid : ^Grid, p : vec2i, tile : Tile){
    assert(p.x >= 0 && p.x < i32(grid.width) && p.y >= 0 && p.y < i32(grid.height))
    grid.tiles[p.y * i32(grid.width) + p.x] = tile
}
grid_set_flags_i16 :: proc(grid : ^Grid, x, y : i32, flags : TileFlags){
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    grid.tiles[y * grid.width + x].flags += flags
}
grid_set_flags_vec2i :: proc(grid : ^Grid, p : vec2i, flags : TileFlags){
    assert(p.x >= 0 && p.x < i32(grid.width) && p.y >= 0 && p.y < i32(grid.height))
    grid.tiles[p.y * i32(grid.width) + p.x].flags += flags
}

grid_get_i16_p :: proc(grid : ^Grid, x, y : i32) -> Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return grid.tiles[y * grid.width + x]
}

grid_get_int_p :: proc(grid : ^Grid, x, y : int) -> Tile {
    assert(x >= 0 && x < int(grid.width) && y >= 0 && y < int(grid.height))
    return grid.tiles[y * int(grid.width) + x]
}
grid_get_vec2i_p :: proc(grid : ^Grid, p : vec2i) -> Tile {
    assert(p.x >= 0 && p.x < grid.width && p.y >= 0 && p.y < grid.height)
    return grid.tiles[p.y * grid.width + p.x]
}
grid_get_i16 :: proc(grid : Grid, x, y : i32) -> Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return grid.tiles[y * grid.width + x]
}

grid_get_vec2i :: proc(grid : Grid, p : vec2i) -> Tile {
    assert(p.x >= 0 && p.x < grid.width && p.y >= 0 && p.y < grid.height)
    return grid.tiles[p.y * grid.width + p.x]
}

grid_get_mut_i16 :: proc(grid: ^Grid, x, y: i32) -> ^Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return &grid.tiles[y * grid.width + x]
}

grid_get_mut_vec2i :: proc(grid: ^Grid, p: vec2i) -> ^Tile {
    assert(p.x >= 0 && p.x < grid.width && p.y >= 0 && p.y < grid.height)
    return &grid.tiles[p.y * grid.width + p.x]
}

grid_get_mut :: proc{grid_get_mut_i16, grid_get_mut_vec2i}

//Set the scale of the level to always match the size of the floor
//So lets say you have a 3 x 3 grid but a 90 x 90 level, 1 grid block is 30

grid_in_bounds :: path_in_bounds

//----------------------------------------------------------------------------\\
// /Pathfinding A* path finding using grid
//----------------------------------------------------------------------------\\
path_pos_equal :: proc(a : vec2i, b : vec2i) -> bool {
    return a[0] == b[0] && a[1] == b[1]
}

path_pos_to_index :: proc(p : vec2i, grid : Grid) -> int {
    return int(p.x + p.y * grid.width)
}

path_index_to_pos :: proc(i : i32, grid : Grid) -> vec2i {
    return vec2i{ i % grid.width, i / grid.width }
}

path_in_bounds :: proc(p : vec2i, grid : Grid) -> bool {
    if p.x < 0 || p.x >= grid.width || p.y < 0 || p.y >= grid.height do return false
    return true
}

path_is_walkable :: proc(p : vec2i, goal : vec2i, grid: Grid) -> bool {
    if path_pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !path_in_bounds(p, grid) { return false }
    t := grid_get(grid,p).flags
    return .Wall not_in t && .Obstacle not_in t
}

path_abs_i :: proc(x : int) -> int {
    if x < 0 { return -x }
    return x
}

path_dist_grid :: proc(a : vec2i, b : vec2i) -> int {
    dx := path_abs_i(int(a[0]) - int(b[0]))
    dy := path_abs_i(int(a[1]) - int(b[1]))
    return dx + dy
}

path_heuristic :: proc(a : vec2i, b : vec2i) -> int {
    //Manhattan distance
    return path_dist_grid(a,b)
}

// Returns path from start to goal as dynamic array of vec2i (start .. goal).
// If no path found, returned array length == 0
path_a_star_find :: proc(start : vec2i, goal, size : vec2i, grid : Grid) -> [dynamic]vec2i {
    // Static arrays sized for grid
    total_cells := len(grid.tiles)
    g_score := make([]int, total_cells, context.temp_allocator)
    f_score := make([]int, total_cells, context.temp_allocator)
    came_from := make([]vec2i, total_cells, context.temp_allocator)
    in_open := make([]bool, total_cells, context.temp_allocator)
    closed := make([]bool, total_cells, context.temp_allocator)

    // init
    for i in 0..<total_cells{
        g_score[i] = 999999
        f_score[i] = 999999
        came_from[i] = vec2i{-1, -1}
        in_open[i] = false
        closed[i] = false
    }

    start_idx := path_pos_to_index(start, grid)
    goal_idx := path_pos_to_index(goal, grid)

    g_score[start_idx] = 0
    f_score[start_idx] = path_heuristic(start, goal)
    in_open[start_idx] = true

    dirs := [4]vec2i{ vec2i{1,0}, vec2i{-1,0}, vec2i{0,1}, vec2i{0,-1} }

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
            path := make([dynamic]vec2i, context.temp_allocator)
            return path
        }

        current_pos := path_index_to_pos(i32(current_idx), grid)

        if current_idx == goal_idx {
            // reconstruct path
            path := make([dynamic]vec2i, context.temp_allocator)
            // backtrack
            node_idx := current_idx
            for {
                append(&path, path_index_to_pos(i32(node_idx), grid))
                if node_idx == start_idx { break }
                parent := came_from[node_idx]
                // if no parent, fail
                if parent[0] == -1 && parent[1] == -1 {
                    // failed reconstruction
                    path = make([dynamic]vec2i, context.temp_allocator)
                    return path
                }
                node_idx = path_pos_to_index(parent, grid)
            }
            // path currently goal..start, reverse to start..goal
            rev := make([dynamic]vec2i, context.temp_allocator)
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
            neighbor := vec2i{ current_pos[0] + dir[0], current_pos[1] + dir[1] }
            if !path_in_bounds(neighbor, grid) { continue }
            if !path_is_walkable(neighbor, goal, grid) { continue }
            neighbor_idx := path_pos_to_index(neighbor, grid)
            if closed[neighbor_idx] { continue }

            tentative_g := g_score[current_idx] + 1

            if !in_open[neighbor_idx] || tentative_g < g_score[neighbor_idx] {
                came_from[neighbor_idx] = current_pos
                g_score[neighbor_idx] = tentative_g
                f_score[neighbor_idx] = tentative_g + path_heuristic(neighbor, goal)
                in_open[neighbor_idx] = true
            }
        }
    }
}

path_is_walkable_internal :: proc(p : vec2i, goal : vec2i, allow_through_obstacles : bool, grid : Grid) -> bool {
    if path_pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !path_in_bounds(p, grid) { return false }
    t := grid_get(grid,p).flags
    if .Wall not_in t && .Obstacle not_in t { return true }
    if allow_through_obstacles && .Obstacle in t { return true }
    return false
}

four_dirs := [4]vec2i{
    { 1,  0},  // right
    {-1,  0},  // left
    { 0,  1},  // up
    { 0, -1},  // down
}

refresh_player_reachability :: proc(grid: ^Grid, pos: vec2i) {
    // Step 1: Clear old reachability flags everywhere
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            pos := vec2i{x, y}
            t := &grid_get_mut(grid, pos).flags
            t^ -= {.Walkable, .Runnable}
        }
    }

    for d in four_dirs {
        // 1 step away
        one := pos + d
        if path_in_bounds(one, grid^) && path_is_walkable(one, pos, grid^) {
            t_one := &grid_get_mut(grid, one).flags
            t_one^ += {.Walkable}

            // 2 steps away (same direction)
            two := pos + d * 2
            if path_in_bounds(two, grid^) && path_is_walkable(two, pos, grid^) {
                t_two := &grid_get_mut(grid, two).flags
                t_two^ += {.Runnable}
            }
        }
    }

    t_player := &grid_get_mut(grid, pos).flags
    t_player^ += {.Walkable}
}
