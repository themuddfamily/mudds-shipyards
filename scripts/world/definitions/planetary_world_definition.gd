class_name PlanetaryWorldDefinition
extends Resource

## Side-effect-free identity, coordinate-frame, and dependency contract for one
## authored planetary destination.
##
## References are stable logical IDs or a project-local scene path. This
## Resource never loads a scene, streams terrain, starts gameplay, or persists
## session state. Those responsibilities remain with later composition owners.

enum EvidenceStatus {
	AUTHENTICATED = 0,
	BOUNDED_PARTIAL_RECONSTRUCTION = 1,
	PROVISIONAL_CANDIDATE = 2,
	MODERN_INTERPRETATION = 3,
	UNKNOWN = 4,
}

const SCHEMA_VERSION := 1
const UNIT_SYSTEM: StringName = &"game_scale_si"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_SCOPE: StringName = &"authored_planetary_destination"
const BODY_CENTRE_REFERENCE: StringName = &"scene_root"
const BODY_RADIUS_REFERENCE: StringName = &"sea_level"
const MAX_ID_LENGTH := 64
const MAX_DISPLAY_NAME_LENGTH := 96
const MAX_CONTENT_NOTE_LENGTH := 512
const MAX_SCENE_PATH_LENGTH := 256
const MAX_EVIDENCE_REFERENCES := 32
const MAX_EVIDENCE_REFERENCE_LENGTH := 192
const MAX_LANDING_REGION_REFERENCES := 32
const DEFAULT_BODY_RADIUS_METRES := 120_000.0
const MIN_BODY_RADIUS_METRES := 1_000.0
const MAX_BODY_RADIUS_METRES := 100_000_000.0
const MAX_ANCHOR_COMPONENT_METRES := 100_000_000.0
const ANCHOR_ORIGIN_EPSILON_METRES := 0.001
const BASIS_EPSILON := 0.0001

const EVIDENCE_AUTHENTICATED: StringName = &"authenticated"
const EVIDENCE_BOUNDED_PARTIAL: StringName = &"bounded_partial_reconstruction"
const EVIDENCE_PROVISIONAL: StringName = &"provisional_candidate"
const EVIDENCE_MODERN: StringName = &"modern_interpretation"
const EVIDENCE_UNKNOWN: StringName = &"unknown"

@export_category("Identity")
@export var world_id: StringName = &"unnamed_planetary_world"
@export var display_name := "Unnamed planetary world"
@export var sector_id: StringName = &"unnamed_sector"
@export_multiline var content_note := ""

@export_category("Scene reference")
@export_file("*.tscn") var scene_path := ""

@export_category("Coordinate-frame anchors")
## All four transforms are expressed relative to the future planetary scene
## root at the body centre. Their bases are unit-scale orthonormal frames; their
## origins use metres.
@export var scene_anchor_id: StringName = &"scene_origin"
@export var scene_anchor := Transform3D.IDENTITY
@export var navigation_anchor_id: StringName = &"navigation_anchor"
@export var navigation_anchor := Transform3D.IDENTITY
@export var orbital_anchor_id: StringName = &"orbital_anchor"
@export var orbital_anchor := Transform3D.IDENTITY
@export var surface_anchor_id: StringName = &"surface_anchor"
@export var surface_anchor := Transform3D.IDENTITY

@export_category("Planetary body")
@export_range(MIN_BODY_RADIUS_METRES, MAX_BODY_RADIUS_METRES, 1.0)
var body_radius_metres := DEFAULT_BODY_RADIUS_METRES
@export var has_atmosphere := false
## Empty is required for an airless body; otherwise this is a stable ID resolved
## by a future atmosphere catalog.
@export var atmosphere_definition_id: StringName = &""
## Stable logical reference resolved by a future terrain catalog.
@export var terrain_definition_id: StringName = &"unassigned_terrain"
## Ordered stable logical references. This schema requires at least one authored
## landing region and never resolves or owns the referenced regions.
@export var landing_region_ids := PackedStringArray()

@export_category("Evidence")
@export_enum(
	"Authenticated:0",
	"Bounded partial reconstruction:1",
	"Provisional candidate:2",
	"Modern interpretation:3",
	"Unknown:4"
)
var evidence_status: int = EvidenceStatus.MODERN_INTERPRETATION
@export var evidence_references := PackedStringArray()
@export_multiline var evidence_notes := ""


func get_evidence_status_id() -> StringName:
	match evidence_status:
		EvidenceStatus.AUTHENTICATED:
			return EVIDENCE_AUTHENTICATED
		EvidenceStatus.BOUNDED_PARTIAL_RECONSTRUCTION:
			return EVIDENCE_BOUNDED_PARTIAL
		EvidenceStatus.PROVISIONAL_CANDIDATE:
			return EVIDENCE_PROVISIONAL
		EvidenceStatus.MODERN_INTERPRETATION:
			return EVIDENCE_MODERN
		EvidenceStatus.UNKNOWN:
			return EVIDENCE_UNKNOWN
		_:
			return &"invalid"


func get_scene_anchor() -> Transform3D:
	return scene_anchor


func get_navigation_anchor() -> Transform3D:
	return navigation_anchor


func get_orbital_anchor() -> Transform3D:
	return orbital_anchor


func get_surface_anchor() -> Transform3D:
	return surface_anchor


func get_body_radius_metres() -> float:
	return body_radius_metres


## Canonical cross-contract accessor. The British-spelled exported field and
## compatibility getter remain stable for existing resources.
func get_body_radius_meters() -> float:
	return body_radius_metres


func get_orbital_anchor_radius_metres() -> float:
	return orbital_anchor.origin.length()


func get_surface_anchor_radius_metres() -> float:
	return surface_anchor.origin.length()


func get_landing_region_ids() -> PackedStringArray:
	return landing_region_ids.duplicate()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "world_id", world_id)
	_validate_stable_id(errors, "sector_id", sector_id)
	_validate_ui_copy(errors, "display_name", display_name, MAX_DISPLAY_NAME_LENGTH)
	_validate_bounded_note(errors, "content_note", content_note, true)
	_validate_scene_path(errors)

	var anchor_ids := PackedStringArray()
	_validate_anchor(errors, "scene", scene_anchor_id, scene_anchor, anchor_ids)
	_validate_anchor(
		errors,
		"navigation",
		navigation_anchor_id,
		navigation_anchor,
		anchor_ids
	)
	_validate_anchor(errors, "orbital", orbital_anchor_id, orbital_anchor, anchor_ids)
	_validate_anchor(errors, "surface", surface_anchor_id, surface_anchor, anchor_ids)

	_validate_range(
		errors,
		"body_radius_metres",
		body_radius_metres,
		MIN_BODY_RADIUS_METRES,
		MAX_BODY_RADIUS_METRES
	)
	_validate_anchor_radial_semantics(errors)
	if has_atmosphere:
		_validate_stable_id(
			errors,
			"atmosphere_definition_id",
			atmosphere_definition_id
		)
	elif not atmosphere_definition_id.is_empty():
		errors.append("airless bodies must not declare atmosphere_definition_id")
	_validate_stable_id(errors, "terrain_definition_id", terrain_definition_id)
	_validate_landing_regions(errors)
	_validate_evidence(errors)
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func audit() -> Dictionary:
	var errors := get_validation_errors()
	var warnings := PackedStringArray()
	if evidence_status == EvidenceStatus.AUTHENTICATED:
		warnings.append(
			"authenticated status still requires manual evidence review outside this resource"
		)
	if evidence_status == EvidenceStatus.MODERN_INTERPRETATION \
			and not evidence_references.is_empty():
		warnings.append(
			"modern-interpretation references record provenance, not historical authentication"
		)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"unit_system": UNIT_SYSTEM,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"world_id": world_id,
		"display_name": display_name,
		"sector_id": sector_id,
		"content_note": content_note,
		"scene_path": scene_path,
		"anchors": {
			"scene": {"anchor_id": scene_anchor_id, "transform": scene_anchor},
			"navigation": {
				"anchor_id": navigation_anchor_id,
				"transform": navigation_anchor,
			},
			"orbital": {"anchor_id": orbital_anchor_id, "transform": orbital_anchor},
			"surface": {"anchor_id": surface_anchor_id, "transform": surface_anchor},
		},
		"body": {
			"radius_metres": body_radius_metres,
			"centre_reference": BODY_CENTRE_REFERENCE,
			"radius_reference": BODY_RADIUS_REFERENCE,
			"has_atmosphere": has_atmosphere,
			"atmosphere_definition_id": atmosphere_definition_id,
			"terrain_definition_id": terrain_definition_id,
			"landing_region_ids": landing_region_ids.duplicate(),
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": get_evidence_status_id(),
			"scope": EVIDENCE_SCOPE,
			"historical_claim": evidence_status in [
				EvidenceStatus.AUTHENTICATED,
				EvidenceStatus.BOUNDED_PARTIAL_RECONSTRUCTION,
				EvidenceStatus.PROVISIONAL_CANDIDATE,
			],
			"authenticated": evidence_status == EvidenceStatus.AUTHENTICATED,
			"manual_review_required": evidence_status == EvidenceStatus.AUTHENTICATED,
			"references": evidence_references.duplicate(),
			"notes": evidence_notes,
		},
		"authority": {
			"renderer": false,
			"gameplay": false,
			"streaming": false,
			"save": false,
			"network": false,
			"physics": false,
			"world_generation": false,
			"terrain_generation": false,
			"collision_generation": false,
			"origin_shift": false,
			"weather_clock": false,
			"audio": false,
		},
		"gameplay_authority": false,
		"streaming_authority": false,
		"save_authority": false,
	}
	return report.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func duplicate_definition() -> PlanetaryWorldDefinition:
	var copy := PlanetaryWorldDefinition.new()
	copy.world_id = world_id
	copy.display_name = display_name
	copy.sector_id = sector_id
	copy.content_note = content_note
	copy.scene_path = scene_path
	copy.scene_anchor_id = scene_anchor_id
	copy.scene_anchor = scene_anchor
	copy.navigation_anchor_id = navigation_anchor_id
	copy.navigation_anchor = navigation_anchor
	copy.orbital_anchor_id = orbital_anchor_id
	copy.orbital_anchor = orbital_anchor
	copy.surface_anchor_id = surface_anchor_id
	copy.surface_anchor = surface_anchor
	copy.body_radius_metres = body_radius_metres
	copy.has_atmosphere = has_atmosphere
	copy.atmosphere_definition_id = atmosphere_definition_id
	copy.terrain_definition_id = terrain_definition_id
	copy.landing_region_ids = landing_region_ids.duplicate()
	copy.evidence_status = evidence_status
	copy.evidence_references = evidence_references.duplicate()
	copy.evidence_notes = evidence_notes
	return copy


func _validate_scene_path(errors: PackedStringArray) -> void:
	if scene_path.is_empty() \
			or scene_path != scene_path.strip_edges() \
			or scene_path.length() > MAX_SCENE_PATH_LENGTH \
			or not scene_path.begins_with("res://") \
			or not scene_path.ends_with(".tscn") \
			or scene_path.contains("\\") \
			or scene_path.contains("..") \
			or _contains_line_break(scene_path):
		errors.append(
			"scene_path must be a trimmed res:// .tscn path of at most %d characters without traversal"
			% MAX_SCENE_PATH_LENGTH
		)


func _validate_anchor(
		errors: PackedStringArray,
		label: String,
		anchor_id: StringName,
		anchor_transform: Transform3D,
		seen_ids: PackedStringArray
	) -> void:
	_validate_stable_id(errors, "%s_anchor_id" % label, anchor_id)
	if seen_ids.has(anchor_id):
		errors.append("%s_anchor_id duplicates another anchor identity" % label)
	else:
		seen_ids.append(anchor_id)
	if not _is_finite_transform(anchor_transform):
		errors.append("%s_anchor must contain only finite values" % label)
		return
	if not _is_anchor_origin_bounded(anchor_transform.origin):
		errors.append(
			"%s_anchor origin components must not exceed %s metres"
			% [label, MAX_ANCHOR_COMPONENT_METRES]
		)
	if not _is_orthonormal_basis(anchor_transform.basis):
		errors.append("%s_anchor basis must be unit-scale and orthonormal" % label)


func _validate_anchor_radial_semantics(errors: PackedStringArray) -> void:
	if not is_finite(body_radius_metres) \
			or body_radius_metres < MIN_BODY_RADIUS_METRES \
			or body_radius_metres > MAX_BODY_RADIUS_METRES:
		return
	if _is_finite_vector(scene_anchor.origin) \
			and scene_anchor.origin.length() > ANCHOR_ORIGIN_EPSILON_METRES:
		errors.append("scene_anchor origin must coincide with the body centre")
	if _is_finite_vector(orbital_anchor.origin) \
			and orbital_anchor.origin.length() <= body_radius_metres:
		errors.append("orbital_anchor origin must be outside the sea-level body radius")
	if _is_finite_vector(surface_anchor.origin) \
			and surface_anchor.origin.length() <= ANCHOR_ORIGIN_EPSILON_METRES:
		errors.append("surface_anchor origin must have a positive body-centred radius")


func _validate_landing_regions(errors: PackedStringArray) -> void:
	if landing_region_ids.is_empty() \
			or landing_region_ids.size() > MAX_LANDING_REGION_REFERENCES:
		errors.append(
			"landing_region_ids must contain 1 to %d stable references"
			% MAX_LANDING_REGION_REFERENCES
		)
	var seen := PackedStringArray()
	for region_id in landing_region_ids:
		_validate_stable_id(errors, "landing region reference", region_id)
		if seen.has(region_id):
			errors.append("landing region reference '%s' is duplicated" % region_id)
		else:
			seen.append(region_id)


func _validate_evidence(errors: PackedStringArray) -> void:
	if evidence_status < EvidenceStatus.AUTHENTICATED \
			or evidence_status > EvidenceStatus.UNKNOWN:
		errors.append("evidence_status is outside the supported enum")
	if evidence_references.size() > MAX_EVIDENCE_REFERENCES:
		errors.append(
			"evidence_references must contain at most %d entries"
			% MAX_EVIDENCE_REFERENCES
		)
	var seen := PackedStringArray()
	for reference in evidence_references:
		if reference.is_empty() \
				or reference != reference.strip_edges() \
				or reference.length() > MAX_EVIDENCE_REFERENCE_LENGTH \
				or _contains_line_break(reference):
			errors.append(
				"evidence references must be trimmed single-line entries of at most %d characters"
				% MAX_EVIDENCE_REFERENCE_LENGTH
			)
		elif seen.has(reference):
			errors.append("evidence reference '%s' is duplicated" % reference)
		else:
			seen.append(reference)
	if evidence_status in [
			EvidenceStatus.AUTHENTICATED,
			EvidenceStatus.BOUNDED_PARTIAL_RECONSTRUCTION,
			EvidenceStatus.PROVISIONAL_CANDIDATE,
		] and evidence_references.is_empty():
		errors.append("historical evidence statuses require at least one evidence reference")
	_validate_bounded_note(
		errors,
		"evidence_notes",
		evidence_notes,
		evidence_status != EvidenceStatus.MODERN_INTERPRETATION
		and evidence_status != EvidenceStatus.UNKNOWN
	)


static func _validate_stable_id(
		errors: PackedStringArray,
		field_name: String,
		value: StringName
	) -> void:
	if not is_stable_id(value):
		errors.append(
			"%s must be a 1-%d character lowercase snake_case identifier"
			% [field_name, MAX_ID_LENGTH]
		)


static func is_stable_id(value: StringName) -> bool:
	var text := String(value)
	if text.is_empty() \
			or text.length() > MAX_ID_LENGTH \
			or text.begins_with("_") \
			or text.ends_with("_") \
			or text.contains("__"):
		return false
	var first_code := text.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower_letter and not is_digit and code != 95:
			return false
	return true


static func _validate_ui_copy(
		errors: PackedStringArray,
		field_name: String,
		value: String,
		maximum_length: int
	) -> void:
	if value.is_empty() \
			or value != value.strip_edges() \
			or value.length() > maximum_length \
			or _contains_line_break(value):
		errors.append(
			"%s must be non-empty, trimmed, single-line, and at most %d characters"
			% [field_name, maximum_length]
		)


static func _validate_bounded_note(
		errors: PackedStringArray,
		field_name: String,
		value: String,
		required: bool
	) -> void:
	if (required and value.is_empty()) \
			or value != value.strip_edges() \
			or value.length() > MAX_CONTENT_NOTE_LENGTH:
		errors.append(
			"%s must be %strimmed and at most %d characters"
			% [field_name, "non-empty, " if required else "", MAX_CONTENT_NOTE_LENGTH]
		)


static func _validate_range(
		errors: PackedStringArray,
		field_name: String,
		value: float,
		minimum: float,
		maximum: float
	) -> void:
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append(
			"%s must be finite and in the range %s to %s"
			% [field_name, minimum, maximum]
		)


static func _contains_line_break(value: String) -> bool:
	return value.contains("\n") or value.contains("\r")


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _is_finite_transform(value: Transform3D) -> bool:
	return _is_finite_vector(value.origin) \
		and _is_finite_vector(value.basis.x) \
		and _is_finite_vector(value.basis.y) \
		and _is_finite_vector(value.basis.z)


static func _is_anchor_origin_bounded(origin: Vector3) -> bool:
	return absf(origin.x) <= MAX_ANCHOR_COMPONENT_METRES \
		and absf(origin.y) <= MAX_ANCHOR_COMPONENT_METRES \
		and absf(origin.z) <= MAX_ANCHOR_COMPONENT_METRES


static func _is_orthonormal_basis(value: Basis) -> bool:
	return absf(value.x.length_squared() - 1.0) <= BASIS_EPSILON \
		and absf(value.y.length_squared() - 1.0) <= BASIS_EPSILON \
		and absf(value.z.length_squared() - 1.0) <= BASIS_EPSILON \
		and absf(value.x.dot(value.y)) <= BASIS_EPSILON \
		and absf(value.x.dot(value.z)) <= BASIS_EPSILON \
		and absf(value.y.dot(value.z)) <= BASIS_EPSILON \
		and absf(value.determinant() - 1.0) <= BASIS_EPSILON
