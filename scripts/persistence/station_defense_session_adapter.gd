class_name StationDefenseSessionAdapter
extends RefCounted

## Terminal-history-only codec used through NearbySectorActivityPersistenceBinding.
## Runtime opponents, sources, health, collisions, leases and reward grants are
## intentionally absent from this payload.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"shipyard_perimeter_defense"
const SAFE_STATES: Array[StringName] = [&"idle", &"completed", &"failed"]

var _restored_generation := -1


func capture(source: Dictionary) -> Dictionary:
	var history := source.get("history", {}) as Dictionary
	var validated := _validate_history(history)
	if not bool(validated.get("accepted", false)):
		return {"schema_version": SCHEMA_VERSION, "history": _idle_history()}
	return {
		"schema_version": SCHEMA_VERSION,
		"history": (validated.get("history", {}) as Dictionary).duplicate(true),
	}.duplicate(true)


func restore(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return _result(false, &"malformed_payload")
	var record := payload as Dictionary
	if int(record.get("schema_version", -1)) != SCHEMA_VERSION:
		return _result(false, &"unsupported_schema")
	var validated := _validate_history(record.get("history", {}) as Dictionary)
	if not bool(validated.get("accepted", false)):
		return validated
	var history := validated.get("history", {}) as Dictionary
	var generation := int(history.get("generation", -1))
	if generation <= _restored_generation:
		return _result(false, &"replay_generation")
	_restored_generation = generation
	return {
		"accepted": true,
		"reason": &"restored_terminal_history",
		"history": history.duplicate(true),
	}.duplicate(true)


func _validate_history(history: Dictionary) -> Dictionary:
	var activity_id := StringName(history.get("activity_id", &""))
	var state_id := StringName(history.get("state_id", &""))
	var generation := int(history.get("generation", -1))
	var reward_generation := int(history.get("reward_handoff_generation", -1))
	if (
		activity_id != ACTIVITY_ID
		or not SAFE_STATES.has(state_id)
		or generation < 0
		or reward_generation < 0
		or reward_generation > generation
		or bool(history.get("reward_replayable", true))
	):
		return _result(false, &"invalid_terminal_history")
	var failure_reason := StringName(history.get("failure_reason", &""))
	if state_id == &"failed" and failure_reason.is_empty():
		return _result(false, &"invalid_failure_history")
	if state_id != &"failed":
		failure_reason = &""
	var safe := {
		"activity_id": ACTIVITY_ID,
		"state_id": state_id,
		"generation": generation,
		"failure_reason": failure_reason,
		"reward_handoff_generation": reward_generation,
		"reward_replayable": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"validated", "history": safe}


func _idle_history() -> Dictionary:
	return {
		"activity_id": ACTIVITY_ID,
		"state_id": &"idle",
		"generation": 0,
		"failure_reason": &"",
		"reward_handoff_generation": 0,
		"reward_replayable": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
