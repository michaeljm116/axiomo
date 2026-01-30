package game

import "core:mem"

//----------------------------------------------------------------------------\\
// /Grid
//----------------------------------------------------------------------------\\
GRID_WIDTH :: 7
GRID_HEIGHT :: 5
grid_size := vec2i{GRID_WIDTH, GRID_HEIGHT}

Grid :: struct{
    data : []Tile,
    width : i16,
    height : i16,
    scale : vec2f,
    weapons : [dynamic]WeaponGrid
}

grid_create :: proc(size : [2]i16 , alloc : mem.Allocator , scale := vec2f{1.0, 1.0}) -> ^Grid
{
    grid := new(Grid, alloc)
    grid.width = size.x
    grid.height = size.y
    grid.data = make([]Tile, grid.width * grid.height, alloc)
    grid.scale = scale
    grid.weapons = make([dynamic]WeaponGrid, alloc)
    return grid
}

grid_set :: proc{grid_set_i16, grid_set_vec2i}
grid_get :: proc{grid_get_i16, grid_get_vec2i, grid_get_int_p, grid_get_i16_p, grid_get_vec2i_p}

grid_set_i16 :: proc(grid : ^Grid, x, y : i16, tile : Tile){
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    grid.data[y * grid.width + x] = tile
}
grid_set_vec2i :: proc(grid : ^Grid, p : vec2i, tile : Tile){
    assert(p.x >= 0 && p.x < i16(grid.width) && p.y >= 0 && p.y < i16(grid.height))
    grid.data[p.y * i16(grid.width) + p.x] = tile
}
grid_get_i16_p :: proc(grid : ^Grid, x, y : i16) -> Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return grid.data[y * grid.width + x]
}

grid_get_int_p :: proc(grid : ^Grid, x, y : int) -> Tile {
    assert(x >= 0 && x < int(grid.width) && y >= 0 && y < int(grid.height))
    return grid.data[y * int(grid.width) + x]
}
grid_get_vec2i_p :: proc(grid : ^Grid, p : vec2i) -> Tile {
    assert(p.x >= 0 && p.x < grid.width && p.y >= 0 && p.y < grid.height)
    return grid.data[p.y * grid.width + p.x]
}
grid_get_i16 :: proc(grid : Grid, x, y : i16) -> Tile {
    assert(x >= 0 && x < grid.width && y >= 0 && y < grid.height)
    return grid.data[y * grid.width + x]
}

grid_get_vec2i :: proc(grid : Grid, p : vec2i) -> Tile {
    assert(p.x >= 0 && p.x < grid.width && p.y >= 0 && p.y < grid.height)
    return grid.data[p.y * grid.width + p.x]
}

//Set the scale of the level to always match the size of the floor
//So lets say you have a 3 x 3 grid but a 90 x 90 level, 1 grid block is 30
grid_set_scale :: proc(floor : Entity, grid : ^Grid)
{
    assert(grid.width > 0 && grid.height > 0)
    tc := get_component(floor, Cmp_Transform)
    if tc == nil do return

    grid.scale.x = tc.global.sca.x / f32(grid.width)
    grid.scale.y = tc.global.sca.z / f32(grid.height)
}
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

path_index_to_pos :: proc(i : i16, grid : Grid) -> vec2i {
    return vec2i{ i % grid.width, i / grid.width }
}

path_in_bounds :: proc(p : vec2i, grid : Grid) -> bool {
    if p.x < 0 || p.x >= grid.width || p.y < 0 || p.y >= grid.height {
        return false
    }
    return true
}

path_is_walkable :: proc(p : vec2i, goal : vec2i, grid: Grid) -> bool {
    if path_pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !path_in_bounds(p, grid) { return false }
    t := grid_get(grid,p)
    return .Blank in t || .Weapon in t
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
    total_cells := len(grid.data)
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

        current_pos := path_index_to_pos(i16(current_idx), grid)

        if current_idx == goal_idx {
            // reconstruct path
            path := make([dynamic]vec2i, context.temp_allocator)
            // backtrack
            node_idx := current_idx
            for {
                append(&path, path_index_to_pos(i16(node_idx), grid))
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

path_is_walkable_internal :: proc(p : vec2i, goal : vec2i, allow_through_walls : bool, grid : Grid) -> bool {
    if path_pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !path_in_bounds(p, grid) { return false }
    t := grid_get(grid,p)
    if .Blank in t || .Weapon in t { return true }
    if allow_through_walls && .Wall in t { return true }
    return false
}

path_set_walkable_runnable :: proc(pos, goal : vec2i, grid : ^Grid, walkable, runable : ^map[vec2i]bool)
{
    dirs := [4]vec2i{ vec2i{1,0}, vec2i{-1,0}, vec2i{0,1}, vec2i{0,-1} }
    for d in dirs {
        one_step := vec2i{ pos[0] + d[0], pos[1] + d[1] }
        if path_is_walkable(one_step, goal, grid^) {
            walkable[one_step] = true

            two_step := vec2i{ pos[0] + d[0]*2, pos[1] + d[1]*2 }
            if path_is_walkable(two_step, goal, grid^) {
                runable[two_step] = true
            }
        }
    }
}
