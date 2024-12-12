package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

main :: proc() {
	track_alloc: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track_alloc, context.allocator)
	context.allocator = mem.tracking_allocator(&track_alloc)
	defer {
		// At the end of the program, lets print out the results
		fmt.eprintf("\n")
		// Memory leaks
		for _, entry in track_alloc.allocation_map {
			fmt.eprintf("- %v leaked %v bytes\n", entry.location, entry.size)
		}
		// Double free etc.
		for entry in track_alloc.bad_free_array {
			fmt.eprintf("- %v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track_alloc)
		fmt.eprintf("\n")

		// Free the temp_allocator so we don't forget it
		// The temp_allocator can be used to allocate temporary memory
		free_all(context.temp_allocator)
	}

	//Create Window
	{
		glfw.Init()

		glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
		glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
		glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6)
		glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)

		g_monitor = glfw.GetPrimaryMonitor()
		mode := glfw.GetVideoMode(g_monitor)

		glfw.WindowHint(glfw.RED_BITS, mode.red_bits)
		glfw.WindowHint(glfw.GREEN_BITS, mode.green_bits)
		glfw.WindowHint(glfw.BLUE_BITS, mode.blue_bits)
		glfw.WindowHint(glfw.REFRESH_RATE, mode.refresh_rate)
		glfw.WindowHint(glfw.RESIZABLE, true)

		g_window = glfw.CreateWindow(1280, 720, "Axiomo Engine", nil, nil)
		if (g_window == nil) {
			fmt.println("unable to create window")
			return
		}

		glfw.MakeContextCurrent(g_window)
		glfw.SwapInterval(1)
		glfw.SetKeyCallback(g_window, key_callback)
		glfw.SetFramebufferSizeCallback(g_window, size_callback)
	}
	defer glfw.Terminate()
	defer glfw.DestroyWindow(g_window)

	//Update Window
	for (!glfw.WindowShouldClose(g_window)) {
		glfw.PollEvents()
	}
}

// Called when glfw keystate changes
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	// Exit program on escape pressed
	if (key == glfw.KEY_ESCAPE) {
		glfw.SetWindowShouldClose(window, true)
	}
}

// Called when glfw window changes size
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	// Set the OpenGL viewport size
	//gl.Viewport(0, 0, width, height)
}

initialize_vulkan :: proc() {
	context.user_ptr = &g_device.instance
	get_proc_address :: proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = glfw.GetInstanceProcAddress((^vk.Instance)(context.user_ptr)^, name)
	}

	vk.load_proc_addresses(get_proc_address)
	initialize_vulkan_device()
	//Set up Application Info
	{
		app_info.sType = vk.StructureType.APPLICATION_INFO
		app_info.pApplicationName = "Hello Odin Engine"
		app_info.applicationVersion = vk.MAKE_VERSION(0, 0, 1)
		app_info.pEngineName = "AxiomO Engine"
		app_info.engineVersion = vk.MAKE_VERSION(0, 0, 1)
		app_info.apiVersion = vk.API_VERSION_1_3
	}

	extensions: [dynamic]cstring
	//Instance Info
	{
		instance_info: vk.InstanceCreateInfo
		instance_info.sType = vk.StructureType.INSTANCE_CREATE_INFO
		instance_info.pApplicationInfo = &app_info

		//Get required Extensions
		{
			glfw_extensions: []cstring
			glfw_extensions = glfw.GetRequiredInstanceExtensions()
			count := len(glfw_extensions)
			for e in glfw_extensions {append(&extensions, e)}
			if (g_device.validation_layers_enabled) {append(&extensions, "VK_EXT_debug_report")}
		}
		instance_info.enabledExtensionCount = u32(len(extensions))
		instance_info.ppEnabledExtensionNames = raw_data(extensions)
		if (g_device.validation_layers_enabled) {
			instance_info.enabledLayerCount = u32(len(g_device.validation_layers))
			instance_info.ppEnabledLayerNames = raw_data(g_device.validation_layers)
		} else {instance_info.enabledLayerCount = 0}

		for e, i in extensions {
			fmt.println("extension ", i, ": ", e)
		}
		result := vk.CreateInstance(&instance_info, nil, &g_device.instance)
		assert(result == vk.Result.SUCCESS)
	}

	// Debug callback
	{
		if(!b_enable_validation_layers){return}
		create_info : vk.DebugReportCallbackCreateInfoEXT
		create_info.sType = vk.StructureType.DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT
		create_info.flags = Vk.DebugReportFlagEXT.ERROR
		create_info.pfnCallback = debug_callback
		
		vk.CreateDebugReportCallbackEXT(g_device.instance,create_info, nil, g_device.callback)
	}

	// Create Surface
	{
		glfw.CreateWindowSurface(g_device.instance, g_window, nil, render_base.surface^)
	}

	// Pick Physical Device
	{
		//Make sure there's atleasT ONE DEVICE
		device_count := u32(0)
		vk.EnumeratePhysicalDevices(g_device.instance, &device_count, nil)
		assert(device_count > 0)

		// Array to hold all the physical devices
		devices : [dynamic]vk.PhysicalDevice
		vk.EnumeratePhysicalDevices(g_device.instance, &device_count, [^]devices)

		//Make sure you pick suitable devices
		//std::remove_if(devices.begin(), devices.end(), [&](const VkPhysicalDevice& d) -> bool {
		//	return isDeviceSuitable(d) == false;
		//});

		for device in devices{
			features : vk.PhysicalDeviceFeatures
			properties : vk.PhysicalDeviceProperties
			vk.GetPhysicalDeviceProperties(device, &properties)
			if(properties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
			{
				vk.GetPhysicalDeviceFeatures(device, &features)
				g_device.physical = device
				g_device.features = features
				g_device.device_properties = properties
				return
			}
		}
		assert(g_device.physical != nil)
	}
}

/*bool RenderBase::isDeviceSuitable(VkPhysicalDevice device) {
	/*
	//Details about basic device properties
	VkPhysicalDeviceProperties deviceProperties;
	vkGetPhysicalDeviceProperties(device, &deviceProperties);

	//Details about device features
	VkPhysicalDeviceFeatures deviceFeatures;
	vkGetPhysicalDeviceFeatures(device, &deviceFeatures);*/
	QueueFamilyIndices indices = findQueueFamilies(device);

	bool extensionsSupported = vkDevice.checkDeviceExtensionSupport(device);
	bool swapChainAdequate = false;
	if (extensionsSupported) {
		SwapChainSupportDetails swapChainSupport = querySwapChainSupport(device);
		swapChainAdequate = !swapChainSupport.formats.empty() && !swapChainSupport.presentModes.empty();
	}
	VkPhysicalDeviceFeatures supportedFeatures;
	vkGetPhysicalDeviceFeatures(device, &supportedFeatures);

	return indices.isComplete() && extensionsSupported && swapChainAdequate && supportedFeatures.samplerAnisotropy;
}*/


is_device_suitable :: proc(device : vk.PhysicalDevice) -> bool {
	indices : QueueFamilyIndices
	extensions_supported := vk.Device.checkDeviceExtensionSupport(device)
	swap_chain_adequate := false	
	if(extensions_supported){
		
	}
}
