class_name CaptionPresentationEvent
extends RefCounted

## Typed, caller-authored caption payload accepted by CaptionPresentationService.
##
## This object owns no timing loop or presentation authority. The service
## validates it again and copies its scalar fields on enqueue, so later caller
## mutation cannot alter queued state.

enum Category {
	DIALOGUE,
	RADIO,
	SYSTEM,
	AMBIENT,
}

const MAX_ID_LENGTH := 64
const MAX_SPEAKER_LENGTH := 64
const MAX_TEXT_LENGTH := 512
const MIN_DURATION_PHYSICS_SECONDS := 0.1
const MAX_DURATION_PHYSICS_SECONDS := 30.0
const MIN_PRIORITY := 0
const MAX_PRIORITY := 100
const CATEGORY_IDS: Array[StringName] = [
	&"dialogue",
	&"radio",
	&"system",
	&"ambient",
]

var stable_id: StringName
var category: Category
var speaker: String
var text: String
var duration_physics_seconds: float
var priority: int


func _init(
		p_stable_id: StringName = &"",
		p_category: Category = Category.DIALOGUE,
		p_speaker: String = "",
		p_text: String = "",
		p_duration_physics_seconds: float = 1.0,
		p_priority: int = 0
	) -> void:
	stable_id = p_stable_id
	category = p_category
	speaker = p_speaker
	text = p_text
	duration_physics_seconds = p_duration_physics_seconds
	priority = p_priority


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_stable_id(stable_id):
		errors.append("stable_id must be a lowercase stable identifier of 1..%d characters" % MAX_ID_LENGTH)
	if category < Category.DIALOGUE or category > Category.AMBIENT:
		errors.append("category must be one of the frozen typed categories")
	if not _is_bounded_visible_text(speaker, MAX_SPEAKER_LENGTH):
		errors.append("speaker must contain 1..%d characters and no NUL" % MAX_SPEAKER_LENGTH)
	if not _is_bounded_visible_text(text, MAX_TEXT_LENGTH):
		errors.append("text must contain 1..%d characters and no NUL" % MAX_TEXT_LENGTH)
	if (
		not is_finite(duration_physics_seconds)
		or duration_physics_seconds < MIN_DURATION_PHYSICS_SECONDS
		or duration_physics_seconds > MAX_DURATION_PHYSICS_SECONDS
	):
		errors.append(
			"duration_physics_seconds must be finite and within %.1f..%.1f"
			% [MIN_DURATION_PHYSICS_SECONDS, MAX_DURATION_PHYSICS_SECONDS]
		)
	if priority < MIN_PRIORITY or priority > MAX_PRIORITY:
		errors.append("priority must be within %d..%d" % [MIN_PRIORITY, MAX_PRIORITY])
	return errors


func get_category_id() -> StringName:
	if category < Category.DIALOGUE or category > Category.AMBIENT:
		return &"invalid"
	return CATEGORY_IDS[category]


func to_dictionary() -> Dictionary:
	return {
		"stable_id": stable_id,
		"category": category,
		"category_id": get_category_id(),
		"speaker": speaker,
		"text": text,
		"duration_physics_seconds": duration_physics_seconds,
		"priority": priority,
	}.duplicate(true)


static func is_stable_id(value: StringName) -> bool:
	var candidate := str(value)
	if candidate.is_empty() or candidate.length() > MAX_ID_LENGTH:
		return false
	for index in candidate.length():
		var code := candidate.unicode_at(index)
		var lowercase := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lowercase and not digit and code != 95 and code != 45 and code != 46 and code != 58:
			return false
	return true


static func _is_bounded_visible_text(value: String, maximum_length: int) -> bool:
	if value.strip_edges().is_empty() or value.length() > maximum_length:
		return false
	for index in value.length():
		if value.unicode_at(index) == 0:
			return false
	return true
