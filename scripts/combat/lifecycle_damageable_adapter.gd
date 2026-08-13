class_name LifecycleDamageableAdapter
extends Damageable

## Bridges CombatResolver into an existing vehicle lifecycle without owning a
## second health value. The legacy craft remains the only source of truth for
## hull, staged damage presentation, destruction, pooling, and regeneration.

enum LifecycleKind {
	HERO_SHIP,
	RANGE_OPPONENT,
}

@export var lifecycle_kind := LifecycleKind.HERO_SHIP

var _last_proxy_hit_position := Vector3.INF
var _last_proxy_hit_normal := Vector3.ZERO
var _last_proxy_source_context: Dictionary = {}


func _ready() -> void:
	# Damageable's internal health store is deliberately not initialized. Every
	# query below reads the attached lifecycle object instead.
	pass


func get_target_entity() -> Node:
	if not target_entity_path.is_empty():
		var configured := get_node_or_null(target_entity_path)
		if configured != null:
			return configured
	return get_parent()


func get_health() -> float:
	var target := get_target_entity()
	if not is_instance_valid(target):
		return 0.0
	if lifecycle_kind == LifecycleKind.HERO_SHIP and target.has_method("get_telemetry"):
		var telemetry: Variant = target.call("get_telemetry")
		if telemetry is Dictionary:
			return maxf(0.0, float((telemetry as Dictionary).get("hull", 0.0)))
	if target.has_method("get_health"):
		return maxf(0.0, float(target.call("get_health")))
	return 0.0


func get_maximum_health() -> float:
	var target := get_target_entity()
	if not is_instance_valid(target):
		return 1.0
	if lifecycle_kind == LifecycleKind.HERO_SHIP and target.has_method("get_telemetry"):
		var telemetry: Variant = target.call("get_telemetry")
		if telemetry is Dictionary:
			return maxf(0.001, float((telemetry as Dictionary).get("maximum_hull", 1.0)))
	if lifecycle_kind == LifecycleKind.RANGE_OPPONENT:
		return maxf(0.001, float(target.get("maximum_health")))
	return maxf(0.001, get_health())


func get_faction_id() -> StringName:
	return faction_id


func is_destroyed() -> bool:
	var target := get_target_entity()
	if not is_instance_valid(target):
		return true
	if target.has_method("is_destroyed"):
		return bool(target.call("is_destroyed"))
	if lifecycle_kind == LifecycleKind.RANGE_OPPONENT and target.has_method("is_active"):
		return not bool(target.call("is_active")) and get_health() <= 0.0
	return get_health() <= 0.0


func can_receive_damage() -> bool:
	if not damage_enabled:
		return false
	var target := get_target_entity()
	if not is_instance_valid(target) or not target.has_method("apply_damage"):
		return false
	if lifecycle_kind == LifecycleKind.RANGE_OPPONENT:
		return target.has_method("is_active") and bool(target.call("is_active")) and get_health() > 0.0
	return not is_destroyed() and get_health() > 0.0


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
		result["reason"] = &"lifecycle_unavailable"
		return result

	var safe_position := hit_position if hit_position.is_finite() else Vector3.INF
	var safe_normal := hit_normal
	if not safe_normal.is_finite() or safe_normal.length_squared() <= 0.000001:
		safe_normal = Vector3.ZERO
	else:
		safe_normal = safe_normal.normalized()
	var target := get_target_entity()
	var presentation_receipt_id := int(source_context.get("presentation_receipt_id", -1))
	var defer_presentation := presentation_receipt_id >= 0
	if lifecycle_kind == LifecycleKind.HERO_SHIP:
		target.call(
			"apply_damage",
			amount,
			safe_position,
			safe_normal,
			presentation_receipt_id,
			defer_presentation
		)
	else:
		target.call(
			"apply_damage",
			amount,
			safe_position,
			presentation_receipt_id,
			defer_presentation
		)

	var after := get_health()
	var applied := maxf(0.0, before - after)
	var now_destroyed := is_destroyed()
	result["health"] = after
	result["destroyed"] = now_destroyed
	if applied <= 0.000001:
		result["reason"] = &"lifecycle_rejected"
		return result

	var safe_context := source_context.duplicate(true)
	_last_proxy_hit_position = safe_position
	_last_proxy_hit_normal = safe_normal
	_last_proxy_source_context = safe_context.duplicate(true)
	result["accepted"] = true
	result["applied_damage"] = applied
	damage_applied.emit(
		applied,
		after,
		get_maximum_health(),
		safe_position,
		safe_normal,
		safe_context.duplicate(true)
	)
	health_changed.emit(after, get_maximum_health())
	if now_destroyed:
		destroyed.emit(safe_position, safe_normal, safe_context.duplicate(true))
	return result
