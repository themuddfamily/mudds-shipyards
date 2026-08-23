class_name SemanticAudioCuePresenter
extends RefCounted

## Presentation-only translation of an already-emitted audio semantic cue.
## Audio playback, caption queueing, and gameplay authority remain caller-owned.

const COMPONENT_ID: StringName = &"semantic-audio-cue-presenter"
const MAX_SOURCE_LENGTH := 64
const REGISTERED_CUES := {
	&"ui_confirm": {"caption": "Action confirmed", "default_severity": &"low"},
	&"combat_alert": {"caption": "Combat alert", "default_severity": &"high"},
	&"target_destroyed": {"caption": "Target destroyed", "default_severity": &"medium"},
	&"hull_impact_light": {"caption": "Light hull impact", "default_severity": &"low"},
	&"hull_impact_medium": {"caption": "Hull impact detected", "default_severity": &"medium"},
	&"hull_impact_heavy": {"caption": "Heavy hull impact", "default_severity": &"high"},
	&"ship_explosion": {"caption": "Ship destruction", "default_severity": &"high"},
	&"engine_damage_alarm": {"caption": "Engine damage alarm", "default_severity": &"high"},
	&"engine_damage_alarm_cleared": {"caption": "Engine damage alarm cleared", "default_severity": &"low"},
	&"ship_landing_contact": {"caption": "Landing contact", "default_severity": &"medium"},
	&"station_machinery_available": {"caption": "Station machinery available", "default_severity": &"low"},
	&"station_machinery_offline": {"caption": "Station machinery offline", "default_severity": &"high"},
	&"boarding_confirmed": {"caption": "Boarding confirmed", "default_severity": &"low"},
	&"disembark_confirmed": {"caption": "Disembark confirmed", "default_severity": &"low"},
	&"surface_entry_severe": {"caption": "Severe surface entry", "default_severity": &"high"},
	&"surface_entry_clear": {"caption": "Surface entry clear", "default_severity": &"low"},
	&"surface_touchdown": {"caption": "Surface touchdown", "default_severity": &"medium"},
	&"surface_departure": {"caption": "Surface departure", "default_severity": &"medium"},
	&"ship_destroyed": {"caption": "Ship destroyed", "default_severity": &"high"},
	&"ship_audio_recovery_ready": {"caption": "Ship audio recovery ready", "default_severity": &"low"},
	&"station_service_servo": {"caption": "Station service servo", "default_severity": &"low"},
	&"station_service_latch": {"caption": "Station service latch", "default_severity": &"medium"},
}
const SEVERITY_MARKERS := {&"low": "○", &"medium": "△", &"high": "!"}

var _last_key := ""
var _last_snapshot: Dictionary = {}


func present_cue(
	cue_id: StringName, source: StringName, intensity: float, world_position: Vector3
) -> Dictionary:
	if not REGISTERED_CUES.has(cue_id):
		return _rejected(&"unregistered_cue")
	var source_text := str(source).strip_edges()
	if source_text.is_empty() or source_text.length() > MAX_SOURCE_LENGTH:
		return _rejected(&"invalid_source")
	if is_nan(intensity) or is_inf(intensity):
		return _rejected(&"invalid_intensity")
	var safe_intensity := clampf(intensity, 0.0, 1.0)
	var definition := REGISTERED_CUES[cue_id] as Dictionary
	var severity := _resolve_severity(definition.default_severity as StringName, safe_intensity)
	var key := "%s|%s|%.3f|%s" % [cue_id, source_text, safe_intensity, world_position]
	if key == _last_key:
		return _rejected(&"duplicate_cue")
	_last_key = key
	_last_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"cue_id": cue_id,
		"source": StringName(source_text),
		"caption": definition.caption,
		"intensity": safe_intensity,
		"severity": severity,
		"severity_marker": SEVERITY_MARKERS[severity],
		"world_position": world_position,
		"presentation_only": true,
	}.duplicate(true)
	return _last_snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func get_registered_cue_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cue_id in REGISTERED_CUES:
		ids.append(cue_id)
	return ids


func _resolve_severity(default_severity: StringName, intensity: float) -> StringName:
	if intensity >= 0.8:
		return &"high"
	if intensity <= 0.25 and default_severity == &"low":
		return &"low"
	return default_severity


func _rejected(reason: StringName) -> Dictionary:
	return {"component_id": COMPONENT_ID, "accepted": false, "reason": reason, "presentation_only": true}
