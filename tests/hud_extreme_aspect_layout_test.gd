extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var cases := [Vector2(7680.0, 1440.0), Vector2(2560.0, 1440.0), Vector2(1280.0, 1024.0), Vector2(1600.0, 1200.0)]
	for requested_scale in [0.75, 1.0, 1.6]:
		hud.set_ui_scale(requested_scale)
		for viewport in cases:
			var effective := hud.layout_for_viewport(viewport)
			var logical: Vector2 = viewport / maxf(effective, 0.01)
			var safe := hud.get_safe_area_insets()
			var status := HudType.compute_runtime_status_panel_rect(viewport, safe, effective)
			_check(status.position.x >= 0.0 and status.end.x <= logical.x + 0.5, "%s status stays within horizontal band at scale %.2f" % [viewport, requested_scale])
			_check(status.position.y >= 0.0 and status.end.y <= logical.y + 0.5, "%s status stays within vertical band at scale %.2f" % [viewport, requested_scale])
	var report := hud.get_hud_panel_rects()
	_check(report.has("objective") and report.has("help") and report.has("telemetry"), "extreme aspect layout retains key readable panels")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_EXTREME_ASPECT_LAYOUT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
