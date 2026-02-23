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
    float wr_offset; // offset to walkable/runnable grid
    vec2 origin;     // NEW: Add this
};

vec4 getWalkableRunnableColor(GridInfo info, vec2 cellCoord)
{
    if (cellCoord.x < 0.0 || cellCoord.x >= info.size.x ||
            cellCoord.y < 0.0 || cellCoord.y >= info.size.y) {
        return vec4(0.0);
    }

    float texel = 1.0 / 32.0;
    float wr_x = info.size.x + 1.0 + cellCoord.x + 0.5;
    float wr_y = cellCoord.y + 0.5;
    vec2 uv = vec2(wr_x, wr_y) * texel;

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
    info.wr_offset = p0.g;
    info.origin = vec2(p1.g, p2.g); // NEW: Read origin here
    return info;
}

// Existing getWalkableRunnableColor is fine

// Optional: Add this if you want to mix main cell colors (walls/obstacles)
vec4 getCellColor(GridInfo info, vec2 cellCoord) {
    if (cellCoord.x < 0.0 || cellCoord.x >= info.size.x ||
        cellCoord.y < 0.0 || cellCoord.y >= info.size.y) {
        return vec4(0.0);
    }

    float texel = 1.0 / 32.0;
    float cell_x = 1.0 + cellCoord.x + 0.5;
    float cell_y = cellCoord.y + 0.5;
    vec2 uv = vec2(cell_x, cell_y) * texel;

    return texture(data_texture, uv);
}

// Updated shadeGrid (merge in shadeGrid2 logic)
vec4 shadeGrid(HitInfo info, vec3 ray_pos, vec4 color, SurfaceData sd) {
    GridInfo grid_info = getGridInfo();
    Primitive prim = primitives[info.prim_type == TYPE_BOX ? info.face_id : info.prim_id];

    // ---- Project position to tangent plane using SurfaceData ----
    vec2 tangent_pos = projectToTangent(sd, ray_pos);

    // ---- Grid settings ----
    vec2 cellSize = grid_info.cell_size;
    float lineWidth = grid_info.line_thickness;

    // For object-space, use actual cell size from texture normalized to object
    // if (sd.use_object_space) {
    //     // vec2 extents = prim.extents.xy;
    //     // tangent_pos = tangent_pos / extents * 0.5 + 0.5;  // normalize to 0 to 1 range
    //     // // Use actual cell_size but scaled to object
    //     // cellSize = cellSize / extents * 2.0;
    //     // lineWidth = lineWidth / extents.x * 2.0;  // normalize line width

    //     tangent_pos = tangent_pos / cellSize * 0.5 + 0.5;  // normalize to 0 to 1 range

    //     // Use actual cell_size but scaled to object
    //     cellSize = cellSize / cellSize * 2.0;
    //     lineWidth = lineWidth / extents.x * 2.0;  // normalize line width
    // }

    // Use zero origin for object-space, otherwise use stored origin for world-space
    vec2 origin = sd.use_object_space ? vec2(0.0) : grid_info.origin;

    // Offset by grid origin and divide by cell size to get cell coordinates
    vec2 coord = (tangent_pos - origin) / cellSize;

    // ---- Core grid line math ----
    vec2 grid = abs(fract(coord) - 0.5);
    float line = min(grid.x, grid.y);
    float mask = 1 - smoothstep(lineWidth - 0.025, lineWidth + 0.025, line);

    vec4 gridColor = grid_info.line_color;
    float blend = mask * gridColor.a;
    color = mix(color, vec4(gridColor.rgb, color.a), blend);

    // NEW: Compute integer cell coord for sampling
    vec2 cellCoord = floor(vec2(coord.x + .5, coord.y + 1.5));

    // NEW: Mix walkable/runnable colors (blue/green)
    vec4 wrColor = getWalkableRunnableColor(grid_info, cellCoord);
    float wrBlend = wrColor.a;
    color = mix(color, vec4(wrColor.rgb, color.a), wrBlend);

    // Optional: Mix main cell colors (e.g., red for obstacles, white for walls)
    // vec4 cellColor = getCellColor(grid_info, cellCoord);
    // float cellBlend = cellColor.a;
    // color = mix(color, vec4(cellColor.rgb, color.a), cellBlend);

    return color;
}

#endif
