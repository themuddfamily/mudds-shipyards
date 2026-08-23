extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var standard := HudType.compute_runtime_status_panel_rect(
		Vector2(1920.0, 1080.0), Rect2(), 1.0
	)
	var ultrawide := HudType.compute_runtime_status_panel_rect(
		Vector2(3440.0, 1440.0), Rect2(28.0, 0.0, 40.0, 0.0), 1.0
	)
	_check(standard.size.x >= 460.0 and standard.size.x <= 680.0, "16:9 status panel stays readable")
	_check(ultrawide.size.x > standard.size.x, "21:9 status panel gains text width")
	_check(ultrawide.size.x <= 680.0, "ultrawide width remains bounded")
	var logical_width := 3440.0 - 28.0 - 40.0
	_check(
		ultrawide.position.x >= 28.0 and ultrawide.end.x <= logical_width,
		"ultrawide status panel remains inside safe horizontal bounds"
	)
	if _failures.is_empty():
		print("RUNTIME_STATUS_ULTRAWIDE_LAYOUT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
