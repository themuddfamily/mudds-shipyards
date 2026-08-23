extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const AdapterType := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const StoreType := preload("res://scripts/persistence/user_data_store.gd")

const PATH := "memory://repair-hud-integration.json"
var _assertions := 0
var _failures: PackedStringArray = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_file(_path: String) -> Error:
		return OK

	func sync_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
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
	call_deferred(&"_run")


func _run() -> void:
	var fixture := _backup_recovery_fixture(PATH)
	var filesystem := fixture.filesystem as FakeFilesystem
	var store := fixture.store as UserDataStore
	var corrupt_primary := (filesystem.files[PATH] as PackedByteArray).duplicate()
	var flow := GameFlowType.new()
	_check(
		flow.configure_runtime_settings_persistence(store, "memory://repair-hud.cfg"),
		"isolated repair store configures before startup"
	)
	flow.call("_initialize_runtime_settings")
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	flow.set("hud", hud)
	flow.call("_connect_runtime_settings_repair_hud")
	var inspected := flow.call("_publish_runtime_settings_repair_to_hud") as Dictionary
	var repair_report := flow.get_runtime_settings_repair_report()
	var repair_panel := hud.get("_settings_repair_panel") as PanelContainer
	var repair_button := hud.get("_settings_repair_confirm_button") as Button
	_check(
		bool(inspected.get("accepted", false))
		and inspected.get("reason", &"") == &"repair_available"
		and repair_report.last_status.confirmation == inspected.confirmation
		and repair_panel.visible
		and repair_button.visible,
		"authentic retained startup inspection reaches the HUD action surface"
	)
	_check(
		filesystem.files[PATH] == corrupt_primary
		and store.get_generation() == 1,
		"publishing recovery availability never repairs or writes automatically"
	)
	repair_button.pressed.emit()
	var committed_report := flow.get_runtime_settings_repair_report()
	var commit := committed_report.last_status.commit as Dictionary
	var settings_status := hud.get("_settings_status_label") as Label
	_check(
		committed_report.last_status.reason == &"repair_committed"
		and store.get_generation() == 2
		and str(commit.get("id", "")) == "runtime-settings-repair-0000000002"
		and filesystem.files[PATH] != corrupt_primary,
		"explicit HUD confirmation uses the caller-owned bounded ID and commits once"
	)
	_check(
		bool((store.get_snapshot().get("foreign", {}) as Dictionary).get("keep", false))
		and not repair_panel.visible
		and settings_status.visible
		and settings_status.text == "SETTINGS BACKUP REPAIRED",
		"successful repair preserves unrelated payload and reports final success accurately"
	)
	var repaired_bytes := (filesystem.files[PATH] as PackedByteArray).duplicate()
	var repair_binding: RefCounted = flow.get("_runtime_settings_repair_binding")
	repair_binding.call("set_attached", false)
	hud.clear_runtime_settings_repair_report()
	repair_binding.call("set_attached", true)
	var reentered := flow.call("_publish_runtime_settings_repair_to_hud") as Dictionary
	_check(
		reentered.get("reason", &"") == &"repair_resolved"
		and not repair_panel.visible
		and not hud.get_runtime_settings_repair_presentation().confirmation_available
		and store.get_generation() == 2
		and filesystem.files[PATH] == repaired_bytes,
		"successful repair stays resolved and write-free across detach and re-entry"
	)

	var failed_fixture := _backup_recovery_fixture("memory://repair-hud-failure.json")
	var failed_store := failed_fixture.store as UserDataStore
	var failed_flow := GameFlowType.new()
	failed_flow.configure_runtime_settings_persistence(
		failed_store, "memory://repair-hud-failure.cfg"
	)
	failed_flow.call("_initialize_runtime_settings")
	var failed_hud := HudType.new()
	root.add_child(failed_hud)
	await process_frame
	failed_flow.set("hud", failed_hud)
	failed_flow.call("_connect_runtime_settings_repair_hud")
	failed_flow.call("_publish_runtime_settings_repair_to_hud")
	var failed_button := failed_hud.get("_settings_repair_confirm_button") as Button
	failed_flow.get("_runtime_settings_repair_binding").set_attached(false)
	failed_button.pressed.emit()
	var failed_status := failed_hud.get("_settings_status_label") as Label
	_check(
		failed_store.get_generation() == 1
		and failed_status.visible
		and failed_status.text == "BACKUP REPAIR FAILED  //  DETACHED"
		and not (failed_hud.get("_settings_repair_panel") as PanelContainer).visible,
		"binding rejection performs no write and reports the actual final failure"
	)

	hud.queue_free()
	failed_hud.queue_free()
	flow.free()
	failed_flow.free()
	await process_frame
	_finish()


func _backup_recovery_fixture(path: String) -> Dictionary:
	var filesystem := FakeFilesystem.new()
	var settings := SettingsType.new(path + ".cfg")
	var seed_store := StoreType.new(path, filesystem)
	seed_store.load()
	var payload := {
		AdapterType.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload(),
		"foreign": {"keep": true},
	}
	seed_store.commit(payload, 0, "repair-hud-seed-001")
	settings.camera_fov = 84.0
	payload[AdapterType.SETTINGS_PAYLOAD_KEY] = settings.to_user_data_payload()
	seed_store.commit(payload, 1, "repair-hud-seed-002")
	filesystem.files[path] = "{corrupt".to_utf8_buffer()
	return {
		"filesystem": filesystem,
		"store": StoreType.new(path, filesystem),
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RUNTIME_SETTINGS_REPAIR_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
