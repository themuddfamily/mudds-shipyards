extends SceneTree

const HeroScene := preload("res://scenes/ships/torrent_interceptor.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroScene.instantiate() as Node
	root.add_child(hero)
	await process_frame
	await process_frame
	var rig := hero.get_node("ShipAudioRig") as ShipAudioRig
	_check(rig != null, "production HeroShip scene owns a ShipAudioRig")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "neutral perspective is exterior")
	_check(rig.set_engine_running(true, false), "engine accepts caller-owned running state")
	_check(rig.set_thrust_state(0.5), "engine accepts a neutral throttle fixture")
	var idle := rig.get_node("ThrustIdle") as AudioStreamPlayer3D
	var exterior_volume := idle.volume_db
	var exterior_pitch := idle.pitch_scale
	var exterior_mix: Dictionary = rig.get_perspective_mix_snapshot()
	_check(rig.set_audio_perspective(ShipAudioRig.PERSPECTIVE_COCKPIT), "cockpit perspective is accepted")
	var cockpit_mix: Dictionary = rig.get_perspective_mix_snapshot()
	_check(
		cockpit_mix.perspective == ShipAudioRig.PERSPECTIVE_COCKPIT
			and float(cockpit_mix.gain_db) < float(exterior_mix.gain_db)
			and float(cockpit_mix.filter_cutoff_hz) < float(exterior_mix.filter_cutoff_hz),
		"cockpit applies bounded attenuation and a lower filter cutoff"
	)
	_check(idle.volume_db < exterior_volume and idle.pitch_scale < exterior_pitch, "cockpit mix reaches the resident engine voice")
	_check(not rig.set_audio_perspective(ShipAudioRig.PERSPECTIVE_COCKPIT), "repeating perspective is deduplicated")
	_check(not rig.set_audio_perspective(&"invalid"), "unknown perspective fails closed")
	_check(rig.set_audio_perspective(ShipAudioRig.PERSPECTIVE_EXTERIOR), "exterior perspective can be restored")
	_check(
		rig.get_perspective_mix_snapshot().filter_cutoff_hz == ShipAudioRig.ATTENUATION_FILTER_CUTOFF_HZ,
		"exterior restores the authored attenuation filter"
	)
	_check(rig.set_audio_perspective(ShipAudioRig.PERSPECTIVE_COCKPIT), "cockpit can be re-entered")
	_check(rig.set_reduced_dynamic_range(true), "reduced dynamic range remains caller-driven")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_COCKPIT, "reduced range preserves perspective")
	_check(int(rig.get_performance_report().maximum_simultaneous_voices) == 6, "perspective does not add voices")
	_check(rig.get_audit_report().valid, "perspective mix remains auditable")
	rig.release_audio_resources()
	_check(not rig.is_rig_enabled(), "detach disables the rig")
	rig.set_rig_enabled(true)
	await process_frame
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_COCKPIT, "re-entry retains caller perspective")
	_check(rig.is_reduced_dynamic_range(), "re-entry retains reduced-range policy")
	_check(rig.get_audit_report().valid, "re-entry rebuilds a valid perspective mix")
	_check(rig.get_state_snapshot().audio_perspective == ShipAudioRig.PERSPECTIVE_COCKPIT, "state snapshot exposes perspective")
	hero.queue_free()
	for failure in _failures:
		push_error(failure)
	print("ship_audio_perspective_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
