class_name CargoTransferAuthority
extends Node

## Session-local authority for typed integer cargo manifests and transfers.
##
## It owns no rewards, activities, ships, berths, UI, persistence, or network
## replication. A caller registers a live entity, receives generation-bearing
## entity/manifest handles, and must present both current handles for every
## transfer. Transfer rejection happens before either manifest quantity mutates;
## the fixed-pair lifecycle seam compensates every attachment it commits if a
## synchronous post-state observer invalidates the pair.

signal manifest_registered(handle: Dictionary)
signal manifest_detached(handle: Dictionary)
signal manifest_reattached(handle: Dictionary)
signal manifest_retired(handle: Dictionary)
signal transfer_committed(receipt: Dictionary)

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_COMMITTED_TRANSFERS := 4096

var _item_definitions: Dictionary = {}
var _records_by_manifest_id: Dictionary = {}
var _manifest_id_by_entity_id: Dictionary = {}
var _manifest_id_by_instance_id: Dictionary = {}
var _entity_generation_cursors: Dictionary = {}
var _manifest_generation_cursors: Dictionary = {}
var _committed_transfer_ids: Dictionary = {}
var _next_receipt_id := 1
var _emitting_commit_signal := false
## A fixed-pair reattach commits both records before notifying observers. Owner
## tree exits triggered synchronously by those observers are retained until both
## post-state signals finish, then applied before the pair result is returned.
var _emitting_pair_reattach_signals := false
var _deferred_pair_owner_exits: Array[int] = []


func _process(_delta: float) -> void:
	_prune_disposed_entities()


func register_item(definition: CargoItemDefinition) -> Dictionary:
	if _mutation_is_guarded():
		return _result(false, &"reentrant_call")
	if definition == null or not definition.is_definition_valid():
		return _result(false, &"invalid_item_definition")
	if _item_definitions.has(definition.item_id):
		return _result(false, &"duplicate_item")
	_item_definitions[definition.item_id] = definition.to_dictionary().duplicate(true)
	return _result(true, &"registered", {"item": definition.to_dictionary()})


func register_entity(
	entity: Node,
	entity_id: StringName,
	manifest_id: StringName,
	capacity: int,
	initial_quantities: Variant = {}
	) -> Dictionary:
	if _mutation_is_guarded():
		return _result(false, &"reentrant_call")
	if not is_instance_valid(entity) or not entity.is_inside_tree():
		return _result(false, &"invalid_entity")
	if not CargoItemDefinition.is_stable_id(entity_id):
		return _result(false, &"invalid_entity_id")
	if not CargoItemDefinition.is_stable_id(manifest_id):
		return _result(false, &"invalid_manifest_id")
	if capacity <= 0 or capacity > CargoManifest.MAX_CAPACITY:
		return _result(false, &"invalid_capacity")
	if _manifest_id_by_entity_id.has(entity_id):
		return _result(false, &"duplicate_entity")
	if _records_by_manifest_id.has(manifest_id):
		return _result(false, &"duplicate_manifest")
	if _manifest_id_by_instance_id.has(entity.get_instance_id()):
		return _result(false, &"duplicate_entity_instance")
	var normalized := _normalize_initial_quantities(initial_quantities, capacity)
	if not bool(normalized.get("accepted", false)):
		return normalized
	var entity_generation := _peek_next_generation(_entity_generation_cursors, entity_id)
	var manifest_generation := _peek_next_generation(_manifest_generation_cursors, manifest_id)
	if entity_generation < 0 or manifest_generation < 0:
		return _result(false, &"generation_exhausted")
	_entity_generation_cursors[entity_id] = entity_generation
	_manifest_generation_cursors[manifest_id] = manifest_generation
	var manifest := CargoManifest.new(
		manifest_id,
		manifest_generation,
		entity_id,
		entity_generation,
		capacity,
		normalized.get("quantities", {}) as Dictionary
	)
	var instance_id := entity.get_instance_id()
	var record := {
		"entity": weakref(entity),
		"instance_id": instance_id,
		"attached": true,
		"manifest": manifest,
	}
	_records_by_manifest_id[manifest_id] = record
	_manifest_id_by_entity_id[entity_id] = manifest_id
	_manifest_id_by_instance_id[instance_id] = manifest_id
	_connect_entity_exit(entity, instance_id)
	var handle := _handle_for(manifest)
	_emit_manifest_signal(manifest_registered, handle)
	return _result(true, &"registered", {
		"handle": handle,
		"manifest": manifest.get_snapshot(_unit_capacities(), true),
	})


func reattach_entity(entity: Node, handle: Dictionary) -> Dictionary:
	if _mutation_is_guarded():
		return _result(false, &"reentrant_call")
	if not is_instance_valid(entity) or not entity.is_inside_tree():
		return _result(false, &"invalid_entity")
	var validation := _validate_handle(handle, false)
	if not bool(validation.get("accepted", false)):
		return validation
	var record := validation.get("record", {}) as Dictionary
	if bool(record.get("attached", false)):
		return _result(false, &"already_attached")
	var reference := record.get("entity") as WeakRef
	if reference == null or reference.get_ref() != entity:
		return _result(false, &"wrong_owner")
	var instance_id := entity.get_instance_id()
	if int(record.get("instance_id", 0)) != instance_id:
		return _result(false, &"wrong_owner")
	record["attached"] = true
	_records_by_manifest_id[StringName(handle.manifest_id)] = record
	_manifest_id_by_instance_id[instance_id] = StringName(handle.manifest_id)
	_connect_entity_exit(entity, instance_id)
	var detached_handle := _handle_for(record.get("manifest") as CargoManifest)
	_emit_manifest_signal(manifest_reattached, detached_handle)
	return _result(true, &"reattached", {"handle": detached_handle})


## Atomically restores the exact two-owner composition used by production cargo.
## Both members are fully preflighted, then every required record/index commit is
## complete before either `manifest_reattached` observer runs. Public mutation
## re-entry is rejected while those signals emit. A synchronous owner tree exit
## is applied after notification; any member newly attached by this call is then
## rolled back so a rejected result never leaves half of the pair committed.
func reattach_entity_pair(
	first_entity: Node,
	first_handle: Dictionary,
	second_entity: Node,
	second_handle: Dictionary
	) -> Dictionary:
	if _mutation_is_guarded():
		return _reattach_pair_result(
			false,
			&"reentrant_call",
			first_entity,
			first_handle,
			second_entity,
			second_handle
		)
	var first := _preflight_reattach_member(first_entity, first_handle, &"first")
	if not bool(first.get("accepted", false)):
		return _reattach_pair_result(
			false,
			StringName(first.get("reason", &"invalid_first_member")),
			first_entity,
			first_handle,
			second_entity,
			second_handle,
			&"first"
		)
	var second := _preflight_reattach_member(second_entity, second_handle, &"second")
	if not bool(second.get("accepted", false)):
		return _reattach_pair_result(
			false,
			StringName(second.get("reason", &"invalid_second_member")),
			first_entity,
			first_handle,
			second_entity,
			second_handle,
			&"second"
		)
	if (
		first.get("manifest_id", &"") == second.get("manifest_id", &"")
		or int(first.get("instance_id", 0)) == int(second.get("instance_id", 0))
	):
		return _reattach_pair_result(
			false,
			&"duplicate_pair_member",
			first_entity,
			first_handle,
			second_entity,
			second_handle
		)

	var members: Array[Dictionary] = [first, second]
	var committed_members: Array[Dictionary] = []
	for member: Dictionary in members:
		if bool(member.get("was_attached", false)):
			continue
		_commit_reattach_member(member)
		committed_members.append(member)
	if committed_members.is_empty():
		return _reattach_pair_result(
			true,
			&"already_attached",
			first_entity,
			first_handle,
			second_entity,
			second_handle
		)

	_deferred_pair_owner_exits.clear()
	_emitting_pair_reattach_signals = true
	_emitting_commit_signal = true
	var invalidated := false
	for member: Dictionary in committed_members:
		manifest_reattached.emit(
			(member.get("handle", {}) as Dictionary).duplicate(true)
		)
		_settle_deferred_pair_owner_exits()
		if not _reattach_pair_is_current(members):
			invalidated = true
			break
	if invalidated:
		var rolled_back_handles: Array[Dictionary] = []
		for member: Dictionary in committed_members:
			var rolled_back := _rollback_reattach_member(member)
			if not rolled_back.is_empty():
				rolled_back_handles.append(rolled_back)
		for handle: Dictionary in rolled_back_handles:
			manifest_detached.emit(handle.duplicate(true))
			_settle_deferred_pair_owner_exits()
	_emitting_commit_signal = false
	_emitting_pair_reattach_signals = false
	_settle_deferred_pair_owner_exits()
	if invalidated:
		return _reattach_pair_result(
			false,
			&"pair_invalidated_during_signal",
			first_entity,
			first_handle,
			second_entity,
			second_handle
		)
	return _reattach_pair_result(
		true,
		&"reattached",
		first_entity,
		first_handle,
		second_entity,
		second_handle
	)


func retire_entity(handle: Dictionary) -> Dictionary:
	if _mutation_is_guarded():
		return _result(false, &"reentrant_call")
	var validation := _validate_handle(handle, false)
	if not bool(validation.get("accepted", false)):
		return validation
	var manifest := validation.get("manifest") as CargoManifest
	var retired_handle := _handle_for(manifest)
	_remove_record(manifest.manifest_id)
	_emit_manifest_signal(manifest_retired, retired_handle)
	return _result(true, &"retired", {"handle": retired_handle})


func transfer(
	transfer_id: StringName,
	source_handle: Dictionary,
	destination_handle: Dictionary,
	item_id: StringName,
	quantity: int
	) -> Dictionary:
	if _mutation_is_guarded():
		return _result(false, &"reentrant_call")
	if not CargoItemDefinition.is_stable_id(transfer_id):
		return _result(false, &"invalid_transfer_id")
	if _committed_transfer_ids.has(transfer_id):
		return _result(false, &"duplicate_transfer")
	if quantity <= 0:
		return _result(false, &"invalid_quantity")
	if quantity > CargoManifest.MAX_QUANTITY:
		return _result(false, &"quantity_overflow")
	if not CargoItemDefinition.is_stable_id(item_id) or not _item_definitions.has(item_id):
		return _result(false, &"unknown_item")
	if _committed_transfer_ids.size() >= MAX_COMMITTED_TRANSFERS:
		return _result(false, &"transfer_ledger_full")
	if _next_receipt_id <= 0 or _next_receipt_id > MAX_SAFE_INTEGER:
		return _result(false, &"receipt_exhausted")
	var source_validation := _validate_handle(source_handle, true)
	if not bool(source_validation.get("accepted", false)):
		return _side_result(source_validation, &"source")
	var destination_validation := _validate_handle(destination_handle, true)
	if not bool(destination_validation.get("accepted", false)):
		return _side_result(destination_validation, &"destination")
	var source := source_validation.get("manifest") as CargoManifest
	var destination := destination_validation.get("manifest") as CargoManifest
	if source.manifest_id == destination.manifest_id:
		return _result(false, &"same_manifest")
	if not source.can_remove(item_id, quantity):
		return _result(false, &"insufficient_quantity")
	var item_definition := _item_definitions[item_id] as Dictionary
	var add_reason := destination.can_add(
		item_id,
		quantity,
		int(item_definition.unit_capacity),
		_unit_capacities()
	)
	if not add_reason.is_empty():
		return _result(false, add_reason)

	# Every possible rejection is above this line. Both manifest writes and the
	# duplicate-transfer ledger commit before observers are notified.
	if not source.commit_remove(item_id, quantity):
		return _result(false, &"commit_invariant_failed")
	if not destination.commit_add(item_id, quantity):
		# This path is unreachable after preflight; fail loudly without exposing a
		# success signal. The bounded single-threaded authority keeps it testable.
		source.commit_add(item_id, quantity)
		return _result(false, &"commit_invariant_failed")
	var receipt_id := _next_receipt_id
	_next_receipt_id += 1
	_committed_transfer_ids[transfer_id] = receipt_id
	var receipt := {
		"accepted": true,
		"reason": &"committed",
		"receipt_id": receipt_id,
		"transfer_id": transfer_id,
		"item_id": item_id,
		"quantity": quantity,
		"source_handle": _handle_for(source),
		"destination_handle": _handle_for(destination),
		"source_quantity_after": source.get_quantity(item_id),
		"destination_quantity_after": destination.get_quantity(item_id),
		"source_used_capacity_after": source.get_used_capacity(_unit_capacities()),
		"destination_used_capacity_after": destination.get_used_capacity(_unit_capacities()),
	}
	_emitting_commit_signal = true
	transfer_committed.emit(receipt.duplicate(true))
	_emitting_commit_signal = false
	return receipt.duplicate(true)


func get_manifest_snapshot(handle: Dictionary) -> Dictionary:
	var validation := _validate_handle(handle, false)
	if not bool(validation.get("accepted", false)):
		return {}
	var manifest := validation.get("manifest") as CargoManifest
	var record := validation.get("record", {}) as Dictionary
	return manifest.get_snapshot(_unit_capacities(), bool(record.get("attached", false))).duplicate(true)


func get_quantity(handle: Dictionary, item_id: StringName) -> int:
	var validation := _validate_handle(handle, false)
	if not bool(validation.get("accepted", false)):
		return -1
	return (validation.get("manifest") as CargoManifest).get_quantity(item_id)


func to_dictionary() -> Dictionary:
	var item_ids: Array[String] = []
	for item_id: StringName in _item_definitions:
		item_ids.append(str(item_id))
	item_ids.sort()
	var items: Array[Dictionary] = []
	for item_text in item_ids:
		items.append((_item_definitions[StringName(item_text)] as Dictionary).duplicate(true))

	var manifest_ids: Array[String] = []
	for manifest_id: StringName in _records_by_manifest_id:
		manifest_ids.append(str(manifest_id))
	manifest_ids.sort()
	var manifests: Array[Dictionary] = []
	for manifest_text in manifest_ids:
		var record := _records_by_manifest_id[StringName(manifest_text)] as Dictionary
		var manifest := record.get("manifest") as CargoManifest
		manifests.append(manifest.get_snapshot(_unit_capacities(), bool(record.get("attached", false))))

	var transfer_ids := PackedStringArray()
	var committed_transfers: Array[Dictionary] = []
	for transfer_id: StringName in _committed_transfer_ids:
		transfer_ids.append(str(transfer_id))
	transfer_ids.sort()
	for transfer_text in transfer_ids:
		committed_transfers.append({
			"transfer_id": StringName(transfer_text),
			"receipt_id": int(_committed_transfer_ids[StringName(transfer_text)]),
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"items": items,
		"manifests": manifests,
		"committed_transfer_ids": transfer_ids,
		"committed_transfers": committed_transfers,
		"entity_generation_cursors": _sorted_generation_cursors(_entity_generation_cursors),
		"manifest_generation_cursors": _sorted_generation_cursors(_manifest_generation_cursors),
		"next_receipt_id": _next_receipt_id,
	}


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var unit_capacities := _unit_capacities()
	for item_id: StringName in _item_definitions:
		var definition := _item_definitions[item_id] as Dictionary
		if not CargoItemDefinition.is_stable_id(item_id) or int(definition.get("unit_capacity", 0)) <= 0:
			errors.append("invalid item definition %s" % item_id)
	for manifest_id: StringName in _records_by_manifest_id:
		var record := _records_by_manifest_id[manifest_id] as Dictionary
		var manifest := record.get("manifest") as CargoManifest
		if manifest == null:
			errors.append("missing manifest object %s" % manifest_id)
			continue
		for error in manifest.get_validation_errors(unit_capacities):
			errors.append("%s: %s" % [manifest_id, error])
		if _manifest_id_by_entity_id.get(manifest.owner_entity_id, &"") != manifest_id:
			errors.append("entity index mismatch for %s" % manifest_id)
		if int(_entity_generation_cursors.get(manifest.owner_entity_id, 0)) != manifest.owner_generation:
			errors.append("entity generation cursor mismatch for %s" % manifest_id)
		if int(_manifest_generation_cursors.get(manifest_id, 0)) != manifest.generation:
			errors.append("manifest generation cursor mismatch for %s" % manifest_id)
		var reference := record.get("entity") as WeakRef
		var entity := reference.get_ref() as Node if reference != null else null
		if entity == null:
			errors.append("owner reference expired for %s" % manifest_id)
		elif bool(record.get("attached", false)):
			if not entity.is_inside_tree():
				errors.append("attached owner is outside tree for %s" % manifest_id)
			if entity.is_queued_for_deletion():
				errors.append("attached owner is queued for deletion for %s" % manifest_id)
			if _manifest_id_by_instance_id.get(entity.get_instance_id(), &"") != manifest_id:
				errors.append("instance index mismatch for %s" % manifest_id)
		elif _manifest_id_by_instance_id.has(int(record.get("instance_id", 0))):
			errors.append("detached owner retains instance index for %s" % manifest_id)
	for raw_instance_id: Variant in _manifest_id_by_instance_id:
		var indexed_manifest_id := StringName(
			_manifest_id_by_instance_id[raw_instance_id]
		)
		var indexed_record := _records_by_manifest_id.get(
			indexed_manifest_id, {}
		) as Dictionary
		if (
			indexed_record.is_empty()
			or not bool(indexed_record.get("attached", false))
			or int(indexed_record.get("instance_id", 0)) != int(raw_instance_id)
		):
			errors.append("orphaned instance index %s" % int(raw_instance_id))
	if _committed_transfer_ids.size() > MAX_COMMITTED_TRANSFERS:
		errors.append("committed transfer ledger exceeds bound")
	errors.sort()
	var serialized := to_dictionary()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"schema_version": SCHEMA_VERSION,
		"registered_item_count": _item_definitions.size(),
		"active_manifest_count": _records_by_manifest_id.size(),
		"committed_transfer_count": _committed_transfer_ids.size(),
		"maximum_committed_transfers": MAX_COMMITTED_TRANSFERS,
		"state": serialized.duplicate(true),
		"reward_authority": false,
		"activity_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"network_authority": false,
		"ui_authority": false,
	}


func _normalize_initial_quantities(initial_quantities: Variant, capacity: int) -> Dictionary:
	if not initial_quantities is Dictionary:
		return _result(false, &"invalid_initial_manifest")
	var normalized: Dictionary = {}
	var used := 0
	for raw_item_id: Variant in initial_quantities as Dictionary:
		if not raw_item_id is String and not raw_item_id is StringName:
			return _result(false, &"invalid_item_id")
		var item_id := StringName(raw_item_id)
		if not CargoItemDefinition.is_stable_id(item_id):
			return _result(false, &"invalid_item_id")
		if normalized.has(item_id):
			return _result(false, &"duplicate_item")
		if not _item_definitions.has(item_id):
			return _result(false, &"unknown_item")
		var raw_quantity: Variant = (initial_quantities as Dictionary)[raw_item_id]
		if not raw_quantity is int or int(raw_quantity) <= 0:
			return _result(false, &"invalid_quantity")
		var quantity := int(raw_quantity)
		if quantity > CargoManifest.MAX_QUANTITY:
			return _result(false, &"quantity_overflow")
		var unit_capacity := int((_item_definitions[item_id] as Dictionary).unit_capacity)
		var remaining := capacity - used
		if quantity > remaining / unit_capacity:
			return _result(false, &"capacity_exceeded")
		normalized[item_id] = quantity
		used += quantity * unit_capacity
	return _result(true, &"valid", {"quantities": normalized})


func _preflight_reattach_member(
	entity: Node,
	handle: Dictionary,
	side: StringName
	) -> Dictionary:
	if (
		not is_instance_valid(entity)
		or not entity.is_inside_tree()
		or entity.is_queued_for_deletion()
	):
		return _result(false, &"invalid_entity", {"side": side})
	var validation := _validate_handle(handle, false)
	if not bool(validation.get("accepted", false)):
		return _side_result(validation, side)
	var record := validation.get("record", {}) as Dictionary
	var reference := record.get("entity") as WeakRef
	if reference == null or reference.get_ref() != entity:
		return _result(false, &"wrong_owner", {"side": side})
	var instance_id := entity.get_instance_id()
	if int(record.get("instance_id", 0)) != instance_id:
		return _result(false, &"wrong_owner", {"side": side})
	var manifest := validation.get("manifest") as CargoManifest
	return _result(true, &"current", {
		"side": side,
		"entity": entity,
		"handle": _handle_for(manifest),
		"instance_id": instance_id,
		"manifest_id": manifest.manifest_id,
		"record": record,
		"was_attached": bool(record.get("attached", false)),
	})


func _commit_reattach_member(member: Dictionary) -> void:
	var manifest_id := StringName(member.get("manifest_id", &""))
	var instance_id := int(member.get("instance_id", 0))
	var entity := member.get("entity") as Node
	var record := (member.get("record", {}) as Dictionary).duplicate()
	record["attached"] = true
	_records_by_manifest_id[manifest_id] = record
	_manifest_id_by_instance_id[instance_id] = manifest_id
	_connect_entity_exit(entity, instance_id)


func _rollback_reattach_member(member: Dictionary) -> Dictionary:
	if bool(member.get("was_attached", false)):
		return {}
	var manifest_id := StringName(member.get("manifest_id", &""))
	var record := _records_by_manifest_id.get(manifest_id, {}) as Dictionary
	if record.is_empty() or not bool(record.get("attached", false)):
		return {}
	record["attached"] = false
	_records_by_manifest_id[manifest_id] = record
	_manifest_id_by_instance_id.erase(int(member.get("instance_id", 0)))
	_disconnect_entity_exit(
		member.get("entity") as Node,
		int(member.get("instance_id", 0))
	)
	return (member.get("handle", {}) as Dictionary).duplicate(true)


func _reattach_pair_is_current(members: Array[Dictionary]) -> bool:
	for member: Dictionary in members:
		var entity := member.get("entity") as Node
		if (
			not is_instance_valid(entity)
			or not entity.is_inside_tree()
			or entity.is_queued_for_deletion()
		):
			return false
		var snapshot := get_manifest_snapshot(
			member.get("handle", {}) as Dictionary
		)
		if snapshot.is_empty() or not bool(snapshot.get("attached", false)):
			return false
	return true


func _reattach_pair_result(
	accepted: bool,
	reason: StringName,
	first_entity: Node,
	first_handle: Dictionary,
	second_entity: Node,
	second_handle: Dictionary,
	side: StringName = &""
	) -> Dictionary:
	var fields := {
		"first": _reattach_member_result(first_entity, first_handle),
		"second": _reattach_member_result(second_entity, second_handle),
	}
	if not side.is_empty():
		fields["side"] = side
	return _result(accepted, reason, fields)


func _reattach_member_result(entity: Node, handle: Dictionary) -> Dictionary:
	var snapshot := get_manifest_snapshot(handle)
	var canonical_handle := _canonical_handle(handle)
	return {
		"handle": canonical_handle,
		"attached": bool(snapshot.get("attached", false)),
		"entity_inside_tree": (
			is_instance_valid(entity)
			and entity.is_inside_tree()
			and not entity.is_queued_for_deletion()
		),
		"manifest": snapshot.duplicate(true),
	}


func _canonical_handle(handle: Dictionary) -> Dictionary:
	var validation := _validate_handle(handle, false)
	if bool(validation.get("accepted", false)):
		return _handle_for(validation.get("manifest") as CargoManifest)
	if (
		handle.has("entity_id")
		and (handle.entity_id is String or handle.entity_id is StringName)
		and handle.has("entity_generation")
		and handle.entity_generation is int
		and handle.has("manifest_id")
		and (handle.manifest_id is String or handle.manifest_id is StringName)
		and handle.has("manifest_generation")
		and handle.manifest_generation is int
	):
		return {
			"entity_id": StringName(handle.entity_id),
			"entity_generation": int(handle.entity_generation),
			"manifest_id": StringName(handle.manifest_id),
			"manifest_generation": int(handle.manifest_generation),
		}
	return {}


func _validate_handle(handle: Dictionary, require_attached: bool) -> Dictionary:
	for field in [&"entity_id", &"entity_generation", &"manifest_id", &"manifest_generation"]:
		if not handle.has(field):
			return _result(false, &"invalid_handle")
	if not handle.entity_id is String and not handle.entity_id is StringName:
		return _result(false, &"invalid_handle")
	if not handle.manifest_id is String and not handle.manifest_id is StringName:
		return _result(false, &"invalid_handle")
	if not handle.entity_generation is int or not handle.manifest_generation is int:
		return _result(false, &"invalid_handle")
	var entity_id := StringName(handle.entity_id)
	var manifest_id := StringName(handle.manifest_id)
	var entity_generation := int(handle.entity_generation)
	var manifest_generation := int(handle.manifest_generation)
	if not CargoItemDefinition.is_stable_id(entity_id) or not CargoItemDefinition.is_stable_id(manifest_id):
		return _result(false, &"invalid_handle")
	var record: Dictionary = _records_by_manifest_id.get(manifest_id, {})
	if record.is_empty():
		if manifest_generation <= int(_manifest_generation_cursors.get(manifest_id, 0)):
			return _result(false, &"stale_manifest")
		return _result(false, &"unknown_manifest")
	var manifest := record.get("manifest") as CargoManifest
	if manifest == null:
		return _result(false, &"invalid_manifest")
	if manifest_generation != manifest.generation:
		return _result(false, &"stale_manifest")
	if entity_id != manifest.owner_entity_id:
		return _result(false, &"wrong_owner")
	if entity_generation != manifest.owner_generation:
		return _result(false, &"stale_entity")
	if require_attached and not bool(record.get("attached", false)):
		return _result(false, &"entity_detached")
	return _result(true, &"current", {"manifest": manifest, "record": record})


func _on_entity_tree_exiting(instance_id: int) -> void:
	if _emitting_pair_reattach_signals:
		if not _deferred_pair_owner_exits.has(instance_id):
			_deferred_pair_owner_exits.append(instance_id)
		return
	_apply_entity_tree_exit(instance_id)


func _settle_deferred_pair_owner_exits() -> void:
	while not _deferred_pair_owner_exits.is_empty():
		var deferred_exits := _deferred_pair_owner_exits.duplicate()
		_deferred_pair_owner_exits.clear()
		for instance_id: int in deferred_exits:
			_apply_entity_tree_exit(instance_id)


func _apply_entity_tree_exit(instance_id: int) -> void:
	var manifest_id := StringName(_manifest_id_by_instance_id.get(instance_id, &""))
	if manifest_id.is_empty():
		return
	var record: Dictionary = _records_by_manifest_id.get(manifest_id, {})
	if record.is_empty():
		return
	var reference := record.get("entity") as WeakRef
	var entity := reference.get_ref() as Node if reference != null else null
	var manifest := record.get("manifest") as CargoManifest
	_manifest_id_by_instance_id.erase(instance_id)
	if entity == null or entity.is_queued_for_deletion():
		var handle := _handle_for(manifest)
		_remove_record(manifest_id)
		_emit_manifest_signal(manifest_retired, handle)
		return
	record["attached"] = false
	_records_by_manifest_id[manifest_id] = record
	_emit_manifest_signal(manifest_detached, _handle_for(manifest))


func _connect_entity_exit(entity: Node, instance_id: int) -> void:
	var callback := _on_entity_tree_exiting.bind(instance_id)
	if not entity.tree_exiting.is_connected(callback):
		entity.tree_exiting.connect(callback, CONNECT_ONE_SHOT)


func _disconnect_entity_exit(entity: Node, instance_id: int) -> void:
	if not is_instance_valid(entity):
		return
	var callback := _on_entity_tree_exiting.bind(instance_id)
	if entity.tree_exiting.is_connected(callback):
		entity.tree_exiting.disconnect(callback)


func _remove_record(manifest_id: StringName) -> void:
	var record: Dictionary = _records_by_manifest_id.get(manifest_id, {})
	if record.is_empty():
		return
	var manifest := record.get("manifest") as CargoManifest
	_records_by_manifest_id.erase(manifest_id)
	if manifest != null:
		_manifest_id_by_entity_id.erase(manifest.owner_entity_id)
	_manifest_id_by_instance_id.erase(int(record.get("instance_id", 0)))


func _peek_next_generation(cursors: Dictionary, stable_id: StringName) -> int:
	var current := int(cursors.get(stable_id, 0))
	if current >= MAX_SAFE_INTEGER:
		return -1
	return current + 1


func _sorted_generation_cursors(cursors: Dictionary) -> Array[Dictionary]:
	var ids: Array[String] = []
	for stable_id: StringName in cursors:
		ids.append(str(stable_id))
	ids.sort()
	var entries: Array[Dictionary] = []
	for id_text in ids:
		entries.append({"id": StringName(id_text), "generation": int(cursors[StringName(id_text)])})
	return entries


func _prune_disposed_entities() -> void:
	for raw_manifest_id: Variant in _records_by_manifest_id.keys():
		var manifest_id := StringName(raw_manifest_id)
		var record := _records_by_manifest_id.get(manifest_id, {}) as Dictionary
		var reference := record.get("entity") as WeakRef
		var entity := reference.get_ref() as Node if reference != null else null
		if entity != null and not entity.is_queued_for_deletion():
			continue
		var manifest := record.get("manifest") as CargoManifest
		var handle := _handle_for(manifest)
		_remove_record(manifest_id)
		_emit_manifest_signal(manifest_retired, handle)


func _unit_capacities() -> Dictionary:
	var result: Dictionary = {}
	for item_id: StringName in _item_definitions:
		result[item_id] = int((_item_definitions[item_id] as Dictionary).unit_capacity)
	return result


func _handle_for(manifest: CargoManifest) -> Dictionary:
	return {
		"entity_id": manifest.owner_entity_id,
		"entity_generation": manifest.owner_generation,
		"manifest_id": manifest.manifest_id,
		"manifest_generation": manifest.generation,
	}


func _side_result(validation: Dictionary, side: StringName) -> Dictionary:
	var result := validation.duplicate(true)
	result["side"] = side
	return result


func _result(accepted: bool, reason: StringName, fields: Dictionary = {}) -> Dictionary:
	var result := fields.duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	return result


func _mutation_is_guarded() -> bool:
	return _emitting_commit_signal or _emitting_pair_reattach_signals


func _emit_manifest_signal(target_signal: Signal, handle: Dictionary) -> void:
	var was_emitting := _emitting_commit_signal
	_emitting_commit_signal = true
	target_signal.emit(handle.duplicate(true))
	_emitting_commit_signal = was_emitting
