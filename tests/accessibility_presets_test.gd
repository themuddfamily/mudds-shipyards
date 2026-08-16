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
	await _test_hud_palette_application()
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
