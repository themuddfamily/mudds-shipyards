extends SceneTree

## Production-scene integration regression for the third physical flyable. This
## deliberately begins before the Torrent guide and uses the real player, ship,
## berth, command-source, combat-authority, and moving-interior paths.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const EXPECTED_JOVIAN_DOCK_ORIGIN := Vector3(-53.0, 1.63, 57.3)

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until] for why every wait in this suite is budgeted in frames.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "four-craft production scene instantiates")
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
	var combat_authority := game.get_combat_authority()
	var fleet: Array[HeroShip] = game.get_flyable_ships()

	_check(fleet.size() == 4, "main scene registers exactly four flyable craft")
	_check(fleet.has(torrent) and fleet.has(arrow) and fleet.has(jovian) and fleet.has(zenith), "fleet registry contains the four production hulls")
	_check(game.get_guided_ship() == torrent, "Torrent remains the explicit guided-activity craft")

	var ship_ids: Dictionary = {}
	var berth_ids: Dictionary = {}
	var source_ids: Dictionary = {}
	for craft in fleet:
		ship_ids[craft.get_ship_id()] = true
		berth_ids[craft.get_home_berth_id()] = true
		var source_id := int(combat_authority.get_source_id(craft))
		if source_id > 0:
			source_ids[source_id] = true
	_check(ship_ids.size() == 4, "all four registered flyables have unique stable ship IDs")
	_check(berth_ids.size() == 4, "all four registered flyables have unique home-berth IDs")
	_check(source_ids.size() == 4, "all four registered flyables have unique nonzero combat source IDs")
	_check(int(combat_authority.get_source_id(jovian)) == 1103, "Jovian owns stable production combat source 1103")
	_check(int(combat_authority.get_source_id(zenith)) == 1104, "Zenith owns stable production combat source 1104")

	for craft in fleet:
		var berth := world.get_berth_node(craft.get_home_berth_id())
		_check(
			berth != null
			and berth.get_reservation_owner() == craft
			and berth.get_occupant() == craft
			and berth.get_reserved_ship_id() == craft.get_ship_id()
			and not berth.get_reservation_token(craft).is_empty(),
			"%s begins with one occupied authoritative home-berth lease" % craft.name
		)
		_check(
			craft.global_transform.is_equal_approx(world.get_berth_transform(craft.get_home_berth_id())),
			"%s root matches its berth's complete production transform" % craft.name
		)

	var definition := jovian.get_ship_definition()
	_check(
		definition != null
		and definition.is_definition_valid()
		and definition.get_ship_id() == &"jovian_provisional"
		and jovian.get_ship_id() == definition.get_ship_id()
		and jovian.get_home_berth_id() == &"jovian_freight_berth",
		"Jovian runtime identity matches its valid provisional definition and freight berth"
	)
	_check(
		definition.get_evidence_status_id() == &"provisional"
		and not definition.is_authenticated()
		and str(jovian.get_jovian_evidence_report().get("evidence_scope", &"")) == "name_and_role_only"
		and not bool(jovian.get_meta("authenticated_historical_silhouette", true)),
		"Jovian identity remains explicitly provisional rather than authenticating its modern hull"
	)
	var jovian_berth_transform := world.get_berth_transform(jovian.get_home_berth_id())
	_check(
		jovian_berth_transform.origin.is_equal_approx(EXPECTED_JOVIAN_DOCK_ORIGIN)
		and (-jovian_berth_transform.basis.z).normalized().dot(Vector3.BACK) > 0.999,
		"freight registry preserves the exact port dock origin and 180-degree full basis"
	)
	var minimum_hull_separation := minf(
		jovian.global_position.distance_to(torrent.global_position),
		jovian.global_position.distance_to(arrow.global_position)
	)
	_check(minimum_hull_separation > 40.0, "the full Jovian hull occupies a visibly separate berth from both small craft")

	var targets := _get_live_range_targets(world)
	var target_health_before: Dictionary = {}
	for target in targets:
		target_health_before[target.get_instance_id()] = float(target.get_meta("health", -1.0))
	var target_count_before := world.get_target_count()
	var destroyed_before := world.get_destroyed_target_count()
	_check(not targets.is_empty() and targets.size() == target_count_before, "guided Torrent range contacts are live before the Jovian sortie")

	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.04
	game.disembarking_motion_time = 0.04
	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "shift begins on foot with the Torrent guide pending")

	# Walk the production PlayerController from the freight apron, over the real
	# yaw-180 hull ramp, across the cargo deck, and into the passenger cabin.
	var walk_basis := jovian.global_basis.orthonormalized()
	var interior_access := jovian.get_interior_access_marker()
	player.teleport_to(Transform3D(
		walk_basis,
		interior_access.global_position + jovian.global_basis.y.normalized() * 0.01
	))
	for _settle_tick in 10:
		await physics_frame
	_check(player.is_on_floor(), "production player begins grounded on the freight apron beside the deployed ramp")

	Input.action_press(&"move_right")
	for _ramp_tick in 50:
		await physics_frame
	Input.action_release(&"move_right")
	var ramp_local := jovian.to_local(player.global_position)
	_check(
		ramp_local.x > -7.4 and ramp_local.x < -4.8
		and absf(ramp_local.z - 3.2) < 0.9
		and player.is_on_floor(),
		"real locomotion climbs and remains grounded on the ship-owned cargo ramp"
	)

	Input.action_press(&"move_right")
	for _cargo_tick in 72:
		await physics_frame
	Input.action_release(&"move_right")
	var cargo_local := jovian.to_local(player.global_position)
	var moving_frame := jovian.get_moving_interior_component()
	_check(cargo_local.x > -3.2 and absf(cargo_local.z - 3.2) < 1.2, "real player crosses the clear aperture onto the cargo deck")
	_check(player.is_on_floor(), "production player remains grounded on physical cargo collision")
	_check(
		moving_frame != null
		and moving_frame.is_occupant_registered(player)
		and player.has_meta(MovingInteriorFrame.OWNER_META),
		"cargo-volume entry automatically registers the real PlayerController with MovingInteriorFrame"
	)

	# Centre the real controller in the physical portal rather than relying on a
	# teleport; the opening is deliberately tight enough that capsule clearance
	# matters at either edge.
	Input.action_press(&"move_left")
	for _aisle_alignment_tick in 9:
		await physics_frame
	Input.action_release(&"move_left")
	for _alignment_settle_tick in 3:
		await physics_frame
	Input.action_press(&"move_forward")
	for _passenger_tick in 118:
		await physics_frame
	Input.action_release(&"move_forward")
	var passenger_local := jovian.to_local(player.global_position)
	_check(
		passenger_local.z < -3.2 and absf(passenger_local.x) < 1.55,
		"real player follows the connected central aisle into the passenger cabin"
	)
	_check(
		player.is_on_floor() and jovian.get_interior_bounds().has_point(passenger_local),
		"passenger traversal stays grounded and inside the published ship-local interior"
	)

	# Exercise the production coordinator deterministically while that same real
	# player remains registered. The frame is stepped directly only for this short
	# bounded probe; normal automatic processing is restored before gameplay.
	player.set_control_enabled(false)
	moving_frame.set_physics_process(false)
	moving_frame.reset_frame_tracking(true)
	var parked_transform := jovian.global_transform
	var player_local_before := parked_transform.affine_inverse() * player.global_transform
	var roll_delta := Basis(Vector3.FORWARD, deg_to_rad(12.0))
	var moved_transform := Transform3D(
		(parked_transform.basis * roll_delta).orthonormalized(),
		parked_transform.origin + Vector3(2.0, 1.0, -1.5)
	)
	jovian.global_transform = moved_transform
	var frame_report := moving_frame.step_frame(
		0.25,
		int(Engine.get_physics_frames()) + 1
	)
	var player_local_after := jovian.global_transform.affine_inverse() * player.global_transform
	_check(
		bool(frame_report.get("applied", false))
		and int(frame_report.get("occupants_applied", 0)) == 1,
		"production moving frame applies one rigid update to the registered player"
	)
	_check(
		player_local_after.origin.distance_to(player_local_before.origin) < 0.015
		and player_local_after.basis.is_equal_approx(player_local_before.basis),
		"combined ship translation and rotation preserve the player's complete local pose"
	)
	var frame_up := jovian.global_basis.y.normalized()
	var controller_gravity: Vector3 = player.call("_get_effective_gravity")
	_check(
		player.up_direction.is_equal_approx(frame_up)
		and controller_gravity.normalized().dot(-frame_up) > 0.999
		and is_equal_approx(controller_gravity.length(), moving_frame.get_frame_gravity(player).length()),
		"PlayerController classifies floors and consumes gravity along live ship-local up"
	)
	var local_vertical_speed := 1.75
	player.velocity = frame_up * local_vertical_speed + jovian.global_basis.x * 2.5
	player.set_control_enabled(false)
	_check(
		is_equal_approx(player.velocity.dot(frame_up), local_vertical_speed)
		and player.velocity.slide(frame_up).is_zero_approx(),
		"disabling locomotion preserves ship-local vertical velocity while stopping deck-tangent motion"
	)
	_check(
		moving_frame.get_frame_linear_velocity().length() > 1.0
		and moving_frame.get_frame_angular_velocity().length() > 0.1,
		"live frame derives both translation and rotation velocity for occupant exit"
	)
	player.velocity = jovian.global_basis * Vector3(0.4, 0.0, -0.25)
	var expected_exit_velocity := moving_frame.get_exit_velocity(player)
	var release_report := moving_frame.unregister_occupant(player, true, &"integration_ramp_exit")
	_check(
		bool(release_report.get("released", false))
		and bool(release_report.get("velocity_applied", false))
		and (release_report.get("exit_velocity", Vector3.ZERO) as Vector3).is_equal_approx(expected_exit_velocity)
		and player.velocity.is_equal_approx(expected_exit_velocity),
		"clean moving-interior exit imparts relative plus linear and angular frame velocity exactly once"
	)
	_check(
		not moving_frame.is_occupant_registered(player)
		and not player.has_meta(MovingInteriorFrame.OWNER_META)
		and player.up_direction.is_equal_approx(Vector3.UP),
		"moving-interior exit restores the production player's world-frame state"
	)
	jovian.global_transform = parked_transform
	moving_frame.reset_frame_tracking(true)
	moving_frame.set_physics_process(true)
	player.teleport_to(Transform3D(
		jovian.global_basis.orthonormalized(),
		jovian.get_boarding_position() + jovian.global_basis.y.normalized() * 0.05
	))
	player.set_control_enabled(true)
	for _boarding_refresh in 4:
		await physics_frame
		await process_frame
	_check(jovian.global_transform.is_equal_approx(jovian_berth_transform), "moving-interior probe restores the exact occupied freight transform")
	_check(game.boarding_candidate == jovian, "physical proximity selects Jovian at its distinct pilot hatch")

	# Board with the actual E action, then route Y/F/W/L/X/E through the live
	# production input paths. This is a free sortie and must leave Torrent state
	# and contacts untouched.
	await _press_live_action(&"interact", 1)
	_check(await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8), "real E interaction completes Jovian boarding")
	_check(
		game.get_active_ship() == jovian and player.is_seated() and jovian.is_piloted(),
		"the same visible production player occupies Jovian's physical pilot seat"
	)
	_check(not game.is_guided_activity_complete() and not bool(opponent.call("is_active")), "Jovian-first boarding preserves the pending, dormant Torrent guide")

	jovian.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(jovian, "ONLINE", 0.4), "Jovian starts through the live pilot action path")
	_check(await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, 0.4), "Jovian-first startup enters an unrestricted pre-guide sortie")
	var jovian_berth := world.get_berth_node(jovian.get_home_berth_id())
	_check(
		jovian_berth.get_occupant() == jovian
		and jovian_berth.get_reservation_owner() == jovian,
		"engine startup alone retains Jovian's occupied freight lease"
	)

	jovian.weapon_cooldown = 0.02
	await _press_live_action(&"fire", 2)
	await process_frame
	var protected_result := game.get_last_player_shot_result()
	_check(
		protected_result.get("status") == &"guided_range_reserved"
		and protected_result.get("source_entity") == jovian
		and int(protected_result.get("source_id", 0)) == 1103,
		"pre-guide Jovian fire is explicitly protected while retaining source 1103"
	)
	_check(
		game.destroyed_targets == 0
		and world.get_destroyed_target_count() == destroyed_before
		and world.get_target_count() == target_count_before
		and _targets_match_health(targets, target_health_before),
		"protected Jovian fire cannot damage, remove, or credit Torrent range contacts"
	)

	var departure_origin := jovian.global_position
	var departure_forward := -jovian.global_basis.z.normalized()
	Input.action_press(&"move_forward")
	for _departure_tick in 24:
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _departure_settle in 3:
		await physics_frame
		await process_frame
	_check(not bool(jovian.get_telemetry().get("landed", true)), "real W thrust clears Jovian's authoritative landed state")
	var departure_offset := jovian.global_position - departure_origin
	_check(
		departure_offset.length() > 0.05
		and departure_offset.normalized().dot(departure_forward) > 0.85,
		"Jovian physically departs along its yaw-180 visible forward axis"
	)
	_check(
		jovian_berth.get_occupant() == null
		and jovian_berth.get_reservation_owner() == null,
		"authoritative Jovian departure releases the occupied freight lease"
	)

	# Begin three metres above the physical apron. This deliberately exercises
	# collision-contact convergence through the full live L path; a near-target
	# snap would miss ramp or landing-gear geometry that can stall the controller.
	jovian.global_transform = jovian_berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	jovian.velocity = Vector3.ZERO
	await physics_frame
	_dispatch_pilot_action(game, &"landing_assist")
	_check(await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 5.0), "live L action completes Jovian's physical freight-berth return")
	_check(
		bool(jovian.get_telemetry().get("landed", false))
		and jovian.global_transform.is_equal_approx(jovian_berth_transform),
		"Jovian landing restores the freight berth's complete origin and basis"
	)
	_check(
		jovian_berth.get_occupant() == jovian
		and jovian_berth.get_reservation_owner() == jovian
		and jovian_berth.get_reserved_ship_id() == &"jovian_provisional",
		"completed return reoccupies Jovian's authoritative lease"
	)

	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(jovian, "OFFLINE", 0.3), "live X action shuts Jovian down at the occupied berth")
	_dispatch_pilot_action(game, &"interact")
	_check(await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 0.8), "live E action completes Jovian disembarkation")
	_check(
		not player.is_seated() and player.is_control_enabled()
		and not jovian.is_piloted() and jovian.is_boardable(),
		"Jovian shutdown returns the same player to on-foot control and leaves a reusable craft"
	)
	_check(
		not game.is_guided_activity_complete()
		and game.get_guided_ship() == torrent
		and game.destroyed_targets == 0
		and not bool(opponent.call("is_active"))
		and _targets_match_health(targets, target_health_before),
		"complete Jovian sortie preserves the untouched Torrent guided mission"
	)

	# Parked craft are still real damageable bodies. Destroying Jovian now must
	# release its lease, preserve the on-foot guide, and regenerate this same hull
	# at the exact freight transform without reloading the world.
	var original_game_id := game.get_instance_id()
	var original_player_id := player.get_instance_id()
	var original_jovian_id := jovian.get_instance_id()
	jovian.apply_damage(jovian.maximum_hull + 1.0, jovian.global_position, Vector3.UP)
	await process_frame
	await physics_frame
	_check(jovian.is_destroyed(), "lethal parked damage destroys Jovian through its production lifecycle")
	_check(
		jovian_berth.get_occupant() == null
		and jovian_berth.get_reservation_owner() == null,
		"parked Jovian destruction immediately releases its freight lease"
	)
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
		and not player.is_seated() and player.is_control_enabled()
		and not game.is_guided_activity_complete()
		and game.get_guided_ship() == torrent,
		"parked Jovian loss cannot steal the player or pending Torrent guide"
	)
	_check(await _wait_for_ship_recovery(jovian, 5.0), "parked Jovian regenerates within the production recovery bound")
	_check(
		game.get_instance_id() == original_game_id
		and player.get_instance_id() == original_player_id
		and jovian.get_instance_id() == original_jovian_id,
		"parked recovery preserves the same world, player, and Jovian instances"
	)
	_check(
		jovian.is_boardable()
		and jovian.global_transform.is_equal_approx(jovian_berth_transform)
		and jovian_berth.get_occupant() == jovian
		and jovian_berth.get_reservation_owner() == jovian,
		"recovered Jovian is reusable at the exact reoccupied freight transform"
	)
	_check(
		game.get_flyable_ships().size() == 4
		and not game.is_guided_activity_complete()
		and game.destroyed_targets == 0
		and world.get_target_count() == target_count_before
		and _targets_match_health(targets, target_health_before),
		"recovery leaves exactly four flyables and all Torrent guide state intact"
	)

	await _clean_up(game)
	_finish()


func _get_live_range_targets(world: Node) -> Array[StaticBody3D]:
	var targets: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			targets.append(candidate as StaticBody3D)
	return targets


func _targets_match_health(targets: Array[StaticBody3D], expected_health: Dictionary) -> bool:
	for target in targets:
		if not is_instance_valid(target) or bool(target.get_meta("destroyed", false)):
			return false
		if not is_equal_approx(
			float(target.get_meta("health", -2.0)),
			float(expected_health.get(target.get_instance_id(), -1.0))
		):
			return false
	return true


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


func _wait_for_engine_state(ship: HeroShip, expected_state: String, timeout_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool:
			return str(ship.get_telemetry().get("engine_state", &"")).to_upper() == expected_state,
		timeout_seconds
	)


## Waits for `ship` to come back as a boardable hull after destruction.
##
## The previous form slept on `create_timer(0.05)` inside a wall-clock deadline,
## which is the worst of both clocks: regeneration is released against a
## monotonic deadline owned by `GameFlow`, the re-arm of the hull is applied from
## a frame callback, and a `SceneTree` timer counts Godot's smoothed engine delta
## — a third clock that was observed running both ahead of and behind the
## monotonic one. [method _wait_until] waits on the condition itself instead.
func _wait_for_ship_recovery(ship: HeroShip, timeout_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool: return not ship.is_destroyed() and ship.is_boardable(),
		timeout_seconds
	)


## Waits for `predicate` on both the simulation clock and the monotonic clock,
## giving up only once both budgets are spent.
##
## Godot runs three clocks here: the monotonic clock behind
## `Time.get_ticks_msec()`, the smoothed engine delta behind `SceneTree` timers,
## and the physics clock, whose steps the engine drops on a busy machine rather
## than letting the simulation spiral. Everything this suite waits on belongs to
## the first or third — phase transitions, engine spin-up and hull regeneration
## are advanced by the engine loops or released against a monotonic deadline —
## and a wall-clock-only deadline abandons a condition that is still progressing
## perfectly well, which is a false failure rather than a defect.
##
## `timeout_seconds` is kept as the *nominal* duration and becomes both a budget
## of simulated frames and a wall-clock deadline. Both bounds stay finite, so a
## genuinely stuck condition still fails the suite. Both loops are advanced each
## iteration because some conditions settle in `_physics_process` and others in
## `_process`.
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
		print("JOVIAN_SANDBOX_INTEGRATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"JOVIAN_SANDBOX_INTEGRATION_TEST_FAILED: %d/%d assertions failed: %s"
			% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
