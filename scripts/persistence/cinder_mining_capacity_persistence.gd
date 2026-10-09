class_name CinderMiningCapacityPersistence
extends RefCounted

## One atomic-store record owns the extraction checkpoint and capacity receipt.
## Capacity acknowledgement and the paid session publish in the same commit.

const SCHEMA_VERSION := 2
const PAYLOAD_KIND := "cinder_mining_capacity_receipt"
const ACTIVITY_ID := "cinder_platform_mining_run"
const REWARD_ID := "cinder_raw_ore_sample"
const CONTENT_CLASS := "NEW"
const EVIDENCE_STATUS := "modern_interpretation"

var _store: RefCounted
var _slot_id: StringName = &""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"mining_capacity_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"mining_capacity_persistence_configured")


func save(snapshot: Dictionary, reward_result: Dictionary, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"mining_capacity_save_invalid")
	var captured := capture(snapshot, reward_result)
	if not bool(captured.get("accepted", false)):
		return captured
	return _save_record(captured.record as Dictionary, commit_id)


func save_session(snapshot: Dictionary, capacity_paid: bool, capacity: Dictionary, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"mining_capacity_save_invalid")
	var record := {"schema_version": SCHEMA_VERSION, "payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id), "capacity": capacity.duplicate(true),
		"session": _session(snapshot, capacity_paid)}
	var validation := validate_record(record)
	if not bool(validation.get("accepted", false)):
		return validation
	return _save_record(record, commit_id)


func _save_record(record: Dictionary, commit_id: String) -> Dictionary:
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.call(&"get_snapshot") as Dictionary
	# Compare the JSON wire representation: decoded numbers are floats.
	var wire_record := JSON.parse_string(JSON.stringify(record)) as Dictionary
	var key := String(_slot_id)
	if payload.has(key):
		var validation := validate_record(payload[key])
		if not bool(validation.get("accepted", false)):
			return validation
		if payload[key] == wire_record:
			return _result(true, &"mining_session_already_saved")
		var previous := (payload[key] as Dictionary).get("session", {}) as Dictionary
		if not previous.is_empty() and _session_regresses(previous, wire_record.session as Dictionary):
			return _result(false, &"mining_session_stale")
	payload[key] = wire_record
	var committed := _store.call(&"commit", payload, int(_store.call(&"get_generation")), commit_id) as Dictionary
	# A platform sync adapter may reject after publication. Re-read the actual
	# authority and reconcile only an exact record match, never pay it twice.
	if not bool(committed.get("accepted", false)) and bool(committed.get("published", false)):
		var reconciled := _store.call(&"load") as Dictionary
		if bool(reconciled.get("accepted", false)) and (_store.call(&"get_snapshot") as Dictionary).get(key) == wire_record:
			committed = _result(true, &"mining_session_published_reconciled")
	committed["binding_reason"] = &"mining_capacity_saved" if bool(committed.get("accepted", false)) else &"store_rejected"
	return committed


## A retained old world binding cannot overwrite a later extraction or undo a
## paid/reset terminal record after another Main has published it.
func _session_regresses(previous: Dictionary, next: Dictionary) -> bool:
	if int(next.generation) < int(previous.generation):
		return true
	if int(next.generation) > int(previous.generation):
		return int(previous.state) == CinderMiningPlatformActivity.State.COMPLETE and not bool(previous.capacity_paid)
	if bool(previous.capacity_paid) and not bool(next.capacity_paid):
		return true
	match int(previous.state):
		CinderMiningPlatformActivity.State.RESET:
			return int(next.state) != CinderMiningPlatformActivity.State.RESET
		CinderMiningPlatformActivity.State.COMPLETE:
			return int(next.state) not in [CinderMiningPlatformActivity.State.COMPLETE, CinderMiningPlatformActivity.State.RESET] \
				or (not bool(previous.capacity_paid) and int(next.state) == CinderMiningPlatformActivity.State.RESET) \
				or (int(next.state) == CinderMiningPlatformActivity.State.COMPLETE and bool(previous.reward_requested) and not bool(next.reward_requested))
		CinderMiningPlatformActivity.State.ACTIVE:
			return int(next.state) == CinderMiningPlatformActivity.State.IDLE \
				or (int(next.state) == CinderMiningPlatformActivity.State.ACTIVE and float(next.elapsed_seconds) < float(previous.elapsed_seconds))
	return false


func _session(snapshot: Dictionary, paid: bool) -> Dictionary:
	return {"state": snapshot.get("state"), "generation": snapshot.get("generation"),
		"elapsed_seconds": snapshot.get("elapsed_seconds"),
		"reward_requested": snapshot.get("reward_requested"), "capacity_paid": paid}


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"mining_capacity_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var key := String(_slot_id)
	if not payload.has(key):
		return _result(false, &"mining_capacity_not_found")
	var validation := validate_record(payload.get(key))
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason": &"mining_capacity_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"capacity": (payload[key] as Dictionary).capacity.duplicate(true),
		"session": ((payload[key] as Dictionary).get("session", {}) as Dictionary).duplicate(true),
	}.duplicate(true)


func capture(snapshot: Dictionary, reward_result: Dictionary) -> Dictionary:
	var request := reward_result.get("reward_request", {}) as Dictionary
	var generation := int(snapshot.get("generation", 0))
	var elapsed := float(snapshot.get("elapsed_seconds", -1.0))
	var duration := float(snapshot.get("extraction_seconds", 0.0))
	if int(snapshot.get("state", -1)) != CinderMiningPlatformActivity.State.COMPLETE \
			or generation < 1 or not is_equal_approx(elapsed, duration) \
			or duration <= 0.0 or duration > 86_400.0 \
			or StringName(snapshot.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(snapshot.get("content_class", &"")) != CONTENT_CLASS \
			or StringName(snapshot.get("evidence_status", &"")) != EVIDENCE_STATUS \
			or not bool(snapshot.get("reward_requested", false)) \
			or not bool(reward_result.get("accepted", false)) \
			or StringName(reward_result.get("reason", &"")) != &"reward_request_ready" \
			or StringName(request.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(request.get("reward_id", &"")) != REWARD_ID \
			or int(request.get("generation", -1)) != generation \
			or bool(request.get("granted", true)):
		return _result(false, &"mining_capacity_receipt_not_committed")
	var capacity := {
		"activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"extraction_seconds": duration,
		"reward_receipt": {
			"activity_id": ACTIVITY_ID,
			"reward_id": REWARD_ID,
			"granted": false,
			"replay_allowed": false,
		},
	}.duplicate(true)
	var record := {"schema_version": SCHEMA_VERSION, "payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id), "capacity": capacity,
		"session": _session(snapshot, true)}.duplicate(true)
	var validation := validate_record(record)
	return {"accepted": bool(validation.get("accepted", false)),
		"reason": &"mining_capacity_captured" if bool(validation.get("accepted", false)) \
			else validation.get("reason", &"mining_capacity_payload_corrupt"),
		"record": record if bool(validation.get("accepted", false)) else {}}.duplicate(true)


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"mining_capacity_payload_corrupt")
	var record := candidate as Dictionary
	if not _integral(record.get("schema_version")):
		return _result(false, &"mining_capacity_payload_corrupt")
	if int(record.schema_version) > SCHEMA_VERSION:
		return _result(false, &"mining_capacity_schema_unsupported")
	var version := int(record.get("schema_version", 0))
	if version not in [1, SCHEMA_VERSION] \
			or record.size() != (4 if version == 1 else 5) \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("capacity") is Dictionary:
		return _result(false, &"mining_capacity_payload_corrupt")
	if version == SCHEMA_VERSION:
		if not bool(CinderMiningPlatformActivity.validate_session(record.get("session")).get("accepted", false)):
			return _result(false, &"mining_session_payload_corrupt")
		var session := record.session as Dictionary
		if bool(session.capacity_paid) != not (record.capacity as Dictionary).is_empty():
			return _result(false, &"mining_capacity_payload_corrupt")
		if (record.capacity as Dictionary).is_empty():
			return _result(true, &"mining_session_payload_valid")
	var capacity := record.capacity as Dictionary
	var duration: Variant = capacity.get("extraction_seconds", null)
	if not capacity.get("reward_receipt") is Dictionary:
		return _result(false, &"mining_capacity_payload_corrupt")
	var receipt := capacity.get("reward_receipt", {}) as Dictionary
	if capacity.size() != 5 or str(capacity.get("activity_id", "")) != ACTIVITY_ID \
			or str(capacity.get("content_class", "")) != CONTENT_CLASS \
			or str(capacity.get("evidence_status", "")) != EVIDENCE_STATUS \
			or not (duration is float or duration is int) or not is_finite(float(duration)) \
			or float(duration) <= 0.0 or float(duration) > 86_400.0 \
			or receipt.size() != 4 or str(receipt.get("activity_id", "")) != ACTIVITY_ID \
			or str(receipt.get("reward_id", "")) != REWARD_ID \
			or receipt.get("granted") is not bool or bool(receipt.get("granted", true)) \
			or receipt.get("replay_allowed") is not bool \
			or bool(receipt.get("replay_allowed", true)):
		return _result(false, &"mining_capacity_payload_corrupt")
	if version == SCHEMA_VERSION and float(duration) != CinderMiningPlatformActivity.EXTRACTION_SECONDS:
		return _result(false, &"mining_capacity_payload_corrupt")
	return _result(true, &"mining_capacity_payload_valid")


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
