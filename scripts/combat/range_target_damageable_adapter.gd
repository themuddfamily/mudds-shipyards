class_name RangeTargetDamageableAdapter
extends Damageable

## Authoritative Damageable facade for the procedural target drones. Health
## stays in the target body's existing metadata and destruction is forwarded to
## ShipyardWorld's established burst/signal/cleanup lifecycle.

const MAXIMUM_HEALTH_META: StringName = &"combat_maximum_health"
const ComponentDamageModelType := preload("res://scripts/combat/component_damage_model.gd")

const FRAME_COMPONENT_ID: StringName = &"frame"
const CORE_COMPONENT_ID: StringName = &"core"
const COMPONENT_STAGES := [
	{
		"stage_id": &"nominal",
		"health_ratio_at_or_below": 1.0,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": &"damaged",
		"health_ratio_at_or_below": 0.67,
		"disabled": false,
		"performance_multiplier": 0.72,
	},
	{
		"stage_id": &"critical",
		"health_ratio_at_or_below": 0.34,
		"disabled": false,
		"performance_multiplier": 0.38,
	},
	{
		"stage_id": &"destroyed",
		"health_ratio_at_or_below": 0.0,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
]

var _world_reference: WeakRef
var _last_proxy_hit_position := Vector3.INF
var _last_proxy_hit_normal := Vector3.ZERO
var _last_proxy_source_context: Dictionary = {}
var _component_damage_model: ComponentDamageModel
var _next_component_damage_sequence := 0


func _ready() -> void:
	var target := get_target_entity()
	if is_instance_valid(target) and not target.has_meta(MAXIMUM_HEALTH_META):
		target.set_meta(MAXIMUM_HEALTH_META, maxf(0.001, float(target.get_meta("health", 1.0))))
	_initialize_component_damage()


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
	return (
		_is_damage_target_current(get_target_entity())
		and damage_enabled
		and not is_destroyed()
		and get_health() > 0.0
	)


func get_last_hit_context() -> Dictionary:
	return {
		"position": _last_proxy_hit_position,
		"normal": _last_proxy_hit_normal,
		"source": _last_proxy_source_context.duplicate(true),
	}


## Detached component condition only. Target metadata remains the sole health,
## destruction, collision, and mission-count authority.
func get_component_snapshot() -> Dictionary:
	return (
		_component_damage_model.get_snapshot()
		if _component_damage_model != null
		else {}
	).duplicate(true)


## Reuses the existing model at the world-owned lifecycle boundary. The caller
## supplies its observed generation so duplicate/stale restores cannot advance
## the ledger or clear presentation a second time.
func reset_for_reuse(expected_generation: int) -> Dictionary:
	if _component_damage_model == null:
		return {
			"accepted": false,
			"reason": &"component_model_unavailable",
			"generation": 0,
		}.duplicate(true)
	var reset_result := _component_damage_model.reset_for_reuse(expected_generation)
	if not bool(reset_result.get("accepted", false)):
		return reset_result.duplicate(true)
	_next_component_damage_sequence = 0
	_last_proxy_hit_position = Vector3.INF
	_last_proxy_hit_normal = Vector3.ZERO
	_last_proxy_source_context.clear()
	_present_component_snapshot()
	return reset_result.duplicate(true)


func apply_damage(
	amount: float,
	hit_position: Vector3 = Vector3.INF,
	hit_normal: Vector3 = Vector3.ZERO,
	source_context: Dictionary = {}
	) -> Dictionary:
	var target := get_target_entity()
	var target_is_current := _is_damage_target_current(target)
	var before := get_health() if target_is_current else 0.0
	var result := {
		"accepted": false,
		"applied_damage": 0.0,
		"health": before,
		"maximum_health": get_maximum_health() if target_is_current else 1.0,
		"destroyed": is_destroyed() if target_is_current else true,
	}
	# A target remains valid and can still have a physics RID for the deferred
	# deletion turn. It is nevertheless no longer a current combat lifecycle,
	# so reject before reading or mutating its health metadata or contacting the
	# ShipyardWorld destruction/presentation authority.
	if not target_is_current:
		result["reason"] = &"target_unavailable"
		return result
	if not damage_enabled:
		result["reason"] = &"damage_disabled"
		return result
	if not is_finite(amount) or amount <= 0.0:
		result["reason"] = &"invalid_damage"
		return result
	if not can_receive_damage():
		result["reason"] = &"already_destroyed"
		return result

	var applied := minf(amount, before)
	var after := maxf(0.0, before - applied)
	target.set_meta("health", after)
	_apply_component_damage(applied)
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
	var presentation_receipt_id := int(safe_context.get("presentation_receipt_id", -1))
	if after <= 0.0 and not bool(target.get_meta("destroyed", false)):
		var world_owner := _get_world_owner()
		var authority_committed := false
		if is_instance_valid(world_owner) and world_owner.has_method("authorize_target_destruction"):
			authority_committed = bool(world_owner.call(
				"authorize_target_destruction",
				target,
				StringName(target.get_meta("target_id", &"UNKNOWN")),
				safe_position
			))
		if (
			presentation_receipt_id >= 0
			and is_instance_valid(world_owner)
			and world_owner.has_method("defer_target_damage_presentation")
		):
			if not authority_committed:
				target.set_meta("destroyed", true)
			world_owner.call(
				"defer_target_damage_presentation",
				presentation_receipt_id,
				target,
				StringName(target.get_meta("target_id", &"UNKNOWN")),
				safe_position,
				true
			)
		elif is_instance_valid(world_owner) and world_owner.has_method("present_authorized_target_destruction"):
			world_owner.call(
				"present_authorized_target_destruction",
				target,
				safe_position
			)
		elif is_instance_valid(world_owner) and world_owner.has_method("_destroy_target"):
			world_owner.call(
				"_destroy_target",
				target,
				StringName(target.get_meta("target_id", &"UNKNOWN")),
				safe_position
			)
		else:
			target.set_meta("destroyed", true)
	result["destroyed"] = after <= 0.0
	if after <= 0.0:
		destroyed.emit(safe_position, safe_normal, safe_context.duplicate(true))
	return result


func _initialize_component_damage() -> void:
	var maximum := get_maximum_health()
	_component_damage_model = ComponentDamageModelType.new([
		{
			"component_id": FRAME_COMPONENT_ID,
			"maximum_health": maximum * 0.45,
			"damage_stages": COMPONENT_STAGES.duplicate(true),
		},
		{
			"component_id": CORE_COMPONENT_ID,
			"maximum_health": maximum * 0.60,
			"damage_stages": COMPONENT_STAGES.duplicate(true),
		},
	]) as ComponentDamageModel
	if _component_damage_model == null or not _component_damage_model.is_configuration_valid():
		_component_damage_model = null
		return
	var reset_result := _component_damage_model.reset_for_reuse(0)
	if not bool(reset_result.get("accepted", false)):
		_component_damage_model = null
		return
	_present_component_snapshot()


func _apply_component_damage(applied_hull_damage: float) -> void:
	if _component_damage_model == null or applied_hull_damage <= 0.0:
		return
	var contexts: Array[Dictionary] = []
	for component_spec in [
		{"component_id": FRAME_COMPONENT_ID, "exposure": 0.5},
		{"component_id": CORE_COMPONENT_ID, "exposure": 1.0},
	]:
		var component_id := StringName(component_spec.component_id)
		var state := _component_damage_model.get_component_state(component_id)
		var requested_damage := applied_hull_damage * float(component_spec.exposure)
		if float(state.get("current_health", 0.0)) <= 0.0 or requested_damage <= 0.0:
			continue
		contexts.append({
			"component_id": component_id,
			"damage": requested_damage,
			"generation": _component_damage_model.get_generation(),
			"sequence": _next_component_damage_sequence + contexts.size(),
		})
	if contexts.is_empty():
		return
	var component_result := _component_damage_model.apply_component_damage_batch(contexts)
	if not bool(component_result.get("accepted", false)):
		return
	_next_component_damage_sequence += contexts.size()
	_present_component_snapshot()


func _present_component_snapshot() -> void:
	var world_owner := _get_world_owner()
	var target := get_target_entity()
	if (
		is_instance_valid(world_owner)
		and is_instance_valid(target)
		and world_owner.has_method("apply_range_target_component_presentation")
	):
		world_owner.call(
			"apply_range_target_component_presentation",
			target,
			get_component_snapshot()
		)


func _is_damage_target_current(target: Node) -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(target)
		and target.is_inside_tree()
		and not target.is_queued_for_deletion()
	)


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
