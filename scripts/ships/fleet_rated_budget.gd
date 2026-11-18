class_name FleetRatedBudget
extends Resource

## Authored handling and an optional detached measurement of live root collision.
## Metadata keeps actual profile provenance and never scores undirected feel.
const FIELD_SPECS := {
	"maximum_speed": ["m/s", "benefit", "flight"],
	"maximum_hull": ["hull point", "benefit", "systems"],
	"boost_speed": ["m/s", "benefit", "flight"],
	"thrust_acceleration": ["m/s2", "benefit", "flight"],
	"yaw_speed_degrees": ["degree/s", "benefit", "flight"],
	"roll_speed_degrees": ["degree/s", "benefit", "flight"],
	"brake_acceleration": ["m/s2", "benefit", "flight"],
	"passive_drag": ["m/s2", "cost", "flight"],
	"boost_multiplier": ["ratio", "benefit", "flight"],
	"landing_maximum_speed": ["m/s", "benefit", "systems"],
	"engine_start_time": ["s", "cost", "systems"],
	"weapon_cooldown": ["s", "cost", "systems"],
	"throttle_response": ["1/s", "benefit", "flight"],
	"flight_assist_strength": ["1/s", "undirected", "flight"],
	"visual_bank_degrees": ["degree", "undirected", "flight"],
	"maximum_mouse_turn_degrees": ["degree", "undirected", "flight"],
}
const MISSING_DIMENSIONS := [
	"component_consequences_and_repair", "firepower_and_range", "cargo",
	"passenger_and_support", "collision_footprint", "boarding_time", "skill_floor",
	"complete_role_and_capability_metadata",
]

var _valid: bool = false
var _reason: StringName = &"missing_definition"
var _ship_id: StringName = &""
const FOOTPRINT_SOURCE := "actual_enabled_direct_root_collision_shapes"
const FOOTPRINT_AXES := ["span", "height", "length"]
var _fields: Dictionary = {}
var _footprint: Dictionary = {"status": "UNKNOWN", "reason": "live_craft_not_supplied", "source": FOOTPRINT_SOURCE}


func _init(definition: ShipDefinition = null, actual_craft: HeroShip = null) -> void:
	if definition == null:
		return
	_reason = &"invalid_definition"
	if not definition.is_definition_valid():
		return
	var flight := definition.get_flight_profile()
	var systems := definition.get_systems_profile()
	var sourced: Dictionary = {}
	for axis: String in FIELD_SPECS:
		var spec: Array = FIELD_SPECS[axis]
		var profile: Dictionary = flight if spec[2] == "flight" else systems
		var raw: float = profile[axis]
		if not is_finite(raw) or raw < 0.0:
			return
		sourced[axis] = _field(raw, spec[0], spec[1], "ShipDefinition.get_%s_profile.%s" % [spec[2], axis])
	_ship_id = definition.get_ship_id()
	_fields = sourced
	_valid = true
	_reason = &"rated_handling_sourced"
	if actual_craft != null:
		_footprint = _measure_footprint(definition, actual_craft)


func is_valid() -> bool:
	return _valid


func get_ship_id() -> StringName:
	return _ship_id


func get_snapshot() -> Dictionary:
	var snapshot := {
		"valid": _valid, "reason": _reason, "ship_id": _ship_id,
		"qualification": &"NOT_QUALIFIED",
		"missing_dimensions": MISSING_DIMENSIONS.duplicate(),
		"footprint": _footprint.duplicate(true),
	}
	if _footprint.status == "MEASURED":
		snapshot.missing_dimensions.erase("collision_footprint")
	if _valid:
		snapshot["fields"] = _fields.duplicate(true)
	return snapshot.duplicate(true)


func _field(raw: float, unit: String, direction: String, source: String) -> Dictionary:
	var field := {"raw": raw, "unit": unit, "direction": direction,
		"unit_scale": 1.0, "source": source}
	if direction != "undirected":
		field["normalized"] = raw / (1.0 + raw) if direction == "benefit" else 1.0 / (1.0 + raw)
	return field


func _unavailable(reason: String) -> Dictionary:
	return {"status": "UNAVAILABLE", "reason": reason, "source": FOOTPRINT_SOURCE}


func _measure_footprint(definition: ShipDefinition, craft: HeroShip) -> Dictionary:
	if not is_instance_valid(craft) or not craft.is_inside_tree() or craft.is_queued_for_deletion() or craft.is_destroyed():
		return _unavailable("live_craft_unavailable")
	if craft.get_ship_definition() != definition or craft.get_ship_id() != definition.get_ship_id():
		return _unavailable("live_definition_identity_mismatch")
	var root_transform := craft.global_transform
	if not _valid_root_transform(root_transform):
		return _unavailable("root_transform_not_proper_rigid")
	var combined := AABB()
	var count := 0
	for child in craft.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled:
			continue
		if collision.is_queued_for_deletion() or collision.shape == null:
			return _unavailable("enabled_shape_unavailable")
		var pose := collision.transform
		if not _valid_shape_transform(pose):
			return _unavailable("enabled_shape_transform_invalid")
		var bounds := _shape_bounds(collision.shape, pose)
		if not bounds.position.is_finite() or not bounds.size.is_finite() or not bounds.has_volume():
			return _unavailable("enabled_shape_unsupported_or_empty")
		combined = bounds if count == 0 else combined.merge(bounds)
		count += 1
	if count == 0:
		return _unavailable("no_enabled_root_shapes")
	var fields := {}
	for index in 3:
		fields[FOOTPRINT_AXES[index]] = _field(combined.size[index], "m", "cost", FOOTPRINT_SOURCE)
	return {"status": "MEASURED", "reason": "complete_enabled_root_union", "source": FOOTPRINT_SOURCE,
		"ship_id": str(_ship_id), "shape_count": count, "fields": fields,
		"local_bounds": {"position": _vector_snapshot(combined.position), "size": _vector_snapshot(combined.size)}}


func _valid_root_transform(pose: Transform3D) -> bool:
	return pose.is_finite() and is_equal_approx(pose.basis.determinant(), 1.0) and pose.basis.is_equal_approx(pose.basis.orthonormalized())


func _valid_shape_transform(pose: Transform3D) -> bool:
	return pose.is_finite() and not is_zero_approx(pose.basis.determinant())


func _vector_snapshot(value: Vector3) -> Dictionary:
	return {"x": float(value.x), "y": float(value.y), "z": float(value.z)}


func _shape_bounds(shape: Shape3D, pose: Transform3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			return AABB()
		return pose * AABB(-size * 0.5, size)
	if shape is ConvexPolygonShape3D:
		var points := (shape as ConvexPolygonShape3D).points
		if points.size() < 4:
			return AABB()
		var bounds := AABB(pose * points[0], Vector3.ZERO)
		for point in points:
			if not point.is_finite():
				return AABB()
			bounds = bounds.expand(pose * point)
		return bounds
	var radius := 0.0
	var segment := 0.0
	var cylinder := false
	if shape is CylinderShape3D:
		radius = (shape as CylinderShape3D).radius
		segment = (shape as CylinderShape3D).height * 0.5
		cylinder = true
	elif shape is SphereShape3D:
		radius = (shape as SphereShape3D).radius
	elif shape is CapsuleShape3D:
		radius = (shape as CapsuleShape3D).radius
		segment = (shape as CapsuleShape3D).height * 0.5 - radius
	else:
		return AABB()
	if not is_finite(radius) or not is_finite(segment) or radius <= 0.0 or segment < 0.0 or (cylinder and segment <= 0.0):
		return AABB()
	var extent := Vector3.ZERO
	for axis in 3:
		var row := Vector3(pose.basis.x[axis], pose.basis.y[axis], pose.basis.z[axis])
		extent[axis] = radius * (sqrt(row.x * row.x + row.z * row.z) if cylinder else row.length()) + segment * absf(row.y)
	return AABB(pose.origin - extent, extent * 2.0)
