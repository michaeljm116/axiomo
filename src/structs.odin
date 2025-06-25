package main
import math "core:math/linalg"
import "core:strings"
import "core:log"
import "core:os"
import "core:io"
import "core:fmt"
import "core:encoding/csv"
import "core:bytes"
import "core:bufio"
import "core:encoding/ini"
import "core:encoding/xml"
import "core:mem"
import vk "vendor:vulkan"
import "vma"

vec4i :: [4]i32
quat :: math.Quaternionf32
vec3 :: math.Vector3f32
vec4 :: math.Vector4f32
//----------------------------------------------------------------------------\\
// /Structs /st
//----------------------------------------------------------------------------\\
Shape :: struct
{
    name : string,
    type : i32,
    center : vec3,
    extents :vec3
}

Vertex :: struct{
    pos : vec3,
    norm : vec3,
    uv : [2]f32
}

rVertex :: struct{
    pos : vec3,
    norm : vec3,
    uv : [2]f32
}

AMaterial :: struct{
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

rMaterial :: struct {
    diffuse : vec3,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32,
    unique_id : i32,
    texture : string,
    name : string,
    rendered_mat : ^ssMaterial
}

ssMaterial :: struct {
    diffuse : vec3,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32
}

//Note: Possible need for BVH Nodes
Mesh :: struct{
    verts : [dynamic]Vertex,
    faces : [dynamic]vec4i,
    center : vec3,
    extents : vec3,
    name : string,
    mat : AMaterial,
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

Sqt :: struct
{
    rot : quat,
    pos : vec4,
    sca : vec4
}

BVHNode :: struct {
    upper: vec3,
    offset: i32,
    lower: vec3,
    numChildren: i32,
}

rController :: struct {
    buttons : [16]i8,
    axis : [6]f32
}

rConfig :: struct {
    num_controller_configs : i8,
    controller_configs : [dynamic]f32
}

PoseSqt :: struct {
    id: i32,
    sqt_data: Sqt,
}

rPose :: struct{
   name : string,
   pose : [dynamic]PoseSqt, // Changed from tuple[int, Sqt]
}

rPoseList :: struct{
    name : string,
    poses : [dynamic]rPose,
    hash_val : i32
}

//----------------------------------------------------------------------------\\
// /BVH
//----------------------------------------------------------------------------\\

ssBVHNode :: struct {
    upper : vec3,
    offset : i32,
    lower : vec3,
    numChildren : i32
}

BVHBounds :: struct {
    upper : vec3,
    lower :vec3
}

// Helper types for vectors/matrices
vec2f :: [2]f32
vec3f :: [3]f32
mat4f :: [4][4]f32

ssGUI :: struct {
    min:        vec2f,
    extents:    vec2f,
    align_min:  vec2f,
    align_ext:  vec2f,
    layer:      int,
    id:         int,
    pad:        int,
    alpha:      f32,
}

ssPrimitive :: struct {
    world:      mat4f,
    extents:    vec3f,
    num_children: int,
    id:         int,
    mat_id:     int,
    start_index: int,
    end_index:   int,
}

ssVert :: struct {
    pos:    vec3f,
    u:      f32,
    norm:   vec3f,
    v:      f32,
}

ssTriangleIndex :: struct {
    v:      [3]int,
    id:     int,
}

ssIndex :: struct {
    v:      [4]int,
}

ssShape :: struct {
    center:     vec3f,
    mat_id:     int,
    extents:    vec3f,
    type:       int,
}

ssLight :: struct {
    pos:        vec3f,
    intensity:  f32,
    color:      vec3f,
    id:         int,
}
