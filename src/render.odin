package main
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"
import "core:strings"
import "core:slice"
import "core:log"
import "external/vma"


SHADER_VERT :: #load("../assets/shaders/vert.spv")
SHADER_FRAG :: #load("../assets/shaders/frag.spv")

// Enables Vulkan debug logging and validation layers.
ENABLE_VALIDATION_LAYERS :: #config(ENABLE_VALIDATION_LAYERS, ODIN_DEBUG)

MAX_FRAMES_IN_FLIGHT :: 2
RenderBase :: struct{
	ctx: runtime.Context,
	window: glfw.WindowHandle,

	framebuffer_resized: bool,

	instance: vk.Instance,
	physical_device: vk.PhysicalDevice,
	device: vk.Device,
	surface: vk.SurfaceKHR,
	graphics_queue: vk.Queue,
	present_queue: vk.Queue,
	compute_queue: vk.Queue,
	compute_queue_family_index: u32,

	swapchain: vk.SwapchainKHR,
	swapchain_images: []vk.Image,
	swapchain_views: []vk.ImageView,
	swapchain_format: vk.SurfaceFormatKHR,
	swapchain_extent: vk.Extent2D,
	swapchain_frame_buffers: []vk.Framebuffer,

	vert_shader_module: vk.ShaderModule,
	frag_shader_module: vk.ShaderModule,
	shader_stages: [2]vk.PipelineShaderStageCreateInfo,

	render_pass: vk.RenderPass,
	pipeline_layout: vk.PipelineLayout,
	pipeline: vk.Pipeline,
	pipeline_cache: vk.PipelineCache,

	command_pool: vk.CommandPool,
	command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,

	image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,

	vma_allocator: vma.Allocator,

	depth_image : vk.Image,
	depth_allocation : vma.Allocation,
	depth_view: vk.ImageView,
}

rb : RenderBase

// KHR_PORTABILITY_SUBSET_EXTENSION_NAME :: "VK_KHR_portability_subset"

DEVICE_EXTENSIONS := []cstring {
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
	// KHR_PORTABILITY_SUBSET_EXTENSION_NAME,
}

init_vulkan :: proc()
{
    glfw.SetErrorCallback(glfw_error_callback)

	if !glfw.Init() {log.panic("glfw: could not be initialized")}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)

	rb.window = glfw.CreateWindow(800, 600, "Vulkan", nil, nil)
	defer glfw.DestroyWindow(rb.window)

	glfw.SetFramebufferSizeCallback(rb.window, proc "c" (_: glfw.WindowHandle, _, _: i32) {
		rb.framebuffer_resized = true
	})

	//----------------------------------------------------------------------------\\
    // /Create Instance /ci
    //----------------------------------------------------------------------------\\
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	assert(vk.CreateInstance != nil, "vulkan function pointers not loaded")

	create_info := vk.InstanceCreateInfo {
		sType            = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &vk.ApplicationInfo {
			sType = .APPLICATION_INFO,
			pApplicationName = "Hello Triangle",
			applicationVersion = vk.MAKE_VERSION(1, 0, 0),
			pEngineName = "No Engine",
			engineVersion = vk.MAKE_VERSION(1, 0, 0),
			apiVersion = vk.API_VERSION_1_2,
		},
	}

	extensions := slice.clone_to_dynamic(glfw.GetRequiredInstanceExtensions(), context.temp_allocator)

	// MacOS is a special snowflake ;)
	when ODIN_OS == .Darwin {
		create_info.flags |= {.ENUMERATE_PORTABILITY_KHR}
		append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
	}

	when ENABLE_VALIDATION_LAYERS {
		create_info.ppEnabledLayerNames = raw_data([]cstring{"VK_LAYER_KHRONOS_validation"})
		create_info.enabledLayerCount = 1

		append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

		// Severity based on logger level.
		severity: vk.DebugUtilsMessageSeverityFlagsEXT
		if context.logger.lowest_level <= .Error {
			severity |= {.ERROR}
		}
		if context.logger.lowest_level <= .Warning {
			severity |= {.WARNING}
		}
		if context.logger.lowest_level <= .Info {
			severity |= {.INFO}
		}
		if context.logger.lowest_level <= .Debug {
			severity |= {.VERBOSE}
		}

		dbg_create_info := vk.DebugUtilsMessengerCreateInfoEXT {
			sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			messageSeverity = severity,
			messageType     = {.GENERAL, .VALIDATION, .PERFORMANCE, .DEVICE_ADDRESS_BINDING}, // all of them.
			pfnUserCallback = vk_messenger_callback,
		}
		create_info.pNext = &dbg_create_info
	}

	create_info.enabledExtensionCount = u32(len(extensions))
	create_info.ppEnabledExtensionNames = raw_data(extensions)

	must(vk.CreateInstance(&create_info, nil, &rb.instance))
	defer vk.DestroyInstance(rb.instance, nil)

	vk.load_proc_addresses_instance(rb.instance)

	when ENABLE_VALIDATION_LAYERS {
		dbg_messenger: vk.DebugUtilsMessengerEXT
		must(vk.CreateDebugUtilsMessengerEXT(rb.instance, &dbg_create_info, nil, &dbg_messenger))
		defer vk.DestroyDebugUtilsMessengerEXT(rb.instance, dbg_messenger, nil)
	}

	//----------------------------------------------------------------------------\\
    // /Create Surface and Devices /cs
    //----------------------------------------------------------------------------\\
	must(glfw.CreateWindowSurface(rb.instance, rb.window, nil, &rb.surface))
	defer vk.DestroySurfaceKHR(rb.instance, rb.surface, nil)

	// Pick a suitable GPU.
	must(pick_physical_device())

	// Setup logical device,
	indices := find_queue_families(rb.physical_device)
	set_compute_queue_family_index(rb.physical_device, &indices)
	rb.compute_queue_family_index = indices.compute.?
	{
		// TODO: this is kinda messy.
		indices_set := make(map[u32]struct {}, allocator = context.temp_allocator)
		indices_set[indices.graphics.?] = {}
		indices_set[indices.present.?] = {}
		indices_set[indices.compute.?] = {}

		queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo, 0, len(indices_set), context.temp_allocator)
		for i in indices_set {
			append(
				&queue_create_infos,
				vk.DeviceQueueCreateInfo {
					sType = .DEVICE_QUEUE_CREATE_INFO,
					queueFamilyIndex = i,
					queueCount = u32(len(indices_set)),
					pQueuePriorities = raw_data([]f32{1,0}),
				},// Scheduling priority between 0 and 1.
			)
		}

		device_create_info := vk.DeviceCreateInfo {
			sType                   = .DEVICE_CREATE_INFO,
			pQueueCreateInfos       = raw_data(queue_create_infos),
			queueCreateInfoCount    = u32(len(queue_create_infos)),
			enabledLayerCount       = create_info.enabledLayerCount,
			ppEnabledLayerNames     = create_info.ppEnabledLayerNames,
			//ppEnabledExtensionNames = raw_data(DEVICE_EXTENSIONS),
			//enabledExtensionCount   = u32(len(DEVICE_EXTENSIONS)),
			pEnabledFeatures = nil, // &device_features.features, // TODO: enable more features.
		}
		//----------------------------------------------------------------------------\\
		// /Bindless /bi add bindless support if it has it
		//----------------------------------------------------------------------------\\
		{
		    indexing_features := vk.PhysicalDeviceDescriptorIndexingFeatures {
		        sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES,
				pNext = nil,
		    }
			device_features := vk.PhysicalDeviceFeatures2 {
				sType = .PHYSICAL_DEVICE_FEATURES_2,
				pNext = &indexing_features,
			}
			physical_features := vk.PhysicalDeviceFeatures2 {
				sType = .PHYSICAL_DEVICE_FEATURES_2,
				pNext = &device_features,
			}
			vk.GetPhysicalDeviceFeatures2(rb.physical_device, &device_features)
			vk.GetPhysicalDeviceFeatures2(rb.physical_device, &physical_features)
			bindless_supported := indexing_features.descriptorBindingPartiallyBound && indexing_features.runtimeDescriptorArray
			if bindless_supported {
				log.info("vulkan: bindless descriptor indexing supported")
				device_create_info.pNext = &indexing_features
				device_create_info.enabledExtensionCount += 1
			} else {
				log.info("vulkan: bindless descriptor indexing not supported")
			}
			device_features.features.samplerAnisotropy = true
		}

		// Back to creating logical device
		device_create_info.enabledExtensionCount = u32(len(DEVICE_EXTENSIONS))
		device_create_info.ppEnabledExtensionNames = raw_data(DEVICE_EXTENSIONS)

		//TODO : ENABLE VALIDATION LAYERS

		must(vk.CreateDevice(rb.physical_device, &device_create_info, nil, &rb.device))

		vk.GetDeviceQueue(rb.device, indices.graphics.?, 0, &rb.graphics_queue)
		vk.GetDeviceQueue(rb.device, indices.present.?, 0, &rb.present_queue)
		vk.GetDeviceQueue(rb.device, indices.compute.?, rb.compute_queue_family_index, &rb.compute_queue)
	}
	defer vk.DestroyDevice(rb.device, nil)

	init_vma()

	create_swapchain()
	defer destroy_swapchain()

	// Load shaders.
	{
		rb.vert_shader_module = create_shader_module(SHADER_VERT)
		rb.shader_stages[0] = vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {.VERTEX},
			module = rb.vert_shader_module,
			pName  = "main",
		}

		rb.frag_shader_module = create_shader_module(SHADER_FRAG)
		rb.shader_stages[1] = vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {.FRAGMENT},
			module = rb.frag_shader_module,
			pName  = "main",
		}
	}
	defer vk.DestroyShaderModule(rb.device, rb.vert_shader_module, nil)
	defer vk.DestroyShaderModule(rb.device, rb.frag_shader_module, nil)

	// Set up render pass.
	{
		color_attachment := vk.AttachmentDescription {
			format         = rb.swapchain_format.format,
			samples        = {._1},
			loadOp         = .CLEAR,
			storeOp        = .STORE,
			stencilLoadOp  = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout  = .UNDEFINED,
			finalLayout    = .PRESENT_SRC_KHR,
		}

		color_attachment_ref := vk.AttachmentReference {
			attachment = 0,
			layout     = .COLOR_ATTACHMENT_OPTIMAL,
		}

		depth_attachment := vk.AttachmentDescription{
			format = find_depth_format(),
			samples = {._1},
			loadOp = .CLEAR,
			storeOp = .DONT_CARE,
			stencilLoadOp = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout = .UNDEFINED,
			finalLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
		}

		depth_attachment_ref := vk.AttachmentReference{
			attachment = 1,
			layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
		}

		subpass := vk.SubpassDescription {
			pipelineBindPoint    = .GRAPHICS,
			colorAttachmentCount = 1,
			pColorAttachments    = &color_attachment_ref,
			pDepthStencilAttachment = &depth_attachment_ref
		}

		dependency := vk.SubpassDependency {
			srcSubpass    = vk.SUBPASS_EXTERNAL,
			dstSubpass    = 0,
			srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
			srcAccessMask = {},
			dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
			dstAccessMask = {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
		}
		attachments := []vk.AttachmentDescription{color_attachment, depth_attachment}

		render_pass := vk.RenderPassCreateInfo {
			sType           = .RENDER_PASS_CREATE_INFO,
			attachmentCount = u32(len(attachments)),
			pAttachments    = raw_data(attachments),
			subpassCount    = 1,
			pSubpasses      = &subpass,
			dependencyCount = 1,
			pDependencies   = &dependency,
		}

		must(vk.CreateRenderPass(rb.device, &render_pass, nil, &rb.render_pass))
	}
	defer vk.DestroyRenderPass(rb.device, rb.render_pass, nil)


	// Set up pipeline.
	{
		dynamic_states := []vk.DynamicState{.VIEWPORT, .SCISSOR}
		dynamic_state := vk.PipelineDynamicStateCreateInfo {
			sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
			dynamicStateCount = 2,
			pDynamicStates    = raw_data(dynamic_states),
		}

		vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
			sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		}

		input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
			sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			topology = .TRIANGLE_LIST,
		}

		viewport_state := vk.PipelineViewportStateCreateInfo {
			sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			viewportCount = 1,
			scissorCount  = 1,
		}

		rasterizer := vk.PipelineRasterizationStateCreateInfo {
			sType       = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			polygonMode = .FILL,
			lineWidth   = 1,
			cullMode    = {.BACK},
			frontFace   = .CLOCKWISE,
		}

		multisampling := vk.PipelineMultisampleStateCreateInfo {
			sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			rasterizationSamples = {._1},
			minSampleShading     = 1,
		}

		color_blend_attachment := vk.PipelineColorBlendAttachmentState {
			colorWriteMask = {.R, .G, .B, .A},
		}

		color_blending := vk.PipelineColorBlendStateCreateInfo {
			sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			attachmentCount = 1,
			pAttachments    = &color_blend_attachment,
		}

		pipeline_layout := vk.PipelineLayoutCreateInfo {
			sType = .PIPELINE_LAYOUT_CREATE_INFO,
		}
		must(vk.CreatePipelineLayout(rb.device, &pipeline_layout, nil, &rb.pipeline_layout))

		pipeline := vk.GraphicsPipelineCreateInfo {
			sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
			stageCount          = 2,
			pStages             = &rb.shader_stages[0],
			pVertexInputState   = &vertex_input_info,
			pInputAssemblyState = &input_assembly,
			pViewportState      = &viewport_state,
			pRasterizationState = &rasterizer,
			pMultisampleState   = &multisampling,
			pColorBlendState    = &color_blending,
			pDynamicState       = &dynamic_state,
			layout              = rb.pipeline_layout,
			renderPass          = rb.render_pass,
			subpass             = 0,
			basePipelineIndex   = -1,
		}
		must(vk.CreateGraphicsPipelines(rb.device, 0, 1, &pipeline, nil, &rb.pipeline))
	}
	defer vk.DestroyPipelineLayout(rb.device, rb.pipeline_layout, nil)
	defer vk.DestroyPipeline(rb.device, rb.pipeline, nil)


	// Create command pool.
	{
		pool_info := vk.CommandPoolCreateInfo {
			sType            = .COMMAND_POOL_CREATE_INFO,
			flags            = {.RESET_COMMAND_BUFFER},
			queueFamilyIndex = indices.graphics.?,
		}
		must(vk.CreateCommandPool(rb.device, &pool_info, nil, &rb.command_pool))

		alloc_info := vk.CommandBufferAllocateInfo {
			sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool        = rb.command_pool,
			level              = .PRIMARY,
			commandBufferCount = MAX_FRAMES_IN_FLIGHT,
		}
		must(vk.AllocateCommandBuffers(rb.device, &alloc_info, &rb.command_buffers[0]))
	}
	defer vk.DestroyCommandPool(rb.device, rb.command_pool, nil)

	create_depth_resources()
	create_framebuffers()
	defer destroy_framebuffers()

	// Set up sync primitives.
	{
		sem_info := vk.SemaphoreCreateInfo {
			sType = .SEMAPHORE_CREATE_INFO,
		}
		fence_info := vk.FenceCreateInfo {
			sType = .FENCE_CREATE_INFO,
			flags = {.SIGNALED},
		}
		for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
			must(vk.CreateSemaphore(rb.device, &sem_info, nil, &rb.image_available_semaphores[i]))
			must(vk.CreateSemaphore(rb.device, &sem_info, nil, &rb.render_finished_semaphores[i]))
			must(vk.CreateFence(rb.device, &fence_info, nil, &rb.in_flight_fences[i]))
		}
	}
	defer for sem in rb.image_available_semaphores {vk.DestroySemaphore(rb.device, sem, nil)}
	defer for sem in rb.render_finished_semaphores {vk.DestroySemaphore(rb.device, sem, nil)}
	defer for fence in rb.in_flight_fences {vk.DestroyFence(rb.device, fence, nil)}

	current_frame := 0
	for !glfw.WindowShouldClose(rb.window) {
		free_all(context.temp_allocator)

		glfw.PollEvents()

		// Wait for previous frame.
		must(vk.WaitForFences(rb.device, 1, &rb.in_flight_fences[current_frame], true, max(u64)))

		// Acquire an image from the swapchain.
		image_index: u32
		acquire_result := vk.AcquireNextImageKHR(
			rb.device,
			rb.swapchain,
			max(u64),
			rb.image_available_semaphores[current_frame],
			0,
			&image_index,
		)
		#partial switch acquire_result {
		case .ERROR_OUT_OF_DATE_KHR:
			recreate_swapchain()
			continue
		case .SUCCESS, .SUBOPTIMAL_KHR:
		case:
			log.panicf("vulkan: acquire next image failure: %v", acquire_result)
		}

		must(vk.ResetFences(rb.device, 1, &rb.in_flight_fences[current_frame]))

		must(vk.ResetCommandBuffer(rb.command_buffers[current_frame], {}))
		record_command_buffer(rb.command_buffers[current_frame], image_index)

		// Submit.
		submit_info := vk.SubmitInfo {
			sType                = .SUBMIT_INFO,
			waitSemaphoreCount   = 1,
			pWaitSemaphores      = &rb.image_available_semaphores[current_frame],
			pWaitDstStageMask    = &vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT},
			commandBufferCount   = 1,
			pCommandBuffers      = &rb.command_buffers[current_frame],
			signalSemaphoreCount = 1,
			pSignalSemaphores    = &rb.render_finished_semaphores[current_frame],
		}
		must(vk.QueueSubmit(rb.graphics_queue, 1, &submit_info, rb.in_flight_fences[current_frame]))

		// Present.
		present_info := vk.PresentInfoKHR {
			sType              = .PRESENT_INFO_KHR,
			waitSemaphoreCount = 1,
			pWaitSemaphores    = &rb.render_finished_semaphores[current_frame],
			swapchainCount     = 1,
			pSwapchains        = &rb.swapchain,
			pImageIndices      = &image_index,
		}
		present_result := vk.QueuePresentKHR(rb.present_queue, &present_info)
		switch {
		case present_result == .ERROR_OUT_OF_DATE_KHR || present_result == .SUBOPTIMAL_KHR || rb.framebuffer_resized:
			rb.framebuffer_resized = false
			recreate_swapchain()
		case present_result == .SUCCESS:
		case:
			log.panicf("vulkan: present failure: %v", present_result)
		}

		current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT
	}
	vk.DeviceWaitIdle(rb.device)
}

@(require_results)
pick_physical_device :: proc() -> vk.Result {

	score_physical_device :: proc(device: vk.PhysicalDevice) -> (score: int) {
		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(device, &props)

		name := byte_arr_str(&props.deviceName)
		log.infof("vulkan: evaluating device %q", name)
		defer log.infof("vulkan: device %q scored %v", name, score)

		features: vk.PhysicalDeviceFeatures
		vk.GetPhysicalDeviceFeatures(device, &features)

		// Need certain extensions supported.
		{
			extensions, result := physical_device_extensions(device, context.temp_allocator)
			if result != .SUCCESS {
				log.infof("vulkan: enumerate device extension properties failed: %v", result)
				return 0
			}

			required_loop: for required in DEVICE_EXTENSIONS {
				for &extension in extensions {
					extension_name := byte_arr_str(&extension.extensionName)
					if extension_name == string(required) {
						continue required_loop
					}
				}

				log.infof("vulkan: device does not support required extension %q", required)
				return 0
			}
		}

		// Check if swapchain is adequately supported.
		{
			support, result := query_swapchain_support(device, context.temp_allocator)
			if result != .SUCCESS {
				log.infof("vulkan: query swapchain support failure: %v", result)
				return 0
			}

			// Need at least a format and present mode.
			if len(support.formats) == 0 || len(support.presentModes) == 0 {
				log.info("vulkan: device does not support swapchain")
				return 0
			}
		}

		families := find_queue_families(device)
		if _, has_graphics := families.graphics.?; !has_graphics {
			log.info("vulkan: device does not have a graphics queue")
			return 0
		}
		if _, has_present := families.present.?; !has_present {
			log.info("vulkan: device does not have a presentation queue")
			return 0
		}

		// Favor GPUs.
		switch props.deviceType {
		case .DISCRETE_GPU:
			score += 300_000
		case .INTEGRATED_GPU:
			score += 200_000
		case .VIRTUAL_GPU:
			score += 100_000
		case .CPU, .OTHER:
		}
		log.infof("vulkan: scored %i based on device type %v", score, props.deviceType)

		// Maximum texture size.
		score += int(props.limits.maxImageDimension2D)
		log.infof(
			"vulkan: added the max 2D image dimensions (texture size) of %v to the score",
			props.limits.maxImageDimension2D,
		)
		return
	}

	count: u32
	vk.EnumeratePhysicalDevices(rb.instance, &count, nil) or_return
	if count == 0 {log.panic("vulkan: no GPU found")}

	devices := make([]vk.PhysicalDevice, count, context.temp_allocator)
	vk.EnumeratePhysicalDevices(rb.instance, &count, raw_data(devices)) or_return

	best_device_score := -1
	for device in devices {
		if score := score_physical_device(device); score > best_device_score {
			rb.physical_device = device
			best_device_score = score
		}
	}

	if best_device_score <= 0 {
		log.panic("vulkan: no suitable GPU found")
	}
	return .SUCCESS
}

Queue_Family_Indices :: struct {
	graphics: Maybe(u32),
	present:  Maybe(u32),
	compute:  Maybe(u32)
}

find_queue_families :: proc(device: vk.PhysicalDevice) -> (ids: Queue_Family_Indices) {
	count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)

	families := make([]vk.QueueFamilyProperties, count, context.temp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(families))

	for family, i in families {
		if .GRAPHICS in family.queueFlags {
			ids.graphics = u32(i)
		}

		supported: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), rb.surface, &supported)
		if supported {
			ids.present = u32(i)
		}

		// Found all needed queues?
		_, has_graphics := ids.graphics.?
		_, has_present := ids.present.?
		if has_graphics && has_present {
			break
		}
	}
	return
}

set_compute_queue_family_index :: proc(device: vk.PhysicalDevice, ids: ^Queue_Family_Indices)
{
   count: u32
   vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)
   fams := make([]vk.QueueFamilyProperties, count, context.temp_allocator)
   vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(fams))

   compute_fams : [dynamic]vk.QueueFamilyProperties
   c : [dynamic] u32
   i : u32
   for fam, i in fams{
       if .COMPUTE in fam.queueFlags{
           append(&compute_fams, fam)
           append(&c, u32(i))
       }
   }
   for cfam, ci in compute_fams{
       if .GRAPHICS not_in cfam.queueFlags{
		ids.compute = c[ci]
		return
       }
   }
   if(len(c) > 0){
       ids.compute = c[0]
   }
}

Swapchain_Support :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats:      []vk.SurfaceFormatKHR,
	presentModes: []vk.PresentModeKHR,
}

query_swapchain_support :: proc(
	device: vk.PhysicalDevice,
	allocator := context.temp_allocator,
) -> (
	support: Swapchain_Support,
	result: vk.Result,
) {
	// NOTE: looks like a wrong binding with the third arg being a multipointer.
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, rb.surface, &support.capabilities) or_return

	{
		count: u32
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, rb.surface, &count, nil) or_return

		support.formats = make([]vk.SurfaceFormatKHR, count, allocator)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, rb.surface, &count, raw_data(support.formats)) or_return
	}

	{
		count: u32
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, rb.surface, &count, nil) or_return

		support.presentModes = make([]vk.PresentModeKHR, count, allocator)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, rb.surface, &count, raw_data(support.presentModes)) or_return
	}

	return
}

choose_swapchain_surface_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	for format in formats {
		if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
			return format
		}
	}

	// Fallback non optimal.
	return formats[0]
}

choose_swapchain_present_mode :: proc(modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
	// We would like mailbox for the best tradeoff between tearing and latency.
	for mode in modes {
		if mode == .MAILBOX {
			return .MAILBOX
		}
	}

	// As a fallback, fifo (basically vsync) is always available.
	return .FIFO
}

choose_swapchain_extent :: proc(capabilities: vk.SurfaceCapabilitiesKHR) -> vk.Extent2D {
	if capabilities.currentExtent.width != max(u32) {
		return capabilities.currentExtent
	}

	width, height := glfw.GetFramebufferSize(rb.window)
	return(
		vk.Extent2D {
			width = clamp(u32(width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
			height = clamp(u32(height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
		} \
	)
}

find_supported_format :: proc(candidates : []vk.Format, tiling : vk.ImageTiling, features : vk.FormatFeatureFlags) -> vk.Format
{
	for format in candidates{
		props : vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(rb.physical_device, format, &props)

		if(tiling == .LINEAR && (props.linearTilingFeatures & features) == features) do return format
		else if (tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features) do return format
		log.panicf("Failed to Find supported Format!")
	}
	return {};
}

find_depth_format :: proc() -> vk.Format
{
	return find_supported_format(
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		vk.ImageTiling.OPTIMAL,
		vk.FormatFeatureFlags{.DEPTH_STENCIL_ATTACHMENT}
	)
}

glfw_error_callback :: proc "c" (code: i32, description: cstring) {
	context = rb.ctx
	log.errorf("glfw: %i: %s", code, description)
}

vk_messenger_callback :: proc "system" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
	messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	context = rb.ctx

	level: log.Level
	if .ERROR in messageSeverity {
		level = .Error
	} else if .WARNING in messageSeverity {
		level = .Warning
	} else if .INFO in messageSeverity {
		level = .Info
	} else {
		level = .Debug
	}

	log.logf(level, "vulkan[%v]: %s", messageTypes, pCallbackData.pMessage)
	return false
}

physical_device_extensions :: proc(
	device: vk.PhysicalDevice,
	allocator := context.temp_allocator,
) -> (
	exts: []vk.ExtensionProperties,
	res: vk.Result,
) {
	count: u32
	vk.EnumerateDeviceExtensionProperties(device, nil, &count, nil) or_return

	exts = make([]vk.ExtensionProperties, count, allocator)
	vk.EnumerateDeviceExtensionProperties(device, nil, &count, raw_data(exts)) or_return

	return
}

create_swapchain :: proc() {
	indices := find_queue_families(rb.physical_device)
	// Setup swapchain.
	{
		support, result := query_swapchain_support(rb.physical_device, context.temp_allocator)
		if result != .SUCCESS {
			log.panicf("vulkan: query swapchain failed: %v", result)
		}

		surface_format := choose_swapchain_surface_format(support.formats)
		present_mode := choose_swapchain_present_mode(support.presentModes)
		extent := choose_swapchain_extent(support.capabilities)

		rb.swapchain_format = surface_format
		rb.swapchain_extent = extent

		image_count := support.capabilities.minImageCount + 1
		if support.capabilities.maxImageCount > 0 && image_count > support.capabilities.maxImageCount {
			image_count = support.capabilities.maxImageCount
		}

		create_info := vk.SwapchainCreateInfoKHR {
			sType            = .SWAPCHAIN_CREATE_INFO_KHR,
			surface          = rb.surface,
			minImageCount    = image_count,
			imageFormat      = surface_format.format,
			imageColorSpace  = surface_format.colorSpace,
			imageExtent      = extent,
			imageArrayLayers = 1,
			imageUsage       = {.COLOR_ATTACHMENT},
			preTransform     = support.capabilities.currentTransform,
			compositeAlpha   = {.OPAQUE},
			presentMode      = present_mode,
			clipped          = true,
		}

		if indices.graphics != indices.present {
			create_info.imageSharingMode = .CONCURRENT
			create_info.queueFamilyIndexCount = 2
			create_info.pQueueFamilyIndices = raw_data([]u32{indices.graphics.?, indices.present.?})
		}
		else {
			create_info.imageSharingMode = .EXCLUSIVE
			create_info.queueFamilyIndexCount = 0
			create_info.pQueueFamilyIndices = nil
		}
		// specify the transform, like a 90deg rotation or a flip
		create_info.preTransform = support.capabilities.currentTransform
		// specify if the alpha should be used for blending with other windows
		create_info.compositeAlpha = vk.CompositeAlphaFlagsKHR{.OPAQUE}
		create_info.presentMode = present_mode
		create_info.clipped = true

		must(vk.CreateSwapchainKHR(rb.device, &create_info, nil, &rb.swapchain))
	}

	// Setup swapchain images.
	{
		count: u32
		must(vk.GetSwapchainImagesKHR(rb.device, rb.swapchain, &count, nil))

		rb.swapchain_images = make([]vk.Image, count)
		rb.swapchain_views = make([]vk.ImageView, count)
		must(vk.GetSwapchainImagesKHR(rb.device, rb.swapchain, &count, raw_data(rb.swapchain_images)))

		for image, i in rb.swapchain_images {
			create_info := vk.ImageViewCreateInfo {
				sType = .IMAGE_VIEW_CREATE_INFO,
				image = image,
				viewType = .D2,
				format = rb.swapchain_format.format,
				subresourceRange = {aspectMask = {.COLOR}, levelCount = 1, layerCount = 1},
			}
			must(vk.CreateImageView(rb.device, &create_info, nil, &rb.swapchain_views[i]))
		}
	}
}

destroy_swapchain :: proc() {
	for view in rb.swapchain_views {
		vk.DestroyImageView(rb.device, view, nil)
	}
	delete(rb.swapchain_views)
	delete(rb.swapchain_images)
	vk.DestroySwapchainKHR(rb.device, rb.swapchain, nil)
}

create_framebuffers :: proc() {
    rb.swapchain_frame_buffers = make([]vk.Framebuffer, len(rb.swapchain_views))
    for view, i in rb.swapchain_views {
        attachments := []vk.ImageView{view, rb.depth_view} // Color and depth attachments
        frame_buffer := vk.FramebufferCreateInfo {
            sType           = .FRAMEBUFFER_CREATE_INFO,
            renderPass      = rb.render_pass,
            attachmentCount = 2,
            pAttachments    = raw_data(attachments),
            width           = rb.swapchain_extent.width,
            height          = rb.swapchain_extent.height,
            layers          = 1,
        }
        must(vk.CreateFramebuffer(rb.device, &frame_buffer, nil, &rb.swapchain_frame_buffers[i]))
    }
}

create_pipeline_cache :: proc()
{
	create_info : vk.PipelineCacheCreateInfo = {
		sType = .PIPELINE_CACHE_CREATE_INFO,
	}
	must(vk.CreatePipelineCache(rb.device, &create_info, nil, &rb.pipeline_cache))
}

init_vma :: proc()
{
	vma_funcs := vma.create_vulkan_functions()

	create_info := vma.AllocatorCreateInfo {
		flags = {.EXT_MEMORY_BUDGET},
		vulkanApiVersion = vk.API_VERSION_1_2,
		instance = rb.instance,
		device = rb.device,
		physicalDevice = rb.physical_device,
		pVulkanFunctions = &vma_funcs
	}
	must(vma.CreateAllocator(&create_info, &rb.vma_allocator))
}

create_depth_resources :: proc() {
    depth_format := find_depth_format()
    create_image(rb.swapchain_extent.width, rb.swapchain_extent.height, depth_format, .OPTIMAL, .DEPTH_STENCIL_ATTACHMENT, &rb.depth_image, &rb.depth_allocation)
    rb.depth_view = create_image_view(rb.depth_image, depth_format, {.DEPTH})
    transition_image_layout(rb.depth_image, depth_format, .UNDEFINED, .DEPTH_STENCIL_ATTACHMENT_OPTIMAL)
}
destroy_depth_resources :: proc() {
    vk.DestroyImageView(rb.device, rb.depth_view, nil)
    vma.DestroyImage(rb.vma_allocator, rb.depth_image, rb.depth_allocation)
}

create_image :: proc (width, height : u32,
	format : vk.Format, tiling : vk.ImageTiling,
	usage : vk.ImageUsageFlag, image : ^vk.Image,
	allocation : ^vma.Allocation
)
{
	image_info := vk.ImageCreateInfo{
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		extent = {width = width, height = height, depth = 1},
		mipLevels = 1,
		arrayLayers = 1,
		format = format,
		tiling = tiling,
		initialLayout = .UNDEFINED,
		usage = {usage},
		samples = {._1},
		sharingMode = .EXCLUSIVE
	}

	alloc_info := vma.AllocationCreateInfo{usage = .AUTO}
	must(vma.CreateImage(rb.vma_allocator, &image_info, &alloc_info, image, allocation, nil))
}

create_image_view :: proc(image: vk.Image, format: vk.Format, aspect_mask: vk.ImageAspectFlags) -> vk.ImageView {
    view_info := vk.ImageViewCreateInfo{
        sType = .IMAGE_VIEW_CREATE_INFO,
        image = image,
        viewType = .D2,
        format = format,
        subresourceRange = {
            aspectMask = aspect_mask,
            levelCount = 1,
            layerCount = 1,
        },
    }
    view: vk.ImageView
    must(vk.CreateImageView(rb.device, &view_info, nil, &view))
    return view
}

create_buffer :: proc(allocator : vma.Allocator, size : vk.DeviceSize, usage : vk.BufferUsageFlags, allocation : ^vma.Allocation, buffer : ^vk.Buffer)
{
	buffer_info := vk.BufferCreateInfo{
		sType = .BUFFER_CREATE_INFO,
		size = size,
		usage = usage,
		sharingMode = .EXCLUSIVE
	}
	alloc_info := vma.AllocationCreateInfo{usage = .AUTO}
	must(vma.CreateBuffer(allocator, &buffer_info, &alloc_info, buffer, allocation, nil))
}

destroy_framebuffers :: proc() {
	for frame_buffer in rb.swapchain_frame_buffers {vk.DestroyFramebuffer(rb.device, frame_buffer, nil)}
	delete(rb.swapchain_frame_buffers)
}

recreate_swapchain :: proc() {
    // Don't do anything when minimized.
    for w, h := glfw.GetFramebufferSize(rb.window); w == 0 || h == 0; w, h = glfw.GetFramebufferSize(rb.window) {
        glfw.WaitEvents()
        if glfw.WindowShouldClose(rb.window) { break }
    }

    vk.DeviceWaitIdle(rb.device)

    destroy_framebuffers()
    destroy_depth_resources()
    destroy_swapchain()

    create_swapchain()
    create_depth_resources()
    create_framebuffers()
}

create_shader_module :: proc(code: []byte) -> (module: vk.ShaderModule) {
	as_u32 := slice.reinterpret([]u32, code)

	create_info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(code),
		pCode    = raw_data(as_u32),
	}
	must(vk.CreateShaderModule(rb.device, &create_info, nil, &module))
	return
}

record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) {
    begin_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
    }
    must(vk.BeginCommandBuffer(command_buffer, &begin_info))

    clear_values: [2]vk.ClearValue
    clear_values[0].color.float32 = {0.0, 0.0, 0.0, 1.0} // Color clear value
    clear_values[1].depthStencil = {depth = 1.0, stencil = 0} // Depth clear value

    render_pass_info := vk.RenderPassBeginInfo {
        sType = .RENDER_PASS_BEGIN_INFO,
        renderPass = rb.render_pass,
        framebuffer = rb.swapchain_frame_buffers[image_index],
        renderArea = {extent = rb.swapchain_extent},
        clearValueCount = 2,
        pClearValues = &clear_values[0],
    }
    vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)

    vk.CmdBindPipeline(command_buffer, .GRAPHICS, rb.pipeline)

    viewport := vk.Viewport {
        width    = f32(rb.swapchain_extent.width),
        height   = f32(rb.swapchain_extent.height),
        maxDepth = 1.0,
    }
    vk.CmdSetViewport(command_buffer, 0, 1, &viewport)

    scissor := vk.Rect2D {
        extent = rb.swapchain_extent,
    }
    vk.CmdSetScissor(command_buffer, 0, 1, &scissor)

    vk.CmdDraw(command_buffer, 3, 1, 0, 0)

    vk.CmdEndRenderPass(command_buffer)

    must(vk.EndCommandBuffer(command_buffer))
}

byte_arr_str :: proc(arr: ^[$N]byte) -> string {
	return strings.truncate_to_byte(string(arr[:]), 0)
}

must :: proc(result: vk.Result, loc := #caller_location) {
	if result != .SUCCESS {
		log.panicf("vulkan failure %v", result, location = loc)
	}
}

begin_single_time_commands :: proc() -> vk.CommandBuffer {
    alloc_info := vk.CommandBufferAllocateInfo {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = rb.command_pool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }
    command_buffer: vk.CommandBuffer
    must(vk.AllocateCommandBuffers(rb.device, &alloc_info, &command_buffer))

    begin_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = {.ONE_TIME_SUBMIT},
    }
    must(vk.BeginCommandBuffer(command_buffer, &begin_info))
    return command_buffer
}

end_single_time_commands :: proc(command_buffer: ^vk.CommandBuffer) {
    must(vk.EndCommandBuffer(command_buffer^))

    submit_info := vk.SubmitInfo {
        sType              = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers    = command_buffer,
    }
    must(vk.QueueSubmit(rb.graphics_queue, 1, &submit_info, 0))
    must(vk.QueueWaitIdle(rb.graphics_queue))

    vk.FreeCommandBuffers(rb.device, rb.command_pool, 1, command_buffer)
}

transition_image_layout :: proc(image: vk.Image, format: vk.Format, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) {
    command_buffer := begin_single_time_commands()

    barrier := vk.ImageMemoryBarrier {
        sType               = .IMAGE_MEMORY_BARRIER,
        oldLayout           = old_layout,
        newLayout           = new_layout,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image               = image,
        subresourceRange    = {
            aspectMask     = {.COLOR},
            baseMipLevel   = 0,
            levelCount     = 1,
            baseArrayLayer = 0,
            layerCount     = 1,
        },
    }

    if new_layout == .DEPTH_STENCIL_ATTACHMENT_OPTIMAL {
        barrier.subresourceRange.aspectMask = {.DEPTH}
        if has_stencil_component(format) {
            barrier.subresourceRange.aspectMask |= {.STENCIL}
        }
    }

    src_stage: vk.PipelineStageFlags
    dst_stage: vk.PipelineStageFlags

    if old_layout == .UNDEFINED && new_layout == .TRANSFER_DST_OPTIMAL {
        barrier.srcAccessMask = {}
        barrier.dstAccessMask = {.TRANSFER_WRITE}
        src_stage = {.TOP_OF_PIPE}
        dst_stage = {.TRANSFER}
    } else if old_layout == .TRANSFER_DST_OPTIMAL && new_layout == .SHADER_READ_ONLY_OPTIMAL {
        barrier.srcAccessMask = {.TRANSFER_WRITE}
        barrier.dstAccessMask = {.SHADER_READ}
        src_stage = {.TRANSFER}
        dst_stage = {.FRAGMENT_SHADER}
    } else if old_layout == .UNDEFINED && new_layout == .DEPTH_STENCIL_ATTACHMENT_OPTIMAL {
        barrier.srcAccessMask = {}
        barrier.dstAccessMask = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE}
        src_stage = {.TOP_OF_PIPE}
        dst_stage = {.EARLY_FRAGMENT_TESTS}
    } else {
        log.panic("unsupported layout transition!")
    }

    vk.CmdPipelineBarrier(
        command_buffer,
        src_stage,
        dst_stage,
        {},
        0, nil,
        0, nil,
        1, &barrier,
    )

    end_single_time_commands(&command_buffer)
}

has_stencil_component :: proc(format: vk.Format) -> bool {
    return format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT
}

copy_buffer_to_image :: proc(buffer: vk.Buffer, image: vk.Image, width, height: u32) {
    command_buffer := begin_single_time_commands()

    region := vk.BufferImageCopy {
        bufferOffset      = 0,
        bufferRowLength   = 0,
        bufferImageHeight = 0,
        imageSubresource  = {
            aspectMask     = {.COLOR},
            mipLevel       = 0,
            baseArrayLayer = 0,
            layerCount     = 1,
        },
        imageOffset       = {0, 0, 0},
        imageExtent       = {width, height, 1},
    }

    vk.CmdCopyBufferToImage(
        command_buffer,
        buffer,
        image,
        .TRANSFER_DST_OPTIMAL,
        1,
        &region,
    )

    end_single_time_commands(&command_buffer)
}

// Pixel and Image structs
PrPixel :: struct {
    r, g, b, a: u8,
}

prpixel_get :: proc(pixel: ^PrPixel, index: int) -> ^u8 {
    assert(index >= 0 && index < 4)
    switch index {
    case 0: return &pixel.r
    case 1: return &pixel.g
    case 2: return &pixel.b
    case 3: return &pixel.a
    case: return &pixel.r
    }
}

PrImage :: struct {
    width, height, channels: i32,
    data: [][]PrPixel,
}

primage_init :: proc(image: ^PrImage, image_width, image_height, image_channels: i32) {
    image.width = image_width
    image.height = image_height
    image.channels = image_channels
    image.data = make([][]PrPixel, image_width)
    for i in 0..<image_width {
        image.data[i] = make([]PrPixel, image_height)
    }
}

primage_load_from_texture :: proc(image: ^PrImage, texture_file: string) {
    // This is a placeholder - you'll need to implement stb_image loading
    // For now, just initialize with default values
    primage_init(image, 512, 512, 4)

    // TODO: Implement stb_image loading
    // stbi_uc* pixels = stbi_load(texture_file.c_str(), &width, &height, &channels, 0);
    // Process pixels and fill image.data
}

primage_destroy :: proc(image: ^PrImage) {
    if image.data != nil {
        for row in image.data {
            delete(row)
        }
        delete(image.data)
    }
}

// Texture struct and related procedures
Texture :: struct {
    image: vk.Image,
    view: vk.ImageView,
    image_layout: vk.ImageLayout,
    image_allocation: vma.Allocation,
    sampler: vk.Sampler,
    width: u32,
    height: u32,
    mip_levels: u32,
    layer_count: u32,
    descriptor: vk.DescriptorImageInfo,
    path: string,
    descriptor_set: vk.DescriptorSet,
}

texture_destroy :: proc(texture: ^Texture, device: vk.Device, allocator: ^vma.Allocator) {
    if texture.sampler != 0 {
        vk.DestroySampler(device, texture.sampler, nil)
    }
    if texture.view != 0 {
        vk.DestroyImageView(device, texture.view, nil)
    }
    if texture.image != 0 {
        vma.DestroyImage(allocator^, texture.image, texture.image_allocation)
    }
}

texture_create :: proc(texture: ^Texture, device: vk.Device, allocator: ^vma.Allocator, path: string) -> bool {
    texture.path = path

    // Load image using stb_image (you'll need to import stb_image bindings)
    // For now, let's assume we have the pixel data somehow
    // This is a placeholder - you'll need to implement image loading
    tex_width: i32 = 512
    tex_height: i32 = 512
    tex_channels: i32 = 4
    image_size := vk.DeviceSize(tex_width * tex_height * 4)

    texture.width = u32(tex_width)
    texture.height = u32(tex_height)

    // Create staging buffer using VMA
    staging_buffer: vk.Buffer
    staging_allocation: vma.Allocation

    staging_buffer_info := vk.BufferCreateInfo {
        sType = .BUFFER_CREATE_INFO,
        size = image_size,
        usage = {.TRANSFER_SRC},
        sharingMode = .EXCLUSIVE,
    }

    staging_alloc_info := vma.AllocationCreateInfo {
        usage = .CPU_ONLY,
        flags = {.MAPPED},
    }

    result := vma.CreateBuffer(allocator^, &staging_buffer_info, &staging_alloc_info, &staging_buffer, &staging_allocation, nil)
    assert(result == .SUCCESS)

    // Map memory and copy pixel data (placeholder)
    data: rawptr
    vma.MapMemory(allocator^, staging_allocation, &data)
    // Copy pixel data here - you'll need to load actual image data
    vma.UnmapMemory(allocator^, staging_allocation)

    // Create image using VMA
    image_info := vk.ImageCreateInfo {
        sType = .IMAGE_CREATE_INFO,
        imageType = .D2,
        extent = {width = u32(tex_width), height = u32(tex_height), depth = 1},
        mipLevels = 1,
        arrayLayers = 1,
        format = .R8G8B8A8_UNORM,
        tiling = .OPTIMAL,
        initialLayout = .UNDEFINED,
        usage = {.TRANSFER_DST, .SAMPLED},
        samples = {._1},
        sharingMode = .EXCLUSIVE,
    }

    image_alloc_info := vma.AllocationCreateInfo {
        usage = .GPU_ONLY,
    }

    result = vma.CreateImage(allocator^, &image_info, &image_alloc_info, &texture.image, &texture.image_allocation, nil)
    assert(result == .SUCCESS)

    // Transition image layout and copy buffer
    transition_image_layout(texture.image, .R8G8B8A8_UNORM, .UNDEFINED, .TRANSFER_DST_OPTIMAL)
    copy_buffer_to_image(staging_buffer, texture.image, u32(tex_width), u32(tex_height))
    transition_image_layout(texture.image, .R8G8B8A8_UNORM, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)

    // Cleanup staging buffer
    vma.DestroyBuffer(allocator^, staging_buffer, staging_allocation)

    // Create image view
    texture.view = create_image_view(texture.image, .R8G8B8A8_UNORM, {.COLOR})

    // Create sampler
    sampler_info := vk.SamplerCreateInfo {
        sType = .SAMPLER_CREATE_INFO,
        magFilter = .LINEAR,
        minFilter = .LINEAR,
        addressModeU = .REPEAT,
        addressModeV = .REPEAT,
        addressModeW = .REPEAT,
        anisotropyEnable = true,
        maxAnisotropy = 16,
        borderColor = .FLOAT_OPAQUE_BLACK,
        unnormalizedCoordinates = false,
        compareEnable = false,
        compareOp = .ALWAYS,
        mipmapMode = .LINEAR,
        mipLodBias = 0.0,
        minLod = 0.0,
        maxLod = 0.0,
    }
    must(vk.CreateSampler(device, &sampler_info, nil, &texture.sampler))

    texture.image_layout = .SHADER_READ_ONLY_OPTIMAL
    texture_update_descriptor(texture)

    return true
}

texture_update_descriptor :: proc(texture: ^Texture) {
    texture.descriptor = vk.DescriptorImageInfo {
        sampler = texture.sampler,
        imageView = texture.view,
        imageLayout = texture.image_layout,
    }
}

