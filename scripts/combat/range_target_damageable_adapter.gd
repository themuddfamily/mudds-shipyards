class_name RangeTargetDamageableAdapter
extends Damageable

## Authoritative Damageable facade for the procedural target drones. Health
## stays in the target body's existing metadata and destruction is forwarded to
## ShipyardWorld's established burst/signal/cleanup lifecycle.

const MAXIMUM_HEALTH_META: StringName = &"combat_maximum_health"

var _world_reference: WeakRef
var _last_proxy_hit_position := Vector3.INF
var _last_proxy_hit_normal := Vector3.ZERO
var _last_proxy_source_context: Dictionary = {}


func _ready() -> void:
	var target := get_target_entity()
	if is_instance_valid(target) and not target.has_meta(MAXIMUM_HEALTH_META):
		target.set_meta(MAXIMUM_HEALTH_META, maxf(0.001, float(target.get_meta("health", 1.0))))


func configure(world_owner: Node, target_faction: StringName = &"range_target") -> void:
	_world_reference = weakref(world_owner) if is_instance_valid(world_owner) else null
	faction_id = target_faction
	target_entity_path = NodePath("..")


func get_target_entity() -> Node:
	if not target_entity_path.is_empty():
		var configured := get_node_or_null(target_entity_path)
		if configured != null:
			return configured
	return get_parent()


func get_health() -> float:
	var target := get_target_entity()
	return maxf(0.0, float(target.get_meta("health", 0.0))) if is_instance_valid(target) else 0.0


func get_maximum_health() -> float:
	var target := get_target_entity()
	if not is_instance_valid(target):
		return 1.0
	return maxf(
		0.001,
		float(target.get_meta(MAXIMUM_HEALTH_META, target.get_meta("health", 1.0)))
	)


func get_faction_id() -> StringName:
	return faction_id


func is_destroyed() -> bool:
	var target := get_target_entity()
	return (
		not is_instance_valid(target)
		or bool(target.get_meta("destroyed", false))
		or get_health() <= 0.0
	)


func can_receive_damage() -> bool:
	return damage_enabled and not is_destroyed() and get_health() > 0.0


func get_last_hit_context() -> Dictionary:
	return {
		"position": _last_proxy_hit_position,
		"normal": _last_proxy_hit_normal,
		"source": _last_proxy_source_context.duplicate(true),
	}


func apply_damage(
	amount: float,
	hit_position: Vector3 = Vector3.INF,
	hit_normal: Vector3 = Vector3.ZERO,
	source_context: Dictionary = {}
	) -> Dictionary:
	var before := get_health()
	var result := {
		"accepted": false,
		"applied_damage": 0.0,
		"health": before,
		"maximum_health": get_maximum_health(),
		"destroyed": is_destroyed(),
	}
	if not damage_enabled:
		result["reason"] = &"damage_disabled"
		return result
	if not is_finite(amount) or amount <= 0.0:
		result["reason"] = &"invalid_damage"
		return result
	if not can_receive_damage():
		result["reason"] = &"already_destroyed"
		return result

	var target := get_target_entity()
	var applied := minf(amount, before)
	var after := maxf(0.0, before - applied)
	target.set_meta("health", after)
	var safe_position := hit_position if hit_position.is_finite() else (target as Node3D).global_position
	var safe_normal := hit_normal
	if not safe_normal.is_finite() or safe_normal.length_squared() <= 0.000001:
		safe_normal = Vector3.ZERO
	else:
		safe_normal = safe_normal.normalized()
	var safe_context := source_context.duplicate(true)
	_last_proxy_hit_position = safe_position
	_last_proxy_hit_normal = safe_normal
	_last_proxy_source_context = safe_context.duplicate(true)

	result["accepted"] = true
	result["applied_damage"] = applied
	result["health"] = after
	damage_applied.emit(
		applied,
		after,
		get_maximum_health(),
		safe_position,
		safe_normal,
		safe_context.duplicate(true)
	)
	health_changed.emit(after, get_maximum_health())
	if after <= 0.0 and not bool(target.get_meta("destroyed", false)):
		var world_owner := _get_world_owner()
		if is_instance_valid(world_owner) and world_owner.has_method("_destroy_target"):
			world_owner.call(
				"_destroy_target",
				target,
				StringName(target.get_meta("target_id", &"UNKNOWN")),
				safe_position
			)
		else:
			target.set_meta("destroyed", true)
		result["destroyed"] = true
		destroyed.emit(safe_position, safe_normal, safe_context.duplicate(true))
	return result


func _get_world_owner() -> Node:
	if _world_reference != null:
		var configured := _world_reference.get_ref() as Node
		if is_instance_valid(configured):
			return configured
	var candidate := get_parent()
	while candidate != null:
		if candidate.has_method("_destroy_target"):
			return candidate
		candidate = candidate.get_parent()
	return null
