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
restart_world :: #force_inline proc(){
    axiom.restart_world(&g.mem_game)
}
set_new_scene :: #force_inline proc(name:string) -> ^scene.SceneData{
    return axiom.set_new_scene(name, &g.mem_scene)
}
get_entity :: axiom.get_entity
get_table :: axiom.get_table
get_component :: axiom.get_component
add_component :: axiom.add_component
// add_component :: #force_inline proc(entity: Entity, component: $T) {
//     axiom.add_component(entity, component)
// }
has :: axiom.has
// has :: #force_inline proc(component: typeid) -> axiom.Term {
// 	return axiom.has(component)
// }
update_gui :: #force_inline proc(gui:^Cmp_Gui){
    axiom.update_gui(gui)
}
load_prefab :: #force_inline proc(name: string) -> (prefab : Entity){
   return axiom.load_prefab(name, g.mem_game.alloc)
}
