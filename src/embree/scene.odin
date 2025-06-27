package embree

import "core:c"

// Opaque types
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

// Foreign function declarations
foreign import embree "lib/embree4.lib"
foreign embree {
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
