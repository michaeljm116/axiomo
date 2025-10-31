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
import "core:strings"

import "vendor:glfw"
import vk "vendor:vulkan"

import "external/ecs"
import res "resource"
import sc "resource/scene"
import "core:c"

Game_Memory :: struct
{
    world: ^ecs.World,
    world_ent: Entity,
    materials: [dynamic]res.Material,
    models: [dynamic]res.Model,
    prefabs: map[string]sc.Node,
    ui_prefabs: map[string]sc.Node,
    gui : map[string]Entity,
    scene: ^sc.SceneData,
    bvh: ^Sys_Bvh,
    enemies: map[string]Entity,
    player: Entity,
    texture_indexes : map[string]i32,
    animations : map[u32]res.Animation,
    frame : FrameRate,

    mem_core : MemoryArena,                   // Memory that persists througout the whole game
    mem_area : MemoryArena,                   // Main memory for loading of resources of an area of the game
    mem_scene : MemoryArena,                  // This holds the scene data from the json, should be reset upon scene change
    mem_game : MemoryArena,                   // This holds game data, reset upon restarting of a game, ecs goes here
    mem_frame : MemoryArena,                  // Mostly for BVH or anything that exist for a single frame
    mem_track: mem.Tracking_Allocator,       // To track the memory leaks

    rb : RenderBase,
    rt : ComputeRaytracer,
    monitor_width : c.int,
    monitor_height : c.int,

    // RENDER
    dbg_messenger: vk.DebugUtilsMessengerEXT,
    current_frame: int,
    image_index: u32,
    font: Font,
    curr_id : u32,
    texture_paths : [1]string,

    // gameplay
    input: InputState,
    camera_entity: Entity,
    light_entity: Entity,
    light_orbit_radius : f32,
    light_orbit_speed : f32,   // radians per second,
    light_orbit_angle : f32,

    floor : Entity,
    objects : [2][dynamic]Entity,

    // BKS
    state : GameState,
    current_bee: int,
    level :Level,
    dice :  [2]Dice,

    bee_selection : int,
    bee_is_near : bool,
    pt_state : PlayerInputState,

    app_state : AppState,
    title : Entity,
    titleAnim : MenuAnimation,
    main_menu : Entity,
    main_menuAnim : MenuAnimation,

    game_started : bool,
    ves : VisualEventData,
}
g: ^Game_Memory


main :: proc() {
    windows.SetConsoleOutputCP(windows.CODEPAGE.UTF8)
    //----------------------------------------------------------------------------\\
    // /MEMORY
    //----------------------------------------------------------------------------\\
    g = new(Game_Memory)
    context.logger = log.create_console_logger()
	defer free(context.logger.data)
    init_tracking()
    // In init, after setting context.allocator
    defer detect_memory_leaks()

    set_up_all_arenas()
    defer destroy_all_arenas()
	g.rb.ctx = context

	g.frame = FrameRate {
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
	//----------------------------------------------------------------------------\\
    // /Asset Loading
    //----------------------------------------------------------------------------\\
	g.materials = make([dynamic]res.Material, 0, g.mem_area.alloc)
	g.models = make([dynamic]res.Model, 0, g.mem_area.alloc)
	g.animations = make(map[u32]res.Animation, 0, g.mem_area.alloc)
	g.prefabs = make(map[string]sc.Node, 0, g.mem_area.alloc)
	g.ui_prefabs = make(map[string]sc.Node, 0, g.mem_area.alloc)

	res.load_materials("assets/Materials.xml", &g.materials)
	res.load_models("assets/models/", &g.models)
	res.load_anim_directory("assets/animations/", &g.animations, g.mem_area.alloc)
	sc.load_prefab_directory("assets/prefabs", &g.prefabs, g.mem_area.alloc)
	sc.load_prefab_directory("assets/prefabs/ui", &g.ui_prefabs, g.mem_core.alloc)

	//----------------------------------------------------------------------------\\
    // /Game Starting
    //----------------------------------------------------------------------------\\
	g.scene = sc.load_new_scene("assets/scenes/BeeKillingsInn.json", g.mem_scene.alloc)
	g.bvh = bvh_system_create(g.mem_core.alloc)
	start_up_raytracer(g.mem_area.alloc)
	gameplay_init()
	defer bvh_system_destroy(g.bvh)
	defer gameplay_destroy()

	// You need to have an ecs ready before you do the stuff below
	sys_trans_process_ecs()
	sys_bvh_process_ecs(g.bvh, g.mem_frame.alloc)

	// you need to have trannsformed and constructed a bh before stuff below
	initialize_raytracer()
	glfw.PollEvents()
	g.frame.prev_time = glfw.GetTime()
	//----------------------------------------------------------------------------\\
    // /Game Updating
    //----------------------------------------------------------------------------\\
	for !glfw.WindowShouldClose(g.rb.window) {
		start_frame(&image_index)
		// Poll and free: Move to main loop if overlapping better
		glfw.PollEvents()
		g.frame.curr_time = glfw.GetTime()
		frame_time := g.frame.curr_time - g.frame.prev_time
		g.frame.prev_time = g.frame.curr_time
		if frame_time > 0.25 {frame_time = 0.25}
		g.frame.delta_time = f32(frame_time)
		g.frame.physics_acc_time += f32(frame_time)
		for g.frame.physics_acc_time >= f32(g.frame.physics_time_step) {
			sys_visual_process_ecs(f32(g.frame.physics_time_step))
			sys_anim_process_ecs(f32(g.frame.physics_time_step))
			sys_trans_process_ecs()
			// print_tracking_stats(&g.mem_track)
			gameplay_update(f32(g.frame.physics_time_step))
			g.frame.physics_acc_time -= f32(g.frame.physics_time_step)
		}
		sys_bvh_process_ecs(g.bvh, g.mem_frame.alloc)
		update_buffers()
		update_descriptors()
		end_frame(&image_index)
		reset_memory_arena(&g.mem_frame)
		free_all(context.temp_allocator)
	}
	cleanup()
}
