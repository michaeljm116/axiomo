// Ray Generation Main
// Mike Murrell (c) 8/27/2024
#ifndef DIFF_RAYGEN_GLSL
#define DIFF_RAYGEN_GLSL

#include "../structs.glsl"
#include "../layouts.glsl"

Ray generate_ray(in vec2 uv)
{
    vec3 ps;
    Ray ray;
    ps.x = (2 * uv.x - 1) * ubo.aspectRatio * ubo.fov;
    ps.y = (2 * uv.y - 1) * ubo.fov;
    ps.z = -1;
    ps = ps * mat3(ubo.rotM);
    ray.d = normalize(ps.xzy);
    ray.o = ubo.rotM[3].xyz; // * inverse(ubo.rotM)
    return ray;
}

vec4 check_gui(vec2 uv, in vec4 txt)
{
    for (int i = 0; i < guis.length(); ++i) {
    if(guis[i].alpha <= 0.f) continue;
    vec2 diff = uv - guis[i].min;
    if(diff.x < 0.f || diff.y < 0.f) continue;
    if(diff.x > guis[i].extents.x || diff.y > guis[i].extents.y) continue;
    vec2 guv = diff / guis[i].extents;
    guv.y = -guv.y;
    vec2 fin = guis[i].alignMin + guv * guis[i].alignExt;
    vec4 temp_txtr = texture(bindless_textures[nonuniformEXT(guis[i].id)], fin);
    txt += temp_txtr * temp_txtr.a;
    }
    return txt;
}

Ray[SAMPLES] main_rg(inout vec4 txtr, inout bool gui_hit)
{
    Ray rays[SAMPLES];
    ivec2 dim = imageSize(resultImage);
    vec2 pixel_uv = vec2(gl_GlobalInvocationID.xy) / vec2(dim);  // Pixel-center UV for GUI check (done once, not per sample)
    // Check GUI once with pixel UV
    txtr = check_gui(pixel_uv, vec4(0.0));  // Start from zero, as before
    if (txtr.a > 0.99f)
    {
        imageStore(resultImage, ivec2(gl_GlobalInvocationID.xy), txtr);
        gui_hit = true;
        return rays;  // Rays not needed
    }
    gui_hit = false;
    // Foveated rendering setup: Compute stride based on distance from center
    vec2 center = vec2(dim) / 2.0;
    vec2 pos = vec2(gl_GlobalInvocationID.xy);
    vec2 dpos = abs(pos - center);
    vec2 norm_dist = dpos / (vec2(dim) / 2.0);
    float dist = length(norm_dist);  // Elliptical distance (circular fovea adjusted for aspect ratio)
    int stride = 1;
    if (dist > 0.4) stride = 2;
    if (dist > 0.7) stride = 4;
    if (dist > 0.9) stride = 8;
    // Snap to center of super-pixel block for subsampling
    vec2 block_start = floor(pos / float(stride)) * float(stride);
    vec2 block_center_offset = vec2(float(stride) / 2.0);
    // Now generate rays for all samples using the foveated UV
    for (int samp = 0; samp < SAMPLES; ++samp) {
    vec2 jitter;
    if (SAMPLES == 1) {
        jitter = vec2(0.0);
    } else {
    // Scale jitter by stride to sample within the super-pixel (lower AA quality in periphery)
        jitter = SampleTable[samp] * float(stride);
    }
    // Sample position: center of block + scaled jitter
    vec2 sample_pos = block_start + block_center_offset + jitter - 0.5;  // -0.5 for subpixel alignment
    vec2 uv = sample_pos / vec2(dim);
    rays[samp] = generate_ray(uv);
    }
    return rays;
}
#endif
