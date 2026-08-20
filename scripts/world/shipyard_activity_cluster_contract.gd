class_name ShipyardActivityClusterContract
extends Resource

## Authored activity handoff manifest for the shipyard's nearby activity cluster.
##
## This is deliberately a data-only boundary. It names the fixed station
## activities and the authorities that already own them; it does not create a
## galaxy, spawn actors, move a ship, resolve an objective, transfer cargo,
## apply damage, or grant a reward. A production director may consume this
## manifest and hand the selected stable IDs to those existing authorities.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_ACTIVITIES := 8
const MIN_TRAVEL_TIME_S := 1.0
const MAX_TRAVEL_TIME_S := 900.0
const MAX_CLUSTER_RADIUS_M := 2_000.0
const REQUIRED_ACTIVITY_TYPES := [
	&"station_defense",
	&"cargo",
	&"patrol",
]

@export_category("Identity and authored scale")
@export var station_id: StringName = &"mudds_shipyards"
@export var cluster_id: StringName = &"shipyard_activity_cluster"
@export var display_name := "Mudds Shipyards Activity Cluster"
@export var return_target_id: StringName = &"mudds_shipyards"
@export_range(MIN_TRAVEL_TIME_S, MAX_TRAVEL_TIME_S, 1.0)
var maximum_return_time_s := 180.0
@export_range(1.0, MAX_CLUSTER_RADIUS_M, 1.0)
var maximum_cluster_radius_m := 900.0

@export_category("Fixed station landmarks")
@export var landmark_ids := PackedStringArray([
	"shipyard_defense_perimeter",
	"shipyard_cargo_terminal",
	"shipyard_patrol_beacon",
	"shipyard_return_berth",
])
@export var landmark_display_names := PackedStringArray([
	"Perimeter Defense Ring",
	"Cargo Transfer Terminal",
	"Patrol Beacon",
	"Shipyard Return Berth",
])
@export var landmark_kind_ids := PackedStringArray([
	"defense_perimeter",
	"cargo_terminal",
	"navigation_beacon",
	"return_berth",
])
@export var landmark_positions_station_local_m := PackedVector3Array([
	Vector3(90.0, 0.0, -10.0),
	Vector3(82.0, 0.0, -34.0),
	Vector3(24.0, 4.0, -128.0),
	Vector3(0.0, 0.0, 0.0),
])

@export_category("Typed activity handoffs")
@export var activity_ids := PackedStringArray([
	"shipyard_perimeter_defense",
	"cinder_kit_cargo_run",
	"cinder_relay_patrol",
])
@export var activity_display_names := PackedStringArray([
	"Shipyard Perimeter Defense",
	"Fabrication Kit Cargo Run",
	"Cinder Relay Patrol",
])
@export var activity_type_ids := PackedStringArray([
	"station_defense",
	"cargo",
	"patrol",
])
@export var activity_start_landmark_ids := PackedStringArray([
	"shipyard_defense_perimeter",
	"shipyard_cargo_terminal",
	"shipyard_patrol_beacon",
])
@export var activity_finish_landmark_ids := PackedStringArray([
	"shipyard_return_berth",
	"shipyard_return_berth",
	"shipyard_return_berth",
])
@export var activity_route_ids := PackedStringArray([
	"shipyard_defense_route",
	"cinder_kit_delivery_route",
	"cinder_relay_patrol_route",
])

@export_category("Authority and return handoffs")
@export var activity_authority_ids := PackedStringArray([
	"station_defense_encounter_host",
	"cargo_delivery_activity",
	"patrol_activity",
])
@export var combat_authority_ids := PackedStringArray([
	"live_combat_authority",
	"none",
	"none",
])
@export var cargo_authority_ids := PackedStringArray([
	"none",
	"cargo_transfer_authority",
	"none",
])
@export var reward_authority_ids := PackedStringArray([
	"game_flow_reward_authority",
	"game_flow_reward_authority",
	"game_flow_reward_authority",
])
@export var return_authority_ids := PackedStringArray([
	"shipyard_return_authority",
	"shipyard_return_authority",
	"shipyard_return_authority",
])
@export var return_incentive_ids := PackedStringArray([
	"return_defense_report_to_shipyard",
	"return_fabrication_kits_to_shipyard",
	"return_patrol_log_to_shipyard",
])
@export var recovery_ids := PackedStringArray([
	"recover_at_shipyard_berth",
	"return_to_landed_ship",
	"abort_to_shipyard_return",
])

@export_category("Evidence")
@export var evidence_references := PackedStringArray([
	"res://ROADMAP.md",
	"res://assets/activities/shipyard_perimeter_defense.tres",
])
@export_multiline var evidence_notes := (
	"Fixed shipyard-centered activity handoffs for station defense, cargo, and "
	+ "patrol. This is modern interpretation and does not authenticate a source "
	+ "mission, procedural galaxy, or implemented reward."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "station_id", station_id)
	_validate_id(errors, "cluster_id", cluster_id)
	_validate_id(errors, "return_target_id", return_target_id)
	if station_id != return_target_id:
		errors.append("return_target_id must identify the authored shipyard anchor")
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH \
		or display_name != display_name.strip_edges() or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	if not is_finite(maximum_return_time_s) or maximum_return_time_s < MIN_TRAVEL_TIME_S \
		or maximum_return_time_s > MAX_TRAVEL_TIME_S:
		errors.append("maximum_return_time_s is outside the bounded activity envelope")
	if not is_finite(maximum_cluster_radius_m) or maximum_cluster_radius_m <= 0.0 \
		or maximum_cluster_radius_m > MAX_CLUSTER_RADIUS_M:
		errors.append("maximum_cluster_radius_m is outside the bounded activity envelope")
	_validate_landmarks(errors)
	_validate_activities(errors)
	_validate_id(errors, "return_target_id", return_target_id)
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	for reference in evidence_references:
		if String(reference).is_empty() or String(reference).length() > 256 \
			or not String(reference).begins_with("res://"):
			errors.append("evidence references must be bounded res:// paths")
	if evidence_notes.is_empty() or evidence_notes.length() > MAX_NOTE_LENGTH:
		errors.append("evidence_notes must be bounded and non-empty")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_activity(index: int) -> Dictionary:
	if index < 0 or index >= activity_ids.size():
		return {}
	return {
		"id": StringName(activity_ids[index]),
		"display_name": String(activity_display_names[index]),
		"type": StringName(activity_type_ids[index]),
		"start_landmark_id": StringName(activity_start_landmark_ids[index]),
		"finish_landmark_id": StringName(activity_finish_landmark_ids[index]),
		"route_id": StringName(activity_route_ids[index]),
		"authority_id": StringName(activity_authority_ids[index]),
		"combat_authority_id": StringName(combat_authority_ids[index]),
		"cargo_authority_id": StringName(cargo_authority_ids[index]),
		"reward_authority_id": StringName(reward_authority_ids[index]),
		"return_authority_id": StringName(return_authority_ids[index]),
		"return_incentive_id": StringName(return_incentive_ids[index]),
		"recovery_id": StringName(recovery_ids[index]),
	}


func get_activity_by_id(requested_id: StringName) -> Dictionary:
	for index in activity_ids.size():
		if StringName(activity_ids[index]) == requested_id:
			return get_activity(index)
	return {}


func get_snapshot() -> Dictionary:
	var activities: Array[Dictionary] = []
	for index in activity_ids.size():
		activities.append(get_activity(index))
	var landmarks: Array[Dictionary] = []
	for index in landmark_ids.size():
		landmarks.append({
			"id": StringName(landmark_ids[index]),
			"display_name": String(landmark_display_names[index]),
			"kind": StringName(landmark_kind_ids[index]),
			"position_station_local_m": landmark_positions_station_local_m[index],
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"identity": {
			"station_id": station_id,
			"cluster_id": cluster_id,
			"display_name": display_name,
			"return_target_id": return_target_id,
		},
		"scale": {
			"maximum_return_time_s": maximum_return_time_s,
			"maximum_cluster_radius_m": maximum_cluster_radius_m,
		},
		"landmarks": landmarks,
		"activities": activities,
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"references": evidence_references.duplicate(),
		},
		"authority": {
			"activity": false,
			"movement": false,
			"combat": false,
			"cargo": false,
			"reward": false,
			"return": false,
			"streaming": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
	}.duplicate(true)


func _validate_landmarks(errors: PackedStringArray) -> void:
	if landmark_ids.is_empty() or landmark_ids.size() > 16:
		errors.append("landmark_ids must contain a bounded authored roster")
	if landmark_display_names.size() != landmark_ids.size():
		errors.append("landmark display names must be parallel to IDs")
	if landmark_kind_ids.size() != landmark_ids.size():
		errors.append("landmark kinds must be parallel to IDs")
	if landmark_positions_station_local_m.size() != landmark_ids.size():
		errors.append("landmark positions must be parallel to IDs")
	_validate_unique_ids(errors, "landmark_ids", landmark_ids)
	for index in landmark_ids.size():
		_validate_id(errors, "landmark_id", StringName(landmark_ids[index]))
		if index < landmark_display_names.size() and _invalid_copy(landmark_display_names[index]):
			errors.append("landmark display name %d must be bounded single-line copy" % index)
		if index < landmark_kind_ids.size():
			_validate_id(errors, "landmark_kind_id", StringName(landmark_kind_ids[index]))
		if index < landmark_positions_station_local_m.size():
			var position := landmark_positions_station_local_m[index]
			if not _finite_vector(position) or position.length() > maximum_cluster_radius_m:
				errors.append("landmark position %d is outside the fixed cluster radius" % index)


func _validate_activities(errors: PackedStringArray) -> void:
	if activity_ids.is_empty() or activity_ids.size() > MAX_ACTIVITIES:
		errors.append("activity_ids must contain a bounded authored roster")
	_validate_unique_ids(errors, "activity_ids", activity_ids)
	var fields := [activity_display_names, activity_type_ids, activity_start_landmark_ids,
		activity_finish_landmark_ids, activity_route_ids, activity_authority_ids,
		combat_authority_ids, cargo_authority_ids, reward_authority_ids,
		return_authority_ids, return_incentive_ids, recovery_ids]
	var field_names := ["display names", "types", "start landmarks", "finish landmarks",
		"routes", "authorities", "combat authorities", "cargo authorities",
		"reward authorities", "return authorities", "return incentives", "recoveries"]
	for field_index in fields.size():
		if fields[field_index].size() != activity_ids.size():
			errors.append("activity %s must be parallel to IDs" % field_names[field_index])
	var landmark_set := {}
	for landmark_id in landmark_ids:
		landmark_set[StringName(landmark_id)] = true
	var type_set := {}
	for index in activity_ids.size():
		_validate_id(errors, "activity_id", StringName(activity_ids[index]))
		if index < activity_display_names.size() and _invalid_copy(activity_display_names[index]):
			errors.append("activity display name %d must be bounded single-line copy" % index)
		if index < activity_type_ids.size():
			var activity_type := StringName(activity_type_ids[index])
			_validate_id(errors, "activity_type_id", activity_type)
			type_set[activity_type] = true
		for field_index in [2, 3]:
			if index < fields[field_index].size():
				var landmark_id := StringName(fields[field_index][index])
				_validate_id(errors, "activity landmark", landmark_id)
				if not landmark_set.has(landmark_id):
					errors.append("activity %d references unknown landmark" % index)
		for field_index in [4, 5, 6, 7, 8, 9, 10, 11]:
			if index < fields[field_index].size():
				_validate_id(errors, "activity handoff", StringName(fields[field_index][index]))
	for required_type in REQUIRED_ACTIVITY_TYPES:
		if not type_set.has(required_type):
			errors.append("activity cluster must include a %s activity" % required_type)
	for index in activity_ids.size():
		if index >= activity_type_ids.size():
			continue
		var activity_type := StringName(activity_type_ids[index])
		if activity_type == &"cargo" and index < cargo_authority_ids.size() \
			and StringName(cargo_authority_ids[index]) == &"none":
			errors.append("cargo activity requires a cargo authority handoff")
		if activity_type == &"station_defense" and index < combat_authority_ids.size() \
			and StringName(combat_authority_ids[index]) == &"none":
			errors.append("station defense requires a combat authority handoff")


func _validate_unique_ids(errors: PackedStringArray, field_name: String, values: PackedStringArray) -> void:
	var seen := {}
	for value in values:
		var id := StringName(value)
		if seen.has(id):
			errors.append("%s must not contain duplicate IDs" % field_name)
		seen[id] = true


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") \
		or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return


func _invalid_copy(value: String) -> bool:
	return value.is_empty() or value.length() > MAX_NAME_LENGTH \
		or value != value.strip_edges() or value.contains("\n") or value.contains("\r")


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
