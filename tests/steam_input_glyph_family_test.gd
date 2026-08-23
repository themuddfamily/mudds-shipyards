extends SceneTree

const Resolver := preload("res://scripts/ui/input_glyph_resolver.gd")
const Presenter := preload("res://scripts/ui/runtime_input_glyph_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const InputBindingProfile := preload("res://scripts/settings/input_binding_profile.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var resolver := Resolver.new()
	_check(Resolver.gamepad_family_from_metadata({"layout": "steam_deck"}) == Resolver.FAMILY_GAMEPAD_STEAM, "Steam Deck metadata selects Steam glyph family")
	var south := Resolver.resolve_binding({"type": &"joy_button", "device": &"gamepad", "button_index": JOY_BUTTON_A}, Resolver.FAMILY_GAMEPAD_STEAM)
	_check(south.text == "A" and south.glyph_token == &"gamepad.steam.a", "Steam preserves physical south face-button semantics")
	var shoulder := Resolver.resolve_binding({"type": &"joy_button", "device": &"gamepad", "button_index": JOY_BUTTON_LEFT_SHOULDER}, Resolver.FAMILY_GAMEPAD_STEAM)
	_check(shoulder.text == "LB", "Steam exposes shoulder glyph labels")
	var profile := InputBindingProfile.new()
	profile.bindings[&"interact"] = [{"type": &"joy_button", "device": &"gamepad", "button_index": JOY_BUTTON_A}]
	var presenter := Presenter.new(resolver)
	presenter.attach(profile)
	_check(presenter.supports_device_family(Presenter.DEVICE_FAMILY_STEAM), "presenter exposes Steam family")
	presenter.set_device_family(Presenter.DEVICE_FAMILY_STEAM)
	_check(presenter.resolve_action(&"interact").text == "A", "presenter refreshes remapped Steam action glyph")
	_check(not presenter.set_device_family(&"unknown_family").get("accepted", false), "unknown family remains rejected with generic fallback policy")
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var selector := (hud.get("_settings_page") as Control).find_child("ControllerGlyphFamilyControl", true, false) as OptionButton
	_check(selector.item_count == 6 and selector.get_item_text(5) == "Steam Deck" and selector.focus_mode == Control.FOCUS_ALL, "settings selector exposes focused Steam Deck choice")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STEAM_INPUT_GLYPH_FAMILY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
