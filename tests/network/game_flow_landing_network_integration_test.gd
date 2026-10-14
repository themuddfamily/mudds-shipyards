extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const Ship := preload("res://scripts/ships/hero_ship.gd")
const ShipDefinition := preload("res://assets/ships/torrent_provisional.tres")
const Berth := preload("res://scripts/world/ship_berth.gd")
const MainScene := preload("res://scenes/main.tscn")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")

var _survey_restart_phase := 0
var _survey_restart_filesystem: SurveyFilesystem
var _interrupted_body_ref: WeakRef
var _interrupted_context: Dictionary = {}
var _interrupted_avatar: StringName = &""
var _coastal_replica: Dictionary = {}
var _coastal_sequence := 0
var _coastal_interaction := 0
var _assertions := 0
var _failures := PackedStringArray()


class SurveyFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var reject_checkpoints := false
	var rejected_checkpoints := 0
	var reject_rewards := false
	var rejected_rewards := 0
	func file_exists(path: String) -> bool:
		return files.has(path)
	func directory_exists(_path: String) -> bool:
		return false
	func ensure_parent_directory(_path: String) -> Error:
		return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes: PackedByteArray = files[path]
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT, "bytes": bytes.duplicate()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_checkpoints and document is Dictionary and str((document.get("commit", {}) as Dictionary).get("id", "")).begins_with("aurora-shared-survey-"):
			rejected_checkpoints += 1
			return ERR_CANT_CREATE
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
	if OS.get_cmdline_user_args().has("--rime-pad-only"):
		await _shared_rime_pad_access()
		if _failures.is_empty():
			print("OK: Rime shared pad integration (%d assertions)" % _assertions)
			quit(0)
		else:
			for failure in _failures:
				push_error(failure)
			quit(1)
		return
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
	await _shared_rime_pad_access()
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


## One staged Rime pad/lease; movement after exterior admission is real intent
## movement. This does not qualify canonical travel or the ice-core survey.
func _shared_rime_pad_access() -> void:
	var game := MainScene.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(UserDataStore.new("memory://rime-pad.json", SurveyFilesystem.new()))
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
	game.player.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position()))
	game._board_ship(craft)
	var piloting := await _wait_until(func(): return game._piloting and not game._transition_busy, 12.0)
	_check(piloting, "Rime pad fixture owns a real retained Halyard host pilot")
	var probe := UDPServer.new()
	var port_ready := probe.listen(0, "127.0.0.1") == OK
	var port := probe.get_local_port() if port_ready else 0
	probe.stop()
	game._ensure_lan_discovery().discovery_port = 0
	var hosted := port_ready and bool(game.host_network_session(port, 2).get("accepted", false))
	var branch := SubViewport.new()
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var client := Adapter.new()
	client.name = GameFlow.NETWORK_SESSION_NODE_NAME
	branch.add_child(client)
	if hosted:
		client.join("127.0.0.1", port)
	var admitted := hosted and await _wait_until(func(): return not client.get_server_offer().is_empty(), 10.0)
	_check(piloting and admitted, "Rime pad crew is admitted over the real authenticated ENet session")
	if piloting and admitted:
		var peer := client.multiplayer.get_unique_id()
		var avatar := GameFlow.network_client_boarding_avatar_id(peer)
		game._ensure_network_boarding_ship_registered(craft)
		var boarding := _rime_boarding_request(game, client, craft, 1, BoardingIntent.ACTION_BOARD)
		client.send_boarding_intent(boarding)
		var boarded := await _wait_until(func(): return game.get_network_remote_body_simulation() != null and game.get_network_remote_body_simulation().has_body(avatar), 12.0)
		_check(boarded, "Rime crew starts as the actual confirmed cabin body")
		if boarded:
			await _rime_pad_body_route(game, client, craft, avatar)
	client.shutdown()
	game.shutdown_network_session(&"rime_pad_fixture_done")
	_check(game._network_ember_passenger_surfaces.is_empty(), "Rime session retirement disposes the retained surface contexts")
	branch.queue_free()
	game.queue_free()
	await process_frame
	await physics_frame


func _rime_boarding_request(game: GameFlow, client: Adapter, craft: HeroShip, sequence: int, action: StringName) -> Dictionary:
	var peer := client.multiplayer.get_unique_id()
	return BoardingIntent.create(peer, GameFlow.network_client_boarding_avatar_id(peer), craft.get_ship_id(), 1,
		StringName("frame_%s" % craft.get_ship_id()), 1, GameFlow.network_cabin_berth_seat_id(craft.get_ship_id(), 1), 1,
		GameFlow.NETWORK_CABIN_BERTH_ROLE, sequence, game.network_session.get_boarding_server_tick(), action).to_dictionary()


func _rime_pad_body_route(game: GameFlow, client: Adapter, craft: HeroShip, avatar: StringName) -> void:
	game.set_physics_process(false)
	var owner := game._rime_expedition
	var bootstrap := game.rime_streaming_bootstrap
	var binding := game.rime_streaming_binding
	var lane := game._planetary_journey.admit_aurora_visit(craft, false, &"rime_glacial_world")
	_check(bool(lane.get("accepted", false)), "Rime pad uses the exact existing world visit lane")
	craft.global_position = bootstrap.global_position + Vector3(0, 120030, 30)
	var sample := {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}
	binding.physics_tick_from_caller_sample(0.0, sample)
	var rebase := game.common_world_origin_rebase_owner.consume_rebase_preview(binding.preview_origin_rebase(bootstrap.get_coordinate_frame_for_session().get_generation()), sample)
	_check(bool(rebase.get("accepted", false)), "Rime pad commits through the actual common origin owner")
	var loaded := await _wait_until(func(): return is_instance_valid(bootstrap.get_loaded_instance()), 10.0)
	_check(loaded, "Rime pad loads its own authored production scene")
	if not loaded:
		return
	var surface := bootstrap.get_loaded_instance()
	var region := surface.get_node("LandingRegion") as Node3D
	owner._ship = craft
	owner._home = game.world.get_berth_node(craft.get_home_berth_id())
	owner._surface = surface
	owner._shared_arrival = true
	owner.state = &"landing"
	owner.survey.attach(surface)
	owner._lease_surface_berth(region)
	var berth := owner._berth as ShipBerth
	craft.global_transform = berth.get_assist_capture_transform()
	craft.velocity = Vector3.ZERO
	craft.request_berth_landing(berth)
	var docked := await _wait_until(func(): return berth.get_occupant() == craft and not craft.is_landing_active(), 15.0)
	_check(docked, "Rime's actual physical berth owns the same docked craft and lease")
	if not docked:
		return
	owner.physics_tick(0.0)
	_check(await _wait_until(func(): return craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_OFFLINE, 5.0), "Rime visit performs its ordinary docked propulsion shutdown")
	var bridge := game._network_planetary_journey
	bridge._epoch = 1
	bridge._craft_instance_id = craft.get_instance_id()
	bridge._pilot_source_ref = weakref(craft.get_command_source())
	bridge._state = {"journey_epoch": 1, "world_id": &"rime_glacial_world", "ship_id": craft.get_ship_id(), "phase": &"landed"}
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var simulation := game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var body_id := body.get_instance_id()
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	# The only crew placement precedes exterior admission, at the real hatch.
	body.teleport_to(Transform3D(Basis.IDENTITY, hatch.global_position - Vector3.UP * 0.7))
	for _tick in 12:
		await physics_frame
	client.send_boarding_intent(_rime_boarding_request(game, client, craft, 2, BoardingIntent.ACTION_DISEMBARK))
	var walking := await _wait_until(func(): return simulation.is_surface_walking(avatar), 5.0)
	print("RIME_PAD_DEPARTURE: walking=", walking, " answer=", client.get_boarding_intent_result_replica())
	_check(walking and simulation.get_body(avatar) == body, "authenticated Rime hatch departure retains the same actual walking crew body")
	if not walking:
		return
	_check(absf(body.gravity_multiplier - 1.0) < 0.02, "Rime retained crew uses its actual world and ordinary project gravity")
	_coastal_sequence = 0
	_coastal_interaction = 0
	if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(Vector3(-44, 0.5, -8)), "retained Rime body walks ordinary intents to the actual pad edge"):
		return
	for _tick in 180:
		if not is_instance_valid(body):
			break
		await _coastal_tick(game, game.network_session, client, body, region.to_global(Vector3(-70, 0.5, -8)))
	var safe := is_instance_valid(body) and simulation.get_body(avatar) == body and game._network_ember_passenger_surface_is_current(avatar)
	_check(safe, "ordinary outward Rime input stops at actual supported pad footprint without losing the same body")
	if not safe:
		return
	_check(int(body.get("_rime_pad_blocked_steps")) > 0 and body.get_instance_id() == body_id, "real pad boundary rejects unsupported steps without replacement or cabin recall")
	_check(bridge.shared_surface_return_gate_reason(&"rime_glacial_world") == &"shared_rime_return_requires_reboarded_crew",
		"Rime return requires exterior crew to physically reboard")
	var initial_height := body.global_position.y
	var jump_peak := initial_height
	for tick in 100:
		await _coastal_tick(game, game.network_session, client, body, region.to_global(Vector3(-70, 0.5, -8)), tick < 4)
		jump_peak = maxf(jump_peak, body.global_position.y)
	_check(jump_peak > initial_height + 0.2 and body.is_on_floor() and game._network_ember_passenger_surface_is_current(avatar),
		"Rime boundary preserves a real intent-driven jump, vertical gravity and subsequent floor contact")
	var tangent_start := region.to_local(body.global_position).z
	for tick in 100:
		await _coastal_tick(game, game.network_session, client, body, region.to_global(Vector3(-70, 0.5, 12)))
	_check(region.to_local(body.global_position).z > tangent_start + 1.0 and game._network_ember_passenger_surface_is_current(avatar),
		"blocked outward Rime input preserves supported tangential walking")
	var context: Dictionary = game._network_ember_passenger_surfaces[avatar]
	var previous_guard_token := StringName(context.pad_guard_token)
	game._bind_network_rime_pad_guard(body, context, Callable(game, "_network_ember_passenger_surface_owner_is_current").bind(avatar, context))
	body.clear_rime_pad_step_guard(previous_guard_token)
	_check(StringName(body.get("_rime_pad_guard_token")) == StringName(context.pad_guard_token)
		and context.pad_guard_token != previous_guard_token, "a superseded guard owner cannot clear the current body's boundary")
	for field in ["journey_epoch", "location_generation", "session_id", "session_epoch", "entity_generation", "scene_id", "body_id"]:
		var previous: Variant = context[field]
		context[field] = int(previous) + 1
		_check(not game._network_ember_passenger_surface_is_current(avatar), "Rime surface rejects stale " + field)
		context[field] = previous
	var token := owner._surface_token
	owner._surface_token = &"retired_rime_token"
	_check(not game._network_ember_passenger_surface_is_current(avatar), "Rime cannot use another physical pad lease")
	owner._surface_token = token
	bridge._state.world_id = &"unsupported_world"
	_check(not game._network_ember_passenger_surface_is_current(avatar) and game._network_passenger_surface_bootstrap() == null,
		"unknown world cannot borrow Ember, Aurora or Rime support")
	bridge._state.world_id = &"rime_glacial_world"
	for point in [region.to_global(Vector3(-8, 0.5, -8)), craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), craft.to_global(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, point, "same Rime body reverses ordinary input and walks back through the physical hatch"):
			return
	client.send_boarding_intent(_rime_boarding_request(game, client, craft, 3, BoardingIntent.ACTION_BOARD_ANY))
	var reboarded := await _wait_until(func(): return not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active(), 5.0)
	_check(reboarded and simulation.get_body(avatar) == body and body.get_instance_id() == body_id,
		"authenticated Rime reboard restores cabin containment on the same body")
	_check(str(body.get("_rime_pad_guard_token")).is_empty(), "Rime reboard clears only its owned pad movement guard")
	_check(bool(owner.runtime_state().action_enabled) and bridge.shared_surface_return_gate_reason(&"rime_glacial_world").is_empty()
		and int(owner.survey.snapshot().get("state", CheckpointRouteActivity.State.IDLE)) == CheckpointRouteActivity.State.IDLE
		and not owner.survey.reward_recorded(), "reboarded Rime crew can return without admitting or rewarding the unsupported ice-core survey")
	var saved_epoch := bridge._epoch
	bridge._epoch += 1
	_check(not owner.request() and bridge._home_return_context.is_empty(), "a stale Rime journey epoch cannot start home return")
	bridge._epoch = saved_epoch
	_check(not bridge.admit_shared_surface_return(&"aurora_temperate_world") and bridge._home_return_context.is_empty(),
		"Rime cannot borrow another world's return authority")
	var home := owner._home as ShipBerth
	var home_parent := home.get_parent()
	home_parent.remove_child(home)
	_check(not owner.request() and bridge._home_return_context.is_empty(), "missing physical home berth refuses Rime return")
	home_parent.add_child(home)
	var return_pose := craft.global_transform
	var return_body_pose := body.global_transform
	_check(owner.request() and owner.state == &"return_cruise" and game._planetary_journey.is_return_departure_pending()
		and craft.global_transform == return_pose and body.global_transform == return_body_pose and berth.get_occupant() == craft,
		"authenticated Rime return queues manual takeoff with unchanged actors and occupied surface lease")
	for field in ["session_id", "session_epoch", "journey_epoch", "scene_id", "location_generation", "home_id"]:
		var previous: Variant = bridge._home_return_context[field]
		bridge._home_return_context[field] = int(previous) + 1
		_check(not bridge._home_return_actors_are_current(), "Rime return rejects stale retained " + field)
		bridge._home_return_context[field] = previous
	var return_world: Variant = bridge._home_return_context.world_id
	bridge._home_return_context.world_id = &"aurora_temperate_world"
	_check(not bridge._home_return_actors_are_current(), "Rime return rejects a different retained world")
	bridge._home_return_context.world_id = return_world
	var return_token: Variant = bridge._home_return_context.surface_token
	bridge._home_return_context.surface_token = &"retired_rime_return_lease"
	_check(not bridge._home_return_actors_are_current(), "Rime return rejects a stale physical surface lease")
	bridge._home_return_context.surface_token = return_token
	game._planetary_journey.cancel_return_departure(&"focused_return_withdrawn")
	owner.physics_tick(0.0)
	bridge._after_surface_arrival_tick()
	_check(owner.state == &"landed" and bridge._home_return_context.is_empty() and craft.global_transform == return_pose
		and body.global_transform == return_body_pose and berth.get_occupant() == craft,
		"withdrawing Rime return before takeoff preserves the same reboarded crew, pad lease and retry controls")
	# Real support loss ends this final admission; never restore a removed floor
	# and pretend the old authority is still current or place a replacement body.
	client.send_boarding_intent(_rime_boarding_request(game, client, craft, 4, BoardingIntent.ACTION_DISEMBARK))
	_check(await _wait_until(func(): return simulation.is_surface_walking(avatar), 5.0), "same reboarded Rime crew can make a fresh authenticated hatch departure")
	var pad := surface.get_node("LandingRegion/WalkablePatch/CollisionShape3D") as CollisionShape3D
	pad.disabled = true
	_check(not game._network_ember_passenger_surface_is_current(avatar), "Rime refuses missing actual scene-owned physical floor")
	game._advance_network_remote_bodies(Engine.get_physics_frames())
	await physics_frame
	_check(not simulation.has_body(avatar) and game._network_ember_passenger_surfaces.is_empty(),
		"actual Rime floor loss retires the old body and grant without a fabricated floor or cabin recall")


## Bounded home-handoff setup only. This fixture does not fly to Aurora or
## manufacture a travel receipt. The real host pilot, confirmed cabin crew,
## physical berth assist, publication failure and retry owners run at Mudds.
func _shared_aurora_home_publication_retry() -> void:
	if _survey_restart_filesystem == null:
		_survey_restart_filesystem = SurveyFilesystem.new()
	var filesystem := _survey_restart_filesystem
	var store := UserDataStore.new("memory://shared-aurora.json", filesystem)
	var game := MainScene.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store)
	root.add_child(game)
	set_multiplayer(SceneMultiplayer.new(), game.get_path())
	await process_frame
	await physics_frame
	game.start_shift()
	if _survey_restart_phase == 2:
		_check(not game._aurora_expedition.is_active() and not game._planetary_journey.is_aurora_visit_active() and not game._network_session_is_live()
			and game.get_network_remote_body_simulation() == null and game._network_ember_passenger_surfaces.is_empty(), "fresh Main keeps interrupted shared progress passive at Mudds without crew, session or lease restoration")
		_check(not game.restore_shared_aurora_survey_checkpoint().get("accepted", false), "offline startup cannot adopt a shared host survey checkpoint")
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
	if not await _shared_aurora_coastal_observations(game, server, client, craft, body, filesystem, store):
		client.shutdown()
		game.shutdown_network_session(&"coastal_fixture_failed")
		branch.queue_free()
		game.queue_free()
		await process_frame
		return
	if _survey_restart_phase == 1:
		_interrupted_body_ref = weakref(body)
		_interrupted_context = game._network_ember_passenger_surfaces[avatar].duplicate(true)
		_interrupted_avatar = avatar
		game.shutdown_network_session(&"survey_interrupted")
		print("COASTAL_SHUTDOWN state=", game._aurora_expedition.state, " phase=", game.phase, " grants=", game._network_ember_passenger_surfaces.size(), " remote_body=", simulation.has_body(avatar), " home_distance_m=", craft.global_position.distance_to(home.get_dock_transform().origin), " player_seated=", game.player.is_seated(), " controls=", game.player.is_control_enabled())
		_check(game._aurora_expedition.state in [&"retiring", &"idle"] and game._network_ember_passenger_surfaces.is_empty()
			and not simulation.has_body(avatar) and game.phase == GameFlow.Phase.APPROACH_SHIP
			and craft.global_position.distance_to(home.get_dock_transform().origin) < 0.05
			and not game.player.is_seated() and game.player.is_control_enabled(), "actual interrupted host shutdown immediately restores its safe-home actors and retires old crew grants")
		game.set_physics_process(true)
		_check(await _wait_until(func(): return not game._aurora_expedition.is_active() and not game._planetary_journey.is_aurora_visit_active() \
			and not is_instance_valid(game.aurora_streaming_bootstrap.get_loaded_instance()), 6.0), "ordinary bounded wind-down completes home origin recovery and retires the old surface visit")
		client.shutdown()
		branch.queue_free()
		game.queue_free()
		await process_frame
		await physics_frame
		_survey_restart_phase = 2
		await _shared_aurora_home_publication_retry()
		return
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
func _shared_aurora_coastal_observations(game: GameFlow, server: Adapter, client: Adapter, craft: HeroShip, body: PlayerController, filesystem: SurveyFilesystem, store: UserDataStore) -> bool:
	_coastal_replica.clear()
	_coastal_sequence = 0
	_coastal_interaction = 0
	client.planetary_journey_state_received.connect(_capture_coastal_state)
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
		return false
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
	await _wait_until(func(): return game._network_aurora_passenger_host_is_current(craft), 5.0)
	owner.physics_tick(0.0)
	if _survey_restart_phase == 2:
		_check(int(owner.survey.snapshot().get("next_checkpoint_index", 0)) == 1 and int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, "fresh current host Aurora admission restores the genuine interrupted lookout progress on its actual scene")
		_check(_interrupted_body_ref.get_ref() == null and not game._network_ember_passenger_surface_is_current(_interrupted_avatar, _interrupted_context), "new host admission never resurrects the retired body's old surface grant")
		var original_payload := store.get_snapshot()
		var foreign_payload := original_payload.duplicate(true)
		foreign_payload[GameFlow.AURORA_SHARED_SURVEY_SLOT].craft_home_berth_id = String(game.ship.get_home_berth_id())
		store.commit(foreign_payload, store.get_generation(), "coastal-foreign-craft")
		_check(game.restore_shared_aurora_survey_checkpoint().get("reason") == &"aurora_shared_survey_checkpoint_unavailable" and int(owner.survey.snapshot().get("next_checkpoint_index", 0)) == 1, "another registered craft's checkpoint cannot replace this host's restored observations")
		store.commit(original_payload, store.get_generation(), "coastal-original-craft")
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
	print("COASTAL_HATCH_BEFORE gate=", game._network_boarding_departure_status(peer, departure), " host_current=", game._network_aurora_passenger_host_is_current(craft), " pilot_current=", bridge._surface_arrival_host_is_current(), " eligible=", game._shared_planetary_host_eligible(), " engine=", craft.get_telemetry().get("engine_state"), " lane=", game._planetary_journey.is_aurora_visit_active(), " floor=", body.is_on_floor(), " local=", craft.to_local(body.global_position), " hatch=", craft.to_local(hatch.global_position), " intent=", departure)
	client.send_boarding_intent(departure)
	var walking := await _wait_until(func(): return simulation.is_surface_walking(avatar), 5.0)
	if not walking:
		print("COASTAL_HATCH_AFTER audit=", game.get_network_remote_body_audit(), " answer=", client.get_boarding_intent_result_replica())
	_check(walking and game._network_aurora_survey_body_is_current(body), "authenticated hatch release retains the actual crew body under the current Aurora surface grant")
	if not walking:
		return false
	if walking:
		var body_id := body.get_instance_id()
		var sign := surface.find_child("SurveyTrailSign", true, false) as Node3D
		var lookout := surface.find_child("SurveyLookout", true, false) as Node3D
		var stones := surface.find_child("SurveyStones", true, false) as Node3D
		for point in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), craft.to_global(Vector3(-8, 0.52, 22)), region.to_global(Vector3(14, 0.5, 22)), region.to_global(Vector3(14, 0.5, 2)), sign.global_position + Vector3.UP * 0.5]:
			if not await _checked_coastal_walk(game, server, client, body, point, "retained crew walks from the actual hatch along the authored trail"):
				return false
		if _survey_restart_phase == 0:
			await _coastal_press(game, server, client, body)
			_check(int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, "real authenticated crew interaction starts the host-owned optional survey")
			await _coastal_press(game, server, client, body)
			_check(int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.FAILED, "crew may abandon the optional survey without losing its return route")
			await _coastal_press(game, server, client, body)
		for point in [region.to_global(Vector3(43, 0.5, -8)), region.to_global(Vector3(57, 0.5, -20)), lookout.global_position + Vector3(-1.5, -1.0, 0)]:
			if not await _checked_coastal_walk(game, server, client, body, point, "real crew walking remains admitted on the existing coastal terrain and lookout floor"):
				return false
		if _survey_restart_phase == 0:
			await _coastal_press(game, server, client, body)
		bridge._publish(true)
		_check(await _wait_until(func(): return int((_coastal_replica.get("aurora_survey", {}) as Dictionary).get("progress", {}).get("next_checkpoint_index", 0)) == 1, 3.0), "actual authenticated host publication synchronizes the crew observation progress")
		_check(int(owner.survey.snapshot().get("next_checkpoint_index", 0)) == 1, "host records the actual lookout observation from the retained crew body")
		var interrupted_store := UserDataStore.new("memory://shared-aurora.json", filesystem)
		interrupted_store.load()
		var saved_checkpoint := interrupted_store.get_snapshot().get("aurora_shared_coastal_survey", {}) as Dictionary
		var checkpoint_recorded := interrupted_store.get_loaded_source() == &"primary" and int((saved_checkpoint.get("survey", {}) as Dictionary).get("next_checkpoint_index", 0)) == 1
		_check(checkpoint_recorded, "real shared lookout observation survives a primary atomic-store reload as passive host progress")
		if not checkpoint_recorded:
			return false
		if _survey_restart_phase == 0:
			_survey_restart_phase = 1
			return true
		if not await _checked_coastal_walk(game, server, client, body, region.to_global(Vector3(55, 0.5, -20)), "crew returns through the lookout entrance"):
			return false
		if not await _checked_coastal_walk(game, server, client, body, stones.global_position + Vector3.UP * 0.5, "crew walks the authored stones branch"):
			return false
		filesystem.reject_rewards = true
		filesystem.reject_checkpoints = true
		await _coastal_press(game, server, client, body)
		_check(int(owner.survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.COMPLETED and not owner.survey.reward_recorded() and filesystem.rejected_rewards > 0, "actual atomic reward write rejection retains completed observations without entitlement")
		bridge._publish(true)
		_check(await _wait_until(func(): return int((_coastal_replica.get("aurora_survey", {}) as Dictionary).get("progress", {}).get("state", -1)) == CheckpointRouteActivity.State.COMPLETED, 3.0), "actual host publication delivers completed unpaid observations to the peer")
		var shared := _coastal_replica.get("aurora_survey", {}) as Dictionary
		var view := owner.survey.shared_presentation(surface, body, shared) as Dictionary
		_check(str(view.get("prompt", "")).contains("RETRY SAVING"), "shared progress gives crew actionable rejected-save guidance")
		var progress := owner.survey.capture() as Dictionary
		var token := owner._surface_token
		owner._surface_token = &"expired_surface_lease"
		_check(not game._interact_network_aurora_survey(body), "current host refuses a stale surface lease before any progression")
		_check(owner.survey.capture() == progress and not owner.survey.reward_recorded(), "stale surface lease cannot submit or reward observations")
		owner._surface_token = token
		_check(game._aurora_shared_survey_checkpoint_pending and filesystem.rejected_checkpoints > 0, "actual rejected passive checkpoint write retains a pending unpaid completion for teardown retry")
		filesystem.reject_rewards = false
		var terminal := owner.survey.snapshot() as Dictionary
		terminal["state_id"] = &"completed"
		terminal["outcome"] = &"cleared"
		var paid: Dictionary = owner.survey._adapter.consume(terminal, int(terminal.generation))
		_check(paid.get("accepted", false) and game._aurora_shared_survey_checkpoint_pending, "the real earned terminal callback commits a newer paid reward while the rejected unpaid checkpoint is still pending")
		filesystem.reject_checkpoints = false
		var flushed := game._flush_shared_aurora_survey_checkpoint()
		_check(flushed.get("accepted", false) and not game.restore_shared_aurora_survey_checkpoint().get("accepted", false), "flushing stale unpaid progress preserves the current paid receipt and refuses paid-progress restoration")
		await _coastal_press(game, server, client, body)
		await _coastal_press(game, server, client, body)
		var loaded := UserDataStore.new("memory://shared-aurora.json", filesystem)
		loaded.load()
		var authority := GameFlowRewardAuthority.new()
		var configured := authority.configure(loaded)
		_check(bool(configured.get("accepted", false)) and owner.survey.reward_recorded() and int(authority.get_snapshot().record.reward_counts.get("aurora_coastal_survey_data", 0)) == 1, "accepted retry persists Aurora data once across real store reload and repeated crew presses")
		var primary: PackedByteArray = filesystem.files["memory://shared-aurora.json"]
		filesystem.files["memory://shared-aurora.json"] = "broken primary".to_utf8_buffer()
		var backup := UserDataStore.new("memory://shared-aurora.json", filesystem)
		backup.load_read_only()
		game._runtime_settings_user_data_store = backup
		_check(backup.get_loaded_source() == &"backup" and game.restore_shared_aurora_survey_checkpoint().get("reason") == &"aurora_shared_survey_store_recovery_required", "actual older-backup adoption cannot resurrect interrupted observations after a newer paid primary")
		bridge._publish(true)
		_check(await _wait_until(func(): return (_coastal_replica.get("aurora_survey", {}) as Dictionary).get("survey_available") == false, 3.0), "host publishes actual recovery-required survey availability to crew")
		var recovery_view: Dictionary = owner.survey.shared_presentation(surface, body, _coastal_replica.aurora_survey)
		_check(recovery_view.get("prompt") == "SURVEY SAVE RECOVERY REQUIRED" and str(recovery_view.get("objective", "")).contains("reboard whenever ready"), "crew receives actionable survey recovery guidance while return stays optional")
		var refused_save := game.save_interrupted_aurora_visit()
		_check(not refused_save.get("accepted", false) and filesystem.files["memory://shared-aurora.json"] == "broken primary".to_utf8_buffer(), "backup-backed host progress writes cannot overwrite the current primary or paid receipt")
		game._runtime_settings_user_data_store = UserDataStore.new("memory://unloaded-coastal.json", filesystem)
		_check(game.restore_shared_aurora_survey_checkpoint().get("reason") == &"aurora_shared_survey_store_recovery_required", "an unknown/unloaded store cannot supply interrupted survey progress")
		filesystem.files["memory://shared-aurora.json"] = primary
		game._runtime_settings_user_data_store = store
		game._flush_shared_aurora_survey_checkpoint()
		_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id, "survey progress and save retries retain the same host-owned body")
	# This bounded fixture finishes its surface attachment before the existing
	# home-handoff publication test; it does not claim a physical return voyage.
	if walking and is_instance_valid(body):
		for point in [region.to_global(Vector3(52, 0.5, -33)), region.to_global(Vector3(52, 0.5, -27)), region.to_global(Vector3(55, 0.5, -20)), region.to_global(Vector3(43, 0.5, -8)), region.to_global(Vector3(30, 0.5, 0)), region.to_global(Vector3(14, 0.5, 2)), region.to_global(Vector3(14, 0.5, 22)), craft.to_global(Vector3(-8, 0.52, 22)), craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), craft.to_global(Vector3(0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))]:
			if not await _checked_coastal_walk(game, server, client, body, point, "survey crew physically follows the trail and airstair back into the cabin"):
				return false
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
	return true


func _coastal_tick(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3, jump: bool = false) -> void:
	var tick := Engine.get_physics_frames()
	server.set_movement_server_tick(tick)
	if tick % 4 == 0:
		var direction := target - body.global_position
		var moving := Vector2(direction.x, direction.z).length() > 0.8
		var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
		var packet: Dictionary = NetworkMovementIntent.create(client.multiplayer.get_unique_id(), identity.entity_id, int(identity.entity_generation), 1001, _coastal_sequence, tick, Vector2(0, -1) if moving else Vector2.ZERO, false, &"", false, atan2(-direction.x, -direction.z), 0.0, false, false, jump, _coastal_interaction).to_dictionary()
		_coastal_sequence += 1
		client.send_movement_intent(packet)
	game.get_network_remote_body_simulation().advance(tick)
	await physics_frame


func _walk_coastal(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < deadline and is_instance_valid(body):
		await _coastal_tick(game, server, client, body, target)
		if not is_instance_valid(body):
			return false
		if Vector2(body.global_position.x - target.x, body.global_position.z - target.z).length() < 1.0 and body.is_on_floor():
			return true
	print("COASTAL_WALK_BLOCKED target=", target, " body_valid=", is_instance_valid(body), " pose=", body.global_position if is_instance_valid(body) else Vector3.INF, " audit=", game.get_network_remote_body_audit())
	return false


func _coastal_press(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController) -> void:
	_coastal_interaction += 1
	var position := body.global_position
	for _i in 12:
		if not is_instance_valid(body):
			return
		await _coastal_tick(game, server, client, body, position)


func _checked_coastal_walk(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3, description: String) -> bool:
	var reached := await _walk_coastal(game, server, client, body, target)
	_check(reached, description)
	return reached


func _capture_coastal_state(packet: Dictionary) -> void:
	_coastal_replica = packet.duplicate(true)
