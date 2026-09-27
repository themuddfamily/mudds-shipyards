extends SceneTree

## The authoritative snapshot stream survives a publishing gap.
##
## The client's `NetworkSnapshotJitterBuffer` refuses a revision whose server
## tick is more than `MAX_TICK_GAP` past the last one it released. The stream is
## reliable and ordered, so the revision it was waiting for never comes: before
## the fix every later snapshot -- movement, ownership, projectiles and the
## piloted-craft poses that now ride it -- was dropped for the rest of the
## session after the host skipped publishing for a moment (a surface visit, a
## long stall). The client now re-adopts the complete decoded packet as a fresh
## baseline.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const PoseStream := preload("res://scripts/network/network_remote_craft_pose_stream.gd")

var _failures: Array[String] = []
var _assertions := 0
var _applied: Array[Dictionary] = []


func _initialize() -> void:
	await process_frame
	var branches: Array[SubViewport] = []
	for branch_name in ["Server", "Client"]:
		var branch := SubViewport.new()
		branch.name = branch_name
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		branches.append(branch)
	var server := Adapter.new()
	var client := Adapter.new()
	server.name = "Session"
	client.name = "Session"
	branches[0].add_child(server)
	branches[1].add_child(client)
	var stream := PoseStream.new()
	client.snapshot_applied.connect(func(result: Dictionary) -> void:
		_applied.append(result.duplicate(true))
		if bool(result.get("accepted", false)):
			var sections := (result.get("snapshot", {}) as Dictionary).get("sections", {}) as Dictionary
			stream.consume_movement_section(sections.get(&"movement", []) as Array))
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve ENet port")
	var port := probe.get_local_port()
	probe.stop()
	_check(server.host(port, 2).accepted, "host real ENet session")
	_check(client.join("127.0.0.1", port).accepted, "connect real ENet client")
	await _pump(func() -> bool: return not client.get_server_offer().is_empty())
	var craft := Node3D.new()
	root.add_child(craft)
	for tick in range(1, 4):
		craft.global_position = Vector3(float(tick), 0.0, 0.0)
		server.publish_snapshot(tick, [PoseStream.build_pose_entry(craft, &"test_craft", 2, tick)], [], [])
	await _pump(func() -> bool: return _accepted_count() >= 3)
	_check(_accepted_count() >= 3, "the client applies the contiguous snapshots")
	# The host skips 200 ticks, then resumes.
	craft.global_position = Vector3(200.0, 0.0, 0.0)
	server.publish_snapshot(203, [PoseStream.build_pose_entry(craft, &"test_craft", 2, 203)], [], [])
	await _pump(func() -> bool: return _accepted_count() >= 4)
	_check(_accepted_count() >= 4, "a snapshot past the jitter window is re-adopted as a baseline")
	_check(int(client.get_snapshot_jitter_state().get("rebaselines", 0)) == 1,
		"the re-adoption is counted once")
	craft.global_position = Vector3(201.0, 0.0, 0.0)
	server.publish_snapshot(204, [PoseStream.build_pose_entry(craft, &"test_craft", 2, 204)], [], [])
	await _pump(func() -> bool: return _accepted_count() >= 5)
	_check(_accepted_count() >= 5, "the stream keeps flowing after the gap")
	_check(int(stream.latest_sample(&"test_craft").get("pose_tick", 0)) == 204
		and (stream.latest_sample(&"test_craft").get("position", Vector3.ZERO) as Vector3).is_equal_approx(
			Vector3(201.0, 0.0, 0.0)),
		"the craft pose stream sees the post-gap poses")
	client.shutdown(&"suite_complete")
	server.shutdown(&"suite_complete")
	await process_frame
	_finish()


func _accepted_count() -> int:
	var count := 0
	for result in _applied:
		if bool(result.get("accepted", false)):
			count += 1
	return count


func _pump(predicate: Callable, seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
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


func _finish() -> void:
	if _failures.is_empty():
		print("NETWORK_SNAPSHOT_GAP_REBASELINE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("NETWORK_SNAPSHOT_GAP_REBASELINE_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertions, "; ".join(_failures)])
	quit(1)
