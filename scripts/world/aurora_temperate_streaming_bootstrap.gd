class_name AuroraTemperateStreamingBootstrap
extends "res://scripts/world/planetary_surface_visit_streaming_bootstrap.gd"

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
## focus, exactly where Ember feeds its sun rig. That atmospheric half is the
## shared surface-visit streaming bootstrap Rime also runs; this file keeps only
## Aurora's identity, scene, observation tuning and coastal audio inputs.

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


func _loaded_instance_is_expected(instance: Node3D) -> bool:
	return instance is AuroraTemperateAuthoredScene


func _atmosphere_composition_path() -> NodePath:
	return ATMOSPHERE_COMPOSITION_PATH


func _observation_view_direction_body_local() -> Vector3:
	return OBSERVATION_VIEW_DIRECTION_BODY_LOCAL


func _observation_fog_path_distance_m() -> float:
	return OBSERVATION_FOG_PATH_DISTANCE_M


func _observation_weather_scalar() -> float:
	return OBSERVATION_WEATHER_SCALAR


func _observation_cloud_scalar() -> float:
	return OBSERVATION_CLOUD_SCALAR


## Aurora is a coast: the distant surf bed is fully exposed, and exterior wind
## follows the weather intensity until the flight effects supply a gust reading.
func _surface_audio_environment() -> Dictionary:
	return {"water_exposure_unitless": 1.0}


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
