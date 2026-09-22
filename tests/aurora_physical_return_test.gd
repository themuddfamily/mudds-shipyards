extends "res://tests/aurora_expedition_production_test.gd"

## Bounded production departure: staging is only before outbound admission.
## From Aurora touchdown onward the same actors move only through real inputs
## and the shared cruise. The long home leg is qualified separately.
const TransitSoak := preload("res://tests/ember_transit_movement_soak.gd")

## Observe every completed physics tick, including catch-up ticks between renders.
## The coroutine's physics_frame + process_frame pair can span several ticks.
class ReturnSampler extends Node:
	var game: GameFlow
	var rebase_count := 0
	var max_ship_step_m := 0.0
	var max_player_step_m := 0.0
	var occupancy_failures := 0
	var cadence_failures := 0
	var ticks := 0
	var _last_tick := -1
	var _last_ship := Vector3.INF
	var _last_player := Vector3.INF
	var _translation := Vector3.ZERO

	func _ready() -> void:
		# Ship motion and seated embodiment run before this common observation point.
		process_physics_priority = 1000
		game.common_world_origin_rebase_owner.rebase_committed.connect(_on_rebase)

	func _exit_tree() -> void:
		game.common_world_origin_rebase_owner.rebase_committed.disconnect(_on_rebase)

	func _on_rebase(receipt: Dictionary) -> void:
		_translation += receipt.get("world_translation_delta", Vector3.ZERO) as Vector3
		rebase_count += 1

	func _physics_process(_delta: float) -> void:
		var craft := game.active_ship as HeroShip
		var player := game.player as PlayerController
		var tick := Engine.get_physics_frames()
		if _last_tick >= 0:
			cadence_failures += int(tick - _last_tick != 1)
			max_ship_step_m = maxf(max_ship_step_m, craft.global_position.distance_to(_last_ship + _translation))
			max_player_step_m = maxf(max_player_step_m, player.global_position.distance_to(_last_player + _translation))
		_last_tick = tick
		_last_ship = craft.global_position
		_last_player = player.global_position
		_translation = Vector3.ZERO
		ticks += 1
		var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
		occupancy_failures += int(not craft.is_piloted()
			or not player.is_seated_at(craft.get_pilot_seat_anchor())
			or area.get_reservation_token() != player)
		cadence_failures += int(process_physics_priority <= craft.process_physics_priority
			or process_physics_priority <= player.process_physics_priority)

func _run() -> void:
	var game := MAIN.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(TransitSoak.Store.new("memory://aurora-return-departure.json", TransitSoak.MemoryFilesystem.new()), "memory://aurora-return-departure.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.01
	game.player.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position() + craft.global_basis.y * 0.01))
	for i in range(6):
		await physics_frame
		await process_frame
	await _press_interact()
	for i in range(240):
		await physics_frame
		if game._piloting:
			break
	_check(game._piloting and game.player.is_seated() and game.active_ship == craft, "ordinary boarding takes the Halyard pilot seat")
	var home_position := craft.global_position
	var owner = game.get("_aurora_expedition")
	game.call(&"_sync_planetary_cruise_hud")
	await _prepare_bounded_outbound(game)
	var row := _row(game)
	_check(bool(row.get("route_available", false)) and bool(row.get("action_enabled", false)), "Aurora is a selectable production destination: %s" % row.get("status_text"))
	if not bool(row.get("action_enabled", false)):
		await _finish(game)
		return
	await _press_destination(game)
	_check(owner.state == &"outbound" and not paused, "the visible Destination Board action starts the production cruise and resumes play")
	await _wait_state(owner, &"landed", 48_000 if _full_flight else 6500)
	_check(owner.state == &"landed", "physical landing completes at Aurora (state %s)" % owner.state)
	if owner.state != &"landed":
		await _finish(game)
		return
	var berth := owner.get("_berth") as ShipBerth
	var surface_pose := craft.global_transform
	var before_velocity := craft.velocity
	var token := berth.get_reservation_token(craft)
	var staging_before := int(owner.get_visit_snapshot().get("staging_events", -1))
	var journey := game._planetary_journey
	var ember_active: bool = journey.get("_ember_surface_journey_active")
	var ember_arrival: bool = journey.get("_planetary_return_physical_arrival_required")
	_check(bool(journey.begin_aurora_return().get("accepted", false)), "negative receipt fixture admits an Aurora return")
	journey.call("_observe_aurora_return_tick", {"accepted": true, "reason": &"return_approach_handoff_ready", "target_generation": 1})
	var refused := journey.get_aurora_visit_snapshot()
	_check(not bool(refused.get("return_active", true)) and not bool(refused.get("return_departure_pending", true))
		and not bool(refused.get("return_handoff_ready", true))
		and (refused.get("last_return_result", {}) as Dictionary).get("reason") == &"return_approach_completion_stale"
		and journey.get("_ember_surface_journey_active") == ember_active
		and journey.get("_planetary_return_physical_arrival_required") == ember_arrival,
		"invalid completion retires only Aurora intent, preserves reason and never mutates Ember arrival")
	for i in 4:
		await physics_frame
		await process_frame
	_check(not bool(game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)),
		"rejected completion cannot automatically rearm")
	_check(owner.request(), "landed Aurora return is admitted")
	_check(craft.global_transform == surface_pose and craft.velocity == before_velocity
		and berth.get_occupant() == craft and berth.get_reservation_token(craft) == token,
		"return admission keeps exact actor pose, velocity and occupied surface lease")
	for i in 20:
		await physics_frame
		await process_frame
	_check(game._planetary_journey.is_return_departure_pending()
		and bool(craft.get_telemetry().get("landed", false)) and berth.get_occupant() == craft,
		"idle return waits for real pilot takeoff without releasing the berth")
	_check(game._planetary_journey.get("_aurora_final_approach_source_ref") == null,
		"return admission retires the consumed outbound source fence")
	var sampler := ReturnSampler.new()
	sampler.game = game
	root.add_child(sampler)
	# Establish the baseline at the same late-physics point used for every sample.
	await physics_frame
	await process_frame
	var climb_direction := (surface_pose.basis.y * 0.85 - surface_pose.basis.z * 0.5).normalized()
	var height := 0.0
	Input.action_press(&"move_forward")
	for tick in 1800:
		var local_climb := craft.global_basis.inverse() * climb_direction
		for action in [&"move_left", &"move_right", &"pitch_up", &"pitch_down"]:
			Input.action_release(action)
		var yaw := atan2(local_climb.x, -local_climb.z)
		var pitch := atan2(local_climb.y, Vector2(local_climb.x, local_climb.z).length())
		if absf(yaw) > 0.005:
			Input.action_press(&"move_right" if yaw > 0.0 else &"move_left", minf(absf(yaw) * 3.0, 1.0))
		if absf(pitch) > 0.005:
			Input.action_press(&"pitch_up" if pitch > 0.0 else &"pitch_down", minf(absf(pitch) * 3.0, 1.0))
		await physics_frame
		await process_frame
		var landing_origin: Vector3 = owner.call("_landing_region_origin")
		height = (craft.global_position - landing_origin).dot(surface_pose.basis.y)
		if tick % 240 == 0:
			print("AURORA_RETURN_LIFT tick=", tick, " height_above_pad=", height, " speed=", craft.velocity.length(), " landed=", craft.get_telemetry().get("landed"), " pending=", game._planetary_journey.is_return_departure_pending())
		if height >= 1200.0:
			break
	for action in [&"move_forward", &"move_left", &"move_right", &"pitch_up", &"pitch_down"]:
		Input.action_release(action)
	_check(height >= 1200.0, "ordinary pitch and thrust physically clear Aurora's terrain")
	_check(not bool(craft.get_telemetry().get("landed", true))
		and not is_instance_valid(owner.get("_berth")), "physical takeoff releases the surface lease")
	# Bound cruise by simulated ticks, independent of render catch-up cadence.
	for tick in 2400:
		await physics_frame
		if tick % 240 == 0:
			print("AURORA_RETURN_DEPARTURE tick=", tick, " speed=", craft.velocity.length(), " hull=", craft.get_telemetry().get("hull"), " journey=", (game._planetary_journey.get_aurora_visit_snapshot().get("last_return_result", {}) as Dictionary).get("reason"), " rebases=", sampler.rebase_count)
		if craft.is_destroyed() or owner.state != &"return_cruise":
			break
	# Let the final physics tick reach the late sampler before reading its totals.
	await process_frame
	_check(owner.state == &"return_cruise" and not game._planetary_journey.is_return_departure_pending()
		and sampler.rebase_count > 2 and not is_instance_valid(game.aurora_streaming_bootstrap.get_loaded_instance()),
		"shared physical return crosses rebases and unloads Aurora after manual clearance")
	_check(sampler.max_ship_step_m < 335.0 and sampler.max_player_step_m < 335.0
		and sampler.occupancy_failures == 0 and sampler.cadence_failures == 0 and sampler.ticks > 2400
		and not craft.is_destroyed()
		and is_equal_approx(float(craft.get_telemetry().get("hull", 0)), float(craft.get_telemetry().get("maximum_hull", -1)))
		and int(owner.get_visit_snapshot().get("staging_events", -1)) == staging_before,
		"return departure preserves physical actor continuity, exact pilot, full hull and zero placement")
	print("RETURN_SAMPLER_SUMMARY max_ship=", sampler.max_ship_step_m, " max_player=", sampler.max_player_step_m, " physics_samples=", sampler.ticks, " cadence_failures=", sampler.cadence_failures, " occupancy_failures=", sampler.occupancy_failures, " hull=", craft.get_telemetry().get("hull"), " staging_delta=", int(owner.get_visit_snapshot().get("staging_events", -1)) - staging_before)
	root.remove_child(sampler)
	sampler.free()
	var cancel_pose := craft.global_transform
	var cancel_velocity := craft.velocity
	owner.cancel()
	_check(owner.state == &"idle" and craft.global_transform == cancel_pose
		and craft.velocity == cancel_velocity and game.player.is_seated() and craft.is_piloted(),
		"explicit return cancellation releases current actors without rescue placement")
	await _finish(game)
