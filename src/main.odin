package main

import "base:intrinsics"
import "base:runtime"

import "core:sys/windows"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import vmem "core:mem/virtual"

import "vendor:glfw"
import vk "vendor:vulkan"

import "external/ecs"
import res "resource"
import sc "resource/scene"

g_world: ^ecs.World
g_world_ent: Entity
g_materials: [dynamic]res.Material
g_models: [dynamic]res.Model
g_prefabs: map[string]sc.Node
g_ui_prefabs: map[string]sc.Node
g_scene: ^sc.SceneData
g_bvh: ^Sys_Bvh
g_enemies: map[string]Entity
g_player: Entity
g_texture_indexes : map[string]i32
g_animations : map[u32]res.Animation

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


main :: proc() {
    windows.SetConsoleOutputCP(windows.CODEPAGE.UTF8)
    //----------------------------------------------------------------------------\\
    // /MEMORY
    //----------------------------------------------------------------------------\\
    context.logger = log.create_console_logger()
	defer free(context.logger.data)
    init_tracking()
    // In init, after setting context.allocator
    defer detect_memory_leaks()
    set_up_all_arenas()
    defer destroy_all_arenas()
	rb.ctx = context

	//----------------------------------------------------------------------------\\
    // /Asset Loading
    //----------------------------------------------------------------------------\\
	g_materials = make([dynamic]res.Material, 0, mem_area.alloc)
	g_models = make([dynamic]res.Model, 0, mem_area.alloc)
	g_animations = make(map[u32]res.Animation, 0, mem_area.alloc)
	g_prefabs = make(map[string]sc.Node, 0, mem_area.alloc)
	g_ui_prefabs = make(map[string]sc.Node, 0, mem_area.alloc)

	res.load_materials("assets/Materials.xml", &g_materials)
	res.load_models("assets/models/", &g_models)
	res.load_anim_directory("assets/animations/", &g_animations, mem_area.alloc)
	sc.load_prefab_directory("assets/prefabs", &g_prefabs, mem_area.alloc)
	sc.load_prefab_directory("assets/prefabs/ui", &g_ui_prefabs, mem_core.alloc)

	//----------------------------------------------------------------------------\\
    // /Game Starting
    //----------------------------------------------------------------------------\\
	g_scene = sc.load_new_scene("assets/scenes/BeeKillingsInn.json", mem_scene.alloc)
	g_bvh = bvh_system_create(mem_core.alloc)
	start_up_raytracer(mem_area.alloc)
	gameplay_init()
	defer bvh_system_destroy(g_bvh)
	defer gameplay_destroy()

	// You need to have an ecs ready before you do the stuff below
	sys_trans_process_ecs()
	sys_bvh_process_ecs(g_bvh, mem_frame.alloc)

	// you need to have trannsformed and constructed a bh before stuff below
	initialize_raytracer()
	glfw.PollEvents()
	g_frame.prev_time = glfw.GetTime()

	//----------------------------------------------------------------------------\\
    // /Game Updating
    //----------------------------------------------------------------------------\\
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
			sys_visual_process_ecs(f32(g_frame.physics_time_step))
			sys_anim_process_ecs(f32(g_frame.physics_time_step))
			sys_trans_process_ecs()
			sys_bvh_process_ecs(g_bvh, mem_frame.alloc)
			// print_tracking_stats(&mem_track)
			gameplay_update(f32(g_frame.physics_time_step))
			reset_memory_arena(&mem_frame)
			g_frame.physics_acc_time -= f32(g_frame.physics_time_step)
		}
		update_buffers()
		update_descriptors()
		end_frame(&image_index)
		free_all(context.temp_allocator)
	}
	cleanup()
}
