extends SceneTree

## Focused proof for the user-facing F2 screenshot path. It injects a small CPU
## image so the route is deterministic in headless CI while production captures
## the post-draw viewport texture.

var _failures: Array[String] = []
var _written_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := GameHUD.new()
	hud.name = "ScreenshotCaptureHud"
	root.add_child(hud)
	await process_frame

	var image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.15, 0.55, 0.9, 1.0))
	hud.set("_screenshot_image_provider_for_test", func() -> Image: return image)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F2
	event.pressed = true
	_check(
		event.is_action_pressed(GameHUD.SCREENSHOT_ACTION)
		and bool(hud.call("_is_screenshot_capture_event", event)),
		"the checked-in capture action binds physical F2 and accepts its fresh press"
	)
	var toast_serial_before_rebind := int(hud.get("_toast_serial"))
	hud.set("_binding_capture_action", &"move_forward")
	hud._unhandled_input(event)
	var binding_report := hud.get_input_binding_report()
	_check(
		int(hud.get("_toast_serial")) == toast_serial_before_rebind
		and StringName(binding_report.get("capturing_action", &"")) == &""
		and bool(binding_report.get("has_pending_conflict", false)),
		"an active settings rebind receives reserved F2 through its normal conflict path without starting a screenshot capture"
	)

	hud._unhandled_input(event)
	await process_frame
	var first_path := _toast_detail(hud)
	_written_paths.append(first_path)
	_check(
		_toast_title(hud) == "SCREENSHOT SAVED"
		and first_path.begins_with(ProjectSettings.globalize_path("user://screenshots"))
		and FileAccess.file_exists(first_path),
		"F2 writes the supplied viewport image into the stable user screenshots folder and confirms its path"
	)
	var saved := Image.load_from_file(first_path)
	_check(
		saved != null and saved.get_size() == Vector2i(3, 2),
		"the saved PNG retains the injected viewport image dimensions"
	)

	var second := hud.call("_save_screenshot_image", image) as Dictionary
	var second_path := str(second.get("path", ""))
	_written_paths.append(second_path)
	_check(
		bool(second.get("accepted", false))
		and not second_path.is_empty()
		and second_path != first_path
		and FileAccess.file_exists(second_path),
		"successive captures reserve collision-safe unique filenames"
	)

	hud.call("_show_screenshot_capture_result", {"accepted": false, "detail": "test write failure"})
	_check(
		_toast_title(hud) == "SCREENSHOT FAILED"
		and _toast_detail(hud) == "test write failure",
		"a write failure is surfaced through the visible HUD toast"
	)

	event.echo = true
	_check(
		not bool(hud.call("_is_screenshot_capture_event", event)),
		"F2 key-repeat events do not queue duplicate screenshot captures"
	)

	for path in _written_paths:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	hud.queue_free()
	await process_frame
	_finish()


func _toast_title(hud: GameHUD) -> String:
	var label := hud.get("_toast_title") as Label
	return label.text if label != null else ""


func _toast_detail(hud: GameHUD) -> String:
	var label := hud.get("_toast_detail") as Label
	return label.text if label != null else ""


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SCREENSHOT_CAPTURE_TEST_OK")
		quit(0)
		return
	print("SCREENSHOT_CAPTURE_TEST_FAILED: ", ", ".join(_failures))
	quit(1)
