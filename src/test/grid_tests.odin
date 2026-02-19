package game_tests

import "core:testing"
import "core:mem"
import math "core:math/linalg"
import game".."
import ax "../axiom"

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
test_grid_init_floor_tile_centers :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{3, 2}  // Small grid for easier verification
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Create a fake floor primitive - floor is 6 units wide, 4 units deep
    floor_transform := game.Cmp_Primitive{
        world = math.MATRIX4F32_IDENTITY,  // Identity matrix (position at origin)
        extents = {3.0, 0.5, 2.0}  // Half-extents: Width=6 (3*2), Height=1 (0.5*2), Depth=4 (2*2)
    }

    // Initialize the grid with the fake floor
    game.grid_init_floor(grid, floor_transform)

    // Verify scale calculation: floor_sca.xz / grid_size = {6,4} / {3,2} = {2,2}
    testing.expect(t, grid.scale.x == 2.0, "Grid scale x should be 6/3 = 2.0")
    testing.expect(t, grid.scale.y == 2.0, "Grid scale y should be 4/2 = 2.0")

    // Verify tile centers are calculated correctly
    // For a 3x2 grid with scale 2.0, centers should be:
    // x positions: 1.0, 3.0, 5.0 (0*2+0.5*2, 1*2+0.5*2, 2*2+0.5*2)
    // z positions: 1.0, 3.0 (same logic)

    // Check corner tiles
    tile_00 := game.grid_get(grid^, 0, 0)  // bottom-left
    tile_20 := game.grid_get(grid^, 2, 0)  // bottom-right
    tile_01 := game.grid_get(grid^, 0, 1)  // top-left
    tile_21 := game.grid_get(grid^, 2, 1)  // top-right

    testing.expect(t, tile_00.center.x == -2.0, "Tile (0,0) center x should be 0*2 + 1.0 - 3.0 = -2.0")
    testing.expect(t, tile_00.center.y == -1.0, "Tile (0,0) center y should be 0*2 + 1.0 - 2.0 = -1.0")

    testing.expect(t, tile_20.center.x == 2.0, "Tile (2,0) center x should be 2*2 + 1.0 - 3.0 = 2.0")
    testing.expect(t, tile_20.center.y == -1.0, "Tile (2,0) center y should be 0*2 + 1.0 - 2.0 = -1.0")

    testing.expect(t, tile_01.center.x == -2.0, "Tile (0,1) center x should be 0*2 + 1.0 - 3.0 = -2.0")
    testing.expect(t, tile_01.center.y == 1.0, "Tile (0,1) center y should be 1*2 + 1.0 - 2.0 = 1.0")

    testing.expect(t, tile_21.center.x == 2.0, "Tile (2,1) center x should be 2*2 + 1.0 - 3.0 = 2.0")
    testing.expect(t, tile_21.center.y == 1.0, "Tile (2,1) center y should be 1*2 + 1.0 - 2.0 = 1.0")
}

@(test)
test_grid_init_floor_center_position :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := game.vec2i{7, 5}  // Match actual game grid
    grid := game.grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // Create a fake floor primitive - floor is 7 units wide, 5 units deep
    floor_transform := game.Cmp_Primitive{
        world = math.MATRIX4F32_IDENTITY,  // Identity matrix (position at origin)
        extents = {3.5, 0.5, 2.5}  // Half-extents: Width=7 (3.5*2), Height=1 (0.5*2), Depth=5 (2.5*2)
    }

    game.grid_init_floor(grid, floor_transform)

    // Player position (0,2) should map to world center at (-3.0, 0.0)
    player_tile := game.grid_get(grid^, 0, 2)
    testing.expect(t, player_tile.center.x == -3.0, "Player at (0,2) should have world x = -3.0 (left side)")
    testing.expect(t, player_tile.center.y == 0.0, "Player at (0,2) should have world y = 0.0")

    // Center of grid (3,2) should be at world (0.0, 0.0)
    center_tile := game.grid_get(grid^, 3, 2)
    testing.expect(t, center_tile.center.x == 0.0, "Center tile (3,2) should have world x = 0.0")
    testing.expect(t, center_tile.center.y == 0.0, "Center tile (3,2) should have world y = 0.0")

    // Rightmost tile (6,2) should be at world (3.0, 0.0)
    right_tile := game.grid_get(grid^, 6, 2)
    testing.expect(t, right_tile.center.x == 3.0, "Rightmost tile (6,2) should have world x = 3.0")
    testing.expect(t, right_tile.center.y == 0.0, "Rightmost tile (6,2) should have world y = 0.0")
}

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

@(test)
test_path_is_walkable_ignores_reachability_flags :: proc(t: ^testing.T) {
    grid := game.grid_create({5, 5}, context.allocator)
    defer { /* cleanup */ }

    goal := game.vec2i{0, 0}
    pos  := game.vec2i{2, 2}

    // These flags are set by refresh_player_reachability
    game.grid_set_flags(grid, pos, {.Walkable})
    game.grid_set_flags(grid, vec2i{3,2}, {.Runnable})

    testing.expect(t, game.path_is_walkable(pos, goal, grid^), "Walkable flag should NOT block movement")
    testing.expect(t, game.path_is_walkable(vec2i{3,2}, goal, grid^), "Runnable flag should NOT block movement")

    // Still block real obstacles
    game.grid_set_flags(grid, vec2i{4,2}, {.Wall})
    testing.expect(t, !game.path_is_walkable(vec2i{4,2}, goal, grid^), "Wall should still block")
}

@(test)
test_a_star_respects_reachability_flags_but_allows_them :: proc(t: ^testing.T) {
    grid := game.grid_create({5, 5}, context.allocator)
    defer { /* cleanup */ }

    // Make a clean grid
    for &tile in grid.tiles { tile.flags = {} }

    start := game.vec2i{0, 0}
    goal  := game.vec2i{4, 0}

    // Simulate player reachability from goal (common real-world case)
    game.refresh_player_reachability(grid, goal)

    path := game.path_a_star_find(start, goal, {5,5}, grid^)

    testing.expect(t, len(path) > 0, "A* should still find path despite .Walkable/.Runnable flags")
    testing.expect(t, path[0] == start)
    testing.expect(t, path[len(path)-1] == goal)
    testing.expect(t, len(path) == 5, "Should be Manhattan distance + 1 (4 steps)")
}

@(test)
test_in_fov_cone_basic :: proc(t: ^testing.T) {
    max_range : i32 = 10

    // Test Right facing
    testing.expect(t, in_fov_cone(0,0, 5,0, .Right, max_range), "Direct right should be in cone")
    testing.expect(t, in_fov_cone(0,0, 5,2, .Right, max_range), "Right-up diagonal (|dy| <= dx) in cone")
    testing.expect(t, in_fov_cone(0,0, 5,-2, .Right, max_range), "Right-down diagonal in cone")
    testing.expect(t, !in_fov_cone(0,0, 5,6, .Right, max_range), "Steep up (|dy| > dx) out")
    testing.expect(t, !in_fov_cone(0,0, -1,0, .Right, max_range), "Left out")
    testing.expect(t, !in_fov_cone(0,0, 0,1, .Right, max_range), "Up out")
    testing.expect(t, !in_fov_cone(0,0, 0,0, .Right, max_range), "Self (manhattan=0) out")

    // Test Left facing
    testing.expect(t, in_fov_cone(0,0, -5,0, .Left, max_range), "Direct left in cone")
    testing.expect(t, in_fov_cone(0,0, -5,2, .Left, max_range), "Left-up in cone")
    testing.expect(t, in_fov_cone(0,0, -5,-2, .Left, max_range), "Left-down in cone")
    testing.expect(t, !in_fov_cone(0,0, -5,6, .Left, max_range), "Steep up out")
    testing.expect(t, !in_fov_cone(0,0, 1,0, .Left, max_range), "Right out")

    // Test Down facing (assume +Y down)
    testing.expect(t, in_fov_cone(0,0, 0,5, .Down, max_range), "Direct down in cone")
    testing.expect(t, in_fov_cone(0,0, 2,5, .Down, max_range), "Down-right in cone")
    testing.expect(t, in_fov_cone(0,0, -2,5, .Down, max_range), "Down-left in cone")
    testing.expect(t, !in_fov_cone(0,0, 6,5, .Down, max_range), "Steep right out")
    testing.expect(t, !in_fov_cone(0,0, 0,-1, .Down, max_range), "Up out")

    // Test Up facing
    testing.expect(t, in_fov_cone(0,0, 0,-5, .Up, max_range), "Direct up in cone")
    testing.expect(t, in_fov_cone(0,0, 2,-5, .Up, max_range), "Up-right in cone")
    testing.expect(t, in_fov_cone(0,0, -2,-5, .Up, max_range), "Up-left in cone")
    testing.expect(t, !in_fov_cone(0,0, 6,-5, .Up, max_range), "Steep right out")
    testing.expect(t, !in_fov_cone(0,0, 0,1, .Up, max_range), "Down out")

    // Range limit
    testing.expect(t, !in_fov_cone(0,0, 11,0, .Right, 10), "Beyond max_range out")
}

@(test)
test_in_fov_cone_manhattan_zero_and_max :: proc(t: ^testing.T) {
    testing.expect(t, !in_fov_cone(0,0,0,0, .Right, 5), "manhattan=0 out")
    testing.expect(t, in_fov_cone(0,0,5,0, .Right, 5), "Exactly max_range in")
    testing.expect(t, !in_fov_cone(0,0,6,0, .Right, 5), "Over max_range out")
}

@(test)
test_has_clear_los_basic :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := vec2i{6, 6}
    grid := grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    // All open grid
    for &tile in grid.tiles { tile.flags = {} }

    testing.expect(t, has_clear_los(grid^, 0,0,0,0), "Self always true")
    testing.expect(t, has_clear_los(grid^, 0,0,5,0), "Straight horizontal clear")
    testing.expect(t, has_clear_los(grid^, 0,0,0,5), "Straight vertical clear")
    testing.expect(t, has_clear_los(grid^, 0,0,3,3), "Diagonal clear")
    testing.expect(t, has_clear_los(grid^, 0,0,2,5), "Steep diagonal clear")

    // Add block in straight line
    grid_set_flags(grid, vec2i{2,0}, {.Wall})
    testing.expect(t, !has_clear_los(grid^, 0,0,5,0), "Blocked horizontal false")

    // Block on diagonal
    grid_set_flags(grid, vec2i{1,1}, {.Obstacle})
    testing.expect(t, !has_clear_los(grid^, 0,0,3,3), "Blocked diagonal false")

    // End on block? (skips end, so if target open, but intermediate blocked already tested)
    grid_set_flags(grid, vec2i{5,0}, {.Wall})  // But since we skip end, and previous block already fails
}

@(test)
test_has_clear_los_edge_cases :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := vec2i{3, 3}
    grid := grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    for &tile in grid.tiles { tile.flags = {} }

    // Adjacent
    testing.expect(t, has_clear_los(grid^, 0,0,1,0), "Adjacent horizontal clear (no intermediate)")

    // Block on start/end skipped
    grid_set_flags(grid, vec2i{0,0}, {.Wall})  // Start blocked, but skipped
    grid_set_flags(grid, vec2i{2,2}, {.Wall})  // End blocked, skipped
    testing.expect(t, has_clear_los(grid^, 0,0,2,2), "Diagonal with start/end blocked but intermediates clear")

    // Single intermediate block
    grid_set_flags(grid, vec2i{1,1}, {.Wall})
    testing.expect(t, !has_clear_los(grid^, 0,0,2,2), "Diagonal with intermediate block false")
}

@(test)
test_can_see_target_combined :: proc(t: ^testing.T) {
    allocator := context.allocator
    size := vec2i{6, 6}
    grid := grid_create(size, allocator)
    defer {
        delete(grid.tiles, allocator)
        delete(grid.weapons)
        free(grid, allocator)
    }

    for &tile in grid.tiles { tile.flags = {} }

    viewer_pos := vec2i{0,0}
    viewer_facing := Direction.Right
    target_pos := vec2i{5,2}

    // Clear LOS + in cone
    testing.expect(t, can_see_target(grid^, viewer_pos, viewer_facing, target_pos), "In cone + clear LOS true")

    // Out of cone
    out_cone := vec2i{5,6}  // Steep
    testing.expect(t, !can_see_target(grid^, viewer_pos, viewer_facing, out_cone), "Out of cone false")

    // In cone but blocked
    grid_set_flags(grid, vec2i{3,1}, {.Wall})  // On approx path to {5,2}
    testing.expect(t, !can_see_target(grid^, viewer_pos, viewer_facing, target_pos), "In cone but blocked LOS false")

    // Different facing
    testing.expect(t, !can_see_target(grid^, viewer_pos, .Left, target_pos), "Wrong facing false")

    // Self
    testing.expect(t, !can_see_target(grid^, viewer_pos, viewer_facing, viewer_pos), "Self false (manhattan=0)")

    // Range limit
    far := vec2i{13,0}
    testing.expect(t, !can_see_target(grid^, viewer_pos, viewer_facing, far, 12), "Beyond range false")
}