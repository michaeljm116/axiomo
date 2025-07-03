package scene
import res "../../resource"
import math "core:math/linalg"
import "core:os"
import "core:io"
import "core:fmt"
import "core:encoding/json"

load_new_scene :: proc(name : string, allocator := context.temp_allocator) {
    data, ok := os.read_entire_file_from_filename(name, allocator)
    res.log_if_err(!ok, fmt.tprintf("Finding file(%s)",name))

    scene: SceneData
    json_err := json.unmarshal(data, &scene, allocator = allocator);
    res.log_if_err(json_err)

    // Process scene and nodes
    for node in scene.Node {

        switch node.Type {
        case .Camera:
            if camera_data, ok := node.Data.(CameraData); ok {
                // Handle camera
            }
        case .Light:
            if light_data, ok := node.Data.(LightData); ok {
                // Handle light
            }
        case .Object:
            if object_data, ok := node.Data.(ObjectData); ok {
                // Handle object
            }
        }
    }
}
