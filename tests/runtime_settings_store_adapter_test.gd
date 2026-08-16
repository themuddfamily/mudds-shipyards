extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Service := preload("res://scripts/settings/input_rebind_service.gd")

const STORE_PATH := "memory://runtime_settings.json"
const ACTION := &"landing_assist"

var _failures := PackedStringArray()
var _assertions := 0
var _legacy_path := ""


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write_once := false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_write_once:
			fail_write_once = false
			files[path] = bytes.slice(0, maxi(1, bytes.size() / 2))
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_legacy_path = "user://runtime_settings_atomic_legacy_%d.cfg" % Time.get_ticks_usec()
	_cleanup_legacy()
	_test_json_round_trip_and_payload_composition()
	_test_legacy_import_is_empty_store_only()
	_test_failed_writes_preserve_live_and_disk()
	_test_corrupt_and_newer_authority_is_preserved()
	_test_typed_payload_rejection_is_atomic()
	_test_signal_reentry_cannot_mutate_store_authority()
	_cleanup_legacy()
	_finish()


func _test_json_round_trip_and_payload_composition() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	_check(bool(store.load().accepted), "composition fixture opens an empty atomic store")
	_check(
		bool(store.commit({"career": {"credits": 17}}, 0, "career-001").accepted),
		"composition fixture commits an unrelated user-data key"
	)
	var settings := Settings.new(_legacy_path)
	settings.ship_mouse_sensitivity = 0.0073
	settings.camera_fov = 101.0
	settings.graphics_profile = Settings.GraphicsProfile.MEDIUM
	settings.window_mode = Settings.WindowMode.FULLSCREEN
	settings.colorblind_palette = Settings.ColorblindPalette.PROTANOPIA
	settings.captions_enabled = true
	var profile := settings.get_input_binding_profile()
	_check(
		profile.set_bindings(ACTION, [_key(KEY_F13), _joy_button(15)]),
		"round-trip fixture creates a complete portable keyboard/gamepad remap"
	)
	_check(settings.set_input_binding_profile(profile), "round-trip fixture installs the valid profile")
	var expected := settings.to_dictionary()
	var input_before := Service.new().capture_input_map().to_dictionary()
	var adapter := Adapter.new(settings, store, _legacy_path)
	var saved := adapter.save("settings-001")
	_check(
		bool(saved.accepted) and saved.reason == &"saved" and int(saved.generation) == 2,
		"settings save composes through the atomic generation contract"
	)
	var stored_payload := store.get_snapshot()
	_check(
		int((stored_payload.career as Dictionary).credits) == 17
		and stored_payload.has(Adapter.SETTINGS_PAYLOAD_KEY),
		"settings save preserves unrelated atomic payload keys"
	)
	_check(
		bool(Store.validate_payload(stored_payload).valid),
		"the settings and input profile section contains only JSON-safe values"
	)
	settings.reset_to_defaults()
	var loaded := adapter.load()
	_check(
		bool(loaded.accepted) and loaded.reason == &"loaded" and bool(loaded.applied),
		"a validated atomic section installs into the live settings owner"
	)
	_check(
		settings.to_dictionary() == expected,
		"JSON-normalized numbers reconstruct the exact typed settings and input profile"
	)
	_check(
		Service.new().capture_input_map().to_dictionary() == input_before,
		"atomic save and load remain side-effect free on InputMap"
	)


func _test_legacy_import_is_empty_store_only() -> void:
	_write_legacy(0.0049)
	var filesystem := FakeFilesystem.new()
	var settings := Settings.new(_legacy_path)
	settings.ship_mouse_sensitivity = 0.0081
	var imported := Adapter.new(
		settings, Store.new(STORE_PATH, filesystem), _legacy_path
	).load()
	_check(
		bool(imported.accepted)
		and imported.reason == &"legacy_imported"
		and bool(imported.applied)
		and bool(imported.migrated_legacy),
		"a genuine generation-zero empty store imports the supported legacy file once"
	)
	_check(
		is_equal_approx(settings.ship_mouse_sensitivity, 0.0049)
		and int(imported.generation) == 1
		and filesystem.files.has(STORE_PATH),
		"legacy state reaches live memory only after its first atomic commit"
	)
	_check(FileAccess.file_exists(_legacy_path), "legacy import preserves the source ConfigFile")

	_write_legacy(0.0052)
	filesystem = FakeFilesystem.new()
	var nonempty := Store.new(STORE_PATH, filesystem)
	nonempty.load()
	nonempty.commit({}, 0, "empty-payload-generation")
	var before_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	settings = Settings.new(_legacy_path)
	settings.ship_mouse_sensitivity = 0.0084
	var skipped := Adapter.new(settings, nonempty, _legacy_path).load()
	_check(
		not bool(skipped.accepted)
		and skipped.reason == &"settings_missing"
		and not bool(skipped.migrated_legacy),
		"a committed atomic generation with an empty payload never falls back to legacy settings"
	)
	_check(
		is_equal_approx(settings.ship_mouse_sensitivity, 0.0084)
		and filesystem.files[STORE_PATH] == before_bytes,
		"skipped legacy import preserves both live state and atomic bytes"
	)


func _test_failed_writes_preserve_live_and_disk() -> void:
	_write_legacy(0.0056)
	var filesystem := FakeFilesystem.new()
	filesystem.fail_write_once = true
	var settings := Settings.new(_legacy_path)
	settings.ship_mouse_sensitivity = 0.0087
	var migration := Adapter.new(
		settings, Store.new(STORE_PATH, filesystem), _legacy_path
	).load()
	_check(
		not bool(migration.accepted)
		and migration.reason == &"legacy_commit_failed"
		and migration.store_reason == &"temp_write_failed",
		"legacy migration surfaces the exact failed atomic write status"
	)
	_check(
		is_equal_approx(settings.ship_mouse_sensitivity, 0.0087)
		and not filesystem.files.has(STORE_PATH)
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"failed legacy commit changes neither live settings nor canonical disk state"
	)

	_cleanup_legacy()
	filesystem = FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	settings = Settings.new(_legacy_path)
	var adapter := Adapter.new(settings, store, _legacy_path)
	_check(bool(adapter.save("settings-initial").accepted), "failed-save fixture publishes one baseline")
	var disk_before := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	settings.ship_mouse_sensitivity = 0.0091
	var live_before := settings.to_dictionary()
	filesystem.fail_write_once = true
	var failed := adapter.save("settings-failed")
	_check(
		not bool(failed.accepted)
		and failed.reason == &"store_commit_failed"
		and failed.store_reason == &"temp_write_failed",
		"ordinary save propagates the atomic store's concrete failure reason"
	)
	_check(
		settings.to_dictionary() == live_before
		and filesystem.files[STORE_PATH] == disk_before
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"failed ordinary save preserves both prior live and canonical disk states"
	)


func _test_corrupt_and_newer_authority_is_preserved() -> void:
	var filesystem := FakeFilesystem.new()
	filesystem.files[STORE_PATH] = "{corrupt".to_utf8_buffer()
	var corrupt_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var settings := Settings.new(_legacy_path)
	settings.ship_mouse_sensitivity = 0.0088
	var adapter := Adapter.new(settings, Store.new(STORE_PATH, filesystem), _legacy_path)
	var corrupt_load := adapter.load()
	_check(
		not bool(corrupt_load.accepted)
		and corrupt_load.reason == &"store_load_failed"
		and corrupt_load.store_reason == &"no_valid_document",
		"corrupt atomic authority fails closed instead of importing legacy/defaults"
	)
	_check(
		is_equal_approx(settings.ship_mouse_sensitivity, 0.0088)
		and filesystem.files[STORE_PATH] == corrupt_bytes,
		"corrupt atomic bytes and prior live settings remain untouched"
	)

	filesystem = FakeFilesystem.new()
	var seeded := Store.new(STORE_PATH, filesystem)
	seeded.load()
	seeded.commit({"career": true}, 0, "future-envelope-base")
	var future_document := _decode(filesystem, STORE_PATH)
	future_document.schema_version = Store.SCHEMA_VERSION + 1
	filesystem.files[STORE_PATH] = JSON.stringify(future_document).to_utf8_buffer()
	var future_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	adapter = Adapter.new(settings, Store.new(STORE_PATH, filesystem), _legacy_path)
	var future_load := adapter.load()
	var future_save := adapter.save("must-not-write")
	_check(
		not bool(future_load.accepted)
		and future_load.store_reason == &"newer_schema"
		and not bool(future_save.accepted)
		and future_save.store_reason == &"newer_schema",
		"a newer atomic envelope blocks both load fallback and ordinary save"
	)
	_check(
		filesystem.files[STORE_PATH] == future_bytes,
		"newer atomic envelope bytes are preserved exactly"
	)

	filesystem = FakeFilesystem.new()
	seeded = Store.new(STORE_PATH, filesystem)
	seeded.load()
	seeded.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1,
			"values": {},
		},
	}, 0, "future-settings")
	var nested_future_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	adapter = Adapter.new(settings, seeded, _legacy_path)
	var nested_load := adapter.load()
	var nested_save := adapter.save("must-not-replace")
	_check(
		not bool(nested_load.accepted)
		and nested_load.reason == &"settings_payload_newer"
		and not bool(nested_save.accepted)
		and nested_save.reason == &"settings_payload_newer",
		"a newer typed settings section is distinguished from corrupt data"
	)
	_check(
		filesystem.files[STORE_PATH] == nested_future_bytes,
		"ordinary save never overwrites a newer typed settings section"
	)

	filesystem = FakeFilesystem.new()
	seeded = Store.new(STORE_PATH, filesystem)
	seeded.load()
	var future_profile_payload := settings.to_user_data_payload()
	var future_profile := (
		(future_profile_payload.values as Dictionary).input_binding_profile as Dictionary
	)
	future_profile.schema_version = Profile.SCHEMA_VERSION + 1
	seeded.commit(
		{Adapter.SETTINGS_PAYLOAD_KEY: future_profile_payload},
		0,
		"future-input-profile"
	)
	var future_profile_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	adapter = Adapter.new(settings, seeded, _legacy_path)
	var future_profile_load := adapter.load()
	var future_profile_save := adapter.save("must-not-replace-profile")
	_check(
		not bool(future_profile_load.accepted)
		and future_profile_load.reason == &"settings_payload_newer"
		and future_profile_load.payload_reason == &"newer_input_binding_profile"
		and not bool(future_profile_save.accepted)
		and future_profile_save.reason == &"settings_payload_newer",
		"a newer nested input-binding schema also blocks load and save"
	)
	_check(
		filesystem.files[STORE_PATH] == future_profile_bytes,
		"ordinary save preserves newer input-binding profile bytes exactly"
	)

	filesystem = FakeFilesystem.new()
	settings = Settings.new(_legacy_path)
	adapter = Adapter.new(settings, Store.new(STORE_PATH, filesystem), _legacy_path)
	settings.ship_mouse_sensitivity = 0.0041
	adapter.save("recovery-generation-1")
	settings.ship_mouse_sensitivity = 0.0062
	adapter.save("recovery-generation-2")
	filesystem.files[STORE_PATH] = "{corrupt-primary".to_utf8_buffer()
	var corrupt_primary := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var recovery_backup := (filesystem.files[STORE_PATH + ".bak"] as PackedByteArray).duplicate()
	var recovered_settings := Settings.new(_legacy_path)
	var recovery_adapter := Adapter.new(
		recovered_settings, Store.new(STORE_PATH, filesystem), _legacy_path
	)
	var recovered := recovery_adapter.load()
	_check(
		bool(recovered.accepted)
		and recovered.store_reason == &"primary_invalid_backup_loaded"
		and is_equal_approx(recovered_settings.ship_mouse_sensitivity, 0.0041),
		"load may safely expose validated backup settings without repairing corrupt primary"
	)
	var repair_refused := recovery_adapter.save("implicit-repair-forbidden")
	_check(
		not bool(repair_refused.accepted)
		and repair_refused.reason == &"store_recovery_required"
		and filesystem.files[STORE_PATH] == corrupt_primary
		and filesystem.files[STORE_PATH + ".bak"] == recovery_backup,
		"ordinary save preserves both corrupt primary and recovery backup bytes"
	)

	filesystem = FakeFilesystem.new()
	seeded = Store.new(STORE_PATH, filesystem)
	seeded.load()
	seeded.commit({Adapter.SETTINGS_PAYLOAD_KEY: {"schema_version": 1}}, 0, "bad-settings")
	var malformed_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	adapter = Adapter.new(settings, seeded, _legacy_path)
	var malformed_save := adapter.save("must-not-replace-bad")
	_check(
		not bool(malformed_save.accepted)
		and malformed_save.reason == &"settings_payload_invalid"
		and filesystem.files[STORE_PATH] == malformed_bytes,
		"ordinary save preserves a malformed typed settings section for diagnosis"
	)


func _test_typed_payload_rejection_is_atomic() -> void:
	var settings := Settings.new(_legacy_path)
	settings.ship_mouse_sensitivity = 0.0086
	settings.camera_fov = 94.0
	var before := settings.to_dictionary()
	var out_of_range := settings.to_user_data_payload()
	(out_of_range.values as Dictionary).camera_fov = 1000.0
	var rejected := settings.apply_user_data_payload(out_of_range)
	_check(
		not bool(rejected.accepted)
		and rejected.reason == &"invalid_camera_fov"
		and settings.to_dictionary() == before,
		"out-of-range atomic values reject as one unit without setter clamping"
	)
	var unknown_profile_field := settings.to_user_data_payload()
	var profile := (unknown_profile_field.values as Dictionary).input_binding_profile as Dictionary
	profile["unexpected"] = true
	rejected = settings.apply_user_data_payload(unknown_profile_field)
	_check(
		not bool(rejected.accepted)
		and rejected.reason == &"invalid_input_binding_profile"
		and settings.to_dictionary() == before,
		"unknown input-profile fields cannot be silently normalized into live state"
	)
	var unsafe_schema := settings.to_user_data_payload()
	unsafe_schema["schema_version"] = 1.0e300
	rejected = settings.apply_user_data_payload(unsafe_schema)
	var unsafe_profile_schema := settings.to_user_data_payload()
	var unsafe_profile := (
		(unsafe_profile_schema.values as Dictionary).input_binding_profile as Dictionary
	)
	unsafe_profile["schema_version"] = 1.0e300
	var profile_rejected := settings.apply_user_data_payload(unsafe_profile_schema)
	_check(
		not bool(rejected.accepted)
		and rejected.reason == &"schema_invalid"
		and not bool(profile_rejected.accepted)
		and profile_rejected.reason == &"invalid_input_binding_profile"
		and settings.to_dictionary() == before,
		"integral-looking numbers outside JSON's safe integer range are invalid schemas, not future versions"
	)


func _test_signal_reentry_cannot_mutate_store_authority() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	store.load()
	var persisted_settings := Settings.new(_legacy_path)
	persisted_settings.camera_fov = 96.0
	_check(
		bool(store.commit({
			"career": {"credits": 27},
			Adapter.SETTINGS_PAYLOAD_KEY: persisted_settings.to_user_data_payload(),
		}, 0, "reentry-fixture").accepted),
		"reentry fixture publishes one settings generation"
	)
	var settings := Settings.new(_legacy_path)
	var adapter := Adapter.new(settings, store, _legacy_path)
	var nested_results: Array[Dictionary] = []
	var reentry_callback := func(_names: PackedStringArray) -> void:
		nested_results.append(adapter.save("nested-signal-save"))
		nested_results.append(adapter.load())
	settings.settings_changed.connect(reentry_callback)
	var bytes_before := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var payload_before := store.get_snapshot()
	var loaded := adapter.load()
	settings.settings_changed.disconnect(reentry_callback)
	var nested_rejected := nested_results.size() == 2
	for nested in nested_results:
		nested_rejected = nested_rejected \
			and not bool(nested.get("accepted", true)) \
			and nested.get("reason") == &"reentrant_call" \
			and nested.get("store_reason") == &"not_attempted"
	_check(
		bool(loaded.accepted)
		and loaded.reason == &"loaded"
		and int(loaded.generation) == 1
		and is_equal_approx(settings.camera_fov, 96.0)
		and nested_rejected,
		"settings signals see committed live values but nested adapter load/save calls are rejected"
	)
	_check(
		store.get_generation() == 1
		and store.get_snapshot() == payload_before
		and filesystem.files[STORE_PATH] == bytes_before,
		"signal reentry cannot advance store generation or alter adjacent payload namespaces"
	)


func _write_legacy(sensitivity: float) -> void:
	_cleanup_legacy()
	var config := ConfigFile.new()
	config.set_value("meta", "schema_version", Settings.SCHEMA_VERSION)
	config.set_value("controls", "ship_mouse_sensitivity", sensitivity)
	_check(config.save(_legacy_path) == OK, "legacy migration fixture writes")


func _decode(filesystem: FakeFilesystem, path: String) -> Dictionary:
	var parsed := JSON.new()
	if parsed.parse((filesystem.files[path] as PackedByteArray).get_string_from_utf8()) != OK:
		return {}
	return parsed.data as Dictionary


func _key(code: Key) -> Dictionary:
	return {
		"device": Profile.DEVICE_KEYBOARD,
		"type": &"key",
		"physical_keycode": code,
	}


func _joy_button(button: int) -> Dictionary:
	return {
		"device": Profile.DEVICE_GAMEPAD,
		"type": &"joy_button",
		"button_index": button,
	}


func _cleanup_legacy() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := _legacy_path + suffix
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("RUNTIME_SETTINGS_STORE_ADAPTER_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"RUNTIME_SETTINGS_STORE_ADAPTER_TEST_FAILED: %d/%d assertions failed"
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
