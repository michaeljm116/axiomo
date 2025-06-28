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

track_alloc: mem.Tracking_Allocator

main :: proc() {
	mem.tracking_allocator_init(&track_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&track_alloc)
	defer leak_detection()

	// Create an arena allocator using context.temp_allocator
	arena: mem.Arena
	arena_data: []byte = make([]byte, 1024 * 1024, context.temp_allocator) // 1 MiB
	mem.arena_init(&arena, arena_data)
	defer mem.arena_free_all(&arena)
	arena_alloc := mem.arena_allocator(&arena)

	context.logger = log.create_console_logger()
	defer free(context.logger.data)
	rb.ctx = context

	load_new_scene("assets/1_Jungle/Scenes/PrefabMaker.json", arena_alloc)

	mod := load_pmodel("assets/froku.pm", arena_alloc)

	models : [dynamic]Model = make([dynamic]Model, 0, arena_alloc)
	defer delete(models)
	load_directory("assets/Models/", &models)

	mats : [dynamic]AMaterial = make([dynamic]AMaterial, 0, arena_alloc)
	res_load_materials("assets/Materials.xml", &mats)
	defer delete(mats)
	for m in mats do fmt.println(m.name)

	poses := res_load_pose("assets/1_Jungle/Animations/Froku.anim", "Froku", arena_alloc)

	// TODO: update vendor bindings to glfw 3.4 and use this to set a custom allocator.
	// glfw.InitAllocator()

	// TODO: set up Vulkan allocator.
	init_vulkan()

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
