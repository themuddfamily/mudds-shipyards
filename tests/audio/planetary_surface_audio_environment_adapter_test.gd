extends SceneTree

const PolicyScript := preload("res://scripts/world/planetary_surface_audio_policy.gd")
const BindingScene := preload("res://scenes/audio/planetary_surface_audio_playback_binding.tscn")
const AdapterScript := preload("res://scripts/audio/planetary_surface_audio_environment_adapter.gd")
const Catalog := preload("res://assets/audio/planetary/temperate_surface_audio_catalog.tres")
const Atmosphere := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScene.instantiate()
	var adapter := AdapterScript.new()
	root.add_child(binding)
	root.add_child(adapter)
	await process_frame
	_check(bool(binding.configure(Catalog).accepted), "binding accepts the authored catalog")
	_check(bool(adapter.configure(binding).accepted), "adapter accepts the playback binding")
	var policy := PolicyScript.new()
	_check(bool(policy.configure(Atmosphere).accepted), "policy accepts the authored atmosphere")
	var profile_id: StringName = policy.get_snapshot().profile_id
	var attached: Dictionary = adapter.attach(profile_id, 1001, 7, 11, binding.get_attachment_generation())
	_check(bool(attached.accepted), "adapter attaches with caller generations")
	var generation: int = binding.get_attachment_generation()
	var policy_result := policy.evaluate({
		"altitude_m": 0.0,
		"listener_context": &"exterior",
		"grounded": false,
		"speed_mps": 80.0,
		"ambient_wind_scalar_unitless": 1.0,
	})
	var environment := {
		"generation": 4,
		"solar": {"phase": &"day"},
		"weather": {
			"intensity_unitless": 1.0,
			"gust_factor_unitless": 1.0,
			"shelter_scalar": 0.0,
			"wind_velocity_mps": Vector3(20.0, 0.0, 0.0),
		},
	}
	var presented := adapter.present_environment(environment, policy_result, 0.75, generation, 1001, 7, 11)
	_check(bool(presented.accepted), "detached Ember environment reaches playback")
	var fade: Dictionary = binding.get_state_snapshot().fade
	_check(float(fade.target_wind_intensity_unitless) > 0.0, "weather drives exterior wind")
	var stale := adapter.present_environment(environment, policy_result, 0.1, generation, 1001, 7, 11)
	_check(stale.reason == &"stale_environment_generation", "stale environment snapshots are rejected")
	var cabin_environment := environment.duplicate(true)
	cabin_environment.generation = 5
	cabin_environment.cabin_exposed = true
	var cabin_policy := policy.evaluate({
		"altitude_m": 0.0,
		"listener_context": &"cabin",
		"grounded": false,
		"speed_mps": 80.0,
		"ambient_wind_scalar_unitless": 1.0,
	})
	_check(
		bool(adapter.present_environment(cabin_environment, cabin_policy, 0.75, generation, 1001, 7, 11).accepted),
		"shelter snapshot reaches the cabin route"
	)
	_check(float(binding.get_state_snapshot().fade.target_wind_intensity_unitless) == 0.0, "cabin route occludes wind")
	_check(bool(adapter.detach(&"caller_detached", generation).accepted), "adapter detaches through the binding")
	for failure in _failures:
		push_error(failure)
	print("planetary_surface_audio_environment_adapter_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
