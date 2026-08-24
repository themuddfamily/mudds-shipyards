extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SHALLOW_RAMP_DEGREES := 6.0
const MAX_SOLE_ERROR_M := 0.02

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

	flat.queue_free()
	await physics_frame
	var ramp := _make_support(&"ShallowRamp", Vector3.ZERO, SHALLOW_RAMP_DEGREES)
	world.add_child(ramp)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
	await _settle(48)
	_check_grounded_snapshot(player, "six-degree ramp")

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

	player.set_physics_process(true)
	player.velocity = Vector3.UP * 2.0
	await _settle(2)
	var airborne := player.get_grounded_foot_placement_snapshot()
	_check(
		not bool(airborne.get("active", true)),
		"foot placement is disabled while airborne"
	)

	world.queue_free()
	await process_frame
	await process_frame
	_finish()


func _make_support(node_name: StringName, origin: Vector3, ramp_degrees: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = origin
	body.rotation.z = deg_to_rad(ramp_degrees)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.2, 6.0)
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
			"%s %s sole stays within 2 cm of support (%.4f m)" % [
				surface_name, side, float(foot.get("sole_error_m", INF))
			]
		)
	_check(
		int(snapshot.get("modifier_node_count", -1)) == 1,
		surface_name + " uses only the one engine compatibility modifier"
	)


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
