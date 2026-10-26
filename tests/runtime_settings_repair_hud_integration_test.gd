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
	var previous_size := root.size
	var previous_content_size := root.content_scale_size
	var previous_aspect := root.content_scale_aspect
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
	var startup_report := flow.get_safe_start_recovery_report()
	var recovered_payload := store.get_snapshot()
	_check(
		bool(startup_report.get("initialized", false))
		and not bool(startup_report.begin_status.get("accepted", true))
		and startup_report.begin_status.reason == &"store_recovery_required",
		"authentic corrupt-backup startup leaves safe-start initialization rejected"
	)
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	flow.set("hud", hud)
	flow.call("_connect_runtime_settings_repair_hud")
	var inspected := flow.call("_publish_runtime_settings_repair_to_hud") as Dictionary
	var repair_report := flow.get_runtime_settings_repair_report()
	var repair_panel := hud.get("_settings_repair_panel") as PanelContainer
	var repair_button := hud.get("_settings_repair_confirm_button") as Button
	hud.set_paused(true)
	var pause_main := hud.get("_pause_main_page") as Control
	(pause_main.find_child("SettingsOpenButton", true, false) as Button).pressed.emit()
	_check(
		bool(inspected.get("accepted", false))
		and inspected.get("reason", &"") == &"repair_available"
		and repair_report.last_status.confirmation == inspected.confirmation
		and repair_panel.visible
		and repair_button.is_visible_in_tree() and not repair_button.disabled,
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
		store.get_snapshot() == recovered_payload
		and filesystem.files.get(PATH + ".recovery") == corrupt_primary
		and flow.get_safe_start_recovery_report() == startup_report,
		"repair preserves payload and damaged bytes while the original startup remains rejected"
	)
	_check(
		not repair_panel.visible
		and settings_status.is_visible_in_tree()
		and settings_status.text == "SETTINGS BACKUP REPAIRED\nQUIT AND REOPEN THE GAME TO FINISH RECOVERY",
		"repair after rejected startup explicitly tells the player to quit and reopen the game"
	)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1024, 768)
	root.size = Vector2i(1024, 768)
	await process_frame
	await process_frame
	hud.set_ui_scale(1.6)
	await process_frame
	await process_frame
	var settings_page := hud.get("_settings_page") as Control
	_check(
		root.get_visible_rect().size == Vector2(1024.0, 768.0)
		and settings_status.size.x >= settings_status.get_minimum_size().x
		and settings_status.size.y >= settings_status.get_minimum_size().y
		and settings_page.get_global_rect().encloses(settings_status.get_global_rect())
		and Rect2(Vector2.ZERO, Vector2(1024.0, 768.0)).encloses(settings_status.get_global_rect()),
		"recovery guidance fits the actual Settings label at minimum window size and maximum requested scale"
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
	await _check_success_presentation_without_startup_owner()

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

	var blocked_path := "memory://repair-hud-preservation-blocked.json"
	var blocked_fixture := _backup_recovery_fixture(blocked_path)
	var blocked_filesystem := blocked_fixture.filesystem as FakeFilesystem
	var blocked_store := blocked_fixture.store as UserDataStore
	var blocked_flow := GameFlowType.new()
	blocked_flow.configure_runtime_settings_persistence(
		blocked_store, "memory://repair-hud-preservation-blocked.cfg"
	)
	blocked_flow.call("_initialize_runtime_settings")
	var blocked_hud := HudType.new()
	root.add_child(blocked_hud)
	await process_frame
	blocked_flow.set("hud", blocked_hud)
	blocked_flow.call("_connect_runtime_settings_repair_hud")
	var blocked_inspected := blocked_flow.call("_publish_runtime_settings_repair_to_hud") as Dictionary
	var blocked_button := blocked_hud.get("_settings_repair_confirm_button") as Button
	_check(
		blocked_inspected.get("reason", &"") == &"repair_available"
		and blocked_button.visible and not blocked_button.disabled,
		"real backup recovery offers confirmation before the preservation collision"
	)
	# A different retained damaged copy must never be overwritten to repair this save.
	blocked_filesystem.files[blocked_path + ".recovery"] = "older-damaged-save".to_utf8_buffer()
	var blocked_files_before := blocked_filesystem.files.duplicate(true)
	var blocked_snapshot_before := blocked_store.get_snapshot()
	var blocked_metadata_before := blocked_store.get_commit_metadata()
	var blocked_source_before := blocked_store.get_loaded_source()
	blocked_button.pressed.emit()
	var blocked_report := blocked_flow.get_runtime_settings_repair_report()
	var blocked_status := blocked_hud.get("_settings_status_label") as Label
	var blocked_title := blocked_hud.get("_settings_repair_title") as Label
	var blocked_detail := blocked_hud.get("_settings_repair_detail") as Label
	var blocked_panel := blocked_hud.get("_settings_repair_panel") as PanelContainer
	_check(
		not bool(blocked_report.last_status.get("accepted", true))
		and blocked_report.last_status.reason == &"primary_quarantine_failed"
		and bool(blocked_report.last_status.get("repair_authority_cleared", false))
		and not bool(blocked_report.last_status.get("repair_retryable", true))
		and blocked_filesystem.files == blocked_files_before
		and blocked_store.get_generation() == 1
		and blocked_store.get_snapshot() == blocked_snapshot_before
		and blocked_store.get_commit_metadata() == blocked_metadata_before
		and blocked_store.get_loaded_source() == blocked_source_before,
		"actual confirmation refuses the collision with every file and loaded save authority unchanged"
	)
	_check(
		blocked_panel.visible
		and blocked_title.text == "SETTINGS RECOVERY BLOCKED"
		and blocked_detail.text.contains("damaged save and verified backup were retained")
		and blocked_detail.text.contains("could not safely preserve the damaged copy")
		and blocked_detail.text.contains("replacement was blocked")
		and blocked_status.visible
		and blocked_status.text == "BACKUP REPAIR BLOCKED  //  SAVE FILES PRESERVED"
		and not blocked_status.text.contains("PRIMARY_QUARANTINE_FAILED")
		and not blocked_title.text.contains("AMBIGUOUS")
		and not blocked_status.text.contains("REPAIRED"),
		"blocked repair shows deterministic preservation copy and never reports success or technical codes"
	)
	_check(
		not blocked_button.visible and blocked_button.disabled
		and not blocked_hud.get_runtime_settings_repair_presentation().confirmation_available
		and not bool(blocked_report.prepared)
		and blocked_report.observed_generation == -1
		and not bool(blocked_flow.get("_runtime_settings_repair_resolved")),
		"refusal retires the real binding plan and HUD confirmation without resolving repair"
	)
	blocked_button.pressed.emit()
	_check(
		blocked_filesystem.files == blocked_files_before
		and blocked_store.get_generation() == 1
		and blocked_flow.get_runtime_settings_repair_report() == blocked_report
		and blocked_status.text == "BACKUP REPAIR BLOCKED  //  SAVE FILES PRESERVED",
		"retired confirmation cannot replay the old token or overwrite the blocked result"
	)

	blocked_hud.queue_free()
	blocked_flow.free()
	hud.queue_free()
	failed_hud.queue_free()
	flow.free()
	failed_flow.free()
	await process_frame
	root.content_scale_aspect = previous_aspect
	root.content_scale_size = previous_content_size
	root.size = previous_size
	await process_frame
	await process_frame
	_finish()


func _check_success_presentation_without_startup_owner() -> void:
	var flow := GameFlowType.new()
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	flow.set("hud", hud)
	flow.call("_present_runtime_settings_repair_result", {
		"accepted": true, "reason": &"repair_committed",
	})
	var status := hud.get("_settings_status_label") as Label
	_check(
		flow.get_safe_start_recovery_report().is_empty()
		and status.visible and status.text == "SETTINGS BACKUP REPAIRED",
		"isolated success presentation keeps generic copy when no startup owner exists"
	)
	hud.queue_free()
	flow.free()
	await process_frame


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
