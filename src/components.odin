package main
import "core:fmt"
import "core:math/linalg"
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
    ROOT        = 21,
    PREFAB      = 22,
}
ComponentFlags :: bit_set[ComponentFlag; u32]

EngineFlags :: union
{
    ComponentFlags,
    u32,
}

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
    entity: Entity,                         // The entity this node represents
    parent: Entity,                         // Parent entity (0 means no parent)
    child: Entity,                          // First child entity
    brotha: Entity,                         // Next Brother Entity
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

Cmp_Root :: struct {
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

RendererType :: enum{
    ComputeRaytracer,
    HardwareRaytracer,
    ComputeRasterizer,
    HardwareRasterizer
}

Cmp_Render :: struct{
    type : RenderTypes,
    renderer : RendererType
}

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

BvhNodeKind :: enum {
    Inner,
    Leaf,
}

InnerBvhNode :: struct {
    kind: BvhNodeKind,     // FIRST FIELD for safe peeking from rawptr
    bounds: [2]BvhBounds,
    children: [2]BvhNode,  // BvhNode will be rawptr
}

LeafBvhNode :: struct {
    kind: BvhNodeKind,     // FIRST FIELD for safe peeking from rawptr
    id: u32,
    bounds: BvhBounds,
}

BvhNode :: rawptr  // Unified raw pointer for tree traversal

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

//----------------------------------------------------------------------------\\
// /PROCS
//----------------------------------------------------------------------------\\

sqt_is_equal :: proc(a: Sqt, b: Sqt) -> bool {
    pos_equal := a.pos == b.pos
    rot_equal := a.rot == b.rot
    sca_equal := a.sca == b.sca
    return pos_equal && rot_equal && sca_equal
}

move_2d_xz :: proc(rot: quat) -> [2]f32 {
    // Extract yaw from quaternion (rotation around Y-axis)
    yaw := linalg.atan2(2.0 * (rot.w * rot.y + rot.x * rot.z), 1.0 - 2.0 * (rot.y * rot.y + rot.z * rot.z))
    return {linalg.cos(yaw), linalg.sin(yaw)}
}

// Full constructor equivalent
cmp_transform_prs :: proc(pos: vec3, rot: vec3, sca: vec3) -> Cmp_Transform {
    tc := Cmp_Transform{}
    tc.euler_rotation = rot

    // Combine rotations (order: X, Y, Z)
    rotation_matrix := linalg.matrix4_from_euler_angles_xyz_f32(rot.x, rot.y, rot.z)

    // Convert rotation matrix to quaternion
    tc.local.rot = linalg.quaternion_from_matrix4_f32(rotation_matrix)
    tc.local.pos = {pos.x, pos.y, pos.z, 0.0}
    tc.local.sca = {sca.x, sca.y, sca.z, 0.0}

    // Set up world matrix
    tc.world = rotation_matrix
    tc.world[3] = {pos.x, pos.y, pos.z, 1.0}  // Set translation

    // TRM is the same as world matrix in this case
    tc.trm = rotation_matrix

    return tc
}

cmp_transform_prs_q :: proc(pos: vec3, rot: vec4, sca: vec3) -> Cmp_Transform {
    tc := Cmp_Transform{}
    // Combine rotations (order: X, Y, Z)
    // linalg.matrix4_from_euler_angles_xyz_f32(rot.x, rot.y, rot.z)

    // Convert rotation matrix to quaternion
    tc.local.rot = transmute(quat)rot // linalg.quaternion_from_matrix4_f32(rotation_matrix)
    tc.local.pos = {pos.x, pos.y, pos.z, 0.0}
    tc.local.sca = {sca.x, sca.y, sca.z, 0.0}
    rotation_matrix := linalg.matrix4_from_quaternion_f32(tc.local.rot)
    // Set up world matrix
    tc.world = rotation_matrix
    tc.world[3] = {pos.x, pos.y, pos.z, 1.0}  // Set translation

    // TRM is the same as world matrix in this case
    tc.trm = rotation_matrix

    return tc
}

node_component_default :: proc(entity: Entity) -> Cmp_Node {
    nc := Cmp_Node{}
    nc.entity = entity
    nc.parent = Entity(0)  // 0 means no parent
    nc.brotha = Entity(0)
    nc.child = Entity(0)
    nc.engine_flags = {ComponentFlag.NODE}
    return nc
}

node_component_with_parent :: proc(entity: Entity, parent_entity: Entity) -> Cmp_Node {
    nc := Cmp_Node{}
    nc.entity = entity
    nc.parent = parent_entity
    nc.child = Entity(0)
    nc.engine_flags = {ComponentFlag.NODE}
    return nc
}

node_component_named :: proc(entity: Entity, node_name: string, flags: ComponentFlag) -> Cmp_Node {
    nc := Cmp_Node{}
    nc.entity = entity
    nc.name = node_name
    nc.engine_flags = {ComponentFlag.NODE + flags}  // Combine flags
    nc.parent = Entity(0)  // 0 means no parent
    nc.child = Entity(0)
    return nc
}

// Utility procedures for node hierarchy management using the ECS
add_child :: proc(parent_entity, child_entity: Entity) {
    parent_node := get_component(parent_entity, Cmp_Node)
    child_node := get_component(child_entity, Cmp_Node)
    if (parent_node == nil || child_node == nil) do return

    parent_node.is_parent = true
    child_node.parent = parent_entity
    if (parent_node.child == 0){
        parent_node.child = child_entity
    }
    else{
       first_child := get_component(parent_node.child, Cmp_Node)
        last_bro := get_last_sibling(first_child)
       last_bro.brotha = child_entity
    }
}

get_last_sibling :: proc(node : ^Cmp_Node) -> ^Cmp_Node{
    last_bro := node
    next_bro := node.brotha
    for next_bro != Entity(0){
        last_bro = get_component(next_bro, Cmp_Node)
        next_bro = last_bro.brotha
    }
    return last_bro
}

remove_child :: proc(parent_entity: Entity, child_entity: Entity) {
    parent_node := get_component(parent_entity, Cmp_Node)
    if parent_node == nil {
        return
    }

    child_node := get_component(child_entity, Cmp_Node)
    if child_node == nil {
        return
    }

    // Check if this is the first child
    if parent_node.child == child_entity {
        // Update parent's first child to the next sibling
        parent_node.child = child_node.brotha
    } else {
        // Find the previous sibling
        curr := parent_node.child
        for curr != Entity(0) {
            curr_node := get_component(curr, Cmp_Node)
            if curr_node.brotha == child_entity {
                // Remove from linked list by updating previous sibling's brotha
                curr_node.brotha = child_node.brotha
                break
            }
            curr = curr_node.brotha
        }
    }

    // Update parent flag if no more children
    if parent_node.child == Entity(0) {
        parent_node.is_parent = false
    }

    // Clear child's parent and sibling references
    child_node.parent = Entity(0)
    child_node.brotha = Entity(0)
}

get_parent :: proc(world: ^ecs.World, entity: Entity) -> Entity {
    node := get_component(entity, Cmp_Node)
    if node == nil {
        return Entity(0)
    }
    return node.parent
}

get_children :: proc(world: ^ecs.World, entity: Entity) -> []Entity {
    node := get_component(entity, Cmp_Node)
    if node == nil {
        return nil
    }

    // Build array from linked list
    context.allocator = context.temp_allocator
    children := make([dynamic]Entity)
    curr := node.child
    for curr != Entity(0) {
        append(&children, curr)
        curr_node := get_component(curr, Cmp_Node)
        if curr_node != nil {
            curr = curr_node.brotha
        } else {
            break
        }
    }
    return children[:]
}


has_flag :: proc(component: Cmp_Node, flag: ComponentFlag) -> bool {
    return flag in component.engine_flags
}

check_any :: proc(component: Cmp_Node, flags: ComponentFlags) -> bool {
    return (transmute(u32)(component.engine_flags ~ flags) > 0)
}

// Utility to create a hierarchical entity withCmp_Node
create_node_entity :: proc(world: ^ecs.World, name: string, flags: ComponentFlag, parent: Entity = Entity(0)) -> Entity {
    entity := ecs.add_entity(world)
    node_comp := parent == Entity(0) ? node_component_named(entity, name, flags) : node_component_with_parent(entity, parent)
    node_comp.name = name
    node_comp.engine_flags += {flags}

    ecs.add_component(world, entity, node_comp)

    // If this entity has a parent, add it to the parent's children
    if parent != Entity(0) {
        add_child(parent, entity)
    }

    return entity
}

// Query helper to find all entities withCmp_Node
query_nodes :: proc(world: ^ecs.World) -> []^ecs.Archetype {
    return ecs.query(world, ecs.has(Cmp_Node))
}

// Query helper to find all head nodes
query_head_nodes :: proc(world: ^ecs.World) -> []^ecs.Archetype {
    return ecs.query(world, ecs.has(Cmp_Node), ecs.has(Cmp_Root))
}

mesh_component_default :: proc() -> Cmp_Mesh {
    return Cmp_Mesh{}
}

mesh_component_with_index :: proc(index: i32) -> Cmp_Mesh {
    return Cmp_Mesh{
        mesh_index = index,
    }
}

mesh_component_with_ids :: proc(model_id: i32, resource_index: i32) -> Cmp_Mesh {
    return Cmp_Mesh{
        mesh_model_id = model_id,
        mesh_resource_index = resource_index,
    }
}

primitive_component_default :: proc() -> Cmp_Primitive {
    return Cmp_Primitive{
        world = linalg.MATRIX4F32_IDENTITY,
    }
}

primitive_component_with_id :: proc(component_id: i32) -> Cmp_Primitive {
    return Cmp_Primitive{
        world = linalg.MATRIX4F32_IDENTITY,
        id = component_id,
    }
}

primitive_get_center :: proc(primitive: Cmp_Primitive) -> vec3 {
    return {primitive.world[3].x, primitive.world[3].y, primitive.world[3].z}
}

model_component_default :: proc() -> Cmp_Model {
    return Cmp_Model{}
}

model_component_with_unique_id :: proc(unique_id: i32) -> Cmp_Model {
    return Cmp_Model{
        model_unique_id = unique_id,
    }
}

model_component_with_ids :: proc(index: i32, unique_id: i32) -> Cmp_Model {
    return Cmp_Model{
        model_index = index,
        model_unique_id = unique_id,
    }
}

selectable_component_default :: proc() -> Cmp_Selectable {
    return Cmp_Selectable{
        state = .UNSELECTED,
        active = false,
        reset = false,
    }
}

gui_component_default :: proc() -> Cmp_Gui {
    return Cmp_Gui{
        update = true,
    }
}

gui_component_full :: proc(
    min: vec2f,
    extents: vec2f,
    align_min: vec2f,
    align_ext: vec2f,
    layer: i32,
    id: i32,
    alpha: f32
) -> Cmp_Gui {
    return Cmp_Gui{
        min = min,
        extents = extents,
        align_min = align_min,
        align_ext = align_ext,
        layer = layer,
        id = id,
        alpha = alpha,
        update = true,
    }
}

gui_number_component_default :: proc() -> Cmp_GuiNumber {
    return Cmp_GuiNumber{
        gui = gui_component_default(),
        shader_references = make([dynamic]i32),
    }
}

gui_number_component_simple :: proc(min: vec2f, extents: vec2f, number: i32) -> Cmp_GuiNumber {
    return Cmp_GuiNumber{
        gui = gui_component_full(min, extents, {0.0, 0.0}, {0.1, 1.0}, 0, 0, 0.0),
        number = number,
        shader_references = make([dynamic]i32),
    }
}

gui_number_component_with_alpha :: proc(min: vec2f, extents: vec2f, number: i32, alpha: f32) -> Cmp_GuiNumber {
    return Cmp_GuiNumber{
        gui = gui_component_full(min, extents, {0.0, 0.0}, {0.1, 1.0}, 0, 0, alpha),
        number = number,
        shader_references = make([dynamic]i32),
    }
}

// Constructor procedures with overloading
mesh_component :: proc{
    mesh_component_default,
    mesh_component_with_index,
    mesh_component_with_ids,
}

primitive_component :: proc{
    primitive_component_default,
    primitive_component_with_id,
}

model_component :: proc{
    model_component_default,
    model_component_with_unique_id,
    model_component_with_ids,
}

gui_component :: proc{
    gui_component_default,
    gui_component_full,
}

gui_number_component :: proc{
    gui_number_component_default,
    gui_number_component_simple,
    gui_number_component_with_alpha,
}

material_component_default :: proc() -> Cmp_Material {
    return Cmp_Material{}
}

material_component_with_id :: proc(id: i32) -> Cmp_Material {
    return Cmp_Material{
        mat_id = id,
    }
}

material_component_with_ids :: proc(id: i32, unique_id: i32) -> Cmp_Material {
    return Cmp_Material{
        mat_id = id,
        mat_unique_id = unique_id,
    }
}

// Constructor overloading
material_component :: proc{
    material_component_default,
    material_component_with_id,
    material_component_with_ids,
}

light_component_default :: proc() -> Cmp_Light {
    return Cmp_Light{
        color = {0, 0, 0},
        intensity = 0.0,
        id = 0,
    }
}

light_component_full :: proc(color: vec3, intensity: f32, id: i32) -> Cmp_Light {
    return Cmp_Light{
        color = color,
        intensity = intensity,
        id = id,
    }
}

// Constructor overloading
light_component :: proc{
    light_component_default,
    light_component_full,
}

camera_component_default :: proc() -> Cmp_Camera {
    return Cmp_Camera{
        aspect_ratio = 0.0,
        fov = 0.0,
        rot_matrix = linalg.MATRIX4F32_IDENTITY,
    }
}

camera_component_with_params :: proc(aspect_ratio: f32, fov: f32) -> Cmp_Camera {
    return Cmp_Camera{
        aspect_ratio = aspect_ratio,
        fov = fov,
        rot_matrix = linalg.MATRIX4F32_IDENTITY,
    }
}

camera_create :: proc() -> Camera {
    return Camera{
        fov = 0.0,
        type = .LOOKAT,
        //look_type = .LOOK_FROM,
        rotation = {0, 0, 0},
        position = {0, 0, 0},
        rotation_speed = 1.0,
        movement_speed = 1.0,
        aspect = 0.0,
        matrices = CameraMatrices{
            perspective = linalg.MATRIX4F32_IDENTITY,
            view = linalg.MATRIX4F32_IDENTITY,
        },
        znear = 0.0,
        zfar = 1000.0,
    }
}

camera_update_view_matrix :: proc(camera: ^Camera) {
    rot_matrix := linalg.MATRIX4F32_IDENTITY
    trans_matrix := linalg.MATRIX4F32_IDENTITY
    // Apply rotations
    rot_matrix = linalg.matrix4_rotate_f32(linalg.to_radians(camera.rotation.x), vec3{1,0,0}) * rot_matrix
    rot_matrix = linalg.matrix4_rotate_f32(linalg.to_radians(camera.rotation.y), vec3{0,1,0}) * rot_matrix
    rot_matrix = linalg.matrix4_rotate_f32(linalg.to_radians(camera.rotation.z), vec3{0,0,1}) * rot_matrix

    trans_matrix = linalg.matrix4_translate_f32(camera.position)

    switch camera.type {
    case .FIRSTPERSON:
        camera.matrices.view = rot_matrix * trans_matrix
    case .LOOKAT:
        camera.matrices.view = trans_matrix * rot_matrix
    }
}

camera_set_perspective :: proc(camera: ^Camera, fov: f32, aspect: f32, znear: f32, zfar: f32) {
    camera.fov = fov
    camera.znear = znear
    camera.zfar = zfar
    camera.aspect = aspect
    camera.matrices.perspective = linalg.matrix4_perspective_f32(linalg.to_radians(fov), aspect, znear, zfar)
}

camera_update_aspect_ratio :: proc(camera: ^Camera, aspect: f32) {
    camera.aspect = aspect
    camera.matrices.perspective = linalg.matrix4_perspective_f32(linalg.to_radians(camera.fov), aspect, camera.znear, camera.zfar)
}

camera_set_position :: proc(camera: ^Camera, position: vec3) {
    camera.position = position
    camera_update_view_matrix(camera)
}

camera_set_rotation :: proc(camera: ^Camera, rotation: vec3) {
    camera.rotation = rotation
    camera_update_view_matrix(camera)
}

camera_rotate :: proc(camera: ^Camera, delta: vec3) {
    camera.rotation += delta
    camera_update_view_matrix(camera)
}

camera_set_translation :: proc(camera: ^Camera, translation: vec3) {
    camera.position = translation
    camera_update_view_matrix(camera)
}

camera_translate :: proc(camera: ^Camera, delta: vec3) {
    camera.position += delta
    camera_update_view_matrix(camera)
}

camera_moving :: proc(camera: ^Camera) -> bool {
    // Placeholder - you'd implement input checking here
    return false
}

camera_update :: proc(camera: ^Camera, delta_time: f32) {
    if camera.type == .FIRSTPERSON {
        if camera_moving(camera) {
            cam_front: vec3
            cam_front.x = -linalg.cos(linalg.to_radians(camera.rotation.x)) * linalg.sin(linalg.to_radians(camera.rotation.y))
            cam_front.y = linalg.sin(linalg.to_radians(camera.rotation.x))
            cam_front.z = linalg.cos(linalg.to_radians(camera.rotation.x)) * linalg.cos(linalg.to_radians(camera.rotation.y))
            cam_front = linalg.normalize(cam_front)

            move_speed := delta_time * camera.movement_speed

            // You'd implement input checking here and move accordingly
            // if INPUT.up do camera.position += cam_front * move_speed
            // etc.

            camera_update_view_matrix(camera)
        }
    }
}

camera_update_pad :: proc(camera: ^Camera, axis_left: vec2f, axis_right: vec2f, delta_time: f32) -> bool {
    ret_val := false

    if camera.type == .FIRSTPERSON {
        DEAD_ZONE :: 0.0015
        RANGE :: 1.0 - DEAD_ZONE

        cam_front: vec3
        cam_front.x = -linalg.cos(linalg.to_radians(camera.rotation.x)) * linalg.sin(linalg.to_radians(camera.rotation.y))
        cam_front.y = linalg.sin(linalg.to_radians(camera.rotation.x))
        cam_front.z = linalg.cos(linalg.to_radians(camera.rotation.x)) * linalg.cos(linalg.to_radians(camera.rotation.y))
        cam_front = linalg.normalize(cam_front)

        move_speed := delta_time * camera.movement_speed * 2.0
        rot_speed := delta_time * camera.rotation_speed * 50.0

        // Move
        if abs(axis_left.y) > DEAD_ZONE {
            pos := (abs(axis_left.y) - DEAD_ZONE) / RANGE
            sign :f32= axis_left.y < 0.0 ? -1.0 : 1.0
            camera.position -= cam_front * pos * sign * move_speed
            ret_val = true
        }

        if abs(axis_left.x) > DEAD_ZONE {
            pos := (abs(axis_left.x) - DEAD_ZONE) / RANGE
            sign :f32= axis_left.x < 0.0 ? -1.0 : 1.0
            right := linalg.normalize(linalg.cross(cam_front, vec3{0,1,0}))
            camera.position += right * pos * sign * move_speed
            ret_val = true
        }

        // Rotate
        if abs(axis_right.x) > DEAD_ZONE {
            pos := (abs(axis_right.x) - DEAD_ZONE) / RANGE
            sign :f32= axis_right.x < 0.0 ? -1.0 : 1.0
            camera.rotation.y += pos * sign * rot_speed
            ret_val = true
        }

        if abs(axis_right.y) > DEAD_ZONE {
            pos := (abs(axis_right.y) - DEAD_ZONE) / RANGE
            sign :f32= axis_right.y < 0.0 ? -1.0 : 1.0
            camera.rotation.x -= pos * sign * rot_speed
            ret_val = true
        }
    }

    if ret_val {
        camera_update_view_matrix(camera)
    }

    return ret_val
}

// Constructor overloading
camera_component :: proc{
    camera_component_default,
    camera_component_with_params,
}

bvh_bounds_default :: proc() -> BvhBounds {
    return BvhBounds{}
}

bvh_bounds_with_points :: proc(a: vec3, b: vec3) -> BvhBounds {
    return BvhBounds{
        lower = a,
        upper = b,
    }
}

// Helper procedures for BVH operations
bvh_merge :: proc(a, b: BvhBounds) -> BvhBounds {
    return BvhBounds{
        lower = linalg.min(a.lower, b.lower),
        upper = linalg.max(a.upper, b.upper),
    }
}

bvh_is_leaf :: proc(node: BvhNode) -> bool {
    if node == nil { return false }
    kind := (cast(^BvhNodeKind)node)^
    #partial switch kind {
    case .Leaf: return true
    case .Inner: return false
    }
    return false  // Fallback
}

bvh_sah :: proc(node: BvhNode) -> f32 {
    if node == nil { return 0.0 }
    kind := (cast(^BvhNodeKind)node)^
    #partial switch kind {
    case .Inner:
        n := cast(^InnerBvhNode)node
        merged := bvh_merge(n.bounds[0], n.bounds[1])
        area_merged := bvh_area(merged)
        child0_sah := bvh_sah(n.children[0])
        child1_sah := bvh_sah(n.children[1])
        return 1.0 + (bvh_area(n.bounds[0]) * child0_sah + bvh_area(n.bounds[1]) * child1_sah) / area_merged
    case .Leaf:
        return 1.0
    }
    return 0.0  // Fallback
}

bvh_area :: proc(bounds: BvhBounds) -> f32 {
    te := bounds.upper - bounds.lower
    return 2 * bvh_madd(te.x, (te.y + te.z), te.y * te.z)
}

bvh_madd :: proc(a, b, c: f32) -> f32 {
    return a * b + c
}

inner_bvh_node_create :: proc() -> BvhNode {
    node := new(InnerBvhNode)
    node.kind = .Inner
    node.bounds = {}  // Zero-init
    node.children = {nil, nil}
    return cast(BvhNode)node  // Cast to rawptr if needed, but since BvhNode is rawptr, return rawptr(node)
}

leaf_bvh_node_create :: proc(id: u32, bounds: BvhBounds) -> BvhNode {
    node := new(LeafBvhNode)
    node.kind = .Leaf
    node.id = id
    node.bounds = bounds
    return cast(BvhNode)node
}
// Constructor overloading
bvh_bounds :: proc{
    bvh_bounds_default,
    bvh_bounds_with_points,
}

bvh_get_bounds :: proc(node: BvhNode) -> BvhBounds {
    if node == nil { return {} }
    kind := (cast(^BvhNodeKind)node)^
    #partial switch kind {
    case .Inner:
        n := cast(^InnerBvhNode)node
        return bvh_merge(n.bounds[0], n.bounds[1])
    case .Leaf:
        n := cast(^LeafBvhNode)node
        return n.bounds
    }
    return {}
}

bf_graph_component_create :: proc() -> Cmp_BFGraph {
    return Cmp_BFGraph{
        nodes = make([dynamic]Entity),
        transforms = make([dynamic]Sqt),
    }
}

bf_graph_component_destroy :: proc(graph: ^Cmp_BFGraph) {
    delete(graph.nodes)
    delete(graph.transforms)
}

// Flatten function - converts hierarchy to breadth-first order
flatten_hierarchy :: proc(world: ^ecs.World, graph: ^Cmp_BFGraph, head_entity: Entity) {
    clear(&graph.nodes)
    clear(&graph.transforms)

    // Use a queue for breadth-first traversal
    queue: [dynamic]Entity
    defer delete(queue)

    append(&queue, head_entity)

    for len(queue) > 0 {
        current := queue[0]
        ordered_remove(&queue, 0)

        // Get node component to find children
        node_comp := get_component(current, Cmp_Node)
        if node_comp == nil do continue

        // Add children to queue and graph
        curr_child := node_comp.child
        for curr_child != Entity(0) {
            append(&queue, curr_child)
            append(&graph.nodes, curr_child)

            // Get transform component
            transform_comp := get_component(curr_child, Cmp_Transform)
            if transform_comp != nil {
                append(&graph.transforms, transform_comp.local)
            } else {
                // If no transform, use identity
                append(&graph.transforms, Sqt{})
            }

            // Move to next sibling
            child_node := get_component(curr_child, Cmp_Node)
            if child_node != nil {
                curr_child = child_node.brotha
            } else {
                break
            }
        }
    }
}

// Set pose from animation data
set_pose :: proc(world: ^ecs.World, graph: ^Cmp_BFGraph, pose: []res.PoseSqt) {
    for p in pose {
        if p.id >= 0 && p.id < i32(len(graph.nodes)) {
            entity := graph.nodes[p.id]
            transform_comp := get_component(entity, Cmp_Transform)
            if transform_comp != nil {
                transform_comp.local.pos = p.sqt_data.pos
                transform_comp.local.rot = p.sqt_data.rot
                transform_comp.local.sca = p.sqt_data.sca
            }
        }
    }
}

// Reset pose to default
reset_pose :: proc(world: ^ecs.World, graph: ^Cmp_BFGraph) {
    for i in 0..<len(graph.nodes) {
        entity := graph.nodes[i]
        transform_comp := get_component(entity, Cmp_Transform)
        if transform_comp != nil && i < len(graph.transforms) {
            transform_comp.local.pos = graph.transforms[i].pos
            transform_comp.local.rot = graph.transforms[i].rot
            transform_comp.local.sca = graph.transforms[i].sca
        }
    }
}

pose_component_create :: proc(name: string, file: string, pose_data: []res.PoseSqt) -> Cmp_Pose {
    comp := Cmp_Pose{
        pose = make([dynamic]res.PoseSqt),
        file_name = strings.clone(file),
        pose_name = strings.clone(name),
    }

    for p in pose_data {
        append(&comp.pose, p)
    }

    return comp
}

pose_component_destroy :: proc(comp: ^Cmp_Pose) {
    delete(comp.pose)
    delete(comp.file_name)
    delete(comp.pose_name)
}

animation_component_default :: proc() -> Cmp_Animation {
    return Cmp_Animation{
        num_poses = 0,
        flags = AnimFlags{},
        time = 0.25,
        start = 0,
        end = 0,
        prefab_name = 0,
        trans_timer = 0.0,
        trans_time = 0.1,
        trans = 0,
        trans_end = 0,
        state = .DEFAULT,
    }
}

animation_component_with_names :: proc(
    num_poses: i32,
    prefab: string,
    start_name: string,
    end_name: string,
    flags: AnimFlags
) -> Cmp_Animation {
    return Cmp_Animation{
        num_poses = num_poses,
        flags = flags,
        time = 0.25,
        start = xxhash.XXH32(transmute([]byte)start_name),
        end = xxhash.XXH32(transmute([]byte)end_name),
        prefab_name = xxhash.XXH32(transmute([]byte)prefab),
        trans_timer = 0.0,
        trans_time = 0.1,
        trans = 0,
        trans_end = 0,
        state = .DEFAULT,
    }
}

animation_component_with_time :: proc(
    time: f32,
    num_poses: i32,
    prefab: string,
    start_name: string,
    end_name: string,
    flags: AnimFlags
) -> Cmp_Animation {
    comp := animation_component_with_names(num_poses, prefab, start_name, end_name, flags)
    comp.time = time
    return comp
}

animation_component_no_start :: proc(
    num_poses: i32,
    prefab: string,
    end_name: string,
    flags: AnimFlags
) -> Cmp_Animation {
    return Cmp_Animation{
        num_poses = num_poses,
        flags = flags,
        time = 0.25,
        start = 0,
        end = xxhash.XXH32(transmute([]byte)end_name),
        prefab_name = xxhash.XXH32(transmute([]byte)prefab),
        trans_timer = 0.0,
        trans_time = 0.1,
        trans = 0,
        trans_end = 0,
        state = .DEFAULT,
    }
}

animation_component_with_hashes :: proc(
    num_poses: i32,
    prefab_hash: u32,
    start_hash: u32,
    end_hash: u32,
    flags: AnimFlags
) -> Cmp_Animation {
    return Cmp_Animation{
        num_poses = num_poses,
        flags = flags,
        time = 0.25,
        start = start_hash,
        end = end_hash,
        prefab_name = prefab_hash,
        trans_timer = 0.0,
        trans_time = 0.1,
        trans = 0,
        trans_end = 0,
        state = .DEFAULT,
    }
}

animation_component_with_time_and_hashes :: proc(
    time: f32,
    prefab_hash: u32,
    start_hash: u32,
    end_hash: u32,
    flags: AnimFlags
) -> Cmp_Animation {
    comp := animation_component_with_hashes(2, prefab_hash, start_hash, end_hash, flags)
    comp.time = time
    return comp
}

animate_component_default :: proc() -> Cmp_Animate {
    return Cmp_Animate{
        curr_time = 0.0,
        time = 1.0,
        flags = AnimFlags{},
        start = Sqt{},
        end = Sqt{},
        parent_entity = Entity(0),
    }
}

animate_component_create :: proc(time: f32, flags: AnimFlags, start: Sqt, end: Sqt, parent: Entity) -> Cmp_Animate {
    return Cmp_Animate{
        curr_time = 0.0,
        time = time,
        flags = flags,
        start = start,
        end = end,
        parent_entity = parent,
    }
}

// Constructor overloading
animation_component :: proc{
    animation_component_default,
    animation_component_with_names,
    animation_component_with_time,
    animation_component_no_start,
    animation_component_with_hashes,
    animation_component_with_time_and_hashes,
}

animate_component :: proc{
    animate_component_default,
    animate_component_create,
}

debug_component_default :: proc() -> Cmp_Debug {
    return Cmp_Debug{
        type = "",
        message = "",
    }
}

debug_component_create :: proc(debug_type: string, debug_message: string) -> Cmp_Debug {
    return Cmp_Debug{
        type = strings.clone(debug_type),
        message = strings.clone(debug_message),
    }
}

debug_component_destroy :: proc(comp: ^Cmp_Debug) {
    delete(comp.type)
    delete(comp.message)
}

// Constructor overloading
debug_component :: proc{
    debug_component_default,
    debug_component_create,
}

audio_component_default :: proc() -> Cmp_Audio {
    return Cmp_Audio{
        play = false,
        chunk = nil,
        file_name = "",
        channel = -1,
    }
}

audio_component_with_file :: proc(filename: string) -> Cmp_Audio {
    return Cmp_Audio{
        play = false,
        chunk = nil,
        file_name = strings.clone(filename),
        channel = -1,
    }
}

audio_component_create :: proc(filename: string, should_play: bool) -> Cmp_Audio {
    return Cmp_Audio{
        play = should_play,
        chunk = nil,
        file_name = strings.clone(filename),
        channel = -1,
    }
}

audio_component_destroy :: proc(comp: ^Cmp_Audio) {
    if comp.chunk != nil {
        sdl_mixer.FreeChunk(comp.chunk)
    }
    delete(comp.file_name)
}

// Constructor overloading
audio_component :: proc{
    audio_component_default,
    audio_component_with_file,
    audio_component_create,
}

// Utility functions for audio
audio_load_file :: proc(comp: ^Cmp_Audio, filename: string) -> bool {
    // Clean up existing chunk
    if comp.chunk != nil {
        sdl_mixer.FreeChunk(comp.chunk)
    }

    // Load new audio file
    comp.chunk = sdl_mixer.LoadWAV(strings.clone_to_cstring(filename, context.temp_allocator))
    if comp.chunk == nil {
        fmt.printf("Failed to load audio file: %s, SDL_Error: %s\n", filename, sdl.GetError())
        return false
    }

    // Update filename
    delete(comp.file_name)
    comp.file_name = strings.clone(filename)
    return true
}

audio_play :: proc(comp: ^Cmp_Audio, loops: i32 = 0) -> bool {
    if comp.chunk == nil {
        if !audio_load_file(comp, comp.file_name) {
            return false
        }
    }

    comp.channel = sdl_mixer.PlayChannel(-1, comp.chunk, loops)
    if comp.channel == -1 {
        fmt.printf("Failed to play audio: %s\n", sdl.GetError())
        return false
    }

    comp.play = true
    return true
}

audio_stop :: proc(comp: ^Cmp_Audio) {
    if comp.channel != -1 {
        sdl_mixer.HaltChannel(comp.channel)
    }
    comp.play = false
    comp.channel = -1
}

audio_pause :: proc(comp: ^Cmp_Audio) {
    if comp.channel != -1 {
        sdl_mixer.Pause(comp.channel)
    }
}

audio_resume :: proc(comp: ^Cmp_Audio) {
    if comp.channel != -1 {
        sdl_mixer.Resume(comp.channel)
    }
}

audio_is_playing :: proc(comp: Cmp_Audio) -> bool {
    if comp.channel == -1 do return false
    return sdl_mixer.Playing(comp.channel) != 0
}

audio_set_volume :: proc(comp: ^Cmp_Audio, volume: i32) {
    if comp.chunk != nil {
        sdl_mixer.VolumeChunk(comp.chunk, volume)
    }
}

// Initialize SDL mixer (call this once at startup)
audio_system_init :: proc() -> bool {
    if sdl_mixer.OpenAudio(44100, sdl_mixer.DEFAULT_FORMAT, 2, 2048) != 0 {
        fmt.printf("Failed to initialize SDL_mixer: %s\n", sdl.GetError())
        return false
    }
    return true
}

// Cleanup SDL mixer (call this at shutdown)
audio_system_quit :: proc() {
    sdl_mixer.CloseAudio()
}

vertex_equals :: proc(a: RenderVertex, b: RenderVertex) -> bool {
    return a.pos == b.pos && a.norm == b.norm && a.tang == b.tang && a.uv == b.uv
}
