class_name ShipDefinition
extends Resource

## Side-effect-free identity, evidence, handling, entry, and audio contract for
## one class of flyable ship. Per-instance identity and berth assignment belong
## to the ship instance, not this shared Resource.

enum EvidenceStatus {
	AUTHENTICATED = 0,
	PROVISIONAL = 1,
	NEW = 2,
}

const SCHEMA_VERSION := 1
const EVIDENCE_SCOPE: StringName = &"name_to_model"
const EVIDENCE_AUTHENTICATED: StringName = &"authenticated"
const EVIDENCE_PROVISIONAL: StringName = &"provisional"
const EVIDENCE_NEW: StringName = &"new"

@export_category("Identity")
@export var ship_id: StringName = &"unnamed_ship"
@export var display_name := "Unnamed spacecraft"
@export var role_name := "Unspecified"
@export_enum("Authenticated:0", "Provisional:1", "New:2") var evidence_status: int = EvidenceStatus.PROVISIONAL
@export var evidence_references := PackedStringArray()
@export_multiline var evidence_notes := ""
@export var compatibility_tags := PackedStringArray(["small_craft"])

@export_category("Flight profile")
@export_range(10.0, 180.0, 1.0) var maximum_speed := 82.0
@export_range(1.0, 80.0, 1.0) var thrust_acceleration := 34.0
@export_range(1.0, 80.0, 1.0) var brake_acceleration := 48.0
@export_range(0.1, 20.0, 0.1) var passive_drag := 2.8
@export_range(1.0, 30.0, 0.5) var throttle_response := 10.0
@export_range(10.0, 180.0, 1.0) var boost_speed := 118.0
@export_range(1.0, 4.0, 0.05) var boost_multiplier := 1.55
@export_range(10.0, 180.0, 1.0) var yaw_speed_degrees := 72.0
@export_range(10.0, 240.0, 1.0) var roll_speed_degrees := 108.0
@export_range(0.1, 12.0, 0.1) var flight_assist_strength := 5.8
@export_range(0.0, 30.0, 0.5) var visual_bank_degrees := 13.0
@export_range(1.0, 45.0, 1.0) var maximum_mouse_turn_degrees := 18.0

@export_category("Systems profile")
@export_range(0.1, 8.0, 0.1) var engine_start_time := 2.0
@export_range(0.05, 2.0, 0.05) var weapon_cooldown := 0.22
@export_range(1.0, 1000.0, 1.0) var maximum_hull := 100.0
@export_range(1.0, 40.0, 0.5) var landing_maximum_speed := 20.0

@export_category("Entry and audio")
@export var entry_noun := "canopy"
@export var entry_open_verb := "open"
@export var entry_close_verb := "close"
@export var boarding_verb := "board"
@export var audio_profile_id: StringName = &"standard_fighter"


func get_ship_id() -> StringName:
	return ship_id


func get_display_name() -> String:
	return display_name


func get_role() -> String:
	return role_name


func get_evidence_status_id() -> StringName:
	match evidence_status:
		EvidenceStatus.AUTHENTICATED:
			return EVIDENCE_AUTHENTICATED
		EvidenceStatus.PROVISIONAL:
			return EVIDENCE_PROVISIONAL
		EvidenceStatus.NEW:
			return EVIDENCE_NEW
		_:
			return &"invalid"


func is_historical_claim() -> bool:
	return evidence_status in [EvidenceStatus.AUTHENTICATED, EvidenceStatus.PROVISIONAL]


func is_authenticated() -> bool:
	return evidence_status == EvidenceStatus.AUTHENTICATED


func get_flight_profile() -> Dictionary:
	return {
		"maximum_speed": maximum_speed,
		"thrust_acceleration": thrust_acceleration,
		"brake_acceleration": brake_acceleration,
		"passive_drag": passive_drag,
		"throttle_response": throttle_response,
		"boost_speed": boost_speed,
		"boost_multiplier": boost_multiplier,
		"yaw_speed_degrees": yaw_speed_degrees,
		"roll_speed_degrees": roll_speed_degrees,
		"flight_assist_strength": flight_assist_strength,
		"visual_bank_degrees": visual_bank_degrees,
		"maximum_mouse_turn_degrees": maximum_mouse_turn_degrees,
	}


func get_systems_profile() -> Dictionary:
	return {
		"engine_start_time": engine_start_time,
		"weapon_cooldown": weapon_cooldown,
		"maximum_hull": maximum_hull,
		"landing_maximum_speed": landing_maximum_speed,
	}


func get_entry_descriptor() -> Dictionary:
	return {
		"noun": entry_noun,
		"open_verb": entry_open_verb,
		"close_verb": entry_close_verb,
		"boarding_verb": boarding_verb,
	}


func get_compatibility_tags() -> PackedStringArray:
	return compatibility_tags.duplicate()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "ship_id", str(ship_id))
	_validate_ui_copy(errors, "display_name", display_name, 80)
	_validate_ui_copy(errors, "role_name", role_name, 48)
	if evidence_status < EvidenceStatus.AUTHENTICATED or evidence_status > EvidenceStatus.NEW:
		errors.append("evidence_status is outside the supported enum")
	_validate_evidence_references(errors)
	if evidence_status in [EvidenceStatus.AUTHENTICATED, EvidenceStatus.PROVISIONAL] \
		and evidence_references.is_empty():
		errors.append("historical ship claims require at least one evidence reference")

	_validate_range(errors, "maximum_speed", maximum_speed, 10.0, 180.0)
	_validate_range(errors, "thrust_acceleration", thrust_acceleration, 1.0, 80.0)
	_validate_range(errors, "brake_acceleration", brake_acceleration, 1.0, 80.0)
	_validate_range(errors, "passive_drag", passive_drag, 0.1, 20.0)
	_validate_range(errors, "throttle_response", throttle_response, 1.0, 30.0)
	_validate_range(errors, "boost_speed", boost_speed, 10.0, 180.0)
	_validate_range(errors, "boost_multiplier", boost_multiplier, 1.0, 4.0)
	_validate_range(errors, "yaw_speed_degrees", yaw_speed_degrees, 10.0, 180.0)
	_validate_range(errors, "roll_speed_degrees", roll_speed_degrees, 10.0, 240.0)
	_validate_range(errors, "flight_assist_strength", flight_assist_strength, 0.1, 12.0)
	_validate_range(errors, "visual_bank_degrees", visual_bank_degrees, 0.0, 30.0)
	_validate_range(errors, "maximum_mouse_turn_degrees", maximum_mouse_turn_degrees, 1.0, 45.0)
	_validate_range(errors, "engine_start_time", engine_start_time, 0.1, 8.0)
	_validate_range(errors, "weapon_cooldown", weapon_cooldown, 0.05, 2.0)
	_validate_range(errors, "maximum_hull", maximum_hull, 1.0, 1000.0)
	_validate_range(errors, "landing_maximum_speed", landing_maximum_speed, 1.0, 40.0)
	if _is_finite_float(boost_speed) and _is_finite_float(maximum_speed) and boost_speed < maximum_speed:
		errors.append("boost_speed must be greater than or equal to maximum_speed")
	if _is_finite_float(brake_acceleration) and _is_finite_float(passive_drag) \
		and brake_acceleration < passive_drag:
		errors.append("brake_acceleration must be greater than or equal to passive_drag")
	if _is_finite_float(landing_maximum_speed) and _is_finite_float(maximum_speed) \
		and landing_maximum_speed > maximum_speed:
		errors.append("landing_maximum_speed must not exceed maximum_speed")

	_validate_ui_copy(errors, "entry_noun", entry_noun, 32)
	_validate_ui_copy(errors, "entry_open_verb", entry_open_verb, 32)
	_validate_ui_copy(errors, "entry_close_verb", entry_close_verb, 32)
	_validate_ui_copy(errors, "boarding_verb", boarding_verb, 32)
	_validate_stable_id(errors, "audio_profile_id", str(audio_profile_id))
	var seen_tags := PackedStringArray()
	for tag in compatibility_tags:
		_validate_stable_id(errors, "compatibility tag", tag)
		if seen_tags.has(tag):
			errors.append("compatibility tag '%s' is duplicated" % tag)
		else:
			seen_tags.append(tag)
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func audit() -> Dictionary:
	var errors := get_validation_errors()
	var warnings := PackedStringArray()
	if evidence_status == EvidenceStatus.AUTHENTICATED:
		warnings.append("authenticated status depends on manual dossier review and does not grant rights or licensing")
	if evidence_status == EvidenceStatus.NEW and not evidence_references.is_empty():
		warnings.append("references on a new design are inspiration/provenance, not a historical-authentication claim")
	if compatibility_tags.is_empty():
		warnings.append("no compatibility tags are declared; only unrestricted berths can accept this definition")
	if boost_speed == maximum_speed or is_equal_approx(boost_multiplier, 1.0):
		warnings.append("the configured boost profile may have no speed or acceleration benefit")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"ship_id": ship_id,
		"display_name": display_name,
		"role": role_name,
		"role_name": role_name,
		"evidence_status": get_evidence_status_id(),
		"evidence_scope": EVIDENCE_SCOPE,
		"historical_claim": is_historical_claim(),
		"authenticated": is_authenticated(),
		"manual_evidence_review_required": evidence_status == EvidenceStatus.AUTHENTICATED,
		"evidence_references": evidence_references.duplicate(),
		"evidence_notes": evidence_notes,
		"flight_profile": get_flight_profile(),
		"systems_profile": get_systems_profile(),
		"entry": get_entry_descriptor(),
		"audio_profile_id": audio_profile_id,
		"compatibility_tags": get_compatibility_tags(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _validate_evidence_references(errors: PackedStringArray) -> void:
	var seen := PackedStringArray()
	for reference in evidence_references:
		if reference.is_empty() or reference != reference.strip_edges() or _contains_line_break(reference):
			errors.append("evidence references must be non-empty, trimmed, and single-line")
		elif seen.has(reference):
			errors.append("evidence reference '%s' is duplicated" % reference)
		else:
			seen.append(reference)


static func _validate_stable_id(errors: PackedStringArray, field_name: String, value: String) -> void:
	if not _is_stable_id(value):
		errors.append("%s must be a 1-64 character lowercase snake_case identifier" % field_name)


static func _validate_ui_copy(errors: PackedStringArray, field_name: String, value: String, maximum_length: int) -> void:
	if value.is_empty() or value != value.strip_edges() or _contains_line_break(value) or value.length() > maximum_length:
		errors.append("%s must be non-empty, trimmed, single-line, and at most %d characters" % [field_name, maximum_length])


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") or value.ends_with("_") or value.contains("__"):
		return false
	var first_code := value.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower_letter and not is_digit and code != 95:
			return false
	return true


static func _contains_line_break(value: String) -> bool:
	return value.contains("\n") or value.contains("\r")


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _validate_range(errors: PackedStringArray, field_name: String, value: float, minimum: float, maximum: float) -> void:
	if not _is_finite_float(value) or value < minimum or value > maximum:
		errors.append("%s must be finite and in the range %s to %s" % [field_name, minimum, maximum])
