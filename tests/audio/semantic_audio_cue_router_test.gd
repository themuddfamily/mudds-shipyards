extends SceneTree

class MockAudioSource:
	extends Node
	signal semantic_cue_emitted(cue_id: StringName, world_position: Vector3, intensity: float)
	signal semantic_music_cue_emitted(cue_id: StringName, intensity: float)

	func emit_combat(cue_id: StringName, position: Vector3, intensity: float) -> void:
		semantic_cue_emitted.emit(cue_id, position, intensity)

	func emit_music(cue_id: StringName, intensity: float) -> void:
		semantic_music_cue_emitted.emit(cue_id, intensity)


const Router := preload("res://scripts/audio/semantic_audio_cue_router.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var router := Router.new()
	var source := MockAudioSource.new()
	var music_source := MockAudioSource.new()
	root.add_child(router)
	root.add_child(source)
	root.add_child(music_source)
	router.semantic_cue_emitted.connect(_on_cue)
	_check(bool(router.bind_source(source, &"combat").accepted), "combat source binds")
	_check(bool(router.bind_source(source, &"music").accepted) == false, "one source cannot bind twice")
	_check(bool(router.bind_source(music_source, &"music").accepted), "music source binds")
	_check(router.get_binding_count() == 2, "binding count is bounded")
	source.emit_combat(&"hull_impact_heavy", Vector3(2.0, 3.0, 4.0), 1.4)
	source.emit_combat(&"hull_impact_heavy", Vector3(2.0, 3.0, 4.0), 1.4)
	_check(_events.size() == 1, "repeated source cue is deduplicated")
	_check(
		_events[0].source_id == &"combat"
		and _events[0].cue_id == &"hull_impact_heavy"
		and is_equal_approx(float(_events[0].intensity), 1.0)
		and _events[0].world_position == Vector3(2.0, 3.0, 4.0),
		"combat cue is normalized with bounded intensity and position"
	)
	music_source.emit_music(&"music_landing", 0.5)
	_check(
		_events.size() == 2
		and _events[1].source_id == &"music"
		and _events[1].world_position == Vector3.ZERO,
		"scalar music cue is normalized with a neutral position"
	)
	_check(bool(router.detach().accepted), "detach clears router lifecycle")
	source.emit_combat(&"hull_impact_heavy", Vector3(2.0, 3.0, 4.0), 1.0)
	music_source.emit_music(&"music_landing", 0.5)
	_check(_events.size() == 2, "detached router receives no stale source cues")
	_check(router.get_binding_count() == 0, "detach clears bindings")
	for failure in _failures:
		push_error(failure)
	print("semantic_audio_cue_router_test: %d assertions" % _assertions)
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
