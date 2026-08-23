extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _rejections: Array[StringName] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	var hosted := adapter.host(29124, 1)
	_check(hosted.accepted, "server capacity is configured")
	_check(adapter.get_session_capacity_snapshot().max_players == 1
		and adapter.get_session_capacity_snapshot().occupancy == 0,
		"capacity snapshot starts empty")
	adapter.transport_rejected.connect(func(status: StringName) -> void: _rejections.append(status))
	adapter._peer_generations[7] = 3
	_check(adapter.get_session_capacity_snapshot().available_slots == 0,
		"admitted peer consumes the bounded slot")
	adapter._receive_hello({})
	_check(_rejections.has(&"session_full"), "full handshake is rejected as session_full")
	adapter._peer_generations.erase(7)
	_check(adapter.get_session_capacity_snapshot().available_slots == 1,
		"released peer restores capacity")
	adapter.shutdown(&"test_complete")
	if _failures.is_empty():
		print("OK: ENet session capacity (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
