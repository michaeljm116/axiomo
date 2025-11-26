package game
// odin test src/test -define:ODIN_TEST_THREADS=1

import "../axiom/external/ode_ecs"
import "core:mem"
import "core:testing"
import "../axiom"
import "base:runtime"

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

@(test)
test_table_creation_and_reuse :: proc(t: ^testing.T) {
    mem_stack := create_test_memory_stack()
    defer axiom.destroy_memory_stack(mem_stack)

    axiom.g_world = axiom.create_world(mem_stack)
    defer axiom.destroy_world(mem_stack)

    // Before adding any component, table should not exist
    tid := typeid_of(axiom.Cmp_Transform)
    _, found_before := axiom.g_world.tables[tid]
    testing.expect(t, !found_before, "Table should not exist before adding component")

    // Add entity and component
    e1 := axiom.add_entity()
    trans1 := axiom.cmp_transform_prs({0,0,0}, {0,0,0}, {1,1,1})
    added_trans1,_  := axiom.add_component_typeid(e1, axiom.Cmp_Transform)//(e1, trans1)
    // mem.copy(added_trans1, &trans1, size_of(axiom.Cmp_Transform))
    // added_trans1^.local.pos.x = 1
    // testing.expect(t, ok != ode_ecs.API_Error.None, "API error when adding typeid")
    table := axiom.get_table(axiom.Cmp_Transform)
    testing.expect(t, added_trans1 != nil, "Failed to add first Cmp_Transform")

    // // After add, table should exist
    // _, found_after := axiom.g_world.tables[tid]
    // testing.expect(t, found_after, "Table should be created after adding component")

    // table1 := axiom.get_table(axiom.Cmp_Transform)
    // testing.expect(t, table1 != nil, "get_table should return non-nil after creation")

    // // Add second entity and same component type
    // e2 := axiom.add_entity()
    // trans2 := axiom.cmp_transform_prs({1,1,1}, {0,0,0}, {2,2,2})
    // added_trans2 := axiom.add_component(e2, trans2)
    // testing.expect(t, added_trans2 != nil, "Failed to add second Cmp_Transform")

    // // Table should be the same (reused)
    // table2 := axiom.get_table(axiom.Cmp_Transform)
    // testing.expect(t, table1 == table2, "Table should be reused for same component type")

    // // Verify table length increased
    // testing.expect(t, axiom.table_len(table2) == 2, "Table should have 2 components now")

    // // Test adding another table to the same entity
    // root := axiom.Cmp_Root{}
    // added_root := axiom.add_component(e1, root)
    // testing.expect(t, added_root != nil, "Failed to add Cmp_Root")
}

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

//     player := axiom.load_prefab("Froku", mem_arena.alloc)
//     testing.expect(t, true, "Froku loaded")
//     bee := axiom.load_prefab("Bee", mem_arena.alloc)
//     testing.expect(t, true, "Bee loaded")

//     // scene := axiom.set_new_scene("assets/scenes/Empty.json", mem_arena)
//     // axiom.load_scene(scene^, mem_stack.alloc)
//     // testing.expect(t, true, "Scene loaded")
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

@(test)
truetest :: proc(t: ^testing.T){
    testing.expect(t, true, "truthtest")
}
