extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	var registered := server.register_remote_ship_pilot(2, &"cinder-long-range-bomber", 1)
	_check(bool(registered.get("accepted", false)), "server admits current pilot owner")
	var valid := {
		"schema_version": 1, "peer_id": 2, "entity_id": &"cinder-long-range-bomber",
		"entity_generation": 1, "stream_id": 0, "sequence": 0, "client_tick": 1,
		"move_axis": [0.5, 0.0], "board_request": false, "boarding_target_id": &"",
		"disembark_request": false,
	}
	_check(bool(server._remote_ship_commands.accept_command(2, valid).get("accepted", false)),
		"valid finite pilot intent is accepted")
	_check(bool(server.consume_remote_ship_command(&"cinder-long-range-bomber", 1).get("accepted", false)),
		"server delivers one accepted command per tick")
	var replay := valid.duplicate(true)
	_check(not bool(server._remote_ship_commands.accept_command(2, replay).get("accepted", false)),
		"replayed sequence is rejected")
	var spoof := valid.duplicate(true)
	spoof["sequence"] = 1
	spoof["peer_id"] = 3
	_check(not bool(server._remote_ship_commands.accept_command(2, spoof).get("accepted", false)),
		"spoofed peer is rejected")
	var oversized := valid.duplicate(true)
	oversized["sequence"] = 2
	oversized["move_axis"] = [2.0, 0.0]
	_check(not bool(server._remote_ship_commands.accept_command(2, oversized).get("accepted", false)),
		"out-of-bounds axis is rejected")
	_check(bool(server.reset_remote_ship_pilot(&"cinder-long-range-bomber", &"disconnect").get("accepted", false)),
		"disconnect reset retires command source")
	_check(int(server.get_remote_ship_command_snapshot().get("pilot_count", -1)) == 0,
		"retired pilot cannot retain command state")
	server.free()
	if _failures.is_empty():
		print("OK: GameFlow remote ship command integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
