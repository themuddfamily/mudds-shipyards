extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	var fail_writes := false
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_writes: return ERR_CANT_CREATE
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
	await _test_failed_save_recovery()
	await _test_real_file_reset_preserves_pending_capacity()
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


func _test_failed_save_recovery() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-mining-retry.json", filesystem)
	store.load()
	var runtime := await _make_runtime(store)
	var binding := runtime.binding as NearbySectorActivityBinding
	(runtime.flow as GameFlow).bind_cinder_mining_capacity_persistence(binding)
	binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	binding.advance_mining_activity(CinderMiningPlatformActivity.EXTRACTION_SECONDS)
	filesystem.fail_writes = true
	var failed := binding.request_mining_reward()
	var duplicate := binding.request_mining_reward()
	var retryable := binding.get_activity_snapshot(&"mining")
	_check(bool(failed.accepted) and not bool(failed.capacity_persisted)
		and not bool(duplicate.accepted) and duplicate.reason == &"reward_already_requested"
		and bool(retryable.get("persistence_retry_available", false))
		and int(store.get_generation()) == 0,
		"a rejected duplicate keeps the failed terminal receipt and its save retry available")
	var failed_retry := binding.retry_mining_capacity_persistence()
	_check(not bool(failed_retry.accepted)
		and bool(binding.get_activity_snapshot(&"mining").get("persistence_retry_available", false))
		and int(store.get_generation()) == 0,
		"another failed write preserves the same completed extraction for later recovery")
	filesystem.fail_writes = false
	var recovered := binding.retry_mining_capacity_persistence()
	var repeated_retry := binding.retry_mining_capacity_persistence()
	_check(bool(recovered.accepted) and bool(recovered.get("capacity_persisted", false))
		and not bool(repeated_retry.accepted)
		and bool(binding.get_activity_snapshot(&"mining").get("capacity_persisted", false))
		and int(store.get_generation()) == 1,
		"recovery commits once and a repeated save retry cannot write the terminal receipt again")
	await _retire(runtime)

	var reloaded_store := StoreScript.new("memory://cinder-mining-retry.json", filesystem)
	var reentered := await _make_runtime(reloaded_store)
	var reentered_binding := reentered.binding as NearbySectorActivityBinding
	(reentered.flow as GameFlow).bind_cinder_mining_capacity_persistence(reentered_binding)
	var restored := reentered_binding.get_activity_snapshot(&"mining")
	var replay := reentered_binding.request_mining_reward()
	_check(bool(restored.get("capacity_persisted", false)) and not bool(replay.accepted)
		and int(reloaded_store.get_generation()) == 1,
		"a recovered capacity receipt survives world reentry without another reward or write")
	reentered_binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	reentered_binding.advance_mining_activity(1.0)
	var aborted := reentered_binding.advance_mining_activity_from_caller_sample(
		0.1, CinderMiningPlatformActivity.APPROACH_ANCHOR + Vector3(100.0, 0.0, 0.0))
	var stale_retry := reentered_binding.retry_mining_capacity_persistence()
	var restarted := reentered_binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	_check(aborted.reason == &"extraction_interrupted" and not bool(stale_retry.accepted)
		and bool(restarted.accepted) and int(restarted.generation) == 2
		and is_zero_approx(float(restarted.elapsed_seconds))
		and int(reloaded_store.get_generation()) == 1,
		"aborting a later extraction prevents stale receipt retry and starts a fresh empty generation")
	await _retire(reentered)


## Mine through actual Main and its streamed binding. A real directory at the
## atomic store's temporary path sustains rejected writes, rather than mocking
## an accepted reset or inventing a terminal reward request.
func _test_real_file_reset_preserves_pending_capacity() -> void:
	var directory := "/tmp/mudds-mining-reset-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var profile_path := directory.path_join("profile.json")
	var store := StoreScript.new(profile_path)
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store, directory.path_join("legacy.cfg"))
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var cluster := await _load_main_mining_cluster(game)
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	game.bind_cinder_mining_capacity_persistence(binding)
	var craft := game.get_flyable_ships()[1] as HeroShip
	game.active_ship = craft
	craft.global_position = CinderMiningPlatformActivity.APPROACH_ANCHOR
	var sample := {"available": true, "actor_kind": &"ship",
		"actor_instance_id": craft.get_instance_id(), "position": craft.global_position}
	_mining_intent(game, &"start_requested")
	var first_completion := game.call(&"_advance_cinder_mining_extraction",
		CinderMiningPlatformActivity.EXTRACTION_SECONDS, sample) as Dictionary
	var first_receipt := first_completion.get("reward_result", {}) as Dictionary
	var first_generation := int(binding.get_activity_snapshot(&"mining").generation)
	_mining_intent(game, &"reset_requested")
	_check(bool(first_receipt.get("capacity_persisted", false))
		and binding.get_activity_snapshot(&"mining").state_id == &"reset",
		"a genuine terminal capacity receipt commits before an ordinary Main reset")
	var saved_bytes := FileAccess.get_file_as_bytes(profile_path)
	DirAccess.make_dir_absolute(profile_path + ".tmp")
	_mining_intent(game, &"start_requested")
	game.call(&"_advance_cinder_mining_extraction", 2.0, sample)
	var active := binding.get_activity_snapshot(&"mining")
	_check(active.state_id == &"active" and int(active.generation) > first_generation
		and is_equal_approx(float(active.elapsed_seconds), 2.0)
		and FileAccess.get_file_as_bytes(profile_path) == saved_bytes,
		"a new legitimate extraction remains transient while the actual atomic write path is blocked")
	var completed := game.call(&"_advance_cinder_mining_extraction", 4.0, sample) as Dictionary
	var request := completed.get("reward_result", {}) as Dictionary
	var pending := binding.get_activity_snapshot(&"mining")
	var pending_generation := int(pending.generation)
	var profile_bytes := FileAccess.get_file_as_bytes(profile_path)
	var terminal_request := (request.get("reward_request", {}) as Dictionary).duplicate(true)
	_check(bool(request.accepted) and not bool(request.capacity_persisted)
		and bool(pending.get("persistence_retry_available", false))
		and int(terminal_request.get("generation", 0)) == pending_generation,
		"the genuine completed extraction keeps its one non-granting terminal capacity request after rejected publication")
	_mining_intent(game, &"reset_requested")
	var replaced := binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	_mining_intent(game, &"start_requested")
	var retained := binding.get_activity_snapshot(&"mining")
	var last_request := (binding.get("_last_mining_reward_result") as Dictionary).get("reward_request", {}) as Dictionary
	_check(not bool(replaced.accepted) and retained.state_id == &"complete"
		and int(retained.generation) == pending_generation
		and bool(retained.get("persistence_retry_available", false))
		and last_request == terminal_request
		and FileAccess.get_file_as_bytes(profile_path) == profile_bytes
		and "START TO RETRY" in str(game.hud.get_activity_objective_report().get("text", "")),
		"ordinary Reset, binding restart and still-rejected Start cannot discard or replace the pending mining receipt")
	DirAccess.remove_absolute(profile_path + ".tmp")
	_mining_intent(game, &"start_requested")
	var recovered := binding.get_activity_snapshot(&"mining")
	var recovered_generation := store.get_generation()
	var repeated := binding.retry_mining_capacity_persistence()
	var duplicate := binding.request_mining_reward()
	_check(bool(recovered.get("capacity_persisted", false))
		and int(recovered.generation) == pending_generation
		and not bool(repeated.accepted) and not bool(duplicate.accepted)
		and store.get_generation() == recovered_generation
		and not bool(((binding.get_cinder_mining_capacity_persistence_snapshot().capacity as Dictionary).reward_receipt as Dictionary).granted),
		"ordinary Start records exactly the retained extraction after recovery without replaying or granting its request")
	game.queue_free()
	for _frame in 3: await process_frame
	var fresh_store := StoreScript.new(profile_path)
	var fresh := MAIN_SCENE.instantiate() as GameFlow
	fresh.configure_runtime_settings_persistence(fresh_store, directory.path_join("legacy.cfg"))
	root.add_child(fresh)
	await process_frame
	fresh.set_physics_process(false)
	var fresh_cluster := await _load_main_mining_cluster(fresh)
	var fresh_binding := fresh_cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	fresh.bind_cinder_mining_capacity_persistence(fresh_binding)
	var before_replay := FileAccess.get_file_as_bytes(profile_path)
	var replay := fresh_binding.request_mining_reward()
	_check(bool(fresh_binding.get_activity_snapshot(&"mining").get("capacity_persisted", false))
		and not bool(replay.accepted) and replay.reason == &"not_complete"
		and FileAccess.get_file_as_bytes(profile_path) == before_replay,
		"fresh Main retains the recovered capacity without reconstructing live extraction or granting another request")
	fresh.queue_free()
	for _frame in 3: await process_frame
	var cleanup := DirAccess.open(directory)
	if cleanup != null:
		for filename in cleanup.get_files(): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)


func _mining_intent(game: GameFlow, action: StringName) -> void:
	game.call(&"_on_hud_nearby_activity_intent_requested", {
		"activity_id": CinderMiningPlatformActivity.ACTIVITY_ID, "reason": action,
	})


func _load_main_mining_cluster(game: GameFlow) -> NearbySectorCluster:
	game.get_node(^"CinderStreamingProductionBinding").set_physics_process(false)
	var bootstrap := game.get_node(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	for _frame in 60:
		if bootstrap.get_loaded_instance() != null:
			return bootstrap.get_loaded_instance() as NearbySectorCluster
		await process_frame
	_check(false, "actual Main loads mining through the production Cinder bootstrap")
	return null


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
