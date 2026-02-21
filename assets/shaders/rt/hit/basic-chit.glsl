#ifndef BASIC_HIT_GLSL
#define BASIC_HIT_GLSL

#include "normals.glsl"
#include "pbr.glsl"
#include "../structs.glsl"
#include "../constants.glsl"
#include "../intersect/main-intersect.glsl"

vec4 box_texture(in vec3 pos, in vec3 norm, in Primitive box, sampler2D t)
{
    // Transform the hit position into the box's local/object space using the inverse world matrix.
    mat4 invWorld = inverse(box.world);
    vec3 div = 1.0 / box.extents * 0.5;
    vec3 iPos = (invWorld * vec4(pos, 1.0)).xyz;

    // Transform normals correctly using the inverse-transpose (normal matrix).
    mat3 normalMatrix = transpose(mat3(invWorld));
    vec3 iNorm = normalize(normalMatrix * norm);

    // Sample projected textures on each axis in object space and blend by the absolute
    // value of the object-space normal to determine which face contributes.
    vec4 xTxtr = texture(t, iPos.yz * div.x);
    vec4 yTxtr = texture(t, iPos.zx * div.y);
    vec4 zTxtr = texture(t, iPos.xy * div.z);

    vec3 ret =
        abs(iNorm.x) * xTxtr.rgb * xTxtr.a +
            abs(iNorm.y) * yTxtr.rgb * yTxtr.a +
            abs(iNorm.z) * zTxtr.rgb * zTxtr.a;
    return vec4(ret, 1.0);
}

vec4 get_texture(HitInfo info, vec3 ray_pos, Material mat)
{
    if (mat.textureID > 0)
    {
        if (info.prim_type == TYPE_BOX) return box_texture(ray_pos, info.normal, primitives[info.face_id], bindless_textures[nonuniformEXT(mat.textureID)]);
        else return texture(bindless_textures[nonuniformEXT(mat.textureID)], info.normal.xy);
    }
    return vec4(0);
}

// This is disgustingly bad WOW
vec4 perform_basic_lighting(HitInfo info, vec3 ray_pos, Material mat, vec4 txtr)
{
    float power = 0;
    float shadow = 0;
    vec3 color = vec3(0);
    vec3 view = normalize(ubo.rotM[3].xyz - ray_pos);
    for (int i = 0; i < lights.length(); ++i)
    {
        vec3 F0 = vec3(0.04);
        F0 = mix(F0, mat.diffuse, mat.reflective);
        vec3 distance = lights[i].pos - ray_pos;
        float ld = length(distance);
        power = lights[i].intensity / (ld * ld);
        vec3 lightDirection = normalize(distance);
        if (power > 0.1f)
        {
            color += specularContribution(lightDirection, view, info.normal, F0, txtr.xyz + mat.diffuse, mat.reflective, mat.roughness) * power;
        }
        if (shadow < 0.9f) {
            Ray shadowRay = Ray(ray_pos, length(distance), lightDirection, 0);
            shadow += calc_shadow_ray(shadowRay);
        }
    }

    shadow = shadow * float(shadow < 0.9f) + float(shadow >= .9f);
    color *= shadow;

    return vec4(color, 0.f);
}

vec4 basic_lighting(HitInfo info, vec3 ray_pos, Material mat, vec4 txtr)
{
    float power = 3;
    float shadow = 0;
    vec3 color = vec3(0);
    vec3 view = normalize(ubo.rotM[3].xyz - ray_pos);
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, mat.diffuse, mat.reflective);
    vec3 distance = lights[0].pos - ray_pos;
    float ld = length(distance);
    power = lights[0].intensity; // / (ld * ld);
    vec3 lightDirection = normalize(distance);
    color = specularContribution(lightDirection, view, info.normal, F0, txtr.xyz + mat.diffuse, mat.reflective, mat.roughness) * power;

    return vec4(color, 1.f);
}

// Given the hit info & ray position
// Get the Normal,Material,Texture if it has one
// Calculate the Light,Shadow, reflection contribtion
vec3 closest_hit_basic(HitInfo info, Ray ray, inout finalmaterial f_mat) {
    vec3 ray_pos = ray.o + ray.t * ray.d;
    set_normals(info, ray_pos);
    Material mat = materials[primitives[info.face_id].matID];
    if (info.prim_type == TYPE_MESH) mat = materials[primitives[info.prim_id].matID];
    vec4 texture = get_texture(info, ray_pos, mat);
    vec4 color = perform_basic_lighting(info, ray_pos, mat, texture);

    f_mat.color = color.xyz;
    f_mat.reflection = mat.reflective;
    f_mat.refraction = 0;//mat.refractiveIndex;
    f_mat.transparency = mat.transparency;

    return ray_pos;
}
#endif
