extends SceneTree

## Real-disk crash points for the shared settings/progress document. A process
## that dies at any step of a commit must leave a document the next launch can
## load and save again; an interrupted transaction must not strand the player on
## authored defaults with every later save refused.

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

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
	_root = "user://user_data_crash_points_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root))
	_test_crash_between_backup_and_publish_reloads_and_saves()
	_test_crash_after_staging_reloads_and_saves()
	_test_crash_during_first_ever_save_reloads_and_saves()
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
