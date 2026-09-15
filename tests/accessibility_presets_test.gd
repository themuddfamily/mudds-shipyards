extends SceneTree

## Verifies the accessibility presets the pause panel exposes.
##
## The colour work is *measured*, not asserted: every preset is simulated through
## the Machado dichromacy matrices and scored with CIEDE2000, and the authored
## palette is scored the same way so the defect being fixed is on the record.

const Palette := preload("res://scripts/ui/hud_palette.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_colour_science()
	_test_palette_completeness()
	_test_authored_palette_defect()
	_test_preset_separation()
	_test_high_contrast_variants()
	await _test_hud_palette_application()
	await _test_hud_high_contrast_application()
	await _test_hud_reticle_styles()
	await _test_hud_scale_and_motion()
	await _test_hud_captions()
	_finish()


func _test_colour_science() -> void:
	_check(
		is_equal_approx(Palette.contrast_ratio(Color.WHITE, Color.BLACK), 21.0),
		"contrast ratio reproduces the WCAG white-on-black maximum of 21:1"
	)
	_check(
		is_zero_approx(Palette.color_difference(Color("62e6ef"), Color("62e6ef"))),
		"CIEDE2000 reports zero difference for identical colours"
	)
	# Sharma et al. CIEDE2000 worked example, converted to sRGB-safe Lab pairs:
	# a mid grey against pure white must be a large, finite difference.
	var grey_to_white := Palette.color_difference(Color("808080"), Color.WHITE)
	_check(grey_to_white > 30.0 and grey_to_white < 60.0, "CIEDE2000 scales plausibly across a large lightness step")

	# A dichromacy simulation must actually collapse the axis it targets.
	var red := Color("ff0000")
	var green := Color("00ff00")
	var normal_gap := Palette.color_difference(red, green)
	var deutan_gap := Palette.color_difference(
		Palette.simulate_dichromacy(red, Palette.MODE_DEUTERANOPIA),
		Palette.simulate_dichromacy(green, Palette.MODE_DEUTERANOPIA)
	)
	_check(
		deutan_gap < normal_gap * 0.5,
		"deuteranopia simulation collapses the red/green axis (%.1f -> %.1f)" % [normal_gap, deutan_gap]
	)
	var blue := Color("0000ff")
	var yellow := Color("ffff00")
	var tritan_gap := Palette.color_difference(
		Palette.simulate_dichromacy(blue, Palette.MODE_TRITANOPIA),
		Palette.simulate_dichromacy(yellow, Palette.MODE_TRITANOPIA)
	)
	_check(
		tritan_gap < Palette.color_difference(blue, yellow),
		"tritanopia simulation compresses the blue/yellow axis"
	)
	_check(
		Palette.simulate_dichromacy(red, &"not_a_deficiency") == red,
		"an unknown deficiency returns the colour unchanged instead of measuring the wrong thing"
	)


func _test_palette_completeness() -> void:
	var mode_ids := Palette.get_mode_ids()
	_check(mode_ids.size() == 4 and mode_ids[0] == Palette.MODE_NONE, "four palettes are published with the authored set first")
	for mode_id: StringName in mode_ids:
		var palette := Palette.get_palette(mode_id)
		var complete := true
		for role: StringName in Palette.get_required_roles():
			if not palette.has(role):
				complete = false
		_check(complete, "palette %s defines every required role" % mode_id)
	_check(
		Palette.get_palette(&"bogus_mode") == Palette.get_palette(Palette.MODE_NONE),
		"an unknown palette ID falls back to the authored set rather than an empty map"
	)
	var detached := Palette.get_palette(Palette.MODE_NONE)
	detached[Palette.ROLE_DANGER] = Color.BLACK
	_check(
		Palette.get_role_color(Palette.MODE_NONE, Palette.ROLE_DANGER) != Color.BLACK,
		"published palettes are detached copies"
	)
	# The settings enum and the palette table must not drift apart.
	var settings := Settings.new("user://accessibility_presets_enum_probe.cfg")
	var settings_ids: Array[StringName] = []
	for palette_value: int in [
		Settings.ColorblindPalette.NONE,
		Settings.ColorblindPalette.DEUTERANOPIA,
		Settings.ColorblindPalette.PROTANOPIA,
		Settings.ColorblindPalette.TRITANOPIA,
	]:
		settings.colorblind_palette = palette_value
		settings_ids.append(settings.get_colorblind_palette_id())
	_check(settings_ids == mode_ids, "every persisted colour-vision ID maps to a published palette")


func _test_authored_palette_defect() -> void:
	# This is the motivation for the presets and is deliberately measured rather
	# than described: the authored HUD confuses amber and red for deuteranopes.
	var deficiencies: Array[StringName] = [
		Palette.MODE_DEUTERANOPIA,
		Palette.MODE_PROTANOPIA,
		Palette.MODE_TRITANOPIA,
	]
	for deficiency in deficiencies:
		var report := Palette.get_separation_report(Palette.MODE_NONE, deficiency)
		print(
			"MEASURED: authored palette under %s -> min dE00 %.1f between %s and %s"
			% [
				deficiency,
				float(report["minimum_difference"]),
				(report["minimum_pair"] as PackedStringArray)[0],
				(report["minimum_pair"] as PackedStringArray)[1],
			]
		)
		_check(
			float(report["minimum_difference"]) < Palette.MINIMUM_STATE_SEPARATION,
			"the authored palette is genuinely confusable under %s, so the preset earns its place" % deficiency
		)


func _test_preset_separation() -> void:
	for mode_id: StringName in Palette.MODE_TARGETS:
		var deficiency: StringName = Palette.MODE_TARGETS[mode_id]
		var simulated := Palette.get_separation_report(mode_id, deficiency)
		var normal := Palette.get_separation_report(mode_id, Palette.MODE_NONE)
		var authored := Palette.get_separation_report(Palette.MODE_NONE, deficiency)
		var simulated_minimum := float(simulated["minimum_difference"])
		var normal_minimum := float(normal["minimum_difference"])
		var contrast := float(simulated["minimum_panel_contrast"])
		print(
			"MEASURED: %s preset -> simulated min dE00 %.1f (%s/%s), normal min %.1f, min panel contrast %.2f:1"
			% [
				mode_id,
				simulated_minimum,
				(simulated["minimum_pair"] as PackedStringArray)[0],
				(simulated["minimum_pair"] as PackedStringArray)[1],
				normal_minimum,
				contrast,
			]
		)
		_check(
			simulated_minimum >= Palette.MINIMUM_STATE_SEPARATION,
			"%s preset keeps every state pair at least %.1f apart under simulation (measured %.1f)"
			% [mode_id, Palette.MINIMUM_STATE_SEPARATION, simulated_minimum]
		)
		_check(
			normal_minimum >= Palette.MINIMUM_NORMAL_SEPARATION,
			"%s preset stays readable with normal colour vision (measured %.1f)" % [mode_id, normal_minimum]
		)
		_check(
			contrast >= Palette.MINIMUM_PANEL_CONTRAST,
			"%s preset keeps every state colour above the panel contrast floor (measured %.2f:1)" % [mode_id, contrast]
		)
		_check(
			simulated_minimum > float(authored["minimum_difference"]),
			"%s preset strictly improves on the authored palette under the same deficiency" % mode_id
		)


## Every palette mode x contrast variant is re-measured here. The high-contrast
## variants must clear the WCAG AAA 7.0:1 floor for *all six* roles against the
## opaque high-contrast panel, and the separation gates the base presets are held
## to must still hold after the same dichromacy simulation. `none` has no target
## deficiency, so its variant is gated on normal-vision separation only and its
## simulated numbers are printed for the record.
func _test_high_contrast_variants() -> void:
	_check(
		Palette.PANEL_BACKGROUND_HIGH_CONTRAST.a == 1.0
		and Palette.contrast_ratio(Color.WHITE, Palette.PANEL_BACKGROUND_HIGH_CONTRAST)
			> Palette.contrast_ratio(Color.WHITE, Palette.PANEL_BACKGROUND),
		"the high-contrast panel is opaque and darker than the authored panel"
	)
	_check(
		Palette.get_palette(Palette.MODE_NONE, false) == Palette.get_palette(Palette.MODE_NONE),
		"the contrast argument defaults off, so existing callers keep the authored palette"
	)
	for mode_id: StringName in Palette.get_mode_ids():
		var base := Palette.get_palette(mode_id, false)
		var variant := Palette.get_palette(mode_id, true)
		var complete := true
		for role: StringName in Palette.get_required_roles():
			if not variant.has(role):
				complete = false
		_check(complete, "high-contrast %s defines every required role" % mode_id)
		_check(variant != base, "high-contrast %s is a distinct variant, not the base palette" % mode_id)
		var deficiency: StringName = Palette.MODE_TARGETS.get(mode_id, Palette.MODE_NONE)
		var simulated := Palette.get_separation_report(mode_id, deficiency, true)
		var normal := Palette.get_separation_report(mode_id, Palette.MODE_NONE, true)
		var base_report := Palette.get_separation_report(mode_id, deficiency, false)
		var role_contrast := float(simulated["minimum_role_contrast"])
		print(
			"MEASURED: %s high-contrast -> simulated min dE00 %.1f (%s/%s) under %s, normal min %.1f, weakest role %s at %.2f:1 on %s"
			% [
				mode_id,
				float(simulated["minimum_difference"]),
				(simulated["minimum_pair"] as PackedStringArray)[0],
				(simulated["minimum_pair"] as PackedStringArray)[1],
				deficiency,
				float(normal["minimum_difference"]),
				simulated["minimum_role_contrast_role"],
				role_contrast,
				Palette.PANEL_BACKGROUND_HIGH_CONTRAST.to_html(false),
			]
		)
		_check(
			bool(simulated["high_contrast"])
			and Color(simulated["panel_background"]) == Palette.PANEL_BACKGROUND_HIGH_CONTRAST,
			"the %s high-contrast report is measured against the opaque high-contrast panel" % mode_id
		)
		for role: StringName in Palette.get_required_roles():
			var ratio := Palette.contrast_ratio(variant[role] as Color, Palette.PANEL_BACKGROUND_HIGH_CONTRAST)
			_check(
				ratio >= Palette.MINIMUM_HIGH_CONTRAST_PANEL_CONTRAST,
				"high-contrast %s/%s clears the %.1f:1 AAA floor (measured %.2f:1)"
				% [mode_id, role, Palette.MINIMUM_HIGH_CONTRAST_PANEL_CONTRAST, ratio]
			)
		_check(
			role_contrast >= Palette.MINIMUM_HIGH_CONTRAST_PANEL_CONTRAST,
			"high-contrast %s reports its weakest role above the AAA floor (%.2f:1)" % [mode_id, role_contrast]
		)
		_check(
			float(normal["minimum_difference"]) >= Palette.MINIMUM_NORMAL_SEPARATION,
			"high-contrast %s stays readable with normal colour vision (measured %.1f)"
			% [mode_id, float(normal["minimum_difference"])]
		)
		if deficiency != Palette.MODE_NONE:
			_check(
				float(simulated["minimum_difference"]) >= Palette.MINIMUM_STATE_SEPARATION,
				"high-contrast %s keeps every state pair at least %.1f apart under %s (measured %.1f)"
				% [mode_id, Palette.MINIMUM_STATE_SEPARATION, deficiency, float(simulated["minimum_difference"])]
			)
			_check(
				float(simulated["minimum_panel_contrast"]) > float(base_report["minimum_panel_contrast"]),
				"high-contrast %s strictly raises the weakest state-role contrast over its base preset" % mode_id
			)
		else:
			for other: StringName in Palette.MODE_TARGETS:
				var record := Palette.get_separation_report(mode_id, other, true)
				print(
					"MEASURED: none high-contrast under %s -> min dE00 %.1f (%s/%s); not colour-safe by design"
					% [
						other,
						float(record["minimum_difference"]),
						(record["minimum_pair"] as PackedStringArray)[0],
						(record["minimum_pair"] as PackedStringArray)[1],
					]
				)
	_check(
		Palette.get_palette(&"bogus_mode", true) == Palette.get_palette(Palette.MODE_NONE, true),
		"an unknown high-contrast ID falls back to the high-contrast authored set"
	)


## Turning the high-contrast HUD on swaps the palette variant, makes every
## registered panel backing opaque and outlines body text; turning it off must
## restore the authored fills and colours exactly, because the ultrawide and
## composition suites freeze the `none` + off layout.
func _test_hud_high_contrast_application() -> void:
	var hud := GameHUD.new()
	hud.name = "AccessibilityContrastHUD"
	root.add_child(hud)
	await process_frame
	hud.set_engine_state("OFFLINE")
	hud.update_ship_telemetry({"damage_status": "critical", "throttle": -0.5, "hull": 10.0, "maximum_hull": 100.0})

	var interaction_box := (hud.get("_interaction_panel") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	var objective_box := (hud.get("_objective_panel") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	var telemetry_box := (hud.get("_telemetry_panel") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	var objective_label := hud.get("_objective_label") as Label
	var authored_interaction_fill := interaction_box.bg_color
	var authored_objective_fill := objective_box.bg_color
	var authored_border := objective_box.border_color
	var authored_widths := [
		objective_box.border_width_left, objective_box.border_width_top,
		objective_box.content_margin_left, objective_box.content_margin_top,
	]
	var authored_report := hud.get_accessibility_report()
	_check(
		not bool(authored_report["high_contrast"])
		and authored_interaction_fill.a < 1.0 and authored_objective_fill.a < 1.0,
		"the authored HUD starts with translucent panel backings and the contrast variant off"
	)
	_check(
		not objective_label.has_theme_constant_override("outline_size"),
		"authored body text carries no outline"
	)

	hud.set_high_contrast_hud(true)
	var applied := hud.get_accessibility_report()
	_check(bool(applied["high_contrast"]) and hud.is_high_contrast_hud(), "the HUD latches the high-contrast variant")
	_check(
		Color(applied["danger_color"]) == Palette.get_role_color(Palette.MODE_NONE, Palette.ROLE_DANGER, true)
		and Color(applied["danger_color"]) != Color(authored_report["danger_color"]),
		"state roles resolve to the high-contrast variant of the active palette"
	)
	_check(
		Color(applied["engine_label_color"]) == Palette.get_role_color(Palette.MODE_NONE, Palette.ROLE_DANGER, true),
		"an already-rendered offline engine readout is retinted to the variant immediately"
	)
	_check(
		interaction_box.bg_color == Palette.PANEL_BACKGROUND_HIGH_CONTRAST
		and objective_box.bg_color == Palette.PANEL_BACKGROUND_HIGH_CONTRAST
		and telemetry_box.bg_color == Palette.PANEL_BACKGROUND_HIGH_CONTRAST
		and interaction_box.bg_color.a == 1.0,
		"every HUD panel backing becomes the opaque high-contrast panel"
	)
	_check(
		objective_box.border_color == authored_border
		and [
			objective_box.border_width_left, objective_box.border_width_top,
			objective_box.content_margin_left, objective_box.content_margin_top,
		] == authored_widths,
		"the opaque backing changes only the fill, never a border width or content margin"
	)
	_check(
		objective_label.has_theme_constant_override("outline_size")
		and objective_label.get_theme_constant("outline_size") == GameHUD.HIGH_CONTRAST_TEXT_OUTLINE_SIZE
		and objective_label.get_theme_color("font_outline_color") == GameHUD.HIGH_CONTRAST_TEXT_OUTLINE_COLOR,
		"body text gains the dark high-contrast outline"
	)
	var authored_outline_kept := 0
	for candidate in (hud.get("_intro") as Control).find_children("*", "Label", true, false):
		var label := candidate as Label
		if label.has_theme_constant_override("outline_size") \
				and label.get_theme_constant("outline_size") > GameHUD.HIGH_CONTRAST_TEXT_OUTLINE_SIZE:
			authored_outline_kept += 1
	_check(
		authored_outline_kept >= 2,
		"labels that author their own larger outline keep it under high contrast (%d kept)" % authored_outline_kept
	)

	hud.set_hud_palette(Palette.MODE_DEUTERANOPIA)
	_check(
		Color(hud.get_accessibility_report()["danger_color"])
			== Palette.get_role_color(Palette.MODE_DEUTERANOPIA, Palette.ROLE_DANGER, true),
		"changing the colour-vision preset while high contrast is on selects that preset's variant"
	)
	hud.set_hud_palette(Palette.MODE_NONE)

	hud.set_high_contrast_hud(false)
	var restored := hud.get_accessibility_report()
	_check(
		not bool(restored["high_contrast"])
		and Color(restored["danger_color"]) == Color(authored_report["danger_color"])
		and Color(restored["nominal_color"]) == Color(authored_report["nominal_color"])
		and Color(restored["muted_color"]) == Color(authored_report["muted_color"])
		and Color(restored["engine_label_color"]) == Color(authored_report["engine_label_color"]),
		"turning high contrast off restores every authored role colour exactly"
	)
	_check(
		interaction_box.bg_color == authored_interaction_fill
		and objective_box.bg_color == authored_objective_fill
		and objective_box.border_color == authored_border,
		"turning high contrast off restores the authored translucent fills exactly"
	)
	_check(
		not objective_label.has_theme_constant_override("outline_size")
		and not objective_label.has_theme_color_override("font_outline_color"),
		"turning high contrast off removes only the outline the HUD added"
	)
	hud.set_accessibility({"high_contrast_hud": true, "colorblind_palette_id": Palette.MODE_TRITANOPIA})
	_check(
		hud.is_high_contrast_hud()
		and Color(hud.get_accessibility_report()["danger_color"])
			== Palette.get_role_color(Palette.MODE_TRITANOPIA, Palette.ROLE_DANGER, true),
		"the accessibility descriptor path applies the contrast flag before the palette"
	)
	hud.queue_free()
	await process_frame
	await process_frame


## The reticle styles change only the authored geometry. Every style keeps the
## four-bar silhouette, keeps the damage staging, reports itself in the
## component snapshot, and keeps the state label clear of the marks.
func _test_hud_reticle_styles() -> void:
	var hud := GameHUD.new()
	hud.name = "AccessibilityReticleHUD"
	root.add_child(hud)
	await process_frame
	hud.set_mode("piloting")
	hud.set_target_lock_state(&"acquired", "RANGE DEFENDER")
	var standard := hud.get_sensor_reticle_component_snapshot()
	_check(
		standard["style"] == &"standard" and int(standard["mark_count"]) == 4
		and int(standard["visible_mark_count"]) == 4
		and is_equal_approx(float(standard["footprint"]), 44.0),
		"the reticle starts in the authored standard style with four marks on a 44 px footprint"
	)
	var authored_marks: Array = []
	for mark: Dictionary in standard["marks"] as Array:
		authored_marks.append([mark["position"], mark["size"]])
	var expected_authored: Array = []
	for layout: Array in GameHUD.SENSOR_RETICLE_MARK_LAYOUT:
		expected_authored.append([layout[0], layout[1]])
	_check(authored_marks == expected_authored, "the standard style is bit-identical to the authored mark table")

	for style: StringName in [&"bold", &"large", &"standard"]:
		hud.set_reticle_style(style)
		await process_frame
		var snapshot := hud.get_sensor_reticle_component_snapshot()
		var layout := GameHUD.SENSOR_RETICLE_STYLE_LAYOUTS[style] as Dictionary
		var expected_marks := 5 if float(layout["centre_dot"]) > 0.0 else 4
		_check(
			snapshot["style"] == style and hud.get_reticle_style() == style
			and int(snapshot["mark_count"]) == expected_marks
			and int(snapshot["visible_mark_count"]) == expected_marks
			and is_equal_approx(float(snapshot["footprint"]), float(layout["footprint"]))
			and is_equal_approx(float(snapshot["mark_thickness"]), float(layout["thickness"])),
			"the %s style reports its style, %d marks and its footprint" % [style, expected_marks]
		)
		var reticle := hud.get("_reticle") as Control
		var label := hud.get("_reticle_state_label") as Label
		var label_rect := Rect2(label.position, label.size)
		var clear_of_marks := true
		var inside_footprint := true
		var reticle_rect := Rect2(Vector2.ZERO, reticle.size)
		for mark: Dictionary in snapshot["marks"] as Array:
			var mark_rect := Rect2(mark["position"], mark["size"])
			if bool(mark["visible"]) and mark_rect.intersects(label_rect):
				clear_of_marks = false
			if not reticle_rect.grow(0.01).encloses(mark_rect):
				inside_footprint = false
		_check(clear_of_marks, "the %s state label never overlaps a visible mark" % style)
		_check(inside_footprint, "every %s mark stays inside the reticle footprint" % style)
		_check(
			is_equal_approx(reticle.position.x, -reticle.size.x * 0.5)
			and is_equal_approx(reticle.pivot_offset.x, reticle.size.x * 0.5),
			"the %s reticle stays centred on the viewport" % style
		)
		_check(
			hud.get_sensor_reticle_component_snapshot()["lock_state"] == &"acquired",
			"rebuilding the %s reticle keeps the target-lock state" % style
		)
	_check(
		float((GameHUD.SENSOR_RETICLE_STYLE_LAYOUTS[&"large"] as Dictionary)["footprint"]) >= 44.0 * 1.6,
		"the large style is at least 1.6x the authored footprint"
	)
	_check(
		float((GameHUD.SENSOR_RETICLE_STYLE_LAYOUTS[&"bold"] as Dictionary)["thickness"]) > 4.0
		and is_equal_approx(float((GameHUD.SENSOR_RETICLE_STYLE_LAYOUTS[&"bold"] as Dictionary)["footprint"]), 44.0),
		"the bold style thickens the marks on the same 44 px footprint"
	)
	hud.set_reticle_style(&"not_a_style")
	_check(hud.get_reticle_style() == &"standard", "an unknown reticle style falls back to standard")
	hud.set_accessibility({"reticle_style": &"large"})
	_check(hud.get_reticle_style() == &"large", "the accessibility descriptor path selects the reticle style")
	hud.queue_free()
	await process_frame
	await process_frame


func _test_hud_palette_application() -> void:
	var hud := GameHUD.new()
	hud.name = "AccessibilityPaletteHUD"
	root.add_child(hud)
	await process_frame

	_check(hud.get_hud_palette_id() == Palette.MODE_NONE, "the HUD starts on the authored palette")
	var baseline := hud.get_accessibility_report()
	_check(
		Color(baseline["danger_color"]) == Palette.get_role_color(Palette.MODE_NONE, Palette.ROLE_DANGER),
		"the authored HUD palette is bit-identical to the pre-accessibility constants"
	)
	_check(int(baseline["palette_target_count"]) > 40, "the HUD registers its full set of palette targets")

	hud.set_engine_state("OFFLINE")
	hud.update_ship_telemetry({"damage_status": "critical", "throttle": -0.5, "hull": 10.0, "maximum_hull": 100.0})
	hud.set_enemy_status("DEFENDER", 10.0, 100.0, true)
	hud.set_hud_palette(Palette.MODE_DEUTERANOPIA)
	var applied := hud.get_accessibility_report()
	var expected_danger := Palette.get_role_color(Palette.MODE_DEUTERANOPIA, Palette.ROLE_DANGER)
	_check(hud.get_hud_palette_id() == Palette.MODE_DEUTERANOPIA, "the HUD adopts the requested preset")
	_check(Color(applied["danger_color"]) == expected_danger, "the HUD danger role resolves to the preset colour")
	_check(
		Color(applied["engine_label_color"]) == expected_danger,
		"an already-rendered offline engine readout is retinted immediately, not on the next telemetry tick"
	)
	_check(
		Color(applied["hull_label_color"]) == expected_danger,
		"an already-rendered critical hull readout is retinted immediately"
	)

	hud.set_hud_palette(&"not_a_palette")
	_check(
		hud.get_hud_palette_id() == Palette.MODE_NONE,
		"an invalid palette request falls back to the authored set instead of leaving a half-applied preset"
	)

	# Palette targets are registered as controls are built, and a page that
	# rebuilds its rows registers a fresh set every time. Retirement used to
	# happen only inside `set_hud_palette`, which a normal session never calls, so
	# the registry grew by one dead entry per rebuilt control for the life of the
	# session — and, because style boxes were held strongly, kept every freed
	# control's `StyleBoxFlat` alive with it.
	var rebuild_baseline := int(hud.get_accessibility_report()["palette_target_count"])
	for _rebuild_round in 40:
		hud.set_nearby_activity_snapshot({})
		await process_frame
	var rebuilt_count := int(hud.get_accessibility_report()["palette_target_count"])
	_check(
		rebuilt_count <= rebuild_baseline + 2 * GameHUD.PALETTE_TARGET_PRUNE_STRIDE,
		"forty page rebuilds leave the palette registry bounded without a palette change (%d -> %d)"
			% [rebuild_baseline, rebuilt_count]
	)

	hud.queue_free()
	await process_frame
	await process_frame


func _test_hud_scale_and_motion() -> void:
	var hud := GameHUD.new()
	hud.name = "AccessibilityScaleHUD"
	root.add_child(hud)
	await process_frame

	_check(is_equal_approx(hud.get_ui_scale(), 1.0), "UI scale starts at the authored one-to-one presentation")
	hud.set_ui_scale(1.4)
	var scaled := hud.get_accessibility_report()
	_check(is_equal_approx(hud.get_ui_scale(), 1.4), "UI scale accepts an in-range request")
	_check(int(scaled["scaled_layer_count"]) == 2, "both the gameplay panels and the pause panels scale")
	_check(
		is_equal_approx(float(scaled["scaled_layer_scale"]), hud.get_effective_ui_scale()),
		"the scaled layer adopts exactly the effective factor"
	)
	_check(
		hud.get_effective_ui_scale() <= hud.get_ui_scale() + 0.0001,
		"the effective factor never exceeds what the player requested"
	)
	_check(
		is_equal_approx(float(scaled["reticle_scale"]), 1.0),
		"the camera-space reticle is deliberately excluded from UI scaling"
	)
	hud.set_ui_scale(9.0)
	_check(is_equal_approx(hud.get_ui_scale(), 1.6), "an out-of-range UI scale clamps to the readable maximum")
	hud.set_ui_scale(-4.0)
	_check(is_equal_approx(hud.get_ui_scale(), 0.75), "a negative UI scale clamps to the readable minimum")
	hud.set_ui_scale(NAN)
	_check(is_equal_approx(hud.get_ui_scale(), 1.0), "a non-finite UI scale returns to the safe default")
	hud.set_ui_scale(1.0)
	_test_ui_scale_layout_ceiling()

	_check(not hud.is_reduced_motion(), "reduced motion starts off")
	_check(is_equal_approx(hud.get_damage_flash_alpha(), GameHUD.DAMAGE_FLASH_ALPHA), "the authored damage flash keeps its full intensity")
	hud.flash_damage(1.0, Vector2.RIGHT)
	var flash := hud.get("_damage_flash") as ColorRect
	var direction := hud.get("_damage_direction") as Label
	_check(
		is_equal_approx(flash.color.a, GameHUD.DAMAGE_FLASH_ALPHA),
		"the authored full-screen damage flash is unchanged while reduced motion is off"
	)
	hud.set_reduced_motion(true)
	_check(hud.is_reduced_motion(), "reduced motion latches on")
	_check(
		is_equal_approx(hud.get_damage_flash_alpha(), GameHUD.REDUCED_DAMAGE_FLASH_ALPHA)
		and GameHUD.REDUCED_DAMAGE_FLASH_ALPHA < GameHUD.DAMAGE_FLASH_ALPHA,
		"reduced motion damps the full-screen damage flash"
	)
	_check(is_zero_approx(hud.get_toast_fade_seconds()), "reduced motion removes the toast cross-fade")
	hud.flash_damage(1.0, Vector2.RIGHT)
	_check(
		is_equal_approx(flash.color.a, GameHUD.REDUCED_DAMAGE_FLASH_ALPHA),
		"a reduced-motion hit still reports damage, at a fraction of the luminance sweep"
	)
	_check(
		direction.visible and not is_zero_approx(direction.modulate.a),
		"reduced motion keeps the directional damage cue, which is information rather than motion"
	)
	hud.toast("Reduced motion toast", "detail", 0.1)
	var toast_panel := hud.get("_toast_panel") as PanelContainer
	_check(
		toast_panel.visible and is_equal_approx(toast_panel.modulate.a, 1.0),
		"a reduced-motion toast is fully legible on the first frame instead of fading in"
	)

	hud.queue_free()
	await process_frame
	await process_frame


## The gameplay panels are laid out with fixed pixel offsets, so a large request
## on a small window overlaps readouts rather than enlarging them. Rendered
## frames caught exactly that at 160%% on a 1280x720 viewport.
##
## RESOLVED. This block previously recorded a known gap: the ceiling clamped the
## request but the clamp was not collision-free, because the panels needed a
## 1512 px logical width while [constant GameHUD.MIN_LOGICAL_WIDTH] promised
## 1180. The two candidate fixes were mutually exclusive -- raising the constant
## to ~1420 removed the collision but capped a plain 100%% request on a 1280x720
## viewport, contradicting "the authored one-to-one presentation is never capped"
## below. The panels were re-anchored instead, so the layout genuinely fits the
## 1180x690 contract with 60x20 px of headroom and both properties now hold.
##
## No assertion here was weakened to achieve that: every check below is the one
## that was already here, and the collision-free claim the old comment declined
## to make is now made -- and measured against the real panel rectangles -- in
## `tests/hud_panel_layout_test.gd`.
func _test_ui_scale_layout_ceiling() -> void:
	var wide := GameHUD.compute_effective_ui_scale(1.6, Vector2(2560.0, 1440.0))
	_check(is_equal_approx(wide, 1.6), "a 1440p viewport honours the full requested scale")
	var small := GameHUD.compute_effective_ui_scale(1.6, Vector2(1280.0, 720.0))
	_check(
		small < 1.6 and small >= GameHUD.MIN_UI_SCALE,
		"a 720p viewport caps the request below the authored maximum (%.3f)" % small
	)
	_check(
		is_equal_approx(
			small,
			minf(1280.0 / GameHUD.MIN_LOGICAL_WIDTH, 720.0 / GameHUD.MIN_LOGICAL_HEIGHT)
		),
		"the ceiling is exactly the largest factor whose logical layout still fits"
	)
	_check(
		is_equal_approx(GameHUD.compute_effective_ui_scale(1.0, Vector2(1280.0, 720.0)), 1.0),
		"the authored one-to-one presentation is never capped"
	)
	_check(
		is_equal_approx(GameHUD.compute_effective_ui_scale(1.6, Vector2(320.0, 200.0)), GameHUD.MIN_UI_SCALE),
		"an absurdly small viewport still resolves to the readable minimum rather than zero"
	)
	_check(
		is_equal_approx(GameHUD.compute_effective_ui_scale(NAN, Vector2(2560.0, 1440.0)), 1.0),
		"a non-finite request resolves to the authored default before any ceiling is applied"
	)
	# The two properties that used to be in tension. Both are now true at once,
	# which is the whole point of having re-anchored the panels rather than
	# retuning the constant.
	var shipping_ceiling := GameHUD.compute_effective_ui_scale(GameHUD.MAX_UI_SCALE, Vector2(1600.0, 900.0))
	var shipping_logical := Vector2(1600.0, 900.0) / shipping_ceiling
	_check(
		shipping_logical.x >= GameHUD.MIN_LOGICAL_WIDTH - 0.001
		and shipping_logical.y >= GameHUD.MIN_LOGICAL_HEIGHT - 0.001,
		"the shipping 1600x900 ceiling of %.4f still delivers the %.0fx%.0f layout contract (%.0fx%.0f)"
		% [
			shipping_ceiling, GameHUD.MIN_LOGICAL_WIDTH, GameHUD.MIN_LOGICAL_HEIGHT,
			shipping_logical.x, shipping_logical.y,
		]
	)
	_check(
		GameHUD.MIN_LOGICAL_WIDTH <= 1280.0 and GameHUD.MIN_LOGICAL_HEIGHT <= 720.0,
		"the layout contract fits inside 1280x720, which is what makes the uncapped 100% above possible"
	)


func _test_hud_captions() -> void:
	var hud := GameHUD.new()
	hud.name = "AccessibilityCaptionHUD"
	root.add_child(hud)
	await process_frame
	var submitted: Array[Dictionary] = []
	var sink := func(request: Dictionary) -> bool:
		submitted.append(request.duplicate(true))
		return true
	_check(hud.bind_caption_event_submitter(sink), "the standalone HUD accepts one request-only caption sink")

	_check(not hud.are_captions_enabled(), "captions start off")
	_check(not hud.caption_cue(&"ship_explosion"), "no caption is produced while the preset is off")
	_check(submitted.is_empty(), "a disabled caption channel submits nothing")

	hud.set_captions_enabled(true)
	_check(hud.caption_cue(&"ship_explosion"), "an authored combat cue produces a caption")
	_check(hud.caption_cue(&"canopy_open"), "an authored flow cue produces a caption")
	_check(not hud.caption_cue(&"footstep_low"), "footsteps are deliberately excluded from the caption channel")
	_check(not hud.caption_cue(&"not_a_cue"), "an unknown cue never fabricates a caption")
	_check(
		submitted.size() == 2
		and submitted[0].cue_id == &"ship_explosion"
		and submitted[0].category_id == &"ambient"
		and str(submitted[0].speaker) == "Combat audio"
		and str(submitted[0].text) == "[ ship explosion ]"
		and is_equal_approx(
			float(submitted[0].duration_physics_seconds),
			GameHUD.CAPTION_DURATION_PHYSICS_SECONDS
		),
		"HUD cue mappings submit detached typed display intent in cue order"
	)
	(submitted[0] as Dictionary)["text"] = "caller mutation"
	_check(
		str(GameHUD.CAPTION_CUES[&"ship_explosion"][2]) == "[ ship explosion ]",
		"a sink cannot mutate the authored cue mapping back through its detached request"
	)

	hud.set_captions_enabled(false)
	_check(
		not hud.caption_cue(&"combat_alert") and submitted.size() == 2,
		"disabling captions stops requests without creating a parallel HUD queue"
	)
	_check(hud.unbind_caption_event_submitter(sink), "the request-only caption sink detaches cleanly")

	hud.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("ACCESSIBILITY_PRESETS_TEST_OK")
		quit(0)
	else:
		print("ACCESSIBILITY_PRESETS_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
