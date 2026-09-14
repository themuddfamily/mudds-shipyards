extends SceneTree

## Focused source/raw-WAV/import integrity audit for every original
## offline-authored Mudds Shipyards music bed: the station-rest bed and the
## flight (orbit/open space) and surface beds it cross-fades with. Runtime
## routing, state response, and lifecycle live in
## `tests/station_music_bed_test.gd` and
## `tests/audio/music_orbit_surface_presentation_test.gd`.
##
## Nothing in this file can establish that the bed sounds good. It establishes
## only that the checked-in assets are the exact project-original fixed-seed
## renders, that they carry real non-silent signal at the declared duration and
## sample rate, and that they loop without a seam. A human listening pass is a
## separate, outstanding acceptance step.

const ASSET_DIRECTORY := "res://assets/audio/music"
const MANIFEST_PATH := ASSET_DIRECTORY + "/station_music_v1_asset_manifest.json"
const GENERATOR_PATH := "res://tools/audio/generate_station_music_v1.py"
const FLIGHT_MANIFEST_PATH := ASSET_DIRECTORY + "/flight_music_v1_asset_manifest.json"
const FLIGHT_GENERATOR_PATH := "res://tools/audio/generate_flight_music_v1.py"
const SAMPLE_RATE := 22050
## -10 dBFS ceiling: a bed must never approach the headroom the combat cues use.
const MAXIMUM_PEAK_PCM16 := 10362
## Anything quieter than this over a whole loop is not a music bed, it is silence
## with a file extension.
const MINIMUM_RMS_PCM16 := 200.0
const EXPECTED_LAYERS := {
	"station_bed_drone_v1.wav": {
		"layer_id": "drone",
		"frames": 352800,
		"loop_seconds": 16.0,
		"peak": 8231,
		"sha256": "1cd52e0379e15b1fee0875ba83d6eff4fc22657a68822872bb78ed3ee5a76392",
	},
	"station_bed_harmonics_v1.wav": {
		"layer_id": "harmonics",
		"frames": 264600,
		"loop_seconds": 12.0,
		"peak": 5827,
		"sha256": "f2c81c271fbfe95ceadabdf79d6e6dba8d2b9e418df4c33bcd684e144dab78b1",
	},
	"station_bed_motif_v1.wav": {
		"layer_id": "motif",
		"frames": 441000,
		"loop_seconds": 20.0,
		"peak": 7336,
		"sha256": "54b214c27382b0577681cc9a87203da0dffbd0e7817b9475af7a1edfc2f251ad",
	},
}
## The flight and surface beds reuse the station bed's three loop lengths on
## purpose: the runtime hands one loop slot over at a time inside the same fixed
## three-voice budget, so a slot's replacement must be the same length.
const EXPECTED_FLIGHT_LAYERS := {
	"flight_bed_drift_v1.wav": {
		"bed_id": "flight",
		"layer_id": "flight_drift",
		"slot_id": "drone",
		"frames": 352800,
		"loop_seconds": 16.0,
		"peak": 7336,
		"sha256": "db17cee08b10ffa474c635bd882e2f1661dd30a691440f9986978fb8b5e90a98",
		"pcm_sha256": "8bc1456d918d0fd4813604ec8119807b13d70879188430ea5bfc2e52e9b9133b",
	},
	"flight_bed_shimmer_v1.wav": {
		"bed_id": "flight",
		"layer_id": "flight_shimmer",
		"slot_id": "harmonics",
		"frames": 264600,
		"loop_seconds": 12.0,
		"peak": 4628,
		"sha256": "b8d759b0da59ee0140921560725c9787065805e38b0ce1b54ea6f940870acd83",
		"pcm_sha256": "5b4182dac4df0bcdaa48e0bdb834fd102ae236369fb57eab958720c1b01b4f0f",
	},
	"flight_bed_signal_v1.wav": {
		"bed_id": "flight",
		"layer_id": "flight_signal",
		"slot_id": "motif",
		"frames": 441000,
		"loop_seconds": 20.0,
		"peak": 5827,
		"sha256": "22a9b456cd9fdc72c45b78aa2cbf5436ac7e0a7d9e04fa34ff41e91e5286b4cb",
		"pcm_sha256": "80f3231106d594202d2a9bd54d3911bad6d2959257bed906dfeed030670ed352",
	},
	"surface_bed_warmth_v1.wav": {
		"bed_id": "surface",
		"layer_id": "surface_warmth",
		"slot_id": "drone",
		"frames": 352800,
		"loop_seconds": 16.0,
		"peak": 8231,
		"sha256": "f9f68be6d3e3c6e27c93bc518ce40d8c72a56457c50d8e1bc831f73c78af6eed",
		"pcm_sha256": "1cc4955e7678ab059f7580cb4fa6e013f9190e8b9d18f55f5e75784181f79f6c",
	},
	"surface_bed_choir_v1.wav": {
		"bed_id": "surface",
		"layer_id": "surface_choir",
		"slot_id": "harmonics",
		"frames": 264600,
		"loop_seconds": 12.0,
		"peak": 5827,
		"sha256": "322853b91c0543d131e30438b97fee5cde61d04ff69cedb2a85ab335bfb96fe6",
		"pcm_sha256": "935d7dc85b56bc82b240f90e38d60dcf7157fa991927d1d5d1708affcfcf4a12",
	},
	"surface_bed_pulse_v1.wav": {
		"bed_id": "surface",
		"layer_id": "surface_pulse",
		"slot_id": "motif",
		"frames": 441000,
		"loop_seconds": 20.0,
		"peak": 6538,
		"sha256": "4d617888412d508f7f2f04517914368e6824a287247c963e3354137648f18bb2",
		"pcm_sha256": "81013f0fe94a282f780b93ffab8f7cd112840df445c09af8062b96d399dfe094",
	},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(FileAccess.file_exists(GENERATOR_PATH), "offline station-music generator is checked in")
	_check(FileAccess.file_exists(MANIFEST_PATH), "station-music asset manifest is checked in")
	var manifest := _read_manifest()
	_test_manifest_contract(manifest)
	var records := _records_by_filename(manifest)
	var observed_hashes := PackedStringArray()
	for filename in EXPECTED_LAYERS:
		var path := ASSET_DIRECTORY.path_join(filename)
		var expected := EXPECTED_LAYERS[filename] as Dictionary
		var record := records.get(filename, {}) as Dictionary
		_check(FileAccess.file_exists(path), "authored loop exists: %s" % filename)
		if not FileAccess.file_exists(path):
			continue
		_test_raw_wave(path, filename, expected, record)
		_test_imported_wave(path, filename, expected)
		observed_hashes.append(FileAccess.get_sha256(path))
	var unique := {}
	for digest in observed_hashes:
		unique[digest] = true
	_check(unique.size() == EXPECTED_LAYERS.size(), "all three loops have distinct frozen audio content")
	_test_combined_cycle()
	_test_flight_and_surface_beds(observed_hashes)
	_finish()


## The flight (orbit/open space) and surface beds are held to the exact same
## container, loop, headroom and determinism contract as the station bed.
func _test_flight_and_surface_beds(station_hashes: PackedStringArray) -> void:
	_check(
		FileAccess.file_exists(FLIGHT_GENERATOR_PATH),
		"offline flight/surface music generator is checked in"
	)
	_check(
		FileAccess.file_exists(FLIGHT_MANIFEST_PATH),
		"flight/surface music asset manifest is checked in"
	)
	var manifest := _read_json_object(FLIGHT_MANIFEST_PATH)
	_test_flight_manifest_contract(manifest)
	var records := _records_by_filename(manifest)
	var observed := PackedStringArray(station_hashes)
	for filename in EXPECTED_FLIGHT_LAYERS:
		var path := ASSET_DIRECTORY.path_join(filename)
		var expected := EXPECTED_FLIGHT_LAYERS[filename] as Dictionary
		var record := records.get(filename, {}) as Dictionary
		_check(FileAccess.file_exists(path), "authored loop exists: %s" % filename)
		if not FileAccess.file_exists(path):
			continue
		_test_raw_wave(path, filename, expected, record)
		_test_imported_wave(path, filename, expected)
		_test_imported_payload_identity(path, filename, expected)
		_check(
			str(record.get("slot_id", "")) == str(expected["slot_id"])
			and str(record.get("bed_id", "")) == str(expected["bed_id"]),
			"manifest files the layer under its bed and loop slot: %s" % filename
		)
		observed.append(FileAccess.get_sha256(path))
	var unique := {}
	for digest in observed:
		unique[digest] = true
	_check(
		unique.size() == EXPECTED_LAYERS.size() + EXPECTED_FLIGHT_LAYERS.size(),
		"every station, flight and surface loop is distinct authored content"
	)
	# Slot geometry has to agree across beds or a hand-over would change the
	# loop length under a retained loop clock.
	for filename in EXPECTED_FLIGHT_LAYERS:
		var expected := EXPECTED_FLIGHT_LAYERS[filename] as Dictionary
		var matched := false
		for station_filename in EXPECTED_LAYERS:
			var station := EXPECTED_LAYERS[station_filename] as Dictionary
			if str(station["layer_id"]) != str(expected["slot_id"]):
				continue
			matched = (
				int(station["frames"]) == int(expected["frames"])
				and is_equal_approx(
					float(station["loop_seconds"]), float(expected["loop_seconds"])
				)
			)
		_check(matched, "layer matches its station slot's loop geometry: %s" % filename)


func _test_flight_manifest_contract(manifest: Dictionary) -> void:
	_check(int(manifest.get("schema_version", -1)) == 1, "flight manifest declares its schema version")
	_check(
		str(manifest.get("asset_id", "")) == "mudds.audio.music.flight_surface_bed.v1",
		"flight manifest declares the stable flight/surface asset id"
	)
	_check(
		str(manifest.get("authorship", "")) == "original_fixed_seed_offline_procedural_synthesis",
		"flight manifest records fixed-seed offline synthesis as the authorship"
	)
	_check(
		manifest.get("recorded_or_sampled_source_material", true) == false
		and manifest.get("runtime_generation", true) == false,
		"flight manifest states there is no recorded/sampled source and no runtime synthesis"
	)
	_check(
		manifest.get("historically_supported", true) == false
		and str(manifest.get("evidence_status", "")) == "modern_interpretation",
		"flight manifest tags both beds as modern interpretation rather than recovered audio"
	)
	_check(
		str(manifest.get("human_listening_pass", "")) == "outstanding",
		"flight manifest records the human listening pass as outstanding rather than complete"
	)
	_check(
		str(manifest.get("generator", "")) == "tools/audio/generate_flight_music_v1.py"
		and str(manifest.get("generator_sha256", "")).length() == 64,
		"flight manifest pins the committed generator and its hash"
	)
	var format := manifest.get("format_contract", {}) as Dictionary
	_check(
		int(format.get("sample_rate_hz", 0)) == SAMPLE_RATE
		and int(format.get("channels", 0)) == 1
		and int(format.get("bit_depth", 0)) == 16
		and format.get("looped", false) == true
		and str(format.get("loop_mode", "")) == "forward",
		"flight manifest format contract matches the runtime mono looping PCM expectation"
	)
	var musical := manifest.get("musical_contract", {}) as Dictionary
	_check(
		is_equal_approx(float(musical.get("combined_cycle_seconds", 0.0)), 240.0)
		and int(musical.get("layer_count", 0)) == EXPECTED_FLIGHT_LAYERS.size()
		and int(musical.get("bed_count", 0)) == 2,
		"flight manifest records two beds on the same 240-second combined cycle"
	)
	_check(
		str(musical.get("mode", "")) == "D natural minor (Aeolian)"
		and is_equal_approx(float(musical.get("tuning_a4_hz", 0.0)), 440.0),
		"flight and surface beds stay in the station bed's key and tuning"
	)
	_check(
		int(manifest.get("layer_count", 0)) == EXPECTED_FLIGHT_LAYERS.size(),
		"flight manifest counts every layer"
	)
	var beds := manifest.get("beds", []) as Array
	var bed_ids := {}
	for entry: Variant in beds:
		if typeof(entry) == TYPE_DICTIONARY:
			bed_ids[str((entry as Dictionary).get("bed_id", ""))] = true
	_check(
		bed_ids.has("flight") and bed_ids.has("surface"),
		"flight manifest declares both the flight and surface beds"
	)


## The runtime bed pins the *imported* payload digest, so the manifest must
## carry the same value the engine will see after import.
func _test_imported_payload_identity(
		path: String,
		filename: String,
		expected: Dictionary
	) -> void:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(stream.data)
	var digest := context.finish().hex_encode()
	_check(
		digest == str(expected["pcm_sha256"]),
		"imported payload digest matches the manifest PCM hash: %s" % filename
	)
	_check(
		digest == _bed_family_fingerprint(str(expected["bed_id"]), str(expected["slot_id"])),
		"runtime bed pins this exact imported payload: %s" % filename
	)


func _bed_family_fingerprint(bed_id: String, slot_id: String) -> String:
	var families := StationMusicBed.FAMILY_LAYER_STREAM_DATA_SHA256 as Dictionary
	var family := families.get(StringName(bed_id), {}) as Dictionary
	return String(family.get(StringName(slot_id), ""))


func _read_manifest() -> Dictionary:
	return _read_json_object(MANIFEST_PATH)


func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "music manifest parses as a JSON object: %s" % path)
		return {}
	return parsed as Dictionary


func _records_by_filename(manifest: Dictionary) -> Dictionary:
	var records := {}
	for entry: Variant in manifest.get("layers", []):
		if typeof(entry) == TYPE_DICTIONARY:
			records[str((entry as Dictionary).get("filename", ""))] = entry
	return records


func _test_manifest_contract(manifest: Dictionary) -> void:
	_check(int(manifest.get("schema_version", -1)) == 1, "manifest declares its schema version")
	_check(
		str(manifest.get("asset_id", "")) == "mudds.audio.music.station_rest_bed.v1",
		"manifest declares the stable station-music asset id"
	)
	_check(
		str(manifest.get("authorship", "")) == "original_fixed_seed_offline_procedural_synthesis",
		"manifest records fixed-seed offline synthesis as the authorship"
	)
	_check(
		manifest.get("recorded_or_sampled_source_material", true) == false
		and manifest.get("runtime_generation", true) == false,
		"manifest states there is no recorded/sampled source and no runtime synthesis"
	)
	_check(
		manifest.get("historically_supported", true) == false
		and str(manifest.get("evidence_status", "")) == "modern_interpretation",
		"manifest tags the bed as modern interpretation rather than recovered audio"
	)
	_check(
		str(manifest.get("human_listening_pass", "")) == "outstanding",
		"manifest records the human listening pass as outstanding rather than complete"
	)
	_check(
		str(manifest.get("generator", "")) == "tools/audio/generate_station_music_v1.py"
		and str(manifest.get("generator_sha256", "")).length() == 64,
		"manifest pins the committed generator and its hash"
	)
	var format := manifest.get("format_contract", {}) as Dictionary
	_check(
		int(format.get("sample_rate_hz", 0)) == SAMPLE_RATE
		and int(format.get("channels", 0)) == 1
		and int(format.get("bit_depth", 0)) == 16
		and format.get("looped", false) == true
		and str(format.get("loop_mode", "")) == "forward",
		"manifest format contract matches the runtime mono looping PCM expectation"
	)
	var musical := manifest.get("musical_contract", {}) as Dictionary
	_check(
		is_equal_approx(float(musical.get("combined_cycle_seconds", 0.0)), 240.0)
		and int(musical.get("layer_count", 0)) == EXPECTED_LAYERS.size(),
		"manifest records the three-layer 240-second combined cycle"
	)
	_check(int(manifest.get("layer_count", 0)) == EXPECTED_LAYERS.size(), "manifest counts every layer")


func _test_raw_wave(
		path: String,
		filename: String,
		expected: Dictionary,
		record: Dictionary
	) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	_check(bytes.size() > 44, "raw WAV carries a RIFF header and payload: %s" % filename)
	if bytes.size() <= 44:
		return
	_check(
		bytes.slice(0, 4).get_string_from_ascii() == "RIFF"
		and bytes.slice(8, 12).get_string_from_ascii() == "WAVE",
		"raw file is a RIFF/WAVE container: %s" % filename
	)
	# `fmt ` chunk: audio format 1 (PCM), channels, sample rate, bit depth.
	_check(bytes.decode_u16(20) == 1, "raw file is uncompressed linear PCM: %s" % filename)
	_check(bytes.decode_u16(22) == 1, "raw file is mono: %s" % filename)
	_check(bytes.decode_u32(24) == SAMPLE_RATE, "raw file uses the declared 22.05 kHz rate: %s" % filename)
	_check(bytes.decode_u16(34) == 16, "raw file is signed 16-bit: %s" % filename)

	var frame_count := int(expected["frames"])
	var payload_offset := 44
	_check(
		bytes.size() == payload_offset + frame_count * 2,
		"raw payload length matches the declared frame count: %s" % filename
	)
	_check(
		FileAccess.get_sha256(path) == str(expected["sha256"]),
		"raw WAV content matches its frozen fixed-seed hash: %s" % filename
	)
	if bytes.size() != payload_offset + frame_count * 2:
		return

	# Inspect the actual buffer: peak, RMS, and the loop join. None of this is
	# inferred from the manifest.
	var peak := 0
	var sum_of_squares := 0.0
	var maximum_internal_step := 0
	var previous := 0
	for index in frame_count:
		var sample := bytes.decode_s16(payload_offset + index * 2)
		var magnitude := absi(sample)
		if magnitude > peak:
			peak = magnitude
		sum_of_squares += float(sample) * float(sample)
		if index > 0:
			var step := absi(sample - previous)
			if step > maximum_internal_step:
				maximum_internal_step = step
		previous = sample
	var rms := sqrt(sum_of_squares / float(frame_count))
	var first_sample := bytes.decode_s16(payload_offset)
	var last_sample := bytes.decode_s16(payload_offset + (frame_count - 1) * 2)
	var join_step := absi(first_sample - last_sample)

	_check(peak == int(expected["peak"]), "decoded peak matches the frozen render: %s" % filename)
	_check(peak > 0 and rms >= MINIMUM_RMS_PCM16, "decoded loop carries real non-silent signal: %s" % filename)
	_check(peak <= MAXIMUM_PEAK_PCM16, "decoded loop respects the bed headroom ceiling: %s" % filename)
	_check(
		is_equal_approx(float(frame_count) / float(SAMPLE_RATE), float(expected["loop_seconds"])),
		"decoded duration matches the declared loop length: %s" % filename
	)
	_check(
		join_step <= maximum_internal_step,
		"loop wrap is no larger than an ordinary internal step, so the loop is seamless: %s" % filename
	)
	if record.is_empty():
		_check(false, "manifest records the layer: %s" % filename)
		return
	_check(
		int(record.get("frame_count", -1)) == frame_count
		and int(record.get("peak_abs_pcm16", -1)) == peak
		and str(record.get("sha256", "")) == str(expected["sha256"])
		and str(record.get("layer_id", "")) == str(expected["layer_id"]),
		"manifest measurements agree with the decoded buffer: %s" % filename
	)
	_check(
		int(record.get("loop_join_step_pcm16", -1)) == join_step
		and int(record.get("maximum_internal_step_pcm16", -1)) == maximum_internal_step,
		"manifest loop-join measurements agree with the decoded buffer: %s" % filename
	)


func _test_imported_wave(path: String, filename: String, expected: Dictionary) -> void:
	var stream := load(path) as AudioStreamWAV
	_check(stream != null, "imported resource is an AudioStreamWAV: %s" % filename)
	if stream == null:
		return
	var frame_count := int(expected["frames"])
	_check(
		stream.format == AudioStreamWAV.FORMAT_16_BITS
		and stream.mix_rate == SAMPLE_RATE
		and not stream.stereo,
		"import preserves mono 16-bit PCM rather than a lossy re-encode: %s" % filename
	)
	_check(
		stream.data.size() == frame_count * 2,
		"imported payload length matches the authored render: %s" % filename
	)
	_check(
		stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and stream.loop_begin == 0
		and stream.loop_end == frame_count - 1,
		"import loops forward across the complete sample range: %s" % filename
	)
	_check(
		is_equal_approx(stream.get_length(), float(expected["loop_seconds"])),
		"imported stream reports the authored loop duration: %s" % filename
	)


func _test_combined_cycle() -> void:
	# The layer lengths are the structural claim: their least common multiple is
	# how long the bed takes to repeat exactly.
	var lengths: Array[int] = []
	for filename in EXPECTED_LAYERS:
		lengths.append(int(float((EXPECTED_LAYERS[filename] as Dictionary)["loop_seconds"])))
	var combined := lengths[0]
	for index in range(1, lengths.size()):
		combined = combined * lengths[index] / _greatest_common_divisor(combined, lengths[index])
	_check(combined == 240, "16/12/20-second loops only realign after 240 seconds")


func _greatest_common_divisor(first: int, second: int) -> int:
	var a := absi(first)
	var b := absi(second)
	while b != 0:
		var remainder := a % b
		a = b
		b = remainder
	return maxi(a, 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_MUSIC_ASSET_TEST_OK")
		quit(0)
	else:
		print("STATION_MUSIC_ASSET_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
