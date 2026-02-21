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
    float texelSize = 1.0 / 256.0;
    vec2 uv00 = vec2(texelSize * 0.5);
    vec2 uv01 = vec2(texelSize * 0.5, texelSize * 1.5);

    vec4 pixel_00 = texture(data_texture, uv00);
    vec4 pixel_01 = texture(data_texture, uv01);

    GridInfo info;
    info.size = ivec2(pixel_00.rg);
    info.cell_size = pixel_00.b / 25.0;
    info.line_thickness = pixel_00.a / 1000.0;
    info.line_color = pixel_01;
    return info;
}

vec3 shadeGrid(HitInfo info, vec3 ray_pos, vec4 color)
{
    GridInfo grid = getGridInfo();

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

    // ---- Grid settings from texture ----
    coord /= grid.cell_size;

    // ---- Sample cell color from texture ----
    // Grid cells start at texture (1, 0)
    float texelSize = 1.0 / 256.0;
    vec2 cellBase = vec2(1.0, 0.0) + 0.5;
    vec2 cellUV = (floor(coord) + cellBase) * texelSize;
    cellUV = clamp(cellUV, texelSize * 0.5, 1.0 - texelSize * 0.5);
    vec3 cellColor = texture(data_texture, cellUV).rgb;

    // ---- Core grid math ----
    vec2 gridCoord = abs(fract(coord) - 0.5);

    float line = min(gridCoord.x, gridCoord.y);

    float mask = step(line, grid.line_thickness);

    return mix(mix(cellColor, color.rgb, 0.5), grid.line_color.rgb, mask * grid.line_color.a);
}

#endif
