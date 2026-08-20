class_name StationDefenseEncounterHost
extends Node3D

## Production-facing composition host for StationDefenseActivity.
##
## Callers stage real RangeOpponent instances and supply their stable handles,
## spawn transforms, target wiring, and caller-owned physics delta. This host
## activates those existing instances when the activity publishes them and
## accepts destruction only from the injected CombatResolver's authoritative
## terminal result. Health, damage, collision, weapons, and destruction remain
## on the existing opponent/lifecycle adapter/resolver seams.

signal snapshot_changed(snapshot: Dictionary)

const MAX_SPAWN_ROSTER := StationDefenseContract.MAX_TOTAL_HOSTILES

const _AUTHORITY_EXCLUSIONS := {
	"combat_resolution": false,
	"health": false,
	"damage": false,
	"rewards": false,
	"scene_instantiation": false,
	"protected_asset_lifecycle": false,
	"ships": false,
	"berths": false,
	"world_geometry": false,
	"hud": false,
	"game_flow": false,
	"main": false,
	"save": false,
	"network": false,
}

var _configured := false
var _activity: StationDefenseActivity
var _combat_authority: LiveCombatAuthority
var _resolver: CombatResolver
var _contract_snapshot: Dictionary = {}
var _hostile_specs: Array[Dictionary] = []
var _spec_by_key: Dictionary = {}
var _record_by_key: Dictionary = {}
var _key_by_entity_instance_id: Dictionary = {}
var _mutation_active := false
var _detached_by_tree := false
var _resolver_connected := false
var _pending_failure_reason: StringName = &""
var _last_observation_result: Dictionary = {}


func _enter_tree() -> void:
	if _detached_by_tree and _configured:
		call_deferred("_restore_after_reentry")


func _exit_tree() -> void:
	if not _configured or _activity == null:
		return
	_disconnect_resolver()
	var generation := _activity.get_generation()
	var snapshot := _activity.get_snapshot()
	if bool(snapshot.get("attached", false)):
		_activity.detach(generation)
	_detached_by_tree = true


func configure(
	contract: StationDefenseContract,
	combat_authority: LiveCombatAuthority
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if is_queued_for_deletion():
		return _result(false, &"host_queued_for_deletion")
	if _configured:
		return _result(false, &"already_configured")
	if contract == null or not contract.is_configuration_valid():
		return _result(false, &"invalid_contract")
	if not is_instance_valid(combat_authority):
		return _result(false, &"combat_authority_required")

	_mutation_active = true
	_contract_snapshot = contract.get_snapshot().duplicate(true)
	_activity = StationDefenseActivity.new(contract) as StationDefenseActivity
	_combat_authority = combat_authority
	_resolver = combat_authority.get_resolver() as CombatResolver
	_build_hostile_specs()
	_connect_activity_signals()
	_connect_resolver()
	_configured = true
	_publish_snapshot()
	return _finish_mutation(true, &"configured")


## Registers an already-created production opponent against one exact contract
## handle. The host retains only a weak reference and never instantiates a ship.
func register_hostile(
	hostile_handle: Dictionary,
	entity: RangeOpponent,
	spawn_transform: Transform3D,
	faction_id: StringName
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if is_queued_for_deletion():
		return _result(false, &"host_queued_for_deletion")
	if not _configured:
		return _result(false, &"not_configured")
	if _activity.get_state() != StationDefenseActivity.State.IDLE:
		return _result(false, &"registration_closed")
	if _record_by_key.size() >= MAX_SPAWN_ROSTER:
		return _result(false, &"spawn_roster_limit_reached")
	if not StationDefenseContract._has_exact_keys(
		hostile_handle, ["hostile_id", "generation"]
	):
		return _result(false, &"invalid_hostile_handle")
	var canonical := StationDefenseContract.canonical_hostile_handle(hostile_handle)
	var key := StationDefenseContract.handle_key(canonical, "hostile_id")
	if not _spec_by_key.has(key):
		return _result(false, &"unknown_hostile")
	if _record_by_key.has(key):
		return _result(false, &"duplicate_hostile_registration")
	if not is_instance_valid(entity):
		return _result(false, &"hostile_entity_required")
	if entity.is_active():
		return _result(false, &"hostile_entity_must_be_dormant")
	var instance_id := entity.get_instance_id()
	if _key_by_entity_instance_id.has(instance_id):
		return _result(false, &"duplicate_hostile_entity")
	if not _transform_is_finite_and_nondegenerate(spawn_transform):
		return _result(false, &"invalid_spawn_transform")
	if not StationDefenseContract.is_stable_id(faction_id):
		return _result(false, &"invalid_faction_id")
	var adapter := _combat_authority.attach_lifecycle_damageable(
		entity,
		LifecycleDamageableAdapter.LifecycleKind.RANGE_OPPONENT,
		faction_id
	)
	if not is_instance_valid(adapter):
		return _result(false, &"damage_adapter_unavailable")

	_mutation_active = true
	_record_by_key[key] = {
		"handle": canonical.duplicate(true),
		"entity": weakref(entity),
		"entity_instance_id": instance_id,
		"adapter": weakref(adapter),
		"adapter_instance_id": adapter.get_instance_id(),
		"spawn_transform": spawn_transform,
		"faction_id": faction_id,
		"state_id": &"registered",
		"activation_generation": 0,
	}
	_key_by_entity_instance_id[instance_id] = key
	_publish_snapshot()
	return _finish_mutation(true, &"hostile_registered")


func start(expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	var lifecycle_rejection := _lifecycle_currentness_rejection()
	if not lifecycle_rejection.is_empty():
		return _result(false, lifecycle_rejection)
	var roster_gate := _validate_start_roster()
	if not bool(roster_gate.get("accepted", false)):
		return _result(false, roster_gate.get("reason", &"incomplete_spawn_roster"))
	_mutation_active = true
	_pending_failure_reason = &""
	_connect_resolver()
	var result := _activity.start(expected_generation)
	_apply_pending_failure()
	_publish_snapshot()
	return _finish_mutation(bool(result.accepted), StringName(result.reason))


## Advances only caller-supplied physics time. This host has no process or
## physics-process callback and never reads a wall clock.
func advance_physics(delta: float, expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	var lifecycle_rejection := _lifecycle_currentness_rejection()
	if not lifecycle_rejection.is_empty():
		return _result(false, lifecycle_rejection)
	_mutation_active = true
	_pending_failure_reason = &""
	var result := _activity.advance(delta, expected_generation)
	_apply_pending_failure()
	_publish_snapshot()
	return _finish_mutation(bool(result.accepted), StringName(result.reason))


func protected_asset_damaged(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	return _forward_asset_event(asset_handle, event_handle, expected_generation, false)


func protected_asset_destroyed(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	return _forward_asset_event(asset_handle, event_handle, expected_generation, true)


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	return _forward_terminal(&"fail", expected_generation, reason)


func abort(expected_generation: int) -> Dictionary:
	return _forward_terminal(&"abort", expected_generation)


func reset(expected_generation: int) -> Dictionary:
	return _forward_terminal(&"reset", expected_generation)


## Rebinds only the activity's observed protected handle after a public reset.
## Physical renewal and health remain on the caller-owned protected object.
func renew_protected_asset_handle(
	old_handle: Dictionary,
	new_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	var lifecycle_rejection := _lifecycle_currentness_rejection()
	if not lifecycle_rejection.is_empty():
		return _result(false, lifecycle_rejection)
	_mutation_active = true
	var result := _activity.renew_protected_asset_handle(
		old_handle,
		new_handle,
		expected_generation
	)
	if bool(result.get("accepted", false)):
		var handles := _contract_snapshot.get("protected_asset_handles", []) as Array
		for index in handles.size():
			var retained := handles[index] as Dictionary
			if StationDefenseContract.handle_key(retained, "asset_id") \
				== StationDefenseContract.handle_key(old_handle, "asset_id"):
				handles[index] = StationDefenseContract.canonical_asset_handle(
					new_handle
				).duplicate(true)
				break
		_contract_snapshot["protected_asset_handles"] = handles
	_publish_snapshot()
	return _finish_mutation(
		bool(result.get("accepted", false)),
		StringName(result.get("reason", &"unknown"))
	)


func get_generation() -> int:
	return _activity.get_generation() if _activity != null else 0


func get_combat_authority() -> LiveCombatAuthority:
	return _combat_authority if is_instance_valid(_combat_authority) else null


func get_snapshot() -> Dictionary:
	var activity_snapshot := (
		_activity.get_snapshot()
		if _activity != null
		else {
			"state": StationDefenseActivity.State.IDLE,
			"state_id": "idle",
			"generation": 0,
			"attached": is_inside_tree(),
			"wave_count": 0,
			"remaining_hostile_count": 0,
		}
	)
	var roster: Array[Dictionary] = []
	var active_count := 0
	var destroyed_count := 0
	var retired_count := 0
	for spec in _hostile_specs:
		var key := str(spec.key)
		var record := _record_by_key.get(key, {}) as Dictionary
		var state_id: StringName = record.get("state_id", &"unregistered")
		if state_id == &"active":
			active_count += 1
		elif state_id == &"destroyed":
			destroyed_count += 1
		elif state_id == &"retired":
			retired_count += 1
		var entity := _entity_from_record(record)
		var adapter := _adapter_from_record(record)
		roster.append({
			"hostile_id": spec.hostile_id,
			"handle_generation": spec.handle_generation,
			"wave_id": spec.wave_id,
			"wave_index": spec.wave_index,
			"wave_number": int(spec.wave_index) + 1,
			"wave_order": spec.wave_order,
			"state_id": state_id,
			"registered": not record.is_empty(),
			"entity_available": is_instance_valid(entity),
			"entity_instance_id": int(record.get("entity_instance_id", 0)),
			"damage_adapter_attached": is_instance_valid(adapter),
			"faction_id": record.get("faction_id", &""),
		})
	return {
		"configured": _configured,
		"activity": activity_snapshot,
		"spawn_roster": roster,
		"spawn_roster_count": _record_by_key.size(),
		"required_spawn_roster_count": _hostile_specs.size(),
		"spawn_roster_complete": _record_by_key.size() == _hostile_specs.size(),
		"active_entity_count": active_count,
		"destroyed_entity_count": destroyed_count,
		"retired_entity_count": retired_count,
		"resolver_connected": _resolver_connected,
		"uses_caller_physics_delta": true,
		"destruction_source": &"combat_resolver_terminal_result",
		"last_observation_result": _last_observation_result.duplicate(true),
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("host is not configured")
	if _hostile_specs.size() > MAX_SPAWN_ROSTER:
		errors.append("contract hostile roster exceeds the host bound")
	if _record_by_key.size() > MAX_SPAWN_ROSTER:
		errors.append("registered spawn roster exceeds the host bound")
	if _record_by_key.size() > _hostile_specs.size():
		errors.append("registered spawn roster exceeds the contract")
	if _configured and (not is_instance_valid(_combat_authority) or not is_instance_valid(_resolver)):
		errors.append("combat dependencies are unavailable")
	var entity_ids: Dictionary = {}
	for key: String in _record_by_key:
		if not _spec_by_key.has(key):
			errors.append("registered hostile is outside the contract")
		var record := _record_by_key[key] as Dictionary
		var entity := _entity_from_record(record)
		var adapter := _adapter_from_record(record)
		if not is_instance_valid(entity):
			errors.append("registered hostile entity is unavailable")
		else:
			var instance_id := entity.get_instance_id()
			if entity_ids.has(instance_id):
				errors.append("one entity is registered more than once")
			entity_ids[instance_id] = true
		if not is_instance_valid(adapter) or (
			is_instance_valid(entity) and adapter.get_target_entity() != entity
		):
			errors.append("registered hostile lacks its lifecycle adapter seam")
	if _activity != null:
		var activity_audit := _activity.audit()
		if not bool(activity_audit.valid):
			for error: String in activity_audit.errors:
				errors.append("activity: %s" % error)
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"limits": {
			"maximum_spawn_roster": MAX_SPAWN_ROSTER,
			"maximum_waves": StationDefenseContract.MAX_WAVES,
			"maximum_hostiles_per_wave": StationDefenseContract.MAX_HOSTILES_PER_WAVE,
		},
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
		"snapshot": get_snapshot(),
	}.duplicate(true)


func _forward_asset_event(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int,
	destroyed: bool
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	var lifecycle_rejection := _lifecycle_currentness_rejection()
	if not lifecycle_rejection.is_empty():
		return _result(false, lifecycle_rejection)
	_mutation_active = true
	var result := (
		_activity.protected_asset_destroyed(asset_handle, event_handle, expected_generation)
		if destroyed
		else _activity.protected_asset_damaged(asset_handle, event_handle, expected_generation)
	)
	_publish_snapshot()
	return _finish_mutation(bool(result.accepted), StringName(result.reason))


func _forward_terminal(
	operation: StringName,
	expected_generation: int,
	reason: StringName = &""
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	var lifecycle_rejection := _lifecycle_currentness_rejection()
	if not lifecycle_rejection.is_empty():
		return _result(false, lifecycle_rejection)
	_mutation_active = true
	var result: Dictionary
	match operation:
		&"fail":
			result = _activity.fail(reason, expected_generation)
		&"abort":
			result = _activity.abort(expected_generation)
		&"reset":
			result = _activity.reset(expected_generation)
		_:
			result = {"accepted": false, "reason": &"unknown_operation"}
	_publish_snapshot()
	return _finish_mutation(bool(result.accepted), StringName(result.reason))


func _build_hostile_specs() -> void:
	_hostile_specs.clear()
	_spec_by_key.clear()
	var waves := _contract_snapshot.get("waves", []) as Array
	for wave_index in waves.size():
		var wave := waves[wave_index] as Dictionary
		var handles := wave.get("hostile_handles", []) as Array
		for wave_order in handles.size():
			var handle := handles[wave_order] as Dictionary
			var key := StationDefenseContract.handle_key(handle, "hostile_id")
			var spec := {
				"key": key,
				"hostile_id": handle.get("hostile_id", &""),
				"handle_generation": int(handle.get("generation", 0)),
				"wave_id": wave.get("wave_id", &""),
				"wave_index": wave_index,
				"wave_order": wave_order,
			}
			_hostile_specs.append(spec)
			_spec_by_key[key] = spec


func _connect_activity_signals() -> void:
	_activity.activity_started.connect(_on_activity_changed)
	_activity.wave_started.connect(_on_activity_wave_started)
	_activity.hostile_destruction_accepted.connect(_on_activity_hostile_changed)
	_activity.wave_completed.connect(_on_activity_changed)
	_activity.protected_asset_damage_accepted.connect(_on_activity_asset_changed)
	_activity.protected_asset_destruction_accepted.connect(_on_activity_asset_changed)
	_activity.protected_asset_renewed.connect(_on_activity_asset_renewed)
	_activity.activity_completed.connect(_on_activity_terminal)
	_activity.activity_failed.connect(_on_activity_terminal)
	_activity.activity_aborted.connect(_on_activity_terminal)
	_activity.activity_reset.connect(_on_activity_reset)


func _connect_resolver() -> void:
	if _resolver_connected or not is_instance_valid(_resolver):
		return
	if not _resolver.shot_resolved.is_connected(_on_resolver_shot_resolved):
		_resolver.shot_resolved.connect(_on_resolver_shot_resolved)
	_resolver_connected = true


func _disconnect_resolver() -> void:
	if is_instance_valid(_resolver) and _resolver.shot_resolved.is_connected(
		_on_resolver_shot_resolved
	):
		_resolver.shot_resolved.disconnect(_on_resolver_shot_resolved)
	_resolver_connected = false


func _on_resolver_shot_resolved(_request: ShotRequest, result: Dictionary) -> void:
	if _mutation_active or _activity == null:
		return
	if (
		not bool(result.get("accepted", false))
		or not bool(result.get("resolved", false))
		or not bool(result.get("damaged", false))
		or not bool(result.get("destroyed", false))
	):
		return
	var target: Variant = result.get("target_entity")
	if not is_instance_valid(target) or target is not Node:
		return
	var target_id := (target as Node).get_instance_id()
	var key := str(_key_by_entity_instance_id.get(target_id, ""))
	if key.is_empty() or not _record_by_key.has(key):
		return
	var record := _record_by_key[key] as Dictionary
	if record.get("state_id", &"") != &"active":
		return
	var generation := _activity.get_generation()
	if int(record.get("activation_generation", 0)) != generation:
		return

	_mutation_active = true
	record["state_id"] = &"destroyed"
	var observation := _activity.hostile_destroyed(record.handle, generation)
	_last_observation_result = {
		"accepted": bool(observation.accepted),
		"reason": observation.reason,
		"hostile_id": (record.handle as Dictionary).hostile_id,
		"handle_generation": int((record.handle as Dictionary).generation),
		"activity_generation": generation,
		"resolver_status": result.get("status", &""),
		"source_id": int(result.get("source_id", 0)),
		"sequence": int(result.get("last_sequence", -1)),
	}
	if not bool(observation.accepted):
		record["state_id"] = &"active"
	else:
		_pending_failure_reason = &""
		_synchronize_active_roster()
		_apply_pending_failure()
	_publish_snapshot()
	_mutation_active = false


func _on_activity_changed(_snapshot: Dictionary) -> void:
	_publish_snapshot()


func _on_activity_wave_started(_snapshot: Dictionary) -> void:
	_synchronize_active_roster()
	_publish_snapshot()


func _on_activity_hostile_changed(_snapshot: Dictionary, _handle: Dictionary) -> void:
	_publish_snapshot()


func _on_activity_asset_changed(
	_snapshot: Dictionary,
	_asset_handle: Dictionary,
	_event_handle: Dictionary
	) -> void:
	_publish_snapshot()


func _on_activity_asset_renewed(
	_snapshot: Dictionary,
	_old_handle: Dictionary,
	_new_handle: Dictionary
	) -> void:
	_publish_snapshot()


func _on_activity_terminal(_snapshot: Dictionary) -> void:
	_retire_active_roster()
	_publish_snapshot()


func _on_activity_reset(_snapshot: Dictionary) -> void:
	for key: String in _record_by_key:
		var record := _record_by_key[key] as Dictionary
		var entity := _entity_from_record(record)
		if is_instance_valid(entity) and entity.is_active():
			entity.deactivate()
		record["state_id"] = &"registered"
		record["activation_generation"] = 0
	_last_observation_result.clear()
	_pending_failure_reason = &""
	_publish_snapshot()


func _synchronize_active_roster() -> void:
	if _activity == null:
		return
	var activity_snapshot := _activity.get_snapshot()
	var active_keys: Dictionary = {}
	for handle: Dictionary in activity_snapshot.get("active_hostile_handles", []) as Array:
		active_keys[StationDefenseContract.handle_key(handle, "hostile_id")] = true
	for spec in _hostile_specs:
		var key := str(spec.key)
		if not active_keys.has(key):
			continue
		var record := _record_by_key.get(key, {}) as Dictionary
		if record.is_empty() or record.get("state_id", &"") == &"active":
			continue
		if record.get("state_id", &"") != &"registered":
			_pending_failure_reason = &"hostile_roster_state_invalid"
			continue
		var entity := _entity_from_record(record)
		if not is_instance_valid(entity) or not entity.is_inside_tree():
			_pending_failure_reason = &"hostile_unavailable"
			continue
		record["state_id"] = &"active"
		record["activation_generation"] = _activity.get_generation()
		entity.activate(record.spawn_transform)


func _retire_active_roster() -> void:
	for key: String in _record_by_key:
		var record := _record_by_key[key] as Dictionary
		if record.get("state_id", &"") != &"active":
			continue
		var entity := _entity_from_record(record)
		if is_instance_valid(entity) and entity.is_active():
			entity.deactivate()
		record["state_id"] = &"retired"


func _apply_pending_failure() -> void:
	if _pending_failure_reason.is_empty() or _activity == null:
		return
	var reason := _pending_failure_reason
	_pending_failure_reason = &""
	if _activity.get_state() == StationDefenseActivity.State.ACTIVE:
		_activity.fail(reason, _activity.get_generation())


func _validate_start_roster() -> Dictionary:
	if _record_by_key.size() != _hostile_specs.size():
		return {"accepted": false, "reason": &"incomplete_spawn_roster"}
	for spec in _hostile_specs:
		var record := _record_by_key.get(str(spec.key), {}) as Dictionary
		var entity := _entity_from_record(record)
		var adapter := _adapter_from_record(record)
		if not is_instance_valid(entity) or not entity.is_inside_tree():
			return {"accepted": false, "reason": &"hostile_unavailable"}
		if not is_instance_valid(adapter) or adapter.get_target_entity() != entity:
			return {"accepted": false, "reason": &"damage_adapter_unavailable"}
		if record.get("state_id", &"") != &"registered" or entity.is_active():
			return {"accepted": false, "reason": &"hostile_roster_state_invalid"}
	return {"accepted": true}


func _lifecycle_currentness_rejection() -> StringName:
	if not is_inside_tree():
		return &"host_not_in_tree"
	if is_queued_for_deletion():
		return &"host_queued_for_deletion"
	return &""


func _restore_after_reentry() -> void:
	if (
		not _configured
		or not _detached_by_tree
		or is_queued_for_deletion()
		or not is_inside_tree()
	):
		return
	_mutation_active = true
	var generation := _activity.get_generation()
	var result := _activity.reattach(generation)
	if bool(result.accepted):
		_detached_by_tree = false
		_connect_resolver()
		_pending_failure_reason = &""
		_synchronize_active_roster()
		_apply_pending_failure()
	_publish_snapshot()
	_mutation_active = false


func _entity_from_record(record: Dictionary) -> RangeOpponent:
	var reference := record.get("entity") as WeakRef
	return reference.get_ref() as RangeOpponent if reference != null else null


func _adapter_from_record(record: Dictionary) -> LifecycleDamageableAdapter:
	var reference := record.get("adapter") as WeakRef
	return reference.get_ref() as LifecycleDamageableAdapter if reference != null else null


func _publish_snapshot() -> void:
	snapshot_changed.emit(get_snapshot())


func _finish_mutation(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	return _result(accepted, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


static func _transform_is_finite_and_nondegenerate(value: Transform3D) -> bool:
	return (
		value.origin.is_finite()
		and value.basis.x.is_finite()
		and value.basis.y.is_finite()
		and value.basis.z.is_finite()
		and is_finite(value.basis.determinant())
		and absf(value.basis.determinant()) > 0.000001
	)
