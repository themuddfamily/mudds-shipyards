class_name CaptionAccessibilityContract
extends RefCounted

## Caller-owned policy adapter for subtitle/caption presentation.
##
## This contract deliberately stops at a detached decision. It does not play
## audio, enqueue captions, mutate settings, or decide whether a cue occurred.
## A HUD may pass the accepted result to CaptionPresentationService and a
## separate audio owner may pass its audibility observation here.

const SCHEMA_VERSION := 1
const CONTRACT_ID: StringName = &"caption-accessibility-contract"
const MAX_TEXT_LENGTH := 512
const MIN_CONTRAST_RATIO := 7.0
const VERBOSITY_VALUES: Array[StringName] = [&"all", &"dialogue_only", &"important_only", &"off"]
const FALLBACK_INAUDIBLE_TEXT := "[inaudible]"
const DEFAULT_PROFILE := {
	"captions_enabled": true,
	"verbosity": &"all",
	"high_contrast": false,
	"reduced_motion": false,
	"reduced_flash": false,
}

var _profile: Dictionary = DEFAULT_PROFILE.duplicate(true)
var _revision := 0


func configure(profile: Dictionary) -> Dictionary:
	var validated := _validate_profile(profile)
	if not bool(validated.accepted):
		return validated
	if _profile == validated.profile:
		return {"accepted": true, "reason": &"unchanged", "revision": _revision}
	_profile = (validated.profile as Dictionary).duplicate(true)
	_revision += 1
	return {"accepted": true, "reason": &"configured", "revision": _revision}


func get_profile_snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "revision": _revision, "profile": _profile.duplicate(true)}


## Resolves one already-observed cue. `audible` is an observation, not a
## playback request. An inaudible cue with no usable text receives a stable
## textual fallback so deaf/hard-of-hearing users are not given an empty row.
func resolve_cue(cue: Dictionary) -> Dictionary:
	var errors := _validate_cue(cue)
	if not errors.is_empty():
		return {"accepted": false, "reason": &"invalid_cue", "errors": errors}
	var category := StringName(cue.get("category", &"system"))
	var priority := int(cue.get("priority", 0))
	var verbosity := StringName(_profile.verbosity)
	if not bool(_profile.captions_enabled) or verbosity == &"off":
		return _rejected(&"captions_disabled", cue)
	if verbosity == &"dialogue_only" and category != &"dialogue":
		return _rejected(&"verbosity_filtered", cue)
	if verbosity == &"important_only" and priority < 50:
		return _rejected(&"verbosity_filtered", cue)
	var text := str(cue.get("text", "")).strip_edges()
	if not bool(cue.get("audible", true)) and text.is_empty():
		text = FALLBACK_INAUDIBLE_TEXT
	return {
		"accepted": true,
		"reason": &"present",
		"stable_id": StringName(cue.stable_id),
		"category": category,
		"speaker": str(cue.get("speaker", "")),
		"text": text,
		"audible_observed": bool(cue.get("audible", true)),
		"inaudible_fallback": not bool(cue.get("audible", true)) and text == FALLBACK_INAUDIBLE_TEXT,
		"priority": priority,
		"visual_policy": get_visual_policy(),
	}.duplicate(true)


func get_visual_policy() -> Dictionary:
	return {
		"contrast_ratio_minimum": MIN_CONTRAST_RATIO,
		"high_contrast": bool(_profile.high_contrast),
		"reduced_motion": bool(_profile.reduced_motion),
		"reduced_flash": bool(_profile.reduced_flash),
		"transition_policy": &"steady_no_motion" if bool(_profile.reduced_motion) else &"consumer_standard",
		"flash_policy": &"steady_no_flash" if bool(_profile.reduced_flash) else &"consumer_standard",
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"valid": _validate_profile(_profile).accepted,
		"profile": _profile.duplicate(true),
		"visual_policy": get_visual_policy(),
		"inaudible_fallback_text": FALLBACK_INAUDIBLE_TEXT,
		"verbosity_values": VERBOSITY_VALUES.duplicate(),
		"presentation_only": true,
		"audio_authority": false,
		"audio_playback": false,
		"caption_queue_authority": false,
		"settings_authority": false,
		"gameplay_authority": false,
	}.duplicate(true)


func _validate_profile(profile: Dictionary) -> Dictionary:
	var candidate := DEFAULT_PROFILE.duplicate(true)
	for key in profile:
		if not candidate.has(key):
			return {"accepted": false, "reason": &"unknown_profile_field", "field": key}
		candidate[key] = profile[key]
	if typeof(candidate.captions_enabled) != TYPE_BOOL or typeof(candidate.high_contrast) != TYPE_BOOL \
		or typeof(candidate.reduced_motion) != TYPE_BOOL or typeof(candidate.reduced_flash) != TYPE_BOOL:
		return {"accepted": false, "reason": &"invalid_profile_flags"}
	if not VERBOSITY_VALUES.has(StringName(candidate.verbosity)) or typeof(candidate.verbosity) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {"accepted": false, "reason": &"invalid_verbosity"}
	candidate.verbosity = StringName(candidate.verbosity)
	return {"accepted": true, "reason": &"valid", "profile": candidate}


func _validate_cue(cue: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var stable_id := StringName(cue.get("stable_id", &""))
	if stable_id == &"" or str(stable_id).length() > 64:
		errors.append("stable_id must be present and bounded")
	var category := StringName(cue.get("category", &""))
	if not [&"dialogue", &"radio", &"system", &"ambient"].has(category):
		errors.append("category is not an authored caption category")
	if typeof(cue.get("audible", true)) != TYPE_BOOL:
		errors.append("audible must be a boolean observation")
	var text := str(cue.get("text", ""))
	if text.length() > MAX_TEXT_LENGTH:
		errors.append("text exceeds the bounded caption length")
	var priority := int(cue.get("priority", 0))
	if priority < 0 or priority > 100:
		errors.append("priority must be within 0..100")
	return errors


func _rejected(reason: StringName, cue: Dictionary) -> Dictionary:
	return {"accepted": false, "reason": reason, "stable_id": StringName(cue.stable_id)}
