extends SceneTree

const Store := preload("res://scripts/persistence/user_data_store.gd")

const PATH := "memory://profile.json"

var _failures := PackedStringArray()
var _assertions := 0


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var directories: Dictionary = {}
	var fail_write_once := false
	var partial_write_on_failure := false
	var rename_failures: Dictionary = {}
	var remove_failures: Dictionary = {}
	var read_failures: Dictionary = {}
	var corrupt_on_rename_to := ""
	var replace_path_after_write := ""
	var replacement_bytes_after_write := PackedByteArray()

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(path: String) -> bool:
		return bool(directories.get(path, false))

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if int(read_failures.get(path, 0)) > 0:
			read_failures[path] = int(read_failures[path]) - 1
			return {"error": ERR_FILE_CANT_READ, "bytes": PackedByteArray()}
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_write_once:
			fail_write_once = false
			if partial_write_on_failure:
				files[path] = bytes.slice(0, maxi(1, bytes.size() / 2))
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		if not replace_path_after_write.is_empty():
			files[replace_path_after_write] = replacement_bytes_after_write.duplicate()
			replace_path_after_write = ""
			replacement_bytes_after_write = PackedByteArray()
		return OK

	func remove_path(path: String) -> Error:
		if int(remove_failures.get(path, 0)) > 0:
			remove_failures[path] = int(remove_failures[path]) - 1
			return ERR_CANT_CREATE
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		var pair := "%s->%s" % [from_path, to_path]
		if int(rename_failures.get(pair, 0)) > 0:
			rename_failures[pair] = int(rename_failures[pair]) - 1
			return ERR_CANT_CREATE
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		if to_path == corrupt_on_rename_to:
			files[to_path] = "{truncated".to_utf8_buffer()
			corrupt_on_rename_to = ""
		return OK

	func fail_rename_once(from_path: String, to_path: String) -> void:
		var pair := "%s->%s" % [from_path, to_path]
		rename_failures[pair] = int(rename_failures.get(pair, 0)) + 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_exact_commits_and_detached_snapshots()
	_test_primary_then_backup_recovery()
	_test_corrupt_and_both_invalid_behavior()
	_test_future_schema_and_unknown_fields()
	_test_stale_temp_and_interrupted_write()
	_test_valid_temp_blocks_recovery_and_overwrite()
	_test_explicit_interrupted_transaction_recovery()
	_test_explicit_backup_restoration()
	_test_explicit_interrupted_transaction_discard()
	_test_rename_rollback_and_cleanup_failures()
	_test_exact_authority_concurrency()
	_test_payload_and_document_bounds()
	_test_native_filesystem_round_trip()
	_finish()


func _test_exact_commits_and_detached_snapshots() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(PATH, filesystem)
	var empty := store.load()
	_check(bool(empty.accepted) and empty.reason == &"empty" and int(empty.generation) == 0, "missing files load as an explicit generation-zero store")
	var first := store.commit({"zeta": 7, "alpha": [true, "cargo"]}, 0, "commit-001")
	_check(bool(first.accepted) and first.reason == &"committed" and int(first.generation) == 1, "first commit advances exactly from generation zero to one")
	_check(
		first.commit.id == "commit-001"
		and int(first.commit.parent_generation) == 0
		and first.commit.parent_id == ""
		and str(first.commit.payload_sha256).length() == 64,
		"first commit metadata records exact identity parent and payload digest"
	)
	_check(float(first.payload.zeta) == 7.0, "integer payload data survives Godot JSON number normalization")
	var detached := first.payload as Dictionary
	detached.zeta = 999.0
	(first.commit as Dictionary).id = "mutated"
	_check(float(store.get_snapshot().zeta) == 7.0 and store.get_commit_metadata().id == "commit-001", "commit results and getters are deeply detached")

	var first_bytes := (filesystem.files[PATH] as PackedByteArray).duplicate()
	var stale := store.commit({"value": 2}, 0, "commit-stale")
	_check(not bool(stale.accepted) and stale.reason == &"stale_generation" and filesystem.files[PATH] == first_bytes, "stale generation rejection performs no write")
	var duplicate := store.commit({"value": 2}, 1, "commit-001")
	_check(not bool(duplicate.accepted) and duplicate.reason == &"invalid_commit_id" and filesystem.files[PATH] == first_bytes, "duplicate commit identity is rejected without mutation")

	var second := store.commit({"slot": {"credits": 12}}, 1, "commit-002")
	_check(bool(second.accepted) and int(second.generation) == 2, "second commit advances exactly one generation")
	_check(
		int(second.commit.parent_generation) == 1 and second.commit.parent_id == "commit-001",
		"second commit binds its exact parent generation and commit identity"
	)
	_check(filesystem.files.has(PATH + ".bak") and int(_decode(filesystem, PATH + ".bak").generation) == 1, "successful replacement retains the prior verified document as backup")

	var reordered_fs := FakeFilesystem.new()
	var reordered := Store.new(PATH, reordered_fs)
	reordered.load()
	reordered.commit({"alpha": [true, "cargo"], "zeta": 7}, 0, "commit-001")
	_check(reordered_fs.files[PATH] == first_bytes, "canonical key ordering produces deterministic bytes for equivalent payloads")


func _test_primary_then_backup_recovery() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _two_commit_store(filesystem)
	var reload := Store.new(PATH, filesystem)
	var primary := reload.load()
	_check(bool(primary.accepted) and primary.source == &"primary" and int(primary.generation) == 2, "a valid primary is chosen before its valid backup")
	var primary_result := primary as Dictionary
	(primary_result.payload as Dictionary).value = 999.0
	_check(float(reload.get_snapshot().value) == 2.0, "loaded payload results are deeply detached")

	filesystem.files[PATH] = "{truncated".to_utf8_buffer()
	var fallback := Store.new(PATH, filesystem)
	var recovered := fallback.load()
	_check(
		bool(recovered.accepted) and recovered.source == &"backup" and int(recovered.generation) == 1,
		"corrupt primary loads the valid last-known-good backup"
	)
	var repaired := fallback.commit({"value": 3}, 1, "commit-repair")
	_check(bool(repaired.accepted) and int(repaired.generation) == 2, "an explicit commit after backup load repairs a corrupt primary")
	_check(int(_decode(filesystem, PATH + ".bak").generation) == 1, "backup-based repair retains the last-known-good backup")
	_check(store.get_generation() == 2, "independent already-loaded instances are not mutated by recovery")


func _test_corrupt_and_both_invalid_behavior() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _two_commit_store(filesystem)
	filesystem.files[PATH] = "null".to_utf8_buffer()
	filesystem.files[PATH + ".bak"] = "[truncated".to_utf8_buffer()
	var failed := store.load()
	_check(not bool(failed.accepted) and failed.reason == &"no_valid_document", "corrupt primary and backup fail closed")
	_check(store.get_generation() == 2 and float(store.get_snapshot().value) == 2.0, "failed load preserves the prior in-memory snapshot exactly")

	var fresh := Store.new(PATH, filesystem)
	var fresh_failed := fresh.load()
	_check(not bool(fresh_failed.accepted) and fresh.get_generation() == 0 and fresh.get_snapshot().is_empty(), "both-invalid load cannot manufacture data in a fresh store")


func _test_future_schema_and_unknown_fields() -> void:
	var filesystem := FakeFilesystem.new()
	_two_commit_store(filesystem)
	var primary := _decode(filesystem, PATH)
	primary.schema_version = Store.SCHEMA_VERSION + 1
	filesystem.files[PATH] = JSON.stringify(primary).to_utf8_buffer()
	var frozen := _copy_files(filesystem.files)
	var future := Store.new(PATH, filesystem)
	var future_load := future.load()
	_check(not bool(future_load.accepted) and future_load.reason == &"newer_schema", "newer primary refuses fallback to an older supported backup")
	_check(filesystem.files == frozen, "newer primary plus older backup remain byte-for-byte untouched")

	# A future transaction artifact also blocks an older writer from deleting it.
	filesystem = FakeFilesystem.new()
	var live := _two_commit_store(filesystem)
	var future_temp := _decode(filesystem, PATH)
	future_temp.schema_version = Store.SCHEMA_VERSION + 1
	filesystem.files[PATH + ".tmp"] = JSON.stringify(future_temp).to_utf8_buffer()
	var future_temp_bytes := (filesystem.files[PATH + ".tmp"] as PackedByteArray).duplicate()
	var future_temp_load := Store.new(PATH, filesystem).load()
	_check(not bool(future_temp_load.accepted) and future_temp_load.reason == &"newer_schema" and filesystem.files[PATH + ".tmp"] == future_temp_bytes, "load also refuses and preserves a newer temporary artifact")
	var refused := live.commit({"value": 3}, 2, "commit-003")
	_check(not bool(refused.accepted) and refused.reason == &"newer_schema", "newer temporary artifact blocks an older commit")
	_check(filesystem.files[PATH + ".tmp"] == future_temp_bytes, "newer temporary artifact is preserved exactly")
	filesystem.files.erase(PATH + ".tmp")
	var future_backup := _decode(filesystem, PATH + ".bak")
	future_backup.schema_version = Store.SCHEMA_VERSION + 1
	filesystem.files[PATH + ".bak"] = JSON.stringify(future_backup).to_utf8_buffer()
	var backup_bytes := (filesystem.files[PATH + ".bak"] as PackedByteArray).duplicate()
	var future_backup_load := Store.new(PATH, filesystem).load()
	_check(not bool(future_backup_load.accepted) and future_backup_load.reason == &"newer_schema" and filesystem.files[PATH + ".bak"] == backup_bytes, "load also refuses and preserves a newer backup artifact")
	var backup_refused := live.commit({"value": 3}, 2, "commit-003")
	_check(not bool(backup_refused.accepted) and backup_refused.reason == &"newer_schema" and filesystem.files[PATH + ".bak"] == backup_bytes, "newer backup blocks mutation and is preserved exactly")

	filesystem = FakeFilesystem.new()
	var one := _one_commit_store(filesystem)
	var unknown := _decode(filesystem, PATH)
	unknown["unexpected"] = true
	filesystem.files[PATH] = JSON.stringify(unknown).to_utf8_buffer()
	var unknown_load := Store.new(PATH, filesystem).load()
	_check(not bool(unknown_load.accepted) and unknown_load.reason == &"no_valid_document", "unknown envelope fields fail closed")
	unknown.erase("unexpected")
	(unknown.commit as Dictionary)["unexpected"] = true
	filesystem.files[PATH] = JSON.stringify(unknown).to_utf8_buffer()
	_check(not bool(Store.new(PATH, filesystem).load().accepted), "unknown commit-metadata fields fail closed")
	_check(one.get_generation() == 1, "invalid disk mutations do not alter an already-loaded authority")


func _test_stale_temp_and_interrupted_write() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _one_commit_store(filesystem)
	filesystem.files[PATH + ".tmp"] = "{interrupted".to_utf8_buffer()
	var load_with_temp := Store.new(PATH, filesystem).load()
	_check(bool(load_with_temp.accepted) and load_with_temp.source == &"primary", "load ignores an interrupted stale temporary file")
	var committed := store.commit({"value": 2}, 1, "commit-002")
	_check(bool(committed.accepted) and not filesystem.files.has(PATH + ".tmp"), "next commit removes a stale temporary file before staging")

	var before := (filesystem.files[PATH] as PackedByteArray).duplicate()
	filesystem.fail_write_once = true
	filesystem.partial_write_on_failure = true
	var interrupted := store.commit({"value": 3}, 2, "commit-003")
	_check(not bool(interrupted.accepted) and interrupted.reason == &"temp_write_failed", "partial temporary write fails the transaction")
	_check(filesystem.files[PATH] == before and not filesystem.files.has(PATH + ".tmp"), "interrupted write preserves primary bytes and cleans partial temp residue")

	filesystem.read_failures[PATH + ".tmp"] = 1
	var unreadable_stage := store.commit({"value": 3}, 2, "commit-003")
	_check(not bool(unreadable_stage.accepted) and unreadable_stage.reason == &"temp_verification_failed" and not filesystem.files.has(PATH + ".tmp"), "failed staged re-read preserves authority and cleans verified-temp residue")


func _test_valid_temp_blocks_recovery_and_overwrite() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _one_commit_store(filesystem)
	var primary_bytes := (filesystem.files[PATH] as PackedByteArray).duplicate()
	filesystem.files[PATH + ".tmp"] = primary_bytes.duplicate()
	var temp_bytes := (filesystem.files[PATH + ".tmp"] as PackedByteArray).duplicate()

	var blocked_load := Store.new(PATH, filesystem).load()
	_check(
		not bool(blocked_load.accepted) and blocked_load.reason == &"interrupted_transaction",
		"a valid temporary transaction fails closed instead of being treated as stale or empty"
	)
	_check(
		filesystem.files[PATH] == primary_bytes and filesystem.files[PATH + ".tmp"] == temp_bytes,
		"failed interrupted-transaction recovery preserves primary and temporary bytes"
	)

	var blocked_commit := store.commit({"value": 2}, 1, "commit-002")
	_check(
		not bool(blocked_commit.accepted) and blocked_commit.reason == &"interrupted_transaction",
		"a loaded writer cannot overwrite a valid interrupted transaction"
	)
	_check(
		filesystem.files[PATH] == primary_bytes and filesystem.files[PATH + ".tmp"] == temp_bytes,
		"interrupted-transaction commit rejection performs no mutation"
	)


func _test_explicit_interrupted_transaction_recovery() -> void:
	var filesystem := FakeFilesystem.new()
	_one_commit_store(filesystem)
	var staged_fs := FakeFilesystem.new()
	_two_commit_store(staged_fs)
	filesystem.files[PATH + ".tmp"] = (staged_fs.files[PATH] as PackedByteArray).duplicate()
	var blocked := Store.new(PATH, filesystem)
	var blocked_load := blocked.load()
	_check(not bool(blocked_load.accepted) and blocked_load.reason == &"interrupted_transaction", "explicit recovery starts from fail-closed load")
	var recovered := blocked.recover_interrupted_transaction()
	_check(bool(recovered.accepted) and recovered.reason == &"recovered" and int(recovered.generation) == 2, "explicit recovery promotes only a verified next transaction")
	_check(float(blocked.get_snapshot().value) == 2.0 and not filesystem.files.has(PATH + ".tmp"), "recovered transaction installs its payload and clears the stage")
	_check(int(_decode(filesystem, PATH + ".bak").generation) == 1, "recovery retains the prior primary as backup")

	var unsafe_fs := FakeFilesystem.new()
	_one_commit_store(unsafe_fs)
	var unsafe_source_fs := FakeFilesystem.new()
	_two_commit_store(unsafe_source_fs)
	var unsafe_temp := _decode(unsafe_source_fs, PATH)
	unsafe_temp.generation = 3
	(unsafe_temp.commit as Dictionary).parent_generation = 2
	unsafe_fs.files[PATH + ".tmp"] = JSON.stringify(unsafe_temp).to_utf8_buffer()
	var unsafe_before := _copy_files(unsafe_fs.files)
	var unsafe := Store.new(PATH, unsafe_fs)
	unsafe.load()
	var refused := unsafe.recover_interrupted_transaction()
	_check(not bool(refused.accepted) and refused.reason == &"unsafe_transaction_parent" and unsafe_fs.files == unsafe_before, "recovery rejects a staged document with an unsafe parent without mutation")


func _test_explicit_backup_restoration() -> void:
	var filesystem := FakeFilesystem.new()
	_two_commit_store(filesystem)
	var backup_bytes := (filesystem.files[PATH + ".bak"] as PackedByteArray).duplicate()
	filesystem.files.erase(PATH)
	var missing := Store.new(PATH, filesystem)
	_check(bool(missing.load().accepted) and missing.get_loaded_source() == &"backup", "missing primary loads the verified backup before explicit restoration")
	var restored := missing.restore_backup_to_primary()
	_check(bool(restored.accepted) and restored.reason == &"backup_restored" and missing.get_loaded_source() == &"primary", "explicit restoration publishes the verified backup as primary")
	_check(filesystem.files[PATH] == backup_bytes and filesystem.files[PATH + ".bak"] == backup_bytes, "backup restoration preserves exact backup bytes and the backup copy")

	filesystem = FakeFilesystem.new()
	_two_commit_store(filesystem)
	var corrupt_bytes := "corrupt-primary".to_utf8_buffer()
	filesystem.files[PATH] = corrupt_bytes
	var corrupt := Store.new(PATH, filesystem)
	corrupt.load()
	var corrupt_restore := corrupt.restore_backup_to_primary()
	_check(bool(corrupt_restore.accepted) and corrupt_restore.reason == &"backup_restored", "explicit restoration repairs a corrupt primary")
	_check(filesystem.files[PATH] == backup_bytes and filesystem.files[PATH + ".tmp"] == corrupt_bytes, "corrupt primary bytes are quarantined instead of discarded")

	filesystem = FakeFilesystem.new()
	_two_commit_store(filesystem)
	var newer := _decode(filesystem, PATH)
	newer.schema_version = Store.SCHEMA_VERSION + 1
	filesystem.files[PATH] = JSON.stringify(newer).to_utf8_buffer()
	var frozen := _copy_files(filesystem.files)
	var newer_store := Store.new(PATH, filesystem)
	var newer_restore := newer_store.restore_backup_to_primary()
	_check(not bool(newer_restore.accepted) and newer_restore.reason == &"newer_schema" and filesystem.files == frozen, "newer primary blocks backup restoration without mutation")


func _test_explicit_interrupted_transaction_discard() -> void:
	var filesystem := FakeFilesystem.new()
	_one_commit_store(filesystem)
	var staged_fs := FakeFilesystem.new()
	_two_commit_store(staged_fs)
	var staged_bytes := (staged_fs.files[PATH] as PackedByteArray).duplicate()
	filesystem.files[PATH + ".tmp"] = staged_bytes
	var store := Store.new(PATH, filesystem)
	var blocked := store.load()
	_check(not bool(blocked.accepted) and blocked.reason == &"interrupted_transaction", "discard requires an explicitly failed-closed re-entry")
	var discarded := store.discard_interrupted_transaction()
	_check(bool(discarded.accepted) and discarded.reason == &"discarded" and not filesystem.files.has(PATH + ".tmp"), "explicit discard removes only the verified interrupted stage")
	var reloaded := store.load()
	_check(bool(reloaded.accepted) and reloaded.source == &"primary" and int(reloaded.generation) == 1, "discarded re-entry returns to the last published safe generation")

	filesystem = FakeFilesystem.new()
	_one_commit_store(filesystem)
	filesystem.files[PATH + ".tmp"] = staged_bytes
	var newer := _decode(filesystem, PATH)
	newer.schema_version = Store.SCHEMA_VERSION + 1
	filesystem.files[PATH] = JSON.stringify(newer).to_utf8_buffer()
	var frozen := _copy_files(filesystem.files)
	var refused := Store.new(PATH, filesystem).discard_interrupted_transaction()
	_check(not bool(refused.accepted) and refused.reason == &"newer_schema" and filesystem.files == frozen, "newer authority blocks explicit discard without mutation")


func _test_rename_rollback_and_cleanup_failures() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _one_commit_store(filesystem)
	var original := (filesystem.files[PATH] as PackedByteArray).duplicate()
	filesystem.fail_rename_once(PATH, PATH + ".bak")
	var rotate_failure := store.commit({"value": 2}, 1, "commit-002")
	_check(not bool(rotate_failure.accepted) and rotate_failure.reason == &"backup_publication_failed", "target-to-backup rename failure is surfaced")
	_check(filesystem.files[PATH] == original and not filesystem.files.has(PATH + ".tmp"), "failed backup rotation preserves primary and cleans staged temp")

	filesystem.fail_rename_once(PATH + ".tmp", PATH)
	var publish_failure := store.commit({"value": 2}, 1, "commit-002")
	_check(not bool(publish_failure.accepted) and publish_failure.reason == &"atomic_replace_failed" and bool(publish_failure.rollback_restored), "temp-to-target rename failure reports successful rollback")
	_check(filesystem.files[PATH] == original and not filesystem.files.has(PATH + ".tmp"), "successful rollback restores exact old primary bytes and cleans temp")

	filesystem.fail_rename_once(PATH + ".tmp", PATH)
	filesystem.fail_rename_once(PATH + ".bak", PATH)
	var rollback_failure := store.commit({"value": 2}, 1, "commit-002")
	_check(not bool(rollback_failure.accepted) and not bool(rollback_failure.rollback_restored) and int(rollback_failure.rollback_error) != OK, "rollback rename failure is explicitly surfaced")
	_check(not filesystem.files.has(PATH) and filesystem.files.has(PATH + ".bak") and not filesystem.files.has(PATH + ".tmp"), "failed rollback retains recoverable backup authority without temp ambiguity")
	var backup_load := Store.new(PATH, filesystem).load()
	_check(bool(backup_load.accepted) and backup_load.source == &"backup", "next load recovers authority from backup after rollback failure")

	filesystem = FakeFilesystem.new()
	store = _two_commit_store(filesystem)
	var current := (filesystem.files[PATH] as PackedByteArray).duplicate()
	var old_backup := (filesystem.files[PATH + ".bak"] as PackedByteArray).duplicate()
	filesystem.remove_failures[PATH + ".bak"] = 1
	var cleanup_failure := store.commit({"value": 3}, 2, "commit-003")
	_check(not bool(cleanup_failure.accepted) and cleanup_failure.reason == &"backup_cleanup_failed", "old-backup cleanup failure is surfaced before rotation")
	_check(filesystem.files[PATH] == current and filesystem.files[PATH + ".bak"] == old_backup and not filesystem.files.has(PATH + ".tmp"), "backup cleanup failure preserves both authorities and removes staged temp")

	filesystem = FakeFilesystem.new()
	store = _one_commit_store(filesystem)
	original = (filesystem.files[PATH] as PackedByteArray).duplicate()
	filesystem.corrupt_on_rename_to = PATH
	var corrupt_publish := store.commit({"value": 2}, 1, "commit-002")
	_check(not bool(corrupt_publish.accepted) and corrupt_publish.reason == &"published_verification_failed" and bool(corrupt_publish.rollback_restored), "post-publish corruption is detected and rollback status is reported")
	_check(filesystem.files[PATH] == original, "post-publish verification failure restores the exact prior primary")

	filesystem = FakeFilesystem.new()
	store = _two_commit_store(filesystem)
	filesystem.files[PATH] = "{corrupt".to_utf8_buffer()
	var backup_store := Store.new(PATH, filesystem)
	backup_store.load()
	filesystem.fail_rename_once(PATH + ".tmp", PATH)
	var repair_publish_failure := backup_store.commit({"value": 3}, 1, "commit-repair")
	_check(not bool(repair_publish_failure.accepted) and bool(repair_publish_failure.rollback_restored), "failed backup-based repair restores backup authority to the primary path")
	_check(filesystem.files.has(PATH) and int(_decode(filesystem, PATH).generation) == 1 and not filesystem.files.has(PATH + ".tmp"), "failed repair rollback leaves one canonical old generation and no temp")


func _test_exact_authority_concurrency() -> void:
	var filesystem := FakeFilesystem.new()
	var store := _two_commit_store(filesystem)
	var raced := _decode(filesystem, PATH)
	(raced.commit as Dictionary).id = "same-generation-racer"
	filesystem.files[PATH] = JSON.stringify(raced).to_utf8_buffer()
	var raced_bytes := (filesystem.files[PATH] as PackedByteArray).duplicate()
	var rejected := store.commit({"value": 3}, 2, "commit-003")
	_check(not bool(rejected.accepted) and rejected.reason == &"authority_changed", "same-generation different-commit race fails exact identity comparison")
	_check(filesystem.files[PATH] == raced_bytes and not filesystem.files.has(PATH + ".tmp"), "concurrency rejection performs no filesystem mutation")

	filesystem = FakeFilesystem.new()
	store = _two_commit_store(filesystem)
	raced = _decode(filesystem, PATH)
	(raced.commit as Dictionary).id = "staging-racer"
	var staging_race_bytes := JSON.stringify(raced).to_utf8_buffer()
	filesystem.replace_path_after_write = PATH
	filesystem.replacement_bytes_after_write = staging_race_bytes
	var staging_race := store.commit({"value": 3}, 2, "commit-003")
	_check(not bool(staging_race.accepted) and staging_race.reason == &"authority_changed_during_staging", "authority identity is rechecked immediately after staged verification")
	_check(filesystem.files[PATH] == staging_race_bytes and not filesystem.files.has(PATH + ".tmp"), "during-staging race preserves the competing canonical bytes and cleans temp")


func _test_payload_and_document_bounds() -> void:
	_check(not bool(Store.validate_payload({"bad": NAN}).valid), "non-finite payload numbers are rejected")
	_check(not bool(Store.validate_payload({"bad": Vector3.ONE}).valid), "non-JSON payload types are rejected")
	_check(not bool(Store.validate_payload({StringName("named"): true}).valid), "StringName payload keys are rejected instead of silently stringified")
	_check(not bool(Store.validate_payload({"": true}).valid), "empty payload keys are rejected")
	_check(not bool(Store.validate_payload({"x".repeat(Store.MAX_KEY_BYTES + 1): true}).valid), "oversized UTF-8 keys are rejected")
	_check(not bool(Store.validate_payload({"text": "x".repeat(Store.MAX_STRING_BYTES + 1)}).valid), "oversized strings are rejected")
	_check(not bool(Store.validate_payload({"integer": Store.MAX_SAFE_JSON_INTEGER + 1}).valid), "integers outside the interoperable JSON range are rejected")

	var schema_fs := FakeFilesystem.new()
	_one_commit_store(schema_fs)
	var original_document := _decode(schema_fs, PATH)
	var malformed := original_document.duplicate(true)
	malformed.schema_version = "1"
	schema_fs.files[PATH] = JSON.stringify(malformed).to_utf8_buffer()
	_check(not bool(Store.new(PATH, schema_fs).load().accepted), "string schema versions are rejected without coercion")
	malformed = original_document.duplicate(true)
	malformed.generation = 1.5
	schema_fs.files[PATH] = JSON.stringify(malformed).to_utf8_buffer()
	_check(not bool(Store.new(PATH, schema_fs).load().accepted), "fractional generations are rejected without rounding")
	malformed = original_document.duplicate(true)
	malformed.generation = float(Store.MAX_SAFE_JSON_INTEGER) + 2.0
	schema_fs.files[PATH] = JSON.stringify(malformed).to_utf8_buffer()
	_check(not bool(Store.new(PATH, schema_fs).load().accepted), "out-of-safe-range generation metadata is rejected")
	malformed = original_document.duplicate(true)
	(malformed.payload as Dictionary).value = 99.0
	schema_fs.files[PATH] = JSON.stringify(malformed).to_utf8_buffer()
	_check(not bool(Store.new(PATH, schema_fs).load().accepted), "payload hash mismatch is rejected")

	var deep := {}
	var cursor := deep
	for depth in Store.MAX_PAYLOAD_DEPTH + 1:
		cursor["next"] = {}
		cursor = cursor.next
	_check(not bool(Store.validate_payload(deep).valid), "payload depth is bounded before serialization")
	var many := {}
	for index in 2048:
		many["k%04d" % index] = index
	_check(not bool(Store.validate_payload(many).valid), "combined payload entries and keys are bounded")

	var filesystem := FakeFilesystem.new()
	var store := Store.new(PATH, filesystem)
	store.load()
	var large := {}
	for index in 65:
		large["chunk_%02d" % index] = "x".repeat(Store.MAX_STRING_BYTES)
	var too_large := store.commit(large, 0, "large-document")
	_check(not bool(too_large.accepted) and too_large.reason == &"document_too_large", "encoded document bytes are bounded before write")

	var nested_json := "{\"schema_version\":1,\"generation\":1,\"commit\":{},\"payload\":"
	nested_json += "[".repeat(Store.MAX_DOCUMENT_NESTING + 1)
	nested_json += "0"
	nested_json += "]".repeat(Store.MAX_DOCUMENT_NESTING + 1) + "}"
	filesystem.files[PATH] = nested_json.to_utf8_buffer()
	var nested_load := Store.new(PATH, filesystem).load()
	_check(not bool(nested_load.accepted) and nested_load.primary_status == "depth_exceeded", "raw document nesting is rejected before JSON parsing")


func _test_native_filesystem_round_trip() -> void:
	var path := "user://atomic_user_data_store_test_%d.json" % Time.get_ticks_usec()
	_cleanup_native(path)
	var store := Store.new(path)
	_check(bool(store.load().accepted), "native filesystem starts from an empty store")
	_check(bool(store.commit({"native": true, "count": 1}, 0, "native-001").accepted), "native filesystem writes flushes verifies and publishes first commit")
	_check(bool(store.commit({"native": true, "count": 2}, 1, "native-002").accepted), "native filesystem rotates and publishes second commit")
	var reload := Store.new(path)
	var loaded := reload.load()
	_check(bool(loaded.accepted) and int(loaded.generation) == 2 and float(loaded.payload.count) == 2.0, "native filesystem JSON reload returns the exact committed generation")
	_check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path + ".tmp"), "native transaction leaves primary plus last-known-good backup and no temp")
	_cleanup_native(path)


func _one_commit_store(filesystem: FakeFilesystem) -> UserDataStore:
	var store := Store.new(PATH, filesystem)
	store.load()
	store.commit({"value": 1}, 0, "commit-001")
	return store


func _two_commit_store(filesystem: FakeFilesystem) -> UserDataStore:
	var store := _one_commit_store(filesystem)
	store.commit({"value": 2}, 1, "commit-002")
	return store


func _decode(filesystem: FakeFilesystem, path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse((filesystem.files[path] as PackedByteArray).get_string_from_utf8()) != OK:
		return {}
	return parser.data as Dictionary


func _copy_files(files: Dictionary) -> Dictionary:
	var result := {}
	for path in files:
		result[path] = (files[path] as PackedByteArray).duplicate()
	return result


func _cleanup_native(path: String) -> void:
	for candidate in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("USER_DATA_STORE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("USER_DATA_STORE_TEST_FAILED: %d/%d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
