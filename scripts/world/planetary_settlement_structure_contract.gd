class_name PlanetarySettlementStructureContract
extends Resource

## Bounded, hand-authored settlement content for one visitable planetary
## landing region.
##
## This resource is a declaration shared by world, navigation, activity,
## reward, and recovery owners. It deliberately does not generate scenery,
## stream a location, resolve a hazard, move an actor, or grant a reward.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_ITEMS := 32
const MIN_LANDING_SITES := 1
const MIN_STRUCTURES := 3
const MIN_LANDMARKS := 4
const MIN_HAZARDS := 2
const MIN_ACTIVITIES := 2
const MIN_REWARDS := 1
const MIN_RECOVERIES := 1
const MAX_SETTLEMENT_RADIUS_M := 100_000.0
const STRUCTURE_KINDS := [
	&"habitat",
	&"operations",
	&"processing",
	&"relay",
	&"shelter",
	&"landing_support",
]

@export_category("Identity and scale")
@export var world_id: StringName = &"ember_moon"
@export var settlement_id: StringName = &"ember_caldera_settlement"
@export var display_name := "Ember Caldera Settlement"
@export var return_target_id: StringName = &"mudds_shipyards"
@export_range(1.0, MAX_SETTLEMENT_RADIUS_M, 1.0)
var authored_radius_m := 720.0

@export_category("Authored landing sites")
@export var landing_site_ids := PackedStringArray([
	"ember_caldera_pad",
	"ember_caldera_service_pad",
])
@export var landing_site_display_names := PackedStringArray([
	"Caldera Landing Pad",
	"Caldera Service Pad",
])
@export var landing_site_route_ids := PackedStringArray([
	"ember_pad_to_settlement_spine",
	"ember_service_pad_to_relay",
])
@export var landing_site_positions_body_local_m := PackedVector3Array([
	Vector3(18.0, 120000.0, 0.0),
	Vector3(132.0, 120002.0, -36.0),
])

@export_category("Authored structures")
@export var structure_ids := PackedStringArray([
	"ember_habitat_spine",
	"ember_operations_relay",
	"ember_fabrication_annex",
	"ember_surface_shelter",
])
@export var structure_display_names := PackedStringArray([
	"Habitat Spine",
	"Operations Relay",
	"Fabrication Annex",
	"Surface Shelter",
])
@export var structure_kind_ids := PackedStringArray([
	"habitat",
	"operations",
	"processing",
	"shelter",
])
@export var structure_positions_body_local_m := PackedVector3Array([
	Vector3(92.0, 120000.5, -18.0),
	Vector3(164.0, 120001.0, -42.0),
	Vector3(238.0, 120004.0, -70.0),
	Vector3(310.0, 120008.0, -92.0),
])
@export var structure_route_ids := PackedStringArray([
	"ember_pad_to_settlement_spine",
	"ember_settlement_spine_to_relay",
	"ember_relay_to_fabrication",
	"ember_fabrication_to_shelter",
])

@export_category("Landmarks and hazards")
@export var landmark_ids := PackedStringArray([
	"ember_settlement_gate",
	"ember_relay_tower",
	"ember_fabrication_crane",
	"ember_caldera_overlook",
	"ember_return_beacon",
])
@export var landmark_display_names := PackedStringArray([
	"Settlement Gate",
	"Relay Tower",
	"Fabrication Crane",
	"Caldera Overlook",
	"Return Beacon",
])
@export var landmark_kind_ids := PackedStringArray([
	"entrance",
	"navigation_beacon",
	"activity_marker",
	"overlook",
	"return_beacon",
])
@export var landmark_route_ids := PackedStringArray([
	"ember_pad_to_settlement_spine",
	"ember_settlement_spine_to_relay",
	"ember_relay_to_fabrication",
	"ember_fabrication_to_shelter",
	"ember_return_route",
])
@export var landmark_positions_body_local_m := PackedVector3Array([
	Vector3(70.0, 120000.0, -10.0),
	Vector3(180.0, 120009.0, -44.0),
	Vector3(260.0, 120012.0, -74.0),
	Vector3(420.0, 120025.0, -180.0),
	Vector3(540.0, 120030.0, -210.0),
])

@export var hazard_ids := PackedStringArray([
	"ember_thermal_vent",
	"ember_unstable_slope",
	"ember_relay_arc",
])
@export var hazard_display_names := PackedStringArray([
	"Thermal Vent",
	"Unstable Slope",
	"Relay Arc",
])
@export var hazard_kind_ids := PackedStringArray([
	"exposed_reactor",
	"unstable_terrain",
	"exposed_reactor",
])
@export var hazard_route_ids := PackedStringArray([
	"ember_relay_to_fabrication",
	"ember_fabrication_to_shelter",
	"ember_settlement_spine_to_relay",
])
@export var hazard_recovery_ids := PackedStringArray([
	"recover_at_surface_shelter",
	"return_to_landed_ship",
	"abort_to_orbit_return",
])
@export var hazard_positions_body_local_m := PackedVector3Array([
	Vector3(222.0, 120004.0, -64.0),
	Vector3(296.0, 120009.0, -96.0),
	Vector3(176.0, 120006.0, -32.0),
])

@export_category("Activity, reward, and recovery handoffs")
@export var activity_ids := PackedStringArray([
	"ember_settlement_supply_run",
	"ember_relay_repair",
	"ember_shelter_recovery",
])
@export var activity_display_names := PackedStringArray([
	"Settlement Supply Run",
	"Relay Repair",
	"Shelter Recovery",
])
@export var activity_start_landmark_ids := PackedStringArray([
	"ember_settlement_gate",
	"ember_relay_tower",
	"ember_caldera_overlook",
])
@export var activity_finish_landmark_ids := PackedStringArray([
	"ember_fabrication_crane",
	"ember_return_beacon",
	"ember_return_beacon",
])
@export var activity_authority_ids := PackedStringArray([
	"cargo_delivery_activity",
	"activity_director",
	"activity_director",
])
@export var activity_reward_ids := PackedStringArray([
	"ember_settlement_supplies",
	"ember_relay_repair_data",
	"ember_shelter_access",
])
@export var activity_recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"recover_at_surface_shelter",
	"abort_to_orbit_return",
])
@export var reward_ids := PackedStringArray([
	"ember_settlement_supplies",
	"ember_relay_repair_data",
	"ember_shelter_access",
])
@export var recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"recover_at_surface_shelter",
	"abort_to_orbit_return",
])

@export_category("Authority and evidence")
@export var activity_authority_id: StringName = &"activity_director"
@export var reward_authority_id: StringName = &"game_flow_reward_authority"
@export var recovery_authority_id: StringName = &"planetary_landing_return_contract"
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Fixed, authored Ember settlement and surface routes. This is a modern "
	+ "interpretation and never a procedural settlement generator."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "settlement_id", settlement_id)
	_validate_id(errors, "return_target_id", return_target_id)
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	if not is_finite(authored_radius_m) or authored_radius_m <= 0.0 or authored_radius_m > MAX_SETTLEMENT_RADIUS_M:
		errors.append("authored_radius_m is outside the bounded settlement envelope")
	_validate_parallel_landing_sites(errors)
	_validate_parallel_structures(errors)
	_validate_parallel_landmarks(errors)
	_validate_parallel_hazards(errors)
	_validate_parallel_activities(errors)
	_validate_id_list(errors, "reward_ids", reward_ids, MIN_REWARDS)
	_validate_id_list(errors, "recovery_ids", recovery_ids, MIN_RECOVERIES)
	_validate_id(errors, "activity_authority_id", activity_authority_id)
	_validate_id(errors, "reward_authority_id", reward_authority_id)
	_validate_id(errors, "recovery_authority_id", recovery_authority_id)
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
			"settlement_id": settlement_id,
			"display_name": display_name,
			"return_target_id": return_target_id,
		},
		"scale": {"authored_radius_m": authored_radius_m},
		"landing_sites": _landing_site_snapshot(),
		"structures": _structure_snapshot(),
		"landmarks": _landmark_snapshot(),
		"hazards": _hazard_snapshot(),
		"activities": _activity_snapshot(),
		"handoffs": {
			"reward_ids": reward_ids.duplicate(),
			"recovery_ids": recovery_ids.duplicate(),
			"activity_authority_id": activity_authority_id,
			"reward_authority_id": reward_authority_id,
			"recovery_authority_id": recovery_authority_id,
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
			"hazard": false,
			"activity": false,
			"reward": false,
			"recovery": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {"schema_version": SCHEMA_VERSION, "valid": errors.is_empty(), "errors": errors, "snapshot": get_snapshot()}.duplicate(true)


func _landing_site_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in landing_site_ids.size():
		result.append({
			"id": StringName(landing_site_ids[index]),
			"display_name": String(landing_site_display_names[index]) if index < landing_site_display_names.size() else "",
			"route_id": StringName(landing_site_route_ids[index]) if index < landing_site_route_ids.size() else &"",
			"position_body_local_m": landing_site_positions_body_local_m[index] if index < landing_site_positions_body_local_m.size() else Vector3.ZERO,
		})
	return result


func _structure_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in structure_ids.size():
		result.append({
			"id": StringName(structure_ids[index]),
			"display_name": String(structure_display_names[index]) if index < structure_display_names.size() else "",
			"kind": StringName(structure_kind_ids[index]) if index < structure_kind_ids.size() else &"",
			"position_body_local_m": structure_positions_body_local_m[index] if index < structure_positions_body_local_m.size() else Vector3.ZERO,
			"route_id": StringName(structure_route_ids[index]) if index < structure_route_ids.size() else &"",
		})
	return result


func _landmark_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in landmark_ids.size():
		result.append({
			"id": StringName(landmark_ids[index]),
			"display_name": String(landmark_display_names[index]) if index < landmark_display_names.size() else "",
			"kind": StringName(landmark_kind_ids[index]) if index < landmark_kind_ids.size() else &"",
			"route_id": StringName(landmark_route_ids[index]) if index < landmark_route_ids.size() else &"",
			"position_body_local_m": landmark_positions_body_local_m[index] if index < landmark_positions_body_local_m.size() else Vector3.ZERO,
		})
	return result


func _hazard_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in hazard_ids.size():
		result.append({
			"id": StringName(hazard_ids[index]),
			"display_name": String(hazard_display_names[index]) if index < hazard_display_names.size() else "",
			"kind": StringName(hazard_kind_ids[index]) if index < hazard_kind_ids.size() else &"",
			"route_id": StringName(hazard_route_ids[index]) if index < hazard_route_ids.size() else &"",
			"recovery_id": StringName(hazard_recovery_ids[index]) if index < hazard_recovery_ids.size() else &"",
			"position_body_local_m": hazard_positions_body_local_m[index] if index < hazard_positions_body_local_m.size() else Vector3.ZERO,
		})
	return result


func _activity_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in activity_ids.size():
		result.append({
			"id": StringName(activity_ids[index]),
			"display_name": String(activity_display_names[index]) if index < activity_display_names.size() else "",
			"start_landmark_id": StringName(activity_start_landmark_ids[index]) if index < activity_start_landmark_ids.size() else &"",
			"finish_landmark_id": StringName(activity_finish_landmark_ids[index]) if index < activity_finish_landmark_ids.size() else &"",
			"authority_id": StringName(activity_authority_ids[index]) if index < activity_authority_ids.size() else &"",
			"reward_id": StringName(activity_reward_ids[index]) if index < activity_reward_ids.size() else &"",
			"recovery_id": StringName(activity_recovery_ids[index]) if index < activity_recovery_ids.size() else &"",
		})
	return result


func _validate_parallel_landing_sites(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "landing_site_ids", landing_site_ids, MIN_LANDING_SITES)
	if landing_site_display_names.size() != landing_site_ids.size():
		errors.append("landing site display names must be parallel to IDs")
	if landing_site_route_ids.size() != landing_site_ids.size():
		errors.append("landing site routes must be parallel to IDs")
	if landing_site_positions_body_local_m.size() != landing_site_ids.size():
		errors.append("landing site positions must be parallel to IDs")
	_validate_positions(errors, "landing site", landing_site_positions_body_local_m)
	_validate_copies(errors, "landing site display name", landing_site_display_names)
	_validate_route_ids(errors, "landing site route", landing_site_route_ids)


func _validate_parallel_structures(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "structure_ids", structure_ids, MIN_STRUCTURES)
	if structure_display_names.size() != structure_ids.size():
		errors.append("structure display names must be parallel to IDs")
	if structure_kind_ids.size() != structure_ids.size():
		errors.append("structure kinds must be parallel to IDs")
	if structure_positions_body_local_m.size() != structure_ids.size():
		errors.append("structure positions must be parallel to IDs")
	if structure_route_ids.size() != structure_ids.size():
		errors.append("structure routes must be parallel to IDs")
	_validate_positions(errors, "structure", structure_positions_body_local_m)
	_validate_copies(errors, "structure display name", structure_display_names)
	_validate_route_ids(errors, "structure route", structure_route_ids)
	for index in structure_kind_ids.size():
		if not STRUCTURE_KINDS.has(StringName(structure_kind_ids[index])):
			errors.append("structure kind %d is not an authored kind" % index)


func _validate_parallel_landmarks(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "landmark_ids", landmark_ids, MIN_LANDMARKS)
	if landmark_display_names.size() != landmark_ids.size():
		errors.append("landmark display names must be parallel to IDs")
	if landmark_kind_ids.size() != landmark_ids.size():
		errors.append("landmark kinds must be parallel to IDs")
	if landmark_route_ids.size() != landmark_ids.size():
		errors.append("landmark routes must be parallel to IDs")
	if landmark_positions_body_local_m.size() != landmark_ids.size():
		errors.append("landmark positions must be parallel to IDs")
	_validate_positions(errors, "landmark", landmark_positions_body_local_m)
	_validate_copies(errors, "landmark display name", landmark_display_names)
	_validate_route_ids(errors, "landmark route", landmark_route_ids)
	_validate_route_ids(errors, "landmark kind", landmark_kind_ids)


func _validate_parallel_hazards(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "hazard_ids", hazard_ids, MIN_HAZARDS)
	if hazard_display_names.size() != hazard_ids.size():
		errors.append("hazard display names must be parallel to IDs")
	if hazard_kind_ids.size() != hazard_ids.size():
		errors.append("hazard kinds must be parallel to IDs")
	if hazard_route_ids.size() != hazard_ids.size():
		errors.append("hazard routes must be parallel to IDs")
	if hazard_recovery_ids.size() != hazard_ids.size():
		errors.append("hazard recoveries must be parallel to IDs")
	if hazard_positions_body_local_m.size() != hazard_ids.size():
		errors.append("hazard positions must be parallel to IDs")
	_validate_positions(errors, "hazard", hazard_positions_body_local_m)
	_validate_copies(errors, "hazard display name", hazard_display_names)
	_validate_route_ids(errors, "hazard kind", hazard_kind_ids)
	_validate_route_ids(errors, "hazard route", hazard_route_ids)
	_validate_route_ids(errors, "hazard recovery", hazard_recovery_ids)


func _validate_parallel_activities(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "activity_ids", activity_ids, MIN_ACTIVITIES)
	if activity_display_names.size() != activity_ids.size():
		errors.append("activity display names must be parallel to IDs")
	if activity_start_landmark_ids.size() != activity_ids.size():
		errors.append("activity starts must be parallel to IDs")
	if activity_finish_landmark_ids.size() != activity_ids.size():
		errors.append("activity finishes must be parallel to IDs")
	if activity_authority_ids.size() != activity_ids.size():
		errors.append("activity authorities must be parallel to IDs")
	if activity_reward_ids.size() != activity_ids.size():
		errors.append("activity rewards must be parallel to IDs")
	if activity_recovery_ids.size() != activity_ids.size():
		errors.append("activity recoveries must be parallel to IDs")
	_validate_copies(errors, "activity display name", activity_display_names)
	_validate_route_ids(errors, "activity start", activity_start_landmark_ids)
	_validate_route_ids(errors, "activity finish", activity_finish_landmark_ids)
	_validate_route_ids(errors, "activity authority", activity_authority_ids)
	_validate_route_ids(errors, "activity reward", activity_reward_ids)
	_validate_route_ids(errors, "activity recovery", activity_recovery_ids)
	var landmarks := {}
	for value in landmark_ids:
		landmarks[StringName(value)] = true
	var rewards := {}
	for value in reward_ids:
		rewards[StringName(value)] = true
	var recoveries := {}
	for value in recovery_ids:
		recoveries[StringName(value)] = true
	for index in activity_ids.size():
		if index < activity_start_landmark_ids.size() and not landmarks.has(StringName(activity_start_landmark_ids[index])):
			errors.append("unknown activity start landmark %d" % index)
		if index < activity_finish_landmark_ids.size() and not landmarks.has(StringName(activity_finish_landmark_ids[index])):
			errors.append("unknown activity finish landmark %d" % index)
		if index < activity_reward_ids.size() and not rewards.has(StringName(activity_reward_ids[index])):
			errors.append("unknown activity reward %d" % index)
		if index < activity_recovery_ids.size() and not recoveries.has(StringName(activity_recovery_ids[index])):
			errors.append("unknown activity recovery %d" % index)


func _validate_positions(errors: PackedStringArray, label: String, positions: PackedVector3Array) -> void:
	for index in positions.size():
		if not _finite_vector(positions[index]):
			errors.append("%s position %d must be finite" % [label, index])
		elif positions[index].length() > MAX_SETTLEMENT_RADIUS_M * 2.0:
			errors.append("%s position %d exceeds authored settlement radius" % [label, index])


func _validate_copies(errors: PackedStringArray, label: String, values: PackedStringArray) -> void:
	for index in values.size():
		if values[index].is_empty() or values[index].length() > MAX_NAME_LENGTH or values[index].contains("\n"):
			errors.append("%s %d must be bounded single-line copy" % [label, index])


func _validate_route_ids(errors: PackedStringArray, label: String, values: PackedStringArray) -> void:
	for index in values.size():
		_validate_id(errors, "%s %d" % [label, index], StringName(values[index]))


func _validate_id_list(errors: PackedStringArray, field_name: String, values: PackedStringArray, minimum: int) -> void:
	if values.size() < minimum or values.size() > MAX_ITEMS:
		errors.append("%s must contain %d to %d unique IDs" % [field_name, minimum, MAX_ITEMS])
	var seen := {}
	for index in values.size():
		var value := StringName(values[index])
		_validate_id(errors, "%s[%d]" % [field_name, index], value)
		if seen.has(value):
			errors.append("%s must not contain duplicate IDs: %s" % [field_name, value])
		seen[value] = true


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
