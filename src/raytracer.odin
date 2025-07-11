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
MAX_BINDLESS_TEXTURES :: 256
MAX_TEXTURES :: 10
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
    gui_textures: [MAX_GUIS]Texture,
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

    gpu.vbuffer_init_storage_buffer(
        &rt.compute.storage_buffers.primitives,
        &rb.vma_allocator,
        rt.primitives[:],
        u32(len(rt.primitives)))

   gui_cmp := get_component(g_world_ent, Cmp_Gui)
   gpu_gui := gpu.Gui{min = gui_cmp.min, extents = gui_cmp.extents,
       align_min = gui_cmp.align_min, align_ext = gui_cmp.align_ext,
       layer = gui_cmp.layer, id = gui_cmp.id, alpha = gui_cmp.alpha
   }
   append(&rt.guis, gpu_gui)
   gui_cmp.ref = i32(len(rt.guis))
   gpu.vbuffer_init_storage_buffer(
        &rt.compute.storage_buffers.guis,
        &rb.vma_allocator,
        rt.guis[:],
        u32(len(rt.guis)))
   gpu.vbuffer_init_storage_buffer(
       &rt.compute.storage_buffers.bvh,
       &rb.vma_allocator,
       rt.bvh[:],
       u32(len(rt.bvh)))
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

    // Initialize descriptor (note: imageLayout is set to GENERAL but no transition is performed)
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
    vert_shader_code, ok := os.read_entire_file("../Assets/Shaders/texture.vert.spv")
    if !ok {
        panic("Failed to read vertex shader")
    }
    defer delete(vert_shader_code)

    frag_shader_code, ok2 := os.read_entire_file("../Assets/Shaders/texture.frag.spv")
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

    // Set up write descriptor sets
    write_sets: [13]vk.WriteDescriptorSet
    write_sets[0] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_IMAGE,
        pImageInfo = &rt.compute_texture.descriptor,
    }
    write_sets[1] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 1,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .UNIFORM_BUFFER,
        pBufferInfo = &rt.compute.uniform_buffer.buffer_info,
    }
    write_sets[2] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 2,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.verts.buffer_info,
    }
    write_sets[3] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 3,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.faces.buffer_info,
    }
    write_sets[4] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 4,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.blas.buffer_info,
    }
    write_sets[5] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 5,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.shapes.buffer_info,
    }
    write_sets[6] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 6,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.primitives.buffer_info,
    }
    write_sets[7] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 7,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.materials.buffer_info,
    }
    write_sets[8] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 8,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.lights.buffer_info,
    }
    write_sets[9] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 9,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.guis.buffer_info,
    }
    write_sets[10] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 10,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_BUFFER,
        pBufferInfo = &rt.compute.storage_buffers.bvh.buffer_info,
    }
    write_sets[11] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 11,
        dstArrayElement = 0,
        descriptorCount = MAX_TEXTURES,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &texture_image_infos[0],
    }
    write_sets[12] = {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = rt.compute.descriptor_set,
        dstBinding = 12,
        dstArrayElement = 0,
        descriptorCount = u32(len(rt.bindless_textures)),
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = raw_data(bindless_image_infos),
    }

    // Update descriptor sets
    vk.UpdateDescriptorSets(rb.device, 13, &write_sets[0], 0, nil)

    // Create compute pipeline
    shader_code, ok := os.read_entire_file("../Assets/Shaders/raytracing.comp.spv")
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
    vk.DestroyShaderModule(rb.device, shader_module, nil)

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
}

create_command_buffers :: proc(swap_ratio: f32 = 1.0, offset_width: i32 = 0, offset_height: i32 = 0) {
    // Allocate command buffers if not already done
    if len(rb.command_buffers) == 0 {
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
            newLayout = .SHADER_READ_ONLY_OPTIMAL,
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
        vk.CmdDraw(cmd_buffer, 4, 1, 0, 0)

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
	for &m in g_materials{
	    gpu_mat : gpu.Material = {
			diffuse = m.diffuse,
			reflective = m.reflective,
			roughness = m.roughness,
			transparency = m.transparency,
			refractive_index = m.refractive_index,
			texture_id = m.texture_id
		}
		append(&rt.materials, gpu_mat)
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
    gpu.vbuffer_init_storage_buffer_with_staging_device(vbuf, rb.device, &rb.vma_allocator, rb.command_pool, rb.compute_queue, objects[:], u32(size))
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
    reserve(&rt.primitives, num_prims)
    for op, i in ordered_prims{
        rt.ordered_prims_map[op.primID] = i
        prim := &prims[op.primID]
        pc := get_component(prim, pair(Cmp_Primitive, Cmp_Primitive))
    }
}