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

Direction :: enum u8 {
    None   = 0,
    Up     = 1 << 0,
    Down   = 1 << 1,
    Left   = 1 << 2,
    Right  = 1 << 3,
}
compute_direction :: proc(v : vec2i) -> Direction
{
    y_bits := (u8(v.y > 0) << 0) | (u8(v.y < 0) << 1)
    x_bits := (u8(v.x > 0) << 3) | (u8(v.x < 0) << 2)
    return transmute(Direction)(y_bits | x_bits)
}

Grid :: struct{
    tiles : []Tile,
    floor_height : f32,

    width : i32,
    height : i32,
    scale : vec2f,
    weapons : [dynamic]WeaponGrid,
    texture : GridTexture,
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
    // Include tile interval offset so origin matches where tile centers actually are
    grid.texture.origin = floor_bottom_left + grid.scale * 0.5

    for x in 0..<grid.width {
    	for y in 0..<grid.height {
       		rc := vec2f{f32(x),f32(y)}
       		center := rc * grid.scale + tile_interval + floor_bottom_left
            grid_get_mut(grid, x, y).center = center

            // Store first tile center as texture origin
            if x == 0 && y == 0 {
                grid.texture.origin = center
            }

       		// grid_set(grid, x,y, Tile{center = center})
	    }
    }
    grid_texture_init(grid, 0.05, {0,1,1,.3})
    data_texture_update()
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
path_a_star_find :: proc(start : vec2i, goal, size : vec2i, grid : Grid, allow_over_obstacles : bool) -> [dynamic]vec2i {
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
            if !path_is_walkable_internal(neighbor, goal, allow_over_obstacles, grid) { continue }
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

// Call this every time player or any bee moves
refresh_visibility :: proc(battle: ^Battle) {
    player_pos := battle.player.pos

    for &bee in battle.bees {
        if .Dead in bee.flags {
            bee.flags -= {.Alert}
            continue
        }

        if can_see_target(battle.grid^, bee.pos, bee.facing, player_pos) {
            bee.added += {.Alert}
        } else {
            bee.removed += {.Alert}
        }
    }
}

// Returns true if (tx,ty) is inside the 90° cone of the viewer facing
in_fov_cone :: proc(sx, sy, tx, ty: i32, facing: Direction, max_range: i32 = 12) -> bool {
    dx := tx - sx
    dy := ty - sy
    manhattan := abs(dx) + abs(dy)
    if manhattan == 0 do return true
    if manhattan > max_range {
        return false
    }

    switch facing {
        case .Right: return dx >= 0 && abs(dy) <= dx      // 90° right quadrant
        case .Left:  return dx <= 0 && abs(dy) <= -dx
        case .Down:  return dy >= 0 && abs(dx) <= dy
        case .Up:    return dy <= 0 && abs(dx) <= -dy
        case .None: return true
    }
    return true
}

// Bresenham's Line Algorithm - Grid LOS
has_clear_los :: proc(grid: Grid, sx, sy, tx, ty: i32) -> bool {
    if sx == tx && sy == ty {
        return true
    }

    dx := abs(tx - sx)
    dy := abs(ty - sy)
    x_step :i32= tx > sx ? 1 : -1
    y_step :i32= ty > sy ? 1 : -1

    err := dx - dy
    x, y := sx, sy

    for {
        e2 := 2 * err

        if e2 > -dy {
            err -= dy
            x += x_step
        }
        if e2 < dx {
            err += dx
            y += y_step
        }

        if x == tx && y == ty {
            return true // Reached target
        }

        // Check blocking tile
        tile := grid_get(grid, x, y)
        if .Wall in tile.flags || .Obstacle in tile.flags {
            return false
        }
    }
}

// Combined check
can_see_target :: proc(grid: Grid, viewer_pos: vec2i, viewer_facing: Direction, target_pos: vec2i, max_range := i32(12)) -> bool {
    return in_fov_cone(viewer_pos.x, viewer_pos.y, target_pos.x, target_pos.y, viewer_facing, max_range) &&
           has_clear_los(grid, viewer_pos.x, viewer_pos.y, target_pos.x, target_pos.y)
}

//----------------------------------------------------------------------------\\
// /GRID TEXTURE /gt
//----------------------------------------------------------------------------\\
// Data texture layout:
// (0,0) = grid_dims: R=grid_width, G=grid_height, B=cell_size*25 (0-255->0-10), A=line_thickness*1000 (0-255->0-0.255)
// (0,1) = line_color: R=line_r, G=line_g, B=line_b, A=unused
// (1+x, y) = grid cell (x, y) color

GridTexture :: struct {
    size: vec2i,
    cell_size: vec2f,
    line_thickness: f32,
    line_color: [4]f32,
    origin: vec2f,
}

GridColor :: enum u8 {
    Empty   = 0,
    Red     = 1,
    Blue    = 2,
    Green   = 3,
    Yellow  = 4,
    Purple  = 5,
    Cyan    = 6,
    White   = 7,
}

GRID_COLOR_TABLE := [8][4]f32{
    {0,   0,   0,   0},   // Empty   - transparent
    {1.0, 0,   0,   1.0},  // Red
    {0,   0,   1.0, 1.0},  // Blue
    {0,   1.0, 0,   1.0},  // Green
    {1.0, 1.0, 0,   1.0},  // Yellow
    {0.5, 0,   0.5, 1.0},  // Purple
    {0,   1.0, 1.0, 1.0},  // Cyan
    {1.0, 1.0, 1.0, 1.0},  // White
}

float_to_bytes :: proc(f:f32) -> [4]u8 {
    bits := transmute(u32)f
    return [4]u8{
        u8(bits & 0xFF),
        u8((bits >> 8) & 0xFF),
        u8((bits >> 16) & 0xFF),
        u8((bits >> 24) & 0xFF),
    }
}

grid_texture_init :: proc(grid: ^Grid, line_thickness: f32, line_color: [4]f32) {
    grid.texture.size = {grid.width, grid.height}
    grid.texture.cell_size = grid.scale.xy
    grid.texture.line_thickness = line_thickness
    grid.texture.line_color = line_color
    grid_texture_sync_to_gpu(&grid.texture)
}

// grid_texture_sync_to_gpu :: proc(gt: ^GridTexture) {
//     cell_byte := u8(gt.cell_size * 25.0)
//     line_byte := u8(gt.line_thickness * 1000.0)
//     data_texture_set({0, 0}, {u8(gt.size.x), u8(gt.size.y), cell_byte, line_byte})
//     data_texture_set({0, 1}, {gt.line_color[0], gt.line_color[1], gt.line_color[2], gt.line_color[3]})
// }

grid_texture_sync_to_gpu :: proc(gt: ^GridTexture) {
    wr_offset := f32(gt.size.x) + 1.0
    data_texture_set({0, 0}, {f32(gt.size.x), wr_offset, 0, 0})
    data_texture_set({0, 1}, {f32(gt.size.y), gt.origin.x, 0, 0})
    data_texture_set({0, 2}, {gt.cell_size.x, gt.origin.y, 0, 0})
    data_texture_set({0, 3}, {gt.cell_size.y, 0, 0, 0})
    data_texture_set({0, 4}, {gt.line_thickness, 0, 0, 0})
    data_texture_set({0, 5}, {gt.line_color[0], gt.line_color[1], gt.line_color[2], gt.line_color[3]})
    data_texture_update()
}

grid_texture_set_cell_size :: proc(gt: ^GridTexture, cell_size: vec2f) {
    gt.cell_size = cell_size
    grid_texture_sync_to_gpu(gt)
}

grid_texture_set_line_thickness :: proc(gt: ^GridTexture, line_thickness: f32) {
    gt.line_thickness = line_thickness
    grid_texture_sync_to_gpu(gt)
}

grid_texture_set_line_color :: proc(gt: ^GridTexture, color :[4]f32) {
    gt.line_color = color
    grid_texture_sync_to_gpu(gt)
}

grid_texture_set_cell :: proc(gt: ^GridTexture, x, y: i32, color: GridColor) {
    tex_x := 1 + x
    tex_y := y
    data_texture_set({tex_x, tex_y}, GRID_COLOR_TABLE[color])
}

grid_texture_get_cell :: proc(gt: ^GridTexture, x, y: i32) -> GridColor {
    tex_x := 1 + x
    tex_y := y
    pixel := data_texture_get({tex_x, tex_y})
    for c in GridColor {
        if GRID_COLOR_TABLE[c] == pixel {
            return c
        }
    }
    return .Empty
}

grid_texture_clear :: proc(gt: ^GridTexture) {
    for y in 0..<gt.size.y {
        for x in 0..<gt.size.x {
            grid_texture_set_cell(gt, x, y, .Empty)
        }
    }
}

grid_texture_sync_from_grid :: proc(gt: ^GridTexture, grid: ^Grid) {
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            tile := grid_get(grid^, x, y)
            color: GridColor = .Empty

            if .Wall in tile.flags {
                color = .White
            } else if .Obstacle in tile.flags {
                color = .Red
            }

            grid_texture_set_cell(gt, x, y, color)
        }
    }

    wr_x := gt.size.x + 1
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            tile := grid_get(grid^, x, y)
            // Debug: all cells red to see the area
            color: [4]f32 = {1.0, 0.0, 0.0, 0.4}

            data_texture_set({wr_x + x, y}, color)
        }
    }
}
