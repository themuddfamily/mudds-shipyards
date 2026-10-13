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


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_current_confirmation_precedes_pending_expiry()
	await _test_orphan_crew_confirmation_is_one_release()
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
		flow._network_engineer_pending_seat = seat
		flow._network_engineer_pending_elapsed = 4.0
		flow.crew_view = {
			"ship_id": halyard.get_ship_id(), "binding_generation": 1,
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
	flow.crew_view = {
		"ship_id": halyard.get_ship_id(), "binding_generation": 1,
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
	await physics_frame
	flow._advance_network_engineer(1.0 / 60.0)
	source.advance(7, {}, 118)
	_check(source.get_interaction_request_id() == 3,
		"a retired crew lifecycle permits one release from its replacement stream")
	flow.free()
	session.free()
	halyard.free()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
