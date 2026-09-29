extends SceneTree

## A session's role must end with the session. `_network_session_mode` is what
## every authority gate reads: a "client" never resolves its own shots or
## payload releases, never completes a landing ("Landing controlled by host"),
## and is refused every planet visit ("SOLO EXPLORATION ONLY"). It used to
## outlive the session, so a player whose host dropped out -- or whose join
## was refused on the spot -- kept all of those refusals in what is now a solo
## game until they quit. RETRY must still reopen the session it had.

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
	await _a_client_whose_host_drops_is_solo_again()
	await _a_refused_join_leaves_no_role()
	await _a_host_that_closes_its_session_is_solo_again()
	for branch in _branches:
		if is_instance_valid(branch):
			branch.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_SESSION_ROLE_AFTER_DROP_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _a_client_whose_host_drops_is_solo_again() -> void:
	var host := _make_adapter("DroppingHost")
	var port := _reserve_loopback_port()
	_check(bool(host.host(port, 2).get("accepted", false)), "a bare host listens")
	var flow := _make_flow("DroppedClientFlow")
	_check(bool(flow.join_network_session("127.0.0.1", port).get("accepted", false)), "GameFlow joins")
	var session := flow.get_network_session()
	_check(await _wait_until(func() -> bool: return not session.get_server_offer().is_empty(), 6.0),
		"the client is admitted")
	_check(flow._consume_bomber_payload_release().get("reason") == &"client_projectile_authority_forbidden",
		"while joined, the client may not release a payload itself")
	# The host process goes away.
	host.shutdown(&"host_quit")
	_check(await _wait_until(func() -> bool: return not session.is_session_active(), 8.0),
		"the client notices its host is gone")
	_check(flow._network_session_mode == &"",
		"a dropped client holds no session role (got '%s')" % flow._network_session_mode)
	_check(flow._consume_bomber_payload_release().get("reason") != &"client_projectile_authority_forbidden",
		"after the drop, the player's own payload release is no longer refused as a client's")
	# RETRY reopens the session it had: a join, to the same host.
	_check(bool(host.host(port, 2).get("accepted", false)), "the host comes back on the same port")
	flow._on_hud_presentation_intent_requested(&"network", {"action": &"retry"})
	_check(flow._network_session_mode == &"client" and session.is_session_active() and not session.is_server(),
		"RETRY after a drop rejoins as a client (mode '%s')" % flow._network_session_mode)
	_check(await _wait_until(func() -> bool: return not session.get_server_offer().is_empty(), 6.0),
		"the retried join is admitted")
	flow.shutdown_network_session(&"test_complete")
	host.shutdown(&"test_complete")


func _a_refused_join_leaves_no_role() -> void:
	var flow := _make_flow("RefusedJoinFlow")
	var joined := flow.join_network_session("not a host name!", 7777)
	_check(not bool(joined.get("accepted", false)), "a join to an invalid address is refused on the spot")
	_check(flow._network_session_mode == &"",
		"a refused join leaves no client role behind (got '%s')" % flow._network_session_mode)
	flow._handle_server_browser_intent({"action": &"manual_join", "address": "not a host name!", "port": 7777})
	_check(flow._network_session_mode == &"",
		"a refused manual join leaves no client role behind (got '%s')" % flow._network_session_mode)


func _a_host_that_closes_its_session_is_solo_again() -> void:
	var flow := _make_flow("ClosingHostFlow")
	var port := _reserve_loopback_port()
	_check(bool(flow.host_network_session(port, 2).get("accepted", false)), "GameFlow hosts")
	_check(flow._network_session_mode == &"server", "the host plays the server role")
	flow.shutdown_network_session(&"ui_disconnect")
	_check(flow._network_session_mode == &"",
		"a closed host session holds no session role (got '%s')" % flow._network_session_mode)
	flow._on_hud_presentation_intent_requested(&"network", {"action": &"retry"})
	_check(flow._network_session_mode == &"server" and flow.get_network_session().is_server(),
		"RETRY after closing reopens the host session")
	flow.shutdown_network_session(&"test_complete")


func _make_branch(branch_name: String) -> Node:
	var branch := SubViewport.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	_branches.append(branch)
	return branch


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
