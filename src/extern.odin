package main
import math "core:math/linalg"
import ecs "external/ecs"
import embree "external/embree"
import "core:fmt"
import vma "external/vma"
import "resource"
import "resource/scene"
import "core:os"
import "core:encoding/json"

// Helper types for vectors/matrices
vec2f :: [2]f32
vec3f :: [3]f32
mat4f :: [4][4]f32
vec4i :: [4]i32

quat :: math.Quaternionf32
vec3 :: math.Vector3f32
vec4 :: math.Vector4f32
mat4 :: math.Matrix4f32
mat3 :: math.Matrix3f32
// Import the ECS Entity type
Entity :: ecs.EntityID
World :: ecs.World
//----------------------------------------------------------------------------\\
// /ECS
//----------------------------------------------------------------------------\\
// Helper functions that assume g_world
create_world :: proc() -> ^World {
     return ecs.create_world()// track_alloc.backing)
}
delete_world :: proc(){
	//context.allocator = track_alloc.backing
	ecs.delete_world(g_world)
}
// Entity management
add_entity :: proc() -> ecs.EntityID {
	return ecs.add_entity(g_world)
}

remove_entity :: proc(entity: ecs.EntityID){
    ecs.remove_entity(g_world, entity)
}
// Component management
add_component :: proc(entity: ecs.EntityID, component: $T) {
    // prev_alloc := context.allocator
    // defer context.allocator = prev_alloc
    // context.allocator = track_alloc.backing
	ecs.add_component(g_world, entity, component)
}

remove_component :: proc(entity: ecs.EntityID, $T: typeid){
    // prev_alloc := context.allocator
    // defer context.allocator = prev_alloc
    // context.allocator = track_alloc.backing
    ecs.remove_component(g_world, entity, typeid)
}

// Query system
query :: proc(terms: ..ecs.Term) -> []^ecs.Archetype {
    // prev_alloc := context.allocator
    // defer context.allocator = prev_alloc
    // context.allocator = track_alloc.backing
	return ecs.query(g_world, ..terms)
}

// Table access - overloaded procedure set
get_table :: proc {
	get_table_same,
	get_table_cast,
	get_table_pair,
}

get_table_same :: proc(archetype: ^ecs.Archetype, $Component: typeid) -> []Component {
	return ecs.get_table_same(g_world, archetype, Component)
}

get_table_cast :: proc(
	archetype: ^ecs.Archetype,
	$Component: typeid,
	$CastTo: typeid,
) -> []CastTo {
	return ecs.get_table_cast(g_world, archetype, Component, CastTo)
}

get_table_pair :: proc(archetype: ^ecs.Archetype, pair: ecs.PairType($R, $T)) -> []R {
	return ecs.get_table_pair(g_world, archetype, pair)
}

get_component :: proc {
	get_component_same,
	get_component_cast,
	get_component_pair,
}

get_component_same :: proc(entity: Entity, $Component: typeid) -> ^Component {
	return ecs.get_component_same(g_world, entity, Component)
}
get_component_cast :: proc(entity: Entity, $Component: typeid, $CastTo: typeid) -> ^CastTo {
	return ecs.get_component_cast(g_world, entity, Component, CastTo)
}
get_component_pair :: proc(entity: Entity, pair: ecs.PairType($R, $T)) -> ^R {
	return ecs.get_component_pair(g_world, entity, pair)
}

has :: proc {
	has_typeid,
	has_pair,
}

has_typeid :: proc(component: typeid) -> ecs.Term {
	return ecs.has(component)
}

has_pair :: proc(p: $P/ecs.PairType) -> ecs.Term {
	return ecs.has(p)
}

end_ecs :: proc() {
	ecs.delete_world(g_world)
}


//----------------------------------------------------------------------------\\
// /Internal helpers
//----------------------------------------------------------------------------\\

get_material :: proc(i: i32) -> ^resource.Material {
	return &g_materials[i]
}
get_material_index :: proc(id: i32) -> i32 {
	for m, i in g_materials {
		if (m.unique_id == id) {
			return i32(i)
		}
	}
	return 1
}

map_sqt :: proc(sqt : resource.Sqt) -> Sqt{
    return Sqt{
        pos = sqt.pos,
        rot = sqt.rot,
        sca = sqt.sca
    }
}

map_vec2f :: proc(vec : scene.Vector2) -> vec2f{
    return vec2f{vec.x, vec.y}
}

map_gui :: proc{map_sc_gui_to_gui_cmp, map_gui_cmp_to_sc_gui}
map_sc_gui_to_gui_cmp :: proc(gui : scene.Gui) -> Cmp_Gui{
    return Cmp_Gui{
        align_ext = map_vec2f(gui.AlignExt),
        align_min = map_vec2f(gui.Alignment),
        extents = map_vec2f(gui.Extent),
        min = vec2f{0.0,0.0},
        id = gui.Texture.Name
    }
}
map_gui_cmp_to_sc_gui :: proc(cmp: Cmp_Gui) -> scene.Gui {
    return scene.Gui{
        AlignExt = scene.Vector2{x = cmp.align_ext.x, y = cmp.align_ext.y},
        Alignment = scene.Vector2{x = cmp.align_min.x, y = cmp.align_min.y},
        Extent = scene.Vector2{x = cmp.extents.x, y = cmp.extents.y},
        Position = scene.Vector2{x = cmp.min.x, y = cmp.min.y},
        // Texture = scene.Texture{Name = cmp.id}, // Texture shouldn't change
    }
}

save_ui_prefab :: proc(entity: Entity, filename: string) {
    nc := get_component(entity, Cmp_Node)
    gc := get_component(entity, Cmp_Gui)
    if nc == nil || gc == nil {
        fmt.eprintln("Error: Entity missing Cmp_Node or Cmp_Gui for saving")
        return
    }

    // Reconstruct minimal Node (defaults for unused fields)
    node := scene.Node{
        Name = nc.name,
        gui = map_gui(gc^),
        eFlags = transmute(u32) nc.engine_flags,
        gFlags = nc.game_flags,
        Dynamic = nc.is_dynamic,
        hasChildren = nc.is_parent,
        // Default Transform (identity, as UI JSONs don't use it)
        Transform = scene.Transform{
            Position = scene.Vector3{x=0, y=0, z=0},
            Rotation = scene.Vector4{i=0, j=0, k=0, w=1},
            Scale = scene.Vector3{x=1, y=1, z=1},
        },
        // Other fields zero/default (e.g., no children, no camera/light, etc.)
    }

    data, marshal_err := json.marshal(node, allocator = context.temp_allocator)
    if marshal_err != nil {
        fmt.eprintf("Error marshalling UI prefab '%s': %v\n", filename, marshal_err)
        return
    }

    ok := os.write_entire_file(filename, data)
    if !ok {
        fmt.eprintf("Error writing UI prefab file '%s'\n", filename)
    }
}
