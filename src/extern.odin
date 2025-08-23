package main
import math "core:math/linalg"
import ecs "external/ecs"
import embree "external/embree"
import vma "external/vma"
import "resource"
import "resource/scene"

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

// Entity management
add_entity :: proc() -> ecs.EntityID {
	return ecs.add_entity(g_world)
}

remove_entity :: proc(entity: ecs.EntityID){
    ecs.remove_entity(g_world, entity)
}
// Component management
add_component :: proc(entity: ecs.EntityID, component: $T) {
	ecs.add_component(g_world, entity, component)
}

// Query system
query :: proc(terms: ..ecs.Term) -> []^ecs.Archetype {
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
