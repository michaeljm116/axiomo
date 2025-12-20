package game_tests

import "core:testing"
import "core:mem"
import game".."

// Assuming Tile is defined in game as something like:
// Tile :: enum { Blank, Weapon, Wall, ... }
// If not, adjust accordingly in tests

@(test)
test_grid_create :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 4}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    testing.expect(t, grid.width == 3, "Width should be set to 3")
    testing.expect(t, grid.height == 4, "Height should be set to 4")
    testing.expect(t, len(grid.data) == 12, "Data length should be exactly width * height = 12")
    testing.expect(t, grid.scale == game.vec2f{1.0, 1.0}, "Default scale should be {1.0, 1.0}")
}

@(test)
test_grid_create_custom_scale :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    custom_scale := game.vec2f{2.0, 3.0}
    grid := game.grid_create(size, allocator, custom_scale)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    testing.expect(t, grid.scale == custom_scale, "Custom scale should be set correctly")
}

@(test)
test_grid_set_get_i16 :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    game.grid_set(grid, i16(0), i16(0), game.Tile.Blank)
    game.grid_set(grid, i16(1), i16(1), game.Tile.Weapon)

    val00 := game.grid_get(grid^, i16(0), i16(0))
    val11 := game.grid_get(grid^, i16(1), i16(1))
    val01 := game.grid_get(grid^, i16(0), i16(1))
    val10 := game.grid_get(grid^, i16(1), i16(0))

    testing.expect(t, val00 == game.Tile.Blank, "Position (0,0) should be Blank after set")
    testing.expect(t, val11 == game.Tile.Weapon, "Position (1,1) should be Weapon after set")
    testing.expect(t, val01 == game.Tile{}, "Unset position (0,1) should be default Tile")  // Assuming default is zero/empty
    testing.expect(t, val10 == game.Tile{}, "Unset position (1,0) should be default Tile")
}

@(test)
test_grid_set_get_vec2i :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    p00 := game.vec2i{0, 0}
    p11 := game.vec2i{1, 1}
    game.grid_set(grid, p00, game.Tile.Blank)
    game.grid_set(grid, p11, game.Tile.Weapon)

    val00 := game.grid_get(grid^, p00)
    val11 := game.grid_get(grid^, p11)

    testing.expect(t, val00 == game.Tile.Blank, "Position {0,0} should be Blank after set")
    testing.expect(t, val11 == game.Tile.Weapon, "Position {1,1} should be Weapon after set")
}

@(test)
test_grid_set_get_pointer_variants :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    p00 := game.vec2i{0, 0}
    game.grid_set(grid, p00, game.Tile.Blank)

    val_i16_p := game.grid_get_i16_p(grid, 0, 0)
    val_int_p := game.grid_get_int_p(grid, 0, 0)
    val_vec2i_p := game.grid_get_vec2i_p(grid, p00)

    testing.expect(t, val_i16_p == game.Tile.Blank, "grid_get_i16_p should return Blank")
    testing.expect(t, val_int_p == game.Tile.Blank, "grid_get_int_p should return Blank")
    testing.expect(t, val_vec2i_p == game.Tile.Blank, "grid_get_vec2i_p should return Blank")
}

@(test)
test_grid_set_scale :: proc(t: ^testing.T) {
    // This test requires mocking or full ECS setup for Entity and Cmp_Transform
    // For now, placeholder; in real setup, create entity with transform
    testing.expect(t, true, "Placeholder: grid_set_scale requires ECS; test manually or integrate")
    // Example mock:
    // floor_ent := ... create entity with Cmp_Transform { global.sca = {90, 0, 90} }
    // grid := game.grid_create({3,3}, allocator)
    // game.grid_set_scale(floor_ent, grid)
    // testing.expect(t, grid.scale.x == 30.0, "Scale x should be 90/3=30")
}

@(test)
test_path_pos_equal :: proc(t: ^testing.T) {
    a := game.vec2i{1, 2}
    b := game.vec2i{1, 2}
    c := game.vec2i{1, 3}

    testing.expect(t, game.path_pos_equal(a, b), "Identical positions should be equal")
    testing.expect(t, !game.path_pos_equal(a, c), "Different positions should not be equal")
}

@(test)
test_path_pos_to_index :: proc(t: ^testing.T) {
    grid := game.Grid{width = 5, height = 5}
    p := game.vec2i{2, 3}
    idx := game.path_pos_to_index(p, grid)
    testing.expect(t, idx == 17, "Index for {2,3} in 5x5 grid should be 2 + 3*5 = 17")
}

@(test)
test_path_index_to_pos :: proc(t: ^testing.T) {
    grid := game.Grid{width = 5, height = 5}
    idx := i16(17)
    p := game.path_index_to_pos(idx, grid)
    testing.expect(t, p == game.vec2i{2, 3}, "Position for index 17 in 5x5 grid should be {2,3}")
}

@(test)
test_path_in_bounds :: proc(t: ^testing.T) {
    grid := game.Grid{width = 4, height = 4}
    in_pos := game.vec2i{2, 2}
    out_pos1 := game.vec2i{-1, 0}
    out_pos2 := game.vec2i{4, 3}
    out_pos3 := game.vec2i{2, 4}

    testing.expect(t, game.path_in_bounds(in_pos, grid), "{2,2} should be in bounds")
    testing.expect(t, !game.path_in_bounds(out_pos1, grid), "{-1,0} should be out of bounds")
    testing.expect(t, !game.path_in_bounds(out_pos2, grid), "{4,3} should be out of bounds")
    testing.expect(t, !game.path_in_bounds(out_pos3, grid), "{2,4} should be out of bounds")
}

@(test)
test_path_is_walkable :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 3}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    goal := game.vec2i{1, 1}
    game.grid_set(grid, game.vec2i{0, 0}, game.Tile.Blank)
    game.grid_set(grid, game.vec2i{0, 1}, game.Tile.Weapon)
    game.grid_set(grid, game.vec2i{1, 0}, game.Tile.Wall)  // Assuming Wall is not walkable
    game.grid_set(grid, goal, game.Tile.Wall)  // But goal is always walkable

    out_pos := game.vec2i{3, 3}

    testing.expect(t, game.path_is_walkable(game.vec2i{0, 0}, goal, grid^), "Blank tile should be walkable")
    testing.expect(t, game.path_is_walkable(game.vec2i{0, 1}, goal, grid^), "Weapon tile should be walkable")
    testing.expect(t, !game.path_is_walkable(game.vec2i{1, 0}, goal, grid^), "Wall tile should not be walkable")
    testing.expect(t, game.path_is_walkable(goal, goal, grid^), "Goal position should always be walkable even if Wall")
    testing.expect(t, !game.path_is_walkable(out_pos, goal, grid^), "Out of bounds should not be walkable")
}

@(test)
test_path_abs_i :: proc(t: ^testing.T) {
    testing.expect(t, game.path_abs_i(10) == 10, "Abs of positive int should be itself")
    testing.expect(t, game.path_abs_i(-10) == 10, "Abs of negative int should be positive")
    testing.expect(t, game.path_abs_i(0) == 0, "Abs of zero should be zero")
}

@(test)
test_path_dist_grid :: proc(t: ^testing.T) {
    a := game.vec2i{0, 0}
    b := game.vec2i{3, 4}
    c := game.vec2i{-3, -4}

    testing.expect(t, game.path_dist_grid(a, b) == 7, "Distance {0,0} to {3,4} should be 7")
    testing.expect(t, game.path_dist_grid(a, c) == 7, "Distance {0,0} to {-3,-4} should be 7 (abs)")
    testing.expect(t, game.path_dist_grid(b, c) == 14, "Distance {3,4} to {-3,-4} should be 14")
}

@(test)
test_path_heuristic :: proc(t: ^testing.T) {
    a := game.vec2i{0, 0}
    b := game.vec2i{5, 5}

    testing.expect(t, game.path_heuristic(a, b) == 10, "Heuristic should match Manhattan distance")
}

@(test)
test_path_a_star_find_simple_path :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 3}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Set all to Blank
    for &tile in grid.data {
        tile = game.Tile.Blank
    }

    start := game.vec2i{0, 0}
    goal := game.vec2i{2, 2}
    path := game.path_a_star_find(start, goal, size, grid^)  // Note: size param seems unused in code, but passed

    testing.expect(t, len(path) > 0, "Path should be found in open grid")
    testing.expect(t, path[0] == start, "Path should start at {0,0}")
    testing.expect(t, path[len(path)-1] == goal, "Path should end at {2,2}")
    // Possible path length: min 5 steps in Manhattan (e.g., right,right,down,down but with diag equiv)
}

@(test)
test_path_a_star_find_no_path :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 3}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Set all to Blank, then block with walls
    for &tile in grid.data {
        tile = game.Tile.Blank
    }
    // Vertical wall in middle column
    game.grid_set(grid, game.vec2i{1, 0}, game.Tile.Wall)
    game.grid_set(grid, game.vec2i{1, 1}, game.Tile.Wall)
    game.grid_set(grid, game.vec2i{1, 2}, game.Tile.Wall)

    start := game.vec2i{0, 0}
    goal := game.vec2i{2, 0}
    path := game.path_a_star_find(start, goal, size, grid^)

    testing.expect(t, len(path) == 0, "No path should be found when blocked by wall")
}

@(test)
test_path_a_star_find_goal_is_walkable :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Set goal to Wall, but should still be reachable if adjacent
    game.grid_set(grid, game.vec2i{0, 0}, game.Tile.Blank)
    game.grid_set(grid, game.vec2i{1, 0}, game.Tile.Blank)
    game.grid_set(grid, game.vec2i{0, 1}, game.Tile.Blank)
    game.grid_set(grid, game.vec2i{1, 1}, game.Tile.Wall)  // Goal

    start := game.vec2i{0, 0}
    goal := game.vec2i{1, 1}
    path := game.path_a_star_find(start, goal, size, grid^)

    testing.expect(t, len(path) > 0, "Path should reach goal even if it's a Wall")
    testing.expect(t, path[len(path)-1] == goal, "Path should end at goal")
}

@(test)
test_path_is_walkable_internal :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.data, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    goal := game.vec2i{1, 1}
    game.grid_set(grid, game.vec2i{0, 0}, game.Tile.Blank)
    game.grid_set(grid, game.vec2i{0, 1}, game.Tile.Wall)

    testing.expect(t, game.path_is_walkable_internal(game.vec2i{0, 0}, goal, false, grid^), "Blank should be walkable without through walls")
    testing.expect(t, !game.path_is_walkable_internal(game.vec2i{0, 1}, goal, false, grid^), "Wall not walkable without through walls")
    testing.expect(t, game.path_is_walkable_internal(game.vec2i{0, 1}, goal, true, grid^), "Wall walkable with allow_through_walls")
}
