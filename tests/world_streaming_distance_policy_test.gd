extends SceneTree

## Focused contract for explicit distance-driven world streaming. The policy is
## composed with the production coordinator, while a synchronous scene loader
## keeps the test concerned with ordering and lifecycle rather than import time.

const CoordinatorScript := preload("res://scripts/world/world_streaming_coordinator.gd")
const PolicyScript := preload("res://scripts/world/world_streaming_distance_policy.gd")

var _assertions := 0
var _failures: Array[String] = []


class ControlledLoader extends RefCounted:
	var requests: Array[Dictionary] = []
	var reject_remaining_by_id: Dictionary = {}

	func request_scene(
		definition: WorldLocationDefinition,
		generation: int,
		completion: Callable
	) -> bool:
		requests.append({
			"location_id": definition.location_id,
			"generation": generation,
		})
		var remaining := int(reject_remaining_by_id.get(definition.location_id, 0))
		if remaining > 0:
			reject_remaining_by_id[definition.location_id] = remaining - 1
			return false
		completion.call(definition.location_id, generation, _packed_root(), &"")
		return true

	func _packed_root() -> PackedScene:
		var template := Node3D.new()
		var packed := PackedScene.new()
		packed.pack(template)
		template.free()
		return packed


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_validation_explicit_clock_and_priority_budget()
	await _test_signal_reentry_guard_and_time_overflow()
	await _test_hysteresis_tracking_loss_and_failures()
	await _test_external_retirement_and_detach_reentry()
	await _test_detached_snapshot_and_authority_boundary()
	_finish()


func _test_validation_explicit_clock_and_priority_budget() -> void:
	var fixture := _fixture(2)
	var coordinator := fixture.coordinator as WorldStreamingCoordinator
	var policy := fixture.policy as WorldStreamingDistancePolicy
	var loader := fixture.loader as ControlledLoader
	var invalid_definition := _definition(&"invalid_anchor", Vector3.INF)
	var alpha := _definition(&"alpha_tie", Vector3(-10.0, 0.0, 0.0))
	var beta := _definition(&"beta_tie", Vector3(10.0, 0.0, 0.0))
	var nearest := _definition(&"nearest", Vector3(4.0, 0.0, 0.0))
	nearest.scene_origin_position = Vector3(900.0, 50.0, -1200.0)
	_check(not policy.register_location(invalid_definition, 20.0, 30.0), "non-finite definitions are rejected")
	_check(not policy.register_location(alpha, NAN, 30.0), "non-finite radii are rejected")
	_check(not policy.register_location(alpha, 20.0, 20.0), "a missing hysteresis band is rejected")
	_check(not policy.register_location(alpha, 30.0, 20.0), "inverted thresholds are rejected")
	_check(policy.register_location(beta, 20.0, 30.0), "beta tie location registers")
	_check(policy.register_location(alpha, 20.0, 30.0), "alpha tie location registers")
	_check(policy.register_location(nearest, 20.0, 30.0), "nearest location registers")
	_check(not policy.register_location(alpha, 20.0, 30.0), "duplicate policy registrations are rejected")
	alpha.location_id = &"caller_mutated_alpha"
	alpha.anchor_position = Vector3(500.0, 0.0, 0.0)

	_check(policy.set_tracked_position(Vector3.ZERO), "a finite tracked position is retained")
	await process_frame
	await process_frame
	_check(loader.requests.is_empty(), "the policy never runs from an engine process callback")
	var first_tick := policy.physics_tick(0.25)
	_check(
		bool(first_tick.get("accepted", false))
			and int(first_tick.get("attempted_count", -1)) == 2
			and int(first_tick.get("deferred_candidate_count", -1)) == 1,
		"one caller physics tick obeys the two-request budget"
	)
	_check(
		_request_ids(loader) == PackedStringArray(["nearest", "alpha_tie"])
			and coordinator.get_loaded_instance(&"nearest").position
				== nearest.scene_origin_position,
		"priority uses navigation distance while scene placement uses its independent origin"
	)
	var second_tick := policy.physics_tick(0.25)
	_check(
		int(second_tick.get("attempted_count", -1)) == 1
			and _request_ids(loader) == PackedStringArray(["nearest", "alpha_tie", "beta_tie"]),
		"the deferred location is requested on the next explicit tick"
	)
	var snapshot := policy.get_snapshot()
	_check(
		is_equal_approx(float(snapshot.get("physics_elapsed_seconds", -1.0)), 0.5)
			and snapshot.get("registered_ids") == PackedStringArray(["alpha_tie", "beta_tie", "nearest"]),
		"caller delta alone advances reported physics time and IDs remain sorted"
	)
	_check(not policy.physics_tick(INF).get("accepted", true), "non-finite physics delta is rejected")
	_check(
		not policy.set_tracked_position(Vector3(NAN, 0.0, 0.0))
			and policy.get_snapshot().get("tracked_position") == Vector3.ZERO,
		"an invalid tracked sample is rejected without corrupting the last valid sample"
	)
	await _free_fixture(fixture)


func _test_signal_reentry_guard_and_time_overflow() -> void:
	var fixture := _fixture(1)
	var coordinator := fixture.coordinator as WorldStreamingCoordinator
	var policy := fixture.policy as WorldStreamingDistancePolicy
	var definition := _definition(&"observer_probe", Vector3.ZERO)
	var intruder := _definition(&"observer_intruder", Vector3.ZERO)
	policy.register_location(definition, 10.0, 20.0)
	policy.set_tracked_position(Vector3.ZERO)
	var observer_state: Dictionary = {}
	policy.transition_attempted.connect(func(
		location_id: StringName,
		action: StringName,
		distance: float,
		outcome: Dictionary
	) -> void:
		observer_state["calls"] = int(observer_state.get("calls", 0)) + 1
		observer_state["location_id"] = location_id
		observer_state["action"] = action
		observer_state["distance"] = distance
		observer_state["outcome"] = outcome
		observer_state["snapshot"] = policy.get_snapshot()
		observer_state["budget_mutated"] = policy.set_request_budget(4)
		observer_state["registered"] = policy.register_location(intruder, 10.0, 20.0)
		observer_state["unregistered"] = policy.unregister_location(location_id)
		observer_state["position_mutated"] = policy.set_tracked_position(Vector3.ONE * 999.0)
		policy.clear_tracked_position()
		observer_state["nested_now"] = policy.update_now()
		observer_state["nested_tick"] = policy.physics_tick(0.5)
		observer_state["nested_position"] = policy.update_position(Vector3.ONE)
	)
	var result := policy.physics_tick(0.25)
	var signal_snapshot := observer_state.get("snapshot", {}) as Dictionary
	var signal_location := (signal_snapshot.get("locations", []) as Array)[0] as Dictionary
	var signal_outcome := signal_location.get("last_outcome", {}) as Dictionary
	_check(
		int(observer_state.get("calls", 0)) == 1
			and observer_state.get("location_id") == definition.location_id
			and observer_state.get("action") == &"load"
			and is_equal_approx(float(observer_state.get("distance", -1.0)), 0.0)
			and int(signal_snapshot.get("attempt_count", -1)) == 1
			and int(signal_snapshot.get("accepted_request_count", -1)) == 1
			and int(signal_snapshot.get("rejected_request_count", -1)) == 0
			and signal_outcome == observer_state.get("outcome"),
		"transition observers see the committed outcome and counters"
	)
	_check(
		not bool(observer_state.get("budget_mutated", true))
			and not bool(observer_state.get("registered", true))
			and not bool(observer_state.get("unregistered", true))
			and not bool(observer_state.get("position_mutated", true))
			and (observer_state.get("nested_now", {}) as Dictionary).get("reason")
				== &"evaluation_in_progress"
			and (observer_state.get("nested_tick", {}) as Dictionary).get("reason")
				== &"evaluation_in_progress"
			and (observer_state.get("nested_position", {}) as Dictionary).get("reason")
				== &"evaluation_in_progress",
		"transition observers cannot reenter policy mutation or evaluation"
	)
	var after_signal := policy.get_snapshot()
	_check(
		bool(result.get("accepted", false))
			and int(after_signal.get("request_budget", -1)) == 1
			and int(after_signal.get("update_index", -1)) == 1
			and is_equal_approx(float(after_signal.get("physics_elapsed_seconds", -1.0)), 0.25)
			and bool(after_signal.get("tracking_available", false))
			and after_signal.get("tracked_position") == Vector3.ZERO
			and after_signal.get("registered_ids") == PackedStringArray(["observer_probe"])
			and coordinator.get_definition(intruder.location_id) == null
			and coordinator.get_loaded_ids() == PackedStringArray(["observer_probe"]),
		"rejected observer mutations leave the completed update without drift"
	)
	await _free_fixture(fixture)

	var overflow_fixture := _fixture(1)
	var overflow_policy := overflow_fixture.policy as WorldStreamingDistancePolicy
	overflow_policy.set_tracked_position(Vector3.ZERO)
	var first_huge := overflow_policy.physics_tick(1.0e308)
	var before_overflow := overflow_policy.get_snapshot()
	var overflow := overflow_policy.physics_tick(1.0e308)
	var after_overflow := overflow_policy.get_snapshot()
	_check(
		bool(first_huge.get("accepted", false))
			and not bool(overflow.get("accepted", true))
			and overflow.get("reason") == &"time_overflow"
			and after_overflow == before_overflow,
		"finite physics-time overflow is rejected before any policy state changes"
	)
	await _free_fixture(overflow_fixture)


func _test_hysteresis_tracking_loss_and_failures() -> void:
	var fixture := _fixture(1)
	var coordinator := fixture.coordinator as WorldStreamingCoordinator
	var policy := fixture.policy as WorldStreamingDistancePolicy
	var loader := fixture.loader as ControlledLoader
	var gate := _definition(&"hysteresis_gate", Vector3.ZERO)
	policy.register_location(gate, 10.0, 15.0)
	var initial := policy.update_position(Vector3(10.0, 0.0, 0.0))
	_check(
		int(initial.get("attempted_count", -1)) == 1
			and coordinator.get_loaded_ids() == PackedStringArray(["hysteresis_gate"]),
		"the inclusive load threshold requests a load"
	)
	var inside_band := policy.update_position(Vector3(12.0, 0.0, 0.0))
	_check(
		int(inside_band.get("attempted_count", -1)) == 0
			and coordinator.get_loaded_ids().has("hysteresis_gate"),
		"a loaded location remains loaded inside the hysteresis band"
	)
	var exact_unload := policy.update_position(Vector3(15.0, 0.0, 0.0))
	_check(
		int(exact_unload.get("attempted_count", -1)) == 0,
		"the exact unload radius is still retained"
	)
	var outside := policy.update_position(Vector3(15.01, 0.0, 0.0))
	_check(
		int(outside.get("attempted_count", -1)) == 1
			and coordinator.get_loaded_ids().is_empty(),
		"crossing outside the unload radius unloads once"
	)
	var unloaded_band := policy.update_position(Vector3(12.0, 0.0, 0.0))
	_check(
		int(unloaded_band.get("attempted_count", -1)) == 0,
		"an unloaded location does not thrash back on inside the hysteresis band"
	)
	policy.update_position(Vector3(9.0, 0.0, 0.0))
	_check(coordinator.get_loaded_ids().has("hysteresis_gate"), "crossing the load threshold again reloads")
	policy.clear_tracked_position()
	var requests_before_loss := loader.requests.size()
	var unavailable := policy.physics_tick(0.5)
	_check(
		not bool(unavailable.get("accepted", true))
			and unavailable.get("reason") == &"tracking_unavailable"
			and loader.requests.size() == requests_before_loss
			and coordinator.get_loaded_ids().has("hysteresis_gate"),
		"temporary tracking loss preserves loaded state and issues no requests"
	)

	coordinator.request_unload(gate.location_id)
	loader.reject_remaining_by_id[gate.location_id] = 1
	var failed := policy.update_position(Vector3.ZERO)
	var failed_transition := (failed.get("transitions", []) as Array)[0] as Dictionary
	_check(
		not bool(failed_transition.get("accepted", true))
			and failed_transition.get("reason") == &"loader_rejected"
			and coordinator.get_loaded_ids().is_empty(),
		"a coordinator request failure is reported without false loaded state"
	)
	var recovered := policy.update_now()
	var recovered_transition := (recovered.get("transitions", []) as Array)[0] as Dictionary
	_check(
		bool(recovered_transition.get("accepted", false))
			and recovered_transition.get("reason") == &"loaded"
			and int(recovered_transition.get("generation", -1))
				> int(failed_transition.get("generation", -1)),
		"the next explicit update recovers through a newer coordinator generation"
	)
	await _free_fixture(fixture)


func _test_external_retirement_and_detach_reentry() -> void:
	var fixture := _fixture(1)
	var coordinator := fixture.coordinator as WorldStreamingCoordinator
	var policy := fixture.policy as WorldStreamingDistancePolicy
	var loader := fixture.loader as ControlledLoader
	var definition := _definition(&"retirement_probe", Vector3.ZERO)
	policy.register_location(definition, 20.0, 30.0)
	var first := policy.update_position(Vector3.ZERO)
	var first_generation := int(((first.get("transitions", []) as Array)[0] as Dictionary).get("generation", -1))
	var first_instance := coordinator.get_loaded_instance(definition.location_id)
	first_instance.queue_free()
	var recovered := policy.update_now()
	var recovered_transition := (recovered.get("transitions", []) as Array)[0] as Dictionary
	var replacement := coordinator.get_loaded_instance(definition.location_id)
	_check(
		bool(recovered_transition.get("accepted", false))
			and int(recovered_transition.get("generation", -1)) > first_generation
			and replacement != first_instance
			and replacement.name == "WorldLocation_RetirementProbe",
		"an externally retired root is observed and reloaded through a fresh generation"
	)
	_check(coordinator.get_child_count() == 1, "external retirement recovery leaves one coordinator child")

	var requests_before_detach := loader.requests.size()
	root.remove_child(policy)
	root.remove_child(coordinator)
	await process_frame
	await process_frame
	_check(
		coordinator.get_loaded_instance(definition.location_id) == replacement
			and loader.requests.size() == requests_before_detach,
		"whole policy/coordinator detach preserves the same loaded instance without automatic work"
	)
	root.add_child(coordinator)
	root.add_child(policy)
	await process_frame
	await process_frame
	var reentry := policy.update_now()
	_check(
		int(reentry.get("attempted_count", -1)) == 0
			and coordinator.get_loaded_instance(definition.location_id) == replacement
			and loader.requests.size() == requests_before_detach,
		"whole detach/re-entry does not duplicate the location on the next explicit update"
	)
	await _free_fixture(fixture)


func _test_detached_snapshot_and_authority_boundary() -> void:
	var fixture := _fixture(3)
	var policy := fixture.policy as WorldStreamingDistancePolicy
	var definition := _definition(&"audit_location", Vector3(3.0, 4.0, 0.0))
	policy.register_location(definition, 6.0, 9.0)
	policy.set_tracked_position(Vector3.ZERO)
	var first := policy.get_snapshot()
	var first_locations := first.get("locations", []) as Array
	(first_locations[0] as Dictionary)["load_radius"] = 999.0
	(first_locations[0] as Dictionary)["last_outcome"] = {"forged": true}
	(first.get("registered_ids") as PackedStringArray).append("forged")
	var second := policy.get_snapshot()
	var second_location := (second.get("locations", []) as Array)[0] as Dictionary
	_check(
		is_equal_approx(float(second_location.get("load_radius", -1.0)), 6.0)
			and second.get("registered_ids") == PackedStringArray(["audit_location"])
			and not bool((second_location.get("last_outcome", {}) as Dictionary).get("forged", false)),
		"snapshot arrays and nested records are detached from policy state"
	)
	var report := policy.audit()
	(report.get("snapshot", {}) as Dictionary)["request_budget"] = 999
	var next_report := policy.audit()
	_check(
		bool(next_report.get("valid", false))
			and int((next_report.get("snapshot", {}) as Dictionary).get("request_budget", -1)) == 3,
		"audit is a detached valid report"
	)
	_check(
		next_report.get("update_authority") == &"explicit_only"
			and next_report.get("priority_policy") == &"distance_ascending_then_stable_id"
			and not bool(next_report.get("automatic_engine_processing", true))
			and not bool(next_report.get("gameplay_authority", true))
			and not bool(next_report.get("grants_rewards", true))
			and not bool(next_report.get("ship_authority", true))
			and not bool(next_report.get("berth_authority", true))
			and not bool(next_report.get("save_authority", true))
			and not bool(next_report.get("network_authority", true)),
		"policy owns only explicit distance decisions, not engine, gameplay, reward, ship, berth, save, or network authority"
	)
	_check(policy.unregister_location(definition.location_id), "policy unregister composes coordinator teardown")
	_check(not policy.unregister_location(definition.location_id), "duplicate policy unregister is rejected")
	await _free_fixture(fixture)


func _fixture(request_budget: int) -> Dictionary:
	var coordinator := CoordinatorScript.new() as WorldStreamingCoordinator
	coordinator.name = "DistancePolicyCoordinator"
	root.add_child(coordinator)
	var loader := ControlledLoader.new()
	coordinator.set_loader(Callable(loader, "request_scene"))
	var policy := PolicyScript.new() as WorldStreamingDistancePolicy
	policy.name = "WorldStreamingDistancePolicy"
	root.add_child(policy)
	_check(policy.configure(coordinator, request_budget), "policy configures with a live coordinator")
	return {
		"coordinator": coordinator,
		"policy": policy,
		"loader": loader,
	}


func _free_fixture(fixture: Dictionary) -> void:
	var policy := fixture.get("policy") as WorldStreamingDistancePolicy
	var coordinator := fixture.get("coordinator") as WorldStreamingCoordinator
	if is_instance_valid(policy):
		policy.queue_free()
	if is_instance_valid(coordinator):
		coordinator.queue_free()
	await process_frame


func _definition(location_id: StringName, anchor: Vector3) -> WorldLocationDefinition:
	var definition := WorldLocationDefinition.new()
	definition.location_id = location_id
	definition.display_name = str(location_id).capitalize()
	definition.sector_id = &"distance_policy_test_sector"
	definition.content_note = "Focused modern-interpretation distance-policy fixture."
	definition.anchor_source_id = &"distance_policy_test_anchor"
	definition.anchor_position = anchor
	return definition


func _request_ids(loader: ControlledLoader) -> PackedStringArray:
	var ids := PackedStringArray()
	for request in loader.requests:
		ids.append(str((request as Dictionary).get("location_id", &"")))
	return ids


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("WORLD_STREAMING_DISTANCE_POLICY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("WORLD_STREAMING_DISTANCE_POLICY_TEST_OK")
		quit(0)
	else:
		print("WORLD_STREAMING_DISTANCE_POLICY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
