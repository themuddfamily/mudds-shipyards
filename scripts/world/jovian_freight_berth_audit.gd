class_name JovianFreightBerthAudit
extends RefCounted

## Strongly typed, detached audit snapshot for JovianFreightBerth.
##
## Callers receive a new instance for every request, so inspecting or mutating a
## snapshot cannot change the live module. `to_dictionary()` exists for tooling
## that cannot consume typed RefCounted reports yet.

var schema_version: int
var module_id: StringName
var valid: bool
var errors: PackedStringArray
var evidence_status: StringName
var creator_supported_identity: bool
var authenticated_original_geometry: bool
var berth_id: StringName
var berth_valid: bool
var route_ids: Array[StringName]
var cargo_unit_count: int
var service_detail_count: int
var animated_equipment_count: int
var footprint: Dictionary
var ship_clearance: Dictionary
var equipment_motion: Dictionary
## Collision-backed freight-handling infrastructure, and its class breakdown.
## Appended rather than folded into `service_detail_count`: the service count is
## the control room and dock systems, and a berth can be richly detailed indoors
## while its apron is still an empty slab.
var handling_fixture_count: int
var handling_fixture_classes: Dictionary


func _init(
		p_schema_version: int,
		p_module_id: StringName,
		p_valid: bool,
		p_errors: PackedStringArray,
		p_evidence_status: StringName,
		p_creator_supported_identity: bool,
		p_authenticated_original_geometry: bool,
		p_berth_id: StringName,
		p_berth_valid: bool,
		p_route_ids: Array[StringName],
		p_cargo_unit_count: int,
		p_service_detail_count: int,
		p_animated_equipment_count: int,
		p_footprint: Dictionary,
		p_ship_clearance: Dictionary,
		p_equipment_motion: Dictionary,
		p_handling_fixture_count: int,
		p_handling_fixture_classes: Dictionary
	) -> void:
	schema_version = p_schema_version
	module_id = p_module_id
	valid = p_valid
	errors = p_errors.duplicate()
	evidence_status = p_evidence_status
	creator_supported_identity = p_creator_supported_identity
	authenticated_original_geometry = p_authenticated_original_geometry
	berth_id = p_berth_id
	berth_valid = p_berth_valid
	route_ids = p_route_ids.duplicate()
	cargo_unit_count = p_cargo_unit_count
	service_detail_count = p_service_detail_count
	animated_equipment_count = p_animated_equipment_count
	footprint = p_footprint.duplicate(true)
	ship_clearance = p_ship_clearance.duplicate(true)
	equipment_motion = p_equipment_motion.duplicate(true)
	handling_fixture_count = p_handling_fixture_count
	handling_fixture_classes = p_handling_fixture_classes.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"module_id": module_id,
		"valid": valid,
		"errors": errors.duplicate(),
		"evidence_status": evidence_status,
		"creator_supported_identity": creator_supported_identity,
		"authenticated_original_geometry": authenticated_original_geometry,
		"berth_id": berth_id,
		"berth_valid": berth_valid,
		"route_ids": route_ids.duplicate(),
		"cargo_unit_count": cargo_unit_count,
		"service_detail_count": service_detail_count,
		"animated_equipment_count": animated_equipment_count,
		"footprint": footprint.duplicate(true),
		"ship_clearance": ship_clearance.duplicate(true),
		"equipment_motion": equipment_motion.duplicate(true),
		"handling_fixture_count": handling_fixture_count,
		"handling_fixture_classes": handling_fixture_classes.duplicate(true),
	}
