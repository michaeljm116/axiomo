#ifndef _INTERSECT_CYLINDER_GLSL
#define _INTERSECT_CYLINDER_GLSL
#include "../structs.glsl"

// Intersect a ray with a finite vertical cylinder using center + extents
vec4 cylinderIntersect(in Ray ray, in Primitive cyl)
{
    // Cylinder center is at cyl.world[3].xyz, aligned along local Y-axis
    // World-space endpoints of the cylinder
    vec3 pa = (cyl.world * vec4(0.0, -cyl.extents.y, 0.0, 1.0)).xyz;
    vec3 pb = (cyl.world * vec4(0.0, cyl.extents.y, 0.0, 1.0)).xyz;

    float ra = cyl.extents.x; // radius
    vec3 ca = pb - pa; // cylinder axis vector
    vec3 oc = ray.o - pa;

    float caca = dot(ca, ca);
    float card = dot(ca, ray.d);
    float caoc = dot(ca, oc);

    float a = caca - card * card;
    float b = caca * dot(oc, ray.d) - caoc * card;
    float c = caca * dot(oc, oc) - caoc * caoc - ra * ra * caca;

    float h = b * b - a * c;
    if (h < 0.0 || abs(a) < 1e-6) return vec4(-1.0); // No intersection or parallel

    h = sqrt(h);
    float t = (-b - h) / a;

    // Check if the hit point is within the body
    float y = caoc + t * card;
    if (y > 0.0 && y < caca) {
        vec3 hit = oc + t * ray.d - ca * (y / caca);
        vec3 normal = normalize(hit / ra); // normal on side surface
        return vec4(t, normal);
    }

    // Check top or bottom cap
    t = (((y < 0.0) ? 0.0 : caca) - caoc) / card;
    if (t < 0.0) return vec4(-1.0); // behind ray

    vec3 hit = oc + t * ray.d - ca * ((y < 0.0) ? 0.0 : 1.0);
    if (dot(hit, hit) <= ra * ra) {
        vec3 normal = normalize(ca) * ((y < 0.0) ? -1.0 : 1.0); // cap normal
        return vec4(t, normal);
    }

    return vec4(-1.0);
}

#endif
