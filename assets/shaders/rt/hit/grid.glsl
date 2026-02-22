#ifndef GRID_GLSL
#define GRID_GLSL

#include "normals.glsl"
#include "pbr.glsl"
#include "../structs.glsl"
#include "../constants.glsl"
#include "../intersect/main-intersect.glsl"

struct GridInfo
{
    vec2 size;
    vec2 cell_size;
    float line_thickness;
    vec4 line_color;
    float wr_offset; // offset to walkable/runnable grid
};

GridInfo getGridInfo()
{
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
    return info;
}

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

vec4 shadeGrid(HitInfo info, vec3 ray_pos, vec4 color)
{
    GridInfo grid_info = getGridInfo();

    // ---- Build tangent basis from normal ----
    vec3 N = normalize(info.normal);
    vec3 T = normalize(abs(N.y) < 0.999 ? cross(N, vec3(0.0, 1.0, 0.0)) : cross(N, vec3(1.0, 0.0, 0.0)));
    vec3 B = cross(N, T);

    // ---- Project world position onto tangent plane ----
    float u = dot(ray_pos, T);
    float v = dot(ray_pos, B);
    vec2 coord = vec2(u, v);

    // ---- Grid settings ----
    vec2 cellSize = grid_info.cell_size;
    float lineWidth = grid_info.line_thickness;
    coord /= cellSize;

    // ---- Core grid math ----
    vec2 grid = abs(fract(coord) - 0.5);
    float line = min(grid.x, grid.y);
    float mask = step(line, lineWidth);

    vec4 gridColor = grid_info.line_color;
    float blend = mask * gridColor.a;
    return mix(color, vec4(gridColor.rgb, color.a), blend);
}

// vec4 shadeGrid2(HitInfo info, vec3 ray_pos, vec4 color)
// {
//     GridInfo grid_info = getGridInfo();

//     // ---- Build tangent basis from normal ----
//     vec3 N = normalize(info.normal);
//     vec3 T = normalize(abs(N.y) < 0.999 ? cross(N, vec3(0.0, 1.0, 0.0)) : cross(N, vec3(1.0, 0.0, 0.0)));
//     vec3 B = cross(N, T);

//     // ---- Project world position onto tangent plane ----
//     float u = dot(ray_pos, T);
//     float v = dot(ray_pos, B);
//     vec2 worldPos = vec2(u, v);

//     // ---- Grid settings ----
//     vec2 cellSize = grid_info.cell_size;
//     vec2 origin = grid_info.origin;
//     float lineWidth = grid_info.line_thickness;

//     // Offset by grid origin and divide by cell size to get cell coordinates
//     vec2 coord = (worldPos - origin) / cellSize;

//     // ---- Core grid line math ----
//     vec2 grid = abs(fract(coord) - 0.5);
//     float line = min(grid.x, grid.y);
//     float lineMask = step(line, lineWidth);

//     vec4 lineColor = grid_info.line_color;
//     float lineBlend = lineMask * lineColor.a;
//     color = mix(color, vec4(lineColor.rgb, color.a), lineBlend);

//     // ---- Walkable/Runnable grid (filled squares) ----
//     vec2 cellCoord = floor(coord);

//     // Debug: show cell coordinates as color
//     // vec4 wrColor = vec4(cellCoord.x * 0.1, cellCoord.y * 0.1, 0.0, 1.0);
//     vec4 wrColor = getWalkableRunnableColor(grid_info, cellCoord);
//     float wrBlend = wrColor.a;
//     color = mix(color, vec4(wrColor.rgb, color.a), wrBlend);

//     return color;
// }
#endif
