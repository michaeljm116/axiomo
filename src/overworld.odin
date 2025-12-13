package game

import "core:fmt"
import "core:mem"
import "core:math"
import "vendor:glfw"
import "axiom"
import "axiom/resource"
import "core:log"
import b2 "vendor:box2d"

CollisionCategory :: enum
{
    Player,
    Enemy,
    Projectile,
    EnemyProjectile,
    Environment,
    MovingEnvironment,
    MovingFloor
}
CollisionCategories :: bit_set[CollisionCategory; u64]


ContactDensities :: struct
{
    Player : f32,
    Vax : f32,
    Doctor : f32,
    Projectiles : f32,
    Wall : f32
}

g_contact_identifier := ContactDensities {
	Player      = 9.0,
	Vax         = 50.0,
	Doctor      = 200.0,
	Projectiles = 8.0,
	Wall        = 800.0
}


overworld_start :: proc() {
	load_scene("Overworld")
	g.player = axiom.load_prefab("Froku", g.mem_game.alloc)

	axiom.sys_trans_process_ecs()
}

overworld_update :: proc(){

}

overworld_update_player_movement :: proc(player : Entity, delta_time: f32){
    cc := get_component(player, Cmp_Collision2D)
    if cc == nil do return
    vel := b2.Body_GetLinearVelocity(cc.bodyid).y
    move_speed :f32= 0.40
    if is_key_pressed(glfw.KEY_SPACE) do vel += move_speed
    b2.Body_SetLinearVelocity(cc.bodyid, {0,vel})
    // b2.Body_ApplyForceToCenter(cc.bodyid, {0,100}, true)
    // fmt.println("Entity ",g.player, " | Force : ", b2.Body_GetLinearVelocity(cc.bodyid), " | ")
    // fmt.println("Entity ",g.player, " | Position : ", b2.Body_GetPosition(cc.bodyid), " | ")
}

overworld_setup_col_player :: proc(physics : ^axiom.Sys_Physics){
    find_player_entity()
    pt := get_component(g.player, Cmp_Transform)
    // Build collision components. Body position is the body origin in world space.
    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Capsule,
        flags = {.Player}
    }
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    // Place the body origin at the transform world position (pt.world[3] should be the object's world origin)
    col.bodydef.position = pt.world[3].xy
    col.bodyid = b2.CreateBody(physics.world_id, col.bodydef)

    // Define the capsule in body-local coordinates (centered on the body origin).
    // Use half extents from the transform scale. magic_scale_number still applied to y if needed.
    box := b2.MakeBox(pt.local.sca.x,pt.local.sca.y)
    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.Player})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Environment, .MovingEnvironment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = g_contact_identifier.Player
    // col.shapeid = b2.CreateCapsuleShape(col.bodyid, col.shapedef, capsule)
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    add_component(g.player, col)
    //add_component(g.player, capsule)
}

overworld_setup_col_floor :: proc(physics : ^axiom.Sys_Physics){
    //create static floor
    {
        col := Cmp_Collision2D{
            bodydef = b2.DefaultBodyDef(),
            shapedef = b2.DefaultShapeDef(),
            type = .Box
        }
        col.bodydef.fixedRotation = true
        col.bodydef.type = .staticBody
        col.bodydef.position = {0,-2.0}
        col.bodyid = b2.CreateBody(physics.world_id, col.bodydef)
        box := b2.MakeBox(500, 1.0)

        col.shapedef = b2.DefaultShapeDef()
        col.shapedef.filter.categoryBits = u64(CollisionCategories{.Environment})
        col.shapedef.filter.maskBits = u64(CollisionCategories{.Player, .MovingEnvironment, .MovingFloor, .Environment, .Enemy})
        col.shapedef.enableContactEvents = true
        col.shapedef.density = 10000
        col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)
    }

    find_floor_entities()
    fc := get_component(g.floor, Cmp_Transform)
    col := Cmp_Collision2D{
        bodydef = b2.DefaultBodyDef(),
        shapedef = b2.DefaultShapeDef(),
        type = .Box,
        flags = {.Movable, .Floor}
    }
    // move := Cmp_Movable{speed = -2.0}
    col.bodydef.fixedRotation = true
    col.bodydef.type = .dynamicBody
    col.bodydef.position = {fc.world[3].x, fc.world[3].y - 1}
    col.bodydef.gravityScale = 0
    col.bodyid = b2.CreateBody(physics.world_id, col.bodydef)
    box := b2.MakeBox(fc.local.sca.x, fc.local.sca.y)

    col.shapedef = b2.DefaultShapeDef()
    col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingFloor})
    col.shapedef.filter.maskBits = u64(CollisionCategories{.Environment})
    col.shapedef.enableContactEvents = true
    col.shapedef.density = 1000.0
    col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

    add_component(g.floor, col)
}

// barrel : Entity
// create_barrel :: proc(pos : b2.Vec2)
// {
//     fmt.println("Barrel creating")
//     barrel = load_prefab("Barrel")
//     fmt.println("Prefab loaded")
//     bt := get_component(barrel, Cmp_Transform)
//     if bt == nil do return

//     col := Cmp_Collision2D{
//         bodydef = b2.DefaultBodyDef(),
//         shapedef = b2.DefaultShapeDef(),
//         type = .Box,
//         flags = CollisionFlags{.Movable}
//     }
//     col.bodydef.fixedRotation = true
//     col.bodydef.type = .dynamicBody
//     // Body position must be scaled to Box2D units
//     col.bodydef.position = b2.Vec2{ pos.x * g_b2scale, pos.y * g_b2scale }
//     col.bodyid = b2.CreateBody(g_world_id, col.bodydef)

//     // Scale shape extents to Box2D units (bt.local.sca holds half-extents in our transform)
//     box := b2.MakeBox(bt.local.sca.x * g_b2scale, bt.local.sca.y * 2 * g_b2scale)
//     col.shapedef = b2.DefaultShapeDef()
//     col.shapedef.filter.categoryBits = u64(CollisionCategories{.MovingEnvironment})
//     col.shapedef.filter.maskBits = u64(CollisionCategories{.Enemy,.EnemyProjectile,.Player, .Environment, .MovingEnvironment})
//     col.shapedef.enableContactEvents = true
//     col.shapedef.density = g_contact_identifier.Player
//     col.shapeid = b2.CreatePolygonShape(col.bodyid, col.shapedef, box)

//     // movable := Cmp_Movable{-1.0}

//     fmt.println("Movable component added")
//     add_component(barrel, col)
//     fmt.println("Collision component added")
//     //add_component(barrel, movable)
// }
// update_movables :: proc(delta_time: f32)
// {
//     //First just the visible g.floor
//     for i in 0..<2{
//         fc := get_component(g.floor, Cmp_Transform)
//         fc.local.pos.x -= 1.0 * delta_time

//         //refresh world if done
//         if fc.local.pos.x <= -100.0 {
//             fmt.println("Floor  ", i, "  | Trans: ", fc.local.pos.xy)
//             for e in g_objects[curr_phase] do remove_entity(e)
//             vmem.arena_free_all(&distance_arena[curr_phase])
//             curr_phase = (curr_phase + 1) % 2

//             col := get_component(g.floor, Cmp_Collision2D)
//             fc.local.pos.x += 200.0
//             trans := b2.Body_GetTransform(col.bodyid)
//             trans.p.x = fc.local.pos.x
//             b2.Body_SetTransform(col.bodyid, trans.p, trans.q)
//         }
//     }
//     movables := query(has(Cmp_Collision2D))
//     for movable in movables{
//         cols := get_table(movable, Cmp_Collision2D)
//         for e, i in movable.entities{
//             if .Movable in cols[i].flags{
//                 nc := get_component(e, Cmp_Node)
//                 tc := get_component(e, Cmp_Transform)
//                 // fmt.println("movable, ", nc.name)
//                 // b2.Body_SetLinearVelocity(cols[i].bodyid, {delta_time * -1.0, 0})
//                 // b2.Body_ApplyLinearImpulse(cols[i].bodyid, {-2.0,0}, {0.5,0.5}, true)
//                 vel := b2.Body_GetLinearVelocity(cols[i].bodyid)
//                 vel.x = -4
//                 b2.Body_SetLinearVelocity(cols[i].bodyid, vel)
//                 // b2.Body_ApplyForceToCenter(cols[i].bodyid, {0,1000.0}, true)
//                 //fmt.printfln("Entity")
//                 // fmt.println("Entity: ",nc.name, " | Position : ", b2.Body_GetPosition(cols[i].bodyid), " | Trans: ", tc.local.pos.xy)
//             }
//         }
//     }
// }
