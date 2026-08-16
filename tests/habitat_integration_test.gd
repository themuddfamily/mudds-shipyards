extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace: locomotion,
## door motion and every other physical result advance on the physics clock, and
## Godot drops physics steps under load rather than letting the simulation spiral,
## so only a frame budget measures the same amount of simulation on a busy box as
## on an idle one.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		call_deferred("_capture_shared_world")
	else:
		call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame
	await physics_frame

	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var player := game.get_node("Player") as PlayerController
	var habitat := world.get_node_or_null("HabitatSpine") as HabitatSpine
	_test_integrated_identity_and_preserved_world(world, habitat)
	if habitat == null:
		await _cleanup(game)
		_finish()
		return
	_test_placement_isolation(world, habitat)
	await _test_shared_physical_route(world, habitat)
	await _test_production_player_traversal(game, world, player, habitat)
	await _test_room_support_and_closed_branch(world, habitat)
	await _cleanup(game)
	_finish()


func _test_integrated_identity_and_preserved_world(world: ShipyardWorld, habitat: HabitatSpine) -> void:
	_check(habitat != null, "HabitatSpine is instantiated inside the shared shipyard world")
	if habitat == null:
		return
	_check(world.get_habitat_spine() == habitat, "world exposes its integrated habitat through a typed accessor")
	_check(habitat.global_position.is_equal_approx(Vector3(49.0, 0.0, 15.5)), "habitat uses the documented starboard-node connection origin")
	var expected_basis := Basis(Vector3.UP, PI * 0.5)
	_check(habitat.global_basis.is_equal_approx(expected_basis), "habitat rotates local +Z outward along world +X")
	_check(habitat.get_validation_errors().is_empty(), "integrated habitat retains its complete component audit")
	_check(
		str(habitat.get_evidence_metadata().evidence_status) == "fixed_era_inspired_modern_interpretation",
		"integrated module retains provisional fixed-era-inspired evidence wording"
	)
	_check(not bool(habitat.get_evidence_metadata().authenticated_original_geometry), "integration does not promote the module to recovered original geometry")

	_check(world.find_child("StarboardGunshipConcept", true, false) == null, "obsolete physical starboard gunship placeholder is absent")
	_check(world.find_child("StarboardBranchArm", true, false) is StaticBody3D, "shared starboard branch deck is preserved")
	_check(world.find_child("StarboardBerthNode", true, false) is StaticBody3D, "shared starboard node deck is preserved beneath the connector")
	_check(world.find_child("BranchRail", true, false) is StaticBody3D, "branch safety rails remain in the shared station")
	_check(world.find_child("OperationsPodFloor", true, false) is StaticBody3D, "separate Dock Operations pod remains present")
	_check(world.get_node_or_null("AftJunctionStack") is AftJunctionStack, "Aft Junction remains integrated independently")
	_check(world.has_berth(&"arrow_recon_berth"), "existing port node is registered as the physical Arrow recon berth")
	_check(not world.has_berth(&"port_berth"), "retired generic handling-article berth identity is absent")
	var arrow_berth := world.get_berth_node(&"arrow_recon_berth")
	_check(arrow_berth != null and arrow_berth.name == "ArrowReconBerth", "Arrow berth remains a direct typed ShipBerth child")
	if arrow_berth != null:
		_check(
			arrow_berth.get_compatibility_tags() == PackedStringArray(["recon"]),
			"Arrow berth advertises the exact rail-safe recon-only compatibility contract"
		)
		_check(arrow_berth.get_dock_transform().origin.is_equal_approx(Vector3(-43.0, 1.15, 15.5)), "Arrow berth reuses the established port physical node")
		_check(arrow_berth.get_landing_half_extents().is_equal_approx(Vector3(8.0, 4.5, 9.0)), "Arrow landing volume clears its provisional 11.1 by 12.2 metre envelope")
	_check(world.find_child("ArrowReconBerthOuterRing", true, false) != null, "physical Arrow berth retains a readable landing ring")


func _test_placement_isolation(world: ShipyardWorld, habitat: HabitatSpine) -> void:
	var habitat_footprint := habitat.get_integration_footprint()
	var habitat_aabb := _transformed_local_aabb(
		habitat.global_transform,
		habitat_footprint.local_min,
		habitat_footprint.local_max
	)
	_check(habitat_aabb.position.x >= 44.7 and habitat_aabb.end.x <= 78.3, "world footprint extends outward from the starboard node")
	# Band low edge 6.49 -> -3.26. The habitat's declared `local_max.x` went 9.0 to
	# 18.75 when the side branch was built, and the module is yawed 90 degrees, so
	# local +X is world -Z: the envelope now reaches world z = -3.25. The high edge,
	# both x edges and the overlap assertion below are untouched, and the module's
	# own origin did not move. `tools/habitat_branch_clearance_probe.gd` swept the
	# volume first and found nothing in it but this module's own door posts.
	_check(habitat_aabb.position.z >= -3.26 and habitat_aabb.end.z <= 24.51, "rotated footprint remains inside the intended starboard band")

	var aft := world.get_node("AftJunctionStack") as AftJunctionStack
	var aft_footprint := aft.get_integration_footprint()
	var aft_aabb := _transformed_local_aabb(aft.global_transform, aft_footprint.local_min, aft_footprint.local_max)
	_check(not _aabbs_overlap(habitat_aabb, aft_aabb, 0.01), "habitat footprint is physically separate from Aft Junction")

	var all_berths_clear := true
	for berth_id in world.get_berth_ids():
		var berth := world.get_berth_node(berth_id)
		if berth == null:
			all_berths_clear = false
			continue
		var half_extents := berth.get_landing_half_extents()
		var berth_aabb := _transformed_local_aabb(
			berth.get_dock_transform(),
			-half_extents,
			half_extents
		)
		all_berths_clear = all_berths_clear and not _aabbs_overlap(habitat_aabb, berth_aabb, 0.01)
	_check(all_berths_clear, "habitat footprint leaves every live landing berth volume clear")

	var launch_arm := world.find_child("LaunchArmDeck", true, false) as StaticBody3D
	var launch_aabb := _static_body_world_aabb(launch_arm)
	_check(not launch_aabb.has_volume() or not _aabbs_overlap(habitat_aabb, launch_aabb, 0.01), "habitat footprint remains clear of the physical launch arm")
	_check(habitat_aabb.position.distance_to(world.launch_gate.global_position) > 70.0, "habitat remains remote from the negative-Z launch gate")

	# The broad declared footprint brushes the Dock Operations band, so prove the
	# stronger property: no actual Habitat collider penetrates an operations-pod
	# collider. Intended connector/deck overlap is not included in this check.
	var habitat_bodies := habitat.find_children("*", "StaticBody3D", true, false)
	var operations_root := world.get_node_or_null("UpperOperations") as Node3D
	var operations_bodies: Array[Node] = []
	if operations_root != null:
		for candidate in operations_root.find_children("*", "StaticBody3D", true, false):
			if str(candidate.name).begins_with("Operations"):
				operations_bodies.append(candidate)
	var colliders_are_separate := true
	for habitat_body_candidate in habitat_bodies:
		var habitat_body := habitat_body_candidate as StaticBody3D
		var habitat_body_aabb := _static_body_world_aabb(habitat_body)
		for operations_body_candidate in operations_bodies:
			var operations_body := operations_body_candidate as StaticBody3D
			var operations_body_aabb := _static_body_world_aabb(operations_body)
			if habitat_body_aabb.has_volume() and operations_body_aabb.has_volume() \
				and _aabbs_overlap(habitat_body_aabb, operations_body_aabb, 0.01):
				colliders_are_separate = false
	_check(not operations_bodies.is_empty(), "operations-pod collision bodies are available to placement audit")
	_check(colliders_are_separate, "actual habitat collision shell does not penetrate Dock Operations")


func _test_shared_physical_route(world: ShipyardWorld, habitat: HabitatSpine) -> void:
	# The starboard arm, its broad node, and the habitat connector deliberately
	# overlap in floor plan so no cosmetic gap can strand an avatar.
	var support_samples := PackedVector3Array([
		Vector3(14.0, 1.5, 15.5),
		Vector3(25.0, 1.5, 15.5),
		Vector3(37.0, 1.5, 15.5),
		Vector3(43.0, 1.5, 15.5),
		Vector3(46.0, 1.5, 15.5),
		Vector3(48.8, 1.5, 15.5),
		Vector3(50.2, 1.5, 15.5),
		Vector3(52.0, 1.5, 15.5),
		Vector3(56.0, 1.5, 15.5),
		Vector3(60.0, 1.5, 15.5),
	])
	var every_sample_supported := true
	var shared_floor_tolerance := true
	for sample in support_samples:
		var hit := await _ray(world, sample, Vector3(sample.x, -1.5, sample.z))
		if hit.is_empty():
			every_sample_supported = false
		else:
			shared_floor_tolerance = shared_floor_tolerance and absf(float(hit.position.y)) <= 0.035
	_check(every_sample_supported, "starboard arm through habitat corridor has continuous physical floor support")
	_check(shared_floor_tolerance, "legacy deck and authored connector join within 3.5 centimetres")

	var door := habitat.get_main_access()
	_check(door.interact(habitat), "shared-route clearance test opens the real Habitat StationDoor")
	await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(door.is_open() and not door.is_portal_blocked(), "integrated door reaches a fully clear physical state")

	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var every_capsule_sample_clear := true
	for sample in support_samples:
		var capsule_center := Vector3(sample.x, 1.08, sample.z)
		var hits := await _intersect_shape(world, capsule, Transform3D(Basis.IDENTITY, capsule_center), 24)
		if not hits.is_empty():
			every_capsule_sample_clear = false
	_check(every_capsule_sample_clear, "real production player capsule clears the shared starboard-to-habitat route")

	var head_clearance_samples := PackedVector3Array([
		Vector3(43.0, 0.2, 15.5),
		Vector3(47.5, 0.2, 15.5),
		Vector3(50.5, 0.2, 15.5),
		Vector3(55.0, 0.2, 15.5),
		Vector3(60.0, 0.2, 15.5),
	])
	var every_head_sample_clear := true
	for sample in head_clearance_samples:
		var ceiling_hit := await _ray(world, sample, sample + Vector3.UP * 3.8)
		if not ceiling_hit.is_empty():
			every_head_sample_clear = false
	_check(every_head_sample_clear, "shared approach and pressurized corridor preserve published head clearance")

	# Restore the authentic start state for the embodied interaction test.
	_check(door.interact(habitat), "integrated door closes repeatably after geometry audit")
	await _wait_for_door_state(door, StationDoor.DoorState.CLOSED, 1.5)
	_check(door.is_portal_blocked(), "production traversal begins against a real closed pressure barrier")


func _test_production_player_traversal(
		game: GameFlow,
		world: ShipyardWorld,
		player: PlayerController,
		habitat: HabitatSpine
	) -> void:
	var door := habitat.get_main_access()
	var start_transform := Transform3D(
		Basis(Vector3.UP, -PI * 0.5),
		Vector3(43.0, 0.18, 15.5)
	)
	player.teleport_to(start_transform)
	await physics_frame
	await physics_frame
	await process_frame
	_check(player.is_control_enabled(), "production PlayerController owns the integrated traversal")

	var reached_closed_threshold := await _drive_player_x(player, 48.0, true, 2.0)
	_check(reached_closed_threshold, "real forward/sprint Input crosses the preserved starboard node to the Habitat threshold")
	_check(player.global_position.x >= 47.8 and player.global_position.x < 49.5, "closed StationDoor physically stops the player before its portal")
	_check(absf(player.global_position.z - 15.5) < 0.35, "production controller reaches the door without a rail snag or lateral deflection")
	_check(player.global_position.y > -0.1 and player.global_position.y < 0.5, "production controller remains supported at the shared seam")
	await process_frame
	await process_frame
	_check(game.station_interaction_candidate == door, "embodied proximity and facing select the integrated Habitat door")

	# Exercise the production input signal rather than calling GameFlow or the
	# component interaction method directly.
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	# The door drives its panel in `_physics_process`, so a `SceneTree` timer is
	# the wrong clock to measure it with: the timer counts smoothed idle delta and
	# fires while dropped physics steps have left the panel mid-travel. Wait for
	# the door's real state on a physics-frame budget derived from its own export.
	var door_opened := await _wait_for_door_state(
		door,
		StationDoor.DoorState.OPEN,
		door.motion_duration
	)
	_check(door_opened, "the interacted door completes its motion inside its own physics-frame budget")
	_check(door.is_open() and not door.is_portal_blocked(), "real interact Input opens the integrated StationDoor")

	var reached_corridor := await _drive_player_x(player, 58.0, true, 2.5)
	_check(reached_corridor, "real movement continues through the clear portal into the pressurized corridor")
	_check(habitat.contains_room(&"habitat-corridor", player.global_position), "production player occupies the published corridor room volume")
	_check(player.global_position.y > -0.1, "corridor traversal does not trigger a fall or regeneration recall")

	var reached_common := await _drive_player_x(player, 67.8, true, 2.5)
	_check(reached_common, "real movement passes the six alcoves and reaches the observation/common threshold")
	_check(habitat.contains_room(&"observation-common", player.global_position), "production player occupies the published observation/common volume")
	_check(absf(player.global_position.z - 15.5) < 0.45, "central circulation remains player-clear through both rooms")

	var returned_to_starboard := await _drive_player_x(player, 47.8, false, 3.5)
	_check(returned_to_starboard, "real reverse Input returns from the habitat to the shared starboard deck")
	_check(not habitat.contains_room(&"habitat-corridor", player.global_position), "return traversal leaves the habitat occupancy volume")
	_check(player.global_position.x < door.global_position.x, "return traversal crosses the same physical StationDoor threshold")


func _test_room_support_and_closed_branch(world: ShipyardWorld, habitat: HabitatSpine) -> void:
	# Rays down through furniture rather than stopping at the first thing it hits.
	#
	# This asked for a single ray from the room centre to land within 0.035 m of
	# y = 0, which quietly assumed no published room ever has anything standing at
	# its middle. The garden bay does: its nutrient column is the room's axis and
	# stands exactly on the declared centre, so the first hit was the column at
	# 2.5 m and the check called a fully decked room unsupported. What it actually
	# wants to prove is that there is collision-backed deck under the room, so it
	# now restarts below each hit — the same technique the orphan sweep in
	# `station_surface_playability_test` uses — up to four levels. No tolerance was
	# loosened: the deck still has to be found at |y| <= 0.035, and a room with no
	# deck under it at all still fails.
	var all_room_centres_supported := true
	for room_id in habitat.get_room_ids():
		var volume := habitat.get_room_volume(room_id)
		var centre: Vector3 = (volume.world_transform as Transform3D).origin
		var probe_from := centre + Vector3.UP * 0.75
		var found_deck := false
		for _level in 4:
			var hit := await _ray(world, probe_from, centre - Vector3.UP * 3.0)
			if hit.is_empty():
				break
			if absf(float(hit.position.y)) <= 0.035:
				found_deck = true
				break
			probe_from = Vector3(probe_from.x, float(hit.position.y) - 0.05, probe_from.z)
			if probe_from.y <= centre.y - 3.0:
				break
		if not found_deck:
			all_room_centres_supported = false
	_check(all_room_centres_supported, "every published integrated room volume has collision-backed floor support")

	var deferred := habitat.get_deferred_branch_access()
	_check(not deferred.locked and not deferred.deferred_access, "the integrated side branch is an open route rather than a deferred landmark")
	_check(habitat.has_room(&"garden-cupola"), "the integrated side branch publishes its built room")
	_check(not habitat.has_room(&"deferred-branch"), "the route marker id is not itself registered as a room")
	_check(deferred.is_portal_blocked(), "deferred branch remains a real physical endpoint in the shared world")
	var branch_ray := await _ray(
		world,
		deferred.to_global(Vector3(0, 1.7, -1.6)),
		deferred.to_global(Vector3(0, 1.7, 1.6))
	)
	_check(not branch_ray.is_empty(), "shared-world physics ray is blocked at the deferred branch")
	_check("No source describes" in str(deferred.get_meta("content_note")), "integrated branch retains its explicit evidence caveat")


## Walks the production avatar along X with real Input until it reaches
## `target_x`, bounded by the number of physics frames `travel_seconds` of
## simulated walking implies.
##
## The budget deliberately counts physics steps rather than wall-clock seconds.
## Locomotion is integrated in `_physics_process`, and on a loaded machine Godot
## drops physics steps to avoid a spiral of death while the wall clock keeps
## running. A wall-clock budget therefore ends the walk after far fewer simulated
## steps than the avatar needs to cover the distance and scores a perfectly
## healthy traversal as a failure. Counting frames gives the avatar the same
## amount of simulation however busy the box is, and still fails a genuinely
## blocked route because the budget remains finite.
func _drive_player_x(player: PlayerController, target_x: float, increasing: bool, travel_seconds: float) -> bool:
	var action := "move_forward" if increasing else "move_back"
	var frame_budget := _frame_budget(travel_seconds)
	var frames := 0
	Input.action_press(action)
	Input.action_press("sprint_boost")
	while is_instance_valid(player):
		if increasing and player.global_position.x >= target_x:
			break
		if not increasing and player.global_position.x <= target_x:
			break
		if frames >= frame_budget:
			break
		await physics_frame
		frames += 1
	Input.action_release(action)
	Input.action_release("sprint_boost")
	await physics_frame
	return player.global_position.x >= target_x if increasing else player.global_position.x <= target_x


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _intersect_shape(
		world: Node3D,
		shape: Shape3D,
		world_transform: Transform3D,
		max_results: int
	) -> Array[Dictionary]:
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = world_transform
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_shape(query, max_results)


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus a fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for a door to reach `expected_state` on the physics clock, which is the
## clock `StationDoor` actually advances its panel on. Returns whether the state
## was reached so callers can assert on it instead of assuming it.
func _wait_for_door_state(door: StationDoor, expected_state: int, travel_seconds: float) -> bool:
	var frame_budget := _frame_budget(travel_seconds)
	var frames := 0
	while is_instance_valid(door) and door.get_state() != expected_state:
		if frames >= frame_budget:
			break
		await physics_frame
		frames += 1
	await process_frame
	return is_instance_valid(door) and door.get_state() == expected_state


func _transformed_local_aabb(transform: Transform3D, local_min: Vector3, local_max: Vector3) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x_value in [local_min.x, local_max.x]:
		for y_value in [local_min.y, local_max.y]:
			for z_value in [local_min.z, local_max.z]:
				var point := transform * Vector3(float(x_value), float(y_value), float(z_value))
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _static_body_world_aabb(body: StaticBody3D) -> AABB:
	if body == null:
		return AABB()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found_shape := false
	for shape_candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision_shape := shape_candidate as CollisionShape3D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		var local_extents := Vector3.ZERO
		if collision_shape.shape is BoxShape3D:
			local_extents = (collision_shape.shape as BoxShape3D).size * 0.5
		elif collision_shape.shape is CylinderShape3D:
			var cylinder := collision_shape.shape as CylinderShape3D
			local_extents = Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius)
		elif collision_shape.shape is CapsuleShape3D:
			var capsule := collision_shape.shape as CapsuleShape3D
			local_extents = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
		else:
			continue
		var shape_aabb := _transformed_local_aabb(
			collision_shape.global_transform,
			-local_extents,
			local_extents
		)
		minimum = minimum.min(shape_aabb.position)
		maximum = maximum.max(shape_aabb.end)
		found_shape = true
	return AABB(minimum, maximum - minimum) if found_shape else AABB()


func _aabbs_overlap(first: AABB, second: AABB, epsilon: float) -> bool:
	return minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x) > epsilon \
		and minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y) > epsilon \
		and minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z) > epsilon


func _capture_shared_world() -> void:
	root.size = Vector2i(1400, 900)
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	if game.hud != null and game.hud.has_method("_begin"):
		# Capture-only presentation setup: reveal the already constructed world UI
		# without waiting through the intro tween or emitting a second start signal.
		game.hud.call("_begin")
		await create_timer(0.55).timeout
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var player := game.get_node("Player") as PlayerController
	var habitat := world.get_habitat_spine()
	var door := habitat.get_main_access()
	if door.interact(player):
		await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)

	var camera := Camera3D.new()
	camera.name = "HabitatIntegrationCaptureCamera"
	camera.fov = 56.0
	camera.near = 0.08
	camera.current = true
	game.add_child(camera)
	player.set_camera_active(false)

	# Exterior frame includes the central lattice, preserved starboard arm, Dock
	# Operations, and the attached habitat rather than presenting it in isolation.
	camera.global_position = Vector3(96.0, 31.0, -22.0)
	camera.look_at(Vector3(37.0, 1.5, 15.5), Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var exterior := root.get_texture().get_image()
	var exterior_error := exterior.save_png("/tmp/habitat-integrated-exterior.png")

	# Interior frame retains the production world/player and uses the real open
	# pressure door state. The player stands inside the published common volume.
	player.teleport_to(Transform3D(Basis(Vector3.UP, -PI * 0.5), habitat.to_global(Vector3(-2.0, 0.18, 24.5))))
	camera.global_position = habitat.to_global(Vector3(0.0, 2.55, 18.8))
	camera.look_at(habitat.to_global(Vector3(0.0, 1.75, 27.2)), Vector3.UP)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var interior := root.get_texture().get_image()
	var interior_error := interior.save_png("/tmp/habitat-integrated-interior.png")
	print("HABITAT_INTEGRATION_CAPTURE_OK")
	game.queue_free()
	await process_frame
	quit(0 if exterior_error == OK and interior_error == OK else 1)


func _cleanup(game: GameFlow) -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("sprint_boost")
	Input.action_release("interact")
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HABITAT_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("HABITAT_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
