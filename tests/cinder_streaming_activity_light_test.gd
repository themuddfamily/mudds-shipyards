extends SceneTree

## Real-Main regression: the streamed Cinder fade re-applies its light
## baselines on every caller physics tick. Activity presenters that set a light
## (the mining crown lamps) must survive that tick and fade with the sector
## rather than snapping back to the bind-time energy.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const LAMPS := ^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var player := game.get_node_or_null(^"Player") as Node3D
	_check(binding != null and bootstrap != null and player != null, "Main exposes the Cinder streaming composition")
	if binding == null or bootstrap == null or player == null:
		await _finish(game)
		return
	var anchor := LOCATION.get_anchor_position()
	var outward := (Vector3.ZERO - anchor).normalized()
	var near := _sample(player, anchor + outward * 400.0)
	binding.physics_tick_from_caller_sample(0.1, near)
	var loaded := await _wait_until(
		func() -> bool: return bootstrap.get_loaded_instance() != null, 30
	)
	for _tick in 10:
		binding.physics_tick_from_caller_sample(0.1, near)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	_check(
		loaded and cluster != null
		and cluster.get_streaming_transition_snapshot().get("phase") == &"authored",
		"one streamed Cinder generation reaches its authored presentation"
	)
	if cluster == null:
		await _finish(game)
		return
	var activity := cluster.get_node(^"ActivityBinding")
	var port := cluster.get_node(NodePath(str(LAMPS) + "/MiningCrownLampPort")) as OmniLight3D
	var starboard := cluster.get_node(NodePath(str(LAMPS) + "/MiningCrownLampStarboard")) as OmniLight3D

	var started: Dictionary = activity.call(
		"start_mining_activity", CinderMiningPlatformActivity.APPROACH_ANCHOR
	)
	binding.physics_tick_from_caller_sample(1.0 / 60.0, near)
	_check(
		bool(started.get("accepted", false))
		and is_equal_approx(port.light_energy, 1.4)
		and is_equal_approx(starboard.light_energy, 3.2),
		"the extracting crown lamps survive the next streaming physics tick (port=%f starboard=%f)"
		% [port.light_energy, starboard.light_energy]
	)

	activity.call("advance_mining_activity", CinderMiningPlatformActivity.EXTRACTION_SECONDS + 1.0)
	var secured_state := StringName(cluster.get_mining_activity_presentation_state().get("state_id", &""))
	for _tick in 3:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, near)
	_check(
		secured_state == &"secured"
		and is_equal_approx(port.light_energy, 3.4)
		and is_equal_approx(starboard.light_energy, 3.4),
		"the secured crown lamps hold their completed energy across streaming ticks (port=%f)"
		% port.light_energy
	)
	_check(
		bool(cluster.get_streaming_transition_audit().get("valid", false)),
		"the transition audit accepts the presented lamp energy"
	)

	binding.physics_tick_from_caller_sample(0.1, _sample(player, anchor + outward * 650.2))
	var fading := cluster.get_streaming_transition_snapshot()
	var opacity := float(fading.get("opacity", -1.0))
	_check(
		fading.get("phase") == &"fading_out" and opacity > 0.0 and opacity < 1.0
		and is_equal_approx(port.light_energy, 3.4 * opacity),
		"the secured crown lamps fade with the sector instead of from their bind-time energy"
	)
	await _finish(game)


func _sample(player: Node3D, position: Vector3) -> Dictionary:
	return {
		"available": true,
		"position": position,
		"actor_kind": &"player",
		"actor_instance_id": player.get_instance_id(),
	}


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("CINDER_STREAMING_ACTIVITY_LIGHT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CINDER_STREAMING_ACTIVITY_LIGHT_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)
