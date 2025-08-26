package main

import "base:intrinsics"
import "base:runtime"

import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:slice"

import "vendor:glfw"
import vk "vendor:vulkan"

import "external/ecs"
import res "resource"
import sc "resource/scene"

g_world: ^ecs.World
g_world_ent: Entity
g_materials: [dynamic]res.Material
g_models: [dynamic]res.Model
g_scene: [dynamic]Entity
g_bvh: ^Sys_Bvh
g_enemies: map[string]Entity
g_player: Entity


g_frame := FrameRate {
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

arena_alloc: mem.Allocator
track_alloc: mem.Tracking_Allocator
ecs_alloc: mem.Allocator

main :: proc() {
	mem.tracking_allocator_init(&track_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&track_alloc)
	defer leak_detection()

	// Create an arena allocator for long-lived allocations (e.g., materials, models, scenes)
	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena, mem.Megabyte * 16) // Start at 16 MiB, grow to 1 GiB max
	assert(arena_err == nil)
	//arena_data: []byte = make([]byte, mem.Megabyte * 120, context.allocator) // 120 MiB; backing on heap for persistence
	//mem.arena_init(&arena, arena_data)
	//defer delete(arena_data) // Explicitly free backing buffer at program end
	defer vmem.arena_free_all(&arena) // Free all allocations from the arena (though defer delete handles backing)
	arena_alloc = vmem.arena_allocator(&arena)


	// Create a per-frame arena for transient data (e.g., BVH construction primitives/nodes)
	per_frame_arena: mem.Arena
	per_frame_arena_data: []byte = make([]byte, mem.Megabyte * 8, context.allocator) // 8 MiB example; monitor with tracking allocator
	mem.arena_init(&per_frame_arena, per_frame_arena_data)
	defer delete(per_frame_arena_data) // Explicitly free backing buffer at program end
	defer mem.arena_free_all(&per_frame_arena) // Free all (though typically reset per frame)
	per_frame_alloc := mem.arena_allocator(&per_frame_arena)

	g_world = create_world()
	//defer delete_world()
	g_world_ent = add_entity()

	defer bvh_system_destroy(g_bvh)

	add_component(g_world_ent, Cmp_Gui{{0, 0}, {1, 1}, {0, 0}, {1, 1}, 0, 1, 0, 0, false})

	g_bvh = bvh_system_create(per_frame_alloc)

	context.logger = log.create_console_logger()
	defer free(context.logger.data)
	rb.ctx = context

	// begin loading data
	g_materials = make([dynamic]res.Material, 0, arena_alloc)
	res.load_materials("assets/Materials.xml", &g_materials)
	scene := sc.load_new_scene("assets/scenes/JetpackJoy.json", arena_alloc)
	g_models = make([dynamic]res.Model, 0, arena_alloc)
	res.load_directory("assets/models/", &g_models)
	poses := res.load_pose("assets/animations/Froku.anim", "Froku", arena_alloc)

	//Begin renderer and scene loading
	start_up_raytracer(arena_alloc)
	load_scene(scene, context.allocator)
	g_player := load_prefab2("assets/prefabs/", "Froku", resource_alloc = arena_alloc)

	transform_sys_process_e()
	bvh_system_build(g_bvh, per_frame_alloc)
	gameplay_init()

	//begin renderer
	initialize_raytracer()
	glfw.PollEvents()
	g_frame.prev_time = glfw.GetTime()
	// gameplay_update(0.015)
	// if true do return
	//Update renderer
	for !glfw.WindowShouldClose(rb.window) {
		start_frame(&image_index)
		// Poll and free: Move to main loop if overlapping better
		glfw.PollEvents()
		g_frame.curr_time = glfw.GetTime()
		frame_time := g_frame.curr_time - g_frame.prev_time
		g_frame.prev_time = g_frame.curr_time
		if frame_time > 0.25 {frame_time = 0.25}
		g_frame.delta_time = f32(frame_time)
		g_frame.physics_acc_time += f32(frame_time)
		for g_frame.physics_acc_time >= f32(g_frame.physics_time_step) {
			gameplay_update(f32(g_frame.physics_time_step))
			transform_sys_process_e()
			bvh_system_build(g_bvh, per_frame_alloc)
			mem.arena_free_all(&per_frame_arena)
			g_frame.physics_acc_time -= f32(g_frame.physics_time_step)
		}
		update_buffers()
		update_descriptors()
		end_frame(&image_index)
	}
	gameplay_destroy()
	cleanup()
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
