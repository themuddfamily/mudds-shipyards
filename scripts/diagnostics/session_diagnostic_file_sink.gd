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
const _TEMP_SUFFIX := ".tmp"

var _root_path := ""
var _filesystem: UserDataFilesystem
var _record_validator := Record.new() as SessionDiagnosticRecord


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


func get_log_path() -> String:
	return _log_path() if bool(_validate_root().accepted) else ""


func _read_log() -> Dictionary:
	if not _filesystem.file_exists(_log_path()):
		return {"accepted": true, "snapshots": []}
	var read := _filesystem.read_bytes(_log_path(), MAX_LOG_BYTES)
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


func _replace_log() -> Error:
	if _filesystem.file_exists(_log_path()):
		var remove_error: Error = _filesystem.remove_path(_log_path())
		if remove_error != OK:
			return remove_error
	return _filesystem.rename_path(_temp_path(), _log_path())


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


func _temp_path() -> String:
	return _log_path() + _TEMP_SUFFIX
