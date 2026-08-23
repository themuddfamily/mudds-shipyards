extends SceneTree

const GameFlow := preload("res://scripts/game/game_flow.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Projectile := preload("res://scripts/combat/bomber_payload_projectile.gd")
const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	var flow := GameFlow.new()
	var bomber := Bomber.new()
	flow.network_session = server
	flow._bomber_payload_ship = bomber
	flow._bomber_payload_generation = 3
	flow._bomber_payload_server_tick = 12
	var projectile := Projectile.new(
		1, Vector3(0.0, -9.81, 0.0), 30.0, 500.0, 100_000.0,
	) as BomberPayloadProjectile
	_check(projectile.begin_generation(3).accepted, "projectile generation starts")
	var release := {
		"schema_version": 1,
		"record_id": "bomber_payload_release_000001",
		"release_sequence": 1,
		"generation": 3,
		"actor_id": &"player_pilot",
		"request_sequence": 1,
		"payload_id": &"cinder_payload_1",
		"weapon_id": &"bomber_payload_release",
		"presentation_id": &"bomber_payload",
		"audio_id": &"bomber_payload",
		"release_position": Vector3.ZERO,
		"release_velocity": Vector3(0.0, 0.0, -220.0),
		"ammunition_remaining": 3,
		"cooldown_remaining": 1.0,
	}
	_check(projectile.consume_release_record(1, release).accepted, "release record is admitted")
	flow._bomber_payload_projectiles.append(projectile)
	var published: Dictionary = flow._publish_bomber_payload_network(projectile, false)
	_check(bool(published.get("accepted", false)), "GameFlow publishes server projectile state")
	var packet := published.get("packet", {}) as Dictionary
	_check(StringName((packet.get("projectile", {}) as Dictionary).get("source_entity_id", &"")) == GameFlow.CINDER_BOMBER_SHIP_ID,
		"published state retains bomber source identity")
	var client := Adapter.new()
	var applied: Dictionary = client._apply_projectile_replica_snapshot(packet)
	_check(bool(applied.get("accepted", false)), "client consumes presentation-only projectile state")
	_check(int(client.get_presentation_cursor_audit().get("projectile_count", 0)) == 1,
		"client creates one projectile presentation cursor")
	var terminal_packet := packet.duplicate(true)
	terminal_packet["terminal"] = true
	terminal_packet["projectile"] = (packet.get("projectile", {}) as Dictionary).duplicate(true)
	terminal_packet.projectile.state = &"terminal"
	var retired: Dictionary = client._apply_projectile_replica_snapshot(terminal_packet)
	_check(bool(retired.get("accepted", false)), "client accepts authoritative terminal")
	_check(int(client.get_presentation_cursor_audit().get("projectile_count", 0)) == 0,
		"terminal retires presentation without client damage authority")
	server.free()
	client.free()
	flow.free()
	bomber.free()
	if _failures.is_empty():
		print("OK: GameFlow bomber payload network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
