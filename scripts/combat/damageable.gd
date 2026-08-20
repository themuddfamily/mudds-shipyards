class_name Damageable
extends Node

## Reusable authoritative health/faction component.
##
## Place this beneath a CollisionObject3D, or beside a body/area beneath the
## same entity node. CombatResolver locates the nearest component without
## depending on a particular ship, character, body, or hurtbox script.

signal health_changed(current: float, maximum: float)
signal damage_applied(
	amount: float,
	current: float,
	maximum: float,
	hit_position: Vector3,
	hit_normal: Vector3,
	source_context: Dictionary
)
signal destroyed(hit_position: Vector3, hit_normal: Vector3, source_context: Dictionary)
signal reset(current: float, maximum: float)

@export_range(0.001, 1000000.0, 0.001, "or_greater") var maximum_health: float = 100.0:
	set(value):
		maximum_health = _sanitize_maximum(value)
		if _initialized:
			_health = minf(_health, maximum_health)
			_destroyed = _health <= 0.0
			health_changed.emit(_health, maximum_health)
@export var faction_id: StringName = &"neutral"
@export var damage_enabled: bool = true
@export var target_entity_path: NodePath

var _health: float = 0.0
var _initialized := false
var _has_entered_live_tree := false
var _destroyed := false
var _last_hit_position := Vector3.INF
var _last_hit_normal := Vector3.ZERO
var _last_source_context: Dictionary = {}


func _ready() -> void:
	_has_entered_live_tree = true
	if not _initialized:
		_initialize_health()


func _initialize_health() -> void:
	maximum_health = _sanitize_maximum(maximum_health)
	_health = maximum_health
	_destroyed = false
	_initialized = true


func get_health() -> float:
	_ensure_initialized()
	return _health


func get_maximum_health() -> float:
	return _sanitize_maximum(maximum_health)


func get_faction_id() -> StringName:
	return faction_id


func is_destroyed() -> bool:
	_ensure_initialized()
	return _destroyed


func can_receive_damage() -> bool:
	_ensure_initialized()
	return damage_enabled and not _destroyed and _health > 0.0


func get_target_entity() -> Node:
	if not target_entity_path.is_empty():
		var configured := get_node_or_null(target_entity_path)
		if configured != null:
			return configured
	return get_parent()


func get_last_hit_context() -> Dictionary:
	return {
		"position": _last_hit_position,
		"normal": _last_hit_normal,
		"source": _last_source_context.duplicate(true),
	}


## Applies actual (health-clamped) damage and returns an authority result that
## the resolver can merge into its ray result.
func apply_damage(
	amount: float,
	hit_position: Vector3 = Vector3.INF,
	hit_normal: Vector3 = Vector3.ZERO,
	source_context: Dictionary = {}
	) -> Dictionary:
	if not _can_mutate_runtime_health():
		return {
			"accepted": false,
			"applied_damage": 0.0,
			"health": _health,
			"maximum_health": maximum_health,
			"destroyed": _destroyed,
			"reason": &"damageable_unavailable",
		}
	_ensure_initialized()
	var result := {
		"accepted": false,
		"applied_damage": 0.0,
		"health": _health,
		"maximum_health": maximum_health,
		"destroyed": _destroyed,
	}
	if not damage_enabled:
		result["reason"] = &"damage_disabled"
		return result
	if _destroyed or _health <= 0.0:
		result["reason"] = &"already_destroyed"
		return result
	if not is_finite(amount) or amount <= 0.0:
		result["reason"] = &"invalid_damage"
		return result

	var safe_position := hit_position if hit_position.is_finite() else Vector3.INF
	var safe_normal := hit_normal
	if not safe_normal.is_finite() or safe_normal.length_squared() <= 0.000001:
		safe_normal = Vector3.ZERO
	else:
		safe_normal = safe_normal.normalized()
	var safe_context := source_context.duplicate(true)
	var applied := minf(amount, _health)
	_health = maxf(0.0, _health - applied)
	_last_hit_position = safe_position
	_last_hit_normal = safe_normal
	_last_source_context = safe_context.duplicate(true)
	_destroyed = _health <= 0.0

	result["accepted"] = true
	result["applied_damage"] = applied
	result["health"] = _health
	result["destroyed"] = _destroyed
	damage_applied.emit(
		applied,
		_health,
		maximum_health,
		safe_position,
		safe_normal,
		safe_context.duplicate(true)
	)
	health_changed.emit(_health, maximum_health)
	if _destroyed:
		destroyed.emit(safe_position, safe_normal, safe_context.duplicate(true))
	return result


## Re-arms pooled/despawned entities and emits a distinct lifecycle event.
func reset_health(new_maximum_health: float = -1.0) -> void:
	if not _can_mutate_runtime_health():
		return
	if is_finite(new_maximum_health) and new_maximum_health > 0.0:
		maximum_health = new_maximum_health
	maximum_health = _sanitize_maximum(maximum_health)
	_health = maximum_health
	_destroyed = false
	_initialized = true
	_last_hit_position = Vector3.INF
	_last_hit_normal = Vector3.ZERO
	_last_source_context.clear()
	health_changed.emit(_health, maximum_health)
	reset.emit(_health, maximum_health)


func _ensure_initialized() -> void:
	if not _initialized:
		_initialize_health()


func _can_mutate_runtime_health() -> bool:
	return not _has_entered_live_tree or (
		is_inside_tree() and not is_queued_for_deletion()
	)


func _sanitize_maximum(value: float) -> float:
	if not is_finite(value) or value <= 0.0:
		return 1.0
	return value
