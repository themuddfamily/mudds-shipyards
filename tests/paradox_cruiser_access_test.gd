extends SceneTree

## One staged fixture pose, then actual Player controls and production physics.
## Runs unchanged as an external script against the exported Windows PCK.
const PARADOX := preload("res://scenes/ships/paradox_cruiser.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const ROOM := AABB(Vector3(-2.8,1.2,-5), Vector3(5.6,2.8,19))
var _ship: HeroShip
var _player: PlayerController
var _hatch: ShipCabinHatch
var _frame: MovingInteriorFrame
var _fixture := Transform3D.IDENTITY
var _checks := 0
var _failed := false
var _interactions := 0
var _geometry_samples := 0
var _last_local := Vector3.INF
var _previous_inside := false
var _commands: FixtureCommands


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
		_fixture = Transform3D(Basis(Vector3.UP,deg_to_rad(35)),Vector3(30,0.38,-20))
	_ship = PARADOX.instantiate() as HeroShip
	_ship.transform = _fixture
	root.add_child(_ship)
	await _frames(3)
	# Unsupported apron and airborne/active refusals are negative API fixtures;
	# no direct door call is used for the positive walking route below.
	_ship.set_canopy_open(true,0)
	if not _check(not _ship.is_canopy_open(), "missing supporting apron refuses opening"):
		return
	var deck := StaticBody3D.new()
	deck.name = "SupportedFixtureApron"
	deck.collision_layer = PhysicsLayers.WORLD
	deck.transform = _fixture
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20,1,42)
	collision.shape = floor_shape
	collision.position = Vector3(0,-0.5,2)
	deck.add_child(collision)
	root.add_child(deck)
	_player = PLAYER.instantiate() as PlayerController
	_player.transform = _fixture * Transform3D(Basis.IDENTITY,Vector3(0,0,20))
	root.add_child(_player)
	_hatch = _ship.get_node("ParadoxOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	_frame = _ship.get_node("MovingInteriorFrame") as MovingInteriorFrame
	_commands = FixtureCommands.new()
	_ship.add_child(_commands)
	_ship.set_command_source(_commands)
	_player.interact_requested.connect(_route_interaction)
	await _frames(12)
	if not _check(_player.is_on_floor() and _local().distance_to(Vector3(0,0,20)) < 0.02
		and _frame.get_interior_bounds().is_equal_approx(ROOM), "one staged actual Player and exact bounded supported cabin"):
		return
	if not _observe_geometry() or not _measure_trajectory():
		return
	# Closed refusal is real movement into the sealed physical access assembly.
	await _walk_axis(2,10,150,false)
	if _failed:
		return
	if not _check(_local().z > 14.2 and _local().z < 15 and not _frame.is_occupant_registered(_player),
		"closed actual ramp/hatch refuses capsule crossing"):
		return
	if not await _walk_axis(2,20,150):
		return
	for cycle in 2:
		# Reach the existing side control by walking outside the complete sweep.
		if not await _walk_axis(0,1.9,100) or not await _walk_axis(2,15,120):
			return
		if not _check(_hatch.is_available() and _local().x - 0.38 > 1.2
			and _player.get_interaction_origin().distance_to(_hatch.global_position) < ShipCabinHatch.MAX_REACH,
			"ordinary side control is reachable outside moving leaf"):
			return
		if not await _interact(true,true):
			return
		if not _check(_ship.get_landing_collision_report().local_bounds.is_equal_approx(AABB(Vector3(-8,0,-14),Vector3(16,6,32))),
			"deployed actual collision envelope ends exactly atz18"):
			return
		if not _aisle_clear():
			return
		# Walk back on apron, align the aisle, then traverse continuously to helm.
		if not await _walk_axis(2,20,120) or not await _walk_axis(0,0,100):
			return
		if not await _walk_axis(2,-2.4,360):
			return
		if not _check(absf(_local().y-1.2)<0.02 and _frame.is_occupant_registered(_player),
			"same supported Player reaches unchanged helm approach through ramp vestibule bridge"):
			return
		if not _camera_clear():
			return
		if not await _walk_axis(2,20,360):
			return
		if not _check(not _frame.is_occupant_registered(_player) and _ship.collision_mask == PhysicsLayers.SHIP_BODY_MASK,
			"physical exterior return retires bounded moving relationship"):
			return
		if not await _walk_axis(0,1.9,100) or not await _walk_axis(2,15,120):
			return
		if not await _interact(false,true):
			return
		if not _check(_ship.get_landing_collision_report().local_bounds.is_equal_approx(AABB(Vector3(-8,0,-14),Vector3(16,6,28))),
			"sealed physical geometry restores exact16x28x6 envelope"):
			return
	# Existing timed startup and ordinary idle: no actor/ship clock mutation.
	_ship.set_piloted(true)
	_commands.brake = true
	await _frames(1)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "sealed normal demand begins inherited timed startup"):
		return
	await _frames(180)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "approved3.2second clock remains STARTING at3seconds"):
		return
	await _frames(16)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "approved inherited startup becomes ONLINE"):
		return
	_ship.set_canopy_open(true,0)
	if not _check(not _ship.is_canopy_open(), "active engine refuses exterior opening"):
		return
	_commands.brake = false
	await _frames(95)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and _ship.global_position.distance_to(_fixture.origin)<0.001,
		"ordinary neutral shutdown preserves supported fixture pose"):
		return
	_commands.throttle = 1
	await _frames(255)
	if not _check(_ship.velocity.length()>1 and not bool(_ship.get_telemetry().get("landed",true)), "actual ordinary throttle produces airborne flight for unsafe-access negative"):
		return
	_ship.set_canopy_open(true,0)
	if not _check(not _ship.is_canopy_open(), "real airborne moving craft refuses opening"):
		return
	_commands.throttle = 0
	_commands.brake = true
	await _frames(90)
	_commands.brake = false
	await _frames(95)
	_ship.set_piloted(false)
	_release_inputs()
	_player.queue_free()
	_ship.queue_free()
	deck.queue_free()
	await _frames(3)
	print("PARADOX_CRUISER_ACCESS_TEST_OK: checks=",_checks," geometry_samples=",_geometry_samples," transformed=",OS.get_cmdline_user_args().has("--transformed"))
	quit(0)


func _route_interaction() -> void:
	# Standalone fixture substitutes only GameFlow dispatch; actual Player emits
	# the request and the existing hatch verifies its own live availability/reach.
	var discovered := false
	for area: Area3D in (_player.get_node("InteractionArea") as Area3D).get_overlapping_areas():
		if area == _hatch:
			discovered = true
	if _check(discovered, "real Player proximity discovers existing hatch") and _hatch.interact(_player):
		_interactions += 1


func _interact(open: bool, safety: bool) -> bool:
	var before := _interactions
	Input.action_press(&"interact")
	await _frames(1)
	Input.action_release(&"interact")
	if not _check(_interactions == before+1 and _ship.is_canopy_open() == open, "ordinary Player Interact operates discovered reachable physical hatch"):
		return false
	if safety:
		_ship.set_piloted(true)
		_commands.throttle = 1
		_ship.request_engine_start()
	for index in 30:
		await physics_frame
		await process_frame
		if not _observe_geometry() or not _observe_player():
			return false
		if safety and not _check(_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE
			and _ship.velocity.length()<0.001 and _ship.global_position.distance_to(_fixture.origin)<0.001,
			"open or moving access blocks inherited start and throttle"):
			return false
		# Stop demand before the final closed fraction can legitimately start.
		if not open and float(_ship.get("_access_fraction")) < 0.15:
			_commands.throttle = 0
			_ship.set_piloted(false)
	_commands.throttle = 0
	_ship.set_piloted(false)
	return _check(is_equal_approx(float(_ship.get("_access_fraction")),1.0 if open else 0.0),"inherited hatch motion reaches exact endpoint")


func _walk_axis(axis: int, target: float, limit: int, require_endpoint: bool = true) -> bool:
	var start := _local()
	var sign_direction := signf(target-start[axis])
	var action: StringName = (&"move_right" if sign_direction>0 else &"move_left") if axis == 0 else (&"move_back" if sign_direction>0 else &"move_forward")
	var frames := 0
	for index in limit:
		var distance := (target-_local()[axis])*sign_direction
		if distance <= 0.035:
			break
		Input.action_press(action,0.35 if distance<0.7 else 1.0)
		await physics_frame
		await process_frame
		frames += 1
		if not _observe_player() or not _observe_geometry():
			_release_inputs()
			return false
	Input.action_release(action)
	for index in 12:
		await physics_frame
		await process_frame
		if not _observe_player():
			return false
	print("PARADOX_ACCESS_WALK: axis=",axis," target=",target," start=",start," end=",_local()," frames=",frames)
	return not require_endpoint or _check(absf(_local()[axis]-target)<0.06,"ordinary movement reaches unchanged exact route endpoint")


func _local() -> Vector3:
	return _fixture.affine_inverse() * _player.global_position


func _observe_player() -> bool:
	var point := _local()
	if not _check(_player.is_on_floor(),"every walking/motion sample retains actual floor support at"+str(point)):
		return false
	if _last_local.is_finite() and not _check(point.distance_to(_last_local)<0.2,"continuous ordinary movement has no pose warp"):
		return false
	_last_local = point
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.collision_mask = PhysicsLayers.SHIP
	query.margin = 0
	var hits := _ship.get_world_3d().direct_space_state.intersect_shape(query)
	if not _check(hits.is_empty(),"actual capsule and head clear physical hull at"+str(point)+" hits="+str(hits)):
		return false
	var inside := _frame.contains_world_position(_player.global_position)
	if inside == _previous_inside and not _check(_frame.is_occupant_registered(_player) == inside,
		"exact supported boundary admits/retires Player within one coordinator tick at"+str(point)):
		return false
	_previous_inside = inside
	return true


func _observe_geometry() -> bool:
	_geometry_samples += 1
	var fraction := float(_ship.get("_access_fraction"))
	var ramp := _ship.get_node("SternRampCollision") as CollisionShape3D
	if not _check(ramp.transform.is_equal_approx(_ramp_pose(fraction)),"actual inherited motion agrees with measured complete rigid trajectory"):
		return false
	for collision: Node in _ship.get_children():
		if not collision is CollisionShape3D:
			continue
		var shape := collision as CollisionShape3D
		var mesh := _ship.get_node("ParadoxOriginalShell/"+String(shape.name).trim_suffix("Collision")) as MeshInstance3D
		if not _check(not shape.disabled and mesh.global_transform.is_equal_approx(shape.global_transform),"visible/actual collider poses match "+str(shape.name)):
			return false
		var faces := mesh.mesh.get_faces()
		for point: Vector3 in (shape.shape as ConvexPolygonShape3D).points:
			var local := shape.transform * point
			var matched := false
			for face_point: Vector3 in faces:
				if point.is_equal_approx(face_point):
					matched = true
					break
			if not _check(matched and local.is_finite() and local.x>=-8.0001 and local.x<=8.0001
				and local.y>=-0.0001 and local.y<=6.0001 and local.z>=-14.0001
				and local.z <= (14.0001 if is_zero_approx(fraction) else 18.0001),
				"every actual motion vertex obeys frozen bounds "+str(shape.name)+" fraction="+str(fraction)+" vertex="+str(local)):
				return false
	return true


func _ramp_pose(fraction: float) -> Transform3D:
	return _ship.call("get_access_ramp_transform",fraction)


## Measure all actual authored vertices without changing the live ship, actor,
## or inherited clock. Runtime samples above tie the actual motion to this path.
func _measure_trajectory() -> bool:
	var fractions: Array[float] = []
	for index in 10001:
		fractions.append(float(index)/10000)
	fractions.append(1.0-atan(0.3)/(PI*0.5+atan(0.3)))
	var bounds := AABB(Vector3(0,1.2,14),Vector3.ZERO)
	for fraction: float in fractions:
		var pose := _ramp_pose(fraction)
		for point: Vector3 in ((_ship.get_node("SternRampCollision") as CollisionShape3D).shape as ConvexPolygonShape3D).points:
			var actual := pose*point
			bounds = bounds.expand(actual)
			if not _check(actual.is_finite() and absf(actual.x)<=1.2001 and actual.y>=-0.0001
				and actual.y<=6.0001 and actual.z>=-14.0001 and actual.z<=(14.0001 if is_zero_approx(fraction) else 18.0001),
				"full authored ramp trajectory frozen bound fraction="+str(fraction)+" point="+str(actual)):
				return false
	print("PARADOX_RAMP_TRAJECTORY: samples=",fractions.size()," actual_vertex_bounds=",bounds," critical_fraction=",fractions[-1])
	return true


func _aisle_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4,2.4,18.98)
	query.shape = box
	query.transform = _fixture * Transform3D(Basis.IDENTITY,Vector3(0,2.401,4.5))
	query.collision_mask = PhysicsLayers.SHIP
	query.margin = 0
	return _check(_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"real1.4m aisle and2.4m hatch headroom remain physically clear")


func _camera_clear() -> bool:
	var camera := _ship.get_node("ParadoxOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	query.shape = sphere
	query.transform = camera.global_transform
	query.collision_mask = PhysicsLayers.SHIP
	return _check(camera.global_transform.is_finite() and _ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"unchanged actual cockpit camera has finite clear eye")


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame


func _release_inputs() -> void:
	for action in [&"move_left",&"move_right",&"move_forward",&"move_back",&"interact",&"sprint_boost",&"jump"]:
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition:
		return true
	if not _failed:
		_failed = true
		_release_inputs()
		push_error("PARADOX_ACCESS_FAIL: "+label)
		quit(1)
	return false
