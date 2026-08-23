extends SceneTree

const BindingScript := preload("res://scripts/audio/component_damage_audio_binding.gd")
const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")

var _events: Array[StringName] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := RigScene.instantiate() as ShipAudioRig
	root.add_child(rig)
	await process_frame
	rig.semantic_engine_cue_emitted.connect(_on_cue)
	var binding := BindingScript.new()
	_check(bool(binding.bind(rig).accepted), "damage binding accepts the existing ship audio rig")
	_check(bool(binding.present_damage_snapshot({"stage": &"degraded", "health_ratio": 0.7}).accepted), "degraded component state is presented")
	_check(_has_cue(&"engine_degraded"), "degradation changes the existing engine presentation")
	_check(bool(binding.present_damage_snapshot({"stage": &"critical", "health_ratio": 0.2}).accepted), "critical component state is presented")
	_check(_has_cue(&"engine_critical"), "critical state emits the existing engine alarm cue")
	_check(bool(binding.present_damage_snapshot({"stage": &"repaired", "health_ratio": 1.0}).accepted), "repair reset is presented")
	_check(_has_cue(&"engine_recovered"), "repair restores the engine presentation")
	_check((binding.get_snapshot().authority as Dictionary).damage == false, "binding owns no damage authority")
	_check(bool(binding.detach().accepted), "detach clears the damage presentation")
	_check(binding.present_damage_snapshot({"stage": &"critical", "health_ratio": 0.1}).reason == &"not_attached", "detached binding rejects stale damage")
	_check(bool(binding.bind(rig).accepted), "binding re-enters with the same rig")
	_check(bool(binding.present_damage_snapshot({"stage": &"nominal", "health_ratio": 1.0, "reset": true}).accepted), "re-entry accepts a neutral reset")
	_check(binding.get_snapshot().last_degradation == 0.0, "re-entry retains neutral audio state")
	rig.queue_free()
	for failure in _failures:
		push_error(failure)
	print("component_damage_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(cue_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)


func _has_cue(cue_id: StringName) -> bool:
	return _events.has(cue_id)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
