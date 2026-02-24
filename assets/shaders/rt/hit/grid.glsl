#ifndef GRID_GLSL
#define GRID_GLSL

#include "normals.glsl"
#include "pbr.glsl"
#include "../structs.glsl"
#include "../constants.glsl"
#include "../intersect/main-intersect.glsl"

struct GridInfo {
    vec2 size; // 7 x 5
    vec2 cell_size; // 16 x 10
    float line_thickness;
    vec4 line_color;
    float offset; // offset to walkable/runnable grid
    vec2 origin;     // NEW: Add this
};

vec4 getGridCellColor(GridInfo info, vec2 cellCoord)
{
    if (cellCoord.x < 0.0 || cellCoord.x >= info.size.x ||
        cellCoord.y < 0.0 || cellCoord.y >= info.size.y) {
        return vec4(0.0);
    }

    float texel = 1.0 / 32.0;
    float x = cellCoord.x + 1.5;
    float y = cellCoord.y + 0.5;
    vec2 uv = vec2(x, y) * texel;

    return texture(data_texture, uv);
}

GridInfo getGridInfo() {
    float texel = 1.0 / 32.0;
    vec2 uv0 = vec2(0.5, 0.5) * texel;
    vec2 uv1 = vec2(0.5, 1.5) * texel;
    vec2 uv2 = vec2(0.5, 2.5) * texel;
    vec2 uv3 = vec2(0.5, 3.5) * texel;
    vec2 uv4 = vec2(0.5, 4.5) * texel;
    vec2 uv5 = vec2(0.5, 5.5) * texel;

    vec4 p0 = texture(data_texture, uv0);
    vec4 p1 = texture(data_texture, uv1);
    vec4 p2 = texture(data_texture, uv2);
    vec4 p3 = texture(data_texture, uv3);
    vec4 p4 = texture(data_texture, uv4);
    vec4 p5 = texture(data_texture, uv5);

    GridInfo info;
    info.size = vec2(p0.r, p1.r);
    info.cell_size = vec2(p2.r, p3.r);
    info.line_thickness = p4.r;
    info.line_color = p5;
    info.offset = p0.g;
    info.origin = vec2(p1.g, p2.g); // NEW: Read origin here
    return info;
}

// Updated shadeGrid (merge in shadeGrid2 logic)
vec4 shadeGrid(HitInfo info, vec3 ray_pos, vec4 color, SurfaceData sd) {
    GridInfo grid_info = getGridInfo();
    Primitive prim = primitives[info.prim_type == TYPE_BOX ? info.face_id : info.prim_id];

    // Project to tangent plane
    vec2 tangent_pos = projectToTangent(sd, ray_pos);  // Assume this gives local if object_space

    // Grid settings (keep world cellSize/lineWidth for now)
    vec2 cellSize = grid_info.cell_size;
    float lineWidth = grid_info.line_thickness;

    // Handle object space: No normalization to 0-1 (keep full units), adjust origin to local bottom-left
    vec2 origin;
    if (sd.use_object_space) {
        vec2 extents = prim.extents.xz;  // FIXED: .xz for floor (x=16, z=10)
        origin = -extents;  // Local bottom-left {-16, -10}
    } else {
        origin = grid_info.origin;  // World bottom-left
    }

    // If your Odin origin is cell CENTER (not corner), shift to align floor(coord)
    vec2 coord = (tangent_pos - origin) / cellSize;
    coord += vec2(0.5, 0.5);  // UNCOMMENT if origin=cell center (shifts floor to match cells)

    // Rest unchanged: lines, cellCoord = floor(coord), WR mixing
    vec2 grid = abs(fract(coord) - 0.5);
    float line = min(grid.x, grid.y);
    float mask = 1 - smoothstep(lineWidth - 0.025, lineWidth + 0.025, line);
    vec4 gridColor = grid_info.line_color;
    float blend = mask * gridColor.a;
    color = mix(color, vec4(gridColor.rgb, color.a), blend);

    vec2 cellCoord = floor(vec2(coord.x - .5, coord.y - .5));
    vec4 gridCellColor = getGridCellColor(grid_info, cellCoord);
    float gridBlend = gridCellColor.a;
    color = mix(color, vec4(gridCellColor.rgb, color.a), gridBlend);

    return color;
}

#endif
