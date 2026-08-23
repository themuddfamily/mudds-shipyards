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
const _EXPORT_NAME := "diagnostics-support.json"
const _EXPORT_TEMP_SUFFIX := ".tmp"
const MAX_EXPORT_BYTES := 256 * 1024

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
	var export_path := export_root + "/" + _EXPORT_NAME
	if _filesystem.file_exists(export_path):
		var prior := _read_export_generation(export_path)
		if not bool(prior.accepted):
			return prior
		if expected_generation <= int(prior.generation):
			return {"accepted": false, "reason": &"export_generation_stale"}
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
	return {"accepted": true, "reason": &"exported", "generation": expected_generation, "path": export_path}


func _read_export_generation(path: String) -> Dictionary:
	var read := _filesystem.read_bytes(path, MAX_EXPORT_BYTES)
	if int(read.get("error", FAILED)) != OK:
		return {"accepted": false, "reason": &"export_read_failed"}
	var parser := JSON.new()
	if parser.parse((read.bytes as PackedByteArray).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"accepted": false, "reason": &"export_invalid"}
	var document := parser.data as Dictionary
	var raw_generation: Variant = document.get("generation")
	if document.get("schema_version") != 1 \
		or (not raw_generation is int and not raw_generation is float) \
		or int(raw_generation) < 1 or float(raw_generation) != float(int(raw_generation)):
		return {"accepted": false, "reason": &"export_invalid"}
	return {"accepted": true, "generation": int(document.generation)}


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
