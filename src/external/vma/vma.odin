package vma

import vk "vendor:vulkan"

@(require)import c "core:c"

STATS_STRING_ENABLED :: 1
VULKAN_VERSION :: 1002000
DEDICATED_ALLOCATION :: 1
BIND_MEMORY2 :: 1
MEMORY_BUDGET :: 1
BUFFER_DEVICE_ADDRESS :: 1
MEMORY_PRIORITY :: 1
EXTERNAL_MEMORY :: 1

Handle :: distinct rawptr
NonDispatchableHandle :: distinct u64

Pool :: distinct Handle
Allocation :: distinct Handle
Allocator :: distinct Handle
DefragmentationContext :: distinct Handle

VirtualAllocation :: distinct Handle

VirtualBlock :: distinct Handle

AllocatorCreateFlags :: distinct bit_set[AllocatorCreateFlagBit;u32]

AllocatorCreateFlagBit :: enum u32 {
	EXTERNALLY_SYNCHRONIZED    = 0,
	KHR_DEDICATED_ALLOCATION   = 1,
	KHR_BIND_MEMORY2           = 2,
	EXT_MEMORY_BUDGET          = 3,
	AMD_DEVICE_COHERENT_MEMORY = 4,
	BUFFER_DEVICE_ADDRESS      = 5,
	EXT_MEMORY_PRIORITY        = 6,
}

MemoryUsage :: enum u32 {
	UNKNOWN              = 0,
	GPU_ONLY             = 1,
	CPU_ONLY             = 2,
	CPU_TO_GPU           = 3,
	GPU_TO_CPU           = 4,
	CPU_COPY             = 5,
	GPU_LAZILY_ALLOCATED = 6,
	AUTO                 = 7,
	AUTO_PREFER_DEVICE   = 8,
	AUTO_PREFER_HOST     = 9,
}

AllocationCreateFlags :: distinct bit_set[AllocationCreateFlagBit;u32]


AllocationCreateFlagBit :: enum u32 {
	DEDICATED_MEMORY                   = 0,
	NEVER_ALLOCATE                     = 1,
	MAPPED                             = 2,
	USER_DATA_COPY_STRING              = 5,
	UPPER_ADDRESS                      = 6,
	DONT_BIND                          = 7,
	WITHIN_BUDGET                      = 8,
	CAN_ALIAS                          = 9,
	HOST_ACCESS_SEQUENTIAL_WRITE       = 10,
	HOST_ACCESS_RANDOM                 = 11,
	HOST_ACCESS_ALLOW_TRANSFER_INSTEAD = 12,
	STRATEGY_MIN_MEMORY                = 16,
	STRATEGY_MIN_TIME                  = 17,
	STRATEGY_MIN_OFFSET                = 18,
	STRATEGY_BEST_FIT                  = STRATEGY_MIN_MEMORY,
	STRATEGY_FIRST_FIT                 = STRATEGY_MIN_TIME,
	STRATEGY_MASK                      = STRATEGY_MIN_MEMORY | STRATEGY_MIN_TIME | STRATEGY_MIN_OFFSET,
}

PoolCreateFlags :: distinct bit_set[PoolCreateFlagBit;u32]

PoolCreateFlagBit :: enum u32 {
	IGNORE_BUFFER_IMAGE_GRANULARITY = 1,
	LINEAR_ALGORITHM                = 2,
	ALGORITHM_MASK                  = LINEAR_ALGORITHM,
}

DefragmentationFlags :: distinct bit_set[DefragmentationFlagBit;u32]


DefragmentationFlagBit :: enum u32 {
	ALGORITHM_FAST      = 0,
	ALGORITHM_BALANCED  = 1,
	ALGORITHM_FULL      = 2,
	ALGORITHM_EXTENSIVE = 3,
	ALGORITHM_MASK      = ALGORITHM_FAST | ALGORITHM_BALANCED | ALGORITHM_FULL | ALGORITHM_EXTENSIVE,
}

DefragmentationMoveOperation :: enum u32 {
	COPY    = 0,
	IGNORE  = 1,
	DESTROY = 2,
}

VirtualBlockCreateFlags :: distinct bit_set[VirtualBlockCreateFlagBit;u32]

VirtualBlockCreateFlagBit :: enum u32 {
	LINEAR_ALGORITHM = 1,
	ALGORITHM_MASK   = LINEAR_ALGORITHM,
}


VirtualAllocationCreateFlags :: distinct bit_set[VirtualAllocationCreateFlagBit;u32]

VirtualAllocationCreateFlagBit :: enum u32 {
	UPPER_ADDRESS       = 7,
	STRATEGY_MIN_MEMORY = 17,
	STRATEGY_MIN_TIME   = 18,
	STRATEGY_MIN_OFFSET = 19,
	STRATEGY_MASK       = STRATEGY_MIN_MEMORY | STRATEGY_MIN_TIME | STRATEGY_MIN_OFFSET,
}

DeviceMemoryCallbacks :: struct {
	pfnAllocate: PFN_vmaAllocateDeviceMemoryFunction,
	pfnFree:     PFN_vmaFreeDeviceMemoryFunction,
	pUserData:   rawptr,
}

VulkanFunctions :: struct {
	unused_1:                              proc(), //vkGetInstanceProcAddr
	unused_2:                              proc(), //vkGetDeviceProcAddr
	GetPhysicalDeviceProperties:           vk.ProcGetPhysicalDeviceProperties,
	GetPhysicalDeviceMemoryProperties:     vk.ProcGetPhysicalDeviceMemoryProperties,
	AllocateMemory:                        vk.ProcAllocateMemory,
	FreeMemory:                            vk.ProcFreeMemory,
	MapMemory:                             vk.ProcMapMemory,
	UnmapMemory:                           vk.ProcUnmapMemory,
	FlushMappedMemoryRanges:               vk.ProcFlushMappedMemoryRanges,
	InvalidateMappedMemoryRanges:          vk.ProcInvalidateMappedMemoryRanges,
	BindBufferMemory:                      vk.ProcBindBufferMemory,
	BindImageMemory:                       vk.ProcBindImageMemory,
	GetBufferMemoryRequirements:           vk.ProcGetBufferMemoryRequirements,
	GetImageMemoryRequirements:            vk.ProcGetImageMemoryRequirements,
	CreateBuffer:                          vk.ProcCreateBuffer,
	DestroyBuffer:                         vk.ProcDestroyBuffer,
	CreateImage:                           vk.ProcCreateImage,
	DestroyImage:                          vk.ProcDestroyImage,
	CmdCopyBuffer:                         vk.ProcCmdCopyBuffer,
	GetBufferMemoryRequirements2KHR:       vk.ProcGetBufferMemoryRequirements2KHR,
	GetImageMemoryRequirements2KHR:        vk.ProcGetImageMemoryRequirements2KHR,
	BindBufferMemory2KHR:                  vk.ProcBindBufferMemory2KHR,
	BindImageMemory2KHR:                   vk.ProcBindImageMemory2KHR,
	GetPhysicalDeviceMemoryProperties2KHR: vk.ProcGetPhysicalDeviceMemoryProperties2KHR,
}

AllocatorCreateInfo :: struct {
	flags:                          AllocatorCreateFlags,
	physicalDevice:                 vk.PhysicalDevice,
	device:                         vk.Device,
	preferredLargeHeapBlockSize:    vk.DeviceSize,
	pAllocationCallbacks:           ^vk.AllocationCallbacks,
	pDeviceMemoryCallbacks:         ^DeviceMemoryCallbacks,
	pHeapSizeLimit:                 ^vk.DeviceSize,
	pVulkanFunctions:               ^VulkanFunctions,
	instance:                       vk.Instance,
	vulkanApiVersion:               u32,
	pTypeExternalMemoryHandleTypes: ^vk.ExternalMemoryHandleTypeFlagsKHR,
}

AllocatorInfo :: struct {
	instance:       vk.Instance,
	physicalDevice: vk.PhysicalDevice,
	device:         vk.Device,
}

Statistics :: struct {
	blockCount:      u32,
	allocationCount: u32,
	blockBytes:      vk.DeviceSize,
	allocationBytes: vk.DeviceSize,
}

DetailedStatistics :: struct {
	statistics:         Statistics,
	unusedRangeCount:   u32,
	allocationSizeMin:  vk.DeviceSize,
	allocationSizeMax:  vk.DeviceSize,
	unusedRangeSizeMin: vk.DeviceSize,
	unusedRangeSizeMax: vk.DeviceSize,
}

TotalStatistics :: struct {
	memoryType: [32]DetailedStatistics,
	memoryHeap: [16]DetailedStatistics,
	total:      DetailedStatistics,
}

Budget :: struct {
	statistics: Statistics,
	usage:      vk.DeviceSize,
	budget:     vk.DeviceSize,
}

AllocationCreateInfo :: struct {
	flags:          AllocationCreateFlags,
	usage:          MemoryUsage,
	requiredFlags:  vk.MemoryPropertyFlags,
	preferredFlags: vk.MemoryPropertyFlags,
	memoryTypeBits: u32,
	pool:           Pool,
	pUserData:      rawptr,
	priority:       f32,
}

PoolCreateInfo :: struct {
	memoryTypeIndex:        u32,
	flags:                  PoolCreateFlags,
	blockSize:              vk.DeviceSize,
	minBlockCount:          uint,
	maxBlockCount:          uint,
	priority:               f32,
	minAllocationAlignment: vk.DeviceSize,
	pMemoryAllocateNext:    rawptr,
}

AllocationInfo :: struct {
	memoryType:   u32,
	deviceMemory: vk.DeviceMemory,
	offset:       vk.DeviceSize,
	size:         vk.DeviceSize,
	pMappedData:  rawptr,
	pUserData:    rawptr,
	pName:        cstring,
}

DefragmentationInfo :: struct {
	flags:                 DefragmentationFlags,
	pool:                  Pool,
	maxBytesPerPass:       vk.DeviceSize,
	maxAllocationsPerPass: u32,
}

DefragmentationMove :: struct {
	operation:        DefragmentationMoveOperation,
	srcAllocation:    Allocation,
	dstTmpAllocation: Allocation,
}

DefragmentationPassMoveInfo :: struct {
	moveCount: u32,
	pMoves:    ^DefragmentationMove,
}

DefragmentationStats :: struct {
	bytesMoved:              vk.DeviceSize,
	bytesFreed:              vk.DeviceSize,
	allocationsMoved:        u32,
	deviceMemoryBlocksFreed: u32,
}

VirtualBlockCreateInfo :: struct {
	size:                 vk.DeviceSize,
	flags:                VirtualBlockCreateFlags,
	pAllocationCallbacks: ^vk.AllocationCallbacks,
}

VirtualAllocationCreateInfo :: struct {
	size:      vk.DeviceSize,
	alignment: vk.DeviceSize,
	flags:     VirtualAllocationCreateFlags,
	pUserData: rawptr,
}

VirtualAllocationInfo :: struct {
	offset:    vk.DeviceSize,
	size:      vk.DeviceSize,
	pUserData: rawptr,
}

PFN_vmaAllocateDeviceMemoryFunction :: proc "c" (
	allocator: Allocator,
	memoryType: u32,
	memory: vk.DeviceMemory,
	size: vk.DeviceSize,
	pUserData: rawptr,
)
PFN_vmaFreeDeviceMemoryFunction :: proc "c" (
	allocator: Allocator,
	memoryType: u32,
	memory: vk.DeviceMemory,
	size: vk.DeviceSize,
	pUserData: rawptr,
)

when ODIN_OS == .Windows do foreign import VulkanMemoryAllocator "lib/VulkanMemoryAllocator.lib"
when ODIN_OS == .Linux do @(extra_linker_flags="-lstdc++") foreign import VulkanMemoryAllocator "lib/libVulkanMemoryAllocator.a"

create_vulkan_functions :: proc() -> VulkanFunctions {
	return(
		{
			AllocateMemory = vk.AllocateMemory,
			BindBufferMemory = vk.BindBufferMemory,
			BindBufferMemory2KHR = vk.BindBufferMemory2,
			BindImageMemory = vk.BindImageMemory,
			BindImageMemory2KHR = vk.BindImageMemory2,
			CmdCopyBuffer = vk.CmdCopyBuffer,
			CreateBuffer = vk.CreateBuffer,
			CreateImage = vk.CreateImage,
			DestroyBuffer = vk.DestroyBuffer,
			DestroyImage = vk.DestroyImage,
			FlushMappedMemoryRanges = vk.FlushMappedMemoryRanges,
			FreeMemory = vk.FreeMemory,
			GetBufferMemoryRequirements = vk.GetBufferMemoryRequirements,
			GetBufferMemoryRequirements2KHR = vk.GetBufferMemoryRequirements2,
			GetImageMemoryRequirements = vk.GetImageMemoryRequirements,
			GetImageMemoryRequirements2KHR = vk.GetImageMemoryRequirements2,
			GetPhysicalDeviceMemoryProperties = vk.GetPhysicalDeviceMemoryProperties,
			GetPhysicalDeviceMemoryProperties2KHR = vk.GetPhysicalDeviceMemoryProperties2,
			GetPhysicalDeviceProperties = vk.GetPhysicalDeviceProperties,
			InvalidateMappedMemoryRanges = vk.InvalidateMappedMemoryRanges,
			MapMemory = vk.MapMemory,
			UnmapMemory = vk.UnmapMemory,
		} \
	)
}

@(default_calling_convention = "c", link_prefix = "vma")
foreign VulkanMemoryAllocator {
	CreateAllocator :: proc(pCreateInfo: ^AllocatorCreateInfo, pAllocator: ^Allocator) -> vk.Result ---
	DestroyAllocator :: proc(allocator: Allocator) ---
	GetAllocatorInfo :: proc(allocator: Allocator, pAllocatorInfo: ^AllocatorInfo) ---
	GetPhysicalDeviceProperties :: proc(allocator: Allocator, ppPhysicalDeviceProperties: ^^vk.PhysicalDeviceProperties) ---
	GetMemoryProperties :: proc(allocator: Allocator, ppPhysicalDeviceMemoryProperties: ^^vk.PhysicalDeviceMemoryProperties) ---
	GetMemoryTypeProperties :: proc(allocator: Allocator, memoryTypeIndex: u32, pFlags: ^vk.MemoryPropertyFlags) ---
	SetCurrentFrameIndex :: proc(allocator: Allocator, frameIndex: u32) ---
	CalculateStatistics :: proc(allocator: Allocator, pStats: ^TotalStatistics) ---
	GetHeapBudgets :: proc(allocator: Allocator, pBudgets: ^Budget) ---
	FindMemoryTypeIndex :: proc(allocator: Allocator, memoryTypeBits: u32, pAllocationCreateInfo: ^AllocationCreateInfo, pMemoryTypeIndex: ^u32) -> vk.Result ---
	FindMemoryTypeIndexForBufferInfo :: proc(allocator: Allocator, pBufferCreateInfo: ^vk.BufferCreateInfo, pAllocationCreateInfo: ^AllocationCreateInfo, pMemoryTypeIndex: ^u32) -> vk.Result ---
	FindMemoryTypeIndexForImageInfo :: proc(allocator: Allocator, pImageCreateInfo: ^vk.ImageCreateInfo, pAllocationCreateInfo: ^AllocationCreateInfo, pMemoryTypeIndex: ^u32) -> vk.Result ---
	CreatePool :: proc(allocator: Allocator, pCreateInfo: ^PoolCreateInfo, pPool: ^Pool) -> vk.Result ---
	DestroyPool :: proc(allocator: Allocator, pool: Pool) ---
	GetPoolStatistics :: proc(allocator: Allocator, pool: Pool, pPoolStats: ^Statistics) ---
	CalculatePoolStatistics :: proc(allocator: Allocator, pool: Pool, pPoolStats: ^DetailedStatistics) ---
	CheckPoolCorruption :: proc(allocator: Allocator, pool: Pool) -> vk.Result ---
	GetPoolName :: proc(allocator: Allocator, pool: Pool, ppName: ^cstring) ---
	SetPoolName :: proc(allocator: Allocator, pool: Pool, pName: cstring) ---
	AllocateMemory :: proc(allocator: Allocator, pVkMemoryRequirements: ^vk.MemoryRequirements, pCreateInfo: ^AllocationCreateInfo, pAllocation: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	AllocateMemoryPages :: proc(allocator: Allocator, pVkMemoryRequirements: ^vk.MemoryRequirements, pCreateInfo: ^AllocationCreateInfo, allocationCount: uint, pAllocations: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	AllocateMemoryForBuffer :: proc(allocator: Allocator, buffer: vk.Buffer, pCreateInfo: ^AllocationCreateInfo, pAllocation: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	AllocateMemoryForImage :: proc(allocator: Allocator, image: vk.Image, pCreateInfo: ^AllocationCreateInfo, pAllocation: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	FreeMemory :: proc(allocator: Allocator, allocation: Allocation) ---
	FreeMemoryPages :: proc(allocator: Allocator, allocationCount: uint, pAllocations: ^Allocation) ---
	GetAllocationInfo :: proc(allocator: Allocator, allocation: Allocation, pAllocationInfo: ^AllocationInfo) ---
	SetAllocationUserData :: proc(allocator: Allocator, allocation: Allocation, pUserData: rawptr) ---
	SetAllocationName :: proc(allocator: Allocator, allocation: Allocation, pName: cstring) ---
	GetAllocationMemoryProperties :: proc(allocator: Allocator, allocation: Allocation, pFlags: ^vk.MemoryPropertyFlags) ---
	MapMemory :: proc(allocator: Allocator, allocation: Allocation, ppData: ^rawptr) -> vk.Result ---
	UnmapMemory :: proc(allocator: Allocator, allocation: Allocation) ---
	FlushAllocation :: proc(allocator: Allocator, allocation: Allocation, offset: vk.DeviceSize, size: vk.DeviceSize) -> vk.Result ---
	InvalidateAllocation :: proc(allocator: Allocator, allocation: Allocation, offset: vk.DeviceSize, size: vk.DeviceSize) -> vk.Result ---
	FlushAllocations :: proc(allocator: Allocator, allocationCount: u32, allocations: ^Allocation, offsets: ^vk.DeviceSize, sizes: ^vk.DeviceSize) -> vk.Result ---
	InvalidateAllocations :: proc(allocator: Allocator, allocationCount: u32, allocations: ^Allocation, offsets: ^vk.DeviceSize, sizes: ^vk.DeviceSize) -> vk.Result ---
	CheckCorruption :: proc(allocator: Allocator, memoryTypeBits: u32) -> vk.Result ---
	BeginDefragmentation :: proc(allocator: Allocator, pInfo: ^DefragmentationInfo, pContext: ^DefragmentationContext) -> vk.Result ---
	EndDefragmentation :: proc(allocator: Allocator, context_: DefragmentationContext, pStats: ^DefragmentationStats) ---
	BeginDefragmentationPass :: proc(allocator: Allocator, context_: DefragmentationContext, pPassInfo: ^DefragmentationPassMoveInfo) -> vk.Result ---
	EndDefragmentationPass :: proc(allocator: Allocator, context_: DefragmentationContext, pPassInfo: ^DefragmentationPassMoveInfo) -> vk.Result ---
	BindBufferMemory :: proc(allocator: Allocator, allocation: Allocation, buffer: vk.Buffer) -> vk.Result ---
	BindBufferMemory2 :: proc(allocator: Allocator, allocation: Allocation, allocationLocalOffset: vk.DeviceSize, buffer: vk.Buffer, pNext: rawptr) -> vk.Result ---
	BindImageMemory :: proc(allocator: Allocator, allocation: Allocation, image: vk.Image) -> vk.Result ---
	BindImageMemory2 :: proc(allocator: Allocator, allocation: Allocation, allocationLocalOffset: vk.DeviceSize, image: vk.Image, pNext: rawptr) -> vk.Result ---
	CreateBuffer :: proc(allocator: Allocator, pBufferCreateInfo: ^vk.BufferCreateInfo, pAllocationCreateInfo: ^AllocationCreateInfo, pBuffer: ^vk.Buffer, pAllocation: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	CreateBufferWithAlignment :: proc(allocator: Allocator, pBufferCreateInfo: ^vk.BufferCreateInfo, pAllocationCreateInfo: ^AllocationCreateInfo, minAlignment: vk.DeviceSize, pBuffer: ^vk.Buffer, pAllocation: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	CreateAliasingBuffer :: proc(allocator: Allocator, allocation: Allocation, pBufferCreateInfo: ^vk.BufferCreateInfo, pBuffer: ^vk.Buffer) -> vk.Result ---
	DestroyBuffer :: proc(allocator: Allocator, buffer: vk.Buffer, allocation: Allocation) ---
	CreateImage :: proc(allocator: Allocator, pImageCreateInfo: ^vk.ImageCreateInfo, pAllocationCreateInfo: ^AllocationCreateInfo, pImage: ^vk.Image, pAllocation: ^Allocation, pAllocationInfo: ^AllocationInfo) -> vk.Result ---
	CreateAliasingImage :: proc(allocator: Allocator, allocation: Allocation, pImageCreateInfo: ^vk.ImageCreateInfo, pImage: ^vk.Image) -> vk.Result ---
	DestroyImage :: proc(allocator: Allocator, image: vk.Image, allocation: Allocation) ---
	CreateVirtualBlock :: proc(pCreateInfo: ^VirtualBlockCreateInfo, pVirtualBlock: ^VirtualBlock) -> vk.Result ---
	DestroyVirtualBlock :: proc(virtualBlock: VirtualBlock) ---
	IsVirtualBlockEmpty :: proc(virtualBlock: VirtualBlock) -> c.bool ---
	GetVirtualAllocationInfo :: proc(virtualBlock: VirtualBlock, allocation: VirtualAllocation, pVirtualAllocInfo: ^VirtualAllocationInfo) ---
	VirtualAllocate :: proc(virtualBlock: VirtualBlock, pCreateInfo: ^VirtualAllocationCreateInfo, pAllocation: ^VirtualAllocation, pOffset: ^vk.DeviceSize) -> vk.Result ---
	VirtualFree :: proc(virtualBlock: VirtualBlock, allocation: VirtualAllocation) ---
	ClearVirtualBlock :: proc(virtualBlock: VirtualBlock) ---
	SetVirtualAllocationUserData :: proc(virtualBlock: VirtualBlock, allocation: VirtualAllocation, pUserData: rawptr) ---
	GetVirtualBlockStatistics :: proc(virtualBlock: VirtualBlock, pStats: ^Statistics) ---
	CalculateVirtualBlockStatistics :: proc(virtualBlock: VirtualBlock, pStats: ^DetailedStatistics) ---
	BuildVirtualBlockStatsString :: proc(virtualBlock: VirtualBlock, ppStatsString: ^cstring, detailedMap:  c.bool) ---
	FreeVirtualBlockStatsString :: proc(virtualBlock: VirtualBlock, pStatsString: cstring) ---
	BuildStatsString :: proc(allocator: Allocator, ppStatsString: ^cstring, detailedMap:  c.bool) ---
	FreeStatsString :: proc(allocator: Allocator, pStatsString: cstring) ---
}