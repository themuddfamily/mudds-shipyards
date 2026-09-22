extends SceneTree
## Drives one complete Aurora visit through a real composed `Main`, and then
## does to it the three things that break a world which is only half-wired: it
## interrupts the visit with a whole-`Main` re-entry, it departs and checks that
## nothing of Aurora is left behind, and it abandons a visit from the surface
## and checks that neither the pilot nor the craft is stranded.
##
## Everything here is the production path. The destination is chosen from the
## real Destination Board, the craft is boarded and re-boarded with a real
## `interact` at a real `ShipBoardingArea`, the touchdown goes through a real
## `ShipBerth` lease and `HeroShip.request_berth_landing()`, the walking is
## real movement on the authored world's own collision, and the interrupted
## visit is carried across the two `Main`s by the same `UserDataStore` the game
## ships with.

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "AURORA_VISIT_LOOP_TEST_OK"
const FAILURE_MARKER := "AURORA_VISIT_LOOP_TEST_FAILED"
const DESTINATION_ID: StringName = &"aurora_temperate_world"

var _failures: Array[String] = []
var _assertions := 0
var _outbound_fixture_ready := false
var _source_receipt_checks := 0
var _source_receipt_rejections_valid := true
var _source_replay_checked := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := await _boot()
	var craft := await _board_halyard(game)
	if craft == null:
		await _finish(game)
		return
	var owner: RefCounted = game.get("_aurora_expedition")
	_install_source_receipt_checks(game, owner)
	var home_position := craft.global_position
	var home_berth_id := craft.get_home_berth_id()

	# --- admit, arrive, land -------------------------------------------------
	await _prepare_bounded_outbound(game)
	var row := _row(game)
	_check(
		bool(row.get("route_available", false))
			and bool(row.get("action_enabled", false)),
		"Aurora is listed and selectable on the Destination Board (%s)"
			% row.get("status_text", "")
	)
	_check(
		float(row.get("orbital_distance_meters", 0.0)) == 12_000_000.0,
		"the board reads Aurora's distance from its own absolute orbital datum"
	)
	if not bool(row.get("action_enabled", false)):
		await _finish(game)
		return
	await _press_destination(game)
	await _wait_state(owner, &"landed", 6000)
	if owner.state != &"landed":
		print("VISIT DIAG: ", owner.get_visit_snapshot())
	_check(owner.state == &"landed", "the visit reaches a landed craft at Aurora")
	if owner.state != &"landed":
		await _finish(game)
		return

	_check(_source_receipt_checks == 3 and _source_receipt_rejections_valid and _source_replay_checked,
		"approach source rejects forged owner receipts and replay without changing live readiness")
	var surface := owner.get("_surface") as Node3D
	var berth := owner.get("_berth") as ShipBerth
	# The yard is 12,000 km behind the committed origin rebases by now, so the
	# craft's distance from the *live* station root is the honest measure of
	# having actually gone somewhere. `home_position` was recorded in a frame
	# that no longer exists.
	_check(
		is_instance_valid(surface) and surface is AuroraTemperateAuthoredScene
			and craft.global_position.distance_to(game.world.global_position)
				> 10_000_000.0,
		"the authored Aurora world is standing and the craft is really there"
	)

	# --- the real path, not a jump ------------------------------------------
	var visit := owner.get_visit_snapshot() as Dictionary
	var journey := visit.get("journey", {}) as Dictionary
	_check(
		is_instance_valid(surface)
			and surface == game.aurora_streaming_bootstrap.get_loaded_instance()
			and int(game.aurora_streaming_bootstrap.get_snapshot().get(
				"location_generation", 0
			)) >= 1,
		"the world the visit stands on is the one the production streaming coordinator loaded"
	)
	# Aurora sits 12,000 km out and the origin-shift threshold is 10 km, so a
	# trip there is not reachable without committed common-world transactions.
	# The Ember suites count these the same way.
	_check(
		int(journey.get("rebase_commit_count", 0)) >= 1
			and int(game.common_world_origin_rebase_owner.get_snapshot().get(
				"transaction_count", 0
			)) >= 1
			and game.common_world_origin_rebase_owner.get_snapshot().get(
				"last_world_id", &""
			) == AuroraTemperateStreamingBootstrap.WORLD_ID,
		"the way down commits real common-world origin rebases, named for Aurora (%d)"
			% int(journey.get("rebase_commit_count", 0))
	)
	_check(
		bool(journey.get("final_approach_armed", false))
			and bool(journey.get("final_approach_handoff_ready", false))
			and not (journey.get("final_approach_completion_receipt", {})
				as Dictionary).is_empty(),
		"the descent is a completed production final approach, consumed by the coordinator"
	)
	var receipt := journey.get("final_approach_completion_receipt", {}) as Dictionary
	_check(
		receipt.get("reason", &"") == &"final_approach_handoff_ready"
			and int(receipt.get("target_generation", 0)) >= 1,
		"the approach completion receipt is the cruise binding's own handoff (%s)"
			% receipt.get("reason", "")
	)
	# The one cruise binding served Aurora and was handed back to Ember, which
	# is what keeps an Ember expedition afterwards undisturbed.
	_check(
		int(visit.get("staging_events", -1)) == 0,
		"physical outbound performs zero expedition actor placements (%d)"
			% int(visit.get("staging_events", 0))
	)
	_check(
		is_instance_valid(berth) and berth.get_occupant() == craft
			and not String(owner.get("_surface_token")).is_empty()
			and bool(craft.get_telemetry().get("landed", false))
			and craft.get_landing_contract_report().get("phase")
				== HeroShip.LANDING_PHASE_DOCKED,
		"touchdown holds a real berth lease and a real docked landing contract"
	)
	_check(
		is_instance_valid(surface)
			and berth.get_parent() == surface.get_node_or_null(^"LandingRegion"),
		"the landing berth stands on the authored landing region, not on Main"
	)

	# Aurora is not a reskin of Ember: it has weather in front of the camera and
	# a bounded terrain generator under the pilot's feet, and neither exists on
	# an airless body.
	var environment := game.get_viewport().world_3d.environment
	_check(
		environment != null and environment.fog_enabled,
		"arriving hands the viewport Aurora's own atmospheric environment"
	)
	var clipmap := (surface.get_terrain_clipmap_snapshot()
		if is_instance_valid(surface) else {}) as Dictionary
	_check(
		int(clipmap.get("ring_count", 0)) == 5
			and int(clipmap.get("collision_ring_count", 0)) == 1,
		"the visited world brought its five committed terrain rings with it"
	)
	_check(
		is_instance_valid(surface) and surface.get_node_or_null(
			^"LandingRegion/CoastalExploration/CoastalLookoutSign"
		) != null,
		"the surface reads as a coast, not a caldera"
	)

	# --- disembark and walk the patch ---------------------------------------
	await _press_interact()
	await _wait_state(owner, &"surface", 400)
	for _i in range(30):
		await physics_frame
	_check(
		owner.state == &"surface" and not game.player.is_seated()
			and game.player.is_control_enabled() and game.player.is_on_floor(),
		"disembarking puts a controllable explorer onto Aurora's ground"
	)
	var disembark_position := game.player.global_position
	_check(
		await _walk_away(game.player, craft, 2.5),
		"the explorer walks the authored patch on real terrain collision"
	)
	_check(
		game.player.global_position.distance_to(disembark_position) > 1.0
			and game.player.is_on_floor(),
		"the walk is physical ground movement, not a teleport"
	)

	# --- interrupt: save and whole-Main re-entry -----------------------------
	var saved := game.save_interrupted_aurora_visit() as Dictionary
	_check(
		bool(saved.get("accepted", false)),
		"an in-progress visit commits an interrupted-visit record (%s)"
			% saved.get("reason", "")
	)
	await _shut_down(game)

	var resumed_game := await _boot()
	var resumed: RefCounted = resumed_game.get("_aurora_expedition")
	var status := resumed_game.get_aurora_interrupted_visit_status() as Dictionary
	var restore := status.get("restore", {}) as Dictionary
	_check(
		bool(restore.get("accepted", false)),
		"a fresh Main resumes the interrupted visit (%s)"
			% restore.get("reason", "")
	)
	# Resuming now streams Aurora back in through the same production lane a
	# fresh arrival uses, which takes physics ticks and committed origin
	# transactions, so the resume completes on the visit's own cadence.
	await _wait_state(resumed, &"surface", 6000)
	if resumed.state != &"surface":
		print("RESUME DIAG: ", resumed.get_visit_snapshot())
	_check(
		resumed.is_active() and resumed.state == &"surface",
		"the pilot comes back standing on Aurora, not quietly back at Mudds"
	)
	_check(
		int((resumed.get_visit_snapshot().get("journey", {}) as Dictionary).get(
			"rebase_commit_count", 0
		)) >= 1
			and is_instance_valid(
				resumed_game.aurora_streaming_bootstrap.get_loaded_instance()
			),
		"the resumed visit streams the same world back in rather than standing a private copy"
	)
	var resumed_craft := resumed.get("_ship") as HeroShip
	var resumed_berth := resumed.get("_berth") as ShipBerth
	_check(
		is_instance_valid(resumed_craft)
			and resumed_craft.get_home_berth_id() == home_berth_id,
		"the resumed visit uses the same craft the pilot flew out in"
	)
	_check(
		is_instance_valid(resumed_berth)
			and resumed_berth.get_occupant() == resumed_craft
			and not String(resumed.get("_surface_token")).is_empty(),
		"the resumed craft holds a real berth lease on Aurora's pad again"
	)
	for _i in range(60):
		await physics_frame
	_check(
		not resumed_game.player.is_seated()
			and resumed_game.player.is_control_enabled()
			and resumed_game.player.is_on_floor(),
		"the resumed explorer has usable controls and physical support"
	)
	var retire := restore.get("retire", {}) as Dictionary
	_check(
		bool(retire.get("accepted", false)),
		"the interrupted-visit receipt is retired once the resume is accepted (%s/%s)"
			% [retire.get("reason", ""), retire.get("binding_reason", "")]
	)

	# --- re-board and return -------------------------------------------------
	_check(
		await _walk_to_boarding_area(resumed_game, resumed_craft),
		"the explorer walks back to the craft's boarding area"
	)
	await _press_interact()
	await _wait_state(resumed, &"landed", 600)
	_check(
		resumed.state == &"landed" and resumed_game.player.is_seated()
			and resumed_game._piloting
			and resumed_game.active_ship == resumed_craft,
		"a real interact re-boards the same physical craft"
	)
	if resumed.state != &"landed":
		await _finish(resumed_game)
		return
	var return_pose := resumed_craft.global_transform
	var return_berth := resumed.get("_berth") as ShipBerth
	await _press_destination(resumed_game)
	for tick in 20:
		await physics_frame
		await process_frame
	_check(resumed.state == &"return_cruise"
		and resumed_game._planetary_journey.is_return_departure_pending()
		and resumed_craft.global_transform == return_pose
		and return_berth.get_occupant() == resumed_craft,
		"restored visit queues real manual departure without moving the occupied craft")
	resumed.cancel()
	_check(resumed.state == &"idle" and resumed_game.player.is_seated()
		and resumed_craft.global_transform == return_pose and resumed_craft.is_piloted(),
		"canceling return preserves the same current pilot and craft instead of rescue placement")
	_check(not _store_has_aurora_record(resumed_game),
		"the resumed and then canceled visit leaves no interrupted-visit record")
	# Actual Aurora unload and home docking/exit/walk are exercised by the
	# physical departure test and the explicit return soak respectively.

	# --- abandon from the surface -------------------------------------------
	resumed_game.call(&"_sync_planetary_cruise_hud")
	await _press_destination(resumed_game)
	await _wait_state(resumed, &"landed", 6000)
	if resumed.state != &"landed":
		print("ABANDON DIAG: ", resumed.get_visit_snapshot().get("admission", {}),
			" compose=", resumed.get_visit_snapshot().get("compose", {}),
			" leg=", resumed.get_visit_snapshot().get("last_leg", {}),
			" state=", resumed.state)
		_check(false, "a further visit can be admitted for the abandon case")
		await _finish(resumed_game)
		return
	resumed_game.call(&"_try_exit_ship")
	await _wait_state(resumed, &"surface", 600)
	_check(resumed.state == &"surface", "the abandon case starts from the surface")
	resumed.cancel()
	for _i in range(40):
		await physics_frame
	_check(
		resumed.state == &"idle" and not resumed_game._piloting
			and not resumed_game._transition_busy
			and not resumed_game.player.is_seated()
			and resumed_game.player.is_control_enabled()
			and resumed_game.player.global_position.distance_to(
				resumed_game.world.get_player_spawn().origin
			) < 400.0,
		"abandoning returns a controllable explorer to the yard, not a stranded one"
	)
	_check(
		bool(resumed_craft.get_telemetry().get("landed", false))
			and (resumed_craft.get_node("ShipBoardingArea") as ShipBoardingArea
				).get_reservation_token() == null,
		"abandoning leaves the craft docked at home with no held reservation"
	)
	_check(
		_aurora_node_count(resumed_game) == 0,
		"abandoning removes Aurora as cleanly as a completed departure"
	)
	await _finish(resumed_game)


# --- harness -----------------------------------------------------------------


func _boot() -> GameFlow:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.01
	game.start_shift()
	await process_frame
	await physics_frame
	return game


func _shut_down(game: GameFlow) -> void:
	game.queue_free()
	for _i in range(6):
		await process_frame
		await physics_frame


func _board_halyard(game: GameFlow) -> HeroShip:
	var craft := game.get_node_or_null("HalyardCrewTransport") as HeroShip
	if craft == null:
		_check(false, "the production Main composes the Halyard crew transport")
		return null
	game.player.teleport_to(Transform3D(
		craft.global_basis,
		craft.get_boarding_position() + craft.global_basis.y * 0.01
	))
	for _i in range(6):
		await physics_frame
		await process_frame
	await _press_interact()
	for _i in range(300):
		await physics_frame
		if game._piloting:
			break
	_check(
		game._piloting and game.player.is_seated() and game.active_ship == craft,
		"an ordinary boarding takes the Halyard's pilot seat"
	)
	return craft if game._piloting else null


func _row(game: GameFlow) -> Dictionary:
	var snapshot := game.get_planetary_destination_catalog_snapshot() as Dictionary
	for row: Dictionary in snapshot.get("destinations", []):
		if row.get("destination_id") == DESTINATION_ID:
			return row
	return {}


func _install_source_receipt_checks(game: GameFlow, owner: RefCounted) -> void:
	game.common_world_origin_rebase_owner.rebase_committed.connect(func(receipt: Dictionary) -> void:
		if _source_receipt_checks > 0:
			return
		var source := owner.get("_approach_source") as AuroraVisitApproachSource
		if not is_instance_valid(source) or not source.is_ready_for_approach():
			return
		var before := source.get_snapshot()
		for field in ["world_id", "request_id", "world_translation_delta"]:
			var forged := receipt.duplicate(true)
			match field:
				"world_id": forged[field] = &"another_world"
				"request_id": forged[field] = int(forged[field]) + 1
				"world_translation_delta": forged[field] = (forged[field] as Vector3) + Vector3.ONE
			var rejected := source.accept_committed_origin_rebase(forged, source.get_generation(), source.get_attachment_generation())
			_source_receipt_rejections_valid = _source_receipt_rejections_valid and not bool(rejected.get("accepted", true)) and source.get_snapshot() == before
			_source_receipt_checks += 1
	)


## Explicit bounded-test setup. Real boarding/departure precede this distance
## placement; production expedition movement begins only after it. Full 12 Mm
## travel is qualified separately and is never inferred from this fixture.
func _prepare_bounded_outbound(game: GameFlow) -> void:
	var owner: RefCounted = game.get("_aurora_expedition")
	if owner.is_active() or _outbound_fixture_ready:
		return
	var craft := game.active_ship as HeroShip
	if bool(craft.get_telemetry().get("landed", true)):
		_check(not bool(owner.runtime_state().get("action_enabled", true)),
			"parked Aurora action asks the pilot to physically depart first")
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		# Hold controls for physics ticks, independent of render catch-up batches.
		for i in 180:
			await physics_frame
		Input.action_release(&"hover")
		Input.action_release(&"move_forward")
		for i in 4:
			await physics_frame
			await process_frame
	print("AURORA_DEPARTURE phase=", game.phase, " landed=", craft.get_telemetry().get("landed"), " departed=", game._sortie_departed_berth)
	_check(game.phase in [GameFlow.Phase.FREE_FLIGHT, GameFlow.Phase.SHUT_DOWN] and game._sortie_departed_berth and not bool(craft.get_telemetry().get("landed", true)),
		"held pilot controls physically depart the yard")
	# Isolate this arrival fixture from the unrelated automatically selected activity.
	var activity := game.cinder_race_session.get_presentation_snapshot()
	if bool(activity.get("running", false)):
		game.cinder_race_session.fail(&"arrival_fixture_activity_ended", game.cinder_race_session.get_session_generation())
	var bootstrap := game.aurora_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(
		bootstrap.get_navigation_destination().get("body_local_position_meters"), frame.get_generation())
	var anchor := frame.orbital_to_world_streaming_position(
		encoded.get("coordinate"), frame.get_generation()).get("position", Vector3.INF) as Vector3
	craft.global_transform = Transform3D(Basis.IDENTITY, anchor + Vector3.BACK * 70_000.0)
	craft.velocity = Vector3.ZERO
	craft.reset_physics_interpolation()
	for i in 2:
		await physics_frame
		await process_frame
	_outbound_fixture_ready = true
	print("AURORA_BOUNDED_FIXTURE: distance staged before request; outbound owner must make zero placements")


func _press_destination(game: GameFlow) -> void:
	await _prepare_bounded_outbound(game)
	game.call(&"_sync_planetary_cruise_hud")
	game.hud.open_planetary_destination_board()
	var button := game.hud.find_child(
		"PlanetaryDestinationAction_%s" % DESTINATION_ID, true, false
	) as Button
	_check(
		button != null and not button.disabled,
		"Aurora's board action is visible and enabled"
	)
	if button != null and not button.disabled:
		button.pressed.emit()
	_outbound_fixture_ready = false


## Counts everything of Aurora still parented under Main. A streamed world that
## departs cleanly leaves exactly zero.
func _aurora_node_count(game: GameFlow) -> int:
	var count := 0
	for candidate in game.find_children("*", "Node3D", true, false):
		if candidate is AuroraTemperateAuthoredScene:
			count += 1
	return count


func _store_has_aurora_record(game: GameFlow) -> bool:
	var store: Object = game.get("_runtime_settings_user_data_store")
	if store == null:
		return false
	var loaded := store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return false
	return (loaded.get("payload", {}) as Dictionary).has(
		String(GameFlow.AURORA_EXPEDITION_PERSISTENCE_SLOT)
	)


func _wait_state(owner: RefCounted, target: StringName, frames: int) -> void:
	var game := owner.get("_flow") as GameFlow
	var craft := owner.get("_ship") as HeroShip
	var samples := {"delta": Vector3.ZERO}
	var origin: CommonWorldOriginRebaseOwner = game.common_world_origin_rebase_owner if is_instance_valid(game) else null
	var receive_rebase := func(receipt: Dictionary) -> void:
		samples.delta = (samples.delta as Vector3) + (receipt.get("world_translation_delta", Vector3.ZERO) as Vector3)
	if is_instance_valid(origin):
		origin.rebase_committed.connect(receive_rebase)
	var fault := ""
	for i in frames:
		var physical: bool = owner.state in [&"outbound", &"corridor", &"landing"] and is_instance_valid(craft) and is_instance_valid(origin)
		var previous_ship := craft.global_position if physical else Vector3.ZERO
		var previous_player := game.player.global_position if physical else Vector3.ZERO
		var previous_speed := craft.velocity.length() if physical else 0.0
		var previous_basis := craft.global_basis if physical else Basis.IDENTITY
		var previous_tick := Engine.get_physics_frames()
		samples.delta = Vector3.ZERO
		# Endpoint speed bounds apply to one physics step, not a render batch
		# that can contain both acceleration and braking around a speed peak.
		await physics_frame
		if physical:
			var source := owner.get("_approach_source") as AuroraVisitApproachSource
			if _source_receipt_checks == 3 and not _source_replay_checked and is_instance_valid(source):
				var before := source.get_snapshot()
				var receipt := origin.get_snapshot().get("last_receipt", {}) as Dictionary
				if int(before.get("coordinate_frame_generation", 0)) == int(receipt.get("target_generation", -1)):
					var replay := source.accept_committed_origin_rebase(receipt, source.get_generation(), source.get_attachment_generation())
					_source_receipt_rejections_valid = _source_receipt_rejections_valid and not bool(replay.get("accepted", true)) and source.get_snapshot() == before
					_source_replay_checked = true
			var elapsed := float(Engine.get_physics_frames() - previous_tick) / float(Engine.physics_ticks_per_second)
			var translation := samples.delta as Vector3
			var motion_bound := maxf(previous_speed, craft.velocity.length()) * elapsed + 0.25
			var seat_radius := craft.get_pilot_seat_anchor().global_position.distance_to(craft.global_position)
			var rotation_allowance := Quaternion(previous_basis).angle_to(Quaternion(craft.global_basis)) * seat_radius
			if craft.global_position.distance_to(previous_ship + translation) > motion_bound \
					or game.player.global_position.distance_to(previous_player + translation) > motion_bound + rotation_allowance:
				fault = "outbound actor moved beyond physical velocity and seat rotation"
			var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
			if not craft.is_piloted() or not game.player.is_seated_at(craft.get_pilot_seat_anchor()) \
					or area.get_reservation_token() != game.player:
				fault = "outbound lost the exact seated pilot reservation"
			if not fault.is_empty():
				break
		if owner.state == target:
			break
	if is_instance_valid(origin):
		origin.rebase_committed.disconnect(receive_rebase)
	_check(fault.is_empty(), "physical arrival preserves per-tick actor continuity and exact pilot ownership: " + fault)
	if owner.state != target:
		print("WAIT ENDED: ", owner.state, " wanted ", target, " snapshot=", owner.get_visit_snapshot() if owner.has_method("get_visit_snapshot") else {})


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


func _look_toward(player: PlayerController, target: Vector3) -> void:
	var direction := player.global_basis.inverse() * (
		target - player.global_position
	)
	(player.get_node("CameraRig/CameraYaw") as Node3D).rotation.y = atan2(
		-direction.x, -direction.z
	)


## Walks directly away from the craft along the pad, which is the one direction
## guaranteed to be authored walkable ground rather than the ship's own hull.
func _walk_away(
		player: PlayerController, craft: HeroShip, metres: float
	) -> bool:
	var start := player.global_position
	var away := (start - craft.global_position)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = craft.global_basis.x
	var target := start + away.normalized() * metres
	_look_toward(player, target)
	for _i in range(360):
		if player.global_position.distance_to(target) < 0.4:
			break
		_look_toward(player, target)
		Input.action_press(&"move_forward")
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _i in range(8):
		await physics_frame
		await process_frame
	return player.is_on_floor()


func _walk_to_boarding_area(game: GameFlow, craft: HeroShip) -> bool:
	var area := craft.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	if area == null:
		return false
	var target := craft.get_boarding_position()
	for _i in range(720):
		if area in game.player.get_nearby_interactables():
			break
		_look_toward(game.player, target)
		Input.action_press(&"move_forward")
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _i in range(8):
		await physics_frame
		await process_frame
	return area in game.player.get_nearby_interactables()


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)


func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [
		SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions,
	])
	quit(0 if _failures.is_empty() else 1)
