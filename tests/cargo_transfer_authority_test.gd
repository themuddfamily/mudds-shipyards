extends SceneTree

## Focused contract for the pre-activity cargo foundation. The fixture uses only
## cargo APIs and generic Nodes: no ship, berth, reward, activity, UI, save, or
## network system participates.

const AuthorityScript := preload("res://scripts/cargo/cargo_transfer_authority.gd")
const ItemScript := preload("res://scripts/cargo/cargo_item_definition.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_registration_and_atomic_transfer()
	await _test_detach_reentry_and_generation_cleanup()
	await _test_atomic_pair_reattach_signal_adversary()
	_finish()


func _test_registration_and_atomic_transfer() -> void:
	var authority := AuthorityScript.new() as CargoTransferAuthority
	authority.name = "CargoTransferAuthority"
	root.add_child(authority)
	await process_frame

	var ore := _item(&"raw_ore", "Raw ore", 2)
	var cells := _item(&"power_cells", "Power cells", 3)
	_check(bool(authority.register_item(ore).accepted), "a valid stable cargo item registers")
	_check(bool(authority.register_item(cells).accepted), "a second item with a different stable ID registers")
	_check(authority.register_item(ore).reason == &"duplicate_item", "duplicate item IDs are rejected")
	var invalid_item := _item(&"Bad Item", "Bad item", 1)
	_check(authority.register_item(invalid_item).reason == &"invalid_item_definition", "unstable item IDs fail closed")
	ore.unit_capacity = 99
	_check(int((authority.to_dictionary().items as Array)[1].unit_capacity) == 2, "registered item accounting is detached from later Resource edits")

	var source_node := Node.new()
	source_node.name = "SourceEntity"
	root.add_child(source_node)
	var destination_node := Node.new()
	destination_node.name = "DestinationEntity"
	root.add_child(destination_node)
	var source_registration := authority.register_entity(
		source_node, &"source_entity", &"source_hold", 20, {&"raw_ore": 5, &"power_cells": 2}
	)
	var destination_registration := authority.register_entity(
		destination_node, &"destination_entity", &"destination_hold", 7
	)
	_check(bool(source_registration.accepted) and bool(destination_registration.accepted), "two bounded manifests register to distinct live entities")
	var source_handle := (source_registration.handle as Dictionary).duplicate(true)
	var destination_handle := (destination_registration.handle as Dictionary).duplicate(true)
	_check(
		int(source_handle.entity_generation) == 1
		and int(source_handle.manifest_generation) == 1
		and int(destination_handle.entity_generation) == 1,
		"authority allocates generation-one entity and manifest handles"
	)
	_check(
		int(authority.get_manifest_snapshot(source_handle).used_capacity) == 16
		and int(authority.get_manifest_snapshot(source_handle).remaining_capacity) == 4,
		"integer item costs exactly account for used and remaining capacity"
	)

	var spare := Node.new()
	root.add_child(spare)
	_check(
		authority.register_entity(spare, &"source_entity", &"spare_hold", 10).reason == &"duplicate_entity",
		"one live stable entity ID cannot own a duplicate manifest"
	)
	_check(
		authority.register_entity(spare, &"spare_entity", &"source_hold", 10).reason == &"duplicate_manifest",
		"one stable manifest ID cannot be registered twice"
	)
	_check(
		authority.register_entity(spare, &"spare_entity", &"negative_hold", 10, {&"raw_ore": -1}).reason == &"invalid_quantity",
		"negative initial quantities are rejected"
	)
	_check(
		authority.register_entity(spare, &"spare_entity", &"overflow_hold", 10, {&"raw_ore": CargoManifest.MAX_QUANTITY + 1}).reason == &"quantity_overflow",
		"initial quantities above the frozen integer bound are rejected"
	)
	_check(
		authority.register_entity(spare, &"spare_entity", &"overfull_hold", 3, {&"raw_ore": 2}).reason == &"capacity_exceeded",
		"over-capacity initial manifests fail before registration"
	)
	_check(
		authority.register_entity(spare, &"spare_entity", &"unknown_hold", 10, {&"unknown_item": 1}).reason == &"unknown_item",
		"unregistered cargo cannot enter an initial manifest"
	)
	_check(authority.audit().active_manifest_count == 2, "rejected registrations leave no partial manifest state")

	var committed_receipts: Array[Dictionary] = []
	var signal_probe := {"observed_post_commit": false, "reentrant_result": {}}
	authority.transfer_committed.connect(func(receipt: Dictionary) -> void:
		committed_receipts.append(receipt.duplicate(true))
		signal_probe["observed_post_commit"] = (
			authority.get_quantity(source_handle, &"raw_ore") == 2
			and authority.get_quantity(destination_handle, &"raw_ore") == 3
		)
		signal_probe["reentrant_result"] = authority.transfer(
			&"reentrant_attack",
			source_handle,
			destination_handle,
			&"raw_ore",
			1
		)
		(receipt.source_handle as Dictionary)["entity_id"] = &"signal_mutation"
	)
	var first_transfer := authority.transfer(
		&"ore_delivery_001", source_handle, destination_handle, &"raw_ore", 3
	)
	_check(bool(first_transfer.accepted) and int(first_transfer.receipt_id) == 1, "valid source-to-destination transfer commits once")
	_check(
		authority.get_quantity(source_handle, &"raw_ore") == 2
		and authority.get_quantity(destination_handle, &"raw_ore") == 3,
		"one commit conserves quantity across both manifests"
	)
	_check(bool(signal_probe.observed_post_commit), "transfer signal observers see both committed manifest states")
	_check((signal_probe.reentrant_result as Dictionary).reason == &"reentrant_call", "a transfer signal cannot re-enter mutation authority")
	_check(
		StringName((first_transfer.source_handle as Dictionary).entity_id) == &"source_entity",
		"mutating a signal receipt cannot alter the detached caller receipt"
	)
	_check(committed_receipts.size() == 1, "one successful transfer emits exactly one receipt")

	var before_rejections := authority.to_dictionary()
	_check(
		authority.transfer(&"ore_delivery_001", source_handle, destination_handle, &"raw_ore", 1).reason == &"duplicate_transfer",
		"a committed transfer ID cannot replay"
	)
	_check(
		authority.transfer(&"negative_transfer", source_handle, destination_handle, &"raw_ore", -1).reason == &"invalid_quantity",
		"negative transfer quantities are rejected"
	)
	_check(
		authority.transfer(&"zero_transfer", source_handle, destination_handle, &"raw_ore", 0).reason == &"invalid_quantity",
		"zero transfer quantities are rejected"
	)
	_check(
		authority.transfer(&"bounded_overflow", source_handle, destination_handle, &"raw_ore", CargoManifest.MAX_QUANTITY + 1).reason == &"quantity_overflow",
		"transfer quantities above the frozen integer bound are rejected"
	)
	_check(
		authority.transfer(&"unknown_transfer_item", source_handle, destination_handle, &"missing", 1).reason == &"unknown_item",
		"unknown transfer items are rejected"
	)
	_check(
		authority.transfer(&"insufficient_transfer", source_handle, destination_handle, &"raw_ore", 3).reason == &"insufficient_quantity",
		"a source cannot transfer more than it owns"
	)
	_check(
		authority.transfer(&"capacity_transfer", source_handle, destination_handle, &"raw_ore", 1).reason == &"capacity_exceeded",
		"a destination cannot exceed its integer capacity"
	)
	_check(
		authority.transfer(&"same_manifest", source_handle, source_handle, &"raw_ore", 1).reason == &"same_manifest",
		"self-transfer is rejected instead of manufacturing a no-op receipt"
	)
	var wrong_owner := source_handle.duplicate(true)
	wrong_owner["entity_id"] = &"destination_entity"
	_check(
		authority.transfer(&"wrong_owner", wrong_owner, destination_handle, &"raw_ore", 1).reason == &"wrong_owner",
		"a forged source owner is rejected"
	)
	var stale_source := source_handle.duplicate(true)
	stale_source["manifest_generation"] = 0
	var stale_source_result := authority.transfer(&"stale_source", stale_source, destination_handle, &"raw_ore", 1)
	_check(stale_source_result.reason == &"stale_manifest" and stale_source_result.side == &"source", "a stale source manifest generation is rejected explicitly")
	var stale_destination := destination_handle.duplicate(true)
	stale_destination["entity_generation"] = 0
	var stale_destination_result := authority.transfer(&"stale_destination", source_handle, stale_destination, &"raw_ore", 1)
	_check(stale_destination_result.reason == &"stale_entity" and stale_destination_result.side == &"destination", "a stale destination entity generation is rejected explicitly")
	_check(committed_receipts.size() == 1, "all rejected transfers emit no commit signal")
	_check(
		authority.get_quantity(source_handle, &"raw_ore") == 2
		and authority.get_quantity(destination_handle, &"raw_ore") == 3,
		"adversarial transfer rejection leaves both manifests unchanged"
	)
	_check(
		(authority.to_dictionary().committed_transfer_ids as PackedStringArray) == PackedStringArray(["ore_delivery_001"]),
		"only committed IDs enter the bounded duplicate ledger"
	)
	_check(
		(before_rejections.manifests as Array) == (authority.to_dictionary().manifests as Array),
		"the complete serialized manifest state is identical across rejected preflights"
	)

	var serialized := authority.to_dictionary()
	var serialized_again := authority.to_dictionary()
	_check(JSON.stringify(serialized) == JSON.stringify(serialized_again), "serialization is byte-order deterministic across repeated reads")
	_check(
		StringName((serialized.items as Array)[0].item_id) == &"power_cells"
		and StringName((serialized.items as Array)[1].item_id) == &"raw_ore"
		and StringName((serialized.manifests as Array)[0].manifest_id) == &"destination_hold",
		"serialized items and manifests use stable ID ordering"
	)
	((serialized.manifests as Array)[0].entries as Array).clear()
	(serialized.items as Array)[0]["unit_capacity"] = 999
	var untouched := authority.to_dictionary()
	_check(
		not ((untouched.manifests as Array)[0].entries as Array).is_empty()
		and int((untouched.items as Array)[0].unit_capacity) == 3,
		"serialized nested arrays and dictionaries are deep detached"
	)
	var audit := authority.audit()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "authority audit is green after accepted and rejected transfers")
	var audit_copy := audit.duplicate(true)
	((audit_copy.state as Dictionary).manifests as Array).clear()
	_check(
		(authority.audit().state.manifests as Array).size() == 2,
		"audit state is deeply detached from caller mutation"
	)
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(authority.to_dictionary()))
	_check(
		json_round_trip is Dictionary
		and int((json_round_trip as Dictionary).schema_version) == AuthorityScript.SCHEMA_VERSION,
		"serialization contains only deterministic JSON-safe values"
	)
	_check(
		not bool(audit.reward_authority)
		and not bool(audit.activity_authority)
		and not bool(audit.ship_authority)
		and not bool(audit.berth_authority)
		and not bool(audit.network_authority)
		and not bool(audit.ui_authority),
		"audit explicitly denies every deferred integration authority"
	)
	_check(
		int(audit.maximum_committed_transfers) == AuthorityScript.MAX_COMMITTED_TRANSFERS,
		"duplicate history publishes its finite memory bound"
	)

	spare.queue_free()
	authority.queue_free()
	source_node.queue_free()
	destination_node.queue_free()
	await process_frame


func _test_detach_reentry_and_generation_cleanup() -> void:
	var authority := AuthorityScript.new() as CargoTransferAuthority
	root.add_child(authority)
	await process_frame
	authority.register_item(_item(&"sealed_parts", "Sealed parts", 1))
	var source := Node.new()
	var destination := Node.new()
	root.add_child(source)
	root.add_child(destination)
	var first_source := authority.register_entity(source, &"source", &"source_manifest", 8, {&"sealed_parts": 4})
	var first_destination := authority.register_entity(destination, &"destination", &"destination_manifest", 8)
	var source_handle := (first_source.handle as Dictionary).duplicate(true)
	var destination_handle := (first_destination.handle as Dictionary).duplicate(true)

	var lifecycle_probe := {"detached_after_commit": false, "retired_after_commit": false}
	authority.manifest_detached.connect(func(handle: Dictionary) -> void:
		lifecycle_probe["detached_after_commit"] = not bool(authority.get_manifest_snapshot(handle).attached)
	)
	authority.manifest_retired.connect(func(handle: Dictionary) -> void:
		lifecycle_probe["retired_after_commit"] = authority.get_manifest_snapshot(handle).is_empty()
	)
	root.remove_child(source)
	await process_frame
	_check(bool(lifecycle_probe.detached_after_commit), "detach signal observes the already-detached manifest")
	_check(
		authority.get_quantity(source_handle, &"sealed_parts") == 4
		and not bool(authority.get_manifest_snapshot(source_handle).attached),
		"temporary tree detach preserves cargo and marks authority unavailable"
	)
	var detached_transfer := authority.transfer(
		&"detached_transfer", source_handle, destination_handle, &"sealed_parts", 1
	)
	_check(detached_transfer.reason == &"entity_detached" and detached_transfer.side == &"source", "detached source authority rejects transfer without cleanup loss")
	var impostor := Node.new()
	root.add_child(impostor)
	_check(authority.reattach_entity(impostor, source_handle).reason == &"wrong_owner", "a different physical node cannot claim a detached stable identity")
	root.add_child(source)
	_check(bool(authority.reattach_entity(source, source_handle).accepted), "the same physical node and generations reattach")
	_check(
		bool(authority.get_manifest_snapshot(source_handle).attached)
		and authority.get_quantity(source_handle, &"sealed_parts") == 4,
		"re-entry retains the exact manifest generation and quantities"
	)
	_check(
		bool(authority.transfer(&"post_reentry", source_handle, destination_handle, &"sealed_parts", 1).accepted),
		"reattached authority can commit a new transfer"
	)

	_check(bool(authority.retire_entity(source_handle).accepted), "explicit retirement cleans up the source manifest")
	_check(bool(lifecycle_probe.retired_after_commit), "retirement signal observes already-removed state")
	_check(authority.get_manifest_snapshot(source_handle).is_empty(), "retired handles expose no manifest snapshot")
	_check(
		authority.transfer(&"retired_source", source_handle, destination_handle, &"sealed_parts", 1).reason == &"stale_manifest",
		"retired source handles remain generation-stale"
	)
	var second_source := authority.register_entity(source, &"source", &"source_manifest", 8, {&"sealed_parts": 2})
	var second_source_handle := second_source.handle as Dictionary
	_check(
		int(second_source_handle.entity_generation) == 2
		and int(second_source_handle.manifest_generation) == 2,
		"stable IDs re-register only in strictly newer entity and manifest generations"
	)
	_check(
		authority.transfer(&"old_generation_attack", source_handle, destination_handle, &"sealed_parts", 1).reason == &"stale_manifest",
		"a replaced manifest cannot be mutated by its prior generation"
	)

	destination.queue_free()
	await process_frame
	await process_frame
	_check(authority.get_manifest_snapshot(destination_handle).is_empty(), "queued deletion automatically removes owned manifest state")
	_check(authority.audit().active_manifest_count == 1, "queued deletion leaves no orphaned destination registration")
	var replacement_destination := Node.new()
	root.add_child(replacement_destination)
	var second_destination := authority.register_entity(
		replacement_destination, &"destination", &"destination_manifest", 8
	)
	_check(
		int(second_destination.handle.entity_generation) == 2
		and int(second_destination.handle.manifest_generation) == 2,
		"post-cleanup replacement advances both stable generations"
	)
	_check(
		authority.transfer(&"stale_destination_attack", second_source_handle, destination_handle, &"sealed_parts", 1).reason == &"stale_manifest",
		"a deleted destination's captured handle cannot target its replacement"
	)
	var detached_disposal := Node.new()
	root.add_child(detached_disposal)
	var detached_disposal_registration := authority.register_entity(
		detached_disposal, &"detached_disposal", &"detached_disposal_manifest", 2
	)
	root.remove_child(detached_disposal)
	detached_disposal.queue_free()
	await process_frame
	await process_frame
	_check(
		authority.get_manifest_snapshot(detached_disposal_registration.handle as Dictionary).is_empty(),
		"deletion while already detached is pruned without an orphaned manifest"
	)
	_check(bool(authority.audit().valid), "detach, re-entry, retirement and replacement finish with a green audit")

	var queued_reentry_source := Node.new()
	root.add_child(queued_reentry_source)
	var queued_reentry_registration := authority.register_entity(
		queued_reentry_source,
		&"queued_reentry_source",
		&"queued_reentry_source_manifest",
		2
	)
	var queued_reentry_handle := (
		queued_reentry_registration.get("handle", {}) as Dictionary
	).duplicate(true)
	root.remove_child(queued_reentry_source)
	await process_frame
	var queued_reentry_signals := 0
	authority.manifest_reattached.connect(
		func(_handle: Dictionary) -> void:
			queued_reentry_signals += 1
	)
	root.add_child(queued_reentry_source)
	queued_reentry_source.queue_free()
	var queued_reentry := authority.reattach_entity(
		queued_reentry_source,
		queued_reentry_handle
	)
	_check(
		not bool(queued_reentry.get("accepted", true))
		and queued_reentry.get("reason", &"") == &"invalid_entity"
		and queued_reentry_signals == 0
		and bool(authority.audit().get("valid", false))
		and not bool(
			(authority.get_manifest_snapshot(queued_reentry_handle) as Dictionary).get(
				"attached",
				true
			)
		),
		"queued direct re-entry rejects before attachment, index restoration, or reattached publication"
	)
	await process_frame
	_check(
		authority.get_manifest_snapshot(queued_reentry_handle).is_empty(),
		"queued direct re-entry leaves the detached owner for ordinary retirement cleanup"
	)

	impostor.queue_free()
	source.queue_free()
	replacement_destination.queue_free()
	authority.queue_free()
	await process_frame


func _test_atomic_pair_reattach_signal_adversary() -> void:
	await _test_pair_idempotence_and_one_attached_modes()
	await _test_pair_second_preflight_and_queued_owner_rejection()
	await _test_pair_owner_removal_case(&"first", &"first")
	await _test_pair_owner_removal_case(&"first", &"second")
	await _test_pair_owner_removal_case(&"second", &"first")
	await _test_pair_owner_removal_case(&"second", &"second")
	await _test_pair_owner_removal_case(&"first", &"second", true)


func _test_pair_idempotence_and_one_attached_modes() -> void:
	var fixture := await _create_pair_fixture()
	var authority := fixture.authority as CargoTransferAuthority
	var source := fixture.source as Node
	var destination := fixture.destination as Node
	var source_handle := (fixture.source_handle as Dictionary).duplicate(true)
	var destination_handle := (fixture.destination_handle as Dictionary).duplicate(true)
	var events: Array[StringName] = []
	authority.manifest_reattached.connect(
		func(handle: Dictionary) -> void:
			events.append(StringName("reattached:%s" % handle.manifest_id))
	)
	# Extra caller values are tolerated as input but never reflected back through
	# the detached four-field result handle.
	source_handle["unsafe_node"] = source
	source_handle["unsafe_resource"] = Resource.new()
	source_handle["unsafe_callable"] = func() -> void:
		pass
	var idempotent := authority.reattach_entity_pair(
		source, source_handle, destination, destination_handle
	)
	_check(
		bool(idempotent.get("accepted", false))
		and idempotent.get("reason", &"") == &"already_attached"
		and events.is_empty()
		and _is_canonical_handle((idempotent.first as Dictionary).handle)
		and _is_canonical_handle((idempotent.second as Dictionary).handle)
		and not _contains_live_reference(idempotent),
		"both-attached pair restore is signal-free idempotence with canonical primitive handles"
	)
	source_handle["entity_id"] = &"input_mutation"
	var detached_result := idempotent.duplicate(true)
	(detached_result.first as Dictionary).handle["entity_id"] = &"consumer_mutation"
	((detached_result.first as Dictionary).manifest.entries as Array).clear()
	_check(
		authority.get_manifest_snapshot(fixture.source_handle).get("owner_entity_id", &"")
		== &"pair_source"
		and not (authority.get_manifest_snapshot(fixture.source_handle).entries as Array).is_empty()
		and (idempotent.first as Dictionary).handle.entity_id == &"pair_source",
		"pair results are deeply detached from caller mutation and contain no live-reference extras"
	)

	root.remove_child(source)
	await process_frame
	root.add_child(source)
	events.clear()
	var first_only := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	_check(
		bool(first_only.get("accepted", false))
		and events == [&"reattached:pair_source_manifest"]
		and bool(authority.get_manifest_snapshot(fixture.destination_handle).attached),
		"detached-first plus attached-second commits only the first member"
	)
	root.remove_child(destination)
	await process_frame
	root.add_child(destination)
	events.clear()
	var second_only := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	_check(
		bool(second_only.get("accepted", false))
		and events == [&"reattached:pair_destination_manifest"]
		and bool(authority.get_manifest_snapshot(fixture.source_handle).attached),
		"attached-first plus detached-second commits only the second member"
	)
	events.clear()
	var repeated := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	_check(
		bool(repeated.get("accepted", false))
		and repeated.get("reason", &"") == &"already_attached"
		and events.is_empty()
		and source.tree_exiting.get_connections().size() == 1
		and destination.tree_exiting.get_connections().size() == 1,
		"repeated pair restore adds no success signals or owner-exit connections"
	)
	await _cleanup_pair_fixture(fixture)


func _test_pair_second_preflight_and_queued_owner_rejection() -> void:
	var fixture := await _create_pair_fixture()
	var authority := fixture.authority as CargoTransferAuthority
	var source := fixture.source as Node
	var destination := fixture.destination as Node
	root.remove_child(source)
	root.remove_child(destination)
	await process_frame
	root.add_child(source)
	var signal_count := {"value": 0}
	authority.manifest_reattached.connect(
		func(_handle: Dictionary) -> void:
			signal_count["value"] = int(signal_count.value) + 1
	)
	var rejected_second := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	_check(
		not bool(rejected_second.get("accepted", true))
		and rejected_second.get("side", &"") == &"second"
		and rejected_second.get("reason", &"") == &"invalid_entity"
		and int(signal_count.value) == 0
		and not bool(authority.get_manifest_snapshot(fixture.source_handle).attached)
		and source.tree_exiting.get_connections().is_empty(),
		"second-member preflight rejection changes neither member, signal, index, nor connection"
	)
	root.add_child(destination)
	destination.queue_free()
	var rejected_queued := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	_check(
		not bool(rejected_queued.get("accepted", true))
		and rejected_queued.get("side", &"") == &"second"
		and rejected_queued.get("reason", &"") == &"invalid_entity"
		and int(signal_count.value) == 0
		and not bool(authority.get_manifest_snapshot(fixture.source_handle).attached),
		"a queued-for-deletion second owner is rejected during preflight without a first-member commit"
	)
	await process_frame
	source.queue_free()
	authority.queue_free()
	await process_frame


func _test_pair_owner_removal_case(
	trigger_side: StringName,
	removed_side: StringName,
	queue_removal: bool = false
	) -> void:
	var fixture := await _create_pair_fixture()
	var authority := fixture.authority as CargoTransferAuthority
	var source := fixture.source as Node
	var destination := fixture.destination as Node
	root.remove_child(source)
	root.remove_child(destination)
	await process_frame
	root.add_child(source)
	root.add_child(destination)
	var events: Array[StringName] = []
	var detach_reentry_batches: Array = []
	var observer := {"triggered": false, "both_committed": false, "reentrant": {}}
	var trigger_manifest := (
		&"pair_source_manifest"
		if trigger_side == &"first"
		else &"pair_destination_manifest"
	)
	authority.manifest_reattached.connect(
		func(handle: Dictionary) -> void:
			events.append(StringName("reattached:%s" % handle.manifest_id))
			if bool(observer.triggered) or handle.manifest_id != trigger_manifest:
				return
			observer["triggered"] = true
			observer["both_committed"] = (
				bool(authority.get_manifest_snapshot(fixture.source_handle).attached)
				and bool(authority.get_manifest_snapshot(fixture.destination_handle).attached)
			)
			observer["reentrant"] = authority.retire_entity(fixture.source_handle)
			var removed := source if removed_side == &"first" else destination
			if queue_removal:
				removed.queue_free()
			else:
				root.remove_child(removed)
	)
	authority.manifest_detached.connect(
		func(handle: Dictionary) -> void:
			events.append(StringName("detached:%s" % handle.manifest_id))
			detach_reentry_batches.append(
				_attempt_all_public_mutations_during_detach(
					authority, source, destination, fixture, events
				)
			)
	)
	var attacked := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	var expected := _expected_pair_removal_events(
		trigger_side, removed_side, queue_removal
	)
	_check(
		not bool(attacked.get("accepted", true))
		and attacked.get("reason", &"") == &"pair_invalidated_during_signal"
		and bool(observer.triggered)
		and bool(observer.both_committed)
		and (observer.reentrant as Dictionary).get("reason", &"") == &"reentrant_call"
		and events == expected
		and detach_reentry_batches.size() == 2
		and _all_mutation_attempts_are_reentrant(detach_reentry_batches),
		"%s callback %s-removing %s owner has exact stop-and-compensate chronology"
		% ["queued" if queue_removal else "synchronous", trigger_side, removed_side]
	)
	_check(
		not bool(authority.get_manifest_snapshot(fixture.source_handle).attached)
		and not bool(authority.get_manifest_snapshot(fixture.destination_handle).attached)
		and not bool((attacked.first as Dictionary).attached)
		and not bool((attacked.second as Dictionary).attached)
		and _is_canonical_handle((attacked.first as Dictionary).handle)
		and _is_canonical_handle((attacked.second as Dictionary).handle),
		"observer invalidation returns one exact all-detached primitive pair"
	)
	_check(
		bool(authority.audit().valid)
		and source.tree_exiting.get_connections().is_empty()
		and destination.tree_exiting.get_connections().is_empty(),
		"observer invalidation leaks no attached index or owner-exit connection"
	)
	if queue_removal:
		await process_frame
		source.queue_free()
		authority.queue_free()
		await process_frame
		return
	var removed := source if removed_side == &"first" else destination
	root.add_child(removed)
	events.clear()
	var retried := authority.reattach_entity_pair(
		source, fixture.source_handle, destination, fixture.destination_handle
	)
	_check(
		bool(retried.get("accepted", false))
		and bool((retried.first as Dictionary).attached)
		and bool((retried.second as Dictionary).attached)
		and source.tree_exiting.get_connections().size() == 1
		and destination.tree_exiting.get_connections().size() == 1,
		"the compensated pair retries with exactly one lifecycle connection per owner"
	)
	await _cleanup_pair_fixture(fixture)


func _expected_pair_removal_events(
	trigger_side: StringName,
	removed_side: StringName,
	queue_removal: bool
	) -> Array[StringName]:
	if queue_removal:
		return _with_detach_reentry_events([
			&"reattached:pair_source_manifest",
			&"detached:pair_source_manifest",
			&"detached:pair_destination_manifest",
		])
	var first_success := &"reattached:pair_source_manifest"
	var second_success := &"reattached:pair_destination_manifest"
	var removed_detach := (
		&"detached:pair_source_manifest"
		if removed_side == &"first"
		else &"detached:pair_destination_manifest"
	)
	var compensated_detach := (
		&"detached:pair_destination_manifest"
		if removed_side == &"first"
		else &"detached:pair_source_manifest"
	)
	if trigger_side == &"first":
		return _with_detach_reentry_events(
			[first_success, removed_detach, compensated_detach]
		)
	return _with_detach_reentry_events(
		[first_success, second_success, removed_detach, compensated_detach]
	)


func _attempt_all_public_mutations_during_detach(
	authority: CargoTransferAuthority,
	source: Node,
	destination: Node,
	fixture: Dictionary,
	events: Array[StringName]
	) -> Array[Dictionary]:
	var names: Array[StringName] = [
		&"register_item",
		&"register_entity",
		&"reattach_entity",
		&"reattach_entity_pair",
		&"retire_entity",
		&"transfer",
	]
	var attempts: Array[Dictionary] = [
		authority.register_item(_item(&"reentry_probe", "Reentry probe", 1)),
		authority.register_entity(
			source, &"reentry_probe", &"reentry_probe_manifest", 1
		),
		authority.reattach_entity(
			source, fixture.source_handle as Dictionary
		),
		authority.reattach_entity_pair(
			source,
			fixture.source_handle as Dictionary,
			destination,
			fixture.destination_handle as Dictionary
		),
		authority.retire_entity(fixture.source_handle as Dictionary),
		authority.transfer(
			&"reentry_probe_transfer",
			fixture.source_handle as Dictionary,
			fixture.destination_handle as Dictionary,
			&"machine_parts",
			1
		),
	]
	for index in attempts.size():
		events.append(StringName(
			"reentry:%s:%s" % [names[index], attempts[index].get("reason", &"")]
		))
	return attempts


func _all_mutation_attempts_are_reentrant(batches: Array) -> bool:
	for batch_value: Variant in batches:
		if not batch_value is Array:
			return false
		var batch := batch_value as Array
		if batch.size() != 6:
			return false
		for result_value: Variant in batch:
			if not result_value is Dictionary:
				return false
			if (result_value as Dictionary).get("reason", &"") != &"reentrant_call":
				return false
	return true


func _with_detach_reentry_events(
	lifecycle_events: Array[StringName]
	) -> Array[StringName]:
	var expected: Array[StringName] = []
	var mutation_names: Array[StringName] = [
		&"register_item",
		&"register_entity",
		&"reattach_entity",
		&"reattach_entity_pair",
		&"retire_entity",
		&"transfer",
	]
	for event: StringName in lifecycle_events:
		expected.append(event)
		if not str(event).begins_with("detached:"):
			continue
		for mutation_name: StringName in mutation_names:
			expected.append(StringName(
				"reentry:%s:reentrant_call" % mutation_name
			))
	return expected


func _create_pair_fixture() -> Dictionary:
	var authority := AuthorityScript.new() as CargoTransferAuthority
	root.add_child(authority)
	await process_frame
	authority.register_item(_item(&"machine_parts", "Machine parts", 1))
	var source := Node.new()
	var destination := Node.new()
	root.add_child(source)
	root.add_child(destination)
	var source_registration := authority.register_entity(
		source, &"pair_source", &"pair_source_manifest", 8, {&"machine_parts": 4}
	)
	var destination_registration := authority.register_entity(
		destination, &"pair_destination", &"pair_destination_manifest", 8
	)
	return {
		"authority": authority,
		"source": source,
		"destination": destination,
		"source_handle": (source_registration.handle as Dictionary).duplicate(true),
		"destination_handle": (
			destination_registration.handle as Dictionary
		).duplicate(true),
	}


func _cleanup_pair_fixture(fixture: Dictionary) -> void:
	var source := fixture.source as Node
	var destination := fixture.destination as Node
	var authority := fixture.authority as CargoTransferAuthority
	if is_instance_valid(source):
		source.queue_free()
	if is_instance_valid(destination):
		destination.queue_free()
	authority.queue_free()
	await process_frame


func _is_canonical_handle(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var handle := value as Dictionary
	return (
		handle.size() == 4
		and handle.get("entity_id") is StringName
		and handle.get("entity_generation") is int
		and handle.get("manifest_id") is StringName
		and handle.get("manifest_generation") is int
	)


func _contains_live_reference(value: Variant) -> bool:
	if value is Object or value is Callable:
		return true
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			if _contains_live_reference(key):
				return true
			if _contains_live_reference((value as Dictionary)[key]):
				return true
	elif value is Array:
		for entry: Variant in value as Array:
			if _contains_live_reference(entry):
				return true
	return false


func _item(item_id: StringName, display_name: String, unit_capacity: int) -> CargoItemDefinition:
	var definition := ItemScript.new() as CargoItemDefinition
	definition.item_id = item_id
	definition.display_name = display_name
	definition.unit_capacity = unit_capacity
	return definition


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CARGO_TRANSFER_AUTHORITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CARGO_TRANSFER_AUTHORITY_TEST_OK")
		quit(0)
	else:
		print("CARGO_TRANSFER_AUTHORITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
