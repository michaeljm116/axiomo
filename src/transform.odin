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

// Process all entities with Transform and Node components
transform_sys_process :: proc() {
    archetypes := query(ecs.has(Cmp_Transform), ecs.has(Cmp_Node), ecs.has(Cmp_Root))

    for archetype in archetypes {
        node_comps := get_table(archetype, Cmp_Node)
        for &node in node_comps {
            sqt_transform(&node)
        }
    }
}

// SQT Transform procedure (main transformation logic)
sqt_transform :: proc(nc: ^Cmp_Node) {
    tc := get_component(nc.entity, Cmp_Transform)
    if tc == nil { return }

    parent_ent := nc.parent
    has_parent := parent_ent != Entity(0)
    pc := get_component(parent_ent, Cmp_Node) if has_parent else nil

    // Local transform
    local := linalg.matrix4_translate_f32(tc.local.pos.xyz) * linalg.matrix4_from_quaternion_f32(tc.local.rot)
    scale_m := linalg.matrix4_scale_f32(tc.local.sca.xyz)

    x,y,z := linalg.euler_angles_from_quaternion_f32(tc.local.rot, .XYZ)
    tc.euler_rotation = linalg.to_degrees(vec3{x,y,z})

    // Combine with parent if exists
    if has_parent {
        pt := get_component(parent_ent, Cmp_Transform)
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
            rt.lights[0] = gpu.Light{
                pos = tc.world[3].xyz,
                color = l.color,
                intensity = l.intensity,
                id = l.id,
            }
        }
    }

    // Recurse for children
    if nc.is_parent {
        for child_ent in nc.children {
            child_nc := get_component(child_ent, Cmp_Node)
            if child_nc != nil {
                sqt_transform(child_nc)
            }
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