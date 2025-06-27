package embree

import "core:c"

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

foreign import embree "lib/embree4.lib"
foreign import tbb "lib/tbb12.lib"
foreign embree{
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
}
