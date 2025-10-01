package scene
import res "../../resource"
import math "core:math/linalg"
import "core:os"
import "core:io"
import "core:fmt"
import "core:encoding/json"
import path2 "../../extensions/filepath2"
import "core:strings"
//----------------------------------------------------------------------------\\
// /STRUCTS
//----------------------------------------------------------------------------\\

ComponentFlag :: enum {
    NODE        = 0,
    TRANSFORM   = 1,
    MATERIAL    = 2,
    LIGHT       = 3,
    CAMERA      = 4,
    MODEL       = 5,
    MESH        = 6,
    BOX         = 7,
    SPHERE      = 8,
    PLANE       = 9,
    AABB        = 10,
    CYLINDER    = 11,
    SKINNED     = 12,
    RIGIDBODY   = 13,
    CCONTROLLER = 14,
    PRIMITIVE   = 15,
    COLIDER     = 16,
    IMPULSE     = 17,
    GUI         = 18,
    BUTTON      = 19,
    JOINT       = 20,
    ROOT        = 21,
    PREFAB      = 22,
}
ComponentFlags :: bit_set[ComponentFlag; u32]

Scene :: struct {
    Num: i32 `json:"_Num"`,
}

// SceneData is the top-level struct
SceneData :: struct {
    Scene: Scene,
    Node: [dynamic]Node,
}

PrefabData :: struct {
    Name: string `json:"_Name"`,
    Node: [dynamic]Node
}
Vector2 :: struct {
    x: f32 `json:"_x"`,
    y: f32 `json:"_y"`,
}

Texture :: struct {
    Name: string `json:"_name"`
}

Vector3 :: struct {
    x: f32 `json:"_x"`,
    y: f32 `json:"_y"`,
    z: f32 `json:"_z"`,
}

// Vector3 maps to JSON objects with _x, _y, _z fields
Vector4 :: struct {
    i: f32 `json:"_x"`,
    j: f32 `json:"_y"`,
    k: f32 `json:"_z"`,
    w: f32 `json:"_w"`,
}
// Transform maps to Position, Rotation, Scale
Transform :: struct {
    Position: Vector3,
    Rotation: Vector4,
    Scale: Vector3,
}

// AspectRatio for Camera nodes
AspectRatio :: struct {
    ratio: f32 `json:"_ratio"`,
}

// FOV for Camera nodes
FOV :: struct {
    fov: f32 `json:"_fov"`,
}

// Color for Light nodes
Color :: struct {
    r: f32 `json:"_r"`,
    g: f32 `json:"_g"`,
    b: f32 `json:"_b"`,
}

// Intensity for Light nodes
Intensity :: struct {
    i: f32 `json:"_i"`,
}

// ID for Light nodes
ID :: struct {
    id: i32 `json:"_id"`,
}

// Material for Object nodes
Material :: struct {
    ID: i32 `json:"_ID"`,
}

// ObjectID for Object nodes
ObjectID :: struct {
    ID: i32 `json:"_ID"`,
}

// Rigid for Object nodes
Rigid :: struct {
    Rigid: bool `json:"_Rigid"`,
}

// Collider for Object nodes
Collider :: struct {
    Local: Vector3,
    Extents: Vector3,
    Type: i32 `json:"_Type"`,
}

Gui :: struct{
    AlignExt : Vector2,
    Alignment : Vector2,
    Extent : Vector2,
    Position : Vector2,
    Texture : Texture
}

// Node struct for each node in the array
Node :: struct {
    Transform: Transform,
    Name: string `json:"_Name"`,
    hasChildren: bool `json:"_hasChildren"`,
    Children: [dynamic]Node `json:"Node"`,
    eFlags: u32 `json:"_eFlags"`,
    gFlags: i64 `json:"_gFlags"`,
    Dynamic: bool `json:"_Dynamic"`,
    aspect_ratio: AspectRatio `json:"AspectRatio"`,
    fov: FOV `json:"FOV"`,
    color: Color `json:"Color"`,
    intensity: Intensity `json:"Intensity"`,
    id: ID `json:"ID"`,
    material: Material `json:"Material"`,
    object: ObjectID `json:"Object"`,
    rigid: Rigid `json:"Rigid"`,
    collider: Collider `json:"Collider"`,
    gui: Gui `json:"GUI"`,
}
//----------------------------------------------------------------------------\\
// /PROCS
//----------------------------------------------------------------------------\\

load_new_scene :: proc(name : string, allocator := context.temp_allocator) -> SceneData {
    data, ok := os.read_entire_file_from_filename(name, allocator)
    res.log_if_err(!ok, fmt.tprintf("Finding file(%s)",name))

    scene: SceneData
    json_err := json.unmarshal(data, &scene, allocator = allocator);
    res.log_if_err(json_err)

    // Process scene and nodes
    // for node in scene.Node {
    //     load_node(node)
    // }
    return scene
}

load_prefab_node :: proc(name: string, alloc := context.allocator) -> (root: Node) {
    data, ok := os.read_entire_file_from_filename(name, alloc)
    res.log_if_err(!ok, fmt.tprintf("Finding Prefab(%s)", name))
    json_err := json.unmarshal(data, &root, allocator = alloc)
    // If there's a JSON error, print helpful debug info: filename, data length and first bytes
    if json_err != nil {
        fmt.printf("DEBUG: JSON unmarshal error loading prefab '%s': %v\n", name, json_err)
        if data != nil && len(data) > 0 {
            maxb := len(data)
            if maxb > 64 { maxb = 64 } // print up to first 64 bytes
            fmt.printf("DEBUG: prefab '%s' data length=%d first_%d_bytes= ", name, len(data), maxb)
            for i in 0..<maxb {
                // Print hex bytes for easier inspection of corrupted/incorrect data
                fmt.printf("%02X ", int(data[i]))
            }
            fmt.printf("\n")
        } else {
            fmt.printf("DEBUG: prefab '%s' has empty data buffer\n", name)
        }
    }
    res.log_if_err(json_err)
    return
}

load_prefab_directory :: proc(directory : string, prefabs : ^map[string]Node, alloc := context.allocator){
    context.allocator = alloc
    files := path2.get_dir_files(directory)
    for f in files{
        stem := path2.get_file_stem(f.name, context.temp_allocator)
        if strings.compare(".json", stem) == 0 {
            prefab := load_prefab_node(f.fullpath, alloc)
            e_flags := transmute(ComponentFlags)prefab.eFlags
            if(.ROOT not_in e_flags){
                e_flags += {.ROOT}
            }
            prefab.eFlags = transmute(u32)e_flags
            prefabs[prefab.Name] = prefab
        }
    }
    os.file_info_slice_delete(files)
}
