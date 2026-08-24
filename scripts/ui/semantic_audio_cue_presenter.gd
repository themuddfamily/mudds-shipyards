class_name SemanticAudioCuePresenter
extends RefCounted

## Presentation-only translation of an already-emitted audio semantic cue.
## Audio playback, caption queueing, and gameplay authority remain caller-owned.

const COMPONENT_ID: StringName = &"semantic-audio-cue-presenter"
const MAX_SOURCE_LENGTH := 64
const MAX_TRANSCRIPT_ENTRIES := 8
const REGISTERED_CUES := {
	&"ui_confirm": {"caption": "Action confirmed", "default_severity": &"low"},
	&"combat_alert": {"caption": "Combat alert", "default_severity": &"high"},
	&"siege_lance_charge": {"caption": "Siege lance charging", "default_severity": &"high"},
	&"siege_lance_fire_heavy": {"caption": "Siege lance discharge", "default_severity": &"high"},
	&"siege_lance_impact_heavy": {"caption": "Siege lance impact", "default_severity": &"high"},
	&"tail_turret_fire_broad": {"caption": "Tail turret fires", "default_severity": &"medium"},
	&"tail_turret_impact_broad": {"caption": "Tail turret impact", "default_severity": &"medium"},
	&"repeater_fire_light": {"caption": "Repeater burst", "default_severity": &"low"},
	&"repeater_impact_light": {"caption": "Repeater impact", "default_severity": &"low"},
	&"target_destroyed": {"caption": "Target destroyed", "default_severity": &"medium"},
	&"hull_impact_light": {"caption": "Light hull impact", "default_severity": &"low"},
	&"hull_impact_medium": {"caption": "Hull impact detected", "default_severity": &"medium"},
	&"hull_impact_heavy": {"caption": "Heavy hull impact", "default_severity": &"high"},
	&"engine_component_impact": {"caption": "Engine bay impact", "default_severity": &"high"},
	&"port_weapon_component_impact": {"caption": "Port weapon impact", "default_severity": &"high"},
	&"starboard_weapon_component_impact": {"caption": "Starboard weapon impact", "default_severity": &"high"},
	&"sensor_component_impact": {"caption": "Sensor core impact", "default_severity": &"high"},
	&"opponent_engine_component_impact": {"caption": "Opponent engine impact", "default_severity": &"high"},
	&"opponent_weapon_component_impact": {"caption": "Opponent weapon impact", "default_severity": &"high"},
	&"opponent_sensor_component_impact": {"caption": "Opponent sensor impact", "default_severity": &"high"},
	&"opponent_component_impact": {"caption": "Opponent component impact", "default_severity": &"medium"},
	&"range_target_frame_component_impact": {"caption": "Range target frame impact", "default_severity": &"medium"},
	&"range_target_core_component_impact": {"caption": "Range target core impact", "default_severity": &"high"},
	&"range_target_component_impact": {"caption": "Range target component impact", "default_severity": &"medium"},
	&"range_target_destroyed": {"caption": "Range target destroyed", "default_severity": &"high"},
	&"range_target_regenerated": {"caption": "Range target regenerated", "default_severity": &"low"},
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
	&"crew_engineer_repair_started": {"caption": "Engineer repair started", "default_severity": &"low"},
	&"crew_engineer_repair_progress": {"caption": "Engineer repair progressing", "default_severity": &"low"},
	&"crew_engineer_repair_interrupted": {"caption": "Engineer repair interrupted", "default_severity": &"high"},
	&"crew_engineer_repair_completed": {"caption": "Engineer repair complete", "default_severity": &"low"},
	&"crew_departure_ready": {"caption": "Crew departure ready", "default_severity": &"medium"},
	&"crew_emergency_pilot_handoff": {"caption": "Emergency pilot handoff", "default_severity": &"high"},
	&"crew_emergency_handoff": {"caption": "Emergency pilot handoff", "default_severity": &"high"},
	&"cinder_navigator_ping_accepted": {"caption": "Navigator ping accepted", "default_severity": &"low"},
	&"cinder_navigator_ping_rejected": {"caption": "Navigator ping rejected", "default_severity": &"high"},
	&"cinder_navigator_ping_cleared": {"caption": "Navigator ping cleared", "default_severity": &"low"},
	&"station_defense_wave_started": {"caption": "Station defense wave started", "default_severity": &"medium"},
	&"station_defense_asset_danger": {"caption": "Station defense asset in danger", "default_severity": &"high"},
	&"station_defense_asset_critical": {"caption": "Station defense asset critical", "default_severity": &"high"},
	&"station_defense_asset_destroyed": {"caption": "Station defense asset destroyed", "default_severity": &"high"},
	&"station_defense_completed": {"caption": "Station defense completed", "default_severity": &"low"},
	&"station_defense_aborted": {"caption": "Station defense aborted", "default_severity": &"high"},
	&"cargo_transfer_pickup_accepted": {"caption": "Cargo pickup accepted", "default_severity": &"low"},
	&"cargo_transfer_destination_delivered": {"caption": "Cargo delivered", "default_severity": &"medium"},
	&"cargo_transfer_rejected": {"caption": "Cargo transfer rejected", "default_severity": &"high"},
	&"cargo_transfer_activity_completed": {"caption": "Cargo transfer completed", "default_severity": &"low"},
	&"cargo_transfer_aborted": {"caption": "Cargo transfer aborted", "default_severity": &"high"},
	&"convoy_escort_separation_critical": {"caption": "Critical convoy separation. Rejoin now", "default_severity": &"high"},
	&"convoy_escort_formation_secured": {"caption": "Convoy engines safe. Formation secured", "default_severity": &"low"},
	&"convoy_escort_lost": {"caption": "Convoy lost", "default_severity": &"high"},
	&"cinder_mining_extraction_failed": {"caption": "Mining extraction failed", "default_severity": &"high"},
	&"cinder_scan_failed": {"caption": "Structure scan failed", "default_severity": &"high"},
	&"cinder_scan_aborted": {"caption": "Structure scan aborted", "default_severity": &"high"},
	&"cinder_race_timed_out": {"caption": "Race timed out", "default_severity": &"high"},
	&"cinder_race_failed": {"caption": "Race failed", "default_severity": &"high"},
	&"cinder_race_aborted": {"caption": "Race aborted", "default_severity": &"high"},
	&"cinder_patrol_completed": {"caption": "Patrol complete", "default_severity": &"low"},
	&"cinder_patrol_failed": {"caption": "Patrol failed", "default_severity": &"high"},
	&"cinder_patrol_aborted": {"caption": "Patrol aborted", "default_severity": &"high"},
	&"planetary_orbit_approach": {"caption": "Approaching planetary orbit", "default_severity": &"medium"},
	&"planetary_atmospheric_entry": {"caption": "Planetary atmospheric entry", "default_severity": &"high"},
	&"planetary_landed": {"caption": "Planetary landing complete", "default_severity": &"low"},
	&"planetary_takeoff": {"caption": "Planetary takeoff", "default_severity": &"medium"},
	&"planetary_ascent": {"caption": "Planetary ascent", "default_severity": &"medium"},
	&"planetary_orbit_return": {"caption": "Returning to orbit", "default_severity": &"medium"},
	&"planetary_returned_to_station": {"caption": "Returned to station", "default_severity": &"low"},
	&"ember_service_repair_completed": {"caption": "Component service complete", "default_severity": &"low"},
	&"ember_service_repair_rejected": {"caption": "Component service rejected", "default_severity": &"medium"},
	&"ember_service_repair_unavailable": {"caption": "Component service unavailable", "default_severity": &"medium"},
}
const SEVERITY_MARKERS := {&"low": "○", &"medium": "△", &"high": "!"}

var _last_key := ""
var _last_snapshot: Dictionary = {}
var _transcript: Array[Dictionary] = []


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
	var transition_id := str(metadata.get("transition_id", "")).strip_edges()
	if transition_id.length() > MAX_SOURCE_LENGTH or transition_id.contains("\n") or transition_id.contains("\r"):
		return _rejected(&"invalid_transition_id")
	var key := "%s|%s|%.3f|%s|%s" % [
		cue_id, source_text, safe_intensity, world_position, transition_id,
	]
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
	if metadata.has("distance_m") and (metadata.distance_m is int or metadata.distance_m is float) and is_finite(float(metadata.distance_m)) and float(metadata.distance_m) >= 0.0:
		var distance := float(metadata.distance_m)
		_last_snapshot["distance_m"] = minf(distance, 1_000_000.0)
		_last_snapshot["distance_band"] = &"near" if distance < 25.0 else (&"mid" if distance < 250.0 else &"far")
	if metadata.has("priority") and (metadata.priority is int or metadata.priority is float):
		_last_snapshot["priority"] = clampi(int(metadata.priority), 0, 100)
	_record_transcript(_last_snapshot, metadata)
	return _last_snapshot.duplicate(true)


func get_transcript(current_tick: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _transcript:
		var copy := entry.duplicate(true)
		copy["age_ticks"] = maxi(0, current_tick - int(copy.get("tick", current_tick)))
		copy.erase("key")
		copy.erase("tick")
		result.append(copy)
	return result


func clear_transcript() -> void:
	_transcript.clear()


func _record_transcript(snapshot: Dictionary, metadata: Dictionary) -> void:
	var tick := int(metadata.get("tick", 0))
	var priority := int(snapshot.get("priority", {&"low": 45, &"medium": 70, &"high": 90}.get(snapshot.get("severity", &"low"), 45)))
	var direction := str(snapshot.get("direction", "")).strip_edges()
	var key := "%s|%s|%d|%s" % [snapshot.get("cue_id", &""), snapshot.get("source", &""), priority, direction]
	if not _transcript.is_empty() and str(_transcript[0].get("key", "")) == key:
		_transcript[0]["tick"] = tick
		return
	_transcript.push_front({
		"key": key,
		"cue_id": snapshot.get("cue_id", &""),
		"label": snapshot.get("caption", ""),
		"direction": direction,
		"priority": priority,
		"tick": tick,
	})
	while _transcript.size() > MAX_TRANSCRIPT_ENTRIES:
		_transcript.pop_back()


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
