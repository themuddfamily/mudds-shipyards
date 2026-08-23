class_name SessionDiagnosticFileSink
extends RefCounted

## Local, privacy-safe sink for snapshots already produced by
## SessionDiagnosticRecord. The caller supplies only a constrained storage
## root; the filename and temporary sibling are fixed by this service.

const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

const MAX_RETAINED_SNAPSHOTS := 4
const MAX_LOG_BYTES := 256 * 1024
const _LOG_NAME := "crash-log.json"
const _PREVIOUS_NAME := "crash-log.previous.json"
const _TEMP_SUFFIX := ".tmp"
const _REJECTED_SUFFIX := ".rejected"
const _EXPORT_INDEX_NAME := "diagnostics-support-index.json"
const _EXPORT_BUNDLE_PREFIX := "diagnostics-support-"
const _EXPORT_BUNDLE_SUFFIX := ".json"
const _EXPORT_TEMP_SUFFIX := ".tmp"
const MAX_EXPORT_BYTES := 256 * 1024
const MAX_EXPORT_BUNDLES := 3

var _root_path := ""
var _filesystem: UserDataFilesystem
var _record_validator := Record.new() as SessionDiagnosticRecord
var _read_source_previous := false


func _init(root_path: String, filesystem: UserDataFilesystem = null) -> void:
	_root_path = root_path
	_filesystem = filesystem if filesystem != null else Filesystem.new()


func append_snapshot(snapshot: Dictionary) -> Dictionary:
	var root_status := _validate_root()
	if not bool(root_status.accepted):
		return root_status
	var validated := _record_validator._validate_snapshot(snapshot)
	if not bool(validated.accepted):
		return {"accepted": false, "reason": &"snapshot_rejected", "snapshot_reason": validated.reason}
	var existing := _read_log()
	if not bool(existing.accepted):
		return existing
	var snapshots := existing.snapshots as Array
	snapshots.append((validated.snapshot as Dictionary).duplicate(true))
	while snapshots.size() > MAX_RETAINED_SNAPSHOTS:
		snapshots.pop_front()
	var encoded := JSON.stringify(snapshots).to_utf8_buffer()
	if encoded.size() > MAX_LOG_BYTES:
		return {"accepted": false, "reason": &"log_too_large"}
	var directory_error: Error = _filesystem.ensure_parent_directory(_log_path())
	if directory_error != OK:
		return {"accepted": false, "reason": &"log_directory_failed", "error": directory_error}
	var write_error: Error = _filesystem.write_bytes_and_flush(_temp_path(), encoded)
	if write_error != OK:
		return {"accepted": false, "reason": &"log_stage_failed", "error": write_error}
	var staged := _filesystem.read_bytes(_temp_path(), MAX_LOG_BYTES)
	if int(staged.get("error", FAILED)) != OK \
		or (staged.get("bytes", PackedByteArray()) as PackedByteArray) != encoded:
		return {"accepted": false, "reason": &"log_stage_verification_failed"}
	var replace_error := _replace_log()
	if replace_error != OK:
		return {"accepted": false, "reason": &"log_publish_failed", "error": replace_error}
	return {
		"accepted": true,
		"reason": &"written",
		"retained_snapshot_count": snapshots.size(),
		"path": _log_path(),
	}


## Explicitly repairs the fixed local sink after an interrupted or malformed
## write. Malformed bytes are quarantined; a valid temp is promoted only when
## no valid target exists. Normal append never performs either action.
func recover_prior_log() -> Dictionary:
	var root_status := _validate_root()
	if not bool(root_status.accepted):
		return root_status
	var target_exists := _filesystem.file_exists(_log_path())
	var temp_exists := _filesystem.file_exists(_temp_path())
	if not target_exists and not temp_exists:
		return {"accepted": false, "reason": &"no_log_recovery_needed"}
	var target := _read_log_at(_log_path()) if target_exists else {"accepted": true, "snapshots": []}
	var temp := _read_log_at(_temp_path()) if temp_exists else {"accepted": true, "snapshots": []}
	if bool(target.accepted) and bool(temp.accepted) and temp_exists:
		return {"accepted": false, "reason": &"valid_log_and_stage_present"}
	if target_exists and not bool(target.accepted):
		var quarantined_target := _quarantine(_log_path())
		if not bool(quarantined_target.accepted):
			return quarantined_target
		target_exists = false
	if temp_exists and not bool(temp.accepted):
		var quarantined_temp := _quarantine(_temp_path())
		if not bool(quarantined_temp.accepted):
			return quarantined_temp
		temp_exists = false
	if temp_exists and not target_exists:
		var promote_error: Error = _filesystem.rename_path(_temp_path(), _log_path())
		if promote_error != OK:
			return {"accepted": false, "reason": &"log_recovery_publish_failed", "error": promote_error}
		return {"accepted": true, "reason": &"interrupted_log_recovered"}
	return {"accepted": true, "reason": &"malformed_log_quarantined"}


func get_log_path() -> String:
	return _log_path() if bool(_validate_root().accepted) else ""


## Explicitly exports only validated current/previous diagnostic snapshots.
## The destination is fixed beneath the caller-authorized diagnostics export
## root; no upload, arbitrary filename, or gameplay data crosses this seam.
func export_support_bundle(export_root: String, expected_generation: int) -> Dictionary:
	if not _valid_export_root(export_root):
		return {"accepted": false, "reason": &"export_root_invalid"}
	if expected_generation < 1:
		return {"accepted": false, "reason": &"export_generation_invalid"}
	var index_path := export_root + "/" + _EXPORT_INDEX_NAME
	var index := _read_export_index(index_path)
	if not bool(index.accepted):
		return index
	var entries := index.entries as Array
	var prior_entries := entries.duplicate(true)
	if not entries.is_empty() and expected_generation <= int((entries[-1] as Dictionary).generation):
		return {"accepted": false, "reason": &"export_generation_stale"}
	var export_path := export_root + "/" + _EXPORT_BUNDLE_PREFIX + ("%08d" % expected_generation) + _EXPORT_BUNDLE_SUFFIX
	var current := _read_log_at(_log_path()) if _filesystem.file_exists(_log_path()) else {"accepted": true, "snapshots": []}
	var previous := _read_log_at(_previous_path()) if _filesystem.file_exists(_previous_path()) else {"accepted": true, "snapshots": []}
	var bundle := {
		"schema_version": 1,
		"generation": expected_generation,
		"current": current.snapshots if bool(current.accepted) else [],
		"previous": previous.snapshots if bool(previous.accepted) else [],
	}
	var encoded := JSON.stringify(bundle).to_utf8_buffer()
	if encoded.size() > MAX_EXPORT_BYTES:
		return {"accepted": false, "reason": &"export_too_large"}
	var parent_error := _filesystem.ensure_parent_directory(export_path)
	if parent_error != OK:
		return {"accepted": false, "reason": &"export_directory_failed", "error": parent_error}
	var temp_path := export_path + _EXPORT_TEMP_SUFFIX
	var write_error := _filesystem.write_bytes_and_flush(temp_path, encoded)
	if write_error != OK:
		return {"accepted": false, "reason": &"export_stage_failed", "error": write_error}
	var staged := _filesystem.read_bytes(temp_path, MAX_EXPORT_BYTES)
	if int(staged.get("error", FAILED)) != OK \
		or (staged.get("bytes", PackedByteArray()) as PackedByteArray) != encoded:
		return {"accepted": false, "reason": &"export_stage_verification_failed"}
	if _filesystem.file_exists(export_path):
		var remove_error := _filesystem.remove_path(export_path)
		if remove_error != OK:
			return {"accepted": false, "reason": &"export_replace_failed", "error": remove_error}
	var publish_error := _filesystem.rename_path(temp_path, export_path)
	if publish_error != OK:
		return {"accepted": false, "reason": &"export_publish_failed", "error": publish_error}
	entries.append({"generation": expected_generation, "path": export_path})
	while entries.size() > MAX_EXPORT_BUNDLES:
		entries.pop_front()
	var index_payload := {"schema_version": 1, "entries": entries}
	var index_encoded := JSON.stringify(index_payload).to_utf8_buffer()
	if index_encoded.size() > MAX_EXPORT_BYTES:
		_filesystem.remove_path(export_path)
		return {"accepted": false, "reason": &"export_index_too_large"}
	var index_temp := index_path + _EXPORT_TEMP_SUFFIX
	var index_write := _filesystem.write_bytes_and_flush(index_temp, index_encoded)
	if index_write != OK:
		_filesystem.remove_path(export_path)
		return {"accepted": false, "reason": &"export_index_stage_failed", "error": index_write}
	var index_staged := _filesystem.read_bytes(index_temp, MAX_EXPORT_BYTES)
	if int(index_staged.get("error", FAILED)) != OK \
		or (index_staged.get("bytes", PackedByteArray()) as PackedByteArray) != index_encoded:
		_filesystem.remove_path(export_path)
		return {"accepted": false, "reason": &"export_index_verification_failed"}
	if _filesystem.file_exists(index_path):
		var remove_index := _filesystem.remove_path(index_path)
		if remove_index != OK:
			_filesystem.remove_path(export_path)
			return {"accepted": false, "reason": &"export_index_replace_failed", "error": remove_index}
	var index_publish := _filesystem.rename_path(index_temp, index_path)
	if index_publish != OK:
		_filesystem.remove_path(export_path)
		return {"accepted": false, "reason": &"export_index_publish_failed", "error": index_publish}
	for entry in prior_entries:
		var prior_path := str((entry as Dictionary).get("path", ""))
		var retained := false
		for kept in entries:
			if str((kept as Dictionary).get("path", "")) == prior_path:
				retained = true
				break
		if not retained and prior_path.begins_with(export_root + "/") and _filesystem.file_exists(prior_path):
			_filesystem.remove_path(prior_path)
	return {"accepted": true, "reason": &"exported", "generation": expected_generation, "path": export_path, "index_path": index_path}


func _read_export_index(path: String) -> Dictionary:
	if not _filesystem.file_exists(path):
		return {"accepted": true, "entries": []}
	var read := _filesystem.read_bytes(path, MAX_EXPORT_BYTES)
	if int(read.get("error", FAILED)) != OK:
		return {"accepted": false, "reason": &"export_read_failed"}
	var parser := JSON.new()
	if parser.parse((read.bytes as PackedByteArray).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"accepted": false, "reason": &"export_invalid"}
	var document := parser.data as Dictionary
	var raw_entries: Variant = document.get("entries")
	if document.get("schema_version") != 1 or not raw_entries is Array \
		or (raw_entries as Array).size() > MAX_EXPORT_BUNDLES:
		return {"accepted": false, "reason": &"export_invalid"}
	return {"accepted": true, "entries": (raw_entries as Array).duplicate(true)}


func delete_all_support_exports(export_root: String) -> Dictionary:
	if not _valid_export_root(export_root):
		return {"accepted": false, "reason": &"export_root_invalid"}
	var index_path := export_root + "/" + _EXPORT_INDEX_NAME
	var index := _read_export_index(index_path)
	if not bool(index.accepted):
		return index
	for entry in index.entries as Array:
		var path := str((entry as Dictionary).get("path", ""))
		if path.begins_with(export_root + "/") and _filesystem.file_exists(path):
			var removed := _filesystem.remove_path(path)
			if removed != OK:
				return {"accepted": false, "reason": &"export_delete_failed", "error": removed}
	if _filesystem.file_exists(index_path):
		var remove_index := _filesystem.remove_path(index_path)
		if remove_index != OK:
			return {"accepted": false, "reason": &"export_delete_failed", "error": remove_index}
	return {"accepted": true, "reason": &"exports_deleted"}


func _valid_export_root(path: String) -> bool:
	return (path == "user://diagnostics/exports" or path.begins_with("user://diagnostics/exports/")) \
		and not path.contains("..") and not path.contains("\\") \
		and not path.contains("\n") and not path.contains("\r")


func _read_log() -> Dictionary:
	_read_source_previous = false
	if _filesystem.file_exists(_log_path()):
		var current := _read_log_at(_log_path())
		if bool(current.accepted):
			return current
	if _filesystem.file_exists(_previous_path()):
		var previous := _read_log_at(_previous_path())
		if bool(previous.accepted):
			_read_source_previous = true
			return previous
	if not _filesystem.file_exists(_log_path()):
		return {"accepted": true, "snapshots": []}
	return {"accepted": false, "reason": &"log_invalid"}


func _read_log_at(path: String) -> Dictionary:
	var read := _filesystem.read_bytes(path, MAX_LOG_BYTES)
	if int(read.get("error", FAILED)) != OK:
		return {"accepted": false, "reason": &"log_read_failed"}
	var bytes := read.get("bytes", PackedByteArray()) as PackedByteArray
	if bytes.is_empty() or bytes.size() > MAX_LOG_BYTES:
		return {"accepted": false, "reason": &"log_invalid"}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Array:
		return {"accepted": false, "reason": &"log_invalid"}
	var snapshots: Array = []
	for candidate in parser.data as Array:
		var validated := _record_validator._validate_snapshot(candidate)
		if not bool(validated.accepted):
			return {"accepted": false, "reason": &"log_invalid"}
		snapshots.append((validated.snapshot as Dictionary).duplicate(true))
	if snapshots.size() > MAX_RETAINED_SNAPSHOTS:
		return {"accepted": false, "reason": &"log_invalid"}
	return {"accepted": true, "snapshots": snapshots}


func _quarantine(path: String) -> Dictionary:
	var rejected_path := path + _REJECTED_SUFFIX
	if _filesystem.file_exists(rejected_path):
		return {"accepted": false, "reason": &"log_quarantine_exists"}
	var read := _filesystem.read_bytes(path, MAX_LOG_BYTES)
	if int(read.get("error", FAILED)) != OK:
		return {"accepted": false, "reason": &"log_quarantine_read_failed"}
	var bytes := read.get("bytes", PackedByteArray()) as PackedByteArray
	if bytes.is_empty() or bytes.size() > MAX_LOG_BYTES:
		return {"accepted": false, "reason": &"log_quarantine_read_failed"}
	var write_error: Error = _filesystem.write_bytes_and_flush(rejected_path, bytes)
	if write_error != OK:
		return {"accepted": false, "reason": &"log_quarantine_write_failed"}
	var verify := _filesystem.read_bytes(rejected_path, MAX_LOG_BYTES)
	if int(verify.get("error", FAILED)) != OK \
		or (verify.get("bytes", PackedByteArray()) as PackedByteArray) != bytes:
		return {"accepted": false, "reason": &"log_quarantine_write_failed"}
	var remove_error: Error = _filesystem.remove_path(path)
	if remove_error != OK:
		return {"accepted": false, "reason": &"log_quarantine_remove_failed"}
	return {"accepted": true, "reason": &"quarantined"}


func _replace_log() -> Error:
	var current_valid := false
	if _filesystem.file_exists(_log_path()):
		current_valid = bool(_read_log_at(_log_path()).accepted)
	if current_valid and not _read_source_previous:
		if _filesystem.file_exists(_previous_path()):
			var remove_previous := _filesystem.remove_path(_previous_path())
			if remove_previous != OK:
				return remove_previous
		var rotate := _filesystem.rename_path(_log_path(), _previous_path())
		if rotate != OK:
			return rotate
	else:
		if _filesystem.file_exists(_log_path()):
			var remove_current := _filesystem.remove_path(_log_path())
			if remove_current != OK:
				return remove_current
	var publish := _filesystem.rename_path(_temp_path(), _log_path())
	if publish != OK and current_valid and not _read_source_previous:
		_filesystem.rename_path(_previous_path(), _log_path())
	return publish


func _validate_root() -> Dictionary:
	if _root_path.is_empty() or _root_path.length() > 128:
		return {"accepted": false, "reason": &"storage_root_invalid"}
	if not (_root_path.begins_with("user://") or _root_path.begins_with("memory://")):
		return {"accepted": false, "reason": &"storage_root_invalid"}
	var suffix := _root_path.substr(_root_path.find("//") + 2)
	for character in suffix:
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) or character in ["/", "-", "_"]):
			return {"accepted": false, "reason": &"storage_root_invalid"}
	if _root_path.contains("..") or _root_path.contains("\\") \
		or _root_path.contains("\n") or _root_path.contains("\r"):
		return {"accepted": false, "reason": &"storage_root_invalid"}
	return {"accepted": true}


func _log_path() -> String:
	return _root_path + "/" + _LOG_NAME


func _previous_path() -> String:
	return _root_path + "/" + _PREVIOUS_NAME


func _temp_path() -> String:
	return _log_path() + _TEMP_SUFFIX
