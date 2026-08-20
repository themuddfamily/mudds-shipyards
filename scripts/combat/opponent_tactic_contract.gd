class_name OpponentTacticContract
extends RefCounted

## Immutable, renderer-independent contract for one opponent's weapon envelope
## and tactical response.
##
## The existing opponent scenes own movement, firing and presentation. This
## contract owns neither: it snapshots the values those owners already expose
## and evaluates one deterministic observation into a motion/fire intent. A
## caller can therefore compare a courier, picket, press fighter or flanker
## without introducing a second combat authority or a random AI stream.
##
## Evidence status: modern_interpretation. No historical weapon, doctrine or
## opponent tactic is authenticated by this data contract.

enum Strategy {
	PRESS,
	STANDOFF,
	FLANK,
	RUNNER,
}

const SCHEMA_VERSION := 1
const MAX_ID_LENGTH := 64
const MAX_RANGE_METERS := 100_000.0
const MAX_DAMAGE_PER_HIT := 1_000_000.0
const MAX_TACTIC_SECONDS := 60.0

const STRATEGY_PRESS: StringName = &"press"
const STRATEGY_STANDOFF: StringName = &"standoff"
const STRATEGY_FLANK: StringName = &"flank"
const STRATEGY_RUNNER: StringName = &"runner"
const STRATEGY_IDS: Array[StringName] = [
	STRATEGY_PRESS, STRATEGY_STANDOFF, STRATEGY_FLANK, STRATEGY_RUNNER,
]

const ACTION_CLOSE: StringName = &"close"
const ACTION_HOLD: StringName = &"hold"
const ACTION_RETREAT: StringName = &"retreat"
const ACTION_FLANK: StringName = &"flank"
const ACTION_ESCAPE: StringName = &"escape"
const ACTION_FIRE: StringName = &"fire"

var _tactic_id: StringName
var _weapon_id: StringName
var _strategy: StringName
var _weapon: Dictionary = {}
var _tactics: Dictionary = {}
var _configuration_errors := PackedStringArray()


func _init(
	p_tactic_id: StringName,
	p_strategy: StringName,
	p_weapon_id: StringName,
	p_weapon_profile: Dictionary,
	p_tactics_profile: Dictionary
	) -> void:
	_tactic_id = p_tactic_id
	_strategy = p_strategy
	_weapon_id = p_weapon_id
	_weapon = _capture_weapon(p_weapon_profile)
	_tactics = _capture_tactics(p_tactics_profile)
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func get_tactic_id() -> StringName:
	return _tactic_id


func get_weapon_id() -> StringName:
	return _weapon_id


func get_strategy() -> StringName:
	return _strategy


func get_weapon_profile() -> Dictionary:
	return _weapon.duplicate(true)


func get_tactics_profile() -> Dictionary:
	return _tactics.duplicate(true)


## Evaluates one detached observation. No node, physics query, clock or random
## source is read. `aim_cosine` is the caller's current forward/target dot
## product and `role_ready` is the coordinator-owned permission for a flanker.
func evaluate(
	distance: float,
	aim_cosine: float,
	hull_ratio: float,
	role_ready: bool = true
	) -> Dictionary:
	var result := {
		"accepted": false,
		"reason": &"invalid_sample",
		"action": ACTION_HOLD,
		"fire_authorized": false,
		"in_weapon_band": false,
		"tactic_id": _tactic_id,
		"weapon_id": _weapon_id,
	}
	if not is_configuration_valid():
		result.reason = &"invalid_configuration"
		return result
	if not is_finite(distance) or distance < 0.0:
		return result
	if not is_finite(aim_cosine) or aim_cosine < -1.0 or aim_cosine > 1.0:
		return result
	if not is_finite(hull_ratio) or hull_ratio < 0.0 or hull_ratio > 1.0:
		return result

	var minimum_range := float(_tactics.minimum_arming_range)
	var engagement_range := minf(
		float(_tactics.engagement_range),
		float(_weapon.range)
	)
	var preferred_range := float(_tactics.preferred_engagement_distance)
	var in_band := distance >= minimum_range and distance <= engagement_range
	result.accepted = true
	result.reason = &"evaluated"
	result.in_weapon_band = in_band

	if hull_ratio <= float(_tactics.retreat_health_ratio):
		result.action = ACTION_RETREAT
		return result

	if _strategy == STRATEGY_RUNNER:
		result.action = ACTION_ESCAPE
		if in_band and aim_cosine >= float(_tactics.aim_cosine):
			result.action = ACTION_FIRE
			result.fire_authorized = true
		return result

	if _strategy == STRATEGY_FLANK and not role_ready:
		result.action = ACTION_FLANK
		return result

	if distance < minimum_range:
		result.action = ACTION_RETREAT
		return result
	if distance > preferred_range * 1.25:
		result.action = ACTION_FLANK if _strategy == STRATEGY_FLANK else ACTION_CLOSE
		return result
	if _strategy == STRATEGY_FLANK and aim_cosine < float(_tactics.aim_cosine):
		result.action = ACTION_FLANK
		return result
	if in_band and aim_cosine >= float(_tactics.aim_cosine):
		result.action = ACTION_FIRE
		result.fire_authorized = true
	else:
		result.action = ACTION_HOLD
	return result


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"tactic_id": _tactic_id,
		"strategy": _strategy,
		"weapon_id": _weapon_id,
		"weapon": get_weapon_profile(),
		"tactics": get_tactics_profile(),
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
		},
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": is_configuration_valid(),
		"errors": get_configuration_errors(),
		"contract": get_snapshot(),
	}.duplicate(true)


func _capture_weapon(profile: Dictionary) -> Dictionary:
	return {
		"range": _number(profile.get("range", NAN)),
		"damage": _number(profile.get("damage", NAN)),
		"origin_tolerance": _number(profile.get("origin_tolerance", NAN)),
	}.duplicate(true)


func _capture_tactics(profile: Dictionary) -> Dictionary:
	return {
		"engagement_range": _number(profile.get("engagement_range", NAN)),
		"preferred_engagement_distance": _number(
			profile.get("preferred_engagement_distance", NAN)
		),
		"minimum_arming_range": _number(profile.get("minimum_arming_range", 0.0)),
		"aim_cosine": _number(profile.get("aim_cosine", 0.9)),
		"retreat_health_ratio": _number(profile.get("retreat_health_ratio", 0.2)),
		"telegraph_time": _number(profile.get("telegraph_time", 0.0)),
		"weapon_cooldown": _number(profile.get("weapon_cooldown", 0.0)),
	}.duplicate(true)


func _validate_configuration() -> void:
	if not is_stable_id(_tactic_id):
		_configuration_errors.append("tactic_id must be a stable identifier")
	if not is_stable_id(_weapon_id):
		_configuration_errors.append("weapon_id must be a stable identifier")
	if not STRATEGY_IDS.has(_strategy):
		_configuration_errors.append("strategy must be one of the frozen tactic IDs")
	var weapon_range := float(_weapon.range)
	var weapon_damage := float(_weapon.damage)
	var origin_tolerance := float(_weapon.origin_tolerance)
	if not is_finite(weapon_range) or weapon_range <= 0.0 or weapon_range > MAX_RANGE_METERS:
		_configuration_errors.append("weapon range is outside its finite bound")
	if not is_finite(weapon_damage) or weapon_damage <= 0.0 or weapon_damage > MAX_DAMAGE_PER_HIT:
		_configuration_errors.append("weapon damage is outside its finite bound")
	if not is_finite(origin_tolerance) or origin_tolerance <= 0.0 or origin_tolerance > MAX_RANGE_METERS:
		_configuration_errors.append("weapon origin tolerance is outside its finite bound")
	var minimum_range := float(_tactics.minimum_arming_range)
	var preferred_range := float(_tactics.preferred_engagement_distance)
	var engagement_range := float(_tactics.engagement_range)
	if not is_finite(engagement_range) or engagement_range <= 0.0 or engagement_range > MAX_RANGE_METERS:
		_configuration_errors.append("engagement range is outside its finite bound")
	if not is_finite(preferred_range) or preferred_range <= 0.0 or preferred_range > engagement_range:
		_configuration_errors.append("preferred range must be positive and inside engagement range")
	if not is_finite(minimum_range) or minimum_range < 0.0 or minimum_range >= preferred_range:
		_configuration_errors.append("minimum arming range must be below preferred range")
	var aim_cosine := float(_tactics.aim_cosine)
	if not is_finite(aim_cosine) or aim_cosine < -1.0 or aim_cosine > 1.0:
		_configuration_errors.append("aim cosine must be within -1..1")
	var retreat_ratio := float(_tactics.retreat_health_ratio)
	if not is_finite(retreat_ratio) or retreat_ratio < 0.0 or retreat_ratio > 1.0:
		_configuration_errors.append("retreat health ratio must be within 0..1")
	for key in [&"telegraph_time", &"weapon_cooldown"]:
		var seconds := float(_tactics[key])
		if not is_finite(seconds) or seconds < 0.0 or seconds > MAX_TACTIC_SECONDS:
			_configuration_errors.append("%s is outside its finite bound" % key)
	_configuration_errors.sort()


static func is_stable_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for character in text:
		var code := character.unicode_at(0)
		if not (code >= 97 and code <= 122 or code >= 48 and code <= 57 or character in ["_", "-", "."]):
			return false
	return true


static func _number(value: Variant) -> float:
	return float(value) if value is int or value is float else NAN
