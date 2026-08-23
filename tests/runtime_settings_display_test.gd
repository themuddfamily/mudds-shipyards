extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := Settings.new("user://runtime_settings_display_test.cfg")
	_check(settings.display_resolution == Settings.DEFAULT_DISPLAY_RESOLUTION_ID, "resolution has an authored default")
	_check(settings.vsync_mode == Settings.DEFAULT_VSYNC_MODE, "VSync has an authored default")
	settings.display_resolution = "not-a-resolution"
	_check(settings.display_resolution == Settings.DEFAULT_DISPLAY_RESOLUTION_ID, "unsupported resolution falls back without persistence")
	settings.display_resolution = "2560x1440"
	settings.vsync_mode = Settings.VSyncMode.ADAPTIVE
	var payload := settings.to_user_data_payload()
	var values := payload.values as Dictionary
	_check(values.display_resolution == "2560x1440" and values.vsync_mode == "adaptive", "display values serialize as stable IDs")
	var restored := Settings.new("user://runtime_settings_display_test_restore.cfg")
	_check(bool(restored.apply_user_data_payload(payload).accepted), "current display payload applies atomically")
	_check(restored.display_resolution == "2560x1440" and restored.vsync_mode == Settings.VSyncMode.ADAPTIVE, "display values round-trip")
	var legacy := payload.duplicate(true)
	legacy.schema_version = 7
	(legacy.values as Dictionary).erase("display_resolution")
	(legacy.values as Dictionary).erase("vsync_mode")
	var migrated := Settings.new("user://runtime_settings_display_test_legacy.cfg")
	_check(bool(migrated.apply_user_data_payload(legacy).accepted), "pre-display schema migrates")
	_check(migrated.display_resolution == Settings.DEFAULT_DISPLAY_RESOLUTION_ID and migrated.vsync_mode == Settings.DEFAULT_VSYNC_MODE, "migration uses safe display defaults")
	var resolution_descriptor := restored.get_display_resolution_descriptor()
	_check(resolution_descriptor.id == &"2560x1440" and (resolution_descriptor.supported_ids as PackedStringArray).has("1920x1080"), "resolution descriptor is bounded")
	var vsync_descriptor := restored.get_vsync_descriptor()
	_check(vsync_descriptor.id == &"adaptive" and (vsync_descriptor.supported_ids as PackedStringArray).has("off"), "VSync descriptor exposes supported modes")
	var report := restored.apply_display_settings()
	if DisplayServer.get_name() == "headless":
		_check(not bool(report.applied) and report.reason == &"headless", "headless startup reports display as not applied")
	else:
		_check(bool(report.applied), "desktop startup applies display settings")
	for path in ["user://runtime_settings_display_test.cfg", "user://runtime_settings_display_test_restore.cfg", "user://runtime_settings_display_test_legacy.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure in _failures:
		push_error(failure)
	print("runtime_settings_display_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
