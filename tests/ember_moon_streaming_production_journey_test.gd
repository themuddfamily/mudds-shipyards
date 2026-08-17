extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://ember-streaming-production-settings.json"
const EXPECTED_ASSERTIONS := 21

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
	_check(game != null, "production Main instantiates with the Ember binding")
	if game == null:
		_finish()
		return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://ember-streaming-production-legacy.cfg"
		),
		"production journey isolates settings persistence before startup",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var binding := game.get_node_or_null(
		^"EmberMoonStreamingProductionBinding"
	) as EmberMoonStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"EmberMoonStreamingBootstrap"
	) as EmberMoonStreamingBootstrap
	_check(
		binding != null and bootstrap != null,
		"Main exposes one Ember binding and bootstrap",
	)
	if binding == null or bootstrap == null:
		await _cleanup(game)
		_finish()
		return

	game.set_physics_process(false)
	await _test_composition_and_absolute_observation(game, binding, bootstrap)
	await _test_rebase_preview_and_fail_closed_journey(game, binding, bootstrap)
	await _test_detach_reentry(game, binding, bootstrap)
	await _cleanup(game)
	_finish()


func _test_composition_and_absolute_observation(
	game: GameFlow,
	binding: EmberMoonStreamingProductionBinding,
	bootstrap: EmberMoonStreamingBootstrap,
	) -> void:
	var report := binding.audit()
	var snapshot := report.get("snapshot", {}) as Dictionary
	_check(
		bool(report.get("valid", false))
			and int(report.get("binding_count", -1)) == 1
			and int(report.get("bootstrap_count", -1)) == 1
			and game.find_children(
				"*", "EmberMoonStreamingProductionBinding", true, false
			).size() == 1,
		"production owns exactly one activated Ember binding and bootstrap",
	)
	_check(
		bool(snapshot.get("activated", false))
			and not bool(snapshot.get("automatic_process", true))
			and not bool(snapshot.get("automatic_physics_process", true))
			and int(snapshot.get("bound_coordinate_frame_generation", 0)) == 1
			and int(snapshot.get("current_coordinate_frame_generation", 0)) == 1,
		"binding is caller-only and freezes exact coordinate generation one",
	)
	var authority := report.get("adjacent_authority", {}) as Dictionary
	var no_adjacent_authority := true
	for value: Variant in authority.values():
		no_adjacent_authority = no_adjacent_authority and value is bool and not value
	_check(
		no_adjacent_authority
			and authority.size() == 15
			and report.get("origin_rebase_policy")
				== &"detached_preview_exact_common_world_owner_commit"
			and bool(report.get("can_make_ember_resident", false)),
		"audit freezes the complete false adjacent-authority boundary",
	)

	var local_position := Vector3(12.0, 3.0, -9.0)
	var result := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(local_position, &"player", 101)
	)
	var absolute := result.get("absolute_coordinate", {}) as Dictionary
	_check(
		bool(result.get("accepted", false))
			and result.get("reason") == &"outside_load_radius"
			and absolute.get("frame_id") == &"nearby_sector_orbital"
			and int(absolute.get("cell_x", -1)) == 0
			and int(absolute.get("cell_y", -1)) == 0
			and int(absolute.get("cell_z", -1)) == 0
			and absolute.get("offset_meters") == local_position,
		"one caller physics sample becomes the exact station-datum absolute coordinate",
	)
	var preview := binding.preview_origin_rebase(1)
	_check(
		bool(preview.get("accepted", false))
			and not bool(preview.get("rebase_required", true))
			and preview.get("world_translation_delta") == -local_position
			and not bool(preview.get("binding_can_request_rebase", true))
			and not bool(preview.get("binding_can_apply_translation", true))
			and not bool(preview.get("binding_can_commit_rebase", true)),
		"subthreshold preview is exact and grants no rebase capability",
	)
	var before_invalid := binding.get_snapshot()
	_check(
		binding.physics_tick_from_caller_sample(
			NAN, _sample(Vector3.ZERO, &"player", 101)
		).reason == &"invalid_delta"
			and binding.physics_tick_from_caller_sample(
				1.0 / 60.0, {"available": false, "reason": &"missing"}
			).reason == &"actor_unavailable"
			and int(binding.get_snapshot().get("physics_tick_count", -1))
				== int(before_invalid.get("physics_tick_count", -2)),
		"invalid delta and unavailable schema cannot mutate streaming progress",
	)
	_check(
		binding.preview_origin_rebase(1).reason == &"actor_not_observed"
			and (binding.get_snapshot().get("last_absolute_coordinate", {}) as Dictionary).is_empty(),
		"latest unavailable actor invalidates the prior rebase preview",
	)
	var restored := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(local_position, &"player", 101)
	)
	var out_of_bounds := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(Vector3(1_100_000_000.0, 0.0, 0.0), &"player", 101)
	)
	_check(
		bool(restored.get("accepted", false))
			and not bool(out_of_bounds.get("accepted", true))
			and out_of_bounds.get("reason") == &"invalid_coordinate"
			and binding.preview_origin_rebase(1).reason == &"actor_not_observed",
		"finite out-of-bounds newest position invalidates the prior rebase preview",
	)


func _test_rebase_preview_and_fail_closed_journey(
	_game: GameFlow,
	binding: EmberMoonStreamingProductionBinding,
	bootstrap: EmberMoonStreamingBootstrap,
	) -> void:
	var frame := bootstrap.get_coordinate_frame_for_session()
	var near_ember_local := Vector3(0.0, 0.0, -7_900_000.0)
	var tick := binding.physics_tick_from_caller_sample(
		1.0 / 120.0, _sample(near_ember_local, &"ship", 202)
	)
	var coordinate := tick.get("absolute_coordinate", {}) as Dictionary
	_check(
		not bool(tick.get("accepted", true))
			and tick.get("reason") == &"rebase_required_before_load"
			and int(coordinate.get("cell_z", 0)) == -8
			and coordinate.get("offset_meters") == Vector3(0.0, 0.0, 100_000.0),
		"near-Ember absolute observation is retained while load fails closed before rebase",
	)
	var preview := binding.preview_origin_rebase(1)
	_check(
		bool(preview.get("accepted", false))
			and bool(preview.get("rebase_required", false))
			and preview.get("world_translation_delta") == Vector3(0.0, 0.0, 7_900_000.0)
			and preview.get("absolute_coordinate") == coordinate,
		"production publishes the exact detached rebase input without applying it",
	)
	var bootstrap_snapshot := bootstrap.get_snapshot()
	_check(
		frame.get_generation() == 1
			and (frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty()
			and bootstrap.position == Vector3(0.0, 0.0, -8_000_000.0)
			and bootstrap.get_loaded_instance() == null
			and int(bootstrap_snapshot.get("location_generation", -1)) == 0,
		"preview leaves frame, root, and coordinator generation byte-for-byte authoritative",
	)
	_check(
		binding.preview_origin_rebase(2).reason
			== &"stale_coordinate_frame_generation",
		"stale preview generation is rejected",
	)
	var mutable := binding.get_snapshot()
	(mutable.get("last_absolute_coordinate", {}) as Dictionary)["cell_z"] = 99
	(mutable.get("bootstrap", {}) as Dictionary).clear()
	var detached := binding.get_snapshot()
	_check(
		int((detached.get("last_absolute_coordinate", {}) as Dictionary).get("cell_z", 0)) == -8
			and not (detached.get("bootstrap", {}) as Dictionary).is_empty(),
		"production snapshots are deeply detached",
	)


func _test_detach_reentry(
	game: GameFlow,
	binding: EmberMoonStreamingProductionBinding,
	bootstrap: EmberMoonStreamingBootstrap,
	) -> void:
	var frame := bootstrap.get_coordinate_frame_for_session()
	var coordinator := bootstrap.get_node_or_null(
		^"WorldStreamingCoordinator"
	) as WorldStreamingCoordinator
	var before := binding.get_snapshot()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	_check(
		binding.get_parent() == game
			and bootstrap.get_parent() == game
			and bootstrap.get_coordinate_frame_for_session() == frame
			and bootstrap.get_node_or_null(^"WorldStreamingCoordinator") == coordinator,
		"whole-Main detach retains exact binding/bootstrap/frame/coordinator composition",
	)
	_check(
		binding.physics_tick_from_caller_sample(
			1.0 / 60.0, _sample(Vector3.ZERO, &"player", 303)
		).reason == &"binding_unavailable"
			and int(binding.get_snapshot().get("physics_tick_count", -1))
				== int(before.get("physics_tick_count", -2)),
		"detached binding cannot observe or replay physics",
	)
	parent.add_child(game)
	await process_frame
	await process_frame
	var after := binding.get_snapshot()
	_check(
		bool(binding.audit().get("valid", false))
			and int(after.get("bootstrap_instance_id", 0))
				== int(before.get("bootstrap_instance_id", -1))
			and int(after.get("coordinate_frame_instance_id", 0))
				== int(before.get("coordinate_frame_instance_id", -1))
			and int(after.get("bound_coordinate_frame_generation", 0)) == 1
			and int(after.get("physics_tick_count", -1))
				== int(before.get("physics_tick_count", -2)),
		"re-entry preserves identity, generation, and counters without duplicate activation",
	)
	var resumed := binding.physics_tick_from_caller_sample(
		1.0 / 30.0, _sample(Vector3.ZERO, &"player", 303)
	)
	_check(
		bool(resumed.get("accepted", false))
			and resumed.get("reason") == &"outside_load_radius"
			and int(binding.get_snapshot().get("physics_tick_count", -1))
				== int(before.get("physics_tick_count", -2)) + 1,
		"first post-reentry caller tick resumes exactly once on generation one",
	)
	var before_queued := binding.get_snapshot()
	bootstrap.queue_free()
	var queued_tick := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(Vector3.ZERO, &"player", 303)
	)
	_check(
		queued_tick.reason == &"bootstrap_identity_drift"
			and binding.preview_origin_rebase(1).reason == &"bootstrap_identity_drift"
			and int(binding.get_snapshot().get("physics_tick_count", -1))
				== int(before_queued.get("physics_tick_count", -2)),
		"queued bootstrap fails tick and preview closed without advancing cadence",
	)


func _sample(position: Vector3, kind: StringName, instance_id: int) -> Dictionary:
	return {
		"available": true,
		"position": position,
		"actor_kind": kind,
		"actor_instance_id": instance_id,
	}


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("EMBER_MOON_STREAMING_PRODUCTION_JOURNEY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_MOON_STREAMING_PRODUCTION_JOURNEY_TEST: %s" % failure)
	quit(1)
