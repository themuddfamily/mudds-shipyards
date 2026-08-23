class_name CinderScanDiscoveryPersistence
extends RefCounted

## Namespaced atomic-store bridge for the terminal Cinder derelict discovery.
## It stores no active scan progress or transient activity generation.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "cinder_scan_discovery_receipt"
const ACTIVITY_ID := "cinder_derelict_structure_scan"
const REWARD_ID := "derelict_material_sample"
const CONTENT_CLASS := "NEW"
const EVIDENCE_STATUS := "modern_interpretation"

var _store: RefCounted
var _slot_id: StringName = &""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"scan_discovery_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"scan_discovery_persistence_configured")


func save(snapshot: Dictionary, reward_result: Dictionary, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"scan_discovery_save_invalid")
	var captured := capture(snapshot, reward_result)
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
		&"scan_discovery_saved" if bool(committed.get("accepted", false)) \
		else &"store_rejected"
	)
	return committed


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"scan_discovery_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var key := String(_slot_id)
	if not payload.has(key):
		return _result(false, &"scan_discovery_not_found")
	var validation := validate_record(payload.get(key))
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason": &"scan_discovery_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"discovery": (payload[key] as Dictionary).discovery.duplicate(true),
	}.duplicate(true)


func capture(snapshot: Dictionary, reward_result: Dictionary) -> Dictionary:
	var request := reward_result.get("reward_request", {}) as Dictionary
	if int(snapshot.get("state", -1)) != 2 \
			or StringName(snapshot.get("state_id", &"")) != &"complete" \
			or not bool(snapshot.get("reward_requested", false)) \
			or StringName(snapshot.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(snapshot.get("content_class", &"")) != CONTENT_CLASS \
			or StringName(snapshot.get("evidence_status", &"")) != EVIDENCE_STATUS \
			or not bool(reward_result.get("accepted", false)) \
			or StringName(reward_result.get("reason", &"")) != &"reward_request_ready" \
			or StringName(request.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(request.get("reward_id", &"")) != REWARD_ID \
			or int(request.get("generation", -1)) != int(snapshot.get("generation", -2)) \
			or bool(request.get("granted", true)):
		return _result(false, &"scan_discovery_receipt_not_committed")
	var discovery := {
		"activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"scan_seconds": float(snapshot.get("scan_seconds", 0.0)),
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
		"discovery": discovery,
	}.duplicate(true)
	var validation := validate_record(record)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason": &"scan_discovery_captured",
		"record": record,
	}.duplicate(true)


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"scan_discovery_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 4 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("discovery") is Dictionary:
		return _result(false, &"scan_discovery_payload_corrupt")
	var discovery := record.discovery as Dictionary
	var duration: Variant = discovery.get("scan_seconds", null)
	var receipt: Variant = discovery.get("reward_receipt", null)
	if discovery.size() != 5 or str(discovery.get("activity_id", "")) != ACTIVITY_ID \
			or str(discovery.get("content_class", "")) != CONTENT_CLASS \
			or str(discovery.get("evidence_status", "")) != EVIDENCE_STATUS \
			or not (duration is float or duration is int) \
			or not is_finite(float(duration)) or float(duration) <= 0.0 \
			or float(duration) > 86_400.0 or not receipt is Dictionary:
		return _result(false, &"scan_discovery_payload_corrupt")
	var reward := receipt as Dictionary
	if reward.size() != 4 or str(reward.get("activity_id", "")) != ACTIVITY_ID \
			or str(reward.get("reward_id", "")) != REWARD_ID \
			or reward.get("granted") is not bool or bool(reward.get("granted", true)) \
			or reward.get("replay_allowed") is not bool \
			or bool(reward.get("replay_allowed", true)):
		return _result(false, &"scan_discovery_payload_corrupt")
	return _result(true, &"scan_discovery_payload_valid")


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
