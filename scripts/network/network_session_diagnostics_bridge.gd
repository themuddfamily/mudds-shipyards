class_name NetworkSessionDiagnosticsBridge
extends RefCounted

## Privacy-safe adapter from the ENet session seam to the existing diagnostic
## lifecycle bridge. It forwards only finite reason/quality counters.

var _lifecycle_bridge


func _init(lifecycle_bridge = null) -> void:
	_lifecycle_bridge = lifecycle_bridge


func publish(adapter, session_id: int, physics_tick: int, elapsed_physics_seconds: float, generation: int) -> Dictionary:
	if _lifecycle_bridge == null or adapter == null:
		return {"accepted": false, "status": &"bridge_unavailable"}
	var end_reason: Dictionary = adapter.get_session_end_reason_snapshot()
	var reason := StringName(end_reason.get("reason", &"unknown"))
	var reason_code: int = {
		"unknown": 0,
		"timeout": 1,
		"rejected": 2,
		"protocol_mismatch": 3,
		"host_migration": 4,
		"manual_leave": 5,
	}.get(String(reason), 0)
	var quality: Dictionary = adapter.get_session_quality_telemetry()
	return _lifecycle_bridge.record_network_observation(
		session_id, physics_tick, elapsed_physics_seconds, generation,
		int(reason_code), quality
	)


func detach() -> Dictionary:
	_lifecycle_bridge = null
	return {"accepted": true, "status": &"detached"}
