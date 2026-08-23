extends SceneTree

const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")
const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var settings := RuntimeSettingsType.new()
	_check(settings.payload_visual_intensity == RuntimeSettingsType.DEFAULT_PAYLOAD_VISUAL_INTENSITY, "payload intensity defaults to high")
	settings.payload_visual_intensity = RuntimeSettingsType.MIN_PAYLOAD_VISUAL_INTENSITY
	var payload := settings.to_user_data_payload()
	_check(int(payload.schema_version) == RuntimeSettingsType.USER_DATA_PAYLOAD_SCHEMA_VERSION, "payload uses current settings schema")
	_check(payload.values.has("payload_visual_intensity"), "payload serializes visual intensity")
	var restored := RuntimeSettingsType.new()
	var applied := restored.apply_user_data_payload(payload)
	_check(bool(applied.accepted), "payload round-trip is accepted")
	_check(restored.payload_visual_intensity == RuntimeSettingsType.MIN_PAYLOAD_VISUAL_INTENSITY, "payload round-trip restores low intensity")
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	var selector := controls.get(&"payload_visual_intensity") as OptionButton
	_check(selector != null, "settings exposes payload intensity selector")
	_check(selector != null and selector.focus_mode == Control.FOCUS_ALL, "selector is controller-focusable")
	_check(selector != null and selector.item_count == 3 and selector.get_item_text(2) == "High", "selector matches low medium high vocabulary")
	hud.setting_change_requested.connect(_on_setting_change_requested)
	if selector != null:
		selector.select(0)
		selector.item_selected.emit(0)
	_check(_requests.size() == 1, "selector emits one persistence-compatible intent")
	_check(_requests.size() == 1 and _requests[0].get("key") == &"payload_visual_intensity", "intent preserves backend key")
	_check(_requests.size() == 1 and int(_requests[0].get("value", -1)) == 0, "intent carries selected low intensity")
	hud.set_settings_snapshot({"payload_visual_intensity": 2})
	_check(selector != null and selector.selected == 2, "live snapshot updates selector")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PAYLOAD_VISUAL_INTENSITY_SETTINGS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_setting_change_requested(key: StringName, value: Variant) -> void:
	_requests.append({"key": key, "value": value})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
