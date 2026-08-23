extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _path := "user://reduced_flash_settings_%d.cfg" % Time.get_ticks_usec()

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var settings := Settings.new(_path)
	_check(not settings.reduced_flash, "reduced flash defaults off")
	settings.reduced_flash = true
	_check(settings.reduced_flash and settings.save_to_file() == OK, "reduced flash accepts and persists the setting")
	var restored := Settings.new(_path)
	_check(restored.load_from_file() == OK and restored.reduced_flash, "reduced flash round-trips through the settings store")
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	var control := controls.get(&"reduced_flash") as CheckButton
	_check(control != null and control.focus_mode == Control.FOCUS_ALL, "reduced flash is a labelled controller-focusable setting")
	hud.set_settings_snapshot({"reduced_flash": true})
	_check(bool(control.button_pressed) and is_equal_approx(hud.get_damage_flash_alpha(), HudType.REDUCED_DAMAGE_FLASH_ALPHA), "snapshot enables reduced flash without removing semantic cues")
	hud.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	if _failures.is_empty():
		print("REDUCED_FLASH_SETTINGS_UI_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
