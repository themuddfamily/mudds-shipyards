extends SceneTree

const Binding := preload("res://scripts/audio/heavy_breach_scenario_audio_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := Binding.new()
	var cues: Array[StringName] = []
	binding.semantic_breach_cue_emitted.connect(func(cue_id: StringName, _intensity: float) -> void: cues.append(cue_id))
	_check(bool(binding.attach().accepted), "heavy-breach audio binding attaches")
	var base := {"scenario_generation": 1, "scenario": &"heavy_breach", "state": &"running", "outcome": &"pending", "objective_health_ratio": 1.0}
	_check(not bool(binding.present_snapshot(base).accepted), "mismatched director generation fails closed")
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted), "generation detach and reattach are fenced")
	_check(bool(binding.present_snapshot(base).accepted), "heavy-breach running snapshot is accepted")
	_check(bool(binding.present_tactic_intent({"generation": 1, "action": &"breach", "suppression_active": false}).accepted), "picket breach intent emits windup cue")
	_check(bool(binding.present_weapon_event({"generation": 1, "event_id": &"picket_fire", "sequence": 1, "accepted": true}).accepted), "accepted picket fire emits cue")
	_check(bool(binding.present_tactic_intent({"generation": 1, "action": &"screen_guard", "suppression_active": true}).accepted), "wing screen and suppression intent emits cues")
	var danger := base.duplicate(true)
	danger.objective_health_ratio = 0.2
	_check(bool(binding.present_snapshot(danger).accepted), "objective danger snapshot is accepted")
	var success := base.duplicate(true)
	success.state = &"concluded"
	success.outcome = &"cleared"
	_check(bool(binding.present_snapshot(success).accepted), "success snapshot is accepted")
	_check(cues.has(&"heavy_breach_picket_windup") and cues.has(&"heavy_breach_picket_fire") and cues.has(&"heavy_breach_wing_screen") and cues.has(&"heavy_breach_suppression") and cues.has(&"heavy_breach_objective_danger") and cues.has(&"heavy_breach_success"), "all bounded heavy-breach semantic cues are emitted")
	_check(int(binding.get_snapshot().maximum_simultaneous_voices) == 2, "heavy-breach audio remains bounded to two voices")
	_check(bool(binding.detach().accepted) and binding.present_snapshot(base).reason == &"not_attached", "detach clears stale scenario presentation")
	for failure in _failures:
		push_error(failure)
	print("HEAVY_BREACH_SCENARIO_AUDIO_BINDING_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
