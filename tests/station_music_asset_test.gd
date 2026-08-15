extends SceneTree

## Focused source/raw-WAV/import integrity audit for the original offline-authored
## Mudds Shipyards station-rest music bed. Runtime routing, state response, and
## lifecycle live in `tests/station_music_bed_test.gd`.
##
## Nothing in this file can establish that the bed sounds good. It establishes
## only that the checked-in assets are the exact project-original fixed-seed
## renders, that they carry real non-silent signal at the declared duration and
## sample rate, and that they loop without a seam. A human listening pass is a
## separate, outstanding acceptance step.

const ASSET_DIRECTORY := "res://assets/audio/music"
const MANIFEST_PATH := ASSET_DIRECTORY + "/station_music_v1_asset_manifest.json"
const GENERATOR_PATH := "res://tools/audio/generate_station_music_v1.py"
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
	_finish()


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "station-music manifest parses as a JSON object")
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
