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
	await _test_start_shift_currentness()
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


func _test_start_shift_currentness() -> void:
	var detached_game := MAIN_SCENE.instantiate() as GameFlow
	detached_game.name = "DetachedStartShiftGame"
	root.add_child(detached_game)
	await process_frame
	await physics_frame
	var detached_before := _start_shift_snapshot(detached_game)
	root.remove_child(detached_game)
	detached_game.start_shift()
	_check(
		not detached_game.is_inside_tree()
			and _start_shift_snapshot(detached_game) == detached_before,
		"a detached GameFlow rejects direct start-shift mutation atomically"
	)
	root.add_child(detached_game)
	await process_frame
	detached_game.start_shift()
	_check(
		detached_game.is_inside_tree()
			and detached_game.phase == GameFlow.Phase.APPROACH_SHIP
			and (detached_game.player as PlayerController).is_control_enabled()
			and (detached_game.player as PlayerController).get_camera().current,
		"a fresh live GameFlow re-entry accepts its current start-shift request"
	)
	detached_game.queue_free()
	await process_frame
	await process_frame

	var queued_game := MAIN_SCENE.instantiate() as GameFlow
	queued_game.name = "QueuedStartShiftGame"
	root.add_child(queued_game)
	await process_frame
	await physics_frame
	var queued_before := _start_shift_snapshot(queued_game)
	queued_game.queue_free()
	queued_game.start_shift()
	_check(
		queued_game.is_inside_tree()
			and queued_game.is_queued_for_deletion()
			and _start_shift_snapshot(queued_game) == queued_before,
		"a queued GameFlow rejects direct start-shift mutation atomically"
	)
	await process_frame
	await process_frame
	_check(not is_instance_valid(queued_game), "the queued GameFlow fixture frees normally")


func _start_shift_snapshot(game: GameFlow) -> Dictionary:
	var player := game.player as PlayerController
	var hud := game.hud as CanvasLayer
	var audio := game.audio as AudioDirector
	var objective := hud.get("_objective_label") as Label
	var objective_kicker := hud.get("_objective_kicker") as Label
	var toast_title := hud.get("_toast_title") as Label
	var toast_detail := hud.get("_toast_detail") as Label
	var toast_panel := hud.get("_toast_panel") as PanelContainer
	return {
		"phase": game.phase,
		"player_control_enabled": player.is_control_enabled(),
		"player_camera_current": player.get_camera().current,
		"hud_mode": hud.get("_state_mode"),
		"objective": objective.text if objective != null else "",
		"objective_kicker": objective_kicker.text if objective_kicker != null else "",
		"toast_title": toast_title.text if toast_title != null else "",
		"toast_detail": toast_detail.text if toast_detail != null else "",
		"toast_visible": toast_panel.visible if toast_panel != null else false,
		"toast_serial": hud.get("_toast_serial"),
		"audio_on_foot_volume_db": audio.get("_desired_ambience_volume_db"),
	}.duplicate(true)


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
