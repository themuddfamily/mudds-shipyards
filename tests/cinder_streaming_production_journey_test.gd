extends SceneTree

## Focused production composition journey for the physics-driven Main binding.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://cinder-streaming-production-settings.json"

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
	_check(game != null, "production Main instantiates with the Cinder streaming composition")
	if game == null:
		_finish()
		return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store,
			"memory://cinder-streaming-production-legacy.cfg"
		),
		"production journey injects isolated settings before Main startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var player := game.get_node_or_null(^"Player") as PlayerController
	var ship := game.get_guided_ship()
	_check(
		binding != null and bootstrap != null and player != null and ship != null,
		"Main exposes one binding, bootstrap, production Player, and guided ship"
	)
	if binding == null or bootstrap == null or player == null or ship == null:
		await _cleanup(game)
		_finish()
		return

	await _test_composition_startup_and_player_tracking(game, binding, bootstrap, player)
	await _test_ship_outbound_missing_actor_and_reentry(game, binding, bootstrap, player, ship)
	await _cleanup(game)
	await _test_deferred_quality_sync_currentness()
	await _test_queued_binding_boundaries()
	_finish()


func _test_composition_startup_and_player_tracking(
	game: GameFlow,
	binding: CinderStreamingProductionBinding,
	bootstrap: CinderStreamingBootstrap,
	player: PlayerController
	) -> void:
	var report := binding.audit()
	var snapshot := report.get("snapshot", {}) as Dictionary
	var bootstrap_snapshot := snapshot.get("bootstrap", {}) as Dictionary
	var coordinator_snapshot := bootstrap_snapshot.get("coordinator", {}) as Dictionary
	_check(
		bool(report.get("valid", false))
		and int(report.get("binding_count", -1)) == 1
		and int(report.get("bootstrap_count", -1)) == 1
		and int(report.get("coordinator_count", -1)) == 1
		and int(report.get("distance_policy_count", -1)) == 1
		and game.find_children(
			"*", "CinderStreamingProductionBinding", true, false
		).size() == 1,
		"production Main owns exactly one binding, bootstrap, coordinator, and distance policy"
	)
	_check(
		bool(snapshot.get("activated", false))
		and bool(snapshot.get("caller_sample_mode", false))
		and not bool(snapshot.get("provider_bound", true))
		and int(snapshot.get("provider_generation", -1)) == 0
		and not bool(snapshot.get("physics_processing", true))
		and report.get("position_provider_policy")
			== &"caller_supplied_piloted_active_ship_else_live_player"
		and report.get("update_authority")
			== &"one_physics_tick_from_caller_sample",
		"one caller-supplied GameFlow sample drives the existing policy only from physics"
	)
	var provider_generation := int(snapshot.get("provider_generation", -1))
	_check(
		not binding.set_position_provider(Callable(self, &"_forged_position_sample"))
		and int(binding.get_snapshot().get("provider_generation", -2))
			== provider_generation,
		"caller-sampled production mode cannot gain a competing provider"
	)
	_check(
		bootstrap.get_loaded_instance() == null
		and game.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and int(coordinator_snapshot.get("load_request_count", -1)) == 0
		and snapshot.get("last_actor_kind") == &"player"
		and int(snapshot.get("last_actor_instance_id", 0)) == player.get_instance_id(),
		"station start tracks Player with zero resident or streamed Cinder instances"
	)
	_check(
		not bool(report.get("activity_authority", true))
		and not bool(report.get("gameplay_authority", true))
		and not bool(report.get("combat_authority", true))
		and not bool(report.get("reward_authority", true))
		and not bool(report.get("ship_authority", true))
		and not bool(report.get("berth_authority", true))
		and not bool(report.get("save_authority", true))
		and not bool(report.get("network_authority", true))
		and not bool(report.get("runtime_settings_authority", true))
		and not bool(report.get("staged_startup_authority", true)),
		"the binding consumes caller cadence and owns no gameplay, settings, startup, or persistence authority"
	)
	var safe_start := game.get_safe_start_recovery_report()
	_check(
		int(safe_start.get("policy_count", -1)) == 1
		and int(safe_start.get("policy_instance_id", 0)) != 0
		and game.runtime_settings != null,
		"existing SafeStart and RuntimeSettings compositions remain singular after binding activation"
	)
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var route_report := world.get_station_route_registry_report() if world != null else {}
	_check(
		world != null
		and bool(route_report.get("valid", false))
		and world.get_station_service_agents().size() == 7,
		"station-owned route definitions and all seven couriers remain live without resident Cinder geometry"
	)
	var before_tick := binding.get_snapshot()
	await physics_frame
	await process_frame
	var after_tick := binding.get_snapshot()
	_check(
		int(after_tick.get("physics_tick_count", -1))
			> int(before_tick.get("physics_tick_count", -1))
		and int(after_tick.get("policy_update_index", -1))
			- int(after_tick.get("initial_policy_update_index", -1))
			== int(after_tick.get("physics_tick_count", -2))
		and bool(binding.audit().get("valid", false)),
		"policy update count remains exactly equal to binding-owned physics ticks"
	)
	var mutable := binding.get_snapshot()
	(mutable.get("last_tick_result", {}) as Dictionary)["reason"] = &"forged"
	(mutable.get("bootstrap", {}) as Dictionary).clear()
	var detached := binding.get_snapshot()
	_check(
		not (detached.get("bootstrap", {}) as Dictionary).is_empty()
		and (detached.get("last_tick_result", {}) as Dictionary).get("reason")
			!= &"forged",
		"binding snapshots are deeply detached from caller mutation"
	)


func _test_ship_outbound_missing_actor_and_reentry(
	game: GameFlow,
	binding: CinderStreamingProductionBinding,
	bootstrap: CinderStreamingBootstrap,
	player: PlayerController,
	ship: HeroShip
	) -> void:
	var anchor := LOCATION.get_anchor_position()
	var toward_station := (Vector3.ZERO - anchor).normalized()
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	if world != null:
		game.runtime_settings.graphics_profile = RuntimeSettings.GraphicsProfile.LOW
		world.apply_visual_quality(NearbySectorCluster.DetailQuality.LOW)
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * 499.9
	var before_outbound_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_outbound_tick)
	var outbound := binding.get_snapshot()
	var outbound_result := outbound.get("last_tick_result", {}) as Dictionary
	var outbound_transition := _first_transition(outbound_result)
	if outbound_transition.is_empty():
		outbound_transition = _last_policy_outcome(bootstrap)
	_check(
		outbound.get("last_actor_kind") == &"ship"
		and int(outbound.get("last_actor_instance_id", 0)) == ship.get_instance_id()
		and outbound_transition.get("action") == &"load"
		and outbound_transition.get("reason") == &"load_requested"
		and is_equal_approx(float(outbound_transition.get("distance", -1.0)), 499.9),
		"the piloted production ship requests Cinder once on the outbound physics tick"
	)
	await _wait_for_cluster(bootstrap)
	var cluster := bootstrap.get_loaded_instance()
	await _wait_for_quality_sync(binding, cluster.get_instance_id())
	var cluster_ref: WeakRef = weakref(cluster)
	var loaded_snapshot := bootstrap.get_snapshot()
	var loaded_coordinator := loaded_snapshot.get("coordinator", {}) as Dictionary
	var coordinator := bootstrap.get_node_or_null(
		^"WorldStreamingCoordinator"
	) as WorldStreamingCoordinator
	var policy := bootstrap.get_node_or_null(
		^"WorldStreamingDistancePolicy"
	) as WorldStreamingDistancePolicy
	var streamed_cluster_count := bootstrap.find_children(
		"*", "NearbySectorCluster", true, false
	).size()
	print(
		"CINDER_PRODUCTION_LOADED: generation=",
		outbound_transition.get("generation", -1),
		" requests=", loaded_coordinator.get("load_request_count", -1),
		" owned=", loaded_coordinator.get("owned_instance_count", -1)
	)
	print(
		"CINDER_PRODUCTION_PRESENTATION: synced=",
		binding.get_snapshot().get("quality_synced_instance_id", 0),
		" cluster=", cluster.get_instance_id(),
		" quality=", cluster.get_detail_quality(),
		" whole_count=", game.find_children("*", "NearbySectorCluster", true, false).size()
	)
	_check(
		cluster is NearbySectorCluster
		and cluster.transform == Transform3D.IDENTITY
		and cluster.get_parent() == coordinator
		and world != null
		and world.get_nearby_sector_cluster() == cluster
		and bool(world.get_nearby_sector_cluster_audit_report().get("valid", false))
		and int(cluster.get_meta(&"world_location_generation", -1))
			== int(outbound_transition.get("generation", -2))
		and int(loaded_coordinator.get("load_request_count", -1)) == 1
		and int(loaded_coordinator.get("owned_instance_count", -1)) == 1
		and streamed_cluster_count == 1
		and game.find_children("*", "NearbySectorCluster", true, false).size() == 1
		and int(binding.get_snapshot().get("quality_synced_instance_id", 0))
			== cluster.get_instance_id()
		and cluster.get_detail_quality() == NearbySectorCluster.DetailQuality.LOW
		and (cluster.get_node_or_null(
			^"RouteBeacons/RouteBeaconAlpha/SignalRing"
		) as MeshInstance3D).mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
		and not (cluster.get_node_or_null(
			^"DebrisField/DebrisChips"
		) as MultiMeshInstance3D).visible,
		"the sole real zero-origin Cinder cluster commits once and receives the retained quality"
	)

	# No actor is a fail-closed tracking loss, not an unload decision. The Player
	# is detached without freeing it and the ship relinquishes its pilot flag.
	ship.set_piloted(false)
	var player_owner := player.owner
	var player_index := player.get_index()
	player.owner = null
	game.remove_child(player)
	var before_missing_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_missing_tick)
	var missing := binding.get_snapshot()
	var missing_policy := (
		(missing.get("bootstrap", {}) as Dictionary).get("distance_policy", {})
		as Dictionary
	)
	_check(
		missing.get("last_sample_reason") == &"no_tracked_production_actor"
		and (missing.get("last_tick_result", {}) as Dictionary).get("reason")
			== &"tracking_unavailable"
		and not bool(missing_policy.get("tracking_available", true))
		and bootstrap.get_loaded_instance() == cluster,
		"missing production actors clear tracking, tick once, and preserve the loaded cluster"
	)
	game.add_child(player)
	game.move_child(player, player_index)
	player.owner = player_owner

	ship.set_piloted(true)
	ship.global_position = anchor
	var before_recovered_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_recovered_tick)
	_check(
		binding.get_snapshot().get("last_actor_kind") == &"ship"
		and bootstrap.get_loaded_instance() == cluster,
		"restoring the production actor resumes tracking without a duplicate load"
	)

	var binding_id := binding.get_instance_id()
	var bootstrap_id := bootstrap.get_instance_id()
	var coordinator_id := coordinator.get_instance_id()
	var policy_id := policy.get_instance_id()
	var cluster_id := cluster.get_instance_id()
	var cluster_generation := int(cluster.get_meta(&"world_location_generation", -1))
	var ticks_before_detach := int(binding.get_snapshot().get("physics_tick_count", -1))
	var safe_start_before := game.get_safe_start_recovery_report()
	var settings_id := game.runtime_settings.get_instance_id()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		int(binding.get_snapshot().get("physics_tick_count", -2)) == ticks_before_detach
		and not bool(binding.get_snapshot().get("physics_processing", true))
		and bootstrap.get_loaded_instance() == cluster,
		"whole-Main detach pauses sampling and retains the loaded instance"
	)
	parent.add_child(game)
	await _wait_for_binding_tick(binding, ticks_before_detach)
	await process_frame
	var reentered_safe_start := game.get_safe_start_recovery_report()
	_check(
		binding.get_instance_id() == binding_id
		and bootstrap.get_instance_id() == bootstrap_id
		and coordinator.get_instance_id() == coordinator_id
		and policy.get_instance_id() == policy_id
		and bootstrap.get_loaded_instance() == cluster
		and cluster.get_instance_id() == cluster_id
		and game.find_children("*", "NearbySectorCluster", true, false).size() == 1
		and world.get_nearby_sector_cluster() == cluster
		and int(reentered_safe_start.get("policy_instance_id", 0))
			== int(safe_start_before.get("policy_instance_id", -1))
		and game.runtime_settings.get_instance_id() == settings_id
		and bool(binding.audit().get("valid", false)),
		"whole-Main re-entry preserves streaming, SafeStart, and RuntimeSettings identities without duplicates"
	)

	# Freeze GameFlow's automatic caller tick so the presentation lifecycle can
	# be proven at exact 60 Hz samples without idle/render timing influencing it.
	game.set_physics_process(false)
	ship.global_position = anchor + toward_station * 650.1
	var outside_sample := _ship_sample(ship)
	var holds_before := int(binding.get_snapshot().get(
		"presentation_unload_hold_count", -1
	))
	binding.physics_tick_from_caller_sample(1.0 / 60.0, outside_sample)
	var first_outside := cluster.get_streaming_transition_snapshot() as Dictionary
	var held_policy := (
		bootstrap.get_snapshot().get("distance_policy", {}) as Dictionary
	)
	var held_locations := held_policy.get("locations", []) as Array
	var held_policy_distance := float(
		(held_locations[0] as Dictionary).get("distance", 1000.0)
	) if not held_locations.is_empty() else 1000.0
	_check(
		bootstrap.get_loaded_instance() == cluster
		and first_outside.get("phase") == &"fading_out"
		and float(first_outside.get("opacity", -1.0)) < 1.0
		and float(first_outside.get("opacity", -1.0)) > 0.0
		and int(binding.get_snapshot().get("presentation_unload_hold_count", -1))
			== holds_before + 1
		and held_policy_distance < 650.0
		and is_equal_approx(held_policy_distance, 649.5)
		and is_equal_approx(
			float(binding.get_snapshot().get(
				"presentation_unload_hold_distance_meters", -1.0
			)), 649.5
		),
		"a non-axis-aligned >650m sample is held safely inside the boundary while fading"
	)
	for _tick_index in 29:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, outside_sample)
	var fade_complete := cluster.get_streaming_transition_snapshot() as Dictionary
	var held_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		bootstrap.get_loaded_instance() == cluster
		and fade_complete.get("phase") == &"fade_out_complete"
		and is_zero_approx(float(fade_complete.get("opacity", -1.0)))
		and not bool(fade_complete.get("retire_ready", true))
		and int(held_coordinator.get("unload_count", -1)) == 0,
		"exactly 0.5 caller-physics seconds reaches hidden while generation ownership is retained"
	)
	var returning := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, outside_sample
	)
	var return_transition := _first_transition(returning)
	print("CINDER_PRODUCTION_RETURN_TRANSITION: ", return_transition)
	_check(
		return_transition.get("action") == &"unload"
		and return_transition.get("reason") == &"unloaded"
		and bootstrap.get_loaded_instance() == null
		and int((bootstrap.get_snapshot().get("coordinator", {}) as Dictionary).get(
			"unload_count", -1
		)) == 1,
		"the subsequent still-outside tick retires through the unchanged coordinator policy"
	)
	game.set_physics_process(true)
	await process_frame
	await process_frame
	_check(
		cluster_ref.get_ref() == null
		and bootstrap.find_children(
			"*", "NearbySectorCluster", true, false
		).is_empty()
		and game.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and world.get_nearby_sector_cluster() == null
		and world.get_nearby_sector_cluster_audit_report().get("reason")
			== &"streamed_cluster_unavailable",
		"unload frees the only Cinder generation and leaves no stale world reference"
	)
	ship.set_piloted(false)
	player.global_position = Vector3.ZERO
	var before_station_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_station_tick)
	var final_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		binding.get_snapshot().get("last_actor_kind") == &"player"
		and int(final_coordinator.get("load_request_count", -1)) == 1
		and int(final_coordinator.get("unload_count", -1)) == 1
		and bootstrap.get_loaded_instance() == null
		and bool(binding.audit().get("valid", false)),
		"station return tracks Player again with one load, one unload, and no hysteresis thrash"
	)

	# A second complete production generation proves that the nullable world
	# accessor and presentation forwarding do not retain the retired instance.
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * 499.9
	var before_second_load_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_second_load_tick)
	await _wait_for_cluster(bootstrap)
	# The load is deferred. Read the retained policy outcome after the cluster
	# wait, so a fast headless physics tick cannot leave this assertion holding
	# the preceding station/no-op observation.
	var second_load_outcome := _last_policy_outcome(bootstrap)
	var second_cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	await _wait_for_quality_sync(binding, second_cluster.get_instance_id())
	var second_cluster_ref: WeakRef = weakref(second_cluster)
	var second_generation := int(second_cluster.get_meta(&"world_location_generation", -1))
	var second_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	var second_generation_checks := {
		"load_action": second_load_outcome.get("action") == &"load",
		"load_reason": second_load_outcome.get("reason") == &"load_requested",
		"new_instance": second_cluster.get_instance_id() != cluster_id,
		"generation": second_generation == cluster_generation + 2,
		"coordinator_parent": second_cluster.get_parent() == coordinator,
		"identity_transform": second_cluster.transform == Transform3D.IDENTITY,
		"world_lookup": world.get_nearby_sector_cluster() == second_cluster,
		"single_cluster": game.find_children(
			"*", "NearbySectorCluster", true, false
		).size() == 1,
		"load_request_count": int(second_coordinator.get("load_request_count", -1)) == 2,
		"owned_instance_count": int(second_coordinator.get("owned_instance_count", -1)) == 1,
		"retained_quality": second_cluster.get_detail_quality()
			== NearbySectorCluster.DetailQuality.LOW,
		"quality_sync_count": int(binding.get_snapshot().get("quality_sync_count", -1)) == 2,
		"quality_sync_identity": int(binding.get_snapshot().get(
			"quality_synced_instance_id", 0
		)) == second_cluster.get_instance_id(),
		"torus_normalized": (second_cluster.get_node_or_null(
			^"RouteBeacons/RouteBeaconAlpha/SignalRing"
		) as MeshInstance3D).mesh.has_meta(TorusGeometryBudget.AUTHORED_META),
	}
	var second_generation_valid := true
	for check_value in second_generation_checks.values():
		second_generation_valid = second_generation_valid and bool(check_value)
	if not second_generation_valid:
		print("CINDER_PRODUCTION_SECOND_GENERATION_RED: ", second_generation_checks)
	_check(
		second_generation_valid,
		"a second outbound trip commits one new tombstone-safe generation with retained presentation"
	)
	game.set_physics_process(false)
	ship.global_position = anchor + toward_station * 650.1
	var second_outside_sample := _ship_sample(ship)
	for _tick_index in 30:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, second_outside_sample)
	_check(
		bootstrap.get_loaded_instance() == second_cluster
		and (second_cluster.get_streaming_transition_snapshot() as Dictionary).get("phase")
			== &"fade_out_complete",
		"the second generation also reaches hidden before retirement"
	)
	var second_unload_result := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, second_outside_sample
	)
	var second_unload_outcome := _first_transition(second_unload_result)
	game.set_physics_process(true)
	await process_frame
	await process_frame
	var final_snapshot := bootstrap.get_snapshot()
	var final_coordinator_after_retry := final_snapshot.get("coordinator", {}) as Dictionary
	_check(
		second_unload_outcome.get("action") == &"unload"
		and second_unload_outcome.get("reason") == &"unloaded"
		and bootstrap.get_loaded_instance() == null
		and second_cluster_ref.get_ref() == null
		and game.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and int(final_coordinator_after_retry.get("load_request_count", -1)) == 2
		and int(final_coordinator_after_retry.get("unload_count", -1)) == 2
		and bool(binding.audit().get("valid", false)),
		"the second generation unloads cleanly with no stale instance or duplicate request"
	)


func _wait_for_binding_tick(
	binding: CinderStreamingProductionBinding,
	previous_tick_count: int
	) -> void:
	for _frame in 30:
		await process_frame
		if int(binding.get_snapshot().get("physics_tick_count", -1)) > previous_tick_count:
			return


func _wait_for_cluster(bootstrap: CinderStreamingBootstrap) -> void:
	for _frame in 30:
		if bootstrap.get_loaded_instance() != null:
			return
		await process_frame


func _wait_for_quality_sync(
	binding: CinderStreamingProductionBinding,
	instance_id: int
	) -> void:
	for _frame in 30:
		if int(binding.get_snapshot().get("quality_synced_instance_id", 0)) == instance_id:
			return
		await process_frame


func _first_transition(result: Dictionary) -> Dictionary:
	var transitions := result.get("transitions", []) as Array
	return transitions[0] as Dictionary if not transitions.is_empty() else {}


func _last_policy_outcome(bootstrap: CinderStreamingBootstrap) -> Dictionary:
	var snapshot := bootstrap.get_snapshot()
	var policy := snapshot.get("distance_policy", {}) as Dictionary
	var locations := policy.get("locations", []) as Array
	if locations.is_empty():
		return {}
	return (locations[0] as Dictionary).get("last_outcome", {}) as Dictionary


func _forged_position_sample() -> Dictionary:
	return {
		"available": true,
		"position": LOCATION.get_anchor_position(),
		"actor_kind": &"forged",
		"actor_instance_id": -1,
	}


func _ship_sample(ship: HeroShip) -> Dictionary:
	return {
		"available": true,
		"position": ship.global_position,
		"actor_kind": &"ship",
		"actor_instance_id": ship.get_instance_id(),
	}


func _test_queued_binding_boundaries() -> void:
	var activation_game := MAIN_SCENE.instantiate() as GameFlow
	var activation_store := Store.new(
		"memory://cinder-queued-activation-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		activation_game.configure_runtime_settings_persistence(
			activation_store, "memory://cinder-queued-activation-legacy.cfg"
		),
		"queued activation fixture injects isolated settings before Main startup"
	)
	root.add_child(activation_game)
	var activation_binding := activation_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	if activation_binding != null:
		activation_binding.queue_free()
		activation_binding.call("_activate_scene_binding")
	var activation_snapshot := activation_binding.get_snapshot() if activation_binding != null else {}
	_check(
		activation_binding != null
		and activation_binding.is_queued_for_deletion()
		and not bool(activation_snapshot.get("activated", true))
		and int(activation_snapshot.get("bootstrap_instance_id", -1)) == 0
		and not bool(activation_snapshot.get("provider_bound", true))
		and int(activation_snapshot.get("physics_tick_count", -1)) == 0,
		"queued deferred binding activation remains inert before bootstrap/provider ownership"
	)
	activation_game.queue_free()
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(activation_game),
		"queued activation fixture frees before any deferred binding activation can run"
	)

	var tick_game := MAIN_SCENE.instantiate() as GameFlow
	var tick_store := Store.new(
		"memory://cinder-queued-tick-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		tick_game.configure_runtime_settings_persistence(
			tick_store, "memory://cinder-queued-tick-legacy.cfg"
		),
		"queued tick fixture injects isolated settings before Main startup"
	)
	root.add_child(tick_game)
	await process_frame
	await physics_frame
	await process_frame
	var tick_binding := tick_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var tick_player := tick_game.get_node_or_null(^"Player") as PlayerController
	var before_tick := tick_binding.get_snapshot() if tick_binding != null else {}
	var queued_sample := {
		"available": true,
		"position": tick_player.global_position if tick_player != null else Vector3.ZERO,
		"actor_kind": &"player",
		"actor_instance_id": tick_player.get_instance_id() if tick_player != null else 0,
	}
	if tick_binding != null:
		tick_binding.queue_free()
	var queued_tick := (
		tick_binding.physics_tick_from_caller_sample(
			0.25, queued_sample
		)
		if tick_binding != null else {}
	)
	_check(
		tick_binding != null
		and tick_binding.is_queued_for_deletion()
		and not bool(queued_tick.get("accepted", true))
		and queued_tick.get("reason", &"") == &"binding_unavailable"
		and tick_binding.get_snapshot() == before_tick,
		"queued direct caller tick rejects before streaming counters, policy, or tracking mutate"
	)
	tick_game.queue_free()
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(tick_game),
		"queued tick fixture frees without a late streaming update"
	)


func _test_deferred_quality_sync_currentness() -> void:
	var detached_game := MAIN_SCENE.instantiate() as GameFlow
	var detached_store := Store.new(
		"memory://cinder-detached-quality-sync-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		detached_game.configure_runtime_settings_persistence(
			detached_store, "memory://cinder-detached-quality-sync-legacy.cfg"
		),
		"detached quality-sync fixture injects isolated settings before Main startup"
	)
	root.add_child(detached_game)
	await process_frame
	await physics_frame
	await process_frame
	var detached_binding := detached_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var detached_bootstrap := detached_game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var detached_ship := detached_game.get_guided_ship()
	_check(
		detached_binding != null and detached_bootstrap != null and detached_ship != null,
		"detached quality-sync fixture resolves the live production binding, bootstrap, and ship"
	)
	if detached_binding == null or detached_bootstrap == null or detached_ship == null:
		await _cleanup(detached_game)
		return
	detached_game.set_physics_process(false)
	detached_ship.set_piloted(true)
	detached_ship.global_position = LOCATION.get_anchor_position() + Vector3.FORWARD * 499.9
	var detached_load := detached_binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _ship_sample(detached_ship)
	)
	var detached_before := _quality_sync_snapshot(detached_binding)
	_check(
		bool(detached_load.get("accepted", false))
			and bool(detached_before.get("pending", false)),
		"a real outbound load schedules one deferred retained-quality completion"
	)
	var binding_parent := detached_binding.get_parent()
	if binding_parent != null:
		binding_parent.remove_child(detached_binding)
	detached_binding.call(
		"_complete_deferred_presentation_sync",
		int(detached_before.get("deferred_generation", -1))
	)
	_check(
		not detached_binding.is_inside_tree()
			and _quality_sync_snapshot(detached_binding) == detached_before,
		"a detached deferred quality completion preserves its retained pending and sync state atomically"
	)
	if binding_parent != null:
		binding_parent.add_child(detached_binding)
	await _wait_for_cluster(detached_bootstrap)
	var detached_cluster := detached_bootstrap.get_loaded_instance() as NearbySectorCluster
	if detached_cluster != null:
		await _wait_for_quality_sync(detached_binding, detached_cluster.get_instance_id())
	var detached_after := _quality_sync_snapshot(detached_binding)
	_check(
		detached_cluster != null
			and not bool(detached_after.get("pending", true))
			and int(detached_after.get("sync_count", -1))
				== int(detached_before.get("sync_count", -2)) + 1
			and int(detached_after.get("synced_instance_id", 0)) == detached_cluster.get_instance_id(),
		"a re-entered binding completes one fresh current-generation quality synchronization"
	)
	await _cleanup(detached_game)

	var queued_game := MAIN_SCENE.instantiate() as GameFlow
	var queued_store := Store.new(
		"memory://cinder-queued-quality-sync-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		queued_game.configure_runtime_settings_persistence(
			queued_store, "memory://cinder-queued-quality-sync-legacy.cfg"
		),
		"queued quality-sync fixture injects isolated settings before Main startup"
	)
	root.add_child(queued_game)
	await process_frame
	await physics_frame
	await process_frame
	var queued_binding := queued_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var queued_ship := queued_game.get_guided_ship()
	if queued_binding != null and queued_ship != null:
		queued_game.set_physics_process(false)
		queued_ship.set_piloted(true)
		queued_ship.global_position = LOCATION.get_anchor_position() + Vector3.FORWARD * 499.9
		queued_binding.physics_tick_from_caller_sample(1.0 / 60.0, _ship_sample(queued_ship))
	var queued_before := _quality_sync_snapshot(queued_binding)
	if queued_binding != null:
		queued_binding.queue_free()
		queued_binding.call(
			"_complete_deferred_presentation_sync",
			int(queued_before.get("deferred_generation", -1))
		)
	_check(
		queued_binding != null
			and queued_binding.is_queued_for_deletion()
			and bool(queued_before.get("pending", false))
			and _quality_sync_snapshot(queued_binding) == queued_before,
		"a queued deferred quality completion preserves pending and quality state before disposal"
	)
	await _cleanup(queued_game)


func _quality_sync_snapshot(binding: CinderStreamingProductionBinding) -> Dictionary:
	if binding == null:
		return {}
	var snapshot := binding.get_snapshot()
	return {
		"pending": bool(snapshot.get("deferred_quality_sync_pending", false)),
		"deferred_generation": int(snapshot.get("deferred_quality_sync_generation", -1)),
		"sync_count": int(snapshot.get("quality_sync_count", -1)),
		"synced_instance_id": int(snapshot.get("quality_synced_instance_id", 0)),
	}.duplicate(true)


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	print("CINDER_STREAMING_PRODUCTION_JOURNEY_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_STREAMING_PRODUCTION_JOURNEY_TEST_OK")
		quit(0)
	else:
		print("CINDER_STREAMING_PRODUCTION_JOURNEY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
