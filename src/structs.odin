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

//----------------------------------------------------------------------------\\
// /Structs /st
//----------------------------------------------------------------------------\\
Shape :: struct
{
    name : string,
    type : int,
    center : math.Vector3f32,
    extents : math.Vector3f32
}

Vertex :: struct{
    pos : math.Vector3f32,
    norm : math.Vector3f32,
    uv : [2]f32
}

rVertex :: struct{
    pos : math.Vector3f32,
    norm : math.Vector3f32,
    uv : [2]f32
}

Material :: struct{
    diffuse : math.Vector3f32,
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
    diffuse : math.Vector3f32,
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
    diffuse : math.Vector3f32,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32
}
Vector4i32 :: [4]i32

//Note: Possible need for BVH Nodes
Mesh :: struct{
    verts : [dynamic]Vertex,
    faces : [dynamic]Vector4i32,
    center : math.Vector3f32,
    extents : math.Vector3f32,
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
    center : math.Vector3f32,
    extents : math.Vector3f32,
    unique_id : i32,
    skeleton_id : i32,
    triangular : bool
}

Sqt :: struct
{
    rot : math.Quaternionf32,
    pos : math.Vector4f32,
    sca : math.Vector4f32
}

BVHNode :: struct {
    upper: math.Vector3f32,
    offset: i32,
    lower: math.Vector3f32,
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


//----------------------------------------------------------------------------\\
// /BVH
//----------------------------------------------------------------------------\\

ssBVHNode :: struct {
    upper : math.Vector3f32,
    offset : i32,
    lower : math.Vector3f32,
    numChildren : i32
}

BVHBounds :: struct {
    upper : math.Vector3f32,
    lower : math.Vector3f32
}
