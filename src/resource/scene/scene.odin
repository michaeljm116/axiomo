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
    HEADNODE    = 21,
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
    for node in scene.Node {
        flags := transmute(ComponentFlags)node.eFlags

        if .CAMERA in flags {
            fmt.printf("Processing Camera Node: %s, AspectRatio: %f, FOV: %f\n",
                node.Name, node.aspect_ratio.ratio, node.fov.fov)
            // Add logic to map to ECS components (e.g., call serialize.load_node)
        } else if .LIGHT in flags {
            fmt.printf("Processing Light Node: %s, Color: (%f, %f, %f), Intensity: %f, ID: %d\n",
                node.Name, node.color.r, node.color.g, node.color.b,
                node.intensity.i, node.id.id)
            // Add logic to map to ECS components
        } else if .PRIMITIVE in flags || .MODEL in flags || .RIGIDBODY in flags || .COLIDER in flags {
            fmt.printf("Processing Object Node: %s, Material ID: %d, Object ID: %d, Rigid: %v\n",
                node.Name, node.material.ID, node.object.ID, node.rigid.Rigid)
            if node.collider.Type != 0 {
                fmt.printf("Collider: Type=%d, Local=(%f, %f, %f), Extents=(%f, %f, %f)\n",
                    node.collider.Type,
                    node.collider.Local.x, node.collider.Local.y, node.collider.Local.z,
                    node.collider.Extents.x, node.collider.Extents.y, node.collider.Extents.z)
            }
            // Add logic to map to ECS components
        }
    }
    return scene
}
