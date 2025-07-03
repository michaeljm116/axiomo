package resource
import math "core:math/linalg"

vec4i :: [4]i32
quat :: math.Quaternionf32
vec3 :: math.Vector3f32
vec4 :: math.Vector4f32
mat4 :: math.Matrix4f32


// Helper types for vectors/matrices
vec2f :: [2]f32
vec3f :: [3]f32
mat4f :: [4][4]f32

Vertex :: struct{
    pos : vec3,
    norm : vec3,
    uv : [2]f32
}
Shape :: struct{
    name : string,
    type : i32,
    center : vec3,
    extents :vec3
}
Mesh :: struct{
    verts : [dynamic]Vertex,
    faces : [dynamic]vec4i,
    center : vec3,
    extents : vec3,
    name : string,
    mat : Material,
    mat_id : i32,
    mesh_id : i32
}

Model :: struct{
    name : string,
    meshes : [dynamic]Mesh,
    shapes : [dynamic]Shape,
    bvhs : [dynamic]BVHNode,
    center : vec3,
    extents : vec3,
    unique_id : i32,
    skeleton_id : i32,
    triangular : bool
}

Material :: struct{
    diffuse : vec3,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32,
    unique_id : i32,
    texture : string,
    name : string
}

Controller :: struct {
    buttons : [16]i8,
    axis : [6]f32
}

Config :: struct {
    num_controller_configs : i8,
    controller_configs : [dynamic]f32
}

Pose :: struct{
   name : string,
   pose : [dynamic]PoseSqt, // Changed from tuple[int, Sqt]
}

PoseList :: struct{
    name : string,
    poses : [dynamic]Pose,
    hash_val : i32
}

Sqt :: struct
{
    rot : quat,
    pos : vec4,
    sca : vec4
}

PoseSqt :: struct {
    id: i32,
    sqt_data: Sqt,
}
BVHNode :: struct {
    upper: vec3,
    offset: i32,
    lower: vec3,
    numChildren: i32,
}