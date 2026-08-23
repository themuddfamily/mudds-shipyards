extends SceneTree

const BindingScript := preload("res://scripts/audio/halyard_crew_semantic_audio_binding.gd")

var _events: Array[StringName] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScript.new()
	root.add_child(binding)
	binding.semantic_crew_cue_emitted.connect(_on_cue)
	_check(bool(binding.attach().accepted), "Halyard crew audio attaches")
	var base := _snapshot(1, &"started", 1.0)
	_check(bool(binding.present_crew_snapshot(base).accepted), "engineer repair start is accepted")
	_check(_events.has(&"crew_engineer_repair_started"), "engineer start routes through crew binding")
	var progress := _snapshot(2, &"progress", 0.5)
	_check(bool(binding.present_crew_snapshot(progress).accepted), "engineer repair progress is accepted")
	var completed := _snapshot(3, &"completed", 1.0)
	_check(bool(binding.present_crew_snapshot(completed).accepted), "engineer repair completion is accepted")
	_check(_events.has(&"crew_engineer_repair_completed"), "engineer completion routes through crew binding")
	var event_count := _events.size()
	_check(bool(binding.present_crew_snapshot(completed).accepted), "duplicate crew snapshot remains harmless")
	_check(_events.size() == event_count, "duplicate engineer sequence emits no second cue")
	_check((binding.get_snapshot().engineer_binding as Dictionary).attached, "engineer child binding remains attached")
	_check((binding.get_snapshot().active_cue_slots as Array).size() <= 2, "Halyard retains two-voice ceiling")
	_check(bool(binding.detach().accepted), "Halyard detach clears engineer binding")
	_check(not bool((binding.get_snapshot().engineer_binding as Dictionary).attached), "engineer binding detaches with Halyard")
	_check(bool(binding.attach(1).accepted), "Halyard re-enters at next generation")
	_check(bool(binding.present_crew_snapshot(_snapshot(1, &"started", 1.0)).accepted), "engineer sequence resets on re-entry")
	for failure in _failures:
		push_error(failure)
	print("halyard_engineer_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(sequence: int, state: StringName, progress: float) -> Dictionary:
	return {
		"occupants": [],
		"departure_readiness": {"ready": false},
		"power_routing": {},
		"emergency_pilot_handoff": {},
		"engineer_repair": {
			"sequence": sequence,
			"repair_state": state,
			"progress": progress,
		},
	}


func _on_cue(cue_id: StringName, _role: StringName, _intensity: float) -> void:
	_events.append(cue_id)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
