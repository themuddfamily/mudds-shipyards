extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")
const CinderType := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var settings := RuntimeSettingsType.new()
	var bomber := CinderType.new()
	root.add_child(bomber)
	await process_frame
	flow.runtime_settings = settings
	flow.ships.append(bomber)
	flow._apply_bomber_payload_presentation_profile(bomber)
	_check(_profile(bomber).get("graphics_profile") == &"high" and not bool(_profile(bomber).get("reduced_flash", true)), "startup applies default high payload profile")
	settings.payload_visual_intensity = 0
	settings.reduced_flash = true
	flow._on_runtime_setting_changed(&"payload_visual_intensity", 0)
	flow._on_runtime_setting_changed(&"reduced_flash", true)
	_check(_profile(bomber).get("graphics_profile") == &"low" and bool(_profile(bomber).get("reduced_flash", false)), "live settings apply low intensity and reduced flash")
	settings.payload_visual_intensity = 1
	settings.reduced_flash = false
	flow._apply_bomber_payload_presentation_profile(bomber)
	_check(_profile(bomber).get("graphics_profile") == &"medium" and not bool(_profile(bomber).get("reduced_flash", true)), "craft re-entry applies medium profile independently")
	settings.reset_to_defaults()
	flow._apply_bomber_payload_presentation_profile(bomber)
	_check(_profile(bomber).get("graphics_profile") == &"high" and not bool(_profile(bomber).get("reduced_flash", true)), "reset restores high profile and flash policy")
	bomber.queue_free()
	flow.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_BOMBER_PAYLOAD_SETTINGS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _profile(bomber: Node) -> Dictionary:
	return bomber.get_payload_presentation().get_presentation_profile()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
