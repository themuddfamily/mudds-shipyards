class_name StationDefenseEncounterContent
extends Node3D

## Checked-in production composition for one bounded station-defense encounter.
##
## This node discovers only its authored children, validates their stable handle
## metadata and physical staging volumes, then registers the pre-created
## RangeOpponent roster with StationDefenseEncounterHost. All runtime authority
## remains in the existing activity, opponent, lifecycle adapter, and resolver.

signal snapshot_changed(snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"shipyard_perimeter_defense_content"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_AUTHORED_NODE_COUNT := 24
const MIN_KEEP_CLEAR_RADIUS := 8.0
const MIN_KEEP_CLEAR_GAP := 4.0

const _AUTHORITY_EXCLUSIONS := {
	"activity_progression": false,
	"combat_resolution": false,
	"health": false,
	"damage": false,
	"rewards": false,
	"runtime_scene_instantiation": false,
	"protected_asset_lifecycle": false,
	"ships": false,
	"berths": false,
	"world_geometry": false,
	"hud": false,
	"game_flow": false,
	"main": false,
	"save": false,
	"network": false,
}

@export var contract_definition: StationDefenseEncounterDefinition

var _initialized := false
var _initialization_errors := PackedStringArray()
var _host: StationDefenseEncounterHost
var _combat_authority: LiveCombatAuthority
var _spawn_staging: Node3D
var _opponent_roster: Node3D
var _entity_by_key: Dictionary = {}
var _staging_by_key: Dictionary = {}


func _ready() -> void:
	_initialize_checked_in_content()


func is_content_ready() -> bool:
	return _initialized


func get_host() -> StationDefenseEncounterHost:
	return _host if is_instance_valid(_host) else null


func get_combat_authority() -> LiveCombatAuthority:
	return _combat_authority if is_instance_valid(_combat_authority) else null


func get_generation() -> int:
	return _host.get_generation() if is_instance_valid(_host) else 0


func start(expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.start(expected_generation)


## Delegates caller-owned physics time; this content has no process callback or
## wall-clock gameplay authority.
func advance_physics(delta: float, expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.advance_physics(delta, expected_generation)


func protected_asset_damaged(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.protected_asset_damaged(asset_handle, event_handle, expected_generation)


func protected_asset_destroyed(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.protected_asset_destroyed(asset_handle, event_handle, expected_generation)


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.fail(reason, expected_generation)


func abort(expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.abort(expected_generation)


func reset(expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.reset(expected_generation)


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_encounter": false,
		"authenticated_spawn_geometry": false,
		"claims_historical_wave_plan": false,
		"modern_interpretations": PackedStringArray([
			"the station-defense encounter itself",
			"all hostile spawn transforms and keep-clear volumes",
			"the wave grouping, ordering, delay, and timeout",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical Keth Shipyards defense encounter or spawn arrangement",
		]),
		"content_note": (
			contract_definition.content_note
			if contract_definition != null
			else "Encounter definition unavailable."
		),
	}.duplicate(true)


## HUD-safe primitive snapshot. Node and Resource references never escape.
func get_snapshot() -> Dictionary:
	var host_snapshot := (
		_host.get_snapshot()
		if is_instance_valid(_host)
		else {
			"configured": false,
			"activity": {"state_id": "idle", "generation": 0},
			"spawn_roster": [],
		}
	)
	var contract_snapshot := (
		contract_definition.instantiate_contract().get_snapshot()
		if contract_definition != null
		else {}
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"content_ready": _initialized,
		"initialization_errors": _initialization_errors.duplicate(),
		"contract": contract_snapshot,
		"host": host_snapshot,
		"staging": _get_staging_snapshot(),
		"opponent_count": _entity_by_key.size(),
		"authored_node_count": _count_authored_nodes(self),
		"precreated_roster_wired": (
			_initialized
			and int(host_snapshot.get("spawn_roster_count", 0)) == _entity_by_key.size()
		),
		"uses_caller_physics_delta": true,
		"evidence": get_evidence_metadata(),
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := _collect_composition_errors(false)
	for initialization_error in _initialization_errors:
		_append_unique(errors, initialization_error)
	if not _initialized:
		_append_unique(errors, "checked-in encounter content is not initialized")
	if is_instance_valid(_host):
		var host_audit := _host.audit()
		if not bool(host_audit.get("valid", false)):
			for host_error in host_audit.get("errors", PackedStringArray()):
				_append_unique(errors, "host: %s" % host_error)
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"limits": {
			"maximum_authored_node_count": MAX_AUTHORED_NODE_COUNT,
			"maximum_content_hostiles": StationDefenseEncounterDefinition.MAX_CONTENT_HOSTILES,
			"minimum_keep_clear_radius": MIN_KEEP_CLEAR_RADIUS,
			"minimum_keep_clear_gap": MIN_KEEP_CLEAR_GAP,
		},
		"evidence": get_evidence_metadata(),
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func _initialize_checked_in_content() -> void:
	if _initialized or not _initialization_errors.is_empty():
		return
	_resolve_authored_nodes()
	_initialization_errors = _collect_composition_errors(true)
	if not _initialization_errors.is_empty():
		_publish_snapshot()
		return

	var contract := contract_definition.instantiate_contract()
	var configured := _host.configure(contract, _combat_authority)
	if not bool(configured.get("accepted", false)):
		_initialization_errors.append(
			"host configuration failed: %s" % String(configured.get("reason", &"unknown"))
		)
		_publish_snapshot()
		return
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var staging := _staging_by_key.get(key, {}) as Dictionary
		var marker := staging.get("marker") as Marker3D
		var registered := _host.register_hostile(
			handle,
			entity,
			marker.global_transform,
			contract_definition.hostile_faction_id
		)
		if not bool(registered.get("accepted", false)):
			_initialization_errors.append(
				"hostile %s registration failed: %s" % [
					key, String(registered.get("reason", &"unknown")),
				]
			)
	if not _initialization_errors.is_empty():
		_initialization_errors.sort()
		_publish_snapshot()
		return
	if not _host.snapshot_changed.is_connected(_on_host_snapshot_changed):
		_host.snapshot_changed.connect(_on_host_snapshot_changed)
	_initialized = true
	_publish_snapshot()


func _resolve_authored_nodes() -> void:
	_host = get_node_or_null(^"Host") as StationDefenseEncounterHost
	_combat_authority = get_node_or_null(^"CombatAuthority") as LiveCombatAuthority
	_spawn_staging = get_node_or_null(^"SpawnStaging") as Node3D
	_opponent_roster = get_node_or_null(^"OpponentRoster") as Node3D


func _collect_composition_errors(rebuild_lookups: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	if contract_definition == null:
		errors.append("contract definition is required")
	else:
		for definition_error in contract_definition.get_validation_errors():
			_append_unique(errors, "definition: %s" % definition_error)
	if not is_instance_valid(_host):
		errors.append("Host must be a StationDefenseEncounterHost")
	if not is_instance_valid(_combat_authority):
		errors.append("CombatAuthority must be a LiveCombatAuthority")
	if not is_instance_valid(_spawn_staging):
		errors.append("SpawnStaging must be a Node3D")
	if not is_instance_valid(_opponent_roster):
		errors.append("OpponentRoster must be a Node3D")
	var authored_count := _count_authored_nodes(self)
	if authored_count > MAX_AUTHORED_NODE_COUNT:
		errors.append("authored node count exceeds the checked-in content bound")
	if contract_definition == null \
		or not is_instance_valid(_spawn_staging) \
		or not is_instance_valid(_opponent_roster):
		errors.sort()
		return errors
	if rebuild_lookups:
		_entity_by_key.clear()
		_staging_by_key.clear()
		_collect_entities(errors)
		_collect_staging(errors)
	_validate_lookup_coverage(errors)
	_validate_keep_clear_separation(errors)
	errors.sort()
	return errors


func _collect_entities(errors: PackedStringArray) -> void:
	for child in _opponent_roster.get_children():
		var entity := child as RangeOpponent
		if entity == null:
			errors.append("OpponentRoster may contain only RangeOpponent instances")
			continue
		var handle := _metadata_handle(entity)
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		if not _handle_metadata_valid(handle):
			errors.append("opponent %s has invalid stable handle metadata" % entity.name)
		elif _entity_by_key.has(key):
			errors.append("duplicate opponent handle metadata: %s" % key)
		else:
			_entity_by_key[key] = entity
		if entity.is_active():
			errors.append("opponent %s must be dormant before host registration" % entity.name)


func _collect_staging(errors: PackedStringArray) -> void:
	for child in _spawn_staging.get_children():
		var marker := child as Marker3D
		if marker == null:
			errors.append("SpawnStaging may contain only Marker3D children")
			continue
		var handle := _metadata_handle(marker)
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		if not _handle_metadata_valid(handle):
			errors.append("spawn marker %s has invalid stable handle metadata" % marker.name)
			continue
		if _staging_by_key.has(key):
			errors.append("duplicate spawn marker handle metadata: %s" % key)
			continue
		var area := marker.get_node_or_null(^"KeepClearVolume") as Area3D
		var collision := (
			area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
			if area != null
			else null
		)
		var sphere := collision.shape as SphereShape3D if collision != null else null
		if area == null or collision == null or sphere == null:
			errors.append("spawn marker %s requires one spherical keep-clear volume" % marker.name)
			continue
		if area.position != Vector3.ZERO or collision.position != Vector3.ZERO:
			errors.append("spawn marker %s keep-clear volume must be marker-centered" % marker.name)
		if area.collision_layer != 0 or area.collision_mask != 0 \
			or area.monitoring or area.monitorable:
			errors.append("spawn marker %s keep-clear volume must be query-inert" % marker.name)
		var radius := _world_sphere_radius(collision, sphere)
		if not is_finite(radius) or radius < MIN_KEEP_CLEAR_RADIUS:
			errors.append("spawn marker %s keep-clear radius is below its bound" % marker.name)
		if not _transform_is_finite_and_nondegenerate(marker.global_transform):
			errors.append("spawn marker %s transform is invalid" % marker.name)
		_staging_by_key[key] = {
			"marker": marker,
			"area": area,
			"collision": collision,
			"radius": radius,
			"world_position": collision.global_position,
		}


func _validate_lookup_coverage(errors: PackedStringArray) -> void:
	var expected_keys: Dictionary = {}
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		expected_keys[key] = true
		if not _entity_by_key.has(key):
			errors.append("contract hostile lacks a pre-created opponent: %s" % key)
		if not _staging_by_key.has(key):
			errors.append("contract hostile lacks a physical spawn marker: %s" % key)
	for key in _entity_by_key:
		if not expected_keys.has(key):
			errors.append("pre-created opponent is outside the contract: %s" % key)
	for key in _staging_by_key:
		if not expected_keys.has(key):
			errors.append("spawn marker is outside the contract: %s" % key)
	if _entity_by_key.size() > StationDefenseEncounterDefinition.MAX_CONTENT_HOSTILES:
		errors.append("pre-created opponent roster exceeds the content bound")


func _validate_keep_clear_separation(errors: PackedStringArray) -> void:
	var ordered := contract_definition.get_ordered_hostile_handles()
	for left_index in ordered.size():
		var left_key := StationDefenseContract.handle_key(ordered[left_index], "hostile_id")
		var left := _staging_by_key.get(left_key, {}) as Dictionary
		if left.is_empty():
			continue
		var left_position := _staging_world_position(left)
		for right_index in range(left_index + 1, ordered.size()):
			var right_key := StationDefenseContract.handle_key(ordered[right_index], "hostile_id")
			var right := _staging_by_key.get(right_key, {}) as Dictionary
			if right.is_empty():
				continue
			var right_position := _staging_world_position(right)
			var required := float(left.radius) + float(right.radius) + MIN_KEEP_CLEAR_GAP
			if left_position.distance_to(right_position) < required:
				errors.append("spawn keep-clear volumes overlap: %s / %s" % [left_key, right_key])


func _get_staging_snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if contract_definition == null:
		return rows
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var staging := _staging_by_key.get(key, {}) as Dictionary
		var marker := staging.get("marker") as Marker3D
		var world_position := _staging_world_position(staging)
		if is_instance_valid(marker) and marker.is_inside_tree():
			staging["world_position"] = world_position
		rows.append({
			"hostile_id": handle.hostile_id,
			"generation": int(handle.generation),
			"marker_name": String(marker.name) if is_instance_valid(marker) else "",
			"local_position": marker.position if is_instance_valid(marker) else Vector3.INF,
			"world_position": world_position,
			"keep_clear_radius": float(staging.get("radius", 0.0)),
			"query_inert": (
				is_instance_valid(staging.get("area"))
				and int((staging.area as Area3D).collision_layer) == 0
				and int((staging.area as Area3D).collision_mask) == 0
			),
		})
	return rows


func _on_host_snapshot_changed(_host_snapshot: Dictionary) -> void:
	_publish_snapshot()


func _publish_snapshot() -> void:
	snapshot_changed.emit(get_snapshot())


func _content_result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


func _count_authored_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += 1
		if child is RangeOpponent:
			continue
		count += _count_authored_descendants(child)
	return count


func _count_authored_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1
		if child is RangeOpponent:
			continue
		count += _count_authored_descendants(child)
	return count


static func _metadata_handle(node: Node) -> Dictionary:
	return {
		"hostile_id": StringName(node.get_meta("hostile_id", &"")),
		"generation": int(node.get_meta("handle_generation", 0)),
	}


static func _handle_metadata_valid(handle: Dictionary) -> bool:
	return StationDefenseContract.is_stable_id(handle.get("hostile_id", &"")) \
		and int(handle.get("generation", 0)) > 0 \
		and int(handle.get("generation", 0)) <= StationDefenseContract.MAX_SAFE_INTEGER


static func _world_sphere_radius(
	collision: CollisionShape3D,
	sphere: SphereShape3D
	) -> float:
	var scale := collision.global_basis.get_scale().abs()
	return sphere.radius * maxf(scale.x, maxf(scale.y, scale.z))


static func _staging_world_position(staging: Dictionary) -> Vector3:
	var collision := staging.get("collision") as CollisionShape3D
	if is_instance_valid(collision) and collision.is_inside_tree():
		return collision.global_position
	return staging.get("world_position", Vector3.INF) as Vector3


static func _transform_is_finite_and_nondegenerate(value: Transform3D) -> bool:
	return value.origin.is_finite() \
		and value.basis.x.is_finite() \
		and value.basis.y.is_finite() \
		and value.basis.z.is_finite() \
		and is_finite(value.basis.determinant()) \
		and absf(value.basis.determinant()) > 0.000001


static func _append_unique(errors: PackedStringArray, message: String) -> void:
	if message not in errors:
		errors.append(message)
