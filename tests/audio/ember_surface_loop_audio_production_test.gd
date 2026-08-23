extends SceneTree

const ProductionBinding := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const AudioBinding := preload("res://scripts/audio/ember_surface_loop_audio_production_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []

class FakeEmberRoot:
	extends Node3D
	func get_world_id() -> StringName: return &"ember_moon"

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
	_check(_has(&"ember_surface_descent_interior"), "production running state maps to descent cue")
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
	var ember_root := FakeEmberRoot.new()
	ember_root.position = Vector3(400.0, -250.0, 90.0)
	root.add_child(ember_root)
	var orbital := _altitude_snapshot(3, ember_root, 20_000.0, 12.0, &"descent")
	var low_descent := _altitude_snapshot(3, ember_root, 5_000.0, 12.0, &"descent")
	var surface := _altitude_snapshot(3, ember_root, 0.0, 12.0, &"descent")
	_check(bool(audio.present_snapshot(orbital).accepted), "exact orbital ceiling is presented")
	var orbital_mix := audio.get_snapshot().altitude_transition as Dictionary
	_check(
		orbital_mix.surface_proximity_unitless == 0.0
			and orbital_mix.target_intensity_unitless == 0.0,
		"the airless hull loop is exactly silent at the 20 km ceiling"
	)
	_check(bool(audio.present_snapshot(low_descent).accepted), "same-phase low descent updates continuously")
	var low_mix := audio.get_snapshot().altitude_transition as Dictionary
	_check(
		float(low_mix.surface_proximity_unitless) > 0.0
			and float(low_mix.target_intensity_unitless) > 0.0
			and bool(low_mix.playback_requested)
			and int(low_mix.voice_instance_id) > 0
			and int(low_mix.stream_instance_id) != 0,
		"descent proximity raises a live bounded hull-resonance loop"
	)
	_check(bool(audio.present_snapshot(surface).accepted), "surface-proximate descent is presented")
	var surface_mix := audio.get_snapshot().altitude_transition as Dictionary
	_check(
		float(surface_mix.target_intensity_unitless) > float(low_mix.target_intensity_unitless),
		"hull resonance increases monotonically toward Ember's surface datum"
	)
	_check(
		not bool(surface_mix.has_atmosphere)
			and surface_mix.fog_factor_unitless == 0.0
			and surface_mix.cloud_factor_unitless == 0.0
			and surface_mix.wind_gain_unitless == 0.0,
		"Ember's checked-in airless contract keeps fog, clouds, and wind at exact zero"
	)
	var on_foot := _altitude_snapshot(3, ember_root, 0.0, 0.0, &"on_foot", &"player")
	_check(bool(audio.present_snapshot(on_foot).accepted), "on-foot surface observation is presented")
	_check(
		audio.get_snapshot().altitude_transition.target_intensity_unitless == 0.0,
		"leaving the ship removes the presentation-only hull resonance"
	)
	_check(bool(audio.detach().accepted), "surface audio detaches")
	_check(
		audio.get_snapshot().altitude_transition.intensity_unitless == 0.0
			and not bool(audio.get_snapshot().altitude_transition.playback_requested),
		"detach silences the altitude loop without retaining lifecycle state"
	)
	_check(bool(audio.attach(owner, &"exterior").accepted), "surface audio re-enters")
	audio.detach()
	audio.free()
	owner.free()
	ember_root.free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURFACE_LOOP_AUDIO_PRODUCTION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(cue_id: StringName, intensity: float) -> void:
	_events.append(cue_id)

func _has(cue_id: StringName) -> bool:
	return _events.has(cue_id)

func _altitude_snapshot(
		generation: int,
		ember_root: Node3D,
		altitude_m: float,
		speed_mps: float,
		phase_id: StringName,
		actor_kind: StringName = &"ship"
	) -> Dictionary:
	return {
		"generation": generation,
		"phase_id": phase_id,
		"identities": {"loaded_scene_instance_id": ember_root.get_instance_id()},
		"last_prepared_evidence": {
			"delta": 0.25,
			"actor_sample": {
				"actor_kind": actor_kind,
				"position": ember_root.global_position + Vector3(0.0, 120_000.0 + altitude_m, 0.0),
			},
			"caller_kinematics": {"velocity_mps": Vector3(0.0, -speed_mps, 0.0)},
		},
	}.duplicate(true)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
