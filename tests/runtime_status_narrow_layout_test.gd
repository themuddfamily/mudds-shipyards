extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var rect := HudType.compute_runtime_status_panel_rect(
		Vector2(1280.0, 720.0), Rect2(18.0, 14.0, 22.0, 16.0), 1.0
	)
	_check(rect.size.x >= 460.0, "minimum viewport keeps status text width")
	_check(rect.size.y == 300.0, "minimum viewport retains readable status height")
	var safe_center := Vector2(18.0 + (1280.0 - 18.0 - 22.0) * 0.5, 14.0 + (720.0 - 14.0 - 16.0) * 0.5)
	_check(rect.get_center().is_equal_approx(safe_center), "panel centers inside narrow safe area")
	_check(rect.position.x >= 18.0 and rect.end.x <= 1280.0 - 22.0, "narrow panel stays inside horizontal safe bounds")
	_check(rect.position.y >= 14.0 and rect.end.y <= 720.0 - 16.0, "narrow panel stays inside vertical safe bounds")
	var scaled := HudType.compute_runtime_status_panel_rect(
		Vector2(1280.0, 720.0), Rect2(18.0, 14.0, 22.0, 16.0), 1.25
	)
	_check(scaled.size.x >= 460.0 and scaled.size.y == 300.0, "text-scale layout remains bounded")
	if _failures.is_empty():
		print("RUNTIME_STATUS_NARROW_LAYOUT_TEST_OK (%d assertions)" % _assertions)
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
