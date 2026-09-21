class_name AuroraTemperateStreamingBootstrap
extends PlanetaryStreamingBootstrap

## Explicit, opt-in Aurora orbital placement and streaming composition.
##
## Aurora is the second world to use [PlanetaryStreamingBootstrap], and it is
## the reason the base exists: the datum, coordinate frame, registration, focus
## hysteresis, travel observation and committed-rebase re-expression here are
## the same shared code Ember runs, with no Ember concept anywhere in it.
##
## What is Aurora's own is the part that could never be shared with an airless
## moon. Ember composes a directional sun rig and a passive airless environment;
## Aurora's authored scene already carries a complete
## [PlanetaryAtmosphereComposition] — sky, fog, cloud shell and its own
## `WorldEnvironment` — so this bootstrap configures that composition against
## the live generation and feeds it one body-local observation per accepted
## focus, exactly where Ember feeds its sun rig.

const LOCATION_ID: StringName = &"aurora_temperate_world"
const WORLD_ID: StringName = &"aurora_temperate_world"
const BODY_ID: StringName = &"aurora_temperate_body"
const LOAD_RADIUS_METERS := 250_000.0
const UNLOAD_RADIUS_METERS := 300_000.0
const MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS := 300_000.0
const BODY_RADIUS_METERS := 120_000.0
const ORIGIN_SHIFT_THRESHOLD_METERS := 10_000.0
const MAX_OBSERVATION_SPEED_METERS_PER_SECOND := 100_000.0
const INITIAL_BODY_CENTER_WORLD_POSITION := Vector3(12_000_000.0, 0.0, 0.0)

const LOCATION_RESOURCE_PATH := "res://assets/world/locations/aurora_temperate.tres"
const SCENE_RESOURCE_PATH := "res://scenes/world/planets/aurora_temperate_world.tscn"
const ATMOSPHERE_COMPOSITION_PATH := NodePath("AuroraAtmosphereComposition")
const _LOCATION_DEFINITION := preload(LOCATION_RESOURCE_PATH)
const _LOCATION_SCENE := preload(SCENE_RESOURCE_PATH)

## Aurora's authored corridor runs in along local +Z above sea level, so the
## observation handed to the atmosphere is taken looking down that corridor.
const OBSERVATION_VIEW_DIRECTION_BODY_LOCAL := Vector3.FORWARD
const OBSERVATION_FOG_PATH_DISTANCE_M := 12_000.0
const OBSERVATION_WEATHER_SCALAR := 0.4
const OBSERVATION_CLOUD_SCALAR := 0.5

var _atmosphere: PlanetaryAtmosphereComposition
var _atmosphere_generation := 0
var _last_atmosphere_result: Dictionary = {}
var _atmosphere_configure_count := 0
var _atmosphere_retire_count := 0


func _create_profile() -> Dictionary:
	return {
		"location_id": LOCATION_ID,
		"world_id": WORLD_ID,
		"body_id": BODY_ID,
		"display_label": "Aurora",
		"location_resource_path": LOCATION_RESOURCE_PATH,
		"scene_resource_path": SCENE_RESOURCE_PATH,
		"location_definition": _LOCATION_DEFINITION,
		"location_scene": _LOCATION_SCENE,
		"datum_point_id": NearbySectorOrbitalRegistry.AURORA_BODY_CENTER_ID,
		"navigation_destination_id": &"aurora_navigation",
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
		"expected_anchor_source_id": &"aurora_navigation_body_local",
		"expected_anchor_position": Vector3(0.0, 130_000.0, 0.0),
		"expected_scene_origin_position": Vector3.ZERO,
	}


## The live atmosphere composition while Aurora is resident. Read-only identity:
## the streamed scene owns its lifetime, and a caller receives no authority to
## create, configure or retire it through this seam.
func get_atmosphere_composition() -> PlanetaryAtmosphereComposition:
	return _atmosphere if is_instance_valid(_atmosphere) else null


## The environment a viewport owner may present while Aurora is resident. Null
## whenever the composition is not configured against a live generation.
func get_scene_environment() -> Environment:
	if not is_instance_valid(_atmosphere):
		return null
	var world_environment := _atmosphere.get_world_environment()
	return world_environment.environment if world_environment != null else null


func _loaded_instance_is_expected(instance: Node3D) -> bool:
	return instance is AuroraTemperateAuthoredScene


func _environment_result_key() -> String:
	return "atmosphere_presentation"


func _not_loaded_reason() -> StringName:
	return &"aurora_not_loaded"


func _on_generation_loaded(
		instance: Node3D,
		frame_generation: int,
		location_generation: int,
	) -> void:
	_retire_atmosphere(&"replacement_before_attach")
	var candidate := instance.get_node_or_null(
		ATMOSPHERE_COMPOSITION_PATH
	) as PlanetaryAtmosphereComposition
	if candidate == null:
		_last_atmosphere_result = _presentation_result(
			false, &"atmosphere_composition_unavailable"
		)
		return
	var configured := candidate.configure()
	if not bool(configured.get("accepted", false)):
		_last_atmosphere_result = _presentation_result(
			false, &"atmosphere_configuration_failed", {
				"composition_reason": configured.get("reason", &"unknown"),
			}
		)
		return
	_atmosphere = candidate
	_atmosphere_generation = int(configured.get("generation", 0))
	_atmosphere_configure_count += 1
	if _last_focus_frame_generation == frame_generation:
		_present_environment(
			_last_body_local_focus, frame_generation, location_generation
		)
	else:
		_last_atmosphere_result = _presentation_result(true, &"awaiting_current_focus")


func _on_generation_load_failed(reason: StringName) -> void:
	_retire_atmosphere(&"load_failed")
	_last_atmosphere_result = _presentation_result(false, &"aurora_load_failed", {
		"streaming_reason": reason,
	})


func _on_generation_unloaded() -> void:
	_retire_atmosphere(&"aurora_unloaded")


func _present_environment(
		body_local_observer: Vector3,
		frame_generation: int,
		location_generation: int,
	) -> Dictionary:
	if not is_instance_valid(_atmosphere):
		_last_atmosphere_result = _presentation_result(
			false, &"atmosphere_composition_unavailable"
		)
		return _last_atmosphere_result.duplicate(true)
	var presented := _atmosphere.present_observation({
		"body_local_observer_m": body_local_observer,
		"view_direction_body_local": OBSERVATION_VIEW_DIRECTION_BODY_LOCAL,
		"fog_path_distance_m": OBSERVATION_FOG_PATH_DISTANCE_M,
		"speed_mps": 0.0,
		"weather_scalar": OBSERVATION_WEATHER_SCALAR,
		"cloud_scalar": OBSERVATION_CLOUD_SCALAR,
		"caller_time_seconds": 0.0,
	}, _atmosphere_generation)
	var result := _presentation_result(
		bool(presented.get("accepted", false)),
		presented.get("reason", &"atmosphere_presentation_rejected") as StringName,
		{
			"coordinate_frame_generation": frame_generation,
			"location_generation": location_generation,
			"composition": presented.duplicate(true),
		},
	)
	_last_atmosphere_result = result.duplicate(true)
	return result.duplicate(true)


func _retire_environment(reason: StringName) -> void:
	_retire_atmosphere(reason)


func _extend_snapshot(snapshot: Dictionary) -> void:
	snapshot["atmosphere"] = {
		"active": is_instance_valid(_atmosphere),
		"composition_instance_id": _atmosphere.get_instance_id() \
			if is_instance_valid(_atmosphere) else 0,
		"composition_generation": _atmosphere_generation,
		"configure_count": _atmosphere_configure_count,
		"retire_count": _atmosphere_retire_count,
		"last_body_local_focus_meters": _last_body_local_focus,
		"last_focus_frame_generation": _last_focus_frame_generation,
		"last_result": _last_atmosphere_result.duplicate(true),
	}


func _collect_presentation_contract_errors(
		errors: PackedStringArray,
		loaded_instance: Node3D,
	) -> void:
	if is_instance_valid(_atmosphere):
		if not is_instance_valid(loaded_instance) \
				or _atmosphere.get_parent() != loaded_instance:
			errors.append("Aurora atmosphere outlived its streamed generation")
	elif is_instance_valid(loaded_instance):
		# The location-loaded signal configures the composition synchronously,
		# so no stable resident snapshot may be missing it.
		errors.append("loaded Aurora generation is missing its atmosphere")


func _evidence() -> Dictionary:
	return {
		"content_class": &"orbital_streaming_composition",
		"status": &"new",
		"scope": &"modern_interpretation",
		"references": PackedStringArray([
			"res://docs/EMBER_MOON_ORBITAL_STREAMING.md",
		]),
		"notes": "Aurora-only streaming composition; production observation remains external and owns no Ember, Cinder, SpaceBackdrop, motion, or GameFlow authority.",
	}


func _retire_atmosphere(reason: StringName) -> void:
	if not is_instance_valid(_atmosphere):
		_atmosphere = null
		_atmosphere_generation = 0
		return
	var retired_id := _atmosphere.get_instance_id()
	# The composition belongs to the streamed scene, which the coordinator frees
	# on unload. This bootstrap only drops its reference and its generation.
	_atmosphere = null
	_atmosphere_generation = 0
	_atmosphere_retire_count += 1
	_last_atmosphere_result = _presentation_result(true, reason, {
		"retired_composition_instance_id": retired_id,
	})
