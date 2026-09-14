class_name LiveCombatAuthority
extends Node3D

const CombatResolverType := preload("res://scripts/combat/combat_resolver.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const LifecycleAdapterType := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")
const RangeTargetAdapterType := preload("res://scripts/combat/range_target_damageable_adapter.gd")
const MAX_PRESENTATION_RECEIPT_ID: int = 9223372036854775807

signal authoritative_shot_submitted(request: ShotRequestType, result: Dictionary)

@onready var resolver: CombatResolverType = get_node_or_null("Resolver") as CombatResolverType

var _registrations_by_instance: Dictionary = {}
var _next_sequence_by_instance: Dictionary = {}
var _sequence_source_by_instance: Dictionary = {}
var _source_id_by_instance: Dictionary = {}
## Monotonic, session-local deferred-receipt allocator.
## Positive, 64-bit signed IDs are assigned to deferred shots independent of source
## identity and source sequence.
var _next_presentation_receipt_id: int = 1


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
	if is_queued_for_deletion():
		return false
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
	if is_queued_for_deletion():
		return {
			"accepted": false,
			"resolved": false,
			"status": &"authority_unavailable",
			"reason": &"authority_unavailable",
		}.duplicate(true)
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
	var presentation_receipt_id := -1
	if defer_damage_presentation:
		presentation_receipt_id = _allocate_presentation_receipt_id()
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
	if presentation_receipt_id < 0 and defer_damage_presentation:
		var saturation_result := _make_rejected_receipt_result(request, &"receipt_exhausted")
		authoritative_shot_submitted.emit(request, saturation_result.duplicate(true))
		return saturation_result
	var result := resolver.resolve_hitscan(request)
	authoritative_shot_submitted.emit(request, result.duplicate(true))
	return result


func _allocate_presentation_receipt_id() -> int:
	# Use a 64-bit positive signed allocator with fail-closed saturation.
	# Exhaustion is detected one step before integer overflow and ID wrap.
	if _next_presentation_receipt_id <= 0:
		return -1
	if _next_presentation_receipt_id >= MAX_PRESENTATION_RECEIPT_ID:
		_next_presentation_receipt_id = -1
		return -1
	var receipt_id := _next_presentation_receipt_id
	_next_presentation_receipt_id += 1
	return receipt_id


func _make_rejected_receipt_result(request: ShotRequestType, status: StringName) -> Dictionary:
	var result := resolver._make_result(request) if is_instance_valid(resolver) else {
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
		"source_entity": request.source_entity,
		"source_id": request.source_id,
		"source_faction_id": request.faction_id,
		"target_faction_id": &"",
		"damage_result": {},
	}
	result["status"] = status
	result["reason"] = "presentation receipt IDs are saturated"
	return result


## ------------------------------------------------------ projectile flights ----
##
## Travelling weapons reuse the one damage path rather than opening a second.
## `launch_projectile()` proves the source, its registration, its authored travel
## envelope and its muzzle envelope through the same `CombatResolver` that owns
## hitscan, and hands back a detached ticket. The travelling object advances a
## position and nothing else; `resolve_projectile_arrival()` allocates the same
## monotonic replay sequence hitscan uses and commits the shot.
##
## Networking: this is the existing server-owned encounter path. The resolver
## still refuses to resolve anything unless it is the multiplayer authority, so a
## client session never resolves a bolt. No network API is widened and no new
## replicated message exists.


func launch_projectile(
		source_entity: Node3D,
		weapon_id: StringName,
		origin: Vector3,
		direction: Vector3
	) -> Dictionary:
	if is_queued_for_deletion():
		return {
			"accepted": false,
			"status": &"authority_unavailable",
			"reason": "combat authority is being torn down",
			"flight_id": 0,
		}.duplicate(true)
	_ensure_resolver()
	var registration := _get_registration(source_entity)
	if registration.is_empty():
		return {
			"accepted": false,
			"status": &"unregistered_source",
			"reason": "source has no authority registration",
			"flight_id": 0,
		}.duplicate(true)
	return resolver.open_projectile_flight(
		source_entity,
		int(registration.get("source_id", 0)),
		registration.get("faction_id", &""),
		weapon_id,
		origin,
		direction
	)


## Per-step liveness poll. Returns &"live", &"quarantined", or &"unknown_flight".
func observe_projectile(flight_id: int) -> StringName:
	if not is_instance_valid(resolver):
		return &"unknown_flight"
	return resolver.observe_projectile_flight(flight_id)


## Commits one travelling bolt against its terminal segment. This consumes the
## same per-source replay sequence hitscan consumes, so a captured arrival can
## never be replayed, and emits the same authoritative signal.
func resolve_projectile_arrival(
		source_entity: Node3D,
		flight_id: int,
		segment_start: Vector3,
		segment_end: Vector3,
		presentation_receipt_id: int = -1
	) -> Dictionary:
	if not is_instance_valid(resolver):
		return {
			"accepted": false,
			"resolved": false,
			"status": &"authority_unavailable",
			"reason": "combat authority has no resolver",
		}.duplicate(true)
	var snapshot := resolver.get_projectile_flight_snapshot(flight_id)
	if snapshot.is_empty():
		return {
			"accepted": false,
			"resolved": false,
			"status": &"unknown_flight",
			"reason": "projectile flight is not open",
		}.duplicate(true)
	var registration := _get_registration(source_entity)
	var sequence := (
		_next_sequence(source_entity, registration)
		if not registration.is_empty()
		else resolver.get_last_sequence(source_entity, int(snapshot.get("source_id", 0))) + 1
	)
	# `authoritative_shot_submitted` is deliberately NOT raised. That signal is the
	# coordinator's cue to present and voice a shot *it* submitted, and it styles
	# anything that is not the one bound defender in the player's own cyan with the
	# player's fire cue. A travelling bolt is owned, presented and voiced by the
	# craft that launched it, exactly as its hitscan predecessor was; re-raising the
	# signal here would paint an enemy lance cyan and double-commit its receipt.
	# `CombatResolver.shot_resolved` still carries the authoritative record.
	return resolver.close_projectile_flight(
		flight_id, sequence, segment_start, segment_end, presentation_receipt_id
	)


## Drops an open flight without inventing a resolver event. Used when the
## travelling object is torn down with the encounter rather than arriving.
func abandon_projectile(flight_id: int) -> bool:
	# Deliberately does not build a resolver: this is the teardown path, and a
	# torn-down authority has no flight left to retire.
	if not is_instance_valid(resolver):
		return false
	return resolver.abandon_projectile_flight(flight_id)


func get_active_projectile_flight_count() -> int:
	if not is_instance_valid(resolver):
		return 0
	return resolver.get_active_projectile_flight_count()


func attach_lifecycle_damageable(
	target_entity: Node3D,
	lifecycle_kind: int,
	target_faction: StringName
	) -> LifecycleAdapterType:
	if not is_instance_valid(target_entity) or target_entity.is_queued_for_deletion():
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


## Retires a source's live registration without disposing of its identity. The
## replay high-water mark and this authority's next-sequence cursor both survive,
## so a craft that leaves and re-enters play cannot replay a captured request.
func retire_source_registration(source_entity: Node3D = null, source_id: int = 0) -> bool:
	_ensure_resolver()
	var resolved_source_id := source_id
	if is_instance_valid(source_entity):
		var instance_id := source_entity.get_instance_id()
		if resolved_source_id <= 0:
			resolved_source_id = int(_source_id_by_instance.get(instance_id, 0))
		# Only the live registration is dropped. `_next_sequence_by_instance` is
		# deliberately retained for the lifetime of this physical instance.
		_registrations_by_instance.erase(instance_id)
	return resolver.retire_source_registration(source_entity, resolved_source_id)


## Issues one presentation receipt from the shared session-monotonic allocator.
## Callers that resolve on `CombatResolver` directly use this instead of keeping
## a second allocator; saturation still fails closed by returning -1.
func allocate_presentation_receipt_id() -> int:
	return _allocate_presentation_receipt_id()


func get_source_id(source_entity: Node3D) -> int:
	return int(_get_registration(source_entity).get("source_id", 0))


func get_source_faction(source_entity: Node3D) -> StringName:
	return _get_registration(source_entity).get("faction_id", &"")


func get_weapon_profile(source_entity: Node3D, weapon_id: StringName) -> Dictionary:
	var registration := _get_registration(source_entity)
	var profiles: Dictionary = registration.get("weapons", {})
	return (profiles.get(weapon_id, {}) as Dictionary).duplicate(true)


## ------------------------------------------------------------ weapon heat ----
##
## Heat is owned end to end by the one `CombatResolver` this authority already
## wraps. These are reads and a reset hook for the craft that mounts the gun and
## the presentation that draws it; nothing here decides, stores, or replicates a
## single heat value, and no network message is added.


func get_weapon_heat_state(
		source_entity: Node3D,
		weapon_id: StringName = &""
	) -> Dictionary:
	if not is_instance_valid(resolver):
		return {}
	return resolver.get_weapon_heat_snapshot(
		source_entity, get_source_id(source_entity), weapon_id
	)


func is_weapon_heat_locked(
		source_entity: Node3D,
		weapon_id: StringName = &""
	) -> bool:
	return get_weapon_heat_lockout_remaining(source_entity, weapon_id) > 0.0


## Allocation-free per-frame reads used by the firing craft's own presentation.
func get_weapon_heat_ratio(
		source_entity: Node3D,
		weapon_id: StringName = &""
	) -> float:
	if not is_instance_valid(resolver):
		return 0.0
	return resolver.get_weapon_heat_ratio(
		source_entity, get_source_id(source_entity), weapon_id
	)


func get_weapon_heat_lockout_remaining(
		source_entity: Node3D,
		weapon_id: StringName = &""
	) -> float:
	if not is_instance_valid(resolver):
		return 0.0
	return resolver.get_weapon_heat_lockout_remaining(
		source_entity, get_source_id(source_entity), weapon_id
	)


## Vents a source's guns back to cold. Used when a craft is regenerated or
## reactivated on its existing registration, so a new epoch never inherits the
## lockout the previous one earned.
func reset_weapon_heat(source_entity: Node3D) -> bool:
	if not is_instance_valid(resolver):
		return false
	return resolver.reset_weapon_heat(source_entity, get_source_id(source_entity))


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
