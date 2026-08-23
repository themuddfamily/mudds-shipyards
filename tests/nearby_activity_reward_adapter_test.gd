extends SceneTree

const AdapterScript := preload("res://scripts/world/nearby_activity_reward_adapter.gd")
const BindingScript := preload("res://scripts/world/nearby_sector_activity_binding.gd")

var callback_count := 0

func _init() -> void:
	call_deferred("_run")

func _reward_callback(_request: Dictionary) -> Dictionary:
	callback_count += 1
	return {"accepted": true, "reason": &"caller_store_accepted"}

func _run() -> void:
	var adapter := AdapterScript.new()
	var binding := BindingScript.new()
	var configured := adapter.configure(
		Callable(self, "_reward_callback"),
		&"shipyard_perimeter_defense", &"return_defense_report_to_shipyard"
	)
	var completed := adapter.consume({
		"activity_id": &"shipyard_perimeter_defense",
		"state_id": &"concluded",
		"outcome": &"cleared",
		"generation": 7,
	}, 7)
	var registered := adapter.register_activity(
		&"cinder_reach_emberline_convoy", &"return_convoy_credit_to_shipyard"
	)
	var convoy_completed := adapter.consume({
		"activity_id": &"cinder_reach_emberline_convoy",
		"state_id": &"completed",
		"outcome": &"cleared",
		"generation": 3,
	}, 3)
	var cargo_registered := adapter.register_activity(
		&"cinder_kit_cargo_run", &"return_fabrication_kits_to_shipyard"
	)
	var cargo_completed := adapter.consume({
		"activity_id": &"cinder_kit_cargo_run",
		"state_id": &"completed",
		"outcome": &"cleared",
		"generation": 11,
	}, 11)
	var patrol_registered := adapter.register_activity(
		&"cinder_relay_patrol", &"return_patrol_log_to_shipyard"
	)
	var patrol_completed := adapter.consume({
		"activity_id": &"cinder_relay_patrol",
		"state_id": &"completed",
		"outcome": &"cleared",
		"generation": 13,
	}, 13)
	var race_registered := adapter.register_activity(
		&"cinder_reach_checkpoint_route", &"return_race_record_to_shipyard"
	)
	var race_completed := adapter.consume({
		"activity_id": &"cinder_reach_checkpoint_route",
		"state_id": &"completed",
		"outcome": &"cleared",
		"generation": 17,
	}, 17)
	var duplicate := adapter.consume({
		"activity_id": &"shipyard_perimeter_defense",
		"state_id": &"concluded",
		"outcome": &"cleared",
		"generation": 7,
	}, 7)
	var detached := adapter.detach()
	var reentered := adapter.reenter(2)
	var failed_state := adapter.consume({
		"activity_id": &"shipyard_perimeter_defense",
		"state_id": &"failed",
		"outcome": &"cleared",
		"generation": 8,
	}, 8)
	var reset := adapter.reset()
	var valid: bool = configured.accepted and completed.accepted and registered.accepted \
			and convoy_completed.accepted and cargo_registered.accepted \
			and cargo_completed.accepted and patrol_registered.accepted \
			and patrol_completed.accepted and race_registered.accepted \
			and race_completed.accepted \
			and not duplicate.accepted and detached.accepted and reentered.accepted \
			and not failed_state.accepted and reset.accepted and callback_count == 5 \
			and binding.has_method(&"configure_station_defense_reward") \
			and binding.has_method(&"request_station_defense_reward") \
			and binding.has_method(&"request_convoy_reward") \
			and binding.has_method(&"request_cargo_reward") \
			and binding.has_method(&"request_patrol_reward") \
			and binding.has_method(&"request_race_reward") \
			and binding.has_method(&"detach_station_defense_reward")
	if not valid:
		push_error("nearby activity reward adapter failed")
		binding.free()
		adapter = null
		await process_frame
		quit(1)
		return
	print("NEARBY_ACTIVITY_REWARD_ADAPTER_TEST_OK: caller-owned exactly-once reward handoff")
	binding.free()
	adapter = null
	await process_frame
	quit(0)
