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
	_check(server.register_boarding_ship(&"cinder-long-range-bomber", 1, &"frame_cinder", 1).accepted,
		"server registers one ship boarding lifecycle")
	_check(server.register_boarding_seat(&"cinder-long-range-bomber_pilot", &"cinder-long-range-bomber", 1, &"pilot").accepted,
		"server registers pilot seat")
	var claimed := server.publish_boarding_snapshot(
		&"cinder-long-range-bomber", 1, &"cinder-long-range-bomber_pilot", 1, 1, true, [2], 10
	)
	_check(bool(claimed.get("accepted", false)), "server publishes pilot claim")
	var client := Adapter.new()
	var applied := client.consume_boarding_ownership_snapshot(claimed.get("packet", {}) as Dictionary)
	_check(bool(applied.get("accepted", false)), "client consumes presentation-only claim")
	_check(int(client.get_presentation_cursor_audit().get("boarding_count", 0)) == 1,
		"client retains one boarding presentation cursor")
	var released := server.publish_boarding_snapshot(
		&"cinder-long-range-bomber", 1, &"cinder-long-range-bomber_pilot", 1, 1, false, [2], 11
	)
	_check(bool(released.get("accepted", false)), "server publishes pilot release")
	_check(bool(client.consume_boarding_ownership_snapshot(released.get("packet", {}) as Dictionary).get("accepted", false)),
		"client consumes ordered release")
	var stale := (claimed.get("packet", {}) as Dictionary).duplicate(true)
	stale["revision"] = 1
	_check(not bool(client.consume_boarding_ownership_snapshot(stale).get("accepted", false)),
		"stale boarding transition is rejected")
	server.reset_snapshot_jitter(2)
	server._on_peer_disconnected(2)
	_check(int(server.get_presentation_cursor_audit().get("boarding_count", 0)) == 0,
		"disconnect clears boarding presentation state")
	server.free()
	client.free()
	if _failures.is_empty():
		print("OK: GameFlow boarding network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
