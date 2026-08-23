extends SceneTree

const HANDOFF := preload("res://scripts/cargo/cinder_cargo_reward_handoff.gd")
const ADAPTER := preload("res://scripts/world/nearby_activity_reward_adapter.gd")

var _assertions := 0
var _failures: Array[String] = []
var _callback_count := 0
var _reject_next := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _build_fixture()
	var activity := fixture.activity as CargoDeliveryActivity
	var adapter := ADAPTER.new()
	adapter.configure(
		Callable(self, "_reward_callback"), &"station", &"station_reward"
	)
	adapter.register_activity(HANDOFF.ACTIVITY_ID, HANDOFF.REWARD_ID)
	var handoff = HANDOFF.new()
	_check(
		handoff.attach(activity, adapter).accepted,
		"cargo completion attaches to the existing nearby reward adapter"
	)

	var first_generation := _complete(activity)
	var first := handoff.get_snapshot()
	_check(
		int(_callback_count) == 1
		and bool((first.last_result as Dictionary).accepted)
		and (first.last_result as Dictionary).reason == &"reward_request_committed"
		and int(first.completion_generation) == first_generation,
		"authoritative transfer completion commits the existing reward intent once"
	)
	var acknowledgment := handoff.request(first_generation)
	var replay := handoff.request(first_generation)
	_check(
		acknowledgment.accepted
		and not replay.accepted and replay.reason == &"reward_already_consumed"
		and _callback_count == 1,
		"the explicit completion acknowledgment reuses the result once, then replay is rejected before the grant callback"
	)

	var reset := activity.reset(first_generation)
	var handoff_reset := handoff.reset(int(reset.generation))
	_check(
		reset.accepted and handoff_reset.accepted
		and (handoff.get_snapshot().last_result as Dictionary).is_empty(),
		"activity reset clears the retained handoff result without clearing its replay fence"
	)
	var second_generation := _complete(activity)
	_check(
		second_generation > first_generation and _callback_count == 2
		and int(handoff.get_snapshot().completion_generation) == second_generation,
		"a fresh cargo generation can commit one fresh existing reward intent"
	)

	var rejected_fixture := _build_fixture()
	var rejected_activity := rejected_fixture.activity as CargoDeliveryActivity
	var rejected_adapter := ADAPTER.new()
	rejected_adapter.configure(
		Callable(self, "_reward_callback"), &"station", &"station_reward"
	)
	rejected_adapter.register_activity(HANDOFF.ACTIVITY_ID, HANDOFF.REWARD_ID)
	var rejected_handoff = HANDOFF.new()
	rejected_handoff.attach(rejected_activity, rejected_adapter)
	_reject_next = true
	var rejected_generation := _complete(rejected_activity)
	var rejected := rejected_handoff.get_snapshot().last_result as Dictionary
	var count_after_rejection := _callback_count
	var retry := rejected_handoff.request(rejected_generation)
	var retry_replay := rejected_handoff.request(rejected_generation)
	_check(
		not rejected.accepted and rejected.reason == &"reward_callback_rejected"
		and retry.accepted and retry.reason == &"reward_request_committed"
		and not retry_replay.accepted and retry_replay.reason == &"reward_already_consumed"
		and _callback_count == count_after_rejection + 1,
		"a rejected grant remains retryable, then commits exactly once and fences replay"
	)
	_check(
		not bool(rejected_handoff.get_snapshot().reward_authority)
		and not bool(rejected_handoff.get_snapshot().inventory_authority)
		and not bool(rejected_handoff.get_snapshot().grant_authority),
		"the handoff never acquires reward, inventory, or grant authority"
	)

	handoff.detach()
	rejected_handoff.detach()
	(fixture.authority as Node).queue_free()
	(rejected_fixture.authority as Node).queue_free()
	await process_frame
	_finish()


func _build_fixture() -> Dictionary:
	var authority := CargoTransferAuthority.new()
	root.add_child(authority)
	var item := CargoItemDefinition.new()
	item.item_id = &"cinder_supply_crates"
	item.display_name = "Cinder supply crates"
	item.unit_capacity = 1
	authority.register_item(item)
	var source := Node.new()
	var destination := Node.new()
	authority.add_child(source)
	authority.add_child(destination)
	var source_handle := authority.register_entity(
		source, &"source", &"source_manifest", 4, {&"cinder_supply_crates": 2}
	).handle as Dictionary
	var destination_handle := authority.register_entity(
		destination, &"destination", &"destination_manifest", 4
	).handle as Dictionary
	var contract := CargoDeliveryContract.new(
		&"cinder_platform_supply_run", source_handle, destination_handle,
		&"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0
	)
	return {
		"authority": authority,
		"activity": CargoDeliveryActivity.new(authority, contract),
	}


func _complete(activity: CargoDeliveryActivity) -> int:
	var started := activity.start(activity.get_generation())
	for phase_id: StringName in [&"load_crate", &"clear_gate", &"dock_platform"]:
		activity.submit_phase(phase_id, int(started.generation))
	var delivered := activity.submit_transfer(int(started.generation))
	_check(bool(delivered.accepted), "fixture commits one authoritative cargo transfer")
	return int(started.generation)


func _reward_callback(_request: Dictionary) -> Dictionary:
	_callback_count += 1
	if _reject_next:
		_reject_next = false
		return {"accepted": false, "reason": &"store_busy"}
	return {"accepted": true, "reason": &"existing_grant_contract_accepted"}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_REWARD_HANDOFF_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
