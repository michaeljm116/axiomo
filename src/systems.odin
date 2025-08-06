package main
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:slice"
import ecs "external/ecs"
import embree "external/embree"

import "gpu"
import math "core:math"
import linalg "core:math/linalg"


import "core:strings"
import res "resource"
import scene "resource/scene"


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

transform_print_hierarchy :: proc() {
    fmt.println("=== Transform Hierarchy ===")

    // Find all root entities (entities with Cmp_Root)
    root_archetypes := query(ecs.has(Cmp_Transform), ecs.has(Cmp_Node), ecs.has(Cmp_Root))

    for archetype in root_archetypes {
        node_comps := get_table(archetype, Cmp_Node)
        transform_comps := get_table(archetype, Cmp_Transform)

        for i in 0..<len(node_comps) {
            node := &node_comps[i]
            transform := &transform_comps[i]

            // Print this root node and its hierarchy
            print_entity_hierarchy(node, transform, 0)
        }
    }

    fmt.println("=== End Hierarchy ===")
}

// Helper procedure to recursively print entity hierarchy
print_entity_hierarchy :: proc(node: ^Cmp_Node, transform: ^Cmp_Transform, depth: int) {
    // Create indentation based on depth
    indent := ""
    for i in 0..<depth {
        indent = fmt.aprintf("%s  ", indent)
    }
    defer delete(indent)

    // Print entity information
    entity_name := node.name if len(node.name) > 0 else fmt.aprintf("Entity_%d", node.entity)
    defer if len(node.name) == 0 do delete(entity_name)

    fmt.printf("%s├─ %s (ID: %d)\n", indent, entity_name, node.entity)
    fmt.printf("%s│  World Matrix:\n", indent)
    fmt.printf("%s│  [%.3f, %.3f, %.3f, %.3f]\n", indent,
               transform.world[0][0], transform.world[0][1], transform.world[0][2], transform.world[0][3])
    fmt.printf("%s│  [%.3f, %.3f, %.3f, %.3f]\n", indent,
               transform.world[1][0], transform.world[1][1], transform.world[1][2], transform.world[1][3])
    fmt.printf("%s│  [%.3f, %.3f, %.3f, %.3f]\n", indent,
               transform.world[2][0], transform.world[2][1], transform.world[2][2], transform.world[2][3])
    fmt.printf("%s│  [%.3f, %.3f, %.3f, %.3f]\n", indent,
               transform.world[3][0], transform.world[3][1], transform.world[3][2], transform.world[3][3])

    // Print children recursively
    for child_entity in node.children {
        child_node := get_component(child_entity, Cmp_Node)
        child_transform := get_component(child_entity, Cmp_Transform)

        if child_node != nil && child_transform != nil {
            print_entity_hierarchy(child_node, child_transform, depth + 1)
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


//----------------------------------------------------------------------------\\
// /BVH System /bs
//----------------------------------------------------------------------------\\

Sys_Bvh :: struct {
    // ECS world reference

    // Embree data
    device: embree.RTCDevice,
    bvh: embree.RTCBVH,

    // BVH tree data
    root: BvhNode,
    num_nodes: i32,

    // Entity and primitive data
    entities: [dynamic]Entity,
    primitive_components: [dynamic]^Cmp_Primitive,
    build_primitives: [dynamic]embree.RTCBuildPrimitive,

    // Rebuild flag
    rebuild: bool,
}

// Global counter for node creation (matches C++ static variable)
g_num_nodes: i32 = 0

// Create a new BVH system
bvh_system_create :: proc() -> ^Sys_Bvh {
    fmt.println("creating bvh")
    system := new(Sys_Bvh)
    system.entities = make([dynamic]Entity)
    system.primitive_components = make([dynamic]^Cmp_Primitive)
    system.build_primitives = make([dynamic]embree.RTCBuildPrimitive)
    system.rebuild = false

    // Initialize Embree
    system.device = embree.rtcNewDevice(nil)
    if system.device == nil {
        fmt.println("Error creating Embree device")
        free(system)
        return nil
    }

    system.bvh = embree.rtcNewBVH(system.device)

    // Set memory monitor (equivalent to C++ lambda)
    embree.rtcSetDeviceMemoryMonitorFunction(system.device,
        proc "c" (userPtr: rawptr, bytes: c.ssize_t, post: bool) -> bool {
            return true
        }, nil)
    fmt.println("bvh created")
    return system
}

// Destroy BVH system
bvh_system_destroy :: proc(using system: ^Sys_Bvh) {
    if system == nil do return

    bvh_destroy(root)
    embree.rtcReleaseBVH(bvh)
    embree.rtcReleaseDevice(device)

    delete(entities)
    delete(primitive_components)
    delete(build_primitives)

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

    //assert(numPrims >= MIN_LEAF_SIZE && numPrims <= MAX_LEAF_SIZE)
    // if !(numPrims >= MIN_LEAF_SIZE && numPrims <= MAX_LEAF_SIZE) {
    //     fmt.println("BVH Exceeded max leaf size. its: ", numPrims)
    //     return nil
    // }
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
bvh_system_build :: proc(using system: ^Sys_Bvh) {
    g_num_nodes = 0
    clear(&build_primitives)
    reserve(&build_primitives, len(primitive_components))

    // Create build primitives from primitive components

    for archetype in query(has(Cmp_Primitive)) {
        prim_comps := get_table(archetype, Cmp_Primitive)
        for prim_comp, i in prim_comps{
            center := prim_comp.world[3].xyz
            lower := center - prim_comp.aabb_extents
            upper := center + prim_comp.aabb_extents

            build_prim := embree.RTCBuildPrimitive{
                lower_x = lower.x,
                lower_y = lower.y,
                lower_z = lower.z,
                geomID = 0,
                upper_x = upper.x,
                upper_y = upper.y,
                upper_z = upper.z,
                primID = u32(i),
            }
            append(&build_primitives, build_prim)
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
        primitives = raw_data(system.build_primitives),
        primitiveCount = c.size_t(len(system.build_primitives)),
        primitiveArrayCapacity = c.size_t(cap(system.build_primitives)),
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
}

// Add entity to BVH system
bvh_system_add_entity :: proc(system: ^Sys_Bvh, entity: Entity) {
    system.rebuild = true
    append(&system.entities, entity)

    // Get primitive component
    prim_comp := get_component(entity, Cmp_Primitive)
    if prim_comp != nil {
        append(&system.primitive_components, prim_comp)
    }
}

// Remove entity from BVH system
bvh_system_remove_entity :: proc(system: ^Sys_Bvh, entity: Entity) {
    system.rebuild = true

    // Find and remove entity
    for e, i in system.entities {
        if e == entity {
            ordered_remove(&system.entities, i)
            ordered_remove(&system.primitive_components, i)
            break
        }
    }
}

// Check if rebuild is needed and build if so
bvh_system_update :: proc(system: ^Sys_Bvh) {
    if system.rebuild {
        bvh_system_build(system)
        system.rebuild = false
    }
}

// ECS integration procedures
bvh_system_query_entities :: proc() -> []Entity {
    // Query for entities with Cmp_Node, Cmp_Transform, andCmp_Primitive
    archetypes := query(
        ecs.has(Cmp_Node),
        ecs.has(Cmp_Transform),
        ecs.has(Cmp_Primitive))

    entities: [dynamic]Entity
    defer delete(entities)

    for archetype in archetypes {
        for entity in archetype.entities {
            append(&entities, entity)
        }
    }

    return entities[:]
}

// Initialize BVH system with existing entities
bvh_system_initialize :: proc(system: ^Sys_Bvh) {
    for arch in query(has(Cmp_Node), has(Cmp_Transform), has(Cmp_Primitive)){
    for entity in arch.entities {
        bvh_system_add_entity(system, entity)
    }}

    // Do initial build
    bvh_system_build(system)
}

// Print BVH statistics (utility function)
bvh_system_print_stats :: proc(using system: ^Sys_Bvh) {
    fmt.printf("BVH Statistics:\n")
    fmt.printf("  Entities: %d\n", len(entities))
    fmt.printf("  Primitives: %d\n", len(primitive_components))
    fmt.printf("  Nodes: %d\n", num_nodes)
    fmt.printf("  Root SAH: %.2f\n", bvh_sah(root))
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
                    x = trans.euler_rotation.x,
                    y = trans.euler_rotation.y,
                    z = trans.euler_rotation.z,
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
        scene_node.Children = make([dynamic]scene.Node, len(cmp_node.children))
        for child_ent, i in cmp_node.children {
            scene_node.Children[i] = save_node(child_ent)
        }
    }

    return scene_node
}

// Save entire scene from head node
save_scene :: proc(head_entity: Entity, scene_num: i32) -> scene.SceneData {
    scene_data := scene.SceneData {
        Scene = scene.Scene{Num = scene_num},
        Node = make([dynamic]scene.Node, 1),
    }
    scene_data.Node[0] = save_node(head_entity)

    // If multiple roots, append more
    // But assuming single head for now

    return scene_data
}

//----------------------------------------------------------------------------\\
// /LOAD
//----------------------------------------------------------------------------\\

// Load a scene.Node into ECS Cmp_Node hierarchy
load_node :: proc(scene_node: scene.Node, parent: Entity = Entity(0), alloc: mem.Allocator) -> Entity {
    context.allocator = alloc
    entity := add_entity()

    e_flags := transmute(ComponentFlags)scene_node.eFlags

    // Add transform
    if .TRANSFORM in e_flags {
        pos := linalg.Vector3f32 {
            scene_node.Transform.Position.x,
            scene_node.Transform.Position.y,
            scene_node.Transform.Position.z,
        }
        rot := linalg.Vector3f32 {
            scene_node.Transform.Rotation.x,
            scene_node.Transform.Rotation.y,
            scene_node.Transform.Rotation.z,
        }
        sca := linalg.Vector3f32 {
            scene_node.Transform.Scale.x,
            scene_node.Transform.Scale.y,
            scene_node.Transform.Scale.z,
        }
        trans_comp := cmp_transform_prs(pos, rot, sca)
        add_component(entity, trans_comp)
    } else {
        add_component(entity, Cmp_Transform{}) // Default
        e_flags += {.TRANSFORM}
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
            e_flags += {.RIGIDBODY}
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
            e_flags += {.COLIDER}
        }
    }

    // Handle other flags/components as in C++
    // e.g. Prefab, GUI, etc. - add similar logic if components are defined

    // If root
    if .ROOT in e_flags {
        add_component(entity, Cmp_Root{})
    }

    // Now add Cmp_Node with final flags (children starts empty)
    cmp_node_local := Cmp_Node {
        entity       = entity,
        parent       = parent,  // Set parent Entity ID here
        children     = make([dynamic]Entity, 0, alloc) if scene_node.hasChildren else {},  // Pre-allocate if known
        name         = strings.clone(scene_node.Name),
        is_dynamic   = scene_node.Dynamic,
        is_parent    = scene_node.hasChildren,
        engine_flags = e_flags,
        game_flags   = scene_node.gFlags,
    }
    add_component(entity, cmp_node_local)

    cmp_node := get_component(entity, Cmp_Node)
    if cmp_node == nil { return Entity(0) }

    // Set is_parent for camera and light as in original
    if .CAMERA in cmp_node.engine_flags { cmp_node.is_parent = true }
    if .LIGHT in cmp_node.engine_flags { cmp_node.is_parent = true }

    // Recurse for children and link via Entity IDs
    if scene_node.hasChildren {
        reserve(&cmp_node.children, len(scene_node.Children))  // Optional: pre-reserve
        for &child_scene, i in scene_node.Children {
            child_entity := load_node(child_scene, entity, alloc)  // Pass parent entity
            if child_entity != Entity(0) {
                append(&cmp_node.children, child_entity)
                // Optionally: Get child_node and set its parent if not already (but it's set in cmp_node_local above)
            }
        }
    }

    // If this is a root (no parent), append to g_scene
    if parent == Entity(0) && .ROOT in cmp_node.engine_flags {
        append(&g_scene, entity)
    }
    return entity
}

// Load entire scene
load_scene :: proc(scene_data: scene.SceneData, alloc: mem.Allocator) {
    context.allocator = alloc
	if len(scene_data.Node) == 0 {
		return // Entity(0)
	}
	for node in scene_data.Node {
		load_node(node, alloc = alloc)
	}
}