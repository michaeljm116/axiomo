package axiom
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:sync"
import vmem "core:mem/virtual"

MemoryArena :: struct
{
    arena: vmem.Arena,
    alloc : mem.Allocator,
    name : string,
}

MemoryStack :: struct
{
    stack : mem.Rollback_Stack,
    alloc : mem.Allocator,
    buffer : []u8,
    name : string
}

init_memory :: proc{init_memory_arena_growing, init_memory_arena_static, init_memory_stack}

init_memory_arena_growing :: proc(ma : ^MemoryArena, min_block_size :uint= vmem.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE)
{
    err := vmem.arena_init_growing(&ma.arena, min_block_size)
    if err == .None do  ma.alloc = vmem.arena_allocator(&ma.arena)
    else{
        fmt.println("Error Failed to allocate memory: ", err, "\n", context.logger)
        panic("Error Failed to allocate memory: ")
    }
}

init_memory_arena_static :: proc(ma : ^MemoryArena, reserved :uint= vmem.DEFAULT_ARENA_STATIC_RESERVE_SIZE, commit_size :uint= vmem.DEFAULT_ARENA_GROWING_COMMIT_SIZE)
{
    err := vmem.arena_init_static(&ma.arena, reserved, commit_size)
    if err == .None do ma.alloc = vmem.arena_allocator(&ma.arena)
    else{
        fmt.println("Error Failed to allocate memory: ", err, "\n", context.logger)
        panic("Error Failed to allocate memory: ")
    }
}


reset_memory_arena :: proc(ma : ^MemoryArena){
    vmem.arena_free_all(&ma.arena)
}
print_arena_usage :: proc(ma: ^MemoryArena) {
    fmt.printfln("Memory Arena '%v' Usage: Total Used = %v bytes, Total Reserved = %v bytes", ma.name, ma.arena.total_used, ma.arena.total_reserved)
}

init_memory_stack :: proc(ms : ^MemoryStack, size : u64){
   ms.buffer = make([]u8, size)
   mem.rollback_stack_init_buffered(&ms.stack, ms.buffer)
   ms.alloc = mem.rollback_stack_allocator(&ms.stack)
}

destroy_memory_stack :: proc(ms : ^MemoryStack){
    mem.rollback_stack_destroy(&ms.stack)
}
destroy_memory_arena :: proc(ma : ^MemoryArena){
    vmem.arena_destroy(&ma.arena)
}
reset_memory_stack :: proc(ms: ^MemoryStack){
    mem.rollback_stack_destroy(&ms.stack)
    delete(ms.buffer)
}

destroy_memory :: proc{destroy_memory_arena, destroy_memory_stack}

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
