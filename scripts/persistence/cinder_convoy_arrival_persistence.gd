class_name CinderConvoyArrivalPersistence
extends RefCounted

## Namespaced atomic-store bridge for one safely arrived Emberline escort.
## It stores no entity transform, movement, sample, combat, or live activity
## generation. The reward receipt is an observation of the accepted handoff and
## is deliberately non-granting and non-replayable.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "cinder_convoy_safe_arrival_receipt"
const ACTIVITY_ID := "cinder_reach_emberline_convoy"
const CONVOY_ID := "emberline_supply_tender"
const REWARD_ID := "return_convoy_credit_to_shipyard"
const CONTENT_CLASS := "NEW"
const EVIDENCE_STATUS := "modern_interpretation"

var _store: RefCounted
var _slot_id: StringName = &""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"convoy_arrival_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"convoy_arrival_persistence_configured")


func save(host_snapshot: Dictionary, reward_result: Dictionary, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"convoy_arrival_save_invalid")
	var captured := capture(host_snapshot, reward_result)
	if not bool(captured.get("accepted", false)):
		return captured
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.call(&"get_snapshot") as Dictionary
	payload[String(_slot_id)] = captured.record
	var committed := _store.call(
		&"commit", payload, int(_store.call(&"get_generation")), commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"convoy_arrival_saved" if bool(committed.get("accepted", false)) \
		else &"store_rejected"
	)
	return committed


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"convoy_arrival_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var key := String(_slot_id)
	if not payload.has(key):
		return _result(false, &"convoy_arrival_not_found")
	var validation := validate_record(payload.get(key))
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason": &"convoy_arrival_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"arrival": (payload[key] as Dictionary).arrival.duplicate(true),
	}.duplicate(true)


func capture(host_snapshot: Dictionary, reward_result: Dictionary) -> Dictionary:
	var activity := host_snapshot.get("activity", {}) as Dictionary
	var request := reward_result.get("reward_request", {}) as Dictionary
	var callback := reward_result.get("callback", {}) as Dictionary
	var generation := int(activity.get("generation", 0))
	var leg_count := int(activity.get("leg_count", 0))
	var elapsed := float(activity.get("elapsed_seconds", -1.0))
	if StringName(host_snapshot.get("content_class", &"")) != CONTENT_CLASS \
			or StringName(host_snapshot.get("evidence_status", &"")) != EVIDENCE_STATUS \
			or StringName(activity.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(activity.get("convoy_id", &"")) != CONVOY_ID \
			or generation < 1 \
			or int(activity.get("state", -1)) != ConvoyEscortActivity.State.COMPLETED \
			or StringName(activity.get("state_id", &"")) != &"completed" \
			or int(activity.get("terminal_result", -1)) \
				!= ConvoyEscortActivity.TerminalResult.SAFELY_ARRIVED \
			or StringName(activity.get("terminal_result_id", &"")) != &"safely_arrived" \
			or StringName(activity.get("terminal_reason", &"")) != &"safely_arrived" \
			or leg_count < 2 or int(activity.get("completed_leg_count", -1)) != leg_count \
			or not is_finite(elapsed) or elapsed <= 0.0 or elapsed > 86_400.0 \
			or not bool(reward_result.get("accepted", false)) \
			or StringName(reward_result.get("reason", &"")) != &"reward_request_committed" \
			or not bool(callback.get("accepted", false)) \
			or StringName(request.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(request.get("reward_id", &"")) != REWARD_ID \
			or int(request.get("activity_generation", -1)) != generation \
			or bool(request.get("granted", true)):
		return _result(false, &"convoy_arrival_receipts_not_committed")
	var arrival := {
		"activity_id": ACTIVITY_ID,
		"convoy_id": CONVOY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"leg_count": leg_count,
		"elapsed_seconds": elapsed,
		"terminal_result": "safely_arrived",
		"reward_receipt": {
			"activity_id": ACTIVITY_ID,
			"reward_id": REWARD_ID,
			"granted": false,
			"replay_allowed": false,
		},
	}.duplicate(true)
	var record := {
		"schema_version": SCHEMA_VERSION,
		"payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id),
		"arrival": arrival,
	}.duplicate(true)
	var validation := validate_record(record)
	return {
		"accepted": bool(validation.get("accepted", false)),
		"reason": &"convoy_arrival_captured" \
			if bool(validation.get("accepted", false)) \
			else validation.get("reason", &"convoy_arrival_payload_corrupt"),
		"record": record if bool(validation.get("accepted", false)) else {},
	}.duplicate(true)


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"convoy_arrival_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 4 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("arrival") is Dictionary:
		return _result(false, &"convoy_arrival_payload_corrupt")
	var arrival := record.arrival as Dictionary
	var elapsed: Variant = arrival.get("elapsed_seconds", null)
	var receipt := arrival.get("reward_receipt", {}) as Dictionary
	if arrival.size() != 8 or str(arrival.get("activity_id", "")) != ACTIVITY_ID \
			or str(arrival.get("convoy_id", "")) != CONVOY_ID \
			or str(arrival.get("content_class", "")) != CONTENT_CLASS \
			or str(arrival.get("evidence_status", "")) != EVIDENCE_STATUS \
			or not _integral(arrival.get("leg_count")) \
			or int(arrival.get("leg_count", 0)) < 2 \
			or not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) \
			or float(elapsed) <= 0.0 or float(elapsed) > 86_400.0 \
			or str(arrival.get("terminal_result", "")) != "safely_arrived" \
			or receipt.size() != 4 or str(receipt.get("activity_id", "")) != ACTIVITY_ID \
			or str(receipt.get("reward_id", "")) != REWARD_ID \
			or receipt.get("granted") is not bool or bool(receipt.get("granted", true)) \
			or receipt.get("replay_allowed") is not bool \
			or bool(receipt.get("replay_allowed", true)):
		return _result(false, &"convoy_arrival_payload_corrupt")
	return _result(true, &"convoy_arrival_payload_valid")


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
