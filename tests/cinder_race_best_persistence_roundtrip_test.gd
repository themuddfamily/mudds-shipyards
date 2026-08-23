extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred(&"_run")


func _accept_reward(request: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {
		"accepted": true,
		"reason": &"reward_receipt_committed",
		"activity_id": request.get("activity_id", &""),
		"reward_id": request.get("reward_id", &""),
	}


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-race-best.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic store loads")
	_check(
		bool(store.commit({"foreign": {"pilot_callsign": "MUDDS"}}, 0, "seed").accepted),
		"foreign user data is seeded before the race transaction"
	)

	var first := await _make_runtime(store)
	var first_binding := first.binding as NearbySectorActivityBinding
	var first_flow := first.flow as GameFlow
	var bound := first_flow.bind_cinder_race_best_persistence(first_binding)
	var reward_configured := first_binding.configure_station_defense_reward(
		Callable(self, &"_accept_reward")
	)
	var completed := _complete_race(first_binding, 8.0)
	var generation := int(completed.get("activity_generation", 0))
	var reward := first_binding.request_race_reward(generation)
	var duplicate := first_binding.request_race_reward(generation)
	var stored := store.get_snapshot()
	var persisted := first_binding.get_cinder_race_best_persistence_snapshot()
	_check(
		bool(bound.accepted) and bool(reward_configured.accepted)
			and completed.state_id == &"completed" and bool(reward.accepted)
			and not bool(duplicate.accepted) and _reward_calls == 1,
		"one authoritative completion reaches the existing reward receipt seam exactly once"
	)
	_check(
		(stored.foreign as Dictionary).pilot_callsign == "MUDDS"
			and is_equal_approx(float((persisted.best_result as Dictionary).time_seconds), 8.0)
			and not bool(((persisted.best_result as Dictionary).reward_receipt as Dictionary).replay_allowed),
		"the best summary and non-replayable receipt merge without replacing foreign data"
	)
	await _retire_runtime(first)

	var reloaded_store := StoreScript.new("memory://cinder-race-best.json", filesystem)
	var second := await _make_runtime(reloaded_store)
	var second_binding := second.binding as NearbySectorActivityBinding
	var second_flow := second.flow as GameFlow
	var rebound := second_flow.bind_cinder_race_best_persistence(second_binding)
	second_binding.configure_station_defense_reward(Callable(self, &"_accept_reward"))
	var restored := second_binding.get_snapshot().race as Dictionary
	var hud := second.hud as GameHUD
	var view := hud.set_nearby_activity_snapshot(second_binding.get_snapshot())
	var card := _race_card(view)
	var world_state := (second.cluster as NearbySectorCluster).get_race_gate_presentation_state()
	var replay := second_binding.request_race_reward(int(restored.activity_generation))
	_check(
		bool(rebound.accepted) and restored.state_id == &"idle"
			and not bool(restored.running) and float(restored.last_time_seconds) < 0.0
			and is_equal_approx(float(restored.best_time_seconds), 8.0)
			and bool(restored.best_result_persisted) and bool(restored.best_reward_consumed),
		"reload restores the best result only, never the completed or current run"
	)
	_check(
		"BEST 8.00s" in str((card.race_feedback as Dictionary).summary)
			and bool(world_state.best_result_persisted)
			and is_equal_approx(float(world_state.best_time_seconds), 8.0),
		"the retained HUD row and retained world presentation receive the restored best"
	)
	_check(
		not bool(replay.accepted) and _reward_calls == 1
			and int(reloaded_store.get_generation()) == int(store.get_generation()),
		"a restored summary cannot replay reward authority or create another write"
	)

	second_binding.start_race()
	second_binding.advance_race(1.0)
	var incomplete := second_binding.get_snapshot().race as Dictionary
	_check(
		incomplete.state_id == &"countdown"
			and is_equal_approx(float(incomplete.best_time_seconds), 8.0)
			and int(reloaded_store.get_generation()) == int(store.get_generation()),
		"an incomplete replacement run remains session-scoped and does not overwrite the best"
	)
	await _retire_runtime(second)

	for failure in _failures:
		push_error(failure)
	print("CINDER_RACE_BEST_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _make_runtime(store: UserDataStore) -> Dictionary:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var flow := GameFlowScript.new() as GameFlow
	flow.set("_runtime_settings_user_data_store", store)
	return {
		"cluster": cluster,
		"binding": cluster.get_node(^"ActivityBinding"),
		"hud": hud,
		"flow": flow,
	}


func _complete_race(binding: NearbySectorActivityBinding, elapsed: float) -> Dictionary:
	binding.start_race()
	binding.advance_race(NearbySectorActivityBinding.CINDER_RACE_COUNTDOWN_SECONDS)
	binding.advance_race(elapsed)
	for index in ROUTE.get_checkpoint_count():
		binding.submit_race_position(ROUTE.get_checkpoint_position(index))
	return binding.get_snapshot().race as Dictionary


func _race_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == \
				NearbySectorActivityBinding.RACE_ACTIVITY_ID:
			return card
	return {}


func _retire_runtime(runtime: Dictionary) -> void:
	(runtime.cluster as Node).queue_free()
	(runtime.hud as Node).queue_free()
	(runtime.flow as Object).free()
	for _frame in 3:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
