extends SceneTree

## One staged fixture pose, then actual Player controls and production physics.
## Runs unchanged as an external script against the exported Windows PCK.
const PREDATOR := preload("res://scenes/ships/predator_detention_transport.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const ROOM := AABB(Vector3(-3,1,-6.5), Vector3(6,3.6,13))
var _ship: HeroShip
var _player: PlayerController
var _hatch: ShipCabinHatch
var _fixture := Transform3D.IDENTITY
var _checks := 0
var _failed := false
var _interactions := 0
var _geometry_samples := 0
var _last_local := Vector3.INF
var _last_observed_physics_frame := -1
var _current_route_axis := -1
var _current_route_target := INF
var _commands: FixtureCommands
var _tick_observer: CompletedPlayerTick
var _observe_positive_ticks := false
var _body_layer := 0
var _body_mask := 0
var _body_gravity := 0.0
var _capsule_radius := 0.0
var _capsule_height := 0.0
var _capsule_pose := Transform3D.IDENTITY


class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake}


## The observer runs after ordinary Player physics.
## A slow rendered
## frame can contain several physics ticks; each is observed independently.
class CompletedPlayerTick:
	extends Node
	signal completed_tick
	var observe: Callable

	func _physics_process(_delta: float) -> void:
		if observe.is_valid():
			observe.call()
		completed_tick.emit()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--transformed"):
		_fixture = Transform3D(Basis(Vector3.UP,deg_to_rad(35)),Vector3(30,0.38,-20))
	_ship = PREDATOR.instantiate() as HeroShip
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
	_player.transform = _fixture * Transform3D(Basis.IDENTITY,Vector3(1,0,13))
	root.add_child(_player)
	_hatch = _ship.get_node("PredatorOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	_commands = FixtureCommands.new()
	_ship.add_child(_commands)
	_ship.set_command_source(_commands)
	_player.interact_requested.connect(_route_interaction)
	_tick_observer = CompletedPlayerTick.new()
	_tick_observer.name = "CompletedPlayerPhysicsObserver"
	_tick_observer.process_physics_priority = _player.process_physics_priority + 1
	_tick_observer.observe = _observe_completed_player_tick
	root.add_child(_tick_observer)
	_body_layer = _player.collision_layer
	_body_mask = _player.collision_mask
	_body_gravity = _player.gravity_multiplier
	var original_collision := _player.get_node("PlayerCollision") as CollisionShape3D
	_capsule_radius = (original_collision.shape as CapsuleShape3D).radius
	_capsule_height = (original_collision.shape as CapsuleShape3D).height
	_capsule_pose = original_collision.transform
	await _frames(12)
	if not _check(_player.is_on_floor() and _local().distance_to(Vector3(1,0,13)) < 0.02
		and not _ship.has_node("MovingInteriorFrame"), "one staged actual Player and exact bounded supported cabin"):
		return
	if not _observe_geometry() or not _measure_trajectory():
		return
	# Closed refusal is real movement into the sealed physical access assembly.
	_observe_positive_ticks = true
	await _walk_axis(2,6,120,false)
	if _failed:
		return
	if not _check(_local().z > 7.4 and _local().z < 8,
		"closed actual ramp/hatch refuses capsule crossing"):
		return
	if not await _walk_axis(2,13,120):
		return
	for cycle in 2:
		# Reach the existing side control by walking outside the complete sweep.
		if not await _walk_axis(0,3.2,100) or not await _walk_axis(2,8.8,120):
			return
		if not _check(_hatch.is_available() and _local().x - _capsule_radius > 2.2
			and _player.get_interaction_origin().distance_to(_hatch.global_position) < ShipCabinHatch.MAX_REACH,
			"ordinary side control is reachable outside moving leaf"):
			return
		if not await _interact(true,true):
			return
		if not _check(_ship.get_landing_collision_report().local_bounds.is_equal_approx(AABB(Vector3(-4.5,0,-8),Vector3(9,5,19))),
			"deployed actual collision envelope ends exactly atz11"):
			return
		if not _aisle_clear():
			return
		# Walk back on apron, align the aisle, then traverse continuously to helm.
		if not await _walk_axis(2,13,120) or not await _walk_axis(0,1,100):
			return
		if not await _walk_axis(2,-5.5,400):
			return
		if not _check(absf(_local().y-1)<0.02 and absf(_local().x-1)<0.02 and absf(_local().z+5.5)<0.02,
			"same supported Player reaches unchanged helm approach through ramp vestibule bridge"):
			return
		if not _camera_clear():
			return
		if not await _walk_axis(2,13,400):
			return
		if not _check(_ship.collision_mask == PhysicsLayers.SHIP_BODY_MASK and absf(_local().y)<0.02,
			"physical exterior return retains normal collision ownership"):
			return
		if not await _walk_axis(0,3.2,100) or not await _walk_axis(2,8.8,120):
			return
		if not await _interact(false,true):
			return
		if not _check(_ship.get_landing_collision_report().local_bounds.is_equal_approx(AABB(Vector3(-4.5,0,-8),Vector3(9,5,16))),
			"sealed physical geometry restores exact9x16x5 envelope"):
			return
		if not await _walk_axis(2,13,120) or not await _walk_axis(0,1,100):
			return
		if not _check(_local().distance_to(Vector3(1,0,13))<0.02,"same Player returns to exact original apron after each sealed cycle"):
			return
	_observe_positive_ticks = false
	# Existing timed startup and ordinary idle: no actor/ship clock mutation.
	_ship.set_piloted(true)
	_commands.brake = true
	await _frames(1)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "sealed normal demand begins inherited timed startup"):
		return
	await _frames(222)
	if not _check(_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "approved3.8second clock remains STARTING at3.7seconds"):
		return
	await _frames(10)
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
	_tick_observer.queue_free()
	_player.queue_free()
	_ship.queue_free()
	deck.queue_free()
	await _frames(3)
	print("PREDATOR_DETENTION_TRANSPORT_ACCESS_TEST_OK: checks=",_checks," geometry_samples=",_geometry_samples," transformed=",OS.get_cmdline_user_args().has("--transformed"))
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
	# Deliver the ordinary edge from the process phase for Player's next tick.
	# The completed-tick observer remains active throughout this wait.
	await process_frame
	_log_interact_input_phase("before_press",open,before)
	Input.action_press(&"interact")
	_log_interact_input_phase("after_press",open,before)
	await _tick_observer.completed_tick
	_log_interact_input_phase("first_completed_tick",open,before)
	Input.action_release(&"interact")
	if _failed:
		return false
	if not _check(_interactions == before+1 and _ship.is_canopy_open() == open, "ordinary Player Interact operates discovered reachable physical hatch"):
		return false
	if safety:
		_ship.set_piloted(true)
		_commands.throttle = 1
		_ship.request_engine_start()
	for index in 30:
		await _tick_observer.completed_tick
		if _failed:
			return false
		if safety and not _check(_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE
			and _ship.velocity.length()<0.001 and _ship.global_position.distance_to(_fixture.origin)<0.001,
			"open or moving access blocks inherited start and throttle"):
			return false
		# Stop demand before the final closed fraction can legitimately start.
		if not open and float(_ship.get("_access_fraction")) < 0.2:
			_commands.throttle = 0
			_ship.set_piloted(false)
	_commands.throttle = 0
	_ship.set_piloted(false)
	return _check(is_equal_approx(float(_ship.get("_access_fraction")),1.0 if open else 0.0),"inherited hatch motion reaches exact endpoint")


func _log_interact_input_phase(phase: String, target_open: bool, before: int) -> void:
	var discovered := false
	for area: Area3D in (_player.get_node("InteractionArea") as Area3D).get_overlapping_areas():
		if area == _hatch:
			discovered = true
	print("PREDATOR_ACCESS_INTERACT_INPUT_OPERANDS: ", {
		"phase": phase, "physics_frame": Engine.get_physics_frames(),
		"in_physics_frame": Engine.is_in_physics_frame(),
		"just_pressed": Input.is_action_just_pressed(&"interact"),
		"pressed": Input.is_action_pressed(&"interact"),
		"interactions_before": before, "interactions_current": _interactions,
		"canopy_open": _ship.is_canopy_open(), "target_open": target_open,
		"player_control_enabled": _player.is_control_enabled(),
		"interact_handoff_blocked": _player.get("_interact_handoff_blocked"),
		"hatch_available": _hatch.is_available(), "hatch_discovered": discovered,
		"reach_distance": _player.get_interaction_origin().distance_to(_hatch.global_position),
		"maximum_reach": ShipCabinHatch.MAX_REACH})


func _walk_axis(axis: int, target: float, limit: int, require_endpoint: bool = true) -> bool:
	_current_route_axis = axis
	_current_route_target = target
	var start := _local()
	var sign_direction := signf(target-start[axis])
	var action: StringName = (&"move_right" if sign_direction>0 else &"move_left") if axis == 0 else (&"move_back" if sign_direction>0 else &"move_forward")
	var frames := 0
	for index in limit:
		var distance := (target-_local()[axis])*sign_direction
		if distance <= 0.01:
			break
		Input.action_press(action,0.23 if distance<0.12 else (0.35 if distance<0.7 else 1.0))
		await _tick_observer.completed_tick
		frames += 1
		if _failed:
			_release_inputs()
			return false
	Input.action_release(action)
	for index in 12:
		await _tick_observer.completed_tick
		if _failed:
			return false
	print("PREDATOR_ACCESS_WALK: axis=",axis," target=",target," start=",start," end=",_local()," frames=",frames)
	return not require_endpoint or _check(absf(_local()[axis]-target)<0.02,"ordinary movement reaches unchanged exact route endpoint")


func _local() -> Vector3:
	return _fixture.affine_inverse() * _player.global_position


func _observe_completed_player_tick() -> void:
	if not _observe_positive_ticks or _failed:
		return
	var current_frame := Engine.get_physics_frames()
	var completed: Dictionary = _player.get_step_up_assist_audit().get("completed_motion",{})
	if not _check(_tick_observer.process_physics_priority > _player.process_physics_priority
		and int(completed.get("frame",-1)) == current_frame,
		"observer runs after the actual Player completes this physical tick"):
		return
	if not _check(_last_observed_physics_frame < 0 or current_frame == _last_observed_physics_frame + 1,
		"every observed completed physical tick is adjacent previous="+str(_last_observed_physics_frame)+" current="+str(current_frame)):
		return
	if not _observe_player():
		return
	_observe_geometry()


func _observe_player() -> bool:
	var point := _local()
	if not _check(_player.is_on_floor(),"every walking/motion sample retains actual floor support at"+str(point)):
		return false
	if _last_local.is_finite() and not point.distance_to(_last_local)<0.2:
		print("PREDATOR_ACCESS_CONTINUITY_OPERANDS: ", {
			"previous_local_position": _last_local, "current_local_position": point,
			"distance": point.distance_to(_last_local),
			"previous_physics_frame": _last_observed_physics_frame,
			"current_physics_frame": Engine.get_physics_frames(),
			"velocity": _player.velocity,
			"route_axis": _current_route_axis, "route_target": _current_route_target})
	if _last_local.is_finite() and not _check(point.distance_to(_last_local)<0.2,"continuous ordinary movement has no pose warp"):
		return false
	_last_local = point
	_last_observed_physics_frame = Engine.get_physics_frames()
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	if not _check(_player.collision_layer == _body_layer and _player.collision_mask == _body_mask
		and is_equal_approx(_player.gravity_multiplier,_body_gravity)
		and is_equal_approx((collision.shape as CapsuleShape3D).radius,_capsule_radius)
		and is_equal_approx((collision.shape as CapsuleShape3D).height,_capsule_height)
		and collision.transform.is_equal_approx(_capsule_pose),"ordinary layer/mask/gravity/capsule remain unchanged"):
		return false
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

	return true


func _observe_geometry() -> bool:
	_geometry_samples += 1
	var fraction := float(_ship.get("_access_fraction"))
	var poses: Dictionary = _ship.call("get_access_transforms",fraction)
	for label: StringName in poses:
		if not _check((_ship.get_node(String(label)+"Collision") as CollisionShape3D).transform.is_equal_approx(poses[label]),"actual inherited motion agrees with pure complete trajectory"):
			return false
	for collision: Node in _ship.get_children():
		if not collision is CollisionShape3D:
			continue
		var shape := collision as CollisionShape3D
		var mesh := _ship.get_node("PredatorOriginalShell/"+String(shape.name).trim_suffix("Collision")) as MeshInstance3D
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
			if not _check(matched and local.is_finite() and local.x>=-4.5001 and local.x<=4.5001
				and local.y>=-0.0001 and local.y<=5.0001 and local.z>=-8.0001
				and local.z <= (8.0001 if is_zero_approx(fraction) else 11.0001),
				"every actual motion vertex obeys frozen bounds "+str(shape.name)+" fraction="+str(fraction)+" vertex="+str(local)):
				return false
	return _motion_separated(fraction,poses)


## Complete analytic sweep: linear carriage stages attain extrema at endpoints.
## Rotating vertex extrema occur where -y*sin(a)+z*cos(a)=0 (y extrema)
## or -y*cos(a)-z*sin(a)=0 (z extrema), plus max-z compensation switches.
## Wedge toe radius sqrt(4.25), stowed z-depth .08/sqrt(1.0625).
func _measure_trajectory() -> bool:
	var angle := PI*0.5+atan(0.25)
	var radius := sqrt(4.25)
	var critical_angles: Array[float] = [0,angle,atan(0.25)]
	for point: Vector3 in (_ship.get_node("InnerSternRampCollision").shape as ConvexPolygonShape3D).points:
		for candidate in [atan2(-point.y,point.z),atan2(point.z,point.y)]:
			for offset in [-PI,0.0,PI]:
				var a: float = candidate+offset
				if a>=0 and a<=angle:
					critical_angles.append(a)
	# Toe z==2 compensation switch: -.5*sin(a)+2*cos(a)==2,
	# using t=tan(a/2), whose roots are0 and.25.
	critical_angles.append(2*atan(0.25))
	var fractions: Array[float] = [0,0.2,0.4,0.6,0.8,1]
	for a: float in critical_angles:
		fractions.append(0.6+0.2*(1-a/angle))
		fractions.append(0.8+0.2*(1-a/angle))
	# Dense samples accompany, and do not replace, the finite critical points.
	for index in 1001:
		fractions.append(float(index)/1000)
	for f: float in fractions:
		var poses: Dictionary = _ship.call("get_access_transforms",f)
		for label: StringName in poses:
			var shape := _ship.get_node(String(label)+"Collision") as CollisionShape3D
			for point: Vector3 in (shape.shape as ConvexPolygonShape3D).points:
				var actual: Vector3 = poses[label]*point
				if not _check(actual.is_finite() and actual.x>=-4.5001 and actual.x<=4.5001
					and actual.y>=-0.0001 and actual.y<=5.0001 and actual.z>=-8.0001
					and actual.z<=(8.0001 if is_zero_approx(f) else 11.0001),"complete critical trajectory bounds f="+str(f)+" point="+str(actual)):
					return false
		if not _motion_separated(f,poses):
			return false
	print("PREDATOR_ACCESS_ANALYTIC_TRAJECTORY: critical_angles=",critical_angles,
		" radius=",radius," maximum_toe_compensation=",radius-2," measured_fractions=",fractions.size())
	return true


## A separating projection proves nonintersection. Additional edge-cross axes
## cannot turn a separation into an intersection; failure to find one is fatal.
func _motion_separated(f: float, poses: Dictionary) -> bool:
	var moving: Array[StringName] = [&"SternClosure",&"InnerSternRamp",&"OuterSternRamp"]
	for label: StringName in moving:
		var collision := _ship.get_node(String(label)+"Collision") as CollisionShape3D
		var a := PackedVector3Array()
		for point: Vector3 in (collision.shape as ConvexPolygonShape3D).points:
			a.append(poses[label]*point)
		for child in _ship.get_children():
			if not child is CollisionShape3D or child == collision:
				continue
			var other := child as CollisionShape3D
			var other_label := StringName(String(other.name).trim_suffix("Collision"))
			var pose: Transform3D = poses.get(other_label,other.transform)
			var b := PackedVector3Array()
			for point: Vector3 in (other.shape as ConvexPolygonShape3D).points:
				b.append(pose*point)
			var axes: Array[Vector3] = [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
			for item in [[label,poses[label]],[other_label,pose]]:
				var mesh := _ship.get_node("PredatorOriginalShell/"+String(item[0])) as MeshInstance3D
				var faces := mesh.mesh.get_faces()
				for index in range(0,faces.size(),3):
					var normal := (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index])
					if normal.length_squared()>0.000001:
						axes.append((item[1] as Transform3D).basis*normal.normalized())
			var separated := false
			for axis: Vector3 in axes:
				var amin := INF
				var amax := -INF
				var bmin := INF
				var bmax := -INF
				for point: Vector3 in a:
					amin = minf(amin,point.dot(axis))
					amax = maxf(amax,point.dot(axis))
				for point: Vector3 in b:
					bmin = minf(bmin,point.dot(axis))
					bmax = maxf(bmax,point.dot(axis))
				if minf(amax,bmax)-maxf(amin,bmin)<=0.0001:
					separated = true
					break
			if not _check(separated,"nonintersecting actual convex motion f="+str(f)+" pair="+String(label)+"/"+String(other_label)):
				return false
	return true


func _aisle_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.598,2.398,13.498)
	query.shape = box
	query.transform = _fixture * Transform3D(Basis.IDENTITY,Vector3(1,2.201,0.25))
	query.collision_mask = PhysicsLayers.SHIP
	query.margin = 0
	return _check(_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"real1.6m aisle and2.4m hatch headroom remain physically clear")


func _camera_clear() -> bool:
	var camera := _ship.get_node("PredatorOriginalShell/PilotFixture/CockpitCamera") as Camera3D
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
		push_error("PREDATOR_ACCESS_FAIL: "+label)
		quit(1)
	return false
