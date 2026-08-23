class_name PlanetarySurfaceAudioEnvironmentAdapter
extends Node

## Audio-only bridge for detached Ember presentation snapshots.
##
## The caller supplies the already-decided policy result and detached solar /
## weather evidence. This adapter only derives a bounded exposure hint, fences
## source generations, and forwards the result to the two-voice playback binding.

signal state_committed(snapshot: Dictionary)

const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _binding: PlanetarySurfaceAudioPlaybackBinding
var _source_generation := -1
var _last_snapshot: Dictionary = {}


func configure(binding: PlanetarySurfaceAudioPlaybackBinding) -> Dictionary:
	if binding == null:
		return _result(false, &"missing_binding")
	if _binding != null:
		return _result(false, &"already_configured")
	_binding = binding
	return _result(true, &"configured")


func attach(
		atmosphere_profile_id: StringName,
		root_instance_id: int,
		frame_generation: int,
		location_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _binding == null:
		return _result(false, &"not_configured")
	var result := _binding.attach(
		atmosphere_profile_id,
		root_instance_id,
		frame_generation,
		location_generation,
		expected_attachment_generation
	)
	if bool(result.get("accepted", false)):
		_source_generation = -1
		_last_snapshot.clear()
	return result


func present_environment(
		environment_snapshot: Dictionary,
		policy_result: Dictionary,
		caller_physics_delta: float,
		expected_attachment_generation: int,
		expected_root_instance_id: int,
		expected_frame_generation: int,
		expected_location_generation: int
	) -> Dictionary:
	if _binding == null:
		return _result(false, &"not_configured")
	var decoded := _decode_environment(environment_snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_environment_snapshot")))
	var generation := int(decoded.get("generation", -1))
	if generation <= _source_generation:
		return _result(false, &"stale_environment_generation")
	var adapted_policy := _adapt_policy_result(
		policy_result,
		StringName(decoded.get("listener_context", &"exterior")),
		float(decoded.get("exposure_unitless", 0.0))
	)
	var result := _binding.present_policy_result(
		adapted_policy,
		caller_physics_delta,
		expected_attachment_generation,
		expected_root_instance_id,
		expected_frame_generation,
		expected_location_generation
	)
	if bool(result.get("accepted", false)):
		_source_generation = generation
		_last_snapshot = environment_snapshot.duplicate(true)
		state_committed.emit(get_snapshot())
	return result


func detach(reason: StringName, expected_attachment_generation: int) -> Dictionary:
	if _binding == null:
		return _result(false, &"not_configured")
	var result := _binding.detach(reason, expected_attachment_generation)
	if bool(result.get("accepted", false)):
		_source_generation = -1
		_last_snapshot.clear()
	return result


func get_snapshot() -> Dictionary:
	return {
		"source_generation": _source_generation,
		"last_environment": _last_snapshot.duplicate(true),
		"binding": _binding.get_state_snapshot() if _binding != null else {},
		"authority": {
			"weather_selection": false,
			"shelter_truth": false,
			"playback": false,
		},
	}.duplicate(true)


func _decode_environment(snapshot: Dictionary) -> Dictionary:
	if not snapshot.has("generation") or not snapshot.has("solar") or not snapshot.has("weather"):
		return _result(false, &"invalid_environment_schema")
	var generation: Variant = snapshot.get("generation")
	var solar := snapshot.get("solar") as Dictionary
	var weather := snapshot.get("weather") as Dictionary
	if not (generation is int) or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION \
			or solar == null or solar.is_empty() or weather == null:
		return _result(false, &"invalid_environment_snapshot")
	var storm: Variant = weather.get("intensity_unitless", NAN)
	var gust: Variant = weather.get("gust_factor_unitless", NAN)
	var shelter: Variant = weather.get("shelter_scalar", 0.0)
	var wind: Variant = weather.get("wind_velocity_mps", Vector3.ZERO)
	if not _finite_range(storm, 0.0, 1.0) or not _finite_range(gust, 0.0, 1.25) \
			or not _finite_range(shelter, 0.0, 1.0) or wind is not Vector3 \
			or not (wind as Vector3).is_finite():
		return _result(false, &"invalid_weather_snapshot")
	var shelter_factor := 1.0 - clampf(float(shelter), 0.0, 1.0) * 0.75
	var exposure := clampf(float(storm) * float(gust) * shelter_factor, 0.0, 1.0)
	var listener_context: StringName = &"exterior"
	if bool(snapshot.get("cabin_exposed", false)):
		listener_context = &"cabin"
	return {
		"accepted": true,
		"generation": int(generation),
		"exposure_unitless": exposure,
		"listener_context": listener_context,
	}.duplicate(true)


func _adapt_policy_result(
		policy_result: Dictionary,
		listener_context: StringName,
		exposure: float
	) -> Dictionary:
	var adapted := policy_result.duplicate(true)
	var evaluation := adapted.get("evaluation", {}) as Dictionary
	var inputs := evaluation.get("inputs", {}) as Dictionary
	var intensity := evaluation.get("intensity", {}) as Dictionary
	if listener_context == &"cabin":
		intensity["ambient_wind_unitless"] = 0.0
	else:
		intensity["ambient_wind_unitless"] = exposure
		intensity["recommended_intensity_unitless"] = minf(
			float(intensity.get("recommended_intensity_unitless", 0.0)), exposure
		)
	evaluation["inputs"] = inputs
	evaluation["intensity"] = intensity
	adapted["evaluation"] = evaluation
	return adapted


func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
			and float(value) >= minimum and float(value) <= maximum


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
