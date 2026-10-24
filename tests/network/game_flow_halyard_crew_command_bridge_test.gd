extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const AdapterType := preload("res://scripts/network/network_enet_session_adapter.gd")
const HalyardType := preload("res://scripts/ships/halyard_crew_transport.gd")
const CrewAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")

class CrewConfirmationFlow extends GameFlowType:
	var crew_view: Dictionary = {}
	var presented := 0

	func _network_physical_crew_view() -> Dictionary:
		return crew_view

	func _present_network_engineer_seat(_seat: ShipCrewSeat) -> void:
		presented += 1
		_network_engineer_pending_seat = null


class CrewRejectionFlow extends CrewConfirmationFlow:
	var current_scope: Dictionary = {}
	var refusals := 0

	# Fixtures isolate the current-scope boundary and toast sink. The physical
	# passenger route exercises production scope construction and actual HUD.
	func _network_halyard_seat_request_scope() -> Dictionary:
		return current_scope.duplicate(true)

	func _present_network_halyard_seat_rejection() -> void:
		refusals += 1


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_current_confirmation_precedes_pending_expiry()
	await _test_orphan_crew_confirmation_is_one_release()
	await _test_current_occupied_chair_rejection()
	var flow := GameFlowType.new()
	var session := AdapterType.new()
	var halyard := HalyardType.new()
	root.add_child(halyard)
	var authority := CrewAuthorityType.new(1)
	_check(authority.register_halyard_roster().accepted, "Halyard roster is available")
	_check(halyard.attach_crew_role_authority(authority).accepted, "Halyard accepts role authority")
	_check(halyard.admit_network_crew_role(7, 3, &"avatar_7", &"pilot_station", &"pilot", 1, 1).accepted,
		"server role admission establishes Halyard assignment")
	flow.network_session = session
	flow.active_ship = halyard
	flow._network_session_mode = &"server"
	_check(flow._attach_network_halyard_command_bridge().accepted, "GameFlow attaches command bridge")
	var receipt := {"accepted": true, "status": &"command_accepted", "receipt": {
		"peer_id": 7, "peer_generation": 3, "avatar_id": &"avatar_7", "seat_id": &"pilot_station",
		"seat_generation": 1, "role": &"pilot", "action": &"flight_command", "ship_id": &"halyard_new_design",
		"ship_generation": 1, "request_sequence": 2, "server_tick": 4, "migration_generation": 1,
		"payload": {"throttle": 0.2, "pitch": -0.1, "yaw": 0.0, "roll": 0.0, "boost": false, "brake": false},
	}}
	flow._on_network_crew_command_result(receipt)
	_check(flow._network_halyard_command_bridge.get_snapshot().dispatch_sequence == 1,
		"server receipt reaches real Halyard command bridge")
	flow._on_network_session_stopped(&"migration")
	_check(flow._network_halyard_command_bridge == null, "session stop detaches and clears bridge")
	flow.free()
	session.free()
	halyard.free()
	if _failures.is_empty():
		print("OK: GameFlow/Halyard crew command bridge (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_current_confirmation_precedes_pending_expiry() -> void:
	for confirmation in ["current", "missing", "foreign"]:
		var flow := CrewConfirmationFlow.new()
		var session := AdapterType.new()
		var halyard := HalyardType.new()
		var seat := ShipCrewSeat.new()
		seat._seat_id = HalyardType.LOADMASTER_STATION_SEAT_ID
		seat._role = &"passenger"
		var source := NetworkRemoteBodyIntentSource.new(1)
		source.bind(&"avatar_7", 1)
		flow.network_session = session
		flow._cabin_ship = halyard
		flow._network_session_mode = &"client"
		flow._network_remote_body_intent_source = source
		flow._network_client_boarding_claim_server_tick = 100
		flow._network_engineer_pending_seat = seat
		flow._network_engineer_pending_elapsed = 4.0
		flow.crew_view = {
			"ship_id": halyard.get_ship_id(), "binding_generation": 1, "server_tick": 100,
			"entity_generation": 2 if confirmation == "foreign" else 1,
			"seated": true,
			"assignment": {"avatar_id": &"avatar_7", "role": &"passenger",
				"seat_id": seat.get_seat_id(), "seat_generation": 1, "claim_sequence": 1},
		} if confirmation != "missing" else {}
		await physics_frame
		flow._advance_network_engineer(1.0 / 60.0)
		source.advance(7, {}, 100)
		_check(flow.presented == (1 if confirmation == "current" else 0),
			"only the already received current confirmation wins the live request expiry tick: " + confirmation)
		_check(flow._network_engineer_pending_seat == null and source.get_interaction_request_id() == 0,
			"expiry processing neither extends the four-second request nor sends a spurious host release: " + confirmation)
		if confirmation != "current":
			_check(flow._network_engineer_pending_elapsed > 4.0,
				"unconfirmed or foreign chair still expires at its original limit: " + confirmation)
		flow.free()
		session.free()
		halyard.free()
		seat.free()


func _test_orphan_crew_confirmation_is_one_release() -> void:
	var flow := CrewConfirmationFlow.new()
	var session := AdapterType.new()
	var halyard := HalyardType.new()
	var source := NetworkRemoteBodyIntentSource.new(1)
	source.bind(&"avatar_7", 1)
	flow.network_session = session
	flow._cabin_ship = halyard
	flow._network_session_mode = &"client"
	flow._network_remote_body_intent_source = source
	flow._network_client_boarding_claim_server_tick = 100
	flow.crew_view = {
		"ship_id": halyard.get_ship_id(), "binding_generation": 1, "server_tick": 100,
		"entity_generation": 1, "seated": true,
		"assignment": {"avatar_id": &"avatar_7", "role": &"passenger",
			"seat_id": HalyardType.LOADMASTER_STATION_SEAT_ID, "seat_generation": 1,
			"claim_sequence": 1},
	}
	# An expired confirmation has no pending local chair. The real source runs
	# across distinct physics frames and sends, exposing repeated host toggles.
	for _tick in 16:
		await physics_frame
		flow._advance_network_engineer(1.0 / 60.0)
		source.advance(7, {}, 100 + _tick)
	_check(source.get_interaction_request_id() == 1 and flow._network_engineer_client_seat == null,
		"a retained orphan confirmation sends one release id and never seats the local player")
	flow.crew_view.assignment.claim_sequence = 2
	await physics_frame
	flow._advance_network_engineer(1.0 / 60.0)
	source.advance(7, {}, 116)
	_check(source.get_interaction_request_id() == 2,
		"a later authenticated chair claim receives its own single orphan release")
	flow.crew_view.entity_generation = 2
	await physics_frame
	flow._advance_network_engineer(1.0 / 60.0)
	source.advance(7, {}, 117)
	_check(source.get_interaction_request_id() == 2,
		"a foreign body generation cannot request an orphan chair release")
	flow.crew_view.entity_generation = 1
	flow._cancel_network_engineer()
	source.unbind()
	source.bind(&"avatar_7", 1)
	flow._network_client_boarding_claim_server_tick = 200
	await physics_frame
	flow._advance_network_engineer(1.0 / 60.0)
	source.advance(7, {}, 118)
	_check(source.get_interaction_request_id() == 2 and flow.presented == 0,
		"a previous admission chair view cannot interact with the replacement stream")
	flow.crew_view.server_tick = 200
	await physics_frame
	flow._advance_network_engineer(1.0 / 60.0)
	source.advance(7, {}, 119)
	_check(source.get_interaction_request_id() == 3,
		"a retired crew lifecycle permits one release from its replacement stream")
	flow.free()
	session.free()
	halyard.free()


func _test_current_occupied_chair_rejection() -> void:
	var flow := CrewRejectionFlow.new()
	var seat := ShipCrewSeat.new()
	var source := NetworkRemoteBodyIntentSource.new(1)
	source.bind(&"avatar_7", 3)
	flow._network_remote_body_intent_source = source
	var epoch := {"package_generation": 1, "session_generation": 2, "migration_generation": 4}
	var scope := {"source_id": source.get_instance_id(), "stream_id": int(source.get_audit().stream_id),
		"entity_id": &"avatar_7", "entity_generation": 3, "player_id": 10, "craft_id": 11,
		"ship_id": &"halyard_new_design", "session_id": 12, "peer_id": 7, "peer_generation": 2,
		"boarding": {"ship_id": &"halyard_new_design", "seat_id": &"cabin_1", "role": &"passenger"},
		"boarding_tick": 100, "seat_id": &"crew_port_00", "role": &"passenger",
		"epoch": epoch}
	flow.current_scope = scope.duplicate(true)
	flow._network_engineer_pending_seat = seat
	var request_id := source.request_interaction()
	source.advance(7, {}, 100)
	_check(not bool(source.get_audit().get("opening_confirmed", false)),
		"staged current chair request has emitted its exact edge before observing an opening ACK")
	flow._network_halyard_seat_request = {"scope": scope.duplicate(true), "interaction_request_id": request_id, "binding_generation": 8}
	var result := {"accepted": false, "status": &"seat_occupied", "interaction_request_id": request_id,
		"stream_id": scope.stream_id, "owner_peer_id": 7, "entity_id": &"avatar_7", "entity_generation": 3,
		"seat_id": &"crew_port_00", "role": &"passenger", "binding_generation": 8, "epoch": epoch}
	var packet := {"ship_id": &"halyard_new_design", "recipient_peer_id": 7, "peer_generation": 2,
		"session_generation": 2, "migration_generation": 4, "binding_generation": 8, "server_tick": 100,
		"seated": false, "assignment": {}, "crew_interaction_result": result}
	for field in ["interaction_request_id", "stream_id", "owner_peer_id", "entity_id", "entity_generation", "seat_id", "role", "binding_generation", "epoch", "accepted", "status"]:
		var wrong := packet.duplicate(true)
		wrong.crew_interaction_result[field] = true if field == "accepted" else null
		flow._consume_network_halyard_seat_rejection(wrong)
		_check(flow.refusals == 0 and flow._network_engineer_pending_seat == seat,
			"foreign or positive occupied-chair result stays silent: " + field)
	for field in ["ship_id", "recipient_peer_id", "peer_generation", "session_generation", "migration_generation", "binding_generation", "server_tick"]:
		var wrong := packet.duplicate(true)
		wrong[field] = null
		_check(not flow._network_halyard_seat_view_is_current(wrong, scope),
			"a foreign initial passenger slot cannot pin a current chair request: " + field)
		flow._consume_network_halyard_seat_rejection(wrong)
		_check(flow.refusals == 0, "foreign passenger envelope stays silent: " + field)
	var wrong_binding := packet.duplicate(true)
	wrong_binding.binding_generation = 9
	wrong_binding.crew_interaction_result.binding_generation = 9
	flow._consume_network_halyard_seat_rejection(wrong_binding)
	_check(flow.refusals == 0, "a known original binding cannot be replaced by another matching envelope/result pair")
	for field in scope.keys():
		flow.current_scope = scope.duplicate(true)
		flow.current_scope[field] = null
		flow._network_halyard_seat_request = {"scope": scope.duplicate(true), "interaction_request_id": request_id, "binding_generation": 8}
		flow._consume_network_halyard_seat_rejection(packet)
		_check(flow.refusals == 0 and flow._network_halyard_seat_request.is_empty(),
			"retired current request scope cannot present an old refusal: " + str(field))
	flow.current_scope = scope.duplicate(true)
	flow._network_halyard_seat_request = {"scope": scope.duplicate(true), "interaction_request_id": request_id, "binding_generation": 8}
	flow._consume_network_halyard_seat_rejection(packet)
	_check(flow.refusals == 1 and flow._network_engineer_pending_seat == null and flow._network_halyard_seat_request.is_empty(),
		"one exact current occupied-chair refusal clears its pending request before feedback even before opening ACK")
	flow._consume_network_halyard_seat_rejection(packet)
	_check(flow.refusals == 1, "repeated current passenger publications cannot replay feedback")
	source.advance(7, {}, 100)
	await physics_frame
	request_id = source.request_interaction()
	source.advance(7, {}, 101)
	flow._network_engineer_pending_seat = seat
	flow._network_halyard_seat_request = {"scope": scope.duplicate(true), "interaction_request_id": request_id, "binding_generation": 0}
	flow._consume_network_halyard_seat_rejection(packet)
	_check(flow.refusals == 1, "a previous refusal cannot answer a fresh press at the same physical chair")
	packet.crew_interaction_result.interaction_request_id = request_id
	flow._consume_network_halyard_seat_rejection(packet)
	_check(flow.refusals == 2 and flow._network_engineer_pending_seat == null,
		"a fresh press made before any binding view earns its own later authenticated refusal")
	await physics_frame
	source.request_interaction()
	source.advance(7, {}, 102)
	flow._network_engineer_pending_seat = seat
	flow._network_halyard_seat_request = {"scope": scope.duplicate(true), "interaction_request_id": request_id, "binding_generation": 8}
	flow._consume_network_halyard_seat_rejection(packet)
	_check(flow.refusals == 2, "a newer emitted non-chair edge makes the old pending chair refusal silent")
	flow.free()
	seat.free()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
