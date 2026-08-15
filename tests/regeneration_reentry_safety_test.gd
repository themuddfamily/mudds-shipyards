extends SceneTree

## Focused regressions for two lifecycle boundaries that can otherwise turn a
## reusable physical craft into stale GameFlow state: a regeneration deadline
## expiring while the whole Main subtree is detached, and an explicit reuse
## reset terminating a guided landing contract.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SHORT_DEADLINE_MSEC := 50

## Extra simulated frames every bounded wait is granted on top of the frames its
## nominal duration implies. A frame count, not a wall-clock grace: widening a
## sleep would hide the clock divergence described on [method _wait_until], while
## a frame budget removes it.
const FRAME_BUDGET_GRACE := 30

## Bound for the wait that lets the shortened regeneration deadline expire while
## Main is detached. Only an upper bound; the wait ends the moment the monotonic
## clock actually crosses the deadline.
const DETACHED_DEADLINE_TIMEOUT_SECONDS := 1.0

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_regeneration_across_whole_main_reentry()
	await _test_guided_mid_landing_reset_is_terminal()
	_finish()


func _test_regeneration_across_whole_main_reentry() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for regeneration re-entry")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var arrow := game.get_node_or_null("ArrowReconShip") as HeroShip
	_check(
		world != null and torrent != null and arrow != null and game.get_active_ship() == torrent,
		"fixture exposes an inactive Arrow beside the active guided Torrent"
	)
	if world == null or torrent == null or arrow == null:
		await _clean_up(game)
		return

	var arrow_id := arrow.get_instance_id()
	var original_arrow_id := arrow_id
	var berth_id := arrow.get_home_berth_id()
	var home_transform := world.get_berth_transform(berth_id)
	var berth := world.get_berth_node(berth_id) as ShipBerth
	_check(
		berth != null
		and berth.get_reservation_owner() == arrow
		and berth.get_occupant() == arrow,
		"inactive Arrow begins with its exact occupied home-berth lease"
	)
	if berth == null:
		await _clean_up(game)
		return

	arrow.apply_damage(arrow.maximum_hull + 1.0, arrow.global_position, Vector3.UP)
	await process_frame
	var initial_pending := _pending_entry(game, arrow_id)
	var initial_ship_reference := initial_pending.get("ship") as WeakRef
	_check(
		arrow.is_destroyed()
		and initial_ship_reference != null
		and initial_ship_reference.get_ref() == arrow,
		"destroyed inactive Arrow remains represented by one process-owned pending entry"
	)
	_check(
		berth.get_reservation_owner() == null and berth.get_occupant() == null,
		"inactive destruction releases Arrow's former occupied berth before regeneration"
	)

	# Keep the home pad unavailable when the deadline expires. This distinguishes
	# an expired process-owned attempt from a timer callback that resurrects a
	# craft while Main has no SceneTree.
	var temporary_occupant := Node3D.new()
	temporary_occupant.name = "RegenerationReentryBerthOccupant"
	game.add_child(temporary_occupant)
	var temporary_token := berth.try_reserve(
		temporary_occupant,
		arrow.get_ship_definition()
	)
	_check(
		not temporary_token.is_empty()
		and berth.occupy(temporary_occupant, temporary_token),
		"compatible stand-in occupies the released Arrow berth"
	)

	var short_ready_at := Time.get_ticks_msec() + SHORT_DEADLINE_MSEC
	_check(
		_set_pending_ready_at(game, arrow_id, short_ready_at),
		"pending regeneration deadline can be shortened without replacing its ship reference"
	)
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	# `ready_at_msec` is a monotonic wall-clock deadline owned by GameFlow, but a
	# `SceneTree` timer counts Godot's smoothed engine delta, which is a different
	# clock. Under parallel load the smoothed delta runs *ahead* of the monotonic
	# clock while the engine catches up from a stall, so `create_timer(0.12)` was
	# observed firing when only ~42 ms of real time had passed and the 50 ms
	# deadline had therefore not expired. Wait for the deadline itself instead.
	var deadline_expired := await _wait_until(
		func() -> bool: return Time.get_ticks_msec() >= short_ready_at,
		DETACHED_DEADLINE_TIMEOUT_SECONDS
	)
	_check(
		deadline_expired,
		"the shortened regeneration deadline really expires while Main is detached"
	)

	var detached_entry := _pending_entry(game, arrow_id)
	var detached_ship_reference := detached_entry.get("ship") as WeakRef
	_check(
		not game.is_inside_tree()
		and Time.get_ticks_msec() >= short_ready_at
		and arrow.is_destroyed()
		and int(detached_entry.get("ready_at_msec", -1)) == short_ready_at
		and detached_ship_reference != null
		and detached_ship_reference.get_ref() == arrow,
		"expired deadline stays unchanged and pending while the whole Main subtree is detached"
	)
	_check(
		berth.get_reservation_owner() == temporary_occupant
		and berth.get_occupant() == temporary_occupant,
		"detached countdown performs no callback or berth mutation"
	)

	var readded_at := Time.get_ticks_msec()
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var retry_entry := _pending_entry(game, arrow_id)
	var retry_ready_at := int(retry_entry.get("ready_at_msec", 0))
	_check(
		game.is_inside_tree()
		and arrow.is_destroyed()
		and not retry_entry.is_empty()
		and retry_ready_at > readded_at + 1000
		and retry_ready_at <= Time.get_ticks_msec() + 2200,
		"first re-entry process attempt observes the occupied berth and schedules one future retry"
	)
	_check(
		berth.get_reservation_owner() == temporary_occupant
		and berth.get_occupant() == temporary_occupant,
		"expired regeneration cannot replace the berth's live occupant after re-entry"
	)

	_check(
		berth.release(temporary_occupant, temporary_token),
		"stand-in releases the same opaque berth lease after the re-entry attempt"
	)
	var final_ready_at := Time.get_ticks_msec() + SHORT_DEADLINE_MSEC
	_check(
		_set_pending_ready_at(game, arrow_id, final_ready_at),
		"occupied-berth retry can be shortened while preserving the pending identity"
	)
	var regenerated := await _wait_until(
		func() -> bool: return not arrow.is_destroyed(),
		1.0
	)
	var pending_after := game.get("_regeneration_pending") as Dictionary
	var regenerated_token := berth.get_reservation_token(arrow)
	_check(regenerated, "Arrow regenerates once its home berth becomes available")
	_check(
		regenerated
		and arrow.get_instance_id() == original_arrow_id
		and arrow.global_transform.is_equal_approx(home_transform)
		and arrow.is_boardable(),
		"regeneration reuses the exact Arrow instance at its exact home transform"
	)
	_check(
		regenerated
		and not regenerated_token.is_empty()
		and berth.has_valid_lease(arrow, regenerated_token, arrow.get_ship_id())
		and berth.get_reservation_owner() == arrow
		and berth.get_occupant() == arrow,
		"regenerated Arrow owns one valid occupied home-berth lease"
	)
	_check(
		not pending_after.has(arrow_id),
		"successful re-entry regeneration clears the pending lifecycle entry"
	)

	await _clean_up(game)


func _test_guided_mid_landing_reset_is_terminal() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for guided reset polling")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var opponent := game.get_node_or_null("RangeOpponent") as RangeOpponent
	_check(
		world != null and torrent != null and opponent != null,
		"guided reset fixture exposes the production ship, opponent, and berth registry"
	)
	if world == null or torrent == null or opponent == null:
		await _clean_up(game)
		return

	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.disembarking_motion_time = 0.02
	game.start_shift()
	await process_frame
	game.call("_board_ship", torrent)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
			0.8
		),
		"guided Torrent reaches one authoritative pilot seat"
	)

	torrent.engine_start_time = 0.01
	torrent.request_engine_start()
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.LAUNCH,
			0.5
		),
		"guided Torrent reaches the launch phase"
	)
	Input.action_press(&"move_forward")
	var departed := await _wait_until(
		func() -> bool: return bool(game.get("_sortie_departed_berth")),
		1.0
	)
	Input.action_release(&"move_forward")
	await physics_frame
	_check(departed, "physical thrust releases the guided Torrent's parked berth")

	game.destroyed_targets = game.total_targets
	game.call("_begin_interceptor_engagement")
	await process_frame
	opponent.apply_damage(opponent.maximum_health + 1.0, opponent.global_position)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.RETURN_TO_YARD,
			0.5
		),
		"guided victory reaches RETURN_TO_YARD before the reset probe"
	)

	var berth_id := torrent.get_home_berth_id()
	var berth := world.get_berth_node(berth_id) as ShipBerth
	var dock_transform := world.get_berth_transform(berth_id)
	if berth == null:
		_check(false, "guided Torrent home berth exists")
		await _clean_up(game)
		return
	torrent.global_transform = dock_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	torrent.velocity = Vector3.ZERO
	await physics_frame
	game.call("_try_request_landing")
	var landing_token := berth.get_reservation_token(torrent)
	var abort_reasons := PackedStringArray()
	torrent.landing_aborted.connect(
		func(reason: StringName) -> void: abort_reasons.append(reason)
	)
	_check(
		torrent.is_landing_active()
		and bool(game.get("_landing_request_active"))
		and game.get("_active_landing_berth_id") == berth_id
		and not landing_token.is_empty()
		and berth.has_valid_lease(torrent, landing_token, torrent.get_ship_id())
		and berth.get_reservation_owner() == torrent
		and berth.get_occupant() == null,
		"guided mid-landing fixture owns one exact pending berth lease"
	)

	torrent.reset_for_reuse(dock_transform)
	var reset_report := torrent.get_landing_contract_report()
	var berth_tokens := game.get("_berth_tokens") as Dictionary
	var reserved_berths := game.get("_reserved_berth_ids") as Dictionary
	_check(
		abort_reasons == PackedStringArray([&"reset_for_reuse"])
		and not torrent.is_landing_active()
		and bool(torrent.get_telemetry().get("landed", false)),
		"reset_for_reuse terminates the active assist once and restores a parked craft"
	)
	_check(
		berth.get_reservation_owner() == null
		and berth.get_occupant() == null
		and berth.get_reservation_token(torrent).is_empty()
		and not berth.has_valid_lease(torrent, landing_token, torrent.get_ship_id())
		and not berth_tokens.has(torrent.get_instance_id())
		and not reserved_berths.has(torrent.get_instance_id()),
		"mid-landing reset releases the exact lease and clears GameFlow's lease indexes"
	)
	_check(
		not bool(reset_report.get("active", true))
		and not bool(reset_report.get("contract_accepted", true))
		and not bool(reset_report.get("strict_dock_acceptance", true))
		and (reset_report.get("berth_id", &"unexpected") as StringName).is_empty()
		and not bool(reset_report.get("reservation_token_bound", true)),
		"reuse reset clears every strict landing-contract authority field"
	)
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD
		and not bool(game.get("_landing_request_active"))
		and (game.get("_active_landing_berth_id") as StringName).is_empty()
		and not bool(game.get("_return_registered")),
		"landing abort leaves RETURN_TO_YARD pending with no completion latch"
	)

	var crossed_completion_gate := false
	for _poll in 12:
		game.call("_update_pilot_flow")
		crossed_completion_gate = crossed_completion_gate or game.phase in [
			GameFlow.Phase.SHUT_DOWN,
			GameFlow.Phase.COMPLETE,
		]
		await process_frame
	_check(
		not crossed_completion_gate
		and game.phase == GameFlow.Phase.RETURN_TO_YARD
		and not bool(game.get("_return_registered"))
		and not game.is_guided_activity_complete(),
		"landed-state polling cannot advance reset RETURN_TO_YARD through SHUT_DOWN or COMPLETE"
	)

	await _clean_up(game)


func _pending_entry(game: GameFlow, instance_id: int) -> Dictionary:
	var pending := game.get("_regeneration_pending") as Dictionary
	var entry_value: Variant = pending.get(instance_id, {})
	return entry_value as Dictionary if entry_value is Dictionary else {}


func _set_pending_ready_at(game: GameFlow, instance_id: int, ready_at_msec: int) -> bool:
	var pending := game.get("_regeneration_pending") as Dictionary
	if not pending.has(instance_id):
		return false
	var entry_value: Variant = pending.get(instance_id)
	if entry_value is not Dictionary:
		return false
	var entry := (entry_value as Dictionary).duplicate()
	var ship_reference := entry.get("ship") as WeakRef
	if ship_reference == null or ship_reference.get_ref() == null:
		return false
	entry["ready_at_msec"] = ready_at_msec
	pending[instance_id] = entry
	game.set("_regeneration_pending", pending)
	return true


## Waits for `predicate` on the simulation clock instead of the wall clock.
##
## Three clocks run in this process and they diverge under parallel load: the
## monotonic clock behind `Time.get_ticks_msec()`, Godot's smoothed engine delta
## behind `SceneTree` timers, and the physics clock, whose steps the engine drops
## on a busy machine rather than letting the simulation spiral. A wall-clock-only
## deadline therefore abandons a condition that is still progressing perfectly
## well, which is a false failure rather than a defect.
##
## `timeout_seconds` is kept as the *nominal* duration and is now converted into
## a budget of simulated frames as well. The wait gives up only once both budgets
## are spent, so it stays bounded and a genuinely stuck condition still fails,
## but a merely slow box is given the same number of simulated frames as an idle
## one. Both `physics_frame` and `process_frame` are awaited each iteration so
## conditions owned by either loop make progress.
func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(timeout_seconds * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(timeout_seconds * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _clean_up(game: Node) -> void:
	Input.action_release(&"move_forward")
	if is_instance_valid(game):
		await _release_combat_audio_before_main_teardown(game)
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
	if combat_audio == null:
		return
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		player.stop()
		player.stream_paused = false
		player.stream = null
	# Give both the scene loop and audio backend a bounded boundary in which to
	# release the final explosion playback before the presentation bank is freed.
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
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
		print("REGENERATION_REENTRY_SAFETY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("REGENERATION_REENTRY_SAFETY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
