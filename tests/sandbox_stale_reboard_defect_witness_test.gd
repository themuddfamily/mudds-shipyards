extends SceneTree

## Regression witness for SANDBOX-001, the `GameFlow` re-board suppression bypass.
##
## `GameFlow` suppresses an immediate re-board of the craft the pilot just left by
## storing it in `_reboard_blocked_ship`. That field used to be consulted in exactly
## one place — `_find_boarding_candidate()` — which runs from `_update_on_foot_flow()`,
## which runs from `_process()`, and only while `not _piloting`.
##
## `_on_interact_requested()` did not consult it at all. It acted on the cached
## `boarding_candidate` / `_near_ship` pair, and during a sortie that pair is never
## refreshed, because `_update_on_foot_flow()` is skipped for the whole time the
## pilot is seated. Both therefore still held the values they had when the pilot
## walked up to the craft and boarded it.
##
## `_try_exit_ship()` re-enables player control and sets `_reboard_blocked_ship`
## before the next `_process()` can refresh anything, and `interact_requested` is
## emitted from `PlayerController._physics_process()`. Godot runs every physics
## iteration of a frame ahead of that frame's idle pass, so an interact arriving in
## that window was served the stale candidate and re-boarded the craft the player
## had just climbed out of — the exact outcome the suppression exists to prevent.
## The window was one idle frame wide, so it widened on a loaded machine, where
## several physics iterations run per idle frame.
##
## The fix is `GameFlow._refresh_interaction_targets()`: the interaction selection
## is recomputed inside `_on_interact_requested()` immediately before it acts,
## instead of being read out of a snapshot taken by an earlier idle frame. There is
## no longer any cached value between the state change and the decision, so the
## window is closed rather than narrowed.
##
## Two deliberate, documented changes were made to this file when it was renamed
## into the `tests/*_test.gd` gate glob, following the precedent set by
## `tests/station_traversal_defect_witness_test.gd`. Neither weakens it:
##
## 1. The red assertion's first conjunct was `game.get_active_ship() != arrow`. That
##    is unsatisfiable in this codebase and could never have discriminated the
##    defect: `active_ship` is a persistent "selected craft" pointer, assigned in
##    exactly two places (`_ready()` seeds it with the guided Torrent before any
##    boarding, and `_board_ship()` re-points it), and nothing clears it on
##    disembark — `_try_exit_ship()` itself reads it at its tail to populate
##    `_reboard_blocked_ship`. It therefore still names the Arrow after a clean
##    exit with no re-board, which was verified directly on the unfixed code. The
##    conjunct is replaced by the observables that do discriminate a re-board, and
##    the replacement is stronger than the original pair: phase, transition state,
##    the coordinator's own `_piloting` latch, the player's seat state, and the
##    craft's piloted state must all show that no boarding transition began.
## 2. A second leg was added that reproduces the same window through the real input
##    path end to end — a full second sortie, an exit driven by the piloted interact
##    edge, and then interact mashed on every physics tick while idle frames are
##    throttled so that several physics iterations land inside one idle frame. It
##    also asserts that the suppression still releases normally when the pilot walks
##    away, so a craft cannot be refused forever.
##
## Both legs now throttle idle frames around the exit, and both assert that the
## window they test was really open on that run — the first by checking that the
## pre-sortie proximity cache still names the Arrow, the second by checking that at
## least two physics ticks landed inside one idle frame. This matters: with idle
## frames running freely, as `--headless` does by default, the idle refresh can win
## the race and the original single assertion passed on unfixed code. Both defect
## assertions are red 3/3 with the fix reverted and green with it in place.

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
	# Starve the idle pass the way a loaded machine does, so the exit tail is
	# guaranteed to be followed by another physics tick before the next
	# `_process()`. Without this the two clocks can interleave the other way round
	# and the window is simply not open on that run.
	var authored_max_fps := Engine.max_fps
	Engine.max_fps = 10
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

	# The window is only open while the idle refresh has not run yet. Assert that
	# it really is open on this run, so the assertion below cannot pass vacuously.
	_check(
		game.boarding_candidate == arrow and bool(game.get("_near_ship")),
		"the exit leaves the pre-sortie proximity cache still naming the suppressed Arrow"
	)

	# The defect: this interact used to be served the pre-sortie cached candidate.
	game.call("_on_interact_requested")
	_check(
		game.phase == GameFlow.Phase.COMPLETE
		and not bool(game.get("_transition_busy"))
		and not bool(game.get("_piloting"))
		and not player.is_seated()
		and not arrow.is_piloted(),
		"an interact arriving before the first post-exit idle frame does not re-board the suppressed Arrow"
	)
	Engine.max_fps = authored_max_fps

	await _run_real_input_leg(game, player, arrow, arrow_transform)

	Input.action_release("interact")
	game.queue_free()
	await process_frame
	await process_frame
	_finish()


## Second leg: the same window, driven end to end through the production input
## path on a frame budget that makes the physics-ahead-of-idle ordering explicit.
func _run_real_input_leg(
		game: GameFlow,
		player: CharacterBody3D,
		arrow: ArrowReconShip,
		arrow_transform: Transform3D
	) -> void:
	# Walking out of reach is the authored release for the suppression. Without it
	# the craft would stay unboardable forever, so this also proves the fix did not
	# simply make the Arrow permanently refused.
	var away := arrow.get_boarding_position() + Vector3(0.0, 0.05, GameFlow.BOARDING_FALLBACK_REACH * 2.0)
	player.teleport_to(Transform3D(Basis.IDENTITY, away))
	_check(
		await _wait_until(
			func() -> bool: return game.get("_reboard_blocked_ship") == null,
			0.3
		),
		"walking out of reach releases the re-board suppression"
	)
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	_check(
		await _wait_until(func() -> bool: return game.boarding_candidate == arrow, 0.3),
		"proximity selects the Arrow again once the suppression has been released"
	)

	# A complete second sortie, so the cached pair is stale again at the exit.
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 0.6),
		"a real interact press boards the Arrow for the second sortie"
	)
	arrow.request_engine_start()
	_check(
		await _wait_until(
			func() -> bool: return str(arrow.get_telemetry().engine_state) == "ONLINE",
			0.2
		),
		"the witness starts the Arrow for the second sortie"
	)
	arrow.global_transform = arrow_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.velocity = Vector3.ZERO
	game.call("_try_request_landing")
	_check(
		await _wait_until(func() -> bool: return bool(arrow.get_telemetry().landed), 2.1),
		"the witness lands the Arrow again at its home berth"
	)
	arrow.request_engine_stop()
	_check(
		await _wait_until(
			func() -> bool: return str(arrow.get_telemetry().engine_state) == "OFFLINE",
			0.6
		),
		"the witness shuts the Arrow down for the second exit"
	)
	_check(
		game.boarding_candidate == arrow and bool(game.get("_near_ship")),
		"the cached proximity pair still names the Arrow at the end of the sortie"
	)

	# Starve the idle pass the way a loaded machine does: physics keeps its own
	# cadence, so several physics iterations run before the next `_process()`.
	var authored_max_fps := Engine.max_fps
	Engine.max_fps = 10

	# Leave the seat through the piloted interact edge rather than by calling
	# `_try_exit_ship()` directly.
	# The seated interact edge is sampled by the ship's command source and drained
	# by GameFlow's idle pass, so with idle frames starved a single one-tick press
	# can fall between drains. A pilot leaving the seat presses until it takes.
	var exit_started := false
	for tick in 900:
		if tick % 2 == 0:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
		await physics_frame
		if bool(game.get("_transition_busy")) or game.phase == GameFlow.Phase.DISEMBARKING:
			exit_started = true
			break
	Input.action_release("interact")
	_check(exit_started, "a real interact press leaves the seat for the second time")
	var exited := false
	for _frame in 900:
		await physics_frame
		if (
			not bool(game.get("_transition_busy"))
			and not bool(game.get("_piloting"))
			and not player.is_seated()
		):
			exited = true
			break
	_check(exited, "the second disembark completes")

	# Mash interact on every physics tick, exactly as a player leaving the seat
	# does. Record how the physics ticks interleave with idle frames so the leg
	# cannot report success from an ordering that never opened the window.
	var reboarded := false
	var idle_frames_seen: Dictionary = {}
	var max_physics_ticks_in_one_idle_frame := 0
	for tick in 24:
		if tick % 2 == 0:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
		await physics_frame
		var idle_frame := Engine.get_process_frames()
		idle_frames_seen[idle_frame] = int(idle_frames_seen.get(idle_frame, 0)) + 1
		max_physics_ticks_in_one_idle_frame = maxi(
			max_physics_ticks_in_one_idle_frame,
			int(idle_frames_seen[idle_frame])
		)
		if (
			game.phase != GameFlow.Phase.COMPLETE
			or bool(game.get("_transition_busy"))
			or bool(game.get("_piloting"))
			or player.is_seated()
			or arrow.is_piloted()
		):
			reboarded = true
			break
	Input.action_release("interact")
	Engine.max_fps = authored_max_fps

	_check(
		max_physics_ticks_in_one_idle_frame >= 2,
		"the mashed interacts really did land on physics ticks ahead of an idle refresh"
	)
	_check(
		not reboarded,
		"mashing the real interact action after a real exit never re-boards the suppressed Arrow"
	)


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
		print("SANDBOX_STALE_REBOARD_DEFECT_WITNESS_TEST_OK")
		quit(0)
	else:
		print("SANDBOX_STALE_REBOARD_DEFECT_WITNESS_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
