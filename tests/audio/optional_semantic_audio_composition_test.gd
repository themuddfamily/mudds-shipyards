extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Composition := preload("res://scripts/audio/optional_semantic_audio_composition.gd")

class MockCinder:
	extends Node
	signal loadmaster_manifest_intent_accepted(receipt: Dictionary)
	signal loadmaster_manifest_cleared(generation: int, reason: StringName)

class MockCruise:
	extends Node
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)

class RetainedSource:
	extends Node
	signal semantic_music_cue_emitted(cue_id: StringName, intensity: float)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	var composition := Composition.new()
	var cinder := MockCinder.new()
	var cruise := MockCruise.new()
	var retained := RetainedSource.new()
	root.add_child(director)
	await process_frame
	root.add_child(composition)
	root.add_child(cinder)
	root.add_child(cruise)
	root.add_child(retained)
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(director.bind_semantic_audio_source(retained, &"music").accepted), "unrelated source binds")
	_check(bool(composition.attach(director, cinder, cruise).accepted), "optional composition attaches")
	_check(director.get_semantic_audio_binding_count() == 3, "three independent sources are registered")
	cinder.loadmaster_manifest_intent_accepted.emit({"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1, "request_sequence": 2, "manifest_id": &"m", "route_id": &"r", "ready": true})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed"}})
	_check(_has(&"cinder_loadmaster_manifest_ready") and _has(&"planetary_final_approach_armed"), "both optional sources route cues")
	_check(bool(composition.present_cinder_rejected({"reason": &"stale_sequence"}).accepted), "Cinder rejection forwards")
	_check(_has(&"cinder_loadmaster_rejected"), "Cinder rejection reaches director")
	var replacement := MockCinder.new()
	root.add_child(replacement)
	_check(bool(composition.set_sources(replacement, null).accepted), "ship replacement unbinds old sources")
	_check(director.get_semantic_audio_binding_count() == 2, "replacement retains unrelated source only")
	retained.semantic_music_cue_emitted.emit(&"retained_music", 1.0)
	_check(_has(&"retained_music"), "unrelated source survives replacement")
	_check(bool(composition.detach().accepted), "composition detaches")
	_check(director.get_semantic_audio_binding_count() == 1, "composition detach preserves unrelated source")
	for failure in _failures:
		push_error(failure)
	print("OPTIONAL_SEMANTIC_AUDIO_COMPOSITION_TEST: %d assertions" % _assertions)
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
