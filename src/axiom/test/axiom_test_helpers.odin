package axiom_tests
// odin test src/axiom/test -define:ODIN_TEST_THREADS=1 -debug

import "core:mem"
import "base:runtime"
import res"../resource"
import sc"../resource/scene"
import axiom".."
import "vendor:glfw"

TestContext :: struct {
    mem_core : ^axiom.MemoryArena,
    mem_area : ^axiom.MemoryArena,
    mem_game : ^axiom.MemoryStack,
    world : ^axiom.World,
    frame : axiom.FrameRate,
}

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


load_assets :: proc(alloc : mem.Allocator)
{
    res.materials = make([dynamic]res.Material, 0, alloc)
	res.models = make([dynamic]res.Model, 0, alloc)
	res.animations = make(map[u32]res.Animation, 0, alloc)

	res.scenes = make(map[string]^sc.SceneData, 0, alloc)
	res.prefabs = make(map[string]sc.Node, 0, alloc)
	res.ui_prefabs = make(map[string]sc.Node, 0, alloc)

	res.load_materials("assets/config/Materials.xml", &res.materials)
	res.load_models("assets/models/", &res.models)
	res.load_anim_directory("assets/animations/", &res.animations, alloc)

	sc.load_scene_directory("assets/scenes", &res.scenes, alloc)
	sc.load_prefab_directory("assets/prefabs", &res.prefabs, alloc)
	sc.load_prefab_directory("assets/prefabs/ui", &res.ui_prefabs, alloc)
}

create_frame :: proc() -> axiom.FrameRate
{
    frame := axiom.FrameRate {
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
    return frame
}

create_test_world :: proc() -> ^TestContext
{
    test_ctx := new(TestContext)
    test_ctx^ = TestContext{
        mem_core = create_test_memory_arena(),
        mem_area = create_test_memory_arena(),
        mem_game = create_test_memory_stack(),
        frame = create_frame(),
    }
    test_ctx.mem_core.name = "core"
    test_ctx.mem_area.name = "area"
    test_ctx.mem_game.name = "game"

    axiom.g_renderbase = new(axiom.RenderBase, test_ctx.mem_core.alloc)
    axiom.g_raytracer = new(axiom.ComputeRaytracer, test_ctx.mem_core.alloc)
    axiom.window_init(context)
    axiom.window_input_init()
    axiom.window_renderer_init()
    axiom.init_vulkan()
    axiom.g_renderbase.ctx = context

    load_assets(test_ctx.mem_area.alloc)

    axiom.g_bvh = axiom.bvh_system_create(test_ctx.mem_core.alloc)
    axiom.g_physics = axiom.sys_physics_create(test_ctx.mem_core.alloc)
    axiom.start_up_raytracer(test_ctx.mem_area.alloc)
    frame := create_frame()

    axiom.reset_memory_stack(test_ctx.mem_game)
    world := axiom.create_world(test_ctx.mem_game)
    return test_ctx
}

destroy_test_world :: proc(test_ctx : ^TestContext)
{
    defer delete(test_ctx.mem_game.buffer)
    defer free(test_ctx.mem_game)
    defer free(test_ctx.mem_area)
    defer free(test_ctx.mem_core)
    defer axiom.destroy_memory_arena(test_ctx.mem_core)
    defer axiom.destroy_memory_arena(test_ctx.mem_area)
    defer axiom.destroy_memory_stack(test_ctx.mem_game)

    glfw.SetKeyCallback(axiom.g_window.handle, nil)
    glfw.SetCursorPosCallback(axiom.g_window.handle, nil)
    glfw.SetMouseButtonCallback(axiom.g_window.handle, nil)
    glfw.SetInputMode(axiom.g_window.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
    axiom.bvh_system_destroy(axiom.g_bvh)
    axiom.cleanup()

    free_all(context.temp_allocator)

    free(test_ctx)
}
