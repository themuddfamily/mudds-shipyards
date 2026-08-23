extends SceneTree

const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const BerthScript := preload("res://scripts/world/ship_berth.gd")
const ARROW_DEFINITION := preload("res://assets/ships/arrow_provisional.tres")

class ReturnCraft extends Node:
	var ship_id: StringName = &"arrow_provisional"
	func is_piloted() -> bool: return true
	func get_ship_id() -> StringName: return ship_id

class ReturnBinding:
	var detach_calls := 0
	var generation := 7
	func detach_planetary_surface() -> Dictionary:
		detach_calls += 1
		return {"accepted": true, "reason": &"detached"}
	func get_generation() -> int: return generation
	func get_planetary_surface_snapshot() -> Dictionary:
		return {"attachment_generation": 3}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var berth := BerthScript.new()
	berth.berth_id = &"mudds_return_berth"
	var craft := ReturnCraft.new()
	var actor := Node.new()
	root.add_child(berth)
	root.add_child(craft)
	root.add_child(actor)
	var token := berth.try_reserve(craft, ARROW_DEFINITION)
	var occupied := berth.occupy(craft, token)
	var flow := GameFlowScript.new()
	flow.phase = GameFlowScript.Phase.RETURN_TO_YARD
	var binding := ReturnBinding.new()
	var receipt := {
		"accepted": true,
		"reason": &"returned_to_station",
		"berth_receipt": {
			"accepted": true,
			"reason": &"return_berth_occupied",
			"berth_id": berth.berth_id,
			"token": token,
			"actor_instance_id": actor.get_instance_id(),
			"craft_instance_id": craft.get_instance_id(),
			"session_generation": 7,
			"attachment_generation": 3,
		},
		"contract_receipt": {"accepted": true, "reason": &"completed"},
	}
	var foreign := receipt.duplicate(true)
	foreign.berth_receipt.actor_instance_id = actor.get_instance_id() + 1
	var rejected := flow.consume_planetary_return_receipt(
		foreign, binding, berth, craft, actor
	)
	var stale := receipt.duplicate(true)
	stale.berth_receipt.session_generation = 8
	var stale_result := flow.consume_planetary_return_receipt(
		stale, binding, berth, craft, actor
	)
	var accepted := flow.consume_planetary_return_receipt(
		receipt, binding, berth, craft, actor
	)
	var replay := flow.consume_planetary_return_receipt(
		receipt, binding, berth, craft, actor
	)
	var valid: bool = occupied and not rejected.accepted \
			and not stale_result.accepted \
			and accepted.accepted \
			and accepted.reason == &"planetary_return_consumed" \
			and flow.phase == GameFlowScript.Phase.SHUT_DOWN \
			and binding.detach_calls == 1 \
			and berth.is_occupied() \
			and berth.get_occupant() == craft \
			and not replay.accepted
	flow.free()
	actor.free()
	craft.free()
	berth.free()
	await process_frame
	if not valid:
		push_error("game flow planetary return integration failed")
		quit(1)
		return
	print("GAME_FLOW_PLANETARY_RETURN_TEST_OK: occupied Ember receipt reaches shutdown")
	quit(0)
