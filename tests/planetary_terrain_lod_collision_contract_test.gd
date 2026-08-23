extends SceneTree

const ProfileScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const PolicyScript := preload("res://scripts/world/planetary_terrain_lod_policy.gd")
const ContractScript := preload(
	"res://scripts/world/planetary_terrain_lod_collision_contract.gd"
)

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_snapshot()
	_test_hysteresis_tier_transitions()
	_test_collision_residency_and_budgets()
	_test_motion_budgets_and_purity()
	_finish()


func _test_configuration_and_snapshot() -> void:
	var contract: Variant = ContractScript.new()
	_check(
		contract.configure(_policy(), 4.0, 2.0, 0.10, 0.50).accepted,
		"valid policy and explicit terrain safety budgets configure once"
	)
	_check(
		contract.configure(_policy(), 4.0, 2.0, 0.10).reason == &"already_configured",
		"configuration is immutable after the first accepted snapshot"
	)
	var snapshot: Dictionary = contract.get_snapshot()
	_check(
		snapshot.tile_size_meters == 4.0
			and snapshot.maximum_sweep_distance_meters == 2.0
			and snapshot.maximum_support_jitter_meters == 0.10
			and snapshot.tier_hysteresis_meters == 0.50
			and snapshot.maximum_collision_tile_count == 4,
		"snapshot freezes collision and motion budgets with the source ceiling"
	)
	_check(
		bool(contract.audit().valid)
			and (contract.audit().authority as Dictionary).collision_generation == false
			and (contract.audit().authority as Dictionary).physics == false,
		"audit stays green while terrain generation and physics remain caller-owned"
	)

	var invalid_policy_contract = ContractScript.new()
	_check(
		invalid_policy_contract.configure(null, 4.0, 2.0, 0.1).reason
			== &"invalid_terrain_lod_policy",
		"missing LOD policy fails closed without partial configuration"
	)
	var too_fast = ContractScript.new()
	_check(
		too_fast.configure(_policy(), 4.0, 4.001, 0.1).reason
			== &"sweep_distance_exceeds_tile_size",
		"a sweep larger than one collision tile is rejected before runtime"
	)


func _test_hysteresis_tier_transitions() -> void:
	var contract: Variant = _contract()
	var near: Dictionary = contract.evaluate_tier(8.0, true)
	_check(
		near.committed_render_ring_index == 0
			and near.collision_participates
			and near.collision_tile_count_ceiling == 4,
		"the exact first ring interior selects fine render and collision tiers"
	)
	var boundary_inside_guard: Dictionary = contract.evaluate_tier(8.25, true, 0)
	_check(
		boundary_inside_guard.requested_render_ring_index == 1
			and boundary_inside_guard.committed_render_ring_index == 0
			and not bool(boundary_inside_guard.transition_required),
		"outward tier transition waits inside the hysteresis guard band"
	)
	var boundary_exit: Dictionary = contract.evaluate_tier(8.51, true, 0)
	_check(
		boundary_exit.committed_render_ring_index == 1
			and bool(boundary_exit.transition_required),
		"outward transition commits after the guard band"
	)
	var inward_inside_guard: Dictionary = contract.evaluate_tier(7.75, true, 1)
	_check(
		inward_inside_guard.requested_render_ring_index == 0
			and inward_inside_guard.committed_render_ring_index == 1,
		"inward transition also retains the coarser tier through its guard band"
	)
	var inward_exit: Dictionary = contract.evaluate_tier(7.49, true, 1)
	_check(
		inward_exit.committed_render_ring_index == 0
			and bool(inward_exit.transition_required),
		"inward transition commits beyond the lower guard edge"
	)
	var collision_edge: Dictionary = contract.evaluate_tier(24.0, true, 1)
	var above_collision: Dictionary = contract.evaluate_tier(24.001, true, 1)
	_check(
		collision_edge.collision_participates
			and not bool(above_collision.collision_participates)
			and above_collision.collision_tile_count_ceiling == 0,
		"collision residency uses the inclusive profile distance independently of render tier"
	)


func _test_collision_residency_and_budgets() -> void:
	var contract: Variant = _contract()
	var complete_plan := {
		"lod_ring_index": 1,
		"desired_tiles": [
			_tile(1, -1, -1, true), _tile(1, 0, -1, true),
			_tile(1, 0, 0, true), _tile(1, -1, 0, true),
		],
	}
	var resident: Dictionary = contract.validate_collision_residency(
		Vector3(0.2, 120000.0, 0.2),
		Vector3(1.4, 120000.0, 1.4),
		complete_plan
	)
	_check(
		resident.accepted
			and resident.reason == &"collision_resident"
			and (resident.required_collision_tiles as PackedStringArray).size() == 1,
		"a bounded local sweep succeeds when its collision tile is resident"
	)
	var missing_plan := complete_plan.duplicate(true)
	(missing_plan.desired_tiles as Array)[0].collision = false
	var missing: Dictionary = contract.validate_collision_residency(
		Vector3(-3.8, 0.0, -3.8), Vector3(-2.6, 0.0, -2.6), missing_plan
	)
	_check(
		not missing.accepted
			and missing.reason == &"collision_tile_missing"
			and (missing.missing_collision_tiles as PackedStringArray).size() == 1,
		"a swept path fails closed when its resident tile has no collision"
	)
	var overlong: Dictionary = contract.validate_collision_residency(
		Vector3(0.0, 0.0, 0.0), Vector3(2.01, 0.0, 0.0), complete_plan
	)
	_check(
		not overlong.accepted
			and overlong.reason == &"tunneling_budget_exceeded",
		"a movement segment over the configured sweep budget is rejected"
	)
	var too_many_collision_tiles := complete_plan.duplicate(true)
	for index in range(4, (too_many_collision_tiles.desired_tiles as Array).size()):
		(too_many_collision_tiles.desired_tiles as Array)[index].collision = true
	# The custom policy permits four collision tiles; duplicate records must not
	# silently inflate the count, so add a distinct fifth tile.
	(too_many_collision_tiles.desired_tiles as Array).append(_tile(1, 2, 0, true))
	var over_budget: Dictionary = contract.validate_collision_residency(
		Vector3(0.2, 0.0, 0.2), Vector3(1.4, 0.0, 1.4),
		too_many_collision_tiles
	)
	_check(
		not over_budget.accepted
			and over_budget.reason == &"collision_residency_budget_exceeded",
		"collision residency cannot exceed the policy tile ceiling"
	)


func _test_motion_budgets_and_purity() -> void:
	var contract: Variant = _contract()
	var before: Dictionary = contract.get_snapshot()
	var safe: Dictionary = contract.validate_motion_sample(
		Vector3.ZERO, Vector3(1.5, 0.0, 0.0), 0.05
	)
	var jitter: Dictionary = contract.validate_motion_sample(
		Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.101
	)
	var tunnel: Dictionary = contract.validate_motion_sample(
		Vector3.ZERO, Vector3(2.001, 0.0, 0.0), 0.0
	)
	_check(
		safe.accepted and safe.reason == &"motion_within_budgets"
			and jitter.reason == &"support_jitter_budget_exceeded"
			and tunnel.reason == &"tunneling_budget_exceeded",
		"motion guard accepts safe movement and rejects jitter/tunnelling violations"
	)
	var resident_plan := {
		"lod_ring_index": 1,
		"desired_tiles": [_tile(1, 0, 0, true)],
	}
	var supported: Dictionary = contract.validate_supported_motion_handoff(
		Vector3(0.2, 0.0, 0.2), Vector3(1.4, 0.0, 1.4), 0.05, resident_plan
	)
	_check(
		supported.accepted and supported.reason == &"supported_motion_handoff"
			and supported.motion.reason == &"motion_within_budgets"
			and supported.residency.reason == &"collision_resident",
		"supported movement commits only when motion and collision residency agree"
	)
	var missing_support := resident_plan.duplicate(true)
	(missing_support.desired_tiles as Array)[0].collision = false
	var rejected_support: Dictionary = contract.validate_supported_motion_handoff(
		Vector3(0.2, 0.0, 0.2), Vector3(1.4, 0.0, 1.4), 0.05, missing_support
	)
	_check(
		not rejected_support.accepted
			and rejected_support.reason == &"collision_tile_missing"
			and rejected_support.motion.accepted,
		"an otherwise safe movement is rejected when its LOD collision tile is absent"
	)
	var recovery: Dictionary = contract.build_support_recovery_handoff(
		Vector3(0.2, 0.0, 0.2), Vector3(1.4, 0.0, 1.4), 0.05, missing_support
	)
	_check(
		recovery.accepted and recovery.reason == &"support_recovery_required"
			and recovery.action == &"request_collision_residency"
			and recovery.safe_position == Vector3(0.2, 0.0, 0.2)
			and recovery.transform_writes == 0 and recovery.collision_writes == 0,
		"missing terrain support yields a detached collision-residency recovery action"
	)
	var long_recovery: Dictionary = contract.build_support_recovery_handoff(
		Vector3.ZERO, Vector3(2.01, 0.0, 0.0), 0.0, resident_plan
	)
	_check(
		long_recovery.accepted
			and long_recovery.action == &"subdivide_motion_sweep",
		"an overlong terrain sweep yields a safe subdivision recovery action"
	)
	var invalid: Dictionary = contract.validate_motion_sample(
		Vector3.ZERO, Vector3.ZERO, NAN
	)
	_check(
		invalid.reason == &"invalid_support_jitter"
			and contract.get_snapshot() == before,
		"non-finite samples reject atomically without retuning the contract"
	)
	var detached: Dictionary = contract.get_snapshot()
	(detached.ring_distances_meters as PackedFloat64Array)[0] = 0.0
	(detached.source_profile as Dictionary).maximum_collision_tile_count = 0
	_check(
		contract.get_snapshot().ring_distances_meters[0] == 8.0
			and contract.get_snapshot().source_profile.maximum_collision_tile_count == 4,
		"published LOD and source snapshots are detached from caller mutation"
	)


func _contract():
	var contract: Variant = ContractScript.new()
	var result: Dictionary = contract.configure(_policy(), 4.0, 2.0, 0.10, 0.50)
	if not bool(result.accepted):
		push_error("fixture contract failed to configure: %s" % result)
	return contract


func _policy() -> PlanetaryTerrainLodPolicy:
	var profile := ProfileScript.new() as PlanetaryTerrainProfile
	profile.profile_id = &"lod_collision_fixture"
	profile.clipmap_ring_distances_meters = PackedFloat64Array([8.0, 24.0, 64.0])
	profile.collision_lod_ring_index = 1
	profile.collision_maximum_distance_meters = 24.0
	profile.tile_resolution_vertices_per_edge = 33
	profile.maximum_visible_tile_count = 8
	profile.maximum_resident_tile_count = 12
	profile.maximum_collision_tile_count = 4
	var policy := PolicyScript.new() as PlanetaryTerrainLodPolicy
	var result := policy.configure(profile)
	if not bool(result.accepted):
		push_error("fixture policy failed to configure: %s" % result)
	return policy


func _tile(lod: int, tile_x: int, tile_z: int, collision: bool) -> Dictionary:
	return {
		"key": "%d:%d:%d" % [lod, tile_x, tile_z],
		"lod": lod,
		"tile_x": tile_x,
		"tile_z": tile_z,
		"collision": collision,
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_terrain_lod_collision_contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
