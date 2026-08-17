class_name PlanetaryLandingRegionDefinition
extends Resource

## Strict, side-effect-free definition of one planetary landing region.
##
## The region owns stable identity and body-local geometry declarations only.
## It never moves a ship, reserves a pad, evaluates terrain, creates routes,
## renders content, streams a world, or grants gameplay outcomes.

const SCHEMA_VERSION := 1
const UNIT_SYSTEM: StringName = &"game_scale_si_body_local"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const EVIDENCE_SCOPE: StringName = &"body_local_landing_region_contract"
const APPROACH_VOLUME_SHAPE: StringName = &"oriented_box"
const APPROACH_FORWARD_AXIS: StringName = &"negative_z"
const SURFACE_NORMAL_AXIS: StringName = &"positive_y"

const MIN_BODY_RADIUS_M := 1_000.0
const MAX_BODY_RADIUS_M := 100_000_000.0
const MAX_ABSOLUTE_ELEVATION_M := 1_000_000.0
const MAX_BODY_LOCAL_COORDINATE_M := (
	MAX_BODY_RADIUS_M + MAX_ABSOLUTE_ELEVATION_M
)
const MAX_REGION_LOCAL_COORDINATE_M := 1_000_000.0
const MAX_APPROACH_CORRIDOR_COUNT := 16
const MAX_TOUCHDOWN_PAD_COUNT := 32
const MAX_SURFACE_ROUTE_ANCHOR_COUNT := 128
const MAX_COMPATIBLE_SHIP_TAG_COUNT := 32
const MAX_EVIDENCE_REFERENCE_COUNT := 64
const MAX_EVIDENCE_REFERENCE_LENGTH := 512
const MAX_EVIDENCE_NOTES_LENGTH := 2_048
const MAX_VOLUME_HALF_EXTENT_M := 100_000.0
const MAX_TOUCHDOWN_PAD_SIZE_M := 2_000.0
const MAX_SURFACE_SLOPE_DEGREES := 45.0
const MAX_SURFACE_ROUGHNESS_M := 25.0
const MAX_VERTICAL_CLEARANCE_M := 10_000.0
const MAX_APPROACH_ALTITUDE_M := 1_000_000.0
const MIN_ON_FOOT_EGRESS_WIDTH_M := 0.8
const MAX_ON_FOOT_EGRESS_WIDTH_M := 50.0
const ORTHONORMAL_TOLERANCE := 0.0001

@export_category("Identity")
@export var world_id: StringName = &"example_planetary_world"
@export var body_id: StringName = &"example_primary_body"
@export var region_id: StringName = &"example_landing_region"
@export var display_name := "Example landing region"

@export_category("Body surface datum (metres)")
## Independent sea-level datum for later composition checks. These values do
## not reference or own a world/terrain profile.
@export_range(MIN_BODY_RADIUS_M, MAX_BODY_RADIUS_M, 1.0) var body_radius_m := 120_000.0
@export_range(-MAX_ABSOLUTE_ELEVATION_M, MAX_ABSOLUTE_ELEVATION_M, 1.0) var minimum_elevation_m := -2_500.0
@export_range(-MAX_ABSOLUTE_ELEVATION_M, MAX_ABSOLUTE_ELEVATION_M, 1.0) var maximum_elevation_m := 8_500.0

@export_category("Body-local region frame (metres)")
## The planetary scene root is the body's physical centre. This position is the
## radial vector from that body-centred origin; its length must lie inside the
## declared sea-level radius plus elevation envelope. Basis +Y is the surface
## normal; +X/+Z span the tangent plane. Scale and reflection are forbidden.
@export var body_local_center_m := Vector3(0.0, 120_000.0, 0.0)
@export var body_local_basis := Basis.IDENTITY

@export_category("Approach corridor oriented boxes")
@export var approach_corridor_ids := PackedStringArray(["primary_approach"])
## Transforms are relative to the region frame. Basis -Z is inbound travel.
@export var approach_corridor_transforms_region_local_m: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(0.0, 60.0, 300.0)),
]
@export var approach_corridor_half_extents_m := PackedVector3Array([
	Vector3(45.0, 60.0, 300.0),
])
@export var approach_corridor_target_pad_ids := PackedStringArray(["pad_alpha"])

@export_category("Touchdown pads")
@export var touchdown_pad_ids := PackedStringArray(["pad_alpha"])
## Pad transforms are relative to the region frame; basis +Y is pad normal.
@export var touchdown_pad_transforms_region_local_m: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3.ZERO),
]
## Width (+X) and length (+Z), in metres.
@export var touchdown_pad_sizes_m := PackedVector2Array([Vector2(28.0, 32.0)])
## Each pad names one surface anchor at which on-foot egress begins.
@export var touchdown_pad_egress_anchor_ids := PackedStringArray(["pad_alpha_egress"])

@export_category("Ship compatibility")
@export var compatible_ship_tags := PackedStringArray(["small_craft", "medium_craft"])

@export_category("Surface and approach limits")
@export_range(0.0, MAX_SURFACE_SLOPE_DEGREES, 0.1) var maximum_surface_slope_degrees := 8.0
@export_range(0.0, MAX_SURFACE_ROUGHNESS_M, 0.01) var maximum_surface_roughness_m := 0.35
@export_range(0.01, MAX_VERTICAL_CLEARANCE_M, 0.01) var minimum_vertical_clearance_m := 18.0
## Altitude is measured along region-frame +Y above its tangent plane.
@export_range(0.0, MAX_APPROACH_ALTITUDE_M, 0.1) var minimum_approach_altitude_m := 15.0
@export_range(0.0, MAX_APPROACH_ALTITUDE_M, 0.1) var maximum_approach_altitude_m := 1_000.0

@export_category("On-foot egress and surface-route anchors")
@export_range(MIN_ON_FOOT_EGRESS_WIDTH_M, MAX_ON_FOOT_EGRESS_WIDTH_M, 0.1) var minimum_on_foot_egress_width_m := 2.0
@export var surface_route_anchor_ids := PackedStringArray([
	"pad_alpha_egress",
	"surface_staging_gate",
])
## Anchor positions are relative to the region frame and remain named points;
## this definition does not create graph edges or assert traversability.
@export var surface_route_anchor_positions_region_local_m := PackedVector3Array([
	Vector3(18.0, 0.0, 0.0),
	Vector3(42.0, 0.0, 0.0),
])

@export_category("Evidence")
@export var evidence_references := PackedStringArray()
@export_multiline var evidence_notes := "New body-local landing-region contract; no recovered historical geometry claim."


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "world_id", str(world_id))
	_validate_stable_id(errors, "body_id", str(body_id))
	_validate_stable_id(errors, "region_id", str(region_id))
	_validate_ui_copy(errors, "display_name", display_name, 96)
	_validate_body_surface_envelope(errors)
	var center_is_bounded := _is_bounded_vector(
		body_local_center_m,
		MAX_BODY_LOCAL_COORDINATE_M
	)
	if not center_is_bounded:
		errors.append("body_local_center_m must be finite and inside the body-local coordinate bound")
	var basis_is_orthonormal := _is_orthonormal_right_handed_basis(body_local_basis)
	if not basis_is_orthonormal:
		errors.append("body_local_basis must be finite, orthonormal, unit scale, and right-handed")
	if center_is_bounded and body_local_center_m.length_squared() > 0.0 \
		and basis_is_orthonormal \
		and absf(
			body_local_basis.y.dot(body_local_center_m.normalized()) - 1.0
		) > ORTHONORMAL_TOLERANCE:
		errors.append(
			"body_local_basis +Y must align outward with the body_local_center_m radial normal"
		)

	_validate_touchdown_pads(errors)
	_validate_approach_corridors(errors)
	_validate_compatible_ship_tags(errors)
	_validate_limits(errors)
	_validate_surface_route_anchors(errors)
	_validate_evidence(errors)
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_identity_snapshot() -> Dictionary:
	return {
		"world_id": world_id,
		"body_id": body_id,
		"region_id": region_id,
		"display_name": display_name,
	}.duplicate(true)


func get_body_local_frame_snapshot() -> Dictionary:
	return {
		"center_m": body_local_center_m,
		"basis": body_local_basis,
		"coordinate_origin": &"body_center_scene_root",
		"surface_normal_axis": SURFACE_NORMAL_AXIS,
	}.duplicate(true)


func get_body_surface_envelope_snapshot() -> Dictionary:
	return {
		"datum": &"sea_level",
		"body_radius_m": body_radius_m,
		"minimum_elevation_m": minimum_elevation_m,
		"maximum_elevation_m": maximum_elevation_m,
		"minimum_surface_radius_m": body_radius_m + minimum_elevation_m,
		"maximum_surface_radius_m": body_radius_m + maximum_elevation_m,
		"region_center_radius_m": body_local_center_m.length(),
	}.duplicate(true)


func get_approach_corridor_snapshot() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index in approach_corridor_ids.size():
		var transform := Transform3D.IDENTITY
		var half_extents := Vector3.ZERO
		var target_pad_id: StringName = &""
		if index < approach_corridor_transforms_region_local_m.size():
			transform = approach_corridor_transforms_region_local_m[index]
		if index < approach_corridor_half_extents_m.size():
			half_extents = approach_corridor_half_extents_m[index]
		if index < approach_corridor_target_pad_ids.size():
			target_pad_id = StringName(approach_corridor_target_pad_ids[index])
		records.append({
			"corridor_id": StringName(approach_corridor_ids[index]),
			"transform_region_local_m": transform,
			"half_extents_m": half_extents,
			"target_pad_id": target_pad_id,
			"volume_shape": APPROACH_VOLUME_SHAPE,
			"inbound_axis": APPROACH_FORWARD_AXIS,
		})
	return records.duplicate(true)


func get_touchdown_pad_snapshot() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index in touchdown_pad_ids.size():
		var transform := Transform3D.IDENTITY
		var size_m := Vector2.ZERO
		var egress_anchor_id: StringName = &""
		if index < touchdown_pad_transforms_region_local_m.size():
			transform = touchdown_pad_transforms_region_local_m[index]
		if index < touchdown_pad_sizes_m.size():
			size_m = touchdown_pad_sizes_m[index]
		if index < touchdown_pad_egress_anchor_ids.size():
			egress_anchor_id = StringName(touchdown_pad_egress_anchor_ids[index])
		records.append({
			"pad_id": StringName(touchdown_pad_ids[index]),
			"transform_region_local_m": transform,
			"size_m": size_m,
			"egress_anchor_id": egress_anchor_id,
			"surface_normal_axis": SURFACE_NORMAL_AXIS,
		})
	return records.duplicate(true)


func get_surface_route_anchor_snapshot() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index in surface_route_anchor_ids.size():
		var position := Vector3.ZERO
		if index < surface_route_anchor_positions_region_local_m.size():
			position = surface_route_anchor_positions_region_local_m[index]
		records.append({
			"anchor_id": StringName(surface_route_anchor_ids[index]),
			"position_region_local_m": position,
		})
	return records.duplicate(true)


func get_constraint_snapshot() -> Dictionary:
	return {
		"compatible_ship_tags": compatible_ship_tags.duplicate(),
		"maximum_surface_slope_degrees": maximum_surface_slope_degrees,
		"maximum_surface_roughness_m": maximum_surface_roughness_m,
		"minimum_vertical_clearance_m": minimum_vertical_clearance_m,
		"minimum_approach_altitude_m": minimum_approach_altitude_m,
		"maximum_approach_altitude_m": maximum_approach_altitude_m,
		"minimum_on_foot_egress_width_m": minimum_on_foot_egress_width_m,
	}.duplicate(true)


func get_evidence_snapshot() -> Dictionary:
	return {
		"content_class": CONTENT_CLASS,
		"status": EVIDENCE_STATUS,
		"scope": EVIDENCE_SCOPE,
		"historical_claim": false,
		"authenticated": false,
		"manual_review_required": false,
		"references": evidence_references.duplicate(),
		"notes": evidence_notes,
	}.duplicate(true)


func get_authority_report() -> Dictionary:
	return {
		"landing_motion": false,
		"berth": false,
		"lease": false,
		"terrain": false,
		"gameplay": false,
		"reward": false,
		"streaming": false,
		"save": false,
		"renderer": false,
		"network": false,
		"ship": false,
		"surface_route": false,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": UNIT_SYSTEM,
		"identity": get_identity_snapshot(),
		"body_surface_envelope": get_body_surface_envelope_snapshot(),
		"body_local_frame": get_body_local_frame_snapshot(),
		"approach_corridors": get_approach_corridor_snapshot(),
		"touchdown_pads": get_touchdown_pad_snapshot(),
		"surface_route_anchors": get_surface_route_anchor_snapshot(),
		"constraints": get_constraint_snapshot(),
		"evidence": get_evidence_snapshot(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": UNIT_SYSTEM,
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"snapshot": get_snapshot(),
		"approach_volume_shape": APPROACH_VOLUME_SHAPE,
		"approach_forward_axis": APPROACH_FORWARD_AXIS,
		"surface_normal_axis": SURFACE_NORMAL_AXIS,
		"deterministic_ordering": &"declared_corridors_pads_surface_anchors",
		"evidence": get_evidence_snapshot(),
		"authority": get_authority_report(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _validate_body_surface_envelope(errors: PackedStringArray) -> void:
	_validate_range(
		errors,
		"body_radius_m",
		body_radius_m,
		MIN_BODY_RADIUS_M,
		MAX_BODY_RADIUS_M
	)
	_validate_range(
		errors,
		"minimum_elevation_m",
		minimum_elevation_m,
		-MAX_ABSOLUTE_ELEVATION_M,
		MAX_ABSOLUTE_ELEVATION_M
	)
	_validate_range(
		errors,
		"maximum_elevation_m",
		maximum_elevation_m,
		-MAX_ABSOLUTE_ELEVATION_M,
		MAX_ABSOLUTE_ELEVATION_M
	)
	if _is_finite_float(minimum_elevation_m) \
		and _is_finite_float(maximum_elevation_m) \
		and minimum_elevation_m >= maximum_elevation_m:
		errors.append("minimum_elevation_m must be below maximum_elevation_m")
	if _is_finite_float(body_radius_m) and _is_finite_float(minimum_elevation_m) \
		and body_radius_m + minimum_elevation_m <= 0.0:
		errors.append("body radius plus minimum elevation must remain positive")
	if not _is_finite_vector(body_local_center_m) \
		or not _is_finite_float(body_radius_m) \
		or not _is_finite_float(minimum_elevation_m) \
		or not _is_finite_float(maximum_elevation_m):
		return
	var minimum_surface_radius_m := body_radius_m + minimum_elevation_m
	var maximum_surface_radius_m := body_radius_m + maximum_elevation_m
	var region_center_radius_m := body_local_center_m.length()
	if minimum_surface_radius_m > maximum_surface_radius_m \
		or region_center_radius_m < minimum_surface_radius_m \
		or region_center_radius_m > maximum_surface_radius_m:
		errors.append(
			"body_local_center_m radial length must lie inside the declared surface radius envelope"
		)


func _validate_touchdown_pads(errors: PackedStringArray) -> void:
	var pad_count := touchdown_pad_ids.size()
	if pad_count < 1 or pad_count > MAX_TOUCHDOWN_PAD_COUNT:
		errors.append("touchdown pad count is outside the supported range")
	if touchdown_pad_transforms_region_local_m.size() != pad_count \
		or touchdown_pad_sizes_m.size() != pad_count \
		or touchdown_pad_egress_anchor_ids.size() != pad_count:
		errors.append("touchdown pad typed arrays must have identical counts")
	var seen_ids := PackedStringArray()
	for index in pad_count:
		var pad_id := touchdown_pad_ids[index]
		_validate_stable_id(errors, "touchdown pad ID", pad_id)
		if seen_ids.has(pad_id):
			errors.append("touchdown pad ID '%s' is duplicated" % pad_id)
		else:
			seen_ids.append(pad_id)
		if index < touchdown_pad_transforms_region_local_m.size() \
			and not _is_valid_region_local_transform(touchdown_pad_transforms_region_local_m[index]):
			errors.append("touchdown pad '%s' transform must be finite, bounded, and orthonormal" % pad_id)
		elif index < touchdown_pad_transforms_region_local_m.size() \
			and _is_finite_float(maximum_surface_slope_degrees):
			var pad_normal := touchdown_pad_transforms_region_local_m[index].basis.y
			var pad_slope_degrees := rad_to_deg(acos(clampf(pad_normal.dot(Vector3.UP), -1.0, 1.0)))
			if pad_slope_degrees > maximum_surface_slope_degrees + ORTHONORMAL_TOLERANCE:
				errors.append("touchdown pad '%s' normal exceeds the maximum surface slope" % pad_id)
		if index < touchdown_pad_sizes_m.size():
			var size_m := touchdown_pad_sizes_m[index]
			if not _is_finite_vector2(size_m) or size_m.x < 1.0 or size_m.y < 1.0 \
				or size_m.x > MAX_TOUCHDOWN_PAD_SIZE_M or size_m.y > MAX_TOUCHDOWN_PAD_SIZE_M:
				errors.append("touchdown pad '%s' size must be finite and bounded" % pad_id)
		if index < touchdown_pad_egress_anchor_ids.size():
			_validate_stable_id(
				errors,
				"touchdown pad egress anchor ID",
				touchdown_pad_egress_anchor_ids[index]
			)


func _validate_approach_corridors(errors: PackedStringArray) -> void:
	var corridor_count := approach_corridor_ids.size()
	if corridor_count < 1 or corridor_count > MAX_APPROACH_CORRIDOR_COUNT:
		errors.append("approach corridor count is outside the supported range")
	if approach_corridor_transforms_region_local_m.size() != corridor_count \
		or approach_corridor_half_extents_m.size() != corridor_count \
		or approach_corridor_target_pad_ids.size() != corridor_count:
		errors.append("approach corridor typed arrays must have identical counts")
	var seen_ids := PackedStringArray()
	var targeted_pad_ids := PackedStringArray()
	for index in corridor_count:
		var corridor_id := approach_corridor_ids[index]
		_validate_stable_id(errors, "approach corridor ID", corridor_id)
		if seen_ids.has(corridor_id):
			errors.append("approach corridor ID '%s' is duplicated" % corridor_id)
		else:
			seen_ids.append(corridor_id)
		if index < approach_corridor_transforms_region_local_m.size() \
			and not _is_valid_region_local_transform(approach_corridor_transforms_region_local_m[index]):
			errors.append("approach corridor '%s' transform must be finite, bounded, and orthonormal" % corridor_id)
		if index < approach_corridor_half_extents_m.size():
			var half_extents := approach_corridor_half_extents_m[index]
			if not _is_positive_bounded_vector(half_extents, MAX_VOLUME_HALF_EXTENT_M):
				errors.append("approach corridor '%s' half extents must be finite, positive, and bounded" % corridor_id)
			elif index < approach_corridor_transforms_region_local_m.size() \
				and _is_valid_region_local_transform(approach_corridor_transforms_region_local_m[index]) \
				and _is_finite_float(minimum_vertical_clearance_m):
				var vertical_extent_m := _oriented_box_vertical_extent_m(
					approach_corridor_transforms_region_local_m[index].basis,
					half_extents
				)
				if vertical_extent_m < minimum_vertical_clearance_m:
					errors.append("approach corridor '%s' cannot provide the minimum vertical clearance" % corridor_id)
		if index < approach_corridor_target_pad_ids.size():
			var target_pad_id := approach_corridor_target_pad_ids[index]
			_validate_stable_id(errors, "approach corridor target pad ID", target_pad_id)
			if not touchdown_pad_ids.has(target_pad_id):
				errors.append("approach corridor '%s' targets an unknown touchdown pad" % corridor_id)
			elif not targeted_pad_ids.has(target_pad_id):
				targeted_pad_ids.append(target_pad_id)
	for pad_id in touchdown_pad_ids:
		if not targeted_pad_ids.has(pad_id):
			errors.append("touchdown pad '%s' requires at least one approach corridor" % pad_id)


func _validate_compatible_ship_tags(errors: PackedStringArray) -> void:
	if compatible_ship_tags.is_empty() \
		or compatible_ship_tags.size() > MAX_COMPATIBLE_SHIP_TAG_COUNT:
		errors.append("compatible ship tag count is outside the supported range")
	var seen := PackedStringArray()
	for tag in compatible_ship_tags:
		_validate_stable_id(errors, "compatible ship tag", tag)
		if seen.has(tag):
			errors.append("compatible ship tag '%s' is duplicated" % tag)
		else:
			seen.append(tag)


func _validate_limits(errors: PackedStringArray) -> void:
	_validate_range(
		errors,
		"maximum_surface_slope_degrees",
		maximum_surface_slope_degrees,
		0.0,
		MAX_SURFACE_SLOPE_DEGREES
	)
	_validate_range(
		errors,
		"maximum_surface_roughness_m",
		maximum_surface_roughness_m,
		0.0,
		MAX_SURFACE_ROUGHNESS_M
	)
	_validate_range(
		errors,
		"minimum_vertical_clearance_m",
		minimum_vertical_clearance_m,
		0.01,
		MAX_VERTICAL_CLEARANCE_M
	)
	_validate_range(
		errors,
		"minimum_approach_altitude_m",
		minimum_approach_altitude_m,
		0.0,
		MAX_APPROACH_ALTITUDE_M
	)
	_validate_range(
		errors,
		"maximum_approach_altitude_m",
		maximum_approach_altitude_m,
		0.0,
		MAX_APPROACH_ALTITUDE_M
	)
	if _is_finite_float(minimum_approach_altitude_m) \
		and _is_finite_float(maximum_approach_altitude_m) \
		and minimum_approach_altitude_m >= maximum_approach_altitude_m:
		errors.append("minimum_approach_altitude_m must be below maximum_approach_altitude_m")
	_validate_range(
		errors,
		"minimum_on_foot_egress_width_m",
		minimum_on_foot_egress_width_m,
		MIN_ON_FOOT_EGRESS_WIDTH_M,
		MAX_ON_FOOT_EGRESS_WIDTH_M
	)


func _validate_surface_route_anchors(errors: PackedStringArray) -> void:
	var anchor_count := surface_route_anchor_ids.size()
	if anchor_count < 1 or anchor_count > MAX_SURFACE_ROUTE_ANCHOR_COUNT:
		errors.append("surface-route anchor count is outside the supported range")
	if surface_route_anchor_positions_region_local_m.size() != anchor_count:
		errors.append("surface-route anchor IDs and positions must have identical counts")
	var seen := PackedStringArray()
	for index in anchor_count:
		var anchor_id := surface_route_anchor_ids[index]
		_validate_stable_id(errors, "surface-route anchor ID", anchor_id)
		if seen.has(anchor_id):
			errors.append("surface-route anchor ID '%s' is duplicated" % anchor_id)
		else:
			seen.append(anchor_id)
		if index < surface_route_anchor_positions_region_local_m.size() \
			and not _is_bounded_vector(
				surface_route_anchor_positions_region_local_m[index],
				MAX_REGION_LOCAL_COORDINATE_M
			):
			errors.append("surface-route anchor '%s' position must be finite and bounded" % anchor_id)
	for egress_anchor_id in touchdown_pad_egress_anchor_ids:
		if not surface_route_anchor_ids.has(egress_anchor_id):
			errors.append("touchdown pad egress anchor '%s' is not a named surface-route anchor" % egress_anchor_id)


func _validate_evidence(errors: PackedStringArray) -> void:
	if evidence_notes.is_empty() or evidence_notes != evidence_notes.strip_edges():
		errors.append("evidence_notes must be non-empty and trimmed")
	elif evidence_notes.length() > MAX_EVIDENCE_NOTES_LENGTH:
		errors.append("evidence_notes exceeds the supported length")
	if evidence_references.size() > MAX_EVIDENCE_REFERENCE_COUNT:
		errors.append("evidence reference count exceeds the supported maximum")
	var seen := PackedStringArray()
	for reference in evidence_references:
		if reference.is_empty() or reference != reference.strip_edges() \
			or reference.contains("\n") or reference.contains("\r") \
			or reference.length() > MAX_EVIDENCE_REFERENCE_LENGTH:
			errors.append("evidence references must be non-empty, trimmed, and single-line")
		elif seen.has(reference):
			errors.append("evidence reference '%s' is duplicated" % reference)
		else:
			seen.append(reference)


static func _validate_stable_id(
	errors: PackedStringArray,
	field_name: String,
	value: String
) -> void:
	if not _is_stable_id(value):
		errors.append(
			"%s must start with a lowercase letter and be a 1-64 character lowercase snake_case identifier"
			% field_name
		)


static func _validate_ui_copy(
	errors: PackedStringArray,
	field_name: String,
	value: String,
	maximum_length: int
) -> void:
	if value.is_empty() or value != value.strip_edges() or value.contains("\n") \
		or value.contains("\r") or value.length() > maximum_length:
		errors.append("%s must be non-empty, trimmed, single-line, and at most %d characters" % [
			field_name,
			maximum_length,
		])


static func _validate_range(
	errors: PackedStringArray,
	field_name: String,
	value: float,
	minimum: float,
	maximum: float
) -> void:
	if not _is_finite_float(value) or value < minimum or value > maximum:
		errors.append("%s must be finite and in the range %s to %s" % [field_name, minimum, maximum])


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") \
		or value.ends_with("_") or value.contains("__"):
		return false
	var first_code := value.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var lower_letter := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lower_letter and not digit and code != 95:
			return false
	return true


static func _is_valid_region_local_transform(value: Transform3D) -> bool:
	return _is_bounded_vector(value.origin, MAX_REGION_LOCAL_COORDINATE_M) \
		and _is_orthonormal_right_handed_basis(value.basis)


static func _oriented_box_vertical_extent_m(basis: Basis, half_extents_m: Vector3) -> float:
	var vertical_half_extent_m := absf(basis.x.y) * half_extents_m.x \
		+ absf(basis.y.y) * half_extents_m.y \
		+ absf(basis.z.y) * half_extents_m.z
	return vertical_half_extent_m * 2.0


static func _is_orthonormal_right_handed_basis(value: Basis) -> bool:
	if not _is_finite_vector(value.x) or not _is_finite_vector(value.y) \
		or not _is_finite_vector(value.z):
		return false
	return absf(value.x.length_squared() - 1.0) <= ORTHONORMAL_TOLERANCE \
		and absf(value.y.length_squared() - 1.0) <= ORTHONORMAL_TOLERANCE \
		and absf(value.z.length_squared() - 1.0) <= ORTHONORMAL_TOLERANCE \
		and absf(value.x.dot(value.y)) <= ORTHONORMAL_TOLERANCE \
		and absf(value.x.dot(value.z)) <= ORTHONORMAL_TOLERANCE \
		and absf(value.y.dot(value.z)) <= ORTHONORMAL_TOLERANCE \
		and absf(value.determinant() - 1.0) <= ORTHONORMAL_TOLERANCE


static func _is_positive_bounded_vector(value: Vector3, maximum: float) -> bool:
	return _is_finite_vector(value) and value.x > 0.0 and value.y > 0.0 \
		and value.z > 0.0 and value.x <= maximum and value.y <= maximum \
		and value.z <= maximum


static func _is_bounded_vector(value: Vector3, maximum: float) -> bool:
	return _is_finite_vector(value) and absf(value.x) <= maximum \
		and absf(value.y) <= maximum and absf(value.z) <= maximum


static func _is_finite_vector(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) \
		and _is_finite_float(value.z)


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
