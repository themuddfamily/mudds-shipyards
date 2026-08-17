extends SceneTree

const CENSUS := preload("res://tools/performance/audio_voice_census.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const BASELINE_PATH := "res://tools/performance/audio_voice_census_baseline.json"
const SCHEMA_PATH := "res://tools/performance/audio_voice_census.schema.json"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var initial_root_children := root.get_child_count()
	var baseline := _read_json(BASELINE_PATH)
	var schema := _read_json(SCHEMA_PATH)
	_check(
		int(baseline.get("schema_version", -1)) == CENSUS.SCHEMA_VERSION
		and baseline.get("report_schema") == SCHEMA_PATH
		and int(schema.get("properties", {}).get("schema_version", {}).get("const", -1))
			== CENSUS.SCHEMA_VERSION,
		"checked-in baseline and JSON Schema freeze the same exact integer version"
	)
	_check(
		AudioServer.get_driver_name() == "Dummy"
		and int((baseline.get("profile", {}) as Dictionary).get("settle_frames", -1))
			== CENSUS.DEFAULT_SETTLE_FRAMES,
		"production census test owns the declared Dummy-driver eight-frame profile"
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for both audio scenarios")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	await CENSUS.settle_scene(self, CENSUS.DEFAULT_SETTLE_FRAMES)
	game.process_mode = Node.PROCESS_MODE_DISABLED

	var resident_contract := CENSUS.inspect_production_scenario(
		game, CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		bool(resident_contract.get("valid", false))
		and int(resident_contract.get("loaded_instance_count", -1)) == 0,
		"station-resident audio census freezes with zero Cinder generations"
	)
	var census := CENSUS.new()
	var resident := census.measure_frozen_scene(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT,
		0,
		CENSUS.DEFAULT_SETTLE_FRAMES
	)
	print("AUDIO_VOICE_CENSUS_RESIDENT_FINGERPRINT: ", resident.get("measurement_fingerprint", ""))
	_check(CENSUS.validate_report(resident).is_empty(), "resident report satisfies its machine schema and fingerprint")
	_check(
		_matches_baseline(
			resident,
			(baseline.get("scenarios", {}) as Dictionary).get("station_resident", {}) as Dictionary
		),
		"resident report matches every checked-in count and fingerprint"
	)
	var resident_totals := resident.get("totals", {}) as Dictionary
	_check(
		int(resident_totals.get("player_nodes", -1)) == 56
		and int(resident_totals.get("audio_stream_player_nodes", -1)) == 8
		and int(resident_totals.get("audio_stream_player_2d_nodes", -1)) == 0
		and int(resident_totals.get("audio_stream_player_3d_nodes", -1)) == 48
		and int(resident_totals.get("summed_max_polyphony_ceiling", -1)) == 56,
		"resident graph freezes 56 players: 8 plain / 0 2D / 48 3D with ceiling 56"
	)
	_check(
		int(resident_totals.get("currently_playing_nodes", -1)) == 0
		and int(resident_totals.get("currently_playing_voice_lower_bound", -1)) == 0
		and int(resident_totals.get("currently_playing_voice_ceiling", -1)) == 0
		and int(resident_totals.get("max_polyphony_exposed_nodes", -1)) == 56
		and int(resident_totals.get("max_polyphony_unexposed_nodes", -1)) == 0,
		"Dummy freeze observes zero attached playback and all 56 exposed polyphony fields"
	)
	var resident_streams := resident.get("retained_streams", {}) as Dictionary
	_check(
		int(resident_streams.get("unique_count", -1)) == 97
		and int(resident_streams.get("payload_bytes", -1)) == 4052420
		and int(resident_streams.get("unknown_payload_count", -1)) == 0,
		"resident retained graph freezes 97 exact WAV payloads / 4,052,420 bytes"
	)
	_check(
		_bus_player_counts(resident) == {
			"Ambience": 9,
			"Engines": 20,
			"Music": 3,
			"UI": 9,
			"Weapons": 15,
		},
		"resident bus split accounts for all 56 player nodes exactly"
	)
	_check(
		_component_player_counts(resident) == _integer_map(
			(baseline.get("scenarios", {}) as Dictionary)
			.get("station_resident", {})
			.get("component_player_nodes", {})
		),
		"resident component buckets freeze every station, fleet, music, director, and combat owner"
	)
	var resident_repeat := census.measure_frozen_scene(
		game, CENSUS.SCENARIO_STATION_RESIDENT, 0, CENSUS.DEFAULT_SETTLE_FRAMES
	)
	_check(
		resident_repeat.get("measurement_fingerprint") == resident.get("measurement_fingerprint"),
		"repeated frozen resident measurement is deterministic in one process"
	)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(resident))
	_check(
		CENSUS.validate_report(round_trip).is_empty()
		and (round_trip as Dictionary).get("measurement_fingerprint")
			== resident.get("measurement_fingerprint"),
		"resident report is detached JSON-safe data with a stable round trip"
	)

	game.process_mode = Node.PROCESS_MODE_INHERIT
	var prepared := await CENSUS.prepare_cinder_loaded_scenario(game)
	_check(
		bool(prepared.get("accepted", false))
		and int(prepared.get("loaded_instance_count", -1)) == 1,
		"loaded scenario commits one real coordinator-owned Cinder generation"
	)
	await CENSUS.settle_scene(self, CENSUS.DEFAULT_SETTLE_FRAMES)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var loaded_contract := CENSUS.inspect_production_scenario(
		game, CENSUS.SCENARIO_CINDER_LOADED
	)
	var resident_mismatch := CENSUS.inspect_production_scenario(
		game, CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		bool(loaded_contract.get("valid", false))
		and int(loaded_contract.get("loaded_instance_count", -1)) == 1
		and not bool(resident_mismatch.get("valid", true)),
		"scenario guard accepts only loaded and rejects a mixed resident baseline"
	)
	var loaded := census.measure_frozen_scene(
		game,
		CENSUS.SCENARIO_CINDER_LOADED,
		1,
		CENSUS.DEFAULT_SETTLE_FRAMES
	)
	print("AUDIO_VOICE_CENSUS_LOADED_FINGERPRINT: ", loaded.get("measurement_fingerprint", ""))
	_check(CENSUS.validate_report(loaded).is_empty(), "loaded report satisfies its machine schema and fingerprint")
	_check(
		_matches_baseline(
			loaded,
			(baseline.get("scenarios", {}) as Dictionary).get("cinder_loaded", {}) as Dictionary
		),
		"loaded report matches every checked-in count and fingerprint"
	)
	_check(
		_audio_delta(resident, loaded) == _integer_map(
			baseline.get("cinder_loaded_minus_station_resident", {})
		)
		and resident.get("measurement_fingerprint") != loaded.get("measurement_fingerprint"),
		"real Cinder generation has exact zero audio delta and a distinct scenario fingerprint"
	)
	_check(
		loaded.get("authority_exclusions") == baseline.get("authority_exclusions")
		and (loaded.get("authority_exclusions") as Array).has("native_mixer_voice_count")
		and (loaded.get("authority_exclusions") as Array).has("frame_time"),
		"report explicitly excludes native mixer, memory, frame-time, and renderer authority"
	)

	var malformed := loaded.duplicate(true)
	malformed["schema_version"] = true
	malformed["component_buckets"] = []
	_check(
		CENSUS.validate_report(malformed).size() == 2,
		"MUTATION: malformed schema and component shape fail closed"
	)
	var forged := loaded.duplicate(true)
	forged["measurement_fingerprint"] = "forged"
	_check(
		CENSUS.validate_report(forged).size() == 1,
		"MUTATION: a forged measurement fingerprint fails closed"
	)

	census.free()
	game.queue_free()
	await process_frame
	await process_frame
	_check(root.get_child_count() == initial_root_children, "production scenarios tear down without orphan nodes")
	_finish()


func _matches_baseline(report: Dictionary, expected: Dictionary) -> bool:
	var streams := report.get("retained_streams", {}) as Dictionary
	return (
		int(report.get("loaded_instance_count", -1)) == int(expected.get("loaded_instance_count", -2))
		and report.get("measurement_fingerprint") == expected.get("measurement_fingerprint")
		and _integer_map(report.get("totals", {})) == _integer_map(expected.get("totals", {}))
		and _bus_player_counts(report) == _integer_map(expected.get("bus_player_nodes", {}))
		and _component_player_counts(report) == _integer_map(expected.get("component_player_nodes", {}))
		and int(streams.get("unique_count", -1)) == int(expected.get("retained_unique_streams", -2))
		and int(streams.get("payload_bytes", -1)) == int(expected.get("retained_payload_bytes", -2))
		and int(streams.get("unknown_payload_count", -1)) == int(expected.get("retained_unknown_payload_count", -2))
	)


func _bus_player_counts(report: Dictionary) -> Dictionary:
	var result := {}
	for bus in (report.get("bus_split", {}) as Dictionary):
		result[str(bus)] = int((report.bus_split[bus] as Dictionary).get("player_nodes", -1))
	return result


func _component_player_counts(report: Dictionary) -> Dictionary:
	var result := {}
	for bucket in (report.get("component_buckets", {}) as Dictionary):
		result[str(bucket)] = int((report.component_buckets[bucket] as Dictionary).get("player_nodes", -1))
	return result


func _integer_map(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key in value as Dictionary:
		result[str(key)] = int((value as Dictionary)[key])
	return result


func _audio_delta(resident: Dictionary, loaded: Dictionary) -> Dictionary:
	var resident_totals := resident.get("totals", {}) as Dictionary
	var loaded_totals := loaded.get("totals", {}) as Dictionary
	var resident_streams := resident.get("retained_streams", {}) as Dictionary
	var loaded_streams := loaded.get("retained_streams", {}) as Dictionary
	var result := {}
	for field in [
		"player_nodes",
		"audio_stream_player_nodes",
		"audio_stream_player_2d_nodes",
		"audio_stream_player_3d_nodes",
		"currently_playing_nodes",
		"summed_max_polyphony_ceiling",
	]:
		result[field] = int(loaded_totals.get(field, 0)) - int(resident_totals.get(field, 0))
	result["retained_unique_streams"] = int(loaded_streams.get("unique_count", 0)) - int(resident_streams.get("unique_count", 0))
	result["retained_payload_bytes"] = int(loaded_streams.get("payload_bytes", 0)) - int(resident_streams.get("payload_bytes", 0))
	result["component_bucket_count"] = (loaded.get("component_buckets", {}) as Dictionary).size() - (resident.get("component_buckets", {}) as Dictionary).size()
	result["bus_count"] = (loaded.get("bus_split", {}) as Dictionary).size() - (resident.get("bus_split", {}) as Dictionary).size()
	return result


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("AUDIO_VOICE_CENSUS_SCENARIO_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("AUDIO_VOICE_CENSUS_SCENARIO_TEST_FAILED: ", ", ".join(_failures))
	quit(1)
