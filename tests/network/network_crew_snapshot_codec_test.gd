extends SceneTree

const Codec := preload("res://scripts/network/network_crew_snapshot_codec.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var codec := Codec.new()
	var role := {"peer_id": 7, "peer_generation": 3, "avatar_id": &"avatar_7", "seat_id": &"pilot_seat", "seat_generation": 2, "role": &"pilot", "ship_id": &"ship_7", "ship_generation": 2, "request_sequence": 1, "migration_generation": 1}
	var command := role.duplicate(true)
	command["action"] = &"flight_command"
	command["server_tick"] = 12
	command["payload"] = {"thrust_x": 0.25, "thrust_y": -0.5}
	var encoded := codec.encode({"migration_generation": 1, "event_sequence": 2, "roles": {"7:avatar_7": role}}, {"migration_generation": 1, "event_sequence": 3}, [{"receipt": command}])
	_check(encoded.accepted, "bounded crew snapshot encodes")
	var decoded := codec.decode(encoded.bytes)
	_check(decoded.accepted and decoded.snapshot.roles.size() == 1 and decoded.snapshot.commands.size() == 1, "crew snapshot round-trips")
	var unknown: PackedByteArray = encoded.bytes.duplicate()
	var unknown_doc: Dictionary = JSON.parse_string(unknown.get_string_from_utf8())
	unknown_doc["unexpected"] = true
	_check(codec.decode(JSON.stringify(unknown_doc).to_utf8_buffer()).status == &"unknown_snapshot_field", "unknown top-level fields reject")
	var missing := role.duplicate(true)
	missing.erase("ship_id")
	_check(codec.encode({"roles": {"x": missing}}, {}, []).status == &"missing_record_field", "missing ship identity rejects")
	var oversized := role.duplicate(true)
	oversized["ship_id"] = "x".repeat(5000)
	_check(codec.encode({"roles": {"x": oversized}}, {}, []).status == &"invalid_record_identity", "oversized identity rejects")
	var huge_command := command.duplicate(true)
	huge_command["payload"] = {"marker": "x".repeat(5000)}
	_check(codec.encode({}, {}, [{"receipt": huge_command}]).status == &"byte_limit_exceeded", "snapshot byte budget rejects")
	if _failures.is_empty():
		print("OK: crew snapshot codec (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
