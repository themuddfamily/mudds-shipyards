extends SceneTree

## Focused contract for generation-safe explicit world streaming. All failure,
## cancellation and stale-callback paths use a controllable fake loader; one
## production PackedScene proves the built-in deferred loader and actual scene
## ownership path without integrating this foundation into `Main`.

const CoordinatorScript := preload("res://scripts/world/world_streaming_coordinator.gd")
const REAL_WORLD_FIXTURE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const REAL_WORLD_DEFINITION := preload("res://assets/world/locations/cinder_reach.tres")

var _assertions := 0
var _failures: Array[String] = []


class FakeLoader extends RefCounted:
	var accepts_requests := true
	var requests: Array[Dictionary] = []

	func request_scene(
		definition: WorldLocationDefinition,
		generation: int,
		completion: Callable
	) -> bool:
		requests.append({
			"definition": definition,
			"generation": generation,
			"completion": completion,
		})
		return accepts_requests

	func complete(index: int, scene: PackedScene, error_reason: StringName = &"") -> Dictionary:
		var request := requests[index]
		var definition := request["definition"] as WorldLocationDefinition
		return (request["completion"] as Callable).call(
			definition.location_id,
			int(request["generation"]),
			scene,
			error_reason
		) as Dictionary


class SynchronousLoader extends RefCounted:
	var scene: PackedScene
	var error_reason: StringName = &""

	func request_scene(
		definition: WorldLocationDefinition,
		generation: int,
		completion: Callable
	) -> bool:
		completion.call(definition.location_id, generation, scene, error_reason)
		return true


class ReentrantUnloadRoot extends Node3D:
	func _enter_tree() -> void:
		var coordinator := get_parent()
		coordinator.call("request_unload", get_meta(&"world_location_id"))


class ReentrantUnregisterRoot extends Node3D:
	func _ready() -> void:
		var coordinator := get_parent()
		coordinator.call("unregister_location", get_meta(&"world_location_id"))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_definition_snapshot_and_synchronous_results()
	await _test_registration_generation_and_failure_recovery()
	await _test_queued_completion_is_inert()
	await _test_direct_runtime_requests_require_live_coordinator()
	await _test_reentrant_scene_entry_and_same_frame_reload()
	await _test_unexpected_loaded_root_retirement()
	await _test_unregister_and_generation_tombstones()
	await _test_real_scene_placement_reentry_and_teardown()
	await _test_audit_is_deep_copy_and_authority_free()
	_finish()


func _test_definition_snapshot_and_synchronous_results() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var original_id: StringName = &"immutable_anchor"
	var original_anchor := Vector3(41.0, -7.0, -303.0)
	var original_scene_origin := Vector3(-12.0, 4.0, 19.0)
	var caller_definition := _definition(original_id, original_anchor)
	caller_definition.scene_origin_position = original_scene_origin
	_check(coordinator.register_location(caller_definition), "the mutation witness registers")
	var exposed_copy := coordinator.get_definition(original_id)
	_check(
		exposed_copy != caller_definition
			and exposed_copy.location_id == original_id
			and exposed_copy.anchor_position == original_anchor
			and exposed_copy.scene_origin_position == original_scene_origin,
		"definition lookup returns a detached snapshot rather than registration authority"
	)
	caller_definition.location_id = &"caller_mutated_identity"
	caller_definition.anchor_position = Vector3(999.0, 999.0, 999.0)
	caller_definition.scene_origin_position = Vector3(999.0, 999.0, 999.0)
	exposed_copy.location_id = &"lookup_mutated_identity"
	exposed_copy.anchor_position = Vector3(-999.0, -999.0, -999.0)
	exposed_copy.scene_origin_position = Vector3(-999.0, -999.0, -999.0)
	var request := coordinator.request_load(original_id)
	_check(
		bool(request.get("accepted", false))
			and request.get("reason") == &"load_requested"
			and not coordinator.get_loading_ids().has("caller_mutated_identity"),
		"caller mutation cannot change registered identity and async acknowledgment is precise"
	)
	var loader_copy := fake.requests[0].get("definition") as WorldLocationDefinition
	_check(
		loader_copy != caller_definition
			and loader_copy != exposed_copy
			and loader_copy.location_id == original_id
			and loader_copy.anchor_position == original_anchor
			and loader_copy.scene_origin_position == original_scene_origin,
		"the injected loader receives another detached definition copy"
	)
	loader_copy.anchor_position = Vector3(700.0, 800.0, 900.0)
	loader_copy.scene_origin_position = Vector3(70.0, 80.0, 90.0)
	var completion := fake.complete(0, _packed_node_3d())
	var instance := coordinator.get_loaded_instance(original_id)
	_check(
		bool(completion.get("accepted", false))
			and instance.transform == Transform3D(Basis.IDENTITY, original_scene_origin)
			and coordinator.get_definition(original_id).anchor_position == original_anchor
			and coordinator.get_definition(original_id).scene_origin_position == original_scene_origin,
		"a frozen nonzero scene origin places independently of the navigation anchor"
	)
	coordinator.queue_free()
	await process_frame

	var synchronous := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(synchronous)
	var synchronous_loader := SynchronousLoader.new()
	synchronous_loader.scene = _packed_node_3d("SynchronousRoot")
	synchronous.set_loader(Callable(synchronous_loader, "request_scene"))
	var synchronous_definition := _definition(&"synchronous_location", Vector3(8.0, 1.0, -88.0))
	synchronous.register_location(synchronous_definition)
	var synchronous_success := synchronous.request_load(synchronous_definition.location_id)
	_check(
		bool(synchronous_success.get("accepted", false))
			and synchronous_success.get("reason") == &"loaded"
			and synchronous.get_loaded_ids() == PackedStringArray(["synchronous_location"]),
		"request_load returns the honest committed result of synchronous success"
	)
	synchronous.request_unload(synchronous_definition.location_id)
	synchronous_loader.scene = null
	synchronous_loader.error_reason = &"synchronous_fixture_failure"
	var synchronous_failure := synchronous.request_load(synchronous_definition.location_id)
	_check(
		bool(synchronous_failure.get("accepted", false))
			and synchronous_failure.get("reason") == &"synchronous_fixture_failure"
			and synchronous.get_loading_ids().is_empty()
			and synchronous.get_loaded_ids().is_empty(),
		"request_load returns the exact committed result of synchronous failure"
	)
	synchronous.queue_free()
	await process_frame


func _test_registration_generation_and_failure_recovery() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	coordinator.name = "FakeStreamingCoordinator"
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	_check(
		coordinator.set_loader(Callable(fake, "request_scene")),
		"an injected asynchronous loader installs before work begins"
	)
	var alpha := _definition(&"alpha_relay", Vector3(14.0, -6.0, -220.0))
	var beta := _definition(&"beta_field", Vector3(-31.0, 9.0, -410.0))
	var invalid := WorldLocationDefinition.new()
	var invalid_scene_origin := _definition(&"invalid_scene_origin", Vector3.ZERO)
	invalid_scene_origin.scene_origin_position = Vector3.INF
	_check(coordinator.register_location(alpha), "a valid location definition registers")
	_check(coordinator.register_location(beta), "a second valid definition registers")
	_check(not coordinator.register_location(alpha), "a duplicate definition ID is rejected")
	_check(not coordinator.register_location(invalid), "an invalid definition is rejected")
	_check(
		not coordinator.register_location(invalid_scene_origin),
		"a non-finite scene origin is rejected independently of a finite navigation anchor"
	)
	var alpha_snapshot := coordinator.get_definition(alpha.location_id)
	_check(
		alpha_snapshot != alpha
			and alpha_snapshot.location_id == alpha.location_id
			and alpha_snapshot.anchor_position == alpha.anchor_position
			and alpha_snapshot.scene_origin_position == alpha.scene_origin_position,
		"the registered definition preserves identity, navigation anchor, and scene origin through a detached copy"
	)
	_check(
		not bool(coordinator.request_load(&"unknown_location").get("accepted", true)),
		"an unknown load request is rejected"
	)

	var signal_observations: Array[Dictionary] = []
	coordinator.location_load_started.connect(
		func(id: StringName, generation: int) -> void:
			signal_observations.append({
				"kind": &"started",
				"id": id,
				"generation": generation,
				"loading_committed": coordinator.get_loading_ids().has(str(id)),
			})
	)
	coordinator.location_loaded.connect(
		func(id: StringName, generation: int, instance: Node3D) -> void:
			signal_observations.append({
				"kind": &"loaded",
				"id": id,
				"generation": generation,
				"loading_cleared": not coordinator.get_loading_ids().has(str(id)),
				"loaded_committed": coordinator.get_loaded_instance(id) == instance,
			})
	)
	coordinator.location_load_failed.connect(
		func(id: StringName, generation: int, reason: StringName) -> void:
			signal_observations.append({
				"kind": &"failed",
				"id": id,
				"generation": generation,
				"reason": reason,
				"state_cleared": not coordinator.get_loading_ids().has(str(id))
					and not coordinator.get_loaded_ids().has(str(id)),
			})
	)
	coordinator.location_unloaded.connect(
		func(id: StringName, generation: int) -> void:
			signal_observations.append({
				"kind": &"unloaded",
				"id": id,
				"generation": generation,
				"state_cleared": not coordinator.get_loading_ids().has(str(id))
					and not coordinator.get_loaded_ids().has(str(id)),
			})
	)

	var first_request := coordinator.request_load(alpha.location_id)
	var first_generation := int(first_request.get("generation", -1))
	_check(
		bool(first_request.get("accepted", false)) and first_generation == 1,
		"the first explicit load creates generation one"
	)
	_check(
		coordinator.get_loading_ids() == PackedStringArray(["alpha_relay"])
			and coordinator.get_loaded_ids().is_empty(),
		"loading and loaded ID queries expose disjoint committed state"
	)
	_check(
		not bool(coordinator.request_load(alpha.location_id).get("accepted", true)),
		"a duplicate in-flight request is rejected"
	)
	_check(
		not bool(coordinator.complete_load(alpha.location_id, 0, _packed_node_3d()).get("accepted", true))
			and coordinator.complete_load(alpha.location_id, 0, _packed_node_3d()).get("reason")
				== &"stale_generation",
		"a callback with the wrong generation is rejected without consuming the request"
	)
	var unknown_callback := coordinator.complete_load(&"not_registered", 1, _packed_node_3d())
	_check(
		not bool(unknown_callback.get("accepted", true))
			and unknown_callback.get("reason") == &"unknown_location",
		"an unknown callback is rejected"
	)

	var packed_alpha := _packed_node_3d("AuthoredAlphaRoot")
	var completed := fake.complete(0, packed_alpha)
	var alpha_instance := coordinator.get_loaded_instance(alpha.location_id)
	_check(
		bool(completed.get("accepted", false))
			and completed.get("reason") == &"loaded"
			and is_instance_valid(alpha_instance),
		"the matching fake-loader callback commits one instance"
	)
	_check(
		alpha_instance.get_parent() == coordinator
			and alpha_instance.name == "WorldLocation_AlphaRelay"
			and not alpha.anchor_position.is_zero_approx()
			and alpha_instance.transform == Transform3D(Basis.IDENTITY, Vector3.ZERO),
		"a nonzero navigation anchor does not double-offset the default-zero scene origin"
	)
	_check(
		alpha_instance.get_meta(&"world_location_id") == alpha.location_id
			and int(alpha_instance.get_meta(&"world_location_generation")) == first_generation,
		"the owned root records stable location and generation identity"
	)
	var duplicate_completion := fake.complete(0, packed_alpha)
	_check(
		not bool(duplicate_completion.get("accepted", true))
			and duplicate_completion.get("reason") == &"duplicate_completion"
			and coordinator.get_child_count() == 1,
		"a duplicate completion cannot instantiate a second root"
	)
	_check(
		not bool(coordinator.request_load(alpha.location_id).get("accepted", true)),
		"a duplicate request for an already-loaded location is rejected"
	)

	var unload_result := coordinator.request_unload(alpha.location_id)
	_check(
		bool(unload_result.get("accepted", false))
			and int(unload_result.get("generation", -1)) == first_generation + 1
			and coordinator.get_loaded_ids().is_empty(),
		"unload retires the generation and commits empty state before returning"
	)
	await process_frame
	_check(not is_instance_valid(alpha_instance), "unload queue-frees the coordinator-owned scene root")
	var stale_after_unload := fake.complete(0, packed_alpha)
	_check(
		not bool(stale_after_unload.get("accepted", true))
			and stale_after_unload.get("reason") == &"stale_generation",
		"a completion racing after unload is stale"
	)
	_check(
		not bool(coordinator.request_unload(alpha.location_id).get("accepted", true)),
		"a duplicate unload is rejected"
	)

	var failing_request := coordinator.request_load(alpha.location_id)
	var failing_generation := int(failing_request.get("generation", -1))
	_check(failing_generation == first_generation + 2, "the next load never reuses a retired generation")
	var failed := fake.complete(1, null, &"fixture_io_failure")
	_check(
		bool(failed.get("accepted", false))
			and failed.get("reason") == &"fixture_io_failure"
			and coordinator.get_loading_ids().is_empty()
			and coordinator.get_loaded_ids().is_empty(),
		"a loader failure clears pending state without creating an instance"
	)
	var recovery_request := coordinator.request_load(alpha.location_id)
	var recovery_generation := int(recovery_request.get("generation", -1))
	_check(recovery_generation == failing_generation + 1, "a failed load can immediately retry with a fresh generation")
	_check(
		bool(fake.complete(2, packed_alpha).get("accepted", false))
			and coordinator.get_loaded_ids() == PackedStringArray(["alpha_relay"]),
		"the retry recovers and commits normally"
	)

	var all_signals_observed_committed_state := true
	for observation in signal_observations:
		match observation.get("kind"):
			&"started":
				all_signals_observed_committed_state = all_signals_observed_committed_state \
					and bool(observation.get("loading_committed", false))
			&"loaded":
				all_signals_observed_committed_state = all_signals_observed_committed_state \
					and bool(observation.get("loading_cleared", false)) \
					and bool(observation.get("loaded_committed", false))
			&"failed", &"unloaded":
				all_signals_observed_committed_state = all_signals_observed_committed_state \
					and bool(observation.get("state_cleared", false))
	_check(all_signals_observed_committed_state, "every signal observer sees state after its transition committed")
	var beta_request := coordinator.request_load(beta.location_id)
	_check(bool(beta_request.get("accepted", false)), "the independent beta request enters loading")
	var replacement_loader := FakeLoader.new()
	_check(
		not coordinator.set_loader(Callable(replacement_loader, "request_scene")),
		"loader replacement is rejected while a request is in flight"
	)
	coordinator.request_unload(beta.location_id)
	coordinator.queue_free()
	await process_frame


func _test_queued_completion_is_inert() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var definition := _definition(&"queued_completion", Vector3(71.0, -4.0, 19.0))
	coordinator.register_location(definition)
	var loaded_signal_count := 0
	var failed_signal_count := 0
	coordinator.location_loaded.connect(
		func(_location_id: StringName, _generation: int, _instance: Node3D) -> void:
			loaded_signal_count += 1
	)
	coordinator.location_load_failed.connect(
		func(_location_id: StringName, _generation: int, _reason: StringName) -> void:
			failed_signal_count += 1
	)
	var request := coordinator.request_load(definition.location_id)
	var pending_snapshot := coordinator.audit()
	coordinator.queue_free()
	var completion := fake.complete(0, _packed_node_3d())
	_check(
		bool(request.get("accepted", false))
			and coordinator.is_queued_for_deletion()
			and not bool(completion.get("accepted", true))
			and completion.get("reason") == &"coordinator_unavailable"
			and coordinator.audit() == pending_snapshot
			and coordinator.get_child_count() == 0
			and loaded_signal_count == 0
			and failed_signal_count == 0,
		"queued coordinator rejects a pending completion before scene ownership or publication mutates"
	)
	await process_frame
	_check(not is_instance_valid(coordinator), "queued completion fixture releases its coordinator cleanly")

	var detached := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(detached)
	var detached_fake := FakeLoader.new()
	detached.set_loader(Callable(detached_fake, "request_scene"))
	var detached_definition := _definition(&"detached_completion", Vector3(-41.0, 8.0, 73.0))
	detached.register_location(detached_definition)
	var detached_loaded_events := PackedStringArray()
	var detached_failed_events := PackedStringArray()
	detached.location_loaded.connect(
		func(location_id: StringName, _generation: int, _instance: Node3D) -> void:
			detached_loaded_events.append(location_id)
	)
	detached.location_load_failed.connect(
		func(location_id: StringName, _generation: int, _reason: StringName) -> void:
			detached_failed_events.append(location_id)
	)
	var detached_request := detached.request_load(detached_definition.location_id)
	root.remove_child(detached)
	await process_frame
	var detached_pending_snapshot := detached.audit()
	var detached_completion := detached_fake.complete(0, _packed_node_3d())
	detached_fake.complete(0, null, &"duplicate_failure")
	_check(
		bool(detached_request.get("accepted", false))
			and not detached.is_inside_tree()
			and not bool(detached_completion.get("accepted", true))
			and detached_completion.get("reason") == &"coordinator_unavailable"
			and detached.audit() == detached_pending_snapshot
			and detached.get_child_count() == 0
			and detached_loaded_events.is_empty()
			and detached_failed_events.is_empty(),
		"detached coordinator rejects a pending completion without retaining scene ownership or publishing an outcome"
	)
	root.add_child(detached)
	await process_frame
	_check(detached.get_loading_ids().is_empty()
		and detached.get_loaded_ids() == PackedStringArray([detached_definition.location_id])
		and detached_loaded_events == PackedStringArray([detached_definition.location_id]),
		"reattachment resumes the retained completion without a manual unload or replacement request")
	var retired_request := detached.request_unload(detached_definition.location_id)
	var fresh_request := detached.request_load(detached_definition.location_id)
	root.remove_child(detached)
	detached_fake.complete(0, _packed_node_3d(), &"obsolete_failure")
	root.add_child(detached)
	await process_frame
	_check(detached.get_loaded_ids().is_empty() and detached.get_loading_ids().size() == 1
		and detached_failed_events.is_empty(),
		"a stale detached callback cannot complete or fail the replacement generation")
	var fresh_completion := detached_fake.complete(1, _packed_node_3d())
	_check(
		bool(retired_request.get("accepted", false))
			and bool(fresh_request.get("accepted", false))
			and bool(fresh_completion.get("accepted", false))
			and detached.get_loaded_ids() == PackedStringArray([detached_definition.location_id])
			and detached.get_child_count() == 1
			and detached_loaded_events == PackedStringArray([detached_definition.location_id, detached_definition.location_id])
			and detached_failed_events.is_empty(),
		"a reattached coordinator accepts a fresh pending completion after the old detached generation was retired"
	)
	detached.request_unload(detached_definition.location_id)
	detached.request_load(detached_definition.location_id)
	root.remove_child(detached)
	detached_fake.complete(2, _packed_node_3d())
	root.add_child(detached)
	# Retire the saved completion before the deferred reentry drain executes.
	detached.request_unload(detached_definition.location_id)
	var replacement_request := detached.request_load(detached_definition.location_id)
	await process_frame
	_check(detached.get_loaded_ids().is_empty() and detached.get_loading_ids().size() == 1
		and detached_loaded_events.size() == 2 and detached_failed_events.is_empty(),
		"retirement before reentry drain discards the saved completion without touching its replacement")
	var replacement_completion := detached_fake.complete(3, _packed_node_3d())
	_check(replacement_completion.accepted
		and replacement_completion.generation == replacement_request.generation
		and detached.get_child_count() == 1,
		"the replacement request retains its own completion authority")
	detached.queue_free()
	await process_frame


func _test_direct_runtime_requests_require_live_coordinator() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var definition := _definition(&"runtime_currentness", Vector3(19.0, -3.0, 47.0))
	coordinator.register_location(definition)
	var load_started_events := PackedStringArray()
	var unloaded_events := PackedStringArray()
	coordinator.location_load_started.connect(
		func(location_id: StringName, _generation: int) -> void:
			load_started_events.append(location_id)
	)
	coordinator.location_unloaded.connect(
		func(location_id: StringName, _generation: int) -> void:
			unloaded_events.append(location_id)
	)

	root.remove_child(coordinator)
	await process_frame
	var detached_snapshot := coordinator.audit()
	var detached_load := coordinator.request_load(definition.location_id)
	var detached_unload := coordinator.request_unload(definition.location_id)
	_check(
		not coordinator.is_inside_tree()
			and not bool(detached_load.get("accepted", true))
			and detached_load.get("reason") == &"coordinator_unavailable"
			and not bool(detached_unload.get("accepted", true))
			and detached_unload.get("reason") == &"coordinator_unavailable"
			and coordinator.audit() == detached_snapshot
			and fake.requests.is_empty()
			and load_started_events.is_empty()
			and unloaded_events.is_empty(),
		"detached coordinator rejects direct load and unload before requests, lifecycle publication, or retained state mutate"
	)

	root.add_child(coordinator)
	await process_frame
	var live_load := coordinator.request_load(definition.location_id)
	var live_completion := fake.complete(0, _packed_node_3d())
	_check(
		bool(live_load.get("accepted", false))
			and bool(live_completion.get("accepted", false))
			and coordinator.get_loaded_ids() == PackedStringArray([definition.location_id])
			and coordinator.get_child_count() == 1
			and load_started_events == PackedStringArray([definition.location_id]),
		"reattached coordinator accepts a fresh direct load and owns its completed scene"
	)

	var queued_snapshot := coordinator.audit()
	coordinator.queue_free()
	var queued_load := coordinator.request_load(definition.location_id)
	var queued_unload := coordinator.request_unload(definition.location_id)
	_check(
		coordinator.is_queued_for_deletion()
			and not bool(queued_load.get("accepted", true))
			and queued_load.get("reason") == &"coordinator_unavailable"
			and not bool(queued_unload.get("accepted", true))
			and queued_unload.get("reason") == &"coordinator_unavailable"
			and coordinator.audit() == queued_snapshot
			and fake.requests.size() == 1
			and load_started_events == PackedStringArray([definition.location_id])
			and unloaded_events.is_empty(),
		"queued coordinator rejects direct load and unload without retiring its live scene or publishing lifecycle events"
	)
	await process_frame


func _test_reentrant_scene_entry_and_same_frame_reload() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var definition := _definition(&"reentrant_location", Vector3(17.0, 3.0, -170.0))
	coordinator.register_location(definition)
	var loaded_signal_count := 0
	coordinator.location_loaded.connect(
		func(_id: StringName, _generation: int, _instance: Node3D) -> void:
			loaded_signal_count += 1
	)
	var request := coordinator.request_load(definition.location_id)
	_check(bool(request.get("accepted", false)), "the adversarial scene load enters pending state")
	var retired_completion := fake.complete(0, _packed_reentrant_unload())
	_check(
		not bool(retired_completion.get("accepted", true))
			and retired_completion.get("reason") == &"retired_during_scene_entry",
		"a scene `_enter_tree()` unload retires its provisional generation"
	)
	_check(
		coordinator.get_loading_ids().is_empty()
			and coordinator.get_loaded_ids().is_empty()
			and coordinator.get_child_count() == 0
			and loaded_signal_count == 0,
		"reentrant retirement cannot resurrect state or emit loaded"
	)

	var recovery := coordinator.request_load(definition.location_id)
	_check(
		int(recovery.get("generation", -1)) > int(request.get("generation", -1)),
		"scene-entry retirement advances generation before recovery"
	)
	fake.complete(1, _packed_node_3d())
	var first_instance := coordinator.get_loaded_instance(definition.location_id)
	_check(
		is_instance_valid(first_instance)
			and first_instance.name == "WorldLocation_ReentrantLocation"
			and coordinator.get_child_count() == 1,
		"the recovered generation owns one stable-name child"
	)
	var unload := coordinator.request_unload(definition.location_id)
	_check(
		bool(unload.get("accepted", false))
			and first_instance.get_parent() == null
			and first_instance.is_queued_for_deletion()
			and coordinator.get_child_count() == 0,
		"unload detaches the owned child before deferred queue-free"
	)
	var replacement_request := coordinator.request_load(definition.location_id)
	var replacement_completion := fake.complete(2, _packed_node_3d())
	var replacement := coordinator.get_loaded_instance(definition.location_id)
	_check(
		bool(replacement_request.get("accepted", false))
			and bool(replacement_completion.get("accepted", false))
			and replacement != first_instance
			and replacement.name == "WorldLocation_ReentrantLocation"
			and coordinator.get_child_count() == 1,
		"same-frame unload and reload reuses the exact stable name with one child"
	)
	var unregister_definition := _definition(
		&"reentrant_unregister_location", Vector3(-17.0, 6.0, -210.0)
	)
	coordinator.register_location(unregister_definition)
	coordinator.request_load(unregister_definition.location_id)
	var loaded_count_before_unregister := loaded_signal_count
	var unregister_completion := fake.complete(3, _packed_reentrant_unregister())
	_check(
		not bool(unregister_completion.get("accepted", true))
			and unregister_completion.get("reason") == &"retired_during_scene_entry"
			and coordinator.get_definition(unregister_definition.location_id) == null,
		"a scene `_ready()` unregister retires its provisional generation and definition"
	)
	_check(
		coordinator.get_loaded_ids() == PackedStringArray(["reentrant_location"])
			and coordinator.get_child_count() == 1
			and loaded_signal_count == loaded_count_before_unregister,
		"reentrant unregister leaves no scene, state, or false loaded signal behind"
	)
	await process_frame
	_check(not is_instance_valid(first_instance), "the detached prior generation is deleted on the queued frame")
	coordinator.queue_free()
	await process_frame


func _test_unexpected_loaded_root_retirement() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var definition := _definition(&"self_retiring_location", Vector3(22.0, -2.0, -260.0))
	coordinator.register_location(definition)
	var unload_generations: Array[int] = []
	coordinator.location_unloaded.connect(
		func(id: StringName, generation: int) -> void:
			if id == definition.location_id:
				unload_generations.append(generation)
	)

	var first_request := coordinator.request_load(definition.location_id)
	fake.complete(0, _packed_node_3d())
	var self_retiring := coordinator.get_loaded_instance(definition.location_id)
	self_retiring.queue_free()
	await process_frame
	await process_frame
	_check(
		unload_generations.size() == 1
			and unload_generations[0] > int(first_request.get("generation", -1)),
		"an independently queue-freed root automatically retires once and tombstones its generation"
	)
	var retired_audit := coordinator.audit()
	_check(
		coordinator.get_loaded_instance(definition.location_id) == null
			and coordinator.get_loaded_ids().is_empty()
			and int(retired_audit.get("owned_instance_count", -1)) == 0
			and int(retired_audit.get("unload_count", -1)) == 1
			and (retired_audit.get("loaded_records", []) as Array).is_empty(),
		"getters and audit fail closed after the owned instance is freed"
	)

	var second_request := coordinator.request_load(definition.location_id)
	fake.complete(1, _packed_node_3d())
	var externally_removed := coordinator.get_loaded_instance(definition.location_id)
	coordinator.remove_child(externally_removed)
	var immediate_replacement_request := coordinator.request_load(definition.location_id)
	_check(
		bool(second_request.get("accepted", false))
			and bool(immediate_replacement_request.get("accepted", false))
			and int(immediate_replacement_request.get("generation", -1))
				> int(second_request.get("generation", -1))
			and unload_generations.size() == 2
			and externally_removed.is_queued_for_deletion(),
		"external removal is reconciled synchronously and allows immediate replacement"
	)
	fake.complete(2, _packed_node_3d())
	var replacement := coordinator.get_loaded_instance(definition.location_id)
	_check(
		is_instance_valid(replacement)
			and replacement.name == "WorldLocation_SelfRetiringLocation"
			and replacement.get_parent() == coordinator
			and coordinator.get_child_count() == 1,
		"external-remove recovery commits exactly one exact-name owned child"
	)
	await process_frame
	await process_frame
	_check(
		unload_generations.size() == 2
			and coordinator.get_loaded_instance(definition.location_id) == replacement,
		"the old generation-bound exit callback cannot retire its replacement"
	)
	coordinator.remove_child(replacement)
	await process_frame
	await process_frame
	_check(
		unload_generations.size() == 3
			and coordinator.get_loaded_ids().is_empty()
			and not is_instance_valid(replacement),
		"external removal also retires automatically when no public reconciliation is requested"
	)
	var callback_recovery_request := coordinator.request_load(definition.location_id)
	fake.complete(3, _packed_node_3d())
	_check(
		bool(callback_recovery_request.get("accepted", false))
			and coordinator.get_child_count() == 1,
		"automatic external-removal retirement leaves the location reloadable"
	)
	coordinator.request_unload(definition.location_id)
	await process_frame
	await process_frame
	_check(
		unload_generations.size() == 4,
		"intentional unload erases first and does not double-report through the exit callback"
	)
	coordinator.queue_free()
	await process_frame


func _test_unregister_and_generation_tombstones() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var definition := _definition(&"retired_outpost", Vector3(5.0, 2.0, -90.0))
	_check(coordinator.register_location(definition), "the unregister fixture registers")
	var first_request := coordinator.request_load(definition.location_id)
	var old_generation := int(first_request.get("generation", -1))
	_check(coordinator.unregister_location(definition.location_id), "unregister cancels a pending definition")
	_check(
		coordinator.get_definition(definition.location_id) == null
			and coordinator.get_loading_ids().is_empty(),
		"unregister commits definition and pending-state removal"
	)
	var callback_while_unknown := fake.complete(0, _packed_node_3d())
	_check(
		not bool(callback_while_unknown.get("accepted", true))
			and callback_while_unknown.get("reason") == &"unknown_location",
		"a callback for an unregistered definition is unknown"
	)
	_check(not coordinator.unregister_location(definition.location_id), "duplicate unregister is rejected")
	_check(coordinator.register_location(definition), "the same stable ID may be deliberately re-registered")
	var new_request := coordinator.request_load(definition.location_id)
	var new_generation := int(new_request.get("generation", -1))
	_check(new_generation > old_generation, "re-registration preserves the generation tombstone")
	var stale_after_reregister := fake.complete(0, _packed_node_3d())
	_check(
		not bool(stale_after_reregister.get("accepted", true))
			and stale_after_reregister.get("reason") == &"stale_generation",
		"the pre-unregister callback stays stale after re-registration"
	)
	_check(
		bool(fake.complete(1, _packed_node_3d()).get("accepted", false))
			and coordinator.get_loaded_ids() == PackedStringArray(["retired_outpost"]),
		"only the re-registered generation can commit"
	)
	var owned := coordinator.get_loaded_instance(definition.location_id)
	_check(coordinator.unregister_location(definition.location_id), "unregister tears down a loaded definition too")
	_check(
		owned.get_parent() == null and owned.is_queued_for_deletion(),
		"loaded unregister also detaches before deferred deletion"
	)
	await process_frame
	_check(not is_instance_valid(owned), "loaded unregister uses queue-free teardown")
	coordinator.queue_free()
	await process_frame


func _test_real_scene_placement_reentry_and_teardown() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	coordinator.name = "RealSceneStreamingCoordinator"
	root.add_child(coordinator)
	var definition := REAL_WORLD_DEFINITION as WorldLocationDefinition
	var unexpected_unload_count := 0
	coordinator.location_unloaded.connect(
		func(id: StringName, _generation: int) -> void:
			if id == definition.location_id:
				unexpected_unload_count += 1
	)
	_check(
		coordinator.register_location(definition, REAL_WORLD_FIXTURE),
		"the built-in loader accepts a real checked-in PackedScene binding"
	)
	var request := coordinator.request_load(definition.location_id)
	var generation := int(request.get("generation", -1))
	_check(
		bool(request.get("accepted", false)) and coordinator.get_loading_ids().has("cinder_reach"),
		"the real PackedScene path is deferred and observable as loading"
	)
	await process_frame
	var instance := coordinator.get_loaded_instance(definition.location_id)
	_check(
		instance is NearbySectorCluster
			and instance.get_parent() == coordinator
			and not definition.anchor_position.is_zero_approx()
			and definition.scene_origin_position.is_zero_approx()
			and instance.transform == Transform3D.IDENTITY,
		"the Cinder scene stays at authored world origin instead of receiving its navigation anchor twice"
	)
	_check(
		int(instance.get_meta(&"world_location_generation")) == generation
			and coordinator.get_child_count() == 1,
		"the real fixture has exactly one owned generation"
	)

	root.remove_child(coordinator)
	await process_frame
	await process_frame
	_check(
		is_instance_valid(instance)
			and instance.get_parent() == coordinator
			and coordinator.get_loaded_instance(definition.location_id) == instance
			and unexpected_unload_count == 0,
		"whole-coordinator detach is guarded from child-retirement reconciliation"
	)
	root.add_child(coordinator)
	await process_frame
	await process_frame
	_check(
		coordinator.get_child_count() == 1
			and coordinator.get_loaded_instance(definition.location_id) == instance
			and unexpected_unload_count == 0,
		"whole-coordinator re-entry does not instantiate a duplicate"
	)
	_check(
		not bool(coordinator.request_load(definition.location_id).get("accepted", true)),
		"re-entry still rejects an already-loaded duplicate request"
	)

	coordinator.queue_free()
	await process_frame
	_check(not is_instance_valid(instance), "freeing the coordinator tears down its owned real scene subtree")


func _test_audit_is_deep_copy_and_authority_free() -> void:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	root.add_child(coordinator)
	var fake := FakeLoader.new()
	coordinator.set_loader(Callable(fake, "request_scene"))
	var zeta := _definition(&"zeta_location", Vector3(3.0, 4.0, 5.0))
	var alpha := _definition(&"alpha_location", Vector3(-3.0, -4.0, -5.0))
	coordinator.register_location(zeta)
	coordinator.register_location(alpha)
	coordinator.request_load(zeta.location_id)
	var first := coordinator.audit()
	_check(
		first.get("registered_ids") == PackedStringArray(["alpha_location", "zeta_location"])
			and first.get("loading_ids") == PackedStringArray(["zeta_location"]),
		"audit identifiers are deterministic and sorted"
	)
	var first_generations := first["generation_by_id"] as Dictionary
	first_generations[zeta.location_id] = 999
	var first_loading_records := first["loading_records"] as Array
	(first_loading_records[0] as Dictionary)["generation"] = 999
	first_loading_records.append({"location_id": &"forged", "generation": 999})
	var second := coordinator.audit()
	_check(
		int((second["generation_by_id"] as Dictionary).get(zeta.location_id, -1)) == 1
			and int(((second["loading_records"] as Array)[0] as Dictionary).get("generation", -1)) == 1
			and (second["loading_records"] as Array).size() == 1,
		"mutating nested audit data cannot edit coordinator state"
	)
	_check(
		not bool(second.get("automatic_distance_policy", true))
			and not bool(second.get("gameplay_authority", true))
			and not bool(second.get("grants_rewards", true))
			and not bool(second.get("ship_authority", true))
			and not bool(second.get("berth_authority", true))
			and not bool(second.get("save_authority", true))
			and not bool(second.get("network_authority", true)),
		"the foundation explicitly owns no policy, gameplay, reward, ship, berth, save, or network authority"
	)
	_check(
		second.get("definition_snapshot_policy") \
				== &"deep_copy_on_registration_loader_dispatch_and_read"
			and second.get("parenting_policy") == &"coordinator_child"
			and second.get("transform_policy") == &"identity_basis_at_definition_scene_origin",
		"audit publishes immutable-definition, scene-ownership, and transform policies"
	)
	coordinator.queue_free()
	await process_frame


func _definition(location_id: StringName, anchor: Vector3) -> WorldLocationDefinition:
	var definition := WorldLocationDefinition.new()
	definition.location_id = location_id
	definition.display_name = str(location_id).capitalize()
	definition.sector_id = &"focused_test_sector"
	definition.content_note = "Focused modern-interpretation world-streaming fixture."
	definition.anchor_source_id = &"focused_test_anchor"
	definition.anchor_position = anchor
	return definition


func _packed_node_3d(root_name := "FakeLocationRoot") -> PackedScene:
	var template := Node3D.new()
	template.name = root_name
	var packed := PackedScene.new()
	packed.pack(template)
	template.free()
	return packed


func _packed_reentrant_unload() -> PackedScene:
	var template := ReentrantUnloadRoot.new()
	template.name = "ReentrantUnloadRoot"
	var packed := PackedScene.new()
	packed.pack(template)
	template.free()
	return packed


func _packed_reentrant_unregister() -> PackedScene:
	var template := ReentrantUnregisterRoot.new()
	template.name = "ReentrantUnregisterRoot"
	var packed := PackedScene.new()
	packed.pack(template)
	template.free()
	return packed


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("WORLD_STREAMING_COORDINATOR_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("WORLD_STREAMING_COORDINATOR_TEST_OK")
		quit(0)
	else:
		print("WORLD_STREAMING_COORDINATOR_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
