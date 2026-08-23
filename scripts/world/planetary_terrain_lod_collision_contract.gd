class_name PlanetaryTerrainLodCollisionContract
extends RefCounted

## Caller-owned guard contract for terrain LOD transitions and physical tile
## residency.
##
## [PlanetaryTerrainLodPolicy] already describes which rings may participate;
## this seam adds the runtime safety envelope around that description. It
## selects one hysteresis-stable render tier, checks that every tile crossed by
## a bounded movement sweep has resident collision, and reports precision
## budgets for a caller-owned Player or ship. It never loads terrain, creates
## meshes/shapes, raycasts, moves a node, or owns physics state.

const SCHEMA_VERSION := 1
const CONTRACT_VERSION: StringName = &"planetary_terrain_lod_collision_v1"
const MIN_TILE_SIZE_METERS := 1.0
const MAX_TILE_SIZE_METERS := 1_000_000.0
const MIN_SWEEP_DISTANCE_METERS := 0.001
const MAX_SWEEP_DISTANCE_METERS := 1_000_000.0
const MAX_TIER_HYSTERESIS_METERS := 100_000.0
const MAX_SUPPORT_JITTER_METERS := 10_000.0
const MAX_RESIDENCY_PATH_SAMPLES_PER_TILE := 8

var _configured := false
var _policy: PlanetaryTerrainLodPolicy
var _profile_snapshot: Dictionary = {}
var _tile_size_meters := 0.0
var _maximum_sweep_distance_meters := 0.0
var _maximum_support_jitter_meters := 0.0
var _tier_hysteresis_meters := 0.0
var _collision_lod_ring_index := -1
var _collision_maximum_distance_meters := 0.0
var _maximum_collision_tile_count := 0
var _ring_distances_meters := PackedFloat64Array()


## Freezes a validated policy and explicit motion/residency budgets once.
## The sweep budget is deliberately bounded to one tile: a caller may still
## move farther in one frame by submitting multiple validated samples.
func configure(
		policy: PlanetaryTerrainLodPolicy,
		tile_size_meters: float,
		maximum_sweep_distance_meters: float,
		maximum_support_jitter_meters: float,
		tier_hysteresis_meters: float = 0.0
	) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if policy == null or not policy.is_configured() \
			or not bool(policy.audit().get("valid", false)):
		return _result(false, &"invalid_terrain_lod_policy")
	if not _finite_bounded(
			tile_size_meters, MIN_TILE_SIZE_METERS, MAX_TILE_SIZE_METERS
		):
		return _result(false, &"invalid_tile_size")
	if not _finite_bounded(
			maximum_sweep_distance_meters,
			MIN_SWEEP_DISTANCE_METERS,
			MAX_SWEEP_DISTANCE_METERS
		):
		return _result(false, &"invalid_sweep_distance")
	if maximum_sweep_distance_meters > tile_size_meters:
		return _result(false, &"sweep_distance_exceeds_tile_size")
	if not _finite_bounded(
			maximum_support_jitter_meters, 0.0, MAX_SUPPORT_JITTER_METERS
		):
		return _result(false, &"invalid_support_jitter_budget")
	if maximum_support_jitter_meters > tile_size_meters:
		return _result(false, &"support_jitter_exceeds_tile_size")
	if not _finite_bounded(
			tier_hysteresis_meters, 0.0, MAX_TIER_HYSTERESIS_METERS
		):
		return _result(false, &"invalid_tier_hysteresis")

	var snapshot := policy.get_snapshot()
	var rings_value: Variant = snapshot.get(
		"clipmap_ring_distances_meters", PackedFloat64Array()
	)
	if not rings_value is PackedFloat64Array:
		return _result(false, &"invalid_terrain_lod_snapshot")
	var rings := rings_value as PackedFloat64Array
	if rings.size() < 2:
		return _result(false, &"invalid_terrain_lod_snapshot")
	var collision_index := int(snapshot.get("collision_lod_ring_index", -1))
	var collision_distance := float(
		snapshot.get("collision_maximum_distance_meters", 0.0)
	)
	var collision_budget := int(
		snapshot.get("maximum_collision_tile_count", 0)
	)
	if collision_index < 0 or collision_index >= rings.size() \
			or not is_finite(collision_distance) or collision_distance <= 0.0 \
			or collision_distance > rings[collision_index] \
			or collision_budget < 1:
		return _result(false, &"invalid_collision_policy_snapshot")
	if tier_hysteresis_meters >= _minimum_ring_gap(rings):
		return _result(false, &"tier_hysteresis_exceeds_ring_gap")

	_policy = policy
	_profile_snapshot = snapshot.duplicate(true)
	_ring_distances_meters = rings.duplicate()
	_tile_size_meters = tile_size_meters
	_maximum_sweep_distance_meters = maximum_sweep_distance_meters
	_maximum_support_jitter_meters = maximum_support_jitter_meters
	_tier_hysteresis_meters = tier_hysteresis_meters
	_collision_lod_ring_index = collision_index
	_collision_maximum_distance_meters = collision_distance
	_maximum_collision_tile_count = collision_budget
	_configured = true
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Selects an inclusive ring with optional transition hysteresis. A caller
## supplies its last committed ring; no internal tier state is mutated.
func evaluate_tier(
		camera_to_surface_distance_meters: Variant,
		collision_needed: Variant,
		previous_render_ring_index: int = -1
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _finite_bounded(
			camera_to_surface_distance_meters,
			0.0,
			PlanetaryTerrainProfile.MAX_LOD_DISTANCE_METERS
		):
		return _result(false, &"invalid_camera_to_surface_distance")
	if typeof(collision_needed) != TYPE_BOOL:
		return _result(false, &"invalid_collision_need")
	if previous_render_ring_index < -1 \
			or previous_render_ring_index >= _ring_distances_meters.size():
		return _result(false, &"invalid_previous_render_ring")
	var distance := float(camera_to_surface_distance_meters)
	var requested_ring := _select_ring(distance)
	var committed_ring := requested_ring
	if previous_render_ring_index >= 0 and requested_ring >= 0:
		committed_ring = _apply_hysteresis(
			requested_ring, previous_render_ring_index, distance
		)
	elif previous_render_ring_index >= 0 and requested_ring < 0:
		# Retain the outer tier until its inclusive boundary plus the guard band;
		# after that, no render tier is safe to retain.
		var outer_boundary := _ring_distances_meters[previous_render_ring_index]
		if distance <= outer_boundary + _tier_hysteresis_meters:
			committed_ring = previous_render_ring_index
	var render_participates := committed_ring >= 0
	var collision_participates := bool(collision_needed) \
			and distance <= _collision_maximum_distance_meters
	return _result(true, &"evaluated", {
		"camera_to_surface_distance_meters": distance,
		"requested_render_ring_index": requested_ring,
		"committed_render_ring_index": committed_ring,
		"render_participates": render_participates,
		"transition_required": previous_render_ring_index >= 0 \
				and committed_ring != previous_render_ring_index,
		"collision_needed": bool(collision_needed),
		"collision_participates": collision_participates,
		"collision_lod_ring_index": _collision_lod_ring_index,
		"collision_maximum_distance_meters": _collision_maximum_distance_meters,
		"collision_tile_count_ceiling": (
			_maximum_collision_tile_count if collision_participates else 0
		),
		"tier_hysteresis_meters": _tier_hysteresis_meters,
	})


## Validates that a caller-owned stream plan has collision residency for every
## tile touched by a bounded straight-line sweep. The plan may be the
## `desired_tiles` result from PlanetaryOriginStreamContract or a detached
## snapshot's `resident_tiles` array.
func validate_collision_residency(
		start_world_streaming_position: Vector3,
		end_world_streaming_position: Vector3,
		stream_plan: Variant
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _finite_vector(start_world_streaming_position) \
			or not _finite_vector(end_world_streaming_position):
		return _result(false, &"invalid_sweep_position")
	if not stream_plan is Dictionary:
		return _result(false, &"invalid_stream_plan")
	var displacement := start_world_streaming_position.distance_to(
		end_world_streaming_position
	)
	if displacement > _maximum_sweep_distance_meters:
		return _result(false, &"tunneling_budget_exceeded", {
			"sweep_distance_meters": displacement,
			"maximum_sweep_distance_meters": _maximum_sweep_distance_meters,
		})
	var plan := stream_plan as Dictionary
	var records_value: Variant = plan.get("desired_tiles", plan.get("resident_tiles", null))
	if not records_value is Array:
		return _result(false, &"missing_resident_tile_records")
	var available := {}
	var collision_count := 0
	for record_value in records_value as Array:
		if not record_value is Dictionary:
			return _result(false, &"invalid_resident_tile_record")
		var record := record_value as Dictionary
		var lod := int(record.get("lod", plan.get("lod_ring_index", -1)))
		var tile_x_value: Variant = record.get("tile_x", null)
		var tile_z_value: Variant = record.get("tile_z", null)
		if typeof(tile_x_value) != TYPE_INT or typeof(tile_z_value) != TYPE_INT \
				or lod < 0:
			return _result(false, &"invalid_resident_tile_coordinates")
		var key := _tile_key(lod, int(tile_x_value), int(tile_z_value))
		available[key] = bool(record.get("collision", false))
		if bool(record.get("collision", false)):
			collision_count += 1
	if collision_count > _maximum_collision_tile_count:
		return _result(false, &"collision_residency_budget_exceeded", {
			"resident_collision_tile_count": collision_count,
			"maximum_collision_tile_count": _maximum_collision_tile_count,
		})
	var required := _segment_tile_keys(
		start_world_streaming_position, end_world_streaming_position
	)
	var missing := PackedStringArray()
	for key in required:
		if not available.has(key) or not bool(available[key]):
			missing.append(key)
	return _result(missing.is_empty(), &"collision_resident" if missing.is_empty() else &"collision_tile_missing", {
		"sweep_distance_meters": displacement,
		"required_collision_tiles": required,
		"missing_collision_tiles": missing,
		"resident_collision_tile_count": collision_count,
		"maximum_collision_tile_count": _maximum_collision_tile_count,
	})


## Checks one caller-owned movement sample against the tunnelling and support
## jitter budgets. `support_jitter_meters` is the residual after the caller's
## expected terrain slope/vehicle motion has been removed.
func validate_motion_sample(
		previous_world_streaming_position: Vector3,
		current_world_streaming_position: Vector3,
		support_jitter_meters: Variant
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _finite_vector(previous_world_streaming_position) \
			or not _finite_vector(current_world_streaming_position):
		return _result(false, &"invalid_motion_position")
	if not _finite_bounded(
			support_jitter_meters, 0.0, MAX_SUPPORT_JITTER_METERS
		):
		return _result(false, &"invalid_support_jitter")
	var displacement := previous_world_streaming_position.distance_to(
		current_world_streaming_position
	)
	var jitter := float(support_jitter_meters)
	if displacement > _maximum_sweep_distance_meters:
		return _result(false, &"tunneling_budget_exceeded", {
			"displacement_meters": displacement,
			"maximum_sweep_distance_meters": _maximum_sweep_distance_meters,
			"support_jitter_meters": jitter,
		})
	if jitter > _maximum_support_jitter_meters:
		return _result(false, &"support_jitter_budget_exceeded", {
			"displacement_meters": displacement,
			"support_jitter_meters": jitter,
			"maximum_support_jitter_meters": _maximum_support_jitter_meters,
		})
	return _result(true, &"motion_within_budgets", {
		"displacement_meters": displacement,
		"maximum_sweep_distance_meters": _maximum_sweep_distance_meters,
		"support_jitter_meters": jitter,
		"maximum_support_jitter_meters": _maximum_support_jitter_meters,
	})


## Commits one player/ship support handoff only when the motion budgets and
## every swept terrain tile are valid together. This is the caller's atomic
## anti-tunnelling seam at an LOD transition; it never moves the actor.
func validate_supported_motion_handoff(
		previous_world_streaming_position: Vector3,
		current_world_streaming_position: Vector3,
		support_jitter_meters: Variant,
		stream_plan: Variant
	) -> Dictionary:
	var motion := validate_motion_sample(
		previous_world_streaming_position,
		current_world_streaming_position,
		support_jitter_meters
	)
	if not bool(motion.get("accepted", false)):
		return _result(false, motion.get("reason", &"motion_rejected") as StringName, {
			"motion": motion.duplicate(true),
		})
	var residency := validate_collision_residency(
		previous_world_streaming_position,
		current_world_streaming_position,
		stream_plan
	)
	if not bool(residency.get("accepted", false)):
		return _result(false, residency.get("reason", &"collision_residency_rejected") as StringName, {
			"motion": motion.duplicate(true),
			"residency": residency.duplicate(true),
		})
	return _result(true, &"supported_motion_handoff", {
		"motion": motion.duplicate(true),
		"residency": residency.duplicate(true),
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_version": CONTRACT_VERSION,
		"configured": _configured,
		"tile_size_meters": _tile_size_meters,
		"maximum_sweep_distance_meters": _maximum_sweep_distance_meters,
		"maximum_support_jitter_meters": _maximum_support_jitter_meters,
		"tier_hysteresis_meters": _tier_hysteresis_meters,
		"ring_distances_meters": _ring_distances_meters.duplicate(),
		"collision_lod_ring_index": _collision_lod_ring_index,
		"collision_maximum_distance_meters": _collision_maximum_distance_meters,
		"maximum_collision_tile_count": _maximum_collision_tile_count,
		"source_profile": _profile_snapshot.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("terrain LOD/collision contract is not configured")
	elif _policy == null or not bool(_policy.audit().get("valid", false)):
		errors.append("source terrain LOD policy audit failed")
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_version": CONTRACT_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"transition_policy": &"inclusive_rings_with_caller_committed_hysteresis",
		"collision_policy": &"all_swept_tiles_resident_and_collision_enabled",
		"tunneling_policy": &"bounded_one_tile_sweep_with_fail_closed_rejection",
		"jitter_policy": &"caller_supplied_residual_support_error_with_fixed_budget",
		"authority": {
			"terrain_generation": false,
			"renderer": false,
			"collision_generation": false,
			"physics": false,
			"movement": false,
			"streaming": false,
			"origin_shift": false,
			"gameplay": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _select_ring(distance_meters: float) -> int:
	for index in _ring_distances_meters.size():
		if distance_meters <= _ring_distances_meters[index]:
			return index
	return -1


func _apply_hysteresis(requested_ring: int, previous_ring: int, distance: float) -> int:
	if requested_ring == previous_ring or _tier_hysteresis_meters <= 0.0:
		return requested_ring
	if requested_ring > previous_ring:
		var exit_distance := _ring_distances_meters[previous_ring] \
				+ _tier_hysteresis_meters
		return previous_ring if distance <= exit_distance else requested_ring
	var enter_distance := 0.0 if previous_ring == 0 else \
			_ring_distances_meters[previous_ring - 1]
	return previous_ring if distance >= enter_distance - _tier_hysteresis_meters else requested_ring


func _segment_tile_keys(start: Vector3, end: Vector3) -> PackedStringArray:
	var horizontal_delta := Vector2(end.x - start.x, end.z - start.z)
	var horizontal_distance := horizontal_delta.length()
	var subdivisions := maxi(
		1,
		ceili(horizontal_distance / _tile_size_meters \
				* float(MAX_RESIDENCY_PATH_SAMPLES_PER_TILE))
	)
	var keys := PackedStringArray()
	for index in subdivisions + 1:
		var fraction := float(index) / float(subdivisions)
		var point := start.lerp(end, fraction)
		var tile_x := floori(point.x / _tile_size_meters)
		var tile_z := floori(point.z / _tile_size_meters)
		var key := _tile_key(_collision_lod_ring_index, tile_x, tile_z)
		if not keys.has(key):
			keys.append(key)
	return keys


func _tile_key(lod: int, tile_x: int, tile_z: int) -> String:
	return "%d:%d:%d" % [lod, tile_x, tile_z]


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"contract_version": CONTRACT_VERSION,
	}
	result.merge(details, true)
	return result.duplicate(true)


static func _finite_bounded(value: Variant, minimum: float, maximum: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _minimum_ring_gap(rings: PackedFloat64Array) -> float:
	var smallest := INF
	for index in range(1, rings.size()):
		smallest = minf(smallest, rings[index] - rings[index - 1])
	return smallest
