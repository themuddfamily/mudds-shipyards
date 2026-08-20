extends SceneTree

## Focused contract coverage for the sampler/envelope transition seam. This
## test does not instantiate a world, renderer, Player, or production flow.

const ValidatorScript := preload(
	"res://scripts/world/planetary_atmosphere_transition_validator.gd"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)

const WIDTHS := {
	"atmosphere_top_width_m": 1000.0,
	"cloud_base_width_m": 500.0,
	"cloud_top_width_m": 500.0,
	"sun_visibility_width_radians": 0.02,
}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_configuration_and_atomic_rejection()
	_test_exact_boundaries_and_combined_sample()
	_test_detachment_and_cadence()
	_test_audit_and_authority()
	_finish()


func _test_configuration_and_atomic_rejection() -> void:
	var validator = ValidatorScript.new()
	_check(
		not validator.is_configured()
		and validator.evaluate(0.0, 0.0, 0.0).reason == &"not_configured"
		and not bool(validator.audit().valid),
		"unconfigured validator fails closed and reports an incomplete audit"
	)
	_check(
		validator.configure(_profile(), {"atmosphere_top_width_m": 1.0}).reason
		== &"invalid_transition_width_schema"
		and not validator.is_configured(),
		"missing transition widths reject atomically"
	)
	var invalid_profile = _profile()
	invalid_profile.cloud_top_altitude_m = invalid_profile.cloud_base_altitude_m
	_check(
		validator.configure(invalid_profile, WIDTHS).reason == &"invalid_profile"
		and not validator.is_configured(),
		"invalid profile input cannot partially configure either policy"
	)
	var configured = validator.configure(_profile(), WIDTHS)
	_check(
		bool(configured.accepted)
		and configured.reason == &"configured"
		and validator.is_configured()
		and bool(validator.audit().valid),
		"one valid profile freezes both policy layers and a valid audit"
	)
	_check(
		validator.configure(_profile(), WIDTHS).reason == &"already_configured",
		"successful configuration is immutable"
	)


func _test_exact_boundaries_and_combined_sample() -> void:
	var validator = _configured()
	var top = validator.evaluate(20_000.0, 0.0, 0.0)
	var top_sample = top.get("sample", {}) as Dictionary
	var top_envelope = top.get("envelope", {}) as Dictionary
	var top_raw = top_envelope.get("raw_boundaries", {}) as Dictionary
	var top_weights = top_envelope.get("weights", {}) as Dictionary
	_check(
		bool(top.accepted)
		and bool(top_sample.vacuum)
		and float(top_sample.density_ratio) == 0.0
		and float(top_sample.fog_factor) == 0.0
		and float(top_sample.cloud_layer_factor) == 0.0
		and top.phase == &"space_vacuum"
		and not bool(top_raw.inside_atmosphere)
		and bool(top_raw.vacuum)
		and float(top_weights.atmosphere_unitless) == 0.0,
		"exact atmosphere top is vacuum in the sampler and zero in the envelope"
	)
	var cloud_base = validator.evaluate(3_000.0, 0.0, 0.0)
	var cloud_base_sample = cloud_base.get("sample", {}) as Dictionary
	var cloud_base_envelope = cloud_base.get("envelope", {}) as Dictionary
	_check(
		bool(cloud_base.accepted)
		and float(cloud_base_sample.cloud_layer_factor) > 0.0
		and bool((cloud_base_envelope.raw_boundaries as Dictionary).inside_cloud_layer)
		and float((cloud_base_envelope.weights as Dictionary).cloud_observer_unitless) == 0.0
		and cloud_base.phase == &"cloud_base_boundary",
		"cloud base is sampler-inclusive but envelope-edge-zero"
	)
	var cloud_top = validator.evaluate(6_000.0, 0.0, 0.0)
	_check(
		bool(cloud_top.accepted)
		and float((cloud_top.sample as Dictionary).cloud_layer_factor) == 0.0
		and not bool((cloud_top.envelope.raw_boundaries as Dictionary).inside_cloud_layer)
		and cloud_top.phase == &"cloud_top_boundary",
		"cloud top is sampler-exclusive and remains an envelope edge"
	)
	var middle = validator.evaluate(19_500.0, 12_000.0, 250.0, 0.5, 0.75, 0.2)
	_check(
		bool(middle.accepted)
		and (middle.sample as Dictionary).profile_id == &"temperate_game_scale"
		and (middle.envelope as Dictionary).profile_id == &"temperate_game_scale"
		and middle.phase == &"upper_atmosphere",
		"combined samples retain one profile identity and a stable transition phase"
	)


func _test_detachment_and_cadence() -> void:
	var profile = _profile()
	var validator = ValidatorScript.new()
	_check(bool(validator.configure(profile, WIDTHS).accepted), "detachment fixture configures")
	var snapshot = validator.get_snapshot()
	var first = validator.evaluate(10_000.0, 4_000.0, 220.0, 0.8, 0.7, 0.3)
	var second = validator.evaluate(10_000.0, 4_000.0, 220.0, 0.8, 0.7, 0.3)
	_check(first == second, "equal observations are cadence-independent")
	profile.profile_id = &"caller_mutated"
	profile.atmosphere_top_altitude_m = 1_000.0
	profile.cloud_top_altitude_m = 1_100.0
	var after_mutation = validator.evaluate(10_000.0, 4_000.0, 220.0, 0.8, 0.7, 0.3)
	_check(
		validator.get_snapshot() == snapshot
		and after_mutation == first,
		"source Resource mutation cannot retune frozen sampler or envelope values"
	)
	var invalid_observation = validator.evaluate(
		10_000.0, 4_000.0, 220.0, 0.8, 0.7, INF
	)
	_check(
		not bool(invalid_observation.accepted)
		and invalid_observation.reason == &"invalid_sun_clearance"
		and validator.get_snapshot() == snapshot,
		"invalid caller observations reject before changing retained state"
	)


func _test_audit_and_authority() -> void:
	var report = _configured().get_audit_report()
	var authority := report.get("authority", {}) as Dictionary
	var capabilities := report.get("capabilities", {}) as Dictionary
	_check(
		bool(report.valid)
		and report.policy_version == &"planetary_atmosphere_transition_validator_v1"
		and report.unit_system == &"game_scale_si"
		and authority.size() == 12
		and authority.values().all(func(value: Variant) -> bool: return value == false),
		"audit publishes the stable SI policy and exact zero authority roster"
	)
	_check(
		bool(capabilities.get("sampler_and_envelope_cross_check_implemented", false)),
		"audit exposes the cross-check capability explicitly"
	)


func _configured():
	var validator = ValidatorScript.new()
	var result = validator.configure(_profile(), WIDTHS)
	if not bool(result.accepted):
		_failures.append("fixture configuration failed: %s" % result)
	return validator


func _profile() -> PlanetaryAtmosphereProfile:
	return ProfileScript.new() as PlanetaryAtmosphereProfile


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	print("PLANETARY_ATMOSPHERE_TRANSITION_VALIDATOR_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_TRANSITION_VALIDATOR_TEST_OK")
		quit(0)
		return
	print(
		"PLANETARY_ATMOSPHERE_TRANSITION_VALIDATOR_TEST_FAILED: %s"
		% ", ".join(_failures)
	)
	quit(1)
