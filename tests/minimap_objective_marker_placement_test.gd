extends SceneTree

## An objective marker's glyph is its only on-map mark, so it must sit on the
## projected world position, and its glyph, label and distance must stay inside
## the minimap's clipped rectangle wherever the objective lies -- including a
## target due east that is clamped to the rim.

const MAP_SIZE := Vector2(240.0, 240.0)
const RANGE_METERS := 1000.0
const PLACEMENT_TOLERANCE_PX := 2.0

var _assertions := 0
var _failures: PackedStringArray = []


class ObjectiveTextWitness extends Minimap:
	var calls: Array[Dictionary] = []

	func _draw() -> void:
		calls.clear()
		super._draw()

	func _draw_objective_text(font: Font, baseline: Vector2, text: String, color: Color) -> void:
		calls.append({"font": font, "baseline": baseline, "text": text})
		super._draw_objective_text(font, baseline, text, color)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var map := ObjectiveTextWitness.new()
	map.size = MAP_SIZE
	root.add_child(map)
	await process_frame
	map.size = MAP_SIZE
	var cases := [
		{"name": "north in range", "position": Vector3(0.0, 0.0, -500.0)},
		{"name": "west in range", "position": Vector3(-700.0, 0.0, 0.0)},
		{"name": "east in range", "position": Vector3(800.0, 0.0, 0.0)},
		{"name": "east beyond range", "position": Vector3(5000.0, 0.0, 0.0)},
		{"name": "south-east beyond range", "position": Vector3(3000.0, 0.0, 3000.0)},
	]
	for marker_case: Dictionary in cases:
		await _check_case(map, marker_case)
	map.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MINIMAP_OBJECTIVE_MARKER_PLACEMENT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_case(map: ObjectiveTextWitness, marker_case: Dictionary) -> void:
	var world := marker_case["position"] as Vector3
	_check(map.apply_snapshot({
		"schema_version": 1,
		"range_meters": RANGE_METERS,
		"center_position": Vector3.ZERO,
		"player_position": Vector3.ZERO,
		"heading_radians": 0.0,
		"objective_markers": [
			{"id": &"active_route_checkpoint", "position": world, "generation": 1},
		],
	}), "%s: the marker snapshot is accepted" % marker_case["name"])
	map.queue_redraw()
	await process_frame
	var center := MAP_SIZE * 0.5
	var radius := minf(MAP_SIZE.x, MAP_SIZE.y) * 0.5 - 8.0
	# North (-Z) is up and east (+X) is right. A target beyond range is clamped
	# inside the rim so the frame ring cannot cover it.
	var projected := Vector2(world.x, world.z) * (radius / RANGE_METERS)
	var rim := radius - Minimap.OBJECTIVE_RIM_INSET
	if projected.length() > rim:
		projected = projected.normalized() * rim
	var expected := center + projected
	var glyph := "◎"
	var bounds := Rect2(Vector2.ZERO, MAP_SIZE)
	var glyph_center := Vector2.INF
	var all_inside := not map.calls.is_empty()
	var outside: PackedStringArray = []
	for call: Dictionary in map.calls:
		var font := call["font"] as Font
		var baseline := call["baseline"] as Vector2
		var text := str(call["text"])
		var ascent := font.get_ascent(Minimap.OBJECTIVE_FONT_SIZE)
		var height := ascent + font.get_descent(Minimap.OBJECTIVE_FONT_SIZE)
		var width := font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Minimap.OBJECTIVE_FONT_SIZE
		).x
		var rect := Rect2(baseline - Vector2(0.0, ascent), Vector2(width, height))
		if not bounds.encloses(rect):
			all_inside = false
			outside.append("'%s' %s" % [text, rect])
		if text.begins_with(glyph) and glyph_center == Vector2.INF:
			var glyph_width := font.get_string_size(
				glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Minimap.OBJECTIVE_FONT_SIZE
			).x
			glyph_center = Vector2(baseline.x + glyph_width * 0.5, rect.get_center().y)
	_check(
		glyph_center.is_finite() and glyph_center.distance_to(expected) <= PLACEMENT_TOLERANCE_PX,
		"%s: the marker glyph is centred on the projected position %s (drawn at %s)"
		% [marker_case["name"], expected, glyph_center]
	)
	_check(
		all_inside,
		"%s: glyph, label and distance stay inside the minimap %s"
		% [marker_case["name"], ", ".join(outside)]
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
