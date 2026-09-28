extends SceneTree

## Locomotion foot IK for the skinned pilot on the production Aft Junction stair
## (the real module scene: a continuous collision ramp under fifteen drawn
## 0.30 m riser / 0.70 m run treads, each carrying a FootSupport shape that only
## the pilot's foot rays cast). Walking down and back up, and running down, each
## stance boot is planted on the drawn tread under it, no IK boot corner is
## driven into a tread, the visual pelvis never jumps a riser in one tick, the
## ray budget stays at two queries per foot, the IK weight is zero while
## airborne, and gated (distant) pilots cast no support rays. Presentation only:
## the capsule rides the ramp and collision authority is unchanged.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const AFT_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
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
var _stair_x := 0.0
var _bottom_z := 0.0
var _top_z := 0.0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var world := Node3D.new()
	world.name = "PilotLocomotionFootIKWorld"
	root.add_child(world)
	var module := AFT_SCENE.instantiate() as AftJunctionStack
	world.add_child(module)
	await physics_frame
	var profile := module.get_stair_profile()
	var samples := module.get_stair_surface_samples()
	_stair_x = samples[0].x
	_bottom_z = samples[0].z
	_top_z = samples[samples.size() - 1].z
	_check(
		is_equal_approx(snappedf(float(profile.riser_height), 0.001), 0.3)
		and float(profile.tread_run) > 0.6
		and profile.collision_solution == &"continuous_ramp_beneath_visible_treads",
		"the flight is the station's authored stair (riser %.3f m, run %.3f m, %s)" % [
			float(profile.riser_height), float(profile.tread_run), profile.collision_solution
		]
	)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	world.add_child(player)
	player.set_camera_active(false)
	player.set_control_enabled(false)
	_check_tread_foot_support(module, player)
	player.teleport_to(Transform3D(
		Basis.IDENTITY,
		Vector3(_stair_x, AftJunctionStack.UPPER_FLOOR_ELEVATION + 0.4, _top_z + 1.6)
	))
	await _settle(48)
	_check(player.is_on_floor(), "the pilot settles on the upper landing")

	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	var capsule_before := Vector2(capsule.radius, capsule.height)
	var shape_before := collision.transform
	var layer_before := player.collision_layer
	var mask_before := player.collision_mask

	# Down the flight is -Z. The stair-base landing's south rail stands 1.44 m
	# short of the ramp foot, so a descent is done 0.6 m clear of the foot.
	player.set_control_enabled(true)
	await _traverse(player, &"move_forward", false, &"walk", "walking down", func(p: PlayerController) -> bool:
		return p.global_position.z < _bottom_z - 0.6)
	await _settle(30)
	await _traverse(player, &"move_back", false, &"walk", "walking up", func(p: PlayerController) -> bool:
		return p.global_position.z > _top_z + 1.2)
	await _settle(30)
	await _traverse(player, &"move_forward", true, &"run", "running down", func(p: PlayerController) -> bool:
		return p.global_position.z < _bottom_z - 0.6)
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


## Every drawn tread carries a FootSupport shape at its exact pose and size,
## which the capsule's mask excludes: the ramp stays the only body it rides.
func _check_tread_foot_support(module: AftJunctionStack, player: PlayerController) -> void:
	var circulation := module.find_child("Circulation", true, false) as Node3D
	var support: StaticBody3D = null
	var ramp: StaticBody3D = null
	if circulation != null:
		support = circulation.get_node_or_null(^"VisibleTreadFootSupport") as StaticBody3D
		ramp = circulation.get_node_or_null(^"ContinuousStairRamp") as StaticBody3D
	var matched := 0
	for index in AftJunctionStack.STAIR_STEP_COUNT:
		if circulation == null or support == null:
			break
		var anchor := circulation.get_node_or_null(NodePath("VisibleTread%02d" % index)) as Node3D
		var shape := support.get_node_or_null(NodePath("TreadFootSupport%02d" % index)) as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		if (
			anchor != null and box != null
			and shape.global_transform.is_equal_approx(anchor.global_transform)
			and box.size.is_equal_approx(AftJunctionStack.STAIR_TREAD_SIZE)
		):
			matched += 1
	_check(
		matched == AftJunctionStack.STAIR_STEP_COUNT
		and support.collision_layer == PhysicsLayers.FOOT_SUPPORT
		and (player.collision_mask & PhysicsLayers.FOOT_SUPPORT) == 0
		and ramp != null and ramp.collision_layer == PhysicsLayers.WORLD
		and (player.collision_mask & PhysicsLayers.WORLD) != 0,
		"every drawn tread carries a FootSupport shape the capsule ignores; the ramp carries the capsule (%d/%d)" % [
			matched, AftJunctionStack.STAIR_STEP_COUNT
		]
	)


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
	var reach_limited_lifts := 0
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
			# A swing boot lifted by the full step reach toward a tread its toe
			# probe found ahead can still sit below that tread's plane: the IK
			# raised it as far as it may and drove nothing down. On this stair the
			# capsule rides the ramp up to 0.15 m below a nosing, so the next
			# tread can be more than one reach above the deck.
			var reach_up := PilotSkinnedPresentation.FOOT_IK_MAX_STEP_RISE_M \
				+ maxf(0.0, float(snapshot.get("visual_pelvis_drop_m", 0.0)))
			if float(record.get("applied_correction_m", 0.0)) >= reach_up - 0.001:
				reach_limited_lifts += 1
			else:
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
		"PILOT_LOCOMOTION_FOOT_IK_MEASURE: %s frames=%d stance=%d stepped=%d within=%.2f worst=%.4f m lowest_gap=%+.4f m reach_limited_lifts=%d pelvis_step=%.4f m snaps_absorbed=%d"
		% [
			label, state_frames, stance_samples, stepped_stance, within_share, worst_stance_error,
			lowest_gap, reach_limited_lifts, largest_pelvis_step, absorbed_snaps
		]
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
