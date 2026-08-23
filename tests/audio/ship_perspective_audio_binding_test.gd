extends SceneTree

const Binding := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const HalyardScene := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var halyard := HalyardScene.instantiate() as Node
	root.add_child(halyard)
	await process_frame
	await process_frame
	var rig := halyard.get_node("ShipAudioRig") as ShipAudioRig
	var binding := Binding.new()
	_check(bool(binding.bind(rig).accepted), "production Halyard scene binds its resident audio rig")
	_check(binding.get_snapshot().authority.camera == false, "perspective binding owns no camera authority")
	_check(rig.set_engine_running(true, false), "Halyard rig accepts engine state for the mix fixture")
	_check(rig.set_thrust_state(0.5), "Halyard rig accepts thrust for the mix fixture")
	var exterior := rig.get_perspective_mix_snapshot()
	var generation: int = binding.get_snapshot().generation
	_check(bool(binding.present_perspective(Binding.PERSPECTIVE_COCKPIT, generation).accepted), "occupied-cabin perspective reaches the Halyard rig")
	var cockpit := rig.get_perspective_mix_snapshot()
	_check(
		cockpit.perspective == Binding.PERSPECTIVE_COCKPIT
			and float(cockpit.gain_db) < float(exterior.gain_db)
			and float(cockpit.filter_cutoff_hz) < float(exterior.filter_cutoff_hz),
		"cockpit perspective applies the bounded interior mix/filter"
	)
	_check(binding.present_perspective(Binding.PERSPECTIVE_COCKPIT, generation).reason == &"unchanged", "duplicate cockpit state is deduplicated")
	_check(binding.present_perspective(Binding.PERSPECTIVE_EXTERIOR, generation).accepted, "chase perspective restores exterior mix")
	_check(binding.present_perspective(&"invalid", generation).reason == &"invalid_perspective", "invalid perspective fails closed")
	_check(bool(binding.detach().accepted), "detach clears the perspective binding")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "detach resets the Halyard rig to exterior")
	_check(binding.present_perspective(Binding.PERSPECTIVE_COCKPIT, generation).reason == &"not_attached", "detached binding rejects stale perspective")
	_check(bool(binding.bind(rig).accepted), "the same Halyard rig can be rebound")
	_check(binding.get_snapshot().generation == 1, "re-entry advances the binding generation")
	_check(binding.present_perspective(Binding.PERSPECTIVE_COCKPIT, 0).reason == &"stale_generation", "old generation cannot mutate re-entry")
	_check(bool(binding.present_perspective(Binding.PERSPECTIVE_COCKPIT, 1).accepted), "current generation restores cockpit perspective")
	_check(int(rig.get_performance_report().maximum_simultaneous_voices) == 6, "perspective binding preserves the six-voice ceiling")
	_check(rig.get_audit_report().valid, "Halyard perspective mix remains auditable")
	_check(bool(binding.detach().accepted), "re-entry detaches cleanly")
	halyard.queue_free()
	for failure in _failures:
		push_error(failure)
	print("ship_perspective_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
