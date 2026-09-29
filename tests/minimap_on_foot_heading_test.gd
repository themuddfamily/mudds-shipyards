extends SceneTree

## The minimap arrow is the embodied player's facing. On foot in first person
## that facing is the view: turning the mouse/stick in place must turn the
## arrow with it, not leave it on the body's last walking direction.

const MainScene := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MainScene.instantiate() as GameFlow
	root.add_child(game)
	for _frame in 4:
		await physics_frame
	await process_frame
	var player := game.player as PlayerController
	_check(is_instance_valid(player) and not bool(game.get("_piloting")),
		"production Main starts with the player on foot")
	var camera_yaw := player.get("_camera_yaw") as Node3D

	player.set_camera_view_mode(PlayerController.CameraViewMode.FIRST_PERSON)
	await physics_frame
	await process_frame
	_check(player.is_first_person_active(), "the on-foot view switches to first person")
	var ahead := float(game.get_minimap_snapshot().get("heading_radians", 0.0))
	var view_ahead := _view_heading(player)
	# Turn the view a right angle in place, as mouse or right-stick look does.
	camera_yaw.rotation.y = wrapf(camera_yaw.rotation.y - PI * 0.5, -PI, PI)
	await physics_frame
	await process_frame
	var turned := float(game.get_minimap_snapshot().get("heading_radians", 0.0))
	var view_turned := _view_heading(player)
	print("arrow ahead %.3f view ahead %.3f arrow turned %.3f view turned %.3f"
		% [ahead, view_ahead, turned, view_turned])
	_check(absf(angle_difference(view_turned, view_ahead)) > 1.4,
		"turning in place rotates the first-person view by a right angle")
	_check(absf(angle_difference(turned, view_turned)) < 0.05,
		"first person: turning in place turns the minimap arrow with the view")

	# Third person keeps the body-facing arrow: the visible suit is the actor.
	player.set_camera_view_mode(PlayerController.CameraViewMode.THIRD_PERSON)
	await physics_frame
	await process_frame
	var body_forward := player.get_pilot_visual_forward_direction()
	var third := float(game.get_minimap_snapshot().get("heading_radians", 0.0))
	_check(absf(angle_difference(third, atan2(body_forward.x, -body_forward.z))) < 0.05,
		"third person: the arrow keeps following the visible body facing")

	root.remove_child(game)
	game.free()
	await process_frame
	print("MINIMAP_ON_FOOT_HEADING_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("MINIMAP_ON_FOOT_HEADING_TEST_OK")
		quit(0)
	else:
		print("MINIMAP_ON_FOOT_HEADING_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _view_heading(player: PlayerController) -> float:
	var forward := player.get_interaction_direction()
	return atan2(forward.x, -forward.z)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
