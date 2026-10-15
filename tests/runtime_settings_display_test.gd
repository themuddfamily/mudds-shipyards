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
	# A historical payload contains only fields introduced by that schema.
	for later_field in ["high_contrast_hud", "reticle_style", "limit_ultrawide_fov", "on_foot_first_person"]:
		(legacy.values as Dictionary).erase(later_field)
	(legacy.values as Dictionary).erase("display_resolution")
	(legacy.values as Dictionary).erase("vsync_mode")
	var migrated := Settings.new("user://runtime_settings_display_test_legacy.cfg")
	_check(bool(migrated.apply_user_data_payload(legacy).accepted), "pre-display schema migrates")
	_check(migrated.display_resolution == Settings.DEFAULT_DISPLAY_RESOLUTION_ID and migrated.vsync_mode == Settings.DEFAULT_VSYNC_MODE, "migration uses safe display defaults")
	var resolution_descriptor := restored.get_display_resolution_descriptor()
	_check(resolution_descriptor.id == &"2560x1440" and (resolution_descriptor.supported_ids as PackedStringArray).has("1920x1080"), "resolution descriptor is bounded")
	var vsync_descriptor := restored.get_vsync_descriptor()
	_check(vsync_descriptor.id == &"adaptive" and (vsync_descriptor.supported_ids as PackedStringArray).has("off"), "VSync descriptor exposes supported modes")
	var usable := Rect2i(0, 0, 1600, 1000)
	var fitted := Settings.fit_window_to_usable_rect(Rect2i(160, 500, 1920, 1080), usable, Vector2i(5, 30), Vector2i(10, 35))
	_check(fitted == Rect2i(5, 30, 1590, 965), "oversized saved resolution fits usable desktop including window decorations")
	var visible := Rect2i(200, 100, 1280, 720)
	_check(Settings.fit_window_to_usable_rect(visible, usable, Vector2i(5, 30), Vector2i(10, 35)) == visible, "fully visible windows retain their size and position")
	_check(Settings.fit_window_to_usable_rect(Rect2i(-100, 500, 1280, 720), Rect2i(-1600, 0, 1600, 1000)) == Rect2i(-1280, 280, 1280, 720), "offscreen placement recovers on monitors with negative origins")
	_check(Settings.fit_window_to_usable_rect(visible, Rect2i()) == visible, "unavailable screen bounds do not fabricate a window placement")
	var original_vsync := DisplayServer.VSYNC_ENABLED
	var original_size := Vector2i.ZERO
	var original_position := Vector2i.ZERO
	var original_window_mode := DisplayServer.WINDOW_MODE_WINDOWED
	var original_borderless := false
	if DisplayServer.get_name() != "headless":
		original_vsync = DisplayServer.window_get_vsync_mode()
		original_size = DisplayServer.window_get_size()
		original_position = DisplayServer.window_get_position()
		original_window_mode = DisplayServer.window_get_mode()
		original_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var desktop := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		DisplayServer.window_set_position(desktop.end - Vector2i(40, 40))
	var report := restored.apply_display_settings()
	if DisplayServer.get_name() == "headless":
		_check(not bool(report.applied) and report.reason == &"headless" \
			and not bool(report.vsync_applied), "headless startup reports display as not applied")
	else:
		# Exercise the live display only after its pending resize has presented.
		await process_frame
		await RenderingServer.frame_post_draw
		_check(bool(report.applied), "desktop startup applies display settings")
		var desktop := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var window_frame := Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())
		_check(desktop.encloses(window_frame), "actual window recovers fully inside the usable desktop")
		_check(restored.display_resolution == "2560x1440" and report.resolution.id == &"2560x1440", "desktop fitting preserves the desired resolution and report")
		# Adaptive may legitimately fall back to enabled on this backend. Exercise
		# exact live-state idempotence with the supported enabled/disabled modes.
		restored.vsync_mode = Settings.VSyncMode.ON
		var before_on := DisplayServer.window_get_vsync_mode()
		var enabled := restored.apply_display_settings()
		_check(bool(enabled.vsync_applied) == (before_on != DisplayServer.VSYNC_ENABLED)
			and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED,
			"display application changes VSync only when the live window differs")
		var repeated := restored.apply_display_settings()
		_check(bool(repeated.applied) and not bool(repeated.vsync_applied),
			"reapplying matching display settings does not request another VSync resize")
		var superseded_generation := int(restored.get("_display_apply_generation"))
		restored.apply_display_settings()
		var latest_size := DisplayServer.window_get_size()
		restored.call("_refit_display_window_after_frame", DisplayServer.MAIN_WINDOW_ID, Vector2i(1280, 720), superseded_generation)
		_check(DisplayServer.window_get_size() == latest_size, "stale deferred preview cannot resize a newer display application")
		restored.vsync_mode = Settings.VSyncMode.OFF
		var changed := restored.apply_display_settings()
		_check(bool(changed.vsync_applied) and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
			"a genuinely changed VSync preference still reaches the live window")
		var changed_repeat := restored.apply_display_settings()
		_check(not bool(changed_repeat.vsync_applied), "the changed preference also skips redundant application")
		# A separate live owner can change the window without changing this settings
		# object. The next application must observe that change, not a cached value.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		var corrected := restored.apply_display_settings()
		_check(bool(corrected.vsync_applied) and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
			"unchanged preferences correct an external live VSync change")
		restored.window_mode = Settings.WindowMode.BORDERLESS
		restored.apply_window_mode()
		DisplayServer.window_set_position(desktop.end - Vector2i(40, 40))
		restored.apply_display_settings()
		await process_frame
		await RenderingServer.frame_post_draw
		window_frame = Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())
		var borderless_client := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		var borderless_expected := Settings.fit_window_to_usable_rect(
			Rect2i(borderless_client.position, Vector2i(2560, 1440)), desktop,
			borderless_client.position - window_frame.position, window_frame.size - borderless_client.size
		)
		var borderless_fits := (DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
			and borderless_client.size == borderless_expected.size
			and desktop.encloses(window_frame) and restored.display_resolution == "2560x1440")
		if not borderless_fits:
			print("BORDERLESS_FIT_DIAGNOSTIC expected=%s client=%s decorated=%s frame_extra=%s borderless=%s usable=%s" % [
				borderless_expected,
				Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()),
				window_frame,
				DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size(),
				DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), desktop,
			])
		_check(borderless_fits, "borderless display applies the same usable-screen fit")
		restored.window_mode = Settings.WindowMode.FULLSCREEN
		restored.apply_window_mode()
		restored.apply_display_settings()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "display fitting leaves fullscreen owned by the backend")
		restored.window_mode = Settings.WindowMode.WINDOWED
		restored.apply_window_mode()
		restored.apply_display_settings()
		await process_frame
		await RenderingServer.frame_post_draw
		window_frame = Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())
		var windowed_fits := (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
			and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
			and desktop.encloses(window_frame))
		if not windowed_fits:
			var windowed_client := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
			print("WINDOWED_RETURN_DIAGNOSTIC mode=%s borderless=%s client=%s decorated=%s usable=%s frame_offset=%s frame_extra=%s" % [
				DisplayServer.window_get_mode(), DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
				windowed_client, window_frame, desktop,
				windowed_client.position - window_frame.position, window_frame.size - windowed_client.size,
			])
		_check(windowed_fits, "fullscreen return recovers a fully visible ordinary window")
		_check(restored.display_resolution == "2560x1440", "mode transitions preserve the desired resolution")
		DisplayServer.window_set_vsync_mode(original_vsync)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, original_borderless)
		if DisplayServer.window_get_mode() != original_window_mode:
			DisplayServer.window_set_mode(original_window_mode)
		if DisplayServer.window_get_size() != original_size:
			DisplayServer.window_set_size(original_size)
		if DisplayServer.window_get_position() != original_position:
			DisplayServer.window_set_position(original_position)
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
