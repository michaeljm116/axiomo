#ifndef _INTERSECT_SHAPES_GLSL
#define _INTERSECT_SHAPES_GLSL
#include "../structs.glsl"

//----------------------------------------------------------------------------
// /Plane
//----------------------------------------------------------------------------

float planeIntersect(in Ray ray, in Primitive plane)
{
    vec3 normal = vec3(0, 1, 0);
    float d = dot(ray.d, normal);

    if (d > EPSILON)
        return 0.0;

    //float t = -(plane.distance + dot(rayO, normal)) / d;
    float t = dot(vec3(plane.world[3].xyz) - ray.o, normal) / d;

    if (t < 0.0)
        return 0.0;

    return t;
}

//----------------------------------------------------------------------------
// /BOX
//----------------------------------------------------------------------------

vec4 boxIntersect(in Ray ray, in Primitive box)
{
    // convert from ray to box space
    // currently 147/148
    mat4 invWorld = inverse(box.world);
    vec3 rdd = (invWorld * vec4(ray.d, 0.0)).xyz;
    vec3 roo = (invWorld * vec4(ray.o, 1.0)).xyz;

    // ray-box intersection in box space
    vec3 m = 1.0 / rdd;
    vec3 n = m * roo;
    vec3 k = abs(m) * box.extents;

    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return vec4(-1.0);

    vec3 nor = -sign(rdd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);

    // convert to ray space

    nor = (box.world * vec4(nor, 0.0)).xyz;

    return vec4(tN, nor);
}

vec4 quadTexIntersect(in Ray ray, in Primitive quad, inout vec2 uv)
{
    return vec4(1.0);
    // Convert from ray to quad space
    mat4 invWorld = inverse(quad.world);
    vec3 rdd = (invWorld * vec4(ray.d, 0.0)).xyz;
    vec3 roo = (invWorld * vec4(ray.o, 1.0)).xyz;

    // Since we're working in the XY plane, ignore the Z component
    rdd.z = 0.0;
    roo.z = 0.0;

    // Early out if the ray is parallel to the plane of the quad
    if (abs(rdd.x) < EPSILON && abs(rdd.y) < EPSILON) {
        return vec4(-1.0);
    }

    // Ray-quad intersection in quad space (2D)
    vec2 m = 1.0 / rdd.xy;
    vec2 n = m * roo.xy;
    vec2 k = abs(m) * quad.extents.xy;

    vec2 t1 = -n - k;
    vec2 t2 = -n + k;

    float tN = max(t1.x, t1.y);
    float tF = min(t2.x, t2.y);
    if (tN > tF || tF < 0.0) {
        return vec4(-1.0);
    }

    // Determine the normal based on the direction of the ray
    vec2 nor2D = -sign(rdd.xy) * step(t1.yx, t1.xy);

    // Convert to ray space
    vec3 nor = vec3(nor2D, 0.0);
    nor = (quad.world * vec4(nor, 0.0)).xyz;

    //Get Texture coordinates
    vec3 pos = rdd * tN + roo;
    vec3 cen = quad.world[3].xyz;
    vec3 ext = quad.extents.xyz;

    vec2 newPos = abs(pos.xy - cen.xy);
    newPos = newPos / ext.xy;
    uv = vec2(newPos);

    return vec4(tN, nor);
}
vec4 quadTexIntersectS(in Ray ray, in Primitive quad)
{
    return vec4(1.0);
    // Convert from ray to quad space
    mat4 invWorld = inverse(quad.world);
    vec3 rdd = (invWorld * vec4(ray.d, 0.0)).xyz;
    vec3 roo = (invWorld * vec4(ray.o, 1.0)).xyz;

    // Since we're working in the XY plane, ignore the Z component
    rdd.z = 0.0;
    roo.z = 0.0;

    // Early out if the ray is parallel to the plane of the quad
    if (abs(rdd.x) < EPSILON && abs(rdd.y) < EPSILON) {
        return vec4(-1.0);
    }

    // Ray-quad intersection in quad space (2D)
    vec2 m = 1.0 / rdd.xy;
    vec2 n = m * roo.xy;
    vec2 k = abs(m) * quad.extents.xy;

    vec2 t1 = -n - k;
    vec2 t2 = -n + k;

    float tN = max(t1.x, t1.y);
    float tF = min(t2.x, t2.y);
    if (tN > tF || tF < 0.0) {
        return vec4(-1.0);
    }

    // Determine the normal based on the direction of the ray
    vec2 nor2D = -sign(rdd.xy) * step(t1.yx, t1.xy);

    // Convert to ray space
    vec3 nor = vec3(nor2D, 0.0);
    nor = (quad.world * vec4(nor, 0.0)).xyz;

    //Get Texture coordinates
    //vec3 pos = rdd * tN + roo;
    //vec3 cen = quad.world[3].xyz;
    //vec3 ext = quad.extents.xyz;

    return vec4(tN, nor);
}
vec3 boxTexture(in vec3 pos, in vec3 norm, in Primitive box, sampler2D t) {
    // Transform the world-space position into the box's local/object space
    // by multiplying the inverse world matrix on the left (mat * vec).
    mat4 invWorld = inverse(box.world);
    vec3 div = 1.0 / box.extents * 0.5;
    vec3 iPos = (invWorld * vec4(pos, 1.0)).xyz;

    // Normals require transformation by the inverse-transpose (normal matrix).
    // Use the 3x3 transpose of the inverse world matrix to get correct local-space normals.
    mat3 normalMatrix = transpose(mat3(invWorld));
    vec3 iNorm = normalize(normalMatrix * norm);

    vec4 xTxtr = texture(t, div.x * iPos.yz);
    vec4 yTxtr = texture(t, div.y * iPos.zx);
    vec4 zTxtr = texture(t, div.z * iPos.xy);

    vec3 ret =
        abs(iNorm.x) * xTxtr.rgb * xTxtr.a +
            abs(iNorm.y) * yTxtr.rgb * yTxtr.a +
            abs(iNorm.z) * zTxtr.rgb * zTxtr.a;
    return ret;
}

//----------------------------------------------------------------------------
// /CONE
//----------------------------------------------------------------------------

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

//----------------------------------------------------------------------------
// /Sphere
//----------------------------------------------------------------------------

float sphereIntersect(inout Ray ray, in Primitive sphere)
{
    vec3 oc = ray.o - sphere.world[3].xyz;
    float b = 2.0 * dot(oc, ray.d);
    float c = dot(oc, oc) - sphere.extents.x * sphere.extents.x;
    float h = b * b - 4.0 * c;
    if (h < 0.0)
    {
        return -1.0;
    }
    float t = (-b - sqrt(h)) / 2.0;

    return t;
}
float skinnedSphereIntersect(inout Ray ray, in Shape sphere)
{
    vec3 oc = ray.o - sphere.center;
    float b = 2.0 * dot(oc, ray.d);
    float c = dot(oc, oc) - sphere.extents.x * sphere.extents.x;
    float h = b * b - 4.0 * c;
    if (h < 0.0)
    {
        return -1.0;
    }
    float t = (-b - sqrt(h)) / 2.0;

    return t;
}

vec3 sphereNormal(in vec3 pos, in Primitive sphere)
{
    return (pos - vec4(sphere.world[3]).xyz) / sphere.extents.x;
}

//----------------------------------------------------------------------------
// /disk
//----------------------------------------------------------------------------

float diskIntersect(in Ray ray, in Primitive disk)
{
    float radius = disk.extents.x;
    vec3 n = vec3(0, 1, 0);
    vec3 p0 = disk.world[3].xyz;

    float t = planeIntersect(ray, disk);
    if (t != 0.0f) {
        vec3 p = ray.o + ray.d * t;
        vec3 v = p - p0;
        float d2 = dot(v, v);
        float r2 = radius * radius;
        //if (sqrt(d2) <= radius)
        if (d2 <= r2)
            return t;
        // or you can use the following optimisation (and precompute radius^2)
        // return d2 <= radius2; // where radius2 = radius * radius
    }

    return 0.0f;
}

//----------------------------------------------------------------------------
// /Cylinder
//----------------------------------------------------------------------------

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
