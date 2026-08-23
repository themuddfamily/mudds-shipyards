extends SceneTree

const Binding := preload("res://scripts/audio/hero_fleet_audio_binding.gd")
const HeroScene := preload("res://scenes/ships/torrent_interceptor.tscn")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroScene.instantiate() as Node
	root.add_child(hero)
	await process_frame
	var rig := hero.get_node("ShipAudioRig") as Node
	var binding := Binding.new()
	_check(bool(binding.bind(&"torrent_interceptor", rig).accepted), "baseline hero rig binds")
	rig.semantic_engine_cue_emitted.connect(_on_cue)
	_check(bool(binding.present_component_damage({"stage": &"degraded", "health_ratio": 0.65}).accepted), "degraded state reaches hero rig")
	_check(bool(binding.present_component_damage({"stage": &"critical", "health_ratio": 0.2}).accepted), "critical state reaches hero rig")
	_check(_events.has(&"engine_critical"), "hero rig emits critical engine cue")
	_check(bool(binding.present_component_damage({"stage": &"repaired", "health_ratio": 1.0}).accepted), "repair reset reaches hero rig")
	_check(_events.has(&"engine_recovered"), "hero rig emits recovery cue")
	_check(binding.bind(&"second", rig).reason == &"already_bound", "active binding cannot be replaced")
	_check(bool(binding.detach().accepted), "hero audio binding detaches")
	_check(binding.get_snapshot().generation == 1, "detach advances generation")
	_check((binding.get_snapshot().component_damage as Dictionary).is_empty(), "detach clears damage bridge")
	_check(bool(binding.bind(&"torrent_interceptor", rig).accepted), "hero audio binding re-enters")
	_check(bool((binding.get_snapshot().component_damage as Dictionary).attached), "re-entry restores damage bridge")
	_check(bool(binding.detach().accepted), "re-entry detaches cleanly")
	hero.queue_free()
	for failure in _failures:
		push_error(failure)
	print("hero_fleet_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _on_cue(cue_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)
