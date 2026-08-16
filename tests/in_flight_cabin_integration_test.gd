extends SceneTree

## Production-scene integration regression for the whole in-flight cabin loop,
## driven through `res://scenes/main.tscn` with real player and pilot input:
## board, fly out, shut down in open space, leave the seat, walk the length of
## the hold while the hull drifts, get back in, and fly home to a real berth.
##
## `modern_interpretation`. This is a modern design decision about this fleet
## and asserts nothing about any historical craft.
##
## Behaviour groups, each with at least one structured-red mutation:
##
##   A. only a craft with a walkable cabin may release its pilot in space.
##      Red: the same shutdown-and-press-E on a fighter must refuse and leave
##      the pilot seated.
##   B. the cabin loop itself: exit, walk, carry, re-board, fly home, and survive
##      a whole-Main detach mid-walk. Red: the seat cannot be left while the
##      engine is still running, in space exactly as at a berth.
##   C. the pilot cannot be stranded. Red: release containment and the identical
##      displacement is not recovered.
##   D. losing the cabin itself falls through to the existing regeneration
##      recall rather than leaving an on-foot pilot in open space.
##
## Every wait is a bounded frame budget on the fixed physics step, cross-checked
## against a monotonic deadline. Nothing here sleeps on a wall clock.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FRAME_BUDGET_GRACE := 30
## Locomotion and thrust are driven until the world reaches a stated condition,
## never for a fixed number of ticks. The engine is free to run several physics
## steps per idle frame on a busy machine, so a fixed tick count is a distance
## that changes between runs; a bounded condition is not.
const LOCOMOTION_TICK_BUDGET := 400
const THRUST_TICK_BUDGET := 400

var _failures: Array[String] = []
var _assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production scene instantiates for the cabin loop")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as ArrowReconShip
	var jovian := game.get_node("JovianLightFreighter") as JovianLightFreighter
	var zenith := game.get_node("ZenithInterceptor") as HeroShip
	var opponent := game.get_node("RangeOpponent") as CharacterBody3D

	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.04
	game.disembarking_motion_time = 0.04
	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "the shift starts on foot with the Torrent guide pending")

	_check(
		not torrent.supports_in_flight_cabin_access()
		and not arrow.supports_in_flight_cabin_access()
		and not zenith.supports_in_flight_cabin_access()
		and jovian.supports_in_flight_cabin_access(),
		"only the craft with a connected walkable interior offers in-flight cabin access"
	)

	await _test_fighter_refuses_to_release_its_pilot(game, player, arrow, world)
	await _test_cabin_loop(game, player, jovian, world)
	await _test_losing_the_cabin_recovers_the_pilot(game, player, jovian, world)

	_check(
		not game.is_guided_activity_complete()
		and game.get_guided_ship() == torrent
		and game.destroyed_targets == 0
		and not bool(opponent.call("is_active")),
		"the whole cabin loop leaves the pending Torrent guided activity untouched"
	)

	await _clean_up(game)
	_finish()


# ---------------------------------------------------------------- group A ----


## Structured red for the "large craft only" decision, taken through the real
## handler rather than the contract: a fighter shut down in open space refuses
## the same key press and leaves its pilot in the seat.
func _test_fighter_refuses_to_release_its_pilot(
		game: GameFlow,
		player: PlayerController,
		fighter: HeroShip,
		world: ShipyardWorld
	) -> void:
	var berth_transform := world.get_berth_transform(fighter.get_home_berth_id())
	await _board_with_real_interaction(game, player, fighter)
	_check(
		game.phase == GameFlow.Phase.START_ENGINES and player.is_seated(),
		"the fighter takes a real E boarding interaction"
	)
	fighter.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	_check(
		await _wait_for_engine_state(fighter, "ONLINE", 0.6),
		"the fighter starts through the live pilot action path"
	)
	var fighter_clearance := await _thrust_clear_of_the_berth(fighter, 90.0)
	_check(
		fighter_clearance > 60.0 and not bool(fighter.get_telemetry().get("landed", true)),
		"the fighter really is away from its berth, in open space"
	)

	_dispatch_pilot_action(game, &"engine_stop")
	_check(
		await _wait_for_engine_state(fighter, "OFFLINE", 0.6),
		"the fighter shuts down in open space"
	)
	var phase_before := game.phase
	_dispatch_pilot_action(game, &"interact")
	for _refusal_tick in 30:
		await physics_frame
		await process_frame
	_check(
		game.phase == phase_before
		and game.phase != GameFlow.Phase.IN_FLIGHT_CABIN
		and player.is_seated()
		and fighter.is_piloted()
		and not player.is_cabin_containment_active(),
		"RED: a fighter shut down in space refuses the seat exit and keeps its pilot seated"
	)

	# Put the craft back where it belongs so the rest of the suite runs against a
	# clean yard. This is recovery, not the behaviour under test.
	fighter.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	fighter.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(fighter, "ONLINE", 0.6), "the fighter restarts for its return")
	_dispatch_pilot_action(game, &"landing_assist")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 6.0),
		"the fighter completes its physical berth return"
	)
	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(fighter, "OFFLINE", 0.6), "the fighter shuts down at its berth")
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 1.5),
		"the landed fighter still releases its pilot at a berth exactly as before"
	)


# --------------------------------------------------------- groups B and C ----


func _test_cabin_loop(
		game: GameFlow,
		player: PlayerController,
		jovian: JovianLightFreighter,
		world: ShipyardWorld
	) -> void:
	var berth_transform := world.get_berth_transform(jovian.get_home_berth_id())
	var frame := jovian.get_moving_interior_component()

	await _board_with_real_interaction(game, player, jovian)
	_check(
		game.phase == GameFlow.Phase.START_ENGINES and player.is_seated() and jovian.is_piloted(),
		"the freighter takes a real E boarding interaction"
	)
	jovian.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(jovian, "ONLINE", 0.6), "the freighter starts for the sortie")
	_check(await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, 0.6), "the freighter sortie is a free flight")

	var departure_distance := await _thrust_clear_of_the_berth(jovian, 120.0)
	_check(
		departure_distance > 100.0 and not bool(jovian.get_telemetry().get("landed", true)),
		"real W thrust flies the freighter clear of the yard"
	)

	# Structured red for the loop's precondition: the seat may only be left once
	# the craft is actually shut down, in space exactly as at a berth.
	var running_phase := game.phase
	_dispatch_pilot_action(game, &"interact")
	for _running_tick in 24:
		await physics_frame
		await process_frame
	_check(
		game.phase == running_phase
		and player.is_seated()
		and not player.is_cabin_containment_active(),
		"RED: the seat cannot be left in space while the engine is still running"
	)

	_dispatch_pilot_action(game, &"engine_stop")
	_check(
		await _wait_for_engine_state(jovian, "OFFLINE", 0.6),
		"real X shutdown works away from a berth, exactly as it already did"
	)
	for _prompt_tick in 6:
		await physics_frame
		await process_frame
	_check(
		_hud_interaction_text(game) == "[ E ]  LEAVE THE PILOT SEAT",
		"the pilot of a shut-down craft with a cabin is told the seat can be left"
	)

	# --- leave the seat -------------------------------------------------------
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_until(
			func() -> bool: return bool(game.get_in_flight_cabin_status().get("carried", false)),
			1.5
		),
		"real E leaves the pilot seat of a shut-down craft in open space"
	)
	var status := game.get_in_flight_cabin_status()
	_check(
		game.phase == GameFlow.Phase.IN_FLIGHT_CABIN
		and status.get("ship") == jovian
		and not player.is_seated()
		and player.is_control_enabled()
		and not jovian.is_piloted(),
		"the pilot is on foot, in control, aboard the craft they were flying"
	)
	_check(
		bool(status.get("carried", false)) and frame.is_occupant_registered(player),
		"the craft's own interior frame owns the new occupant"
	)
	_check(
		bool((status.get("containment", {}) as Dictionary).get("contained", false)),
		"the new occupant starts inside the craft's confinement envelope"
	)
	for _settle_tick in 8:
		await physics_frame
	var stand_local := jovian.to_local(player.global_position)
	_check(
		player.is_on_floor()
		and stand_local.distance_to(JovianLightFreighter.CABIN_STAND_LOCAL_ORIGIN) < 0.2,
		"the pilot arrives standing on the craft's own published cabin pose"
	)
	_check(
		(jovian.collision_mask & PhysicsLayers.PLAYER) == 0,
		"a crew member on the craft's own deck is not an obstacle to the craft's own hull"
	)
	# The on-foot readout used to be able to say only one thing, because on foot
	# used to mean only one place.
	var mode_text := str((game.get_node("HUD")._mode_label as Label).text)
	_check(
		mode_text.begins_with("ON FOOT")
		and mode_text.contains(jovian.get_display_name().to_upper())
		and not mode_text.contains("REGENERATION DECK"),
		"the readout says the pilot is on foot aboard the craft, not on the station deck"
	)

	# --- whole-Main detach and re-entry, mid-cabin ---------------------------
	# `MovingInteriorFrame` drops its occupants when it leaves the tree and Godot
	# does not call `_ready()` again, so an explicit registration has to be
	# restated on re-entry or the pilot silently stops being carried.
	var parent := game.get_parent()
	# Hold the hull still across the detach so this measures the re-entry
	# mechanics rather than however far a drifting hull travelled meanwhile. The
	# drifting case is exercised immediately below.
	jovian.velocity = Vector3.ZERO
	await physics_frame
	var detached_local := jovian.to_local(player.global_position)
	parent.remove_child(game)
	await process_frame
	_check(
		not frame.is_occupant_registered(player),
		"a detached interior frame really does drop its occupant"
	)
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	_check(
		game.phase == GameFlow.Phase.IN_FLIGHT_CABIN
		and frame.is_occupant_registered(player)
		and bool(game.get_in_flight_cabin_status().get("carried", false)),
		"re-entering the whole Main subtree restores the pilot's interior occupancy"
	)
	_check(
		bool(player.get_cabin_containment_report().get("contained", false))
		and jovian.to_local(player.global_position).distance_to(detached_local) < 0.35,
		"the pilot survives the detach in place, still confined to the cabin"
	)

	# --- walk the hold while the hull drifts ---------------------------------
	# A real drift, not a scripted one: the shut-down hull keeps the momentum it
	# had, and the pilot walks it while it travels.
	jovian.velocity = -jovian.global_basis.z * 9.0
	var hull_origin := jovian.global_position
	var reached_aft := await _walk_until(
		&"move_forward",
		false,
		func() -> bool: return jovian.to_local(player.global_position).z > 7.5
	)
	var hold_local := jovian.to_local(player.global_position)
	var hull_travel := jovian.global_position.distance_to(hull_origin)
	_check(hull_travel > 5.0, "the hull really is under way while the pilot walks it")
	_check(
		reached_aft and hold_local.z > 7.5 and player.is_on_floor(),
		"real locomotion walks the full length of the drifting hold, on the craft's own deck"
	)
	_check(
		hold_local.distance_to(JovianLightFreighter.CABIN_STAND_LOCAL_ORIGIN) > 14.0,
		"that walk really is the length of the hull, not a step off the seat"
	)
	_check(
		frame.is_occupant_registered(player)
		and bool(player.get_cabin_containment_report().get("contained", false)),
		"the walk keeps the occupant carried by the interior frame and inside the envelope"
	)

	# The interior frame, not the world, is what the occupant's floor and gravity
	# are resolved against while the hull travels.
	var hull_up := jovian.global_basis.y.normalized()
	var occupant_gravity: Vector3 = player.call("_get_effective_gravity")
	_check(
		player.up_direction.is_equal_approx(hull_up)
		and occupant_gravity.normalized().dot(-hull_up) > 0.999,
		"the walking occupant stands and falls along the craft's own up, not the world's"
	)

	# One lateral hull displacement, to show the occupant keeps their place
	# aboard rather than their place in the world.
	var carried_before := jovian.to_local(player.global_position)
	jovian.global_position += jovian.global_basis.x * 4.0
	# `SceneTree.physics_frame` fires before the node tree is stepped, so the
	# first await only reaches the start of the frame that will apply this.
	for _carry_tick in 2:
		await physics_frame
	var carried_after := jovian.to_local(player.global_position)
	print(
		"CABIN_OCCUPANT_CARRY: before=", carried_before,
		" after=", carried_after,
		" delta=", carried_after.distance_to(carried_before)
	)
	_check(
		carried_after.distance_to(carried_before) < 0.15,
		"an occupant keeps their exact place aboard when the hull moves under them"
	)

	# --- group C: the pilot cannot be stranded -------------------------------
	# Walk back into the aperture band, then drive at the one real opening in the
	# hull with real sprinting input, for as long as it would take to get out.
	# Stop between the two rows of secured freight, so the push at the aperture
	# is a clean run at the opening rather than a scrape past cargo.
	await _walk_until(
		&"move_back",
		false,
		func() -> bool: return jovian.to_local(player.global_position).z < 3.0
	)
	var reached_aperture := await _walk_until(
		&"move_right",
		true,
		func() -> bool: return jovian.to_local(player.global_position).x < -5.5
	)
	var pushed := player.get_cabin_containment_report()
	var pushed_local := jovian.to_local(player.global_position)
	_check(
		bool(pushed.get("contained", false))
		and pushed_local.x >= JovianLightFreighter.CABIN_MOVEMENT_BOUNDS.position.x,
		"sprinting at the open cargo aperture of a moving hull cannot put the pilot outside it"
	)
	_check(
		reached_aperture and int(pushed.get("clamp_count", 0)) > 0,
		"the pilot really does reach the aperture and is held at its threshold"
	)

	var recalls_before := int(player.get_cabin_containment_report().get("recall_count", 0))
	player.global_position += jovian.global_basis.x * -120.0
	for _recall_tick in 6:
		await physics_frame
	var recalled := player.get_cabin_containment_report()
	_check(
		bool(recalled.get("contained", false))
		and int(recalled.get("recall_count", 0)) > recalls_before
		and jovian.to_local(player.global_position).distance_to(
			JovianLightFreighter.CABIN_STAND_LOCAL_ORIGIN
		) < 0.2,
		"a pilot displaced clean outside the hull is returned to the cabin standing pose"
	)

	# Structured red: containment is the mechanism, not a coincidence.
	player.clear_cabin_containment()
	player.global_position += jovian.global_basis.x * -120.0
	for _escape_tick in 8:
		await physics_frame
	_check(
		not JovianLightFreighter.CABIN_MOVEMENT_BOUNDS.has_point(
			jovian.to_local(player.global_position)
		),
		"RED: with confinement released the identical displacement leaves the pilot outside the hull"
	)
	game._bind_cabin_occupancy(jovian)
	for _restore_tick in 6:
		await physics_frame
	_check(
		bool(player.get_cabin_containment_report().get("contained", false)),
		"restoring confinement recovers the pilot into the cabin"
	)

	# --- walk back to the cockpit and take the seat --------------------------
	var reached_cockpit := await _walk_until(
		&"move_back",
		false,
		func() -> bool: return jovian.to_local(player.global_position).z < -6.5
	)
	_check(
		reached_cockpit and player.is_on_floor(),
		"real locomotion walks back forward onto the flight deck"
	)
	_check(
		game.boarding_candidate == jovian
		and _hud_interaction_text(game) == "[ E ]  TAKE THE PILOT SEAT",
		"the seat is offered back from inside the cabin without walking away and back"
	)

	await _press_live_action(&"interact", 1)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 1.5),
		"one real E press retakes the pilot seat"
	)
	_check(
		player.is_seated() and jovian.is_piloted()
		and not player.is_cabin_containment_active()
		and not frame.is_occupant_registered(player),
		"retaking the seat releases both the confinement and the interior occupancy"
	)
	_check(
		(jovian.collision_mask & PhysicsLayers.PLAYER) != 0,
		"an empty cabin restores the craft's full hull collision mask"
	)

	# --- fly home ------------------------------------------------------------
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(jovian, "ONLINE", 0.6), "the freighter restarts after the cabin walk")
	_check(await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, 0.6), "the sortie resumes in free flight")
	jovian.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	jovian.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 6.0),
		"the freighter completes its physical freight-berth return after the cabin walk"
	)
	_check(
		jovian.global_transform.is_equal_approx(berth_transform),
		"the return restores the berth's exact origin and basis"
	)
	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(jovian, "OFFLINE", 0.6), "the freighter shuts down at its berth")
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 1.5),
		"the landed exit still puts the pilot back on the regeneration deck"
	)
	_check(
		not player.is_seated()
		and player.is_control_enabled()
		and not player.is_cabin_containment_active()
		and jovian.is_boardable(),
		"the loop ends with a free pilot and a reusable craft"
	)


# ---------------------------------------------------------------- group D ----


## The outer safety net. Everything above keeps the pilot inside a hull that
## exists; this covers the hull ceasing to exist while they are walking it, which
## is the one remaining way an on-foot pilot could be left in open space.
func _test_losing_the_cabin_recovers_the_pilot(
		game: GameFlow,
		player: PlayerController,
		jovian: JovianLightFreighter,
		world: ShipyardWorld
	) -> void:
	var frame := jovian.get_moving_interior_component()
	await _board_with_real_interaction(game, player, jovian)
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(jovian, "ONLINE", 0.6), "the freighter restarts for the loss case")
	var clearance := await _thrust_clear_of_the_berth(jovian, 90.0)
	_check(clearance > 60.0, "the freighter is well clear of the yard for the loss case")
	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(jovian, "OFFLINE", 0.6), "the freighter shuts down for the loss case")
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_until(
			func() -> bool: return bool(game.get_in_flight_cabin_status().get("carried", false)),
			1.5
		),
		"the pilot is walking the cabin again, far from the yard"
	)

	jovian.apply_damage(jovian.maximum_hull + 1.0, jovian.global_position, Vector3.UP)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 2.0),
		"losing the cabin under way runs the existing regeneration recall"
	)
	_check(
		not frame.is_occupant_registered(player)
		and not player.is_cabin_containment_active(),
		"the lost cabin releases both the interior occupancy and the confinement"
	)
	_check(
		player.is_control_enabled()
		and not player.is_seated()
		and player.global_position.distance_to(world.get_player_spawn().origin) < 3.0,
		"the pilot is recalled to the regeneration deck rather than left in open space"
	)
	_check(
		await _wait_until(
			func() -> bool: return not jovian.is_destroyed() and jovian.is_boardable(),
			6.0
		),
		"the lost freighter regenerates at its berth and is flyable again"
	)


# --------------------------------------------------------------- helpers ----


func _board_with_real_interaction(
		game: GameFlow,
		player: PlayerController,
		candidate: HeroShip
	) -> void:
	# A landed exit deliberately suppresses re-boarding the craft just left until
	# the pilot walks away from it. Stand clear first and let the coordinator
	# retire that suppression through its own rule rather than reaching past it.
	player.teleport_to(Transform3D(
		candidate.global_basis.orthonormalized(),
		candidate.get_boarding_position()
			+ candidate.global_basis.y.normalized() * 0.05
			+ candidate.global_basis.x.normalized() * 20.0
	))
	for _stand_clear_tick in 4:
		await physics_frame
		await process_frame
	player.teleport_to(Transform3D(
		candidate.global_basis.orthonormalized(),
		candidate.get_boarding_position() + candidate.global_basis.y.normalized() * 0.05
	))
	player.set_control_enabled(true)
	for _approach_tick in 6:
		await physics_frame
		await process_frame
	await _press_live_action(&"interact", 1)
	await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 1.5)


## Applies real forward thrust until the craft is a stated distance clear of
## where it started, and reports how far it actually travelled.
func _thrust_clear_of_the_berth(craft: HeroShip, clearance: float) -> float:
	var origin := craft.global_position
	Input.action_press(&"move_forward")
	var ticks := 0
	while craft.global_position.distance_to(origin) < clearance and ticks < THRUST_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(&"move_forward")
	for _thrust_settle in 4:
		await physics_frame
		await process_frame
	return craft.global_position.distance_to(origin)


## Holds a locomotion action until `predicate` is satisfied, then releases it and
## lets the body settle. Returns whether the condition still holds after settling.
func _walk_until(
		action: StringName,
		sprint: bool,
		predicate: Callable,
		tick_budget: int = LOCOMOTION_TICK_BUDGET
	) -> bool:
	Input.action_press(action)
	if sprint:
		Input.action_press(&"sprint_boost")
	var ticks := 0
	while not bool(predicate.call()) and ticks < tick_budget:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	if sprint:
		Input.action_release(&"sprint_boost")
	for _settle_tick in 8:
		await physics_frame
		await process_frame
	return bool(predicate.call())


## The HUD exposes no reader for its prompt, so the live label is sampled
## directly. This asserts what the player is actually told, not what the
## coordinator believes it said.
func _hud_interaction_text(game: GameFlow) -> String:
	return str((game.get_node("HUD")._interaction_label as Label).text)


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _dispatch_pilot_action(game: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _wait_for_phase(game: GameFlow, expected_phase: int, timeout_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool: return game.phase == expected_phase,
		timeout_seconds
	)


func _wait_for_engine_state(craft: HeroShip, expected_state: String, timeout_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool:
			return str(craft.get_telemetry().get("engine_state", &"")).to_upper() == expected_state,
		timeout_seconds
	)


## Waits on both the simulation clock and the monotonic clock, giving up only
## once both budgets are spent, so a busy machine cannot fail a condition that is
## still progressing.
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


func _clean_up(game: Node) -> void:
	for action in [
		&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
		&"fire", &"engine_start", &"engine_stop", &"landing_assist", &"sprint_boost",
	]:
		Input.action_release(action)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("IN_FLIGHT_CABIN_INTEGRATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"IN_FLIGHT_CABIN_INTEGRATION_TEST_FAILED: %d/%d assertions failed: %s"
			% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
