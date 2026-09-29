extends SceneTree

## Craft poses must survive a host whose world has been rebased.
##
## Every planet visit commits the common-world origin rebase, which translates
## the station, the fleet and the player by one delta; a Rime round trip leaves
## the station ~58 m off its authored origin for the rest of the process. Each
## peer's rebases are its own, so two peers' world spaces differ by exactly the
## difference of their station offsets. Craft poses used to cross the wire in
## the host's raw world space, so a client whose world had not been rebased
## drew every craft the host published -- the host's own, and the one a remote
## pilot was flying -- displaced by the host's offset: parked inside the
## station, or snapped off its own berth.
##
## Both ends here are whole production `Main` subtrees over loopback ENet. The
## host's direct roots (station, fleet, player) are translated by the offset a
## real Rime round trip leaves; the client's are not. The host flies its own
## craft, and the client's copy of that craft must sit where the host's does
## *relative to each peer's own station*.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const MAIN_SCENE := preload("res://scenes/main.tscn")
## The station offset a production Rime round trip was measured to leave.
const HOST_REBASE_OFFSET := Vector3(-31.0, -4.0, -48.0)
const TOLERANCE_METERS := 0.5

var _assertions := 0
var _failures := PackedStringArray()
var _host: GameFlow = null
var _client: GameFlow = null
var _branch: SubViewport = null


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	Engine.max_physics_steps_per_frame = 1
	if await _build():
		await _assert_the_client_draws_the_host_craft_at_the_same_berth()
	await _finish()


func _build() -> bool:
	_host = MAIN_SCENE.instantiate() as GameFlow
	_host.name = "RebasedHostMain"
	root.add_child(_host)
	_branch = SubViewport.new()
	_branch.name = "ClientWorld"
	_branch.size = Vector2i(64, 64)
	_branch.own_world_3d = true
	_branch.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_branch)
	_client = MAIN_SCENE.instantiate() as GameFlow
	_client.name = "ClientMain"
	_branch.add_child(_client)
	await process_frame
	await physics_frame
	_host.start_shift()
	_client.start_shift()
	await process_frame
	await physics_frame
	_check(is_instance_valid(_host.world) and is_instance_valid(_client.world)
		and is_instance_valid(_host.active_ship), "both peers stand up a whole production station")
	if not is_instance_valid(_host.active_ship):
		return false
	# The host has been to Rime and back before hosting: every direct root the
	# origin owner moves (station, fleet, player) carries the same offset.
	for child in _host.get_children():
		if child is Node3D and (child == _host.world or child is HeroShip or child is PlayerController):
			(child as Node3D).global_position += HOST_REBASE_OFFSET
	_check(_host.world.global_position.is_equal_approx(_client.world.global_position + HOST_REBASE_OFFSET),
		"the host's station stands at its rebased offset; the client's does not")
	set_multiplayer(SceneMultiplayer.new(), _host.get_path())
	set_multiplayer(SceneMultiplayer.new(), _client.get_path())
	var port := _reserve_loopback_port()
	_check(bool(_host.host_network_session(port, 2).get("accepted", false)), "the rebased host opens a session")
	_check(bool(_client.join_network_session("127.0.0.1", port).get("accepted", false)), "the client joins it")
	var admitted := await _wait_until(func() -> bool:
		return not _client.get_network_session().get_server_offer().is_empty(), 10.0)
	_check(admitted, "the client is admitted")
	return admitted


func _assert_the_client_draws_the_host_craft_at_the_same_berth() -> void:
	var host_craft := _host.active_ship
	var ship_id := host_craft.get_ship_id()
	var client_craft: HeroShip = null
	for craft in _client.ships:
		if is_instance_valid(craft) and craft.get_ship_id() == ship_id:
			client_craft = craft
	_check(client_craft != null and client_craft != host_craft, "the client has its own copy of the host's craft")
	if client_craft == null:
		return
	# The host takes its craft 30 m up off its berth and holds it there.
	host_craft.set_physics_process(false)
	host_craft.global_position += Vector3(0.0, 30.0, 0.0)
	host_craft.velocity = Vector3.ZERO
	_host.set("_piloting", true)
	var host_station_pose := host_craft.global_position - _host.world.global_position
	var client_station_pose := client_craft.global_position - _client.world.global_position
	_check(client_station_pose.distance_to(host_station_pose) > 10.0,
		"before any pose arrives the client's copy is still on its berth")
	var arrived := await _wait_until(func() -> bool:
		return _client._network_craft_pose_stream.has_samples(ship_id), 8.0)
	_check(arrived, "the host's craft pose reaches the client")
	# Let the observer interpolation settle on the held pose.
	for _i in 30:
		await physics_frame
	client_station_pose = client_craft.global_position - _client.world.global_position
	var error := client_station_pose.distance_to(host_station_pose)
	_check(error <= TOLERANCE_METERS,
		"the client draws the host's craft at the same place relative to its own station (off by %.2f m)" % error)
	_host.set("_piloting", false)


func _reserve_loopback_port() -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port")
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _finish() -> void:
	if is_instance_valid(_client):
		_client.shutdown_network_session(&"test_complete")
	if is_instance_valid(_host):
		_host.shutdown_network_session(&"test_complete")
		_host.queue_free()
	if is_instance_valid(_branch):
		_branch.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_CRAFT_POSE_STATION_FRAME_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append("FAIL: " + description)
