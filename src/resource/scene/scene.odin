package scene
import res "../../resource"
import math "core:math/linalg"
import "core:os"
import "core:io"
import "core:fmt"
import "core:encoding/json"

//----------------------------------------------------------------------------\\
// /STRUCTS
//----------------------------------------------------------------------------\\

Scene :: struct {
    Num: i32 `json:"_Num"`,
}

// SceneData is the top-level struct
SceneData :: struct {
    Scene: Scene,
    Node: [dynamic]Node,
}

// Vector3 maps to JSON objects with _x, _y, _z fields
Vector3 :: struct {
    x: f32 `json:"_x"`,
    y: f32 `json:"_y"`,
    z: f32 `json:"_z"`,
}

// Transform maps to Position, Rotation, Scale
Transform :: struct {
    Position: Vector3,
    Rotation: Vector3,
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

// NodeType to distinguish node types
NodeType :: enum {
    Camera,
    Light,
    Object,
}

// NodeData union for type-specific fields
NodeData :: union {
    CameraData,
    LightData,
    ObjectData,

}

// Camera-specific data
CameraData :: struct {
    AspectRatio: AspectRatio,
    FOV: FOV,
}

// Light-specific data
LightData :: struct {
    Color: Color,
    Intensity: Intensity,
    ID: ID,
}

// Object-specific data
ObjectData :: struct {
    Material: Material,
    Object: ObjectID,
    Rigid: Rigid,
    Collider: Collider,
}

// Node struct for each node in the array
Node :: struct {
    Type: NodeType, // Determined during unmarshalling
    Transform: Transform,
    Name: string `json:"_Name"`,
    hasChildren: bool `json:"_hasChildren"`,
    Children: [dynamic]Node,
    eFlags: u32 `json:"_eFlags"`,
    gFlags: i64 `json:"_gFlags"`,
    Dynamic: bool `json:"_Dynamic"`,
    Data: NodeData,
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

    return scene
}
