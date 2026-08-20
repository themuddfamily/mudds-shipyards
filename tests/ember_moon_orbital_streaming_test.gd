extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const EMBER_SCENE := preload("res://scenes/world/planets/ember_moon.tscn")
const EXPECTED_ASSERTIONS := 48

var _assertions := 0
var _failures := PackedStringArray()


class ManualLoader extends RefCounted:
	var requests: Array[Dictionary] = []

	func request_scene(
		definition: WorldLocationDefinition,
		generation: int,
		completion: Callable
	) -> bool:
		requests.append({
			"location_id": definition.location_id,
			"generation": generation,
			"completion": completion,
		})
		return true

	func complete(index: int) -> Dictionary:
		var request := requests[index]
		return request.completion.call(
			request.location_id, request.generation, EMBER_SCENE, &""
		) as Dictionary


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_registry_contract()
	var bootstrap := _bootstrap()
	_test_bootstrap_contract_and_required_rebase(bootstrap)
	await _test_exact_lifecycle_and_observations(bootstrap)
	await _test_stale_completion_and_reentry()
	await _test_detached_bootstrap_update_guard()
	await _test_loader_replacement_currentness()
	_test_audit_authority_and_mutation(bootstrap)
	bootstrap.queue_free()
	await process_frame
	_finish()


func _test_registry_contract() -> void:
	var registry := NearbySectorOrbitalRegistry.new()
	var snapshot := registry.get_snapshot()
	var station := registry.get_coordinate(registry.STATION_DATUM_ID)
	var ember := registry.get_coordinate(registry.EMBER_BODY_CENTER_ID)
	_check(
		snapshot.registry_id == &"nearby_sector_orbital_registry"
			and snapshot.frame_id == &"nearby_sector_orbital"
			and snapshot.cell_size_meters == 1_000_000.0,
		"registry freezes the exact shared frame identity and one-million-metre cells",
	)
	_check(
		station.cell_x == 0 and station.cell_y == 0 and station.cell_z == 0
			and station.offset_meters == Vector3.ZERO,
		"station datum is canonical cell zero",
	)
	_check(
		ember.cell_x == 0 and ember.cell_y == 0 and ember.cell_z == -8
			and ember.offset_meters == Vector3.ZERO,
		"Ember body centre is exactly cell -8 on Z",
	)
	var outward := registry.relative_position_meters(
		registry.STATION_DATUM_ID, registry.EMBER_BODY_CENTER_ID
	)
	var inward := registry.relative_position_meters(
		registry.EMBER_BODY_CENTER_ID, registry.STATION_DATUM_ID
	)
	_check(outward.position_meters == Vector3(0.0, 0.0, -8_000_000.0), "station-to-Ember displacement is exactly 8,000 km on -Z")
	_check(inward.position_meters == Vector3(0.0, 0.0, 8_000_000.0), "relative displacement is exactly reversible")
	station.cell_z = 99
	_check(registry.get_coordinate(registry.STATION_DATUM_ID).cell_z == 0, "coordinate results are detached")
	var malformed := registry.get_coordinate(registry.STATION_DATUM_ID)
	malformed["extra"] = true
	_check(registry.validate_coordinate(malformed).reason == &"coordinate_schema_mismatch", "coordinate validation rejects extra fields")
	var boundary := registry.get_coordinate(registry.STATION_DATUM_ID)
	boundary.offset_meters = Vector3(500_000.0, 0.0, 0.0)
	_check(registry.validate_coordinate(boundary).reason == &"coordinate_offset_not_canonical", "positive half-cell offsets are excluded")
	_check(registry.relative_position_meters(&"missing", registry.EMBER_BODY_CENTER_ID).reason == &"unknown_point", "unknown registry points fail closed")
	_check(registry.audit().valid, "the immutable registry audits green")


func _test_bootstrap_contract_and_required_rebase(
		bootstrap: EmberMoonStreamingBootstrap
	) -> void:
	var frame := bootstrap.get_coordinate_frame_for_session()
	var snapshot := bootstrap.get_snapshot()
	_check(
		bootstrap.position == Vector3(0.0, 0.0, -8_000_000.0)
			and bootstrap.get_child_count() == 1
			and bootstrap.get_node_or_null(^"WorldStreamingCoordinator") != null,
		"bootstrap begins at the station-relative body centre with one private coordinator",
	)
	_check(
		frame != null and frame.get_generation() == 1
			and snapshot.coordinate_frame.body_radius_meters == 120_000.0
			and snapshot.coordinate_frame.origin_shift_threshold_meters == 10_000.0,
		"coordinate frame freezes Ember radius, shift threshold, and generation one",
	)
	_check(
		snapshot.navigation_anchor_body_local_meters == Vector3(0.0, 130_000.0, 0.0)
			and snapshot.scene_origin_body_local_meters == Vector3.ZERO,
		"location registration separates body-local navigation from the scene origin",
	)
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var blocked := bootstrap.update_absolute_focus(body_coordinate, 1)
	_check(blocked.reason == &"rebase_required_before_load" and bootstrap.get_loaded_instance() == null, "near focus cannot load a body still eight million metres from streaming zero")
	var request := frame.request_rebase(bootstrap.position, 1)
	_check(request.accepted and request.request.world_translation_delta == Vector3(0.0, 0.0, 8_000_000.0), "caller receives the exact station-to-Ember rebase delta")
	var pending := bootstrap.update_absolute_focus(body_coordinate, 1)
	_check(pending.reason == &"rebase_pending", "streaming updates reject while caller rebase work is pending")
	bootstrap.position += request.request.world_translation_delta
	var commit := frame.commit_rebase(request.request.request_id, 1)
	_check(commit.accepted and frame.get_generation() == 2 and bootstrap.position == Vector3.ZERO, "caller-applied translation and exact commit establish generation two at Ember")
	_check(bootstrap.update_absolute_focus(body_coordinate, 1).reason == &"stale_generation", "stale focus generations cannot evaluate streaming")
	_check(bootstrap.audit().valid, "post-rebase root alignment audits green")


func _test_exact_lifecycle_and_observations(
		bootstrap: EmberMoonStreamingBootstrap
	) -> void:
	var frame := bootstrap.get_coordinate_frame_for_session()
	var outside := _absolute(frame, Vector3(0.0, 250_001.0, 0.0), 2)
	var no_load := bootstrap.update_absolute_focus(outside, 2)
	_check(no_load.reason == &"outside_load_radius" and bootstrap.get_loaded_instance() == null, "one metre beyond the load boundary remains unloaded")
	var boundary := _absolute(frame, Vector3(0.0, 250_000.0, 0.0), 2)
	var load := bootstrap.update_absolute_focus(boundary, 2)
	_check(load.accepted and load.action == &"load" and load.location_generation == 1, "inclusive 250 km boundary requests load generation one")
	await process_frame
	await process_frame
	var instance := bootstrap.get_loaded_instance()
	_check(is_instance_valid(instance) and instance.name == "WorldLocation_EmberMoon", "bound authored scene completes into the exact coordinator-owned root")
	_check(
		instance.transform == Transform3D.IDENTITY
			and instance.get_meta(&"world_location_id") == &"ember_moon"
			and instance.get_meta(&"world_location_generation") == 1,
		"loaded scene is body-centred identity with exact generation metadata",
	)
	var hold_coordinate := _absolute(frame, Vector3(0.0, 300_000.0, 0.0), 2)
	var hold := bootstrap.update_absolute_focus(hold_coordinate, 2)
	_check(hold.reason == &"within_unload_hysteresis" and bootstrap.get_loaded_instance() == instance, "inclusive 300 km boundary remains loaded")
	var orbit_world := frame.orbital_to_world_streaming_position(
		_absolute(frame, Vector3(0.0, 140_000.0, 0.0), 2), 2
	).position as Vector3
	var observation := bootstrap.create_travel_observation(orbit_world, 1200.0, 2, 1)
	_check(
		observation.accepted and observation.world_id == &"ember_moon"
			and observation.location_generation == 1
			and observation.coordinate_frame_generation == 2,
		"observation binds exact live location and coordinate generations",
	)
	_check(
		observation.body_local_position_meters == Vector3(0.0, 140_000.0, 0.0)
			and observation.radial_distance_meters == 140_000.0
			and observation.altitude_meters == 20_000.0,
		"observation publishes exact body-local radial values for TravelSession",
	)
	var forged := observation.orbital_coordinate as Dictionary
	forged.cell_z = 77
	var fresh := bootstrap.create_travel_observation(orbit_world, 1200.0, 2, 1)
	_check(fresh.orbital_coordinate.cell_z == -8, "observation orbital coordinates are deeply detached")
	_check(bootstrap.create_travel_observation(orbit_world, 1200.0, 1, 1).reason == &"stale_generation", "stale coordinate generations cannot produce observations")
	_check(bootstrap.create_travel_observation(orbit_world, INF, 2, 1).reason == &"invalid_observation_speed", "nonfinite observation speed fails closed")
	var beyond := _absolute(frame, Vector3(0.0, 300_001.0, 0.0), 2)
	var unload := bootstrap.update_absolute_focus(beyond, 2)
	_check(unload.accepted and unload.action == &"unload" and unload.location_generation == 2, "one metre beyond unload boundary retires as generation two")
	await process_frame
	_check(bootstrap.get_loaded_instance() == null and bootstrap.create_travel_observation(Vector3.ZERO, 0.0, 2, 2).reason == &"ember_not_loaded", "unload removes the live observation source")
	var reload := bootstrap.update_absolute_focus(boundary, 2)
	_check(reload.accepted and reload.location_generation == 3, "return to inclusive load boundary starts generation three")
	await process_frame
	await process_frame
	_check(is_instance_valid(bootstrap.get_loaded_instance()) and bootstrap.get_snapshot().location_generation == 3, "reload completes as exact generation three")


func _test_stale_completion_and_reentry() -> void:
	var bootstrap := _bootstrap()
	var frame := bootstrap.get_coordinate_frame_for_session()
	var loader := ManualLoader.new()
	_check(bootstrap.set_scene_loader(Callable(loader, "request_scene")), "manual loader binds before first request")
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var request := frame.request_rebase(bootstrap.position, 1)
	bootstrap.position += request.request.world_translation_delta
	frame.commit_rebase(request.request.request_id, 1)
	var coordinator := bootstrap.get_node(^"WorldStreamingCoordinator") as WorldStreamingCoordinator
	var nested_result := [{}]
	coordinator.location_load_started.connect(func(_id: StringName, _generation: int) -> void:
		nested_result[0] = bootstrap.update_absolute_focus(body_coordinate, 2)
	)
	var load := bootstrap.update_absolute_focus(body_coordinate, 2)
	_check(load.accepted and loader.requests.size() == 1 and nested_result[0].reason == &"update_in_progress", "load signal reentry observes the nesting-safe update guard")
	var far := _absolute(frame, Vector3(0.0, 300_001.0, 0.0), 2)
	var unload := bootstrap.update_absolute_focus(far, 2)
	_check(unload.accepted and unload.location_generation == 2, "pending generation can be retired before completion")
	var stale := loader.complete(0)
	_check(not stale.accepted and stale.reason == &"stale_generation" and bootstrap.get_loaded_instance() == null, "retired async completion is stale and cannot leak a scene")
	bootstrap.queue_free()
	await process_frame


func _test_detached_bootstrap_update_guard() -> void:
	var bootstrap := _bootstrap()
	var frame := bootstrap.get_coordinate_frame_for_session()
	var loader := ManualLoader.new()
	bootstrap.set_scene_loader(Callable(loader, "request_scene"))
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var request := frame.request_rebase(bootstrap.position, 1)
	bootstrap.position += request.request.world_translation_delta
	frame.commit_rebase(request.request.request_id, 1)
	root.remove_child(bootstrap)
	await process_frame
	var detached_before := bootstrap.get_snapshot()
	var detached_update := bootstrap.update_absolute_focus(body_coordinate, 2)
	_check(
		not bootstrap.is_inside_tree()
			and not detached_update.accepted
			and detached_update.reason == &"bootstrap_detached"
			and bootstrap.get_snapshot() == detached_before
			and loader.requests.is_empty(),
		"detached bootstrap rejects focus without retaining a deferred streaming request",
	)
	root.add_child(bootstrap)
	await process_frame
	var reentry_load := bootstrap.update_absolute_focus(body_coordinate, 2)
	_check(
		reentry_load.accepted and reentry_load.action == &"load"
			and reentry_load.location_generation == 1 and loader.requests.size() == 1,
		"reentry permits one fresh current focus request after detached rejection",
	)
	bootstrap.queue_free()
	await process_frame


func _test_loader_replacement_currentness() -> void:
	var bootstrap := _bootstrap()
	var frame := bootstrap.get_coordinate_frame_for_session()
	var loader_a := ManualLoader.new()
	var loader_b := ManualLoader.new()
	var configured_a := bootstrap.set_scene_loader(Callable(loader_a, "request_scene"))
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var request := frame.request_rebase(bootstrap.position, 1)
	bootstrap.position += request.request.world_translation_delta
	frame.commit_rebase(request.request.request_id, 1)
	root.remove_child(bootstrap)
	await process_frame
	var detached_before := bootstrap.get_snapshot()
	var detached_replacement := bootstrap.set_scene_loader(Callable(loader_b, "request_scene"))
	_check(
		configured_a
		and not bootstrap.is_inside_tree()
		and not detached_replacement
		and bootstrap.get_snapshot() == detached_before
		and loader_a.requests.is_empty()
		and loader_b.requests.is_empty(),
		"a detached Ember bootstrap rejects loader replacement without retaining new streaming authority"
	)

	root.add_child(bootstrap)
	await process_frame
	var reentry_load := bootstrap.update_absolute_focus(body_coordinate, 2)
	_check(
		reentry_load.accepted
		and loader_a.requests.size() == 1
		and loader_b.requests.is_empty(),
		"a reentered Ember bootstrap dispatches its fresh load through the retained live loader"
	)
	bootstrap.queue_free()
	await process_frame

	var queued := _bootstrap()
	var queued_loader_a := ManualLoader.new()
	var queued_loader_b := ManualLoader.new()
	var queued_configured_a := queued.set_scene_loader(Callable(queued_loader_a, "request_scene"))
	var queued_before := queued.get_snapshot()
	queued.queue_free()
	var queued_replacement := queued.set_scene_loader(Callable(queued_loader_b, "request_scene"))
	_check(
		queued_configured_a
		and queued.is_inside_tree()
		and queued.is_queued_for_deletion()
		and not queued_replacement
		and queued.get_snapshot() == queued_before
		and queued_loader_a.requests.is_empty()
		and queued_loader_b.requests.is_empty(),
		"a queued Ember bootstrap rejects loader replacement without retained streaming mutation"
	)
	await process_frame


func _test_audit_authority_and_mutation(
		bootstrap: EmberMoonStreamingBootstrap
	) -> void:
	var audit := bootstrap.audit()
	_check(audit.valid and (audit.errors as Array).is_empty(), "loaded generation-three bootstrap audits green")
	_check(_exact_true_keys(audit.owned_capabilities, bootstrap.OWNED_CAPABILITY_KEYS), "audit declares exactly six truthful owned capabilities")
	_check(_exact_false_keys(audit.adjacent_authority, bootstrap.ADJACENT_AUTHORITY_KEYS), "all adjacent runtime authority remains exactly false")
	var detached := audit.snapshot as Dictionary
	(detached.registry as Dictionary)["frame_id"] = &"forged"
	_check(bootstrap.get_snapshot().registry.frame_id == &"nearby_sector_orbital", "bootstrap snapshots are deeply detached")
	var frame := bootstrap.get_coordinate_frame_for_session()
	var request := frame.request_rebase(Vector3(300_001.0, 0.0, 0.0), 2)
	bootstrap.position += request.request.world_translation_delta
	frame.commit_rebase(request.request.request_id, 2)
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var local_retirement := bootstrap.update_absolute_focus(body_coordinate, 3)
	_check(local_retirement.accepted and local_retirement.action == &"unload" and local_retirement.location_generation == 4, "resident scene retires when its aligned body centre leaves the 300 km local envelope")
	bootstrap.position += Vector3.ONE
	_check(not bootstrap.audit().valid, "root transform drift makes the contract audit red")
	bootstrap.position -= Vector3.ONE


func _bootstrap() -> EmberMoonStreamingBootstrap:
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	root.add_child(bootstrap)
	return bootstrap


func _absolute(
		frame: PlanetaryCoordinateFrame,
		body_local_position: Vector3,
		generation: int
	) -> Dictionary:
	var encoded := frame.encode_body_local_position(body_local_position, generation)
	return (encoded.coordinate as Dictionary).orbital_coordinate as Dictionary


func _exact_true_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key) or not candidate[key] is bool or not bool(candidate[key]):
			return false
	return true


func _exact_false_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key) or not candidate[key] is bool or bool(candidate[key]):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions])
	if _failures.is_empty():
		print("PASS: Ember Moon orbital streaming contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(1)
