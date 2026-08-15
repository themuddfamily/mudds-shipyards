extends SceneTree

## Renders the live HUD under every accessibility preset so the readability of
## the colour-vision palettes, the UI-scale layout, and the caption channel can
## be reviewed by eye. Headless assertions do not establish readability.

const Palette := preload("res://scripts/ui/hud_palette.gd")
const OUTPUT_DIR := "res://artifacts/accessibility"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var hud := GameHUD.new()
	hud.name = "AccessibilityCaptureHUD"
	root.add_child(hud)
	await process_frame

	hud.set("_started", true)
	var intro := hud.get("_intro") as Control
	intro.visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("piloting")
	hud.set_ship_identity("Torrent-class Interceptor", "Interceptor")
	hud.set_objective("Return to the central berth and shut down", "CURRENT OBJECTIVE")
	hud.set_target_count(2, 3)
	hud.set_interaction("[ E ]  DOCK TORRENT", true)
	hud.set_enemy_status("RANGE DEFENCE INTERCEPTOR", 22.0, 100.0, true)

	for entry in [
		{"id": Palette.MODE_NONE, "engine": "ONLINE", "damage": "healthy", "hull": 100.0},
		{"id": Palette.MODE_NONE, "engine": "STARTING", "damage": "damaged", "hull": 52.0},
		{"id": Palette.MODE_NONE, "engine": "OFFLINE", "damage": "critical", "hull": 12.0},
		{"id": Palette.MODE_DEUTERANOPIA, "engine": "STARTING", "damage": "damaged", "hull": 52.0},
		{"id": Palette.MODE_DEUTERANOPIA, "engine": "OFFLINE", "damage": "critical", "hull": 12.0},
		{"id": Palette.MODE_PROTANOPIA, "engine": "STARTING", "damage": "damaged", "hull": 52.0},
		{"id": Palette.MODE_PROTANOPIA, "engine": "OFFLINE", "damage": "critical", "hull": 12.0},
		{"id": Palette.MODE_TRITANOPIA, "engine": "STARTING", "damage": "damaged", "hull": 52.0},
		{"id": Palette.MODE_TRITANOPIA, "engine": "OFFLINE", "damage": "critical", "hull": 12.0},
	]:
		hud.set_hud_palette(StringName(entry["id"]))
		hud.update_ship_telemetry({
			"speed": 74.0,
			"altitude": 318.0,
			"throttle": -0.65,
			"hull": float(entry["hull"]),
			"maximum_hull": 100.0,
			"damage_status": str(entry["damage"]),
			"engine_power": 0.62,
			"engine_state": str(entry["engine"]),
		})
		await _capture("hud_%s_%s" % [entry["id"], str(entry["damage"])])

	# Colour-vision presets, simulated as a dichromat would see them. The HUD is
	# hidden so the swatch sheet is reviewed against a clean panel background.
	hud.visible = false
	for mode_id: StringName in Palette.get_mode_ids():
		await _capture_swatches(mode_id)
	hud.visible = true

	hud.set_hud_palette(Palette.MODE_NONE)
	hud.set_captions_enabled(true)
	hud.caption_cue(&"combat_alert")
	hud.caption_cue(&"hull_impact_heavy")
	hud.caption_cue(&"ship_explosion")
	await _capture("hud_captions")

	for scale: float in [0.75, 1.0, 1.6]:
		hud.set_ui_scale(scale)
		await _capture("hud_scale_%03d" % roundi(scale * 100.0))
	hud.set_ui_scale(1.0)
	hud.set_captions_enabled(false)

	hud.set_paused(true)
	await _capture("pause_settings_scale_100")
	var open_button := (hud.get("_pause_main_page") as Control).find_child("SettingsOpenButton", true, false) as Button
	open_button.pressed.emit()
	await _capture("settings_panel_scale_100")
	hud.set_ui_scale(1.4)
	await _capture("settings_panel_scale_140")
	hud.set_paused(false)

	hud.queue_free()
	await process_frame
	print("CAPTURE_ACCESSIBILITY_PRESETS_OK")
	quit(0)


## Renders each palette's four state roles side by side, both as authored and as
## simulated for the deficiency the preset targets.
func _capture_swatches(mode_id: StringName) -> void:
	var sheet := Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Palette.PANEL_BACKGROUND
	sheet.add_child(background)

	var rows: Array[StringName] = [Palette.MODE_NONE]
	if Palette.MODE_TARGETS.has(mode_id):
		rows.append(Palette.MODE_TARGETS[mode_id])
	else:
		rows.append_array([Palette.MODE_DEUTERANOPIA, Palette.MODE_PROTANOPIA, Palette.MODE_TRITANOPIA])

	var palette := Palette.get_palette(mode_id)
	var y := 70.0
	for deficiency in rows:
		var caption := Label.new()
		caption.position = Vector2(60.0, y - 34.0)
		caption.add_theme_font_size_override("font_size", 22)
		caption.add_theme_color_override("font_color", Color.WHITE)
		caption.text = "%s  //  seen as %s" % [
			mode_id,
			"authored" if deficiency == Palette.MODE_NONE else deficiency,
		]
		sheet.add_child(caption)
		var x := 60.0
		for role in Palette.STATE_ROLES:
			var swatch := ColorRect.new()
			swatch.position = Vector2(x, y)
			swatch.size = Vector2(260.0, 130.0)
			var color := palette[role] as Color
			swatch.color = (
				color
				if deficiency == Palette.MODE_NONE
				else Palette.simulate_dichromacy(color, deficiency)
			)
			sheet.add_child(swatch)
			var name_label := Label.new()
			name_label.position = Vector2(x + 12.0, y + 92.0)
			name_label.add_theme_font_size_override("font_size", 22)
			name_label.add_theme_color_override("font_color", Palette.PANEL_BACKGROUND)
			name_label.text = String(role)
			sheet.add_child(name_label)
			x += 290.0
		y += 190.0
	await _capture("swatches_%s" % mode_id)
	sheet.queue_free()
	await process_frame


func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, label]
	image.save_png(path)
	print("CAPTURED: ", path)
