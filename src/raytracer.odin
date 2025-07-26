package main
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"
import "core:strings"
import "core:slice"
import "core:log"
import "core:os"
import "external/vma"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:fmt"
import "gpu"
import res "resource"
import "external/embree"

curr_id : u32 = 0
MAX_MATERIALS :: 256
MAX_MESHES :: 2048
MAX_VERTS :: 32768
MAX_INDS :: 16384
MAX_OBJS :: 4096
MAX_LIGHTS :: 32
MAX_GUIS :: 96
MAX_NODES :: 2048
MAX_BINDLESS_TEXTURES :: 6
MAX_TEXTURES :: 5
// Update flags for tracking what needs to be updated
UpdateFlag :: enum {
    OBJECT,
    MATERIAL,
    LIGHT,
    GUI,
    BVH,
}
UpdateFlags :: bit_set[UpdateFlag]

rt: ComputeRaytracer

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
    primitives: [dynamic]gpu.Primitive,
    materials: [dynamic]gpu.Material,
    lights: [dynamic]gpu.Light,
    guis: [dynamic]gpu.Gui,
    bvh: [dynamic]gpu.BvhNode,

    mesh_comps: [dynamic]Cmp_Mesh,
    light_comps: [dynamic]Cmp_Light,

    mesh_assigner: map[i32][2]int,
    joint_assigner: map[i32][2]int,
    shape_assigner: map[i32][2]int,

    compute_texture: Texture,
    gui_textures: [MAX_TEXTURES]Texture,
    bindless_textures: []Texture,

    compute_write_descriptor_sets: []vk.WriteDescriptorSet,

    ordered_prims_map: [dynamic]int,

    prepared: bool,
    update_flags: UpdateFlags,
}

//----------------------------------------------------------------------------\\
// /Initialization Procs /ip
//----------------------------------------------------------------------------\\
initialize_raytracer :: proc()
{
    prepare_storage_buffers()
    create_uniform_buffers()
    prepare_texture_target(&rt.compute_texture, 1280, 720, .R8G8B8A8_UNORM)
    create_descriptor_set_layout() // multiple
    create_graphics_pipeline() // multiple
    create_descriptor_pool()
    create_descriptor_sets()
    prepare_compute()
    create_command_buffers(1.0, 0, 0) // multiple
    rt.prepared = true
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
prepare_storage_buffers :: proc() {
    reserve(&rt.materials, MAX_MATERIALS)
    reserve(&rt.lights, MAX_LIGHTS)

    gpu.vbuffer_init_storage_buffer_custom_size(
        &rt.compute.storage_buffers.primitives,
        &rb.vma_allocator,
        rt.primitives[:],
        MAX_OBJS)

    gpu.vbuffer_init_storage_buffer_custom_size(
        &rt.compute.storage_buffers.lights,
        &rb.vma_allocator,
        rt.lights[:],
        MAX_LIGHTS)

    gpu.vbuffer_init_storage_buffer_custom_size(
        &rt.compute.storage_buffers.materials,
        &rb.vma_allocator,
        rt.materials[:],
        MAX_MATERIALS)

   gui_cmp := get_component(g_world_ent, Cmp_Gui)
   gpu_gui := gpu.Gui{min = gui_cmp.min, extents = gui_cmp.extents,
       align_min = gui_cmp.align_min, align_ext = gui_cmp.align_ext,
       layer = gui_cmp.layer, id = gui_cmp.id, alpha = gui_cmp.alpha
   }
   append(&rt.guis, gpu_gui)
   gui_cmp.ref = i32(len(rt.guis))
   gpu.vbuffer_init_storage_buffer_custom_size(
        &rt.compute.storage_buffers.guis,
        &rb.vma_allocator,
        rt.guis[:],
        MAX_GUIS)
   gpu.vbuffer_init_storage_buffer_custom_size(
       &rt.compute.storage_buffers.bvh,
       &rb.vma_allocator,
       rt.bvh[:],
       MAX_NODES)
}

create_uniform_buffers :: proc() {
    gpu.vbuffer_init_custom(&rt.compute.uniform_buffer, &rb.vma_allocator, 1, {.UNIFORM_BUFFER}, .CPU_TO_GPU)
    gpu.vbuffer_apply_changes_no_data(&rt.compute.uniform_buffer, &rb.vma_allocator)
}

prepare_texture_target :: proc(tex: ^Texture, width, height: u32, format: vk.Format) {
    // Get format properties to check if the format supports storage image operations
    format_properties: vk.FormatProperties
    vk.GetPhysicalDeviceFormatProperties(rb.physical_device, format, &format_properties)
    if (format_properties.optimalTilingFeatures & { .STORAGE_IMAGE }) == {} {
        panic("Format does not support storage image operations")
    }

    // Set texture dimensions
    tex.width = width
    tex.height = height

    // Create the image using VMA
    image_info := vk.ImageCreateInfo{
        sType = .IMAGE_CREATE_INFO,
        imageType = .D2,
        format = format,
        extent = {width, height, 1},
        mipLevels = 1,
        arrayLayers = 1,
        samples = {._1},
        tiling = .OPTIMAL,
        usage = { .SAMPLED, .STORAGE },
        sharingMode = .EXCLUSIVE,
        initialLayout = .UNDEFINED,
    }
    alloc_info := vma.AllocationCreateInfo{
        usage = .AUTO_PREFER_DEVICE,
    }
    must(vma.CreateImage(rb.vma_allocator, &image_info, &alloc_info, &tex.image, &tex.image_allocation, nil))

    // Create image view
    view_info := vk.ImageViewCreateInfo{
        sType = .IMAGE_VIEW_CREATE_INFO,
        image = tex.image,
        viewType = .D2,
        format = format,
        subresourceRange = {
            aspectMask = { .COLOR },
            baseMipLevel = 0,
            levelCount = 1,
            baseArrayLayer = 0,
            layerCount = 1,
        },
    }
    must(vk.CreateImageView(rb.device, &view_info, nil, &tex.view))

    // Create sampler
    sampler_info := vk.SamplerCreateInfo{
        sType = .SAMPLER_CREATE_INFO,
        magFilter = .LINEAR,
        minFilter = .LINEAR,
        mipmapMode = .LINEAR,
        addressModeU = .CLAMP_TO_BORDER,
        addressModeV = .CLAMP_TO_BORDER,
        addressModeW = .CLAMP_TO_BORDER,
        mipLodBias = 0.0,
        anisotropyEnable = false,
        maxAnisotropy = 1.0,
        compareEnable = false,
        compareOp = .NEVER,
        minLod = 0.0,
        maxLod = 0.0,
        borderColor = .FLOAT_OPAQUE_WHITE,
    }
    must(vk.CreateSampler(rb.device, &sampler_info, nil, &tex.sampler))

    // Transition layout to GENERAL (for compute storage/sampling) before descriptor use
    transition_image_layout(tex.image, format, .UNDEFINED, .GENERAL)

    // Now safe: Initialize descriptor with matching layout
    tex.descriptor = vk.DescriptorImageInfo{
        imageLayout = .GENERAL,
        imageView = tex.view,
        sampler = tex.sampler,
    }
}

create_descriptor_set_layout :: proc() {
    bindings: [1]vk.DescriptorSetLayoutBinding
    bindings[0] = vk.DescriptorSetLayoutBinding{
        binding = 0,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        descriptorCount = 1,
        stageFlags = { .FRAGMENT },
        pImmutableSamplers = nil,
    }
    layout_info := vk.DescriptorSetLayoutCreateInfo{
        sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        bindingCount = 1,
        pBindings = &bindings[0],
    }
    must(vk.CreateDescriptorSetLayout(rb.device, &layout_info, nil, &rt.graphics.descriptor_set_layout))

    pipeline_layout_info := vk.PipelineLayoutCreateInfo{
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = 1,
        pSetLayouts = &rt.graphics.descriptor_set_layout,
    }
    must(vk.CreatePipelineLayout(rb.device, &pipeline_layout_info, nil, &rt.graphics.pipeline_layout))
}

create_graphics_pipeline :: proc() {
    // Input assembly state
    input_assembly_state := vk.PipelineInputAssemblyStateCreateInfo{
        sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    // Rasterization state
    rasterization_state := vk.PipelineRasterizationStateCreateInfo{
        sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable = false,
        rasterizerDiscardEnable = false,
        polygonMode = .FILL,
        cullMode = { .FRONT },
        frontFace = .COUNTER_CLOCKWISE,
        depthBiasEnable = false,
        lineWidth = 1.0,
    }

    // Color blend attachment state
    blend_attachment_state := vk.PipelineColorBlendAttachmentState{
        blendEnable = false,
        colorWriteMask = { .R, .G, .B, .A },
    }

    // Color blend state
    color_blend_state := vk.PipelineColorBlendStateCreateInfo{
        sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        attachmentCount = 1,
        pAttachments = &blend_attachment_state,
    }

    // Depth stencil state
    depth_stencil_state := vk.PipelineDepthStencilStateCreateInfo{
        sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        depthTestEnable = false,
        depthWriteEnable = false,
        depthCompareOp = .LESS_OR_EQUAL,
    }

    // Viewport state
    viewport_state := vk.PipelineViewportStateCreateInfo{
        sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        scissorCount = 1,
    }

    // Multisample state
    multisample_state := vk.PipelineMultisampleStateCreateInfo{
        sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        rasterizationSamples = {._1},
    }

    // Dynamic state
    dynamic_state_enables := [2]vk.DynamicState{ .VIEWPORT, .SCISSOR }
    dynamic_state := vk.PipelineDynamicStateCreateInfo{
        sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        dynamicStateCount = 2,
        pDynamicStates = &dynamic_state_enables[0],
    }

    // Read shader files
    vert_shader_code, ok := os.read_entire_file("assets/shaders/texture.vert.spv")
    if !ok {
        panic("Failed to read vertex shader")
    }
    defer delete(vert_shader_code)

    frag_shader_code, ok2 := os.read_entire_file("assets/shaders/texture.frag.spv")
    if !ok2 {
        panic("Failed to read fragment shader")
    }
    defer delete(frag_shader_code)

    // Create shader modules
    vert_module_info := vk.ShaderModuleCreateInfo{
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = int(len(vert_shader_code)),
        pCode = cast(^u32)raw_data(vert_shader_code),
    }
    vert_shader_module: vk.ShaderModule
    must(vk.CreateShaderModule(rb.device, &vert_module_info, nil, &vert_shader_module))

    frag_module_info := vk.ShaderModuleCreateInfo{
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = int(len(frag_shader_code)),
        pCode = cast(^u32)raw_data(frag_shader_code),
    }
    frag_shader_module: vk.ShaderModule
    must(vk.CreateShaderModule(rb.device, &frag_module_info, nil, &frag_shader_module))

    // Shader stages
    vert_shader_stage := vk.PipelineShaderStageCreateInfo{
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .VERTEX },
        module = vert_shader_module,
        pName = "main",
    }
    frag_shader_stage := vk.PipelineShaderStageCreateInfo{
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .FRAGMENT },
        module = frag_shader_module,
        pName = "main",
    }
    shader_stages := [2]vk.PipelineShaderStageCreateInfo{vert_shader_stage, frag_shader_stage}

    // Vertex input state (empty)
    vertex_input_state := vk.PipelineVertexInputStateCreateInfo{
        sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount = 0,
        pVertexBindingDescriptions = nil,
        vertexAttributeDescriptionCount = 0,
        pVertexAttributeDescriptions = nil,
    }

    // Pipeline create info
    pipeline_info := vk.GraphicsPipelineCreateInfo{
        sType = .GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount = 2,
        pStages = &shader_stages[0],
        pVertexInputState = &vertex_input_state,
        pInputAssemblyState = &input_assembly_state,
        pViewportState = &viewport_state,
        pRasterizationState = &rasterization_state,
        pMultisampleState = &multisample_state,
        pDepthStencilState = &depth_stencil_state,
        pColorBlendState = &color_blend_state,
        pDynamicState = &dynamic_state,
        layout = rt.graphics.pipeline_layout,
        renderPass = rb.render_pass,
        subpass = 0,
    }

    must(vk.CreateGraphicsPipelines(rb.device, rb.pipeline_cache, 1, &pipeline_info, nil, &rt.graphics.pipeline))

    // Destroy shader modules
    vk.DestroyShaderModule(rb.device, frag_shader_module, nil)
    vk.DestroyShaderModule(rb.device, vert_shader_module, nil)
}

create_descriptor_pool :: proc() {
    pool_sizes: [5]vk.DescriptorPoolSize
    pool_sizes[0] = { type = .UNIFORM_BUFFER, descriptorCount = 2 }
    pool_sizes[1] = { type = .COMBINED_IMAGE_SAMPLER, descriptorCount = 3 + MAX_TEXTURES }
    pool_sizes[2] = { type = .STORAGE_IMAGE, descriptorCount = 1 }
    pool_sizes[3] = { type = .STORAGE_BUFFER, descriptorCount = 9 }
    pool_sizes[4] = { type = .COMBINED_IMAGE_SAMPLER, descriptorCount = MAX_BINDLESS_TEXTURES }
    pool_info := vk.DescriptorPoolCreateInfo{
        sType = .DESCRIPTOR_POOL_CREATE_INFO,
        flags = { .UPDATE_AFTER_BIND },
        maxSets = 3,
        poolSizeCount = 5,
        pPoolSizes = &pool_sizes[0],
    }
    must(vk.CreateDescriptorPool(rb.device, &pool_info, nil, &rt.descriptor_pool))
}

create_descriptor_sets :: proc() {
    alloc_info := vk.DescriptorSetAllocateInfo{
        sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool = rt.descriptor_pool,
        descriptorSetCount = 1,
        pSetLayouts = &rt.graphics.descriptor_set_layout,
    }
    must(vk.AllocateDescriptorSets(rb.device, &alloc_info, &rt.graphics.descriptor_set))
    write_set := vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.graphics.descriptor_set,
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &rt.compute_texture.descriptor,
    }
    vk.UpdateDescriptorSets(rb.device, 1, &write_set, 0, nil)
}

prepare_compute :: proc() {
    // Get compute queue
    vk.GetDeviceQueue(rb.device, rb.compute_queue_family_index, 0, &rt.compute.queue)

    // Define descriptor set layout bindings
    bindings: [13]vk.DescriptorSetLayoutBinding
    for i in 0..<11 {
        bindings[i] = {
            binding = u32(i),
            descriptorType = i == 0 ? .STORAGE_IMAGE : i == 1 ? .UNIFORM_BUFFER : .STORAGE_BUFFER,
            descriptorCount = 1,
            stageFlags = { .COMPUTE },
        }
    }
    bindings[11] = {
        binding = 11,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        descriptorCount = MAX_TEXTURES,
        stageFlags = { .COMPUTE },
    }
    bindings[12] = {
        binding = 12,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        descriptorCount = MAX_BINDLESS_TEXTURES,
        stageFlags = { .COMPUTE },
    }

    // Set up binding flags for bindless textures
    binding_flags: [13]vk.DescriptorBindingFlags
    binding_flags[12] = { .PARTIALLY_BOUND, .UPDATE_AFTER_BIND }
    for i in 0..<12 {
        binding_flags[i] = { .PARTIALLY_BOUND}
    }

    extended_flags_info := vk.DescriptorSetLayoutBindingFlagsCreateInfoEXT{
        sType = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO_EXT,
        bindingCount = 13,
        pBindingFlags = &binding_flags[0],
    }

    layout_info := vk.DescriptorSetLayoutCreateInfo{
        sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        flags = { .UPDATE_AFTER_BIND_POOL },
        bindingCount = 13,
        pBindings = &bindings[0],
        pNext = &extended_flags_info,
    }
    must(vk.CreateDescriptorSetLayout(rb.device, &layout_info, nil, &rt.compute.descriptor_set_layout))

    // Create pipeline layout
    pipeline_layout_info := vk.PipelineLayoutCreateInfo{
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = 1,
        pSetLayouts = &rt.compute.descriptor_set_layout,
    }
    must(vk.CreatePipelineLayout(rb.device, &pipeline_layout_info, nil, &rt.compute.pipeline_layout))

    // Allocate descriptor set
    alloc_info := vk.DescriptorSetAllocateInfo{
        sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool = rt.descriptor_pool,
        descriptorSetCount = 1,
        pSetLayouts = &rt.compute.descriptor_set_layout,
    }
    must(vk.AllocateDescriptorSets(rb.device, &alloc_info, &rt.compute.descriptor_set))

    // Prepare image infos for gui_textures and bindless_textures
    texture_image_infos: [MAX_TEXTURES]vk.DescriptorImageInfo
    for i in 0..<MAX_TEXTURES {
        texture_image_infos[i] = rt.gui_textures[i].descriptor
    }
    bindless_image_infos := make([]vk.DescriptorImageInfo, len(rt.bindless_textures))
    defer delete(bindless_image_infos)
    for t, i in rt.bindless_textures {
        bindless_image_infos[i] = t.descriptor
    }

// Dynamically build write_sets, skipping buffer writes if handle is null
    write_sets: [dynamic]vk.WriteDescriptorSet
    defer delete(write_sets)

    // Binding 0: STORAGE_IMAGE (always write, assuming rt.compute_texture.descriptor is valid; it's pImageInfo anyway)
    append(&write_sets, vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_IMAGE,
        pImageInfo = &rt.compute_texture.descriptor,
    })

    // Binding 1: UNIFORM_BUFFER (skip if null)
    if rt.compute.uniform_buffer.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 1,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .UNIFORM_BUFFER,
            pBufferInfo = &rt.compute.uniform_buffer.buffer_info,
        })
    }

    // Binding 2: STORAGE_BUFFER verts (skip if null)
    if rt.compute.storage_buffers.verts.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 2,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.verts.buffer_info,
        })
    }

    // Binding 3: STORAGE_BUFFER faces (skip if null)
    if rt.compute.storage_buffers.faces.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 3,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.faces.buffer_info,
        })
    }

    // Binding 4: STORAGE_BUFFER blas (skip if null)
    if rt.compute.storage_buffers.blas.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 4,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.blas.buffer_info,
        })
    }

    // Binding 5: STORAGE_BUFFER shapes (skip if null)
    if rt.compute.storage_buffers.shapes.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 5,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.shapes.buffer_info,
        })
    }

    // Binding 6: STORAGE_BUFFER primitives (skip if null)
    if rt.compute.storage_buffers.primitives.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 6,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.primitives.buffer_info,
        })
    }

    // Binding 7: STORAGE_BUFFER materials (skip if null)
    if rt.compute.storage_buffers.materials.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 7,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.materials.buffer_info,
        })
    }

    // Binding 8: STORAGE_BUFFER lights (skip if null)
    if rt.compute.storage_buffers.lights.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 8,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.lights.buffer_info,
        })
    }

    // Binding 9: STORAGE_BUFFER guis (skip if null)
    if rt.compute.storage_buffers.guis.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 9,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.guis.buffer_info,
        })
    }

    // Binding 10: STORAGE_BUFFER bvh (skip if null)
    if rt.compute.storage_buffers.bvh.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = rt.compute.descriptor_set,
            dstBinding = 10,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &rt.compute.storage_buffers.bvh.buffer_info,
        })
    }

    // Binding 11: COMBINED_IMAGE_SAMPLER array (always write, but could add checks if some are invalid)
    append(&write_sets, vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 11,
        dstArrayElement = 0,
        descriptorCount = MAX_TEXTURES,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &texture_image_infos[0],
    })

    // Binding 12: COMBINED_IMAGE_SAMPLER bindless array (always write, with dynamic count)
    append(&write_sets, vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 12,
        dstArrayElement = 0,
        descriptorCount = u32(len(rt.bindless_textures)),
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = raw_data(bindless_image_infos),
    })

    // Update descriptor sets (now with potentially fewer than 13 writes)
    vk.UpdateDescriptorSets(rb.device, u32(len(write_sets)), raw_data(write_sets), 0, nil)

    // Create compute pipeline
    shader_code, ok := os.read_entire_file("assets/shaders/raytracing.comp.spv")
    if !ok {
        panic("Failed to read compute shader")
    }
    defer delete(shader_code)
    module_info := vk.ShaderModuleCreateInfo{
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = int(len(shader_code)),
        pCode = cast(^u32)raw_data(shader_code),
    }
    shader_module: vk.ShaderModule
    must(vk.CreateShaderModule(rb.device, &module_info, nil, &shader_module))
    pipeline_info := vk.ComputePipelineCreateInfo{
        sType = .COMPUTE_PIPELINE_CREATE_INFO,
        stage = {
            sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage = { .COMPUTE },
            module = shader_module,
            pName = "main",
        },
        layout = rt.compute.pipeline_layout,
    }
    must(vk.CreateComputePipelines(rb.device, rb.pipeline_cache, 1, &pipeline_info, nil, &rt.compute.pipeline))
    defer vk.DestroyShaderModule(rb.device, shader_module, nil)

    // Create command pool
    cmd_pool_info := vk.CommandPoolCreateInfo{
        sType = .COMMAND_POOL_CREATE_INFO,
        queueFamilyIndex = rb.compute_queue_family_index,
        flags = { .RESET_COMMAND_BUFFER },
    }
    must(vk.CreateCommandPool(rb.device, &cmd_pool_info, nil, &rt.compute.command_pool))

    // Allocate command buffer
    cmd_buf_info := vk.CommandBufferAllocateInfo{
        sType = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool = rt.compute.command_pool,
        level = .PRIMARY,
        commandBufferCount = 1,
    }
    must(vk.AllocateCommandBuffers(rb.device, &cmd_buf_info, &rt.compute.command_buffer))

    // Create fence
    fence_info := vk.FenceCreateInfo{
        sType = .FENCE_CREATE_INFO,
        flags = { .SIGNALED },
    }
    must(vk.CreateFence(rb.device, &fence_info, nil, &rt.compute.fence))

    create_compute_command_buffer()

}

create_compute_command_buffer :: proc() {
    cmd_buf_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        // No flags needed; equivalent to vks::initializers default (no ONE_TIME_SUBMIT for re-recordable if desired)
    }

    must(vk.BeginCommandBuffer(rt.compute.command_buffer, &cmd_buf_info))

    vk.CmdBindPipeline(rt.compute.command_buffer, .COMPUTE, rt.compute.pipeline)
    vk.CmdBindDescriptorSets(rt.compute.command_buffer, .COMPUTE, rt.compute.pipeline_layout, 0, 1, &rt.compute.descriptor_set, 0, nil)

    // Dispatch: Matches your /16 (assuming workgroup size 16x16 in shader; adjust if different)
    vk.CmdDispatch(rt.compute.command_buffer, rt.compute_texture.width / 16, rt.compute_texture.height / 16, 1)

    must(vk.EndCommandBuffer(rt.compute.command_buffer))
}

create_command_buffers :: proc(swap_ratio: f32 = 1.0, offset_width: i32 = 0, offset_height: i32 = 0) {
    // Allocate command buffers if not already done
    //if len(rb.command_buffers) == 0
    {
        //rb.command_buffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
        command_buffer_info := vk.CommandBufferAllocateInfo{
            sType = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = rb.command_pool,
            level = .PRIMARY,
            commandBufferCount = u32(len(rb.swapchain_images)),
        }
        must(vk.AllocateCommandBuffers(rb.device, &command_buffer_info, &rb.command_buffers[0]))
    }

    // Calculate viewport and scissor based on parameters
    width := f32(rb.swapchain_extent.width) * swap_ratio
    height := f32(rb.swapchain_extent.height) * swap_ratio
    x := f32(offset_width)
    y := f32(offset_height)

    for i in 0..<len(rb.command_buffers) {
        cmd_buffer := rb.command_buffers[i]

        // Begin command buffer
        begin_info := vk.CommandBufferBeginInfo{
            sType = .COMMAND_BUFFER_BEGIN_INFO,
            flags = { .SIMULTANEOUS_USE },
        }
        must(vk.BeginCommandBuffer(cmd_buffer, &begin_info))

        // Image memory barrier for compute_texture
        barrier := vk.ImageMemoryBarrier{
            sType = .IMAGE_MEMORY_BARRIER,
            oldLayout = .GENERAL,
            newLayout = .GENERAL,
            srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            image = rt.compute_texture.image,
            subresourceRange = {
                aspectMask = { .COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
            srcAccessMask = { .SHADER_WRITE},
            dstAccessMask = { .SHADER_READ},
        }
        vk.CmdPipelineBarrier(
            cmd_buffer,
            { .COMPUTE_SHADER},
            { .FRAGMENT_SHADER},
            {},
            0, nil,
            0, nil,
            1, &barrier,
        )

        // Begin render pass
        clear_values: [2]vk.ClearValue
        clear_values[0].color = { float32 = {0.0, 0.0, 0.0, 1.0} }
        clear_values[1].depthStencil = { depth = 1.0, stencil = 0 }
        render_pass_info := vk.RenderPassBeginInfo{
            sType = .RENDER_PASS_BEGIN_INFO,
            renderPass = rb.render_pass,
            framebuffer = rb.swapchain_frame_buffers[i],
            renderArea = { offset = {0, 0}, extent = rb.swapchain_extent },
            clearValueCount = 2,
            pClearValues = &clear_values[0],
        }
        vk.CmdBeginRenderPass(cmd_buffer, &render_pass_info, .INLINE)

        // Bind graphics pipeline
        vk.CmdBindPipeline(cmd_buffer, .GRAPHICS, rt.graphics.pipeline)

        // Set viewport
        viewport := vk.Viewport{
            x = x,
            y = y,
            width = width,
            height = height,
            minDepth = 0.0,
            maxDepth = 1.0,
        }
        vk.CmdSetViewport(cmd_buffer, 0, 1, &viewport)

        // Set scissor
        scissor := vk.Rect2D{
            offset = {i32(x), i32(y)},
            extent = {u32(width), u32(height)},
        }
        vk.CmdSetScissor(cmd_buffer, 0, 1, &scissor)

        // Bind descriptor sets
        vk.CmdBindDescriptorSets(
            cmd_buffer,
            .GRAPHICS,
            rt.graphics.pipeline_layout,
            0,
            1,
            &rt.graphics.descriptor_set,
            0,
            nil,
        )

        // Draw full-screen quad (4 vertices)
        vk.CmdDraw(cmd_buffer, 3, 1, 0, 0)

        // End render pass
        vk.CmdEndRenderPass(cmd_buffer)

        // End command buffer
        must(vk.EndCommandBuffer(cmd_buffer))
    }
}

//----------------------------------------------------------------------------\\
// /Start up /su
//----------------------------------------------------------------------------\\
start_up_raytracer :: proc(alloc: mem.Allocator)
{
   init_vulkan()
   set_camera()
   map_materials_to_gpu(alloc)
   map_models_to_gpu(alloc)
}

set_camera :: proc()
{
    rt.compute.ubo.aspect_ratio = 1280.0 / 720.0
    rt.compute.ubo.fov = math.tan(f32(13.0 * 0.03490658503))
    rt.compute.ubo.rotM = mat4f(0)
    rt.compute.ubo.rand = rand.int31()
}


map_materials_to_gpu :: proc(alloc : mem.Allocator)
{
	rt.materials = make([dynamic]gpu.Material, len(g_materials), alloc)
	for &m, i in g_materials{
	    gpu_mat : gpu.Material = {
			diffuse = m.diffuse,
			reflective = m.reflective,
			roughness = m.roughness,
			transparency = m.transparency,
			refractive_index = m.refractive_index,
			texture_id = m.texture_id
		}
        rt.materials[i] = gpu_mat
	}
}

map_models_to_gpu :: proc(alloc : mem.Allocator)
{
    verts : [dynamic]gpu.Vert
    faces : [dynamic]gpu.Index
    shapes : [dynamic]gpu.Shape
    blas : [dynamic]gpu.BvhNode
    defer delete(blas)
    defer delete(shapes)
    defer delete(faces)
    defer delete(verts)

    for mod in g_models
    {
        for mesh, i in mod.meshes
        {
            prev_vert_size := len(verts)
            prev_ind_size := len(faces)
            prev_blas_size := len(blas)

            reserve(&verts, prev_vert_size + len(mesh.verts))
            for vert in mesh.verts{
                append(&verts, gpu.Vert{pos = vert.pos, norm = vert.norm, u = vert.uv.x, v = vert.uv.y})
            }
            reserve(&faces, prev_ind_size + len(mesh.faces))
            for face in mesh.faces{
                append(&faces, gpu.Index{v = face + i32(prev_vert_size)})
            }
            reserve(&blas, prev_blas_size + len(mesh.bvhs))
            for bvh in mesh.bvhs{
                append(&blas, gpu.BvhNode{bvh.upper, bvh.offset, bvh.lower, bvh.numChildren})
            }
        }
    }
    append(&shapes, gpu.Shape{})

    //Load them into the gpu
    init_storage_buf(&rt.compute.storage_buffers.verts,verts, len(verts))
    init_storage_buf(&rt.compute.storage_buffers.faces,faces, len(faces))
    init_storage_buf(&rt.compute.storage_buffers.blas, blas, len(blas))
    init_storage_buf(&rt.compute.storage_buffers.shapes, shapes, len(shapes))
    for &t, i in rt.gui_textures{
        t = Texture{path = texture_paths[i]}
        texture_create(&t)
    }
    rt.bindless_textures = make([dynamic]Texture, len(texture_paths), alloc)[:]
    for p, i in texture_paths{
        t := Texture{path = p}
        texture_create(&t)
        rt.bindless_textures[i] = t
    }
}

texture_paths := [6]string{
    "../Assets/Levels/1_Jungle/Textures/numbers.png",
    "../Assets/Levels/1_Jungle/Textures/pause.png",
    "../Assets/Levels/1_Jungle/Textures/circuit.png",
    "../Assets/Levels/1_Jungle/Textures/ARROW.png",
    "../Assets/Levels/1_Jungle/Textures/debugr.png",
    "../Assets/Levels/1_Jungle/Textures/title.png",
}

init_storage_buf :: proc(vbuf: ^gpu.VBuffer($T), objects: [dynamic]T, size : int )
{
    gpu.vbuffer_init_storage_buffer_with_staging_device(vbuf, rb.device, &rb.vma_allocator, rb.command_pool, rb.graphics_queue, objects[:], u32(size))
}

//----------------------------------------------------------------------------\\
// Updates /up
//----------------------------------------------------------------------------\\
// Update descriptor sets for compute pipeline
update_descriptors :: proc() {
    // Prepare write descriptor sets
    write_descriptor_sets: [13]vk.WriteDescriptorSet

    // Binding 0: storage image
    image_info := vk.DescriptorImageInfo{
        imageView = rt.compute_texture.view,
        imageLayout = .GENERAL,
    }
    write_descriptor_sets[0] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_IMAGE,
        pImageInfo = &image_info,
    }

    // Binding 1: uniform buffer
    buffer_info := rt.compute.uniform_buffer.buffer_info
    write_descriptor_sets[1] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 1,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .UNIFORM_BUFFER,
        pBufferInfo = &buffer_info,
    }

    // Bindings 2-10: storage buffers (verts, faces, blas, shapes, primitives, materials, lights, guis, bvh)
    write_descriptor_sets[2] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 2,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.verts.buffer_info,
    }
    write_descriptor_sets[3] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 3,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.faces.buffer_info,
    }
    write_descriptor_sets[4] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 4,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.blas.buffer_info,
    }
    write_descriptor_sets[5] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 5,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.shapes.buffer_info,
    }
    write_descriptor_sets[6] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 6,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.primitives.buffer_info,
    }
    write_descriptor_sets[7] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 7,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.materials.buffer_info,
    }
    write_descriptor_sets[8] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 8,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.lights.buffer_info,
    }
    write_descriptor_sets[9] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 9,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.guis.buffer_info,
    }
    write_descriptor_sets[10] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 10,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.bvh.buffer_info,
    }

    // Binding 11: combined image sampler for GUI textures (up to MAX_GUIS)
    gui_image_infos: []vk.DescriptorImageInfo = make([]vk.DescriptorImageInfo, len(rt.gui_textures))
    defer delete(gui_image_infos)
    for i in 0..<len(rt.gui_textures) {
        gui_image_infos[i] = vk.DescriptorImageInfo{
            sampler = rt.gui_textures[i].sampler,
            imageView = rt.gui_textures[i].view,
            imageLayout = .SHADER_READ_ONLY_OPTIMAL,
        }
    }
    write_descriptor_sets[11] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 11,
        dstArrayElement = 0,
        descriptorCount = u32(len(rt.gui_textures)),
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &gui_image_infos[0] if len(gui_image_infos) > 0 else nil,
    }

    // Binding 12: combined image sampler for bindless textures
    bindless_image_infos: []vk.DescriptorImageInfo = make([]vk.DescriptorImageInfo, len(rt.bindless_textures))
    defer delete(bindless_image_infos)
    for i in 0..<len(rt.bindless_textures) {
        bindless_image_infos[i] = vk.DescriptorImageInfo{
            sampler = rt.bindless_textures[i].sampler,
            imageView = rt.bindless_textures[i].view,
            imageLayout = .SHADER_READ_ONLY_OPTIMAL,
        }
    }
    write_descriptor_sets[12] = vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 12,
        dstArrayElement = 0,
        descriptorCount = u32(len(rt.bindless_textures)),
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &bindless_image_infos[0] if len(bindless_image_infos) > 0 else nil,
    }

    // Update descriptor sets
    vk.UpdateDescriptorSets(rb.device, 13, &write_descriptor_sets[0], 0, nil)
}

update_buffers :: proc() {
    vk.WaitForFences(rb.device, 1, &rt.compute.fence, true, max(u64))

    if rt.update_flags == {} do return

    if .OBJECT in rt.update_flags {
        // compute_.storage_buffers.primitives.UpdateBuffers(vkDevice, primitives);
        rt.update_flags -= {.OBJECT}
    }

    if .MATERIAL in rt.update_flags {
        rt.update_flags -= {.MATERIAL}
    }

    if .LIGHT in rt.update_flags {
        gpu.vbuffer_update(&rt.compute.storage_buffers.lights, &rb.vma_allocator, rt.lights[:])
        rt.update_flags -= {.LIGHT}
    }

    if .GUI in rt.update_flags {
        gpu.vbuffer_update(&rt.compute.storage_buffers.guis, &rb.vma_allocator, rt.guis[:])
        rt.update_flags -= {.GUI}
    }

    if .BVH in rt.update_flags {
        gpu.vbuffer_update_and_expand(&rt.compute.storage_buffers.primitives, &rb.vma_allocator, rt.primitives[:], u32(len(rt.primitives)))
        gpu.vbuffer_update_and_expand(&rt.compute.storage_buffers.bvh, &rb.vma_allocator, rt.bvh[:], u32(len(rt.bvh)))
        rt.update_flags -= {.BVH}
    }

    rt.update_flags = {}
    // compute_.storage_buffers.objects.UpdateAndExpandBuffers(vkDevice, objects, objects.size());
    // compute_.storage_buffers.bvh.UpdateAndExpandBuffers(vkDevice, bvh, bvh.size());
    update_descriptors()
}

update_camera :: proc{update_camera_full, update_camera_component}

update_camera_full :: proc(camera: ^Camera) {
    rt.compute.ubo.aspect_ratio = camera.aspect
    rt.compute.ubo.fov = math.tan(camera.fov * 0.03490658503)
    rt.compute.ubo.rotM = transmute(mat4f)camera.matrices.view
    rt.compute.ubo.rand = rand.int31()
    gpu.vbuffer_apply_changes(&rt.compute.uniform_buffer, &rb.vma_allocator, &rt.compute.ubo)
}

update_camera_component :: proc(camera: ^Cmp_Camera) {
    rt.compute.ubo.aspect_ratio = camera.aspect_ratio
    rt.compute.ubo.fov = math.tan(camera.fov * 0.03490658503)
    rt.compute.ubo.rotM = transmute(mat4f)camera.rot_matrix
    rt.compute.ubo.rand = rand.int31()
    gpu.vbuffer_apply_changes(&rt.compute.uniform_buffer, &rb.vma_allocator, &rt.compute.ubo)
}

update_bvh :: proc(ordered_prims : ^[dynamic]embree.RTCBuildPrimitive, prims: [dynamic]Entity, root: ^BvhNode, num_nodes : i32)
{
    num_prims := len(ordered_prims)
    if(num_prims == 0) do return
    clear(&rt.primitives)
    clear(&rt.ordered_prims_map)
    reserve(&rt.primitives, num_prims)
    resize(&rt.ordered_prims_map, num_prims)
    for op, i in ordered_prims{
        rt.ordered_prims_map[op.primID] = i
        prim := prims[op.primID]
        pc := get_component(prim, Cmp_Primitive)

        if pc != nil {
            // Convert primitive component to GPU primitive
            gpu_prim := gpu.Primitive{
                world = transmute(mat4f)pc.world,
                extents = pc.extents,
                num_children = pc.num_children,
                id = pc.id,
                mat_id = pc.mat_id,
                start_index = pc.start_index,
                end_index = pc.end_index,
            }
            append(&rt.primitives, gpu_prim)
        }
    }

    // Flatten BVH tree
    offset := 0
    resize(&rt.bvh, int(num_nodes))

    // Get root bounds
    root_bounds := BvhBounds{}
    switch root_node in root {
    case ^InnerBvhNode:
        root_bounds = bvh_merge(root_node.bounds[0], root_node.bounds[1])
    case ^LeafBvhNode:
        root_bounds = root_node.bounds
    }

    flatten_bvh(root^, root_bounds, &offset)
    rt.update_flags |= {.BVH}
}

// Flatten BVH tree into linear array for GPU
flatten_bvh :: proc(node: BvhNode, bounds: BvhBounds, offset: ^int) -> i32 {
    bvh_node := &rt.bvh[offset^]
    my_offset := i32(offset^)
    offset^ += 1

    switch n in node {
    case ^LeafBvhNode:
        // Leaf node
        bvh_node.upper = n.bounds.upper
        bvh_node.lower = n.bounds.lower
        bvh_node.num_children = 0
        bvh_node.offset = i32(rt.ordered_prims_map[n.id])

    case ^InnerBvhNode:
        // Inner node
        bvh_node.upper = bounds.upper
        bvh_node.lower = bounds.lower
        bvh_node.num_children = 2

        // Recursively flatten children
        flatten_bvh(n.children[0], n.bounds[0], offset)
        bvh_node.offset = flatten_bvh(n.children[1], n.bounds[1], offset)
    }

    return my_offset
}

update_uniform_buffers :: proc() {
    gpu.vbuffer_apply_changes(&rt.compute.uniform_buffer, &rb.vma_allocator, &rt.compute.ubo)
}

update_material :: proc(id: i32) {
    m := get_material(id)
    rt.materials[id].diffuse = m.diffuse
    rt.materials[id].reflective = m.reflective
    rt.materials[id].roughness = m.roughness
    rt.materials[id].transparency = m.transparency
    rt.materials[id].refractive_index = m.refractive_index
    rt.materials[id].texture_id = m.texture_id
    gpu.vbuffer_update(&rt.compute.storage_buffers.materials, &rb.vma_allocator, rt.materials[:])
}

update_gui :: proc(gc: ^Cmp_Gui) {
    g := &rt.guis[gc.ref]
    g.min = gc.min
    g.extents = gc.extents
    g.align_min = gc.align_min
    g.align_ext = gc.align_ext
    g.layer = gc.layer
    g.id = gc.id
    g.alpha = gc.alpha
    rt.update_flags |= {.GUI}
}

int_to_array_of_ints :: proc(n: i32) -> [dynamic]i32 {
    if n == 0 {
        res := make([dynamic]i32, 1)
        res[0] = 0
        return res
    }
    res: [dynamic]i32
    nn := n
    for nn > 0 {
        append(&res, nn % 10)
        nn /= 10
    }
    slice.reverse(res[:])
    return res
}

update_gui_number :: proc(gnc: ^Cmp_GuiNumber) {
    nums := int_to_array_of_ints(gnc.number)
    num_size := i32(len(nums))
    change_occured := num_size != gnc.highest_active_digit_index + i32(1)
    if !change_occured {
        for i in 0..<gnc.highest_active_digit_index + 1 {
            rt.guis[gnc.shader_references[i]].align_min = {0.1 * f32(nums[i]), 0.0}
            rt.guis[gnc.shader_references[i]].alpha = gnc.alpha
        }
    } else {
        increased := num_size > gnc.highest_active_digit_index + 1
        if increased {
            needs_shader_ref := num_size > i32(len(gnc.shader_references))
            if needs_shader_ref {
                for i in (num_size - i32(len(gnc.shader_references)))..<num_size {
                    gui := gpu.Gui{
                        min = gnc.min,
                        extents = gnc.extents,
                        align_min = {0.1 * f32(nums[num_size - 1]), 0.0},
                        align_ext = {0.1, 1.0},
                        layer = 0,
                        id = 0,
                        alpha = gnc.alpha,
                    }
                    append(&gnc.shader_references, i32(len(rt.guis)))
                    append(&rt.guis, gui)
                }
                gpu.vbuffer_update_and_expand(&rt.compute.storage_buffers.guis, &rb.vma_allocator, rt.guis[:], u32(len(rt.guis)))
            }
            for i in 0..<num_size {
                rt.guis[gnc.shader_references[i]].align_min = {0.1 * f32(nums[i]), 0.0}
                rt.guis[gnc.shader_references[i]].alpha = gnc.alpha
                rt.guis[gnc.shader_references[i]].min.x = gnc.min.x - (f32(num_size - 1 - i) * gnc.extents.x)
            }
            gnc.highest_active_digit_index = num_size - 1
        } else {
            for i in 0..<num_size {
                rt.guis[gnc.shader_references[i]].align_min = {0.1 * f32(nums[i]), 0.0}
                rt.guis[gnc.shader_references[i]].alpha = gnc.alpha
                rt.guis[gnc.shader_references[i]].min.x = gnc.min.x - (f32(num_size - 1 - i) * gnc.extents.x)
            }
            for i in gnc.highest_active_digit_index..<num_size {
                rt.guis[gnc.shader_references[i]].alpha = 0
            }
            gnc.highest_active_digit_index = num_size - 1
        }
    }
    rt.update_flags |= {.GUI}
}

//----------------------------------------------------------------------------\\
// /Main Procs /main procs
//----------------------------------------------------------------------------\\
add_material :: proc(diff: vec3, rfl: f32, rough: f32, trans: f32, ri: f32) {
    mat := gpu.Material{
        diffuse = diff,
        reflective = rfl,
        roughness = rough,
        transparency = trans,
        refractive_index = ri,
        texture_id = 0,
    }
    append(&rt.materials, mat)
    gpu.vbuffer_update_and_expand(&rt.compute.storage_buffers.materials, &rb.vma_allocator, rt.materials[:], u32(len(rt.materials)))
    update_descriptors()
}

add_node :: proc(node: ^Cmp_Node) {
    if .MODEL in node.engine_flags {
        return
    }
    if .LIGHT in node.engine_flags {
        return
    }
    if .CAMERA in node.engine_flags {
        cam := get_component(node.entity, Cmp_Camera)
        trans_comp := get_component(node.entity, Cmp_Transform)
        rt.compute.ubo.aspect_ratio = cam.aspect_ratio
        rt.compute.ubo.rotM = transmute(mat4f)trans_comp.world
        rt.compute.ubo.fov = math.tan(cam.fov * 0.03490658503)
    }
}

add_gui_number :: proc(gnc: ^Cmp_GuiNumber) {
    nums := int_to_array_of_ints(gnc.number)
    num_size := i32(len(nums))
    for i in 0..<num_size {
        gui := gpu.Gui{
            min = gnc.min,
            extents = gnc.extents,
            align_min = {0.1 * f32(nums[i]), 0.0},
            align_ext = {0.1, 1.0},
            layer = 0,
            id = 0,
            alpha = gnc.alpha,
        }
        append(&gnc.shader_references, i32(len(rt.guis)))
        append(&rt.guis, gui)
    }
    gnc.ref = gnc.shader_references[0]
    rt.update_flags |= {.GUI}
}

start_frame :: proc(image_index: ^u32) {
    // Wait/reset graphics fence for prior frame sync (enables multi-frame overlap)
    must(vk.WaitForFences(rb.device, 1, &rb.in_flight_fences[current_frame], true, max(u64)))
    must(vk.ResetFences(rb.device, 1, &rb.in_flight_fences[current_frame]))

    result := vk.AcquireNextImageKHR(
        rb.device,
        rb.swapchain,
        max(u64),
        rb.image_available_semaphores[current_frame],
        {},
        image_index
    )

    #partial switch result {
    case .ERROR_OUT_OF_DATE_KHR:
        rt_recreate_swapchain()
        return
    case .SUCCESS, .SUBOPTIMAL_KHR:
    case:
        panic(fmt.tprintf("vulkan: acquire next image failure: %v", result))
    }

    wait_stages := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}
    rb.submit_info = vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers = &rb.command_buffers[image_index^],
        waitSemaphoreCount = 1,
        pWaitSemaphores = &rb.image_available_semaphores[current_frame],
        pWaitDstStageMask = &wait_stages,
        signalSemaphoreCount = 1,
        pSignalSemaphores = &rb.render_finished_semaphores[current_frame]
    }
    must(vk.QueueSubmit(rb.graphics_queue, 1, &rb.submit_info, rb.in_flight_fences[current_frame]))  // Fence for graphics
}

end_frame :: proc(image_index: ^u32) {
    present_info := vk.PresentInfoKHR{
        sType = .PRESENT_INFO_KHR,
        waitSemaphoreCount = 1,  // Fixed to 1 (matches signal)
        pWaitSemaphores = &rb.render_finished_semaphores[current_frame],
        swapchainCount = 1,
        pSwapchains = &rb.swapchain,
        pImageIndices = image_index,
    }

    result := vk.QueuePresentKHR(rb.present_queue, &present_info)
    switch {
    case result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || rb.framebuffer_resized:
        rb.framebuffer_resized = false
        rt_recreate_swapchain()
        return  // Skip advance on recreate
    case result == .SUCCESS:
    case:
        panic(fmt.tprintf("vulkan: present failure: %v", result))
    }

    // No QueueWaitIdle: Use fences for async sync instead

    // Compute: Wait/reset dedicated compute fence (matches C++)
    must(vk.WaitForFences(rb.device, 1, &rt.compute.fence, true, max(u64)))
    must(vk.ResetFences(rb.device, 1, &rt.compute.fence))

    compute_submit_info := vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers = &rt.compute.command_buffer,
    }
    must(vk.QueueSubmit(rb.compute_queue, 1, &compute_submit_info, rt.compute.fence))  // Dedicated fence

    current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

added_entity :: proc(e: Entity) {
    rc := get_component(e, Cmp_Render)
    if rc == nil { return }
    t := rc.type

    if .MATERIAL in t {
    }
    if .PRIMITIVE in t {
        prim_comp := get_component(e, Cmp_Primitive)
        mat_comp := get_component(e, Cmp_Material)
        trans_comp := get_component(e, Cmp_Transform)

        prim_comp.mat_id = mat_comp.mat_id
        prim_comp.world = trans_comp.world
        prim_comp.extents = trans_comp.local.sca.xyz
        if prim_comp.id > 0 {
            temp := rt.mesh_assigner[prim_comp.id]
            prim_comp.start_index = i32(temp[0])
            prim_comp.end_index = i32(temp[1])
        }
        rt.update_flags |= {.OBJECT}
    }
    if .LIGHT in t {
        light_comp := get_component(e, Cmp_Light)
        trans_comp := get_component(e, Cmp_Transform)
        light := gpu.Light{
            pos = trans_comp.local.pos.xyz, // technically yes it should be global pos, but this is fine
            color = light_comp.color,
            intensity = light_comp.intensity,
            id = i32(e),
        }
        light_comp.id = light.id
        append(&rt.lights, light)
        append(&rt.light_comps, light_comp^)

        gpu.vbuffer_update_and_expand(&rt.compute.storage_buffers.lights, &rb.vma_allocator, rt.lights[:], u32(len(rt.lights)))
        rt.update_flags |= {.LIGHT}
    }
    if .GUI in t {
        gc := get_component(e, Cmp_Gui)
        gui := gpu.Gui{
            min = gc.min,
            extents = gc.extents,
            align_min = gc.align_min,
            align_ext = gc.align_ext,
            layer = gc.layer,
            id = gc.id,
            alpha = gc.alpha,
        }
        gc.ref = i32(len(rt.guis))
        append(&rt.guis, gui)
        rt.update_flags |= {.GUI}
    }
    if .GUINUM in t {
        gnc := get_component(e, Cmp_GuiNumber)
        nums := int_to_array_of_ints(gnc.number)
        for i in 0..<len(nums) {
            gui := gpu.Gui{
                min = gnc.min,
                extents = gnc.extents,
                align_min = {0.1 * f32(nums[i]), 0.0},
                align_ext = {0.1, 1.0},
                layer = 0,
                id = 0,
                alpha = gnc.alpha,
            }
            append(&gnc.shader_references, i32(len(rt.guis)))
            append(&rt.guis, gui)
        }
        gnc.ref = gnc.shader_references[0]
        rt.update_flags |= {.GUI}
    }
    if .CAMERA in t {
        cam := get_component(e, Cmp_Camera)
        trans_comp := get_component(e, Cmp_Transform)
        rt.compute.ubo.aspect_ratio = cam.aspect_ratio
        rt.compute.ubo.rotM = transmute(mat4f)trans_comp.world
        rt.compute.ubo.fov = cam.fov
        update_camera(cam)
    }
}

removed_entity :: proc(e: Entity) {
    rc := get_component(e, Cmp_Render)
    if rc == nil { return }
    t := rc.type

    if .LIGHT in t {
        lc := get_component(e, Cmp_Light)
        for l, i in rt.lights {
            if lc.id == l.id {
                ordered_remove(&rt.lights, i)
                ordered_remove(&rt.light_comps, i)
                break
            }
        }
        if len(rt.lights) == 0 {
            clear(&rt.lights)
            clear(&rt.light_comps)
        }
    }
}

process_entity :: proc(e: Entity) {
    rc := get_component(e, Cmp_Render)
    if rc == nil { return }
    type := rc.type
    if type == {} { return }

    switch {
    case .MATERIAL in type:
        rt.update_flags |= {.MATERIAL}
    case .PRIMITIVE in type:
        rt.update_flags |= {.OBJECT}
    case .LIGHT in type:
        rt.update_flags |= {.LIGHT}
    case .GUI in type:
        gc := get_component(e, Cmp_Gui)
        update_gui(gc)
    case .GUINUM in type:
        gnc := get_component(e, Cmp_GuiNumber)
        if gnc.update {
            gnc.update = false
            update_gui_number(gnc)
        }
    }
    type = {}
}

end :: proc() {
    update_buffers()
    update_descriptors()
    if glfw.WindowShouldClose(rb.window) {
        end_ecs()
        vk.DeviceWaitIdle(rb.device)
    }
}

cleanup :: proc() {
    vk.DeviceWaitIdle(rb.device)
    cleanup_swapchain()

    destroy_compute()

    vk.DestroyDescriptorPool(rb.device, rt.descriptor_pool, nil)
    vk.DestroyDescriptorSetLayout(rb.device, rt.graphics.descriptor_set_layout, nil)

    vk.DestroyCommandPool(rb.device, rb.command_pool, nil)

    cleanup_vulkan()
}

destroy_compute :: proc() {
    gpu.vbuffer_destroy(&rt.compute.uniform_buffer, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.verts, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.faces, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.blas, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.shapes, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.primitives, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.materials, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.lights, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.guis, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.bvh, &rb.vma_allocator)

    texture_destroy(&rt.compute_texture, rb.device, &rb.vma_allocator)
    for &t in rt.gui_textures {
        texture_destroy(&t, rb.device, &rb.vma_allocator)
    }
    for &t in rt.bindless_textures {
        texture_destroy(&t, rb.device, &rb.vma_allocator)
    }
    vk.DestroyPipelineCache(rb.device, rb.pipeline_cache, nil)
    vk.DestroyPipeline(rb.device, rt.compute.pipeline, nil)
    vk.DestroyPipelineLayout(rb.device, rt.compute.pipeline_layout, nil)
    vk.DestroyDescriptorSetLayout(rb.device, rt.compute.descriptor_set_layout, nil)
    vk.DestroyFence(rb.device, rt.compute.fence, nil)
    vk.DestroyCommandPool(rb.device, rt.compute.command_pool, nil)
}

cleanup_swapchain :: proc() {
    vk.DestroyPipeline(rb.device, rt.graphics.pipeline, nil)
    vk.DestroyPipelineLayout(rb.device, rt.graphics.pipeline_layout, nil)

    cleanup_swapchain_vulkan()
}

rt_recreate_swapchain :: proc() {
    recreate_swapchain_vulkan()
    create_descriptor_set_layout()
    create_graphics_pipeline()
    create_command_buffers(0.7333333333, i32(f32(rb.swapchain_extent.width) * 0.16666666666), 36)
}

// Cleanup swap chain resources
cleanup_swapchain_vulkan :: proc() {
    // Destroy depth image view, image, and memory
    vk.DestroyImageView(rb.device, rb.depth_view, nil)
    vma.DestroyImage(rb.vma_allocator, rb.depth_image, rb.depth_allocation)

    // Destroy framebuffers
    for framebuffer in rb.swapchain_frame_buffers {
        vk.DestroyFramebuffer(rb.device, framebuffer, nil)
    }
    delete(rb.swapchain_frame_buffers)

    // Destroy render pass
    vk.DestroyRenderPass(rb.device, rb.render_pass, nil)

    // Destroy swapchain image views
    for view in rb.swapchain_views {
        vk.DestroyImageView(rb.device, view, nil)
    }
    delete(rb.swapchain_views)

    // Destroy swapchain
    vk.DestroySwapchainKHR(rb.device, rb.swapchain, nil)
}

// Recreate swap chain
recreate_swapchain_vulkan :: proc() {
    // Don't do anything when minimized.
    for w, h := glfw.GetFramebufferSize(rb.window); w == 0 || h == 0; w, h = glfw.GetFramebufferSize(rb.window) {
        glfw.WaitEvents()
        if glfw.WindowShouldClose(rb.window) { break }
    }

    vk.DeviceWaitIdle(rb.device)

    cleanup_swapchain_vulkan()

    create_swapchain()
    create_depth_resources()
    create_framebuffers()
}

// Full Vulkan cleanup
cleanup_vulkan :: proc() {
    vk.DeviceWaitIdle(rb.device)

    // Destroy semaphores
    for sem in rb.image_available_semaphores {
        vk.DestroySemaphore(rb.device, sem, nil)
    }
    for sem in rb.render_finished_semaphores {
        vk.DestroySemaphore(rb.device, sem, nil)
    }
    for fence in rb.in_flight_fences {
        vk.DestroyFence(rb.device, fence, nil)
    }

    // Destroy surface
    vk.DestroySurfaceKHR(rb.instance, rb.surface, nil)

    // Destroy device
    vk.DestroyDevice(rb.device, nil)

    // Additional compute cleanup from DestroyCompute
    gpu.vbuffer_destroy(&rt.compute.uniform_buffer, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.verts, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.faces, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.blas, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.shapes, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.primitives, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.materials, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.lights, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.guis, &rb.vma_allocator)
    gpu.vbuffer_destroy(&rt.compute.storage_buffers.bvh, &rb.vma_allocator)

    // Destroy compute texture
    texture_destroy(&rt.compute_texture, rb.device, &rb.vma_allocator)

    // Destroy GUI textures
    for &tex in rt.gui_textures {
        texture_destroy(&tex, rb.device, &rb.vma_allocator)
    }

    // Destroy bindless textures
    for &tex in rt.bindless_textures {
        texture_destroy(&tex, rb.device, &rb.vma_allocator)
    }

    // Destroy pipeline cache
    vk.DestroyPipelineCache(rb.device, rb.pipeline_cache, nil)

    // Destroy pipelines and layouts
    vk.DestroyPipeline(rb.device, rt.compute.pipeline, nil)
    vk.DestroyPipelineLayout(rb.device, rt.compute.pipeline_layout, nil)
    vk.DestroyDescriptorSetLayout(rb.device, rt.compute.descriptor_set_layout, nil)

    // Destroy fence and command pool
    vk.DestroyFence(rb.device, rt.compute.fence, nil)
    vk.DestroyCommandPool(rb.device, rt.compute.command_pool, nil)

    // Cleanup swap chain if not already done
    cleanup_swapchain_vulkan()
}
