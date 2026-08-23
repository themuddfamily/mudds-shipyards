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
	hud.set_reduced_motion(true)
	hud.set_safe_area_insets(Rect2(24.0, 18.0, 32.0, 20.0))
	var marker := hud.update_offscreen_route_marker(Vector2.RIGHT, 640.0, &"surface_route")
	_check(bool(marker.get("accepted", false)), "HUD exposes accepted offscreen route marker")
	_check(marker.get("marker") == ">>" and marker.get("distance_m") == 640.0, "HUD exposes shape and distance text data")
	_check(bool(marker.get("reduced_motion", false)), "HUD composes its reduced-motion policy")
	_check(hud.get_offscreen_route_marker().get("route_kind") == &"surface_route", "HUD retains caller-readable marker snapshot")
	hud.clear_offscreen_route_marker()
	_check(hud.get_offscreen_route_marker().is_empty(), "HUD clear removes the marker")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_OFFSCREEN_ROUTE_MARKER_TEST_OK (%d assertions)" % _assertions)
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
