extends SceneTree

## Adversarial focused contract for the typed delivery foundation. Every cargo
## mutation below goes through the real CargoTransferAuthority.

const AuthorityScript := preload("res://scripts/cargo/cargo_transfer_authority.gd")
const ItemScript := preload("res://scripts/cargo/cargo_item_definition.gd")
const ContractScript := preload("res://scripts/cargo/cargo_delivery_contract.gd")
const ActivityScript := preload("res://scripts/cargo/cargo_delivery_activity.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_exact_delivery_lifecycle()
	await _test_receipt_mismatch_and_failed_transfer_rejection()
	await _test_stale_detached_and_spoofed_evidence()
	await _test_signal_reentry_and_detached_snapshots()
	await _test_contract_validation()
	_finish()


func _test_exact_delivery_lifecycle() -> void:
	var fixture := await _fixture({&"sealed_parts": 9}, {&"sealed_parts": 1})
	var phases: Array[StringName] = [&"collect", &"transit", &"unload"]
	var source_input := (fixture.source_handle as Dictionary).duplicate(true)
	var contract := ContractScript.new(
		&"freight_run",
		source_input,
		fixture.destination_handle,
		&"sealed_parts",
		4,
		phases,
		10.0
	) as CargoDeliveryContract
	source_input["entity_id"] = &"mutated_input"
	phases[0] = &"mutated_phase"
	var contract_snapshot := contract.get_snapshot()
	(contract_snapshot.source_handle as Dictionary)["entity_id"] = &"mutated_snapshot"
	(contract_snapshot.ordered_phases as Array)[0] = &"mutated_snapshot_phase"
	_check(
		contract.is_configuration_valid()
		and StringName(contract.get_source_handle().entity_id) == &"source"
		and contract.get_ordered_phases()[0] == &"collect",
		"contract construction and snapshots deeply detach bound handles and ordered phases"
	)

	var activity := ActivityScript.new(fixture.authority, contract) as CargoDeliveryActivity
	var chronology := PackedStringArray()
	var completion_probe := {"count": 0, "snapshot": {}, "receipt": {}}
	activity.started.connect(func(snapshot: Dictionary) -> void:
		chronology.append("started:%d" % int(snapshot.generation))
	)
	activity.phase_advanced.connect(func(snapshot: Dictionary) -> void:
		chronology.append("phase:%d:%d" % [int(snapshot.generation), int(snapshot.next_phase_index)])
	)
	activity.completed.connect(func(snapshot: Dictionary, receipt: Dictionary) -> void:
		chronology.append("completed:%d:%d" % [int(snapshot.generation), int(receipt.receipt_id)])
		completion_probe.count = int(completion_probe.count) + 1
		completion_probe.snapshot = snapshot.duplicate(true)
		completion_probe.receipt = receipt.duplicate(true)
		snapshot["state"] = -99
		receipt["item_id"] = &"observer_mutation"
	)
	activity.activity_reset.connect(func(snapshot: Dictionary) -> void:
		chronology.append("reset:%d" % int(snapshot.generation))
	)

	var started := activity.start(0)
	var generation := int(started.generation)
	_check(
		started.accepted
		and generation == 1
		and started.expected_transfer_id == &"freight_run_g1"
		and int(started.state) == ActivityScript.State.ACTIVE,
		"generation one starts with one deterministic authority transfer ID"
	)
	var colliding_activity := ActivityScript.new(
		fixture.authority,
		contract
	) as CargoDeliveryActivity
	_check(
		colliding_activity.start(0).reason == &"transfer_id_reserved"
		and colliding_activity.get_generation() == 0
		and colliding_activity.reset(0).reason == &"already_idle",
		"a second activity cannot reserve or skip past the same authority transfer ID"
	)
	_check(
		activity.start(0).reason == &"stale_generation"
		and activity.start(generation).reason == &"already_active",
		"stale and duplicate starts cannot replace an active delivery"
	)
	var before_process_frames := activity.get_snapshot()
	await process_frame
	await process_frame
	_check(activity.get_snapshot() == before_process_frames, "render/process frames cannot age the physics deadline")
	_check(
		activity.advance_physics(0.0, generation).reason == &"no_delta"
		and activity.advance_physics(2.5, generation).accepted
		and is_equal_approx(float(activity.get_snapshot().deadline_remaining_seconds), 7.5),
		"only accepted caller physics delta advances the delivery deadline"
	)
	_check(
		activity.submit_phase(&"transit", generation).reason == &"out_of_order"
		and activity.submit_transfer(generation).reason == &"phases_incomplete",
		"ordered phases must complete before cargo can be submitted"
	)
	_check(activity.submit_phase(&"collect", generation).accepted, "the first ordered phase advances")
	_check(
		activity.submit_phase(&"collect", generation).reason == &"duplicate_phase"
		and activity.submit_phase(&"missing", generation).reason == &"unknown_phase",
		"duplicate and unknown phases are rejected without progress"
	)
	_check(activity.submit_phase(&"transit", generation).accepted, "the second ordered phase advances")
	_check(activity.submit_phase(&"unload", generation).accepted, "the final ordered phase advances")

	var delivered := activity.submit_transfer(generation)
	var authority := fixture.authority as CargoTransferAuthority
	_check(
		delivered.accepted
		and delivered.reason == &"delivered"
		and int(delivered.state) == ActivityScript.State.COMPLETED
		and int((delivered.receipt as Dictionary).receipt_id) == 1,
		"only the exact real authority receipt completes the delivery"
	)
	_check(
		authority.get_quantity(contract.get_source_handle(), &"sealed_parts") == 5
		and authority.get_quantity(contract.get_destination_handle(), &"sealed_parts") == 5,
		"completion reflects the authority's conserved source-to-destination mutation"
	)
	_check(
		int(completion_probe.count) == 1
		and StringName(activity.get_snapshot().accepted_receipt.item_id) == &"sealed_parts"
		and int(activity.get_snapshot().state) == ActivityScript.State.COMPLETED,
		"observer mutation cannot alter retained completion state or receipt"
	)
	var replay := authority.transfer(
		&"freight_run_g1",
		contract.get_source_handle(),
		contract.get_destination_handle(),
		&"sealed_parts",
		4
	)
	_check(
		replay.reason == &"duplicate_transfer"
		and int(completion_probe.count) == 1
		and activity.submit_transfer(generation).reason == &"not_active"
		and activity.start(generation).reason == &"reset_required",
		"transfer replay cannot mutate manifests or complete twice"
	)

	var reset := activity.reset(generation)
	_check(
		reset.accepted
		and int(reset.generation) == 2
		and int(reset.state) == ActivityScript.State.IDLE
		and authority.get_quantity(contract.get_destination_handle(), &"sealed_parts") == 5,
		"reset advances activity generation without rolling back authority cargo"
	)
	_check(
		activity.reset(generation).reason == &"stale_generation"
		and activity.fail(&"old_callback", generation).reason == &"stale_generation",
		"retired generation callbacks cannot mutate reset state"
	)
	var restarted := activity.start(2)
	_check(
		restarted.accepted
		and int(restarted.generation) == 3
		and restarted.expected_transfer_id == &"freight_run_g3",
		"post-reset start allocates a fresh non-replayable transfer ID"
	)
	(fixture.authority as CargoTransferAuthority).transfer_committed.emit(
		(completion_probe.receipt as Dictionary).duplicate(true)
	)
	_check(
		int(activity.get_snapshot().state) == ActivityScript.State.ACTIVE
		and activity.get_snapshot().accepted_receipt.is_empty(),
		"a late receipt from the prior generation is ignored"
	)
	_check(activity.fail(&"caller_abort", 3).accepted, "a current generation can fail explicitly once")
	_check(
		chronology == PackedStringArray([
			"started:1", "phase:1:1", "phase:1:2", "phase:1:3",
			"completed:1:1", "reset:2", "started:3",
		]),
		"accepted lifecycle signals have stable post-state ordering"
	)
	var audit := activity.audit()
	_check(
		audit.valid
		and bool(audit.uses_cargo_transfer_authority)
		and not bool(audit.owns_inventory)
		and not bool(audit.reward_authority)
		and not bool(audit.ship_authority)
		and not bool(audit.berth_authority)
		and not bool(audit.combat_authority)
		and not bool(audit.network_authority)
		and not bool(audit.ui_authority),
		"audit declares composition and denies every deferred gameplay authority"
	)
	await _dispose_fixture(fixture)


func _test_receipt_mismatch_and_failed_transfer_rejection() -> void:
	await _assert_committed_mismatch(&"wrong_item")
	await _assert_committed_mismatch(&"partial_quantity")
	await _assert_committed_mismatch(&"reversed_direction")

	var fixture := await _fixture({&"sealed_parts": 2}, {})
	var contract := _contract(fixture, &"insufficient_run", 4, [], 3.0)
	var activity := ActivityScript.new(fixture.authority, contract) as CargoDeliveryActivity
	var generation := int(activity.start(0).generation)
	var before_failure := (fixture.authority as CargoTransferAuthority).to_dictionary()
	var rejected := activity.submit_transfer(generation)
	_check(
		rejected.reason == &"insufficient_quantity"
		and int(rejected.state) == ActivityScript.State.ACTIVE
		and rejected.accepted_receipt.is_empty(),
		"a failed authority transfer neither completes nor stores a receipt"
	)
	_check(
		(before_failure.manifests as Array) == ((fixture.authority as CargoTransferAuthority).to_dictionary().manifests as Array)
		and ((fixture.authority as CargoTransferAuthority).to_dictionary().committed_transfer_ids as PackedStringArray).is_empty(),
		"failed transfer leaves both authority manifests and committed ledger unchanged"
	)
	activity.advance_physics(2.0, generation)
	var expired := activity.advance_physics(1.0, generation)
	_check(
		expired.reason == &"expired"
		and int(expired.state) == ActivityScript.State.EXPIRED
		and expired.failure_reason == &"deadline_expired",
		"the exact caller physics deadline expires a still-unfulfilled delivery"
	)
	_check(
		activity.advance_physics(1.0, generation).reason == &"not_active"
		and activity.submit_transfer(generation).reason == &"not_active"
		and activity.start(generation).reason == &"reset_required",
		"expiry is terminal and cannot commit late cargo"
	)
	var expiry_reset := activity.reset(generation)
	var expiry_restart := activity.start(int(expiry_reset.generation))
	_check(
		expiry_reset.accepted
		and expiry_restart.accepted
		and int(expiry_restart.generation) == 3,
		"EXPIRED requires reset before a fresh generation can start"
	)
	activity.fail(&"fixture_cleanup", 3)
	await _dispose_fixture(fixture)


func _assert_committed_mismatch(mode: StringName) -> void:
	var destination_initial := {&"sealed_parts": 8} if mode == &"reversed_direction" else {}
	var fixture := await _fixture(
		{&"sealed_parts": 10, &"power_cells": 10},
		destination_initial,
		80,
		80
	)
	var contract := _contract(fixture, StringName("%s_run" % mode), 4, [], 10.0)
	if mode == &"wrong_item":
		# This observer is deliberately connected before the activity. It rewrites
		# the mutable public signal to look like the expected delivery. Completion
		# must still rely on the authority's separate direct return.
		(fixture.authority as CargoTransferAuthority).transfer_committed.connect(
			func(receipt: Dictionary) -> void:
				receipt["item_id"] = &"sealed_parts"
				receipt["quantity"] = 4
				receipt["source_handle"] = contract.get_source_handle()
				receipt["destination_handle"] = contract.get_destination_handle()
				receipt["source_quantity_after"] = 10
				receipt["destination_quantity_after"] = 0
		)
	var activity := ActivityScript.new(fixture.authority, contract) as CargoDeliveryActivity
	var completed_count := {"value": 0}
	activity.completed.connect(func(_snapshot: Dictionary, _receipt: Dictionary) -> void:
		completed_count.value = int(completed_count.value) + 1
	)
	var generation := int(activity.start(0).generation)
	var transfer_id := StringName(activity.get_snapshot().expected_transfer_id)
	var source_handle := contract.get_source_handle()
	var destination_handle := contract.get_destination_handle()
	var item_id := &"sealed_parts"
	var quantity := 4
	if mode == &"wrong_item":
		item_id = &"power_cells"
	elif mode == &"partial_quantity":
		quantity = 2
	elif mode == &"reversed_direction":
		var swap := source_handle
		source_handle = destination_handle
		destination_handle = swap
	var authority_receipt := (fixture.authority as CargoTransferAuthority).transfer(
		transfer_id,
		source_handle,
		destination_handle,
		item_id,
		quantity
	)
	_check(
		authority_receipt.accepted
		and int(activity.get_snapshot().state) == ActivityScript.State.FAILED
		and activity.get_snapshot().failure_reason == &"transfer_id_consumed_externally"
		and int(completed_count.value) == 0,
		"a real committed %s receipt fails closed instead of satisfying the contract" % mode
	)
	_check(
		activity.submit_transfer(generation).reason == &"not_active",
		"a mismatched committed transfer ID cannot be repaired or replayed"
	)
	_check(
		activity.start(generation).reason == &"reset_required",
		"FAILED cannot restart without an explicit reset"
	)
	var failed_reset := activity.reset(generation)
	var failed_restart := activity.start(int(failed_reset.generation))
	_check(
		failed_reset.accepted
		and failed_restart.accepted
		and int(failed_restart.generation) == 3,
		"FAILED reset opens exactly one fresh generation"
	)
	activity.fail(&"fixture_cleanup", 3)
	await _dispose_fixture(fixture)


func _test_stale_detached_and_spoofed_evidence() -> void:
	var stale_fixture := await _fixture({&"sealed_parts": 8}, {})
	var stale_contract := _contract(stale_fixture, &"stale_run", 2, [], 10.0)
	var stale_authority := stale_fixture.authority as CargoTransferAuthority
	_check(stale_authority.retire_entity(stale_contract.get_source_handle()).accepted, "fixture retires the captured source generation")
	var replacement := stale_authority.register_entity(
		stale_fixture.source,
		&"source",
		&"source_manifest",
		40,
		{&"sealed_parts": 8}
	)
	_check(
		replacement.accepted
		and int(replacement.handle.entity_generation) == 2
		and int(replacement.handle.manifest_generation) == 2,
		"replacement source advances both stable generations"
	)
	var stale_activity := ActivityScript.new(stale_authority, stale_contract) as CargoDeliveryActivity
	_check(
		stale_activity.start(0).reason == &"stale_source_handle"
		and stale_activity.get_generation() == 0,
		"a captured stale source handle cannot start against its replacement"
	)
	await _dispose_fixture(stale_fixture)

	var stale_destination_fixture := await _fixture({&"sealed_parts": 8}, {})
	var stale_destination_contract := _contract(
		stale_destination_fixture, &"stale_destination_run", 2, [], 10.0
	)
	var stale_destination_authority := (
		stale_destination_fixture.authority as CargoTransferAuthority
	)
	stale_destination_authority.retire_entity(
		stale_destination_contract.get_destination_handle()
	)
	stale_destination_authority.register_entity(
		stale_destination_fixture.destination,
		&"destination",
		&"destination_manifest",
		40
	)
	var stale_destination_activity := ActivityScript.new(
		stale_destination_authority,
		stale_destination_contract
	) as CargoDeliveryActivity
	_check(
		stale_destination_activity.start(0).reason == &"stale_destination_handle"
		and stale_destination_activity.get_generation() == 0,
		"a captured stale destination handle cannot target its replacement"
	)
	await _dispose_fixture(stale_destination_fixture)

	var detached_fixture := await _fixture({&"sealed_parts": 8}, {})
	var detached_contract := _contract(detached_fixture, &"detached_run", 2, [], 10.0)
	root.remove_child(detached_fixture.source)
	await process_frame
	var detached_activity := ActivityScript.new(detached_fixture.authority, detached_contract) as CargoDeliveryActivity
	_check(detached_activity.start(0).reason == &"source_detached", "a detached bound source fails closed before activity start")
	root.add_child(detached_fixture.source)
	_check(
		(detached_fixture.authority as CargoTransferAuthority).reattach_entity(
			detached_fixture.source,
			detached_contract.get_source_handle()
		).accepted
		and detached_activity.start(0).accepted,
		"the same physical owner can reattach the exact captured handle and start"
	)
	await _dispose_fixture(detached_fixture)

	var spoof_fixture := await _fixture({&"sealed_parts": 8}, {})
	var spoof_contract := _contract(spoof_fixture, &"spoof_run", 2, [], 10.0)
	var spoof_activity := ActivityScript.new(spoof_fixture.authority, spoof_contract) as CargoDeliveryActivity
	spoof_activity.start(0)
	var fake_receipt := {
		"accepted": true,
		"reason": &"committed",
		"receipt_id": 1,
		"transfer_id": spoof_activity.get_snapshot().expected_transfer_id,
		"item_id": &"sealed_parts",
		"quantity": 2,
		"source_handle": spoof_contract.get_source_handle(),
		"destination_handle": spoof_contract.get_destination_handle(),
		"source_quantity_after": 6,
		"destination_quantity_after": 2,
	}
	(spoof_fixture.authority as CargoTransferAuthority).transfer_committed.emit(fake_receipt)
	_check(
		int(spoof_activity.get_snapshot().state) == ActivityScript.State.ACTIVE
		and spoof_activity.get_snapshot().failure_reason == &""
		and (spoof_fixture.authority as CargoTransferAuthority).get_quantity(
			spoof_contract.get_source_handle(), &"sealed_parts"
		) == 8,
		"an exact-looking signal without a committed authority ledger entry is ignored"
	)
	await _dispose_fixture(spoof_fixture)

	var early_fixture := await _fixture({&"sealed_parts": 8}, {})
	var early_phases: Array[StringName] = [&"collect", &"unload"]
	var early_contract := _contract(early_fixture, &"early_run", 2, early_phases, 10.0)
	var early_activity := ActivityScript.new(early_fixture.authority, early_contract) as CargoDeliveryActivity
	early_activity.start(0)
	var early_receipt := (early_fixture.authority as CargoTransferAuthority).transfer(
		early_activity.get_snapshot().expected_transfer_id,
		early_contract.get_source_handle(),
		early_contract.get_destination_handle(),
		&"sealed_parts",
		2
	)
	_check(
		early_receipt.accepted
		and early_activity.get_snapshot().failure_reason == &"transfer_before_phases"
		and int(early_activity.get_snapshot().state) == ActivityScript.State.FAILED,
		"an exact transfer committed before ordered phases fails rather than completing"
	)
	await _dispose_fixture(early_fixture)


func _test_signal_reentry_and_detached_snapshots() -> void:
	var fixture := await _fixture({&"sealed_parts": 4}, {})
	var phases: Array[StringName] = [&"load"]
	var contract := _contract(fixture, &"signal_run", 1, phases, 10.0)
	var activity: CargoDeliveryActivity
	var activity_holder: Dictionary = {}
	var authority_reentry: Dictionary = {}
	(fixture.authority as CargoTransferAuthority).transfer_committed.connect(
		func(_receipt: Dictionary) -> void:
			var current_activity := activity_holder.get("activity") as CargoDeliveryActivity
			authority_reentry["reset"] = current_activity.reset(current_activity.get_generation())
			authority_reentry["fail"] = current_activity.fail(
				&"authority_observer_attack",
				current_activity.get_generation()
			)
	)
	activity = ActivityScript.new(fixture.authority, contract) as CargoDeliveryActivity
	activity_holder["activity"] = activity
	var observations: Array[Dictionary] = []
	activity.started.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"started", activity, snapshot))
	)
	activity.phase_advanced.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"phase", activity, snapshot))
	)
	activity.completed.connect(func(snapshot: Dictionary, receipt: Dictionary) -> void:
		observations.append(_probe_reentry(&"completed", activity, snapshot))
		receipt.clear()
	)
	activity.activity_reset.connect(func(snapshot: Dictionary) -> void:
		observations.append(_probe_reentry(&"reset", activity, snapshot))
	)
	var generation := int(activity.start(0).generation)
	activity.submit_phase(&"load", generation)
	activity.submit_transfer(generation)
	_check(
		(authority_reentry.reset as Dictionary).reason == &"reentrant_call"
		and (authority_reentry.fail as Dictionary).reason == &"reentrant_call"
		and int(activity.get_snapshot().state) == ActivityScript.State.COMPLETED,
		"earlier authority-signal observers cannot reset or fail during synchronous submission"
	)
	activity.reset(generation)
	var all_reentrant := true
	var labels := PackedStringArray()
	for observation: Dictionary in observations:
		labels.append(str(observation.label))
		all_reentrant = (
			all_reentrant
			and bool(observation.all_reentrant)
			and bool(observation.snapshot_unchanged)
		)
	_check(all_reentrant, "every lifecycle signal rejects all public mutator reentry without state change")
	_check(
		labels == PackedStringArray(["started", "phase", "completed", "reset"]),
		"signal dispatch remains exact and deterministically ordered"
	)
	_check(
		int(activity.get_snapshot().state) == ActivityScript.State.IDLE
		and int(activity.get_snapshot().generation) == 2
		and (activity.get_snapshot().accepted_receipt as Dictionary).is_empty(),
		"observer mutation and reentry cannot corrupt the committed reset snapshot"
	)
	await _dispose_fixture(fixture)


func _probe_reentry(label: StringName, activity: CargoDeliveryActivity, emitted: Dictionary) -> Dictionary:
	var generation := int(emitted.generation)
	var before := activity.get_snapshot()
	var results := [
		activity.start(generation),
		activity.submit_phase(&"load", generation),
		activity.submit_transfer(generation),
		activity.advance_physics(0.1, generation),
		activity.fail(&"observer_attack", generation),
		activity.reset(generation),
	]
	var all_reentrant := true
	for result: Dictionary in results:
		all_reentrant = all_reentrant and result.reason == &"reentrant_call"
	emitted.clear()
	return {
		"label": label,
		"all_reentrant": all_reentrant,
		"snapshot_unchanged": activity.get_snapshot() == before,
	}


func _test_contract_validation() -> void:
	var fixture := await _fixture({&"sealed_parts": 5}, {})
	var valid_phases: Array[StringName] = []
	var valid := _contract(fixture, &"valid_no_phases", 1, valid_phases, 5.0)
	_check(
		valid.is_configuration_valid()
		and valid.get_transfer_id(1) == &"valid_no_phases_g1"
		and valid.get_transfer_id(0).is_empty(),
		"optional empty phases remain valid and transfer IDs require a positive generation"
	)
	var invalid_phases: Array[StringName] = [&"load", &"load", &"Bad Phase"]
	var invalid := ContractScript.new(
		&"Bad Contract",
		fixture.source_handle,
		fixture.source_handle,
		&"Bad Item",
		0,
		invalid_phases,
		NAN
	) as CargoDeliveryContract
	_check(
		not invalid.is_configuration_valid()
		and invalid.get_configuration_errors().size() >= 6,
		"invalid identity, direction, item, quantity, phases, and deadline fail closed together"
	)
	var stale_generation_handle := (fixture.source_handle as Dictionary).duplicate(true)
	stale_generation_handle["entity_generation"] = 0
	var invalid_handle := ContractScript.new(
		&"bad_handle",
		stale_generation_handle,
		fixture.destination_handle,
		&"sealed_parts",
		1,
		valid_phases,
		5.0
	) as CargoDeliveryContract
	_check(
		not invalid_handle.is_configuration_valid()
		and "source handle has an invalid generation" in invalid_handle.get_configuration_errors(),
		"non-positive handle generations are structurally rejected"
	)
	var too_many_phases: Array[StringName] = []
	for index in ContractScript.MAX_ORDERED_PHASES + 1:
		too_many_phases.append(StringName("phase_%02d" % index))
	var bounded := _contract(fixture, &"too_many_phases", 1, too_many_phases, 5.0)
	_check(
		not bounded.is_configuration_valid()
		and "ordered phase count exceeds 16" in bounded.get_configuration_errors(),
		"ordered phase memory is explicitly bounded"
	)
	var audit_copy := valid.audit()
	(audit_copy.source_handle as Dictionary).clear()
	_check(
		valid.audit().valid
		and not (valid.audit().source_handle as Dictionary).is_empty(),
		"contract audit is deterministic and deeply detached"
	)
	var frozen_contract := _contract(fixture, &"frozen_binding", 1, valid_phases, 5.0)
	var frozen_activity := ActivityScript.new(
		fixture.authority,
		frozen_contract
	) as CargoDeliveryActivity
	frozen_contract.set("_quantity", 4)
	frozen_contract.set("_deadline_seconds", 0.25)
	var frozen_start := frozen_activity.start(0)
	_check(
		frozen_start.accepted
		and int((frozen_start.contract as Dictionary).quantity) == 1
		and is_equal_approx(float(frozen_start.deadline_seconds), 5.0),
		"activity binding snapshots the contract against later caller-owned mutation"
	)
	await _dispose_fixture(fixture)


func _fixture(
	source_initial: Dictionary,
	destination_initial: Dictionary,
	source_capacity: int = 40,
	destination_capacity: int = 40
	) -> Dictionary:
	var authority := AuthorityScript.new() as CargoTransferAuthority
	root.add_child(authority)
	authority.register_item(_item(&"sealed_parts", "Sealed parts", 1))
	authority.register_item(_item(&"power_cells", "Power cells", 1))
	var source := Node.new()
	source.name = "CargoSource"
	root.add_child(source)
	var destination := Node.new()
	destination.name = "CargoDestination"
	root.add_child(destination)
	var source_registration := authority.register_entity(
		source, &"source", &"source_manifest", source_capacity, source_initial
	)
	var destination_registration := authority.register_entity(
		destination, &"destination", &"destination_manifest", destination_capacity, destination_initial
	)
	return {
		"authority": authority,
		"source": source,
		"destination": destination,
		"source_handle": (source_registration.handle as Dictionary).duplicate(true),
		"destination_handle": (destination_registration.handle as Dictionary).duplicate(true),
	}


func _contract(
	fixture: Dictionary,
	contract_id: StringName,
	quantity: int,
	phases: Array[StringName],
	deadline_seconds: float
	) -> CargoDeliveryContract:
	return ContractScript.new(
		contract_id,
		fixture.source_handle,
		fixture.destination_handle,
		&"sealed_parts",
		quantity,
		phases,
		deadline_seconds
	) as CargoDeliveryContract


func _item(item_id: StringName, display_name: String, unit_capacity: int) -> CargoItemDefinition:
	var definition := ItemScript.new() as CargoItemDefinition
	definition.item_id = item_id
	definition.display_name = display_name
	definition.unit_capacity = unit_capacity
	return definition


func _dispose_fixture(fixture: Dictionary) -> void:
	for key: StringName in [&"source", &"destination", &"authority"]:
		var node := fixture.get(key) as Node
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CARGO_DELIVERY_CONTRACT_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CARGO_DELIVERY_CONTRACT_TEST_OK")
		quit(0)
	else:
		print("CARGO_DELIVERY_CONTRACT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
