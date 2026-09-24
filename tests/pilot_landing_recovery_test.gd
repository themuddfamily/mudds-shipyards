extends SceneTree

## Production Player contact witness: sampled skinned boot corners on a flat and
## shallow deck, with the real jump, grounded recovery and locomotion handoff.
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MIN_SOLE_GAP_M := -0.005
const MAX_FOOT_ANGLE_STEP_DEG := 27.0
const MAX_ANKLE_STEP_M := 0.20
const MAX_CORNER_STEP_M := 0.25

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	stage.add_child(player)
	player.set_camera_active(false)
	player.set_control_enabled(false)
	for slope in [0.0, 6.0]:
		var deck := StaticBody3D.new()
		deck.rotation.z = deg_to_rad(slope)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(20.0, 0.2, 20.0)
		shape.shape = box
		deck.add_child(shape)
		stage.add_child(deck)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
		await _physics_frames(45)
		_check(player.is_on_floor(), "%.0f degree deck has a grounded starting pose" % slope)
		if slope == 0.0:
			await _brief_support_loss(player, deck)
		await _jump_and_measure(player, deck, slope, false)
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
		await _physics_frames(40)
		await _jump_and_measure(player, deck, slope, true)
		if slope == 0.0:
			await _boarding_interrupts_landing(player, stage)
		deck.queue_free()
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("jump")
	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PILOT_LANDING_RECOVERY_TEST_OK")
		quit(0)
	else:
		for failure in _failures:
			print("PILOT_LANDING_RECOVERY_TEST_FAIL: ", failure)
		quit(1)

func _brief_support_loss(player: PlayerController, deck: StaticBody3D) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var previous := _sample_soles(presentation, deck)
	var max_angle_step := 0.0
	var max_ankle_step := 0.0
	var max_corner_step := 0.0
	deck.collision_layer = 0
	await physics_frame
	var now := _sample_soles(presentation, deck)
	for side in ["l", "r"]:
		var current: Dictionary = now[side]
		var prior: Dictionary = previous[side]
		max_angle_step = maxf(max_angle_step, rad_to_deg((current.basis as Quaternion).angle_to(prior.basis as Quaternion)))
		max_ankle_step = maxf(max_ankle_step, (current.ankle as Vector3).distance_to(prior.ankle as Vector3))
		for corner in 4:
			max_corner_step = maxf(max_corner_step, (current.corners[corner] as Vector3).distance_to(prior.corners[corner] as Vector3))
	previous = now
	deck.collision_layer = 1
	var landing_seen := false
	for index in 8:
		await physics_frame
		landing_seen = landing_seen or player.get_authored_motion_state() == &"landing_recovery"
		now = _sample_soles(presentation, deck)
		for side in ["l", "r"]:
			var current: Dictionary = now[side]
			var prior: Dictionary = previous[side]
			max_angle_step = maxf(max_angle_step, rad_to_deg((current.basis as Quaternion).angle_to(prior.basis as Quaternion)))
			max_ankle_step = maxf(max_ankle_step, (current.ankle as Vector3).distance_to(prior.ankle as Vector3))
			for corner in 4:
				max_corner_step = maxf(max_corner_step, (current.corners[corner] as Vector3).distance_to(prior.corners[corner] as Vector3))
		previous = now
	_check(not landing_seen and player.is_on_floor(), "one lost support tick does not trigger impact recovery")
	_check(max_angle_step <= MAX_FOOT_ANGLE_STEP_DEG and max_ankle_step <= MAX_ANKLE_STEP_M and max_corner_step <= MAX_CORNER_STEP_M,
		"one lost support tick keeps pose continuous (angle %.1f deg, ankle %.1f mm, sole %.1f mm)" % [max_angle_step, max_ankle_step * 1000.0, max_corner_step * 1000.0])
	print("SUPPORT_SEAM: max_angle_step_deg=%.1f max_ankle_step_mm=%.1f max_corner_step_mm=%.1f" % [max_angle_step, max_ankle_step * 1000.0, max_corner_step * 1000.0])

func _jump_and_measure(player: PlayerController, deck: StaticBody3D, slope: float, moving: bool) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	_check(presentation != null and bool(player.get_pilot_presentation_audit().get("valid", false)), "imported pilot accepted")
	if presentation == null:
		return
	player.set_control_enabled(true)
	if moving:
		Input.action_press("move_forward")
		await _physics_frames(8)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var airborne_seen := false
	var landing_seen := false
	var landing_frames := 0
	var previous: Dictionary = {}
	var min_gap := INF
	var max_angle_step := 0.0
	var max_ankle_step := 0.0
	var max_corner_step := 0.0
	var first_grounded := false
	var moved_during_recovery := false
	for index in 100:
		await physics_frame
		var state := player.get_authored_motion_state()
		if not player.is_on_floor():
			airborne_seen = true
		if state == &"landing_recovery":
			landing_seen = true
			landing_frames += 1
			if moving:
				moved_during_recovery = moved_during_recovery or Vector2(player.velocity.x, player.velocity.z).length() > 1.0
		if airborne_seen and player.is_on_floor():
			first_grounded = true
			var sample := _sample_soles(presentation, deck)
			min_gap = minf(min_gap, float(sample.min_gap))
			if not previous.is_empty():
				for side in ["l", "r"]:
					var now: Dictionary = sample[side]
					var prior: Dictionary = previous[side]
					max_angle_step = maxf(max_angle_step, rad_to_deg((now.basis as Quaternion).angle_to(prior.basis as Quaternion)))
					max_ankle_step = maxf(max_ankle_step, (now.ankle as Vector3).distance_to(prior.ankle as Vector3))
					for corner in 4:
						max_corner_step = maxf(max_corner_step, (now.corners[corner] as Vector3).distance_to(prior.corners[corner] as Vector3))
			previous = sample
		if landing_seen and state in [&"idle", &"walk", &"run"] and landing_frames >= 1:
			break
	_check(airborne_seen and first_grounded and landing_seen, "%.0f degree %s jump has actual airborne flight, contact and landing state" % [slope, "moving" if moving else "idle"])
	_check(landing_frames >= 8, "%.0f degree %s landing has visible duration (%d frames)" % [slope, "moving" if moving else "idle", landing_frames])
	_check(min_gap >= MIN_SOLE_GAP_M, "%.0f degree %s soles clear deck (minimum %.1f mm)" % [slope, "moving" if moving else "idle", min_gap * 1000.0])
	_check(max_angle_step <= MAX_FOOT_ANGLE_STEP_DEG and max_ankle_step <= MAX_ANKLE_STEP_M and max_corner_step <= MAX_CORNER_STEP_M,
		"%.0f degree %s contact/handoff continuity (angle %.1f deg, ankle %.1f mm, sole %.1f mm)" % [slope, "moving" if moving else "idle", max_angle_step, max_ankle_step * 1000.0, max_corner_step * 1000.0])
	if moving:
		_check(moved_during_recovery, "%.0f degree held movement continues through landing" % slope)
	print("LANDING_CONTACT: slope=%+.0f moving=%s frames=%d min_gap_mm=%.1f max_angle_step_deg=%.1f max_ankle_step_mm=%.1f max_corner_step_mm=%.1f" % [slope, moving, landing_frames, min_gap * 1000.0, max_angle_step, max_ankle_step * 1000.0, max_corner_step * 1000.0])
	Input.action_release("move_forward")
	player.set_control_enabled(false)

func _boarding_interrupts_landing(player: PlayerController, stage: Node3D) -> void:
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
	await _physics_frames(25)
	player.set_control_enabled(true)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var landing_seen := false
	for index in 75:
		await physics_frame
		if player.is_on_floor() and player.get_authored_motion_state() == &"landing_recovery":
			landing_seen = true
			break
	_check(landing_seen, "boarding probe begins during a real landing recovery")
	if not landing_seen:
		return
	var seat := Node3D.new()
	stage.add_child(seat)
	var boarded := player.begin_boarding(Transform3D.IDENTITY, seat, 0.0)
	var disembarked := player.begin_disembark(Transform3D.IDENTITY, 0.0)
	await _physics_frames(10)
	_check(boarded and disembarked and player.get_authored_motion_state() != &"landing_recovery", "seat lifecycle clears interrupted landing recovery")
	player.set_control_enabled(false)
	seat.queue_free()

func _sample_soles(presentation: PilotSkinnedPresentation, deck: StaticBody3D) -> Dictionary:
	var skeleton := presentation.get_skeleton()
	skeleton.force_update_all_bone_transforms()
	var normal := deck.global_basis.y.normalized()
	var top := deck.global_transform * Vector3(0.0, 0.1, 0.0)
	var result := {"min_gap": INF}
	for side in ["l", "r"]:
		var foot := skeleton.find_bone("foot_" + side)
		var toe := skeleton.find_bone("toe_" + side)
		var foot_pose := skeleton.get_bone_global_pose(foot)
		var foot_deform := foot_pose * skeleton.get_bone_global_rest(foot).affine_inverse()
		var toe_deform := skeleton.get_bone_global_pose(toe) * skeleton.get_bone_global_rest(toe).affine_inverse()
		var center_x := -0.14 if side == "l" else 0.14
		var corners: Array[Vector3] = []
		for z in [-0.085, 0.295]:
			for x in [-0.095, 0.095]:
				var bind := Vector3(center_x + x, 0.0, z)
				var point := skeleton.global_transform * (foot_deform * bind * 0.62 + toe_deform * bind * 0.38)
				corners.append(point)
				result.min_gap = minf(float(result.min_gap), (point - top).dot(normal))
		result[side] = {"corners": corners, "ankle": skeleton.global_transform * foot_pose.origin, "basis": (skeleton.global_basis * foot_pose.basis).get_rotation_quaternion()}
	return result

func _physics_frames(count: int) -> void:
	for index in count:
		await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
		push_error(message)
