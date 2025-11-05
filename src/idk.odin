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

// Find the camera entity in the scene
find_camera_entity :: proc() {
    camera_archetypes := query(has(Cmp_Camera), has(Cmp_Transform), has(Cmp_Node))

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
    if !entity_exists(g.light_entity) {
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

    g_raytracer.update_flags += {.LIGHT}
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