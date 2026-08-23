class_name EmberPlanetarySurfaceProductionBinding
extends Node

## Retained Ember composition for the caller-owned planetary surface systems.
## The Ember host still owns lifecycle and actors; this node only keeps one
## generation-fenced set of planetary runtimes and forwards observations.

const AdapterScript := preload("res://scripts/world/planetary_surface_activity_reward_adapter.gd")
const ActivityRuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const NavigationScript := preload("res://scripts/world/planetary_surface_navigation_runtime.gd")
const NavigationContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const HazardScript := preload("res://scripts/world/planetary_surface_hazard_runtime.gd")
const WeatherScript := preload("res://scripts/world/planetary_weather_field.gd")
const WeatherProfile := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")
const WaterPresentationScript := preload("res://scripts/world/planetary_water_presentation.gd")
const WaterScript := preload("res://scripts/world/planetary_water_contact_runtime.gd")
const WaterContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")
const LandmarkScript := preload("res://scripts/world/planetary_activity_landmark_runtime.gd")
const LandmarkContractScript := preload("res://scripts/world/planetary_activity_landmark_cluster_contract.gd")
const SettlementScript := preload("res://scripts/world/planetary_settlement_interaction_runtime.gd")
const SettlementContractScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
const SettlementPracticalScript := preload("res://scripts/world/planetary_settlement_practical_presentation.gd")
const SurfaceAudioBindingScene := preload("res://scenes/audio/planetary_surface_audio_playback_binding.tscn")
const SurfaceAudioAdapterScript := preload("res://scripts/audio/planetary_surface_audio_environment_adapter.gd")
const SurfaceAudioPolicyScript := preload("res://scripts/world/planetary_surface_audio_policy.gd")
const SurfaceAudioCatalog := preload("res://assets/audio/planetary/temperate_surface_audio_catalog.tres")

enum State { IDLE, BOUND, DETACHED }

var _state := State.IDLE
var _host: Object
var _host_generation := -1
var _attachment_generation := -1
var _composition_generation := 0
var _adapter: RefCounted
var _navigation: RefCounted
var _hazard: RefCounted
var _weather: RefCounted
var _solar_phase: Dictionary = {}
var _weather_observation: Dictionary = {}
var _water_presentation: Node
var _water: RefCounted
var _landmarks: RefCounted
var _settlement: RefCounted
var _settlement_practicals: Dictionary = {}
var _surface_audio_binding: Node
var _surface_audio_adapter: Node
var _surface_audio_policy: RefCounted
var _surface_audio_generation := 0
var _surface_audio_altitude_m := 0.0
var _surface_audio_exposure := 0.0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_water_presentation = WaterPresentationScript.new() as Node
	_water_presentation.name = "OwnedPlanetaryWaterPresentation"
	add_child(_water_presentation)
	_water_presentation.call(&"configure")
	_surface_audio_binding = SurfaceAudioBindingScene.instantiate()
	_surface_audio_binding.name = "OwnedPlanetarySurfaceAudioBinding"
	add_child(_surface_audio_binding)
	_surface_audio_adapter = SurfaceAudioAdapterScript.new() as Node
	_surface_audio_adapter.name = "OwnedPlanetarySurfaceAudioAdapter"
	add_child(_surface_audio_adapter)
	_surface_audio_binding.call(&"configure", SurfaceAudioCatalog)
	_surface_audio_adapter.call(&"configure", _surface_audio_binding)


func configure(
		host: Object,
		director: ActivityDirector,
		reward_sink: Callable,
		expected_generation: int = 0
	) -> Dictionary:
	if _state != State.IDLE or host == null or not is_instance_valid(host):
		return _result(false, &"composition_unavailable")
	if not host.has_method(&"get_generation") or not host.has_method(&"get_attachment_generation"):
		return _result(false, &"host_generation_api_incomplete")
	var generation := int(host.call(&"get_generation"))
	if generation != expected_generation and expected_generation != 0:
		return _result(false, &"stale_host_generation")
	_host = host
	_host_generation = generation
	_attachment_generation = int(host.call(&"get_attachment_generation"))
	_navigation = NavigationScript.new()
	var navigation_contract := NavigationContractScript.new()
	var configured: Dictionary = _navigation.call(&"configure", navigation_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"navigation_configuration_rejected")
	_hazard = HazardScript.new()
	configured = _hazard.call(&"configure", navigation_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"hazard_configuration_rejected")
	_weather = WeatherScript.new()
	configured = _weather.call(&"configure", WeatherProfile)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"weather_configuration_rejected")
	configured = _hazard.call(&"bind_weather_field", _weather)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"weather_binding_rejected")
	_surface_audio_policy = SurfaceAudioPolicyScript.new()
	configured = _surface_audio_policy.call(&"configure", WeatherProfile)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"surface_audio_policy_rejected")
	_water = WaterScript.new()
	configured = _water.call(&"configure", WaterContractScript.new())
	if not bool(configured.get("accepted", false)):
		return _result(false, &"water_configuration_rejected")
	_landmarks = LandmarkScript.new()
	configured = _landmarks.call(&"configure", LandmarkContractScript.new())
	if not bool(configured.get("accepted", false)):
		return _result(false, &"landmark_configuration_rejected")
	_settlement = SettlementScript.new()
	var settlement_contract := SettlementContractScript.new()
	configured = _settlement.call(&"configure", settlement_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"settlement_configuration_rejected")
	_configure_settlement_practicals(settlement_contract.get_snapshot())
	_adapter = AdapterScript.new()
	var runtime := ActivityRuntimeScript.new()
	var bound: Dictionary = _adapter.call(&"bind", host, runtime, director, reward_sink)
	if not bool(bound.get("accepted", false)):
		return _result(false, bound.get("reason", &"activity_binding_rejected") as StringName)
	for binding in [
		_adapter.call(&"bind_surface_hazard", _hazard),
		_adapter.call(&"bind_surface_water", _water),
		_adapter.call(&"bind_activity_landmarks", _landmarks),
		_adapter.call(&"bind_settlement", _settlement),
	]:
		if not bool(binding.get("accepted", false)):
			return _result(false, binding.get("reason", &"runtime_binding_rejected") as StringName)
	var audio_attach: Dictionary = _surface_audio_adapter.call(
		&"attach", _surface_audio_policy.get_snapshot().get("profile_id", &""),
		maxi(1, absi(host.get_instance_id())), 1, 1,
		_surface_audio_binding.call(&"get_attachment_generation")
	)
	if not bool(audio_attach.get("accepted", false)):
		return _result(false, &"surface_audio_attach_rejected")
	_composition_generation += 1
	_state = State.BOUND
	return _result(true, &"composition_bound")


func start_surface_activity_sequence(activity_ids: Array[StringName]) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _adapter.call(&"start_surface_activity_sequence", activity_ids, _navigation)


func discover_settlements(position: Variant, radius_m: Variant) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _adapter.call(&"discover_settlements", position, radius_m)


func enter_settlement(structure_id: StringName, position: Variant) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _adapter.call(&"submit_settlement_entry", structure_id, position, _attachment_generation)


func submit_hazard_exposure(hazard_id: StringName, position: Variant, exposure: float, delta_seconds: float) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _adapter.call(&"submit_surface_hazard_exposure", hazard_id, position, exposure, delta_seconds)


func submit_weather_exposure(
		hazard_id: StringName,
		position: Variant,
		altitude_m: float,
		caller_time_seconds: float,
		exposure: float,
		delta_seconds: float,
		shelter_scalar: float
	) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	var result: Dictionary = _hazard.call(
		&"submit_weather_exposure", hazard_id, position, altitude_m,
		caller_time_seconds, exposure, delta_seconds, shelter_scalar
	)
	if bool(result.get("accepted", false)):
		_weather_observation = result.get("weather", {}).duplicate(true)
		_surface_audio_altitude_m = altitude_m
		_surface_audio_exposure = clampf(exposure, 0.0, 1.0)
		_surface_audio_generation += 1
		_present_surface_audio()
		_apply_water_presentation()
	return result


func submit_solar_observation(
		surface_up: Variant, direction_to_sun: Variant, caller_time_seconds: float
	) -> Dictionary:
	if not _live() or not surface_up is Vector3 or not direction_to_sun is Vector3:
		return _result(false, &"invalid_solar_observation")
	var up := surface_up as Vector3
	var sun := direction_to_sun as Vector3
	if not up.is_finite() or not sun.is_finite() or up.length_squared() <= 0.0 \
			or sun.length_squared() <= 0.0 or not is_finite(caller_time_seconds) \
			or caller_time_seconds < 0.0:
		return _result(false, &"invalid_solar_observation")
	var elevation := clampf(up.normalized().dot(sun.normalized()), -1.0, 1.0)
	var state: StringName = &"night"
	var twilight := 0.0
	if elevation > 0.0:
		state = &"daylight"
	elif elevation > -0.104528:
		state = &"twilight"
		twilight = clampf(1.0 + elevation / 0.104528, 0.0, 1.0)
	_solar_phase = {
		"state": state, "sun_elevation_sine": elevation,
		"twilight_factor_unitless": twilight,
		"caller_time_seconds": caller_time_seconds,
	}.duplicate(true)
	_apply_settlement_practicals()
	_surface_audio_generation += 1
	_present_surface_audio()
	_apply_water_presentation()
	return _result(true, &"solar_observation_accepted")


func apply_graphics_profile(profile: StringName) -> Dictionary:
	if not _live() or profile not in [&"low", &"medium", &"high"]:
		return _result(false, &"invalid_graphics_profile")
	_water_presentation.call(&"apply_graphics_profile", profile)
	for practical: Node in _settlement_practicals.values():
		practical.call(&"apply_graphics_profile", profile)
	return _result(true, &"graphics_profile_applied")


func _present_surface_audio() -> void:
	if _surface_audio_adapter == null or _surface_audio_policy == null \
			or _solar_phase.is_empty() or _weather_observation.is_empty():
		return
	var shelter := float(_weather_observation.get("shelter_scalar", 0.0))
	var context: StringName = &"cabin" if shelter >= 0.75 else &"exterior"
	var policy_result: Dictionary = _surface_audio_policy.call(&"evaluate", {
		"altitude_m": _surface_audio_altitude_m,
		"listener_context": context,
		"grounded": false,
		"speed_mps": 0.0,
		"ambient_wind_scalar_unitless": 1.0,
	})
	var environment := {
		"generation": _surface_audio_generation,
		"solar": _solar_phase.duplicate(true),
		"weather": _weather_observation.duplicate(true),
		"cabin_exposed": context == &"cabin",
	}.duplicate(true)
	_surface_audio_adapter.call(
		&"present_environment", environment, policy_result, 0.0,
		_surface_audio_binding.call(&"get_attachment_generation"),
		maxi(1, absi(_host.get_instance_id())), 1, 1
	)


func _apply_water_presentation() -> void:
	if _water_presentation == null or _solar_phase.is_empty() or _weather_observation.is_empty():
		return
	var solar_recipe := {
		"sun_energy_unitless": clampf(float(_solar_phase.get("sun_elevation_sine", 0.0)), 0.0, 1.0),
	}
	_water_presentation.call(
		&"apply_presentation_recipe", solar_recipe, _weather_observation
	)


func submit_water_contact(position: Variant, depth_m: float, velocity_mps: Variant, delta_seconds: float) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _water.call(
		&"sample_contact", depth_m, velocity_mps, delta_seconds, _attachment_generation
	)


func enter_water(position: Variant) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _water.call(&"enter_water", position, _attachment_generation)


func detach() -> Dictionary:
	if _state != State.BOUND or not _host_current():
		return _result(false, &"composition_not_bound")
	var activity: StringName = _adapter.get_snapshot().get("state", &"idle") as StringName
	if activity in [&"active", &"ready"]:
		var detached: Dictionary = _adapter.call(&"detach")
		if not bool(detached.get("accepted", false)) and activity == &"active":
			return detached
	var settlement_snapshot := _settlement.call(&"get_snapshot") as Dictionary
	if settlement_snapshot.get("state", &"idle") == &"inside":
		_settlement.call(&"detach")
	for practical: Node in _settlement_practicals.values():
		practical.call(&"detach")
	var water_snapshot := _water.call(&"get_snapshot") as Dictionary
	if water_snapshot.get("state", &"idle") == &"in_water":
		_water.call(&"detach")
	if _surface_audio_adapter != null:
		_surface_audio_adapter.call(
			&"detach", &"caller_detached",
			_surface_audio_binding.call(&"get_attachment_generation")
		)
	_state = State.DETACHED
	return _result(true, &"composition_detached")


func reenter() -> Dictionary:
	if _state != State.DETACHED or not _host_current():
		return _result(false, &"composition_reentry_unavailable")
	var next_attachment := int(_host.call(&"get_attachment_generation"))
	if next_attachment <= _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	_attachment_generation = next_attachment
	if _adapter.get_snapshot().get("state", &"ready") == &"detached":
		var activity_reentry: Dictionary = _adapter.call(&"reenter")
		if not bool(activity_reentry.get("accepted", false)):
			return activity_reentry
	var settlement_snapshot := _settlement.call(&"get_snapshot") as Dictionary
	if settlement_snapshot.get("state", &"idle") == &"detached":
		_settlement.call(&"reenter", next_attachment)
	_apply_settlement_practicals()
	var water_snapshot := _water.call(&"get_snapshot") as Dictionary
	if water_snapshot.get("state", &"idle") == &"detached":
		_water.call(&"reenter", next_attachment)
	var audio_attach: Dictionary = _surface_audio_adapter.call(
		&"attach", _surface_audio_policy.get_snapshot().get("profile_id", &""),
		maxi(1, absi(_host.get_instance_id())), 1, 1,
		_surface_audio_binding.call(&"get_attachment_generation")
	)
	if not bool(audio_attach.get("accepted", false)):
		return _result(false, &"surface_audio_reentry_rejected")
	_state = State.BOUND
	return _result(true, &"composition_reentered")


func consume_orbit_return_handback(handback: Variant) -> Dictionary:
	if _state != State.BOUND or not handback is Dictionary:
		return _result(false, &"orbit_return_unavailable")
	var receipt := handback as Dictionary
	if StringName(receipt.get("reason", &"")) != &"runtime_ownership_returned" \
			or StringName(receipt.get("host_id", &"")) != &"ember_surface_loop" \
			or bool(receipt.get("host_attached", true)):
		return _result(false, &"invalid_orbit_return_handback")
	var detached := detach()
	if not bool(detached.get("accepted", false)):
		return detached
	return _result(true, &"planetary_orbit_return_consumed")


func accept_origin_rebase(receipt: Variant) -> Dictionary:
	if _state != State.BOUND or _adapter == null:
		return _result(false, &"origin_rebase_unavailable")
	return _adapter.call(&"accept_origin_rebase", receipt)


func get_snapshot() -> Dictionary:
	return {
		"state": [&"idle", &"bound", &"detached"][_state],
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"composition_generation": _composition_generation,
		"adapter": _adapter.get_snapshot() if _adapter != null else {},
		"navigation": _navigation.get_snapshot() if _navigation != null else {},
		"hazard": _hazard.get_snapshot() if _hazard != null else {},
		"weather": _weather.call(&"audit") if _weather != null else {},
		"solar_phase": _solar_phase.duplicate(true),
		"weather_observation": _weather_observation.duplicate(true),
		"water_presentation": _water_presentation.call(&"get_snapshot") if _water_presentation != null else {},
		"water": _water.get_snapshot() if _water != null else {},
		"landmarks": _landmarks.get_snapshot() if _landmarks != null else {},
		"settlement": _settlement.get_snapshot() if _settlement != null else {},
		"settlement_practicals": _settlement_practical_snapshot(),
		"surface_audio": _surface_audio_adapter.call(&"get_snapshot") if _surface_audio_adapter != null else {},
	}.duplicate(true)


func get_session_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"composition_generation": _composition_generation,
		"surface": _adapter.call(&"get_session_snapshot") if _adapter != null else {},
		"authority": {"save": false, "movement": false, "reward": false, "doors": false},
	}.duplicate(true)


func restore_session_snapshot(snapshot: Variant) -> Dictionary:
	if _state != State.BOUND or not snapshot is Dictionary:
		return _result(false, &"invalid_planetary_session_snapshot")
	var saved := snapshot as Dictionary
	if int(saved.get("schema_version", -1)) != 1:
		return _result(false, &"unsupported_planetary_session_schema")
	if int(saved.get("host_generation", -1)) != _host_generation:
		return _result(false, &"stale_planetary_host_generation")
	if int(saved.get("attachment_generation", -1)) >= _attachment_generation:
		return _result(false, &"stale_planetary_attachment_generation")
	var surface := saved.get("surface", {}) as Dictionary
	if surface.is_empty():
		return _result(false, &"invalid_planetary_session_snapshot")
	var restored: Dictionary = _adapter.call(
		&"restore_session_snapshot", surface, _navigation, _hazard, _landmarks, _settlement
	)
	if not bool(restored.get("accepted", false)):
		return _result(false, restored.get("reason", &"planetary_session_restore_rejected") as StringName)
	return _result(true, &"planetary_session_restored")


func _configure_settlement_practicals(contract_snapshot: Dictionary) -> void:
	_settlement_practicals.clear()
	for item in contract_snapshot.get("structures", []) as Array:
		var structure := item as Dictionary
		var structure_id := StringName(structure.get("id", &""))
		if structure_id.is_empty() or _settlement_practicals.size() >= 4:
			continue
		var practical := SettlementPracticalScript.new() as Node3D
		practical.name = "SettlementPractical_%s" % structure_id
		practical.position = structure.get("position_body_local_m", Vector3.ZERO)
		add_child(practical)
		var result: Dictionary = practical.call(&"configure", structure_id)
		if bool(result.get("accepted", false)):
			_settlement_practicals[structure_id] = practical


func _apply_settlement_practicals() -> void:
	if _solar_phase.is_empty():
		return
	for practical: Node in _settlement_practicals.values():
		practical.call(&"apply_solar_phase", _solar_phase)


func _settlement_practical_snapshot() -> Dictionary:
	var snapshot := {}
	for structure_id: StringName in _settlement_practicals:
		var practical: Node = _settlement_practicals[structure_id]
		snapshot[structure_id] = practical.call(&"get_snapshot")
	return snapshot


func _live() -> bool:
	return _state == State.BOUND and _host_current()


func _host_current() -> bool:
	return _host != null and is_instance_valid(_host) \
		and int(_host.call(&"get_generation")) == _host_generation


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "runtime": get_snapshot()}.duplicate(true)
