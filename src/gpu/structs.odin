/*
    These are data structues that go into the GPU
    The structures must be laid out in a particular way
*/
package gpu
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


Gui :: struct {
    min:        vec2f,
    extents:    vec2f,
    align_min:  vec2f,
    align_ext:  vec2f,
    layer:      i32,
    id:         i32,
    pad:        i32,
    alpha:      f32,
}

Primitive :: struct {
    world:      mat4f,
    extents:    vec3f,
    num_children: i32,
    id:         i32,
    mat_id:     i32,
    start_index: i32,
    end_index:   i32,
}

Vert :: struct {
    pos:    vec3f,
    u:      f32,
    norm:   vec3f,
    v:      f32,
}

TriangleIndex :: struct {
    v:      [3]i32,
    id:     i32,
}

Index :: struct {
    v:      [4]i32,
}

Shape :: struct {
    center:     vec3f,
    mat_id:     i32,
    extents:    vec3f,
    type:       i32,
}

Light :: struct {
    pos:        vec3f,
    intensity:  f32,
    color:      vec3f,
    id:         i32,
}

Material :: struct {
    diffuse : vec3,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32
}

BvhNode :: struct {
    upper: vec3,
    offset: i32,
    lower: vec3,
    num_children: i32,
}