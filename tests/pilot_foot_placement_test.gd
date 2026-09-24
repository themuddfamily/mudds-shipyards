extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PRESENTATION_SCENE := preload("res://scenes/player/pilot_skinned_presentation.tscn")
const SHALLOW_RAMP_DEGREES := 6.0
const MAX_SOLE_ERROR_M := 0.025
const MAX_ANKLE_CHAIN_ERROR_M := 0.001
const MAX_BOOT_SOLE_PLANE_SPREAD_M := 0.010
const MAX_BOOT_SOLE_GAP_M := 0.010
const MIN_BOOT_SOLE_GAP_M := -0.005

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "PilotFootPlacementWorld"
	root.add_child(world)
	var flat := _make_support(&"FlatDeck", Vector3.ZERO, 0.0)
	world.add_child(flat)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	world.add_child(player)
	player.set_control_enabled(false)
	player.set_camera_active(false)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.35, 0.0)))
	await _settle(36)
	_check_grounded_snapshot(player, "flat deck")
	_check_ramp_boot_sole_contact(player, "flat deck")

	flat.queue_free()
	await physics_frame
	var ramp := _make_support(&"ShallowRamp", Vector3.ZERO, SHALLOW_RAMP_DEGREES)
	world.add_child(ramp)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
	await _settle(48)
	_check_grounded_snapshot(player, "six-degree ramp")
	_check_ramp_boot_sole_contact(player, "positive six-degree ramp")
	await _sweep_idle_ramp(player, "positive six-degree ramp")
	player.set_control_enabled(true)
	await _exercise_sloped_locomotion(player, &"walk", false)
	await _exercise_sloped_locomotion(player, &"run", true)
	player.set_control_enabled(false)
	await _settle(30)

	ramp.queue_free()
	await physics_frame
	var opposite_ramp := _make_support(&"OppositeRamp", Vector3.ZERO, -SHALLOW_RAMP_DEGREES)
	world.add_child(opposite_ramp)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
	await _settle(48)
	_check_grounded_snapshot(player, "negative six-degree ramp")
	_check_ramp_boot_sole_contact(player, "negative six-degree ramp")
	await _sweep_idle_ramp(player, "negative six-degree ramp")
	var ramp_presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var pelvis_before_clear := _bone_world_position(ramp_presentation, &"pelvis")
	var head_before_clear := _bone_world_position(ramp_presentation, &"head")
	var ramp_drop := float(ramp_presentation.get_foot_placement_snapshot().get("visual_pelvis_drop_m", 0.0))
	var ramp_animation_time := ramp_presentation.get_animation_player().current_animation_position
	var generation := ramp_presentation.get_foot_placement_attachment_generation()
	var stale_clear := ramp_presentation.clear_foot_placement(generation - 1, &"test_stale_generation")
	_check(
		not bool(stale_clear.get("accepted", true))
		and _bone_world_position(ramp_presentation, &"pelvis").is_equal_approx(pelvis_before_clear),
		"stale attachment generation cannot release the pelvis offset"
	)
	ramp_presentation.clear_foot_placement(
		generation, &"test_no_animation_advance"
	)
	var pelvis_after_clear := _bone_world_position(ramp_presentation, &"pelvis")
	var head_after_clear := _bone_world_position(ramp_presentation, &"head")
	var first_release := float(ramp_presentation.get_foot_placement_snapshot().get("visual_pelvis_drop_m", INF))
	_check(
		ramp_drop > 0.01
		and first_release > 0.0
		and ramp_drop - first_release <= 0.0061
		and pelvis_after_clear.distance_to(pelvis_before_clear) <= 0.0061
		and head_after_clear.distance_to(head_before_clear) <= 0.0061
		and ramp_presentation.get_animation_player().current_animation_position == ramp_animation_time,
		"clearing without animation advance releases at most 6 mm of pelvis/head offset"
	)
	ramp_presentation.clear_foot_placement(generation, &"test_duplicate_same_frame")
	_check(
		_bone_world_position(ramp_presentation, &"pelvis").is_equal_approx(pelvis_after_clear)
		and _bone_world_position(ramp_presentation, &"head").is_equal_approx(head_after_clear),
		"duplicate same-frame clear cannot release another pelvis step"
	)
	await _test_clip_release(player, world, &"jump")
	await _test_clip_release(player, world, &"boarding")

	opposite_ramp.queue_free()
	await physics_frame
	var repeated_flat := _make_support(&"RepeatedFlatDeck", Vector3.ZERO, 0.0)
	world.add_child(repeated_flat)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.35, 0.0)))
	await _settle(36)
	_check_grounded_snapshot(player, "repeated flat deck")
	_check_ramp_boot_sole_contact(player, "repeated flat deck")
	_check(
		float(player.get_grounded_foot_placement_snapshot().get("visual_pelvis_drop_m", INF)) <= 0.0001,
		"returning to flat ground releases the visual pelvis drop"
	)

	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	var body_before := player.global_transform
	var velocity_before := player.velocity
	var layer_before := player.collision_layer
	var mask_before := player.collision_mask
	var capsule_radius_before := capsule.radius
	var capsule_height_before := capsule.height
	var motion_player := player.get_motion_animation_player()
	var animation_before := motion_player.current_animation_position
	player.set_physics_process(false)
	await physics_frame
	player.call("_update_grounded_foot_placement")
	_check(player.global_transform.is_equal_approx(body_before), "visual correction cannot move the Player root")
	_check(player.velocity.is_equal_approx(velocity_before), "visual correction cannot change Player velocity")
	_check(
		player.collision_layer == layer_before and player.collision_mask == mask_before,
		"visual correction cannot change Player collision authority"
	)
	_check(
		is_equal_approx(capsule.radius, capsule_radius_before)
		and is_equal_approx(capsule.height, capsule_height_before),
		"visual correction cannot resize the production capsule"
	)
	_check(
		is_equal_approx(motion_player.current_animation_position, animation_before),
		"visual correction cannot advance imported animation timing"
	)

	_test_repeated_foot_placement(player)
	await _test_rotated_presentation_and_seat_clips(world)

	player.set_physics_process(true)
	player.velocity = Vector3.UP * 2.0
	await _settle(2)
	var airborne := player.get_grounded_foot_placement_snapshot()
	_check(
		not bool(airborne.get("active", true))
		and is_zero_approx(float(airborne.get("visual_pelvis_drop_m", INF))),
		"foot placement and visual pelvis drop are disabled while airborne"
	)

	world.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_repeated_foot_placement(player: PlayerController) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var skeleton := presentation.get_skeleton()
	var animation := presentation.get_animation_player()
	var feet := {}
	var snapshot := presentation.get_foot_placement_snapshot()
	var chain_indices: Array[int] = []
	for side: StringName in [&"l", &"r"]:
		var foot: Dictionary = snapshot.feet[side]
		feet[side] = {"position": foot.support_position, "normal": foot.support_normal}
		for bone_name: StringName in PilotSkinnedPresentation.FOOT_CHAIN_BONES[side]:
			chain_indices.append(skeleton.find_bone(bone_name))
	var frame := int(snapshot.physics_frame) + 1
	var body_before := player.global_transform
	var velocity_before := player.velocity
	var layer_before := player.collision_layer
	var mask_before := player.collision_mask
	var capsule := (player.get_node("PlayerCollision") as CollisionShape3D).shape as CapsuleShape3D
	var capsule_size := Vector2(capsule.radius, capsule.height)
	var stable_pose := true
	var stable_contact := true
	var stable_orientation := true
	var stable_animation_time := true
	var iterations := 0
	# Run more than ten minutes of actual imported idle sampling without waiting
	# for wall time. The global-pose IK setters used to accumulate scale drift.
	for iteration in 40000:
		animation.advance(1.0 / 60.0)
		skeleton.force_update_all_bone_transforms()
		var animated_poses: Array[Transform3D] = []
		for bone in chain_indices:
			animated_poses.append(skeleton.get_bone_pose(bone))
		var foot_rotations: Array[Basis] = []
		for index in [2, 5]:
			foot_rotations.append(skeleton.get_bone_global_pose(chain_indices[index]).basis.orthonormalized())
		var animation_time := animation.current_animation_position
		presentation.apply_foot_placement({
			"physics_frame": frame + iteration, "motion_state": &"idle",
			"movement_up": Vector3.UP, "feet": feet,
		}, presentation.get_foot_placement_attachment_generation())
		stable_animation_time = stable_animation_time and animation.current_animation_position == animation_time
		for index in chain_indices.size():
			var bone := chain_indices[index]
			var pose := skeleton.get_bone_pose(bone)
			stable_pose = stable_pose and pose.is_finite() \
				and skeleton.get_bone_global_pose(bone).is_finite() \
				and not is_zero_approx(skeleton.get_bone_global_pose(bone).basis.determinant()) \
				and pose.origin.is_equal_approx(animated_poses[index].origin) \
				and pose.basis.get_scale().is_equal_approx(animated_poses[index].basis.get_scale()) \
				and skeleton.get_bone_pose_rotation(bone).is_normalized()
		var corrected_feet: Dictionary = presentation.get_foot_placement_snapshot().feet
		for side: StringName in [&"l", &"r"]:
			var foot: Dictionary = corrected_feet[side]
			stable_contact = stable_contact and bool(foot.get("active", false)) \
				and float(foot.get("sole_error_m", INF)) <= MAX_SOLE_ERROR_M \
				and float(foot.get("ankle_chain_error_m", INF)) <= MAX_ANKLE_CHAIN_ERROR_M
		for index in 2:
			var rotation := skeleton.get_bone_global_pose(chain_indices[2 + index * 3]).basis.orthonormalized()
			stable_orientation = stable_orientation and rotation.is_equal_approx(foot_rotations[index])
		iterations = iteration + 1
		if not stable_pose or not stable_contact or not stable_orientation:
			break
	_check(stable_pose and iterations == 40000, "40,000 animated IK samples preserve finite rotations and animated joint positions/scales")
	_check(stable_contact, "repeated IK preserves sole contact and continuous ankle chains")
	_check(stable_orientation, "repeated IK preserves animated global foot orientation")
	_check(stable_animation_time, "repeated IK does not advance imported animation timing")
	_check(
		player.global_transform.is_equal_approx(body_before)
		and player.velocity.is_equal_approx(velocity_before)
		and player.collision_layer == layer_before and player.collision_mask == mask_before
		and Vector2(capsule.radius, capsule.height).is_equal_approx(capsule_size),
		"repeated IK leaves player movement and capsule collision authority unchanged"
	)


func _exercise_sloped_locomotion(player: PlayerController, expected_state: StringName, sprint: bool) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var prior_drop := float(player.get_grounded_foot_placement_snapshot().get("visual_pelvis_drop_m", 0.0))
	var largest_step := 0.0
	var largest_drop := 0.0
	var lowest_corner := INF
	var highest_corner := -INF
	var largest_ankle_error := 0.0
	var state_frames := 0
	var contact_samples := 0
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint_boost")
	for _motion_frame in 36:
		await physics_frame
		var snapshot := player.get_grounded_foot_placement_snapshot()
		var drop := float(snapshot.get("visual_pelvis_drop_m", 0.0))
		largest_step = maxf(largest_step, absf(drop - prior_drop))
		largest_drop = maxf(largest_drop, drop)
		prior_drop = drop
		if player.get_authored_motion_state() == expected_state:
			state_frames += 1
		var feet: Dictionary = snapshot.get("feet", {})
		for side: StringName in [&"l", &"r"]:
			var record: Dictionary = feet.get(side, {})
			if not bool(record.get("active", false)):
				continue
			contact_samples += 1
			var gaps := _boot_sole_gaps(presentation, side, record)
			lowest_corner = minf(lowest_corner, gaps.x)
			highest_corner = maxf(highest_corner, gaps.y)
			largest_ankle_error = maxf(largest_ankle_error, float(record.get("ankle_chain_error_m", INF)))
	Input.action_release("move_forward")
	if sprint:
		Input.action_release("sprint_boost")
	_check(state_frames >= 20 and contact_samples > 0, "%s exercises supported production locomotion" % expected_state)
	_check(largest_step <= 0.0061 and largest_drop <= 0.0401, "%s limits visual pelvis travel to 6 mm per tick and 40 mm total (step %.4f m, drop %.4f m)" % [expected_state, largest_step, largest_drop])
	_check(lowest_corner >= MIN_BOOT_SOLE_GAP_M, "%s never drives a sampled boot corner through the ramp (lowest %+.4f m)" % [expected_state, lowest_corner])
	_check(largest_ankle_error <= MAX_ANKLE_CHAIN_ERROR_M, "%s keeps both ankle chains continuous (worst %.5f m)" % [expected_state, largest_ankle_error])
	print("PILOT_SLOPED_MOTION_MEASURE: %s active_corners=%+.4f..%+.4f m" % [expected_state, lowest_corner, highest_corner])


func _sweep_idle_ramp(player: PlayerController, label: String) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var lowest_corner := INF
	var highest_corner := -INF
	var largest_step := 0.0
	var prior_drop := float(presentation.get_foot_placement_snapshot().get("visual_pelvis_drop_m", 0.0))
	var planted_samples := 0
	for _frame in 144:
		await physics_frame
		var snapshot := presentation.get_foot_placement_snapshot()
		var drop := float(snapshot.get("visual_pelvis_drop_m", 0.0))
		largest_step = maxf(largest_step, absf(drop - prior_drop))
		prior_drop = drop
		var feet: Dictionary = snapshot.get("feet", {})
		for side: StringName in [&"l", &"r"]:
			var record: Dictionary = feet.get(side, {})
			if not bool(record.get("active", false)):
				continue
			planted_samples += 1
			var gaps := _boot_sole_gaps(presentation, side, record)
			lowest_corner = minf(lowest_corner, gaps.x)
			highest_corner = maxf(highest_corner, gaps.y)
	_check(planted_samples == 288, "%s keeps both boots planted through a full idle loop" % label)
	_check(lowest_corner >= MIN_BOOT_SOLE_GAP_M and highest_corner <= MAX_BOOT_SOLE_GAP_M, "%s full idle loop keeps skinned corners near deck (%+.4f..%+.4f m)" % [label, lowest_corner, highest_corner])
	_check(largest_step <= 0.0061, "%s full idle loop has no visual pelvis step above 6 mm" % label)


func _make_support(node_name: StringName, origin: Vector3, ramp_degrees: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = origin
	body.rotation.z = deg_to_rad(ramp_degrees)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = box
	body.add_child(collision)
	return body


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await physics_frame


func _check_grounded_snapshot(player: PlayerController, surface_name: String) -> void:
	var snapshot := player.get_grounded_foot_placement_snapshot()
	_check(bool(snapshot.get("attached", false)), surface_name + " keeps one attached presentation")
	_check(bool(snapshot.get("active", false)), surface_name + " activates grounded foot placement")
	_check(snapshot.get("motion_state", &"") == &"idle", surface_name + " preserves imported idle timing")
	var feet: Dictionary = snapshot.get("feet", {})
	for side: StringName in [&"l", &"r"]:
		var foot: Dictionary = feet.get(side, {})
		_check(bool(foot.get("active", false)), "%s %s foot resolves support" % [surface_name, side])
		_check(
			float(foot.get("sole_error_m", INF)) <= MAX_SOLE_ERROR_M,
			"%s %s sole stays within 2.5 cm of support (%.4f m)" % [
				surface_name, side, float(foot.get("sole_error_m", INF))
			]
		)
		_check(
			float(foot.get("ankle_chain_error_m", INF)) <= MAX_ANKLE_CHAIN_ERROR_M,
			"%s %s foot remains attached to its solved ankle (%.4f m)" % [
				surface_name, side, float(foot.get("ankle_chain_error_m", INF))
			]
		)
	_check(
		int(snapshot.get("modifier_node_count", -1)) == 1,
		surface_name + " uses only the one engine compatibility modifier"
	)


func _check_ramp_boot_sole_contact(player: PlayerController, label: String) -> void:
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	_check_boot_sole_plane(presentation, label)


func _check_boot_sole_plane(presentation: PilotSkinnedPresentation, label: String) -> void:
	var feet: Dictionary = presentation.get_foot_placement_snapshot().feet
	for side: StringName in [&"l", &"r"]:
		var record: Dictionary = feet[side]
		var gaps := _boot_sole_gaps(presentation, side, record)
		var minimum := gaps.x
		var maximum := gaps.y
		_check(
			maximum - minimum <= MAX_BOOT_SOLE_PLANE_SPREAD_M,
			"%s %s boot sole follows support plane (corner gaps %+.4f to %+.4f m)" % [label, side, minimum, maximum]
		)
		_check(
			minimum >= MIN_BOOT_SOLE_GAP_M and maximum <= MAX_BOOT_SOLE_GAP_M,
			"%s %s skinned heel and toe contact the support without penetration or hover" % [label, side]
		)


func _boot_sole_gaps(presentation: PilotSkinnedPresentation, side: StringName, record: Dictionary) -> Vector2:
	var skeleton := presentation.get_skeleton()
	var support_position: Vector3 = record.support_position
	var support_normal: Vector3 = record.support_normal
	var foot_index := skeleton.find_bone("foot_" + String(side))
	var toe_index := skeleton.find_bone("toe_" + String(side))
	var foot_deform := skeleton.get_bone_global_pose(foot_index) * skeleton.get_bone_global_rest(foot_index).affine_inverse()
	var toe_deform := skeleton.get_bone_global_pose(toe_index) * skeleton.get_bone_global_rest(toe_index).affine_inverse()
	var center_x := -0.14 if side == &"l" else 0.14
	var minimum := INF
	var maximum := -INF
	# The shipped BootSole uses 62% foot and 38% toe weights at every
	# vertex. Probe its four bottom corners against the sampled ramp plane.
	for offset_x in [-0.095, 0.095]:
		for z in [-0.085, 0.295]:
			var bind := Vector3(center_x + offset_x, 0.0, z)
			var deformed := foot_deform * bind * 0.62 + toe_deform * bind * 0.38
			var point := skeleton.global_transform * deformed
			var gap := (point - support_position).dot(support_normal)
			minimum = minf(minimum, gap)
			maximum = maxf(maximum, gap)
	return Vector2(minimum, maximum)


func _bone_world_position(presentation: PilotSkinnedPresentation, bone_name: StringName) -> Vector3:
	var skeleton := presentation.get_skeleton()
	skeleton.force_update_all_bone_transforms()
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin


func _test_clip_release(player: PlayerController, world: Node3D, clip: StringName) -> void:
	await _settle(48)
	var presentation := player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation
	var starting_drop := float(presentation.get_foot_placement_snapshot().get("visual_pelvis_drop_m", 0.0))
	player.set_physics_process(false)
	var reference := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	world.add_child(reference)
	reference.global_transform = presentation.global_transform
	var live_animation := presentation.get_animation_player()
	var reference_animation := reference.get_animation_player()
	reference_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	reference_animation.play(&"idle")
	reference_animation.seek(live_animation.current_animation_position, true)
	reference_animation.advance(0.0)
	var prior_pelvis_offset := _bone_world_position(presentation, &"pelvis") - _bone_world_position(reference, &"pelvis")
	var prior_head_offset := _bone_world_position(presentation, &"head") - _bone_world_position(reference, &"head")
	var largest_pelvis_step := 0.0
	var largest_head_step := 0.0
	var generation := presentation.get_foot_placement_attachment_generation()
	for sample in 8:
		await physics_frame
		if sample == 0:
			live_animation.play(clip, 0.0)
			reference_animation.play(clip, 0.0)
			live_animation.seek(0.0, true)
			reference_animation.seek(0.0, true)
		else:
			live_animation.advance(1.0 / 60.0)
			reference_animation.advance(1.0 / 60.0)
		presentation.clear_foot_placement(generation, StringName("test_%s_transition" % clip))
		var pelvis_offset := _bone_world_position(presentation, &"pelvis") - _bone_world_position(reference, &"pelvis")
		var head_offset := _bone_world_position(presentation, &"head") - _bone_world_position(reference, &"head")
		largest_pelvis_step = maxf(largest_pelvis_step, pelvis_offset.distance_to(prior_pelvis_offset))
		largest_head_step = maxf(largest_head_step, head_offset.distance_to(prior_head_offset))
		prior_pelvis_offset = pelvis_offset
		prior_head_offset = head_offset
	_check(starting_drop > 0.01, "%s transition begins from a real sloped idle correction" % clip)
	_check(
		largest_pelvis_step <= 0.0061 and largest_head_step <= 0.0061,
		"%s authored clip releases world pelvis/head offset by at most 6 mm per physics frame (%.4f/%.4f m)" % [clip, largest_pelvis_step, largest_head_step]
	)
	_check(
		prior_pelvis_offset.length() <= 0.001 and prior_head_offset.length() <= 0.001,
		"%s authored clip fully releases the prior ramp offset" % clip
	)
	reference.queue_free()
	await process_frame
	player.set_physics_process(true)
	await _settle(48)


func _test_rotated_presentation_and_seat_clips(world: Node3D) -> void:
	var presentation := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	world.add_child(presentation)
	presentation.global_basis = Basis(Vector3.FORWARD, deg_to_rad(30.0))
	await process_frame
	var animation := presentation.get_animation_player()
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play(&"idle")
	animation.seek(0.0, true)
	animation.advance(0.0)
	var movement_up := presentation.global_basis * Vector3.UP
	var support_normal := Basis(Vector3.FORWARD, deg_to_rad(6.0)) * movement_up
	var anchors := presentation.get_animated_foot_anchors()
	var feet := {}
	for side: StringName in [&"l", &"r"]:
		feet[side] = {
			"position": (anchors[side] as Vector3) - movement_up * PilotSkinnedPresentation.FOOT_SOLE_CLEARANCE_M,
			"normal": support_normal,
		}
	var result := presentation.apply_foot_placement({
		"physics_frame": 1, "motion_state": &"idle",
		"movement_up": movement_up, "feet": feet,
	}, presentation.get_foot_placement_attachment_generation())
	_check(bool(result.get("accepted", false)), "rotated presentation accepts a planted support sample")
	_check_boot_sole_plane(presentation, "rotated presentation six-degree ramp")
	var skeleton := presentation.get_skeleton()
	for clip: StringName in [&"boarding", &"seated_control", &"disembark_recovery"]:
		animation.play(clip)
		animation.seek(0.3, true)
		animation.advance(0.0)
		var foot_index := skeleton.find_bone(&"foot_l")
		var before := skeleton.get_bone_global_pose(foot_index)
		var time_before := animation.current_animation_position
		presentation.apply_foot_placement({
			"physics_frame": 2 + [&"boarding", &"seated_control", &"disembark_recovery"].find(clip),
			"motion_state": clip, "movement_up": movement_up, "feet": feet,
		}, presentation.get_foot_placement_attachment_generation())
		_check(
			not bool(presentation.get_foot_placement_snapshot().get("active", true))
			and is_zero_approx(float(presentation.get_foot_placement_snapshot().get("visual_pelvis_drop_m", INF)))
			and skeleton.get_bone_global_pose(foot_index).is_equal_approx(before)
			and animation.current_animation_position == time_before,
			"%s keeps the authored seated/transition pose and timing" % clip
		)
	presentation.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PILOT_FOOT_PLACEMENT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	push_error("PILOT_FOOT_PLACEMENT_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
