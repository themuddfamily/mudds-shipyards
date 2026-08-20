extends SceneTree

const Contract := preload("res://scripts/audio/dynamic_audio_mix.gd")
var _failures: Array[String] = []
var _assertions := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var mix := Contract.new()
	_check(bool(mix.audit().valid), "mix audit is valid")
	var initial := mix.get_mix_plan()
	_check(float((initial.layers as Dictionary)[&"station"].gain) > 0.0, "station layer starts audible")
	_check(float((initial.layers as Dictionary)[&"planetary"].gain) == 0.0, "planetary layer starts inactive")
	_check(int((initial.layers as Dictionary)[&"station"].voice_ceiling) == 8, "station voice ceiling is bounded")
	_check(int((initial.layers as Dictionary)[&"combat"].voice_ceiling) == 10, "combat voice ceiling is bounded")
	_check(bool(mix.configure_layers({&"planetary": 0.8, &"combat": 1.0}).accepted), "planetary/combat layers configure")
	_check(float((mix.get_mix_plan().layers as Dictionary)[&"combat"].gain) > 0.0, "combat layer is exposed")
	_check(bool(mix.set_ducking(&"planetary", 0.5).accepted), "planetary ducking configures")
	var ducked := float((mix.get_mix_plan().layers as Dictionary)[&"planetary"].gain)
	_check(is_equal_approx(ducked, 0.4), "ducking attenuates planetary layer")
	_check(bool(mix.configure_bus_ceilings({&"Weapons": -12.0}).accepted), "weapons ceiling configures")
	var combat_db := float((mix.get_mix_plan().layers as Dictionary)[&"combat"].gain_db)
	_check(combat_db <= -12.0, "combat gain respects bus ceiling")
	_check(bool(mix.set_accessibility_muted(true).accepted), "accessibility mute configures")
	var muted_layers := mix.get_mix_plan().layers as Dictionary
	_check(float(muted_layers[&"station"].gain) == 0.0 and float(muted_layers[&"combat"].gain) == 0.0, "accessibility mute silences all layers")
	_check(not bool(mix.get_mix_plan().playback_authority), "mix cannot grant playback authority")
	var snapshot := mix.get_snapshot()
	_check(mix.restore(snapshot), "detached mix snapshot restores")
	_check(bool(mix.configure_layers({&"unknown": 1.0}).accepted) == false, "unknown layer fails closed")
	_check(bool(mix.set_ducking(&"combat", INF).accepted) == false, "nonfinite ducking fails closed")
	_check(bool(mix.configure_bus_ceilings({&"Weapons": 2.0}).accepted) == false, "positive bus ceiling fails closed")
	print("dynamic_audio_mix_test: %d assertions passed" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error(message)
