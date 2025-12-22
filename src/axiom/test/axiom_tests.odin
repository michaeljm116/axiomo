package game_tests
// odin test src/axiom/test -define:ODIN_TEST_THREADS=1 -debug

import "core:mem"
import "core:testing"
import "base:runtime"
import "core:log"
import res"../resource"
import sc"../resource/scene"
import axiom".."
import "vendor:glfw"

TestContext :: struct {
    mem_core : ^axiom.MemoryArena,
    mem_area : ^axiom.MemoryArena,
    mem_game : ^axiom.MemoryStack,
    world : ^axiom.World,
    frame : axiom.FrameRate,
}

// Helper to create a temporary memory stack for each test
create_test_memory_stack :: proc() -> ^axiom.MemoryStack {
    stack := new(axiom.MemoryStack)
    axiom.init_memory(stack, mem.Megabyte * 1) // Adjust size as needed
    return stack
}
create_test_memory_arena :: proc() -> ^axiom.MemoryArena {
    arena := new(axiom.MemoryArena)
    axiom.init_memory(arena, mem.Megabyte * 100) // Adjust size as needed
    return arena
}


load_assets :: proc(alloc : mem.Allocator)
{
    res.materials = make([dynamic]res.Material, 0, alloc)
	res.models = make([dynamic]res.Model, 0, alloc)
	res.animations = make(map[u32]res.Animation, 0, alloc)

	res.scenes = make(map[string]^sc.SceneData, 0, alloc)
	res.prefabs = make(map[string]sc.Node, 0, alloc)
	res.ui_prefabs = make(map[string]sc.Node, 0, alloc)

	res.load_materials("assets/config/Materials.xml", &res.materials)
	res.load_models("assets/models/", &res.models)
	res.load_anim_directory("assets/animations/", &res.animations, alloc)

	sc.load_scene_directory("assets/scenes", &res.scenes, alloc)
	sc.load_prefab_directory("assets/prefabs", &res.prefabs, alloc)
	sc.load_prefab_directory("assets/prefabs/ui", &res.ui_prefabs, alloc)
}

create_frame :: proc() -> axiom.FrameRate
{
    frame := axiom.FrameRate {
       	prev_time         = glfw.GetTime(),
       	curr_time         = 0,
       	wait_time         = 0,
       	delta_time        = 0,
       	target            = 120.0,
       	target_dt         = (1.0 / 120.0),
       	locked            = true,
       	physics_acc_time  = 0,
       	physics_time_step = 1.0 / 60.0,
    }
    return frame
}

create_test_world :: proc() -> ^TestContext
{
    test_ctx := new(TestContext)
    test_ctx^ = TestContext{
        mem_core = create_test_memory_arena(),
        mem_area = create_test_memory_arena(),
        mem_game = create_test_memory_stack(),
        frame = create_frame(),
    }
    test_ctx.mem_core.name = "core"
    test_ctx.mem_area.name = "area"
    test_ctx.mem_game.name = "game"

    axiom.g_renderbase = new(axiom.RenderBase, test_ctx.mem_core.alloc)
    axiom.g_raytracer = new(axiom.ComputeRaytracer, test_ctx.mem_core.alloc)
    axiom.window_init(context)
    axiom.window_input_init()
    axiom.window_renderer_init()
    axiom.init_vulkan()
    axiom.g_renderbase.ctx = context

    load_assets(test_ctx.mem_area.alloc)

    axiom.g_bvh = axiom.bvh_system_create(test_ctx.mem_core.alloc)
    axiom.g_physics = axiom.sys_physics_create(test_ctx.mem_core.alloc)
    axiom.start_up_raytracer(test_ctx.mem_area.alloc)
    frame := create_frame()
    world := axiom.create_world(test_ctx.mem_game)
    // axiom.load_scene("Empty", test_ctx.mem_game.alloc)
    return test_ctx
}

destroy_test_world :: proc(test_ctx : ^TestContext)
{
    defer axiom.destroy_memory_arena(test_ctx.mem_core)
    defer axiom.destroy_memory_arena(test_ctx.mem_area)
    defer axiom.destroy_memory_stack(test_ctx.mem_game)
    glfw.SetKeyCallback(axiom.g_window.handle, nil)
    glfw.SetCursorPosCallback(axiom.g_window.handle, nil)
    glfw.SetMouseButtonCallback(axiom.g_window.handle, nil)
    glfw.SetInputMode(axiom.g_window.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
    axiom.bvh_system_destroy(axiom.g_bvh)
    axiom.cleanup()
    free_all(context.temp_allocator)
    free(test_ctx)
}

@(test)
test_create_world :: proc(t: ^testing.T){
    test_ctx := create_test_world()
    defer destroy_test_world(test_ctx)
    testing.expect(t,test_ctx != nil, "Test context should not be nil")
}

@(test)
test_load_empty_scene :: proc(t: ^testing.T){
    test_ctx := create_test_world()
    defer destroy_test_world(test_ctx)
    axiom.load_scene("Empty", test_ctx.mem_game.alloc)
    testing.expect(t,test_ctx != nil, "Test context should not be nil")
}

// @(test)
// test_table_add_cmp_works :: proc(t: ^testing.T)
// {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     //First just create a direct table
//     table : axiom.Table(axiom.Cmp_Root)
//     axiom.init_table(&table, axiom.g_world.db, 100)
//     ent := axiom.add_entity()
//     cmp,err := axiom.add_component_table(&table, ent)
//     testing.expect(t, err == nil, "Component not added")
//     testing.expect(t, cmp != nil, "Component should not be nil")
// }

// @(test)
// test_typeid_add_cmp_works :: proc(t: ^testing.T)
// {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     //First just create a direct table
//     ent := axiom.add_entity()
//     tid := typeid_of(axiom.Cmp_Root)
//     table_ptr, found := axiom.g_world.tables[tid]
//     if !found {
//         new_table := new(axiom.Table(axiom.Cmp_Root), mem_stack.alloc)
//         log.warn(new_table != nil)
//         axiom.init_table(new_table, db=axiom.g_world.db, cap=1000)
//         log.warn(new_table != nil)
//         axiom.g_world.tables[tid] = rawptr(new_table)
//         table_ptr = rawptr(new_table)
//     }
//     table := cast(^axiom.Table(axiom.Cmp_Root)) table_ptr

//     cmp,err := axiom.add_component_table(table, ent)
//     testing.expect(t, err == nil, "Component not added")
//     testing.expect(t, cmp != nil, "Component should not be nil")
// }

// @(test)
// test_table_creation_and_reuse :: proc(t: ^testing.T) {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     // Before adding any component, table should not exist
//     tid := typeid_of(axiom.Cmp_Transform)
//     _, found_before := axiom.g_world.tables[tid]
//     testing.expect(t, !found_before, "Table should not exist before adding component")

//     // Add entity and component
//     e1 := axiom.add_entity()
//     trans1 := axiom.cmp_transform_prs({0,0,0}, {0,0,0}, {1,1,1})
//     added_trans1 := axiom.add_component(e1, trans1)
//     testing.expect(t, added_trans1 != nil, "Failed to add first Cmp_Transform")

//     // After add, table should exist
//     _, found_after := axiom.g_world.tables[tid]
//     testing.expect(t, found_after, "Table should be created after adding component")

//     table1 := axiom.get_table(axiom.Cmp_Transform)
//     testing.expect(t, table1 != nil, "get_table should return non-nil after creation")

//     // Add second entity and same component type
//     e2 := axiom.add_entity()
//     trans2 := axiom.cmp_transform_prs({1,1,1}, {0,0,0}, {2,2,2})
//     added_trans2 := axiom.add_component(e2, trans2)
//     testing.expect(t, added_trans2 != nil, "Failed to add second Cmp_Transform")

//     // Table should be the same (reused)
//     table2 := axiom.get_table(axiom.Cmp_Transform)
//     testing.expect(t, table1 == table2, "Table should be reused for same component type")

//     // Verify table length increased
//     testing.expect(t, axiom.table_len(table2) == 2, "Table should have 2 components now")

//     // Test adding another table to the same entity
//     // root := axiom.Cmp_Root{}
//     // added_root := axiom.add_component(e1, root)
//     // testing.expect(t, added_root != nil, "Failed to add Cmp_Root")
// }



// @(test)
// test_get_component_and_table :: proc(t: ^testing.T) {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     e := axiom.add_entity()
//     trans := axiom.cmp_transform_prs({0,1,2}, {3,4,5}, {6,7,8})
//     axiom.add_component(e, trans)

//     // Get table
//     table := axiom.get_table(axiom.Cmp_Transform)
//     testing.expect(t, table != nil, "get_table failed to retrieve existing table")

//     // Get component by typeid
//     comp_typeid := axiom.get_component_type_id(e, axiom.Cmp_Transform)
//     testing.expect(t, comp_typeid != nil, "get_component_type_id returned nil")

//     // Get component from table
//     comp_table := axiom.get_component_table(table, e)
//     testing.expect(t, comp_table != nil, "get_component_table returned nil")
//     testing.expect(t, comp_typeid == comp_table, "get_component variants should return same pointer")

//     // Verify values were set correctly
//     testing.expect(t, comp_table.local.pos.x == 0 && comp_table.local.pos.y == 1 && comp_table.local.pos.z == 2,
//                    "Component values not set correctly")
// }

// @(test)
// test_multiple_components_same_type :: proc(t: ^testing.T) {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     e1 := axiom.add_entity()
//     trans1 := axiom.cmp_transform_prs({0,0,0}, {0,0,0}, {1,1,1})
//     axiom.add_component(e1, trans1)

//     e2 := axiom.add_entity()
//     trans2 := axiom.cmp_transform_prs({10,10,10}, {20,20,20}, {30,30,30})
//     axiom.add_component(e2, trans2)

//     comp1 := axiom.get_component(e1, axiom.Cmp_Transform)
//     testing.expect(t, comp1 != nil, "Failed to get comp1")
//     testing.expect(t, comp1.local.pos.x == 0 && comp1.local.sca.z == 1, "comp1 values incorrect")

//     comp2 := axiom.get_component(e2, axiom.Cmp_Transform)
//     testing.expect(t, comp2 != nil, "Failed to get comp2")
//     testing.expect(t, comp2.local.pos.x == 10 && comp2.local.sca.z == 30, "comp2 values incorrect")

//     // Modify one and ensure the other is unaffected
//     comp1.local.pos = {5,5,5,1}
//     testing.expect(t, comp2.local.pos.x == 10, "Modifying comp1 affected comp2")
// }

// @(test)
// test_has_component :: proc(t: ^testing.T) {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     e := axiom.add_entity()
//     testing.expect(t, !axiom.has(e, axiom.Cmp_Transform), "Should not have component before add")

//     trans := axiom.cmp_transform_prs({0,0,0}, {0,0,0}, {1,1,1})
//     axiom.add_component(e, trans)

//     testing.expect(t, axiom.has(e, axiom.Cmp_Transform), "Should have component after add")

//     table := axiom.get_table(axiom.Cmp_Transform)
//     testing.expect(t, axiom.has(table, e), "has_component_table failed")
// }

// @(test)
// test_remove_component :: proc(t: ^testing.T) {
//     mem_stack := create_test_memory_stack()
//     defer axiom.destroy_memory_stack(mem_stack)

//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)

//     e := axiom.add_entity()
//     trans := axiom.cmp_transform_prs({0,0,0}, {0,0,0}, {1,1,1})
//     axiom.add_component(e, trans)

//     table := axiom.get_table(axiom.Cmp_Transform)
//     testing.expect(t, axiom.table_len(table) == 1, "Table len should be 1 before remove")

//     axiom.remove_component(e, axiom.Cmp_Transform)

//     testing.expect(t, !axiom.has(e, axiom.Cmp_Transform), "Component should be removed")
//     testing.expect(t, axiom.table_len(table) == 0, "Table len should be 0 after remove")

//     // Table should still exist in map
//     tid := typeid_of(axiom.Cmp_Transform)
//     _, found := axiom.g_world.tables[tid]
//     testing.expect(t, found, "Table should still exist after remove")
// }

// @(test)
// test_app_start :: proc(t: ^testing.T){
//     mem_stack := create_test_memory_stack()
//     mem_arena := create_test_memory_arena()
//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)
//     defer axiom.destroy_memory_stack(mem_stack)
//     defer axiom.destroy_memory_arena(mem_arena)
//     load_assets(mem_arena.alloc)

//     player := axiom.load_prefab("Froku", mem_arena.alloc)
//     testing.expect(t, player != axiom.Entity(0), "Froku FAILED TO LOAD")
//     // bee := axiom.load_prefab("Bee", mem_arena.alloc)
//     // testing.expect(t, bee != axiom.Entity(0), "BEE FAILED TO LOAD")

//     // scene := axiom.set_new_scene("assets/scenes/Empty.json", mem_arena)
//     // axiom.load_scene(scene^, mem_stack.alloc)
//     // testing.expect(t, true, "Scene loaded")
// }
// @(test)
// test_load_prefab :: proc(t: ^testing.T){
//     mem_stack := create_test_memory_stack()
//     mem_arena := create_test_memory_arena()
//     axiom.g_world = axiom.create_world(mem_stack)
//     defer axiom.destroy_world(mem_stack)
//     defer axiom.destroy_memory_stack(mem_stack)
//     defer axiom.destroy_memory_arena(mem_arena)
//     load_assets(mem_arena.alloc)

//     entity := axiom.load_prefab("Froku", mem_arena.alloc)
//     testing.expect(t, true, "Froku loaded")

//     head_node := axiom.get_component(entity, axiom.Cmp_Node)
//     testing.expect(t, head_node != nil, "Head Node not loaded")
//     child_entity := head_node.child
//     testing.expect(t, child_entity != axiom.Entity(0), "Child entity not loaded")

//     // scene := axiom.set_new_scene("assets/scenes/Empty.json", mem_arena)
//     // axiom.load_scene(scene^, mem_stack.alloc)
//     // testing.expect(t, true, "Scene loaded")
// }
