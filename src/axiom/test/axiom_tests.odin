package axiom_tests
// odin test src/axiom/test -define:ODIN_TEST_THREADS=1 -debug

import "core:mem"
import "core:testing"
import "base:runtime"
import "core:log"
import res"../resource"
import sc"../resource/scene"
import axiom".."
import xxh2 "../extensions/xxhash2"
import "vendor:glfw"
import "core:math/linalg"
import "core:math"

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
    axiom.init_memory(arena, mem.Megabyte * 1) // Adjust size as needed
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

    axiom.reset_memory_stack(test_ctx.mem_game)
    world := axiom.create_world(test_ctx.mem_game)
    return test_ctx
}

destroy_test_world :: proc(test_ctx : ^TestContext)
{
    defer axiom.destroy_memory_arena(test_ctx.mem_core)
    defer axiom.destroy_memory_arena(test_ctx.mem_area)
    defer axiom.destroy_memory_stack(test_ctx.mem_game)
    // defer axiom.destroy_world(test_ctx.mem_game)
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
// test_animation_system_comprehensive :: proc(t: ^testing.T) {
//     test_ctx := create_test_world()
//     defer destroy_test_world(test_ctx)

//     // Flatten entity test part
//     player := axiom.load_prefab("Test", test_ctx.mem_area.alloc)
//     testing.expect(t, player != axiom.Entity(0), "Failed to load Test prefab")

//     axiom.flatten_entity(player)
//     bfg_comp := axiom.get_component(player, axiom.Cmp_BFGraph)
//     testing.expect(t, bfg_comp != nil, "flatten_entity should add BFGraph")
//     testing.expect(t, len(bfg_comp.nodes) > 2, "BFGraph should have 2 nodes (root + 1 child)")

//     // Mock animation setup
//     anim_name := "test_anim"
//     start_name := "start"
//     end_name := "end"
//     new_end_name := "new_end"

//     anim_hash := xxh2.str_to_u32(anim_name)
//     start_hash := xxh2.str_to_u32(start_name)
//     end_hash := xxh2.str_to_u32(end_name)
//     new_end_hash := xxh2.str_to_u32(new_end_name)

//     start_pose_sqt := res.PoseSqt{id = 1, sqt_data = res.Sqt{pos = {0,0,0,0}, rot = linalg.QUATERNIONF32_IDENTITY, sca = {1,1,1,0}}}
//     end_pose_sqt := res.PoseSqt{id = 1, sqt_data = res.Sqt{pos = {1,1,1,0}, rot = linalg.QUATERNIONF32_IDENTITY, sca = {2,2,2,0}}}
//     new_end_pose_sqt := res.PoseSqt{id = 1, sqt_data = res.Sqt{pos = {3,3,3,0}, rot = linalg.QUATERNIONF32_IDENTITY, sca = {4,4,4,0}}}

//     context.allocator = context.temp_allocator
//     start_pose_dyn := make([dynamic]res.PoseSqt)
//     append(&start_pose_dyn, start_pose_sqt)
//     start_pose := res.Pose{name = start_name, pose = start_pose_dyn}

//     end_pose_dyn := make([dynamic]res.PoseSqt)
//     append(&end_pose_dyn, end_pose_sqt)
//     end_pose := res.Pose{name = end_name, pose = end_pose_dyn}

//     new_end_pose_dyn := make([dynamic]res.PoseSqt)
//     append(&new_end_pose_dyn, new_end_pose_sqt)
//     new_end_pose := res.Pose{name = new_end_name, pose = new_end_pose_dyn}

//     anim_poses := make(map[u32]res.Pose)
//     anim_poses[start_hash] = start_pose
//     anim_poses[end_hash] = end_pose
//     anim_poses[new_end_hash] = new_end_pose

//     anim := res.Animation{
//         name = anim_name,
//         poses = anim_poses,
//     }
//     res.animations[anim_hash] = anim

//     // sys_anim_add test
//     anim_comp := axiom.animation_component_with_hashes(2, anim_hash, start_hash, end_hash, {})
//     axiom.add_component(player, anim_comp)
//     axiom.sys_anim_add(player)

//     added_anim := axiom.get_component(player, axiom.Cmp_Animation)
//     testing.expect(t, added_anim != nil, "Animation component should be added")
//     // testing.expect(t, added_anim.flags.active == 1, "Animation should be active after add")

//     // Assume child id=1 (from flatten)
//     child_ent := bfg_comp.nodes[1]
//     child_animate := axiom.get_component(child_ent, axiom.Cmp_Animate)
//     testing.expect(t, child_animate != nil, "Child should have Animate component")
//     testing.expect(t, child_animate.start.pos == {0,0,0,0}, "Start pos matches pose")
//     testing.expect(t, child_animate.end.pos == {1,1,1,0}, "End pos matches pose")

//     // sys_anim_process_ecs / sys_anim_update test (interpolation)
//     axiom.sys_anim_update(player, 0.5) // dt=0.5, halfway for time=1.0 default?

//     updated_child_trans := axiom.get_component(child_ent, axiom.Cmp_Transform)
//     testing.expect(t, math.abs(updated_child_trans.local.pos.x - 0.5) < 0.01, "Pos interpolated halfway")

//     // Complete animation
//     axiom.sys_anim_update(player, 0.5)
//     testing.expect(t, math.abs(updated_child_trans.local.pos.x - 1.0) < 0.01, "Pos at end")

//     updated_animate := axiom.get_component(child_ent, axiom.Cmp_Animate)
//     testing.expect(t, axiom.check_if_finished(updated_child_trans.local, updated_animate), "Animation should be finished")

//     // sys_anim_transition test - set up component for transition
//     trans_anim_comp := axiom.get_component(player, axiom.Cmp_Animation)
//     trans_anim_comp.trans = end_hash
//     trans_anim_comp.trans_end = new_end_hash
//     trans_anim_comp.state = .TRANSITION

//     axiom.sys_anim_update(player, 0.1)  // Trigger transition (dt >0 to call sys_anim_transition)

//     trans_anim := axiom.get_component(player, axiom.Cmp_Animation)
//     testing.expect(t, trans_anim.trans_timer > 0, "Transition timer advanced")
//     testing.expect(t, trans_anim.trans == end_hash, "Trans set to previous end")
//     testing.expect(t, trans_anim.trans_end == new_end_hash, "Trans_end set to new end")

//     // Advance through transition
//     axiom.sys_anim_update(player, trans_anim.trans_time)  // Complete transition

//     trans_child_animate := axiom.get_component(child_ent, axiom.Cmp_Animate)
//     testing.expect(t, trans_child_animate.start.pos == {1,1,1,0}, "Start updated to prev end after transition")
//     testing.expect(t, trans_child_animate.end.pos == {3,3,3,0}, "End updated to new end")

//     // Deactivation test
//     axiom.sys_anim_deactivate_component(player)
//     deact_anim := axiom.get_component(player, axiom.Cmp_Animation)
//     testing.expect(t, deact_anim.flags.active == 0, "Animation deactivated")
//     testing.expect(t, axiom.get_component(child_ent, axiom.Cmp_Animate) == nil, "Child Animate removed")
// }

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
