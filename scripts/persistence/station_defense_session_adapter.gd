class_name StationDefenseSessionAdapter
extends RefCounted

## Safe history and explicit earned terminal handoff codec. Legacy history never
## implies entitlement. No active encounter is restored.
## Runtime opponents, sources, health, collisions, leases and reward grants are
## intentionally absent from this payload.

const SCHEMA_VERSION := 2
const ACTIVITY_ID: StringName = &"shipyard_perimeter_defense"
const SAFE_STATES: Array[StringName] = [&"idle", &"completed", &"failed"]

var _restored_generation := -1


func capture(source: Dictionary) -> Dictionary:
	var history := source.get("history", {}) as Dictionary
	var validated := _validate_history(history)
	if not bool(validated.get("accepted", false)):
		return {"schema_version": SCHEMA_VERSION, "history": _idle_history(), "completion": {}}
	return {
		"schema_version": SCHEMA_VERSION,
		"history": (validated.get("history", {}) as Dictionary).duplicate(true),
		"completion": (source.get("completion", {}) as Dictionary).duplicate(true),
	}.duplicate(true)


func restore(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return _result(false, &"malformed_payload")
	var record := payload as Dictionary
	if not (record.get("schema_version") is int or record.get("schema_version") is float) or float(record.schema_version) != floor(float(record.schema_version)) or int(record.schema_version) not in [1, SCHEMA_VERSION]:
		return _result(false, &"unsupported_schema")
	if not record.get("history") is Dictionary:
		return _result(false, &"invalid_terminal_history")
	if int(record.schema_version) == SCHEMA_VERSION:
		for field in ["generation", "reward_handoff_generation"]:
			var cursor: Variant = record.history.get(field)
			if not (cursor is int or cursor is float) or not is_finite(float(cursor)) or float(cursor) != floor(float(cursor)) or float(cursor) > StationDefenseContract.MAX_SAFE_INTEGER:
				return _result(false, &"invalid_terminal_history")
	var validated := _validate_history(record.get("history", {}) as Dictionary)
	if not bool(validated.get("accepted", false)):
		return validated
	var history := validated.get("history", {}) as Dictionary
	var completion: Dictionary = {}
	if int(record.schema_version) == SCHEMA_VERSION:
		var checked := validate_completion(record.get("completion"), history)
		if not checked.accepted:
			return checked
		completion = checked.completion
	var generation := int(history.get("generation", -1))
	if generation <= _restored_generation:
		return _result(false, &"replay_generation")
	_restored_generation = generation
	return {
		"accepted": true,
		"reason": &"restored_terminal_history",
		"history": history.duplicate(true),
		"completion": completion.duplicate(true),
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


static func validate_completion(candidate: Variant, history: Dictionary) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"invalid_completion"}
	if candidate.is_empty():
		return {"accepted": true, "completion": {}}
	if candidate.size() != 4 or str(candidate.get("activity_id", "")) != str(ACTIVITY_ID) \
			or not (candidate.get("generation") is int or candidate.get("generation") is float) \
			or float(candidate.generation) != floor(float(candidate.generation)) \
			or int(candidate.generation) < 1 or int(candidate.generation) > StationDefenseContract.MAX_SAFE_INTEGER \
			or candidate.get("reward_requested") is not bool or candidate.get("reward_requested") != true or candidate.get("reward_granted") is not bool \
			or str(history.get("state_id", "")) != "completed" \
			or int(history.get("generation", -1)) != int(candidate.generation) \
			or (candidate.reward_granted and int(history.get("reward_handoff_generation", -1)) != int(candidate.generation)) \
			or (not candidate.reward_granted and int(history.get("reward_handoff_generation", -1)) >= int(candidate.generation)):
		return {"accepted": false, "reason": &"invalid_completion"}
	return {"accepted": true, "completion": candidate.duplicate(true)}


func validate_save(current: Dictionary, captured: Dictionary) -> Dictionary:
	if current.is_empty():
		return {"accepted": true}
	var reader := StationDefenseSessionAdapter.new()
	var restored := reader.restore(current)
	if not restored.accepted:
		return restored
	var existing := restored.history as Dictionary
	if int(existing.generation) > int(captured.history.generation):
		return _result(false, &"newer_session_retained")
	var prior := restored.completion as Dictionary
	var next := captured.get("completion", {}) as Dictionary
	if not prior.is_empty() and int(existing.generation) == int(captured.history.generation) \
			and (next.is_empty() or (prior.reward_granted and not next.reward_granted)):
		return _result(false, &"completion_acknowledgement_retained")
	return {"accepted": true}
