extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var player := game.get_node("Player") as PlayerController
	var module := world.get_node_or_null("AftJunctionStack") as AftJunctionStack
	_check(module != null, "the aft junction is instantiated inside the shared shipyard world")
	if module == null:
		game.queue_free()
		await process_frame
		_finish()
		return
	_check(module.get_validation_errors().is_empty(), "integrated junction retains its evidence and structure audit")
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
	await create_timer(1.75).timeout
	Input.action_release("sprint_boost")
	Input.action_release("move_forward")
	await physics_frame
	var stair_local := module.to_local(player.global_position)
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
	await create_timer(0.7).timeout
	_check(operations_door.is_open() and not operations_door.is_portal_blocked(), "operations access opens a genuinely clear physical portal")
	Input.action_press("move_forward")
	await create_timer(0.8).timeout
	Input.action_release("move_forward")
	await physics_frame
	_check(module.contains_operations_room(player.global_position), "the production player walks through the door into the enterable operations room")
	_check(module.get_vip_access().deferred_access, "the red VIP landmark remains explicit deferred content rather than an invented room")

	Input.action_release("move_forward")
	Input.action_release("sprint_boost")
	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


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
