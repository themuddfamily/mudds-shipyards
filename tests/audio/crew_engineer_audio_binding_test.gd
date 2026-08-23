extends SceneTree

const BindingScript := preload("res://scripts/audio/crew_engineer_audio_binding.gd")
const RouterScript := preload("res://scripts/audio/semantic_audio_cue_router.gd")

var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScript.new()
	var router := RouterScript.new()
	root.add_child(binding)
	root.add_child(router)
	router.semantic_cue_emitted.connect(_on_router_cue)
	_check(bool(binding.attach().accepted), "engineer audio binding attaches")
	_check(bool(router.bind_source(binding, &"ship").accepted), "binding routes through existing semantic router")
	_check(bool(binding.set_reduced_dynamic_range(true).accepted), "reduced range is caller-configurable")
	_check(bool(binding.present_repair_snapshot(_snapshot(0, 1, &"started", 1.0)).accepted), "repair start is accepted")
	_check(bool(binding.present_repair_snapshot(_snapshot(0, 2, &"progress", 0.5)).accepted), "repair progress is accepted")
	_check(bool(binding.present_repair_snapshot(_snapshot(0, 3, &"interrupted", 0.5)).accepted), "repair interruption is accepted")
	_check(bool(binding.present_repair_snapshot(_snapshot(0, 4, &"completed", 1.0)).accepted), "repair completion is accepted")
	_check(_has_event(&"crew_engineer_repair_started"), "repair start cue routes")
	_check(_has_event(&"crew_engineer_repair_completed"), "repair completion cue routes")
	_check(_events[1].intensity < 1.0, "reduced range attenuates cue intensity deterministically")
	_check(binding.present_repair_snapshot(_snapshot(0, 4, &"completed", 1.0)).reason == &"duplicate_sequence", "duplicate sequence is rejected")
	_check((binding.get_snapshot().active_cue_slots as Array).size() == 2, "repair cues retain two-voice ceiling")
	_check(int(binding.get_snapshot().preempted_cue_count) >= 1, "completion preempts lower priority cue")
	_check((binding.get_snapshot().authority as Dictionary).repair == false, "binding owns no repair authority")
	_check(bool(binding.detach().accepted), "detach clears engineer presentation")
	_check(binding.present_repair_snapshot(_snapshot(1, 1, &"started", 1.0)).reason == &"not_attached", "detached binding rejects events")
	_check(binding.attach(1).accepted, "binding re-enters at next generation")
	_check(binding.present_repair_snapshot(_snapshot(1, 1, &"started", 1.0)).accepted, "re-entry resets sequence fence")
	router.detach()
	for failure in _failures:
		push_error(failure)
	print("crew_engineer_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(generation: int, sequence: int, state: StringName, progress: float) -> Dictionary:
	return {"generation": generation, "sequence": sequence, "repair_state": state, "progress": progress}


func _on_router_cue(source_id: StringName, cue_id: StringName, intensity: float, _position: Vector3) -> void:
	_events.append({"source": source_id, "cue_id": cue_id, "intensity": intensity})


func _has_event(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
