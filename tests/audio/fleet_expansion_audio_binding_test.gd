extends SceneTree

const Binding := preload("res://scripts/audio/fleet_expansion_audio_binding.gd")
const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := RigScene.instantiate() as Node
	rig.set("profile_id", &"efficient_twin_recon")
	root.add_child(rig)
	await process_frame
	var binding := Binding.new()
	_check(bool(binding.bind(&"lightweight_interceptor", rig).accepted), "matching caller ship and rig bind")
	var baseline := binding.get_snapshot()
	_check(float(baseline.applied_plan.engine_pitch_scale) == 1.24, "recipe applies interceptor pitch")
	_check(bool(binding.set_reduced_dynamic_range(true).accepted), "reduced dynamic range applies")
	_check(float(binding.get_snapshot().applied_plan.boost_volume_db) < float(baseline.applied_plan.boost_volume_db), "reduced range attenuates boost")
	for _index in 12:
		_check(bool(binding.set_reduced_dynamic_range(true).accepted), "repeated reduced-range update remains stable")
	var hot_path_audit: Dictionary = binding.get_snapshot().audit
	_check(int(hot_path_audit.plan_build_count) == 2, "nominal and reduced plans are built once")
	_check(int(hot_path_audit.plan_cache_entries) == 2, "plan cache retains both immutable mix plans")
	_check(bool(hot_path_audit.player_count_stable), "repeated updates allocate no new rig players")
	_check(bool(hot_path_audit.resource_generation_stable), "repeated updates synthesize no new resources")
	_check((binding.get_snapshot().authority as Dictionary).flight == false, "binding owns no flight authority")
	rig.semantic_engine_cue_emitted.connect(_on_cue)
	_check(bool(binding.present_component_damage({"stage": &"degraded", "health_ratio": 0.7}).accepted), "degraded component damage reaches rig")
	_check(bool(binding.present_component_damage({"stage": &"critical", "health_ratio": 0.2}).accepted), "critical component damage reaches rig")
	_check(_events.has(&"engine_critical"), "critical damage emits the existing engine cue")
	_check(bool(binding.present_component_damage({"stage": &"repaired", "health_ratio": 1.0}).accepted), "repair reset reaches rig")
	_check(_events.has(&"engine_recovered"), "repair emits the existing recovery cue")
	_check(binding.bind(&"cargo_craft", rig).reason == &"already_bound", "rebind cannot replace active caller binding")
	_check(bool(binding.detach().accepted), "detach releases rig association")
	_check(binding.get_snapshot().generation == 1, "detach advances binding generation")
	_check((binding.get_snapshot().component_damage as Dictionary).is_empty(), "detach clears component damage binding")
	_check(bool(binding.bind(&"lightweight_interceptor", rig).accepted), "detached binding can reuse the same rig")
	_check(not bool(binding.get_snapshot().reduced_dynamic_range), "re-entry resets caller mix policy")
	_check(bool((binding.get_snapshot().component_damage as Dictionary).attached), "re-entry restores component damage binding")
	_check(int(binding.get_snapshot().plan_build_count) == 2, "detach and reuse keep cached plans")
	_check(bool(binding.detach().accepted), "reused binding detaches cleanly")
	var foreign := Node.new()
	_check(binding.bind(&"cargo_craft", foreign).reason == &"foreign_audio_rig", "foreign rig is rejected")
	foreign.free()
	rig.queue_free()
	for failure in _failures:
		push_error(failure)
	print("fleet_expansion_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _on_cue(cue_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)
