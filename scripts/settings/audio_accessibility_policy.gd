class_name AudioAccessibilityPolicy
extends RefCounted

## Presentation-only policy for making important audio cues perceivable when
## the mix is muted, inaccessible, or intentionally reduced.  It does not
## play audio, emit captions, mutate HUD state, or own gameplay authority;
## callers consume the detached decision returned by [method resolve_cue].

enum Mode {
	OFF,
	CAPTIONS,
	CAPTIONS_AND_VISUAL,
}

const MIN_CUE_ID_LENGTH := 1
const MAX_CUE_ID_LENGTH := 64
const CUE_CATEGORIES: Array[StringName] = [
	&"ui",
	&"combat",
	&"warning",
	&"vehicle",
	&"world",
]

var mode: Mode = Mode.OFF
var _generation := 0


func configure(requested_mode: int) -> Dictionary:
	if requested_mode < Mode.OFF or requested_mode > Mode.CAPTIONS_AND_VISUAL:
		return {"accepted": false, "reason": &"invalid_mode", "generation": _generation}
	mode = requested_mode as Mode
	_generation += 1
	return {"accepted": true, "reason": &"applied", "generation": _generation}


## Resolve one bounded cue into detached presentation intents. `audible` is a
## caller-owned observation of the mixer and is never used to grant authority.
func resolve_cue(cue_id: StringName, category: StringName, audible: bool = true) -> Dictionary:
	if not _is_valid_cue_id(cue_id):
		return {"accepted": false, "reason": &"invalid_cue_id", "generation": _generation}
	if not CUE_CATEGORIES.has(category):
		return {"accepted": false, "reason": &"invalid_category", "generation": _generation}
	var show_caption := mode >= Mode.CAPTIONS
	var show_visual := mode == Mode.CAPTIONS_AND_VISUAL and category in [&"combat", &"warning"]
	return {
		"accepted": true,
		"cue_id": cue_id,
		"category": category,
		"audible": audible,
		"show_caption": show_caption,
		"show_visual": show_visual,
		"generation": _generation,
		"gameplay_authority": false,
	}


func get_snapshot() -> Dictionary:
	return {
		"mode": mode,
		"generation": _generation,
		"categories": CUE_CATEGORIES.duplicate(),
		"gameplay_authority": false,
		"audio_authority": false,
	}


func audit() -> Dictionary:
	return {
		"valid": mode >= Mode.OFF and mode <= Mode.CAPTIONS_AND_VISUAL,
		"cue_id_limits": {"minimum": MIN_CUE_ID_LENGTH, "maximum": MAX_CUE_ID_LENGTH},
		"category_count": CUE_CATEGORIES.size(),
		"presentation_only": true,
	}


static func _is_valid_cue_id(value: StringName) -> bool:
	var candidate := str(value)
	if candidate.length() < MIN_CUE_ID_LENGTH or candidate.length() > MAX_CUE_ID_LENGTH:
		return false
	for index in candidate.length():
		var code := candidate.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code in [95, 45, 46, 58]):
			return false
	return true
