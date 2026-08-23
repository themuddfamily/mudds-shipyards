class_name CinderRaceBestPersistence
extends RefCounted

## Namespaced atomic-store bridge for the best completed Cinder race result.
## Live race state and transient generations never enter this record.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "cinder_race_best_result"
const ACTIVITY_ID := "cinder_reach_checkpoint_route"
const REWARD_ID := "return_race_record_to_shipyard"

var _store: RefCounted
var _slot_id: StringName = &""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"race_best_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"race_best_persistence_configured")


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"race_best_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"race_best_not_found")
	var validated := validate_record(payload.get(slot_key))
	if not bool(validated.get("accepted", false)):
		return validated
	return {
		"accepted": true,
		"reason": &"race_best_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"best_result": (payload[slot_key] as Dictionary).best_result.duplicate(true),
	}.duplicate(true)


func save(best_result: Dictionary, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"race_best_save_invalid")
	var record := _record(best_result)
	var validated := validate_record(record)
	if not bool(validated.get("accepted", false)):
		return validated
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.call(&"get_snapshot") as Dictionary
	payload[String(_slot_id)] = record
	var committed := _store.call(
		&"commit", payload, int(_store.call(&"get_generation")), commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"race_best_saved" if bool(committed.get("accepted", false)) else &"store_rejected"
	)
	return committed


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"race_best_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 4 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("best_result") is Dictionary:
		return _result(false, &"race_best_payload_corrupt")
	var best := record.best_result as Dictionary
	var time: Variant = best.get("time_seconds", null)
	var penalty: Variant = best.get("penalty_seconds", null)
	var receipt: Variant = best.get("reward_receipt", null)
	if best.size() != 4 or str(best.get("activity_id", "")) != ACTIVITY_ID \
			or not (time is float or time is int) or not is_finite(float(time)) \
			or float(time) <= 0.0 or float(time) > 86_400.0 \
			or not (penalty is float or penalty is int) or not is_finite(float(penalty)) \
			or float(penalty) < 0.0 or float(penalty) > float(time) \
			or not receipt is Dictionary:
		return _result(false, &"race_best_payload_corrupt")
	var reward := receipt as Dictionary
	if not reward.is_empty() and (
		reward.size() != 3 or str(reward.get("activity_id", "")) != ACTIVITY_ID \
		or str(reward.get("reward_id", "")) != REWARD_ID \
		or reward.get("replay_allowed") is not bool \
		or bool(reward.get("replay_allowed", true))
	):
		return _result(false, &"race_best_payload_corrupt")
	return _result(true, &"race_best_payload_valid")


func _record(best_result: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id),
		"best_result": best_result.duplicate(true),
	}.duplicate(true)


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _integral(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
