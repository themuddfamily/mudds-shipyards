extends SceneTree

const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const ProfileScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const LodScript := preload("res://scripts/world/planetary_terrain_lod_policy.gd")
const ContractScript := preload("res://scripts/world/planetary_origin_stream_contract.gd")

const BODY_ID: StringName = &"ember_moon"
const ORBITAL_FRAME_ID: StringName = &"nearby_sector"
const CELL_SIZE := 10_000.0
const HUGE_CELL_X := FrameScript.MAX_SAFE_INTEGER - 100
const HUGE_CELL_Y := -FrameScript.MAX_SAFE_INTEGER + 100
const SHIFT_THRESHOLD := 5_000.0

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_detached_snapshots()
	_test_precision_and_lod_plans()
	_test_origin_invalidation_and_generation_fence()
	_test_authority_and_invalid_inputs()
	_finish()


func _test_configuration_and_detached_snapshots() -> void:
	var frame := _frame()
	var policy := _lod_policy()
	var contract := ContractScript.new()
	_check(
		contract.configure(frame, null, 64.0).reason == &"invalid_terrain_lod_policy"
			and not contract.is_configured(),
		"missing terrain LOD policy rejects without partial configuration"
	)
	var configured := contract.configure(frame, policy, 64.0, 32, 48)
	var snapshot := contract.get_snapshot()
	_check(
		bool(configured.accepted)
			and contract.is_configured()
			and int(snapshot.visible_budget) == 32
			and int(snapshot.resident_budget) == 48
			and snapshot.contract_version == &"planetary_origin_stream_v1",
		"one valid frame/LOD composition freezes explicit bounded stream ceilings"
	)
	var detached := contract.get_snapshot()
	(detached.coordinate_frame as Dictionary)["generation"] = 900
	(detached.terrain_lod as Dictionary)["maximum_visible_tile_count"] = 1
	(detached.resident_tiles as Array).append({"key": "forged"})
	_check(
		int(contract.get_snapshot().coordinate_frame.generation) == 1
			and int(contract.get_snapshot().terrain_lod.maximum_visible_tile_count) == 512
			and contract.get_snapshot().resident_tiles.is_empty(),
		"nested snapshots and resident arrays are detached from caller mutation"
	)


func _test_precision_and_lod_plans() -> void:
	var contract := _contract()
	var generation := contract.get_generation()
	var first := contract.encode_body_local_position(
		Vector3(0.125, -0.375, 120000.0625), generation
	)
	var second := contract.encode_body_local_position(
		Vector3(0.1875, -0.3125, 120000.125), generation
	)
	var first_world := first.coordinate.world_streaming_position as Vector3
	var second_world := second.coordinate.world_streaming_position as Vector3
	var decoded := contract.decode_world_streaming_position(second_world, generation)
	_check(
		bool(first.accepted)
			and bool(second.accepted)
			and first.coordinate.orbital_coordinate.cell_x == HUGE_CELL_X
			and first.coordinate.orbital_coordinate.cell_y == HUGE_CELL_Y
			and first_world.distance_to(second_world) < 0.2
			and (decoded.coordinate.orbital_coordinate as Dictionary)
				== (second.coordinate.orbital_coordinate as Dictionary),
		"sub-metre local deltas remain stable beside near-maximum absolute cell identities"
	)
	var near := contract.request_stream_plan(Vector3(4.0, 0.0, 4.0), generation)
	var near_plan := near.plan as Dictionary
	var near_tiles := near_plan.desired_tiles as Array
	_check(
		bool(near.accepted)
			and near.reason == &"stream_plan_ready"
			and int(near_plan.lod_ring_index) == 0
			and near_tiles.size() <= 32
			and near_tiles.size() <= 48
			and bool((near_tiles[0] as Dictionary).has("collision")),
		"near focus selects the inclusive finest LOD and stays within visible/resident ceilings"
	)
	var forged_plan := near_plan.duplicate(true)
	(forged_plan.desired_tiles as Array).clear()
	var committed_near := contract.commit_stream_plan(forged_plan)
	_check(
		bool(committed_near.accepted)
			and int(committed_near.resident_tile_count) == near_tiles.size()
			and int(committed_near.collision_tile_count) > 0
			and contract.get_snapshot().resident_tile_count == near_tiles.size(),
		"commit consumes the internally frozen plan rather than forged detached tile data"
	)
	var far := contract.request_stream_plan(Vector3(5000.0, 0.0, 5000.0), generation)
	var far_plan := far.plan as Dictionary
	_check(
		bool(far.accepted)
			and int(far_plan.lod_ring_index) >= 3
			and (far_plan.desired_tiles as Array).size() <= 9,
		"far focus selects a coarser ring with a bounded neighbourhood"
	)
	var far_commit := contract.commit_stream_plan(far_plan)
	_check(
		bool(far_commit.accepted)
			and int(far_commit.resident_tile_count) <= 48
			and contract.request_stream_plan(Vector3.ZERO, generation).reason == &"stream_plan_already_pending"
			== false,
		"a committed far plan replaces rather than grows unbounded local residency"
	)


func _test_origin_invalidation_and_generation_fence() -> void:
	var contract := _contract()
	var generation := contract.get_generation()
	var plan_result := contract.request_stream_plan(Vector3.ZERO, generation)
	var plan := plan_result.plan as Dictionary
	contract.commit_stream_plan(plan)
	var before_epoch := int(contract.get_snapshot().stream_epoch)
	var request := contract.request_origin_shift(Vector3(SHIFT_THRESHOLD, 0.0, 0.0), generation)
	var request_id := int(request.request.request_id)
	_check(
		bool(request.accepted)
			and contract.request_stream_plan(Vector3.ZERO, generation).reason == &"origin_shift_pending",
		"origin requests are generation-fenced and block local streaming while pending"
	)
	var committed := contract.commit_origin_shift(request_id, generation)
	var after := contract.get_snapshot()
	_check(
		bool(committed.accepted)
			and int(after.coordinate_frame_generation) == generation + 1
			and int(after.stream_epoch) == before_epoch + 1
			and int(after.resident_tile_count) == 0
			and bool(committed.stream_replan_required)
			and int(committed.invalidated_resident_tile_count) > 0,
		"an atomic origin commit invalidates local residency and requires a new plan"
	)
	_check(
		contract.request_stream_plan(Vector3.ZERO, generation).reason == &"stale_generation"
			and contract.request_stream_plan(Vector3.ZERO, generation + 1).accepted,
		"pre-shift stream samples cannot be replayed after the generation advances"
	)
	var pending := contract.get_snapshot().pending_stream_plan as Dictionary
	if not pending.is_empty():
		contract.cancel_stream_plan(int(pending.plan_id))


func _test_authority_and_invalid_inputs() -> void:
	var contract := _contract()
	var generation := contract.get_generation()
	_check(
		contract.request_stream_plan(Vector3(NAN, 0.0, 0.0), generation).reason == &"invalid_stream_focus"
			and contract.request_stream_plan(Vector3.ZERO, generation + 1).reason == &"stale_generation",
		"non-finite focus and stale generations fail closed before stream mutation"
	)
	var audit := contract.audit()
	var authority := audit.authority as Dictionary
	_check(
		bool(audit.valid)
			and not bool(authority.renderer)
			and not bool(authority.physics)
			and not bool(authority.terrain_generation)
			and not bool(authority.streaming_loader)
			and not bool(authority.save)
			and not bool(authority.network),
		"audit states the bounded contract has no engine, loader, or persistence authority"
	)


func _contract() -> PlanetaryOriginStreamContract:
	var contract := ContractScript.new() as PlanetaryOriginStreamContract
	var result := contract.configure(_frame(), _lod_policy(), 64.0, 32, 48)
	if not bool(result.accepted):
		_failures.append("test fixture failed to configure: %s" % result.reason)
	return contract


func _frame() -> PlanetaryCoordinateFrame:
	var frame := FrameScript.new() as PlanetaryCoordinateFrame
	var body_center := _coordinate(HUGE_CELL_X, HUGE_CELL_Y, 12_345, Vector3.ZERO)
	var origin := _coordinate(HUGE_CELL_X, HUGE_CELL_Y, 12_345, Vector3.ZERO)
	var result := frame.configure(
		BODY_ID,
		120000.0,
		ORBITAL_FRAME_ID,
		CELL_SIZE,
		body_center,
		Vector3.BACK,
		Vector3.UP,
		SHIFT_THRESHOLD,
		origin
	)
	if not bool(result.accepted):
		_failures.append("frame fixture failed to configure: %s" % result.reason)
	return frame


func _lod_policy() -> PlanetaryTerrainLodPolicy:
	var policy := LodScript.new() as PlanetaryTerrainLodPolicy
	var profile := ProfileScript.new() as PlanetaryTerrainProfile
	var result := policy.configure(profile)
	if not bool(result.accepted):
		_failures.append("LOD fixture failed to configure: %s" % result.reason)
	return policy


func _coordinate(cell_x: int, cell_y: int, cell_z: int, offset: Vector3) -> Dictionary:
	return {
		"schema_version": 1,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_ORIGIN_STREAM_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	printerr(
		"PLANETARY_ORIGIN_STREAM_CONTRACT_TEST_FAILED: %d / %d assertions failed"
		% [_failures.size(), _assertions]
	)
	quit(1)
