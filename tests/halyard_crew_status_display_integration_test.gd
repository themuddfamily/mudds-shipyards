extends SceneTree

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const BodySource := preload("res://scripts/network/network_remote_body_intent_source.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


# Keep world startup outside this focused consumer test. All replica handling
# and cabin-lifetime predicates remain the production GameFlow implementation.
class PanelFlow extends GameFlowType:

	func _enter_tree() -> void:
		pass

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _exit_tree() -> void:
		pass

	func _network_client_peer_id() -> int:
		return 7

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft: Node = HALYARD_SCENE.instantiate()
	root.add_child(craft)
	await process_frame
	await physics_frame
	var display: Node = craft.get_crew_status_display()
	_check(
		display != null
			and is_instance_valid(display)
			and display.get_parent().name == "CabinStatusPanel",
		"the Halyard retains one crew status display beneath the authored cabin panel"
	)
	_check(
		display.get_readout_text().contains("ROSTER [DETACHED]"),
		"the retained display starts with a safe empty-crew state"
	)
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the focused authority roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the Halyard accepts the focused authority")
	_check(bool(authority.claim(1, 71, &"pilot_avatar", &"pilot_station", Authority.ROLE_PILOT, 1).get("accepted", false)), "the pilot claim is admitted")
	_check(bool(authority.claim(1, 77, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1).get("accepted", false)), "the engineer claim is admitted")
	var refreshed: Dictionary = craft.refresh_crew_status_display()
	_check(
		bool(refreshed.get("pilot_ready", false))
			and int(refreshed.get("optional_crew_count", 0)) == 1
			and display.get_readout_text().contains("P [ACTIVE] G [OPEN]")
			and display.get_readout_text().contains("E [ACTIVE] X [OPEN]"),
		"an explicit detached-snapshot refresh drives pilot readiness and optional-role tokens"
	)
	var released: Dictionary = craft.release_crew_role(1, 71, &"pilot_avatar", &"pilot_station", 2, 1)
	_check(bool(released.get("accepted", false)), "the pilot release is admitted")
	_check(
		not display.get_display_snapshot().get("pilot_ready", true)
			and display.get_readout_text().contains("DEPART [WAIT PILOT]"),
		"role detach clears visible departure readiness without polling"
	)
	var generation_before_reentry := int(
		display.get_repair_presentation_snapshot().get("generation", -1)
	)
	craft.call("_set_interior_operational", false)
	_check(
		display.get_readout_text().contains("ROSTER [DETACHED]"),
		"interior shutdown clears the retained presentation"
	)
	craft.call("_set_interior_operational", true)
	_check(
		display.get_readout_text().contains("DEPART [WAIT PILOT]")
			and display.get_display_snapshot().get("optional_crew_count", -1) == 1
			and int(display.get_repair_presentation_snapshot().get("generation", -1))
				> generation_before_reentry
			and display.get_readout_text().contains("IDLE // REPAIR READY"),
		"interior re-entry advances the repair fence and reapplies a clean detached crew snapshot"
	)
	var generation_before_release := int(
		display.get_repair_presentation_snapshot().get("generation", -1)
	)
	var engineer_release: Dictionary = craft.release_crew_role(
		1, 77, &"engineer_avatar", &"crew_port_01", 2, 1
	)
	_check(bool(engineer_release.get("accepted", false)), "the engineer role release is admitted")
	var released_gameplay: Dictionary = craft.get_crew_role_gameplay_snapshot()
	var released_network: Dictionary = craft.get_engineer_repair_network_snapshot()
	_check(
		int(display.get_repair_presentation_snapshot().get("generation", -1))
			> generation_before_release
			and display.get_readout_text().contains("E [OPEN]")
			and display.get_readout_text().contains("ENG ROUTE [NONE]")
			and display.get_readout_text().contains("IDLE // REPAIR READY")
			and ((released_gameplay.get("selected_targets", {}) as Dictionary).get("engineer", {}) as Dictionary).is_empty()
			and ((released_network.get("owner", {}) as Dictionary).is_empty()),
		"engineer role release opens the station, clears route and owner, and advances its snapshot fence"
	)
	var generation_before_reuse := int(
		display.get_repair_presentation_snapshot().get("generation", -1)
	)
	var reset: Dictionary = craft.reset_for_reuse(Transform3D.IDENTITY)
	_check(bool(reset.get("accepted", false)), "the Halyard reuse reset is admitted")
	_check(
		int(display.get_repair_presentation_snapshot().get("generation", -1))
			> generation_before_reuse
			and display.get_readout_text().contains("IDLE // REPAIR READY"),
		"craft reuse clears the engineer station and advances its repair generation"
	)
	# Streaming the craft out of the tree and back is what every production
	# `Main` re-entry does to it. `_exit_tree()` parks the panel on its detached
	# copy and arms a one-shot skip for the outgoing lifecycle's repair envelope;
	# the refresh on the way back in has to republish the live one, or the craft
	# comes back with the repair-kit inventory field missing from its cabin panel
	# while carrying a full kit load.
	var kit_capacity := int(
		((craft.get_engineer_repair_network_snapshot().get("repair", {}) as Dictionary)
			.get("resource_capacity", 0))
	)
	var kit_token := "KITS %d/%d" % [kit_capacity, kit_capacity]
	_check(
		kit_capacity > 0 and display.get_readout_text().contains(kit_token),
		"the parked craft's cabin panel carries its full repair-kit inventory"
	)
	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	await process_frame
	await physics_frame
	_check(
		display.get_readout_text().contains(kit_token),
		"a craft streamed out of the tree and back keeps its repair-kit inventory"
	)
	await _check_host_repair_panel(craft, display)
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_CREW_STATUS_DISPLAY_INTEGRATION_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check_host_repair_panel(craft: Node, display: Node) -> void:
	var host: Node = HALYARD_SCENE.instantiate()
	root.add_child(host)
	await process_frame
	# Freeze both local simulations while advancing the host's real authority
	# explicitly. There are no fabricated successful repair receipts here.
	host.set_physics_process(false)
	craft.set_physics_process(false)
	var authority := Authority.new(1)
	_check(
		bool(authority.register_halyard_roster().get("accepted", false))
			and bool(authority.claim(1, 77, &"host_engineer", &"crew_port_01", Authority.ROLE_ENGINEER, 1).get("accepted", false))
			and bool(host.attach_crew_role_authority(authority).get("accepted", false)),
		"the independent host admits its actual engineer authority"
	)
	var model: ShipComponentDamage = host.get_component_damage()
	var damage := model.record_damage(70.0, Vector3.INF)
	var component_id: StringName = &""
	for candidate in model.COMPONENT_ORDER:
		if model.get_component_integrity(candidate) < 1.0:
			component_id = candidate
			break
	host.set("_landed", true)
	var started: Dictionary = host.submit_crew_intent(
		1, 77, &"host_engineer", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1}, 2
	)
	host.call("_advance_engineer_repair", 0.2)
	var progress: Dictionary = host.get_engineer_gameplay_state()
	var repair := progress.get("repair", {}) as Dictionary
	_check(
		bool(damage.get("accepted", false)) and bool(started.get("consumed", false))
			and repair.get("status") == &"repairing"
			and float(repair.get("progress", 0.0)) > 0.0,
		"the real host repair authority produces active nonzero progress"
	)
	var local_repair: Dictionary = craft.get_engineer_repair_state()
	var local_components: Dictionary = craft.get_component_damage().get_component_report()
	var session := Adapter.new()
	root.add_child(session)
	session._configured = true
	session._server_offer = {"admission": {"accepted": true, "peer": {"peer_id": 7, "peer_generation": 1}}}
	var epoch := session.get_migration_snapshot()
	var flow := PanelFlow.new()
	root.add_child(flow)
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	flow.player = player
	flow.network_session = session
	flow._network_session_mode = &"client"
	flow.phase = GameFlowType.Phase.IN_FLIGHT_CABIN
	flow._cabin_ship = craft
	flow._network_client_boarding_claim = {"ship_id": craft.get_ship_id(), "seat_id": &"berth_01", "role": &"passenger"}
	flow._network_client_boarding_claim_server_tick = 10
	flow._network_remote_body_intent_source = BodySource.new()
	flow._network_remote_body_intent_source.bind(GameFlowType.network_client_boarding_avatar_id(7), 1, 1)
	flow._advance_network_engineer(0.0)
	craft.refresh_crew_status_display()
	_check(
		display.get_readout_text().contains("AWAITING HOST")
			and not display.get_readout_text().contains("KITS"),
		"a current client cabin awaits its host instead of showing local kit authority"
	)
	# Deliberately stage the already-admitted replica boundary, not transport
	# admission. The separate real ENet route proves publication and receipt.
	# Empty assignment is the host's normal view for a walking cabin occupant.
	var packet := {
		"ship_id": craft.get_ship_id(), "recipient_peer_id": 7, "peer_generation": 1,
		"session_generation": int(epoch.get("session_generation", 0)),
		"migration_generation": int(epoch.get("migration_generation", 0)),
		"revision": 1, "binding_generation": 1, "server_tick": 11,
		"assignment": {}, "seated": false, "entity_generation": 0,
		"gameplay": progress.duplicate(true), "components": {},
	}
	var previous_grant := packet.duplicate(true)
	previous_grant["server_tick"] = 9
	session._engineer_replica_snapshot = previous_grant
	flow._advance_network_engineer(0.0)
	_check(
		display.get_readout_text().contains("AWAITING HOST")
			and not display.get_readout_text().contains("REPAIRING"),
		"a cached repair view from before the current boarding grant cannot populate the panel"
	)
	session._engineer_replica_snapshot = packet.duplicate(true)
	flow._advance_network_engineer(0.0)
	var percent := "%d%%" % roundi(float(repair.get("progress", 0.0)) * 100.0)
	_check(
		display.get_readout_text().contains("REPAIRING")
			and display.get_readout_text().contains(percent),
		"a walking client's physical Halyard panel displays accepted host repair progress"
	)
	craft.refresh_crew_status_display()
	_check(
		display.get_readout_text().contains("REPAIRING")
			and display.get_readout_text().contains(percent),
		"a local cabin refresh cannot overwrite accepted host repair progress"
	)
	host.call("_advance_engineer_repair", 0.5)
	var completed: Dictionary = host.get_engineer_gameplay_state()
	var completed_repair := completed.get("repair", {}) as Dictionary
	var capacity := int(completed_repair.get("resource_capacity", 0))
	_check(
		completed_repair.get("status") == &"completed"
			and int(completed_repair.get("resource_units", -1)) == capacity - 1,
		"the host actually commits its repair and spends one finite kit"
	)
	packet["revision"] = 2
	packet["server_tick"] = 12
	packet["gameplay"] = completed.duplicate(true)
	session._engineer_replica_snapshot = packet.duplicate(true)
	flow._advance_network_engineer(0.0)
	craft.refresh_crew_status_display()
	_check(
		display.get_readout_text().contains("COMPLETED")
			and display.get_readout_text().contains("KITS %d/%d" % [capacity - 1, capacity]),
		"the walking client's physical panel retains host completion and spent stock across refresh"
	)
	_check(
		craft.get_engineer_repair_state() == local_repair
			and craft.get_component_damage().get_component_report() == local_components,
		"host presentation never changes the client's local repair authority or component ledger"
	)
	flow._cabin_ship = null
	flow._advance_network_engineer(0.0)
	_check(
		display.get_readout_text().contains("IDLE // REPAIR READY")
			and display.get_readout_text().contains("KITS %d/%d" % [capacity, capacity]),
		"leaving the live cabin restores its local repair presentation"
	)
	flow._cabin_ship = craft
	flow._advance_network_engineer(0.0)
	session._configured = false
	flow._advance_network_engineer(0.0)
	_check(
		display.get_readout_text().contains("IDLE // REPAIR READY")
			and display.get_readout_text().contains("KITS %d/%d" % [capacity, capacity]),
		"a stopped session restores the local repair presentation"
	)
	flow._cabin_ship = null
	flow.free()
	session.queue_free()
	player.queue_free()
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
