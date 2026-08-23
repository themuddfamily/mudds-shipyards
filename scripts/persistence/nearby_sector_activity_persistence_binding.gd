class_name NearbySectorActivityPersistenceBinding
extends RefCounted

## Caller-owned bridge between NearbySectorActivitySessionAdapter and the
## existing UserDataStore envelope/transaction seam.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND: StringName = &"nearby_sector_activity_session"

var _store: RefCounted
var _adapter: RefCounted
var _slot_id: StringName = &""


func configure(store: RefCounted, adapter: RefCounted, slot_id: StringName) -> bool:
	if store == null or adapter == null or str(slot_id).strip_edges().is_empty():
		return false
	_store = store
	_adapter = adapter
	_slot_id = slot_id
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
	var result: Dictionary = _store.call("commit", payload, expected_generation, commit_id)
	result["binding_reason"] = &"saved" if bool(result.get("accepted", false)) else &"store_rejected"
	return result


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"not_configured")
	var loaded: Dictionary = _store.call("load")
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	if payload.get("payload_kind", &"") != PAYLOAD_KIND or payload.get("slot_id", &"") != _slot_id:
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
