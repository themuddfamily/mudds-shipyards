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
const PILOT_SOURCE := "actual_registered_pilot_weapon_and_firing_constraints"
const PILOT_FIELDS := {
	"damage": ["damage/trigger", "benefit"], "range": ["m", "benefit"],
	"cooldown": ["s", "cost"], "warmup": ["s", "cost"],
	"heatlockout": ["s", "cost"], "minimum_operators": ["operator", "cost"],
	"ammo_capacity": ["round", "benefit"],
}
var _pilot_weapon: Dictionary = {"status": "UNKNOWN", "reason": "live_craft_not_supplied", "source": PILOT_SOURCE}
var _fields: Dictionary = {}
var _footprint: Dictionary = {"status": "UNKNOWN", "reason": "live_craft_not_supplied", "source": FOOTPRINT_SOURCE}


func _init(definition: ShipDefinition = null, actual_craft: HeroShip = null, pilot_source: Dictionary = {}) -> void:
	if definition == null or actual_craft != null:
		_pilot_weapon = {"status": "UNAVAILABLE", "reason": "live_pilot_source_unavailable", "source": PILOT_SOURCE}
	if definition == null:
		return
	_reason = &"invalid_definition"
	if not definition.is_definition_valid():
		_pilot_weapon = {"status": "UNAVAILABLE", "reason": "live_pilot_source_unavailable", "source": PILOT_SOURCE}
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
		_pilot_weapon = _measure_pilot(definition, actual_craft, pilot_source)


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
		"pilot_weapon": _pilot_weapon.duplicate(true),
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


func _measure_pilot(definition: ShipDefinition, craft: HeroShip, source: Dictionary) -> Dictionary:
	var unavailable := {"status": "UNAVAILABLE", "reason": "live_pilot_source_unavailable", "source": PILOT_SOURCE}
	if not is_instance_valid(craft) or not craft.is_inside_tree() or craft.is_queued_for_deletion() or craft.is_destroyed():
		return unavailable
	if craft.get_ship_definition() != definition or craft.get_ship_id() != definition.get_ship_id() or not _detached_finite(source):
		return unavailable
	if not source.get("ship_id") is String or not source.get("status") is String:
		return unavailable
	if source.ship_id != str(_ship_id):
		return unavailable
	if source.get("status") == "UNARMED" and _ship_id == &"predator_provisional":
		return {"status": "UNARMED", "reason": "production_pilot_unarmed", "source": PILOT_SOURCE,
			"ship_id": str(_ship_id), "selected_context": "", "contexts": {}}
	if source.status != "SOURCED" or not source.get("selected_context") is String or not source.get("profiles") is Dictionary or not source.get("constraints") is Dictionary:
		return unavailable
	var contexts := {}
	for context: Variant in source.profiles:
		var item: Variant = source.profiles[context]
		if not item is Dictionary or not item.get("resolver_profile") is Dictionary or not item.get("weapon_id") is String:
			return unavailable
		var built := _pilot_context(item.weapon_id, item.resolver_profile, source.constraints)
		if built.is_empty():
			return unavailable
		contexts[context] = built
	if source.constraints != craft.get_pilot_weapon_constraints():
		return unavailable
	var result := {"status": "SOURCED", "reason": "actual_registered_pilot_configuration", "source": PILOT_SOURCE,
		"ship_id": str(_ship_id), "selected_context": source.get("selected_context"), "contexts": contexts}
	return result if valid_pilot_weapon(result, str(_ship_id)) else unavailable


static func _detached_finite(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not _detached_finite(value[key]):
				return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _detached_finite(item):
				return false
		return true
	return value is String or value is StringName or value is bool or ((value is float or value is int) and is_finite(float(value)))


static func _pilot_context(weapon_id: String, profile: Dictionary, constraints: Dictionary) -> Dictionary:
	if weapon_id.is_empty() or not _detached_finite(profile) or not _detached_finite(constraints):
		return {}
	var allowed_profile_keys := ["range", "damage", "origin_tolerance", "trigger_damage", "spread_degrees", "pellet_count",
		"projectile_speed", "projectile_lifetime", "projectile_radius", "heat_per_shot", "heat_capacity", "heat_cooldown_per_second", "heat_lockout_seconds"]
	for key: Variant in profile:
		if not key is String or key not in allowed_profile_keys or not _nonnegative_number(profile[key]) or float(profile[key]) <= 0.0:
			return {}
	for axis: String in ["range", "damage", "origin_tolerance"]:
		if not profile.has(axis):
			return {}
	for group: Array in [["trigger_damage", "spread_degrees", "pellet_count"], ["projectile_speed", "projectile_lifetime", "projectile_radius"], ["heat_per_shot", "heat_capacity", "heat_cooldown_per_second", "heat_lockout_seconds"]]:
		var count := 0
		for key: String in group:
			count += int(profile.has(key))
		if count != 0 and count != group.size():
			return {}
	if profile.has("trigger_damage") and (float(profile.pellet_count) != 3.0 or not is_equal_approx(float(profile.trigger_damage), float(profile.damage) * float(profile.pellet_count))):
		return {}
	for axis: String in ["cooldown", "warmup", "minimum_operators"]:
		if not _nonnegative_number(constraints.get(axis)):
			return {}
	if float(constraints.warmup) != 0.0 or float(constraints.minimum_operators) != 1.0 or not constraints.get("ammo_unbounded") is bool:
		return {}
	var thermal: Variant = constraints.get("thermal")
	if not thermal is Dictionary or not thermal.get("model") is String or not constraints.get("refill_rule") is String:
		return {}
	var lockout := 0.0
	if thermal.get("model") == "native":
		if thermal.size() != 6:
			return {}
		var expected := {"heat_per_shot": 0.28, "heat_capacity": 1.0, "cooling_per_second": 0.50, "lockout_seconds": 1.0, "recovery_heat": 0.35}
		for axis: String in expected:
			if not _nonnegative_number(thermal.get(axis)) or float(thermal[axis]) != expected[axis]:
				return {}
		lockout = float(thermal.lockout_seconds)
	elif thermal.model != "none" or thermal.size() != 1:
		return {}
	if constraints.ammo_unbounded:
		if constraints.size() != 6 or constraints.get("refill_rule") != "unbounded":
			return {}
	elif constraints.size() != 7 or not _nonnegative_number(constraints.get("ammo_capacity")) or float(constraints.ammo_capacity) != 4.0 or constraints.get("refill_rule") != "pilot_retake_only":
		return {}
	var raw := {"damage": profile.get("trigger_damage", profile.damage), "range": profile.range,
		"cooldown": constraints.cooldown, "warmup": constraints.warmup, "heatlockout": lockout,
		"minimum_operators": constraints.minimum_operators}
	var fields := {}
	for axis: String in raw:
		var number := float(raw[axis])
		var spec: Array = PILOT_FIELDS[axis]
		var provenance := "HeroShip.get_pilot_weapon_constraints.%s" % axis
		if axis in ["damage", "range"]:
			provenance = "LiveCombatAuthority.get_weapon_profile.%s" % ("trigger_damage" if axis == "damage" and profile.has("trigger_damage") else axis)
		fields[axis] = {"raw": number, "unit": spec[0], "direction": spec[1], "unit_scale": 1.0,
			"source": provenance, "normalized": number / (1.0 + number) if spec[1] == "benefit" else 1.0 / (1.0 + number)}
	fields["ammo_capacity"] = {"unbounded": constraints.ammo_unbounded, "unit": "round", "direction": "benefit",
		"unit_scale": 1.0, "source": "HeroShip.get_pilot_weapon_constraints.ammo_capacity", "normalized": 1.0}
	if not constraints.ammo_unbounded:
		fields.ammo_capacity["raw"] = float(constraints.ammo_capacity)
		fields.ammo_capacity.normalized = float(constraints.ammo_capacity) / (1.0 + float(constraints.ammo_capacity))
	return {"weapon_id": weapon_id, "resolver_profile": profile.duplicate(true),
		"constraints": constraints.duplicate(true), "fields": fields}


static func _nonnegative_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0


## Whole-payload validation is independent of the currently displayed page.
static func valid_pilot_weapon(value: Variant, ship_id: String) -> bool:
	if not value is Dictionary or not _detached_finite(value):
		return false
	for key: String in ["status", "reason", "source"]:
		if not value.get(key) is String:
			return false
	if value.source != PILOT_SOURCE:
		return false
	if value.status in ["UNKNOWN", "UNAVAILABLE"]:
		return value.size() == 3 and value.reason == ("live_craft_not_supplied" if value.status == "UNKNOWN" else "live_pilot_source_unavailable")
	if value.size() != 6 or not value.get("ship_id") is String or value.ship_id != ship_id or not value.get("selected_context") is String or not value.get("contexts") is Dictionary:
		return false
	if value.status == "UNARMED":
		return ship_id == "predator_provisional" and value.reason == "production_pilot_unarmed" and value.selected_context == "" and value.contexts.is_empty()
	if value.status != "SOURCED" or value.reason != "actual_registered_pilot_configuration" or ship_id == "predator_provisional":
		return false
	var contexts: Dictionary = value.contexts
	if contexts.size() != (2 if ship_id == "torrent_provisional" else 1) or not contexts.has("combat") or not contexts.has(value.selected_context):
		return false
	if contexts.size() == 2 and not contexts.has("tutorial_range"):
		return false
	for context: Variant in contexts:
		if not context is String or context not in ["combat", "tutorial_range"]:
			return false
		var item: Variant = contexts[context]
		if not item is Dictionary or not item.get("weapon_id") is String or not item.get("resolver_profile") is Dictionary or not item.get("constraints") is Dictionary or not item.get("fields") is Dictionary:
			return false
		var expected := _pilot_context(item.weapon_id, item.resolver_profile, item.constraints)
		if expected.is_empty() or item.size() != 4 or item.fields.size() != PILOT_FIELDS.size():
			return false
		for axis: String in PILOT_FIELDS:
			var field_raw: Variant = item.fields.get(axis)
			if not field_raw is Dictionary:
				return false
			var field: Dictionary = field_raw
			var expected_field: Dictionary = expected.fields[axis]
			if field.size() != expected_field.size():
				return false
			for key: String in ["unit", "direction", "source"]:
				if not field.get(key) is String or field[key] != expected_field[key]:
					return false
			if not _nonnegative_number(field.get("unit_scale")) or float(field.unit_scale) != float(expected_field.unit_scale):
				return false
			if not _nonnegative_number(field.get("normalized")) or absf(float(field.normalized) - float(expected_field.normalized)) > 0.000000000001:
				return false
			if axis == "ammo_capacity":
				if not field.get("unbounded") is bool or field.unbounded != expected_field.unbounded:
					return false
			if expected_field.has("raw"):
				if not _nonnegative_number(field.get("raw")) or float(field.raw) != float(expected_field.raw):
					return false
			elif field.has("raw"):
				return false
		var no_heat := ship_id in ["paradox_provisional", "cinder_long_range_bomber"]
		if (item.constraints.thermal.model == "none") != no_heat or item.constraints.ammo_unbounded == (ship_id == "cinder_long_range_bomber"):
			return false
	return true
