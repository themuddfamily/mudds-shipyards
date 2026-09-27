extends SceneTree

## Locomotion foot IK for the skinned pilot on a real stair flight (the Aft
## Junction's authored 0.30 m riser / 0.70 m run): walking down and back up,
## and running down, each stance boot is planted on its own tread, the visual
## pelvis never jumps a riser in one tick when the capsule snaps a nosing, the
## ray budget stays at two queries per foot, the IK weight is zero while
## airborne, and gated (distant) pilots cast no support rays. Presentation only:
## the capsule and collision authority are unchanged.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const STAIR_STEPS := 8
const STAIR_WIDTH_M := 2.92
## A planted stance boot's lowest sole corner sits this close to its tread.
const MAX_STANCE_SOLE_ERROR_M := 0.03
## Share of stance samples that must meet the tolerance (heel strike on a lower
## tread may be reach-limited for a tick or two while the pelvis catches up).
const MIN_STANCE_WITHIN_TOLERANCE := 0.85
const MIN_BOOT_SOLE_GAP_M := -0.008
const MIN_STEPPED_STANCE_SAMPLES := 4
## One tick of pelvis travel. Walking a 30/70 flight descends ~0.04 m per tick
## on average and the clip bobs ~0.02 m; a raw capsule snap would be 0.30 m.
const MAX_PELVIS_VERTICAL_STEP_M := {&"walk": 0.12, &"run": 0.15}

var _failures := PackedStringArray()
var _assertions := 0
var _rise := 0.0
var _run := 0.0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_rise = AftJunctionStack.STAIR_RISE
	_run = AftJunctionStack.STAIR_RUN
	_check(
		is_equal_approx(snappedf(_rise, 0.001), 0.3) and _run > 0.6,
		"the flight uses the station's authored stair (riser %.3f m, run %.3f m)" % [_rise, _run]
	)
	var world := Node3D.new()
	world.name = "PilotLocomotionFootIKWorld"
	root.add_child(world)
	_build_flight(world)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	world.add_child(player)
	player.set_camera_active(false)
	player.set_control_enabled(false)
	var top := _rise * STAIR_STEPS
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, top + 0.2, 1.6)))
	await _settle(48)
	_check(player.is_on_floor(), "the pilot settles on the upper landing")

	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	var capsule_before := Vector2(capsule.radius, capsule.height)
	var shape_before := collision.transform
	var layer_before := player.collision_layer
	var mask_before := player.collision_mask

	player.set_control_enabled(true)
	await _traverse(player, &"move_forward", false, &"walk", "walking down", func(p: PlayerController) -> bool:
		return p.global_position.z < -_run * STAIR_STEPS - 1.2)
	await _settle(30)
	await _traverse(player, &"move_back", false, &"walk", "walking up", func(p: PlayerController) -> bool:
		return p.global_position.z > 1.2)
	await _settle(30)
	await _traverse(player, &"move_forward", true, &"run", "running down", func(p: PlayerController) -> bool:
		return p.global_position.z < -_run * STAIR_STEPS - 1.5)
	player.set_control_enabled(false)
	await _settle(40)

	_check(
		Vector2(capsule.radius, capsule.height).is_equal_approx(capsule_before)
		and collision.transform.is_equal_approx(shape_before)
		and player.collision_layer == layer_before and player.collision_mask == mask_before,
		"locomotion IK leaves the capsule shape, transform and collision layers unchanged"
	)
	await _check_airborne_weight(player)
	await _settle(40)
	await _check_distant_pilot_casts_no_rays(player, world)

	world.queue_free()
	await process_frame
	await process_frame
	_finish()


## Upper landing behind z = 0, then STAIR_STEPS solid treads descending toward
## -Z (the pilot's forward), then a lower landing at y = 0.
func _build_flight(world: Node3D) -> void:
	var top := _rise * STAIR_STEPS
	world.add_child(_make_box(
		&"UpperLanding", Vector3(0.0, (top - 0.2) * 0.5, 4.0), Vector3(STAIR_WIDTH_M, top + 0.2, 8.0)
	))
	for step in range(1, STAIR_STEPS):
		var tread_top := top - _rise * step
		world.add_child(_make_box(
			StringName("Tread%02d" % step),
			Vector3(0.0, (tread_top - 0.2) * 0.5, -_run * (step - 0.5)),
			Vector3(STAIR_WIDTH_M, tread_top + 0.2, _run)
		))
	var lower_start := -_run * (STAIR_STEPS - 1)
	world.add_child(_make_box(
		&"LowerLanding", Vector3(0.0, -0.1, lower_start - 5.0), Vector3(STAIR_WIDTH_M + 4.0, 0.2, 10.0)
	))


func _traverse(
		player: PlayerController, action: StringName, sprint: bool, expected_state: StringName,
		label: String, done: Callable
	) -> void:
	var presentation := _presentation(player)
	var skeleton := presentation.get_skeleton()
	var pelvis_index := skeleton.find_bone("pelvis")
	var previous_pelvis := Vector3.INF
	var previous_state := StringName()
	var state_frames := 0
	var stance_samples := 0
	var stance_within := 0
	var stepped_stance := 0
	var worst_stance_error := 0.0
	var lowest_gap := INF
	var largest_pelvis_step := 0.0
	var absorbed_snaps := 0
	var max_toe_probes := 0
	var reached := false
	Input.action_press(action)
	if sprint:
		Input.action_press(&"sprint_boost")
	for _frame in 260:
		await physics_frame
		if done.call(player):
			reached = true
			break
		var snapshot := presentation.get_foot_placement_snapshot()
		var state := StringName(snapshot.get("motion_state", &""))
		max_toe_probes = maxi(max_toe_probes, int(snapshot.get("toe_probe_count", 0)))
		if not is_zero_approx(float(snapshot.get("body_step_absorbed_m", 0.0))):
			absorbed_snaps += 1
		skeleton.force_update_all_bone_transforms()
		var pelvis := skeleton.global_transform * skeleton.get_bone_global_pose(pelvis_index).origin
		if state == expected_state and previous_state == expected_state and previous_pelvis.is_finite():
			largest_pelvis_step = maxf(largest_pelvis_step, absf(pelvis.y - previous_pelvis.y))
		previous_pelvis = pelvis
		previous_state = state
		if state != expected_state:
			continue
		state_frames += 1
		var feet: Dictionary = snapshot.get("feet", {})
		for side: StringName in [&"l", &"r"]:
			var record: Dictionary = feet.get(side, {})
			if not bool(record.get("active", false)):
				continue
			var gap := float(record.get("corrected_sole_min_gap_m", INF))
			lowest_gap = minf(lowest_gap, gap)
			if record.get("reason", &"") != &"stance_planted" or float(record.get("stance_weight", 0.0)) < 0.9:
				continue
			stance_samples += 1
			var error := absf(gap - 0.001)
			worst_stance_error = maxf(worst_stance_error, error)
			if error <= MAX_STANCE_SOLE_ERROR_M:
				stance_within += 1
			if bool(record.get("stepped_support", false)):
				stepped_stance += 1
	Input.action_release(action)
	if sprint:
		Input.action_release(&"sprint_boost")
	var within_share := float(stance_within) / maxf(1.0, float(stance_samples))
	print(
		"PILOT_LOCOMOTION_FOOT_IK_MEASURE: %s frames=%d stance=%d stepped=%d within=%.2f worst=%.4f m lowest_gap=%+.4f m pelvis_step=%.4f m snaps_absorbed=%d"
		% [label, state_frames, stance_samples, stepped_stance, within_share, worst_stance_error, lowest_gap, largest_pelvis_step, absorbed_snaps]
	)
	_check(reached, "%s reaches the far landing" % label)
	_check(state_frames >= 20, "%s runs the %s clip on the flight (%d ticks)" % [label, expected_state, state_frames])
	_check(
		stepped_stance >= MIN_STEPPED_STANCE_SAMPLES,
		"%s plants stance boots on treads above or below the capsule's deck (%d samples)" % [label, stepped_stance]
	)
	_check(
		within_share >= MIN_STANCE_WITHIN_TOLERANCE,
		"%s keeps %.0f%% of stance soles within %.0f mm of their tread (%.0f%%, worst %.4f m)" % [
			label, MIN_STANCE_WITHIN_TOLERANCE * 100.0, MAX_STANCE_SOLE_ERROR_M * 1000.0,
			within_share * 100.0, worst_stance_error
		]
	)
	_check(
		lowest_gap >= MIN_BOOT_SOLE_GAP_M,
		"%s never drives an IK boot corner through a tread (lowest %+.4f m)" % [label, lowest_gap]
	)
	var pelvis_bound: float = MAX_PELVIS_VERTICAL_STEP_M.get(expected_state, 0.12)
	_check(
		largest_pelvis_step <= pelvis_bound,
		"%s never moves the pelvis more than %.2f m in one tick (%.4f m)" % [label, pelvis_bound, largest_pelvis_step]
	)
	_check(max_toe_probes <= 2, "%s adds at most one toe ray per foot per tick" % label)


func _check_airborne_weight(player: PlayerController) -> void:
	player.velocity = Vector3.UP * 3.0
	await _settle(16)
	var snapshot := _presentation(player).get_foot_placement_snapshot()
	_check(not player.is_on_floor(), "the pilot is airborne for the weight check")
	_check(
		is_zero_approx(float(snapshot.get("ik_weight", -1.0))) and not bool(snapshot.get("active", true)),
		"locomotion IK weight is zero while airborne"
	)


func _check_distant_pilot_casts_no_rays(player: PlayerController, world: Node3D) -> void:
	var camera := Camera3D.new()
	camera.name = "DistantObserver"
	world.add_child(camera)
	camera.global_position = player.global_position + Vector3(0.0, 5.0, 120.0)
	camera.make_current()
	await _settle(4)
	var presentation := _presentation(player)
	var snapshot := presentation.get_foot_placement_snapshot()
	_check(presentation.is_foot_support_sampling_gated(), "a pilot 120 m from the camera is gated")
	_check(
		snapshot.get("reason", &"") == &"foot_ik_beyond_camera_distance"
		and int(snapshot.get("toe_probe_count", -1)) == 0,
		"a gated pilot casts no toe rays and only blends out (%s)" % str(snapshot.get("reason", &""))
	)
	camera.queue_free()
	await _settle(4)
	_check(not presentation.is_foot_support_sampling_gated(), "the gate lifts when the camera goes away")


func _presentation(player: PlayerController) -> PilotSkinnedPresentation:
	return player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation


func _make_box(node_name: StringName, origin: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = origin
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	return body


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PILOT_LOCOMOTION_FOOT_IK_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	push_error("PILOT_LOCOMOTION_FOOT_IK_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
