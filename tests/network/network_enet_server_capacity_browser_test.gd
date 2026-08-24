extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	_check(adapter.host(29125, 2).accepted, "server starts for browser capacity publication")
	var receipts: Array[Dictionary] = []
	adapter.server_browser_result.connect(func(result: Dictionary) -> void:
		receipts.append(result.duplicate(true))
	)
	var entry := {"session_id": &"hosted_run", "host_peer_id": 1, "title": "Hosted Run",
		"region_id": &"local", "ping_ms": -1, "player_count": 0, "max_players": 2}
	_check(adapter.publish_server_directory(4, 10, [entry]).accepted, "hosted listing publishes")
	var published_sequence := int(receipts.back().snapshot_sequence)
	var initial := adapter.query_server_directory()
	_check(initial.size() == 1 and initial[0].available_slots == 2 and not initial[0].is_full,
		"browser listing exposes initial capacity")
	adapter._peer_generations[7] = 3
	adapter._refresh_hosted_directory()
	var occupied := adapter.query_server_directory()
	_check(occupied[0].player_count == 1 and occupied[0].available_slots == 1,
		"admission refreshes hosted listing occupancy")
	_check(receipts.back().directory_generation == 4 and receipts.back().server_tick == 10
		and int(receipts.back().snapshot_sequence) > published_sequence,
		"capacity-only refresh retains the authoritative cursor and advances its local receipt sequence")
	var stale := adapter.publish_server_directory(3, 11, [entry])
	_check(stale.status == &"stale_directory_generation", "stale browser generation is rejected")
	adapter._peer_generations.erase(7)
	adapter._refresh_hosted_directory()
	_check(adapter.query_server_directory()[0].available_slots == 2, "disconnect refreshes capacity")
	adapter.shutdown(&"test_complete")
	if _failures.is_empty():
		print("OK: ENet server capacity browser (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
