package main

import "core:fmt"
import "core:strings"
import math "core:math/linalg"
import ecs "external/ecs"
import scene "resource/scene"
import res "resource"

//----------------------------------------------------------------------------\\
// /SAVE
//----------------------------------------------------------------------------\\

// Save a node hierarchy to scene.Node struct (for JSON marshalling)
save_node :: proc(cmp_node: ^Cmp_Node) -> scene.Node {
    scene_node := scene.Node{
        Name = strings.clone(cmp_node.name),
        hasChildren = cmp_node.is_parent,
        eFlags = transmute(u32)cmp_node.engine_flags,
        gFlags = cmp_node.game_flags,
        Dynamic = cmp_node.is_dynamic,
    }

    // Save transform if present
    if .TRANSFORM in cmp_node.engine_flags {
        trans := get_component(cmp_node.entity, Cmp_Transform)
        if trans != nil {
            scene_node.Transform = scene.Transform{
                Position = {x = trans.local.pos.x, y = trans.local.pos.y, z = trans.local.pos.z},
                Rotation = {x = trans.euler_rotation.x, y = trans.euler_rotation.y, z = trans.euler_rotation.z},
                Scale = {x = trans.local.sca.x, y = trans.local.sca.y, z = trans.local.sca.z},
            }
        }
    }

    // Determine node type and save data
    if .LIGHT in cmp_node.engine_flags {
        light := get_component(cmp_node.entity, Cmp_Light)
        if light != nil {
            scene_node.Type = .Light
            scene_node.Data = scene.LightData{
                Color = {r = light.color.r, g = light.color.g, b = light.color.b},
                Intensity = {i = light.intensity},
                ID = {id = light.id},
            }
        }
    } else if .CAMERA in cmp_node.engine_flags {
        cam := get_component(cmp_node.entity, Cmp_Camera)
        if cam != nil {
            scene_node.Type = .Camera
            scene_node.Data = scene.CameraData{
                AspectRatio = {ratio = cam.aspect_ratio},
                FOV = {fov = cam.fov},
            }
        }
    } else if .PRIMITIVE in cmp_node.engine_flags || .MODEL in cmp_node.engine_flags {
        scene_node.Type = .Object
        obj_data := scene.ObjectData{}

        // Material
        mat := get_component(cmp_node.entity, Cmp_Material)
        if mat != nil {
            obj_data.Material = scene.Material{ID = mat.mat_unique_id}
        }

        // Primitive/Object ID
        prim := get_component(cmp_node.entity, Cmp_Primitive)
        if prim != nil {
            obj_data.Object = scene.ObjectID{ID = prim.id}
        } else {
            // For model, perhaps use model ID
            model := get_component(cmp_node.entity, Cmp_Model)
            if model != nil {
                obj_data.Object = scene.ObjectID{ID = model.model_unique_id}
            }
        }

        // Rigid
        if .RIGIDBODY in cmp_node.engine_flags {
            obj_data.Rigid = scene.Rigid{Rigid = true}
        }

        // Collider
        if .COLIDER in cmp_node.engine_flags {
            // Assuming collider component exists, but not defined in provided code
            // Placeholder: you'd need to add Cmp_Collider similar to C++
            // For now, skip or assume defaults
        }

        scene_node.Data = obj_data
    }

    // Recurse for children
    if cmp_node.is_parent {
        scene_node.Children = make([dynamic]scene.Node, len(cmp_node.children))
        for child_ptr, i in cmp_node.children {
            scene_node.Children[i] = save_node(child_ptr)
        }
    }

    return scene_node
}

// Save entire scene from head node
save_scene :: proc(head_entity: Entity, scene_num: i32) -> scene.SceneData {
    head_node := get_component(head_entity, Cmp_Node)
    if head_node == nil {
        return scene.SceneData{}
    }

    scene_data := scene.SceneData{
        Scene = scene.Scene{Num = scene_num},
        Node = make([dynamic]scene.Node, 1),
    }
    scene_data.Node[0] = save_node(head_node)

    // If multiple roots, append more
    // But assuming single head for now

    return scene_data
}

//----------------------------------------------------------------------------\\
// /LOAD
//----------------------------------------------------------------------------\\

// Load a scene.Node into ECS Cmp_Node hierarchy
load_node :: proc(scene_node: scene.Node, parent: Entity = Entity(0)) -> Entity {
    entity := add_entity()

    cmp_node := Cmp_Node{
        entity = entity,
        parent = parent,
        name = strings.clone(scene_node.Name),
        is_dynamic = scene_node.Dynamic,
        is_parent = scene_node.hasChildren,
        engine_flags = transmute(ComponentFlags)scene_node.eFlags,
        game_flags = scene_node.gFlags,
    }
    add_component(entity, cmp_node)

    // Add transform
    if .TRANSFORM in cmp_node.engine_flags {
        pos := math.Vector3f32{scene_node.Transform.Position.x, scene_node.Transform.Position.y, scene_node.Transform.Position.z}
        rot := math.Vector3f32{scene_node.Transform.Rotation.x, scene_node.Transform.Rotation.y, scene_node.Transform.Rotation.z}
        sca := math.Vector3f32{scene_node.Transform.Scale.x, scene_node.Transform.Scale.y, scene_node.Transform.Scale.z}
        trans_comp := cmp_transform_prs(pos, rot, sca)
        add_component(entity, trans_comp)
    } else {
        add_component(entity, Cmp_Transform{}) // Default
        cmp_node.engine_flags += {.TRANSFORM}
    }

    // Handle type-specific components
    switch scene_node.Type {
    case .Camera:
        if data, ok := scene_node.Data.(scene.CameraData); ok {
            cam_comp := camera_component(data.AspectRatio.ratio, data.FOV.fov)
            add_component(entity, cam_comp)
            add_component(entity, Cmp_Render{type = {.CAMERA}}) // Example, adjust as needed
            cmp_node.is_parent = true
        }

    case .Light:
        if data, ok := scene_node.Data.(scene.LightData); ok {
            color := math.Vector3f32{data.Color.r, data.Color.g, data.Color.b}
            id_int := data.ID.id
            light_comp := light_component(color, data.Intensity.i, id_int)
            add_component(entity, light_comp)
            add_component(entity, Cmp_Render{type = {.LIGHT}})
            cmp_node.is_parent = true
        }

    case .Object:
        if data, ok := scene_node.Data.(scene.ObjectData); ok {
            // Material
            mat_id := data.Material.ID
            mat_comp := material_component(i32(mat_id))
            add_component(entity, mat_comp)

            // Object/Primitive
            obj_id := data.Object.ID
            prim_comp := primitive_component(i32(obj_id))
            add_component(entity, prim_comp)
            add_component(entity, Cmp_Render{type = {.PRIMITIVE}})

            // Rigid
            if data.Rigid.Rigid {
                cmp_node.engine_flags += {.RIGIDBODY}
                // Add physics components if needed
            }

            // Collider
            if data.Collider.Type != 0 { // Assuming presence indicates collider
                coll_type := data.Collider.Type // Parse type
                local := math.Vector3f32{data.Collider.Local.x, data.Collider.Local.y, data.Collider.Local.z}
                extents := math.Vector3f32{data.Collider.Extents.x, data.Collider.Extents.y, data.Collider.Extents.z}
                // Add Cmp_Collider if defined, e.g. add_component(entity, Cmp_Collider{local=local, extents=extents, type=coll_type})
                cmp_node.engine_flags += {.COLIDER}
            }
        }
    }

    // Handle other flags/components as in C++
    // e.g. Prefab, GUI, etc. - add similar logic if components are defined

    // If head node
    if .HEADNODE in cmp_node.engine_flags {
        add_component(entity, Cmp_HeadNode{})
    }

    // Recurse for children
    if scene_node.hasChildren {
        for child in scene_node.Children {
            child_entity := load_node(child, entity)
            child_node := get_component(child_entity, Cmp_Node)
            if child_node != nil {
                append(&cmp_node.children, child_node)
            }
        }
    }

    // Refresh entity if needed
    // entity.refresh() - if ECS has such method
    return entity
}

// Load entire scene
load_scene :: proc(scene_data: scene.SceneData){
    if len(scene_data.Node) == 0 {
        return// Entity(0)
    }
    for node in scene_data.Node{
        load_node(node)
    }
}