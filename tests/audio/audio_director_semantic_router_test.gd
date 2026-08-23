extends SceneTree

class MockAudioSource:
	extends Node
	signal semantic_music_cue_emitted(cue_id: StringName, intensity: float)

	func emit_music(cue_id: StringName, intensity: float) -> void:
		semantic_music_cue_emitted.emit(cue_id, intensity)


const Director := preload("res://scripts/audio/audio_director.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := Director.new()
	var source := MockAudioSource.new()
	root.add_child(director)
	director.add_child(source)
	director.semantic_cue_emitted.connect(_on_cue)
	await process_frame
	_check(director.get_semantic_audio_binding_count() == 0, "production director starts detached")
	_check(
		bool(director.bind_semantic_audio_source(source, &"music").accepted),
		"director binds a caller-owned music source"
	)
	source.emit_music(&"music_landing", 0.5)
	source.emit_music(&"music_landing", 0.5)
	_check(_events.size() == 1, "director forwards one deduplicated normalized cue")
	_check(
		_events[0].source_id == &"music"
		and _events[0].cue_id == &"music_landing"
		and is_equal_approx(float(_events[0].intensity), 0.5),
		"director preserves normalized cue metadata"
	)
	_check(director.get_semantic_audio_binding_count() == 1, "director retains the binding")
	_check(bool(director.detach_semantic_audio_sources().accepted), "director detaches semantic sources")
	source.emit_music(&"music_landing", 0.5)
	_check(_events.size() == 1 and director.get_semantic_audio_binding_count() == 0, "detach clears forwarding")
	_check(bool(director.bind_semantic_audio_source(source, &"music").accepted), "re-entry can bind a fresh source")
	source.emit_music(&"music_landing", 0.5)
	_check(_events.size() == 2, "fresh attachment forwards after detach")
	for failure in _failures:
		push_error(failure)
	print("audio_director_semantic_router_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3) -> void:
	_events.append({
		"source_id": source_id,
		"cue_id": cue_id,
		"intensity": intensity,
		"world_position": world_position,
	})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
