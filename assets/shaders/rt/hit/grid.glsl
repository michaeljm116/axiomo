#ifndef GRID_GLSL
#define GRID_GLSL

#include "normals.glsl"
#include "pbr.glsl"
#include "../structs.glsl"
#include "../constants.glsl"
#include "../intersect/main-intersect.glsl"

struct GridInfo
{
    ivec2 size;
    float cell_size;
    float line_thickness;
    vec4 line_color;
};

GridInfo getGridInfo()
{
    GridInfo info;
    info.size = data_texture[0].rg
    info.cell_size = data_texture[0].b
    info.line_thickness = data_texture[0].a
    info.line_color = data_texture[1].rgba
}

vec3 shadeGrid(HitInfo info, vec3 ray_pos, vec4 color)
{
    // ---- Build tangent basis from normal ----
    vec3 N = normalize(info.normal);

    vec3 T = normalize(
            abs(N.y) < 0.999
            ? cross(N, vec3(0.0, 1.0, 0.0)) : cross(N, vec3(1.0, 0.0, 0.0))
        );

    vec3 B = cross(N, T);

    // ---- Project world position onto tangent plane ----
    float u = dot(ray_pos, T);
    float v = dot(ray_pos, B);

    vec2 coord = vec2(u, v);

    // ---- Grid settings ----
    float cellSize = 1.0;
    float lineWidth = 0.03;

    coord /= cellSize;

    // ---- Core grid math ----
    vec2 grid = abs(fract(coord) - 0.5);

    float line = min(grid.x, grid.y);

    float mask = step(line, lineWidth);

    vec3 lineColor = vec3(0.9);

    return mix(color.rgb, lineColor, mask);
}

#endif
