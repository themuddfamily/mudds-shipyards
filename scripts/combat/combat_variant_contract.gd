class_name CombatVariantContract
extends RefCounted

## Detached authoring contract for the first varied combat slice.
##
## A variant binds one weapon envelope to one opponent identity, tactic and
## objective.  It deliberately evaluates observations only: the production
## LiveCombatAuthority, CombatResolver and damage adapter remain the sole
## owners of shot validation, resolution and damage.  This keeps the breadth
## work useful to encounter composition without introducing a second hit or
## health path.
##
## Evidence status: modern_interpretation.  The weapon names, opponents,
## tactics and recovery values are new gameplay design, not recovered source
## material.

const Profile := preload("res://scripts/combat/combat_breadth_profile.gd")
const Tactic := preload("res://scripts/combat/opponent_tactic_contract.gd")

const SCHEMA_VERSION := 1
const MAX_VARIANTS := 8
const MAX_ID_LENGTH := 64
const MAX_ARCADE_RECOVERY_SECONDS := 3.0
const MAX_INVULNERABILITY_SECONDS := 1.0
const MAX_RESUME_SECONDS := 5.0

const OBJECTIVE_INTERCEPT: StringName = &"intercept_runner"
const OBJECTIVE_BREAK_WING: StringName = &"break_wing"
const OBJECTIVE_PROTECT_ASSET: StringName = &"protect_asset"
const OBJECTIVE_IDS: Array[StringName] = [
	OBJECTIVE_INTERCEPT,
	OBJECTIVE_BREAK_WING,
	OBJECTIVE_PROTECT_ASSET,
]

var _variants: Array = []
var _profiles: Dictionary = {}
var _configuration_errors := PackedStringArray()


func _init(definitions: Array = []) -> void:
	var source := definitions if not definitions.is_empty() else build_examples()
	for definition in source:
		if not definition is Dictionary:
			_configuration_errors.append("variant definitions must be dictionaries")
			continue
		var variant := _capture_variant(definition)
		_variants.append(variant)
		var profile := Profile.new(
			variant.profile_id,
			variant.opponent_id,
			variant.weapon,
			variant.strategy,
			variant.tactics
		)
		_profiles[variant.profile_id] = profile
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func get_variant_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for variant in _variants:
		ids.append(variant.variant_id)
	return ids


func get_variant(variant_id: StringName) -> Dictionary:
	for variant in _variants:
		if variant.variant_id == variant_id:
			return variant.duplicate(true)
	return {}


func get_profile(variant_id: StringName) -> Profile:
	var variant := get_variant(variant_id)
	if variant.is_empty():
		return null
	return _profiles.get(variant.profile_id) as Profile


## Evaluates a caller-owned observation.  The result is dispatch metadata only;
## it is not a ShotRequest and it never resolves, damages or advances a clock.
func evaluate(
	variant_id: StringName,
	distance: float,
	aim_cosine: float,
	hull_ratio: float,
	role_ready: bool = true
) -> Dictionary:
	var variant := get_variant(variant_id)
	var result := {
		"accepted": false,
		"reason": &"unknown_variant",
		"variant_id": variant_id,
	}
	if variant.is_empty():
		return result
	var profile := _profiles.get(variant.profile_id) as Profile
	if profile == null:
		result.reason = &"invalid_profile"
		return result
	var evaluated := profile.evaluate(distance, aim_cosine, hull_ratio, role_ready)
	evaluated["variant_id"] = variant.variant_id
	evaluated["opponent_id"] = variant.opponent_id
	evaluated["objective"] = variant.objective
	evaluated["scenario_id"] = variant.scenario_id
	evaluated["recovery"] = variant.recovery.duplicate(true)
	return evaluated.duplicate(true)


func get_recovery_budget(variant_id: StringName) -> Dictionary:
	var variant := get_variant(variant_id)
	if variant.is_empty():
		return {}
	return variant.recovery.duplicate(true)


func is_low_friction_recovery(variant_id: StringName) -> bool:
	var recovery := get_recovery_budget(variant_id)
	if recovery.is_empty():
		return false
	return bool(recovery.low_friction)


func get_snapshot() -> Dictionary:
	var variants: Array = []
	for variant in _variants:
		variants.append(variant.duplicate(true))
	return {
		"schema_version": SCHEMA_VERSION,
		"variants": variants,
		"configuration_errors": get_configuration_errors(),
		"evidence": {
			"status": &"modern_interpretation",
			"authenticated_original_weapon": false,
			"authenticated_original_opponent": false,
			"authenticated_original_tactic": false,
		},
		"authority": {
			"combat_resolution": false,
			"damage": false,
			"damage_commit": false,
			"presentation": false,
			"recovery": false,
		},
		"authority_chain": {
			"shot_validation_owner": &"live_combat_authority",
			"resolution_owner": &"combat_resolver",
			"damage_commit_owner": &"damage_adapter",
			"receipt_deduplication": &"monotonic_sequence",
			"damage_commit_owner_count": 1,
			"duplicate_damage_authority": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": is_configuration_valid(),
		"errors": get_configuration_errors(),
		"contract": get_snapshot(),
	}.duplicate(true)


## Four bounded combinations give the encounter director distinct weapon,
## opponent and tactical reads without expanding the production resolver API.
static func build_examples() -> Array:
	return [
		_variant(
			&"courier_repeater",
			&"courier_runner",
			&"courier_intercept",
			OBJECTIVE_INTERCEPT,
			&"repeater",
			Profile.ROLE_REPEATER,
			Tactic.STRATEGY_RUNNER,
			{
				"range": 260.0,
				"damage_per_shot": 9.0,
				"cadence_shots_per_second": 5.5,
				"spread_degrees": 0.8,
				"origin_tolerance": 22.0,
			},
			{
				"engagement_range": 220.0,
				"preferred_engagement_distance": 70.0,
				"minimum_arming_range": 20.0,
				"aim_cosine": 0.91,
				"retreat_health_ratio": 0.18,
				"telegraph_time": 0.16,
				"weapon_cooldown": 0.18,
			},
			1.5,
			0.55,
			2.2
		),
		_variant(
			&"picket_lance",
			&"picket_standoff",
			&"perimeter_hold",
			OBJECTIVE_PROTECT_ASSET,
			&"lance",
			Profile.ROLE_LANCE,
			Tactic.STRATEGY_STANDOFF,
			{
				"range": 500.0,
				"damage_per_shot": 30.0,
				"cadence_shots_per_second": 1.3,
				"spread_degrees": 0.0,
				"origin_tolerance": 30.0,
			},
			{
				"engagement_range": 450.0,
				"preferred_engagement_distance": 300.0,
				"minimum_arming_range": 90.0,
				"aim_cosine": 0.97,
				"retreat_health_ratio": 0.30,
				"telegraph_time": 0.75,
				"weapon_cooldown": 0.77,
			},
			2.0,
			0.75,
			2.8
		),
		_variant(
			&"press_scatter",
			&"press_fighter",
			&"paired_wing_break",
			OBJECTIVE_BREAK_WING,
			&"scatter",
			Profile.ROLE_SCATTER,
			Tactic.STRATEGY_PRESS,
			{
				"range": 180.0,
				"damage_per_shot": 14.0,
				"cadence_shots_per_second": 2.5,
				"spread_degrees": 5.0,
				"origin_tolerance": 20.0,
			},
			{
				"engagement_range": 160.0,
				"preferred_engagement_distance": 55.0,
				"minimum_arming_range": 12.0,
				"aim_cosine": 0.78,
				"retreat_health_ratio": 0.25,
				"telegraph_time": 0.30,
				"weapon_cooldown": 0.40,
			},
			1.75,
			0.65,
			2.4
		),
		_variant(
			&"flanker_scatter",
			&"skirmisher_flanker",
			&"paired_wing_break",
			OBJECTIVE_BREAK_WING,
			&"scatter",
			Profile.ROLE_SCATTER,
			Tactic.STRATEGY_FLANK,
			{
				"range": 180.0,
				"damage_per_shot": 14.0,
				"cadence_shots_per_second": 2.5,
				"spread_degrees": 5.0,
				"origin_tolerance": 20.0,
			},
			{
				"engagement_range": 160.0,
				"preferred_engagement_distance": 55.0,
				"minimum_arming_range": 12.0,
				"aim_cosine": 0.78,
				"retreat_health_ratio": 0.25,
				"telegraph_time": 0.30,
				"weapon_cooldown": 0.40,
			},
			1.75,
			0.65,
			2.4
		),
	]


static func _variant(
	variant_id: StringName,
	opponent_id: StringName,
	scenario_id: StringName,
	objective: StringName,
	weapon_id: StringName,
	weapon_role: StringName,
	strategy: StringName,
	weapon_values: Dictionary,
	tactics: Dictionary,
	recovery_seconds: float,
	invulnerability_seconds: float,
	resume_seconds: float
) -> Dictionary:
	var weapon := weapon_values.duplicate(true)
	weapon["weapon_id"] = weapon_id
	weapon["weapon_role"] = weapon_role
	return {
		"variant_id": variant_id,
		"profile_id": variant_id,
		"opponent_id": opponent_id,
		"scenario_id": scenario_id,
		"objective": objective,
		"strategy": strategy,
		"weapon": weapon,
		"tactics": tactics.duplicate(true),
		"recovery": {
			"recovery_seconds": recovery_seconds,
			"invulnerability_seconds": invulnerability_seconds,
			"resume_seconds": resume_seconds,
			"low_friction": true,
		},
	}.duplicate(true)


func _capture_variant(source: Dictionary) -> Dictionary:
	var recovery: Dictionary = source.get("recovery", {}) as Dictionary
	var weapon: Dictionary = source.get("weapon", {}) as Dictionary
	var tactics: Dictionary = source.get("tactics", {}) as Dictionary
	return {
		"variant_id": StringName(source.get("variant_id", &"")),
		"profile_id": StringName(source.get("profile_id", source.get("variant_id", &""))),
		"opponent_id": StringName(source.get("opponent_id", &"")),
		"scenario_id": StringName(source.get("scenario_id", &"")),
		"objective": StringName(source.get("objective", &"")),
		"strategy": StringName(source.get("strategy", &"")),
		"weapon": weapon.duplicate(true),
		"tactics": tactics.duplicate(true),
		"recovery": {
			"recovery_seconds": float(recovery.get("recovery_seconds", NAN)),
			"invulnerability_seconds": float(recovery.get("invulnerability_seconds", NAN)),
			"resume_seconds": float(recovery.get("resume_seconds", NAN)),
			"low_friction": bool(recovery.get("low_friction", false)),
		}.duplicate(true),
	}.duplicate(true)


func _validate_configuration() -> void:
	_configuration_errors.clear()
	if _variants.is_empty() or _variants.size() > MAX_VARIANTS:
		_configuration_errors.append("variant count is outside its fixed bound")
	var variant_ids := {}
	var opponent_ids := {}
	for variant in _variants:
		var variant_id: StringName = variant.variant_id
		if not Tactic.is_stable_id(variant_id) or str(variant_id).length() > MAX_ID_LENGTH:
			_configuration_errors.append("variant IDs must be stable identifiers")
		if variant_ids.has(variant_id):
			_configuration_errors.append("variant IDs must be unique")
		variant_ids[variant_id] = true
		if not Tactic.is_stable_id(variant.opponent_id):
			_configuration_errors.append("opponent IDs must be stable identifiers")
		opponent_ids[variant.opponent_id] = true
		if not OBJECTIVE_IDS.has(variant.objective):
			_configuration_errors.append("variant objective is unknown")
		if not Tactic.is_stable_id(variant.scenario_id):
			_configuration_errors.append("scenario IDs must be stable identifiers")
		if not Tactic.is_stable_id(variant.profile_id) or not _profiles.has(variant.profile_id):
			_configuration_errors.append("variant profile is missing")
		else:
			var profile := _profiles[variant.profile_id] as Profile
			if not profile.is_configuration_valid():
				_configuration_errors.append("variant profile is invalid")
		var recovery: Dictionary = variant.recovery
		var recovery_seconds := float(recovery.recovery_seconds)
		var invulnerability_seconds := float(recovery.invulnerability_seconds)
		var resume_seconds := float(recovery.resume_seconds)
		if not is_finite(recovery_seconds) or recovery_seconds <= 0.0 or recovery_seconds > MAX_ARCADE_RECOVERY_SECONDS:
			_configuration_errors.append("recovery window must be short and finite")
		if not is_finite(invulnerability_seconds) or invulnerability_seconds < 0.0 or invulnerability_seconds > MAX_INVULNERABILITY_SECONDS or invulnerability_seconds > recovery_seconds:
			_configuration_errors.append("invulnerability window must fit the recovery budget")
		if not is_finite(resume_seconds) or resume_seconds < recovery_seconds or resume_seconds > MAX_RESUME_SECONDS:
			_configuration_errors.append("resume budget must follow and bound recovery")
		if not bool(recovery.low_friction):
			_configuration_errors.append("every breadth variant must declare low-friction recovery")
	_configuration_errors.sort()
