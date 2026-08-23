class_name PlanetarySurfaceAudioPlaybackBinding
extends Node

## Caller-driven two-voice playback adapter for PlanetarySurfaceAudioPolicy.
##
## The caller supplies one accepted detached policy result, physics delta, and
## exact attachment/root/frame/location generations. This node owns only its two
## non-positional voices and the retained equal-power fade. It never polls an
## actor, samples a position/context, advances itself, mutates AudioServer buses,
## or decides which world/profile is current.

signal state_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-surface-audio-playback-binding"
const POLICY_VERSION: StringName = &"planetary_surface_audio_v1"
const EQUATION_VERSION: StringName = &"density_max_airflow_hints_v1"
const AUDIO_BUS: StringName = &"Ambience"
const EXTERIOR_VOICE_PATH := NodePath("ExteriorVoice")
const INTERIOR_VOICE_PATH := NodePath("InteriorVoice")
const VOICE_PROFILE_IDS := {
	&"exterior": PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID,
	&"interior": PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID,
}
const VOICE_ROUTES: Array[StringName] = [&"exterior", &"interior"]
const CROSSFADE_SECONDS := 0.75
const MAX_CALLER_DELTA_SECONDS := 1.0
const SILENCE_DB := -80.0
const WIND_BASE_GAIN_DB := -9.0
const ENTRY_MAX_GAIN_DB := 3.0
const MAX_GAIN_DB := 24.0
const MIN_AUDIBLE_LINEAR := 0.0001
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const DETACH_REASONS: Array[StringName] = [
	&"caller_detached",
	&"profile_lost",
	&"root_lost",
	&"stream_unloaded",
	&"attachment_replaced",
	&"tree_exiting",
	&"catalog_contract_lost",
]
const POLICY_RESULT_KEYS := [
	"accepted", "reason", "configured", "profile_id", "evaluation",
]
const EVALUATION_KEYS := [
	"evaluation_schema_version", "profile_id", "policy_version",
	"equation_version", "inputs", "altitude", "routing", "gain", "mix",
	"intensity", "atmosphere_sample",
]
const AUTHORITY := {
	"renderer": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": true,
}
const ADJACENT_AUTHORITY := {
	"listener_context_truth": false,
	"grounded_truth": false,
	"position_or_altitude_sampling": false,
	"speed_sampling": false,
	"wind_or_weather_selection": false,
	"world_or_profile_selection": false,
	"streaming_lifecycle": false,
	"origin_shift_or_rebase": false,
	"audio_bus_level": false,
	"audio_bus_effects": false,
	"master_volume": false,
	"wall_clock": false,
	"process_cadence": false,
	"gameplay": false,
	"save": false,
	"network": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

var _exterior_voice: AudioStreamPlayer
var _interior_voice: AudioStreamPlayer
var _voice_instance_ids := {}
var _catalog: PlanetarySurfaceAudioCatalog
var _catalog_snapshot := {}
var _streams := {}
var _configured := false
var _initialized := false
var _tree_suspended := false
var _audio_available := false

var _attached := false
var _attachment_generation := 0
var _atmosphere_profile_id: StringName = &""
var _root_instance_id := 0
var _frame_generation := 0
var _location_generation := 0
var _paused := false

var _route_mix_unitless := 0.0
var _target_route_mix_unitless := 0.0
var _intensity_unitless := 0.0
var _target_intensity_unitless := 0.0
var _wind_intensity_unitless := 0.0
var _target_wind_intensity_unitless := 0.0
var _entry_intensity_unitless := 0.0
var _target_entry_intensity_unitless := 0.0
var _exterior_gain_db := SILENCE_DB
var _interior_gain_db := SILENCE_DB
var _last_policy_evaluation := {}
var _accepted_submission_count := 0
var _revision := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _lifecycle_active := false


func _ready() -> void:
	_cache_and_configure_voices()
	_initialized = true
	_tree_suspended = false


func _enter_tree() -> void:
	_tree_suspended = false
	if _initialized:
		call_deferred(&"_restore_voice_hierarchy_after_reentry")


func _exit_tree() -> void:
	_tree_suspended = true
	_lifecycle_active = true
	if _attached:
		_internal_detach(&"tree_exiting", true)
	else:
		_stop_and_detach_all_voices()
	_lifecycle_active = false


## Freezes one complete catalog. Configuration retains the two imported stream
## resources intentionally; public snapshots expose only detached value data.
func configure(catalog: PlanetarySurfaceAudioCatalog) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if _configured:
		return _result(false, &"already_configured")
	if not _initialized or not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"binding_unavailable")
	if catalog == null:
		return _result(false, &"missing_catalog")
	if not catalog.is_definition_valid() \
			or not bool(catalog.get_audit_report().get("valid", false)):
		return _result(false, &"invalid_catalog")
	if not _voice_hierarchy_is_valid():
		return _result(false, &"invalid_voice_hierarchy")
	var exterior := catalog.resolve_stream(
		PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID
	)
	var interior := catalog.resolve_stream(
		PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID
	)
	if exterior == null or interior == null or exterior == interior:
		return _result(false, &"catalog_resolution_failed")

	_mutation_active = true
	_catalog = catalog
	_catalog_snapshot = catalog.get_snapshot().duplicate(true)
	_streams = {
		&"exterior": exterior,
		&"interior": interior,
	}
	_configured = true
	_mutation_active = false
	_commit(&"configured")
	return _result(true, &"configured")


## Starts one fresh caller-owned attachment. The three upstream identities are
## opaque values: this binding compares them but never resolves or samples them.
func attach(
		atmosphere_profile_id: StringName,
		root_instance_id: int,
		frame_generation: int,
		location_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _binding_is_available():
		return _result(false, &"binding_unavailable")
	if expected_attachment_generation != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	if _attached:
		return _result(false, &"already_attached")
	if _attachment_generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	if atmosphere_profile_id.is_empty():
		return _result(false, &"invalid_profile_id")
	if root_instance_id <= 0:
		return _result(false, &"invalid_root_instance_id")
	if not _valid_upstream_generation(frame_generation) \
			or not _valid_upstream_generation(location_generation):
		return _result(false, &"invalid_upstream_generation")
	if not _catalog_contract_is_current():
		return _result(false, &"catalog_contract_lost")

	_mutation_active = true
	_attachment_generation += 1
	_attached = true
	_atmosphere_profile_id = atmosphere_profile_id
	_root_instance_id = root_instance_id
	_frame_generation = frame_generation
	_location_generation = location_generation
	_paused = false
	_reset_fade_state()
	_mutation_active = false
	_commit(&"attached")
	return _result(true, &"attached")


## Accepts exactly one successful detached PlanetarySurfaceAudioPolicy result.
## Target updates and fade advancement are one atomic caller tick.
func present_policy_result(
		policy_result: Dictionary,
		caller_physics_delta: float,
		expected_attachment_generation: int,
		expected_root_instance_id: int,
		expected_frame_generation: int,
		expected_location_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _attached:
		return _result(false, &"not_attached")
	if not _binding_is_available():
		return _result(false, &"binding_unavailable")
	var freshness_reason := _freshness_reason(
		expected_attachment_generation,
		expected_root_instance_id,
		expected_frame_generation,
		expected_location_generation
	)
	if freshness_reason != &"current":
		return _result(false, freshness_reason)
	if not is_finite(caller_physics_delta) \
			or caller_physics_delta < 0.0 \
			or caller_physics_delta > MAX_CALLER_DELTA_SECONDS:
		return _result(false, &"invalid_caller_delta")
	if not _catalog_contract_is_current():
		_mutation_active = true
		_internal_detach(&"catalog_contract_lost", true)
		_mutation_active = false
		_commit(&"catalog_contract_lost")
		return _result(false, &"catalog_contract_lost")
	var decoded := _decode_policy_result(policy_result)
	if not bool(decoded.get("accepted", false)):
		return _result(
			false,
			StringName(decoded.get("reason", &"invalid_policy_result"))
		)

	var evaluation := decoded.get("evaluation", {}) as Dictionary
	var targets := decoded.get("targets", {}) as Dictionary
	_mutation_active = true
	_target_route_mix_unitless = float(targets.get("route_mix_unitless", 0.0))
	_target_intensity_unitless = float(targets.get("intensity_unitless", 0.0))
	_exterior_gain_db = float(targets.get("exterior_gain_db", SILENCE_DB))
	_interior_gain_db = float(targets.get("interior_gain_db", SILENCE_DB))
	_target_wind_intensity_unitless = float(targets.get("wind_intensity_unitless", 0.0))
	_target_entry_intensity_unitless = float(targets.get("entry_intensity_unitless", 0.0))
	_last_policy_evaluation = evaluation.duplicate(true)
	var before := _fade_value_snapshot()
	if not _paused and caller_physics_delta > 0.0:
		var step := caller_physics_delta / CROSSFADE_SECONDS
		_route_mix_unitless = move_toward(
			_route_mix_unitless, _target_route_mix_unitless, step
		)
		_intensity_unitless = move_toward(
			_intensity_unitless, _target_intensity_unitless, step
		)
		_wind_intensity_unitless = move_toward(
			_wind_intensity_unitless, _target_wind_intensity_unitless, step
		)
		_entry_intensity_unitless = move_toward(
			_entry_intensity_unitless, _target_entry_intensity_unitless, step
		)
	var apply_result := _apply_voice_state()
	if not bool(apply_result.get("accepted", false)):
		_internal_detach(&"profile_lost", true)
		_mutation_active = false
		_commit(&"playback_backend_failed")
		return _result(false, &"playback_backend_failed")
	_accepted_submission_count += 1
	_mutation_active = false
	var reason: StringName = (
		&"target_accepted" if before == _fade_value_snapshot() else &"fade_advanced"
	)
	_commit(reason)
	return _result(true, reason)


func set_paused(paused: bool, expected_attachment_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _attached:
		return _result(false, &"not_attached")
	if not _binding_is_available():
		return _result(false, &"binding_unavailable")
	if expected_attachment_generation != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	if _paused == paused:
		return _result(true, &"unchanged")
	_mutation_active = true
	_paused = paused
	for voice in _voices():
		voice.stream_paused = paused and voice.playing
	_mutation_active = false
	_commit(&"paused" if paused else &"resumed")
	return _result(true, &"paused" if paused else &"resumed")


## Immediate safety teardown for caller-observed profile/root/streaming loss.
## Ordinary context changes must use present_policy_result() and crossfade.
func detach(
		reason: StringName,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _attached:
		return _result(false, &"not_attached")
	if not _binding_is_available():
		return _result(false, &"binding_unavailable")
	if expected_attachment_generation != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	if not DETACH_REASONS.has(reason) or reason == &"tree_exiting" \
			or reason == &"catalog_contract_lost":
		return _result(false, &"invalid_detach_reason")
	if _attachment_generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_mutation_active = true
	_internal_detach(reason, true)
	_mutation_active = false
	_commit(reason)
	return _result(true, reason)


func get_attachment_generation() -> int:
	return _attachment_generation


func get_state_snapshot() -> Dictionary:
	var route_weights := _route_weights()
	var target_weights := _route_weights(_target_route_mix_unitless)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"configured": _configured,
		"inside_tree": is_inside_tree(),
		"tree_suspended": _tree_suspended,
		"audio_driver": AudioServer.get_driver_name(),
		"audio_available": _audio_available,
		"attachment_generation": _attachment_generation,
		"revision": _revision,
		"attached": _attached,
		"attachment": {
			"atmosphere_profile_id": _atmosphere_profile_id,
			"root_instance_id": _root_instance_id,
			"frame_generation": _frame_generation,
			"location_generation": _location_generation,
		}.duplicate(true),
		"paused": _paused,
		"fade": {
			"crossfade_seconds": CROSSFADE_SECONDS,
			"route_mix_unitless": _route_mix_unitless,
			"target_route_mix_unitless": _target_route_mix_unitless,
			"intensity_unitless": _intensity_unitless,
			"target_intensity_unitless": _target_intensity_unitless,
			"wind_intensity_unitless": _wind_intensity_unitless,
			"target_wind_intensity_unitless": _target_wind_intensity_unitless,
			"entry_intensity_unitless": _entry_intensity_unitless,
			"target_entry_intensity_unitless": _target_entry_intensity_unitless,
			"exterior_gain_db": _exterior_gain_db,
			"interior_gain_db": _interior_gain_db,
			"wind_gain_db": _wind_gain_db_for_intensity(_wind_intensity_unitless),
			"target_wind_gain_db": _wind_gain_db_for_intensity(_target_wind_intensity_unitless),
			"entry_gain_db": _entry_gain_db_for_intensity(_entry_intensity_unitless),
			"target_entry_gain_db": _entry_gain_db_for_intensity(_target_entry_intensity_unitless),
			"exterior_route_weight_unitless": route_weights.exterior,
			"interior_route_weight_unitless": route_weights.interior,
			"target_exterior_route_weight_unitless": target_weights.exterior,
			"target_interior_route_weight_unitless": target_weights.interior,
			"equal_power_sum": (
				float(route_weights.exterior) * float(route_weights.exterior)
				+ float(route_weights.interior) * float(route_weights.interior)
			),
		}.duplicate(true),
		"voices": _voice_snapshot(),
		"accepted_submission_count": _accepted_submission_count,
		"last_policy_evaluation": _last_policy_evaluation.duplicate(true),
		"catalog": _catalog_snapshot.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _initialized:
		errors.append("binding has not initialized its fixed hierarchy")
	if not _voice_hierarchy_is_valid():
		errors.append("two-voice hierarchy drifted")
	if _configured and not _catalog_contract_is_current():
		errors.append("configured catalog contract drifted")
	if _attached:
		if _atmosphere_profile_id.is_empty() or _root_instance_id <= 0 \
				or not _valid_upstream_generation(_frame_generation) \
				or not _valid_upstream_generation(_location_generation):
			errors.append("active attachment identity is invalid")
	elif not _attachment_values_are_clear():
		errors.append("detached lifecycle retained upstream identity or fade state")
	if not _fade_state_is_bounded():
		errors.append("fade state is nonfinite or out of bounds")
	if not _authority_contract_is_exact():
		errors.append("authority roster drifted")
	if not _evidence_contract_is_exact():
		errors.append("evidence roster drifted")
	if _tree_suspended or not _audio_available or not _attached:
		for voice in _voices():
			if voice.playing or voice.stream != null or voice.stream_paused:
				errors.append("inactive or Dummy lifecycle retained a playback handle")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_state_snapshot(),
		"performance": {
			"audio_player_count": _voices().size(),
			"maximum_simultaneous_voices": 2,
			"maximum_polyphony": 2,
			"non_positional_voice_count": 2,
			"positional_voice_count": 0,
			"process_loop": false,
			"physics_process_loop": false,
		}.duplicate(true),
		"capabilities": {
			"accepted_policy_result_consumption": true,
			"caller_physics_delta_crossfade": true,
			"equal_power_route_weights": true,
			"gain_and_intensity_crossfade": true,
			"cabin_aliases_interior": true,
			"exact_attachment_root_frame_location_freshness": true,
			"immediate_safety_detach": true,
			"dummy_driver_safe": true,
			"native_audibility_proven": false,
		}.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func _decode_policy_result(policy_result: Dictionary) -> Dictionary:
	if not _has_exact_keys(policy_result, POLICY_RESULT_KEYS) \
			or policy_result.get("accepted") is not bool \
			or not bool(policy_result.get("accepted", false)) \
			or policy_result.get("reason") is not StringName \
			or policy_result.get("reason") != &"evaluated" \
			or policy_result.get("configured") is not bool \
			or not bool(policy_result.get("configured", false)) \
			or policy_result.get("profile_id") is not StringName \
			or policy_result.get("profile_id") != _atmosphere_profile_id \
			or policy_result.get("evaluation") is not Dictionary:
		return {"accepted": false, "reason": &"invalid_policy_result"}
	var evaluation := policy_result.get("evaluation") as Dictionary
	if not _has_exact_keys(evaluation, EVALUATION_KEYS) \
			or evaluation.get("evaluation_schema_version") != 1 \
			or evaluation.get("profile_id") != _atmosphere_profile_id \
			or evaluation.get("policy_version") != POLICY_VERSION \
			or evaluation.get("equation_version") != EQUATION_VERSION:
		return {"accepted": false, "reason": &"policy_identity_mismatch"}
	var inputs := evaluation.get("inputs") as Dictionary
	var routing := evaluation.get("routing") as Dictionary
	var gain := evaluation.get("gain") as Dictionary
	var mix := evaluation.get("mix") as Dictionary
	var intensity := evaluation.get("intensity") as Dictionary
	if inputs == null or routing == null or gain == null or mix == null \
			or intensity == null or evaluation.get("altitude") is not Dictionary \
			or evaluation.get("atmosphere_sample") is not Dictionary:
		return {"accepted": false, "reason": &"invalid_policy_schema"}
	var context: Variant = inputs.get("listener_context")
	if context is not StringName or context not in [&"exterior", &"interior", &"cabin"]:
		return {"accepted": false, "reason": &"invalid_listener_context"}
	var uses_interior: bool = context != &"exterior"
	var expected_route: StringName = &"interior" if uses_interior else &"exterior"
	var expected_id: StringName = (
		PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID if uses_interior
		else PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID
	)
	var available := routing.get("available_profile_ids") as Dictionary
	if available == null \
			or routing.get("selected_route") != expected_route \
			or routing.get("selected_audio_profile_id") != expected_id \
			or routing.get("listener_context") != context \
			or routing.get("profile_id_resolved") != false \
			or routing.get("playback_requested") != false \
			or routing.get("cabin_aliases_interior") != (context == &"cabin") \
			or available.get("exterior") \
				!= PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID \
			or available.get("interior") \
				!= PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID:
		return {"accepted": false, "reason": &"invalid_policy_route"}
	if not _mix_matches_route(mix, uses_interior):
		return {"accepted": false, "reason": &"invalid_policy_mix"}
	var exterior_gain: Variant = gain.get("authored_exterior_gain_db")
	var attenuation: Variant = gain.get("authored_interior_attenuation_db")
	var selected_gain: Variant = gain.get("recommended_gain_db")
	var recommended_intensity: Variant = intensity.get(
		"recommended_intensity_unitless"
	)
	if not _finite_range(exterior_gain, SILENCE_DB, MAX_GAIN_DB) \
			or not _finite_range(attenuation, SILENCE_DB, 0.0) \
			or not _finite_range(selected_gain, SILENCE_DB, MAX_GAIN_DB) \
			or not _finite_range(recommended_intensity, 0.0, 1.0):
		return {"accepted": false, "reason": &"invalid_policy_gain_or_intensity"}
	var expected_interior_gain := clampf(
		float(exterior_gain) + float(attenuation), SILENCE_DB, MAX_GAIN_DB
	)
	var expected_selected_gain := (
		expected_interior_gain if uses_interior else float(exterior_gain)
	)
	if not is_equal_approx(float(selected_gain), expected_selected_gain):
		return {"accepted": false, "reason": &"policy_gain_contract_mismatch"}
	var ambient_wind: Variant = intensity.get("ambient_wind_unitless")
	if not _finite_range(ambient_wind, 0.0, 1.0):
		return {"accepted": false, "reason": &"invalid_wind_route"}
	var wind_active: bool = context == &"exterior" and float(ambient_wind) > 0.0
	var wind_gain_db := SILENCE_DB
	if wind_active:
		wind_gain_db = minf(
			WIND_BASE_GAIN_DB + linear_to_db(float(ambient_wind)),
			WIND_BASE_GAIN_DB
		)
	var entry_sample: Variant = (evaluation.get("atmosphere_sample") as Dictionary).get("entry_effect_intensity")
	if not _finite_range(entry_sample, 0.0, 1.0):
		return {"accepted": false, "reason": &"invalid_entry_intensity"}
	return {
		"accepted": true,
		"reason": &"decoded",
		"evaluation": evaluation.duplicate(true),
		"targets": {
			"route_mix_unitless": 1.0 if uses_interior else 0.0,
			"intensity_unitless": float(recommended_intensity),
			"exterior_gain_db": float(exterior_gain),
			"interior_gain_db": expected_interior_gain,
			"wind_gain_db": wind_gain_db,
			"wind_intensity_unitless": float(ambient_wind) if not uses_interior else 0.0,
			"entry_intensity_unitless": float(entry_sample) if not uses_interior else 0.0,
		}.duplicate(true),
	}


func _mix_matches_route(mix: Dictionary, uses_interior: bool) -> bool:
	return _finite_range(mix.get("exterior_route_unitless"), 0.0, 1.0) \
		and _finite_range(mix.get("interior_route_unitless"), 0.0, 1.0) \
		and float(mix.get("exterior_route_unitless")) \
			== (0.0 if uses_interior else 1.0) \
		and float(mix.get("interior_route_unitless")) \
			== (1.0 if uses_interior else 0.0) \
		and mix.get("instantaneous_endpoints_only") is bool \
		and bool(mix.get("instantaneous_endpoints_only"))


func _apply_voice_state() -> Dictionary:
	if not _attached or _tree_suspended or not _audio_available:
		_stop_and_detach_all_voices()
		return {"accepted": true, "reason": &"silent_backend"}
	var weights := _route_weights()
	var desired_linear := {
		&"exterior": _intensity_unitless * (
			db_to_linear(_exterior_gain_db)
			+ db_to_linear(WIND_BASE_GAIN_DB) * _wind_intensity_unitless
			+ db_to_linear(ENTRY_MAX_GAIN_DB) * _entry_intensity_unitless
		) * float(weights.exterior),
		&"interior": _intensity_unitless * db_to_linear(_interior_gain_db) \
			* float(weights.interior),
	}
	for route in VOICE_ROUTES:
		var voice := _voice_for_route(route)
		var stream := _streams.get(route) as AudioStreamWAV
		var linear_gain := float(desired_linear.get(route, 0.0))
		voice.volume_db = (
			clampf(linear_to_db(linear_gain), SILENCE_DB, MAX_GAIN_DB)
			if linear_gain > 0.0 else SILENCE_DB
		)
		if linear_gain <= MIN_AUDIBLE_LINEAR:
			_stop_and_detach(voice)
			continue
		if voice.stream != stream:
			voice.stop()
			voice.stream = stream
		if not voice.playing:
			voice.play()
			if not voice.playing:
				_stop_and_detach(voice)
				return {"accepted": false, "reason": &"playback_request_failed"}
		voice.stream_paused = _paused
	return {"accepted": true, "reason": &"voice_state_applied"}


func _route_weights(mix: float = _route_mix_unitless) -> Dictionary:
	var safe_mix := clampf(mix, 0.0, 1.0)
	return {
		"exterior": sqrt(1.0 - safe_mix),
		"interior": sqrt(safe_mix),
	}


func _voice_snapshot() -> Dictionary:
	var weights := _route_weights()
	var report := {}
	for route in VOICE_ROUTES:
		var voice := _voice_for_route(route)
		var base_gain := _exterior_gain_db if route == &"exterior" else _interior_gain_db
		var weight := float(weights.get(route, 0.0))
		var effective_linear := _intensity_unitless * (
			db_to_linear(base_gain) + (
				db_to_linear(WIND_BASE_GAIN_DB) * _wind_intensity_unitless
				+ db_to_linear(ENTRY_MAX_GAIN_DB) * _entry_intensity_unitless
				if route == &"exterior" else 0.0
		)
		) * weight
		report[route] = {
			"node_name": voice.name if voice != null else &"",
			"node_path": str(voice.get_path()) if voice != null and voice.is_inside_tree() else "",
			"player_instance_id": voice.get_instance_id() if voice != null else 0,
			"expected_player_instance_id": int(_voice_instance_ids.get(route, 0)),
			"profile_id": VOICE_PROFILE_IDS[route],
			"bus": voice.bus if voice != null else &"",
			"max_polyphony": voice.max_polyphony if voice != null else 0,
			"playing": voice.playing if voice != null else false,
			"stream_paused": voice.stream_paused if voice != null else false,
			"stream_attached": voice.stream != null if voice != null else false,
			"stream_instance_id": voice.stream.get_instance_id() \
				if voice != null and voice.stream != null else 0,
			"route_weight_unitless": weight,
			"effective_linear_gain": effective_linear,
			"expected_volume_db": clampf(
				linear_to_db(effective_linear), SILENCE_DB, MAX_GAIN_DB
			) if effective_linear > 0.0 else SILENCE_DB,
			"actual_volume_db": voice.volume_db if voice != null else SILENCE_DB,
		}.duplicate(true)
	return report.duplicate(true)


func _cache_and_configure_voices() -> void:
	_exterior_voice = get_node_or_null(EXTERIOR_VOICE_PATH) as AudioStreamPlayer
	_interior_voice = get_node_or_null(INTERIOR_VOICE_PATH) as AudioStreamPlayer
	_audio_available = AudioServer.get_driver_name() != "Dummy"
	_voice_instance_ids.clear()
	for route in VOICE_ROUTES:
		var voice := _voice_for_route(route)
		if voice == null:
			continue
		voice.autoplay = false
		voice.max_polyphony = 1
		voice.pitch_scale = 1.0
		voice.volume_db = SILENCE_DB
		voice.stream_paused = false
		voice.stop()
		voice.stream = null
		_voice_instance_ids[route] = voice.get_instance_id()
	set_process(false)
	set_physics_process(false)


func _restore_voice_hierarchy_after_reentry() -> void:
	if not _initialized or not is_inside_tree() or is_queued_for_deletion():
		return
	_lifecycle_active = true
	_cache_and_configure_voices()
	_tree_suspended = false
	_lifecycle_active = false


func _voice_hierarchy_is_valid() -> bool:
	if _exterior_voice == null or _interior_voice == null \
			or _exterior_voice == _interior_voice:
		return false
	var ordinary := find_children("*", "AudioStreamPlayer", true, false)
	if ordinary.size() != 2 \
			or not find_children("*", "AudioStreamPlayer2D", true, false).is_empty() \
			or not find_children("*", "AudioStreamPlayer3D", true, false).is_empty():
		return false
	for route in VOICE_ROUTES:
		var voice := _voice_for_route(route)
		if voice.get_parent() != self or voice.bus != AUDIO_BUS \
				or voice.max_polyphony != 1 or voice.autoplay \
				or not is_equal_approx(voice.pitch_scale, 1.0) \
				or int(_voice_instance_ids.get(route, 0)) != voice.get_instance_id():
			return false
	return true


func _catalog_contract_is_current() -> bool:
	if _catalog == null or not is_instance_valid(_catalog) \
			or not _catalog.is_definition_valid() \
			or _catalog.get_snapshot() != _catalog_snapshot:
		return false
	for route in VOICE_ROUTES:
		var expected := _streams.get(route) as AudioStreamWAV
		var resolved := _catalog.resolve_stream(VOICE_PROFILE_IDS[route])
		if expected == null or resolved == null or resolved != expected:
			return false
	return true


func _binding_is_available() -> bool:
	return _initialized and is_inside_tree() and not _tree_suspended \
		and not is_queued_for_deletion() and _voice_hierarchy_is_valid()


func _freshness_reason(
		expected_attachment_generation: int,
		expected_root_instance_id: int,
		expected_frame_generation: int,
		expected_location_generation: int
	) -> StringName:
	if expected_attachment_generation != _attachment_generation:
		return &"stale_attachment_generation"
	if expected_root_instance_id != _root_instance_id:
		return &"stale_root_instance"
	if expected_frame_generation != _frame_generation:
		return &"stale_frame_generation"
	if expected_location_generation != _location_generation:
		return &"stale_location_generation"
	return &"current"


func _internal_detach(reason: StringName, advance_generation: bool) -> void:
	_stop_and_detach_all_voices()
	if advance_generation and _attachment_generation < MAX_SAFE_GENERATION:
		_attachment_generation += 1
	_attached = false
	_atmosphere_profile_id = &""
	_root_instance_id = 0
	_frame_generation = 0
	_location_generation = 0
	_paused = false
	_last_policy_evaluation.clear()
	_reset_fade_state()


func _reset_fade_state() -> void:
	_route_mix_unitless = 0.0
	_target_route_mix_unitless = 0.0
	_intensity_unitless = 0.0
	_target_intensity_unitless = 0.0
	_wind_intensity_unitless = 0.0
	_target_wind_intensity_unitless = 0.0
	_entry_intensity_unitless = 0.0
	_target_entry_intensity_unitless = 0.0
	_exterior_gain_db = SILENCE_DB
	_interior_gain_db = SILENCE_DB


func _stop_and_detach_all_voices() -> void:
	for voice in _voices():
		_stop_and_detach(voice)


func _stop_and_detach(voice: AudioStreamPlayer) -> void:
	if voice == null or not is_instance_valid(voice):
		return
	voice.stop()
	voice.stream_paused = false
	voice.stream = null
	voice.volume_db = SILENCE_DB


func _voices() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	if _exterior_voice != null and is_instance_valid(_exterior_voice):
		result.append(_exterior_voice)
	if _interior_voice != null and is_instance_valid(_interior_voice):
		result.append(_interior_voice)
	return result


func _voice_for_route(route: StringName) -> AudioStreamPlayer:
	return _exterior_voice if route == &"exterior" else _interior_voice


func _attachment_values_are_clear() -> bool:
	return _atmosphere_profile_id.is_empty() and _root_instance_id == 0 \
		and _frame_generation == 0 and _location_generation == 0 \
		and not _paused and _last_policy_evaluation.is_empty() \
		and _fade_value_snapshot() == {
			"route": 0.0, "target_route": 0.0,
			"intensity": 0.0, "target_intensity": 0.0,
			"wind_intensity": 0.0, "target_wind_intensity": 0.0,
			"entry_intensity": 0.0, "target_entry_intensity": 0.0,
			"exterior_gain": SILENCE_DB, "interior_gain": SILENCE_DB,
			"wind_gain": SILENCE_DB,
		}


func _fade_value_snapshot() -> Dictionary:
	return {
		"route": _route_mix_unitless,
		"target_route": _target_route_mix_unitless,
		"intensity": _intensity_unitless,
		"target_intensity": _target_intensity_unitless,
		"wind_intensity": _wind_intensity_unitless,
		"target_wind_intensity": _target_wind_intensity_unitless,
		"entry_intensity": _entry_intensity_unitless,
		"target_entry_intensity": _target_entry_intensity_unitless,
		"exterior_gain": _exterior_gain_db,
		"interior_gain": _interior_gain_db,
		"wind_gain": _wind_gain_db_for_intensity(_wind_intensity_unitless),
	}


func _fade_state_is_bounded() -> bool:
	return _finite_range(_route_mix_unitless, 0.0, 1.0) \
		and _finite_range(_target_route_mix_unitless, 0.0, 1.0) \
		and _finite_range(_intensity_unitless, 0.0, 1.0) \
		and _finite_range(_target_intensity_unitless, 0.0, 1.0) \
		and _finite_range(_wind_intensity_unitless, 0.0, 1.0) \
		and _finite_range(_target_wind_intensity_unitless, 0.0, 1.0) \
		and _finite_range(_entry_intensity_unitless, 0.0, 1.0) \
		and _finite_range(_target_entry_intensity_unitless, 0.0, 1.0) \
		and _finite_range(_exterior_gain_db, SILENCE_DB, MAX_GAIN_DB) \
		and _finite_range(_interior_gain_db, SILENCE_DB, MAX_GAIN_DB) \
		and _finite_range(_wind_gain_db_for_intensity(_wind_intensity_unitless), SILENCE_DB, 0.0)


func _wind_gain_db_for_intensity(intensity: float) -> float:
	return SILENCE_DB if intensity <= 0.0 else minf(
		WIND_BASE_GAIN_DB + linear_to_db(intensity), WIND_BASE_GAIN_DB
	)


func _entry_gain_db_for_intensity(intensity: float) -> float:
	return 0.0 if intensity <= 0.0 else linear_to_db(
		1.0 + db_to_linear(ENTRY_MAX_GAIN_DB) * intensity
	)


func _authority_contract_is_exact() -> bool:
	if AUTHORITY.size() != 12 or ADJACENT_AUTHORITY.size() != 16:
		return false
	for key: String in AUTHORITY:
		if AUTHORITY[key] is not bool \
				or bool(AUTHORITY[key]) != (key == "audio"):
			return false
	for key: String in ADJACENT_AUTHORITY:
		if ADJACENT_AUTHORITY[key] is not bool or bool(ADJACENT_AUTHORITY[key]):
			return false
	return true


func _evidence_contract_is_exact() -> bool:
	return EVIDENCE.size() == 4 \
		and EVIDENCE.get("content_class") == &"NEW" \
		and EVIDENCE.get("status") == &"modern_interpretation" \
		and EVIDENCE.get("source_bounded") == false \
		and EVIDENCE.get("confidence") == &"none"


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active or _lifecycle_active


func _commit(reason: StringName) -> void:
	_revision += 1
	var snapshot := get_state_snapshot()
	_signal_dispatch_active = true
	state_committed.emit(reason, snapshot.duplicate(true))
	_signal_dispatch_active = false


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"attached": _attached,
		"attachment_generation": _attachment_generation,
		"revision": _revision,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result.duplicate(true)


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


static func _valid_upstream_generation(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_GENERATION
