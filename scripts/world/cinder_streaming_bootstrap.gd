class_name CinderStreamingBootstrap
extends Node3D

## Explicit Cinder Reach streaming composition.
##
## This bootstrap binds the checked-in location definition and authored cluster
## scene to one [WorldStreamingCoordinator] and one
## [WorldStreamingDistancePolicy]. It deliberately has no process callback: a
## host supplies each tracked position or physics delta through the public API.

signal transition_attempted(
	location_id: StringName,
	action: StringName,
	distance: float,
	outcome: Dictionary
)

const SCHEMA_VERSION := 1
const LOCATION_ID: StringName = &"cinder_reach"
const LOAD_RADIUS_METERS := 500.0
const UNLOAD_RADIUS_METERS := 650.0
const REQUESTS_PER_UPDATE := 1
const EXPECTED_NAVIGATION_ANCHOR := Vector3(60.0, -70.0, -700.0)
const EXPECTED_SCENE_ORIGIN := Vector3.ZERO
const LOCATION_RESOURCE_PATH := "res://assets/world/locations/cinder_reach.tres"
const SCENE_RESOURCE_PATH := "res://scenes/world/components/nearby_sector_cluster.tscn"
const _LOCATION_DEFINITION := preload(LOCATION_RESOURCE_PATH)
const _LOCATION_SCENE := preload(SCENE_RESOURCE_PATH)

var _coordinator: WorldStreamingCoordinator
var _distance_policy: WorldStreamingDistancePolicy
var _configured := false
var _configuration_error: StringName = &""
var _update_active := false


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_coordinator = WorldStreamingCoordinator.new()
	_coordinator.name = "WorldStreamingCoordinator"
	add_child(_coordinator)
	_distance_policy = WorldStreamingDistancePolicy.new()
	_distance_policy.name = "WorldStreamingDistancePolicy"
	add_child(_distance_policy)
	_distance_policy.transition_attempted.connect(_on_transition_attempted)
	_configure_checked_profile()


## Overrides the default deferred PackedScene binding with the coordinator's
## public loader contract. This is accepted only under the coordinator's normal
## no-in-flight-work rule.
func set_scene_loader(loader: Callable) -> bool:
	if _update_active or not _configured or not is_instance_valid(_coordinator):
		return false
	if int(_coordinator.audit().get("load_request_count", -1)) != 0:
		return false
	return _coordinator.set_loader(loader)


## Stores one finite tracking sample without evaluating it.
func set_tracked_position(position: Vector3) -> bool:
	if _update_active or not _configured or not is_instance_valid(_distance_policy):
		return false
	return _distance_policy.set_tracked_position(position)


## Temporarily removes tracking without unloading or cancelling Cinder Reach.
func clear_tracked_position() -> bool:
	if _update_active or not _configured or not is_instance_valid(_distance_policy):
		return false
	_distance_policy.clear_tracked_position()
	return true


## Supplies a position and evaluates the fixed Cinder profile once.
func update_position(position: Vector3) -> Dictionary:
	if _update_active:
		return _rejected_result(&"bootstrap_update_in_progress")
	if not _configured or not is_instance_valid(_distance_policy):
		return _unavailable_result()
	_update_active = true
	var result := _distance_policy.update_position(position)
	_update_active = false
	return result


## Evaluates a retained position and advances only caller-supplied physics time.
func physics_tick(delta: float) -> Dictionary:
	if _update_active:
		return _rejected_result(&"bootstrap_update_in_progress")
	if not _configured or not is_instance_valid(_distance_policy):
		return _unavailable_result()
	_update_active = true
	var result := _distance_policy.physics_tick(delta)
	_update_active = false
	return result


## Explicitly evaluates the retained sample without advancing physics time.
func update_now() -> Dictionary:
	if _update_active:
		return _rejected_result(&"bootstrap_update_in_progress")
	if not _configured or not is_instance_valid(_distance_policy):
		return _unavailable_result()
	_update_active = true
	var result := _distance_policy.update_now()
	_update_active = false
	return result


func get_loaded_instance() -> Node3D:
	if not _configured or not is_instance_valid(_coordinator):
		return null
	return _coordinator.get_loaded_instance(LOCATION_ID)


## Detached composition state. No Resource, Node, Callable, or mutable internal
## collection is returned.
func get_snapshot() -> Dictionary:
	var coordinator_report := {}
	var policy_snapshot := {}
	var registered_definition: WorldLocationDefinition
	var loaded_instance: Node3D
	if is_instance_valid(_coordinator):
		coordinator_report = _coordinator.audit()
		registered_definition = _coordinator.get_definition(LOCATION_ID)
		loaded_instance = _coordinator.get_loaded_instance(LOCATION_ID)
	if is_instance_valid(_distance_policy):
		policy_snapshot = _distance_policy.get_snapshot()
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"configuration_error": _configuration_error,
		"location_id": LOCATION_ID,
		"location_resource_path": LOCATION_RESOURCE_PATH,
		"scene_resource_path": SCENE_RESOURCE_PATH,
		"navigation_anchor_position": registered_definition.get_anchor_position() \
			if registered_definition != null else Vector3.INF,
		"scene_origin_position": registered_definition.get_scene_origin_position() \
			if registered_definition != null else Vector3.INF,
		"load_radius_meters": LOAD_RADIUS_METERS,
		"unload_radius_meters": UNLOAD_RADIUS_METERS,
		"requests_per_update": REQUESTS_PER_UPDATE,
		"loaded_instance_id": loaded_instance.get_instance_id() \
			if is_instance_valid(loaded_instance) else 0,
		"loaded_generation": int(loaded_instance.get_meta(&"world_location_generation", -1)) \
			if is_instance_valid(loaded_instance) else -1,
		"coordinator": coordinator_report,
		"distance_policy": policy_snapshot,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var coordinator_report := _coordinator.audit() if is_instance_valid(_coordinator) else {}
	var policy_report := _distance_policy.audit() if is_instance_valid(_distance_policy) else {}
	var policy_snapshot := policy_report.get("snapshot", {}) as Dictionary
	var locations := policy_snapshot.get("locations", []) as Array
	var registered_definition := _coordinator.get_definition(LOCATION_ID) \
		if is_instance_valid(_coordinator) else null
	if not _configured:
		errors.append("checked Cinder streaming profile is not configured: %s" % _configuration_error)
	if not is_instance_valid(_coordinator) or _coordinator.get_parent() != self:
		errors.append("one live child coordinator is required")
	if not is_instance_valid(_distance_policy) or _distance_policy.get_parent() != self:
		errors.append("one live child distance policy is required")
	if coordinator_report.get("registered_ids") != PackedStringArray([str(LOCATION_ID)]):
		errors.append("coordinator must retain exactly the Cinder definition")
	if registered_definition == null or not registered_definition.is_definition_valid():
		errors.append("registered Cinder definition must remain valid")
	else:
		if registered_definition.get_anchor_position() != EXPECTED_NAVIGATION_ANCHOR:
			errors.append("Cinder navigation anchor diverged from the checked profile")
		if registered_definition.get_scene_origin_position() != EXPECTED_SCENE_ORIGIN:
			errors.append("Cinder scene origin diverged from the checked profile")
	if not bool(policy_report.get("valid", false)):
		errors.append("distance policy audit is invalid")
	if locations.size() != 1:
		errors.append("distance policy must contain exactly one Cinder registration")
	else:
		var location := locations[0] as Dictionary
		if location.get("location_id") != LOCATION_ID \
			or not is_equal_approx(float(location.get("load_radius", -1.0)), LOAD_RADIUS_METERS) \
			or not is_equal_approx(float(location.get("unload_radius", -1.0)), UNLOAD_RADIUS_METERS):
			errors.append("distance policy diverged from the fixed Cinder thresholds")
	var report := {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"profile_policy": &"checked_resources_fixed_500m_load_650m_unload",
		"update_authority": &"explicit_only",
		"automatic_engine_processing": false,
		"gameplay_authority": false,
		"mission_authority": false,
		"activity_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
	}
	return report.duplicate(true)


func _configure_checked_profile() -> void:
	var definition := _LOCATION_DEFINITION as WorldLocationDefinition
	var scene := _LOCATION_SCENE as PackedScene
	if definition == null or not definition.is_definition_valid():
		_configuration_error = &"invalid_location_definition"
		return
	if definition.location_id != LOCATION_ID \
		or definition.get_anchor_position() != EXPECTED_NAVIGATION_ANCHOR \
		or definition.get_scene_origin_position() != EXPECTED_SCENE_ORIGIN:
		_configuration_error = &"location_contract_mismatch"
		return
	if scene == null:
		_configuration_error = &"missing_cluster_scene"
		return
	if not _distance_policy.configure(_coordinator, REQUESTS_PER_UPDATE):
		_configuration_error = &"policy_configuration_failed"
		return
	if not _distance_policy.register_location(
		definition,
		LOAD_RADIUS_METERS,
		UNLOAD_RADIUS_METERS,
		scene
	):
		_configuration_error = &"profile_registration_failed"
		return
	_configured = true


func _on_transition_attempted(
	location_id: StringName,
	action: StringName,
	distance: float,
	outcome: Dictionary
) -> void:
	transition_attempted.emit(location_id, action, distance, outcome.duplicate(true))


func _unavailable_result() -> Dictionary:
	var result := _rejected_result(&"bootstrap_not_configured")
	result["configuration_error"] = _configuration_error
	return result.duplicate(true)


func _rejected_result(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"configuration_error": _configuration_error,
		"attempted_count": 0,
		"transitions": [],
	}.duplicate(true)
