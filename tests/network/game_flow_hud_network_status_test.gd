extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const StatusPresenter := preload("res://scripts/ui/network_session_status_presenter.gd")

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
	var presenter := StatusPresenter.new()
	flow._on_network_session_stopped(&"server_disconnected")
	var host_lost := presenter.present_snapshot(probe.snapshots.back())
	_check(host_lost.message.begins_with("Connection to the session host was lost."),
		"the production host-loss receipt presents a readable explanation")
	flow._on_network_session_started(&"client")
	var retrying := presenter.present_snapshot(probe.snapshots.back())
	_check(retrying.state == &"connecting" and not retrying.message.contains("was lost"),
		"a new production session clears the retired host-loss receipt")
	flow._on_network_session_stopped(&"connection_failed")
	var unreachable := presenter.present_snapshot(probe.snapshots.back())
	_check(unreachable.message.begins_with("Could not reach the session host."),
		"the production initial-connection failure presents readable recovery guidance")
	flow._on_network_session_started(&"client")
	presenter.present_snapshot(probe.snapshots.back())
	flow._on_network_session_stopped(&"protocol_mismatch")
	_check(probe.snapshots.back().get("detail") == "Session closed: protocol_mismatch",
		"admission refusal reaches the presenter through the actual protocol-mismatch detail")
	var incompatible := presenter.present_snapshot(probe.snapshots.back())
	_check(incompatible.message.begins_with("Your game and the host use incompatible session protocols.")
		and incompatible.message.contains("same game version"),
		"the production incompatible-host receipt explains how to resolve the mismatch")
	_check(incompatible.state == &"disconnected" and presenter.request_retry().accepted
		and not presenter.request_disconnect().accepted,
		"protocol guidance preserves the caller-owned disconnected retry choices")
	flow._on_network_session_started(&"client")
	var after_protocol_retry := presenter.present_snapshot(probe.snapshots.back())
	_check(after_protocol_retry.state == &"connecting"
		and after_protocol_retry.message.begins_with("Contacting the session host.")
		and not after_protocol_retry.message.contains("incompatible")
		and after_protocol_retry.actions[0].id == &"cancel",
		"a fresh production attempt replaces protocol-mismatch guidance with current connecting status")
	flow.free()
	probe.free()
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
