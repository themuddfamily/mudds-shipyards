extends SceneTree

const ContractScript := preload(
	"res://scripts/world/planetary_day_night_lighting_contract.gd"
)
const BODY_RADIUS_M := 120_000.0
const EXPECTED_ASSERTIONS := 25
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.evaluate(_observation()).reason == &"not_configured", "evaluation fails closed before configuration")
	_check(contract.configure(null).reason == &"invalid_definition", "missing definition is rejected")
	var configured := contract.configure({
		"world_id": &"ember_moon",
		"body_radius_m": BODY_RADIUS_M,
		"twilight_min_clearance_degrees": -6.0,
		"moonlight_energy_factor_unitless": 0.16,
		"interior_sky_factor_unitless": 0.08,
	})
	_check(bool(configured.accepted) and contract.is_configured() and bool(contract.audit().valid), "valid definition freezes and audits")
	_check(contract.configure({}).reason == &"already_configured", "configuration is immutable")
	var snapshot := contract.get_snapshot()
	_check(snapshot.world_id == &"ember_moon" and float(snapshot.body_radius_m) == BODY_RADIUS_M and snapshot.policy_version == ContractScript.POLICY_VERSION, "snapshot exposes stable identity and units")
	_check(not bool(snapshot.authority.renderer) and not bool(snapshot.adjacent_authority.clock_or_ephemeris) and not bool(snapshot.capabilities.renderer_application_implemented), "renderer and clock remain outside policy authority")
	var invalid := _observation()
	invalid.erase("normalized_body_to_moon")
	var extra := _observation()
	extra["time_seconds"] = 1.0
	_check(contract.evaluate(null).reason == &"invalid_observation" and contract.evaluate(invalid).reason == &"invalid_observation_schema" and contract.evaluate(extra).reason == &"invalid_observation_schema", "observation schema is strict and rejects clock input")
	var bad_mode := _observation()
	bad_mode.location_mode = &"cave"
	var bad_phase := _observation()
	bad_phase.moon_phase_unitless = 1.1
	var bad_sun := _observation()
	bad_sun.normalized_body_to_sun = Vector3.ZERO
	_check(contract.evaluate(bad_mode).reason == &"invalid_location_mode" and contract.evaluate(bad_phase).reason == &"invalid_moon_phase_unitless" and contract.evaluate(bad_sun).reason == &"invalid_celestial_direction", "mode, phase, and direction validation are bounded")
	var centre := _observation()
	centre.body_local_observer_m = Vector3.ZERO
	var below_surface := _observation()
	below_surface.body_local_observer_m = Vector3.UP * (BODY_RADIUS_M - 1.0)
	_check(contract.evaluate(centre).reason == &"observer_radial_up_undefined" and contract.evaluate(below_surface).reason == &"observer_inside_reference_sphere", "invalid radial positions fail closed")
	var zenith: Dictionary = contract.evaluate(_observation(Vector3.UP, Vector3.UP, Vector3.DOWN)).evaluation
	_check(zenith.classification.state == &"direct_daylight" and float(zenith.classification.day_factor_unitless) == 1.0 and float(zenith.classification.night_factor_unitless) == 0.0, "sun zenith deterministically classifies direct daylight")
	_check(bool(zenith.solar_phase.direct_sun_visible) and is_equal_approx(float(zenith.solar_phase.sun_elevation_radians), PI * 0.5), "solar elevation is derived from body-local vectors")
	_check(float(zenith.lighting_hints.recommended_sun_energy_factor_unitless) == 1.0 and float(zenith.moon_phase.recommended_energy_factor_unitless) == 0.0, "visible sun produces bounded sun hint while hidden moon contributes zero")
	var horizon_observation := _observation(Vector3.RIGHT, Vector3.UP, Vector3.UP)
	horizon_observation.body_local_observer_m = Vector3.RIGHT * BODY_RADIUS_M
	var horizon: Dictionary = contract.evaluate(horizon_observation).evaluation
	_check(horizon.classification.state == &"atmospheric_twilight" and float(horizon.classification.twilight_factor_unitless) == 1.0, "exact spherical horizon starts the documented twilight band")
	var twilight_result: Dictionary = contract.evaluate(_observation(Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(93.0)), Vector3.UP, Vector3.UP))
	var twilight: Dictionary = twilight_result.get("evaluation", {}) as Dictionary
	_check(float(twilight.classification.twilight_factor_unitless) > 0.0 and float(twilight.classification.twilight_factor_unitless) < 1.0, "negative solar clearance interpolates within twilight")
	var night: Dictionary = contract.evaluate(_observation(Vector3.DOWN, Vector3.UP, Vector3.UP)).evaluation
	_check(night.classification.state == &"night" and float(night.classification.night_factor_unitless) == 1.0 and float(night.lighting_hints.recommended_sun_energy_factor_unitless) == 0.0, "anti-sun position is deterministic night")
	var moon := _observation(Vector3.DOWN, Vector3.UP, Vector3.DOWN)
	moon.moon_phase_unitless = 1.0
	var moon_eval: Dictionary = contract.evaluate(moon).evaluation
	_check(bool(moon_eval.moon_phase.direct_moon_visible) and float(moon_eval.moon_phase.recommended_energy_factor_unitless) == 0.16, "full visible moon produces only bounded caller-independent phase energy")
	moon.moon_phase_unitless = 0.5
	var half_moon: Dictionary = contract.evaluate(moon).evaluation
	_check(is_equal_approx(float(half_moon.moon_phase.recommended_energy_factor_unitless), 0.08), "moon phase scales linearly and deterministically")
	moon.moon_occlusion_unitless = 1.0
	var occluded_moon: Dictionary = contract.evaluate(moon).evaluation
	_check(float(occluded_moon.moon_phase.recommended_energy_factor_unitless) == 0.0 and float(occluded_moon.shadow_hints.moon_shadow_receiver_factor_unitless) == 0.0, "caller moon occlusion suppresses moonlight and publishes shadow hint")
	var sun_occluded := _observation(Vector3.UP, Vector3.UP, Vector3.DOWN)
	sun_occluded.sun_occlusion_unitless = 0.75
	var sun_shadow: Dictionary = contract.evaluate(sun_occluded).evaluation
	_check(is_equal_approx(float(sun_shadow.lighting_hints.recommended_sun_energy_factor_unitless), 0.25) and is_equal_approx(float(sun_shadow.shadow_hints.sun_shadow_receiver_factor_unitless), 0.25), "caller sun occlusion maps to bounded sun energy and shadow hint")
	var interior := _observation(Vector3.UP, Vector3.UP, Vector3.DOWN)
	interior.location_mode = &"interior"
	var interior_eval: Dictionary = contract.evaluate(interior).evaluation
	_check(interior_eval.classification.state == &"interior" and bool(interior_eval.transition.direct_sources_suppressed), "interior mode is an explicit transition state")
	_check(float(interior_eval.lighting_hints.recommended_sun_energy_factor_unitless) == 0.0 and float(interior_eval.moon_phase.recommended_energy_factor_unitless) == 0.0 and float(interior_eval.lighting_hints.recommended_ambient_energy_factor_unitless) == 0.08, "interior suppresses celestial sources and retains authored sky fill")
	_check(not bool(interior_eval.shadow_hints.sun_occluded_by_caller) and not bool(interior_eval.shadow_hints.moon_occluded_by_caller) and not bool(interior_eval.shadow_hints.renderer_shadow_map_consulted), "interior and shadow hints have no renderer query side effects")
	var deterministic_a := contract.evaluate(_observation(Vector3.UP, Vector3.UP, Vector3.DOWN))
	var deterministic_b := contract.evaluate(_observation(Vector3.UP, Vector3.UP, Vector3.DOWN))
	_check(deterministic_a == deterministic_b, "identical observations produce byte-identical detached evaluations")
	_check(contract.get_snapshot() == snapshot, "evaluation does not mutate frozen configuration")
	_check(_all_authority_false(contract.get_snapshot().authority) and _all_authority_false(contract.get_snapshot().adjacent_authority), "authority declarations remain all false")
	_finish()


func _observation(observer := Vector3.UP, sun := Vector3.UP, moon := Vector3.DOWN) -> Dictionary:
	return {
		"body_local_observer_m": observer.normalized() * (BODY_RADIUS_M + 1.0),
		"normalized_body_to_sun": sun,
		"normalized_body_to_moon": moon,
		"moon_phase_unitless": 1.0,
		"sun_occlusion_unitless": 0.0,
		"moon_occlusion_unitless": 0.0,
		"location_mode": &"exterior",
	}


func _all_authority_false(values: Dictionary) -> bool:
	for key: String in values:
		if bool(values[key]):
			return false
	return true


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("%s (assertion %d)" % [label, _assertions])


func _finish() -> void:
	if _failures.is_empty() and _assertions == EXPECTED_ASSERTIONS:
		print("PLANETARY_DAY_NIGHT_LIGHTING_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("PLANETARY_DAY_NIGHT_LIGHTING_CONTRACT_TEST_FAILED: %d/%d assertions\\n%s" % [_assertions, EXPECTED_ASSERTIONS, "\\n".join(_failures)])
		quit(1)
