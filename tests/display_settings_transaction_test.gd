extends SceneTree

## Headless checks the paused recovery owner with a seeded preview.
## Xvfb also exercises the actual production display request.
const Fixture := preload("res://tests/runtime_settings_production_persistence_test.gd")
const Main := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.disable_3d = true
	var filesystem := Fixture.FakeFilesystem.new()
	var store := UserDataStore.new("memory://display-transaction.json", filesystem)
	var game := Main.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store, "memory://display-transaction.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	var settings := game.get_runtime_settings()
	var hud := game.get_node("HUD") as GameHUD
	hud.set_paused(true)
	var baseline := settings.display_resolution
	if DisplayServer.get_name() == "headless":
		# Production intentionally refuses headless previews. Seed only that
		# unavailable display boundary; run the real recovery clock and owner.
		game.set("_pending_display_confirmation", {
			"generation": 1, "remaining": 15.0,
			"prior": settings.to_dictionary(),
		})
		settings.display_resolution = "1280x720"
		game.call("_start_display_confirmation_clock")
		print("Display request integration: NOT_RUN (headless); testing recovery clock")
	else:
		game.call("_on_setting_change_requested", &"display_resolution", "1280x720")
	var pending := game.get("_pending_display_confirmation") as Dictionary
	_check(not pending.is_empty(), "display recovery has a pending preview")
	_check(paused and not game.can_process(), "settings pause leaves gameplay suspended")
	# Shorten only this test's deadline; await the real always-processing owner.
	pending.remaining = 0.2
	await create_timer(0.5, true).timeout
	_check((game.get("_pending_display_confirmation") as Dictionary).is_empty(), "paused display preview expires automatically")
	_check(settings.display_resolution == baseline, "timeout restores the confirmed display")
	_check(paused and not game.can_process(), "recovery does not resume gameplay")
	if DisplayServer.get_name() != "headless":
		_test_persistence(game, filesystem, store)
	else:
		print("Display persistence integration: NOT_RUN (headless)")
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("display_settings_transaction_test: %d assertions" % _assertions)
	if _failures.is_empty():
		print("DISPLAY_SETTINGS_TRANSACTION_TEST_OK")
	quit(0 if _failures.is_empty() else 1)


func _test_persistence(game: GameFlow, filesystem: Fixture.FakeFilesystem, store: UserDataStore) -> void:
	var settings := game.get_runtime_settings()
	var hud := game.get_node("HUD") as GameHUD
	var baseline := settings.display_resolution
	# Ordinary saves must retain the accepted display on disk during a preview.
	game.call("_on_settings_save_requested")
	game.call("_on_setting_change_requested", &"display_resolution", "1280x720")
	var generation := int((game.get("_pending_display_confirmation") as Dictionary).generation)
	game.call("_on_setting_change_requested", &"master_volume", 0.5)
	var fresh := RuntimeSettings.new("memory://fresh.cfg")
	var adapter := RuntimeSettingsStoreAdapter.new(fresh, store, "memory://fresh.cfg")
	_check(bool(adapter.load().accepted) and fresh.display_resolution == baseline, "volume autosave persists the confirmed display")
	_check(is_equal_approx(fresh.master_volume, 0.5), "unrelated changes are still saved during preview")
	game.call("_on_settings_save_requested")
	adapter.load()
	_check(fresh.display_resolution == baseline and settings.display_resolution == "1280x720", "Apply + Save preserves baseline on disk and candidate live")
	game.call("_on_display_settings_revert_requested", generation)
	adapter.load()
	_check(settings.display_resolution == baseline and fresh.display_resolution == baseline, "revert and fresh reload agree on the confirmed display")
	var volume_control := (hud.get("_settings_controls") as Dictionary).get(&"master_volume") as Range
	_check(is_equal_approx(settings.master_volume, 0.5) and is_equal_approx(volume_control.value, 0.5), "revert retains unrelated settings in runtime and HUD")
	game.call("_on_setting_change_requested", &"display_resolution", "1280x720")
	generation = int((game.get("_pending_display_confirmation") as Dictionary).generation)
	game.call("_on_display_settings_keep_requested", generation)
	adapter.load()
	_check(fresh.display_resolution == "1280x720" and (game.get("_pending_display_confirmation") as Dictionary).is_empty(), "Keep Display commits its candidate and completes preview")
	game.call("_on_setting_change_requested", &"display_resolution", "2560x1440")
	generation = int((game.get("_pending_display_confirmation") as Dictionary).generation)
	filesystem.fail_write_once = true
	game.call("_on_display_settings_keep_requested", generation)
	adapter.load()
	_check(settings.display_resolution == "1280x720" and fresh.display_resolution == "1280x720", "failed Keep restores the confirmed display and disk authority")
	game.call("_on_setting_change_requested", &"display_resolution", "2560x1440")
	generation = int((game.get("_pending_display_confirmation") as Dictionary).generation)
	game.call("_on_settings_reset_requested")
	adapter.load()
	_check((game.get("_pending_display_confirmation") as Dictionary).is_empty(), "reset resolves the pending preview")
	game.call("_on_display_settings_revert_requested", generation)
	_check(settings.display_resolution == RuntimeSettings.DEFAULT_DISPLAY_RESOLUTION_ID and fresh.display_resolution == settings.display_resolution, "stale revert cannot undo accepted reset defaults")
	# Teardown also cancels transient display state after unrelated saves.
	game.call("_on_setting_change_requested", &"display_resolution", "1280x720")
	game.call("_on_setting_change_requested", &"master_volume", 0.6)
	hud.set_paused(false)
	root.remove_child(game)
	adapter.load()
	_check(settings.display_resolution == fresh.display_resolution and fresh.display_resolution == RuntimeSettings.DEFAULT_DISPLAY_RESOLUTION_ID, "detaching Main discards its candidate and retains saved display")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
