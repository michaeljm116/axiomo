package game

import "axiom"
import "axiom/resource/scene"
//----------------------------------------------------------------------------\\
// /Interface - common things for easy interfacing with the engine
//----------------------------------------------------------------------------\\
// Re-export common types from the axiom package for game code convenience
vec2f :: axiom.vec2f
vec3f :: axiom.vec3f
mat4f :: axiom.mat4f
vec4i :: axiom.vec4i
vec2i :: axiom.vec2i

quat :: axiom.quat
vec3 :: axiom.vec3
vec4 :: axiom.vec4
mat4 :: axiom.mat4
mat3 :: axiom.mat3

// Import the ECS Entity type
Entity :: axiom.Entity
World :: axiom.World

//----------------------------------------------------------------------------\\
// /Component interface aliases (re-export axiom components for game code)
//----------------------------------------------------------------------------\\
Cmp_Transform :: axiom.Cmp_Transform
Cmp_Node :: axiom.Cmp_Node
Cmp_Root :: axiom.Cmp_Root
Cmp_Render :: axiom.Cmp_Render
Cmp_Mesh :: axiom.Cmp_Mesh
Cmp_Primitive :: axiom.Cmp_Primitive
Cmp_Model :: axiom.Cmp_Model
Cmp_Selectable :: axiom.Cmp_Selectable
Cmp_Gui :: axiom.Cmp_Gui
Cmp_GuiNumber :: axiom.Cmp_GuiNumber
Cmp_Text :: axiom.Cmp_Text
Cmp_Material :: axiom.Cmp_Material
Cmp_Light :: axiom.Cmp_Light
Cmp_Camera :: axiom.Cmp_Camera
Cmp_BFGraph :: axiom.Cmp_BFGraph
Cmp_Pose :: axiom.Cmp_Pose
Cmp_Animation :: axiom.Cmp_Animation
Cmp_Animate :: axiom.Cmp_Animate
Cmp_Debug :: axiom.Cmp_Debug
Cmp_Audio :: axiom.Cmp_Audio
Cmp_Collision2D :: axiom.Cmp_Collision2D

create_world :: #force_inline proc() -> ^World{
   return axiom.create_world(&g.mem_game)
}
destroy_world :: #force_inline proc(){
   axiom.destroy_world(&g.mem_game)
}
load_scene :: #force_inline proc(name:string){
    axiom.load_scene(name, g.mem_game.alloc)
}

get_entity :: axiom.get_entity
get_table :: axiom.get_table
get_component :: axiom.get_component
add_component :: axiom.add_component
has :: axiom.has
entity_exists :: axiom.entity_exists

update_gui :: #force_inline proc(gui:^Cmp_Gui){
    axiom.update_gui(gui)
}
load_prefab :: #force_inline proc(name: string) -> (prefab : Entity){
   return axiom.load_prefab(name, g.mem_game.alloc)
}

is_mouse_button_pressed :: axiom.is_mouse_button_pressed
is_key_just_released :: axiom.is_key_just_released
is_key_just_pressed :: axiom.is_key_just_pressed
is_key_pressed :: axiom.is_key_pressed

MoveAxis :: axiom.Axis
controller_init :: #force_inline proc() {axiom.controller_init_default_keyboard(&axiom.g_controller)}
controller_update :: #force_inline proc(dt: f32) {
    axiom.controller_handle_keyboard(&axiom.g_controller, dt)
}
controller_just_pressed :: #force_inline proc(btn: axiom.ButtonType) -> bool {
    return .JustPressed in axiom.g_controller.buttons[btn].action
}
controller_pressed :: #force_inline proc(btn: axiom.ButtonType) -> bool {
    return .Pressed in axiom.g_controller.buttons[btn].action
}
controller_held :: #force_inline proc(btn: axiom.ButtonType) -> bool {
    return .Held in axiom.g_controller.buttons[btn].action
}
controller_released :: #force_inline proc(btn: axiom.ButtonType) -> bool {
    return .Released in axiom.g_controller.buttons[btn].action
}
controller_just_released :: #force_inline proc(btn: axiom.ButtonType) -> bool {
    return .JustReleased in axiom.g_controller.buttons[btn].action
}
controller_button_action :: #force_inline proc(btn: axiom.ButtonType) -> axiom.ButtonActions {
    return axiom.g_controller.buttons[btn].action
}
controller_move_axis :: #force_inline proc() -> axiom.Axis {
    return axiom.g_controller.left_axis
}
controller_is_moving :: #force_inline proc() -> bool {
    return axiom.g_controller.left_axis.isMoving
}

GameButton :: enum
{
    Select,
    Back,
    Dodge,
    Focus,
    Walk,
    Run,
}
ButtonTypes :: bit_set[axiom.ButtonType;u16]

Controller :: axiom.Controller
GameController :: struct
{
    buttons : [GameButton]ButtonTypes,
    move_axis : ^axiom.Axis,
    look_axis : ^axiom.Axis,
}

init_game_controller :: proc(c : ^Controller)
{
    g.controller.move_axis = &c.left_axis
    g.controller.look_axis = &c.right_axis

    g.controller.buttons[.Select] = {.ActionD, .ActionU}
    g.controller.buttons[.Back] = {.MenuL, .MenuR}
    g.controller.buttons[.Focus] = {.ActionL}
    g.controller.buttons[.Dodge] = {.ActionR}
    g.controller.buttons[.Walk] = {.PadU, .PadD, .PadL, .PadR}
    g.controller.buttons[.Run] = {.AnalogL}
}

game_controller_held :: #force_inline proc(button: GameButton) -> bool {
    for b in g.controller.buttons[button] {
        if .Held in axiom.g_controller.buttons[b].action do return true
    }
    return false
}

game_controller_just_pressed :: #force_inline proc(button: GameButton) -> bool {
    for b in g.controller.buttons[button] {
        if .JustPressed in axiom.g_controller.buttons[b].action do return true
    }
    return false
}

game_controller_pressed :: #force_inline proc(button: GameButton) -> bool {
    for b in g.controller.buttons[button] {
        if .Pressed in axiom.g_controller.buttons[b].action do return true
    }
    return false
}

game_controller_just_released :: #force_inline proc(button: GameButton) -> bool {
    for b in g.controller.buttons[button] {
        if .JustReleased in axiom.g_controller.buttons[b].action do return true
    }
    return false
}

game_controller_all_released :: #force_inline proc(button: GameButton) -> bool {
    for b in g.controller.buttons[button] {
        if .Pressed in axiom.g_controller.buttons[b].action do return false
    }
    return true
}

game_controller_button_state :: proc(button: GameButton) -> axiom.ButtonActions {
    combined: axiom.ButtonActions
    for b in g.controller.buttons[button] {
        combined += axiom.g_controller.buttons[b].action
    }
    return combined
}

game_controller_is_moving :: #force_inline proc() -> bool {
    return g.controller.move_axis.isMoving
}

game_controller_move_axis :: #force_inline proc() -> MoveAxis {
    return g.controller.move_axis^
}

game_controller_is_running :: #force_inline proc() -> bool {
    return game_controller_held(.Run) || game_controller_pressed(.Run)
}

data_texture_set :: proc(pos: vec2i, pixel: [4]f32)
{
   axiom.data_texture_set(axiom.g_raytracer.data_texture, pos, pixel)
}

data_texture_get :: proc(pos: vec2i) -> [4]f32
{
   return axiom.data_texture_get(axiom.g_raytracer.data_texture, pos)
}

data_texture_update :: proc()
{
    axiom.data_texture_upload(axiom.g_raytracer.data_texture)
}