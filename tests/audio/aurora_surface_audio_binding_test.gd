extends SceneTree

const BINDING := preload("res://scripts/audio/aurora_surface_audio_binding.gd")
const MIXER := preload("res://scripts/audio/aurora_exterior_ambience_mixer.gd")
const CATALOG := preload("res://assets/audio/planetary/temperate_surface_audio_catalog.tres")
const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_mixed_pcm_output()
	var world := SCENE.instantiate()
	root.add_child(world)
	await process_frame
	_check(bool(world.get_surface_audio_snapshot().get("attached", false)), "Aurora authored owner composes its surface audio binding")
	var exterior := world.get_node(^"SurfaceAmbience/ExteriorVoice") as AudioStreamPlayer
	var interior := world.get_node(^"SurfaceAmbience/InteriorVoice") as AudioStreamPlayer
	_check(exterior.stream != null and interior.stream != null and exterior.stream != interior.stream, "production owns one mixed exterior output and the original imported cabin loop")
	var snapshot := {"generation": 1, "weather_intensity_unitless": 0.8, "water_exposure_unitless": 0.6, "day_night_unitless": 0.3, "settlement_activity_unitless": 0.4, "ship_perspective": &"exterior"}
	_check(bool(world.present_surface_audio_snapshot(snapshot).get("accepted", false)), "Aurora accepts detached environment evidence")
	_check(exterior.playing and not interior.playing and exterior.bus == &"AuroraExteriorWind", "exterior snapshot drives the mixed wind/coastal output through its own wind-filtered bus")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"AuroraExteriorWind")) == &"Ambience", "the exterior wind bus still cascades into the shared Ambience bus")
	var playback := world.get_surface_audio_snapshot().get("playback", {}) as Dictionary
	var live_mixer := playback.get("exterior_mixer", {}) as Dictionary
	_check(exterior.stream is AudioStreamGenerator and interior.stream == CATALOG.interior_stream
		and int(live_mixer.get("output_stream_count", 0)) == 1
		and float(live_mixer.get("wind_weight", 0.0)) > 0.0
		and float(live_mixer.get("water_weight", 0.0)) > 0.0
		and live_mixer.get("water_source_path", "") == CATALOG.coastal_stream.resource_path,
		"one actual exterior stream combines both authored sources while cabin keeps the second voice")
	_check(exterior.max_polyphony == 1 and interior.max_polyphony == 1,
		"both actual playback nodes retain one voice each")
	await create_timer(1.2).timeout
	var steady_playback := world.get_surface_audio_snapshot().get("playback", {}) as Dictionary
	_check(int(steady_playback.get("generator_buffer_skips", -1)) == 0
		and int(steady_playback.get("exterior_mixer", {}).get("generated_frames", 0)) > 24_000,
		"the bounded source-rate generator refills under Dummy without buffer skips")
	print("AURORA_EXTERIOR_MIXER_PROFILE %s" % steady_playback.get("exterior_mixer", {}))
	var previous_playback := exterior.get_stream_playback()
	var pure_water := snapshot.merged({"wind_strength_unitless": 0.0}, true)
	_check(bool(world.present_surface_audio_snapshot(pure_water).get("accepted", false))
		and exterior.playing and not interior.playing
		and is_zero_approx(float(world.get_surface_audio_snapshot().get("playback", {}).get("exterior_mixer", {}).get("wind_weight", -1.0)))
		and is_equal_approx(float(world.get_surface_audio_snapshot().get("playback", {}).get("exterior_mixer", {}).get("water_weight", -1.0)), 1.0),
		"coastal exposure plays the coastal PCM even with calm wind")
	_check(exterior.get_stream_playback() != previous_playback,
		"a source disappearance retires the old generator ring instead of retaining queued wind")
	previous_playback = null
	var dry := pure_water.merged({"water_exposure_unitless": 0.0}, true)
	_check(bool(world.present_surface_audio_snapshot(dry).get("accepted", false))
		and not exterior.playing and not interior.playing and not world.is_processing(),
		"dry calm ground stops both voices and all sample refill work")
	var dry_wind := snapshot.merged({"water_exposure_unitless": 0.0}, true)
	world.present_surface_audio_snapshot(dry_wind)
	var dry_wind_playback := world.get_surface_audio_snapshot().get("playback", {}) as Dictionary
	var boundary_flushes := int(dry_wind_playback.get("source_boundary_flushes", 0))
	_check(exterior.playing
		and is_zero_approx(float(dry_wind_playback.get("exterior_mixer", {}).get("water_weight", -1.0))),
		"dry windy ground retains only the original wind waveform")
	previous_playback = exterior.get_stream_playback()
	world.present_surface_audio_snapshot(snapshot)
	_check(exterior.get_stream_playback() != previous_playback
		and int(world.get_surface_audio_snapshot().get("playback", {}).get("source_boundary_flushes", 0)) == boundary_flushes + 1,
		"entering coastal exposure retires the old ring before refilling with both sources")
	previous_playback = null
	var mix := world.get_surface_audio_snapshot().get("mix", {}) as Dictionary
	_check(float(mix.get("wind", 0.0)) > 0.0 and float(mix.get("distant_water", 0.0)) > 0.0, "weather and water produce bounded ambience gains")
	_check(float(mix.get("low_pass_hz", 0.0)) < 18_000.0 and float(mix.get("pitch_scale", 0.0)) > 0.0, "environment changes bounded filter and pitch")
	var wind_filter := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"AuroraExteriorWind"), 0) as AudioEffectLowPassFilter
	_check(is_equal_approx(exterior.pitch_scale, float(mix.get("pitch_scale", 1.0))), "the live exterior voice picks up the mix's wind pitch")
	_check(wind_filter != null and is_equal_approx(wind_filter.cutoff_hz, float(mix.get("low_pass_hz", 0.0))), "the dedicated wind bus filter tracks the mix's cutoff")
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
	# Standalone bindings isolate the wind-strength comparisons from the
	# world's own generation sequence used below.
	var calm_wind := BINDING.new()
	_check(bool(calm_wind.attach().get("accepted", false)), "calm-wind binding attaches")
	_check(bool(calm_wind.present_snapshot({"generation": 0, "weather_intensity_unitless": 0.7, "water_exposure_unitless": 0.6, "day_night_unitless": 0.3, "settlement_activity_unitless": 0.4, "wind_strength_unitless": 0.0, "ship_perspective": &"exterior"}).get("accepted", false)), "calm wind reading is accepted despite heavy weather")
	var calm_mix := calm_wind.get_snapshot().get("mix", {}) as Dictionary
	_check(is_equal_approx(float(calm_mix.get("wind", -1.0)), 0.0) and float(calm_mix.get("low_pass_hz", 99_999.0)) < 1_000.0, "calm wind is silent and muffled even under heavy weather")
	var strong_wind := BINDING.new()
	_check(bool(strong_wind.attach().get("accepted", false)), "strong-wind binding attaches")
	_check(bool(strong_wind.present_snapshot({"generation": 0, "weather_intensity_unitless": 0.1, "water_exposure_unitless": 0.6, "day_night_unitless": 0.3, "settlement_activity_unitless": 0.4, "wind_strength_unitless": 1.0, "ship_perspective": &"exterior"}).get("accepted", false)), "strong wind reading is accepted despite light weather")
	var strong_mix := strong_wind.get_snapshot().get("mix", {}) as Dictionary
	_check(
		float(strong_mix.get("wind", 0.0)) > float(calm_mix.get("wind", 0.0))
		and float(strong_mix.get("low_pass_hz", 0.0)) > float(calm_mix.get("low_pass_hz", 0.0))
		and float(strong_mix.get("pitch_scale", 0.0)) > float(calm_mix.get("pitch_scale", 0.0)),
		"strong wind is louder, brighter and pitched up than calm wind despite lighter weather",
	)
	_check(strong_wind.present_snapshot({"generation": 1, "weather_intensity_unitless": 0.1, "water_exposure_unitless": 0.6, "day_night_unitless": 0.3, "settlement_activity_unitless": 0.4, "wind_strength_unitless": 1.4, "ship_perspective": &"exterior"}).get("reason", &"") == &"invalid_environment_snapshot", "out-of-range wind strength is rejected")
	_check(bool(strong_wind.detach().get("accepted", false)), "strong-wind binding detaches")
	_check(float(strong_wind.get_snapshot().get("mix", {}).get("wind", 1.0)) == 0.0, "unload resets exterior wind ambience to silence")
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "standalone Aurora binding attaches")
	_check(binding.present_snapshot({"generation": 0, "weather_intensity_unitless": 0.0, "water_exposure_unitless": 0.0, "day_night_unitless": 0.5, "settlement_activity_unitless": 0.0, "ship_perspective": &"exterior"}).get("accepted", false), "neutral snapshot is accepted")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "Aurora keeps two fixed ambience voices")
	var high := snapshot.duplicate(true)
	high["generation"] = 2
	high["altitude_m"] = 3000.0
	_check(bool(world.present_surface_audio_snapshot(high).get("accepted", false)) and not exterior.playing and not interior.playing and not world.is_processing(), "high altitude silences both live voices")
	_check(int(world.get_surface_audio_snapshot().get("playback", {}).get("voice_count", 0)) == 2, "the authored world owns exactly two bounded players")
	_check(bool((world.get_surface_audio_snapshot().get("playback", {}).get("authority", {}) as Dictionary).get("audio", false))
		and not bool((world.get_surface_audio_snapshot().get("playback", {}).get("authority", {}) as Dictionary).get("perspective", true)),
		"playback snapshot owns audio while perspective stays caller-owned")
	world.present_surface_audio_snapshot(snapshot.merged({"generation": 3}, true))
	world.queue_free()
	await process_frame
	_check(not is_instance_valid(exterior) and not is_instance_valid(interior), "stream unload releases both playback nodes")
	var unloaded_filter := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"AuroraExteriorWind"), 0) as AudioEffectLowPassFilter
	_check(unloaded_filter != null and is_equal_approx(unloaded_filter.cutoff_hz, 18_000.0), "unload resets the shared wind filter to a neutral, unmuffled cutoff")
	var reentered := SCENE.instantiate()
	root.add_child(reentered)
	await process_frame
	var fresh_exterior := reentered.get_node(^"SurfaceAmbience/ExteriorVoice") as AudioStreamPlayer
	var fresh_interior := reentered.get_node(^"SurfaceAmbience/InteriorVoice") as AudioStreamPlayer
	_check(not fresh_exterior.playing and not fresh_interior.playing and int(reentered.get_surface_audio_snapshot().get("last_source_generation", -1)) == -1,
		"a streamed re-entry starts with fresh silent voices and no stale source")
	_check(bool(reentered.present_surface_audio_snapshot(snapshot).get("accepted", false)) and fresh_exterior.playing,
		"the re-entered world accepts a fresh source generation")
	_check(int(reentered.get_surface_audio_snapshot().get("playback", {}).get("exterior_mixer", {}).get("generated_frames", 0)) <= 4096,
		"re-entry primes a new bounded buffer without retaining the old PCM cursor or generation count")
	reentered.queue_free()
	await process_frame
	# The audio server retires stopped WAV playback on its own mix cadence.
	await create_timer(0.25).timeout
	if _failures.is_empty():
		print("PASS aurora_surface_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _test_mixed_pcm_output() -> void:
	var water_source := CATALOG.resolve_coastal_stream()
	var mixer := MIXER.new()
	var output := mixer.configure(CATALOG.exterior_stream, water_source)
	_check(output != null and is_equal_approx(output.mix_rate, 24_000.0)
		and is_equal_approx(output.buffer_length, 0.2),
		"mixed output preserves the authored source rate with a fixed bounded buffer")
	if water_source == null:
		return
	mixer.set_weights(0.0, 1.0)
	var coast_chunk: PackedVector2Array = mixer._render_next_chunk()
	var water_matches := true
	var differs_from_wind := false
	for index in coast_chunk.size():
		var water_sample := float(water_source.data.decode_s16(index * 2)) / 32768.0
		var wind_sample := float(CATALOG.exterior_stream.data.decode_s16(index * 2)) / 32768.0
		water_matches = water_matches and is_equal_approx(coast_chunk[index].x, water_sample) \
			and is_equal_approx(coast_chunk[index].y, water_sample)
		differs_from_wind = differs_from_wind or not is_equal_approx(water_sample, wind_sample)
	_check(water_matches and differs_from_wind,
		"water-only output contains the authored water waveform rather than changed wind gain")
	var mixed := MIXER.new()
	mixed.configure(CATALOG.exterior_stream, water_source)
	mixed.set_weights(0.65, 0.35)
	var mixed_chunk: PackedVector2Array = mixed._render_next_chunk()
	var contribution_matches := true
	for index in mixed_chunk.size():
		var expected := (float(CATALOG.exterior_stream.data.decode_s16(index * 2)) * 0.65
			+ float(water_source.data.decode_s16(index * 2)) * 0.35) / 32768.0
		contribution_matches = contribution_matches and is_equal_approx(mixed_chunk[index].x, expected)
	_check(contribution_matches, "exterior PCM contains simultaneous weighted wind and water")
	# Both original loops have 375 complete chunks; the next one wraps exactly.
	for _chunk in 374:
		mixer._render_next_chunk()
	var wrapped: PackedVector2Array = mixer._render_next_chunk()
	_check(wrapped == coast_chunk, "mixed sample cursor wraps at the original eight-second loop boundary")

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
