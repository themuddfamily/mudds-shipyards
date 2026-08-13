extends SceneTree

const EXPECTED_CUES := {
	"res://assets/audio/combat/player_pulse_fire_v1.wav": 17280,
	"res://assets/audio/combat/defender_pulse_fire_v1.wav": 20160,
	"res://assets/audio/combat/hull_impact_light_v1.wav": 18240,
	"res://assets/audio/combat/hull_impact_medium_v1.wav": 27840,
	"res://assets/audio/combat/hull_impact_heavy_v1.wav": 42240,
	"res://assets/audio/combat/ship_explosion_v1.wav": 134400,
	"res://assets/audio/combat/dry_fire_click_v1.wav": 5760,
}


func _init() -> void:
	var failures := PackedStringArray()
	for path in EXPECTED_CUES:
		var stream := load(path) as AudioStreamWAV
		if (
			stream == null
			or stream.mix_rate != 48_000
			or stream.stereo
			or stream.format != AudioStreamWAV.FORMAT_16_BITS
			or stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
			or stream.data.size() != int(EXPECTED_CUES[path]) * 2
		):
			failures.append(path)
	if failures.is_empty():
		print("PACKAGED_COMBAT_AUDIO_OK: 7 authored PCM streams")
		quit(0)
		return
	push_error("Packaged combat-audio contract failed: %s" % ", ".join(failures))
	quit(1)
