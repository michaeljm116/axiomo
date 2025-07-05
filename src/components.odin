package main
import "core:fmt"
import math "core:math/linalg"
import "external/ecs"
import "core:hash/xxhash"
import "core:strings"
import res "resource"
import sdl "vendor:sdl2"
import sdl_mixer "vendor:sdl2/mixer"

//components
// ✅bvh
// ✅light
// ✅camera
// ✅material
// ✅render
// ✅animation
// ✅transform
// ✅node
// debug
// prefab???
// script - maybe
// physics
//  - collision
//  - dynamic
//  - immovoable
//  - physics
//  - static
// audio

Sqt :: struct
{
    rot : quat,
    pos : vec4,
    sca : vec4
}

Cmp_Transform :: struct {
    world: mat4,           // translation rotation scale matrix
    trm: mat4,             // Translation+Rotation Matrix, scale is left separate
    local: Sqt,             // local transform
    global: Sqt,            // global transform
    euler_rotation: vec3,   // euler angles for rotation
}

ComponentFlag :: enum {
    NODE        = 0,
    TRANSFORM   = 1,
    MATERIAL    = 2,
    LIGHT       = 3,
    CAMERA      = 4,
    MODEL       = 5,
    MESH        = 6,
    BOX         = 7,
    SPHERE      = 8,
    PLANE       = 9,
    AABB        = 10,
    CYLINDER    = 11,
    SKINNED     = 12,
    RIGIDBODY   = 13,
    CCONTROLLER = 14,
    PRIMITIVE   = 15,
    COLIDER     = 16,
    IMPULSE     = 17,
    GUI         = 18,
    BUTTON      = 19,
    JOINT       = 20,
    HEADNODE    = 21,
    PREFAB      = 22,
}
ComponentFlags :: bit_set[ComponentFlag; u32]

ObjectType :: enum i32 {
    SPHERE = 1,
    BOX = 2,
    CYLINDER = 3,
    PLANE = 4,
    DISK = 5,
    QUAD = 6,
    CONE = 7,
}

Cmp_Node :: struct {
    entity: Entity,                       // The entity this node represents
    parent: Entity,                       // Parent entity (0 means no parent)
    children: [dynamic]^Cmp_Node,            // Dynamic array of child entities
    name: string,                           // Node name
    clicked: bool,                          // UI interaction state
    is_dynamic: bool,                       // Dynamic object flag
    is_parent: bool,                        // Has children flag
    is_head: bool,                          // Is head node flag
    needs_delete: bool,                     // Marked for deletion
    culled: bool,                           // Culling state
    engine_flags: ComponentFlags,            // Engine component flags
    game_flags: i64,                        // Game-specific flags
}

Cmp_HeadNode :: struct {
    // Empty component marker for head nodes
}

RenderType :: enum {
    MATERIAL = 0,
    PRIMITIVE = 1,
    LIGHT = 2,
    GUI = 3,
    GUINUM = 4,
    CAMERA = 5
}

RenderTypes :: bit_set[RenderType; u8]

Cmp_Mesh :: struct {
    mesh_index: i32,
    mesh_model_id: i32,
    mesh_resource_index: i32,
    unique_id: i32,
}

Cmp_Primitive :: struct {
    world: mat4,
    extents: vec3,
    aabb_extents: vec3,
    num_children: i32,
    id: i32,
    mat_id: i32,
    start_index: i32,
    end_index: i32,
}

Cmp_Model :: struct {
    model_index: i32,
    model_unique_id: i32,
}

SelectableState :: enum {
    UNSELECTED,
    RELEASED,
    HELD,
    PRESSED,
}

Cmp_Selectable :: struct {
    state: SelectableState,
    active: bool,
    reset: bool,
}

Cmp_Gui :: struct {
    min: vec2f,
    extents: vec2f,
    align_min: vec2f,
    align_ext: vec2f,
    layer: i32,
    id: i32,
    ref: i32,
    alpha: f32,
    update: bool,
}

Cmp_GuiNumber :: struct {
    using gui: Cmp_Gui,  // Inheritance-like behavior
    number: i32,
    highest_active_digit_index: i32,
    shader_references: [dynamic]i32,
}

RenderVertex :: struct {
    pos: vec3,
    norm: vec3,
    tang: vec3,
    uv: vec2f,
}

Cmp_Material :: struct {
    mat_id: i32,
    mat_unique_id: i32,
}

Cmp_Light :: struct {
    color: vec3,
    intensity: f32,
    id: i32,
}

CameraType :: enum {
    LOOKAT,
    FIRSTPERSON,
}

CameraMatrices :: struct {
    perspective: mat4,
    view: mat4,
}

Cmp_Camera :: struct {
    aspect_ratio: f32,
    fov: f32,
    rot_matrix: mat4,
}

Camera :: struct {
    // Public fields
    fov: f32,
    type: CameraType,
    rotation: vec3,
    position: vec3,
    rotation_speed: f32,
    movement_speed: f32,
    aspect: f32,
    matrices: CameraMatrices,

    // Private fields (were private in C++)
    znear: f32,
    zfar: f32,
}

BvhBounds :: struct {
    lower: vec3,
    _pad: i32,
    upper: vec3,
    _pad2: i32,
}

// Base BVH node interface using Odin's union
BvhNode :: union {
    ^InnerBvhNode,
    ^LeafBvhNode,
}

InnerBvhNode :: struct {
    bounds: [2]BvhBounds,
    children: [2]BvhNode,
}

LeafBvhNode :: struct {
    id: u32,
    bounds: BvhBounds,
}

// Animation flags - 4 bytes with bitfields
AnimFlags :: bit_field u16{
   idPo         : u8   | 8,
   loop         : bool | 1,
   force_start  : bool | 1,
   force_end    : bool | 1,
   pos_flag     : bool | 1,
   rot_flag     : bool | 1,
   sca_flag     : bool | 1,
   start_set    : bool | 1,
   end_set      : bool | 1
}

// Breadth-First Graph Component
Cmp_BFGraph :: struct {
    nodes: [dynamic]Entity,  // Using entity IDs instead of pointers
    transforms: [dynamic]Sqt,
}

Cmp_Pose :: struct {
    pose: [dynamic]res.PoseSqt,
    file_name: string,
    pose_name: string,
}

// Animation State
AnimationState :: enum {
    DEFAULT,
    TRANSITION,
    TRANSITION_TO_START,
    START,
    TRANSITION_TO_END,
    END,
}

// Animation Component
Cmp_Animation :: struct {
    num_poses: i32,
    flags: AnimFlags,
    time: f32,
    start: u32,
    end: u32,
    prefab_name: u32,
    trans_timer: f32,
    trans_time: f32,
    trans: i32,
    trans_end: i32,
    state: AnimationState,
}

Cmp_Animate :: struct {
    curr_time: f32,
    time: f32,
    flags: AnimFlags,
    start: Sqt,
    end: Sqt,
    parent_entity: Entity,  // Reference to parent animation entity
}

// Constants
ANIM_FLAG_RESET :: 0b11111111111000000000000000000000

Cmp_Debug :: struct {
    type: string,
    message: string,
}

// Audio type enumeration
AudioType :: enum {
    SOUND_EFFECT,
    MUSIC,
}

Cmp_Audio :: struct {
    play: bool,
    chunk: ^sdl_mixer.Chunk,  // SDL2 mixer chunk
    file_name: string,
    channel: i32,  // SDL mixer channel for this audio
}
