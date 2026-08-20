extends SceneTree

## Focused client-prediction boundary coverage. It exercises only detached
## snapshot validation and correction policy; no MultiplayerPeer, scene,
## renderer, physics, or network soak is started.

const Guard := preload("res://scripts/network/network_prediction_correction_guard.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wire_and_snapshot_validation()
	_test_correction_thresholds()
	_test_tick_and_generation_guards()
	_test_authority_audit()
	if _failures.is_empty():
		print("OK: network prediction correction guard (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_wire_and_snapshot_validation() -> void:
	var guard := Guard.new(99)
	_check(guard.register_entity(99, &"pilot_a", 3, 7).accepted, "server registers a generation-bearing predicted entity")
	var packet := Guard.create_snapshot(99, &"pilot_a", 3, 7, 20, 1, Vector3(1, 2, 3), Vector3(4, 0, -1))
	var prediction := _prediction(&"pilot_a", 3, Vector3(1, 2, 3), Vector3(4, 0, -1))
	var accepted := guard.accept_snapshot(99, 7, 20, prediction, packet)
	_check(accepted.accepted and accepted.status == &"within_threshold", "matching server snapshot is accepted without correction")
	var detached := accepted.authoritative_state as Dictionary
	(detached.position as Array)[0] = 999.0
	_check(float((guard.get_last_result().authoritative_state.position as Array)[0]) == 1.0, "correction results are detached from caller mutation")
	var malformed := packet.duplicate(true)
	malformed.position = [NAN, 0.0, 0.0]
	_check(
		guard.accept_snapshot(99, 7, 21, prediction, malformed).status == &"invalid_snapshot",
		"non-finite server position fails closed"
	)
	var extra := packet.duplicate(true)
	extra.debug = true
	_check(
		guard.accept_snapshot(99, 7, 21, prediction, extra).status == &"invalid_snapshot_schema",
		"unknown server snapshot fields fail closed"
	)


func _test_correction_thresholds() -> void:
	var guard := Guard.new(1, 6, 2, 0.25, 1.0, 4.0, 32.0)
	guard.register_entity(1, &"pilot_a", 1, 7)
	var prediction := _prediction(&"pilot_a", 1, Vector3.ZERO, Vector3.ZERO)
	var mild := Guard.create_snapshot(1, &"pilot_a", 1, 7, 10, 1, Vector3(0.1, 0, 0), Vector3(0.5, 0, 0))
	var mild_result := guard.accept_snapshot(1, 7, 10, prediction, mild)
	_check(mild_result.accepted and mild_result.status == &"within_threshold", "sub-threshold drift does not request a correction")
	var visible := Guard.create_snapshot(1, &"pilot_a", 1, 7, 11, 2, Vector3(0.5, 0, 0), Vector3(2, 0, 0))
	var visible_result := guard.accept_snapshot(1, 7, 11, prediction, visible)
	_check(visible_result.accepted and visible_result.status == &"correction_required", "bounded drift requests an authoritative correction")
	_check(
		float(visible_result.position_error_meters) > 0.25
		and (visible_result.position_delta as Array)[0] == 0.5
		and not bool(visible_result.client_can_mutate_state),
		"correction reports the authoritative delta without granting client mutation"
	)
	var excessive := Guard.create_snapshot(1, &"pilot_a", 1, 7, 12, 3, Vector3(8, 0, 0), Vector3.ZERO)
	_check(
		guard.accept_snapshot(1, 7, 12, prediction, excessive).status == &"position_correction_exceeds_hard_limit",
		"implausibly large position correction is rejected rather than teleported locally"
	)


func _test_tick_and_generation_guards() -> void:
	var guard := Guard.new(1, 3, 1)
	guard.register_entity(1, &"pilot_b", 5, 8)
	var prediction := _prediction(&"pilot_b", 5, Vector3.ZERO, Vector3.ZERO)
	var first := Guard.create_snapshot(1, &"pilot_b", 5, 8, 30, 10, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(1, 8, 30, prediction, first).accepted, "snapshot at the client tick is accepted")
	var old := Guard.create_snapshot(1, &"pilot_b", 5, 8, 26, 11, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(1, 8, 30, prediction, old).status == &"snapshot_tick_too_old", "old snapshot outside the tick window is rejected")
	var future := Guard.create_snapshot(1, &"pilot_b", 5, 8, 32, 12, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(1, 8, 30, prediction, future).status == &"snapshot_tick_too_far_ahead", "future snapshot outside the tick window is rejected")
	var duplicate := Guard.create_snapshot(1, &"pilot_b", 5, 8, 30, 13, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(1, 8, 30, prediction, duplicate).status == &"stale_snapshot_tick", "duplicate server tick cannot replay a correction")
	var stale_generation := Guard.create_snapshot(1, &"pilot_b", 4, 8, 31, 14, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(1, 8, 31, prediction, stale_generation).status == &"stale_entity_generation", "late snapshot from an old entity generation is rejected")
	var wrong_owner := Guard.create_snapshot(1, &"pilot_b", 5, 9, 31, 15, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(1, 8, 31, prediction, wrong_owner).status == &"owner_mismatch", "snapshot cannot silently change entity ownership")


func _test_authority_audit() -> void:
	var guard := Guard.new(99)
	_check(guard.register_entity(7, &"pilot_c", 1, 4).status == &"unauthorized_source", "client cannot register prediction authority")
	guard.register_entity(99, &"pilot_c", 1, 4)
	var packet := Guard.create_snapshot(99, &"pilot_c", 1, 4, 1, 1, Vector3.ZERO, Vector3.ZERO)
	var prediction := _prediction(&"pilot_c", 1, Vector3.ZERO, Vector3.ZERO)
	_check(guard.accept_snapshot(7, 4, 1, prediction, packet).status == &"unauthorized_source", "client cannot submit an authoritative snapshot")
	var audit := guard.audit()
	_check(
		bool(audit.server_owns_snapshot_validation)
		and bool(audit.server_owns_correction_source)
		and bool(audit.client_prediction_is_presentation_only)
		and not bool(audit.client_can_mutate_state),
		"audit freezes server correction ownership and presentation-only prediction"
	)


func _prediction(entity_id: StringName, generation: int, position: Vector3, velocity: Vector3) -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_generation": generation,
		"position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
	}.duplicate(true)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
