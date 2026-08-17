extends SceneTree

## Focused contract for the first nearby-activity seam. It drives the resource
## and public director APIs only: no reward, ship, berth, combat, or GameFlow
## system is present in this fixture.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_resources_match_the_live_nearby_sector()
	await _test_route_lifecycle_and_generation_guards()
	_finish()


func _test_resources_match_the_live_nearby_sector() -> void:
	_check(LOCATION.is_definition_valid(), "the Cinder Reach location resource is valid")
	_check(ROUTE.is_definition_valid(), "the checkpoint-route activity resource is valid")
	var location_audit := LOCATION.audit()
	_check(
		LOCATION.get_scene_origin_position().is_zero_approx()
			and (location_audit.get("scene_origin_position", Vector3.INF) as Vector3).is_zero_approx()
			and location_audit.get("anchor_position") == LOCATION.get_anchor_position()
			and int(location_audit.get("schema_version", -1)) == 2,
		"the Cinder resource separately publishes an origin-zero scene and its navigation anchor"
	)
	var invalid_scene_origin := LOCATION.duplicate(true) as WorldLocationDefinition
	invalid_scene_origin.scene_origin_position = Vector3.INF
	var origin_errors := invalid_scene_origin.get_validation_errors()
	var invalid_origin_audit := invalid_scene_origin.audit()
	_check(
		not invalid_scene_origin.is_definition_valid()
			and origin_errors.has("scene_origin_position must be finite")
			and not origin_errors.has("anchor_position must be finite")
			and not bool(invalid_origin_audit.get("valid", true))
			and invalid_origin_audit.get("scene_origin_position") == Vector3.INF,
		"definition validation audits a non-finite scene origin separately from the navigation anchor"
	)
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	_check(
		world != null and cluster != null,
		"the station and real streamed-component fixture instantiate for resource verification"
	)
	if world == null or cluster == null:
		return
	root.add_child(world)
	root.add_child(cluster)
	await process_frame
	_check(
		world.get_nearby_sector_cluster() == null,
		"station-owned activity resources do not require an always-resident Cinder instance"
	)
	_check(
		LOCATION.get_anchor_position().is_equal_approx(cluster.PLATFORM_ANCHOR),
		"the location resource uses the authored Cinder Reach platform anchor"
	)
	var beacon_positions := cluster.get_route_beacon_positions()
	_check(
		ROUTE.get_checkpoint_count() == beacon_positions.size() + 1,
		"the route has each authored beacon plus the Cinder Reach destination"
	)
	var matches := true
	for index in beacon_positions.size():
		matches = matches and ROUTE.get_checkpoint_position(index).is_equal_approx(beacon_positions[index])
	matches = matches and ROUTE.get_checkpoint_position(ROUTE.get_checkpoint_count() - 1).is_equal_approx(
		cluster.PLATFORM_ANCHOR
	)
	_check(matches, "the station-owned route stays anchored to the streamed component contract")
	cluster.queue_free()
	world.queue_free()
	await process_frame


func _test_route_lifecycle_and_generation_guards() -> void:
	var director := DirectorScript.new() as ActivityDirector
	root.add_child(director)
	_check(director.register_definition(ROUTE), "a valid route definition registers once")
	_check(not director.register_definition(ROUTE), "duplicate activity definitions are rejected")
	var audit := director.audit()
	_check(
		not bool(audit.get("gameplay_authority", true))
			and not bool(audit.get("grants_rewards", true))
			and not bool(audit.get("ship_authority", true))
			and not bool(audit.get("berth_authority", true)),
		"the director explicitly owns no reward, ship, berth, or gameplay authority"
	)

	var first_start := director.start_activity(ROUTE.activity_id)
	var first_generation := int(first_start.get("generation", -1))
	_check(
		bool(first_start.get("accepted", false))
			and first_generation == 1
			and int(first_start.get("state", -1)) == CheckpointRouteActivity.State.ACTIVE,
		"starting creates generation one in the active state"
	)
	_check(
		not bool(director.submit_position(
			ROUTE.activity_id, ROUTE.get_checkpoint_position(1), first_generation
		).get("accepted", true)),
		"a later checkpoint cannot be claimed out of order"
	)
	for index in ROUTE.get_checkpoint_count():
		var step := director.submit_position(
			ROUTE.activity_id, ROUTE.get_checkpoint_position(index), first_generation
		)
		_check(bool(step.get("accepted", false)), "checkpoint %d advances through the public director API" % index)
	var completed := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		int(completed.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED
			and int(completed.get("next_checkpoint_index", -1)) == ROUTE.get_checkpoint_count(),
		"the final checkpoint completes the finite route"
	)

	var second_start := director.start_activity(ROUTE.activity_id)
	var second_generation := int(second_start.get("generation", -1))
	_check(second_generation == first_generation + 1, "a completed route starts a fresh generation")
	var stale_result := director.submit_position(
		ROUTE.activity_id, ROUTE.get_checkpoint_position(0), first_generation
	)
	_check(
		not bool(stale_result.get("accepted", true)) and stale_result.get("reason", &"") == &"stale_generation",
		"a delayed callback from the completed run cannot enter the new run"
	)
	_check(
		director.fail_activity(ROUTE.activity_id, &"test_abort", second_generation),
		"an active route has an explicit finite failure transition"
	)
	_check(
		int(director.get_activity_snapshot(ROUTE.activity_id).get("state", -1)) == CheckpointRouteActivity.State.FAILED,
		"failure is terminal until restart or reset"
	)
	var third_start := director.start_activity(ROUTE.activity_id)
	var third_generation := int(third_start.get("generation", -1))
	_check(third_generation == second_generation + 1, "a failed route also re-enters with a new generation")

	root.remove_child(director)
	await process_frame
	root.add_child(director)
	await process_frame
	_check(
		int(director.get_activity_snapshot(ROUTE.activity_id).get("generation", -1)) == third_generation,
		"director tree re-entry preserves the live route without replaying it"
	)
	_check(
		director.reset_activity(ROUTE.activity_id, third_generation),
		"the current generation can reset an active route"
	)
	var reset_snapshot := director.get_activity_snapshot(ROUTE.activity_id)
	_check(
		int(reset_snapshot.get("state", -1)) == CheckpointRouteActivity.State.IDLE
			and int(reset_snapshot.get("generation", -1)) == third_generation + 1,
		"reset clears route progress and invalidates the prior generation"
	)
	_check(
		not director.reset_activity(ROUTE.activity_id, third_generation),
		"a stale generation cannot reset the replacement route state"
	)
	director.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("ACTIVITY_DIRECTOR_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("ACTIVITY_DIRECTOR_TEST_OK")
		quit(0)
	else:
		print("ACTIVITY_DIRECTOR_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
