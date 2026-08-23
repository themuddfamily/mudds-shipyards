extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	_check(server.register_landing_entity(1, &"cinder-long-range-bomber", 1).accepted,
		"server registers one landing lifecycle")
	var docked := server.publish_landing_snapshot(
		&"cinder-long-range-bomber", 1, Vector3(4.0, 2.0, -8.0), &"docked", [2], 7
	)
	_check(bool(docked.get("accepted", false)), "server publishes docked state")
	var client := Adapter.new()
	var applied := client.consume_landing_snapshot(docked.get("packet", {}) as Dictionary)
	_check(bool(applied.get("accepted", false)), "client consumes presentation-only landing state")
	_check(int(client.get_presentation_cursor_audit().get("landing_count", 0)) == 1,
		"client retains one landing presentation cursor")
	var flying := server.publish_landing_snapshot(
		&"cinder-long-range-bomber", 1, Vector3(9.0, 4.0, -2.0), &"flying", [2], 8
	)
	_check(bool(flying.get("accepted", false)), "server publishes released state")
	_check(bool(client.consume_landing_snapshot(flying.get("packet", {}) as Dictionary).get("accepted", false)),
		"client consumes ordered release transition")
	var stale := (docked.get("packet", {}) as Dictionary).duplicate(true)
	stale["revision"] = 1
	_check(not bool(client.consume_landing_snapshot(stale).get("accepted", false)),
		"stale landing transition is rejected")
	server.reset_snapshot_jitter(2)
	_check(int(client.get_presentation_cursor_audit().get("landing_count", 0)) == 1,
		"server migration reset does not mutate client state")
	server._on_peer_disconnected(2)
	_check(int(server.get_presentation_cursor_audit().get("landing_count", 0)) == 0,
		"disconnect clears server landing presentation state")
	server.free()
	client.free()
	if _failures.is_empty():
		print("OK: GameFlow landing network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
