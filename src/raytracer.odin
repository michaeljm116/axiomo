package main
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"
import "core:strings"
import "core:slice"
import "core:log"
import "core:os"
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

    ordered_prims_map: []int,

    prepared: bool,
}

//----------------------------------------------------------------------------\\
// /PROCS
//----------------------------------------------------------------------------\\

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
prepare_storage_buffers :: proc(cr: ^ComputeRaytracer) {
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