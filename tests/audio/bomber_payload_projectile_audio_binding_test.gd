extends SceneTree

const BindingScript := preload("res://scripts/audio/bomber_payload_projectile_audio_binding.gd")
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
	binding.projectile_audio_cue_emitted.connect(_on_projectile_cue)
	router.semantic_cue_emitted.connect(_on_router_cue)
	_check(bool(binding.attach().accepted), "projectile audio binding attaches")
	_check(bool(router.bind_source(binding, &"ship").accepted), "projectile cues route through semantic router")
	_check(bool(binding.set_reduced_dynamic_range(true).accepted), "reduced range is caller-configurable")
	_check(bool(binding.present_launch_record(_record(0, 1)).accepted), "launch record routes once")
	_check(binding.present_launch_record(_record(0, 1)).reason == &"duplicate_event", "duplicate launch is rejected")
	_check(bool(binding.present_terminal_intent(_expiry(0, 1)).accepted), "expiry intent routes once")
	_check(bool(binding.present_terminal_intent(_impact(0, 2, 2)).accepted), "impact intent routes once")
	_check(_has_cue(&"bomber_payload_projectile_impact"), "impact cue reaches semantic router")
	_check(_events[0].intensity < 1.0, "reduced range attenuates projectile cues")
	_check(int(binding.get_snapshot().preempted_cue_count) >= 1, "impact priority preempts launch")
	_check(bool(binding.present_abort_record(_record(0, 2)).accepted), "abort record routes")
	_check(binding.present_abort_record(_record(0, 2)).reason == &"duplicate_event", "duplicate abort is rejected")
	_check((binding.get_snapshot().active_cue_slots as Array).size() == 2, "projectile binding retains two-voice ceiling")
	_check((binding.get_snapshot().authority as Dictionary).impact == false, "binding owns no impact authority")
	_check(bool(binding.detach().accepted), "detach clears projectile presentation")
	_check(binding.present_launch_record(_record(1, 1)).reason == &"not_attached", "detached binding rejects launch")
	_check(bool(binding.reset_for_reuse(1).accepted), "binding re-enters at next generation")
	_check(bool(binding.present_launch_record(_record(1, 1)).accepted), "re-entry resets exactly-once fence")
	router.detach()
	for failure in _failures:
		push_error(failure)
	print("bomber_payload_projectile_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _record(generation: int, sequence: int) -> Dictionary:
	return {"generation": generation, "request_sequence": sequence, "payload_id": &"cinder_payload_alpha"}


func _impact(generation: int, terminal_sequence: int, _request_sequence: int) -> Dictionary:
	return {
		"generation": generation,
		"terminal_sequence": terminal_sequence,
		"kind": &"impact",
		"payload_id": &"cinder_payload_alpha",
		"position": Vector3(2.0, 3.0, 4.0),
	}


func _expiry(generation: int, terminal_sequence: int) -> Dictionary:
	return {
		"generation": generation,
		"terminal_sequence": terminal_sequence,
		"kind": &"expiry",
		"payload_id": &"cinder_payload_alpha",
		"position": Vector3.ZERO,
	}


func _on_projectile_cue(cue_id: StringName, payload_id: StringName, intensity: float, _position: Vector3) -> void:
	_events.append({"cue_id": cue_id, "payload_id": payload_id, "intensity": intensity})


func _on_router_cue(_source: StringName, cue_id: StringName, intensity: float, _position: Vector3) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.get("cue_id", &"") == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
