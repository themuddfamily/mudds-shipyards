extends SceneTree

## Focused journey and lifecycle contract for the opt-in Cinder composition.
## It never instantiates ShipyardWorld or Main.

const BOOTSTRAP_SCENE := preload("res://scenes/world/components/cinder_streaming_bootstrap.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


class RejectOnceLoader extends RefCounted:
	var requests: Array[Dictionary] = []

	func request_scene(
		definition: WorldLocationDefinition,
		generation: int,
		completion: Callable
	) -> bool:
		requests.append({
			"location_id": definition.location_id,
			"navigation_anchor_position": definition.get_anchor_position(),
			"scene_origin_position": definition.get_scene_origin_position(),
			"generation": generation,
		})
		if requests.size() == 1:
			return false
		completion.call(definition.location_id, generation, CLUSTER_SCENE, &"")
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_checked_contract_explicit_updates_and_detached_audit()
	await _test_station_outbound_cluster_return_journey()
	await _test_exact_thresholds()
	await _test_failure_retry_uses_new_generation()
	_finish()


func _test_checked_contract_explicit_updates_and_detached_audit() -> void:
	var bootstrap := _bootstrap()
	var report := bootstrap.audit()
	var snapshot := report.get("snapshot", {}) as Dictionary
	_check(
		bool(report.get("valid", false))
			and snapshot.get("location_id") == &"cinder_reach"
			and snapshot.get("location_resource_path")
				== "res://assets/world/locations/cinder_reach.tres"
			and snapshot.get("scene_resource_path")
				== "res://scenes/world/components/nearby_sector_cluster.tscn"
			and is_equal_approx(float(snapshot.get("load_radius_meters", -1.0)), 500.0)
			and is_equal_approx(float(snapshot.get("unload_radius_meters", -1.0)), 650.0),
		"the bootstrap freezes the checked Cinder resources and 500/650 metre profile"
	)
	_check(
		snapshot.get("navigation_anchor_position") == Vector3(60.0, -70.0, -700.0)
			and snapshot.get("scene_origin_position") == Vector3.ZERO
			and bootstrap.get_child_count() == 2
			and bootstrap.get_node_or_null(^"WorldStreamingCoordinator") != null
			and bootstrap.get_node_or_null(^"WorldStreamingDistancePolicy") != null,
		"one coordinator and one distance policy retain separate navigation and scene origins"
	)
	_check(
		report.get("update_authority") == &"explicit_only"
			and not bootstrap.is_processing()
			and not bootstrap.is_physics_processing()
			and not bool(report.get("automatic_engine_processing", true))
			and not bool(report.get("gameplay_authority", true))
			and not bool(report.get("mission_authority", true))
			and not bool(report.get("activity_authority", true))
			and not bool(report.get("grants_rewards", true))
			and not bool(report.get("save_authority", true))
			and not bool(report.get("network_authority", true)),
		"the bootstrap has explicit-update authority only and no gameplay, mission, reward, save, or network authority"
	)
	await process_frame
	await process_frame
	var after_idle := bootstrap.get_snapshot()
	var idle_coordinator := after_idle.get("coordinator", {}) as Dictionary
	_check(
		bootstrap.get_loaded_instance() == null
			and (idle_coordinator.get("loading_ids", PackedStringArray()) as PackedStringArray).is_empty()
			and int(idle_coordinator.get("load_request_count", -1)) == 0,
		"tree entry and idle frames never run a hidden streaming update"
	)
	var station_update := bootstrap.update_position(Vector3.ZERO)
	_check(
		bool(station_update.get("accepted", false))
			and int(station_update.get("attempted_count", -1)) == 0
			and bootstrap.set_tracked_position(Vector3.ZERO)
			and bool(bootstrap.physics_tick(0.25).get("accepted", false)),
		"position updates and caller-supplied physics time are explicit public operations"
	)
	var mutable_report := bootstrap.audit()
	var mutable_snapshot := mutable_report.get("snapshot", {}) as Dictionary
	mutable_snapshot["load_radius_meters"] = 1.0
	var mutable_coordinator := mutable_snapshot.get("coordinator", {}) as Dictionary
	(mutable_coordinator.get("registered_ids") as PackedStringArray).append("forged")
	var fresh_report := bootstrap.audit()
	var fresh_snapshot := fresh_report.get("snapshot", {}) as Dictionary
	_check(
		is_equal_approx(float(fresh_snapshot.get("load_radius_meters", -1.0)), 500.0)
			and (fresh_snapshot.get("coordinator", {}) as Dictionary).get("registered_ids")
				== PackedStringArray(["cinder_reach"]),
		"nested audit and snapshot data are detached from bootstrap state"
	)
	await _free_bootstrap(bootstrap)


func _test_station_outbound_cluster_return_journey() -> void:
	var bootstrap := _bootstrap()
	var anchor := LOCATION.get_anchor_position()
	var toward_station := (Vector3.ZERO - anchor).normalized()
	var first_beacon := ROUTE.get_checkpoint_position(0)
	var pre_beacon_load_position := anchor + toward_station * 499.9
	var station := bootstrap.update_position(Vector3.ZERO)
	_check(
		int(station.get("attempted_count", -1)) == 0
			and bootstrap.get_loaded_instance() == null,
		"Cinder remains unloaded at the station"
	)
	var outbound := bootstrap.update_position(pre_beacon_load_position)
	var outbound_transition := _first_transition(outbound)
	var outbound_snapshot := bootstrap.get_snapshot()
	var outbound_coordinator := outbound_snapshot.get("coordinator", {}) as Dictionary
	_check(
		pre_beacon_load_position.length() < first_beacon.length()
			and int(outbound.get("attempted_count", -1)) == 1
			and outbound_transition.get("action") == &"load"
			and is_equal_approx(float(outbound_transition.get("distance", -1.0)), 499.9)
			and outbound_transition.get("reason") == &"load_requested"
			and (outbound_coordinator.get("loading_ids") as PackedStringArray)
				== PackedStringArray(["cinder_reach"])
			and bootstrap.get_loaded_instance() == null,
		"outbound travel requests the deferred cluster load before reaching the first route beacon"
	)
	await process_frame
	var cluster := bootstrap.get_loaded_instance()
	var loaded_snapshot := bootstrap.get_snapshot()
	var loaded_coordinator := loaded_snapshot.get("coordinator", {}) as Dictionary
	_check(
		cluster is NearbySectorCluster
			and cluster.transform == Transform3D.IDENTITY
			and int(cluster.get_meta(&"world_location_generation", -1))
				== int(outbound_transition.get("generation", -2))
			and int(loaded_coordinator.get("owned_instance_count", -1)) == 1
			and int(loaded_coordinator.get("load_request_count", -1)) == 1,
		"the built-in deferred load commits one generation and keeps the authored cluster at zero origin"
	)
	var at_cluster := bootstrap.update_position(anchor)
	_check(
		int(at_cluster.get("attempted_count", -1)) == 0
			and bootstrap.get_loaded_instance() == cluster,
		"arrival at the navigation anchor retains the single loaded cluster"
	)
	_check(
		bootstrap.clear_tracked_position()
			and bootstrap.physics_tick(0.1).get("reason") == &"tracking_unavailable"
			and bootstrap.get_loaded_instance() == cluster
			and bootstrap.set_tracked_position(anchor),
		"temporary tracking loss preserves the loaded Cinder generation"
	)

	var requests_before_detach := int(loaded_coordinator.get("load_request_count", -1))
	root.remove_child(bootstrap)
	await process_frame
	await process_frame
	_check(
		bootstrap.get_loaded_instance() == cluster
			and int((bootstrap.get_snapshot().get("coordinator", {}) as Dictionary).get(
				"load_request_count", -1
			)) == requests_before_detach,
		"whole-bootstrap detach preserves the same instance without replaying a request"
	)
	root.add_child(bootstrap)
	await process_frame
	await process_frame
	var after_reentry := bootstrap.update_now()
	_check(
		int(after_reentry.get("attempted_count", -1)) == 0
			and bootstrap.get_loaded_instance() == cluster,
		"whole-bootstrap re-entry keeps one instance until another explicit update"
	)

	var return_band := bootstrap.update_position(anchor + toward_station * 600.0)
	_check(
		int(return_band.get("attempted_count", -1)) == 0
			and bootstrap.get_loaded_instance() == cluster,
		"return travel through the hysteresis band retains the loaded cluster"
	)
	var return_unload_position := anchor + toward_station * 650.1
	var returning := bootstrap.update_position(return_unload_position)
	var return_transition := _first_transition(returning)
	_check(
		return_unload_position.length() > 0.0
			and return_unload_position.length() < first_beacon.length()
			and return_transition.get("action") == &"unload"
			and return_transition.get("reason") == &"unloaded"
			and bootstrap.get_loaded_instance() == null
			and cluster.get_parent() == null
			and cluster.is_queued_for_deletion(),
		"return travel unloads outside 650 metres before station arrival"
	)
	var unloaded_band := bootstrap.update_position(anchor + toward_station * 600.0)
	var station_return := bootstrap.update_position(Vector3.ZERO)
	_check(
		int(unloaded_band.get("attempted_count", -1)) == 0
			and int(station_return.get("attempted_count", -1)) == 0
			and bootstrap.get_loaded_instance() == null,
		"an unloaded cluster does not thrash back on in the hysteresis band or at the station"
	)
	await _free_bootstrap(bootstrap)


func _test_exact_thresholds() -> void:
	var bootstrap := _bootstrap()
	var anchor := LOCATION.get_anchor_position()
	bootstrap.update_position(Vector3.ZERO)
	var exact_load_position := anchor + Vector3(500.0, 0.0, 0.0)
	var exact_load := bootstrap.update_position(exact_load_position)
	_check(
		is_equal_approx(exact_load_position.distance_to(anchor), 500.0)
			and _first_transition(exact_load).get("action") == &"load",
		"the 500 metre load threshold is inclusive"
	)
	await process_frame
	var exact_unload_position := anchor + Vector3(650.0, 0.0, 0.0)
	var exact_unload := bootstrap.update_position(exact_unload_position)
	_check(
		is_equal_approx(exact_unload_position.distance_to(anchor), 650.0)
			and int(exact_unload.get("attempted_count", -1)) == 0
			and bootstrap.get_loaded_instance() != null,
		"the exact 650 metre unload threshold is retained"
	)
	var outside_unload := bootstrap.update_position(anchor + Vector3(650.01, 0.0, 0.0))
	_check(
		_first_transition(outside_unload).get("action") == &"unload"
			and bootstrap.get_loaded_instance() == null,
		"only travel outside 650 metres unloads"
	)
	await _free_bootstrap(bootstrap)


func _test_failure_retry_uses_new_generation() -> void:
	var bootstrap := _bootstrap()
	var loader := RejectOnceLoader.new()
	_check(bootstrap.set_scene_loader(Callable(loader, "request_scene")), "an explicit loader installs before work begins")
	var failed := bootstrap.update_position(LOCATION.get_anchor_position())
	var failed_transition := _first_transition(failed)
	var failed_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		loader.requests.size() == 1
			and not bool(failed_transition.get("accepted", true))
			and failed_transition.get("reason") == &"loader_rejected"
			and int(failed_coordinator.get("load_failure_count", -1)) == 1
			and bootstrap.get_loaded_instance() == null,
		"a rejected coordinator request leaves no false loaded state"
	)
	var recovered := bootstrap.update_now()
	var recovered_transition := _first_transition(recovered)
	var instance := bootstrap.get_loaded_instance()
	var recovered_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		loader.requests.size() == 2
			and bool(recovered_transition.get("accepted", false))
			and recovered_transition.get("reason") == &"loaded"
			and int(recovered_transition.get("generation", -1))
				> int(failed_transition.get("generation", -1))
			and instance is NearbySectorCluster
			and instance.transform == Transform3D.IDENTITY
			and int(recovered_coordinator.get("owned_instance_count", -1)) == 1,
		"retry commits the checked scene once through a newer generation without double offset"
	)
	_check(
		(loader.requests[1] as Dictionary).get("navigation_anchor_position")
				== LOCATION.get_anchor_position()
			and (loader.requests[1] as Dictionary).get("scene_origin_position") == Vector3.ZERO,
		"the loader receives distinct navigation-anchor and zero-origin definition fields"
	)
	await _free_bootstrap(bootstrap)


func _bootstrap() -> CinderStreamingBootstrap:
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as CinderStreamingBootstrap
	root.add_child(bootstrap)
	return bootstrap


func _free_bootstrap(bootstrap: CinderStreamingBootstrap) -> void:
	if is_instance_valid(bootstrap):
		bootstrap.queue_free()
	await process_frame


func _first_transition(result: Dictionary) -> Dictionary:
	var transitions := result.get("transitions", []) as Array
	return transitions[0] as Dictionary if not transitions.is_empty() else {}


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CINDER_STREAMING_BOOTSTRAP_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_STREAMING_BOOTSTRAP_TEST_OK")
		quit(0)
	else:
		print("CINDER_STREAMING_BOOTSTRAP_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
