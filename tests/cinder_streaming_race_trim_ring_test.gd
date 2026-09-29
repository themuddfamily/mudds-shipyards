extends SceneTree

## Real-Main regression: a streamed Cinder generation hides the four beacon
## trim rings behind one MultiMesh batch. The race gate presenter animates those
## rings (pending, cleared, missed, completed), so the batch must draw their
## live transforms, not the bind-time copy.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const TRIM_RING_PATHS: Array[NodePath] = [
	^"RouteBeacons/RouteBeaconAlpha/TrimRing",
	^"RouteBeacons/RouteBeaconBravo/TrimRing",
	^"RouteBeacons/RouteBeaconCharlie/TrimRing",
	^"RouteBeacons/RouteBeaconDelta/TrimRing",
]

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
	# Stage the streamed roots where a planet visit leaves them.
	var offset := Vector3(-31.0, -4.0, -48.0)
	bootstrap.position += offset
	var anchor := bootstrap.to_global(LOCATION.get_anchor_position())
	var near := {
		"available": true,
		"position": anchor + Vector3(0.0, 0.0, 400.0),
		"actor_kind": &"player",
		"actor_instance_id": player.get_instance_id(),
	}
	binding.physics_tick_from_caller_sample(0.1, near)
	var loaded := await _wait_until(
		func() -> bool: return bootstrap.get_loaded_instance() != null, 30
	)
	for _tick in 10:
		binding.physics_tick_from_caller_sample(0.1, near)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	var batch := cluster.get_node_or_null(^"StreamingBeaconTrimRingBatch") as MultiMeshInstance3D \
		if cluster != null else null
	_check(
		loaded and cluster != null and batch != null
		and cluster.get_streaming_transition_snapshot().get("phase") == &"authored",
		"one offset streamed Cinder generation draws its trim rings through the batch"
	)
	if cluster == null or batch == null:
		await _finish(game)
		return
	_check(_batch_matches_live_rings(cluster, batch), "the idle batch matches the authored trim rings")

	var activity := cluster.get_node(^"ActivityBinding")
	var started := activity.call("start_race") as Dictionary
	var countdown := cluster.get_race_gate_presentation_state()
	_check(
		bool(started.get("accepted", false))
		and countdown.get("state_id") == &"countdown"
		and ((countdown.get("gates", []) as Array)[1] as Dictionary).get("trim_scale") \
			== Vector3.ONE * 0.84,
		"the streamed race enters its countdown and shrinks the pending trim rings"
	)
	binding.physics_tick_from_caller_sample(1.0 / 60.0, near)
	_check(
		_batch_matches_live_rings(cluster, batch),
		"the drawn trim-ring batch follows the countdown presentation"
	)
	activity.call("reset_race")
	_check(
		_batch_matches_live_rings(cluster, batch),
		"the drawn trim-ring batch returns with the reset presentation"
	)
	_check(
		bool(cluster.get_streaming_transition_audit().get("valid", false)),
		"the streamed transition audit remains valid"
	)
	await _finish(game)


func _batch_matches_live_rings(cluster: Node3D, batch: MultiMeshInstance3D) -> bool:
	var root_inverse := cluster.global_transform.affine_inverse()
	for index in TRIM_RING_PATHS.size():
		var ring := cluster.get_node(TRIM_RING_PATHS[index]) as Node3D
		var expected := root_inverse * ring.global_transform
		if ring.visible or not _drawn_transform(batch, index).is_equal_approx(expected):
			return false
		var ring_bounds := expected * (ring as MeshInstance3D).mesh.get_aabb()
		if not batch.multimesh.custom_aabb.grow(0.001).encloses(ring_bounds):
			return false
	return true


## The headless renderer keeps only the raw MultiMesh buffer.
func _drawn_transform(batch: MultiMeshInstance3D, index: int) -> Transform3D:
	var buffer := batch.multimesh.buffer
	var offset := index * 12
	if buffer.size() < offset + 12:
		return Transform3D()
	return Transform3D(
		Vector3(buffer[offset + 0], buffer[offset + 4], buffer[offset + 8]),
		Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
		Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10]),
		Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
	)


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
		print("CINDER_STREAMING_RACE_TRIM_RING_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CINDER_STREAMING_RACE_TRIM_RING_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)
