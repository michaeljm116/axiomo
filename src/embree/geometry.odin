package embree

import "core:c"

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

// Foreign function declarations (prototypes only, no implementation)
foreign import embree "lib/embree4.lib"
foreign embree {
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
}