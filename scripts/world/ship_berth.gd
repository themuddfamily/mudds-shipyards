class_name ShipBerth
extends Node3D

## A reusable physical parking/landing contract. The berth owns no gameplay
## mission state and never spawns, boards, or pilots a ship itself.

signal reservation_changed(owner: Node, token: StringName)
signal occupancy_changed(occupant: Node)

const SCHEMA_VERSION := 3
const LANDING_ACCEPTANCE_SCHEMA_VERSION := 2
const ASSIST_CAPTURE_SCHEMA_VERSION := 1

@export_category("Identity")
@export var berth_id: StringName = &"unnamed_berth"
@export var compatibility_tags := PackedStringArray()

@export_category("Docking")
## Local transform of the exact parked ship root relative to this berth node.
## `get_dock_transform()` composes it with the berth's complete global transform.
@export var dock_transform := Transform3D.IDENTITY
## Exact physical parked volume. This remains deliberately tight: widening the
## assist must never make an overhanging hull count as docked.
@export var landing_half_extents := Vector3(6.0, 4.0, 8.0)

@export_category("Landing Assist Capture")
## A broad, clear acquisition box expressed in dock-local space. It is separate
## from `landing_half_extents`, so pilots can hand control to the assist without
## weakening the final physical parking contract.
@export var assist_capture_center := Vector3(0.0, 8.0, -18.0)
@export var assist_capture_half_extents := Vector3(24.0, 16.0, 36.0)
@export_range(1.0, 80.0, 0.5) var assist_capture_maximum_speed := 32.0
@export_range(1.0, 89.0, 0.5) var assist_maximum_tilt_degrees := 75.0

var _reservation_owner: WeakRef
var _occupant: WeakRef
var _reservation_token: StringName = &""
var _reserved_ship_id: StringName = &""
var _token_serial := 0


func get_berth_id() -> StringName:
	return berth_id


func get_dock_transform() -> Transform3D:
	return global_transform * dock_transform


func get_landing_half_extents() -> Vector3:
	return landing_half_extents


func get_assist_capture_transform() -> Transform3D:
	return get_dock_transform() * Transform3D(Basis.IDENTITY, assist_capture_center)


## The capture centre is intentionally also the clear alignment staging point.
## World layouts place it above/in front of the physical berth so a craft can
## brake, translate there in its current attitude, then rotate before descending.
func get_assist_staging_transform() -> Transform3D:
	return Transform3D(get_dock_transform().basis, get_assist_capture_transform().origin)


func get_assist_capture_center() -> Vector3:
	return assist_capture_center


func get_assist_capture_half_extents() -> Vector3:
	return assist_capture_half_extents


func get_assist_capture_maximum_speed() -> float:
	return assist_capture_maximum_speed


func get_assist_maximum_tilt_degrees() -> float:
	return assist_maximum_tilt_degrees


func get_compatibility_tags() -> PackedStringArray:
	return compatibility_tags.duplicate()


func contains(world_position: Vector3) -> bool:
	if not _is_valid_volume():
		return false
	var target := get_dock_transform()
	if not _is_valid_transform(target):
		return false
	var local_position := target.affine_inverse() * world_position
	return absf(local_position.x) <= landing_half_extents.x \
		and absf(local_position.y) <= landing_half_extents.y \
		and absf(local_position.z) <= landing_half_extents.z


func contains_transform(world_transform: Transform3D) -> bool:
	return contains(world_transform.origin)


## Broad, root-based acquisition test used only to decide whether landing
## assistance may take control. It never attests final hull clearance.
func contains_assist_capture(world_position: Vector3) -> bool:
	if not _is_valid_assist_capture() or not world_position.is_finite():
		return false
	var capture := get_assist_capture_transform()
	if not _is_valid_transform(capture):
		return false
	var local_position := capture.affine_inverse() * world_position
	return absf(local_position.x) <= assist_capture_half_extents.x + 0.0001 \
		and absf(local_position.y) <= assist_capture_half_extents.y + 0.0001 \
		and absf(local_position.z) <= assist_capture_half_extents.z + 0.0001


## Diagnostic only: unlike the root-based accessibility gate above, this
## reports whether the whole current hull happens to be inside the capture box.
func contains_assist_oriented_bounds(
	world_transform: Transform3D,
	local_bounds: AABB,
	clearance_margin: float = 0.0
	) -> bool:
	if not _is_valid_assist_capture() \
			or not _is_valid_transform(world_transform) \
			or not _is_valid_transform(get_assist_capture_transform()) \
			or not _is_valid_bounds(local_bounds) \
			or not is_finite(clearance_margin) \
			or clearance_margin < 0.0:
		return false
	var available := assist_capture_half_extents - Vector3.ONE * clearance_margin
	if available.x <= 0.0 or available.y <= 0.0 or available.z <= 0.0:
		return false
	var capture_inverse := get_assist_capture_transform().affine_inverse()
	for corner in _aabb_corners(local_bounds):
		var capture_local_corner := capture_inverse * (world_transform * corner)
		if absf(capture_local_corner.x) > available.x + 0.0001 \
				or absf(capture_local_corner.y) > available.y + 0.0001 \
				or absf(capture_local_corner.z) > available.z + 0.0001:
			return false
	return true


## Tests the complete oriented craft envelope against the berth volume. Unlike
## `contains_transform()`, this does not treat a ship root point as proof that
## the hull, wings, ramps, or tail are clear to enter the landing assist.
func contains_oriented_bounds(
	world_transform: Transform3D,
	local_bounds: AABB,
	clearance_margin: float = 0.0
	) -> bool:
	if not _is_valid_volume() \
			or not _is_valid_transform(world_transform) \
			or not _is_valid_transform(get_dock_transform()) \
			or not _is_valid_bounds(local_bounds) \
			or not is_finite(clearance_margin) \
			or clearance_margin < 0.0:
		return false
	var available := landing_half_extents - Vector3.ONE * clearance_margin
	if available.x <= 0.0 or available.y <= 0.0 or available.z <= 0.0:
		return false
	var berth_inverse := get_dock_transform().affine_inverse()
	for corner in _aabb_corners(local_bounds):
		var berth_local_corner := berth_inverse * (world_transform * corner)
		if absf(berth_local_corner.x) > available.x + 0.0001 \
				or absf(berth_local_corner.y) > available.y + 0.0001 \
				or absf(berth_local_corner.z) > available.z + 0.0001:
			return false
	return true


## Returns a fail-closed physical approach contract for landing assist. The
## candidate must be slow, upright and heading generally with the berth. Its
## root must be inside the approach volume, while the exact docked transform
## must contain its complete collision envelope. Requiring the entire hull to
## fit at the high approach point would reject valid tall craft before the
## assist has descended them into the berth.
func evaluate_landing_candidate(
	ship_transform: Transform3D,
	ship_local_bounds: AABB,
	world_velocity: Vector3,
	maximum_speed: float,
	maximum_up_angle_degrees: float = 35.0,
	maximum_heading_angle_degrees: float = 55.0,
	clearance_margin: float = 0.05
	) -> Dictionary:
	var errors := PackedStringArray()
	var berth_errors := get_validation_errors()
	for error in berth_errors:
		errors.append("berth_%s" % error)
	if not _is_valid_transform(get_dock_transform()):
		errors.append("berth_world_transform_invalid")
	if not _is_valid_transform(ship_transform):
		errors.append("ship_transform_invalid")
	if not _is_valid_bounds(ship_local_bounds):
		errors.append("ship_collision_bounds_invalid")
	if not world_velocity.is_finite():
		errors.append("ship_velocity_invalid")
	if not is_finite(maximum_speed) or maximum_speed <= 0.0:
		errors.append("maximum_speed_invalid")
	if not is_finite(maximum_up_angle_degrees) \
			or maximum_up_angle_degrees <= 0.0 \
			or maximum_up_angle_degrees >= 90.0:
		errors.append("maximum_up_angle_invalid")
	if not is_finite(maximum_heading_angle_degrees) \
			or maximum_heading_angle_degrees <= 0.0 \
			or maximum_heading_angle_degrees > 180.0:
		errors.append("maximum_heading_angle_invalid")
	if not is_finite(clearance_margin) or clearance_margin < 0.0:
		errors.append("clearance_margin_invalid")

	var speed := world_velocity.length() if world_velocity.is_finite() else INF
	var up_error_degrees := INF
	var heading_error_degrees := INF
	var root_inside := false
	var approach_hull_inside := false
	var docked_hull_fits := false
	var local_root_offset := Vector3.INF
	if errors.is_empty():
		var dock := get_dock_transform()
		var ship_up := ship_transform.basis.y.normalized()
		var dock_up := dock.basis.y.normalized()
		var ship_forward := -ship_transform.basis.z.normalized()
		var dock_forward := -dock.basis.z.normalized()
		up_error_degrees = rad_to_deg(acos(clampf(ship_up.dot(dock_up), -1.0, 1.0)))
		heading_error_degrees = rad_to_deg(acos(clampf(ship_forward.dot(dock_forward), -1.0, 1.0)))
		local_root_offset = dock.affine_inverse() * ship_transform.origin
		root_inside = contains(ship_transform.origin)
		approach_hull_inside = contains_oriented_bounds(ship_transform, ship_local_bounds, clearance_margin)
		docked_hull_fits = contains_oriented_bounds(dock, ship_local_bounds, clearance_margin)
		if speed > maximum_speed + 0.0001:
			errors.append("approach_speed_exceeds_limit")
		if up_error_degrees > maximum_up_angle_degrees + 0.0001:
			errors.append("approach_attitude_exceeds_limit")
		if heading_error_degrees > maximum_heading_angle_degrees + 0.0001:
			errors.append("approach_heading_exceeds_limit")
		if not root_inside:
			errors.append("ship_root_outside_landing_volume")
		if not docked_hull_fits:
			errors.append("docked_hull_does_not_fit")
	return {
		"schema_version": LANDING_ACCEPTANCE_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"contract_accepted": errors.is_empty(),
		"strict_dock_acceptance": errors.is_empty() and docked_hull_fits,
		"errors": errors,
		"berth_id": berth_id,
		"ship_local_bounds": ship_local_bounds,
		"ship_speed": speed,
		"maximum_speed": maximum_speed,
		"up_error_degrees": up_error_degrees,
		"maximum_up_angle_degrees": maximum_up_angle_degrees,
		"heading_error_degrees": heading_error_degrees,
		"maximum_heading_angle_degrees": maximum_heading_angle_degrees,
		"local_root_offset": local_root_offset,
		"clearance_margin": clearance_margin,
		"root_inside": root_inside,
		"approach_hull_inside": approach_hull_inside,
		"docked_hull_fits": docked_hull_fits,
		"approach_clearance_authority": &"runtime_current_and_step_pose_checks",
		"continuous_swept_clearance_proved": false,
		"swept_volume_precomputed": false,
		"dock_transform": get_dock_transform(),
		"landing_half_extents": landing_half_extents,
	}


## Accessibility-first acquisition contract for the production landing assist.
## It intentionally permits any yaw and up to 75 degrees of pitch/bank by
## default. The berth-specific capture speed is authoritative here; the legacy
## per-ship limit is retained in the report for honest compatibility telemetry,
## but does not quietly narrow a deliberately widened production capture zone.
##
## Final safety is still strict: the exact dock transform must contain the full
## collision envelope. An inverted craft, an out-of-volume root, excessive
## speed, or an undersized final berth all fail closed before motion authority.
func evaluate_assist_capture_candidate(
	ship_transform: Transform3D,
	ship_local_bounds: AABB,
	world_velocity: Vector3,
	legacy_ship_maximum_speed: float,
	clearance_margin: float = 0.05
	) -> Dictionary:
	var errors := PackedStringArray()
	var berth_errors := get_validation_errors()
	for error in berth_errors:
		errors.append("berth_%s" % error)
	var dock := get_dock_transform()
	var capture := get_assist_capture_transform()
	var staging := get_assist_staging_transform()
	if not _is_valid_transform(dock):
		errors.append("berth_world_transform_invalid")
	if not _is_valid_transform(capture):
		errors.append("assist_capture_world_transform_invalid")
	if not _is_valid_transform(staging):
		errors.append("assist_staging_world_transform_invalid")
	if not _is_valid_transform(ship_transform):
		errors.append("ship_transform_invalid")
	if not _is_valid_bounds(ship_local_bounds):
		errors.append("ship_collision_bounds_invalid")
	if not world_velocity.is_finite():
		errors.append("ship_velocity_invalid")
	if not is_finite(legacy_ship_maximum_speed) or legacy_ship_maximum_speed <= 0.0:
		errors.append("legacy_ship_maximum_speed_invalid")
	if not is_finite(clearance_margin) or clearance_margin < 0.0:
		errors.append("clearance_margin_invalid")

	var speed := world_velocity.length() if world_velocity.is_finite() else INF
	var up_error_degrees := INF
	var heading_error_degrees := INF
	var capture_root_inside := false
	var capture_hull_inside := false
	var docked_hull_fits := false
	var capture_local_root_offset := Vector3.INF
	var dock_local_root_offset := Vector3.INF
	if errors.is_empty():
		var ship_up := ship_transform.basis.y.normalized()
		var dock_up := dock.basis.y.normalized()
		var ship_forward := -ship_transform.basis.z.normalized()
		var dock_forward := -dock.basis.z.normalized()
		up_error_degrees = rad_to_deg(acos(clampf(ship_up.dot(dock_up), -1.0, 1.0)))
		# Yaw is deliberately diagnostic-only. A natural nose-first return may
		# enter facing 180 degrees away and align safely at the clear staging pose.
		heading_error_degrees = rad_to_deg(acos(clampf(ship_forward.dot(dock_forward), -1.0, 1.0)))
		capture_local_root_offset = capture.affine_inverse() * ship_transform.origin
		dock_local_root_offset = dock.affine_inverse() * ship_transform.origin
		capture_root_inside = contains_assist_capture(ship_transform.origin)
		capture_hull_inside = contains_assist_oriented_bounds(
			ship_transform,
			ship_local_bounds,
			clearance_margin
		)
		docked_hull_fits = contains_oriented_bounds(dock, ship_local_bounds, clearance_margin)
		if speed > assist_capture_maximum_speed + 0.0001:
			errors.append("assist_capture_speed_exceeds_limit")
		if up_error_degrees > assist_maximum_tilt_degrees + 0.0001:
			errors.append("assist_capture_attitude_exceeds_limit")
		if not capture_root_inside:
			errors.append("ship_root_outside_assist_capture_volume")
		if not docked_hull_fits:
			errors.append("docked_hull_does_not_fit")
	var accepted := errors.is_empty()
	return {
		"schema_version": ASSIST_CAPTURE_SCHEMA_VERSION,
		"valid": accepted,
		"contract_accepted": accepted,
		"assist_capture_accepted": accepted,
		"strict_dock_acceptance": accepted and docked_hull_fits,
		"errors": errors,
		"berth_id": berth_id,
		"ship_local_bounds": ship_local_bounds,
		"ship_speed": speed,
		"legacy_ship_maximum_speed": legacy_ship_maximum_speed,
		"ship_maximum_speed": legacy_ship_maximum_speed,
		"capture_maximum_speed": assist_capture_maximum_speed,
		"effective_maximum_speed": assist_capture_maximum_speed,
		"speed_authority": &"berth_assist_capture_maximum_speed",
		"up_error_degrees": up_error_degrees,
		"maximum_up_angle_degrees": assist_maximum_tilt_degrees,
		"heading_error_degrees": heading_error_degrees,
		"maximum_heading_angle_degrees": 180.0,
		"heading_unrestricted": true,
		"capture_root_inside": capture_root_inside,
		"root_inside": capture_root_inside,
		"capture_hull_inside": capture_hull_inside,
		"approach_hull_inside": capture_hull_inside,
		"docked_hull_fits": docked_hull_fits,
		"capture_local_root_offset": capture_local_root_offset,
		"dock_local_root_offset": dock_local_root_offset,
		"local_root_offset": dock_local_root_offset,
		"clearance_margin": clearance_margin,
		"capture_center": assist_capture_center,
		"capture_half_extents": assist_capture_half_extents,
		"capture_transform": capture,
		"staging_transform": staging,
		"dock_transform": dock,
		"landing_half_extents": landing_half_extents,
		"approach_clearance_authority": &"runtime_current_and_step_pose_checks",
		"continuous_swept_clearance_proved": false,
		"swept_volume_precomputed": false,
	}


## Returns whether this berth is compatible and presently claimable. Empty
## berth tags mean unrestricted. Otherwise at least one definition tag must
## match. A requester may inspect or renew its own existing claim.
func can_accept(definition: ShipDefinition, requester: Node = null) -> bool:
	if is_queued_for_deletion() or not is_inside_tree():
		return false
	_cleanup_stale_claims()
	if definition == null or not definition.is_definition_valid():
		return false
	if requester != null and (
		not is_instance_valid(requester)
		or requester.is_queued_for_deletion()
		or not requester.is_inside_tree()
	):
		return false
	if not _is_compatible(definition):
		return false
	var reservation_owner := get_reservation_owner()
	var current_occupant := get_occupant()
	if reservation_owner != null and reservation_owner != requester:
		return false
	if current_occupant != null and current_occupant != requester:
		return false
	if requester != null and reservation_owner == requester \
		and not _reserved_ship_id.is_empty() and _reserved_ship_id != definition.ship_id:
		return false
	return true


## Pure compatibility query for berth selection and HUD previews. Availability
## and lease ownership remain separate concerns in `can_accept()`.
func is_compatible_with(definition: ShipDefinition) -> bool:
	return definition != null \
		and definition.is_definition_valid() \
		and _is_compatible(definition)


## Attempts an exclusive reservation and returns an opaque lease token. Calling
## again with the same requester and definition is idempotent and returns the
## existing token. An empty token means the berth was not claimable.
func try_reserve(requester: Node, definition: ShipDefinition) -> StringName:
	if requester == null or not can_accept(definition, requester):
		return &""
	if get_reservation_owner() == requester and not _reservation_token.is_empty():
		return _reservation_token
	_token_serial += 1
	_reservation_owner = weakref(requester)
	_reserved_ship_id = definition.ship_id
	_reservation_token = StringName("%s:%d:%d:%d" % [
		str(berth_id),
		requester.get_instance_id(),
		_token_serial,
		Time.get_ticks_usec(),
	])
	reservation_changed.emit(requester, _reservation_token)
	return _reservation_token


## Converts a valid reservation into physical occupancy. The reservation token
## remains the lease authority until release, making duplicate occupy calls safe.
func occupy(requester: Node, token: StringName) -> bool:
	if not _is_lease_current():
		return false
	_cleanup_stale_claims()
	if not _owns_reservation(requester, token):
		return false
	var current_occupant := get_occupant()
	if current_occupant == requester:
		return true
	if current_occupant != null:
		return false
	_occupant = weakref(requester)
	occupancy_changed.emit(requester)
	return true


## Releases either a pending reservation or an occupied lease. Both requester
## identity and token must match; stale, duplicate, or foreign releases fail.
func release(requester: Node, token: StringName) -> bool:
	if not _is_lease_current():
		return false
	_cleanup_stale_claims()
	if not _owns_reservation(requester, token):
		return false
	var had_occupant := get_occupant() != null
	_reservation_owner = null
	_occupant = null
	_reservation_token = &""
	_reserved_ship_id = &""
	reservation_changed.emit(null, &"")
	if had_occupant:
		occupancy_changed.emit(null)
	return true


func get_reservation_owner() -> Node:
	return _weak_node(_reservation_owner)


func get_occupant() -> Node:
	return _weak_node(_occupant)


func get_reserved_ship_id() -> StringName:
	_cleanup_stale_claims()
	return _reserved_ship_id


func get_reservation_token(requester: Node) -> StringName:
	_cleanup_stale_claims()
	return _reservation_token if requester != null and get_reservation_owner() == requester else &""


## Verifies the complete identity of a pending or occupied berth lease. Landing
## assist snapshots the opaque token and ship ID, then calls this every physics
## tick so a release/reissue race cannot inherit authority from an old claim.
func has_valid_lease(
	requester: Node,
	token: StringName,
	expected_ship_id: StringName
	) -> bool:
	if not _is_lease_current():
		return false
	_cleanup_stale_claims()
	if expected_ship_id.is_empty() \
			or _reserved_ship_id != expected_ship_id \
			or not _owns_reservation(requester, token):
		return false
	var occupant := get_occupant()
	return occupant == null or occupant == requester


func is_reserved() -> bool:
	_cleanup_stale_claims()
	return get_reservation_owner() != null


func is_occupied() -> bool:
	_cleanup_stale_claims()
	return get_occupant() != null


## Finds the first matching berth beneath a scene subtree. This is a scene-tree
## lookup convenience only; duplicate berth IDs should be rejected by a fleet
## registry or validation test at the integration boundary.
static func find(search_root: Node, requested_id: StringName) -> ShipBerth:
	if search_root == null or requested_id.is_empty():
		return null
	if search_root is ShipBerth and (search_root as ShipBerth).berth_id == requested_id:
		return search_root as ShipBerth
	for child in search_root.get_children():
		var match := ShipBerth.find(child, requested_id)
		if match != null:
			return match
	return null


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_stable_id(str(berth_id)):
		errors.append("berth_id must be a 1-64 character lowercase snake_case identifier")
	if not _is_valid_transform(dock_transform):
		errors.append("dock_transform must be finite and have an invertible basis")
	if not _is_valid_volume():
		errors.append("landing_half_extents must contain three finite values greater than zero")
	if not assist_capture_center.is_finite():
		errors.append("assist_capture_center must contain three finite values")
	if not assist_capture_half_extents.is_finite() \
			or assist_capture_half_extents.x <= 0.0 \
			or assist_capture_half_extents.y <= 0.0 \
			or assist_capture_half_extents.z <= 0.0:
		errors.append("assist_capture_half_extents must contain three finite values greater than zero")
	if not is_finite(assist_capture_maximum_speed) or assist_capture_maximum_speed <= 0.0:
		errors.append("assist_capture_maximum_speed must be finite and greater than zero")
	if not is_finite(assist_maximum_tilt_degrees) \
			or assist_maximum_tilt_degrees <= 0.0 \
			or assist_maximum_tilt_degrees >= 90.0:
		errors.append("assist_maximum_tilt_degrees must be finite and between zero and 90 degrees")
	var seen := PackedStringArray()
	for tag in compatibility_tags:
		if not _is_stable_id(tag):
			errors.append("compatibility tag '%s' is not a lowercase snake_case identifier" % tag)
		elif seen.has(tag):
			errors.append("compatibility tag '%s' is duplicated" % tag)
		else:
			seen.append(tag)
	return errors


func audit() -> Dictionary:
	_cleanup_stale_claims()
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"berth_id": berth_id,
		"dock_transform": get_dock_transform(),
		"landing_half_extents": landing_half_extents,
		"assist_capture_center": assist_capture_center,
		"assist_capture_half_extents": assist_capture_half_extents,
		"assist_capture_maximum_speed": assist_capture_maximum_speed,
		"assist_maximum_tilt_degrees": assist_maximum_tilt_degrees,
		"assist_capture_transform": get_assist_capture_transform(),
		"assist_staging_transform": get_assist_staging_transform(),
		"compatibility_tags": get_compatibility_tags(),
		"reserved": get_reservation_owner() != null,
		"occupied": get_occupant() != null,
		"reserved_ship_id": _reserved_ship_id,
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _is_compatible(definition: ShipDefinition) -> bool:
	if compatibility_tags.is_empty():
		return true
	var definition_tags := definition.get_compatibility_tags()
	for tag in compatibility_tags:
		if definition_tags.has(tag):
			return true
	return false


func _owns_reservation(requester: Node, token: StringName) -> bool:
	return requester != null \
		and is_instance_valid(requester) \
		and not token.is_empty() \
		and token == _reservation_token \
		and get_reservation_owner() == requester


func _is_lease_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _cleanup_stale_claims() -> void:
	var owner := _weak_node(_reservation_owner)
	var occupant := _weak_node(_occupant)
	if _reservation_owner != null and owner == null:
		_reservation_owner = null
		_occupant = null
		_reservation_token = &""
		_reserved_ship_id = &""
		return
	if _occupant != null and occupant == null:
		_occupant = null


static func _weak_node(reference: WeakRef) -> Node:
	if reference == null:
		return null
	var candidate: Variant = reference.get_ref()
	return candidate as Node if is_instance_valid(candidate) and candidate is Node else null


func _is_valid_volume() -> bool:
	return landing_half_extents.is_finite() \
		and landing_half_extents.x > 0.0 \
		and landing_half_extents.y > 0.0 \
		and landing_half_extents.z > 0.0


func _is_valid_assist_capture() -> bool:
	return assist_capture_center.is_finite() \
		and assist_capture_half_extents.is_finite() \
		and assist_capture_half_extents.x > 0.0 \
		and assist_capture_half_extents.y > 0.0 \
		and assist_capture_half_extents.z > 0.0 \
		and is_finite(assist_capture_maximum_speed) \
		and assist_capture_maximum_speed > 0.0 \
		and is_finite(assist_maximum_tilt_degrees) \
		and assist_maximum_tilt_degrees > 0.0 \
		and assist_maximum_tilt_degrees < 90.0


static func _is_valid_transform(value: Transform3D) -> bool:
	if not value.origin.is_finite() \
			or not value.basis.x.is_finite() \
			or not value.basis.y.is_finite() \
			or not value.basis.z.is_finite():
		return false
	var basis := value.basis
	return basis.determinant() > 0.0 \
		and absf(basis.determinant() - 1.0) <= 0.001 \
		and absf(basis.x.length_squared() - 1.0) <= 0.001 \
		and absf(basis.y.length_squared() - 1.0) <= 0.001 \
		and absf(basis.z.length_squared() - 1.0) <= 0.001 \
		and absf(basis.x.dot(basis.y)) <= 0.001 \
		and absf(basis.x.dot(basis.z)) <= 0.001 \
		and absf(basis.y.dot(basis.z)) <= 0.001


static func _is_valid_bounds(value: AABB) -> bool:
	return value.position.is_finite() \
		and value.size.is_finite() \
		and value.size.x > 0.0 \
		and value.size.y > 0.0 \
		and value.size.z > 0.0


static func _aabb_corners(value: AABB) -> PackedVector3Array:
	var minimum := value.position
	var maximum := value.end
	return PackedVector3Array([
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
	])


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") or value.ends_with("_") or value.contains("__"):
		return false
	var first_code := value.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower_letter and not is_digit and code != 95:
			return false
	return true
