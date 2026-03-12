package game

import "vendor:windows/XAudio2"
import "core:container/small_array"
import "core:math"
import "core:math/linalg"
import "vendor:glfw"
import "axiom"
import "core:log"
import b2 "vendor:box2d"
import "core:fmt"
import lex"lexicon"
import xxh"axiom/extensions/xxhash2"

overworld_detect_area_change :: proc(player_transform : Cmp_Transform, trigger : AreaTrigger) -> bool
{
    px := player_transform.local.pos.x
    py := player_transform.local.pos.z
    tx := trigger.pos.x
    ty := trigger.pos.y
    tl := trigger.len

    switch trigger.dir {
	    case .Up: return py > ty && px > tx && px < tx + tl
	    case .Down: return py < ty && px > tx && px < tx + tl
	    case .Left: return px < tx && py > ty && py < ty + tl
	    case .Right: return px > tx && py > ty && py < ty + tl
		case .None: return false
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

MovementState :: enum
{
	Idle, Walk, Run
}
CharacaterState :: struct
{
	movement_type : MovementState,
	name_hash : u32,
	start_transition_time : f32,
	end_transition_time : f32,
}
MAX_CHARACTER_STATES :: 3
Cmp_Character :: struct {
	using movement : Cmp_Movement,
	prefab_name : int,
	states : [MovementState]CharacaterState,
	curr_state : CharacaterState,
	in_trans : bool,
	trans_time : CurrMax,
}

Cmp_Movement :: struct {
	curr_speed : f32,
	curr_time : f32,
	walk_speed : f32,
	run_speed : f32,

	prev_y : f32,

	forward_dir : vec2f,
	right_dir : vec2f,
	move_dir : vec2f,

	is_grounded : bool,
	times : MovementTimes,
}

init_character :: proc(c : ^Cmp_Character, e : Entity)
{
	c.prefab_name = 0
	c.states[.Idle] = {.Idle, xxh.str_to_u32("Idle"), 0, 0}
	c.states[.Walk] = {.Walk, xxh.str_to_u32("Walk"), 0, 0}
	c.states[.Run] = {.Run,  xxh.str_to_u32("Run"),  0, 0}
	c.curr_state = c.states[.Idle]

	init_cmp_movement(&c.movement)

    axiom.flatten_entity(e)
    ac := axiom.animation_component_with_names(2,lex.ENTITY_FROKU, lex.IDLE_START, lex.IDLE_END, axiom.AnimFlags{ active = 1, loop = true, force_start = true, force_end = true})
    add_component(e, ac)
    axiom.sys_anim_add(e)
    // animate_idle(&ac, prefab, c.move_anim)
}

init_cmp_movement :: proc(m : ^Cmp_Movement){
	m.curr_speed = 0
	m.curr_time = 0
	m.walk_speed = 5.0
	m.run_speed = 20.0
	m.prev_y = 0.0
	m.times = MovementTimes{
        idle_time = 1.5,
        walk_time = 0.25,
        run_time = 0.4,
        jump_time = 0.25
    }
}

o_character : Cmp_Character
ow_cc_update :: proc(player : Entity, cm : ^Cmp_Character, dt : f32)
{
	fmt.println("MovementState : ", cm.curr_state.movement_type)
	switch cm.curr_state.movement_type
	{
	case .Idle: ow_cc_update_idle(player, cm, dt)
	case .Walk: ow_cc_update_walk(player, cm, dt)
	case .Run: ow_cc_update_run(player, cm, dt)
	}
}

ow_cc_update_idle :: proc(player : Entity, cm : ^Cmp_Character, dt : f32){
	if game_controller_is_moving(){
		ac := get_component(player, Cmp_Animation)
		ac.state = .DEFAULT
		animate_walk(ac, lex.PREFAB_FROKU, cm.times)
		cm.curr_state.movement_type = .Walk
		cm.curr_speed = cm.walk_speed
		// ow_cc_update_walk(player, cm, dt)
	}
}

transition_time :: 0.5
ow_cc_update_walk :: proc(player : Entity, cm : ^Cmp_Character, dt : f32){
	// Setup
	ac := get_component(player, Cmp_Animation)
	cc := get_component(player, Cmp_Collision2D)

	cm.curr_speed = ow_calculate_speed(cm^, dt)
	if cm.curr_speed >= cm.run_speed{
		ac.state = .DEFAULT
		animate_run(ac, lex.PREFAB_FROKU, cm.times)
	}
	if cm.curr_speed <= 0{
		ac.state = .DEFAULT
		animate_idle(ac, lex.PREFAB_FROKU, cm.times)
	}
	// Actuallly move the character now
	ow_move_character(cm^, cc.bodyid)
}

ow_cc_update_run :: proc(player : Entity, cm : ^Cmp_Character, dt : f32){
	// Setup
	ac := get_component(player, Cmp_Animation)
	cc := get_component(player, Cmp_Collision2D)

	// calculate Acceleration
	cm.curr_speed = ow_calculate_speed(cm^, dt)

	//keep running or transition based on speed
	half_way := (cm.run_speed - cm.walk_speed) * .5 + cm.walk_speed
	if cm.curr_speed <= half_way{
		cm.curr_state = cm.states[.Walk]
		animate_walk(ac, lex.PREFAB_FROKU, cm.times)
	}
	ow_move_character(cm^, cc.bodyid)
}

ow_move_character :: #force_inline proc(cm : Cmp_Character, body : b2.BodyId)
{
	movement := cm.forward_dir * .42 * cm.curr_speed
	b2.Body_SetLinearVelocity(body, movement)
}

ow_calculate_speed :: proc(cm : Cmp_Character, dt : f32) -> f32
{
	change_in_speed := cm.run_speed - cm.walk_speed
	accleration := change_in_speed / transition_time * dt
	speed := cm.curr_speed
	if game_controller_is_moving() do speed += accleration
	else do speed -= 2 * accleration
	return linalg.clamp(speed, 0, cm.run_speed)
}

ow_calc_dir :: proc(cm : ^Cmp_Character, rot : quat){
	dir := linalg.yaw_from_quaternion(rot);
	cosdir := linalg.cos(dir) * linalg.cos(linalg.pitch_from_quaternion(rot));
	sindir := linalg.sin(dir);

	cm.forward_dir = vec2f{sindir, cosdir};
	cm.right_dir = vec2f{cosdir, -sindir};
}
ow_calc_rot :: proc(cm : ^Cmp_Character, rot : ^quat, body : b2.BodyId){
		d := eight_deg_rot_convert(game_controller_move_axis().as_int)
		fmt.println("ROT: ", d)
		quat_to_rotate_towards := eight_degree_quat[d]

		// Perform and update the rotation
		rot^ = linalg.quaternion_slerp(rot^, quat_to_rotate_towards, f32(0.15))
		bt := b2.Body_GetTransform(body)
		bt.q = {cm.forward_dir.y, cm.forward_dir.x}
		b2.Body_SetTransform(body, bt.p, bt.q)
}

overworld_start :: proc() {
	load_scene(lex.SCENE_OVERWORLD)
	g.player = axiom.load_prefab(lex.ENTITY_FROKU, g.mem_game.alloc)
	init_character(&o_character, g.player)

	find_camera_entity()
	find_floor_entities()

    // room, _ := find_room_and_floor(&g.inn, g.inn.curr)
    // if room != nil {
    //     exit_pos := room.exit.pos
    //     pt := get_component(g.player, Cmp_Transform)
    //     if pt != nil {
    //         pt.local.pos.x = exit_pos.x
    //         pt.local.pos.y = exit_pos.y
    //     }
    // }

	overworld_place_entity_on_floor(g.player, g.floor)
	overworld_setup_col_player(axiom.g_physics)
	overworld_setup_col_floor(axiom.g_physics)

	axiom.sys_trans_process_ecs()
}

overworld_update :: proc(dt : f32){
	trans := get_component(g.player, Cmp_Transform)
	col := get_component(g.player, Cmp_Collision2D)

	ow_calc_rot(&o_character, &trans.local.rot, col.bodyid)
	ow_calc_dir(&o_character, trans.local.rot)
	ow_cc_update(g.player, &o_character, dt)
    // overworld_update_player_movement(g.player, dt)
    overworld_point_camera_at_2(g.player)

    if trans == nil {
        log.error("transform not found")
        return
    }

    _, floor := find_room_and_floor(&g.inn, g.inn.curr)
    if floor == nil do return
    i := 0
    for name, &room in &floor.rooms
    {
    	i += 1
        if room.flag  == .Locked do return
        if overworld_detect_area_change(trans^, room.entry){
           room.flag = advance_room_flag(room.flag, .Visited)
           g.inn.curr =name
           overworld_end()
           save_inn(g.inn)
           return
        }
    }
    assert (i == 2)
}

advance_room_flag :: proc(current: RoomFlag, target: RoomFlag) -> RoomFlag {
    if transmute(u8)target > transmute(u8)current {
        return target
    }
    return current
}

overworld_end :: proc()
{
    app_restart()
    g.app_state = .Battle
    ToggleMenuUI(&g.app_state)
    battle_start(get_curr_battle_name(&g.inn))
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


//----------------------------------------------------------------------------\\
// /8 Degree rotation
//----------------------------------------------------------------------------\\
/*
-1 1   0 1   1 1

-1 0   0 0   1 0

-1-1   0-1   1-1

02 12 22
01 11 21
00 10 20

0010 0110 1010
0001 0101 1001
0000 0100 1000

2 6 10
1 5 9
0 4 8

default = 5,
up = 6,
upleft = 2,
left = 1,
downleft = 0,
down = 4,
downright = 8,
right = 9,
upright = 10

*/
RotationDir :: enum {
	downleft,
	left,
	upleft,
	null1,
	down,
	none,
	up,
	null2,
	downright,
	right,
	upright
}

eight_deg_rot_convert :: proc(axis : vec2i) -> RotationDir {
	axis_c := axis + 1
	res := axis_c.y
	res |= axis_c.x << 2
	return RotationDir(res)
}

rot_epsilon :f32= 0.01
eight_degree_float :[11]f32= {
	225 + rot_epsilon,
	270 + rot_epsilon,
	315 + rot_epsilon,
	0,
	180 + rot_epsilon,
	0,
	360 - rot_epsilon,
	0,
	135 + rot_epsilon,
	90 + rot_epsilon,
	45 + rot_epsilon
}

eight_degree_quat : [11]quat
@(init)
init_eight_degree_quats :: proc "contextless" () {
    for deg, i in eight_degree_float {
        rad := math.to_radians_f32(deg)
        eight_degree_quat[i] = linalg.quaternion_angle_axis_f32(rad, {0, 1, 0})
    }
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
