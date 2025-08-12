// Licensed under the MIT License (MIT). See LICENSE in the repository root for more information.
package jolt


/*
    LIBRARIES:
        joltc: [2025/06/15]
*/

import "core:c"


when ODIN_OS == .Windows {
    // @(extra_linker_flags="-ltcg")
    // @(extra_linker_flags="/NODEFAULTLIB:LIBCMTD")
    foreign import lib {
        "lib/Jolt.lib",
        "lib/joltc.lib",
        // "windows/joltc.dll",
    }
} else {
    #panic("No lib.")
    // @(extra_linker_flags="-lstdc++")
    // foreign import lib {
    // }
}


//--------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------

DOUBLE_PRECISION :: #config(DOUBLE_PRECISION, false)

DEFAULT_COLLISION_TOLERANCE   :: 1.0-4  // float cDefaultCollisionTolerance = 1.0e-4f
DEFAULT_PENETRATION_TOLERANCE :: 1.0-4  // float cDefaultPenetrationTolerance = 1.0e-4f
DEFAULT_CONVEX_RADIUS         :: 0.05   // float cDefaultConvexRadius = 0.05f
CAPSULE_PROJECTION_SLOP       :: 0.02   // float cCapsuleProjectionSlop = 0.02f
MAX_PHYSICS_JOBS              :: 2048   // int cMaxPhysicsJobs = 2048
MAX_PHYSICS_BARRIERS          :: 8      // int cMaxPhysicsBarriers = 8


//--------------------------------------------------------------------------------------------------
// Math
//--------------------------------------------------------------------------------------------------

Vec3 :: [3]f32
Vec4 :: [4]f32

Quat :: [4]f32

Matrix4x4 :: #row_major matrix[4, 4]f32
// Equivalent to:
// Matrix4x4 :: struct {
//  m11, m12, m13, m14: f32,
//  m21, m22, m23, m24: f32,
//  m31, m32, m33, m34: f32,
//  m41, m42, m43, m44: f32,
// }

/*
REAL numbers.
They should change when aiming for double precision.
It is necessary to rebuild the libraries with the same intent of Double Precision.
*/
when DOUBLE_PRECISION {
    RMatrix4x4 :: #row_major matrix[4, 4]f64
    RVec3 :: [3]f64
} else {
    RMatrix4x4 :: Matrix4x4
    RVec3 :: Vec3
}


AABox :: struct {
    min: Vec3,
    max: Vec3,
}

Plane :: struct {
    normal:   Vec3,
    distance: f32,
}

Triangle :: struct {
    v1:            Vec3,
    v2:            Vec3,
    v3:            Vec3,
    material_index: u32,
}

Indexed_Triangle_No_Material :: struct {
    i1: u32,
    i2: u32,
    i3: u32,
}

Indexed_Triangle :: struct {
    i1:             u32,
    i2:             u32,
    i3:             u32,
    material_index: u32,
    user_data:      u32,
}

//--------------------------------------------------------------------------------------------------
// Setup
//--------------------------------------------------------------------------------------------------

Trace_Func          :: proc "c" (cstring)
Assert_Failure_Func :: proc "c" (cstring, cstring, cstring, u32) -> bool

Job_System          :: struct {}

Job_System_Thread_Pool_Config :: struct {
    max_jobs:     u32,
    max_barriers: u32,
    num_threads:  i32,
}

Job_System_Config :: struct {
    _context:        rawptr,
    queue_job:       Queue_Job_Callback,
    queue_jobs:      Queue_Jobs_Callback,
    max_concurrency: u32,
    max_barriers:    u32,
}

Job_Function        :: proc "c" (rawptr)
Queue_Job_Callback  :: proc "c" (rawptr, Job_Function, rawptr)
Queue_Jobs_Callback :: proc "c" (rawptr, Job_Function, ^rawptr, u32)

Body_Lock_Interface                 :: struct {}
Body_Lock_MultiRead                 :: struct {}
Body_Lock_MultiWrite                :: struct {}

Body_Lock_Read :: struct {
    lock_interface: ^Body_Lock_Interface,
    mutex:          ^Shared_Mutex,
    body:           ^Body,
}

Body_Lock_Write :: struct {
    lock_interface:  ^Body_Lock_Interface,
    mutex:           ^Shared_Mutex,
    body:            ^Body,
}

Shared_Mutex                        :: struct {}


//--------------------------------------------------------------------------------------------------
// Physics_System
//--------------------------------------------------------------------------------------------------

Physics_System                      :: struct {}

Physics_System_Settings :: struct {
    max_bodies:                         u32, /* If not set, the joltc interface will set automatically to: 10240 */
        // inMaxBodies Maximum number of bodies to support.

    num_body_mutexes:                   u32, /* If not set, the joltc interface will set automatically to: 0 */
        // inNumBodyMutexes Number of body mutexes to use. Should be a power of 2 in the range [1, 64], use 0 to auto detect.

    max_body_pairs:                     u32, /* If not set, the joltc interface will set automatically to: 65536 */
        // inMaxBodyPairs Maximum amount of body pairs to process (anything else will fall through the world), this number should generally be much higher than the max amount of contact points as there will be lots of bodies close that are not actually touching.

    max_contact_constraints:            u32, /* If not set, the joltc interface will set automatically to: 10240 */
        // inMaxContactConstraints Maximum amount of contact constraints to process (anything else will fall through the world).

    _padding:                           u32,
        // Maybe for struct alignment? I don't know.

    broad_phase_layer_interface:        ^BroadPhase_Layer_Interface,
        // inBroadPhaseLayerInterface Information on the mapping of object layers to broad phase layers. Since this is a virtual interface, the instance needs to stay alive during the lifetime of the PhysicsSystem.

    object_layer_pair_filter:           ^Object_Layer_Pair_Filter,
        // inObjectLayerPairFilter Filter callback function that is used to determine if two object layers collide. Since this is a virtual interface, the instance needs to stay alive during the lifetime of the PhysicsSystem.

    object_vs_broad_phase_layer_filter: ^ObjectVsBroadPhase_Layer_Filter,
        // inObjectVsBroadPhaseLayerFilter Filter callback function that is used to determine if an object layer collides with a broad phase layer. Since this is a virtual interface, the instance needs to stay alive during the lifetime of the PhysicsSystem.
}

Physics_Settings :: struct {
    /*
    Main physics simulation settings
    */

    max_in_flight_body_pairs:                    c.int, // Jolt default: 16384
        // Size of body pairs array, corresponds to the maximum amount of potential body pairs that can be in flight at any time.
        // Setting this to a low value will use less memory but slow down simulation as threads may run out of narrow phase work.

    step_listeners_batch_size:                   c.int, // Jolt default: 8
        // How many Physics_Step_Listeners to notify in 1 batch

    step_listener_batches_per_job:               c.int, // Jolt default: 1
        // How many step listener batches are needed before spawning another job (set to INT_MAX if no parallelism is desired)

    baumgarte:                                   f32,   // Jolt default: 0.2
        // Baumgarte stabilization factor (how much of the position error to 'fix' in 1 update) (unit: dimensionless, 0 = nothing, 1 = 100%)

    speculative_contact_distance:                f32,   // Jolt default: 0.02
        // Radius around objects inside which speculative contact points will be detected. Note that if this is too big
        // you will get ghost collisions as speculative contacts are based on the closest points during the collision detection
        // step which may not be the actual closest points by the time the two objects hit (unit: meters)

    penetration_slop:                            f32,   // Jolt default: 0.02
        // How much bodies are allowed to sink into each other (unit: meters)

    linear_cast_threshold:                       f32,   // Jolt default: 0.75
        // Fraction of its inner radius a body must move per step to enable casting for the LinearCast motion quality

    linear_cast_max_penetration:                 f32,   // Jolt default: 0.25
        // Fraction of its inner radius a body may penetrate another body for the LinearCast motion quality

    manifold_tolerance:                          f32,   // Jolt default: 1e-3
        // Max distance to use to determine if two points are on the same plane for determining the contact manifold between two shape faces (unit: meter)

    max_penetration_distance:                    f32,   // Jolt default: 0.2
        // Maximum distance to correct in a single iteration when solving position constraints (unit: meters)

    body_pair_cache_max_delta_position_sq:       f32,   // Jolt default: Square(0.001)  // 1mm
        // Maximum relative delta position for body pairs to be able to reuse collision results from last frame (units: meter^2)

    body_pair_cache_cos_max_delta_rotation_div2: f32,   // Jolt default: 0.99984769515639123915701155881391f; // cos(2 degrees / 2)
        // Maximum relative delta orientation for body pairs to be able to reuse collision results from last frame, stored as cos(max angle / 2)

    contact_normal_cos_max_delta_rotation:       f32,   // Jolt default: 0.99619469809174553229501040247389f; // cos(5 degree)
        // Maximum angle between normals that allows manifolds between different sub shapes of the same body pair to be combined

    contact_point_preserve_lambda_max_dist_sq:   f32,   // Jolt default: Square(0.01f); // 1 cm
        // Maximum allowed distance between old and new contact point to preserve contact forces for warm start (units: meter^2)

    num_velocity_steps:                          u32,   // Jolt default: 10
        // Number of solver velocity iterations to run
        // Note that this needs to be >= 2 in order for friction to work (friction is applied using the non-penetration impulse from the previous iteration)

    num_position_steps:                          u32,   // Jolt default: 2
        // Number of solver position iterations to run

    min_velocity_for_restitution:                f32,   // Jolt default: 1.0
        // Minimal velocity needed before a collision can be elastic. If the relative velocity between colliding objects
        // in the direction of the contact normal is lower than this, the restitution will be zero regardless of the configured
        // value. This lets an object settle sooner. Must be a positive number. (unit: m)

    time_before_sleep:                           f32,   // Jolt default: 0.5
        // Time before object is allowed to go to sleep (unit: seconds)

    point_velocity_sleep_threshold:              f32,   // Jolt default: 0.03
        // To detect if an object is sleeping, we use 3 points:
        // - The center of mass.
        // - The centers of the faces of the bounding box that are furthest away from the center.
        // The movement of these points is tracked and if the velocity of all 3 points is lower than this value,
        // the object is allowed to go to sleep. Must be a positive number. (unit: m/s)

    deterministic_simulation:                    bool,  // Jolt default: true
        // By default the simulation is deterministic, it is possible to turn this off by setting this setting to false. This will make the simulation run faster but it will no longer be deterministic.

    // >> These variables are mainly for debugging purposes, they allow turning on/off certain subsystems. You probably want to leave them alone.
    constraint_warm_start:                       bool,  // Jolt default: true
        // Whether or not to use warm starting for constraints (initially applying previous frames impulses)

    use_body_pair_contact_cache:                 bool,  // Jolt default: true
        // Whether or not to use the body pair cache, which removes the need for narrow phase collision detection when orientation between two bodies didn't change

    use_manifold_reduction:                      bool,  // Jolt default: true
        // Whether or not to reduce manifolds with similar contact normals into one contact manifold (see description at Body::SetUseManifoldReduction)

    use_large_island_splitter:                   bool,  // Jolt default: true
        // If we split up large islands into smaller parallel batches of work (to improve performance)

    allow_sleeping:                              bool,  // Jolt default: true
        // If objects can go to sleep or not

    check_active_edges:                          bool,  // Jolt default: true
        // When false, we prevent collision against non-active (shared) edges. Mainly for debugging the algorithm.
    // <<

}

Physics_Update_Error :: enum c.int {
    None = 0,
    Manifold_Cache_Full = 1,
    BodyPair_Cache_Full = 2,
    Contact_Constraints_Full = 4,
    _Count,
}

/* Object Layer & BroadPhase Layer */
Object_Layer                    :: u32
BroadPhase_Layer                :: u8
Object_Layer_Pair_Filter        :: struct {}
BroadPhase_Layer_Interface      :: struct {}
ObjectVsBroadPhase_Layer_Filter :: struct {}


//--------------------------------------------------------------------------------------------------
// Filters
//--------------------------------------------------------------------------------------------------

/* Filters */
Group_Filter            :: struct {}
Group_Filter_Table      :: struct { using _: Group_Filter}
Shape_Filter            :: struct {}
SimShape_Filter         :: struct {}
/* Query */
ObjectLayer_Filter      :: struct {}
BroadPhase_Layer_Filter :: struct {}
BroadPhase_Query        :: struct {}
NarrowPhase_Query       :: struct {}


//--------------------------------------------------------------------------------------------------
// Contact Listeners
//--------------------------------------------------------------------------------------------------

Contact_Listener       :: struct {}
    /*
    Listener that is notified whenever a contact point between two bodies is added/updated/removed.
    You can't change contact listener during `PhysicsSystem::Update` but it can be changed at any other time.

    The only thing that differentiates a Contact_Listener from each other, is the `contact_listener_data: rawptr` it holds.
    */

Contact_Listener_Procs :: struct {
    /*
    The rawptr received from the proc is the `user_data` configured when creating the Contact_Listener.

    Note that contact listener callbacks are called from multiple threads at the same time when all bodies are locked, this means you cannot
    use PhysicsSystem::GetBodyInterface / PhysicsSystem::GetBodyLockInterface but must use PhysicsSystem::GetBodyInterfaceNoLock / PhysicsSystem::GetBodyLockInterfaceNoLock instead.
    If you use a locking interface, the simulation will deadlock. You're only allowed to read from the bodies and you can't change physics state.
    During OnContactRemoved you cannot access the bodies at all.
    */

    on_contact_validate:  proc "c" (contact_listener_data: rawptr, body1: ^Body, body2: ^Body, base_offset: ^RVec3, collide_shape_result: ^Collide_Shape_Result) -> Validate_Result,
        /*
        Called after detecting a collision between a body pair, but before calling OnContactAdded and before adding the contact constraint.
        If the function rejects the contact, the contact will not be processed by the simulation.

        If no Contact_Listener is defined, or if this procedure is not defined, the default Validate_Result is `ValidateResult::AcceptAllContactsForThisBodyPair``.

        This is a rather expensive time to reject a contact point since a lot of the collision detection has happened already, make sure you
        filter out the majority of undesired body pairs through the ObjectLayerPairFilter that is registered on the PhysicsSystem.

        This function may not be called again the next update if a contact persists and no new contact pairs between sub shapes are found.

        Body 1 will have a motion type that is larger or equal than body 2's motion type (order from large to small: dynamic -> kinematic -> static).
        When motion types are equal, they are ordered by BodyID.

        The collision result `collide_shape_result` is reported relative to `base_offset`.

        LOCK:
            Note that this callback is called when all bodies are locked, so don't use any locking functions!
        */

    on_contact_added:     proc "c" (contact_listener_data: rawptr, body1: ^Body, body2: ^Body, contact_manifold: ^Contact_Manifold, contact_settings: ^Contact_Settings),
        /*
        Called whenever a new contact point is detected.

        Note that only active bodies will report contacts.
        Body 1 and 2 will be sorted such that body 1 ID < body 2 ID, so body 1 may not be dynamic.

        When contacts are added, the constraint solver has not run yet, so the collision impulse is unknown at that point.
        The velocities of inBody1 and inBody2 are the velocities before the contact has been resolved, so you can use this to
        estimate the collision impulse to e.g. determine the volume of the impact sound to play (see: EstimateCollisionResponse).

        LOCK:
            Note that this callback is called when all bodies are locked, so don't use any locking functions!
        */

    on_contact_persisted: proc "c" (contact_listener_data: rawptr, body1: ^Body, body2: ^Body, contact_manifold: ^Contact_Manifold, contact_settings: ^Contact_Settings),
        /*
        Called whenever a contact is detected that was also detected last update
        Body 1 and 2 will be sorted such that body 1 ID < body 2 ID, so body 1 may not be dynamic.

        If the structure of the shape of a body changes between simulation steps (e.g. by adding/removing a child shape of a compound shape),
        it is possible that the same sub shape ID used to identify the removed child shape is now reused for a different child shape. The physics
        system cannot detect this, so may send a 'contact persisted' callback even though the contact is now on a different child shape. You can
        detect this by keeping the old shape (before adding/removing a part) around until the next PhysicsSystem::Update (when the OnContactPersisted
        callbacks are triggered) and resolving the sub shape ID against both the old and new shape to see if they still refer to the same child shape.

        LOCK:
            Note that this callback is called when all bodies are locked, so don't use any locking functions!
        */

    on_contact_removed:   proc "c" (contact_listener_data: rawptr, subshape_id_pair: ^SubShape_ID_Pair),
        /*
        Called whenever a contact was detected last update but is not detected anymore.

        Body 1 and 2 will be sorted such that body 1 ID < body 2 ID, so body 1 may not be dynamic.

        As soon as a body goes to sleep the contacts between that body and all other bodies will receive an OnContactRemoved callback,
        if this is the case then Body::IsActive() will return false during the callback.

        The sub shape IDs were created in the previous simulation step, so if the structure of a shape changes (e.g. by adding/removing a child shape of a compound shape),
        the sub shape ID may not be valid / may not point to the same sub shape anymore.
        If you want to know if this is the last contact between the two bodies, use PhysicsSystem::WereBodiesInContact.

        LOCK:
            You cannot access the bodies at the time of this callback because:
            - All bodies are locked at the time of this callback.
            - Some properties of the bodies are being modified from another thread at the same time.
            - The body may have been removed and destroyed (you'll receive an OnContactRemoved callback in the PhysicsSystem::Update after the body has been removed).
            Cache what you need in the OnContactAdded and OnContactPersisted callbacks and store it in a separate structure to use during this callback.
            Alternatively, you could just record that the contact was removed and process it after PhysicsSystem::Update.
        */
}

Validate_Result :: enum c.int {
    Accept_All_Contacts_For_This_Body_Pair = 0,
    Accept_Contact = 1,
    Reject_Contact = 2,
    Reject_All_Contacts_For_This_Body_Pair = 3,
    _Count,
}

Contact_Settings :: struct {}
    /*
    Note: I'm not sure if changing something through this callback actually changes the property. I haven't tried that yet.

    When a contact point is added or persisted, the callback gets a chance to override certain properties of the contact constraint.
    The values are filled in with their defaults by the system so the callback doesn't need to modify anything, but it can if it wants to.

    float  mCombinedFriction = 0.0f;            // Combined friction for the body pair (see: PhysicsSystem::SetCombineFriction)
    float  mCombinedRestitution = 0.0f;         // Combined restitution for the body pair (see: PhysicsSystem::SetCombineRestitution)
    float  mInvMassScale1 = 1.0f;               // Scale factor for the inverse mass of body 1 (0 = infinite mass, 1 = use original mass, 2 = body has half the mass). For the same contact pair, you should strive to keep the value the same over time.
    float  mInvInertiaScale1 = 1.0f;            // Scale factor for the inverse inertia of body 1 (usually same as mInvMassScale1)
    float  mInvMassScale2 = 1.0f;               // Scale factor for the inverse mass of body 2 (0 = infinite mass, 1 = use original mass, 2 = body has half the mass). For the same contact pair, you should strive to keep the value the same over time.
    float  mInvInertiaScale2 = 1.0f;            // Scale factor for the inverse inertia of body 2 (usually same as mInvMassScale2)
    bool   mIsSensor = false;                   // A sensor will receive collision callbacks, but will not cause any collision responses and can be used as a trigger volume.
    Vec3   mRelativeLinearSurfaceVelocity = Vec3::sZero();  // Relative linear surface velocity between the bodies (world space surface velocity of body 2 - world space surface velocity of body 1), can be used to create a conveyor belt effect
    Vec3   mRelativeAngularSurfaceVelocity = Vec3::sZero(); // Relative angular surface velocity between the bodies (world space angular surface velocity of body 2 - world space angular surface velocity of body 1). Note that this angular velocity is relative to the center of mass of body 1, so if you want it relative to body 2's center of mass you need to add body 2 angular velocity x (body 1 world space center of mass - body 2 world space center of mass) to mRelativeLinearSurfaceVelocity.
    */

Contact_Manifold :: struct {}
    /*
    Describes the contact surface between two bodies

    RVec3          mBaseOffset;                // Offset to which all the contact points are relative
    Vec3           mWorldSpaceNormal;          // Normal for this manifold, direction along which to move body 2 out of collision along the shortest path
    float          mPenetrationDepth;          // Penetration depth (move shape 2 by this distance to resolve the collision). If this value is negative, this is a speculative contact point and may not actually result in a velocity change as during solving the bodies may not actually collide.
    SubShapeID     mSubShapeID1;               // Sub shapes that formed this manifold (note that when multiple manifolds are combined because they're coplanar, we lose some information here because we only keep track of one sub shape pair that we encounter, see description at Body::SetUseManifoldReduction)
    SubShapeID     mSubShapeID2;
    ContactPoints  mRelativeContactPointsOn1;  // Contact points on the surface of shape 1 relative to mBaseOffset.
    ContactPoints  mRelativeContactPointsOn2;  // Contact points on the surface of shape 2 relative to mBaseOffset. If there's no penetration, this will be the same as mRelativeContactPointsOn1. If there is penetration they will be different.
    */


//--------------------------------------------------------------------------------------------------
// Listeners
//--------------------------------------------------------------------------------------------------

Physics_Step_Listener :: struct {}

Physics_Step_Listener_Context :: struct {
    delta_time:      f32,
    is_first_step:   bool,
    is_last_step:    bool,
    physics_system: ^Physics_System,
}

Physics_Step_Listener_Procs :: struct {
    /*
    The rawptr received from the proc is the `user_data` configured when creating the Body_Activation_Listener.
    */

    on_step: proc "c" (rawptr, ^Physics_Step_Listener_Context),
}


Body_Activation_Listener :: struct {}

Body_Activation_Listener_Procs :: struct {
    /*
    The rawptr received from the proc is the `user_data` configured when creating the Body_Activation_Listener.
    */

    on_body_activated:   proc "c" (rawptr, Body_ID, i64),
    on_body_deactivated: proc "c" (rawptr, Body_ID, i64),
}


//--------------------------------------------------------------------------------------------------
// Body
//--------------------------------------------------------------------------------------------------

Body_ID :: u32

Body    :: struct {}
    /*
    A rigid body that can be simulated using the physics system
    Note that internally all properties (position, velocity etc.) are tracked relative to the center of mass of the object to simplify the simulation of the object.
    The offset between the position of the body and the center of mass position of the body is GetShape()->GetCenterOfMass().
    The functions that get/set the position of the body all indicate if they are relative to the center of mass or to the original position in which the shape was created.
    The linear velocity is also velocity of the center of mass, to correct for this: \f$VelocityCOM = Velocity - AngularVelocity \times ShapeCOM\f$.
    By default, all Body properties are "zero" or equivalent.
    */

Body_Creation_Settings :: struct {}
    /*
    Default values for a BodyCreationSetting:

    position = {},
        // Position of the body (not of the center of mass)

    rotation = {0, 0, 0, 1},
        // Rotation of the body

    linear_velocity = {},
        // World space linear velocity of the center of mass (m/s)

    angular_velocity = {},
        // World space angular velocity (rad/s)

    user_data = 0,
        // User data value (can be used by application)

    object_layer = 0,
        // The collision layer this body belongs to (determines if two objects can collide)

    collision_group = {},
        // The collision group this body belongs to (determines if two objects can collide)

    motion_type = .Dynamic,
        // Motion type, determines if the object is static, dynamic or kinematic

    allowed_dofs = .All,
        // Which degrees of freedom this body has (can be used to limit simulation to 2D)

    allow_dynamic_or_kinematic = false,
        // When this body is created as static, this setting tells the system to create a MotionProperties object so that the object can be switched to kinematic or dynamic.

    is_sensor = false,
        /*
        A sensor will receive collision callbacks, but will not cause any collision responses and can be used as a trigger volume.
        A static sensor will only detect active bodies entering their area. As soon as a body goes to sleep, the contact will be lost.
        A Sensor can't go to sleep (they would stop detecting collisions with sleeping bodies).
        */

    collide_kinematic_vs_non_dynamic = false,
        // If kinematic objects can generate contact points against other kinematic or static objects.

    use_manifold_reduction = true,
        // If this body should use manifold reduction (see description at Body::SetUseManifoldReduction)

    apply_gyroscopic_force = false,
        // Set to indicate that the gyroscopic force should be applied to this body (aka Dzhanibekov effect, see https://en.wikipedia.org/wiki/Tennis_racket_theorem)

    motion_quality = .Discrete,
        // Motion quality, or how well it detects collisions when it has a high velocity.

    enhanced_internal_edge_removal = false,
        // Set to indicate that extra effort should be made to try to remove ghost contacts (collisions with internal edges of a mesh). This is more expensive but makes bodies move smoother over a mesh with convex edges.

    allow_sleeping = true,
        // If this body can go to sleep or not

    friction = 0.2,
        // Friction of the body (dimensionless number, usually between 0 and 1, 0 = no friction, 1 = friction force equals force that presses the two bodies together). Note that bodies can have negative friction but the combined friction (see PhysicsSystem::SetCombineFriction) should never go below zero.

    restitution = 0.0,
        // Restitution of body (dimensionless number, usually between 0 and 1, 0 = completely inelastic collision response, 1 = completely elastic collision response). Note that bodies can have negative restitution but the combined restitution (see PhysicsSystem::SetCombineRestitution) should never go below zero.

    linear_damping = 0.05,
        // Linear damping: dv/dt = -c * v. c must be between 0 and 1 but is usually close to 0.

    angular_damping = 0.05,
        // Angular damping: dw/dt = -c * w. c must be between 0 and 1 but is usually close to 0.

    max_linear_velocity = 500,
        // Maximum linear velocity that this body can reach (m/s)

    max_angular_velocity = 0.25 * PI * 60,
        // Maximum angular velocity that this body can reach (rad/s)

    gravity_factor = 1.0,
        // Value to multiply gravity with for this body

    num_velocity_steps_override = 0,
        // Used only when this body is dynamic and colliding. Override for the number of solver velocity iterations to run, 0 means use the default in Physics_Settings::mNumVelocitySteps. The number of iterations to use is the max of all contacts and constraints in the island.

    num_position_steps_override = 0,
        // Used only when this body is dynamic and colliding. Override for the number of solver position iterations to run, 0 means use the default in Physics_Settings::mNumPositionSteps. The number of iterations to use is the max of all contacts and constraints in the island.

    override_mass_properties = .CalculateMassAndInertia,
        // Mass properties of the body (by default calculated by the shape). Determines how mMassPropertiesOverride will be used

    inertia_multiplayer = 1.0,
        // When calculating the inertia (not when it is provided) the calculated inertia will be multiplied by this value

    mass_properties_override = {},
        // Contains replacement mass settings which override the automatically calculated values
    */

SoftBody_Creation_Settings :: struct {}

Body_Interface             :: struct {}

Body_Filter                :: struct {}

Body_Type :: enum c.int {
    Rigid = 0,
    Soft = 1,
    _Count,
}

Motion_Type :: enum c.int {
    /* Non movable */
    Static = 0,

    /*
    Movable using velocities only, does not respond to forces.
    Kinematic objects are not affected by other kinematic/static objects.
    Note:
        From my understanding, Kinematic bodies can only interact with other Kinematic or Static Bodies through the Character/CharacterVirtual class.
        I'm not familiar with Kinematic bodies yet.
        I recommend looking into the Samples from the JoltPhysics in C++, there are some examples of the use of Kinematic Bodies e Character/CharacterVirtual.
    */
    Kinematic = 1,

    /* Responds to forces as a normal physics object */
    Dynamic = 2,

    _Count,
}

Motion_Quality :: enum c.int {
    Discrete = 0,
    Linear_Cast = 1,
    _Count,
}

Activation :: enum c.int {
    Activate = 0,
    Dont_Activate = 1,
    _Count,
}

Allowed_DOFs :: enum c.int {
    All = 63,
    Translation_X = 1,
    Translation_Y = 2,
    Translation_Z = 4,
    Rotation_X = 8,
    Rotation_Y = 16,
    Rotation_Z = 32,
    Plane_2D = 35,
    _Count,
}

Mass_Properties :: struct {
    mass:    f32,
    inertia: Matrix4x4,
}

Override_Mass_Properties :: enum c.int {
    Calculate_Mass_And_Inertia,
        // Tells the system to calculate the mass and inertia based on density

    Calculate_Inertia,
        // Tells the system to take the mass from mMassPropertiesOverride and to calculate the inertia based on density of the shapes and to scale it to the provided mass

    Mass_And_Inertia_Provided,
        // Tells the system to take the mass and inertia from mMassPropertiesOverride

    _Count,
}

Physics_Material         :: struct {}
Motion_Properties        :: struct {}


//--------------------------------------------------------------------------------------------------
// Shape
//--------------------------------------------------------------------------------------------------

SubShape_ID :: u32

/* Shapes */
Shape                               :: struct {}

Compound_Shape                      :: struct { using _: Shape }
Static_Compound_Shape               :: struct { using _: Compound_Shape }
Mutable_Compound_Shape              :: struct { using _: Compound_Shape }

Convex_Shape                        :: struct { using _: Shape }
Box_Shape                           :: struct { using _: Convex_Shape }
Capsule_Shape                       :: struct { using _: Convex_Shape }
Convex_Hull_Shape                   :: struct { using _: Convex_Shape }
Cylinder_Shape                      :: struct { using _: Convex_Shape }
Sphere_Shape                        :: struct { using _: Convex_Shape }
Tapered_Capsule_Shape               :: struct { using _: Convex_Shape }
Tapered_Cylinder_Shape              :: struct { using _: Convex_Shape }
Triangle_Shape                      :: struct { using _: Convex_Shape }

Decorated_Shape                     :: struct { using _: Shape }
Offset_Center_Of_Mass_Shape         :: struct { using _: Decorated_Shape }
Rotated_Translated_Shape            :: struct { using _: Decorated_Shape }
Scaled_Shape                        :: struct { using _: Decorated_Shape }

Empty_Shape                         :: struct { using _: Shape }
HeightField_Shape                   :: struct { using _: Shape }
Mesh_Shape                          :: struct { using _: Shape }
Plane_Shape                         :: struct { using _: Shape }


/* Shape Settings */
Shape_Settings                      :: struct {}

Plane_Shape_Settings                :: struct { using _: Shape_Settings}
Mesh_Shape_Settings                 :: struct { using _: Shape_Settings}
HeightField_Shape_Settings          :: struct { using _: Shape_Settings}
Empty_Shape_Settings                :: struct { using _: Shape_Settings}

Convex_Shape_Settings               :: struct { using _: Shape_Settings}
Box_Shape_Settings                  :: struct { using _: Convex_Shape_Settings }
Capsule_Shape_Settings              :: struct { using _: Convex_Shape_Settings }
Convex_Hull_Shape_Settings          :: struct { using _: Convex_Shape_Settings }
Cylinder_Shape_Settings             :: struct { using _: Convex_Shape_Settings }
Sphere_Shape_Settings               :: struct { using _: Convex_Shape_Settings }
Tapered_Capsule_Shape_Settings      :: struct { using _: Convex_Shape_Settings }
Tapered_Cylinder_Shape_Settings     :: struct { using _: Convex_Shape_Settings }
Triangle_Shape_Settings             :: struct { using _: Convex_Shape_Settings }

Compound_Shape_Settings             :: struct { using _: Shape_Settings}
Mutable_Compound_Shape_Settings     :: struct { using _: Compound_Shape_Settings }
Static_Compound_Shape_Settings      :: struct { using _: Compound_Shape_Settings }

Offset_Center_Of_Mass_Shape_Settings :: struct {}
Rotated_Translated_Shape_Settings    :: struct {}
Scaled_Shape_Settings                :: struct {}


Shape_Type :: enum c.int {
    Convex = 0,
    Compound = 1,
    Decorated = 2,
    Mesh = 3,
    HeightField = 4,
    SoftBody = 5,
    User1 = 6,
    User2 = 7,
    User3 = 8,
    User4 = 9,
    _Count,
}

Shape_SubType :: enum c.int {
    Sphere = 0,
    Box = 1,
    Triangle = 2,
    Capsule = 3,
    Tapered_Capsule = 4,
    Cylinder = 5,
    ConvexHull = 6,
    Static_Compound = 7,
    Mutable_Compound = 8,
    Rotated_Translated = 9,
    Scaled = 10,
    Offset_Center_Of_Mass = 11,
    Mesh = 12,
    HeightField = 13,
    SoftBody = 14,
    _Count,
}

SubShape_ID_Pair :: struct {
    body1_id:      Body_ID,
    sub_shape_id1: SubShape_ID,
    body2_id:      Body_ID,
    sub_shape_id2: SubShape_ID,
}

Supporting_Face :: struct {
    count:    u32,
    vertices: [32]Vec3,
}

Mesh_Shape_Build_Quality :: enum c.int {
    Favor_Runtime_Performance = 0,
    Favor_Build_Speed = 1,
    _Count,
}

//--------------------------------------------------------------------------------------------------
// Collide
//--------------------------------------------------------------------------------------------------

Collide_Settings_Base :: struct {
    active_edge_mode:               Active_Edge_Mode,   /* = ActiveEdgeMode_CollideOnlyWithActive*/
    collect_faces_mode:             Collect_Faces_Mode, /* = CollectFacesMode_NoFaces*/
    collision_tolerance:            f32,                /* = DEFAULT_COLLISION_TOLERANCE*/
    penetration_tolerance:          f32,                /* = DEFAULT_PENETRATION_TOLERANCE*/
    active_edge_movement_direction: Vec3,               /* = Vec3::sZero()*/
}

Active_Edge_Mode :: enum c.int {
    Collide_Only_With_Active,
    Collide_With_All,
    _Count,
}

Collect_Faces_Mode :: enum c.int {
    Collect_Faces,
    No_Faces,
    _Count,
}

Collide_Shape_Result :: struct {
    contact_point_on1: Vec3,
    contact_point_on2: Vec3,
    penetration_axis:  Vec3,
    penetration_depth: f32,
    sub_shape_id1:     SubShape_ID,
    sub_shape_id2:     SubShape_ID,
    body_id2:          Body_ID,
    shape1_face_count: u32,
    shape1_faces:      ^Vec3,
    shape2_face_count: u32,
    shape2_faces:      ^Vec3,
}

Collide_Shape_Result_Callback           :: proc "c" (rawptr, ^Collide_Shape_Result)
Collide_Shape_Collector_Callback        :: proc "c" (rawptr, ^Collide_Shape_Result) -> f32

Collide_Point_Result :: struct {
    body_id:       Body_ID,
    sub_shape_id2: SubShape_ID,
}

Collide_Point_Result_Callback           :: proc "c" (rawptr, ^Collide_Point_Result)
Collide_Point_Collector_Callback        :: proc "c" (rawptr, ^Collide_Point_Result) -> f32

RayCast_Settings :: struct {
    back_face_mode_triangles: BackFace_Mode, /* = BackFaceMode_IgnoreBackFaces */
    back_face_mode_convex:    BackFace_Mode, /* = BackFaceMode_IgnoreBackFaces */
    treat_convex_as_solid:    bool,          /* = true */
}

RayCast_Result :: struct {
    body_id:       Body_ID,
    fraction:      f32,
    sub_shape_id2: SubShape_ID,
}

CastRay_Result_Callback             :: proc "c" (rawptr, ^RayCast_Result)
CastRay_Collector_Callback          :: proc "c" (rawptr, ^RayCast_Result) -> f32


BroadPhase_Cast_Result :: struct {
    body_id:   Body_ID,
    fraction:  f32,
}

ShapeCast_Settings :: struct {
    using base:                           Collide_Settings_Base, /* Inherits Collide_Settings_Base */
    back_face_mode_triangles:             BackFace_Mode,         /* = BackFaceMode_IgnoreBackFaces */
    back_face_mode_convex:                BackFace_Mode,         /* = BackFaceMode_IgnoreBackFaces */
    use_shrunken_shape_and_convex_radius: bool,                  /* = false */
    return_deepest_point:                 bool,                  /* = false */
}

ShapeCast_Result :: struct {
    contact_point_on1: Vec3,
    contact_point_on2: Vec3,
    penetration_axis:  Vec3,
    penetration_depth: f32,
    sub_shape_id1:     SubShape_ID,
    sub_shape_id2:     SubShape_ID,
    body_id2:          Body_ID,
    fraction:          f32,
    is_back_face_hit:  bool,
}
CastShape_Result_Callback           :: proc "c" (rawptr, ^ShapeCast_Result)
CastShape_Collector_Callback        :: proc "c" (rawptr, ^ShapeCast_Result) -> f32

Collide_Shape_Settings :: struct {
    using base:              Collide_Settings_Base, /* Inherits Collide_Settings_Base */
    max_separation_distance: f32,                   /* = 0.0f*/
    back_face_mode:          BackFace_Mode,         /* = BackFaceMode_IgnoreBackFaces */
}

Collision_Collector_Type :: enum c.int {
    All_Hit = 0,
    All_Hit_Sorted = 1,
    Closest_Hit = 2,
    Any_Hit = 3,
    _Count,
}

Collision_Group_ID      :: u32
Collision_SubGroup_ID   :: u32

Collision_Group :: struct {
    group_filter:  ^Group_Filter,
    group_id:      Collision_Group_ID,
    sub_group_id:  Collision_SubGroup_ID,
}

Collision_Estimation_Result :: struct {
    linear_velocity1:  Vec3,
    angular_velocity1: Vec3,
    linear_velocity2:  Vec3,
    angular_velocity2: Vec3,
    tangent1:          Vec3,
    tangent2:          Vec3,
    impulse_count:     u32,
    impulses:          ^Collision_Estimation_Result_Impulse,
}

Collision_Estimation_Result_Impulse :: struct {
    contact_impulse:   f32,
    friction_impulse1: f32,
    friction_impulse2: f32,
}

BackFace_Mode :: enum c.int {
    Ignore_Back_Faces,
    Collide_With_BackFaces,
    _Count,
}

/* Query */
RayCast_Body_Result_Callback            :: proc "c" (rawptr, ^BroadPhase_Cast_Result)
RayCast_Body_Collector_Callback         :: proc "c" (rawptr, ^BroadPhase_Cast_Result) -> f32
// Collide_Shape_Body_Result_Callback       :: proc "c" (rawptr, Body_ID)
Collide_Shape_Body_Collector_Callback   :: proc "c" (rawptr, Body_ID) -> f32

//--------------------------------------------------------------------------------------------------
// Filters
//--------------------------------------------------------------------------------------------------

Object_Layer_Filter_Procs :: struct {
    should_collide: proc "c" (rawptr, Object_Layer) -> bool,
}

Broad_Phase_Layer_Filter_Procs :: struct {
    should_collide: proc "c" (rawptr, BroadPhase_Layer) -> bool,
}

Shape_Filter_Procs :: struct {
    should_collide:  proc "c" (rawptr, ^Shape, ^SubShape_ID) -> bool,
    should_collide2: proc "c" (rawptr, ^Shape, ^SubShape_ID, ^Shape, ^SubShape_ID) -> bool,
}

Sim_Shape_Filter_Procs :: struct {
    should_collide: proc "c" (rawptr, ^Body, ^Shape, ^SubShape_ID, ^Body, ^Shape, ^SubShape_ID) -> bool,
}

Body_Filter_Procs :: struct {
    should_collide:        proc "c" (rawptr, Body_ID) -> bool,
    should_collide_locked: proc "c" (rawptr, ^Body) -> bool,
}

Body_Draw_Filter_Procs :: struct {
    should_draw: proc "c" (rawptr, ^Body) -> bool,
}

//--------------------------------------------------------------------------------------------------
// Character
//--------------------------------------------------------------------------------------------------

Character_ID :: u32

Character_Base                      :: struct {}
Character                           :: struct { using _: Character_Base }
Character_Virtual                   :: struct { using _: Character_Base }

Character_Vs_Character_Collision    :: struct {}
    /*
    Interface class that allows a CharacterVirtual to check collision with other CharacterVirtual instances.
    Since CharacterVirtual instances are not registered anywhere, it is up to the application to test collision against relevant characters.
    The characters could be stored in a tree structure to make this more efficient.
    */

Character_Contact_Listener          :: struct {}


Character_Base_Settings :: struct {
    /* Vector indicating the up direction of the character */
    up:                             Vec3,

    /* Plane, defined in local space relative to the character. Every contact behind this plane can support the
    character, every contact in front of this plane is treated as only colliding with the player.
    Default: Accept any contact. */
    supporting_volume:              Plane,  // Jolt default: { Vec3::sAxisY(), -1.0e10f };

    /* Maximum angle of slope that character can still walk on (radians). */
    max_slope_angle:                f32,

    /* Set to indicate that extra effort should be made to try to remove ghost contacts (collisions with internal edges of a mesh). This is more expensive but makes bodies move smoother over a mesh with convex edges. */
    enhanced_internal_edge_removal: bool,

    shape:                          ^Shape,
}

Character_Settings :: struct {
    using base:     Character_Base_Settings, /* Inherits Character_Base_Settings */
    layer:          Object_Layer,
    mass:           f32,
    friction:       f32,
    gravity_factor: f32,
    allowed_DOFs:   Allowed_DOFs,
}

Character_Contact_Settings :: struct {
    can_push_character:   bool,
    can_receive_impulses: bool,
}

Character_Contact_Listener_Procs :: struct {
    on_adjust_body_velocity:        proc "c" (rawptr, ^Character_Virtual, ^Body, ^Vec3, ^Vec3),
    on_contact_validate:            proc "c" (rawptr, ^Character_Virtual, Body_ID, SubShape_ID) -> bool,
    on_character_contact_validate:  proc "c" (rawptr, ^Character_Virtual, ^Character_Virtual, SubShape_ID) -> bool,
    on_contact_added:               proc "c" (rawptr, ^Character_Virtual, Body_ID, SubShape_ID, ^RVec3, ^Vec3, ^Character_Contact_Settings),
    on_contact_persisted:           proc "c" (rawptr, ^Character_Virtual, Body_ID, SubShape_ID, ^RVec3, ^Vec3, ^Character_Contact_Settings),
    on_contact_removed:             proc "c" (rawptr, ^Character_Virtual, Body_ID, SubShape_ID),
    on_character_contact_added:     proc "c" (rawptr, ^Character_Virtual, ^Character_Virtual, SubShape_ID, ^RVec3, ^Vec3, ^Character_Contact_Settings),
    on_character_contact_persisted: proc "c" (rawptr, ^Character_Virtual, ^Character_Virtual, SubShape_ID, ^RVec3, ^Vec3, ^Character_Contact_Settings),
    on_character_contact_removed:   proc "c" (rawptr, ^Character_Virtual, Character_ID, SubShape_ID),
    on_contact_solve:               proc "c" (rawptr, ^Character_Virtual, Body_ID, SubShape_ID, ^RVec3, ^Vec3, ^Vec3, ^Physics_Material, ^Vec3, ^Vec3),
    on_character_contact_solve:     proc "c" (rawptr, ^Character_Virtual, ^Character_Virtual, SubShape_ID, ^RVec3, ^Vec3, ^Vec3, ^Physics_Material, ^Vec3, ^Vec3),
}

Character_Virtual_Settings :: struct {
    using base:                  Character_Base_Settings, /* Inherits Character_Base_Settings */
    id:                          Character_ID,
    mass:                        f32,
    max_strength:                f32,
    shape_offset:                Vec3,
    back_face_mode:              BackFace_Mode,
    predictive_contact_distance: f32,
    max_collision_iterations:    u32,
    max_constraint_iterations:   u32,
    min_time_remaining:          f32,
    collision_tolerance:         f32,
    character_padding:           f32,
    max_num_hits:                u32,
    hit_reduction_cos_max_angle: f32,
    penetration_recovery_speed:  f32,
    inner_body_shape:            ^Shape,
    inner_body_id_override:      Body_ID,
    inner_body_layer:            Object_Layer,
}

Character_Virtual_Contact :: struct {
    hash:               u64,
    body_id:            Body_ID,
    character_id:       Character_ID,
    sub_shape_id:       SubShape_ID,
    position:           RVec3,
    linear_velocity:    Vec3,
    contact_normal:     Vec3,
    surface_normal:     Vec3,
    distance:           f32,
    fraction:           f32,
    motion_type:        Motion_Type,

    is_sensor:          bool,
        /* A sensor will receive collision callbacks, but will not cause any collision responses and can be used as a trigger volume. */

    character_virtual:  ^Character_Virtual,
    user_data:          u64,
    material:           ^Physics_Material,
    had_collision:      bool,
    was_discarded:      bool,
    can_push_character: bool,
}

/*
Character_Vs_Character_Collision_Procs
    For CharacterVirtual vs CharacterVirtual.
*/
Character_Vs_Character_Collision_Procs :: struct {
    collide_character: proc "c" (rawptr, ^Character_Virtual, ^RMatrix4x4, ^Collide_Shape_Settings, ^RVec3),
    cast_character:    proc "c" (rawptr, ^Character_Virtual, ^RMatrix4x4, ^Vec3, ^ShapeCast_Settings, ^RVec3),
}

/*
Extended_Update_Settings
    Settings struct for the ExtendedUpdate of a CharacterVirtual.
*/
Extended_Update_Settings :: struct {
    stick_to_floor_step_down:              Vec3,
    walk_stairs_step_up:                   Vec3,
    walk_stairs_min_step_forward:          f32,
    walk_stairs_step_forward_test:         f32,
    walk_stairs_cos_angle_forward_contact: f32,
    walk_stairs_step_down_extra:           Vec3,
}

Ground_State :: enum c.int {
    On_Ground = 0,
    On_SteepGround = 1,
    Not_Supported = 2,
    In_Air = 3,
    _Count,
}

//--------------------------------------------------------------------------------------------------
// Constraints
//--------------------------------------------------------------------------------------------------

Constraint                          :: struct {}
    /*
    A constraint removes one or more degrees of freedom for a rigid body.

    A constraint needs to be added to the Physics_System to have effect.
    */

Two_Body_Constraint                 :: struct { using _: Constraint }
    /*
    Base class for settings for all constraints that involve 2 bodies.
    Body1 is usually considered the parent, Body2 the child.
    */

Cone_Constraint                     :: struct { using _: Two_Body_Constraint }

Distance_Constraint                 :: struct { using _: Two_Body_Constraint }

Fixed_Constraint                    :: struct { using _: Two_Body_Constraint }
    /*
    A fixed constraint welds two bodies together removing all degrees of freedom between them.
    This variant uses Euler angles for the rotation constraint.
    */

Gear_Constraint                     :: struct { using _: Two_Body_Constraint }

Hinge_Constraint                    :: struct { using _: Two_Body_Constraint }

// Path_Constraint                     :: struct { using _: Two_Body_Constraint }
    /* Not implemented */

Point_Constraint                    :: struct { using _: Two_Body_Constraint }

// Pulley_Constraint                   :: struct { using _: Two_Body_Constraint }
    /* Not implemented */

// Rack_And_Pinion_Constraint          :: struct { using _: Two_Body_Constraint }
    /* Not implemented */

SixDOF_Constraint                   :: struct { using _: Two_Body_Constraint }

Slider_Constraint                   :: struct { using _: Two_Body_Constraint }

Swing_Twist_Constraint              :: struct { using _: Two_Body_Constraint }


Vehicle_Constraint                  :: struct { using _: Constraint }

Constraint_Type :: enum c.int {
    Constraint = 0,
    Two_Body_Constraint = 1,
    _Count,
}

Constraint_SubType :: enum c.int {
    Fixed = 0,
    Point = 1,
    Hinge = 2,
    Slider = 3,
    Distance = 4,
    Cone = 5,
    Swing_Twist = 6,
    Six_DOF = 7,
    Path = 8,
    Vehicle = 9,
    Rack_And_Pinion = 10,
    Gear = 11,
    Pulley = 12,
    User1 = 13,
    User2 = 14,
    User3 = 15,
    User4 = 16,
    _Count,
}

Constraint_Space :: enum c.int {
    Local_To_Body_COM = 0,
    World_Space = 1,
    _Count,
}


Constraint_Settings :: struct {
    // If this constraint is enabled initially.
    enabled:                     bool, // Jolt default: true

    // Priority of the constraint when solving. Higher numbers have are more likely to be solved correctly.
    // Note that if you want a deterministic simulation and you cannot guarantee the order in which constraints are added/removed,
    // you can make the priority for all constraints unique to get a deterministic ordering.
    constraint_priority:         u32,  // Jolt default: 0

    // Used only when the constraint is active.
    // Override for the number of solver velocity iterations to run, 0 means use the default in PhysicsSettings::mNumVelocitySteps.
    // The number of iterations to use is the max of all contacts and constraints in the island.
    num_velocity_steps_override: u32,  // Jolt default: 0

    // Used only when the constraint is active.
    // Override for the number of solver position iterations to run, 0 means use the default in PhysicsSettings::mNumPositionSteps.
    // The number of iterations to use is the max of all contacts and constraints in the island.
    num_position_steps_override: u32,  // Jolt default: 0

    // Size of constraint when drawing it through the debug renderer
    draw_constraint_size:        f32,  // Jolt default: 1.0

    // User data value (can be used by application)
    user_data:                   u64,  // Jolt default: 0
}

Cone_Constraint_Settings :: struct {
    using base:      Constraint_Settings, /* Inherits Constraint_Settings */
    space:           Constraint_Space,
    point1:          RVec3,
    twist_axis1:     Vec3,
    point2:          RVec3,
    twist_axis2:     Vec3,
    half_cone_angle: f32,
}

Distance_Constraint_Settings :: struct {
    using base:             Constraint_Settings, /* Inherits Constraint_Settings */
    space:                  Constraint_Space,
    point1:                 RVec3,
    point2:                 RVec3,
    min_distance:           f32,
    max_distance:           f32,
    limits_spring_settings: Spring_Settings,
}

Fixed_Constraint_Settings :: struct {
    using base:        Constraint_Settings, /* Inherits Constraint_Settings */

    // This determines in which space the constraint is setup, all properties below should be in the specified space
    space:             Constraint_Space,    // Jolt default: EConstraintSpace::WorldSpace

    // When space is WorldSpace point1 and point2 can be automatically calculated based on the positions of the bodies when the constraint is created
    // (they will be fixated in their current relative position/orientation). Set this to false if you want to supply the attachment points yourself.
    // Doesn't do anything if the space is Local_To_Body_COM.
    auto_detect_point: bool,                // Jolt default: false

    // Body 1 constraint reference frame (space determined by 'space')
    point1:            RVec3,               // Jolt default: RVec3::sZero()
    axis_x1:           Vec3,                // Jolt default: Vec3::sAxisX()
    axis_y1:           Vec3,                // Jolt default: Vec3::sAxisY()

    // Body 2 constraint reference frame (space determined by 'space')
    point2:            RVec3,               // Jolt default: RVec3::sZero()
    axis_x2:           Vec3,                // Jolt default: Vec3::sAxisX()
    axis_y2:           Vec3,                // Jolt default: Vec3::sAxisY()

    /*
    The axis are only used to set the `mInvInitialOrientation` internally.
    */
}

Gear_Constraint_Settings :: struct {
    using base:  Constraint_Settings, /* Inherits Constraint_Settings */
    space:       Constraint_Space,
    hinge_axis1: Vec3,
    hinge_axis2: Vec3,
    ratio:       f32,
}

Hinge_Constraint_Settings :: struct {
    using base:             Constraint_Settings, /* Inherits Constraint_Settings */

    // This determines in which space the constraint is setup, all properties below should be in the specified space
    space:                  Constraint_Space, // Jolt default: EConstraintSpace::WorldSpace

    // Body 1 constraint reference frame (space determined by mSpace).
    // Hinge axis is the axis where rotation is allowed.
    // When the normal axis of both bodies align in world space, the hinge angle is defined to be 0.
    // mHingeAxis1 and mNormalAxis1 should be perpendicular. mHingeAxis2 and mNormalAxis2 should also be perpendicular.
    // If you configure the joint in world space and create both bodies with a relative rotation you want to be defined as zero,
    // you can simply set mHingeAxis1 = mHingeAxis2 and mNormalAxis1 = mNormalAxis2.
    point1:                 RVec3,           // Jolt default: mPoint1 = RVec3::sZero()
    hinge_axis1:            Vec3,            // Jolt default: mHingeAxis1 = Vec3::sAxisY()
    normal_axis1:           Vec3,            // Jolt default: mNormalAxis1 = Vec3::sAxisX()

    // Body 2 constraint reference frame (space determined by mSpace)
    point2:                 RVec3,           // Jolt default: mPoint2 = RVec3::sZero()
    hinge_axis2:            Vec3,            // Jolt default: mHingeAxis2 = Vec3::sAxisY()
    normal_axis2:           Vec3,            // Jolt default: mNormalAxis2 = Vec3::sAxisX()

    // Rotation around the hinge axis will be limited between [mLimitsMin, mLimitsMax] where mLimitsMin e [-pi, 0] and mLimitsMax e [0, pi].
    // Both angles are in radians.
    limits_min:             f32,             // Jolt default: mLimitsMin = -JPH_PI
    limits_max:             f32,             // Jolt default: mLimitsMax = JPH_PI

    // When enabled, this makes the limits soft. When the constraint exceeds the limits, a spring force will pull it back.
    limits_spring_settings: Spring_Settings, // Jolt default: {}

    // Maximum amount of torque (N m) to apply as friction when the constraint is not powered by a motor
    max_friction_torque:    f32,             // Jolt default: 0.0f

    // In case the constraint is powered, this determines the motor settings around the hinge axis
    motor_settings:         Motor_Settings,  // Jolt default: {}
}

Point_Constraint_Settings :: struct {
    using base:   Constraint_Settings, /* Inherits Constraint_Settings */
    space:        Constraint_Space,
    point1:       RVec3,
    point2:       RVec3,
}

Six_DOF_Constraint_Settings :: struct {
    using base:             Constraint_Settings, /* Inherits Constraint_Settings */
    space:                  Constraint_Space,
    position1:              RVec3,
    axis_x1:                Vec3,
    axis_y1:                Vec3,
    position2:              RVec3,
    axis_x2:                Vec3,
    axis_y2:                Vec3,
    max_friction:           [6]f32,
    swing_type:             Swing_Type,
    limit_min:              [6]f32,
    limit_max:              [6]f32,
    limits_spring_settings: [3]Spring_Settings,
    motor_settings:         [6]Motor_Settings,
}

Six_DOF_Constraint_Axis :: enum c.int {
    Translation_X,
    Translation_Y,
    Translation_Z,
    Rotation_X,
    Rotation_Y,
    Rotation_Z,
    _Num,
    _Num_Translation = 3,
}

Slider_Constraint_Settings :: struct {
    using base:             Constraint_Settings, /* Inherits Constraint_Settings */
    space:                  Constraint_Space,
    auto_detect_point:      bool,
    point1:                 RVec3,
    slider_axis1:           Vec3,
    normal_axis1:           Vec3,
    point2:                 RVec3,
    slider_axis2:           Vec3,
    normal_axis2:           Vec3,
    limits_min:             f32,
    limits_max:             f32,
    limits_spring_settings: Spring_Settings,
    max_friction_force:     f32,
    motor_settings:         Motor_Settings,
}

Swing_Twist_Constraint_Settings :: struct {
    using base:             Constraint_Settings, /* Inherits Constraint_Settings */
    space:                  Constraint_Space,
    position1:              RVec3,
    twist_axis1:            Vec3,
    plane_axis1:            Vec3,
    position2:              RVec3,
    twist_axis2:            Vec3,
    plane_axis2:            Vec3,
    swing_type:             Swing_Type,
    normal_half_cone_angle: f32,
    plane_half_cone_angle:  f32,
    twist_min_angle:        f32,
    twist_max_angle:        f32,
    max_friction_torque:    f32,
    swing_motor_settings:   Motor_Settings,
    twist_motor_settings:   Motor_Settings,
}

Swing_Type :: enum c.int {
    Cone,
    Pyramid,
    _Count,
}

Motor_Settings :: struct {
    spring_settings:  Spring_Settings,
    min_force_limit:  f32,
    max_force_limit:  f32,
    min_torque_limit: f32,
    max_torque_limit: f32,
}

Spring_Settings :: struct {
    mode:                   Spring_Mode,
    frequency_or_stiffness: f32,
    damping:                f32,
}

Spring_Mode :: enum c.int {
    Frequency_And_Damping = 0,
    Stiffness_And_Damping = 1,
    _Count,
}


//--------------------------------------------------------------------------------------------------
// Ragdoll & Skeleton
//--------------------------------------------------------------------------------------------------

Ragdoll_Settings :: struct {}
Ragdoll          :: struct {}

Skeleton         :: struct {}
    /*
    From my understanding:
        This serves as a collection of bodies and constraints configurations to be used for when creating a ragdoll.
        A ragdoll in the end will be just some bodies with constraints, created and linked just as described in the skeleton; nothing fancy.
    */

Skeleton_Joint   :: struct {
    // Name of the joint
    name:               cstring,

    // Name of parent joint
    parent_name:        cstring,

    // Index of parent joint (in mJoints) or -1 if it has no parent
    parent_joint_index: c.int,
}


//--------------------------------------------------------------------------------------------------
// Vehicle
//--------------------------------------------------------------------------------------------------

Vehicle_Transmission_Settings           :: struct {}
Vehicle_Collision_Tester                :: struct {}
Vehicle_Collision_Tester_Ray            :: struct {}
Vehicle_Collision_Tester_Cast_Sphere    :: struct {}
Vehicle_Collision_Tester_Cast_Cylinder  :: struct {}
Vehicle_Controller_Settings             :: struct {}
Wheel                                   :: struct {}
Wheel_WV                                :: struct {}
Wheeled_Vehicle_Controller_Settings     :: struct {}
Wheeled_Vehicle_Controller              :: struct {}


Vehicle_Constraint_Settings :: struct {
    using base:           Constraint_Settings, /* Inherits Constraint_Settings */
    up:                   Vec3,
    forward:              Vec3,
    max_pitch_roll_angle: f32,
    wheels_count:         u32,
    wheels:               ^Wheel_Settings_WV,
    controller:           ^Vehicle_Controller_Settings,
}

Vehicle_Engine_Settings :: struct {
    max_torque:      f32,
    min_rpm:         f32,
    max_rpm:         f32,
    inertia:         f32,
    angular_damping: f32,
}

Wheel_Settings :: struct {
    position:                      Vec3,
    suspension_force_point:        Vec3,
    suspension_direction:          Vec3,
    steering_axis:                 Vec3,
    wheel_up:                      Vec3,
    wheel_forward:                 Vec3,
    suspension_min_length:         f32,
    suspension_max_length:         f32,
    suspension_preload_length:     f32,
    suspension_spring:             Spring_Settings,
    radius:                        f32,
    width:                         f32,
    enable_suspension_force_point: bool,
}

Wheel_Settings_WV :: struct {
    using base:            Wheel_Settings, /* Inherits Character_Base_Settings */
    inertia:               f32,
    angular_damping:       f32,
    max_steer_angle:       f32,
    max_brake_torque:      f32,
    max_hand_brake_torque: f32,
}

Transmission_Mode :: enum c.int {
    Auto = 0,
    Manual = 1,
    _Count,
}

Motor_State :: enum c.int {
    Off = 0,
    Velocity = 1,
    Position = 2,
    _Count,
}

//--------------------------------------------------------------------------------------------------
// Debug
//--------------------------------------------------------------------------------------------------

Color :: u32

Debug_Renderer                          :: struct {}
Body_Draw_Filter                        :: struct {}

// Defines how to color soft body constraints
SoftBody_Constraint_Color :: enum c.int {
    Constraint_Type,
    // Draw different types of constraints in different colors
    Constraint_Group,
    // Draw constraints in the same group in the same color, non-parallel group will be red
    Constraint_Order,
    // Draw constraints in the same group in the same color, non-parallel group will be red, and order within each group will be indicated with gradient
    _Count,
    // Draw constraints in the same group in the same color, non-parallel group will be red, and order within each group will be indicated with gradient
}

BodyManager_ShapeColor :: enum c.int {
    Instance_Color,    // Random color per instance
    Shape_Type_Color,  // Convex = green, scaled = yellow, compound = orange, mesh = red
    Motion_Type_Color, // Static = grey, keyframed = green, dynamic = random color per instance
    Sleep_Color,       // Static = grey, keyframed = green, dynamic = yellow, sleeping = red
    Island_Color,      // Static = grey, active = random color per island, sleeping = light grey
    Material_Color,    // Color as defined by the Physics_Material of the shape
    _Count,
}

Draw_Settings :: struct {
    draw_get_support_function:         bool,                    // Draw the GetSupport() function, used for convex collision detection
    draw_support_direction:            bool,                    // When drawing the support function, also draw which direction mapped to a specific support point
    draw_get_supporting_face:          bool,                    // Draw the faces that were found colliding during collision detection
    draw_shape:                        bool,                    // Draw the shapes of all bodies
    draw_shape_wireframe:              bool,                    // When mDrawShape is true and this is true, the shapes will be drawn in wireframe instead of solid.
    draw_shape_color:                  BodyManager_ShapeColor,  // Coloring scheme to use for shapes
    draw_bounding_box:                 bool,                    // Draw a bounding box per body
    draw_center_of_mass_transform:     bool,                    // Draw the center of mass for each body
    draw_world_transform:              bool,                    // Draw the world transform (which can be different than the center of mass) for each body
    draw_velocity:                     bool,                    // Draw the velocity vector for each body
    draw_mass_and_inertia:             bool,                    // Draw the mass and inertia (as the box equivalent) for each body
    draw_sleep_stats:                  bool,                    // Draw stats regarding the sleeping algorithm of each body
    draw_soft_body_vertices:           bool,                    // Draw the vertices of soft bodies
    draw_soft_body_vertex_velocities:  bool,                    // Draw the velocities of the vertices of soft bodies
    draw_soft_body_edge_constraints:   bool,                    // Draw the edge constraints of soft bodies
    draw_soft_body_bend_constraints:   bool,                    // Draw the bend constraints of soft bodies
    draw_soft_body_volume_constraints: bool,                    // Draw the volume constraints of soft bodies
    draw_soft_body_skin_constraints:   bool,                    // Draw the skin constraints of soft bodies
    draw_soft_body_LRA_constraints:    bool,                    // Draw the LRA constraints of soft bodies
    draw_soft_body_predicted_bounds:   bool,                    // Draw the predicted bounds of soft bodies
    draw_soft_body_constraint_color:   SoftBody_Constraint_Color, // Coloring scheme to use for soft body constraints
}

Debug_Renderer_Procs :: struct {
    draw_line:     proc "c" (rawptr, ^RVec3, ^RVec3, Color),
    draw_triangle: proc "c" (rawptr, ^RVec3, ^RVec3, ^RVec3, Color, Debug_Renderer_CastShadow),
    draw_text3d:   proc "c" (rawptr, ^RVec3, cstring, Color, f32),
}

Debug_Renderer_CastShadow :: enum c.int {
    On = 0,  // This shape should cast a shadow
    Off = 1, // This shape should not cast a shadow
    _Count,
}

Debug_Renderer_DrawMode :: enum c.int {
    Solid = 0,     // Draw as a solid shape
    Wireframe = 1, // Draw as wireframe
    _Count,
}


@(default_calling_convention="c", link_prefix="JPH_")
foreign lib {
    //--------------------------------------------------------------------------------------------------
    // Init
    //--------------------------------------------------------------------------------------------------
    Init                                                  :: proc() -> bool ---
    Shutdown                                              :: proc() ---

    SetTraceHandler                                       :: proc(handler: Trace_Func) ---
    SetAssertFailureHandler                               :: proc(handler: Assert_Failure_Func) ---

    //--------------------------------------------------------------------------------------------------
    // Job_System
    //--------------------------------------------------------------------------------------------------
    JobSystemThreadPool_Create                            :: proc(config: ^Job_System_Thread_Pool_Config) -> ^Job_System ---
        /*
        If Job_System_Thread_Pool_Config is nil, a new configuration will be created with the default values.
        Job_System_Thread_Pool_Config{
            max_jobs = cMaxPhysicsJobs,
            max_barriers = cMaxPhysicsBarriers,
            num_threads = -1,
        }
        numTreads = -1 means "thread::hardware_concurrency() - 1"
        */
    JobSystemCallback_Create                              :: proc(config: ^Job_System_Config) -> ^Job_System ---
    JobSystem_Destroy                                     :: proc(job_system: ^Job_System) ---

    //--------------------------------------------------------------------------------------------------
    // Object Layer & BroadPhase Layer
    //--------------------------------------------------------------------------------------------------
    /* Object_Layer_Pair_Filter */
        /*
        Object layer filter that decides if two objects can collide, this was passed to the Init function.
        */
    ObjectLayerPairFilterTable_Create                     :: proc(num_object_layers: u32) -> ^Object_Layer_Pair_Filter ---
    ObjectLayerPairFilterTable_DisableCollision           :: proc(object_filter: ^Object_Layer_Pair_Filter, layer1: Object_Layer, layer2: Object_Layer) ---
    ObjectLayerPairFilterTable_EnableCollision            :: proc(object_filter: ^Object_Layer_Pair_Filter, layer1: Object_Layer, layer2: Object_Layer) ---
    ObjectLayerPairFilterTable_ShouldCollide              :: proc(object_filter: ^Object_Layer_Pair_Filter, layer1: Object_Layer, layer2: Object_Layer) -> bool ---
    ObjectLayerPairFilterMask_Create                      :: proc() -> ^Object_Layer_Pair_Filter ---
    ObjectLayerPairFilterMask_GetObjectLayer              :: proc(group: u32, mask: u32) -> Object_Layer ---
    ObjectLayerPairFilterMask_GetGroup                    :: proc(layer: Object_Layer) -> u32 ---
    ObjectLayerPairFilterMask_GetMask                     :: proc(layer: Object_Layer) -> u32 ---

    /* BroadPhase_Layer_Interface */
        /*
        This defines a mapping between object and broadphase layers.
        */
    BroadPhaseLayerInterfaceTable_Create                  :: proc(num_object_layers: u32, num_broad_phase_layers: u32) -> ^BroadPhase_Layer_Interface ---
    BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer :: proc(bp_interface: ^BroadPhase_Layer_Interface, object_layer: Object_Layer, broad_phase_layer: BroadPhase_Layer) ---
    BroadPhaseLayerInterfaceMask_Create                   :: proc(num_broad_phase_layers: u32) -> ^BroadPhase_Layer_Interface ---
    BroadPhaseLayerInterfaceMask_ConfigureLayer           :: proc(bp_interface: ^BroadPhase_Layer_Interface, broad_phase_layer: BroadPhase_Layer, groups_to_include: u32, groups_to_exclude: u32) ---

    /* ObjectVsBroadPhase_Layer_Filter */
        /*
        Determines if an object layer can collide with a broadphase layer.
        */
    ObjectVsBroadPhaseLayerFilterTable_Create             :: proc(broad_phase_layer_interface: ^BroadPhase_Layer_Interface, num_broad_phase_layers: u32, object_layer_pair_filter: ^Object_Layer_Pair_Filter, num_object_layers: u32) -> ^ObjectVsBroadPhase_Layer_Filter ---
    ObjectVsBroadPhaseLayerFilterMask_Create              :: proc(broad_phase_layer_interface: ^BroadPhase_Layer_Interface) -> ^ObjectVsBroadPhase_Layer_Filter ---

    //--------------------------------------------------------------------------------------------------
    // Physics_System
    //--------------------------------------------------------------------------------------------------
    /* Setup */
    PhysicsSystem_Create                                  :: proc(settings: ^Physics_System_Settings) -> ^Physics_System ---
    PhysicsSystem_Destroy                                 :: proc(system: ^Physics_System) ---
    PhysicsSystem_SetPhysicsSettings                      :: proc(system: ^Physics_System, settings: ^Physics_Settings) ---
    PhysicsSystem_GetPhysicsSettings                      :: proc(system: ^Physics_System, result: ^Physics_Settings) ---
    PhysicsSystem_Update                                  :: proc(system: ^Physics_System, delta_time: f32, collision_steps: c.int, job_system: ^Job_System) -> Physics_Update_Error ---
    PhysicsSystem_OptimizeBroadPhase                      :: proc(system: ^Physics_System) ---
        /*
        Optimize the broadphase, needed only if you've added many bodies prior to calling Update() for the first time.
        Don't call this every frame as PhysicsSystem::Update spreads out the same work over multiple frames.
        If you add many bodies through BodyInterface::AddBodiesPrepare/AddBodiesFinalize and if the bodies in a batch are
        in a roughly unoccupied space (e.g. a new level section) then a call to OptimizeBroadPhase is also not needed
        as batch adding creates an efficient bounding volume hierarchy.
        Don't call this function while bodies are being modified from another thread or use the locking BodyInterface to modify bodies.
        */
    /* Interfaces */
    PhysicsSystem_GetBodyInterface                        :: proc(system: ^Physics_System) -> ^Body_Interface ---
    PhysicsSystem_GetBodyInterfaceNoLock                  :: proc(system: ^Physics_System) -> ^Body_Interface ---
    PhysicsSystem_GetBodyLockInterface                    :: proc(system: ^Physics_System) -> ^Body_Lock_Interface ---
        /*
        Returns a locking interface that locks the body so other threads cannot modify it.
        */
    PhysicsSystem_GetBodyLockInterfaceNoLock              :: proc(system: ^Physics_System) -> ^Body_Lock_Interface ---
        /*
        Returns a locking interface that won't actually lock the body. Use with great care!
        */
    /* Data */
    PhysicsSystem_GetBodies                               :: proc(system: ^Physics_System, ids: ^Body_ID, count: u32) ---
        /* Note: This seems incorrect from the joltc api. */
    PhysicsSystem_GetNumBodies                            :: proc(system: ^Physics_System) -> u32 ---
    PhysicsSystem_GetNumActiveBodies                      :: proc(system: ^Physics_System, type: Body_Type) -> u32 ---
    PhysicsSystem_GetMaxBodies                            :: proc(system: ^Physics_System) -> u32 ---
    PhysicsSystem_GetNumConstraints                       :: proc(system: ^Physics_System) -> u32 ---
    /* Physics Properties */
    PhysicsSystem_SetGravity                              :: proc(system: ^Physics_System, value: ^Vec3) ---
    PhysicsSystem_GetGravity                              :: proc(system: ^Physics_System, result: ^Vec3) ---
    /* Constraints */
        /* A constraint needs to be added to the physics system to have effect! */
    PhysicsSystem_AddConstraint                           :: proc(system: ^Physics_System, constraint: ^Constraint) ---
    PhysicsSystem_RemoveConstraint                        :: proc(system: ^Physics_System, constraint: ^Constraint) ---
    PhysicsSystem_AddConstraints                          :: proc(system: ^Physics_System, constraints: ^^Constraint, count: u32) ---
    PhysicsSystem_RemoveConstraints                       :: proc(system: ^Physics_System, constraints: ^^Constraint, count: u32) ---
    PhysicsSystem_GetConstraints                          :: proc(system: ^Physics_System, constraints: ^^Constraint, count: u32) ---
    /* Listeners */
    PhysicsSystem_SetContactListener                      :: proc(system: ^Physics_System, listener: ^Contact_Listener) ---
    PhysicsSystem_WereBodiesInContact                     :: proc(system: ^Physics_System, body1: Body_ID, body2: Body_ID) -> bool ---
        /*
        Check if 2 bodies were in contact during the last simulation step. Since contacts are only detected between active bodies, so at least one of the bodies must be active in order for this function to work.
        It queries the state at the time of the last PhysicsSystem::Update and will return true if the bodies were in contact, even if one of the bodies was moved / removed afterwards.
        This function can be called from any thread when the PhysicsSystem::Update is not running. During PhysicsSystem::Update this function is only valid during contact callbacks:
        - During the ContactListener::OnContactAdded callback this function can be used to determine if a different contact pair between the bodies was active in the previous simulation step (function returns true) or if this is the first step that the bodies are touching (function returns false).
        - During the ContactListener::OnContactRemoved callback this function can be used to determine if this is the last contact pair between the bodies (function returns false) or if there are other contacts still present (function returns true).
        */
    PhysicsSystem_SetBodyActivationListener               :: proc(system: ^Physics_System, listener: ^Body_Activation_Listener) ---
    PhysicsSystem_AddStepListener                         :: proc(system: ^Physics_System, listener: ^Physics_Step_Listener) ---
    PhysicsSystem_RemoveStepListener                      :: proc(system: ^Physics_System, listener: ^Physics_Step_Listener) ---
    /* Filters */
    PhysicsSystem_SetSimShapeFilter                       :: proc(system: ^Physics_System, filter: ^SimShape_Filter) ---
    /* Queries */
    PhysicsSystem_GetBroadPhaseQuery                      :: proc(system: ^Physics_System) -> ^BroadPhase_Query ---
    PhysicsSystem_GetNarrowPhaseQuery                     :: proc(system: ^Physics_System) -> ^NarrowPhase_Query ---
    PhysicsSystem_GetNarrowPhaseQueryNoLock               :: proc(system: ^Physics_System) -> ^NarrowPhase_Query ---
    /* Draw */
    PhysicsSystem_DrawBodies                              :: proc(system: ^Physics_System, settings: ^Draw_Settings, renderer: ^Debug_Renderer, body_filter: ^Body_Draw_Filter) ---
    PhysicsSystem_DrawConstraints                         :: proc(system: ^Physics_System, renderer: ^Debug_Renderer) ---
    PhysicsSystem_DrawConstraintLimits                    :: proc(system: ^Physics_System, renderer: ^Debug_Renderer) ---
    PhysicsSystem_DrawConstraintReferenceFrame            :: proc(system: ^Physics_System, renderer: ^Debug_Renderer) ---

    //--------------------------------------------------------------------------------------------------
    // Contact Listeners
    //--------------------------------------------------------------------------------------------------
    ContactListener_Create                                :: proc(contact_listener_data: rawptr) -> ^Contact_Listener ---
        /*
        To set the Contact Listener, use `PhysicsSystem_SetContactListener`.
        */
    ContactListener_Destroy                               :: proc(listener: ^Contact_Listener) ---
    ContactListener_SetProcs                              :: proc(procs: ^Contact_Listener_Procs) ---
        /*
        This sets the procedure for ALL Contact_Listener's statically.

        It's necessary to define a ContactListener for the PhysicsSystem for the procedures to have effect.
        */

    /* Contact Settings */
    ContactSettings_GetIsSensor                           :: proc(settings: ^Contact_Settings) -> bool ---
    ContactSettings_SetIsSensor                           :: proc(settings: ^Contact_Settings, sensor: bool) ---
    ContactSettings_GetFriction                           :: proc(settings: ^Contact_Settings) -> f32 ---
    ContactSettings_SetFriction                           :: proc(settings: ^Contact_Settings, friction: f32) ---
    ContactSettings_GetRestitution                        :: proc(settings: ^Contact_Settings) -> f32 ---
    ContactSettings_SetRestitution                        :: proc(settings: ^Contact_Settings, restitution: f32) ---
    ContactSettings_GetInvMassScale1                      :: proc(settings: ^Contact_Settings) -> f32 ---
    ContactSettings_SetInvMassScale1                      :: proc(settings: ^Contact_Settings, scale: f32) ---
    ContactSettings_GetInvInertiaScale1                   :: proc(settings: ^Contact_Settings) -> f32 ---
    ContactSettings_SetInvInertiaScale1                   :: proc(settings: ^Contact_Settings, scale: f32) ---
    ContactSettings_GetInvMassScale2                      :: proc(settings: ^Contact_Settings) -> f32 ---
    ContactSettings_SetInvMassScale2                      :: proc(settings: ^Contact_Settings, scale: f32) ---
    ContactSettings_GetInvInertiaScale2                   :: proc(settings: ^Contact_Settings) -> f32 ---
    ContactSettings_SetInvInertiaScale2                   :: proc(settings: ^Contact_Settings, scale: f32) ---
    ContactSettings_GetRelativeLinearSurfaceVelocity      :: proc(settings: ^Contact_Settings, result: ^Vec3) ---
    ContactSettings_SetRelativeLinearSurfaceVelocity      :: proc(settings: ^Contact_Settings, velocity: ^Vec3) ---
    ContactSettings_GetRelativeAngularSurfaceVelocity     :: proc(settings: ^Contact_Settings, result: ^Vec3) ---
    ContactSettings_SetRelativeAngularSurfaceVelocity     :: proc(settings: ^Contact_Settings, velocity: ^Vec3) ---

    /* Contact_Manifold */
    ContactManifold_GetWorldSpaceNormal                   :: proc(manifold: ^Contact_Manifold, result: ^Vec3) ---
    ContactManifold_GetPenetrationDepth                   :: proc(manifold: ^Contact_Manifold) -> f32 ---
    ContactManifold_GetSubShapeID1                        :: proc(manifold: ^Contact_Manifold) -> SubShape_ID ---
    ContactManifold_GetSubShapeID2                        :: proc(manifold: ^Contact_Manifold) -> SubShape_ID ---
    ContactManifold_GetPointCount                         :: proc(manifold: ^Contact_Manifold) -> u32 ---
    ContactManifold_GetWorldSpaceContactPointOn1          :: proc(manifold: ^Contact_Manifold, index: u32, result: ^RVec3) ---
    ContactManifold_GetWorldSpaceContactPointOn2          :: proc(manifold: ^Contact_Manifold, index: u32, result: ^RVec3) ---

    //--------------------------------------------------------------------------------------------------
    // Listeners
    //--------------------------------------------------------------------------------------------------
    /* Physics_Step_Listener */
        /*
        A listener class that receives a callback before every physics simulation step
        */
    PhysicsStepListener_Create                            :: proc(user_data: rawptr) -> ^Physics_Step_Listener ---
    PhysicsStepListener_Destroy                           :: proc(listener: ^Physics_Step_Listener) ---
    PhysicsStepListener_SetProcs                          :: proc(procs: ^Physics_Step_Listener_Procs) ---
        /*
        This sets the procedure for ALL Physics_Step_Listener's statically.
        */

    /* BodyActivationListener */
        /*
        Listener that is notified whenever a body is activated/deactivated.
        */
    BodyActivationListener_Create                         :: proc(user_data: rawptr) -> ^Body_Activation_Listener ---
    BodyActivationListener_Destroy                        :: proc(listener: ^Body_Activation_Listener) ---
    BodyActivationListener_SetProcs                       :: proc(procs: ^Body_Activation_Listener_Procs) ---
        /*
        This sets the procedure for ALL Body_Activation_Listener's statically.
        */

    //--------------------------------------------------------------------------------------------------
    // Filters
    //--------------------------------------------------------------------------------------------------
    /* Group_Filter */
    GroupFilterTable_Create                               :: proc(num_sub_groups: u32) -> ^Group_Filter_Table ---
    GroupFilter_Destroy                                   :: proc(group_filter: ^Group_Filter) ---
    GroupFilterTable_DisableCollision                     :: proc(table: ^Group_Filter_Table, sub_group1: Collision_SubGroup_ID, sub_group2: Collision_SubGroup_ID) ---
    GroupFilterTable_EnableCollision                      :: proc(table: ^Group_Filter_Table, sub_group1: Collision_SubGroup_ID, sub_group2: Collision_SubGroup_ID) ---
    GroupFilterTable_IsCollisionEnabled                   :: proc(table: ^Group_Filter_Table, sub_group1: Collision_SubGroup_ID, sub_group2: Collision_SubGroup_ID) -> bool ---
    GroupFilter_CanCollide                                :: proc(group_filter: ^Group_Filter, group1: ^Collision_Group, group2: ^Collision_Group) -> bool ---
    /* BodyFilter */
        /*
        Filter out bodies. Test if should collide with body.
        */
    BodyFilter_Create                                     :: proc(user_data: rawptr) -> ^Body_Filter ---
    BodyFilter_Destroy                                    :: proc(filter: ^Body_Filter) ---
    BodyFilter_SetProcs                                   :: proc(procs: ^Body_Filter_Procs) ---
    /* Shape_Filter */
        /*
        Filter out shapes. Test if should collide with shape.
        */
    ShapeFilter_Create                                    :: proc(user_data: rawptr) -> ^Shape_Filter ---
    ShapeFilter_Destroy                                   :: proc(filter: ^Shape_Filter) ---
    ShapeFilter_SetProcs                                  :: proc(procs: ^Shape_Filter_Procs) ---
    ShapeFilter_GetBodyID2                                :: proc(filter: ^Shape_Filter) -> Body_ID ---
    ShapeFilter_SetBodyID2                                :: proc(filter: ^Shape_Filter, id: Body_ID) ---
    /* SimShape_Filter */
        /*
        Shape filter that will be used during simulation. This can be used to exclude shapes within a body from colliding with each other.
        E.g. if you have a high detail and a low detail collision model, you can attach them to the same body in a StaticCompoundShape and use the Shape_Filter
        to exclude the high detail collision model when simulating and exclude the low detail collision model when casting rays. Note that in this case
        you would need to pass the inverse of inShape_Filter to the CastRay function. Pass a nullptr to disable the shape filter.
        The PhysicsSystem does not own the Shape_Filter, make sure it stays alive during the lifetime of the PhysicsSystem.
        */
    SimShapeFilter_Create                                 :: proc(user_data: rawptr) -> ^SimShape_Filter ---
    SimShapeFilter_Destroy                                :: proc(filter: ^SimShape_Filter) ---
    SimShapeFilter_SetProcs                               :: proc(procs: ^Sim_Shape_Filter_Procs) ---

    //--------------------------------------------------------------------------------------------------
    // Queries
    //--------------------------------------------------------------------------------------------------
    /* ObjectLayerFilter */
    ObjectLayerFilter_SetProcs                            :: proc(procs: ^Object_Layer_Filter_Procs) ---
    ObjectLayerFilter_Create                              :: proc(user_data: rawptr) -> ^ObjectLayer_Filter ---
    ObjectLayerFilter_Destroy                             :: proc(filter: ^ObjectLayer_Filter) ---

    /* BroadPhase_Layer_Filter */
    BroadPhaseLayerFilter_SetProcs                        :: proc(procs: ^Broad_Phase_Layer_Filter_Procs) ---
    BroadPhaseLayerFilter_Create                          :: proc(user_data: rawptr) -> ^BroadPhase_Layer_Filter ---
    BroadPhaseLayerFilter_Destroy                         :: proc(filter: ^BroadPhase_Layer_Filter) ---

    /*  BroadPhase_Query */
    BroadPhaseQuery_CastRay                               :: proc(query: ^BroadPhase_Query, origin: ^Vec3, direction: ^Vec3, callback: RayCast_Body_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter) -> bool ---
    BroadPhaseQuery_CastRay2                              :: proc(query: ^BroadPhase_Query, origin: ^Vec3, direction: ^Vec3, collector_type: Collision_Collector_Type, callback: RayCast_Body_Result_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter) -> bool ---
    BroadPhaseQuery_CollideAABox                          :: proc(query: ^BroadPhase_Query, box: ^AABox, callback: Collide_Shape_Body_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter) -> bool ---
    BroadPhaseQuery_CollideSphere                         :: proc(query: ^BroadPhase_Query, center: ^Vec3, radius: f32, callback: Collide_Shape_Body_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter) -> bool ---
    BroadPhaseQuery_CollidePoint                          :: proc(query: ^BroadPhase_Query, point: ^Vec3, callback: Collide_Shape_Body_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter) -> bool ---

    /*  NarrowPhase_Query */
    NarrowPhaseQuery_CastRay                              :: proc(query: ^NarrowPhase_Query, origin: ^RVec3, direction: ^Vec3, hit: ^RayCast_Result, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter) -> bool ---
    NarrowPhaseQuery_CastRay2                             :: proc(query: ^NarrowPhase_Query, origin: ^RVec3, direction: ^Vec3, ray_cast_settings: ^RayCast_Settings, callback: CastRay_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CastRay3                             :: proc(query: ^NarrowPhase_Query, origin: ^RVec3, direction: ^Vec3, ray_cast_settings: ^RayCast_Settings, collector_type: Collision_Collector_Type, callback: CastRay_Result_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CollidePoint                         :: proc(query: ^NarrowPhase_Query, point: ^RVec3, callback: Collide_Point_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CollidePoint2                        :: proc(query: ^NarrowPhase_Query, point: ^RVec3, collector_type: Collision_Collector_Type, callback: Collide_Point_Result_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CollideShape                         :: proc(query: ^NarrowPhase_Query, shape: ^Shape, scale: ^Vec3, center_of_mass_transform: ^RMatrix4x4, settings: ^Collide_Shape_Settings, baseOffset: ^RVec3, callback: Collide_Shape_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CollideShape2                        :: proc(query: ^NarrowPhase_Query, shape: ^Shape, scale: ^Vec3, center_of_mass_transform: ^RMatrix4x4, settings: ^Collide_Shape_Settings, baseOffset: ^RVec3, collector_type: Collision_Collector_Type, callback: Collide_Shape_Result_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CastShape                            :: proc(query: ^NarrowPhase_Query, shape: ^Shape, worldTransform: ^RMatrix4x4, direction: ^Vec3, settings: ^ShapeCast_Settings, baseOffset: ^RVec3, callback: CastShape_Collector_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    NarrowPhaseQuery_CastShape2                           :: proc(query: ^NarrowPhase_Query, shape: ^Shape, worldTransform: ^RMatrix4x4, direction: ^Vec3, settings: ^ShapeCast_Settings, baseOffset: ^RVec3, collector_type: Collision_Collector_Type, callback: CastShape_Result_Callback, user_data: rawptr, broad_phase_layer_filter: ^BroadPhase_Layer_Filter, object_layer_filter: ^ObjectLayer_Filter, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---

    //--------------------------------------------------------------------------------------------------
    // Body
    //--------------------------------------------------------------------------------------------------
    /* Body Creation */
    BodyCreationSettings_Create                           :: proc() -> ^Body_Creation_Settings ---
    BodyCreationSettings_Create2                          :: proc(settings: ^Shape_Settings, position: ^RVec3, rotation: ^Quat, motion_type: Motion_Type, object_layer: Object_Layer) -> ^Body_Creation_Settings ---
    BodyCreationSettings_Create3                          :: proc(shape: ^Shape, position: ^RVec3, rotation: ^Quat, motion_type: Motion_Type, object_layer: Object_Layer) -> ^Body_Creation_Settings ---
    BodyCreationSettings_Destroy                          :: proc(settings: ^Body_Creation_Settings) ---
    /* Body Transforms */
    BodyCreationSettings_GetPosition                      :: proc(settings: ^Body_Creation_Settings, result: ^RVec3) ---
    BodyCreationSettings_SetPosition                      :: proc(settings: ^Body_Creation_Settings, value: ^RVec3) ---
    BodyCreationSettings_GetRotation                      :: proc(settings: ^Body_Creation_Settings, result: ^Quat) ---
    BodyCreationSettings_SetRotation                      :: proc(settings: ^Body_Creation_Settings, value: ^Quat) ---
    BodyCreationSettings_GetLinearVelocity                :: proc(settings: ^Body_Creation_Settings, velocity: ^Vec3) ---
    BodyCreationSettings_SetLinearVelocity                :: proc(settings: ^Body_Creation_Settings, velocity: ^Vec3) ---
    BodyCreationSettings_GetAngularVelocity               :: proc(settings: ^Body_Creation_Settings, velocity: ^Vec3) ---
    BodyCreationSettings_SetAngularVelocity               :: proc(settings: ^Body_Creation_Settings, velocity: ^Vec3) ---
    /* Body Properties */
    BodyCreationSettings_GetMotionType                    :: proc(settings: ^Body_Creation_Settings) -> Motion_Type ---
    BodyCreationSettings_SetMotionType                    :: proc(settings: ^Body_Creation_Settings, value: Motion_Type) ---
    BodyCreationSettings_GetMotionQuality                 :: proc(settings: ^Body_Creation_Settings) -> Motion_Quality ---
    BodyCreationSettings_SetMotionQuality                 :: proc(settings: ^Body_Creation_Settings, value: Motion_Quality) ---
    BodyCreationSettings_GetAllowSleeping                 :: proc(settings: ^Body_Creation_Settings) -> bool ---
    BodyCreationSettings_SetAllowSleeping                 :: proc(settings: ^Body_Creation_Settings, value: bool) ---
    BodyCreationSettings_GetAllowedDOFs                   :: proc(settings: ^Body_Creation_Settings) -> Allowed_DOFs ---
    BodyCreationSettings_SetAllowedDOFs                   :: proc(settings: ^Body_Creation_Settings, value: Allowed_DOFs) ---
    BodyCreationSettings_GetEnhancedInternalEdgeRemoval   :: proc(settings: ^Body_Creation_Settings) -> bool ---
    BodyCreationSettings_SetEnhancedInternalEdgeRemoval   :: proc(settings: ^Body_Creation_Settings, value: bool) ---
        /*
        Set to indicate that extra effort should be made to try to remove ghost contacts (collisions with internal edges of a mesh).
        This is more expensive but makes bodies move smoother over a mesh with convex edges.
        */
    BodyCreationSettings_SetAllowDynamicOrKinematic       :: proc(settings: ^Body_Creation_Settings, value: bool) ---
    BodyCreationSettings_GetAllowDynamicOrKinematic       :: proc(settings: ^Body_Creation_Settings) -> bool ---
    BodyCreationSettings_SetCollideKinematicVsNonDynamic  :: proc(settings: ^Body_Creation_Settings, value: bool) ---
    BodyCreationSettings_GetCollideKinematicVsNonDynamic  :: proc(settings: ^Body_Creation_Settings) -> bool ---
        /*
        If kinematic objects can generate contact points against other kinematic or static objects.
        Note that turning this on can be CPU intensive as much more collision detection work will be done without any effect on the simulation (kinematic objects are not affected by other kinematic/static objects).
        This can be used to make sensors detect static objects. Note that the sensor must be kinematic and active for it to detect static objects.
        */
    BodyCreationSettings_GetObjectLayer                   :: proc(settings: ^Body_Creation_Settings) -> Object_Layer ---
    BodyCreationSettings_SetObjectLayer                   :: proc(settings: ^Body_Creation_Settings, object_layer: Object_Layer) ---
    BodyCreationSettings_GetCollissionGroup               :: proc(settings: ^Body_Creation_Settings, result: ^Collision_Group) ---
    BodyCreationSettings_SetCollissionGroup               :: proc(settings: ^Body_Creation_Settings, collision_group: ^Collision_Group) ---
    BodyCreationSettings_GetUserData                      :: proc(settings: ^Body_Creation_Settings) -> u64 ---
    BodyCreationSettings_SetUserData                      :: proc(settings: ^Body_Creation_Settings, user_data: u64) ---
    BodyCreationSettings_GetIsSensor                      :: proc(settings: ^Body_Creation_Settings) -> bool ---
    BodyCreationSettings_SetIsSensor                      :: proc(settings: ^Body_Creation_Settings, is_sensor: bool) ---
    BodyCreationSettings_GetUseManifoldReduction          :: proc(settings: ^Body_Creation_Settings) -> bool ---
    BodyCreationSettings_SetUseManifoldReduction          :: proc(settings: ^Body_Creation_Settings, use_manifold_reduction: bool) ---
    /* Body Physics Properties */
    BodyCreationSettings_GetMaxLinearVelocity             :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetMaxLinearVelocity             :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetMaxAngularVelocity            :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetMaxAngularVelocity            :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetGravityFactor                 :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetGravityFactor                 :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetInertiaMultiplier             :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetInertiaMultiplier             :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetFriction                      :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetFriction                      :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetRestitution                   :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetRestitution                   :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetLinearDamping                 :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetLinearDamping                 :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetAngularDamping                :: proc(settings: ^Body_Creation_Settings) -> f32 ---
    BodyCreationSettings_SetAngularDamping                :: proc(settings: ^Body_Creation_Settings, value: f32) ---
    BodyCreationSettings_GetOverrideMassProperties        :: proc(settings: ^Body_Creation_Settings) -> Override_Mass_Properties ---
    BodyCreationSettings_SetOverrideMassProperties        :: proc(settings: ^Body_Creation_Settings, value: Override_Mass_Properties) ---
    BodyCreationSettings_GetMassPropertiesOverride        :: proc(settings: ^Body_Creation_Settings, result: ^Mass_Properties) ---
    BodyCreationSettings_SetMassPropertiesOverride        :: proc(settings: ^Body_Creation_Settings, mass_properties: ^Mass_Properties) ---
    BodyCreationSettings_GetNumVelocityStepsOverride      :: proc(settings: ^Body_Creation_Settings) -> u32 ---
    BodyCreationSettings_SetNumVelocityStepsOverride      :: proc(settings: ^Body_Creation_Settings, value: u32) ---
    BodyCreationSettings_GetNumPositionStepsOverride      :: proc(settings: ^Body_Creation_Settings) -> u32 ---
    BodyCreationSettings_SetNumPositionStepsOverride      :: proc(settings: ^Body_Creation_Settings, value: u32) ---
    BodyCreationSettings_GetApplyGyroscopicForce          :: proc(settings: ^Body_Creation_Settings) -> bool ---
    BodyCreationSettings_SetApplyGyroscopicForce          :: proc(settings: ^Body_Creation_Settings, value: bool) ---

    /* SoftBody_Creation_Settings */
    SoftBodyCreationSettings_Create                       :: proc() -> ^SoftBody_Creation_Settings ---
    SoftBodyCreationSettings_Destroy                      :: proc(settings: ^SoftBody_Creation_Settings) ---

    /*
    Body_Interface
        Access to the body interface. This interface allows to to create / remove bodies and to change their properties.
    */
    /* Body Creation */
    BodyInterface_CreateBody                              :: proc(body_interface: ^Body_Interface, settings: ^Body_Creation_Settings) -> ^Body ---
    BodyInterface_CreateBodyWithoutID                     :: proc(body_interface: ^Body_Interface, settings: ^Body_Creation_Settings) -> ^Body ---
    BodyInterface_CreateBodyWithID                        :: proc(body_interface: ^Body_Interface, body_id: Body_ID, settings: ^Body_Creation_Settings) -> ^Body ---
    BodyInterface_CreateAndAddBody                        :: proc(body_interface: ^Body_Interface, settings: ^Body_Creation_Settings, activation_mode: Activation) -> Body_ID ---
    BodyInterface_CreateSoftBody                          :: proc(body_interface: ^Body_Interface, settings: ^SoftBody_Creation_Settings) -> ^Body ---
    BodyInterface_CreateSoftBodyWithID                    :: proc(body_interface: ^Body_Interface, body_id: Body_ID, settings: ^SoftBody_Creation_Settings) -> ^Body ---
    BodyInterface_CreateSoftBodyWithoutID                 :: proc(body_interface: ^Body_Interface, settings: ^SoftBody_Creation_Settings) -> ^Body ---
    BodyInterface_CreateAndAddSoftBody                    :: proc(body_interface: ^Body_Interface, settings: ^SoftBody_Creation_Settings, activation_mode: Activation) -> Body_ID ---
    BodyInterface_DestroyBody                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID) ---
    BodyInterface_DestroyBodyWithoutID                    :: proc(body_interface: ^Body_Interface, body: ^Body) ---
    /* Body Properties */
    BodyInterface_AssignBodyID                            :: proc(body_interface: ^Body_Interface, body: ^Body) -> bool ---
    BodyInterface_AssignBodyID2                           :: proc(body_interface: ^Body_Interface, body: ^Body, body_id: Body_ID) -> bool ---
    BodyInterface_UnassignBodyID                          :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> ^Body ---
    BodyInterface_IsAdded                                 :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> bool ---
    BodyInterface_AddBody                                 :: proc(body_interface: ^Body_Interface, body_id: Body_ID, activation_mode: Activation) ---
    BodyInterface_RemoveBody                              :: proc(body_interface: ^Body_Interface, body_id: Body_ID) ---
    BodyInterface_RemoveAndDestroyBody                    :: proc(body_interface: ^Body_Interface, body_id: Body_ID) ---
    BodyInterface_IsActive                                :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> bool ---
        /* If this body is currently actively simulating (true) or sleeping (false) */
    BodyInterface_ActivateBody                            :: proc(body_interface: ^Body_Interface, body_id: Body_ID) ---
        /*
        If the body is not static, then:
            Resets sleeping timer so that we don't immediately go to sleep again
            Check if we're sleeping, if so, add to be activated by the body manager and call `OnBodyActivated` on the BodyActivationListener.
        */
    BodyInterface_DeactivateBody                          :: proc(body_interface: ^Body_Interface, body_id: Body_ID) ---
        /*
        If the body is active, then:
            Mark the body as no longer active.
            Reset its linear and angular velocity.
            Call `OnBodyDeactivated` on the BodyActivationListener.
        */
    BodyInterface_GetBodyType                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> Body_Type ---
    BodyInterface_GetShape                                :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> ^Shape ---
    BodyInterface_SetShape                                :: proc(body_interface: ^Body_Interface, body_id: Body_ID, shape: ^Shape, update_mass_properties: bool, activation_mode: Activation) ---
    BodyInterface_GetMotionType                           :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> Motion_Type ---
    BodyInterface_SetMotionType                           :: proc(body_interface: ^Body_Interface, body_id: Body_ID, motion_type: Motion_Type, activation_mode: Activation) ---
    BodyInterface_GetObjectLayer                          :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> Object_Layer ---
    BodyInterface_SetObjectLayer                          :: proc(body_interface: ^Body_Interface, body_id: Body_ID, layer: Object_Layer) ---
    BodyInterface_GetCollissionGroup                      :: proc(body_interface: ^Body_Interface, body_id: Body_ID, result: ^Collision_Group) ---
    BodyInterface_SetCollissionGroup                      :: proc(body_interface: ^Body_Interface, body_id: Body_ID, group: ^Collision_Group) ---
    BodyInterface_NotifyShapeChanged                      :: proc(body_interface: ^Body_Interface, body_id: Body_ID, previous_center_of_mass: ^Vec3, update_mass_properties: bool, activation_mode: Activation) ---
    BodyInterface_SetMotionQuality                        :: proc(body_interface: ^Body_Interface, body_id: Body_ID, quality: Motion_Quality) ---
    BodyInterface_GetMotionQuality                        :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> Motion_Quality ---
    BodyInterface_SetUseManifoldReduction                 :: proc(body_interface: ^Body_Interface, body_id: Body_ID, value: bool) ---
    BodyInterface_GetUseManifoldReduction                 :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> bool ---
    BodyInterface_SetUserData                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, user_data: u64) ---
    BodyInterface_GetUserData                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> u64 ---
    BodyInterface_InvalidateContactCache                  :: proc(body_interface: ^Body_Interface, body_id: Body_ID) ---
    /* Body Transforms */
    BodyInterface_GetCenterOfMassPosition                 :: proc(body_interface: ^Body_Interface, body_id: Body_ID, position: ^RVec3) ---
    BodyInterface_GetCenterOfMassTransform                :: proc(body_interface: ^Body_Interface, body_id: Body_ID, result: ^RMatrix4x4) ---
    BodyInterface_GetWorldTransform                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, result: ^RMatrix4x4) ---
    BodyInterface_SetPosition                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, position: ^RVec3, activation_mode: Activation) ---
    BodyInterface_GetPosition                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, result: ^RVec3) ---
    BodyInterface_SetRotation                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, rotation: ^Quat, activation_mode: Activation) ---
    BodyInterface_GetRotation                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, result: ^Quat) ---
    BodyInterface_SetPositionAndRotation                  :: proc(body_interface: ^Body_Interface, body_id: Body_ID, position: ^RVec3, rotation: ^Quat, activation_mode: Activation) ---
    BodyInterface_GetPositionAndRotation                  :: proc(body_interface: ^Body_Interface, body_id: Body_ID, position: ^RVec3, rotation: ^Quat) ---
    BodyInterface_SetPositionAndRotationWhenChanged       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, position: ^RVec3, rotation: ^Quat, activation_mode: Activation) ---
    BodyInterface_SetLinearVelocity                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, velocity: ^Vec3) ---
    BodyInterface_GetLinearVelocity                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, velocity: ^Vec3) ---
    BodyInterface_AddLinearVelocity                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, linear_velocity: ^Vec3) ---
    BodyInterface_GetPointVelocity                        :: proc(body_interface: ^Body_Interface, body_id: Body_ID, point: ^RVec3, velocity: ^Vec3) ---
    BodyInterface_SetAngularVelocity                      :: proc(body_interface: ^Body_Interface, body_id: Body_ID, angular_velocity: ^Vec3) ---
    BodyInterface_GetAngularVelocity                      :: proc(body_interface: ^Body_Interface, body_id: Body_ID, angular_velocity: ^Vec3) ---
    BodyInterface_AddLinearAndAngularVelocity             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, linear_velocity: ^Vec3, angular_velocity: ^Vec3) ---
    BodyInterface_SetLinearAndAngularVelocity             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, linear_velocity: ^Vec3, angular_velocity: ^Vec3) ---
    BodyInterface_GetLinearAndAngularVelocity             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, linear_velocity: ^Vec3, angular_velocity: ^Vec3) ---
    BodyInterface_SetPositionRotationAndVelocity          :: proc(body_interface: ^Body_Interface, body_id: Body_ID, position: ^RVec3, rotation: ^Quat, linear_velocity: ^Vec3, angular_velocity: ^Vec3) ---
    /* Body Forces */
    BodyInterface_GetRestitution                          :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> f32 ---
    BodyInterface_SetRestitution                          :: proc(body_interface: ^Body_Interface, body_id: Body_ID, restitution: f32) ---
    BodyInterface_GetFriction                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> f32 ---
    BodyInterface_SetFriction                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, friction: f32) ---
    BodyInterface_MoveKinematic                           :: proc(body_interface: ^Body_Interface, body_id: Body_ID, target_position: ^RVec3, target_rotation: ^Quat, delta_time: f32) ---
        /*
        Set velocity of body such that it will be positioned at inTargetPosition/Rotation in inDeltaTime seconds.
        The BodyInterface::MoveKinematic will wake up the body if is sleeping, the Body::MoveKinematic will not.
        */
    BodyInterface_AddForce                                :: proc(body_interface: ^Body_Interface, body_id: Body_ID, force: ^Vec3) ---
    BodyInterface_AddForce2                               :: proc(body_interface: ^Body_Interface, body_id: Body_ID, force: ^Vec3, point: ^RVec3) ---
    BodyInterface_AddTorque                               :: proc(body_interface: ^Body_Interface, body_id: Body_ID, torque: ^Vec3) ---
    BodyInterface_AddForceAndTorque                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, force: ^Vec3, torque: ^Vec3) ---
    BodyInterface_AddImpulse                              :: proc(body_interface: ^Body_Interface, body_id: Body_ID, impulse: ^Vec3) ---
    BodyInterface_AddImpulse2                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, impulse: ^Vec3, point: ^RVec3) ---
    BodyInterface_AddAngularImpulse                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, angular_impulse: ^Vec3) ---
    BodyInterface_ApplyBuoyancyImpulse                    :: proc(body_interface: ^Body_Interface, body_id: Body_ID, surface_position: ^RVec3, surface_normal: ^Vec3, buoyancy: f32, linear_drag: f32, angular_drag: f32, fluid_velocity: ^Vec3, gravity: ^Vec3, delta_time: f32) -> bool ---
    BodyInterface_SetGravityFactor                        :: proc(body_interface: ^Body_Interface, body_id: Body_ID, value: f32) ---
    BodyInterface_GetGravityFactor                        :: proc(body_interface: ^Body_Interface, body_id: Body_ID) -> f32 ---
    BodyInterface_GetInverseInertia                       :: proc(body_interface: ^Body_Interface, body_id: Body_ID, result: ^Matrix4x4) ---
    BodyInterface_GetMaterial                             :: proc(body_interface: ^Body_Interface, body_id: Body_ID, sub_shape_id: SubShape_ID) -> ^Physics_Material ---

    /* Body_Lock_Interface */
    BodyLockInterface_LockRead                            :: proc(lock_interface: ^Body_Lock_Interface, body_id: Body_ID, lock: ^Body_Lock_Read) ---
    BodyLockInterface_UnlockRead                          :: proc(lock_interface: ^Body_Lock_Interface, io_lock: ^Body_Lock_Read) ---
    BodyLockInterface_LockWrite                           :: proc(lock_interface: ^Body_Lock_Interface, body_id: Body_ID, lock: ^Body_Lock_Write) ---
        /*
        Pending for testing:
            body_lock_write: jolt.BodyLockWrite
            jolt.BodyLockInterface_LockWrite(body_lock_interface, body_id, &body_lock_write)
            defer jolt.BodyLockInterface_UnlockWrite(body_lock_interface, &body_lock_write)

            // Can I now use `body_lock_write.body`?
        */
    BodyLockInterface_UnlockWrite                         :: proc(lock_interface: ^Body_Lock_Interface, io_lock: ^Body_Lock_Write) ---
    BodyLockInterface_LockMultiRead                       :: proc(lock_interface: ^Body_Lock_Interface, body_id: ^Body_ID, count: u32) -> ^Body_Lock_MultiRead ---
    BodyLockInterface_LockMultiWrite                      :: proc(lock_interface: ^Body_Lock_Interface, body_id: ^Body_ID, count: u32) -> ^Body_Lock_MultiWrite ---
    BodyLockMultiRead_GetBody                             :: proc(io_lock: ^Body_Lock_MultiRead, body_index: u32) -> ^Body ---
    BodyLockMultiRead_Destroy                             :: proc(io_lock: ^Body_Lock_MultiRead) ---
    BodyLockMultiWrite_GetBody                            :: proc(io_lock: ^Body_Lock_MultiWrite, body_index: u32) -> ^Body ---
    BodyLockMultiWrite_Destroy                            :: proc(io_lock: ^Body_Lock_MultiWrite) ---

    /* Body */
    /* Body Imutable Properties */
    Body_GetID                                            :: proc(body: ^Body) -> Body_ID ---
    Body_GetBodyType                                      :: proc(body: ^Body) -> Body_Type ---
    Body_GetShape                                         :: proc(body: ^Body) -> ^Shape ---
    Body_IsRigidBody                                      :: proc(body: ^Body) -> bool ---
    Body_IsSoftBody                                       :: proc(body: ^Body) -> bool ---
    Body_IsActive                                         :: proc(body: ^Body) -> bool ---
        /* If this body is currently actively simulating (true) or sleeping (false) */
    Body_IsStatic                                         :: proc(body: ^Body) -> bool ---
    Body_IsKinematic                                      :: proc(body: ^Body) -> bool ---
    Body_IsDynamic                                        :: proc(body: ^Body) -> bool ---
    Body_CanBeKinematicOrDynamic                          :: proc(body: ^Body) -> bool ---
    Body_GetObjectLayer                                   :: proc(body: ^Body) -> Object_Layer ---
    Body_GetBroadPhaseLayer                               :: proc(body: ^Body) -> BroadPhase_Layer ---
    Body_IsInBroadPhase                                   :: proc(body: ^Body) -> bool ---
    Body_IsCollisionCacheInvalid                          :: proc(body: ^Body) -> bool ---
    /* Body Mutable Properties */
    Body_GetMotionType                                    :: proc(body: ^Body) -> Motion_Type ---
    Body_SetMotionType                                    :: proc(body: ^Body, motion_type: Motion_Type) ---
    Body_SetCollideKinematicVsNonDynamic                  :: proc(body: ^Body, value: bool) ---
    Body_GetCollideKinematicVsNonDynamic                  :: proc(body: ^Body) -> bool ---
    Body_SetEnhancedInternalEdgeRemoval                   :: proc(body: ^Body, value: bool) ---
    Body_GetEnhancedInternalEdgeRemoval                   :: proc(body: ^Body) -> bool ---
    Body_GetEnhancedInternalEdgeRemovalWithBody           :: proc(body: ^Body, other: ^Body) -> bool ---
    Body_SetIsSensor                                      :: proc(body: ^Body, value: bool) ---
    Body_IsSensor                                         :: proc(body: ^Body) -> bool ---
    Body_GetAllowSleeping                                 :: proc(body: ^Body) -> bool ---
    Body_SetAllowSleeping                                 :: proc(body: ^Body, allow_sleeping: bool) ---
    Body_ResetSleepTimer                                  :: proc(body: ^Body) ---
    Body_GetCollissionGroup                               :: proc(body: ^Body, result: ^Collision_Group) ---
    Body_SetCollissionGroup                               :: proc(body: ^Body, value: ^Collision_Group) ---
    Body_SetUseManifoldReduction                          :: proc(body: ^Body, value: bool) ---
    Body_GetUseManifoldReduction                          :: proc(body: ^Body) -> bool ---
    Body_GetUseManifoldReductionWithBody                  :: proc(body: ^Body, other: ^Body) -> bool ---
    Body_SetUserData                                      :: proc(body: ^Body, user_data: u64) ---
    Body_GetUserData                                      :: proc(body: ^Body) -> u64 ---
    /* Body Imutable Physics Properties */
    Body_GetWorldTransform                                :: proc(body: ^Body, result: ^RMatrix4x4) ---
    Body_GetCenterOfMassPosition                          :: proc(body: ^Body, result: ^RVec3) ---
    Body_GetCenterOfMassTransform                         :: proc(body: ^Body, result: ^RMatrix4x4) ---
    Body_GetInverseCenterOfMassTransform                  :: proc(body: ^Body, result: ^RMatrix4x4) ---
    Body_GetPosition                                      :: proc(body: ^Body, result: ^RVec3) ---
    Body_GetRotation                                      :: proc(body: ^Body, result: ^Quat) ---
    Body_GetWorldSpaceBounds                              :: proc(body: ^Body, result: ^AABox) ---
    Body_GetWorldSpaceSurfaceNormal                       :: proc(body: ^Body, sub_shape_id: SubShape_ID, position: ^RVec3, normal: ^Vec3) ---
    Body_GetMotionProperties                              :: proc(body: ^Body) -> ^Motion_Properties ---
    Body_GetMotionPropertiesUnchecked                     :: proc(body: ^Body) -> ^Motion_Properties ---
    Body_GetFixedToWorldBody                              :: proc() -> ^Body ---
    /* Body Mutable Physics Properties */
    Body_GetLinearVelocity                                :: proc(body: ^Body, velocity: ^Vec3) ---
    Body_SetLinearVelocity                                :: proc(body: ^Body, velocity: ^Vec3) ---
    Body_SetLinearVelocityClamped                         :: proc(body: ^Body, velocity: ^Vec3) ---
    Body_GetAngularVelocity                               :: proc(body: ^Body, velocity: ^Vec3) ---
    Body_SetAngularVelocity                               :: proc(body: ^Body, velocity: ^Vec3) ---
    Body_SetAngularVelocityClamped                        :: proc(body: ^Body, velocity: ^Vec3) ---
    Body_GetPointVelocityCOM                              :: proc(body: ^Body, point_relative_to_COM: ^Vec3, velocity: ^Vec3) ---
    Body_GetPointVelocity                                 :: proc(body: ^Body, point: ^RVec3, velocity: ^Vec3) ---
    Body_GetInverseInertia                                :: proc(body: ^Body, result: ^Matrix4x4) ---
    Body_GetFriction                                      :: proc(body: ^Body) -> f32 ---
    Body_SetFriction                                      :: proc(body: ^Body, friction: f32) ---
    Body_GetRestitution                                   :: proc(body: ^Body) -> f32 ---
    Body_SetRestitution                                   :: proc(body: ^Body, restitution: f32) ---
    /* Body Forces */
    Body_MoveKinematic                                    :: proc(body: ^Body, target_position: ^RVec3, target_rotation: ^Quat, delta_time: f32) ---
    Body_AddForce                                         :: proc(body: ^Body, force: ^Vec3) ---
    Body_AddForceAtPosition                               :: proc(body: ^Body, force: ^Vec3, position: ^RVec3) ---
    Body_GetAccumulatedForce                              :: proc(body: ^Body, force: ^Vec3) ---
    Body_ResetForce                                       :: proc(body: ^Body) ---
    Body_AddTorque                                        :: proc(body: ^Body, force: ^Vec3) ---
    Body_GetAccumulatedTorque                             :: proc(body: ^Body, force: ^Vec3) ---
    Body_ResetTorque                                      :: proc(body: ^Body) ---
    Body_ResetMotion                                      :: proc(body: ^Body) ---
    Body_AddImpulse                                       :: proc(body: ^Body, impulse: ^Vec3) ---
    Body_AddImpulseAtPosition                             :: proc(body: ^Body, impulse: ^Vec3, position: ^RVec3) ---
    Body_AddAngularImpulse                                :: proc(body: ^Body, angular_impulse: ^Vec3) ---
    Body_ApplyBuoyancyImpulse                             :: proc(body: ^Body, surface_position: ^RVec3, surface_normal: ^Vec3, buoyancy: f32, linear_drag: f32, angular_drag: f32, fluid_velocity: ^Vec3, gravity: ^Vec3, delta_time: f32) -> bool ---
    Body_SetApplyGyroscopicForce                          :: proc(body: ^Body, value: bool) ---
    Body_GetApplyGyroscopicForce                          :: proc(body: ^Body) -> bool ---

    //--------------------------------------------------------------------------------------------------
    // Character
    //--------------------------------------------------------------------------------------------------
    CharacterBase_Destroy                                 :: proc(character: ^Character_Base) ---
    CharacterBase_GetShape                                :: proc(character: ^Character_Base) -> ^Shape ---
    CharacterBase_IsSupported                             :: proc(character: ^Character_Base) -> bool ---
    CharacterBase_GetUp                                   :: proc(character: ^Character_Base, result: ^Vec3) ---
    CharacterBase_SetUp                                   :: proc(character: ^Character_Base, value: ^Vec3) ---
    CharacterBase_IsSlopeTooSteep                         :: proc(character: ^Character_Base, value: ^Vec3) -> bool ---
    CharacterBase_GetCosMaxSlopeAngle                     :: proc(character: ^Character_Base) -> f32 ---
    CharacterBase_SetMaxSlopeAngle                        :: proc(character: ^Character_Base, max_slope_angle: f32) ---
    CharacterBase_GetGroundState                          :: proc(character: ^Character_Base) -> Ground_State ---
    CharacterBase_GetGroundPosition                       :: proc(character: ^Character_Base, position: ^RVec3) ---
    CharacterBase_GetGroundNormal                         :: proc(character: ^Character_Base, normal: ^Vec3) ---
    CharacterBase_GetGroundVelocity                       :: proc(character: ^Character_Base, velocity: ^Vec3) ---
    CharacterBase_GetGroundMaterial                       :: proc(character: ^Character_Base) -> ^Physics_Material ---
    CharacterBase_GetGroundBodyId                         :: proc(character: ^Character_Base) -> Body_ID ---
    CharacterBase_GetGroundSubShapeId                     :: proc(character: ^Character_Base) -> SubShape_ID ---
    CharacterBase_GetGroundUserData                       :: proc(character: ^Character_Base) -> u64 ---

    /* Character */
    CharacterSettings_Init                                :: proc(settings: ^Character_Settings) ---
    Character_Create                                      :: proc(settings: ^Character_Settings, position: ^RVec3, rotation: ^Quat, user_data: u64, system: ^Physics_System) -> ^Character ---
    Character_AddToPhysicsSystem                          :: proc(character: ^Character, activation_mode: Activation, lock_bodies: bool) ---
    Character_RemoveFromPhysicsSystem                     :: proc(character: ^Character, lock_bodies: bool) ---
    Character_Activate                                    :: proc(character: ^Character, lock_bodies: bool) ---
    Character_PostSimulation                              :: proc(character: ^Character, max_separation_distance: f32, lock_bodies: bool) ---
    Character_GetBodyID                                   :: proc(character: ^Character) -> Body_ID ---
    Character_GetLayer                                    :: proc(character: ^Character) -> Object_Layer ---
    Character_SetLayer                                    :: proc(character: ^Character, value: Object_Layer, lock_bodies: bool) ---
    Character_SetShape                                    :: proc(character: ^Character, shape: ^Shape, max_penetration_depth: f32, lock_bodies: bool) ---
    Character_GetPosition                                 :: proc(character: ^Character, position: ^RVec3, lock_bodies: bool) ---
    Character_SetPosition                                 :: proc(character: ^Character, position: ^RVec3, activation_mode: Activation, lock_bodies: bool) ---
    Character_GetPositionAndRotation                      :: proc(character: ^Character, position: ^RVec3, rotation: ^Quat, lock_bodies: bool) ---
    Character_SetPositionAndRotation                      :: proc(character: ^Character, position: ^RVec3, rotation: ^Quat, activation_mode: Activation, lock_bodies: bool) ---
    Character_GetRotation                                 :: proc(character: ^Character, rotation: ^Quat, lock_bodies: bool) ---
    Character_SetRotation                                 :: proc(character: ^Character, rotation: ^Quat, activation_mode: Activation, lock_bodies: bool) ---
    Character_GetCenterOfMassPosition                     :: proc(character: ^Character, result: ^RVec3, lock_bodies: bool) ---
    Character_GetWorldTransform                           :: proc(character: ^Character, result: ^RMatrix4x4, lock_bodies: bool) ---
    Character_GetLinearVelocity                           :: proc(character: ^Character, result: ^Vec3) ---
    Character_SetLinearVelocity                           :: proc(character: ^Character, value: ^Vec3, lock_bodies: bool) ---
    Character_AddLinearVelocity                           :: proc(character: ^Character, value: ^Vec3, lock_bodies: bool) ---
    Character_AddImpulse                                  :: proc(character: ^Character, value: ^Vec3, lock_bodies: bool) ---
    Character_SetLinearAndAngularVelocity                 :: proc(character: ^Character, linear_velocity: ^Vec3, angular_velocity: ^Vec3, lock_bodies: bool) ---

    /* Character_Virtual */
    CharacterVirtualSettings_Init                         :: proc(settings: ^Character_Virtual_Settings) ---
    CharacterVirtual_Create                               :: proc(settings: ^Character_Virtual_Settings, position: ^RVec3, rotation: ^Quat, user_data: u64, system: ^Physics_System) -> ^Character_Virtual ---
    CharacterVirtual_GetID                                :: proc(character: ^Character_Virtual) -> Character_ID ---
    CharacterVirtual_GetInnerBodyID                       :: proc(character: ^Character_Virtual) -> Body_ID ---
    /* Collision */
    CharacterVirtual_GetEnhancedInternalEdgeRemoval       :: proc(character: ^Character_Virtual) -> bool ---
    CharacterVirtual_SetEnhancedInternalEdgeRemoval       :: proc(character: ^Character_Virtual, value: bool) ---
    CharacterVirtual_SetListener                          :: proc(character: ^Character_Virtual, listener: ^Character_Contact_Listener) ---
    CharacterVirtual_StartTrackingContactChanges          :: proc(character: ^Character_Virtual) ---
    CharacterVirtual_FinishTrackingContactChanges         :: proc(character: ^Character_Virtual) ---
    CharacterVirtual_RefreshContacts                      :: proc(character: ^Character_Virtual, layer: Object_Layer, system: ^Physics_System, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) ---
    CharacterVirtual_GetNumActiveContacts                 :: proc(character: ^Character_Virtual) -> u32 ---
    CharacterVirtual_GetActiveContact                     :: proc(character: ^Character_Virtual, index: u32, result: ^Character_Virtual_Contact)     ---
    CharacterVirtual_HasCollidedWithBody                  :: proc(character: ^Character_Virtual, body: Body_ID) -> bool ---
    CharacterVirtual_HasCollidedWith                      :: proc(character: ^Character_Virtual, other: Character_ID) -> bool ---
    CharacterVirtual_HasCollidedWithCharacter             :: proc(character: ^Character_Virtual, other: ^Character_Virtual) -> bool ---
    CharacterVirtual_GetMaxNumHits                        :: proc(character: ^Character_Virtual) -> u32 ---
    CharacterVirtual_SetMaxNumHits                        :: proc(character: ^Character_Virtual, value: u32) ---
    CharacterVirtual_GetMaxHitsExceeded                   :: proc(character: ^Character_Virtual) -> bool ---
    CharacterVirtual_GetHitReductionCosMaxAngle           :: proc(character: ^Character_Virtual) -> f32 ---
    CharacterVirtual_SetHitReductionCosMaxAngle           :: proc(character: ^Character_Virtual, value: f32) ---
    CharacterVirtual_Update                               :: proc(character: ^Character_Virtual, delta_time: f32, layer: Object_Layer, system: ^Physics_System, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) ---
    CharacterVirtual_ExtendedUpdate                       :: proc(character: ^Character_Virtual, delta_time: f32, settings: ^Extended_Update_Settings, layer: Object_Layer, system: ^Physics_System, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) ---
    CharacterVirtual_UpdateGroundVelocity                 :: proc(character: ^Character_Virtual) ---
    CharacterVirtual_CanWalkStairs                        :: proc(character: ^Character_Virtual, linear_velocity: ^Vec3) -> bool ---
    CharacterVirtual_WalkStairs                           :: proc(character: ^Character_Virtual, delta_time: f32, stepUp: ^Vec3, step_forward: ^Vec3, step_forward_test: ^Vec3, step_down_extra: ^Vec3, layer: Object_Layer, system: ^Physics_System, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    CharacterVirtual_StickToFloor                         :: proc(character: ^Character_Virtual, stepDown: ^Vec3, layer: Object_Layer, system: ^Physics_System, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    CharacterVirtual_SetShape                             :: proc(character: ^Character_Virtual, shape: ^Shape, max_penetration_depth: f32, layer: Object_Layer, system: ^Physics_System, body_filter: ^Body_Filter, shape_filter: ^Shape_Filter) -> bool ---
    CharacterVirtual_SetInnerBodyShape                    :: proc(character: ^Character_Virtual, shape: ^Shape) ---
    CharacterVirtual_GetShapeOffset                       :: proc(character: ^Character_Virtual, result: ^Vec3) ---
    CharacterVirtual_SetShapeOffset                       :: proc(character: ^Character_Virtual, value: ^Vec3) ---
    CharacterVirtual_GetMaxStrength                       :: proc(character: ^Character_Virtual) -> f32 ---
    CharacterVirtual_SetMaxStrength                       :: proc(character: ^Character_Virtual, value: f32) ---
    CharacterVirtual_GetPenetrationRecoverySpeed          :: proc(character: ^Character_Virtual) -> f32 ---
    CharacterVirtual_SetPenetrationRecoverySpeed          :: proc(character: ^Character_Virtual, value: f32) ---
    CharacterVirtual_GetCharacterPadding                  :: proc(character: ^Character_Virtual) -> f32 ---
    CharacterVirtual_GetUserData                          :: proc(character: ^Character_Virtual) -> u64 ---
    CharacterVirtual_SetUserData                          :: proc(character: ^Character_Virtual, user_data: u64) ---
    /* Physics Properties */
    CharacterVirtual_GetPosition                          :: proc(character: ^Character_Virtual, position: ^RVec3) ---
    CharacterVirtual_SetPosition                          :: proc(character: ^Character_Virtual, position: ^RVec3) ---
    CharacterVirtual_GetRotation                          :: proc(character: ^Character_Virtual, rotation: ^Quat) ---
    CharacterVirtual_SetRotation                          :: proc(character: ^Character_Virtual, rotation: ^Quat) ---
    CharacterVirtual_GetLinearVelocity                    :: proc(character: ^Character_Virtual, velocity: ^Vec3) ---
    CharacterVirtual_SetLinearVelocity                    :: proc(character: ^Character_Virtual, velocity: ^Vec3) ---
    CharacterVirtual_CancelVelocityTowardsSteepSlopes     :: proc(character: ^Character_Virtual, desired_velocity: ^Vec3, velocity: ^Vec3) ---
    CharacterVirtual_GetWorldTransform                    :: proc(character: ^Character_Virtual, result: ^RMatrix4x4) ---
    CharacterVirtual_GetCenterOfMassTransform             :: proc(character: ^Character_Virtual, result: ^RMatrix4x4) ---
    CharacterVirtual_GetMass                              :: proc(character: ^Character_Virtual) -> f32 ---
    CharacterVirtual_SetMass                              :: proc(character: ^Character_Virtual, value: f32) ---
    /* Character_Vs_Character_Collision */
    CharacterVirtual_SetCharacterVsCharacterCollision     :: proc(character: ^Character_Virtual, character_vs_character_collision: ^Character_Vs_Character_Collision) ---
    CharacterVsCharacterCollision_Create                  :: proc(user_data: rawptr) -> ^Character_Vs_Character_Collision ---
    CharacterVsCharacterCollision_CreateSimple            :: proc() -> ^Character_Vs_Character_Collision ---
    CharacterVsCharacterCollision_Destroy                 :: proc(listener: ^Character_Vs_Character_Collision) ---
    CharacterVsCharacterCollisionSimple_AddCharacter      :: proc(character_vs_character: ^Character_Vs_Character_Collision, character: ^Character_Virtual) ---
    CharacterVsCharacterCollisionSimple_RemoveCharacter   :: proc(character_vs_character: ^Character_Vs_Character_Collision, character: ^Character_Virtual) ---
    CharacterVsCharacterCollision_SetProcs                :: proc(procs: ^Character_Vs_Character_Collision_Procs) ---

    /* Listeners */
    CharacterContactListener_Create                       :: proc(user_data: rawptr) -> ^Character_Contact_Listener ---
    CharacterContactListener_Destroy                      :: proc(listener: ^Character_Contact_Listener) ---
    CharacterContactListener_SetProcs                     :: proc(procs: ^Character_Contact_Listener_Procs) ---

    //--------------------------------------------------------------------------------------------------
    // Motion_Properties
    //--------------------------------------------------------------------------------------------------
    MotionProperties_GetAllowedDOFs                       :: proc(properties: ^Motion_Properties) -> Allowed_DOFs ---
    MotionProperties_SetLinearDamping                     :: proc(properties: ^Motion_Properties, damping: f32) ---
    MotionProperties_GetLinearDamping                     :: proc(properties: ^Motion_Properties) -> f32 ---
    MotionProperties_SetAngularDamping                    :: proc(properties: ^Motion_Properties, damping: f32) ---
    MotionProperties_GetAngularDamping                    :: proc(properties: ^Motion_Properties) -> f32 ---
    MotionProperties_SetMassProperties                    :: proc(properties: ^Motion_Properties, allowed_DOFs: Allowed_DOFs, mass_properties: ^Mass_Properties) ---
    MotionProperties_GetInverseMassUnchecked              :: proc(properties: ^Motion_Properties) -> f32 ---
    MotionProperties_SetInverseMass                       :: proc(properties: ^Motion_Properties, inverse_mass: f32) ---
    MotionProperties_GetInverseInertiaDiagonal            :: proc(properties: ^Motion_Properties, result: ^Vec3) ---
    MotionProperties_GetInertiaRotation                   :: proc(properties: ^Motion_Properties, result: ^Quat) ---
    MotionProperties_SetInverseInertia                    :: proc(properties: ^Motion_Properties, diagonal: ^Vec3, rot: ^Quat) ---
    MotionProperties_ScaleToMass                          :: proc(properties: ^Motion_Properties, mass: f32) ---

    //--------------------------------------------------------------------------------------------------
    // Mass_Properties
    //--------------------------------------------------------------------------------------------------
        /*
        Only relevant for kinematic or dynamic objects that need a MotionProperties object.
        */
    MassProperties_DecomposePrincipalMomentsOfInertia     :: proc(properties: ^Mass_Properties, rotation: ^Matrix4x4, diagonal: ^Vec3) ---
    MassProperties_ScaleToMass                            :: proc(properties: ^Mass_Properties, mass: f32) ---
    MassProperties_GetEquivalentSolidBoxSize              :: proc(mass: f32, inertia_diagonal: ^Vec3, result: ^Vec3) ---

    //--------------------------------------------------------------------------------------------------
    // Physics_Material
    //--------------------------------------------------------------------------------------------------
    PhysicsMaterial_Create                                :: proc(name: cstring, color: u32) -> ^Physics_Material ---
    PhysicsMaterial_Destroy                               :: proc(material: ^Physics_Material) ---
    PhysicsMaterial_GetDebugName                          :: proc(material: ^Physics_Material) -> cstring ---
    PhysicsMaterial_GetDebugColor                         :: proc(material: ^Physics_Material) -> u32 ---

    //--------------------------------------------------------------------------------------------------
    // Collide
    //--------------------------------------------------------------------------------------------------
    /* RayCast */
    RayCast_GetPointOnRay                                 :: proc(origin: ^Vec3, direction: ^Vec3, fraction: f32, result: ^Vec3) ---
    RRayCast_GetPointOnRay                                :: proc(origin: ^RVec3, direction: ^Vec3, fraction: f32, result: ^RVec3) ---

    /* ShapeCast_Settings */
    ShapeCastSettings_Init                                :: proc(settings: ^ShapeCast_Settings) ---

    CollideShapeSettings_Init                             :: proc(settings: ^Collide_Shape_Settings) ---
    CollideShapeResult_FreeMembers                        :: proc(result: ^Collide_Shape_Result) ---

    CollisionDispatch_CollideShapeVsShape                 :: proc(shape1: ^Shape, shape2: ^Shape, scale1: ^Vec3, scale2: ^Vec3, center_of_mass_transform1: ^Matrix4x4, center_of_mass_transform2: ^Matrix4x4, collideShapeSettings: ^Collide_Shape_Settings, callback: Collide_Shape_Collector_Callback, user_data: rawptr, shape_filter: ^Shape_Filter) -> bool ---
    CollisionDispatch_CastShapeVsShapeLocalSpace          :: proc(direction: ^Vec3, shape1: ^Shape, shape2: ^Shape, scale1_in_shape2_local_space: ^Vec3, scale2: ^Vec3, center_of_mass_transform1_in_shape2_local_space: ^Matrix4x4, center_of_mass_world_transform2: ^Matrix4x4, shape_cast_settings: ^ShapeCast_Settings, callback: CastShape_Collector_Callback, user_data: rawptr, shape_filter: ^Shape_Filter) -> bool ---
    CollisionDispatch_CastShapeVsShapeWorldSpace          :: proc(direction: ^Vec3, shape1: ^Shape, shape2: ^Shape, scale1: ^Vec3, in_scale2: ^Vec3, center_of_mass_world_transform1: ^Matrix4x4, center_of_mass_world_transform2: ^Matrix4x4, shape_cast_settings: ^ShapeCast_Settings, callback: CastShape_Collector_Callback, user_data: rawptr, shape_filter: ^Shape_Filter) -> bool ---

    /* Estimation */
    CollisionEstimationResult_FreeMembers                 :: proc(result: ^Collision_Estimation_Result) ---
    EstimateCollisionResponse                             :: proc(body1: ^Body, body2: ^Body, manifold: ^Contact_Manifold, combined_friction: f32, combined_restitution: f32, min_velocity_for_restitution: f32, num_iterations: u32, result: ^Collision_Estimation_Result) ---

    //--------------------------------------------------------------------------------------------------
    // Constraints
    //--------------------------------------------------------------------------------------------------
    Constraint_Destroy                                    :: proc(constraint: ^Constraint) ---
    Constraint_GetType                                    :: proc(constraint: ^Constraint) -> Constraint_Type ---
    Constraint_GetSubType                                 :: proc(constraint: ^Constraint) -> Constraint_SubType ---
    Constraint_GetConstraintPriority                      :: proc(constraint: ^Constraint) -> u32 ---
    Constraint_SetConstraintPriority                      :: proc(constraint: ^Constraint, priority: u32) ---
    Constraint_GetNumVelocityStepsOverride                :: proc(constraint: ^Constraint) -> u32 ---
    Constraint_SetNumVelocityStepsOverride                :: proc(constraint: ^Constraint, value: u32) ---
    Constraint_GetNumPositionStepsOverride                :: proc(constraint: ^Constraint) -> u32 ---
    Constraint_SetNumPositionStepsOverride                :: proc(constraint: ^Constraint, value: u32) ---
    Constraint_GetEnabled                                 :: proc(constraint: ^Constraint) -> bool ---
    Constraint_SetEnabled                                 :: proc(constraint: ^Constraint, enabled: bool) ---
    Constraint_GetUserData                                :: proc(constraint: ^Constraint) -> u64 ---
    Constraint_SetUserData                                :: proc(constraint: ^Constraint, user_data: u64) ---
    Constraint_NotifyShapeChanged                         :: proc(constraint: ^Constraint, body_id: Body_ID, delta_COM: ^Vec3) ---
    Constraint_ResetWarmStart                             :: proc(constraint: ^Constraint) ---
    Constraint_IsActive                                   :: proc(constraint: ^Constraint) -> bool ---
    Constraint_SetupVelocityConstraint                    :: proc(constraint: ^Constraint, delta_time: f32) ---
    Constraint_WarmStartVelocityConstraint                :: proc(constraint: ^Constraint, warm_start_impulse_ratio: f32) ---
    Constraint_SolveVelocityConstraint                    :: proc(constraint: ^Constraint, delta_time: f32) -> bool ---
    Constraint_SolvePositionConstraint                    :: proc(constraint: ^Constraint, delta_time: f32, baumgarte: f32) -> bool ---

    /* Two_Body_Constraint */
    TwoBodyConstraint_GetBody1                            :: proc(constraint: ^Two_Body_Constraint) -> ^Body ---
    TwoBodyConstraint_GetBody2                            :: proc(constraint: ^Two_Body_Constraint) -> ^Body ---
    TwoBodyConstraint_GetConstraintToBody1Matrix          :: proc(constraint: ^Two_Body_Constraint, result: ^Matrix4x4) ---
    TwoBodyConstraint_GetConstraintToBody2Matrix          :: proc(constraint: ^Two_Body_Constraint, result: ^Matrix4x4) ---

    /* Fixed_Constraint */
    FixedConstraintSettings_Init                          :: proc(settings: ^Fixed_Constraint_Settings) ---
        /* Copies default from Jolt. */
    FixedConstraint_Create                                :: proc(settings: ^Fixed_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Fixed_Constraint ---
    FixedConstraint_GetSettings                           :: proc(constraint: ^Fixed_Constraint, settings: ^Fixed_Constraint_Settings) ---
    FixedConstraint_GetTotalLambdaPosition                :: proc(constraint: ^Fixed_Constraint, result: ^Vec3) ---
    FixedConstraint_GetTotalLambdaRotation                :: proc(constraint: ^Fixed_Constraint, result: ^Vec3) ---

    /* Distance_Constraint */
    DistanceConstraintSettings_Init                       :: proc(settings: ^Distance_Constraint_Settings) ---
        /* Copies default from Jolt. */
    DistanceConstraint_Create                             :: proc(settings: ^Distance_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Distance_Constraint ---
    DistanceConstraint_GetSettings                        :: proc(constraint: ^Distance_Constraint, settings: ^Distance_Constraint_Settings) ---
    DistanceConstraint_SetDistance                        :: proc(constraint: ^Distance_Constraint, min_distance: f32, max_distance: f32) ---
    DistanceConstraint_GetMinDistance                     :: proc(constraint: ^Distance_Constraint) -> f32 ---
    DistanceConstraint_GetMaxDistance                     :: proc(constraint: ^Distance_Constraint) -> f32 ---
    DistanceConstraint_GetLimitsSpringSettings            :: proc(constraint: ^Distance_Constraint, result: ^Spring_Settings) ---
    DistanceConstraint_SetLimitsSpringSettings            :: proc(constraint: ^Distance_Constraint, settings: ^Spring_Settings) ---
    DistanceConstraint_GetTotalLambdaPosition             :: proc(constraint: ^Distance_Constraint) -> f32 ---

    /* Point_Constraint */
    PointConstraintSettings_Init                          :: proc(settings: ^Point_Constraint_Settings) ---
        /* Copies default from Jolt. */
    PointConstraint_Create                                :: proc(settings: ^Point_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Point_Constraint ---
    PointConstraint_GetSettings                           :: proc(constraint: ^Point_Constraint, settings: ^Point_Constraint_Settings) ---
    PointConstraint_SetPoint1                             :: proc(constraint: ^Point_Constraint, space: Constraint_Space, value: ^RVec3) ---
    PointConstraint_SetPoint2                             :: proc(constraint: ^Point_Constraint, space: Constraint_Space, value: ^RVec3) ---
    PointConstraint_GetLocalSpacePoint1                   :: proc(constraint: ^Point_Constraint, result: ^Vec3) ---
    PointConstraint_GetLocalSpacePoint2                   :: proc(constraint: ^Point_Constraint, result: ^Vec3) ---
    PointConstraint_GetTotalLambdaPosition                :: proc(constraint: ^Point_Constraint, result: ^Vec3) ---

    /* Hinge_Constraint */
    HingeConstraintSettings_Init                          :: proc(settings: ^Hinge_Constraint_Settings) ---
        /* Copies default from Jolt. */
    HingeConstraint_Create                                :: proc(settings: ^Hinge_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Hinge_Constraint ---
    HingeConstraint_GetSettings                           :: proc(constraint: ^Hinge_Constraint, settings: ^Hinge_Constraint_Settings) ---
    HingeConstraint_GetLocalSpacePoint1                   :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetLocalSpacePoint2                   :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetLocalSpaceHingeAxis1               :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetLocalSpaceHingeAxis2               :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetLocalSpaceNormalAxis1              :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetLocalSpaceNormalAxis2              :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetCurrentAngle                       :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_SetMaxFrictionTorque                  :: proc(constraint: ^Hinge_Constraint, friction_torque: f32) ---
    HingeConstraint_GetMaxFrictionTorque                  :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_SetMotorSettings                      :: proc(constraint: ^Hinge_Constraint, settings: ^Motor_Settings) ---
    HingeConstraint_GetMotorSettings                      :: proc(constraint: ^Hinge_Constraint, result: ^Motor_Settings) ---
    HingeConstraint_SetMotorState                         :: proc(constraint: ^Hinge_Constraint, state: Motor_State) ---
    HingeConstraint_GetMotorState                         :: proc(constraint: ^Hinge_Constraint) -> Motor_State ---
    HingeConstraint_SetTargetAngularVelocity              :: proc(constraint: ^Hinge_Constraint, angular_velocity: f32) ---
    HingeConstraint_GetTargetAngularVelocity              :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_SetTargetAngle                        :: proc(constraint: ^Hinge_Constraint, angle: f32) ---
    HingeConstraint_GetTargetAngle                        :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_SetLimits                             :: proc(constraint: ^Hinge_Constraint, min: f32, max: f32) ---
    HingeConstraint_GetLimitsMin                          :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_GetLimitsMax                          :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_HasLimits                             :: proc(constraint: ^Hinge_Constraint) -> bool ---
    HingeConstraint_GetLimitsSpringSettings               :: proc(constraint: ^Hinge_Constraint, result: ^Spring_Settings) ---
    HingeConstraint_SetLimitsSpringSettings               :: proc(constraint: ^Hinge_Constraint, settings: ^Spring_Settings) ---
    HingeConstraint_GetTotalLambdaPosition                :: proc(constraint: ^Hinge_Constraint, result: ^Vec3) ---
    HingeConstraint_GetTotalLambdaRotation                :: proc(constraint: ^Hinge_Constraint, rotation: ^f32) ---
    HingeConstraint_GetTotalLambdaRotationLimits          :: proc(constraint: ^Hinge_Constraint) -> f32 ---
    HingeConstraint_GetTotalLambdaMotor                   :: proc(constraint: ^Hinge_Constraint) -> f32 ---

    /* Slider_Constraint */
    SliderConstraintSettings_Init                         :: proc(settings: ^Slider_Constraint_Settings) ---
        /* Copies default from Jolt. */
    SliderConstraintSettings_SetSliderAxis                :: proc(settings: ^Slider_Constraint_Settings, axis: ^Vec3) ---
    SliderConstraint_Create                               :: proc(settings: ^Slider_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Slider_Constraint ---
    SliderConstraint_GetSettings                          :: proc(constraint: ^Slider_Constraint, settings: ^Slider_Constraint_Settings) ---
    SliderConstraint_GetCurrentPosition                   :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_SetMaxFrictionForce                  :: proc(constraint: ^Slider_Constraint, friction_force: f32) ---
    SliderConstraint_GetMaxFrictionForce                  :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_SetMotorSettings                     :: proc(constraint: ^Slider_Constraint, settings: ^Motor_Settings) ---
    SliderConstraint_GetMotorSettings                     :: proc(constraint: ^Slider_Constraint, result: ^Motor_Settings) ---
    SliderConstraint_SetMotorState                        :: proc(constraint: ^Slider_Constraint, state: Motor_State) ---
    SliderConstraint_GetMotorState                        :: proc(constraint: ^Slider_Constraint) -> Motor_State ---
    SliderConstraint_SetTargetVelocity                    :: proc(constraint: ^Slider_Constraint, velocity: f32) ---
    SliderConstraint_GetTargetVelocity                    :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_SetTargetPosition                    :: proc(constraint: ^Slider_Constraint, position: f32) ---
    SliderConstraint_GetTargetPosition                    :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_SetLimits                            :: proc(constraint: ^Slider_Constraint, min: f32, max: f32) ---
    SliderConstraint_GetLimitsMin                         :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_GetLimitsMax                         :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_HasLimits                            :: proc(constraint: ^Slider_Constraint) -> bool ---
    SliderConstraint_GetLimitsSpringSettings              :: proc(constraint: ^Slider_Constraint, result: ^Spring_Settings) ---
    SliderConstraint_SetLimitsSpringSettings              :: proc(constraint: ^Slider_Constraint, settings: ^Spring_Settings) ---
    SliderConstraint_GetTotalLambdaPosition               :: proc(constraint: ^Slider_Constraint, position: ^f32) ---
    SliderConstraint_GetTotalLambdaPositionLimits         :: proc(constraint: ^Slider_Constraint) -> f32 ---
    SliderConstraint_GetTotalLambdaRotation               :: proc(constraint: ^Slider_Constraint, result: ^Vec3) ---
    SliderConstraint_GetTotalLambdaMotor                  :: proc(constraint: ^Slider_Constraint) -> f32 ---

    /* Cone_Constraint */
    ConeConstraintSettings_Init                           :: proc(settings: ^Cone_Constraint_Settings) ---
        /* Copies default from Jolt. */
    ConeConstraint_Create                                 :: proc(settings: ^Cone_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Cone_Constraint ---
    ConeConstraint_GetSettings                            :: proc(constraint: ^Cone_Constraint, settings: ^Cone_Constraint_Settings) ---
    ConeConstraint_SetHalfConeAngle                       :: proc(constraint: ^Cone_Constraint, half_cone_angle: f32) ---
    ConeConstraint_GetCosHalfConeAngle                    :: proc(constraint: ^Cone_Constraint) -> f32 ---
    ConeConstraint_GetTotalLambdaPosition                 :: proc(constraint: ^Cone_Constraint, result: ^Vec3) ---
    ConeConstraint_GetTotalLambdaRotation                 :: proc(constraint: ^Cone_Constraint) -> f32 ---

    /* Swing_Twist_Constraint */
    SwingTwistConstraintSettings_Init                     :: proc(settings: ^Swing_Twist_Constraint_Settings) ---
    SwingTwistConstraint_Create                           :: proc(settings: ^Swing_Twist_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Swing_Twist_Constraint ---
        /* Copies default from Jolt. */
    SwingTwistConstraint_GetSettings                      :: proc(constraint: ^Swing_Twist_Constraint, settings: ^Swing_Twist_Constraint_Settings) ---
    SwingTwistConstraint_GetNormalHalfConeAngle           :: proc(constraint: ^Swing_Twist_Constraint) -> f32 ---
    SwingTwistConstraint_GetTotalLambdaPosition           :: proc(constraint: ^Swing_Twist_Constraint, result: ^Vec3) ---
    SwingTwistConstraint_GetTotalLambdaTwist              :: proc(constraint: ^Swing_Twist_Constraint) -> f32 ---
    SwingTwistConstraint_GetTotalLambdaSwingY             :: proc(constraint: ^Swing_Twist_Constraint) -> f32 ---
    SwingTwistConstraint_GetTotalLambdaSwingZ             :: proc(constraint: ^Swing_Twist_Constraint) -> f32 ---
    SwingTwistConstraint_GetTotalLambdaMotor              :: proc(constraint: ^Swing_Twist_Constraint, result: ^Vec3) ---

    /* SixDOF_Constraint */
    SixDOFConstraintSettings_Init                         :: proc(settings: ^Six_DOF_Constraint_Settings) ---
        /* Copies default from Jolt. */
    SixDOFConstraintSettings_MakeFreeAxis                 :: proc(settings: ^Six_DOF_Constraint_Settings, axis: Six_DOF_Constraint_Axis) ---
    SixDOFConstraintSettings_IsFreeAxis                   :: proc(settings: ^Six_DOF_Constraint_Settings, axis: Six_DOF_Constraint_Axis) -> bool ---
    SixDOFConstraintSettings_MakeFixedAxis                :: proc(settings: ^Six_DOF_Constraint_Settings, axis: Six_DOF_Constraint_Axis) ---
    SixDOFConstraintSettings_IsFixedAxis                  :: proc(settings: ^Six_DOF_Constraint_Settings, axis: Six_DOF_Constraint_Axis) -> bool ---
    SixDOFConstraintSettings_SetLimitedAxis               :: proc(settings: ^Six_DOF_Constraint_Settings, axis: Six_DOF_Constraint_Axis, min: f32, max: f32) ---
    SixDOFConstraint_Create                               :: proc(settings: ^Six_DOF_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^SixDOF_Constraint ---
    SixDOFConstraint_GetSettings                          :: proc(constraint: ^SixDOF_Constraint, settings: ^Six_DOF_Constraint_Settings) ---
    SixDOFConstraint_GetLimitsMin                         :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis) -> f32 ---
    SixDOFConstraint_GetLimitsMax                         :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis) -> f32 ---
    SixDOFConstraint_GetTotalLambdaPosition               :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetTotalLambdaRotation               :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetTotalLambdaMotorTranslation       :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetTotalLambdaMotorRotation          :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetTranslationLimitsMin              :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetTranslationLimitsMax              :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetRotationLimitsMin                 :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_GetRotationLimitsMax                 :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_IsFixedAxis                          :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis) -> bool ---
    SixDOFConstraint_IsFreeAxis                           :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis) -> bool ---
    SixDOFConstraint_GetLimitsSpringSettings              :: proc(constraint: ^SixDOF_Constraint, result: ^Spring_Settings, axis: Six_DOF_Constraint_Axis) ---
    SixDOFConstraint_SetLimitsSpringSettings              :: proc(constraint: ^SixDOF_Constraint, settings: ^Spring_Settings, axis: Six_DOF_Constraint_Axis) ---
    SixDOFConstraint_SetMaxFriction                       :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis, friction: f32) ---
    SixDOFConstraint_GetMaxFriction                       :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis) -> f32 ---
    SixDOFConstraint_GetRotationInConstraintSpace         :: proc(constraint: ^SixDOF_Constraint, result: ^Quat) ---
    SixDOFConstraint_GetMotorSettings                     :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis, settings: ^Motor_Settings) ---
    SixDOFConstraint_SetMotorState                        :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis, state: Motor_State) ---
    SixDOFConstraint_GetMotorState                        :: proc(constraint: ^SixDOF_Constraint, axis: Six_DOF_Constraint_Axis) -> Motor_State ---
    SixDOFConstraint_SetTargetVelocityCS                  :: proc(constraint: ^SixDOF_Constraint, velocity: ^Vec3) ---
    SixDOFConstraint_GetTargetVelocityCS                  :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_SetTargetAngularVelocityCS           :: proc(constraint: ^SixDOF_Constraint, angular_velocity: ^Vec3) ---
    SixDOFConstraint_GetTargetAngularVelocityCS           :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_SetTargetPositionCS                  :: proc(constraint: ^SixDOF_Constraint, position: ^Vec3) ---
    SixDOFConstraint_GetTargetPositionCS                  :: proc(constraint: ^SixDOF_Constraint, result: ^Vec3) ---
    SixDOFConstraint_SetTargetOrientationCS               :: proc(constraint: ^SixDOF_Constraint, orientation: ^Quat) ---
    SixDOFConstraint_GetTargetOrientationCS               :: proc(constraint: ^SixDOF_Constraint, result: ^Quat) ---
    SixDOFConstraint_SetTargetOrientationBS               :: proc(constraint: ^SixDOF_Constraint, orientation: ^Quat) ---

    /* Gear_Constraint */
    GearConstraintSettings_Init                           :: proc(settings: ^Gear_Constraint_Settings) ---
        /* Copies default from Jolt. */
    GearConstraint_Create                                 :: proc(settings: ^Gear_Constraint_Settings, body1: ^Body, body2: ^Body) -> ^Gear_Constraint ---
    GearConstraint_GetSettings                            :: proc(constraint: ^Gear_Constraint, settings: ^Gear_Constraint_Settings) ---
    GearConstraint_SetConstraints                         :: proc(constraint: ^Gear_Constraint, gear1: ^Constraint, gear2: ^Constraint) ---
    GearConstraint_GetTotalLambda                         :: proc(constraint: ^Gear_Constraint) -> f32 ---

    //--------------------------------------------------------------------------------------------------
    // Ragdoll & Skeleton
    //--------------------------------------------------------------------------------------------------
    /* Ragdoll */
    RagdollSettings_Create                                :: proc() -> ^Ragdoll_Settings ---
    RagdollSettings_Destroy                               :: proc(settings: ^Ragdoll_Settings) ---
    RagdollSettings_SetSkeleton                           :: proc(character: ^Ragdoll_Settings, skeleton: ^Skeleton) ---
    RagdollSettings_GetSkeleton                           :: proc(character: ^Ragdoll_Settings) -> ^Skeleton ---
    RagdollSettings_Stabilize                             :: proc(settings: ^Ragdoll_Settings) -> bool ---
    RagdollSettings_DisableParentChildCollisions          :: proc(settings: ^Ragdoll_Settings, joint_matrices: ^Matrix4x4, min_separation_distance: f32) ---
        /*
        After the ragdoll has been fully configured, call this function to automatically create and add a GroupFilterTable collision filter to all bodies
        and configure them so that parent and children don't collide.

        This will:
        - Create a GroupFilterTable and assign it to all of the bodies in a ragdoll.
        - Each body in your ragdoll will get a SubGroupID that is equal to the joint index in the Skeleton that it is attached to.
        - Loop over all joints in the Skeleton and call GroupFilterTable::DisableCollision(joint index, parent joint index).
        - When a pose is provided through inJointMatrices the function will detect collisions between joints
        (they must be separated by more than inMinSeparationDistance to be treated as not colliding) and automatically disable collisions.

        When you create an instance using Ragdoll::CreateRagdoll pass in a unique GroupID for each ragdoll (e.g. a simple counter), note that this number
        should be unique throughout the PhysicsSystem, so if you have different types of ragdolls they should not share the same GroupID.
        */
    RagdollSettings_CalculateBodyIndexToConstraintIndex   :: proc(settings: ^Ragdoll_Settings) ---
        /* Calculate the map needed for GetBodyIndexToConstraintIndex() */
    RagdollSettings_CalculateConstraintIndexToBodyIdxPair :: proc(settings: ^Ragdoll_Settings) ---
        /*  Calculate the map needed for GetConstraintIndexToBodyIdxPair() */
    RagdollSettings_GetConstraintIndexForBodyIndex        :: proc(settings: ^Ragdoll_Settings, body_index: c.int) -> c.int ---
        /* Map a single body index to a constraint index */
    RagdollSettings_CreateRagdoll                         :: proc(settings: ^Ragdoll_Settings, system: ^Physics_System, collision_group: Collision_Group_ID, user_data: u64) -> ^Ragdoll ---
    Ragdoll_Destroy                                       :: proc(ragdoll: ^Ragdoll) ---
    Ragdoll_AddToPhysicsSystem                            :: proc(ragdoll: ^Ragdoll, activation_mode: Activation, lock_bodies: bool) ---
    Ragdoll_RemoveFromPhysicsSystem                       :: proc(ragdoll: ^Ragdoll, lock_bodies: bool) ---
    Ragdoll_Activate                                      :: proc(ragdoll: ^Ragdoll, lock_bodies: bool) ---
        /* Wake up all bodies in the ragdoll */
    Ragdoll_IsActive                                      :: proc(ragdoll: ^Ragdoll, lock_bodies: bool) -> bool ---
        /*
        Check if one or more of the bodies in the ragdoll are active.
        Note that this involves locking the bodies (if inLockBodies is true) and looping over them. An alternative and possibly faster
        way could be to install a BodyActivationListener and count the number of active bodies of a ragdoll as they're activated / deactivated
        (basically check if the body that activates / deactivates is in GetBodyIDs() and increment / decrement a counter).
        */
    Ragdoll_ResetWarmStart                                :: proc(ragdoll: ^Ragdoll) ---
        /*  Calls ResetWarmStart on all constraints. It can be used after calling SetPose to reset previous frames impulses. See: Constraint::ResetWarmStart. */

    /* Skeleton */
    Skeleton_Create                                       :: proc() -> ^Skeleton ---
    Skeleton_Destroy                                      :: proc(skeleton: ^Skeleton) ---
    Skeleton_AddJoint                                     :: proc(skeleton: ^Skeleton, name: cstring) -> u32 ---
        /* Usually used to create the first join of a chain. */
    Skeleton_AddJoint2                                    :: proc(skeleton: ^Skeleton, name: cstring, parent_index: c.int) -> u32 ---
    Skeleton_AddJoint3                                    :: proc(skeleton: ^Skeleton, name: cstring, parent_name: cstring) -> u32 ---
    Skeleton_GetJointCount                                :: proc(skeleton: ^Skeleton) -> c.int ---
    Skeleton_GetJoint                                     :: proc(skeleton: ^Skeleton, index: c.int, joint: ^Skeleton_Joint) ---
    Skeleton_GetJointIndex                                :: proc(skeleton: ^Skeleton, name: cstring) -> c.int ---
    Skeleton_CalculateParentJointIndices                  :: proc(skeleton: ^Skeleton) ---
        /* Fill in parent joint indices based on name */
    Skeleton_AreJointsCorrectlyOrdered                    :: proc(skeleton: ^Skeleton) -> bool ---
        /*
        Many of the algorithms that use the Skeleton class require that parent joints are in the mJoints array before their children.
        This function returns true if this is the case, false if not.
        */

    //--------------------------------------------------------------------------------------------------
    // Vehicle
    //--------------------------------------------------------------------------------------------------
    VehicleEngineSettings_Init                            :: proc(settings: ^Vehicle_Engine_Settings) ---
        /* Copies default from Jolt. */

    /* VehicleTransmission */
    VehicleTransmissionSettings_Create                    :: proc(mode: Transmission_Mode, switch_time: f32, clutch_release_time: f32, switch_latency: f32, shift_up_rpm: f32, shift_down_rpm: f32, clutch_strength: f32) -> ^Vehicle_Transmission_Settings ---
    VehicleTransmissionSettings_Destroy                   :: proc(settings: ^Vehicle_Transmission_Settings) ---

    /* Vehicle_Constraint */
    VehicleConstraintSettings_Init                        :: proc(settings: ^Vehicle_Constraint_Settings) ---
    VehicleConstraint_Create                              :: proc(body: ^Body, settings: ^Vehicle_Constraint_Settings) -> ^Vehicle_Constraint ---
    VehicleConstraint_Destroy                             :: proc(constraint: ^Vehicle_Constraint) ---
    VehicleConstraint_AsPhysics_Step_Listener                 :: proc(constraint: ^Vehicle_Constraint) -> ^Physics_Step_Listener ---
    VehicleConstraint_GetWheeledVehicleController         :: proc(constraint: ^Vehicle_Constraint) -> ^Wheeled_Vehicle_Controller ---
    VehicleConstraint_SetVehicleCollisionTester           :: proc(constraint: ^Vehicle_Constraint, tester: ^Vehicle_Collision_Tester) ---

    /* VehicleColliionTester */
    VehicleCollisionTesterRay_Create                      :: proc(layer: Object_Layer, up: ^Vec3, max_slope_angle: f32) -> ^Vehicle_Collision_Tester_Ray ---
    VehicleCollisionTesterRay_Destroy                     :: proc(tester: ^Vehicle_Collision_Tester_Ray) ---
    VehicleCollisionTesterCastSphere_Create               :: proc(layer: Object_Layer, radius: f32, up: ^Vec3, max_slope_angle: f32) -> ^Vehicle_Collision_Tester_Cast_Sphere ---
    VehicleCollisionTesterCastSphere_Destroy              :: proc(tester: ^Vehicle_Collision_Tester_Cast_Sphere) ---
    VehicleCollisionTesterCastCylinder_Create             :: proc(layer: Object_Layer, convex_radius_fraction: f32) -> ^Vehicle_Collision_Tester_Cast_Cylinder ---
    VehicleCollisionTesterCastCylinder_Destroy            :: proc(tester: ^Vehicle_Collision_Tester_Cast_Cylinder) ---

    /* Wheel */
    WheelSettings_Init                                    :: proc(settings: ^Wheel_Settings) ---
    WheelSettingsWV_Init                                  :: proc(settings: ^Wheel_Settings_WV) ---
    Wheel_Create                                          :: proc(settings: ^Wheel_Settings) -> ^Wheel ---
    Wheel_Destroy                                         :: proc(wheel: ^Wheel) ---
    Wheel_HasContact                                      :: proc(wheel: ^Wheel) -> bool ---
    Wheel_HasHitHardPoint                                 :: proc(wheel: ^Wheel) -> bool ---
    WheelWV_Create                                        :: proc(settings: ^Wheel_Settings_WV) -> ^Wheel_WV ---

    /* Wheeled_Vehicle_Controller */
    WheeledVehicleControllerSettings_Create               :: proc(engine: ^Vehicle_Engine_Settings, transmission: ^Vehicle_Transmission_Settings, differential_limited_slip_ratio: f32) -> ^Wheeled_Vehicle_Controller_Settings ---
    WheeledVehicleControllerSettings_Destroy              :: proc(settings: ^Wheeled_Vehicle_Controller_Settings) ---
    WheeledVehicleController_GetConstraint                :: proc(vehicle: ^Wheeled_Vehicle_Controller) -> ^Constraint ---
    WheeledVehicleController_SetForwardInput              :: proc(vehicle: ^Wheeled_Vehicle_Controller, forward: f32) ---
    WheeledVehicleController_GetForwardInput              :: proc(vehicle: ^Wheeled_Vehicle_Controller) -> f32 ---
    WheeledVehicleController_SetRightInput                :: proc(vehicle: ^Wheeled_Vehicle_Controller, right_ratio: f32) ---
    WheeledVehicleController_GetRightInput                :: proc(vehicle: ^Wheeled_Vehicle_Controller) -> f32 ---
    WheeledVehicleController_SetBrakeInput                :: proc(vehicle: ^Wheeled_Vehicle_Controller, brake_input: f32) ---
    WheeledVehicleController_GetBrakeInput                :: proc(vehicle: ^Wheeled_Vehicle_Controller) -> f32 ---
    WheeledVehicleController_SetHandBrakeInput            :: proc(vehicle: ^Wheeled_Vehicle_Controller, hand_brake_input: f32) ---
    WheeledVehicleController_GetHandBrakeInput            :: proc(vehicle: ^Wheeled_Vehicle_Controller) -> f32 ---

    //--------------------------------------------------------------------------------------------------
    // Shape
    //--------------------------------------------------------------------------------------------------
    /* Shape Settings */
        /*
        This contains serializable (non-runtime optimized) information about the Shape.
        */
    ShapeSettings_SetUserData                             :: proc(settings: ^Shape_Settings, user_data: u64) ---
    ShapeSettings_GetUserData                             :: proc(settings: ^Shape_Settings) -> u64 ---
    ShapeSettings_Destroy                                 :: proc(settings: ^Shape_Settings) ---
    /* Shape */
    Shape_Destroy                                         :: proc(shape: ^Shape) ---
    Shape_GetType                                         :: proc(shape: ^Shape) -> Shape_Type ---
    Shape_GetSubType                                      :: proc(shape: ^Shape) -> Shape_SubType ---
    Shape_GetCenterOfMass                                 :: proc(shape: ^Shape, result: ^Vec3) ---
    Shape_GetInnerRadius                                  :: proc(shape: ^Shape) -> f32 ---
    Shape_GetMassProperties                               :: proc(shape: ^Shape, result: ^Mass_Properties) ---
    Shape_GetMaterial                                     :: proc(shape: ^Shape, sub_shape_id: SubShape_ID) -> ^Physics_Material ---
    Shape_GetSurfaceNormal                                :: proc(shape: ^Shape, sub_shape_id: SubShape_ID, local_position: ^Vec3, normal: ^Vec3) ---
    Shape_GetSupportingFace                               :: proc(shape: ^Shape, sub_shape_id: SubShape_ID, direction: ^Vec3, scale: ^Vec3, center_of_mass_transform: ^Matrix4x4, vertices: ^Supporting_Face) ---
    Shape_GetVolume                                       :: proc(shape: ^Shape) -> f32 ---
    Shape_GetLocalBounds                                  :: proc(shape: ^Shape, result: ^AABox) ---
    Shape_GetSubShapeIDBitsRecursive                      :: proc(shape: ^Shape) -> u32 ---
    Shape_GetWorldSpaceBounds                             :: proc(shape: ^Shape, center_of_mass_transform: ^RMatrix4x4, scale: ^Vec3, result: ^AABox) ---
    Shape_GetLeafShape                                    :: proc(shape: ^Shape, sub_shape_id: SubShape_ID, remainder: ^SubShape_ID) -> ^Shape ---
    Shape_MakeScaleValid                                  :: proc(shape: ^Shape, scale: ^Vec3, result: ^Vec3) ---
    Shape_ScaleShape                                      :: proc(shape: ^Shape, scale: ^Vec3) -> ^Shape ---
    Shape_IsValidScale                                    :: proc(shape: ^Shape, scale: ^Vec3) -> bool ---
    Shape_GetUserData                                     :: proc(shape: ^Shape) -> u64 ---
    Shape_SetUserData                                     :: proc(shape: ^Shape, user_data: u64) ---
    Shape_MustBeStatic                                    :: proc(shape: ^Shape) -> bool ---
    Shape_CastRay                                         :: proc(shape: ^Shape, origin: ^Vec3, direction: ^Vec3, hit: ^RayCast_Result) -> bool ---
    Shape_CastRay2                                        :: proc(shape: ^Shape, origin: ^Vec3, direction: ^Vec3, ray_cast_settings: ^RayCast_Settings, collector_type: Collision_Collector_Type, callback: CastRay_Result_Callback, user_data: rawptr, shape_filter: ^Shape_Filter) -> bool ---
    Shape_CollidePoint                                    :: proc(shape: ^Shape, point: ^Vec3, shape_filter: ^Shape_Filter) -> bool ---
    Shape_CollidePoint2                                   :: proc(shape: ^Shape, point: ^Vec3, collector_type: Collision_Collector_Type, callback: Collide_Point_Result_Callback, user_data: rawptr, shape_filter: ^Shape_Filter) -> bool ---
    /* Convex_Shape */
    ConvexShapeSettings_GetDensity                        :: proc(shape: ^Convex_Shape_Settings) -> f32 ---
    ConvexShapeSettings_SetDensity                        :: proc(shape: ^Convex_Shape_Settings, value: f32) ---
    ConvexShape_GetDensity                                :: proc(shape: ^Convex_Shape) -> f32 ---
    ConvexShape_SetDensity                                :: proc(shape: ^Convex_Shape, density: f32) ---
    /* Box_Shape */
    BoxShapeSettings_Create                               :: proc(half_extent: ^Vec3, convex_radius: f32) -> ^Box_Shape_Settings ---
    BoxShapeSettings_CreateShape                          :: proc(settings: ^Box_Shape_Settings) -> ^Box_Shape ---
    BoxShape_Create                                       :: proc(half_extent: ^Vec3, convex_radius: f32) -> ^Box_Shape ---
    BoxShape_GetHalfExtent                                :: proc(shape: ^Box_Shape, half_extent: ^Vec3) ---
    BoxShape_GetConvexRadius                              :: proc(shape: ^Box_Shape) -> f32 ---
    /* Sphere_Shape */
    SphereShapeSettings_Create                            :: proc(radius: f32) -> ^Sphere_Shape_Settings ---
    SphereShapeSettings_CreateShape                       :: proc(settings: ^Sphere_Shape_Settings) -> ^Sphere_Shape ---
    SphereShapeSettings_GetRadius                         :: proc(settings: ^Sphere_Shape_Settings) -> f32 ---
    SphereShapeSettings_SetRadius                         :: proc(settings: ^Sphere_Shape_Settings, radius: f32) ---
    SphereShape_Create                                    :: proc(radius: f32) -> ^Sphere_Shape ---
    SphereShape_GetRadius                                 :: proc(shape: ^Sphere_Shape) -> f32 ---
    /* Plane_Shape */
    PlaneShapeSettings_Create                             :: proc(plane: ^Plane, material: ^Physics_Material, half_extent: f32) -> ^Plane_Shape_Settings ---
    PlaneShapeSettings_CreateShape                        :: proc(settings: ^Plane_Shape_Settings) -> ^Plane_Shape ---
    PlaneShape_Create                                     :: proc(plane: ^Plane, material: ^Physics_Material, half_extent: f32) -> ^Plane_Shape ---
    PlaneShape_GetPlane                                   :: proc(shape: ^Plane_Shape, result: ^Plane) ---
    PlaneShape_GetHalfExtent                              :: proc(shape: ^Plane_Shape) -> f32 ---
    /* Triangle_Shape */
    TriangleShapeSettings_Create                          :: proc(v1: ^Vec3, v2: ^Vec3, v3: ^Vec3, convex_radius: f32) -> ^Triangle_Shape_Settings ---
    TriangleShapeSettings_CreateShape                     :: proc(settings: ^Triangle_Shape_Settings) -> ^Triangle_Shape ---
    TriangleShape_Create                                  :: proc(v1: ^Vec3, v2: ^Vec3, v3: ^Vec3, convex_radius: f32) -> ^Triangle_Shape ---
    TriangleShape_GetConvexRadius                         :: proc(shape: ^Triangle_Shape) -> f32 ---
    TriangleShape_GetVertex1                              :: proc(shape: ^Triangle_Shape, result: ^Vec3) ---
    TriangleShape_GetVertex2                              :: proc(shape: ^Triangle_Shape, result: ^Vec3) ---
    TriangleShape_GetVertex3                              :: proc(shape: ^Triangle_Shape, result: ^Vec3) ---
    /* Capsule_Shape */
    CapsuleShapeSettings_Create                           :: proc(half_height_of_cylinder: f32, radius: f32) -> ^Capsule_Shape_Settings ---
    CapsuleShapeSettings_CreateShape                      :: proc(settings: ^Capsule_Shape_Settings) -> ^Capsule_Shape ---
    CapsuleShape_Create                                   :: proc(half_height_of_cylinder: f32, radius: f32) -> ^Capsule_Shape ---
    CapsuleShape_GetRadius                                :: proc(shape: ^Capsule_Shape) -> f32 ---
    CapsuleShape_GetHalfHeightOfCylinder                  :: proc(shape: ^Capsule_Shape) -> f32 ---
    /* Cylinder_Shape */
    CylinderShapeSettings_Create                          :: proc(half_height: f32, radius: f32, convex_radius: f32) -> ^Cylinder_Shape_Settings ---
    CylinderShapeSettings_CreateShape                     :: proc(settings: ^Cylinder_Shape_Settings) -> ^Cylinder_Shape ---
    CylinderShape_Create                                  :: proc(half_height: f32, radius: f32) -> ^Cylinder_Shape ---
    CylinderShape_GetRadius                               :: proc(shape: ^Cylinder_Shape) -> f32 ---
    CylinderShape_GetHalfHeight                           :: proc(shape: ^Cylinder_Shape) -> f32 ---
    /* Tapered_Cylinder_Shape */
    TaperedCylinderShapeSettings_Create                   :: proc(half_height_of_tapered_cylinder: f32, top_radius: f32, bottom_radius: f32, convex_radius: f32, material: ^Physics_Material) -> ^Tapered_Cylinder_Shape_Settings ---
    TaperedCylinderShapeSettings_CreateShape              :: proc(settings: ^Tapered_Cylinder_Shape_Settings) -> ^Tapered_Cylinder_Shape ---
    TaperedCylinderShape_GetTopRadius                     :: proc(shape: ^Tapered_Cylinder_Shape) -> f32 ---
    TaperedCylinderShape_GetBottomRadius                  :: proc(shape: ^Tapered_Cylinder_Shape) -> f32 ---
    TaperedCylinderShape_GetConvexRadius                  :: proc(shape: ^Tapered_Cylinder_Shape) -> f32 ---
    TaperedCylinderShape_GetHalfHeight                    :: proc(shape: ^Tapered_Cylinder_Shape) -> f32 ---
    /* Convex_Hull_Shape */
    ConvexHullShapeSettings_Create                        :: proc(points: ^Vec3, points_count: u32, max_convex_radius: f32) -> ^Convex_Hull_Shape_Settings ---
    ConvexHullShapeSettings_CreateShape                   :: proc(settings: ^Convex_Hull_Shape_Settings) -> ^Convex_Hull_Shape ---
    ConvexHullShape_GetNumPoints                          :: proc(shape: ^Convex_Hull_Shape) -> u32 ---
    ConvexHullShape_GetPoint                              :: proc(shape: ^Convex_Hull_Shape, index: u32, result: ^Vec3) ---
    ConvexHullShape_GetNumFaces                           :: proc(shape: ^Convex_Hull_Shape) -> u32 ---
    ConvexHullShape_GetNumVerticesInFace                  :: proc(shape: ^Convex_Hull_Shape, face_index: u32) -> u32 ---
    ConvexHullShape_GetFaceVertices                       :: proc(shape: ^Convex_Hull_Shape, face_index: u32, max_vertices: u32, vertices: ^u32) -> u32 ---
    /* Mesh_Shape */
    MeshShapeSettings_Create                              :: proc(triangles: ^Triangle, triangle_count: u32) -> ^Mesh_Shape_Settings ---
    MeshShapeSettings_Create2                             :: proc(vertices: ^Vec3, vertices_count: u32, triangles: ^Indexed_Triangle, triangle_count: u32) -> ^Mesh_Shape_Settings ---
    MeshShapeSettings_GetMaxTrianglesPerLeaf              :: proc(settings: ^Mesh_Shape_Settings) -> u32 ---
    MeshShapeSettings_SetMaxTrianglesPerLeaf              :: proc(settings: ^Mesh_Shape_Settings, value: u32) ---
    MeshShapeSettings_GetActiveEdgeCosThresholdAngle      :: proc(settings: ^Mesh_Shape_Settings) -> f32 ---
    MeshShapeSettings_SetActiveEdgeCosThresholdAngle      :: proc(settings: ^Mesh_Shape_Settings, value: f32) ---
    MeshShapeSettings_GetPerTriangleUserData              :: proc(settings: ^Mesh_Shape_Settings) -> bool ---
    MeshShapeSettings_SetPerTriangleUserData              :: proc(settings: ^Mesh_Shape_Settings, user_data: bool) ---
    MeshShapeSettings_GetBuildQuality                     :: proc(settings: ^Mesh_Shape_Settings) -> Mesh_Shape_Build_Quality ---
    MeshShapeSettings_SetBuildQuality                     :: proc(settings: ^Mesh_Shape_Settings, value: Mesh_Shape_Build_Quality) ---
    MeshShapeSettings_Sanitize                            :: proc(settings: ^Mesh_Shape_Settings) ---
    MeshShapeSettings_CreateShape                         :: proc(settings: ^Mesh_Shape_Settings) -> ^Mesh_Shape ---
    MeshShape_GetTriangleUserData                         :: proc(shape: ^Mesh_Shape, id: SubShape_ID) -> u32 ---
    /* HeightField_Shape */
    HeightFieldShapeSettings_Create                       :: proc(samples: ^f32, offset: ^Vec3, scale: ^Vec3, sample_count: u32) -> ^HeightField_Shape_Settings ---
    HeightFieldShapeSettings_CreateShape                  :: proc(settings: ^HeightField_Shape_Settings) -> ^HeightField_Shape ---
    HeightFieldShapeSettings_DetermineMinAndMaxSample     :: proc(settings: ^HeightField_Shape_Settings, min_value: ^f32, max_value: ^f32, quantization_scale: ^f32) ---
    HeightFieldShapeSettings_CalculateBitsPerSampleForError :: proc(settings: ^HeightField_Shape_Settings, max_error: f32) -> u32 ---
    HeightFieldShape_GetSampleCount                       :: proc(shape: ^HeightField_Shape) -> u32 ---
    HeightFieldShape_GetBlockSize                         :: proc(shape: ^HeightField_Shape) -> u32 ---
    HeightFieldShape_GetMaterial                          :: proc(shape: ^HeightField_Shape, x: u32, y: u32) -> ^Physics_Material ---
    HeightFieldShape_GetPosition                          :: proc(shape: ^HeightField_Shape, x: u32, y: u32, result: ^Vec3) ---
    HeightFieldShape_IsNoCollision                        :: proc(shape: ^HeightField_Shape, x: u32, y: u32) -> bool ---
    HeightFieldShape_ProjectOntoSurface                   :: proc(shape: ^HeightField_Shape, local_position: ^Vec3, surface_position: ^Vec3, sub_shape_id: ^SubShape_ID) -> bool ---
    HeightFieldShape_GetMinHeightValue                    :: proc(shape: ^HeightField_Shape) -> f32 ---
    HeightFieldShape_GetMaxHeightValue                    :: proc(shape: ^HeightField_Shape) -> f32 ---
    /* Tapered_Capsule_Shape */
    TaperedCapsuleShapeSettings_Create                    :: proc(half_height_of_tapered_cylinder: f32, top_radius: f32, bottom_radius: f32) -> ^Tapered_Capsule_Shape_Settings ---
    TaperedCapsuleShapeSettings_CreateShape               :: proc(settings: ^Tapered_Capsule_Shape_Settings) -> ^Tapered_Capsule_Shape ---
    TaperedCapsuleShape_GetTopRadius                      :: proc(shape: ^Tapered_Capsule_Shape) -> f32 ---
    TaperedCapsuleShape_GetBottomRadius                   :: proc(shape: ^Tapered_Capsule_Shape) -> f32 ---
    TaperedCapsuleShape_GetHalfHeight                     :: proc(shape: ^Tapered_Capsule_Shape) -> f32 ---

    /* Compound_Shape */
    CompoundShapeSettings_AddShape                        :: proc(settings: ^Compound_Shape_Settings, position: ^Vec3, rotation: ^Quat, shape_settings: ^Shape_Settings, user_data: u32) ---
    CompoundShapeSettings_AddShape2                       :: proc(settings: ^Compound_Shape_Settings, position: ^Vec3, rotation: ^Quat, shape: ^Shape, user_data: u32) ---
    CompoundShape_GetNumSubShapes                         :: proc(shape: ^Compound_Shape) -> u32 ---
    CompoundShape_GetSubShape                             :: proc(shape: ^Compound_Shape, index: u32, subShape: ^^Shape, positionCOM: ^Vec3, rotation: ^Quat, user_data: ^u32) ---
    CompoundShape_GetSubShapeIndexFromID                  :: proc(shape: ^Compound_Shape, id: SubShape_ID, remainder: ^SubShape_ID) -> u32 ---
    /* Static_Compound_Shape */
    StaticCompoundShapeSettings_Create                    :: proc() -> ^Static_Compound_Shape_Settings ---
    StaticCompoundShape_Create                            :: proc(settings: ^Static_Compound_Shape_Settings) -> ^Static_Compound_Shape ---
    /* Mutable_Compound_Shape */
    MutableCompoundShapeSettings_Create                   :: proc() -> ^Mutable_Compound_Shape_Settings ---
    MutableCompoundShape_Create                           :: proc(settings: ^Mutable_Compound_Shape_Settings) -> ^Mutable_Compound_Shape ---
    MutableCompoundShape_AddShape                         :: proc(shape: ^Mutable_Compound_Shape, position: ^Vec3, rotation: ^Quat, child: ^Shape, user_data: u32, index: u32) -> u32 ---
    MutableCompoundShape_RemoveShape                      :: proc(shape: ^Mutable_Compound_Shape, index: u32) ---
    MutableCompoundShape_ModifyShape                      :: proc(shape: ^Mutable_Compound_Shape, index: u32, position: ^Vec3, rotation: ^Quat) ---
    MutableCompoundShape_ModifyShape2                     :: proc(shape: ^Mutable_Compound_Shape, index: u32, position: ^Vec3, rotation: ^Quat, newShape: ^Shape) ---
    MutableCompoundShape_AdjustCenterOfMass               :: proc(shape: ^Mutable_Compound_Shape) ---

    /* Decorated_Shape */
    DecoratedShape_GetInnerShape                          :: proc(shape: ^Decorated_Shape) -> ^Shape ---
    /* Rotated_Translated_Shape */
    RotatedTranslatedShapeSettings_Create                 :: proc(position: ^Vec3, rotation: ^Quat, shape_settings: ^Shape_Settings) -> ^Rotated_Translated_Shape_Settings ---
    RotatedTranslatedShapeSettings_Create2                :: proc(position: ^Vec3, rotation: ^Quat, shape: ^Shape) -> ^Rotated_Translated_Shape_Settings ---
    RotatedTranslatedShapeSettings_CreateShape            :: proc(settings: ^Rotated_Translated_Shape_Settings) -> ^Rotated_Translated_Shape ---
    RotatedTranslatedShape_Create                         :: proc(position: ^Vec3, rotation: ^Quat, shape: ^Shape) -> ^Rotated_Translated_Shape ---
    RotatedTranslatedShape_GetPosition                    :: proc(shape: ^Rotated_Translated_Shape, position: ^Vec3) ---
    RotatedTranslatedShape_GetRotation                    :: proc(shape: ^Rotated_Translated_Shape, rotation: ^Quat) ---
    /* Scaled_Shape */
    ScaledShapeSettings_Create                            :: proc(shape_settings: ^Shape_Settings, scale: ^Vec3) -> ^Scaled_Shape_Settings ---
    ScaledShapeSettings_Create2                           :: proc(shape: ^Shape, scale: ^Vec3) -> ^Scaled_Shape_Settings ---
    ScaledShapeSettings_CreateShape                       :: proc(settings: ^Scaled_Shape_Settings) -> ^Scaled_Shape ---
    ScaledShape_Create                                    :: proc(shape: ^Shape, scale: ^Vec3) -> ^Scaled_Shape ---
    ScaledShape_GetScale                                  :: proc(shape: ^Scaled_Shape, result: ^Vec3) ---
    /* Offset_Center_Of_Mass_Shape */
    OffsetCenterOfMassShapeSettings_Create                :: proc(offset: ^Vec3, shape_settings: ^Shape_Settings) -> ^Offset_Center_Of_Mass_Shape_Settings ---
    OffsetCenterOfMassShapeSettings_Create2               :: proc(offset: ^Vec3, shape: ^Shape) -> ^Offset_Center_Of_Mass_Shape_Settings ---
    OffsetCenterOfMassShapeSettings_CreateShape           :: proc(settings: ^Offset_Center_Of_Mass_Shape_Settings) -> ^Offset_Center_Of_Mass_Shape ---
    OffsetCenterOfMassShape_Create                        :: proc(offset: ^Vec3, shape: ^Shape) -> ^Offset_Center_Of_Mass_Shape ---
    OffsetCenterOfMassShape_GetOffset                     :: proc(shape: ^Offset_Center_Of_Mass_Shape, result: ^Vec3) ---
    /* Empty_Shape */
    EmptyShapeSettings_Create                             :: proc(center_of_mass: ^Vec3) -> ^Empty_Shape_Settings ---
    EmptyShapeSettings_CreateShape                        :: proc(settings: ^Empty_Shape_Settings) -> ^Empty_Shape ---

    //--------------------------------------------------------------------------------------------------
    // Math
    //--------------------------------------------------------------------------------------------------
    Quaternion_FromTo                                     :: proc(from: ^Vec3, to: ^Vec3, quat: ^Quat) ---
    Quat_GetAxisAngle                                     :: proc(quat: ^Quat, axis: ^Vec3, angle: ^f32) ---
    Quat_GetEulerAngles                                   :: proc(quat: ^Quat, result: ^Vec3) ---
    Quat_RotateAxisX                                      :: proc(quat: ^Quat, result: ^Vec3) ---
    Quat_RotateAxisY                                      :: proc(quat: ^Quat, result: ^Vec3) ---
    Quat_RotateAxisZ                                      :: proc(quat: ^Quat, result: ^Vec3) ---
    Quat_Inversed                                         :: proc(quat: ^Quat, result: ^Quat) ---
    Quat_GetPerpendicular                                 :: proc(quat: ^Quat, result: ^Quat) ---
    Quat_GetRotationAngle                                 :: proc(quat: ^Quat, axis: ^Vec3) -> f32 ---
    Quat_FromEulerAngles                                  :: proc(angles: ^Vec3, result: ^Quat) ---
    Quat_Add                                              :: proc(q1: ^Quat, q2: ^Quat, result: ^Quat) ---
    Quat_Subtract                                         :: proc(q1: ^Quat, q2: ^Quat, result: ^Quat) ---
    Quat_Multiply                                         :: proc(q1: ^Quat, q2: ^Quat, result: ^Quat) ---
    Quat_MultiplyScalar                                   :: proc(q: ^Quat, scalar: f32, result: ^Quat) ---
    Quat_Divide                                           :: proc(q1: ^Quat, q2: ^Quat, result: ^Quat) ---
    Quat_Dot                                              :: proc(q1: ^Quat, q2: ^Quat, result: ^f32) ---
    Quat_Conjugated                                       :: proc(quat: ^Quat, result: ^Quat) ---
    Quat_GetTwist                                         :: proc(quat: ^Quat, axis: ^Vec3, result: ^Quat) ---
    Quat_GetSwingTwist                                    :: proc(quat: ^Quat, swing: ^Quat, twist: ^Quat) ---
    Quat_LERP                                             :: proc(from: ^Quat, to: ^Quat, fraction: f32, result: ^Quat) ---
    Quat_SLERP                                            :: proc(from: ^Quat, to: ^Quat, fraction: f32, result: ^Quat) ---
    Quat_Rotate                                           :: proc(quat: ^Quat, vec: ^Vec3, result: ^Vec3) ---
    Quat_InverseRotate                                    :: proc(quat: ^Quat, vec: ^Vec3, result: ^Vec3) ---
    Vec3_IsClose                                          :: proc(v1: ^Vec3, v2: ^Vec3, max_dist_sq: f32) -> bool ---
    Vec3_IsNearZero                                       :: proc(v: ^Vec3, max_dist_sq: f32) -> bool ---
    Vec3_IsNormalized                                     :: proc(v: ^Vec3, tolerance: f32) -> bool ---
    Vec3_IsNaN                                            :: proc(v: ^Vec3) -> bool ---
    Vec3_Negate                                           :: proc(v: ^Vec3, result: ^Vec3) ---
    Vec3_Normalized                                       :: proc(v: ^Vec3, result: ^Vec3) ---
    Vec3_Cross                                            :: proc(v1: ^Vec3, v2: ^Vec3, result: ^Vec3) ---
    Vec3_Abs                                              :: proc(v: ^Vec3, result: ^Vec3) ---
    Vec3_Length                                           :: proc(v: ^Vec3) -> f32 ---
    Vec3_LengthSquared                                    :: proc(v: ^Vec3) -> f32 ---
    Vec3_DotProduct                                       :: proc(v1: ^Vec3, v2: ^Vec3, result: ^f32) ---
    Vec3_Normalize                                        :: proc(v: ^Vec3, result: ^Vec3) ---
    Vec3_Add                                              :: proc(v1: ^Vec3, v2: ^Vec3, result: ^Vec3) ---
    Vec3_Subtract                                         :: proc(v1: ^Vec3, v2: ^Vec3, result: ^Vec3) ---
    Vec3_Multiply                                         :: proc(v1: ^Vec3, v2: ^Vec3, result: ^Vec3) ---
    Vec3_MultiplyScalar                                   :: proc(v: ^Vec3, scalar: f32, result: ^Vec3) ---
    Vec3_Divide                                           :: proc(v1: ^Vec3, v2: ^Vec3, result: ^Vec3) ---
    Vec3_DivideScalar                                     :: proc(v: ^Vec3, scalar: f32, result: ^Vec3) ---
    Matrix4x4_Add                                         :: proc(m1: ^Matrix4x4, m2: ^Matrix4x4, result: ^Matrix4x4) ---
    Matrix4x4_Subtract                                    :: proc(m1: ^Matrix4x4, m2: ^Matrix4x4, result: ^Matrix4x4) ---
    Matrix4x4_Multiply                                    :: proc(m1: ^Matrix4x4, m2: ^Matrix4x4, result: ^Matrix4x4) ---
    Matrix4x4_MultiplyScalar                              :: proc(m: ^Matrix4x4, scalar: f32, result: ^Matrix4x4) ---
    Matrix4x4_Zero                                        :: proc(result: ^Matrix4x4) ---
    Matrix4x4_Identity                                    :: proc(result: ^Matrix4x4) ---
    Matrix4x4_Rotation                                    :: proc(result: ^Matrix4x4, rotation: ^Quat) ---
    Matrix4x4_Translation                                 :: proc(result: ^Matrix4x4, translation: ^Vec3) ---
    Matrix4x4_RotationTranslation                         :: proc(result: ^Matrix4x4, rotation: ^Quat, translation: ^Vec3) ---
    Matrix4x4_InverseRotationTranslation                  :: proc(result: ^Matrix4x4, rotation: ^Quat, translation: ^Vec3) ---
    Matrix4x4_Scale                                       :: proc(result: ^Matrix4x4, scale: ^Vec3) ---
    Matrix4x4_Inversed                                    :: proc(m: ^Matrix4x4, result: ^Matrix4x4) ---
    Matrix4x4_Transposed                                  :: proc(m: ^Matrix4x4, result: ^Matrix4x4) ---
    RMatrix4x4_Zero                                       :: proc(result: ^RMatrix4x4) ---
    RMatrix4x4_Identity                                   :: proc(result: ^RMatrix4x4) ---
    RMatrix4x4_Rotation                                   :: proc(result: ^RMatrix4x4, rotation: ^Quat) ---
    RMatrix4x4_Translation                                :: proc(result: ^RMatrix4x4, translation: ^RVec3) ---
    RMatrix4x4_RotationTranslation                        :: proc(result: ^RMatrix4x4, rotation: ^Quat, translation: ^RVec3) ---
    RMatrix4x4_InverseRotationTranslation                 :: proc(result: ^RMatrix4x4, rotation: ^Quat, translation: ^RVec3) ---
    RMatrix4x4_Scale                                      :: proc(result: ^RMatrix4x4, scale: ^Vec3) ---
    RMatrix4x4_Inversed                                   :: proc(m: ^RMatrix4x4, result: ^RMatrix4x4) ---
    Matrix4x4_GetAxisX                                    :: proc(mat: ^Matrix4x4, result: ^Vec3) ---
    Matrix4x4_GetAxisY                                    :: proc(mat: ^Matrix4x4, result: ^Vec3) ---
    Matrix4x4_GetAxisZ                                    :: proc(mat: ^Matrix4x4, result: ^Vec3) ---
    Matrix4x4_GetTranslation                              :: proc(mat: ^Matrix4x4, result: ^Vec3) ---
    Matrix4x4_GetQuaternion                               :: proc(mat: ^Matrix4x4, result: ^Quat) ---

    //--------------------------------------------------------------------------------------------------
    // Draw Stuff
    //--------------------------------------------------------------------------------------------------
    /* Body_Draw_Filter */
    BodyDrawFilter_SetProcs                               :: proc(procs: ^Body_Draw_Filter_Procs) ---
    BodyDrawFilter_Create                                 :: proc(user_data: rawptr) -> ^Body_Draw_Filter ---
    BodyDrawFilter_Destroy                                :: proc(filter: ^Body_Draw_Filter) ---

    /* Draw_Settings */
    DrawSettings_InitDefault                              :: proc(settings: ^Draw_Settings) ---

    /* Debug_Renderer */
    DebugRenderer_SetProcs                                :: proc(procs: ^Debug_Renderer_Procs) ---
    DebugRenderer_Create                                  :: proc(user_data: rawptr) -> ^Debug_Renderer ---
    DebugRenderer_Destroy                                 :: proc(renderer: ^Debug_Renderer) ---
    DebugRenderer_NextFrame                               :: proc(renderer: ^Debug_Renderer) ---
    DebugRenderer_SetCameraPos                            :: proc(renderer: ^Debug_Renderer, position: ^RVec3) ---
    DebugRenderer_DrawLine                                :: proc(renderer: ^Debug_Renderer, from: ^RVec3, to: ^RVec3, color: Color) ---
    DebugRenderer_DrawWireBox                             :: proc(renderer: ^Debug_Renderer, box: ^AABox, color: Color) ---
    DebugRenderer_DrawWireBox2                            :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, box: ^AABox, color: Color) ---
    DebugRenderer_DrawMarker                              :: proc(renderer: ^Debug_Renderer, position: ^RVec3, color: Color, size: f32) ---
    DebugRenderer_DrawArrow                               :: proc(renderer: ^Debug_Renderer, from: ^RVec3, to: ^RVec3, color: Color, size: f32) ---
    DebugRenderer_DrawCoordinateSystem                    :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, size: f32) ---
    DebugRenderer_DrawPlane                               :: proc(renderer: ^Debug_Renderer, point: ^RVec3, normal: ^Vec3, color: Color, size: f32) ---
    DebugRenderer_DrawWireTriangle                        :: proc(renderer: ^Debug_Renderer, v1: ^RVec3, v2: ^RVec3, v3: ^RVec3, color: Color) ---
    DebugRenderer_DrawWireSphere                          :: proc(renderer: ^Debug_Renderer, center: ^RVec3, radius: f32, color: Color, level: c.int) ---
    DebugRenderer_DrawWireUnitSphere                      :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, color: Color, level: c.int) ---
    DebugRenderer_DrawTriangle                            :: proc(renderer: ^Debug_Renderer, v1: ^RVec3, v2: ^RVec3, v3: ^RVec3, color: Color, cast_shadow: Debug_Renderer_CastShadow) ---
    DebugRenderer_DrawBox                                 :: proc(renderer: ^Debug_Renderer, box: ^AABox, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawBox2                                :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, box: ^AABox, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawSphere                              :: proc(renderer: ^Debug_Renderer, center: ^RVec3, radius: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawUnitSphere                          :: proc(renderer: ^Debug_Renderer, mat: RMatrix4x4, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawCapsule                             :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, half_height_of_cylinder: f32, radius: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawCylinder                            :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, half_height: f32, radius: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawOpenCone                            :: proc(renderer: ^Debug_Renderer, top: ^RVec3, axis: ^Vec3, perpendicular: ^Vec3, half_angle: f32, length: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawSwingConeLimits                     :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, swingY_half_angle: f32, swing_z_half_angle: f32, edge_length: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawSwingPyramidLimits                  :: proc(renderer: ^Debug_Renderer, mat: ^RMatrix4x4, min_swing_y_angle: f32, max_swing_y_angle: f32, min_swing_z_angle: f32, max_swing_z_angle: f32, edge_length: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawPie                                 :: proc(renderer: ^Debug_Renderer, center: ^RVec3, radius: f32, normal: ^Vec3, axis: ^Vec3, min_angle: f32, max_angle: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
    DebugRenderer_DrawTaperedCylinder                     :: proc(renderer: ^Debug_Renderer, inMatrix: ^RMatrix4x4, top: f32, bottom: f32, top_radius: f32, bottom_radius: f32, color: Color, cast_shadow: Debug_Renderer_CastShadow, draw_mode: Debug_Renderer_DrawMode) ---
}
