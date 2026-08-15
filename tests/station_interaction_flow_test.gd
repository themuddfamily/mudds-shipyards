extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DOOR_SCENE := preload("res://scenes/world/components/station_door.tscn")

## Extra simulated physics frames allowed on top of the exact number the door's
## own `motion_duration` requires. This is a frame count, never a wall-clock
## grace, so the budget is identical on an idle and on a saturated machine.
const DOOR_MOTION_FRAME_GRACE := 12

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()

	var player := game.get_node("Player") as PlayerController
	var door := DOOR_SCENE.instantiate() as StationDoor
	door.name = "IntegrationDoor"
	door.motion_duration = 0.08
	door.interaction_label = "AFT OPERATIONS"
	game.add_child(door)

	var player_transform: Transform3D = game.world.get_player_spawn()
	player.teleport_to(player_transform)
	door.global_position = player_transform.origin + Vector3(0.0, 0.0, -2.0)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame

	_check(
		game.station_interaction_candidate == door,
		"facing a nearby station door selects it through the shared interaction area"
	)
	_check(not game._near_ship, "station interaction does not fabricate a boarding candidate")
	game.call("_on_interact_requested")
	_check(
		door.get_state() == StationDoor.DoorState.OPENING,
		"the same embodied interact request starts the physical station door"
	)
	# `StationDoor` advances its panel in `_physics_process`, so the only clock that
	# measures its motion is the physics clock. A `SceneTree` timer counts smoothed
	# idle delta instead, and the two diverge under parallel load: Godot drops
	# physics steps to avoid a spiral of death while idle time keeps accumulating,
	# so a 0.15 s idle timer can fire before 0.08 s of simulated motion has been
	# stepped. Wait on the door's real completion with a budget counted in physics
	# frames, which is the same number of frames however busy the box is.
	var opened := await _wait_for_physics_frames(
		func() -> bool: return door.is_open() and not door.is_portal_blocked(),
		_door_motion_frame_budget(door)
	)
	_check(
		opened,
		"the started door completes its motion inside its own physics-frame budget"
	)
	_check(door.is_open() and not door.is_portal_blocked(), "door interaction reaches a traversable physical opening")

	# Facing is part of the interaction contract; proximity alone must not make a
	# station control behind the player consume E.
	var away_transform: Transform3D = player_transform
	away_transform.basis = Basis(Vector3.UP, PI)
	player.teleport_to(away_transform)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(
		game.station_interaction_candidate == null,
		"a nearby station door behind the camera does not consume interaction"
	)

	# A remote door must not disturb the established physical ship interaction.
	var arrow := game.get_node("ArrowReconShip") as HeroShip
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position()))
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(game.station_interaction_candidate == null, "remote station controls leave ship prompts clear")
	_check(game.boarding_candidate == arrow, "ship boarding still wins at its own physical interaction point")

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


## Exactly the number of physics steps `door.motion_duration` needs at the
## project's configured tick rate, plus a fixed frame grace. Derived from the
## door's own export so shortening or lengthening the motion keeps the budget
## honest instead of silently gaining slack.
func _door_motion_frame_budget(door: StationDoor) -> int:
	var required := int(ceil(door.motion_duration * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + DOOR_MOTION_FRAME_GRACE


## Waits for `predicate` on the physics clock. Returns `false` once the budget of
## simulated frames is spent, so a stalled condition still fails the suite rather
## than hanging, but a merely slow machine is never mistaken for a broken door.
func _wait_for_physics_frames(predicate: Callable, maximum_frames: int) -> bool:
	if bool(predicate.call()):
		return true
	for _frame in maximum_frames:
		await physics_frame
		if bool(predicate.call()):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_INTERACTION_FLOW_TEST_OK")
		quit(0)
	else:
		print("STATION_INTERACTION_FLOW_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
