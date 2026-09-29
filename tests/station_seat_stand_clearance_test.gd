extends SceneTree

## Every fixed seat in the station's walkable interiors must let the pilot stand
## up onto clear floor and walk away.
##
## Standing places the player at the seat's exit pose. The Aft coordinator chair
## faces its desk from 1.09 m, and its exit pose — 1.2 m straight ahead — landed
## inside the desk: after "[E] STAND" the capsule was wedged between desk and
## chair and could not move in any direction. This suite sits and stands through
## GameFlow's real seat flow, then drives real movement input from the pose.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SEAT_OWNERS: Array[NodePath] = [
	^"AftJunctionStack",
	^"HabitatSpine",
	^"VipReceptionSuite",
]
## Slightly under the production 0.38 m capsule so resting contact is not an overlap.
const CLEARANCE_RADIUS := 0.36
const WALK_FRAMES := 40
const WALK_AWAY_METRES := 0.75
## Of eight headings, at least this many must carry the pilot clear of the pose.
const MINIMUM_OPEN_HEADINGS := 3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for _settle in 6:
		await physics_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(world != null and player != null, "production world and player are live")
	if world == null or player == null:
		await _teardown(game)
		return

	var seats: Array[StationSeat] = []
	for owner_path in SEAT_OWNERS:
		var owner := world.get_node_or_null(owner_path)
		_check(owner != null, "%s is present in production Main" % owner_path)
		if owner == null:
			continue
		for seat in owner.find_children("*", "StationSeat", true, false):
			seats.append(seat as StationSeat)
	_check(seats.size() >= 20, "the interior seat roster is discovered (%d seats)" % seats.size())

	for seat in seats:
		await _test_seat(game, world, player, seat)

	await _teardown(game)


func _test_seat(game: GameFlow, world: ShipyardWorld, player: PlayerController, seat: StationSeat) -> void:
	var label := str(world.get_path_to(seat.get_parent()))
	_release()
	player.teleport_to(seat.get_exit_transform())
	for _settle in 4:
		await physics_frame
	await process_frame
	await process_frame
	var candidate: Variant = game.station_interaction_candidate
	_check(candidate == seat, "%s: its sit prompt is selected from its own stand pose" % label)
	game.call("_sit_in_station_seat", seat)
	var sat := await _wait(func() -> bool: return player.is_station_seated() and player.is_control_enabled(), 120)
	_check(sat, "%s: the pilot sits" % label)
	if not sat:
		return
	game.call("_stand_from_station_seat")
	var stood := await _wait(func() -> bool: return not player.is_seated() and player.is_control_enabled(), 120)
	_check(stood, "%s: the pilot stands back up" % label)
	if not stood:
		return
	for _settle in 6:
		await physics_frame

	var pose := player.global_position
	var overlaps := _world_overlaps(player)
	_check(overlaps.is_empty(), "%s: the standing pose is clear of solid geometry %s" % [label, overlaps])

	var distances := PackedFloat32Array()
	var open_headings := 0
	for heading in 8:
		player.global_position = pose
		player.velocity = Vector3.ZERO
		await physics_frame
		(player.get("_camera_yaw") as Node3D).rotation.y = TAU * float(heading) / 8.0
		Input.action_press(&"move_forward")
		for _frame in WALK_FRAMES:
			await physics_frame
		_release()
		var moved := Vector2(player.global_position.x - pose.x, player.global_position.z - pose.z).length()
		distances.append(snappedf(moved, 0.01))
		if moved >= WALK_AWAY_METRES:
			open_headings += 1
	player.global_position = pose
	player.velocity = Vector3.ZERO
	print("SEAT_STAND_POSE ", label, " pose=", pose.snappedf(0.01), " walk=", distances)
	_check(
		open_headings >= MINIMUM_OPEN_HEADINGS,
		"%s: after standing the pilot can walk %.2f m away in at least %d headings (%s)" % [
			label, WALK_AWAY_METRES, MINIMUM_OPEN_HEADINGS, distances
		]
	)


func _world_overlaps(player: PlayerController) -> Array[String]:
	var shape := CapsuleShape3D.new()
	shape.radius = CLEARANCE_RADIUS
	shape.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = PhysicsLayers.WORLD
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis(), player.global_position + Vector3.UP * 1.0)
	var names: Array[String] = []
	for hit in player.get_world_3d().direct_space_state.intersect_shape(query, 16):
		names.append(str((hit.collider as Node).name))
	return names


func _wait(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return bool(predicate.call())


func _release() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)


func _teardown(game: Node) -> void:
	_release()
	game.queue_free()
	await process_frame
	await physics_frame
	if _failures.is_empty():
		print("STATION_SEAT_STAND_CLEARANCE_TEST_OK")
		quit(0)
	else:
		print("STATION_SEAT_STAND_CLEARANCE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
