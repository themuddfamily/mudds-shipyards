extends PlanetaryStreamingBootstrap

## The streaming composition every atmospheric surface-visit world shares.
##
## [PlanetaryStreamingBootstrap] owns the datum, coordinate frame, registration,
## focus hysteresis, travel observation and committed-rebase re-expression.
## What an atmospheric world adds on top was written for Aurora and then copied
## for Rime - and the copy had quietly dropped the half the flight effects need.
## This is that half, once:
##
## - the authored [PlanetaryAtmosphereComposition] is configured against each
##   live generation and fed one body-local observation per accepted focus, so
##   the sky, fog, cloud shell and ambient fill follow altitude up to the
##   world's own atmosphere top and go orbital-dark above it;
## - [method get_atmosphere_weather_scalar], [method set_surface_atmosphere_state]
##   and [method clear_surface_atmosphere_state] are the optional seams
##   [PlanetaryAtmosphereFlightEffects] uses for wind drift, the cloud shell's
##   weather clock and the interior/exterior ambience cross-fade;
## - the surface-audio snapshot handed to the authored scene carries the
##   caller-smoothed interior blend and gusting wind when supplied.
##
## A world's subclass supplies only its profile, its expected scene class, its
## composition node path, its observation tuning and its fixed audio inputs.

var _atmosphere: PlanetaryAtmosphereComposition
var _atmosphere_generation := 0
var _last_atmosphere_result: Dictionary = {}
var _atmosphere_configure_count := 0
var _atmosphere_retire_count := 0
var _surface_audio_perspective: StringName = &"cockpit"
var _surface_audio_source_generation := 0
var _last_surface_audio_result: Dictionary = {}
## Caller-smoothed atmosphere state from [PlanetaryAtmosphereFlightEffects].
## Negative means "not supplied": audio falls back to the seated/on-foot
## perspective and the world's own wind reading, and the cloud shell stays at
## rest.
var _surface_audio_interior_blend := -1.0
var _surface_audio_wind_strength := -1.0
var _weather_clock_seconds := 0.0
var _last_surface_audio_altitude_m := -1.0


# --- per-world tuning (override) ----------------------------------------------


func _atmosphere_composition_path() -> NodePath:
	return NodePath("")


func _observation_view_direction_body_local() -> Vector3:
	return Vector3.FORWARD


func _observation_fog_path_distance_m() -> float:
	return 12_000.0


func _observation_weather_scalar() -> float:
	return 0.4


func _observation_cloud_scalar() -> float:
	return 0.5


## Fixed environment inputs of the world's surface-audio snapshot (for example
## `water_exposure_unitless`, or a default `wind_strength_unitless` that the
## flight effects' gusting wind replaces whenever it is supplied).
func _surface_audio_environment() -> Dictionary:
	return {"water_exposure_unitless": 0.0}


# --- shared seams ---------------------------------------------------------------


## The visit owner supplies seated/on-foot truth; streaming only forwards it.
func set_surface_audio_perspective(perspective: StringName) -> Dictionary:
	if perspective not in [&"cockpit", &"exterior"]:
		return {"accepted": false, "reason": &"invalid_ship_perspective"}
	_surface_audio_perspective = perspective
	return {"accepted": true, "reason": &"perspective_accepted"}


## The weather multiplier this bootstrap presents the world's atmosphere with,
## so wind drift samples exactly the wind the cloud shell is drawn moving with.
func get_atmosphere_weather_scalar() -> float:
	return _observation_weather_scalar()


## Accepts one tick of caller-smoothed atmosphere state: the interior blend
## (0 outside .. 1 sealed cabin), the gusting wind strength for exterior audio
## and the weather clock that advances the cloud shell's wind offset. Audio is
## re-presented immediately when the blend or wind moved, so a cross-fade keeps
## running even while the streaming focus is unchanged.
func set_surface_atmosphere_state(
		interior_blend: float, wind_strength: float, weather_clock_seconds: float
	) -> Dictionary:
	if not is_finite(interior_blend) or interior_blend > 1.0 \
			or not is_finite(wind_strength) or wind_strength > 1.0 \
			or not is_finite(weather_clock_seconds) or weather_clock_seconds < 0.0:
		return {"accepted": false, "reason": &"invalid_atmosphere_state"}
	var blend := interior_blend if interior_blend >= 0.0 else -1.0
	var wind := wind_strength if wind_strength >= 0.0 else -1.0
	var audible_change := absf(blend - _surface_audio_interior_blend) > 0.001 \
		or absf(wind - _surface_audio_wind_strength) > 0.005
	_surface_audio_interior_blend = blend
	_surface_audio_wind_strength = wind
	_weather_clock_seconds = weather_clock_seconds
	if audible_change and _last_surface_audio_altitude_m >= 0.0 \
			and is_instance_valid(_atmosphere):
		_present_surface_audio(_last_surface_audio_altitude_m)
	return {"accepted": true, "reason": &"atmosphere_state_accepted"}


func clear_surface_atmosphere_state() -> void:
	_surface_audio_interior_blend = -1.0
	_surface_audio_wind_strength = -1.0
	_weather_clock_seconds = 0.0


## The live atmosphere composition while the world is resident. Read-only
## identity: the streamed scene owns its lifetime, and a caller receives no
## authority to create, configure or retire it through this seam.
func get_atmosphere_composition() -> PlanetaryAtmosphereComposition:
	return _atmosphere if is_instance_valid(_atmosphere) else null


## The environment a viewport owner may present while the world is resident.
## Null whenever the composition is not configured against a live generation.
func get_scene_environment() -> Environment:
	if not is_instance_valid(_atmosphere):
		return null
	var world_environment := _atmosphere.get_world_environment()
	return world_environment.environment if world_environment != null else null


# --- PlanetaryStreamingBootstrap hooks --------------------------------------------


func _environment_result_key() -> String:
	return "atmosphere_presentation"


func _not_loaded_reason() -> StringName:
	return StringName("%s_not_loaded" % _world_stem())


func _on_generation_loaded(
		instance: Node3D,
		frame_generation: int,
		location_generation: int,
	) -> void:
	_retire_atmosphere(&"replacement_before_attach")
	_surface_audio_source_generation = 0
	var candidate := instance.get_node_or_null(
		_atmosphere_composition_path()
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
	_last_atmosphere_result = _presentation_result(
		false, StringName("%s_load_failed" % _world_stem()), {
			"streaming_reason": reason,
		}
	)


func _on_generation_unloaded() -> void:
	_retire_atmosphere(StringName("%s_unloaded" % _world_stem()))
	_surface_audio_perspective = &"cockpit"
	clear_surface_atmosphere_state()


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
		"view_direction_body_local": _observation_view_direction_body_local(),
		"fog_path_distance_m": _observation_fog_path_distance_m(),
		"speed_mps": 0.0,
		"weather_scalar": _observation_weather_scalar(),
		"cloud_scalar": _observation_cloud_scalar(),
		"caller_time_seconds": _weather_clock_seconds,
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
	if bool(presented.get("accepted", false)):
		_present_surface_audio(
			maxf(0.0, body_local_observer.length() - _body_radius_m())
		)
	return result.duplicate(true)


func _present_surface_audio(altitude: float) -> void:
	var world := get_loaded_instance()
	if not is_instance_valid(world) \
			or not world.has_method(&"present_surface_audio_snapshot"):
		return
	_last_surface_audio_altitude_m = altitude
	_surface_audio_source_generation += 1
	var snapshot := {
		"generation": _surface_audio_source_generation,
		"altitude_m": altitude,
		"weather_intensity_unitless": _observation_weather_scalar(),
		"day_night_unitless": 0.5,
		"settlement_activity_unitless": 0.0,
		"ship_perspective": _surface_audio_perspective,
	}
	var environment := _surface_audio_environment()
	for key: Variant in environment:
		snapshot[key] = environment[key]
	if _surface_audio_interior_blend >= 0.0:
		snapshot["interior_blend_unitless"] = _surface_audio_interior_blend
	if _surface_audio_wind_strength >= 0.0:
		snapshot["wind_strength_unitless"] = _surface_audio_wind_strength
	_last_surface_audio_result = world.call(
		&"present_surface_audio_snapshot", snapshot
	) as Dictionary


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
	snapshot["surface_audio"] = {
		"perspective": _surface_audio_perspective,
		"interior_blend": _surface_audio_interior_blend,
		"wind_strength": _surface_audio_wind_strength,
		"weather_clock_seconds": _weather_clock_seconds,
		"source_generation": _surface_audio_source_generation,
		"last_result": _last_surface_audio_result.duplicate(true),
	}


func _collect_presentation_contract_errors(
		errors: PackedStringArray,
		loaded_instance: Node3D,
	) -> void:
	if is_instance_valid(_atmosphere):
		if not is_instance_valid(loaded_instance) \
				or _atmosphere.get_parent() != loaded_instance:
			errors.append("%s atmosphere outlived its streamed generation" % _world_label())
	elif is_instance_valid(loaded_instance):
		# The location-loaded signal configures the composition synchronously,
		# so no stable resident snapshot may be missing it.
		errors.append("loaded %s generation is missing its atmosphere" % _world_label())


func _retire_atmosphere(reason: StringName) -> void:
	_surface_audio_source_generation = 0
	_last_surface_audio_altitude_m = -1.0
	_last_surface_audio_result.clear()
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


# --- helpers ----------------------------------------------------------------------


func _world_label() -> String:
	var label := str(_profile.get("display_label", ""))
	return label if not label.is_empty() else "Planetary"


func _world_stem() -> String:
	return _world_label().to_lower()


func _body_radius_m() -> float:
	return float(_profile.get("body_radius_meters", 0.0))
