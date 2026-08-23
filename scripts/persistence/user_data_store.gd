class_name UserDataStore
extends RefCounted

## Strict, versioned JSON persistence boundary for future user data.
##
## The store deliberately has no knowledge of RuntimeSettings, GameFlow, HUD,
## save slots, cloud/network state, or migrations. Callers own the keys inside
## `payload`; this class owns and strictly validates the surrounding envelope.
## This is a single-writer recoverable transaction, not durable ACID storage.

const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

const SCHEMA_VERSION := 1
const MAX_DOCUMENT_BYTES := 1024 * 1024
const MAX_PAYLOAD_DEPTH := 12
const MAX_DOCUMENT_NESTING := MAX_PAYLOAD_DEPTH + 2
const MAX_TOTAL_ENTRIES := 4096
const MAX_KEY_BYTES := 256
const MAX_STRING_BYTES := 16 * 1024
const MAX_COMMIT_ID_BYTES := 128
const MAX_GENERATION := 2147483647
const MAX_SAFE_JSON_INTEGER := 9007199254740991

const _TEMP_SUFFIX := ".tmp"
const _BACKUP_SUFFIX := ".bak"
const _ENVELOPE_KEYS := ["schema_version", "generation", "commit", "payload"]
const _COMMIT_KEYS := ["id", "parent_generation", "parent_id", "payload_sha256"]

var _path: String
var _filesystem: UserDataFilesystem
var _loaded := false
var _generation := 0
var _commit_metadata: Dictionary = {}
var _snapshot: Dictionary = {}
var _loaded_from := &"none"


func _init(path: String, filesystem: UserDataFilesystem = null) -> void:
	_path = path
	_filesystem = filesystem if filesystem != null else Filesystem.new()


## Loads the valid primary, otherwise the valid last-known-good backup. A stale
## temporary sibling is never promoted by load. Failure leaves no partial state.
func load() -> Dictionary:
	var previous := _state_record()
	var primary := _read_document(_path)
	var temporary := _read_document(_temp_path())
	var backup := _read_document(_backup_path())
	if _has_newer_schema([primary, temporary, backup]):
		_restore_state(previous)
		return _load_result(false, &"newer_schema", &"none", primary, backup)
	# A valid temporary document is an interrupted transaction, not an empty
	# or stale sibling. Fail closed so a caller cannot silently discard it.
	if bool(temporary.valid):
		_restore_state(previous)
		return _load_result(false, &"interrupted_transaction", &"none", primary, backup)
	if bool(primary.valid) and bool(backup.valid) and not _documents_form_chain(
		primary.document as Dictionary, backup.document as Dictionary
	):
		_restore_state(previous)
		return _load_result(false, &"incoherent_primary_backup", &"none", primary, backup)
	if bool(primary.valid):
		_install_document(primary.document as Dictionary, &"primary")
		return _load_result(true, &"ok", &"primary", primary, {})
	if bool(backup.valid):
		_install_document(backup.document as Dictionary, &"backup")
		return _load_result(true, &"primary_invalid_backup_loaded", &"backup", primary, backup)
	_restore_state(previous)
	var both_missing := not bool(primary.exists) and not bool(backup.exists)
	if both_missing:
		_loaded = true
		_generation = 0
		_commit_metadata = {}
		_snapshot = {}
		_loaded_from = &"empty"
		return _load_result(true, &"empty", &"empty", primary, backup)
	return _load_result(false, &"no_valid_document", &"none", primary, backup)


## Explicitly promotes a verified interrupted transaction. Normal load never
## performs this action implicitly because the staged document was not yet
## published when the previous process stopped.
func recover_interrupted_transaction() -> Dictionary:
	if _path.is_empty():
		return _commit_result(false, &"invalid_path")
	for collision_path in [_path, _temp_path(), _backup_path()]:
		if _filesystem.directory_exists(collision_path):
			return _commit_result(false, &"transaction_path_is_directory")
	var primary := _read_document(_path)
	var temporary := _read_document(_temp_path())
	var backup := _read_document(_backup_path())
	if _has_newer_schema([primary, temporary, backup]):
		return _commit_result(false, &"newer_schema")
	if not bool(temporary.valid):
		return _commit_result(false, &"no_interrupted_transaction")
	# Never consume a corrupt/unreadable artifact as part of recovery.
	if bool(primary.exists) and not bool(primary.valid):
		return _commit_result(false, &"invalid_primary")
	if bool(backup.exists) and not bool(backup.valid):
		return _commit_result(false, &"invalid_backup")
	if bool(primary.valid) and bool(backup.valid) and not _documents_form_chain(
		primary.document as Dictionary, backup.document as Dictionary
	):
		return _commit_result(false, &"incoherent_primary_backup")
	var staged := temporary.document as Dictionary
	var authority: Dictionary = {}
	if bool(primary.valid):
		authority = primary.document as Dictionary
	elif bool(backup.valid):
		authority = backup.document as Dictionary
	if authority.is_empty():
		if int(staged.generation) != 1 or int((staged.commit as Dictionary).parent_generation) != 0 \
			or str((staged.commit as Dictionary).parent_id) != "":
			return _commit_result(false, &"unsafe_transaction_parent")
	else:
		var staged_commit := staged.commit as Dictionary
		var authority_commit := authority.commit as Dictionary
		if int(staged.generation) != int(authority.generation) + 1 \
			or int(staged_commit.parent_generation) != int(authority.generation) \
			or str(staged_commit.parent_id) != str(authority_commit.id):
			return _commit_result(false, &"unsafe_transaction_parent")
	var encoded := JSON.stringify(staged).to_utf8_buffer()
	var moved_primary := false
	if bool(primary.valid):
		if _filesystem.file_exists(_backup_path()):
			var remove_backup_error: Error = _filesystem.remove_path(_backup_path())
			if remove_backup_error != OK:
				return _commit_result(false, &"backup_cleanup_failed")
		var backup_error: Error = _filesystem.rename_path(_path, _backup_path())
		if backup_error != OK:
			return _commit_result(false, &"backup_publication_failed")
		moved_primary = true
	var publish_error: Error = _filesystem.rename_path(_temp_path(), _path)
	if publish_error != OK:
		if moved_primary and not _filesystem.file_exists(_path):
			_filesystem.rename_path(_backup_path(), _path)
		return _commit_result(false, &"atomic_replace_failed")
	var published := _read_document(_path)
	if not bool(published.valid) or (published.document as Dictionary) != staged:
		if _filesystem.file_exists(_path):
			_filesystem.remove_path(_path)
		if moved_primary and _filesystem.file_exists(_backup_path()):
			_filesystem.rename_path(_backup_path(), _path)
		# Keep the staged bytes available for another explicit attempt even when
		# publication verification fails after rotating the old authority.
		_filesystem.write_bytes_and_flush(_temp_path(), encoded)
		return _commit_result(false, &"published_verification_failed")
	_install_document(published.document as Dictionary, &"primary")
	return _commit_result(true, &"recovered")


## Explicitly restores a verified backup to a missing or corrupt primary. A
## corrupt primary is quarantined as the temporary sibling so its bytes remain
## available; valid or newer authorities are never overwritten.
func restore_backup_to_primary() -> Dictionary:
	if _path.is_empty():
		return _commit_result(false, &"invalid_path")
	for collision_path in [_path, _temp_path(), _backup_path()]:
		if _filesystem.directory_exists(collision_path):
			return _commit_result(false, &"transaction_path_is_directory")
	var primary := _read_document(_path)
	var temporary := _read_document(_temp_path())
	var backup := _read_document(_backup_path())
	if _has_newer_schema([primary, temporary, backup]):
		return _commit_result(false, &"newer_schema")
	if not bool(backup.valid):
		return _commit_result(false, &"no_valid_backup")
	if bool(primary.valid):
		return _commit_result(false, &"primary_valid")
	if bool(temporary.exists):
		return _commit_result(false, &"temporary_exists")
	var backup_read := _filesystem.read_bytes(_backup_path(), MAX_DOCUMENT_BYTES)
	if int(backup_read.get("error", FAILED)) != OK:
		return _commit_result(false, &"backup_read_failed")
	var backup_bytes := backup_read.get("bytes", PackedByteArray()) as PackedByteArray
	if backup_bytes.is_empty() or backup_bytes.size() > MAX_DOCUMENT_BYTES:
		return _commit_result(false, &"backup_read_failed")
	var primary_bytes := PackedByteArray()
	if bool(primary.exists):
		var primary_read := _filesystem.read_bytes(_path, MAX_DOCUMENT_BYTES)
		if int(primary_read.get("error", FAILED)) != OK:
			return _commit_result(false, &"primary_quarantine_failed")
		primary_bytes = primary_read.get("bytes", PackedByteArray()) as PackedByteArray
		if primary_bytes.is_empty():
			return _commit_result(false, &"primary_quarantine_failed")
		var quarantine_error: Error = _filesystem.write_bytes_and_flush(_temp_path(), primary_bytes)
		if quarantine_error != OK:
			return _commit_result(false, &"primary_quarantine_failed")
		var staged_quarantine := _filesystem.read_bytes(_temp_path(), MAX_DOCUMENT_BYTES)
		if int(staged_quarantine.get("error", FAILED)) != OK \
			or (staged_quarantine.get("bytes", PackedByteArray()) as PackedByteArray) != primary_bytes:
			return _commit_result(false, &"primary_quarantine_failed")
		var remove_error: Error = _filesystem.remove_path(_path)
		if remove_error != OK:
			return _commit_result(false, &"primary_quarantine_failed")
	var publish_error: Error = _filesystem.write_bytes_and_flush(_path, backup_bytes)
	if publish_error != OK:
		return _commit_result(false, &"primary_restore_failed")
	var restored := _read_document(_path)
	if not bool(restored.valid) or (restored.document as Dictionary) != (backup.document as Dictionary):
		return _commit_result(false, &"primary_restore_failed")
	_install_document(restored.document as Dictionary, &"primary")
	return _commit_result(true, &"backup_restored")


## Explicitly discards a verified interrupted transaction so a caller can
## re-enter from the published primary/backup state. Normal load and commit
## never take this destructive step implicitly.
func discard_interrupted_transaction() -> Dictionary:
	if _path.is_empty():
		return _commit_result(false, &"invalid_path")
	for collision_path in [_path, _temp_path(), _backup_path()]:
		if _filesystem.directory_exists(collision_path):
			return _commit_result(false, &"transaction_path_is_directory")
	var primary := _read_document(_path)
	var temporary := _read_document(_temp_path())
	var backup := _read_document(_backup_path())
	if _has_newer_schema([primary, temporary, backup]):
		return _commit_result(false, &"newer_schema")
	if not bool(temporary.valid):
		return _commit_result(false, &"no_interrupted_transaction")
	if (bool(primary.exists) and not bool(primary.valid)) or (bool(backup.exists) and not bool(backup.valid)):
		return _commit_result(false, &"unsafe_authority")
	if bool(primary.valid) and bool(backup.valid) and not _documents_form_chain(
		primary.document as Dictionary, backup.document as Dictionary
	):
		return _commit_result(false, &"incoherent_primary_backup")
	var remove_error: Error = _filesystem.remove_path(_temp_path())
	if remove_error != OK:
		return _commit_result(false, &"transaction_discard_failed")
	return _commit_result(true, &"discarded")


## Commits only against the generation most recently returned by load/commit.
## The caller supplies a stable commit ID; no wall-clock value enters the file.
func commit(payload: Variant, expected_generation: int, commit_id: String) -> Dictionary:
	if not _loaded:
		return _commit_result(false, &"not_loaded")
	if expected_generation != _generation:
		return _commit_result(false, &"stale_generation")
	if _generation >= MAX_GENERATION:
		return _commit_result(false, &"generation_exhausted")
	if not _valid_commit_id(commit_id) or commit_id == str(_commit_metadata.get("id", "")):
		return _commit_result(false, &"invalid_commit_id")
	var payload_validation := validate_payload(payload)
	if not bool(payload_validation.valid):
		return _commit_result(false, &"invalid_payload", payload_validation.errors)
	if _path.is_empty():
		return _commit_result(false, &"invalid_path")
	for collision_path in [_temp_path(), _backup_path()]:
		if _filesystem.directory_exists(collision_path):
			return _commit_result(false, &"transaction_path_is_directory")

	# Inspect every artifact before deleting a stale sibling. An older build must
	# never erase a document or interrupted transaction from a newer schema.
	var current_primary := _read_document(_path)
	var current_temporary := _read_document(_temp_path())
	var current_backup := _read_document(_backup_path())
	if _has_newer_schema([current_primary, current_temporary, current_backup]):
		return _commit_result(false, &"newer_schema")
	if bool(current_temporary.valid):
		return _commit_result(false, &"interrupted_transaction")
	if bool(current_primary.valid) and bool(current_backup.valid) and not _documents_form_chain(
		current_primary.document as Dictionary, current_backup.document as Dictionary
	):
		return _commit_result(false, &"authority_changed")
	if not _authority_matches_loaded_state(current_primary, current_backup):
		return _commit_result(false, &"authority_changed")
	if _filesystem.file_exists(_temp_path()):
		var stale_cleanup: Error = _filesystem.remove_path(_temp_path())
		if stale_cleanup != OK:
			return _commit_result(false, &"stale_temp_cleanup_failed")

	var canonical_payload: Variant = _canonicalize(payload)
	var payload_json := JSON.stringify(canonical_payload)
	var next_generation := _generation + 1
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"generation": next_generation,
		"commit": {
			"id": commit_id,
			"parent_generation": _generation,
			"parent_id": str(_commit_metadata.get("id", "")),
			"payload_sha256": payload_json.sha256_text(),
		},
		"payload": canonical_payload,
	}
	var encoded := JSON.stringify(envelope).to_utf8_buffer()
	if encoded.size() > MAX_DOCUMENT_BYTES:
		return _commit_result(false, &"document_too_large")
	var intended_parser := JSON.new()
	if intended_parser.parse(encoded.get_string_from_utf8()) != OK or not intended_parser.data is Dictionary:
		return _commit_result(false, &"internal_serialization_failed")
	var intended_document := intended_parser.data as Dictionary
	var directory_error: Error = _filesystem.ensure_parent_directory(_path)
	if directory_error != OK:
		return _commit_result(false, &"parent_directory_failed")
	var write_error: Error = _filesystem.write_bytes_and_flush(_temp_path(), encoded)
	if write_error != OK:
		_cleanup_temp_best_effort()
		return _commit_result(false, &"temp_write_failed")
	var staged := _read_document(_temp_path())
	if not bool(staged.valid) or (staged.document as Dictionary) != intended_document:
		_cleanup_temp_best_effort()
		return _commit_result(false, &"temp_verification_failed")
	# Staging may yield to the OS. Re-read the exact authority immediately before
	# rotation so a same-generation/different-commit writer is not overwritten.
	current_primary = _read_document(_path)
	current_backup = _read_document(_backup_path())
	if _has_newer_schema([current_primary, current_backup]) \
		or not _authority_matches_loaded_state(current_primary, current_backup) \
		or (
			bool(current_primary.valid)
			and bool(current_backup.valid)
			and not _documents_form_chain(
				current_primary.document as Dictionary, current_backup.document as Dictionary
			)
		):
		_cleanup_temp_best_effort()
		return _commit_result(false, &"authority_changed_during_staging")

	var moved_primary := false
	var backup_is_authority := _loaded_from == &"backup" and bool(current_backup.valid)
	if bool(current_primary.valid):
		if _filesystem.file_exists(_backup_path()):
			var backup_cleanup: Error = _filesystem.remove_path(_backup_path())
			if backup_cleanup != OK:
				_cleanup_temp_best_effort()
				return _commit_result(false, &"backup_cleanup_failed")
		var backup_error: Error = _filesystem.rename_path(_path, _backup_path())
		if backup_error != OK:
			_cleanup_temp_best_effort()
			return _commit_result(false, &"backup_publication_failed")
		moved_primary = true
	elif bool(current_primary.exists):
		# A caller explicitly committing after loading the backup may replace a
		# corrupt old primary, while retaining that verified backup as authority.
		var corrupt_cleanup: Error = _filesystem.remove_path(_path)
		if corrupt_cleanup != OK:
			_cleanup_temp_best_effort()
			return _commit_result(false, &"corrupt_primary_cleanup_failed")
	var publish_error: Error = _filesystem.rename_path(_temp_path(), _path)
	if publish_error != OK:
		var rollback_error: Error = OK
		var rollback_restored := not moved_primary and not backup_is_authority
		if (moved_primary or backup_is_authority) and not _filesystem.file_exists(_path):
			rollback_error = _filesystem.rename_path(_backup_path(), _path)
			rollback_restored = rollback_error == OK
		_cleanup_temp_best_effort()
		return _commit_result(false, &"atomic_replace_failed", PackedStringArray(), {
			"rollback_restored": rollback_restored,
			"rollback_error": rollback_error,
		})
	var published := _read_document(_path)
	if not bool(published.valid) or (published.document as Dictionary) != intended_document:
		var rollback := _restore_backup_after_bad_publish(moved_primary or backup_is_authority)
		return _commit_result(false, &"published_verification_failed", PackedStringArray(), rollback)
	# Install the parsed wire representation so commit and later load expose the
	# same JSON number variants (Godot decodes JSON numbers as floats).
	_install_document(published.document as Dictionary, &"primary")
	return _commit_result(true, &"committed")


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_generation() -> int:
	return _generation


func get_commit_metadata() -> Dictionary:
	return _commit_metadata.duplicate(true)


func get_loaded_source() -> StringName:
	return _loaded_from


static func validate_payload(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return {"valid": false, "errors": PackedStringArray(["payload must be a Dictionary"])}
	var budget := {"entries": 0}
	var errors := PackedStringArray()
	_validate_json_value(payload, 0, budget, errors, "payload")
	return {"valid": errors.is_empty(), "errors": errors}


static func validate_envelope(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		return PackedStringArray(["envelope must be a Dictionary"])
	var envelope := candidate as Dictionary
	_require_exact_keys(envelope, _ENVELOPE_KEYS, "envelope", errors)
	if not _is_integral_json_number(envelope.get("schema_version")):
		errors.append("schema_version must be an integral number")
	elif int(envelope.schema_version) != SCHEMA_VERSION:
		errors.append("schema_version is unsupported")
	if not _is_integral_json_number(envelope.get("generation")) \
		or int(envelope.get("generation", 0)) < 1 \
		or int(envelope.get("generation", 0)) > MAX_GENERATION:
		errors.append("generation is invalid")
	if not envelope.get("commit") is Dictionary:
		errors.append("commit must be a Dictionary")
	else:
		_validate_commit_metadata(envelope.get("commit") as Dictionary, int(envelope.get("generation", 0)), errors)
	var payload_validation: Dictionary = validate_payload(envelope.get("payload"))
	for payload_error in payload_validation.errors:
		errors.append(payload_error)
	if errors.is_empty():
		var canonical_payload: Variant = _canonicalize(envelope.payload)
		var expected_hash := JSON.stringify(canonical_payload).sha256_text()
		if str((envelope.commit as Dictionary).payload_sha256) != expected_hash:
			errors.append("payload_sha256 does not match payload")
	return errors


func _read_document(path: String) -> Dictionary:
	if _filesystem.directory_exists(path):
		return {"exists": true, "valid": false, "reason": "path_is_directory", "document": {}}
	if not _filesystem.file_exists(path):
		return {"exists": false, "valid": false, "reason": "missing", "document": {}}
	var read: Dictionary = _filesystem.read_bytes(path, MAX_DOCUMENT_BYTES)
	if int(read.get("error", FAILED)) != OK:
		return {"exists": true, "valid": false, "reason": "read_failed", "document": {}}
	var bytes := read.get("bytes", PackedByteArray()) as PackedByteArray
	if bytes.is_empty() or bytes.size() > MAX_DOCUMENT_BYTES:
		return {"exists": true, "valid": false, "reason": "invalid_size", "document": {}}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"exists": true, "valid": false, "reason": "invalid_utf8", "document": {}}
	if not _json_nesting_within_limit(text):
		return {"exists": true, "valid": false, "reason": "depth_exceeded", "document": {}}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"exists": true, "valid": false, "reason": "invalid_json", "document": {}}
	var parsed: Variant = parser.data
	if parsed is Dictionary and _is_integral_json_number((parsed as Dictionary).get("schema_version")) \
		and int((parsed as Dictionary).get("schema_version")) > SCHEMA_VERSION:
		return {"exists": true, "valid": false, "reason": "newer_schema", "document": {}}
	var errors := validate_envelope(parsed)
	if not errors.is_empty():
		return {
			"exists": true,
			"valid": false,
			"reason": "invalid_schema",
			"errors": errors,
			"document": {},
		}
	return {"exists": true, "valid": true, "reason": "ok", "document": parsed}


func _install_document(document: Dictionary, source: StringName) -> void:
	_loaded = true
	_generation = int(document.generation)
	_commit_metadata = (document.commit as Dictionary).duplicate(true)
	_snapshot = (document.payload as Dictionary).duplicate(true)
	_loaded_from = source


func _load_result(
		accepted: bool,
		reason: StringName,
		source: StringName,
		primary: Dictionary,
		backup: Dictionary
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"source": source,
		"generation": _generation,
		"commit": _commit_metadata.duplicate(true),
		"payload": _snapshot.duplicate(true),
		"primary_status": str(primary.get("reason", "unchecked")),
		"backup_status": str(backup.get("reason", "unchecked")),
	}


func _commit_result(
		accepted: bool,
		reason: StringName,
		errors: PackedStringArray = PackedStringArray(),
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"commit": _commit_metadata.duplicate(true),
		"payload": _snapshot.duplicate(true),
		"errors": errors.duplicate(),
	}
	result.merge(details, true)
	return result


func _state_record() -> Dictionary:
	return {
		"loaded": _loaded,
		"generation": _generation,
		"commit": _commit_metadata.duplicate(true),
		"snapshot": _snapshot.duplicate(true),
		"source": _loaded_from,
	}


func _restore_state(state: Dictionary) -> void:
	_loaded = bool(state.loaded)
	_generation = int(state.generation)
	_commit_metadata = (state.commit as Dictionary).duplicate(true)
	_snapshot = (state.snapshot as Dictionary).duplicate(true)
	_loaded_from = StringName(state.source)


func _authority_matches_loaded_state(primary: Dictionary, backup: Dictionary) -> bool:
	match _loaded_from:
		&"empty":
			return not bool(primary.exists) and not bool(backup.exists)
		&"primary":
			return bool(primary.valid) and _document_matches_loaded(primary.document as Dictionary)
		&"backup":
			return (
				not bool(primary.valid)
				and str(primary.reason) != "newer_schema"
				and bool(backup.valid)
				and _document_matches_loaded(backup.document as Dictionary)
			)
	return false


func _document_matches_loaded(document: Dictionary) -> bool:
	return (
		int(document.get("generation", -1)) == _generation
		and (document.get("commit", {}) as Dictionary) == _commit_metadata
		and (document.get("payload", {}) as Dictionary) == _snapshot
	)


static func _has_newer_schema(records: Array) -> bool:
	for record_variant in records:
		var record := record_variant as Dictionary
		if str(record.get("reason", "")) == "newer_schema":
			return true
	return false


static func _documents_form_chain(primary: Dictionary, backup: Dictionary) -> bool:
	var primary_commit := primary.get("commit", {}) as Dictionary
	var backup_commit := backup.get("commit", {}) as Dictionary
	return (
		int(primary.get("generation", -1)) == int(backup.get("generation", -1)) + 1
		and int(primary_commit.get("parent_generation", -1)) == int(backup.get("generation", -1))
		and str(primary_commit.get("parent_id", "")) == str(backup_commit.get("id", ""))
	)


func _cleanup_temp_best_effort() -> void:
	if _filesystem.file_exists(_temp_path()) and not _filesystem.directory_exists(_temp_path()):
		_filesystem.remove_path(_temp_path())


func _restore_backup_after_bad_publish(had_backup: bool) -> Dictionary:
	if not had_backup or not _filesystem.file_exists(_backup_path()):
		return {"rollback_restored": false, "rollback_error": ERR_FILE_NOT_FOUND}
	if _filesystem.file_exists(_path) and not _filesystem.directory_exists(_path):
		var remove_error: Error = _filesystem.remove_path(_path)
		if remove_error != OK:
			return {"rollback_restored": false, "rollback_error": remove_error}
	if not _filesystem.file_exists(_path):
		var rollback_error: Error = _filesystem.rename_path(_backup_path(), _path)
		return {"rollback_restored": rollback_error == OK, "rollback_error": rollback_error}
	return {"rollback_restored": false, "rollback_error": ERR_ALREADY_EXISTS}


func _temp_path() -> String:
	return _path + _TEMP_SUFFIX


func _backup_path() -> String:
	return _path + _BACKUP_SUFFIX


static func _valid_commit_id(commit_id: String) -> bool:
	var size := commit_id.to_utf8_buffer().size()
	if commit_id.strip_edges() != commit_id or size < 1 or size > MAX_COMMIT_ID_BYTES:
		return false
	for character in commit_id:
		var code := character.unicode_at(0)
		if code < 33 or code > 126:
			return false
	return true


static func _validate_commit_metadata(metadata: Dictionary, generation: int, errors: PackedStringArray) -> void:
	_require_exact_keys(metadata, _COMMIT_KEYS, "commit", errors)
	if not metadata.get("id") is String or not _valid_commit_id(str(metadata.get("id", ""))):
		errors.append("commit.id is invalid")
	if not _is_integral_json_number(metadata.get("parent_generation")) \
		or int(metadata.get("parent_generation", -1)) != generation - 1:
		errors.append("commit.parent_generation does not precede generation")
	if not metadata.get("parent_id") is String:
		errors.append("commit.parent_id must be a String")
	elif generation == 1 and not str(metadata.parent_id).is_empty():
		errors.append("first commit parent_id must be empty")
	elif generation > 1 and not _valid_commit_id(str(metadata.parent_id)):
		errors.append("later commit parent_id is invalid")
	if not metadata.get("payload_sha256") is String \
		or not _is_lower_hex_digest(str(metadata.get("payload_sha256", ""))):
		errors.append("commit.payload_sha256 is invalid")


static func _require_exact_keys(
		dictionary: Dictionary,
		allowed: Array,
		label: String,
		errors: PackedStringArray
	) -> void:
	for key in allowed:
		if not dictionary.has(key):
			errors.append("%s.%s is required" % [label, key])
	var unknown_fields: Array[String] = []
	for key in dictionary:
		if not key is String or not allowed.has(key):
			unknown_fields.append(str(key))
	unknown_fields.sort()
	for field in unknown_fields:
		errors.append("%s contains unknown field %s" % [label, field])


static func _validate_json_value(
		value: Variant,
		depth: int,
		budget: Dictionary,
		errors: PackedStringArray,
		path: String
	) -> void:
	if not errors.is_empty():
		return
	if depth > MAX_PAYLOAD_DEPTH:
		errors.append("payload exceeds maximum depth at %s" % path)
		return
	match typeof(value):
		TYPE_NIL, TYPE_BOOL:
			budget.entries = int(budget.entries) + 1
		TYPE_INT:
			budget.entries = int(budget.entries) + 1
			if absi(int(value)) > MAX_SAFE_JSON_INTEGER:
				errors.append("integer exceeds JSON-safe range at %s" % path)
		TYPE_FLOAT:
			budget.entries = int(budget.entries) + 1
			if is_nan(float(value)) or is_inf(float(value)):
				errors.append("non-finite number at %s" % path)
		TYPE_STRING:
			budget.entries = int(budget.entries) + 1
			if (value as String).to_utf8_buffer().size() > MAX_STRING_BYTES:
				errors.append("string exceeds maximum bytes at %s" % path)
		TYPE_ARRAY:
			budget.entries = int(budget.entries) + 1
			for index in (value as Array).size():
				_validate_json_value((value as Array)[index], depth + 1, budget, errors, "%s[%d]" % [path, index])
				if not errors.is_empty():
					return
		TYPE_DICTIONARY:
			budget.entries = int(budget.entries) + 1
			var keys := (value as Dictionary).keys()
			for key in keys:
				if not key is String or (key as String).is_empty():
					errors.append("dictionary key must be a nonempty String at %s" % path)
					return
			keys.sort()
			for key in keys:
				if (key as String).to_utf8_buffer().size() > MAX_KEY_BYTES:
					errors.append("dictionary key exceeds maximum bytes at %s" % path)
					return
				budget.entries = int(budget.entries) + 1
				_validate_json_value((value as Dictionary)[key], depth + 1, budget, errors, "%s.%s" % [path, key])
				if not errors.is_empty():
					return
		_:
			errors.append("unsupported JSON type at %s" % path)
	if int(budget.entries) > MAX_TOTAL_ENTRIES and errors.is_empty():
		errors.append("payload exceeds maximum entries")


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys := (value as Dictionary).keys()
		keys.sort()
		for key in keys:
			result[key] = _canonicalize((value as Dictionary)[key])
		return result
	if value is Array:
		var result := []
		for entry in value as Array:
			result.append(_canonicalize(entry))
		return result
	if value is int:
		# JSON.parse() represents every JSON number as a float. Normalizing before
		# hashing makes integer-bearing payloads stable across write/read cycles.
		return float(value)
	return value


static func _json_nesting_within_limit(text: String) -> bool:
	var depth := 0
	var in_string := false
	var escaped := false
	for character in text:
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			continue
		if character == "\"":
			in_string = true
		elif character == "{" or character == "[":
			depth += 1
			if depth > MAX_DOCUMENT_NESTING:
				return false
		elif character == "}" or character == "]":
			depth -= 1
			if depth < 0:
				return false
	return depth == 0 and not in_string


static func _is_lower_hex_digest(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func _is_integral_json_number(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return (
		not is_nan(number)
		and not is_inf(number)
		and number == floor(number)
		and absf(number) <= MAX_SAFE_JSON_INTEGER
	)
