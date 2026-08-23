extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const AdapterType := preload("res://scripts/network/network_enet_session_adapter.gd")
const HalyardType := preload("res://scripts/ships/halyard_crew_transport.gd")
const CrewAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var session := AdapterType.new()
	var halyard := HalyardType.new()
	var authority := CrewAuthorityType.new(1)
	_check(authority.register_halyard_roster().accepted, "Halyard roster is available")
	_check(halyard.attach_crew_role_authority(authority).accepted, "Halyard accepts role authority")
	_check(halyard.admit_network_crew_role(7, 3, &"avatar_7", &"pilot_station", &"pilot", 1, 1).accepted,
		"server role admission establishes Halyard assignment")
	flow.network_session = session
	flow.active_ship = halyard
	_check(flow._attach_network_halyard_command_bridge().accepted, "GameFlow attaches command bridge")
	var receipt := {"accepted": true, "status": &"command_accepted", "receipt": {
		"peer_id": 7, "peer_generation": 3, "avatar_id": &"avatar_7", "seat_id": &"pilot_station",
		"seat_generation": 1, "role": &"pilot", "action": &"flight_command", "ship_id": &"halyard_new_design",
		"ship_generation": 1, "request_sequence": 1, "server_tick": 4, "migration_generation": 1,
		"payload": {"thrust_x": 0.2, "thrust_y": -0.1},
	}}
	session.crew_command_result.emit(receipt)
	_check(flow._network_halyard_command_bridge.get_snapshot().dispatch_sequence == 1,
		"server receipt reaches real Halyard command bridge")
	flow._on_network_session_stopped(&"migration")
	_check(flow._network_halyard_command_bridge == null, "session stop detaches and clears bridge")
	if _failures.is_empty():
		print("OK: GameFlow/Halyard crew command bridge (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
