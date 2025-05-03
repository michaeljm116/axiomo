package main
import math"core:math/linalg"
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
import "core:mem"
import "core:strconv"
import "extensions/xml2"
//----------------------------------------------------------------------------\\
// /LoadModel /lm
//----------------------------------------------------------------------------\\
load_pmodel :: proc(file_name : string) -> Model
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
            fmt.print(rune(c))
        }
    }

    // Read the Name, First get the length, then assemble the string
    name_length = read_i32(&binaryio)
    if name_length > 0 {
        name_bytes := make([]u8, name_length)//, context.temp_allocator)
        br, err = os.read(binaryio, name_bytes[:])
        log_if_err(err)
        mod.name = string(name_bytes[:])
    }

    // Read the unique id and num meshes
    unique_id = read_i32(&binaryio)
    num_mesh = read_i32(&binaryio)

    // Assemble the meshes
    mod.meshes = make([dynamic]Mesh, num_mesh)
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
            name_bytes := make([]u8, mesh_name_length)
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
        m.verts = make([dynamic]Vertex, num_verts)
        for v in 0..<num_verts{
            vert : Vertex
            br,err = os.read(binaryio, mem.ptr_to_bytes(&vert))
            log_if_err(err)
            m.verts[v] = vert
        }

        //Get The num_faces
        m.faces = make([dynamic]vec4i, num_faces)
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
    mod.shapes = make([dynamic]Shape, num_shapes)
    for s in 0..<num_shapes{
        shape : Shape
        s_name_length := read_i32(&binaryio)
        s_name_bytes := make([]u8, s_name_length)
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
    return mod
}

destroy_model :: proc(model : ^Model)
{
   for &m in model.meshes{
       delete(m.name)
       delete(m.faces)
       delete(m.verts)
       delete(m.mat.name)
       delete(m.mat.texture)
   }
   delete(model.meshes)
   for &s in model.shapes{
       delete(s.name)
   }
   delete(model.shapes)
   delete(model.bvhs)
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

log_if_err :: proc(e : os.Error,  loc := #caller_location){
    if e != os.ERROR_NONE {
        fmt.eprintln("Error: ", e, " at location : ", loc)
    }
}



//----------------------------------------------------------------------------\\
// /LoadMaterials /lm
//----------------------------------------------------------------------------\\
res_load_materials :: proc(file : string, materials : ^[dynamic]Material)
{
    doc, err := xml.load_from_file(file)
    if xml2.log_if_err(err) do return
    defer xml.destroy(doc)

    // Find the Root
    //root_id, found : (u32, bool) = (0, true)// xml.find_child_by_ident(doc, 0, "Root")
    root_id : u32 = 0
    found : bool = true
    if xml2.log_if_not_found(found) do return

    // Iterate through the materials
    nth_mat := 0
    curr_id := root_id
    mat_id : xml.Element_ID
    for found == true {
        mat_id, found = xml.find_child_by_ident(doc, curr_id, "Material", nth_mat)
        if xml2.log_if_not_found(found) do return
        nth_mat += 1

        temp_mat : Material
        temp_mat.name = xml2.get_str_attr(doc, mat_id, "Name")
        temp_mat.diffuse = vec3 {
            xml2.get_f32_attr(doc, mat_id, "DiffuseR"),
            xml2.get_f32_attr(doc, mat_id, "DiffuseG"),
            xml2.get_f32_attr(doc, mat_id, "DiffuseB")
        }
        temp_mat.reflective = xml2.get_f32_attr(doc, mat_id, "Reflective")
        temp_mat.roughness = xml2.get_f32_attr(doc, mat_id, "Roughness")
        temp_mat.transparency = xml2.get_f32_attr(doc, mat_id, "Transparency")
        temp_mat.refractive_index = xml2.get_f32_attr(doc, mat_id, "Refractive")
        temp_mat.texture_id = xml2.get_i32_attr(doc, mat_id, "TextureID")

        append(materials, temp_mat)
    }
}


//----------------------------------------------------------------------------\\
// /LoadPose /lp
//----------------------------------------------------------------------------\\

/*res_load_pose :: proc(file_name, prefab : string) -> bool
{
    doc, err := xml.load_from_file(file_name)
    is_err := xml2.log_if_err(err)
    defer xml.free(doc)
    if(is_err){
        return false
    }

    // Get the root element
    // Find the root element
    root_id, found := xml_helpers.find_child_by_ident(doc, 0, "Root")
    if !found {
        return false
    }

    // Prepare pose list
    pl: rPoseList
    pl.name = prefab
    pl.hashVal = xxhash.XXH32([]u8(prefab))

    // Iterate through Pose elements
    nth_pose := 0
    for {
        pose_id, found := xml_helpers.find_child_by_ident(doc, root_id, "Pose", nth_pose)
        if !found {
            break
        }
        nth_pose += 1

        pose: rPose

        // Get the Name attribute
        name, name_found := xml_helpers.find_attribute_val_by_key(doc, pose_id, "Name")
        if name_found {
            pose.name = name
            pose.hashVal = xxhash.XXH32([]u8name)
        }

        // Iterate through Tran elements
        nth_tran := 0
        for {
            tran_id, found := xml_helpers.find_child_by_ident(doc, pose_id, "Tran", nth_tran)
            if !found {
                break
            }
            nth_tran += 1

            i: int
            t: sqt

            // Get CN attribute
            cn_str, cn_found := xml_helpers.find_attribute_val_by_key(doc, tran_id, "CN")
            if cn_found {
                i = strings.atoi(cn_str)
            }

            // Find Pos, Rot, Sca children
            pos_id, pos_found := xml_helpers.find_child_by_ident(doc, tran_id, "Pos")
            rot_id, rot_found := xml_helpers.find_child_by_ident(doc, tran_id, "Rot")
            sca_id, sca_found := xml_helpers.find_child_by_ident(doc, tran_id, "Sca")

            // Read Pos
            if pos_found {
                x, _ := xml_helpers.find_attribute_val_by_key(doc, pos_id, "x")
                y, _ := xml_helpers.find_attribute_val_by_key(doc, pos_id, "y")
                z, _ := xml_helpers.find_attribute_val_by_key(doc, pos_id, "z")
                t.position.x = strings.atof(x)
                t.position.y = strings.atof(y)
                t.position.z = strings.atof(z)
            }
            // Read Rot
            if rot_found {
                x, _ := xml_helpers.find_attribute_val_by_key(doc, rot_id, "x")
                y, _ := xml_helpers.find_attribute_val_by_key(doc, rot_id, "y")
                z, _ := xml_helpers.find_attribute_val_by_key(doc, rot_id, "z")
                w, _ := xml_helpers.find_attribute_val_by_key(doc, rot_id, "w")
                t.rotation.x = strings.atof(x)
                t.rotation.y = strings.atof(y)
                t.rotation.z = strings.atof(z)
                t.rotation.w = strings.atof(w)
            }
            // Read Sca
            if sca_found {
                x, _ := xml_helpers.find_attribute_val_by_key(doc, sca_id, "x")
                y, _ := xml_helpers.find_attribute_val_by_key(doc, sca_id, "y")
                z, _ := xml_helpers.find_attribute_val_by_key(doc, sca_id, "z")
                t.scale.x = strings.atof(x)
                t.scale.y = strings.atof(y)
                t.scale.z = strings.atof(z)
            }

            pose.pose.append((i, t))
        }

        pl.poses.append(pose)
    }

    poses.append(pl) // Make sure 'poses' is defined in your context
    return true
    }*/