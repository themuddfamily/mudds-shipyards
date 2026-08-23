extends SceneTree

const PolicyScript := preload("res://scripts/world/planetary_surface_audio_policy.gd")
const BindingScene := preload("res://scenes/audio/planetary_surface_audio_playback_binding.tscn")
const Catalog := preload("res://assets/audio/planetary/temperate_surface_audio_catalog.tres")
const Atmosphere := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScene.instantiate()
	root.add_child(binding)
	binding.semantic_surface_cue_emitted.connect(_on_cue)
	await process_frame
	_check(bool(binding.configure(Catalog).accepted), "binding configures the authored catalog")
	var policy := PolicyScript.new()
	_check(bool(policy.configure(Atmosphere).accepted), "surface policy configures")
	var profile_id: StringName = policy.get_snapshot().profile_id
	_check(bool(binding.attach(profile_id, 1001, 7, 11, binding.get_attachment_generation()).accepted), "surface attachment is accepted")
	var generation: int = binding.get_attachment_generation()
	var severe := policy.evaluate(_observation(&"exterior", 2000.0, 1.0))
	_check(bool(binding.present_policy_result(severe, 0.75, generation, 1001, 7, 11).accepted), "severe state is accepted")
	var count_after_first := _events.size()
	_check(count_after_first <= 2, "severe state emits bounded semantic cues")
	_check(bool(binding.present_policy_result(severe, 0.75, generation, 1001, 7, 11).accepted), "repeated state is accepted")
	_check(_events.size() == count_after_first, "repeated severe state emits no spam")
	var cabin := policy.evaluate(_observation(&"cabin", 0.0, 0.0))
	_check(bool(binding.present_policy_result(cabin, 0.75, generation, 1001, 7, 11).accepted), "cabin transition is accepted")
	_check(_has_cue(&"surface_cabin_entered"), "cabin entry emits a typed transition cue")
	_check(_events.all(func(event): return event.cue_id is StringName and event.intensity is float), "semantic payload has no free text")
	for failure in _failures:
		push_error(failure)
	print("planetary_surface_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _observation(context: StringName, speed: float, wind: float) -> Dictionary:
	return {"altitude_m": 0.0, "listener_context": context, "grounded": false, "speed_mps": speed, "ambient_wind_scalar_unitless": wind}


func _on_cue(cue_id: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
