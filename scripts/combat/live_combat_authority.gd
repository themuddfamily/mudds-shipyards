class_name LiveCombatAuthority
extends Node3D

const CombatResolverType := preload("res://scripts/combat/combat_resolver.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const LifecycleAdapterType := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")
const RangeTargetAdapterType := preload("res://scripts/combat/range_target_damageable_adapter.gd")

signal authoritative_shot_submitted(request: ShotRequestType, result: Dictionary)

@onready var resolver: CombatResolverType = get_node_or_null("Resolver") as CombatResolverType

var _registrations_by_instance: Dictionary = {}
var _next_sequence_by_instance: Dictionary = {}
var _sequence_source_by_instance: Dictionary = {}
var _source_id_by_instance: Dictionary = {}


func _ready() -> void:
	_ensure_resolver()


func _process(_delta: float) -> void:
	_prune_invalid_sequence_cursors()


func register_source(
	source_entity: Node3D,
	source_id: int,
	faction_id: StringName,
	weapon_profiles: Dictionary
	) -> bool:
	_ensure_resolver()
	if not is_instance_valid(source_entity) or source_id <= 0 or faction_id.is_empty():
		return false
	if not resolver.register_source(source_id, source_entity, faction_id, weapon_profiles):
		return false
	var instance_id := source_entity.get_instance_id()
	_registrations_by_instance[instance_id] = {
		"source": weakref(source_entity),
		"source_id": source_id,
		"faction_id": faction_id,
		"weapons": weapon_profiles.duplicate(true),
	}
	_next_sequence_by_instance[instance_id] = max(
		int(_next_sequence_by_instance.get(instance_id, 0)),
		resolver.get_last_sequence(source_entity, source_id) + 1
	)
	_sequence_source_by_instance[instance_id] = weakref(source_entity)
	_source_id_by_instance[instance_id] = source_id
	if not source_entity.tree_exiting.is_connected(_on_source_exiting):
		source_entity.tree_exiting.connect(_on_source_exiting.bind(instance_id), CONNECT_ONE_SHOT)
	return true


func submit_hitscan(
	source_entity: Node3D,
	weapon_id: StringName,
	origin: Vector3,
	direction: Vector3
	) -> Dictionary:
	return _submit_hitscan(source_entity, weapon_id, origin, direction, false)


## Resolves authority immediately while issuing a stable receipt that lets the
## visual coordinator align target feedback with the travelling pulse endpoint.
func submit_hitscan_with_deferred_presentation(
	source_entity: Node3D,
	weapon_id: StringName,
	origin: Vector3,
	direction: Vector3
	) -> Dictionary:
	return _submit_hitscan(source_entity, weapon_id, origin, direction, true)


func _submit_hitscan(
	source_entity: Node3D,
	weapon_id: StringName,
	origin: Vector3,
	direction: Vector3,
	defer_damage_presentation: bool
	) -> Dictionary:
	_ensure_resolver()
	var registration := _get_registration(source_entity)
	if registration.is_empty():
		var unregistered := ShotRequestType.new(
			source_entity, 0, &"", weapon_id, 0, origin, direction, 1.0, 1.0
		)
		return resolver.resolve_hitscan(unregistered)
	var profiles: Dictionary = registration.get("weapons", {})
	var profile: Dictionary = profiles.get(weapon_id, {})
	if profile.is_empty():
		var unauthorized := ShotRequestType.new(
			source_entity,
			int(registration.get("source_id", 0)),
			registration.get("faction_id", &""),
			weapon_id,
			_next_sequence(source_entity, registration),
			origin,
			direction,
			1.0,
			1.0
		)
		return resolver.resolve_hitscan(unauthorized)
	var sequence := _next_sequence(source_entity, registration)
	var source_id := int(registration.get("source_id", 0))
	var presentation_receipt_id := (
		(source_id << 32) | (sequence & 0xffffffff)
		if defer_damage_presentation
		else -1
	)
	var request := ShotRequestType.new(
		source_entity,
		source_id,
		registration.get("faction_id", &""),
		weapon_id,
		sequence,
		origin,
		direction,
		float(profile.get("range", 0.0)),
		float(profile.get("damage", 0.0)),
		presentation_receipt_id
	)
	var result := resolver.resolve_hitscan(request)
	authoritative_shot_submitted.emit(request, result.duplicate(true))
	return result


func attach_lifecycle_damageable(
	target_entity: Node3D,
	lifecycle_kind: int,
	target_faction: StringName
	) -> LifecycleAdapterType:
	if not is_instance_valid(target_entity):
		return null
	var existing: LifecycleAdapterType = target_entity.get_node_or_null("AuthoritativeDamageable") as LifecycleAdapterType
	if existing != null:
		existing.lifecycle_kind = lifecycle_kind
		existing.faction_id = target_faction
		return existing
	var adapter: LifecycleAdapterType = LifecycleAdapterType.new() as LifecycleAdapterType
	adapter.name = "AuthoritativeDamageable"
	adapter.lifecycle_kind = lifecycle_kind
	adapter.faction_id = target_faction
	adapter.target_entity_path = NodePath("..")
	target_entity.add_child(adapter)
	return adapter


func attach_range_targets(world_owner: Node) -> int:
	if not is_instance_valid(world_owner):
		return 0
	var attached := 0
	for candidate in world_owner.find_children("*", "StaticBody3D", true, false):
		if not candidate.get_meta("is_shipyard_target", false):
			continue
		var existing: RangeTargetAdapterType = candidate.get_node_or_null("AuthoritativeDamageable") as RangeTargetAdapterType
		if existing == null:
			existing = RangeTargetAdapterType.new() as RangeTargetAdapterType
			existing.name = "AuthoritativeDamageable"
			candidate.add_child(existing)
		existing.configure(world_owner)
		attached += 1
	return attached


func get_resolver() -> CombatResolverType:
	_ensure_resolver()
	return resolver


## Explicitly retires a source. Unlike temporary tree removal, this erases its
## live registration, replay high-water mark, and next-sequence cursor.
func forget_source(source_entity: Node3D = null, source_id: int = 0) -> void:
	_ensure_resolver()
	var resolved_source_id := source_id
	if is_instance_valid(source_entity):
		var instance_id := source_entity.get_instance_id()
		if resolved_source_id <= 0:
			resolved_source_id = int(_source_id_by_instance.get(instance_id, 0))
		_erase_sequence_cursor(instance_id)
	elif resolved_source_id > 0:
		for untyped_instance_id: Variant in _source_id_by_instance.keys():
			var instance_id := int(untyped_instance_id)
			if int(_source_id_by_instance.get(instance_id, 0)) == resolved_source_id:
				_erase_sequence_cursor(instance_id)
	resolver.forget_source(source_entity, resolved_source_id)


func get_source_id(source_entity: Node3D) -> int:
	return int(_get_registration(source_entity).get("source_id", 0))


func get_source_faction(source_entity: Node3D) -> StringName:
	return _get_registration(source_entity).get("faction_id", &"")


func get_weapon_profile(source_entity: Node3D, weapon_id: StringName) -> Dictionary:
	var registration := _get_registration(source_entity)
	var profiles: Dictionary = registration.get("weapons", {})
	return (profiles.get(weapon_id, {}) as Dictionary).duplicate(true)


func get_last_submitted_sequence(source_entity: Node3D) -> int:
	if not is_instance_valid(source_entity):
		return -1
	_prune_invalid_sequence_cursors()
	return int(_next_sequence_by_instance.get(source_entity.get_instance_id(), 0)) - 1


func _next_sequence(source_entity: Node3D, registration: Dictionary) -> int:
	var instance_id := source_entity.get_instance_id()
	var source_id := int(registration.get("source_id", 0))
	var sequence := maxi(
		int(_next_sequence_by_instance.get(instance_id, 0)),
		resolver.get_last_sequence(source_entity, source_id) + 1
	)
	_next_sequence_by_instance[instance_id] = sequence + 1
	return sequence


func _get_registration(source_entity: Node3D) -> Dictionary:
	if not is_instance_valid(source_entity):
		return {}
	var instance_id := source_entity.get_instance_id()
	var registration: Dictionary = _registrations_by_instance.get(instance_id, {})
	if registration.is_empty():
		return {}
	var source_reference: WeakRef = registration.get("source") as WeakRef
	if source_reference == null or source_reference.get_ref() != source_entity:
		_erase_sequence_cursor(instance_id)
		return {}
	return registration


func _on_source_exiting(instance_id: int) -> void:
	var registration: Dictionary = _registrations_by_instance.get(instance_id, {})
	var source_reference := registration.get("source") as WeakRef
	var source_entity := (
		source_reference.get_ref() as Node
		if source_reference != null and is_instance_valid(source_reference.get_ref())
		else null
	)
	_registrations_by_instance.erase(instance_id)
	# Preserve the next sequence for the lifetime of this authority and physical
	# source instance. Whole-Main streaming re-adds the same nodes; clearing this
	# cursor would make a captured pre-detach request current again. Explicit source
	# disposal is still owned by the resolver's `forget_source()`/history reset API.
	# A source that is actually queued for deletion has no future physical epoch,
	# so its per-instance cursor can be released immediately.
	if source_entity == null or source_entity.is_queued_for_deletion():
		_erase_sequence_cursor(instance_id)


func _erase_sequence_cursor(instance_id: int) -> void:
	_registrations_by_instance.erase(instance_id)
	_next_sequence_by_instance.erase(instance_id)
	_sequence_source_by_instance.erase(instance_id)
	_source_id_by_instance.erase(instance_id)


func _prune_invalid_sequence_cursors() -> void:
	for untyped_instance_id: Variant in _sequence_source_by_instance.keys():
		var instance_id := int(untyped_instance_id)
		var source_reference: WeakRef = _sequence_source_by_instance.get(instance_id) as WeakRef
		if source_reference == null or not is_instance_valid(source_reference.get_ref()):
			_erase_sequence_cursor(instance_id)


func _ensure_resolver() -> void:
	if is_instance_valid(resolver):
		return
	resolver = CombatResolverType.new() as CombatResolverType
	resolver.name = "Resolver"
	add_child(resolver)
