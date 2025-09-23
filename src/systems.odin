package main
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:math"
import "core:math/linalg"
import "external/ecs"
import "external/embree"

import b2"vendor:box2d"
import "resource/scene"
import "gpu"
import "resource"

// these are sus V
import "vendor:glfw"
import vmem "core:mem/virtual"

//----------------------------------------------------------------------------\\
// /Transform System /ts
//----------------------------------------------------------------------------\\

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

transform_sys_process_e :: proc() {
    archetypes := query(ecs.has(Cmp_Transform), ecs.has(Cmp_Node), ecs.has(Cmp_Root))
    for archetype in archetypes {
        for entity in archetype.entities do sqt_transform_e(entity)
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
        tc.global.sca = pt.global.sca * tc.local.sca
        tc.global.rot = pt.global.rot * tc.local.rot
        tc.trm = pt.trm * local
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
        //fmt.println("Parent: ", nc.name)
        curr_child := nc.child
        for curr_child != Entity(0) {
            child_nc := get_component(curr_child, Cmp_Node)
            //fmt.println("--Child: ", child_nc.name)
            if child_nc != nil {
                sqt_transform(child_nc)
                curr_child = child_nc.brotha
            } else {
                break
            }
        }
    }
}

sqt_transform_e :: proc(entity: Entity) {
    tc := get_component(entity, Cmp_Transform)
    nc := get_component(entity, Cmp_Node)
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
        pt := get_component(parent_ent, Cmp_Transform)^
        tc.global.sca = pt.global.sca * tc.local.sca
        tc.global.rot = pt.global.rot * tc.local.rot
        tc.trm = pt.world * local
        local = local * scale_m
        tc.world = pt.world * local
        tc.global.pos = tc.trm[3].xyzw
    } else {
        tc.global.sca = tc.local.sca
        tc.global.rot = tc.local.rot
        tc.global.pos = tc.local.pos
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
    if nc.brotha != Entity(0) do sqt_transform_e(nc.brotha)
    if nc.child != Entity(0) do sqt_transform_e(nc.child)

    // Recurse for children
    // if nc.is_parent {
    //     curr_child := nc.child
    //     for curr_child != Entity(0) {
    //         child_nc := get_component(curr_child, Cmp_Node)
    //         if child_nc != nil {
    //             sqt_transform_e(curr_child)
    //             curr_child = child_nc.brotha
    //         } else {
    //             break
    //         }
    //     }
    // }
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

//----------------------------------------------------------------------------\\
// /BVH System
//----------------------------------------------------------------------------\\

Sys_Bvh :: struct {
    device: embree.RTCDevice,
    bvh: embree.RTCBVH,
    root: BvhNode,
    num_nodes: i32,
    rebuild: bool,
}

// Global counter for node creation (matches C++ static variable)
g_num_nodes: i32 = 0

// Create a new BVH system
bvh_system_create :: proc(alloc: mem.Allocator) -> ^Sys_Bvh {
    system := new(Sys_Bvh)
    system.rebuild = true

    // Initialize Embree
    system.device = embree.rtcNewDevice(nil)
    if system.device == nil {
        free(system)
        log.panicf("Error creating Embree device")
    }

    system.bvh = embree.rtcNewBVH(system.device)

    // Set memory monitor (equivalent to C++ lambda)
    embree.rtcSetDeviceMemoryMonitorFunction(system.device,
        proc "c" (userPtr: rawptr, bytes: c.ssize_t, post: bool) -> bool {
            return true
        }, nil)
    return system
}

// Destroy BVH system
bvh_system_destroy :: proc(using system: ^Sys_Bvh) {
    if system == nil do return
    embree.rtcReleaseBVH(bvh)
    embree.rtcReleaseDevice(device)
    free(system)
}

bvh_destroy :: proc(node: BvhNode) {
    if node == nil { return }

    kind := (cast(^BvhNodeKind)node)^
    #partial switch kind {
    case .Inner:
        n := cast(^InnerBvhNode)node
        bvh_destroy(n.children[0])
        bvh_destroy(n.children[1])
        free(n)  // Assuming nodes were new()-ed or alloc-ed
    case .Leaf:
        free(cast(^LeafBvhNode)node)
    }
}

// Embree callback functions
bounds_function :: proc "c" (args: ^embree.RTCBoundsFunctionArguments) {
    context = runtime.default_context()
    prims := cast(^Cmp_Primitive)args.geometryUserPtr
    prim := mem.ptr_offset(prims, int(args.primID))

    center := prim.world[3].xyz
    lower := center - prim.extents
    upper := center + prim.extents

    args.bounds_o.lower_x = lower.x
    args.bounds_o.lower_y = lower.y
    args.bounds_o.lower_z = lower.z
    args.bounds_o.upper_x = upper.x
    args.bounds_o.upper_y = upper.y
    args.bounds_o.upper_z = upper.z
}

split_primitive :: proc "c" (
    prim: ^embree.RTCBuildPrimitive,
    dim: u32,
    pos: f32,
    lprim: ^embree.RTCBounds,
    rprim: ^embree.RTCBounds,
    userPtr: rawptr
) {
    context = runtime.default_context()
    assert(dim < 3)
    assert(prim.geomID == 0)

    // Copy bounds to left and right primitives
    mem.copy(lprim, prim, size_of(embree.RTCBounds))
    mem.copy(rprim, prim, size_of(embree.RTCBounds))

    // Split at position
    switch dim {
    case 0: // X
        lprim.upper_x = pos
        rprim.lower_x = pos
    case 1: // Y
        lprim.upper_y = pos
        rprim.lower_y = pos
    case 2: // Z
        lprim.upper_z = pos
        rprim.lower_z = pos
    }
}

create_inner :: proc "c" (alloc: embree.RTCThreadLocalAllocator, numChildren: u32, userPtr: rawptr) -> rawptr {
    context = runtime.default_context()
    assert(numChildren == 2)
    ptr := embree.rtcThreadLocalAlloc(alloc, size_of(InnerBvhNode), 16)
    g_num_nodes += 1
    node := cast(^InnerBvhNode)ptr
    mem.zero(node, size_of(InnerBvhNode))
    node.kind = .Inner  // ADD THIS
    return ptr
}

set_children :: proc "c" (bvhNodePtr: rawptr, childPtr: ^^rawptr, numChildren: u32, userPtr: rawptr) {
    context = runtime.default_context()
    assert(numChildren == 2)
    node := cast(^InnerBvhNode)bvhNodePtr

    children_array := transmute([^]BvhNode)childPtr
    node.children[0] = children_array[0]
    node.children[1] = children_array[1]
}

set_bounds :: proc "c" (bvhNodePtr: rawptr, bounds: ^^embree.RTCBounds, numChildren: u32, userPtr: rawptr) {
    context = runtime.default_context()
    assert(numChildren == 2)
    node := cast(^InnerBvhNode)bvhNodePtr

    for i in 0..<2 {
        bounds_ptr := mem.ptr_offset(bounds, i)
        // Convert RTCBounds to BvhBounds
        rtc_bounds := bounds_ptr^
        node.bounds[i] = BvhBounds{
            lower = {rtc_bounds.lower_x, rtc_bounds.lower_y, rtc_bounds.lower_z},
            upper = {rtc_bounds.upper_x, rtc_bounds.upper_y, rtc_bounds.upper_z},
        }
    }
}

create_leaf :: proc "c" (
    alloc: embree.RTCThreadLocalAllocator,
    prims: ^embree.RTCBuildPrimitive,
    numPrims: c.size_t,
    userPtr: rawptr
) -> rawptr {
    context = runtime.default_context()
    MIN_LEAF_SIZE :: 1
    MAX_LEAF_SIZE :: 1

    ptr := embree.rtcThreadLocalAlloc(alloc, size_of(LeafBvhNode), 16)
     g_num_nodes += 1

    // Create leaf node
    node := cast(^LeafBvhNode)ptr
    node.kind = .Leaf
    node.id = prims.primID
    node.bounds = BvhBounds{
        lower = {prims.lower_x, prims.lower_y, prims.lower_z},
        upper = {prims.upper_x, prims.upper_y, prims.upper_z},
    }

    return ptr
}

// Build the BVH tree
bvh_system_build :: proc(using system: ^Sys_Bvh, alloc : mem.Allocator) {
    //context.allocator = alloc
    if !rebuild do return
    g_num_nodes = 0

    //Now Begin reseriving
    archetypes := query(has(Cmp_Primitive), has(Cmp_Node), has(Cmp_Transform))
    num_ents := 0
    for a in archetypes do num_ents += len(a.entities)

    prims := make([dynamic]embree.RTCBuildPrimitive, 0, num_ents, alloc)
    entts := make([dynamic]Entity, 0, num_ents, alloc)
    pcmps := make([dynamic]^Cmp_Primitive, 0, num_ents, alloc)

    // Asemble!
    pid := 0
    for a in archetypes
    {
       prim_comps := get_table(a, Cmp_Primitive)
       for &pc, i in prim_comps
       {
            center := pc.world[3].xyz
            lower := center - pc.aabb_extents
            upper := center + pc.aabb_extents
            build_prim := embree.RTCBuildPrimitive{
                lower_x = lower.x,
                lower_y = lower.y,
                lower_z = lower.z,
                geomID = 0,
                upper_x = upper.x,
                upper_y = upper.y,
                upper_z = upper.z,
                primID = u32(pid)
            }
            append(&pcmps, &pc)
            append(&entts, a.entities[i])
            append(&prims, build_prim)
            pid += 1
       }
    }

    // Set up build arguments
    MIN_LEAF_SIZE :: 1
    MAX_LEAF_SIZE :: 1

    arguments := embree.RTCBuildArguments{
        byteSize = size_of(embree.RTCBuildArguments),
        buildQuality = .MEDIUM,
        buildFlags = .DYNAMIC,
        maxBranchingFactor = 2,
        maxDepth = 1024,
        sahBlockSize = 1,
        minLeafSize = MIN_LEAF_SIZE,
        maxLeafSize = MAX_LEAF_SIZE,
        traversalCost = 1.0,
        intersectionCost = 1.0,
        bvh = system.bvh,
        primitives = raw_data(prims),
        primitiveCount = c.size_t(len(prims)),
        primitiveArrayCapacity = c.size_t(cap(prims)),
        createNode = create_inner,
        setNodeChildren = set_children,
        setNodeBounds = set_bounds,
        createLeaf = create_leaf,
        splitPrimitive = split_primitive,
        buildProgress = nil,
        userPtr = nil,
    }

    // Build the BVH
    root_raw := embree.rtcBuildBVH(&arguments)
    system.root = root_raw
    system.num_nodes = g_num_nodes

    update_bvh(&prims, entts, root, num_nodes)
}

//----------------------------------------------------------------------------\\
// /SERIALIZE /SZ
//----------------------------------------------------------------------------\\

// Save a node hierarchy to scene.Node struct (for JSON marshalling)
save_node :: proc(entity: Entity) -> scene.Node {
    cmp_node := get_component(entity, Cmp_Node)
    if cmp_node == nil {
        return scene.Node{}
    }

    scene_node := scene.Node {
        Name        = strings.clone(cmp_node.name),
        hasChildren = cmp_node.is_parent,
        eFlags      = transmute(u32)cmp_node.engine_flags,
        gFlags      = cmp_node.game_flags,
        Dynamic     = cmp_node.is_dynamic,
    }

    // Save transform if present
    if .TRANSFORM in cmp_node.engine_flags {
        trans := get_component(entity, Cmp_Transform)
        if trans != nil {
            scene_node.Transform = scene.Transform {
                Position = {x = trans.local.pos.x, y = trans.local.pos.y, z = trans.local.pos.z},
                Rotation = {
                    i = trans.euler_rotation.x,
                    j = trans.euler_rotation.y,
                    k = trans.euler_rotation.z,
                },
                Scale = {x = trans.local.sca.x, y = trans.local.sca.y, z = trans.local.sca.z},
            }
        }
    }

    // Save data based on flags
    if .LIGHT in cmp_node.engine_flags {
        light := get_component(entity, Cmp_Light)
        if light != nil {
            scene_node.color = scene.Color {
                r = light.color.r,
                g = light.color.g,
                b = light.color.b,
            }
            scene_node.intensity = scene.Intensity {
                i = light.intensity,
            }
            scene_node.id = scene.ID {
                id = light.id,
            }
        }
    } else if .CAMERA in cmp_node.engine_flags {
        cam := get_component(entity, Cmp_Camera)
        if cam != nil {
            scene_node.aspect_ratio = scene.AspectRatio {
                ratio = cam.aspect_ratio,
            }
            scene_node.fov = scene.FOV {
                fov = cam.fov,
            }
        }
    } else if .PRIMITIVE in cmp_node.engine_flags || .MODEL in cmp_node.engine_flags {
        // Material
        mat := get_component(entity, Cmp_Material)
        if mat != nil {
            scene_node.material = scene.Material {
                ID = mat.mat_unique_id,
            }
        }

        // Primitive/Object ID
        prim := get_component(entity, Cmp_Primitive)
        if prim != nil {
            scene_node.object = scene.ObjectID {
                ID = prim.id,
            }
        } else {
            // For model, perhaps use model ID
            model := get_component(entity, Cmp_Model)
            if model != nil {
                scene_node.object = scene.ObjectID {
                    ID = model.model_unique_id,
                }
            }
        }

        // Rigid
        if .RIGIDBODY in cmp_node.engine_flags {
            scene_node.rigid = scene.Rigid {
                Rigid = true,
            }
        }

        // Collider
        if .COLIDER in cmp_node.engine_flags {
            // Assuming collider component exists, e.g. Cmp_Collider
            // coll := get_component(entity, Cmp_Collider)
            // if coll != nil {
            //     scene_node.collider = scene.Collider{
            //         Local = {x = coll.local.x, y = coll.local.y, z = coll.local.z},
            //         Extents = {x = coll.extents.x, y = coll.extents.y, z = coll.extents.z},
            //         Type = i32(coll.type),
            //     }
            // }
        }
    }

    // Recurse for children
    if cmp_node.is_parent {
        // Count children first
        child_count := 0
        curr_child := cmp_node.child
        for curr_child != Entity(0) {
            child_count += 1
            child_node := get_component(curr_child, Cmp_Node)
            if child_node != nil {
                curr_child = child_node.brotha
            } else {
                break
            }
        }

        scene_node.Children = make([dynamic]scene.Node, child_count)
        curr_child = cmp_node.child
        i := 0
        for curr_child != Entity(0) && i < child_count {
            scene_node.Children[i] = save_node(curr_child)
            i += 1
            child_node := get_component(curr_child, Cmp_Node)
            if child_node != nil {
                curr_child = child_node.brotha
            } else {
                break
            }
        }
    }

    return scene_node
}

// Save entire scene from head node
save_scene :: proc(head_entity: Entity, scene_num: i32) -> scene.SceneData {
    scene_data := scene.SceneData {
        Scene = scene.Scene{Num = scene_num},

    }
    scene_data.Node[0] = save_node(head_entity)

    // If multiple roots, append more
    // But assuming single head for now

    return scene_data
}

//----------------------------------------------------------------------------\\
// /LOAD
//----------------------------------------------------------------------------\\
load_node_components :: proc(scene_node: scene.Node, entity: Entity, e_flags :^ComponentFlags ){
    if .TRANSFORM in e_flags {
        pos := linalg.Vector3f32 {
            scene_node.Transform.Position.x,
            scene_node.Transform.Position.y,
            scene_node.Transform.Position.z,
        }
        rot := linalg.Vector4f32 {
            scene_node.Transform.Rotation.i,
            scene_node.Transform.Rotation.j,
            scene_node.Transform.Rotation.k,
            scene_node.Transform.Rotation.w,

        }
        sca := linalg.Vector3f32 {
            scene_node.Transform.Scale.x,
            scene_node.Transform.Scale.y,
            scene_node.Transform.Scale.z,
        }
        trans_comp := cmp_transform_prs_q(pos, rot, sca)
            add_component(entity, trans_comp)
    } else {
        add_component(entity, Cmp_Transform{}) // Default
        e_flags^ += {.TRANSFORM}
    }

    // Handle type-specific components
    if .CAMERA in e_flags {
        cam_comp := camera_component(scene_node.aspect_ratio.ratio, scene_node.fov.fov)
        add_component(entity, cam_comp)
        add_component(entity, Cmp_Render{type = {.CAMERA}}) // Example, adjust as needed
        added_entity(entity)
    }
    if .LIGHT in e_flags {
        color := linalg.Vector3f32{scene_node.color.r, scene_node.color.g, scene_node.color.b}
        light_comp := light_component(color, scene_node.intensity.i, scene_node.id.id)
        add_component(entity, light_comp)
        add_component(entity, Cmp_Render{type = {.LIGHT}})
        added_entity(entity)
    }
    if .PRIMITIVE in e_flags {
        // Material
        mat_id := scene_node.material.ID
        mat_uid := get_material_index(mat_id)
        mat_comp := material_component(i32(mat_id), mat_uid)
        add_component(entity, mat_comp)
        // Object/Primitive
        obj_id := scene_node.object.ID
        prim_comp := primitive_component(i32(obj_id))

        add_component(entity, Cmp_Primitive{
                world = linalg.MATRIX4F32_IDENTITY,
                id = i32(obj_id)})
        add_component(entity, Cmp_Render{type = {.PRIMITIVE}})
        added_entity(entity)

        // Rigid
        if scene_node.rigid.Rigid {
            e_flags^ += {.RIGIDBODY}
            // Add physics components if needed
        }

        // Collider
        if scene_node.collider.Type != 0 {  // Assuming presence indicates collider
            coll_type := scene_node.collider.Type
            local := linalg.Vector3f32 {
                scene_node.collider.Local.x,
                scene_node.collider.Local.y,
                scene_node.collider.Local.z,
            }
            extents := linalg.Vector3f32 {
                scene_node.collider.Extents.x,
                scene_node.collider.Extents.y,
                scene_node.collider.Extents.z,
            }
            // Add Cmp_Collider if defined, e.g. add_component(entity, Cmp_Collider{local=local, extents=extents, type=coll_type})
            e_flags^ += {.COLIDER}
        }
    }

    // Handle other flags/components as in C++
    // e.g. Prefab, GUI, etc. - add similar logic if components are defined

    // If root
    if .ROOT in e_flags {
        add_component(entity, Cmp_Root{})
    }
}
// Load a scene.Node into ECS Cmp_Node hierarchy
load_node :: proc(scene_node: scene.Node, parent: Entity = Entity(0)) -> Entity {
    entity := add_entity()
    e_flags := transmute(ComponentFlags)scene_node.eFlags
    load_node_components(scene_node, entity, &e_flags)

    // Now add Cmp_Node with final flags
    cmp_node_local := Cmp_Node {
        entity       = entity,
        parent       = parent,  // Set parent Entity ID here
        child        = Entity(0),  // Will be set when loading children
        brotha       = Entity(0),  // Will be set by parent when adding as child
        name         = strings.clone(scene_node.Name, context.temp_allocator),
        is_dynamic   = scene_node.Dynamic,
        is_parent    = scene_node.hasChildren,
        engine_flags = e_flags,
        game_flags   = scene_node.gFlags,
    }
    add_component(entity, cmp_node_local)

    cmp_node := get_component(entity, Cmp_Node)
    if cmp_node == nil {
        fmt.println("[load_node] ERROR: missing Cmp_Node after add")
        return Entity(0)
    }

    // Set is_parent for camera and light as in original
    if .CAMERA in cmp_node.engine_flags { cmp_node.is_parent = true }
    if .LIGHT in cmp_node.engine_flags { cmp_node.is_parent = true }

    // Recurse for children and link via Entity IDs
    if scene_node.hasChildren {
        for &child_scene in scene_node.Children {
            child_entity := load_node(child_scene, entity)  // Pass parent entity
            if child_entity != Entity(0) {
                add_child(entity, child_entity)
                // Optionally: Get child_node and set its parent if not already (but it's set in cmp_node_local above)
            }
        }
    }

    // If this is a root (no parent), append to g_scene
    // if parent == Entity(0) && .ROOT in cmp_node.engine_flags {
    //     append(&g_scene, entity)
    // }
    return entity
}

// Load entire scene
load_scene :: proc(scene_data: scene.SceneData, alloc: mem.Allocator) {
	if len(scene_data.Node) == 0 {
		return // Entity(0)
	}
	for node in scene_data.Node {
		load_node(node)
	}
}

load_prefab :: proc(name: string) -> (prefab : Entity)
{
    node, ok := g_prefabs[name]
    if !ok{
        fmt.printf("[load_prefab] Prefab '%s' not found in g_prefabs map \n", name)
        return 0
    }
    // Create the entity using the requested ECS allocator
    prefab = load_node(node)
    nc := get_component(prefab,Cmp_Node)
    children := get_children(nc.entity)
    for n in children{
        cc := get_component(n, Cmp_Node)
        cc.parent = prefab
    }
    //append(&g_scene, prefab)
    return prefab
}

//----------------------------------------------------------------------------\\
// /Physics System /ps
//----------------------------------------------------------------------------\\
MAX_DYANMIC_OBJECTS :: 1000
g_world_def := b2.DefaultWorldDef()
g_world_id : b2.WorldId
g_b2scale := f32(1)

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

setup_physics :: proc (){
    fmt.println("Setting up phsyics")
    b2.SetLengthUnitsPerMeter(g_b2scale)
    g_world_id = b2.CreateWorld(g_world_def)
    b2.World_SetGravity(g_world_id, b2.Vec2{0,-9.8})
    //Set Player's body def
    {
        find_player_entity()
        ///////////////////////////////////
        // /plr
        ///////////////////////////////////
        pt := get_component(g_player, Cmp_Transform)
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
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

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
        add_component(g_player, col)
        //add_component(g_player, capsule)
    }

    fmt.println("Floor created")
    set_floor_entities()
    // create_barrel({3, 2})
    // create_barrel({1, 2})
    // create_barrel({2, 2})
    // create_barrel({4, 2})
    // create_barrel({5, 2})
    // create_barrel({6, 2})
    // create_barrel({7, 2})
    // create_barrel({8, 2})
    // create_barrel({9, 2})
    // create_barrel({10, 2})
    // create_barrel({15, 2})
    // create_barrel({11, 2})
    // create_barrel({12, 2})
    // create_barrel({13, 2})
    // create_barrel({14.5, 2})
    // create_barrel({4, 2})
    // create_debug_quad({2,2,1}, {0,0,0,0}, {1,1,.1})
    //create_debug_cube_with_col({2,2}, {10,10})
    //
    create_debug_cube_with_col({25,2}, {2,2})
   }

set_floor_entities :: proc()
{
    // /flr
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
        col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
        box := b2.MakeBox(500, 1.0)

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Player, .MovingEnvironment, .MovingFloor, .Environment, .Enemy})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = 10000
        col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    }

    find_floor_entities()
    fc := get_component(g_floor, Cmp_Transform)
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
    col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
    box := b2.MakeBox(fc.local.sca.x, fc.local.sca.y)

    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingFloor})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Environment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = 1000.0
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    add_component(g_floor, col)
}

barrel : Entity
create_barrel :: proc(pos : b2.Vec2)
{
    fmt.println("Barrel creating")
    barrel = load_prefab("Barrel")
    fmt.println("Prefab loaded")
    bt := get_component(barrel, Cmp_Transform)
    if bt == nil do return

    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Box,
        flags = CollisionFlags{.Movable}
    }
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    // Body position must be scaled to Box2D units
    col.bodydef.position = b2.Vec2{ pos.x * g_b2scale, pos.y * g_b2scale }
    col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

    // Scale shape extents to Box2D units (bt.local.sca holds half-extents in our transform)
    box := b2.MakeBox(bt.local.sca.x * g_b2scale, bt.local.sca.y * 2 * g_b2scale)
    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingEnvironment})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player, .Environment, .MovingEnvironment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = g_contact_identifier.Player
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    // movable := Cmp_Movable{-1.0}

    fmt.println("Movable component added")
    add_component(barrel, col)
    fmt.println("Collision component added")
    //add_component(barrel, movable)
}

update_movables :: proc(delta_time: f32)
{
    //First just the visible g_floor
    for i in 0..<2{
        fc := get_component(g_floor, Cmp_Transform)
        fc.local.pos.x -= 1.0 * delta_time

        //refresh world if done
        if fc.local.pos.x <= -100.0 {
            fmt.println("Floor  ", i, "  | Trans: ", fc.local.pos.xy)
            for e in g_objects[curr_phase] do remove_entity(e)
            vmem.arena_free_all(&distance_arena[curr_phase])
            curr_phase = (curr_phase + 1) % 2

            col := get_component(g_floor, Cmp_Collision2D)
            fc.local.pos.x += 200.0
            trans := b2.Body_GetTransform(col.bodyid)
            trans.p.x = fc.local.pos.x
            b2.Body_SetTransform(col.bodyid, trans.p, trans.q)
        }
    }
    movables := query(has(Cmp_Collision2D))
    for movable in movables{
        cols := get_table(movable, Cmp_Collision2D)
        for e, i in movable.entities{
            if .Movable in cols[i].flags{
                nc := get_component(e, Cmp_Node)
                tc := get_component(e, Cmp_Transform)
                // fmt.println("movable, ", nc.name)
                // b2.Body_SetLinearVelocity(cols[i].bodyid, {delta_time * -1.0, 0})
                // b2.Body_ApplyLinearImpulse(cols[i].bodyid, {-2.0,0}, {0.5,0.5}, true)
                vel := b2.Body_GetLinearVelocity(cols[i].bodyid)
                vel.x = -4
                b2.Body_SetLinearVelocity(cols[i].bodyid, vel)
                // b2.Body_ApplyForceToCenter(cols[i].bodyid, {0,1000.0}, true)
                //fmt.printfln("Entity")
                // fmt.println("Entity: ",nc.name, " | Position : ", b2.Body_GetPosition(cols[i].bodyid), " | Trans: ", tc.local.pos.xy)
            }
        }
    }
}

update_physics :: proc(delta_time: f32)
{
    update_player_movement_phys(delta_time)
    b2.World_Step(g_world_id, delta_time, 4)
    arcs := query(has(Cmp_Transform), has(Cmp_Collision2D))
    for arc in arcs{
        trans := get_table(arc,Cmp_Transform)
        colis := get_table(arc,Cmp_Collision2D)
        for _, i in arc.entities{
            pos := b2.Body_GetPosition(colis[i].bodyid)
            if(.Floor not_in colis[i].flags) do trans[i].local.pos.xy = pos
            else{
                trans[i].local.pos.x = pos.x
            }
            trans[i].local.pos.z = 1
        }
    }
}

update_player_movement_phys :: proc(delta_time: f32)
{
    cc := get_component(g_player, Cmp_Collision2D)
    if cc == nil do return
    vel := b2.Body_GetLinearVelocity(cc.bodyid).y
    move_speed :f32= 0.40
    if is_key_pressed(glfw.KEY_SPACE) do vel += move_speed
    b2.Body_SetLinearVelocity(cc.bodyid, {0,vel})
    // b2.Body_ApplyForceToCenter(cc.bodyid, {0,100}, true)
    // fmt.println("Entity ",g_player, " | Force : ", b2.Body_GetLinearVelocity(cc.bodyid), " | ")
    // fmt.println("Entity ",g_player, " | Position : ", b2.Body_GetPosition(cc.bodyid), " | ")
}

///////////////////////////////
// /debug lines
// ///////////////////////////
create_debug_quad :: proc(pos: b2.Vec2, extents: b2.Vec2, mat_unique_id: i32 = 1125783744) -> Entity {
    e := create_node_entity("debug_quad", ComponentFlag.PRIMITIVE)
    pos3 := vec3{ pos.x, pos.y, 0.0 }
    half_ext := vec3{ extents.x * 0.5, extents.y * 0.5, 0.1 }
    rot_q := vec4{ 0.0, 0.0, 0.0, 1.0 } // identity rotation
    add_component(e, cmp_transform_prs_q(pos3, rot_q, half_ext))
    add_component(e, material_component(i32(mat_unique_id)))
    add_component(e, primitive_component_with_id(-6))
    add_component(e, Cmp_Render{ type = {.PRIMITIVE} })
    add_component(e, Cmp_Root{})
    add_component(e, Cmp_Node{engine_flags = {.ROOT}})
    added_entity(e)
    return e
}

create_debug_cube :: proc(pos: b2.Vec2, extents: b2.Vec2, mat_unique_id: i32 = 1125783744) -> Entity {
    e := create_node_entity("debug_cube", ComponentFlag.PRIMITIVE)
    pos3 := vec3{ pos.x, pos.y, 1.0 }
    rot_q := vec4{ 0.0, 0.0, 0.0, 1.0 } // identity rotation
    add_component(e, cmp_transform_prs_q(pos3, rot_q, {extents.x, extents.y, .1}))
    add_component(e, material_component(i32(mat_unique_id)))
    add_component(e, primitive_component_with_id(-2))
    add_component(e, Cmp_Render{ type = {.PRIMITIVE} })
    add_component(e, Cmp_Root{})
    added_entity(e)
    return e
}

// Create a debug cube (visual) and also attach collision similar to create_barrel.
// pos and extents are in world units; collision is created in Box2D space using g_b2scale.
create_debug_cube_with_col :: proc(pos: b2.Vec2, extents: b2.Vec2, mat_unique_id: i32 = 1125783744) -> Entity {
    // create visual cube first
    e := create_debug_cube(pos, extents, mat_unique_id)

    // get transform (visual) to base collision on
    bt := get_component(e, Cmp_Transform)
    if bt == nil do return e

    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Box,
        flags = CollisionFlags{.Movable}
    }
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    // convert world position to Box2D space
    col.bodydef.position = b2.Vec2{ pos.x * g_b2scale, pos.y * g_b2scale }
    col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

    // extents parameter is full size; Box2D MakeBox expects half-extents, in Box2D units
    half := b2.Vec2{ (extents.x) * g_b2scale, (extents.y) * g_b2scale }
    box := b2.MakeBox(half.x, half.y)

    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingEnvironment})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player, .Environment, .MovingFloor})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = g_contact_identifier.Wall
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    add_component(e, col)
    return e
}

//----------------------------------------------------------------------------\\
// /Animation System
//----------------------------------------------------------------------------\\
