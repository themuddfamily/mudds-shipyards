extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://cinder-streamed-berth-binding-settings.json"
const COMMON_AUTHORITY_KEYS := [
	"renderer",
	"gameplay",
	"streaming",
	"save",
	"network",
	"physics",
	"world_generation",
	"terrain_generation",
	"collision_generation",
	"origin_shift",
	"weather_clock",
	"audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"scene_tree_mutation",
	"berth_lease",
	"reservation",
	"occupancy",
	"ship_token",
	"landing",
	"ship_movement",
	"streaming_decision",
	"cargo",
	"route",
	"reward",
	"ui",
]

var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

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
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(game != null, "production Main instantiates with the streamed berth binding")
	if game == null:
		_finish()
		return
	_check(
		game.configure_runtime_settings_persistence(
			store,
			"memory://cinder-streamed-berth-binding-legacy.cfg"
		),
		"production fixture injects isolated settings before Main startup"
	)
	root.add_child(game)
	# This test drives the real coordinator explicitly. Disabling GameFlow's
	# physics sampler prevents its distance policy from racing those requests.
	game.set_physics_process(false)
	await process_frame
	await process_frame

	var binding := game.get_node_or_null(
		^"CinderStreamedShipBerthBinding"
	) as CinderStreamedShipBerthBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var coordinator := (
		bootstrap.get_node_or_null(^"WorldStreamingCoordinator")
		as WorldStreamingCoordinator
		if bootstrap != null
		else null
	)
	_check(
		binding != null and bootstrap != null and world != null and coordinator != null,
		"Main owns the binding beside the existing bootstrap, coordinator, and world"
	)
	if binding == null or bootstrap == null or world == null or coordinator == null:
		await _cleanup(game)
		_finish()
		return

	var resident_nodes := _resident_node_identities(world)
	_test_resident_only_startup(game, binding, bootstrap, coordinator, world)
	await _test_zero_berth_load_and_reentry(
		game, binding, bootstrap, coordinator, world, resident_nodes
	)
	await _test_unload_reload_generations(
		game, binding, bootstrap, coordinator, world, resident_nodes
	)
	_test_detached_reports_and_authority(binding)

	await _cleanup(game)
	_finish()


func _test_resident_only_startup(
	game: GameFlow,
	binding: CinderStreamedShipBerthBinding,
	bootstrap: CinderStreamingBootstrap,
	coordinator: WorldStreamingCoordinator,
	world: ShipyardWorld
	) -> void:
	var report := binding.audit()
	var snapshot := report.get("snapshot", {}) as Dictionary
	var overlay := snapshot.get("overlay", {}) as Dictionary
	var merged := binding.get_merged_berth_snapshot()
	print(
		"CINDER_STREAMED_BERTH_BINDING_STARTUP: ",
		snapshot.get("configuration_result", {}),
		" world_ids=", world.get_berth_ids(),
		" expected=", CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS
	)
	_check(
		bool(report.get("valid", false))
		and bool(snapshot.get("configured", false))
		and int(snapshot.get("configuration_attempt_count", -1)) == 1
		and int(snapshot.get("configuration_success_count", -1)) == 1
		and int(report.get("binding_count", -1)) == 1
		and game.find_children(
			"*", "CinderStreamedShipBerthBinding", true, false
		).size() == 1,
		"Main configures exactly one lifetime binding before streaming begins"
	)
	_check(
		int(snapshot.get("bootstrap_instance_id", 0)) == bootstrap.get_instance_id()
		and int(snapshot.get("coordinator_instance_id", 0)) == coordinator.get_instance_id()
		and int(snapshot.get("world_instance_id", 0)) == world.get_instance_id()
		and int(overlay.get("coordinator_instance_id", 0)) == coordinator.get_instance_id()
		and int((coordinator.audit()).get("load_request_count", -1)) == 0,
		"binding freezes exact production identities before the first load request"
	)
	_check(
		_sorted_ids(world.get_berth_ids())
		== CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS
		and merged.get("berth_ids")
		== CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS
		and int((merged.get("entries", []) as Array).size()) == 5
		and int(overlay.get("active_location_count", -1)) == 0
		and int(overlay.get("active_berth_count", -1)) == 0,
		"resident-only startup exposes exactly the unchanged five-berth world roster"
	)
	_check(
		int(snapshot.get("registration_signal_count", -1)) == 0
		and int(snapshot.get("retirement_signal_count", -1)) == 0
		and int(overlay.get("loaded_observation_count", -1)) == 0
		and int(overlay.get("unloaded_observation_count", -1)) == 0,
		"configuration emits no synthetic stream observation or roster signal"
	)
	_check(
		game.find_children("*", "CinderCargoAccess", true, false).is_empty()
		and game.find_children("*", "CargoDestinationTerminal", true, false).is_empty(),
		"Stage B places no Cinder access or cargo-terminal content"
	)


func _test_zero_berth_load_and_reentry(
	game: GameFlow,
	binding: CinderStreamedShipBerthBinding,
	bootstrap: CinderStreamingBootstrap,
	coordinator: WorldStreamingCoordinator,
	world: ShipyardWorld,
	resident_nodes: Dictionary
	) -> void:
	var request := coordinator.request_load(CinderStreamingBootstrap.LOCATION_ID)
	_check(
		bool(request.get("accepted", false)) and int(request.get("generation", -1)) == 1,
		"the real Cinder coordinator accepts its first generation after binding"
	)
	var cluster := await _wait_for_cluster(bootstrap)
	_check(
		cluster != null
		and int(cluster.get_meta(&"world_location_generation", -1)) == 1
		and cluster.find_children("*", "ShipBerth", true, false).is_empty(),
		"the real generation-1 Cinder scene truthfully contains zero ShipBerths"
	)
	var loaded := binding.get_snapshot()
	var overlay := loaded.get("overlay", {}) as Dictionary
	var last_load := overlay.get("last_loaded_observation", {}) as Dictionary
	_check(
		int(overlay.get("loaded_observation_count", -1)) == 1
		and last_load.get("reason") == &"no_ship_berths"
		and not bool(last_load.get("accepted", true))
		and int(last_load.get("load_generation", -1)) == 1
		and int(overlay.get("active_location_count", -1)) == 0
		and int(overlay.get("active_berth_count", -1)) == 0
		and int(loaded.get("registration_signal_count", -1)) == 0,
		"generation 1 is observed exactly once and fails closed without a fake roster"
	)
	_check(
		binding.get_merged_berth_snapshot().get("berth_ids")
		== CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS
		and _resident_nodes_match(world, resident_nodes)
		and bool(binding.audit().get("valid", false)),
		"zero-berth load preserves the exact five resident identities and valid audit"
	)
	var unknown := binding.lookup_streamed_berth_record(&"cinder_cargo_jovian_berth")
	_check(
		not bool(unknown.get("found", true))
		and binding.resolve_streamed_berth_node(
			&"cinder_reach", 1, cluster.get_instance_id(),
			&"cinder_cargo_jovian_berth", 1
		) == null,
		"no live Cinder berth capability is invented for an absent access module"
	)

	var binding_id := binding.get_instance_id()
	var bootstrap_id := bootstrap.get_instance_id()
	var coordinator_id := coordinator.get_instance_id()
	var world_id := world.get_instance_id()
	var cluster_id := cluster.get_instance_id()
	var before_detach := binding.get_snapshot()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await process_frame
	var detached := binding.get_snapshot()
	_check(
		not bool(detached.get("inside_tree", true))
		and int(detached.get("configuration_attempt_count", -1)) == 1
		and int(detached.get("configuration_success_count", -1)) == 1
		and int((detached.get("overlay", {}) as Dictionary).get(
			"loaded_observation_count", -1
		)) == 1
		and int(detached.get("registration_signal_count", -1)) == 0
		and bootstrap.get_loaded_instance() == cluster,
		"whole-Main detach retains the loaded generation and freezes observations"
	)
	parent.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var reentered := binding.get_snapshot()
	_check(
		binding.get_instance_id() == binding_id
		and bootstrap.get_instance_id() == bootstrap_id
		and coordinator.get_instance_id() == coordinator_id
		and world.get_instance_id() == world_id
		and bootstrap.get_loaded_instance() == cluster
		and cluster.get_instance_id() == cluster_id
		and int(reentered.get("configuration_attempt_count", -1)) == 1
		and int(reentered.get("registration_signal_count", -1)) == 0
		and int((reentered.get("overlay", {}) as Dictionary).get(
			"loaded_observation_count", -1
		)) == 1
		and int(reentered.get("tree_exit_count", -1))
		== int(before_detach.get("tree_exit_count", -2)) + 1
		and bool(binding.audit().get("valid", false)),
		"whole-Main re-entry preserves every identity without reconfigure or replay"
	)


func _test_unload_reload_generations(
	_game: GameFlow,
	binding: CinderStreamedShipBerthBinding,
	bootstrap: CinderStreamingBootstrap,
	coordinator: WorldStreamingCoordinator,
	world: ShipyardWorld,
	resident_nodes: Dictionary
	) -> void:
	var first_cluster := bootstrap.get_loaded_instance()
	var first_instance_id := first_cluster.get_instance_id()
	var first_ref: WeakRef = weakref(first_cluster)
	var unload := coordinator.request_unload(CinderStreamingBootstrap.LOCATION_ID)
	_check(
		bool(unload.get("accepted", false)) and int(unload.get("generation", -1)) == 2,
		"coordinator commits exact retirement generation 2"
	)
	await process_frame
	await process_frame
	var unloaded := binding.get_snapshot()
	var unloaded_overlay := unloaded.get("overlay", {}) as Dictionary
	var last_unload := unloaded_overlay.get("last_unloaded_observation", {}) as Dictionary
	_check(
		bootstrap.get_loaded_instance() == null
		and first_ref.get_ref() == null
		and int(unloaded_overlay.get("unloaded_observation_count", -1)) == 1
		and last_unload.get("reason") == &"unknown_location"
		and int(last_unload.get("load_generation", -1)) == 1
		and int(last_unload.get("retirement_generation", -1)) == 2
		and int(unloaded.get("retirement_signal_count", -1)) == 0
		and (unloaded_overlay.get("location_tombstones", []) as Array).is_empty(),
		"zero-roster unload is observed once without a fabricated retirement signal or tombstone"
	)

	var reload := coordinator.request_load(CinderStreamingBootstrap.LOCATION_ID)
	_check(
		bool(reload.get("accepted", false)) and int(reload.get("generation", -1)) == 3,
		"coordinator advances the real reload to generation 3"
	)
	var second_cluster := await _wait_for_cluster(bootstrap)
	var reloaded := binding.get_snapshot()
	var reloaded_overlay := reloaded.get("overlay", {}) as Dictionary
	var second_last_load := reloaded_overlay.get(
		"last_loaded_observation", {}
	) as Dictionary
	_check(
		second_cluster != null
		and second_cluster.get_instance_id() != first_instance_id
		and int(second_cluster.get_meta(&"world_location_generation", -1)) == 3
		and int(reloaded_overlay.get("loaded_observation_count", -1)) == 2
		and second_last_load.get("reason") == &"no_ship_berths"
		and int(second_last_load.get("load_generation", -1)) == 3
		and int(reloaded.get("registration_signal_count", -1)) == 0
		and int(reloaded.get("retirement_signal_count", -1)) == 0
		and _resident_nodes_match(world, resident_nodes)
		and bool(binding.audit().get("valid", false)),
		"reload observes the replacement generation once with resident identity unchanged"
	)
	var second_unload := coordinator.request_unload(
		CinderStreamingBootstrap.LOCATION_ID
	)
	_check(
		bool(second_unload.get("accepted", false))
		and int(second_unload.get("generation", -1)) == 4,
		"replacement generation retires at exact generation 4"
	)
	await process_frame
	await process_frame
	var final := binding.get_snapshot()
	var final_overlay := final.get("overlay", {}) as Dictionary
	var coordinator_audit := coordinator.audit()
	_check(
		int(final_overlay.get("loaded_observation_count", -1)) == 2
		and int(final_overlay.get("unloaded_observation_count", -1)) == 2
		and int(final.get("registration_signal_count", -1)) == 0
		and int(final.get("retirement_signal_count", -1)) == 0
		and int(coordinator_audit.get("load_request_count", -1)) == 2
		and int(coordinator_audit.get("unload_count", -1)) == 2
		and binding.get_merged_berth_snapshot().get("berth_ids")
		== CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS
		and _resident_nodes_match(world, resident_nodes)
		and bool(binding.audit().get("valid", false)),
		"two load/unload generations produce exactly two observations and zero duplicate roster signals"
	)


func _test_detached_reports_and_authority(
	binding: CinderStreamedShipBerthBinding
	) -> void:
	var snapshot := binding.get_snapshot()
	var report := binding.audit()
	_check(
		_exact_false_keys(report.get("authority"), COMMON_AUTHORITY_KEYS)
		and _exact_false_keys(
			report.get("adjacent_authority"), ADJACENT_AUTHORITY_KEYS
		),
		"binding audit publishes exact common and adjacent zero-authority rosters"
	)
	_check(
		report.get("zero_berth_load_policy")
		== &"typed_no_ship_berths_no_registration"
		and report.get("zero_berth_unload_policy")
		== &"typed_unknown_location_no_retirement"
		and not binding.is_processing()
		and not binding.is_physics_processing(),
		"zero-roster semantics are explicit and the binding owns no process cadence"
	)
	_check(
		not _contains_live_capability(snapshot)
		and not _contains_live_capability(report)
		and not _contains_live_capability(binding.get_merged_berth_snapshot()),
		"all binding reports and merged reads contain no live capabilities"
	)
	var snapshot_json := JSON.stringify(snapshot)
	var tombstone_count := (
		((snapshot.get("overlay", {}) as Dictionary).get(
			"location_tombstones", []
		) as Array).size()
	)
	(snapshot.get("resident_berth_ids", []) as Array).clear()
	(snapshot.get("authority", {}) as Dictionary)["gameplay"] = true
	(snapshot.get("overlay", {}) as Dictionary).clear()
	var fresh := binding.get_snapshot()
	_check(
		(fresh.get("resident_berth_ids", []) as Array).size() == 5
		and not bool((fresh.get("authority", {}) as Dictionary).get("gameplay", true))
		and int(((fresh.get("overlay", {}) as Dictionary).get(
			"location_tombstones", []
		) as Array).size()) == tombstone_count
		and JSON.stringify(fresh) == snapshot_json,
		"nested caller mutation cannot change deterministic binding or overlay state"
	)


func _resident_node_identities(world: ShipyardWorld) -> Dictionary:
	var result := {}
	for berth_id in CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS:
		var berth := world.get_berth_node(berth_id)
		result[berth_id] = berth.get_instance_id() if berth != null else 0
	return result


func _resident_nodes_match(world: ShipyardWorld, expected: Dictionary) -> bool:
	if _sorted_ids(world.get_berth_ids()) \
			!= CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS:
		return false
	for berth_id in CinderStreamedShipBerthBinding.RESIDENT_BERTH_IDS:
		var berth := world.get_berth_node(berth_id)
		if berth == null or berth.get_instance_id() != int(expected.get(berth_id, 0)):
			return false
	return true


func _sorted_ids(source: Array[StringName]) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(source)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a) < str(b)
	)
	return ids


func _wait_for_cluster(bootstrap: CinderStreamingBootstrap) -> Node3D:
	for _frame in 30:
		var cluster := bootstrap.get_loaded_instance()
		if cluster != null:
			return cluster
		await process_frame
	_check(false, "real Cinder cluster loads within thirty frames")
	return null


func _exact_false_keys(value: Variant, expected_keys: Array) -> bool:
	if value is not Dictionary:
		return false
	var dictionary := value as Dictionary
	if dictionary.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not dictionary.has(key) \
				or dictionary[key] is not bool \
				or bool(dictionary[key]):
			return false
	return true


func _contains_live_capability(value: Variant) -> bool:
	if value is Node or value is Resource or value is WeakRef \
			or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if _contains_live_capability(key) \
					or _contains_live_capability((value as Dictionary)[key]):
				return true
	elif value is Array:
		for entry in value as Array:
			if _contains_live_capability(entry):
				return true
	return false


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"CINDER_STREAMED_SHIP_BERTH_BINDING_TEST_OK: %d assertions"
			% _assertions
		)
		quit(0)
	else:
		print(
			"CINDER_STREAMED_SHIP_BERTH_BINDING_TEST_FAILED: %d failures / %d assertions"
			% [_failures.size(), _assertions]
		)
		quit(1)
