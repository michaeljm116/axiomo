package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "vendor:glfw"
import "axiom"

// Find the camera entity in the scene
find_camera_entity :: proc() {
    table_camera := get_table(Cmp_Camera)
    for camera, i in table_camera.rows{
        g.camera_entity = table_camera.rid_to_eid[i]
        return
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
    if g.player != Entity(0) {
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
    fmt.println("Player facing left")
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
