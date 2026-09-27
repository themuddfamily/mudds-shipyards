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

## --- Locomotion stance (walk/run) ------------------------------------------
## The walk and run clips are treadmill cycles authored on a flat deck: the
## skeleton origin is the floor, and a boot in stance slides backward toward
## the heel while its lowest sole corner sits near that floor. Stance is read
## from the live (possibly blended) clip pose every tick, so idle/walk/run
## blends need no per-clip tables: a foot is in stance when its sole is within
## a few centimetres of the clip floor AND it is travelling backward in clip
## time. Swing feet (moving forward, including the placeholder walk's toe drag)
## stay on the clip.
const STANCE_HEIGHT_FULL_M := 0.06
const STANCE_HEIGHT_NONE_M := 0.10
## Backward sole speed in clip seconds (independent of playback rate).
const STANCE_BACKWARD_SPEED_NONE_MPS := -0.2
const STANCE_BACKWARD_SPEED_FULL_MPS := 0.4
## Stance weight travel time, so heel strike and toe-off ramp in and out over a
## few ticks instead of switching the plant in one.
const STANCE_BLEND_SECONDS := 0.05
## A carried body that moves this far along its up axis in ONE grounded tick
## snapped over a stair nosing (floor snap down or step-up assist). The visual
## pelvis absorbs the jump and eases it out, so the torso never pops a riser.
## Smaller per-tick changes are ordinary ramp travel; larger ones are teleports.
const BODY_STEP_ABSORB_MIN_M := 0.03
const BODY_STEP_ABSORB_MAX_M := 0.36
## A planted or lifted boot lowers relative to its clip pose at most this fast
## (plus whatever the pelvis moved that tick): a stance boot sliding off a tread
## edge settles onto the lower tread instead of dropping a riser in one tick.
## Rising is never limited, because a sole must not cut through a tread.
const LOCOMOTION_FOOT_DESCENT_MPS := 3.0

var stance_weights := {&"l": 1.0, &"r": 1.0}
var _stance_motion := {&"l": 1.0, &"r": 1.0}
var _stance_forward := {}
var _stance_clip := StringName()
var _stance_clip_time := -INF
var _stance_tick := -1
var _stance_held := false
var _body_height := NAN
var _body_height_tick := -1
var _foot_correction := {}
var _foot_correction_tick := {}

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
	reset_locomotion()


func reset_locomotion() -> void:
	stance_weights = {&"l": 1.0, &"r": 1.0}
	_stance_motion = {&"l": 1.0, &"r": 1.0}
	_stance_forward.clear()
	_stance_clip = &""
	_stance_clip_time = -INF
	_stance_tick = -1
	_stance_held = false
	_body_height = NAN
	_body_height_tick = -1
	_foot_correction.clear()
	_foot_correction_tick.clear()


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
	var collision_transform := _collision_transform(body)
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


# --- Locomotion stance, body-step absorption and boot descent ---------------

## Stance weight per foot for a walk/run tick. `samples` maps each side to
## Vector2(lowest clip sole corner height above the clip floor, sole forward
## coordinate), both in skeleton space from the clip pose before any IK.
## `assume_planted` (the moving-to-idle blend) treats both boots as travelling
## backward, so only sole height decides.
func update_stance(
		samples: Dictionary, clip: StringName, clip_time: float, clip_length: float,
		tick_key: int, assume_planted: bool = false
	) -> Dictionary:
	if tick_key == _stance_tick:
		return stance_weights.duplicate()
	var consecutive := tick_key == _stance_tick + 1
	var clip_dt := 0.0
	if consecutive and clip == _stance_clip and is_finite(_stance_clip_time):
		clip_dt = clip_time - _stance_clip_time
		if clip_length > 0.0 and clip_dt < -0.5 * clip_length:
			clip_dt += clip_length
	var ticks := maxf(1.0, float(Engine.physics_ticks_per_second))
	var blend_step := 1.0 / maxf(1.0, STANCE_BLEND_SECONDS * ticks)
	for side: StringName in [&"l", &"r"]:
		var sample: Variant = samples.get(side, null)
		if not sample is Vector2 or not (sample as Vector2).is_finite():
			stance_weights[side] = move_toward(float(stance_weights.get(side, 1.0)), 0.0, blend_step)
			_stance_forward.erase(side)
			continue
		var height := (sample as Vector2).x
		var forward := (sample as Vector2).y
		if assume_planted:
			_stance_motion[side] = 1.0
		elif clip_dt > 0.00001 and _stance_forward.has(side):
			_stance_motion[side] = stance_motion_factor(
				(float(_stance_forward[side]) - forward) / clip_dt
			)
		var raw := float(_stance_motion.get(side, 1.0)) * stance_height_factor(height)
		# Leaving idle or landing (or after a gated gap) starts from what the
		# pose shows now, so a boot already lifted is never pulled down to ramp out.
		var previous := raw
		if consecutive and not _stance_held:
			previous = float(stance_weights.get(side, 1.0))
		stance_weights[side] = move_toward(previous, raw, blend_step)
		_stance_forward[side] = forward
	_stance_clip = clip
	_stance_clip_time = clip_time
	_stance_tick = tick_key
	_stance_held = false
	return stance_weights.duplicate()


## Standing: both boots are planted. Keeps the stance clock continuous so the
## first walk tick after idle starts from planted feet instead of a guess.
func hold_stance_planted(clip: StringName, clip_time: float, tick_key: int) -> void:
	stance_weights = {&"l": 1.0, &"r": 1.0}
	_stance_motion = {&"l": 1.0, &"r": 1.0}
	_stance_forward.clear()
	_stance_clip = clip
	_stance_clip_time = clip_time
	_stance_tick = tick_key
	_stance_held = true


static func stance_height_factor(sole_height_m: float) -> float:
	return 1.0 - smoothstep(STANCE_HEIGHT_FULL_M, STANCE_HEIGHT_NONE_M, sole_height_m)


static func stance_motion_factor(backward_speed_mps: float) -> float:
	return smoothstep(
		STANCE_BACKWARD_SPEED_NONE_MPS, STANCE_BACKWARD_SPEED_FULL_MPS, backward_speed_mps
	)


## Signed displacement of the carried body along its up axis since the previous
## consecutive tick when it is a stair snap the visual pelvis should absorb;
## 0.0 for ordinary travel, teleports, frame changes or a broken tick chain.
## Measured in the owner's collision frame, so a moving ship adds nothing.
func take_body_step(presentation: Node3D, movement_up: Vector3, tick_key: int, absorb: bool) -> float:
	if tick_key == _body_height_tick:
		return 0.0
	var body := find_body(presentation)
	var height := NAN
	if (
		body != null and body.is_inside_tree()
		and movement_up.is_finite() and not movement_up.is_zero_approx()
	):
		var collision_transform := _collision_transform(body)
		var collision_up := (collision_transform.basis * movement_up).normalized()
		height = (collision_transform * body.global_position).dot(collision_up)
	var step := 0.0
	if (
		absorb and tick_key == _body_height_tick + 1
		and is_finite(height) and is_finite(_body_height)
	):
		# Travel the body's own velocity explains (a steep ramp at a sprint) is
		# not a snap; only the unexplained remainder is absorbed.
		var ticks := maxf(1.0, float(Engine.physics_ticks_per_second))
		var velocity_rise := 0.0
		if body.velocity.is_finite():
			velocity_rise = body.velocity.dot(movement_up.normalized()) / ticks
		var delta := height - _body_height
		var snap := delta - velocity_rise
		if absf(snap) >= BODY_STEP_ABSORB_MIN_M and absf(delta) <= BODY_STEP_ABSORB_MAX_M:
			step = snap
	_body_height = height
	_body_height_tick = tick_key
	return step


## Holds a boot's IK correction (metres along movement up, relative to its clip
## pose) from falling faster than `max_step` per consecutive tick. It only ever
## raises the requested correction, so it can never push a sole into support.
func limit_foot_descent(side: StringName, correction: float, tick_key: int, max_step: float) -> float:
	if int(_foot_correction_tick.get(side, -2)) == tick_key - 1 and _foot_correction.has(side):
		correction = maxf(correction, float(_foot_correction[side]) - maxf(0.0, max_step))
	return correction


func record_foot_correction(side: StringName, correction: float, tick_key: int) -> void:
	_foot_correction[side] = correction if is_finite(correction) else 0.0
	_foot_correction_tick[side] = tick_key


static func planar_speed(presentation: Node, movement_up: Vector3) -> float:
	var body := find_body(presentation)
	if body == null or not body.velocity.is_finite():
		return 0.0
	var up := Vector3.UP
	if movement_up.is_finite() and not movement_up.is_zero_approx():
		up = movement_up.normalized()
	return (body.velocity - up * body.velocity.dot(up)).length()


static func _collision_transform(body: Node) -> Transform3D:
	var frame_owner: Variant = _frame_owner(body)
	if frame_owner != null and frame_owner.has_method(&"get_occupant_collision_transform"):
		var published: Variant = frame_owner.call(&"get_occupant_collision_transform", body)
		if published is Transform3D and (published as Transform3D).is_finite():
			return published as Transform3D
	return Transform3D.IDENTITY


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
