extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const Contract := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	for viewport in [Vector2(1920, 1080), Vector2(1920, 1200), Vector2(2560, 1080), Vector2(5120, 1440)]:
		for requested_scale in [0.75, 1.0, 1.6]:
			hud.set_ui_scale(requested_scale)
			hud.layout_for_viewport(viewport)
			await process_frame
			var effective := hud.get_effective_ui_scale()
			var safe := Contract.safe_rect(viewport, effective)
			var rects := hud.get_hud_panel_rects()
			for key in [&"brand", &"help", &"telemetry", &"minimap"]:
				var logical_panel := rects.get(key, Rect2()) as Rect2
				var panel := Rect2(logical_panel.position * effective, logical_panel.size * effective)
				_check(safe.intersects(panel) and Rect2(Vector2.ZERO, viewport).encloses(panel), "%s remains in the readable safe band at %s scale %.2f" % [key, Contract.classify_viewport(viewport), requested_scale])
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_ULTRAWIDE_SAFE_AREA_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
