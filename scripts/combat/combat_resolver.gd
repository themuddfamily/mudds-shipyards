class_name CombatResolver
extends Node3D

const PhysicsLayerContract := preload("res://scripts/core/physics_layers.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const DamageableType := preload("res://scripts/combat/damageable.gd")

## Node-scoped authority service for deterministic hitscan resolution. The
## sequence ledger intentionally lives on this node so a future multiplayer
## authority can own one resolver per world/session without global state.

signal shot_resolved(request: ShotRequest, result: Dictionary)

@export var allow_friendly_fire := false
@export var enforce_multiplayer_authority := true
@export var require_registered_sources := true

var _last_sequence_by_source: Dictionary = {}
var _source_registry: Dictionary = {}
var _source_key_by_instance_id: Dictionary = {}
var _history_owner_by_source: Dictionary = {}


func _process(_delta: float) -> void:
	_prune_invalid_sources()
	_prune_invalid_history()


## Registers the authority-owned identity, collision root, faction, and weapon
## envelope used to validate future requests. `weapon_profiles` is keyed by
## weapon id; every value must define positive finite `range` and `damage`, and
## may define a positive `origin_tolerance` around the source root.
func register_source(
	source_id: int,
	source_entity: Node3D,
	faction_id: StringName,
	weapon_profiles: Dictionary
	) -> bool:
	if source_id < 0 or not is_instance_valid(source_entity) or faction_id.is_empty():
		return false
	var source_key := _source_key(source_entity, source_id)
	if source_key.is_empty():
		return false
	_prune_invalid_history()
	var instance_id := source_entity.get_instance_id()
	var previous_key := String(_source_key_by_instance_id.get(instance_id, ""))
	if not previous_key.is_empty() and previous_key != source_key:
		return false
	var retained_owner: Dictionary = _history_owner_by_source.get(source_key, {})
	var retained_reference: WeakRef = retained_owner.get("entity") as WeakRef
	var retained_entity: Node = (
		retained_reference.get_ref() as Node if retained_reference != null else null
	)
	if is_instance_valid(retained_entity) and retained_entity != source_entity:
		# A detached live source still owns its stable identity. A different object
		# cannot take over the ID merely because the registration is temporarily out
		# of the physics tree.
		return false
	var normalized_profiles := _normalize_weapon_profiles(weapon_profiles)
	if normalized_profiles.is_empty() or normalized_profiles.size() != weapon_profiles.size():
		return false
	_remove_source_registration(source_key)
	_source_registry[source_key] = {
		"entity": weakref(source_entity),
		"instance_id": instance_id,
		"source_id": source_id,
		"faction_id": faction_id,
		"weapons": normalized_profiles,
	}
	_source_key_by_instance_id[instance_id] = source_key
	_remember_history_owner(source_key, source_entity, source_id)
	if not source_entity.tree_exiting.is_connected(_on_registered_source_exiting):
		source_entity.tree_exiting.connect(
			_on_registered_source_exiting.bind(source_key, instance_id),
			CONNECT_ONE_SHOT
		)
	return true


func resolve_hitscan(request: ShotRequestType) -> Dictionary:
	var result := _make_result(request)
	if request == null:
		return _reject(result, &"invalid_request", "request is null", request)

	var validation_errors := request.get_validation_errors()
	if not validation_errors.is_empty():
		return _reject(
			result,
			&"invalid_request",
			"; ".join(validation_errors),
			request
		)
	if enforce_multiplayer_authority and not is_multiplayer_authority():
		return _reject(result, &"not_authority", "resolver is not multiplayer authority", request)

	var authority_context := _resolve_authority_context(request)
	if not bool(authority_context.get("valid", false)):
		return _reject(
			result,
			authority_context.get("status", &"unregistered_source"),
			str(authority_context.get("reason", "source is not registered")),
			request
		)
	var source_key: String = authority_context.source_key
	result["source_entity"] = authority_context.source_entity
	result["source_id"] = authority_context.source_id
	result["source_faction_id"] = authority_context.faction_id
	var previous_sequence := int(_last_sequence_by_source.get(source_key, -1))
	if request.sequence <= previous_sequence:
		var replay_status := (
			&"duplicate_sequence"
			if request.sequence == previous_sequence
			else &"out_of_order_sequence"
		)
		result["last_sequence"] = previous_sequence
		return _reject(
			result,
			replay_status,
			"sequence %d is not newer than %d" % [request.sequence, previous_sequence],
			request
		)

	if not is_inside_tree() or get_world_3d() == null:
		return _reject(result, &"no_physics_world", "resolver is not in a 3D world", request)

	# Valid authority requests consume their sequence even when they miss or are
	# blocked. Re-sending an already-fired shot can therefore never apply damage.
	_last_sequence_by_source[source_key] = request.sequence
	_remember_history_owner(
		source_key,
		authority_context.source_entity,
		int(authority_context.source_id)
	)
	result["accepted"] = true
	result["resolved"] = true
	result["last_sequence"] = request.sequence

	var authoritative_entity: Node3D = authority_context.source_entity
	var authoritative_range: float = authority_context.range
	var authoritative_damage: float = authority_context.damage
	var authoritative_faction: StringName = authority_context.faction_id
	var ray_direction := request.get_normalized_direction()
	var query := PhysicsRayQueryParameters3D.create(
		request.origin,
		request.origin + ray_direction * authoritative_range,
		PhysicsLayerContract.HITSCAN_QUERY_MASK,
		_collect_source_exclusions(authoritative_entity)
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		result["status"] = &"miss"
		_emit_result(request, result)
		return result

	var collider: Object = hit.get("collider")
	var hit_position: Vector3 = hit.get("position", request.origin + ray_direction * request.range)
	var hit_normal: Vector3 = hit.get("normal", -ray_direction)
	result["hit"] = true
	result["collider"] = collider
	result["position"] = hit_position
	result["normal"] = hit_normal
	result["distance"] = request.origin.distance_to(hit_position)

	var damageable: Damageable = _find_damageable(collider)
	if damageable == null:
		result["status"] = (
			&"world_blocked" if _collider_is_world(collider) else &"non_damageable_blocked"
		)
		_emit_result(request, result)
		return result

	result["damageable"] = damageable
	result["target_entity"] = damageable.get_target_entity()
	result["target_faction_id"] = damageable.get_faction_id()
	if not allow_friendly_fire and _same_faction(authoritative_faction, damageable.get_faction_id()):
		result["status"] = &"friendly_fire_blocked"
		_emit_result(request, result)
		return result

	var damage_result := damageable.apply_damage(
		authoritative_damage,
		hit_position,
		hit_normal,
		_make_authoritative_source_context(request, authority_context)
	)
	result["damage_result"] = damage_result
	result["damaged"] = bool(damage_result.get("accepted", false))
	result["applied_damage"] = float(damage_result.get("applied_damage", 0.0))
	result["remaining_health"] = float(damage_result.get("health", damageable.get_health()))
	result["destroyed"] = bool(damage_result.get("destroyed", damageable.is_destroyed()))
	if result["damaged"]:
		result["status"] = &"destroyed" if result["destroyed"] else &"damaged"
	else:
		result["status"] = damage_result.get("reason", &"damage_rejected")
	_emit_result(request, result)
	return result


func get_last_sequence(source_entity: Node = null, source_id: int = 0) -> int:
	_prune_invalid_history()
	var key := _source_key(source_entity, source_id)
	return int(_last_sequence_by_source.get(key, -1))


func forget_source(source_entity: Node = null, source_id: int = 0) -> void:
	var key := _source_key(source_entity, source_id)
	if not key.is_empty():
		_remove_source_registration(key)
		_forget_history(key)


func reset_sequence_history() -> void:
	_last_sequence_by_source.clear()
	_history_owner_by_source.clear()


func get_tracked_source_count() -> int:
	_prune_invalid_history()
	return _last_sequence_by_source.size()


func get_registered_source_count() -> int:
	_prune_invalid_sources()
	return _source_registry.size()


func _make_result(request: ShotRequestType) -> Dictionary:
	return {
		"accepted": false,
		"resolved": false,
		"hit": false,
		"damaged": false,
		"destroyed": false,
		"status": &"unresolved",
		"reason": "",
		"request": request,
		"collider": null,
		"damageable": null,
		"target_entity": null,
		"position": Vector3.INF,
		"normal": Vector3.ZERO,
		"distance": 0.0,
		"applied_damage": 0.0,
		"remaining_health": -1.0,
		"last_sequence": -1,
		"source_entity": null,
		"source_id": 0,
		"source_faction_id": &"",
		"target_faction_id": &"",
		"damage_result": {},
	}


func _reject(
	result: Dictionary,
	status: StringName,
	reason: String,
	request: ShotRequestType
	) -> Dictionary:
	result["status"] = status
	result["reason"] = reason
	_emit_result(request, result)
	return result


func _emit_result(request: ShotRequestType, result: Dictionary) -> void:
	shot_resolved.emit(request, result.duplicate(true))


func _resolve_authority_context(request: ShotRequestType) -> Dictionary:
	var source_key := request.get_source_key()
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		if require_registered_sources:
			return {
				"valid": false,
				"status": &"unregistered_source",
				"reason": "source has no authority registration",
			}
		return _trusted_local_context(request, source_key)
	var source_reference: WeakRef = registration.get("entity") as WeakRef
	var source_entity := source_reference.get_ref() as Node3D if source_reference != null else null
	if not is_instance_valid(source_entity):
		_remove_source_registration(source_key)
		return {
			"valid": false,
			"status": &"source_unavailable",
			"reason": "registered source no longer exists",
		}
	if is_instance_valid(request.source_entity) and request.source_entity != source_entity:
		return {
			"valid": false,
			"status": &"source_mismatch",
			"reason": "request entity does not match registered source",
		}
	var authoritative_faction: StringName = registration.get("faction_id", &"")
	if not request.faction_id.is_empty() and request.faction_id != authoritative_faction:
		return {
			"valid": false,
			"status": &"source_mismatch",
			"reason": "request faction does not match registered source",
		}
	var profiles: Dictionary = registration.get("weapons", {})
	var profile: Dictionary = profiles.get(request.weapon_id, {})
	if profile.is_empty():
		return {
			"valid": false,
			"status": &"weapon_not_authorized",
			"reason": "weapon is not registered for source",
		}
	var authoritative_range := float(profile.range)
	var authoritative_damage := float(profile.damage)
	if not is_equal_approx(request.range, authoritative_range) \
		or not is_equal_approx(request.damage, authoritative_damage):
		return {
			"valid": false,
			"status": &"weapon_data_mismatch",
			"reason": "request range or damage differs from authority profile",
		}
	var origin_tolerance := float(profile.origin_tolerance)
	if source_entity.global_position.distance_to(request.origin) > origin_tolerance:
		return {
			"valid": false,
			"status": &"origin_out_of_bounds",
			"reason": "request origin lies outside the registered source envelope",
		}
	return {
		"valid": true,
		"source_key": source_key,
		"source_entity": source_entity,
		"source_id": int(registration.get("source_id", 0)),
		"faction_id": authoritative_faction,
		"range": authoritative_range,
		"damage": authoritative_damage,
	}


func _trusted_local_context(request: ShotRequestType, source_key: String) -> Dictionary:
	if not is_instance_valid(request.source_entity) or not request.source_entity is Node3D:
		return {
			"valid": false,
			"status": &"source_unavailable",
			"reason": "unregistered local request requires a live Node3D source",
		}
	return {
		"valid": true,
		"source_key": source_key,
		"source_entity": request.source_entity,
		"source_id": request.source_id,
		"faction_id": request.faction_id,
		"range": request.range,
		"damage": request.damage,
	}


func _make_authoritative_source_context(
	request: ShotRequestType,
	authority_context: Dictionary
	) -> Dictionary:
	return {
		"source_entity": authority_context.source_entity,
		"source_id": authority_context.source_id,
		"faction_id": authority_context.faction_id,
		"weapon_id": request.weapon_id,
		"sequence": request.sequence,
		"presentation_receipt_id": request.presentation_receipt_id,
	}


func _normalize_weapon_profiles(profiles: Dictionary) -> Dictionary:
	var normalized := {}
	for untyped_weapon_id: Variant in profiles:
		var weapon_id := StringName(untyped_weapon_id)
		var raw_profile: Variant = profiles[untyped_weapon_id]
		if weapon_id.is_empty() or not raw_profile is Dictionary:
			continue
		var profile := raw_profile as Dictionary
		var weapon_range := float(profile.get("range", 0.0))
		var weapon_damage := float(profile.get("damage", 0.0))
		var origin_tolerance := float(profile.get("origin_tolerance", 12.0))
		if not is_finite(weapon_range) or weapon_range <= 0.0 \
			or not is_finite(weapon_damage) or weapon_damage <= 0.0 \
			or not is_finite(origin_tolerance) or origin_tolerance <= 0.0:
			continue
		normalized[weapon_id] = {
			"range": weapon_range,
			"damage": weapon_damage,
			"origin_tolerance": origin_tolerance,
		}
	return normalized


func _on_registered_source_exiting(source_key: String, instance_id: int) -> void:
	var registration: Dictionary = _source_registry.get(source_key, {})
	if int(registration.get("instance_id", 0)) == instance_id:
		var source_reference := registration.get("entity") as WeakRef
		var source_entity := (
			source_reference.get_ref() as Node
			if source_reference != null and is_instance_valid(source_reference.get_ref())
			else null
		)
		# An ordinary remove/re-add streams the same physical source out of the tree.
		# Drop only its live collision registration; the stable source-ID replay
		# ledger must survive so a captured pre-detach request remains stale.
		_remove_source_registration(source_key)
		# Once the physical owner is genuinely queued for deletion, its identity is
		# retired and the replay entry can be reclaimed. A live node removed for
		# streaming retains it until re-registration or explicit `forget_source()`.
		if source_entity == null or source_entity.is_queued_for_deletion():
			_forget_history(source_key)


func _remove_source_registration(source_key: String) -> void:
	var registration: Dictionary = _source_registry.get(source_key, {})
	var instance_id := int(registration.get("instance_id", 0))
	# Godot ObjectIDs are signed and may be negative; zero alone means absent.
	if instance_id != 0 and String(_source_key_by_instance_id.get(instance_id, "")) == source_key:
		_source_key_by_instance_id.erase(instance_id)
	_source_registry.erase(source_key)


func _prune_invalid_sources() -> void:
	for source_key: String in _source_registry.keys():
		var registration: Dictionary = _source_registry[source_key]
		var source_reference: WeakRef = registration.get("entity") as WeakRef
		if source_reference == null or not is_instance_valid(source_reference.get_ref()):
			_remove_source_registration(source_key)


func _remember_history_owner(source_key: String, source_entity: Node, source_id: int) -> void:
	if source_key.is_empty() or not is_instance_valid(source_entity):
		return
	_history_owner_by_source[source_key] = {
		"entity": weakref(source_entity),
		"source_id": source_id,
	}


func _forget_history(source_key: String) -> void:
	_last_sequence_by_source.erase(source_key)
	_history_owner_by_source.erase(source_key)


func _prune_invalid_history() -> void:
	for source_key: String in _history_owner_by_source.keys():
		var owner: Dictionary = _history_owner_by_source[source_key]
		var source_reference: WeakRef = owner.get("entity") as WeakRef
		if source_reference == null or not is_instance_valid(source_reference.get_ref()):
			_forget_history(source_key)


func _collect_source_exclusions(source_entity: Node) -> Array[RID]:
	var exclusions: Array[RID] = []
	if not is_instance_valid(source_entity):
		return exclusions
	_append_collision_rids(source_entity, exclusions)
	var ancestor := source_entity.get_parent()
	while ancestor != null:
		if ancestor is CollisionObject3D:
			_append_unique_rid(exclusions, (ancestor as CollisionObject3D).get_rid())
			break
		ancestor = ancestor.get_parent()
	return exclusions


func _append_collision_rids(node: Node, output: Array[RID]) -> void:
	if node is CollisionObject3D:
		_append_unique_rid(output, (node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_append_collision_rids(child, output)


func _append_unique_rid(output: Array[RID], candidate: RID) -> void:
	if candidate.is_valid() and not output.has(candidate):
		output.append(candidate)


func _find_damageable(collider: Object) -> Damageable:
	if not collider is Node:
		return null
	var candidate := collider as Node
	while candidate != null:
		var component := _damageable_on_node(candidate)
		if component != null:
			return component
		candidate = candidate.get_parent()
	return null


func _damageable_on_node(node: Node) -> Damageable:
	if node is DamageableType:
		return node as Damageable
	for method_name: StringName in [&"get_damageable_component", &"get_damageable"]:
		if node.has_method(method_name) and _method_accepts_no_arguments(node, method_name):
			var provided: Variant = node.call(method_name)
			if provided is DamageableType and is_instance_valid(provided):
				return provided as Damageable
	for metadata_name: StringName in [&"damageable_component", &"damageable"]:
		if node.has_meta(metadata_name):
			var tagged: Variant = node.get_meta(metadata_name)
			if tagged is DamageableType:
				return tagged as Damageable
	for child in node.get_children():
		if child is DamageableType:
			return child as Damageable
	return null


func _method_accepts_no_arguments(node: Node, method_name: StringName) -> bool:
	for method_info: Dictionary in node.get_method_list():
		if StringName(method_info.get("name", &"")) != method_name:
			continue
		var arguments: Array = method_info.get("args", [])
		var defaults: Array = method_info.get("default_args", [])
		return arguments.size() - defaults.size() <= 0
	return false


func _collider_is_world(collider: Object) -> bool:
	return (
		collider is CollisionObject3D
		and ((collider as CollisionObject3D).collision_layer & PhysicsLayerContract.WORLD) != 0
	)


func _same_faction(source_faction: StringName, target_faction: StringName) -> bool:
	return not source_faction.is_empty() and source_faction == target_faction


func _source_key(source_entity: Node, source_id: int) -> String:
	if source_id > 0:
		return "source_id:%d" % source_id
	if is_instance_valid(source_entity):
		return "instance_id:%d" % source_entity.get_instance_id()
	return ""
