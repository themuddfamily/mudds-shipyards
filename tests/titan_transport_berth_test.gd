extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const TITAN_DEFINITION := preload("res://assets/ships/titan_provisional.tres")
const OLD_TRANSFORMS := preload("res://tests/station_route_registry_integration_test.gd").EXPECTED_BERTH_TRANSFORMS
# Frozen before traversal, using existing production Operations/Annex/Spur paths.
# No pose writes, jump, rescue, remote-intent controller or collision disabling.
const ROUTE := [
	Vector3(8, 0, 11), Vector3(8, 0, 13.5), Vector3(35, 0, 13.5),
	Vector3(35, 0, 15.5), Vector3(43, 0, 15.5),
	Vector3(43, 0, 24.8), Vector3(48.1, 0, 24.8), Vector3(48.1, 0, 28),
	Vector3(68.5, 0, 28), Vector3(68.5, 0, 38), Vector3(83, 0, 38),
	Vector3(93.3, 0, 38), Vector3(116.5, 0, 38), Vector3(116.5, 0, 46),
	Vector3(124.5, 0, 46), Vector3(129.65, 0, 41.55), Vector3(130.5, 0, 38),
	Vector3(135, 0, 38), Vector3(139.5, 0, 38),
	Vector3(139.5, 0, 39.9), Vector3(144, 0, 39.9),
]
var _failures: Array[String] = []
var _frames := 0
var _supported := 0
var _clear := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var player := game.get_node("Player") as PlayerController
	player.set_camera_active(false)
	await _wait_frames(10)
	_check(player.global_position.distance_to(world.get_player_spawn().origin) < 0.25 and player.is_on_floor(),
		"actual Main Player begins at normal production spawn without fixture pose")
	var module := world.get_node("TitanTransportBerth") as TitanTransportBerth
	var berth := world.get_berth_node(&"titan_home_berth")
	_check(berth != null and berth == module.get_node("ShipBerth") and berth.get_validation_errors().is_empty(),
		"production discovery finds the new valid own ShipBerth")
	var matching := 0
	for candidate in get_nodes_in_group(ShipBerth.GROUP):
		if candidate.get_berth_id() == &"titan_home_berth": matching += 1
	_check(matching == 1 and world.get_berth_ids().size() == 11, "own berth discovered exactly once alongside unchanged nine")
	var unchanged := true
	for berth_id in OLD_TRANSFORMS:
		unchanged = unchanged and world.get_berth_transform(berth_id).is_equal_approx(OLD_TRANSFORMS[berth_id])
	_check(unchanged and game.get_flyable_ships().size() == 10, "original nine transforms remain unchanged alongside production Titan")
	_check(berth.compatibility_tags == PackedStringArray(["titan_transport"])
		and berth.landing_half_extents == Vector3(7, 7, 14)
		and berth.assist_capture_center == Vector3(0, 10, -24)
		and berth.assist_capture_half_extents == Vector3(25, 17, 38)
		and berth.assist_capture_maximum_speed == 25 and berth.assist_maximum_tilt_degrees == 65
		and berth.departure_lift_height == 5 and TITAN_DEFINITION.landing_maximum_speed == 11,
		"exact approved fit, capture, departure and original landing-speed gates")
	var before := berth.get_audit_report()
	var wrong := preload("res://assets/ships/torrent_provisional.tres")
	_check(not berth.can_accept(wrong, player) and berth.try_reserve(player, wrong).is_empty()
		and berth.get_audit_report() == before,
		"wrong-tag compatibility and reservation refuse without mutating rightful Titan lease")
	var registry := world.get_station_route_registry_report()
	_check(registry.valid and registry.modules.has(&"titan-transport-berth"), "new module joins the existing real route registry: %s" % registry.errors)
	var graph := world.get_station_navigation_graph_report()
	var edge := (graph.get("edges", {}) as Dictionary).get(&"hub-titan-transport-berth", {}) as Dictionary
	_check(bool(graph.get("valid", false)) and is_equal_approx(float(edge.get("length", -1)), 1.5)
		and edge.get("hub_node_id") == &"station-hub:hub-titan-transport-berth"
		and edge.get("module_node_id") == &"titan-transport-berth:approach",
		"real supported 1.5m Titan connector edge keeps the complete navigation graph valid")
	_check(bool(world.get_ship_berth_feedback_audit_report().valid), "existing six feedback placements remain valid with the legitimate tenth berth")
	var ship := game.get_node("TitanMediumTransport") as HeroShip
	var titans := 0
	for craft in game.get_flyable_ships():
		if craft.get_ship_id() == &"titan_provisional": titans += 1
	_check(titans == 1 and berth.get_occupant() == ship and berth.get_reservation_owner() == ship,
		"exactly one registered production Titan owns its own occupied berth")
	_check(ship.global_transform.is_equal_approx(berth.get_dock_transform()), "production Titan begins at exact approved own berth")
	_check(berth.contains_oriented_bounds(ship.global_transform, ship.get_landing_collision_report().local_bounds), "complete closed Titan fits strict landing bounds")
	await _test_clearance(ship, module, false)
	ship.set_canopy_open(true, 0.0)
	await _wait_frames(3)
	_check(ship.is_canopy_open() and ship.get_landing_collision_report().local_bounds.is_equal_approx(AABB(Vector3(-6, 0, -9), Vector3(12, 6.5, 22))), "supported production deck deploys full unchanged accepted Titan access")
	_check(berth.contains_oriented_bounds(ship.global_transform, ship.get_landing_collision_report().local_bounds), "full deployed Titan fits strict landing bounds")
	await _test_clearance(ship, module, true)
	ship.set_canopy_open(false, 0.0)
	await _wait_frames(3)
	print("TITAN_FROZEN_ROUTE: ", ROUTE)
	var reached_all := true
	for index in ROUTE.size():
		if not await _walk_to(player, ROUTE[index], index):
			reached_all = false
			break
	_check(reached_all, "same actual Player walks normal spawn through station to Titan stern apron and normal-range control")
	_check(_frames > 1000 and _supported == _frames and _clear == _frames,
		"every movement and braking frame retains actual floor support and capsule clearance: %d/%d supported, %d clear" % [_supported, _frames, _clear])
	var hatch := ship.get_node("TitanOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	var local := ship.to_local(player.global_position)
	_check(reached_all and Vector2(local.x - 1.9, local.z - 10).length() < 0.08
		and absf(local.y) < 0.03 and hatch.is_available()
		and player.get_interaction_origin().distance_to(hatch.global_position) < ShipCabinHatch.MAX_REACH,
		"walk endpoint is supported outside ramp sweep and within unchanged control reach")
	_check(reached_all and hatch.interact(player), "the physically reached normal-range control accepts its existing interaction API")
	await _wait_frames(25)
	_check(ship.is_canopy_open(), "reached hatch control deploys the real physical stern access")
	_release_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await _wait_frames(3)
	if _failures.is_empty():
		print("TITAN_TRANSPORT_BERTH_TEST_PASS")
		quit(0)
	else:
		print("TITAN_TRANSPORT_BERTH_TEST: FAIL ", _failures)
		quit(1)

func _test_clearance(ship: HeroShip, module: TitanTransportBerth, deployed: bool) -> void:
	var failures: Array[String] = []
	var continuous_clear := true
	# Use every actual enabled hull/access shape, including hatch/roof slot and
	# both ramp leaves. The allowed contact deck is excluded only as support;
	# all other live station geometry and all original nine craft stay queried.
	var support := module.get_node("BerthDeck") as StaticBody3D
	for height_index in 21:
		var lift := float(height_index) * 0.25
		for candidate in ship.find_children("*", "CollisionShape3D", true, false):
			var collision := candidate as CollisionShape3D
			if collision.disabled: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collision.shape
			query.transform = collision.global_transform
			query.transform.origin += Vector3.UP * lift
			query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
			query.margin = 0
			query.exclude = [ship.get_rid(), support.get_rid()]
			if height_index == 0:
				query.motion = Vector3.UP * 5
				var fractions := ship.get_world_3d().direct_space_state.cast_motion(query)
				continuous_clear = continuous_clear and fractions[0] == 1.0 and fractions[1] == 1.0
				query.motion = Vector3.ZERO
			for hit in ship.get_world_3d().direct_space_state.intersect_shape(query, 32):
				failures.append("lift=%.2f shape=%s neighbor=%s" % [lift, ship.get_path_to(collision), hit.collider.get_path()])
	_check(failures.is_empty() and continuous_clear, "complete %s actual hull/access shapes and full 5m departure sweep clear live neighbors: %s" % ["deployed" if deployed else "closed", failures])
	# Actual clear elevated flight lane starts after the required 5m lift and
	# extends to the front edge of the configured broad acquisition box.
	_check(_box_clear(ship, Transform3D(ship.global_basis, ship.to_global(Vector3(0, 8.25, -24))), Vector3(12, 6.48, 76), [ship.get_rid()]),
		"complete-width elevated approach/departure lane clears live neighboring geometry")
	_check(_box_clear(ship, Transform3D(ship.global_basis, ship.to_global(Vector3(0, 3.5, 16))), Vector3(5, 2, 12), [ship.get_rid()]),
		"stern on-foot approach headroom clears station neighbors")
	_test_actual_chase_camera(ship)

func _box_clear(ship: HeroShip, pose: Transform3D, size: Vector3, excluded: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	query.shape = shape
	query.transform = pose
	query.margin = 0
	query.exclude = excluded
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	var hits := ship.get_world_3d().direct_space_state.intersect_shape(query, 32)
	if not hits.is_empty(): print("TITAN_CLEARANCE_HITS: ", hits)
	return hits.is_empty()

func _walk_to(player: PlayerController, target: Vector3, index: int) -> bool:
	var reached := false
	for frame in 900:
		var offset := target - player.global_position
		offset.y = 0
		# Avoid commanding a microscopic cross-axis correction after braking.
		# The unchanged 3.5 cm arrival tolerance already contains this residue.
		if absf(offset.x) < 0.02: offset.x = 0
		if absf(offset.z) < 0.02: offset.z = 0
		if offset.length() <= 0.035:
			reached = true
			break
		var local_direction := (player.get_node("%CameraYaw") as Node3D).global_basis.inverse() * offset.normalized()
		_release_inputs()
		var strength := 0.4 if offset.length() < 0.8 else 1.0
		var axis := Vector2(local_direction.x, local_direction.z) * strength
		Input.action_press(&"move_right" if axis.x > 0 else &"move_left", absf(axis.x))
		Input.action_press(&"move_back" if axis.y > 0 else &"move_forward", absf(axis.y))
		await physics_frame
		await process_frame
		_observe(player)
		if frame == 20 or frame == 899:
			print("TITAN_INPUT_STATE: leg=", index, " frame=", frame, " input=", Input.get_vector("move_left", "move_right", "move_forward", "move_back"), " vel=", player.velocity, " control=", player.get("_control_enabled"), " paused=", paused, " axis=", axis, " local=", local_direction, " embodiment=", player.get("_embodiment_state"), " remote=", player.get("_remote_drive_enabled"), " floor=", player.get_floor_normal(), " cabin=", player.get("_cabin_frame"))
	_release_inputs()
	for frame in 12:
		await physics_frame
		await process_frame
		_observe(player)
	print("TITAN_ROUTE_LEG: %d target=%s actual=%s reached=%s" % [index, target, player.global_position, reached])
	if not reached:
		var collision_shape := player.get_node("PlayerCollision") as CollisionShape3D
		for advance in [0.1, 0.3, 0.5]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collision_shape.shape
			query.transform = collision_shape.global_transform
			query.transform.origin += (target - player.global_position).slide(Vector3.UP).normalized() * advance
			query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
			query.exclude = [player.get_rid()]
			print("TITAN_ROUTE_AHEAD: advance=", advance, " hits=", player.get_world_3d().direct_space_state.intersect_shape(query, 16))
		for slide_index in player.get_slide_collision_count():
			var hit := player.get_slide_collision(slide_index)
			print("TITAN_ROUTE_STOP: ", hit.get_collider().get_path(), " at ", hit.get_position(), " normal=", hit.get_normal())
	return reached

func _observe(player: PlayerController) -> void:
	_frames += 1
	if player.is_on_floor(): _supported += 1
	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [player.get_rid()]
	var hits := player.get_world_3d().direct_space_state.intersect_shape(query, 8)
	if hits.is_empty(): _clear += 1
	elif _clear == _frames - 1: print("TITAN_CAPSULE_FIRST_HIT: pose=", player.global_position, " hits=", hits)

func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
func _wait_frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func _check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		print("FAIL: ", message)
		_failures.append(message)


func _test_actual_chase_camera(ship: HeroShip) -> void:
	var arm := ship.get_node("CameraRig/CameraCollisionArm") as SpringArm3D
	var camera := ship.get_camera()
	var clear := true
	for lift in [0.0, 5.0]:
		var sweep := PhysicsShapeQueryParameters3D.new()
		sweep.shape = arm.shape
		sweep.transform = arm.global_transform
		sweep.transform.origin += Vector3.UP * lift
		sweep.motion = arm.global_basis.z * arm.spring_length
		sweep.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		sweep.exclude = [ship.get_rid()]
		sweep.margin = arm.margin
		var fractions := ship.get_world_3d().direct_space_state.cast_motion(sweep)
		clear = clear and fractions[0] == 1.0 and fractions[1] == 1.0
		sweep.transform = camera.global_transform
		sweep.transform.origin += Vector3.UP * lift
		sweep.motion = Vector3.ZERO
		clear = clear and ship.get_world_3d().direct_space_state.intersect_shape(sweep).is_empty()
		if lift == 0.0:
			sweep.motion = Vector3.UP * 5
			var departure := ship.get_world_3d().direct_space_state.cast_motion(sweep)
			clear = clear and departure[0] == 1.0 and departure[1] == 1.0
	print("TITAN_ACTUAL_CAMERA: local=", ship.to_local(camera.global_position), " arm=", arm.spring_length, " shape=", (arm.shape as SphereShape3D).radius, " clear=", clear)
	_check(clear and ship.get_chase_camera_self_hull_boundary_report().valid,
		"actual default inherited chase-camera sphere/arm and near plane clear live neighbors and own hull at berth and full5m lift")
