class_name CombatBreadthProfile
extends RefCounted

## Detached, data-only loadout contract for one varied combat participant.
##
## This is the seam between authored weapon/tactic variety and the existing
## resolver-backed opponents. It deliberately does not register a source,
## perform a ray query, apply damage, advance a clock, or choose a scene. A
## caller supplies the current observation and owns all resulting movement,
## firing, presentation, and lifecycle work.
##
## The weapon values are a compact authoring snapshot rather than a second
## WeaponDefinition. Production conversion remains the responsibility of the
## existing WeaponDefinitionResolverProfile and LiveCombatAuthority seams.
## Evidence status: modern_interpretation; no original weapon or doctrine is
## authenticated by this contract.

const TacticContract := preload("res://scripts/combat/opponent_tactic_contract.gd")

const SCHEMA_VERSION := 1
const MAX_ID_LENGTH := 64
const MAX_RANGE_METERS := 100_000.0
const MAX_DAMAGE_PER_SHOT := 1_000_000.0
const MAX_CADENCE := 1_000.0
const MAX_SPREAD_DEGREES := 45.0

const ROLE_REPEATER: StringName = &"repeater"
const ROLE_LANCE: StringName = &"lance"
const ROLE_SCATTER: StringName = &"scatter"
const ROLE_IDS: Array[StringName] = [ROLE_REPEATER, ROLE_LANCE, ROLE_SCATTER]

var _profile_id: StringName
var _opponent_id: StringName
var _weapon: Dictionary = {}
var _tactic: RefCounted
var _configuration_errors := PackedStringArray()


func _init(
		p_profile_id: StringName,
		p_opponent_id: StringName,
		p_weapon_profile: Dictionary,
		p_strategy: StringName,
		p_tactics_profile: Dictionary
	) -> void:
	_profile_id = p_profile_id
	_opponent_id = p_opponent_id
	_weapon = _capture_weapon(p_weapon_profile)
	_tactic = TacticContract.new(
		p_profile_id,
		p_strategy,
		StringName(_weapon.weapon_id),
		{
			"range": _weapon.range,
			"damage": _weapon.damage_per_shot,
			"origin_tolerance": _weapon.origin_tolerance,
		},
		p_tactics_profile
	)
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty() and _tactic.is_configuration_valid()


func get_configuration_errors() -> PackedStringArray:
	var errors := _configuration_errors.duplicate()
	for error in _tactic.get_configuration_errors():
		errors.append("tactic: %s" % error)
	return errors


func get_profile_id() -> StringName:
	return _profile_id


func get_opponent_id() -> StringName:
	return _opponent_id


func get_weapon_profile() -> Dictionary:
	return _weapon.duplicate(true)


func get_tactic_profile() -> Dictionary:
	return _tactic.get_tactics_profile()


## Evaluates one caller-owned observation through the shared tactic contract,
## then attaches the immutable weapon envelope needed by a dispatch seam.
func evaluate(
		distance: float,
		aim_cosine: float,
		hull_ratio: float,
		role_ready: bool = true
	) -> Dictionary:
	var result: Dictionary = _tactic.evaluate(
		distance, aim_cosine, hull_ratio, role_ready
	)
	result["profile_id"] = _profile_id
	result["opponent_id"] = _opponent_id
	result["weapon_role"] = _weapon.weapon_role
	result["damage_per_shot"] = _weapon.damage_per_shot
	result["cadence_shots_per_second"] = _weapon.cadence_shots_per_second
	result["spread_degrees"] = _weapon.spread_degrees
	return result.duplicate(true)


## Returns only detached values. The authority booleans make the ownership
## boundary reviewable by a focused test and by tooling without inspecting code.
func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": _profile_id,
		"opponent_id": _opponent_id,
		"weapon": get_weapon_profile(),
		"tactics": get_tactic_profile(),
		"configuration_errors": get_configuration_errors(),
		"evidence": {
			"status": &"modern_interpretation",
			"authenticated_original_weapon": false,
			"authenticated_original_tactic": false,
		},
		"authority": {
			"combat_resolution": false,
			"damage": false,
			"movement": false,
			"presentation": false,
			"lifecycle": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": is_configuration_valid(),
		"errors": get_configuration_errors(),
		"profile": get_snapshot(),
	}.duplicate(true)


## Canonical examples provide measurable lateral variety for designers and
## tests. They are detached profiles, not registered production opponents.
static func build_examples() -> Array:
	return [
		new(
			&"press_repeater",
			&"interceptor_press",
			{
				"weapon_id": &"repeater",
				"weapon_role": ROLE_REPEATER,
				"range": 260.0,
				"damage_per_shot": 9.0,
				"cadence_shots_per_second": 5.5,
				"spread_degrees": 0.8,
				"origin_tolerance": 22.0,
			},
			TacticContract.STRATEGY_PRESS,
			{
				"engagement_range": 220.0,
				"preferred_engagement_distance": 70.0,
				"minimum_arming_range": 20.0,
				"aim_cosine": 0.91,
				"retreat_health_ratio": 0.18,
				"telegraph_time": 0.16,
				"weapon_cooldown": 0.18,
			}
		),
		new(
			&"standoff_lance",
			&"picket_standoff",
			{
				"weapon_id": &"lance",
				"weapon_role": ROLE_LANCE,
				"range": 500.0,
				"damage_per_shot": 30.0,
				"cadence_shots_per_second": 1.3,
				"spread_degrees": 0.0,
				"origin_tolerance": 30.0,
			},
			TacticContract.STRATEGY_STANDOFF,
			{
				"engagement_range": 450.0,
				"preferred_engagement_distance": 300.0,
				"minimum_arming_range": 90.0,
				"aim_cosine": 0.97,
				"retreat_health_ratio": 0.3,
				"telegraph_time": 0.75,
				"weapon_cooldown": 0.77,
			}
		),
		new(
			&"flank_scatter",
			&"skirmisher_flank",
			{
				"weapon_id": &"scatter",
				"weapon_role": ROLE_SCATTER,
				"range": 180.0,
				"damage_per_shot": 14.0,
				"cadence_shots_per_second": 2.5,
				"spread_degrees": 5.0,
				"origin_tolerance": 20.0,
			},
			TacticContract.STRATEGY_FLANK,
			{
				"engagement_range": 160.0,
				"preferred_engagement_distance": 55.0,
				"minimum_arming_range": 12.0,
				"aim_cosine": 0.78,
				"retreat_health_ratio": 0.25,
				"telegraph_time": 0.3,
				"weapon_cooldown": 0.4,
			}
		),
	]


func _capture_weapon(profile: Dictionary) -> Dictionary:
	return {
		"weapon_id": StringName(profile.get("weapon_id", &"")),
		"weapon_role": StringName(profile.get("weapon_role", &"")),
		"range": _number(profile.get("range", NAN)),
		"damage_per_shot": _number(profile.get("damage_per_shot", NAN)),
		"cadence_shots_per_second": _number(profile.get("cadence_shots_per_second", NAN)),
		"spread_degrees": _number(profile.get("spread_degrees", NAN)),
		"origin_tolerance": _number(profile.get("origin_tolerance", NAN)),
	}.duplicate(true)


func _validate_configuration() -> void:
	_validate_id(_configuration_errors, "profile_id", _profile_id)
	_validate_id(_configuration_errors, "opponent_id", _opponent_id)
	if not TacticContract.is_stable_id(_weapon.weapon_id):
		_configuration_errors.append("weapon_id must be a stable identifier")
	if not ROLE_IDS.has(_weapon.weapon_role):
		_configuration_errors.append("weapon_role must be one of the frozen role IDs")
	_validate_number(_configuration_errors, "range", _weapon.range, 0.001, MAX_RANGE_METERS)
	_validate_number(_configuration_errors, "damage_per_shot", _weapon.damage_per_shot, 0.001, MAX_DAMAGE_PER_SHOT)
	_validate_number(_configuration_errors, "cadence_shots_per_second", _weapon.cadence_shots_per_second, 0.001, MAX_CADENCE)
	_validate_number(_configuration_errors, "spread_degrees", _weapon.spread_degrees, 0.0, MAX_SPREAD_DEGREES)
	_validate_number(_configuration_errors, "origin_tolerance", _weapon.origin_tolerance, 0.001, MAX_RANGE_METERS)


static func _validate_id(errors: PackedStringArray, label: String, value: StringName) -> void:
	if not TacticContract.is_stable_id(value) or str(value).length() > MAX_ID_LENGTH:
		errors.append("%s must be a stable identifier" % label)


static func _validate_number(
		errors: PackedStringArray,
		label: String,
		value: float,
		minimum: float,
		maximum: float
	) -> void:
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append("%s is outside its finite bound" % label)


static func _number(value: Variant) -> float:
	return float(value) if value is int or value is float else NAN
