extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const StatusPresenter := preload("res://scripts/ui/network_session_status_presenter.gd")
const AdapterType := preload("res://scripts/network/network_enet_session_adapter.gd")
const BodySourceType := preload("res://scripts/network/network_remote_body_intent_source.gd")

class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []
	signal presentation_intent_requested(kind: StringName, payload: Dictionary)

	func update_network_session_status(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))


class CrewFlowProbe extends GameFlowType:
	var crew_view: Dictionary = {}

	func _network_client_boarding_holds(_craft: HeroShip) -> bool:
		return true

	func _network_physical_crew_view() -> Dictionary:
		return crew_view

	func _bind_cabin_occupancy(_craft: HeroShip) -> void:
		pass

	func _sync_network_moving_interior_presenter() -> void:
		pass


class CrewSessionProbe extends AdapterType:
	var active := true

	func _ready() -> void:
		pass

	func is_session_active() -> bool:
		return active

	func get_migration_snapshot() -> Dictionary:
		return {"migration_generation": 0}

	func get_authoritative_snapshot() -> Dictionary:
		return {}

	func get_crew_role_snapshot() -> Dictionary:
		return {"roles": {}}


class CrewCraftProbe extends HeroShip:
	func _ready() -> void:
		set_physics_process(false)
		set_process(false)


class CrewPlayerProbe extends CharacterBody3D:
	signal boarding_completed
	signal disembarking_completed

	func begin_boarding(_entry: Transform3D, _anchor: Node3D, _duration: float, _craft: Node3D) -> bool:
		return true

	func begin_disembark(_exit: Transform3D, _duration: float, _craft: Node3D) -> bool:
		return true

	func set_station_seated_context(_seated: bool) -> void:
		pass

	func set_control_enabled(_enabled: bool) -> void:
		pass

	func force_recovery_to_on_foot(_pose: Transform3D) -> void:
		pass


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var probe := HudProbe.new()
	flow.hud = probe
	flow._connect_runtime_signals()
	flow._network_session_mode = &"client"
	flow._on_network_session_started(&"client")
	_check(probe.snapshots.back().get("state") == &"connecting", "join lifecycle presents connecting")
	flow._on_network_session_started(&"server")
	_check(probe.snapshots.back().get("state") == &"connected", "host lifecycle presents connected")
	flow._on_network_peer_admitted(7, {})
	_check(probe.snapshots.back().get("state") == &"connected", "server offer presents connected")
	flow._on_network_transport_rejected(&"connect_failed")
	_check(probe.snapshots.back().get("state") == &"failed", "transport failure presents failed")
	_check(bool(probe.snapshots.back().get("retryable", false)), "transport failure remains retryable")
	flow._on_network_session_stopped(&"requested")
	_check(probe.snapshots.back().get("state") == &"disconnected", "shutdown presents disconnected")
	_check(flow.get_network_session() == null, "status wiring does not create an opt-in network node")
	var presenter := StatusPresenter.new()
	flow._on_network_session_stopped(&"server_disconnected")
	var host_lost := presenter.present_snapshot(probe.snapshots.back())
	_check(host_lost.message.begins_with("Connection to the session host was lost."),
		"the production host-loss receipt presents a readable explanation")
	flow._on_network_session_started(&"client")
	var retrying := presenter.present_snapshot(probe.snapshots.back())
	_check(retrying.state == &"connecting" and not retrying.message.contains("was lost"),
		"a new production session clears the retired host-loss receipt")
	flow._on_network_session_stopped(&"connection_failed")
	var unreachable := presenter.present_snapshot(probe.snapshots.back())
	_check(unreachable.message.begins_with("Could not reach the session host."),
		"the production initial-connection failure presents readable recovery guidance")
	flow._on_network_session_started(&"client")
	presenter.present_snapshot(probe.snapshots.back())
	flow._on_network_session_stopped(&"protocol_mismatch")
	_check(probe.snapshots.back().get("detail") == "Session closed: protocol_mismatch",
		"admission refusal reaches the presenter through the actual protocol-mismatch detail")
	var incompatible := presenter.present_snapshot(probe.snapshots.back())
	_check(incompatible.message.begins_with("Your game and the host use incompatible session protocols.")
		and incompatible.message.contains("same game version"),
		"the production incompatible-host receipt explains how to resolve the mismatch")
	_check(incompatible.state == &"disconnected" and presenter.request_retry().accepted
		and not presenter.request_disconnect().accepted,
		"protocol guidance preserves the caller-owned disconnected retry choices")
	flow._on_network_session_started(&"client")
	var after_protocol_retry := presenter.present_snapshot(probe.snapshots.back())
	_check(after_protocol_retry.state == &"connecting"
		and after_protocol_retry.message.begins_with("Contacting the session host.")
		and not after_protocol_retry.message.contains("incompatible")
		and after_protocol_retry.actions[0].id == &"cancel",
		"a fresh production attempt replaces protocol-mismatch guidance with current connecting status")
	await _check_confirmed_crew_publication()
	flow.free()
	probe.free()
	if _failures.is_empty():
		print("GAME_FLOW_HUD_NETWORK_STATUS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


## Run the production confirmation/stand callbacks. Only animation timing,
## accepted host-view input and cabin binding are supplied by bounded probes.
func _check_confirmed_crew_publication() -> void:
	var flow := CrewFlowProbe.new()
	var probe := HudProbe.new()
	var session := CrewSessionProbe.new()
	var craft := CrewCraftProbe.new()
	var actor := CrewPlayerProbe.new()
	var seat := ShipCrewSeat.new()
	var anchor := Marker3D.new()
	craft.add_child(anchor)
	seat._ship = craft
	seat._anchor = anchor
	seat._role = &"gunner"
	seat._seat_id = &"gunner_station"
	var source := BodySourceType.new()
	source.bind(&"crew_avatar", 3)
	root.add_child(session)
	root.add_child(craft)
	root.add_child(actor)
	flow.hud = probe
	flow.player = actor
	flow.network_session = session
	flow.active_ship = craft
	flow._cabin_ship = craft
	flow._network_session_mode = &"client"
	flow._network_remote_body_intent_source = source
	flow.crew_view = {"seated": true, "entity_generation": 3, "assignment": {"claim_sequence": 7}}
	flow._publish_network_session_snapshot(&"connected", &"client", "Host admitted this client.")
	var presenter := StatusPresenter.new()
	presenter.present_snapshot(probe.snapshots.back())
	var count := probe.snapshots.size()
	var epoch := int(probe.snapshots.back().generation)
	flow._present_network_engineer_seat(seat)
	_check(probe.snapshots.size() == count and not flow._station_seated,
		"pending crew animation does not publish an unconfirmed gunner role")
	actor.boarding_completed.emit()
	await process_frame
	var seated := presenter.present_snapshot(probe.snapshots.back())
	_check(probe.snapshots.size() == count + 1 and seated.ownership_text == "GUNNER"
		and seated.next_action == "CONTINUE AS GUNNER OR DISCONNECT" and flow._station_seated,
		"confirmed gunner transition immediately updates the HUD without another session event")
	_check(int(probe.snapshots.back().generation) == epoch and int(probe.snapshots.back().sequence) > count,
		"crew publication advances presentation sequence without creating a new session epoch")
	count = probe.snapshots.size()
	flow._finish_network_engineer_stand()
	_check(probe.snapshots.size() == count,
		"pending stand retains the confirmed role until disembark completes")
	actor.disembarking_completed.emit()
	await process_frame
	var standing := presenter.present_snapshot(probe.snapshots.back())
	_check(probe.snapshots.size() == count + 1 and standing.ownership_text == "OBSERVER"
		and standing.state == &"connected" and not flow._station_seated,
		"completed stand immediately clears the gunner label in the same connected session")
	flow._network_engineer_client_seat = seat
	count = probe.snapshots.size()
	flow._cancel_network_engineer()
	_check(probe.snapshots.size() == count + 1 and probe.snapshots.back().local_role == &"observer",
		"ordinary live crew cancellation refreshes the released role")
	flow._network_engineer_client_seat = seat
	count = probe.snapshots.size()
	flow._on_network_migration_result({"accepted": true})
	_check(probe.snapshots.size() == count and flow._network_engineer_client_seat == null,
		"actual migration cleanup releases the chair without publishing a synthetic connected update")
	for state: StringName in [&"connecting", &"failed", &"migrating", &"disconnected"]:
		flow._publish_network_session_snapshot(state, &"client", "Retain lifecycle status.")
		flow._network_engineer_client_seat = seat
		count = probe.snapshots.size()
		flow._cancel_network_engineer()
		_check(probe.snapshots.size() == count and probe.snapshots.back().state == state,
			"crew cleanup cannot promote %s while the transport temporarily remains active" % state)
	flow._publish_network_session_snapshot(&"connected", &"client", "Connected before transport loss.")
	session.active = false
	flow._network_engineer_client_seat = seat
	count = probe.snapshots.size()
	flow._cancel_network_engineer()
	_check(probe.snapshots.size() == count,
		"inactive transport cleanup cannot repaint an old connected status")
	flow.free()
	probe.free()
	seat.free()
	actor.free()
	craft.free()
	session.free()
