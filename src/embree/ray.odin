package embree

import "core:c"

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
