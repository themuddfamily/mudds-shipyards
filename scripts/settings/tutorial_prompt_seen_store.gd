class_name TutorialPromptSeenStore
extends RefCounted

## "Seen once" set for one-shot tutorial prompts.
##
## This is a persistence contract, not a tutorial authority. It records which
## prompt ids a player has already been shown so a first-time briefing never
## repeats, and it stores them as one more caller-owned namespace inside the
## existing `user://mudds_user_data.json` document. No new persistence format:
## the same UserDataStore envelope, generation fence and atomic commit path the
## runtime settings adapter already uses, beside the "runtime_settings" key.

const SCHEMA_VERSION := 1
const PAYLOAD_NAMESPACE := "tutorial_prompts_seen"
const MAX_SEEN_IDS := 64
const MAX_ID_BYTES := 64

const _SNAPSHOT_KEYS := ["schema_version", "seen_ids"]

var _store: UserDataStore
var _restored := false
var _operation_active := false
var _seen: Dictionary = {}


func _init(store: UserDataStore = null) -> void:
	_store = store


func is_restored() -> bool:
	return _restored


func has_store() -> bool:
	return _store != null


## Adopts the shared user-data document when one only becomes available after
## this set was created. Records already made in memory are kept.
func adopt_store(store: UserDataStore) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	if store == null or _store != null:
		return _result(false, &"store_already_bound")
	_store = store
	_operation_active = true
	var previous := _seen.duplicate()
	var result := _restore()
	_operation_active = false
	for raw: Variant in previous:
		_seen[str(raw)] = true
	return result


func has_seen(prompt_id: StringName) -> bool:
	return _seen.has(String(prompt_id))


func get_seen_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw: Variant in _seen.keys():
		ids.append(StringName(str(raw)))
	ids.sort()
	return ids


## Restores only the already-loaded store. A missing namespace is a valid first
## run; malformed or newer state is rejected without changing this set.
func restore() -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _restore()
	_operation_active = false
	return result


## Records one prompt id. Without a usable store the id is still remembered for
## the rest of the process so a briefing cannot repeat inside one session.
func mark_seen(prompt_id: StringName, commit_id: String = "") -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call")
	_operation_active = true
	var result := _mark_seen(prompt_id, commit_id)
	_operation_active = false
	return result


static func decode_snapshot(raw_value: Variant) -> Dictionary:
	if not raw_value is Dictionary:
		return {"accepted": false, "reason": &"snapshot_invalid"}
	var raw := raw_value as Dictionary
	if raw.size() != _SNAPSHOT_KEYS.size():
		return {"accepted": false, "reason": &"snapshot_invalid"}
	for key: String in _SNAPSHOT_KEYS:
		if not raw.has(key):
			return {"accepted": false, "reason": &"snapshot_invalid"}
	# JSON round-trips integral numbers as floats, so accept either encoding of
	# the same integer and reject anything that is not a whole number.
	if not _is_integral_number(raw.schema_version):
		return {"accepted": false, "reason": &"schema_invalid"}
	var schema := int(raw.schema_version)
	if schema > SCHEMA_VERSION:
		return {"accepted": false, "reason": &"schema_newer"}
	if schema < 1:
		return {"accepted": false, "reason": &"schema_invalid"}
	if not raw.seen_ids is Array:
		return {"accepted": false, "reason": &"seen_ids_invalid"}
	var ids := raw.seen_ids as Array
	if ids.size() > MAX_SEEN_IDS:
		return {"accepted": false, "reason": &"seen_ids_invalid"}
	var unique := {}
	var normalized: Array[String] = []
	for candidate: Variant in ids:
		if not candidate is String or not _valid_prompt_id(candidate as String):
			return {"accepted": false, "reason": &"seen_ids_invalid"}
		var value := candidate as String
		if unique.has(value):
			return {"accepted": false, "reason": &"seen_ids_invalid"}
		unique[value] = true
		normalized.append(value)
	return {
		"accepted": true,
		"reason": &"valid",
		"snapshot": {
			"schema_version": schema,
			"seen_ids": normalized.duplicate(),
		},
	}


func _restore() -> Dictionary:
	if _store == null:
		return _result(false, &"no_store")
	if _store.get_loaded_source() == &"none":
		return _result(false, &"store_not_loaded")
	var stored := _store.get_snapshot()
	if not stored.has(PAYLOAD_NAMESPACE):
		_seen.clear()
		_restored = true
		return _result(true, &"empty")
	var decoded := decode_snapshot(stored.get(PAYLOAD_NAMESPACE))
	if not bool(decoded.accepted):
		return _result(false, StringName(decoded.reason))
	_install((decoded.snapshot as Dictionary).get("seen_ids", []) as Array)
	_restored = true
	return _result(true, &"restored")


func _mark_seen(prompt_id: StringName, commit_id: String) -> Dictionary:
	var value := String(prompt_id)
	if not _valid_prompt_id(value):
		return _result(false, &"prompt_id_invalid")
	if _seen.has(value):
		return _result(true, &"already_seen")
	if _seen.size() >= MAX_SEEN_IDS:
		return _result(false, &"seen_ids_full")
	_seen[value] = true
	if _store == null or not _restored:
		# Presentation must still not repeat inside this process. Persistence is
		# simply unavailable; the caller keeps its in-memory guarantee.
		return _result(true, &"memory_only")
	var candidate := _snapshot()
	var decoded := decode_snapshot(candidate)
	if not bool(decoded.accepted):
		_seen.erase(value)
		return _result(false, StringName(decoded.reason))
	var payload := _store.get_snapshot()
	payload[PAYLOAD_NAMESPACE] = candidate.duplicate(true)
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	if not bool(committed.accepted):
		return _result(true, &"memory_only", {"store_status": committed})
	return _result(true, &"persisted", {"generation": int(committed.generation)})


func _snapshot() -> Dictionary:
	var ids: Array[String] = []
	for raw: Variant in _seen.keys():
		ids.append(str(raw))
	ids.sort()
	return {"schema_version": SCHEMA_VERSION, "seen_ids": ids}


func _install(ids: Array) -> void:
	_seen.clear()
	for value: Variant in ids:
		_seen[str(value)] = true


static func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var number := float(value)
	return is_finite(number) and is_equal_approx(number, roundf(number))


static func _valid_prompt_id(value: String) -> bool:
	if value.is_empty() or value.to_utf8_buffer().size() > MAX_ID_BYTES:
		return false
	for index in value.length():
		var character := value[index]
		if not (
			(character >= "a" and character <= "z")
			or (character >= "0" and character <= "9")
			or character == "_"
		):
			return false
	return true


func _result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
		) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"restored": _restored,
		"seen_count": _seen.size(),
		"schema_version": SCHEMA_VERSION,
		"tutorial_authority": false,
		"gameplay_authority": false,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
