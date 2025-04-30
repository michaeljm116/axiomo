package main
import vk "vendor:vulkan"
import "vendor:glfw"
import "base:runtime"


when ODIN_OS == .Darwin {
	// NOTE: just a bogus import of the system library,
	// needed so we can add a linker flag to point to /usr/local/lib (where vulkan is installed by default)
	// when trying to load vulkan.
	@(require, extra_linker_flags = "-rpath /usr/local/lib")
	foreign import __ "system:System.framework"
}

SHADER_VERT :: #load("vert.spv")
SHADER_FRAG :: #load("frag.spv")

// Enables Vulkan debug logging and validation layers.
ENABLE_VALIDATION_LAYERS :: #config(ENABLE_VALIDATION_LAYERS, ODIN_DEBUG)

MAX_FRAMES_IN_FLIGHT :: 2

g_ctx: runtime.Context

g_window: glfw.WindowHandle

g_framebuffer_resized: bool

g_instance: vk.Instance
g_physical_device: vk.PhysicalDevice
g_device: vk.Device
g_surface: vk.SurfaceKHR
g_graphics_queue: vk.Queue
g_present_queue: vk.Queue

g_swapchain: vk.SwapchainKHR
g_swapchain_images: []vk.Image
g_swapchain_views: []vk.ImageView
g_swapchain_format: vk.SurfaceFormatKHR
g_swapchain_extent: vk.Extent2D
g_swapchain_frame_buffers: []vk.Framebuffer

g_vert_shader_module: vk.ShaderModule
g_frag_shader_module: vk.ShaderModule
g_shader_stages: [2]vk.PipelineShaderStageCreateInfo

g_render_pass: vk.RenderPass
g_pipeline_layout: vk.PipelineLayout
g_pipeline: vk.Pipeline

g_command_pool: vk.CommandPool
g_command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer

g_image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
g_render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
g_in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence

// KHR_PORTABILITY_SUBSET_EXTENSION_NAME :: "VK_KHR_portability_subset"

DEVICE_EXTENSIONS := []cstring {
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
	// KHR_PORTABILITY_SUBSET_EXTENSION_NAME,
}
