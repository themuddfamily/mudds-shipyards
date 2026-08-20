class_name FlightPathCue
extends Control

## Screen-space velocity cue. The fixed HUD reticle remains the weapon/nose
## datum; this separate hollow marker shows where the craft is actually moving.

const INK := Color("07111d")
const CYAN_SOFT := Color("a9f7f5")
const AMBER := Color("ffb85c")

const SAFE_HORIZONTAL_VIEWPORT_RATIO := 0.27
const SAFE_HORIZONTAL_ASPECT_LIMIT := 0.52
const SAFE_VERTICAL_VIEWPORT_RATIO := 0.18
const CONNECTOR_THRESHOLD := 56.0
const MARKER_RADIUS := 10.0

var _piloting := false
var _marker_visible := false
var _marker_position := Vector2.ZERO
var _clamped := false
var _rearward := false
var _alignment := 0.0
var _camera_view: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	visible = false


func set_piloting(enabled: bool) -> void:
	if not _can_mutate_live_cue():
		return
	_piloting = enabled
	if not enabled:
		clear()


func update_from_telemetry(data: Dictionary) -> void:
	if not _can_mutate_live_cue():
		return
	var position_value: Variant = data.get("flight_path_screen_position", Vector2.ZERO)
	var has_valid_position := position_value is Vector2 and (position_value as Vector2).is_finite()
	_marker_visible = _piloting and bool(data.get("flight_path_visible", false)) and has_valid_position
	_marker_position = position_value as Vector2 if has_valid_position else Vector2.ZERO
	_clamped = bool(data.get("flight_path_clamped", false))
	_rearward = bool(data.get("flight_path_rearward", false))
	_alignment = clampf(float(data.get("flight_path_alignment", 0.0)), -1.0, 1.0)
	_camera_view = StringName(data.get("camera_view", &""))
	visible = _marker_visible
	queue_redraw()


func clear() -> void:
	if not _can_mutate_live_cue():
		return
	_marker_visible = false
	_marker_position = Vector2.ZERO
	_clamped = false
	_rearward = false
	_alignment = 0.0
	_camera_view = &""
	visible = false
	queue_redraw()


func _can_mutate_live_cue() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_audit_report() -> Dictionary:
	var viewport_size := _logical_viewport_size()
	var center := viewport_size * 0.5
	var radii := _safe_radii(viewport_size)
	return {
		"valid": true,
		"errors": PackedStringArray(),
		"schema_version": 1,
		"layer_visible": visible,
		"marker_visible": _marker_visible and visible,
		"visible": _marker_visible and visible,
		"marker_position": _marker_position,
		"screen_position": _marker_position,
		"connector_visible": _should_draw_connector(center),
		"clamped": _clamped,
		"rearward": _rearward,
		"visual_state": &"rearward" if _rearward else (&"clamped" if _clamped else &"forward"),
		"alignment": _alignment,
		"camera_view": _camera_view,
		"safe_center": center,
		"safe_radii": radii,
		"safe_rect": Rect2(center - radii, radii * 2.0),
		"mouse_passthrough": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"mouse_filter_ignored": mouse_filter == Control.MOUSE_FILTER_IGNORE,
	}


func _draw() -> void:
	if not _marker_visible:
		return
	var center := _logical_viewport_size() * 0.5
	if _rearward:
		_draw_reverse_marker(_marker_position)
		return
	if _should_draw_connector(center):
		_draw_connector(center, _marker_position)
	_draw_forward_marker(_marker_position, center)


func _draw_connector(center: Vector2, marker: Vector2) -> void:
	var direction := (marker - center).normalized()
	var start := center + direction * 29.0
	var finish := marker - direction * 22.0
	if start.distance_squared_to(finish) <= 1.0:
		return
	draw_line(start, finish, Color(INK, 0.62), 5.0, true)
	draw_line(start, finish, Color(CYAN_SOFT, 0.34), 1.5, true)


func _draw_forward_marker(marker: Vector2, center: Vector2) -> void:
	draw_arc(marker, MARKER_RADIUS, 0.0, TAU, 32, INK, 6.0, true)
	draw_arc(marker, MARKER_RADIUS, 0.0, TAU, 32, CYAN_SOFT, 2.2, true)
	var strokes: Array[PackedVector2Array] = [
		PackedVector2Array([marker + Vector2(-21.0, 0.0), marker + Vector2(-10.0, 0.0)]),
		PackedVector2Array([marker + Vector2(10.0, 0.0), marker + Vector2(21.0, 0.0)]),
		PackedVector2Array([marker + Vector2(0.0, -20.0), marker + Vector2(0.0, -10.0)]),
	]
	for stroke in strokes:
		draw_polyline(stroke, INK, 6.0, true)
		draw_polyline(stroke, CYAN_SOFT, 2.2, true)
	if _clamped:
		var outward := (_marker_position - center).normalized()
		if outward.is_zero_approx():
			outward = Vector2.UP
		var perpendicular := outward.orthogonal()
		var arrow := PackedVector2Array([
			marker + outward * 18.0,
			marker + outward * 10.0 + perpendicular * 4.5,
			marker + outward * 10.0 - perpendicular * 4.5,
		])
		draw_colored_polygon(arrow, INK)
		var inset_arrow := PackedVector2Array([
			marker + outward * 16.0,
			marker + outward * 11.5 + perpendicular * 2.6,
			marker + outward * 11.5 - perpendicular * 2.6,
		])
		draw_colored_polygon(inset_arrow, CYAN_SOFT)


func _draw_reverse_marker(marker: Vector2) -> void:
	var upper := PackedVector2Array([
		marker + Vector2(-13.0, -11.0),
		marker + Vector2(0.0, 1.0),
		marker + Vector2(13.0, -11.0),
	])
	var lower := PackedVector2Array([
		marker + Vector2(-13.0, 0.0),
		marker + Vector2(0.0, 12.0),
		marker + Vector2(13.0, 0.0),
	])
	for chevron in [upper, lower]:
		draw_polyline(chevron, INK, 7.0, true)
		draw_polyline(chevron, AMBER, 2.5, true)
	var label_rect := Rect2(marker + Vector2(-23.0, -39.0), Vector2(46.0, 18.0))
	draw_rect(label_rect, Color(INK, 0.88), true)
	draw_string(
		ThemeDB.fallback_font,
		marker + Vector2(-23.0, -25.0),
		"REV",
		HORIZONTAL_ALIGNMENT_CENTER,
		46.0,
		12,
		AMBER
	)


func _should_draw_connector(center: Vector2) -> bool:
	return (
		_marker_visible
		and not _rearward
		and center.distance_to(_marker_position) > CONNECTOR_THRESHOLD
	)


func _logical_viewport_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if get_viewport() != null:
		return get_viewport().get_visible_rect().size
	return Vector2.ZERO


func _safe_radii(viewport_size: Vector2) -> Vector2:
	return Vector2(
		minf(
			viewport_size.x * SAFE_HORIZONTAL_VIEWPORT_RATIO,
			viewport_size.y * SAFE_HORIZONTAL_ASPECT_LIMIT
		),
		viewport_size.y * SAFE_VERTICAL_VIEWPORT_RATIO
	)
