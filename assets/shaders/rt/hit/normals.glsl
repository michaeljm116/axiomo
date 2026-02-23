#ifndef NORMALS_GLSL
#define NORMALS_GLSL
#include "../structs.glsl"
#include "../constants.glsl"

vec3 sphere_normal(in vec3 pos, in Primitive sphere)
{
	return (pos - vec4(sphere.world[3]).xyz) / sphere.extents.x;
}

vec3 disk_normal(){
    return vec3(0,1,0);
}

vec3 quad_normal(Primitive prim, Face f, float u, float v) {
	vec3 n0 = verts[f.v[0]].norm;
	vec3 n1 = verts[f.v[1]].norm;
	vec3 n2 = verts[f.v[2]].norm;
	vec3 n3 = verts[f.v[3]].norm;

	vec3 lerp1 = mix(n0, n1, u);
	vec3 lerp2 = mix(n3, n2, u);
	mat4 temp2 =
	mat4(prim.extents.x, 0, 0, 0,
		 0, prim.extents.y, 0, 0,
		 0, 0, prim.extents.z, 0,
		0, 0, 0, 1);
	mat4 world = prim.world * temp2;
	return normalize(world * vec4(mix(lerp1, lerp2, v), 0.f)).xyz;
}

vec3 quad_normal2(Primitive prim, Face f, float u, float v) {
    vec3 n0 = verts[f.v[0]].norm;
    vec3 n1 = verts[f.v[1]].norm;
    vec3 n2 = verts[f.v[2]].norm;
    vec3 n3 = verts[f.v[3]].norm;

    vec3 lerp1 = mix(n0, n1, u);
    vec3 lerp2 = mix(n3, n2, u);
    vec3 interpolated_normal = mix(lerp1, lerp2, v);

    mat4 temp2 = mat4(
        prim.extents.x, 0, 0, 0,
        0, prim.extents.y, 0, 0,
        0, 0, prim.extents.z, 0,
        0, 0, 0, 1
    );
    mat4 model = prim.world * temp2;
    mat3 normalMatrix = transpose(inverse(mat3(model)));
    return normalize(normalMatrix * interpolated_normal);
}

void set_normals(inout HitInfo info, in vec3 ray_pos){
    switch (info.prim_type) {
        case TYPE_DISK:
        {
            info.normal = disk_normal();
            break;
        }
        case TYPE_SPHERE:
        {
            info.normal = sphereNormal(ray_pos, primitives[info.face_id]);
            break;
        }
        case TYPE_MESH:
        {
            info.normal = quad_normal2(primitives[info.prim_id], faces[info.face_id], info.normal.x, info.normal.y);
            break;
        }
        default:
            break;
    }
}

mat3 buildTangentBasis(vec3 N) {
    N = normalize(N);
    vec3 arb = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
    vec3 T = normalize(cross(N, arb));
    vec3 B = -cross(N, T);
    return mat3(T, B, N);
}

SurfaceData buildSurfaceData(HitInfo info, vec3 world_pos, uint flags) {
    SurfaceData sd;

    Primitive prim = primitives[info.prim_id];
    sd.inv_world = inverse(prim.world);
    sd.local_pos = sd.inv_world * vec4(world_pos, 1.0);
    // sd.TBN = buildTangentBasis((transpose(mat3(sd.inv_world)) * info.normal));
    sd.TBN = buildTangentBasis(info.normal);
    sd.use_object_space = (flags & MATERIAL_FLAG_PROC_OBJECT_SPACE) != 0u;

    return sd;
}

vec2 projectToTangent(SurfaceData sd, vec3 world_pos) {
    vec3 pos = sd.use_object_space ? sd.local_pos.xyz : world_pos;
    return vec2(dot(pos, sd.TBN[0]), dot(pos, sd.TBN[1]));
}

#endif
