class_name PilotFootIK
extends RefCounted

## Runtime per-foot IK support owned by [PilotSkinnedPresentation].
##
## The presentation keeps the two-bone leg solve and the pelvis offset; this
## helper owns everything around it that must stay cheap and presentation-only:
##
## - one supplementary toe support ray per foot (the gameplay owner already
##   casts one ankle ray per foot), so a boot whose toe sits over a stair tread
##   or a terrain bump is planted on it instead of cutting through it;
## - the global IK weight, blended in when the pilot becomes grounded and out
##   when he is seated, boarding, sleeping, airborne or the carried frame is
##   unstable, instead of snapping the legs back to the clip;
## - gating: no probes and no solve for pilots far from the active camera, for
##   remote-driven bodies simulated on a headless peer, or while the moving
##   interior frame is swinging hard.
##
## It is a RefCounted, never a node: the presentation's runtime node roster is
## a frozen contract, and it must never own a SkeletonModifier3D.

const MAX_CAMERA_DISTANCE_M := 50.0
const BLEND_IN_SECONDS := 0.10
const BLEND_OUT_SECONDS := 0.18
## A carried deck shaking this hard (impacts, violent manoeuvring) for several
## consecutive ticks makes planted boots jitter against the hull, so the legs
## fall back to the clip until it settles. The frame owner zeroes its
## kinematics on a teleport or reset, and every tick re-casts its own supports,
## so a single discontinuity or a steady turn never trips this.
const UNSTABLE_FRAME_ACCELERATION_MPS2 := 30.0
const UNSTABLE_FRAME_ANGULAR_ACCELERATION_RAD_S2 := 20.0
const UNSTABLE_STREAK_TICKS := 3
const UNSTABLE_HOLD_SECONDS := 0.25
const TOE_RAY_RISE_M := 0.33
const TOE_RAY_DROP_M := 0.37
## A toe support at least this far above the ankle support's plane is a real
## step or bump under the toe, not ramp or triangle noise.
const TOE_STEP_MIN_M := 0.015

var weight := 1.0
var gate_reason := StringName()
var toe_probe_count := 0
var _last_weight_key := -1
var _last_gate_key := -1
var _unstable_streak := 0
var _unstable_until_key := -1
# Bone index -> Quaternion. `_leg_source` is the clip pose the solve started
# from, `_leg_applied` the rotation written last, `_leg_delta` the full-weight
# IK offset from source that the blend scales.
var _leg_source := {}
var _leg_applied := {}
var _leg_delta := {}


func reset() -> void:
	weight = 1.0
	gate_reason = &""
	toe_probe_count = 0
	_last_weight_key = -1
	_last_gate_key = -1
	_unstable_streak = 0
	_unstable_until_key = -1
	_leg_source.clear()
	_leg_applied.clear()
	_leg_delta.clear()


## Returns an empty reason when the presentation may solve this tick, or the
## reason it must blend out instead.
func evaluate_gate(presentation: Node3D, tick_key: int) -> StringName:
	gate_reason = &""
	var body := find_body(presentation)
	if (
		body != null and DisplayServer.get_name() == "headless"
		and body.has_method(&"is_remote_driven") and bool(body.call(&"is_remote_driven"))
	):
		gate_reason = &"foot_ik_headless_remote"
		return gate_reason
	var viewport := presentation.get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if (
		camera != null and camera.is_inside_tree()
		and camera.global_position.distance_to(presentation.global_position) > MAX_CAMERA_DISTANCE_M
	):
		gate_reason = &"foot_ik_beyond_camera_distance"
		return gate_reason
	var ticks := maxf(1.0, float(Engine.physics_ticks_per_second))
	if tick_key != _last_gate_key:
		_last_gate_key = tick_key
		if _frame_is_shaking(_frame_owner(body)):
			_unstable_streak += 1
		else:
			_unstable_streak = 0
		if _unstable_streak >= UNSTABLE_STREAK_TICKS:
			_unstable_until_key = tick_key + ceili(UNSTABLE_HOLD_SECONDS * ticks)
	if tick_key <= _unstable_until_key:
		gate_reason = &"foot_ik_unstable_frame"
	return gate_reason


## Steps the global weight once per tick key toward `target`.
func step_weight(target: float, tick_key: int) -> float:
	if tick_key == _last_weight_key:
		return weight
	_last_weight_key = tick_key
	var ticks := maxf(1.0, float(Engine.physics_ticks_per_second))
	var seconds := BLEND_IN_SECONDS if target > weight else BLEND_OUT_SECONDS
	weight = move_toward(weight, clampf(target, 0.0, 1.0), 1.0 / maxf(1.0, seconds * ticks))
	return weight


func snap_weight(tick_key: int) -> void:
	weight = 1.0
	_last_weight_key = tick_key


## Puts each leg bone back on the clip pose the solve should start from. When
## the imported player has re-sampled the bone since our last write, that
## sample is the new source; otherwise the stored source is restored so a
## repeated call without an animation advance never compounds the IK.
func restore_leg_sources(skeleton: Skeleton3D, bone_indices: Array[int]) -> void:
	for bone in bone_indices:
		var current := skeleton.get_bone_pose_rotation(bone)
		var source := current
		if (
			_leg_applied.has(bone) and _leg_source.has(bone)
			and current.is_equal_approx(_leg_applied[bone] as Quaternion)
		):
			source = _leg_source[bone] as Quaternion
			skeleton.set_bone_pose_rotation(bone, source)
		_leg_source[bone] = source
		_leg_applied[bone] = source


## Records the full-weight solve as a delta from source and writes the pose at
## the current weight.
func commit_leg_solution(skeleton: Skeleton3D, bone_indices: Array[int]) -> void:
	for bone in bone_indices:
		var source: Quaternion = _leg_source.get(bone, skeleton.get_bone_pose_rotation(bone))
		var solved := skeleton.get_bone_pose_rotation(bone)
		_leg_delta[bone] = (source.inverse() * solved).normalized()
		var final_rotation := solved
		if weight < 1.0:
			final_rotation = source.slerp(solved, weight).normalized()
			skeleton.set_bone_pose_rotation(bone, final_rotation)
		_leg_applied[bone] = final_rotation


## Applies the last solved IK offset at the decaying weight on top of whatever
## clip is now playing. Called on every tick the presentation is not solving.
func apply_leg_residual(skeleton: Skeleton3D, bone_indices: Array[int], tick_key: int) -> void:
	step_weight(0.0, tick_key)
	if _leg_delta.is_empty():
		return
	restore_leg_sources(skeleton, bone_indices)
	if weight <= 0.0:
		_leg_delta.clear()
		return
	for bone in bone_indices:
		if not _leg_delta.has(bone):
			continue
		var source: Quaternion = _leg_source[bone]
		var final_rotation := (
			source * Quaternion.IDENTITY.slerp(_leg_delta[bone] as Quaternion, weight)
		).normalized()
		skeleton.set_bone_pose_rotation(bone, final_rotation)
		_leg_applied[bone] = final_rotation


## Detach cleanup: leaves the clip pose on the skeleton and forgets the solve.
func release(skeleton: Skeleton3D, bone_indices: Array[int]) -> void:
	if is_instance_valid(skeleton) and not _leg_applied.is_empty():
		restore_leg_sources(skeleton, bone_indices)
	reset()


## One ray under the boot toe, cast in the same collision space as the gameplay
## owner's ankle ray. Returns {} when there is no walkable support or no body
## context (a bare presentation in a capture harness).
func probe_toe_support(presentation: Node3D, toe_world: Vector3, movement_up: Vector3) -> Dictionary:
	var body := find_body(presentation)
	if body == null or not body.is_inside_tree() or not toe_world.is_finite():
		return {}
	var world := body.get_world_3d()
	if world == null:
		return {}
	var collision_transform := Transform3D.IDENTITY
	var frame_owner: Variant = _frame_owner(body)
	if frame_owner != null and frame_owner.has_method(&"get_occupant_collision_transform"):
		var published: Variant = frame_owner.call(&"get_occupant_collision_transform", body)
		if published is Transform3D and (published as Transform3D).is_finite():
			collision_transform = published as Transform3D
	var query := PhysicsRayQueryParameters3D.create(
		collision_transform * (toe_world + movement_up * TOE_RAY_RISE_M),
		collision_transform * (toe_world - movement_up * TOE_RAY_DROP_M),
		body.collision_mask
	)
	query.exclude = [body.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false
	toe_probe_count += 1
	var hit := world.direct_space_state.intersect_ray(query)
	var position: Variant = hit.get("position", Vector3.INF)
	var normal: Variant = hit.get("normal", Vector3.ZERO)
	if (
		not position is Vector3 or not (position as Vector3).is_finite()
		or not normal is Vector3 or not (normal as Vector3).is_finite()
		or (normal as Vector3).is_zero_approx()
	):
		return {}
	var collision_up := (collision_transform.basis * movement_up).normalized()
	if (normal as Vector3).normalized().dot(collision_up) < cos(body.floor_max_angle):
		return {}
	var carried := collision_transform.affine_inverse()
	return {
		"position": carried * (position as Vector3),
		"normal": (carried.basis * (normal as Vector3)).normalized(),
	}


## Folds a toe support into the ankle support. A toe resting higher than the
## ankle plane (a stair tread, a rock) shifts the support plane up to it, so the
## whole boot rises onto it; otherwise the ankle support stands.
static func merge_toe_support(heel: Variant, toe: Dictionary) -> Variant:
	if toe.is_empty():
		return heel
	if not heel is Dictionary:
		return toe.duplicate(true)
	var heel_position: Variant = (heel as Dictionary).get("position", Vector3.INF)
	var heel_normal: Variant = (heel as Dictionary).get("normal", Vector3.ZERO)
	if (
		not heel_position is Vector3 or not (heel_position as Vector3).is_finite()
		or not heel_normal is Vector3 or not (heel_normal as Vector3).is_finite()
		or (heel_normal as Vector3).is_zero_approx()
	):
		return toe.duplicate(true)
	var normal := (heel_normal as Vector3).normalized()
	var rise := ((toe.position as Vector3) - (heel_position as Vector3)).dot(normal)
	if rise < TOE_STEP_MIN_M:
		return heel
	return {
		"position": (heel_position as Vector3) + normal * rise,
		"normal": normal,
		"toe_raised_m": rise,
	}


static func find_body(presentation: Node) -> CharacterBody3D:
	var node := presentation.get_parent() if presentation != null else null
	var depth := 0
	while node != null and depth < 6:
		if node is CharacterBody3D:
			return node as CharacterBody3D
		node = node.get_parent()
		depth += 1
	return null


static func _frame_is_shaking(frame_owner: Variant) -> bool:
	if frame_owner == null:
		return false
	for probe: Array in [
		[&"get_frame_linear_acceleration", UNSTABLE_FRAME_ACCELERATION_MPS2],
		[&"get_frame_angular_acceleration", UNSTABLE_FRAME_ANGULAR_ACCELERATION_RAD_S2],
	]:
		if not (frame_owner as Object).has_method(probe[0]):
			continue
		var value: Variant = (frame_owner as Object).call(probe[0])
		if value is Vector3 and (value as Vector3).is_finite() and (value as Vector3).length() > float(probe[1]):
			return true
	return false


static func _frame_owner(body: Node) -> Variant:
	if body == null or not body.has_meta(&"_moving_interior_frame_owner"):
		return null
	var owner_ref: Variant = body.get_meta(&"_moving_interior_frame_owner")
	if not owner_ref is WeakRef:
		return null
	var frame_owner: Variant = (owner_ref as WeakRef).get_ref()
	return frame_owner if is_instance_valid(frame_owner) else null
