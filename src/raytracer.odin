package main
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"
import "core:strings"
import "core:slice"
import "core:log"
import "external/vma"
import "gpu"

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

raytracer: ComputeRaytracer

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
            verts: gpu.VBuffer(gpu.Vert),
            faces: gpu.VBuffer(gpu.Index),
            blas: gpu.VBuffer(gpu.BvhNode),
            shapes: gpu.VBuffer(gpu.Shape),
            primitives: gpu.VBuffer(gpu.Primitive),
            materials: gpu.VBuffer(gpu.Material),
            lights: gpu.VBuffer(gpu.Light),
            guis: gpu.VBuffer(gpu.Gui),
            bvh: gpu.VBuffer(gpu.BvhNode),
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
        uniform_buffer: gpu.VBuffer(struct {
            rotM: mat4f,
            fov: f32,
            aspect_ratio: f32,
            rand: i32,
        }),
    },

    // Scene data
    primitives: []gpu.Primitive,
    materials: []gpu.Material,
    lights: []gpu.Light,
    guis: []gpu.Gui,
    bvh: []gpu.BvhNode,

    mesh_comps: []Cmp_Mesh,
    light_comps: []Cmp_Light,

    mesh_assigner: map[i32][2]int,
    joint_assigner: map[i32][2]int,
    shape_assigner: map[i32][2]int,

    compute_texture: Texture,
    gui_textures: [MAX_GUIS]Texture,
    bindless_textures: []Texture,

    compute_write_descriptor_sets: []vk.WriteDescriptorSet,

    ordered_prims_map: []int,

    prepared: bool,
}

// Initialize a uniform buffer with the provided data
init_uniform_buffer :: proc(vb: ^gpu.VBuffer, rc: ^RenderBase, data: $T) {
    size := u64(size_of(T))
    create_buffer(rc, size, {.UNIFORM_BUFFER}, &vb.allocation, &vb.buffer)
    vb.buffer_info = vk.DescriptorBufferInfo{buffer = vb.buffer, offset = 0, range = size}
    mapped: rawptr
    must(vma.MapMemory(rc.vma_allocator, vb.allocation, &mapped))
    mem.copy(mapped, &data, size_of(T))
    vma.UnmapMemory(rc.vma_allocator, vb.allocation)
}


// Example usage in a compute raytracer
/*prepare_storage_buffers :: proc(cr: ^ComputeRaytracer) {
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
        gui := gpu.Gui{
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
}*/
