package embree

// Quaternion decomposition struct (16 floats, 16-byte aligned)
RTCQuaternionDecomposition :: struct #align(16) {
    scale_x, scale_y, scale_z: f32,
    skew_xy, skew_xz, skew_yz: f32,
    shift_x, shift_y, shift_z: f32,
    quaternion_r, quaternion_i, quaternion_j, quaternion_k: f32,
    translation_x, translation_y, translation_z: f32,
}

// Initialization helpers (optional, for user convenience)
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
