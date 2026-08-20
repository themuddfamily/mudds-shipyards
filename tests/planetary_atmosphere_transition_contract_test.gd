extends SceneTree

## Focused ROADMAP 1094 contract test. It exercises only the pure transition
## seam; no production world, renderer, Player, audio device, or full matrix.

const ContractScript := preload(
	"res://scripts/world/planetary_atmosphere_transition_contract.gd"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)

const WIDTHS := {
	"atmosphere_top_width_m": 1_000.0,
	"cloud_base_width_m": 500.0,
	"cloud_top_width_m": 500.0,
	"sun_visibility_width_radians": 0.02,
}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_configuration_and_audit()
	_test_space_to_sky_and_entry()
	_test_audio_routes_and_weather()
	_test_detachment_and_rejection()
	_finish()


func _test_configuration_and_audit() -> void:
	var contract = ContractScript.new()
	_check(
		not contract.is_configured()
		and contract.evaluate({}).reason == &"invalid_observation_schema",
		"unconfigured contract fails closed on invalid observation schema"
	)
	var invalid_widths := WIDTHS.duplicate(true)
	invalid_widths["cloud_top_width_m"] = -1.0
	_check(
		contract.configure(_profile(), invalid_widths).reason
		== &"envelope_configuration_failed"
		and not contract.is_configured(),
		"invalid transition width rejects atomically"
	)
	_check(
		bool(contract.configure(_profile(), WIDTHS).accepted)
		and contract.is_configured()
		and bool(contract.get_audit_report().valid),
		"valid profile freezes the three policy layers with a valid audit"
	)
	var report := contract.get_audit_report()
	var authority := report.get("authority", {}) as Dictionary
	_check(
		int(report.schema_version) == 1
		and report.policy_version == &"planetary_atmosphere_transition_v1"
		and authority.size() == 10
		and authority.values().all(func(value: Variant) -> bool: return value == false),
		"audit publishes the SI policy and exact zero authority roster"
	)
	_check(
		bool((report.get("capabilities", {}) as Dictionary).get("entry_heat_and_compression_hints"))
		and bool((report.get("capabilities", {}) as Dictionary).get("interior_exterior_audio_routes")),
		"audit names heat/compression and distinct audio capabilities"
	)


func _test_space_to_sky_and_entry() -> void:
	var contract = _configured()
	var vacuum: Dictionary = contract.evaluate(_observation(20_000.0, 2_000.0, 340.0))
	var vacuum_eval := vacuum.get("evaluation", {}) as Dictionary
	var vacuum_space := vacuum_eval.get("space_to_sky", {}) as Dictionary
	var vacuum_density := vacuum_eval.get("density_visibility", {}) as Dictionary
	var vacuum_entry := vacuum_eval.get("entry", {}) as Dictionary
	_check(
		bool(vacuum.accepted)
		and vacuum_space.phase == &"space_vacuum"
		and not bool(vacuum_space.inside_atmosphere)
		and float(vacuum_space.atmosphere_weight_unitless) == 0.0
		and float(vacuum_density.density_ratio) == 0.0
		and float(vacuum_density.fog_factor_unitless) == 0.0
		and float(vacuum_entry.heat_intensity_unitless) == 0.0
		and float(vacuum_entry.compression_intensity_unitless) == 0.0,
		"exact atmosphere top is vacuum with zero visual and entry effects"
	)
	var lower: Dictionary = contract.evaluate(_observation(4_000.0, 12_000.0, 250.0, 0.8, 0.9, 0.25))
	var lower_eval := lower.get("evaluation", {}) as Dictionary
	var lower_density := lower_eval.get("density_visibility", {}) as Dictionary
	var lower_clouds := lower_eval.get("clouds", {}) as Dictionary
	var lower_entry := lower_eval.get("entry", {}) as Dictionary
	var lower_space := lower_eval.get("space_to_sky", {}) as Dictionary
	_check(
		bool(lower.accepted)
		and lower_space.phase == &"cloud_layer"
		and float(lower_space.atmosphere_weight_unitless) > 0.0
		and float(lower_density.density_ratio) > 0.0
		and float(lower_density.visibility_m) > 0.0
		and float(lower_density.fog_factor_unitless) > 0.0
		and float(lower_clouds.layer_factor_unitless) > 0.0
		and bool(lower_clouds.shadow_hint_only)
		and float(lower_entry.heat_intensity_unitless) > 0.0
		and float(lower_entry.compression_intensity_unitless) > 0.0,
		"lower atmosphere exposes density, aerial perspective, cloud, heat and compression hints"
	)
	var horizon: Dictionary = contract.evaluate(_observation(19_500.0, 4_000.0, 0.0, 1.0, 1.0, 0.5))
	var horizon_space := (horizon.evaluation as Dictionary).get("space_to_sky", {}) as Dictionary
	_check(
		bool(horizon.accepted)
		and float(horizon_space.horizon_visibility_weight_unitless) > 0.0
		and float(horizon_space.horizon_visibility_weight_unitless) <= 1.0,
		"signed horizon clearance produces a bounded horizon visibility weight"
	)


func _test_audio_routes_and_weather() -> void:
	var contract = _configured()
	var exterior: Dictionary = contract.evaluate(_observation(1_000.0, 0.0, 50.0, 0.6, 0.0, 0.0, &"exterior", false, 0.7))
	var interior: Dictionary = contract.evaluate(_observation(1_000.0, 0.0, 50.0, 0.6, 0.0, 0.0, &"interior", false, 0.7))
	var cabin: Dictionary = contract.evaluate(_observation(1_000.0, 0.0, 50.0, 0.6, 0.0, 0.0, &"cabin", false, 0.7))
	var exterior_audio := (exterior.evaluation as Dictionary).get("audio", {}) as Dictionary
	var interior_audio := (interior.evaluation as Dictionary).get("audio", {}) as Dictionary
	var cabin_audio := (cabin.evaluation as Dictionary).get("audio", {}) as Dictionary
	var weather := (exterior.evaluation as Dictionary).get("wind_weather", {}) as Dictionary
	_check(
		bool(exterior.accepted)
		and exterior_audio.selected_route == &"exterior"
		and float(exterior_audio.exterior_route_unitless) == 1.0
		and float(exterior_audio.interior_route_unitless) == 0.0
		and exterior_audio.selected_audio_profile_id == &"temperate_exterior"
		and bool(interior.accepted)
		and interior_audio.selected_route == &"interior"
		and float(interior_audio.interior_route_unitless) == 1.0
		and interior_audio.selected_audio_profile_id == &"temperate_interior"
		and bool(cabin.accepted)
		and cabin_audio.selected_route == &"interior"
		and float(weather.weather_scalar) == 0.6
		and bool(weather.wind_response_bounded),
		"exterior, interior and cabin routes remain distinct and weather is bounded"
	)


func _test_detachment_and_rejection() -> void:
	var profile := _profile()
	var contract = ContractScript.new()
	_check(bool(contract.configure(profile, WIDTHS).accepted), "detachment fixture configures")
	var snapshot := contract.get_snapshot()
	var observation := _observation(8_000.0, 2_000.0, 220.0)
	var first: Dictionary = contract.evaluate(observation)
	var second: Dictionary = contract.evaluate(observation)
	profile.profile_id = &"mutated_profile"
	profile.atmosphere_top_altitude_m = 1_000.0
	_check(
		first == second
		and contract.evaluate(observation) == first
		and contract.get_snapshot() == snapshot,
		"equal observations and source mutation cannot change frozen results"
	)
	var invalid := observation.duplicate(true)
	invalid["speed_mps"] = INF
	_check(
		contract.evaluate(invalid).reason == &"invalid_observation_value"
		and contract.get_snapshot() == snapshot,
		"invalid observations reject without mutating retained state"
	)


func _configured():
	var contract = ContractScript.new()
	if not bool(contract.configure(_profile(), WIDTHS).accepted):
		_failures.append("fixture configuration failed")
	return contract


func _profile() -> PlanetaryAtmosphereProfile:
	return ProfileScript.new() as PlanetaryAtmosphereProfile


func _observation(
	altitude: float,
	path_distance: float,
	speed: float,
	weather_scalar: float = 1.0,
	cloud_scalar: float = 1.0,
	clearance: float = 0.0,
	context: StringName = &"exterior",
	grounded: bool = false,
	wind_scalar: float = 1.0
) -> Dictionary:
	return {
		"altitude_m": altitude,
		"path_distance_m": path_distance,
		"speed_mps": speed,
		"weather_scalar": weather_scalar,
		"cloud_scalar": cloud_scalar,
		"sun_horizon_clearance_radians": clearance,
		"listener_context": context,
		"grounded": grounded,
		"ambient_wind_scalar_unitless": wind_scalar,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	print("PLANETARY_ATMOSPHERE_TRANSITION_CONTRACT_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_TRANSITION_CONTRACT_TEST_OK")
		quit(0)
		return
	print("PLANETARY_ATMOSPHERE_TRANSITION_CONTRACT_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
