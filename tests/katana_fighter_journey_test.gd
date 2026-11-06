extends SceneTree

## Card 1 standalone foundation only, despite this extensible journey filename.
## No ordinary Player access, Main integration, combat or comparative handling
## qualification. One initial ship/source/pilot setup; real commands thereafter.
## No pose, velocity, startup-clock or engine-state mutation.
const KATANA := preload("res://scenes/ships/katana_fighter.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const DEFINITION := preload("res://assets/ships/katana_provisional.tres")
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
]
const VALUES := {"maximum_speed": 88.0, "boost_speed": 114.0, "thrust_acceleration": 38.0, "brake_acceleration": 64.0, "passive_drag": 2.4, "throttle_response": 11.0, "boost_multiplier": 1.35, "yaw_speed_degrees": 58.0, "roll_speed_degrees": 98.0, "flight_assist_strength": 5.2, "visual_bank_degrees": 11.0, "maximum_mouse_turn_degrees": 17.0, "engine_start_time": 2.3, "weapon_cooldown": 0.38, "maximum_hull": 145.0, "landing_maximum_speed": 15.0}
var _checks := 0
var _failed := false


class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0

	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake, "yaw": yaw, "pitch": pitch, "roll": roll}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _check(DEFINITION.is_definition_valid(), "valid approved resource"):
		return
	if not _check(DEFINITION.ship_id == &"katana_provisional"
		and DEFINITION.display_name == "Katana-class Fighter candidate"
		and DEFINITION.role_name == "Fighter"
		and DEFINITION.evidence_status == ShipDefinition.EvidenceStatus.PROVISIONAL,
		"exact provisional identity"):
		return
	if not _check(DEFINITION.compatibility_tags == PackedStringArray(["small_craft", "fighter", "single_pilot", "katana_fighter"])
		and DEFINITION.get_entry_descriptor() == {"noun": "canopy", "open_verb": "raise", "close_verb": "seal", "boarding_verb": "board"}
		and DEFINITION.audio_profile_id == &"standard_fighter"
		and DEFINITION.evidence_references == PackedStringArray(["A3: creator-authored roster captured 2009-11-12", "B3: fleet.labels_titan_torrent_arrow_altair_katana label only; no Katana frame/model tie", "B4: fleet.labels_jovian_titan_paradox_katana_vortex_predator label only; no Katana frame/model tie"])
		and DEFINITION.evidence_notes == "A3 supports Katana's dated name and fighter role only. B3/B4 corroborate label strings only. Name-to-model mapping is unknown; all candidate geometry, access, fittings, weapons, handling and berth are modern trial design.",
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
	print("KATANA_COMBINED_FLEET: count=", profiles.size(), " errors=", errors)
	if not _check(errors.is_empty() and profiles.size() == 13, "all current profiles plus Vortex, Paradox and Katana retain14 axes/non-dominance/extrema"):
		return
	for definition: ShipDefinition in FLEET:
		if not _check(DEFINITION.brake_acceleration > definition.brake_acceleration, "new numeric braking maximum over " + String(definition.ship_id)):
			return
	var ship := KATANA.instantiate() as HeroShip
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
	ship.request_engine_start()
	await _frames(132)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "2.3s spool still STARTING after2.2s"):
		return
	await _frames(7)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "actual inherited spool ONLINE after2.3s"):
		return
	var start := ship.global_transform
	commands.throttle = 1
	await _frames(120)
	var speed := ship.velocity.length()
	print("KATANA_THRUST: speed=", speed, " displacement=", ship.position - start.origin)
	if not _check(speed > 60 and speed < 76 and ship.position.z < start.origin.z - 25
		and absf(ship.position.x - start.origin.x) < 0.001, "real source drives forward translation"):
		return
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
	print("KATANA_BRAKE: before=", before_brake, " after0.5s=", ship.velocity.length())
	if not _check(ship.velocity.length() < before_brake - 20 and ship.velocity.length() > 0, "actual brake reduces motion"):
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
	await _frames(132)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "automatic wake still respects2.3s"):
		return
	await _frames(10)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE and ship.velocity.length() > 0, "second real sortie becomes usable"):
		return
	commands.throttle = 0
	commands.brake = true
	await _frames(60)
	commands.brake = false
	await _frames(95)
	ship.set_piloted(false)
	ship.queue_free()
	await _frames(3)
	print("KATANA_FIGHTER_JOURNEY_TEST_OK: ", _checks, " checks")
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
		var mesh := ship.get_node("KatanaOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
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
				print("KATANA_INWARD_SURFACE: ", mesh.name, " vertex=", vertices[index], " normal=", normals[index])
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
	if not _check(sections == 17 and envelope.position.is_equal_approx(Vector3(-5.5, 0, -6))
		and envelope.size.is_equal_approx(Vector3(11, 3.8, 12)), "actual authored11x12x3.8 hull/collision envelope"):
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
					print("KATANA_OVERLAP: ", shapes[i].name, " / ", shapes[j].name, " area=", absf(area) * 0.5)
					_check(false, "convex shell and engines meet only at boundaries without overlapping interiors")
					return false
	if not _check(true, "actual convex sections have outward normals and nonoverlapping interiors"):
		return false
	var cabin := PhysicsShapeQueryParameters3D.new()
	var clearance := BoxShape3D.new()
	clearance.size = Vector3(2.998, 2.898, 4.498)
	cabin.shape = clearance
	cabin.transform.origin = Vector3(0, 2.05, 0.25)
	cabin.collision_mask = PhysicsLayers.SHIP
	cabin.margin = 0
	if not _check(ship.get_world_3d().direct_space_state.intersect_shape(cabin).is_empty(), "reserved walking recess has no full-box collider"):
		return false
	var eye := ship.get_node("KatanaOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	query.shape = sphere
	query.transform = eye.global_transform
	query.collision_mask = PhysicsLayers.SHIP
	if not _check(ship.get_pilot_seat_anchor().position.is_equal_approx(Vector3(0, 0.55, -1))
		and eye.position.is_equal_approx(Vector3(0,2.31,-1.25))
		and (ship.get_node("DockingReceiver") as Node3D).transform == Transform3D.IDENTITY
		and ship.find_children("PilotSeatAnchor", "Marker3D", true, false).size() == 1
		and ship.get_pilot_seat_anchor().get_meta("station_id") == &"pilot_station"
		and eye.global_transform.is_finite() and ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "exact pilot anchor and clear finite cockpit camera"):
		return false
	# Clone the production collision off-tree: no second physics actor or
	# hand-authored approximation of the Player's walking clearance.
	var player_fixture := PLAYER.instantiate()
	var player_collision := player_fixture.get_node("PlayerCollision") as CollisionShape3D
	var capsule := player_collision.shape.duplicate() as CapsuleShape3D
	player_fixture.free()
	if not _check(capsule != null, "production PlayerCollision is an actual capsule"):
		return false
	print("KATANA_PLAYER_CAPSULE: radius=", capsule.radius, " height=", capsule.height)
	query.shape = capsule
	query.margin = 0
	for z in [-1.5,0.0,2.0]:
		query.transform = ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-0.95,0.6 + capsule.height * 0.5 + 0.01,z))
		if not _check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "actual capsule-sized reserved walking path"):
			return false
	var view_ray := PhysicsRayQueryParameters3D.create(eye.global_position,eye.global_position-eye.global_basis.z*0.7,PhysicsLayers.SHIP)
	if not _check(ship.get_world_3d().direct_space_state.intersect_ray(view_ray).is_empty(), "actual cockpit eye and near sight line clear"):
		return false
	print("KATANA_GEOMETRY: sections=", sections, " bounds=", envelope)
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
		push_error("KATANA_FAIL: " + label)
		quit(1)
	return false
