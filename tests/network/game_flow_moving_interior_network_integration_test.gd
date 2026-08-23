extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
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
	var relationship := Relationship.create(4, &"pilot_cinder", 1, &"frame_cinder", 1, Transform3D.IDENTITY)
	var published := server.publish_moving_interior_snapshot(relationship.get_snapshot(), [2], 4)
	_check(bool(published.get("accepted", false)), "server publishes frame-local relationship")
	var client := Adapter.new()
	var applied := client.consume_moving_interior_snapshot(published.get("packet", {}) as Dictionary)
	_check(bool(applied.get("accepted", false)), "client consumes presentation relationship")
	_check(int(client.get_presentation_cursor_audit().get("moving_interior_count", 0)) == 1,
		"client retains one moving-interior presentation cursor")
	var stale := (published.get("packet", {}) as Dictionary).duplicate(true)
	stale["migration_generation"] = 0
	_check(not bool(client.consume_moving_interior_snapshot(stale).get("accepted", false)),
		"stale migration relationship is rejected")
	var released := server.publish_moving_interior_release(&"pilot_cinder", 1, [2])
	_check(bool(released.get("accepted", false)), "server publishes relationship release")
	client._broadcast_moving_interior_release(released.get("packet", {}) as Dictionary)
	_check(int(client.get_presentation_cursor_audit().get("moving_interior_count", 0)) == 0,
		"release clears client relationship presentation")
	server._on_peer_disconnected(2)
	server.free()
	client.free()
	if _failures.is_empty():
		print("OK: GameFlow moving interior network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
