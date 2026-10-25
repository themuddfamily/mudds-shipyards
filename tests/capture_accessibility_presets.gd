extends SceneTree

## Renders the live HUD under every accessibility preset so the readability of
## the colour-vision palettes, the UI-scale layout, and the caption channel can
## be reviewed by eye. Headless assertions do not establish readability.

const Palette := preload("res://scripts/ui/hud_palette.gd")
const DEFAULT_OUTPUT_DIR := "res://artifacts/accessibility"
## `ACCESSIBILITY_CAPTURE_DIR` redirects the PNGs (an absolute path is fine);
## `ACCESSIBILITY_CAPTURE_SET=presentation` renders only the piloting-state
## contrast/reticle pair; `settings-extremes` renders Settings top/middle/bottom
## at requested scales 0.75/1.6 at 1024x768. `ACCESSIBILITY_CAPTURE_SIZE=WxH`
## sizes the viewport (required as 1024x768 for settings-extremes).
var _output_dir := DEFAULT_OUTPUT_DIR
## Every capture is checked for a blank frame: the count of distinct colours on
## a sampling grid is printed, and a uniform frame is reported as such.
var _blank_frames := 0
var _capture_failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var override_dir := OS.get_environment("ACCESSIBILITY_CAPTURE_DIR")
	if not override_dir.is_empty():
		_output_dir = override_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	var size_override := OS.get_environment("ACCESSIBILITY_CAPTURE_SIZE")
	if size_override.contains("x"):
		var parts := size_override.split("x")
		var requested := Vector2i(int(parts[0]), int(parts[1]))
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.content_scale_size = requested
		root.size = requested
		await process_frame
		await process_frame
		print("CAPTURE_VIEWPORT ", root.get_visible_rect().size)
	if OS.get_environment("ACCESSIBILITY_CAPTURE_SET") == "presentation":
		await _capture_presentation_pair()
		_finish()
		return
	if OS.get_environment("ACCESSIBILITY_CAPTURE_SET") == "settings-extremes":
		await _capture_settings_extremes()
		_finish()
		return
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
	await _capture_presentation_pair()
	_finish()


func _finish() -> void:
	if not _capture_failure.is_empty():
		print("CAPTURE_ACCESSIBILITY_PRESETS_FAILED: %s" % _capture_failure)
		quit(1)
		return
	if _blank_frames > 0:
		print("CAPTURE_ACCESSIBILITY_PRESETS_FAILED: %d blank frame(s)" % _blank_frames)
		quit(1)
		return
	print("CAPTURE_ACCESSIBILITY_PRESETS_OK")
	quit(0)


## Source-component coverage: open the actual paused Settings page through its
## button, retaining production scale clamping and the actual scroll content.
func _capture_settings_extremes() -> void:
	if root.get_visible_rect().size != Vector2(1024.0, 768.0):
		_capture_failure = "settings-extremes requires actual viewport 1024x768"
		return
	var hud := GameHUD.new()
	hud.name = "AccessibilitySettingsExtremesCaptureHUD"
	root.add_child(hud)
	await process_frame
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_paused(true)
	var main_page := hud.get("_pause_main_page") as Control
	if main_page == null:
		_capture_failure = "missing actual pause main page"
		return
	var open_button := main_page.find_child("SettingsOpenButton", true, false) as Button
	if open_button == null or not open_button.is_visible_in_tree():
		_capture_failure = "missing visible SettingsOpenButton"
		return
	open_button.pressed.emit()
	# Opening Settings focuses its first control. Let that deferred scroll settle
	# before releasing focus and selecting the three explicit content positions.
	await process_frame
	await process_frame
	root.gui_release_focus()
	var page := hud.get("_settings_page") as Control
	var scroll := hud.get("_settings_scroll") as ScrollContainer
	if page == null or scroll == null:
		_capture_failure = "missing actual Settings page or scroll surface"
		return
	for requested: float in [0.75, 1.6]:
		hud.set_ui_scale(requested)
		await process_frame
		await process_frame
		var effective := float(hud.get("_pause_effective_ui_scale"))
		var expected := minf(requested, minf(1024.0 / 880.0, 768.0 / 760.0))
		if not is_equal_approx(effective, expected):
			_capture_failure = "pause scale requested=%s actual=%s expected=%s" % [requested, effective, expected]
			return
		var bar := scroll.get_v_scroll_bar()
		for position_name: String in ["top", "middle", "bottom"]:
			var end := bar.max_value - bar.page
			if end <= 0.0:
				_capture_failure = "Settings content has no scroll range"
				return
			var target := 0.0
			if position_name == "middle":
				target = floorf(end / 2.0)
			elif position_name == "bottom":
				target = end
			bar.value = target
			await process_frame
			await process_frame
			if not is_equal_approx(bar.value, target) or not is_equal_approx(bar.max_value - bar.page, end):
				_capture_failure = "Settings scroll failed to settle at %s" % position_name
				return
			if not _settings_capture_controls_visible(page, scroll):
				return
			var label := "settings_panel_scale_%03d_%s" % [roundi(requested * 100.0), position_name]
			print(
				"CAPTURE_STATE %s requested=%.6f effective=%.6f viewport=%s scroll_vertical=%d value=%.6f max=%.6f page=%.6f"
				% [label, requested, effective, root.get_visible_rect().size,
					scroll.scroll_vertical, bar.value, bar.max_value, bar.page]
			)
			if not await _capture(label):
				_capture_failure = "Settings capture artifact failed: %s" % label
				return
	hud.set_paused(false)
	hud.queue_free()
	await process_frame


func _settings_capture_controls_visible(page: Control, scroll: ScrollContainer) -> bool:
	var viewport := root.get_visible_rect().grow(0.5)
	if not _capture_control_inside(page, viewport) or not _capture_control_inside(scroll, viewport):
		_capture_failure = "Settings page or scroll surface is hidden or outside viewport"
		return false
	var heading: Label
	for candidate: Node in page.find_children("*", "Label", true, false):
		if (candidate as Label).text == "SHIP SYSTEM SETTINGS":
			heading = candidate as Label
			break
	if not _capture_control_inside(heading, viewport) or scroll.is_ancestor_of(heading):
		_capture_failure = "missing visible fixed Settings heading"
		return false
	for button_name: String in ["SettingsSaveButton", "SettingsResetButton", "SettingsBackButton"]:
		var button := page.find_child(button_name, true, false) as Button
		if not _capture_control_inside(button, viewport) or scroll.is_ancestor_of(button):
			_capture_failure = "missing visible fixed Settings footer: %s" % button_name
			return false
	if scroll.get_child_count() < 1:
		_capture_failure = "missing Settings content columns"
		return false
	var columns := scroll.get_child(0) as HBoxContainer
	if columns == null or columns.get_child_count() != 2:
		_capture_failure = "missing both actual Settings columns"
		return false
	var surface := scroll.get_global_rect()
	for child: Node in columns.get_children():
		var column := child as VBoxContainer
		if column == null or not column.is_visible_in_tree() or not surface.intersects(column.get_global_rect()):
			_capture_failure = "Settings column is missing or outside scroll surface"
			return false
		var rect := column.get_global_rect()
		if rect.position.x < surface.position.x - 0.5 or rect.end.x > surface.end.x + 0.5:
			_capture_failure = "Settings column is horizontally clipped"
			return false
	return true


func _capture_control_inside(control: Control, rect: Rect2) -> bool:
	return (
		control != null and control.is_visible_in_tree()
		and control.size.x > 0.0 and control.size.y > 0.0
		and rect.encloses(control.get_global_rect())
	)


## The piloting HUD as authored (palette `none`, contrast off, standard reticle)
## beside the high-contrast HUD with the large reticle, on the same telemetry,
## so the opaque backings, outlined text and wider reticle can be compared.
func _capture_presentation_pair() -> void:
	var hud := GameHUD.new()
	hud.name = "AccessibilityPresentationCaptureHUD"
	root.add_child(hud)
	await process_frame
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("piloting")
	hud.set_ship_identity("Torrent-class Interceptor", "Interceptor")
	hud.set_objective("Return to the central berth and shut down", "CURRENT OBJECTIVE")
	hud.set_target_count(2, 3)
	hud.set_interaction("[ E ]  DOCK TORRENT", true)
	hud.set_enemy_status("RANGE DEFENCE INTERCEPTOR", 22.0, 100.0, true)
	hud.set_target_lock_state(&"acquired", "RANGE DEFENDER")
	hud.set_engine_state("STARTING")
	hud.update_ship_telemetry({
		"speed": 74.0,
		"altitude": 318.0,
		"throttle": -0.65,
		"hull": 52.0,
		"maximum_hull": 100.0,
		"damage_status": "damaged",
		"engine_power": 0.62,
		"engine_state": "STARTING",
	})
	for entry in [
		{"label": "hud_piloting_standard_none", "high_contrast_hud": false, "reticle_style": &"standard"},
		{"label": "hud_piloting_high_contrast_large", "high_contrast_hud": true, "reticle_style": &"large"},
	]:
		hud.set_accessibility({
			"colorblind_palette_id": Palette.MODE_NONE,
			"high_contrast_hud": bool(entry["high_contrast_hud"]),
			"reticle_style": StringName(entry["reticle_style"]),
		})
		var reticle := hud.get_sensor_reticle_component_snapshot()
		print(
			"CAPTURE_STATE %s high_contrast=%s reticle=%s marks=%d footprint=%.0f"
			% [
				entry["label"], hud.is_high_contrast_hud(), reticle["style"],
				int(reticle["mark_count"]), float(reticle["footprint"]),
			]
		)
		await _capture(str(entry["label"]))
	hud.queue_free()
	await process_frame


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


func _capture(label: String) -> bool:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_output_dir, label]
	var saved := image.save_png(path)
	var distinct := _distinct_sampled_colours(image)
	if distinct <= 1:
		_blank_frames += 1
	print(
		"CAPTURED: %s (%dx%d, save=%d, distinct_sampled_colours=%d%s)"
		% [path, image.get_width(), image.get_height(), saved, distinct, "" if distinct > 1 else ", BLANK"]
	)
	return saved == OK and distinct > 1


## Number of distinct colours on a 64x36 sampling grid. One means a uniform,
## blank frame; the composed HUD produces hundreds.
func _distinct_sampled_colours(image: Image) -> int:
	var seen := {}
	var columns := 64
	var rows := 36
	for row in rows:
		for column in columns:
			var x := int((column + 0.5) * image.get_width() / columns)
			var y := int((row + 0.5) * image.get_height() / rows)
			seen[image.get_pixel(x, y).to_rgba32()] = true
	return seen.size()
