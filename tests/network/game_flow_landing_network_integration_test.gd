extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BodyIntentSource := preload("res://scripts/network/network_remote_body_intent_source.gd")
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
var _rime_shared_survey_mode := false
var _rime_survey_retirement_case := false
var _rime_intent_source: NetworkRemoteBodyIntentSource
var _rime_jump_held := false
var _rime_last_movement_send: Dictionary = {}
var _rime_last_neutral_packet: Dictionary = {}
var _shared_visit_restore_mode := false
var _shared_visit_restoration_completed := false


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
	if OS.get_cmdline_user_args().has("--restore-shared-rime") or OS.get_cmdline_user_args().has("--restore-shared-aurora"):
		_shared_visit_restore_mode = true
		if OS.get_cmdline_user_args().has("--restore-shared-rime"):
			_rime_shared_survey_mode = true
			await _shared_rime_pad_access()
		else:
			await _shared_aurora_home_publication_retry()
		_check(_shared_visit_restoration_completed, "the requested fresh-Main shared restoration route reaches ordinary authenticated reboarding")
		if _failures.is_empty():
			print("OK: Shared visit restoration integration (%d assertions)" % _assertions)
			quit(0)
		else:
			for failure in _failures:
				push_error(failure)
			quit(1)
		return
	if OS.get_cmdline_user_args().has("--rime-shared-survey"):
		_rime_shared_survey_mode = true
		_rime_survey_retirement_case = true
		await _shared_rime_pad_access()
		_rime_survey_retirement_case = false
		await _shared_rime_pad_access()
		if _failures.is_empty():
			print("OK: Rime shared ice-core survey integration (%d assertions)" % _assertions)
			quit(0)
		else:
			for failure in _failures:
				push_error(failure)
			quit(1)
		return
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
	await _shared_rime_pad_access(true)
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
func _shared_rime_pad_access(native_floor_loss_only: bool = false) -> void:
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
			await _rime_pad_body_route(game, client, craft, avatar, native_floor_loss_only)
	client.shutdown()
	if is_instance_valid(game):
		game.shutdown_network_session(&"rime_pad_fixture_done")
		_check(game._network_ember_passenger_surfaces.is_empty(), "Rime session retirement disposes the retained surface contexts")
	branch.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame


func _rime_boarding_request(game: GameFlow, client: Adapter, craft: HeroShip, sequence: int, action: StringName) -> Dictionary:
	var peer := client.multiplayer.get_unique_id()
	return BoardingIntent.create(peer, GameFlow.network_client_boarding_avatar_id(peer), craft.get_ship_id(), 1,
		StringName("frame_%s" % craft.get_ship_id()), 1, GameFlow.network_cabin_berth_seat_id(craft.get_ship_id(), 1), 1,
		GameFlow.NETWORK_CABIN_BERTH_ROLE, sequence, game.network_session.get_boarding_server_tick(), action).to_dictionary()


func _rime_pad_body_route(game: GameFlow, client: Adapter, craft: HeroShip, avatar: StringName,
		native_floor_loss_only: bool = false) -> void:
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
	if _rime_shared_survey_mode:
		await _rime_shared_survey_body_route(game, client, craft, body, region, avatar)
		return
	if native_floor_loss_only:
		var native_floor := surface.get_node("TerrainClipmap/CommittedTerrain/TerrainCollision/TerrainCollisionSurface") as CollisionShape3D
		# An unannounced replacement still has identical real collision geometry.
		# It cannot inherit an already-issued floor identity; never restore it or
		# fabricate another body to make this old grant current again.
		native_floor.shape = native_floor.shape.duplicate()
		_check(not game._network_ember_passenger_surface_is_current(avatar),
			"an unannounced native floor replacement refuses the old retained Rime grant")
		var old_body: WeakRef = weakref(body)
		game._advance_network_remote_bodies(Engine.get_physics_frames())
		await physics_frame
		await process_frame
		_check(not simulation.has_body(avatar) and game._network_ember_passenger_surfaces.is_empty()
			and old_body.get_ref() == null,
			"actual native floor replacement retires the old body and grant without recall or floor repair")
		return
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
	# The original native terrain already physically supports this authored
	# route. Only the retained current grant is being extended beyond the pad.
	for point: Vector3 in [Vector3(-24, 0.5, -16), Vector3(-40, 0.5, -28),
			Vector3(-52, 0.5, -42), Vector3(-54, 0.5, -46), Vector3(-52, 0.5, -42),
			Vector3(-50, 0.5, -54), Vector3(-30, 0.5, -66), Vector3(-8, 0.5, -68)]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(point),
				"authenticated retained Rime crew walks the existing authored survey route beyond the pad"):
			return
	_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id
		and game._network_ember_passenger_surface_is_current(avatar),
		"native icefall support retains the original authenticated body and current lease")
	var trail_height := body.global_position.y
	var trail_jump_peak := trail_height
	for tick in 100:
		await _coastal_tick(game, game.network_session, client, body, body.global_position, tick < 4)
		if not is_instance_valid(body):
			break
		trail_jump_peak = maxf(trail_jump_peak, body.global_position.y)
	_check(is_instance_valid(body) and trail_jump_peak > trail_height + 0.2 and body.is_on_floor()
		and game._network_ember_passenger_surface_is_current(avatar),
		"ordinary Rime jump and gravity return to the current original terrain outside the pad")
	if not is_instance_valid(body):
		return
	for point: Vector3 in [Vector3(14, 0.5, -70), Vector3(28, 0.5, -63), Vector3(30, 0.5, -62),
			Vector3(30, 0.5, -60), Vector3(20, 0.5, -40), Vector3(10, 0.5, -24)]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(point),
				"same Rime crew reaches the gauge and follows the authored return trail"):
			return
	var native_root := surface.get_node("TerrainClipmap/CommittedTerrain") as Node3D
	var native_generation: Variant = native_root.get_meta(&"terrain_generation")
	native_root.set_meta(&"terrain_generation", int(native_generation) + 1)
	_check(not game._network_ember_passenger_surface_is_current(avatar),
		"a stale native terrain generation cannot retain the original Rime grant")
	native_root.set_meta(&"terrain_generation", native_generation)
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
		var recovered := await _wait_until(func(): return game._aurora_expedition.can_share_restored_surface(), 20.0)
		_check(recovered and not game._network_session_is_live() and not game.player.is_seated()
			and game.get_network_remote_body_simulation() == null and game._network_ember_passenger_surfaces.is_empty(), "fresh Main recovers Aurora's physical visit on foot without old session, bodies or grants")
		_check(not game.restore_shared_aurora_survey_checkpoint().get("accepted", false), "offline startup cannot adopt a shared host survey checkpoint")
		if not recovered:
			game.queue_free()
			await process_frame
			return
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var home := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	if _survey_restart_phase != 2:
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
	if _survey_restart_phase == 2:
		# The public restored-surface host action ran while standing. Retake
		# this actual visit's helm through its ordinary physical boarding owner.
		game._aurora_expedition.interact()
		var piloting := await _wait_until(func(): return game._piloting and game.player.is_seated_at(craft.get_pilot_seat_anchor()) \
			and not game._transition_busy and game._aurora_expedition.state == &"landed", 12.0)
		_check(piloting, "bounded home retry uses the actual Halyard host pilot")
		if not piloting:
			game.queue_free()
			await process_frame
			return
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
		if is_instance_valid(game):
			game.shutdown_network_session(&"coastal_fixture_failed")
		branch.queue_free()
		if is_instance_valid(game):
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
	if _survey_restart_phase == 2:
		_check(owner.settled_surface_is_current() and game._planetary_journey.get_visit_world_id() == &"aurora_temperate_world",
			"continuation retains the actual recovered Aurora visit lane")
		_check(owner._surface == bootstrap.get_loaded_instance() and game._network_planetary_journey._restored_surface_session_is_current(),
			"continuation retains the recovered current scene and common origin")
	else:
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
	var berth := owner._berth as ShipBerth
	if _survey_restart_phase == 2:
		_check(is_instance_valid(berth) and berth.get_occupant() == craft and owner.settled_surface_is_current(),
			"continuation retains the actual recovered occupied Aurora berth")
	else:
		owner._ship = craft
		owner._home = game.world.get_berth_node(craft.get_home_berth_id())
		owner._surface = surface
		owner._shared_arrival = true
		owner.state = &"landed"
		owner.survey.attach(surface)
		owner._lease_surface_berth(region)
		berth = owner._berth as ShipBerth
		craft.global_transform = berth.get_assist_capture_transform()
		craft.velocity = Vector3.ZERO
		craft.request_berth_landing(berth)
		_check(await _wait_until(func(): return berth.get_occupant() == craft and not craft.is_landing_active(), 15.0), "staged survey physically docks the retained Halyard on the actual Aurora lease")
	var bridge := game._network_planetary_journey
	if _survey_restart_phase != 2:
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
	# Only the first arrival stages the actor. A recovered crew body keeps its
	# admitted pose and walks to the existing deck marker through real intents.
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	if _survey_restart_phase != 2:
		body.teleport_to(Transform3D(Basis.IDENTITY, hatch.global_position - Vector3.UP * 0.7))
	var deck := craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
	var hatch_deadline := Time.get_ticks_msec() + 5000
	var hatch_ready := false
	while Time.get_ticks_msec() < hatch_deadline and is_instance_valid(body) \
			and is_instance_valid(simulation) and simulation == game.get_network_remote_body_simulation() \
			and simulation.get_body(avatar) == body:
		var near_hatch := body.get_nearby_interactables().has(hatch) \
			and body.get_interaction_origin().distance_to(hatch.global_position) <= ShipCabinHatch.MAX_REACH
		await _coastal_tick(game, server, client, body,
			body.global_position if near_hatch or _survey_restart_phase != 2 else deck.global_position, false, near_hatch)
		if is_instance_valid(body) and is_instance_valid(simulation) \
				and simulation == game.get_network_remote_body_simulation() and simulation.get_body(avatar) == body \
				and body.is_cabin_containment_active() and game._network_aurora_passenger_host_is_current(craft) \
				and game._network_ember_passenger_at_hatch(body, craft, false):
			hatch_ready = true
			break
	if not hatch_ready:
		print("COASTAL_HATCH_NOT_READY body_valid=", is_instance_valid(body),
			" floor=", body.is_on_floor() if is_instance_valid(body) else false,
			" pose=", body.global_position if is_instance_valid(body) else Vector3.INF)
		_check(false, "authenticated hatch release retains the actual crew body under the current Aurora surface grant")
		return false
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
		if _shared_visit_restore_mode:
			await _restore_shared_visit_with_fresh_crew(game, client, body, &"aurora_temperate_world")
			return false
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
		_check(((bridge.get("_restored_surface_session") as Dictionary).is_empty() if _survey_restart_phase != 2 \
			else bridge._restored_surface_session_is_current()) \
			and await _wait_until(func(): return not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active(), 5.0) \
			and simulation.get_body(avatar) == body \
			and not server.get_boarding_snapshot().get("occupancies", []).is_empty(), \
			"ordinary authenticated reboard retains the survey body and seat under its current visit authority")
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


## Only initial arrival and hatch approach use the existing bounded staging.
## After the real exterior grant, ordinary Main physics owns movement, cold,
## publication and retirement. This is an authenticated Adapter intent check,
## not full-client keyboard/HUD or canonical travel qualification.
func _rime_shared_survey_body_route(game: GameFlow, client: Adapter, craft: HeroShip,
		body: PlayerController, region: Node3D, avatar: StringName) -> void:
	var owner := game._rime_expedition
	var survey: RefCounted = owner.survey
	var body_id := body.get_instance_id()
	var host_id := game.player.get_instance_id()
	_coastal_sequence = 0
	_coastal_interaction = 0
	_coastal_replica.clear()
	_rime_intent_source = BodyIntentSource.new()
	_rime_jump_held = false
	_rime_last_movement_send.clear()
	var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
	var bound := _rime_intent_source.bind(identity.entity_id, int(identity.entity_generation), 1001)
	_check(bool(bound.get("accepted", false)), "Rime client intent source binds the authentic retained survey body")
	if not bool(bound.get("accepted", false)):
		return
	client.movement_intent_result.connect(_accept_rime_movement_result.bind(client))
	client.planetary_journey_state_received.connect(_capture_coastal_state)
	game.set_physics_process(true)
	if not await _checked_coastal_walk(game, game.network_session, client, body,
			region.to_global(Vector3(-24, 0.5, -16)), "actual Rime participant walks to the survey beacon under ordinary host physics"):
		return
	_check(bool(_rime_intent_source.get_audit().opening_confirmed) and _rime_intent_source.has_authoritative_movement_clock(),
		"authenticated movement reply confirms the Rime client source opening and actual movement clock")
	await _coastal_press(game, game.network_session, client, body)
	var started := await _wait_until(func(): return int(survey.snapshot().get("state", 0)) == CheckpointRouteActivity.State.ACTIVE, 3.0)
	_check(started and survey.shared_state().participant_entity_id == String(avatar),
		"accepted retained-body interaction starts the host-owned Rime survey for that actual participant")
	if not started:
		return
	var heat_start := float(survey.get_heat_snapshot().heat_s)
	var frame_start := Engine.get_physics_frames()
	for _tick in 120:
		await _coastal_tick(game, game.network_session, client, body, body.global_position)
		if not is_instance_valid(body):
			return
	var expected_exposure := float(Engine.get_physics_frames() - frame_start) / float(Engine.physics_ticks_per_second)
	var heat := survey.get_heat_snapshot() as Dictionary
	_check(not heat.warm and absf(heat_start - float(heat.heat_s) - expected_exposure) < 0.15
		and game.player.get_instance_id() == host_id and game.player.is_seated() and game._piloting,
		"natural cold drains the actual exposed crew suit once per physics tick while the seated host remains pilot")
	var replicated := await _wait_until(func(): return (_coastal_replica.get("rime_survey", {}) as Dictionary).get("participant_entity_id") == String(avatar), 3.0)
	_check(replicated and int((_coastal_replica.rime_survey.progress as Dictionary).state) == CheckpointRouteActivity.State.ACTIVE
		and float((_coastal_replica.rime_survey.heat as Dictionary).fraction) < 1.0,
		"real host publication carries Rime progress and the participant's heater to the admitted peer")
	var view: Dictionary = survey.shared_presentation(owner._surface, body, _coastal_replica.get("rime_survey", {}), avatar)
	_check(view.get("prompt", "").contains("ABANDON") and view.get("objective", "").contains("SUIT HEATER"),
		"passive Rime presentation follows the host's actual participant and heater picture")
	var before := survey.capture() as Dictionary
	_check(not survey.interact(game.player) and survey.capture() == before,
		"the seated host cannot substitute its own body for the active remote survey participant")
	await _coastal_press(game, game.network_session, client, body)
	_check(int(survey.snapshot().state) == CheckpointRouteActivity.State.FAILED,
		"a fresh accepted beacon interaction abandons the optional participant survey")
	await _coastal_press(game, game.network_session, client, body)
	_check(int(survey.snapshot().state) == CheckpointRouteActivity.State.ACTIVE,
		"the same authenticated body can restart a fresh optional survey at the beacon")
	if _rime_survey_retirement_case:
		var prior_participant := game._network_rime_survey_participant_context(body)
		for target: Vector3 in [region.to_global(Vector3(-8, 0.5, -8)),
				craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)),
				(craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D).global_position]:
			if not await _checked_coastal_walk(game, game.network_session, client, body, target,
					"active Rime survey participant physically returns through the ordinary hatch"):
				return
		_check(survey.get_heat_snapshot().warm, "the actual participant is warmed by the existing craft radius")
		client.send_boarding_intent(_rime_boarding_request(game, client, craft, 3, BoardingIntent.ACTION_BOARD_ANY))
		var retirement_simulation := game.get_network_remote_body_simulation()
		var reboarded := await _wait_until(func(): return not retirement_simulation.is_surface_walking(avatar) and body.is_cabin_containment_active(), 5.0)
		_check(reboarded and game._network_planetary_journey.shared_surface_return_gate_reason(&"rime_glacial_world").is_empty(),
			"an unfinished optional Rime survey does not gate authenticated reboard or the all-crew return manifest")
		if not reboarded:
			return
		client.send_boarding_intent(_rime_boarding_request(game, client, craft, 4, BoardingIntent.ACTION_DISEMBARK))
		var readmitted := await _wait_until(func(): return retirement_simulation.is_surface_walking(avatar), 5.0)
		_check(readmitted and retirement_simulation.get_body(avatar) == body and body.get_instance_id() == body_id
			and game._network_rime_survey_body_is_current(body)
			and not game._network_rime_survey_participant_is_current(body, prior_participant),
			"a genuine fresh exterior admission keeps the body but cannot inherit its old survey participant grant")
		if not readmitted:
			return
		for target: Vector3 in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)),
				craft.to_global(Vector3(-8, 0.52, 22))]:
			if not await _checked_coastal_walk(game, game.network_session, client, body, target,
					"fresh participant physically exits through the existing cabin and airstair route"):
				return
		if not await _checked_coastal_walk(game, game.network_session, client, body,
				region.to_global(Vector3(-24, 0.5, -16)), "fresh authenticated participant walks back to the beacon"):
			return
		await _coastal_press(game, game.network_session, client, body)
		_check(int(survey.snapshot().state) == CheckpointRouteActivity.State.ACTIVE,
			"fresh exterior admission starts a new participant-owned survey rather than resuming old authority")
		client.shutdown()
		_check(await _wait_until(func(): return int(survey.snapshot().get("state", 0)) == CheckpointRouteActivity.State.FAILED, 5.0)
			and survey.snapshot().failure_reason == &"survey_participant_retired"
			and survey.shared_state().participant_entity_id == "" and not survey.reward_recorded(),
			"actual participant disconnect retires its optional survey authority without a stale reward")
		return
	for point: Vector3 in [Vector3(-40, 0.5, -28), Vector3(-52, 0.5, -42), Vector3(-54, 0.5, -46)]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(point),
				"actual Rime survey participant walks to the existing drill and heated hut"):
			return
	var arrival_heat := float(survey.get_heat_snapshot().heat_s)
	var warm_frame := Engine.get_physics_frames()
	_check(survey.get_heat_snapshot().warm, "the actual crew drill checkpoint is within the existing hut warmth")
	for _tick in 60:
		await _coastal_tick(game, game.network_session, client, body, body.global_position)
	var expected_warm_heat := minf(120.0, arrival_heat + 10.0 * float(Engine.get_physics_frames() - warm_frame) / float(Engine.physics_ticks_per_second))
	_check(absf(float(survey.get_heat_snapshot().heat_s) - expected_warm_heat) < 0.15,
		"ordinary ticks refill the participant heater at the hut using the unchanged capacity and warmth rate")
	await _coastal_press(game, game.network_session, client, body)
	_check(int(survey.snapshot().next_checkpoint_index) == 1,
		"accepted actual drill interaction records the first ice-core observation")
	if _shared_visit_restore_mode:
		await _restore_shared_visit_with_fresh_crew(game, client, body, &"rime_glacial_world")
		return
	for point: Vector3 in [Vector3(-52, 0.5, -42), Vector3(-50, 0.5, -54), Vector3(-30, 0.5, -66), Vector3(-8, 0.5, -68)]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(point),
				"retained Rime survey participant follows the authored serac trail"):
			return
	var jump_start := body.global_position.y
	var jump_peak := jump_start
	for tick in 100:
		await _coastal_tick(game, game.network_session, client, body, body.global_position, tick < 4)
		if not is_instance_valid(body):
			return
		jump_peak = maxf(jump_peak, body.global_position.y)
	_check(jump_peak > jump_start + 0.2 and body.is_on_floor()
		and int(survey.snapshot().state) == CheckpointRouteActivity.State.ACTIVE
		and survey.shared_state().participant_entity_id == String(avatar),
		"ordinary airborne movement preserves participant identity and active cold ownership")
	for point: Vector3 in [Vector3(14, 0.5, -70), Vector3(28, 0.5, -63), Vector3(30, 0.5, -62)]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(point),
				"actual Rime survey participant reaches the existing ridge gauge"):
			return
	var filesystem := game._runtime_settings_user_data_store.get("_filesystem") as SurveyFilesystem
	filesystem.reject_rewards = true
	await _coastal_press(game, game.network_session, client, body)
	_check(int(survey.snapshot().state) == CheckpointRouteActivity.State.COMPLETED
		and not survey.reward_recorded() and filesystem.rejected_rewards > 0,
		"real rejected atomic reward write retains the two host-observed readings for retry")
	filesystem.reject_rewards = false
	await _coastal_press(game, game.network_session, client, body)
	await _coastal_press(game, game.network_session, client, body)
	var loaded := UserDataStore.new("memory://rime-pad.json", filesystem)
	loaded.load()
	var authority := GameFlowRewardAuthority.new()
	var configured := authority.configure(loaded)
	_check(configured.get("accepted", false) and survey.reward_recorded()
		and int(authority.get_snapshot().record.reward_counts.get("rime_ice_core_record", 0)) == 1,
		"accepted current-body retry writes the Rime record once across real store reload and repeated presses")
	for point: Vector3 in [Vector3(30, 0.5, -60), Vector3(20, 0.5, -40), Vector3(10, 0.5, -24), Vector3(-8, 0.5, -8)]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, region.to_global(point),
				"same survey participant follows the real return trail toward the craft warmth"):
			return
	for target: Vector3 in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)),
			(craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D).global_position]:
		if not await _checked_coastal_walk(game, game.network_session, client, body, target,
				"same Rime participant physically walks back through the hatch"):
			return
	client.send_boarding_intent(_rime_boarding_request(game, client, craft, 3, BoardingIntent.ACTION_BOARD_ANY))
	var simulation := game.get_network_remote_body_simulation()
	_check(await _wait_until(func(): return not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active(), 5.0)
		and simulation.get_body(avatar) == body and body.get_instance_id() == body_id,
		"ordinary authenticated Rime reboard retains the actual survey participant body")
	_check(game._network_planetary_journey.shared_surface_return_gate_reason(&"rime_glacial_world").is_empty(),
		"optional Rime survey leaves the ordinary all-crew return manifest usable")



## The old arrival is staged by the existing feature fixture. The saved
## observation is real; the new Main uses production recovery and public host
## startup. Every fresh crew step/interaction below travels over real ENet.
func _restore_shared_visit_with_fresh_crew(game: GameFlow, old_client: Adapter,
		old_body: PlayerController, world_id: StringName) -> void:
	var is_rime := world_id == &"rime_glacial_world"
	var owner = game._rime_expedition if is_rime else game._aurora_expedition
	var store := game._runtime_settings_user_data_store
	var filesystem := store.get("_filesystem") as SurveyFilesystem
	var path := "memory://rime-pad.json" if is_rime else "memory://shared-aurora.json"
	var home_id: StringName = owner.get_craft().get_home_berth_id()
	var old_avatar := StringName(NetworkRemoteBodySimulation.get_remote_body_identity(old_body).entity_id)
	var old_context: Dictionary = game._network_ember_passenger_surfaces[old_avatar].duplicate(true)
	var old_body_ref: WeakRef = weakref(old_body)
	var saved_progress: Dictionary = owner.survey.capture()
	var saved := game.save_interrupted_rime_visit() if is_rime else game.save_interrupted_aurora_visit()
	_check(bool(saved.get("accepted", false)), "actual shared observation commits a resumable visit through the atomic store")
	var binding = game._rime_expedition_persistence_binding if is_rime else game._aurora_expedition_persistence_binding
	var loaded: Dictionary = binding.load_interrupted_visit()
	_check(loaded.get("accepted", false) and loaded.visit.size() == 4
		and loaded.visit.craft_home_berth_id == String(home_id)
		and int(loaded.visit.survey.next_checkpoint_index) == 1,
		"the existing visit receipt contains only craft, phase, on-foot state and observed progress")
	if not saved.get("accepted", false) or not loaded.get("accepted", false):
		return
	game.queue_free()
	await process_frame
	await physics_frame
	old_client.shutdown()
	_check(old_body_ref.get_ref() == null, "whole-Main teardown disposes the old shared crew body")
	var fresh := MainScene.instantiate() as GameFlow
	fresh.configure_runtime_settings_persistence(UserDataStore.new(path, filesystem))
	root.add_child(fresh)
	set_multiplayer(SceneMultiplayer.new(), fresh.get_path())
	await process_frame
	await physics_frame
	fresh.start_shift()
	owner = fresh._rime_expedition if is_rime else fresh._aurora_expedition
	var recovered := await _wait_until(func(): return owner.can_share_restored_surface(), 20.0)
	_check(recovered and fresh.active_ship.get_home_berth_id() == home_id
		and not fresh.player.is_seated() and not fresh._piloting and fresh.player.is_control_enabled()
		and not fresh._network_session_is_live() and not fresh._network_planetary_journey.is_active()
		and fresh.get_network_remote_body_simulation() == null,
		"fresh Main physically restores the same world's registered craft and standing host without old network authority")
	if not recovered:
		fresh.queue_free()
		await process_frame
		return
	var craft := owner.get_craft() as HalyardCrewTransport
	var berth: ShipBerth = owner.get("_berth")
	var token := berth.get_reservation_token(craft)
	var pose := fresh.player.global_transform
	_check(owner.settled_surface_is_current() and not token.is_empty()
		and berth.get_occupant() == craft and int(owner.survey.snapshot().next_checkpoint_index) == 1,
		"restoration owns a fresh real occupied lease and retains the saved observation")
	_check(not fresh._network_ember_passenger_surface_is_current(old_avatar, old_context),
		"the retired body's saved world/session/lease context cannot enter the fresh Main")
	var probe := UDPServer.new()
	var port_ready := probe.listen(0, "127.0.0.1") == OK
	var port := probe.get_local_port() if port_ready else 0
	probe.stop()
	fresh._ensure_lan_discovery().discovery_port = 0
	var context: Dictionary = owner.get("_restored_surface_context").duplicate(true)
	owner._restored_surface_context.token = &"forged-restored-token"
	_check(not fresh.host_network_session(port, 2).get("accepted", false),
		"the public host action refuses a restored visit with a stale lease identity")
	owner._restored_surface_context = context
	_check(not fresh.join_network_session("127.0.0.1", port).get("accepted", false),
		"a recovered planetary host cannot join another session through the hosting exception")
	var hosted := port_ready and bool(fresh.host_network_session(port, 2).get("accepted", false))
	_check(hosted and fresh._network_planetary_journey.get_world_id() == world_id
		and fresh.get_network_planetary_journey_snapshot().phase == &"landed"
		and fresh.player.global_transform == pose and not fresh.player.is_seated()
		and not fresh._shared_planetary_host_eligible() and owner.restored_surface_host_is_current(),
		"public hosting adopts only this fresh world and lease while preserving the intentional standing host")
	_check(not fresh._network_planetary_journey.adopt_restored_surface().get("accepted", false)
		and fresh._network_planetary_journey.shared_surface_return_gate_reason(world_id) == fresh._network_planetary_journey._arrival_reason(world_id, "return_requires_host_pilot"),
		"duplicate adoption is refused and standing recovery grants no return pilot capability")
	var branch := SubViewport.new()
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var client := Adapter.new()
	client.name = GameFlow.NETWORK_SESSION_NODE_NAME
	branch.add_child(client)
	client.planetary_journey_state_received.connect(_capture_coastal_state)
	_coastal_replica.clear()
	if hosted:
		client.join("127.0.0.1", port)
	var admitted := hosted and await _wait_until(func(): return not client.get_server_offer().is_empty() \
		and _coastal_replica.get("world_id") == world_id and _coastal_replica.get("phase") == &"landed", 10.0)
	_check(admitted, "a newly authenticated late crew receives the actual recovered world's current journey publication")
	if admitted:
		var avatar := GameFlow.network_client_boarding_avatar_id(client.multiplayer.get_unique_id())
		var request := _rime_boarding_request(fresh, client, craft, 1, BoardingIntent.ACTION_BOARD)
		var peer := client.multiplayer.get_unique_id()
		var bridge := fresh._network_planetary_journey
		var adopted: Dictionary = bridge.get("_restored_surface_session").duplicate(true)
		_check(bridge.restored_cabin_admission_is_current(peer, request)
			and fresh._network_boarding_departure_status(peer, request).is_empty(),
			"only this authenticated fresh recovered-session cabin request reaches the ordinary boarding ledger")
		bridge._restored_surface_session.clear()
		_check(fresh._network_boarding_departure_status(peer, request) == &"surface_return_requires_retained_body",
			"an ordinary landed shared journey retains its blanket no-new-body boarding guard")
		bridge._restored_surface_session = adopted.duplicate(true)
		bridge._restored_surface_session.journey_epoch += 1
		_check(not bridge.restored_cabin_admission_is_current(peer, request),
			"a stale adopted journey epoch cannot admit fresh recovered crew")
		bridge._restored_surface_session = adopted.duplicate(true)
		bridge._restored_surface_session.surface.token = &"stale-recovered-lease"
		_check(not bridge.restored_cabin_admission_is_current(peer, request),
			"an old surface lease cannot authorize fresh recovered-session boarding")
		bridge._restored_surface_session = adopted.duplicate(true)
		var pilot_request := request.duplicate(true)
		pilot_request["role"] = &"pilot"
		_check(not bridge.restored_cabin_admission_is_current(peer, pilot_request),
			"the fresh attachment exception cannot grant a pilot or another cabin role")
		var finalization_case := {"invalidate_once": true, "failed_claim": {}, "accepted_result": {}}
		fresh.network_session.set_boarding_result_finalizer(func(result: Dictionary, wire: Dictionary) -> Dictionary:
			if finalization_case.invalidate_once:
				finalization_case.invalidate_once = false
				finalization_case.failed_claim = result.get("occupancy", {}).duplicate(true)
				bridge._restored_surface_session.journey_epoch += 1
				var refused := fresh._finalize_network_boarding_result(result, wire)
				bridge._restored_surface_session = adopted.duplicate(true)
				return refused
			var finalized := fresh._finalize_network_boarding_result(result, wire)
			if bool(finalized.get("accepted", false)):
				finalization_case.accepted_result = finalized.duplicate(true)
			return finalized
		)
		client.send_boarding_intent(request)
		var late_answered := await _wait_until(func(): return int(client.get_boarding_intent_result_replica().get("sequence", -1)) == 1, 3.0)
		_check(late_answered and not client.get_boarding_intent_result_replica().get("accepted", true)
			and client.get_boarding_intent_result_replica().get("status") == &"surface_return_requires_retained_body"
			and fresh.network_session.get_boarding_snapshot().get("occupancies", []).is_empty()
			and not fresh.get_network_remote_body_simulation().has_body(avatar)
			and not (bridge.get("_restored_crew_admissions") as Dictionary).has(peer),
			"genuine post-claim epoch loss rolls back that exact seat and sends an actual refused answer without a body or consumed attachment")
		var revision := int(client.get_boarding_intent_result_replica().get("revision", 0))
		request["client_tick"] = fresh.network_session.get_boarding_server_tick()
		client.send_boarding_intent(request)
		_check(await _wait_until(func(): return int(client.get_boarding_intent_result_replica().get("revision", 0)) > revision, 3.0)
			and client.get_boarding_intent_result_replica().get("status") == &"stale_sequence",
			"rolling back the refused claim preserves the accepted intent sequence highwater")
		request = _rime_boarding_request(fresh, client, craft, 2, BoardingIntent.ACTION_BOARD)
		var sent := client.send_boarding_intent(request)
		var boarded := await _wait_until(func(): return fresh.get_network_remote_body_simulation() != null \
			and fresh.get_network_remote_body_simulation().has_body(avatar), 12.0)
		_check(boarded, "the new session's real boarding ledger creates a fresh confirmed cabin body")
		if not boarded:
			var ledger := fresh.network_session.get_boarding_snapshot()
			var cabin := craft.get_in_flight_cabin_report() if is_instance_valid(craft) else {}
			var frame := cabin.get("frame") as MovingInteriorFrame
			var scene: Variant = owner.get("_surface")
			print("SHARED_RESTORE_BOARDING_REFUSAL: ", {
				"peer_id": client.multiplayer.get_unique_id(), "avatar_id": avatar,
				"request": request, "sent": sent, "response": client.get_boarding_intent_result_replica(),
				"current_guard": fresh._network_boarding_departure_status(client.multiplayer.get_unique_id(), request),
				"host_session": fresh.network_session.get_snapshot(), "client_session": client.get_snapshot(),
				"admitted_peers": fresh.network_session.get_admitted_peer_ids(), "boarding_ledger": ledger,
				"crew_roles": fresh.network_session.get_crew_role_snapshot(),
				"body_audit": fresh.get_network_remote_body_audit(),
				"registered_ships": fresh._network_boarding_entities.keys(), "ship_id": request.ship_id,
				"craft_id": craft.get_instance_id() if is_instance_valid(craft) else 0, "active_craft": is_instance_valid(craft) and fresh.active_ship == craft,
				"cabin_supported": cabin.get("supported"), "frame_valid": is_instance_valid(frame),
				"frame_in_tree": frame.is_inside_tree() if is_instance_valid(frame) else false,
				"frame_craft_current": frame.get_moving_frame() == craft if is_instance_valid(frame) else false,
				"physical_dock": craft.get_landing_contract_report() if is_instance_valid(craft) else {},
				"engine": craft.get_telemetry().get("engine_state") if is_instance_valid(craft) else &"",
				"journey": fresh.get_network_planetary_journey_snapshot(), "visit_state": owner.state,
				"restored_context": owner.get("_restored_surface_context"),
				"scene_id": scene.get_instance_id() if is_instance_valid(scene) else 0,
				"berth_occupied": is_instance_valid(berth) and is_instance_valid(craft) and berth.get_occupant() == craft,
				"lease_token": berth.get_reservation_token(craft) if is_instance_valid(berth) and is_instance_valid(craft) else &"",
			})
		if boarded:
			var simulation := fresh.get_network_remote_body_simulation()
			var body := simulation.get_body(avatar) as PlayerController
			var current_occupancies: Array = fresh.network_session.get_boarding_snapshot().get("occupancies", [])
			var body_pose := body.global_transform
			var admissions := int(fresh.get_network_remote_body_audit().get("hatch_admissions", 0))
			var old_release := fresh.network_session.release_exact_server_boarding_occupancy(finalization_case.failed_claim)
			_check(not old_release.get("accepted", false) and old_release.get("status") == &"occupancy_changed"
				and fresh.network_session.get_boarding_snapshot().get("occupancies", []) == current_occupancies
				and simulation.get_body(avatar) == body and body.global_transform == body_pose,
				"a stale exact-claim rollback preserves the genuinely newer accepted seat and its current body")
			var duplicate := fresh._finalize_network_boarding_result(finalization_case.accepted_result, request)
			_check(duplicate.get("accepted", false) and simulation.get_body(avatar) == body and body.global_transform == body_pose
				and int(fresh.get_network_remote_body_audit().get("hatch_admissions", 0)) == admissions,
				"a legitimate duplicate accepted current-body callback preserves the same body and pose without another admission")
			_check(int((bridge.get("_restored_crew_admissions") as Dictionary).get(peer, 0)) \
				== int((fresh.network_session.get("_peer_generations") as Dictionary).get(peer, -1))
				and not bridge.restored_cabin_admission_is_current(peer, request),
				"ordinary confirmed body creation consumes one fresh attachment for this authenticated peer generation")
			var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
			_rime_intent_source = BodyIntentSource.new()
			_rime_intent_source.bind(identity.entity_id, int(identity.entity_generation), 1001)
			client.movement_intent_result.connect(_accept_rime_movement_result.bind(client))
			_rime_shared_survey_mode = true
			_rime_jump_held = false
			_coastal_sequence = 0
			_coastal_interaction = 0
			var deck := craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
			var walked := await _checked_coastal_walk(fresh, fresh.network_session, client, body,
				deck.global_position, "fresh authenticated crew walks ordinarily to the recovered craft's real hatch")
			if walked:
				client.send_boarding_intent(_rime_boarding_request(fresh, client, craft, 3, BoardingIntent.ACTION_DISEMBARK))
				var exterior := await _wait_until(func(): return simulation.is_surface_walking(avatar), 5.0)
				_check(exterior and simulation.get_body(avatar) == body
					and fresh._network_ember_passenger_surface_is_current(avatar, fresh._network_ember_passenger_surfaces.get(avatar, {}))
					and not fresh._network_ember_passenger_surface_is_current(avatar, old_context),
					"ordinary fresh hatch departure owns only the new body and fresh world/session/epoch/lease grant")
				if exterior:
					var region := owner.get("_surface").get_node("LandingRegion") as Node3D
					for target: Vector3 in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)),
							craft.to_global(Vector3(-8, 0.52, 22)), region.to_global(Vector3(-8, 0.5, -8))]:
						walked = walked and await _checked_coastal_walk(fresh, fresh.network_session, client, body,
							target, "late crew uses ordinary retained-body intents on the recovered actual surface")
					if is_rime:
						var frozen_heat := float(owner.survey.get_heat_snapshot().heat_s)
						for _tick in 30:
							if not is_instance_valid(body):
								break
							await _coastal_tick(fresh, fresh.network_session, client, body, body.global_position)
						_check(owner.survey.get("_pending_shared_restoration") and owner.survey.shared_state().participant_entity_id == ""
							and is_equal_approx(float(owner.survey.get_heat_snapshot().heat_s), frozen_heat)
							and int(owner.survey.snapshot().next_checkpoint_index) == int(saved_progress.next_checkpoint_index),
							"restored Rime progress and heater wait for a new authenticated observation instead of reviving the old participant")
						for point: Vector3 in [Vector3(-24, 0.5, -16), Vector3(-40, 0.5, -28), Vector3(-52, 0.5, -42),
								Vector3(-50, 0.5, -54), Vector3(-30, 0.5, -66), Vector3(-8, 0.5, -68),
								Vector3(14, 0.5, -70), Vector3(28, 0.5, -63), Vector3(30, 0.5, -62)]:
							walked = walked and await _checked_coastal_walk(fresh, fresh.network_session, client, body,
								region.to_global(point), "fresh Rime participant follows the actual trail to the remaining saved observation")
						if walked:
							filesystem.reject_rewards = true
							await _coastal_press(fresh, fresh.network_session, client, body)
							_check(not owner.survey.get("_pending_shared_restoration") and int(owner.survey.snapshot().state) == CheckpointRouteActivity.State.COMPLETED
								and not owner.survey.reward_recorded() and filesystem.rejected_rewards > 0,
								"a real current observation binds the fresh participant and rejected saving leaves completion unpaid")
							filesystem.reject_rewards = false
							await _coastal_press(fresh, fresh.network_session, client, body)
							await _coastal_press(fresh, fresh.network_session, client, body)
							var reloaded := UserDataStore.new(path, filesystem)
							reloaded.load()
							_check(owner.survey.reward_recorded() and int((reloaded.get_snapshot().get(String(GameFlowRewardAuthority.SLOT_ID), {}) as Dictionary).get("reward_counts", {}).get("rime_ice_core_record", 0)) == 1,
								"the freshly observed restored Rime survey retries and reloads exactly one durable reward")
						for point: Vector3 in [Vector3(30, 0.5, -60), Vector3(20, 0.5, -40), Vector3(10, 0.5, -24), Vector3(-8, 0.5, -8)]:
							walked = walked and await _checked_coastal_walk(fresh, fresh.network_session, client, body,
								region.to_global(point), "restored Rime observer physically follows the cyan return trail")
					for target: Vector3 in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), deck.global_position]:
						walked = walked and await _checked_coastal_walk(fresh, fresh.network_session, client, body,
							target, "late crew physically returns through the existing airstair and hatch")
					if walked:
						client.send_boarding_intent(_rime_boarding_request(fresh, client, craft, 4, BoardingIntent.ACTION_BOARD_ANY))
						var reboarded := await _wait_until(func(): return is_instance_valid(body) and not simulation.is_surface_walking(avatar) \
							and body.is_cabin_containment_active(), 5.0)
						_check(reboarded and simulation.get_body(avatar) == body and not fresh.player.is_seated()
							and berth.get_occupant() == craft and berth.get_reservation_token(craft) == token
							and (owner.survey.reward_recorded() if is_rime else not owner.survey.reward_recorded()),
							"fresh crew reboards the same physical body without moving the standing host, changing its lease or duplicating a reward")
						_shared_visit_restoration_completed = reboarded
	client.shutdown()
	fresh.shutdown_network_session(&"shared_restoration_fixture_done")
	_check(fresh._network_ember_passenger_surfaces.is_empty(), "restored session retirement clears its fresh grants")
	branch.queue_free()
	fresh.queue_free()
	await process_frame
	await physics_frame


func _accept_rime_movement_result(result: Dictionary, client: Adapter) -> void:
	if int(result.get("sequence", 0)) > 0:
		_rime_intent_source.accept_clock_refusal(client.multiplayer.get_unique_id(), result)
	else:
		_rime_intent_source.accept_opening_result(client.multiplayer.get_unique_id(), result)


func _coastal_tick(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3, jump: bool = false, neutral_movement: bool = false) -> void:
	if _rime_shared_survey_mode:
		# The production client source owns cadence, edges and opening recovery.
		# Ordinary Main physics remains the only host clock/body advancement.
		if jump and not _rime_jump_held:
			_rime_intent_source.request_jump()
		_rime_jump_held = jump
		var movement_tick := client.get_moving_interior_latest_server_tick()
		if movement_tick >= 0:
			_rime_intent_source.observe_movement_clock(movement_tick)
		elif not _rime_intent_source.has_authoritative_movement_clock():
			movement_tick = client.get_boarding_server_tick_estimate()
		var direction := target - body.global_position
		if _shared_visit_restore_mode:
			var rig := body.get_node("CameraRig") as Node3D
			direction = (rig.get_parent() as Node3D).global_basis.inverse() * direction
		var packet := _rime_intent_source.advance(client.multiplayer.get_unique_id(), {
			"move_axis": Vector2(0, -1) if not neutral_movement and Vector2(direction.x, direction.z).length() > 0.8 else Vector2.ZERO,
			"look_yaw": atan2(-direction.x, -direction.z), "look_pitch": 0.0,
			"run": false, "crouch": false,
		}, movement_tick)
		if not packet.is_empty():
			_rime_last_movement_send = client.send_movement_intent(packet)
			if neutral_movement and _rime_last_neutral_packet.is_empty() and bool(_rime_last_movement_send.get("accepted", false)):
				_rime_last_neutral_packet = packet.duplicate(true)
			if not bool(_rime_last_movement_send.get("accepted", false)) or _rime_last_movement_send.get("status") != &"queued":
				print("RIME_MOVEMENT_SEND_FAILED send=", _rime_last_movement_send,
					" source=", _rime_intent_source.get_audit(), " transport=", client.get_snapshot(),
					" authority=", server.get_movement_authority_audit())
				_check(false, "actual Rime client movement transport queues the sampled source packet")
				quit(1)
		await physics_frame
		return
	var tick := Engine.get_physics_frames()
	server.set_movement_server_tick(tick)
	if tick % 4 == 0:
		var direction := target - body.global_position
		if _survey_restart_phase == 2:
			var rig := body.get_node("CameraRig") as Node3D
			direction = (rig.get_parent() as Node3D).global_basis.inverse() * direction
		var moving := not neutral_movement and Vector2(direction.x, direction.z).length() > 0.8
		var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
		var packet: Dictionary = NetworkMovementIntent.create(client.multiplayer.get_unique_id(), identity.entity_id, int(identity.entity_generation), 1001, _coastal_sequence, tick, Vector2(0, -1) if moving else Vector2.ZERO, false, &"", false, atan2(-direction.x, -direction.z), 0.0, false, false, jump, _coastal_interaction).to_dictionary()
		_coastal_sequence += 1
		client.send_movement_intent(packet)
	game.get_network_remote_body_simulation().advance(tick)
	await physics_frame


func _walk_coastal(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController, target: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	var neutral_movement := false
	if _rime_shared_survey_mode:
		_rime_last_neutral_packet.clear()
	while Time.get_ticks_msec() < deadline and is_instance_valid(body):
		await _coastal_tick(game, server, client, body, target, false, neutral_movement)
		if not is_instance_valid(body):
			return false
		if Vector2(body.global_position.x - target.x, body.global_position.z - target.z).length() < 1.0 and body.is_on_floor():
			if not _rime_shared_survey_mode:
				return true
			# Release the held movement through the ordinary client stream and
			# wait for the first neutral command's actual host consumption within
			# this same leg budget. Later cadence samples also remain neutral.
			neutral_movement = true
			if not _rime_last_neutral_packet.is_empty():
				var avatar := server.get_movement_avatar_snapshot(_rime_intent_source.get_entity_id())
				var simulation := game.get_network_remote_body_simulation()
				var record := simulation.get_body_record(_rime_intent_source.get_entity_id())
				# Read the existing authority FIFO without consuming or altering it.
				# Acceptance/tick cursors alone do not prove this command was applied.
				var authority_avatar: Dictionary = server.get("_movement").get("_avatars").get(_rime_intent_source.get_entity_id(), {})
				var pending: Array = authority_avatar.get("pending", [])
				var first_dequeued: bool = pending.is_empty() or int(pending[0].sequence) > int(_rime_last_neutral_packet.sequence)
				if int(avatar.get("entity_generation", -1)) == int(_rime_last_neutral_packet.entity_generation) \
						and int(avatar.get("stream_id", -1)) == int(_rime_last_neutral_packet.stream_id) \
						and int(avatar.get("last_sequence", -1)) >= int(_rime_last_neutral_packet.sequence) \
						and first_dequeued and simulation.get_body(_rime_intent_source.get_entity_id()) == body \
						and not bool(record.get("frozen", true)) \
						and body.get_remote_drive_audit().get("move_axis") == Vector2.ZERO:
					return true
		elif _rime_shared_survey_mode:
			neutral_movement = false
			_rime_last_neutral_packet.clear()
	print("COASTAL_WALK_BLOCKED target=", target, " body_valid=", is_instance_valid(body), " pose=", body.global_position if is_instance_valid(body) else Vector3.INF,
		" floor=", body.is_on_floor() if is_instance_valid(body) else false,
		" velocity=", body.velocity if is_instance_valid(body) else Vector3.INF,
		" first_neutral=", _rime_last_neutral_packet, " audit=", game.get_network_remote_body_audit())
	if _rime_shared_survey_mode:
		print("RIME_MOVEMENT_WALK_AUDIT source=", _rime_intent_source.get_audit(),
			" send=", _rime_last_movement_send, " transport=", client.get_snapshot(),
			" authority=", server.get_movement_authority_audit(),
			" avatar=", server.get_movement_avatar_snapshot(_rime_intent_source.get_entity_id()))
	return false


func _coastal_press(game: GameFlow, server: Adapter, client: Adapter, body: PlayerController) -> void:
	_coastal_interaction += 1
	if _rime_shared_survey_mode:
		_rime_intent_source.request_interaction()
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
