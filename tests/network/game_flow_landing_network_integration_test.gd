extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const Ship := preload("res://scripts/ships/hero_ship.gd")
const ShipDefinition := preload("res://assets/ships/torrent_provisional.tres")
const Berth := preload("res://scripts/world/ship_berth.gd")
const MainScene := preload("res://scenes/main.tscn")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")

var _coastal_sequence := 0
var _coastal_interaction := 0
var _assertions := 0
var _failures := PackedStringArray()


class SurveyFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var reject_rewards := false
	var rejected_rewards := 0
	func exists(path: String) -> bool:
		return files.has(path)
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes: PackedByteArray = files[path]
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT, "bytes": bytes.duplicate()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_rewards and document is Dictionary and str((document.get("commit", {}) as Dictionary).get("id", "")).begins_with("game-flow-reward-"):
			rejected_rewards += 1
			return ERR_CANT_CREATE
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK


class LandingAdapterProbe extends Adapter:
	var fail_release := false
	var fail_abort := false
	var fail_landed_publication := false
	var fail_flying_publication := false
	var abort_call_count := 0
	var landed_publication_failures := 0
	var landed_publication_successes := 0
	var journey_retirements := 0

	func publish_planetary_journey_state(state: Dictionary, reliable: bool = false, recipient: int = 0) -> Dictionary:
		var result := super.publish_planetary_journey_state(state, reliable, recipient)
		if state.get("phase") == &"retired" and bool(result.get("accepted", false)):
			journey_retirements += 1
		return result

	func release_server_landing(
		entity_id: StringName,
		entity_generation: int,
		lease_id: StringName,
	) -> Dictionary:
		if fail_release:
			return {"accepted": false, "status": &"injected_retirement_failure"}
		return super.release_server_landing(entity_id, entity_generation, lease_id)

	func abort_server_landing(
		entity_id: StringName,
		entity_generation: int,
		lease_id: StringName,
	) -> Dictionary:
		abort_call_count += 1
		if fail_abort:
			return {"accepted": false, "status": &"injected_abort_failure"}
		return super.abort_server_landing(entity_id, entity_generation, lease_id)

	func publish_landing_snapshot(
		entity_id: StringName,
		entity_generation: int,
		position: Vector3,
		state: StringName,
		recipients: Array = [],
		server_tick: int = 0,
	) -> Dictionary:
		if fail_landed_publication and state == &"landed":
			landed_publication_failures += 1
			return {"accepted": false, "status": &"injected_landed_publication_failure"}
		if fail_flying_publication and state == &"flying":
			return {"accepted": false, "status": &"injected_flying_publication_failure"}
		var result := super.publish_landing_snapshot(
			entity_id, entity_generation, position, state, recipients, server_tick
		)
		if state == &"landed" and bool(result.get("accepted", false)):
			landed_publication_successes += 1
		return result


class LandingFlowProbe extends GameFlow:
	var planetary_completion_calls := 0

	func _complete_planetary_return_physical_arrival(
		berth: ShipBerth,
		landing_report: Dictionary,
	) -> Dictionary:
		planetary_completion_calls += 1
		_planetary_return_physical_arrival_required = false
		_landing_request_active = false
		_active_landing_berth_id = &""
		return {
			"accepted": is_instance_valid(berth)
				and bool(landing_report.get("strict_dock_acceptance", false)),
			"reason": &"injected_planetary_completion",
		}


class HudProbe extends CanvasLayer:
	var objective := ""
	var toast_title := ""

	func set_interaction(_text: String, _available: bool = true) -> void:
		pass

	func set_objective(text: String, _eyebrow: String = "") -> void:
		objective = text

	func toast(title: String, _detail: String = "", _duration: float = 0.0) -> void:
		toast_title = title


class LandingWorld extends Node3D:
	var berth: Node

	func get_berth_node(berth_id: StringName) -> Node:
		if berth != null and berth.call(&"get_berth_id") == berth_id:
			return berth
		return null


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := LandingAdapterProbe.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	var world := LandingWorld.new()
	var berth := Berth.new()
	berth.berth_id = &"network_landing_test_berth"
	world.berth = berth
	world.add_child(berth)
	root.add_child(world)
	var bomber := Ship.new()
	bomber.ship_definition = ShipDefinition
	root.add_child(bomber)
	await process_frame
	var hud := HudProbe.new()
	root.add_child(hud)
	var flow := LandingFlowProbe.new()
	flow.network_session = server
	flow._network_session_mode = &"server"
	flow.world = world
	flow.active_ship = bomber
	flow.hud = hud
	_check(flow._reserve_berth_for_ship(bomber, berth.get_berth_id(), false),
		"the real physical berth owns the pending lease before networking")
	var reserved := flow._begin_network_landing_handoff(bomber, berth)
	var pending_packet := (reserved.get("publication", {}) as Dictionary).get("packet", {}) as Dictionary
	var pending_entity := server.get_landing_entity(bomber.get_ship_id())
	_check(bool(reserved.get("accepted", false))
		and pending_entity.get("state") == &"landing_pending"
		and not StringName(pending_entity.get("lease_id", &"")).is_empty(),
		"GameFlow hands the exact physical reservation to server landing authority")
	_check((pending_packet.get("landing", {}) as Dictionary).get("state") == &"landing_pending",
		"pending presentation publishes only after the server reservation")
	var client := Adapter.new()
	var pending_applied := client.consume_landing_snapshot(pending_packet)
	_check(bool(pending_applied.get("accepted", false)),
		"client consumes the pending state as presentation only")
	_check(int(client.get_presentation_cursor_audit().get("landing_count", 0)) == 1,
		"client retains one landing presentation cursor")
	_check(client.commit_server_landing(
		bomber.get_ship_id(), 1, StringName(pending_entity.get("lease_id", &""))
	).get("status") == &"authority_required",
		"client cannot commit physical occupancy from its presentation cursor")
	var premature_commit := flow._commit_network_landing_handoff(bomber, berth)
	_check(premature_commit.get("status") == &"physical_berth_occupancy_mismatch"
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landing_pending",
		"server cannot publish landed before the physical berth is occupied")
	_check(berth.occupy(
		bomber, StringName(flow._berth_tokens.get(bomber.get_instance_id(), &""))
	), "physical berth commits occupancy before the network lifecycle")
	var committed := flow._commit_network_landing_handoff(bomber, berth)
	var landed_packet := (committed.get("publication", {}) as Dictionary).get("packet", {}) as Dictionary
	_check(bool(committed.get("accepted", false))
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landed"
		and (landed_packet.get("landing", {}) as Dictionary).get("state") == &"landed",
		"server commits and publishes landed only after exact physical occupancy")
	_check(bool(client.consume_landing_snapshot(landed_packet).get("accepted", false))
		and int(client.get_presentation_cursor_audit().get("landing_count", 0)) == 1,
		"client applies landed without acquiring berth or landing authority")
	server.fail_release = true
	var failed_departure := flow._mark_sortie_departed()
	_check(not bool(failed_departure.get("accepted", false))
		and failed_departure.get("status") == &"injected_retirement_failure"
		and berth.is_occupied() and berth.is_reserved()
		and not flow._sortie_departed_berth,
		"retirement failure keeps the physical berth occupied and departure retryable")
	_check((flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"landed"
		and hud.objective.contains("berth retained"),
		"failed retirement retains the committed handoff and exposes retry state")
	server.fail_release = false
	var departed := flow._mark_sortie_departed()
	var released := departed.get("network_release", {}) as Dictionary
	var flying_packet := (released.get("publication", {}) as Dictionary).get("packet", {}) as Dictionary
	var released_entity := server.get_landing_entity(bomber.get_ship_id())
	_check(bool(departed.get("accepted", false))
		and bool(released.get("accepted", false))
		and int(released.get("entity_generation", 0)) == 2
		and released_entity.get("state") == &"flying"
		and int(released_entity.get("entity_generation", 0)) == 2
		and not berth.is_occupied() and not berth.is_reserved(),
		"successful retry retires network occupancy before freeing the physical berth")
	_check(bool(client.consume_landing_snapshot(flying_packet).get("accepted", false))
		and int((flying_packet.get("landing", {}) as Dictionary).get("entity_generation", 0)) == 2,
		"client receives the newer flying generation as presentation only")
	_check(flow._reserve_berth_for_ship(bomber, berth.get_berth_id(), false)
		and bool(flow._begin_network_landing_handoff(bomber, berth).get("accepted", false)),
		"released target can admit a fresh physical reservation on the newer generation")
	flow._landing_request_active = true
	flow._active_landing_berth_id = berth.get_berth_id()
	server.fail_abort = true
	flow._on_landing_aborted(&"injected_abort", bomber)
	_check(flow._landing_request_active
		and flow._active_landing_berth_id == berth.get_berth_id()
		and berth.is_reserved()
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landing_pending",
		"rejected server abort retains landing flags and the physical reservation")
	_check((flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"landing_pending"
		and not bool(flow._last_network_landing_handoff_result.get("mutation_committed", true))
		and bool(flow._last_network_landing_handoff_result.get("retryable", false)),
		"rejected abort retains a retryable uncommitted network handoff")
	server.fail_abort = false
	server.fail_flying_publication = true
	flow._on_landing_aborted(&"injected_abort", bomber)
	_check(flow._landing_request_active and berth.is_reserved()
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"flying"
		and (flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"abort_pending_publication",
		"failed abort publication retains physical state and a resumable committed handoff")
	_check(server.abort_call_count == 2
		and bool(flow._last_network_landing_handoff_result.get("mutation_committed", false))
		and flow._last_network_landing_handoff_result.get("status") == &"network_landing_abort_publication_failed",
		"abort publication failure records committed mutation without clearing local state")
	server.fail_flying_publication = false
	flow._on_landing_aborted(&"injected_abort", bomber)
	_check(server.abort_call_count == 2
		and not flow._landing_request_active
		and flow._active_landing_berth_id.is_empty()
		and not berth.is_reserved()
		and not flow._network_landing_handoffs.has(bomber.get_ship_id()),
		"abort retry publishes flying without repeating mutation, then releases physical state")
	_check(flow._reserve_berth_for_ship(bomber, berth.get_berth_id(), false)
		and berth.occupy(
			bomber,
			StringName(flow._berth_tokens.get(bomber.get_instance_id(), &"")),
		), "planetary completion starts with exact physical occupancy and no network handoff")
	flow._landing_request_active = true
	flow._active_landing_berth_id = berth.get_berth_id()
	flow._planetary_return_physical_arrival_required = true
	flow.phase = GameFlow.Phase.RETURN_TO_YARD
	bomber._landing_berth_id = berth.get_berth_id()
	bomber._landing_contract = {
		"contract_accepted": true,
		"strict_dock_acceptance": true,
	}
	server.fail_landed_publication = true
	flow._on_landing_completed(bomber)
	var planetary_failure := flow._last_network_landing_handoff_result
	_check(not bool(planetary_failure.get("accepted", false))
		and bool(planetary_failure.get("mutation_committed", false))
		and bool(planetary_failure.get("retryable", false))
		and planetary_failure.get("status") == &"network_landing_commit_publication_failed",
		"planetary completion observes landed publication failure as retryable")
	_check(berth.is_occupied() and flow._landing_request_active
		and flow.planetary_completion_calls == 0
		and (flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"landed",
		"planetary bypass begins the shared handoff and retains physical occupancy before terminal completion")
	server.fail_landed_publication = false
	flow._on_landing_completed(bomber)
	_check(flow.planetary_completion_calls == 1
		and bool(flow._last_network_landing_handoff_result.get("accepted", false))
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landed"
		and berth.is_occupied(),
		"planetary retry republishes the committed handoff then completes exactly once")
	_check(bool(flow._release_network_landing_handoff(bomber, berth).get("accepted", false)),
		"planetary test cleanup retires the committed network landing")
	flow._release_ship_berth(bomber)
	server.free()
	client.free()
	flow.free()
	hud.queue_free()
	bomber.queue_free()
	world.queue_free()
	await process_frame
	await _shared_aurora_home_publication_retry()
	if _failures.is_empty():
		print("OK: GameFlow landing network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
	else:
		print("PASS: " + description)


## Bounded home-handoff setup only. This fixture does not fly to Aurora or
## manufacture a travel receipt. The real host pilot, confirmed cabin crew,
## physical berth assist, publication failure and retry owners run at Mudds.
func _shared_aurora_home_publication_retry() -> void:
	var filesystem := SurveyFilesystem.new()
	var store := UserDataStore.new("memory://shared-aurora.json", filesystem)
	var game := MainScene.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store)
	root.add_child(game)
	set_multiplayer(SceneMultiplayer.new(), game.get_path())
	await process_frame
	await physics_frame
	game.start_shift()
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var home := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	game._release_ship_berth(craft)
	craft.global_transform = home.get_assist_capture_transform()
	craft.velocity = Vector3.ZERO
	game.player.teleport_to(Transform3D(craft.global_basis.orthonormalized(), craft.get_boarding_position()))
	game._board_ship(craft)
	var piloting := await _wait_until(func(): return game._piloting and game.player.is_seated_at(craft.get_pilot_seat_anchor()) \
		and not game._transition_busy, 12.0)
	_check(piloting, "bounded home retry uses the actual Halyard host pilot")
	if not piloting:
		game.queue_free()
		await process_frame
		return
	game._retire_network_session(&"home_retry_probe")
	await process_frame
	var server := LandingAdapterProbe.new()
	server.name = GameFlow.NETWORK_SESSION_NODE_NAME
	game.add_child(server)
	game.network_session = server
	for binding: Array in game._network_session_signal_bindings():
		game._connect_signal_once(server, StringName(binding[0]), binding[1] as Callable)
	game._attach_network_halyard_command_bridge()
	game._attach_network_ship_authority_composition()
	var port_probe := UDPServer.new()
	var port_ready := port_probe.listen(0, "127.0.0.1") == OK
	var port := port_probe.get_local_port() if port_ready else 0
	port_probe.stop()
	game._ensure_lan_discovery().discovery_port = 0
	_check(port_ready and bool(game.host_network_session(port, 2).get("accepted", false)), "bounded retry opens the real authoritative host session")
	var branch := SubViewport.new()
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var client := Adapter.new()
	client.name = GameFlow.NETWORK_SESSION_NODE_NAME
	branch.add_child(client)
	client.join("127.0.0.1", port)
	var admitted := await _wait_until(func(): return not client.get_server_offer().is_empty(), 10.0)
	_check(admitted, "bounded retry admits a real independent crew adapter")
	var peer := client.multiplayer.get_unique_id()
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var ship_id := craft.get_ship_id()
	game._ensure_network_boarding_ship_registered(craft)
	var request: Dictionary = BoardingIntent.create(peer, avatar, ship_id, 1, StringName("frame_%s" % ship_id), 1,
		GameFlow.network_cabin_berth_seat_id(ship_id, 1), 1, GameFlow.NETWORK_CABIN_BERTH_ROLE,
		1, server.get_boarding_server_tick(), BoardingIntent.ACTION_BOARD).to_dictionary()
	_check(bool(client.send_boarding_intent(request).get("accepted", false)), "crew uses the real authenticated cabin boarding ledger")
	var boarded := await _wait_until(func(): return game.get_network_remote_body_simulation() != null \
		and game.get_network_remote_body_simulation().has_body(avatar), 12.0)
	_check(boarded, "confirmed cabin occupancy owns a real retained crew body")
	if not boarded:
		client.shutdown()
		game.shutdown_network_session(&"test_failed")
		branch.queue_free()
		game.queue_free()
		await process_frame
		return
	var simulation := game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var frame := craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	await _shared_aurora_coastal_observations(game, server, client, craft, body, filesystem, store)
	var bridge := game._network_planetary_journey
	bridge._epoch = 1
	bridge._craft_instance_id = craft.get_instance_id()
	bridge._pilot_source_ref = weakref(craft.get_command_source())
	bridge._state = {"journey_epoch": 1, "world_id": &"aurora_temperate_world", "ship_id": ship_id, "phase": &"returning"}
	bridge._home_return_context = {"session_id": server.get_instance_id(), "session_epoch": game._network_hud_session_epoch,
		"journey_epoch": 1, "world_id": &"aurora_temperate_world", "player_id": game.player.get_instance_id(),
		"home_id": home.get_instance_id(), "home_berth_id": home.get_berth_id()}
	bridge._home_return_crew = bridge._current_cabin_crew().crew
	bridge._home_approach = true
	game._planetary_journey._aurora_return_handoff_ready = true
	game._sortie_departed_berth = true
	game._return_registered = false
	game.phase = GameFlow.Phase.FREE_FLIGHT
	server.fail_landed_publication = true
	game._try_request_landing()
	_check(craft.is_landing_active() and game._landing_request_active, "ordinary home assist owns a real pending physical and network landing")
	var docked := await _wait_until(func(): return not craft.is_landing_active() and home.get_occupant() == craft \
		and server.landed_publication_failures > 0, 12.0)
	_check(docked and craft.get_landing_contract_report().get("phase") == HeroShip.LANDING_PHASE_DOCKED,
		"real home docking reaches occupied DOCKED despite injected landed publication rejection")
	game.set_physics_process(false)
	var ship_pose := craft.global_transform
	var pilot_pose := game.player.global_transform
	var body_pose := body.global_transform
	var body_parent := body.get_parent()
	var crew := bridge._home_return_crew.duplicate(true)
	var context := bridge._home_return_context.duplicate(true)
	var token := home.get_reservation_token(craft)
	_check(game._landing_request_active and game._active_landing_berth_id == home.get_berth_id()
		and not game._return_registered and game.phase == GameFlow.Phase.FREE_FLIGHT,
		"failed local landed publication retains ordinary completion intent for retry")
	bridge.after_world_tick()
	_check(bridge.is_active() and server.journey_retirements == 0 and bridge._home_return_crew == crew
		and bridge._home_return_context == context and home.get_reservation_token(craft) == token
		and simulation.get_body(avatar) == body and body.get_parent() == body_parent
		and frame.is_occupant_registered(body) and craft.global_transform == ship_pose
		and game.player.global_transform == pilot_pose and body.global_transform == body_pose,
		"publication rejection retains journey, exact bodies, poses, parent and occupied lease without recall")
	server.fail_landed_publication = false
	game._advance_network_remote_landing_handoffs()
	_check(game.phase == GameFlow.Phase.SHUT_DOWN and game._return_registered
		and server.landed_publication_successes == 1 and not game._landing_request_active,
		"normal per-craft heartbeat republishes and finishes local landing once")
	var handoff: Dictionary = game._network_landing_handoffs[ship_id].duplicate(true)
	for changed: Dictionary in [{"target_id": &"retired_home"}, {"physical_token": &"retired_home_lease"},
			{"entity_generation": int(handoff.entity_generation) - 1}]:
		var stale := handoff.duplicate(true)
		stale.merge(changed, true)
		game._network_landing_handoffs[ship_id] = stale
		bridge.after_world_tick()
		_check(bridge.is_active() and server.journey_retirements == 0 and simulation.get_body(avatar) == body
			and craft.global_transform == ship_pose and body.global_transform == body_pose,
			"stale home landing target/token/generation cannot retire the retained crew journey")
	game._network_landing_handoffs[ship_id] = handoff
	bridge.after_world_tick()
	game._advance_network_remote_landing_handoffs()
	bridge.after_world_tick()
	_check(not bridge.is_active() and server.journey_retirements == 1 and server.landed_publication_successes == 1
		and game.phase == GameFlow.Phase.SHUT_DOWN and game._return_registered
		and simulation.get_body(avatar) == body and body.get_parent() == body_parent
		and frame.is_occupant_registered(body) and body.is_cabin_containment_active()
		and craft.global_transform == ship_pose and game.player.global_transform == pilot_pose and body.global_transform == body_pose
		and home.get_reservation_token(craft) == token and home.get_occupant() == craft,
		"successful ordinary publication permits one retirement with unchanged actors and no duplicate completion")
	client.shutdown()
	game.shutdown_network_session(&"test_complete")
	branch.queue_free()
	game.queue_free()
	await process_frame
	await physics_frame


func _wait_until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await physics_frame
		await process_frame
	return false


## Staged feature fixture: one production-streamed world and physical dock.
## It exercises authenticated crew observations, not canonical world travel.
func _shared_aurora_coastal_observations(game: GameFlow, server: Adapter, client: Adapter, craft: HeroShip, body: PlayerController, filesystem: SurveyFilesystem, store: UserDataStore) -> void:
	game.set_physics_process(false)
	var owner := game._aurora_expedition
	var bootstrap := game.aurora_streaming_bootstrap
	var binding := game.aurora_streaming_binding
	_check(bool(game._planetary_journey.admit_aurora_visit(craft, false).get("accepted", false)), "staged survey admits the actual Aurora visit lane")
	craft.global_position = bootstrap.global_position + Vector3(0, 120030, 30)
	var sample := {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}
	binding.physics_tick_from_caller_sample(0.0, sample)
	var rebased := game.common_world_origin_rebase_owner.consume_rebase_preview(binding.preview_origin_rebase(bootstrap.get_coordinate_frame_for_session().get_generation()), sample)
	_check(bool(rebased.get("accepted", false)), "staged survey uses the real common origin owner")
	await _wait_until(func(): return is_instance_valid(bootstrap.get_loaded_instance()), 10.0)
	var surface := bootstrap.get_loaded_instance()
	if not is_instance_valid(surface):
		_check(false, "staged survey loads the real coastal scene")
		return
	var region := surface.get_node("LandingRegion") as Node3D
	owner._ship = craft
	owner._home = game.world.get_berth_node(craft.get_home_berth_id())
	owner._surface = surface
	owner._shared_arrival = true
	owner.state = &"landed"
	owner.survey.attach(surface)
	owner._lease_surface_berth(region)
	var berth := owner._berth as ShipBerth
	craft.global_transform = berth.get_assist_capture_transform()
	craft.velocity = Vector3.ZERO
	craft.request_berth_landing(berth)
	_check(await _wait_until(func(): return berth.get_occupant() == craft and not craft.is_landing_active(), 15.0), "staged survey physically docks the retained Halyard on the actual Aurora lease")
	var bridge := game._network_planetary_journey
	bridge._epoch = 1
	bridge._craft_instance_id = craft.get_instance_id()
	bridge._pilot_source_ref = weakref(craft.get_command_source())
	bridge._state = {"journey_epoch": 1, "world_id": &"aurora_temperate_world", "ship_id": craft.get_ship_id(), "phase": &"landed"}
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var avatar := NetworkRemoteBodySimulation.get_remote_body_identity(body).entity_id as StringName
	var simulation := game.get_network_remote_body_simulation()
	# Initial actor staging only; every subsequent coastal leg is real intent movement.
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	body.teleport_to(Transform3D(Basis.IDENTITY, hatch.global_position - Vector3.UP * 0.7))
	for _i in 12:
		await physics_frame
	var peer := client.multiplayer.get_unique_id()
	var seat := GameFlow.network_cabin_berth_seat_id(craft.get_ship_id(), 1)
	var departure: Dictionary = BoardingIntent.create(peer, avatar, craft.get_ship_id(), 1, StringName("frame_%s" % craft.get_ship_id()), 1, seat, 1, GameFlow.NETWORK_CABIN_BERTH_ROLE, 2, server.get_boarding_server_tick(), BoardingIntent.ACTION_DISEMBARK).to_dictionary()
	client.send_boarding_intent(departure)
	var walking := await _wait_until(func(): return simulation.is_surface_walking(avatar), 5.0)
	_check(walking and game._network_aurora_survey_body_is_current(body), "authenticated hatch release retains the actual crew body under the current Aurora surface grant")
	if walking:
		var body_id := body.get_instance_id()
		var sign := surface.find_child("SurveyTrailSign", true, false) as Node3D
		var lookout := surface.find_child("SurveyLookout", true, false) as Node3D
		var stones := surface.find_child("SurveyStones", true, false) as Node3D
		for point in [region.to_global(Vector3(14, 0.5, 2)), sign.global_position + Vector3.UP * 0.5]:
			_check(await _walk_coastal(game, server, client, body, point), "retained crew walks from the actual hatch along the authored trail")
		await _coastal_press(game, server, client, body)
		_check(int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, "real authenticated crew interaction starts the host-owned optional survey")
		await _coastal_press(game, server, client, body)
		_check(int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.FAILED, "crew may abandon the optional survey without losing its return route")
		await _coastal_press(game, server, client, body)
		for point in [region.to_global(Vector3(43, 0.5, -8)), region.to_global(Vector3(57, 0.5, -20)), lookout.global_position + Vector3(-1.5, -1.0, 0)]:
			_check(await _walk_coastal(game, server, client, body, point), "real crew walking remains admitted on the existing coastal terrain and lookout floor")
		await _coastal_press(game, server, client, body)
		_check(int(owner.survey.snapshot().get("next_checkpoint_index", 0)) == 1, "host records the actual lookout observation from the retained crew body")
		_check(await _walk_coastal(game, server, client, body, region.to_global(Vector3(55, 0.5, -20))), "crew returns through the lookout entrance")
		_check(await _walk_coastal(game, server, client, body, stones.global_position + Vector3.UP * 0.5), "crew walks the authored stones branch")
		filesystem.reject_rewards = true
		await _coastal_press(game, server, client, body)
		_check(int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.COMPLETED and not owner.survey.reward_recorded() and filesystem.rejected_rewards > 0, "actual atomic reward write rejection retains completed observations without entitlement")
		bridge._publish(true)
		var shared := bridge.get_snapshot().get("aurora_survey", {}) as Dictionary
		var view := owner.survey.shared_presentation(surface, body, shared) as Dictionary
		_check(str(view.get("prompt", "")).contains("RETRY SAVING"), "shared progress gives crew actionable rejected-save guidance")
		var progress := owner.survey.capture() as Dictionary
		var token := owner._surface_token
		owner._surface_token = &"expired_surface_lease"
		_check(not game._interact_network_aurora_survey(body), "current host refuses a stale surface lease before any progression")
		_check(owner.survey.capture() == progress and not owner.survey.reward_recorded(), "stale surface lease cannot submit or reward observations")
		owner._surface_token = token
		filesystem.reject_rewards = false
		await _coastal_press(game, server, client, body)
		await _coastal_press(game, server, client, body)
		var loaded := UserDataStore.new("memory://shared-aurora.json", filesystem)
		loaded.load()
		var authority := GameFlowRewardAuthority.new()
		var configured := authority.configure(loaded)
		_check(bool(configured.get("accepted", false)) and owner.survey.reward_recorded() and int(authority.get_snapshot().record.reward_counts.get("aurora_coastal_survey_data", 0)) == 1, "accepted retry persists Aurora data once across real store reload and repeated crew presses")
		_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id, "survey progress and save retries retain the same host-owned body")
	# This bounded fixture finishes its surface attachment before the existing
	# home-handoff publication test; it does not claim a physical return voyage.
	if walking and is_instance_valid(body):
		for point in [region.to_global(Vector3(55, 0.5, -20)), region.to_global(Vector3(43, 0.5, -8)), region.to_global(Vector3(30, 0.5, 0)), region.to_global(Vector3(14, 0.5, 2)), craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), craft.to_global(Vector3(0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))]:
			_check(await _walk_coastal(game, server, client, body, point), "survey crew physically follows the trail and airstair back into the cabin")
		var reboard: Dictionary = BoardingIntent.create(peer, avatar, craft.get_ship_id(), 1, StringName("frame_%s" % craft.get_ship_id()), 1, seat, 1, GameFlow.NETWORK_CABIN_BERTH_ROLE, 3, server.get_boarding_server_tick(), BoardingIntent.ACTION_BOARD).to_dictionary()
		client.send_boarding_intent(reboard)
		_check(await _wait_until(func(): return not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active(), 5.0), "ordinary authenticated reboard retains the survey body and restores the return manifest")
		_check(bridge.shared_aurora_return_gate_reason().is_empty(), "optional Aurora survey leaves the existing shared return admission usable")
	owner._release_surface_lease()
	owner.state = &"idle"
	owner._ship = null
	owner._surface = null
	owner._shared_arrival = false
	game._planetary_journey.retire_aurora_visit()
	bridge._state.clear()
	craft.global_transform = game.world.get_berth_node(craft.get_home_berth_id()).get_assist_capture_transform()
	var home_sample := {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}
	binding.physics_tick_from_caller_sample(0.0, home_sample)
	game.common_world_origin_rebase_owner.consume_rebase_preview(binding.preview_origin_rebase(bootstrap.get_coordinate_frame_for_session().get_generation()), home_sample)
	game.set_physics_process(true)


func _coastal_tick(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3) -> void:
	var tick := Engine.get_physics_frames()
	server.set_movement_server_tick(tick)
	if tick % 4 == 0:
		var direction := target - body.global_position
		var moving := Vector2(direction.x, direction.z).length() > 0.8
		var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
		var packet: Dictionary = NetworkMovementIntent.create(client.multiplayer.get_unique_id(), identity.entity_id, int(identity.entity_generation), 1001, _coastal_sequence, tick, Vector2(0, -1) if moving else Vector2.ZERO, false, &"", false, atan2(-direction.x, -direction.z), 0.0, false, false, false, _coastal_interaction).to_dictionary()
		_coastal_sequence += 1
		client.send_movement_intent(packet)
	game.get_network_remote_body_simulation().advance(tick)
	await physics_frame


func _walk_coastal(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < deadline and is_instance_valid(body):
		await _coastal_tick(game, server, client, body, target)
		if Vector2(body.global_position.x - target.x, body.global_position.z - target.z).length() < 1.0 and body.is_on_floor():
			return true
	return false


func _coastal_press(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController) -> void:
	_coastal_interaction += 1
	var position := body.global_position
	for _i in 12:
		await _coastal_tick(game, server, client, body, position)
