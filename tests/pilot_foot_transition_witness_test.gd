extends SceneTree

## Production PlayerController transition witness. The four bottom corners use
## the shipped BootSole bind coordinates and its uniform 62% foot/38% toe skin.
## A run-specific JSONL frame record is written to /tmp for exact contact review.
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FRAME_PATH_FORMAT := "/tmp/mudds-pilot-foot-transition-witness-%d.jsonl"
const MIN_SOLE_GAP_M := -0.005
const PHASE_FRAMES := 36
const BLEND_SECONDS := 0.12 # PlayerController.MOTION_BLEND_TIME
## World steps include legitimate traversal. These phase limits leave a small
## margin over the measured authored gait and reject a one-tick IK ankle pop.
const MAX_ANKLE_STEP_M := {
	"idle_to_walk": 0.17, "walk_to_run": 0.27, "run_to_walk": 0.18,
	"stopping_from_walk": 0.115, "idle_to_run": 0.27, "stopping_from_run": 0.15,
}
const MAX_ANKLE_VERTICAL_STEP_M := {
	"idle_to_walk": 0.045, "walk_to_run": 0.095, "run_to_walk": 0.095,
	"stopping_from_walk": 0.05, "idle_to_run": 0.095, "stopping_from_run": 0.07,
}
const MAX_SOLE_CORNER_STEP_M := {
	"idle_to_walk": 0.21, "walk_to_run": 0.36, "run_to_walk": 0.28,
	"stopping_from_walk": 0.14, "idle_to_run": 0.36, "stopping_from_run": 0.24,
}
const MAX_FOOT_ANGLE_STEP_DEG := 25.0

var _failures: Array[String] = []
var _first_penetration: Dictionary = {}
var _frames: FileAccess
var _frame_path := ""
var _previous_sample_frame := -1
var _previous_pose_row: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_frame_path = FRAME_PATH_FORMAT % OS.get_process_id()
	_frames = FileAccess.open(_frame_path, FileAccess.WRITE)
	if _frames == null:
		push_error("Cannot open transition frame record: %s" % error_string(FileAccess.get_open_error()))
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	world.add_child(player)
	player.set_camera_active(false)
	player.set_control_enabled(false)
	for slope in [0.0, 6.0, -6.0]:
		var deck := _make_deck(slope)
		world.add_child(deck)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.35 if slope == 0.0 else 0.55, 0.0)))
		await _settle(48)
		_require(player.is_on_floor(), "%.0f degree deck settles on the floor" % slope)
		_check_start(player, slope)
		player.set_control_enabled(true)
		await _phase(player, deck, slope, "idle_to_walk", false, true, &"walk")
		await _phase(player, deck, slope, "walk_to_run", true, true, &"run")
		await _phase(player, deck, slope, "run_to_walk", false, true, &"walk")
		await _phase(player, deck, slope, "stopping_from_walk", false, false, &"idle")
		player.set_control_enabled(false)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.35 if slope == 0.0 else 0.55, 0.0)))
		await _settle(48)
		_check_start(player, slope)
		player.set_control_enabled(true)
		await _phase(player, deck, slope, "idle_to_run", true, true, &"run")
		await _phase(player, deck, slope, "stopping_from_run", false, false, &"idle")
		player.set_control_enabled(false)
		deck.queue_free()
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint_boost")
	_frames.close()
	world.queue_free()
	await process_frame
	if _first_penetration.is_empty() and _failures.is_empty():
		print("PILOT_FOOT_TRANSITION_WITNESS_OK: all grounded soles clear; frames=", _frame_path)
		quit(0)
		return
	print("TRANSITION_FRAME_LOG: ", _frame_path)
	if not _first_penetration.is_empty():
		push_error("FIRST_PRODUCTION_SOLE_PENETRATION: " + JSON.stringify(_first_penetration))
	if not _failures.is_empty():
		push_error("WITNESS_PRECONDITION_FAILED: " + "; ".join(_failures))
	quit(1)


func _check_start(player: PlayerController, slope: float) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var snapshot := player.get_grounded_foot_placement_snapshot()
	var feet: Dictionary = snapshot.get("feet", {})
	_require(
		player.is_on_floor() and presentation != null
		and player.get_motion_animation_player() == presentation.get_animation_player()
		and bool(snapshot.get("attached", false)) and bool(snapshot.get("active", false))
		and snapshot.get("motion_state", &"") == &"idle"
		and bool((feet.get(&"l", {}) as Dictionary).get("active", false))
		and bool((feet.get(&"r", {}) as Dictionary).get("active", false)),
		"%.0f degree deck: idle, grounded, imported animation authority, both supported feet (snapshot=%s)" % [slope, snapshot]
	)
	# The teleport/settle intentionally leaves a gap; every subsequent measured
	# transition tick until the next reset must advance the producer stamp once.
	_previous_sample_frame = -1
	_previous_pose_row = {}


func _phase(player: PlayerController, deck: StaticBody3D, slope: float, phase: String, sprint: bool, move: bool, expected: StringName) -> void:
	if move:
		Input.action_press("move_forward")
	else:
		Input.action_release("move_forward")
	if sprint:
		Input.action_press("sprint_boost")
	else:
		Input.action_release("sprint_boost")
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	_require(presentation != null, "%s %.0f: production skinned presentation exists" % [phase, slope])
	if presentation == null:
		return
	var animation := player.get_motion_animation_player()
	var active := {&"l": 0, &"r": 0}
	var inactive := {&"l": 0, &"r": 0}
	var expected_frames := 0
	var previous_state := player.get_authored_motion_state()
	var state_start_frame := Engine.get_physics_frames()
	var blend_from := previous_state
	var deck_top := deck.global_transform * Vector3(0.0, 0.1, 0.0)
	var deck_normal := deck.global_basis.y.normalized()
	for index in PHASE_FRAMES:
		await physics_frame
		var state := player.get_authored_motion_state()
		if state != previous_state:
			blend_from = previous_state
			state_start_frame = Engine.get_physics_frames()
			previous_state = state
		if state == expected:
			expected_frames += 1
		var snapshot := player.get_grounded_foot_placement_snapshot()
		var frame := Engine.get_physics_frames()
		var sample_frame := int(snapshot.get("physics_frame", -1))
		var feet: Dictionary = snapshot.get("feet", {})
		var left: Dictionary = feet.get(&"l", {})
		var right: Dictionary = feet.get(&"r", {})
		var precondition: bool = (
			player.is_on_floor()
			and bool(snapshot.get("attached", false))
			and sample_frame >= frame - 1 and sample_frame <= frame
			and (_previous_sample_frame < 0 or sample_frame == _previous_sample_frame + 1)
			and snapshot.get("motion_state", &"") == state
			and feet.has(&"l") and feet.has(&"r")
			and bool(snapshot.get("active", false)) == (
				bool(left.get("active", false)) or bool(right.get("active", false))
			)
			and absf(player.global_position.x) < 14.5
			and absf(player.global_position.z) < 14.5
		)
		_require(precondition, "%s %.0f frame %d: grounded, attached, advancing accepted support sample (prior=%d sample=%d root=%s snapshot=%s)" % [phase, slope, frame, _previous_sample_frame, sample_frame, player.global_position, snapshot])
		_previous_sample_frame = sample_frame
		var row := {
			"deck_degrees": slope, "phase": phase, "phase_frame": index,
			"caller_physics_frame": frame, "physics_frame": sample_frame,
			"grounded": player.is_on_floor(),
			"sample_offset": frame - sample_frame,
			"sample_active": bool(snapshot.get("active", false)),
			"state": String(state), "animation": String(animation.assigned_animation),
			"animation_time_s": animation.current_animation_position,
			"animation_speed": animation.speed_scale,
			"blend_from": String(blend_from),
			"blend_elapsed_s": float(frame - state_start_frame) / Engine.physics_ticks_per_second,
			"blend_fraction_inferred": clampf(float(frame - state_start_frame) / (BLEND_SECONDS * Engine.physics_ticks_per_second), 0.0, 1.0),
			"pelvis_m": _v(_bone_world(presentation, &"pelvis")),
			"head_m": _v(_bone_world(presentation, &"head")),
			"visual_pelvis_drop_m": snapshot.get("visual_pelvis_drop_m", 0.0),
			"feet": {},
		}
		for side: StringName in [&"l", &"r"]:
			var foot: Dictionary = feet.get(side, {})
			var is_active := bool(foot.get("active", false))
			if not is_active:
				inactive[side] += 1
			else:
				active[side] += 1
			var support_position: Vector3 = foot.get("support_position", deck_top) if is_active else deck_top
			var support_normal: Vector3 = foot.get("support_normal", deck_normal) if is_active else deck_normal
			var contact := _sole_contact(presentation, side, foot, support_position, support_normal)
			row.feet[String(side)] = contact
			if precondition and float(contact["min_gap_m"]) < MIN_SOLE_GAP_M and _first_penetration.is_empty():
				_first_penetration = row.duplicate(true)
			if not _previous_pose_row.is_empty() and sample_frame == int(_previous_pose_row.physics_frame) + 1:
				var prior: Dictionary = _previous_pose_row.feet[String(side)]
				var ankle_step := _array_distance(prior.ankle_m, contact.ankle_m)
				var vertical_step := absf(float(prior.ankle_m[1]) - float(contact.ankle_m[1]))
				var sole_step := 0.0
				for corner in 4:
					sole_step = maxf(sole_step, _array_distance(prior.sole_corners_m[corner], contact.sole_corners_m[corner]))
				var angle_step := absf(float(prior.foot_angle_deg) - float(contact.foot_angle_deg))
				_require(
					ankle_step <= float(MAX_ANKLE_STEP_M[phase])
					and vertical_step <= float(MAX_ANKLE_VERTICAL_STEP_M[phase])
					and sole_step <= float(MAX_SOLE_CORNER_STEP_M[phase])
					and angle_step <= MAX_FOOT_ANGLE_STEP_DEG,
					"%s %.0f frame %d %s: world ankle/sole step stays continuous (ankle %.1f, vertical %.1f, sole %.1f mm; angle %.1f deg)" % [
						phase, slope, index, side, ankle_step * 1000.0, vertical_step * 1000.0,
						sole_step * 1000.0, angle_step,
					]
				)
		_frames.store_line(JSON.stringify(row))
		_previous_pose_row = row.duplicate(true)
	_require(expected_frames >= 20, "%s %.0f: %d frames in expected %s state" % [phase, slope, expected_frames, expected])
	_require(active[&"l"] + active[&"r"] >= 10, "%s %.0f: %d active foot samples" % [phase, slope, active[&"l"] + active[&"r"]])
	for side: StringName in [&"l", &"r"]:
		_require(active[side] >= 1, "%s %.0f %s: at least one active support sample" % [phase, slope, side])
	print("TRANSITION_PRECONDITION: deck=%+.0f phase=%s expected=%d active_l=%d active_r=%d inactive_l=%d inactive_r=%d" % [slope, phase, expected_frames, active[&"l"], active[&"r"], inactive[&"l"], inactive[&"r"]])


func _sole_contact(presentation: PilotSkinnedPresentation, side: StringName, record: Dictionary, support_position: Vector3, support_normal: Vector3) -> Dictionary:
	var skeleton := presentation.get_skeleton()
	skeleton.force_update_all_bone_transforms()
	var foot_index := skeleton.find_bone("foot_" + String(side))
	var toe_index := skeleton.find_bone("toe_" + String(side))
	var foot_deform := skeleton.get_bone_global_pose(foot_index) * skeleton.get_bone_global_rest(foot_index).affine_inverse()
	var toe_deform := skeleton.get_bone_global_pose(toe_index) * skeleton.get_bone_global_rest(toe_index).affine_inverse()
	var center_x := -0.14 if side == &"l" else 0.14
	var points: Array[Vector3] = []
	var gaps: Array[float] = []
	for z in [-0.085, 0.295]:
		for x in [-0.095, 0.095]:
			var bind := Vector3(center_x + x, 0.0, z)
			var point := skeleton.global_transform * (foot_deform * bind * 0.62 + toe_deform * bind * 0.38)
			points.append(point)
			gaps.append((point - support_position).dot(support_normal))
	var sole_up := (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	return {
		"active": bool(record.get("active", false)), "reason": String(record.get("reason", &"missing")),
		"support_kind": "ray" if bool(record.get("active", false)) else "known_deck_plane",
		"support_m": _v(support_position), "support_normal": _v(support_normal),
		"sole_corners_m": [_v(points[0]), _v(points[1]), _v(points[2]), _v(points[3])],
		"corner_gaps_m": gaps, "min_gap_m": gaps.min(), "max_gap_m": gaps.max(),
		"foot_angle_deg": rad_to_deg(sole_up.angle_to(support_normal)),
		"ankle_m": _v(skeleton.global_transform * skeleton.get_bone_global_pose(foot_index).origin),
		"ankle_chain_error_m": record.get("ankle_chain_error_m", INF),
	}


func _bone_world(presentation: PilotSkinnedPresentation, bone: StringName) -> Vector3:
	var skeleton := presentation.get_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_distance(a: Array, b: Array) -> float:
	return Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(
		Vector3(float(b[0]), float(b[1]), float(b[2]))
	)


func _make_deck(slope: float) -> StaticBody3D:
	var deck := StaticBody3D.new()
	deck.rotation.z = deg_to_rad(slope)
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	deck.add_child(collision)
	return deck


func _settle(count: int) -> void:
	for index in count:
		await physics_frame


func _require(ok: bool, description: String) -> void:
	if not ok:
		if _failures.size() < 8:
			_failures.append(description)
			push_error("PRECONDITION: " + description)
