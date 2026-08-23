extends SceneTree

const AdapterScript := preload("res://scripts/world/planetary_return_persistence_adapter.gd")

var _failures := PackedStringArray()


class FakeRuntime:
	var travel := {
		"state_id": &"completed", "generation": 7,
		"attachment_generation": 4, "reward_authority": false,
	}
	var contract := {
		"phase_id": &"completed", "return_target_id": &"mudds_shipyards",
		"world_id": &"ember_moon", "run_generation": 7,
		"attachment_generation": 4,
		"authority": {"movement": false, "reward": false},
	}
	func get_presentation_snapshot() -> Dictionary: return travel.duplicate(true)
	func get_snapshot() -> Dictionary: return contract.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := FakeRuntime.new()
	var adapter := AdapterScript.new()
	var receipt := _receipt()
	var saved := adapter.capture(runtime, runtime, receipt)
	_check(bool(saved.get("accepted", false)), "completed return is captured")
	_check(
		(saved.completed_return.returned_receipt as Dictionary).berth_receipt.token == "lease-7"
		and saved.completed_return.travel_session.state_id == "completed"
		and saved.completed_return.return_contract.phase_id == "completed"
		and str(saved.receipt_sha256).length() == 64,
		"the exact session, contract, and berth receipt are retained behind a digest",
	)
	var restored := adapter.restore(saved)
	_check(
		bool(restored.get("accepted", false))
		and restored.surface_attachment.state == &"detached"
		and restored.berth_lease.state == &"fresh_station"
		and not bool(restored.reward_replay_allowed),
		"restore publishes detached fresh-station evidence only",
	)
	_check(
		adapter.restore(saved).reason == &"return_persistence_stale_generation",
		"one adapter cannot replay the same generation twice",
	)
	_check(
		bool(adapter.retire(7).get("accepted", false))
		and adapter.restore(saved).reason == &"return_persistence_stale_generation",
		"explicit retirement permanently fences the consumed generation",
	)

	var corrupt := saved.duplicate(true)
	corrupt.completed_return.returned_receipt.berth_receipt.craft_instance_id = 99
	_check(
		AdapterScript.new().restore(corrupt).reason == &"return_persistence_receipt_corrupt",
		"tampered receipt content is rejected by the exact digest",
	)
	var newer := saved.duplicate(true)
	newer.schema_version = 2
	_check(
		AdapterScript.new().restore(newer).reason == &"return_persistence_newer_schema",
		"a newer adapter schema fails closed",
	)
	var active := saved.duplicate(true)
	active.surface_attachment.active = true
	_check(
		AdapterScript.new().restore(active).reason == &"return_persistence_surface_attachment_active",
		"active surface authority cannot be restored",
	)
	var lease := saved.duplicate(true)
	lease.berth_lease.active = true
	_check(
		AdapterScript.new().restore(lease).reason == &"return_persistence_berth_authority_present",
		"an active berth lease cannot be restored",
	)
	var reward := saved.duplicate(true)
	reward.completed_return.return_contract.authority.reward_authority = true
	reward.receipt_sha256 = AdapterScript.new().call(
		"_digest", reward.completed_return
	)
	_check(
		AdapterScript.new().restore(reward).reason == &"return_persistence_reward_authority_present",
		"reward authority is rejected even when its payload digest is internally consistent",
	)
	var stale_runtime := FakeRuntime.new()
	stale_runtime.travel.generation = 8
	_check(
		not bool(AdapterScript.new().capture(stale_runtime, stale_runtime, receipt).get("accepted", false)),
		"capture rejects a stale session generation",
	)

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PLANETARY_RETURN_PERSISTENCE_TEST_OK: exact terminal receipt restores once without authority")
	quit(0)


func _receipt() -> Dictionary:
	return {
		"accepted": true,
		"reason": &"returned_to_station",
		"berth_receipt": {
			"accepted": true,
			"reason": &"return_berth_occupied",
			"berth_id": &"mudds_return_berth",
			"token": &"lease-7",
			"session_generation": 7,
			"attachment_generation": 4,
			"actor_instance_id": 11,
			"craft_instance_id": 22,
		},
		"contract_receipt": {
			"accepted": true,
			"reason": &"returned_to_station",
			"phase_id": &"completed",
		},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
