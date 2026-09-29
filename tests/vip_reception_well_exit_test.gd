extends SceneTree

## The VIP reception's sunken conversation well must be walkable back out toward
## the landmark door, not only through the port-side step.
##
## The broad entry step (`WellStepEntry`) the processional route ends at was
## 0.7 m deep and sat almost entirely under the banquette arc that sweeps the
## entry side, so from the well floor the capsule met a 0.45 m face (step plus
## banquette base) with no usable tread: holding W toward the door from
## anywhere in the well's front half stopped dead against the banquette. This
## suite drives the production capsule with real movement input on real Main.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WALK_FRAMES := 240
const REACH_METRES := 0.4

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for _settle in 6:
		await physics_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"Player") as PlayerController
	var room := world.get_node_or_null(^"VipReceptionSuite/Structure/Reception") as Node3D if world != null else null
	_check(player != null and room != null, "production player and VIP reception room are live")
	if player != null and room != null:
		# Room-local well-floor starts either side of the table, and the reception
		# floor ahead of the entry, toward the landmark door.
		for route in [
			[Vector3(0.2, VipReceptionSuite.WELL_FLOOR, 7.6), Vector3(-0.6, 0.0, 3.5)],
			[Vector3(-2.7, VipReceptionSuite.WELL_FLOOR, 7.7), Vector3(-1.4, 0.0, 3.5)],
		]:
			var start := route[0] as Vector3
			await _walk_out(player, room, start, route[1] as Vector3, "from the well floor at x=%.1f" % start.x)
		# The port step remains a working exit.
		await _walk_out(player, room, Vector3(-3.3, VipReceptionSuite.WELL_FLOOR, 8.6), Vector3(-5.3, 0.0, 9.0), "through the port step")
	_release()
	if game != null:
		game.queue_free()
	await process_frame
	await physics_frame
	if _failures.is_empty():
		print("VIP_RECEPTION_WELL_EXIT_TEST_OK")
		quit(0)
	else:
		print("VIP_RECEPTION_WELL_EXIT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _walk_out(player: PlayerController, room: Node3D, local_start: Vector3, local_target: Vector3, label: String) -> void:
	_release()
	player.teleport_to(Transform3D(Basis(), room.to_global(local_start + Vector3.UP * 0.02)))
	for _settle in 8:
		await physics_frame
	var settled := room.to_local(player.global_position)
	_check(
		absf(settled.y - VipReceptionSuite.WELL_FLOOR) <= 0.05,
		"%s: the pilot starts standing on the well floor (y=%.3f)" % [label, settled.y]
	)
	var target := room.to_global(local_target)
	var reached := false
	for _frame in WALK_FRAMES:
		var offset := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
		if offset.length() <= REACH_METRES:
			reached = true
			break
		(player.get("_camera_yaw") as Node3D).rotation.y = atan2(-offset.x, -offset.z)
		Input.action_press(&"move_forward")
		await physics_frame
	_release()
	await physics_frame
	var final_local := room.to_local(player.global_position)
	print("VIP_WELL_EXIT ", label, " final_local=", final_local.snappedf(0.01))
	_check(
		reached and absf(final_local.y) <= 0.1,
		"%s: holding forward walks up out of the well onto the reception floor without a jump" % label
	)


func _release() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
