extends SceneTree

const ProfileScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const PolicyScript := preload(
	"res://scripts/world/planetary_terrain_lod_policy.gd"
)
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const POLICY_SPECIFIC_AUTHORITY_KEYS := [
	"height_generation", "terrain_mesh", "landing", "clock",
]

const EXPECTED_ASSERTIONS := 18
var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_detached_profile()
	_test_render_ring_boundaries()
	_test_collision_and_budget_hints()
	_test_invalid_inputs_purity_and_audit()
	_finish()


func _test_configuration_and_detached_profile() -> void:
	var policy := PolicyScript.new() as PlanetaryTerrainLodPolicy
	_check(
		policy.evaluate(0.0, false).reason == &"not_configured"
			and not bool(policy.audit().valid),
		"an unconfigured policy rejects evaluation and fails its audit closed"
	)
	_check(
		policy.configure(null).reason == &"missing_profile"
			and not policy.is_configured(),
		"a missing profile is rejected without partially configuring"
	)
	var invalid_profile := _profile()
	invalid_profile.clipmap_ring_distances_meters = PackedFloat64Array([
		256.0, NAN,
	])
	_check(
		policy.configure(invalid_profile).reason == &"invalid_profile"
			and not policy.is_configured(),
		"a malformed terrain profile is rejected and the policy remains retryable"
	)

	var profile := _profile()
	var expected_rings := profile.get_clipmap_ring_distances_meters()
	var configured := policy.configure(profile)
	var frozen_snapshot := policy.get_snapshot()
	var duplicate := policy.configure(_profile())
	_check(
		bool(configured.accepted)
			and configured.reason == &"configured"
			and duplicate.reason == &"already_configured"
			and frozen_snapshot.clipmap_ring_distances_meters == expected_rings
			and int(frozen_snapshot.maximum_visible_tile_count) == 512
			and int(frozen_snapshot.maximum_resident_tile_count) == 1024
			and int(frozen_snapshot.maximum_collision_tile_count) == 256,
		"one valid profile freezes the exact ordered rings and tile ceilings once"
	)

	profile.profile_id = &"caller_mutated"
	profile.clipmap_ring_distances_meters[0] = 1.0
	profile.collision_lod_ring_index = 0
	profile.collision_maximum_distance_meters = 1.0
	profile.tile_resolution_vertices_per_edge = 17
	profile.maximum_visible_tile_count = 1
	profile.maximum_resident_tile_count = 1
	profile.maximum_collision_tile_count = 1
	_check(
		policy.get_snapshot() == frozen_snapshot
			and policy.evaluate(256.0, true).render_ring_index == 0
			and policy.evaluate(1500.0, true).collision_participates,
		"caller mutation of every load-bearing profile field cannot retune the frozen policy"
	)


func _test_render_ring_boundaries() -> void:
	var policy := _policy()
	var at_zero := policy.evaluate(0, false)
	var at_first_outer := policy.evaluate(256.0, false)
	var above_first_outer := policy.evaluate(256.001, false)
	_check(
		bool(at_zero.accepted)
			and at_zero.render_ring_index == 0
			and at_zero.render_ring_inner_distance_meters == 0.0
			and at_zero.render_ring_outer_distance_meters == 256.0
			and at_first_outer.render_ring_index == 0
			and above_first_outer.render_ring_index == 1
			and above_first_outer.render_ring_inner_distance_meters == 256.0
			and above_first_outer.render_ring_outer_distance_meters == 768.0,
		"zero and the exact first boundary stay in the finest inclusive ring"
	)

	var profile := _profile()
	var ordered_boundaries_hold := true
	for index in profile.clipmap_ring_distances_meters.size():
		var boundary := profile.clipmap_ring_distances_meters[index]
		var selected := policy.evaluate(boundary, false)
		ordered_boundaries_hold = ordered_boundaries_hold \
			and selected.render_ring_index == index
	_check(
		ordered_boundaries_hold,
		"every authored outer boundary selects its deterministic near-to-far ring"
	)

	var last_index := profile.clipmap_ring_distances_meters.size() - 1
	var farthest_boundary := profile.clipmap_ring_distances_meters[last_index]
	var at_farthest := policy.evaluate(farthest_boundary, false)
	var beyond_farthest := policy.evaluate(farthest_boundary + 0.001, false)
	_check(
		at_farthest.render_participates
			and at_farthest.render_ring_index == last_index
			and not bool(beyond_farthest.render_participates)
			and beyond_farthest.render_ring_index == -1
			and beyond_farthest.render_ring_inner_distance_meters == 0.0
			and beyond_farthest.render_ring_outer_distance_meters == 0.0,
		"the farthest boundary participates while the point beyond returns no render ring"
	)

	var maximum_supported := policy.evaluate(
		ProfileScript.MAX_LOD_DISTANCE_METERS, false
	)
	_check(
		bool(maximum_supported.accepted)
			and not bool(maximum_supported.render_participates)
			and _budget_hints_are_zero(maximum_supported.tile_budget_hints),
		"the maximum supported distance is an accepted no-participation result"
	)


func _test_collision_and_budget_hints() -> void:
	var policy := _policy()
	var no_need := policy.evaluate(0.0, false)
	var need := policy.evaluate(0.0, true)
	_check(
		not bool(no_need.collision_participates)
			and bool(need.collision_participates)
			and need.collision_lod_ring_index == 2
			and need.collision_maximum_distance_meters == 1500.0,
		"collision participation requires the caller need and exposes the fixed profile LOD"
	)

	var exact_collision_limit := policy.evaluate(1500.0, true)
	var above_collision_limit := policy.evaluate(1500.001, true)
	_check(
		exact_collision_limit.collision_participates
			and exact_collision_limit.render_ring_index == 2
			and not bool(above_collision_limit.collision_participates)
			and above_collision_limit.render_participates,
		"the profile collision distance is inclusive and the next point disables only collision"
	)

	var near_hints := need.tile_budget_hints as Dictionary
	var no_collision_hints := no_need.tile_budget_hints as Dictionary
	_check(
		near_hints == {
			"tile_resolution_vertices_per_edge": 129,
			"visible_tile_count_ceiling": 512,
			"resident_tile_count_ceiling": 1024,
			"collision_tile_count_ceiling": 256,
		}
			and int(no_collision_hints.collision_tile_count_ceiling) == 0
			and int(no_collision_hints.visible_tile_count_ceiling) == 512
			and int(no_collision_hints.resident_tile_count_ceiling) == 1024,
		"participation gates exact profile tile ceilings without inventing allocations"
	)

	var custom_profile := _profile()
	custom_profile.clipmap_ring_distances_meters = PackedFloat64Array([
		10.0, 20.0, 40.0,
	])
	custom_profile.collision_lod_ring_index = 1
	custom_profile.collision_maximum_distance_meters = 20.0
	custom_profile.tile_resolution_vertices_per_edge = 33
	custom_profile.maximum_visible_tile_count = 7
	custom_profile.maximum_resident_tile_count = 9
	custom_profile.maximum_collision_tile_count = 3
	var custom_policy := PolicyScript.new() as PlanetaryTerrainLodPolicy
	var custom_configured := custom_policy.configure(custom_profile)
	var collision_edge := custom_policy.evaluate(20.0, true)
	var far_render := custom_policy.evaluate(25.0, true)
	_check(
		bool(custom_configured.accepted)
			and collision_edge.render_ring_index == 1
			and collision_edge.collision_participates
			and (collision_edge.tile_budget_hints as Dictionary) == {
				"tile_resolution_vertices_per_edge": 33,
				"visible_tile_count_ceiling": 7,
				"resident_tile_count_ceiling": 9,
				"collision_tile_count_ceiling": 3,
			}
			and far_render.render_ring_index == 2
			and not bool(far_render.collision_participates)
			and int(far_render.tile_budget_hints.collision_tile_count_ceiling) == 0,
		"custom valid profile ceilings and ring boundaries compose without default assumptions"
	)


func _test_invalid_inputs_purity_and_audit() -> void:
	var policy := _policy()
	var before := policy.get_snapshot()
	var invalid_results := [
		policy.evaluate(NAN, false),
		policy.evaluate(INF, false),
		policy.evaluate(-0.001, false),
		policy.evaluate(ProfileScript.MAX_LOD_DISTANCE_METERS + 1.0, false),
		policy.evaluate("100", false),
		policy.evaluate(true, false),
	]
	var distance_rejections_hold := true
	for rejected: Dictionary in invalid_results:
		distance_rejections_hold = distance_rejections_hold \
			and not bool(rejected.accepted) \
			and rejected.reason == &"invalid_camera_to_surface_distance" \
			and not rejected.has("render_ring_index")
	_check(
		distance_rejections_hold and policy.get_snapshot() == before,
		"negative, non-finite, out-of-range, and coercible distances reject atomically"
	)

	var invalid_collision_string := policy.evaluate(100.0, "true")
	var invalid_collision_integer := policy.evaluate(100.0, 1)
	_check(
		invalid_collision_string.reason == &"invalid_collision_need"
			and invalid_collision_integer.reason == &"invalid_collision_need"
			and not invalid_collision_string.has("collision_participates")
			and policy.get_snapshot() == before,
		"collision need accepts an exact boolean and rejects coercion without partial output"
	)

	var baseline := policy.evaluate(777.0, true)
	var equivalent := true
	for sample_count in [30, 60, 120]:
		var latest: Dictionary = {}
		for _index in sample_count:
			latest = policy.evaluate(777.0, true)
		equivalent = equivalent and latest == baseline
	_check(
		equivalent and policy.get_snapshot() == before,
		"30, 60, and 120 equivalent evaluations are exact and timestep-free"
	)

	var mutable_result := baseline.duplicate(true)
	(mutable_result.tile_budget_hints as Dictionary)[
		"visible_tile_count_ceiling"
	] = 999999
	mutable_result["render_ring_index"] = 999
	var snapshot := policy.get_snapshot()
	(snapshot.clipmap_ring_distances_meters as PackedFloat64Array)[0] = 999999.0
	var audit := policy.audit()
	(audit.snapshot as Dictionary)["profile_id"] = &"forged"
	(audit.authority as Dictionary)["renderer"] = true
	_check(
		policy.evaluate(777.0, true) == baseline
			and policy.get_snapshot() == before
			and policy.get_snapshot().profile_id == &"terrain_lod_fixture"
			and not bool(policy.audit().authority.renderer),
		"results, packed rings, snapshots, and nested audits are deeply detached"
	)

	var authority := policy.audit().authority as Dictionary
	var specific_authority := (
		policy.audit().policy_specific_authority as Dictionary
	)
	_check(
		bool(policy.audit().valid)
			and _has_exact_false_keys(authority, COMMON_AUTHORITY_KEYS)
			and _has_exact_false_keys(
				specific_authority, POLICY_SPECIFIC_AUTHORITY_KEYS
			)
			and not policy.has_method("_process")
			and not policy.has_method("_physics_process")
			and not policy.has_method("generate")
			and not policy.has_method("save")
			and not bool(policy.audit().purity.delta_or_clock_input)
			and not bool(policy.audit().purity.mutates_source_profile)
			and not bool(policy.audit().purity.mutates_policy_during_evaluation),
		"the policy owns no generation, terrain mesh, renderer, physics, streaming, landing, clock, origin, save, or gameplay authority"
	)


func _profile() -> PlanetaryTerrainProfile:
	var profile := ProfileScript.new() as PlanetaryTerrainProfile
	profile.profile_id = &"terrain_lod_fixture"
	return profile


func _policy() -> PlanetaryTerrainLodPolicy:
	var policy := PolicyScript.new() as PlanetaryTerrainLodPolicy
	var configured := policy.configure(_profile())
	if not bool(configured.get("accepted", false)):
		_failures.append("fixture failed to configure: %s" % configured)
	return policy


func _budget_hints_are_zero(hints: Dictionary) -> bool:
	return int(hints.get("tile_resolution_vertices_per_edge", -1)) == 0 \
		and int(hints.get("visible_tile_count_ceiling", -1)) == 0 \
		and int(hints.get("resident_tile_count_ceiling", -1)) == 0 \
		and int(hints.get("collision_tile_count_ceiling", -1)) == 0


func _has_exact_false_keys(candidate: Dictionary, expected_keys: Array) -> bool:
	if candidate.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not candidate.has(key) or not candidate[key] is bool \
			or bool(candidate[key]):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		printerr("FAIL: %s" % message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion harness expected %d checks but ran %d" % [
				EXPECTED_ASSERTIONS, _assertions,
			]
		)
	if _failures.is_empty():
		print(
			"PLANETARY_TERRAIN_LOD_POLICY_TEST_OK: %d assertions" \
			% _assertions
		)
		quit(0)
		return
	printerr(
		"PLANETARY_TERRAIN_LOD_POLICY_TEST_FAILED: %d / %d assertions failed" \
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - %s" % failure)
	quit(1)
