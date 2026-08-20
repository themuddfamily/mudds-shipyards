class_name CombatScenarioCatalog
extends RefCounted

## Detached catalog for a small, replayable combat-breadth slice.
##
## The catalog joins the existing weapon/tactic profiles to scenario objectives
## without becoming another combat owner.  It never registers a source, moves
## an opponent, resolves a shot, applies damage, or advances time.  A session
## supplies the observation snapshot and owns all world effects.
##
## Evidence status: modern_interpretation.  These scenario names, rosters and
## objective numbers are authored design, not an authenticated historical
## mission or weapon doctrine.

const Profile := preload("res://scripts/combat/combat_breadth_profile.gd")

const SCHEMA_VERSION := 1
const MAX_SCENARIOS := 8
const MAX_ROSTER := 4
const MAX_ID_LENGTH := 64

const OBJECTIVE_INTERCEPT: StringName = &"intercept_runner"
const OBJECTIVE_BREAK_WING: StringName = &"break_wing"
const OBJECTIVE_PROTECT_ASSET: StringName = &"protect_asset"
const OBJECTIVE_IDS: Array[StringName] = [
	OBJECTIVE_INTERCEPT, OBJECTIVE_BREAK_WING, OBJECTIVE_PROTECT_ASSET,
]

const OUTCOME_PENDING: StringName = &"pending"
const OUTCOME_CLEARED: StringName = &"cleared"
const OUTCOME_ESCAPED: StringName = &"escaped"
const OUTCOME_LOST: StringName = &"lost"
const OUTCOME_WITHDRAWN: StringName = &"withdrawn"
const OUTCOME_EXPIRED: StringName = &"expired"
const OUTCOME_ABORTED: StringName = &"aborted"
const TERMINAL_OUTCOMES: Array[StringName] = [
	OUTCOME_CLEARED, OUTCOME_ESCAPED, OUTCOME_LOST, OUTCOME_WITHDRAWN,
	OUTCOME_EXPIRED, OUTCOME_ABORTED,
]

var _scenarios: Array = []
var _profiles: Dictionary = {}
var _configuration_errors := PackedStringArray()


func _init(p_scenarios: Array = [], p_profiles: Array = []) -> void:
	_scenarios = _capture_scenarios(
		p_scenarios if not p_scenarios.is_empty() else _default_scenarios()
	)
	var source_profiles: Array = p_profiles if not p_profiles.is_empty() else Profile.build_examples()
	for profile in source_profiles:
		if profile is Profile:
			_profiles[profile.get_profile_id()] = profile.get_snapshot()
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func get_scenario_ids() -> Array:
	var ids: Array = []
	for scenario in _scenarios:
		ids.append(scenario.id)
	return ids


func get_scenario(scenario_id: StringName) -> Dictionary:
	for scenario in _scenarios:
		if scenario.id == scenario_id:
			return scenario.duplicate(true)
	return {}


func get_profile_snapshot(profile_id: StringName) -> Dictionary:
	return _profiles.get(profile_id, {}).duplicate(true)


## Deterministic sortie selection.  The caller owns the sortie counter; this
## function has no random stream or hidden progression state.
func select_scenario(sortie_index: int) -> Dictionary:
	if _scenarios.is_empty() or sortie_index < 0:
		return {}
	return _scenarios[sortie_index % _scenarios.size()].duplicate(true)


## Evaluates detached state against one scenario.  The state keys are caller
## observations, not authority writes: player_alive, phase_authorized,
## disengaged, runner_distance, runner_escape_distance, targets_destroyed,
## protected_health_ratio and elapsed_seconds.  Missing optional measurements
## resolve to safe defaults and never make a scenario win accidentally.
func evaluate(scenario_id: StringName, state: Dictionary) -> Dictionary:
	var result := {
		"accepted": false,
		"reason": &"unknown_scenario",
		"scenario_id": scenario_id,
		"outcome": OUTCOME_PENDING,
	}
	var scenario := get_scenario(scenario_id)
	if scenario.is_empty():
		return result
	if not _valid_state(state):
		result.reason = &"invalid_state"
		return result
	result.accepted = true
	result.reason = &"evaluated"
	result.outcome = _evaluate_outcome(scenario, state)
	result.terminal = TERMINAL_OUTCOMES.has(result.outcome)
	return result


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"scenarios": _scenarios.duplicate(true),
		"profiles": _profiles.duplicate(true),
		"configuration_errors": get_configuration_errors(),
		"evidence": {
			"status": &"modern_interpretation",
			"authenticated_original_scenario": false,
			"authenticated_original_doctrine": false,
		},
		"authority": {
			"combat_resolution": false,
			"damage": false,
			"movement": false,
			"phase": false,
			"lifecycle": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": is_configuration_valid(),
		"errors": get_configuration_errors(),
		"catalog": get_snapshot(),
	}.duplicate(true)


static func _default_scenarios() -> Array:
	return [
		{
			"id": &"courier_intercept",
			"objective": OBJECTIVE_INTERCEPT,
			"roster": [&"standoff_lance", &"press_repeater"],
			"primary_profile": &"standoff_lance",
			"duration_seconds": 120.0,
			"runner_escape_distance": 1400.0,
			"protected_health_floor": 0.0,
		},
		{
			"id": &"paired_wing_break",
			"objective": OBJECTIVE_BREAK_WING,
			"roster": [&"press_repeater", &"flank_scatter"],
			"primary_profile": &"flank_scatter",
			"duration_seconds": 150.0,
			"runner_escape_distance": 0.0,
			"protected_health_floor": 0.0,
		},
		{
			"id": &"perimeter_hold",
			"objective": OBJECTIVE_PROTECT_ASSET,
			"roster": [&"standoff_lance", &"flank_scatter", &"press_repeater"],
			"primary_profile": &"press_repeater",
			"duration_seconds": 90.0,
			"runner_escape_distance": 0.0,
			"protected_health_floor": 0.35,
		},
	]


func _capture_scenarios(source: Array) -> Array:
	var captured: Array = []
	for value in source:
		if value is Dictionary:
			var roster: Array = []
			for profile_id in value.get("roster", []):
				roster.append(StringName(profile_id))
			captured.append({
				"id": StringName(value.get("id", &"")),
				"objective": StringName(value.get("objective", &"")),
				"roster": roster,
				"primary_profile": StringName(value.get("primary_profile", &"")),
				"duration_seconds": float(value.get("duration_seconds", NAN)),
				"runner_escape_distance": float(value.get("runner_escape_distance", 0.0)),
				"protected_health_floor": float(value.get("protected_health_floor", 0.0)),
			}.duplicate(true))
	return captured


func _validate_configuration() -> void:
	if _scenarios.is_empty() or _scenarios.size() > MAX_SCENARIOS:
		_configuration_errors.append("scenario count is outside its fixed bound")
	var seen := {}
	for scenario in _scenarios:
		var scenario_id: StringName = scenario.id
		if not _is_stable_id(scenario_id) or str(scenario_id).length() > MAX_ID_LENGTH:
			_configuration_errors.append("scenario IDs must be stable identifiers")
		if seen.has(scenario_id):
			_configuration_errors.append("scenario IDs must be unique")
		seen[scenario_id] = true
		if not OBJECTIVE_IDS.has(scenario.objective):
			_configuration_errors.append("scenario objective is unknown")
		if scenario.roster.is_empty() or scenario.roster.size() > MAX_ROSTER:
			_configuration_errors.append("scenario roster is outside its fixed bound")
		if not _is_stable_id(scenario.primary_profile) or not _profiles.has(scenario.primary_profile):
			_configuration_errors.append("primary profile must be present in the catalog")
		for profile_id in scenario.roster:
			if not _profiles.has(profile_id):
				_configuration_errors.append("roster profile must be present in the catalog")
		if not is_finite(float(scenario.duration_seconds)) or scenario.duration_seconds <= 0.0:
			_configuration_errors.append("scenario duration must be finite and positive")
		if not is_finite(float(scenario.runner_escape_distance)) or scenario.runner_escape_distance < 0.0:
			_configuration_errors.append("runner escape distance must be finite and non-negative")
		if not is_finite(float(scenario.protected_health_floor)) or scenario.protected_health_floor < 0.0 or scenario.protected_health_floor > 1.0:
			_configuration_errors.append("protected health floor must be within 0..1")
	_configuration_errors.sort()


func _evaluate_outcome(scenario: Dictionary, state: Dictionary) -> StringName:
	if not bool(state.get("player_alive", true)):
		return OUTCOME_ABORTED
	if not bool(state.get("phase_authorized", true)):
		return OUTCOME_WITHDRAWN
	if bool(state.get("disengaged", false)):
		return OUTCOME_WITHDRAWN
	match scenario.objective:
		OBJECTIVE_INTERCEPT:
			if bool(state.get("runner_captured", false)):
				return OUTCOME_CLEARED
			if float(state.get("runner_distance", 0.0)) >= scenario.runner_escape_distance:
				return OUTCOME_ESCAPED
		OBJECTIVE_BREAK_WING:
			if int(state.get("targets_destroyed", 0)) >= scenario.roster.size():
				return OUTCOME_CLEARED
		OBJECTIVE_PROTECT_ASSET:
			if float(state.get("protected_health_ratio", 1.0)) <= scenario.protected_health_floor:
				return OUTCOME_LOST
			if float(state.get("elapsed_seconds", 0.0)) >= scenario.duration_seconds:
				return OUTCOME_CLEARED
	if float(state.get("elapsed_seconds", 0.0)) >= scenario.duration_seconds:
		return OUTCOME_EXPIRED
	return OUTCOME_PENDING


func _valid_state(state: Dictionary) -> bool:
	for key in [&"elapsed_seconds", &"runner_distance", &"runner_escape_distance", &"protected_health_ratio"]:
		if state.has(key) and (not (state[key] is int or state[key] is float) or not is_finite(float(state[key]))):
			return false
	if float(state.get("elapsed_seconds", 0.0)) < 0.0:
		return false
	if float(state.get("runner_distance", 0.0)) < 0.0:
		return false
	var ratio := float(state.get("protected_health_ratio", 1.0))
	return ratio >= 0.0 and ratio <= 1.0


static func _is_stable_id(value: Variant) -> bool:
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
