import "core:os"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:fmt"
import "gpu"
import res "resource"
import "external/embree"
import "core:math/bits"
import stbi "vendor:stb/image"
import path2 "extensions/filepath2"
//----------------------------------------------------------------------------\
// /RENDERBASE /rb
//----------------------------------------------------------------------------\
SHADER_VERT :: #load("../assets/shaders/texture.vert.spv")
SHADER_FRAG :: #load("../assets/shaders/texture.frag.spv")
POST_BLUR :: #load("../assets/shaders/post-blur.spv") // ADDED: Load the post-blur SPIR-V
// Enables Vulkan debug logging and validation layers.
ENABLE_VALIDATION_LAYERS :: #config(ENABLE_VALIDATION_LAYERS, ODIN_DEBUG)
dbg_messenger: vk.DebugUtilsMessengerEXT
current_frame: int
MAX_FRAMES_IN_FLIGHT :: 1
MAX_SWAPCHAIN_IMAGES := 3
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
command_buffers: []vk.CommandBuffer,
image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
vma_allocator: vma.Allocator,
depth_image : vk.Image,
depth_allocation : vma.Allocation,
depth_view: vk.ImageView,
submit_info: vk.SubmitInfo,
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
glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
rb.window = glfw.CreateWindow(1280, 720, "Bee Killins Inn", nil, nil)
glfw.SetFramebufferSizeCallback(rb.window, proc "c" (_: glfw.WindowHandle, _, _: i32) {
rb.framebuffer_resized = true
})
//----------------------------------------------------------------------------\
// /Create Instance /ci
//----------------------------------------------------------------------------\
vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
assert(vk.CreateInstance != nil, "vulkan function pointers not loaded")
create_info := vk.InstanceCreateInfo {
sType            = .INSTANCE_CREATE_INFO,
pApplicationInfo = &vk.ApplicationInfo {
sType = .APPLICATION_INFO,
pApplicationName = "JetpackJoyrayde",
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
must(vk.CreateInstance(&create_info, nil, &rb.instance))
vk.load_proc_addresses_instance(rb.instance)
when ENABLE_VALIDATION_LAYERS {
must(vk.CreateDebugUtilsMessengerEXT(rb.instance, &dbg_create_info, nil, &dbg_messenger))
}
//----------------------------------------------------------------------------\
// /Create Surface and Devices /cs
//----------------------------------------------------------------------------\
must(glfw.CreateWindowSurface(rb.instance, rb.window, nil, &rb.surface))
// Pick a suitable GPU.
must(pick_physical_device())
// Setup logical device,
indices := find_queue_families(rb.physical_device)
set_compute_queue_family_index(rb.physical_device, &indices)
rb.compute_queue_family_index = indices.compute.?
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
//----------------------------------------------------------------------------\
// /Bindless /bi add bindless support if it has it
//----------------------------------------------------------------------------\
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
vk.GetDeviceQueue(rb.device, indices.compute.?, 1, &rb.compute_queue) // should be rb.compute_queue_family_index, but it aint workin fo some reason
}
init_vma()
create_swapchain()
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
dstSubpass = 0,
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
create_pipeline_cache()
// Create command pool.
{
pool_info := vk.CommandPoolCreateInfo {
sType            = .COMMAND_POOL_CREATE_INFO,
flags            = {.TRANSIENT},
queueFamilyIndex = indices.graphics.?,
}
must(vk.CreateCommandPool(rb.device, &pool_info, nil, &rb.command_pool))
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
must(vk.CreateSemaphore(rb.device, &sem_info, nil, &rb.image_available_semaphores[i]))
must(vk.CreateSemaphore(rb.device, &sem_info, nil, &rb.render_finished_semaphores[i]))
must(vk.CreateFence(rb.device, &fence_info, nil, &rb.in_flight_fences[i]))
}
}
current_frame = 0
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
for fam, i in fams {
if .COMPUTE in fam.queueFlags && u32(i) != ids.graphics.? && u32(i) != ids.present.? {
ids.compute = u32(i)
return
}
}
for fam, i in fams {
if .COMPUTE in fam.queueFlags {
ids.compute = u32(i)
return
}
}
}
init_vma :: proc() {
create_info := vma.AllocatorCreateInfo {
physicalDevice = rb.physical_device,
device = rb.device,
instance = rb.instance,
vulkanApiVersion = vk.API_VERSION_1_3,
}
must(vma.CreateAllocator(&create_info, &rb.vma_allocator))
}
create_swapchain :: proc() {
support, _ := query_swapchain_support(rb.physical_device, context.temp_allocator)
surface_format := choose_swap_surface_format(support.formats[:])
present_mode := choose_swap_present_mode(support.presentModes[:])
extent := choose_swap_extent(support.capabilities)
image_count := support.capabilities.minImageCount + 1
if support.capabilities.maxImageCount > 0 && image_count > support.capabilities.maxImageCount {
image_count = support.capabilities.maxImageCount
}
indices := find_queue_families(rb.physical_device)
queue_family_indices := [?]u32{indices.graphics.?, indices.present.?}
sharing_mode: vk.SharingMode = .EXCLUSIVE
queue_family_index_count: u32 = 0
p_queue_family_indices: ^u32 = nil
if indices.graphics.? != indices.present.? {
sharing_mode = .CONCURRENT
queue_family_index_count = 2
p_queue_family_indices = raw_data(queue_family_indices[:])
}
create_info := vk.SwapchainCreateInfoKHR {
sType = .SWAPCHAIN_CREATE_INFO_KHR,
surface = rb.surface,
minImageCount = image_count,
imageFormat = surface_format.format,
imageColorSpace = surface_format.colorSpace,
imageExtent = extent,
imageArrayLayers = 1,
imageUsage = {.COLOR_ATTACHMENT},
imageSharingMode = sharing_mode,
queueFamilyIndexCount = queue_family_index_count,
pQueueFamilyIndices = p_queue_family_indices,
preTransform = support.capabilities.currentTransform,
compositeAlpha = {.OPAQUE},
presentMode = present_mode,
clipped = true,
oldSwapchain = rb.swapchain,
}
must(vk.CreateSwapchainKHR(rb.device, &create_info, nil, &rb.swapchain))
rb.swapchain_format = surface_format
rb.swapchain_extent = extent
count: u32
vk.GetSwapchainImagesKHR(rb.device, rb.swapchain, &count, nil)
rb.swapchain_images = make([]vk.Image, count)
vk.GetSwapchainImagesKHR(rb.device, rb.swapchain, &count, raw_data(rb.swapchain_images))
rb.swapchain_views = make([]vk.ImageView, len(rb.swapchain_images))
for &view, i in rb.swapchain_views {
view_info := vk.ImageViewCreateInfo {
sType = .IMAGE_VIEW_CREATE_INFO,
image = rb.swapchain_images[i],
viewType = .TYPE_2D,
format = rb.swapchain_format.format,
components = {
r = .IDENTITY,
g = .IDENTITY,
b = .IDENTITY,
a = .IDENTITY,
},
subresourceRange = {
aspectMask = {.COLOR},
baseMipLevel = 0,
levelCount = 1,
baseArrayLayer = 0,
layerCount = 1,
},
}
must(vk.CreateImageView(rb.device, &view_info, nil, &view))
}
// ADDED: Create scene and final images after swapchain
create_scene_and_final_images()
}
create_scene_and_final_images :: proc() {
format := vk.Format.R8G8B8A8_UNORM
usage := vk.ImageUsageFlags{.STORAGE, .SAMPLED} // For final, sampled for graphics frag; for scene, storage is enough, but add sampled if needed
// Create scene texture
gpu.texture_create(&rt.scene_texture, rb.swapchain_extent.width, rb.swapchain_extent.height, format, usage, rb.device, &rb.vma_allocator)
// Create final texture
gpu.texture_create(&rt.final_texture, rb.swapchain_extent.width, rb.swapchain_extent.height, format, usage, rb.device, &rb.vma_allocator)
}
destroy_scene_and_final_images :: proc() {
gpu.texture_destroy(&rt.scene_texture, rb.device, &rb.vma_allocator)
gpu.texture_destroy(&rt.final_texture, rb.device, &rb.vma_allocator)
}
// Assume this is called in init_vulkan after other compute init
init_post_blur :: proc() {
// Assume rt.post_blur is defined in rt struct as type with pipeline, etc.
// Create descriptor set layout - copy from compute desc set layout creation, adjust for post_blur
// Assuming create_compute_descriptor_set_layout() exists, create similar for post_blur
create_post_blur_descriptor_set_layout()
// Create pipeline layout
layout_info := vk.PipelineLayoutCreateInfo {
sType = .PIPELINE_LAYOUT_CREATE_INFO,
setLayoutCount = 1,
pSetLayouts = &rt.post_blur.descriptor_set_layout,
}
must(vk.CreatePipelineLayout(rb.device, &layout_info, nil, &rt.post_blur.pipeline_layout))
// Create shader module
module := create_shader_module(POST_BLUR)
// Create pipeline
stage := vk.PipelineShaderStageCreateInfo {
sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
stage = {.COMPUTE},
module = module,
pName = "main",
}
pipeline_info := vk.ComputePipelineCreateInfo {
sType = .COMPUTE_PIPELINE_CREATE_INFO,
stage = stage,
layout = rt.post_blur.pipeline_layout,
}
must(vk.CreateComputePipelines(rb.device, rb.pipeline_cache, 1, &pipeline_info, nil, &rt.post_blur.pipeline))
// Destroy temporary module
vk.DestroyShaderModule(rb.device, module, nil)
// Allocate descriptor set
alloc_info := vk.DescriptorSetAllocateInfo {
sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
descriptorPool = rt.descriptor_pool, // Assume same pool
descriptorSetCount = 1,
pSetLayouts = &rt.post_blur.descriptor_set_layout,
}
must(vk.AllocateDescriptorSets(rb.device, &alloc_info, &rt.post_blur.descriptor_set))
// Create command buffer (assume same command pool as compute)
alloc_info_cb := vk.CommandBufferAllocateInfo {
sType = .COMMAND_BUFFER_ALLOCATE_INFO,
commandPool = rt.compute.command_pool, // Assume shared
level = .PRIMARY,
commandBufferCount = 1,
}
must(vk.AllocateCommandBuffers(rb.device, &alloc_info_cb, &rt.post_blur.command_buffer))
// Create fence
fence_info := vk.FenceCreateInfo {
sType = .FENCE_CREATE_INFO,
flags = {.SIGNALED},
}
must(vk.CreateFence(rb.device, &fence_info, nil, &rt.post_blur.fence))
// Record the command buffer
record_post_blur_command_buffer()
}
// Assume this function creates the desc set layout for post_blur
create_post_blur_descriptor_set_layout :: proc() {
// This should be similar to the raytrace compute desc set layout, but with adjustments for bindings
// Assume the user has a list of bindings for the compute, copy and modify
// For example:
// bindings := make([]vk.DescriptorSetLayoutBinding, NUM_BINDINGS, context.temp_allocator)
// ... fill bindings for ubo, storage buffers, bindless
// Then for images:
// bindings[0] = ... for scene readonly STORAGE_IMAGE
// bindings[1] = ... for final writeonly STORAGE_IMAGE
// Adjust the binding numbers as per your layouts.glsl
// Then:
// create_info := vk.DescriptorSetLayoutCreateInfo {
//     sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
//     bindingCount = u32(len(bindings)),
//     pBindings = raw_data(bindings),
// }
// must(vk.CreateDescriptorSetLayout(rb.device, &create_info, nil, &rt.post_blur.descriptor_set_layout))
// Note: If bindless, add flags for PARTIALLY_BOUND etc.
}
// Record the post blur command buffer
record_post_blur_command_buffer :: proc() {
begin_info := vk.CommandBufferBeginInfo {
sType = .COMMAND_BUFFER_BEGIN_INFO,
flags = {.ONE_TIME_SUBMIT},
}
must(vk.BeginCommandBuffer(rt.post_blur.command_buffer, &begin_info))
// Add barrier for scene image
barrier := vk.ImageMemoryBarrier {
sType = .IMAGE_MEMORY_BARRIER,
srcAccessMask = {.SHADER_WRITE},
dstAccessMask = {.SHADER_READ},
oldLayout = .GENERAL,
newLayout = .GENERAL,
srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
image = rt.scene_texture.image,
subresourceRange = {
aspectMask = {.COLOR},
baseMipLevel = 0,
levelCount = 1,
baseArrayLayer = 0,
layerCount = 1,
},
}
vk.CmdPipelineBarrier(rt.post_blur.command_buffer, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 0, nil, 0, nil, 1, &barrier)
vk.CmdBindPipeline(rt.post_blur.command_buffer, .COMPUTE, rt.post_blur.pipeline)
vk.CmdBindDescriptorSets(rt.post_blur.command_buffer, .COMPUTE, rt.post_blur.pipeline_layout, 0, 1, &rt.post_blur.descriptor_set, 0, nil)
groupX := (rb.swapchain_extent.width + 15) / 16
groupY := (rb.swapchain_extent.height + 15) / 16
vk.CmdDispatch(rt.post_blur.command_buffer, groupX, groupY, 1)
must(vk.EndCommandBuffer(rt.post_blur.command_buffer))
}
// In update_descriptors, add update for post_blur desc set
// Assume update_descriptors :: proc() {
//   ... existing for raytrace, change to bind rt.scene_texture.image_view at binding 0 for write
//   then for post_blur:
//   scene_info := vk.DescriptorImageInfo {
//       imageLayout = .GENERAL,
//       imageView = rt.scene_texture.view,
//   }
//   final_info := vk.DescriptorImageInfo {
//       imageLayout = .GENERAL,
//       imageView = rt.final_texture.view,
//   }
//   writes := [2]vk.WriteDescriptorSet {
//       {
//           sType = .WRITE_DESCRIPTOR_SET,
//           dstSet = rt.post_blur.descriptor_set,
//           dstBinding = 0,
//           descriptorType = .STORAGE_IMAGE,
//           descriptorCount = 1,
//           pImageInfo = &scene_info,
//       },
//       {
//           sType = .WRITE_DESCRIPTOR_SET,
//           dstSet = rt.post_blur.descriptor_set,
//           dstBinding = 1,
//           descriptorType = .STORAGE_IMAGE,
//           descriptorCount = 1,
//           pImageInfo = &final_info,
//       },
//   }
//   vk.UpdateDescriptorSets(rb.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
//   // Add other writes for ubo, guis, bindless similar to raytrace
// }
// Update end_frame to submit post_blur after raytrace
end_frame :: proc(image_index: ^u32) {
present_info := vk.PresentInfoKHR{
sType = .PRESENT_INFO_KHR,
waitSemaphoreCount = 1,
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
return
case result == .SUCCESS:
case:
panic(fmt.tprintf("vulkan: present failure: %v", result))
}
// Compute raytrace
must(vk.WaitForFences(rb.device, 1, &rt.compute.fence, true, fence_timeout_ns))
must(vk.ResetFences(rb.device, 1, &rt.compute.fence))
compute_submit_info := vk.SubmitInfo{
sType = .SUBMIT_INFO,
commandBufferCount = 1,
pCommandBuffers = &rt.compute.command_buffer,
}
must(vk.QueueSubmit(rb.compute_queue, 1, &compute_submit_info, rt.compute.fence))
// ADDED: Post blur
must(vk.WaitForFences(rb.device, 1, &rt.post_blur.fence, true, fence_timeout_ns))
must(vk.ResetFences(rb.device, 1, &rt.post_blur.fence))
post_blur_submit_info := vk.SubmitInfo{
sType = .SUBMIT_INFO,
commandBufferCount = 1,
pCommandBuffers = &rt.post_blur.command_buffer,
}
must(vk.QueueSubmit(rb.compute_queue, 1, &post_blur_submit_info, rt.post_blur.fence))
current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}
// Update cleanup
cleanup :: proc() {
vk.DeviceWaitIdle(rb.device)
// ADDED: Destroy post_blur
vk.DestroyFence(rb.device, rt.post_blur.fence, nil)
vk.DestroyPipeline(rb.device, rt.post_blur.pipeline, nil)
vk.DestroyPipelineLayout(rb.device, rt.post_blur.pipeline_layout, nil)
vk.DestroyDescriptorSetLayout(rb.device, rt.post_blur.descriptor_set_layout, nil)
// Cleanup swapchain first
cleanup_swapchain()
// Destroy descriptor pool and layout before other resources
vk.DestroyDescriptorPool(rb.device, rt.descriptor_pool, nil)
vk.DestroyDescriptorSetLayout(rb.device, rt.graphics.descriptor_set_layout, nil)
// Now cleanup everything else including the device
cleanup_vulkan()
// Final cleanup of instance-level resources
destroy_vulkan()
}
// Update cleanup_swapchain_vulkan
cleanup_swapchain_vulkan :: proc() {
destroy_scene_and_final_images() // ADDED
}
// Update recreate_swapchain_vulkan
recreate_swapchain_vulkan :: proc() {
// Don't do anything when minimized.
for w, h := glfw.GetFramebufferSize(rb.window); w == 0 || h == 0; w, h = glfw.GetFramebufferSize(rb.window) {
glfw.WaitEvents()
}
vk.DeviceWaitIdle(rb.device)
cleanup_swapchain_vulkan()
create_swapchain()
create_depth_resources()
create_framebuffers()
// ADDED: Recreate scene and final images
create_scene_and_final_images()
// Update descriptors for new views
update_descriptors()
}