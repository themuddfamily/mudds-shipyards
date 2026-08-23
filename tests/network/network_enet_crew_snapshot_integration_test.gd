extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	var hosted := adapter.host(29123, 1)
	_check(hosted.accepted, "server session is configured for crew publication")
	var published := adapter.publish_crew_snapshot()
	_check(published.accepted and published.status == &"crew_snapshot_published",
		"server publishes detached crew snapshot through transport seam")
	_check(int(published.get("entry_count", -1)) == 0 and adapter.get_crew_replica_snapshot().is_empty(),
		"server publication does not mutate client presentation state")
	adapter.shutdown(&"test_complete")
	_check(adapter.get_crew_replica_snapshot().is_empty(), "shutdown clears crew replica state")
	var roles := {
		"7:pilot": {"peer_id": 7, "ship_id": &"ship_7"},
		"8:gunner": {"peer_id": 8, "ship_id": &"ship_8"},
		"9:engineer": {"peer_id": 9, "ship_id": &"ship_7"},
	}
	var receipts: Array = [
		{"receipt": {"peer_id": 8, "ship_id": &"ship_8"}},
		{"receipt": {"peer_id": 9, "ship_id": &"ship_7"}},
	]
	var filtered := adapter._crew_snapshot_for_peer(7, {"roles": roles}, receipts)
	_check(filtered.roles.roles.size() == 2 and filtered.receipts.size() == 1
		and filtered.receipts[0].receipt.ship_id == &"ship_7",
		"publication filter keeps only recipient ship state")
	if _failures.is_empty():
		print("OK: ENet crew snapshot integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
