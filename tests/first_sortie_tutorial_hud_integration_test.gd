extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
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
	_check(hud.apply_first_sortie_tutorial_snapshot({"step_id": &"board", "generation": 4, "revision": 1}), "HUD accepts normal GameFlow tutorial snapshot")
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	_check(title.text == "Board" and detail.text.contains("E"), "HUD resolves current keyboard glyph in tutorial prompt")
	var glyph_presenter: Variant = hud.get("_runtime_input_glyph_presenter")
	glyph_presenter.set_device_family(&"gamepad_xbox")
	hud.call("_refresh_input_prompts")
	var xbox_interact := str(glyph_presenter.resolve_action(&"interact").get("text", "INPUT"))
	_check(detail.text.contains(xbox_interact) and not detail.text.contains("{interact}"), "active controller glyph refreshes the retained tutorial without changing progress")
	var default_profile: Variant = hud.get("_input_binding_profile")
	var remapped_profile: Variant = default_profile.duplicate_profile()
	remapped_profile.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB}])
	hud.set_settings_snapshot({"input_binding_profile": remapped_profile.to_dictionary()})
	glyph_presenter.set_device_family(&"keyboard")
	hud.call("_refresh_input_prompts")
	_check(detail.text.contains("Tab") and _intents.is_empty(), "profile refresh redraws the same tutorial generation without emitting an intent")
	root.remove_child(hud)
	await process_frame
	hud.set_settings_snapshot({"input_binding_profile": default_profile.to_dictionary()})
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
	var next := hud.find_child("RuntimeStatusNextButton", true, false) as Button
	var repeat := hud.find_child("RuntimeStatusRepeatButton", true, false) as Button
	var dismiss := hud.find_child("RuntimeStatusDismissButton", true, false) as Button
	_check(
		is_instance_valid(next)
		and is_instance_valid(repeat)
		and is_instance_valid(dismiss)
		and next.focus_neighbor_left == next.get_path_to(next)
		and next.focus_neighbor_right == next.get_path_to(repeat)
		and repeat.focus_neighbor_left == repeat.get_path_to(next)
		and repeat.focus_neighbor_right == repeat.get_path_to(dismiss)
		and dismiss.focus_neighbor_left == dismiss.get_path_to(repeat)
		and dismiss.focus_neighbor_right == dismiss.get_path_to(dismiss)
		and hud.get_viewport().gui_get_focus_owner() == next,
		"tutorial buttons have deterministic controller focus order and initial focus"
	)
	repeat.pressed.emit()
	_check(
		_intents.size() == 1
		and _intents[0].kind == &"tutorial"
		and _intents[0].payload.action == &"repeat"
		and _intents[0].payload.has("completion_intent")
		and not _intents[0].payload.has("snapshot"),
		"rendered Repeat button uses the tutorial request API with a top-level completion intent"
	)
	next.pressed.emit()
	_check(
		_intents.size() == 2
		and _intents[1].payload.action == &"next"
		and _intents[1].payload.completion_intent.generation == 4
		and _intents[1].payload.completion_intent.revision == 1,
		"rendered Next button forwards the current authoritative tutorial fence"
	)
	dismiss.pressed.emit()
	_check(
		_intents.size() == 3
		and _intents[2].payload.action == &"dismiss"
		and _intents[2].payload.completion_intent.persist,
		"rendered Dismiss button clears through the tutorial request contract"
	)
	glyph_presenter.set_device_family(&"gamepad_xbox")
	hud.call("_refresh_input_prompts")
	root.remove_child(hud)
	await process_frame
	root.add_child(hud)
	await process_frame
	_check(not (hud.get("_runtime_status_panel") as PanelContainer).visible and _intents.size() == 3, "dismissed tutorial cannot reappear on later glyph refresh or retained re-entry")
	_check(hud.apply_first_sortie_tutorial_snapshot({"step_id": &"board", "generation": 0, "revision": 1}), "dismiss clear permits presenter reuse by a fresh authoritative source")
	hud.clear_first_sortie_tutorial(&"session_lost")
	_check(
		not (hud.get("_runtime_status_panel") as PanelContainer).visible
		and (hud.get("_first_sortie_tutorial_source_snapshot") as Dictionary).is_empty(),
		"real session loss clears retained HUD prompt and presenter fence"
	)
	var invalid := hud.apply_first_sortie_tutorial_snapshot({"step_id": &"unknown", "generation": 1, "revision": 1})
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
	_check(hud.apply_first_sortie_tutorial_snapshot({"step_id": &"launch", "generation": 7, "revision": 1}), "enabled persisted setting presents the current tutorial")
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
	_check(reentered.apply_first_sortie_tutorial_snapshot({"step_id": &"fire", "generation": 8, "revision": 1}), "re-entry witness starts with one visible retained tutorial")
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
