extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")

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
	var dismiss := hud.request_first_sortie_tutorial_action(&"dismiss")
	_check(dismiss.accepted, "dismiss action is accepted through HUD seam")
	_check(_intents.size() == 1 and _intents[0].kind == &"tutorial", "tutorial action forwards presentation intent")
	_check(_intents[0].payload.completion_intent.persist, "completion intent remains caller-owned")
	glyph_presenter.set_device_family(&"gamepad_xbox")
	hud.call("_refresh_input_prompts")
	_check(not (hud.get("_runtime_status_panel") as PanelContainer).visible and _intents.size() == 1, "dismissed tutorial cannot reappear on later glyph refresh")
	var invalid := hud.apply_first_sortie_tutorial_snapshot({"step_id": &"unknown"})
	_check(not invalid, "invalid tutorial snapshot is rejected")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	_intents.append({"kind": kind, "payload": payload})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
