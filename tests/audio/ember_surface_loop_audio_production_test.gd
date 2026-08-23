extends SceneTree

const ProductionBinding := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const AudioBinding := preload("res://scripts/audio/ember_surface_loop_audio_production_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := ProductionBinding.new()
	var audio := AudioBinding.new()
	root.add_child(owner)
	root.add_child(audio)
	audio.semantic_surface_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach(owner, &"interior").accepted), "real Ember production owner attaches")
	owner.state_changed.emit({"generation": 1, "state_id": &"running"})
	owner.state_changed.emit({"generation": 1, "state_id": &"descent"})
	owner.state_changed.emit({"generation": 1, "state_id": &"landed"})
	owner.state_changed.emit({"generation": 1, "state_id": &"on_foot"})
	_check(_has(&"ember_surface_descent_interior") and _has(&"ember_surface_landed_interior") and _has(&"ember_surface_on_foot_interior"), "descent/landing/on-foot cues emit")
	_check(audio.present_snapshot({"generation": 0, "state_id": &"takeoff"}).reason == &"stale_generation", "stale generation is rejected")
	_check(bool(audio.set_perspective(&"exterior").accepted), "exterior perspective is accepted")
	owner.state_changed.emit({"generation": 2, "state_id": &"reboarded"})
	owner.state_changed.emit({"generation": 2, "state_id": &"takeoff"})
	owner.state_changed.emit({"generation": 2, "state_id": &"ascent"})
	owner.state_changed.emit({"generation": 2, "state_id": &"orbit_return"})
	_check(_has(&"ember_surface_reboard_exterior") and _has(&"ember_surface_orbit_return_exterior"), "reboard/takeoff/ascent/orbit-return cues emit")
	owner.state_changed.emit({"generation": 2, "state_id": &"failed", "terminal_reason": &"caller_aborted"})
	_check(_has(&"ember_surface_abort_exterior"), "abort cue emits")
	owner.state_changed.emit({"generation": 2, "state_id": &"takeoff"})
	_check(_events.size() == 8, "duplicate phase is suppressed")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "two-voice ceiling is retained")
	_check(bool(audio.detach().accepted), "surface audio detaches")
	_check(bool(audio.attach(owner, &"exterior").accepted), "surface audio re-enters")
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURFACE_LOOP_AUDIO_PRODUCTION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(cue_id: StringName, intensity: float) -> void:
	_events.append(cue_id)

func _has(cue_id: StringName) -> bool:
	return _events.has(cue_id)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
