class_name PlanetarySurfaceHazardRuntime
extends RefCounted

## Caller-evidence hazard exposure for authored planetary surface hazards.
## This runtime produces bounded damage/recovery requests only; it never
## mutates health, moves an actor, or owns a recovery transition.

const ContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const HAZARD_RADIUS_M := 12.0
const MAX_DELTA_SECONDS := 10.0
const MAX_EXPOSURE := 1.0
const RECOVERY_EXPOSURE_THRESHOLD := 0.8
const EXPOSURE_RATE_PER_SECOND := 0.1
const DAMAGE_RATE_PER_SECOND := 0.4
const COOLING_RATE_PER_SECOND := 0.2

var _configured := false
var _hazards: Dictionary = {}
var _exposure: Dictionary = {}
var _weather_field: RefCounted


func configure(contract: PlanetarySurfaceNavigationContract) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if contract == null or not contract.is_definition_valid():
		return _result(false, &"invalid_navigation_contract")
	for hazard in contract.get_snapshot().get("hazards", []) as Array:
		var item := hazard as Dictionary
		var hazard_id := StringName(item.get("id", &""))
		_hazards[hazard_id] = item.duplicate(true)
		_exposure[hazard_id] = 0.0
	_configured = true
	return _result(true, &"configured")


func bind_weather_field(weather_field: RefCounted) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if weather_field == null or not bool(weather_field.call(&"is_configured")):
		return _result(false, &"weather_unavailable")
	_weather_field = weather_field
	return _result(true, &"weather_bound")


## Samples caller-owned weather at the hazard and scales exposure by authored
## storm intensity. Wind direction is returned as context, never applied.
func submit_weather_exposure(
		hazard_id: StringName,
		position: Variant,
		altitude_m: Variant,
		caller_time_seconds: Variant,
		exposure_scalar: Variant,
		delta_seconds: Variant,
		shelter_scalar: Variant = 0.0
	) -> Dictionary:
	if _weather_field == null:
		return _result(false, &"weather_unavailable")
	if not _finite_number(altitude_m) or not _finite_number(caller_time_seconds):
		return _result(false, &"invalid_weather_observation")
	if not _finite_range(shelter_scalar, 0.0, 1.0):
		return _result(false, &"invalid_shelter_scalar")
	var weather: Dictionary = _weather_field.call(
		&"sample", float(altitude_m), position, 0.0, float(caller_time_seconds)
	)
	if not bool(weather.get("accepted", false)):
		return _result(false, weather.get("reason", &"weather_sample_rejected") as StringName)
	var intensity := clampf(float(weather.get("weather_intensity_unitless", 0.0)), 0.0, 1.0)
	var gust := clampf(float(weather.get("weather_gust_factor_unitless", 1.0)), 0.0, 1.25)
	var multiplier := clampf(1.0 + intensity * gust, 1.0, 2.0)
	var shelter := float(shelter_scalar)
	var shelter_factor := 1.0 - shelter * 0.75
	var scaled := clampf(float(exposure_scalar) * multiplier * shelter_factor, 0.0, 1.0)
	var sampled := submit_exposure(hazard_id, position, scaled, delta_seconds)
	if bool(sampled.get("accepted", false)):
		var wind := weather.get("wind_velocity_mps", Vector3.ZERO) as Vector3
		sampled["weather"] = {
			"intensity_unitless": intensity,
			"gust_factor_unitless": gust,
			"exposure_multiplier": multiplier,
			"shelter_scalar": shelter,
			"shelter_factor": shelter_factor,
			"wind_velocity_mps": wind,
			"wind_direction": wind.normalized() if wind.length_squared() > 0.0 else Vector3.ZERO,
		}.duplicate(true)
	return sampled


## Evaluates one caller-owned hazard observation and returns transport-safe
## requests for the owning health/recovery system to decide and apply.
func submit_exposure(
		hazard_id: StringName,
		position: Variant,
		exposure_scalar: Variant,
		delta_seconds: Variant
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _hazards.has(hazard_id):
		return _result(false, &"unknown_hazard")
	if not _finite_vector(position):
		return _result(false, &"invalid_position")
	if not _finite_range(exposure_scalar, 0.0, 1.0):
		return _result(false, &"invalid_exposure_scalar")
	if not _finite_range(delta_seconds, 0.0, MAX_DELTA_SECONDS):
		return _result(false, &"invalid_delta_seconds")
	var hazard := _hazards[hazard_id] as Dictionary
	var target := hazard.get("position_body_local_m", Vector3.INF) as Vector3
	if (position as Vector3).distance_to(target) > HAZARD_RADIUS_M:
		return _result(false, &"hazard_out_of_range")
	var scalar := float(exposure_scalar)
	var delta := float(delta_seconds)
	var current := float(_exposure.get(hazard_id, 0.0))
	if scalar > 0.0:
		current = clampf(current + scalar * delta * EXPOSURE_RATE_PER_SECOND, 0.0, MAX_EXPOSURE)
	else:
		current = clampf(current - delta * COOLING_RATE_PER_SECOND, 0.0, MAX_EXPOSURE)
	_exposure[hazard_id] = current
	var damage := clampf(scalar * delta * DAMAGE_RATE_PER_SECOND, 0.0, 1.0)
	var recovery_id := StringName(hazard.get("recovery_id", &""))
	return _result(true, &"exposure_sampled", {
		"hazard_id": hazard_id,
		"hazard_kind": hazard.get("kind", &""),
		"exposure_unitless": current,
		"damage_request": {
			"requested": damage > 0.0,
			"amount_unitless": damage,
			"health_mutation": false,
		},
		"recovery_request": {
			"requested": current >= RECOVERY_EXPOSURE_THRESHOLD,
			"recovery_id": recovery_id,
			"hazard_id": hazard_id,
			"movement_mutation": false,
		},
	})


func get_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"hazard_ids": _hazards.keys(),
		"exposure": _exposure.duplicate(true),
		"hazard_radius_m": HAZARD_RADIUS_M,
		"authority": {
			"health": false,
			"movement": false,
			"recovery_transition": false,
			"terrain": false,
		},
		"weather_bound": _weather_field != null,
	}.duplicate(true)


func restore_snapshot(snapshot: Variant) -> Dictionary:
	if not _configured or not snapshot is Dictionary:
		return _result(false, &"invalid_hazard_snapshot")
	var saved := snapshot as Dictionary
	var saved_exposure_value: Variant = saved.get("exposure", {})
	if not saved_exposure_value is Dictionary:
		return _result(false, &"invalid_hazard_exposure")
	var saved_exposure := saved_exposure_value as Dictionary
	for hazard_id: StringName in _hazards.keys():
		var value := float(saved_exposure.get(hazard_id, 0.0))
		if not is_finite(value) or value < 0.0 or value > MAX_EXPOSURE:
			return _result(false, &"invalid_hazard_exposure")
		_exposure[hazard_id] = value
	return _result(true, &"hazard_restored")


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	if value is not float and value is not int:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _finite_vector(value: Variant) -> bool:
	if value is not Vector3:
		return false
	var vector := value as Vector3
	return vector.is_finite()


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := extra.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	result["runtime"] = get_snapshot()
	return result.duplicate(true)
