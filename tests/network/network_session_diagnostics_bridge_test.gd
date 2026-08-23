extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const DiagnosticsBridge := preload("res://scripts/network/network_session_diagnostics_bridge.gd")

class FakeLifecycleBridge extends RefCounted:
	var observations: Array = []

	func record_network_observation(session_id: int, tick: int, elapsed: float, generation: int, reason_code: int, quality: Dictionary) -> Dictionary:
		observations.append({"session_id": session_id, "tick": tick, "elapsed": elapsed, "generation": generation, "reason_code": reason_code, "quality": quality.duplicate(true)})
		return {"accepted": true, "reason": &"network_recorded"}


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	adapter.record_session_end(&"connection_timeout", 2, 4)
	var lifecycle := FakeLifecycleBridge.new()
	var bridge := DiagnosticsBridge.new(lifecycle)
	var published := bridge.publish(adapter, 42, 100, 1.5, 4)
	_check(published.accepted and lifecycle.observations.size() == 1,
		"network diagnostics bridge forwards a detached observation")
	var observation: Dictionary = lifecycle.observations[0]
	_check(int(observation.reason_code) == 1 and int(observation.session_id) == 42
		and int((observation.quality as Dictionary).buffer_count) == 7,
		"bridge maps only normalized reason and bounded quality counters")
	_check((bridge.detach()).accepted and not bridge.publish(adapter, 42, 101, 1.6, 4).accepted,
		"diagnostics detach fences later publication")
	if _failures.is_empty():
		print("OK: network diagnostics bridge (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
