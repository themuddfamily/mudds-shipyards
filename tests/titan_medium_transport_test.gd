extends SceneTree

## Standalone component fixture, deliberately no Main, berth or boarding claim.
const TITAN := preload("res://scenes/ships/titan_medium_transport.tscn")
const DEFINITION := preload("res://assets/ships/titan_provisional.tres")
const TITAN_SCRIPT := preload("res://scripts/ships/titan_medium_transport.gd")
const VALUES := {"maximum_speed": 72.0, "boost_speed": 90.0,
	"thrust_acceleration": 18.0, "brake_acceleration": 27.0,
	"passive_drag": 1.95, "throttle_response": 6.1, "boost_multiplier": 1.19,
	"yaw_speed_degrees": 40.0, "roll_speed_degrees": 48.0,
	"flight_assist_strength": 4.45, "visual_bank_degrees": 5.5,
	"maximum_mouse_turn_degrees": 12.5, "engine_start_time": 3.4,
	"weapon_cooldown": 0.62, "maximum_hull": 220.0, "landing_maximum_speed": 11.0}
var _checks := 0
var _failures := 0


class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false

	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(DEFINITION.is_definition_valid(), "candidate definition validates")
	_check(DEFINITION.ship_id == &"titan_provisional"
		and DEFINITION.display_name == "Titan-class Medium Transport candidate"
		and DEFINITION.role_name == "Medium transport"
		and DEFINITION.evidence_status == ShipDefinition.EvidenceStatus.PROVISIONAL,
		"exact provisional Titan identity and role")
	_check(DEFINITION.compatibility_tags == PackedStringArray(["medium_craft", "medium_transport", "multi_crew", "cargo", "titan_transport"]), "exact declared compatibility tags")
	_check(DEFINITION.get_entry_descriptor() == {"noun": "hatch", "open_verb": "open", "close_verb": "seal", "boarding_verb": "board"}
		and DEFINITION.audio_profile_id == &"standard_fighter", "approved entry vocabulary and shared audio profile")
	_check("A3 supports" in DEFINITION.evidence_notes and "B3 and B4 corroborate labels only" in DEFINITION.evidence_notes
		and "original modern" in DEFINITION.evidence_notes and "UNKNOWN" in DEFINITION.evidence_notes,
		"provenance distinguishes name/role and labels from unknown historical geometry and modern mechanics")
	var ship := TITAN.instantiate() as HeroShip
	_check(ship != null, "standalone Titan scene instantiates as HeroShip")
	if ship == null:
		_finish()
		return
	root.add_child(ship)
	await process_frame
	await physics_frame
	await physics_frame
	for key: String in VALUES:
		_check(is_equal_approx(float(DEFINITION.get(key)), VALUES[key])
			and is_equal_approx(float(ship.get(key)), VALUES[key]), "approved definition/controller tuning: " + key)
	_check(ship.get_pilot_seat_anchor().position.is_equal_approx(Vector3(0, 0.75, -5.8))
		and ship.to_local(ship.get_pilot_seat_anchor().global_position).is_equal_approx(Vector3(0, 0.75, -5.8)), "exact root-local pilot feet anchor")
	var eye := ship.get_node("TitanOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	_check(ship.to_local(eye.global_position).is_equal_approx(Vector3(0, 2.51, -6.05)), "exact root-local cockpit eye")
	_check(ship.home_berth_id == &"" and not ship.call("_uses_inherited_primary_weapon")
		and not ship.has_node("MovingInteriorFrame") and not ship.has_node("ShipBoardingArea"),
		"standalone child has no berth, boarding, cabin carry or inherited combat composition")
	_test_shell(ship)
	await _test_flight(ship)
	ship.set_piloted(false)
	ship.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_shell(ship: HeroShip) -> void:
	var report := ship.get_landing_collision_report()
	_check(report.valid and report.local_bounds.is_equal_approx(AABB(Vector3(-6, 0, -9), Vector3(12, 5, 18))),
		"finite supported convex collision envelope is exactly 12 by 18 by 5 metres")
	var shapes: Array[CollisionShape3D] = []
	var polygons: Array[PackedVector2Array] = []
	var bounds: Array[AABB] = []
	var valid := true
	var outward := true
	for node: CollisionShape3D in ship.find_children("*", "CollisionShape3D", false, false):
		shapes.append(node)
		valid = valid and node.shape is ConvexPolygonShape3D and not node.disabled
		var convex := node.shape as ConvexPolygonShape3D
		if convex == null:
			continue
		var polygon := PackedVector2Array()
		var mesh := ship.get_node("TitanOriginalShell/" + str(node.name).trim_suffix("Collision")) as MeshInstance3D
		var faces := mesh.mesh.get_faces()
		var center := Vector3.ZERO
		for point in convex.points:
			center += point / convex.points.size()
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in range(vertices.size()):
			if normals[index].dot(vertices[index] - center) <= 0.0:
				print("TITAN_INWARD_SURFACE: ", mesh.name)
				outward = false
		var aabb := AABB(convex.points[0], Vector3.ZERO)
		for point in convex.points:
			valid = valid and point.is_finite() and _contains_point(faces, point)
			aabb = aabb.expand(point)
			polygon.append(Vector2(point.x, point.z))
		for point in faces:
			valid = valid and point.is_finite() and _contains_point(convex.points, point)
		bounds.append(aabb)
		polygons.append(Geometry2D.convex_hull(polygon))
	_check(outward, "authored prism surfaces face outward for visible hull rendering")
	_check(valid and shapes.size() >= 16, "every shell/engine convex has finite matching authored visible vertices")
	var nonoverlap := true
	for i in range(shapes.size()):
		for j in range(i + 1, shapes.size()):
			if minf(bounds[i].end.y, bounds[j].end.y) - maxf(bounds[i].position.y, bounds[j].position.y) <= 0.0001:
				continue
			for polygon in Geometry2D.intersect_polygons(polygons[i], polygons[j]):
				var area := 0.0
				for k in range(polygon.size()):
					area += polygon[k].cross(polygon[(k + 1) % polygon.size()])
				if absf(area) > 0.0001:
					print("TITAN_OVERLAP: ", shapes[i].name, " / ", shapes[j].name, " area=", absf(area) * 0.5)
					nonoverlap = false
	_check(nonoverlap, "convex shell and engines meet only at boundaries without overlapping interiors")
	var query := PhysicsShapeQueryParameters3D.new()
	var void_box := BoxShape3D.new()
	void_box.size = TITAN_SCRIPT.CABIN_VOID.size - Vector3.ONE * 0.002
	query.shape = void_box
	query.margin = 0.0
	query.transform = Transform3D(Basis.IDENTITY, TITAN_SCRIPT.CABIN_VOID.get_center())
	query.collision_mask = PhysicsLayers.SHIP
	_check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
		"actual physics leaves whole reserved 5.4m wide cabin void clear above 0.8m floor for 2.5m headroom")
	var stern := ship.get_node("ClosedSternBlankCollision") as CollisionShape3D
	var stern_mesh := ship.get_node("TitanOriginalShell/ClosedSternBlank") as MeshInstance3D
	_check(stern != null and stern_mesh.get_aabb().end.z <= 8.001
		and ship.get_node("TitanOriginalShell/PortVestibuleCheek").get_aabb().end.z == 9.0,
		"stern closure is physically recessed one metre behind aft cheeks")


func _contains_point(points: PackedVector3Array, point: Vector3) -> bool:
	for candidate in points:
		if candidate.is_equal_approx(point):
			return true
	print("TITAN_UNMATCHED_VERTEX: ", point)
	return false


func _test_flight(ship: HeroShip) -> void:
	var source := FixtureCommands.new()
	ship.add_child(source)
	ship.set_command_source(source)
	ship.set_piloted(true)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE, "inherited engine starts OFFLINE")
	ship.request_engine_start()
	_check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "inherited timed-start request enters STARTING")
	await _frames(90)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "approved 3.4-second spool remains STARTING at 1.5 seconds")
	await _frames(115)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "inherited spool reaches ONLINE after approved start interval")
	var origin := ship.position
	source.throttle = 1.0
	await _frames(120)
	var speed := ship.velocity.length()
	_check(speed > 28.0 and speed < 33.0 and ship.position.z < origin.z - 25.0
		and absf(ship.position.x - origin.x) < 0.001,
		"real command-source thrust moves hull forward at approved transport acceleration")
	print("TITAN_FLIGHT: thrust_2s_speed=", speed, " displacement=", ship.position - origin)
	source.throttle = 0.0
	source.brake = true
	await _frames(30)
	var braking_speed := ship.velocity.length()
	_check(braking_speed < speed - 10.0 and braking_speed > 0.0, "inherited manual braking measurably reduces actual velocity")
	await _frames(90)
	_check(ship.velocity.length() < 0.001 and ship.get("_engine_state") == HeroShip.ENGINE_ONLINE,
		"held brake arrests hull and remains propulsion demand")
	source.brake = false
	await _frames(95)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE
		and ship.velocity.length() < 0.001 and is_zero_approx(float(ship.get("_throttle"))),
		"neutral commands automatically shut down inherited engine with zero thrust")
	_check(not ship.get_ship_audio_rig().is_engine_running(), "shutdown also retires continuous engine audio authority")
	print("TITAN_FLIGHT: brake_0.5s_speed=", braking_speed, " final_engine=", ship.get("_engine_state"))


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
	await process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)


func _finish() -> void:
	print("TITAN_MEDIUM_TRANSPORT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
