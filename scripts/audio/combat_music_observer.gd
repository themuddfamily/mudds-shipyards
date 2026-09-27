class_name CombatMusicObserver
extends RefCounted

## Pure reduction of already-decided combat snapshots into one music
## observation for `CombatMusicLayer`.
##
## Every input is a detached copy the caller already owns: the encounter
## scenario director's public state, the station-defence activity snapshot,
## the Cinder convoy threat snapshot, and whether the legacy interceptor
## engagement is live. The observer never reads a node, never calls back into
## gameplay, and never decides an outcome: it only notices the edge where a
## source it saw engaged reports a terminal state, and maps that terminal state
## onto the three musical answers (victory, failure, or a quiet release).

const OUTCOME_NONE: StringName = &""
const OUTCOME_VICTORY: StringName = &"victory"
const OUTCOME_FAILURE: StringName = &"failure"

## EncounterScenarioDirector vocabulary, copied rather than preloaded so the
## observer stays a leaf that tests can drive without the combat stack.
const ENCOUNTER_RUNNING: StringName = &"running"
const ENCOUNTER_CONCLUDED: StringName = &"concluded"
const ENCOUNTER_VICTORY_OUTCOMES: Array[StringName] = [&"cleared"]
const ENCOUNTER_FAILURE_OUTCOMES: Array[StringName] = [&"escaped", &"aborted", &"expired"]
## StationDefenseActivity `state_id` vocabulary.
const DEFENSE_ACTIVE := "active"
const DEFENSE_VICTORY_STATES: Array[String] = ["completed"]
const DEFENSE_FAILURE_STATES: Array[String] = ["failed", "timed_out"]

var _encounter_running_generation := -1
var _defense_active_generation := -1
var _convoy_engaged_generation := -1
var _outcome_serial := 0
var _last_observation: Dictionary = {}


## Reduces one sample of caller-owned snapshots. Missing or malformed sources
## read as "not engaged"; they never raise and never invent an outcome.
func observe(sources: Dictionary) -> Dictionary:
	var engaged := false
	var hostile_count := 0
	var outcomes: Array[StringName] = []
	var engaged_sources: Array[StringName] = []

	var encounter := _dictionary(sources.get("encounter"))
	if not encounter.is_empty():
		var state := StringName(encounter.get("state", &""))
		var generation := int(encounter.get("generation", -1))
		if state == ENCOUNTER_RUNNING:
			engaged = true
			engaged_sources.append(&"encounter")
			hostile_count += maxi(0, int(encounter.get("hostile_count", 0)))
			_encounter_running_generation = generation
		elif _encounter_running_generation >= 0:
			if state == ENCOUNTER_CONCLUDED and generation == _encounter_running_generation:
				var outcome := StringName(encounter.get("outcome", &""))
				if ENCOUNTER_VICTORY_OUTCOMES.has(outcome):
					outcomes.append(OUTCOME_VICTORY)
				elif ENCOUNTER_FAILURE_OUTCOMES.has(outcome):
					outcomes.append(OUTCOME_FAILURE)
			# Any non-running state after a running one closes that generation:
			# a withdrawal or a reset is a quiet release, and a late repeat of
			# the same concluded snapshot cannot fire a second stinger.
			_encounter_running_generation = -1

	var defense := _dictionary(sources.get("station_defense"))
	if not defense.is_empty():
		var state_id := String(defense.get("state_id", ""))
		var generation := int(defense.get("generation", -1))
		if state_id == DEFENSE_ACTIVE:
			engaged = true
			engaged_sources.append(&"station_defense")
			hostile_count += maxi(0, int(defense.get("remaining_hostile_count", 0))) \
				if bool(defense.get("wave_active", false)) else 0
			_defense_active_generation = generation
		elif _defense_active_generation >= 0:
			if generation == _defense_active_generation:
				if DEFENSE_VICTORY_STATES.has(state_id):
					outcomes.append(OUTCOME_VICTORY)
				elif DEFENSE_FAILURE_STATES.has(state_id):
					outcomes.append(OUTCOME_FAILURE)
			_defense_active_generation = -1
	elif _defense_active_generation >= 0:
		# The defence content left the world mid-run: a quiet release.
		_defense_active_generation = -1

	var convoy := _dictionary(sources.get("convoy_threat"))
	var convoy_active := bool(convoy.get("active", false))
	var attacker_alive := bool(convoy.get("attacker_alive", false))
	if convoy_active and attacker_alive:
		engaged = true
		engaged_sources.append(&"convoy_threat")
		hostile_count += 1
		_convoy_engaged_generation = int(convoy.get("generation", 0))
	elif _convoy_engaged_generation >= 0:
		var same_generation := int(convoy.get("generation", -1)) == _convoy_engaged_generation
		var tender_maximum := float(convoy.get("tender_maximum_health", 0.0))
		if same_generation and tender_maximum > 0.0 and float(convoy.get("tender_health", 0.0)) <= 0.0:
			outcomes.append(OUTCOME_FAILURE)
		elif same_generation and convoy_active and not attacker_alive:
			outcomes.append(OUTCOME_VICTORY)
		_convoy_engaged_generation = -1

	if bool(sources.get("legacy_engaged", false)):
		engaged = true
		engaged_sources.append(&"legacy")
		hostile_count += maxi(1, int(sources.get("legacy_hostile_count", 1)))

	# A loss anywhere outranks a win elsewhere in the same sample: the subdued
	# stinger is the honest answer when the station falls as the picket dies.
	var outcome := OUTCOME_NONE
	if outcomes.has(OUTCOME_FAILURE):
		outcome = OUTCOME_FAILURE
	elif outcomes.has(OUTCOME_VICTORY):
		outcome = OUTCOME_VICTORY
	if outcome != OUTCOME_NONE:
		_outcome_serial += 1

	_last_observation = {
		"engaged": engaged,
		"hostile_count": hostile_count,
		"outcome": outcome,
		"outcome_serial": _outcome_serial,
		"engaged_sources": engaged_sources,
		"presentation_only": true,
	}
	return _last_observation.duplicate(true)


func reset() -> void:
	_encounter_running_generation = -1
	_defense_active_generation = -1
	_convoy_engaged_generation = -1
	_last_observation = {}


func get_snapshot() -> Dictionary:
	return {
		"encounter_running_generation": _encounter_running_generation,
		"defense_active_generation": _defense_active_generation,
		"convoy_engaged_generation": _convoy_engaged_generation,
		"outcome_serial": _outcome_serial,
		"last_observation": _last_observation.duplicate(true),
		"gameplay_authority": false,
	}


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
