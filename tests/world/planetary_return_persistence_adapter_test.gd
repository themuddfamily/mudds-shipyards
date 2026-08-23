extends SceneTree

const AdapterScript := preload("res://scripts/world/planetary_return_persistence_adapter.gd")

class FakeRuntime:
	var travel := {"state_id": &"completed", "generation": 7}
	var contract := {"phase_id": &"completed", "return_target_id": &"mudds_shipyards", "world_id": &"ember_moon", "run_generation": 7}
	func get_presentation_snapshot() -> Dictionary: return travel.duplicate(true)
	func get_snapshot() -> Dictionary: return contract.duplicate(true)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime := FakeRuntime.new()
	var adapter := AdapterScript.new()
	var receipt := {
		"accepted": true, "reason": &"returned_to_station",
		"berth_receipt": {
			"accepted": true, "reason": &"return_berth_occupied",
			"session_generation": 7, "attachment_generation": 4,
			"actor_instance_id": 11, "craft_instance_id": 22,
		},
	}
	var saved := adapter.capture(runtime, runtime, receipt)
	var restored := adapter.restore(saved)
	var replay := adapter.restore(saved)
	var lease := saved.duplicate(true)
	lease.berth_lease.active = true
	var rejected_lease := AdapterScript.new().restore(lease)
	var valid: bool = saved.get("marker") == &"returned_to_station" \
			and restored.accepted \
			and restored.surface_attachment.state == &"detached" \
			and restored.berth_lease.state == &"fresh_station" \
			and not bool(restored.reward_replay_allowed) \
			and not replay.accepted \
			and not rejected_lease.accepted
	if not valid:
		push_error("planetary return persistence adapter failed")
		quit(1)
		return
	print("PLANETARY_RETURN_PERSISTENCE_TEST_OK: completed marker restores fresh station state")
	quit(0)
