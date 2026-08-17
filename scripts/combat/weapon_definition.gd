class_name WeaponDefinition
extends Resource

## Strict, side-effect-free data contract for one weapon configuration.
##
## This Resource describes authoring data only. Combat resolution, faction
## identity, damage, presentation, audio, persistence, and synchronization stay
## with their existing runtime authorities.

enum ResolutionMode {
	HITSCAN = 0,
	PROJECTILE = 1,
	BEAM = 2,
}

enum FactionPolicy {
	INHERIT_SOURCE = 0,
	FIXED_FACTION = 1,
}

enum FriendlyFirePolicy {
	DENY = 0,
	ALLOW = 1,
}

enum EvidenceStatus {
	AUTHENTICATED = 0,
	PROVISIONAL = 1,
	NEW = 2,
}

const SCHEMA_VERSION := 1
const UNIT_SYSTEM: StringName = &"game_scale_si"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_SCOPE: StringName = &"weapon_definition_parameters"
const MAX_EVIDENCE_REFERENCES := 32
const MAX_EVIDENCE_REFERENCE_LENGTH := 192

const MAX_RANGE_METERS := 100_000.0
const MAX_DAMAGE_PER_HIT := 1_000_000.0
const MAX_CADENCE_SHOTS_PER_SECOND := 1_000.0
const MAX_SPREAD_DEGREES := 45.0
const MAX_HEAT_UNITS := 1_000_000.0
const MAX_HEAT_UNITS_PER_SECOND := 1_000_000.0
const MAX_AMMUNITION := 1_000_000

const RESOLUTION_HITSCAN: StringName = &"hitscan"
const RESOLUTION_PROJECTILE: StringName = &"projectile"
const RESOLUTION_BEAM: StringName = &"beam"
const FACTION_INHERIT_SOURCE: StringName = &"inherit_source"
const FACTION_FIXED: StringName = &"fixed_faction"
const FRIENDLY_FIRE_DENY: StringName = &"deny"
const FRIENDLY_FIRE_ALLOW: StringName = &"allow"
const EVIDENCE_AUTHENTICATED: StringName = &"authenticated"
const EVIDENCE_PROVISIONAL: StringName = &"provisional"
const EVIDENCE_NEW: StringName = &"new"

@export_category("Identity and evidence")
@export var weapon_id: StringName = &"unnamed_weapon"
@export var display_name := "Unnamed weapon"
@export_enum("Hitscan:0", "Projectile:1", "Beam:2") var resolution_mode: int = ResolutionMode.HITSCAN
@export_enum("Authenticated:0", "Provisional:1", "New:2") var evidence_status: int = EvidenceStatus.NEW
@export var evidence_references := PackedStringArray()
@export_multiline var evidence_notes := "New gameplay tuning; not a recovered historical weapon specification."

@export_category("Resolution envelope")
@export_range(0.001, MAX_RANGE_METERS, 0.001) var range_meters := 360.0
@export_range(0.001, MAX_DAMAGE_PER_HIT, 0.001) var damage_per_hit := 34.0
@export_range(0.001, MAX_CADENCE_SHOTS_PER_SECOND, 0.001) var cadence_shots_per_second := 4.0

@export_category("Faction policy")
@export_enum("Inherit source:0", "Fixed faction:1") var faction_policy: int = FactionPolicy.INHERIT_SOURCE
@export var fixed_faction_id: StringName = &""
@export_enum("Deny:0", "Allow:1") var friendly_fire_policy: int = FriendlyFirePolicy.DENY

@export_category("Optional spread")
@export var spread_enabled := false
@export_range(0.0, MAX_SPREAD_DEGREES, 0.001) var spread_degrees := 0.0

@export_category("Optional heat")
@export var heat_enabled := false
@export_range(0.0, MAX_HEAT_UNITS, 0.001) var heat_per_shot := 0.0
@export_range(0.0, MAX_HEAT_UNITS, 0.001) var heat_capacity := 0.0
@export_range(0.0, MAX_HEAT_UNITS_PER_SECOND, 0.001) var heat_cooldown_per_second := 0.0

@export_category("Optional ammunition")
@export var ammunition_enabled := false
@export_range(0, MAX_AMMUNITION, 1) var magazine_capacity := 0
@export_range(0, MAX_AMMUNITION, 1) var reserve_ammunition := 0
@export_range(0, MAX_AMMUNITION, 1) var ammunition_per_shot := 0

@export_category("Presentation and audio hints")
@export var presentation_id: StringName = &"standard_pulse"
@export var fire_audio_id: StringName = &"standard_pulse_fire"
@export var impact_audio_id: StringName = &"standard_pulse_impact"
@export var dry_fire_audio_id: StringName = &"standard_weapon_dry_fire"


func get_resolution_mode_id() -> StringName:
	match resolution_mode:
		ResolutionMode.HITSCAN:
			return RESOLUTION_HITSCAN
		ResolutionMode.PROJECTILE:
			return RESOLUTION_PROJECTILE
		ResolutionMode.BEAM:
			return RESOLUTION_BEAM
		_:
			return &"invalid"


func get_faction_policy_id() -> StringName:
	match faction_policy:
		FactionPolicy.INHERIT_SOURCE:
			return FACTION_INHERIT_SOURCE
		FactionPolicy.FIXED_FACTION:
			return FACTION_FIXED
		_:
			return &"invalid"


func get_friendly_fire_policy_id() -> StringName:
	match friendly_fire_policy:
		FriendlyFirePolicy.DENY:
			return FRIENDLY_FIRE_DENY
		FriendlyFirePolicy.ALLOW:
			return FRIENDLY_FIRE_ALLOW
		_:
			return &"invalid"


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


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "weapon_id", str(weapon_id))
	_validate_ui_copy(errors, "display_name", display_name, 96)
	if resolution_mode < ResolutionMode.HITSCAN or resolution_mode > ResolutionMode.BEAM:
		errors.append("resolution_mode is outside the supported enum")
	if evidence_status < EvidenceStatus.AUTHENTICATED or evidence_status > EvidenceStatus.NEW:
		errors.append("evidence_status is outside the supported enum")
	_validate_evidence_references(errors)
	if evidence_status in [EvidenceStatus.AUTHENTICATED, EvidenceStatus.PROVISIONAL] \
			and evidence_references.is_empty():
		errors.append("historical weapon claims require at least one evidence reference")
	if evidence_notes.is_empty() or evidence_notes != evidence_notes.strip_edges():
		errors.append("evidence_notes must be non-empty and trimmed")

	_validate_range(errors, "range_meters", range_meters, 0.001, MAX_RANGE_METERS)
	_validate_range(errors, "damage_per_hit", damage_per_hit, 0.001, MAX_DAMAGE_PER_HIT)
	_validate_range(
		errors,
		"cadence_shots_per_second",
		cadence_shots_per_second,
		0.001,
		MAX_CADENCE_SHOTS_PER_SECOND
	)

	if faction_policy < FactionPolicy.INHERIT_SOURCE or faction_policy > FactionPolicy.FIXED_FACTION:
		errors.append("faction_policy is outside the supported enum")
	elif faction_policy == FactionPolicy.INHERIT_SOURCE:
		if not fixed_faction_id.is_empty():
			errors.append("fixed_faction_id must be empty when faction_policy inherits the source")
	else:
		_validate_stable_id(errors, "fixed_faction_id", str(fixed_faction_id))
	if friendly_fire_policy < FriendlyFirePolicy.DENY \
			or friendly_fire_policy > FriendlyFirePolicy.ALLOW:
		errors.append("friendly_fire_policy is outside the supported enum")

	_validate_range(errors, "spread_degrees", spread_degrees, 0.0, MAX_SPREAD_DEGREES)
	if spread_enabled:
		if _is_finite_float(spread_degrees) and spread_degrees <= 0.0:
			errors.append("spread_degrees must be positive when spread is enabled")
	elif _is_finite_float(spread_degrees) and spread_degrees != 0.0:
		errors.append("spread_degrees must be exactly zero when spread is disabled")

	_validate_range(errors, "heat_per_shot", heat_per_shot, 0.0, MAX_HEAT_UNITS)
	_validate_range(errors, "heat_capacity", heat_capacity, 0.0, MAX_HEAT_UNITS)
	_validate_range(
		errors,
		"heat_cooldown_per_second",
		heat_cooldown_per_second,
		0.0,
		MAX_HEAT_UNITS_PER_SECOND
	)
	if heat_enabled:
		if _is_finite_float(heat_per_shot) and heat_per_shot <= 0.0:
			errors.append("heat_per_shot must be positive when heat is enabled")
		if _is_finite_float(heat_capacity) and heat_capacity <= 0.0:
			errors.append("heat_capacity must be positive when heat is enabled")
		if _is_finite_float(heat_cooldown_per_second) and heat_cooldown_per_second <= 0.0:
			errors.append("heat_cooldown_per_second must be positive when heat is enabled")
		if _is_finite_float(heat_per_shot) and _is_finite_float(heat_capacity) \
				and heat_per_shot > heat_capacity:
			errors.append("heat_per_shot must not exceed heat_capacity")
	elif heat_per_shot != 0.0 or heat_capacity != 0.0 or heat_cooldown_per_second != 0.0:
		errors.append("heat fields must be exactly zero when heat is disabled")

	_validate_integer_range(errors, "magazine_capacity", magazine_capacity, 0, MAX_AMMUNITION)
	_validate_integer_range(errors, "reserve_ammunition", reserve_ammunition, 0, MAX_AMMUNITION)
	_validate_integer_range(errors, "ammunition_per_shot", ammunition_per_shot, 0, MAX_AMMUNITION)
	if ammunition_enabled:
		if magazine_capacity <= 0:
			errors.append("magazine_capacity must be positive when ammunition is enabled")
		if ammunition_per_shot <= 0:
			errors.append("ammunition_per_shot must be positive when ammunition is enabled")
		if ammunition_per_shot > magazine_capacity:
			errors.append("ammunition_per_shot must not exceed magazine_capacity")
	elif magazine_capacity != 0 or reserve_ammunition != 0 or ammunition_per_shot != 0:
		errors.append("ammunition fields must be exactly zero when ammunition is disabled")

	_validate_stable_id(errors, "presentation_id", str(presentation_id))
	_validate_stable_id(errors, "fire_audio_id", str(fire_audio_id))
	_validate_stable_id(errors, "impact_audio_id", str(impact_audio_id))
	_validate_stable_id(errors, "dry_fire_audio_id", str(dry_fire_audio_id))
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_resolution_snapshot() -> Dictionary:
	return {
		"mode": get_resolution_mode_id(),
		"range_meters": range_meters,
		"damage_per_hit": damage_per_hit,
		"cadence_shots_per_second": cadence_shots_per_second,
	}.duplicate(true)


func get_policy_snapshot() -> Dictionary:
	return {
		"faction_policy": get_faction_policy_id(),
		"fixed_faction_id": fixed_faction_id,
		"friendly_fire_policy": get_friendly_fire_policy_id(),
	}.duplicate(true)


func get_optional_systems_snapshot() -> Dictionary:
	return {
		"spread": {
			"enabled": spread_enabled,
			"degrees": spread_degrees,
		},
		"heat": {
			"enabled": heat_enabled,
			"per_shot": heat_per_shot,
			"capacity": heat_capacity,
			"cooldown_per_second": heat_cooldown_per_second,
		},
		"ammunition": {
			"enabled": ammunition_enabled,
			"magazine_capacity": magazine_capacity,
			"reserve": reserve_ammunition,
			"per_shot": ammunition_per_shot,
		},
	}.duplicate(true)


func get_presentation_snapshot() -> Dictionary:
	return {
		"presentation_id": presentation_id,
		"fire_audio_id": fire_audio_id,
		"impact_audio_id": impact_audio_id,
		"dry_fire_audio_id": dry_fire_audio_id,
	}.duplicate(true)


## The exact common authority core. Every key is intentionally false: this
## Resource is descriptive data and cannot perform or own runtime work.
func get_authority_report() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"save": false,
		"network": false,
		"physics": false,
		"world_generation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"origin_shift": false,
		"weather_clock": false,
		"audio": false,
	}.duplicate(true)


func get_definition_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": UNIT_SYSTEM,
		"weapon_id": weapon_id,
		"display_name": display_name,
		"resolution": get_resolution_snapshot(),
		"policy": get_policy_snapshot(),
		"optional_systems": get_optional_systems_snapshot(),
		"presentation": get_presentation_snapshot(),
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": get_evidence_status_id(),
			"scope": EVIDENCE_SCOPE,
			"references": evidence_references.duplicate(),
			"notes": evidence_notes,
		},
		"authority": get_authority_report(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"definition": get_definition_snapshot(),
		"authority": get_authority_report(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _validate_evidence_references(errors: PackedStringArray) -> void:
	if evidence_references.size() > MAX_EVIDENCE_REFERENCES:
		errors.append("evidence references must contain at most %d entries" % MAX_EVIDENCE_REFERENCES)
	var seen := PackedStringArray()
	for reference in evidence_references:
		if reference.is_empty() or reference != reference.strip_edges() \
				or reference.contains("\n") or reference.contains("\r") \
				or reference.length() > MAX_EVIDENCE_REFERENCE_LENGTH:
			errors.append(
				"evidence references must be non-empty, trimmed, single-line, and at most %d characters"
				% MAX_EVIDENCE_REFERENCE_LENGTH
			)
		elif seen.has(reference):
			errors.append("evidence reference '%s' is duplicated" % reference)
		else:
			seen.append(reference)


static func _validate_stable_id(errors: PackedStringArray, field_name: String, value: String) -> void:
	if not _is_stable_id(value):
		errors.append("%s must be a 1-64 character lowercase snake_case identifier" % field_name)


static func _validate_ui_copy(errors: PackedStringArray, field_name: String, value: String, maximum_length: int) -> void:
	if value.is_empty() or value != value.strip_edges() or value.contains("\n") \
			or value.contains("\r") or value.length() > maximum_length:
		errors.append(
			"%s must be non-empty, trimmed, single-line, and at most %d characters"
			% [field_name, maximum_length]
		)


static func _validate_range(
	errors: PackedStringArray,
	field_name: String,
	value: float,
	minimum: float,
	maximum: float
	) -> void:
	if not _is_finite_float(value) or value < minimum or value > maximum:
		errors.append("%s must be finite and between %s and %s" % [field_name, minimum, maximum])


static func _validate_integer_range(
	errors: PackedStringArray,
	field_name: String,
	value: int,
	minimum: int,
	maximum: int
	) -> void:
	if value < minimum or value > maximum:
		errors.append("%s must be between %d and %d" % [field_name, minimum, maximum])


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") \
			or value.ends_with("_") or value.contains("__"):
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
