extends SceneTree

const GameFlow := preload("res://scripts/game/game_flow.gd")
const Director := preload("res://scripts/audio/audio_director.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var flow := GameFlow.new()
	var director := Director.new()
	var cinder := Cinder.new()
	root.add_child(director)
	root.add_child(cinder)
	await process_frame
	flow.audio = director
	flow.active_ship = cinder
	director.semantic_cue_emitted.connect(_on_cue)
	flow._initialize_optional_semantic_audio()
	_check(is_instance_valid(flow.optional_semantic_audio_composition), "GameFlow creates optional audio composition")
	_check(director.get_semantic_audio_binding_count() == 1, "GameFlow binds Cinder as one crew source")
	cinder.loadmaster_manifest_intent_accepted.emit({"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1, "request_sequence": 3, "manifest_id": &"m", "route_id": &"r", "ready": true})
	_check(_has(&"cinder_loadmaster_manifest_ready"), "GameFlow-composed Cinder accepted cue reaches AudioDirector")
	flow._on_network_crew_command_result({"accepted": false, "reason": &"stale_sequence", "request_sequence": 4})
	_check(_has(&"cinder_loadmaster_rejected"), "GameFlow forwards authoritative Cinder rejection")
	flow._detach_optional_semantic_audio()
	_check(director.get_semantic_audio_binding_count() == 0, "GameFlow detaches only its optional source")
	flow.queue_free()
	director.queue_free()
	cinder.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("GAME_FLOW_OPTIONAL_SEMANTIC_AUDIO_INTEGRATION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
