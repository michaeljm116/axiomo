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

import "core:slice"
import "core:log"
import "core:mem"
import "base:intrinsics"

import "core:os"
import "core:fmt"
import "core:path/filepath"
import vk "vendor:vulkan"
import "vendor:glfw"
import "external/ecs"
import res "resource"
import sc "resource/scene"

g_world : ^ecs.World
g_world_ent : Entity
g_materials : [dynamic]res.Material
g_models : [dynamic]res.Model
g_level_dir := "../Assets/Levels/1_Jungle/"


track_alloc: mem.Tracking_Allocator

main :: proc() {
	mem.tracking_allocator_init(&track_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&track_alloc)
	defer leak_detection()

	g_world = ecs.create_world()
	g_world_ent = add_entity()
	add_component(g_world_ent, Cmp_Gui{
	    {0,0}, {1,1},
		{0,0}, {1,1},
		0, 1, 0, 0, false
	})

	defer ecs.delete_world(g_world)

	// Create an arena allocator using context.temp_allocator
	arena: mem.Arena
	arena_data: []byte = make([]byte, 1024 * 1024, context.temp_allocator) // 1 MiB
	mem.arena_init(&arena, arena_data)
	defer mem.arena_free_all(&arena)
	arena_alloc := mem.arena_allocator(&arena)

	context.logger = log.create_console_logger()
	defer free(context.logger.data)
	rb.ctx = context

	sc.load_new_scene("assets/1_Jungle/Scenes/PrefabMaker.json", arena_alloc)

	mod := res.load_pmodel("assets/froku.pm", arena_alloc)

	g_models = make([dynamic]res.Model, 0, arena_alloc)
	res.load_directory("assets/Models/", &g_models)
	g_materials = make([dynamic]res.Material, 0, arena_alloc)
	res.load_materials("assets/Materials.xml", &g_materials)

	poses := res.load_pose("assets/1_Jungle/Animations/Froku.anim", "Froku", arena_alloc)

	// TODO: update vendor bindings to glfw 3.4 and use this to set a custom allocator.
	// glfw.InitAllocator()

	// TODO: set up Vulkan allocator.
	start_up_raytracer(arena_alloc)

}

leak_detection :: proc()
{
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
