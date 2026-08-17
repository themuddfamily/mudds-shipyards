extends SceneTree

## Focused production composition journey for the physics-driven Main binding.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with the Cinder streaming composition")
	if game == null:
		_finish()
		return
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

	ship.global_position = anchor + toward_station * 650.1
	var before_return_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_return_tick)
	var returning := binding.get_snapshot().get("last_tick_result", {}) as Dictionary
	var return_transition := _first_transition(returning)
	if return_transition.is_empty():
		# Headless scheduling may run the following no-op physics tick before its
		# process-frame waiter resumes. The policy retains the committed outcome.
		return_transition = _last_policy_outcome(bootstrap)
	print("CINDER_PRODUCTION_RETURN_TRANSITION: ", return_transition)
	_check(
		return_transition.get("action") == &"unload"
		and return_transition.get("reason") == &"unloaded"
		and bootstrap.get_loaded_instance() == null
		and int((bootstrap.get_snapshot().get("coordinator", {}) as Dictionary).get(
			"unload_count", -1
		)) == 1,
		"return travel unloads the one cluster outside 650 metres"
	)
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
	var second_load_outcome := _last_policy_outcome(bootstrap)
	await _wait_for_cluster(bootstrap)
	var second_cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	await _wait_for_quality_sync(binding, second_cluster.get_instance_id())
	var second_cluster_ref: WeakRef = weakref(second_cluster)
	var second_generation := int(second_cluster.get_meta(&"world_location_generation", -1))
	var second_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		second_load_outcome.get("action") == &"load"
		and second_load_outcome.get("reason") == &"load_requested"
		and second_cluster.get_instance_id() != cluster_id
		and second_generation == cluster_generation + 2
		and second_cluster.get_parent() == coordinator
		and second_cluster.transform == Transform3D.IDENTITY
		and world.get_nearby_sector_cluster() == second_cluster
		and game.find_children("*", "NearbySectorCluster", true, false).size() == 1
		and int(second_coordinator.get("load_request_count", -1)) == 2
		and int(second_coordinator.get("owned_instance_count", -1)) == 1
		and second_cluster.get_detail_quality() == NearbySectorCluster.DetailQuality.LOW
		and int(binding.get_snapshot().get("quality_sync_count", -1)) == 2
		and int(binding.get_snapshot().get("quality_synced_instance_id", 0))
			== second_cluster.get_instance_id()
		and (second_cluster.get_node_or_null(
			^"RouteBeacons/RouteBeaconAlpha/SignalRing"
		) as MeshInstance3D).mesh.has_meta(TorusGeometryBudget.AUTHORED_META),
		"a second outbound trip commits one new tombstone-safe generation with retained presentation"
	)
	ship.global_position = anchor + toward_station * 650.1
	var before_second_unload_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_second_unload_tick)
	var second_unload_outcome := _last_policy_outcome(bootstrap)
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
		print("CINDER_STREAMING_PRODUCTION_JOURNEY_OK")
		quit(0)
	else:
		print("CINDER_STREAMING_PRODUCTION_JOURNEY_FAILED: ", ", ".join(_failures))
		quit(1)
