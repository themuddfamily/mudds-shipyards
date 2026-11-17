extends SceneTree

## Standalone access retains its original cases; --main exercises the ordinary
## Boot/Main pilot journey, physical home exit and full station return.
## Initial setup only; no later Player pose/clock/velocity/mask/gravity writes.
const UTOPIA := preload("res://scenes/ships/utopia_dropship.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
var _checks := 0
var _failed := false
var _access_ship: HeroShip
var _access_player: PlayerController
var _hatch: ShipCabinHatch
var _commands: FixtureCommands
var _observer: CompletedPlayerTick
var _static_sections: Array[Dictionary] = []
var _reservations: Array[Dictionary] = []
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
var _bad_origin := false
var _profile_started_ms := 0

class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var fire := false
	func _sample_controls() -> Dictionary:
		return {"throttle":throttle,"brake":brake,"yaw":yaw,"pitch":pitch,"roll":roll,"fire":fire}

class CompletedPlayerTick:
	extends Node
	var suite: SceneTree
	func _physics_process(_delta: float) -> void:
		suite.call("_audit_walking_tick")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--main" in OS.get_cmdline_user_args() or "--crew" in OS.get_cmdline_user_args():
		await _run_main()
		return
	_profile_started_ms = Time.get_ticks_msec()
	var watchdog := create_timer(180.0)
	watchdog.timeout.connect(func(): _check(false, "fixed180s profile cap"))
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
	box.size = Vector3(28,0.5,34)
	slab.shape = box
	slab.position.y = -0.25
	deck.add_child(slab)
	_access_ship = UTOPIA.instantiate() as HeroShip
	fixture.add_child(_access_ship)
	_commands = FixtureCommands.new()
	_access_ship.add_child(_commands)
	_access_ship.set_command_source(_commands)
	_access_ship.projectile_fired.connect(func(origin: Vector3,direction: Vector3):
		_shots += 1
		if _access_ship.to_local(origin).distance_to(Vector3(0,1.5,-8.7)) > 0.0001 or not direction.is_finite() or direction.is_zero_approx(): _bad_origin = true)
	_access_player = PLAYER.instantiate() as PlayerController
	_access_player.position = Vector3(0,0,14.5)
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
	if not _check(_access_ship.call("is_access_supported") and _access_ship.has_node("ShipBoardingArea") and not (_access_ship.get_node("ShipBoardingArea") as ShipBoardingArea).is_reserved() and not _access_ship.has_node("MovingInteriorFrame") and not _access_ship.has_method("get_cargo_manifest") and not _access_ship.has_method("get_passenger_station_role_contract"),"actual supported standalone access has unreserved helm and no Main/frame/cargo/guest grant"): return
	if not _trajectory_contract(): return
	await _drive_for(Vector3.FORWARD,100)
	if not _check(_access_ship.to_local(_access_player.global_position).z > 8.5,"sealed full actual Player cannot cross stern closure/ramp"): return
	await _walk_to(Vector3(0,0,14.5))
	for cycle in 2:
		await _walk_to(Vector3(-3.4,0,10.1))
		if _failed: return
		if not _check(_access_player.get_nearby_interactables().has(_hatch),"ordinary proximity discovers reachable physical port-side stern control"): return
		await _interact_edge()
		if not _check(_access_ship.is_canopy_open() and _access_ship.call("is_access_motion_active"),"real Player Interact starts complete stern motion"): return
		if not await _probe_propulsion_blocked("moving"): return
		await _await_access_complete()
		if not _check(_access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active"),"real hatch finishes complete supported ramp/door deployment"): return
		if not await _probe_propulsion_blocked("open"): return
		for point in [Vector3(-3.4,0,13.3),Vector3(0,0,13.3),Vector3(0,0.8,8),Vector3(0,0.8,7.5),Vector3(0,0.8,0),Vector3(0.8,0.8,-5.8)]:
			await _walk_to(point)
			if _failed: return
		if not _check(_access_ship.to_local(_access_player.global_position).distance_to(Vector3(0.8,0.8,-5.8)) < 0.12 and not _access_player.is_seated(),"same unseated Player continuously reaches exact supported pilot stand"): return
		for point in [Vector3(0,0.8,0),Vector3(0,0.8,7.5),Vector3(0,0.8,8),Vector3(0,0,13.3),Vector3(-3.4,0,13.3),Vector3(-3.4,0,10.1)]:
			await _walk_to(point)
			if _failed: return
		await _interact_edge()
		await _await_access_complete()
		if not _check(not _access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active"),"same Player physically reverses complete route and seals from outside sweep"): return
		await _walk_to(Vector3(0,0,14.5))
	# Explicitly controller-only negative probes. Injected remote simulation
	# never claims/seats this Player or takes its local camera/input ownership.
	_access_ship.set_remote_piloted(true)
	_access_ship.request_engine_start()
	await _frames(1)
	_access_ship.set_canopy_open(true)
	if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_STARTING and not _access_ship.is_canopy_open(),"active startup refuses hatch opening"): return
	await _frames(203)
	if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_STARTING,"closed inherited3.45s startup remains STARTING before exact clock"): return
	await _frames(4)
	_access_ship.set_canopy_open(true)
	if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_ONLINE and not _access_ship.is_canopy_open(),"actual3.45s startup completes and ONLINE opening refuses"): return
	_commands.fire = true
	await _frames(20)
	_commands.fire = false
	if not _check(_shots == 1 and not _bad_origin and is_equal_approx(float(_access_ship.call("_get_weapon_targeting_distance")),650.0) and is_equal_approx(_access_ship.weapon_cooldown,0.62), "real closed ONLINE fire positively emits one exact center pulse with adopted650m range/.62s cooldown"): return
	_commands.throttle = 0.5
	await _frames(240)
	_commands.throttle = 0
	_commands.brake = true
	await _frames(180)
	_commands.brake = false
	await _frames(95)
	_access_ship.set_canopy_open(true)
	if not _check(not bool(_access_ship.get_telemetry().landed) and _access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and not _access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active") and _shots > 0 and not _bad_origin and not _access_player.is_seated() and not _access_ship.supports_in_flight_cabin_access(),"real commands establish airborne OFFLINE; unsupported opening refuses and closed flight fire uses original pulse with Player still on apron"): return
	_access_ship.set_remote_piloted(false)
	_release_inputs()
	Input.action_release("interact")
	Input.action_release("jump")
	Input.action_release("sprint_boost")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_observer.queue_free()
	fixture.queue_free()
	await _frames(3)
	print("UTOPIA_DROPSHIP_ACCESS_TEST_OK: checks=",_checks," walking_ticks=",_walking_ticks," geometry_ticks=",_motion_samples," shots=",_shots," transformed=", "--transformed" in OS.get_cmdline_user_args(), " elapsed_ms=", Time.get_ticks_msec()-_profile_started_ms)
	quit(0)

func _on_interact() -> void:
	if not _failed and _access_player.get_nearby_interactables().has(_hatch):
		_check(_hatch.interact(_access_player),"real Player Interact reaches normal hatch API at unchanged range")

func _probe_propulsion_blocked(label: String) -> bool:
	var before := _access_ship.global_transform
	var previous_shots := _shots
	var previous_heat: float = _access_ship.get("_weapon_heat")
	var previous_timer: float = _access_ship.get("_weapon_timer")
	_access_ship.set_remote_piloted(true)
	_commands.throttle = 1
	_commands.yaw = 1
	_commands.pitch = 1
	_commands.roll = 1
	_commands.fire = true
	_access_ship.request_engine_start()
	await _frames(3)
	var blocked: bool = _access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and _access_ship.velocity.length() < 0.001 and _access_ship.global_transform.is_equal_approx(before) and _shots == previous_shots and is_equal_approx(float(_access_ship.get("_weapon_heat")),previous_heat) and is_equal_approx(float(_access_ship.get("_weapon_timer")),previous_timer)
	_commands.throttle = 0
	_commands.yaw = 0
	_commands.pitch = 0
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
		push_error("UTOPIA_ACCESS_FAIL: "+label)
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
		var mesh := _access_ship.get_node("UtopiaOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
		var faces := PackedVector3Array()
		for surface_index in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for point in vertices: faces.append(mesh.transform * point)
			else:
				for index in indices: faces.append(mesh.transform * vertices[index])
		_static_sections.append(_section(points,faces,String(mesh.name),false))
	# These are fixed future capacity volumes, never spawned cargo or seats.
	for side in [-1.0,1.0]:
		for index in 4:
			var center := Vector3(side*2,1.4,-1.2+index*2)
			_reservations.append(_reservation_volume(center,Vector3(1.2,1.2,1.2),"future rack"))
		_reservations.append(_reservation_volume(Vector3(side*2,1.4,-3.6),Vector3(1.2,1.2,1.2),"future port chair" if side < 0 else "future starboard chair"))
	_reservations.append(_reservation_volume(Vector3(0,2.1,0.35),Vector3(1.6,2.6,14.3),"fixed1.6m centre aisle"))


func _reservation_volume(center: Vector3, size: Vector3, label: String) -> Dictionary:
	var points := PackedVector3Array()
	for corner in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,-1,1),Vector3(-1,-1,1),
		Vector3(-1,1,-1),Vector3(1,1,-1),Vector3(1,1,1),Vector3(-1,1,1)]:
		points.append(center+corner*size*0.5)
	return _moving_section(points,label)


func _reservations_clear(sections: Array[Dictionary], fraction: float) -> bool:
	for section in sections:
		for reserved in _reservations:
			if _overlaps(section,reserved):
				if _fitted_chair_consumes_reservation(section,reserved): continue
				return _check(false,"solid invades "+reserved.name+" / "+section.name+" fraction="+str(fraction)+" actual_bounds="+str(section.bounds)+" reserved_bounds="+str(reserved.bounds))
	return true


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
	return point.is_finite() and absf(point.x) <= 4.50001 and point.y >= -0.00001 and point.y <= 4.80001 and point.z >= -8.50001 and point.z <= (8.50001 if closed else 12.50001)


func _trajectory_contract() -> bool:
	_prime_static_sections()
	var leaves: Array = _access_ship.get("_access_leaves")
	if not _check(leaves.size() == 5,"exact two rigid closure halves and three rigid ramp leaves"):
		return false
	# Every stage boundary and hundredth of the rigid door/ramp trajectory.
	# Every rotated corner participates in the production maximum-Z correction.
	for sample in 101:
		var fraction := float(sample) / 100.0
		var sections: Array[Dictionary] = _static_sections.duplicate()
		for leaf in leaves:
			var points: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,fraction)
			for i in points.size():
				for j in range(i+1,points.size()):
					if not _check(is_equal_approx(points[i].distance_to(points[j]),leaf.open[i].distance_to(leaf.open[j])),"every leaf remains rigid through authored motion"): return false
			for point in points:
				if not _check(_bounded(point,sample == 0),"finite bounded authored trajectory " + String(leaf.mesh.name) + " fraction=" + str(fraction) + " point=" + str(point)):
					return false
			sections.append(_moving_section(points,String(leaf.mesh.name)))
		if not _reservations_clear(sections,fraction): return false
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
	if not _check(full_ramp.is_equal_approx(AABB(Vector3(-1.2,0,8),Vector3(2.4,0.8,4.5))),"exact adopted deployed ramp footprint and top height"):
		return false
	print("UTOPIA_ACCESS_TRAJECTORY:101 fractions, rigid door halves/three staged rigid ramp leaves, strict closed/deployed bounds and moving/static SAT separation")
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
	if not _reservations_clear(sections,fraction): return false
	if not _separated(sections,fraction):
		return false
	_motion_samples += 1
	if fraction > 0.999 and not _access_ship.call("is_access_motion_active"):
		var query := PhysicsShapeQueryParameters3D.new()
		var clearance := BoxShape3D.new()
		# Full required dimensions immediately aft of the physical header;
		# this slab touches neither the floor nor header. Never shrink.
		clearance.size = Vector3(2.4,2.4,0.04)
		query.shape = clearance
		query.transform = _access_ship.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,2.0,8.55))
		query.collision_mask = PhysicsLayers.SHIP
		query.margin = 0
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual deployed outer stern aperture2.4m wide x2.4m high"): return false
		# Exact1.6m aisle and full2.6m cabin headroom are checked against
		# actual root convex vertices by SAT above, including shared boundaries.

	if _access_player.is_seated():
		var eye := _access_ship.get_node("CockpitCamera") as Camera3D
		var eye_query := PhysicsShapeQueryParameters3D.new()
		var clearance := SphereShape3D.new()
		clearance.radius = 0.1
		eye_query.shape = clearance
		eye_query.transform = eye.global_transform
		eye_query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		eye_query.margin = 0
		if not _check(eye.position == Vector3(0,2.56,-6.05) and _access_ship.get_world_3d().direct_space_state.intersect_shape(eye_query).is_empty(),"actual fixed seated cockpit eye has physical clearance throughout access and flight"): return false
	return true


func _await_access_complete() -> void:
	for tick in 100:
		if _failed: return
		if not _access_ship.call("is_access_motion_active"): return
		await _frames(1)
	_check(false, "authored1.2s hatch motion completes within100 normal ticks")


# Actual Boot/Main mode composes no custom boarding coordinator or command
# source. Every transition and flight action comes through real production input.
const BOOT := preload("res://scenes/boot.tscn")
const MAIN_STATION_ROUTE := [
	Vector3(8,0,11),Vector3(8,0,13.5),Vector3(35,0,13.5),
	Vector3(35,0,15.5),Vector3(43,0,15.5),Vector3(43,0,24.8),
	Vector3(48.1,0,24.8),Vector3(48.1,0,28),Vector3(68.5,0,28),
	Vector3(68.5,0,38),Vector3(83,0,38),Vector3(93.3,0,38),
	Vector3(116.5,0,38),Vector3(116.5,0,46),Vector3(124.5,0,46),
	Vector3(129.65,0,41.55),Vector3(130.5,0.38,38),Vector3(135,0.38,38),
	Vector3(135,0.38,-16.4),Vector3(140.6,0.38,-16.4),Vector3(140.6,0.38,-19.9),
]
var _main_game: GameFlow
var _main_ship: HeroShip
var _main_player: PlayerController
var _main_observer: MainCompletedPlayerTick
var _main_active := false
var _main_ticks := 0
var _main_last_frame := -1
var _main_last_point := Vector3.INF
var _main_layer := 0
var _main_mask := 0
var _main_gravity := 0.0
var _main_capsule_size := Vector2.ZERO
var _main_capsule_pose := Transform3D.IDENTITY
var _main_engine_edges: Array[Dictionary] = []
var _main_shots := 0
var _main_projectiles := 0
var _main_bad_shot := false
var _main_claims := 0
var _main_releases := 0

class MainCompletedPlayerTick:
	extends Node
	signal completed_tick
	var suite: SceneTree
	func _physics_process(_delta: float) -> void:
		suite.call("_main_audit_completed_tick")
		completed_tick.emit()


func _run_main() -> void:
	_profile_started_ms = Time.get_ticks_msec()
	var watchdog := create_timer(300.0)
	watchdog.timeout.connect(func(): _main_check(false,"fixed300s complete Main profile cap"))
	var boot := BOOT.instantiate() as StartupLoader
	root.add_child(boot)
	_main_game = await boot.startup_completed as GameFlow
	await _main_frames(3)
	if not _main_check(StartupLoader.is_title_menu_ready(_main_game),"ordinary Boot reaches actual Begin Shift"): return
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_X
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _main_frames(2)
	await _main_frames(45)
	_main_player = _main_game.player
	_main_ship = _main_game.get_node("UtopiaDropship") as HeroShip
	# Reuse the access fixture's actual animated render/collider audit only;
	# no standalone access coordinator is installed in this mode.
	_access_ship = _main_ship
	_access_player = _main_player
	_main_ship.engine_state_changed.connect(func(state: StringName): _main_engine_edges.append({"state":state,"tick":Engine.get_physics_frames(),"remaining":_main_ship.get("_engine_timer")}))
	_main_ship.projectile_fired.connect(func(_origin: Vector3,_direction: Vector3): _main_projectiles += 1)
	_main_game.get_combat_authority().authoritative_shot_submitted.connect(func(request: Variant,result: Dictionary):
		if request.source_entity == _main_ship:
			_main_shots += 1
			_main_bad_shot = _main_bad_shot or not bool(result.get("accepted",false)) or request.source_id != 1113 or request.weapon_id != GameFlow.JOVIAN_COMBAT_WEAPON_ID or request.range != 650 or request.damage != 70 or _main_ship.to_local(request.origin).distance_to(Vector3(0,1.5,-8.7)) > 0.0001)
	var identity := _main_player.get_instance_id()
	var spawn := _main_player.global_position
	var world := _main_game.world
	var berth := world.get_berth_node(&"utopia_home_berth") as ShipBerth
	var dock := berth.get_dock_transform()
	if not _main_check(_main_game.phase == GameFlow.Phase.APPROACH_SHIP and _main_player.is_control_enabled() and _main_player.global_position.distance_to(world.get_player_spawn().origin) < 0.25 and _main_game.get_flyable_ships().size() == 15 and world.get_berth_ids().size() == 15 and berth.get_occupant() == _main_ship and berth.get_reservation_owner() == _main_ship and _main_ship.global_transform.is_equal_approx(dock),"actual normal Main spawn, fifteen flyables and exact occupied Utopia home"): return
	var old_poses := {}
	var old_sources := {}
	var old_settings := {}
	var old_leases := {}
	var old_centers := {}
	var unique := {}
	var source_owners := {}
	for craft: HeroShip in _main_game.get_flyable_ships():
		if not _main_check(not unique.has(craft.get_ship_id()),"unique production craft identity "+str(craft.get_ship_id())): return
		unique[craft.get_ship_id()] = true
		var source := _main_game.get_combat_authority().get_source_id(craft)
		if source > 0:
			if not _main_check(not source_owners.has(source),"unique authoritative firing source "+str(source)): return
			source_owners[source] = craft
		if craft == _main_ship: continue
		old_poses[craft] = craft.global_transform
		old_sources[craft] = source
		old_settings[craft] = [craft.mouse_sensitivity,craft.invert_mouse_y,craft.get_camera().fov,craft.maximum_chase_camera_rotation_lag_degrees]
		var home := world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		if not _main_check(home != null and home.get_occupant() == craft and home.get_reservation_owner() == craft,"all fourteen existing craft retain occupied own homes"): return
		old_leases[home] = {"audit":home.audit(),"owner":home.get_reservation_owner(),"occupant":home.get_occupant(),"token":home.get_reservation_token(craft),"pose":home.get_dock_transform()}
		old_centers[home] = home.landing_volume_center
	var profiles := _main_game._get_player_weapon_profiles(_main_ship)
	var profile := _main_game.get_combat_authority().get_weapon_profile(_main_ship,GameFlow.JOVIAN_COMBAT_WEAPON_ID)
	if not _main_check(profiles.size() == 1 and profiles.has(GameFlow.JOVIAN_COMBAT_WEAPON_ID) and profile == profiles[GameFlow.JOVIAN_COMBAT_WEAPON_ID] and profile.get("range") == 650 and profile.get("damage") == 70 and is_equal_approx(_main_ship.weapon_cooldown,0.62) and _main_game.get_combat_authority().get_source_id(_main_ship) == 1113 and (_main_ship.get_node("AuthoritativeDamageable") as LifecycleDamageableAdapter).get_target_entity() == _main_ship and _main_ship.has_node("MovingInteriorFrame") and not _main_ship.supports_in_flight_cabin_access() and not _main_ship.has_method("get_passenger_station_role_contract"),"actual unique Utopia source1113 binds only unchanged70/650/.62 pilot pulse and closed local-only chair frame; no travelling cabin grant"): return
	var roster := _main_game._build_fleet_registry_snapshot()
	if not _main_check(roster.rows.size() == 15 and old_poses.size() == 14 and old_leases.size() == 14,"actual registry and preserved original fourteen state set"): return
	var area := _main_ship.get_node("ShipBoardingArea") as ShipBoardingArea
	var generation := _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(not area.is_reserved() and not _main_game._transition_busy and _main_game._transition_generation == generation,"outside direct boarding refuses before reservation or generation"): return
	var collision := _main_player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	_main_layer = _main_player.collision_layer
	_main_mask = _main_player.collision_mask
	_main_gravity = _main_player.gravity_multiplier
	_main_capsule_size = Vector2(capsule.radius,capsule.height)
	_main_capsule_pose = collision.transform
	_main_observer = MainCompletedPlayerTick.new()
	_main_observer.suite = self
	_main_observer.process_physics_priority = 1000000
	root.add_child(_main_observer)
	_main_active = true
	if not _trajectory_contract(): return
	if not _main_fitted_chair_geometry(): return
	for index in MAIN_STATION_ROUTE.size():
		if not await _main_walk_to(MAIN_STATION_ROUTE[index],index): return
	if "--crew" in OS.get_cmdline_user_args():
		await _main_crew_journey(identity,spawn,area)
		return
	for sortie in 2:
		if not await _main_board_from_stern(sortie,identity,area): return
		if not await _main_sortie_home(sortie,identity,area,berth,dock): return
		if not await _main_walk_out(sortie): return
	# A fresh physical third claim proves that the second exit did not strand
	# the body, reservation, camera, input bank or the generic reboard fence.
	if not await _main_board_from_stern(2,identity,area): return
	if not _main_check(_main_claims == 3 and _main_releases == 2 and _main_ticks > 1000 and _main_player.get_instance_id() == identity and _main_game.active_ship == _main_ship and _main_game._piloting and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()),"two complete ordinary sorties/exits and fresh third physical claim retain same Player"): return
	if not await _main_release_at_home(identity,area): return
	if not await _main_walk_out(2): return
	if not _main_check(_main_claims == 3 and _main_releases == 3,"fresh third home-only reboard releases normal claims once"): return
	for index in range(MAIN_STATION_ROUTE.size()-2,-1,-1):
		if not await _main_walk_to(MAIN_STATION_ROUTE[index],100+index): return
	if not await _main_walk_to(spawn,199): return
	if not _main_check(_main_player.get_instance_id() == identity and _main_player.global_position.distance_to(spawn) < 0.12 and _main_player.is_on_floor() and not _main_player.is_seated(),"same ordinary Player completes full reverse station walk to original spawn"): return
	for craft: HeroShip in old_poses:
		if not _main_check(craft.global_transform.is_equal_approx(old_poses[craft]) and _main_game.get_combat_authority().get_source_id(craft) == old_sources[craft] and [craft.mouse_sensitivity,craft.invert_mouse_y,craft.get_camera().fov,craft.maximum_chase_camera_rotation_lag_degrees] == old_settings[craft],"all fourteen old craft poses/source IDs/settings preserved "+String(craft.name)): return
	for home: ShipBerth in old_leases:
		var saved: Dictionary = old_leases[home]
		if not _main_check(home.audit() == saved.audit and home.get_reservation_owner() == saved.owner and home.get_occupant() == saved.occupant and home.get_reservation_token(saved.owner) == saved.token and home.get_dock_transform().is_equal_approx(saved.pose) and home.landing_volume_center == old_centers[home],"all fourteen old berth poses/centers/owners/occupants/tokens preserved "+str(home.get_berth_id())): return
	if not _main_check(not _main_bad_shot and _main_shots >= 2 and _main_projectiles == _main_shots,"both usable flights emit only real center-muzzle approved pulse with unique source"): return
	await _main_quit_normally()


func _main_board_from_stern(sortie: int, identity: int, area: ShipBoardingArea) -> bool:
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"normal look discovers reachable physical stern control"): return false
	await _main_tap(&"interact")
	_main_ship.request_engine_start() # Negative moving/open startup probe only.
	if not _main_check(StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"moving access refuses engine start"): return false
	await _main_frames(80)
	_main_ship.request_engine_start()
	if not _main_check(_main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"full open access refuses startup"): return false
	var generation := _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(not area.is_reserved() and _main_game._transition_generation == generation,"open access outside actual helm still refuses direct boarding"): return false
	for point in [Vector3(-3.4,0,13.3),Vector3(0,0,13.3),Vector3(0,0.8,8),Vector3(0,0.8,7.5),Vector3(0,0.8,0),Vector3(0.8,0.8,-5.8)]:
		if not await _main_walk_to(_main_ship.to_global(point),30+sortie,true): return false
	if not _main_check(_main_ship.can_board_from_landed_approach(_main_player),"same full actual Player walks continuously up ramp to fixed supported stand"): return false
	if not _main_check(area.try_reserve(_main_game) and area.try_reserve(_main_game) and not area.try_reserve(_main_player) and not area.release_reservation(_main_player) and area.get_reservation_token() == _main_game,"foreign/duplicate seat requests preserve current temporary claimant"): return false
	await _main_tap(&"interact")
	if not _main_check(not _main_game._piloting and area.get_reservation_token() == _main_game,"foreign-held helm refuses ordinary Interact"): return false
	if not _main_check(area.release_reservation(_main_game) and not area.release_reservation(_main_game),"temporary foreign claim retires once and stale release refuses"): return false
	await _main_aim(_main_ship.get_pilot_seat_anchor().global_position)
	await _main_tap(&"interact")
	for frame in 240:
		if _main_game._piloting and not _main_game._transition_busy: break
		await _main_frames(1)
	if not _main_check(_main_game.active_ship == _main_ship and _main_game._piloting and not _main_game._transition_busy and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _main_player and _main_player.get_instance_id() == identity and not _main_ship.is_canopy_open() and _main_ship.get_camera().current,"actual ordinary E claims seat/camera/input and fully seals Utopia sortie="+str(sortie)): return false
	_main_claims += 1
	generation = _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(_main_game._transition_generation == generation and area.get_reservation_token() == _main_player,"duplicate seated direct boarding cannot replace current transaction"): return false
	var eye := _main_ship.get_node("CockpitCamera") as Camera3D
	if not _main_check(eye.position == Vector3(0,2.56,-6.05) and _main_ship.get_pilot_seat_anchor().position == Vector3(0,0.8,-5.8) and _main_game.hud._active_ship_name == "UTOPIA-CLASS DROPSHIP CANDIDATE" and _main_game.hud._active_ship_role == "SUPPLY DROPSHIP","actual adopted pilot/eye poses and bound candidate HUD identity"): return false
	return true


func _main_sortie_home(sortie: int, identity: int, area: ShipBoardingArea, berth: ShipBerth, dock: Transform3D) -> bool:
	_main_engine_edges.clear()
	Input.action_press(&"move_forward")
	for frame in 500:
		if not bool(_main_ship.get_telemetry().landed) and not _main_ship.get("_departure_lift_active"): break
		await _main_frames(1)
	_main_release_inputs()
	if not _main_check(_main_engine_edges.size() == 2 and _main_engine_edges[0].state == HeroShip.ENGINE_STARTING and _main_engine_edges[1].state == HeroShip.ENGINE_ONLINE and is_equal_approx(float(_main_engine_edges[0].remaining),3.45) and int(_main_engine_edges[1].tick)-int(_main_engine_edges[0].tick) >= 206 and int(_main_engine_edges[1].tick)-int(_main_engine_edges[0].tick) <= 208 and StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE,"actual inherited3.45s startup edges/ticks="+str(_main_engine_edges)): return false
	if not _main_check((_main_ship.global_position-dock.origin).dot(dock.basis.y) >= 3.99 and berth.get_occupant() == null and berth.get_reservation_owner() == null,"actual4m departure lift releases exact own occupied lease"): return false
	await _main_tap(&"interact")
	if not _main_check(_main_game._piloting and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _main_player and not _main_game._transition_busy,"active airborne pilot exit refuses"): return false
	var target := dock*Vector3(0,8,-20)
	var arrived := false
	var turned := false
	for frame in 1800:
		var offset := target-_main_ship.global_position
		var distance := offset.length()
		_main_release_inputs()
		if distance < 0.6 and _main_ship.velocity.length() <= 0.35:
			arrived = true
			break
		var local_direction := _main_ship.global_basis.inverse()*offset.normalized()
		var pitch_error := atan2(local_direction.y,-local_direction.z)
		if absf(pitch_error) > 0.003:
			Input.action_press(&"pitch_up" if pitch_error > 0 else &"pitch_down",clampf(absf(pitch_error)*3,0.08,1))
		var desired_speed := minf(6.0,distance*0.9)
		if _main_ship.velocity.length() > desired_speed+0.1: Input.action_press(&"brake")
		elif distance > 0.45: Input.action_press(&"move_forward",clampf((desired_speed-_main_ship.velocity.length())*0.3+0.13,0.12,0.8))
		await _main_frames(1)
		turned = turned or _main_ship.global_basis.get_rotation_quaternion().angle_to(dock.basis.get_rotation_quaternion()) > 0.01
		if frame%180 == 0: print("UTOPIA_MAIN_FLIGHT: sortie=",sortie," frame=",frame," local=",dock.affine_inverse()*_main_ship.global_position," speed=",_main_ship.velocity.length())
	_main_release_inputs()
	if not _main_check(arrived and turned and _main_game.phase == GameFlow.Phase.FREE_FLIGHT and (dock.affine_inverse()*_main_ship.global_position).distance_to(Vector3(0,8,-20)) <= 0.6 and _main_ship.velocity.length() <= 0.5 and not berth.contains_oriented_bounds(_main_ship.global_transform,_main_ship.get_landing_collision_report().local_bounds),"actual ordinary pitch/throttle/brake flight reaches finite own-home acquisition endpoint"): return false
	var shots := _main_shots
	var projectiles := _main_projectiles
	Input.action_press(&"fire")
	await _main_frames(20)
	Input.action_release(&"fire")
	if not _main_check(_main_shots > shots and _main_projectiles > projectiles and not _main_bad_shot,"actual held fire uses approved center-muzzle pulse on usable flight "+str(sortie)): return false
	Input.action_press(&"brake")
	await _main_frames(30)
	_main_release_inputs()
	await _main_frames(95)
	if not _main_check(StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE and not bool(_main_ship.get_telemetry().landed),"real neutral input establishes airborne OFFLINE"): return false
	var generation := _main_game._transition_generation
	await _main_tap(&"interact")
	await _main_tap(&"interact")
	if not _main_check(_main_game._piloting and _main_ship.is_piloted() and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _main_player and _main_game._transition_generation == generation and not _main_game._transition_busy and not _main_ship.is_canopy_open() and not _main_ship.supports_in_flight_cabin_access(),"duplicate airborne OFFLINE exit refuses without claim/body/camera/generation mutation"): return false
	Input.action_press(&"brake")
	for frame in 300:
		if StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE: break
		await _main_frames(1)
	_main_release_inputs()
	var capture := _main_game._get_active_landing_assist_report()
	if not _main_check(bool(capture.get("assist_capture_accepted",false)) and StringName(capture.get("selected_berth_id",&"")) == &"utopia_home_berth","normal capture selects exact own compatible home"): return false
	await _main_tap(&"landing_assist")
	for frame in 600:
		if _main_game.phase == GameFlow.Phase.SHUT_DOWN: break
		await _main_frames(1)
	var landing := _main_ship.get_landing_contract_report()
	if not _main_check(_main_game.phase == GameFlow.Phase.SHUT_DOWN and berth.get_occupant() == _main_ship and berth.get_reservation_owner() == _main_ship and _main_ship.global_position.distance_to(dock.origin) <= 0.05 and _main_ship.velocity.length() <= 0.05 and _main_ship.global_basis.is_equal_approx(dock.basis) and landing.strict_dock_acceptance and landing.contract_accepted and _main_game._ship_owns_exact_occupied_berth(_main_ship,&"utopia_home_berth") and berth.contains_oriented_bounds(_main_ship.global_transform,_main_ship.get_landing_collision_report().local_bounds),"normal L restores complete strict hull at exact own dock and current occupied lease"): return false
	_main_release_inputs()
	await _main_frames(95)
	if not _main_check(StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"landed neutral input shuts propulsion OFFLINE"): return false
	return await _main_release_at_home(identity,area)


func _main_release_at_home(identity: int, area: ShipBoardingArea) -> bool:
	await _main_tap(&"interact")
	for frame in 180:
		if not _main_game._transition_busy and not _main_player.is_seated(): break
		await _main_frames(1)
	await _main_frames(3)
	if not _main_check(not _main_game._piloting and not _main_ship.is_piloted() and not _main_player.is_seated() and _main_player.get_instance_id() == identity and _main_player.is_control_enabled() and _main_player.is_on_floor() and (_main_player.get_node("%PlayerCamera") as Camera3D).current and not _main_ship.get_camera().current and _main_player.collision_layer == _main_layer and _main_player.collision_mask == _main_mask and not (_main_player.get_node("PlayerCollision") as CollisionShape3D).disabled and not area.is_reserved() and _main_game._boarding_area == null and _main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and _main_ship.to_local(_main_player.global_position).distance_to(Vector3(0.8,0.8,-5.8)) < 0.05 and not bool(_main_player.get_cabin_containment_report().get("active",false)),"normal supported seated-open/inside release restores exact stand, walking body/control/camera and retires claim"): return false
	_main_releases += 1
	return _main_check(not area.release_reservation(_main_player),"stale released pilot claim cannot act")


func _main_walk_out(sortie: int) -> bool:
	for point in [Vector3(0.8,0.8,0),Vector3(0,0.8,0),Vector3(0,0.8,7.5),Vector3(0,0.8,8),Vector3(0,0,13.3),Vector3(-3.4,0,13.3),Vector3(-3.4,0,10.1)]:
		if not await _main_walk_to(_main_ship.to_global(point),70+sortie,true): return false
	if not _main_check(_main_game._reboard_blocked_ship == null,"physical corridor walk naturally clears unchanged7m reboard fence"): return false
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"standing Player rediscovers actual outside stern control"): return false
	await _main_tap(&"interact")
	await _main_frames(80)
	return _main_check(not _main_ship.is_canopy_open() and _main_player.is_on_floor(),"same Player physically walks out stern ramp, reaches apron and seals outside full sweep")


func _main_audit_completed_tick() -> void:
	if not _main_active or _failed: return
	if not _audit_animated_geometry(): return
	if _main_game._transition_busy or _main_player.is_seated() or not _main_player.is_control_enabled() or bool(_main_player.get("_disembarking_completion_pending")):
		_main_last_frame = -1
		_main_last_point = Vector3.INF
		return
	var frame := Engine.get_physics_frames()
	var completed: Dictionary = _main_player.get_step_up_assist_audit().get("completed_motion",{})
	var point := _main_player.global_position
	var collision := _main_player.get_node("PlayerCollision") as CollisionShape3D
	var original := collision.shape as CapsuleShape3D
	if not _main_check(_main_observer.process_physics_priority > _main_player.process_physics_priority and int(completed.get("frame",-1)) == frame and (_main_last_frame < 0 or frame == _main_last_frame+1) and (not _main_last_point.is_finite() or point.distance_to(_main_last_point) < 0.2) and _main_player.collision_layer == _main_layer and _main_player.collision_mask == _main_mask and is_equal_approx(_main_player.gravity_multiplier,_main_gravity) and Vector2(original.radius,original.height) == _main_capsule_size and collision.transform == _main_capsule_pose and not collision.disabled,"completed actual walking tick stays current/adjacent/continuous with unchanged capsule/masks/gravity",false): return
	var capsule := original.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = _main_mask
	query.exclude = [_main_player.get_rid()]
	var state := _main_player.get_world_3d().direct_space_state
	var hits := state.intersect_shape(query,16)
	var support := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.12,point-Vector3.UP*0.18,_main_mask)
	support.exclude = [_main_player.get_rid()]
	var hit := state.intersect_ray(support)
	if not _main_check(_main_player.is_on_floor() and hits.is_empty() and not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) >= cos(_main_player.floor_max_angle),"every completed walking tick has actual capsule/head clearance and physical support position="+str(point)+" overlaps="+str(hits)+" support="+str(hit),false): return
	_main_last_frame = frame
	_main_last_point = point
	_main_ticks += 1


func _main_walk_to(target: Vector3, leg: int, cabin: bool = false) -> bool:
	var reached := false
	for frame in (400 if cabin else 900):
		if _failed: return false
		var offset := target-_main_player.global_position
		offset.y = 0
		if absf(offset.x) < (0.005 if cabin else 0.02): offset.x = 0
		if absf(offset.z) < (0.005 if cabin else 0.02): offset.z = 0
		if offset.length() <= (0.01 if cabin else 0.035):
			reached = true
			break
		var direction := (_main_player.get_node("%CameraYaw") as Node3D).global_basis.inverse()*offset.normalized()
		_main_release_inputs()
		var strength := ((0.23 if offset.length() < 0.12 else (0.35 if offset.length() < 0.7 else 1.0)) if cabin else (0.4 if offset.length() < 0.8 else 1.0))
		Input.action_press(&"move_right" if direction.x > 0 else &"move_left",absf(direction.x)*strength)
		Input.action_press(&"move_back" if direction.z > 0 else &"move_forward",absf(direction.z)*strength)
		await _main_observer.completed_tick
	_main_release_inputs()
	for frame in 12: await _main_observer.completed_tick
	print("UTOPIA_MAIN_ROUTE_LEG: ",leg," target=",target," actual=",_main_player.global_position," reached=",reached)
	return _main_check(reached and (not cabin or Vector2(target.x-_main_player.global_position.x,target.z-_main_player.global_position.z).length() < 0.02),"ordinary station .035/900/12 or ramp .02/400 endpoint "+str(leg))


func _main_aim(target: Vector3) -> void:
	for frame in 180:
		var direction := (target-_main_player.get_interaction_origin()).slide(Vector3.UP).normalized()
		var forward := _main_player.get_interaction_direction().slide(Vector3.UP).normalized()
		var angle := forward.signed_angle_to(direction,Vector3.UP)
		if absf(angle) < 0.03: break
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_RIGHT_X
		motion.axis_value = -signf(angle)*(0.4 if absf(angle) < 0.25 else 1.0)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await _main_frames(1)
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_RIGHT_X
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _main_frames(2)


func _main_tap(action: StringName) -> void:
	if action == &"interact" or action == &"landing_assist":
		await _main_key(KEY_E if action == &"interact" else KEY_L)
		return
	Input.action_press(action)
	await _main_frames(2)
	Input.action_release(action)
	await _main_frames(2)

func _main_key(key: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame

func _main_release_inputs() -> void:
	for action in [&"move_forward",&"move_back",&"move_left",&"move_right",&"pitch_up",&"pitch_down",&"brake",&"sprint_boost",&"interact",&"landing_assist",&"fire"]:
		Input.action_release(action)

func _main_frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _main_check(condition: bool, message: String, verbose: bool = true) -> bool:
	if _failed: return false
	if not condition:
		_failed = true
		_main_release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		push_error("UTOPIA_MAIN_FAIL: "+message)
		quit(1)
	elif verbose: print("PASS: ",message)
	return condition

func _main_quit_normally() -> void:
	_main_release_inputs()
	await _main_key(KEY_ESCAPE)
	var exit_button := _main_game.hud.find_child("ExitButton",true,false) as Control
	for frame in 160:
		if root.gui_get_focus_owner() == exit_button: break
		await _main_key(KEY_TAB)
	if not _main_check(is_instance_valid(exit_button) and root.gui_get_focus_owner() == exit_button,"normal pause Tab reaches actual Exit to desktop"): return
	print("UTOPIA_MAIN_USER_DATA_DIR: ",OS.get_user_data_dir())
	print("UTOPIA_DROPSHIP_CREW_NORMAL_EXIT_READY" if "--crew" in OS.get_cmdline_user_args() else "UTOPIA_DROPSHIP_MAIN_TEST_OK",": claims=",_main_claims," releases=",_main_releases," walking_ticks=",_main_ticks," actual_pulse_shots=",_main_shots," elapsed_ms=",Time.get_ticks_msec()-_profile_started_ms)
	await _main_key(KEY_ENTER)
	for frame in 120: await process_frame
	_main_check(false,"normal Main Quit did not terminate actual OS process")


## Only the three exact fitted sections consume their own adopted chair space.
## All rack, aisle, other-chair and moving-leaf reservations remain strict SAT.
func _fitted_chair_consumes_reservation(section: Dictionary, reserved: Dictionary) -> bool:
	if not bool(_access_ship.get("local_passenger_chairs_fitted")): return false
	for index in 2:
		var label := "PortPassenger" if index == 0 else "StarboardPassenger"
		if reserved.name != ("future port chair" if index == 0 else "future starboard chair"): continue
		for part: String in ["Pedestal","Cushion","Back"]:
			if section.name != label+part: continue
			var bounds := _chair_part_bounds(index,part)
			return (section.bounds as AABB).is_equal_approx(bounds) and bounds.position.x >= (1.54 if index == 1 else -2.46)-0.00001 \
				and bounds.end.x <= (2.46 if index == 1 else -1.54)+0.00001
	return false


func _chair_part_bounds(index: int, part: String) -> AABB:
	var point: Vector3 = UtopiaDropship.CREW_POSITIONS[index]
	var low := Vector3(-0.28,0,-0.20)
	var high := Vector3(0.28,0.54,0.26)
	if part == "Cushion":
		low = Vector3(-0.46,0.54,-0.25)
		high = Vector3(0.46,0.68,0.42)
	elif part == "Back":
		low = Vector3(-0.46,0.68,0.42)
		high = Vector3(0.46,1.62,0.58)
	return AABB(point+low,high-low)


func _main_crew_journey(identity: int, spawn: Vector3, area: ShipBoardingArea) -> void:
	var frame := _main_ship.call("get_interior_frame") as MovingInteriorFrame
	var ship_pose := _main_ship.global_transform
	var seat := _main_ship.get_node("passenger_port_00/SoloPassengerSeatInteraction") as ShipCrewSeat
	var generation := _main_game._transition_generation
	_main_game._sit_in_solo_crew_seat(seat)
	if not _main_check(not _main_player.is_seated() and not area.is_reserved() and _main_game._transition_generation == generation and not _main_ship.supports_in_flight_cabin_access(),"closed/unreachable actual Main chair refuses before claim, frame, body or transition"): return
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"crew journey discovers actual reachable stern control"): return
	await _main_tap(&"interact")
	await _main_frames(80)
	if not _main_check(_main_ship.call("is_local_chair_access_supported") and not frame.auto_register_from_volume and frame.get_occupant_volume() == null and frame.get_interior_bounds() == UtopiaDropship.LOCAL_CABIN and not frame.is_occupant_registered(_main_player),"exact occupied home opens local-only manual chair frame with no sensor/travel grant"): return
	# Open but still on the apron: no direct path or reachable chair exists.
	_main_game._sit_in_solo_crew_seat(seat)
	if not _main_check(not _main_player.is_seated() and not area.is_reserved() and _main_game._transition_generation == generation,"open unreachable chair still refuses without authority theft"): return
	for point in [Vector3(-3.4,0,13.3),Vector3(0,0,13.3),Vector3(0,0.8,8),Vector3(0,0.8,7.5),Vector3(0,0.8,0),Vector3(0,0.8,-3.6)]:
		if not await _main_walk_to(_main_ship.to_global(point),210,true): return
	if not _crew_authority_refusals(): return
	for index in 2:
		seat = _main_ship.get_node(String(UtopiaDropship.CREW_IDS[index])+"/SoloPassengerSeatInteraction") as ShipCrewSeat
		var anchor := seat.get_seat_anchor()
		var stand: Vector3 = UtopiaDropship.CREW_STANDS[index]
		for point in [Vector3(0,0.8,-3.6),stand]:
			if not await _main_walk_to(_main_ship.to_global(point),220+index,true): return
		for cycle in 2:
			await _main_aim(seat.global_position)
			if not _main_check(_main_game.station_interaction_candidate == seat and anchor.position == UtopiaDropship.CREW_POSITIONS[index] and _main_ship.to_local(seat.get_exit_transform().origin).is_equal_approx(stand),"normal look finds exact fixed real passenger chair index="+str(index)+" cycle="+str(cycle)): return
			_crew_print_handoff_state("before_E",seat)
			await _main_tap(&"interact")
			for tick in 180:
				if _main_game._station_seated and not _main_game._transition_busy: break
				await _main_frames(1)
			var owner := _main_ship.call("get_crew_role_authority") as CrewSeatRoleAuthority
			_crew_print_handoff_state("after_E",seat)
			if not _main_check(owner != null and _main_game._solo_crew_authority == owner and _main_game._solo_crew_claim_is_current() and _main_player.is_station_seated() and _main_player.is_seated_at(anchor) and not _main_game._piloting and not _main_ship.is_piloted() and frame.is_occupant_registered(_main_player) and (_main_player.get_node("%PlayerCamera") as Camera3D).current and not _main_ship.get_camera().current and _crew_seated_geometry(index),"ordinary E seats same actual Player with matching ledger/frame/camera and live suit/cushion/eye proof"): return
			var assignment := owner.get_assignment(1,GameFlow.SOLO_CREW_AVATAR_ID)
			var snapshot := owner.get_snapshot()
			var pose := _main_player.global_transform
			if not _main_check(assignment.seat_id == UtopiaDropship.CREW_IDS[index] and assignment.role == &"passenger" and assignment.anchor_id == assignment.seat_id and assignment.frame_id == UtopiaDropship.CREW_FRAME_ID and assignment.seat_generation == 1 and owner.authorize_action(1,GameFlow.SOLO_CREW_AVATAR_ID,CrewSeatRoleAuthority.CAPABILITY_PASSENGER_ACCESS).accepted and not owner.authorize_action(1,GameFlow.SOLO_CREW_AVATAR_ID,CrewSeatRoleAuthority.CAPABILITY_SHIP_COMMAND).accepted and not owner.authorize_action(1,GameFlow.SOLO_CREW_AVATAR_ID,CrewSeatRoleAuthority.CAPABILITY_WEAPON_CONTROL).accepted and not owner.authorize_action(1,GameFlow.SOLO_CREW_AVATAR_ID,CrewSeatRoleAuthority.CAPABILITY_SYSTEMS_CONTROL).accepted,"two passenger capability identities; no helm/fire/repair grant"): return
			_main_ship.set_canopy_open(false)
			_main_ship.request_engine_start()
			Input.action_press(&"move_forward")
			Input.action_press(&"fire")
			await _main_frames(20)
			_main_release_inputs()
			if not _main_check(_main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and _main_ship.global_transform.is_equal_approx(ship_pose) and _main_ship.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE and _main_shots == 0 and owner.get_snapshot() == snapshot and _main_player.global_transform.is_equal_approx(pose) and _main_game._solo_crew_claim_is_current(),"occupied local chair refuses hatch closure/start and passenger drive/fire without claim/body drift"): return
			if index == 0 and cycle == 0:
				var blocker := StaticBody3D.new()
				blocker.collision_layer = PhysicsLayers.SHIP
				var collision := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.5,1,0.5)
				collision.shape = box
				blocker.add_child(collision)
				_main_game.add_child(blocker)
				blocker.global_position = seat.get_exit_transform().origin+Vector3.UP
				await _main_frames(2)
				await _main_tap(&"interact")
				if not _main_check(_main_game._station_seated and not _main_game._transition_busy and _main_game._solo_crew_claim_is_current() and _main_player.global_transform.is_equal_approx(pose) and owner.get_snapshot() == snapshot and frame.is_occupant_registered(_main_player),"blocked actual stand refuses atomically with seated body/claim/containment retained"): return
				blocker.queue_free()
				await _main_frames(2)
			await _main_tap(&"interact")
			for tick in 180:
				if not _main_player.is_seated() and not _main_game._transition_busy: break
				await _main_frames(1)
			await _main_frames(3)
			if not _main_check(_main_player.get_instance_id() == identity and _main_player.is_on_floor() and not _main_player.is_seated() and _main_player.is_control_enabled() and _main_ship.to_local(_main_player.global_position).distance_to(stand) < 0.05 and _main_game._cabin_ship == null and _main_game._boarding_area == null and _main_game._solo_crew_authority == null and _main_ship.call("get_crew_role_authority") == null and not area.is_reserved() and not frame.is_occupant_registered(_main_player) and not bool(_main_player.get_cabin_containment_report().get("active",false)) and _main_player.collision_layer == _main_layer and _main_player.collision_mask == _main_mask and not (_main_player.get_node("PlayerCollision") as CollisionShape3D).disabled and not _main_player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META),"ordinary E restores exact supported stand/body/masks/control and retires local claim/reservation/frame/containment"): return
			print("UTOPIA_CREW_CYCLE_OK: chair=",index," cycle=",cycle)
	if not await _main_walk_out(9): return
	for index in range(MAIN_STATION_ROUTE.size()-2,-1,-1):
		if not await _main_walk_to(MAIN_STATION_ROUTE[index],300+index): return
	if not await _main_walk_to(spawn,399): return
	if not _main_check(_main_player.get_instance_id() == identity and _main_player.is_on_floor() and _main_player.global_position.distance_to(spawn) < 0.12 and _main_ship.global_transform.is_equal_approx(ship_pose) and not _main_ship.supports_in_flight_cabin_access() and _main_ticks > 1000,"same actual Player full reverse station route returns to original spawn; local chair fitout grants no travel"): return
	print("UTOPIA_DROPSHIP_CREW_TEST_OK: chairs=2 cycles_each=2 walking_ticks=",_main_ticks," elapsed_ms=",Time.get_ticks_msec()-_profile_started_ms)
	await _main_quit_normally()


## Isolated ledger negatives are explicitly supplementary, never ordinary
## journey evidence. The actual Player acquires every claim through normal E.
func _crew_authority_refusals() -> bool:
	var owner := CrewSeatRoleAuthority.new(1)
	if not _main_check((_main_ship.call("register_crew_seat_roster",owner) as Dictionary).accepted,"existing authority seals exact three-row Utopia roster"): return false
	if not _main_check(owner.claim(1,2,&"fixture_port",UtopiaDropship.CREW_IDS[0],&"passenger",1).accepted and owner.claim(1,3,&"fixture_starboard",UtopiaDropship.CREW_IDS[1],&"passenger",1).accepted,"supplementary existing ledger holds two distinct underlying passenger claims"): return false
	var snapshot := owner.get_snapshot()
	return _main_check(not owner.claim(1,4,&"fixture_third",UtopiaDropship.CREW_IDS[0],&"passenger",1).accepted and not owner.claim(1,2,&"fixture_port",UtopiaDropship.CREW_IDS[1],&"passenger",2).accepted and not owner.claim(1,4,&"fixture_third",&"passenger_third",&"passenger",2).accepted and not owner.release(1,2,&"fixture_port",UtopiaDropship.CREW_IDS[0],1,1).accepted and not owner.release(1,2,&"fixture_port",UtopiaDropship.CREW_IDS[0],2,2).accepted and not owner.claim(2,4,&"fixture_foreign",&"pilot_station",&"pilot",1).accepted and owner.get_snapshot() == snapshot,"third/duplicate/unknown/stale-generation/stale-sequence/foreign claims refuse without ledger mutation")


func _crew_seated_geometry(index: int) -> bool:
	var presentation := _main_player.get_node("%PilotSkinnedPresentation") as PilotSkinnedPresentation
	var skeleton := presentation.get_skeleton()
	var cushion := _chair_part_bounds(index,"Cushion")
	var support_gap := INF
	var vertices_checked := 0
	for mesh: MeshInstance3D in presentation.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			for vertex_index in vertices.size():
				var world := mesh.global_transform*vertices[vertex_index]
				if mesh.skin != null and not weights.is_empty():
					var skinned := Vector3.ZERO
					for influence in 4:
						var offset := vertex_index*4+influence
						if weights[offset] <= 0: continue
						var bind := bones[offset]
						var bone := skeleton.find_bone(mesh.skin.get_bind_name(bind))
						if bone < 0: bone = mesh.skin.get_bind_bone(bind)
						skinned += (skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*vertices[vertex_index])*weights[offset]
					world = skeleton.global_transform*skinned
				var point := _main_ship.to_local(world)
				vertices_checked += 1
				for chair in 2:
					for part: String in ["Pedestal","Cushion","Back"]:
						if _chair_part_bounds(chair,part).grow(-0.002).has_point(point):
							return _main_check(false,"actual animated suit/backpack vertex penetrates fitted "+part+" point="+str(point))
				if point.x >= cushion.position.x and point.x <= cushion.end.x and point.z >= cushion.position.z and point.z <= cushion.end.z:
					support_gap = minf(support_gap,point.y-cushion.end.y)
	var query := PhysicsShapeQueryParameters3D.new()
	var eye := SphereShape3D.new()
	eye.radius = 0.08
	query.shape = eye
	query.transform = (_main_player.get_node("%PlayerCamera") as Camera3D).global_transform
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [_main_player.get_rid()]
	var camera_clear := _main_ship.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty()
	var head := skeleton.find_bone("head")
	query.transform.origin = skeleton.global_transform*skeleton.get_bone_global_pose(head).origin
	var head_clear := _main_ship.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty()
	print("UTOPIA_CREW_BODY: chair=",index," live_vertices=",vertices_checked," cushion_gap=",support_gap," camera_clear=",camera_clear," head_clear=",head_clear)
	return vertices_checked > 500 and support_gap >= -0.002 and support_gap <= 0.04 and camera_clear and head_clear


func _main_fitted_chair_geometry() -> bool:
	for index in 2:
		var label := "PortPassenger" if index == 0 else "StarboardPassenger"
		for part: String in ["Pedestal","Cushion","Back"]:
			var collision := _main_ship.get_node(label+part+"Collision") as CollisionShape3D
			var mesh := _main_ship.get_node("UtopiaOriginalShell/"+label+part) as MeshInstance3D
			var expected := _chair_part_bounds(index,part)
			var points := PackedVector3Array()
			for point: Vector3 in (collision.shape as ConvexPolygonShape3D).points:
				points.append(collision.transform*point)
			var bounds := AABB(points[0],Vector3.ZERO)
			for point in points: bounds = bounds.expand(point)
			if not _main_check(not collision.disabled and mesh.visible and bounds.is_equal_approx(expected) and points.size() == 8 and collision.global_transform.is_equal_approx(mesh.global_transform),"exact fitted convex and visible "+label+part+" preserve adopted chair/aisle footprint"): return false
			var visible_points := PackedVector3Array()
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: visible_points.append(mesh.transform*point)
			for point in points:
				if not _main_check(_has_point(visible_points,point),"fitted chair collider corner belongs to actual visible mesh",false): return false
			for point in visible_points:
				if not _main_check(_has_point(points,point),"fitted chair visible geometry belongs to actual solid",false): return false
	return true


func _crew_print_handoff_state(edge: String, seat: ShipCrewSeat) -> void:
	var frame := _main_ship.call("get_interior_frame") as MovingInteriorFrame
	var owner := _main_ship.call("get_crew_role_authority") as CrewSeatRoleAuthority
	var area := _main_ship.get_node("ShipBoardingArea") as ShipBoardingArea
	var contract := seat.get_role_contract()
	var cabin := _main_ship.get_in_flight_cabin_report()
	var collision := _main_player.get_node("PlayerCollision") as CollisionShape3D
	var support := PhysicsRayQueryParameters3D.create(_main_player.global_position+Vector3.UP*0.2,_main_player.global_position-Vector3.UP*0.25,PhysicsLayers.WORLD|PhysicsLayers.SHIP,[_main_player.get_rid()])
	var hit := _main_player.get_world_3d().direct_space_state.intersect_ray(support)
	print("UTOPIA_CREW_HANDOFF: ",edge," state=",{
		"phase":_main_game.phase,"transition_busy":_main_game._transition_busy,
		"generation":_main_game._transition_generation,"station_seated":_main_game._station_seated,
		"piloting":_main_game._piloting,"ship_piloted":_main_ship.is_piloted(),
		"candidate":_main_game.station_interaction_candidate,"seat":seat,
		"seat_contract":contract,"ship_boardable":_main_ship.is_boardable(),
		"local_supported":_main_ship.call("is_local_chair_access_supported"),
		"cabin_report":cabin,"safe_cabin":_main_game._solo_safe_recovery_cabin(_main_ship),
		"area_available":area.is_available_for(_main_player),"area_reserved":area.is_reserved(),
		"area_token":area.get_reservation_token(),"game_area":_main_game._boarding_area,
		"reach":_main_player.get_interaction_origin().distance_to(seat.global_position),
		"max_reach":GameFlow.STATION_SEAT_MAX_REACH,"on_floor":_main_player.is_on_floor(),
		"local_feet":_main_ship.to_local(_main_player.global_position),
		"bounds_contains_feet":(cabin.get("local_bounds",AABB()) as AABB).has_point(_main_ship.to_local(_main_player.global_position)),
		"foot_support":hit,"player_seated":_main_player.is_seated(),
		"player_station_seated":_main_player.is_station_seated(),
		"player_seated_at_anchor":_main_player.is_seated_at(seat.get_seat_anchor()),
		"player_control":_main_player.is_control_enabled(),"body_disabled":collision.disabled,
		"body_layer":_main_player.collision_layer,"body_mask":_main_player.collision_mask,
		"owner":owner,"game_owner":_main_game._solo_crew_authority,
		"owner_snapshot":owner.get_snapshot() if owner != null else {},
		"current_claim":_main_game._solo_crew_claim_is_current(),
		"game_seat":_main_game._solo_crew_seat,"game_seat_id":_main_game._solo_crew_seat_id,
		"game_role":_main_game._solo_crew_role,"game_seat_generation":_main_game._solo_crew_seat_generation,
		"game_ship":_main_game._solo_crew_ship,"game_cabin_ship":_main_game._cabin_ship,
		"frame_registered":frame.is_occupant_registered(_main_player),
		"frame_owner_meta":_main_player.get_meta(MovingInteriorFrame.OWNER_META) if _main_player.has_meta(MovingInteriorFrame.OWNER_META) else null,
		"frame_registration_meta":_main_player.get_meta(MovingInteriorFrame.REGISTRATION_META) if _main_player.has_meta(MovingInteriorFrame.REGISTRATION_META) else null,
		"role_meta":_main_player.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META,{}),
		"containment":_main_player.get_cabin_containment_report(),
		"player_camera_current":(_main_player.get_node("%PlayerCamera") as Camera3D).current,
		"ship_camera_current":_main_ship.get_camera().current})
