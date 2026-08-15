extends SceneTree

## Red-by-design witness for a confirmed `GameFlow` defect.
##
## `GameFlow` suppresses an immediate re-board of the craft the pilot just left by
## storing it in `_reboard_blocked_ship`. That field is consulted in exactly one
## place — `_find_boarding_candidate()` — which runs from `_update_on_foot_flow()`,
## which runs from `_process()`, and only while `not _piloting`.
##
## `_on_interact_requested()` does not consult `_reboard_blocked_ship` at all. It
## acts on the cached `boarding_candidate` / `_near_ship` pair, and during a sortie
## that pair is never refreshed, because `_update_on_foot_flow()` is skipped for
## the whole time the pilot is seated. Both therefore still hold the values they
## had when the pilot walked up to the craft and boarded it.
##
## `_try_exit_ship()` re-enables player control and sets `_reboard_blocked_ship`
## before the next `_process()` can refresh anything, and `interact_requested` is
## emitted from `PlayerController._physics_process()`. Godot runs physics
## iterations ahead of the idle frame, so an interact arriving in that window is
## served the stale candidate and re-boards the craft the player just climbed out
## of — the exact outcome the suppression exists to prevent. The window is one
## idle frame wide, so it widens on a loaded machine.
##
## This file is deliberately named outside the `tests/*_test.gd` glob that
## `tools/release/run_test_matrix.sh` collects, following the precedent set for the
## station traversal witness: its assertion is red until the defect is fixed, and
## renaming it back into the glob is part of fixing it.
##
## Fixing it is a test-harness-external change and was out of scope for the agent
## that recorded this, so no production edit accompanies the witness.

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame

	var player := game.get_node("Player") as CharacterBody3D
	var arrow := game.get_node("ArrowReconShip") as ArrowReconShip
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var arrow_transform := world.get_berth_transform(&"arrow_recon_berth")

	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	game.start_shift()
	await process_frame
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE

	# Board the Arrow through the same proximity/interact path the sandbox uses.
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	_check(
		await _wait_until(func() -> bool: return game.boarding_candidate == arrow, 0.2),
		"proximity selects the Arrow before the witness boards it"
	)
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 0.4),
		"the witness boards the Arrow"
	)

	# Land and shut down so the exit path is legitimately available.
	arrow.engine_start_time = 0.03
	arrow.request_engine_start()
	_check(
		await _wait_until(
			func() -> bool: return str(arrow.get_telemetry().engine_state) == "ONLINE",
			0.12
		),
		"the witness starts the Arrow"
	)
	arrow.global_transform = arrow_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.velocity = Vector3.ZERO
	game.call("_try_request_landing")
	_check(
		await _wait_until(func() -> bool: return bool(arrow.get_telemetry().landed), 2.1),
		"the witness lands the Arrow at its home berth"
	)
	arrow.request_engine_stop()

	# Exit, and advance only the physics clock afterwards. This reproduces the real
	# ordering: `interact_requested` is emitted from `PlayerController`'s physics
	# tick, which is reached before the idle tick that would have refreshed
	# `boarding_candidate` and honoured `_reboard_blocked_ship`.
	game.call("_try_exit_ship")
	var exited := false
	for _frame in 240:
		await physics_frame
		if not bool(game.get("_transition_busy")) and not bool(player.is_seated()):
			exited = true
			break
	_check(exited, "the witness disembarks from the Arrow")
	_check(
		game.get("_reboard_blocked_ship") == arrow,
		"GameFlow records the just-exited Arrow as re-board suppressed"
	)

	# The defect: this interact is served the pre-sortie cached candidate.
	game.call("_on_interact_requested")
	_check(
		game.get_active_ship() != arrow and game.phase == GameFlow.Phase.COMPLETE,
		"an interact arriving before the first post-exit idle frame does not re-board the suppressed Arrow"
	)

	Input.action_release("interact")
	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(nominal_seconds, 0.0) * float(Engine.physics_ticks_per_second))) + 30
	)
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SANDBOX_STALE_REBOARD_WITNESS_OK")
		quit(0)
	else:
		print("SANDBOX_STALE_REBOARD_WITNESS_RED: ", "; ".join(_failures))
		quit(1)
