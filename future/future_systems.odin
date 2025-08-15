
//----------------------------------------------------------------------------\\
// /Physics System /ps
//----------------------------------------------------------------------------\\
// Global map (init in sys_init)
entity_body_map: map[jolt.BodyID]Entity

// Layers unchanged

// Callbacks now "c" with user_data (nil here)
object_layer_pair_should_collide :: proc "c" (user_data: rawptr, layer1, layer2: u16) -> bool {
    context = runtime.default_context()
    l1 := ObjectLayer(layer1)
    l2 := ObjectLayer(layer2)
    return l1 == .MOVING || l2 == .MOVING  // Example: moving collides with everything
}

object_vs_broadphase_should_collide :: proc "c" (user_data: rawptr, object_layer: u16, broad_layer: jolt.Broad_Phase_Layer) -> bool {
    context = runtime.default_context()
    obj := ObjectLayer(object_layer)
    broad := BroadPhaseLayer(broad_layer)
    return (obj == .NON_MOVING && broad == .NON_MOVING) || (obj == .MOVING && broad == .MOVING)
}

// Contact callback (improved with state handling)
contact_on_added :: proc "c" (user_data: rawptr, body1, body2: ^jolt.Body, manifold: ^jolt.Contact_Manifold, settings: ^jolt.Contact_Settings) {
    context = runtime.default_context()
    entity_map := cast(^map[jolt.BodyID]Entity)user_data

    id1 := body1.id
    id2 := body2.id
    e1, ok1 := entity_map^[id1]
    e2, ok2 := entity_map^[id2]
    if !ok1 || !ok2 { return }  // Comma ok for safety

    // Simplified: Use first point
    point := manifold.sub_shape_a.points[0].position if len(manifold.sub_shape_a.points) > 0 else manifold.base_offset
    normal := manifold.normal

    add_collision :: proc(e: Entity, other: Entity, p: vec3, n: vec3, state: CollisionState) {
        collided := get_component(e, Cmp_Collided)
        if collided == nil {
            add_component(e, Cmp_Collided{})
            collided = get_component(e, Cmp_Collided)
        }
        append(&collided.collisions, CollisionData{other_entity = other, point = p, normal = n, state = state})
    }

    add_collision(e1, e2, point, normal, .Enter)
    add_collision(e2, e1, point, -normal, .Enter)  // Invert normal for symmetry
}

// Init (with defer, error checks, proper filter setup)
physics_sys_init :: proc(alloc := context.allocator) {
    context.allocator = alloc

    jolt.Register_Default_Material()
    jolt.Register_Types()

    // Job system (single-threaded starter; expand to threads)
    job_config: jolt.Job_System_Config
    job_config.queue_job = proc "c" (ctx: rawptr, job_func: jolt.Job_Function, data: rawptr) {
        context = runtime.default_context()
        job_func(data)
    }
    job_config.queue_jobs = proc "c" (ctx: rawptr, job_func: jolt.Job_Function, data: ^rawptr, count: u32) {
        context = runtime.default_context()
        for i in 0..<count { job_func(data[i]) }
    }
    job_system := jolt.Job_System_Create(&job_config)
    if job_system == nil { fmt.eprintln("Failed to create job system"); return }

    // Temp allocator
    temp_alloc := jolt.Temp_Allocator_Create(10 * 1024 * 1024)
    if temp_alloc == nil { fmt.eprintln("Failed to create temp allocator"); return }

    // Filters (set procs first)
    olp_procs: jolt.Object_Layer_Pair_Filter_Procs
    olp_procs.should_collide = object_layer_pair_should_collide
    jolt.Object_Layer_Pair_Filter_SetProcs(&olp_procs)
    object_layer_filter := jolt.Object_Layer_Pair_Filter_Create(nil)  // nil user_data
    if object_layer_filter == nil { fmt.eprintln("Failed to create object layer filter"); return }

    obp_procs: jolt.Object_vs_BroadPhase_Layer_Filter_Procs
    obp_procs.should_collide = object_vs_broadphase_should_collide
    jolt.Object_vs_BroadPhase_Layer_Filter_SetProcs(&obp_procs)
    broad_phase_filter := jolt.Object_vs_BroadPhase_Layer_Filter_Create(nil)
    if broad_phase_filter == nil { fmt.eprintln("Failed to create broad phase filter"); return }

    // Broad phase interface
    broad_phase_interface := jolt.Broad_Phase_Layer_Interface_Create(proc "c" (user_data: rawptr, layer: jolt.Object_Layer) -> jolt.Broad_Phase_Layer {
        context = runtime.default_context()
        return jolt.Broad_Phase_Layer(u8(BroadPhaseLayer(layer)))
    }, nil, 2)  // 2 layers
    if broad_phase_interface == nil { fmt.eprintln("Failed to create broad phase interface"); return }

    // Listeners
    activation_listener := jolt.Activation_Listener_Create(nil)
    if activation_listener == nil { fmt.eprintln("Failed to create activation listener"); return }

    contact_procs: jolt.Contact_Listener_Procs
    contact_procs.on_contact_added = contact_on_added
    jolt.Contact_Listener_SetProcs(&contact_procs)
    contact_listener := jolt.Contact_Listener_Create(&entity_body_map)
    if contact_listener == nil { fmt.eprintln("Failed to create contact listener"); return }

    // Physics system
    settings: jolt.Physics_System_Settings
    settings.max_bodies = 10240
    settings.max_body_pairs = 65536
    // Fill others...
    physics_system := jolt.Physics_System_Create(&settings, broad_phase_interface, object_layer_filter, broad_phase_filter, activation_listener, contact_listener)
    if physics_system == nil { fmt.eprintln("Failed to create physics system"); return }

    // Singleton
    physics_entity := create_entity()
    add_component(physics_entity, Cmp_Physics{
        system = physics_system,
        body_interface = jolt.Physics_System_Get_Body_Interface_No_Lock(physics_system),
        activation_listener = activation_listener,
        contact_listener = contact_listener,
        temp_allocator = temp_alloc,
        job_system = job_system,
        object_layer_filter = object_layer_filter,
        broad_phase_filter = broad_phase_filter,
    })

    // Map init
    entity_body_map = make(map[jolt.BodyID]Entity, 1024)  // Pre-reserve

    // Shutdown hook (call at engine quit)
    physics_sys_shutdown :: proc(p: ^Cmp_Physics) {
        defer jolt.Physics_System_Destroy(p.system)
        defer jolt.Activation_Listener_Destroy(p.activation_listener)
        defer jolt.Contact_Listener_Destroy(p.contact_listener)
        defer jolt.Temp_Allocator_Destroy(p.temp_allocator)
        defer jolt.Job_System_Destroy(p.job_system)
        defer jolt.Object_Layer_Pair_Filter_Destroy(p.object_layer_filter)
        defer jolt.Object_vs_BroadPhase_Layer_Filter_Destroy(p.broad_phase_filter)
        defer jolt.Broad_Phase_Layer_Interface_Destroy(broad_phase_interface)
        delete(entity_body_map)
    }
}

// Process (with checks)
physics_sys_process :: proc(delta_time: f32) {
    archetypes := query(ecs.has(Cmp_Physics))
    for archetype in archetypes {
        physics_comps := get_table(archetype, Cmp_Physics)
        for &physics in physics_comps {
            jolt.Physics_System_Update(physics.system, delta_time, 1, 2, physics.temp_allocator, physics.job_system)
        }
    }

    // Sync
    rigid_archetypes := query(ecs.has(Cmp_RigidBody), ecs.has(Cmp_Transform))
    for archetype in rigid_archetypes {
        rigid_comps := get_table(archetype, Cmp_RigidBody)
        trans_comps := get_table(archetype, Cmp_Transform)
        for i in 0..<len(rigid_comps) {
            rigid := &rigid_comps[i]
            if jolt.BodyID_Is_Invalid(rigid.body_id) { continue }  // Skip invalid

            trans := &trans_comps[i]
            pos: jolt.Vec3
            rot: jolt.Quat
            jolt.Body_Interface_Get_Position_And_Rotation(physics.body_interface, rigid.body_id, &pos, &rot)
            trans.global.pos = {pos.x, pos.y, pos.z, 1.0}
            trans.global.rot = {rot.x, rot.y, rot.z, rot.w}

            if rigid.motion_type == .KINEMATIC {
                jolt.Body_Interface_Set_Position_And_Rotation(physics.body_interface, rigid.body_id, trans.global.pos.xyz, trans.global.rot, .DONT_ACTIVATE)
            }
        }
    }
}

// Added (with error check)
physics_sys_added :: proc(entity: Entity) {
    if !has_component(entity, Cmp_Collider) || !has_component(entity, Cmp_RigidBody) { return }

    collider := get_component(entity, Cmp_Collider)
    rigid := get_component(entity, Cmp_RigidBody)
    trans := get_component(entity, Cmp_Transform)
    physics := get_physics_singleton() or_return  // Assume helper returns ^Cmp_Physics or nil

    // Create shape
    shape: ^jolt.Shape
    switch collider.type {
    case .Box:     shape = jolt.Shape_Create_Box(collider.extents)
    case .Sphere:  shape = jolt.Shape_Create_Sphere(collider.extents.x)
    case .Capsule: shape = jolt.Shape_Create_Capsule(0.5 * collider.extents.y, collider.extents.x)  // half-height, radius
    case .Plane:   shape = jolt.Shape_Create_Static_Floor()
    // Add cases...
    case: return  // Unknown type
    }
    if shape == nil { fmt.eprintln("Failed to create shape"); return }
    defer jolt.Shape_Release(shape)  // Ref release after use

    // Settings
    settings: jolt.Body_Creation_Settings
    settings.position = trans.global.pos.xyz
    settings.rotation = trans.global.rot
    settings.shape = shape
    settings.object_layer = collider.layer
    settings.motion_type = rigid.motion_type
    settings.friction = rigid.friction
    settings.restitution = rigid.restitution
    if rigid.motion_type == .DYNAMIC {
        settings.mass_properties_override.mass = rigid.mass
    }

    body_id := jolt.Body_Interface_Create_And_Add_Body(physics.body_interface, &settings, .ACTIVATE)
    if jolt.BodyID_Is_Invalid(body_id) { fmt.eprintln("Failed to create body"); return }
    rigid.body_id = body_id

    entity_body_map[body_id] = entity
}

// Removed
physics_sys_removed :: proc(entity: Entity) {
    if !has_component(entity, Cmp_RigidBody) { return }
    rigid := get_component(entity, Cmp_RigidBody)
    if jolt.BodyID_Is_Invalid(rigid.body_id) { return }

    physics := get_physics_singleton() or_return
    jolt.Body_Interface_Remove_And_Destroy_Body(physics.body_interface, rigid.body_id)
    delete_key(&entity_body_map, rigid.body_id)
}

// Helper (with error prop)
get_physics_singleton :: proc() -> (p: ^Cmp_Physics, ok: bool) {
    archetypes := query(ecs.has(Cmp_Physics))
    if len(archetypes) == 0 { return nil, false }
    physics_comps := get_table(archetypes[0], Cmp_Physics)
    if len(physics_comps) == 0 { return nil, false }
    return &physics_comps[0], true
}
