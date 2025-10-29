package main
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:sync"
import vmem "core:mem/virtual"


MemoryArena :: struct
{
    arena: mem.Arena,
    alloc : mem.Allocator,
    buffer : []byte,
    name : string
}

mem_track: mem.Tracking_Allocator       // To track the memory leaks
mem_core :MemoryArena                   // Memory that persists througout the whole game
mem_area :MemoryArena                   // Main memory for loading of resources of an area of the game
mem_scene :MemoryArena                  // This holds the scene data from the json, should be reset upon scene change
mem_game :MemoryArena                   // This holds game data, reset upon restarting of a game, ecs goes here
mem_frame :MemoryArena                  // Mostly for BVH or anything that exist for a single frame

GlobalDataStruct :: struct{}
g_data : GlobalDataStruct

set_up_all_arenas :: proc()
{
    init_memory_arena(&mem_core, mem.Megabyte * 1)
    init_memory_arena(&mem_area, mem.Megabyte * 1)
    init_memory_arena(&mem_scene, mem.Megabyte * 1)
    init_memory_arena(&mem_game, mem.Megabyte * 1)
    init_memory_arena(&mem_frame, mem.Kilobyte * 16)
    mem_core.name = "core"
    mem_area.name = "area"
    mem_scene.name = "scene"
    mem_game.name = "game"
    mem_frame.name = "frame"
}

destroy_all_arenas :: proc()
{
    destroy_memory_arena(&mem_core)
    destroy_memory_arena(&mem_area)
    destroy_memory_arena(&mem_scene)
    destroy_memory_arena(&mem_game)
    destroy_memory_arena(&mem_frame)
}

init_tracking :: proc()
{
    default_alloc := context.allocator
    mem.tracking_allocator_init(&mem_track, default_alloc)
    context.allocator = mem.tracking_allocator(&mem_track)
}

detect_memory_leaks :: proc() {
	fmt.eprintf("\n")
	for _, entry in mem_track.allocation_map {
		fmt.eprintf("- %v leaked %v bytes\n", entry.location, entry.size)
	}
	for entry in mem_track.bad_free_array {
		fmt.eprintf("- %v bad free\n", entry.location)
	}
	mem.tracking_allocator_destroy(&mem_track)
	fmt.eprintf("\n")
	free_all(context.temp_allocator)
}


init_memory_arena ::#force_inline proc(ma : ^MemoryArena, reserved :uint= vmem.DEFAULT_ARENA_STATIC_RESERVE_SIZE)
{
    ma.buffer = make([]byte, reserved, mem_track.backing)
    mem.arena_init(&ma.arena, ma.buffer)
    ma.alloc = mem.arena_allocator(&ma.arena)
}

destroy_memory_arena ::#force_inline proc(ma : ^MemoryArena){
    delete(ma.buffer)
    reset_memory_arena(ma)
}

reset_memory_arena ::#force_inline proc(ma : ^MemoryArena){
    mem.arena_free_all(&ma.arena)
}

print_arena_usage ::#force_inline proc(ma: ^MemoryArena) {
    fmt.printfln("Memory Arena '%v' Usage: Total Used = %v bytes, Total Reserved = %v bytes", ma.name)
}
print_all_arenas :: proc()
{
    print_arena_usage(&mem_core)
	print_arena_usage(&mem_area)
	print_arena_usage(&mem_scene)
	print_arena_usage(&mem_game)
	print_arena_usage(&mem_frame)
}

print_tracking_stats :: proc(ta: ^mem.Tracking_Allocator) {
    sync.lock(&ta.mutex)
    defer sync.unlock(&ta.mutex)

    fmt.printfln("Tracking Allocator Stats:")
    fmt.printfln("  Current Memory Allocated: %v bytes", ta.current_memory_allocated)
    fmt.printfln("  Peak Memory Allocated: %v bytes", ta.peak_memory_allocated)
    fmt.printfln("  Total Memory Allocated: %v bytes", ta.total_memory_allocated)
    fmt.printfln("  Total Allocation Count: %v", ta.total_allocation_count)
    fmt.printfln("  Total Memory Freed: %v bytes", ta.total_memory_freed)
    fmt.printfln("  Total Free Count: %v", ta.total_free_count)
    fmt.printfln("  Active Allocations: %v", len(ta.allocation_map))
    fmt.printfln("  Bad Frees: %v", len(ta.bad_free_array))
    fmt.printfln("  Clear on Free All: %v", ta.clear_on_free_all)
}
