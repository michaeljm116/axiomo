package embree

import "core:c"

// Opaque BVH type
RTCBVH :: distinct rawptr

// Opaque thread local allocator type
RTCThreadLocalAllocator :: distinct rawptr

// Build flags
RTCBuildFlags :: enum c.int {
    NONE    = 0,
    DYNAMIC = 1 << 0,
}

// Build constants
RTC_BUILD_MAX_PRIMITIVES_PER_LEAF :: 32

// Build quality is in common.RTCBuildQuality

// Build primitive struct
RTCBuildPrimitive :: struct #align(32) {
    lower_x, lower_y, lower_z: f32,
    geomID: u32,
    upper_x, upper_y, upper_z: f32,
    primID: u32,
}

// Callback types
RTCCreateNodeFunction :: #type proc "c" (allocator: RTCThreadLocalAllocator, childCount: u32, userPtr: rawptr) -> rawptr
RTCSetNodeChildrenFunction :: #type proc "c" (nodePtr: rawptr, children: ^^rawptr, childCount: u32, userPtr: rawptr)
RTCSetNodeBoundsFunction :: #type proc "c" (nodePtr: rawptr, bounds: ^^RTCBounds, childCount: u32, userPtr: rawptr)
RTCCreateLeafFunction :: #type proc "c" (allocator: RTCThreadLocalAllocator, primitives: ^RTCBuildPrimitive, primitiveCount: c.size_t, userPtr: rawptr) -> rawptr
RTCSplitPrimitiveFunction :: #type proc "c" (primitive: ^RTCBuildPrimitive, dimension: u32, position: f32, leftBounds: ^RTCBounds, rightBounds: ^RTCBounds, userPtr: rawptr)

// Build arguments struct
RTCBuildArguments :: struct {
    byteSize: c.size_t,
    buildQuality: RTCBuildQuality,
    buildFlags: RTCBuildFlags,
    maxBranchingFactor: u32,
    maxDepth: u32,
    sahBlockSize: u32,
    minLeafSize: u32,
    maxLeafSize: u32,
    traversalCost: f32,
    intersectionCost: f32,
    bvh: RTCBVH,
    primitives: ^RTCBuildPrimitive,
    primitiveCount: c.size_t,
    primitiveArrayCapacity: c.size_t,
    createNode: RTCCreateNodeFunction,
    setNodeChildren: RTCSetNodeChildrenFunction,
    setNodeBounds: RTCSetNodeBoundsFunction,
    createLeaf: RTCCreateLeafFunction,
    splitPrimitive: RTCSplitPrimitiveFunction,
    buildProgress: rawptr, // Use appropriate callback type if needed
    userPtr: rawptr,
}

// Foreign function declarations
foreign import embree "lib/embree4.lib"
foreign embree {
    @(link_name="rtcNewBVH")
    rtcNewBVH :: proc(device: RTCDevice) -> RTCBVH ---

    @(link_name="rtcBuildBVH")
    rtcBuildBVH :: proc(args: ^RTCBuildArguments) -> rawptr ---

    @(link_name="rtcThreadLocalAlloc")
    rtcThreadLocalAlloc :: proc(allocator: RTCThreadLocalAllocator, bytes: c.size_t, align: c.size_t) -> rawptr ---

    @(link_name="rtcRetainBVH")
    rtcRetainBVH :: proc(bvh: RTCBVH) ---

    @(link_name="rtcReleaseBVH")
    rtcReleaseBVH :: proc(bvh: RTCBVH) ---
}

