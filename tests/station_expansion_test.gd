extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SHIPYARD_WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until].
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authored_world := SHIPYARD_WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(authored_world)
	await process_frame
	var authored_tie_socket := authored_world.get_node_or_null(^"LandingPad/IntegratedDeckServices/TieDownSocket") as MeshInstance3D
	var authored_tie_mesh := authored_tie_socket.mesh as TorusMesh if authored_tie_socket != null else null
	var authored_tie_down_audit := authored_world.get_tie_down_socket_allocation_audit()
	_check(
		bool(authored_tie_down_audit.valid) \
			and authored_tie_mesh != null \
			and not authored_tie_mesh.has_meta(TorusGeometryBudget.AUTHORED_META) \
			and authored_tie_mesh.rings == 64 \
			and authored_tie_mesh.ring_segments == 16,
		"tie-down sockets retain the authored 64 by 16 recipe before TorusGeometryBudget"
	)
	_test_drain_slat_batch(authored_world)
	authored_world.queue_free()
	await process_frame
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	game.start_shift()
	var player := game.get_node("Player") as PlayerController
	var module := world.get_node_or_null("AftJunctionStack") as AftJunctionStack
	var tie_down_audit := world.get_tie_down_socket_allocation_audit()
	_check(bool(tie_down_audit.valid) and int(tie_down_audit.copies) == 6 and int(tie_down_audit.mesh_resource_allocations) == 1, "six flush tie-down sockets share one presentation-only torus mesh")
	var tie_socket := world.get_node_or_null(^"LandingPad/IntegratedDeckServices/TieDownSocket") as MeshInstance3D
	if tie_socket != null:
		var tie_mesh := tie_socket.mesh
		tie_socket.mesh = tie_mesh.duplicate() as TorusMesh
		var tie_red := world.get_tie_down_socket_allocation_audit()
		tie_socket.mesh = tie_mesh
		_check(not bool(tie_red.valid) and (tie_red.errors as PackedStringArray).has("tie_down_socket_mesh_count_drift") and bool(world.get_tie_down_socket_allocation_audit().valid), "splitting one tie-down mesh is a structured red and restores")
	TorusGeometryBudget.normalise_tree(world)
	_check(bool(world.get_tie_down_socket_allocation_audit().valid), "TorusGeometryBudget preserves tie-down sharing")
	_check(module != null, "the aft junction is instantiated inside the shared shipyard world")
	if module == null:
		game.queue_free()
		await process_frame
		_finish()
		return
	var junction_errors := module.get_validation_errors()
	_check(
		junction_errors.is_empty(),
		"integrated junction retains its evidence and structure audit: %s" % [junction_errors]
	)
	var ceiling_lens_audit := module.get_ceiling_luminaire_lens_batch_audit()
	_check(
		bool(ceiling_lens_audit.valid) \
			and int(ceiling_lens_audit.legacy.renderer_nodes) == 6 \
			and int(ceiling_lens_audit.current.renderer_nodes) == 1 \
			and int(ceiling_lens_audit.current.drawn_copies) == 6 \
			and int(ceiling_lens_audit.fixture_housings) == 6 \
			and int(ceiling_lens_audit.fixture_practicals) == 6 \
			and not bool(ceiling_lens_audit.collision_authority_added) \
			and not bool(ceiling_lens_audit.interaction_authority_added),
		"six Aft luminaire lenses retain their fixtures and visible copies in one inert renderer"
	)
	var door_indicator_batches_current := true
	for door in [module.get_operations_entrance(), module.get_vip_access()]:
		var left_indicator := door.get_node_or_null(
			^"SlidingPanel/LeftIndicator"
		) as MeshInstance3D
		var right_indicator := door.get_node_or_null(
			^"SlidingPanel/RightIndicator"
		) as MeshInstance3D
		var indicator_batch := door.get_node_or_null(
			^"SlidingPanel/IndicatorRenderBatch"
		) as MultiMeshInstance3D
		var indicator_multi := indicator_batch.multimesh if indicator_batch != null else null
		door_indicator_batches_current = door_indicator_batches_current \
			and left_indicator != null \
			and right_indicator != null \
			and indicator_batch != null \
			and indicator_multi != null \
			and left_indicator.visible \
			and right_indicator.visible \
			and left_indicator.layers == 0 \
			and right_indicator.layers == 0 \
			and indicator_batch.layers == 1 \
			and indicator_multi.instance_count == 2 \
			and indicator_multi.visible_instance_count == -1 \
			and indicator_batch.material_override == left_indicator.material_override \
			and indicator_batch.material_override == right_indicator.material_override
	_check(
		door_indicator_batches_current,
		"both Aft access doors render their two host-coloured indicators through the live batches"
	)
	_check(module.global_position.is_equal_approx(Vector3(0.0, 0.0, 48.0)), "module uses the documented aft-spine connection plane")

	# Prove that the procedural spine, new connector, and authored module form one
	# physical route rather than merely touching visually.
	var route_supported := true
	for z_position in [24.0, 32.0, 39.0, 43.5, 47.7, 50.0]:
		var support := await _ray(world, Vector3(0.0, 2.0, z_position), Vector3(0.0, -2.0, z_position))
		route_supported = route_supported and not support.is_empty()
	_check(route_supported, "central deck, connector, and module approach have continuous physical support")
	var portal_clear := await _ray(world, Vector3(0.0, 1.2, 20.5), Vector3(0.0, 1.2, 24.5))
	_check(portal_clear.is_empty(), "the navigation sign is an open player route rather than the former solid wall")

	# Traverse the new stair with the production CharacterBody controller and real
	# InputMap actions. The ramp under visible treads is deliberately tested as a
	# locomotion surface, not only with raycasts.
	var stair_base := module.get_route_transform(&"stair-base").origin
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), stair_base + Vector3.UP * 0.2))
	await physics_frame
	Input.action_press("move_forward")
	Input.action_press("sprint_boost")
	var climbed_in_budget := await _wait_until(
		func() -> bool:
			var probe := module.to_local(player.global_position)
			return probe.y > 3.75 and probe.z > 12.0,
		1.75
	)
	Input.action_release("sprint_boost")
	Input.action_release("move_forward")
	await physics_frame
	var stair_local := module.to_local(player.global_position)
	_check(climbed_in_budget, "the stair climb completes inside its bounded simulated-frame budget")
	_check(stair_local.y > 3.75 and stair_local.z > 12.0, "real on-foot movement climbs from the lower deck to the upper level")

	# Use the same proximity/facing interaction path as ship boarding, then walk
	# through the fully clear physical portal into the operations room.
	var operations_door := module.get_operations_entrance()
	var door_start := operations_door.global_position + Vector3(0.0, 0.18, -2.0)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), door_start))
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(game.station_interaction_candidate == operations_door, "the integrated operations door is discovered by embodied proximity and facing")
	game.call("_on_interact_requested")
	var door_opened_in_budget := await _wait_until(
		func() -> bool: return operations_door.is_open() and not operations_door.is_portal_blocked(),
		0.7
	)
	_check(door_opened_in_budget, "operations access clears its portal inside the bounded panel-travel budget")
	_check(operations_door.is_open() and not operations_door.is_portal_blocked(), "operations access opens a genuinely clear physical portal")
	Input.action_press("move_forward")
	var entered_in_budget := await _wait_until(
		func() -> bool: return module.contains_operations_room(player.global_position),
		0.8
	)
	Input.action_release("move_forward")
	await physics_frame
	_check(entered_in_budget, "the walk through the portal completes inside its bounded simulated-frame budget")
	_check(module.contains_operations_room(player.global_position), "the production player walks through the door into the enterable operations room")
	# The landmark is no longer deferred — it opens onto `VipReceptionSuite` — so
	# what is asserted here is the thing that still has to be true: the room behind
	# it is published as an invention, at confidence none, by the module that owns
	# it rather than by the module that owns the door.
	_check(not module.get_vip_access().deferred_access, "the red VIP landmark now opens onto its published interpretation interior")
	var suite := world.get_node_or_null(^"VipReceptionSuite")
	_check(suite != null, "the interpretation interior behind the landmark is live in the production world")
	if suite != null:
		var suite_evidence: Dictionary = suite.call("get_evidence_metadata")
		_check(str(suite_evidence.get("evidence_status", "")) == "modern_interpretation", "the VIP interior publishes modern_interpretation")
		_check(str(suite_evidence.get("source_confidence", "")) == "none", "the VIP interior publishes confidence none")
		_check(not bool(suite_evidence.get("reproduces_observed_interior", true)), "the VIP interior claims to reproduce nothing")

	Input.action_release("move_forward")
	Input.action_release("sprint_boost")
	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_drain_slat_batch(world: ShipyardWorld) -> void:
	var details := world.get_node_or_null(^"LandingPad/IntegratedDeckServices") as Node3D
	var batch := details.get_node_or_null(^"DrainSlatVisuals") as MultiMeshInstance3D \
		if details != null else null
	var multi := batch.multimesh if batch != null else null
	var expected_transforms: Array[Transform3D] = []
	for drain_position in [
		Vector3(-9.6, 0.104, -20.0),
		Vector3(9.6, 0.104, -20.0),
		Vector3(-9.6, 0.104, 0.0),
		Vector3(9.6, 0.104, 0.0),
	]:
		for slat_index in 5:
			expected_transforms.append(
				Transform3D(
					Basis.IDENTITY,
					drain_position + Vector3(-0.64 + float(slat_index) * 0.32, 0.015, 0.0)
				)
			)
	var slat_mesh := multi.mesh if multi != null else null
	var expected_bounds := AABB()
	if slat_mesh != null:
		for index in expected_transforms.size():
			var transformed_bounds := (expected_transforms[index] * slat_mesh.get_aabb()).abs()
			expected_bounds = transformed_bounds if index == 0 else expected_bounds.merge(transformed_bounds)
	var tie_socket := details.get_node_or_null(^"TieDownSocket") as MeshInstance3D \
		if details != null else null
	_check(
		batch != null \
			and multi != null \
			and multi.transform_format == MultiMesh.TRANSFORM_3D \
			and multi.visible_instance_count == -1 \
			and multi.instance_count == expected_transforms.size() \
			and multi.buffer == _encode_multimesh_transforms(expected_transforms) \
			and slat_mesh != null \
			and slat_mesh.get_aabb().size.is_equal_approx(Vector3(0.055, 0.012, 0.29)) \
			and multi.custom_aabb.is_equal_approx(expected_bounds) \
			and tie_socket != null \
			and batch.material_override == tie_socket.material_override \
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			and batch.layers == 1,
		"twenty identical drain slats retain exact geometry/transforms in one shadow-casting submission"
	)
	var anchors := details.find_children("*", "Marker3D", true, false) \
		if details != null else []
	anchors = anchors.filter(func(anchor: Node) -> bool: return anchor.has_meta("visual_batch_index"))
	var anchors_are_inert := anchors.size() == 20
	for raw_anchor in anchors:
		var anchor := raw_anchor as Marker3D
		anchors_are_inert = anchors_are_inert \
			and anchor != null \
			and anchor.find_children("*", "GeometryInstance3D", true, false).is_empty() \
			and anchor.find_children("*", "CollisionObject3D", true, false).is_empty()
	_check(
		anchors_are_inert,
		"all twenty historical drain-slat paths remain inert anchors with no render or collision authority"
	)


func _encode_multimesh_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


## Waits for `predicate` on a finite simulation-frame budget.
##
## The stair climb, the door panel travel and the walk through the portal are all
## integrated in `_physics_process`. A `SceneTree` timer counts Godot's smoothed
## engine delta, which is neither that clock nor the monotonic one; under load
## Godot drops physics steps rather than letting the simulation spiral, so a
## sleep ended while the avatar still had metres to walk in simulated time and
## the assertion on the next line probed a traversal that was still in progress
## — a false failure, not a defect.
##
## `nominal_seconds` is kept as the expected simulated duration and becomes a
## finite frame budget, so a genuinely blocked route still fails the suite.
func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(nominal_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_EXPANSION_TEST_OK")
		quit(0)
	else:
		print("STATION_EXPANSION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
