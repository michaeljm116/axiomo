package axiom
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"
import "core:strings"
import "core:slice"
import "core:log"
import "external/vma"
import "core:c"
import "core:os"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:fmt"
import "gpu"
import res "resource"
import "external/embree"
import stbi "vendor:stb/image"
import path2 "extensions/filepath2"
import sttt "vendor:stb/truetype"

//----------------------------------------------------------------------------\\
// /RENDERBASE /rb
//----------------------------------------------------------------------------\\
SHADER_VERT :: #load("../../assets/shaders/texture.vert.spv")
SHADER_FRAG :: #load("../../assets/shaders/texture.frag.spv")

// Enables Vulkan debug logging and validation layers.
ENABLE_VALIDATION_LAYERS :: #config(ENABLE_VALIDATION_LAYERS, ODIN_DEBUG)
MAX_FRAMES_IN_FLIGHT :: 1
MAX_SWAPCHAIN_IMAGES := 3

Window :: struct{
    handle : glfw.WindowHandle,
    primary_monitor : glfw.MonitorHandle,
    mode : ^glfw.VidMode,
    width : c.int,
    height : c.int,
    ctx : runtime.Context,
}

RenderBase :: struct{
    dbg_messenger: vk.DebugUtilsMessengerEXT,
	ctx: runtime.Context,

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
	command_buffers: []vk.CommandBuffer,

	image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,

	vma_allocator: vma.Allocator,

	depth_image : vk.Image,
	depth_allocation : vma.Allocation,
	depth_view: vk.ImageView,

	submit_info: vk.SubmitInfo,
	current_frame: int,
	image_index: u32,
}

// KHR_PORTABILITY_SUBSET_EXTENSION_NAME :: "VK_KHR_portability_subset"
DEVICE_EXTENSIONS := []cstring {
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
	// KHR_PORTABILITY_SUBSET_EXTENSION_NAME,
}
init_vulkan :: proc()
{
	//----------------------------------------------------------------------------\\
    // /Create Instance /ci
    //----------------------------------------------------------------------------\\
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	assert(vk.CreateInstance != nil, "vulkan function pointers not loaded")

	create_info := vk.InstanceCreateInfo {
		sType            = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &vk.ApplicationInfo {
			sType = .APPLICATION_INFO,
			pApplicationName = "BeeKillingsInn",
			applicationVersion = vk.MAKE_VERSION(0, 0, 1),
			pEngineName = "Axiomo",
			engineVersion = vk.MAKE_VERSION(0, 0, 1),
			apiVersion = vk.API_VERSION_1_3,
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

	must(vk.CreateInstance(&create_info, nil, &g_renderbase.instance))

	vk.load_proc_addresses_instance(g_renderbase.instance)

	when ENABLE_VALIDATION_LAYERS {
		must(vk.CreateDebugUtilsMessengerEXT(g_renderbase.instance, &dbg_create_info, nil, &g_renderbase.dbg_messenger))
	}

	//----------------------------------------------------------------------------\\
    // /Create Surface and Devices /cs
    //----------------------------------------------------------------------------\\
	must(glfw.CreateWindowSurface(g_renderbase.instance, g_window.handle, nil, &g_renderbase.surface))

	// Pick a suitable GPU.
	must(pick_physical_device())

	// Setup logical device,
	indices := find_queue_families(g_renderbase.physical_device)
	set_compute_queue_family_index(g_renderbase.physical_device, &indices)
	g_renderbase.compute_queue_family_index = indices.compute.?
	{
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
			vk.GetPhysicalDeviceFeatures2(g_renderbase.physical_device, &device_features)
			vk.GetPhysicalDeviceFeatures2(g_renderbase.physical_device, &physical_features)
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
		must(vk.CreateDevice(g_renderbase.physical_device, &device_create_info, nil, &g_renderbase.device))

		vk.GetDeviceQueue(g_renderbase.device, indices.graphics.?, 0, &g_renderbase.graphics_queue)
		vk.GetDeviceQueue(g_renderbase.device, indices.present.?, 0, &g_renderbase.present_queue)
		vk.GetDeviceQueue(g_renderbase.device, indices.compute.?, 1, &g_renderbase.compute_queue) // should be g_renderbase.compute_queue_family_index, but it aint workin fo some reason
	}

	init_vma()

	create_swapchain()

	// Load shaders.
	{
		g_renderbase.vert_shader_module = create_shader_module(SHADER_VERT)
		g_renderbase.shader_stages[0] = vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {.VERTEX},
			module = g_renderbase.vert_shader_module,
			pName  = "main",
		}

		g_renderbase.frag_shader_module = create_shader_module(SHADER_FRAG)
		g_renderbase.shader_stages[1] = vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {.FRAGMENT},
			module = g_renderbase.frag_shader_module,
			pName  = "main",
		}
	}

	// Set up render pass.
	{
		color_attachment := vk.AttachmentDescription {
			format         = g_renderbase.swapchain_format.format,
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

		must(vk.CreateRenderPass(g_renderbase.device, &render_pass, nil, &g_renderbase.render_pass))
	}

	create_pipeline_cache()

	// Create command pool.
	{
		pool_info := vk.CommandPoolCreateInfo {
			sType            = .COMMAND_POOL_CREATE_INFO,
			flags            = {.TRANSIENT},
			queueFamilyIndex = indices.graphics.?,
		}
		must(vk.CreateCommandPool(g_renderbase.device, &pool_info, nil, &g_renderbase.command_pool))
	}

	create_depth_resources()
	create_framebuffers()

	// Set up sync primitives.
	{
		sem_info := vk.SemaphoreCreateInfo {
			sType = .SEMAPHORE_CREATE_INFO,
		}
		fence_info := vk.FenceCreateInfo {
			sType = .FENCE_CREATE_INFO,
			flags = {.SIGNALED}, // Start with fences signaled so we can use them immediately.
		}
		for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
			must(vk.CreateSemaphore(g_renderbase.device, &sem_info, nil, &g_renderbase.image_available_semaphores[i]))
			must(vk.CreateSemaphore(g_renderbase.device, &sem_info, nil, &g_renderbase.render_finished_semaphores[i]))
			must(vk.CreateFence(g_renderbase.device, &fence_info, nil, &g_renderbase.in_flight_fences[i]))
		}
	}

	g_renderbase.current_frame = 0
	//update_vulkan()
}

@(require_results)
pick_physical_device :: proc() -> vk.Result {

	score_physical_device :: proc(device: vk.PhysicalDevice) -> (score: int) {
		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(device, &props)

		name := byte_arr_str(&props.deviceName)
		// log.infof("vulkan: evaluating device %q", name)
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
		// log.infof("vulkan: scored %i based on device type %v", score, props.deviceType)

		// Maximum texture size.
		score += int(props.limits.maxImageDimension2D)
		// log.infof(
		// 	"vulkan: added the max 2D image dimensions (texture size) of %v to the score",
		// 	props.limits.maxImageDimension2D,
		// )
		return
	}

	count: u32
	vk.EnumeratePhysicalDevices(g_renderbase.instance, &count, nil) or_return
	if count == 0 {log.panic("vulkan: no GPU found")}

	devices := make([]vk.PhysicalDevice, count, context.temp_allocator)
	vk.EnumeratePhysicalDevices(g_renderbase.instance, &count, raw_data(devices)) or_return

	best_device_score := -1
	for device in devices {
		if score := score_physical_device(device); score > best_device_score {
			g_renderbase.physical_device = device
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
		vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), g_renderbase.surface, &supported)
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
   defer delete(compute_fams)
   defer delete(c)

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
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, g_renderbase.surface, &support.capabilities) or_return

	{
		count: u32
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, g_renderbase.surface, &count, nil) or_return

		support.formats = make([]vk.SurfaceFormatKHR, count, allocator)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, g_renderbase.surface, &count, raw_data(support.formats)) or_return
	}

	{
		count: u32
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, g_renderbase.surface, &count, nil) or_return

		support.presentModes = make([]vk.PresentModeKHR, count, allocator)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, g_renderbase.surface, &count, raw_data(support.presentModes)) or_return
	}

	return
}

choose_swapchain_surface_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
    for format in formats {
		if format.format == .B8G8R8A8_UNORM && format.colorSpace == .SRGB_NONLINEAR {
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

	width, height := glfw.GetFramebufferSize(g_window.handle)
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
		vk.GetPhysicalDeviceFormatProperties(g_renderbase.physical_device, format, &props)

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
	context = g_renderbase.ctx
	log.errorf("glfw: %i: %s", code, description)
}

vk_messenger_callback :: proc "system" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
	messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	context = g_renderbase.ctx

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
	indices := find_queue_families(g_renderbase.physical_device)
	// Setup swapchain.
	{
		support, result := query_swapchain_support(g_renderbase.physical_device, context.temp_allocator)
		if result != .SUCCESS {
			log.panicf("vulkan: query swapchain failed: %v", result)
		}

		surface_format := choose_swapchain_surface_format(support.formats)
		present_mode := choose_swapchain_present_mode(support.presentModes)
		extent := choose_swapchain_extent(support.capabilities)

		g_renderbase.swapchain_format = surface_format
		g_renderbase.swapchain_extent = extent

		image_count := support.capabilities.minImageCount + 1
		if support.capabilities.maxImageCount > 0 && image_count > support.capabilities.maxImageCount {
			image_count = support.capabilities.maxImageCount
		}

		create_info := vk.SwapchainCreateInfoKHR {
			sType            = .SWAPCHAIN_CREATE_INFO_KHR,
			surface          = g_renderbase.surface,
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

		must(vk.CreateSwapchainKHR(g_renderbase.device, &create_info, nil, &g_renderbase.swapchain))
	}

	// Setup swapchain images.
	{
		count: u32
		must(vk.GetSwapchainImagesKHR(g_renderbase.device, g_renderbase.swapchain, &count, nil))

		g_renderbase.swapchain_images = make([]vk.Image, count)
		g_renderbase.swapchain_views = make([]vk.ImageView, count)
		must(vk.GetSwapchainImagesKHR(g_renderbase.device, g_renderbase.swapchain, &count, raw_data(g_renderbase.swapchain_images)))

		for image, i in g_renderbase.swapchain_images {
			create_info := vk.ImageViewCreateInfo {
				sType = .IMAGE_VIEW_CREATE_INFO,
				image = image,
				viewType = .D2,
				format = g_renderbase.swapchain_format.format,
				subresourceRange = {aspectMask = {.COLOR}, levelCount = 1, layerCount = 1},
			}
			must(vk.CreateImageView(g_renderbase.device, &create_info, nil, &g_renderbase.swapchain_views[i]))
		}
	}
}

destroy_swapchain :: proc() {
	for view in g_renderbase.swapchain_views {
		vk.DestroyImageView(g_renderbase.device, view, nil)
	}
	delete(g_renderbase.swapchain_views)
	delete(g_renderbase.swapchain_images)
	vk.DestroySwapchainKHR(g_renderbase.device, g_renderbase.swapchain, nil)
}

create_framebuffers :: proc() {
    g_renderbase.swapchain_frame_buffers = make([]vk.Framebuffer, len(g_renderbase.swapchain_views))
    for view, i in g_renderbase.swapchain_views {
        attachments := []vk.ImageView{view, g_renderbase.depth_view} // Color and depth attachments
        frame_buffer := vk.FramebufferCreateInfo {
            sType           = .FRAMEBUFFER_CREATE_INFO,
            renderPass      = g_renderbase.render_pass,
            attachmentCount = 2,
            pAttachments    = raw_data(attachments),
            width           = g_renderbase.swapchain_extent.width,
            height          = g_renderbase.swapchain_extent.height,
            layers          = 1,
        }
        must(vk.CreateFramebuffer(g_renderbase.device, &frame_buffer, nil, &g_renderbase.swapchain_frame_buffers[i]))
    }
}

create_pipeline_cache :: proc()
{
	create_info : vk.PipelineCacheCreateInfo = {
		sType = .PIPELINE_CACHE_CREATE_INFO,
	}
	must(vk.CreatePipelineCache(g_renderbase.device, &create_info, nil, &g_renderbase.pipeline_cache))
}

init_vma :: proc()
{
	vma_funcs := vma.create_vulkan_functions()

	create_info := vma.AllocatorCreateInfo {
		flags = {.EXT_MEMORY_BUDGET},
		vulkanApiVersion = vk.API_VERSION_1_3,
		instance = g_renderbase.instance,
		device = g_renderbase.device,
		physicalDevice = g_renderbase.physical_device,
		pVulkanFunctions = &vma_funcs
	}
	must(vma.CreateAllocator(&create_info, &g_renderbase.vma_allocator))
}

create_depth_resources :: proc() {
    depth_format := find_depth_format()
    create_image(g_renderbase.swapchain_extent.width, g_renderbase.swapchain_extent.height, depth_format, .OPTIMAL, .DEPTH_STENCIL_ATTACHMENT, &g_renderbase.depth_image, &g_renderbase.depth_allocation)
    g_renderbase.depth_view = create_image_view(g_renderbase.depth_image, depth_format, {.DEPTH})
    transition_image_layout(g_renderbase.depth_image, depth_format, .UNDEFINED, .DEPTH_STENCIL_ATTACHMENT_OPTIMAL)
}
destroy_depth_resources :: proc() {
    vk.DestroyImageView(g_renderbase.device, g_renderbase.depth_view, nil)
    vma.DestroyImage(g_renderbase.vma_allocator, g_renderbase.depth_image, g_renderbase.depth_allocation)
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
	must(vma.CreateImage(g_renderbase.vma_allocator, &image_info, &alloc_info, image, allocation, nil))
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
    must(vk.CreateImageView(g_renderbase.device, &view_info, nil, &view))
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
	for frame_buffer in g_renderbase.swapchain_frame_buffers {vk.DestroyFramebuffer(g_renderbase.device, frame_buffer, nil)}
	delete(g_renderbase.swapchain_frame_buffers)
}

recreate_swapchain :: proc() {
    // Don't do anything when minimized.
    for w, h := glfw.GetFramebufferSize(g_window.handle); w == 0 || h == 0; w, h = glfw.GetFramebufferSize(g_window.handle) {
        glfw.WaitEvents()
        if glfw.WindowShouldClose(g_window.handle) { break }
    }

    vk.DeviceWaitIdle(g_renderbase.device)

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
	must(vk.CreateShaderModule(g_renderbase.device, &create_info, nil, &module))
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
        renderPass = g_renderbase.render_pass,
        framebuffer = g_renderbase.swapchain_frame_buffers[image_index],
        renderArea = {extent = g_renderbase.swapchain_extent},
        clearValueCount = 2,
        pClearValues = &clear_values[0],
    }
    vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)

    vk.CmdBindPipeline(command_buffer, .GRAPHICS, g_renderbase.pipeline)

    viewport := vk.Viewport {
        width    = f32(g_renderbase.swapchain_extent.width),
        height   = f32(g_renderbase.swapchain_extent.height),
        maxDepth = 1.0,
    }
    vk.CmdSetViewport(command_buffer, 0, 1, &viewport)

    scissor := vk.Rect2D {
        extent = g_renderbase.swapchain_extent,
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
        commandPool        = g_renderbase.command_pool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }
    command_buffer: vk.CommandBuffer
    must(vk.AllocateCommandBuffers(g_renderbase.device, &alloc_info, &command_buffer))

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
    must(vk.QueueSubmit(g_renderbase.graphics_queue, 1, &submit_info, 0))
    must(vk.QueueWaitIdle(g_renderbase.graphics_queue))

    vk.FreeCommandBuffers(g_renderbase.device, g_renderbase.command_pool, 1, command_buffer)
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
    } else if old_layout == .UNDEFINED && new_layout == .GENERAL {
        barrier.srcAccessMask = {}  // No prior access needed from undefined
        barrier.dstAccessMask = {.SHADER_WRITE}  // For compute storage writes; add .SHADER_READ if you sample in shader too
        src_stage = {.TOP_OF_PIPE}
        dst_stage = {.COMPUTE_SHADER}  // Matches your raytracing dispatch
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

texture_create :: proc
{
    texture_load_create,
    texture_create_w_pixels,
}

texture_load_create :: proc(texture: ^Texture) -> bool {
    tex_width, tex_height, tex_channels: i32
    pixels := stbi.load(strings.clone_to_cstring(texture.path, context.temp_allocator), &tex_width, &tex_height, &tex_channels, 4)
    defer     stbi.image_free(pixels)
    if pixels == nil {
        log.error("Failed to load texture image!")
        return false
    }
    texture.width = u32(tex_width)
    texture.height = u32(tex_height)
    return texture_create_device(texture, pixels, g_renderbase.device, &g_renderbase.vma_allocator)
}

texture_create_w_pixels :: proc(texture: ^Texture, pixels : [^]byte) -> bool {
    return texture_create_device(texture, pixels, g_renderbase.device, &g_renderbase.vma_allocator)
}

texture_create_device :: proc(texture: ^Texture, pixels : [^]byte, device: vk.Device, allocator: ^vma.Allocator) -> bool {
    image_size := vk.DeviceSize(texture.width * texture.height * 4)
        // Create staging buffer
    staging_buffer: vk.Buffer
    staging_allocation: vma.Allocation
    staging_buffer_info := vk.BufferCreateInfo {
        sType = .BUFFER_CREATE_INFO,
        size = image_size,
        usage = {.TRANSFER_SRC},
        sharingMode = .EXCLUSIVE,
    }
    staging_alloc_info := vma.AllocationCreateInfo {
        flags = {.HOST_ACCESS_SEQUENTIAL_WRITE},
        usage = .AUTO,
    }
    result := vma.CreateBuffer(allocator^, &staging_buffer_info, &staging_alloc_info, &staging_buffer, &staging_allocation, nil)
    if result != .SUCCESS {
        log.error("Failed to create staging buffer!")
        return false
    }
    defer vma.DestroyBuffer(allocator^, staging_buffer, staging_allocation)

    // Map and copy data
    data: rawptr
    vma.MapMemory(allocator^, staging_allocation, &data)
    mem.copy(data, pixels, int(image_size))
    vma.UnmapMemory(allocator^, staging_allocation)

    // Create image
    image_info := vk.ImageCreateInfo {
        sType = .IMAGE_CREATE_INFO,
        imageType = .D2,
        extent = {width = u32(texture.width), height = u32(texture.height), depth = 1},
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
        usage = .AUTO,
    }
    result = vma.CreateImage(allocator^, &image_info, &image_alloc_info, &texture.image, &texture.image_allocation, nil)
    if result != .SUCCESS {
        log.error("Failed to create texture image!")
        return false
    }

    // Transition to TRANSFER_DST_OPTIMAL
    transition_image_layout(texture.image, .R8G8B8A8_UNORM, .UNDEFINED, .TRANSFER_DST_OPTIMAL)

    // Copy buffer to image
    copy_buffer_to_image(staging_buffer, texture.image, u32(texture.width), u32(texture.height))

    // Transition to SHADER_READ_ONLY_OPTIMAL
    transition_image_layout(texture.image, .R8G8B8A8_UNORM, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)

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
        anisotropyEnable = false,
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


//----------------------------------------------------------------------------\\
// /TFONT
//----------------------------------------------------------------------------\\
// Font :: struct {
//     atlas_texture: Texture,
//     atlas_width, atlas_height: i32,
//     scale: f32,
//     char_data: map[rune]struct {
//         uv_min, uv_ext: vec2f,
//         advance: f32,
//         offset: vec2f,
//     },
//     info : sttt.fontinfo,

// }
Font :: struct {
    using gui: Cmp_Gui,
    atlas_texture: Texture,
    atlas_width, atlas_height: i32,
    scale: f32,
    info: sttt.fontinfo,         // Add this
    baked_chars: [95]sttt.bakedchar,  // Add this (matches your ASCII range)
    char_data: map[rune]struct {
        uv_min, uv_ext: vec2f,
        advance: f32,
        offset: vec2f,
    },
}

// Renders a string to an RGBA bitmap (returns buffer, width, height)
render_string_to_bitmap :: proc(text: string, scale: f32) -> ([]u8, i32, i32) {
    // First pass: Compute total width/height
    total_width: f32 = 0
    max_height: f32 = 0
    baseline: f32 = 0
    for char in text {
        advance_width, left_side_bearing: i32
        x0, y0, x1, y1: i32
        sttt.GetCodepointHMetrics(&g_raytracer.font.info, char, &advance_width, &left_side_bearing)
        sttt.GetCodepointBitmapBox(&g_raytracer.font.info, char, scale, scale, &x0, &y0, &x1, &y1)

        glyph_width := f32(x1 - x0)
        glyph_height := f32(y1 - y0)
        total_width += f32(advance_width) * scale
        max_height = max(max_height, glyph_height)
        baseline = max(baseline, -f32(y0))
    }

    ascent, descent, line_gap: i32
    sttt.GetFontVMetrics(&g_raytracer.font.info, &ascent, &descent, &line_gap)
    baseline = max(baseline, f32(ascent) * scale)

    bitmap_width := i32(math.ceil(total_width)) + 10  // Padding
    bitmap_height := i32(math.ceil(max_height + baseline)) + 10

    // Allocate RGBA bitmap (4 bytes per pixel)
    bitmap := make([]u8, bitmap_width * bitmap_height * 4, context.temp_allocator)

    // Second pass: Render each glyph
    x_pos: f32 = 5  // Left padding
    for char in text {
        if char == ' ' {
            advance_width: i32
            sttt.GetCodepointHMetrics(&g_raytracer.font.info, char, &advance_width, nil)
            x_pos += f32(advance_width) * scale
            continue
        }

        // Render glyph to temp alpha buffer
        glyph_w, glyph_h, glyph_xoff, glyph_yoff: i32
        glyph_bitmap := sttt.GetCodepointBitmap(&g_raytracer.font.info, scale, scale, char, &glyph_w, &glyph_h, &glyph_xoff, &glyph_yoff)
        defer sttt.FreeBitmap(glyph_bitmap, nil)  // STB cleanup

        // Blit alpha to RGBA (white text; adjust color if needed)
        for gy in 0..<glyph_h {
            for gx in 0..<glyph_w {
                alpha := glyph_bitmap[gy * glyph_w + gx]
                if alpha > 0 {
                    bx := i32(x_pos) + gx + glyph_xoff
                    by := i32(baseline) + gy + glyph_yoff
                    if bx >= 0 && bx < bitmap_width && by >= 0 && by < bitmap_height {
                        idx := (by * bitmap_width + bx) * 4
                        bitmap[idx + 0] = 255  // R
                        bitmap[idx + 1] = 255  // G
                        bitmap[idx + 2] = 255  // B
                        bitmap[idx + 3] = alpha  // A
                    }
                }
            }
        }

        // Advance
        advance_width: i32
        sttt.GetCodepointHMetrics(&g_raytracer.font.info, char, &advance_width, nil)
        x_pos += f32(advance_width) * scale
    }

    return bitmap, bitmap_width, bitmap_height
}

create_texture_from_bitmap :: proc(bitmap: []u8, width, height: i32) -> Texture {
    tex: Texture
    tex.width = u32(width)
    tex.height = u32(height)
    image_size := vk.DeviceSize(width * height * 4)

    // Staging buffer (copy from bake_font_atlas)
    staging_buffer: vk.Buffer
    staging_allocation: vma.Allocation
    staging_buffer_info := vk.BufferCreateInfo {
        sType = .BUFFER_CREATE_INFO,
        size = image_size,
        usage = {.TRANSFER_SRC},
        sharingMode = .EXCLUSIVE,
    }
    staging_alloc_info := vma.AllocationCreateInfo {
        flags = {.HOST_ACCESS_SEQUENTIAL_WRITE},
        usage = .AUTO,
    }
    must(vma.CreateBuffer(g_renderbase.vma_allocator, &staging_buffer_info, &staging_alloc_info, &staging_buffer, &staging_allocation, nil))

    data: rawptr
    vma.MapMemory(g_renderbase.vma_allocator, staging_allocation, &data)
    mem.copy(data, raw_data(bitmap), int(image_size))
    vma.UnmapMemory(g_renderbase.vma_allocator, staging_allocation)

    // Image
    image_info := vk.ImageCreateInfo {
        sType = .IMAGE_CREATE_INFO,
        imageType = .D2,
        extent = {u32(width), u32(height), 1},
        mipLevels = 1,
        arrayLayers = 1,
        format = .R8G8B8A8_UNORM,
        tiling = .OPTIMAL,
        initialLayout = .UNDEFINED,
        usage = {.TRANSFER_DST, .SAMPLED},
        samples = {._1},
        sharingMode = .EXCLUSIVE,
    }
    alloc_info := vma.AllocationCreateInfo { usage = .AUTO }
    must(vma.CreateImage(g_renderbase.vma_allocator, &image_info, &alloc_info, &tex.image, &tex.image_allocation, nil))

    transition_image_layout(tex.image, .R8G8B8A8_UNORM, .UNDEFINED, .TRANSFER_DST_OPTIMAL)
    copy_buffer_to_image(staging_buffer, tex.image, u32(width), u32(height))
    transition_image_layout(tex.image, .R8G8B8A8_UNORM, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)

    tex.view = create_image_view(tex.image, .R8G8B8A8_UNORM, {.COLOR})

    sampler_info := vk.SamplerCreateInfo {
        sType = .SAMPLER_CREATE_INFO,
        magFilter = .LINEAR,
        minFilter = .LINEAR,
        addressModeU = .CLAMP_TO_EDGE,
        addressModeV = .CLAMP_TO_EDGE,
        addressModeW = .CLAMP_TO_EDGE,
    }
    must(vk.CreateSampler(g_renderbase.device, &sampler_info, nil, &tex.sampler))

    tex.image_layout = .SHADER_READ_ONLY_OPTIMAL
    texture_update_descriptor(&tex)

    // Cleanup staging
    vma.DestroyBuffer(g_renderbase.vma_allocator, staging_buffer, staging_allocation)

    return tex
}

bake_font_atlas :: proc(font_path: string, pixel_height: f32) {
    // Load TTF (e.g., "../assets/fonts/arial.ttf")
    ttf_data, ok := os.read_entire_file(font_path)
    if !ok { log.panic("Failed to load font") }
    defer delete(ttf_data)

    // Init font info
    info: sttt.fontinfo
    offset := sttt.GetFontOffsetForIndex(raw_data(ttf_data), 0)
    sttt.InitFont(&info, raw_data(ttf_data), offset)

    // Bake atlas (ASCII 32-126 for simplicity; extend for Unicode)
    bitmap_width, bitmap_height :: 512, 512  // Adjust if too small/large
    bitmap := make([]byte, bitmap_width * bitmap_height)
    defer delete(bitmap)

    char_range := [2]rune{' ', '~'}  // ASCII printable
    baked_chars: [95]sttt.bakedchar  // '~' - ' ' + 1 = 95
    // sttt.BakeFontBitmap(&info, 0, pixel_height, bitmap[:], bitmap_width, bitmap_height, char_range[0], &baked_chars[0], i32(len(baked_chars)))
    sttt.BakeFontBitmap(
        raw_data(ttf_data),
        offset,
        pixel_height,
        raw_data(bitmap),
        bitmap_width,
        bitmap_height,
        i32(char_range[0]),
        i32(len(baked_chars)),
        raw_data(&baked_chars)
    )

    g_raytracer.font.info = info
    g_raytracer.font.baked_chars = baked_chars

    // Create Vulkan texture from bitmap (RGBA, assuming 1-channel bitmap -> expand to RGBA)
    rgba_data := make([]byte, bitmap_width * bitmap_height * 4, context.temp_allocator)
    defer delete(rgba_data)
    for i in 0..<bitmap_width*bitmap_height {
        rgba_data[i*4 + 0] = 255
        rgba_data[i*4 + 1] = 255
        rgba_data[i*4 + 2] = 255
        rgba_data[i*4 + 3] = bitmap[i]  // Alpha from bitmap
    }

    // Create texture (adapt your texture_create_device)
    g_raytracer.font.atlas_texture = Texture{path = font_path}  // Reuse path for logging
    g_raytracer.font.atlas_texture.width = u32(bitmap_width)
    g_raytracer.font.atlas_texture.height = u32(bitmap_height)
    // Manual create: staging buffer, copy to image, etc. (copy from texture_create_device)
    // ... (use create_image, copy_buffer_to_image, etc., with .R8G8B8A8_UNORM)
    // Set sampler to .LINEAR for smooth scaling
    // Call texture_update_descriptor(&g_raytracer.font.atlas_texture)
    //
    if(texture_create(&g_raytracer.font.atlas_texture, raw_data(rgba_data))){
        append(&g_raytracer.bindless_textures, g_raytracer.font.atlas_texture)
        g_texture_indexes["Deutsch.ttf"] = i32(len(g_texture_indexes))
    }
    texture_update_descriptor(&g_raytracer.font.atlas_texture)

    // Store per-char UVs and metrics
    g_raytracer.font.scale = sttt.ScaleForPixelHeight(&info, pixel_height)
    g_raytracer.font.atlas_width, g_raytracer.font.atlas_height = bitmap_width, bitmap_height
    for i in 0..<len(baked_chars) {
        c := baked_chars[i]
        char := rune(char_range[0] + rune(i))
        g_raytracer.font.char_data[char] = {
            uv_min = {f32(c.x0)/f32(bitmap_width), f32(c.y0)/f32(bitmap_height)},
            uv_ext = {f32(c.x1-c.x0)/f32(bitmap_width), f32(c.y1-c.y0)/f32(bitmap_height)},
            advance = c.xadvance,
            offset = {c.xoff, c.yoff},
        }
    }
}

destroy_vulkan :: proc()
{
    // Final cleanup after device is destroyed - only instance-level resources
    vk.DestroyDebugUtilsMessengerEXT(g_renderbase.instance, g_renderbase.dbg_messenger, nil)
    vk.DestroyInstance(g_renderbase.instance, nil)
    glfw.DestroyWindow(g_window.handle)
    glfw.Terminate()
}

//----------------------------------------------------------------------------\\
// /RAYTRACER /rt
//----------------------------------------------------------------------------\\
MAX_MATERIALS :: 256
MAX_MESHES :: 2048
MAX_VERTS :: 32768
MAX_INDS :: 16384
MAX_OBJS :: 4096
MAX_LIGHTS :: 32
MAX_GUIS :: 96
MAX_NODES :: 2048
MAX_BINDLESS_TEXTURES :u32= 0
MAX_TEXTURES :: 1

// Update flags for tracking what needs to be updated
UpdateFlag :: enum {
    OBJECT,
    MATERIAL,
    LIGHT,
    GUI,
    BVH,
}
UpdateFlags :: bit_set[UpdateFlag]

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
    primitives: [dynamic]gpu.Primitive, // isn't this going to be per-frame?
    materials: [dynamic]gpu.Material,
    lights: [dynamic]gpu.Light,
    guis: [dynamic]gpu.Gui,
    bvh: [dynamic]gpu.BvhNode,

    mesh_comps: [dynamic]Cmp_Mesh,
    light_comps: [dynamic]Cmp_Light,

    mesh_assigner: map[i32][2]int,
    //joint_assigner: map[i32][2]int,
    //shape_assigner: map[i32][2]int,

    compute_texture: Texture,
    gui_textures: [MAX_TEXTURES]Texture,
    bindless_textures: [dynamic]Texture,

    compute_write_descriptor_sets: []vk.WriteDescriptorSet,

    ordered_prims_map: [dynamic]int,

    prepared: bool,
    update_flags: UpdateFlags,
    font: Font,
    texture_paths : [1]string
}

//----------------------------------------------------------------------------\\
// /Initialization Procs /ip
//----------------------------------------------------------------------------\\
initialize_raytracer :: proc()
{
    prepare_storage_buffers()
    create_uniform_buffers()
    prepare_texture_target(&g_raytracer.compute_texture, u32(g_window.width), u32(g_window.height), .R8G8B8A8_UNORM)
    create_descriptor_set_layout() // multiple
    create_graphics_pipeline() // multiple
    create_descriptor_pool()
    create_descriptor_sets()
    prepare_compute()
    create_command_buffers(1.0, 0, 0) // multiple
    g_raytracer.prepared = true
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
    reserve(&g_raytracer.materials, MAX_MATERIALS)
    reserve(&g_raytracer.lights, MAX_LIGHTS)

    gpu.vbuffer_init_storage_buffer_custom_size(
        &g_raytracer.compute.storage_buffers.primitives,
        &g_renderbase.vma_allocator,
        g_raytracer.primitives[:],
        MAX_OBJS)

    gpu.vbuffer_init_storage_buffer_custom_size(
        &g_raytracer.compute.storage_buffers.lights,
        &g_renderbase.vma_allocator,
        g_raytracer.lights[:],
        MAX_LIGHTS)

    gpu.vbuffer_init_storage_buffer_custom_size(
        &g_raytracer.compute.storage_buffers.materials,
        &g_renderbase.vma_allocator,
        g_raytracer.materials[:],
        MAX_MATERIALS)

   gui_cmp := Cmp_Gui{{0, 0}, {1, 1}, {0, 0}, {1, 1}, 0, "title.png", 0, 0, false}
   gpu_gui := gpu.Gui{min = gui_cmp.min, extents = gui_cmp.extents,
       align_min = gui_cmp.align_min, align_ext = gui_cmp.align_ext,
       layer = gui_cmp.layer, id = g_texture_indexes[gui_cmp.id], alpha = gui_cmp.alpha
   }
   append(&g_raytracer.guis, gpu_gui)
   gui_cmp.ref = i32(len(g_raytracer.guis))
   gpu.vbuffer_init_storage_buffer_custom_size(
        &g_raytracer.compute.storage_buffers.guis,
        &g_renderbase.vma_allocator,
        g_raytracer.guis[:],
        MAX_GUIS)
   gpu.vbuffer_init_storage_buffer_custom_size(
       &g_raytracer.compute.storage_buffers.bvh,
       &g_renderbase.vma_allocator,
       g_raytracer.bvh[:],
       MAX_NODES)
}

create_uniform_buffers :: proc() {
    gpu.vbuffer_init_custom(&g_raytracer.compute.uniform_buffer, &g_renderbase.vma_allocator, 1, {.UNIFORM_BUFFER}, .CPU_TO_GPU)
    gpu.vbuffer_apply_changes_no_data(&g_raytracer.compute.uniform_buffer, &g_renderbase.vma_allocator)
}

prepare_texture_target :: proc(tex: ^Texture, width, height: u32, format: vk.Format) {
    // Get format properties to check if the format supports storage image operations
    format_properties: vk.FormatProperties
    vk.GetPhysicalDeviceFormatProperties(g_renderbase.physical_device, format, &format_properties)
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
    must(vma.CreateImage(g_renderbase.vma_allocator, &image_info, &alloc_info, &tex.image, &tex.image_allocation, nil))

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
    must(vk.CreateImageView(g_renderbase.device, &view_info, nil, &tex.view))

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
    must(vk.CreateSampler(g_renderbase.device, &sampler_info, nil, &tex.sampler))

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
    must(vk.CreateDescriptorSetLayout(g_renderbase.device, &layout_info, nil, &g_raytracer.graphics.descriptor_set_layout))

    pipeline_layout_info := vk.PipelineLayoutCreateInfo{
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = 1,
        pSetLayouts = &g_raytracer.graphics.descriptor_set_layout,
    }
    must(vk.CreatePipelineLayout(g_renderbase.device, &pipeline_layout_info, nil, &g_raytracer.graphics.pipeline_layout))
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
    must(vk.CreateShaderModule(g_renderbase.device, &vert_module_info, nil, &vert_shader_module))

    frag_module_info := vk.ShaderModuleCreateInfo{
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = int(len(frag_shader_code)),
        pCode = cast(^u32)raw_data(frag_shader_code),
    }
    frag_shader_module: vk.ShaderModule
    must(vk.CreateShaderModule(g_renderbase.device, &frag_module_info, nil, &frag_shader_module))

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
        layout = g_raytracer.graphics.pipeline_layout,
        renderPass = g_renderbase.render_pass,
        subpass = 0,
    }

    must(vk.CreateGraphicsPipelines(g_renderbase.device, g_renderbase.pipeline_cache, 1, &pipeline_info, nil, &g_raytracer.graphics.pipeline))

    // Destroy shader modules
    vk.DestroyShaderModule(g_renderbase.device, frag_shader_module, nil)
    vk.DestroyShaderModule(g_renderbase.device, vert_shader_module, nil)
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
    must(vk.CreateDescriptorPool(g_renderbase.device, &pool_info, nil, &g_raytracer.descriptor_pool))
}

create_descriptor_sets :: proc() {
    alloc_info := vk.DescriptorSetAllocateInfo{
        sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool = g_raytracer.descriptor_pool,
        descriptorSetCount = 1,
        pSetLayouts = &g_raytracer.graphics.descriptor_set_layout,
    }
    must(vk.AllocateDescriptorSets(g_renderbase.device, &alloc_info, &g_raytracer.graphics.descriptor_set))
    write_set := vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = g_raytracer.graphics.descriptor_set,
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &g_raytracer.compute_texture.descriptor,
    }
    vk.UpdateDescriptorSets(g_renderbase.device, 1, &write_set, 0, nil)
}

prepare_compute :: proc() {
    // Get compute queue
    vk.GetDeviceQueue(g_renderbase.device, g_renderbase.compute_queue_family_index, 0, &g_raytracer.compute.queue)

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
    must(vk.CreateDescriptorSetLayout(g_renderbase.device, &layout_info, nil, &g_raytracer.compute.descriptor_set_layout))

    // Create pipeline layout
    pipeline_layout_info := vk.PipelineLayoutCreateInfo{
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = 1,
        pSetLayouts = &g_raytracer.compute.descriptor_set_layout,
    }
    must(vk.CreatePipelineLayout(g_renderbase.device, &pipeline_layout_info, nil, &g_raytracer.compute.pipeline_layout))

    // Allocate descriptor set
    alloc_info := vk.DescriptorSetAllocateInfo{
        sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool = g_raytracer.descriptor_pool,
        descriptorSetCount = 1,
        pSetLayouts = &g_raytracer.compute.descriptor_set_layout,
    }
    must(vk.AllocateDescriptorSets(g_renderbase.device, &alloc_info, &g_raytracer.compute.descriptor_set))

    // Prepare image infos for gui_textures and bindless_textures
    texture_image_infos: [MAX_TEXTURES]vk.DescriptorImageInfo
    for i in 0..<MAX_TEXTURES {
        texture_image_infos[i] = g_raytracer.gui_textures[i].descriptor
    }
    bindless_image_infos := make([]vk.DescriptorImageInfo, len(g_raytracer.bindless_textures))
    defer delete(bindless_image_infos)
    for t, i in g_raytracer.bindless_textures {
        bindless_image_infos[i] = t.descriptor
    }

// Dynamically build write_sets, skipping buffer writes if handle is null
    write_sets: [dynamic]vk.WriteDescriptorSet
    defer delete(write_sets)

    // Binding 0: STORAGE_IMAGE (always write, assuming g_raytracer.compute_texture.descriptor is valid; it's pImageInfo anyway)
    append(&write_sets, vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = g_raytracer.compute.descriptor_set,
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorCount = 1,
        descriptorType = .STORAGE_IMAGE,
        pImageInfo = &g_raytracer.compute_texture.descriptor,
    })

    // Binding 1: UNIFORM_BUFFER (skip if null)
    if g_raytracer.compute.uniform_buffer.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 1,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .UNIFORM_BUFFER,
            pBufferInfo = &g_raytracer.compute.uniform_buffer.buffer_info,
        })
    }

    // Binding 2: STORAGE_BUFFER verts (skip if null)
    if g_raytracer.compute.storage_buffers.verts.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 2,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.verts.buffer_info,
        })
    }

    // Binding 3: STORAGE_BUFFER faces (skip if null)
    if g_raytracer.compute.storage_buffers.faces.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 3,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.faces.buffer_info,
        })
    }

    // Binding 4: STORAGE_BUFFER blas (skip if null)
    if g_raytracer.compute.storage_buffers.blas.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 4,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.blas.buffer_info,
        })
    }

    // Binding 5: STORAGE_BUFFER shapes (skip if null)
    if g_raytracer.compute.storage_buffers.shapes.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 5,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.shapes.buffer_info,
        })
    }

    // Binding 6: STORAGE_BUFFER primitives (skip if null)
    if g_raytracer.compute.storage_buffers.primitives.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 6,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.primitives.buffer_info,
        })
    }

    // Binding 7: STORAGE_BUFFER materials (skip if null)
    if g_raytracer.compute.storage_buffers.materials.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 7,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.materials.buffer_info,
        })
    }

    // Binding 8: STORAGE_BUFFER lights (skip if null)
    if g_raytracer.compute.storage_buffers.lights.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 8,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.lights.buffer_info,
        })
    }

    // Binding 9: STORAGE_BUFFER guis (skip if null)
    if g_raytracer.compute.storage_buffers.guis.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 9,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.guis.buffer_info,
        })
    }

    // Binding 10: STORAGE_BUFFER bvh (skip if null)
    if g_raytracer.compute.storage_buffers.bvh.buffer_info.buffer != vk.Buffer(0) {
        append(&write_sets, vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 10,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.bvh.buffer_info,
        })
    }

    // Binding 11: COMBINED_IMAGE_SAMPLER array (always write, but could add checks if some are invalid)
    append(&write_sets, vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = g_raytracer.compute.descriptor_set,
        dstBinding = 11,
        dstArrayElement = 0,
        descriptorCount = MAX_TEXTURES,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = &texture_image_infos[0],
    })

    // Binding 12: COMBINED_IMAGE_SAMPLER bindless array (always write, with dynamic count)
    append(&write_sets, vk.WriteDescriptorSet{
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = g_raytracer.compute.descriptor_set,
        dstBinding = 12,
        dstArrayElement = 0,
        descriptorCount = u32(len(g_raytracer.bindless_textures)),
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        pImageInfo = raw_data(bindless_image_infos),
    })

    // Update descriptor sets (now with potentially fewer than 13 writes)
    vk.UpdateDescriptorSets(g_renderbase.device, u32(len(write_sets)), raw_data(write_sets), 0, nil)

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
    must(vk.CreateShaderModule(g_renderbase.device, &module_info, nil, &shader_module))
    pipeline_info := vk.ComputePipelineCreateInfo{
        sType = .COMPUTE_PIPELINE_CREATE_INFO,
        stage = {
            sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage = { .COMPUTE },
            module = shader_module,
            pName = "main",
        },
        layout = g_raytracer.compute.pipeline_layout,
    }
    must(vk.CreateComputePipelines(g_renderbase.device, g_renderbase.pipeline_cache, 1, &pipeline_info, nil, &g_raytracer.compute.pipeline))
    defer vk.DestroyShaderModule(g_renderbase.device, shader_module, nil)

    // Create command pool
    cmd_pool_info := vk.CommandPoolCreateInfo{
        sType = .COMMAND_POOL_CREATE_INFO,
        queueFamilyIndex = g_renderbase.compute_queue_family_index,
        flags = { .RESET_COMMAND_BUFFER },
    }
    must(vk.CreateCommandPool(g_renderbase.device, &cmd_pool_info, nil, &g_raytracer.compute.command_pool))

    // Allocate command buffer
    cmd_buf_info := vk.CommandBufferAllocateInfo{
        sType = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool = g_raytracer.compute.command_pool,
        level = .PRIMARY,
        commandBufferCount = 1,
    }
    must(vk.AllocateCommandBuffers(g_renderbase.device, &cmd_buf_info, &g_raytracer.compute.command_buffer))

    // Create fence
    fence_info := vk.FenceCreateInfo{
        sType = .FENCE_CREATE_INFO,
        flags = { .SIGNALED },
    }
    must(vk.CreateFence(g_renderbase.device, &fence_info, nil, &g_raytracer.compute.fence))

    create_compute_command_buffer()

}

create_compute_command_buffer :: proc() {
    cmd_buf_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        // No flags needed; equivalent to vks::initializers default (no ONE_TIME_SUBMIT for re-recordable if desired)
    }

    must(vk.BeginCommandBuffer(g_raytracer.compute.command_buffer, &cmd_buf_info))

    vk.CmdBindPipeline(g_raytracer.compute.command_buffer, .COMPUTE, g_raytracer.compute.pipeline)
    vk.CmdBindDescriptorSets(g_raytracer.compute.command_buffer, .COMPUTE, g_raytracer.compute.pipeline_layout, 0, 1, &g_raytracer.compute.descriptor_set, 0, nil)

    // Dispatch: Matches your /16 (assuming workgroup size 16x16 in shader; adjust if different)
    vk.CmdDispatch(g_raytracer.compute.command_buffer, g_raytracer.compute_texture.width / 16, g_raytracer.compute_texture.height / 16, 1)

    must(vk.EndCommandBuffer(g_raytracer.compute.command_buffer))
}

create_command_buffers :: proc(swap_ratio: f32 = 1.0, offset_width: i32 = 0, offset_height: i32 = 0) {
    // Allocate command buffers if not already done
    if len(g_renderbase.command_buffers) == 0
    {
        g_renderbase.command_buffers = make([]vk.CommandBuffer, len(g_renderbase.swapchain_frame_buffers))
        command_buffer_info := vk.CommandBufferAllocateInfo{
            sType = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = g_renderbase.command_pool,
            level = .PRIMARY,
            commandBufferCount = u32(len(g_renderbase.swapchain_images)),
        }
        must(vk.AllocateCommandBuffers(g_renderbase.device, &command_buffer_info, &g_renderbase.command_buffers[0]))
    }

    // Calculate viewport and scissor based on parameters
    width := f32(g_renderbase.swapchain_extent.width) * swap_ratio
    height := f32(g_renderbase.swapchain_extent.height) * swap_ratio
    x := f32(offset_width)
    y := f32(offset_height)

    for i in 0..<len(g_renderbase.command_buffers) {
        cmd_buffer := g_renderbase.command_buffers[i]

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
            image = g_raytracer.compute_texture.image,
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
            renderPass = g_renderbase.render_pass,
            framebuffer = g_renderbase.swapchain_frame_buffers[i],
            renderArea = { offset = {0, 0}, extent = g_renderbase.swapchain_extent },
            clearValueCount = 2,
            pClearValues = &clear_values[0],
        }
        vk.CmdBeginRenderPass(cmd_buffer, &render_pass_info, .INLINE)

        // Bind graphics pipeline
        vk.CmdBindPipeline(cmd_buffer, .GRAPHICS, g_raytracer.graphics.pipeline)

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
            g_raytracer.graphics.pipeline_layout,
            0,
            1,
            &g_raytracer.graphics.descriptor_set,
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
    g_raytracer.texture_paths[0] =  "assets/textures/numbers.png"
   map_models_to_gpu(alloc)
   map_materials_to_gpu(alloc)
   // bake_font_atlas("../../assets/textures/fonts/Deutsch.ttf", 32.0)  // 32px height
}

set_camera :: proc()
{
    g_raytracer.compute.ubo.aspect_ratio = 1280.0 / 720.0
    g_raytracer.compute.ubo.fov = math.tan(f32(13.0 * 0.03490658503))
    g_raytracer.compute.ubo.rotM = mat4f(0)
    g_raytracer.compute.ubo.rand = rand.int31()
}

map_materials_to_gpu :: proc(alloc : mem.Allocator)
{
	g_raytracer.materials = make([dynamic]gpu.Material, len(res.materials), alloc)
	for &m, i in res.materials{
	    gpu_mat : gpu.Material = {
			diffuse = m.diffuse,
			reflective = m.reflective,
			roughness = m.roughness,
			transparency = m.transparency,
			refractive_index = m.refractive_index,
			texture_id = g_texture_indexes[m.texture]
		}
        g_raytracer.materials[i] = gpu_mat
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

    g_raytracer.mesh_assigner = make(map[i32][2]int, alloc)

    for mod in res.models
    {
        for mesh, i in mod.meshes
        {
            prev_vert_size := len(verts)
            prev_ind_size := len(faces)
            prev_blas_size := len(blas)

            reserve(&verts, prev_vert_size + len(mesh.verts))
            for vert in mesh.verts{
                append(&verts, gpu.Vert{pos = vert.pos / mesh.extents, norm = vert.norm, u = vert.uv.x, v = vert.uv.y})
            }
            reserve(&faces, prev_ind_size + len(mesh.faces))
            for face in mesh.faces{
                append(&faces, gpu.Index{v = face + i32(prev_vert_size)})
            }
            reserve(&blas, prev_blas_size + len(mesh.bvhs))
            for bvh in mesh.bvhs{
                append(&blas, gpu.BvhNode{bvh.upper, bvh.offset, bvh.lower, bvh.numChildren})
            }
            g_raytracer.mesh_assigner[mod.unique_id + i32(i)] = {prev_ind_size, prev_ind_size + len(mesh.faces)}
        }
    }

    append(&shapes, gpu.Shape{center = {0.0, 1.0, 0.0}, type = 1})
    append(&blas, gpu.BvhNode{} )

    //Load them into the gpu
    init_staging_buf(&g_raytracer.compute.storage_buffers.verts,verts, len(verts))
    init_staging_buf(&g_raytracer.compute.storage_buffers.faces,faces, len(faces))
    init_staging_buf(&g_raytracer.compute.storage_buffers.blas, blas, len(blas))
    init_staging_buf(&g_raytracer.compute.storage_buffers.shapes, shapes, len(shapes))

    //Dynamically load textures
    // g_texture_indexes = make(map[string]i32, g_mem_area.alloc)
    g_texture_indexes[""] = -1
    index :i32= 0
    files := path2.get_dir_files("assets/textures")
    for f,i in files{
        file_ext := path2.get_file_stem(f.fullpath, alloc)
        if file_ext != ".png" && file_ext != ".jpg" && file_ext != ".jpeg" do continue
        filename := strings.clone(f.name, alloc)
        t := Texture{path = f.fullpath}
        if texture_create(&t){
            append(&g_raytracer.bindless_textures, t)
            g_texture_indexes[filename] = index
            index += 1
        }
    }
    os.file_info_slice_delete(files)
    MAX_BINDLESS_TEXTURES = u32(len(g_raytracer.bindless_textures)) + 1

    // Similarly for gui_textures if needed, but since it's fixed array, perhaps initialize with a default texture or handle differently
    // For now, assume gui_textures are critical, so check in loop
    for &t, i in g_raytracer.gui_textures {
        t = Texture{path = g_raytracer.texture_paths[i]}
        if !texture_create(&t) do log.errorf("Failed to create GUI texture for path: %s", g_raytracer.texture_paths[i])
    }
}

init_staging_buf :: proc(vbuf: ^gpu.VBuffer($T), objects: [dynamic]T, size : int )
{
    gpu.vbuffer_init_storage_buffer_with_staging_device(vbuf, g_renderbase.device, &g_renderbase.vma_allocator, g_renderbase.command_pool, g_renderbase.graphics_queue, objects[:], u32(size))
}

//----------------------------------------------------------------------------\\
// Updates /up
//----------------------------------------------------------------------------\\
update_descriptors :: proc() {
    // Wait for fence - equivalent to vkWaitForFences with UINT64_MAX
    vk.WaitForFences(g_renderbase.device, 1, &g_raytracer.compute.fence, true, fence_timeout_ns)

    // Create write descriptor sets for the specific bindings you need
    // Based on your C++ code, you need bindings 6-10 for primitives, materials, lights, guis, and bvh
    g_raytracer.compute_write_descriptor_sets = {
        // Binding 6: for objects (primitives)
        vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 6,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.primitives.buffer_info,
        },

        // Binding 7: for materials
        vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 7,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.materials.buffer_info,
        },

        // Binding 8: for lights
        vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 8,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.lights.buffer_info,
        },

        // Binding 9: for gui
        vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 9,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.guis.buffer_info,
        },

        // Binding 10: for bvhnodes
        vk.WriteDescriptorSet{
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = g_raytracer.compute.descriptor_set,
            dstBinding = 10,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType = .STORAGE_BUFFER,
            pBufferInfo = &g_raytracer.compute.storage_buffers.bvh.buffer_info,
        },
    }

    // Update descriptor sets
    vk.UpdateDescriptorSets(
        g_renderbase.device,
        u32(len(g_raytracer.compute_write_descriptor_sets)),
        &g_raytracer.compute_write_descriptor_sets[0],
        0,
        nil
    )

    // Create compute command buffer
    create_compute_command_buffer()
}

update_buffers :: proc() {
    vk.WaitForFences(g_renderbase.device, 1, &g_raytracer.compute.fence, true, fence_timeout_ns)

    if g_raytracer.update_flags == {} do return

    if .OBJECT in g_raytracer.update_flags {
        // compute_.storage_buffers.primitives.UpdateBuffers(vkDevice, primitives);
        g_raytracer.update_flags -= {.OBJECT}
    }

    if .MATERIAL in g_raytracer.update_flags {
        g_raytracer.update_flags -= {.MATERIAL}
    }

    if .LIGHT in g_raytracer.update_flags {
        gpu.vbuffer_update(&g_raytracer.compute.storage_buffers.lights, &g_renderbase.vma_allocator, g_raytracer.lights[:])
        g_raytracer.update_flags -= {.LIGHT}
    }

    if .GUI in g_raytracer.update_flags {
        gpu.vbuffer_update(&g_raytracer.compute.storage_buffers.guis, &g_renderbase.vma_allocator, g_raytracer.guis[:])
        g_raytracer.update_flags -= {.GUI}
    }

    if .BVH in g_raytracer.update_flags {
        gpu.vbuffer_update_and_expand(&g_raytracer.compute.storage_buffers.primitives, &g_renderbase.vma_allocator, g_raytracer.primitives[:], u32(len(g_raytracer.primitives)))
        gpu.vbuffer_update_and_expand(&g_raytracer.compute.storage_buffers.bvh, &g_renderbase.vma_allocator, g_raytracer.bvh[:], u32(len(g_raytracer.bvh)))
        g_raytracer.update_flags -= {.BVH}
    }

    g_raytracer.update_flags = {}
    // compute_.storage_buffers.objects.UpdateAndExpandBuffers(vkDevice, objects, objects.size());
    // compute_.storage_buffers.bvh.UpdateAndExpandBuffers(vkDevice, bvh, bvh.size());
    update_descriptors()
}

update_camera :: proc{update_camera_full, update_camera_component}

update_camera_full :: proc(camera: ^Camera) {
    g_raytracer.compute.ubo.aspect_ratio = camera.aspect
    g_raytracer.compute.ubo.fov = math.tan(camera.fov * 0.03490658503)
    g_raytracer.compute.ubo.rotM = transmute(mat4f)camera.matrices.view
    g_raytracer.compute.ubo.rand = rand.int31()
    gpu.vbuffer_apply_changes(&g_raytracer.compute.uniform_buffer, &g_renderbase.vma_allocator, &g_raytracer.compute.ubo)
}

update_camera_component :: proc(camera: ^Cmp_Camera) {
    g_raytracer.compute.ubo.aspect_ratio = camera.aspect_ratio
    g_raytracer.compute.ubo.fov = math.tan(camera.fov * 0.03490658503)
    g_raytracer.compute.ubo.rotM = transmute(mat4f)camera.rot_matrix
    g_raytracer.compute.ubo.rand = rand.int31()
    gpu.vbuffer_apply_changes(&g_raytracer.compute.uniform_buffer, &g_renderbase.vma_allocator, &g_raytracer.compute.ubo)
}

update_bvh :: proc(ordered_prims : ^[dynamic]embree.RTCBuildPrimitive, prims: [dynamic]Entity, root: BvhNode, num_nodes : i32, alloc : mem.Allocator = context.temp_allocator)
{
    context.allocator = alloc
    num_prims := len(ordered_prims)
    if(num_prims == 0) do return
    g_raytracer.primitives = make([dynamic]gpu.Primitive, 0, num_prims, alloc)
    g_raytracer.ordered_prims_map = make([dynamic]int, num_prims, alloc)
    // clear(&g_raytracer.primitives)
    // clear(&g_raytracer.ordered_prims_map)
    // reserve(&g_raytracer.primitives, num_prims)
    // resize(&g_raytracer.ordered_prims_map, num_prims)
    for op, i in ordered_prims{
        g_raytracer.ordered_prims_map[op.primID] = i
        prim := prims[op.primID]
        pc := get_component(prim, Cmp_Primitive)

        if pc != nil {
            n := get_component(prim, Cmp_Node)
            //fmt.printfln("Prim #%d: %s",i, n.name)
            // Convert primitive component to GPU primitive
            gpu_prim := gpu.Primitive{
                world = pc.world,
                extents = pc.extents,
                num_children = pc.num_children,
                id = pc.id,
                mat_id = pc.mat_id,
                start_index = pc.start_index,
                end_index = pc.end_index,
            }
            append(&g_raytracer.primitives, gpu_prim)
        }
    }

    // Flatten BVH tree
    resize(&g_raytracer.bvh, int(num_nodes))

    // Get root bounds
    root_bounds: BvhBounds
    if root == nil { return }  // Early exit if no tree

    kind := (cast(^BvhNodeKind)root)^  // Peek
    #partial switch kind {
    case .Inner:
        root_node := cast(^InnerBvhNode)root
        root_bounds = bvh_merge(root_node.bounds[0], root_node.bounds[1])
    case .Leaf:
        root_node := cast(^LeafBvhNode)root
        root_bounds = root_node.bounds
    }

    offset := 0
    flatten_bvh(root, root_bounds, &offset)
    g_raytracer.update_flags |= {.BVH}
}

// Flatten BVH tree into linear array for GPU
flatten_bvh :: proc(node: BvhNode, bounds: BvhBounds, offset: ^int) -> i32 {
    if node == nil { return -1 }  // Safeguard

    bvh_node := &g_raytracer.bvh[offset^]
    my_offset := i32(offset^)
    offset^ += 1

    // Peek at kind (safe: first field)
    kind := (cast(^BvhNodeKind)node)^

    #partial switch kind {
    case .Leaf:
        n := cast(^LeafBvhNode)node
        bvh_node.upper = n.bounds.upper
        bvh_node.lower = n.bounds.lower
        bvh_node.num_children = 0
        bvh_node.offset = i32(g_raytracer.ordered_prims_map[n.id])

    case .Inner:
        n := cast(^InnerBvhNode)node
        bvh_node.upper = bounds.upper
        bvh_node.lower = bounds.lower
        bvh_node.num_children = 2
        flatten_bvh(n.children[0], n.bounds[0], offset)
        bvh_node.offset = flatten_bvh(n.children[1], n.bounds[1], offset)
    }

    return my_offset
}

// Debug print for update_bvh parameters
print_update_bvh_debug :: proc(ordered_prims: ^[dynamic]embree.RTCBuildPrimitive, prims: [dynamic]Entity) {
    fmt.println("=== Update BVH Debug ===")

    for ordered_prim, idx in ordered_prims {
        prim_id := ordered_prim.primID
        prim_value := prims[prim_id] if prim_id < u32(len(prims)) else Entity(0)

        if prim_id < u32(len(prims)) {
            node := get_component(prim_value, Cmp_Node)
            node_name := node.name if node != nil && len(node.name) > 0 else fmt.aprintf("Entity_%d", prim_value)
            defer if node == nil || len(node.name) == 0 do delete(node_name)

            fmt.printf("[%d] PrimID: %d, Entity: %v, Name: %s\n", idx, prim_id, prim_value, node_name)
        } else {
            fmt.printf("[%d] PrimID: %d - OUT OF BOUNDS!\n", idx, prim_id)
        }
    }
}


update_uniform_buffers :: proc() {
    gpu.vbuffer_apply_changes(&g_raytracer.compute.uniform_buffer, &g_renderbase.vma_allocator, &g_raytracer.compute.ubo)
}

update_material :: proc(id: i32) {
    m := get_material(id)
    g_raytracer.materials[id].diffuse = m.diffuse
    g_raytracer.materials[id].reflective = m.reflective
    g_raytracer.materials[id].roughness = m.roughness
    g_raytracer.materials[id].transparency = m.transparency
    g_raytracer.materials[id].refractive_index = m.refractive_index
    g_raytracer.materials[id].texture_id = g_texture_indexes[m.texture]
    gpu.vbuffer_update(&g_raytracer.compute.storage_buffers.materials, &g_renderbase.vma_allocator, g_raytracer.materials[:])
}

update_gui :: proc(gc: ^Cmp_Gui) {
    gui := &g_raytracer.guis[gc.ref]
    gui.min = gc.min
    gui.extents = gc.extents
    gui.align_min = gc.align_min
    gui.align_ext = gc.align_ext
    gui.layer = gc.layer
    gui.id = g_texture_indexes[gc.id]
    gui.alpha = gc.alpha
    g_raytracer.update_flags |= {.GUI}
}

update_text :: proc(tc: ^Cmp_Text) {
    for ref in tc.shader_refs {
        if ref >= 0 && ref < i32(len(g_raytracer.guis)) {
            g_raytracer.guis[ref].alpha = 0
        }
    }
    clear(&tc.shader_refs)

    pos := tc.min
    for char in tc.text {
        if char not_in g_raytracer.font.char_data { continue }

        data := g_raytracer.font.char_data[char]
        gui := gpu.Gui {
            min = pos + data.offset * tc.font_scale,
            extents = data.uv_ext * tc.font_scale,
            align_min = data.uv_min,
            align_ext = data.uv_ext,
            layer = tc.layer,
            id = g_texture_indexes["Deutsch.ttf"],
            alpha = tc.alpha,
            // color = tc.color,  // If you add this to gpu.Gui
        }
        append(&tc.shader_refs, i32(len(g_raytracer.guis)))
        append(&g_raytracer.guis, gui)
        pos.x += data.advance * tc.font_scale
    }

    if len(tc.shader_refs) > 0 do tc.ref = tc.shader_refs[0]
    update_descriptors()
    g_raytracer.update_flags |= {.GUI}
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
            g_raytracer.guis[gnc.shader_references[i]].align_min = {0.1 * f32(nums[i]), 0.0}
            g_raytracer.guis[gnc.shader_references[i]].alpha = gnc.alpha
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
                    append(&gnc.shader_references, i32(len(g_raytracer.guis)))
                    append(&g_raytracer.guis, gui)
                }
                gpu.vbuffer_update_and_expand(&g_raytracer.compute.storage_buffers.guis, &g_renderbase.vma_allocator, g_raytracer.guis[:], u32(len(g_raytracer.guis)))
            }
            for i in 0..<num_size {
                g_raytracer.guis[gnc.shader_references[i]].align_min = {0.1 * f32(nums[i]), 0.0}
                g_raytracer.guis[gnc.shader_references[i]].alpha = gnc.alpha
                g_raytracer.guis[gnc.shader_references[i]].min.x = gnc.min.x - (f32(num_size - 1 - i) * gnc.extents.x)
            }
            gnc.highest_active_digit_index = num_size - 1
        } else {
            for i in 0..<num_size {
                g_raytracer.guis[gnc.shader_references[i]].align_min = {0.1 * f32(nums[i]), 0.0}
                g_raytracer.guis[gnc.shader_references[i]].alpha = gnc.alpha
                g_raytracer.guis[gnc.shader_references[i]].min.x = gnc.min.x - (f32(num_size - 1 - i) * gnc.extents.x)
            }
            for i in gnc.highest_active_digit_index..<num_size {
                g_raytracer.guis[gnc.shader_references[i]].alpha = 0
            }
            gnc.highest_active_digit_index = num_size - 1
        }
    }
    g_raytracer.update_flags |= {.GUI}
}

//----------------------------------------------------------------------------\\
// /Main Procs /main procs
//----------------------------------------------------------------------------\\
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
        append(&gnc.shader_references, i32(len(g_raytracer.guis)))
        append(&g_raytracer.guis, gui)
    }
    gnc.ref = gnc.shader_references[0]
    g_raytracer.update_flags |= {.GUI}
}

fence_timeout_ns :: 10_000_000_000 // 1 second
start_frame :: proc(image_index: ^u32) {
    // Wait/reset graphics fence for prior frame sync (enables multi-frame overlap)
    must(vk.WaitForFences(g_renderbase.device, 1, &g_renderbase.in_flight_fences[g_renderbase.current_frame], true, fence_timeout_ns))
    must(vk.ResetFences(g_renderbase.device, 1, &g_renderbase.in_flight_fences[g_renderbase.current_frame]))

    result := vk.AcquireNextImageKHR(
        g_renderbase.device,
        g_renderbase.swapchain,
        max(u64),
        g_renderbase.image_available_semaphores[g_renderbase.current_frame],
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
    g_renderbase.submit_info = vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers = &g_renderbase.command_buffers[image_index^],
        waitSemaphoreCount = 1,
        pWaitSemaphores = &g_renderbase.image_available_semaphores[g_renderbase.current_frame],
        pWaitDstStageMask = &wait_stages,
        signalSemaphoreCount = 1,
        pSignalSemaphores = &g_renderbase.render_finished_semaphores[g_renderbase.current_frame]
    }
    must(vk.QueueSubmit(g_renderbase.graphics_queue, 1, &g_renderbase.submit_info, g_renderbase.in_flight_fences[g_renderbase.current_frame]))  // Fence for graphics
}

end_frame :: proc(image_index: ^u32) {
    present_info := vk.PresentInfoKHR{
        sType = .PRESENT_INFO_KHR,
        waitSemaphoreCount = 1,  // Fixed to 1 (matches signal)
        pWaitSemaphores = &g_renderbase.render_finished_semaphores[g_renderbase.current_frame],
        swapchainCount = 1,
        pSwapchains = &g_renderbase.swapchain,
        pImageIndices = image_index,
    }

    result := vk.QueuePresentKHR(g_renderbase.present_queue, &present_info)
    switch {
    case result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || g_renderbase.framebuffer_resized:
        g_renderbase.framebuffer_resized = false
        rt_recreate_swapchain()
        return  // Skip advance on recreate
    case result == .SUCCESS:
    case:
        panic(fmt.tprintf("vulkan: present failure: %v", result))
    }

    // No QueueWaitIdle: Use fences for async sync instead

    // Compute: Wait/reset dedicated compute fence (matches C++)
    must(vk.WaitForFences(g_renderbase.device, 1, &g_raytracer.compute.fence, true, fence_timeout_ns))
    must(vk.ResetFences(g_renderbase.device, 1, &g_raytracer.compute.fence))

    compute_submit_info := vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers = &g_raytracer.compute.command_buffer,
    }
    must(vk.QueueSubmit(g_renderbase.compute_queue, 1, &compute_submit_info, g_raytracer.compute.fence))  // Dedicated fence

    g_renderbase.current_frame = (g_renderbase.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

added_entity :: proc(e: Entity, world : ^World) {
    rc := get_component(e, Cmp_Render, world)
    if rc == nil { return }
    t := rc.type

    if .MATERIAL in t {
    }
    if .PRIMITIVE in t {
        prim_comp := get_component(e, Cmp_Primitive, world)
        mat_comp := get_component(e, Cmp_Material, world)
        trans_comp := get_component(e, Cmp_Transform, world)
        prim_comp.mat_id = mat_comp.mat_unique_id
        prim_comp.world = trans_comp.world
        prim_comp.extents = trans_comp.local.sca.xyz
        if prim_comp.id > 0 {
            temp := g_raytracer.mesh_assigner[prim_comp.id]
            prim_comp.start_index = i32(temp[0])
            prim_comp.end_index = i32(temp[1])
        }
        g_raytracer.update_flags |= {.OBJECT}
    }
    if .LIGHT in t {
        light_comp := get_component(e, Cmp_Light, world)
        trans_comp := get_component(e, Cmp_Transform, world)
        light := gpu.Light{
            pos = trans_comp.local.pos.xyz, // technically yes it should be global pos, but this is fine
            color = light_comp.color,
            intensity = light_comp.intensity,
            id = i32(e),
        }
        light_comp.id = light.id
        append(&g_raytracer.lights, light)
        append(&g_raytracer.light_comps, light_comp^)

        gpu.vbuffer_update_and_expand(&g_raytracer.compute.storage_buffers.lights, &g_renderbase.vma_allocator, g_raytracer.lights[:], u32(len(g_raytracer.lights)))
        g_raytracer.update_flags |= {.LIGHT}
    }
    if .GUI in t {
        gc := get_component(e, Cmp_Gui, world)
        gui := gpu.Gui{
            min = gc.min,
            extents = gc.extents,
            align_min = gc.align_min,
            align_ext = gc.align_ext,
            layer = gc.layer,
            id = g_texture_indexes[gc.id],
            alpha = gc.alpha,
        }
        gc.ref = i32(len(g_raytracer.guis))
        append(&g_raytracer.guis, gui)
        g_raytracer.update_flags |= {.GUI}
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
            append(&gnc.shader_references, i32(len(g_raytracer.guis)))
            append(&g_raytracer.guis, gui)
        }
        gnc.ref = gnc.shader_references[0]
        g_raytracer.update_flags |= {.GUI}
    }
    if .CAMERA in t {
        cam := get_component(e, Cmp_Camera)
        trans_comp := get_component(e, Cmp_Transform)
        g_raytracer.compute.ubo.aspect_ratio = cam.aspect_ratio
        g_raytracer.compute.ubo.rotM = transmute(mat4f)trans_comp.world
        g_raytracer.compute.ubo.fov = cam.fov
        update_camera(cam)
    }
    if .TEXT in t {
        tc := get_component(e,Cmp_Text)
        update_text(tc)
        tc.ref = tc.shader_refs[0] if len(tc.shader_refs) > 0 else -1
        g_raytracer.update_flags |= {.GUI}
    }
}

removed_entity :: proc(e: Entity) {
    rc := get_component(e, Cmp_Render)
    if rc == nil { return }
    t := rc.type

    if .LIGHT in t {
        lc := get_component(e, Cmp_Light)
        for l, i in g_raytracer.lights {
            if lc.id == l.id {
                ordered_remove(&g_raytracer.lights, i)
                ordered_remove(&g_raytracer.light_comps, i)
                break
            }
        }
        if len(g_raytracer.lights) == 0 {
            clear(&g_raytracer.lights)
            clear(&g_raytracer.light_comps)
        }
    }
    if .TEXT in t {
        tc := get_component(e, Cmp_Text)
        for ref in tc.shader_refs {
            if ref >= 0 && ref < i32(len(g_raytracer.guis)) {
                g_raytracer.guis[ref].alpha = 0
            }
        }
        delete(tc.shader_refs)
        g_raytracer.update_flags |= {.GUI}
    }
}

render_clear_entities :: proc() {
    clear(&g_raytracer.lights)
    clear(&g_raytracer.light_comps)
    clear(&g_raytracer.primitives)
    clear(&g_raytracer.guis)
}

process_entity :: proc(e: Entity) {
    rc := get_component(e, Cmp_Render)
    if rc == nil { return }
    type := rc.type
    if type == {} { return }

    switch {
    case .MATERIAL in type:
        g_raytracer.update_flags |= {.MATERIAL}
    case .PRIMITIVE in type:
        g_raytracer.update_flags |= {.OBJECT}
    case .LIGHT in type:
        g_raytracer.update_flags |= {.LIGHT}
    case .GUI in type:
        gc := get_component(e, Cmp_Gui)
        update_gui(gc)
    case .GUINUM in type:
        gnc := get_component(e, Cmp_GuiNumber)
        if gnc.update {
            gnc.update = false
            update_gui_number(gnc)
        }
    case .TEXT in type:
            tc := get_component(e, Cmp_Text)
            if tc.update{
                tc.update = false
                update_text(tc)
        }
    }
}

end :: proc() {
    update_buffers()
    update_descriptors()
    if glfw.WindowShouldClose(g_window.handle) {
        end_ecs()
        vk.DeviceWaitIdle(g_renderbase.device)
    }
}

cleanup :: proc() {
    vk.DeviceWaitIdle(g_renderbase.device)

    // Cleanup swapchain first
    cleanup_swapchain()

    // Destroy descriptor pool and layout before other resources
    vk.DestroyDescriptorPool(g_renderbase.device, g_raytracer.descriptor_pool, nil)
    vk.DestroyDescriptorSetLayout(g_renderbase.device, g_raytracer.graphics.descriptor_set_layout, nil)

    // Now cleanup everything else including the device
    cleanup_vulkan()

    // Final cleanup of instance-level resources
    destroy_vulkan()
    delete(g_texture_indexes)
}

destroy_compute :: proc() {
    // This function is now handled by cleanup_vulkan to ensure proper ordering
    // All compute resource cleanup moved to cleanup_vulkan()
}

cleanup_swapchain :: proc() {
    vk.DestroyPipeline(g_renderbase.device, g_raytracer.graphics.pipeline, nil)
    vk.DestroyPipelineLayout(g_renderbase.device, g_raytracer.graphics.pipeline_layout, nil)

    cleanup_swapchain_vulkan()
}

rt_recreate_swapchain :: proc() {
    recreate_swapchain_vulkan()
    create_descriptor_set_layout()
    create_graphics_pipeline()
    create_command_buffers(0.7333333333, i32(f32(g_renderbase.swapchain_extent.width) * 0.16666666666), 36)
}

// Cleanup swap chain resources
cleanup_swapchain_vulkan :: proc() {
    // Swapchain views and swapchain are destroyed by destroy_swapchain()
    // This function is kept for any future swapchain-specific cleanup
}

// Recreate swap chain
recreate_swapchain_vulkan :: proc() {
    // Don't do anything when minimized.
    for w, h := glfw.GetFramebufferSize(g_window.handle); w == 0 || h == 0; w, h = glfw.GetFramebufferSize(g_window.handle) {
        glfw.WaitEvents()
        if glfw.WindowShouldClose(g_window.handle) { break }
    }

    vk.DeviceWaitIdle(g_renderbase.device)

    cleanup_swapchain_vulkan()

    create_swapchain()
    create_depth_resources()
    create_framebuffers()
}

// Full Vulkan cleanup
cleanup_vulkan :: proc() {
    vk.DeviceWaitIdle(g_renderbase.device)

    // First cleanup all VMA buffers (must be done before device destruction)
    gpu.vbuffer_destroy(&g_raytracer.compute.uniform_buffer, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.verts, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.faces, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.blas, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.shapes, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.primitives, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.materials, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.lights, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.guis, &g_renderbase.vma_allocator)
    gpu.vbuffer_destroy(&g_raytracer.compute.storage_buffers.bvh, &g_renderbase.vma_allocator)

    // Destroy textures
    texture_destroy(&g_raytracer.compute_texture, g_renderbase.device, &g_renderbase.vma_allocator)
    for &tex in g_raytracer.gui_textures do texture_destroy(&tex, g_renderbase.device, &g_renderbase.vma_allocator)
    for &tex in g_raytracer.bindless_textures do texture_destroy(&tex, g_renderbase.device, &g_renderbase.vma_allocator)
    texture_destroy(&g_raytracer.font.atlas_texture, g_renderbase.device, &g_renderbase.vma_allocator)
    delete(g_raytracer.font.char_data)

    // Destroy all dynamic objects
    delete(g_raytracer.primitives)
    delete(g_raytracer.materials)
    delete(g_raytracer.lights)
    delete(g_raytracer.guis)
    delete(g_raytracer.bvh)
    delete(g_raytracer.mesh_comps)
    delete(g_raytracer.light_comps)
    delete(g_raytracer.mesh_assigner)
    delete(g_raytracer.bindless_textures)
    delete(g_raytracer.ordered_prims_map)
    // Destroy command pools (this automatically frees command buffers)
    vk.DestroyCommandPool(g_renderbase.device, g_raytracer.compute.command_pool, nil)
    vk.DestroyCommandPool(g_renderbase.device, g_renderbase.command_pool, nil)
    vk.DestroyFence(g_renderbase.device, g_raytracer.compute.fence, nil)

    // Destroy pipelines and layouts
    vk.DestroyPipeline(g_renderbase.device, g_raytracer.compute.pipeline, nil)
    vk.DestroyPipelineLayout(g_renderbase.device, g_raytracer.compute.pipeline_layout, nil)
    vk.DestroyDescriptorSetLayout(g_renderbase.device, g_raytracer.compute.descriptor_set_layout, nil)
    vk.DestroyPipelineCache(g_renderbase.device, g_renderbase.pipeline_cache, nil)

    // Destroy framebuffers first, then depth resources, then swapchain
    destroy_framebuffers()
    destroy_depth_resources()
    destroy_swapchain()
    cleanup_swapchain_vulkan()

    vk.DestroyRenderPass(g_renderbase.device, g_renderbase.render_pass, nil)

    // Destroy semaphores
    for sem in g_renderbase.image_available_semaphores do vk.DestroySemaphore(g_renderbase.device, sem, nil)
    for sem in g_renderbase.render_finished_semaphores do vk.DestroySemaphore(g_renderbase.device, sem, nil)
    for fence in g_renderbase.in_flight_fences do vk.DestroyFence(g_renderbase.device, fence, nil)

    // Destroy remaining graphics resources
    vk.DestroyShaderModule(g_renderbase.device, g_renderbase.vert_shader_module, nil)
    vk.DestroyShaderModule(g_renderbase.device, g_renderbase.frag_shader_module, nil)
    vma.DestroyAllocator(g_renderbase.vma_allocator)

    // Finally destroy device
    vk.DestroyDevice(g_renderbase.device, nil)
    vk.DestroySurfaceKHR(g_renderbase.instance, g_renderbase.surface, nil)
}
