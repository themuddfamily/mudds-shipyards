extends SceneTree

const BindingScript := preload("res://scripts/audio/halyard_crew_semantic_audio_binding.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScript.new()
	root.add_child(binding)
	binding.semantic_crew_cue_emitted.connect(_on_cue)
	_check(bool(binding.attach().accepted), "crew audio binding attaches")
	var base := _snapshot([_occupant(7, &"avatar_a", &"engineer")], false, {}, {})
	_check(bool(binding.present_crew_snapshot(base).accepted), "crew snapshot is accepted")
	_check(_has_cue(&"crew_role_joined"), "role joined cue emits")
	var route := _snapshot(
		[_occupant(7, &"avatar_a", &"engineer")], true,
		{"channel": &"mobility", "component_generation": 3}, {}
	)
	_check(bool(binding.present_crew_snapshot(route).accepted), "route and departure snapshot is accepted")
	_check(_has_cue(&"crew_engineer_route_changed") and _has_cue(&"crew_departure_ready"), "route and departure cues emit")
	_check(bool(binding.present_crew_snapshot(route).accepted), "duplicate crew snapshot is accepted")
	_check(_events.size() == 3, "duplicate snapshot does not spam cues")
	var handoff := _snapshot(
		[_occupant(7, &"avatar_a", &"engineer")], true,
		{"channel": &"mobility", "component_generation": 3},
		{"authority_event_sequence": 9, "new_seat_generation": 4}
	)
	_check(bool(binding.present_crew_snapshot(handoff).accepted), "handoff snapshot is accepted")
	var audit := binding.get_snapshot()
	_check(_has_cue(&"crew_emergency_pilot_handoff"), "emergency pilot handoff cue emits")
	_check((audit.active_cue_slots as Array).size() == 2, "crew cues retain two-voice ceiling")
	_check(int(audit.preempted_cue_count) >= 1, "handoff deterministically preempts lower priority cue")
	_check((audit.authority as Dictionary).crew_roles == false, "audio binding owns no crew authority")
	_check(bool(binding.detach().accepted), "detach clears crew presentation")
	_check(binding.present_crew_snapshot(base).reason == &"not_attached", "detached binding rejects snapshots")
	for failure in _failures:
		push_error(failure)
	print("halyard_crew_semantic_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(occupants: Array, ready: bool, engineer: Dictionary, handoff: Dictionary) -> Dictionary:
	return {
		"occupants": occupants,
		"departure_readiness": {"ready": ready},
		"power_routing": {"engineer": engineer},
		"emergency_pilot_handoff": handoff,
	}


func _occupant(peer_id: int, avatar_id: StringName, role: StringName) -> Dictionary:
	return {"occupant_peer_id": peer_id, "avatar_id": avatar_id, "role": role}


func _on_cue(cue_id: StringName, role: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "role": role, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
