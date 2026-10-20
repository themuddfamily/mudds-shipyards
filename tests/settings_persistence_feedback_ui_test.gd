extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	var captions := controls.get(&"captions_enabled") as CheckButton
	captions.button_pressed = not captions.button_pressed
	_check(hud.has_unsaved_settings(), "live setting edit marks settings unsaved")
	_check(
		not hud.present_settings_persistence_result({"accepted": false, "reason": &"disk_unavailable"}),
		"save failure remains rejected"
	)
	_check(hud.has_unsaved_settings(), "save failure preserves unsaved state")
	var status_label := hud.get("_settings_status_label") as Label
	var status_identity: int = status_label.get_instance_id()
	_check_status_palette(hud, &"_settings_status_label", status_identity, &"danger", "save failure")
	_check(str(status_label.text).begins_with("SAVE FAILED"), "save failure is explicitly readable")
	hud.set_hud_palette(&"deuteranopia")
	_check_status_palette(hud, &"_settings_status_label", status_identity, &"danger", "failed palette repaint")
	hud.set_high_contrast_hud(true)
	_check_status_palette(hud, &"_settings_status_label", status_identity, &"danger", "failed contrast repaint")
	_check(
		hud.present_settings_persistence_result({"accepted": true}, &"save"),
		"accepted save clears persistence feedback"
	)
	_check(not hud.has_unsaved_settings(), "accepted save clears unsaved state")
	_check(status_label.text == "SETTINGS SAVED", "accepted save has clear confirmation")
	_check_status_palette(hud, &"_settings_status_label", status_identity, &"nominal_soft", "save success")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SETTINGS_PERSISTENCE_FEEDBACK_UI_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


func _check_status_palette(
	hud: GameHUD, field: StringName, identity: int, role: StringName, outcome: String
) -> void:
	var label: Label = hud.get(field) as Label
	var expected: Color = GameHUD.PaletteType.get_role_color(
		hud.get_hud_palette_id(), role, hud.is_high_contrast_hud()
	)
	var entries: int = 0
	var registered_role: StringName = &""
	var targets: Array = hud.get("_palette_targets") as Array
	for entry: Dictionary in targets:
		if entry.get("kind") == &"theme_color" and entry.get("node") == label \
				and entry.get("property") == &"font_color":
			entries += 1
			registered_role = StringName(entry.get("role", &""))
	_check(
		label.get_instance_id() == identity and entries == 1 and registered_role == role
		and label.modulate == Color.WHITE
		and label.get_theme_color("font_color") == expected
		and label.get_theme_color("font_color") * label.modulate == expected,
		outcome + " retains one current font role and applies its colour once"
	)
