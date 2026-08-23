extends SceneTree

const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const MainScene := preload("res://scenes/main.tscn")
const BerthScript := preload("res://scripts/world/ship_berth.gd")
const ARROW_DEFINITION := preload("res://assets/ships/arrow_provisional.tres")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": OK, "bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK

class ReturnCraft extends Node:
	var ship_id: StringName = &"arrow_provisional"
	func is_piloted() -> bool: return true
	func get_ship_id() -> StringName: return ship_id

class ReturnBinding:
	var detach_calls := 0
	var generation := 7
	var saved := false
	func configure_planetary_return_persistence(_store: RefCounted, _slot: StringName) -> Dictionary:
		return {"accepted": true, "reason": &"configured"}
	func save_planetary_return_persistence(_travel: Object, _contract: Object, _receipt: Dictionary, _generation: int, _commit_id: String) -> Dictionary:
		saved = true
		return {"accepted": true, "reason": &"saved"}
	func restore_planetary_return_persistence() -> Dictionary:
		return {"accepted": saved, "reason": &"restored"}
	func detach_planetary_surface() -> Dictionary:
		detach_calls += 1
		return {"accepted": true, "reason": &"detached"}
	func get_generation() -> int: return generation
	func get_planetary_surface_snapshot() -> Dictionary:
		return {"attachment_generation": 3}

class StartupPersistenceBinding:
	var restore_calls := 0
	var retire_calls := 0
	var retirement_generations: Array[int] = []
	var retirement_commit_ids: Array[String] = []
	var fail_retirement_once := false
	var forge_movement_authority := false

	func restore_planetary_return_persistence() -> Dictionary:
		restore_calls += 1
		return {
			"accepted": true,
			"reason": &"return_persistence_loaded",
			"detached": true,
			"fresh_station": true,
			"requires_retirement": true,
			"store_generation": 12,
			"session": {
				"accepted": true,
				"reason": &"returned_to_station_restored",
				"marker": &"returned_to_station",
				"run_generation": 7,
				"attachment_generation": 4,
				"actor_instance_id": 101,
				"craft_instance_id": 202,
				"receipt_sha256": "a".repeat(64),
				"surface_attachment": {
					"active": false, "state": &"detached",
				},
				"berth_lease": {
					"active": false, "state": &"fresh_station",
				},
				"reward_replay_allowed": false,
				"movement_authority": forge_movement_authority,
			}.duplicate(true),
		}.duplicate(true)

	func retire_planetary_return_persistence(
			expected_store_generation: int, commit_id: String
		) -> Dictionary:
		retire_calls += 1
		retirement_generations.append(expected_store_generation)
		retirement_commit_ids.append(commit_id)
		if fail_retirement_once:
			fail_retirement_once = false
			return {"accepted": false, "reason": &"temp_write_failed"}
		return {
			"accepted": true,
			"reason": &"committed",
			"binding_reason": &"retired",
			"generation": expected_store_generation + 1,
			"run_generation": 7,
		}.duplicate(true)

class Runtime:
	func get_presentation_snapshot() -> Dictionary:
		return {"state_id": &"completed", "generation": 7}
	func get_snapshot() -> Dictionary:
		return {"phase_id": &"completed", "return_target_id": &"mudds_shipyards", "world_id": &"ember_moon", "run_generation": 7}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var authored_main := MainScene.instantiate()
	var authored_binding_count := authored_main.find_children("EmberSurfaceLoopProductionBinding", "Node", true, false).size()
	authored_main.free()
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
	var begin_rejected := flow.begin_ember_surface_journey(null, null, Callable(), 1)
	var binding := ReturnBinding.new()
	var store := StoreScript.new("user://game_flow_planetary_return_test.json", MemoryFilesystem.new())
	flow.set("_runtime_settings_user_data_store", store)
	var persistence_bound := flow.bind_planetary_return_persistence(binding)
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
		receipt, binding, berth, craft, actor, Runtime.new(), Runtime.new()
	)
	var restored := flow.restore_planetary_return_persistence()
	var replay := flow.consume_planetary_return_receipt(
		receipt, binding, berth, craft, actor
	)

	var startup_flow := GameFlowScript.new()
	startup_flow.phase = GameFlowScript.Phase.RETURN_TO_YARD
	var startup_binding := StartupPersistenceBinding.new()
	startup_binding.fail_retirement_once = true
	startup_flow.set("_planetary_return_persistence_binding", startup_binding)
	var startup_phase_before := startup_flow.phase
	var failed_startup_retirement := (
		startup_flow._restore_and_retire_planetary_return_persistence()
	)
	var retried_startup_retirement := (
		startup_flow.retry_planetary_return_persistence_retirement()
	)
	var retired_replay := (
		startup_flow.retry_planetary_return_persistence_retirement()
	)
	var startup_retirement_valid: bool = (
		not bool(failed_startup_retirement.get("accepted", true))
		and failed_startup_retirement.get("reason") == &"temp_write_failed"
		and bool(retried_startup_retirement.get("accepted", false))
		and retired_replay.get("reason") \
			== &"planetary_return_startup_already_retired"
		and startup_binding.restore_calls == 1
		and startup_binding.retire_calls == 2
		and startup_binding.retirement_generations == [12, 12]
		and startup_binding.retirement_commit_ids == [
			"planetary-return-retire-0000000012",
			"planetary-return-retire-0000000012",
		]
		and bool(startup_flow.get(
			"_planetary_return_startup_retired"
		))
		and not bool(startup_flow.get(
			"_planetary_return_startup_retirement_pending"
		))
		and startup_flow.phase == startup_phase_before
		and not bool(startup_flow.get("_return_registered"))
		and not bool(startup_flow.get("_planetary_return_receipt_consumed"))
		and (startup_flow.get("_berth_tokens") as Dictionary).is_empty()
		and (startup_flow.get("_reserved_berth_ids") as Dictionary).is_empty()
	)
	var forged_flow := GameFlowScript.new()
	var forged_binding := StartupPersistenceBinding.new()
	forged_binding.forge_movement_authority = true
	forged_flow.set("_planetary_return_persistence_binding", forged_binding)
	var forged_restore := (
		forged_flow._restore_and_retire_planetary_return_persistence()
	)
	startup_retirement_valid = startup_retirement_valid \
		and forged_restore.get("reason") \
			== &"planetary_return_startup_restore_invalid" \
		and forged_binding.restore_calls == 1 \
		and forged_binding.retire_calls == 0 \
		and not bool(forged_flow.get(
			"_planetary_return_startup_retirement_pending"
		))
	var valid: bool = authored_binding_count == 1 \
			and begin_rejected.reason == &"ember_surface_request_invalid" \
			and occupied and not rejected.accepted \
			and not stale_result.accepted \
			and accepted.accepted \
			and accepted.reason == &"planetary_return_consumed" \
			and flow.phase == GameFlowScript.Phase.SHUT_DOWN \
			and binding.detach_calls == 1 \
			and persistence_bound.accepted and binding.saved and restored.accepted \
			and berth.is_occupied() \
			and berth.get_occupant() == craft \
			and not replay.accepted \
			and startup_retirement_valid
	startup_flow.free()
	forged_flow.free()
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
