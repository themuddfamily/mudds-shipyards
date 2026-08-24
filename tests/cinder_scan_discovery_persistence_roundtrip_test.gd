extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")
const ScanActivityScript := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")
const ScanPersistenceScript := preload("res://scripts/persistence/cinder_scan_discovery_persistence.gd")

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


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_terminal_receipt_gate()

	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-scan-discovery.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic store loads")
	_check(
		bool(store.commit({"foreign": {"navigation_mode": "survey"}}, 0, "seed").accepted),
		"foreign user data is seeded before the discovery transaction"
	)

	var first := await _make_runtime(store)
	var first_binding := first.binding as NearbySectorActivityBinding
	var first_flow := first.flow as GameFlow
	var bound := first_flow.bind_cinder_scan_discovery_persistence(first_binding)
	var started := first_binding.start_structure_scan(
		CinderAbandonedStructureScanActivity.APPROACH_ANCHOR
	)
	var completed := first_binding.advance_structure_scan(
		CinderAbandonedStructureScanActivity.SCAN_SECONDS
	)
	var receipt := first_binding.request_structure_scan_reward()
	var repeated := first_binding.request_structure_scan_reward()
	var payload := store.get_snapshot()
	var persisted := first_binding.get_cinder_scan_discovery_persistence_snapshot()
	_check(
		bool(bound.accepted) and bool(started.accepted) and bool(completed.accepted)
			and bool(receipt.accepted) and not bool(repeated.accepted)
			and int(store.get_generation()) == 2,
		"one completed authoritative scan commits its terminal receipt exactly once"
	)
	_check(
		(payload.foreign as Dictionary).navigation_mode == "survey"
			and not bool(((persisted.discovery as Dictionary).reward_receipt as Dictionary).replay_allowed)
			and not bool(((persisted.discovery as Dictionary).reward_receipt as Dictionary).granted),
		"the non-granting receipt merges atomically without replacing foreign data"
	)
	await _retire(first)

	var reloaded_store := StoreScript.new("memory://cinder-scan-discovery.json", filesystem)
	var second := await _make_runtime(reloaded_store)
	var second_binding := second.binding as NearbySectorActivityBinding
	var second_flow := second.flow as GameFlow
	var rebound := second_flow.bind_cinder_scan_discovery_persistence(second_binding)
	var restored := second_binding.get_snapshot().structure_scan as Dictionary
	var authority := second_binding.get("_scan_activity") as RefCounted
	var authority_snapshot := authority.call("get_snapshot") as Dictionary
	var hud := second.hud as GameHUD
	var view := hud.set_nearby_activity_snapshot(second_binding.get_snapshot())
	var card := _scan_card(view)
	var receiver := (second.cluster as NearbySectorCluster).get_structure_scan_presentation_state()
	var replay := second_binding.request_structure_scan_reward()
	_check(
		bool(rebound.accepted) and restored.state_id == &"complete"
			and bool(restored.discovery_persisted)
			and not bool(restored.reward_pending)
			and authority_snapshot.state_id == &"idle"
			and int(authority_snapshot.generation) == 0,
		"reload restores completed discovery presentation while scan authority remains idle"
	)
	_check(
		(card.scan_feedback as Dictionary).stage_id == &"discovery_recorded"
			and "DISCOVERY RECORDED" in str((card.scan_feedback as Dictionary).summary)
			and receiver.state_id == &"completed" and bool(receiver.complete_geometry),
		"the retained HUD and physical receiver restore the completed discovery state"
	)
	_check(
		not bool(replay.accepted) and replay.reason == &"not_complete"
			and int(reloaded_store.get_generation()) == 2,
		"the presentation-only receipt cannot replay reward or write again"
	)

	var fresh := second_binding.start_structure_scan(
		CinderAbandonedStructureScanActivity.APPROACH_ANCHOR
	)
	second_binding.advance_structure_scan(1.0)
	var active := second_binding.get_snapshot().structure_scan as Dictionary
	_check(
		bool(fresh.accepted) and active.state_id == &"active"
			and not bool(active.get("discovery_persisted", false))
			and is_equal_approx(float(active.elapsed_seconds), 1.0)
			and int(reloaded_store.get_generation()) == 2,
		"a new incomplete scan stays session-scoped and does not overwrite discovery"
	)
	await _retire(second)

	var third_store := StoreScript.new("memory://cinder-scan-discovery.json", filesystem)
	var third := await _make_runtime(third_store)
	var third_binding := third.binding as NearbySectorActivityBinding
	var third_flow := third.flow as GameFlow
	third_flow.bind_cinder_scan_discovery_persistence(third_binding)
	var stable := third_binding.get_snapshot().structure_scan as Dictionary
	_check(
		stable.state_id == &"complete" and bool(stable.discovery_persisted)
			and is_equal_approx(float(stable.progress_unitless), 1.0)
			and int(third_store.get_generation()) == 2,
		"a later reload discards incomplete progress and retains terminal discovery"
	)
	await _retire(third)

	for failure in _failures:
		push_error(failure)
	print("CINDER_SCAN_DISCOVERY_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _test_terminal_receipt_gate() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-scan-receipt-gate.json", filesystem)
	var persistence := ScanPersistenceScript.new()
	var scan := ScanActivityScript.new()
	var configured := persistence.configure(store, &"cinder_scan_discovery")
	var started := scan.start(ScanActivityScript.APPROACH_ANCHOR)
	var completed := scan.advance_physics(ScanActivityScript.SCAN_SECONDS)
	var receipt := scan.request_reward()
	var snapshot := scan.get_snapshot()
	var saved := persistence.save(snapshot, receipt, "terminal-receipt")
	var reloaded_store := StoreScript.new("memory://cinder-scan-receipt-gate.json", filesystem)
	var reloaded_persistence := ScanPersistenceScript.new()
	var rebound := reloaded_persistence.configure(reloaded_store, &"cinder_scan_discovery")
	var restored := reloaded_persistence.load()
	_check(
		bool(configured.accepted) and bool(started.accepted) and bool(completed.accepted)
			and bool(receipt.accepted) and bool(saved.accepted) and bool(rebound.accepted)
			and bool(restored.accepted) and int(reloaded_store.get_generation()) == 1,
		"one terminal scan receipt restores once through a fresh store and persistence adapter"
	)

	var interrupted_scan := ScanActivityScript.new()
	interrupted_scan.start(ScanActivityScript.APPROACH_ANCHOR)
	interrupted_scan.advance_physics(1.0)
	var interrupted := interrupted_scan.get_snapshot()
	interrupted["state"] = ScanActivityScript.State.COMPLETE
	interrupted["state_id"] = &"complete"
	interrupted["reward_requested"] = true
	var interrupted_receipt := receipt.duplicate(true)
	(interrupted_receipt.reward_request as Dictionary)["generation"] = interrupted.generation
	var zero_generation := snapshot.duplicate(true)
	zero_generation["generation"] = 0
	var zero_generation_receipt := receipt.duplicate(true)
	(zero_generation_receipt.reward_request as Dictionary)["generation"] = 0
	var fractional_generation := snapshot.duplicate(true)
	fractional_generation["generation"] = 1.5
	var fractional_receipt := receipt.duplicate(true)
	(fractional_receipt.reward_request as Dictionary)["generation"] = 1.5
	var stale_receipt := receipt.duplicate(true)
	(stale_receipt.reward_request as Dictionary)["generation"] = int(snapshot.generation) + 1
	_check(
		not bool(persistence.capture(interrupted, interrupted_receipt).accepted)
			and not bool(persistence.capture(zero_generation, zero_generation_receipt).accepted)
			and not bool(persistence.capture(fractional_generation, fractional_receipt).accepted)
			and not bool(persistence.capture(snapshot, stale_receipt).accepted),
		"interrupted, zero, fractional, and stale generations cannot forge a completed discovery"
	)


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


func _scan_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == \
				CinderAbandonedStructureScanActivity.ACTIVITY_ID:
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
