package game

import "core:fmt"
import "core:mem"
import "core:math"
import "core:time"
import "core:math/linalg"
import vmem "core:mem/virtual"
import "core:c"
import "vendor:glfw"
import b2"vendor:box2d"
import "axiom"

// Find the camera entity in the scene
find_camera_entity :: proc() {
    camera_archetypes := axiom.query(has(Cmp_Camera), has(Cmp_Transform), has(Cmp_Node))

    for archetype in camera_archetypes {
        entities := archetype.entities
        if len(entities) > 0 {
            g.camera_entity = entities[0]
            ct := get_component(g.camera_entity, Cmp_Transform)
            return
        }
    }

    fmt.println("Warning: No camera entity found!")
}

init_light_entity :: proc() {
    g.light_orbit_radius = 5.0
    g.light_orbit_speed = 0.25   // radians per second
    g.light_orbit_angle = 15.0
}

// Update the cached light entity so it orbits around a center point.
// If a player exists, orbit around the player's world position; otherwise use world origin.
update_light_orbit :: proc(delta_time: f32) {
    if !axiom.entity_exists(g.light_entity) {
        return
    }

    lc := get_component(g.light_entity, Cmp_Light)
    tc := get_component(g.light_entity, Cmp_Transform)
    if tc == nil || lc == nil {
        return
    }

    // Determine orbit center: prefer player position if available
    center := vec3{0.0, 11.5, 0.0}
    if g.player != 0 {
        pc := get_component(g.player, Cmp_Transform)
        if pc != nil {
            center = pc.local.pos.xyz
        }
    }

    // Advance angle
    g.light_orbit_angle += g.light_orbit_speed * delta_time

    // Compute new local position on XZ plane; keep Y relative to center
    new_x := center.x + math.cos(g.light_orbit_angle) * g.light_orbit_radius
    new_z := center.z + math.sin(g.light_orbit_angle) * g.light_orbit_radius
    new_y := center.y + 10.5 // offset above center (tweak as desired)

    // Update transform local position so the transform system will update world matrix
    tc.local.pos.x = new_x
    tc.local.pos.z = new_z
    tc.local.pos.y = new_y

    axiom.g_raytracer.update_flags += {.LIGHT}
}

update_player_movement :: proc(delta_time: f32)
{
    tc := get_component(g.player, Cmp_Transform)
    if tc == nil do return

    move_speed :f32= .10
    if is_key_pressed(glfw.KEY_W) {
        tc.local.pos.z += move_speed
    }
    if is_key_pressed(glfw.KEY_S) {
        tc.local.pos.z -= move_speed
    }
    if is_key_pressed(glfw.KEY_A) {
        tc.local.pos.x -= move_speed
    }
    if is_key_pressed(glfw.KEY_D) {
        tc.local.pos.x += move_speed
    }
    // Verticaltc.local.pos.x
    if is_key_pressed(glfw.KEY_SPACE) {
        tc.local.pos.y += move_speed
    }
    if is_key_pressed(glfw.KEY_LEFT_SHIFT) {
        tc.local.pos.y -= move_speed
    }
}

face_left :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(89.5, {0,1,0})
}

face_180 :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(179, {0,1,0})
    fmt.println(linalg.angle_axis_from_quaternion(tc.local.rot))
}

face_right :: proc(entity : Entity)
{
    tc := get_component(entity, Cmp_Transform)
    tc.local.rot = linalg.quaternion_angle_axis_f32(-89.5, {0,1,0})
}

// Get camera forward vector
get_camera_forward :: proc(transform: ^Cmp_Transform) -> vec3 {
    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform.local.rot)
    return -vec3{rotation_matrix[0][2], rotation_matrix[1][2], rotation_matrix[2][2]}
}

// Get camera right vector
get_camera_right :: proc(transform: ^Cmp_Transform) -> vec3 {
    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform.local.rot)
    return vec3{rotation_matrix[0][0], rotation_matrix[1][0], rotation_matrix[2][0]}
}

//----------------------------------------------------------------------------\\
// /Physics System /ps
//----------------------------------------------------------------------------\\
// MAX_DYANMIC_OBJECTS :: 1000
// g_world_def := b2.DefaultWorldDef()
// g_world_id : b2.WorldId
// g_b2scale := f32(1)

// ContactDensities :: struct
// {
//     Player : f32,
//     Vax : f32,
//     Doctor : f32,
//     Projectiles : f32,
//     Wall : f32
// }

// g_contact_identifier := ContactDensities {
// 	Player      = 9.0,
// 	Vax         = 50.0,
// 	Doctor      = 200.0,
// 	Projectiles = 8.0,
// 	Wall        = 800.0
// }



// setup_physics :: proc (){
//     fmt.println("Setting up phsyics")
//     b2.SetLengthUnitsPerMeter(g_b2scale)
//     g_world_id = b2.CreateWorld(g_world_def)
//     b2.World_SetGravity(g_world_id, b2.Vec2{0,-9.8})
//     //Set Player's body def
//     {
//         // find_player_entity()
//         ///////////////////////////////////
//         // /plr
//         ///////////////////////////////////
//         pt := get_component(g.player, Cmp_Transform)
//         // Build collision components. Body position is the body origin in world space.
//         col := Cmp_Collision2D{
//             bodydef = b2.DefaultBodyDef(),
//             shapedef = b2.DefaultShapeDef(),
//             type = .Capsule,
//             flags = {.Player}
//         }
//         col.bodydef.fixedRotation = true
//         col.bodydef.type = .dynamicBody
//         // Place the body origin at the transform world position (pt.world[3] should be the object's world origin)
//         col.bodydef.position = pt.world[3].xy
//         col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

//         // Define the capsule in body-local coordinates (centered on the body origin).
//         // Use half extents from the transform scale. magic_scale_number still applied to y if needed.
//         box := b2.MakeBox(pt.local.sca.x,pt.local.sca.y)
//         col.shapedef = b2.DefaultShapeDef()
//         col.shapedef.filter.categoryBits = u64(CollisionCategories{.Player})
//         col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Environment, .MovingEnvironment})
//         col.shapedef.enableContactEvents = true
//         col.shapedef.density = g_contact_identifier.Player
//         // col.shapeid = b2.CreateCapsuleShape(col.bodyid, col.shapedef, capsule)
//         col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
//         add_component(g.player, col)
//         //add_component(g.player, capsule)
//     }

//     fmt.println("Floor created")
//     set_floor_entities()
//     // create_barrel({3, 2})
//     // create_barrel({1, 2})
//     // create_barrel({2, 2})
//     // create_barrel({4, 2})
//     // create_barrel({5, 2})
//     // create_barrel({6, 2})
//     // create_barrel({7, 2})
//     // create_barrel({8, 2})
//     // create_barrel({9, 2})
//     // create_barrel({10, 2})
//     // create_barrel({15, 2})
//     // create_barrel({11, 2})
//     // create_barrel({12, 2})
//     // create_barrel({13, 2})
//     // create_barrel({14.5, 2})
//     // create_barrel({4, 2})
//     // create_debug_quad({2,2,1}, {0,0,0,0}, {1,1,.1})
//     //create_debug_cube_with_col({2,2}, {10,10})
//     //
//     create_debug_cube_with_col({25,2}, {2,2})
//    }

// set_floor_entities :: proc()
// {
//     // /flr
//     //create static floor
//     {
//         col := Cmp_Collision2D{
//             bodydef = b2.DefaultBodyDef(),
//             shapedef = b2.DefaultShapeDef(),
//             type = .Box
//         }
//         col.bodydef.fixedRotation = true
//         col.bodydef.type = .staticBody
//         col.bodydef.position = {0,-2.0}
//         col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
//         box := b2.MakeBox(500, 1.0)

//         col.shapedef = b2.DefaultShapeDef()
//         col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
//         col.shapedef.filter.maskBits = u64(CollisionCategories{.Player, .MovingEnvironment, .MovingFloor, .Environment, .Enemy})
//         col.shapedef.enableContactEvents = true
//         col.shapedef.density = 10000
//         col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
//     }

//     find_floor_entities()
//     fc := get_component(g.floor, Cmp_Transform)
//     col := Cmp_Collision2D{
//         bodydef = b2.DefaultBodyDef(),
//         shapedef = b2.DefaultShapeDef(),
//         type = .Box,
//         flags = {.Movable, .Floor}
//     }
//     // move := Cmp_Movable{speed = -2.0}
//     col.bodydef.fixedRotation = true
//     col.bodydef.type = .dynamicBody
//     col.bodydef.position = {fc.world[3].x, fc.world[3].y - 1}
//     col.bodydef.gravityScale = 0
//     col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
//     box := b2.MakeBox(fc.local.sca.x, fc.local.sca.y)

//     col.shapedef = b2.DefaultShapeDef()
//     col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingFloor})
//     col.shapedef.filter.maskBits = u64(CollisionCategories{.Environment})
//     col.shapedef.enableContactEvents = true
//     col.shapedef.density = 1000.0
//     col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

//     add_component(g.floor, col)
// }

// barrel : Entity
// create_barrel :: proc(pos : b2.Vec2)
// {
//     fmt.println("Barrel creating")
//     barrel = load_prefab("Barrel")
//     fmt.println("Prefab loaded")
//     bt := get_component(barrel, Cmp_Transform)
//     if bt == nil do return

//     col := Cmp_Collision2D{
//         bodydef = b2.DefaultBodyDef(),
//         shapedef = b2.DefaultShapeDef(),
//         type = .Box,
//         flags = CollisionFlags{.Movable}
//     }
//     col.bodydef.fixedRotation = true
//     col.bodydef.type = .dynamicBody
//     // Body position must be scaled to Box2D units
//     col.bodydef.position = b2.Vec2{ pos.x * g_b2scale, pos.y * g_b2scale }
//     col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

//     // Scale shape extents to Box2D units (bt.local.sca holds half-extents in our transform)
//     box := b2.MakeBox(bt.local.sca.x * g_b2scale, bt.local.sca.y * 2 * g_b2scale)
//     col.shapedef = b2.DefaultShapeDef()
//     col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingEnvironment})
//     col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player, .Environment, .MovingEnvironment})
//     col.shapedef.enableContactEvents = true
//     col.shapedef.density = g_contact_identifier.Player
//     col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

//     // movable := Cmp_Movable{-1.0}

//     fmt.println("Movable component added")
//     add_component(barrel, col)
//     fmt.println("Collision component added")
//     //add_component(barrel, movable)
// }

// // update_movables :: proc(delta_time: f32)
// // {
// //     //First just the visible g.floor
// //     for i in 0..<2{
// //         fc := get_component(g.floor, Cmp_Transform)
// //         fc.local.pos.x -= 1.0 * delta_time

// //         //refresh world if done
// //         if fc.local.pos.x <= -100.0 {
// //             fmt.println("Floor  ", i, "  | Trans: ", fc.local.pos.xy)
// //             for e in g_objects[curr_phase] do remove_entity(e)
// //             vmem.arena_free_all(&distance_arena[curr_phase])
// //             curr_phase = (curr_phase + 1) % 2

// //             col := get_component(g.floor, Cmp_Collision2D)
// //             fc.local.pos.x += 200.0
// //             trans := b2.Body_GetTransform(col.bodyid)
// //             trans.p.x = fc.local.pos.x
// //             b2.Body_SetTransform(col.bodyid, trans.p, trans.q)
// //         }
// //     }
// //     movables := query(has(Cmp_Collision2D))
// //     for movable in movables{
// //         cols := get_table(movable, Cmp_Collision2D)
// //         for e, i in movable.entities{
// //             if .Movable in cols[i].flags{
// //                 nc := get_component(e, Cmp_Node)
// //                 tc := get_component(e, Cmp_Transform)
// //                 // fmt.println("movable, ", nc.name)
// //                 // b2.Body_SetLinearVelocity(cols[i].bodyid, {delta_time * -1.0, 0})
// //                 // b2.Body_ApplyLinearImpulse(cols[i].bodyid, {-2.0,0}, {0.5,0.5}, true)
// //                 vel := b2.Body_GetLinearVelocity(cols[i].bodyid)
// //                 vel.x = -4
// //                 b2.Body_SetLinearVelocity(cols[i].bodyid, vel)
// //                 // b2.Body_ApplyForceToCenter(cols[i].bodyid, {0,1000.0}, true)
// //                 //fmt.printfln("Entity")
// //                 // fmt.println("Entity: ",nc.name, " | Position : ", b2.Body_GetPosition(cols[i].bodyid), " | Trans: ", tc.local.pos.xy)
// //             }
// //         }
// //     }
// // }

// update_physics :: proc(delta_time: f32)
// {
//     update_player_movement_phys(delta_time)
//     b2.World_Step(g_world_id, delta_time, 4)
//     arcs := axiom.query(has(Cmp_Transform), has(Cmp_Collision2D))
//     for arc in arcs{
//         trans := get_table(arc,Cmp_Transform)
//         colis := get_table(arc,Cmp_Collision2D)
//         for _, i in arc.entities{
//             pos := b2.Body_GetPosition(colis[i].bodyid)
//             if(.Floor not_in colis[i].flags) do trans[i].local.pos.xy = pos
//             else{
//                 trans[i].local.pos.x = pos.x
//             }
//             trans[i].local.pos.z = 1
//         }
//     }
// }

// update_player_movement_phys :: proc(delta_time: f32)
// {
//     cc := get_component(g.player, Cmp_Collision2D)
//     if cc == nil do return
//     vel := b2.Body_GetLinearVelocity(cc.bodyid).y
//     move_speed :f32= 0.40
//     if is_key_pressed(glfw.KEY_SPACE) do vel += move_speed
//     b2.Body_SetLinearVelocity(cc.bodyid, {0,vel})
//     // b2.Body_ApplyForceToCenter(cc.bodyid, {0,100}, true)
//     // fmt.println("Entity ",g.player, " | Force : ", b2.Body_GetLinearVelocity(cc.bodyid), " | ")
//     // fmt.println("Entity ",g.player, " | Position : ", b2.Body_GetPosition(cc.bodyid), " | ")
// }

//----------------------------------------------------------------------------\\
// /AI A-Star Pathfinding
//----------------------------------------------------------------------------\\
pos_equal :: proc(a : vec2i, b : vec2i) -> bool {
    return a[0] == b[0] && a[1] == b[1]
}

pos_to_index :: proc(p : vec2i) -> int {
    return int(p[0]) + int(p[1]) * GRID_WIDTH
}

index_to_pos :: proc(i : int) -> vec2i {
    return vec2i{ i16(i % GRID_WIDTH), i16(i / GRID_WIDTH) }
}

in_bounds :: proc(p : vec2i) -> bool {
    if p[0] < 0 || p[0] >= i16(GRID_WIDTH) || p[1] < 0 || p[1] >= i16(GRID_HEIGHT) {
        return false
    }
    return true
}

is_walkable :: proc(p : vec2i, goal : vec2i) -> bool {
    if pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !in_bounds(p) { return false }
    t := g.level.grid[p[0]][p[1]]
    return t == Tile.Blank || t == Tile.Weapon
}

abs_i :: proc(x : int) -> int {
    if x < 0 { return -x }
    return x
}

dist_grid :: proc(a : vec2i, b : vec2i) -> int {
    dx := abs_i(int(a[0]) - int(b[0]))
    dy := abs_i(int(a[1]) - int(b[1]))
    return dx + dy
}

heuristic :: proc(a : vec2i, b : vec2i) -> int {
    //Manhattan distance
    return dist_grid(a,b)
}

// Returns path from start to goal as dynamic array of vec2i (start .. goal).
// If no path found, returned array length == 0
total_cells :: GRID_HEIGHT * GRID_WIDTH
a_star_find_path :: proc(start : vec2i, goal, size : vec2i) -> [dynamic]vec2i {
    // Static arrays sized for grid
    g_score : [total_cells]int
    f_score : [total_cells]int
    came_from : [total_cells]vec2i
    in_open : [total_cells]bool
    closed : [total_cells]bool

    // init
    for i in 0..<total_cells{
        g_score[i] = 999999
        f_score[i] = 999999
        came_from[i] = vec2i{-1, -1}
        in_open[i] = false
        closed[i] = false
    }

    start_idx := pos_to_index(start)
    goal_idx := pos_to_index(goal)

    g_score[start_idx] = 0
    f_score[start_idx] = heuristic(start, goal)
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

        current_pos := index_to_pos(current_idx)

        if current_idx == goal_idx {
            // reconstruct path
            path := make([dynamic]vec2i, context.temp_allocator)
            // backtrack
            node_idx := current_idx
            for {
                append(&path, index_to_pos(node_idx))
                if node_idx == start_idx { break }
                parent := came_from[node_idx]
                // if no parent, fail
                if parent[0] == -1 && parent[1] == -1 {
                    // failed reconstruction
                    path = make([dynamic]vec2i, context.temp_allocator)
                    return path
                }
                node_idx = pos_to_index(parent)
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
            if !in_bounds(neighbor) { continue }
            if !is_walkable(neighbor, goal) { continue }
            neighbor_idx := pos_to_index(neighbor)
            if closed[neighbor_idx] { continue }

            tentative_g := g_score[current_idx] + 1

            if !in_open[neighbor_idx] || tentative_g < g_score[neighbor_idx] {
                came_from[neighbor_idx] = current_pos
                g_score[neighbor_idx] = tentative_g
                f_score[neighbor_idx] = tentative_g + heuristic(neighbor, goal)
                in_open[neighbor_idx] = true
            }
        }
    }
}

is_walkable_internal :: proc(p : vec2i, goal : vec2i, allow_through_walls : bool) -> bool {
    if pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !in_bounds(p) { return false }
    t := g.level.grid[p[0]][p[1]]
    if t == Tile.Blank || t == Tile.Weapon { return true }
    if allow_through_walls && t == Tile.Wall { return true }
    return false
}

// //----------------------------------------------------------------------------\\
// // /debug lines
// //----------------------------------------------------------------------------\\
// create_debug_quad :: proc(pos: b2.Vec2, extents: b2.Vec2, mat_unique_id: i32 = 1125783744) -> Entity {
//     e := create_node_entity("debug_quad", ComponentFlag.PRIMITIVE)
//     pos3 := vec3{ pos.x, pos.y, 0.0 }
//     half_ext := vec3{ extents.x * 0.5, extents.y * 0.5, 0.1 }
//     rot_q := vec4{ 0.0, 0.0, 0.0, 1.0 } // identity rotation
//     add_component(e, cmp_transform_prs_q(pos3, rot_q, half_ext))
//     add_component(e, material_component(i32(mat_unique_id)))
//     add_component(e, primitive_component_with_id(-6))
//     add_component(e, Cmp_Render{ type = {.PRIMITIVE} })
//     add_component(e, Cmp_Root{})
//     add_component(e, Cmp_Node{engine_flags = {.ROOT}})
//     added_entity(e)
//     return e
// }

// create_debug_cube :: proc(pos: b2.Vec2, extents: b2.Vec2, mat_unique_id: i32 = 1125783744) -> Entity {
//     e := create_node_entity("debug_cube", ComponentFlag.PRIMITIVE)
//     pos3 := vec3{ pos.x, pos.y, 1.0 }
//     rot_q := vec4{ 0.0, 0.0, 0.0, 1.0 } // identity rotation
//     add_component(e, cmp_transform_prs_q(pos3, rot_q, {extents.x, extents.y, .1}))
//     add_component(e, material_component(i32(mat_unique_id)))
//     add_component(e, primitive_component_with_id(-2))
//     add_component(e, Cmp_Render{ type = {.PRIMITIVE} })
//     add_component(e, Cmp_Root{})
//     added_entity(e)
//     return e
// }

// // Create a debug cube (visual) and also attach collision similar to create_barrel.
// // pos and extents are in world units; collision is created in Box2D space using g_b2scale.
// create_debug_cube_with_col :: proc(pos: b2.Vec2, extents: b2.Vec2, mat_unique_id: i32 = 1125783744) -> Entity {
//     // create visual cube first
//     e := create_debug_cube(pos, extents, mat_unique_id)

//     // get transform (visual) to base collision on
//     bt := get_component(e, Cmp_Transform)
//     if bt == nil do return e

//     col := Cmp_Collision2D{
//         bodydef = b2.DefaultBodyDef(),
//         shapedef = b2.DefaultShapeDef(),
//         type = .Box,
//         flags = CollisionFlags{.Movable}
//     }
//     col.bodydef.fixedRotation = true
//     col.bodydef.type = .dynamicBody
//     // convert world position to Box2D space
//     col.bodydef.position = b2.Vec2{ pos.x * g_b2scale, pos.y * g_b2scale }
//     col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

//     // extents parameter is full size; Box2D MakeBox expects half-extents, in Box2D units
//     half := b2.Vec2{ (extents.x) * g_b2scale, (extents.y) * g_b2scale }
//     box := b2.MakeBox(half.x, half.y)

//     col.shapedef = b2.DefaultShapeDef()
//     col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingEnvironment})
//     col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player, .Environment, .MovingFloor})
//     col.shapedef.enableContactEvents = true
//     col.shapedef.density = g_contact_identifier.Wall
//     col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

//     add_component(e, col)
//     return e
// }
