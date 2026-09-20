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

	_check_objective_text_advances(minimap)

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
		{
			"id": &"active_mining_hold",
			"position": Vector3(160.0, 0.0, -280.0),
			"generation": 1,
		},
		{
			"id": &"active_structure_scan_hold",
			"position": Vector3(170.0, 0.0, -290.0),
			"generation": 1,
		},
		{
			"id": &"active_convoy_rendezvous",
			"position": Vector3(184.0, 0.0, -324.0),
			"generation": 1,
		},
		{
			"id": &"active_convoy_leg",
			"position": Vector3(204.0, 0.0, -370.0),
			"generation": 1,
		},
		{
			"id": &"active_jovian_delivery_return",
			"position": Vector3(80.0, 0.0, -110.0),
			"generation": 1,
		},
		{
			"id": &"active_platform_supply_target",
			"position": Vector3(120.0, 0.0, -160.0),
			"generation": 1,
		},
		{
			"id": &"active_ember_surface_route",
			"position": Vector3(130.0, 0.0, -150.0),
			"generation": 1,
		},
		{
			"id": &"active_ember_side_task",
			"position": Vector3(140.0, 0.0, -145.0),
			"generation": 1,
		},
	]
	_check(minimap.apply_snapshot(marked), "live activity marker snapshot is accepted")
	audit = minimap.get_audit_report()
	_check(int(audit.get("objective_marker_count", 0)) == 12, "static destinations and active route targets are retained")
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
	_check(legend.size() == 18 and legend_patterns.size() == 18, "objective legend uses distinct non-color patterns")
	_check(legend.all(func(entry: Dictionary) -> bool:
		return str(entry.get("focus_label", "")).length() > 0
	), "objective legend exposes controller-readable focus labels")
	_test_nearby_sector_destination_markers(minimap, snapshot)
	var stale := marked.duplicate(true)
	(stale["objective_markers"] as Array)[0]["generation"] = 3
	_check(minimap.apply_snapshot(stale), "stale marker snapshot remains structurally valid")
	_check(int(minimap.get_audit_report().get("objective_marker_count", 0)) == 11, "stale marker generation is removed without retaining old location")
	var route_only := snapshot.duplicate(true)
	route_only["objective_markers"] = [{
		"id": &"active_route_checkpoint",
		"position": Vector3(160.0, 0.0, -260.0),
		"generation": 5,
	}]
	_check(minimap.apply_snapshot(route_only), "a single live target snapshot is accepted")
	var visible_legend: Array = minimap.call(
		&"get_visible_objective_marker_legend"
	) as Array
	_check(
		visible_legend.size() == 1
		and visible_legend[0].get("id", &"") == &"active_route_checkpoint",
		"the drawn legend contains only objectives present in the current frame"
	)
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


## The nearby sector's own places ride the same detached marker roster as the
## activities. They must read distinctly from every existing objective, stay
## legible without colour, and never animate.
func _test_nearby_sector_destination_markers(minimap: Minimap, base: Dictionary) -> void:
	var sector_ids: Array[StringName] = [
		&"nearby_hulk_dock",
		&"nearby_belt_bore",
		&"nearby_route_beacon",
		&"nearby_ringed_moonlet",
		&"nearby_extraction_platform",
		&"nearby_debris_field",
	]
	var legend := minimap.get_objective_marker_legend()
	var styles: Dictionary = {}
	for entry in legend:
		styles[StringName(entry.get("id", &""))] = entry
	var glyphs: Dictionary = {}
	var labels: Dictionary = {}
	var complete := true
	for marker_id in sector_ids:
		var style := styles.get(marker_id, {}) as Dictionary
		if style.is_empty() \
				or str(style.get("glyph", "")).is_empty() \
				or str(style.get("label", "")).is_empty() \
				or str(style.get("focus_label", "")).is_empty():
			complete = false
			continue
		glyphs[str(style.get("glyph", ""))] = true
		labels[str(style.get("label", ""))] = true
	_check(
		complete and glyphs.size() == sector_ids.size()
		and labels.size() == sector_ids.size(),
		"every nearby-sector destination carries its own glyph, label and focus label",
	)
	var all_glyphs: Dictionary = {}
	for entry in legend:
		all_glyphs[str(entry.get("glyph", ""))] = true
	_check(
		all_glyphs.size() == legend.size(),
		"no nearby-sector destination reuses an existing objective glyph",
	)

	var sector := base.duplicate(true)
	var roster: Array = []
	var index := 0
	for marker_id in sector_ids:
		index += 1
		roster.append({
			"id": marker_id,
			"position": Vector3(20.0 * index, 0.0, -30.0 * index),
			"generation": 4,
		})
	# Four beacons share one family, exactly as the streamed cluster publishes
	# them: the map draws four marks and the key still shows one row.
	for beacon in 3:
		roster.append({
			"id": &"nearby_route_beacon",
			"position": Vector3(-24.0 * (beacon + 1), 0.0, -40.0 * (beacon + 1)),
			"generation": 4,
		})
	sector["objective_markers"] = roster
	_check(minimap.apply_snapshot(sector), "the sector destination roster is accepted")
	var audit := minimap.get_audit_report()
	_check(
		int(audit.get("objective_marker_count", 0)) == sector_ids.size() + 3,
		"one beacon family publishes each of its four marks",
	)
	var visible := minimap.get_visible_objective_marker_legend()
	_check(
		visible.size() == sector_ids.size(),
		"the visible key lists each present destination family exactly once",
	)
	_check(
		(audit.get("visible_objective_marker_legend", []) as Array).size() == visible.size()
		and (audit.get("objective_marker_legend", []) as Array).size() == legend.size(),
		"the audit reports both the present key and the full accessibility legend",
	)
	var drawn := minimap.get_snapshot().get("objective_markers", []) as Array
	var steady := true
	for marker_variant: Variant in drawn:
		var marker := marker_variant as Dictionary
		if marker.has("blink") or marker.has("flash") or marker.has("pulse_hz"):
			steady = false
	_check(
		steady,
		"no sector destination marker carries a flashing presentation field",
	)
	var dock := drawn.filter(func(marker: Dictionary) -> bool:
		return marker.get("id", &"") == &"nearby_hulk_dock"
	)
	_check(
		dock.size() == 1 and str(dock[0].get("label", "")) == "HULK DOCK"
		and str(dock[0].get("glyph", "")) == str(
			(styles[&"nearby_hulk_dock"] as Dictionary).get("glyph", "")
		),
		"the hulk dock marker uses the frozen readable style, not caller text",
	)
	# Colour is never the carrier: the palette can change wholesale and every
	# mark keeps its own shape and text.
	_check(
		minimap.set_palette({
			&"nominal": Color.WHITE, &"caution": Color.WHITE,
			&"danger": Color.WHITE, &"muted": Color.WHITE,
		}),
		"a single-hue colour-vision palette is accepted",
	)
	var mono := minimap.get_visible_objective_marker_legend()
	var mono_glyphs: Dictionary = {}
	for entry in mono:
		mono_glyphs[str(entry.get("glyph", ""))] = true
	_check(
		mono_glyphs.size() == mono.size(),
		"under one flat hue every visible destination is still told apart by shape",
	)
	minimap.set_palette({
		&"nominal": Minimap.CYAN, &"caution": Minimap.AMBER,
		&"danger": Minimap.RED, &"muted": Minimap.MUTED,
	})
	# A streamed-out sector publishes an empty roster, exactly as GameFlow does
	# once the cluster leaves the tree.
	var streamed_out := base.duplicate(true)
	streamed_out["objective_markers"] = []
	_check(
		minimap.apply_snapshot(streamed_out)
		and int(minimap.get_audit_report().get("objective_marker_count", 0)) == 0
		and minimap.get_visible_objective_marker_legend().is_empty(),
		"a streamed-out sector leaves no retained destination mark or key row behind",
	)


func _check_objective_text_advances(minimap: Control) -> void:
	var text_server := TextServerManager.get_primary_interface()
	for legend in minimap.get_objective_marker_legend():
		var prefix := "%s %s  " % [legend.glyph, legend.label]
		var advance: float = minimap._get_objective_prefix_advance(prefix, ThemeDB.fallback_font)
		var matches := true
		for distance in ["0M", "1M", "380M", "100000M"]:
			var full := TextLine.new()
			full.add_string(prefix + distance, ThemeDB.fallback_font, 10)
			var full_advance := 0.0
			for glyph in text_server.shaped_text_get_glyphs(full.get_rid()):
				if int(glyph.start) >= prefix.length():
					break
				full_advance += float(glyph.advance) * int(glyph.repeat)
			matches = matches and is_equal_approx(advance, full_advance)
		_check(matches, "%s distance retains the full string's fractional position" % legend.id)
	# A replaced fallback font must invalidate widths even for identical text.
	var alternate_font := SystemFont.new()
	alternate_font.font_names = PackedStringArray(["serif"])
	minimap._get_objective_prefix_advance("◆ DEFENSE BOARD  ", alternate_font)
	_check(minimap._objective_prefix_font == alternate_font, "objective text follows fallback font replacement")
	alternate_font.changed.emit()
	_check(minimap._objective_prefix_advances.is_empty(), "objective text widths invalidate when the font changes")


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
