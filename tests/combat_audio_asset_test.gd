extends SceneTree

## Focused source/raw-WAV/import integrity audit for the original offline-authored
## Mudds Shipyards combat one-shot library.  Runtime cue routing is deliberately
## outside this asset-only test.

const ASSET_DIRECTORY := "res://assets/audio/combat"
const MANIFEST_PATH := ASSET_DIRECTORY + "/combat_audio_v1_asset_manifest.json"
const GENERATOR_PATH := "res://tools/audio/generate_combat_audio_v1.py"
const SAMPLE_RATE := 48000
const MAXIMUM_PEAK_PCM16 := 26029 # -2.0 dBFS ceiling, rounded conservatively.
const DRY_FIRE_MAXIMUM_PEAK_PCM16 := 13045 # -8.0 dBFS ceiling.
const EXPECTED_CUES := {
	"player_pulse_fire_v1.wav": {
		"frames": 17280,
		"peak": 23197,
		"sha256": "6a637d442f79688e41d3cd1934cece85dd362d974c1610ffa20b9b377cb97463",
	},
	"defender_pulse_fire_v1.wav": {
		"frames": 20160,
		"peak": 21900,
		"sha256": "6c9647288e23a4f09968085c64224c9f0aa05776072e0701348c05f2088f2818",
	},
	"hull_impact_light_v1.wav": {
		"frames": 18240,
		"peak": 19518,
		"sha256": "211f16ad9499cfd5f0c4c5f4e6067521fa56ecc51191aaafc0e5357be83d1004",
	},
	"hull_impact_medium_v1.wav": {
		"frames": 27840,
		"peak": 21156,
		"sha256": "7e49c7fb7991ee8414be0c914ccf5a91181b3ebee8cdf87ab38ba51b35fd2df9",
	},
	"hull_impact_heavy_v1.wav": {
		"frames": 42240,
		"peak": 23197,
		"sha256": "3c3b450e75a82c86beebc99dfbebedafb279a00392ff4c588465c1e262685cce",
	},
	"ship_explosion_v1.wav": {
		"frames": 134400,
		"peak": 24572,
		"sha256": "67b52b88422d194bc29a5f46c4734b75bca682a79b7edec65b11c78f1eccac3a",
	},
	"dry_fire_click_v1.wav": {
		"frames": 5760,
		"peak": 11626,
		"sha256": "bc855092662538cab11b8ca26348423e7833f957f6c6a8923e5f2baab69c6d48",
	},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(FileAccess.file_exists(GENERATOR_PATH), "offline combat-audio generator is checked in")
	_check(FileAccess.file_exists(MANIFEST_PATH), "combat-audio asset manifest is checked in")
	var manifest := _read_manifest()
	_test_manifest_contract(manifest)
	var records_by_filename := _records_by_filename(manifest)
	var observed_hashes := PackedStringArray()
	for filename in EXPECTED_CUES:
		var path := ASSET_DIRECTORY.path_join(filename)
		var expected := EXPECTED_CUES[filename] as Dictionary
		var record := records_by_filename.get(filename, {}) as Dictionary
		_check(FileAccess.file_exists(path), "authored WAV exists: %s" % filename)
		if not FileAccess.file_exists(path):
			continue
		_test_raw_wave(path, filename, expected, record)
		_test_imported_wave(path, filename, expected)
		observed_hashes.append(FileAccess.get_sha256(path))
	observed_hashes.sort()
	var unique_hashes := PackedStringArray()
	for digest in observed_hashes:
		if not unique_hashes.has(digest):
			unique_hashes.append(digest)
	_check(unique_hashes.size() == EXPECTED_CUES.size(), "all seven cues have distinct frozen audio content")
	_test_role_specific_contracts()
	_finish()


func _test_manifest_contract(manifest: Dictionary) -> void:
	_check(int(manifest.get("schema_version", 0)) == 1, "manifest uses the frozen v1 schema")
	_check(str(manifest.get("asset_id", "")) == "mudds.audio.combat.one_shots.v1", "manifest retains the combat-audio asset ID")
	_check(
		str(manifest.get("authorship", "")) == "original_fixed_seed_offline_procedural_synthesis"
		and str(manifest.get("license", "")) == "project_original"
		and not bool(manifest.get("recorded_or_sampled_source_material", true)),
		"manifest records wholly original synthesis with no sampled source material"
	)
	_check(
		not bool(manifest.get("runtime_generation", true))
		and "non-looping" in str(manifest.get("runtime_intent", "")),
		"checked-in WAVs, not runtime synthesis, are the authored asset contract"
	)
	_check(
		str(manifest.get("generator", "")) == "tools/audio/generate_combat_audio_v1.py"
		and str(manifest.get("generator_sha256", "")) == FileAccess.get_sha256(GENERATOR_PATH),
		"manifest pins the exact deterministic generator"
	)
	var format := manifest.get("format_contract", {}) as Dictionary
	_check(
		str(format.get("container", "")) == "RIFF/WAVE"
		and str(format.get("encoding", "")) == "linear PCM signed 16-bit little-endian"
		and int(format.get("sample_rate_hz", 0)) == SAMPLE_RATE
		and int(format.get("channels", 0)) == 1
		and str(format.get("channel_layout", "")) == "mono"
		and int(format.get("bit_depth", 0)) == 16
		and not bool(format.get("looped", true)),
		"manifest freezes mono 48 kHz 16-bit PCM non-looping delivery"
	)
	var mix := manifest.get("mix_contract", {}) as Dictionary
	_check(
		is_equal_approx(float(mix.get("maximum_allowed_peak_dbfs", 0.0)), -2.0)
		and is_equal_approx(float(mix.get("dry_fire_maximum_peak_dbfs", 0.0)), -8.0)
		and str(mix.get("normalization", "")) == "per-cue integer sample peak",
		"manifest reserves explicit mix headroom rather than normalizing to clipping"
	)
	_check(
		int(manifest.get("cue_count", 0)) == EXPECTED_CUES.size()
		and (manifest.get("cues", []) as Array).size() == EXPECTED_CUES.size(),
		"manifest publishes the exact seven-cue inventory"
	)


func _test_raw_wave(path: String, filename: String, expected: Dictionary, record: Dictionary) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var expected_frames := int(expected.get("frames", 0))
	var expected_data_bytes := expected_frames * 2
	_check(bytes.size() == 44 + expected_data_bytes, "%s has an exact canonical 44-byte PCM header" % filename)
	if bytes.size() < 44:
		return
	_check(
		bytes.slice(0, 4).get_string_from_ascii() == "RIFF"
		and bytes.slice(8, 12).get_string_from_ascii() == "WAVE"
		and bytes.slice(12, 16).get_string_from_ascii() == "fmt "
		and bytes.slice(36, 40).get_string_from_ascii() == "data",
		"%s uses a canonical RIFF/WAVE PCM chunk layout" % filename
	)
	_check(
		int(bytes.decode_u32(16)) == 16
		and int(bytes.decode_u16(20)) == 1
		and int(bytes.decode_u16(22)) == 1
		and int(bytes.decode_u32(24)) == SAMPLE_RATE
		and int(bytes.decode_u32(28)) == SAMPLE_RATE * 2
		and int(bytes.decode_u16(32)) == 2
		and int(bytes.decode_u16(34)) == 16,
		"%s is mono 48 kHz signed 16-bit linear PCM" % filename
	)
	_check(
		int(bytes.decode_u32(4)) == bytes.size() - 8
		and int(bytes.decode_u32(40)) == expected_data_bytes,
		"%s publishes exact RIFF and sample-payload sizes" % filename
	)
	var analysis := _analyse_pcm16(bytes, 44, expected_frames)
	var expected_hash := str(expected.get("sha256", ""))
	var expected_peak := int(expected.get("peak", 0))
	_check(FileAccess.get_sha256(path) == expected_hash, "%s retains its frozen deterministic SHA-256" % filename)
	_check(
		int(analysis.get("peak", 0)) == expected_peak
		and expected_peak <= MAXIMUM_PEAK_PCM16
		and int(record.get("peak_abs_pcm16", 0)) == expected_peak,
		"%s retains its declared peak with at least 2 dBFS library headroom" % filename
	)
	_check(
		int(analysis.get("first", 1)) == 0
		and int(analysis.get("last", 1)) == 0,
		"%s has zero-valued playback boundaries" % filename
	)
	_check(
		float(analysis.get("rms", 0.0)) > 100.0
		and absf(float(analysis.get("mean", 9999.0))) < 100.0,
		"%s is non-silent and keeps bounded DC offset" % filename
	)
	_check(
		int(record.get("frame_count", 0)) == expected_frames
		and is_equal_approx(float(record.get("duration_seconds", 0.0)), float(expected_frames) / SAMPLE_RATE)
		and str(record.get("sha256", "")) == expected_hash
		and int(record.get("first_sample_pcm16", 1)) == 0
		and int(record.get("last_sample_pcm16", 1)) == 0,
		"%s raw measurements match its manifest record" % filename
	)


func _test_imported_wave(path: String, filename: String, expected: Dictionary) -> void:
	var stream := ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
	_check(stream != null, "Godot imports authored cue as AudioStreamWAV: %s" % filename)
	if stream == null:
		return
	_check(
		stream.format == AudioStreamWAV.FORMAT_16_BITS
		and stream.mix_rate == SAMPLE_RATE
		and not stream.stereo
		and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
		and stream.loop_begin == 0
		and stream.loop_end == 0,
		"Godot preserves the non-looping mono 48 kHz PCM contract: %s" % filename
	)
	_check(
		stream.data.size() == int(expected.get("frames", 0)) * 2,
		"Godot preserves every authored PCM frame: %s" % filename
	)


func _test_role_specific_contracts() -> void:
	_check(
		int((EXPECTED_CUES["hull_impact_light_v1.wav"] as Dictionary).frames)
		< int((EXPECTED_CUES["hull_impact_medium_v1.wav"] as Dictionary).frames)
		and int((EXPECTED_CUES["hull_impact_medium_v1.wav"] as Dictionary).frames)
		< int((EXPECTED_CUES["hull_impact_heavy_v1.wav"] as Dictionary).frames),
		"light, medium, and heavy hull impacts have progressively longer resonant bodies"
	)
	var dry_path := ASSET_DIRECTORY.path_join("dry_fire_click_v1.wav")
	var dry_bytes := FileAccess.get_file_as_bytes(dry_path)
	var dry_analysis := _analyse_pcm16(dry_bytes, 44, int((EXPECTED_CUES["dry_fire_click_v1.wav"] as Dictionary).frames))
	_check(
		int(dry_analysis.get("peak", MAXIMUM_PEAK_PCM16)) <= DRY_FIRE_MAXIMUM_PEAK_PCM16,
		"dry-fire click retains its deliberately restrained safety ceiling"
	)
	var explosion_path := ASSET_DIRECTORY.path_join("ship_explosion_v1.wav")
	var explosion_bytes := FileAccess.get_file_as_bytes(explosion_path)
	var early_rms := _window_rms_pcm16(explosion_bytes, 44, 0, roundi(0.25 * SAMPLE_RATE))
	var tail_start := roundi(1.5 * SAMPLE_RATE)
	var tail_end := roundi(2.75 * SAMPLE_RATE)
	var tail_rms := _window_rms_pcm16(explosion_bytes, 44, tail_start, tail_end)
	_check(
		early_rms > tail_rms * 3.0
		and tail_rms > 500.0,
		"explosion contains a quieter but audible authored debris-and-rumble tail"
	)


func _read_manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _records_by_filename(manifest: Dictionary) -> Dictionary:
	var result := {}
	for value in manifest.get("cues", []) as Array:
		if value is Dictionary:
			var record := value as Dictionary
			result[str(record.get("filename", ""))] = record
	return result


func _analyse_pcm16(bytes: PackedByteArray, offset: int, frame_count: int) -> Dictionary:
	var peak := 0
	var total := 0.0
	var squared_total := 0.0
	var first := 0
	var last := 0
	for index in frame_count:
		var sample := _decode_pcm16(bytes, offset + index * 2)
		if index == 0:
			first = sample
		last = sample
		peak = maxi(peak, absi(sample))
		total += sample
		squared_total += float(sample * sample)
	return {
		"peak": peak,
		"mean": total / frame_count,
		"rms": sqrt(squared_total / frame_count),
		"first": first,
		"last": last,
	}


func _window_rms_pcm16(bytes: PackedByteArray, offset: int, begin_frame: int, end_frame: int) -> float:
	var squared_total := 0.0
	for index in range(begin_frame, end_frame):
		var sample := _decode_pcm16(bytes, offset + index * 2)
		squared_total += float(sample * sample)
	return sqrt(squared_total / maxi(end_frame - begin_frame, 1))


func _decode_pcm16(bytes: PackedByteArray, offset: int) -> int:
	var value := int(bytes.decode_u16(offset))
	return value - 65536 if value >= 32768 else value


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_AUDIO_ASSET_TEST_PASS")
		quit(0)
	else:
		push_error("COMBAT_AUDIO_ASSET_TEST_FAIL (%d): %s" % [_failures.size(), _failures])
		quit(1)
