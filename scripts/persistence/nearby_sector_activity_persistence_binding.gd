class_name NearbySectorActivityPersistenceBinding
extends RefCounted

## Caller-owned bridge between NearbySectorActivitySessionAdapter and the
## existing UserDataStore envelope/transaction seam.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND: StringName = &"nearby_sector_activity_session"

var _store: RefCounted
var _adapter: RefCounted
var _slot_id: StringName = &""
var _namespace := ""


func configure(store: RefCounted, adapter: RefCounted, slot_id: StringName, payload_namespace: String = "") -> bool:
	if store == null or adapter == null or str(slot_id).strip_edges().is_empty():
		return false
	_store = store
	_adapter = adapter
	_slot_id = slot_id
	_namespace = payload_namespace
	return true


func save(binding_snapshot: Dictionary, expected_generation: int, commit_id: String) -> Dictionary:
	if not _configured() or expected_generation < 0 or commit_id.strip_edges().is_empty():
		return _result(false, &"invalid_save_request")
	var captured: Dictionary = _adapter.call("capture", binding_snapshot)
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"payload_kind": PAYLOAD_KIND,
		"slot_id": _slot_id,
		"activity_generation": expected_generation,
		"session": captured,
	}
	var document := payload
	if not _namespace.is_empty():
		var loaded: Dictionary = _store.call("load")
		if not loaded.get("accepted", false):
			return loaded
		document = (_store.call("get_snapshot") as Dictionary).duplicate(true)
		var previous: Variant = document.get(_namespace, {})
		if not previous is Dictionary:
			return _result(false, &"malformed_session_retained")
		if not previous.is_empty() and (previous.get("schema_version") != SCHEMA_VERSION or str(previous.get("payload_kind", "")) != str(PAYLOAD_KIND) or str(previous.get("slot_id", "")) != str(_slot_id)):
			return _result(false, &"unsupported_session_retained")
		if _adapter.has_method("validate_save"):
			var gate: Dictionary = _adapter.call("validate_save", previous.get("session", {}) as Dictionary, captured)
			if not gate.get("accepted", false):
				return gate
		document[_namespace] = JSON.parse_string(JSON.stringify(payload))
		expected_generation = int(_store.call("get_generation"))
	var result: Dictionary = _store.call("commit", document, expected_generation, commit_id)
	result["binding_reason"] = &"saved" if bool(result.get("accepted", false)) else &"store_rejected"
	return result


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"not_configured")
	var loaded: Dictionary = _store.call("load")
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	if not _namespace.is_empty():
		if not payload.has(_namespace):
			return _result(false, &"session_absent")
		if not payload[_namespace] is Dictionary:
			return _result(false, &"malformed_session_retained")
		payload = payload[_namespace]
	if payload.get("schema_version") != SCHEMA_VERSION or payload.get("payload_kind", &"") != PAYLOAD_KIND or payload.get("slot_id", &"") != _slot_id:
		return _result(false, &"wrong_slot_or_payload")
	var session: Variant = payload.get("session", {})
	var restored: Dictionary = _adapter.call("restore", session)
	if not bool(restored.get("accepted", false)):
		return restored
	return {"accepted": true, "reason": &"loaded", "generation": int(payload.get("activity_generation", -1)), "session": restored}


func _configured() -> bool:
	return is_instance_valid(_store) and is_instance_valid(_adapter) and not _slot_id.is_empty()


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
