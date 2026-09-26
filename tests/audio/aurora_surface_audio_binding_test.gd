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
	var exterior := world.get_node(^"SurfaceAmbience/ExteriorVoice") as AudioStreamPlayer
	var interior := world.get_node(^"SurfaceAmbience/InteriorVoice") as AudioStreamPlayer
	_check(exterior.stream != null and interior.stream != null and exterior.stream != interior.stream, "production voices retain distinct imported loops")
	var snapshot := {"generation": 1, "weather_intensity_unitless": 0.8, "water_exposure_unitless": 0.6, "day_night_unitless": 0.3, "settlement_activity_unitless": 0.4, "ship_perspective": &"exterior"}
	_check(bool(world.present_surface_audio_snapshot(snapshot).get("accepted", false)), "Aurora accepts detached environment evidence")
	_check(exterior.playing and not interior.playing and exterior.bus == &"Ambience", "exterior snapshot drives the live wind/coast voice")
	var mix := world.get_surface_audio_snapshot().get("mix", {}) as Dictionary
	_check(float(mix.get("wind", 0.0)) > 0.0 and float(mix.get("distant_water", 0.0)) > 0.0, "weather and water produce bounded ambience gains")
	_check(float(mix.get("low_pass_hz", 0.0)) < 18_000.0 and float(mix.get("pitch_scale", 0.0)) > 0.0, "environment changes bounded filter and pitch")
	_check(world.present_surface_audio_snapshot(snapshot).get("reason", &"") == &"duplicate_snapshot", "identical snapshot is deduplicated")
	var cockpit := snapshot.duplicate(true)
	cockpit["ship_perspective"] = &"cockpit"
	_check(bool(world.present_surface_audio_snapshot(cockpit).get("accepted", false)), "cockpit perspective updates the mix")
	_check(exterior.playing and interior.playing and interior.volume_db > exterior.volume_db, "cockpit routes the live cabin voice above muffled exterior")
	var cockpit_volume := interior.volume_db
	_check(bool(world.set_surface_audio_reduced_dynamic_range(true).get("accepted", false)), "reduced range remains caller-driven")
	_check(interior.volume_db < cockpit_volume, "reduced range attenuates live playback")
	var reduced := world.get_surface_audio_snapshot().get("mix", {}) as Dictionary
	_check(float(reduced.get("wind", 1.0)) < float(mix.get("wind", 0.0)), "reduced range attenuates ambience")
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "standalone Aurora binding attaches")
	_check(binding.present_snapshot({"generation": 0, "weather_intensity_unitless": 0.0, "water_exposure_unitless": 0.0, "day_night_unitless": 0.5, "settlement_activity_unitless": 0.0, "ship_perspective": &"exterior"}).get("accepted", false), "neutral snapshot is accepted")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "Aurora keeps two fixed ambience voices")
	var high := snapshot.duplicate(true)
	high["generation"] = 2
	high["altitude_m"] = 3000.0
	_check(bool(world.present_surface_audio_snapshot(high).get("accepted", false)) and not exterior.playing and not interior.playing, "high altitude silences both live voices")
	_check(int(world.get_surface_audio_snapshot().get("playback", {}).get("voice_count", 0)) == 2, "the authored world owns exactly two bounded players")
	_check(bool((world.get_surface_audio_snapshot().get("playback", {}).get("authority", {}) as Dictionary).get("audio", false))
		and not bool((world.get_surface_audio_snapshot().get("playback", {}).get("authority", {}) as Dictionary).get("perspective", true)),
		"playback snapshot owns audio while perspective stays caller-owned")
	world.present_surface_audio_snapshot(snapshot.merged({"generation": 3}, true))
	world.queue_free()
	await process_frame
	_check(not is_instance_valid(exterior) and not is_instance_valid(interior), "stream unload releases both playback nodes")
	var reentered := SCENE.instantiate()
	root.add_child(reentered)
	await process_frame
	var fresh_exterior := reentered.get_node(^"SurfaceAmbience/ExteriorVoice") as AudioStreamPlayer
	var fresh_interior := reentered.get_node(^"SurfaceAmbience/InteriorVoice") as AudioStreamPlayer
	_check(not fresh_exterior.playing and not fresh_interior.playing and int(reentered.get_surface_audio_snapshot().get("last_source_generation", -1)) == -1,
		"a streamed re-entry starts with fresh silent voices and no stale source")
	_check(bool(reentered.present_surface_audio_snapshot(snapshot).get("accepted", false)) and fresh_exterior.playing,
		"the re-entered world accepts a fresh source generation")
	reentered.queue_free()
	await process_frame
	# The audio server retires stopped WAV playback after the scene has left the tree.
	for _frame in range(10):
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
