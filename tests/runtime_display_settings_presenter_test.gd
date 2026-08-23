extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Presenter := preload("res://scripts/ui/runtime_display_settings_presenter.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := Settings.new("user://runtime_display_presenter_test.cfg")
	settings.display_resolution = "2560x1440"
	settings.vsync_mode = Settings.VSyncMode.ADAPTIVE
	settings.window_mode = Settings.WindowMode.BORDERLESS
	var presenter := Presenter.new()
	var snapshot := presenter.attach(settings)
	_check(snapshot.attached and snapshot.display_resolution == &"2560x1440", "presenter reflects persisted resolution")
	_check(snapshot.vsync_mode == &"adaptive", "presenter reflects persisted VSync")
	_check(snapshot.window_mode == &"borderless", "presenter reflects persisted window mode")
	_check(snapshot.focus_order == [&"window_mode", &"display_resolution", &"vsync_mode"], "rows expose deterministic keyboard/controller focus order")
	var generation := int(snapshot.generation)
	var changed := presenter.select_resolution(&"1280x720", generation)
	_check(bool(changed.accepted) and changed.intent == &"display_resolution_changed", "resolution selection emits a caller intent")
	var mode_changed := presenter.select_window_mode(&"fullscreen", generation)
	_check(bool(mode_changed.accepted) and mode_changed.intent == &"window_mode_changed", "window mode selection emits a caller intent")
	var invalid := presenter.select_vsync(&"unsupported", generation)
	_check(not bool(invalid.accepted) and invalid.reason == &"unsupported_vsync", "unsupported VSync is rejected")
	var stale := presenter.select_vsync(&"off", generation - 1)
	_check(not bool(stale.accepted) and stale.reason == &"stale_generation", "stale UI input is fenced")
	_check(settings.display_resolution == "2560x1440" and settings.vsync_mode == Settings.VSyncMode.ADAPTIVE and settings.window_mode == Settings.WindowMode.BORDERLESS, "presenter never mutates settings authority")
	presenter.detach()
	_check(not bool(presenter.get_snapshot().attached), "detach clears the presentation")
	for failure in _failures:
		push_error(failure)
	print("runtime_display_settings_presenter_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
