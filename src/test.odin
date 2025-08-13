package main

import "core:testing"
import ecs "external/ecs"

@(test)
test_get_last_sibling :: proc(t: ^testing.T) {
    // Set up test world
    test_world := ecs.create_world()
    defer ecs.delete_world(test_world)
    
    // Store original world and restore it after test
    original_world := g_world
    g_world = test_world
    defer {
        g_world = original_world
    }
    
    // Test Case 1: Single child (should return itself)
    parent1 := ecs.add_entity(test_world)
    child1 := ecs.add_entity(test_world)
    
    parent1_node := node_component_default(parent1)
    child1_node := node_component_default(child1)
    
    ecs.add_component(test_world, parent1, parent1_node)
    ecs.add_component(test_world, child1, child1_node)
    
    add_child(parent1, child1)
    
    child1_node_ptr := get_component(child1, Cmp_Node)
    last_sibling := get_last_sibling(child1_node_ptr)
    
    testing.expect(t, last_sibling == child1_node_ptr, "Single child should return itself as last sibling")
    
    // Test Case 2: Multiple siblings
    parent2 := ecs.add_entity(test_world)
    child2_1 := ecs.add_entity(test_world)
    child2_2 := ecs.add_entity(test_world)
    child2_3 := ecs.add_entity(test_world)
    
    parent2_node := node_component_default(parent2)
    child2_1_node := node_component_default(child2_1)
    child2_2_node := node_component_default(child2_2)
    child2_3_node := node_component_default(child2_3)
    
    ecs.add_component(test_world, parent2, parent2_node)
    ecs.add_component(test_world, child2_1, child2_1_node)
    ecs.add_component(test_world, child2_2, child2_2_node)
    ecs.add_component(test_world, child2_3, child2_3_node)
    
    // Add children in sequence
    add_child(parent2, child2_1)
    add_child(parent2, child2_2)
    add_child(parent2, child2_3)
    
    // Get node pointers after they've been added to the ECS
    child2_1_node_ptr := get_component(child2_1, Cmp_Node)
    child2_2_node_ptr := get_component(child2_2, Cmp_Node)
    child2_3_node_ptr := get_component(child2_3, Cmp_Node)
    
    // Test getting last sibling from first child
    last_from_first := get_last_sibling(child2_1_node_ptr)
    testing.expect(t, last_from_first == child2_3_node_ptr, "Last sibling from first child should be the third child")
    
    // Test getting last sibling from middle child
    last_from_middle := get_last_sibling(child2_2_node_ptr)
    testing.expect(t, last_from_middle == child2_3_node_ptr, "Last sibling from middle child should be the third child")
    
    // Test getting last sibling from last child
    last_from_last := get_last_sibling(child2_3_node_ptr)
    testing.expect(t, last_from_last == child2_3_node_ptr, "Last sibling from last child should return itself")
    
    // Test Case 3: Two siblings only
    parent3 := ecs.add_entity(test_world)
    child3_1 := ecs.add_entity(test_world)
    child3_2 := ecs.add_entity(test_world)
    
    parent3_node := node_component_default(parent3)
    child3_1_node := node_component_default(child3_1)
    child3_2_node := node_component_default(child3_2)
    
    ecs.add_component(test_world, parent3, parent3_node)
    ecs.add_component(test_world, child3_1, child3_1_node)
    ecs.add_component(test_world, child3_2, child3_2_node)
    
    add_child(parent3, child3_1)
    add_child(parent3, child3_2)
    
    child3_1_node_ptr := get_component(child3_1, Cmp_Node)
    child3_2_node_ptr := get_component(child3_2, Cmp_Node)
    
    last_from_first_of_two := get_last_sibling(child3_1_node_ptr)
    testing.expect(t, last_from_first_of_two == child3_2_node_ptr, "Last sibling from first of two should be the second")
    
    last_from_second_of_two := get_last_sibling(child3_2_node_ptr)
    testing.expect(t, last_from_second_of_two == child3_2_node_ptr, "Last sibling from second of two should return itself")
}