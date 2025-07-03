package main
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"
import "core:strings"
import "core:slice"
import "core:log"
import "external/vma"

curr_id : u32 = 0
MAX_MATERIALS :: 256
MAX_MESHES :: 2048
MAX_VERTS :: 32768
MAX_INDS :: 16384
MAX_OBJS :: 4096
MAX_LIGHTS :: 32
MAX_GUIS :: 96
MAX_NODES :: 2048
MAX_BINDLESS_TEXTURES :: 256

/*
ComputeRaytracer :: struct {
    // System state
    editor: bool,

    // Descriptor pool and graphics pipeline state
    descriptor_pool: vk.DescriptorPool,
    graphics: struct {
        descriptor_set_layout: vk.DescriptorSetLayout,
        descriptor_set: vk.DescriptorSet,
        pipeline_layout: vk.PipelineLayout,
        pipeline: vk.Pipeline,
    },

    // Compute pipeline state
    compute: struct {
        storage_buffers: struct {
            verts: VBuffer(ssVert),
            faces: VBuffer(ssIndex),
            blas: VBuffer(ssBVHNode),
            shapes: VBuffer(ssShape),
            primitives: VBuffer(ssPrimitive),
            materials: VBuffer(ssMaterial),
            lights: VBuffer(ssLight),
            guis: VBuffer(ssGUI),
            bvh: VBuffer(ssBVHNode),
        },
        queue: vk.Queue,
        command_pool: vk.CommandPool,
        command_buffer: vk.CommandBuffer,
        fence: vk.Fence,
        descriptor_set_layout: vk.DescriptorSetLayout,
        descriptor_set: vk.DescriptorSet,
        pipeline_layout: vk.PipelineLayout,
        pipeline: vk.Pipeline,
        ubo: struct {
            rotM: mat4f,
            fov: f32,
            aspect_ratio: f32,
            rand: i32,
        },
        uniform_buffer: VBuffer(struct {
            rotM: mat4f,
            fov: f32,
            aspect_ratio: f32,
            rand: i32,
        }),
    },

    // Scene data
    primitives: []ssPrimitive,
    materials: []ssMaterial,
    lights: []ssLight,
    guis: []ssGUI,
    bvh: []ssBVHNode,

    mesh_comps: []MeshComponent,
    // objectComps: []PrimitiveComponent, // Uncomment/adapt as needed
    // jointComps: []JointComponent, // Uncomment/adapt as needed
    light_comps: []LightComponent,

    mesh_assigner: map[i32][2]int,
    joint_assigner: map[i32][2]int,
    shape_assigner: map[i32][2]int,

    // Texture state
    compute_texture: Texture,
    gui_textures: [MAX_TEXTURES]Texture,
    bindless_textures: []Texture,

    // Compute helpers
    compute_write_descriptor_sets: []vk.WriteDescriptorSet,

    // BVH helpers
    ordered_prims_map: []int,

    // Misc
    prepared: bool,
}

raytracer: ComputeRaytracer



// VBuffer struct to manage Vulkan buffers and their memory
VBuffer :: struct {
    buffer: vk.Buffer,
    allocation: vma.Allocation,
    buffer_info: vk.DescriptorBufferInfo,
}

// Initialize a uniform buffer with the provided data
init_uniform_buffer :: proc(vb: ^VBuffer, rc: ^RenderBase, data: $T) {
    size := u64(size_of(T))
    create_buffer(rc, size, {.UNIFORM_BUFFER}, &vb.allocation, &vb.buffer)
    vb.buffer_info = vk.DescriptorBufferInfo{buffer = vb.buffer, offset = 0, range = size}
    mapped: rawptr
    must(vma.MapMemory(rc.vma_allocator, vb.allocation, &mapped))
    mem.copy(mapped, &data, size_of(T))
    vma.UnmapMemory(rc.vma_allocator, vb.allocation)
}

// Initialize a storage buffer with the provided data and maximum count
init_storage_buffer :: proc(vb: ^VBuffer, rc: ^RenderBase, data: []$T, max_count: int) {
    size := u64(size_of(T) * max_count)
    create_buffer(rc, size, {.STORAGE_BUFFER}, &vb.allocation, &vb.buffer)
    vb.buffer_info = vk.DescriptorBufferInfo{buffer = vb.buffer, offset = 0, range = size}
    if len(data) > 0 {
        mapped: rawptr
        must(vma.MapMemory(rc.vma_allocator, vb.allocation, &mapped))
        mem.copy(mapped, raw_data(data), size_of(T) * len(data))
        vma.UnmapMemory(rc.vma_allocator, vb.allocation)
    }
}

// Initialize a storage buffer using a staging buffer for data transfer
init_storage_buffer_with_staging :: proc(vb: ^VBuffer, rc: ^RenderBase, data: []$T) {
    size := u64(size_of(T) * len(data))
    staging_buffer: vk.Buffer
    staging_allocation: vma.Allocation
    create_buffer(rc, size, {.TRANSFER_SRC}, &staging_allocation, &staging_buffer)
    mapped: rawptr
    must(vma.MapMemory(rc.vma_allocator, staging_allocation, &mapped))
    mem.copy(mapped, raw_data(data), int(size))
    vma.UnmapMemory(rc.vma_allocator, staging_allocation)

    create_buffer(rc, size, {.STORAGE_BUFFER, .TRANSFER_DST}, &vb.allocation, &vb.buffer)
    vb.buffer_info = vk.DescriptorBufferInfo{buffer = vb.buffer, offset = 0, range = size}

    cmd := begin_single_time_commands(rc)
    copy_region := vk.BufferCopy{srcOffset = 0, dstOffset = 0, size = size}
    vk.CmdCopyBuffer(cmd, staging_buffer, vb.buffer, 1, &copy_region)
    end_single_time_commands(rc, &cmd)

    vma.DestroyBuffer(rc.vma_allocator, staging_buffer, staging_allocation)
}

// Update the buffer with new data
update_buffer :: proc(vb: ^VBuffer, rc: ^RenderBase, data: []$T) {
    size := u64(size_of(T) * len(data))
    mapped: rawptr
    must(vma.MapMemory(rc.vma_allocator, vb.allocation, &mapped))
    mem.copy(mapped, raw_data(data), int(size))
    vma.UnmapMemory(rc.vma_allocator, vb.allocation)
}

// Destroy the VBuffer and free its resources
destroy_vbuffer :: proc(vb: ^VBuffer, rc: ^RenderBase) {
    vma.DestroyBuffer(rc.vma_allocator, vb.buffer, vb.allocation)
}

// Example usage in a compute raytracer
prepare_storage_buffers :: proc(cr: ^ComputeRaytracer) {
    reserve(&cr.materials, MAX_MATERIALS)
    reserve(&cr.lights, MAX_LIGHTS)
    reserve(&cr.primitives, MAX_OBJS)
    reserve(&cr.guis, MAX_GUIS)
    reserve(&cr.bvh, MAX_NODES)

    init_storage_buffer(&cr.compute.storage_buffers.primitives, cr.rc, cr.primitives[:], MAX_OBJS)
    init_storage_buffer(&cr.compute.storage_buffers.materials, cr.rc, cr.materials[:], MAX_MATERIALS)
    init_storage_buffer(&cr.compute.storage_buffers.lights, cr.rc, cr.lights[:], MAX_LIGHTS)
    init_storage_buffer(&cr.compute.storage_buffers.guis, cr.rc, cr.guis[:], MAX_GUIS)
    init_storage_buffer(&cr.compute.storage_buffers.bvh, cr.rc, cr.bvh[:], MAX_NODES)

    // GUI initialization example
    gui_comp := get_singleton_gui_component(cr.world)
    if gui_comp != nil {
        gui := ssGUI{
            min = gui_comp.min,
            extents = gui_comp.extents,
            alignMin = gui_comp.alignMin,
            alignExt = gui_comp.alignExt,
            layer = gui_comp.layer,
            id = gui_comp.id,
            alpha = gui_comp.alpha,
        }
        gui_comp.ref = i32(len(cr.guis))
        append(&cr.guis, gui)
        update_buffer(&cr.compute.storage_buffers.guis, cr.rc, cr.guis[:])
    }
}
*/