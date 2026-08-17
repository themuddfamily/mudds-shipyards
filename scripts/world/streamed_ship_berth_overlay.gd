class_name StreamedShipBerthOverlay
extends RefCounted

## Atomic, generation-safe discovery overlay for externally owned streamed
## ShipBerths. A later world owner can merge its configured resident berth IDs
## with this overlay and resolve a streamed ID to the exact live ShipBerth.
##
## The caller observes WorldStreamingCoordinator's committed location signals
## and forwards their exact generations here. This object never loads, unloads,
## reparents, frees, reserves, occupies, releases, lands, moves, or presents.

signal location_registered(snapshot: Dictionary)
signal location_retired(tombstone: Dictionary)

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_RESIDENT_BERTH_IDS := 128
const MAX_ACTIVE_STREAMED_BERTHS := 64
const MAX_ACTIVE_LOCATIONS := 32
const MAX_BERTHS_PER_LOCATION := 16
const MAX_TRACKED_BERTH_IDS := 128
const MAX_TRACKED_LOCATION_IDS := 64

const AUTHORITY := {
	"renderer": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": false,
}
const ADJACENT_AUTHORITY := {
	"scene_tree_mutation": false,
	"berth_lease": false,
	"reservation": false,
	"occupancy": false,
	"ship_token": false,
	"landing": false,
	"ship_movement": false,
	"cargo": false,
	"route": false,
	"reward": false,
	"ui": false,
}

var _configured := false
var _coordinator: WeakRef
var _coordinator_instance_id := 0
var _resident_berth_ids: Array[StringName] = []
var _resident_berth_id_set: Dictionary = {}
var _locations: Dictionary = {}
var _records_by_berth_id: Dictionary = {}
var _berth_id_by_instance_id: Dictionary = {}
var _location_tombstones: Dictionary = {}
var _berth_tombstones: Dictionary = {}
var _loaded_observation_count := 0
var _unloaded_observation_count := 0
var _last_loaded_observation: Dictionary = {}
var _last_unloaded_observation: Dictionary = {}
var _mutation_active := false
var _signal_dispatch_active := false


## Configures the future owner's stable resident roster once. An explicit empty
## roster is valid. Streamed registration remains closed until configuration is
## committed, preventing accidental omission of resident collision checks.
func configure(
	coordinator: WorldStreamingCoordinator,
	berth_ids: PackedStringArray
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if _configured:
		return _finish(false, &"already_configured")
	if coordinator == null or not is_instance_valid(coordinator) \
			or coordinator.is_queued_for_deletion() or not coordinator.is_inside_tree():
		return _finish(false, &"invalid_coordinator")
	if not coordinator.get_loaded_ids().is_empty() \
			or not coordinator.get_loading_ids().is_empty():
		return _finish(false, &"coordinator_not_quiescent")
	if berth_ids.size() > MAX_RESIDENT_BERTH_IDS:
		return _finish(false, &"resident_capacity_exceeded")
	var normalized: Array[StringName] = []
	var seen: Dictionary = {}
	for berth_id_text in berth_ids:
		var berth_id := StringName(berth_id_text)
		if not _is_stable_id(berth_id):
			return _finish(false, &"invalid_resident_berth_id")
		if seen.has(berth_id):
			return _finish(false, &"duplicate_resident_berth_id")
		seen[berth_id] = true
		normalized.append(berth_id)
	normalized.sort_custom(_sort_string_names)
	_resident_berth_ids = normalized
	_resident_berth_id_set = seen
	_coordinator = weakref(coordinator)
	_coordinator_instance_id = coordinator.get_instance_id()
	coordinator.location_loaded.connect(_on_coordinator_location_loaded)
	coordinator.location_unloaded.connect(_on_coordinator_location_unloaded)
	_configured = true
	return _finish(true, &"configured", &"", -1, -1, {
		"resident_berth_ids": _resident_berth_ids.duplicate(),
		"coordinator_instance_id": _coordinator_instance_id,
	})


## Discovers and atomically registers the complete valid ShipBerth roster under
## one coordinator-loaded scene root. No index or signal changes if any berth or
## provenance field fails preflight.
func register_loaded_root(
	location_id: StringName,
	load_generation: int,
	root_instance_id: int,
	loaded_root: Node3D
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call", location_id, load_generation)
	_mutation_active = true
	if not _configured:
		return _finish(false, &"not_configured", location_id, load_generation)
	var primitive_error := _registration_primitive_error(
		location_id, load_generation, root_instance_id
	)
	if not primitive_error.is_empty():
		return _finish(false, primitive_error, location_id, load_generation)
	var root_error := _loaded_root_error(
		loaded_root, location_id, load_generation, root_instance_id
	)
	if not root_error.is_empty():
		return _finish(false, root_error, location_id, load_generation)
	var coordinator := _get_coordinator()
	if coordinator == null:
		return _finish(false, &"coordinator_unavailable", location_id, load_generation)
	if coordinator.get_loaded_instance(location_id) != loaded_root:
		return _finish(
			false, &"coordinator_loaded_root_mismatch", location_id, load_generation
		)

	var active: Dictionary = _locations.get(location_id, {})
	if not active.is_empty():
		var active_generation := int(active.load_generation)
		if load_generation < active_generation:
			return _finish(false, &"stale_generation", location_id, load_generation)
		if load_generation > active_generation:
			return _finish(false, &"generation_collision", location_id, load_generation)
		if root_instance_id == int(active.root_instance_id):
			return _finish(false, &"duplicate_location", location_id, load_generation)
		return _finish(false, &"root_collision", location_id, load_generation)

	var location_tombstone: Dictionary = _location_tombstones.get(location_id, {})
	if not location_tombstone.is_empty() \
			and load_generation <= int(location_tombstone.retirement_generation):
		return _finish(false, &"stale_generation", location_id, load_generation)
	if _locations.size() >= MAX_ACTIVE_LOCATIONS:
		return _finish(false, &"active_location_capacity_exceeded", location_id, load_generation)
	if not _tracked_location_has_capacity(location_id):
		return _finish(false, &"tracked_location_capacity_exceeded", location_id, load_generation)

	var discovered := loaded_root.find_children("*", "ShipBerth", true, false)
	if discovered.is_empty():
		return _finish(false, &"no_ship_berths", location_id, load_generation)
	if discovered.size() > MAX_BERTHS_PER_LOCATION:
		return _finish(false, &"location_berth_capacity_exceeded", location_id, load_generation)
	if _records_by_berth_id.size() + discovered.size() > MAX_ACTIVE_STREAMED_BERTHS:
		return _finish(false, &"active_berth_capacity_exceeded", location_id, load_generation)

	var pending: Array[Dictionary] = []
	var pending_ids: Dictionary = {}
	var pending_instances: Dictionary = {}
	var new_tracked_berth_ids := 0
	for candidate_value in discovered:
		var berth := candidate_value as ShipBerth
		if berth == null or not is_instance_valid(berth) \
				or berth.is_queued_for_deletion() or not berth.is_inside_tree():
			return _finish(false, &"invalid_berth", location_id, load_generation)
		if not loaded_root.is_ancestor_of(berth):
			return _finish(false, &"invalid_berth_ancestry", location_id, load_generation)
		if not berth.get_validation_errors().is_empty():
			return _finish(false, &"invalid_berth", location_id, load_generation)
		var berth_id := berth.get_berth_id()
		var berth_instance_id := berth.get_instance_id()
		if not _is_stable_id(berth_id) or not _is_positive_safe_integer(berth_instance_id):
			return _finish(false, &"invalid_berth", location_id, load_generation)
		if pending_ids.has(berth_id):
			return _finish(false, &"duplicate_berth_id", location_id, load_generation)
		if pending_instances.has(berth_instance_id):
			return _finish(false, &"duplicate_berth_instance", location_id, load_generation)
		if _resident_berth_id_set.has(berth_id) or _records_by_berth_id.has(berth_id):
			return _finish(false, &"berth_id_collision", location_id, load_generation)
		if _berth_id_by_instance_id.has(berth_instance_id):
			return _finish(false, &"berth_instance_collision", location_id, load_generation)
		var berth_tombstone: Dictionary = _berth_tombstones.get(berth_id, {})
		if not berth_tombstone.is_empty():
			if StringName(berth_tombstone.location_id) != location_id:
				return _finish(false, &"berth_id_collision", location_id, load_generation)
			if load_generation <= int(berth_tombstone.retirement_generation):
				return _finish(false, &"stale_generation", location_id, load_generation)
			if berth_instance_id == int(berth_tombstone.berth_instance_id):
				return _finish(false, &"retired_berth_instance", location_id, load_generation)
		else:
			new_tracked_berth_ids += 1
		pending_ids[berth_id] = true
		pending_instances[berth_instance_id] = true
		var tags := berth.get_compatibility_tags()
		tags.sort()
		pending.append({
			"location_id": location_id,
			"load_generation": load_generation,
			"root_instance_id": root_instance_id,
			"root": weakref(loaded_root),
			"berth_id": berth_id,
			"berth_instance_id": berth_instance_id,
			"berth_schema_version": ShipBerth.SCHEMA_VERSION,
			"compatibility_tags": tags,
			"berth": weakref(berth),
		})
	if _tracked_berth_count() + new_tracked_berth_ids > MAX_TRACKED_BERTH_IDS:
		return _finish(false, &"tracked_berth_capacity_exceeded", location_id, load_generation)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.berth_id) < str(b.berth_id)
	)

	# Every rejection is above this line. Commit the root and complete roster as
	# one state change before observers receive the detached batch signal.
	var berth_ids: Array[StringName] = []
	for record in pending:
		var berth_id := StringName(record.berth_id)
		berth_ids.append(berth_id)
		_records_by_berth_id[berth_id] = record
		_berth_id_by_instance_id[int(record.berth_instance_id)] = berth_id
	_locations[location_id] = {
		"location_id": location_id,
		"load_generation": load_generation,
		"root_instance_id": root_instance_id,
		"root": weakref(loaded_root),
		"berth_ids": berth_ids,
	}
	var snapshot := _location_snapshot(_locations[location_id] as Dictionary)
	var result := _finish(true, &"registered", location_id, load_generation, -1, {
		"snapshot": snapshot,
	})
	_emit_detached(location_registered, snapshot)
	return result


## Retires the exact current loaded-root provenance as one batch. The caller
## supplies WorldStreamingCoordinator's newer unload generation separately from
## the original load generation; both are retained in the tombstone.
func retire_location(
	location_id: StringName,
	load_generation: int,
	root_instance_id: int,
	retirement_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(
			false, &"reentrant_call", location_id, load_generation, retirement_generation
		)
	_mutation_active = true
	if not _is_stable_id(location_id):
		return _finish(
			false, &"invalid_location_id", location_id, load_generation, retirement_generation
		)
	if not _is_load_generation(load_generation):
		return _finish(
			false, &"invalid_generation", location_id, load_generation, retirement_generation
		)
	if not _is_positive_safe_integer(root_instance_id):
		return _finish(
			false, &"invalid_root_instance_id", location_id, load_generation, retirement_generation
		)
	if not _is_positive_safe_integer(retirement_generation) \
			or retirement_generation != load_generation + 1:
		return _finish(
			false,
			&"retirement_generation_mismatch",
			location_id,
			load_generation,
			retirement_generation
		)
	var coordinator := _get_coordinator()
	if coordinator == null:
		return _finish(
			false, &"coordinator_unavailable", location_id, load_generation,
			retirement_generation
		)
	if coordinator.get_loaded_instance(location_id) != null:
		return _finish(
			false, &"coordinator_location_still_loaded", location_id, load_generation,
			retirement_generation
		)
	var coordinator_generations := coordinator.audit().get("generation_by_id", {}) as Dictionary
	if int(coordinator_generations.get(location_id, -1)) != retirement_generation:
		return _finish(
			false, &"retirement_generation_mismatch", location_id, load_generation,
			retirement_generation
		)

	var location_record: Dictionary = _locations.get(location_id, {})
	if location_record.is_empty():
		var prior: Dictionary = _location_tombstones.get(location_id, {})
		if not prior.is_empty() \
				and int(prior.load_generation) == load_generation \
				and int(prior.root_instance_id) == root_instance_id \
				and int(prior.retirement_generation) == retirement_generation:
			return _finish(
				false, &"already_retired", location_id, load_generation, retirement_generation
			)
		return _finish(
			false, &"unknown_location", location_id, load_generation, retirement_generation
		)
	if load_generation != int(location_record.load_generation):
		return _finish(
			false, &"stale_generation", location_id, load_generation, retirement_generation
		)
	if root_instance_id != int(location_record.root_instance_id):
		return _finish(
			false, &"root_provenance_mismatch", location_id, load_generation,
			retirement_generation
		)

	var retired_berths: Array[Dictionary] = []
	for berth_id_value in location_record.berth_ids as Array:
		var berth_id := StringName(berth_id_value)
		var record := _records_by_berth_id[berth_id] as Dictionary
		var row := _primitive_berth_record(record)
		row["retirement_generation"] = retirement_generation
		retired_berths.append(row)
		_records_by_berth_id.erase(berth_id)
		_berth_id_by_instance_id.erase(int(record.berth_instance_id))
		_berth_tombstones[berth_id] = row.duplicate(true)
	_locations.erase(location_id)
	var tombstone := {
		"schema_version": SCHEMA_VERSION,
		"location_id": location_id,
		"load_generation": load_generation,
		"retirement_generation": retirement_generation,
		"root_instance_id": root_instance_id,
		"berth_count": retired_berths.size(),
		"berths": retired_berths,
	}
	_location_tombstones[location_id] = tombstone.duplicate(true)
	var result := _finish(
		true, &"retired", location_id, load_generation, retirement_generation,
		{"tombstone": tombstone}
	)
	_emit_detached(location_retired, tombstone)
	return result


func has_streamed_berth(berth_id: StringName) -> bool:
	return _records_by_berth_id.has(berth_id)


## The sole live-capability accessor. A consumer must echo the complete
## provenance from lookup_record(); this prevents an old consumer from silently
## acquiring a replacement berth that reused the same stable ID after reload.
## Detached, queued, expired, reparented, drifted, or mismatched records resolve
## to null without altering overlay state.
func resolve_berth_node(
	location_id: StringName,
	load_generation: int,
	root_instance_id: int,
	berth_id: StringName,
	berth_instance_id: int
	) -> ShipBerth:
	var record: Dictionary = _records_by_berth_id.get(berth_id, {})
	if record.is_empty():
		return null
	if StringName(record.location_id) != location_id \
			or int(record.load_generation) != load_generation \
			or int(record.root_instance_id) != root_instance_id \
			or int(record.berth_instance_id) != berth_instance_id:
		return null
	var status := _berth_status(record)
	if not bool(status.available):
		return null
	var reference := record.berth as WeakRef
	return reference.get_ref() as ShipBerth if reference != null else null


func lookup_record(berth_id: StringName) -> Dictionary:
	var record: Dictionary = _records_by_berth_id.get(berth_id, {})
	if record.is_empty():
		return {
			"schema_version": SCHEMA_VERSION,
			"found": false,
			"berth_id": berth_id,
		}.duplicate(true)
	var result := _primitive_berth_record(record)
	result.merge(_berth_status(record), true)
	result["schema_version"] = SCHEMA_VERSION
	result["found"] = true
	return result.duplicate(true)


func lookup_location(location_id: StringName) -> Dictionary:
	var record: Dictionary = _locations.get(location_id, {})
	if record.is_empty():
		return {
			"schema_version": SCHEMA_VERSION,
			"found": false,
			"location_id": location_id,
		}.duplicate(true)
	return _location_snapshot(record)


func get_streamed_berth_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for berth_id_value in _records_by_berth_id.keys():
		ids.append(StringName(berth_id_value))
	ids.sort_custom(_sort_string_names)
	return ids


func get_merged_berth_ids() -> Array[StringName]:
	var ids := _resident_berth_ids.duplicate()
	ids.append_array(get_streamed_berth_ids())
	ids.sort_custom(_sort_string_names)
	return ids


## Primitive-only rows for the later ShipyardWorld merge. Resident rows carry
## identity only because their node lookup remains with that owner.
func get_merged_read_snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	for berth_id in _resident_berth_ids:
		entries.append({
			"berth_id": berth_id,
			"source": &"resident",
			"streamed": false,
		})
	for berth_id in get_streamed_berth_ids():
		var row := lookup_record(berth_id)
		row["source"] = &"streamed"
		row["streamed"] = true
		entries.append(row)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.berth_id) < str(b.berth_id)
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"resident_configured": _configured,
		"berth_ids": get_merged_berth_ids(),
		"entries": entries,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	var locations: Array[Dictionary] = []
	var location_ids: Array[StringName] = []
	for location_id_value in _locations.keys():
		location_ids.append(StringName(location_id_value))
	location_ids.sort_custom(_sort_string_names)
	for location_id in location_ids:
		locations.append(_location_snapshot(_locations[location_id] as Dictionary))
	var location_tombstones := _sorted_dictionary_rows(
		_location_tombstones, &"location_id"
	)
	var berth_tombstones := _sorted_dictionary_rows(_berth_tombstones, &"berth_id")
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"coordinator_instance_id": _coordinator_instance_id,
		"coordinator_valid": _get_coordinator() != null,
		"resident_berth_ids": _resident_berth_ids.duplicate(),
		"merged_berth_ids": get_merged_berth_ids(),
		"active_location_count": locations.size(),
		"active_berth_count": _records_by_berth_id.size(),
		"locations": locations,
		"location_tombstones": location_tombstones,
		"berth_tombstones": berth_tombstones,
		"loaded_observation_count": _loaded_observation_count,
		"unloaded_observation_count": _unloaded_observation_count,
		"last_loaded_observation": _last_loaded_observation.duplicate(true),
		"last_unloaded_observation": _last_unloaded_observation.duplicate(true),
		"limits": {
			"resident_berth_ids": MAX_RESIDENT_BERTH_IDS,
			"active_streamed_berths": MAX_ACTIVE_STREAMED_BERTHS,
			"active_locations": MAX_ACTIVE_LOCATIONS,
			"berths_per_location": MAX_BERTHS_PER_LOCATION,
			"tracked_berth_ids": MAX_TRACKED_BERTH_IDS,
			"tracked_location_ids": MAX_TRACKED_LOCATION_IDS,
			"maximum_safe_integer": MAX_SAFE_INTEGER,
		},
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("not_configured")
	if _configured and _get_coordinator() == null:
		errors.append("coordinator_unavailable")
	if _records_by_berth_id.size() > MAX_ACTIVE_STREAMED_BERTHS:
		errors.append("active_berth_capacity_exceeded")
	if _locations.size() > MAX_ACTIVE_LOCATIONS:
		errors.append("active_location_capacity_exceeded")
	if _tracked_berth_count() > MAX_TRACKED_BERTH_IDS:
		errors.append("tracked_berth_capacity_exceeded")
	if _tracked_location_count() > MAX_TRACKED_LOCATION_IDS:
		errors.append("tracked_location_capacity_exceeded")
	var resident_seen: Dictionary = {}
	for berth_id in _resident_berth_ids:
		if not _is_stable_id(berth_id) or resident_seen.has(berth_id):
			errors.append("resident_roster_invalid")
		resident_seen[berth_id] = true

	for location_id_value in _locations.keys():
		var location_id := StringName(location_id_value)
		var location_record := _locations[location_id] as Dictionary
		if not _location_record_schema_valid(location_record):
			errors.append("location_schema_invalid_%s" % location_id)
			continue
		var root_status := _root_status(location_record)
		if not bool(root_status.root_valid):
			errors.append("root_expired_%s" % location_id)
		elif bool(root_status.root_queued_for_deletion):
			errors.append("root_queued_%s" % location_id)
		elif not bool(root_status.root_provenance_current):
			errors.append("root_provenance_drift_%s" % location_id)
		elif not bool(root_status.root_coordinator_owned):
			errors.append("root_ownership_drift_%s" % location_id)
		for berth_id_value in location_record.berth_ids as Array:
			var berth_id := StringName(berth_id_value)
			var record: Dictionary = _records_by_berth_id.get(berth_id, {})
			if record.is_empty() or StringName(record.location_id) != location_id:
				errors.append("location_index_mismatch_%s_%s" % [location_id, berth_id])
				continue
			var status := _berth_status(record)
			if not bool(status.berth_valid):
				errors.append("berth_expired_or_drifted_%s" % berth_id)
			elif bool(status.berth_queued_for_deletion):
				errors.append("berth_queued_%s" % berth_id)
			elif not bool(status.berth_contract_current):
				errors.append("berth_contract_drift_%s" % berth_id)
			elif not bool(status.ancestry_current):
				errors.append("berth_ancestry_drift_%s" % berth_id)
			if _resident_berth_id_set.has(berth_id):
				errors.append("resident_collision_%s" % berth_id)
			if _berth_id_by_instance_id.get(int(record.berth_instance_id), &"") != berth_id:
				errors.append("berth_instance_index_mismatch_%s" % berth_id)
	for berth_id_value in _records_by_berth_id.keys():
		var berth_id := StringName(berth_id_value)
		var record := _records_by_berth_id[berth_id] as Dictionary
		if not _berth_record_schema_valid(record) or StringName(record.berth_id) != berth_id:
			errors.append("berth_schema_invalid_%s" % berth_id)
		elif not _locations.has(StringName(record.location_id)):
			errors.append("orphaned_berth_record_%s" % berth_id)
	for instance_id_value in _berth_id_by_instance_id.keys():
		var instance_id := int(instance_id_value)
		var berth_id := StringName(_berth_id_by_instance_id[instance_id])
		var record: Dictionary = _records_by_berth_id.get(berth_id, {})
		if record.is_empty() or int(record.berth_instance_id) != instance_id:
			errors.append("orphaned_instance_index_%d" % instance_id)
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func _on_coordinator_location_loaded(
	location_id: StringName,
	load_generation: int,
	loaded_root: Node3D
	) -> void:
	_loaded_observation_count += 1
	_last_loaded_observation = register_loaded_root(
		location_id,
		load_generation,
		loaded_root.get_instance_id() if is_instance_valid(loaded_root) else 0,
		loaded_root
	).duplicate(true)


func _on_coordinator_location_unloaded(
	location_id: StringName,
	retirement_generation: int
	) -> void:
	_unloaded_observation_count += 1
	var record: Dictionary = _locations.get(location_id, {})
	if record.is_empty():
		_last_unloaded_observation = _result(
			false,
			&"unknown_location",
			location_id,
			retirement_generation - 1,
			retirement_generation
		)
		return
	_last_unloaded_observation = retire_location(
		location_id,
		int(record.load_generation),
		int(record.root_instance_id),
		retirement_generation
	).duplicate(true)


func _location_snapshot(record: Dictionary) -> Dictionary:
	var berths: Array[Dictionary] = []
	for berth_id_value in record.berth_ids as Array:
		var berth_id := StringName(berth_id_value)
		berths.append(lookup_record(berth_id))
	var root_status := _root_status(record)
	var identity_current := bool(root_status.root_valid) \
		and bool(root_status.root_provenance_current) \
		and bool(root_status.root_coordinator_owned)
	var available := identity_current and bool(root_status.root_inside_tree) \
		and not bool(root_status.root_queued_for_deletion)
	for berth in berths:
		identity_current = identity_current and bool(berth.identity_current)
		available = available and bool(berth.available)
	return {
		"schema_version": SCHEMA_VERSION,
		"found": true,
		"location_id": StringName(record.location_id),
		"load_generation": int(record.load_generation),
		"root_instance_id": int(record.root_instance_id),
		"root_valid": bool(root_status.root_valid),
		"root_inside_tree": bool(root_status.root_inside_tree),
		"root_queued_for_deletion": bool(root_status.root_queued_for_deletion),
		"root_provenance_current": bool(root_status.root_provenance_current),
		"root_coordinator_owned": bool(root_status.root_coordinator_owned),
		"berth_count": berths.size(),
		"berths": berths,
		"identity_current": identity_current,
		"available": available,
	}.duplicate(true)


func _primitive_berth_record(record: Dictionary) -> Dictionary:
	return {
		"location_id": StringName(record.location_id),
		"load_generation": int(record.load_generation),
		"root_instance_id": int(record.root_instance_id),
		"berth_id": StringName(record.berth_id),
		"berth_instance_id": int(record.berth_instance_id),
		"berth_schema_version": int(record.berth_schema_version),
		"compatibility_tags": (record.compatibility_tags as PackedStringArray).duplicate(),
	}


func _root_status(record: Dictionary) -> Dictionary:
	var reference := record.get("root") as WeakRef
	var candidate: Variant = reference.get_ref() if reference != null else null
	var root_valid: bool = candidate != null and is_instance_valid(candidate) \
		and candidate is Node3D \
		and candidate.get_instance_id() == int(record.root_instance_id)
	var root: Node3D = candidate as Node3D if root_valid else null
	var coordinator: WorldStreamingCoordinator = _get_coordinator()
	return {
		"root_valid": root_valid,
		"root_inside_tree": root.is_inside_tree() if root_valid else false,
		"root_queued_for_deletion": root.is_queued_for_deletion() if root_valid else false,
		"root_provenance_current": root_valid and _root_metadata_matches(
			root, StringName(record.location_id), int(record.load_generation)
		),
		"root_coordinator_owned": root_valid and coordinator != null \
			and root.get_parent() == coordinator,
	}


func _berth_status(record: Dictionary) -> Dictionary:
	var berth_reference := record.get("berth") as WeakRef
	var berth_candidate: Variant = (
		berth_reference.get_ref() if berth_reference != null else null
	)
	var berth_valid: bool = berth_candidate != null and is_instance_valid(berth_candidate) \
		and berth_candidate is ShipBerth \
		and berth_candidate.get_instance_id() == int(record.berth_instance_id) \
		and berth_candidate.get_berth_id() == StringName(record.berth_id)
	var berth: ShipBerth = berth_candidate as ShipBerth if berth_valid else null
	var root_reference := record.get("root") as WeakRef
	var root_candidate: Variant = root_reference.get_ref() if root_reference != null else null
	var root_valid: bool = root_candidate != null and is_instance_valid(root_candidate) \
		and root_candidate is Node3D \
		and root_candidate.get_instance_id() == int(record.root_instance_id)
	var loaded_root: Node3D = root_candidate as Node3D if root_valid else null
	var ancestry_current: bool = berth_valid and root_valid \
		and loaded_root.is_ancestor_of(berth)
	var root_provenance_current: bool = root_valid and _root_metadata_matches(
		loaded_root, StringName(record.location_id), int(record.load_generation)
	)
	var coordinator: WorldStreamingCoordinator = _get_coordinator()
	var root_coordinator_owned: bool = root_valid and coordinator != null \
		and loaded_root.get_parent() == coordinator
	var current_tags := PackedStringArray()
	if berth_valid:
		current_tags = berth.get_compatibility_tags()
		current_tags.sort()
	var berth_contract_current: bool = berth_valid \
		and berth.get_validation_errors().is_empty() \
		and int(record.berth_schema_version) == ShipBerth.SCHEMA_VERSION \
		and current_tags == (record.compatibility_tags as PackedStringArray)
	var identity_current: bool = berth_valid and root_valid \
		and berth_contract_current and ancestry_current \
		and root_provenance_current and root_coordinator_owned
	return {
		"berth_valid": berth_valid,
		"berth_inside_tree": berth.is_inside_tree() if berth_valid else false,
		"berth_queued_for_deletion": berth.is_queued_for_deletion() if berth_valid else false,
		"berth_contract_current": berth_contract_current,
		"root_valid": root_valid,
		"root_inside_tree": loaded_root.is_inside_tree() if root_valid else false,
		"root_queued_for_deletion": loaded_root.is_queued_for_deletion() if root_valid else false,
		"root_provenance_current": root_provenance_current,
		"root_coordinator_owned": root_coordinator_owned,
		"ancestry_current": ancestry_current,
		"identity_current": identity_current,
		"available": identity_current \
			and berth.is_inside_tree() and loaded_root.is_inside_tree() \
			and not berth.is_queued_for_deletion() \
			and not loaded_root.is_queued_for_deletion(),
	}


func _registration_primitive_error(
	location_id: StringName,
	load_generation: int,
	root_instance_id: int
	) -> StringName:
	if not _is_stable_id(location_id):
		return &"invalid_location_id"
	if not _is_load_generation(load_generation):
		return &"invalid_generation"
	if not _is_positive_safe_integer(root_instance_id):
		return &"invalid_root_instance_id"
	return &""


func _loaded_root_error(
	loaded_root: Node3D,
	location_id: StringName,
	load_generation: int,
	root_instance_id: int
	) -> StringName:
	if loaded_root == null or not is_instance_valid(loaded_root):
		return &"invalid_root"
	if loaded_root.get_instance_id() != root_instance_id:
		return &"root_provenance_mismatch"
	if loaded_root.is_queued_for_deletion() or not loaded_root.is_inside_tree():
		return &"invalid_root"
	if not _root_metadata_matches(loaded_root, location_id, load_generation):
		return &"root_provenance_mismatch"
	return &""


func _root_metadata_matches(
	loaded_root: Node3D,
	location_id: StringName,
	load_generation: int
	) -> bool:
	var metadata_location: Variant = loaded_root.get_meta(&"world_location_id", null)
	var metadata_generation: Variant = loaded_root.get_meta(
		&"world_location_generation", null
	)
	return typeof(metadata_location) == TYPE_STRING_NAME \
		and metadata_location == location_id \
		and typeof(metadata_generation) == TYPE_INT \
		and int(metadata_generation) == load_generation


func _location_record_schema_valid(record: Dictionary) -> bool:
	return _is_stable_id(record.get("location_id", &"")) \
		and _is_load_generation(record.get("load_generation", 0)) \
		and _is_positive_safe_integer(record.get("root_instance_id", 0)) \
		and record.get("root") is WeakRef \
		and record.get("berth_ids") is Array \
		and not (record.berth_ids as Array).is_empty() \
		and (record.berth_ids as Array).size() <= MAX_BERTHS_PER_LOCATION


func _berth_record_schema_valid(record: Dictionary) -> bool:
	return _is_stable_id(record.get("location_id", &"")) \
		and _is_load_generation(record.get("load_generation", 0)) \
		and _is_positive_safe_integer(record.get("root_instance_id", 0)) \
		and _is_stable_id(record.get("berth_id", &"")) \
		and _is_positive_safe_integer(record.get("berth_instance_id", 0)) \
		and int(record.get("berth_schema_version", 0)) == ShipBerth.SCHEMA_VERSION \
		and record.get("compatibility_tags") is PackedStringArray \
		and record.get("root") is WeakRef \
		and record.get("berth") is WeakRef


func _tracked_location_has_capacity(location_id: StringName) -> bool:
	return _location_tombstones.has(location_id) \
		or _locations.has(location_id) \
		or _tracked_location_count() < MAX_TRACKED_LOCATION_IDS


func _tracked_location_count() -> int:
	var ids: Dictionary = {}
	for location_id in _location_tombstones.keys():
		ids[location_id] = true
	for location_id in _locations.keys():
		ids[location_id] = true
	return ids.size()


func _tracked_berth_count() -> int:
	var ids: Dictionary = {}
	for berth_id in _berth_tombstones.keys():
		ids[berth_id] = true
	for berth_id in _records_by_berth_id.keys():
		ids[berth_id] = true
	return ids.size()


func _sorted_dictionary_rows(source: Dictionary, id_key: StringName) -> Array[Dictionary]:
	var ids: Array[StringName] = []
	for id_value in source.keys():
		ids.append(StringName(id_value))
	ids.sort_custom(_sort_string_names)
	var rows: Array[Dictionary] = []
	for stable_id in ids:
		var row := (source[stable_id] as Dictionary).duplicate(true)
		if not row.has(id_key):
			row[id_key] = stable_id
		rows.append(row)
	return rows


func _get_coordinator() -> WorldStreamingCoordinator:
	if _coordinator == null:
		return null
	var candidate: Variant = _coordinator.get_ref()
	if candidate == null or not is_instance_valid(candidate) \
			or candidate is not WorldStreamingCoordinator \
			or candidate.get_instance_id() != _coordinator_instance_id \
			or candidate.is_queued_for_deletion():
		return null
	return candidate as WorldStreamingCoordinator


func _emit_detached(target_signal: Signal, payload: Dictionary) -> void:
	var previous_dispatch := _signal_dispatch_active
	_signal_dispatch_active = true
	target_signal.emit(payload.duplicate(true))
	_signal_dispatch_active = previous_dispatch


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


func _finish(
	accepted: bool,
	reason: StringName,
	location_id: StringName = &"",
	load_generation: int = -1,
	retirement_generation: int = -1,
	fields: Dictionary = {}
	) -> Dictionary:
	_mutation_active = false
	return _result(
		accepted, reason, location_id, load_generation, retirement_generation, fields
	)


func _result(
	accepted: bool,
	reason: StringName,
	location_id: StringName = &"",
	load_generation: int = -1,
	retirement_generation: int = -1,
	fields: Dictionary = {}
	) -> Dictionary:
	var result := fields.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	result["location_id"] = location_id
	result["load_generation"] = load_generation
	result["retirement_generation"] = retirement_generation
	return result


static func _sort_string_names(a: StringName, b: StringName) -> bool:
	return str(a) < str(b)


static func _is_positive_safe_integer(value: Variant) -> bool:
	return value is int and int(value) > 0 and int(value) <= MAX_SAFE_INTEGER


static func _is_load_generation(value: Variant) -> bool:
	# A registered load must leave one strictly newer bounded generation for its
	# eventual coordinator retirement signal.
	return value is int and int(value) > 0 and int(value) < MAX_SAFE_INTEGER


static func _is_stable_id(value: Variant) -> bool:
	if value is not String and value is not StringName:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 64 \
			or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lower and not digit and code != 95:
			return false
	return true
