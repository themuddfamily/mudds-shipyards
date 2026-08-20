extends SceneTree

const ValidatorScript := preload(
	"res://scripts/world/planetary_terrain_composition_validator.gd"
)
const ProfileScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const PolicyScript := preload("res://scripts/world/planetary_terrain_lod_policy.gd")

const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	_test_valid_join_and_detached_report()
	_test_profile_policy_identity_is_frozen()
	_test_missing_and_invalid_inputs_fail_closed()
	_finish()


func _test_valid_join_and_detached_report() -> void:
	var profile := _profile()
	var policy := _policy(profile)
	var validator := ValidatorScript.new() as PlanetaryTerrainCompositionValidator
	var report := validator.validate_composition(profile, policy)
	var authority := report.authority as Dictionary
	var authority_zero := _has_exact_keys(authority, COMMON_AUTHORITY_KEYS)
	for key in COMMON_AUTHORITY_KEYS:
		authority_zero = authority_zero and authority[key] is bool \
			and not bool(authority[key])
	_check(
		bool(report.valid)
			and report.profile_id == profile.profile_id
			and report.surface_classification.material_channel_order \
				== &"declared_biome_layer_order"
			and report.surface_classification.biome_layer_ids \
				== profile.biome_layer_ids
			and authority_zero,
		"a configured policy joins the exact terrain LOD, collision, and ordered biome contract"
	)
	var expected_rings := profile.clipmap_ring_distances_meters.duplicate()
	(report.surface_classification.biome_layer_ids as PackedStringArray)[0] = "tampered"
	(report.policy as Dictionary)["profile_id"] = &"tampered"
	(report.clipmap_ring_distances_meters as PackedFloat64Array)[0] = -1.0
	var fresh := validator.audit(profile, policy)
	_check(
		bool(fresh.valid)
			and fresh.surface_classification.biome_layer_ids == profile.biome_layer_ids
			and fresh.clipmap_ring_distances_meters == expected_rings
			and fresh.policy.profile_id == profile.profile_id,
		"nested report mutation cannot alter profile, policy, or later detached results"
	)


func _test_profile_policy_identity_is_frozen() -> void:
	var profile := _profile()
	var policy := _policy(profile)
	var validator := ValidatorScript.new() as PlanetaryTerrainCompositionValidator
	profile.profile_id = &"mutated_after_configuration"
	_check(
		_has_code(
			validator.validate_composition(profile, policy),
			&"lod_policy_profile_mismatch"
		),
		"a caller changing the profile identity cannot silently reuse an old frozen policy"
	)
	var custom := _profile()
	custom.clipmap_ring_distances_meters = PackedFloat64Array([128.0, 512.0])
	custom.collision_lod_ring_index = 0
	custom.collision_maximum_distance_meters = 64.0
	var custom_policy := _policy(custom)
	_check(
		_has_code(
			validator.validate_composition(profile, custom_policy),
			&"lod_policy_profile_mismatch"
		),
		"different rings and collision limits produce a structured composition red"
	)


func _test_missing_and_invalid_inputs_fail_closed() -> void:
	var validator := ValidatorScript.new() as PlanetaryTerrainCompositionValidator
	var profile := _profile()
	var policy := PolicyScript.new() as PlanetaryTerrainLodPolicy
	_check(
		_has_code(validator.validate_composition(null, policy), &"missing_terrain_profile")
			and _has_code(validator.validate_composition(profile, null), &"missing_lod_policy"),
		"missing composition inputs return distinct structured errors"
	)
	_check(
		_has_code(validator.validate_composition(profile, policy), &"invalid_lod_policy"),
		"an unconfigured LOD policy fails closed"
	)
	var invalid_profile := _profile()
	invalid_profile.biome_layer_ids = PackedStringArray(["bedrock", "bedrock"])
	_check(
		_has_code(
			validator.validate_composition(invalid_profile, _policy(invalid_profile)),
			&"invalid_terrain_profile"
		),
		"a duplicate biome/material layer cannot enter the composed contract"
	)


func _profile() -> PlanetaryTerrainProfile:
	return ProfileScript.new() as PlanetaryTerrainProfile


func _policy(profile: PlanetaryTerrainProfile) -> PlanetaryTerrainLodPolicy:
	var policy := PolicyScript.new() as PlanetaryTerrainLodPolicy
	policy.configure(profile)
	return policy


func _has_code(report: Dictionary, code: StringName) -> bool:
	return (report.get("error_codes", PackedStringArray()) as PackedStringArray).has(
		str(code)
	)


func _has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("PLANETARY_TERRAIN_COMPOSITION_VALIDATOR_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_TERRAIN_COMPOSITION_VALIDATOR_TEST_OK")
		quit(0)
		return
	print("PLANETARY_TERRAIN_COMPOSITION_VALIDATOR_TEST_FAILURES: %s" % _failures)
	quit(1)
