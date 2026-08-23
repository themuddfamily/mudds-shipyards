class_name RuntimeDisplaySettingsPresenter
extends RefCounted

## Detached, controller/keyboard-focusable presentation for the persisted
## display preferences. It emits caller intents; RuntimeSettings remains the
## validation/persistence authority and startup remains the apply authority.

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const SCHEMA_VERSION := 1

var _attached := false
var _generation := 0
var _resolution_id := Settings.DEFAULT_DISPLAY_RESOLUTION_ID
var _vsync_id: StringName = &"on"


func attach(settings: RuntimeSettings) -> Dictionary:
	if settings == null:
		return _reject(&"settings_missing")
	_resolution_id = settings.display_resolution
	_vsync_id = settings.get_vsync_mode_id()
	_attached = true
	_generation += 1
	return get_snapshot()


func detach() -> Dictionary:
	_attached = false
	_generation += 1
	return get_snapshot()


func select_resolution(resolution_id: StringName, expected_generation: int = -1) -> Dictionary:
	var rejected := _validate(expected_generation)
	if not rejected.is_empty():
		return rejected
	if not Settings.SUPPORTED_DISPLAY_RESOLUTION_IDS.has(String(resolution_id)):
		return _reject(&"unsupported_resolution")
	_resolution_id = String(resolution_id)
	return _intent(&"display_resolution_changed", {"display_resolution": _resolution_id})


func select_vsync(vsync_id: StringName, expected_generation: int = -1) -> Dictionary:
	var rejected := _validate(expected_generation)
	if not rejected.is_empty():
		return rejected
	if not [&"off", &"on", &"adaptive"].has(vsync_id):
		return _reject(&"unsupported_vsync")
	_vsync_id = vsync_id
	return _intent(&"vsync_mode_changed", {"vsync_mode": _vsync_id})


func get_snapshot() -> Dictionary:
	var resolutions: Array[Dictionary] = []
	for resolution_id: String in Settings.SUPPORTED_DISPLAY_RESOLUTION_IDS:
		resolutions.append({
			"id": StringName(resolution_id),
			"label": resolution_id.replace("x", " × "),
			"selected": resolution_id == _resolution_id,
			"focusable": true,
		})
	var vsync_modes: Array[Dictionary] = []
	for vsync_id: StringName in [&"off", &"on", &"adaptive"]:
		vsync_modes.append({
			"id": vsync_id,
			"label": String(vsync_id).capitalize(),
			"selected": vsync_id == _vsync_id,
			"focusable": true,
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"attached": _attached,
		"generation": _generation,
		"status": &"ready" if _attached else &"detached",
		"rows": [
			{"id": &"display_resolution", "label": "Resolution", "options": resolutions, "focusable": true},
			{"id": &"vsync_mode", "label": "VSync", "options": vsync_modes, "focusable": true},
		],
		"focus_order": [&"display_resolution", &"vsync_mode"],
		"display_resolution": StringName(_resolution_id),
		"vsync_mode": _vsync_id,
		"presentation_only": true,
		"settings_authority": false,
		"persistence_owned_by_caller": true,
		"runtime_apply_owned_by_startup": true,
	}.duplicate(true)


func _validate(expected_generation: int) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if expected_generation >= 0 and expected_generation != _generation:
		return _reject(&"stale_generation")
	return {}


func _intent(intent: StringName, values: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"intent": intent,
		"generation": _generation,
		"values": values,
		"snapshot": get_snapshot(),
		"presentation_only": true,
		"settings_authority": false,
	}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true, "settings_authority": false}
