extends SceneTree

## End-to-end regression for the first repeatable physical sandbox foundation:
## enter the completed-activity sandbox, choose among three parked craft, berth/exit,
## move to another craft, crash it, recover without a reload, and keep flying.

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "sandbox main scene loads")
	if packed == null:
		_finish()
		return

	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var original_game_id := game.get_instance_id()
	var player := game.get_node("Player") as CharacterBody3D
	var original_player_id := player.get_instance_id()
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(fleet.size() == 3, "exactly three physical flyable craft share the station")
	if fleet.size() != 3:
		game.queue_free()
		await process_frame
		_finish()
		return

	var primary := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as ArrowReconShip
	var jovian := game.get_node("JovianLightFreighter") as JovianLightFreighter
	_check(primary != arrow, "fleet registry contains distinct ship instances")
	_check(primary.get_ship_id() != arrow.get_ship_id(), "fleet ships expose unique stable IDs")
	_check(
		fleet.has(primary) and fleet.has(arrow) and fleet.has(jovian),
		"fleet registry contains the Torrent, Arrow, and Jovian instances"
	)
	_check(
		jovian.get_ship_id() == &"jovian_provisional"
		and jovian.get_ship_id() != primary.get_ship_id()
		and jovian.get_ship_id() != arrow.get_ship_id(),
		"Jovian exposes a unique stable production ID"
	)
	_check(jovian.get_home_berth_id() == &"jovian_freight_berth", "Jovian retains its dedicated freight home berth")
	_check(primary.global_position.distance_to(arrow.global_position) > 25.0, "both craft occupy separate visible berths")
	_check(jovian.global_position.distance_to(primary.global_position) > 25.0, "Jovian occupies a separate visible freight berth")
	_check(
		primary.maximum_speed != arrow.maximum_speed
		and primary.yaw_speed_degrees != arrow.yaw_speed_degrees,
		"Torrent and Arrow have measurably different handling profiles"
	)
	_check(world.get_berth_ids().size() == 3, "world exposes exactly three registered production landing berths")
	var jovian_berth := world.get_berth_node(jovian.get_home_berth_id())
	_check(
		jovian_berth != null
		and jovian_berth.get_reservation_owner() == jovian
		and jovian_berth.get_occupant() == jovian
		and jovian_berth.get_reserved_ship_id() == jovian.get_ship_id(),
		"Jovian's initial occupied freight-berth lease is authoritative"
	)
	var arrow_transform := world.get_berth_transform(&"arrow_recon_berth")
	_check(
		(-arrow_transform.basis.z).dot(Vector3.LEFT) > 0.99,
		"Arrow berth preserves a full rotated docking transform"
	)
	for craft in [primary, arrow, jovian]:
		var area := craft.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
		_check(area != null, "%s has a physical boarding interaction area" % craft.name)
		if area != null:
			_check(area.collision_layer == PhysicsLayers.INTERACTABLE, "%s advertises boarding on Interactable" % craft.name)

	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	game.start_shift()
	await process_frame
	# This suite starts from an already completed guide so it can exercise the
	# persistent multi-ship sandbox without replaying the combat activity. Do not
	# call `_begin_return_to_yard()` here: victory now correctly creates only a
	# pending return leg, and physical landing/shutdown/disembark owns completion.
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE
	_check(game.is_guided_activity_complete(), "sandbox regression begins after guided completion")

	# Choose the Arrow by physically entering its interaction volume. No menu or
	# node-name selection is used by the gameplay coordinator.
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	await physics_frame
	await process_frame
	_check(game.boarding_candidate == arrow, "proximity selects the Arrow in the shared world")
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await create_timer(0.4).timeout
	_check(game.get_active_ship() == arrow, "physical interaction boards the selected Arrow")
	_check(player.is_seated(), "the visible player occupies the Arrow's live seat")
	_check(not primary.is_piloted(), "boarding one craft leaves the other parked and inactive")

	arrow.engine_start_time = 0.03
	arrow.request_engine_start()
	await create_timer(0.12).timeout
	await physics_frame
	_check(str(arrow.get_telemetry().engine_state) == "ONLINE", "Arrow completes its own engine startup")

	# Landing remains a basic capability rather than a reward gated behind target
	# practice. The Arrow begins over its home pad, so this is a short real
	# docking cycle that also proves the 90-degree berth orientation is retained.
	arrow.global_transform = arrow_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.velocity = Vector3.ZERO
	game.call("_try_request_landing")
	await create_timer(2.1).timeout
	await physics_frame
	_check(bool(arrow.get_telemetry().landed), "Arrow landing assist works in the completed sandbox")
	_check(arrow.global_basis.is_equal_approx(arrow_transform.basis), "landing aligns to the recon berth's full basis")
	arrow.request_engine_stop()
	game.call("_try_exit_ship")
	await create_timer(0.35).timeout
	await physics_frame
	_check(not player.is_seated() and player.is_control_enabled(), "Arrow shutdown returns the same character to the deck")
	_check(game.phase == GameFlow.Phase.COMPLETE, "ending a post-guide sortie returns to the persistent sandbox")

	# The just-exited craft is suppressed until the player moves clear, avoiding a
	# stale E press while still permitting an intentional later reboard.
	game.call("_on_interact_requested")
	await process_frame
	_check(not arrow.is_piloted(), "immediate stale reboarding is blocked")
	player.teleport_to(Transform3D(Basis.IDENTITY, primary.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	await physics_frame
	await process_frame
	_check(game.boarding_candidate == primary, "walking to the other berth selects the primary craft")
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await create_timer(0.4).timeout
	_check(game.get_active_ship() == primary and player.is_seated(), "the player switches ships without a reload or menu")
	primary.engine_start_time = 0.03
	primary.request_engine_start()
	await create_timer(0.12).timeout
	await physics_frame
	_check(game.phase == GameFlow.Phase.FREE_FLIGHT, "subsequent boarding enters unrestricted free flight")
	Input.action_press("move_forward")
	await physics_frame
	await physics_frame
	Input.action_release("move_forward")
	for _settle in 4:
		await physics_frame

	# A low-speed contact remains harmless, while a deliberate high-speed impact
	# causes physical hull damage and invokes the reusable destruction lifecycle.
	var crash_wall := _make_crash_wall()
	game.add_child(crash_wall)
	primary.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0, 0.0))
	primary.velocity = Vector3(0.0, 0.0, -10.0)
	var hull_before_contact := float(primary.get_telemetry().hull)
	for _step in 20:
		await physics_frame
		if primary.velocity.length() < 0.2:
			break
	_check(is_equal_approx(float(primary.get_telemetry().hull), hull_before_contact), "low-speed station contact does not damage the hull")

	primary.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0, 0.0))
	primary.velocity = Vector3(0.0, 0.0, -105.0)
	primary.impact_damage_scale = 3.2
	for _step in 20:
		await physics_frame
		if primary.is_destroyed():
			break
	_check(primary.is_destroyed(), "a deliberate high-speed physical crash destroys the active craft")
	await create_timer(0.3).timeout
	await physics_frame
	_check(game.get_instance_id() == original_game_id, "crash recovery preserves the same world/session instance")
	_check(player.get_instance_id() == original_player_id, "crash recovery preserves the same player instance")
	_check(not player.is_seated() and player.is_control_enabled(), "destroyed-craft recall restores on-foot control")
	_check(game.phase == GameFlow.Phase.COMPLETE, "destruction returns to the non-terminal sandbox state")
	_check(arrow.is_boardable(), "the other physical craft remains immediately available after a crash")

	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	await physics_frame
	await process_frame
	_check(game.boarding_candidate == arrow, "post-crash player can select the surviving craft")
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await create_timer(0.4).timeout
	_check(game.get_active_ship() == arrow and player.is_seated(), "post-crash loop boards and seats the player in another craft")

	await create_timer(4.1).timeout
	_check(not primary.is_destroyed() and primary.is_boardable(), "destroyed berth regenerates its craft for another loop")
	_check(primary.global_transform.is_equal_approx(world.get_berth_transform(primary.get_home_berth_id())), "regenerated craft returns to its own berth transform")

	Input.action_release("move_forward")
	Input.action_release("sprint_boost")
	Input.action_release("fire")
	game.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _make_crash_wall() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SandboxCrashWall"
	body.position = Vector3(0.0, 24.0, -7.0)
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 18.0, 1.0)
	collision.shape = shape
	body.add_child(collision)
	return body


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SANDBOX_LOOP_TEST_OK")
		quit(0)
	else:
		print("SANDBOX_LOOP_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
