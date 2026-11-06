extends SceneTree

## Card 1 standalone foundation only, despite this extensible journey filename.
## No ordinary Player access, Main integration, combat or comparative handling
## qualification. One initial ship/source/pilot setup; real commands thereafter.
## No pose, velocity, startup-clock or engine-state mutation.
const PREDATOR := preload("res://scenes/ships/predator_detention_transport.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const DEFINITION := preload("res://assets/ships/predator_provisional.tres")
const Registry := preload("res://scripts/ships/fleet_role_registry.gd")
const FLEET := [
	preload("res://assets/ships/torrent_provisional.tres"),
	preload("res://assets/ships/arrow_provisional.tres"),
	preload("res://assets/ships/jovian_provisional.tres"),
	preload("res://assets/ships/zenith_b7_observed.tres"),
	preload("res://assets/ships/halyard_new_design.tres"),
	preload("res://assets/ships/bulwark_new_design.tres"),
	preload("res://assets/ships/cinder_cargo_hauler_new_design.tres"),
	preload("res://assets/ships/cinder_long_range_bomber_new_design.tres"),
	preload("res://assets/ships/cinder_light_interceptor_new_design.tres"),
	preload("res://assets/ships/titan_provisional.tres"),
	preload("res://assets/ships/vortex_provisional.tres"),
	preload("res://assets/ships/paradox_provisional.tres"),
	preload("res://assets/ships/katana_provisional.tres"),
]
const VALUES := {"maximum_speed": 73.0, "boost_speed": 94.0, "thrust_acceleration": 23.0, "brake_acceleration": 32.0, "passive_drag": 2.2, "throttle_response": 6.5, "boost_multiplier": 1.25, "yaw_speed_degrees": 43.0, "roll_speed_degrees": 54.0, "flight_assist_strength": 4.1, "visual_bank_degrees": 4.0, "maximum_mouse_turn_degrees": 11.0, "engine_start_time": 3.8, "weapon_cooldown": 0.78, "maximum_hull": 245.0, "landing_maximum_speed": 11.0}
var _checks := 0
var _failed := false
var _projectiles := 0


class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var fire := false

	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake, "yaw": yaw, "pitch": pitch, "roll": roll, "fire": fire}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _check(DEFINITION.is_definition_valid(), "valid approved resource"):
		return
	if not _check(DEFINITION.ship_id == &"predator_provisional"
		and DEFINITION.display_name == "Predator-class Detention Ship candidate"
		and DEFINITION.role_name == "Detention transport"
		and DEFINITION.evidence_status == ShipDefinition.EvidenceStatus.PROVISIONAL,
		"exact provisional identity"):
		return
	if not _check(DEFINITION.compatibility_tags == PackedStringArray(["medium_craft", "detention_transport", "predator_transport"])
		and DEFINITION.get_entry_descriptor() == {"noun": "stern hatch", "open_verb": "open", "close_verb": "seal", "boarding_verb": "board"}
		and DEFINITION.audio_profile_id == &"heavy_quad_freighter"
		and DEFINITION.evidence_references == PackedStringArray(["A3: creator-authored roster captured 2009-11-12", "B4: fleet.labels_jovian_titan_paradox_katana_vortex_predator label only; no Predator frame/model tie"])
		and DEFINITION.evidence_notes == "A3 supports Predator's dated name and detention-transport role only. B4 corroborates a label string only. Name-to-model mapping is unknown; all candidate geometry, access, fittings, systems, handling and berth are original modern trial design.",
		"approved entry/audio/tags and honest source boundary"):
		return
	var profiles := {}
	var registered: Array = []
	for definition: ShipDefinition in FLEET:
		profiles[definition.ship_id] = Registry._profile(definition)
		if Registry.get_supported_ship_ids().has(definition.ship_id):
			registered.append(definition)
	if not _check(registered.size() == 6 and Registry.audit_definitions(registered).valid, "unchanged registered fleet audit"):
		return
	profiles[DEFINITION.ship_id] = Registry._profile(DEFINITION)
	var errors := PackedStringArray()
	Registry._validate_pairwise_separation(profiles, errors)
	Registry._validate_non_dominance(profiles, errors)
	Registry._validate_signatures(profiles, errors)
	print("PREDATOR_COMBINED_FLEET: count=", profiles.size(), " errors=", errors)
	if not _check(errors.is_empty() and profiles.size() == 14, "all current profiles plus Vortex, Paradox, Katana and Predator retain14 axes/non-dominance/extrema"):
		return
	var ship := PREDATOR.instantiate() as HeroShip
	if not _check(ship != null, "actual HeroShip scene"):
		return
	root.add_child(ship)
	await _frames(3)
	for key: String in VALUES:
		if not _check(is_equal_approx(float(DEFINITION.get(key)), VALUES[key])
			and is_equal_approx(float(ship.get(key)), VALUES[key]), "approved controller value " + key):
			return
	if not _check(ship.home_berth_id == &"" and not ship.has_node("ShipBoardingArea")
		and not ship.has_method("get_cargo_manifest") and not ship.has_method("get_passenger_station_role_contract")
		and not ship.call("_uses_inherited_primary_weapon"), "standalone scope has no Main/cargo/passenger/combat grants"):
		return
	if not _test_geometry(ship):
		return
	var commands := FixtureCommands.new()
	ship.add_child(commands)
	ship.set_command_source(commands)
	ship.set_piloted(true)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE, "initial OFFLINE"):
		return
	ship.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void: _projectiles += 1)
	ship.request_engine_start()
	await _frames(222)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "3.8s spool still STARTING after3.7s"):
		return
	await _frames(7)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "actual inherited spool ONLINE after3.8s"):
		return
	var start := ship.global_transform
	commands.throttle = 1
	await _frames(120)
	var speed := ship.velocity.length()
	print("PREDATOR_THRUST: speed=", speed, " displacement=", ship.position - start.origin)
	if not _check(is_finite(speed) and speed > 0 and speed <= 73 and ship.position.z < start.origin.z - 1
		and absf(ship.position.x - start.origin.x) < 0.001, "real source drives forward translation"):
		return
	commands.fire = true
	await _frames(60)
	ship.call("_fire_weapon")
	ship.call("_fire_weapon_with_aim")
	ship.call("_fire_weapon_with_aim", ship.global_position, Vector3.FORWARD)
	var status := ship.get_weapon_fire_status()
	var presentation := ship.get_weapon_component_emitter_snapshot()
	if not _check(_projectiles == 0 and is_zero_approx(float(ship.get("_weapon_heat")))
		and is_zero_approx(float(ship.get("_weapon_timer"))) and not status.ready
		and status.status == &"unarmed" and status.reason == &"unarmed"
		and ship.call("_get_weapon_unavailable_reason") == &"unarmed"
		and str(ship.call("_get_cockpit_system_readout").text).contains("UNARMED")
		and str((ship.get("_cockpit_readout") as Label3D).text).contains("UNARMED")
		and ship.get("_muzzle_left") == null and ship.get("_muzzle_right") == null
		and ship.find_children("*Muzzle*", "Marker3D", true, false).is_empty()
		and int(presentation.emitter_count) == 0 and int(presentation.fallback_node_count) == 0
		and int(presentation.fallback_mesh_count) == 0, "held and direct FIRE are unconditional readable UNARMED without installed emitters"):
		return
	commands.fire = false
	commands.yaw = 0.25
	commands.pitch = 0.15
	commands.roll = 0.2
	await _frames(60)
	if not _check(ship.global_basis.is_finite() and ship.global_basis.get_rotation_quaternion().angle_to(start.basis.get_rotation_quaternion()) > 0.1,
		"real yaw/pitch/roll source changes attitude"):
		return
	commands.throttle = 0
	commands.yaw = 0
	commands.pitch = 0
	commands.roll = 0
	commands.brake = true
	var before_brake := ship.velocity.length()
	await _frames(30)
	print("PREDATOR_BRAKE: before=", before_brake, " after0.5s=", ship.velocity.length())
	if not _check(ship.velocity.length() < before_brake and ship.velocity.length() > 0, "actual brake reduces motion"):
		return
	await _frames(150)
	if not _check(ship.velocity.length() < 0.001 and ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "held brake arrests hull and retains demand"):
		return
	commands.brake = false
	await _frames(95)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and ship.velocity.length() < 0.001
		and is_zero_approx(float(ship.get("_throttle"))) and not ship.get_ship_audio_rig().is_engine_running(), "ordinary neutral idle reaches OFFLINE and retires engine audio"):
		return
	# Automatic thrust demand must also respect the approved spool, rather than
	# silently using HeroShip's immediate fighter wake path on the second sortie.
	commands.throttle = 0.5
	await _frames(1)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "ordinary automatic wake retains timed startup"):
		return
	await _frames(222)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "automatic wake still respects3.8s"):
		return
	await _frames(10)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE and ship.velocity.length() > 0, "second real sortie becomes usable"):
		return
	commands.throttle = 0
	commands.brake = true
	await _frames(60)
	commands.brake = false
	await _frames(95)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and ship.velocity.length() < 0.001
		and not ship.get_ship_audio_rig().is_engine_running() and _projectiles == 0, "second sortie retires propulsion/audio without latent weapon effects"):
		return
	ship.set_piloted(false)
	ship.queue_free()
	await _frames(3)
	print("PREDATOR_DETENTION_TRANSPORT_TEST_OK: ", _checks, " checks")
	quit(0)


func _test_geometry(ship: HeroShip) -> bool:
	var envelope := AABB()
	var first := true
	var sections := 0
	var shapes: Array[CollisionShape3D] = []
	var polygons: Array[PackedVector2Array] = []
	var section_bounds: Array[AABB] = []
	for child in ship.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if not _check(collision.shape is ConvexPolygonShape3D and not collision.disabled, "finite enabled convex section " + collision.name):
			return false
		var shape := collision.shape as ConvexPolygonShape3D
		var mesh := ship.get_node("PredatorOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
		var points := shape.points
		var faces := mesh.mesh.get_faces()
		var center := Vector3.ZERO
		var polygon := PackedVector2Array()
		var section_bound := AABB(collision.transform * points[0], Vector3.ZERO)
		for point in points:
			center += point / points.size()
			section_bound = section_bound.expand(collision.transform * point)
			var posed := collision.transform * point
			polygon.append(Vector2(posed.x, posed.z))
		shapes.append(collision)
		polygons.append(Geometry2D.convex_hull(polygon))
		section_bounds.append(section_bound)
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			if normals[index].dot(vertices[index] - center) <= 0.0:
				print("PREDATOR_INWARD_SURFACE: ", mesh.name, " vertex=", vertices[index], " normal=", normals[index])
				_check(false, "authored prism surfaces face outward for visible hull rendering")
				return false
		for point in points:
			if not _check(point.is_finite() and _has_point(faces, point), "collision vertex on editable mesh " + collision.name):
				return false
		for point in faces:
			if not _check(_has_point(points, point), "mesh vertex on actual collision " + collision.name):
				return false
		var bounds: AABB = section_bound
		envelope = bounds if first else envelope.merge(bounds)
		first = false
		sections += 1
	if not _check(sections == 26 and envelope.position.is_equal_approx(Vector3(-4.5, 0, -8))
		and envelope.size.is_equal_approx(Vector3(9, 5, 16)), "actual authored9x16x5 hull/collision envelope"):
		return false
	for i in shapes.size():
		for j in range(i + 1, shapes.size()):
			if minf(section_bounds[i].end.y, section_bounds[j].end.y) - maxf(section_bounds[i].position.y, section_bounds[j].position.y) <= 0.0001:
				continue
			for polygon in Geometry2D.intersect_polygons(polygons[i], polygons[j]):
				var area := 0.0
				for k in polygon.size():
					area += polygon[k].cross(polygon[(k + 1) % polygon.size()])
				if absf(area) > 0.0001:
					print("PREDATOR_OVERLAP: ", shapes[i].name, " / ", shapes[j].name, " area=", absf(area) * 0.5)
					_check(false, "convex shell and engines meet only at boundaries without overlapping interiors")
					return false
	if not _check(true, "actual convex sections have outward normals and nonoverlapping interiors"):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = PhysicsLayers.SHIP
	query.margin = 0
	# Exact reserved regions, shrunk 1mm only at shared solid boundaries.
	for bounds in [AABB(Vector3(0.201,1.001,-6.499),Vector3(1.598,2.598,12.998)),
		AABB(Vector3(-2.999,1.001,4.201),Vector3(5.998,2.598,2.298)),
		AABB(Vector3(-2.999,1.001,-0.999),Vector3(2.198,2.598,4.798))]:
		var clearance := BoxShape3D.new()
		clearance.size = bounds.size
		query.shape = clearance
		query.transform = ship.global_transform * Transform3D(Basis.IDENTITY,bounds.get_center())
		if not _check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "complete reserved aisle/corridor/secure interior remains clear"):
			return false
	var eye := ship.get_node("PredatorOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	query.shape = sphere
	query.transform = eye.global_transform
	if not _check(ship.get_pilot_seat_anchor().position.is_equal_approx(Vector3(0,1.45,-5.5))
		and eye.position.is_equal_approx(Vector3(0,3.21,-5.75))
		and (ship.get_node("DockingReceiver") as Node3D).position.is_equal_approx(Vector3(0,2.5,1.5))
		and (ship.get("_boarding_marker") as Marker3D).position.is_equal_approx(Vector3(1,1,-5.5))
		and ship.find_children("PilotSeatAnchor", "Marker3D", true, false).size() == 1
		and ship.get_pilot_seat_anchor().get_meta("station_id") == &"pilot_station"
		and eye.global_transform.is_finite() and ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "exact pilot/entry/receiver and clear finite cockpit eye"):
		return false
	# Actual production capsule cloned off-tree, including its collision transform.
	var player_fixture := PLAYER.instantiate()
	var player_collision := player_fixture.get_node("PlayerCollision") as CollisionShape3D
	var capsule := player_collision.shape.duplicate() as CapsuleShape3D
	var capsule_pose := player_collision.transform
	player_fixture.free()
	if not _check(capsule != null, "production PlayerCollision is an actual capsule"):
		return false
	print("PREDATOR_PLAYER_CAPSULE: radius=", capsule.radius, " height=", capsule.height, " local=", capsule_pose)
	query.shape = capsule
	for x in [0.2,0.6,1.0,1.4,1.8]:
		query.transform = ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(x,1.001,-6.5)) * capsule_pose
		query.motion = ship.global_basis * Vector3(0,0,13)
		var sweep := ship.get_world_3d().direct_space_state.cast_motion(query)
		if not _check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
			and sweep[0] >= 1.0, "actual capsule clears entire reserved longitudinal aisle"):
			return false
	query.motion = Vector3.ZERO
	query.transform = ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(1,1.001,-5.5)) * capsule_pose
	if not _check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "actual capsule clears future pilot entry"):
		return false
	var view_ray := PhysicsRayQueryParameters3D.create(eye.global_position,eye.global_position-eye.global_basis.z*0.7,PhysicsLayers.SHIP)
	if not _check(ship.get_world_3d().direct_space_state.intersect_ray(view_ray).is_empty(), "actual cockpit eye and near sight line clear"):
		return false
	print("PREDATOR_GEOMETRY: sections=", sections, " bounds=", envelope)
	return true


func _has_point(points: PackedVector3Array, target: Vector3) -> bool:
	for point in points:
		if point.is_equal_approx(target):
			return true
	return false


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
	await process_frame


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition:
		return true
	if not _failed:
		_failed = true
		push_error("PREDATOR_FAIL: " + label)
		quit(1)
	return false
