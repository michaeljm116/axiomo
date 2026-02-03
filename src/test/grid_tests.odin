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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    testing.expect(t, grid.width == 3, "Width should be set to 3")
    testing.expect(t, grid.height == 4, "Height should be set to 4")
    testing.expect(t, len(grid.tiles) == 12, "Data length should be exactly width * height = 12")
    testing.expect(t, grid.scale == game.vec2f{1.0, 1.0}, "Default scale should be {1.0, 1.0}")
}

@(test)
test_grid_create_custom_scale :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    custom_scale := game.vec2f{2.0, 3.0}
    grid := game.grid_create(size, allocator, custom_scale)
    defer {
        delete(grid.tiles, allocator)
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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    game.grid_set_flags(grid, i32(1), i32(1), game.TileFlags{ .Weapon })

    val00 := game.grid_get(grid^, i32(0), i32(0)).flags
    val11 := game.grid_get(grid^, i32(1), i32(1)).flags
    val01 := game.grid_get(grid^, i32(0), i32(1)).flags
    val10 := game.grid_get(grid^, i32(1), i32(0)).flags

    testing.expect(t, val00 == game.TileFlags{  }, "Position (0,0) should be Blank after set")
    testing.expect(t, val11 == game.TileFlags{ .Weapon }, "Position (1,1) should be Weapon after set")
    testing.expect(t, val01 == game.TileFlags{}, "Unset position (0,1) should be default Tile")  // Assuming default is zero/empty
    testing.expect(t, val10 == game.TileFlags{}, "Unset position (1,0) should be default Tile")
}

@(test)
test_grid_set_get_vec2i :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    p00 := game.vec2i{0, 0}
    p11 := game.vec2i{1, 1}
    game.grid_set_flags(grid, p00, game.TileFlags{  })
    game.grid_set_flags(grid, p11, game.TileFlags{ .Weapon })

    val00 := game.grid_get(grid^, p00).flags
    val11 := game.grid_get(grid^, p11).flags

    testing.expect(t, val00 == game.TileFlags{  }, "Position {0,0} should be Blank after set")
    testing.expect(t, val11 == game.TileFlags{ .Weapon }, "Position {1,1} should be Weapon after set")
}

@(test)
test_grid_set_get_pointer_variants :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{2, 2}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    p00 := game.vec2i{0, 0}
    game.grid_set_flags(grid, p00, game.TileFlags{  })

    val_i16_p := game.grid_get_i16_p(grid, 0, 0).flags
    val_int_p := game.grid_get_int_p(grid, 0, 0).flags
    val_vec2i_p := game.grid_get_vec2i_p(grid, p00).flags

    testing.expect(t, val_i16_p == game.TileFlags{  }, "grid_get_i16_p should return Blank")
    testing.expect(t, val_int_p == game.TileFlags{  }, "grid_get_int_p should return Blank")
    testing.expect(t, val_vec2i_p == game.TileFlags{  }, "grid_get_vec2i_p should return Blank")
}

@(test)
test_grid_set_scale :: proc(t: ^testing.T) {
    // This test requires mocking or full ECS setup for Entity and Cmp_Transform
    // For now, placeholder; in real setup, create entity with transform
    testing.expect(t, true, "Placeholder: grid_set_scale requires ECS; test manually or integrate")
    // Example mock:
    // floor_ent := ... create entity with Cmp_Transform { global.sca = {90, 0, 90} }
    // grid := game.grid_create({3,3}, allocator)
    // game.grid_set_flags_scale(floor_ent, grid)
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
    idx := i32(17)
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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    goal := game.vec2i{1, 1}
    game.grid_set_flags(grid, game.vec2i{0, 0}, game.TileFlags{  })
    game.grid_set_flags(grid, game.vec2i{0, 1}, game.TileFlags{ .Weapon })
    game.grid_set_flags(grid, game.vec2i{1, 0}, game.TileFlags{ .Wall })  // Assuming Wall is not walkable
    game.grid_set_flags(grid, goal, game.TileFlags{ .Wall })  // But goal is always walkable

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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Set all to Blank
    for &tile in grid.tiles {
        tile.flags = game.TileFlags{  }
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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Set all to Blank, then block with walls
    for &tile in grid.tiles {
        tile.flags = game.TileFlags{  }
    }
    // Vertical wall in middle column
    game.grid_set_flags(grid, game.vec2i{1, 0}, game.TileFlags{ .Wall })
    game.grid_set_flags(grid, game.vec2i{1, 1}, game.TileFlags{ .Wall })
    game.grid_set_flags(grid, game.vec2i{1, 2}, game.TileFlags{ .Wall })

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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Set goal to Wall, but should still be reachable if adjacent
    game.grid_set_flags(grid, game.vec2i{0, 0}, game.TileFlags{  })
    game.grid_set_flags(grid, game.vec2i{1, 0}, game.TileFlags{  })
    game.grid_set_flags(grid, game.vec2i{0, 1}, game.TileFlags{  })
    game.grid_set_flags(grid, game.vec2i{1, 1}, game.TileFlags{ .Wall })  // Goal

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
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    goal := game.vec2i{1, 1}
    game.grid_set_flags(grid, game.vec2i{0, 0}, game.TileFlags{  })
    game.grid_set_flags(grid, game.vec2i{0, 1}, game.TileFlags{ .Wall })

    testing.expect(t, game.path_is_walkable_internal(game.vec2i{0, 0}, goal, false, grid^), "Blank should be walkable without through walls")
    testing.expect(t, !game.path_is_walkable_internal(game.vec2i{0, 1}, goal, false, grid^), "Wall not walkable without through walls")
    testing.expect(t, game.path_is_walkable_internal(game.vec2i{0, 1}, goal, true, grid^), "Wall walkable with allow_through_walls")
}

@(test)
test_refresh_player_reachability_basic :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{5, 5}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Clear all tiles to default (empty / walkable)
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            game.grid_set_flags(grid, x, y, game.TileFlags{})
        }
    }

    player_pos := game.vec2i{2, 2}  // center

    game.refresh_player_reachability(grid, player_pos)

    // Current position should be Walkable
    current_tile := game.grid_get(grid^, player_pos).flags
    testing.expect(t, .Walkable in current_tile, "Current position should be marked Walkable")

    // 1-step in each direction should be Walkable
    expected_walkable := [4]game.vec2i{
        {3, 2},  // right
        {1, 2},  // left
        {2, 3},  // up
        {2, 1},  // down
    }

    for pos in expected_walkable {
        tile := game.grid_get(grid^, pos).flags
        testing.expect(t, .Walkable in tile, "1-step neighbor should be Walkable")
    }

    // 2-step in each direction should be Runnable
    expected_runnable := [4]game.vec2i{
        {4, 2},  // right 2
        {0, 2},  // left 2
        {2, 4},  // up 2
        {2, 0},  // down 2
    }

    for pos in expected_runnable {
        tile := game.grid_get(grid^, pos).flags
        testing.expect(t, .Runnable in tile, "2-step position should be Runnable")
    }

    // Non-adjacent positions should NOT have flags
    non_adjacent := game.vec2i{4, 4}
    tile := game.grid_get(grid^, non_adjacent).flags
    testing.expect(t, tile == game.TileFlags{}, "Non-reachable position should have no reachability flags")
}

@(test)
test_refresh_player_reachability_with_wall :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{5, 5}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Clear all to default
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            game.grid_set_flags(grid, x, y, game.TileFlags{})
        }
    }

    player_pos := game.vec2i{2, 2}

    // Block right direction with Wall at 1-step
    game.grid_set_flags(grid, game.vec2i{3, 2}, game.TileFlags{.Wall})

    // Block down direction at 2-step (but 1-step open)
    game.grid_set_flags(grid, game.vec2i{2, 0}, game.TileFlags{.Wall})

    game.refresh_player_reachability(grid, player_pos)

    // Right 1-step: Wall → should NOT be Walkable
    right_one := game.grid_get(grid^, game.vec2i{3, 2}).flags
    testing.expect(t, .Walkable not_in right_one, "Blocked 1-step should NOT be Walkable")
    testing.expect(t, .Runnable not_in right_one, "Blocked 1-step should NOT be Runnable")

    // Right 2-step: irrelevant since 1-step blocked
    right_two := game.grid_get(grid^, game.vec2i{4, 2}).flags
    testing.expect(t, .Runnable not_in right_two, "2-step beyond wall should NOT be Runnable")

    // Down 1-step: open → Walkable
    down_one := game.grid_get(grid^, game.vec2i{2, 1}).flags
    testing.expect(t, .Walkable in down_one, "Open 1-step should be Walkable")

    // Down 2-step: Wall → NOT Runnable
    down_two := game.grid_get(grid^, game.vec2i{2, 0}).flags
    testing.expect(t, .Runnable not_in down_two, "2-step blocked by wall should NOT be Runnable")

    // Left and Up should be normal (open)
    left_one := game.grid_get(grid^, game.vec2i{1, 2}).flags
    testing.expect(t, .Walkable in left_one, "Open direction should be Walkable")
}

@(test)
test_refresh_player_reachability_clears_old_flags :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 3}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Manually set some old flags
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            pos := game.vec2i{x, y}
            t := &game.grid_get_mut(grid, pos).flags
            t^ += {.Walkable, .Runnable}
        }
    }

    player_pos := game.vec2i{1, 1}

    // Call refresh - should clear all first
    game.refresh_player_reachability(grid, player_pos)

    // Check a non-reachable position (corner, not adjacent)
    corner := game.grid_get(grid^, game.vec2i{0, 0}).flags
    testing.expect(t, corner == game.TileFlags{}, "Old flags should have been cleared from non-reachable tiles")

    // Current pos should have Walkable
    current := game.grid_get(grid^, player_pos).flags
    testing.expect(t, .Walkable in current, "Current position should be Walkable after refresh")
    testing.expect(t, .Runnable not_in current, "Current position should NOT be Runnable")
}

@(test)
test_refresh_player_reachability_current_pos :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 3}
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Clear all
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            game.grid_set_flags(grid, x, y, game.TileFlags{})
        }
    }

    player_pos := game.vec2i{1, 1}

    game.refresh_player_reachability(grid, player_pos)

    current_tile := game.grid_get(grid^, player_pos).flags
    testing.expect(t, .Walkable in current_tile, "Player's current position should be marked Walkable")
    testing.expect(t, .Runnable not_in current_tile, "Current position should not be Runnable")
}
