class_name RuntimeAccessibilityPresentation
extends RefCounted

## Detached runtime presentation adapter for the accessibility-facing HUD.
##
## This is the narrow seam between runtime cue observations and UI output.  It
## composes the existing visual, caption, audio-fallback and ultrawide
## contracts, and exposes server-browser wording without owning a Control,
## settings store, audio playback, networking, or gameplay authority.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"runtime-accessibility-presentation"
const VisualPreset := preload("res://scripts/ui/accessibility_visual_preset.gd")
const CaptionContract := preload("res://scripts/ui/caption_accessibility_contract.gd")
const AudioPreset := preload("res://scripts/audio/audio_accessibility_preset.gd")
const SafeAreaContract := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")
const ServerBrowserPresenter := preload("res://scripts/ui/server_browser_presenter.gd")
const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")

const VISUAL_FIELDS: Array[StringName] = [&"visual", &"captions", &"audio"]
const VISUAL_CATEGORIES: Array[StringName] = [
	&"info", &"caution", &"danger", &"objective", &"navigation",
]
const CAPTION_CATEGORIES: Array[StringName] = [&"dialogue", &"radio", &"system", &"ambient"]
const STATUS_SETTING_FIELDS: Array[StringName] = [
	&"captions_enabled",
	&"reduced_flash",
	&"reduced_motion",
	&"ui_scale",
	&"colorblind_palette",
]
const PALETTE_LABELS := {
	&"none": "Standard colours",
	&"deuteranopia": "Deuteranopia alternative",
	&"protanopia": "Protanopia alternative",
	&"tritanopia": "Tritanopia alternative",
}
const PALETTE_VALUES := {
	&"none": RuntimeSettingsType.ColorblindPalette.NONE,
	&"deuteranopia": RuntimeSettingsType.ColorblindPalette.DEUTERANOPIA,
	&"protanopia": RuntimeSettingsType.ColorblindPalette.PROTANOPIA,
	&"tritanopia": RuntimeSettingsType.ColorblindPalette.TRITANOPIA,
}

var _visual: RefCounted = VisualPreset.new()
var _captions: RefCounted = CaptionContract.new()
var _audio: RefCounted = AudioPreset.new()
var _revision := 0
var _settings: RuntimeSettings
var _attached := false
var _status_confirmation: Dictionary = {}


## Read-only lifecycle seam for the validated RuntimeSettings authority.  An
## exact revision is mandatory so a recycled HUD cannot attach, refresh or
## detach an older presenter lifetime.  The staged descriptor is fully checked
## before an existing attachment is replaced.
func attach(settings: RuntimeSettings, expected_revision: int) -> Dictionary:
	var fenced := _validate_revision(expected_revision)
	if not fenced.is_empty():
		return fenced
	if settings == null or not is_instance_valid(settings):
		return _reject(&"settings_missing")
	var staged := _build_status_confirmation(settings.get_accessibility_descriptor())
	if not bool(staged.get("accepted", false)):
		return _reject(StringName(staged.get("reason", &"invalid_accessibility_descriptor")))
	_disconnect_settings()
	_settings = settings
	_attached = true
	_status_confirmation = (staged.status as Dictionary).duplicate(true)
	_settings.setting_changed.connect(_on_setting_changed)
	_revision += 1
	return _lifecycle_result(&"attached")


## Explicit refresh for callers that batch settings changes. RuntimeSettings'
## normal `setting_changed` signal also refreshes immediately without polling.
func refresh_status(expected_revision: int) -> Dictionary:
	var fenced := _validate_revision(expected_revision)
	if not fenced.is_empty():
		return fenced
	if not _attached or not is_instance_valid(_settings):
		return _reject(&"detached")
	return _refresh_attached(expected_revision, &"refreshed")


## Clears the retained settings reference, signal connection and visible card.
## The instance can be attached again at the returned exact revision.
func detach(expected_revision: int) -> Dictionary:
	var fenced := _validate_revision(expected_revision)
	if not fenced.is_empty():
		return fenced
	_disconnect_settings()
	_settings = null
	_attached = false
	_status_confirmation.clear()
	_revision += 1
	return _lifecycle_result(&"detached")


## Applies the three presentation policies as one transaction.  The candidate
## policies are validated before replacing the live policies, so malformed
## visual/caption/audio combinations cannot leave half an accessibility profile.
func configure(request: Dictionary) -> Dictionary:
	for key in request.keys():
		if not VISUAL_FIELDS.has(StringName(key)):
			return _reject(&"unknown_profile_field", StringName(key))
		if not request[key] is Dictionary:
			return _reject(&"invalid_profile_section", StringName(key))
	var visual_candidate: RefCounted = VisualPreset.new()
	var captions_candidate: RefCounted = CaptionContract.new()
	var audio_candidate: RefCounted = AudioPreset.new()
	var visual_result: Dictionary = visual_candidate.configure(_visual.get_snapshot())
	if not bool(visual_result.accepted):
		return _reject(&"invalid_visual_state")
	var caption_state := _captions.get_profile_snapshot().get("profile", {}) as Dictionary
	var caption_result: Dictionary = captions_candidate.configure(caption_state)
	if not bool(caption_result.accepted):
		return _reject(&"invalid_caption_state")
	var audio_result: Dictionary = audio_candidate.configure(_audio.get_snapshot())
	if not bool(audio_result.accepted):
		return _reject(&"invalid_audio_state")
	if request.has("visual"):
		visual_result = visual_candidate.configure(request.visual)
		if not bool(visual_result.accepted):
			return _reject(&"invalid_visual_profile")
	if request.has("captions"):
		caption_result = captions_candidate.configure(request.captions)
		if not bool(caption_result.accepted):
			return _reject(&"invalid_caption_profile")
	if request.has("audio"):
		audio_result = audio_candidate.configure(request.audio)
		if not bool(audio_result.accepted):
			return _reject(&"invalid_audio_profile")
	_visual = visual_candidate
	_captions = captions_candidate
	_audio = audio_candidate
	_revision += 1
	return {"accepted": true, "reason": &"applied", "revision": _revision, "snapshot": get_snapshot()}


## Resolves an already-observed cue into independent presentation decisions.
## The caller remains responsible for enqueueing captions or playing audio.
func resolve_cue(cue: Dictionary) -> Dictionary:
	if not cue is Dictionary or str(cue.get("cue_id", "")).is_empty():
		return _reject(&"invalid_cue")
	var visual_category := StringName(cue.get("visual_category", cue.get("category", &"info")))
	if not VISUAL_CATEGORIES.has(visual_category):
		return _reject(&"invalid_visual_category")
	var visual: Dictionary = _visual.resolve_cue(
		StringName(cue.cue_id),
		visual_category,
		bool(cue.get("audible", true)),
		true,
		bool(cue.get("key_cue", false)),
		float(cue.get("contrast_ratio", 7.0)),
	)
	if not bool(visual.accepted):
		return _reject(StringName(visual.get("reason", &"invalid_visual_cue")))
	var audio: Dictionary = _audio.resolve_cue(
		StringName(cue.cue_id),
		StringName(cue.get("bus", &"UI")),
		bool(cue.get("key_cue", false)),
		float(cue.get("flash_strength", 1.0)),
		float(cue.get("motion_strength", 1.0)),
	)
	if not bool(audio.accepted):
		return _reject(StringName(audio.get("reason", &"invalid_audio_cue")))
	var caption_category := StringName(cue.get("caption_category", &"system"))
	if not CAPTION_CATEGORIES.has(caption_category):
		return _reject(&"invalid_caption_category")
	var caption: Dictionary = _captions.resolve_cue({
		"stable_id": StringName(cue.cue_id),
		"category": caption_category,
		"priority": int(cue.get("priority", 0)),
		"audible": bool(cue.get("audible", true)),
		"speaker": str(cue.get("speaker", "")),
		"text": str(cue.get("text", "")),
	})
	return {
		"accepted": true,
		"cue_id": StringName(cue.cue_id),
		"visual": visual,
		"audio": audio,
		"caption": caption,
		"caption_visible": bool(caption.get("accepted", false)),
		"presentation_only": true,
		"gameplay_authority": false,
		"audio_authority": false,
		"caption_authority": false,
		"revision": _revision,
	}.duplicate(true)


## Places a UI prompt inside the shared safe-area policy for any supported
## viewport, including 21:9 and 32:9 desktop layouts.
func fit_prompt(viewport_size: Vector2, desired_size: Vector2, anchor: StringName = &"bottom_center") -> Dictionary:
	return SafeAreaContract.fit_prompt(viewport_size, desired_size, anchor, float(_visual.ui_scale))


func get_server_browser_prompts() -> Dictionary:
	return ServerBrowserPresenter.new().get_accessibility_prompts()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"revision": _revision,
		"attached": _attached,
		"status_confirmation": _status_confirmation.duplicate(true),
		"visual": _visual.get_snapshot(),
		"captions": _captions.get_profile_snapshot(),
		"audio": _audio.get_snapshot(),
		"safe_area": SafeAreaContract.get_contract(),
		"server_browser_prompts": get_server_browser_prompts(),
		"presentation_only": true,
		"settings_authority": false,
		"input_authority": false,
		"camera_authority": false,
		"gameplay_authority": false,
		"audio_authority": false,
		"caption_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": bool(_visual.audit().valid) and bool(_captions.audit().valid) and bool(_audio.audit().valid),
		"safe_area_schema_version": SafeAreaContract.CONTRACT_SCHEMA_VERSION,
		"server_browser_prompts_textual": true,
		"status_confirmation_textual": true,
		"status_confirmation_focusable": false,
		"presentation_only": true,
		"settings_authority": false,
		"input_authority": false,
		"camera_authority": false,
		"gameplay_authority": false,
		"audio_authority": false,
		"caption_authority": false,
	}.duplicate(true)


func _reject(reason: StringName, field: StringName = &"") -> Dictionary:
	var result := {
		"accepted": false,
		"reason": reason,
		"revision": _revision,
		"presentation_only": true,
		"settings_authority": false,
		"input_authority": false,
		"camera_authority": false,
		"audio_authority": false,
	}
	if field != &"":
		result["field"] = field
	return result


func _validate_revision(expected_revision: int) -> Dictionary:
	if expected_revision != _revision:
		return _reject(&"stale_revision")
	return {}


func _refresh_attached(expected_revision: int, reason: StringName) -> Dictionary:
	var fenced := _validate_revision(expected_revision)
	if not fenced.is_empty():
		return fenced
	var staged := _build_status_confirmation(_settings.get_accessibility_descriptor())
	if not bool(staged.get("accepted", false)):
		return _reject(StringName(staged.get("reason", &"invalid_accessibility_descriptor")))
	_status_confirmation = (staged.status as Dictionary).duplicate(true)
	_revision += 1
	return _lifecycle_result(reason)


func _build_status_confirmation(descriptor: Dictionary) -> Dictionary:
	for field: StringName in [
		&"captions_enabled", &"reduced_flash", &"reduced_motion", &"ui_scale",
		&"colorblind_palette", &"colorblind_palette_id",
	]:
		if not descriptor.has(field):
			return {"accepted": false, "reason": &"accessibility_field_missing", "field": field}
	if typeof(descriptor.captions_enabled) != TYPE_BOOL:
		return {"accepted": false, "reason": &"invalid_captions_enabled"}
	if typeof(descriptor.reduced_flash) != TYPE_BOOL:
		return {"accepted": false, "reason": &"invalid_reduced_flash"}
	if typeof(descriptor.reduced_motion) != TYPE_BOOL:
		return {"accepted": false, "reason": &"invalid_reduced_motion"}
	if typeof(descriptor.ui_scale) not in [TYPE_FLOAT, TYPE_INT]:
		return {"accepted": false, "reason": &"invalid_ui_scale"}
	var ui_scale := float(descriptor.ui_scale)
	if not is_finite(ui_scale) or ui_scale < RuntimeSettingsType.MIN_UI_SCALE \
			or ui_scale > RuntimeSettingsType.MAX_UI_SCALE:
		return {"accepted": false, "reason": &"invalid_ui_scale"}
	if typeof(descriptor.colorblind_palette) != TYPE_INT \
			or typeof(descriptor.colorblind_palette_id) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {"accepted": false, "reason": &"invalid_colour_alternative"}
	var palette_id := StringName(descriptor.colorblind_palette_id)
	if not PALETTE_VALUES.has(palette_id) \
			or int(PALETTE_VALUES[palette_id]) != int(descriptor.colorblind_palette):
		return {"accepted": false, "reason": &"invalid_colour_alternative"}
	var captions_enabled := bool(descriptor.captions_enabled)
	var reduced_flash := bool(descriptor.reduced_flash)
	var reduced_motion := bool(descriptor.reduced_motion)
	var scale_percent := roundi(ui_scale * 100.0)
	var palette_label := String(PALETTE_LABELS[palette_id])
	var rows: Array[Dictionary] = [
		_status_row(&"captions", "Captions", "ON" if captions_enabled else "OFF"),
		_status_row(&"reduced_flash", "Reduced flash", "ON" if reduced_flash else "OFF"),
		_status_row(&"reduced_motion", "Reduced motion", "ON" if reduced_motion else "OFF"),
		_status_row(&"ui_text_scale", "UI / text scale", "%d%%" % scale_percent),
		_status_row(&"colour_alternative", "Colour alternative", palette_label),
	]
	var active := captions_enabled or reduced_flash or reduced_motion \
			or not is_equal_approx(ui_scale, RuntimeSettingsType.DEFAULT_UI_SCALE) \
			or palette_id != &"none"
	var status_text := "ACCESSIBILITY OPTIONS // %s" % ("ACTIVE" if active else "STANDARD")
	var announcement_parts := PackedStringArray([status_text])
	for row: Dictionary in rows:
		announcement_parts.append(String(row.text))
	return {
		"accepted": true,
		"status": {
			"id": &"active_accessibility_status",
			"title": "Accessibility status",
			"status_text": status_text,
			"announcement_text": " | ".join(announcement_parts),
			"active": active,
			"rows": rows,
			"captions_enabled": captions_enabled,
			"reduced_flash": reduced_flash,
			"reduced_motion": reduced_motion,
			"ui_scale": ui_scale,
			"text_scale": ui_scale,
			"scale_percent": scale_percent,
			"colorblind_palette": int(descriptor.colorblind_palette),
			"colorblind_palette_id": palette_id,
			"colour_alternative_label": palette_label,
			"color_independent": true,
			"uses_text_labels": true,
			"focusable": false,
			"steals_focus": false,
			"safe_area_owned_by_caller": true,
			"presentation_only": true,
			"settings_authority": false,
			"input_authority": false,
			"camera_authority": false,
			"audio_authority": false,
		},
	}


func _status_row(id: StringName, label: String, value_label: String) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"value_label": value_label,
		"text": "%s // %s" % [label.to_upper(), value_label.to_upper()],
		"color_independent": true,
		"focusable": false,
	}


func _on_setting_changed(setting: StringName, _value: Variant) -> void:
	if not _attached or not STATUS_SETTING_FIELDS.has(setting):
		return
	_refresh_attached(_revision, &"settings_changed")


func _disconnect_settings() -> void:
	if is_instance_valid(_settings) and _settings.setting_changed.is_connected(_on_setting_changed):
		_settings.setting_changed.disconnect(_on_setting_changed)


func _lifecycle_result(reason: StringName) -> Dictionary:
	return {
		"accepted": true,
		"reason": reason,
		"revision": _revision,
		"snapshot": get_snapshot(),
		"presentation_only": true,
		"settings_authority": false,
		"input_authority": false,
		"camera_authority": false,
		"audio_authority": false,
	}
