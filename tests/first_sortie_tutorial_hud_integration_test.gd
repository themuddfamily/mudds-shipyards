extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.presentation_intent_requested.connect(_on_intent)
	_check(hud.apply_first_sortie_tutorial_snapshot({"step_id": &"board", "generation": 4}), "HUD accepts normal GameFlow tutorial snapshot")
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	_check(title.text == "Board" and detail.text.contains("E"), "HUD resolves current keyboard glyph in tutorial prompt")
	var glyph_presenter: Variant = hud.get("_runtime_input_glyph_presenter")
	glyph_presenter.set_device_family(&"gamepad_xbox")
	hud.call("_refresh_input_prompts")
	var xbox_interact := str(glyph_presenter.resolve_action(&"interact").get("text", "INPUT"))
	_check(detail.text.contains(xbox_interact) and not detail.text.contains("{interact}"), "active controller glyph refreshes the retained tutorial without changing progress")
	var remapped_profile: InputBindingProfile = RebindService.new().get_defaults()
	remapped_profile.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB}])
	hud.set_settings_snapshot({"input_binding_profile": remapped_profile.to_dictionary()})
	glyph_presenter.set_device_family(&"keyboard")
	hud.call("_refresh_input_prompts")
	_check(detail.text.contains("Tab") and _intents.is_empty(), "profile refresh redraws the same tutorial generation without emitting an intent")
	root.remove_child(hud)
	await process_frame
	hud.set_settings_snapshot({"input_binding_profile": RebindService.new().get_defaults().to_dictionary()})
	glyph_presenter.set_device_family(&"gamepad_xbox")
	root.add_child(hud)
	await process_frame
	var reentered_interact := str(glyph_presenter.resolve_action(&"interact").get("text", "INPUT"))
	_check(
		detail.text.contains(reentered_interact)
		and int((hud.get("_first_sortie_tutorial_source_snapshot") as Dictionary).get("generation", -1)) == 4
		and _intents.is_empty(),
		"retained HUD re-entry refreshes current glyphs without replacing tutorial generation or emitting intent"
	)
	var dismiss := hud.request_first_sortie_tutorial_action(&"dismiss")
	_check(dismiss.accepted, "dismiss action is accepted through HUD seam")
	_check(_intents.size() == 1 and _intents[0].kind == &"tutorial", "tutorial action forwards presentation intent")
	_check(_intents[0].payload.completion_intent.persist, "completion intent remains caller-owned")
	glyph_presenter.set_device_family(&"gamepad_xbox")
	hud.call("_refresh_input_prompts")
	root.remove_child(hud)
	await process_frame
	root.add_child(hud)
	await process_frame
	_check(not (hud.get("_runtime_status_panel") as PanelContainer).visible and _intents.size() == 1, "dismissed tutorial cannot reappear on later glyph refresh or retained re-entry")
	var invalid := hud.apply_first_sortie_tutorial_snapshot({"step_id": &"unknown"})
	_check(not invalid, "invalid tutorial snapshot is rejected")
	hud.queue_free()
	await process_frame
	await _test_show_tutorials_round_trip()
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	_intents.append({"kind": kind, "payload": payload})


func _test_show_tutorials_round_trip() -> void:
	var path := "user://first_sortie_tutorial_visibility_%d.cfg" % Time.get_ticks_usec()
	var settings := Settings.new(path)
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_settings_snapshot(settings.to_dictionary())
	hud.setting_change_requested.connect(
		func(key: StringName, value: Variant) -> void:
			settings.set(key, value)
			settings.save_to_file()
	)
	_check(hud.apply_first_sortie_tutorial_snapshot({"step_id": &"launch", "generation": 7}), "enabled persisted setting presents the current tutorial")
	var controls := hud.get("_settings_controls") as Dictionary
	var tutorial_toggle := controls.get(&"show_tutorials") as CheckButton
	tutorial_toggle.button_pressed = false
	_check(
		not (hud.get("_runtime_status_panel") as Control).visible
		and (hud.get("_first_sortie_tutorial_source_snapshot") as Dictionary).is_empty(),
		"turning the displayed tutorial setting off immediately clears the retained prompt"
	)
	hud.queue_free()
	await process_frame
	var restored := Settings.new(path)
	_check(restored.load_from_file() == OK and not restored.show_tutorials, "tutorial visibility persists off through RuntimeSettings")
	var reentered := HudType.new()
	root.add_child(reentered)
	await process_frame
	_check(reentered.apply_first_sortie_tutorial_snapshot({"step_id": &"fire", "generation": 8}), "re-entry witness starts with one visible retained tutorial")
	reentered.set_settings_snapshot(restored.to_dictionary())
	root.remove_child(reentered)
	root.add_child(reentered)
	await process_frame
	_check(
		not (reentered.get("_runtime_status_panel") as Control).visible
		and (reentered.get("_first_sortie_tutorial_source_snapshot") as Dictionary).is_empty(),
		"the restored off setting keeps the tutorial hidden across retained HUD re-entry"
	)
	reentered.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
