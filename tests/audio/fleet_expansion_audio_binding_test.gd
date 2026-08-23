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
	var rebind_result: Dictionary = binding.bind(&"lightweight_interceptor", rig)
	_check(bool(rebind_result.accepted), "detached binding can reuse the same rig (%s)" % rebind_result.reason)
	_check(not bool(binding.get_snapshot().reduced_dynamic_range), "re-entry resets caller mix policy")
	var reentry_damage: Dictionary = binding.get_snapshot().component_damage
	_check(bool(reentry_damage.get("attached", false)), "re-entry restores component damage binding")
	_check(int(binding.get_snapshot().plan_build_count) == 2, "detach and reuse keep cached plans")
	_check(bool(binding.detach().accepted), "reused binding detaches cleanly")
	var foreign := Node.new()
	_check(binding.bind(&"cargo_craft", foreign).reason == &"foreign_audio_rig", "foreign rig is rejected")
	foreign.free()
	var bomber_rig := RigScene.instantiate() as Node
	bomber_rig.set("profile_id", &"standard_fighter")
	root.add_child(bomber_rig)
	await process_frame
	var bomber_binding := Binding.new()
	bomber_binding.semantic_engine_cue_emitted.connect(_on_cue)
	_check(bool(bomber_binding.bind(&"bomber", bomber_rig).accepted), "bomber profile binds payload audio")
	_check(bool(bomber_binding.set_reduced_dynamic_range(true).accepted), "bomber payload mix follows reduced range")
	_check(bool(bomber_binding.present_payload_release({"generation": 0, "request_sequence": 1, "payload_id": &"cinder_payload_alpha"}).accepted), "accepted bomber release reaches composed audio")
	_check(bool(bomber_binding.present_payload_abort({"generation": 0, "request_sequence": 2, "payload_id": &"cinder_payload_alpha"}).accepted), "accepted bomber abort reaches composed audio")
	_check(_events.has(&"bomber_payload_release") and _events.has(&"bomber_payload_abort"), "composed payload cues reach the fleet audio signal")
	_check(bomber_binding.present_payload_release({"generation": 0, "request_sequence": 2, "payload_id": &"cinder_payload_alpha"}).reason == &"duplicate_sequence", "payload sequence fence rejects duplicates")
	_check(bool(bomber_binding.detach().accepted), "bomber payload composition detaches")
	_check(bool(bomber_binding.bind(&"bomber", bomber_rig).accepted), "bomber payload composition re-enters")
	_check(bool(bomber_binding.present_payload_release({"generation": 1, "request_sequence": 1, "payload_id": &"cinder_payload_alpha"}).accepted), "payload generation resets on re-entry")
	_check(bool(bomber_binding.detach().accepted), "bomber payload composition final detach")
	bomber_rig.queue_free()
	rig.queue_free()
	await process_frame
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
