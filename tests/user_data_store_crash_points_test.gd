extends SceneTree

## Real-disk crash points for the shared settings/progress document. A process
## that dies at any step of a commit must leave a document the next launch can
## load and save again; an interrupted transaction must not strand the player on
## authored defaults with every later save refused.

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const UNSUPPORTED_MARKER := "SYNTHETIC_PRIVATE_FUTURE_SAVE_CONTENT_7fe092b1"
const UNSUPPORTED_CHILD_OK := "SAVE_UNSUPPORTED_CHILD_OK "
const UNSUPPORTED_CASES := ["primary", "temporary", "backup"]

var _failures := PackedStringArray()
var _assertions := 0
var _root := ""


## Real file I/O that "loses power" at one chosen rename: that rename and every
## later mutation are skipped, exactly as if the process had stopped there.
class CrashingFilesystem extends UserDataFilesystem:
	var crash_before_rename_to := ""
	var crash_after_write_to := ""
	var crashed := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if crashed:
			return ERR_UNAVAILABLE
		var error := super.write_bytes_and_flush(path, bytes)
		if path == crash_after_write_to:
			crashed = true
		return error

	func remove_path(path: String) -> Error:
		if crashed:
			return ERR_UNAVAILABLE
		return super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		if crashed or to_path == crash_before_rename_to:
			crashed = true
			return ERR_UNAVAILABLE
		return super.rename_path(from_path, to_path)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--save-unsupported-child" in OS.get_cmdline_user_args():
		_run_unsupported_child()
		return
	_root = "user://user_data_crash_points_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root))
	_test_crash_between_backup_and_publish_reloads_and_saves()
	_test_crash_after_staging_reloads_and_saves()
	_test_crash_during_first_ever_save_reloads_and_saves()
	_test_crash_during_commit_from_backup_reloads_and_saves()
	_test_crash_during_commit_from_rotated_copy_reloads_and_saves()
	_test_newer_history_survives_saving_and_crash_recovery()
	if _failures.is_empty():
		_test_unsupported_files_survive_two_processes()
	_finish()


func _store_path(label: String) -> String:
	return "%s/%s.json" % [_root, label]


func _settings_for(label: String) -> RuntimeSettings:
	return Settings.new("%s/%s_legacy.cfg" % [_root, label])


## Commits two real saves (so `.bak` exists), then attempts a third on a
## filesystem that stops at the requested step.
func _crash_third_save(label: String, crash_fs: CrashingFilesystem) -> void:
	var path := _store_path(label)
	var settings := _settings_for(label)
	var store := Store.new(path) as UserDataStore
	var adapter := Adapter.new(settings, store, settings.config_path)
	_check(bool(adapter.load().accepted), "%s: a fresh profile opens" % label)
	settings.camera_fov = 80.0
	_check(bool(adapter.save("settings-1").accepted), "%s: first save publishes" % label)
	settings.camera_fov = 90.0
	_check(bool(adapter.save("settings-2").accepted), "%s: second save publishes" % label)
	var crashing_store := Store.new(path, crash_fs) as UserDataStore
	var crashing_adapter := Adapter.new(settings, crashing_store, settings.config_path)
	settings.camera_fov = 100.0
	var interrupted := crashing_adapter.save("settings-3")
	_check(not bool(interrupted.accepted) and crash_fs.crashed, "%s: the third save stops mid-transaction" % label)


func _relaunch_expect_usable(label: String, expected_fov: float) -> void:
	var path := _store_path(label)
	var settings := _settings_for(label)
	var store := Store.new(path) as UserDataStore
	var adapter := Adapter.new(settings, store, settings.config_path)
	var loaded := adapter.load()
	_check(
		bool(loaded.accepted) and bool(loaded.applied),
		"%s: the next launch loads the saved settings (got %s / %s)"
			% [label, loaded.get("reason"), loaded.get("store_reason")]
	)
	_check(
		is_equal_approx(settings.camera_fov, expected_fov),
		"%s: the relaunch applies FOV %.0f (got %.1f)" % [label, expected_fov, settings.camera_fov]
	)
	settings.camera_fov = 70.0
	var saved := adapter.save("settings-after-relaunch")
	_check(
		bool(saved.accepted),
		"%s: settings save again after the relaunch (got %s / %s)"
			% [label, saved.get("reason"), saved.get("store_reason")]
	)
	var reopened_settings := _settings_for(label)
	var reopened := Adapter.new(reopened_settings, Store.new(path), reopened_settings.config_path).load()
	_check(
		bool(reopened.accepted) and is_equal_approx(reopened_settings.camera_fov, 70.0),
		"%s: the post-relaunch save survives another restart" % label
	)


func _test_crash_between_backup_and_publish_reloads_and_saves() -> void:
	var label := "backup_then_crash"
	var crash_fs := CrashingFilesystem.new()
	crash_fs.crash_before_rename_to = _store_path(label)
	_crash_third_save(label, crash_fs)
	_check(
		not FileAccess.file_exists(_store_path(label))
			and FileAccess.file_exists(_store_path(label) + ".tmp")
			and FileAccess.file_exists(_store_path(label) + ".bak"),
		"%s: disk holds only the staged save and the backup" % label
	)
	# The staged save was complete and verified; rolling it forward keeps it.
	_relaunch_expect_usable(label, 100.0)


func _test_crash_after_staging_reloads_and_saves() -> void:
	var label := "staged_then_crash"
	var crash_fs := CrashingFilesystem.new()
	crash_fs.crash_after_write_to = _store_path(label) + ".tmp"
	_crash_third_save(label, crash_fs)
	_check(
		FileAccess.file_exists(_store_path(label))
			and FileAccess.file_exists(_store_path(label) + ".tmp"),
		"%s: disk holds the published save beside a staged successor" % label
	)
	_relaunch_expect_usable(label, 100.0)


func _test_crash_during_first_ever_save_reloads_and_saves() -> void:
	var label := "first_save_crash"
	var path := _store_path(label)
	var settings := _settings_for(label)
	var crash_fs := CrashingFilesystem.new()
	crash_fs.crash_before_rename_to = path
	var adapter := Adapter.new(settings, Store.new(path, crash_fs), settings.config_path)
	_check(bool(adapter.load().accepted), "%s: a fresh profile opens" % label)
	settings.camera_fov = 95.0
	_check(not bool(adapter.save("settings-1").accepted) and crash_fs.crashed, "%s: the first save stops before publishing" % label)
	_relaunch_expect_usable(label, 95.0)


func _truncate(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	var bytes := file.get_buffer(file.get_length())
	file.close()
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() / 2))
	file.close()


## Loads a damaged profile from its fallback and commits the recovered payload
## (as the startup session record and the confirmed repair both do) on a
## filesystem that stops at the requested step.
func _crash_commit_from_fallback(label: String, crash_fs: CrashingFilesystem, expected_source_generation: int) -> void:
	var path := _store_path(label)
	var fallback := Store.new(path, crash_fs) as UserDataStore
	var loaded := fallback.load()
	_check(
		bool(loaded.accepted) and loaded.reason == &"primary_invalid_backup_loaded"
			and int(loaded.generation) == expected_source_generation,
		"%s: the damaged profile loads its fallback generation %d" % [label, expected_source_generation]
	)
	var committed := fallback.commit(fallback.get_snapshot(), fallback.get_generation(), "repair-from-fallback")
	_check(not bool(committed.accepted) and crash_fs.crashed, "%s: the fallback commit stops mid-transaction" % label)


func _test_crash_during_commit_from_backup_reloads_and_saves() -> void:
	var label := "backup_repair_crash"
	var crash_fs := CrashingFilesystem.new()
	crash_fs.crash_after_write_to = _store_path(label) + ".tmp"
	_crash_third_save_setup_only(label)
	_truncate(_store_path(label))
	_crash_commit_from_fallback(label, crash_fs, 1)
	_relaunch_expect_usable(label, 80.0)


func _test_crash_during_commit_from_rotated_copy_reloads_and_saves() -> void:
	var label := "history_repair_crash"
	var path := _store_path(label)
	_crash_third_save_setup_only(label)
	var settings := _settings_for(label)
	var adapter := Adapter.new(settings, Store.new(path), settings.config_path)
	adapter.load()
	settings.camera_fov = 110.0
	_check(bool(adapter.save("settings-3").accepted), "%s: a third save rotates the oldest backup" % label)
	_truncate(path)
	_truncate(path + ".bak")
	var crash_fs := CrashingFilesystem.new()
	crash_fs.crash_before_rename_to = path
	_crash_commit_from_fallback(label, crash_fs, 1)
	_relaunch_expect_usable(label, 80.0)


func _crash_third_save_setup_only(label: String) -> void:
	var path := _store_path(label)
	var settings := _settings_for(label)
	var adapter := Adapter.new(settings, Store.new(path), settings.config_path)
	_check(bool(adapter.load().accepted), "%s: a fresh profile opens" % label)
	settings.camera_fov = 80.0
	_check(bool(adapter.save("settings-1").accepted), "%s: first save publishes" % label)
	settings.camera_fov = 90.0
	_check(bool(adapter.save("settings-2").accepted), "%s: second save publishes" % label)


## An older executable can load a supported primary while an unsupported copy
## remains in history. Saving and rolling an interrupted save forward must keep
## that copy at its original path, including when it is the oldest rotation.
func _test_newer_history_survives_saving_and_crash_recovery() -> void:
	for history_index in [1, Store.HISTORY_DEPTH]:
		var path := _store_path("newer_history_%d" % history_index)
		var store := Store.new(path) as UserDataStore
		_check(bool(store.load().accepted), "newer history: a fresh profile opens")
		for generation in range(1, 6):
			var committed := store.commit(
				{"credits": generation * 100}, generation - 1, "history-%d" % generation
			)
			_check(bool(committed.accepted), "newer history: generation %d publishes" % generation)
		var unsupported_path := "%s.bak.%d" % [path, history_index]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(unsupported_path))
		document.schema_version = Store.SCHEMA_VERSION + 1
		var unsupported_bytes := JSON.stringify(document).to_utf8_buffer()
		_check(
			Filesystem.new().write_bytes_and_flush(unsupported_path, unsupported_bytes) == OK,
			"newer history: an unsupported archived document is on disk"
		)
		var original_history: Dictionary = {}
		for history_path in store.get_history_paths():
			original_history[history_path] = FileAccess.get_file_as_bytes(history_path)
		_check(bool(store.commit({"credits": 600}, 5, "history-6").accepted), "newer history: a supported current profile still saves")
		_check(
			_history_bytes_match(original_history),
			"newer history: ordinary saving preserves every archive path and byte (unsupported index %d)"
				% history_index
		)
		var crash_fs := CrashingFilesystem.new()
		crash_fs.crash_before_rename_to = path
		var crashing := Store.new(path, crash_fs) as UserDataStore
		_check(bool(crashing.load().accepted), "newer history: current authority reloads")
		_check(
			not bool(crashing.commit({"credits": 700}, 6, "history-7").accepted) and crash_fs.crashed,
			"newer history: the next save stops before publishing"
		)
		var recovered := Store.new(path) as UserDataStore
		_check(
			recovered.load().reason == &"interrupted_transaction"
				and bool(recovered.recover_interrupted_transaction().accepted),
			"newer history: the supported interrupted save rolls forward"
		)
		_check(
			_history_bytes_match(original_history),
			"newer history: crash recovery preserves every archive path and byte (unsupported index %d)"
				% history_index
		)
		_check(
			bool(recovered.load().accepted) and float(recovered.get_snapshot().credits) == 700.0,
			"newer history: the recovered current progress remains usable"
		)


func _history_bytes_match(expected: Dictionary) -> bool:
	for history_path in expected:
		if not FileAccess.file_exists(history_path) or FileAccess.get_file_as_bytes(history_path) != expected[history_path]:
			return false
	return true


## The retained authority and two genuinely fresh processes must all refuse a
## future outer envelope before any transaction or quarantine can touch disk.
func _test_unsupported_files_survive_two_processes() -> void:
	if not _unsupported_check(DisplayServer.get_name() == "headless"
			and AudioServer.get_driver_name() == "Dummy",
			"unsupported files: parent uses headless/Dummy"):
		return
	if OS.has_feature("windows"):
		print("UNSUPPORTED_FILES_UNIX_MODES_UNAVAILABLE: Windows; names and bytes remain checked")
	var nonce := Crypto.new().generate_random_bytes(16).hex_encode()
	var owned_root := _root.path_join("unsupported_" + nonce)
	if not _unsupported_check(DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(owned_root)) == OK,
			"unsupported files: create the owned fixture root"):
		return
	var owner := {"nonce": nonce, "parent_pid": OS.get_process_id()}
	if not _unsupported_check(Filesystem.new().write_bytes_and_flush(
			owned_root.path_join("owner.json"), JSON.stringify(owner).to_utf8_buffer()) == OK,
			"unsupported files: publish the child ownership guard"):
		return
	var snapshots := {}
	for label in UNSUPPORTED_CASES:
		var directory := owned_root.path_join(label)
		if not _unsupported_check(DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(directory)) == OK,
				"unsupported %s: create fixture directory" % label):
			return
		var path := directory.path_join("profile.json")
		var store := Store.new(path) as UserDataStore
		if not _unsupported_check(bool(store.load().accepted),
				"unsupported %s: real empty store loads" % label):
			return
		for generation in [1, 2]:
			if not _unsupported_check(bool(store.commit({"credits": generation * 100},
					generation - 1, "unsupported-seed-%d" % generation).accepted),
					"unsupported %s: real generation %d publishes" % [label, generation]):
				return
		var future_path: String = path + {"primary": "", "temporary": ".tmp", "backup": ".bak"}[label]
		var future := {"schema_version": Store.SCHEMA_VERSION + 1,
			"opaque_future_payload": {"private_marker": UNSUPPORTED_MARKER, "shape": [null, true, {"future": 9}]}}
		if not _unsupported_check(Filesystem.new().write_bytes_and_flush(future_path,
				JSON.stringify(future).to_utf8_buffer()) == OK,
				"unsupported %s: publish opaque future envelope" % label):
			return
		if not _unsupported_check(Filesystem.new().write_bytes_and_flush(
				directory.path_join("unrelated.txt"), "UNRELATED FILE MUST SURVIVE\n".to_utf8_buffer()) == OK,
				"unsupported %s: publish unrelated sentinel" % label):
			return
		var files := DirAccess.get_files_at(directory)
		files.sort()
		if not OS.has_feature("windows"):
			for index in files.size():
				if not _unsupported_check(FileAccess.set_unix_permissions(directory.path_join(files[index]),
						384 if index % 2 == 0 else 416) == OK,
						"unsupported %s: set distinct Unix file modes" % label):
					return
		var before := _unsupported_snapshot(directory)
		if not _unsupported_check(_unsupported_fixture_shape(before, label),
				"unsupported %s: snapshot exact fixture names, bytes and modes" % label):
			return
		var refused := store.commit({"credits": 999}, store.get_generation(), "unsupported-retained")
		if not _unsupported_check(not bool(refused.accepted) and refused.reason == &"newer_schema"
				and _unsupported_snapshot(directory) == before,
				"unsupported %s: legitimately loaded authority refuses commit without changing files" % label):
			return
		snapshots[label] = before
	var child_pids := [OS.get_process_id()]
	for launch in [1, 2]:
		var output: Array = []
		var arguments := PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path",
			ProjectSettings.globalize_path("res://"), "--script",
			"res://tests/user_data_store_crash_points_test.gd", "--", "--save-unsupported-child",
			"--owned-root=" + owned_root, "--owned-nonce=" + nonce,
			"--owned-parent-pid=" + str(OS.get_process_id())])
		# OS.execute waits for this finite child. The independent outer suite
		# process guard owns the deadline and all descendants; never retry a child.
		var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
		var diagnostics := "\n".join(output)
		print("UNSUPPORTED CHILD %d STDOUT/STDERR BEGIN\n%s\nUNSUPPORTED CHILD %d STDOUT/STDERR END"
			% [launch, diagnostics, launch])
		if not _unsupported_check(exit_code == 0 and not diagnostics.contains(UNSUPPORTED_MARKER)
				and diagnostics.count(UNSUPPORTED_CHILD_OK) == 1
				and not diagnostics.contains("USER_DATA_STORE_CRASH_POINTS_TEST_OK"),
				"unsupported files: child %d exits cleanly without leaking opaque content" % launch):
			return
		var child_pid := 0
		for line in diagnostics.split("\n"):
			if line.begins_with(UNSUPPORTED_CHILD_OK):
				var receipt: Variant = JSON.parse_string(line.trim_prefix(UNSUPPORTED_CHILD_OK))
				if receipt is Dictionary and receipt.get("nonce") == nonce \
						and int(receipt.get("parent_pid", 0)) == OS.get_process_id():
					child_pid = int(receipt.get("pid", 0))
		if not _unsupported_check(child_pid > 0 and not child_pids.has(child_pid),
				"unsupported files: child %d has a distinct actual PID after synchronous exit" % launch):
			return
		child_pids.append(child_pid)
		for label in UNSUPPORTED_CASES:
			if not _unsupported_check(_unsupported_snapshot(owned_root.path_join(label)) == snapshots[label],
					"unsupported %s: child %d preserves original names, bytes and modes" % [label, launch]):
				return


func _run_unsupported_child() -> void:
	var passed := _verify_unsupported_child()
	if passed:
		print(UNSUPPORTED_CHILD_OK + JSON.stringify({"pid": OS.get_process_id(),
			"parent_pid": _unsupported_argument("--owned-parent-pid=").to_int(),
			"nonce": _unsupported_argument("--owned-nonce=")}))
	quit(0 if passed else 1)


func _verify_unsupported_child() -> bool:
	var owned_root := _unsupported_argument("--owned-root=")
	var nonce := _unsupported_argument("--owned-nonce=")
	var parent_pid := _unsupported_argument("--owned-parent-pid=").to_int()
	if not _unsupported_check(DisplayServer.get_name() == "headless"
			and AudioServer.get_driver_name() == "Dummy"
			and nonce.length() == 32 and nonce.is_valid_hex_number(false)
			and parent_pid > 0 and parent_pid != OS.get_process_id()
			and owned_root.begins_with("user://user_data_crash_points_")
			and owned_root.ends_with("/unsupported_" + nonce)
			and not owned_root.contains("..") and not owned_root.contains("\\"),
			"unsupported child: explicit private root, nonce, parent and headless/Dummy guards"):
		return false
	var owner: Variant = JSON.parse_string(FileAccess.get_file_as_string(owned_root.path_join("owner.json")))
	if not _unsupported_check(owner is Dictionary and owner.get("nonce") == nonce
			and int(owner.get("parent_pid", 0)) == parent_pid,
			"unsupported child: root matches the invoking parent identity"):
		return false
	for label in UNSUPPORTED_CASES:
		var directory := owned_root.path_join(label)
		var before := _unsupported_snapshot(directory)
		if not _unsupported_check(_unsupported_fixture_shape(before, label),
				"unsupported %s child: actual future fixture and file modes are present" % label):
			return false
		var store := Store.new(directory.path_join("profile.json")) as UserDataStore
		for action in ["load", "load_read_only", "commit", "recover_interrupted_transaction",
				"restore_backup_to_primary", "discard_interrupted_transaction"]:
			var result: Dictionary
			if action == "commit":
				# Failed load supplies no authority. Do not manufacture loaded state.
				result = store.commit({"credits": 999}, store.get_generation(), "unsupported-fresh")
			else:
				result = store.call(action)
			var expected := &"not_loaded" if action == "commit" else &"newer_schema"
			if not _unsupported_check(not bool(result.get("accepted", true)) and result.get("reason") == expected
					and _unsupported_snapshot(directory) == before,
					"unsupported %s child: %s refuses and preserves every file" % [label, action]):
				return false
	return true


func _unsupported_argument(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _unsupported_snapshot(directory: String) -> Dictionary:
	var access := DirAccess.open(directory)
	if access == null:
		return {}
	access.include_hidden = true
	access.include_navigational = false
	var entries := {}
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		var path := directory.path_join(name)
		entries[name] = {"directory": access.current_is_dir(),
			"bytes": FileAccess.get_file_as_bytes(path) if not access.current_is_dir() else PackedByteArray(),
			"mode": null if OS.has_feature("windows") else FileAccess.get_unix_permissions(path)}
		name = access.get_next()
	access.list_dir_end()
	return {"mode": null if OS.has_feature("windows") else FileAccess.get_unix_permissions(directory),
		"entries": entries}


func _unsupported_fixture_shape(snapshot: Dictionary, label: String) -> bool:
	var entries := snapshot.get("entries", {}) as Dictionary
	var expected := ["profile.json", "profile.json.bak", "unrelated.txt"]
	if label == "temporary":
		expected.append("profile.json.tmp")
	var names := entries.keys()
	names.sort()
	expected.sort()
	if names != expected:
		return false
	for index in expected.size():
		var entry := entries[expected[index]] as Dictionary
		if bool(entry.directory):
			return false
		if OS.has_feature("windows"):
			if entry.mode != null:
				return false
		elif int(entry.mode) != (384 if index % 2 == 0 else 416):
			return false
	var future_name: String = "profile.json" + {"primary": "", "temporary": ".tmp", "backup": ".bak"}[label]
	var bytes: PackedByteArray = entries[future_name].bytes
	var envelope: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return envelope is Dictionary and envelope.get("schema_version") == Store.SCHEMA_VERSION + 1 \
		and bytes.get_string_from_utf8().contains(UNSUPPORTED_MARKER) \
		and entries["unrelated.txt"].bytes == "UNRELATED FILE MUST SURVIVE\n".to_utf8_buffer()


func _unsupported_check(condition: bool, description: String) -> bool:
	_check(condition, description)
	return condition


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("USER_DATA_STORE_CRASH_POINTS_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"USER_DATA_STORE_CRASH_POINTS_TEST_FAILED: %d/%d assertions failed"
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
