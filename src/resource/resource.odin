package resource
import math "core:math/linalg"
import "core:strings"
import "core:log"
import "core:os"
import "core:io"
import "core:fmt"
import "core:encoding/csv"
import "core:bytes"
import "core:bufio"
import "core:encoding/ini"
import xml "core:encoding/xml"
import "core:encoding/json"
import "core:mem"
import "core:strconv"
import "../extensions/xml2"
import path "core:path/filepath"
import path2 "../extensions/filepath2"

//----------------------------------------------------------------------------\\
// /STRUCTS
//----------------------------------------------------------------------------\\
vec4i :: [4]i32
quat :: math.Quaternionf32
vec3 :: math.Vector3f32
vec4 :: math.Vector4f32
mat4 :: math.Matrix4f32
vec2 :: math.Vector2f32

Vertex :: struct{
    pos : vec3,
    norm : vec3,
    uv : vec2
}

Shape :: struct{
    name : string,
    type : i32,
    center : vec3,
    extents :vec3
}

Mesh :: struct{
    verts : [dynamic]Vertex,
    faces : [dynamic]vec4i,
    bvhs : [dynamic]BVHNode,
    center : vec3,
    extents : vec3,
    name : string,
    mat : Material,
    mat_id : i32,
    mesh_id : i32
}

Model :: struct{
    name : string,
    meshes : [dynamic]Mesh,
    shapes : [dynamic]Shape,
    center : vec3,
    extents : vec3,
    unique_id : i32,
    skeleton_id : i32,
    triangular : bool
}

Material :: struct{
    diffuse : vec3,
    reflective : f32,
    roughness : f32,
    transparency : f32,
    refractive_index : f32,
    texture_id : i32,
    unique_id : i32,
    texture : string,
    name : string
}

Controller :: struct {
    buttons : [16]i8,
    axis : [6]f32
}

Config :: struct {
    num_controller_configs : i8,
    controller_configs : [dynamic]f32
}

Pose :: struct{
   name : string,
   pose : [dynamic]PoseSqt, // Changed from tuple[int, Sqt]
}

PoseList :: struct{
    name : string,
    poses : [dynamic]Pose,
    hash_val : i32
}

Sqt :: struct
{
    rot : quat,
    pos : vec4,
    sca : vec4
}

PoseSqt :: struct {
    id: i32,
    sqt_data: Sqt,
}
BVHNode :: struct {
    upper: vec3,
    offset: i32,
    lower: vec3,
    numChildren: i32,
}

//----------------------------------------------------------------------------\\
// /PROCSs
//----------------------------------------------------------------------------\\
//----------------------------------------------------------------------------\\
// /LoadOthers /lo
//----------------------------------------------------------------------------\\
load_directory :: proc(directory: string, models: ^[dynamic]Model) {
    files := path2.get_dir_files(directory)
    for f in files{
        append(models, load_pmodel(f.fullpath, models^.allocator))
    }
    os.file_info_slice_delete(files)
}

//----------------------------------------------------------------------------\\
// /LoadModel /lm
//----------------------------------------------------------------------------\\
load_pmodel :: proc(file_name : string, allocator: mem.Allocator) -> Model
{
    // Set up initial variables
    mod : Model
    intro_length : i32 = 0
    name_length : i32 = 0
    num_mesh : i32 = 0
    unique_id : i32 = 0
    skeleton_id : i32 = 0
    skinned : b8 = false

    // Set up bionary io
    binaryio, err := os.open(file_name, os.O_RDONLY)
    log_if_err(err)
    defer os.close(binaryio)

    // Dont really need the intro but do it anyways
    br : int // br = total bytes read
    intro_length = read_i32(&binaryio)
    c : u8
    if intro_length > 0 {
        for b in 0..<intro_length {
            br, err = os.read(binaryio, mem.ptr_to_bytes(&c) )
            log_if_err(err)
        }
    }

    // Read the Name, First get the length, then assemble the string
    name_length = read_i32(&binaryio)
    if name_length > 0 {
        name_bytes := make([]u8, name_length, allocator)
        br, err = os.read(binaryio, name_bytes[:])
        log_if_err(err)
        mod.name = string(name_bytes[:])
    }

    // Read the unique id and num meshes
    unique_id = read_i32(&binaryio)
    num_mesh = read_i32(&binaryio)

    // Assemble the meshes
    mod.meshes = make([dynamic]Mesh, num_mesh, num_mesh, allocator)
    for i in 0..< num_mesh
    {
        // Declare meta deta
        m : Mesh
        mesh_name_length : i32
        num_verts : i32
        num_faces : i32
        num_nodes : i32
        mesh_id : i32

        //Get Mesh Name, first get length then get actual name
        mesh_name_length = read_i32(&binaryio)
        if(mesh_name_length > 0){
            name_bytes := make([]u8, mesh_name_length, allocator)
            br, err = os.read(binaryio, name_bytes[:])
            log_if_err(err)
            m.name = string(name_bytes)
        }

        //Get the mesh_id
        mesh_id = read_i32(&binaryio)

        //Get the primitives nums
        num_verts = read_i32(&binaryio)
        num_faces = read_i32(&binaryio)
        num_nodes = read_i32(&binaryio)

        //Get the aabbs
        m.center = read_vec3(&binaryio)
        m.extents = read_vec3(&binaryio)

        //Get the veritices
        m.verts = make([dynamic]Vertex, num_verts, num_verts, allocator)
        for v in 0..<num_verts{
            vert : Vertex
            br,err = os.read(binaryio, mem.ptr_to_bytes(&vert))
            log_if_err(err)
            m.verts[v] = vert
        }

        //Get The num_faces
        m.faces = make([dynamic]vec4i, num_faces, num_faces, allocator)
        for f in 0..<num_faces{
            face : vec4i
            br, err = os.read(binaryio, mem.ptr_to_bytes(&face))
            log_if_err(err)
            m.faces[f] = face
        }

        //For now ignore the bvh nodes
        for n in 0..<num_nodes{
            node : BVHNode
            br, err = os.read(binaryio, mem.ptr_to_bytes(&node))
            log_if_err(err)
        }
        m.mesh_id = mesh_id
        mod.meshes[i] = m
    }

    // Now get the shapes
    num_shapes := read_i32(&binaryio)
    mod.shapes = make([dynamic]Shape, num_shapes, num_shapes, allocator)
    for s in 0..<num_shapes{
        shape : Shape
        s_name_length := read_i32(&binaryio)
        s_name_bytes := make([]u8, s_name_length, allocator)
        br, err = os.read(binaryio, s_name_bytes[:])
        log_if_err(err)
        shape.name = string(s_name_bytes)

        shape.type = read_i32(&binaryio)
        shape.center = read_vec3(&binaryio)
        shape.extents = read_vec3(&binaryio)
        mod.shapes[s] = shape
    }

    // Get num transforms??? idk why
    num_transforms := read_i32(&binaryio)
    mod.unique_id = unique_id
    return mod
}

destroy_model :: proc(model : ^Model)
{
   for &m in model.meshes{
       delete(m.name)
       delete(m.faces)
       delete(m.verts)
       delete(m.bvhs)
       delete(m.mat.name)
       delete(m.mat.texture)
   }
   delete(model.meshes)
   for &s in model.shapes{
       delete(s.name)
   }
   delete(model.shapes)
   delete(model.name)
}

print_mesh :: proc(mesh : Mesh)
{
    using mesh
    num_verts := len(verts)
    num_faces := len(faces)

    fmt.println("Mesh Name: ", name, " ID: ", mesh_id, " verts: ", num_verts, " faces: ", num_faces)
    fmt.println("Center: ", center, " Extents: ", extents)
    for mv in 0..<num_verts{
        fmt.println("Vert: ", verts[mv])
    }
    for mf in 0..<num_faces{
        fmt.println("Face: ", faces[mf])
    }
}

read_i32 :: proc(io : ^os.Handle) -> i32
{
   num : i32
   num_bytes,err := os.read(io^, mem.ptr_to_bytes(&num))
   log_if_err(err)
   if(err != os.ERROR_NONE){
       fmt.print("Error reading i32: ", num, "\n")
   }
   return num
}

read_vec3 :: proc(io : ^os.Handle) -> vec3
{
    v : vec3
    num_bytes,err := os.read(io^, mem.ptr_to_bytes(&v))
    log_if_err(err)
    if(err != os.ERROR_NONE){
        fmt.print("Error reading vec3: ", v, "\n")
    }
    return v
}

log_if_err_os :: proc(e : os.Error,  loc := #caller_location){
    if e != os.ERROR_NONE {
        fmt.eprintln("Error: ", e, " at location : ", loc)
    }
}
log_if_err_b :: proc(b : bool, msg : string, loc := #caller_location)
{
   if b do fmt.eprintln("Error: ", msg, " at location: ",  loc)
}
log_if_err_j :: proc(e : json.Unmarshal_Error, loc := #caller_location)
{
   if e != nil do fmt.eprintln("Error: ", e, " at location : ", loc)
}
log_if_err :: proc{log_if_err_os, log_if_err_b, log_if_err_j}

//----------------------------------------------------------------------------\\
// /Materials /ma
//----------------------------------------------------------------------------\\
load_materials :: proc(file : string, materials : ^[dynamic]Material)
{
    doc, err := xml.load_from_file(file)
    if xml2.log_if_err(err) do return
    defer xml.destroy(doc)

    // Iterate through the materials
    nth_mat := 0
    mat_id : xml.Element_ID
    found : bool = true
    for found == true {
        mat_id, found = xml.find_child_by_ident(doc, 0, "Material", nth_mat)
        if !found do return
        //if xml2.log_if_not_found(found, "Material") do return
        nth_mat += 1

        temp_mat : Material
        temp_mat.name = strings.clone(xml2.get_str_attr(doc, mat_id, "Name"), materials^.allocator)
        temp_mat.diffuse = vec3 {
            xml2.get_f32_attr(doc, mat_id, "DiffuseR"),
            xml2.get_f32_attr(doc, mat_id, "DiffuseG"),
            xml2.get_f32_attr(doc, mat_id, "DiffuseB")
        }
        temp_mat.reflective = xml2.get_f32_attr(doc, mat_id, "Reflective")
        temp_mat.roughness = xml2.get_f32_attr(doc, mat_id, "Roughness")
        temp_mat.transparency = xml2.get_f32_attr(doc, mat_id, "Transparency")
        temp_mat.refractive_index = xml2.get_f32_attr(doc, mat_id, "Refractive")
        // temp_mat.texture_id = xml2.get_i32_attr(doc, mat_id, "TextureID")
        temp_mat.texture = strings.clone(xml2.get_str_attr(doc, mat_id, "Texture"), materials^.allocator)
        temp_mat.unique_id = i32(temp_mat.name[0])
        for i in 1..<len(temp_mat.name) {
            temp_mat.unique_id *= i32(temp_mat.name[i]) + i32(temp_mat.name[i - 1])
        }


        append(materials, temp_mat)
    }
}

//----------------------------------------------------------------------------\\
// /Load Animations /la
//----------------------------------------------------------------------------\\
load_pose :: proc(file_name, prefab_name : string, allocator: mem.Allocator) -> PoseList {
    pl: PoseList
    pl.name = strings.clone(prefab_name, allocator)
    pl.poses = make([dynamic]Pose, 0, allocator)

    doc, err := xml.load_from_file(file_name)
    if xml2.log_if_err(err) do return pl
    defer xml.destroy(doc)

    // Iterate through "Pose" elements
    pose_id : xml.Element_ID
    found : bool = true
    nth_pose := 0
    for found == true{
        pose_id, found = xml.find_child_by_ident(doc, 0, "Pose", nth_pose)
        if(!found){
            if(nth_pose == 0){
                log.warnf("No poses found in %v.", file_name)
            }
            return pl
        }
       nth_pose += 1

        temp_pose: Pose
        temp_pose.name = xml2.get_str_attr(doc, pose_id, "Name")
        // Initialize dynamic array for PoseSqts
        temp_pose.pose = make([dynamic]PoseSqt, allocator)

        // Iterate through "Tran" elements for the current pose
        tran_id : xml.Element_ID
        nth_tran := 0
        tran_found : bool = true
        for tran_found == true{
            tran_id, tran_found = xml.find_child_by_ident(doc, pose_id, "Tran", nth_tran)
            if !tran_found {
                break // No more Tran elements for this Pose
            }
            nth_tran += 1

            cn_val := xml2.get_i32_attr(doc, tran_id, "CN")
            current_sqt_data: Sqt

            // Get "Pos" element and its attributes
            pos_id, pos_sub_elem_found := xml.find_child_by_ident(doc, tran_id, "Pos", 0)
            if pos_sub_elem_found {
                current_sqt_data.pos.x = xml2.get_f32_attr(doc, pos_id, "x")
                current_sqt_data.pos.y = xml2.get_f32_attr(doc, pos_id, "y")
                current_sqt_data.pos.z = xml2.get_f32_attr(doc, pos_id, "z")
                current_sqt_data.pos.w = 1.0 // Set w component for position
            } else {
                log.warnf("Pose '%v', Tran #%v (CN %v): Missing 'Pos' element in %v. Using default (0,0,0,1).", temp_pose.name, nth_tran-1, cn_val, file_name)
                current_sqt_data.pos = {0,0,0,1} // Default position
            }

            // Get "Rot" element and its attributes
            rot_id, rot_sub_elem_found := xml.find_child_by_ident(doc, tran_id, "Rot", 0)
            if rot_sub_elem_found {
                current_sqt_data.rot.x = xml2.get_f32_attr(doc, rot_id, "x")
                current_sqt_data.rot.y = xml2.get_f32_attr(doc, rot_id, "y")
                current_sqt_data.rot.z = xml2.get_f32_attr(doc, rot_id, "z")
                current_sqt_data.rot.w = xml2.get_f32_attr(doc, rot_id, "w")
            } else {
                log.warnf("Pose '%v', Tran #%v (CN %v): Missing 'Rot' element in %v. Using default identity quaternion (0,0,0,1).", temp_pose.name, nth_tran-1, cn_val, file_name)
                current_sqt_data.rot = math.QUATERNIONF32_IDENTITY
            }

            // Get "Sca" element and its attributes
            sca_id, sca_sub_elem_found := xml.find_child_by_ident(doc, tran_id, "Sca", 0)
            if sca_sub_elem_found {
                current_sqt_data.sca.x = xml2.get_f32_attr(doc, sca_id, "x")
                current_sqt_data.sca.y = xml2.get_f32_attr(doc, sca_id, "y")
                current_sqt_data.sca.z = xml2.get_f32_attr(doc, sca_id, "z")
                current_sqt_data.sca.w = 1.0 // Set w component for scale
            } else {
                log.warnf("Pose '%v', Tran #%v (CN %v): Missing 'Sca' element in %v. Using default scale (1,1,1,1).", temp_pose.name, nth_tran-1, cn_val, file_name)
                current_sqt_data.sca = {1,1,1,1} // Default scale
            }

            pose_transform_entry: PoseSqt
            pose_transform_entry.id = cn_val
            pose_transform_entry.sqt_data = current_sqt_data
            append(&temp_pose.pose, pose_transform_entry) // Changed here
        }
        append(&pl.poses, temp_pose)
    }
    return pl
}

destroy_pose_list :: proc(pl: ^PoseList) {
    for &pose in pl.poses {
        delete(pose.name)
        delete(pose.pose)
    }
    delete(pl.poses)
    delete(pl.name)
}
