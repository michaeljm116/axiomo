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
	print_resource_strings(6)
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
			// print_tracking_stats(&mem_track)
			gameplay_update(f32(g_frame.physics_time_step))
			g_frame.physics_acc_time -= f32(g_frame.physics_time_step)
		}
		sys_bvh_process_ecs(g_bvh, mem_frame.alloc)
		update_buffers()
		update_descriptors()
		end_frame(&image_index)
		reset_memory_arena(&mem_frame)
		free_all(context.temp_allocator)

		print_resource_strings(10)
	}
	cleanup()
}

// ...existing code...

// Quick debug printers for globals
print_frame_info :: proc() {
    if &g_frame == nil {
        fmt.println("Frame: <nil>")
        return
    }
    fmt.printfln("Frame: target=%.2f delta_time=%.6f physics_step=%.6f\n",
        g_frame.target, g_frame.delta_time, g_frame.physics_time_step)
}

print_resource_info :: proc() {
    fmt.printfln("Resources: materials=%d models=%d animations=%d\n",
        len(g_materials), len(g_models), len(g_animations))
    fmt.printfln("Prefabs: ui=%d scene=%d\n", len(g_ui_prefabs), len(g_prefabs))
    fmt.printfln("Textures=%d enemies=%d\n", len(g_texture_indexes), len(g_enemies))
}

// Print first `limit` keys from a string->Node map
print_prefab_keys :: proc(prefabs: map[string]sc.Node, limit: int) {
    i := 0
    for k, _ in prefabs {
        fmt.printfln("  prefab: %s\n", k)
        i += 1
        if i >= limit {
            break
        }
    }
    if i == 0 {
        fmt.println("  (no prefabs)")
    }
}

// Print first `limit` keys from a string->Entity map
print_enemy_keys :: proc(enemies: map[string]Entity, limit: int) {
    i := 0
    for k, _ in enemies {
        fmt.printfln("  enemy: %s\n", k)
        i += 1
        if i >= limit {
            break
        }
    }
    if i == 0 {
        fmt.println("  (no enemies)")
    }
}

print_world_info :: proc() {
    if g_world == nil {
        fmt.println("World: <nil>")
    } else {
        fmt.printfln("World pointer: %v\n", g_world)
        fmt.printfln("World entity root: %v player: %v\n", g_world_ent, g_player)
    }
}

// High level summary of important globals
print_globals_summary :: proc(limit_keys: int) {
    fmt.println("=== Globals Summary ===")
    print_frame_info()
    print_resource_info()
    print_world_info()

    fmt.println("Sample prefabs:")
    print_prefab_keys(g_prefabs, limit_keys)

    fmt.println("Sample UI prefabs:")
    print_prefab_keys(g_ui_prefabs, limit_keys)

    fmt.println("Sample enemies:")
    print_enemy_keys(g_enemies, limit_keys)

    fmt.println("Animation keys (first few):")
    j := 0
    for k, _ in g_animations {
        fmt.printfln("  anim key: %d\n", k)
        j += 1
        if j >= limit_keys { break }
    }
    fmt.println("=======================")
}
// ...existing code...

// diagnostic counter used to call heavier dumps periodically
g_frame_counter: int = 0

// Dump a few materials (struct dump, shows embedded strings)
print_materials_dump :: proc(limit: int) {
    i := 0
    for i < len(g_materials) && i < limit {
        fmt.printfln("material[%d]: %v", i, g_materials[i])
        i += 1
    }
    if len(g_materials) == 0 {
        fmt.println("  (no materials)")
    }
}

// Dump a few models (struct dump, shows embedded strings/paths)
print_models_dump :: proc(limit: int) {
    i := 0
    for i < len(g_models) && i < limit {
        fmt.printfln("model[%d]: %v", i, g_models[i])
        i += 1
    }
    if len(g_models) == 0 {
        fmt.println("  (no models)")
    }
}

// Dump some animations (key + struct dump)
print_animations_dump :: proc(limit: int) {
    j := 0
    for k, v in g_animations {
        fmt.printfln("anim key=%d -> %v", k, v)
        j += 1
        if j >= limit { break }
    }
    if len(g_animations) == 0 {
        fmt.println("  (no animations)")
    }
}

// List texture key strings (these are the primary string keys for your textures)
print_texture_keys :: proc(limit: int) {
    i := 0
    for k, _ in g_texture_indexes {
        fmt.printfln("texture key: %s", k)
        i += 1
        if i >= limit { break }
    }
    if i == 0 {
        fmt.println("  (no texture keys)")
    }
}

// Higher-level resource string dump (calls the specific dumps)
print_resource_strings :: proc(limit: int) {
    fmt.println("=== Resource String Dump ===")
    fmt.printfln("materials: %d  models: %d  animations: %d  textures: %d",
        len(g_materials), len(g_models), len(g_animations), len(g_texture_indexes))
    fmt.println("-- materials --")
    print_materials_dump(limit)
    // fmt.println("-- models --")
    // print_models_dump(limit)
    fmt.println("-- animations --")
    print_animations_dump(limit)
    fmt.println("-- texture keys --")
    print_texture_keys(limit)
    fmt.println("============================")
}
