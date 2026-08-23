extends SceneTree

const Binding := preload("res://scripts/audio/fleet_expansion_audio_binding.gd")
const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")

var _assertions := 0
var _failures := PackedStringArray()


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
	_check((binding.get_snapshot().authority as Dictionary).flight == false, "binding owns no flight authority")
	_check(binding.bind(&"cargo_craft", rig).reason == &"already_bound", "rebind cannot replace active caller binding")
	_check(bool(binding.detach().accepted), "detach releases rig association")
	_check(binding.get_snapshot().generation == 1, "detach advances binding generation")
	_check(bool(binding.bind(&"lightweight_interceptor", rig).accepted), "detached binding can reuse the same rig")
	_check(not bool(binding.get_snapshot().reduced_dynamic_range), "re-entry resets caller mix policy")
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
