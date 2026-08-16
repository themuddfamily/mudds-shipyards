extends SceneTree

## Regression coverage for command consumers rather than producers. These probes
## deliberately exercise the production HeroShip and GameFlow paths so FIFO,
## replay, focus, and whole-tree lifecycle guarantees cannot be satisfied by a
## source-only unit test.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HERO_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ShipCommandType := preload("res://scripts/control/ship_command.gd")

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until] for why every wait in this suite is budgeted in frames.
const FRAME_BUDGET_GRACE := 30

var _failures := PackedStringArray()
var _assertions := 0


class ReplayCommandSource:
	extends ShipCommandSource

	var commands: Array[ShipCommand] = []
	var cursor := 0

	func next_command(_timestamp_usec: int = -1) -> ShipCommand:
		if commands.is_empty():
			return ShipCommand.neutral()
		var index := mini(cursor, commands.size() - 1)
		cursor += 1
		return ShipCommand.from_dictionary(commands[index].to_dictionary())


class MutableCommandSource:
	extends ShipCommandSource

	var values: Dictionary = {}

	func _sample_controls() -> Dictionary:
		return values.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_hero_camera_edges_are_ordered_exactly_once()
	await _test_game_flow_lossless_lifecycle_delivery()
	_finish()


func _test_hero_camera_edges_are_ordered_exactly_once() -> void:
	var stage := Node3D.new()
	stage.name = "CameraConsumerStage"
	root.add_child(stage)
	var ship := HERO_SCENE.instantiate() as HeroShip
	_check(ship != null, "production HeroShip instantiates for camera replay probes")
	if ship == null:
		stage.queue_free()
		await process_frame
		return
	stage.add_child(ship)
	await process_frame
	ship.set_piloted(true)
	var midpoint := (
		ship.minimum_chase_camera_distance + ship.maximum_chase_camera_distance
	) * 0.5
	ship.set_chase_camera_distance(midpoint)

	var repeated := ReplayCommandSource.new()
	repeated.name = "RepeatedCameraSnapshotSource"
	repeated.commands = [
		_command(3, 17, {"camera_distance_delta": 1.0}),
		_command(3, 17, {"camera_distance_delta": 1.0}),
		_command(3, 18, {"camera_toggle": true}),
		_command(3, 18, {"camera_toggle": true}),
	]
	stage.add_child(repeated)
	ship.set_command_source(repeated)
	repeated.reset_stream(0, -1, 3)
	ship.call("_physics_process", 1.0 / 60.0)
	var after_first_distance := ship.get_chase_camera_distance()
	ship.call("_physics_process", 1.0 / 60.0)
	_check(
		is_equal_approx(
			after_first_distance,
			midpoint + ship.chase_camera_zoom_step
		)
		and is_equal_approx(ship.get_chase_camera_distance(), after_first_distance),
		"identical stream 3 sequence 17 camera-distance snapshots on separate ticks apply once"
	)
	ship.call("_physics_process", 1.0 / 60.0)
	var view_after_first_toggle := ship.get_camera_view()
	ship.call("_physics_process", 1.0 / 60.0)
	_check(
		view_after_first_toggle == &"COCKPIT"
		and ship.get_camera_view() == view_after_first_toggle,
		"a replayed ordered camera-toggle snapshot cannot toggle the production view twice"
	)

	# Replacing the producer is not permission to move the ship's replay cursor
	# backwards. A genuinely newer epoch from a replacement remains usable.
	ship.set_cockpit_view(false)
	var older_replacement := ReplayCommandSource.new()
	older_replacement.name = "OlderReplacementSource"
	older_replacement.commands = [
		_command(2, 999, {"camera_distance_delta": -1.0}),
	]
	stage.add_child(older_replacement)
	ship.set_command_source(older_replacement)
	var before_old_replacement := ship.get_chase_camera_distance()
	ship.call("_physics_process", 1.0 / 60.0)
	_check(
		is_equal_approx(ship.get_chase_camera_distance(), before_old_replacement),
		"source-instance replacement cannot make an older camera epoch current"
	)
	var newer_replacement := ReplayCommandSource.new()
	newer_replacement.name = "NewerReplacementSource"
	newer_replacement.commands = [
		_command(4, 0, {"camera_distance_delta": -1.0}),
	]
	stage.add_child(newer_replacement)
	ship.set_command_source(newer_replacement)
	ship.call("_physics_process", 1.0 / 60.0)
	_check(
		is_equal_approx(
			ship.get_chase_camera_distance(),
			before_old_replacement - ship.chase_camera_zoom_step
		),
		"source-instance replacement continues normally with a newer camera epoch"
	)

	# A command may already have been returned to a deterministic tool when focus,
	# pause, pilot authority, or tree state invalidates its source. No newer sample
	# is required to revoke it: the source epoch itself is the active fence.
	var boundary_source := MutableCommandSource.new()
	boundary_source.name = "CapturedCameraBoundarySource"
	boundary_source.values = {"camera_distance_delta": 1.0}
	stage.add_child(boundary_source)
	ship.set_command_source(boundary_source)
	boundary_source.reset_stream(0, -1, 20)
	var captured_camera := boundary_source.next_command(2000)
	var before_captured_camera := ship.get_chase_camera_distance()
	boundary_source.invalidate_pending_commands()
	var captured_applied := ship.consume_sampled_camera_edges(captured_camera)
	_check(
		captured_camera.camera_distance_delta > 0.0
		and not captured_applied
		and is_equal_approx(
			ship.get_chase_camera_distance(),
			before_captured_camera
		),
		"source invalidation revokes a captured direct camera command before any newer sample"
	)

	# The final representable pair can be returned once, but if a caller delays it
	# beyond the source's terminal next request the exhausted source accepts no old
	# direct command and never aliases the epoch/sequence space.
	boundary_source.reset_stream(
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER,
		-1,
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
	)
	var terminal_camera := boundary_source.next_command(2001)
	var exhausted_neutral := boundary_source.next_command(2002)
	var before_terminal_replay := ship.get_chase_camera_distance()
	var terminal_applied := ship.consume_sampled_camera_edges(terminal_camera)
	_check(
		terminal_camera.camera_distance_delta > 0.0
		and boundary_source.is_stream_exhausted()
		and exhausted_neutral.is_neutral()
		and not terminal_applied
		and is_equal_approx(
			ship.get_chase_camera_distance(),
			before_terminal_replay
		),
		"exhausted camera source fails closed without replaying its captured terminal pair"
	)

	# Direct flight effects share one freshness fence, not only camera and lifecycle
	# edges. Fresh held fire remains meaningful on each increasing sequence; an
	# identical or rolled-back snapshot cannot reapply look, fire, or barrel roll.
	ship.engine_start_time = 0.0
	ship.request_engine_start()
	ship.call("_update_engine", 0.01)
	ship.set("_landed", false)
	ship.set("_docked_latch", false)
	ship.velocity = Vector3.ZERO
	var projectile_count := [0]
	ship.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		projectile_count[0] += 1
	)
	var duplicate_effect_source := ReplayCommandSource.new()
	duplicate_effect_source.name = "DuplicateDirectEffectSource"
	stage.add_child(duplicate_effect_source)
	ship.set_command_source(duplicate_effect_source)
	var duplicate_epoch := duplicate_effect_source.get_stream_id()
	var duplicate_effect := _command(duplicate_epoch, 5, {
		"look_yaw_delta": 0.5,
		"fire": true,
	})
	duplicate_effect_source.commands = [duplicate_effect, duplicate_effect]
	var basis_before_effect := ship.global_basis
	ship.call("_physics_process", ship.weapon_cooldown + 0.01)
	var basis_after_first_effect := ship.global_basis
	var shots_after_first_effect := int(projectile_count[0])
	ship.set("_weapon_timer", 0.0)
	ship.call("_physics_process", ship.weapon_cooldown + 0.01)
	_check(
		not basis_after_first_effect.is_equal_approx(basis_before_effect)
		and ship.global_basis.is_equal_approx(basis_after_first_effect)
		and shots_after_first_effect == 1
		and projectile_count[0] == shots_after_first_effect
		and ship.get_last_ship_command().is_neutral(),
		"an identical direct snapshot applies look and fire once, then is neutralized before every consumer"
	)

	var duplicate_roll_source := ReplayCommandSource.new()
	duplicate_roll_source.name = "DuplicateBarrelRollSource"
	stage.add_child(duplicate_roll_source)
	ship.set_command_source(duplicate_roll_source)
	var roll_epoch := duplicate_roll_source.get_stream_id()
	var duplicate_roll := _command(roll_epoch, 0, {"barrel_roll": true})
	duplicate_roll_source.commands = [duplicate_roll, duplicate_roll]
	ship.set("_roll_animation", 0.0)
	ship.call("_physics_process", 0.01)
	var first_roll_remaining := float(ship.get("_roll_animation"))
	ship.set("_roll_animation", 0.0)
	ship.call("_physics_process", 0.01)
	_check(
		first_roll_remaining > 0.0
		and is_zero_approx(float(ship.get("_roll_animation"))),
		"a completed barrel roll cannot be restarted by replaying its exact command pair"
	)

	var fresh_held_source := ReplayCommandSource.new()
	fresh_held_source.name = "FreshHeldFireSource"
	stage.add_child(fresh_held_source)
	ship.set_command_source(fresh_held_source)
	var held_epoch := fresh_held_source.get_stream_id()
	fresh_held_source.commands = [
		_command(held_epoch, 0, {"fire": true}),
		_command(held_epoch, 1, {"fire": true}),
	]
	var shots_before_fresh_hold := int(projectile_count[0])
	ship.call("_physics_process", ship.weapon_cooldown + 0.01)
	ship.call("_physics_process", ship.weapon_cooldown + 0.01)
	_check(
		projectile_count[0] == shots_before_fresh_hold + 2
		and ship.get_last_ship_command().fire
		and ship.get_last_ship_command().sequence == 1,
		"held fire remains active on every genuinely fresh increasing command sequence"
	)

	var rollback_source := ReplayCommandSource.new()
	rollback_source.name = "RolledBackDirectEffectSource"
	stage.add_child(rollback_source)
	ship.set_command_source(rollback_source)
	var rolled_back_epoch := maxi(0, held_epoch - 1)
	rollback_source.commands = [_command(rolled_back_epoch, 999, {
		"throttle": 1.0,
		"look_yaw_delta": -0.5,
		"fire": true,
		"barrel_roll": true,
	})]
	var basis_before_rollback := ship.global_basis
	var shots_before_rollback := int(projectile_count[0])
	ship.set("_roll_animation", 0.0)
	ship.set("_weapon_timer", 0.0)
	ship.call("_physics_process", ship.weapon_cooldown + 0.01)
	_check(
		ship.global_basis.is_equal_approx(basis_before_rollback)
		and projectile_count[0] == shots_before_rollback
		and is_zero_approx(float(ship.get("_roll_animation")))
		and is_zero_approx(float(ship.get_telemetry().throttle))
		and ship.get_last_ship_command().is_neutral(),
		"an older replacement epoch cannot steer, thrust, look, fire, roll, or affect the direct snapshot"
	)

	stage.queue_free()
	await process_frame
	await physics_frame


func _test_game_flow_lossless_lifecycle_delivery() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for lifecycle delivery probes")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.0
	game.disembarking_motion_time = 0.0
	game.start_shift()
	await process_frame
	var ship := game.get_node_or_null("ArrowReconShip") as HeroShip
	_check(ship != null, "lifecycle fixture resolves a production fleet ship")
	if ship == null:
		await _clean_up(game)
		return
	game.call("_board_ship", ship)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
			0.8
		),
		"lifecycle fixture reaches live seated START_ENGINES authority"
	)
	var source := ship.get_command_source() as LocalShipInputSource
	_check(
		source != null
		and source.has_method(&"drain_pending_commands")
		and source.has_method(&"invalidate_pending_commands"),
		"production local source exposes ordered drain and boundary invalidation"
	)
	if source == null or not source.has_method(&"drain_pending_commands"):
		await _clean_up(game)
		return

	# Stop automatic callbacks while retaining a live, processable source. This
	# lets the probe create two exact physics samples before one delayed idle poll.
	game.set_process(false)
	ship.set_physics_process(false)
	source.call(&"invalidate_pending_commands")
	game.call("_reset_lifecycle_command_cursor")
	ship.engine_start_time = 5.0
	var starting_count := [0]
	ship.engine_state_changed.connect(func(state: StringName) -> void:
		if state == HeroShip.ENGINE_STARTING:
			starting_count[0] += 1
	)

	source.queue_action_edge(&"engine_start")
	ship.call("_physics_process", 1.0 / 60.0)
	var edge_sample := ship.get_last_ship_command()
	ship.call("_physics_process", 1.0 / 60.0)
	var neutral_sample := ship.get_last_ship_command()
	_check(
		edge_sample.engine_start
		and neutral_sample.sequence > edge_sample.sequence
		and not neutral_sample.engine_start
		and str(ship.get_telemetry().engine_state) == "OFFLINE",
		"edge sequence 1 can be followed by neutral sequence 2 before GameFlow polls"
	)
	game.call("_consume_active_ship_command_edges")
	_check(
		str(ship.get_telemetry().engine_state) == "STARTING"
		and starting_count[0] == 1,
		"ordered FIFO delivery preserves and consumes the overwritten lifecycle edge once"
	)
	game.call("_consume_active_ship_command_edges")
	_check(
		starting_count[0] == 1,
		"an empty later idle drain cannot replay an already consumed lifecycle edge"
	)
	ship.request_engine_stop(false)

	# A command already sampled by HeroShip is still pending for GameFlow. Focus
	# loss must invalidate that side-channel before it can start the engines.
	source.queue_action_edge(&"engine_start")
	ship.call("_physics_process", 1.0 / 60.0)
	_check(ship.get_last_ship_command().engine_start, "focus probe stages one pending engine edge")
	source.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.call("_consume_active_ship_command_edges")
	_check(
		str(ship.get_telemetry().engine_state) == "OFFLINE"
		and starting_count[0] == 1,
		"focus-out invalidation rejects a sampled but not-yet-dispatched engine edge"
	)
	source.notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# Exercise the direct compatibility seam rather than the FIFO drain. Invalidate
	# after capture and call the consumer before any newer command is sampled; the
	# live source epoch alone must reject the stale start edge.
	source.queue_action_edge(&"engine_start")
	var captured_lifecycle := source.next_command(3000)
	var starts_before_direct_replay := int(starting_count[0])
	source.invalidate_pending_commands()
	game.call("_consume_active_ship_command", captured_lifecycle)
	_check(
		captured_lifecycle.engine_start
		and str(ship.get_telemetry().engine_state) == "OFFLINE"
		and starting_count[0] == starts_before_direct_replay,
		"source invalidation revokes a captured direct lifecycle command before any newer sample"
	)

	# A packet cannot establish an epoch merely by claiming a larger number than
	# the active producer. Only that producer's current ledger is authoritative.
	# Rejection must leave the lifecycle cursor unpoisoned, and a later boundary
	# must continue to reject the same captured packet.
	var source_epoch_before_future := source.get_stream_id()
	var lifecycle_cursor_before_future := Vector2i(
		int(game.get("_last_lifecycle_command_stream_id")),
		int(game.get("_last_lifecycle_command_sequence"))
	)
	var future_lifecycle := _command(
		source_epoch_before_future + 50,
		0,
		{"engine_start": true}
	)
	var starts_before_future := int(starting_count[0])
	game.call("_consume_active_ship_command", future_lifecycle)
	var cursor_after_future := Vector2i(
		int(game.get("_last_lifecycle_command_stream_id")),
		int(game.get("_last_lifecycle_command_sequence"))
	)
	source.invalidate_pending_commands()
	game.call("_consume_active_ship_command", future_lifecycle)
	_check(
		future_lifecycle.engine_start
		and int(starting_count[0]) == starts_before_future
		and str(ship.get_telemetry().engine_state) == "OFFLINE"
		and cursor_after_future == lifecycle_cursor_before_future
		and Vector2i(
			int(game.get("_last_lifecycle_command_stream_id")),
			int(game.get("_last_lifecycle_command_sequence"))
		) == lifecycle_cursor_before_future,
		"a future-epoch lifecycle packet is unauthorized, cannot poison the cursor, and remains revoked after a boundary"
	)

	# The same direct-consumer fence fails closed when the active source has used
	# its final representable epoch/sequence pair.
	var exhaustion_source := LocalShipInputSource.new()
	exhaustion_source.name = "ExhaustedLifecycleInputSource"
	game.add_child(exhaustion_source)
	ship.set_command_source(exhaustion_source)
	exhaustion_source.reset_stream(
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER,
		-1,
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
	)
	exhaustion_source.queue_action_edge(&"engine_start")
	var terminal_lifecycle := exhaustion_source.next_command(3001)
	var exhausted_lifecycle_neutral := exhaustion_source.next_command(3002)
	game.call("_consume_active_ship_command", terminal_lifecycle)
	_check(
		terminal_lifecycle.engine_start
		and exhaustion_source.is_stream_exhausted()
		and exhausted_lifecycle_neutral.is_neutral()
		and str(ship.get_telemetry().engine_state) == "OFFLINE"
		and starting_count[0] == starts_before_direct_replay,
		"exhausted lifecycle source rejects its delayed terminal command and remains neutral"
	)
	ship.set_command_source(source)

	# Exact whole-Main reviewer repro: a sampled interact edge at START_ENGINES
	# must not survive removal and cause DISEMBARKING after the same tree is added.
	source.queue_action_edge(&"interact")
	ship.call("_physics_process", 1.0 / 60.0)
	var stale_interact := ship.get_last_ship_command()
	_check(
		stale_interact.interact and game.phase == GameFlow.Phase.START_ENGINES,
		"detach probe stages a pending interact edge while seated at START_ENGINES"
	)
	root.remove_child(game)
	root.add_child(game)
	game.set_process(false)
	ship.set_physics_process(false)
	game.call("_consume_active_ship_command_edges")
	_check(
		game.phase == GameFlow.Phase.START_ENGINES
		and ship.is_piloted()
		and not bool(game.get("_transition_busy")),
		"whole-Main detach invalidates stale interact instead of entering DISEMBARKING after re-entry"
	)

	# An older sampled edge may already be waiting when a deterministic tool asks
	# for immediate delivery. The synthetic sample must drain behind it, never jump
	# the cursor ahead and make the older command look stale. Start then stop makes
	# the FIFO order observable in both signal history and final engine state.
	source.queue_action_edge(&"engine_start")
	ship.call("_physics_process", 1.0 / 60.0)
	var pending_start := ship.get_last_ship_command()
	var synthetic_stop := InputEventAction.new()
	synthetic_stop.action = &"engine_stop"
	synthetic_stop.pressed = true
	game.call("_unhandled_input", synthetic_stop)
	_check(
		pending_start.engine_start
		and str(ship.get_telemetry().engine_state) == "OFFLINE"
		and starting_count[0] == 2,
		"synthetic InputEventAction drains an older edge first and still delivers immediately"
	)
	# Negative control: both edges were consumed before yielding. Their former
	# FIFO copies and a later detach cannot repeat either lifecycle transition.
	root.remove_child(game)
	root.add_child(game)
	game.set_process(false)
	ship.set_physics_process(false)
	game.call("_consume_active_ship_command_edges")
	_check(
		starting_count[0] == 2
		and str(ship.get_telemetry().engine_state) == "OFFLINE",
		"whole-Main re-entry cannot replay an edge already consumed before detachment"
	)

	# Source swaps revoke both the producer being left and the producer being
	# entered. Thus A -> B -> A cannot resurrect an undelivered edge still cached
	# in A, even though A remains a valid live Node throughout the round trip.
	ship.set_command_source(source)
	source.queue_action_edge(&"engine_start")
	ship.call("_physics_process", 1.0 / 60.0)
	_check(ship.get_last_ship_command().engine_start, "source-swap probe stages one edge in source A")
	var replacement_local := LocalShipInputSource.new()
	replacement_local.name = "ReplacementLocalInputSource"
	game.add_child(replacement_local)
	ship.set_command_source(replacement_local)
	ship.set_command_source(source)
	game.call("_consume_active_ship_command_edges")
	_check(
		str(ship.get_telemetry().engine_state) == "OFFLINE"
		and starting_count[0] == 2,
		"A to B to A source replacement cannot resurrect A's pending lifecycle backlog"
	)

	# Claim stream 10/sequence 7 while dispatch is disabled, then advance to a
	# newer epoch. Replaying the exact old edge after an actual source-instance
	# replacement must not move the lifecycle cursor backwards or start engines.
	var old_source := ReplayCommandSource.new()
	old_source.name = "OldLifecycleSource"
	var old_stream := maxi(
		int(ship.get("_last_direct_command_stream_id")),
		int(ship.get("_last_camera_command_stream_id"))
	) + 20
	var old_edge := _command(old_stream, 7, {"engine_start": true})
	old_source.commands = [old_edge]
	game.add_child(old_source)
	ship.set_command_source(old_source)
	old_source.reset_stream(0, -1, old_stream)
	game.call("_reset_lifecycle_command_cursor")
	game.phase = GameFlow.Phase.INTRO
	game.call("_consume_active_ship_command", old_edge)
	var new_source := ReplayCommandSource.new()
	new_source.name = "NewLifecycleSource"
	var new_stream := old_stream + 1
	var new_epoch := _command(new_stream, 0)
	new_source.commands = [new_epoch]
	game.add_child(new_source)
	ship.set_command_source(new_source)
	new_source.reset_stream(0, -1, new_stream)
	game.phase = GameFlow.Phase.START_ENGINES
	game.call("_consume_active_ship_command", new_epoch)
	ship.set_command_source(old_source)
	game.call("_consume_active_ship_command", old_edge)
	_check(
		str(ship.get_telemetry().engine_state) == "OFFLINE"
		and int(game.get("_last_lifecycle_command_stream_id")) == new_stream
		and int(game.get("_last_lifecycle_command_sequence")) == 0,
		"an older lifecycle epoch cannot reacquire authority after a newer epoch, even across source replacement"
	)

	await _clean_up(game)


func _command(stream_id: int, sequence: int, values: Dictionary = {}) -> ShipCommand:
	var data := values.duplicate(true)
	data["schema_version"] = ShipCommandType.SCHEMA_VERSION
	data["stream_id"] = stream_id
	data["sequence"] = sequence
	data["timestamp_usec"] = 1000 + sequence
	return ShipCommandType.from_dictionary(data)


## Waits for `predicate` on both the simulation clock and the monotonic clock,
## giving up only once both budgets are spent.
##
## Commands are drained and applied by `HeroShip` in `_physics_process`, so every
## condition this suite waits on advances only when a physics step actually runs.
## Under load Godot drops physics steps rather than letting the simulation
## spiral while the wall clock keeps running, so a `Time.get_ticks_msec()`-only
## deadline abandons a queue that is still being drained perfectly well — a false
## failure rather than a defect. `timeout_seconds` is kept as the *nominal*
## duration and becomes both a frame budget and a wall-clock deadline; both stay
## finite, so a consumer that genuinely never delivers still fails the suite.
func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _clean_up(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await physics_frame
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
		print("COMMAND_CONSUMER_DELIVERY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("COMMAND_CONSUMER_DELIVERY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
