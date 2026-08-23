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
	_check(server.register_damage_entity(1, &"cinder-long-range-bomber", 1, 1).accepted,
		"server registers one ship lifecycle")
	var active := server.publish_damage_respawn_snapshot(
		&"cinder-long-range-bomber", 1, 80.0, &"active", false, 0, [2], 4
	)
	_check(bool(active.get("accepted", false)), "server publishes active hull state")
	var client := Adapter.new()
	var applied := client.consume_damage_respawn_snapshot(active.get("packet", {}) as Dictionary)
	_check(bool(applied.get("accepted", false)), "client consumes presentation-only hull state")
	_check(int(client.get_presentation_cursor_audit().get("damage_count", 0)) == 1,
		"client retains one damage presentation cursor")
	var destroyed := server.publish_damage_respawn_snapshot(
		&"cinder-long-range-bomber", 1, 0.0, &"destroyed", true, 1, [2], 5
	)
	_check(bool(destroyed.get("accepted", false)), "server publishes destruction state")
	var destroyed_applied := client.consume_damage_respawn_snapshot(destroyed.get("packet", {}) as Dictionary)
	_check(bool(destroyed_applied.get("accepted", false)), "client consumes destruction presentation")
	_check(StringName((destroyed_applied.get("samples", []) as Array)[0].get("state", &"")) == &"destroyed",
		"client observes destroyed state without mutating health")
	var stale := (active.get("packet", {}) as Dictionary).duplicate(true)
	stale["revision"] = 1
	_check(not bool(client.consume_damage_respawn_snapshot(stale).get("accepted", false)),
		"stale lifecycle packet is rejected")
	server._on_peer_disconnected(2)
	_check(int(server.get_presentation_cursor_audit().get("damage_count", 0)) == 0,
		"disconnect clears damage presentation state")
	server.free()
	client.free()
	if _failures.is_empty():
		print("OK: GameFlow damage respawn network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
