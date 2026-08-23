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
	&"target_lock_acquired": {"caption": "Target lock acquired", "default_severity": &"medium"},
	&"target_lock_lost": {"caption": "Target lock lost", "default_severity": &"low"},
	&"weapon_not_ready": {"caption": "Weapon not ready", "default_severity": &"medium"},
	&"weapon_ready": {"caption": "Weapon ready", "default_severity": &"low"},
	&"engine_started": {"caption": "Engine started", "default_severity": &"low"},
	&"engine_stopped": {"caption": "Engine stopped", "default_severity": &"medium"},
	&"boost_engaged": {"caption": "Boost engaged", "default_severity": &"medium"},
	&"boost_released": {"caption": "Boost released", "default_severity": &"low"},
	&"thrust_load_engaged": {"caption": "Thrust load engaged", "default_severity": &"medium"},
	&"thrust_load_released": {"caption": "Thrust load released", "default_severity": &"low"},
	&"crew_pilot_joined": {"caption": "Pilot joined crew", "default_severity": &"low"},
	&"crew_gunner_joined": {"caption": "Gunner joined crew", "default_severity": &"low"},
	&"crew_engineer_joined": {"caption": "Engineer joined crew", "default_severity": &"low"},
	&"crew_passenger_joined": {"caption": "Passenger joined crew", "default_severity": &"low"},
	&"crew_pilot_left": {"caption": "Pilot left crew", "default_severity": &"medium"},
	&"crew_gunner_left": {"caption": "Gunner left crew", "default_severity": &"medium"},
	&"crew_engineer_left": {"caption": "Engineer left crew", "default_severity": &"medium"},
	&"crew_passenger_left": {"caption": "Passenger left crew", "default_severity": &"low"},
	&"crew_engineer_route_changed": {"caption": "Engineer power route changed", "default_severity": &"medium"},
	&"crew_departure_ready": {"caption": "Crew departure ready", "default_severity": &"medium"},
	&"crew_emergency_pilot_handoff": {"caption": "Emergency pilot handoff", "default_severity": &"high"},
	&"crew_emergency_handoff": {"caption": "Emergency pilot handoff", "default_severity": &"high"},
	&"station_defense_wave_started": {"caption": "Station defense wave started", "default_severity": &"medium"},
	&"station_defense_asset_danger": {"caption": "Station defense asset in danger", "default_severity": &"high"},
	&"station_defense_asset_critical": {"caption": "Station defense asset critical", "default_severity": &"high"},
	&"station_defense_completed": {"caption": "Station defense completed", "default_severity": &"low"},
	&"station_defense_aborted": {"caption": "Station defense aborted", "default_severity": &"high"},
	&"cargo_transfer_pickup_accepted": {"caption": "Cargo pickup accepted", "default_severity": &"low"},
	&"cargo_transfer_destination_delivered": {"caption": "Cargo delivered", "default_severity": &"medium"},
	&"cargo_transfer_rejected": {"caption": "Cargo transfer rejected", "default_severity": &"high"},
	&"cargo_transfer_activity_completed": {"caption": "Cargo transfer completed", "default_severity": &"low"},
	&"cargo_transfer_aborted": {"caption": "Cargo transfer aborted", "default_severity": &"high"},
	&"planetary_orbit_approach": {"caption": "Approaching planetary orbit", "default_severity": &"medium"},
	&"planetary_atmospheric_entry": {"caption": "Planetary atmospheric entry", "default_severity": &"high"},
	&"planetary_landed": {"caption": "Planetary landing complete", "default_severity": &"low"},
	&"planetary_takeoff": {"caption": "Planetary takeoff", "default_severity": &"medium"},
	&"planetary_ascent": {"caption": "Planetary ascent", "default_severity": &"medium"},
	&"planetary_orbit_return": {"caption": "Returning to orbit", "default_severity": &"medium"},
	&"planetary_returned_to_station": {"caption": "Returned to station", "default_severity": &"low"},
}
const SEVERITY_MARKERS := {&"low": "○", &"medium": "△", &"high": "!"}

var _last_key := ""
var _last_snapshot: Dictionary = {}


func present_cue(
	cue_id: StringName, source: StringName, intensity: float, world_position: Vector3,
	metadata: Dictionary = {}
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
	var direction := str(metadata.get("direction", "")).strip_edges()
	if not direction.is_empty() and direction.length() <= 32 and not direction.contains("\n") and not direction.contains("\r"):
		_last_snapshot["direction"] = direction
	if metadata.has("priority") and (metadata.priority is int or metadata.priority is float):
		_last_snapshot["priority"] = clampi(int(metadata.priority), 0, 100)
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
