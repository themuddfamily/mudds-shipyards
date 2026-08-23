extends SceneTree

const MinimapType := preload("res://scripts/ui/minimap.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class EmptySnapshotDrawWitness extends Minimap:
	var offscreen_draw_count := 0

	func _draw_offscreen_marker(_center: Vector2, _radius: float) -> void:
		offscreen_draw_count += 1


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var route := MinimapType.get_offscreen_marker_presentation(
		Vector2(4.0, -3.0), 420.0, &"surface_route", true
	)
	_check(bool(route.get("accepted", false)), "offscreen route marker accepts typed direction")
	_check(route.marker == ">>" and route.distance_m == 420.0, "route marker carries shape and distance")
	_check(bool(route.reduced_motion), "reduced-motion state is retained without animation authority")
	var landing := MinimapType.get_offscreen_marker_presentation(
		Vector2(-1.0, 0.0), 80.0, &"landing"
	)
	_check(landing.marker == "△", "landing marker uses a distinct shape")
	var invalid := MinimapType.get_offscreen_marker_presentation(
		Vector2.ZERO, 10.0, &"landing"
	)
	_check(invalid.get("reason") == &"invalid_direction", "zero direction is rejected")
	_check(
		MinimapType.get_offscreen_marker_presentation(Vector2.UP, -1.0, &"landing").get("reason")
			== &"invalid_distance",
		"negative distance is rejected"
	)
	var draw_witness := EmptySnapshotDrawWitness.new()
	draw_witness.size = Vector2(180.0, 180.0)
	root.add_child(draw_witness)
	draw_witness.present_offscreen_route_marker(Vector2.DOWN, 275.0, &"surface_route", true)
	await process_frame
	_check(
		draw_witness.get_snapshot().is_empty() and draw_witness.offscreen_draw_count > 0,
		"retained offscreen guidance draws even while the topology snapshot is empty"
	)
	draw_witness.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MINIMAP_OFFSCREEN_ROUTE_MARKER_TEST_OK (%d assertions)" % _assertions)
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
