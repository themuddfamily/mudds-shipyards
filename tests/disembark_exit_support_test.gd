extends SceneTree

## A pilot who climbs out of a berthed craft finishes the climb standing on the
## deck, not in the air above it.
##
## The Zenith's `ExitPoint` sits 0.53 m above Fleet Dock slab 01 when the craft
## is docked. The disembark arc used to end there, so every Zenith exit dropped
## the pilot half a metre and played the airborne and landing-recovery clips in
## front of the canopy. Driven through production `Main`: a real boarding at the
## Zenith's `ShipBoardingArea`, a real berth exit through `_try_exit_ship()`.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "DISEMBARK_EXIT_SUPPORT_TEST_OK"
const FAILURE_MARKER := "DISEMBARK_EXIT_SUPPORT_TEST_FAILED"
const DECK_TOLERANCE := 0.05

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.05
	game.boarding_motion_time = 0.2
	game.disembarking_motion_time = 0.3
	game.start_shift()
	await process_frame
	await physics_frame

	var player := game.player as PlayerController
	var zenith := game.get_node_or_null(^"ZenithInterceptor") as HeroShip
	_check(player != null and zenith != null, "production Main exposes the pilot and the Zenith")
	if player == null or zenith == null:
		await _finish(game)
		return

	# The slab the docked Zenith stands on, measured under its own exit marker.
	var exit_marker := zenith.get_exit_transform().origin
	var deck_hit := player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			exit_marker + Vector3.UP * 0.3,
			exit_marker + Vector3.DOWN * 3.0,
			PhysicsLayers.WORLD,
			[player.get_rid(), zenith.get_rid()]
		)
	)
	_check(not deck_hit.is_empty(), "a walkable deck stands under the Zenith's exit")
	if deck_hit.is_empty():
		await _finish(game)
		return
	var deck_y := (deck_hit.position as Vector3).y

	player.teleport_to(Transform3D(Basis.IDENTITY, zenith.get_boarding_position() + Vector3.UP * 0.05))
	for _i in 4:
		await physics_frame
	game._board_ship(zenith)
	_check(
		await _wait_until(func() -> bool:
			return game.phase == GameFlow.Phase.START_ENGINES and not game._transition_busy, 600),
		"the pilot takes the Zenith's seat through the production boarding flow"
	)

	game._try_exit_ship()
	var motion_states := {}
	var settled := false
	var exit_phase_seen := false
	for _frame in 600:
		await physics_frame
		if not player.is_seated():
			motion_states[player.get_authored_motion_state()] = true
		if game.phase == GameFlow.Phase.APPROACH_SHIP and not game._transition_busy:
			# physics_frame resumes before the player's callback. Observe the ready
			# phase twice so one ordinary on-foot solver runs before the floor check.
			if exit_phase_seen:
				settled = true
				break
			exit_phase_seen = true
		else:
			exit_phase_seen = false
	_check(settled, "the berth exit returns the pilot to the deck")
	_check(
		not motion_states.has(&"airborne") and not motion_states.has(&"landing_recovery"),
		"the climb down never leaves the pilot falling (states: %s)" % [motion_states.keys()]
	)
	_check(
		absf(player.global_position.y - deck_y) <= DECK_TOLERANCE and player.is_on_floor(),
		"the pilot stands on the slab (%.3f m above it)" % (player.global_position.y - deck_y)
	)
	await _assert_on_foot_exterior_exit(game, player)
	await _finish(game)


func _assert_on_foot_exterior_exit(game: GameFlow, player: PlayerController) -> void:
	var frame := Node3D.new()
	frame.name = "SupportedPassengerExitFrame"
	game.add_child(frame)
	frame.global_transform = Transform3D(Basis.IDENTITY, player.global_position)
	var waypoint := frame.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.2, 0.0, 0.0))
	var target := frame.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.4, 0.0, 0.0))
	var route: Array[Transform3D] = [waypoint]
	var start := player.global_transform
	var standing_layer := player.collision_layer
	var standing_mask := player.collision_mask
	var shape := player.get_node(^"PlayerCollision") as CollisionShape3D
	_check(not player.begin_on_foot_exterior_exit(target, 0.15, null, route)
		and player.global_transform == start and player.is_control_enabled(),
		"walking exterior exit refuses a missing live frame without changing the supported body")
	var completion := {"count": 0, "collision_ready": false}
	player.disembarking_completed.connect(func() -> void:
		completion.count += 1
		completion.collision_ready = player.collision_layer == standing_layer \
			and player.collision_mask == standing_mask and not shape.disabled,
		CONNECT_ONE_SHOT)
	var accepted := player.begin_on_foot_exterior_exit(target, 0.15, frame, route)
	_check(accepted and not player.is_seated() and not player.is_control_enabled()
		and player.global_transform == start and player.collision_layer == 0,
		"supported walking passenger starts physical exit directly without acquiring a seat or teleporting")
	if accepted:
		# The shared disembark path must resolve its endpoint through the live
		# reference frame, including a rebase during an already-running exit.
		frame.global_position += Vector3.RIGHT * 0.1
		var seated_seen := false
		for _tick in 120:
			await physics_frame
			seated_seen = seated_seen or player.is_seated()
			if int(completion.count) > 0:
				break
		_check(int(completion.count) == 1 and bool(completion.collision_ready)
			and not seated_seen and not player.is_control_enabled(),
			"walking exit completes once with collision restored and controls left to its coordinator")
		_check(player.global_position.distance_to(target.origin + Vector3.RIGHT * 0.1) <= 0.01,
			"walking exit follows the reference frame to its supported authored endpoint")
		player.set_control_enabled(true)
		await physics_frame
		await physics_frame
		_check(player.is_on_floor() and not shape.disabled,
			"walking exterior exit resumes as an ordinary supported colliding body")
	frame.queue_free()


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _frame in frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return bool(predicate.call())


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if ok:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [
		SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions,
	])
	quit(0 if _failures.is_empty() else 1)
