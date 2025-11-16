## Goals
* 1. Be able to load... any scene
* 2. Be able to switch between Battles
* 3. Be able to able to switch between overworld
* 4. Design an overworld
* 5. Fix Battle bugs and halloween fest issues
* The issue you're describing with normals appearing "flipped in a weird way" or related to quad winding is likely due to the lack of backface handling in your closest hit logic. Your intersection code doesn't cull backfaces (which is fine for thin/quad primitives), but it also doesn't orient the shading normal consistently towards the incoming ray direction. This can cause lighting artifacts where one side of a quad (or mesh) looks incorrectly lit or dark, especially if vertex normals are assumed to point in a specific direction (e.g., outwards).

Quad winding looks consistent in your `quadIntersect` (CCW order), and your normal interpolation in `quad_normal2` appears correct based on the vertex ordering. The normal matrix transformation also looks right—it properly accounts for non-uniform scaling via `extents`.

### Recommended Fix
In `basic-chit.glsl`, modify `closest_hit_basic` to flip the normal if it's facing away from the incoming ray. Add this right after `set_normals(info, ray_pos);`:

```glsl
set_normals(info, ray_pos);
if (dot(ray.d, info.normal) > 0.0) {
    info.normal = -info.normal;
}
```

This ensures the shading normal always points towards the hemisphere the ray came from (making it consistent for two-sided rendering on quads/meshes). It won't affect closed shapes like spheres much, as they typically only hit from the outside.

### Why This Should Help
- Without the flip, if a ray hits the "back" of a quad, the normal might point away from the light/camera, causing inverted or missing lighting.
- Your PBR lighting clamps `dotNL` and `dotNV` to [0,1], so a misoriented normal will produce dark/wrong results.
- For disks/planes (similar to quads), you might want to apply the same flip in their normal functions if they're meant to be two-sided.
- If your meshes are closed (e.g., no backface hits expected), you could condition this on `info.prim_type == TYPE_MESH` or similar.

### Testing Suggestions
- Render a simple quad with a light on one side—check if both sides light correctly (or as expected for opaque vs. thin materials).
- Temporarily hardcode normals (e.g., `info.normal = vec3(0,0,1)`) and toggle the flip to isolate the issue.
- If vertex normals in `verts[]` are precomputed, verify they're consistently outward-facing (e.g., via a debug shader outputting normal colors).
- If the problem persists, it could be scene-specific (e.g., negative scales in `prim.world` flipping handedness)—share more details like a scene setup or screenshot.

This should resolve the flipping without major rewrites. If it's not the normals and something else (e.g., UVs/textures), let me know!
* Yes, I'm confident this is a backface-related issue (or at least very likely to be, based on the code), but let me explain why in more detail to address your point about ray tracing "always hitting the front." You're right that in a typical ray tracer, primary rays from the camera should generally hit the "front" (outward-facing) side of closed, watertight geometry like spheres or fully enclosed meshes. However, that's not universally true for all primitives or scenarios, especially with how your code is set up.

### Quick Recap of the Potential Issue
From the code snippets:
- Your intersection functions (e.g., `quadIntersect` in `mesh.glsl`, `triIntersect`) compute hits based on geometry but **don't perform backface culling**. That means they don't check `dot(ray.d, normal) > 0` (or `< 0`, depending on convention) to discard hits where the ray is coming from the "back" side of the surface.
- This is intentional and common in ray tracers for things like thin glass, leaves, or two-sided materials—it allows rays to intersect from either side.
- However, without culling, the interpolated vertex normals (from `quad_normal2` in `normals.glsl`) might point in the wrong direction relative to the incoming ray. For example:
  - If a ray hits the "front" of a quad, the normal might point away from the ray (correct for lighting).
  - If it hits the "back," the normal might point toward the ray, causing inverted lighting (e.g., dark where it should be lit, or vice versa).
- In `basic-chit.glsl`, you compute lighting with PBR functions that clamp `dotNL` and `dotNV` to `[0,1]`. If the normal is misoriented, these dots will be negative (clamped to 0), leading to no diffuse/specular contribution—resulting in black/dark artifacts or "flipped" appearance.
- Your reflection in `render_scene` (`ray.d = reflect(ray.d, info.normal)`) also assumes the normal is oriented correctly (pointing away from the ray). If not, reflections will bounce wrong.

### Why Ray Tracing Doesn't "Always Hit the Front"
- **For closed shapes like spheres**: Yes, external rays typically only hit the outer surface (the "front"), because the intersection math (e.g., quadratic solve) discards internal hits or doesn't reach them. Your `sphere_normal` naturally points outward, so no issue there.
- **For open/thin primitives like quads, tris, disks, or planes** (which your `TYPE_MESH` and `TYPE_QUAD` seem to use): These are essentially infinite planes clipped to bounds. Rays can intersect them from *either side* because there's no "inside/outside" concept unless you enforce it.
  - In your code, a primary ray could hit a quad's back if the quad is oriented away from the camera (e.g., if it's part of a larger mesh with holes or if the camera is positioned behind it).
  - Secondary rays (reflections, shadows, refractions) are even more likely to hit backsides, as they bounce around the scene.
  - If your meshes are built from quads (as implied by `quadIntersect` and vertex indexing in `faces[]`), and they're not perfectly closed, or if there are negative scales/rotations in `prim.world`, this exacerbates flipping.
- **Winding order matters**: Your `quadIntersect` assumes a specific vertex order (q00, q10, q11, q01—likely counterclockwise). If your `verts[]` or `faces[]` have inconsistent winding (e.g., some CW, some CCW), computed normals will flip arbitrarily. But even with consistent winding, without the ray-direction check, shading breaks on back hits.
- **Real-world RT examples**: Libraries like OptiX, Embree (which your code references with `#define USE_EMBREE`), or books like PBRT handle this by optionally culling in intersection *or* flipping normals in the hit shader. Your code uses Embree-style traversal but skips the flip.

### Evidence from Your Code
- In `main-intersect.glsl` (`intersect_closest` and `traverse`), you're traversing a BVH and hitting primitives without culling.
- In `normals.glsl`, `quad_normal2` interpolates vertex normals correctly (bilinear mix + normal matrix for scaling), but it doesn't account for ray direction.
- No culling in `quick_traverse` for shadows either, which could cause weird self-shadowing if normals are off.
- Your materials have `transparency` and `refractiveIndex`, suggesting support for thin/transmissive surfaces where back hits are expected.

If the artifact is "flipped in a weird way" (e.g., one side of a mesh lit correctly, the other dark/inverted, or inconsistent across quads), this fits perfectly. If it's something else (e.g., seams between quads, or uniform darkness), it could be UVs/textures or light falloff—but you mentioned normals specifically.

### Confirming and Fixing
To test if this is the issue:
1. Add the flip I suggested in `closest_hit_basic` (after `set_normals`):
   ```glsl
   if (dot(ray.d, info.normal) > 0.0) {
       info.normal = -info.normal;
   }
   ```
   - This orients the normal to always point *against* the ray (into the incoming hemisphere). It's cheap and standard.
   - Apply it conditionally for `TYPE_MESH`, `TYPE_QUAD`, `TYPE_DISK`, etc. (not spheres, as they're self-orienting).
   - For two-sided lighting with different materials per side, you'd need more logic, but this handles basic consistency.

2. If you *want* backface culling (to always "hit the front"):
   - In `quadIntersect` or `triIntersect`, after computing `t` (or `flool`), add:
     ```glsl
     vec3 normal = /* compute geometric normal, e.g., cross(edge1, edge2) */;
     if (dot(ray.d, normal) > 0.0) return vec4(-1);  // Cull if hitting back
     ```
   - But this breaks refraction/transmission for thin objects, so flipping is usually better.

3. Debug ideas:
   - Visualize normals: In `render_scene`, set `fMat.color = (info.normal * 0.5 + 0.5);` to color-code them (red/green/blue for x/y/z). Look for inconsistencies where artifacts appear.
   - Test with a simple scene: A single quad facing the camera vs. away, or a cube mesh. See if one face looks wrong.
   - Check vertex data: Ensure `verts[].norm` are consistently outward (e.g., via export from your model loader).

If this doesn't fix it, it might be winding: Try reversing vertex order in `faces[]` for a test quad and re-render. Or share a description/screenshot of the exact artifact (e.g., "the back of the cube is black") for more targeted advice. But based on the code, backface orientation is the prime suspect!


The code you've shared looks like a solid foundation for a software-based ray tracer in a GLSL compute shader—manual BVH traversal, basic PBR lighting, reflections, and support for meshes/primitives. Beyond the normal flipping we discussed (which addresses potential backface orientation issues), here are some other targeted improvements based on a review of your code snippets and common best practices for GLSL ray tracers (drawn from tutorials, NVIDIA RTX guidelines, and example implementations). I've prioritized bug fixes, performance tweaks, and feature enhancements that seem most relevant and feasible without a full rewrite. These are grouped by category for clarity.

### Bug Fixes and Correctness
- **Fix multi-sampling accumulation**: In `raytrace-main.comp`'s `main()` function, you're accumulating `combinedColor += finalColor.color / SAMPLES;` inside the sample loop, but then calling `imageStore(resultImage, ..., vec4(finalColor.color, 1.0));` (which overwrites the image with only the last sample's color). Move the `imageStore` *outside* the loop and use `combinedColor` instead. This ensures proper averaging across samples for anti-aliasing (AA). If `SampleTable` in `main_rg.glsl` is a jitter table (e.g., for stratified sampling), this will reduce noise effectively.
  
- **Improve shadow ray handling**: In `basic-chit.glsl`'s `perform_basic_lighting()`, you're accumulating `shadow += calc_shadow_ray(shadowRay);` across all lights but only if `shadow < 0.9f`, then multiplying the total color by a thresholded `shadow`. This can lead to incorrect shadowing with multiple lights (e.g., over-darkening or binary artifacts). Instead, compute shadows *per light* inside the light loop: Add a `float shadow = calc_shadow_ray(shadowRay);` before `color += specularContribution(...) * power;`, then multiply that term by `shadow`. This makes occlusion independent per light source. Also, if `SHADOW` is 0.0 (as implied), consider soft shadows by casting multiple offset rays per light for better realism.

- **Handle miss shaders properly**: In `render_scene()`, if `info.face_id == -1`, you set `fMat.color = vec3(0);` (black). This can make backgrounds unnaturally dark. Add a simple sky gradient or environment map: e.g., `fMat.color = mix(vec3(0.5, 0.7, 1.0), vec3(1.0), 0.5 * (ray.d.y + 1.0));` for a blue-ish sky. This improves visual quality without much cost.

- **Refraction implementation**: You have a `fresnel()` function but it's unused. Integrate it into `render_scene()` for transparent materials (using `fMat.transparency` and `fMat.refraction`). After the initial hit, compute `kr` with `fresnel(ray.d, info.normal, fMat.refraction, kr);`, then blend reflection and a refracted ray (using Snell's law to compute the refract direction). Trace a separate refract ray similar to your reflection loop, mixing results based on `kr`. This enables glass/water effects—start with a simple single-bounce version to avoid complexity.

### Performance Optimizations
- **Tune local workgroup size**: Your `layout(local_size_x = 16, local_size_y = 16)` is a reasonable start, but test larger sizes (e.g., 32x32) based on your GPU's limits (query `GL_MAX_COMPUTE_WORK_GROUP_SIZE` in host code). Smaller groups can increase overhead; larger ones improve cache coherence for ray traversal. Profile with different sizes for your scene complexity—NVIDIA recommends balancing to maximize occupancy.

- **Increase BVH stack size**: The `stack[16]` in `main-intersect.glsl` might overflow for deep BVHs or complex meshes, causing missed intersections. Bump it to 32 or 64 (common in software ray tracers). If scenes are very complex, consider iterative traversal instead of stack-based to avoid fixed-size limits.

- **Optimize intersections**: Your `quadIntersect()` and `triIntersect()` are functional but could be faster. Add early-outs (e.g., if `det < 0` or `t > ray.t`, bail early). For meshes, consider precomputing per-triangle bounds in the BVH for tighter nodes. If using triangles (via `triIntersect`), prefer them over quads for hardware-friendly traversal. Also, in `bvhIntersect()`, avoid redundant computations—some GLSL examples unroll the loop for the 3 axes to reduce branches.

- **Simplify shading**: Your PBR in `pbr.glsl` is good, but keep shaders lean (as per NVIDIA/RTX best practices). Reduce texture lookups in reflections (e.g., lower mip bias) to minimize divergence. For higher bounces, use simpler Lambertian shading instead of full GGX to cut compute time without much visual loss.

- **Add Russian roulette for reflections**: In the reflection loop, terminate rays probabilistically after a few bounces (e.g., if `random() > reflectionStrength`, stop and add throughput compensation). This reduces noise and paths in your `RAYBOUNCES=4` limit, making it more like a basic path tracer.

### Feature Enhancements and Quality
- **Better anti-aliasing and sampling**: If `SAMPLES > 1`, ensure `SampleTable` includes random jitter (e.g., via a noise texture or Halton sequence). This turns your fixed sampling into Monte Carlo for less aliasing. For real-time, add a simple temporal AA (accumulate frames) or look into denoising libraries if integrating with host code.

- **Environment lighting**: Beyond the miss sky, add an HDR environment map for indirect lighting. Sample it in the miss shader or as ambient term in `perform_basic_lighting()`. This approximates global illumination cheaply.

- **Debug visualizations**: Add modes (e.g., via UBO flags) to output normals (`fMat.color = info.normal * 0.5 + 0.5;`), depths (`fMat.color = vec3(ray.t / MAXLEN);`), or BVH traversals (as your `#DEBUGLINES` starts). This helps diagnose issues like the normals you mentioned.

- **Hardware ray tracing migration**: If your GPU supports it (e.g., NVIDIA RTX), consider porting to `GL_NV_ray_tracing` extension for hardware-accelerated traversal. Your BVH code could map to acceleration structures, yielding massive speedups (10x+). Tutorials like Anton's or NVIDIA's RTX guides provide migration paths, but this is a bigger change.

- **General code cleanup**: Remove unused includes (e.g., commented `main-rg.glsl` vs. `foveated-rg.glsl`). Add more constants for tweakability (e.g., light count). Test with simple scenes (hardcoded spheres/planes) before meshes to isolate bugs.

These should make your renderer more robust, efficient, and visually appealing. Start with the bug fixes—they'll have the biggest immediate impact. If you share more details (e.g., a screenshot of the artifact, scene setup, or performance stats), I can refine these further!



# Ecs fix
* Add Component
	* if old archetype exists... which it does for the bug
	* make a new one based off edges of old one
	* oh then there's deletes which you can just... context_temp alloc
* Move Entity:
	* takes in both a new and old archetype
	* and entity
	* new_row = old size before append of entity
	* ent gets appeneded
	* world gets updated 
	* 