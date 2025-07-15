package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:slice"
import ecs "external/ecs"
import embree "external/embree"

//----------------------------------------------------------------------------\\
// /BVH System /bs
//----------------------------------------------------------------------------\\

Sys_Bvh :: struct {
    // ECS world reference

    // Embree data
    device: embree.RTCDevice,
    bvh: embree.RTCBVH,

    // BVH tree data
    root: ^BvhNode,
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

    assert(numPrims >= MIN_LEAF_SIZE && numPrims <= MAX_LEAF_SIZE)
    ptr := embree.rtcThreadLocalAlloc(alloc, size_of(LeafBvhNode), 16)
     g_num_nodes += 1

    // Create leaf node
    node := cast(^LeafBvhNode)ptr
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
    system.root = transmute(^BvhNode)embree.rtcBuildBVH(&arguments)
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
    entities := bvh_system_query_entities()

    for entity in entities {
        bvh_system_add_entity(system, entity)
    }

    // Do initial build
    bvh_system_build(system)
}

// Print BVH statistics (utility function)
bvh_system_print_stats :: proc(using system: ^Sys_Bvh) {
    fmt.printf("BVH Statistics:\n")
    fmt.printf("  Entities: %d\n", len(entities))
    fmt.printf("  Primitives: %d\n", len(primitive_components))
    fmt.printf("  Nodes: %d\n", num_nodes)
    fmt.printf("  Root SAH: %.2f\n", bvh_sah(root^))
}
