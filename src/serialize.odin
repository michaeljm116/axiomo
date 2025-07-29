package main

import "core:fmt"
import math "core:math/linalg"
import "core:strings"
import ecs "external/ecs"
import res "resource"
import scene "resource/scene"

//----------------------------------------------------------------------------\\
// /SAVE
//----------------------------------------------------------------------------\\

// Save a node hierarchy to scene.Node struct (for JSON marshalling)
save_node :: proc(cmp_node: ^Cmp_Node) -> scene.Node {
	scene_node := scene.Node {
		Name        = strings.clone(cmp_node.name),
		hasChildren = cmp_node.is_parent,
		eFlags      = transmute(u32)cmp_node.engine_flags,
		gFlags      = cmp_node.game_flags,
		Dynamic     = cmp_node.is_dynamic,
	}

	// Save transform if present
	if .TRANSFORM in cmp_node.engine_flags {
		trans := get_component(cmp_node.entity, Cmp_Transform)
		if trans != nil {
			scene_node.Transform = scene.Transform {
				Position = {x = trans.local.pos.x, y = trans.local.pos.y, z = trans.local.pos.z},
				Rotation = {
					x = trans.euler_rotation.x,
					y = trans.euler_rotation.y,
					z = trans.euler_rotation.z,
				},
				Scale = {x = trans.local.sca.x, y = trans.local.sca.y, z = trans.local.sca.z},
			}
		}
	}

	// Save data based on flags
	if .LIGHT in cmp_node.engine_flags {
		light := get_component(cmp_node.entity, Cmp_Light)
		if light != nil {
			scene_node.color = scene.Color {
				r = light.color.r,
				g = light.color.g,
				b = light.color.b,
			}
			scene_node.intensity = scene.Intensity {
				i = light.intensity,
			}
			scene_node.id = scene.ID {
				id = light.id,
			}
		}
	} else if .CAMERA in cmp_node.engine_flags {
		cam := get_component(cmp_node.entity, Cmp_Camera)
		if cam != nil {
			scene_node.aspect_ratio = scene.AspectRatio {
				ratio = cam.aspect_ratio,
			}
			scene_node.fov = scene.FOV {
				fov = cam.fov,
			}
		}
	} else if .PRIMITIVE in cmp_node.engine_flags || .MODEL in cmp_node.engine_flags {
		// Material
		mat := get_component(cmp_node.entity, Cmp_Material)
		if mat != nil {
			scene_node.material = scene.Material {
				ID = mat.mat_unique_id,
			}
		}

		// Primitive/Object ID
		prim := get_component(cmp_node.entity, Cmp_Primitive)
		if prim != nil {
			scene_node.object = scene.ObjectID {
				ID = prim.id,
			}
		} else {
			// For model, perhaps use model ID
			model := get_component(cmp_node.entity, Cmp_Model)
			if model != nil {
				scene_node.object = scene.ObjectID {
					ID = model.model_unique_id,
				}
			}
		}

		// Rigid
		if .RIGIDBODY in cmp_node.engine_flags {
			scene_node.rigid = scene.Rigid {
				Rigid = true,
			}
		}

		// Collider
		if .COLIDER in cmp_node.engine_flags {
			// Assuming collider component exists, e.g. Cmp_Collider
			// coll := get_component(cmp_node.entity, Cmp_Collider)
			// if coll != nil {
			//     scene_node.collider = scene.Collider{
			//         Local = {x = coll.local.x, y = coll.local.y, z = coll.local.z},
			//         Extents = {x = coll.extents.x, y = coll.extents.y, z = coll.extents.z},
			//         Type = i32(coll.type),
			//     }
			// }
		}
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

	scene_data := scene.SceneData {
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

	cmp_node := Cmp_Node {
		entity       = entity,
		parent       = parent,
		name         = strings.clone(scene_node.Name),
		is_dynamic   = scene_node.Dynamic,
		is_parent    = scene_node.hasChildren,
		engine_flags = transmute(ComponentFlags)scene_node.eFlags,
		game_flags   = scene_node.gFlags,
	}
	add_component(entity, cmp_node)

	// Add transform
	if .TRANSFORM in cmp_node.engine_flags {
		pos := math.Vector3f32 {
			scene_node.Transform.Position.x,
			scene_node.Transform.Position.y,
			scene_node.Transform.Position.z,
		}
		rot := math.Vector3f32 {
			scene_node.Transform.Rotation.x,
			scene_node.Transform.Rotation.y,
			scene_node.Transform.Rotation.z,
		}
		sca := math.Vector3f32 {
			scene_node.Transform.Scale.x,
			scene_node.Transform.Scale.y,
			scene_node.Transform.Scale.z,
		}
		trans_comp := cmp_transform_prs(pos, rot, sca)
		add_component(entity, trans_comp)
	} else {
		add_component(entity, Cmp_Transform{}) // Default
		cmp_node.engine_flags += {.TRANSFORM}
	}

	// Handle type-specific components
	if .CAMERA in cmp_node.engine_flags {
		cam_comp := camera_component(scene_node.aspect_ratio.ratio, scene_node.fov.fov)
		add_component(entity, cam_comp)
		add_component(entity, Cmp_Render{type = {.CAMERA}}) // Example, adjust as needed
		added_entity(entity)
		cmp_node.is_parent = true
	}
	if .LIGHT in cmp_node.engine_flags {
		color := math.Vector3f32{scene_node.color.r, scene_node.color.g, scene_node.color.b}
		light_comp := light_component(color, scene_node.intensity.i, scene_node.id.id)
		add_component(entity, light_comp)
		add_component(entity, Cmp_Render{type = {.LIGHT}})
		added_entity(entity)
		cmp_node.is_parent = true
	}
	if .PRIMITIVE in cmp_node.engine_flags {
		// Material
		mat_id := scene_node.material.ID
		mat_uid := get_material_index(mat_id)
		mat_comp := material_component(i32(mat_id), mat_uid)
		add_component(entity, mat_comp)
		// Object/Primitive
		obj_id := scene_node.object.ID
		prim_comp := primitive_component(i32(obj_id))

		add_component(entity, prim_comp)
		add_component(entity, Cmp_Render{type = {.PRIMITIVE}})
		added_entity(entity)

		// Rigid
		if scene_node.rigid.Rigid {
			cmp_node.engine_flags += {.RIGIDBODY}
			// Add physics components if needed
		}

		// Collider
		if scene_node.collider.Type != 0 { 	// Assuming presence indicates collider
			coll_type := scene_node.collider.Type
			local := math.Vector3f32 {
				scene_node.collider.Local.x,
				scene_node.collider.Local.y,
				scene_node.collider.Local.z,
			}
			extents := math.Vector3f32 {
				scene_node.collider.Extents.x,
				scene_node.collider.Extents.y,
				scene_node.collider.Extents.z,
			}
			// Add Cmp_Collider if defined, e.g. add_component(entity, Cmp_Collider{local=local, extents=extents, type=coll_type})
			cmp_node.engine_flags += {.COLIDER}
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
load_scene :: proc(scene_data: scene.SceneData) {
	if len(scene_data.Node) == 0 {
		return // Entity(0)
	}
	for node in scene_data.Node {
		load_node(node)
	}
}
