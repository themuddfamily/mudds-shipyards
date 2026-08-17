extends SceneTree

const CENSUS := preload("res://tools/performance/audio_voice_census.gd")
const FIXTURE_SCRIPT := preload("res://tests/fixtures/audio_voice_census_fixture.gd")

const FIXTURE_FINGERPRINT := "173abd748e8837914347a56d2d3da21181d52366757ba42463e8c4f2b931a441"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture := FIXTURE_SCRIPT.new()
	fixture.name = "Fixture"
	var alpha := Node.new()
	alpha.name = "Alpha"
	var beta := Node.new()
	beta.name = "Beta"
	fixture.add_child(alpha)
	fixture.add_child(beta)

	var shared_wave := _wave(400, 11025)
	var spatial_wave := _wave(800, 22050)
	var retained_only_wave := _wave(600, 44100)
	fixture.retained_streams[&"retained_only"] = retained_only_wave

	var plain := AudioStreamPlayer.new()
	plain.name = "PlainVoice"
	plain.bus = &"Music"
	plain.max_polyphony = 1
	plain.stream = shared_wave
	alpha.add_child(plain)
	var planar := AudioStreamPlayer2D.new()
	planar.name = "PlanarVoice"
	planar.bus = &"UI"
	planar.max_polyphony = 2
	planar.stream = shared_wave
	alpha.add_child(planar)
	var spatial := AudioStreamPlayer3D.new()
	spatial.name = "SpatialVoice"
	spatial.bus = &"Weapons"
	spatial.max_polyphony = 3
	spatial.stream = spatial_wave
	beta.add_child(spatial)
	var idle := AudioStreamPlayer3D.new()
	idle.name = "IdleVoice"
	idle.bus = &"Ambience"
	idle.max_polyphony = 4
	beta.add_child(idle)
	var irrelevant := Timer.new()
	irrelevant.name = "NotAVoice"
	beta.add_child(irrelevant)

	root.add_child(fixture)
	plain.play()
	spatial.play()
	var census := CENSUS.new()
	var report := census.measure_frozen_scene(fixture, &"station_resident", 0, 8)
	print("AUDIO_VOICE_CENSUS_FIXTURE_FINGERPRINT: ", report.get("measurement_fingerprint", ""))
	_check(CENSUS.validate_report(report).is_empty(), "fixture report satisfies the machine schema")
	var totals := report.get("totals", {}) as Dictionary
	print("AUDIO_VOICE_CENSUS_FIXTURE_TOTALS: ", totals)
	_check(
		int(totals.get("player_nodes", -1)) == 4
		and int(totals.get("audio_stream_player_nodes", -1)) == 1
		and int(totals.get("audio_stream_player_2d_nodes", -1)) == 1
		and int(totals.get("audio_stream_player_3d_nodes", -1)) == 2,
		"fixture counts exact plain, 2D, and 3D player node classes"
	)
	_check(
		int(totals.get("currently_playing_nodes", -1)) == 2
		and int(totals.get("currently_playing_voice_lower_bound", -1)) == 2
		and int(totals.get("currently_playing_voice_ceiling", -1)) == 4
		and int(totals.get("max_polyphony_exposed_nodes", -1)) == 4
		and int(totals.get("summed_max_polyphony_ceiling", -1)) == 10,
		"fixture separates playing-node observation from exposed polyphony bounds"
	)
	var buses := report.get("bus_split", {}) as Dictionary
	_check(
		buses.keys() == ["Ambience", "Music", "UI", "Weapons"]
		and int((buses.get("Music", {}) as Dictionary).get("currently_playing_nodes", -1)) == 1
		and int((buses.get("Weapons", {}) as Dictionary).get("currently_playing_voice_ceiling", -1)) == 3
		and int((buses.get("Ambience", {}) as Dictionary).get("summed_max_polyphony_ceiling", -1)) == 4,
		"fixture freezes sorted bus splits and their independent ceilings"
	)
	var streams := report.get("retained_streams", {}) as Dictionary
	_check(
		int(streams.get("unique_count", -1)) == 3
		and int(streams.get("payload_bytes", -1)) == 1800
		and int(streams.get("unknown_payload_count", -1)) == 0
		and (streams.get("rows", []) as Array).size() == 3,
		"retained traversal counts shared bound streams once and includes script-only audio"
	)
	var components := report.get("component_buckets", {}) as Dictionary
	_check(
		components.keys() == ["Alpha", "Beta"]
		and int((components.get("Alpha", {}) as Dictionary).get("player_nodes", -1)) == 2
		and int((components.get("Alpha", {}) as Dictionary).get("bound_unique_streams", -1)) == 1
		and int((components.get("Beta", {}) as Dictionary).get("player_nodes", -1)) == 2
		and int((components.get("Beta", {}) as Dictionary).get("bound_unique_streams", -1)) == 1,
		"component buckets retain exact player and unique bound-stream ownership"
	)
	_check(
		str(report.get("measurement_fingerprint", "")) == FIXTURE_FINGERPRINT,
		"fixture fingerprint freezes paths, buses, states, polyphony, streams, and buckets"
	)

	var mutable := report.duplicate(true)
	(mutable.get("players") as Array).clear()
	(mutable.get("component_buckets") as Dictionary).clear()
	var repeated := census.measure_frozen_scene(fixture, &"station_resident", 0, 8)
	_check(
		(repeated.get("players") as Array).size() == 4
		and (repeated.get("component_buckets") as Dictionary).size() == 2
		and repeated.get("measurement_fingerprint") == report.get("measurement_fingerprint"),
		"reports are deeply detached and repeated frozen measurement is deterministic"
	)

	var injected := AudioStreamPlayer.new()
	injected.name = "InjectedVoice"
	injected.bus = &"Master"
	injected.max_polyphony = 1
	beta.add_child(injected)
	var mutated := census.measure_frozen_scene(fixture, &"station_resident", 0, 8)
	_check(
		int((mutated.get("totals", {}) as Dictionary).get("player_nodes", -1)) == 5
		and mutated.get("measurement_fingerprint") != report.get("measurement_fingerprint"),
		"MUTATION: an added voice changes the exact roster and fingerprint"
	)
	beta.remove_child(injected)
	injected.free()
	var restored := census.measure_frozen_scene(fixture, &"station_resident", 0, 8)
	_check(
		restored.get("measurement_fingerprint") == report.get("measurement_fingerprint"),
		"removing the injected voice restores the frozen fingerprint"
	)

	var malformed := report.duplicate(true)
	malformed["schema_version"] = 1.5
	malformed["players"] = {}
	_check(
		CENSUS.validate_report(malformed).size() == 2,
		"schema validation rejects non-integer schema versions and object-shaped player lists"
	)

	plain.stop()
	spatial.stop()
	plain.stream = null
	spatial.stream = null
	await process_frame
	census.free()
	fixture.free()
	await process_frame
	await process_frame
	shared_wave = null
	spatial_wave = null
	retained_only_wave = null
	plain = null
	planar = null
	spatial = null
	idle = null
	fixture = null
	await process_frame
	_finish()


func _wave(byte_count: int, mix_rate: int) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = mix_rate
	wave.stereo = false
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var data := PackedByteArray()
	data.resize(byte_count)
	for index in byte_count:
		data[index] = index % 251
	wave.data = data
	wave.loop_end = byte_count / 2
	return wave


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("AUDIO_VOICE_CENSUS_FIXTURE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("AUDIO_VOICE_CENSUS_FIXTURE_TEST_FAILED: ", ", ".join(_failures))
	quit(1)
