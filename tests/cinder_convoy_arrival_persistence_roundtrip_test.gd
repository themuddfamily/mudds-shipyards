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
		"reason": &"caller_reward_receipt_accepted",
		"activity_id": request.get("activity_id", &""),
		"reward_id": request.get("reward_id", &""),
	}


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-convoy-arrival.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic store loads")
	_check(
		bool(store.commit({"foreign": {"pilot_callsign": "MUDDS"}}, 0, "seed").accepted),
		"foreign user data is seeded before safe arrival"
	)

	var first := await _make_runtime(store)
	var first_binding := first.binding as NearbySectorActivityBinding
	var first_host := first.host as CinderConvoyEscortHost
	var bound := (first.flow as GameFlow).bind_cinder_convoy_arrival_persistence(
		first_binding
	)
	var reward_bound := first_binding.configure_station_defense_reward(
		Callable(self, &"_accept_reward")
	)
	var completed := _complete_convoy(first_binding, first_host)
	var generation := int(completed.get("generation", 0))
	var reward := first_binding.request_convoy_reward(generation)
	var duplicate := first_binding.request_convoy_reward(generation)
	var persistence := first_binding.get_cinder_convoy_arrival_persistence_snapshot()
	var arrival := persistence.get("arrival", {}) as Dictionary
	_check(
		bool(bound.accepted) and bool(reward_bound.accepted)
			and completed.state_id == &"completed" and bool(reward.accepted)
			and not bool(duplicate.accepted) and _reward_calls == 1
			and int(store.get_generation()) == 2,
		"one authoritative safe arrival and exact reward handoff commit once"
	)
	_check(
		(store.get_snapshot().foreign as Dictionary).pilot_callsign == "MUDDS"
			and arrival.terminal_result == "safely_arrived"
			and int(arrival.leg_count) == 4
			and not bool((arrival.reward_receipt as Dictionary).granted)
			and not bool((arrival.reward_receipt as Dictionary).replay_allowed)
			and not arrival.has("generation") and not arrival.has("entity_position")
			and not arrival.has("movement_distance") and not arrival.has("combat"),
		"the non-granting receipt merges without replacing foreign user data"
	)
	await _retire(first)

	var reloaded_store := StoreScript.new(
		"memory://cinder-convoy-arrival.json", filesystem
	)
	var second := await _make_runtime(reloaded_store)
	var second_binding := second.binding as NearbySectorActivityBinding
	var second_host := second.host as CinderConvoyEscortHost
	var rebound := (second.flow as GameFlow).bind_cinder_convoy_arrival_persistence(
		second_binding
	)
	second_binding.configure_station_defense_reward(Callable(self, &"_accept_reward"))
	var restored := (
		(second_binding.get_snapshot().host as Dictionary).activity as Dictionary
	)
	var live := (second_host.get_snapshot().activity as Dictionary)
	var view := (second.hud as GameHUD).set_nearby_activity_snapshot(
		second_binding.get_snapshot()
	)
	var card := _convoy_card(view)
	var feedback := card.get("convoy_feedback", {}) as Dictionary
	var formation := second_host.get_snapshot().visual_feedback as Dictionary
	var replay := second_binding.request_convoy_reward(int(restored.generation))
	_check(
		bool(rebound.accepted) and restored.state_id == &"completed"
			and int(restored.generation) == 0 and bool(restored.arrival_persisted)
			and int(restored.completed_leg_count) == int(restored.leg_count)
			and not bool(restored.reward_pending),
		"reload restores safe-arrival completion into detached presentation only"
	)
	_check(
		live.state_id == &"idle" and int(live.generation) == 0
			and int(second_host.get_snapshot().physics_tick_count) == 0
			and int(second_host.get_snapshot().sample_publication_count) == 0
			and is_zero_approx(float(second_host.get_snapshot().movement_distance)),
		"reload restores no live activity, samples, or convoy movement"
	)
	_check(
		feedback.threat_id == &"secured"
			and "ENGINES SAFE" in str(feedback.summary)
			and "FORMATION SECURED" in str(feedback.summary)
			and formation.geometry_state == &"convoy_complete"
			and formation.engine_state == &"safe"
			and formation.formation_state == &"secured"
			and formation.arrival_response_id == &"engines_safe_formation_secured"
			and int(formation.arrival_response_serial) == 1
			and bool(formation.restored_terminal_presentation),
		"retained HUD and static convoy formation return in safe-arrival state"
	)
	_check(
		not bool(replay.accepted) and _reward_calls == 1
			and int(reloaded_store.get_generation()) == 2,
		"restored completion cannot replay the reward handoff or write again"
	)

	var fresh := second_binding.start_convoy()
	second_binding.advance_convoy(
		0.25, second_host.get_snapshot().entity_position as Vector3
	)
	var active := (
		(second_binding.get_snapshot().host as Dictionary).activity as Dictionary
	)
	var live_formation := second_host.get_snapshot().visual_feedback as Dictionary
	_check(
		bool(fresh.accepted) and active.state_id == &"active"
			and not bool(active.get("arrival_persisted", false))
			and live_formation.geometry_state == &"formation_stable"
			and not bool(live_formation.arrival_response_active)
			and not bool(live_formation.restored_terminal_presentation)
			and int(reloaded_store.get_generation()) == 2,
		"a fresh incomplete escort is session-scoped and supersedes restored display"
	)
	await _retire(second)

	var third_store := StoreScript.new("memory://cinder-convoy-arrival.json", filesystem)
	var third := await _make_runtime(third_store)
	var third_binding := third.binding as NearbySectorActivityBinding
	(third.flow as GameFlow).bind_cinder_convoy_arrival_persistence(third_binding)
	var stable := ((third_binding.get_snapshot().host as Dictionary).activity as Dictionary)
	_check(
		stable.state_id == &"completed" and bool(stable.arrival_persisted)
			and int(stable.generation) == 0 and int(third_store.get_generation()) == 2,
		"later reload discards incomplete progress and retains the terminal receipt"
	)
	await _retire(third)

	for failure in _failures:
		push_error(failure)
	print("CINDER_CONVOY_ARRIVAL_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _make_runtime(store: UserDataStore) -> Dictionary:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var flow := GameFlowScript.new() as GameFlow
	flow.set("_runtime_settings_user_data_store", store)
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	return {
		"cluster": cluster,
		"binding": binding,
		"host": binding.get("_host"),
		"hud": hud,
		"flow": flow,
	}


func _complete_convoy(
		binding: NearbySectorActivityBinding, host: CinderConvoyEscortHost
	) -> Dictionary:
	binding.start_convoy()
	var budget := 100
	while (host.get_snapshot().activity as Dictionary).state_id == &"active" \
			and budget > 0:
		binding.advance_convoy(0.25, host.get_snapshot().entity_position as Vector3)
		budget -= 1
	return host.get_snapshot().activity as Dictionary


func _convoy_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == \
				NearbySectorActivityBinding.ACTIVITY_ID:
			return card
	return {}


func _retire(runtime: Dictionary) -> void:
	(runtime.cluster as Node).queue_free()
	(runtime.hud as Node).queue_free()
	(runtime.flow as Object).free()
	for _frame in 3:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
