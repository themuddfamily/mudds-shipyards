extends SceneTree

const BindingScript := preload("res://scripts/audio/bomber_payload_audio_binding.gd")
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
	binding.payload_audio_cue_emitted.connect(_on_payload_cue)
	router.semantic_cue_emitted.connect(_on_router_cue)
	_check(bool(binding.attach().accepted), "payload audio binding attaches")
	_check(bool(router.bind_source(binding, &"ship").accepted), "payload cues route through existing semantic router")
	_check(bool(binding.set_reduced_dynamic_range(true).accepted), "reduced range is caller-configurable")
	_check(bool(binding.present_release_record(_record(0, 1, &"cinder_payload_alpha")).accepted), "accepted release routes")
	_check(bool(binding.present_release_record(_record(0, 2, &"cinder_payload_beta")).accepted), "second payload routes")
	_check(_has_payload(&"cinder_payload_alpha"), "payload ID is retained in release cue")
	_check(_events[0].intensity < 1.0, "reduced range attenuates payload cue intensity")
	_check(binding.present_release_record(_record(0, 2, &"cinder_payload_beta")).reason == &"duplicate_sequence", "duplicate release is rejected")
	_check(bool(binding.present_abort_record(_record(0, 3, &"cinder_payload_beta")).accepted), "abort record routes")
	_check(_has_router_cue(&"bomber_payload_abort"), "abort cue reaches semantic router")
	_check(int(binding.get_snapshot().preempted_cue_count) >= 1, "abort preempts a lower priority payload cue")
	_check(int((binding.get_snapshot().active_cue_slots as Array).size()) == 2, "payload binding retains two-voice ceiling")
	_check((binding.get_snapshot().authority as Dictionary).spawn == false, "binding owns no payload spawn authority")
	_check(bool(binding.detach().accepted), "detach clears payload presentation")
	_check(binding.present_release_record(_record(1, 1, &"cinder_payload_alpha")).reason == &"not_attached", "detached binding rejects releases")
	_check(bool(binding.reset_for_reuse(1).accepted), "binding re-enters at next generation")
	_check(bool(binding.present_release_record(_record(1, 1, &"cinder_payload_alpha")).accepted), "re-entry resets sequence fence")
	router.detach()
	for failure in _failures:
		push_error(failure)
	print("bomber_payload_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _record(generation: int, sequence: int, payload_id: StringName) -> Dictionary:
	return {
		"generation": generation,
		"request_sequence": sequence,
		"payload_id": payload_id,
		"audio_id": &"payload_release_audio",
	}


func _on_payload_cue(cue_id: StringName, payload_id: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "payload_id": payload_id, "intensity": intensity})


func _on_router_cue(_source: StringName, cue_id: StringName, intensity: float, _position: Vector3) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity})


func _has_payload(payload_id: StringName) -> bool:
	for event in _events:
		if event.get("payload_id", &"") == payload_id:
			return true
	return false


func _has_router_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.get("cue_id", &"") == cue_id and not event.has("payload_id"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
