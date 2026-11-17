extends SceneTree

## Actual standalone production scenes/controllers. This fixture does not prove
## physical boarding, Main registration, combat authority or passenger capacity.
const Registry = preload("res://scripts/ships/fleet_role_registry.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
const CONFIG = {
	"dynamic": {"scene":"dynamic_gunship", "shell":"DynamicOriginalShell", "display":"Dynamic-class Gunship candidate", "role":"Gunship", "bounds":AABB(Vector3(-4.5,0,-5),Vector3(9,3.6,10)), "pilot":Vector3(0,.5,-.8), "eye":Vector3(0,2.26,-1.05), "entry":Vector3(-.9,.55,.4), "clear":AABB(Vector3(-1.5,.55,-2),Vector3(1.2,2.3,4)), "muzzle":Vector3(0,.9,-4.9), "range":360.0},
	"utopia": {"scene":"utopia_dropship", "shell":"UtopiaOriginalShell", "display":"Utopia-class Dropship candidate", "role":"Supply dropship", "bounds":AABB(Vector3(-4.5,0,-8.5),Vector3(9,4.8,17)), "pilot":Vector3(0,.8,-5.8), "eye":Vector3(0,2.56,-6.05), "entry":Vector3(.8,.8,-5.8), "clear":AABB(Vector3(-.8,.8,-6.8),Vector3(1.6,2.6,14.3)), "muzzle":Vector3(0,1.5,-8.7), "range":650.0},
	"salyut": {"scene":"salyut_transport", "shell":"SalyutOriginalShell", "display":"Salyut-class Transport candidate", "role":"Transport", "bounds":AABB(Vector3(-4,0,-7),Vector3(8,4.5,14)), "pilot":Vector3(0,.9,-4.7), "eye":Vector3(0,2.66,-4.95), "entry":Vector3(-.75,.9,-3.3), "clear":AABB(Vector3(-.7,.9,-5.6),Vector3(1.4,2.5,11.2)), "range":0.0},
}
const VALUES = {"dynamic": {"maximum_speed": 90.0, "boost_speed": 121.0, "thrust_acceleration": 33.0, "brake_acceleration": 45.0, "passive_drag": 2.65, "throttle_response": 9.5, "boost_multiplier": 1.37, "yaw_speed_degrees": 57.0, "roll_speed_degrees": 91.0, "flight_assist_strength": 5.1, "visual_bank_degrees": 12.5, "maximum_mouse_turn_degrees": 19.0, "engine_start_time": 2.1, "weapon_cooldown": 0.3, "maximum_hull": 158.0, "landing_maximum_speed": 16.5}, "utopia": {"maximum_speed": 71.0, "boost_speed": 93.0, "thrust_acceleration": 19.0, "brake_acceleration": 31.0, "passive_drag": 1.75, "throttle_response": 5.8, "boost_multiplier": 1.23, "yaw_speed_degrees": 40.0, "roll_speed_degrees": 51.0, "flight_assist_strength": 3.7, "visual_bank_degrees": 4.0, "maximum_mouse_turn_degrees": 10.5, "engine_start_time": 3.45, "weapon_cooldown": 0.62, "maximum_hull": 250.0, "landing_maximum_speed": 10.5}, "salyut": {"maximum_speed": 78.0, "boost_speed": 102.0, "thrust_acceleration": 26.0, "brake_acceleration": 37.0, "passive_drag": 2.05, "throttle_response": 7.3, "boost_multiplier": 1.31, "yaw_speed_degrees": 48.0, "roll_speed_degrees": 63.0, "flight_assist_strength": 4.35, "visual_bank_degrees": 8.0, "maximum_mouse_turn_degrees": 13.0, "engine_start_time": 2.9, "weapon_cooldown": 0.81, "maximum_hull": 175.0, "landing_maximum_speed": 12.5}}
const FLEET_PATHS = ["res://assets/ships/arrow_provisional.tres", "res://assets/ships/bulwark_new_design.tres", "res://assets/ships/cinder_cargo_hauler_new_design.tres", "res://assets/ships/cinder_light_interceptor_new_design.tres", "res://assets/ships/cinder_long_range_bomber_new_design.tres", "res://assets/ships/dynamic_provisional.tres", "res://assets/ships/halyard_new_design.tres", "res://assets/ships/jovian_provisional.tres", "res://assets/ships/katana_provisional.tres", "res://assets/ships/paradox_provisional.tres", "res://assets/ships/predator_provisional.tres", "res://assets/ships/salyut_provisional.tres", "res://assets/ships/titan_provisional.tres", "res://assets/ships/torrent_provisional.tres", "res://assets/ships/utopia_provisional.tres", "res://assets/ships/vortex_provisional.tres", "res://assets/ships/zenith_b7_observed.tres"]
var _name: String
var _ship: HeroShip
var _failed = false
var _checks = 0
var _shots = 0
var _bad_origin = false
var _edges: Array[Dictionary] = []
var _solid_poses: Dictionary = {}

class FixtureCommands:
	extends ShipCommandSource
	var throttle = 0.0
	var brake = false
	var yaw = 0.0
	var pitch = 0.0
	var roll = 0.0
	var fire = false
	func _sample_controls() -> Dictionary:
		return {"throttle":throttle,"brake":brake,"yaw":yaw,"pitch":pitch,"roll":roll,"fire":fire}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): _name = arg.trim_prefix("--ship=")
	if not _check(CONFIG.has(_name),"explicit named production candidate"): return
	var data: Dictionary = CONFIG[_name]
	var definition = load("res://assets/ships/"+_name+"_provisional.tres") as ShipDefinition
	if not _check(definition != null and definition.is_definition_valid()
		and definition.ship_id == StringName(_name+"_provisional")
		and definition.display_name == data.display and definition.role_name == data.role
		and definition.evidence_status == ShipDefinition.EvidenceStatus.PROVISIONAL
		and not definition.evidence_references.is_empty()
		and "modern" in definition.evidence_notes.to_lower()
		and "unknown" in definition.evidence_notes.to_lower(),"valid adopted identity and honest modern evidence boundary"): return
	var profiles: Dictionary = {}
	var registered: Array = []
	for path: String in FLEET_PATHS:
		var item = load(path) as ShipDefinition
		if not _check(item != null and item.is_definition_valid() and not profiles.has(item.ship_id),"unique actual definition "+path): return
		profiles[item.ship_id] = Registry._profile(item)
		if Registry.get_supported_ship_ids().has(item.ship_id): registered.append(item)
	var errors = PackedStringArray()
	Registry._validate_pairwise_separation(profiles,errors)
	Registry._validate_non_dominance(profiles,errors)
	Registry._validate_signatures(profiles,errors)
	if not _check(profiles.size()==17 and registered.size()==6 and Registry.audit_definitions(registered).valid and errors.is_empty(),"all17 actual profiles retain14 axes/non-dominance/signatures and registered-six policy: "+str(errors)): return
	_ship = (load("res://scenes/ships/"+str(data.scene)+".tscn") as PackedScene).instantiate() as HeroShip
	root.add_child(_ship)
	await _frames(3)
	for key: String in VALUES[_name]:
		if not _check(is_equal_approx(float(definition.get(key)),float(VALUES[_name][key])) and is_equal_approx(float(_ship.get(key)),float(VALUES[_name][key])),"resource and actual controller adopted value "+key): return
	if not _check(_ship.get_home_berth_id()==&"" and _ship.has_node("ShipBoardingArea")==(_name in ["dynamic","utopia"]) and not _ship.has_node("MovingInteriorFrame")
		and not _ship.has_method("get_passenger_station_role_contract") and not _ship.has_method("get_cargo_manifest"),"standalone scope keeps only Dynamic/Utopia physical boarding and no Main/berth/passenger/frame/cargo grants"): return
	if not _geometry(data): return
	var command = FixtureCommands.new()
	_ship.add_child(command)
	_ship.set_command_source(command)
	_ship.set_piloted(true)
	_ship.engine_state_changed.connect(func(state: StringName): _edges.append({"state":state,"tick":Engine.get_physics_frames(),"remaining":_ship.get("_engine_timer")}))
	_ship.projectile_fired.connect(func(origin: Vector3,direction: Vector3):
		_shots += 1
		if not data.has("muzzle") or _ship.to_local(origin).distance_to(data.muzzle)>.0001 or not direction.is_finite() or direction.is_zero_approx(): _bad_origin = true)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE,"initial real OFFLINE"): return
	var ticks = int(round(float(VALUES[_name].engine_start_time)*60))
	_ship.request_engine_start()
	await _frames(ticks-2)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_STARTING,"real approved spool remains STARTING before deadline"): return
	await _frames(5)
	if not _check(_edges.size()==2 and _edges[0].state==HeroShip.ENGINE_STARTING and _edges[1].state==HeroShip.ENGINE_ONLINE
		and is_equal_approx(float(_edges[0].remaining),float(VALUES[_name].engine_start_time))
		and absi(int(_edges[1].tick)-int(_edges[0].tick)-ticks)<=1,"actual inherited startup edges/ticks "+str(_edges)): return
	var initial = _ship.global_transform
	command.throttle = 1.0
	await _frames(120)
	var speed = _ship.velocity.length()
	if not _check(is_finite(speed) and speed>0 and speed<=float(VALUES[_name].maximum_speed)
		and _ship.position.z<initial.origin.z-1 and absf(_ship.position.x-initial.origin.x)<.001,"actual source drives finite approved forward flight"): return
	command.fire = true
	await _frames(60)
	command.fire = false
	if _name=="salyut":
		_ship._fire_weapon()
		_ship._fire_weapon_with_aim()
		_ship._fire_weapon_with_aim(_ship.global_position,Vector3.FORWARD)
		var status: Dictionary = _ship.get_weapon_fire_status()
		var emitter: Dictionary = _ship.get_weapon_component_emitter_snapshot()
		if not _check(_shots==0 and _ship._weapon_heat==0 and _ship._weapon_timer==0 and not status.ready
			and status.reason==&"unarmed" and status.status==&"unarmed" and not _ship._uses_inherited_primary_weapon()
			and _ship._muzzle_left==null and _ship._muzzle_right==null
			and _ship.find_children("*Muzzle*","Marker3D",true,false).is_empty()
			and emitter.emitter_count==0 and emitter.fallback_node_count==0
			and "UNARMED" in _ship._cockpit_readout.text,"held/direct Salyut fire is visibly UNARMED with no shots/heat/cooldown/muzzle/emitter"): return
	else:
		if not _check(_shots>0 and not _bad_origin and _ship._muzzle_left==_ship._muzzle_right
			and _ship.find_children("*Muzzle*","Marker3D",true,false).size()==1
			and is_equal_approx(_ship._get_weapon_targeting_distance(),float(data.range)),"actual held pulse uses one exact center origin and adopted targeting range"): return
		await _frames(int(ceil(float(VALUES[_name].weapon_cooldown)*60))+2)
		var previous = _shots
		_ship._fire_weapon()
		_ship._fire_weapon_with_aim()
		if not _check(_shots==previous+1 and not _bad_origin and is_equal_approx(_ship._weapon_timer,float(VALUES[_name].weapon_cooldown)),"one accepted direct trigger emits once; duplicate is gated by adopted cooldown"): return
	command.yaw = .25
	command.pitch = .15
	command.roll = .2
	await _frames(60)
	if not _check(_ship.global_basis.is_finite() and _ship.global_basis.get_rotation_quaternion().angle_to(initial.basis.get_rotation_quaternion())>.1,"actual yaw/pitch/roll command changes finite attitude"): return
	for mesh: MeshInstance3D in _solid_poses:
		if not _check(_root_pose(mesh).is_equal_approx(_solid_poses[mesh]),"actual yaw/roll keeps rendered solid matched to physical root "+str(mesh.name)): return
	if not _check(_root_pose(_ship.get_pilot_seat_anchor()).origin.is_equal_approx(data.pilot)
		and _root_pose(_ship.get("_cockpit_camera") as Camera3D).origin.is_equal_approx(data.eye),"actual yaw/roll retains physical helm and cockpit eye instead of cosmetic-bank drift"): return
	command.throttle = 0.0
	command.yaw = 0.0
	command.pitch = 0.0
	command.roll = 0.0
	command.brake = true
	await _frames(180)
	if not _check(_ship.velocity.length()<.001 and StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_ONLINE,"actual held brake arrests hull while retaining propulsion demand"): return
	command.brake = false
	await _frames(95)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE and _ship.velocity.length()<.001 and not _ship.get_ship_audio_rig().is_engine_running(),"normal neutral idle retires propulsion and engine audio"): return
	_edges.clear()
	command.throttle = .5
	await _frames(1)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_STARTING,"automatic demand respects timed spool instead of instant wake"): return
	await _frames(ticks-3)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_STARTING,"second real spool remains STARTING before approved duration"): return
	await _frames(6)
	if not _check(_edges.size()==2 and _edges[1].state==HeroShip.ENGINE_ONLINE and absi(int(_edges[1].tick)-int(_edges[0].tick)-ticks)<=1 and _ship.velocity.length()>0,"second demand-driven cycle becomes usable with exact inherited clock"): return
	command.throttle = 0.0
	command.brake = true
	await _frames(90)
	command.brake = false
	await _frames(95)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE and _ship.velocity.length()<.001 and not _ship.get_ship_audio_rig().is_engine_running(),"second cycle cleanly retires propulsion/audio"): return
	_ship.set_piloted(false)
	_ship.queue_free()
	await _frames(3)
	print("FLEET_CANDIDATE_FOUNDATION_TEST_OK: ship=",_name," checks=",_checks," shots=",_shots)
	quit(0)

func _geometry(data: Dictionary) -> bool:
	var shell = _ship.get_node(String(data.shell)) as Node3D
	var sections: Array[Dictionary] = []
	var envelope = AABB()
	for node in _ship.get_children():
		if not node is CollisionShape3D: continue
		var collision = node as CollisionShape3D
		var mesh = shell.get_node_or_null(String(collision.name).trim_suffix("Collision")) as MeshInstance3D
		if not _check(not collision.disabled and collision.shape is ConvexPolygonShape3D and mesh!=null and mesh.visible,"actual enabled convex section and matching editable mesh "+str(collision.name)): return false
		var points = PackedVector3Array()
		var local = collision.transform
		for p: Vector3 in (collision.shape as ConvexPolygonShape3D).points: points.append(local*p)
		var faces = PackedVector3Array()
		var mesh_pose = _root_pose(mesh)
		_solid_poses[mesh] = mesh_pose
		# Read actual render buffers. Mesh.get_faces() uses a cached triangle
		# representation whose quantization changes rational sheared vertices.
		for surface_index in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for p: Vector3 in vertices: faces.append(mesh_pose*p)
			else:
				for index in indices: faces.append(mesh_pose*vertices[index])
		var center = Vector3.ZERO
		for p: Vector3 in points: center += p/float(points.size())
		for p: Vector3 in points:
			if not _check(p.is_finite() and _has_point(faces,p),"collision vertex lies on visible source mesh"): return false
		for p: Vector3 in faces:
			if not _check(_has_point(points,p),"visible source vertex lies on convex collision hull"): return false
		var normals: Array[Vector3] = []
		var edges: Array[Vector3] = []
		for surface_index in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var authored_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if not _check(vertices.size()==authored_normals.size(),"all visible vertices have authored normals"): return false
			for i in vertices.size():
				var normal = (mesh_pose.basis*authored_normals[i]).normalized()
				if not _check(normal.dot(mesh_pose*vertices[i]-center)>0,"authored surface normal faces outward "+str(mesh.name)): return false
		for i in range(0,faces.size(),3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i+1]
			var c: Vector3 = faces[i+2]
			var normal = (b-a).cross(c-a).normalized()
			if normal.dot((a+b+c)/3.0-center)<0: normal = -normal
			_axis(normals,normal)
			for p: Vector3 in points:
				if not _check(normal.dot(p-a)<=.0001,"editable section is convex and agrees with full collision hull"): return false
			_axis(edges,b-a)
			_axis(edges,c-b)
			_axis(edges,a-c)
		var bounds = AABB(points[0],Vector3.ZERO)
		for p: Vector3 in points: bounds = bounds.expand(p)
		envelope = bounds if sections.is_empty() else envelope.merge(bounds)
		sections.append({"name":collision.name,"points":points,"normals":normals,"edges":edges,"bounds":bounds})
	if not _check(not sections.is_empty() and envelope.is_equal_approx(data.bounds),"complete actual authored closed hull bounds "+str(envelope)): return false
	for i in sections.size():
		for j in range(i+1,sections.size()):
			if _overlaps(sections[i],sections[j]):
				print("FOUNDATION_OVERLAP: ",sections[i].name," / ",sections[j].name)
				return _check(false,"convex physical sections have no positive-volume overlap")
	var query = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = PhysicsLayers.SHIP
	query.margin = 0
	var clear: AABB = data.clear
	var space = BoxShape3D.new()
	space.size = clear.size-Vector3.ONE*.002
	query.shape = space
	query.transform = _ship.global_transform*Transform3D(Basis.IDENTITY,clear.get_center())
	if not _check(_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"complete reserved cockpit path or cabin aisle remains hollow"): return false
	var player = PLAYER.instantiate()
	var body = player.get_node("PlayerCollision") as CollisionShape3D
	var capsule = body.shape.duplicate() as CapsuleShape3D
	var body_pose = body.transform
	player.free()
	capsule.radius -= .005
	capsule.height -= .01
	query.shape = capsule
	query.transform = _ship.global_transform*Transform3D(Basis.IDENTITY,data.entry+Vector3.UP*.001)*body_pose
	if not _check(_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual normal Player capsule clears exact future supported entry"): return false
	var feet: Vector3 = _ship.to_global(data.entry)
	var support = PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.06,feet-Vector3.UP*.06,PhysicsLayers.SHIP)
	var hit: Dictionary = _ship.get_world_3d().direct_space_state.intersect_ray(support)
	if not _check(not hit.is_empty() and hit.collider==_ship and (hit.normal as Vector3).dot(Vector3.UP)>.99,"entry support is actual authored collision floor"): return false
	var camera = _ship.get("_cockpit_camera") as Camera3D
	var eye = SphereShape3D.new()
	eye.radius = .1
	query.shape = eye
	query.transform = camera.global_transform
	if not _check(_root_pose(_ship.get_pilot_seat_anchor()).origin.is_equal_approx(data.pilot)
		and _ship.get_pilot_seat_anchor().get_meta("station_id")==&"pilot_station"
		and _root_pose(camera).origin.is_equal_approx(data.eye)
		and (_ship.get_node("DockingReceiver") as Marker3D).transform.is_equal_approx(Transform3D.IDENTITY)
		and _ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"exact single pilot/receiver and clear actual cockpit eye"): return false
	var ray = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*.7,PhysicsLayers.SHIP)
	if not _check(_ship.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"actual forward cockpit near sightline clears shell"): return false
	if data.has("muzzle"):
		var origin: Vector3 = _ship.to_global(data.muzzle)
		var bore = PhysicsRayQueryParameters3D.create(origin,origin-Vector3(0,0,2),PhysicsLayers.SHIP)
		if not _check(_ship.get_world_3d().direct_space_state.intersect_ray(bore).is_empty(),"single center weapon bore clears physical nose"): return false
	print("FOUNDATION_GEOMETRY: ship=",_name," sections=",sections.size()," bounds=",envelope)
	return true

func _axis(axes: Array[Vector3],value: Vector3) -> void:
	if value.length_squared()<.00000001: return
	var normal = value.normalized()
	for existing: Vector3 in axes:
		if absf(existing.dot(normal))>.99999: return
	axes.append(normal)

func _overlaps(a: Dictionary,b: Dictionary) -> bool:
	var aa: AABB = a.bounds
	var bb: AABB = b.bounds
	for i in 3:
		if minf(aa.end[i],bb.end[i])-maxf(aa.position[i],bb.position[i])<=.0001: return false
	var axes: Array[Vector3] = []
	for n: Vector3 in a.normals: _axis(axes,n)
	for n: Vector3 in b.normals: _axis(axes,n)
	for x: Vector3 in a.edges:
		for y: Vector3 in b.edges: _axis(axes,x.cross(y))
	for axis: Vector3 in axes:
		var amin = INF
		var amax = -INF
		var bmin = INF
		var bmax = -INF
		for p: Vector3 in a.points:
			amin = minf(amin,axis.dot(p)); amax = maxf(amax,axis.dot(p))
		for p: Vector3 in b.points:
			bmin = minf(bmin,axis.dot(p)); bmax = maxf(bmax,axis.dot(p))
		if minf(amax,bmax)-maxf(amin,bmin)<=.0001: return false
	return true

func _has_point(points: PackedVector3Array,target: Vector3) -> bool:
	for p: Vector3 in points:
		if p.is_equal_approx(target): return true
	return false

func _frames(count: int) -> void:
	for _i in count: await physics_frame
	await process_frame

func _check(value: bool,message: String) -> bool:
	_checks += 1
	if value: return true
	if not _failed:
		_failed = true
		print("FAIL: ",_name,": ",message)
		quit(1)
	return false

func _root_pose(value: Node3D) -> Transform3D:
	# Accumulate the physical hierarchy directly. A world inverse round trip at
	# 180m introduces float quantization into an otherwise exact local pose.
	var pose = Transform3D.IDENTITY
	var current = value
	while current != _ship:
		if current == null:
			_check(false,"physical fixture must remain under its actual ship")
			return Transform3D.IDENTITY
		pose = current.transform * pose
		current = current.get_parent() as Node3D
	return pose
