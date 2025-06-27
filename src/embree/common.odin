package embree

import "core:c"

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