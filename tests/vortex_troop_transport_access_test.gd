extends SceneTree

## One physical actor and one initial setup per process. All subsequent route
## motion and access edges use production Player input and the discovered hatch.
## All preloads are production resources so this fixture also runs from a PCK.
const VORTEX := preload("res://scenes/ships/vortex_troop_transport.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
var _ship: HeroShip
var _player: PlayerController
var _hatch: ShipCabinHatch
var _commands: FixtureCommands
var _frame: MovingInteriorFrame
var _initial_pose := Transform3D.IDENTITY
var _actor_id := 0
var _mask := 0
var _layer := 0
var _gravity := 0.0
var _checks := 0
var _samples := 0
var _interactions := 0
var _registered := 0
var _retired := 0
var _failed := false
var _monitor_walk_samples := false
var _exterior_control_walk := false
var _control_walk_z := 0.0
var _diagnostic_motion_history: Array[Dictionary] = []
var _diagnostic_last_frame := -1


class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--transformed"):
		_initial_pose = Transform3D(Basis(Vector3.UP, deg_to_rad(35)), Vector3(30, 0.38, -20))
	var apron := StaticBody3D.new()
	apron.name = "SupportedFixtureApron"
	apron.collision_layer = PhysicsLayers.WORLD
	apron.transform = _initial_pose
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 1, 28)
	collision.position = Vector3(0, -0.5, 1)
	collision.shape = box
	apron.add_child(collision)
	root.add_child(apron)
	_ship = VORTEX.instantiate() as HeroShip
	_ship.transform = _initial_pose
	root.add_child(_ship)
	_commands = FixtureCommands.new()
	_ship.add_child(_commands)
	_ship.set_command_source(_commands)
	_player = PLAYER.instantiate() as PlayerController
	_player.transform = _initial_pose * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 12.05))
	root.add_child(_player)
	_player.set_camera_active(false)
	_frame = _ship.call("get_interior_frame") as MovingInteriorFrame
	_frame.occupant_registered.connect(func(body: Node3D):
		if body == _player: _registered += 1)
	_frame.occupant_unregistered.connect(func(body: Node3D, _velocity: Vector3, _reason: StringName):
		if body == _player: _retired += 1)
	_hatch = _ship.get_node("VortexOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	_player.interact_requested.connect(_dispatch_interact)
	_actor_id = _player.get_instance_id()
	_mask = _player.collision_mask
	_layer = _player.collision_layer
	_gravity = float(_player.get("gravity_multiplier"))
	await _frames(20)
	_monitor_walk_samples = true
	if not _sample("initial apron") or not _geometry(false): return
	if not _check(_ship.call("has_supported_exterior_access") and not _ship.is_canopy_open()
		and _frame.get_occupant_count() == 0, "supported sealed initial fixture"): return
	# The actual closed door has collision across the opening, and the closed
	# access assembly refuses this same ordinary walking capsule.
	var door_ray := PhysicsRayQueryParameters3D.create(_ship.to_global(Vector3(0, 2, 8.2)),
		_ship.to_global(Vector3(0, 2, 7.6)), PhysicsLayers.SHIP)
	var door_hit := _ship.get_world_3d().direct_space_state.intersect_ray(door_ray)
	if not _check(not door_hit.is_empty(), "physical closed stern door seals opening"): return
	Input.action_press("move_forward")
	for _index in 90:
		await _tick()
		if not _sample("closed refusal"): return
	Input.action_release("move_forward")
	await _frames(12)
	if not _check(_local().z > 8 and not _frame.is_occupant_registered(_player), "closed assembly refuses physical crossing"): return
	if not await _walk(12.05, "closed return to control apron"): return
	for cycle in 2:
		if not await _walk_control_side(1.75): return
		if not await _interact(true): return
		if not _geometry(true): return
		if not await _walk_control_side(0): return
		# Unsafe demand must be neutralized at its actual command seam while open.
		var start := _ship.global_transform
		_ship.set_piloted(true)
		_commands.throttle = 1
		_ship.request_engine_start()
		await _frames(30)
		if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE
			and _ship.global_transform.is_equal_approx(start) and _ship.velocity.length() < 0.001,
			"open access prevents manual/automatic start and hull movement"): return
		_commands.throttle = 0
		_ship.set_piloted(false)
		if not await _walk(6.5, "inbound ramp and vestibule"): return
		if not _check(_frame.is_occupant_registered(_player) and _frame.get_occupant_count() == 1,
			"same physical body automatically admitted inside bounded cabin"): return
		if not await _walk(-5, "continuous centre aisle to helm approach"): return
		if not _check(_local().distance_to(Vector3(0, 1, -5)) < 0.35
			and _frame.is_occupant_registered(_player), "supported helm approach without seat claim"): return
		if not await _walk(12.05, "same-body aisle ramp exterior return"): return
		if not _check(not _frame.is_occupant_registered(_player) and _frame.get_occupant_count() == 0,
			"physical exterior return retires automatic membership"): return
		if not await _walk_control_side(1.75): return
		if not await _interact(false): return
		if not _geometry(false): return
		if not await _walk_control_side(0): return
	if not _check(_registered == 2 and _retired == 2 and _interactions == 4,
		"two physical admissions/retirements and four actual Player Interact edges"): return
	_monitor_walk_samples = false
	await _negative_safety()
	if _failed: return
	_release_inputs()
	_player.queue_free()
	_ship.queue_free()
	apron.queue_free()
	await _frames(3)
	print("VORTEX_TROOP_TRANSPORT_ACCESS_TEST_OK: checks=", _checks, " samples=", _samples,
		" transformed=", OS.get_cmdline_user_args().has("--transformed"))
	quit(0)


func _dispatch_interact() -> void:
	if not _check(_player.get_nearby_interactables().has(_hatch), "actual Player discovers physical hatch"): return
	if not _check(_hatch.is_available() and _player.get_interaction_origin().distance_to(_hatch.global_position) <= ShipCabinHatch.MAX_REACH,
		"existing hatch available within unchanged production reach"): return
	if _check(_hatch.interact(_player), "actual Player Interact dispatched to discovered hatch"):
		_interactions += 1


func _interact(open: bool) -> bool:
	var capsule := (_player.get_node("PlayerCollision") as CollisionShape3D).shape as CapsuleShape3D
	if not _check(_exterior_control_walk and _local().x - capsule.radius > 1.2,
		"ordinary side-control operator capsule clears full moving ramp width"): return false
	Input.action_press("interact")
	await _tick()
	Input.action_release("interact")
	var original := _ship.global_transform
	# Apply real pilot demand during the first five motion ticks, before the
	# sealed endpoint legitimately becomes startable again.
	_ship.set_piloted(true)
	_commands.throttle = 1
	for index in 26:
		if index == 5:
			_commands.throttle = 0
			_ship.set_piloted(false)
		await _tick()
		if not _sample("access motion") or not _geometry_motion(): return false
		if index < 5:
			_ship.request_engine_start()
			if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE
				and _ship.global_transform.is_equal_approx(original) and _ship.velocity.length() < 0.001,
				"actual start/throttle during access motion retains OFFLINE and fixed hull"): return false
	return _check(_ship.is_canopy_open() == open and is_equal_approx(float(_ship.get("_access_fraction")), 1.0 if open else 0.0),
		"actual physical Interact reaches requested access endpoint")


func _walk(target_z: float, label: String) -> bool:
	var direction := 1 if target_z > _local().z else -1
	var action := "move_back" if direction > 0 else "move_forward"
	Input.action_press(action)
	var reached := false
	for _index in 420:
		await _tick()
		if not _sample(label): return false
		if (_local().z - target_z) * direction >= -0.22:
			reached = true
			break
	Input.action_release(action)
	for _index in 12:
		await _tick()
		if not _sample(label + " stop"): return false
	print("VORTEX_ACCESS_WALK: ", label, " local=", _local(), " registered=", _frame.is_occupant_registered(_player))
	return _check(reached and absf(_local().z - target_z) < 0.35, label + " reaches ordinary walking endpoint")


func _walk_control_side(target_x: float) -> bool:
	if not _exterior_control_walk:
		if not _check(absf(_local().z - 12.05) < 0.35 and not _frame.is_occupant_registered(_player),
			"lateral control walk begins at original supported exterior return endpoint"): return false
		_control_walk_z = _local().z
		_exterior_control_walk = true
	var reached := false
	for _index in 420:
		var error := target_x - _local().x
		if absf(error) < 0.025:
			reached = true
			break
		var action := "move_right" if error > 0 else "move_left"
		Input.action_release("move_left" if error > 0 else "move_right")
		var strength := 1.0 if absf(error) > 0.5 else lerpf(InputMap.action_get_deadzone(action), 1.0, 0.2)
		Input.action_press(action, strength)
		await _tick()
		if not _sample("supported exterior lateral control walk"): return false
	Input.action_release("move_left")
	Input.action_release("move_right")
	for _index in 12:
		await _tick()
		if not _sample("supported exterior lateral stop"): return false
	if not _check(reached and absf(_local().x - target_x) < 0.1,
		"normal lateral input reaches supported hatch side or exact aisle centre"): return false
	if is_zero_approx(target_x):
		_exterior_control_walk = false
	return true


func _sample(label: String) -> bool:
	_samples += 1
	var completed: Dictionary = _player.get_step_up_assist_audit().get("completed_motion", {})
	if int(completed.get("frame", -1)) != _diagnostic_last_frame:
		_diagnostic_last_frame = int(completed.get("frame", -1))
		_diagnostic_motion_history.append({"completed_motion": completed, "local": _local(),
			"velocity": _player.velocity, "real_velocity": _player.get_real_velocity(),
			"last_motion": _player.get_last_motion(), "position_delta": _player.get_position_delta(),
			"on_floor": _player.is_on_floor(), "floor_normal": _player.get_floor_normal(),
			"slide_count": _player.get_slide_collision_count(),
			"registered": _frame.is_occupant_registered(_player)})
		if _diagnostic_motion_history.size() > 6:
			_diagnostic_motion_history.pop_front()
	if not _check(_player.get_instance_id() == _actor_id and _player.collision_mask == _mask
		and _player.collision_layer == _layer and is_equal_approx(float(_player.get("gravity_multiplier")), _gravity)
		and not Input.is_action_pressed("jump") and not _player.is_seated(), label + ": actor/masks/gravity/standing unchanged"): return false
	if not _check(_player.is_on_floor(), label + ": actual walking floor contact at " + str(_local())): return false
	var space := _player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.1,
		_player.global_position - Vector3.UP * 0.4, PhysicsLayers.WORLD | PhysicsLayers.SHIP, [_player.get_rid()])
	var hit := space.intersect_ray(ray)
	if not _check(not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > 0.9,
		label + ": real supporting floor ray"): return false
	var capsule := _player.get_node("PlayerCollision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.transform = capsule.global_transform
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.margin = 0
	query.exclude = [_player.get_rid()]
	var capsule_hits := space.intersect_shape(query)
	if not capsule_hits.is_empty():
		_capture_capsule_failure(label, query, capsule_hits)
	if not _check(capsule_hits.is_empty(), label + ": actual capsule clear at " + str(_local())): return false
	var head := SphereShape3D.new()
	head.radius = 0.16
	query.shape = head
	query.transform = Transform3D(Basis.IDENTITY, _player.global_position + Vector3.UP * 1.76)
	if not _check(space.intersect_shape(query).is_empty(), label + ": head/camera clearance"): return false
	if _exterior_control_walk:
		return _check(absf(_local().z - _control_walk_z) < 0.1 and not _frame.is_occupant_registered(_player),
			label + ": lateral interaction stays on supported exterior apron")
	return _check(absf(_local().x) < 0.1, label + ": centre aisle stays capsule safe")


func _capture_capsule_failure(label: String, query: PhysicsShapeQueryParameters3D, hits: Array[Dictionary]) -> void:
	var shape := query.shape as CapsuleShape3D
	var hit_records: Array[Dictionary] = []
	for hit in hits:
		var record := {"collider_id": hit.get("collider_id"), "rid": hit.get("rid"), "shape": hit.get("shape")}
		var collider := hit.get("collider") as CollisionObject3D
		if is_instance_valid(collider):
			record["collider_path"] = collider.get_path()
			record["collider_scene_transform"] = collider.global_transform
			record["collider_server_transform"] = PhysicsServer3D.body_get_state(collider.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
			var shape_index := int(hit.get("shape", -1))
			record["server_shape_transform"] = PhysicsServer3D.body_get_shape_transform(collider.get_rid(), shape_index)
			record["server_shape_data"] = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(collider.get_rid(), shape_index))
			var owner_id := collider.shape_find_owner(int(hit.get("shape", -1)))
			var owner := collider.shape_owner_get_owner(owner_id) as Node
			record["shape_owner_transform"] = collider.shape_owner_get_transform(owner_id)
			if is_instance_valid(owner):
				record["shape_owner_path"] = owner.get_path()
				if owner is CollisionShape3D:
					var collision_shape := owner as CollisionShape3D
					record["shape_scene_transform"] = collision_shape.global_transform
					if collision_shape.shape is ConvexPolygonShape3D:
						record["shape_vertices"] = (collision_shape.shape as ConvexPolygonShape3D).points
		hit_records.append(record)
	var slides: Array[Dictionary] = []
	for index in _player.get_slide_collision_count():
		var slide := _player.get_slide_collision(index)
		slides.append({"normal": slide.get_normal(), "position": slide.get_position(),
			"travel": slide.get_travel(), "remainder": slide.get_remainder(), "depth": slide.get_depth()})
	var collision := KinematicCollision3D.new()
	var overlapping := _player.test_move(_player.global_transform, Vector3.ZERO,
		collision, _player.safe_margin, true, 4)
	var contacts: Array[Dictionary] = []
	for index in collision.get_collision_count():
		var collider := collision.get_collider(index) as Node
		contacts.append({"collider_path": collider.get_path() if is_instance_valid(collider) else NodePath(),
			"shape": collision.get_collider_shape(index), "normal": collision.get_normal(index),
			"point": collision.get_position(index), "depth": collision.get_depth()})
	print("VORTEX_CAPSULE_DIAGNOSTIC: ", {"label": label, "local": _local(),
		"hits": hit_records, "rest_info": _player.get_world_3d().direct_space_state.get_rest_info(query),
		"capsule_radius": shape.radius, "capsule_height": shape.height, "capsule_transform": query.transform,
		"query_margin": query.margin, "query_mask": query.collision_mask, "query_exclude": query.exclude,
		"contact_pairs": _player.get_world_3d().direct_space_state.collide_shape(query, 8),
		"motion_history": _diagnostic_motion_history, "slide_contacts": slides,
		"floor_snap_length": _player.floor_snap_length, "floor_max_angle": _player.floor_max_angle,
		"interior_collision_transform": _player.call("_get_interior_collision_transform"),
		"player_transform": _player.global_transform, "player_velocity": _player.velocity,
		"on_floor": _player.is_on_floor(), "floor_normal": _player.get_floor_normal(), "safe_margin": _player.safe_margin,
		"ship_transform": _ship.global_transform, "ship_velocity": _ship.velocity,
		"access_fraction": _ship.get("_access_fraction"), "canopy_open": _ship.is_canopy_open(),
		"engine_state": _ship.get("_engine_state"), "interactions": _interactions,
		"input_forward": Input.is_action_pressed("move_forward"), "input_back": Input.is_action_pressed("move_back"),
		"input_interact": Input.is_action_pressed("interact"), "input_jump": Input.is_action_pressed("jump"),
		"test_move_overlapping": overlapping, "test_move_travel": collision.get_travel(), "contacts": contacts})


func _geometry_motion() -> bool:
	for collision: CollisionShape3D in _ship.find_children("*Collision", "CollisionShape3D", false, false):
		var name := String(collision.name).trim_suffix("Collision")
		var meshes := _ship.get_node("VortexOriginalShell").find_children(name, "MeshInstance3D", true, false)
		if not _check(meshes.size() == 1, "one visible mesh per actual physical section " + name): return false
		var mesh := meshes[0] as MeshInstance3D
		if not _check(collision.global_transform.is_equal_approx(mesh.global_transform), "matching physical/visible pose " + name): return false
		for point: Vector3 in (collision.shape as ConvexPolygonShape3D).points:
			var actual := collision.transform * point
			if not _check(actual.x >= -5.0001 and actual.x <= 5.0001 and actual.y >= -0.0001
				and actual.y <= 5.0001 and actual.z >= -10.0001 and actual.z <= 12.0001,
				"all access motion remains within approved deployment envelope " + name + str(actual)): return false
	return true


func _geometry(open: bool) -> bool:
	if not _geometry_motion(): return false
	var ramp := _ship.get_node("SternRampFirstCollision") as CollisionShape3D
	var toe := _ship.get_node("SternRampToeCollision") as CollisionShape3D
	if open:
		if not _check((ramp.transform * Vector3(-1.2, 0, 0)).is_equal_approx(Vector3(-1.2, 1, 8))
			and (toe.transform * Vector3(1.2, -0.5, 2)).is_equal_approx(Vector3(1.2, 0, 12)),
			"actual ramp is2.4m wide with4m run descending y1 to0 atz8..12"): return false
		var aperture := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.398, 2.598, 0.198)
		aperture.shape = box
		aperture.transform = _ship.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 2.3, 7.9))
		aperture.collision_mask = PhysicsLayers.SHIP
		aperture.margin = 0
		if not _check(_ship.get_world_3d().direct_space_state.intersect_shape(aperture).is_empty(), "actual full2.4x2.6m hatch aperture clears"): return false
	else:
		for collision: CollisionShape3D in _ship.find_children("*Collision", "CollisionShape3D", false, false):
			for point: Vector3 in (collision.shape as ConvexPolygonShape3D).points:
				if not _check((collision.transform * point).z <= 10.0001, "stowed sections stay inside20m hull length"): return false
	return _check(_frame.get_interior_bounds() == AABB(Vector3(-2.2, 1, -7.5), Vector3(4.4, 2.6, 15)),
		"one bounded supported cabin, no external hull AABB inflation")


func _negative_safety() -> void:
	# Independent negative fixtures may call the public API; they never replace
	# any positive route, manipulate the ordinary actor or fake controller state.
	var unsupported := VORTEX.instantiate() as HeroShip
	unsupported.position = Vector3(200, 30, 0)
	root.add_child(unsupported)
	await _frames(3)
	unsupported.set_canopy_open(true)
	await _frames(25)
	if not _check(not unsupported.is_canopy_open() and is_zero_approx(float(unsupported.get("_access_fraction"))),
		"missing supporting apron refuses opening"): return
	unsupported.queue_free()
	_ship.set_piloted(true)
	_commands.brake = true
	_ship.request_engine_start()
	await _frames(210)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "sealed actual3.6s clock still STARTING at3.5s"): return
	_ship.set_canopy_open(true)
	if not _check(not _ship.is_canopy_open(), "actual STARTING refuses opening"): return
	await _frames(10)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "sealed inherited clock reaches ONLINE"): return
	_ship.set_canopy_open(true)
	if not _check(not _ship.is_canopy_open(), "actual ONLINE refuses opening"): return
	_commands.brake = false
	_commands.throttle = 1
	await _frames(90)
	_ship.set_canopy_open(true)
	if not _check(_ship.velocity.length() > 15 and not _ship.is_canopy_open(), "actual moving flight refuses opening"): return
	_commands.throttle = 0
	_commands.brake = true
	await _frames(90)
	_commands.brake = false
	await _frames(100)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and _ship.velocity.length() < 0.001,
		"normal neutral idle shuts sealed controller down"): return
	_ship.set_canopy_open(true)
	if not _check(not _ship.is_canopy_open(), "actual airborne OFFLINE hull refuses opening"): return
	_ship.set_piloted(false)


func _local() -> Vector3:
	return _ship.to_local(_player.global_position)


func _tick() -> void:
	await physics_frame
	await process_frame
	if _monitor_walk_samples and not _failed:
		_sample("ordinary route physics tick")


func _frames(count: int) -> void:
	for _index in count:
		await _tick()


func _release_inputs() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "interact", "jump"]:
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition: return true
	if not _failed:
		_failed = true
		_release_inputs()
		push_error("VORTEX_ACCESS_FAIL: " + label)
		quit(1)
	return false
