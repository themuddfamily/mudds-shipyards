extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
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
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-mining-capacity.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic store loads")
	_check(bool(store.commit({"foreign": {"pilot_profile": "retained"}}, 0, "seed").accepted),
		"foreign user data is seeded before extraction")

	var first := await _make_runtime(store)
	var first_binding := first.binding as NearbySectorActivityBinding
	var bound := (first.flow as GameFlow).bind_cinder_mining_capacity_persistence(first_binding)
	var started := first_binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	var completed := first_binding.advance_mining_activity(CinderMiningPlatformActivity.EXTRACTION_SECONDS)
	var receipt := first_binding.request_mining_reward()
	var duplicate := first_binding.request_mining_reward()
	var persisted := first_binding.get_cinder_mining_capacity_persistence_snapshot()
	_check(bool(bound.accepted) and bool(started.accepted) and bool(completed.accepted)
		and bool(receipt.accepted) and not bool(duplicate.accepted)
		and int(store.get_generation()) == 2,
		"one full-capacity generation commits its non-granting terminal receipt once")
	_check((store.get_snapshot().foreign as Dictionary).pilot_profile == "retained"
		and not bool(((persisted.capacity as Dictionary).reward_receipt as Dictionary).replay_allowed)
		and not bool(((persisted.capacity as Dictionary).reward_receipt as Dictionary).granted),
		"the capacity receipt merges atomically without replacing foreign data")
	await _retire(first)

	var reloaded_store := StoreScript.new("memory://cinder-mining-capacity.json", filesystem)
	var second := await _make_runtime(reloaded_store)
	var second_binding := second.binding as NearbySectorActivityBinding
	var rebound := (second.flow as GameFlow).bind_cinder_mining_capacity_persistence(second_binding)
	var restored := second_binding.get_snapshot().mining as Dictionary
	var authority := second_binding.get("_mining_activity") as RefCounted
	var live := authority.call("get_snapshot") as Dictionary
	var view := (second.hud as GameHUD).set_nearby_activity_snapshot(second_binding.get_snapshot())
	var card := _mining_card(view)
	var geometry := (second.cluster as NearbySectorCluster).get_mining_activity_presentation_state()
	var replay := second_binding.request_mining_reward()
	_check(bool(rebound.accepted) and int(restored.state) == CinderMiningPlatformActivity.State.COMPLETE
		and bool(restored.capacity_persisted) and not bool(restored.reward_requested)
		and int(live.state) == CinderMiningPlatformActivity.State.IDLE and int(live.generation) == 0,
		"reload restores capacity presentation while extraction authority remains idle")
	_check((card.mining_feedback as Dictionary).stage_id == &"capacity_recorded"
		and "CAPACITY READY" in str((card.mining_feedback as Dictionary).summary)
		and geometry.state_id == &"secured" and bool(geometry.capacity_ready_geometry),
		"retained HUD, full collectors, and widened hopper restore capacity-ready state")
	_check(not bool(replay.accepted) and replay.reason == &"not_complete"
		and int(reloaded_store.get_generation()) == 2,
		"restored capacity cannot replay reward or create another write")

	var fresh := second_binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	second_binding.advance_mining_activity(2.0)
	var active := second_binding.get_snapshot().mining as Dictionary
	_check(bool(fresh.accepted) and int(active.state) == CinderMiningPlatformActivity.State.ACTIVE
		and not bool(active.get("capacity_persisted", false))
		and is_equal_approx(float(active.elapsed_seconds), 2.0)
		and int(reloaded_store.get_generation()) == 2,
		"fresh incomplete extraction remains session-scoped and overrides retained summary")
	await _retire(second)

	var third_store := StoreScript.new("memory://cinder-mining-capacity.json", filesystem)
	var third := await _make_runtime(third_store)
	var third_binding := third.binding as NearbySectorActivityBinding
	(third.flow as GameFlow).bind_cinder_mining_capacity_persistence(third_binding)
	var stable := third_binding.get_snapshot().mining as Dictionary
	_check(int(stable.state) == CinderMiningPlatformActivity.State.COMPLETE
		and bool(stable.capacity_persisted)
		and is_equal_approx(float(stable.elapsed_seconds), float(stable.extraction_seconds))
		and int(third_store.get_generation()) == 2,
		"later reload discards incomplete progress and retains terminal capacity")
	await _retire(third)

	for failure in _failures: push_error(failure)
	print("CINDER_MINING_CAPACITY_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _make_runtime(store: UserDataStore) -> Dictionary:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var flow := GameFlowScript.new() as GameFlow
	flow.set("_runtime_settings_user_data_store", store)
	return {"cluster": cluster, "binding": cluster.get_node(^"ActivityBinding"),
		"hud": hud, "flow": flow}


func _mining_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == CinderMiningPlatformActivity.ACTIVITY_ID:
			return card
	return {}


func _retire(runtime: Dictionary) -> void:
	(runtime.cluster as Node).queue_free(); (runtime.hud as Node).queue_free(); (runtime.flow as Object).free()
	for _frame in 3: await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
