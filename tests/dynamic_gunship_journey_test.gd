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
	if "--main" in OS.get_cmdline_user_args():
		await _run_main()
		return
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


# Actual Boot/Main mode composes no custom boarding coordinator or command
# source. Every transition and flight action comes through real production input.
const BOOT := preload("res://scenes/boot.tscn")
const MAIN_STATION_ROUTE := [
	Vector3(8,0,11),Vector3(8,0,13.5),Vector3(35,0,13.5),
	Vector3(35,0,15.5),Vector3(43,0,15.5),Vector3(43,-0.02,7),
	Vector3(43,-0.02,-12),Vector3(55,-0.02,-12),Vector3(55,-0.02,-44),
	Vector3(99.6,-0.02,-44),Vector3(99.6,-0.02,-30),
	Vector3(101,-0.02,-30),Vector3(102.1,-0.02,-32.4),
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
	_main_ship = _main_game.get_node("DynamicGunship") as HeroShip
	# Reuse the access fixture's actual animated render/collider audit only;
	# no standalone access coordinator is installed in this mode.
	_access_ship = _main_ship
	_access_player = _main_player
	_main_ship.engine_state_changed.connect(func(state: StringName): _main_engine_edges.append({"state":state,"tick":Engine.get_physics_frames(),"remaining":_main_ship.get("_engine_timer")}))
	_main_ship.projectile_fired.connect(func(_origin: Vector3,_direction: Vector3): _main_projectiles += 1)
	_main_game.get_combat_authority().authoritative_shot_submitted.connect(func(request: Variant,_result: Dictionary):
		if request.source_entity == _main_ship:
			_main_shots += 1
			_main_bad_shot = _main_bad_shot or request.source_id != 1112 or request.weapon_id != GameFlow.BULWARK_COMBAT_WEAPON_ID or request.range != 360 or request.damage != 50 or _main_ship.to_local(request.origin).distance_to(Vector3(0,0.9,-4.9)) > 0.0001)
	var identity := _main_player.get_instance_id()
	var world := _main_game.world
	var berth := world.get_berth_node(&"dynamic_home_berth") as ShipBerth
	var dock := berth.get_dock_transform()
	if not _main_check(_main_game.phase == GameFlow.Phase.APPROACH_SHIP and _main_player.is_control_enabled() and _main_player.global_position.distance_to(world.get_player_spawn().origin) < 0.25 and _main_game.get_flyable_ships().size() == 15 and world.get_berth_ids().size() == 15 and berth.get_occupant() == _main_ship and berth.get_reservation_owner() == _main_ship and _main_ship.global_transform.is_equal_approx(dock),"actual normal Main spawn, fifteen flyables and exact occupied Dynamic home"): return
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
	var profile := _main_game.get_combat_authority().get_weapon_profile(_main_ship,GameFlow.BULWARK_COMBAT_WEAPON_ID)
	if not _main_check(profiles.size() == 1 and profiles.has(GameFlow.BULWARK_COMBAT_WEAPON_ID) and profile == profiles[GameFlow.BULWARK_COMBAT_WEAPON_ID] and profile.get("range") == 360 and profile.get("damage") == 50 and is_equal_approx(_main_ship.weapon_cooldown,0.3) and _main_game.get_combat_authority().get_source_id(_main_ship) == 1112 and (_main_ship.get_node("AuthoritativeDamageable") as LifecycleDamageableAdapter).get_target_entity() == _main_ship and not _main_ship.has_node("MovingInteriorFrame") and not _main_ship.has_method("get_passenger_station_role_contract"),"actual unique Dynamic source1112 binds only unchanged50/360/.30 pilot pulse, no crew/guest/cabin grant"): return
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
	for index in MAIN_STATION_ROUTE.size():
		if not await _main_walk_to(MAIN_STATION_ROUTE[index],index): return
	for sortie in 2:
		if not await _main_board_from_port(sortie,identity,area): return
		if not await _main_sortie_home(sortie,identity,area,berth,dock): return
		if not await _main_walk_out(sortie): return
	# A fresh physical third claim proves that the second exit did not strand
	# the body, reservation, camera, input bank or the generic reboard fence.
	if not await _main_board_from_port(2,identity,area): return
	if not _main_check(_main_claims == 3 and _main_releases == 2 and _main_ticks > 1000 and _main_player.get_instance_id() == identity and _main_game.active_ship == _main_ship and _main_game._piloting and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()),"two complete ordinary sorties/exits and fresh third physical claim retain same Player"): return
	for craft: HeroShip in old_poses:
		if not _main_check(craft.global_transform.is_equal_approx(old_poses[craft]) and _main_game.get_combat_authority().get_source_id(craft) == old_sources[craft] and [craft.mouse_sensitivity,craft.invert_mouse_y,craft.get_camera().fov,craft.maximum_chase_camera_rotation_lag_degrees] == old_settings[craft],"all fourteen old craft poses/source IDs/settings preserved "+String(craft.name)): return
	for home: ShipBerth in old_leases:
		var saved: Dictionary = old_leases[home]
		if not _main_check(home.audit() == saved.audit and home.get_reservation_owner() == saved.owner and home.get_occupant() == saved.occupant and home.get_reservation_token(saved.owner) == saved.token and home.get_dock_transform().is_equal_approx(saved.pose) and home.landing_volume_center == old_centers[home],"all fourteen old berth poses/centers/owners/occupants/tokens preserved "+str(home.get_berth_id())): return
	if not _main_check(not _main_bad_shot and _main_shots >= 2 and _main_projectiles == _main_shots,"both usable flights emit only real center-muzzle approved pulse with unique source"): return
	await _main_quit_normally()


func _main_board_from_port(sortie: int, identity: int, area: ShipBoardingArea) -> bool:
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"normal look discovers reachable physical port control"): return false
	await _main_tap(&"interact")
	_main_ship.request_engine_start() # Negative moving/open startup probe only.
	if not _main_check(StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"moving access refuses engine start"): return false
	await _main_frames(45)
	_main_ship.request_engine_start()
	if not _main_check(_main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"full open access refuses startup"): return false
	var generation := _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(not area.is_reserved() and _main_game._transition_generation == generation,"open access outside actual helm still refuses direct boarding"): return false
	for point in [Vector3(-5.9,0,0),Vector3(-0.9,0.55,0.4)]:
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
	if not _main_check(_main_game.active_ship == _main_ship and _main_game._piloting and not _main_game._transition_busy and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _main_player and _main_player.get_instance_id() == identity and not _main_ship.is_canopy_open() and _main_ship.get_camera().current,"actual ordinary E claims seat/camera/input and fully seals Dynamic sortie="+str(sortie)): return false
	_main_claims += 1
	generation = _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(_main_game._transition_generation == generation and area.get_reservation_token() == _main_player,"duplicate seated direct boarding cannot replace current transaction"): return false
	var eye := _main_ship.get_node("CockpitCamera") as Camera3D
	if not _main_check(eye.position == Vector3(0,2.26,-1.05) and _main_ship.get_pilot_seat_anchor().position == Vector3(0,0.5,-0.8) and _main_game.hud._active_ship_name == "DYNAMIC-CLASS GUNSHIP CANDIDATE" and _main_game.hud._active_ship_role == "GUNSHIP","actual adopted pilot/eye poses and bound candidate HUD identity"): return false
	return true


func _main_sortie_home(sortie: int, identity: int, area: ShipBoardingArea, berth: ShipBerth, dock: Transform3D) -> bool:
	_main_engine_edges.clear()
	Input.action_press(&"move_forward")
	for frame in 500:
		if not bool(_main_ship.get_telemetry().landed) and not _main_ship.get("_departure_lift_active"): break
		await _main_frames(1)
	_main_release_inputs()
	if not _main_check(_main_engine_edges.size() == 2 and _main_engine_edges[0].state == HeroShip.ENGINE_STARTING and _main_engine_edges[1].state == HeroShip.ENGINE_ONLINE and is_equal_approx(float(_main_engine_edges[0].remaining),2.1) and int(_main_engine_edges[1].tick)-int(_main_engine_edges[0].tick) >= 125 and int(_main_engine_edges[1].tick)-int(_main_engine_edges[0].tick) <= 127 and StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE,"actual inherited2.1s startup edges/ticks="+str(_main_engine_edges)): return false
	if not _main_check((_main_ship.global_position-dock.origin).dot(dock.basis.y) >= 3.49 and berth.get_occupant() == null and berth.get_reservation_owner() == null,"actual3.5m departure lift releases exact own occupied lease"): return false
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
		if frame%180 == 0: print("DYNAMIC_MAIN_FLIGHT: sortie=",sortie," frame=",frame," local=",dock.affine_inverse()*_main_ship.global_position," speed=",_main_ship.velocity.length())
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
	if not _main_check(bool(capture.get("assist_capture_accepted",false)) and StringName(capture.get("selected_berth_id",&"")) == &"dynamic_home_berth","normal capture selects exact own compatible home"): return false
	await _main_tap(&"landing_assist")
	for frame in 600:
		if _main_game.phase == GameFlow.Phase.SHUT_DOWN: break
		await _main_frames(1)
	var landing := _main_ship.get_landing_contract_report()
	if not _main_check(_main_game.phase == GameFlow.Phase.SHUT_DOWN and berth.get_occupant() == _main_ship and berth.get_reservation_owner() == _main_ship and _main_ship.global_position.distance_to(dock.origin) <= 0.05 and _main_ship.velocity.length() <= 0.05 and _main_ship.global_basis.is_equal_approx(dock.basis) and landing.strict_dock_acceptance and landing.contract_accepted and _main_game._ship_owns_exact_occupied_berth(_main_ship,&"dynamic_home_berth") and berth.contains_oriented_bounds(_main_ship.global_transform,_main_ship.get_landing_collision_report().local_bounds),"normal L restores complete strict hull at exact own dock and current occupied lease"): return false
	_main_release_inputs()
	await _main_frames(95)
	if not _main_check(StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"landed neutral input shuts propulsion OFFLINE"): return false
	await _main_tap(&"interact")
	for frame in 180:
		if not _main_game._transition_busy and not _main_player.is_seated(): break
		await _main_frames(1)
	await _main_frames(3)
	if not _main_check(not _main_game._piloting and not _main_ship.is_piloted() and not _main_player.is_seated() and _main_player.get_instance_id() == identity and _main_player.is_control_enabled() and _main_player.is_on_floor() and (_main_player.get_node("%PlayerCamera") as Camera3D).current and not _main_ship.get_camera().current and _main_player.collision_layer == _main_layer and _main_player.collision_mask == _main_mask and not (_main_player.get_node("PlayerCollision") as CollisionShape3D).disabled and not area.is_reserved() and _main_game._boarding_area == null and _main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and _main_ship.to_local(_main_player.global_position).distance_to(Vector3(-0.9,0.55,0.4)) < 0.05 and not bool(_main_player.get_cabin_containment_report().get("active",false)),"normal supported seated-open/inside release restores exact stand, walking body/control/camera and retires claim"): return false
	_main_releases += 1
	return _main_check(not area.release_reservation(_main_player),"stale released pilot claim cannot act")


func _main_walk_out(sortie: int) -> bool:
	for point in [Vector3(-5.9,0,0),Vector3(-8.4,0,0),Vector3(-8.4,0,-2.4),Vector3(-5.9,0,-2.4)]:
		if not await _main_walk_to(_main_ship.to_global(point),70+sortie,true): return false
	if not _main_check(_main_game._reboard_blocked_ship == null,"physical corridor walk naturally clears unchanged7m reboard fence"): return false
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"standing Player rediscovers actual outside port control"): return false
	await _main_tap(&"interact")
	await _main_frames(45)
	return _main_check(not _main_ship.is_canopy_open() and _main_player.is_on_floor(),"same Player physically walks out ramp, reaches corridor and seals outside full sweep")


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
	print("DYNAMIC_MAIN_ROUTE_LEG: ",leg," target=",target," actual=",_main_player.global_position," reached=",reached)
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
		push_error("DYNAMIC_MAIN_FAIL: "+message)
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
	print("DYNAMIC_MAIN_USER_DATA_DIR: ",OS.get_user_data_dir())
	print("DYNAMIC_GUNSHIP_MAIN_TEST_OK: claims=",_main_claims," releases=",_main_releases," walking_ticks=",_main_ticks," actual_pulse_shots=",_main_shots)
	await _main_key(KEY_ENTER)
	for frame in 120: await process_frame
	_main_check(false,"normal Main Quit did not terminate actual OS process")
