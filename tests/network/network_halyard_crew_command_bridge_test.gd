extends SceneTree

const Bridge := preload("res://scripts/network/network_halyard_crew_command_bridge.gd")

class FakeHalyard extends RefCounted:
	var calls: Array = []
	var authority := FakeRoleAuthority.new()

	func get_crew_role_authority() -> Object:
		return authority

	func submit_crew_intent(source_peer_id: int, peer_id: int, avatar_id: StringName,
		action: StringName, payload: Dictionary, request_sequence: int) -> Dictionary:
		calls.append({"source_peer_id": source_peer_id, "peer_id": peer_id,
			"avatar_id": avatar_id, "action": action, "payload": payload,
			"request_sequence": request_sequence})
		return {"accepted": true, "status": &"intent_consumed"}


class FakeRoleAuthority extends RefCounted:
	func get_assignment(peer_id: int, avatar_id: StringName) -> Dictionary:
		if peer_id == 7 and avatar_id == &"avatar_7":
			return {"seat_id": &"pilot_seat", "vessel_id": &"ship_7", "seat_generation": 2}
		return {}


class FakeAdapter extends RefCounted:
	signal crew_command_result(result: Dictionary)


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var bridge := Bridge.new(1)
	var halyard := FakeHalyard.new()
	var receipt := {"accepted": true, "status": &"command_accepted", "receipt": {
		"peer_id": 7, "peer_generation": 3, "avatar_id": &"avatar_7", "seat_id": &"pilot_seat",
		"seat_generation": 2, "role": &"pilot", "action": &"flight_command",
		"ship_id": &"ship_7", "ship_generation": 2,
		"request_sequence": 4, "migration_generation": 1,
		"payload": {"thrust_x": 0.25, "thrust_y": -0.5},
	}}
	var dispatched := bridge.dispatch(1, receipt, halyard)
	_check(dispatched.accepted and halyard.calls.size() == 1, "server receipt reaches Halyard")
	_check(halyard.calls[0].source_peer_id == 1 and halyard.calls[0].peer_id == 7
		and halyard.calls[0].request_sequence == 4, "dispatch preserves authority identity")
	_check(bridge.dispatch(1, receipt, halyard).status == &"stale_receipt_sequence",
		"receipt replay is rejected")
	var adapter := FakeAdapter.new()
	_check(bridge.attach(adapter, halyard).accepted, "bridge attaches to adapter receipts")
	adapter.crew_command_result.emit(receipt.duplicate(true))
	_check(halyard.calls.size() == 1, "stale adapter receipt is not re-dispatched")
	_check(bridge.dispatch(2, receipt, halyard).status == &"unauthorized_source",
		"client source cannot dispatch")
	_check(bridge.reset_migration(1, 2).accepted and bridge.get_snapshot().tracked_stream_count == 0,
		"migration reset clears dispatch cursors")
	_check(bridge.dispatch(1, receipt, halyard).status == &"invalid_receipt_identity",
		"stale migration receipt is rejected")
	_check(bridge.release_peer(1, 7, 3).accepted, "disconnect cleanup is accepted")
	if _failures.is_empty():
		print("OK: Halyard crew command bridge (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
