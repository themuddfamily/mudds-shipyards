extends SceneTree

const RouterScript := preload("res://scripts/audio/semantic_audio_cue_router.gd")
const BindingScript := preload("res://scripts/audio/halyard_crew_semantic_audio_binding.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var router := RouterScript.new()
	var source := BindingScript.new()
	root.add_child(router)
	root.add_child(source)
	router.semantic_cue_emitted.connect(_on_cue)
	_check(bool(source.attach().accepted), "crew source attaches")
	_check(bool(router.bind_source(source, &"crew").accepted), "crew source binds")
	var joined := _snapshot([_occupant(2, &"crew_a", &"engineer")], false, {}, {})
	_check(bool(source.present_crew_snapshot(joined).accepted), "joined snapshot reaches router")
	_check(_has_cue(&"crew", &"crew_engineer_joined"), "role label is normalized")
	var count := _events.size()
	_check(bool(source.present_crew_snapshot(joined).accepted), "duplicate crew snapshot is accepted")
	_check(_events.size() == count, "router and source deduplicate repeated crew state")
	var handoff := _snapshot(
		[_occupant(2, &"crew_a", &"engineer")], true, {"channel": &"mobility", "component_generation": 2},
		{"authority_event_sequence": 5, "new_seat_generation": 3}
	)
	_check(bool(source.present_crew_snapshot(handoff).accepted), "handoff snapshot reaches router")
	_check(_has_cue(&"crew", &"crew_engineer_route_changed"), "engineer route label is normalized")
	_check(_has_cue(&"crew", &"crew_departure_ready"), "departure label is normalized")
	_check(_has_cue(&"crew", &"crew_emergency_pilot_handoff"), "handoff label is normalized")
	_check(
		_events.all(func(event): return event.source_id == &"crew" and event.cue_id is StringName \
			and event.intensity is float and event.position == Vector3.ZERO),
		"crew payload remains typed and bounded"
	)
	_check(bool(router.detach().accepted), "router detaches crew source")
	_check(router.get_binding_count() == 0, "detach clears crew binding")
	_check(bool(router.bind_source(source, &"crew").accepted), "crew source rebinds")
	for failure in _failures:
		push_error(failure)
	print("halyard_crew_semantic_audio_router_test: %d assertions" % _assertions)
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


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})


func _has_cue(source_id: StringName, cue_id: StringName) -> bool:
	for event in _events:
		if event.source_id == source_id and event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
