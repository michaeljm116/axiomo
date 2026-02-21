# Axiomo Shaders - Agent Guidelines

This file contains guidelines for AI agents working on the Axiomo shader codebase (GLSL/Vulkan compute shaders).

## Build Commands

### Compiling Shaders
```bash
# Compile the main raytracing compute shader
./raytraceCompile.bat

# Or manually with glslangValidator:
glslangvalidator -V raytrace-main.comp -o raytracing.comp.spv
```

### Shader Output Locations
- `raytracing.comp.spv` - Main raytracing compute shader
- `raytrace_fov.comp.spv` - Foveated rendering variant
- Other `.spv` files in root are legacy/utility shaders

## Project Structure

```
assets/shaders/
├── raytrace-main.comp      # Main compute shader entry point
├── raytraceCompile.bat    # Compilation script
├── rt/                    # Raytracing modules
│   ├── structs.glsl       # Data structures (Ray, BVHNode, Primitive, etc.)
│   ├── constants.glsl     # Constants and configuration
│   ├── layouts.glsl       # Buffer/image layouts
│   ├── ray_gen/           # Ray generation kernels
│   │   ├── main-rg.glsl
│   │   └── foveated-rg.glsl
│   ├── intersect/         # Intersection routines
│   │   ├── main-intersect.glsl
│   │   ├── shapes.glsl
│   │   ├── traverse.glsl
│   │   ├── bvh.glsl
│   │   ├── mesh.glsl
│   │   └── helpers.glsl
│   ├── hit/               # Hit processing
│   │   ├── basic-chit.glsl
│   │   ├── pbr.glsl
│   │   └── normals.glsl
│   └── post_proc/         # Post-processing
│       └── post-blur.comp
├── texture.vert/frag      # Texturing shaders
└── shader.vert/frag      # Legacy rendering shaders
```

## Code Style Guidelines

### Naming Conventions
- **Structs**: `PascalCase` (e.g., `Ray`, `BVHNode`, `Primitive`)
- **Procedures/Functions**: `snake_case` (e.g., `ray_intersect_sphere`, `compute_normal`)
- **Constants/Defines**: `UPPER_SNAKE_CASE` (e.g., `MAXLEN`, `RAYBOUNCES`)
- **Uniforms/Globals**: `lowercase` (e.g., `ubo`, `scratch`)
- **Macros**: `UPPER_SNAKE_CASE` with `#define`

### Shader Organization
```glsl
#version 450

#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable
#extension GL_GOOGLE_include_directive : enable
#extension GL_EXT_nonuniform_qualifier : enable

// Workgroup size
layout(local_size_x = 16, local_size_y = 16) in;

// Images and Buffers
layout(binding = 0, rgba8) uniform writeonly image2D resultImage;

// Constants
#define EPSILON 0.0001
#define MAXLEN 1000.0

// Includes (use GL_GOOGLE_include_directive)
#include "rt/structs.glsl"
#include "rt/constants.glsl"

// Main shader logic
void main() {
    // ...
}
```

### Include System
- Use `#include "path"` with `GL_GOOGLE_include_directive`
- Include guards in each file: `#ifndef _FILENAME_GLSL` / `#define _FILENAME_GLSL` / `#endif`
- Order: structs → constants → helpers → main logic

### Layout Bindings
| Binding | Type | Description |
|---------|------|-------------|
| 0 | image2D | Result image (writeonly) |
| 1-10 | Uniform | UBOs (camera, scene, lights) |
| 11-20 | Buffer | Device addresses (BVH, primitives) |

### Data Structures (from rt/structs.glsl)

```glsl
struct Ray {
    vec3 o;    // Origin
    float t;   // Current t (distance)
    vec3 d;    // Direction
    float t2;  // Secondary t for volumes
};

struct BVHNode {
    vec3 upper;
    int offset;
    vec3 lower;
    int numChildren;
};

struct Primitive {
    mat4 world;
    vec3 extents;
    int numChildren;
    int id;
    int matID;
    int startIndex;
    int endIndex;
};

struct Vert {
    vec3 pos;
    float u;
    vec3 norm;
    float v;
};
```

### Best Practices

1. **Precision**: Use `float` for positions, `highp` for critical calculations
2. **Avoid branching**: Use step/mix instead of if-else in hot paths
3. **Coalesce memory accesses**: Process data in workgroup-sized chunks
4. **Avoid texture in ray generation**: Use compute shader outputs instead
5. **Fresnel**: Implement with Schlick's approximation for performance

### Feature Flags
Defined at top of `raytrace-main.comp`:
```glsl
#define USE_EMBREE          // Use Embree integration
#define REFLECTIONS         // Enable reflections
#define RAYBOUNCES 4        // Max reflection bounces
#define DEBUGLINES          // Enable debug output (commented)
```

### Common Patterns

**Ray Generation**:
```glsl
void main() {
    uvec2 pixel = gl_GlobalInvocationID.xy;
    if (pixel.x >= ubo.width || pixel.y >= ubo.height) return;
    
    vec2 uv = (vec2(pixel) + 0.5) / vec2(ubo.width, ubo.height);
    Ray ray = generate_ray(uv, ubo.camera);
    // ...
}
```

**Intersection Loop**:
```glsl
for (int i = 0; i < scene.numPrimitives; i++) {
    Primitive prim = primitives[i];
    intersect_primitive(ray, prim);
}
```

### Debugging Tips
- Enable `DEBUGLINES` define for verbose output
- Use `#ifdef DEBUG` blocks for development-only code
- Write debug info to image alpha channel
- Check validation layer errors in Vulkan

## Important Notes

- Shaders use Vulkan compute model (`#version 450`)
- Uses `GL_GOOGLE_include_directive` for modular includes
- Embree integration for BVH acceleration (`#define USE_EMBREE`)
- Foveated rendering available via `rt/ray_gen/foveated-rg.glsl`
- Post-processing via `rt/post_proc/post-blur.comp`

## Common Pitfalls

- Don't forget `#version 450` at top of every file
- Don't use `gl_LocalInvocationID` before defining `local_size_x/y`
- Don't forget image layout qualifiers (`readonly`, `writeonly`)
- Don't use `sampler2D` in compute shaders - use textures as images
- Don't forget to match buffer layouts between Odin and GLSL
