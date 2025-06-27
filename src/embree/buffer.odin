package embree

import "core:c"

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

foreign import embree "lib/embree4.lib"
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
}