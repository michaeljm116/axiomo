/*
Vulkan triangle example by laytan, source:
https://gist.github.com/laytan/ba57af3e5a59ab5cb2fca9e25bcfe262

Compile and run using:

	odin run .

This example comes with pre-compiled shaders. During compilation the shaders
will be loaded from `vert.spv` and `frag.spv`.

If you make any changes to the shader source files (`shader.vert` or
`shader.frag`), then you must recompile them using `glslc`:

	glslc shader.vert -o vert.spv
	glslc shader.frag -o frag.spv

`glslc` is part of the Vulkan SDK, which you can find here:
https://vulkan.lunarg.com/sdk/home

This example uses glfw for window management.
*/
package main

import "base:runtime"

import "base:intrinsics"
import "core:log"
import "core:mem"
import "core:slice"

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "external/ecs"
import res "resource"
import sc "resource/scene"
import "vendor:glfw"
import vk "vendor:vulkan"

g_world: ^ecs.World
g_world_ent: Entity
g_materials: [dynamic]res.Material
g_models: [dynamic]res.Model
g_level_dir := "../Assets/Levels/1_Jungle/"
g_scene: [dynamic]Entity
g_bvh: ^Sys_Bvh

track_alloc: mem.Tracking_Allocator

main :: proc() {
	fmt.println("HI")
	mem.tracking_allocator_init(&track_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&track_alloc)
	defer leak_detection()

	g_world = ecs.create_world()
	g_world_ent = add_entity()
	defer bvh_system_destroy(g_bvh)

	add_component(g_world_ent, Cmp_Gui{{0, 0}, {1, 1}, {0, 0}, {1, 1}, 0, 1, 0, 0, false})

	defer ecs.delete_world(g_world)

	// Create an arena allocator for long-lived allocations (e.g., materials, models, scenes)
	arena: mem.Arena
	arena_data: []byte = make([]byte, 1024 * 1024 * 120, context.allocator) // 120 MiB; backing on heap for persistence
	mem.arena_init(&arena, arena_data)
	defer delete(arena_data) // Explicitly free backing buffer at program end
	defer mem.arena_free_all(&arena) // Free all allocations from the arena (though defer delete handles backing)
	arena_alloc := mem.arena_allocator(&arena)

	// Create a per-frame arena for transient data (e.g., BVH construction primitives/nodes)
	per_frame_arena: mem.Arena
	per_frame_arena_data: []byte = make([]byte, 1024 * 1024 * 8, context.allocator) // 8 MiB example; monitor with tracking allocator
	mem.arena_init(&per_frame_arena, per_frame_arena_data)
	defer delete(per_frame_arena_data) // Explicitly free backing buffer at program end
	defer mem.arena_free_all(&per_frame_arena) // Free all (though typically reset per frame)
	per_frame_alloc := mem.arena_allocator(&per_frame_arena)

	g_bvh = bvh_system_create(per_frame_alloc)


	context.logger = log.create_console_logger()
	defer free(context.logger.data)
	rb.ctx = context


	// begin loading data
	g_materials = make([dynamic]res.Material, 0, arena_alloc)
	res.load_materials("assets/Materials.xml", &g_materials)
	scene := sc.load_new_scene("assets/1_Jungle/Scenes/PrefabMaker2.json", arena_alloc)
	mod := res.load_pmodel("assets/froku.pm", arena_alloc)
	g_models = make([dynamic]res.Model, 0, arena_alloc)
	res.load_directory("assets/Models/", &g_models)
	poses := res.load_pose("assets/1_Jungle/Animations/Froku.anim", "Froku", arena_alloc)

	//Begin renderer and scene loading
	start_up_raytracer(arena_alloc)
	load_scene(scene, arena_alloc)
	transform_sys_process()
	bvh_system_build(g_bvh, per_frame_alloc)
	//	gameplay_init()

	//begin renderer
	initialize_raytracer()
	glfw.PollEvents()
	start_frame(&image_index)

	//Update renderer
	for !glfw.WindowShouldClose(rb.window) {
		end_frame(&image_index)
		// Poll and free: Move to main loop if overlapping better
		glfw.PollEvents()
//		free_all(context.temp_allocator)

		start_frame(&image_index)
	//	gameplay_update(0.015)
		transform_sys_process()
		bvh_system_build(g_bvh, per_frame_alloc)
		update_descriptors()

		// Reset per-frame arena after all frame processing (ensures data is used before free)
		mem.arena_free_all(&per_frame_arena)
	}
	vk.DeviceWaitIdle(rb.device)
	destroy_vulkan()
}

leak_detection :: proc() {
	fmt.eprintf("\n")
	for _, entry in track_alloc.allocation_map {
		fmt.eprintf("- %v leaked %v bytes\n", entry.location, entry.size)
	}
	for entry in track_alloc.bad_free_array {
		fmt.eprintf("- %v bad free\n", entry.location)
	}
	mem.tracking_allocator_destroy(&track_alloc)
	fmt.eprintf("\n")
	free_all(context.temp_allocator)
}
