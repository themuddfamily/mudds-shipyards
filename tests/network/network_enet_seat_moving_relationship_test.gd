extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	adapter._is_server = true
	adapter._configured = true
	adapter._peer_generations[2] = 1
	_check(adapter.register_owned_ship(&"ship_1", 3, 2).accepted, "server registers the owned ship")
	_check(adapter.register_crew_seat(&"seat_1", &"ship_1", &"passenger", &"", 7).accepted,
		"server registers the generation-fenced seat")
	var claimed: Dictionary = adapter.claim_crew_seat(2, &"crew_7", &"seat_1", &"passenger", 1)
	_check(bool(claimed.get("accepted", false)), "accepted seat claim establishes relationship")
	var relationship: Dictionary = adapter.get_crew_moving_interior_relationship(2, &"crew_7")
	_check(int(relationship.get("entity_generation", 0)) == 7, "relationship carries seat generation")
	_check(StringName(relationship.get("entity_id", &"")) == &"crew_7", "relationship carries avatar identity")
	_check(int(relationship.get("event_sequence", 0)) == 1, "relationship carries claim sequence")
	var released: Dictionary = adapter.release_crew_seat(2, &"crew_7", &"seat_1", 2, 7)
	_check(bool(released.get("accepted", false)), "accepted release clears the seat")
	_check(adapter.get_crew_moving_interior_relationship(2, &"crew_7").is_empty(),
		"release clears the relationship before reuse")
	adapter.free()
	if _failures.is_empty():
		print("OK: ENet seat moving relationship (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
