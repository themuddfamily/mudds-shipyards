class_name HeavyBreachScenarioAudioBinding
extends RefCounted

## Presentation-only consumer for detached heavy-breach scenario snapshots and
## intents. Encounter, combat, wing, and objective authority remain upstream.

signal semantic_breach_cue_emitted(cue_id: StringName, intensity: float)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const CUES := {
	&"started": &"heavy_breach_started",
	&"picket_windup": &"heavy_breach_picket_windup",
	&"picket_fire": &"heavy_breach_picket_fire",
	&"wing_screen": &"heavy_breach_wing_screen",
	&"suppression": &"heavy_breach_suppression",
	&"objective_danger": &"heavy_breach_objective_danger",
	&"success": &"heavy_breach_success",
	&"failure": &"heavy_breach_failure",
	&"timeout": &"heavy_breach_timeout",
}
const PRIORITIES := {
	&"heavy_breach_started": 30,
	&"heavy_breach_picket_windup": 45,
	&"heavy_breach_picket_fire": 75,
	&"heavy_breach_wing_screen": 55,
	&"heavy_breach_suppression": 60,
	&"heavy_breach_objective_danger": 85,
	&"heavy_breach_success": 100,
	&"heavy_breach_failure": 95,
	&"heavy_breach_timeout": 95,
}

var _attached := false
var _generation := 0
var _last_state: StringName = &""
var _last_outcome: StringName = &""
var _seen: Dictionary = {}
var _slots: Array[Dictionary] = []
var _emitted_count := 0

func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_state = &""
	_last_outcome = &""
	_seen.clear()
	_slots.clear()
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_last_state = &""
	_last_outcome = &""
	_seen.clear()
	_slots.clear()
	return _result(true, &"detached")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var generation: Variant = snapshot.get("scenario_generation", -1)
	var scenario: Variant = snapshot.get("scenario", &"")
	var state: Variant = snapshot.get("state", &"")
	var outcome: Variant = snapshot.get("outcome", &"")
	if not generation is int or int(generation) != _generation or scenario != &"heavy_breach":
		return _result(false, &"stale_or_foreign_snapshot")
	if not state is StringName or not outcome is StringName:
		return _result(false, &"invalid_snapshot")
	if state == &"running" and _last_state != &"running":
		_emit_once(&"started", "state")
	var ratio: Variant = snapshot.get("objective_health_ratio", 1.0)
	if (ratio is float or ratio is int) and float(ratio) <= 0.34:
		_emit_once(&"objective_danger", "objective")
	if outcome in [&"cleared", &"success"] and outcome != _last_outcome:
		_emit_once(&"success", "outcome")
	elif outcome in [&"failed", &"failure", &"escaped"] and outcome != _last_outcome:
		_emit_once(&"failure", "outcome")
	elif outcome == &"timed_out" and outcome != _last_outcome:
		_emit_once(&"timeout", "outcome")
	_last_state = state
	_last_outcome = outcome
	return _result(true, &"snapshot_presented")

func present_tactic_intent(intent: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if int(intent.get("generation", _generation)) != _generation:
		return _result(false, &"stale_generation")
	var action: Variant = intent.get("action", &"")
	if action == &"breach":
		_emit_once(&"picket_windup", "breach")
	elif action == &"screen_guard":
		_emit_once(&"wing_screen", "screen")
	if bool(intent.get("suppression_active", false)):
		_emit_once(&"suppression", "suppression")
	return _result(true, &"intent_presented")

func present_weapon_event(event: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if int(event.get("generation", _generation)) != _generation:
		return _result(false, &"stale_generation")
	var event_id: Variant = event.get("event_id", &"")
	if event_id not in [&"picket_windup", &"picket_fire"] or not bool(event.get("accepted", false)):
		return _result(false, &"invalid_weapon_event")
	_emit_once(event_id as StringName, "weapon:%s" % str(event.get("sequence", 0)))
	return _result(true, &"weapon_event_presented")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_state": _last_state, "last_outcome": _last_outcome, "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(true), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "authority": {"combat": false, "objective": false, "wing": false, "audio_cues": true}}.duplicate(true)

func _emit_once(event_id: StringName, key_suffix: String) -> void:
	var key := "%d:%s" % [_generation, key_suffix]
	if _seen.has(key) or not CUES.has(event_id):
		return
	_seen[key] = true
	var cue_id: StringName = CUES[event_id]
	var priority := int(PRIORITIES.get(cue_id, 0))
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		var lowest := 0
		for index in range(1, _slots.size()):
			if int(_slots[index].priority) < int(_slots[lowest].priority):
				lowest = index
		if priority < int(_slots[lowest].priority):
			return
		_slots[lowest] = {"cue_id": cue_id, "priority": priority}
	else:
		_slots.append({"cue_id": cue_id, "priority": priority})
	_emitted_count += 1
	semantic_breach_cue_emitted.emit(cue_id, 1.0)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
