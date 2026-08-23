extends SceneTree

## Focused production check for the outdoor wind state reaching the existing
## authored exterior wind loop. The Dummy driver keeps native audibility NOT_RUN.

const PolicyScript := preload("res://scripts/world/planetary_surface_audio_policy.gd")
const BindingScene := preload("res://scenes/audio/planetary_surface_audio_playback_binding.tscn")
const Catalog := preload("res://assets/audio/planetary/temperate_surface_audio_catalog.tres")
const Atmosphere := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScene.instantiate()
	root.add_child(binding)
	await process_frame
	_check(bool(binding.configure(Catalog).accepted), "binding accepts the authored surface catalog")
	var policy := PolicyScript.new()
	_check(bool(policy.configure(Atmosphere).accepted), "surface policy accepts Aurora's atmosphere")
	var profile_id: StringName = policy.get_snapshot().profile_id
	var attachment: Dictionary = binding.attach(profile_id, 1001, 7, 11, binding.get_attachment_generation())
	_check(bool(attachment.accepted), "binding accepts the caller-owned surface attachment")
	var generation: int = binding.get_attachment_generation()
	var calm := policy.evaluate(_observation(0.0))
	var windy := policy.evaluate(_observation(1.0))
	var calm_result: Dictionary = binding.present_policy_result(calm, 0.75, generation, 1001, 7, 11)
	_check(
		bool(calm_result.accepted),
		"calm exterior policy reaches the playback adapter"
	)
	var calm_snapshot: Dictionary = binding.get_state_snapshot()
	_check(
		float((calm_snapshot.fade as Dictionary).wind_gain_db) == -80.0,
		"calm exterior keeps the wind contribution silent"
	)
	var windy_result: Dictionary = binding.present_policy_result(windy, 0.75, generation, 1001, 7, 11)
	_check(
		bool(windy_result.accepted),
		"windy exterior policy reaches the playback adapter"
	)
	var windy_snapshot: Dictionary = binding.get_state_snapshot()
	var windy_fade := windy_snapshot.fade as Dictionary
	var windy_voice := (windy_snapshot.voices as Dictionary).exterior as Dictionary
	_check(
		float(windy_fade.wind_gain_db) <= -9.0
		and float(windy_fade.wind_gain_db) > -80.0
		and float(windy_voice.effective_linear_gain) > 0.0,
		"wind intensity modulates the authored exterior wind loop without a new voice"
	)
	_check(
		int((binding.get_audit_report().performance as Dictionary).maximum_simultaneous_voices) == 2,
		"wind modulation preserves the bounded two-voice playback ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("planetary_surface_audio_playback_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _observation(wind: float) -> Dictionary:
	return {
		"altitude_m": 0.0,
		"listener_context": &"exterior",
		"grounded": false,
		"speed_mps": 80.0,
		"ambient_wind_scalar_unitless": wind,
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
