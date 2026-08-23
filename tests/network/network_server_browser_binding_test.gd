extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	var entries := [_entry("slow", 180), _entry("fast", 20)]
	_check(adapter.apply_server_directory_snapshot(4, 100, entries).accepted, "client binding accepts hosted discovery snapshot")
	var listing: Array = adapter.query_server_directory()
	_check(listing.size() == 2 and String((listing[0] as Dictionary).session_id) == "fast",
		"binding exposes detached sorted discovery listings")
	var intent := adapter.create_join_intent(&"fast")
	_check(intent.accepted and intent.intent.session_id == &"fast"
		and int(intent.intent.directory_generation) == 4, "join remains a caller-owned detached intent")
	_check(adapter.expire_server_directory(131).accepted and adapter.query_server_directory().is_empty(),
		"binding applies caller-driven TTL expiry")
	_check(not adapter.apply_server_directory_snapshot(3, 132, entries).accepted,
		"binding rejects replayed directory generation")
	_check(adapter.apply_server_directory_snapshot(5, 132, [_entry("fresh", 30)]).accepted, "new directory generation replaces stale listings")
	_check(adapter.detach_server_directory().accepted and adapter.query_server_directory().is_empty(),
		"binding detaches discovery state for migration/reconnect")
	if _failures.is_empty():
		print("OK: server browser binding (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _entry(session_id: String, ping_ms: int) -> Dictionary:
	return {
		"session_id": session_id,
		"host_peer_id": 2,
		"title": "Hosted probe",
		"region_id": "lan",
		"ping_ms": ping_ms,
		"player_count": 1,
		"max_players": 4,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
