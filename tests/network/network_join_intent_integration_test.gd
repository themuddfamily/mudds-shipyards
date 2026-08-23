extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.apply_server_directory_snapshot(1, 10, [_entry("alpha")]).accepted, "client consumes a validated discovery generation")
	var created := adapter.create_join_intent(&"alpha")
	var intent: Dictionary = created.get("intent", {}) as Dictionary
	_check(created.accepted and int(intent.intent_sequence) == 1, "browser binding issues a sequenced join intent")
	var routed := adapter.consume_join_intent(intent, "")
	_check(not routed.accepted and routed.status == &"invalid_address", "accepted intent routes through the normal join path")
	_check(adapter.consume_join_intent(intent, "").status == &"stale_join_intent", "replayed intent is rejected")
	_check(adapter.apply_server_directory_snapshot(2, 11, [_entry("alpha")]).accepted, "new directory generation replaces the old listing")
	var stale_generation := {"session_id": &"alpha", "directory_generation": 1, "intent_sequence": 3}
	_check(adapter.consume_join_intent(stale_generation, "").status == &"stale_join_intent_generation",
		"intent from an older directory generation is fenced")
	var fresh := adapter.create_join_intent(&"alpha")
	_check(fresh.accepted and int((fresh.intent as Dictionary).intent_sequence) == 2,
		"fresh generation issues the next local intent sequence")
	_check(adapter.reset_snapshot_jitter(3).accepted
		and adapter.consume_join_intent(intent, "").status == &"session_not_found",
		"migration reset clears consumed discovery intents and listings")
	if _failures.is_empty():
		print("OK: join intent integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _entry(session_id: String) -> Dictionary:
	return {
		"session_id": session_id,
		"host_peer_id": 2,
		"title": "Join probe",
		"region_id": "lan",
		"ping_ms": 20,
		"player_count": 1,
		"max_players": 4,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
