extends SceneTree

const BINDING := preload("res://scripts/audio/aurora_surface_audio_binding.gd")
const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := SCENE.instantiate()
	root.add_child(world)
	await process_frame
	_check(bool(world.get_surface_audio_snapshot().get("attached", false)), "Aurora authored owner composes its surface audio binding")
	var snapshot := {"generation": 1, "weather_intensity_unitless": 0.8, "water_exposure_unitless": 0.6, "day_night_unitless": 0.3, "settlement_activity_unitless": 0.4, "ship_perspective": &"exterior"}
	_check(bool(world.present_surface_audio_snapshot(snapshot).get("accepted", false)), "Aurora accepts detached environment evidence")
	var mix := world.get_surface_audio_snapshot().get("mix", {}) as Dictionary
	_check(float(mix.get("wind", 0.0)) > 0.0 and float(mix.get("distant_water", 0.0)) > 0.0, "weather and water produce bounded ambience gains")
	_check(float(mix.get("low_pass_hz", 0.0)) < 18_000.0 and float(mix.get("pitch_scale", 0.0)) > 0.0, "environment changes bounded filter and pitch")
	_check(world.present_surface_audio_snapshot(snapshot).get("reason", &"") == &"duplicate_snapshot", "identical snapshot is deduplicated")
	var cockpit := snapshot.duplicate(true)
	cockpit["ship_perspective"] = &"cockpit"
	_check(bool(world.present_surface_audio_snapshot(cockpit).get("accepted", false)), "cockpit perspective updates the mix")
	_check(bool(world.set_surface_audio_reduced_dynamic_range(true).get("accepted", false)), "reduced range remains caller-driven")
	var reduced := world.get_surface_audio_snapshot().get("mix", {}) as Dictionary
	_check(float(reduced.get("wind", 1.0)) < float(mix.get("wind", 0.0)), "reduced range attenuates ambience")
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "standalone Aurora binding attaches")
	_check(binding.present_snapshot({"generation": 0, "weather_intensity_unitless": 0.0, "water_exposure_unitless": 0.0, "day_night_unitless": 0.5, "settlement_activity_unitless": 0.0, "ship_perspective": &"exterior"}).get("accepted", false), "neutral snapshot is accepted")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 4, "Aurora keeps four fixed ambience voices")
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS aurora_surface_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
