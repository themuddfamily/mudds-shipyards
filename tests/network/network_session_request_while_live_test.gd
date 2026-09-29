extends SceneTree

## A host or join request made while a session is already running is refused
## by the adapter (`already_started`). It must be refused before GameFlow
## rewrites its own session role: the running session is still the one that
## decides whether this game is the authority. Flipping `_network_session_mode`
## on a refused request turned a host who pressed "Manual Join" into a "client"
## that stopped running boarding, pilot and projectile authority for everyone,
## and a connected client who pressed "Host Session" into a "server".

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

## Only the session seam is under test; the production start-up is not.
class FlowProbe:
	extends GameFlowType

	func _ready() -> void:
		pass

var _assertions := 0
var _failures := PackedStringArray()
var _branches: Array[Node] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _host_keeps_its_role()
	await _client_keeps_its_role()
	for branch in _branches:
		if is_instance_valid(branch):
			branch.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_SESSION_REQUEST_WHILE_LIVE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _host_keeps_its_role() -> void:
	var flow := _make_flow("HostingFlow")
	var port := _reserve_loopback_port()
	_check(bool(flow.host_network_session(port, 2).get("accepted", false)), "GameFlow hosts")
	var joined := flow.join_network_session("127.0.0.1", port + 1)
	_check(not bool(joined.get("accepted", false)), "a join while hosting is refused")
	_check(flow._network_session_mode == &"server",
		"a refused join leaves the host's role as server (got %s)" % flow._network_session_mode)
	flow._handle_server_browser_intent({"action": &"manual_join", "address": "127.0.0.1", "port": port + 1})
	_check(flow._network_session_mode == &"server",
		"a refused manual join leaves the host's role as server (got %s)" % flow._network_session_mode)
	_check(flow.get_network_session().is_server(), "the host is still hosting")
	flow.shutdown_network_session(&"test_complete")


func _client_keeps_its_role() -> void:
	var host := _make_adapter("BareHost")
	var port := _reserve_loopback_port()
	_check(bool(host.host(port, 2).get("accepted", false)), "a bare host listens")
	var flow := _make_flow("JoiningFlow")
	_check(bool(flow.join_network_session("127.0.0.1", port).get("accepted", false)), "GameFlow joins")
	var session := flow.get_network_session()
	await _wait_until(func() -> bool: return not session.get_server_offer().is_empty(), 6.0)
	var hosted := flow.host_network_session(_reserve_loopback_port(), 2)
	_check(not bool(hosted.get("accepted", false)), "a host request while joined is refused")
	_check(flow._network_session_mode == &"client",
		"a refused host request leaves the client's role as client (got %s)" % flow._network_session_mode)
	flow._handle_server_browser_intent({"action": &"host_session", "port": _reserve_loopback_port(), "max_clients": 2})
	_check(flow._network_session_mode == &"client",
		"a refused browser host request leaves the role as client (got %s)" % flow._network_session_mode)
	flow.shutdown_network_session(&"test_complete")
	host.shutdown(&"test_complete")


func _make_branch(branch_name: String) -> Node:
	var branch := SubViewport.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	_branches.append(branch)
	return branch


## The flow is its own multiplayer root, as Main is in production, so its
## adapter answers at `NetworkSession` like the bare peer's does.
func _make_flow(branch_name: String) -> GameFlowType:
	var flow := FlowProbe.new()
	flow.name = branch_name
	root.add_child(flow)
	set_multiplayer(SceneMultiplayer.new(), flow.get_path())
	_branches.append(flow)
	return flow


func _make_adapter(branch_name: String) -> Adapter:
	var adapter := Adapter.new()
	adapter.name = GameFlowType.NETWORK_SESSION_NODE_NAME
	_make_branch(branch_name).add_child(adapter)
	return adapter


func _reserve_loopback_port() -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port")
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append("FAIL: " + description)
