extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	_check(flow.get_network_session() == null, "solo GameFlow starts without a network node")
	var detached_host := flow.host_network_session()
	_check(
		not bool(detached_host.get("accepted", true))
		and detached_host.get("status") == &"game_flow_not_in_tree",
		"detached GameFlow cannot open a transport implicitly"
	)
	_check(flow.get_network_session() == null, "rejected detached hosting leaves solo state untouched")
	var detached_join := flow.join_network_session("127.0.0.1", 27101)
	_check(
		not bool(detached_join.get("accepted", true))
		and detached_join.get("status") == &"game_flow_not_in_tree",
		"detached GameFlow cannot join a transport implicitly"
	)
	_check(
		not bool(flow.shutdown_network_session().get("accepted", true)),
		"shutdown remains a no-op before opt-in session creation"
	)
	flow.free()
	if _failures.is_empty():
		print("GAME_FLOW_NETWORK_SESSION_TEST_OK (%d assertions)" % _assertions)
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

