extends SceneTree

## Ultrawide and 4:3 displays must receive the full window, not 16:9 bars,
## while the headless runner keeps the project default so every layout suite
## still measures the 1600 x 900 test viewport.
const StartupLoaderType := preload("res://scripts/game/startup_loader.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		StartupLoaderType.stretch_aspect_for_display("headless") == Window.CONTENT_SCALE_ASPECT_KEEP,
		"headless runs keep the project default aspect so test viewports stay 1600 x 900"
	)
	for display in ["Windows", "X11", "Wayland", "macOS"]:
		_check(
			StartupLoaderType.stretch_aspect_for_display(display) == Window.CONTENT_SCALE_ASPECT_EXPAND,
			"%s displays expand the content to the window aspect" % display
		)
	var boot: Node = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	_check(
		root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP
			and root.get_visible_rect().size.is_equal_approx(Vector2(1600, 900)),
		"booting under the headless runner leaves the 1600 x 900 viewport untouched"
	)
	boot.queue_free()
	await process_frame
	if _failures.is_empty():
		print("DISPLAY_STRETCH_POLICY_TEST_OK")
		quit(0)
	else:
		push_error("DISPLAY_STRETCH_POLICY_TEST_FAILED: " + "; ".join(_failures))
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
