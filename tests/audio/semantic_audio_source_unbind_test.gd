extends SceneTree

const Router := preload("res://scripts/audio/semantic_audio_cue_router.gd")
const Director := preload("res://scripts/audio/audio_director.gd")

class MockSource:
	## Minimal source contract for the router's existing combat/music kinds.
	extends Node
	signal semantic_cue_emitted(cue_id: StringName, world_position: Vector3, intensity: float)
	signal semantic_music_cue_emitted(cue_id: StringName, intensity: float)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var router := Router.new()
	var source := MockSource.new()
	var other := MockSource.new()
	root.add_child(router)
	root.add_child(source)
	root.add_child(other)
	router.semantic_cue_emitted.connect(_on_cue)
	_check(bool(router.bind_source(source, &"combat").accepted), "combat source binds")
	_check(bool(router.bind_source(other, &"music").accepted), "music source binds")
	_check(bool(router.unbind_source(source, &"combat").accepted), "exact source unbinds")
	_check(router.get_binding_count() == 1, "other source remains registered")
	source.semantic_cue_emitted.emit(&"removed", Vector3.ZERO, 1.0)
	other.semantic_music_cue_emitted.emit(&"retained", 1.0)
	_check(_events.size() == 1 and _events[0].cue_id == &"retained", "only retained source reaches router")
	_check(router.unbind_source(source, &"combat").reason == &"source_not_bound", "repeated unbind is stale-rejected")
	_check(router.unbind_source(other, &"combat").reason == &"source_kind_mismatch", "wrong source kind is rejected")
	_check(bool(router.bind_source(source, &"combat").accepted), "unbound source can rebind")
	_check(router.unbind_source(source, &"music").reason == &"source_kind_mismatch", "rebound source still fences kind")

	var director := Director.new()
	root.add_child(director)
	await process_frame
	var director_source := MockSource.new()
	root.add_child(director_source)
	_check(bool(director.bind_semantic_audio_source(director_source, &"combat").accepted), "AudioDirector binds source")
	_check(bool(director.unbind_semantic_audio_source(director_source, &"combat").accepted), "AudioDirector unbinds exact source")
	_check(director.get_semantic_audio_binding_count() == 0, "AudioDirector retains no stale source")
	_check(director.unbind_semantic_audio_source(director_source, &"combat").reason == &"source_not_bound", "AudioDirector stale unbind is idempotent")
	for failure in _failures:
		push_error(failure)
	print("SEMANTIC_AUDIO_SOURCE_UNBIND_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
