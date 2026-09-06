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
	hud.set_paused(false)
	game.queue_free()
	await process_frame
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("display_settings_transaction_test: %d assertions" % _assertions)
	if _failures.is_empty():
		print("DISPLAY_SETTINGS_TRANSACTION_TEST_OK")
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
