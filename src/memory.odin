package main
import "base:runtime"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"


MemoryArena :: struct
{
    arena: vmem.Arena,
    alloc : mem.Allocator
}

mem_area :MemoryArena                   // Main memory for loading of resources of an area of the game
mem_scene :MemoryArena                  // This holds the scene data from the json, should be reset upon scene change
mem_game :MemoryArena                   // This holds game data, reset upon restarting of a game, ecs goes here
mem_frame :MemoryArena                  // Mostly for BVH or anything that exist for a single frame
mem_track: mem.Tracking_Allocator       // To track the memory leaks

GlobalDataStruct :: struct{}
g_data : GlobalDataStruct

set_up_all_arenas :: proc()
{
    init_memory_arena_growing(&mem_area, mem.Megabyte * 64)
    init_memory_arena_growing(&mem_scene, mem.Megabyte * 8)
    init_memory_arena_growing(&mem_game, mem.Megabyte * 40)
    init_memory_arena_static(&mem_frame, mem.Megabyte * 16, mem.Megabyte)
}

destroy_all_arenas :: proc()
{
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

init_memory_arena :: proc{init_memory_arena_growing, init_memory_arena_static}

@(private)
init_memory_arena_growing :: proc(ma : ^MemoryArena, min_block_size :uint= vmem.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE)
{
    err := vmem.arena_init_growing(&ma.arena, min_block_size)
    if err == .None do  ma.alloc = vmem.arena_allocator(&ma.arena)
    else{
        fmt.println("Error Failed to allocate memory: ", err, "\n", context.logger)
        panic("Error Failed to allocate memory: ")
    }
}

@(private)
init_memory_arena_static :: proc(ma : ^MemoryArena, reserved :uint= vmem.DEFAULT_ARENA_STATIC_RESERVE_SIZE, commit_size :uint= vmem.DEFAULT_ARENA_GROWING_COMMIT_SIZE)
{
    err := vmem.arena_init_static(&ma.arena, reserved, commit_size)
    if err == .None do ma.alloc = vmem.arena_allocator(&ma.arena)
    else{
        fmt.println("Error Failed to allocate memory: ", err, "\n", context.logger)
        panic("Error Failed to allocate memory: ")
    }
}

destroy_memory_arena :: proc(ma : ^MemoryArena){
    vmem.arena_destroy(&ma.arena)
}
reset_memory_arena :: proc(ma : ^MemoryArena){
    vmem.arena_free_all(&ma.arena)
}
