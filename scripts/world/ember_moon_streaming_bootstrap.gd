class_name EmberMoonStreamingBootstrap
extends Node3D

## Explicit, opt-in Ember Moon orbital placement and streaming composition.
##
## A host submits absolute focus coordinates and owns every rebase decision and
## node translation. This component only configures the immutable datum/frame,
## registers Ember with one private coordinator, and requests its fixed
## load/unload lifecycle. It has no automatic engine callback.

const SCHEMA_VERSION := 1
const LOCATION_ID: StringName = &"ember_moon"
const WORLD_ID: StringName = &"ember_moon"
const BODY_ID: StringName = &"ember_body"
const LOAD_RADIUS_METERS := 250_000.0
const UNLOAD_RADIUS_METERS := 300_000.0
const MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS := 300_000.0
const BODY_RADIUS_METERS := 120_000.0
const ORIGIN_SHIFT_THRESHOLD_METERS := 10_000.0
const MAX_OBSERVATION_SPEED_METERS_PER_SECOND := 100_000.0
const INITIAL_BODY_CENTER_WORLD_POSITION := Vector3(0.0, 0.0, -8_000_000.0)

const LOCATION_RESOURCE_PATH := "res://assets/world/locations/ember_moon.tres"
const SCENE_RESOURCE_PATH := "res://scenes/world/planets/ember_moon.tscn"
const _LOCATION_DEFINITION := preload(LOCATION_RESOURCE_PATH)
const _LOCATION_SCENE := preload(SCENE_RESOURCE_PATH)

const OWNED_CAPABILITY_KEYS := [
	"absolute_orbital_datum",
	"coordinate_frame_configuration",
	"absolute_focus_evaluation",
	"location_registration",
	"streaming_requests",
	"travel_observation_encoding",
]
const ADJACENT_AUTHORITY_KEYS := [
	"automatic_process",
	"rebase_decision",
	"rebase_application",
	"ship_movement",
	"player_movement",
	"game_flow",
	"travel_session_mutation",
	"landing_decision",
	"world_generation",
	"terrain_generation",
	"collision_generation",
	"save",
	"network",
	"space_backdrop",
	"cinder_streaming",
]

var _registry := NearbySectorOrbitalRegistry.new()
var _coordinate_frame := PlanetaryCoordinateFrame.new()
var _coordinator: WorldStreamingCoordinator
var _configured := false
var _configuration_error: StringName = &""
var _update_active := false
var _update_count := 0
var _load_attempt_count := 0
var _unload_attempt_count := 0
var _last_update_result: Dictionary = {}


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	position = INITIAL_BODY_CENTER_WORLD_POSITION
	_coordinator = WorldStreamingCoordinator.new()
	_coordinator.name = "WorldStreamingCoordinator"
	add_child(_coordinator)
	_configure_checked_contract()


## Returns the exact immutable-config frame instance required by
## PlanetaryTravelSession's identity binding. The caller may use its explicit
## rebase API, but this bootstrap never requests, commits, or applies a rebase.
func get_coordinate_frame_for_session() -> PlanetaryCoordinateFrame:
	return _coordinate_frame if _configured else null


func get_registry_snapshot() -> Dictionary:
	return _registry.get_snapshot()


func get_loaded_instance() -> Node3D:
	return _coordinator.get_loaded_instance(LOCATION_ID) \
		if _configured and is_instance_valid(_coordinator) else null


## Test/integration seam matching WorldStreamingCoordinator. Replacement is
## allowed only before the first load attempt.
func set_scene_loader(loader: Callable) -> bool:
	if _update_active or not _configured or not is_instance_valid(_coordinator):
		return false
	if int(_coordinator.audit().get("load_request_count", -1)) != 0:
		return false
	return _coordinator.set_loader(loader)


## Evaluates one canonical absolute focus. Distance is radial from Ember's body
## centre. Loading also requires the body centre to be within the bounded local
## streaming envelope, forcing a caller-owned rebase before the 8,000 km scene
## can become resident.
func update_absolute_focus(
		orbital_coordinate: Dictionary,
		expected_coordinate_frame_generation: int
	) -> Dictionary:
	if _update_active:
		return _update_result(false, &"update_in_progress")
	_update_active = true
	if not _configured or not is_instance_valid(_coordinator):
		return _finish_update(false, &"bootstrap_not_configured")
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return _finish_update(false, &"rebase_pending")
	var body_world_result := _body_center_world_position(
		expected_coordinate_frame_generation
	)
	if not bool(body_world_result.get("accepted", false)):
		return _finish_update(
			false, body_world_result.get("reason", &"body_center_out_of_bounds")
		)
	if transform.basis != Basis.IDENTITY or not position.is_equal_approx(
		body_world_result.get("position", Vector3.INF) as Vector3
	):
		return _finish_update(false, &"root_alignment_mismatch")
	var body_result := _coordinate_frame.orbital_to_body_local_position(
		orbital_coordinate, expected_coordinate_frame_generation
	)
	if not bool(body_result.get("accepted", false)):
		return _finish_update(false, body_result.get("reason", &"invalid_focus_coordinate"))
	var body_local := body_result.get("position", Vector3.INF) as Vector3
	var radial_distance := body_local.length()
	if not body_local.is_finite() or not is_finite(radial_distance):
		return _finish_update(false, &"focus_out_of_bounds")
	var body_world := body_world_result.get("position", Vector3.INF) as Vector3
	var body_center_distance := body_world.length()
	if not is_finite(body_center_distance):
		return _finish_update(false, &"body_center_out_of_bounds")

	var loaded := get_loaded_instance() != null
	var loading := _coordinator.get_loading_ids().has(str(LOCATION_ID))
	if loaded or loading:
		if radial_distance > UNLOAD_RADIUS_METERS \
				or body_center_distance > MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS:
			_unload_attempt_count += 1
			var unload := _coordinator.request_unload(LOCATION_ID)
			return _finish_transition(
				unload, &"unload", radial_distance, body_center_distance,
				expected_coordinate_frame_generation
			)
		return _finish_update(true, &"within_unload_hysteresis", {
			"action": &"none",
			"radial_distance_meters": radial_distance,
			"body_center_world_distance_meters": body_center_distance,
			"coordinate_frame_generation": expected_coordinate_frame_generation,
			"location_generation": _current_location_generation(),
		})

	if radial_distance <= LOAD_RADIUS_METERS:
		if body_center_distance > MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS:
			return _finish_update(false, &"rebase_required_before_load", {
				"action": &"none",
				"radial_distance_meters": radial_distance,
				"body_center_world_distance_meters": body_center_distance,
				"coordinate_frame_generation": expected_coordinate_frame_generation,
				"location_generation": _current_location_generation(),
			})
		_load_attempt_count += 1
		var load := _coordinator.request_load(LOCATION_ID)
		return _finish_transition(
			load, &"load", radial_distance, body_center_distance,
			expected_coordinate_frame_generation
		)
	return _finish_update(true, &"outside_load_radius", {
		"action": &"none",
		"radial_distance_meters": radial_distance,
		"body_center_world_distance_meters": body_center_distance,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"location_generation": _current_location_generation(),
	})


## Produces a detached, exact-current-generation envelope suitable for a caller
## to pass into PlanetaryTravelSession. The session itself is never retained or
## mutated here.
func create_travel_observation(
		world_streaming_position: Vector3,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_location_generation: int
	) -> Dictionary:
	if _update_active:
		return _observation_result(false, &"update_in_progress")
	if not _configured or not is_instance_valid(_coordinator):
		return _observation_result(false, &"bootstrap_not_configured")
	if not is_finite(speed_meters_per_second) or speed_meters_per_second < 0.0:
		return _observation_result(false, &"invalid_observation_speed")
	if speed_meters_per_second > MAX_OBSERVATION_SPEED_METERS_PER_SECOND:
		return _observation_result(false, &"observation_speed_out_of_bounds")
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return _observation_result(false, &"rebase_pending")
	var body_world_result := _body_center_world_position(
		expected_coordinate_frame_generation
	)
	if not bool(body_world_result.get("accepted", false)):
		return _observation_result(
			false, body_world_result.get("reason", &"body_center_out_of_bounds")
		)
	if transform.basis != Basis.IDENTITY or not position.is_equal_approx(
		body_world_result.get("position", Vector3.INF) as Vector3
	):
		return _observation_result(false, &"root_alignment_mismatch")
	var instance := get_loaded_instance()
	var current_location_generation := _current_location_generation()
	if not is_instance_valid(instance):
		return _observation_result(false, &"ember_not_loaded")
	if expected_location_generation != current_location_generation \
			or int(instance.get_meta(&"world_location_generation", -1)) \
			!= expected_location_generation:
		return _observation_result(false, &"stale_location_generation")
	var decoded := _coordinate_frame.decode_world_streaming_position(
		world_streaming_position, expected_coordinate_frame_generation
	)
	if not bool(decoded.get("accepted", false)):
		return _observation_result(
			false, decoded.get("reason", &"invalid_world_streaming_position")
		)
	var coordinate_record := decoded.get("coordinate", {}) as Dictionary
	return _observation_result(true, &"current_generation_observation", {
		"world_id": WORLD_ID,
		"body_id": BODY_ID,
		"location_id": LOCATION_ID,
		"location_generation": current_location_generation,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"orbital_coordinate": (
			coordinate_record.get("orbital_coordinate", {}) as Dictionary
		).duplicate(true),
		"world_streaming_position_meters": coordinate_record.get(
			"world_streaming_position", Vector3.INF
		),
		"body_local_position_meters": coordinate_record.get(
			"planetary_body_local_position", Vector3.INF
		),
		"radial_distance_meters": (
			coordinate_record.get("planetary_body_local_position", Vector3.INF) as Vector3
		).length(),
		"altitude_meters": coordinate_record.get("altitude_meters", INF),
		"speed_meters_per_second": speed_meters_per_second,
	})


func get_snapshot() -> Dictionary:
	var registered_definition := _coordinator.get_definition(LOCATION_ID) \
		if is_instance_valid(_coordinator) else null
	var loaded_instance := get_loaded_instance()
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"configuration_error": _configuration_error,
		"location_id": LOCATION_ID,
		"world_id": WORLD_ID,
		"body_id": BODY_ID,
		"location_resource_path": LOCATION_RESOURCE_PATH,
		"scene_resource_path": SCENE_RESOURCE_PATH,
		"load_radius_meters": LOAD_RADIUS_METERS,
		"unload_radius_meters": UNLOAD_RADIUS_METERS,
		"maximum_active_body_center_distance_meters": MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS,
		"navigation_anchor_body_local_meters": registered_definition.get_anchor_position() \
			if registered_definition != null else Vector3.INF,
		"scene_origin_body_local_meters": registered_definition.get_scene_origin_position() \
			if registered_definition != null else Vector3.INF,
		"root_streaming_position_meters": position,
		"coordinate_frame": _coordinate_frame.get_snapshot(),
		"registry": _registry.get_snapshot(),
		"coordinator": _coordinator.audit() if is_instance_valid(_coordinator) else {},
		"loaded_instance_id": loaded_instance.get_instance_id() \
			if is_instance_valid(loaded_instance) else 0,
		"location_generation": _current_location_generation(),
		"update_count": _update_count,
		"load_attempt_count": _load_attempt_count,
		"unload_attempt_count": _unload_attempt_count,
		"last_update_result": _last_update_result.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var registry_report := _registry.audit()
	var frame_report := _coordinate_frame.audit()
	var coordinator_report := _coordinator.audit() if is_instance_valid(_coordinator) else {}
	var definition := _coordinator.get_definition(LOCATION_ID) \
		if is_instance_valid(_coordinator) else null
	if not _configured:
		errors.append("checked Ember orbital streaming contract is not configured: %s" % _configuration_error)
	if not bool(registry_report.get("valid", false)):
		errors.append("nearby-sector orbital registry is invalid")
	if not bool(frame_report.get("valid", false)):
		errors.append("Ember coordinate frame is invalid")
	if not is_instance_valid(_coordinator) or _coordinator.get_parent() != self \
			or get_child_count() != 1:
		errors.append("exactly one private child coordinator is required")
	if coordinator_report.get("registered_ids") != PackedStringArray([str(LOCATION_ID)]):
		errors.append("coordinator must retain exactly the Ember registration")
	if definition == null or not definition.is_definition_valid() \
			or definition.location_id != LOCATION_ID \
			or definition.sector_id != &"nearby_sector" \
			or definition.anchor_source_id != &"ember_navigation_body_local" \
			or definition.get_anchor_position() != Vector3(0.0, 130_000.0, 0.0) \
			or definition.get_scene_origin_position() != Vector3.ZERO:
		errors.append("registered Ember location definition diverged")
	var generation := _coordinate_frame.get_generation()
	if generation > 0 and not _root_is_aligned(generation):
		errors.append("bootstrap root is not aligned to the current streaming origin")
	var loaded_instance := get_loaded_instance()
	if is_instance_valid(loaded_instance) and loaded_instance.transform != Transform3D.IDENTITY:
		errors.append("loaded Ember scene root must remain body-centred and locally identity")
	var owned_capabilities := {}
	for key in OWNED_CAPABILITY_KEYS:
		owned_capabilities[key] = true
	var adjacent_authority := {}
	for key in ADJACENT_AUTHORITY_KEYS:
		adjacent_authority[key] = false
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"evidence": {
			"content_class": &"orbital_streaming_composition",
			"status": &"new",
			"scope": &"modern_interpretation",
			"references": PackedStringArray([
				"res://docs/EMBER_MOON_ORBITAL_STREAMING.md",
			]),
			"notes": "Opt-in Ember-only composition; no Main, Cinder, SpaceBackdrop, motion, or GameFlow integration.",
		},
		"owned_capabilities": owned_capabilities,
		"adjacent_authority": adjacent_authority,
	}.duplicate(true)


func _configure_checked_contract() -> void:
	var registry_report := _registry.audit()
	if not bool(registry_report.get("valid", false)):
		_configuration_error = &"invalid_orbital_registry"
		return
	var body_coordinate := _registry.get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var station_coordinate := _registry.get_coordinate(
		NearbySectorOrbitalRegistry.STATION_DATUM_ID
	)
	var configured := _coordinate_frame.configure(
		BODY_ID,
		BODY_RADIUS_METERS,
		NearbySectorOrbitalRegistry.FRAME_ID,
		NearbySectorOrbitalRegistry.CELL_SIZE_METERS,
		body_coordinate,
		Vector3.UP,
		Vector3.FORWARD,
		ORIGIN_SHIFT_THRESHOLD_METERS,
		station_coordinate
	)
	if not bool(configured.get("accepted", false)):
		_configuration_error = &"coordinate_frame_configuration_failed"
		return
	var definition := _LOCATION_DEFINITION as WorldLocationDefinition
	var scene := _LOCATION_SCENE as PackedScene
	if definition == null or not definition.is_definition_valid() \
			or definition.location_id != LOCATION_ID \
			or definition.get_anchor_position() != Vector3(0.0, 130_000.0, 0.0) \
			or definition.get_scene_origin_position() != Vector3.ZERO:
		_configuration_error = &"location_contract_mismatch"
		return
	if scene == null or not _coordinator.register_location(definition, scene):
		_configuration_error = &"location_registration_failed"
		return
	_configured = true


func _body_center_world_position(expected_generation: int) -> Dictionary:
	var body_coordinate := _registry.get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	return _coordinate_frame.orbital_to_world_streaming_position(
		body_coordinate, expected_generation
	)


func _root_is_aligned(expected_generation: int) -> bool:
	if transform.basis != Basis.IDENTITY:
		return false
	var expected := _body_center_world_position(expected_generation)
	return bool(expected.get("accepted", false)) \
		and position.is_equal_approx(expected.get("position", Vector3.INF) as Vector3)


func _current_location_generation() -> int:
	if not is_instance_valid(_coordinator):
		return -1
	var generations := _coordinator.audit().get("generation_by_id", {}) as Dictionary
	return int(generations.get(LOCATION_ID, -1))


func _finish_transition(
		outcome: Dictionary,
		action: StringName,
		radial_distance: float,
		body_center_distance: float,
		frame_generation: int
	) -> Dictionary:
	return _finish_update(bool(outcome.get("accepted", false)), outcome.get(
		"reason", &"streaming_request_rejected"
	), {
		"action": action,
		"radial_distance_meters": radial_distance,
		"body_center_world_distance_meters": body_center_distance,
		"coordinate_frame_generation": frame_generation,
		"location_generation": int(outcome.get(
			"generation", _current_location_generation()
		)),
		"coordinator_outcome": outcome.duplicate(true),
	})


func _finish_update(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {}
	) -> Dictionary:
	_update_count += 1
	var result := _update_result(accepted, reason, extra)
	_last_update_result = result.duplicate(true)
	_update_active = false
	return result


func _update_result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


func _observation_result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
