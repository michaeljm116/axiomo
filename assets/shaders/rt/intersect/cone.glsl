#ifndef _INTERSECT_CONE_GLSL
#define _INTERSECT_CONE_GLSL
#include "../structs.glsl"

vec4 coneIntersect(in Ray ray, in Primitive cone)
{
    vec3 pa = (cone.world * vec4(0.0, -cone.extents.y, 0.0, 1.0)).xyz; // base
    vec3 pb = (cone.world * vec4(0.0, cone.extents.y, 0.0, 1.0)).xyz; // apex
    float radius = cone.extents.x;

    vec3 ca = pa - pb; // base - apex
    vec3 oc = ray.o - pb; // ray from apex

    float caca = dot(ca, ca);
    float card = dot(ca, ray.d);
    float caoc = dot(ca, oc);

    float k = radius / length(ca);
    k = k * k + 1.0;

    float a = dot(ray.d, ray.d) - k * (card * card) / caca;
    float b = dot(ray.d, oc) - k * (card * caoc) / caca;
    float c = dot(oc, oc) - k * (caoc * caoc) / caca;

    float h = b * b - a * c;
    if (h < 0.0) return vec4(-1.0); // no hit

    h = sqrt(h);
    float t = (-b - h) / a;
    if (t < 0.0) t = (-b + h) / a;
    if (t < 0.0) return vec4(-1.0);

    float y = caoc + t * card;
    if (y < 0.0 || y > caca) return vec4(-1.0); // outside cone body

    vec3 hit = ray.o + ray.d * t;
    vec3 q = hit - pb;
    vec3 proj = ca * (dot(q, ca) / caca);
    vec3 normal = normalize(q - proj * (1.0 + radius * radius / caca));

    return vec4(t, normal);
}
#endif
