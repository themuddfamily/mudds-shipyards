class_name RimeGlacialStreamingBootstrap
extends "res://scripts/world/planetary_surface_visit_streaming_bootstrap.gd"

## Explicit, opt-in Rime orbital placement and streaming composition.
##
## Rime is the third body on [PlanetaryStreamingBootstrap]. The datum, frame,
## registration, focus hysteresis, travel observation and committed-rebase
## re-expression are all the shared base, and the atmospheric half - composition
## configure/observe, the flight-effects weather scalar, interior blend, gust
## and weather-clock seams, and the surface-audio snapshot - is the shared
## surface-visit streaming bootstrap Aurora runs too. What is Rime's own is its
## authored [PlanetaryAtmosphereComposition] - a cold, thin, hazy one whose
## 14 km atmosphere top goes orbital-dark lower than Aurora's - and the tuning
## and hard, waterless wind it is observed with.

const LOCATION_ID: StringName = &"rime_glacial_world"
const WORLD_ID: StringName = &"rime_glacial_world"
const BODY_ID: StringName = &"rime_glacial_body"
const LOAD_RADIUS_METERS := 250_000.0
const UNLOAD_RADIUS_METERS := 300_000.0
const MAX_ACTIVE_BODY_CENTER_DISTANCE_METERS := 300_000.0
const BODY_RADIUS_METERS := 120_000.0
const ORIGIN_SHIFT_THRESHOLD_METERS := 10_000.0
const MAX_OBSERVATION_SPEED_METERS_PER_SECOND := 100_000.0
const INITIAL_BODY_CENTER_WORLD_POSITION := Vector3(-10_000_000.0, 0.0, 0.0)

const LOCATION_RESOURCE_PATH := "res://assets/world/locations/rime_glacial.tres"
const SCENE_RESOURCE_PATH := "res://scenes/world/planets/rime_glacial_world.tscn"
const ATMOSPHERE_COMPOSITION_PATH := NodePath("RimeAtmosphereComposition")
const _LOCATION_DEFINITION := preload(LOCATION_RESOURCE_PATH)
const _LOCATION_SCENE := preload(SCENE_RESOURCE_PATH)

## Rime's corridor runs in along local +Z like Aurora's. The observation looks
## down it through a short fog path, with a heavier weather and cloud reading:
## the ice-crystal overcast and ground haze are the world's identity.
const OBSERVATION_VIEW_DIRECTION_BODY_LOCAL := Vector3.FORWARD
const OBSERVATION_FOG_PATH_DISTANCE_M := 6_000.0
const OBSERVATION_WEATHER_SCALAR := 0.66
const OBSERVATION_CLOUD_SCALAR := 0.74
## Exterior wind reading used before the flight effects supply a gust sample.
const SURFACE_AUDIO_RESTING_WIND_UNITLESS := 0.78


func _create_profile() -> Dictionary:
	return {
		"location_id": LOCATION_ID,
		"world_id": WORLD_ID,
		"body_id": BODY_ID,
		"display_label": "Rime",
		"location_resource_path": LOCATION_RESOURCE_PATH,
		"scene_resource_path": SCENE_RESOURCE_PATH,
		"location_definition": _LOCATION_DEFINITION,
		"location_scene": _LOCATION_SCENE,
		"datum_point_id": NearbySectorOrbitalRegistry.RIME_BODY_CENTER_ID,
		"navigation_destination_id": &"rime_navigation",
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
		"expected_anchor_source_id": &"rime_navigation_body_local",
		"expected_anchor_position": Vector3(0.0, 130_000.0, 0.0),
		"expected_scene_origin_position": Vector3.ZERO,
	}


func _loaded_instance_is_expected(instance: Node3D) -> bool:
	return instance is RimeGlacialAuthoredScene


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


## No open water on the ice; a hard steady wind is the resting reading until the
## flight effects supply the gusting one sampled from Rime's own wind profile.
func _surface_audio_environment() -> Dictionary:
	return {
		"water_exposure_unitless": 0.0,
		"wind_strength_unitless": SURFACE_AUDIO_RESTING_WIND_UNITLESS,
	}


func _evidence() -> Dictionary:
	return {
		"content_class": &"orbital_streaming_composition",
		"status": &"new",
		"scope": &"modern_interpretation",
		"references": PackedStringArray([
			"res://docs/RIME_GLACIAL_WORLD.md",
		]),
		"notes": "Rime-only streaming composition; production observation remains external and owns no Ember, Aurora, Cinder, SpaceBackdrop, motion, or GameFlow authority.",
	}
