extends SceneTree

## Real-Main regression for an activity actor disappearing while the streamed
## Cinder generation is in its deferred-unload presentation envelope.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for Cinder actor-loss lifecycle testing")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)

	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var player := game.get_node_or_null(^"Player") as PlayerController
	var jovian := _ship_by_id(game, &"jovian_provisional")
	var arrow := _ship_by_id(game, &"arrow_provisional")
	_check(
		binding != null
		and bootstrap != null
		and player != null
		and jovian != null
		and arrow != null
		and jovian.supports_in_flight_cabin_access(),
		"fixture exposes the binding, Player, cabin-capable Jovian, and replacement Arrow"
	)
	if (
		binding == null
		or bootstrap == null
		or player == null
		or jovian == null
		or arrow == null
	):
		await _clean_up(game)
		_finish()
		return

	_check(
		bool(game.select_activity_kind(
			GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		).get("accepted", false)),
		"cargo is selected before the production activity interpretation locks"
	)
	game.active_ship = jovian
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	jovian.set_piloted(true)

	var anchor := LOCATION.get_anchor_position()
	var outward := (Vector3.ZERO - anchor).normalized()
	jovian.global_position = anchor + outward * 499.9
	game.call("_physics_process", 0.1)
	_check(
		await _wait_until(
			func() -> bool: return bootstrap.get_loaded_instance() != null,
			30
		),
		"one production caller sample commits the Cinder generation"
	)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	game.call("_physics_process", 0.5)
	_check(
		cluster != null
		and cluster.get_streaming_transition_snapshot().get("phase") == &"authored"
		and is_equal_approx(float(
			cluster.get_streaming_transition_snapshot().get("opacity", -1.0)
		), 1.0),
		"the committed generation reaches its authored presentation before departure"
	)

	var started := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var activity_generation := int(started.get("session_generation", -1))
	_check(
		bool(started.get("accepted", false))
		and started.get("state_id", &"") == &"active"
		and activity_generation == 1,
		"the real Jovian starts one current cargo activity generation"
	)

	jovian.global_position = anchor + outward * 650.1
	game.call("_physics_process", 0.1)
	var fading := cluster.get_streaming_transition_snapshot()
	_check(
		fading.get("phase") == &"fading_out"
		and float(fading.get("opacity", 0.0)) > 0.0
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"cargo remains current while Cinder begins its caller-physics fade-out"
	)

	var parent := game.get_parent()
	var cluster_id := cluster.get_instance_id()
	parent.remove_child(game)
	await process_frame
	_check(
		bootstrap.get_loaded_instance() == cluster
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"whole-Main detach freezes the same fading cluster and cargo generation"
	)
	parent.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	_check(
		bootstrap.get_loaded_instance() == cluster
		and cluster.get_instance_id() == cluster_id
		and int(game.get_active_activity_snapshot().get(
			"session_generation", -1
		)) == activity_generation,
		"re-entry restores the same cluster and exact active activity generation"
	)

	# This is the production cabin-unseat seam. Its activity terminal decision is
	# synchronous and precedes the awaited embodiment movement.
	game.call("_leave_seat_into_cabin")
	var unseated := game.get_active_activity_snapshot()
	_check(
		unseated.get("state_id", &"") == &"failed"
		and unseated.get("failure_reason", &"") == &"pilot_unseated"
		and int(unseated.get("session_generation", -1)) == activity_generation,
		"losing the pilot seat fails the exact current cargo generation after re-entry"
	)

	# The same policy applies to a different hull becoming active. The boarding
	# path terminates the replacement activity before assigning Arrow, then its
	# ordinary next-sortie reset leaves no stale terminal state on the new craft.
	_check(game.reset_active_activity(), "unseat failure resets before the hull-swap witness")
	game.set("_transition_busy", false)
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.active_ship = jovian
	jovian.set_piloted(true)
	var replacement_start := game.request_activity_start(
		GameFlow.CARGO_DELIVERY_ACTIVITY_ID
	)
	var replacement_generation := int(replacement_start.get("session_generation", -1))
	_check(
		bool(replacement_start.get("accepted", false))
		and replacement_start.get("state_id", &"") == &"active",
		"one replacement cargo generation starts on the original physical ship"
	)
	game.call("_board_ship", arrow)
	var swapped := game.get_active_activity_snapshot()
	_check(
		game.active_ship == arrow
		and swapped.get("state_id", &"") == &"idle"
		and not bool(swapped.get("running", true))
		and int(swapped.get("session_generation", -1)) > replacement_generation,
		"boarding a different hull terminates and resets the previous ship's generation"
	)

	# A replacement production actor at/above the hard retention bound hides the
	# generation on this tick; one subsequent still-outside tick owns retirement.
	var replacement_position := anchor + outward * 725.1
	var player_sample := {
		"available": true,
		"position": replacement_position,
		"actor_kind": &"player",
		"actor_instance_id": player.get_instance_id(),
	}
	var hidden_tick := binding.physics_tick_from_caller_sample(
		1.0 / 60.0,
		player_sample
	)
	var hidden := cluster.get_streaming_transition_snapshot()
	_check(
		bootstrap.get_loaded_instance() == cluster
		and hidden.get("phase") == &"fade_out_complete"
		and is_zero_approx(float(hidden.get("opacity", -1.0)))
		and not bool(hidden.get("retire_ready", true))
		and _first_transition(hidden_tick).is_empty(),
		"the >=725m replacement sample reaches hidden while retaining one confirmation tick"
	)
	var retirement_tick := binding.physics_tick_from_caller_sample(
		1.0 / 60.0,
		player_sample
	)
	var retirement := _first_transition(retirement_tick)
	_check(
		retirement.get("action", &"") == &"unload"
		and retirement.get("reason", &"") == &"unloaded"
		and bootstrap.get_loaded_instance() == null
		and not bool(game.get_active_activity_snapshot().get("running", true)),
		"the next still-outside tick retires Cinder without reviving terminal activity state"
	)

	await _clean_up(game)
	_finish()


func _ship_by_id(game: GameFlow, ship_id: StringName) -> HeroShip:
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == ship_id:
			return candidate
	return null


func _first_transition(result: Dictionary) -> Dictionary:
	var transitions := result.get("transitions", []) as Array
	return transitions[0] as Dictionary if not transitions.is_empty() else {}


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
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
		print("CINDER_STREAMING_ACTOR_LOSS_LIFECYCLE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print(
			"CINDER_STREAMING_ACTOR_LOSS_LIFECYCLE_TEST_FAILED: %s"
			% "; ".join(_failures)
		)
		quit(1)
