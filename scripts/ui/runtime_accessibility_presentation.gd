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

const VISUAL_FIELDS: Array[StringName] = [&"visual", &"captions", &"audio"]
const VISUAL_CATEGORIES: Array[StringName] = [
	&"info", &"caution", &"danger", &"objective", &"navigation",
]
const CAPTION_CATEGORIES: Array[StringName] = [&"dialogue", &"radio", &"system", &"ambient"]

var _visual: RefCounted = VisualPreset.new()
var _captions: RefCounted = CaptionContract.new()
var _audio: RefCounted = AudioPreset.new()
var _revision := 0


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
		"visual": _visual.get_snapshot(),
		"captions": _captions.get_profile_snapshot(),
		"audio": _audio.get_snapshot(),
		"safe_area": SafeAreaContract.get_contract(),
		"server_browser_prompts": get_server_browser_prompts(),
		"presentation_only": true,
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
		"presentation_only": true,
		"gameplay_authority": false,
		"audio_authority": false,
		"caption_authority": false,
	}.duplicate(true)


func _reject(reason: StringName, field: StringName = &"") -> Dictionary:
	var result := {"accepted": false, "reason": reason, "revision": _revision}
	if field != &"":
		result["field"] = field
	return result
