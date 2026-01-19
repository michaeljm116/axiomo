package game

import "core:fmt"
import "core:mem"
import "core:math"
import "core:math/linalg"
import "vendor:glfw"
import "axiom"
import "axiom/resource"
import "core:log"
import b2 "vendor:box2d"

Room :: struct
{
	using entrance : AreaEntry,
	battle : Battle,
	is_battle : bool,
}

Floor :: struct
{
	using entrance : AreaEntry,
	rooms : map[string]Room,
}

Inn :: struct
{
	levels : map[u32]Floor,
}

AreaEntry :: struct
{
	entry : AreaTrigger,
	exit : AreaTrigger,
}

AreaTrigger :: struct
{
	dir : AreaDirection,
	can_enter : bool,
	pos : vec2f,
	len : f32,
}
AreaDirection :: enum{Up,Down,Left,Right}

overworld_detect_area_change :: proc(player_transform : Cmp_Transform, trigger : AreaTrigger) -> bool
{
    using player_transform.local
    px := pos.x
    py := pos.y
    tx := trigger.pos.x
    ty := trigger.pos.y
    tl := trigger.len

    switch trigger.dir {
	    case .Up: return py > ty && px > tx && px < tx + tl
	    case .Down: return py < ty && px > tx && px < tx + tl
	    case .Left: return px < tx && py > ty && py < ty + tl
	    case .Right: return px > tx && py > ty && py < ty + tl
    }
    return false
}



CollisionCategory :: enum
{
    Player,
    Enemy,
    Projectile,
    EnemyProjectile,
    Environment,
    MovingEnvironment,
    MovingFloor
}
CollisionCategories :: bit_set[CollisionCategory; u64]

ContactDensities :: struct
{
    Player : f32,
    Vax : f32,
    Doctor : f32,
    Projectiles : f32,
    Wall : f32
}

g_contact_identifier := ContactDensities {
	Player      = 9.0,
	Vax         = 50.0,
	Doctor      = 200.0,
	Projectiles = 8.0,
	Wall        = 800.0
}

overworld_start :: proc() {
	load_scene("Overworld")
	g.player = axiom.load_prefab("Froku", g.mem_game.alloc)
	find_camera_entity()
	find_floor_entities()

	overworld_place_entity_on_floor(g.player, g.floor)
	overworld_setup_col_player(axiom.g_physics)
	overworld_setup_col_floor(axiom.g_physics)

	axiom.sys_trans_process_ecs()
}

overworld_update :: proc(dt : f32){
    overworld_update_player_movement(g.player, dt)
    overworld_point_camera_at_2(g.player)

    trans := get_component(g.player, Cmp_Transform)
    if trans == nil {
        log.error("transform not found")
        return
    }
    if trans.local.pos.x >= 20 do overworld_end()
}

overworld_end :: proc()
{
    app_restart()
    g.app_state = .Game
    ToggleMenuUI(&g.app_state)
    battle_start()
    start_game()
}

overworld_point_camera_at_2 :: proc(entity: Entity){
    if !entity_exists(g.camera_entity) do find_camera_entity()
    if !entity_exists(entity) do find_player_entity()

    pt := get_component(entity, Cmp_Transform)
    ct := get_component(g.camera_entity, Cmp_Transform)
    if pt == nil || ct == nil{
        log.error("transform not found")
        return
    }

    overworld_follow_player(ct, pt)
    overworld_look_at_player(ct, pt)
}
overworld_point_camera_at :: proc(entity: Entity){
    if !entity_exists(g.camera_entity) do find_camera_entity()
    if !entity_exists(entity) do find_player_entity()

    pt := get_component(entity, Cmp_Transform)
    ct := get_component(g.camera_entity, Cmp_Transform)
    if pt == nil || ct == nil{
        log.error("transform not found")
        return
    }

    ct^ = pt^
    ct^.local.pos.y += 12.0
    ct^.local.pos.z -= 8.0

    // // Compute look-at rotation to face the player
    target := pt.local.pos.xyz
    dir := linalg.normalize(target - ct.local.pos.xyz)

    horiz_len := math.sqrt_f32(dir.x * dir.x + dir.z * dir.z)
    pitch_rad := math.atan2_f32(dir.y, horiz_len)
    yaw_rad := math.atan2_f32(dir.x, dir.z)

    ct^.local.rot = linalg.quaternion_from_euler_angles_f32(pitch_rad, 0, yaw_rad, .XYZ)
}

overworld_place_entity_on_floor :: proc(entity: Entity, floor : Entity){
    // First get their transforms
    ft := get_component(floor, Cmp_Transform)
    pt := get_component(entity, Cmp_Transform)
    if ft == nil || pt == nil do return

    //The find the top of floor and bottom of entity:
    floor_top := get_top_of_entity(floor)
    entity_bottom := get_bottom_of_entity(entity)

    if entity_bottom == -999999.0 { return }

    dy := floor_top - entity_bottom
    pt.local.pos.y += dy
}

overworld_update_player_movement :: proc(player: Entity, dt: f32) {
    cc := get_component(player, Cmp_Collision2D)
    if cc == nil do return

    body := cc.bodyid
    vel := b2.Body_GetLinearVelocity(body)

    move_speed :: f32(12.0)

    input_x: f32 = 0
    input_z: f32 = 0

    if is_key_pressed(glfw.KEY_A) do input_x -= 1.0
    if is_key_pressed(glfw.KEY_D) do input_x += 1.0
    if is_key_pressed(glfw.KEY_W) do input_z += 1.0
    if is_key_pressed(glfw.KEY_S) do input_z -= 1.0

    // Normalize diagonal movement
    mag_sq := input_x*input_x + input_z*input_z
    if mag_sq > 0.0 {
        mag := math.sqrt_f32(mag_sq)
        input_x = (input_x / mag) * move_speed
        input_z = (input_z / mag) * move_speed
    } else {
        input_x = 0
        input_z = 0
    }

    // Set velocity directly (simple top-down control, physics handles collisions)
    vel.x = input_x
    vel.y = input_z
    b2.Body_SetLinearVelocity(body, vel)
}

overworld_setup_col_player :: proc(physics : ^axiom.Sys_Physics){
    find_player_entity()
    pt := get_component(g.player, Cmp_Transform)
    // Build collision components. Body position is the body origin in world space.
    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Capsule,
        flags = {.Player}
    }
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    // Place the body origin at the transform world position (pt.world[3] should be the object's world origin)
    col.bodydef.position = pt.world[3].xy
    col.bodyid = b2.CreateBody(physics.world_id, col.bodydef)

    // Define the capsule in body-local coordinates (centered on the body origin).
    // Use half extents from the transform scale. magic_scale_number still applied to y if needed.
    box := b2.MakeBox(pt.local.sca.x,pt.local.sca.y)
    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.Player})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Environment, .MovingEnvironment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = g_contact_identifier.Player
    // col.shapeid = b2.CreateCapsuleShape(col.bodyid, col.shapedef, capsule)
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    add_component(g.player, col)
    //add_component(g.player, capsule)
}

overworld_setup_col_floor :: proc(physics : ^axiom.Sys_Physics){
    //create static floor
    {
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Box
        }
        col.bodydef.fixedRotation = true
        col.bodydef.type = .staticBody
        col.bodydef.position = {0,-2.0}
        col.bodyid = b2.CreateBody(physics.world_id, col.bodydef)
        box := b2.MakeBox(500, 1.0)

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Player, .MovingEnvironment, .MovingFloor, .Environment, .Enemy})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = 10000
        col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    }

    find_floor_entities()
    fc := get_component(g.floor, Cmp_Transform)
    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Box,
        flags = {.Movable, .Floor}
    }
    // move := Cmp_Movable{speed = -2.0}
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    col.bodydef.position = {fc.world[3].x, fc.world[3].y - 1}
    col.bodydef.gravityScale = 0
    col.bodyid = b2.CreateBody(physics.world_id, col.bodydef)
    box := b2.MakeBox(fc.local.sca.x, fc.local.sca.y)

    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingFloor})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Environment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = 1000.0
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    add_component(g.floor, col)
}

overworld_look_at_player :: proc(ct: ^Cmp_Transform, pt: ^Cmp_Transform) {
    target_dir := linalg.normalize(ct.local.pos.xyz - pt.local.pos.xyz)

    // Unused in original
    _x_angle := linalg.dot(target_dir, vec3{-1, 0, 0})
    _y_angle := linalg.dot(target_dir, vec3{0, 0, 1})

    yaw   := -target_dir.x
    pitch :=  target_dir.z
    roll  := f32(0)

    // Compose matrix to match GLM yawPitchRoll: rotateY(yaw) * rotateX(pitch) * rotateZ(roll)
    mat_y := linalg.matrix4_rotate_f32(yaw,   {0,1,0})
    mat_x := linalg.matrix4_rotate_f32(pitch, {1,0,0})
    mat_z := linalg.matrix4_rotate_f32(roll,  {0,0,1})
    rot_mat := mat_y * mat_x * mat_z

    // Extract upper 3x3 for quaternion (flatten literal)
    rot_mat3 := linalg.Matrix3f32{
        rot_mat[0][0], rot_mat[0][1], rot_mat[0][2],
        rot_mat[1][0], rot_mat[1][1], rot_mat[1][2],
        rot_mat[2][0], rot_mat[2][1], rot_mat[2][2],
    }
    target_quat := linalg.quaternion_from_matrix3_f32(rot_mat3)
    ct.local.rot = target_quat
}

overworld_follow_player :: proc(ct: ^Cmp_Transform, pt: ^Cmp_Transform) {
    ct.local.pos.x = pt.local.pos.x
    ct.local.pos.z = pt.local.pos.z
}

// Fixed version with proper look-at (recommended for actual use)
overworld_look_at_player_fixed :: proc(ct: ^Cmp_Transform, pt: ^Cmp_Transform, player_eye_height: f32 = 1.5) {
    target := pt.local.pos.xyz + {0, player_eye_height, 0}
    dir := linalg.normalize(target - ct.local.pos.xyz)

    horiz_len := math.sqrt_f32(dir.x*dir.x + dir.z*dir.z)
    pitch_rad := math.atan2_f32(dir.y, horiz_len)
    yaw_rad   := math.atan2_f32(dir.x, dir.z)

    // Match GLM yawPitchRoll order: .YXZ (yaw Y, pitch X, roll Z)
    ct.local.rot = linalg.quaternion_from_euler_angles_f32(yaw_rad, pitch_rad, 0.0, .YXZ)
}

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
// update_movables :: proc(delta_time: f32)
// {
//     //First just the visible g.floor
//     for i in 0..<2{
//         fc := get_component(g.floor, Cmp_Transform)
//         fc.local.pos.x -= 1.0 * delta_time

//         //refresh world if done
//         if fc.local.pos.x <= -100.0 {
//             fmt.println("Floor  ", i, "  | Trans: ", fc.local.pos.xy)
//             for e in g_objects[curr_phase] do remove_entity(e)
//             vmem.arena_free_all(&distance_arena[curr_phase])
//             curr_phase = (curr_phase + 1) % 2

//             col := get_component(g.floor, Cmp_Collision2D)
//             fc.local.pos.x += 200.0
//             trans := b2.Body_GetTransform(col.bodyid)
//             trans.p.x = fc.local.pos.x
//             b2.Body_SetTransform(col.bodyid, trans.p, trans.q)
//         }
//     }
//     movables := query(has(Cmp_Collision2D))
//     for movable in movables{
//         cols := get_table(movable, Cmp_Collision2D)
//         for e, i in movable.entities{
//             if .Movable in cols[i].flags{
//                 nc := get_component(e, Cmp_Node)
//                 tc := get_component(e, Cmp_Transform)
//                 // fmt.println("movable, ", nc.name)
//                 // b2.Body_SetLinearVelocity(cols[i].bodyid, {delta_time * -1.0, 0})
//                 // b2.Body_ApplyLinearImpulse(cols[i].bodyid, {-2.0,0}, {0.5,0.5}, true)
//                 vel := b2.Body_GetLinearVelocity(cols[i].bodyid)
//                 vel.x = -4
//                 b2.Body_SetLinearVelocity(cols[i].bodyid, vel)
//                 // b2.Body_ApplyForceToCenter(cols[i].bodyid, {0,1000.0}, true)
//                 //fmt.printfln("Entity")
//                 // fmt.println("Entity: ",nc.name, " | Position : ", b2.Body_GetPosition(cols[i].bodyid), " | Trans: ", tc.local.pos.xy)
//             }
//         }
//     }
// }
