class_name DebugOverlay
extends PanelContainer

## Screenshot-oriented F3 diagnostics. GameFlow supplies read-only world state;
## this presenter owns only formatting and display.

const SCHEMA_VERSION := 1

var _readout: Label
var _snapshot: Dictionary = {}


func _ready() -> void:
	name = "DebugOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(18.0, 18.0)
	size.x = 680.0
	custom_minimum_size = Vector2(680.0, 0.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.02, 0.025, 0.88)
	panel_style.border_color = Color(0.32, 0.9, 1.0, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 9.0
	panel_style.content_margin_bottom = 9.0
	add_theme_stylebox_override("panel", panel_style)

	_readout = Label.new()
	_readout.name = "Readout"
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.clip_text = true
	_readout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var debug_font := SystemFont.new()
	debug_font.font_names = PackedStringArray([
		"JetBrains Mono", "DejaVu Sans Mono", "Consolas", "monospace",
	])
	_readout.add_theme_font_override("font", debug_font)
	_readout.add_theme_font_size_override("font_size", 13)
	_readout.add_theme_color_override("font_color", Color("d9f7ff"))
	_readout.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_readout.add_theme_constant_override("shadow_offset_x", 1)
	_readout.add_theme_constant_override("shadow_offset_y", 1)
	_readout.text = "MUDDS SHIPYARDS DEBUG  [F3]"
	add_child(_readout)


func present(snapshot: Dictionary) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_snapshot = snapshot.duplicate(true)
	_readout.text = format_snapshot(_snapshot)


func get_report() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"visible": visible,
		"mouse_passthrough": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"text": _readout.text if is_instance_valid(_readout) else "",
		"snapshot": _snapshot.duplicate(true),
	}.duplicate(true)


static func format_snapshot(snapshot: Dictionary) -> String:
	var viewport_size := snapshot.get("viewport_size", Vector2i.ZERO) as Vector2i
	var actor_position := snapshot.get("actor_position", Vector3.ZERO) as Vector3
	var actor_velocity := snapshot.get("actor_velocity", Vector3.ZERO) as Vector3
	var camera_position := snapshot.get("camera_position", Vector3.ZERO) as Vector3
	var camera_forward := snapshot.get("camera_forward", Vector3.FORWARD) as Vector3
	var lines := PackedStringArray([
		"MUDDS SHIPYARDS DEBUG  [F3]",
		"%s  //  %s  //  %s" % [
			str(snapshot.get("mode", "UNKNOWN")),
			str(snapshot.get("phase", "UNKNOWN")),
			str(snapshot.get("actor_name", "UNKNOWN")),
		],
		"Actor XYZ (scene m)  %s" % _vector3(actor_position, 3),
		"Velocity (m/s)       %s  |  speed %.2f" % [
			_vector3(actor_velocity, 2), actor_velocity.length(),
		],
		"Camera XYZ (scene m) %s  |  FOV %.1f" % [
			_vector3(camera_position, 3), float(snapshot.get("camera_fov", 0.0)),
		],
		"Facing %-10s yaw %7.2f  pitch %7.2f  |  look %s" % [
			str(snapshot.get("facing", "UNKNOWN")),
			float(snapshot.get("yaw_degrees", 0.0)),
			float(snapshot.get("pitch_degrees", 0.0)),
			_vector3(camera_forward, 3),
		],
	])

	if bool(snapshot.get("aim_hit", false)):
		lines.append("Aim hit  %s" % str(snapshot.get("aim_collider", "UNKNOWN")))
		lines.append("Hit XYZ (scene m)    %s  |  %.2f m away" % [
			_vector3(snapshot.get("aim_position", Vector3.ZERO) as Vector3, 3),
			float(snapshot.get("aim_distance", 0.0)),
		])
		var aim_absolute := snapshot.get("aim_absolute_coordinate", {}) as Dictionary
		if not aim_absolute.is_empty():
			lines.append("Hit absolute cell     %d / %d / %d" % [
				int(aim_absolute.get("cell_x", 0)),
				int(aim_absolute.get("cell_y", 0)),
				int(aim_absolute.get("cell_z", 0)),
			])
			lines.append("Hit absolute offset   %s" % _vector3(
				aim_absolute.get("offset_meters", Vector3.ZERO) as Vector3, 3
			))
	else:
		lines.append("Aim hit  NONE  |  ray endpoint %s" % _vector3(
			snapshot.get("aim_endpoint", Vector3.ZERO) as Vector3, 3
		))

	var absolute := snapshot.get("absolute_coordinate", {}) as Dictionary
	if not absolute.is_empty():
		lines.append("Actor absolute cell   %d / %d / %d  |  frame %d" % [
			int(absolute.get("cell_x", 0)),
			int(absolute.get("cell_y", 0)),
			int(absolute.get("cell_z", 0)),
			int(snapshot.get("coordinate_frame_generation", 0)),
		])
		lines.append("Actor absolute offset %s" % _vector3(
			absolute.get("offset_meters", Vector3.ZERO) as Vector3, 3
		))

	lines.append("Actor %s  |  Camera %s" % [
		str(snapshot.get("actor_path", "UNKNOWN")),
		str(snapshot.get("camera_path", "UNKNOWN")),
	])
	lines.append("FPS %d  |  frame %d  |  viewport %dx%d" % [
		int(snapshot.get("fps", 0)),
		int(snapshot.get("frame", 0)),
		viewport_size.x,
		viewport_size.y,
	])
	return "\n".join(lines)


static func _vector3(value: Vector3, decimals: int) -> String:
	var pattern := "%%.%df / %%.%df / %%.%df" % [decimals, decimals, decimals]
	return pattern % [value.x, value.y, value.z]
