class_name EmberMoonStreamingBootstrap
extends PlanetaryStreamingBootstrap

## Explicit, opt-in Ember Moon orbital placement and streaming composition.
##
## The world-agnostic half of this component — datum, coordinate frame,
## registration, focus hysteresis, travel observation and rebase re-expression —
## now lives in [PlanetaryStreamingBootstrap] and is shared with every other
## streamed body. What remains here is the part that is true only of an airless
## moon: the one generation-bound airless sun rig and the passive airless
## environment presentation it drives. An atmospheric world brings its own.

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
const AIRLESS_SUN_RIG_SCENE_PATH := \
	"res://scenes/world/components/ember_airless_sun_rig.tscn"
const EMBER_WORLD_RESOURCE_PATH := \
	"res://assets/world/planets/ember_moon_world.tres"
const _LOCATION_DEFINITION := preload(LOCATION_RESOURCE_PATH)
const _LOCATION_SCENE := preload(SCENE_RESOURCE_PATH)
const _EMBER_WORLD_DEFINITION := preload(EMBER_WORLD_RESOURCE_PATH)
const _AIRLESS_SUN_RIG_SCENE := preload(AIRLESS_SUN_RIG_SCENE_PATH)
const _AIRLESS_ENVIRONMENT_SCRIPT := preload(
	"res://scripts/world/ember_airless_environment_presentation.gd"
)
const AUTHORED_WORLD_ENVIRONMENT_PATH := \
	NodePath("../ShipyardWorld/ShipyardEnvironment")

@export var airless_sun_rig_scene: PackedScene = _AIRLESS_SUN_RIG_SCENE

var _airless_sun_rig: Node3D
var _last_sun_result: Dictionary = {}
var _sun_attach_count := 0
var _sun_detach_count := 0
var _airless_environment_presentation: RefCounted
var _last_environment_result: Dictionary = {}
var _environment_attach_count := 0
var _environment_detach_count := 0


func _create_profile() -> Dictionary:
	return {
		"location_id": LOCATION_ID,
		"world_id": WORLD_ID,
		"body_id": BODY_ID,
		"display_label": "Ember",
		"location_resource_path": LOCATION_RESOURCE_PATH,
		"scene_resource_path": SCENE_RESOURCE_PATH,
		"location_definition": _LOCATION_DEFINITION,
		"location_scene": _LOCATION_SCENE,
		"datum_point_id": NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID,
		"body_radius_meters": BODY_RADIUS_METERS,
		"load_radius_meters": LOAD_RADIUS_METERS,
		"unload_radius_meters": UNLOAD_RADIUS_METERS,
		"max_active_body_center_distance_meters":
			MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS,
		"origin_shift_threshold_meters": ORIGIN_SHIFT_THRESHOLD_METERS,
		"max_observation_speed_meters_per_second":
			MAX_OBSERVATION_SPEED_METERS_PER_SECOND,
		"initial_body_center_world_position": INITIAL_BODY_CENTER_WORLD_POSITION,
		"expected_sector_id": &"nearby_sector",
		"expected_anchor_source_id": &"ember_navigation_body_local",
		"expected_anchor_position": Vector3(0.0, 130_000.0, 0.0),
		"expected_scene_origin_position": Vector3.ZERO,
	}


## Returns the single generation-bound renderer rig while Ember is resident.
## The bootstrap owns its lifetime; callers receive no creation or streaming
## authority through this read-only identity seam.
func get_airless_sun_rig() -> Node3D:
	return _airless_sun_rig if is_instance_valid(_airless_sun_rig) else null


func _loaded_instance_is_expected(instance: Node3D) -> bool:
	return instance is EmberMoonAuthoredScene


func _environment_result_key() -> String:
	return "sun_presentation"


func _not_loaded_reason() -> StringName:
	return &"ember_not_loaded"


func _validate_presentation_configuration() -> StringName:
	# Exported scene assignments from a `.tscn` are applied after construction,
	# so resolve the authored default here rather than assuming field order.
	if airless_sun_rig_scene == null:
		airless_sun_rig_scene = _AIRLESS_SUN_RIG_SCENE
	if airless_sun_rig_scene != _AIRLESS_SUN_RIG_SCENE:
		return &"airless_sun_rig_scene_mismatch"
	return &""


func _on_generation_loaded(
		instance: Node3D,
		frame_generation: int,
		location_generation: int,
	) -> void:
	_retire_airless_sun(&"replacement_before_attach")
	var candidate := _AIRLESS_SUN_RIG_SCENE.instantiate()
	if candidate is not Node3D:
		if candidate != null:
			candidate.queue_free()
		_last_sun_result = _presentation_result(false, &"sun_rig_instantiation_failed")
		return
	_airless_sun_rig = candidate as Node3D
	_coordinator.add_child(_airless_sun_rig)
	var configured := _airless_sun_rig.call(
		&"configure",
		_EMBER_WORLD_DEFINITION,
		self,
		_coordinate_frame,
		instance,
		frame_generation,
		location_generation,
	) as Dictionary
	if not bool(configured.get("accepted", false)):
		var failed_result := _presentation_result(
			false, &"sun_binding_configuration_failed", {
				"binding_reason": configured.get("reason", &"unknown"),
			}
		)
		_retire_airless_sun(&"configuration_failed")
		_last_sun_result = failed_result
		return
	_sun_attach_count += 1
	_attach_airless_environment(frame_generation, location_generation)
	if _last_focus_frame_generation == frame_generation:
		_present_environment(
			_last_body_local_focus,
			frame_generation,
			location_generation,
		)
	else:
		_last_sun_result = _presentation_result(true, &"awaiting_current_focus")


func _on_generation_load_failed(reason: StringName) -> void:
	_retire_airless_sun(&"load_failed")
	_last_sun_result = _presentation_result(false, &"ember_load_failed", {
		"streaming_reason": reason,
	})


func _on_generation_unloaded() -> void:
	_retire_airless_sun(&"ember_unloaded")


func _present_environment(
		body_local_observer: Vector3,
		frame_generation: int,
		location_generation: int,
	) -> Dictionary:
	if not is_instance_valid(_airless_sun_rig):
		_last_sun_result = _presentation_result(false, &"sun_rig_unavailable")
		return _last_sun_result.duplicate(true)
	var binding_generation := int(_airless_sun_rig.call(&"get_generation"))
	var result := _airless_sun_rig.call(
		&"present_post_rebase_observation",
		body_local_observer,
		frame_generation,
		location_generation,
		binding_generation,
	) as Dictionary
	if bool(result.get("accepted", false)):
		if _airless_environment_presentation == null:
			_attach_airless_environment(frame_generation, location_generation)
		if _airless_environment_presentation != null:
			var environment_result := _airless_environment_presentation.call(
				&"present_accepted_sun", result, frame_generation,
				location_generation,
				_airless_environment_presentation.call(&"get_generation")
			) as Dictionary
			_last_environment_result = environment_result.duplicate(true)
			result["environment_presentation"] = environment_result.duplicate(true)
	_last_sun_result = result.duplicate(true)
	return result.duplicate(true)


func _retire_environment(reason: StringName) -> void:
	_retire_airless_environment(reason)


func _extend_snapshot(snapshot: Dictionary) -> void:
	snapshot["airless_sun"] = {
		"scene_path": AIRLESS_SUN_RIG_SCENE_PATH,
		"active": is_instance_valid(_airless_sun_rig),
		"rig_instance_id": _airless_sun_rig.get_instance_id() \
			if is_instance_valid(_airless_sun_rig) else 0,
		"last_body_local_focus_meters": _last_body_local_focus,
		"last_focus_frame_generation": _last_focus_frame_generation,
		"attach_count": _sun_attach_count,
		"detach_count": _sun_detach_count,
		"last_result": _last_sun_result.duplicate(true),
	}
	snapshot["airless_environment"] = {
		"active": _airless_environment_presentation != null,
		"authored_target_path": AUTHORED_WORLD_ENVIRONMENT_PATH,
		"attach_count": _environment_attach_count,
		"detach_count": _environment_detach_count,
		"last_result": _last_environment_result.duplicate(true),
		"presentation": (
			_airless_environment_presentation.call(&"get_snapshot")
			if _airless_environment_presentation != null else {}
		),
	}


func _collect_presentation_contract_errors(
		errors: PackedStringArray,
		loaded_instance: Node3D,
	) -> void:
	var directional_lights := find_children(
		"*", "DirectionalLight3D", true, false
	)
	var sun_rig := get_airless_sun_rig()
	if is_instance_valid(sun_rig):
		if not is_instance_valid(loaded_instance) \
				or sun_rig.get_parent() != _coordinator \
				or sun_rig.scene_file_path != AIRLESS_SUN_RIG_SCENE_PATH \
				or sun_rig.find_children("*", "DirectionalLight3D", true, false).size() != 1 \
				or directional_lights.size() != 1:
			errors.append("airless sun rig is not bound to the one live Ember generation")
	elif is_instance_valid(loaded_instance):
		# A location-loaded signal composes the rig synchronously, so no stable
		# resident snapshot may omit its sole light owner.
		errors.append("loaded Ember generation is missing its airless sun rig")
	elif not directional_lights.is_empty():
		errors.append("unloaded Ember retains a directional light")
	var authored_environment := _resolve_authored_world_environment()
	# The sun binding calls this audit while it configures, before the passive
	# environment adapter can consume its first accepted sample. Audit an adapter
	# once attached without making it a circular prerequisite of sun startup.
	if _airless_environment_presentation != null:
		if not is_instance_valid(loaded_instance) or authored_environment == null:
			errors.append("airless environment presentation outlived its target lifecycle")
		else:
			var environment_audit := (
				_airless_environment_presentation.call(&"audit") as Dictionary
			)
			if not bool(environment_audit.get("valid", false)):
				errors.append("authored environment presentation is invalid")
	if airless_sun_rig_scene != _AIRLESS_SUN_RIG_SCENE:
		errors.append("airless sun scene binding diverged")


func _evidence() -> Dictionary:
	return {
		"content_class": &"orbital_streaming_composition",
		"status": &"new",
		"scope": &"modern_interpretation",
		"references": PackedStringArray([
			"res://docs/EMBER_MOON_ORBITAL_STREAMING.md",
		]),
		"notes": "Ember-only streaming composition; production observation remains external and owns no Cinder, SpaceBackdrop, motion, or GameFlow authority.",
	}


func _retire_airless_sun(reason: StringName) -> void:
	_retire_airless_environment(reason)
	if not is_instance_valid(_airless_sun_rig):
		_airless_sun_rig = null
		return
	var retired_id := _airless_sun_rig.get_instance_id()
	if _airless_sun_rig.get_parent() == _coordinator:
		_coordinator.remove_child(_airless_sun_rig)
	if not _airless_sun_rig.is_queued_for_deletion():
		_airless_sun_rig.queue_free()
	_airless_sun_rig = null
	_sun_detach_count += 1
	_last_sun_result = _presentation_result(true, reason, {
		"retired_rig_instance_id": retired_id,
	})


func _attach_airless_environment(
		frame_generation: int, location_generation: int
	) -> Dictionary:
	if _airless_environment_presentation != null:
		return _presentation_result(true, &"environment_already_attached")
	var target := _resolve_authored_world_environment()
	if target == null or not is_instance_valid(_airless_sun_rig):
		_last_environment_result = _presentation_result(
			false, &"authored_environment_unavailable"
		)
		return _last_environment_result.duplicate(true)
	var candidate := _AIRLESS_ENVIRONMENT_SCRIPT.new() as RefCounted
	var configured := candidate.call(
		&"configure", target, _airless_sun_rig, frame_generation,
		location_generation
	) as Dictionary
	if not bool(configured.get("accepted", false)):
		_last_environment_result = configured.duplicate(true)
		return _last_environment_result.duplicate(true)
	_airless_environment_presentation = candidate
	_environment_attach_count += 1
	_last_environment_result = configured.duplicate(true)
	return configured.duplicate(true)


func _retire_airless_environment(reason: StringName) -> void:
	if _airless_environment_presentation == null:
		return
	var detached := _airless_environment_presentation.call(
		&"detach", reason,
		_airless_environment_presentation.call(&"get_generation")
	) as Dictionary
	_last_environment_result = detached.duplicate(true)
	_airless_environment_presentation = null
	_environment_detach_count += 1


func _resolve_authored_world_environment() -> WorldEnvironment:
	var host := get_parent()
	var candidate := (
		host.get_node_or_null(^"ShipyardWorld/ShipyardEnvironment")
		if host != null else null
	)
	if candidate is not WorldEnvironment:
		return null
	var target := candidate as WorldEnvironment
	return target if target.environment != null else null
