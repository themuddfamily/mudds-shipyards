extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	var compatible := _entry(&"compatible", 1, 1)
	var protocol_mismatch := _entry(&"old_protocol", 0, 1)
	var build_mismatch := _entry(&"old_build", 1, 2)
	_check(adapter.apply_server_directory_snapshot(4, 10, [compatible, protocol_mismatch, build_mismatch]).accepted,
		"directory accepts versioned records")
	var listing := adapter.query_compatible_server_directory()
	_check(listing.compatible.size() == 1 and listing.compatible[0].session_id == &"compatible",
		"compatibility query keeps only matching protocol/build")
	_check(listing.incompatible.size() == 2,
		"compatibility query exposes detached incompatibility records")
	_check(adapter.create_join_intent(&"old_protocol").status == &"protocol_mismatch",
		"protocol-incompatible join intent is rejected")
	_check(adapter.create_join_intent(&"old_build").status == &"build_mismatch",
		"build-incompatible join intent is rejected")
	var intent := adapter.create_join_intent(&"compatible")
	_check(intent.accepted and adapter.consume_join_intent({"session_id": &"old_protocol", "directory_generation": 4, "intent_sequence": 99}).status == &"protocol_mismatch",
		"incompatible intent cannot be consumed")
	if _failures.is_empty():
		print("OK: ENet discovery compatibility (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _entry(session_id: StringName, protocol_version: int, build_version: int) -> Dictionary:
	return {"session_id": session_id, "host_peer_id": 2, "title": "Compatibility Probe",
		"region_id": &"lan", "ping_ms": -1, "player_count": 0, "max_players": 2,
		"protocol_version": protocol_version, "build_version": build_version}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
