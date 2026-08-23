extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

class Store:
	var payload: Dictionary = {}
	func commit(next: Dictionary, _generation: int, _commit_id: String) -> Dictionary:
		payload = next.duplicate(true)
		return {"accepted": true, "generation": 1}
	func load() -> Dictionary:
		return {"accepted": not payload.is_empty(), "payload": payload.duplicate(true)}

class Runtime:
	func get_presentation_snapshot() -> Dictionary:
		return {"state_id": &"completed", "generation": 7}
	func get_snapshot() -> Dictionary:
		return {"phase_id": &"completed", "return_target_id": &"mudds_shipyards", "world_id": &"ember_moon", "run_generation": 7}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BindingScript.new()
	var store := Store.new()
	var configured := binding.configure_planetary_return_persistence(store, &"return_slot")
	var receipt := {
		"accepted": true, "reason": &"returned_to_station",
		"berth_receipt": {
			"accepted": true, "reason": &"return_berth_occupied",
			"session_generation": 7, "attachment_generation": 4,
			"actor_instance_id": 11, "craft_instance_id": 22,
		},
	}
	var saved := binding.save_planetary_return_persistence(
		Runtime.new(), Runtime.new(), receipt, 0, "return-1"
	)
	var loaded := binding.restore_planetary_return_persistence()
	var bad_receipt := receipt.duplicate(true)
	bad_receipt.reason = &"not_returned"
	var rejected := binding.save_planetary_return_persistence(
		Runtime.new(), Runtime.new(), bad_receipt, 1, "return-2"
	)
	var valid: bool = configured.accepted and saved.accepted \
			and loaded.accepted and bool(loaded.detached) \
			and bool(loaded.fresh_station) and not rejected.accepted \
			and binding.get_planetary_return_persistence_snapshot().owns_save_authority == false
	binding.free()
	await process_frame
	if not valid:
		push_error("Ember return persistence composition failed")
		quit(1)
		return
	print("EMBER_RETURN_PERSISTENCE_TEST_OK: binding commits and restores detached station marker")
	quit(0)
