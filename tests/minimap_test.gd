extends SceneTree

const MINIMAP_SCRIPT := preload("res://scripts/ui/minimap.gd")
const HUD_PALETTE := preload("res://scripts/ui/hud_palette.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var minimap: Control = MINIMAP_SCRIPT.new()
	minimap.name = "StandaloneMinimapTest"
	minimap.size = Vector2(240.0, 240.0)
	root.add_child(minimap)
	await process_frame

	_check(minimap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "minimap ignores pointer input")
	_check(
		minimap.set_palette(HUD_PALETTE.get_palette(HUD_PALETTE.MODE_DEUTERANOPIA)),
		"minimap accepts the HUD's validated semantic accessibility palette"
	)
	var snapshot := {
		"schema_version": 1,
		"range_meters": 1000.0,
		"center_position": Vector3(100.0, 40.0, -200.0),
		"player_position": Vector3(110.0, 12.0, -220.0),
		"heading_radians": PI * 0.5,
		"active_ship": {"id": &"torrent", "position": Vector3(130.0, 8.0, -190.0)},
		"topology_nodes": [
			{"id": &"hub:north", "position": Vector3(100.0, 0.0, -300.0)},
			{"id": &"dock:entry", "position": Vector3(100.0, 0.0, -350.0)},
			{"id": &"far:station", "position": Vector3(5000.0, 0.0, -200.0)},
		],
		"topology_edges": [
			{"from": &"hub:north", "to": &"dock:entry"},
			{"from": &"dock:entry", "to": &"far:station"},
		],
		"contacts": [
			{"id": &"friendly", "position": Vector3(150.0, 0.0, -250.0), "kind": &"ship", "hostile": false},
			{"id": &"far_hostile", "position": Vector3(5000.0, 0.0, -200.0), "kind": &"ship", "hostile": true},
		],
	}
	_check(minimap.apply_snapshot(snapshot), "valid detached snapshot is accepted")
	var audit: Dictionary = minimap.get_audit_report()
	_check(
		bool(audit.valid)
		and int(audit.node_count) == 3
		and int(audit.edge_count) == 2
		and int(audit.rendered_node_count) == 2
		and int(audit.rendered_edge_count) == 1
		and int(audit.contact_count) == 2
		and int(audit.rendered_contact_count) == 1,
		"audit reports range-bounded topology and rendered contacts"
	)
	_check(bool(audit.player_visible) and bool(audit.active_ship_visible), "player and active ship are independently visible")
	var marked := snapshot.duplicate(true)
	marked["objective_markers"] = [
		{"id": &"cinder_cargo_terminal", "position": Vector3(2100.0, 0.0, -200.0), "generation": 4},
		{"id": &"station_defense_activity_board", "position": Vector3(120.0, 0.0, -210.0), "generation": 4},
		{
			"id": &"active_route_checkpoint",
			"position": Vector3(160.0, 0.0, -260.0),
			"generation": 4,
			"glyph": "FORGED",
			"label": "FORGED LABEL",
		},
		{
			"id": &"active_debris_beacon",
			"position": Vector3(180.0, 0.0, -300.0),
			"generation": 2,
		},
	]
	_check(minimap.apply_snapshot(marked), "live activity marker snapshot is accepted")
	audit = minimap.get_audit_report()
	_check(int(audit.get("objective_marker_count", 0)) == 4, "static destinations and active route targets are retained")
	var accepted_markers := minimap.get_snapshot().get("objective_markers", []) as Array
	var route_marker := accepted_markers.filter(func(marker: Dictionary) -> bool:
		return marker.get("id", &"") == &"active_route_checkpoint"
	)
	_check(
		route_marker.size() == 1
		and route_marker[0].get("glyph", "") == "◎"
		and route_marker[0].get("label", "") == "NEXT ROUTE GATE",
		"the active checkpoint uses the frozen readable style instead of caller text"
	)
	var legend: Array[Dictionary] = minimap.get_objective_marker_legend()
	var legend_patterns: Dictionary = {}
	for entry in legend:
		legend_patterns[entry.get("pattern", &"")] = true
	_check(legend.size() == 4 and legend_patterns.size() == 4, "objective legend uses distinct non-color patterns")
	_check(legend.all(func(entry: Dictionary) -> bool:
		return str(entry.get("focus_label", "")).length() > 0
	), "objective legend exposes controller-readable focus labels")
	var stale := marked.duplicate(true)
	(stale["objective_markers"] as Array)[0]["generation"] = 3
	_check(minimap.apply_snapshot(stale), "stale marker snapshot remains structurally valid")
	_check(int(minimap.get_audit_report().get("objective_marker_count", 0)) == 3, "stale marker generation is removed without retaining old location")
	_check(
		not bool((audit.authority as Dictionary).gameplay)
		and not bool((audit.authority as Dictionary).navigation)
		and audit.projection == &"world_xz_north_negative_z_north_up"
		and bool(audit.contact_state_has_shape_cue)
		and (audit.contact_glyphs as Dictionary).friendly != (audit.contact_glyphs as Dictionary).hostile,
		"renderer documents projection, shape-distinct contacts, and no gameplay or navigation authority"
	)

	# The source is deeply detached: later mutations cannot alter presentation.
	(snapshot.topology_nodes as Array)[0]["position"] = Vector3(NAN, 0.0, 0.0)
	(snapshot.contacts as Array).clear()
	_check(
		int(minimap.get_audit_report().node_count) == 3
		and int(minimap.get_audit_report().contact_count) == 2,
		"applied snapshot is detached from caller mutations"
	)

	var before: Dictionary = minimap.get_snapshot()
	var invalid_core := {
		"schema_version": 1,
		"range_meters": INF,
		"center_position": Vector2.ZERO,
	}
	_check(
		not minimap.apply_snapshot(invalid_core) and minimap.get_snapshot() == before,
		"non-finite core data rejects atomically without replacing the last good map"
	)

	var partial := {
		"schema_version": 1,
		"range_meters": 250.0,
		"center_position": Vector2.ZERO,
		"heading_radians": 0.0,
		"player_position": Vector2(NAN, 0.0),
		"topology_nodes": [
			{"id": &"good", "position": Vector2(10.0, -10.0)},
			{"id": &"bad", "position": Vector3(0.0, NAN, 0.0)},
		],
		"topology_edges": [
			{"from": &"good", "to": &"missing"},
			{"from": &"good", "to": &"good"},
		],
		"contacts": [{"id": &"bad", "position": Vector2(INF, 0.0)}],
	}
	_check(minimap.apply_snapshot(partial), "structurally valid snapshot safely omits malformed optional records")
	audit = minimap.get_audit_report()
	_check(
		int(audit.node_count) == 1
		and int(audit.edge_count) == 0
		and int(audit.contact_count) == 0
		and not bool(audit.player_visible)
		and (audit.warnings as PackedStringArray).size() >= 4,
		"audit exposes every safely omitted record class"
	)

	minimap.clear()
	_check(not bool(minimap.get_audit_report().has_snapshot), "clear removes presentation data")
	minimap.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("Minimap tests passed")
		quit(0)
	else:
		push_error("Minimap tests failed: %s" % ", ".join(_failures))
		quit(1)
