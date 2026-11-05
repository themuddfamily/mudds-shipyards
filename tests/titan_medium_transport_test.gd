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
		and ship.has_node("MovingInteriorFrame") and not ship.has_node("ShipBoardingArea"),
		"standalone access has a moving cabin frame, no berth/Main boarding or inherited combat composition")
	_test_shell(ship)
	await _test_access(ship)
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
		if str(node.name).begins_with("SternRamp"):
			continue
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
	var slot_shape := BoxShape3D.new()
	slot_shape.size = Vector3(2.398, 2.99, 0.198)
	query.shape = slot_shape
	query.transform.origin = Vector3(0, 4.9, 7.9)
	_check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
		"physical roof/header contain a genuine empty channel for the entire vertical hatch stroke")
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


func _test_access(ship: HeroShip) -> void:
	ship.set_canopy_open(true, 0.0)
	await _frames(2)
	_check(not ship.is_canopy_open(), "unsupported exterior access refuses through inherited canopy API")
	var deck := StaticBody3D.new()
	deck.name = "SupportedFixtureApron"
	deck.collision_layer = PhysicsLayers.WORLD
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(16, 1, 32)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	deck.add_child(floor_collision)
	root.add_child(deck)
	var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerController
	# The sole staged pose. All later player/ship displacement is real physics.
	player.position = Vector3(0, 0, 14.5)
	root.add_child(player)
	await _frames(10)
	_check(player.is_on_floor() and player.position.distance_to(Vector3(0, 0, 14.5)) < 0.02,
		"one real Player starts supported once on fixture apron at (0,0,14.5)")
	_check(ship.get_node("MovingInteriorFrame").get_interior_bounds().is_equal_approx(TITAN_SCRIPT.CABIN_VOID),
		"existing MovingInteriorFrame uses exact approved walking bounds")
	var closed_origin := ship.position
	await _walk_to(player, 7.0, &"move_forward", 110)
	_check(player.position.z > 8.2 and player.position.z < 9.1,
		"real Player normal forward movement cannot pass the closed stern boundary")
	await _walk_to(player, 14.5, &"move_back", 100)
	_check(absf(player.position.z - 14.5) < 0.05 and absf(player.position.x) < 0.01, "same Player walks back to safe apron before ramp deployment")
	ship.set_canopy_open(true, 1.2)
	await _frames(35)
	var fraction := float(ship.get("_access_fraction"))
	_check(fraction > 0.1 and fraction < 0.9 and _access_collisions_match(ship),
		"moving hatch and both folding ramp leaves retain matching visible/physical poses")
	await _frames(45)
	_check(ship.is_canopy_open() and is_equal_approx(float(ship.get("_access_fraction")), 1.0)
		and _access_collisions_match(ship), "fully open hatch/ramp preserve actual matched collision")
	var deployed := ship.get_landing_collision_report()
	_check(deployed.valid and deployed.local_bounds.is_equal_approx(AABB(Vector3(-6, 0, -9), Vector3(12, 6.5, 22))),
		"deployed collision envelope is exactly x±6,z−9..13,y0..6.5")
	_check(_aisle_clear(ship), "actual aperture and continuous 1.4m aisle have 2.5m unobstructed headroom")
	var control := ship.get_node("TitanOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	var safe_point := Vector3(1.9, 0, 10)
	var safe_ray := PhysicsRayQueryParameters3D.create(safe_point + Vector3.UP * 0.2, safe_point - Vector3.UP * 0.2, PhysicsLayers.WORLD)
	_check(control.is_available() and absf(safe_point.x) - 0.38 > 1.2
		and not ship.get_world_3d().direct_space_state.intersect_ray(safe_ray).is_empty()
		and (safe_point + Vector3.UP * 1.75).distance_to(control.global_position) < ShipCabinHatch.MAX_REACH,
		"stern cheek control is normally reachable from supported apron outside ramp sweep")
	var controls := FixtureCommands.new()
	ship.add_child(controls)
	ship.set_command_source(controls)
	ship.set_piloted(true)
	controls.throttle = 1.0
	ship.request_engine_start()
	await _frames(30)
	_check(ship.position.is_equal_approx(closed_origin) and ship.velocity.length() < 0.001
		and ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE,
		"open access refuses timed start and actual throttle departure through inherited controller")
	controls.throttle = 0.0
	ship.set_piloted(false)
	var inbound := await _walk_to(player, -4.2, &"move_forward", 280, ship)
	_check(absf(player.position.z + 4.2) < 0.05 and absf(player.position.x) < 0.01 and absf(player.position.y - 0.8) < 0.02,
		"normal uninterrupted locomotion climbs real ramp and reaches exact helm approach")
	_check(inbound.supported == inbound.frames and inbound.clear == inbound.frames and inbound.ship_contacts > 150,
		"every inbound movement frame has supported contact and clear actual Player capsule/head")
	_check((ship.get_node("MovingInteriorFrame") as MovingInteriorFrame).is_occupant_registered(player) and not (ship.collision_mask & PhysicsLayers.PLAYER),
		"real cabin traversal automatically registers Player with existing moving frame")
	ship.set_canopy_open(false, 1.2)
	await _frames(35)
	ship.set_piloted(true)
	controls.throttle = 1.0
	ship.request_engine_start()
	await _frames(5)
	_check(not ship.is_canopy_open() and float(ship.get("_access_fraction")) > 0.0
		and _access_collisions_match(ship) and ship.position.is_equal_approx(closed_origin)
		and ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE,
		"closing access still refuses actual timed start/throttle until physical stow completes")
	controls.throttle = 0.0
	ship.set_piloted(false)
	await _frames(40)
	_check(not ship.is_canopy_open() and is_zero_approx(float(ship.get("_access_fraction")))
		and _access_collisions_match(ship), "closed hatch and stowed ramp restore matched collision")
	_check(ship.get_landing_collision_report().local_bounds.is_equal_approx(AABB(Vector3(-6, 0, -9), Vector3(12, 5, 18))),
		"sealed access restores exact original 12×18×5m collision envelope")
	ship.set_piloted(true)
	controls.brake = true
	await _frames(5)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "sealed fixture pilot intent wakes actual inherited propulsion")
	controls.brake = false
	await _frames(95)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_OFFLINE and ship.position.is_equal_approx(closed_origin),
		"actual inherited neutral shutdown completes before physical return outside")
	ship.set_piloted(false)
	ship.set_canopy_open(true, 1.2)
	await _frames(80)
	var outbound := await _walk_to(player, 14.5, &"move_back", 280, ship)
	_check(absf(player.position.z - 14.5) < 0.05 and absf(player.position.x) < 0.01 and absf(player.position.y) < 0.02,
		"same Player physically returns down ramp to original supported apron after shutdown")
	_check(outbound.supported == outbound.frames and outbound.clear == outbound.frames,
		"every outbound movement frame retains support and clear actual Player capsule/head")
	_check(not (ship.get_node("MovingInteriorFrame") as MovingInteriorFrame).is_occupant_registered(player) and ship.collision_mask == PhysicsLayers.SHIP_BODY_MASK,
		"walking outside releases automatic moving-frame occupancy")
	print("TITAN_ACCESS: inbound=", inbound, " outbound=", outbound, " final=", player.position)
	ship.set_canopy_open(false, 0.0)
	await _frames(2)
	player.queue_free()
	deck.queue_free()
	controls.queue_free()
	await _frames(2)


func _walk_to(player: PlayerController, target_z: float, action: StringName, limit: int, ship: HeroShip = null) -> Dictionary:
	var report := {"frames": 0, "supported": 0, "clear": 0, "ship_contacts": 0}
	Input.action_press(action)
	for _index in limit:
		await physics_frame
		await process_frame
		_observe_walk_frame(player, ship, report)
		var distance := (player.position.z - target_z) if action == &"move_forward" else (target_z - player.position.z)
		if distance <= 0.04:
			break
		# Release speed through the same ordinary analogue action input, so the
		# controller's deceleration lands at the endpoint without any pose edit.
		Input.action_press(action, 0.4 if distance < 0.8 else 1.0)
	Input.action_release(action)
	for _index in 12:
		await physics_frame
		await process_frame
		_observe_walk_frame(player, ship, report)
	print("TITAN_WALK: target=", target_z, " pose=", player.position, " operands=", report)
	return report


func _observe_walk_frame(player: PlayerController, ship: HeroShip, report: Dictionary) -> void:
	report.frames += 1
	if player.is_on_floor():
		report.supported += 1
	if ship != null:
		var collision := player.get_node("PlayerCollision") as CollisionShape3D
		var capsule := (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.radius -= 0.005
		capsule.height -= 0.01
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = collision.global_transform
		query.collision_mask = PhysicsLayers.SHIP
		query.margin = 0.0
		if player.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			report.clear += 1
		for index in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_collider() == ship:
				report.ship_contacts += 1
				break


func _access_collisions_match(ship: HeroShip) -> bool:
	var pairs := [["ClosedSternBlankCollision", "TitanOriginalShell/ClosedSternBlank"],
		["SternRampFirstCollision", "TitanOriginalShell/SternRampHinge/SternRampFirst"],
		["SternRampToeCollision", "TitanOriginalShell/SternRampHinge/RampToeHinge/SternRampToe"]]
	for pair in pairs:
		var collision := ship.get_node(pair[0]) as CollisionShape3D
		var mesh := ship.get_node(pair[1]) as MeshInstance3D
		if collision.disabled or not collision.global_transform.is_equal_approx(mesh.global_transform):
			return false
		var query := PhysicsShapeQueryParameters3D.new()
		var box := SphereShape3D.new()
		box.radius = 0.015
		query.shape = box
		query.collision_mask = PhysicsLayers.SHIP
		var points := (collision.shape as ConvexPolygonShape3D).points
		var faces := mesh.mesh.get_faces()
		for point in points:
			if not _contains_point(faces, point):
				return false
		for point in faces:
			if not _contains_point(points, point):
				return false
		var center := Vector3.ZERO
		for point in points:
			center += point / points.size()
		query.transform.origin = collision.global_transform * center
		if ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			return false
	return true


func _aisle_clear(ship: HeroShip) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4 - 0.002, 2.5 - 0.002, 14.8 - 0.002)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = ship.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 2.05, 0.6))
	query.collision_mask = PhysicsLayers.SHIP
	query.margin = 0.0
	return ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
