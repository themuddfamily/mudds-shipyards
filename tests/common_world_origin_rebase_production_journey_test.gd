extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Layers := preload("res://scripts/core/physics_layers.gd")
const STORE_PATH := "memory://common-origin-owner-settings.json"
const EXPECTED_ASSERTIONS := 127

class OwnerSubclassProbe extends CommonWorldOriginRebaseOwner:
	func _init() -> void:
		pass
	func _enter_tree() -> void:
		pass

class TopologyMutationOwner extends CommonWorldOriginRebaseOwner:
	var rename_after_apply: Node
	func _apply_root_translation(roots: Array, delta: Vector3) -> bool:
		var applied := super._apply_root_translation(roots, delta)
		if applied and is_instance_valid(rename_after_apply):
			rename_after_apply.name = "RenamedAfterTranslation"
			rename_after_apply = null
		return applied

class RosterCapabilityProbe extends Node3D:
	var eligible := true
	var rename_during_capture := false
	func is_common_world_translation_root() -> bool:
		if rename_during_capture:
			rename_during_capture = false
			name = "RenamedDuringCapture"
		return eligible

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
	await _check_aurora_transit_carry()
	for mutation in [&"body_added", &"body_removed", &"body_reparented", &"body_reentered",
			&"shape_added", &"shape_replaced", &"shape_moved", &"shape_resized"]:
		await _check_aurora_transit_carry(mutation)
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null: _finish(); return
	# Exercise topology rollback through an inherited implementation seam, before
	# Main discovers its caller-only owner and binds the original world frames.
	var scene_owner := game.get_node(^"CommonWorldOriginRebaseOwner")
	game.remove_child(scene_owner)
	scene_owner.free()
	var mutation_owner := TopologyMutationOwner.new()
	mutation_owner.name = "CommonWorldOriginRebaseOwner"
	game.add_child(mutation_owner)
	var mutation_marker := Node.new()
	mutation_marker.name = "TopologyMutationMarker"
	game.add_child(mutation_marker)
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
	var aurora_binding := game.get_node_or_null(^"AuroraTemperateStreamingProductionBinding") as AuroraTemperateStreamingProductionBinding
	var aurora := game.get_node_or_null(^"AuroraTemperateStreamingBootstrap") as AuroraTemperateStreamingBootstrap
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(owner != null and ember_binding != null and ember != null and cinder_binding != null and cinder != null and aurora_binding != null and aurora != null and player != null, "all production identities resolve")
	if owner == null or ember_binding == null or ember == null or cinder_binding == null or cinder == null or aurora_binding == null or aurora == null or player == null:
		await _cleanup(game); _finish(); return
	var aurora_frame := aurora.get_coordinate_frame_for_session()
	# Rime is bound by discovery too; it is never travelled to here, but every
	# committed transaction carries its frame along with the others.
	var rime := game.get_node_or_null(^"RimeGlacialStreamingBootstrap") as RimeGlacialStreamingBootstrap
	_check(rime != null, "the third composed world resolves")
	if rime == null:
		await _cleanup(game); _finish(); return
	var rime_frame := rime.get_coordinate_frame_for_session()
	var ember_world_record := owner.get_world_binding_snapshot(EmberMoonStreamingBootstrap.WORLD_ID)
	var aurora_world_record := owner.get_world_binding_snapshot(AuroraTemperateStreamingBootstrap.WORLD_ID)
	_check(
		owner.get_bound_world_ids() == PackedStringArray([
			String(AuroraTemperateStreamingBootstrap.WORLD_ID),
			String(EmberMoonStreamingBootstrap.WORLD_ID),
			String(RimeGlacialStreamingBootstrap.WORLD_ID),
		])
			and int(owner.get_snapshot().world_count) == 3
			and int(ember_world_record.get("binding_instance_id", 0)) == ember_binding.get_instance_id()
			and int(ember_world_record.get("bootstrap_instance_id", 0)) == ember.get_instance_id()
			and int(aurora_world_record.get("binding_instance_id", 0)) == aurora_binding.get_instance_id()
			and int(aurora_world_record.get("bootstrap_instance_id", 0)) == aurora.get_instance_id()
			and String(aurora_world_record.get("identity_error", &"")).is_empty(),
		"one owner binds every composed world by its own bootstrap/binding pair"
	)
	var initial_actor_reads := int(game.get_activity_integration_report().get("actor_position_sample_count", -1))
	_check(initial_actor_reads > 0 and int(ember_binding.get_snapshot().get("accepted_sample_count", -1)) == initial_actor_reads, "GameFlow's one actor read drives Ember without a second sampler")
	game.set_physics_process(false)

	var owner_audit := owner.audit()
	var authority := owner_audit.get("adjacent_authority", {}) as Dictionary
	var owned := owner_audit.get("owned_capabilities", {}) as Dictionary
	var authority_false := true
	for value: Variant in authority.values(): authority_false = authority_false and value is bool and not value
	_check(bool(owner_audit.get("valid", false)) and int(owner_audit.get("owner_count", 0)) == 1 and authority_false and bool(owned.get("collision_transform_synchronization", false)) and not owner.is_processing() and not owner.is_physics_processing(), "one caller-only owner exposes narrow collision-transform synchronization and zero adjacent authority")
	await _check_live_owner_validation(game, owner)
	await _check_roster_cache_lifecycle(game, owner)

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
	var network_probes := _prepare_network_origin_probes(game, ship as HeroShip)
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
	# The common world is shared. A translation asked for by one world moves the
	# local space of both, so the world that was not travelled to must come with
	# it rather than be left behind holding a stale origin.
	var first_receipt := result.get("receipt", {}) as Dictionary
	_check(
		aurora_frame.get_generation() == 2
			and (aurora_frame.get_snapshot().pending_rebase as Dictionary).is_empty()
			and aurora.global_position.is_equal_approx(
				AuroraTemperateStreamingBootstrap.INITIAL_BODY_CENTER_WORLD_POSITION + delta
			)
			and bool(aurora.audit().get("valid", false))
			and int(aurora_binding.get_snapshot().bound_coordinate_frame_generation) == 2
			and (first_receipt.get("world_generations", {}) as Dictionary) == {
				String(AuroraTemperateStreamingBootstrap.WORLD_ID): 2,
				String(EmberMoonStreamingBootstrap.WORLD_ID): 2,
				String(RimeGlacialStreamingBootstrap.WORLD_ID): 2,
			}
			and rime_frame.get_generation() == 2,
		"an Ember transaction carries the untravelled second world's frame, root and adapter with it"
	)
	_check(player.global_position == Vector3.ZERO and world.global_position.is_equal_approx(before_positions.world + delta) and ship.global_position.is_equal_approx(before_positions.ship + delta), "actor, station, and fleet roots receive one exact delta")
	_check(cinder.global_position.is_equal_approx(before_positions.cinder + delta) and cinder_loaded.global_position.is_equal_approx(before_positions.cinder_loaded + delta) and cinder.get_loaded_instance() == cinder_loaded and int(cinder.get_snapshot().loaded_generation) == 1, "Cinder bootstrap and live generation translate without retirement")
	_check(ember.global_position.is_equal_approx(before_positions.ember + delta) and top_probe.global_position.is_equal_approx(before_positions.top + delta), "Ember and nested top-level nodes receive the same delta")
	_check_network_origin_probes(game, network_probes, delta)
	var no_op_pose := game._network_craft_pose_stream.latest_sample((ship as HeroShip).get_ship_id())
	var no_op_sample := _sample(player)
	var no_op_tick := ember_binding.physics_tick_from_caller_sample(1.0 / 60.0, no_op_sample)
	var no_op_preview := ember_binding.preview_origin_rebase(int(no_op_tick.coordinate_frame_generation))
	var no_op := owner.consume_rebase_preview(no_op_preview, no_op_sample)
	_check(no_op.reason == &"no_rebase_required" and int(owner.get_snapshot().transaction_count) == 1
		and game._network_craft_pose_stream.latest_sample((ship as HeroShip).get_ship_id()) == no_op_pose,
		"a real no-op preview preserves histories and does not replay the committed translation")
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
	var before_topology_generations := [frame.get_generation(), aurora_frame.get_generation(), rime_frame.get_generation()]
	mutation_owner.rename_after_apply = mutation_marker
	var topology_rejected := owner.consume_rebase_preview(rollback_preview, rollback_sample)
	var topology_body_server := PhysicsServer3D.body_get_state(
		rollback_body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D
	var topology_area_server := PhysicsServer3D.area_get_transform(rollback_area.get_rid())
	_check(topology_rejected.reason == &"world_roster_changed"
		and world.global_transform.is_equal_approx(before_rollback_world)
		and camera.transform.is_equal_approx(before_rollback_camera)
		and topology_body_server.is_equal_approx(before_rollback_body_server)
		and topology_area_server.is_equal_approx(before_rollback_area_server)
		and [frame.get_generation(), aurora_frame.get_generation(), rime_frame.get_generation()] == before_topology_generations
		and (frame.get_snapshot().pending_rebase as Dictionary).is_empty()
		and (aurora_frame.get_snapshot().pending_rebase as Dictionary).is_empty()
		and (rime_frame.get_snapshot().pending_rebase as Dictionary).is_empty(),
		"post-translation topology changes restore roots, local and server transforms and cancel every frame before commit")
	owner._commit_adapter = Callable(self, &"_reject_commit")
	var rollback_pose := game._network_craft_pose_stream.latest_sample((ship as HeroShip).get_ship_id())
	var rejected := owner.consume_rebase_preview(rollback_preview, rollback_sample)
	owner._commit_adapter = Callable()
	var after_rollback_body_server := PhysicsServer3D.body_get_state(
		rollback_body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var after_rollback_area_server := PhysicsServer3D.area_get_transform(
		rollback_area.get_rid()
	)
	_check(rejected.reason == &"forced_commit_rejection" and world.global_transform.is_equal_approx(before_rollback_world) and camera.transform.is_equal_approx(before_rollback_camera) and after_rollback_body_server.is_equal_approx(before_rollback_body_server) and after_rollback_area_server.is_equal_approx(before_rollback_area_server) and frame.get_generation() == before_rollback_generation and (frame.get_snapshot().pending_rebase as Dictionary).is_empty(), "commit failure restores roots, derived local state, and body/area PhysicsServer transforms before cancelling the exact request")
	_check(int(owner.get_snapshot().rollback_count) == 2 and bool(owner.audit().valid), "rollback is counted and production audit recovers")
	_check(game._network_craft_pose_stream.latest_sample((ship as HeroShip).get_ship_id()) == rollback_pose,
		"a rejected transaction does not migrate retained network samples")

	var identities := [owner.get_instance_id(), ember.get_instance_id(), ember_binding.get_instance_id(), frame.get_instance_id(), cinder_loaded.get_instance_id()]
	var transaction_count := int(owner.get_snapshot().transaction_count)
	root.remove_child(game)
	await process_frame
	_check(owner.consume_rebase_preview(rollback_preview, rollback_sample).reason == &"owner_unavailable" and int(owner.get_snapshot().transaction_count) == transaction_count, "whole-Main detach freezes transactions")
	root.add_child(game)
	_check(int(owner.get("_roster_cache_revision")) == -1, "owner reentry starts with a cold structure cache")
	await process_frame
	await process_frame
	_check([owner.get_instance_id(), ember.get_instance_id(), ember_binding.get_instance_id(), frame.get_instance_id(), cinder_loaded.get_instance_id()] == identities and int(owner.get_snapshot().transaction_count) == transaction_count and bool(owner.audit().valid), "re-entry preserves owner/frame/stream identities without replay")

	game.remove_child(ember_binding)
	_check(not bool(owner.get_live_validation().valid)
		and owner.get_live_validation().errors == owner.audit().errors,
		"compact and full validation both reject current world-binding identity drift")
	var detached_binding_before := ember_binding.get_snapshot()
	var detached_bootstrap_before := ember.get_snapshot()
	var detached_accept := ember_binding.accept_committed_origin_rebase({}, {}, {}, 0)
	_check(
		not bool(detached_accept.accepted)
			and detached_accept.reason == &"binding_unavailable"
			and ember_binding.get_snapshot() == detached_binding_before
			and ember.get_snapshot() == detached_bootstrap_before,
		"a detached Ember binding rejects direct rebase acceptance without retained or bootstrap mutation"
	)
	game.add_child(ember_binding)
	await process_frame
	player.global_position = Vector3(12_000.0, 0.0, 0.0)
	var reentry_sample := _sample(player)
	var reentry_tick := ember_binding.physics_tick_from_caller_sample(1.0 / 60.0, reentry_sample)
	var reentry_preview := ember_binding.preview_origin_rebase(
		int(reentry_tick.coordinate_frame_generation)
	)
	var reentry_transaction := owner.consume_rebase_preview(reentry_preview, reentry_sample)
	_check((game._network_craft_pose_stream.latest_sample((ship as HeroShip).get_ship_id()).position as Vector3)
		.is_equal_approx((rollback_pose.position as Vector3) + (reentry_preview.world_translation_delta as Vector3)),
		"a fresh transaction migrates histories once after rollback and tree reentry")
	_check(
		bool(reentry_transaction.accepted)
			and reentry_transaction.reason == &"rebase_committed"
			and int(ember_binding.get_snapshot().get("external_rebase_commit_count", 0)) == 2,
		"a reattached Ember binding accepts one fresh live origin-rebase transaction"
	)

	# --- the same owner, the second world -------------------------------------
	# Aurora is 12,000 km out on +X, Ember 8,000 km out on -Z. Standing at
	# Aurora's own navigation anchor is a fresh transaction for a different
	# world, through the one owner that already served Ember twice.
	player.global_position = aurora.global_position + Vector3(0.0, 130_000.0, 0.0)
	var aurora_sample := _sample(player)
	var aurora_tick := aurora_binding.physics_tick_from_caller_sample(1.0 / 60.0, aurora_sample)
	var aurora_preview := aurora_binding.preview_origin_rebase(int(aurora_tick.coordinate_frame_generation))
	_check(
		aurora_tick.reason == &"rebase_required_before_load"
			and bool(aurora_preview.rebase_required)
			and aurora_preview.world_id == AuroraTemperateStreamingBootstrap.WORLD_ID,
		"a near-Aurora sample produces Aurora's own required preview, named for its world"
	)

	# A world that has retired is not a world the owner will act for, and a
	# rebind restores it without replaying anything.
	var unbound := owner.unbind_world(AuroraTemperateStreamingBootstrap.WORLD_ID)
	var refused := owner.consume_rebase_preview(aurora_preview, aurora_sample)
	var rebound := owner.rebind_composed_worlds()
	_check(
		bool(unbound.accepted) and int(unbound.world_count) == 2
			and not bool(refused.accepted) and refused.reason == &"unbound_rebase_world"
			and bool(rebound.accepted)
			and (rebound.bound_world_ids as PackedStringArray) == PackedStringArray([
				String(AuroraTemperateStreamingBootstrap.WORLD_ID),
			])
			and int(owner.get_snapshot().world_count) == 3
			and int(owner.get_snapshot().transaction_count) == transaction_count + 1,
		"a retired world is refused by name and a rebind restores it without replaying a transaction"
	)

	var aurora_ember_generation_before := frame.get_generation()
	var aurora_generation_before := aurora_frame.get_generation()
	var rime_generation_before := rime_frame.get_generation()
	var aurora_ember_loaded_before := ember.get_loaded_instance()
	var aurora_transaction := owner.consume_rebase_preview(aurora_preview, aurora_sample)
	var aurora_delta := aurora_preview.world_translation_delta as Vector3
	var aurora_receipt := aurora_transaction.get("receipt", {}) as Dictionary
	_check(
		bool(aurora_transaction.accepted)
			and aurora_transaction.reason == &"rebase_committed"
			and aurora_transaction.world_id == AuroraTemperateStreamingBootstrap.WORLD_ID
			and player.global_position == Vector3.ZERO
			and aurora_frame.get_generation() == aurora_generation_before + 1
			and frame.get_generation() == aurora_ember_generation_before + 1
			and (aurora_receipt.get("world_generations", {}) as Dictionary) == {
				String(AuroraTemperateStreamingBootstrap.WORLD_ID): aurora_generation_before + 1,
				String(EmberMoonStreamingBootstrap.WORLD_ID): aurora_ember_generation_before + 1,
				String(RimeGlacialStreamingBootstrap.WORLD_ID): rime_generation_before + 1,
			}
			and int(aurora_binding.get_snapshot().external_rebase_commit_count) >= 1,
		"the second world commits its own transaction through the same owner"
	)
	await process_frame
	await process_frame
	_check(
		is_instance_valid(aurora.get_loaded_instance())
			and aurora.get_loaded_instance() is AuroraTemperateAuthoredScene
			and int(aurora.get_snapshot().location_generation) == 1
			and ember.get_loaded_instance() == aurora_ember_loaded_before
			and int(ember_binding.get_snapshot().bound_coordinate_frame_generation)
				== frame.get_generation()
			and bool(ember.audit().valid) and bool(aurora.audit().valid),
		"Aurora's committed rebase streams Aurora's own world in and leaves Ember's generation and adapter intact"
	)

	# A failed commit must roll back exactly as it does for the first world.
	player.global_position = aurora.global_position + Vector3(0.0, 150_000.0, 0.0)
	var aurora_rollback_sample := _sample(player)
	var aurora_rollback_tick := aurora_binding.physics_tick_from_caller_sample(1.0 / 60.0, aurora_rollback_sample)
	var aurora_rollback_preview := aurora_binding.preview_origin_rebase(int(aurora_rollback_tick.coordinate_frame_generation))
	var aurora_world_before := world.global_transform
	var aurora_root_before := aurora.global_transform
	var aurora_loaded_before := aurora.get_loaded_instance() as Node3D
	var aurora_loaded_transform_before := aurora_loaded_before.global_transform
	var aurora_frame_generation_before := aurora_frame.get_generation()
	var aurora_ember_frame_before := frame.get_generation()
	var aurora_rollback_count_before := int(owner.get_snapshot().rollback_count)
	owner._commit_adapter = Callable(self, &"_reject_commit")
	var aurora_rejected := owner.consume_rebase_preview(aurora_rollback_preview, aurora_rollback_sample)
	owner._commit_adapter = Callable()
	_check(
		aurora_rejected.reason == &"forced_commit_rejection"
			and world.global_transform.is_equal_approx(aurora_world_before)
			and aurora.global_transform.is_equal_approx(aurora_root_before)
			and aurora.get_loaded_instance() == aurora_loaded_before
			and aurora_loaded_before.global_transform.is_equal_approx(aurora_loaded_transform_before)
			and aurora_frame.get_generation() == aurora_frame_generation_before
			and frame.get_generation() == aurora_ember_frame_before
			and (aurora_frame.get_snapshot().pending_rebase as Dictionary).is_empty()
			and (frame.get_snapshot().pending_rebase as Dictionary).is_empty()
			and int(owner.get_snapshot().rollback_count) == aurora_rollback_count_before + 1
			and bool(owner.audit().valid),
		"a failed commit for the second world rolls every root and every bound frame back"
	)

	var queued_binding_before := ember_binding.get_snapshot()
	var queued_bootstrap_before := ember.get_snapshot()
	ember_binding.queue_free()
	var queued_accept := ember_binding.accept_committed_origin_rebase({}, {}, {}, 0)
	_check(
		ember_binding.is_inside_tree()
			and ember_binding.is_queued_for_deletion()
			and not bool(queued_accept.accepted)
			and queued_accept.reason == &"binding_unavailable"
			and ember_binding.get_snapshot() == queued_binding_before
			and ember.get_snapshot() == queued_bootstrap_before,
		"a queued Ember binding rejects direct rebase acceptance without retained or bootstrap mutation"
	)

	top_probe.queue_free()
	rollback_area.queue_free()
	await _cleanup(game)
	_finish()


func _check_aurora_transit_carry(roster_mutation: StringName = &"") -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(
		Store.new("memory://aurora-carry.json", MemoryFilesystem.new()),
		"memory://aurora-carry-legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var roster_probe: StaticBody3D
	var roster_shape: CollisionShape3D
	if not roster_mutation.is_empty():
		roster_probe = StaticBody3D.new()
		roster_probe.name = "CollisionPublicationRosterProbe"
		roster_shape = CollisionShape3D.new()
		roster_shape.shape = BoxShape3D.new()
		roster_probe.add_child(roster_shape)
		game.add_child(roster_probe)
	var ship := game.active_ship
	ship.set_physics_process(false)
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.opponent.deactivate()
	# Isolate the origin-carry boundary, not a physical departure flight.
	ship.global_position = Vector3(11_000.0, 150.0, 0.0)
	ship.global_basis = Basis.looking_at(Vector3.RIGHT)
	var before := ship.global_transform
	var journey: RefCounted = game.get("_planetary_journey")
	var admitted: Dictionary = journey.call(&"admit_aurora_visit", ship, false)
	var local: Dictionary = journey.call(&"engage_aurora_cruise", ship)
	var carried: Dictionary = journey.call(&"engage_aurora_cruise", ship, true)
	var binding := game.planetary_cruise_binding
	_check(bool(admitted.get("accepted", false))
		and bool(local.get("accepted", false)) and bool(carried.get("accepted", false))
		and bool(binding.get_snapshot().get("carry_transit", false))
		and ship.global_transform == before,
		"an admitted Aurora cruise upgrades to continuous transit without placing the craft")
	var advanced: Dictionary = journey.call(&"advance_aurora_visit", 1.0 / 60.0,
		game.call(&"_capture_cinder_actor_sample"))
	var visit: Dictionary = journey.call(&"get_aurora_visit_snapshot")
	var origin := visit.get("last_origin_result", {}) as Dictionary
	var adoption := origin.get("adoption", {}) as Dictionary
	var cruise_adoption := adoption.get("cruise", {}) as Dictionary
	_check(bool(advanced.get("accepted", false))
		and int(visit.get("rebase_commit_count", 0)) == 1
		and bool(adoption.get("accepted", false))
		and cruise_adoption.get("reason") == &"origin_translation_accepted"
		and (advanced.get("actor_sample", {}) as Dictionary).get("position") == ship.global_position,
		"the Aurora caller adopts its real common-origin receipt before the next cruise tick")
	var owner := game.common_world_origin_rebase_owner
	var receipt := origin.get("receipt", {}) as Dictionary
	var controller_id := binding.get_controller().get_instance_id()
	var attachment := int(ship.get_planetary_cruise_attachment_report().get("ship_attachment_generation", 0))
	var held_pose := ship.global_transform
	var held_velocity := ship.velocity
	var binding_generation := binding.get_generation()
	_check(ship.get_planetary_cruise_collision_publication_status() == &"pending"
		and not (PhysicsServer3D.body_get_state(ship.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
			as Transform3D).is_equal_approx(held_pose),
		"a genuine committed moving kinematic rebase retains an actual unpublished collision pose")
	if not roster_mutation.is_empty():
		match roster_mutation:
			&"body_added":
				var added_body := StaticBody3D.new()
				var added_shape := CollisionShape3D.new()
				added_shape.shape = BoxShape3D.new()
				added_body.add_child(added_shape)
				game.add_child(added_body)
			&"body_removed":
				game.remove_child(roster_probe)
			&"body_reparented":
				roster_probe.reparent(game.get_node(^"ShipyardWorld"), true)
			&"body_reentered":
				game.remove_child(roster_probe)
				game.add_child(roster_probe)
			&"shape_added":
				var added_shape := CollisionShape3D.new()
				added_shape.shape = BoxShape3D.new()
				roster_probe.add_child(added_shape)
			&"shape_replaced":
				roster_shape.shape = BoxShape3D.new()
			&"shape_moved":
				roster_shape.position += Vector3.RIGHT
			&"shape_resized":
				(roster_shape.shape as BoxShape3D).size += Vector3.ONE
		var stale := ship.build_planetary_cruise_clearance_proof(Vector3.RIGHT, 1000.0,
			int(receipt.target_generation), attachment, controller_id)
		_check(ship.get_planetary_cruise_collision_publication_status()
			== &"collision_publication_roster_changed"
			and not bool(stale.get("accepted", true))
			and stale.get("reason") == &"collision_publication_roster_changed"
			and not bool(stale.get("clearance_full_hull", true))
			and int(stale.get("queried_shape_count", -1)) == 0,
			"%s rejects a changed collision roster before granting any clearance" % roster_mutation)
		await physics_frame
		_check(owner.get_collision_publication_status(receipt, ship)
			== &"collision_publication_roster_changed"
			and ship.global_transform == held_pose and ship.velocity == held_velocity,
			"%s cannot publish or move the held hull through the stale barrier" % roster_mutation)
		if roster_mutation == &"body_removed":
			roster_probe.free()
		journey.call(&"retire_aurora_visit")
		ship.set_piloted(false)
		game.set("_piloting", false)
		await _cleanup(game)
		return
	# This ordinary HUD setting rebuilds real Control children while the same
	# production collision transaction is waiting for PhysicsServer publication.
	game.hud.call(&"set_reticle_style", &"large")
	var presentation := Node3D.new()
	game.add_child(presentation)
	presentation.name = "RenamedCollisionFreePresentation"
	game.remove_child(presentation)
	presentation.free()
	_check(ship.get_planetary_cruise_collision_publication_status() == &"pending",
		"ordinary HUD rebuild and collision-free node churn preserve the exact pending barrier")
	var forged := receipt.duplicate(true)
	forged["transaction_index"] = int(receipt.transaction_index) + 1
	_check(ship.await_planetary_cruise_collision_publication(owner, forged, controller_id, attachment)
		== &"collision_publication_not_current"
		and ship.await_planetary_cruise_collision_publication(owner, receipt, controller_id, attachment)
		== &"collision_publication_replayed",
		"forged and replayed transactions cannot renew the publication wait")
	var waiting_proof := ship.build_planetary_cruise_clearance_proof(Vector3.RIGHT, 1000.0,
		int(receipt.target_generation), attachment, controller_id)
	_check(not bool(waiting_proof.get("accepted", true))
		and waiting_proof.get("reason") == &"collision_publication_pending",
		"pending collision publication cannot masquerade as an accepted clearance proof")
	var held_tick := ship._update_planetary_cruise_physics(1.0 / 60.0)
	var held_report := ship.get_planetary_cruise_attachment_report()
	_check(held_tick and ship.global_transform == held_pose and ship.velocity == held_velocity
		and int(held_report.controller_instance_id) == controller_id
		and int(held_report.ship_attachment_generation) == attachment
		and (held_report.pending_envelope as Dictionary).is_empty()
		and (held_report.pending_clearance_proof as Dictionary).is_empty(),
		"the authentic wait consumes a tick without movement, acceleration, old proof or ownership retirement")
	for _publication_frame in 3:
		await physics_frame
		if ship.get_planetary_cruise_collision_publication_status() != &"pending":
			break
	_check(ship.get_planetary_cruise_collision_publication_status() == &"ready"
		and binding.get_generation() == binding_generation
		and int(ship.get_planetary_cruise_attachment_report().controller_instance_id) == controller_id
		and int(ship.get_planetary_cruise_attachment_report().ship_attachment_generation) == attachment
		and ship.global_transform == held_pose
		and (PhysicsServer3D.body_get_state(ship.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
			as Transform3D).is_equal_approx(held_pose),
		"real physics publication releases the wait with the exact hull and controller attachment retained")
	var blocker := StaticBody3D.new()
	blocker.collision_layer = ship.collision_mask
	var blocker_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 200.0, 200.0)
	blocker_shape.shape = box
	blocker.add_child(blocker_shape)
	game.add_child(blocker)
	blocker.global_position = ship.global_position + Vector3.RIGHT * 250.0
	blocker.force_update_transform()
	PhysicsServer3D.body_set_state(blocker.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, blocker.global_transform)
	var blocked := ship.build_planetary_cruise_clearance_proof(Vector3.RIGHT, 1000.0,
		int(receipt.target_generation), attachment, controller_id)
	_check(bool(blocked.get("accepted", false)) and bool(blocked.get("obstacle_detected", false))
		and float(blocked.get("verified_clearance_meters", INF)) < 250.0,
		"the released current-generation full hull still detects a genuine live blocker")
	blocker.queue_free()
	await physics_frame
	var fresh := binding.get_controller().evaluate_and_submit(
		ship.global_position + Vector3.RIGHT * 8_000_000.0, false,
		int(receipt.target_generation), binding.get_controller().get_generation())
	_check(bool(fresh.get("accepted", false))
		and not (ship.get_planetary_cruise_attachment_report().pending_envelope as Dictionary).is_empty(),
		"publication release resumes only with a fresh current-generation strict proof and envelope")
	ship._update_planetary_cruise_physics(1.0 / 60.0)
	ship._update_planetary_cruise_physics(1.0 / 60.0)
	_check(ship.get_planetary_cruise_collision_publication_status() == &"not_pending"
		and int(ship.get_planetary_cruise_attachment_report().ship_attachment_generation) > attachment
		and int(ship.get_planetary_cruise_attachment_report().controller_instance_id) == 0,
		"ordinary missing-envelope retirement remains strict after publication release")
	var repeated := binding.accept_committed_origin_rebase(
		origin.get("receipt", {}) as Dictionary, binding.get_generation())
	_check(not bool(repeated.get("accepted", false)),
		"the same committed Aurora receipt cannot translate the controller twice")
	journey.call(&"retire_aurora_visit")
	ship.set_piloted(false)
	game.set("_piloting", false)
	await _cleanup(game)


func _roster_entry(entries: Array, node: Node3D) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.instance_id == node.get_instance_id(): return entry
	return {}


func _check_roster_cache_lifecycle(game: GameFlow, owner: CommonWorldOriginRebaseOwner) -> void:
	_check(has_signal(&"node_added") and has_signal(&"node_removed") and has_signal(&"node_renamed"),
		"actual SceneTree exposes synchronous topology and rename signals")
	var ancestor := Node.new()
	ancestor.name = "CacheAncestor"
	game.add_child(ancestor)
	var probe := RosterCapabilityProbe.new()
	probe.name = "CacheProbe"
	ancestor.add_child(probe)
	# Insert out of order under a plain Node, including case, numeric text and
	# a parent-path prefix. Preserve the original String < comparator contract.
	for probe_name in ["a", "A2", "Z", "A10", "A"]:
		var ordering_probe := Node3D.new()
		ordering_probe.name = probe_name
		ancestor.add_child(ordering_probe)
	var prefix_child := Node3D.new()
	prefix_child.name = "AChild"
	ancestor.get_node(^"A").add_child(prefix_child)
	var first := owner._capture_live_roster()
	var first_revision := int(owner.get("_roster_cache_revision"))
	var paths: Array[String] = []
	for entry: Dictionary in first.covered: paths.append(entry.path)
	var sorted_paths := paths.duplicate()
	sorted_paths.sort_custom(func(a: String, b: String) -> bool: return a < b)
	var ordering_paths: Array[String] = []
	for path: String in paths:
		if path.begins_with("CacheAncestor/") and path != "CacheAncestor/CacheProbe":
			ordering_paths.append(path)
	_check(ordering_paths == ["CacheAncestor/A", "CacheAncestor/A/AChild",
		"CacheAncestor/A10", "CacheAncestor/A2", "CacheAncestor/Z", "CacheAncestor/a"],
		"cold capture preserves case-sensitive lexical, numeric-text and prefix order through plain ancestors")
	_check(bool(first.accepted) and paths == sorted_paths and not _roster_entry(first.covered, probe).is_empty(),
		"cold capture discovers and lexically orders the complete live roster")
	var warm := owner._capture_live_roster()
	_check(bool(warm.accepted) and first_revision == int(owner.get("_roster_cache_revision"))
		and first.covered == warm.covered, "unchanged topology reuses structure with an identical public roster")
	probe.position = Vector3(3.0, 4.0, 5.0)
	var transformed := owner._capture_live_roster()
	_check((_roster_entry(transformed.covered, probe).transform as Transform3D).is_equal_approx(probe.transform)
		and first_revision == int(owner.get("_roster_cache_revision")), "warm capture reads fresh transforms")
	probe.top_level = true
	var top := owner._capture_live_roster()
	_check(_roster_entry(top.roots, probe).get("mode", &"") == &"top_level",
		"warm capture reclassifies a changed top-level flag")
	probe.eligible = false
	_check(_roster_entry(owner._capture_live_roster().roots, probe).is_empty(),
		"warm capture reevaluates translation-root capability")
	probe.eligible = true
	var added := Node3D.new()
	added.name = "CacheAdded"
	game.add_child(added)
	_check(not _roster_entry(owner._capture_live_roster().covered, added).is_empty()
		and int(owner.get("_roster_cache_revision")) != first_revision, "node addition invalidates cached structure")
	game.remove_child(added)
	_check(_roster_entry(owner._capture_live_roster().covered, added).is_empty(),
		"node removal invalidates cached structure")
	ancestor.add_child(added)
	probe.reparent(added)
	_check(_roster_entry(owner._capture_live_roster().covered, probe).path == "CacheAncestor/CacheAdded/CacheProbe",
		"reparenting refreshes cached host-relative paths")
	ancestor.name = "RenamedPlainAncestor"
	_check(_roster_entry(owner._capture_live_roster().covered, probe).path == "RenamedPlainAncestor/CacheAdded/CacheProbe",
		"renaming a plain Node ancestor synchronously invalidates descendant paths")
	probe.rename_during_capture = true
	_check(owner._capture_live_roster().get("reason") == &"world_roster_changed",
		"a structural mutation inside a capability callback fails closed without retry")
	owner._capture_live_roster()
	probe.queue_free()
	_check(owner._capture_live_roster().get("reason") == &"queued_or_detached_world_node",
		"warm cache refuses a queued node before the removal signal")
	ancestor.queue_free()
	await process_frame


func _check_live_owner_validation(game: GameFlow, owner: CommonWorldOriginRebaseOwner) -> void:
	var nested := Node.new()
	game.add_child(nested)
	var other_host := Node.new()
	root.add_child(other_host)
	var unrelated := Node.new()
	unrelated.add_to_group(CommonWorldOriginRebaseOwner._LIVE_OWNER_GROUP)
	nested.add_child(unrelated)
	_check(bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 1,
		"group members without the actual owner type cannot change the live census")
	var duplicate := OwnerSubclassProbe.new()
	nested.add_child(duplicate)
	_check(not bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 2,
		"base construction registers nested owner subclasses despite overridden lifecycle callbacks")
	duplicate.reparent(other_host)
	_check(bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 1,
		"reparenting a duplicate outside this host restores the next live validation")
	duplicate.reparent(nested)
	_check(not bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 2,
		"reparenting the same duplicate back immediately refuses validation")
	duplicate.queue_free()
	_check(not bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 2,
		"queued duplicate owners still count until actual tree removal")
	await process_frame
	_check(bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 1,
		"freeing a duplicate restores validation without a retained validity cache")
	duplicate = OwnerSubclassProbe.new()
	nested.add_child(duplicate)
	nested.remove_child(duplicate)
	_check(bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 1,
		"removing an owner immediately removes it from this host's census")
	nested.add_child(duplicate)
	_check(not bool(owner.get_live_validation().valid) and int(owner.audit().owner_count) == 2,
		"the same removed owner registers again on tree re-entry")
	nested.remove_child(duplicate)
	duplicate.free()
	nested.free()
	other_host.free()

	var detached_host := Node.new()
	var detached_owner := CommonWorldOriginRebaseOwner.new()
	var detached_nested := Node.new()
	var detached_duplicate := OwnerSubclassProbe.new()
	detached_host.add_child(detached_owner)
	detached_host.add_child(detached_nested)
	detached_nested.add_child(detached_duplicate)
	_check(int(detached_owner.get_live_validation().owner_count) == 2
		and int(detached_owner.audit().owner_count) == 2,
		"out-of-tree validation keeps the original recursive nested-owner scope")
	detached_nested.remove_child(detached_duplicate)
	detached_duplicate.free()
	_check(int(detached_owner.get_live_validation().owner_count) == 1
		and int(detached_owner.audit().owner_count) == 1,
		"out-of-tree owner removal is reflected without a SceneTree index")
	detached_host.free()

	owner._commit_adapter = Callable(self, &"_reject_commit")
	_check(not bool(owner.get_live_validation().valid)
		and owner.get_live_validation().errors == owner.audit().errors,
		"compact validation retains the production test-adapter refusal")
	owner._commit_adapter = Callable()
	owner.set_process(true)
	_check(not bool(owner.get_live_validation().valid)
		and owner.get_live_validation().errors == owner.audit().errors,
		"compact validation retains the automatic process refusal")
	owner.set_process(false)
	owner.set_physics_process(true)
	_check(not bool(owner.get_live_validation().valid)
		and owner.get_live_validation().errors == owner.audit().errors,
		"compact validation retains the automatic physics refusal")
	owner.set_physics_process(false)


func _prepare_network_origin_probes(game: GameFlow, craft: HeroShip) -> Dictionary:
	var stream := game._network_craft_pose_stream
	stream.bind_replica_craft_presentations([craft])
	var canonical: Array = []
	for tick: int in [20, 30, 40, 50]:
		var entry := NetworkRemoteCraftPoseStream.build_pose_entry(craft, craft.get_ship_id(), 2, tick)
		entry["position"] = Vector3(float(tick), 300.0, 400.0)
		entry["velocity_world"] = Vector3.ZERO
		entry["craft_epoch"] = 7
		canonical.append(NetworkRemoteCraftPoseStream.pack_display_facts(
			game._shift_network_craft_pose_entries([entry], -game.world.global_position)))
	var admitted := stream.consume_movement_section(canonical[0], 0, game.world.global_position)
	admitted += stream.consume_movement_section(canonical[1], 0, game.world.global_position)
	stream._clock = 31.0
	var proxy := Node3D.new()
	proxy.name = "OriginCraftInterpolationProbe"
	game.add_child(proxy)
	stream.interpolate_observer(proxy, craft.get_ship_id())
	var probe_root := Node3D.new()
	probe_root.name = "OriginFlightProbes"
	game.add_child(probe_root)
	var authority := LiveCombatAuthority.new()
	probe_root.add_child(authority)
	var bolt := TravellingBoltProjectile.new()
	var seeker := SeekerTorpedoProjectile.new()
	var targets: Array = []
	var launches: Array = []
	var results: Array = []
	var replicator := game._ensure_network_remote_projectile_replicator()
	var published: Array = []
	replicator.set_publisher(func(record: Dictionary, terminal: bool, _recipients: Array) -> Dictionary:
		published.append({"projectile": record.duplicate(true), "terminal": terminal})
		return {"accepted": true})
	for index in 2:
		var source := Node3D.new()
		probe_root.add_child(source)
		source.global_position = Vector3(200.0 + 400.0 * index, 300.0, 400.0)
		var target := StaticBody3D.new()
		probe_root.add_child(target)
		target.global_position = source.global_position + Vector3.FORWARD * 60.0
		target.collision_layer = Layers.SHIP_BODY_LAYER
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 6.0
		shape.shape = sphere
		target.add_child(shape)
		var health := Damageable.new()
		health.faction_id = &"origin_target"
		target.add_child(health)
		targets.append(health)
		var pool = bolt if index == 0 else seeker
		source.add_child(pool)
		pool.bind_authority(authority)
		authority.register_source(source, 9801 + index, &"origin_source", {&"origin_probe": {
			"range": 200.0, "damage": 10.0, "origin_tolerance": 4.0,
			"projectile_speed": 40.0, "projectile_lifetime": 5.0, "projectile_radius": 0.2}})
		replicator.observe_pool(pool, NetworkRemoteProjectileReplicator.KIND_SLUG if index == 0
			else NetworkRemoteProjectileReplicator.KIND_TORPEDO, &"origin_probe")
		if index == 0:
			bolt.bolt_resolved.connect(func(_record: Dictionary, result: Dictionary) -> void: results.append(result))
			launches.append(bolt.launch(source, &"origin_probe", source.global_position, Vector3.FORWARD))
		else:
			seeker.torpedo_resolved.connect(func(_record: Dictionary, result: Dictionary) -> void: results.append(result))
			launches.append(seeker.launch(source, &"origin_probe", source.global_position, Vector3.FORWARD, target))
		pool._advance_slot(int(launches.back().slot_index), 0.1)
		pool.set_physics_process(false)
	var visual_packet := {"projectile": {"projectile_id": &"origin_visual", "position": Vector3(800.0, 300.0, 400.0),
		"direction": Vector3.FORWARD, NetworkRemoteProjectileReplicator.RECORD_KEY: {
			"kind": NetworkRemoteProjectileReplicator.KIND_SLUG, "speed": 10.0, "lifetime": 5.0}}}
	var presented := replicator.present_packet(visual_packet, &"projectile_presented")
	replicator.set_process(false)
	_check(admitted == 2 and bool(launches[0].accepted) and bool(launches[1].accepted) and bool(presented.accepted),
		"real craft histories, authority flights and remote projectile presentation are live before origin commit")
	return {"craft": craft, "proxy": proxy, "proxy_position": proxy.global_position, "canonical": canonical,
		"canonical_copy": canonical.duplicate(true), "replicator": replicator, "published": published,
		"bolt": bolt, "seeker": seeker, "launches": launches, "authority": authority,
		"targets": targets, "results": results}


func _check_network_origin_probes(game: GameFlow, probes: Dictionary, delta: Vector3) -> void:
	var stream := game._network_craft_pose_stream
	var ship_id := (probes.craft as HeroShip).get_ship_id()
	_check((stream.latest_sample(ship_id).position as Vector3).is_equal_approx(Vector3(30.0, 300.0, 400.0) + delta)
		and probes.canonical == probes.canonical_copy and stream._epoch == 7,
		"commit migrates local craft histories once while canonical packets and session epoch stay intact")
	stream.interpolate_observer(probes.proxy, ship_id)
	_check((probes.proxy as Node3D).global_position.is_equal_approx((probes.proxy_position as Vector3) + delta),
		"retained interpolation brackets continue coherently after the real owner commit")
	(probes.proxy as Node3D).global_position = stream.latest_sample(ship_id).position
	_check(stream.reconcile_pilot(probes.proxy, ship_id, 0.0, 1.0 / 60.0).status == &"within_deadband",
		"pilot reconciliation sees the translated history without a corrective snap")
	var replicator := probes.replicator as NetworkRemoteProjectileReplicator
	var visual := replicator._visuals[&"origin_visual"] as Dictionary
	var expected_visual := Vector3(800.0, 300.0, 400.0) + delta
	_check(replicator.get_visual_position(&"origin_visual").is_equal_approx(expected_visual)
		and (visual.root as Node3D).global_position.is_equal_approx(expected_visual),
		"active projectile cache and top-level visual receive the delta exactly once")
	replicator._process(0.1)
	_check(replicator.get_visual_position(&"origin_visual").is_equal_approx(expected_visual + Vector3.FORWARD),
		"the next presentation step keeps its translated trajectory and correction target")
	replicator.republish_for_peer(2)
	var republished := (probes.published as Array).slice(-2)
	_check(((republished[0].projectile.position as Vector3) - (Vector3(200.0, 300.0, 400.0) + delta)).length() < 20.0
		and ((republished[1].projectile.position as Vector3) - (Vector3(600.0, 300.0, 400.0) + delta)).length() < 20.0,
		"late-join host records retain the moved launch origins before any steering republish")
	for index in 2:
		var pool = probes.bolt if index == 0 else probes.seeker
		var slot := pool._slots[int(probes.launches[index].slot_index)] as Dictionary
		var origin := Vector3(200.0 + 400.0 * index, 300.0, 400.0) + delta
		pool._advance_slot(int(probes.launches[index].slot_index), 0.1)
		_check(bool(slot.active) and (slot.position as Vector3).is_equal_approx(origin + Vector3.FORWARD * 8.0)
			and (probes.authority.resolver.get_projectile_flight_snapshot(int(slot.flight_id)).launch_origin as Vector3).is_equal_approx(origin)
			and is_equal_approx(float(slot.elapsed), 0.2) and is_equal_approx(float(slot.travelled), 8.0),
			"translated %s flight advances without false contact or widened travel envelope" % ("bolt" if index == 0 else "seeker"))
	for _step in 100:
		(probes.bolt as TravellingBoltProjectile)._advance_slot(int(probes.launches[0].slot_index), 0.02)
		(probes.seeker as SeekerTorpedoProjectile)._advance_slot(int(probes.launches[1].slot_index), 0.02)
	_check(probes.results.size() == 2 and bool(probes.results[0].damaged) and bool(probes.results[1].damaged)
		and is_equal_approx((probes.targets[0] as Damageable).get_health(), 90.0)
		and is_equal_approx((probes.targets[1] as Damageable).get_health(), 90.0)
		and (probes.authority as LiveCombatAuthority).get_active_projectile_flight_count() == 0,
		"both real translated flights resolve their legitimate arrivals once through authority")
	var delayed := stream.consume_movement_section(probes.canonical[2], 0, game.world.global_position)
	var fresh := stream.consume_movement_section(probes.canonical[3], 0, game.world.global_position)
	_check(delayed == 1 and fresh == 1
		and (stream.latest_sample(ship_id).position as Vector3).is_equal_approx(Vector3(50.0, 300.0, 400.0) + delta)
		and probes.canonical == probes.canonical_copy,
		"delayed and fresh canonical movement records decode against the current moved station origin")
	replicator.clear_host(false)
	replicator.clear_presentation()
	stream._clock = -1.0


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
