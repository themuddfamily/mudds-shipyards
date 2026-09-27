extends SceneTree

## Per-foot IK for the skinned pilot: both boots plant on a stair step and on a
## pitched slope, the IK weight fades to zero when seated or airborne, and the
## solve never touches the Player capsule, velocity or collision authority.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const STEP_HEIGHT_M := 0.16
const SLOPE_DEGREES := 8.0
const MAX_SOLE_ERROR_M := 0.03
const MAX_ANKLE_CHAIN_ERROR_M := 0.001
const MIN_BOOT_SOLE_GAP_M := -0.008
const MAX_BOOT_SOLE_GAP_M := 0.02

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "PilotFootIKWorld"
	root.add_child(world)

	# A stair edge running along the pilot's facing: the capsule stands on the
	# upper tread (its edge 3 cm past the capsule centre, x = 0.03) and the boot
	# at x = +/-0.14 on the open side hangs over the lower floor.
	var lower := _make_box(&"LowerFloor", Vector3(0.0, -0.1, 0.0), Vector3(12.0, 0.2, 12.0), Basis.IDENTITY)
	var upper := _make_box(
		&"UpperTread", Vector3(-2.97, STEP_HEIGHT_M - 0.1, 0.0), Vector3(6.0, 0.2, 12.0), Basis.IDENTITY
	)
	world.add_child(lower)
	world.add_child(upper)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	world.add_child(player)
	player.set_control_enabled(false)
	player.set_camera_active(false)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, STEP_HEIGHT_M + 0.2, 0.0)))
	await _settle(72)
	_check_step_stance(player)
	_check_capsule_authority(player)

	lower.queue_free()
	upper.queue_free()
	await physics_frame
	var slope := _make_box(
		&"PitchedSlope", Vector3.ZERO, Vector3(20.0, 0.2, 20.0),
		Basis(Vector3.RIGHT, deg_to_rad(SLOPE_DEGREES))
	)
	world.add_child(slope)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)))
	await _settle(72)
	_check_slope_stance(player)

	await _check_airborne_blend_out(player)
	await _settle(48)
	await _check_seated_blend_out(player, world)

	world.queue_free()
	await process_frame
	await process_frame
	_finish()


func _check_step_stance(player: PlayerController) -> void:
	var presentation := _presentation(player)
	var snapshot := presentation.get_foot_placement_snapshot()
	_check(snapshot.get("motion_state", &"") == &"idle", "step stance runs on imported idle")
	_check(
		is_equal_approx(float(snapshot.get("ik_weight", 0.0)), 1.0),
		"standing IK runs at full weight"
	)
	var feet: Dictionary = snapshot.get("feet", {})
	var heights: Array[float] = []
	for side: StringName in [&"l", &"r"]:
		var record: Dictionary = feet.get(side, {})
		_check(bool(record.get("active", false)), "step %s foot is planted" % side)
		_check(
			float(record.get("sole_error_m", INF)) <= MAX_SOLE_ERROR_M,
			"step %s sole within %.0f mm of its support (%.4f m)" % [
				side, MAX_SOLE_ERROR_M * 1000.0, float(record.get("sole_error_m", INF))
			]
		)
		_check(
			float(record.get("ankle_chain_error_m", INF)) <= MAX_ANKLE_CHAIN_ERROR_M,
			"step %s ankle stays on its solved chain" % side
		)
		if record.has("support_position"):
			heights.append((record.support_position as Vector3).y)
			var gaps := _boot_sole_gaps(presentation, side, record)
			_check(
				gaps.x >= MIN_BOOT_SOLE_GAP_M and gaps.y <= MAX_BOOT_SOLE_GAP_M,
				"step %s boot corners rest on their own tread (%+.4f..%+.4f m)" % [side, gaps.x, gaps.y]
			)
	_check(
		heights.size() == 2 and absf(absf(heights[0] - heights[1]) - STEP_HEIGHT_M) <= 0.01,
		"the two boots are planted on different treads one step apart (%s)" % str(heights)
	)
	_check(
		float(snapshot.get("visual_pelvis_drop_m", 0.0)) > 0.04,
		"the visual pelvis lowers so the lower leg reaches its tread (%.4f m)" % float(snapshot.get("visual_pelvis_drop_m", 0.0))
	)
	_check(
		int(snapshot.get("toe_probe_count", 0)) <= 2,
		"the presentation adds at most one toe ray per foot per tick"
	)
	_check(
		int(snapshot.get("modifier_node_count", -1)) == 1,
		"foot IK adds no SkeletonModifier3D nodes"
	)


func _check_slope_stance(player: PlayerController) -> void:
	var presentation := _presentation(player)
	var snapshot := presentation.get_foot_placement_snapshot()
	var feet: Dictionary = snapshot.get("feet", {})
	for side: StringName in [&"l", &"r"]:
		var record: Dictionary = feet.get(side, {})
		_check(bool(record.get("active", false)), "slope %s foot is planted" % side)
		_check(
			float(record.get("sole_error_m", INF)) <= MAX_SOLE_ERROR_M,
			"slope %s sole within tolerance (%.4f m)" % [side, float(record.get("sole_error_m", INF))]
		)
		if record.has("support_position"):
			var gaps := _boot_sole_gaps(presentation, side, record)
			_check(
				gaps.x >= MIN_BOOT_SOLE_GAP_M and gaps.y <= MAX_BOOT_SOLE_GAP_M,
				"slope %s boot sole follows the %.0f-degree plane (%+.4f..%+.4f m)" % [
					side, SLOPE_DEGREES, gaps.x, gaps.y
				]
			)


func _check_capsule_authority(player: PlayerController) -> void:
	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	var body_before := player.global_transform
	var shape_before := collision.transform
	var velocity_before := player.velocity
	var layer_before := player.collision_layer
	var mask_before := player.collision_mask
	var capsule_before := Vector2(capsule.radius, capsule.height)
	player.set_physics_process(false)
	await physics_frame
	for _repeat in 3:
		player.call("_update_grounded_foot_placement")
	_check(
		player.global_transform.is_equal_approx(body_before)
		and collision.transform.is_equal_approx(shape_before),
		"foot IK leaves the Player root and capsule transform unchanged"
	)
	_check(player.velocity.is_equal_approx(velocity_before), "foot IK leaves velocity unchanged")
	_check(
		player.collision_layer == layer_before and player.collision_mask == mask_before
		and Vector2(capsule.radius, capsule.height).is_equal_approx(capsule_before),
		"foot IK leaves collision layers and capsule size unchanged"
	)
	player.set_physics_process(true)


func _check_airborne_blend_out(player: PlayerController) -> void:
	player.velocity = Vector3.UP * 3.0
	await physics_frame
	await physics_frame
	var first := float(_presentation(player).get_foot_placement_snapshot().get("ik_weight", -1.0))
	_check(first > 0.0 and first < 1.0, "leaving the ground fades the leg IK instead of snapping (%.3f)" % first)
	await _settle(14)
	var airborne := _presentation(player).get_foot_placement_snapshot()
	_check(not player.is_on_floor(), "the pilot is still airborne for the weight check")
	_check(
		is_zero_approx(float(airborne.get("ik_weight", -1.0)))
		and not bool(airborne.get("active", true)),
		"IK weight is zero while airborne"
	)


func _check_seated_blend_out(player: PlayerController, world: Node3D) -> void:
	var seat := Node3D.new()
	seat.name = "FootIKSeat"
	world.add_child(seat)
	seat.global_transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3(0.0, 0.3, -1.0))
	var entry := player.global_transform
	_check(player.begin_boarding(entry, seat, 0.3), "boarding begins from the slope stance")
	await physics_frame
	var boarding_weight := float(_presentation(player).get_foot_placement_snapshot().get("ik_weight", -1.0))
	_check(
		boarding_weight > 0.0 and boarding_weight < 1.0,
		"boarding fades the leg IK out over the transition clip (%.3f)" % boarding_weight
	)
	await _settle(40)
	var seated := _presentation(player).get_foot_placement_snapshot()
	_check(player.is_seated(), "the pilot reaches the seat")
	_check(
		is_zero_approx(float(seated.get("ik_weight", -1.0)))
		and not bool(seated.get("active", true)),
		"IK weight is zero while seated"
	)


func _presentation(player: PlayerController) -> PilotSkinnedPresentation:
	return player.find_child("PilotSkinnedPresentation", true, false) as PilotSkinnedPresentation


func _make_box(node_name: StringName, origin: Vector3, size: Vector3, basis: Basis) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = Transform3D(basis, origin)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	return body


func _boot_sole_gaps(presentation: PilotSkinnedPresentation, side: StringName, record: Dictionary) -> Vector2:
	var skeleton := presentation.get_skeleton()
	skeleton.force_update_all_bone_transforms()
	var support_position: Vector3 = record.support_position
	var support_normal: Vector3 = record.support_normal
	var foot_index := skeleton.find_bone("foot_" + String(side))
	var toe_index := skeleton.find_bone("toe_" + String(side))
	var foot_deform := skeleton.get_bone_global_pose(foot_index) * skeleton.get_bone_global_rest(foot_index).affine_inverse()
	var toe_deform := skeleton.get_bone_global_pose(toe_index) * skeleton.get_bone_global_rest(toe_index).affine_inverse()
	# The rig's `_l` side sits at negative X by authoring; do not swap it.
	var center_x := -0.14 if side == &"l" else 0.14
	var minimum := INF
	var maximum := -INF
	for offset_x in [-0.095, 0.095]:
		for z in [-0.085, 0.295]:
			var bind := Vector3(center_x + offset_x, 0.0, z)
			var deformed := foot_deform * bind * 0.62 + toe_deform * bind * 0.38
			var gap := (skeleton.global_transform * deformed - support_position).dot(support_normal)
			minimum = minf(minimum, gap)
			maximum = maxf(maximum, gap)
	return Vector2(minimum, maximum)


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
		print("PILOT_FOOT_IK_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	push_error("PILOT_FOOT_IK_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
