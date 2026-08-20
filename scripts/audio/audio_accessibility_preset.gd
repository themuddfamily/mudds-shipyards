class_name AudioAccessibilityPreset
extends RefCounted

## Detached accessibility decisions for audio-adjacent presentation.
##
## This contract never plays audio, changes AudioServer, emits captions, or
## owns gameplay. Callers provide the cue metadata and consume a detached
## result. It deliberately keeps reduced-flash/reduced-motion alternatives
## together with subtitle verbosity and per-bus safety ceilings so a settings
## transaction cannot apply only half of an accessibility preference.

enum SubtitleVerbosity {
	OFF,
	KEY_CUES,
	ALL_CUES,
}

const BUS_CEILING_IDS: Array[StringName] = [
	&"Master", &"Ambience", &"Engines", &"Weapons", &"UI", &"Music",
]
const DEFAULT_BUS_CEILINGS := {
	&"Master": 0.0,
	&"Ambience": 0.0,
	&"Engines": 0.0,
	&"Weapons": 0.0,
	&"UI": 0.0,
	&"Music": 0.0,
}

var reduced_flash := false
var reduced_motion := false
var subtitle_verbosity: SubtitleVerbosity = SubtitleVerbosity.OFF
var _bus_ceilings: Dictionary = DEFAULT_BUS_CEILINGS.duplicate()
var _generation := 0


func configure(request: Dictionary) -> Dictionary:
	var next_reduced_flash: bool = bool(request.get("reduced_flash", reduced_flash))
	var next_reduced_motion: bool = bool(request.get("reduced_motion", reduced_motion))
	var next_verbosity := int(request.get("subtitle_verbosity", subtitle_verbosity))
	if next_verbosity < SubtitleVerbosity.OFF or next_verbosity > SubtitleVerbosity.ALL_CUES:
		return {"accepted": false, "reason": &"invalid_subtitle_verbosity", "generation": _generation}
	var next_ceilings: Dictionary = _bus_ceilings.duplicate()
	if request.has("bus_ceilings"):
		if not request.bus_ceilings is Dictionary:
			return {"accepted": false, "reason": &"invalid_bus_ceilings", "generation": _generation}
		var supplied: Dictionary = request["bus_ceilings"]
		for bus in BUS_CEILING_IDS:
			if not supplied.has(bus):
				continue
			var value: Variant = supplied[bus]
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < -80.0 or float(value) > 0.0:
				return {"accepted": false, "reason": &"invalid_bus_ceiling", "bus": bus, "generation": _generation}
			next_ceilings[bus] = float(value)
		for key in supplied.keys():
			if not BUS_CEILING_IDS.has(StringName(key)):
				return {"accepted": false, "reason": &"unknown_bus", "bus": key, "generation": _generation}
	else:
		for bus in BUS_CEILING_IDS:
			if not next_ceilings.has(bus):
				next_ceilings[bus] = DEFAULT_BUS_CEILINGS[bus]
	reduced_flash = next_reduced_flash
	reduced_motion = next_reduced_motion
	subtitle_verbosity = next_verbosity as SubtitleVerbosity
	_bus_ceilings = next_ceilings
	_generation += 1
	return {"accepted": true, "reason": &"applied", "generation": _generation}


## Resolves one cue without allowing accessibility choices to become gameplay.
## `key_cue` is caller-owned metadata used only by subtitle filtering.
func resolve_cue(cue_id: StringName, bus: StringName, key_cue: bool = false, flash_strength: float = 1.0, motion_strength: float = 1.0) -> Dictionary:
	if str(cue_id).is_empty() or not BUS_CEILING_IDS.has(bus):
		return {"accepted": false, "reason": &"invalid_cue", "generation": _generation}
	if not is_finite(flash_strength) or not is_finite(motion_strength) or flash_strength < 0.0 or motion_strength < 0.0:
		return {"accepted": false, "reason": &"invalid_strength", "generation": _generation}
	var show_subtitle := subtitle_verbosity == SubtitleVerbosity.ALL_CUES or (subtitle_verbosity == SubtitleVerbosity.KEY_CUES and key_cue)
	return {
		"accepted": true,
		"cue_id": cue_id,
		"bus": bus,
		"bus_ceiling_db": float(_bus_ceilings[bus]),
		"show_subtitle": show_subtitle,
		"flash_strength": 0.0 if reduced_flash else flash_strength,
		"motion_strength": 0.0 if reduced_motion else motion_strength,
		"gameplay_authority": false,
		"audio_authority": false,
		"generation": _generation,
	}


func get_snapshot() -> Dictionary:
	return {
		"reduced_flash": reduced_flash,
		"reduced_motion": reduced_motion,
		"subtitle_verbosity": subtitle_verbosity,
		"bus_ceilings": _bus_ceilings.duplicate(),
		"generation": _generation,
		"presentation_only": true,
	}


func audit() -> Dictionary:
	return {
		"valid": BUS_CEILING_IDS.size() == 6 and _bus_ceilings.size() == 6,
		"bus_ids": BUS_CEILING_IDS.duplicate(),
		"ceiling_range_db": {"minimum": -80.0, "maximum": 0.0},
		"subtitle_modes": [SubtitleVerbosity.OFF, SubtitleVerbosity.KEY_CUES, SubtitleVerbosity.ALL_CUES],
		"presentation_only": true,
		"gameplay_authority": false,
	}
