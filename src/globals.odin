package main
import glfw "vendor:glfw"
import vk "vendor:vulkan"
import "core:fmt"

g_monitor : glfw.MonitorHandle
g_window : glfw.WindowHandle

//Vulkan
app_info : vk.ApplicationInfo
b_enable_validation_layers : b32

VulkanDevice :: struct 
{
    instance : vk.Instance,
    logical : vk.Device,
    physical : vk.PhysicalDevice,
    callback : vk.DebugReportCallbackEXT,
    features : vk.PhysicalDeviceFeatures,
    properties : vk.PhysicalDeviceProperties,
    qfams : QueueFamilyIndices,
    queue : ^vk.Queue,
    command_pool : vk.CommandPool,
    device_extensions : []cstring,
    validation_layers : []cstring,
    validation_layers_enabled : b32
}
g_device : VulkanDevice

RenderBase :: struct{
    surface : vk.SurfaceKHR,
    depth_image : vk.Image,
    depth_image_memory : vk.DeviceMemory,
    depth_image_view : vk.ImageView,
    depth_format : vk.Format,
    
    graphics_queue : vk.Queue,
    present_queue : vk.Queue,
    compute_queue : vk.Queue,

    render_pass : vk.RenderPass,
    pipeline_cache : vk.PipelineCache,
    swap_chain : vk.SwapchainKHR,
    swap_chain_images : [dynamic]vk.Image,
    swap_chain_image_format : vk.Format,
    swap_chain_extent : vk.Extent2D,

    swap_chain_image_views : [dynamic]vk.ImageView,
    swap_chain_frame_buffers : [dynamic]vk.Framebuffer,
    command_buffers : [dynamic]vk.CommandBuffer,
    command_pool : vk.CommandPool,

    image_available_semaphore : vk.Semaphore,
    render_finished_semaphore : vk.Semaphore
}

render_base : RenderBase

initialize_vulkan_device :: proc(){
    g_device.qfams.compute_fam = -1
    g_device.qfams.graphics_fam = -1
    g_device.qfams.present_fam = -1
    g_device.validation_layers_enabled = false
    g_device.device_extensions = {vk.KHR_SWAPCHAIN_EXTENSION_NAME}
    g_device.validation_layers = { "VK_LAYER_KHRONOS_validation" };// "VK_LAYER_LUNARG_standard_validation"};
}

QueueFamilyIndices :: struct 
{
    graphics_fam : int,
    present_fam : int,
    compute_fam : int    
}

debug_callback :: proc "c"(
    flags : vk.DebugReportFlagsEXT,
    type : vk.DebugReportObjectTypeEXT,
    obj : u64,
    location : u32,
    code : i32,
    layer_prefix : const char^,
    msg : const char^,
    user_data : void^
) -> vk.VkBool32{
    fmt.printf(msg)
    return vk.FALSE
}
