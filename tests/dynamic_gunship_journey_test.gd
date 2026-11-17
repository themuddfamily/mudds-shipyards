extends SceneTree

## Standalone physical access only. Foundation/controller/weapon proof remains
## in fleet_candidate_foundation_test. Production-only preloads permit the
## exact same fixture to execute against the real exported Windows PCK.
## One initial fixture/player placement; ordinary input and public handoffs
## thereafter, with no pose/velocity/engine-clock mutation or player bypass.
const DYNAMIC := preload("res://scenes/ships/dynamic_gunship.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
var _checks := 0
var _failed := false
var _static_sections: Array[Dictionary] = []
var _motion_samples := 0

class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake}

func _init() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		if _failed:
			return

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition:
		return true
	if not _failed:
		_failed = true
		push_error("DYNAMIC_ACCESS_FAIL: " + label)
		_release_inputs()
		Input.action_release("interact")
		Input.action_release("jump")
		Input.action_release("sprint_boost")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		quit(1)
	return false

class AccessObserver:
	extends Node
	var suite: SceneTree
	func _physics_process(_delta: float) -> void:
		suite.call("_audit_walking_tick")
	func _process(_delta: float) -> void:
		if Input.is_action_just_pressed("interact"):
			suite.call("_seated_interact")

var _access_ship: HeroShip
var _access_player: PlayerController
var _access_commands: FixtureCommands
var _access_area: ShipBoardingArea
var _access_hatch: ShipCabinHatch
var _access_observer: AccessObserver
var _access_busy := false
var _walking_audits := 0
var _previous_audit := -1
var _was_walking := false
var _walking_layer := 0
var _walking_mask := 0
var _walking_gravity := 0.0
var _release_count := 0
var _claim_count := 0
var _walking_transition_pending := false
var _pending_restore_ticks := 0


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
	box.size = Vector3(24,0.5,20)
	slab.shape = box
	slab.position.y = -0.25
	deck.add_child(slab)
	_access_ship = DYNAMIC.instantiate()
	fixture.add_child(_access_ship)
	_access_commands = FixtureCommands.new()
	_access_ship.add_child(_access_commands)
	_access_ship.set_command_source(_access_commands)
	_access_player = PLAYER.instantiate()
	_access_player.transform = Transform3D(Basis.IDENTITY,Vector3(-7,0,0))
	fixture.add_child(_access_player)
	_walking_layer = _access_player.collision_layer
	_walking_mask = _access_player.collision_mask
	_walking_gravity = _access_player.gravity_multiplier
	_access_area = _access_ship.get_node("ShipBoardingArea")
	_access_hatch = _access_ship.get_node("CabinHatchInteraction")
	_access_player.interact_requested.connect(_on_access_interact)
	_access_observer = AccessObserver.new()
	_access_observer.suite = self
	_access_observer.process_physics_priority = 1000000
	root.add_child(_access_observer)
	await _frames(8)
	if not _check(_access_ship.call("is_access_supported"), "real deck supports hull, ramp tip and operator"):
		return
	if not _trajectory_contract():
		return
	# Closed crossing uses the same body and ordinary held input, then walks
	# back to the apron; no actor reset or hidden fixture placement follows.
	await _drive_for(Vector3.RIGHT,100)
	var closed_local := _access_ship.to_local(_access_player.global_position)
	if not _check(closed_local.x < -1.88, "sealed real capsule cannot cross port wall: " + str(closed_local)):
		return
	await _walk_to(Vector3(-7,0,0))
	for cycle in 2:
		await _walk_to(Vector3(-5.9,0,-2.4))
		if _failed:
			return
		if not _check(_access_player.get_nearby_interactables().has(_access_hatch), "real proximity discovers reachable hatch control"):
			return
		await _interact_edge()
		await _frames(26)
		if not _check(_access_ship.is_canopy_open() and not _access_ship.call("is_access_motion_active"), "on-foot Interact opened full ramp/canopy"):
			return
		_access_ship.request_engine_start()
		_access_commands.throttle = 1
		await _frames(3)
		_access_commands.throttle = 0
		if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and _access_ship.velocity.length() < 0.001, "open launch/start refuses"):
			return
		await _walk_to(Vector3(-5.9,0,0))
		await _walk_to(Vector3(-0.9,0.55,0.4))
		if _failed:
			return
		await _interact_edge()
		await _frames(110)
		if not _check(_claim_count == cycle + 1 and _access_player.is_seated_at(_access_ship.get_pilot_seat_anchor()) and _access_area.get_reservation_token() == _access_player and _access_ship.is_piloted() and not _access_ship.is_canopy_open(), "actual exclusive Player seating and normal sealed handoff"):
			return
		var foreign := RefCounted.new()
		if not _check(not _access_area.try_reserve(foreign) and not _access_area.release_reservation(foreign) and _access_area.get_reservation_token() == _access_player, "foreign/duplicate claim cannot steal current seat"):
			return
		var eye := _access_ship.get_node("CockpitCamera") as Camera3D
		if not _check(_access_player.global_position.distance_to(_access_ship.get_pilot_seat_anchor().global_position) < 0.001 and eye.position == Vector3(0,2.26,-1.05) and eye.current, "actual seated anchor and active exact cockpit eye"):
			return
		_access_ship.request_engine_start()
		await _frames(120)
		if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "ordinary sealed start retains 2.1s clock"):
			return
		await _frames(7)
		if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "real startup completes after 2.1s"):
			return
		_access_ship.set_canopy_open(true)
		await _interact_edge()
		if not _check(not _access_ship.is_canopy_open() and _access_player.is_seated(), "active opening and active pilot release refuse"):
			return
		await _frames(100)
		if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE, "neutral landed engine becomes OFFLINE"):
			return
		await _interact_edge()
		await _frames(85)
		if not _check(_release_count == cycle + 1 and not _access_player.is_seated() and not _access_area.is_reserved() and not _access_ship.is_piloted(), "normal supported release restores walking body and retires claim"):
			return
		if not _check(not _access_area.release_reservation(_access_player), "stale released claim cannot act"):
			return
		await _walk_to(Vector3(-5.9,0,0))
		await _walk_to(Vector3(-5.9,0,-2.4))
		await _interact_edge()
		await _frames(26)
		if not _check(not _access_ship.is_canopy_open(), "outside physical Interact seals access again"):
			return
		await _walk_to(Vector3(-7,0,0))
	# Final real-command airborne/OFFLINE negative follows the complete two
	# positive cycles, avoiding any actor/hull reset to set up another case.
	await _walk_to(Vector3(-5.9,0,-2.4))
	await _interact_edge()
	await _frames(26)
	await _walk_to(Vector3(-5.9,0,0))
	await _walk_to(Vector3(-0.9,0.55,0.4))
	await _interact_edge()
	await _frames(110)
	_access_commands.throttle = 0.5
	await _frames(240)
	_access_commands.throttle = 0
	_access_commands.brake = true
	await _frames(180)
	_access_commands.brake = false
	await _frames(100)
	if not _check(not _access_ship.get_telemetry().landed and _access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE, "real commands establish final airborne OFFLINE state"):
		return
	_access_ship.set_canopy_open(true)
	await _interact_edge()
	if not _check(not _access_ship.is_canopy_open() and _access_player.is_seated() and _access_area.get_reservation_token() == _access_player and not _access_ship.supports_in_flight_cabin_access(), "unsupported opening/airborne exit refuses without free cabin"):
		return
	_release_inputs()
	Input.action_release("interact")
	Input.action_release("jump")
	Input.action_release("sprint_boost")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_access_observer.queue_free()
	fixture.queue_free()
	await _frames(3)
	print("DYNAMIC_GUNSHIP_ACCESS_TEST_OK: checks=",_checks," walking_ticks=",_walking_audits," claims=",_claim_count," releases=",_release_count," pending_restore_ticks=",_pending_restore_ticks," geometry_ticks=",_motion_samples," transformed=", "--transformed" in OS.get_cmdline_user_args())
	quit(0)


func _on_access_interact() -> void:
	if _access_busy or _failed:
		return
	var local := _access_ship.to_local(_access_player.global_position)
	if local.distance_to(Vector3(-0.9,0.55,0.4)) < 0.16 and _access_player.get_nearby_interactables().has(_access_area):
		if not _access_area.try_reserve(_access_player):
			return
		var foreign := RefCounted.new()
		if not _check(_access_area.try_reserve(_access_player) and not _access_area.try_reserve(foreign) and not _access_area.release_reservation(foreign) and _access_area.get_reservation_token() == _access_player,"same live claim is idempotent and foreign claimant cannot steal it"):
			return
		_access_busy = true
		_walking_transition_pending = true
		if not _access_player.begin_boarding(_access_ship.get_boarding_entry_transform(),_access_ship.get_pilot_seat_anchor(),1.1,_access_ship):
			_check(false,"public Player boarding accepted at reached helm")
			return
		await _access_player.boarding_completed
		_access_ship.set_command_source(_access_commands)
		_access_ship.set_piloted(true)
		_access_ship.set_cockpit_view(true)
		_access_ship.set_canopy_open(false,0.35)
		_access_commands.throttle = 1
		_access_ship.request_engine_start()
		await _frames(2)
		_check(_access_ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and _access_ship.velocity.length() < 0.001,"current reserved pilot open/moving throttle and start refuse")
		_access_commands.throttle = 0
		await _access_ship.canopy_motion_finished
		_claim_count += 1
		_access_busy = false
	elif _access_player.get_nearby_interactables().has(_access_hatch):
		_check(_access_hatch.interact(_access_player),"discovered hatch accepts real Player Interact")


func _seated_interact() -> void:
	if _access_busy or _failed or not is_instance_valid(_access_player) or not _access_player.is_seated():
		return
	if not _access_ship.call("is_access_supported") or _access_area.get_reservation_token() != _access_player:
		return
	_access_busy = true
	_access_ship.set_canopy_open(true,0.35)
	await _access_ship.canopy_motion_finished
	if not _access_player.begin_disembark(_access_ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-0.9,0.55,0.4)),0.9,_access_ship):
		_check(false,"normal Player disembark accepted")
		return
	await _access_player.disembarking_completed
	_walking_transition_pending = false
	_access_ship.set_piloted(false)
	_access_ship.set_command_source(null)
	_check(_access_area.release_reservation(_access_player),"current claim retires after real disembark")
	_access_player.set_control_enabled(true)
	_access_player.set_camera_active(true)
	_release_count += 1
	_access_busy = false


func _audit_walking_tick() -> void:
	if _failed or not is_instance_valid(_access_player):
		return
	if not _audit_animated_geometry():
		return
	var current := Engine.get_physics_frames()
	var walking: bool = _access_player.get("_embodiment_state") == PlayerController.EmbodimentState.ON_FOOT
	if walking and _walking_transition_pending:
		# Player has published its internal ON_FOOT pose while its public
		# completion still owns deferred collision restoration. This is
		# transition time; no walking tick can start until that signal.
		_pending_restore_ticks += 1
		_was_walking = false
		return
	if not walking:
		_was_walking = false
		return
	var start: Vector3 = _access_player.get("_completed_motion_start")
	var end: Vector3 = _access_player.get("_completed_motion_end")
	if not _check(int(_access_player.get("_completed_motion_frame")) == current and (not _was_walking or current == _previous_audit + 1) and start.distance_to(end) < 0.2, "adjacent completed Player tick continuity frame=" + str(current)):
		return
	_previous_audit = current
	_was_walking = true
	_walking_audits += 1
	var actual := _access_player.get_node("PlayerCollision") as CollisionShape3D
	var shape := actual.shape.duplicate() as CapsuleShape3D
	shape.radius -= 0.005
	shape.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = actual.global_transform
	query.collision_mask = _walking_mask
	query.exclude = [_access_player.get_rid()]
	query.margin = 0
	var hits := _access_player.get_world_3d().direct_space_state.intersect_shape(query)
	var support := PhysicsRayQueryParameters3D.create(end+Vector3.UP*0.12,end-Vector3.UP*0.18,_walking_mask)
	support.exclude = [_access_player.get_rid()]
	var hit := _access_player.get_world_3d().direct_space_state.intersect_ray(support)
	_check(_access_player.collision_layer == _walking_layer and _access_player.collision_mask == _walking_mask and _access_player.gravity_multiplier == _walking_gravity and not actual.disabled and hits.is_empty() and not hit.is_empty() and _access_player.is_on_floor() and (hit.normal as Vector3).dot(Vector3.UP) >= cos(_access_player.floor_max_angle), "every walking tick retains full actual capsule/head clearance/support/masks/gravity frame=" + str(current) + " position=" + str(end) + " hits=" + str(hits) + " support=" + str(hit))


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
		var mesh := _access_ship.get_node("DynamicOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
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
	return point.is_finite() and point.x >= (-4.50001 if closed else -5.20001) and point.x <= 4.50001 and point.y >= -0.00001 and point.y <= (3.60001 if closed else 5.30001) and absf(point.z) <= 5.00001


func _trajectory_contract() -> bool:
	_prime_static_sections()
	var leaves: Array = _access_ship.get("_access_leaves")
	if not _check(leaves.size() == 5,"exact two ramp leaves, sill, hinged side and hinged roof"):
		return false
	# Every stage boundary, plus hundredths across each rigid translation and
	# hinge arc. The authored hinge formula reaches its maximum at the open
	# front/top corner:3.4+4.24*sin(theta)+.2*cos(theta)=5.3.
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
		if not String(leaf.mesh.name).begins_with("PortRamp"):
			continue
		var points: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,1.0)
		for point in points:
			full_ramp = AABB(point,Vector3.ZERO) if first else full_ramp.expand(point)
			first = false
	if not _check(full_ramp.is_equal_approx(AABB(Vector3(-5.2,0,-1),Vector3(3.7,0.55,2))),"exact adopted deployed ramp footprint and top height"):
		return false
	print("DYNAMIC_ACCESS_TRAJECTORY:101 fractions, rigid hinges/staged translations, strict closed/deployed bounds and moving/static SAT separation")
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
		clearance.size = Vector3(0.12,2.3,2.0)
		query.shape = clearance
		query.transform = _access_ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-1.5,1.701,0))
		query.collision_mask = PhysicsLayers.SHIP
		query.margin = 0
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual deployed aperture >=2m wide x2.3m high"):
			return false
		clearance.size = Vector3(1.2,2.3,3.998)
		query.transform = _access_ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-0.9,1.701,0))
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual supported1.2m aisle beside physical chair"):
			return false
	if _access_player.is_seated():
		var query := PhysicsShapeQueryParameters3D.new()
		var eye := SphereShape3D.new()
		eye.radius = 0.1
		query.shape = eye
		query.transform = (_access_ship.get_node("CockpitCamera") as Camera3D).global_transform
		query.collision_mask = PhysicsLayers.SHIP
		query.margin = 0
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual seated eye remains clear through canopy motion"):
			return false
	return true
