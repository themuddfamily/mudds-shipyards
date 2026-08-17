extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://common-origin-owner-settings.json"
const EXPECTED_ASSERTIONS := 21

var _assertions := 0
var _failures: Array[String] = []
var _reentry_reason: StringName = &""
var _signal_receipt: Dictionary = {}
var _reentry_owner: CommonWorldOriginRebaseOwner
var _reentry_preview: Dictionary = {}
var _reentry_sample: Dictionary = {}


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate(); files.erase(from_path); return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null: _finish(); return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(game.configure_runtime_settings_persistence(store, "memory://origin-owner-legacy.cfg"), "settings are isolated")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var owner := game.get_node_or_null(^"CommonWorldOriginRebaseOwner") as CommonWorldOriginRebaseOwner
	var ember_binding := game.get_node_or_null(^"EmberMoonStreamingProductionBinding") as EmberMoonStreamingProductionBinding
	var ember := game.get_node_or_null(^"EmberMoonStreamingBootstrap") as EmberMoonStreamingBootstrap
	var cinder_binding := game.get_node_or_null(^"CinderStreamingProductionBinding") as CinderStreamingProductionBinding
	var cinder := game.get_node_or_null(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(owner != null and ember_binding != null and ember != null and cinder_binding != null and cinder != null and player != null, "all production identities resolve")
	if owner == null or ember_binding == null or ember == null or cinder_binding == null or cinder == null or player == null:
		await _cleanup(game); _finish(); return
	var initial_actor_reads := int(game.get_activity_integration_report().get("actor_position_sample_count", -1))
	_check(initial_actor_reads > 0 and int(ember_binding.get_snapshot().get("accepted_sample_count", -1)) == initial_actor_reads, "GameFlow's one actor read drives Ember without a second sampler")
	game.set_physics_process(false)

	var owner_audit := owner.audit()
	var authority := owner_audit.get("adjacent_authority", {}) as Dictionary
	var owned := owner_audit.get("owned_capabilities", {}) as Dictionary
	var authority_false := true
	for value: Variant in authority.values(): authority_false = authority_false and value is bool and not value
	_check(bool(owner_audit.get("valid", false)) and int(owner_audit.get("owner_count", 0)) == 1 and authority_false and bool(owned.get("collision_transform_synchronization", false)) and not owner.is_processing() and not owner.is_physics_processing(), "one caller-only owner exposes narrow collision-transform synchronization and zero adjacent authority")

	player.global_position = CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR
	cinder_binding.physics_tick_from_caller_sample(1.0 / 60.0, _sample(player))
	await process_frame
	await process_frame
	var cinder_loaded := cinder.get_loaded_instance()
	_check(is_instance_valid(cinder_loaded) and int(cinder.get_snapshot().get("loaded_generation", 0)) == 1, "one real Cinder generation is live before rebase")

	var top_probe := Node3D.new()
	top_probe.name = "TopLevelRebaseProbe"
	top_probe.top_level = true
	game.get_node(^"ShipyardWorld").add_child(top_probe)
	top_probe.global_position = Vector3(4.0, 5.0, 6.0)
	var world := game.get_node(^"ShipyardWorld") as Node3D
	var ship := game.get_node(^"TorrentInterceptor") as Node3D
	var before_positions := {
		"world": world.global_position,
		"ship": ship.global_position,
		"cinder": cinder.global_position,
		"cinder_loaded": cinder_loaded.global_position,
		"ember": ember.global_position,
		"top": top_probe.global_position,
	}
	player.global_position = Vector3(0.0, 0.0, -7_900_000.0)
	var sample := _sample(player)
	var ember_tick := ember_binding.physics_tick_from_caller_sample(1.0 / 60.0, sample)
	var preview := ember_binding.preview_origin_rebase(int(ember_tick.coordinate_frame_generation))
	_check(ember_tick.reason == &"rebase_required_before_load" and bool(preview.rebase_required), "near-Ember sample produces the exact required preview")
	var absolute_before := (preview.absolute_coordinate as Dictionary).duplicate(true)
	_reentry_owner = owner; _reentry_preview = preview; _reentry_sample = sample
	owner.rebase_committed.connect(_on_rebase_committed)
	var result := owner.consume_rebase_preview(preview, sample)
	var delta := preview.world_translation_delta as Vector3
	_check(bool(result.accepted) and result.reason == &"rebase_committed" and (result.actor_sample as Dictionary).position == Vector3.ZERO, "owner commits and returns the adjusted shared actor sample")
	_check(_reentry_reason == &"reentrant_call" and _signal_receipt.reason == &"rebase_committed", "committed signal observes final state and rejects reentry")
	var frame := ember.get_coordinate_frame_for_session()
	_check(frame.get_generation() == 2 and (frame.get_snapshot().pending_rebase as Dictionary).is_empty(), "frame advances exactly once with no pending request")
	_check(player.global_position == Vector3.ZERO and world.global_position.is_equal_approx(before_positions.world + delta) and ship.global_position.is_equal_approx(before_positions.ship + delta), "actor, station, and fleet roots receive one exact delta")
	_check(cinder.global_position.is_equal_approx(before_positions.cinder + delta) and cinder_loaded.global_position.is_equal_approx(before_positions.cinder_loaded + delta) and cinder.get_loaded_instance() == cinder_loaded and int(cinder.get_snapshot().loaded_generation) == 1, "Cinder bootstrap and live generation translate without retirement")
	_check(ember.global_position.is_equal_approx(before_positions.ember + delta) and top_probe.global_position.is_equal_approx(before_positions.top + delta), "Ember and nested top-level nodes receive the same delta")
	var binding_after := ember_binding.get_snapshot()
	_check(int(binding_after.bound_coordinate_frame_generation) == 2 and binding_after.last_absolute_coordinate == absolute_before and int(binding_after.external_rebase_commit_count) == 1, "binding handoff preserves the absolute coordinate at target generation")
	await process_frame
	await process_frame
	_check(is_instance_valid(ember.get_loaded_instance()) and int(ember.get_snapshot().location_generation) == 1, "committed rebase makes the existing Ember generation loadable")
	var receipt := result.get("receipt", {}) as Dictionary
	var root_paths: Array = []
	for entry: Dictionary in receipt.get("root_roster", []): root_paths.append(entry.path)
	_check(root_paths.has("ShipyardWorld") and root_paths.has("Player") and root_paths.has("CinderStreamingBootstrap") and root_paths.has("EmberMoonStreamingBootstrap") and root_paths.has("ShipyardWorld/TopLevelRebaseProbe") and int(receipt.get("covered_node_count", 0)) > (receipt.get("root_roster", []) as Array).size(), "receipt freezes direct/top-level roots and complete descendant coverage")
	var mutable := owner.get_snapshot(); (mutable.last_receipt as Dictionary).clear(); (mutable.last_root_roster as Array).clear()
	_check(not (owner.get_snapshot().last_receipt as Dictionary).is_empty() and not (owner.get_snapshot().last_root_roster as Array).is_empty(), "owner snapshots are deeply detached")

	var rollback_area := Area3D.new()
	rollback_area.name = "RollbackCollisionAreaProbe"
	rollback_area.collision_layer = 0
	rollback_area.collision_mask = 0
	var rollback_area_shape := CollisionShape3D.new()
	rollback_area_shape.name = "RollbackCollisionAreaShape"
	var rollback_area_sphere := SphereShape3D.new()
	rollback_area_sphere.radius = 1.0
	rollback_area_shape.shape = rollback_area_sphere
	rollback_area.add_child(rollback_area_shape)
	game.add_child(rollback_area)
	rollback_area.global_position = Vector3(17.0, 23.0, 31.0)
	await physics_frame
	player.global_position = Vector3(10_000.0, 0.0, 0.0)
	var rollback_sample := _sample(player)
	var rollback_tick := ember_binding.physics_tick_from_caller_sample(1.0 / 60.0, rollback_sample)
	var rollback_preview := ember_binding.preview_origin_rebase(int(rollback_tick.coordinate_frame_generation))
	var before_rollback_world := world.global_transform
	var camera := game.get_node(^"Player/CameraRig/CameraYaw/CameraPitch/SpringArm3D/PlayerCamera") as Camera3D
	var before_rollback_camera := camera.transform
	var before_rollback_generation := frame.get_generation()
	var rollback_body := ship as PhysicsBody3D
	var before_rollback_body_server := PhysicsServer3D.body_get_state(
		rollback_body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var before_rollback_area_server := PhysicsServer3D.area_get_transform(
		rollback_area.get_rid()
	)
	owner._commit_adapter = Callable(self, &"_reject_commit")
	var rejected := owner.consume_rebase_preview(rollback_preview, rollback_sample)
	owner._commit_adapter = Callable()
	var after_rollback_body_server := PhysicsServer3D.body_get_state(
		rollback_body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var after_rollback_area_server := PhysicsServer3D.area_get_transform(
		rollback_area.get_rid()
	)
	_check(rejected.reason == &"forced_commit_rejection" and world.global_transform.is_equal_approx(before_rollback_world) and camera.transform.is_equal_approx(before_rollback_camera) and after_rollback_body_server.is_equal_approx(before_rollback_body_server) and after_rollback_area_server.is_equal_approx(before_rollback_area_server) and frame.get_generation() == before_rollback_generation and (frame.get_snapshot().pending_rebase as Dictionary).is_empty(), "commit failure restores roots, derived local state, and body/area PhysicsServer transforms before cancelling the exact request")
	_check(int(owner.get_snapshot().rollback_count) == 1 and bool(owner.audit().valid), "rollback is counted and production audit recovers")

	var identities := [owner.get_instance_id(), ember.get_instance_id(), ember_binding.get_instance_id(), frame.get_instance_id(), cinder_loaded.get_instance_id()]
	var transaction_count := int(owner.get_snapshot().transaction_count)
	root.remove_child(game)
	await process_frame
	_check(owner.consume_rebase_preview(rollback_preview, rollback_sample).reason == &"owner_unavailable" and int(owner.get_snapshot().transaction_count) == transaction_count, "whole-Main detach freezes transactions")
	root.add_child(game)
	await process_frame
	await process_frame
	_check([owner.get_instance_id(), ember.get_instance_id(), ember_binding.get_instance_id(), frame.get_instance_id(), cinder_loaded.get_instance_id()] == identities and int(owner.get_snapshot().transaction_count) == transaction_count and bool(owner.audit().valid), "re-entry preserves owner/frame/stream identities without replay")

	top_probe.queue_free()
	rollback_area.queue_free()
	await _cleanup(game)
	_finish()


func _sample(actor: Node3D) -> Dictionary:
	return {"available": true, "position": actor.global_position, "actor_kind": &"player", "actor_instance_id": actor.get_instance_id()}


func _on_rebase_committed(receipt: Dictionary) -> void:
	_signal_receipt = receipt.duplicate(true)
	_reentry_reason = _reentry_owner.consume_rebase_preview(_reentry_preview, _reentry_sample).reason


func _reject_commit(_request_id: int, _source_generation: int) -> Dictionary:
	return {"accepted": false, "reason": &"forced_commit_rejection"}


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game): game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS: _failures.append("expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions])
	if _failures.is_empty():
		print("COMMON_WORLD_ORIGIN_REBASE_PRODUCTION_JOURNEY_TEST_OK: %d assertions" % _assertions); quit(0); return
	for failure in _failures: push_error("COMMON_WORLD_ORIGIN_REBASE_PRODUCTION_JOURNEY_TEST: %s" % failure)
	quit(1)
