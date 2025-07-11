/*
    These are data structues that go into the GPU
    The structures must be laid out in a particular way
*/
package gpu
import math "core:math/linalg"
import "../external/vma"
import vk "vendor:vulkan"
import "core:mem"
import "core:log"

//----------------------------------------------------------------------------\\
// /STRUCTS
//----------------------------------------------------------------------------\\
vec4i :: [4]i32
quat :: math.Quaternionf32
vec3 :: math.Vector3f32
vec4 :: math.Vector4f32
mat4 :: math.Matrix4f32


// Helper types for vectors/matrices
vec2f :: [2]f32
vec3f :: [3]f32
mat4f :: [4][4]f32


Gui :: struct {
    min:        vec2f,
    extents:    vec2f,
    align_min:  vec2f,
    align_ext:  vec2f,
    layer:      i32,
    id:         i32,
    pad:        i32,
    alpha:      f32,
}

Primitive :: struct {
    world:      mat4f,
    extents:    vec3f,
    num_children: i32,
    id:         i32,
    mat_id:     i32,
    start_index: i32,
    end_index:   i32,
}

Vert :: struct {
    pos:    vec3f,
    u:      f32,
    norm:   vec3f,
    v:      f32,
}

TriangleIndex :: struct {
    v:      [3]i32,
    id:     i32,
}

Index :: struct {
    v:      [4]i32,
}

Shape :: struct {
    center:     vec3f,
    mat_id:     i32,
    extents:    vec3f,
    type:       i32,
}

Light :: struct {
    pos:        vec3f,
    intensity:  f32,
    color:      vec3f,
    id:         i32,
}

Material :: struct {
    diffuse : vec3,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32
}

BvhNode :: struct {
    upper: vec3,
    offset: i32,
    lower: vec3,
    num_children: i32,
}

//----------------------------------------------------------------------------\\
// /BUFFER
//----------------------------------------------------------------------------\\
VBuffer :: struct($T : typeid) {
    buffer: vk.Buffer,
    alloc: vma.Allocation,
    buffer_info: vk.DescriptorBufferInfo,
    data: T,
    initialized: bool,
}

// Basic uniform buffer initialization
vbuffer_initialize :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator) {
    buffer_size := vk.DeviceSize(size_of(T))

    buffer_create_info := vk.BufferCreateInfo{
        sType = .BUFFER_CREATE_INFO,
        size = buffer_size,
        usage = {.UNIFORM_BUFFER},
        sharingMode = .EXCLUSIVE,
    }

    alloc_create_info := vma.AllocationCreateInfo{
        usage = .CPU_TO_GPU,
        flags = {.MAPPED},
    }

    result := vma.create_buffer(allocator, &buffer_create_info, &alloc_create_info, &vbuf.buffer, &vbuf.alloc, nil)
    assert(result == .SUCCESS)

    vbuf.buffer_info = vk.DescriptorBufferInfo{
        buffer = vbuf.buffer,
        offset = 0,
        range = buffer_size,
    }

    vbuf.initialized = true
}

// Custom initialization with specific parameters
vbuffer_init_custom :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, mul: u32, usage: vk.BufferUsageFlags, memory_usage: vma.MemoryUsage) {
    buffer_size := vk.DeviceSize(size_of(T) * mul)

    buffer_create_info := vk.BufferCreateInfo{
        sType = .BUFFER_CREATE_INFO,
        size = buffer_size,
        usage = usage,
        sharingMode = .EXCLUSIVE,
    }

    alloc_create_info := vma.AllocationCreateInfo{
        usage = memory_usage,
    }

    if memory_usage == .CPU_TO_GPU || memory_usage == .CPU_ONLY {
        alloc_create_info.flags = {.MAPPED}
    }

    result := vma.CreateBuffer(allocator^, &buffer_create_info, &alloc_create_info, &vbuf.buffer, &vbuf.alloc, nil)
    assert(result == .SUCCESS)

    vbuf.buffer_info = vk.DescriptorBufferInfo{
        buffer = vbuf.buffer,
        offset = 0,
        range = buffer_size,
    }

    vbuf.initialized = true
}

vbuffer_init :: proc{
    vbuffer_initialize,
    vbuffer_init_custom,
}

// Initialize storage buffer with data
vbuffer_initialize_storage_buffer :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, objects: []T, usage: vk.BufferUsageFlags = {.VERTEX_BUFFER, .INDEX_BUFFER, .STORAGE_BUFFER, .TRANSFER_DST}, memory_usage: vma.MemoryUsage = .CPU_TO_GPU) {
    buffer_size := vk.DeviceSize(len(objects) * size_of(T))

    buffer_create_info := vk.BufferCreateInfo{
        sType = .BUFFER_CREATE_INFO,
        size = buffer_size,
        usage = usage,
        sharingMode = .EXCLUSIVE,
    }

    alloc_create_info := vma.AllocationCreateInfo{
        usage = memory_usage,
    }

    if memory_usage == .CPU_TO_GPU || memory_usage == .CPU_ONLY {
        alloc_create_info.flags = {.MAPPED}
    }

    result := vma.CreateBuffer(allocator^, &buffer_create_info, &alloc_create_info, &vbuf.buffer, &vbuf.alloc, nil)
    assert(result == .SUCCESS)

    // Map and copy data if using CPU accessible memory
    if memory_usage == .CPU_TO_GPU || memory_usage == .CPU_ONLY {
        data_ptr: rawptr
        vma.MapMemory(allocator^, vbuf.alloc, &data_ptr)
        mem.copy(data_ptr, raw_data(objects), int(buffer_size))
        vma.UnmapMemory(allocator^, vbuf.alloc)
    }

    vbuf.buffer_info = vk.DescriptorBufferInfo{
        buffer = vbuf.buffer,
        offset = 0,
        range = buffer_size,
    }

    vbuf.initialized = true
}

// Initialize storage buffer with custom size (allocates more than needed)
vbuffer_init_storage_buffer_custom_size :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, objects: []T, max_count: u32, usage: vk.BufferUsageFlags = {.VERTEX_BUFFER, .INDEX_BUFFER, .STORAGE_BUFFER, .TRANSFER_DST}, memory_usage: vma.MemoryUsage = .CPU_TO_GPU) {
    data_size := vk.DeviceSize(len(objects) * size_of(T))
    max_buffer_size := vk.DeviceSize(max_count * size_of(T))

    buffer_create_info := vk.BufferCreateInfo{
        sType = .BUFFER_CREATE_INFO,
        size = max_buffer_size,
        usage = usage,
        sharingMode = .EXCLUSIVE,
    }

    alloc_create_info := vma.AllocationCreateInfo{
        usage = memory_usage,
    }

    if memory_usage == .CPU_TO_GPU || memory_usage == .CPU_ONLY {
        alloc_create_info.flags = {.MAPPED}
    }

    must(vma.CreateBuffer(allocator^, &buffer_create_info, &alloc_create_info, &vbuf.buffer, &vbuf.alloc, nil))

    // Map and copy initial data if using CPU accessible memory
    if memory_usage == .CPU_TO_GPU || memory_usage == .CPU_ONLY {
        data_ptr: rawptr
        vma.MapMemory(allocator^, vbuf.alloc, &data_ptr)
        mem.copy(data_ptr, raw_data(objects), int(data_size))
        vma.UnmapMemory(allocator^, vbuf.alloc)
    }

    vbuf.buffer_info = vk.DescriptorBufferInfo{
        buffer = vbuf.buffer,
        offset = 0,
        range = data_size, // Use actual data size, not max size
    }

    vbuf.initialized = true
}

// Initialize storage buffer with staging (for GPU-only memory)
vbuffer_init_storage_buffer_with_staging :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, device: vk.Device, cmd_pool: vk.CommandPool, queue: vk.Queue, objects: []T, usage: vk.BufferUsageFlags = {.VERTEX_BUFFER, .INDEX_BUFFER, .STORAGE_BUFFER, .TRANSFER_DST}) {
    buffer_size := vk.DeviceSize(len(objects) * size_of(T))

    // Create staging buffer
    staging_buffer: vk.Buffer
    staging_alloc: vma.Allocation

    create_buffer_with_device(device, allocator, buffer_size, {.TRANSFER_SRC}, .CPU_ONLY, &staging_buffer, &staging_alloc)

    // Map and copy data to staging buffer
    data_ptr: rawptr
    vma.MapMemory(allocator^, staging_alloc, &data_ptr)
    mem.copy(data_ptr, raw_data(objects), int(buffer_size))
    vma.UnmapMemory(allocator^, staging_alloc)

    // Create device local buffer
    create_buffer_with_device(device, allocator, buffer_size, usage, .GPU_ONLY, &vbuf.buffer, &vbuf.alloc)

    // Copy from staging to device local buffer
    copy_buffer_with_device(device, cmd_pool, queue, staging_buffer, vbuf.buffer, buffer_size)

    // Cleanup staging buffer
    vma.DestroyBuffer(allocator^, staging_buffer, staging_alloc)

    vbuf.buffer_info = vk.DescriptorBufferInfo{
        buffer = vbuf.buffer,
        offset = 0,
        range = buffer_size,
    }

    vbuf.initialized = true
}

// Initialize storage buffer with staging using device-based approach (similar to C++ version)
vbuffer_init_storage_buffer_with_staging_device :: proc(vbuf: ^VBuffer($T), device: vk.Device, allocator: ^vma.Allocator, command_pool: vk.CommandPool, queue: vk.Queue, objects: []T, mul: u32, usage: vk.BufferUsageFlags = {.VERTEX_BUFFER, .INDEX_BUFFER, .STORAGE_BUFFER, .TRANSFER_DST}) {
    buffer_size := vk.DeviceSize(size_of(T) * mul)

    // Create staging buffer
    staging_buffer: vk.Buffer
    staging_alloc: vma.Allocation

    create_buffer_with_device(device, allocator, buffer_size, {.TRANSFER_SRC}, .CPU_ONLY, &staging_buffer, &staging_alloc)

    // Map and copy data to staging buffer
    data_ptr: rawptr
    vma.MapMemory(allocator^, staging_alloc, &data_ptr)
    mem.copy(data_ptr, raw_data(objects), int(buffer_size))
    vma.UnmapMemory(allocator^, staging_alloc)

    // Create device local buffer
    create_buffer_with_device(device, allocator, buffer_size, usage, .GPU_ONLY, &vbuf.buffer, &vbuf.alloc)

    // Copy from staging to device local buffer
    copy_buffer_with_device(device, command_pool, queue, staging_buffer, vbuf.buffer, buffer_size)

    // Cleanup staging buffer
    vma.DestroyBuffer(allocator^, staging_buffer, staging_alloc)

    vbuf.buffer_info = vk.DescriptorBufferInfo{
        buffer = vbuf.buffer,
        offset = 0,
        range = buffer_size,
    }

    vbuf.initialized = true
}

vbuffer_init_storage_buffer :: proc{
   vbuffer_initialize_storage_buffer,
   vbuffer_init_storage_buffer_custom_size,
   vbuffer_init_storage_buffer_with_staging,
   vbuffer_init_storage_buffer_with_staging_device,
}

// Update buffer contents
vbuffer_update :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, objects: []T) {
    if !vbuf.initialized do return

    data_ptr: rawptr
    vma.MapMemory(allocator^, vbuf.alloc, &data_ptr)
    mem.copy(data_ptr, raw_data(objects), int(vbuf.buffer_info.range))
    vma.UnmapMemory(allocator^, vbuf.alloc)
}

// Update buffer and expand the used range
vbuffer_update_and_expand :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, objects: []T, size: u32) {
    if !vbuf.initialized do return

    vbuf.buffer_info.range = vk.DeviceSize(size_of(T) * size)

    data_ptr: rawptr
    vma.MapMemory(allocator^, vbuf.alloc, &data_ptr)
    mem.copy(data_ptr, raw_data(objects), int(vbuf.buffer_info.range))
    vma.UnmapMemory(allocator^, vbuf.alloc)
}

// Apply changes from the internal data member
vbuffer_apply_changes_no_data :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator) {
    if !vbuf.initialized do return

    data_ptr: rawptr
    vma.MapMemory(allocator^, vbuf.alloc, &data_ptr)
    mem.copy(data_ptr, &vbuf.data, size_of(T))
    vma.UnmapMemory(allocator^, vbuf.alloc)
}

// Apply changes from provided data
vbuffer_apply_changes_with_data :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator, data: ^T) {
    if !vbuf.initialized do return

    data_ptr: rawptr
    vma.MapMemory(allocator^, vbuf.alloc, &data_ptr)
    mem.copy(data_ptr, data, size_of(T))
    vma.UnmapMemory(allocator^, vbuf.alloc)
}

vbuffer_apply_changes :: proc{
   vbuffer_apply_changes_no_data,
   vbuffer_apply_changes_with_data,
}

// Helper function to begin single time commands
begin_single_time_commands :: proc(device: vk.Device, command_pool: vk.CommandPool) -> vk.CommandBuffer {
    alloc_info := vk.CommandBufferAllocateInfo{
        sType = .COMMAND_BUFFER_ALLOCATE_INFO,
        level = .PRIMARY,
        commandPool = command_pool,
        commandBufferCount = 1,
    }

    command_buffer: vk.CommandBuffer
    must(vk.AllocateCommandBuffers(device, &alloc_info, &command_buffer))

    begin_info := vk.CommandBufferBeginInfo{
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = {.ONE_TIME_SUBMIT},
    }

    must(vk.BeginCommandBuffer(command_buffer, &begin_info))
    return command_buffer
}

// Helper function to end single time commands
end_single_time_commands :: proc(device: vk.Device, command_pool: vk.CommandPool, queue: vk.Queue, command_buffer: ^vk.CommandBuffer) {
    must(vk.EndCommandBuffer(command_buffer^))

    submit_info := vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers = command_buffer,
    }

    must(vk.QueueSubmit(queue, 1, &submit_info, 0))
    must(vk.QueueWaitIdle(queue))

    vk.FreeCommandBuffers(device, command_pool, 1, command_buffer)
}

// Helper function to create buffer with device
create_buffer_with_device :: proc(device: vk.Device, allocator: ^vma.Allocator, size: vk.DeviceSize, usage: vk.BufferUsageFlags, memory_usage: vma.MemoryUsage, buffer: ^vk.Buffer, alloc: ^vma.Allocation) {
    buffer_create_info := vk.BufferCreateInfo{
        sType = .BUFFER_CREATE_INFO,
        size = size,
        usage = usage,
        sharingMode = .EXCLUSIVE,
    }

    alloc_create_info := vma.AllocationCreateInfo{
        usage = memory_usage,
    }

    if memory_usage == .CPU_TO_GPU || memory_usage == .CPU_ONLY {
        alloc_create_info.flags = {.MAPPED}
    }

    result := vma.CreateBuffer(allocator^, &buffer_create_info, &alloc_create_info, buffer, alloc, nil)
    assert(result == .SUCCESS)
}

// Helper function to copy buffer using device commands
copy_buffer_with_device :: proc(device: vk.Device, command_pool: vk.CommandPool, queue: vk.Queue, src_buffer: vk.Buffer, dst_buffer: vk.Buffer, size: vk.DeviceSize) {
    command_buffer := begin_single_time_commands(device, command_pool)

    copy_region := vk.BufferCopy{
        size = size,
    }

    vk.CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region)

    end_single_time_commands(device, command_pool, queue, &command_buffer)
}

// Destroy buffer and free memory
vbuffer_destroy :: proc(vbuf: ^VBuffer($T), allocator: ^vma.Allocator) {
    if vbuf.initialized {
        vma.DestroyBuffer(allocator^, vbuf.buffer, vbuf.alloc)
        vbuf.initialized = false
        vbuf.buffer = {}
        vbuf.alloc = {}
        vbuf.buffer_info = {}
    }
}

// Helper procedure for copying buffers using a command buffer
copy_buffer_immediate :: proc(device: vk.Device, cmd_pool: vk.CommandPool, queue: vk.Queue, src_buffer: vk.Buffer, dst_buffer: vk.Buffer, size: vk.DeviceSize) {
    alloc_info := vk.CommandBufferAllocateInfo{
        sType = .COMMAND_BUFFER_ALLOCATE_INFO,
        level = .PRIMARY,
        commandPool = cmd_pool,
        commandBufferCount = 1,
    }

    cmd_buffer: vk.CommandBuffer
    must(vk.AllocateCommandBuffers(device, &alloc_info, &cmd_buffer))

    begin_info := vk.CommandBufferBeginInfo{
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = {.ONE_TIME_SUBMIT},
    }

    must(vk.BeginCommandBuffer(cmd_buffer, &begin_info))

    copy_region := vk.BufferCopy{
        size = size,
    }

    vk.CmdCopyBuffer(cmd_buffer, src_buffer, dst_buffer, 1, &copy_region)

    must(vk.EndCommandBuffer(cmd_buffer))

    submit_info := vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers = &cmd_buffer,
    }

    must(vk.QueueSubmit(queue, 1, &submit_info, 0))
    must(vk.QueueWaitIdle(queue))

    vk.FreeCommandBuffers(device, cmd_pool, 1, &cmd_buffer)
}

must :: proc(result: vk.Result, loc := #caller_location) {
	if result != .SUCCESS {
		log.panicf("vulkan failure %v", result, location = loc)
	}
}