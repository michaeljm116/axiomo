package game

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

//--------------------------------------------------------------------------------\\
// /Globals
//--------------------------------------------------------------------------------\\
Game_Memory :: struct
{
    world: ^ecs.World,
    world_ent: Entity,
    scene : ^sc.SceneData,
    frame : FrameRate,
    player : Entity,

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
    level : Level,
    dice :  [2]Dice,
    ui_keys: [dynamic]string,

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
    mem_scene : MemoryArena,                  // This holds the scene data from the json, should be reset upon scene change
    mem_game : MemoryArena,                   // This holds game data, reset upon restarting of a game, ecs goes here
    mem_frame : MemoryArena,                  // Mostly for BVH or anything that exist for a single frame
}

g: ^Game_Memory
g_renderbase : ^RenderBase
g_raytracer : ^ComputeRaytracer
g_mem_core : MemoryArena                   // Memory that persists througout the whole game
g_mem_area : MemoryArena                   // Main memory for loading of resources of an area of the game
g_materials : [dynamic]res.Material
g_models : [dynamic]res.Model
g_prefabs : map[string]sc.Node
g_ui_prefabs : map[string]sc.Node
g_gui  : map[string]Entity
g_bvh : ^Sys_Bvh
g_texture_indexes : map[string]i32
g_animations : map[u32]res.Animation

//--------------------------------------------------------------------------------\\
// /Game Initializing
//--------------------------------------------------------------------------------\\
@(export)
game_init_window :: proc(){
    set_up_core_arenas()
    g_renderbase = new(RenderBase, g_mem_core.alloc)
    g_raytracer = new(ComputeRaytracer, g_mem_area.alloc)
    glfw.SetErrorCallback(glfw_error_callback)
    if !glfw.Init() {log.panic("glfw: could not be initialized")}

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
    glfw.WindowHint(glfw.DECORATED, glfw.TRUE)

    // Get monitor and set to full screen
    primary_monitor := glfw.GetPrimaryMonitor()
    mode := glfw.GetVideoMode(primary_monitor)
    g_renderbase.monitor_width = c.int(f64(mode.width) * 0.5)
    g_renderbase.monitor_height =  c.int(f64(mode.height) * 0.5)
    g_renderbase.window = glfw.CreateWindow(g_renderbase.monitor_width, g_renderbase.monitor_height, "Bee Killins Inn", nil, nil)
    glfw.SetFramebufferSizeCallback(g_renderbase.window, proc "c" (_: glfw.WindowHandle, _, _: i32) {
        g_renderbase.framebuffer_resized = true
    })
    init_vulkan()
    set_camera()
}

@(export)
game_init :: proc() {
    g = new(Game_Memory)
    set_up_game_arenas()
	g_renderbase.ctx = context

	//----------------------------------------------------------------------------\\
    // /Asset Loading
    //----------------------------------------------------------------------------\\
    windows.SetConsoleOutputCP(windows.CODEPAGE.UTF8)
	g_materials = make([dynamic]res.Material, 0, g_mem_area.alloc)
	g_models = make([dynamic]res.Model, 0, g_mem_area.alloc)
	g_animations = make(map[u32]res.Animation, 0, g_mem_area.alloc)
	g_prefabs = make(map[string]sc.Node, 0, g_mem_area.alloc)
	g_ui_prefabs = make(map[string]sc.Node, 0, g_mem_area.alloc)

	res.load_materials("assets/config/Materials.xml", &g_materials)
	res.load_models("assets/models/", &g_models)
	res.load_anim_directory("assets/animations/", &g_animations, g_mem_area.alloc)
	sc.load_prefab_directory("assets/prefabs", &g_prefabs, g_mem_area.alloc)
	sc.load_prefab_directory("assets/prefabs/ui", &g_ui_prefabs, g_mem_core.alloc)

	//----------------------------------------------------------------------------\\
    // /Game Starting
    //----------------------------------------------------------------------------\\
    g.frame = FrameRate {
       	prev_time         = glfw.GetTime(),
       	curr_time         = 0,
       	wait_time         = 0,
       	delta_time        = 0,
       	target            = 120.0,
       	target_dt         = (1.0 / 120.0),
       	locked            = true,
       	physics_acc_time  = 0,
       	physics_time_step = 1.0 / 60.0,}
    g.scene = set_new_scene("assets/scenes/BeeKillingsInn.json")
	g_bvh = bvh_system_create(g_mem_core.alloc)
	start_up_raytracer(g_mem_area.alloc)

	app_init()

	// You need to have an ecs ready before you do the stuff below
	sys_trans_process_ecs()
	sys_bvh_process_ecs(g_bvh, g.mem_frame.alloc)

	// you need to have trannsformed and constructed a bh before stuff below
	initialize_raytracer()
	glfw.PollEvents()
	g.frame.prev_time = glfw.GetTime()
}

//--------------------------------------------------------------------------------\\
// /Game Updating
//--------------------------------------------------------------------------------\\
@(export)
game_should_run :: proc() -> bool{
    if glfw.WindowShouldClose(g_renderbase.window) do return false
    return true
}
@(export)
game_update :: proc(){
	start_frame(&g_renderbase.image_index)
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
		app_update(f32(g.frame.physics_time_step))
		g.frame.physics_acc_time -= f32(g.frame.physics_time_step)
	}
	sys_bvh_process_ecs(g_bvh, g.mem_frame.alloc)
	update_buffers()
	update_descriptors()
	end_frame(&g_renderbase.image_index)
	reset_memory_arena(&g.mem_frame)
}

//--------------------------------------------------------------------------------\\
// /Game Shutdown
//--------------------------------------------------------------------------------\\
@(export)
game_shutdown :: proc(){
    cleanup()
    app_destroy()
    bvh_system_destroy(g_bvh)
    destroy_all_arenas()
    free_all(context.temp_allocator)
}

@(export)
game_shutdown_window :: proc(){
    glfw.DestroyWindow(g_renderbase.window)
}

//--------------------------------------------------------------------------------\\
// /Hot Reload
//--------------------------------------------------------------------------------\\
@(export)
game_memory :: proc() -> rawptr{
    return g
}
@(export)
game_memory_size :: proc() -> int{
    return size_of(Game_Memory)
}
@(export)
game_hot_reloaded :: proc(mem:rawptr){
    g = (^Game_Memory)(mem)
    app_restart()
}
@(export)
game_force_reload :: proc() -> bool{
    return is_key_just_pressed(glfw.KEY_F5)
}
@(export)
game_force_restart :: proc() -> bool{
    return is_key_just_pressed(glfw.KEY_F6)
}
