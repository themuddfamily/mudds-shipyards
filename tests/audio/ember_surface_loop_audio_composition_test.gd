extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const ProductionBinding := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const Composition := preload("res://scripts/audio/ember_surface_loop_audio_composition.gd")

class RetainedPlanetarySource:
	extends Node
	signal semantic_surface_cue_emitted(cue_id: StringName, intensity: float)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	var owner := ProductionBinding.new()
	var retained := RetainedPlanetarySource.new()
	var composition := Composition.new()
	root.add_child(director)
	root.add_child(owner)
	root.add_child(retained)
	root.add_child(composition)
	await process_frame
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(director.bind_semantic_audio_source(retained, &"planetary").accepted), "existing planetary source binds")
	_check(bool(composition.attach(director, owner, &"interior").accepted), "real Ember production owner composes")
	_check(director.get_semantic_audio_binding_count() == 2, "composition adds one planetary source")
	owner.state_changed.emit({"generation": 1, "state_id": &"landed"})
	_check(_has(&"ember_surface_landed_interior"), "composed surface cue reaches AudioDirector")
	var binding_snapshot: Dictionary = composition.get_snapshot().get("binding", {}) as Dictionary
	_check(binding_snapshot.attached and int(binding_snapshot.maximum_simultaneous_voices) == 2, "composition retains one bounded adapter")
	_check(bool(composition.detach().accepted), "composition detaches")
	_check(director.get_semantic_audio_binding_count() == 1, "unrelated planetary source survives targeted detach")
	_check(bool(composition.attach(director, owner, &"exterior").accepted), "composition re-enters")
	_check(director.get_semantic_audio_binding_count() == 2, "re-entry registers exactly one source")
	owner.state_changed.emit({"generation": 2, "state_id": &"ascent"})
	_check(_has(&"ember_surface_ascent_exterior"), "re-entry cue reaches director")
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURFACE_LOOP_AUDIO_COMPOSITION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append(cue_id)

func _has(cue_id: StringName) -> bool:
	return _events.has(cue_id)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
