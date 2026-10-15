extends SceneTree

const MinimapType := preload("res://scripts/ui/minimap.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class EmptySnapshotDrawWitness extends Minimap:
	var offscreen_draw_count := 0

	func _draw_offscreen_marker(_center: Vector2, _radius: float) -> void:
		offscreen_draw_count += 1


class DistanceTextWitness extends Minimap:
	var calls: Array[Dictionary] = []

	func _draw() -> void:
		calls.clear()
		super._draw()

	func _draw_offscreen_text(font: Font, baseline: Vector2, text: String, color: Color) -> void:
		calls.append({"font": font, "baseline": baseline, "text": text})
		super._draw_offscreen_text(font, baseline, text, color)


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
	var text_witness := DistanceTextWitness.new()
	root.add_child(text_witness)
	await process_frame
	for map_size: Vector2 in [Vector2(180.0, 180.0), Vector2(240.0, 240.0)]:
		text_witness.size = map_size
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
				Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
			for kind: StringName in [&"surface_route", &"landing"]:
				text_witness.present_offscreen_route_marker(direction, 100000.0, kind, true)
				await process_frame
				_check(text_witness.calls.size() == 1, "offscreen distance has one visible readout")
				for call: Dictionary in text_witness.calls:
					var font := call.font as Font
					var ascent := font.get_ascent(MinimapType.OBJECTIVE_FONT_SIZE)
					var dimensions := font.get_string_size(call.text, HORIZONTAL_ALIGNMENT_LEFT,
						-1.0, MinimapType.OBJECTIVE_FONT_SIZE)
					dimensions.y = ascent + font.get_descent(MinimapType.OBJECTIVE_FONT_SIZE)
					var text_rect := Rect2(call.baseline - Vector2(0.0, ascent), dimensions)
					_check(Rect2(Vector2.ZERO, map_size).grow(-MinimapType.OBJECTIVE_TEXT_INSET).encloses(text_rect),
						"%s %s on %s: complete distance stays inside the map frame" % [kind, direction, map_size])
					var marker_point := map_size * 0.5 + direction.normalized() * (minf(map_size.x, map_size.y) * 0.5 - 22.0)
					_check(not text_rect.intersects(Rect2(marker_point - Vector2(8.0, 8.0), Vector2(16.0, 16.0))),
						"fitted distance remains separate from its directional glyph")
					_check(str(call.text).ends_with("100000 M"), "full distance survives fitting")
	text_witness.queue_free()
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
