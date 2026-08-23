extends SceneTree

const Contract := preload("res://scripts/audio/dynamic_audio_mix.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	var mix := Contract.new()
	mix.configure_layers({&"combat": 1.0})
	var baseline := mix.get_mix_plan().layers as Dictionary
	_check(mix.set_reduced_dynamic_range(true).accepted, "reduced-range mode is caller-configurable")
	var reduced := mix.get_mix_plan().layers as Dictionary
	_check(
		float(reduced.station.gain) < float(baseline.station.gain)
		and float(reduced.combat.gain) < float(baseline.combat.gain),
		"reduced range attenuates authored ambience and combat layers"
	)
	_check(
		int(reduced.station.voice_ceiling) == 8
		and int(reduced.combat.voice_ceiling) == 10,
		"reduced range preserves fixed layer voice ceilings"
	)
	_check(bool(mix.get_snapshot().reduced_dynamic_range), "mode is exposed in detached state")
	var snapshot := mix.get_snapshot()
	var restored := Contract.new()
	_check(restored.restore(snapshot), "reduced-range state restores without playback authority")
	_check(
		bool(restored.get_mix_plan().reduced_dynamic_range)
		and not bool(restored.get_mix_plan().playback_authority),
		"restored mode remains presentation-only"
	)
	_check(bool(restored.set_reduced_dynamic_range(false).accepted), "mode can return to neutral")
	for failure in _failures:
		push_error(failure)
	print("reduced_dynamic_range_mix_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
