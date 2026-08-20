class_name AccessibilityVisualPreset
extends RefCounted

## Detached visual accessibility policy for callers that render state cues.
##
## This contract deliberately owns no Control, material, AudioServer, caption
## service, or gameplay state. A caller supplies semantic cue metadata and
## consumes a detached presentation decision. Configuration is all-or-nothing
## so reduced motion/flash cannot be applied without the matching alternatives.

enum ContrastMode {
	STANDARD,
	HIGH,
}

const MIN_CONTRAST_RATIO := 4.5
const MIN_LARGE_CONTRAST_RATIO := 3.0
const MIN_SCALE := 0.75
const MAX_SCALE := 1.6
const CUE_CATEGORIES: Array[StringName] = [
	&"info",
	&"caution",
	&"danger",
	&"objective",
	&"navigation",
]
const SHAPE_CUES: Array[StringName] = [
	&"dot",
	&"triangle",
	&"cross",
	&"diamond",
	&"chevron",
]

var reduced_flash := false
var reduced_motion := false
var colour_safe_cues := false
var contrast_mode: ContrastMode = ContrastMode.STANDARD
var ui_scale := 1.0
var _generation := 0


## Apply a complete or partial detached request atomically. Omitted fields retain
## their current value; malformed fields leave every current value untouched.
func configure(request: Dictionary) -> Dictionary:
	var next_reduced_flash := reduced_flash
	var next_reduced_motion := reduced_motion
	var next_colour_safe := colour_safe_cues
	var next_contrast := contrast_mode
	var next_scale := ui_scale
	if request.has("reduced_flash") and not request.reduced_flash is bool:
		return _reject(&"invalid_reduced_flash")
	if request.has("reduced_motion") and not request.reduced_motion is bool:
		return _reject(&"invalid_reduced_motion")
	if request.has("colour_safe_cues") and not request.colour_safe_cues is bool:
		return _reject(&"invalid_colour_safe_cues")
	if request.has("contrast_mode"):
		if not (request.contrast_mode is int) or int(request.contrast_mode) < ContrastMode.STANDARD or int(request.contrast_mode) > ContrastMode.HIGH:
			return _reject(&"invalid_contrast_mode")
		next_contrast = int(request.contrast_mode) as ContrastMode
	if request.has("ui_scale"):
		if not (request.ui_scale is float or request.ui_scale is int):
			return _reject(&"invalid_ui_scale")
		next_scale = float(request.ui_scale)
		if not is_finite(next_scale) or next_scale < MIN_SCALE or next_scale > MAX_SCALE:
			return _reject(&"invalid_ui_scale")
	next_reduced_flash = bool(request.get("reduced_flash", reduced_flash))
	next_reduced_motion = bool(request.get("reduced_motion", reduced_motion))
	next_colour_safe = bool(request.get("colour_safe_cues", colour_safe_cues))
	reduced_flash = next_reduced_flash
	reduced_motion = next_reduced_motion
	colour_safe_cues = next_colour_safe
	contrast_mode = next_contrast
	ui_scale = next_scale
	_generation += 1
	return {
		"accepted": true,
		"reason": &"applied",
		"generation": _generation,
		"snapshot": get_snapshot(),
	}


## Resolve a single semantic cue into visual and audio/subtitle alternatives.
## `audible` and `captions_enabled` are caller observations, never authority.
func resolve_cue(
	cue_id: StringName,
	category: StringName,
	audible: bool = true,
	captions_enabled: bool = false,
	key_cue: bool = false,
	contrast_ratio: float = 7.0
) -> Dictionary:
	if str(cue_id).is_empty() or not CUE_CATEGORIES.has(category):
		return _reject(&"invalid_cue")
	if not is_finite(contrast_ratio) or contrast_ratio < MIN_LARGE_CONTRAST_RATIO:
		return _reject(&"insufficient_contrast")
	var show_caption := captions_enabled and (key_cue or not audible)
	return {
		"accepted": true,
		"cue_id": cue_id,
		"category": category,
		"audible": audible,
		"show_caption": show_caption,
		"caption_reason": &"audio_fallback" if show_caption and not audible else (&"key_cue" if show_caption else &"not_requested"),
		"shape_cue": SHAPE_CUES[CUE_CATEGORIES.find(category)] if colour_safe_cues else &"none",
		"colour_channel_allowed": not colour_safe_cues,
		"flash_strength": 0.0 if reduced_flash else 1.0,
		"motion_strength": 0.0 if reduced_motion else 1.0,
		"contrast_mode": contrast_mode,
		"contrast_ratio": contrast_ratio,
		"generation": _generation,
		"gameplay_authority": false,
		"audio_authority": false,
		"caption_authority": false,
	}


func get_snapshot() -> Dictionary:
	return {
		"reduced_flash": reduced_flash,
		"reduced_motion": reduced_motion,
		"colour_safe_cues": colour_safe_cues,
		"contrast_mode": contrast_mode,
		"ui_scale": ui_scale,
		"generation": _generation,
		"presentation_only": true,
		"gameplay_authority": false,
		"audio_authority": false,
		"caption_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": MIN_CONTRAST_RATIO == 4.5 and MIN_LARGE_CONTRAST_RATIO == 3.0 and CUE_CATEGORIES.size() == 5,
		"contrast_ratio_minimum": MIN_CONTRAST_RATIO,
		"large_text_contrast_ratio_minimum": MIN_LARGE_CONTRAST_RATIO,
		"shape_cue_count": SHAPE_CUES.size(),
		"presentation_only": true,
		"gameplay_authority": false,
	}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation}
