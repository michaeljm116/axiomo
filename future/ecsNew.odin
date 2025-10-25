package ecs

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:slice"
import "core:strings"

// Type Definitions
EntityID :: distinct u64
ArchetypeID :: u64
ComponentID :: EntityID

// Errors
Error :: enum {
	None,
	EntityNotFound,
	ComponentNotFound,
	ArchetypeNotFound,
	ComponentDataOutOfBounds,
	InvalidComponentID,
	EntityAlreadyExists,
	ComponentAlreadyExists,
	ComponentDisabled,
	OperationFailed,
}

Result :: union($T: typeid) {
	T,
	Error,
}

// Component Type Registry
ComponentTypeInfo :: struct {
	size:      int,
	type_info: ^reflect.Type_Info,
}

// Size of Type_Info
size_of_type :: proc(type_info: ^reflect.Type_Info) -> int {
	return int(runtime.type_info_base(type_info).size)
}

get_component_id :: proc(world: ^World, T: typeid) -> (ComponentID, bool) {
	return world.component_ids[T]
}

World :: struct {
	component_info:       map[ComponentID]ComponentTypeInfo,
	info_component:       map[ComponentTypeInfo]ComponentID,
	component_ids:        map[typeid]ComponentID,
	pair_component_ids:   map[EntityID]ComponentID,
	entity_index:         map[EntityID]EntityInfo,
	archetypes:           map[ArchetypeID]^Archetype,
	component_archetypes: map[ComponentID]map[ArchetypeID]^Archetype,
	next_entity_id:       EntityID,
	queries:              [dynamic]^Query,
	allocator:            runtime.Allocator, // NEW: Stored allocator
	archetype_pool:       [dynamic]^Archetype, // NEW: Pool for archetype reuse
	free_archetype_indices: [dynamic]int, // NEW: Free list
}

// Entity Info stores the location of an entity within an archetype and its version
// TODO: store version in upper 16 bits of entity ID
// TODO: if entity ID is a Pair: store relationship target in lower 16 bits and relation id in upper 16 bits

Wildcard :: distinct struct {}

PairType :: struct($R, $T: typeid) {
	relation: R,
	target:   T,
}

EntityInfo :: struct {
	archetype: ^Archetype,
	row:       int,
	version:   u32,
}

Query :: struct {
	component_ids: [dynamic]ComponentID,
	archetypes:    [dynamic]^Archetype,
}

Archetype :: struct {
	id:               ArchetypeID,
	component_ids:    [dynamic]ComponentID,
	tag_ids:          [dynamic]ComponentID,
	component_types:  map[ComponentID]^reflect.Type_Info,
	entities:         [dynamic]EntityID,
	tables:           map[ComponentID][dynamic]byte,
	disabled_set:     map[ComponentID]bool,
	matching_queries: [dynamic]^Query,
	add_edges:        map[ComponentID]^Archetype, // No remove_edges
}

create_world :: proc(alloc: runtime.Allocator) -> ^World {
	world := new(World, alloc)
	world.allocator = alloc
	world.component_info = make(map[ComponentID]ComponentTypeInfo, alloc)
	world.info_component = make(map[ComponentTypeInfo]ComponentID, alloc)
	world.component_ids = make(map[typeid]ComponentID, alloc)
	world.pair_component_ids = make(map[EntityID]ComponentID, alloc)
	world.entity_index = make(map[EntityID]EntityInfo, alloc)
	world.archetypes = make(map[ArchetypeID]^Archetype, alloc)
	world.component_archetypes = make(map[ComponentID]map[ArchetypeID]^Archetype, alloc)
	world.queries = make([dynamic]^Query, alloc)
	world.next_entity_id = EntityID(1)

	// // Pre-reserve capacities (adjust based on your game)
	// reserve(&world.entity_index, 10000)
	// reserve(&world.component_ids, 100) // e.g., 100 component types

	// // NEW: Preallocate archetype pool (e.g., 128 max archetypes)
	// world.archetype_pool = make([dynamic]^Archetype, 128, alloc)
	// world.free_archetype_indices = make([dynamic]int, 128, alloc)
	// for i in 0..<128 {
	// 	arch := new(Archetype, alloc)
	// 	arch.component_ids = make([dynamic]ComponentID, alloc)
	// 	arch.tag_ids = make([dynamic]ComponentID, alloc)
	// 	arch.component_types = make(map[ComponentID]^reflect.Type_Info, alloc)
	// 	arch.entities = make([dynamic]EntityID, alloc)
	// 	arch.tables = make(map[ComponentID][dynamic]byte, alloc)
	// 	arch.disabled_set = make(map[ComponentID]bool, alloc)
	// 	arch.matching_queries = make([dynamic]^Query, alloc)
	// 	arch.add_edges = make(map[ComponentID]^Archetype, alloc)

	// 	// Pre-reserve per-archetype (e.g., 500 entities per archetype)
	// 	reserve(&arch.entities, 500)
	// 	reserve(&arch.component_types, 50)
	// 	reserve(&arch.tables, 50)
	// 	append(&world.archetype_pool, arch)
	// 	append(&world.free_archetype_indices, i)
	// }

	return world
}

new_world :: create_world

delete_world :: proc(world: ^World) {
	if world == nil {
		return
	}

	alloc := world.allocator

	for _, archetype in world.archetypes {
		clear_archetype(archetype, alloc) // Clear for reuse
	}
	clear(&world.archetypes)

	clear(&world.component_info)
	clear(&world.info_component)
	clear(&world.component_ids)
	clear(&world.pair_component_ids)
	clear(&world.entity_index)
	for cid, &comp_map in world.component_archetypes {
		clear(&comp_map)
	}
	clear(&world.component_archetypes)
	clear(&world.queries)

	// Reset pool for reuse (no free)
	clear(&world.free_archetype_indices)
	for i in 0..<len(world.archetype_pool) {
		clear_archetype(world.archetype_pool[i], alloc)
		append(&world.free_archetype_indices, i)
	}

	// No free(world) - arena reset handles
	// If not reusing world, free(world, alloc) - but assume reset
}

clear_archetype :: proc(archetype: ^Archetype, alloc: runtime.Allocator) {
	clear(&archetype.component_ids)
	clear(&archetype.tag_ids)
	clear(&archetype.component_types)
	clear(&archetype.entities)
	for cid, &table in archetype.tables {
		clear(&table)
	}
	clear(&archetype.tables)
	clear(&archetype.disabled_set)
	clear(&archetype.matching_queries)
	clear(&archetype.add_edges)
}

register_component :: proc {
	register_component_typeid,
}

register_component_typeid :: proc(world: ^World, T: typeid) -> ComponentID {
	id := add_entity(world)
	type_info := type_info_of(T)
	info := ComponentTypeInfo {
		size      = size_of_type(type_info),
		type_info = type_info,
	}
	world.component_info[id] = info
	world.info_component[info] = id
	world.component_ids[type_info.id] = id
	return id
}

add_entity :: proc(world: ^World) -> EntityID {
	entity := world.next_entity_id
	world.next_entity_id = world.next_entity_id + 1

	// TODO: pack version etc into ID bits
	if entity in world.entity_index {
		info := &world.entity_index[entity]
		info.archetype = nil
		info.row = -1
		info.version += 1
	} else {
		world.entity_index[entity] = EntityInfo {
			archetype = nil,
			row       = -1,
			version   = 0,
		}
	}
	return entity
}

create_entity :: add_entity

// Removed remove_entity (bulk only via delete_world)

entity_exists :: proc(world: ^World, entity: EntityID) -> bool {
	info, ok := world.entity_index[entity]
	return ok && info.archetype != nil
}

entity_alive :: entity_exists

has_component :: proc {
	has_component_type,
	has_component_instance,
}

has_component_type :: proc(world: ^World, entity: EntityID, $T: typeid) -> bool {
	info, exists := world.entity_index[entity]
	if !exists || info.archetype == nil {
		return false
	}

	cid, ok := get_component_id(world, T)
	if !ok {
		return false
	}
	return slice.contains(info.archetype.component_ids[:], cid)
}

has_component_instance :: proc(world: ^World, entity: EntityID, component: $T) -> bool {
	info, exists := world.entity_index[entity]
	if !exists || info.archetype == nil {
		return false
	}

	cid, ok := get_component_id(world, T)
	if !ok {
		return false
	}
	return slice.contains(info.archetype.component_ids[:], cid)
}

get_relation_typeid :: proc(c: PairType($R, $T)) -> typeid {
	return typeid_of(R)
}

get_relation_type :: proc(c: PairType($R, $T)) -> typeid {
	return R
}

add_component :: proc(world: ^World, entity: EntityID, component: $T) {
	alloc := world.allocator
    cid: ComponentID
    ok: bool

    when intrinsics.type_is_struct(T) && intrinsics.type_has_field(T, "relation") && intrinsics.type_has_field(T, "target") {
        relation_cid: ComponentID
        target_cid: ComponentID

        when type_of(component.relation) == EntityID {
            relation_cid = ComponentID(component.relation)
        } else {
            relation_cid, ok = get_component_id(world, type_of(component.relation))
            if !ok {
                relation_cid = register_component(world, type_of(component.relation))
            }
        }

        when type_of(component.target) == EntityID {
            target_cid = ComponentID(component.target)
        } else {
            target_cid, ok = get_component_id(world, type_of(component.target))
            if !ok {
                target_cid = register_component(world, type_of(component.target))
            }
        }

        cid = hash_pair(relation_cid, target_cid)

        pair_type_info := type_info_of(T)
        world.component_info[cid] = ComponentTypeInfo{
            size      = size_of(T),
            type_info = pair_type_info,
        }
    } else {
        cid, ok = get_component_id(world, T)
        if !ok {
            cid = register_component(world, T)
        }
    }

    info := world.entity_index[entity]
    info_ptr := &world.entity_index[entity]
    old_archetype := info.archetype
    new_archetype: ^Archetype

    if old_archetype == nil {
        new_component_ids: [dynamic]ComponentID = make([dynamic]ComponentID, alloc)
        defer clear(&new_component_ids)
        append(&new_component_ids, cid)

        new_tag_ids: [dynamic]ComponentID = make([dynamic]ComponentID, alloc)
        defer clear(&new_tag_ids)
        tag_count := 0
        if size_of(T) == 0 {
            append(&new_tag_ids, cid)
            tag_count = 1
        }

        new_archetype = get_or_create_archetype(world, new_component_ids[:], new_tag_ids[:])

        move_entity(world, entity, info, nil, new_archetype)
    } else {
        new_archetype, ok = old_archetype.add_edges[cid]
        if !ok {
            new_component_ids: [dynamic]ComponentID = make([dynamic]ComponentID, alloc)
            defer clear(&new_component_ids)
            append(&new_component_ids, ..old_archetype.component_ids[:])
            append(&new_component_ids, cid)
            slice.sort(new_component_ids[:])

            new_tag_ids: [dynamic]ComponentID = make([dynamic]ComponentID, alloc)
            defer clear(&new_tag_ids)
            append(&new_tag_ids, ..old_archetype.tag_ids[:])
            if size_of(T) == 0 {
                append(&new_tag_ids, cid)
            }

            new_archetype = get_or_create_archetype(world, new_component_ids[:], new_tag_ids[:])

            old_archetype.add_edges[cid] = new_archetype
            // No remove_edges
        }

        move_entity(world, entity, info, old_archetype, new_archetype)
    }

    when size_of(T) > 0 {
        index := info_ptr.row
        local_component := component

        when intrinsics.type_is_struct(T) && intrinsics.type_has_field(T, "relation") && intrinsics.type_has_field(T, "target") {
            add_component_data(
                new_archetype,
                cid,
                rawptr(&local_component),
                index,
                type_of(component.relation),
            )
        } else {
            add_component_data(new_archetype, cid, rawptr(&local_component), index, T)
        }
    }
}

// Removed remove_component

add_component_data :: proc(
	archetype: ^Archetype,
	component_id: ComponentID,
	component: rawptr,
	index: int,
	$T: typeid,
) {
	table, ok := &archetype.tables[component_id]
	if !ok {
		return
	}

	size := size_of(T)
	if size == 0 {
		return // Skip tags as they don't have data
	}

	required_size := (index + 1) * size
	if len(table^) < required_size {
		resize(table, required_size) // Use resize for [dynamic]
	}

	offset := index * size

	mem.copy(rawptr(uintptr(raw_data(table^)) + uintptr(offset)), component, size)
}

move_entity :: proc(world: ^World, entity: EntityID, info: EntityInfo, old_archetype, new_archetype: ^Archetype) {
	alloc := world.allocator
	old_row := info.row

	// Append entity to new archetype
	new_row := len(new_archetype.entities)
	append(&new_archetype.entities, entity)

	// Copy component data from old to new
	if old_archetype != nil {
		for cid in old_archetype.component_ids[:] {
			old_table := old_archetype.tables[cid]
			new_table, _ := &new_archetype.tables[cid]

			component_size := size_of_type(old_archetype.component_types[cid])
			if component_size == 0 { continue }

			required_size := (new_row + 1) * component_size
			if len(new_table^) < required_size {
				resize(new_table, required_size)
			}

			old_offset := old_row * component_size
			new_offset := new_row * component_size
			mem.copy(rawptr(uintptr(raw_data(new_table^)) + uintptr(new_offset)), rawptr(uintptr(raw_data(old_table)) + uintptr(old_offset)), component_size)
		}

		// Swap-remove from old archetype
		last_old_row := len(old_archetype.entities) - 1
		if old_row != last_old_row {
			moved_entity := old_archetype.entities[last_old_row]
			old_archetype.entities[old_row] = moved_entity
			moved_info := &world.entity_index[moved_entity]
			moved_info.row = old_row

			for cid in old_archetype.component_ids[:] {
				component_size := size_of_type(old_archetype.component_types[cid])
				if component_size == 0 { continue }

				old_table := &old_archetype.tables[cid]
				last_offset := last_old_row * component_size
				old_offset := old_row * component_size
				mem.copy(rawptr(uintptr(raw_data(old_table^)) + uintptr(old_offset)), rawptr(uintptr(raw_data(old_table^)) + uintptr(last_offset)), component_size)
			}
		}

		pop(&old_archetype.entities)
		for cid in old_archetype.component_ids[:] {
			component_size := size_of_type(old_archetype.component_types[cid])
			if component_size == 0 { continue }

			table := &old_archetype.tables[cid]
			resize(table, len(old_archetype.entities) * component_size)
		}

		// If old archetype empty, clear it (no delete)
		if len(old_archetype.entities) == 0 {
			clear_archetype(old_archetype, alloc)
			// remove archetype entry from the world map
			delete_key(&world.archetypes, old_archetype.id)
			// remove archetype from component -> archetype maps (in-place)
			for cid in old_archetype.component_ids[:] {
				if _, ok := world.component_archetypes[cid]; ok {
					delete_key(&world.component_archetypes[cid], old_archetype.id)
				}
			}
		}
	}

	// Update entity info
	entity_info := &world.entity_index[entity]
	entity_info.archetype = new_archetype
	entity_info.row = new_row
}

get_or_create_archetype :: proc(world: ^World, component_ids: []ComponentID, tag_ids: []ComponentID) -> ^Archetype {
	alloc := world.allocator
	id := hash_archetype(component_ids, tag_ids)
	if arch, ok := world.archetypes[id]; ok {
		return arch
	}

	// Reuse from pool
	if len(world.free_archetype_indices) == 0 {
		// Grow pool
		new_idx := len(world.archetype_pool)
		arch := new(Archetype, alloc)
		arch.component_ids = make([dynamic]ComponentID, alloc)
		arch.tag_ids = make([dynamic]ComponentID, alloc)
		arch.component_types = make(map[ComponentID]^reflect.Type_Info, alloc)
		arch.entities = make([dynamic]EntityID, alloc)
		arch.tables = make(map[ComponentID][dynamic]byte, alloc)
		arch.disabled_set = make(map[ComponentID]bool, alloc)
		arch.matching_queries = make([dynamic]^Query, alloc)
		arch.add_edges = make(map[ComponentID]^Archetype, alloc)

		// reserve(&arch.entities, 500)
		// reserve(&arch.component_types, 50)
		// reserve(&arch.tables, 50)
		append(&world.archetype_pool, arch)
		append(&world.free_archetype_indices, new_idx)
	}

	idx := pop(&world.free_archetype_indices)
	archetype := world.archetype_pool[idx]

	// Clear/reinit
	clear_archetype(archetype, alloc) // Ensures clean state

	archetype.id = id
	append(&archetype.component_ids, ..component_ids)
	append(&archetype.tag_ids, ..tag_ids)

	for cid in component_ids {
		if info, ok := world.component_info[cid]; ok {
			archetype.component_types[cid] = info.type_info
			if info.size > 0 {
				archetype.tables[cid] = make([dynamic]byte, alloc)
				// reserve(&archetype.tables[cid], 500 * info.size) // Pre-reserve
			}
		}
	}

	world.archetypes[id] = archetype

	for cid in component_ids {
		if _, ok := world.component_archetypes[cid]; !ok {
			world.component_archetypes[cid] = make(map[ArchetypeID]^Archetype, alloc)
		}
		comp_arch := world.component_archetypes[cid]
		comp_arch[id] = archetype
	}

	return archetype
}

hash_archetype :: proc(component_ids: []ComponentID, tag_ids: []ComponentID) -> ArchetypeID {
	h: u64 = 14695981039346656037
	for id in component_ids {
		h = (h ~ u64(id)) * 1099511628211
	}
	for id in tag_ids {
		h = (h ~ u64(id)) * 1099511628211
	}
	return ArchetypeID(h)
}

get_component :: proc {
	get_component_same,
	get_component_cast,
	get_component_pair,
}

get_component_same :: proc(world: ^World, entity: EntityID, $Component: typeid) -> ^Component {
	info, ok := world.entity_index[entity]
	if !ok || info.archetype == nil {
		return nil
	}
	cid, cid_ok := get_component_id(world, Component)
	if !cid_ok {
		return nil
	}
	table, exists := info.archetype.tables[cid]
	if !exists {
		return nil
	}
	row := info.row
	component_size := size_of(Component)
	num_components := len(table) / component_size
	if row >= num_components {
		return nil
	}
	components := transmute([]Component)raw_data(table)[:num_components]
	return &components[row]
}

get_component_cast :: proc(world: ^World, entity: EntityID, $Component: typeid, $CastTo: typeid) -> ^CastTo {
	// Similar to above, cast to CastTo
	info, ok := world.entity_index[entity]
	if !ok || info.archetype == nil {
		return nil
	}
	cid, cid_ok := get_component_id(world, Component)
	if !cid_ok {
		return nil
	}
	table, exists := info.archetype.tables[cid]
	if !exists {
		return nil
	}
	row := info.row
	component_size := size_of(CastTo)
	num_components := len(table) / component_size
	if row >= num_components {
		return nil
	}
	components := transmute([]CastTo)raw_data(table)[:num_components]
	return &components[row]
}

get_component_pair :: proc(world: ^World, entity: EntityID, pair: PairType($R, $T)) -> ^R {
	info, ok := world.entity_index[entity]
	if !ok || info.archetype == nil {
		return nil
	}
	relation_cid, _ := get_component_id(world, R)
	target_cid, _ := get_component_id(world, T)
	pair_cid := hash_pair(relation_cid, target_cid)
	table, exists := info.archetype.tables[pair_cid]
	if !exists {
		return nil
	}
	row := info.row
	component_size := size_of(R)
	num_components := len(table) / component_size
	if row >= num_components {
		return nil
	}
	components := transmute([]R)raw_data(table)[:num_components]
	return &components[row]
}

get_table :: proc {
	get_table_same,
	get_table_cast,
	get_table_pair,
}

get_table_same :: proc(world: ^World, archetype: ^Archetype, $Component: typeid) -> []Component {
	cid, ok := get_component_id(world, Component)
	if !ok {
		return nil
	}
	table, exists := archetype.tables[cid]
	if !exists {
		return nil
	}
	component_size := size_of(Component)
	num_components := len(table) / component_size
	return transmute([]Component)raw_data(table)[:num_components]
}

get_table_cast :: proc(
	world: ^World,
	archetype: ^Archetype,
	$Component: typeid,
	$CastTo: typeid,
) -> []CastTo {
	cid, ok := get_component_id(world, Component)
	if !ok {
		return nil
	}
	table, exists := archetype.tables[cid]
	if !exists {
		return nil
	}
	component_size := size_of(CastTo)
	num_components := len(table) / component_size
	return transmute([]CastTo)raw_data(table)[:num_components]
}

get_table_pair :: proc(world: ^World, archetype: ^Archetype, pair: PairType($R, $T)) -> []R {
	relation_cid, _ := get_component_id(world, R)
	target_cid, _ := get_component_id(world, T)
	pair_cid := hash_pair(relation_cid, target_cid)
	table, exists := archetype.tables[pair_cid]
	if !exists {
		return nil
	}
	component_size := size_of(R)
	num_components := len(table) / component_size
	return transmute([]R)raw_data(table)[:num_components]
}

get_table_row :: proc(world: ^World, entity_id: EntityID) -> int {
	if info, ok := world.entity_index[entity_id]; ok {
		return info.row
	}
	return -1
}

// Query builder structure
QueryBuilder :: struct {
	world: ^World,
	terms: [dynamic]Term,
}

Term :: union {
	HasTerm,
	NotTerm,
	PairType(typeid, typeid),
	PairType(EntityID, EntityID),
	PairType(EntityID, typeid),
	PairType(typeid, EntityID),
}

HasTerm :: struct {
	component: union {
		typeid,
		PairType(typeid, typeid),
		PairType(EntityID, EntityID),
		PairType(EntityID, typeid),
		PairType(typeid, EntityID),
	},
}

NotTerm :: struct {
	component: union {
		typeid,
		PairType(typeid, typeid),
		PairType(EntityID, EntityID),
		PairType(EntityID, typeid),
		PairType(typeid, EntityID),
	},
}

// Initialize a new query builder
new_query :: proc(world: ^World) -> QueryBuilder {
	alloc := world.allocator
	return QueryBuilder{world = world, terms = make([dynamic]Term, alloc)}
}

execute :: proc(q: ^QueryBuilder) -> []^Archetype {
	alloc := q.world.allocator
	if len(q.terms) == 0 {
		return nil
	}

	has_terms: [dynamic]ComponentID = make([dynamic]ComponentID, alloc)
	not_terms: [dynamic]ComponentID = make([dynamic]ComponentID, alloc)
	defer {
		clear(&has_terms)
		clear(&not_terms)
	}

	for term in q.terms {
		cid: ComponentID
		ok: bool

		switch t in term {
		case HasTerm:
			switch component in t.component {
			case typeid:
				cid, ok = get_component_id_from_term_typeid(q.world, component)
			case PairType(typeid, typeid):
				cid, ok = get_component_id_from_term_pair_typeid_typeid(q.world, component)
			case PairType(EntityID, EntityID):
				cid, ok = get_component_id_from_term_pair_entity_entity(q.world, component)
			case PairType(EntityID, typeid):
				cid, ok = get_component_id_from_term_pair_entity_typeid(q.world, component)
			case PairType(typeid, EntityID):
				cid, ok = get_component_id_from_term_pair_typeid_entity(q.world, component)
			}
			if ok {
				append(&has_terms, cid)
			}
		case NotTerm:
			switch component in t.component {
			case typeid:
				cid, ok = get_component_id_from_term_typeid(q.world, component)
			case PairType(typeid, typeid):
				cid, ok = get_component_id_from_term_pair_typeid_typeid(q.world, component)
			case PairType(EntityID, EntityID):
				cid, ok = get_component_id_from_term_pair_entity_entity(q.world, component)
			case PairType(EntityID, typeid):
				cid, ok = get_component_id_from_term_pair_entity_typeid(q.world, component)
			case PairType(typeid, EntityID):
				cid, ok = get_component_id_from_term_pair_typeid_entity(q.world, component)
			}
			if ok {
				append(&not_terms, cid)
			}
		case PairType(typeid, typeid):
			cid, ok = get_component_id_from_pair(q.world, t)
			if ok {
				append(&has_terms, cid)
			}
		case PairType(EntityID, EntityID):
			cid, ok = get_component_id_from_pair(q.world, t)
			if ok {
				append(&has_terms, cid)
			}
		case PairType(EntityID, typeid):
			cid, ok = get_component_id_from_pair(q.world, t)
			if ok {
				append(&has_terms, cid)
			}
		case PairType(typeid, EntityID):
			cid, ok = get_component_id_from_pair(q.world, t)
			if ok {
				append(&has_terms, cid)
			}
		}

		if !ok {
			return []^Archetype{}
		}
	}

	result: [dynamic]^Archetype = make([dynamic]^Archetype, alloc)
	defer clear(&result)
	for key, archetype in q.world.archetypes {
		all_has_present := true
		for id in has_terms[:] {
			if !slice.contains(archetype.component_ids[:], id) {
				all_has_present = false
				break
			}
		}

		no_not_present := true
		for id in not_terms[:] {
			if slice.contains(archetype.component_ids[:], id) {
				no_not_present = false
				break
			}
		}

		if all_has_present && no_not_present {
			append(&result, archetype)
		}
	}

	// Return as slice (caller can copy if needed)
	return result[:]
}

get_component_id_from_term :: proc {
    get_component_id_from_term_typeid,
    get_component_id_from_term_pair_typeid_typeid,
    get_component_id_from_term_pair_typeid_entity,
    get_component_id_from_term_pair_entity_typeid,
    get_component_id_from_term_pair_entity_entity,
}

get_component_id_from_term_typeid :: proc(world: ^World, component: typeid) -> (ComponentID, bool) {
    return get_component_id(world, component)
}

get_component_id_from_term_pair_typeid_typeid :: proc(world: ^World, component: PairType(typeid, typeid)) -> (ComponentID, bool) {
    return get_component_id_from_pair(world, component)
}

get_component_id_from_term_pair_typeid_entity :: proc(world: ^World, component: PairType(typeid, EntityID)) -> (ComponentID, bool) {
    return get_component_id_from_pair(world, component)
}

get_component_id_from_term_pair_entity_typeid :: proc(world: ^World, component: PairType(EntityID, typeid)) -> (ComponentID, bool) {
    return get_component_id_from_pair(world, component)
}

get_component_id_from_term_pair_entity_entity :: proc(world: ^World, component: PairType(EntityID, EntityID)) -> (ComponentID, bool) {
    return get_component_id_from_pair(world, component)
}

get_type_id_from_type_or_struct :: proc(value: $T) -> typeid {
	when T == typeid {
		return type_info_of(value).id
	} else {
		return type_info_of(typeid_of(T)).id
	}
}

get_relation_from_pair :: proc(pair: $P/PairType) -> union{EntityID, typeid} {
	return pair.relation
}

get_target_from_pair :: proc(pair: $P/PairType) -> union{EntityID, typeid} {
	return pair.target
}

get_component_id_from_pair :: proc(world: ^World, pair: $P/PairType) -> (ComponentID, bool) {
    relation := get_relation_from_pair(pair)
    relation_cid: ComponentID

    switch r in relation {
    case EntityID:
        relation_cid = ComponentID(r)
    case typeid:
        ok: bool
        relation_cid, ok = get_component_id(world, r)
        if !ok {
            return 0, false
        }
    case:
        return 0, false
    }

    target := get_target_from_pair(pair)
    target_cid: ComponentID

    switch t in target {
    case EntityID:
        target_cid = ComponentID(t)
    case typeid:
        ok: bool
        target_cid, ok = get_component_id(world, t)
        if !ok {
            return 0, false
        }
    case:
        return 0, false
    }

    result := hash_pair(relation_cid, target_cid)
    return result, true
}

hash_pair :: proc(relation_cid, target_cid: ComponentID) -> ComponentID {
	return ComponentID(u64(relation_cid) << 32 | u64(target_cid))
}

has :: proc {
	has_typeid,
	has_pair,
}

has_typeid :: proc(component: typeid) -> Term {
	return HasTerm{component}
}

has_pair :: proc(p: $P/PairType) -> Term {
	return HasTerm{p}
}

not :: proc {
	not_typeid,
	not_pair,
}

not_typeid :: proc(component: typeid) -> Term {
	return NotTerm{component}
}

not_pair :: proc(p: $P/PairType) -> Term {
	return NotTerm{p}
}

query :: proc(world: ^World, terms: ..Term) -> []^Archetype {
	q := new_query(world)
	for term in terms {
		append(&q.terms, term)
	}
	defer clear(&q.terms) // Clear for reuse
	return execute(&q)
}

pair :: proc {
    pair_generic,
    pair_typeid_entity,
    pair_entity_typeid,
    pair_typeid_typeid,
}

pair_generic :: proc(r: $R, t: $T) -> PairType(R, T) {
    return PairType(R, T){r, t}
}

pair_typeid_entity :: proc(r: typeid, t: EntityID) -> PairType(typeid, EntityID) {
    return PairType(typeid, EntityID){r, t}
}

pair_entity_typeid :: proc(r: EntityID, t: typeid) -> PairType(EntityID, typeid) {
    return PairType(EntityID, typeid){r, t}
}

pair_typeid_typeid :: proc(r: typeid, t: typeid) -> PairType(typeid, typeid) {
    return PairType(typeid, typeid){r, t}
}