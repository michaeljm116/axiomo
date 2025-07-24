package main

import "gpu"
import "core:fmt"
import math "core:math"
import linalg "core:math/linalg"
import "external/ecs"
import "core:slice"

//----------------------------------------------------------------------------\\
// /Transform System /ts
//----------------------------------------------------------------------------\\

Sys_Transform :: struct {
    // ECS world reference (assuming global g_world)
}

// Create a new transform system
transform_sys_create :: proc() -> ^Sys_Transform {
    system := new(Sys_Transform)
    return system
}

// Destroy transform system
transform_sys_destroy :: proc(system: ^Sys_Transform) {
    free(system)
}

// Process all entities with Transform and Node components
transform_sys_process :: proc() {
    archetypes := query(ecs.has(Cmp_Transform), ecs.has(Cmp_Node), ecs.has(Cmp_HeadNode))

    for archetype in archetypes {
        transform_comps := get_table(archetype, Cmp_Transform)
        node_comps := get_table(archetype, Cmp_Node)

        for i in 0..<len(transform_comps) {
            sqt_transform(&node_comps[i])
        }
    }
}

// SQT Transform procedure (main transformation logic)
sqt_transform :: proc(nc: ^Cmp_Node) {
    tc := get_component(nc.entity, Cmp_Transform)
    if tc == nil { return }

    pc := get_component(nc.parent, Cmp_Node) if nc.parent != Entity(0) else nil
    has_parent := pc != nil

    // Local transform
    local := linalg.matrix4_translate_f32(tc.local.pos.xyz) * linalg.matrix4_from_quaternion_f32(tc.local.rot)
    scale_m := linalg.matrix4_scale_f32(tc.local.sca.xyz)

    x,y,z := linalg.euler_angles_from_quaternion_f32(tc.local.rot, .XYZ)
    tc.euler_rotation = linalg.to_degrees(vec3{x,y,z})

    // Combine with parent if exists
    if has_parent {
        pt := get_component(nc.parent, Cmp_Transform)
        tc.global.sca = tc.local.sca * pt.global.sca
        tc.global.rot = tc.local.rot * pt.global.rot
        tc.trm = pt.world * local
        local = local * scale_m
        tc.world = pt.world * local
    } else {
        tc.global.sca = tc.local.sca
        tc.global.rot = tc.local.rot
        tc.trm = local
        local = local * scale_m
        tc.world = local
    }

    // Update specific components
    if .PRIMITIVE in nc.engine_flags {
        obj_comp := get_component(nc.entity, Cmp_Primitive)
        if obj_comp != nil {
            obj_comp.extents = tc.global.sca.xyz
            rot_mat := linalg.Matrix3f32{
                tc.world[0].x, tc.world[0].y, tc.world[0].z,
                tc.world[1].x, tc.world[1].y, tc.world[1].z,
                tc.world[2].x, tc.world[2].y, tc.world[2].z
            }
            obj_comp.aabb_extents = rotate_aabb(rot_mat)
            obj_comp.world = obj_comp.id < 0 ? tc.trm : tc.world
        }
    } else if .CAMERA in nc.engine_flags {
        c := get_component(nc.entity, Cmp_Camera)
        if c != nil {
            c.rot_matrix = tc.world
            update_camera(c) // Call update_camera from raytracer.odin
        }
    } else if .LIGHT in nc.engine_flags {
        l := get_component(nc.entity, Cmp_Light)
        if l != nil {
            // Update light in render system
            light := gpu.Light{
                pos = tc.world[3].xyz,
                color = l.color,
                intensity = l.intensity,
                id = l.id,
            }
            update_light(l.id, light) // Assuming update_light is defined elsewhere
        }
    }

    // Recurse for children
    if nc.is_parent {
        for child in nc.children {
            sqt_transform(child)
        }
    }
}

// Rotate AABB procedure
rotate_aabb :: proc(m: linalg.Matrix3f32) -> vec3 {
    extents := vec3{1, 1, 1}
    v: [8]vec3 = {
        extents,
        {extents.x, extents.y, -extents.z},
        {extents.x, -extents.y, -extents.z},
        {extents.x, -extents.y, extents.z},
        -extents,
        {-extents.x, -extents.y, extents.z},
        {-extents.x, extents.y, -extents.z},
        {-extents.x, extents.y, extents.z},
    }

    // Transform vectors
    for i in 0..<8 {
        v[i] = linalg.abs(m * v[i])
    }

    // Find max extents
    vmax := vec3{-math.F32_MAX, -math.F32_MAX, -math.F32_MAX}
    for i in 0..<8 {
        vmax.x = math.max(vmax.x, v[i].x)
        vmax.y = math.max(vmax.y, v[i].y)
        vmax.z = math.max(vmax.z, v[i].z)
    }

    return vmax
}

// Geometry transform converter (constrain scales for certain primitives)
geometry_transform_converter :: proc(nc: ^Cmp_Node) {
    if .MESH in nc.engine_flags || .MODEL in nc.engine_flags || .BOX in nc.engine_flags {
        return
    }
    tc := get_component(nc.entity, Cmp_Transform)
    if tc == nil { return }

    if .SPHERE in nc.engine_flags {
        tc.global.sca.y = tc.global.sca.x
        tc.global.sca.z = tc.global.sca.x
    }
    if .CYLINDER in nc.engine_flags {
        tc.global.sca.z = tc.global.sca.x
    }
}