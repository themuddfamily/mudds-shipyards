class_name LegacyDataRetirement
extends RefCounted

## One-time caller-driven migration boundary for a legacy file and the
## UserDataStore. Legacy bytes are never parsed or deleted by this class; the
## caller supplies the already-validated destination payload.

const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

const MAX_LEGACY_BYTES := 1024 * 1024
const _BACKUP_SUFFIX := ".retired.bak"

var _legacy_path := ""
var _store: UserDataStore
var _filesystem: UserDataFilesystem


func _init(
		legacy_path: String,
		store: UserDataStore,
		filesystem: UserDataFilesystem = null
		) -> void:
	_legacy_path = legacy_path
	_store = store
	_filesystem = filesystem if filesystem != null else Filesystem.new()


## Publishes the supplied validated payload, then retires legacy bytes to one
## fixed backup marker. A retry after retirement failure recognizes an exact
## already-published payload and only retries the rename.
func migrate(
		payload: Dictionary,
		expected_generation: int,
		commit_id: String
		) -> Dictionary:
	if _store == null or _legacy_path.is_empty():
		return {"accepted": false, "reason": &"migration_unavailable"}
	if _store.get_loaded_source() == &"none":
		return {"accepted": false, "reason": &"store_not_loaded"}
	if not bool(UserDataStore.validate_payload(payload).valid):
		return {"accepted": false, "reason": &"payload_invalid"}
	var legacy := _read_legacy()
	if not bool(legacy.accepted):
		return legacy
	var backup_path := _backup_path()
	if _filesystem.file_exists(backup_path):
		return {"accepted": false, "reason": &"retirement_marker_exists"}
	var already_published := _payloads_match(_store.get_snapshot(), payload) \
		and _store.get_generation() >= expected_generation
	if not already_published:
		var committed := _store.commit(payload, expected_generation, commit_id)
		if not bool(committed.accepted):
			return {
				"accepted": false,
				"reason": &"migration_publish_failed",
				"store_status": committed,
			}
	var retire_error: Error = _filesystem.rename_path(_legacy_path, backup_path)
	if retire_error != OK:
		return {
			"accepted": false,
			"reason": &"legacy_retirement_failed",
			"error": retire_error,
			"already_published": already_published,
		}
	return {
		"accepted": true,
		"reason": &"migrated",
		"backup_path": backup_path,
		"already_published": already_published,
	}


func _read_legacy() -> Dictionary:
	if not _filesystem.file_exists(_legacy_path):
		return {"accepted": false, "reason": &"legacy_missing"}
	var read := _filesystem.read_bytes(_legacy_path, MAX_LEGACY_BYTES)
	if int(read.get("error", FAILED)) != OK:
		return {"accepted": false, "reason": &"legacy_read_failed"}
	var bytes := read.get("bytes", PackedByteArray()) as PackedByteArray
	if bytes.is_empty() or bytes.size() > MAX_LEGACY_BYTES:
		return {"accepted": false, "reason": &"legacy_too_large"}
	return {"accepted": true, "bytes": bytes}


func _backup_path() -> String:
	return _legacy_path + _BACKUP_SUFFIX


func _payloads_match(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		var left_number := typeof(left) in [TYPE_INT, TYPE_FLOAT]
		var right_number := typeof(right) in [TYPE_INT, TYPE_FLOAT]
		return left_number and right_number and float(left) == float(right)
	if left is Dictionary:
		var left_dict := left as Dictionary
		var right_dict := right as Dictionary
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict:
			if not right_dict.has(key) or not _payloads_match(left_dict[key], right_dict[key]):
				return false
		return true
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _payloads_match(left_array[index], right_array[index]):
				return false
		return true
	return left == right
