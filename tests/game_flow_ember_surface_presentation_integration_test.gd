extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const AudioDirectorType := preload("res://scripts/audio/audio_director.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const HostType := preload("res://scripts/world/ember_surface_loop_host.gd")
const ProductionType := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const AudioCompositionType := preload("res://scripts/audio/ember_surface_loop_audio_composition.gd")
const StatusBindingType := preload("res://scripts/ui/ember_surface_return_status_binding.gd")
const HudAdapterType := preload("res://scripts/ui/ember_surface_return_hud_adapter.gd")
const MainScene := preload("res://scenes/main.tscn")

class NeutralHostInput:
	extends RefCounted
	func is_action_pressed(_action: StringName) -> bool:
		return false
	func get_action_strength(_action: StringName) -> float:
		return 0.0

class SurveySaveFilesystem:
	extends UserDataFilesystem
	var reject_rewards := false
	var rejected_rewards := 0
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_rewards and document is Dictionary and str((document.get("commit", {}) as Dictionary).get("id", "")).begins_with("game-flow-reward-"):
			rejected_rewards += 1
			return ERR_CANT_CREATE
		return super.write_bytes_and_flush(path, bytes)

class FlowProbe:
	extends GameFlowType
	func _ready() -> void:
		pass

class CountingAudioComposition:
	extends AudioCompositionType
	var snapshot_reads := 0
	func get_snapshot() -> Dictionary:
		snapshot_reads += 1
		return super.get_snapshot()

class CountingStatusBinding:
	extends StatusBindingType
	var snapshot_reads := 0
	func get_snapshot() -> Dictionary:
		snapshot_reads += 1
		return super.get_snapshot()

class CountingHudAdapter:
	extends HudAdapterType
	var snapshot_reads := 0
	func get_snapshot() -> Dictionary:
		snapshot_reads += 1
		return super.get_snapshot()

class StatusBindingProbe:
	extends RefCounted
	var snapshot: Dictionary = {}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

class PlanetaryCompositionProbe:
	extends Node
	var snapshot: Dictionary = {}
	var expedition_intent_sink := Callable()
	var started: Array[StringName] = []
	var abandoned: Array[StringName] = []
	var reject_next := false
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)
	func get_authored_hazard_presentation_snapshot() -> Dictionary:
		return {}
	func configure_caldera_expedition_intent_sink(sink: Callable) -> Dictionary:
		expedition_intent_sink = sink
		return {"accepted": true, "reason": &"caldera_expedition_intent_sink_configured"}
	func start_caldera_expedition(activity_id: StringName) -> Dictionary:
		if reject_next:
			return {"accepted": false, "reason": &"caldera_expedition_unavailable"}
		started.append(activity_id)
		return {"accepted": true, "reason": &"activity_started"}
	func abandon_caldera_expedition(
			activity_id: StringName, reason: StringName = &"player_abandoned"
		) -> Dictionary:
		abandoned.append(activity_id)
		return {"accepted": true, "reason": reason}
	func get_caldera_expedition_snapshot() -> Dictionary:
		return {"world_id": &"ember_moon", "activities": {}}

var _assertions := 0
var _failures: PackedStringArray = []
var _cues: Array[StringName] = []
var _hud_host: GameFlow
var _hud_host_manual := false
var _hud_setup_failed := false
var _hud_survey_filesystem: SurveySaveFilesystem
var _hud_saved_profile: InputBindingProfile


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--rime-shared-survey-client"):
		RenderingServer.set_render_loop_enabled(false)
		await _test_client_survey_retirement("rime_survey", &"rime_glacial_world")
		if _failures.is_empty():
			print("GAME_FLOW_RIME_CLIENT_SURVEY_TEST_OK (%d assertions)" % _assertions)
			quit(0)
		else:
			_finish()
		return
	var flow := FlowProbe.new()
	var director := AudioDirectorType.new()
	var hud := HudType.new()
	var host := HostType.new()
	var production := ProductionType.new()
	var planetary := PlanetaryCompositionProbe.new()
	var ship_identity := Node.new()
	var player_identity := Node.new()
	var audio_composition := CountingAudioComposition.new()
	var status_binding := CountingStatusBinding.new()
	var hud_adapter := CountingHudAdapter.new()
	director.name = "AudioDirector"
	hud.name = "HUD"
	host.name = "EmberSurfaceLoopHost"
	production.name = "EmberSurfaceLoopProductionBinding"
	planetary.name = "PlanetaryCompositionProbe"
	ship_identity.name = "ShipIdentityProbe"
	player_identity.name = "PlayerIdentityProbe"
	audio_composition.name = "EmberSurfaceLoopAudioComposition"
	flow.add_child(director)
	flow.add_child(hud)
	flow.add_child(host)
	flow.add_child(production)
	production.add_child(planetary)
	flow.add_child(ship_identity)
	flow.add_child(player_identity)
	flow.add_child(audio_composition)
	flow.set("_ember_surface_loop_audio_composition", audio_composition)
	flow.set("_ember_surface_return_status_binding", status_binding)
	flow.set("_ember_surface_return_hud_adapter", hud_adapter)
	var presentation_owners: Array[Object] = [audio_composition, status_binding, hud_adapter]
	_check_attachment_parity(presentation_owners, false, "initial")
	flow.set("audio", director)
	flow.set("hud", hud)
	flow.set("ember_surface_loop_host", host)
	flow.set("ember_surface_loop_production_binding", production)
	host.set("_attached", true)
	host.set("_generation", 1)
	host.set("_attachment_generation", 1)
	host.set("_ship_instance_id", ship_identity.get_instance_id())
	host.set("_player_instance_id", player_identity.get_instance_id())
	production.set("_configured", true)
	production.set("_generation", 1)
	production.set("_host", host)
	production.set("_host_instance_id", host.get_instance_id())
	production.set("_ship_instance_id", ship_identity.get_instance_id())
	production.set("_player_instance_id", player_identity.get_instance_id())
	production.set("_planetary_composition", planetary)
	planetary.snapshot = {
		"state": &"bound",
		"host_generation": 1,
		"attachment_generation": 1,
	}
	root.add_child(flow)
	production.set_physics_process(false)
	await process_frame
	await process_frame
	director.semantic_cue_emitted.connect(_on_semantic_cue)

	hud.update_surface_route_status({
		"title": "ORDINARY ROUTE",
		"message": "EXTERNAL FALLBACK",
		"waypoints": [{"id": &"ordinary", "label": "ORDINARY", "distance_m": 12.0}],
		"hazard": {"state": &"clear", "exposure": 0.0, "recovery_available": false},
	})
	var detail := hud.get("_runtime_status_detail") as Label
	var ordinary_detail := detail.text
	var attached := flow.call("_ensure_ember_surface_presentations") as Dictionary
	_check(
		bool(attached.get("accepted", false))
		and attached.get("reason", &"") == &"attached",
		"GameFlow composes the authenticated idle Host without seizing the route row",
	)
	_check(detail != null and not ordinary_detail.is_empty() and detail.text == ordinary_detail, "idle Ember observation leaves ordinary route fallback external")
	var identities := [audio_composition.get_instance_id(), status_binding.get_instance_id(), hud_adapter.get_instance_id()]
	_check(director.get_semantic_audio_binding_count() == 1, "one planetary semantic source is registered")
	_check_attachment_parity(presentation_owners, true, "attached")
	var snapshot_reads_before := Vector3i(
		audio_composition.snapshot_reads, status_binding.snapshot_reads, hud_adapter.snapshot_reads
	)
	_check((flow.call("_ensure_ember_surface_presentations") as Dictionary).reason == &"already_attached" and director.get_semantic_audio_binding_count() == 1, "repeated ensure cannot duplicate the planetary source")
	_check(
		Vector3i(audio_composition.snapshot_reads, status_binding.snapshot_reads, hud_adapter.snapshot_reads)
			== snapshot_reads_before,
		"idempotent GameFlow attachment polls skip all three complete presentation reports",
	)

	host.set("_phase", HostType.Phase.DESCENT)
	production._finish_late_signal(&"integration_phase_changed")
	_check(detail.text.contains("DESCENT // ENTERING"), "surface descent overrides the existing route row")
	_check(_cues.count(&"ember_surface_descent_exterior") == 1, "surface descent reaches AudioDirector once")
	hud.update_surface_route_status({
		"title": "ORDINARY ROUTE",
		"message": "EXTERNAL FALLBACK RESTORED",
		"waypoints": [{"id": &"ordinary", "label": "ORDINARY", "distance_m": 8.0}],
		"hazard": {"state": &"clear", "exposure": 0.0, "recovery_available": false},
	})
	var restored_ordinary_detail := detail.text
	flow.call("_ensure_ember_surface_presentations")
	_check(not restored_ordinary_detail.is_empty() and detail.text == restored_ordinary_detail, "idempotent composition does not seize ordinary route fallback")

	root.remove_child(flow)
	_check_attachment_parity(presentation_owners, false, "detached")
	_check(director.get_semantic_audio_binding_count() == 0, "detach targets and releases the Ember semantic source")
	_check(not bool((status_binding.call("get_snapshot") as Dictionary).attached) and not bool((hud_adapter.call("get_snapshot") as Dictionary).attached), "detach fences both retained HUD observers")
	root.add_child(flow)
	production.set_physics_process(false)
	await process_frame
	await process_frame
	# The retained Host owner, not GameFlow presentation, re-establishes its live
	# attachment before presentation is eligible to return.
	host.set("_attached", true)
	host.set("_phase", HostType.Phase.IDLE)
	host.set("_generation", 2)
	host.set("_attachment_generation", 2)
	production.set("_generation", 2)
	planetary.snapshot.host_generation = 2
	planetary.snapshot.attachment_generation = 2
	var reattached := flow.call("_ensure_ember_surface_presentations") as Dictionary
	_check(bool(reattached.get("accepted", false)), "re-entry restores the production presentation composition")
	_check_attachment_parity(presentation_owners, true, "reentered")
	_check([audio_composition.get_instance_id(), status_binding.get_instance_id(), hud_adapter.get_instance_id()] == identities, "re-entry preserves all three exact presentation identities")
	_check(director.get_semantic_audio_binding_count() == 1, "re-entry restores exactly one planetary semantic source")
	host.set("_phase", HostType.Phase.ASCENT)
	production._finish_late_signal(&"integration_phase_changed")
	_check(detail.text.contains("EMBER RETURN // ASCENT"), "fresh re-entry updates the surface HUD once")
	_check(_cues.count(&"ember_surface_ascent_exterior") == 1, "fresh re-entry reaches AudioDirector once")
	_test_in_range_minimap_markers()
	_test_caldera_expedition_intent_seam(flow, production, planetary)

	flow.queue_free()
	await process_frame
	RenderingServer.set_render_loop_enabled(false)
	for scenario in ["retired", "local_loss", "session", "newer", "replacement"]:
		await _test_client_survey_retirement(scenario)
		if _hud_setup_failed:
			break
	_finish()


## Staged real Main peers and authenticated boarding/retirement. This checks the
## client's real HUD producer, not canonical travel or a restored survey save.
func _test_client_survey_retirement(scenario: String, world_id: StringName = &"aurora_temperate_world") -> void:
	var started_ms := Time.get_ticks_msec()
	var started_physics := Engine.get_physics_frames()
	print("SURVEY_CLIENT_SCENARIO begin scenario=", scenario, " wall_ms=", started_ms, " physics_frame=", started_physics)
	var host_view := SubViewport.new()
	var client_view := SubViewport.new()
	host_view.own_world_3d = true
	client_view.own_world_3d = true
	host_view.world_3d = World3D.new()
	client_view.world_3d = World3D.new()
	root.add_child(host_view)
	root.add_child(client_view)
	set_multiplayer(SceneMultiplayer.new(), host_view.get_path())
	set_multiplayer(SceneMultiplayer.new(), client_view.get_path())
	var server := MainScene.instantiate() as GameFlow
	var client := MainScene.instantiate() as GameFlow
	for pair: Array in [[server, "host"], [client, "client"]]:
		var filesystem := SurveySaveFilesystem.new()
		if scenario in ["retired", "rime_survey"] and pair[0] == server:
			_hud_survey_filesystem = filesystem
		var store := UserDataStore.new("user://survey-hud-%s-%s.json" % [scenario, pair[1]], filesystem)
		store.load()
		(pair[0] as GameFlow).configure_runtime_settings_persistence(store)
	host_view.add_child(server)
	client_view.add_child(client)
	_hud_host = server
	await process_frame
	await physics_frame
	server.start_shift()
	client.start_shift()
	server.set_process(false)
	client.set_process(false)
	var craft := server.get_node("HalyardCrewTransport") as HeroShip
	var replica := client.get_node("HalyardCrewTransport") as HeroShip
	server.player.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position()))
	server._board_ship(craft)
	var pilot_ready := await _hud_wait(func(): return server._piloting and not server._transition_busy, 12.0)
	_check(pilot_ready, "%s: actual Main host seats its retained Halyard pilot" % scenario)
	var port_probe := UDPServer.new()
	var port_ready := port_probe.listen(0, "127.0.0.1") == OK
	var port := port_probe.get_local_port() if port_ready else 0
	port_probe.stop()
	server._ensure_lan_discovery().discovery_port = 0
	var hosted := port_ready and bool(server.host_network_session(port, 2).get("accepted", false))
	var joined := hosted and bool(client.join_network_session("127.0.0.1", port).get("accepted", false))
	var admitted := joined and await _hud_wait(func(): return client._network_client_peer_id() > 1 and not client.network_session.get_server_offer().is_empty(), 10.0)
	_check(admitted, "%s: two real Main sessions authenticate the client" % scenario)
	_hud_setup_failed = not pilot_ready or not admitted
	if pilot_ready and admitted:
		client.player.teleport_to(Transform3D(replica.global_basis, replica.get_boarding_position()))
		var area := replica.get_node("ShipBoardingArea") as ShipBoardingArea
		var asked := client._request_network_client_boarding(replica, area)
		var boarded := bool(asked.get("accepted", false)) and await _hud_wait(func(): return client._network_client_boarding_holds(replica) and not client._transition_busy, 12.0)
		_check(boarded, "%s: full client presents only its authenticated cabin grant" % scenario)
		_hud_setup_failed = not boarded
		if boarded:
			var surface_ready := await _stage_client_survey_surface(server, client, craft, replica, area, world_id)
			_check(surface_ready, "%s: real exterior grant makes the client's surface context current" % scenario)
			_hud_setup_failed = not surface_ready
			if surface_ready:
				if world_id == &"rime_glacial_world":
					if scenario == "rime_survey":
						await _check_client_rime_survey_input(server, client, craft, replica)
					else:
						await _check_client_rime_controls(scenario, server, client, craft, replica)
				else:
					if scenario == "retired":
						await _check_client_survey_input(server, client, craft, replica)
					await _check_client_survey_retirement(scenario, server, client)
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	Input.parse_input_event(_survey_key(false))
	if _hud_saved_profile != null:
		client.runtime_settings.set_input_binding_profile(_hud_saved_profile)
		_hud_saved_profile = null
	_hud_host_manual = false
	_hud_host = null
	client.shutdown_network_session(&"hud_fixture_done")
	server.shutdown_network_session(&"hud_fixture_done")
	host_view.queue_free()
	client_view.queue_free()
	for _frame in 6:
		await process_frame
		await physics_frame
	print("SURVEY_CLIENT_SCENARIO end scenario=", scenario, " wall_ms=", Time.get_ticks_msec(), " elapsed_ms=", Time.get_ticks_msec() - started_ms, " physics_frame=", Engine.get_physics_frames(), " physics_elapsed=", Engine.get_physics_frames() - started_physics)


func _stage_client_survey_surface(server: GameFlow, client: GameFlow, craft: HeroShip, replica: HeroShip, area: ShipBoardingArea, world_id: StringName = &"aurora_temperate_world") -> bool:
	server.set_physics_process(false)
	_hud_host_manual = true
	var rime := world_id == &"rime_glacial_world"
	var owner = server._rime_expedition if rime else server._aurora_expedition
	var bootstrap: PlanetaryStreamingBootstrap = server.rime_streaming_bootstrap if rime else server.aurora_streaming_bootstrap
	var binding = server.rime_streaming_binding if rime else server.aurora_streaming_binding
	if not bool(server._planetary_journey.admit_aurora_visit(craft, false, world_id).get("accepted", false)):
		return false
	server._release_ship_berth(craft)
	craft.global_position = bootstrap.global_position + Vector3(0, 120030, 30)
	var sample := {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}
	binding.physics_tick_from_caller_sample(0.0, sample)
	server.common_world_origin_rebase_owner.consume_rebase_preview(binding.preview_origin_rebase(bootstrap.get_coordinate_frame_for_session().get_generation()), sample)
	if not await _hud_wait(func(): return is_instance_valid(bootstrap.get_loaded_instance()), 10.0):
		return false
	var surface := bootstrap.get_loaded_instance()
	owner._ship = craft
	owner._home = server.world.get_berth_node(craft.get_home_berth_id())
	owner._surface = surface
	owner._shared_arrival = true
	owner.state = &"landing" if rime else &"landed"
	owner.survey.attach(surface)
	owner._lease_surface_berth(surface.get_node("LandingRegion"))
	var berth := owner._berth as ShipBerth
	craft.global_transform = berth.get_assist_capture_transform()
	craft.velocity = Vector3.ZERO
	craft.request_berth_landing(berth)
	if not await _hud_wait(func(): return berth.get_occupant() == craft and not craft.is_landing_active(), 15.0):
		return false
	if rime:
		# The actual visit observes DOCKED and requests ordinary engine shutdown.
		owner.physics_tick(0.0)
		if not await _hud_wait(func(): return owner.state == &"landed" and craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_OFFLINE, 5.0):
			return false
	var bridge := server._network_planetary_journey
	bridge._epoch = 2
	bridge._craft_instance_id = craft.get_instance_id()
	bridge._pilot_source_ref = weakref(craft.get_command_source())
	bridge._state = {"journey_epoch": 2, "world_id": world_id, "ship_id": craft.get_ship_id(), "phase": &"landed"}
	bridge._publish(true)
	if not await _hud_wait(func(): return server._network_surface_visit_passenger_host_is_current(craft, world_id) and client._network_client_ember_surface_scene_is_current(replica, 2), 12.0):
		print("SURVEY_HUD_SETUP_CURRENT server=", server._network_surface_visit_passenger_host_is_current(craft, world_id), " client=", client._network_client_ember_surface_scene_is_current(replica, 2), " journey=", client.get_network_planetary_journey_snapshot(), " pose=", client._network_craft_pose_stream.latest_sample(replica.get_ship_id()))
		return false
	var avatar := client.get_network_remote_body_intent_source().get_entity_id()
	var body := server.get_network_remote_body_simulation().get_body(avatar) as PlayerController
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as Node3D
	var mirror_hatch := replica.get_node("WalkableInterior/CabinHatchInteraction") as Node3D
	# Initial hatch approach staging precedes the authenticated exterior grant.
	body.teleport_to(Transform3D(Basis.IDENTITY, hatch.global_position - Vector3.UP * 0.7))
	client.player.teleport_to(Transform3D(Basis.IDENTITY, mirror_hatch.global_position - Vector3.UP * 0.7))
	for _frame in 12:
		await _hud_wait(func(): return false, 0.001)
	var departure := client._request_network_client_boarding(replica, area)
	if not bool(departure.get("accepted", false)) or not await _hud_wait(func(): return client._network_client_ember_passenger_surface_is_current(), 12.0):
		print("SURVEY_HUD_SETUP_DEPARTURE asked=", departure, " answer=", client.network_session.get_boarding_intent_result_replica(), " context=", client._network_client_ember_passenger_surface, " host=", server._network_surface_visit_passenger_host_is_current(craft, world_id))
		return false
	client.set_physics_process(false)
	client._update_on_foot_flow()
	return client._network_client_ember_passenger_surface_is_current() if rime else str(client.hud.get("_objective_source_text")).contains("Optional shared survey")


## One full client consumer check: initial arrival/hatch approach are staged;
## every survey action thereafter is ordinary input and authenticated physics.
func _check_client_rime_survey_input(server: GameFlow, client: GameFlow, craft: HeroShip, replica: HeroShip) -> void:
	var survey := server._rime_expedition.survey
	var region := server.rime_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var source := client.get_network_remote_body_intent_source()
	var avatar := source.get_entity_id()
	var simulation := server.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var body_id := body.get_instance_id()
	var client_body_id := client.player.get_instance_id()
	var pilot_source := craft.get_command_source() as LocalShipInputSource
	pilot_source.set_input_provider(NeutralHostInput.new())
	_hud_saved_profile = client.runtime_settings.get_input_binding_profile()
	var remap := _hud_saved_profile.duplicate_profile()
	remap.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F14}])
	_check(client.runtime_settings.set_input_binding_profile(remap), "Rime survey full client accepts the physical Interact remap")
	_hud_host_manual = false
	server.set_physics_process(true)
	client.set_physics_process(true)
	client.set_process(true)
	_check(await _hud_wait(func(): return InputMap.action_has_event(&"interact", _survey_key(true)), 2.0)
		and client.hud.get_action_prompt(&"interact").contains("F14"), "Rime survey InputMap and HUD resolve the accepted physical key")
	for point in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), region.to_global(Vector3(-24, 0.5, -16))]:
		if not await _client_survey_walk(server, client, body, point):
			return
	_check(await _hud_wait(func(): return str(client.hud.get("_interaction_source_text")).contains("START ICE-CORE"), 3.0)
		and str((client.hud.get("_interaction_label") as Label).text).contains("F14"), "actual Rime client HUD offers the remapped survey action at its own beacon")
	Input.parse_input_event(_survey_key(true))
	var started := await _hud_wait(func(): return int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, 3.0)
	var generation := int(survey.snapshot().get("generation", -1))
	Input.parse_input_event(_survey_key(true, true))
	await _hud_wait(func(): return false, 0.35)
	Input.parse_input_event(_survey_key(false))
	_check(started and int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE
		and int(survey.snapshot().get("generation", -1)) == generation and survey.shared_state().participant_entity_id == String(avatar),
		"held and echoed physical key events start one host-owned survey for the actual Rime client body")
	if not started:
		return
	var cold_heat := float(survey.get_heat_snapshot().heat_s)
	var cold_frame := Engine.get_physics_frames()
	for _tick in 120:
		await _hud_wait(func(): return false, 0.001)
	var exposure := float(Engine.get_physics_frames() - cold_frame) / float(Engine.physics_ticks_per_second)
	_check(not survey.get_heat_snapshot().warm and absf(cold_heat - float(survey.get_heat_snapshot().heat_s) - exposure) < 0.15
		and server.player.is_seated() and server._piloting, "ordinary Rime exposure drains the actual crew suit while its host remains seated")
	_check(await _hud_wait(func(): return str(client.hud.get("_objective_source_text")).contains("SUIT HEATER"), 3.0),
		"actual client HUD displays its host-owned active Rime heater")
	await _client_survey_press()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.FAILED, "physical Rime Interact abandons the optional survey")
	await _client_survey_press()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, "a fresh physical edge restarts the optional Rime survey")
	for point in [Vector3(-40, 0.5, -28), Vector3(-52, 0.5, -42), Vector3(-54, 0.5, -46)]:
		if not await _client_survey_walk(server, client, body, region.to_global(point)):
			return
	_check(absf(region.to_local(body.global_position).x) > 48.0 and absf((client.rime_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D).to_local(client.player.global_position).x) > 48.0
		and server._network_ember_passenger_surface_is_current(avatar) and client._network_client_ember_passenger_surface_is_current(),
		"authoritative and predicted Rime bodies reach the actual drill beyond the pad with current grants")
	var warm_heat := float(survey.get_heat_snapshot().heat_s)
	var warm_frame := Engine.get_physics_frames()
	_check(survey.get_heat_snapshot().warm, "the actual client participant reaches existing hut warmth")
	for _tick in 60:
		await _hud_wait(func(): return false, 0.001)
	_check(absf(float(survey.get_heat_snapshot().heat_s) - minf(120.0, warm_heat + 10.0 * float(Engine.get_physics_frames() - warm_frame) / float(Engine.physics_ticks_per_second))) < 0.15,
		"ordinary hut physics refills the crew heater at the unchanged rate")
	await _client_survey_press()
	_check(int(survey.snapshot().get("next_checkpoint_index", -1)) == 1
		and await _hud_wait(func(): return str(client.hud.get("_objective_source_text")).contains("1/2 readings"), 3.0),
		"real remapped drill interaction updates host progress and the actual peer HUD")
	for point in [Vector3(-52, 0.5, -42), Vector3(-50, 0.5, -54), Vector3(-30, 0.5, -66), Vector3(-8, 0.5, -68)]:
		if not await _client_survey_walk(server, client, body, region.to_global(point)):
			return
	var jump_key := 0
	for binding: Dictionary in client.runtime_settings.get_input_binding_profile().get_bindings(&"jump"):
		if binding.get("device") == &"keyboard" and binding.get("type") == &"key":
			jump_key = int(binding.physical_keycode)
			break
	_check(jump_key > 0, "Rime survey jump uses the actual current physical key binding")
	var event := InputEventKey.new()
	event.physical_keycode = jump_key
	event.pressed = true
	Input.parse_input_event(event)
	var host_height := body.global_position.y
	var client_height := client.player.global_position.y
	var host_peak := host_height
	var client_peak := client_height
	for tick in 100:
		await _hud_wait(func(): return false, 0.001)
		if tick == 3:
			event = InputEventKey.new()
			event.physical_keycode = jump_key
			event.pressed = false
			Input.parse_input_event(event)
		if not is_instance_valid(body):
			event = InputEventKey.new()
			event.physical_keycode = jump_key
			event.pressed = false
			Input.parse_input_event(event)
			_check(false, "ordinary Rime survey jump retains its actual host body")
			return
		host_peak = maxf(host_peak, body.global_position.y)
		client_peak = maxf(client_peak, client.player.global_position.y)
	_check(host_peak > host_height + 0.2 and client_peak > client_height + 0.2 and body.is_on_floor() and client.player.is_on_floor()
		and int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE and server._network_rime_survey_body_is_current(body)
		and client._network_client_ember_passenger_surface_is_current(), "ordinary full-client keyboard jump preserves both floor arcs and active participant authority")
	for point in [Vector3(14, 0.5, -70), Vector3(28, 0.5, -63), Vector3(30, 0.5, -62)]:
		if not await _client_survey_walk(server, client, body, region.to_global(point)):
			return
	_hud_survey_filesystem.reject_rewards = true
	await _client_survey_press()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.COMPLETED and not survey.reward_recorded()
		and _hud_survey_filesystem.rejected_rewards > 0
		and await _hud_wait(func(): return str(client.hud.get("_interaction_source_text")).contains("RETRY SAVING"), 3.0),
		"actual Rime gauge key interaction preserves unpaid readings and displays rejected-save retry")
	_hud_survey_filesystem.reject_rewards = false
	await _client_survey_press()
	_check(survey.reward_recorded() and await _hud_wait(func(): return str(client.hud.get("_objective_source_text")).contains("Rime survey saved"), 3.0),
		"physical Rime Interact retry saves and publishes the durable ice-core reward")
	await _client_survey_press()
	var reloaded := UserDataStore.new("user://survey-hud-rime_survey-host.json")
	var loaded := reloaded.load()
	_check(bool(loaded.get("accepted", false)) and int((reloaded.get_snapshot().get("game_flow_reward_store", {}) as Dictionary).get("reward_counts", {}).get("rime_ice_core_record", 0)) == 1,
		"repeated real Rime Interact leaves exactly one reward across primary store reload")
	for point in [Vector3(30, 0.5, -60), Vector3(20, 0.5, -40), Vector3(10, 0.5, -24), Vector3(-8, 0.5, -8)]:
		if not await _client_survey_walk(server, client, body, region.to_global(point)):
			return
	if not await _client_survey_walk(server, client, body, craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z))):
		return
	var deck := craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
	var mirror_deck := replica.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
	if not await _client_survey_walk(server, client, body, deck.global_position, mirror_deck.global_position):
		return
	await _client_survey_press()
	var boarded := await _hud_wait(func(): return not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active() \
		and client._network_client_ember_passenger_surface.is_empty() and not client._transition_busy, 3.0)
	_check(boarded and simulation.get_body(avatar) == body and body.get_instance_id() == body_id and client.player.get_instance_id() == client_body_id
		and craft.get_command_source() == pilot_source, "ONE physical Rime hatch press reboards the same author and predicted survey bodies")
	_check(str(body.get("_rime_pad_guard_token")).is_empty() and str(client.player.get("_rime_pad_guard_token")).is_empty()
		and not server._network_ember_passenger_surfaces.has(avatar), "survey reboard clears both real guards and current exterior contexts")
	_check(server._network_planetary_journey.shared_surface_return_gate_reason(&"rime_glacial_world").is_empty(),
		"full-client Rime survey leaves ordinary all-crew return usable")
	pilot_source.set_input_provider(null)


## Rime is a separate controls contract: its supported pad must constrain BOTH
## the server body and ordinary local prediction. Initial arrival only is staged.
func _check_client_rime_controls(scenario: String, server: GameFlow, client: GameFlow, craft: HeroShip, replica: HeroShip) -> void:
	var source := client.get_network_remote_body_intent_source()
	var avatar := source.get_entity_id()
	var simulation := server.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var body_id := body.get_instance_id()
	var client_body_id := client.player.get_instance_id()
	var host_context := server._network_ember_passenger_surfaces.get(avatar, {}) as Dictionary
	var client_context := client._network_client_ember_passenger_surface
	var host_token := StringName(host_context.get("pad_guard_token", &""))
	var client_token := StringName(client_context.get("pad_guard_token", &""))
	_check(not host_token.is_empty() and not client_token.is_empty() and StringName(body.get("_rime_pad_guard_token")) == host_token and StringName(client.player.get("_rime_pad_guard_token")) == client_token,
		"%s: actual exterior admission binds each same body's matching Rime guard" % scenario)
	var pilot_source := craft.get_command_source() as LocalShipInputSource
	pilot_source.set_input_provider(NeutralHostInput.new())
	_hud_saved_profile = client.runtime_settings.get_input_binding_profile()
	var remap := _hud_saved_profile.duplicate_profile()
	remap.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F14}])
	_check(client.runtime_settings.set_input_binding_profile(remap), "%s: actual full client accepts the physical Interact remap" % scenario)
	_hud_host_manual = false
	server.set_physics_process(true)
	client.set_physics_process(true)
	client.set_process(true)
	_check(await _hud_wait(func(): return InputMap.action_has_event(&"interact", _survey_key(true)), 2.0), "%s: ordinary InputMap applies the accepted remap" % scenario)
	var host_region := server.rime_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var client_region := client.rime_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var host_pad := host_region.get_node("WalkablePatch/CollisionShape3D") as CollisionShape3D
	var client_pad := client_region.get_node("WalkablePatch/CollisionShape3D") as CollisionShape3D
	for point in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), host_region.to_global(Vector3(-8, 0.5, -8)), host_region.to_global(Vector3(-44, 0.5, -8))]:
		if not await _client_survey_walk(server, client, body, point):
			_hud_setup_failed = true
			return
	var host_before := int(body.get("_rime_pad_blocked_steps"))
	var client_before := int(client.player.get("_rime_pad_blocked_steps"))
	Input.action_press(&"move_left", 1.0)
	for _tick in 180:
		await _hud_wait(func(): return false, 0.001)
		if not is_instance_valid(body) or not client._network_client_ember_passenger_surface_is_current():
			break
	var retained := is_instance_valid(body) and simulation.get_body(avatar) == body and client.player.get_instance_id() == client_body_id
	var current := retained and server._network_ember_passenger_surface_is_current(avatar) and client._network_client_ember_passenger_surface_is_current()
	_check(current, "%s: held outward ordinary client input retains both real Rime bodies and current grants" % scenario)
	if not current:
		Input.action_release(&"move_left")
		_hud_setup_failed = true
		return
	var host_position := host_pad.to_local(body.global_position)
	var predicted_position := client_pad.to_local(client.player.global_position)
	_check(int(body.get("_rime_pad_blocked_steps")) > host_before and int(client.player.get("_rime_pad_blocked_steps")) > client_before,
		"%s: ordinary outward movement executes BOTH authoritative and predicted pad guards" % scenario)
	_check(absf(host_position.x) < (host_pad.shape as BoxShape3D).size.x * 0.5 and absf(predicted_position.x) < (client_pad.shape as BoxShape3D).size.x * 0.5 and body.is_on_floor() and client.player.is_on_floor(),
		"%s: both actual supported footprints and normal floor contact survive held edge movement" % scenario)
	_check(absf(body.gravity_multiplier - 1.0) < 0.02 and absf(client.player.gravity_multiplier - 1.0) < 0.02, "%s: both bodies keep ordinary Rime project gravity" % scenario)
	print("RIME_FULL_CLIENT_GUARDS ", scenario, " host_steps=", body.get("_rime_pad_blocked_steps"), " client_steps=", client.player.get("_rime_pad_blocked_steps"), " host_local=", host_position, " predicted_local=", predicted_position, " source=", source.get_audit())
	var jump_key := 0
	for binding: Dictionary in client.runtime_settings.get_input_binding_profile().get_bindings(&"jump"):
		if binding.get("device") == &"keyboard" and binding.get("type") == &"key":
			jump_key = int(binding.physical_keycode)
			break
	_check(jump_key > 0, "%s: jump uses the actual live keyboard binding" % scenario)
	var event := InputEventKey.new()
	event.physical_keycode = jump_key
	event.pressed = true
	Input.parse_input_event(event)
	var host_height := host_position.y
	var client_height := predicted_position.y
	var host_peak := host_height
	var client_peak := client_height
	for tick in 100:
		await _hud_wait(func(): return false, 0.001)
		if tick == 3:
			event = InputEventKey.new()
			event.physical_keycode = jump_key
			event.pressed = false
			Input.parse_input_event(event)
		if not is_instance_valid(body):
			break
		host_peak = maxf(host_peak, host_pad.to_local(body.global_position).y)
		client_peak = maxf(client_peak, client_pad.to_local(client.player.global_position).y)
	Input.action_release(&"move_left")
	_check(is_instance_valid(body) and host_peak > host_height + 0.2 and client_peak > client_height + 0.2 and body.is_on_floor() and client.player.is_on_floor(),
		"%s: a real keyboard jump preserves both vertical arcs, gravity and subsequent physical floor support" % scenario)
	for point in [host_region.to_global(Vector3(-8, 0.5, -8)), craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z))]:
		if not await _client_survey_walk(server, client, body, point):
			_hud_setup_failed = true
			return
	var deck := craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
	var mirror_deck := replica.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
	if not await _client_survey_walk(server, client, body, deck.global_position, mirror_deck.global_position):
		_hud_setup_failed = true
		return
	await _client_survey_press()
	var boarded := await _hud_wait(func(): return not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active() and client._network_client_ember_passenger_surface.is_empty() and not client._transition_busy, 3.0)
	_check(boarded and simulation.get_body(avatar) == body and body.get_instance_id() == body_id and client.player.get_instance_id() == client_body_id and craft.get_command_source() == pilot_source,
		"%s: ONE physical remapped hatch press reboards the SAME author and predicted bodies" % scenario)
	_check(str(body.get("_rime_pad_guard_token")).is_empty() and str(client.player.get("_rime_pad_guard_token")).is_empty() and not server._network_ember_passenger_surfaces.has(avatar),
		"%s: ordinary authenticated reboard clears both matching guards and surface contexts" % scenario)
	_check(not server._rime_expedition.survey._running()
		and not server._rime_expedition.survey.reward_recorded(), "%s: pad controls leave the Rime ice-core survey inactive and unrewarded" % scenario)
	if not boarded:
		_hud_setup_failed = true
		return
	await _client_survey_press()
	var departed := await _hud_wait(func(): return client._network_client_ember_passenger_surface_is_current() and simulation.is_surface_walking(avatar), 3.0)
	_check(departed and not str(body.get("_rime_pad_guard_token")).is_empty() and not str(client.player.get("_rime_pad_guard_token")).is_empty(), "%s: fresh ordinary exterior admission owns fresh guards on the same bodies" % scenario)
	if not departed:
		_hud_setup_failed = true
		return
	var exiting_token := [&"not_observed"]
	body.tree_exiting.connect(func(): exiting_token[0] = StringName(body.get("_rime_pad_guard_token")))
	if scenario == "rime_session":
		client.shutdown_network_session(&"rime_client_input_session_loss")
	else:
		client.rime_streaming_bootstrap.get_loaded_instance().queue_free()
		_check(await _hud_wait(func(): return str(client.player.get("_rime_pad_guard_token")).is_empty() and not source.is_bound(), 3.0), "actual local Rime scene loss retires the local guard and old intent authority")
		var host_scene := server.rime_streaming_bootstrap.get_loaded_instance()
		if is_instance_valid(host_scene):
			host_scene.queue_free()
	var retired := await _hud_wait(func(): return not simulation.has_body(avatar) and not server._network_ember_passenger_surfaces.has(avatar) and str(client.player.get("_rime_pad_guard_token")).is_empty() and not source.is_bound(), 6.0)
	var body_alive := is_instance_valid(body)
	var client_alive := is_instance_valid(client.player)
	var host_post := server._network_ember_passenger_surfaces.get(avatar, {}) as Dictionary
	var client_post := client._network_client_ember_passenger_surface
	print("RIME_FULL_CLIENT_RETIREMENT ", {
		"scenario": scenario, "retired_predicate": retired,
		"expected_host_body_id": body_id, "expected_client_body_id": client_body_id,
		"host_body_alive": body_alive,
		"host_body_id": body.get_instance_id() if body_alive else 0,
		"host_live_token": StringName(body.get("_rime_pad_guard_token")) if body_alive else &"disposed",
		"simulation_has_body": simulation.has_body(avatar),
		"host_context_present": server._network_ember_passenger_surfaces.has(avatar),
		"host_context_token": host_post.get("pad_guard_token", &""),
		"client_body_alive": client_alive,
		"client_body_id": client.player.get_instance_id() if client_alive else 0,
		"client_token": StringName(client.player.get("_rime_pad_guard_token")) if client_alive else &"disposed",
		"client_context_present": not client_post.is_empty(),
		"client_context_token": client_post.get("pad_guard_token", &""),
		"source_bound": source.is_bound(),
		"tree_exiting_observed": StringName(exiting_token[0]) != &"not_observed",
		"tree_exiting_token": StringName(exiting_token[0]),
	})
	_check(retired and StringName(exiting_token[0]).is_empty(), "%s: actual retirement clears the exact host guard before body disposal and clears client stale guard/stream" % scenario)
	client.set_physics_process(false)
	client.set_process(false)


## Only the initial arrival/hatch approach is staged. From this point the same
## bodies walk using ordinary client input and press an accepted physical remap;
## no direct survey callback, intent packet, progress or reward is injected.
func _check_client_survey_input(server: GameFlow, client: GameFlow, craft: HeroShip, replica: HeroShip) -> void:
	var survey := server._aurora_expedition.survey
	var surface := server.aurora_streaming_bootstrap.get_loaded_instance()
	var region := surface.get_node("LandingRegion") as Node3D
	var sign := surface.find_child("SurveyTrailSign", true, false) as Node3D
	var lookout := surface.find_child("SurveyLookout", true, false) as Node3D
	var stones := surface.find_child("SurveyStones", true, false) as Node3D
	var source := client.get_network_remote_body_intent_source()
	var avatar := source.get_entity_id()
	var body := server.get_network_remote_body_simulation().get_body(avatar) as PlayerController
	var body_id := body.get_instance_id()
	var client_body_id := client.player.get_instance_id()
	var pilot_source := craft.get_command_source() as LocalShipInputSource
	# Two Main peers share Input in this process. Only the host sampler is neutral;
	# its retained source, seated pilot and all host authorities remain real.
	pilot_source.set_input_provider(NeutralHostInput.new())
	var original_profile := client.runtime_settings.get_input_binding_profile()
	_hud_saved_profile = original_profile
	var remapped := original_profile.duplicate_profile()
	remapped.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F14}])
	_check(client.runtime_settings.set_input_binding_profile(remapped), "full client accepts the real Interact physical-key remap")
	_hud_host_manual = false
	server.set_physics_process(true)
	client.set_physics_process(true)
	client.set_process(true)
	await _hud_wait(func(): return InputMap.action_has_event(&"interact", _survey_key(true)), 2.0)
	_check(client.hud.get_action_prompt(&"interact").contains("F14"), "actual client prompt resolver displays the accepted Interact remap before walking")
	print("SURVEY_INPUT_FRAME client_basis=", client.player.global_basis, " host_basis=", body.global_basis, " client_yaw=", client.player.get_look_yaw(), " host_yaw=", body.get_look_yaw(), " client_forward=", -client.player.get_camera().global_basis.z, " host_forward=", -body.get_camera().global_basis.z)
	for point in [craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), craft.to_global(Vector3(-8, 0.52, 22)), region.to_global(Vector3(14, 0.5, 22)), region.to_global(Vector3(14, 0.5, 2)), sign.global_position + Vector3.UP * 0.5]:
		if not await _client_survey_walk(server, client, body, point):
			_hud_setup_failed = true
			return
	_diagnose_client_survey("sign", server, client)
	_check(str((client.hud.get("_interaction_label") as Label).text).contains("F14") and str(client.hud.get("_interaction_source_text")).contains("START COASTAL"), "actual client HUD shows the remapped survey key at the real sign")
	Input.parse_input_event(_survey_key(true))
	await _hud_wait(func(): return int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, 3.0)
	var generation := int(survey.snapshot().get("generation", -1))
	# A held key and operating-system echo cannot toggle the optional activity.
	Input.parse_input_event(_survey_key(true, true))
	await _hud_wait(func(): return false, 0.35)
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE and int(survey.snapshot().get("generation", -1)) == generation, "held and repeated remapped events produce one authenticated survey start")
	Input.parse_input_event(_survey_key(false))
	await _hud_wait(func(): return false, 0.12)
	await _client_survey_press()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.FAILED, "a new physical Interact edge abandons the optional survey")
	await _client_survey_press()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE, "another physical edge restarts through host-owned activity authority")
	for point in [region.to_global(Vector3(43, 0.5, -8)), region.to_global(Vector3(57, 0.5, -20)), lookout.global_position + Vector3(-1.5, -1.0, 0)]:
		if not await _client_survey_walk(server, client, body, point):
			_hud_setup_failed = true
			return
	await _client_survey_press()
	_diagnose_client_survey("lookout", server, client)
	_check(int(survey.snapshot().get("next_checkpoint_index", 0)) == 1 and str(client.hud.get("_objective_source_text")).contains("1/2 observations"), "real remapped client interaction records the lookout and updates the peer HUD")
	# Follow the authored branch around the solid stones before the same anchor.
	for point in [region.to_global(Vector3(55, 0.5, -20)), region.to_global(Vector3(51, 0.5, -32)), stones.global_position + Vector3.UP * 0.5]:
		if not await _client_survey_walk(server, client, body, point):
			_hud_setup_failed = true
			return
	_hud_survey_filesystem.reject_rewards = true
	await _client_survey_press()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.COMPLETED and not survey.reward_recorded() and _hud_survey_filesystem.rejected_rewards > 0 and str(client.hud.get("_interaction_source_text")).contains("RETRY SAVING"), "actual remapped completion retains unpaid observations and presents rejected-save retry")
	_diagnose_client_survey("rejected_stones", server, client)
	_hud_survey_filesystem.reject_rewards = false
	await _client_survey_press()
	_diagnose_client_survey("accepted_retry", server, client)
	_check(survey.reward_recorded() and str(client.hud.get("_objective_source_text")).contains("Aurora data saved"), "physical Interact retry commits and publishes the real durable reward")
	await _client_survey_press()
	var reloaded := UserDataStore.new("user://survey-hud-retired-host.json")
	reloaded.load()
	var record := reloaded.get_snapshot().get("game_flow_reward_store", {}) as Dictionary
	_check(int((record.get("reward_counts", {}) as Dictionary).get("aurora_coastal_survey_data", 0)) == 1, "repeated physical Interact leaves exactly one reward after an actual store reload")
	for point in [region.to_global(Vector3(52, 0.5, -33)), region.to_global(Vector3(52, 0.5, -27)), region.to_global(Vector3(55, 0.5, -20)), region.to_global(Vector3(43, 0.5, -8)), region.to_global(Vector3(30, 0.5, 0)), region.to_global(Vector3(14, 0.5, 2)), region.to_global(Vector3(14, 0.5, 22)), craft.to_global(Vector3(-8, 0.52, 22)), craft.to_global(Vector3(-5, 0.52, HalyardCrewTransport.AIRSTAIR_Z)), craft.to_global(Vector3(0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))]:
		if not await _client_survey_walk(server, client, body, point):
			_hud_setup_failed = true
			return
	_diagnose_client_hatch("center_endpoint", server, client, body, avatar)
	if not server._network_ember_passenger_at_hatch(body, craft, true):
		# A loose center waypoint can stop beyond the real hatch/floor/cabin
		# admission. Enter at each craft's authored marker before pressing.
		var deck := craft.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
		var mirror_deck := replica.get_node("WalkableInterior/InteriorDeckMarker") as Node3D
		if not await _client_survey_walk(server, client, body, deck.global_position, mirror_deck.global_position):
			_hud_setup_failed = true
			return
		_diagnose_client_hatch("authored_deck_entry", server, client, body, avatar)
	await _client_survey_press()
	_diagnose_client_hatch("pressed", server, client, body, avatar)
	var reboarded := await _hud_wait(func(): return not server.get_network_remote_body_simulation().is_surface_walking(avatar) and body.is_cabin_containment_active() and client._network_client_ember_passenger_surface.is_empty() and not client._transition_busy, 3.0)
	_diagnose_client_hatch("settled", server, client, body, avatar)
	_check(reboarded, "the same remapped Interact key gives the actual hatch reboard priority")
	_check(body.get_instance_id() == body_id and client.player.get_instance_id() == client_body_id and craft.get_command_source() == pilot_source, "observations, reward retry and reboarding retain both real bodies and the host pilot source")
	# A second fresh hatch edge re-admits this same visit for the retirement checks.
	await _client_survey_press()
	_diagnose_client_hatch("departure_pressed", server, client, body, avatar)
	var departed := await _hud_wait(func(): return client._network_client_ember_passenger_surface_is_current() and server.get_network_remote_body_simulation().is_surface_walking(avatar) and not client._transition_busy, 3.0)
	_diagnose_client_hatch("departure_settled", server, client, body, avatar)
	_check(departed, "ordinary hatch disembark remains usable after survey reboarding")
	client.set_physics_process(false)
	client.set_process(false)
	pilot_source.set_input_provider(null)
	client._update_on_foot_flow()


func _diagnose_client_hatch(stage: String, server: GameFlow, client: GameFlow, body: PlayerController, avatar: StringName) -> void:
	var craft := server._find_flyable_ship_by_id(server._network_planetary_journey.get_ship_id()) as HeroShip
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	var cabin := craft.get_in_flight_cabin_report()
	print("SURVEY_CLIENT_HATCH ", stage, " wall_ms=", Time.get_ticks_msec(), " physics_frame=", Engine.get_physics_frames(), " host_local=", craft.to_local(body.global_position), " floor=", body.is_on_floor(), " near_hatch=", body.get_nearby_interactables().has(hatch), " reach=", body.get_interaction_origin().distance_to(hatch.global_position), " in_cabin=", (cabin.local_bounds as AABB).has_point(craft.to_local(body.global_position)), " host_surface=", server.get_network_remote_body_simulation().is_surface_walking(avatar), " host_cabin=", body.is_cabin_containment_active(), " client_context_empty=", client._network_client_ember_passenger_surface.is_empty(), " transition=", client._transition_busy, " request=", client.get_network_client_boarding_audit(), " result=", client.network_session.get_boarding_intent_result_replica())


func _diagnose_client_survey(stage: String, server: GameFlow, client: GameFlow) -> void:
	print("SURVEY_CLIENT_INPUT_STAGE ", stage, " host=", server._aurora_expedition.survey.snapshot(), " paid=", server._aurora_expedition.survey.reward_recorded(), " rejected=", _hud_survey_filesystem.rejected_rewards, " peer=", client.get_network_planetary_journey_snapshot().get("aurora_survey", {}), " objective=", client.hud.get("_objective_source_text"), " prompt=", client.hud.get("_interaction_source_text"), " body=", server.get_network_remote_body_simulation().get_body_record(client.get_network_remote_body_intent_source().get_entity_id()), " registered=", client._cabin_ship.get_moving_interior_component().is_occupant_registered(client.player), " source=", client.get_network_remote_body_intent_source().get_audit(), " store=", server._runtime_settings_user_data_store.get_snapshot().get("game_flow_reward_store", {}))


func _survey_key(pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F14
	event.pressed = pressed
	event.echo = echo
	return event


func _client_survey_press() -> void:
	Input.parse_input_event(_survey_key(true))
	await _hud_wait(func(): return false, 0.25)
	Input.parse_input_event(_survey_key(false))
	await _hud_wait(func(): return false, 0.25)


func _client_survey_walk(server: GameFlow, client: GameFlow, body: PlayerController, target: Vector3, peer_target: Vector3 = Vector3.INF) -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	var start_physics_frame := Engine.get_physics_frames()
	var source := client.get_network_remote_body_intent_source()
	var simulation := server.get_network_remote_body_simulation()
	var start_sent := int(source.get_audit().get("sent", 0))
	var start_applied := int(simulation.get_body_record(source.get_entity_id()).get("intents_applied", 0))
	var settled := 0
	var rime := server._network_planetary_journey.get_world_id() == &"rime_glacial_world"
	var host_bootstrap: PlanetaryStreamingBootstrap = server.rime_streaming_bootstrap if rime else server.aurora_streaming_bootstrap
	var client_bootstrap: PlanetaryStreamingBootstrap = client.rime_streaming_bootstrap if rime else client.aurora_streaming_bootstrap
	var host_region := host_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var client_region := client_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var client_target := peer_target if peer_target.is_finite() else client_region.to_global(host_region.to_local(target))
	while Time.get_ticks_msec() < deadline and is_instance_valid(body):
		var local_delta := client_target - client.player.global_position
		var host_delta := target - body.global_position
		# Each peer uses the same authored waypoint in its own streamed scene.
		local_delta.y = 0.0
		host_delta.y = 0.0
		var delta := (local_delta + host_delta) * 0.5
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		if local_delta.length() < 0.8 and host_delta.length() < 0.8:
			settled = settled + 1 if body.is_on_floor() else 0
			if settled >= 8:
				return true
		else:
			settled = 0
			var forward: Vector3 = (-client.player.get_camera().global_basis.z).slide(Vector3.UP).normalized()
			var right: Vector3 = forward.cross(Vector3.UP).normalized()
			var direction := delta.normalized()
			var axis := Vector2(direction.dot(right), -direction.dot(forward)) * clampf(delta.length() / 1.5, 0.2, 1.0)
			Input.action_press(&"move_left" if axis.x < 0.0 else &"move_right", absf(axis.x))
			Input.action_press(&"move_forward" if axis.y < 0.0 else &"move_back", absf(axis.y))
		await _hud_wait(func(): return false, 0.001)
	var held_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	_check(false, "full client ordinary walk reaches the same retained host-body waypoint")
	var host_alive := is_instance_valid(body)
	var client_alive := is_instance_valid(client.player)
	var contacts: Array = []
	for actor in [body, client.player]:
		if not is_instance_valid(actor):
			continue
		var slides: Array = []
		for i in range(actor.get_slide_collision_count()):
			var collision: KinematicCollision3D = actor.get_slide_collision(i)
			var collider := collision.get_collider()
			slides.append({"collider": str(collider.get_path()) if is_instance_valid(collider) and collider is Node else "unavailable", "normal": collision.get_normal(), "position": collision.get_position()})
		contacts.append({"body_id": actor.get_instance_id(), "velocity": actor.velocity, "slides": slides})
	print("SURVEY_INPUT_WALK_CONTACTS contacts=", contacts, " input=", held_input, " elapsed_ms=", Time.get_ticks_msec() - (deadline - 18000), " physics_start=", start_physics_frame, " physics_end=", Engine.get_physics_frames(), " sent_delta=", int(source.get_audit().get("sent", 0)) - start_sent, " applied_delta=", int(simulation.get_body_record(source.get_entity_id()).get("intents_applied", 0)) - start_applied)
	print("SURVEY_INPUT_WALK_BLOCKED target=", target, " client=", client.player.global_position if client_alive else Vector3.INF, " host=", body.global_position if host_alive else Vector3.INF, " client_target=", client_target, " host_region=", host_region.global_transform, " client_region=", client_region.global_transform, " client_basis=", client.player.global_basis if client_alive else Basis.IDENTITY, " host_basis=", body.global_basis if host_alive else Basis.IDENTITY, " client_yaw=", client.player.get_look_yaw() if client_alive else NAN, " host_yaw=", body.get_look_yaw() if host_alive else NAN, " host_floor=", host_alive and body.is_on_floor(), " client_floor=", client_alive and client.player.is_on_floor(), " settled=", settled, " current=", client_alive and client._network_client_ember_passenger_surface_is_current(), " registered=", client_alive and is_instance_valid(client._cabin_ship) and is_instance_valid(client._cabin_ship.get_moving_interior_component()) and client._cabin_ship.get_moving_interior_component().is_occupant_registered(client.player), " source=", client.get_network_remote_body_intent_source().get_audit(), " audit=", server.get_network_remote_body_simulation().get_audit())
	return false


func _check_client_survey_retirement(scenario: String, server: GameFlow, client: GameFlow) -> void:
	var bridge := server._network_planetary_journey
	var epoch := int(client.get_network_planetary_journey_snapshot().journey_epoch)
	var objective := str(client.hud.get("_objective_source_text"))
	var kicker := client.hud.get("_objective_kicker") as Label
	_check(kicker.text == "AURORA COASTAL OBSERVATION", "%s: current-context producer renders the real survey objective" % scenario)
	# A genuine host packet with an old journey epoch must not clear this view.
	var live := bridge._state.duplicate(true)
	var context := client._network_client_ember_passenger_surface.duplicate(true)
	bridge._state["journey_epoch"] = epoch - 1
	bridge._state["phase"] = &"retired"
	bridge._publish(true)
	await _hud_wait(func(): return false, 0.05)
	bridge._state = live
	_check(client._network_client_ember_passenger_surface == context and int(client.get_network_planetary_journey_snapshot().get("journey_epoch", 0)) == epoch and str(client.hud.get("_objective_source_text")) == objective,
		"%s: authenticated stale retirement cannot erase a current survey view" % scenario)
	if scenario == "newer":
		client.hud.set_objective("New unrelated objective", "NEW OBJECTIVE")
	elif scenario == "replacement":
		var replacement := HudType.new()
		client.add_child(replacement)
		client.hud = replacement
		replacement.set_objective(objective, "AURORA COASTAL OBSERVATION")
	if scenario == "local_loss":
		# Real local scene loss revokes prediction before the host's tombstone.
		client.aurora_streaming_bootstrap.get_loaded_instance().queue_free()
		await process_frame
		client._advance_network_remote_body_intent_stream()
		_check(client._network_client_ember_passenger_surface.is_empty() and not client._network_client_ember_passenger_retired.is_empty(),
			"local scene loss retains only the pending authenticated recall identity")
		_check(not str(client.hud.get("_objective_source_text")).contains("Optional shared survey"),
			"local scene loss immediately retires the owned survey objective")
	if scenario == "session":
		var profile := client.runtime_settings.get_input_binding_profile()
		_hud_saved_profile = profile
		var remap := profile.duplicate_profile()
		remap.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F14}])
		_check(client.runtime_settings.set_input_binding_profile(remap), "body fence uses an accepted physical Interact remap")
		await _hud_wait(func(): return InputMap.action_has_event(&"interact", _survey_key(true)), 2.0)
		var source := client.get_network_remote_body_intent_source()
		var sent := int(source.get_audit().sent)
		var body_id := client.player.get_instance_id()
		var progress: Dictionary = server._aurora_expedition.survey.capture()
		var edges := [0]
		var count_edge := func(): edges[0] += 1
		client.player.interact_requested.connect(count_edge)
		# An exterior picture identifying another body cannot retain this body's
		# input authority, even while its admitted session and host scene are live.
		client._network_client_ember_passenger_surface.body_id = body_id + 1
		client.set_physics_process(true)
		await _client_survey_press()
		client.set_physics_process(false)
		client.player.interact_requested.disconnect(count_edge)
		_check(int(edges[0]) == 1 and client.player.get_instance_id() == body_id and not source.is_bound() and int(source.get_audit().sent) == sent,
			"real Player Interact cannot send stale exterior authority for a different body")
		_check(server._aurora_expedition.survey.capture() == progress and not server._aurora_expedition.survey.reward_recorded(),
			"stale current-body picture cannot record host observations or grant a reward")
		client.shutdown_network_session(&"survey_hud_session_loss")
	else:
		bridge.cancel(&"survey_hud_retired")
	await _hud_wait(func(): return client._network_client_ember_passenger_surface.is_empty(), 3.0)
	client._update_on_foot_flow()
	if scenario == "newer":
		_check(str(client.hud.get("_objective_source_text")) == "New unrelated objective" and (client.hud.get("_objective_kicker") as Label).text == "NEW OBJECTIVE",
			"retirement preserves a newer unrelated objective and kicker")
	elif scenario == "replacement":
		_check(str(client.hud.get("_objective_source_text")) == objective,
			"retirement cannot clear matching text on a replacement HUD instance")
	else:
		_check(not str(client.hud.get("_objective_source_text")).contains("Optional shared survey") and (client.hud.get("_objective_kicker") as Label).text != "AURORA COASTAL OBSERVATION",
			"%s: retirement clears owned survey text and kicker through the real client consumer" % scenario)
		_check(not str(client.hud.get("_interaction_source_text")).contains("COASTAL"), "%s: retired survey prompt cannot persist" % scenario)
	_check(client._network_client_ember_passenger_surface.is_empty() and not client.get_network_remote_body_intent_source().is_bound() and client.player.is_control_enabled(),
		"%s: existing authority cleanup leaves the same client body usable without survey prediction" % scenario)


func _hud_wait(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		if _hud_host_manual and is_instance_valid(_hud_host) and _hud_host._network_session_is_live():
			_hud_host._advance_network_boarding_authority()
			_hud_host._advance_network_moving_interior_publication()
			if not _hud_host._network_planetary_journey._state.is_empty():
				_hud_host._network_planetary_journey._publish(false)
			# Publish the real craft telemetry/pose through its existing authority;
			# staged setup pauses only the expedition's automatic cabin transition.
			var attachment := _hud_host._attach_network_ship_authority_composition()
			if bool(attachment.get("accepted", false)):
				_hud_host._network_ship_event_sequence += 1
				_hud_host._network_ship_authority_composition.submit_server_physics_tick(
					maxi(_hud_host._network_boarding_server_tick, _hud_host._network_ship_event_sequence),
					_hud_host._network_ship_event_sequence, _hud_host._build_network_craft_pose_entries())
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _check_attachment_parity(owners: Array[Object], expected: bool, stage: String) -> void:
	for owner: Object in owners:
		var attached: bool = owner.call(&"is_attached")
		var diagnostic: Dictionary = owner.call(&"get_snapshot")
		_check(attached == expected and attached == bool(diagnostic.attached),
			"%s attachment getter preserves its complete report's lifecycle state" % stage)


func _on_semantic_cue(
	_source_id: StringName, cue_id: StringName, _intensity: float, _position: Vector3
) -> void:
	_cues.append(cue_id)


func _test_in_range_minimap_markers() -> void:
	var flow := FlowProbe.new()
	var binding := StatusBindingProbe.new()
	binding.snapshot = {
		"attached": true,
		"view": {
			"accepted": true,
			"attached": true,
			"presentation_only": true,
			"generation": 7,
			"route_guidance": {
				"available": true,
				"target_position": Vector3(24.0, 120000.0, -18.0),
				"navigation_authority": false,
			},
			"optional_objectives": {
				"available": true,
				"nearest_incomplete": {
					"position_body_local_m": Vector3(-17.5, 120000.0, -17.5),
				},
				"navigation_authority": false,
			},
		},
	}
	flow.set("_ember_surface_return_status_binding", binding)
	var markers := flow._get_ember_surface_minimap_markers(23)
	var route := _find_marker(markers, &"active_ember_surface_route")
	var side_task := _find_marker(markers, &"active_ember_side_task")
	_check(
		markers.size() == 2
		and (route.get("position", Vector3.INF) as Vector3) \
			.is_equal_approx(Vector3(24.0, 120000.0, -18.0))
		and (side_task.get("position", Vector3.INF) as Vector3) \
			.is_equal_approx(Vector3(-17.5, 120000.0, -17.5))
		and int(route.get("generation", -1)) == 23
		and int(side_task.get("generation", -1)) == 23,
		"authenticated in-range Ember route and nearest side task join the minimap frame",
	)
	(binding.snapshot.view.route_guidance as Dictionary).available = false
	(binding.snapshot.view.optional_objectives as Dictionary).nearest_incomplete = {}
	_check(
		flow._get_ember_surface_minimap_markers(24).is_empty(),
		"withdrawn Ember guidance cannot leave an in-range minimap target",
	)
	flow.free()


## The authored trailhead offer points can only ask; this owner answers. The
## press must land on the same public `begin_/abandon_ember_caldera_expedition`
## seams an external caller would use, and nothing else may get through.
func _test_caldera_expedition_intent_seam(
		flow: FlowProbe, production: ProductionType,
		planetary: PlanetaryCompositionProbe
	) -> void:
	_check(
		planetary.expedition_intent_sink.is_valid()
			and planetary.expedition_intent_sink.get_object() == flow
			and planetary.expedition_intent_sink.get_method() \
				== "_submit_ember_caldera_expedition_intent",
		"composing the Ember presentation installs GameFlow's own errand seam behind the offer points",
	)
	var begin_intent := {
		"action": &"begin",
		"activity_id": &"ember_lava_tube_sounding",
		"world_id": &"ember_moon",
	}
	var began: Dictionary = planetary.expedition_intent_sink.call(
		begin_intent.duplicate(true)
	)
	var abandoned: Dictionary = planetary.expedition_intent_sink.call({
		"action": &"abandon",
		"activity_id": &"ember_lava_tube_sounding",
		"world_id": &"ember_moon",
	})
	_check(
		bool(began.get("accepted", false))
			and bool(abandoned.get("accepted", false))
			and planetary.started.size() == 1
			and planetary.started[0] == &"ember_lava_tube_sounding"
			and planetary.abandoned.size() == 1
			and planetary.abandoned[0] == &"ember_lava_tube_sounding"
			and StringName(abandoned.get("reason", &"")) == &"player_abandoned",
		"one press each way reaches the retained errand owner exactly once through the public seams",
	)
	var refusals := [
		planetary.expedition_intent_sink.call("not a dictionary"),
		planetary.expedition_intent_sink.call({
			"action": &"begin", "activity_id": &"ember_beacon_survey",
			"world_id": &"ember_moon",
		}),
		planetary.expedition_intent_sink.call({
			"action": &"begin", "activity_id": &"ember_lava_tube_sounding",
			"world_id": &"cinder_reach",
		}),
		planetary.expedition_intent_sink.call({
			"action": &"complete", "activity_id": &"ember_lava_tube_sounding",
			"world_id": &"ember_moon",
		}),
	]
	var all_refused := true
	for refusal: Dictionary in refusals:
		if bool(refusal.get("accepted", true)) \
				or StringName(refusal.get("reason", &"")) \
					!= &"invalid_caldera_expedition_intent":
			all_refused = false
	_check(
		all_refused
			and planetary.started.size() == 1 and planetary.abandoned.size() == 1,
		"a malformed, foreign-world, foreign-activity or unknown-action intent starts nothing",
	)
	planetary.reject_next = true
	var refused_by_owner: Dictionary = planetary.expedition_intent_sink.call(
		begin_intent.duplicate(true)
	)
	planetary.reject_next = false
	_check(
		not bool(refused_by_owner.get("accepted", true))
			and StringName(refused_by_owner.get("reason", &"")) \
				== &"caldera_expedition_unavailable",
		"the errand owner's refusal is reported verbatim rather than being presented as a start",
	)
	planetary.expedition_intent_sink = Callable()
	flow.call("_ensure_ember_surface_presentations")
	_check(
		planetary.expedition_intent_sink.is_valid(),
		"an idempotent presentation pass restores the errand seam after re-entry",
	)
	var detached_flow := FlowProbe.new()
	_check(
		not bool(detached_flow._submit_ember_caldera_expedition_intent({
			"action": &"begin", "activity_id": &"ember_lava_tube_sounding",
			"world_id": &"ember_moon",
		}).get("accepted", true))
		and detached_flow.get_ember_caldera_expedition_report().is_empty(),
		"off Ember, with no surface binding, the same intent cannot start an errand",
	)
	detached_flow.free()
	# The probe's own counters, not GameFlow's, prove nothing was smuggled past
	# the seam while these refusals were being made.
	_check(
		production.get_caldera_expedition_snapshot().get("world_id", &"") \
			== &"ember_moon",
		"the retained production owner remains the single errand report source",
	)


func _find_marker(markers: Array[Dictionary], marker_id: StringName) -> Dictionary:
	for marker in markers:
		if StringName(marker.get("id", &"")) == marker_id:
			return marker.duplicate(true)
	return {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
		printerr("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_EMBER_SURFACE_PRESENTATION_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
