package embree

import "core:c"
RTC_VERSION_MAJOR :: 4
RTC_VERSION_MINOR :: 4
RTC_VERSION_PATCH :: 0
RTC_VERSION       :: 40400
RTC_VERSION_STRING :: "4.4.0"


EMBREE_GEOMETRY_INSTANCE_ARRAY :: true
RTC_GEOMETRY_INSTANCE_ARRAY :: true

EMBREE_SYCL_GEOMETRY_CALLBACK :: 0

EMBREE_MIN_WIDTH :: 0
RTC_MIN_WIDTH :: EMBREE_MIN_WIDTH

// EMBREE_STATIC_LIB and EMBREE_API_NAMESPACE are not needed in Odin

// API/namespace macros are not needed in Odin

// No need for import/export/visibility macros in Odin

RTCBuffer :: distinct rawptr

RTCBufferType :: enum c.int {
    INDEX = 0,
    VERTEX = 1,
    VERTEX_ATTRIBUTE = 2,
    NORMAL = 3,
    TANGENT = 4,
    NORMAL_DERIVATIVE = 5,
    GRID = 8,
    FACE = 16,
    LEVEL = 17,
    EDGE_CREASE_INDEX = 18,
    EDGE_CREASE_WEIGHT = 19,
    VERTEX_CREASE_INDEX = 20,
    VERTEX_CREASE_WEIGHT = 21,
    HOLE = 22,
    TRANSFORM = 23,
    FLAGS = 32,
}

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

RTC_MAX_INSTANCE_LEVEL_COUNT :: 1
RTC_INVALID_GEOMETRY_ID :: u32(0xFFFFFFFF)
RTC_MAX_TIME_STEP_COUNT :: 129

RTCFormat :: enum c.int {
    UNDEFINED = 0,
    UCHAR = 0x1001,
    UCHAR2,
    UCHAR3,
    UCHAR4,
    CHAR = 0x2001,
    CHAR2,
    CHAR3,
    CHAR4,
    USHORT = 0x3001,
    USHORT2,
    USHORT3,
    USHORT4,
    SHORT = 0x4001,
    SHORT2,
    SHORT3,
    SHORT4,
    UINT = 0x5001,
    UINT2,
    UINT3,
    UINT4,
    INT = 0x6001,
    INT2,
    INT3,
    INT4,
    ULLONG = 0x7001,
    ULLONG2,
    ULLONG3,
    ULLONG4,
    LLONG = 0x8001,
    LLONG2,
    LLONG3,
    LLONG4,
    FLOAT = 0x9001,
    FLOAT2,
    FLOAT3,
    FLOAT4,
    FLOAT5,
    FLOAT6,
    FLOAT7,
    FLOAT8,
    FLOAT9,
    FLOAT10,
    FLOAT11,
    FLOAT12,
    FLOAT13,
    FLOAT14,
    FLOAT15,
    FLOAT16,
    FLOAT2X2_ROW_MAJOR = 0x9122,
    FLOAT2X3_ROW_MAJOR = 0x9123,
    FLOAT2X4_ROW_MAJOR = 0x9124,
    FLOAT3X2_ROW_MAJOR = 0x9132,
    FLOAT3X3_ROW_MAJOR = 0x9133,
    FLOAT3X4_ROW_MAJOR = 0x9134,
    FLOAT4X2_ROW_MAJOR = 0x9142,
    FLOAT4X3_ROW_MAJOR = 0x9143,
    FLOAT4X4_ROW_MAJOR = 0x9144,
    FLOAT2X2_COLUMN_MAJOR = 0x9222,
    FLOAT2X3_COLUMN_MAJOR = 0x9223,
    FLOAT2X4_COLUMN_MAJOR = 0x9224,
    FLOAT3X2_COLUMN_MAJOR = 0x9232,
    FLOAT3X3_COLUMN_MAJOR = 0x9233,
    FLOAT3X4_COLUMN_MAJOR = 0x9234,
    FLOAT4X2_COLUMN_MAJOR = 0x9242,
    FLOAT4X3_COLUMN_MAJOR = 0x9243,
    FLOAT4X4_COLUMN_MAJOR = 0x9244,
    GRID = 0xA001,
    QUATERNION_DECOMPOSITION = 0xB001,
}

RTCBuildQuality :: enum c.int {
    LOW = 0,
    MEDIUM = 1,
    HIGH = 2,
    REFIT = 3,
}

RTCFeatureFlags :: enum c.int {
    NONE = 0,
    MOTION_BLUR = 1 << 0,
    TRIANGLE = 1 << 1,
    QUAD = 1 << 2,
    GRID = 1 << 3,
    SUBDIVISION = 1 << 4,
    CONE_LINEAR_CURVE = 1 << 5,
    ROUND_LINEAR_CURVE = 1 << 6,
    FLAT_LINEAR_CURVE = 1 << 7,
    ROUND_BEZIER_CURVE = 1 << 8,
    FLAT_BEZIER_CURVE = 1 << 9,
    NORMAL_ORIENTED_BEZIER_CURVE = 1 << 10,
    ROUND_BSPLINE_CURVE = 1 << 11,
    FLAT_BSPLINE_CURVE = 1 << 12,
    NORMAL_ORIENTED_BSPLINE_CURVE = 1 << 13,
    ROUND_HERMITE_CURVE = 1 << 14,
    FLAT_HERMITE_CURVE = 1 << 15,
    NORMAL_ORIENTED_HERMITE_CURVE = 1 << 16,
    ROUND_CATMULL_ROM_CURVE = 1 << 17,
    FLAT_CATMULL_ROM_CURVE = 1 << 18,
    NORMAL_ORIENTED_CATMULL_ROM_CURVE = 1 << 19,
    SPHERE_POINT = 1 << 20,
    DISC_POINT = 1 << 21,
    ORIENTED_DISC_POINT = 1 << 22,
    INSTANCE = 1 << 23,
    FILTER_FUNCTION_IN_ARGUMENTS = 1 << 24,
    FILTER_FUNCTION_IN_GEOMETRY = 1 << 25,
    USER_GEOMETRY_CALLBACK_IN_ARGUMENTS = 1 << 26,
    USER_GEOMETRY_CALLBACK_IN_GEOMETRY = 1 << 27,
    _32_BIT_RAY_MASK = 1 << 28,
    INSTANCE_ARRAY = 1 << 29,
}

RTC_FEATURE_FLAG_POINT : c.int = c.int(RTCFeatureFlags.SPHERE_POINT) | c.int(RTCFeatureFlags.DISC_POINT) | c.int(RTCFeatureFlags.ORIENTED_DISC_POINT)
RTC_FEATURE_FLAG_ROUND_CURVES : c.int = c.int(RTCFeatureFlags.ROUND_LINEAR_CURVE) | c.int(RTCFeatureFlags.ROUND_BEZIER_CURVE) | c.int(RTCFeatureFlags.ROUND_BSPLINE_CURVE) | c.int(RTCFeatureFlags.ROUND_HERMITE_CURVE) | c.int(RTCFeatureFlags.ROUND_CATMULL_ROM_CURVE)
RTC_FEATURE_FLAG_FLAT_CURVES : c.int = c.int(RTCFeatureFlags.FLAT_LINEAR_CURVE) | c.int(RTCFeatureFlags.FLAT_BEZIER_CURVE) | c.int(RTCFeatureFlags.FLAT_BSPLINE_CURVE) | c.int(RTCFeatureFlags.FLAT_HERMITE_CURVE) | c.int(RTCFeatureFlags.FLAT_CATMULL_ROM_CURVE)
RTC_FEATURE_FLAG_NORMAL_ORIENTED_CURVES : c.int = c.int(RTCFeatureFlags.NORMAL_ORIENTED_BEZIER_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_BSPLINE_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_HERMITE_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_CATMULL_ROM_CURVE)
RTC_FEATURE_FLAG_LINEAR_CURVES : c.int = c.int(RTCFeatureFlags.CONE_LINEAR_CURVE) | c.int(RTCFeatureFlags.ROUND_LINEAR_CURVE) | c.int(RTCFeatureFlags.FLAT_LINEAR_CURVE)
RTC_FEATURE_FLAG_BEZIER_CURVES : c.int = c.int(RTCFeatureFlags.ROUND_BEZIER_CURVE) | c.int(RTCFeatureFlags.FLAT_BEZIER_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_BEZIER_CURVE)
RTC_FEATURE_FLAG_BSPLINE_CURVES : c.int = c.int(RTCFeatureFlags.ROUND_BSPLINE_CURVE) | c.int(RTCFeatureFlags.FLAT_BSPLINE_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_BSPLINE_CURVE)
RTC_FEATURE_FLAG_HERMITE_CURVES : c.int = c.int(RTCFeatureFlags.ROUND_HERMITE_CURVE) | c.int(RTCFeatureFlags.FLAT_HERMITE_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_HERMITE_CURVE)
RTC_FEATURE_FLAG_CURVES : c.int = c.int(RTCFeatureFlags.CONE_LINEAR_CURVE) | c.int(RTCFeatureFlags.ROUND_LINEAR_CURVE) | c.int(RTCFeatureFlags.FLAT_LINEAR_CURVE) | c.int(RTCFeatureFlags.ROUND_BEZIER_CURVE) | c.int(RTCFeatureFlags.FLAT_BEZIER_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_BEZIER_CURVE) | c.int(RTCFeatureFlags.ROUND_BSPLINE_CURVE) | c.int(RTCFeatureFlags.FLAT_BSPLINE_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_BSPLINE_CURVE) | c.int(RTCFeatureFlags.ROUND_HERMITE_CURVE) | c.int(RTCFeatureFlags.FLAT_HERMITE_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_HERMITE_CURVE) | c.int(RTCFeatureFlags.ROUND_CATMULL_ROM_CURVE) | c.int(RTCFeatureFlags.FLAT_CATMULL_ROM_CURVE) | c.int(RTCFeatureFlags.NORMAL_ORIENTED_CATMULL_ROM_CURVE)
RTC_FEATURE_FLAG_FILTER_FUNCTION : c.int = c.int(RTCFeatureFlags.FILTER_FUNCTION_IN_ARGUMENTS) | c.int(RTCFeatureFlags.FILTER_FUNCTION_IN_GEOMETRY)
RTC_FEATURE_FLAG_USER_GEOMETRY : c.int = c.int(RTCFeatureFlags.USER_GEOMETRY_CALLBACK_IN_ARGUMENTS) | c.int(RTCFeatureFlags.USER_GEOMETRY_CALLBACK_IN_GEOMETRY)
RTC_FEATURE_FLAG_ALL : c.int = -1

RTCRayQueryFlags :: enum c.int {
    NONE = 0,
    INVOKE_ARGUMENT_FILTER = 1 << 1,
    INCOHERENT = 0 << 16,
    COHERENT = 1 << 16,
}

RTCBounds :: struct #align (16) {
    lower_x: f32,
    lower_y: f32,
    lower_z: f32,
    align0: f32,
    upper_x: f32,
    upper_y: f32,
    upper_z: f32,
    align1: f32,
}

RTCLinearBounds :: struct #align (16) {
    bounds0: RTCBounds,
    bounds1: RTCBounds,
}

RTCRayQueryContext :: struct {
    instID: [RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
    instPrimID: [RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
}

RTCPointQuery :: struct #align (16) {
    x: f32,
    y: f32,
    z: f32,
    time: f32,
    radius: f32,
}

RTCPointQuery4 :: struct #align(16){
    x: [4]f32,
    y: [4]f32,
    z: [4]f32,
    time: [4]f32,
    radius: [4]f32,
}

RTCPointQuery8 :: struct #align (32) {
    x: [8]f32,
    y: [8]f32,
    z: [8]f32,
    time: [8]f32,
    radius: [8]f32,
}

RTCPointQuery16 :: struct #align (64) {
    x: [16]f32,
    y: [16]f32,
    z: [16]f32,
    time: [16]f32,
    radius: [16]f32,
}

RTCPointQueryContext :: struct #align (16) {
    world2inst: [RTC_MAX_INSTANCE_LEVEL_COUNT][16]f32,
    inst2world: [RTC_MAX_INSTANCE_LEVEL_COUNT][16]f32,
    instID: [RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
    instPrimID: [RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
    instStackSize: u32,
}

RTCFilterFunctionNArguments :: struct {
    valid: ^c.int,
    geometryUserPtr: rawptr,
    ctx: ^RTCRayQueryContext,
    ray: rawptr, // ^RTCRayN
    hit: rawptr, // ^RTCHitN
    N: u32,
}

RTCPointQueryFunctionArguments :: struct #align (16) {
    query: ^RTCPointQuery,
    userPtr: rawptr,
    primID: u32,
    geomID: u32,
    ctx: ^RTCPointQueryContext,
    similarityScale: f32,
}


RTCDevice :: distinct rawptr
RTCScene :: distinct rawptr

RTCDeviceProperty :: enum c.int {
    VERSION = 0,
    VERSION_MAJOR = 1,
    VERSION_MINOR = 2,
    VERSION_PATCH = 3,
    NATIVE_RAY4_SUPPORTED = 32,
    NATIVE_RAY8_SUPPORTED = 33,
    NATIVE_RAY16_SUPPORTED = 34,
    BACKFACE_CULLING_SPHERES_ENABLED = 62,
    BACKFACE_CULLING_CURVES_ENABLED = 63,
    RAY_MASK_SUPPORTED = 64,
    BACKFACE_CULLING_ENABLED = 65,
    FILTER_FUNCTION_SUPPORTED = 66,
    IGNORE_INVALID_RAYS_ENABLED = 67,
    COMPACT_POLYS_ENABLED = 68,
    TRIANGLE_GEOMETRY_SUPPORTED = 96,
    QUAD_GEOMETRY_SUPPORTED = 97,
    SUBDIVISION_GEOMETRY_SUPPORTED = 98,
    CURVE_GEOMETRY_SUPPORTED = 99,
    USER_GEOMETRY_SUPPORTED = 100,
    POINT_GEOMETRY_SUPPORTED = 101,
    TASKING_SYSTEM = 128,
    JOIN_COMMIT_SUPPORTED = 129,
    PARALLEL_COMMIT_SUPPORTED = 130,
    CPU_DEVICE = 140,
    SYCL_DEVICE = 141,
}

RTCError :: enum c.int {
    NONE = 0,
    UNKNOWN = 1,
    INVALID_ARGUMENT = 2,
    INVALID_OPERATION = 3,
    OUT_OF_MEMORY = 4,
    UNSUPPORTED_CPU = 5,
    CANCELLED = 6,
    LEVEL_ZERO_RAYTRACING_SUPPORT_MISSING = 7,
}

RTCErrorFunction :: #type proc "c" (userPtr: rawptr, code: RTCError, str: cstring)
RTCMemoryMonitorFunction :: #type proc "c" (ptr: rawptr, bytes: c.ssize_t, post: bool) -> bool

RTCGeometry :: distinct rawptr

RTCGeometryType :: enum c.int
{
  TRIANGLE = 0, // triangle mesh
  QUAD     = 1, // quad (triangle pair) mesh
  GRID     = 2, // grid mesh

  SUBDIVISION = 8, // Catmull-Clark subdivision surface

  CONE_LINEAR_CURVE   = 15, // Cone linear curves - discontinuous at edge boundaries
  ROUND_LINEAR_CURVE  = 16, // Round (rounded cone like) linear curves
  FLAT_LINEAR_CURVE   = 17, // flat (ribbon-like) linear curves

  ROUND_BEZIER_CURVE  = 24, // round (tube-like) Bezier curves
  FLAT_BEZIER_CURVE   = 25, // flat (ribbon-like) Bezier curves
  NORMAL_ORIENTED_BEZIER_CURVE  = 26, // flat normal-oriented Bezier curves

  ROUND_BSPLINE_CURVE = 32, // round (tube-like) B-spline curves
  FLAT_BSPLINE_CURVE  = 33, // flat (ribbon-like) B-spline curves
  NORMAL_ORIENTED_BSPLINE_CURVE  = 34, // flat normal-oriented B-spline curves

  ROUND_HERMITE_CURVE = 40, // round (tube-like) Hermite curves
  FLAT_HERMITE_CURVE  = 41, // flat (ribbon-like) Hermite curves
  NORMAL_ORIENTED_HERMITE_CURVE  = 42, // flat normal-oriented Hermite curves

  SPHERE_POINT = 50,
  DISC_POINT = 51,
  ORIENTED_DISC_POINT = 52,

  ROUND_CATMULL_ROM_CURVE = 58, // round (tube-like) Catmull-Rom curves
  FLAT_CATMULL_ROM_CURVE  = 59, // flat (ribbon-like) Catmull-Rom curves
  NORMAL_ORIENTED_CATMULL_ROM_CURVE  = 60, // flat normal-oriented Catmull-Rom curves

  USER     = 120, // user-defined geometry
  INSTANCE = 121,  // scene instance
  INSTANCE_ARRAY = 122,  // scene instance array
};

RTCSubdivisionMode :: enum c.int
{
  NO_BOUNDARY     = 0,
  SMOOTH_BOUNDARY = 1,
  PIN_CORNERS     = 2,
  PIN_BOUNDARY    = 3,
  PIN_ALL         = 4,
};

/* Curve segment flags */
RTCCurveFlags :: enum c.int
{
  NEIGHBOR_LEFT  = (1 << 0), // left segments exists
  NEIGHBOR_RIGHT = (1 << 1)  // right segment exists
};

// Callback argument structs
RTCBoundsFunctionArguments :: struct {
    geometryUserPtr: rawptr,
    primID: c.uint,
    timeStep: c.uint,
    bounds_o: ^RTCBounds,
}

RTCBoundsFunction :: #type proc "c" (args: ^RTCBoundsFunctionArguments)

// Intersect/occluded/displacement callback argument structs
RTCIntersectFunctionNArguments :: struct {
    valid: ^c.int,
    geometryUserPtr: rawptr,
    primID: c.uint,
    ctx: ^RTCRayQueryContext,
    rayhit: rawptr, // ^RTCRayHitN, define as needed
    N: c.uint,
    geomID: c.uint,
}
RTCOccludedFunctionNArguments :: struct {
    valid: ^c.int,
    geometryUserPtr: rawptr,
    primID: c.uint,
    ctx: ^RTCRayQueryContext,
    ray: rawptr, // ^RTCRayN, define as needed
    N: c.uint,
    geomID: c.uint,
}
RTCDisplacementFunctionNArguments :: struct {
    geometryUserPtr: rawptr,
    geometry: RTCGeometry,
    primID: c.uint,
    timeStep: c.uint,
    u: ^f32,
    v: ^f32,
    Ng_x: ^f32,
    Ng_y: ^f32,
    Ng_z: ^f32,
    P_x: ^f32,
    P_y: ^f32,
    P_z: ^f32,
    N: c.uint,
}

RTCDisplacementFunctionN :: #type proc "c" (args: ^RTCDisplacementFunctionNArguments)

// Interpolation argument structs
RTCInterpolateArguments :: struct {
    geometry: RTCGeometry,
    primID: c.uint,
    u: f32,
    v: f32,
    bufferType: RTCBufferType,
    bufferSlot: c.uint,
    P: ^f32,
    dPdu: ^f32,
    dPdv: ^f32,
    ddPdudu: ^f32,
    ddPdvdv: ^f32,
    ddPdudv: ^f32,
    valueCount: c.uint,
}
RTCInterpolateNArguments :: struct {
    geometry: RTCGeometry,
    valid: rawptr, // const void*
    primIDs: ^c.uint,
    u: ^f32,
    v: ^f32,
    N: c.uint,
    bufferType: RTCBufferType,
    bufferSlot: c.uint,
    P: ^f32,
    dPdu: ^f32,
    dPdv: ^f32,
    ddPdudu: ^f32,
    ddPdvdv: ^f32,
    ddPdudv: ^f32,
    valueCount: c.uint,
}

// Grid primitive struct
RTCGrid :: struct {
    startVertexID: c.uint,
    stride: c.uint,
    width: u16,
    height: u16,
}

// Quaternion decomposition struct (16 floats, 16-byte aligned)
RTCQuaternionDecomposition :: struct #align(16) {
    scale_x, scale_y, scale_z: f32,
    skew_xy, skew_xz, skew_yz: f32,
    shift_x, shift_y, shift_z: f32,
    quaternion_r, quaternion_i, quaternion_j, quaternion_k: f32,
    translation_x, translation_y, translation_z: f32,
}

// Single ray structure
RTCRay :: struct #align(16) {
    org_x, org_y, org_z, tnear: f32,
    dir_x, dir_y, dir_z, time: f32,
    tfar: f32,
    mask: u32,
    id: u32,
    flags: u32,
}

// Ray hit structure
RTCHit :: struct #align(16) {
    Ng_x, Ng_y, Ng_z: f32,
    u, v: f32,
    primID: u32,
    geomID: u32,
    instID: [RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
}

// Ray + hit structure
RTCRayHit :: struct #align(16) {
    ray: RTCRay,
    hit: RTCHit,
}

// Ray packets (4, 8, 16)
RTCRay4 :: struct #align(16) {
    org_x, org_y, org_z, tnear: [4]f32,
    dir_x, dir_y, dir_z, time: [4]f32,
    tfar: [4]f32,
    mask: [4]u32,
    id: [4]u32,
    flags: [4]u32,
}

RTCHit4 :: struct #align(16) {
    Ng_x, Ng_y, Ng_z: [4]f32,
    u, v: [4]f32,
    primID: [4]u32,
    geomID: [4]u32,
    instID: [4][RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
}

RTCRayHit4 :: struct #align(16) {
    ray: RTCRay4,
    hit: RTCHit4,
}

RTCRay8 :: struct #align(32) {
    org_x, org_y, org_z, tnear: [8]f32,
    dir_x, dir_y, dir_z, time: [8]f32,
    tfar: [8]f32,
    mask: [8]u32,
    id: [8]u32,
    flags: [8]u32,
}

RTCHit8 :: struct #align(32) {
    Ng_x, Ng_y, Ng_z: [8]f32,
    u, v: [8]f32,
    primID: [8]u32,
    geomID: [8]u32,
    instID: [8][RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
}

RTCRayHit8 :: struct #align(32) {
    ray: RTCRay8,
    hit: RTCHit8,
}

RTCRay16 :: struct #align(64) {
    org_x, org_y, org_z, tnear: [16]f32,
    dir_x, dir_y, dir_z, time: [16]f32,
    tfar: [16]f32,
    mask: [16]u32,
    id: [16]u32,
    flags: [16]u32,
}

RTCHit16 :: struct #align(64) {
    Ng_x, Ng_y, Ng_z: [16]f32,
    u, v: [16]f32,
    primID: [16]u32,
    geomID: [16]u32,
    instID: [16][RTC_MAX_INSTANCE_LEVEL_COUNT]u32,
}

RTCRayHit16 :: struct #align(64) {
    ray: RTCRay16,
    hit: RTCHit16,
}

// N-wide ray/hit types (opaque for user geometry callbacks)
RTCRayN :: distinct rawptr
RTCHitN :: distinct rawptr
RTCRayHitN :: distinct rawptr


RTCTraversable :: distinct rawptr

// Scene flags
RTCSceneFlags :: enum c.int {
    NONE                         = 0,
    DYNAMIC                      = 1 << 0,
    COMPACT                      = 1 << 1,
    ROBUST                       = 1 << 2,
    FILTER_FUNCTION_IN_ARGUMENTS = 1 << 3,
    PREFETCH_USM_SHARED_ON_GPU   = 1 << 4,
}

// Progress monitor callback
RTCProgressMonitorFunction :: #type proc "c" (ptr: rawptr, n: f64) -> bool

// Intersect/Occluded arguments
RTCIntersectArguments :: struct {
    flags: RTCRayQueryFlags,
    feature_mask: RTCFeatureFlags,
    ctx: ^RTCRayQueryContext,
    filter: RTCFilterFunctionN,
    intersect: RTCIntersectFunctionN,
    minWidthDistanceFactor: f32, // Only used if RTC_MIN_WIDTH != 0
}

RTCOccludedArguments :: struct {
    flags: RTCRayQueryFlags,
    feature_mask: RTCFeatureFlags,
    ctx: ^RTCRayQueryContext,
    filter: RTCFilterFunctionN,
    occluded: RTCOccludedFunctionN,
    minWidthDistanceFactor: f32, // Only used if RTC_MIN_WIDTH != 0
}

// Collision callback and struct
RTCCollision :: struct {
    geomID0: u32,
    primID0: u32,
    geomID1: u32,
    primID1: u32,
}
RTCCollideFunc :: #type proc "c" (userPtr: rawptr, collisions: ^RTCCollision, num_collisions: u32)


foreign import embree "lib/embree4.lib"
foreign import tbb "lib/tbb12.lib"
foreign embree{
    @(link_name="rtcNewBuffer")
    rtcNewBuffer :: proc(device: RTCDevice, byteSize: c.size_t) -> RTCBuffer ---
    @(link_name="rtcNewBufferHostDevice")
    rtcNewBufferHostDevice :: proc(device: RTCDevice, byteSize: c.size_t) -> RTCBuffer ---
    @(link_name="rtcNewSharedBuffer")
    rtcNewSharedBuffer :: proc(device: RTCDevice, ptr: rawptr, byteSize: c.size_t) -> RTCBuffer ---
    @(link_name="rtcNewSharedBufferHostDevice")
    rtcNewSharedBufferHostDevice :: proc(device: RTCDevice, ptr: rawptr, byteSize: c.size_t) -> RTCBuffer ---
    @(link_name="rtcCommitBuffer")
    rtcCommitBuffer :: proc(buffer: RTCBuffer) ---
    @(link_name="rtcGetBufferData")
    rtcGetBufferData :: proc(buffer: RTCBuffer) -> rawptr ---
    @(link_name="rtcGetBufferDataDevice")
    rtcGetBufferDataDevice :: proc(buffer: RTCBuffer) -> rawptr ---
    @(link_name="rtcRetainBuffer")
    rtcRetainBuffer :: proc(buffer: RTCBuffer) ---
    @(link_name="rtcReleaseBuffer")
    rtcReleaseBuffer :: proc(buffer: RTCBuffer) ---


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

    @(link_name="rtcNewDevice")
    rtcNewDevice :: proc(config: cstring) -> RTCDevice ---

    @(link_name="rtcRetainDevice")
    rtcRetainDevice :: proc(device: RTCDevice) ---

    @(link_name="rtcReleaseDevice")
    rtcReleaseDevice :: proc(device: RTCDevice) ---

    @(link_name="rtcGetDeviceProperty")
    rtcGetDeviceProperty :: proc(device: RTCDevice, prop: RTCDeviceProperty) -> c.ssize_t ---

    @(link_name="rtcSetDeviceProperty")
    rtcSetDeviceProperty :: proc(device: RTCDevice, prop: RTCDeviceProperty, value: c.ssize_t) ---

    @(link_name="rtcGetErrorString")
    rtcGetErrorString :: proc(error: RTCError) -> cstring ---

    @(link_name="rtcGetDeviceError")
    rtcGetDeviceError :: proc(device: RTCDevice) -> RTCError ---

    @(link_name="rtcGetDeviceLastErrorMessage")
    rtcGetDeviceLastErrorMessage :: proc(device: RTCDevice) -> cstring ---

    @(link_name="rtcSetDeviceErrorFunction")
    rtcSetDeviceErrorFunction :: proc(device: RTCDevice, error: RTCErrorFunction, userPtr: rawptr) ---

    @(link_name="rtcSetDeviceMemoryMonitorFunction")
    rtcSetDeviceMemoryMonitorFunction :: proc(device: RTCDevice, memoryMonitor: RTCMemoryMonitorFunction, userPtr: rawptr) ---

    @(link_name="rtcNewGeometry")
    rtcNewGeometry :: proc(device: RTCDevice, type: RTCGeometryType) -> RTCGeometry ---

    @(link_name="rtcRetainGeometry")
    rtcRetainGeometry :: proc(geometry: RTCGeometry) ---

    @(link_name="rtcReleaseGeometry")
    rtcReleaseGeometry :: proc(geometry: RTCGeometry) ---

    @(link_name="rtcCommitGeometry")
    rtcCommitGeometry :: proc(geometry: RTCGeometry) ---

    @(link_name="rtcEnableGeometry")
    rtcEnableGeometry :: proc(geometry: RTCGeometry) ---

    @(link_name="rtcDisableGeometry")
    rtcDisableGeometry :: proc(geometry: RTCGeometry) ---

    @(link_name="rtcSetGeometryTimeStepCount")
    rtcSetGeometryTimeStepCount :: proc(geometry: RTCGeometry, timeStepCount: c.uint) ---

    @(link_name="rtcSetGeometryTimeRange")
    rtcSetGeometryTimeRange :: proc(geometry: RTCGeometry, startTime: f32, endTime: f32) ---

    @(link_name="rtcSetGeometryVertexAttributeCount")
    rtcSetGeometryVertexAttributeCount :: proc(geometry: RTCGeometry, vertexAttributeCount: c.uint) ---

    @(link_name="rtcSetGeometryMask")
    rtcSetGeometryMask :: proc(geometry: RTCGeometry, mask: c.uint) ---

    @(link_name="rtcSetGeometryBuildQuality")
    rtcSetGeometryBuildQuality :: proc(geometry: RTCGeometry, quality: RTCBuildQuality) ---

    @(link_name="rtcSetGeometryMaxRadiusScale")
    rtcSetGeometryMaxRadiusScale :: proc(geometry: RTCGeometry, maxRadiusScale: f32) ---

    @(link_name="rtcSetGeometryBuffer")
    rtcSetGeometryBuffer :: proc(geometry: RTCGeometry, type: RTCBufferType, slot: c.uint, format: RTCFormat, buffer: rawptr, byteOffset: c.size_t, byteStride: c.size_t, itemCount: c.size_t) ---

    @(link_name="rtcSetSharedGeometryBuffer")
    rtcSetSharedGeometryBuffer :: proc(geometry: RTCGeometry, type: RTCBufferType, slot: c.uint, format: RTCFormat, ptr: rawptr, byteOffset: c.size_t, byteStride: c.size_t, itemCount: c.size_t) ---

    @(link_name="rtcSetSharedGeometryBufferHostDevice")
    rtcSetSharedGeometryBufferHostDevice :: proc(geometry: RTCGeometry, bufferType: RTCBufferType, slot: c.uint, format: RTCFormat, ptr: rawptr, dptr: rawptr, byteOffset: c.size_t, byteStride: c.size_t, itemCount: c.size_t) ---

    @(link_name="rtcSetNewGeometryBuffer")
    rtcSetNewGeometryBuffer :: proc(geometry: RTCGeometry, type: RTCBufferType, slot: c.uint, format: RTCFormat, byteStride: c.size_t, itemCount: c.size_t) -> rawptr ---

    @(link_name="rtcSetNewGeometryBufferHostDevice")
    rtcSetNewGeometryBufferHostDevice :: proc(geometry: RTCGeometry, bufferType: RTCBufferType, slot: c.uint, format: RTCFormat, byteStride: c.size_t, itemCount: c.size_t, ptr: ^^rawptr, dptr: ^^rawptr) ---

    @(link_name="rtcGetGeometryBufferData")
    rtcGetGeometryBufferData :: proc(geometry: RTCGeometry, type: RTCBufferType, slot: c.uint) -> rawptr ---

    @(link_name="rtcGetGeometryBufferDataDevice")
    rtcGetGeometryBufferDataDevice :: proc(geometry: RTCGeometry, type: RTCBufferType, slot: c.uint) -> rawptr ---

    @(link_name="rtcUpdateGeometryBuffer")
    rtcUpdateGeometryBuffer :: proc(geometry: RTCGeometry, type: RTCBufferType, slot: c.uint) ---

    @(link_name="rtcSetGeometryIntersectFilterFunction")
    rtcSetGeometryIntersectFilterFunction :: proc(geometry: RTCGeometry, filter: RTCFilterFunctionN) ---

    @(link_name="rtcSetGeometryOccludedFilterFunction")
    rtcSetGeometryOccludedFilterFunction :: proc(geometry: RTCGeometry, filter: RTCFilterFunctionN) ---

    @(link_name="rtcSetGeometryEnableFilterFunctionFromArguments")
    rtcSetGeometryEnableFilterFunctionFromArguments :: proc(geometry: RTCGeometry, enable: bool) ---

    @(link_name="rtcSetGeometryUserData")
    rtcSetGeometryUserData :: proc(geometry: RTCGeometry, ptr: rawptr) ---

    @(link_name="rtcGetGeometryUserData")
    rtcGetGeometryUserData :: proc(geometry: RTCGeometry) -> rawptr ---

    @(link_name="rtcSetGeometryPointQueryFunction")
    rtcSetGeometryPointQueryFunction :: proc(geometry: RTCGeometry, pointQuery: RTCPointQueryFunction) ---

    @(link_name="rtcSetGeometryUserPrimitiveCount")
    rtcSetGeometryUserPrimitiveCount :: proc(geometry: RTCGeometry, userPrimitiveCount: c.uint) ---

    @(link_name="rtcSetGeometryBoundsFunction")
    rtcSetGeometryBoundsFunction :: proc(geometry: RTCGeometry, bounds: RTCBoundsFunction, userPtr: rawptr) ---

    @(link_name="rtcSetGeometryIntersectFunction")
    rtcSetGeometryIntersectFunction :: proc(geometry: RTCGeometry, intersect: RTCIntersectFunctionN) ---

    @(link_name="rtcSetGeometryOccludedFunction")
    rtcSetGeometryOccludedFunction :: proc(geometry: RTCGeometry, occluded: RTCOccludedFunctionN) ---

    @(link_name="rtcSetGeometryInstancedScene")
    rtcSetGeometryInstancedScene :: proc(geometry: RTCGeometry, scene: RTCScene) ---

    @(link_name="rtcSetGeometryInstancedScenes")
    rtcSetGeometryInstancedScenes :: proc(geometry: RTCGeometry, scenes: ^RTCScene, numScenes: c.size_t) ---

    @(link_name="rtcSetGeometryTransform")
    rtcSetGeometryTransform :: proc(geometry: RTCGeometry, timeStep: c.uint, format: RTCFormat, xfm: rawptr) ---

    @(link_name="rtcSetGeometryTransformQuaternion")
    rtcSetGeometryTransformQuaternion :: proc(geometry: RTCGeometry, timeStep: c.uint, qd: rawptr) ---

    @(link_name="rtcGetGeometryTransform")
    rtcGetGeometryTransform :: proc(geometry: RTCGeometry, time: f32, format: RTCFormat, xfm: rawptr) ---

    @(link_name="rtcGetGeometryTransformEx")
    rtcGetGeometryTransformEx :: proc(geometry: RTCGeometry, instPrimID: c.uint, time: f32, format: RTCFormat, xfm: rawptr) ---

    @(link_name="rtcSetGeometryTessellationRate")
    rtcSetGeometryTessellationRate :: proc(geometry: RTCGeometry, tessellationRate: f32) ---

    @(link_name="rtcSetGeometryTopologyCount")
    rtcSetGeometryTopologyCount :: proc(geometry: RTCGeometry, topologyCount: c.uint) ---

    @(link_name="rtcSetGeometrySubdivisionMode")
    rtcSetGeometrySubdivisionMode :: proc(geometry: RTCGeometry, topologyID: c.uint, mode: RTCSubdivisionMode) ---

    @(link_name="rtcSetGeometryVertexAttributeTopology")
    rtcSetGeometryVertexAttributeTopology :: proc(geometry: RTCGeometry, vertexAttributeID: c.uint, topologyID: c.uint) ---

    @(link_name="rtcSetGeometryDisplacementFunction")
    rtcSetGeometryDisplacementFunction :: proc(geometry: RTCGeometry, displacement: RTCDisplacementFunctionN) ---

    @(link_name="rtcGetGeometryFirstHalfEdge")
    rtcGetGeometryFirstHalfEdge :: proc(geometry: RTCGeometry, faceID: c.uint) -> c.uint ---

    @(link_name="rtcGetGeometryFace")
    rtcGetGeometryFace :: proc(geometry: RTCGeometry, edgeID: c.uint) -> c.uint ---

    @(link_name="rtcGetGeometryNextHalfEdge")
    rtcGetGeometryNextHalfEdge :: proc(geometry: RTCGeometry, edgeID: c.uint) -> c.uint ---

    @(link_name="rtcGetGeometryPreviousHalfEdge")
    rtcGetGeometryPreviousHalfEdge :: proc(geometry: RTCGeometry, edgeID: c.uint) -> c.uint ---

    @(link_name="rtcGetGeometryOppositeHalfEdge")
    rtcGetGeometryOppositeHalfEdge :: proc(geometry: RTCGeometry, topologyID: c.uint, edgeID: c.uint) -> c.uint ---

    @(link_name="rtcInterpolate")
    rtcInterpolate :: proc(args: ^RTCInterpolateArguments) ---

    @(link_name="rtcInterpolateN")
    rtcInterpolateN :: proc(args: ^RTCInterpolateNArguments) ---

    @(link_name="rtcNewScene")
    rtcNewScene :: proc(device: RTCDevice) -> RTCScene ---

    @(link_name="rtcGetSceneDevice")
    rtcGetSceneDevice :: proc(hscene: RTCScene) -> RTCDevice ---

    @(link_name="rtcRetainScene")
    rtcRetainScene :: proc(scene: RTCScene) ---

    @(link_name="rtcReleaseScene")
    rtcReleaseScene :: proc(scene: RTCScene) ---

    @(link_name="rtcGetSceneTraversable")
    rtcGetSceneTraversable :: proc(scene: RTCScene) -> RTCTraversable ---

    @(link_name="rtcAttachGeometry")
    rtcAttachGeometry :: proc(scene: RTCScene, geometry: RTCGeometry) -> u32 ---

    @(link_name="rtcAttachGeometryByID")
    rtcAttachGeometryByID :: proc(scene: RTCScene, geometry: RTCGeometry, geomID: u32) ---

    @(link_name="rtcDetachGeometry")
    rtcDetachGeometry :: proc(scene: RTCScene, geomID: u32) ---

    @(link_name="rtcGetGeometry")
    rtcGetGeometry :: proc(scene: RTCScene, geomID: u32) -> RTCGeometry ---

    @(link_name="rtcGetGeometryThreadSafe")
    rtcGetGeometryThreadSafe :: proc(scene: RTCScene, geomID: u32) -> RTCGeometry ---

    @(link_name="rtcCommitScene")
    rtcCommitScene :: proc(scene: RTCScene) ---

    @(link_name="rtcJoinCommitScene")
    rtcJoinCommitScene :: proc(scene: RTCScene) ---

    @(link_name="rtcSetSceneProgressMonitorFunction")
    rtcSetSceneProgressMonitorFunction :: proc(scene: RTCScene, progress: RTCProgressMonitorFunction, ptr: rawptr) ---

    @(link_name="rtcSetSceneBuildQuality")
    rtcSetSceneBuildQuality :: proc(scene: RTCScene, quality: RTCBuildQuality) ---

    @(link_name="rtcSetSceneFlags")
    rtcSetSceneFlags :: proc(scene: RTCScene, flags: RTCSceneFlags) ---

    @(link_name="rtcGetSceneFlags")
    rtcGetSceneFlags :: proc(scene: RTCScene) -> RTCSceneFlags ---

    @(link_name="rtcGetSceneBounds")
    rtcGetSceneBounds :: proc(scene: RTCScene, bounds_o: ^RTCBounds) ---

    @(link_name="rtcGetSceneLinearBounds")
    rtcGetSceneLinearBounds :: proc(scene: RTCScene, bounds_o: ^RTCLinearBounds) ---

    @(link_name="rtcCollide")
    rtcCollide :: proc(scene0: RTCScene, scene1: RTCScene, callback: RTCCollideFunc, userPtr: rawptr) ---

    // Point query API
    @(link_name="rtcPointQuery")
    rtcPointQuery :: proc(scene: RTCScene, query: ^RTCPointQuery, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: rawptr) -> bool ---

    @(link_name="rtcPointQuery4")
    rtcPointQuery4 :: proc(valid: ^c.int, scene: RTCScene, query: ^RTCPointQuery4, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: ^^rawptr) -> bool ---

    @(link_name="rtcPointQuery8")
    rtcPointQuery8 :: proc(valid: ^c.int, scene: RTCScene, query: ^RTCPointQuery8, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: ^^rawptr) -> bool ---

    @(link_name="rtcPointQuery16")
    rtcPointQuery16 :: proc(valid: ^c.int, scene: RTCScene, query: ^RTCPointQuery16, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: ^^rawptr) -> bool ---

    // Ray intersection API
    @(link_name="rtcIntersect1")
    rtcIntersect1 :: proc(scene: RTCScene, rayhit: ^RTCRayHit, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcIntersect4")
    rtcIntersect4 :: proc(valid: ^c.int, scene: RTCScene, rayhit: ^RTCRayHit4, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcIntersect8")
    rtcIntersect8 :: proc(valid: ^c.int, scene: RTCScene, rayhit: ^RTCRayHit8, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcIntersect16")
    rtcIntersect16 :: proc(valid: ^c.int, scene: RTCScene, rayhit: ^RTCRayHit16, args: ^RTCIntersectArguments = nil) ---

    // Ray forwarding API
    @(link_name="rtcForwardIntersect1")
    rtcForwardIntersect1 :: proc(args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay, instID: u32) ---

    @(link_name="rtcForwardIntersect1Ex")
    rtcForwardIntersect1Ex :: proc(args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay, instID: u32, instPrimID: u32) ---

    @(link_name="rtcForwardIntersect4")
    rtcForwardIntersect4 :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay4, instID: u32) ---

    @(link_name="rtcForwardIntersect4Ex")
    rtcForwardIntersect4Ex :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay4, instID: u32, primInstID: u32) ---

    @(link_name="rtcForwardIntersect8")
    rtcForwardIntersect8 :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay8, instID: u32) ---

    @(link_name="rtcForwardIntersect8Ex")
    rtcForwardIntersect8Ex :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay8, instID: u32, primInstID: u32) ---

    @(link_name="rtcForwardIntersect16")
    rtcForwardIntersect16 :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay16, instID: u32) ---

    @(link_name="rtcForwardIntersect16Ex")
    rtcForwardIntersect16Ex :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, scene: RTCScene, ray: ^RTCRay16, instID: u32, primInstID: u32) ---

    // Occlusion API
    @(link_name="rtcOccluded1")
    rtcOccluded1 :: proc(scene: RTCScene, ray: ^RTCRay, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcOccluded4")
    rtcOccluded4 :: proc(valid: ^c.int, scene: RTCScene, ray: ^RTCRay4, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcOccluded8")
    rtcOccluded8 :: proc(valid: ^c.int, scene: RTCScene, ray: ^RTCRay8, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcOccluded16")
    rtcOccluded16 :: proc(valid: ^c.int, scene: RTCScene, ray: ^RTCRay16, args: ^RTCOccludedArguments = nil) ---

    // Occlusion forwarding API
    @(link_name="rtcForwardOccluded1")
    rtcForwardOccluded1 :: proc(args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay, instID: u32) ---

    @(link_name="rtcForwardOccluded1Ex")
    rtcForwardOccluded1Ex :: proc(args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay, instID: u32, instPrimID: u32) ---

    @(link_name="rtcForwardOccluded4")
    rtcForwardOccluded4 :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay4, instID: u32) ---

    @(link_name="rtcForwardOccluded4Ex")
    rtcForwardOccluded4Ex :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay4, instID: u32, instPrimID: u32) ---

    @(link_name="rtcForwardOccluded8")
    rtcForwardOccluded8 :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay8, instID: u32) ---

    @(link_name="rtcForwardOccluded8Ex")
    rtcForwardOccluded8Ex :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay8, instID: u32, instPrimID: u32) ---

    @(link_name="rtcForwardOccluded16")
    rtcForwardOccluded16 :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay16, instID: u32) ---

    @(link_name="rtcForwardOccluded16Ex")
    rtcForwardOccluded16Ex :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, scene: RTCScene, ray: ^RTCRay16, instID: u32, instPrimID: u32) ---

    // Geometry user data and transform from scene
    @(link_name="rtcGetGeometryUserDataFromScene")
    rtcGetGeometryUserDataFromScene :: proc(scene: RTCScene, geomID: u32) -> rawptr ---

    @(link_name="rtcGetGeometryTransformFromScene")
    rtcGetGeometryTransformFromScene :: proc(scene: RTCScene, geomID: u32, time: f32, format: RTCFormat, xfm: rawptr) ---

    // Traversable API
    @(link_name="rtcGetGeometryUserDataFromTraversable")
    rtcGetGeometryUserDataFromTraversable :: proc(traversable: RTCTraversable, geomID: u32) -> rawptr ---

    @(link_name="rtcGetGeometryTransformFromTraversable")
    rtcGetGeometryTransformFromTraversable :: proc(traversable: RTCTraversable, geomID: u32, time: f32, format: RTCFormat, xfm: rawptr) ---

    @(link_name="rtcTraversablePointQuery")
    rtcTraversablePointQuery :: proc(traversable: RTCTraversable, query: ^RTCPointQuery, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: rawptr) -> bool ---

    @(link_name="rtcTraversablePointQuery4")
    rtcTraversablePointQuery4 :: proc(valid: ^c.int, traversable: RTCTraversable, query: ^RTCPointQuery4, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: ^^rawptr) -> bool ---

    @(link_name="rtcTraversablePointQuery8")
    rtcTraversablePointQuery8 :: proc(valid: ^c.int, traversable: RTCTraversable, query: ^RTCPointQuery8, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: ^^rawptr) -> bool ---

    @(link_name="rtcTraversablePointQuery16")
    rtcTraversablePointQuery16 :: proc(valid: ^c.int, traversable: RTCTraversable, query: ^RTCPointQuery16, ctx: ^RTCPointQueryContext, queryFunc: RTCPointQueryFunction, userPtr: ^^rawptr) -> bool ---

    @(link_name="rtcTraversableIntersect1")
    rtcTraversableIntersect1 :: proc(traversable: RTCTraversable, rayhit: ^RTCRayHit, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcTraversableIntersect4")
    rtcTraversableIntersect4 :: proc(valid: ^c.int, traversable: RTCTraversable, rayhit: ^RTCRayHit4, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcTraversableIntersect8")
    rtcTraversableIntersect8 :: proc(valid: ^c.int, traversable: RTCTraversable, rayhit: ^RTCRayHit8, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcTraversableIntersect16")
    rtcTraversableIntersect16 :: proc(valid: ^c.int, traversable: RTCTraversable, rayhit: ^RTCRayHit16, args: ^RTCIntersectArguments = nil) ---

    @(link_name="rtcTraversableForwardIntersect1")
    rtcTraversableForwardIntersect1 :: proc(args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay, instID: u32) ---

    @(link_name="rtcTraversableForwardIntersect1Ex")
    rtcTraversableForwardIntersect1Ex :: proc(args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableForwardIntersect4")
    rtcTraversableForwardIntersect4 :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay4, instID: u32) ---

    @(link_name="rtcTraversableForwardIntersect4Ex")
    rtcTraversableForwardIntersect4Ex :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay4, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableForwardIntersect8")
    rtcTraversableForwardIntersect8 :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay8, instID: u32) ---

    @(link_name="rtcTraversableForwardIntersect8Ex")
    rtcTraversableForwardIntersect8Ex :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay8, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableForwardIntersect16")
    rtcTraversableForwardIntersect16 :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay16, instID: u32) ---

    @(link_name="rtcTraversableForwardIntersect16Ex")
    rtcTraversableForwardIntersect16Ex :: proc(valid: ^c.int, args: ^RTCIntersectFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay16, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableOccluded1")
    rtcTraversableOccluded1 :: proc(traversable: RTCTraversable, ray: ^RTCRay, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcTraversableOccluded4")
    rtcTraversableOccluded4 :: proc(valid: ^c.int, traversable: RTCTraversable, ray: ^RTCRay4, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcTraversableOccluded8")
    rtcTraversableOccluded8 :: proc(valid: ^c.int, traversable: RTCTraversable, ray: ^RTCRay8, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcTraversableOccluded16")
    rtcTraversableOccluded16 :: proc(valid: ^c.int, traversable: RTCTraversable, ray: ^RTCRay16, args: ^RTCOccludedArguments = nil) ---

    @(link_name="rtcTraversableForwardOccluded1")
    rtcTraversableForwardOccluded1 :: proc(args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay, instID: u32) ---

    @(link_name="rtcTraversableForwardOccluded1Ex")
    rtcTraversableForwardOccluded1Ex :: proc(args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableForwardOccluded4")
    rtcTraversableForwardOccluded4 :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay4, instID: u32) ---

    @(link_name="rtcTraversableForwardOccluded4Ex")
    rtcTraversableForwardOccluded4Ex :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay4, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableForwardOccluded8")
    rtcTraversableForwardOccluded8 :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay8, instID: u32) ---

    @(link_name="rtcTraversableForwardOccluded8Ex")
    rtcTraversableForwardOccluded8Ex :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay8, instID: u32, instPrimID: u32) ---

    @(link_name="rtcTraversableForwardOccluded16")
    rtcTraversableForwardOccluded16 :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay16, instID: u32) ---

    @(link_name="rtcTraversableForwardOccluded16Ex")
    rtcTraversableForwardOccluded16Ex :: proc(valid: ^c.int, args: ^RTCOccludedFunctionNArguments, traversable: RTCTraversable, ray: ^RTCRay16, instID: u32, instPrimID: u32) ---
}

RTCFilterFunctionN :: #type proc "c" (args: ^RTCFilterFunctionNArguments)
RTCIntersectFunctionN :: #type proc "c" (args: rawptr) // ^RTCIntersectFunctionNArguments
RTCOccludedFunctionN :: #type proc "c" (args: rawptr) // ^RTCOccludedFunctionNArguments
RTCPointQueryFunction :: #type proc "c" (args: ^RTCPointQueryFunctionArguments) -> bool

rtcInitRayQueryContext :: proc "c" (ctx: ^RTCRayQueryContext) {
    for l in 0..<RTC_MAX_INSTANCE_LEVEL_COUNT {
        ctx.instID[l] = RTC_INVALID_GEOMETRY_ID
        ctx.instPrimID[l] = RTC_INVALID_GEOMETRY_ID
    }
}

rtcInitPointQueryContext :: proc "c" (ctx: ^RTCPointQueryContext) {
    ctx.instStackSize = 0
    for l in 0..<RTC_MAX_INSTANCE_LEVEL_COUNT {
        ctx.instID[l] = RTC_INVALID_GEOMETRY_ID
        ctx.instPrimID[l] = RTC_INVALID_GEOMETRY_ID
    }
}

rtcInitQuaternionDecomposition :: proc(qd: ^RTCQuaternionDecomposition) {
    qd.scale_x = 1.0
    qd.scale_y = 1.0
    qd.scale_z = 1.0
    qd.skew_xy = 0.0
    qd.skew_xz = 0.0
    qd.skew_yz = 0.0
    qd.shift_x = 0.0
    qd.shift_y = 0.0
    qd.shift_z = 0.0
    qd.quaternion_r = 1.0
    qd.quaternion_i = 0.0
    qd.quaternion_j = 0.0
    qd.quaternion_k = 0.0
    qd.translation_x = 0.0
    qd.translation_y = 0.0
    qd.translation_z = 0.0
}

rtcQuaternionDecompositionSetQuaternion :: proc(qd: ^RTCQuaternionDecomposition, r, i, j, k: f32) {
    qd.quaternion_r = r
    qd.quaternion_i = i
    qd.quaternion_j = j
    qd.quaternion_k = k
}

rtcQuaternionDecompositionSetScale :: proc(qd: ^RTCQuaternionDecomposition, scale_x, scale_y, scale_z: f32) {
    qd.scale_x = scale_x
    qd.scale_y = scale_y
    qd.scale_z = scale_z
}

rtcQuaternionDecompositionSetSkew :: proc(qd: ^RTCQuaternionDecomposition, skew_xy, skew_xz, skew_yz: f32) {
    qd.skew_xy = skew_xy
    qd.skew_xz = skew_xz
    qd.skew_yz = skew_yz
}

rtcQuaternionDecompositionSetShift :: proc(qd: ^RTCQuaternionDecomposition, shift_x, shift_y, shift_z: f32) {
    qd.shift_x = shift_x
    qd.shift_y = shift_y
    qd.shift_z = shift_z
}

rtcQuaternionDecompositionSetTranslation :: proc(qd: ^RTCQuaternionDecomposition, translation_x, translation_y, translation_z: f32) {
    qd.translation_x = translation_x
    qd.translation_y = translation_y
    qd.translation_z = translation_z
}