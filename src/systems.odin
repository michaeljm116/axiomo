package game
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:container/queue"
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


sys_trans_process_ecs :: proc() {
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
            g_raytracer.lights[0] = gpu.Light{
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
        tc.global.sca = tc.local.sca * pt.global.sca
        tc.global.rot = tc.local.rot * pt.global.rot
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
            obj_comp.aabb_extents = rotate_aabb(linalg.matrix3_from_matrix4_f32(tc.world))
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
            g_raytracer.lights[0] = gpu.Light{
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
    system := new(Sys_Bvh, alloc)
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
    // free(system)
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
sys_bvh_process_ecs :: proc(using system: ^Sys_Bvh, alloc : mem.Allocator) {
    context.allocator = alloc
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
        Name        = strings.clone(cmp_node.name, context.temp_allocator),
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

        scene_node.Children = make([dynamic]scene.Node, child_count, context.temp_allocator)
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
load_node :: proc(scene_node: scene.Node, parent: Entity = Entity(0), alloc := context.temp_allocator) -> Entity {
    entity := add_entity()
    e_flags := transmute(ComponentFlags)scene_node.eFlags
    load_node_components(scene_node, entity, &e_flags)

    // Now add Cmp_Node with final flags
    cmp_node_local := Cmp_Node {
        entity       = entity,
        parent       = parent,  // Set parent Entity ID here
        child        = Entity(0),  // Will be set when loading children
        brotha       = Entity(0),  // Will be set by parent when adding as child
        name         = strings.clone(scene_node.Name, alloc),
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
            child_entity := load_node(child_scene, entity, alloc)  // Pass parent entity
            if child_entity != Entity(0) {
                add_child(entity, child_entity)
                // Optionally: Get child_node and set its parent if not already (but it's set in cmp_node_local above)
            }
        }
    }

    // If this is a root (no parent), append to g.scene
    // if parent == Entity(0) && .ROOT in cmp_node.engine_flags {
    //     append(&g.scene, entity)
    // }
    return entity
}

// Load entire scene
load_scene :: proc(scene_data: scene.SceneData, alloc: mem.Allocator) {
	assert(len(scene_data.Node) != 0)
	for node in scene_data.Node {
		load_node(node, alloc = alloc)
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
    //append(&g.scene, prefab)
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
        add_component(g.player, col)
        //add_component(g.player, capsule)
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
    col.bodyid = b2.CreateBody(g_world_id, col.bodydef)
    box := b2.MakeBox(fc.local.sca.x, fc.local.sca.y)

    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingFloor})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Environment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = 1000.0
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    add_component(g.floor, col)
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
    cc := get_component(g.player, Cmp_Collision2D)
    if cc == nil do return
    vel := b2.Body_GetLinearVelocity(cc.bodyid).y
    move_speed :f32= 0.40
    if is_key_pressed(glfw.KEY_SPACE) do vel += move_speed
    b2.Body_SetLinearVelocity(cc.bodyid, {0,vel})
    // b2.Body_ApplyForceToCenter(cc.bodyid, {0,100}, true)
    // fmt.println("Entity ",g.player, " | Force : ", b2.Body_GetLinearVelocity(cc.bodyid), " | ")
    // fmt.println("Entity ",g.player, " | Position : ", b2.Body_GetPosition(cc.bodyid), " | ")
}

//----------------------------------------------------------------------------\\
// /debug lines
//----------------------------------------------------------------------------\\
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
sys_anim_process_ecs :: proc(dt : f32)
{
    archetypes := query(ecs.has(Cmp_Animation), ecs.has(Cmp_BFGraph))
    for archetype in archetypes {
        for entity in archetype.entities do sys_anim_update(entity, dt)
    }

   animate_archetypes := query(ecs.has(Cmp_Animate), ecs.has(Cmp_Transform))
   for anim in animate_archetypes {
       anims := get_table(anim, Cmp_Animate)
       trans := get_table(anim, Cmp_Transform)
       for entity, i in anim.entities do sys_anim_process(entity, &anims[i], &trans[i], dt)
   }
}

sys_anim_add :: proc(e : Entity){
    ac := get_component(e, Cmp_Animation)
    bfg := get_component(e, Cmp_BFGraph)
    // node := get_component(e, Cmp_Node)
    assert(ac != nil && bfg != nil, "Animation, BFGraph, and Node components are required")
    animation := g_animations[ac.prefab_name]
    end_pose := animation.poses[ac.end]

    // If there's only 1 pose, then it'll only be the end pose
    // The start will just be where you're currently at
    if ac.num_poses <= 1 {
        for pose in end_pose.pose {
            a := Cmp_Animate{
                flags = ac.flags,
                time = ac.time,
                end = map_sqt(pose.sqt_data),
                parent_entity = e,}
            curr_node := bfg.nodes[pose.id]
            a.start = get_component(curr_node, Cmp_Transform).local
            add_animate_component(curr_node, a)
        }
    }
    else{
        // This needs to be done a little differently since lets say...
    	// Start = 1,5,7, End = 2,5,7. You want Children 1,2,5,7 to be called once
    	// But you also want 1 5 7 to be 1st 5se 7se
    	// And you also want 2 5 7 to be 2te 5se 7se
    	// t = original transform, s = start e = end
       comps := make(map[i32]Cmp_Animate, 0, context.temp_allocator)
       start_pose := animation.poses[ac.start]
       // All starts just instanly go inside the map
       for pose in start_pose.pose{
           a := Cmp_Animate{
               flags = ac.flags,
               time = ac.time,
               start = map_sqt(pose.sqt_data),
               parent_entity = e}
           a.flags.start_set = true
           comps[pose.id] = a
       }
       // For the end, first make sure there's no duplicates, then insert
       for pose in end_pose.pose{
          a,ok := comps[pose.id]
          if(ok){
              a.end = map_sqt(pose.sqt_data)
              a.flags.end_set = true
          }
          else{
            a = Cmp_Animate{
                flags = ac.flags,
                time = ac.time,
                end = map_sqt(pose.sqt_data),
                parent_entity = e}
            a.flags.end_set = true
            comps[pose.id] = a
          }
       }
       // Now dispatch the components
       for key, &a in comps{
           bfg_ent := bfg.nodes[key]
           bfg_sqt := get_component(bfg_ent, Cmp_Transform).local

           if !a.flags.start_set do a.start = bfg_sqt
           if !a.flags.end_set do a.end = bfg_sqt

           add_animate_component(bfg_ent, a)
       }
    }
}
// This keeps track of the transitions
// Default state = you are free to animate
// End State = a single-frame trigger
// Transition takes the start and end from previous pose and transitions to the new pose
// Start performs the animation
// TransitionToStart/End times the animations
sys_anim_update :: proc(entity: Entity, delta_time: f32)
{
    ac := get_component(entity, Cmp_Animation)
    //display_animation_state(e, ac->state);
    //display_animation_names(ac);

    switch ac.state {
    case .DEFAULT:
        break
    case .TRANSITION:
        if ac.trans != 0 do sys_anim_transition(entity)
        ac.state = .TRANSITION_TO_START
    case .TRANSITION_TO_START:
        ac.trans_timer += delta_time
        if ac.trans_timer > ac.trans_time do ac.state = .START
    case .START:
        ac.start = ac.trans
        ac.end = ac.trans_end
        ac.trans_timer = 0.0
        ac.state = .TRANSITION_TO_END
        sys_anim_add(entity)
    case .TRANSITION_TO_END:
        ac.trans_timer += delta_time
        if ac.trans_timer > ac.time do ac.state = .END
    case .END:
        ac.state = .DEFAULT
    }
}

sys_anim_process :: proc(entity: Entity, ac : ^Cmp_Animate, tc : ^Cmp_Transform, dt : f32)
{
    //Increment time
    if ac.flags.active == 0 do return
    x := math.clamp(dt / ac.time, 0.0, 1.0)
    ac.curr_time += dt

    //Interpolate dat ish
    if !ac.flags.pos_flag do tc.local.pos = linalg.mix(tc.local.pos, ac.end.pos, x)
    if !ac.flags.sca_flag do tc.local.sca = linalg.mix(tc.local.sca, ac.end.sca, x)
    if !ac.flags.rot_flag do tc.local.rot = linalg.quaternion_slerp_f32(tc.local.rot, ac.end.rot, x)

    //End Animation if finished
    if ac.curr_time >= ac.time {
        ac.curr_time = 0.0
        if ac.flags.force_end {
            tc.local = ac.end
            ac.flags.force_end = false
        }
        if ac.flags.loop {
            temp := ac.start
            ac.start = ac.end
            ac.end = temp
        } else do remove_component(entity, Cmp_Animate)
    }
}

CombinedEntry :: struct {
    start: Sqt,
    end:   Sqt,
    flags: AnimFlags,
}
//On Transition,
// - unused parts go back to normal, and
// - similar parts transition
// - New parts go to the new pose
sys_anim_transition :: proc(entity: Entity)
{
    ac := get_component(entity, Cmp_Animation)
    bfg := get_component(entity, Cmp_BFGraph)
    assert(ac != nil && bfg != nil, "Animation and BFGraph components are required")

    animation := g_animations[ac.prefab_name]
    start_pose := animation.poses[ac.start]
    end_pose   := animation.poses[ac.end]
    trans_pose := animation.poses[ac.trans]

    //First place every Previous Pose in a hashset
    prev_pose := make(map[i32]bool, 0, context.temp_allocator)
    for p in start_pose.pose do prev_pose[p.id] = true
    for p in end_pose.pose do prev_pose[p.id] = true

    //Create a list that combines everything
    combined := make(map[i32]CombinedEntry, 0, context.temp_allocator)

    //Go through the previous pose, Start = It's Transform, End = It's Original Transform
    for id in prev_pose {
        trans_comp := get_component(bfg.nodes[id], Cmp_Transform)
        start_sqt := trans_comp.local
        end_sqt := bfg.transforms[id]
        combined[id] = CombinedEntry{
            start = start_sqt,
            end = end_sqt,
            flags = AnimFlags{ active = 1, loop = false, force_start = true, force_end = false },
        }
    }

    //Go through the transitional pose, End = the transitional pose,
    //Start = original transform if its not in list, or prevpose start if in the list
    for p in trans_pose.pose {
        entry, ok := combined[p.id]
        if !ok {
            combined[p.id] = CombinedEntry{
                start = bfg.transforms[p.id],
                end = map_sqt(p.sqt_data),
                flags = AnimFlags{ active = 1, loop = false, force_start = true, force_end = true },
            }
        } else {
            entry.end = map_sqt(p.sqt_data)
            combined[p.id] = entry
        }
    }

    //Iterate through the list and dispatch animate components
    for id, &entry in combined {
        a := Cmp_Animate{
            flags = entry.flags,
            time = ac.time,
            start = entry.start,
            end = entry.end,
            parent_entity = entity,
        }
        a.flags.end_set = true
        add_animate_component(bfg.nodes[id], a)
    }

    //Turn off transition;
    ac.trans_timer = 0.0001
}

//Onadd you can choose to reset the animation to the start
//Or just interpolate from where you're already at
add_animate_component :: proc(ent: Entity, comp: Cmp_Animate)
{
    if(has_component(ent, Cmp_Animate)){
        ac := get_component(ent, Cmp_Animate)
        ac^ = comp
        ac.flags.active = 1
        tc := get_component(ent, Cmp_Transform)
        if ac == nil || tc == nil do return

        //This forces the animation to go to the start position
        if ac.flags.force_start do tc.local = ac.start
        check_if_finished(tc.local, ac)
    }
    else {
        add_component(ent, comp)
        ac := get_component(ent, Cmp_Animate)
        tc := get_component(ent, Cmp_Transform)
        if ac == nil || tc == nil do return
        //This forces the animation to go to the start position
        if ac.flags.force_start do tc.local = ac.start
        check_if_finished(tc.local, ac)
        ac.flags.active = 1
    }
}

deactivate_animate_component :: proc(e : Entity)
{
    ac := get_component(e, Cmp_Animate)
    assert(ac != nil)
    ac.flags.active = 0
    if ac.flags.force_end == true{
        tc := get_component(e, Cmp_Transform)
        tc.local = ac.end
    }
    remove_component(e, Cmp_Animate)
}

sys_anim_deactivate_component :: proc(entity : Entity)
{
    ac := get_component(entity, Cmp_Animation)
    bfg := get_component(entity, Cmp_BFGraph)
    assert(ac != nil && bfg != nil, "Animation and BFGraph components are required")

    animation := g_animations[ac.prefab_name]
    end_pose := animation.poses[ac.end]

    //First remove the endpose
    removed := make(map[i32]bool, 0, context.temp_allocator)
    for pose in end_pose.pose {
        bfg_ent := bfg.nodes[pose.id]
        deactivate_animate_component(bfg_ent)
        removed[pose.id] = true
    }

    // If there's a start pose, remove animate components for nodes that overlap with end pose
    if ac.num_poses > 1 {
        start_pose := animation.poses[ac.start]
        for pose in start_pose.pose {
            _, ok := removed[pose.id]
            if ok do deactivate_animate_component(bfg.nodes[pose.id])
        }
    }
    ac.flags.active = 0
    // remove_component(entity, Cmp_Animation)
}

check_if_finished :: proc(curr: Sqt, ac: ^Cmp_Animate) -> bool {
    ep: f32 = 0.01

    p_x := math.abs(curr.pos.x - ac.end.pos.x) < ep
    p_y := math.abs(curr.pos.y - ac.end.pos.y) < ep
    p_z := math.abs(curr.pos.z - ac.end.pos.z) < ep

    r_x := math.abs(curr.rot.x - ac.end.rot.x) < ep
    r_y := math.abs(curr.rot.y - ac.end.rot.y) < ep
    r_z := math.abs(curr.rot.z - ac.end.rot.z) < ep

    s_x := math.abs(curr.sca.x - ac.end.sca.x) < ep
    s_y := math.abs(curr.sca.y - ac.end.sca.y) < ep
    s_z := math.abs(curr.sca.z - ac.end.sca.z) < ep

    ac.flags.pos_flag = p_x && p_y && p_z
    ac.flags.rot_flag = r_x && r_y && r_z
    ac.flags.sca_flag = s_x && s_y && s_z

    anim_finished := u8(ac.flags.pos_flag) | (u8(ac.flags.rot_flag) << 1) | (u8(ac.flags.sca_flag) << 2)

    return anim_finished == 7
}

//----------------------------------------------------------------------------\\
// /AI A-Star Pathfinding
//----------------------------------------------------------------------------\\
pos_equal :: proc(a : vec2, b : vec2) -> bool {
    return a[0] == b[0] && a[1] == b[1]
}

pos_to_index :: proc(p : vec2) -> int {
    return int(p[0]) + int(p[1]) * GRID_WIDTH
}

index_to_pos :: proc(i : int) -> vec2 {
    return vec2{ i16(i % GRID_WIDTH), i16(i / GRID_WIDTH) }
}

in_bounds :: proc(p : vec2) -> bool {
    if p[0] < 0 || p[0] >= i16(GRID_WIDTH) || p[1] < 0 || p[1] >= i16(GRID_HEIGHT) {
        return false
    }
    return true
}

is_walkable :: proc(p : vec2, goal : vec2) -> bool {
    if pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !in_bounds(p) { return false }
    t := g.level.grid[p[0]][p[1]]
    return t == Tile.Blank || t == Tile.Weapon
}

abs_i :: proc(x : int) -> int {
    if x < 0 { return -x }
    return x
}

dist_grid :: proc(a : vec2, b : vec2) -> int {
    dx := abs_i(int(a[0]) - int(b[0]))
    dy := abs_i(int(a[1]) - int(b[1]))
    return dx + dy
}

heuristic :: proc(a : vec2, b : vec2) -> int {
    //Manhattan distance
    return dist_grid(a,b)
}

// Returns path from start to goal as dynamic array of vec2 (start .. goal).
// If no path found, returned array length == 0
total_cells :: GRID_WIDTH * GRID_HEIGHT
a_star_find_path :: proc(start : vec2, goal : vec2) -> [dynamic]vec2 {
    // Static arrays sized for grid
    g_score : [total_cells]int
    f_score : [total_cells]int
    came_from : [total_cells]vec2
    in_open : [total_cells]bool
    closed : [total_cells]bool

    // init
    for i in 0..<total_cells{
        g_score[i] = 999999
        f_score[i] = 999999
        came_from[i] = vec2{-1, -1}
        in_open[i] = false
        closed[i] = false
    }

    start_idx := pos_to_index(start)
    goal_idx := pos_to_index(goal)

    g_score[start_idx] = 0
    f_score[start_idx] = heuristic(start, goal)
    in_open[start_idx] = true

    dirs := [4]vec2{ vec2{1,0}, vec2{-1,0}, vec2{0,1}, vec2{0,-1} }

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
            path := make([dynamic]vec2, context.temp_allocator)
            return path
        }

        current_pos := index_to_pos(current_idx)

        if current_idx == goal_idx {
            // reconstruct path
            path := make([dynamic]vec2, context.temp_allocator)
            // backtrack
            node_idx := current_idx
            for {
                append(&path, index_to_pos(node_idx))
                if node_idx == start_idx { break }
                parent := came_from[node_idx]
                // if no parent, fail
                if parent[0] == -1 && parent[1] == -1 {
                    // failed reconstruction
                    path = make([dynamic]vec2, context.temp_allocator)
                    return path
                }
                node_idx = pos_to_index(parent)
            }
            // path currently goal..start, reverse to start..goal
            rev := make([dynamic]vec2, context.temp_allocator)
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
            neighbor := vec2{ current_pos[0] + dir[0], current_pos[1] + dir[1] }
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

is_walkable_internal :: proc(p : vec2, goal : vec2, allow_through_walls : bool) -> bool {
    if pos_equal(p, goal) { return true } // always allow stepping on the goal
    if !in_bounds(p) { return false }
    t := g.level.grid[p[0]][p[1]]
    if t == Tile.Blank || t == Tile.Weapon { return true }
    if allow_through_walls && t == Tile.Wall { return true }
    return false
}

//----------------------------------------------------------------------------\\
// /UI
//----------------------------------------------------------------------------\\
add_ui :: proc (gui : Cmp_Gui, name : string) -> Entity
{
    e := add_entity()
    add_component(e, gui)
    add_component(e, Cmp_Render{type = {.GUI}})
    add_component(e, Cmp_Node{name = name, engine_flags = {.GUI}})
    added_entity(e)
    return e
}
