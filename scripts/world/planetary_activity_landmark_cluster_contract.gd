class_name PlanetaryActivityLandmarkClusterContract
extends Resource

## Bounded authored activity and landmark manifest for one visitable world.
##
## The manifest keeps the nearby-world cluster small and legible: every
## landmark and activity is a checked-in ID with a fixed body-local position.
## It is a handoff to the existing navigation, activity, cargo, combat,
## reward, and return authorities; it does not generate a galaxy, spawn
## scenery, move an actor, resolve an objective, or grant a reward.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_LANDMARKS := 32
const MAX_ACTIVITIES := 16
const MIN_LANDMARKS := 6
const MIN_ACTIVITIES := 5
const MIN_TRAVEL_TIME_S := 15.0
const MAX_TRAVEL_TIME_S := 900.0
const MAX_CLUSTER_RADIUS_M := 10_000.0
const REQUIRED_ACTIVITY_TYPES := [
	&"beacon",
	&"patrol",
	&"cargo",
	&"race",
	&"convoy",
]

@export_category("Identity and scale")
@export var world_id: StringName = &"ember_moon"
@export var cluster_id: StringName = &"ember_activity_cluster"
@export var display_name := "Ember Reach Activity Cluster"
@export var return_target_id: StringName = &"mudds_shipyards"
@export_range(MIN_TRAVEL_TIME_S, MAX_TRAVEL_TIME_S, 1.0)
var maximum_travel_time_s := 180.0
@export_range(1.0, MAX_CLUSTER_RADIUS_M, 1.0)
var maximum_cluster_radius_m := 900.0

@export_category("Fixed authored landmarks")
@export var landmark_ids := PackedStringArray([
	"ember_orbital_moonlet",
	"ember_caldera_pad",
	"ember_staging_relay",
	"ember_mining_platform",
	"ember_abandoned_reactor",
	"ember_debris_beacon",
	"ember_convoy_waypoint",
	"ember_return_beacon",
])
@export var landmark_display_names := PackedStringArray([
	"Ringed Moonlet",
	"Caldera Landing Pad",
	"Staging Relay",
	"Mining Platform",
	"Abandoned Reactor",
	"Debris Navigation Beacon",
	"Convoy Waypoint",
	"Return Beacon",
])
@export var landmark_kind_ids := PackedStringArray([
	"orbital_silhouette",
	"landing_region",
	"navigation_beacon",
	"mining_platform",
	"abandoned_structure",
	"debris_field",
	"convoy_waypoint",
	"return_beacon",
])
@export var landmark_positions_body_local_m := PackedVector3Array([
	Vector3(619.0, 0.0, -42.0),
	Vector3(18.0, 0.0, 0.0),
	Vector3(96.0, 0.0, -180.0),
	Vector3(480.0, 3.0, -210.0),
	Vector3(560.0, 1.0, -120.0),
	Vector3(603.0, 0.0, -64.0),
	Vector3(672.0, 0.0, -84.0),
	Vector3(706.0, 0.0, -96.0),
])

@export_category("Typed activity handoffs")
@export var activity_ids := PackedStringArray([
	"ember_beacon_survey",
	"ember_caldera_patrol",
	"ember_kit_cargo_run",
	"ember_checkpoint_race",
	"ember_convoy_escort",
])
@export var activity_display_names := PackedStringArray([
	"Beacon Survey",
	"Caldera Patrol",
	"Fabrication Kit Cargo Run",
	"Checkpoint Race",
	"Emberline Convoy Escort",
])
@export var activity_type_ids := PackedStringArray([
	"beacon",
	"patrol",
	"cargo",
	"race",
	"convoy",
])
@export var activity_start_landmark_ids := PackedStringArray([
	"ember_caldera_pad",
	"ember_caldera_pad",
	"ember_mining_platform",
	"ember_caldera_pad",
	"ember_convoy_waypoint",
])
@export var activity_finish_landmark_ids := PackedStringArray([
	"ember_staging_relay",
	"ember_abandoned_reactor",
	"ember_caldera_pad",
	"ember_return_beacon",
	"ember_return_beacon",
])
@export var activity_route_ids := PackedStringArray([
	"ember_beacon_route",
	"ember_caldera_patrol_route",
	"ember_cargo_route",
	"ember_checkpoint_route",
	"ember_convoy_route",
])
@export var activity_authority_ids := PackedStringArray([
	"activity_director",
	"activity_director",
	"cargo_delivery_activity",
	"timed_checkpoint_race",
	"convoy_escort_activity",
])
@export var activity_reward_ids := PackedStringArray([
	"ember_beacon_data",
	"ember_patrol_log",
	"ember_fabrication_kits",
	"ember_race_record",
	"ember_convoy_credit",
])
@export var activity_return_incentive_ids := PackedStringArray([
	"return_beacon_data_to_shipyard",
	"return_patrol_log_to_shipyard",
	"return_kits_to_shipyard_berth",
	"return_race_record_to_shipyard",
	"return_convoy_credit_to_shipyard",
])
@export var activity_recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"abort_to_orbit_return",
	"return_to_landed_ship",
	"reset_at_start_beacon",
	"recover_convoy_at_return_beacon",
])

@export_category("Authority and evidence")
@export var activity_director_authority_id: StringName = &"activity_director"
@export var reward_authority_id: StringName = &"game_flow_reward_authority"
@export var return_authority_id: StringName = &"planetary_landing_return_contract"
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Fixed Ember Reach activity cluster. IDs are authored handoffs to existing "
	+ "authorities; no procedural galaxy or reward implementation is implied."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "cluster_id", cluster_id)
	_validate_id(errors, "return_target_id", return_target_id)
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	if not is_finite(maximum_travel_time_s) or maximum_travel_time_s < MIN_TRAVEL_TIME_S or maximum_travel_time_s > MAX_TRAVEL_TIME_S:
		errors.append("maximum_travel_time_s is outside the bounded cluster envelope")
	if not is_finite(maximum_cluster_radius_m) or maximum_cluster_radius_m <= 0.0 or maximum_cluster_radius_m > MAX_CLUSTER_RADIUS_M:
		errors.append("maximum_cluster_radius_m is outside the bounded cluster envelope")
	_validate_parallel_landmarks(errors)
	_validate_parallel_activities(errors)
	_validate_id(errors, "activity_director_authority_id", activity_director_authority_id)
	_validate_id(errors, "reward_authority_id", reward_authority_id)
	_validate_id(errors, "return_authority_id", return_authority_id)
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	for reference in evidence_references:
		if String(reference).length() > 256 or not String(reference).begins_with("res://"):
			errors.append("evidence references must be bounded res:// paths")
	if evidence_notes.length() > MAX_NOTE_LENGTH:
		errors.append("evidence_notes exceeds the bounded note length")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": &"game_scale_si_body_local",
		"identity": {
			"world_id": world_id,
			"cluster_id": cluster_id,
			"display_name": display_name,
			"return_target_id": return_target_id,
		},
		"scale": {
			"maximum_travel_time_s": maximum_travel_time_s,
			"maximum_cluster_radius_m": maximum_cluster_radius_m,
		},
		"landmarks": _landmark_snapshot(),
		"activities": _activity_snapshot(),
		"handoffs": {
			"activity_director_authority_id": activity_director_authority_id,
			"reward_authority_id": reward_authority_id,
			"return_authority_id": return_authority_id,
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"references": evidence_references.duplicate(),
		},
		"authority": {
			"renderer": false,
			"terrain": false,
			"streaming": false,
			"movement": false,
			"activity": false,
			"cargo": false,
			"combat": false,
			"reward": false,
			"return": false,
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


func _landmark_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in landmark_ids.size():
		result.append({
			"id": StringName(landmark_ids[index]),
			"display_name": String(landmark_display_names[index]) if index < landmark_display_names.size() else "",
			"kind": StringName(landmark_kind_ids[index]) if index < landmark_kind_ids.size() else &"",
			"position_body_local_m": landmark_positions_body_local_m[index] if index < landmark_positions_body_local_m.size() else Vector3.ZERO,
		})
	return result


func _activity_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in activity_ids.size():
		result.append({
			"id": StringName(activity_ids[index]),
			"display_name": String(activity_display_names[index]) if index < activity_display_names.size() else "",
			"type": StringName(activity_type_ids[index]) if index < activity_type_ids.size() else &"",
			"start_landmark_id": StringName(activity_start_landmark_ids[index]) if index < activity_start_landmark_ids.size() else &"",
			"finish_landmark_id": StringName(activity_finish_landmark_ids[index]) if index < activity_finish_landmark_ids.size() else &"",
			"route_id": StringName(activity_route_ids[index]) if index < activity_route_ids.size() else &"",
			"authority_id": StringName(activity_authority_ids[index]) if index < activity_authority_ids.size() else &"",
			"reward_id": StringName(activity_reward_ids[index]) if index < activity_reward_ids.size() else &"",
			"return_incentive_id": StringName(activity_return_incentive_ids[index]) if index < activity_return_incentive_ids.size() else &"",
			"recovery_id": StringName(activity_recovery_ids[index]) if index < activity_recovery_ids.size() else &"",
		})
	return result


func _validate_parallel_landmarks(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "landmark_ids", landmark_ids, MIN_LANDMARKS, MAX_LANDMARKS)
	if landmark_display_names.size() != landmark_ids.size():
		errors.append("landmark display names must be parallel to IDs")
	if landmark_kind_ids.size() != landmark_ids.size():
		errors.append("landmark kinds must be parallel to IDs")
	if landmark_positions_body_local_m.size() != landmark_ids.size():
		errors.append("landmark positions must be parallel to IDs")
	var seen_kinds := {}
	for index in landmark_ids.size():
		if index < landmark_display_names.size() and _invalid_copy(landmark_display_names[index]):
			errors.append("landmark display name %d must be bounded single-line copy" % index)
		if index < landmark_kind_ids.size():
			_validate_id(errors, "landmark kind %d" % index, StringName(landmark_kind_ids[index]))
			seen_kinds[StringName(landmark_kind_ids[index])] = true
		if index < landmark_positions_body_local_m.size():
			var position := landmark_positions_body_local_m[index]
			if not _finite_vector(position) or position.length() > maximum_cluster_radius_m:
				errors.append("landmark position %d is outside the fixed cluster radius" % index)


func _validate_parallel_activities(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "activity_ids", activity_ids, MIN_ACTIVITIES, MAX_ACTIVITIES)
	var fields := [activity_display_names, activity_type_ids, activity_start_landmark_ids,
		activity_finish_landmark_ids, activity_route_ids, activity_authority_ids,
		activity_reward_ids, activity_return_incentive_ids, activity_recovery_ids]
	var field_names := ["display names", "types", "start landmarks", "finish landmarks",
		"routes", "authorities", "rewards", "return incentives", "recoveries"]
	for index in fields.size():
		if fields[index].size() != activity_ids.size():
			errors.append("activity %s must be parallel to IDs" % field_names[index])
	var landmark_set := {}
	for landmark_id in landmark_ids:
		landmark_set[StringName(landmark_id)] = true
	var type_set := {}
	for activity_type in activity_type_ids:
		var type_id := StringName(activity_type)
		_validate_id(errors, "activity type", type_id)
		type_set[type_id] = true
	for required_type in REQUIRED_ACTIVITY_TYPES:
		if not type_set.has(required_type):
			errors.append("activity cluster must include a %s activity" % required_type)
	for index in activity_ids.size():
		if index < activity_display_names.size() and _invalid_copy(activity_display_names[index]):
			errors.append("activity display name %d must be bounded single-line copy" % index)
		for list_index in [2, 3]:
			if list_index < fields.size() and index < fields[list_index].size():
				var landmark_id := StringName(fields[list_index][index])
				_validate_id(errors, "%s landmark %d" % [field_names[list_index], index], landmark_id)
				if not landmark_set.has(landmark_id):
					errors.append("activity %d references unknown landmark" % index)
		for list_index in [1, 4, 5, 6, 7, 8]:
			if list_index < fields.size() and index < fields[list_index].size():
				_validate_id(errors, "%s %d" % [field_names[list_index], index], StringName(fields[list_index][index]))


func _validate_id_list(errors: PackedStringArray, field_name: String, values: PackedStringArray, minimum: int, maximum: int) -> void:
	if values.size() < minimum or values.size() > maximum:
		errors.append("%s must contain %d to %d IDs" % [field_name, minimum, maximum])
	var seen := {}
	for value in values:
		var id := StringName(value)
		_validate_id(errors, "%s item" % field_name, id)
		if seen.has(id):
			errors.append("%s must not contain duplicate IDs" % field_name)
		seen[id] = true


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return


func _invalid_copy(value: String) -> bool:
	return value.is_empty() or value.length() > MAX_NAME_LENGTH or value.contains("\n")


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
