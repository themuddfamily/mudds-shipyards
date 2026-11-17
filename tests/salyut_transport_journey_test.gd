extends SceneTree

## Access only: ordinary production Player walks twice through real stern
## geometry. No pilot claim, Main registration, passenger or network proof.
## Initial setup only; no later Player pose/clock/velocity/mask/gravity writes.
const SALYUT := preload("res://scenes/ships/salyut_transport.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
var _checks := 0
var _failed := false
var _access_ship: HeroShip
var _access_player: PlayerController
var _hatch: ShipCabinHatch
var _commands: FixtureCommands
var _observer: CompletedPlayerTick
var _static_sections: Array[Dictionary] = []
var _motion_samples := 0
var _walking_ticks := 0
var _last_tick := -1
var _last_point := Vector3.INF
var _body_layer := 0
var _body_mask := 0
var _gravity := 0.0
var _capsule_size := Vector2.ZERO
var _capsule_pose := Transform3D.IDENTITY
var _shots := 0

class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	var yaw := 0.0
	var roll := 0.0
	var fire := false
	func _sample_controls() -> Dictionary:
		return {"throttle":throttle,"brake":brake,"yaw":yaw,"roll":roll,"fire":fire}

class CompletedPlayerTick:
	extends Node
	var suite: SceneTree
	func _physics_process(_delta: float) -> void:
		suite.call("_audit_walking_tick")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	if "--transformed" in OS.get_cmdline_user_args():
		fixture.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(35)),Vector3(23,7,-19))
	var deck := StaticBody3D.new()
	deck.collision_layer = PhysicsLayers.WORLD
	deck.collision_mask = 0
	fixture.add_child(deck)
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24,0.5,28)
	slab.shape = box
	slab.position.y = -0.25
	deck.add_child(slab)
	_access_ship = SALYUT.instantiate() as HeroShip
	fixture.add_child(_access_ship)
	_commands = FixtureCommands.new()
	_access_ship.add_child(_commands)
	_access_ship.set_command_source(_commands)
	_access_ship.projectile_fired.connect(func(_origin: Vector3,_direction: Vector3): _shots += 1)
	_access_player = PLAYER.instantiate() as PlayerController
	_access_player.position = Vector3(0,0,12)
	fixture.add_child(_access_player)
	_hatch = _access_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	_access_player.interact_requested.connect(_on_interact)
	_body_layer = _access_player.collision_layer
	_body_mask = _access_player.collision_mask
	_gravity = _access_player.gravity_multiplier
	var actual := _access_player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := actual.shape as CapsuleShape3D
	_capsule_size = Vector2(capsule.radius,capsule.height)
	_capsule_pose = actual.transform
	_observer = CompletedPlayerTick.new()
	_observer.suite = self
	_observer.process_physics_priority = 1000000
	root.add_child(_observer)
	await _frames(8)
	if not _check(_access_ship.call("is_access_supported") and not _access_ship.has_node("ShipBoardingArea") and not _access_ship.has_node("MovingInteriorFrame") and not _access_ship.has_method("get_cargo_manifest") and not _access_ship.has_method("get_passenger_station_role_contract"),"actual supported standalone access adds no seat/Main/frame/cargo/guest grant"): return
	if not _trajectory_contract(): return
	await _drive_for(Vector3.FORWARD,100)
	if not _check(_access_ship.to_local(_access_player.global_position).z > 7.35,"sealed full actual Player cannot cross stern closure/ramp"): return
	await _walk_to(Vector3(0,0,12))
	for cycle in 2:
		await _walk_to(Vector3(-2.3,0,8.6))
		if _failed: return
		if not _check(_access_player.get_nearby_interactables().has(_hatch),"ordinary proximity discovers reachable physical port-side stern control"): return
		await _interact_edge()
		if not _check(_access_ship.is_canopy_open() and _access_ship.call("is_access_motion_active"),"real Player Interact starts complete stern motion"): return
		if not await _probe_propulsion_blocked("moving"): return
		await _frames(26)
		if not _check(_access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active"),"real hatch finishes complete supported ramp/door deployment"): return
		if not await _probe_propulsion_blocked("open"): return
		for point in [Vector3(-2.3,0,10.8),Vector3(0,0,10.8),Vector3(0,0.9,7),Vector3(0,0.9,5.6),Vector3(0,0.9,0),Vector3(-0.75,0.9,-3.3)]:
			await _walk_to(point)
			if _failed: return
		if not _check(_access_ship.to_local(_access_player.global_position).distance_to(Vector3(-0.75,0.9,-3.3)) < 0.12 and not _access_player.is_seated(),"same unseated Player continuously reaches exact supported pilot stand"): return
		for point in [Vector3(0,0.9,0),Vector3(0,0.9,5.6),Vector3(0,0.9,7),Vector3(0,0,10.8),Vector3(-2.3,0,10.8),Vector3(-2.3,0,8.6)]:
			await _walk_to(point)
			if _failed: return
		await _interact_edge()
		await _frames(26)
		if not _check(not _access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active"),"same Player physically reverses complete route and seals from outside sweep"): return
		await _walk_to(Vector3(0,0,12))
	# Explicitly controller-only negative probes. Injected remote simulation
	# never claims/seats this Player or takes its local camera/input ownership.
	_access_ship.set_remote_piloted(true)
	_access_ship.request_engine_start()
	await _frames(1)
	_access_ship.set_canopy_open(true)
	if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_STARTING and not _access_ship.is_canopy_open(),"active startup refuses hatch opening"): return
	await _frames(170)
	if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_STARTING,"closed inherited2.9s startup remains STARTING before exact clock"): return
	await _frames(4)
	_access_ship.set_canopy_open(true)
	if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_ONLINE and not _access_ship.is_canopy_open(),"actual2.9s startup completes and ONLINE opening refuses"): return
	_commands.fire = true
	await _frames(20)
	_commands.fire = false
	_commands.throttle = 0.5
	await _frames(240)
	_commands.throttle = 0
	_commands.brake = true
	await _frames(180)
	_commands.brake = false
	await _frames(95)
	_access_ship.set_canopy_open(true)
	if not _check(not bool(_access_ship.get_telemetry().landed) and _access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and not _access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active") and _shots == 0 and not _access_player.is_seated() and not _access_ship.supports_in_flight_cabin_access(),"real commands establish airborne OFFLINE; unsupported opening refuses and held fire stays unarmed with Player still on apron"): return
	_access_ship.set_remote_piloted(false)
	_release_inputs()
	Input.action_release("interact")
	Input.action_release("jump")
	Input.action_release("sprint_boost")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_observer.queue_free()
	fixture.queue_free()
	await _frames(3)
	print("SALYUT_TRANSPORT_ACCESS_TEST_OK: checks=",_checks," walking_ticks=",_walking_ticks," geometry_ticks=",_motion_samples," shots=",_shots," transformed=", "--transformed" in OS.get_cmdline_user_args())
	quit(0)

func _on_interact() -> void:
	if not _failed and _access_player.get_nearby_interactables().has(_hatch):
		_check(_hatch.interact(_access_player),"real Player Interact reaches normal hatch API at unchanged range")

func _probe_propulsion_blocked(label: String) -> bool:
	var before := _access_ship.global_transform
	_access_ship.set_remote_piloted(true)
	_commands.throttle = 1
	_commands.yaw = 1
	_commands.roll = 1
	_commands.fire = true
	_access_ship.request_engine_start()
	await _frames(3)
	var blocked := _access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and _access_ship.velocity.length() < 0.001 and _access_ship.global_transform.is_equal_approx(before)
	_commands.throttle = 0
	_commands.yaw = 0
	_commands.roll = 0
	_commands.fire = false
	_access_ship.set_remote_piloted(false)
	return _check(blocked,"non-vacuous controller-only throttle/turn/start neutral while access is "+label)

func _audit_walking_tick() -> void:
	if _failed or not is_instance_valid(_access_player): return
	if not _audit_animated_geometry(): return
	var frame := Engine.get_physics_frames()
	var completed: Dictionary = _access_player.get_step_up_assist_audit().get("completed_motion",{})
	var point := _access_player.global_position
	var collision := _access_player.get_node("PlayerCollision") as CollisionShape3D
	var original := collision.shape as CapsuleShape3D
	if not _check(_observer.process_physics_priority > _access_player.process_physics_priority and int(completed.get("frame",-1)) == frame and (_last_tick < 0 or frame == _last_tick+1) and (not _last_point.is_finite() or point.distance_to(_last_point) < 0.2) and _access_player.collision_layer == _body_layer and _access_player.collision_mask == _body_mask and is_equal_approx(_access_player.gravity_multiplier,_gravity) and Vector2(original.radius,original.height) == _capsule_size and collision.transform == _capsule_pose and not collision.disabled and not _access_player.is_seated(),"adjacent completed walking tick retains actual capsule/masks/gravity and <.2m continuity"): return
	var capsule := original.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = _body_mask
	query.exclude = [_access_player.get_rid()]
	var state := _access_player.get_world_3d().direct_space_state
	var hits := state.intersect_shape(query,16)
	var support := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.12,point-Vector3.UP*0.18,_body_mask)
	support.exclude = [_access_player.get_rid()]
	var floor_hit := state.intersect_ray(support)
	if not _check(_access_player.is_on_floor() and hits.is_empty() and not floor_hit.is_empty() and (floor_hit.normal as Vector3).dot(Vector3.UP) >= cos(_access_player.floor_max_angle),"every completed walking tick has actual capsule/head clearance/support point="+str(point)+" hits="+str(hits)+" support="+str(floor_hit)): return
	_last_tick = frame
	_last_point = point
	_walking_ticks += 1

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		if _failed: return

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition: return true
	if not _failed:
		_failed = true
		_release_inputs()
		Input.action_release("interact")
		Input.action_release("jump")
		Input.action_release("sprint_boost")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		push_error("SALYUT_ACCESS_FAIL: "+label)
		quit(1)
	return false

func _walk_to(local_target: Vector3) -> void:
	for tick in 900:
		if _failed:
			return
		var difference := _access_ship.to_global(local_target) - _access_player.global_position
		difference.y = 0
		if difference.length() < 0.035:
			_release_inputs()
			await _frames(10)
			_check((_access_ship.to_local(_access_player.global_position) - local_target).length() < 0.12,"ordinary walking reaches " + str(local_target))
			return
		await process_frame
		_set_walk_input(difference.normalized(),minf(1.0,maxf(0.25,difference.length()*1.4)))
		await physics_frame
	_release_inputs()
	_check(false,"ordinary walking timed out target=" + str(local_target) + " actual=" + str(_access_ship.to_local(_access_player.global_position)))


func _set_walk_input(world_direction: Vector3, strength: float = 1.0) -> void:
	var yaw := _access_player.get_node("CameraRig/CameraYaw") as Node3D
	var right := yaw.global_basis.x
	var forward := -yaw.global_basis.z
	var x := world_direction.dot(right)*strength
	var y := world_direction.dot(forward)*strength
	_release_inputs()
	if absf(x) > 0.001:
		Input.action_press("move_right" if x > 0 else "move_left",absf(x))
	if absf(y) > 0.001:
		Input.action_press("move_forward" if y > 0 else "move_back",absf(y))


func _drive_for(local_direction: Vector3, ticks: int) -> void:
	await process_frame
	_set_walk_input(_access_ship.global_basis * local_direction)
	await _frames(ticks)
	_release_inputs()
	await _frames(10)


func _interact_edge() -> void:
	await process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _release_inputs() -> void:
	for action in ["move_left","move_right","move_forward","move_back"]:
		Input.action_release(action)


func _has_point(points: PackedVector3Array, target: Vector3) -> bool:
	for point in points:
		if point.distance_to(target) <= 0.00001:
			return true
	return false


func _axis(axes: Array[Vector3], value: Vector3) -> void:
	if value.length_squared() < 0.00000001:
		return
	var normal := value.normalized()
	for existing in axes:
		if absf(existing.dot(normal)) > 0.99999:
			return
	axes.append(normal)


func _section(points: PackedVector3Array, faces: PackedVector3Array, label: String, moving: bool) -> Dictionary:
	var normals: Array[Vector3] = []
	var edges: Array[Vector3] = []
	var bounds := AABB(points[0],Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	for i in range(0,faces.size(),3):
		var a := faces[i]
		var b := faces[i+1]
		var c := faces[i+2]
		_axis(normals,(b-a).cross(c-a))
		_axis(edges,b-a)
		_axis(edges,c-b)
		_axis(edges,a-c)
	return {"points":points,"normals":normals,"edges":edges,"bounds":bounds,"name":label,"moving":moving}


func _moving_section(points: PackedVector3Array, label: String) -> Dictionary:
	var faces := PackedVector3Array()
	var triangles := [0,1,2,0,2,3,6,5,4,7,6,4,4,1,0,4,5,1,5,2,1,5,6,2,6,3,2,6,7,3,7,0,3,7,4,0]
	for index in triangles:
		faces.append(points[index])
	return _section(points,faces,label,true)


func _prime_static_sections() -> void:
	if not _static_sections.is_empty():
		return
	var leaves: Array = _access_ship.get("_access_leaves")
	for child in _access_ship.get_children():
		if not child is CollisionShape3D:
			continue
		var moving := false
		for leaf in leaves:
			if leaf.collision == child:
				moving = true
		if moving:
			continue
		var collision := child as CollisionShape3D
		var points := PackedVector3Array()
		for point in (collision.shape as ConvexPolygonShape3D).points:
			points.append(collision.transform * point)
		var mesh := _access_ship.get_node("SalyutOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_static_sections.append(_section(points,vertices,String(mesh.name),false))


func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	var aa: AABB = a.bounds
	var bb: AABB = b.bounds
	for i in 3:
		if minf(aa.end[i],bb.end[i]) - maxf(aa.position[i],bb.position[i]) <= 0.00001:
			return false
	var axes: Array[Vector3] = []
	for normal: Vector3 in a.normals:
		_axis(axes,normal)
	for normal: Vector3 in b.normals:
		_axis(axes,normal)
	for first: Vector3 in a.edges:
		for second: Vector3 in b.edges:
			_axis(axes,first.cross(second))
	for axis in axes:
		var amin := INF
		var amax := -INF
		var bmin := INF
		var bmax := -INF
		for point: Vector3 in a.points:
			amin = minf(amin,axis.dot(point))
			amax = maxf(amax,axis.dot(point))
		for point: Vector3 in b.points:
			bmin = minf(bmin,axis.dot(point))
			bmax = maxf(bmax,axis.dot(point))
		if minf(amax,bmax) - maxf(amin,bmin) <= 0.00001:
			return false
	return true


func _separated(sections: Array[Dictionary], fraction: float) -> bool:
	for i in sections.size():
		for j in range(i+1,sections.size()):
			if not sections[i].moving and not sections[j].moving:
				continue # Unchanged foundation fixture covers every static pair.
			if _overlaps(sections[i],sections[j]):
				return _check(false,"moving solid interiors overlap " + sections[i].name + " / " + sections[j].name + " fraction=" + str(fraction))
	return true


func _bounded(point: Vector3, closed: bool) -> bool:
	return point.is_finite() and absf(point.x) <= 4.00001 and point.y >= -0.00001 and point.y <= 4.50001 and point.z >= -7.00001 and point.z <= (7.00001 if closed else 10.00001)


func _trajectory_contract() -> bool:
	_prime_static_sections()
	var leaves: Array = _access_ship.get("_access_leaves")
	if not _check(leaves.size() == 4,"exact two sheared closure halves and two rigid ramp leaves"):
		return false
	# Every stage boundary and hundredth of the rigid door/ramp trajectory.
	# Every rotated corner participates in the production maximum-Z correction.
	for sample in 101:
		var fraction := float(sample) / 100.0
		var sections: Array[Dictionary] = _static_sections.duplicate()
		for leaf in leaves:
			var points: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,fraction)
			for point in points:
				if not _check(_bounded(point,sample == 0),"finite bounded authored trajectory " + String(leaf.mesh.name) + " fraction=" + str(fraction) + " point=" + str(point)):
					return false
			sections.append(_moving_section(points,String(leaf.mesh.name)))
		if not _separated(sections,fraction):
			return false
	var full_ramp := AABB()
	var first := true
	for leaf in leaves:
		if not String(leaf.mesh.name).begins_with("SternRamp"):
			continue
		var points: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,1.0)
		for point in points:
			full_ramp = AABB(point,Vector3.ZERO) if first else full_ramp.expand(point)
			first = false
	if not _check(full_ramp.is_equal_approx(AABB(Vector3(-1.1,0,7),Vector3(2.2,0.9,3))),"exact adopted deployed ramp footprint and top height"):
		return false
	print("SALYUT_ACCESS_TRAJECTORY:101 fractions, sheared door halves/staged rigid ramp leaves, strict closed/deployed bounds and moving/static SAT separation")
	return true


func _audit_animated_geometry() -> bool:
	_prime_static_sections()
	var sections: Array[Dictionary] = _static_sections.duplicate()
	var fraction := float(_access_ship.get("_access_fraction"))
	for leaf in _access_ship.get("_access_leaves"):
		var expected: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,fraction)
		var points: PackedVector3Array = leaf.collision.shape.points
		# This is the real render buffer; get_faces() rounds rational ramp data.
		var arrays: Array = leaf.mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if not _check((leaf.mesh.global_transform as Transform3D).is_equal_approx(leaf.collision.global_transform) and normals.size() == vertices.size(),"actual moving render/collider global poses and normals agree " + String(leaf.mesh.name)):
			return false
		var center := Vector3.ZERO
		for point in points:
			center += point / float(points.size())
		for point in expected:
			if not _check(_has_point(points,point) and _has_point(vertices,point) and _bounded(point,fraction <= 0.000001),"actual visible/collider vertices match bounded trajectory " + String(leaf.mesh.name) + " fraction=" + str(fraction) + " point=" + str(point)):
				return false
		for i in vertices.size():
			if not _check(_has_point(expected,vertices[i]) and normals[i].dot(vertices[i]-center) > 0,"actual render triangles belong to collision and face outward " + String(leaf.mesh.name)):
				return false
		sections.append(_section(points,vertices,String(leaf.mesh.name),true))
	if not _separated(sections,fraction):
		return false
	_motion_samples += 1
	if fraction > 0.999 and not _access_ship.call("is_access_motion_active"):
		var query := PhysicsShapeQueryParameters3D.new()
		var clearance := BoxShape3D.new()
		# Full required dimensions at the physical outer aperture; the sheared
		# header ends before this z slab. Offset above support, never shrink.
		clearance.size = Vector3(2.2,2.4,0.12)
		query.shape = clearance
		query.transform = _access_ship.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,2.101,6.9))
		query.collision_mask = PhysicsLayers.SHIP
		query.margin = 0
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual deployed stern opening at least2m wide x2.4m high"): return false
		clearance.size = Vector3(1.4,2.4,11.2)
		query.transform = _access_ship.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,2.101,0))
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"complete actual1.4m cabin aisle and standing headroom remain clear"): return false
	return true
