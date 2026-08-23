extends SceneTree

const AdapterScript := preload("res://scripts/world/planetary_return_berth_adapter.gd")
const BerthScript := preload("res://scripts/world/ship_berth.gd")
const ARROW_DEFINITION := preload("res://assets/ships/arrow_provisional.tres")
const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

class FakeLandingReturnContract:
	var calls := 0
	func confirm_orbit_return(_confirmed: bool, target: StringName, _observation: Dictionary, run_generation: int, attachment_generation: int) -> Dictionary:
		calls += 1
		return {"accepted": target == &"mudds_shipyards", "reason": &"completed", "run_generation": run_generation, "attachment_generation": attachment_generation}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var berth := BerthScript.new()
	berth.berth_id = &"mudds_return_berth"
	var ship := Node.new()
	root.add_child(berth)
	root.add_child(ship)
	var adapter := AdapterScript.new()
	var receipt := {"accepted": true, "return_target_id": &"mudds_shipyards"}
	var requested := adapter.request(receipt, berth, ship, ARROW_DEFINITION, 11, 22, 4, 6)
	var occupied := adapter.confirm_occupied({"accepted": true, "strict_dock_acceptance": true})
	var duplicate := adapter.confirm_occupied({"accepted": true, "strict_dock_acceptance": true})
	var contract := FakeLandingReturnContract.new()
	var foreign := occupied.duplicate(true)
	foreign.token = &"foreign"
	var foreign_result := adapter.complete_return_contract(foreign, contract, {"position": Vector3.ZERO})
	var returned := adapter.complete_return_contract(occupied, contract, {"position": Vector3.ZERO})
	var returned_duplicate := adapter.complete_return_contract(occupied, contract, {"position": Vector3.ZERO})
	var reset := adapter.reset()
	var retired := adapter.retire(5)
	var second_request := adapter.request(receipt, berth, ship, ARROW_DEFINITION, 11, 22, 5, 7)
	var second_occupied := adapter.confirm_occupied({"accepted": true, "strict_dock_acceptance": true})
	var stale_first_receipt := adapter.complete_return_contract(occupied, contract, {"position": Vector3.ZERO})
	var binding := BindingScript.new()
	var valid: bool = requested.accepted and occupied.accepted \
			and not duplicate.accepted and reset.accepted \
			and not foreign_result.accepted and returned.accepted \
			and not returned_duplicate.accepted and contract.calls == 1 \
			and retired.accepted and second_request.accepted and second_occupied.accepted \
			and not stale_first_receipt.accepted \
			and berth.is_occupied() == true \
			and occupied.berth_id == &"mudds_return_berth" \
			and binding.has_method(&"request_planetary_return_berth") \
			and binding.has_method(&"confirm_planetary_return_berth_occupied") \
			and binding.has_method(&"complete_planetary_return_contract") \
			and binding.has_method(&"retire_planetary_return")
	if not valid:
		push_error("planetary return berth adapter failed")
		binding.free()
		ship.free()
		berth.free()
		await process_frame
		quit(1)
		return
	print("PLANETARY_RETURN_BERTH_ADAPTER_TEST_OK: real lease and occupancy handoff")
	binding.free()
	ship.free()
	berth.free()
	await process_frame
	quit(0)
