class_name Minimap
extends Control

## Presentation-only, top-down minimap. The control consumes detached scalar
## snapshots and never reads or mutates world nodes. Vector3 positions are
## projected north-up on X/Z: north is world -Z and east is world +X.
## `heading_radians` rotates only the player marker clockwise from north
## (0 faces -Z, PI/2 faces +X); topology never spins beneath the player.

const SNAPSHOT_SCHEMA_VERSION := 1
const MIN_RANGE_METERS := 25.0
const MAX_RANGE_METERS := 100000.0
const MAX_TOPOLOGY_NODES := 512
const MAX_TOPOLOGY_EDGES := 1024
const MAX_CONTACTS := 256
const MAX_OBJECTIVE_MARKERS := 32

const INK := Color("07111d")
const GLASS := Color("0b1c2ae6")
const GRID := Color("5e9aa048")
const CYAN := Color("a9f7f5")
const AMBER := Color("ffb85c")
const RED := Color("ff667d")
const MUTED := Color("72949b")

var _snapshot: Dictionary = {}
var _warnings := PackedStringArray()
var _revision := 0
var _nominal_color := CYAN
var _caution_color := AMBER
var _danger_color := RED
var _muted_color := MUTED
var _offscreen_marker: Dictionary = {}
var _marker_generations: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(180.0, 180.0)
	resized.connect(queue_redraw)


## Atomically applies one presentation snapshot. Invalid root metadata or
## non-finite core navigation values reject the update and retain the previous
## snapshot. Malformed bounded roster entries are safely omitted and reported.
func apply_snapshot(raw_snapshot: Dictionary) -> bool:
	var sanitized := _sanitize_snapshot(raw_snapshot)
	if not bool(sanitized.get("accepted", false)):
		return false
	_snapshot = (sanitized.get("snapshot", {}) as Dictionary).duplicate(true)
	_warnings = (sanitized.get("warnings", PackedStringArray()) as PackedStringArray).duplicate()
	_revision += 1
	queue_redraw()
	return true


## Compatibility-friendly presenter name for callers that stream HUD data.
func present_snapshot(snapshot: Dictionary) -> bool:
	return apply_snapshot(snapshot)


## Accepts the HUD's already validated semantic palette. Contact allegiance is
## still encoded by shape, so colour is never the only way to distinguish it.
func set_palette(palette: Dictionary) -> bool:
	for role in [&"nominal", &"caution", &"danger", &"muted"]:
		if not (palette.get(role) is Color):
			return false
	_nominal_color = palette[&"nominal"] as Color
	_caution_color = palette[&"caution"] as Color
	_danger_color = palette[&"danger"] as Color
	_muted_color = palette[&"muted"] as Color
	queue_redraw()
	return true


func clear() -> void:
	_snapshot.clear()
	_offscreen_marker.clear()
	_warnings.clear()
	_marker_generations.clear()
	_revision += 1
	queue_redraw()


func clear_offscreen_route_marker() -> void:
	_offscreen_marker.clear()
	queue_redraw()


func get_offscreen_route_marker() -> Dictionary:
	return _offscreen_marker.duplicate(true)


func get_objective_marker_legend() -> Array[Dictionary]:
	return [
		{"id": &"cinder_cargo_terminal", "glyph": "▣", "pattern": &"double_square", "label": "CARGO TERMINAL", "focus_label": "Cargo terminal objective"},
		{"id": &"station_defense_activity_board", "glyph": "◆", "pattern": &"diamond", "label": "DEFENSE BOARD", "focus_label": "Station defense activity board"},
		{"id": &"active_route_checkpoint", "glyph": "◎", "pattern": &"ring_dot", "label": "NEXT ROUTE GATE", "focus_label": "Next active route checkpoint"},
		{"id": &"active_debris_beacon", "glyph": "⊕", "pattern": &"crosshair", "label": "NEXT DEBRIS BEACON", "focus_label": "Next active debris beacon"},
		{"id": &"active_mining_hold", "glyph": "▤", "pattern": &"striped_square", "label": "EXTRACTION HOLD", "focus_label": "Active extraction hold point"},
		{"id": &"active_structure_scan_hold", "glyph": "◈", "pattern": &"nested_diamond", "label": "SCAN HOLD", "focus_label": "Active structure scan hold point"},
		{"id": &"active_convoy_rendezvous", "glyph": "◇", "pattern": &"hollow_diamond", "label": "CONVOY RENDEZVOUS", "focus_label": "Convoy rendezvous point"},
		{"id": &"active_convoy_leg", "glyph": "»", "pattern": &"double_chevron", "label": "CONVOY NEXT LEG", "focus_label": "Convoy next route leg"},
	]


## The complete legend remains available to controller/accessibility consumers,
## while the compact map draws only entries actually present in this frame.
func get_visible_objective_marker_legend() -> Array[Dictionary]:
	var visible_ids: Dictionary = {}
	for marker_variant in _snapshot.get("objective_markers", []) as Array:
		var marker := marker_variant as Dictionary
		if bool(marker.get("active", true)):
			visible_ids[StringName(marker.get("id", &""))] = true
	var visible_legend: Array[Dictionary] = []
	for legend in get_objective_marker_legend():
		if visible_ids.has(StringName(legend.get("id", &""))):
			visible_legend.append(legend.duplicate(true))
	return visible_legend


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_audit_report() -> Dictionary:
	var nodes := _snapshot.get("topology_nodes", []) as Array
	var edges := _snapshot.get("topology_edges", []) as Array
	var contacts := _snapshot.get("contacts", []) as Array
	var visible_node_ids: Dictionary = {}
	for node_record in nodes:
		var node := node_record as Dictionary
		if _is_in_range(node.position):
			visible_node_ids[node.id] = true
	var visible_edges := 0
	for edge_record in edges:
		var edge := edge_record as Dictionary
		if visible_node_ids.has(edge.from) and visible_node_ids.has(edge.to):
			visible_edges += 1
	var visible_contacts := 0
	for contact in contacts:
		if _is_in_range((contact as Dictionary).position):
			visible_contacts += 1
	var errors := PackedStringArray()
	if mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("minimap must ignore pointer input")
	if not _snapshot.is_empty() and not _snapshot_is_finite():
		errors.append("stored minimap snapshot is not finite")
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": _warnings.duplicate(),
		"revision": _revision,
		"has_snapshot": not _snapshot.is_empty(),
		"visible": visible,
		"visible_in_tree": is_visible_in_tree(),
		"range_meters": float(_snapshot.get("range_meters", 0.0)),
		"node_count": nodes.size(),
		"edge_count": edges.size(),
		"contact_count": contacts.size(),
		"rendered_node_count": visible_node_ids.size(),
		"rendered_edge_count": visible_edges,
		"rendered_contact_count": visible_contacts,
		"player_visible": _snapshot.has("player_position") and _is_in_range(_snapshot.player_position),
		"active_ship_visible": _snapshot.has("active_ship") and _is_in_range((_snapshot.active_ship as Dictionary).position),
		"map_center": _snapshot.get("center_position", Vector2.ZERO),
		"heading_radians": float(_snapshot.get("heading_radians", 0.0)),
		"mouse_passthrough": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"snapshot_storage": &"deep_detached_scalar_copy",
		"projection": &"world_xz_north_negative_z_north_up",
		"contact_glyphs": {"friendly": &"circle_cross", "hostile": &"diamond"},
		"objective_marker_count": (_snapshot.get("objective_markers", []) as Array).size(),
		"objective_marker_glyphs": {
			&"cinder_cargo_terminal": "▣",
			&"station_defense_activity_board": "◆",
			&"active_route_checkpoint": "◎",
			&"active_debris_beacon": "⊕",
			&"active_mining_hold": "▤",
			&"active_structure_scan_hold": "◈",
			&"active_convoy_rendezvous": "◇",
			&"active_convoy_leg": "»",
		},
		"objective_marker_legend": get_objective_marker_legend(),
		"visible_objective_marker_legend": get_visible_objective_marker_legend(),
		"contact_state_has_shape_cue": true,
		"bounded": true,
		"bounds": {
			"minimum_range_meters": MIN_RANGE_METERS,
			"maximum_range_meters": MAX_RANGE_METERS,
			"maximum_nodes": MAX_TOPOLOGY_NODES,
			"maximum_edges": MAX_TOPOLOGY_EDGES,
			"maximum_contacts": MAX_CONTACTS,
		},
		"authority": {
			"gameplay": false,
			"navigation": false,
			"targeting": false,
			"contact_detection": false,
			"station_topology": false,
		},
	}


func _draw() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	if map_rect.size.x <= 1.0 or map_rect.size.y <= 1.0:
		return
	draw_rect(map_rect, GLASS, true)
	var center := map_rect.get_center()
	var radius := maxf(minf(map_rect.size.x, map_rect.size.y) * 0.5 - 8.0, 1.0)
	draw_circle(center, radius, Color(INK, 0.72))
	for fraction in [0.5, 1.0]:
		draw_arc(center, radius * fraction, 0.0, TAU, 64, GRID, 1.0, true)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), GRID, 1.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), GRID, 1.0)
	if _snapshot.is_empty():
		_draw_frame(center, radius)
		# Retained route guidance must survive a topology snapshot gap. The
		# marker is caller-owned presentation state and needs only this safe
		# frame; withholding it here made accepted guidance silently invisible.
		_draw_offscreen_marker(center, radius)
		return

	var projected_nodes: Dictionary = {}
	for node_record in (_snapshot.topology_nodes as Array):
		var record := node_record as Dictionary
		if not _is_in_range(record.position):
			continue
		var point := _project(record.position, center, radius)
		projected_nodes[record.id] = point
	for edge_record in (_snapshot.topology_edges as Array):
		var edge := edge_record as Dictionary
		if not projected_nodes.has(edge.from) or not projected_nodes.has(edge.to):
			continue
		var from_point := projected_nodes[edge.from] as Vector2
		var to_point := projected_nodes[edge.to] as Vector2
		draw_line(from_point, to_point, Color(_nominal_color, 0.34), 2.0, true)
	for node_record in (_snapshot.topology_nodes as Array):
		var record := node_record as Dictionary
		if not projected_nodes.has(record.id):
			continue
		var point := projected_nodes[record.id] as Vector2
		match StringName(record.kind):
			&"berth":
				draw_rect(Rect2(point - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), _caution_color, false, 1.8)
			&"connection":
				draw_circle(point, 4.2, _nominal_color)
			_:
				draw_circle(point, 3.2, _muted_color)

	for contact_record in (_snapshot.contacts as Array):
		var contact := contact_record as Dictionary
		if not _is_in_range(contact.position):
			continue
		var point := _project(contact.position, center, radius)
		if bool(contact.hostile):
			var diamond := PackedVector2Array([
				point + Vector2(0.0, -5.5), point + Vector2(5.5, 0.0),
				point + Vector2(0.0, 5.5), point + Vector2(-5.5, 0.0),
			])
			draw_colored_polygon(diamond, _danger_color)
		else:
			draw_circle(point, 4.5, _caution_color, false, 2.0, true)
			draw_line(point - Vector2(2.5, 0.0), point + Vector2(2.5, 0.0), _caution_color, 1.5, true)
			draw_line(point - Vector2(0.0, 2.5), point + Vector2(0.0, 2.5), _caution_color, 1.5, true)

	for marker_record in (_snapshot.get("objective_markers", []) as Array):
		var marker := marker_record as Dictionary
		if not bool(marker.get("active", true)):
			continue
		var point := _project(marker.position, center, radius)
		var marker_id := StringName(marker.id)
		var marker_color := _caution_color if marker_id == &"station_defense_activity_board" else _nominal_color
		var glyph := str(marker.get("glyph", "◆"))
		var label := str(marker.get("label", marker_id)).to_upper()
		var distance: float = marker.position.distance_to(_snapshot.center_position as Vector2)
		draw_string(ThemeDB.fallback_font, point + Vector2(7.0, 4.0), glyph + " " + label + "  %.0fM" % distance, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, marker_color)
	var legend_y := size.y - 12.0
	for legend in get_visible_objective_marker_legend():
		draw_string(ThemeDB.fallback_font, Vector2(10.0, legend_y), "%s %s" % [legend.get("glyph", ""), legend.get("label", "")], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, _muted_color)
		legend_y -= 11.0

	if _snapshot.has("active_ship"):
		var ship := _snapshot.active_ship as Dictionary
		if _is_in_range(ship.position):
			var point := _project(ship.position, center, radius)
			draw_arc(point, 6.5, 0.0, TAU, 24, _caution_color, 2.2, true)
	if _snapshot.has("player_position") and _is_in_range(_snapshot.player_position):
		var point := _project(_snapshot.player_position, center, radius)
		var heading := float(_snapshot.heading_radians)
		var forward := Vector2(sin(heading), -cos(heading))
		var side := forward.orthogonal()
		var arrow := PackedVector2Array([
			point + forward * 8.0,
			point - forward * 6.0 + side * 5.0,
			point - forward * 3.0,
			point - forward * 6.0 - side * 5.0,
		])
		draw_colored_polygon(arrow, _nominal_color)
	_draw_frame(center, radius)
	_draw_offscreen_marker(center, radius)


## Presents one caller-owned route/landing target that lies beyond the map
## bounds. The marker is clamped inside the minimap's safe frame and carries
## shape plus distance text, so colour and motion are optional enhancements.
func present_offscreen_route_marker(
	direction: Vector2, distance_m: float, route_kind: StringName, reduced_motion := false
) -> Dictionary:
	var presentation := get_offscreen_marker_presentation(
		direction, distance_m, route_kind, reduced_motion
	)
	if not bool(presentation.get("accepted", false)):
		return presentation
	_offscreen_marker = presentation.duplicate(true)
	queue_redraw()
	return _offscreen_marker.duplicate(true)


static func get_offscreen_marker_presentation(
	direction: Vector2, distance_m: float, route_kind: StringName, reduced_motion := false
) -> Dictionary:
	if direction.is_zero_approx() or not direction.is_finite():
		return {"accepted": false, "reason": &"invalid_direction"}
	if not is_finite(distance_m) or distance_m < 0.0:
		return {"accepted": false, "reason": &"invalid_distance"}
	if route_kind not in [&"surface_route", &"landing"]:
		return {"accepted": false, "reason": &"invalid_route_kind"}
	return {
		"accepted": true,
		"direction": direction.normalized(),
		"distance_m": distance_m,
		"route_kind": route_kind,
		"marker": "△" if route_kind == &"landing" else ">>",
		"reduced_motion": reduced_motion,
		"presentation_only": true,
	}


func _draw_frame(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, 0.0, TAU, 64, Color(INK, 0.95), 5.0, true)
	draw_arc(center, radius, 0.0, TAU, 64, _nominal_color, 1.5, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-6.0, -radius + 17.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, _nominal_color)


func _draw_offscreen_marker(center: Vector2, radius: float) -> void:
	if _offscreen_marker.is_empty():
		return
	var direction := _offscreen_marker.direction as Vector2
	var point := center + direction * maxf(radius - 14.0, 1.0)
	var route_kind := StringName(_offscreen_marker.route_kind)
	var marker_color := _caution_color if route_kind == &"landing" else _nominal_color
	if route_kind == &"landing":
		var triangle := PackedVector2Array([
			point + Vector2(0.0, -7.0),
			point + Vector2(6.0, 5.0),
			point + Vector2(-6.0, 5.0),
		])
		draw_colored_polygon(triangle, marker_color)
	else:
		var side := direction.orthogonal() * 5.0
		var arrow := PackedVector2Array([
			point + direction * 7.0,
			point - direction * 5.0 + side,
			point - direction * 1.0,
			point - direction * 5.0 - side,
		])
		draw_colored_polygon(arrow, marker_color)
	var distance_text := "%s  %.0f M" % [_offscreen_marker.marker, float(_offscreen_marker.distance_m)]
	draw_string(
		ThemeDB.fallback_font,
		point + Vector2(-30.0, 22.0),
		distance_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		60.0,
		10,
		marker_color
	)


func _project(world_position: Vector2, center: Vector2, radius: float) -> Vector2:
	var relative := world_position - (_snapshot.center_position as Vector2)
	# World X is screen right and world -Z is screen up. The map remains north-up;
	# heading belongs only to the player marker.
	var map_vector := Vector2(relative.x, -relative.y)
	var projected := map_vector * (radius / float(_snapshot.range_meters))
	if projected.length() > radius:
		projected = projected.normalized() * radius
	return center + projected


func _is_in_range(position: Vector2) -> bool:
	if _snapshot.is_empty():
		return false
	return position.distance_to(_snapshot.center_position as Vector2) <= float(_snapshot.range_meters)


func _sanitize_snapshot(raw: Dictionary) -> Dictionary:
	if typeof(raw.get("schema_version")) != TYPE_INT or int(raw.get("schema_version", -1)) != SNAPSHOT_SCHEMA_VERSION:
		return {"accepted": false}
	var range_value: Variant = raw.get("range_meters", null)
	if not _is_finite_number(range_value):
		return {"accepted": false}
	var range_meters := float(range_value)
	if range_meters < MIN_RANGE_METERS or range_meters > MAX_RANGE_METERS:
		return {"accepted": false}
	var center: Variant = _read_position(raw.get("center_position", null))
	var heading_value: Variant = raw.get("heading_radians", 0.0)
	if center == null or not _is_finite_number(heading_value):
		return {"accepted": false}
	var sanitized: Dictionary = {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"range_meters": range_meters,
		"center_position": center,
		"heading_radians": wrapf(float(heading_value), -PI, PI),
		"topology_nodes": [],
		"topology_edges": [],
		"contacts": [],
		"objective_markers": [],
	}
	var warnings: PackedStringArray = PackedStringArray()
	var player: Variant = _read_position(raw.get("player_position", null))
	if player != null:
		sanitized["player_position"] = player
	elif raw.has("player_position"):
		warnings.append("ignored malformed player_position")

	var active_ship: Variant = raw.get("active_ship", null)
	if active_ship is Dictionary:
		var ship_position: Variant = _read_position((active_ship as Dictionary).get("position", null))
		if ship_position != null:
			sanitized["active_ship"] = {
				"id": StringName((active_ship as Dictionary).get("id", &"active_ship")),
				"position": ship_position,
			}
		else:
			warnings.append("ignored malformed active_ship")
	elif active_ship != null:
		warnings.append("ignored malformed active_ship")

	var node_ids: Dictionary = {}
	var raw_nodes: Variant = raw.get("topology_nodes", [])
	if raw_nodes is Array:
		for raw_node in (raw_nodes as Array).slice(0, MAX_TOPOLOGY_NODES):
			if not (raw_node is Dictionary):
				warnings.append("ignored malformed topology node")
				continue
			var node := raw_node as Dictionary
			var node_id := StringName(node.get("id", &""))
			var position: Variant = _read_position(node.get("position", null))
			if node_id.is_empty() or position == null or node_ids.has(node_id):
				warnings.append("ignored malformed or duplicate topology node")
				continue
			node_ids[node_id] = true
			(sanitized.topology_nodes as Array).append({
				"id": node_id,
				"position": position,
				"kind": StringName(node.get("kind", &"route")),
			})
		if (raw_nodes as Array).size() > MAX_TOPOLOGY_NODES:
			warnings.append("topology node roster truncated to bounded limit")
	else:
		warnings.append("ignored malformed topology_nodes roster")

	var raw_edges: Variant = raw.get("topology_edges", [])
	if raw_edges is Array:
		for raw_edge in (raw_edges as Array).slice(0, MAX_TOPOLOGY_EDGES):
			if not (raw_edge is Dictionary):
				warnings.append("ignored malformed topology edge")
				continue
			var edge := raw_edge as Dictionary
			var from_id := StringName(edge.get("from", &""))
			var to_id := StringName(edge.get("to", &""))
			if from_id == to_id or not node_ids.has(from_id) or not node_ids.has(to_id):
				warnings.append("ignored topology edge with unknown or identical endpoint")
				continue
			(sanitized.topology_edges as Array).append({"from": from_id, "to": to_id})
		if (raw_edges as Array).size() > MAX_TOPOLOGY_EDGES:
			warnings.append("topology edge roster truncated to bounded limit")
	else:
		warnings.append("ignored malformed topology_edges roster")

	var raw_contacts: Variant = raw.get("contacts", [])
	if raw_contacts is Array:
		for raw_contact in (raw_contacts as Array).slice(0, MAX_CONTACTS):
			if not (raw_contact is Dictionary):
				warnings.append("ignored malformed contact")
				continue
			var contact := raw_contact as Dictionary
			var position: Variant = _read_position(contact.get("position", null))
			if position == null:
				warnings.append("ignored contact with non-finite position")
				continue
			(sanitized.contacts as Array).append({
				"id": StringName(contact.get("id", &"contact")),
				"position": position,
				"kind": StringName(contact.get("kind", &"unknown")),
				"hostile": bool(contact.get("hostile", false)),
			})
		if (raw_contacts as Array).size() > MAX_CONTACTS:
			warnings.append("contact roster truncated to bounded limit")
	else:
		warnings.append("ignored malformed contacts roster")
	var raw_markers: Variant = raw.get("objective_markers", [])
	if raw_markers is Array:
		for raw_marker in (raw_markers as Array).slice(0, MAX_OBJECTIVE_MARKERS):
			if not raw_marker is Dictionary:
				continue
			var marker := raw_marker as Dictionary
			var marker_id := StringName(marker.get("id", &""))
			var marker_position: Variant = _read_position(marker.get("position", null))
			var generation := int(marker.get("generation", raw.get("generation", 0)))
			var marker_style := _get_objective_marker_style(marker_id)
			if marker_style.is_empty() or marker_position == null \
					or generation < int(_marker_generations.get(marker_id, -1)):
				continue
			_marker_generations[marker_id] = generation
			(sanitized.objective_markers as Array).append({
				"id": marker_id, "position": marker_position, "generation": generation,
				"active": bool(marker.get("active", true)),
				"glyph": marker_style.get("glyph", "◆"),
				"pattern": marker_style.get("pattern", &"diamond"),
				"label": marker_style.get("label", "OBJECTIVE"),
			})
	return {"accepted": true, "snapshot": sanitized, "warnings": warnings}


func _get_objective_marker_style(marker_id: StringName) -> Dictionary:
	for style in get_objective_marker_legend():
		if StringName(style.get("id", &"")) == marker_id:
			return style
	return {}


func _read_position(value: Variant) -> Variant:
	if value is Vector2 and (value as Vector2).is_finite():
		return value as Vector2
	if value is Vector3 and (value as Vector3).is_finite():
		var vector := value as Vector3
		return Vector2(vector.x, vector.z)
	return null


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


func _snapshot_is_finite() -> bool:
	return (
		(_snapshot.center_position as Vector2).is_finite()
		and is_finite(float(_snapshot.range_meters))
		and is_finite(float(_snapshot.heading_radians))
	)
