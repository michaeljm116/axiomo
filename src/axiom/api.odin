package axiom
import math "core:math/linalg"
import ecs "external/ode_ecs"
import "core:fmt"
import "resource"
import "resource/scene"
import "core:os"
import "core:encoding/json"
import "core:mem"
import "base:runtime"
import "core:log"

// Helper types for vectors/matrices
vec2f :: [2]f32
vec3f :: [3]f32
mat4f :: [4][4]f32
vec4i :: [4]i32
vec2i :: [2]i16

quat :: math.Quaternionf32
vec3 :: math.Vector3f32
vec4 :: math.Vector4f32
mat4 :: math.Matrix4f32
mat3 :: math.Matrix3f32
// Import the ECS Entity type
Entity :: ecs.entity_id
Database :: ecs.Database
View :: ecs.View
Iterator :: ecs.Iterator
Table :: ecs.Table
Error :: ecs.Error

// curr_max_union
CurrMax :: struct #raw_union{
    using _: struct{
        curr:f32,
        max:f32,
    },
    _: [2]f32,
}

//----------------------------------------------------------------------------\\
// /Globals for the engine
//----------------------------------------------------------------------------\\
g_renderbase : ^RenderBase
g_raytracer : ^ComputeRaytracer
g_window : Window
g_input : InputState
g_controller : Controller
g_bvh : ^Sys_Bvh
g_physics : ^Sys_Physics

g_texture_indexes : map[string]i32
g_world : ^World
g_cap :: 10000

//----------------------------------------------------------------------------\\
// /ECS
//----------------------------------------------------------------------------\\
World :: struct{
    db : ^Database,
    tables : map[typeid]rawptr,
    entity : Entity,
    alloc : mem.Allocator,
    cap : int
}

// Helper functions that assume g_world
create_world :: #force_inline proc(mem_stack : ^MemoryStack) -> ^World {
    init_memory(mem_stack, mem.Megabyte * 100)
    g_world = new(World, mem_stack.alloc)
    g_world.tables = make(map[typeid]rawptr, mem_stack.alloc)
    g_world.cap = g_cap
    tag_root = new(ecs.Tag_Table, mem_stack.alloc)
    g_world.db = new(Database, mem_stack.alloc)
    ecs.init(g_world.db, entities_cap=g_cap, allocator = mem_stack.alloc)
    g_world.entity = add_entity()
    g_world.alloc = mem_stack.alloc
    create_main_tables(g_world)
    init_views(g_world.alloc)
    return g_world
}

create_main_tables :: proc(world : ^World)
{
    //Tables needed for views
    create_table(Cmp_Transform, world)
    create_table(Cmp_Node, world)
    create_table(Cmp_Primitive, world)
    create_table(Cmp_Animation, world)
    create_table(Cmp_Animate, world)
    create_table(Cmp_BFGraph, world)
    create_table(Cmp_Collision2D, world)
    ecs.tag_table__init(tag_root, world.db, g_cap)

    // Misc tables
    create_table(Cmp_Gui, world)
    create_table(Cmp_Camera, world)
    create_table(Cmp_Light, world)
    create_table(Cmp_Render, world)
}

init_views :: proc(alloc : mem.Allocator){
    sys_transform_init(alloc)
    sys_bvh_init(alloc)
    sys_anim_init(alloc)
    sys_physics_init(alloc)
    sys_text_init(alloc)
}

destroy_world :: #force_inline proc(mem_stack : ^MemoryStack) {
	render_clear_entities()
	reset_memory_stack(mem_stack)
    anim_initialized = false
    // g_world.tables = {}
    // g_world = nil
}

// Entity management
add_entity :: #force_inline proc() -> Entity {
    entity, err := ecs.create_entity(g_world.db)
    if err != ecs.API_Error.None do panic("Failed to add entity")
	return entity
}

// Component management
add_component_type :: #force_inline proc(entity: Entity, component: $T) -> (^T) {
    // copy := component
    c, ok := add_component_typeid(entity, T)
    if ok != nil{
        log.error("Failed to loadd Add Compoennt", entity, component)
        // panic("Failed to add component")
    }

    // NOTE: this is a shallow copy, doesn't handle pointers/dynamic data
    // mem.copy(c, &copy, size_of(T))
    c^ = component
    return c
}

add_component_typeid :: proc(entity: Entity, $T: typeid) -> (^T, Error) {
    tid := typeid_of(T)
    table_ptr, found := g_world.tables[tid]
    if !found {
        new_table := new(Table(T), g_world.alloc)
        table_err := ecs.table_init(new_table, db=g_world.db, cap=g_cap)
        if table_err != nil do panic("failed to add table")
        g_world.tables[tid] = rawptr(new_table)
        table_ptr = rawptr(new_table)
    }
    table := transmute(^Table(T)) table_ptr
    ret, err := ecs.add_component(table, entity)
    return ret,err
}
init_table :: ecs.table_init

get_or_create_table :: proc($T: typeid) -> (^Table(T)){
    tid := typeid_of(T)
    table_ptr, found := g_world.tables[tid]
    if !found {
        new_table := new(Table(T), g_world.alloc)
        table_err := ecs.table_init(new_table, db=g_world.db, cap=g_cap)
        if table_err != nil do panic("failed to add table")
        g_world.tables[tid] = rawptr(new_table)
        table_ptr = rawptr(new_table)
    }
    return transmute(^Table(T))table_ptr
}

create_table :: proc($T: typeid, world : ^World) -> ^Table(T){
    tid := typeid_of(T)
    new_table := new(Table(T), world.alloc)
    table_err := ecs.table_init(new_table, db=world.db, cap=world.cap)
    if table_err != nil do panic("failed to add table")
    world.tables[tid] = rawptr(new_table)
    table_ptr := rawptr(new_table)
    return transmute(^Table(T))table_ptr
}

add_component_table :: ecs.add_component

add_component :: proc{add_component_type, add_component_typeid}

remove_component :: #force_inline proc(entity: Entity, $T: typeid){
    // First find the table, then remove from table
    table_ptr, found := g_world.tables[typeid_of(T)]
    if !found {
        fmt.println("Trying to remove component from non-existent table", entity, type_info_of(T))
        return
    }
    table := cast(^Table(T))table_ptr
    ecs.remove_component(table, entity)
}

entity_exists :: #force_inline proc(entity: Entity) -> bool {
    return !ecs.is_entity_expired(g_world.db, entity) && (entity != Entity(0))
}

table_len     :: ecs.table_len
view_len      :: ecs.view_len
view_rebuild  :: ecs.rebuild
view_init     :: ecs.view_init
iterator_init :: ecs.iterator_init
iterator_next :: ecs.iterator_next
get_entity    :: ecs.get_entity

get_component_table :: #force_inline proc(table : ^Table($T), entity : Entity) -> ^T{
    return ecs.get_component(table,entity)
}
get_component_type_id :: proc(entity: Entity, $T: typeid) -> ^T{
   table := get_table(T)
   return ecs.get_component(table, entity)
}
get_component :: proc{get_component_type_id, get_component_table}

get_table_ptr :: proc($T: typeid) -> rawptr {
    tid := typeid_of(T)
    table_ptr, found := g_world.tables[tid]
    if !found {
        // return nil  // Or panic("Table not found for type") or just make the table
        new_table := new(Table(T), g_world.alloc)
        table_err := ecs.table_init(new_table, db=g_world.db, cap=g_cap)
        if table_err != nil do panic("failed to add table")
        g_world.tables[tid] = rawptr(new_table)
        table_ptr = rawptr(new_table)
    }
    return table_ptr
}
get_table :: proc($T: typeid) -> ^Table(T) {
    table_ptr := get_table_ptr(T)
    return transmute(^Table(T)) table_ptr
}

has :: proc {has_component_table,has_component_type_id,}
has_component_table :: #force_inline proc(table: ^Table($T), entity: Entity) -> bool{
    return ecs.has_component(table, entity)
}
has_component_type_id :: #force_inline proc(entity: Entity, $T: typeid) -> bool{
    table_ptr := get_table_ptr(T)
    if table_ptr == nil{
        fmt.println("Component Table does not exist")
        return false
    }
    table := cast(^Table(T)) table_ptr
    return ecs.has_component(table, entity)
}

end_ecs :: #force_inline proc() {
	// ecs.delete_world(g_world)
}

tag_root : ^ecs.Tag_Table
tag :: ecs.tag
untag :: ecs.untag

//----------------------------------------------------------------------------\\
// /Internal helpers
//----------------------------------------------------------------------------\\

get_material :: #force_inline proc(i: i32) -> ^resource.Material {
	return &resource.materials[i]
}
get_material_index :: #force_inline proc(id: i32) -> i32 {
	for m, i in resource.materials {
		if (m.unique_id == id) {
			return i32(i)
		}
	}
	return 1
}

map_sqt :: #force_inline proc(sqt : resource.Sqt) -> Sqt{
    return Sqt{
        pos = sqt.pos,
        rot = sqt.rot,
        sca = sqt.sca
    }
}

map_vec2f :: #force_inline proc(vec : scene.Vector2) -> vec2f{
    return vec2f{vec.x, vec.y}
}

map_gui :: proc{map_sc_gui_to_gui_cmp, map_gui_cmp_to_sc_gui}
map_sc_gui_to_gui_cmp :: #force_inline proc(gui : scene.Gui) -> Cmp_Gui{
    return Cmp_Gui{
        align_ext = map_vec2f(gui.AlignExt),
        align_min = map_vec2f(gui.Alignment),
        extents = map_vec2f(gui.Extent),
        min = map_vec2f(gui.Position),
        id = gui.Texture.Name
    }
}
map_gui_cmp_to_sc_gui :: #force_inline proc(cmp: Cmp_Gui) -> scene.Gui {
    return scene.Gui{
        AlignExt = scene.Vector2{x = cmp.align_ext.x, y = cmp.align_ext.y},
        Alignment = scene.Vector2{x = cmp.align_min.x, y = cmp.align_min.y},
        Extent = scene.Vector2{x = cmp.extents.x, y = cmp.extents.y},
        Position = scene.Vector2{x = cmp.min.x, y = cmp.min.y},
        Texture = scene.Texture{Name = cmp.id},
    }
}

save_ui_prefab :: #force_inline proc(entity: Entity, filename: string) {
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

    data, marshal_err := json.marshal(node, json.Marshal_Options{pretty = true}, allocator = context.temp_allocator)
    if marshal_err != nil {
        fmt.eprintf("Error marshalling UI prefab '%s': %v\n", filename, marshal_err)
        return
    }

    ok := os.write_entire_file(filename, data)
    if !ok {
        fmt.eprintf("Error writing UI prefab file '%s'\n", filename)
    }
}

set_new_scene :: proc(name : string, arena : ^MemoryArena) -> ^scene.SceneData
{
    destroy_memory(arena)
    init_memory(arena, mem.Megabyte)
    return scene.load_new_scene(name, arena.alloc)
}

//----------------------------------------------------------------------------\\
// /Resource
//----------------------------------------------------------------------------\\
load_materials :: #force_inline proc(file : string, materials : ^[dynamic]resource.Material){
    resource.load_materials(file,materials)
}
load_models :: #force_inline proc(directory: string, models: ^[dynamic]resource.Model) {
    resource.load_models(directory, models)
}
load_anim_directory :: #force_inline proc(directory : string, poses : ^map[u32]resource.Animation, alloc : mem.Allocator){
    resource.load_anim_directory(directory, poses, alloc)
}

//----------------------------------------------------------------------------\\
// /Scene
//----------------------------------------------------------------------------\\
load_prefab_directory :: #force_inline proc(directory : string, prefabs : ^map[string]scene.Node, alloc := context.allocator){
   scene.load_prefab_directory(directory, prefabs, alloc)
}

load_prefab_node :: #force_inline proc(name: string, alloc := context.allocator) -> (root: scene.Node) {
    return scene.load_prefab_node(name,alloc)
}

load_new_scene :: #force_inline proc(name : string, allocator := context.temp_allocator) -> ^scene.SceneData {
    return scene.load_new_scene(name, allocator)
}
