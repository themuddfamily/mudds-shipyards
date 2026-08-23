extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")

class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []
	signal presentation_intent_requested(kind: StringName, payload: Dictionary)

	func update_network_session_status(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))


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
	flow.free()
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
