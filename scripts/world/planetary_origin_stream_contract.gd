class_name PlanetaryOriginStreamContract
extends RefCounted

## Bounded composition seam for a planetary coordinate frame, terrain LOD and
## local tile residency.
##
## This contract deliberately stops at planning. It converts precise absolute
## coordinates through [PlanetaryCoordinateFrame], selects one deterministic
## LOD neighbourhood, and commits a bounded detached residency set. It never
## creates terrain, moves a Node3D, invokes a loader, generates collision, or
## owns rendering, physics, gameplay, save, or network state.

const SCHEMA_VERSION := 1
const CONTRACT_VERSION: StringName = &"planetary_origin_stream_v1"
const MIN_TILE_SIZE_METERS := 1.0
const MAX_TILE_SIZE_METERS := 1_000_000.0
const MAX_STREAM_VISIBLE_BUDGET := 16_384
const MAX_STREAM_RESIDENT_BUDGET := 32_768
const MAX_STREAM_PLAN_CANDIDATES := 64

var _configured := false
var _frame: PlanetaryCoordinateFrame
var _lod_policy: PlanetaryTerrainLodPolicy
var _tile_size_meters := 0.0
var _ring_distances_meters := PackedFloat64Array()
var _collision_lod_ring_index := -1
var _collision_maximum_distance_meters := 0.0
var _visible_budget := 0
var _resident_budget := 0
var _collision_budget := 0
var _stream_epoch := 1
var _next_plan_id := 1
var _pending_stream_plan: Dictionary = {}
var _resident_tiles: Dictionary = {}


## Freezes detached frame/LOD snapshots and one hard-bounded tile policy.
## Optional stream budgets can only lower the source profile ceilings.
func configure(
		frame: PlanetaryCoordinateFrame,
		lod_policy: PlanetaryTerrainLodPolicy,
		tile_size_meters: float,
		stream_visible_budget: int = -1,
		stream_resident_budget: int = -1
	) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if frame == null or not frame.is_configured() or not bool(frame.audit().get("valid", false)):
		return _result(false, &"invalid_coordinate_frame")
	if lod_policy == null or not lod_policy.is_configured() \
			or not bool(lod_policy.audit().get("valid", false)):
		return _result(false, &"invalid_terrain_lod_policy")
	if not is_finite(tile_size_meters) or tile_size_meters < MIN_TILE_SIZE_METERS \
			or tile_size_meters > MAX_TILE_SIZE_METERS:
		return _result(false, &"invalid_tile_size")
	var lod_snapshot := lod_policy.get_snapshot()
	var rings_value: Variant = lod_snapshot.get(
		"clipmap_ring_distances_meters", PackedFloat64Array()
	)
	if not rings_value is PackedFloat64Array:
		return _result(false, &"invalid_lod_snapshot")
	var rings := rings_value as PackedFloat64Array
	if rings.size() < 2 or rings.size() > MAX_STREAM_PLAN_CANDIDATES:
		return _result(false, &"invalid_lod_ring_count")
	var visible_source := int(lod_snapshot.get("maximum_visible_tile_count", 0))
	var resident_source := int(lod_snapshot.get("maximum_resident_tile_count", 0))
	var collision_source := int(lod_snapshot.get("maximum_collision_tile_count", 0))
	if visible_source < 1 or resident_source < visible_source \
			or collision_source < 1 or collision_source > visible_source:
		return _result(false, &"invalid_lod_budgets")
	var visible := visible_source if stream_visible_budget < 0 else stream_visible_budget
	var resident := resident_source if stream_resident_budget < 0 else stream_resident_budget
	if visible < 1 or visible > visible_source or visible > MAX_STREAM_VISIBLE_BUDGET:
		return _result(false, &"invalid_visible_budget")
	if resident < visible or resident > resident_source \
			or resident > MAX_STREAM_RESIDENT_BUDGET:
		return _result(false, &"invalid_resident_budget")

	_frame = frame
	_lod_policy = lod_policy
	_tile_size_meters = tile_size_meters
	_ring_distances_meters = rings.duplicate()
	_collision_lod_ring_index = int(lod_snapshot.get("collision_lod_ring_index", -1))
	_collision_maximum_distance_meters = float(
		lod_snapshot.get("collision_maximum_distance_meters", 0.0)
	)
	_visible_budget = visible
	_resident_budget = resident
	_collision_budget = mini(collision_source, resident)
	_configured = true
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


func get_generation() -> int:
	return _frame.get_generation() if _frame != null else 0


## Precision-preserving wrappers keep absolute cell identity separate from the
## bounded local Vector3 used by a renderer/physics caller.
func encode_body_local_position(body_local_position: Vector3, expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	return _frame.encode_body_local_position(body_local_position, expected_generation)


func decode_world_streaming_position(world_position: Vector3, expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	return _frame.decode_world_streaming_position(world_position, expected_generation)


## Evaluates a local focus against the frozen inclusive origin threshold. No
## request or world transform is committed by this method.
func evaluate_origin_shift(focus_world_streaming_position: Vector3, expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	return _frame.evaluate_origin_shift(focus_world_streaming_position, expected_generation)


func request_origin_shift(focus_world_streaming_position: Vector3, expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	return _frame.request_rebase(focus_world_streaming_position, expected_generation)


## Commits the frame transaction and invalidates local tile residency. A caller
## must request a fresh stream plan in the new generation; this prevents stale
## local tile coordinates from surviving a floating-origin shift.
func commit_origin_shift(request_id: int, expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	var committed := _frame.commit_rebase(request_id, expected_generation)
	if not bool(committed.get("accepted", false)):
		return committed
	var invalidated := _resident_tiles.size()
	_resident_tiles.clear()
	_pending_stream_plan.clear()
	_stream_epoch += 1
	var result := committed.duplicate(true)
	result["stream_epoch"] = _stream_epoch
	result["invalidated_resident_tile_count"] = invalidated
	result["stream_replan_required"] = true
	return result


## Builds a deterministic bounded tile plan around a local focus. The plan is
## caller-committed, so this method is safe to call during a read/evaluation
## phase. One pending plan per generation is allowed.
func request_stream_plan(focus_world_streaming_position: Vector3, expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _pending_stream_plan.is_empty():
		return _result(false, &"stream_plan_already_pending")
	if not (_frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty():
		return _result(false, &"origin_shift_pending")
	if expected_generation != _frame.get_generation():
		return _result(false, &"stale_generation")
	if not focus_world_streaming_position.is_finite():
		return _result(false, &"invalid_stream_focus")
	var distance := focus_world_streaming_position.length()
	var ring := _select_ring(distance)
	if ring < 0:
		return _result(false, &"focus_outside_lod_envelope")
	var focus_tile_x := floori(focus_world_streaming_position.x / _tile_size_meters)
	var focus_tile_z := floori(focus_world_streaming_position.z / _tile_size_meters)
	# Fine rings use a 5x5 neighbourhood; far rings use a 3x3 or one tile.
	var radius := 2 if ring == 0 else (1 if ring < _ring_distances_meters.size() - 1 else 0)
	var candidates: Array[Dictionary] = []
	for tile_z in range(focus_tile_z - radius, focus_tile_z + radius + 1):
		for tile_x in range(focus_tile_x - radius, focus_tile_x + radius + 1):
			var center := Vector3(
				(float(tile_x) + 0.5) * _tile_size_meters,
				0.0,
				(float(tile_z) + 0.5) * _tile_size_meters
			)
			var key := "%d:%d:%d" % [ring, tile_x, tile_z]
			candidates.append({
				"key": key,
				"lod": ring,
				"tile_x": tile_x,
				"tile_z": tile_z,
				"center_world_streaming_meters": center,
				"distance_to_focus_meters": center.distance_to(focus_world_streaming_position),
				"collision": false,
			})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance_to_focus_meters", INF))
		var right_distance := float(right.get("distance_to_focus_meters", INF))
		if not is_equal_approx(left_distance, right_distance):
			return left_distance < right_distance
		return str(left.get("key", "")) < str(right.get("key", ""))
	)
	var desired: Array[Dictionary] = []
	var collision_count := 0
	for candidate in candidates:
		if desired.size() >= _visible_budget or desired.size() >= _resident_budget:
			break
		var record := candidate.duplicate(true)
		var collision_allowed := ring <= _collision_lod_ring_index \
				and distance <= _collision_maximum_distance_meters \
				and collision_count < _collision_budget
		if collision_allowed:
			record["collision"] = true
			collision_count += 1
		desired.append(record)
	var plan_id := _next_plan_id
	_next_plan_id += 1
	_pending_stream_plan = {
		"schema_version": SCHEMA_VERSION,
		"plan_id": plan_id,
		"stream_epoch": _stream_epoch,
		"coordinate_frame_generation": expected_generation,
		"focus_world_streaming_meters": focus_world_streaming_position,
		"lod_ring_index": ring,
		"desired_tiles": desired.duplicate(true),
		"visible_budget": _visible_budget,
		"resident_budget": _resident_budget,
		"collision_budget": _collision_budget,
	}
	return _result(true, &"stream_plan_ready", {"plan": _pending_stream_plan.duplicate(true)})


## Applies only the internally frozen plan identified by the caller's detached
## plan ID. No tile scene or terrain resource is loaded here.
func commit_stream_plan(plan: Variant) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not plan is Dictionary:
		return _result(false, &"invalid_stream_plan")
	if _pending_stream_plan.is_empty():
		return _result(false, &"no_stream_plan_pending")
	if not (_frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty():
		return _result(false, &"origin_shift_pending")
	var candidate := plan as Dictionary
	if int(candidate.get("plan_id", -1)) != int(_pending_stream_plan.get("plan_id", -2)):
		return _result(false, &"stale_stream_plan")
	if int(_pending_stream_plan.get("coordinate_frame_generation", 0)) != _frame.get_generation():
		return _result(false, &"stale_generation")
	var before := _resident_tiles.keys()
	var next: Dictionary = {}
	for tile_value in _pending_stream_plan.get("desired_tiles", []) as Array:
		var tile := tile_value as Dictionary
		next[str(tile.get("key", ""))] = tile.duplicate(true)
	var after := next.keys()
	var loaded := PackedStringArray()
	var unloaded := PackedStringArray()
	for key in after:
		if not before.has(key):
			loaded.append(str(key))
	for key in before:
		if not after.has(key):
			unloaded.append(str(key))
	loaded.sort()
	unloaded.sort()
	_resident_tiles = next
	var committed_plan := _pending_stream_plan.duplicate(true)
	_pending_stream_plan.clear()
	return _result(true, &"stream_plan_committed", {
		"plan": committed_plan,
		"loaded_tile_keys": loaded,
		"unloaded_tile_keys": unloaded,
		"resident_tile_count": _resident_tiles.size(),
		"collision_tile_count": _collision_tile_count(),
	})


func cancel_stream_plan(plan_id: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if _pending_stream_plan.is_empty():
		return _result(false, &"no_stream_plan_pending")
	if plan_id != int(_pending_stream_plan.get("plan_id", -1)):
		return _result(false, &"stale_stream_plan")
	_pending_stream_plan.clear()
	return _result(true, &"stream_plan_cancelled")


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_version": CONTRACT_VERSION,
		"configured": _configured,
		"coordinate_frame_generation": get_generation(),
		"coordinate_frame": _frame.get_snapshot() if _frame != null else {},
		"terrain_lod": _lod_policy.get_snapshot() if _lod_policy != null else {},
		"tile_size_meters": _tile_size_meters,
		"ring_distances_meters": _ring_distances_meters.duplicate(),
		"collision_lod_ring_index": _collision_lod_ring_index,
		"collision_maximum_distance_meters": _collision_maximum_distance_meters,
		"visible_budget": _visible_budget,
		"resident_budget": _resident_budget,
		"collision_budget": _collision_budget,
		"stream_epoch": _stream_epoch,
		"pending_stream_plan": _pending_stream_plan.duplicate(true),
		"resident_tiles": _resident_tiles.values().duplicate(true),
		"resident_tile_count": _resident_tiles.size(),
		"collision_tile_count": _collision_tile_count(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("planetary origin/stream contract is not configured")
	else:
		if _frame == null or not bool(_frame.audit().get("valid", false)):
			errors.append("coordinate frame audit failed")
		if _lod_policy == null or not bool(_lod_policy.audit().get("valid", false)):
			errors.append("terrain LOD audit failed")
		if _resident_tiles.size() > _resident_budget:
			errors.append("resident tiles exceed the frozen budget")
		if _pending_stream_plan.size() > 0 \
				and int(_pending_stream_plan.get("coordinate_frame_generation", 0)) != get_generation():
			errors.append("pending stream plan generation is stale")
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_version": CONTRACT_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"coordinate_policy": &"safe_integer_orbital_cells_plus_bounded_local_metres",
		"origin_policy": &"generation_fenced_two_phase_rebase_invalidates_local_residency",
		"streaming_policy": &"deterministic_focus_neighbourhood_with_visible_and_resident_ceilings",
		"lod_policy": &"inclusive_near_to_far_rings_with_bounded_collision_subset",
		"authority": {
			"automatic_process": false,
			"renderer": false,
			"physics": false,
			"terrain_generation": false,
			"collision_generation": false,
			"streaming_loader": false,
			"gameplay": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func _select_ring(distance_meters: float) -> int:
	for index in _ring_distances_meters.size():
		if distance_meters <= _ring_distances_meters[index]:
			return index
	return -1


func _collision_tile_count() -> int:
	var count := 0
	for value in _resident_tiles.values():
		if bool((value as Dictionary).get("collision", false)):
			count += 1
	return count


func _result(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"coordinate_frame_generation": get_generation(),
		"stream_epoch": _stream_epoch,
	}
	result.merge(details, true)
	return result.duplicate(true)
