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


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
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
func _test_client_survey_retirement(scenario: String) -> void:
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
		var store := UserDataStore.new("user://survey-hud-%s-%s.json" % [scenario, pair[1]])
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
			var surface_ready := await _stage_client_survey_surface(server, client, craft, replica, area)
			_check(surface_ready, "%s: real exterior grant makes the client's surface context current" % scenario)
			_hud_setup_failed = not surface_ready
			if surface_ready:
				await _check_client_survey_retirement(scenario, server, client)
	_hud_host_manual = false
	_hud_host = null
	client.shutdown_network_session(&"hud_fixture_done")
	server.shutdown_network_session(&"hud_fixture_done")
	host_view.queue_free()
	client_view.queue_free()
	for _frame in 6:
		await process_frame
		await physics_frame


func _stage_client_survey_surface(server: GameFlow, client: GameFlow, craft: HeroShip, replica: HeroShip, area: ShipBoardingArea) -> bool:
	server.set_physics_process(false)
	_hud_host_manual = true
	var owner := server._aurora_expedition
	var bootstrap := server.aurora_streaming_bootstrap
	var binding := server.aurora_streaming_binding
	if not bool(server._planetary_journey.admit_aurora_visit(craft, false).get("accepted", false)):
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
	owner.state = &"landed"
	owner.survey.attach(surface)
	owner._lease_surface_berth(surface.get_node("LandingRegion"))
	var berth := owner._berth as ShipBerth
	craft.global_transform = berth.get_assist_capture_transform()
	craft.velocity = Vector3.ZERO
	craft.request_berth_landing(berth)
	if not await _hud_wait(func(): return berth.get_occupant() == craft and not craft.is_landing_active(), 15.0):
		return false
	var bridge := server._network_planetary_journey
	bridge._epoch = 2
	bridge._craft_instance_id = craft.get_instance_id()
	bridge._pilot_source_ref = weakref(craft.get_command_source())
	bridge._state = {"journey_epoch": 2, "world_id": &"aurora_temperate_world", "ship_id": craft.get_ship_id(), "phase": &"landed"}
	bridge._publish(true)
	if not await _hud_wait(func(): return server._network_aurora_passenger_host_is_current(craft) and client._network_client_ember_surface_scene_is_current(replica, 2), 12.0):
		print("SURVEY_HUD_SETUP_CURRENT server=", server._network_aurora_passenger_host_is_current(craft), " client=", client._network_client_ember_surface_scene_is_current(replica, 2), " journey=", client.get_network_planetary_journey_snapshot(), " pose=", client._network_craft_pose_stream.latest_sample(replica.get_ship_id()))
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
		print("SURVEY_HUD_SETUP_DEPARTURE asked=", departure, " answer=", client.network_session.get_boarding_intent_result_replica(), " context=", client._network_client_ember_passenger_surface, " host=", server._network_aurora_passenger_host_is_current(craft))
		return false
	client.set_physics_process(false)
	client._update_on_foot_flow()
	return str(client.hud.get("_objective_source_text")).contains("Optional shared survey")


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


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_EMBER_SURFACE_PRESENTATION_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
