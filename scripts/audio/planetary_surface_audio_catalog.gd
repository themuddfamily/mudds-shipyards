class_name PlanetarySurfaceAudioCatalog
extends Resource

## Strict two-entry resource catalog for the temperate surface-audio policy IDs.
##
## IDs and recipes are code-owned and immutable. The Resource stores only the
## two imported loop references. It resolves those references for a playback
## owner, but never loads on demand, plays audio, allocates voices, changes a
## bus, samples a listener, or advances time.

const SCHEMA_VERSION := 1
const CATALOG_ID: StringName = &"temperate_planetary_surface_audio_v1"
const AUDIO_BUS: StringName = &"Ambience"
const EXTERIOR_PROFILE_ID: StringName = &"temperate_exterior"
const INTERIOR_PROFILE_ID: StringName = &"temperate_interior"
const PROFILE_IDS: Array[StringName] = [
	EXTERIOR_PROFILE_ID,
	INTERIOR_PROFILE_ID,
]
const SAMPLE_RATE_HZ := 24_000
const LOOP_FRAME_COUNT := 192_000
## AudioStreamWAV's forward-loop end is an inclusive final frame index.
const LOOP_END_FRAME := LOOP_FRAME_COUNT - 1
const LOOP_SECONDS := 8.0
const PCM_BYTE_COUNT := LOOP_FRAME_COUNT * 2
const STREAM_SPECS := {
	EXTERIOR_PROFILE_ID: {
		"resource_path": "res://assets/audio/planetary/temperate_exterior_wind_air_v1.wav",
		"pcm_payload_sha256": "aee627cee390c218c22242785257dafc994012f1a00c5a549a9b660e7ca2710e",
		"raw_file_sha256": "5c04b1711a696033e8f3a770a94568845265cbdf0294118f5751d99acc063320",
		"role": &"exterior_wind_air",
	},
	INTERIOR_PROFILE_ID: {
		"resource_path": "res://assets/audio/planetary/temperate_interior_cabin_air_v1.wav",
		"pcm_payload_sha256": "30f72556aa14e36e49921a8011f5a8bfd7136d85d2ebd2115bbdad05e0ff76c3",
		"raw_file_sha256": "a63fab5afc695f2422394c5720dde6f73e34f8bc04a1a2d3ffcf52eefc13fc28",
		"role": &"interior_cabin_air",
	},
}
const AUTHORITY := {
	"renderer": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": false,
}
const ADJACENT_AUTHORITY := {
	"playback": false,
	"voice_allocation": false,
	"bus_or_mixer": false,
	"crossfade": false,
	"crossfade_clock": false,
	"listener_context_truth": false,
	"grounded_truth": false,
	"position_sampling": false,
	"weather_selection": false,
	"world_or_profile_selection": false,
	"streaming": false,
	"origin_shift": false,
	"save": false,
	"network": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

@export var exterior_stream: AudioStreamWAV
@export var interior_stream: AudioStreamWAV


func get_profile_ids() -> Array[StringName]:
	return PROFILE_IDS.duplicate()


## Returns a live imported AudioStream reference only when the complete catalog
## remains valid. Callers must not mutate it; the playback binding revalidates
## the catalog before every accepted state change.
func resolve_stream(profile_id: StringName) -> AudioStreamWAV:
	if not is_definition_valid():
		return null
	match profile_id:
		EXTERIOR_PROFILE_ID:
			return exterior_stream
		INTERIOR_PROFILE_ID:
			return interior_stream
		_:
			return null


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stream(errors, EXTERIOR_PROFILE_ID, exterior_stream)
	_validate_stream(errors, INTERIOR_PROFILE_ID, interior_stream)
	if exterior_stream != null and interior_stream != null \
			and exterior_stream == interior_stream:
		errors.append("catalog entries must resolve distinct loop resources")
	if not _has_exact_zero_authority(AUTHORITY):
		errors.append("common authority roster drifted")
	if not _has_exact_zero_adjacent_authority(ADJACENT_AUTHORITY):
		errors.append("adjacent authority roster drifted")
	errors.sort()
	return errors


func get_snapshot() -> Dictionary:
	var entries := {}
	for profile_id in PROFILE_IDS:
		var stream := _stream_without_validation(profile_id)
		var spec := STREAM_SPECS[profile_id] as Dictionary
		entries[profile_id] = {
			"profile_id": profile_id,
			"role": spec.get("role", &""),
			"resource_path": stream.resource_path if stream != null else "",
			"resource_instance_id": stream.get_instance_id() if stream != null else 0,
			"mix_rate_hz": stream.mix_rate if stream != null else 0,
			"channel_count": 1 if stream != null and not stream.stereo else 0,
			"format": &"signed_pcm_16_bit" if stream != null \
					and stream.format == AudioStreamWAV.FORMAT_16_BITS else &"invalid",
			"loop_mode": &"forward" if stream != null \
					and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD else &"invalid",
			"loop_begin_frame": stream.loop_begin if stream != null else -1,
			"loop_end_frame": stream.loop_end if stream != null else -1,
			"frame_count": stream.data.size() / 2 if stream != null else 0,
			"pcm_payload_bytes": stream.data.size() if stream != null else 0,
			"pcm_payload_sha256": _hash_bytes(stream.data) if stream != null else "",
			"expected_pcm_payload_sha256": spec.get("pcm_payload_sha256", ""),
			"raw_file_sha256": spec.get("raw_file_sha256", ""),
		}.duplicate(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"catalog_id": CATALOG_ID,
		"audio_bus": AUDIO_BUS,
		"profile_ids": PROFILE_IDS.duplicate(),
		"entry_count": PROFILE_IDS.size(),
		"sample_rate_hz": SAMPLE_RATE_HZ,
		"loop_frame_count": LOOP_FRAME_COUNT,
		"loop_seconds": LOOP_SECONDS,
		"pcm_byte_count_per_loop": PCM_BYTE_COUNT,
		"entries": entries.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"catalog_id": CATALOG_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"capabilities": {
			"exact_profile_id_resolution": true,
			"strict_imported_loop_validation": true,
			"detached_reports": true,
			"returns_live_immutable_audio_resources": true,
			"loads_resources_on_demand": false,
			"plays_audio": false,
		}.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"evidence": EVIDENCE.duplicate(true),
	}.duplicate(true)


func _stream_without_validation(profile_id: StringName) -> AudioStreamWAV:
	return exterior_stream if profile_id == EXTERIOR_PROFILE_ID else interior_stream


func _validate_stream(
		errors: PackedStringArray,
		profile_id: StringName,
		stream: AudioStreamWAV
	) -> void:
	var spec := STREAM_SPECS[profile_id] as Dictionary
	if stream == null:
		errors.append("%s stream is missing" % profile_id)
		return
	if stream.resource_path != String(spec.get("resource_path", "")):
		errors.append("%s resource path drifted" % profile_id)
	if stream.resource_local_to_scene:
		errors.append("%s stream must remain a shared imported resource" % profile_id)
	if stream.format != AudioStreamWAV.FORMAT_16_BITS:
		errors.append("%s stream must remain signed PCM16" % profile_id)
	if stream.stereo:
		errors.append("%s stream must remain mono" % profile_id)
	if stream.mix_rate != SAMPLE_RATE_HZ:
		errors.append("%s sample rate drifted" % profile_id)
	if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD \
			or stream.loop_begin != 0 or stream.loop_end != LOOP_END_FRAME:
		errors.append("%s forward-loop metadata drifted" % profile_id)
	if stream.data.size() != PCM_BYTE_COUNT:
		errors.append("%s PCM byte count drifted" % profile_id)
	elif _hash_bytes(stream.data) != String(spec.get("pcm_payload_sha256", "")):
		errors.append("%s PCM payload identity drifted" % profile_id)


static func _hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


static func _has_exact_zero_authority(value: Dictionary) -> bool:
	if value.size() != AUTHORITY.size():
		return false
	for key: String in AUTHORITY:
		if not value.has(key) or value[key] is not bool or bool(value[key]):
			return false
	return true


static func _has_exact_zero_adjacent_authority(value: Dictionary) -> bool:
	if value.size() != ADJACENT_AUTHORITY.size():
		return false
	for key: String in ADJACENT_AUTHORITY:
		if not value.has(key) or value[key] is not bool or bool(value[key]):
			return false
	return true
