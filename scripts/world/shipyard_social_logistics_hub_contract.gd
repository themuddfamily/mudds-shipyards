class_name ShipyardSocialLogisticsHubContract
extends Resource

## Fixed handoff contract for Mudds Shipyards as the nearby-world hub.
##
## The hub is an authored social/logistics anchor, not a world generator. It
## records the station services that activities return to and the existing
## authorities which may consume those handoffs. It does not create scenery,
## move actors, resolve objectives, transfer cargo, grant rewards, or own a
## procedural galaxy.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_SERVICES := 12
const MAX_ACTIVITIES := 8
const MAX_RETURN_TIME_S := 900.0
const MAX_ACTIVITY_RADIUS_M := 2_000.0
const REQUIRED_HEART_ROLES := [&"social", &"logistics", &"return_anchor"]
const REQUIRED_SERVICE_KINDS := [&"social", &"logistics", &"activity", &"return"]

@export_category("Authored hub identity")
@export var station_id: StringName = &"mudds_shipyards"
@export var hub_id: StringName = &"mudds_shipyards_social_logistics_hub"
@export var display_name := "Mudds Shipyards Social and Logistics Hub"
@export var return_target_id: StringName = &"mudds_shipyards"
@export var hub_role_ids := PackedStringArray([
	"social",
	"logistics",
	"return_anchor",
])
@export_range(1.0, MAX_RETURN_TIME_S, 1.0)
var maximum_return_time_s := 180.0
@export_range(1.0, MAX_ACTIVITY_RADIUS_M, 1.0)
var maximum_activity_radius_m := 900.0

@export_category("Fixed hub service anchors")
@export var service_ids := PackedStringArray([
	"crew_social_deck",
	"activity_board",
	"cargo_transfer_terminal",
	"shipyard_return_berth",
])
@export var service_display_names := PackedStringArray([
	"Crew Social Deck",
	"Activity Board",
	"Cargo Transfer Terminal",
	"Shipyard Return Berth",
])
@export var service_kind_ids := PackedStringArray([
	"social",
	"activity",
	"logistics",
	"return",
])
@export var service_authority_ids := PackedStringArray([
	"station_social_authority",
	"activity_director",
	"cargo_transfer_authority",
	"shipyard_return_authority",
])
@export var service_positions_station_local_m := PackedVector3Array([
	Vector3(-18.0, 0.0, -34.0),
	Vector3(12.0, 1.0, -26.0),
	Vector3(82.0, 0.0, -34.0),
	Vector3(0.0, 0.0, 0.0),
])

@export_category("Activity return handoffs")
@export var activity_ids := PackedStringArray([
	"shipyard_perimeter_defense",
	"cinder_kit_cargo_run",
	"cinder_relay_patrol",
	"ember_checkpoint_race",
	"ember_convoy_escort",
])
@export var activity_display_names := PackedStringArray([
	"Shipyard Perimeter Defense",
	"Fabrication Kit Cargo Run",
	"Cinder Relay Patrol",
	"Ember Checkpoint Race",
	"Emberline Convoy Escort",
])
@export var activity_type_ids := PackedStringArray([
	"station_defense",
	"cargo",
	"patrol",
	"race",
	"convoy",
])
@export var activity_start_service_ids := PackedStringArray([
	"activity_board",
	"cargo_transfer_terminal",
	"activity_board",
	"activity_board",
	"activity_board",
])
@export var activity_handoff_authority_ids := PackedStringArray([
	"station_defense_encounter_host",
	"cargo_delivery_activity",
	"patrol_activity",
	"timed_checkpoint_race",
	"convoy_escort_activity",
])
@export var activity_return_route_ids := PackedStringArray([
	"shipyard_defense_return_route",
	"cinder_cargo_return_route",
	"cinder_patrol_return_route",
	"ember_race_return_route",
	"ember_convoy_return_route",
])
@export var activity_return_incentive_ids := PackedStringArray([
	"return_defense_report_to_shipyard",
	"return_fabrication_kits_to_shipyard",
	"return_patrol_log_to_shipyard",
	"return_race_record_to_shipyard",
	"return_convoy_credit_to_shipyard",
])
@export var activity_finish_service_ids := PackedStringArray([
	"shipyard_return_berth",
	"shipyard_return_berth",
	"shipyard_return_berth",
	"shipyard_return_berth",
	"shipyard_return_berth",
])
@export var activity_recovery_ids := PackedStringArray([
	"recover_at_shipyard_berth",
	"return_to_landed_ship",
	"abort_to_shipyard_return",
	"reset_at_shipyard_board",
	"recover_convoy_at_shipyard_berth",
])

@export_category("Evidence")
@export var evidence_references := PackedStringArray([
	"res://ROADMAP.md",
	"res://scripts/world/shipyard_activity_cluster_contract.gd",
])
@export_multiline var evidence_notes := (
	"Mudds Shipyards remains the fixed social and logistical heart for nearby "
	+ "authored activities. Return incentives and service handoffs are explicit; "
	+ "this contract does not imply a procedural galaxy or historical recovery."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "station_id", station_id)
	_validate_id(errors, "hub_id", hub_id)
	_validate_id(errors, "return_target_id", return_target_id)
	if station_id != return_target_id:
		errors.append("return_target_id must identify the shipyard station")
	if hub_id != &"mudds_shipyards_social_logistics_hub":
		errors.append("hub_id must identify the fixed shipyard social/logistics hub")
	if _invalid_copy(display_name):
		errors.append("display_name must be bounded single-line copy")
	if not is_finite(maximum_return_time_s) or maximum_return_time_s <= 0.0 \
		or maximum_return_time_s > MAX_RETURN_TIME_S:
		errors.append("maximum_return_time_s is outside the bounded return envelope")
	if not is_finite(maximum_activity_radius_m) or maximum_activity_radius_m <= 0.0 \
		or maximum_activity_radius_m > MAX_ACTIVITY_RADIUS_M:
		errors.append("maximum_activity_radius_m is outside the bounded activity envelope")
	_validate_id_list(errors, "hub_role_ids", hub_role_ids, 3, 6)
	for required_role in REQUIRED_HEART_ROLES:
		if not hub_role_ids.has(String(required_role)):
			errors.append("hub must expose the %s heart role" % String(required_role))
	_validate_services(errors)
	_validate_activities(errors)
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


func get_service(index: int) -> Dictionary:
	if index < 0 or index >= service_ids.size():
		return {}
	return {
		"id": StringName(service_ids[index]),
		"display_name": String(service_display_names[index]),
		"kind": StringName(service_kind_ids[index]),
		"authority_id": StringName(service_authority_ids[index]),
		"position_station_local_m": service_positions_station_local_m[index],
	}


func get_service_by_id(requested_id: StringName) -> Dictionary:
	for index in service_ids.size():
		if StringName(service_ids[index]) == requested_id:
			return get_service(index)
	return {}


func get_activity(index: int) -> Dictionary:
	if index < 0 or index >= activity_ids.size():
		return {}
	return {
		"id": StringName(activity_ids[index]),
		"display_name": String(activity_display_names[index]),
		"type": StringName(activity_type_ids[index]),
		"start_service_id": StringName(activity_start_service_ids[index]),
		"handoff_authority_id": StringName(activity_handoff_authority_ids[index]),
		"return_route_id": StringName(activity_return_route_ids[index]),
		"return_incentive_id": StringName(activity_return_incentive_ids[index]),
		"finish_service_id": StringName(activity_finish_service_ids[index]),
		"recovery_id": StringName(activity_recovery_ids[index]),
	}


func get_activity_by_id(requested_id: StringName) -> Dictionary:
	for index in activity_ids.size():
		if StringName(activity_ids[index]) == requested_id:
			return get_activity(index)
	return {}


func get_snapshot() -> Dictionary:
	var services: Array[Dictionary] = []
	for index in service_ids.size():
		services.append(get_service(index))
	var activities: Array[Dictionary] = []
	for index in activity_ids.size():
		activities.append(get_activity(index))
	return {
		"schema_version": SCHEMA_VERSION,
		"identity": {
			"station_id": station_id,
			"hub_id": hub_id,
			"display_name": display_name,
			"return_target_id": return_target_id,
			"heart_roles": hub_role_ids.duplicate(),
		},
		"scale": {
			"maximum_return_time_s": maximum_return_time_s,
			"maximum_activity_radius_m": maximum_activity_radius_m,
		},
		"services": services,
		"activities": activities,
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"procedural_galaxy": false,
			"references": evidence_references.duplicate(),
		},
		"authority": {
			"social": false,
			"logistics": false,
			"activity": false,
			"movement": false,
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


func _validate_services(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "service_ids", service_ids, 4, MAX_SERVICES)
	var fields := [service_display_names, service_kind_ids, service_authority_ids,
		service_positions_station_local_m]
	var names := ["display names", "kinds", "authorities", "positions"]
	for field_index in fields.size():
		if fields[field_index].size() != service_ids.size():
			errors.append("service %s must be parallel to IDs" % names[field_index])
	var kind_set := {}
	for index in service_ids.size():
		if index < service_display_names.size() and _invalid_copy(service_display_names[index]):
			errors.append("service display name %d must be bounded single-line copy" % index)
		if index < service_kind_ids.size():
			var kind := StringName(service_kind_ids[index])
			_validate_id(errors, "service kind", kind)
			kind_set[kind] = true
		if index < service_authority_ids.size():
			_validate_id(errors, "service authority", StringName(service_authority_ids[index]))
		if index < service_positions_station_local_m.size():
			var position := service_positions_station_local_m[index]
			if not _finite_vector(position) or position.length() > maximum_activity_radius_m:
				errors.append("service position %d is outside the fixed hub radius" % index)
	for required_kind in REQUIRED_SERVICE_KINDS:
		if not kind_set.has(required_kind):
			errors.append("hub must expose a %s service" % String(required_kind))


func _validate_activities(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "activity_ids", activity_ids, 1, MAX_ACTIVITIES)
	var fields := [activity_display_names, activity_type_ids, activity_start_service_ids,
		activity_handoff_authority_ids, activity_return_route_ids,
		activity_return_incentive_ids, activity_finish_service_ids, activity_recovery_ids]
	var names := ["display names", "types", "start services", "authorities",
		"return routes", "return incentives", "finish services", "recoveries"]
	for field_index in fields.size():
		if fields[field_index].size() != activity_ids.size():
			errors.append("activity %s must be parallel to IDs" % names[field_index])
	var service_set := {}
	for service_id in service_ids:
		service_set[StringName(service_id)] = true
	for index in activity_ids.size():
		if index < activity_display_names.size() and _invalid_copy(activity_display_names[index]):
			errors.append("activity display name %d must be bounded single-line copy" % index)
		if index < activity_type_ids.size():
			_validate_id(errors, "activity type", StringName(activity_type_ids[index]))
		for field_index in [2, 6]:
			if index < fields[field_index].size():
				var service_id := StringName(fields[field_index][index])
				_validate_id(errors, "activity service", service_id)
				if not service_set.has(service_id):
					errors.append("activity %d references unknown service" % index)
		for field_index in [3, 4, 5, 7]:
			if index < fields[field_index].size():
				var handoff := StringName(fields[field_index][index])
				_validate_id(errors, "activity handoff", handoff)
		if index < activity_return_route_ids.size() \
			and not String(activity_return_route_ids[index]).begins_with("shipyard_") \
			and not String(activity_return_route_ids[index]).contains("_return_"):
			errors.append("activity %d return route must explicitly target the shipyard" % index)
		if index < activity_return_incentive_ids.size() \
			and not String(activity_return_incentive_ids[index]).begins_with("return_"):
			errors.append("activity %d return incentive must begin with return_" % index)


func _validate_id_list(errors: PackedStringArray, field_name: String,
		values: PackedStringArray, minimum: int, maximum: int) -> void:
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
