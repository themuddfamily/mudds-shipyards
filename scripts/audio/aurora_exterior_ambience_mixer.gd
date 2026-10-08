class_name AuroraExteriorAmbienceMixer
extends RefCounted

## Decode two immutable authored mono loops once, then combine their PCM into
## ONE output stream. There are no child players or simultaneous substreams.
## The caller owns output gain, pitch, filtering, playback and refill cadence.
const SAMPLE_RATE_HZ := 24_000
const CHUNK_FRAMES := 512
const MAX_CHUNKS_PER_FILL := 8
const BUFFER_SECONDS := 0.2

var _wind := PackedFloat32Array()
var _water := PackedFloat32Array()
var _chunk := PackedVector2Array()
var _frame := 0
var _wind_weight := 1.0
var _water_weight := 0.0
var _generated_frames := 0
var _maximum_fill_usec := 0
var _wind_path := ""
var _water_path := ""

func configure(wind: AudioStreamWAV, water: AudioStreamWAV) -> AudioStreamGenerator:
	if wind == null or water == null or wind == water \
			or wind.mix_rate != SAMPLE_RATE_HZ or water.mix_rate != SAMPLE_RATE_HZ \
			or wind.stereo or water.stereo \
			or wind.format != AudioStreamWAV.FORMAT_16_BITS \
			or water.format != AudioStreamWAV.FORMAT_16_BITS \
			or wind.data.size() != water.data.size() or wind.data.is_empty():
		return null
	_wind = _decode(wind.data)
	_water = _decode(water.data)
	_chunk.resize(CHUNK_FRAMES)
	_wind_path = wind.resource_path
	_water_path = water.resource_path
	var output := AudioStreamGenerator.new()
	output.mix_rate = SAMPLE_RATE_HZ
	output.buffer_length = BUFFER_SECONDS
	return output

## Returns true when a source enters or leaves the mix. The owner flushes old
## queued PCM at those boundaries; smooth nonzero weight changes retain the
## fixed buffer latency instead of rebuilding its entire queue every tick.
func set_weights(wind_level: float, water_level: float) -> bool:
	var wind_was_active := _wind_weight > 0.0
	var water_was_active := _water_weight > 0.0
	var total := maxf(wind_level, 0.0) + maxf(water_level, 0.0)
	_wind_weight = maxf(wind_level, 0.0) / total if total > 0.0 else 0.0
	_water_weight = maxf(water_level, 0.0) / total if total > 0.0 else 0.0
	return wind_was_active != (_wind_weight > 0.0) or water_was_active != (_water_weight > 0.0)

func fill(playback: AudioStreamGeneratorPlayback) -> void:
	if playback == null or _wind.is_empty():
		return
	var started := Time.get_ticks_usec()
	var chunk_count := mini(playback.get_frames_available() / CHUNK_FRAMES, MAX_CHUNKS_PER_FILL)
	for _block in chunk_count:
		if not playback.push_buffer(_render_next_chunk()):
			break
		_generated_frames += CHUNK_FRAMES
	_maximum_fill_usec = maxi(_maximum_fill_usec, Time.get_ticks_usec() - started)

func get_snapshot() -> Dictionary:
	return {
		"output_stream_count": 1,
		"sample_rate_hz": SAMPLE_RATE_HZ,
		"buffer_seconds": BUFFER_SECONDS,
		"chunk_frames": CHUNK_FRAMES,
		"maximum_chunks_per_fill": MAX_CHUNKS_PER_FILL,
		"decoded_pcm_bytes": (_wind.size() + _water.size()) * 4,
		"wind_source_path": _wind_path,
		"water_source_path": _water_path,
		"wind_weight": _wind_weight,
		"water_weight": _water_weight,
		"generated_frames": _generated_frames,
		"maximum_fill_usec": _maximum_fill_usec,
	}

func _render_next_chunk() -> PackedVector2Array:
	for index in CHUNK_FRAMES:
		var sample := _wind[_frame] * _wind_weight + _water[_frame] * _water_weight
		_chunk[index] = Vector2(sample, sample)
		_frame += 1
		if _frame == _wind.size():
			_frame = 0
	return _chunk

static func _decode(pcm: PackedByteArray) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(pcm.size() / 2)
	for index in samples.size():
		samples[index] = float(pcm.decode_s16(index * 2)) / 32768.0
	return samples
