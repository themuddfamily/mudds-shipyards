class_name PlanetaryWaterSurfaceMaterialContract
extends Resource

## Bounded authored water, surface-material, shoreline-hazard, and audio
## handoff for one planetary surface region.
##
## This Resource names authored material and route identities only. It never
## creates a mesh, binds a renderer material, simulates water, resolves a
## hazard, plays audio, or owns terrain/physics/streaming authority.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_CONTENT_ITEMS := 32
const MIN_MATERIAL_LAYERS := 3
const MIN_SHORELINE_HAZARDS := 2
const MATERIAL_KINDS := [
	&"water",
	&"shoreline",
	&"substrate",
]
const WATER_BODY_KINDS := [
	&"coastal_inlet",
	&"lake",
	&"river",
	&"ocean_shelf",
]
const SHORELINE_HAZARD_KINDS := [
	&"undertow",
	&"slippery_shore",
	&"unstable_bank",
	&"tide_cut",
]

@export_category("Identity")
@export var world_id: StringName = &"aurora_temperate_world"
@export var landing_region_id: StringName = &"aurora_foundation_landing"
@export var surface_feature_id: StringName = &"aurora_coastal_shelf"
@export var display_name := "Aurora Coastal Shelf"
@export var water_appropriate := true

@export_category("Authored water")
@export var water_body_id: StringName = &"aurora_coastal_shelf_water"
@export var water_body_kind: StringName = &"coastal_inlet"
@export var water_surface_material_id: StringName = &"aurora_water_surface"
@export var shoreline_material_id: StringName = &"aurora_wet_shoreline"
@export var substrate_material_id: StringName = &"aurora_shore_substrate"

@export_category("Material layers and audio routes")
## Material IDs are opaque authored keys. Their order is part of the handoff:
## water, shoreline, then supporting substrate.
@export var material_layer_ids := PackedStringArray([
	"aurora_water_surface",
	"aurora_wet_shoreline",
	"aurora_shore_substrate",
])
@export var material_layer_kinds := PackedStringArray([
	"water",
	"shoreline",
	"substrate",
])
@export var material_audio_route_ids := PackedStringArray([
	"planetary_water_surface",
	"planetary_shoreline_contact",
	"planetary_shore_substrate",
])
@export var audio_authority_id: StringName = &"planetary_surface_audio_policy"

@export_category("Recoverable shoreline hazards")
@export var shoreline_hazard_ids := PackedStringArray([
	"aurora_shelf_undertow",
	"aurora_slick_ledge",
])
@export var shoreline_hazard_kinds := PackedStringArray([
	"undertow",
	"slippery_shore",
])
@export var shoreline_hazard_positions_body_local_m := PackedVector3Array([
	Vector3(180.0, 120000.0, -240.0),
	Vector3(260.0, 120003.0, -198.0),
])
@export var shoreline_hazard_route_ids := PackedStringArray([
	"aurora_coastal_access_route",
	"aurora_coastal_access_route",
])
@export var shoreline_hazard_recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"recover_at_aurora_egress",
])

@export_category("Evidence")
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_SURFACE_AUDIO_POLICY.md",
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Bounded authored Aurora water and shoreline material handoff. Material "
	+ "and audio IDs are opaque; renderer, simulation, hazard, and playback "
	+ "ownership remain outside this declaration."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "landing_region_id", landing_region_id)
	_validate_id(errors, "surface_feature_id", surface_feature_id)
	_validate_id(errors, "water_body_id", water_body_id)
	_validate_id(errors, "water_surface_material_id", water_surface_material_id)
	_validate_id(errors, "shoreline_material_id", shoreline_material_id)
	_validate_id(errors, "substrate_material_id", substrate_material_id)
	_validate_id(errors, "audio_authority_id", audio_authority_id)
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	if not water_appropriate:
		errors.append("water_appropriate must be true for a water surface contract")
	if not WATER_BODY_KINDS.has(water_body_kind):
		errors.append("water_body_kind is not in the authored water catalog")
	_validate_material_layers(errors)
	_validate_parallel_hazards(errors)
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	for reference in evidence_references:
		if String(reference).length() > MAX_NOTE_LENGTH or not String(reference).begins_with("res://"):
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
			"landing_region_id": landing_region_id,
			"surface_feature_id": surface_feature_id,
			"display_name": display_name,
		},
		"water": {
			"water_appropriate": water_appropriate,
			"body_id": water_body_id,
			"body_kind": water_body_kind,
		},
		"materials": _material_snapshot(),
		"shoreline_hazards": _hazard_snapshot(),
		"audio": {
			"route_ids": material_audio_route_ids.duplicate(),
			"authority_id": audio_authority_id,
			"routes_are_opaque_hints": true,
			"profile_resolution_requested": false,
			"playback_requested": false,
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"references": evidence_references.duplicate(),
		},
		"authority": _authority_snapshot(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"authority": _authority_snapshot(),
	}.duplicate(true)


func _material_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in material_layer_ids.size():
		result.append({
			"id": StringName(material_layer_ids[index]),
			"kind": StringName(material_layer_kinds[index]) if index < material_layer_kinds.size() else &"",
			"audio_route_id": StringName(material_audio_route_ids[index]) if index < material_audio_route_ids.size() else &"",
		})
	return result


func _hazard_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in shoreline_hazard_ids.size():
		result.append({
			"id": StringName(shoreline_hazard_ids[index]),
			"kind": StringName(shoreline_hazard_kinds[index]) if index < shoreline_hazard_kinds.size() else &"",
			"position_body_local_m": shoreline_hazard_positions_body_local_m[index] if index < shoreline_hazard_positions_body_local_m.size() else Vector3.INF,
			"route_id": StringName(shoreline_hazard_route_ids[index]) if index < shoreline_hazard_route_ids.size() else &"",
			"recovery_id": StringName(shoreline_hazard_recovery_ids[index]) if index < shoreline_hazard_recovery_ids.size() else &"",
		})
	return result


func _authority_snapshot() -> Dictionary:
	return {
		"renderer": false,
		"material_binding": false,
		"water_simulation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"physics": false,
		"hazard_resolution": false,
		"audio_route_resolution": false,
		"audio_playback": false,
		"streaming": false,
		"save": false,
		"network": false,
	}


func _validate_material_layers(errors: PackedStringArray) -> void:
	if material_layer_ids.size() < MIN_MATERIAL_LAYERS or material_layer_ids.size() > MAX_CONTENT_ITEMS:
		errors.append("material_layer_ids must contain %d to %d IDs" % [MIN_MATERIAL_LAYERS, MAX_CONTENT_ITEMS])
	if material_layer_kinds.size() != material_layer_ids.size() or material_audio_route_ids.size() != material_layer_ids.size():
		errors.append("material layer IDs, kinds, and audio routes must remain parallel")
	var seen := {}
	for index in material_layer_ids.size():
		_validate_id(errors, "material layer %d" % index, StringName(material_layer_ids[index]))
		if seen.has(material_layer_ids[index]):
			errors.append("material_layer_ids must not contain duplicates")
		seen[material_layer_ids[index]] = true
		if index < material_layer_kinds.size() and StringName(material_layer_kinds[index]) != MATERIAL_KINDS[index] if index < MATERIAL_KINDS.size() else true:
			errors.append("material layer %d must use the authored water/shoreline/substrate order" % index)
		if index < material_audio_route_ids.size():
			_validate_id(errors, "material audio route %d" % index, StringName(material_audio_route_ids[index]))
	if material_layer_ids.size() >= MIN_MATERIAL_LAYERS:
		if StringName(material_layer_ids[0]) != water_surface_material_id:
			errors.append("water layer must match water_surface_material_id")
		if StringName(material_layer_ids[1]) != shoreline_material_id:
			errors.append("shoreline layer must match shoreline_material_id")
		if StringName(material_layer_ids[2]) != substrate_material_id:
			errors.append("substrate layer must match substrate_material_id")


func _validate_parallel_hazards(errors: PackedStringArray) -> void:
	if shoreline_hazard_ids.size() < MIN_SHORELINE_HAZARDS or shoreline_hazard_ids.size() > MAX_CONTENT_ITEMS:
		errors.append("shoreline_hazard_ids must contain %d to %d IDs" % [MIN_SHORELINE_HAZARDS, MAX_CONTENT_ITEMS])
	if shoreline_hazard_kinds.size() != shoreline_hazard_ids.size():
		errors.append("shoreline hazard kinds must remain parallel to IDs")
	if shoreline_hazard_positions_body_local_m.size() != shoreline_hazard_ids.size():
		errors.append("shoreline hazard positions must remain parallel to IDs")
	if shoreline_hazard_route_ids.size() != shoreline_hazard_ids.size():
		errors.append("shoreline hazard routes must remain parallel to IDs")
	if shoreline_hazard_recovery_ids.size() != shoreline_hazard_ids.size():
		errors.append("shoreline hazard recoveries must remain parallel to IDs")
	var seen := {}
	for index in shoreline_hazard_ids.size():
		_validate_id(errors, "shoreline hazard %d" % index, StringName(shoreline_hazard_ids[index]))
		if seen.has(shoreline_hazard_ids[index]):
			errors.append("shoreline_hazard_ids must not contain duplicates")
		seen[shoreline_hazard_ids[index]] = true
		if index < shoreline_hazard_kinds.size() and not SHORELINE_HAZARD_KINDS.has(StringName(shoreline_hazard_kinds[index])):
			errors.append("shoreline hazard %d is not in the authored hazard catalog" % index)
		if index < shoreline_hazard_positions_body_local_m.size() and not _finite_vector(shoreline_hazard_positions_body_local_m[index]):
			errors.append("shoreline hazard position %d must be finite" % index)
		if index < shoreline_hazard_route_ids.size():
			_validate_id(errors, "shoreline hazard route %d" % index, StringName(shoreline_hazard_route_ids[index]))
		if index < shoreline_hazard_recovery_ids.size():
			_validate_id(errors, "shoreline hazard recovery %d" % index, StringName(shoreline_hazard_recovery_ids[index]))


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return
