extends SceneTree

## Standalone actual-component fixture, deliberately no Main or berth.
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
	var yaw := 0.0
	var fire := false

	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake, "yaw": yaw, "fire": fire}


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
	_check(ship.home_berth_id == &"" and ship.call("_uses_inherited_primary_weapon")
		and ship.has_node("MovingInteriorFrame") and not ship.has_node("ShipBoardingArea"),
		"standalone access has a moving cabin frame, no berth/Main boarding and an inherited pilot cannon")
	_check(ship.to_local((ship.get("_muzzle_left") as Marker3D).global_position).is_equal_approx(Vector3(0, 1.1, -8.9))
		and (ship.get("_muzzle_left") as Marker3D).global_position.is_equal_approx((ship.get("_muzzle_right") as Marker3D).global_position),
		"one co-located centre muzzle at approved coordinates")
	var bore := PhysicsRayQueryParameters3D.create(Vector3(0, 1.1, -8.9), Vector3(0, 1.1, -10), PhysicsLayers.SHIP)
	_check(ship.get_world_3d().direct_space_state.intersect_ray(bore).is_empty()
		and is_equal_approx((ship.get_node("TitanOriginalShell/CentreNoseSill") as MeshInstance3D).get_aabb().position.z, -8.8),
		"actual centre bore clears recessed matching nose skin and collision")
	_test_shell(ship)
	await _test_access(ship)
	await _test_flight(ship)
	await _test_passengers(ship)
	await _test_cabin_floor_roundoff()
	await _test_components()
	ship.set_piloted(false)
	ship.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_cabin_floor_roundoff() -> void:
	var craft := TITAN.instantiate() as HeroShip
	root.add_child(craft)
	craft.set_physics_process(false)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	var cabin := craft.get_in_flight_cabin_report()
	var frame := cabin.frame as MovingInteriorFrame
	var bounds := cabin.local_bounds as AABB
	frame.register_occupant(player, {"require_inside_bounds": false})
	for pose: Transform3D in [Transform3D(Basis.IDENTITY, Vector3(1000, 90, -900)),
			Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, 0.188), Vector3(184.7, 10.29, 38))]:
		craft.global_transform = pose
		player.global_position = craft.to_global(Vector3(0, 0.8, -4.2))
		player.set_cabin_containment(craft, bounds, craft.get_boarding_entry_transform())
		player.call("_resolve_cabin_containment")
		_check(frame.contains_world_position(player.global_position)
			and bool(player.get_cabin_containment_report().contained)
			and int(player.get_cabin_containment_report().recall_count) == 0,
			"actual authored Titan floor survives translated/rotated world-local round trip")
		player.global_position = craft.to_global(Vector3(0, 0.79995, -4.2))
		player.set_cabin_containment(craft, bounds, craft.get_boarding_entry_transform())
		var before := player.global_position
		for _index in 90:
			player.call("_resolve_cabin_containment")
		var report := player.get_cabin_containment_report()
		print("TITAN_FLOOR_ROUNDOFF: ", {"pose": pose, "report": report, "position_unchanged": player.global_position == before})
		_check(frame.contains_world_position(player.global_position) and bool(report.contained)
			and int(report.recall_count) == 0 and int(report.clamp_count) == 0 and player.global_position == before,
			"current translated/rotated Titan floor rounding agrees for admission/report and causes no false recall or pose write")
		for outside: Vector3 in [Vector3(0, 0.799, -4.2), Vector3(-2.701, 0.8, -4.2),
				Vector3(0, 0.8, 7.501), Vector3(0, 3.301, -4.2)]:
			player.global_position = craft.to_global(outside)
			_check(not frame.contains_world_position(player.global_position)
				and not bool(player.get_cabin_containment_report().contained),
				"Titan floor tolerance rejects real1mm fall and keeps walls/ceiling strict: %s" % outside)
		player.global_position = craft.to_global(Vector3(0, 0.799, -4.2))
		player.call("_resolve_cabin_containment")
		_check(int(player.get_cabin_containment_report().recall_count) == 1,
			"actual1mm fall still invokes existing cabin recall")
	player.global_position = craft.to_global(Vector3(0, 0.79995, -4.2))
	frame.set_interior_bounds(AABB(bounds.position + Vector3.UP * 0.01, bounds.size))
	_check(not bool(player.get_cabin_containment_report().contained),
		"changed coordinator bounds cannot relax Player's cached strict containment")
	frame.set_interior_bounds(bounds)
	craft.set("_destroyed", true)
	_check(not bool(player.get_cabin_containment_report().contained),
		"unsupported cabin cannot relax Player's cached strict containment")
	craft.set("_destroyed", false)
	frame.unregister_occupant(player, false)
	_check(not bool(player.get_cabin_containment_report().contained),
		"unregistered body cannot use Titan coordinator floor tolerance")
	player.clear_cabin_containment()
	player.queue_free()
	craft.queue_free()
	await _frames(2)


func _test_components() -> void:
	var anchors := [Vector3(0, 2.6, -8.2), Vector3(-5.4, 2.15, 4),
		Vector3(5.4, 2.15, 4), Vector3(0, 4.75, 0), Vector3(0, 3.9, 8.5)]
	var starts := [Vector3(0, 2.6, -12), Vector3(-9, 2.15, 4),
		Vector3(9, 2.15, 4), Vector3(0, 8, 0), Vector3(0, 3.9, 12)]
	var ends := [Vector3(0, 2.6, -7), Vector3(-5, 2.15, 4),
		Vector3(5, 2.15, 4), Vector3(0, 4, 0), Vector3(0, 3.9, 8)]
	var surfaces := ["ForwardGlazingCollision", "PortEngineBoxCollision",
		"StarboardEngineBoxCollision", "ChamferedRoofCollision", "SternHeaderCollision"]
	var crafts: Array[HeroShip] = []
	var sources: Array[FixtureCommands] = []
	# Independent fixtures spool concurrently through their real unchanged
	# clocks; held brake keeps each ready until its bounded measurement begins.
	for index in ShipComponentDamage.COMPONENT_ORDER.size():
		var craft := TITAN.instantiate() as HeroShip
		craft.position = Vector3(1000 + index * 100, 0, 0)
		root.add_child(craft)
		var source := FixtureCommands.new()
		source.brake = true
		craft.add_child(source)
		craft.set_command_source(source)
		craft.set_piloted(true)
		craft.request_engine_start()
		crafts.append(craft)
		sources.append(source)
	await _frames(205)
	for index in ShipComponentDamage.COMPONENT_ORDER.size():
		var id := ShipComponentDamage.COMPONENT_ORDER[index]
		var craft := crafts[index]
		var source := sources[index]
		source.brake = false
		# Independent fixture craft allow matched controller initial conditions;
		# the ordinary Main journey below never changes Titan pose or velocity.
		source.throttle = 1.0
		await _frames(45)
		craft.velocity = Vector3.ZERO
		craft.global_basis = Basis.IDENTITY
		source.yaw = 0.2
		await _frames(30)
		var healthy_speed := craft.velocity.length()
		var healthy_turn := Quaternion(craft.global_basis).get_angle()
		var model := craft.get_component_damage()
		var presentation := craft.get_damage_presentation()
		var report := model.get_component_report()
		var section := (report.components as Array)[index] as Dictionary
		var extents := (report.local_bounds as AABB).size * 0.5
		var radius := extents.z * 0.55 if index in [0, 4] else (extents.x + extents.z) * 0.28 if index == 3 else extents.x * 0.55
		_check(craft.find_children("*", "ShipComponentDamage", true, false).size() == 1
			and presentation != null and section.local_position == anchors[index]
			and is_equal_approx(section.local_radius, radius), "%s has one ledger, actual geometry anchor and inherited radius" % id)
		if index in [1, 2]:
			source.throttle = 0.0
			source.yaw = 0.0
			source.brake = true
			await _frames(90)
			await _test_fire_cadence(craft, source, [38, 39], "%s healthy" % id)
			source.brake = false
			source.throttle = 1.0
			source.yaw = 0.2
			await _frames(12)
		if index == 3:
			_test_core_aim(craft, 1000.0)
		var ray := PhysicsRayQueryParameters3D.create(craft.to_global(starts[index]), craft.to_global(ends[index]), PhysicsLayers.SHIP)
		var hit := craft.get_world_3d().direct_space_state.intersect_ray(ray)
		var shape_name := ""
		if not hit.is_empty():
			shape_name = str(craft.shape_owner_get_owner(craft.shape_find_owner(int(hit.shape))).name)
		_check(hit.get("collider") == craft and shape_name == surfaces[index], "%s ray strikes its actual authored surface %s" % [id, shape_name])
		if hit.is_empty():
			craft.queue_free()
			await _frames(2)
			continue
		craft.apply_damage(22.0, hit.position, hit.normal)
		await _frames(1)
		_check(model.get_impaired_component_count() == 1 and model.get_component_state(id) == ShipComponentDamage.ComponentState.IMPAIRED
			and presentation.get_active_component_effect_count() == 1
			and presentation.get_component_effect_state(id) == ShipComponentDamage.ComponentState.IMPAIRED,
			"%s actual physical hit impairs only that section and presents its localized cue" % id)
		craft.velocity = Vector3.ZERO
		craft.global_basis = Basis.IDENTITY
		await _frames(30)
		var impaired_speed := craft.velocity.length()
		var impaired_turn := Quaternion(craft.global_basis).get_angle()
		if index in [0, 4]:
			print("TITAN_COMPONENT_MOTION: ", {"id": id, "healthy_speed": healthy_speed,
				"impaired_speed": impaired_speed, "healthy_turn": healthy_turn,
				"impaired_turn": impaired_turn, "turn_ratio": impaired_turn / healthy_turn})
			_check(impaired_speed < healthy_speed * 0.68 and impaired_speed > healthy_speed * 0.50
				and absf(impaired_turn / healthy_turn - 0.62) < 0.01,
				"%s actual matched thrust/steering falls with .62 mobility: speeds %.3f/%.3f turns %.3f/%.3f" % [id, impaired_speed, healthy_speed, impaired_turn, healthy_turn])
		source.throttle = 0.0
		source.yaw = 0.0
		source.brake = true
		await _frames(90)
		if index in [1, 2]:
			await _test_fire_cadence(craft, source, [60, 61], "%s impaired" % id)
		if index == 3:
			_test_core_aim(craft, 734.0)
		# A second real surface contact takes .6 integrity to .2 (FAILED).
		ray = PhysicsRayQueryParameters3D.create(craft.to_global(starts[index]), craft.to_global(ends[index]), PhysicsLayers.SHIP)
		hit = craft.get_world_3d().direct_space_state.intersect_ray(ray)
		craft.apply_damage(22.0, hit.position, hit.normal)
		await _frames(1)
		_check(model.get_component_state(id) == ShipComponentDamage.ComponentState.FAILED
			and presentation.get_component_effect_state(id) == ShipComponentDamage.ComponentState.FAILED,
			"%s second actual contact fails the same physical section" % id)
		if index in [0, 4]:
			craft.velocity = Vector3.ZERO
			craft.global_basis = Basis.IDENTITY
			source.brake = false
			source.throttle = 1.0
			source.yaw = 0.2
			await _frames(30)
			_check(craft.velocity.length() < 0.001 and Quaternion(craft.global_basis).get_angle() < 0.001,
				"%s failed mobility blocks actual thrust and steering" % id)
		elif index in [1, 2]:
			var blocked: Array[int] = []
			var fired := func(_origin: Vector3, _direction: Vector3) -> void: blocked.append(1)
			craft.projectile_fired.connect(fired)
			source.fire = true
			await _frames(90)
			source.fire = false
			_check(blocked.is_empty() and craft.get_weapon_fire_status().reason == &"weapon_component_failed", "%s failed section refuses actual held fire" % id)
			craft.projectile_fired.disconnect(fired)
		else:
			_test_core_aim(craft, 300.0)
		var hull := float(craft.get_telemetry().hull)
		var damaged := model.get_ledger_snapshot()
		craft.set_piloted(false)
		craft.set_piloted(true)
		await _frames(3)
		_check(model.get_ledger_snapshot() == damaged and is_equal_approx(craft.get_telemetry().hull, hull), "%s seat cycle cannot heal hull or component" % id)
		craft.set_piloted(false)
		craft.queue_free()
		await _frames(3)


func _test_fire_cadence(craft: HeroShip, source: FixtureCommands, expected: Array, label: String) -> void:
	var ticks: Array[int] = []
	var fired := func(_origin: Vector3, _direction: Vector3) -> void: ticks.append(Engine.get_physics_frames())
	craft.projectile_fired.connect(fired)
	source.fire = true
	await _frames(125)
	source.fire = false
	craft.projectile_fired.disconnect(fired)
	_check(ticks.size() >= 2 and ticks[1] - ticks[0] in expected,
		"%s actual held-fire cadence has expected physics interval %s: %s" % [label, expected, ticks])


func _test_core_aim(craft: HeroShip, expected_distance: float) -> void:
	# Recover the real shot's convergence distance from the distinct camera and
	# muzzle lines. This exercises emitted aim, rather than checking a multiplier.
	craft.set("_weapon_timer", 0.0)
	var shots: Array[Dictionary] = []
	var fired := func(origin: Vector3, direction: Vector3) -> void: shots.append({"origin": origin, "direction": direction})
	craft.projectile_fired.connect(fired)
	craft.call("_fire_weapon")
	craft.projectile_fired.disconnect(fired)
	var distance := -1.0
	if shots.size() == 1:
		var camera := craft.get_camera()
		var camera_direction := camera.project_ray_normal(camera.get_viewport().get_visible_rect().size * 0.5).normalized()
		var shot_direction := shots[0].direction as Vector3
		var cross := camera_direction.cross(shot_direction)
		distance = ((shots[0].origin as Vector3) - camera.global_position).cross(shot_direction).dot(cross) / cross.length_squared()
	_check(absf(distance - expected_distance) < 1.0, "core stage changes actual emitted aim convergence to %.1fm (measured %.3f)" % [expected_distance, distance])


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
	void_box.size = Vector3(1.4, 2.5, 14.3) - Vector3.ONE * 0.002
	query.shape = void_box
	query.margin = 0.0
	query.transform = Transform3D(Basis.IDENTITY, TITAN_SCRIPT.CABIN_VOID.get_center())
	query.collision_mask = PhysicsLayers.SHIP
	_check(ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
		"actual physics leaves central 1.4m aisle clear above 0.8m floor for 2.5m headroom")
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
	_check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "sealed fixture pilot intent begins approved timed propulsion startup")
	await _frames(205)
	_check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "sealed fixture pilot intent completes inherited 3.4s propulsion startup")
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


func _test_passengers(ship: HeroShip) -> void:
	var frame := ship.call("get_interior_frame") as MovingInteriorFrame
	var seats: Array[ShipCrewSeat] = []
	var players: Array[PlayerController] = []
	for index in 2:
		var id: StringName = TITAN_SCRIPT.PASSENGER_IDS[index]
		var anchor := ship.get_node("TitanOriginalShell/" + String(id)) as Marker3D
		var seat := anchor.get_node("SoloPassengerSeatInteraction") as ShipCrewSeat
		seats.append(seat)
		_check(seat.get_role_contract().get("seat_id") == id and seat.get_role() == &"passenger"
			and anchor.position.is_equal_approx(Vector3(-2 if index == 0 else 2, 0.75, 1.8)),
			"anchor-specific physical ordinary passenger contract " + String(id))
		var actor := preload("res://scenes/player/player.tscn").instantiate() as PlayerController
		# One setup pose per actual body. Every subsequent displacement comes
		# from the existing transition, locomotion and real ship/frame owners.
		actor.transform = seat.get_entry_transform()
		root.add_child(actor)
		actor.set_control_enabled(false)
		players.append(actor)
	await _frames(10)
	var unsealed := CrewSeatRoleAuthority.new(1)
	_check(not bool(ship.call("attach_crew_role_authority", unsealed).get("accepted", false))
		and ship.call("get_crew_role_authority") == null, "unsealed authority cannot attach or mutate Titan")
	for changed_field in ["vessel_id", "seat_id", "role", "frame_id", "anchor_id", "seat_generation"]:
		var wrong := CrewSeatRoleAuthority.new(1)
		for record in ship.call("_crew_seat_records"):
			var identity := {"seat_id": record.seat_id, "vessel_id": ship.get_ship_id(), "role": record.role,
				"frame_id": TITAN_SCRIPT.CREW_FRAME_ID, "seat_generation": 1, "anchor_id": record.anchor_id}
			if record.seat_id == TITAN_SCRIPT.PASSENGER_IDS[0]:
				identity[changed_field] = 2 if changed_field == "seat_generation" else (&"pilot" if changed_field == "role" else &"wrong_identity")
			wrong.register_seat(identity.seat_id, identity.vessel_id, identity.role, identity.frame_id, identity.seat_generation, identity.anchor_id)
		wrong.seal_roster([&"pilot", &"passenger"])
		var before := wrong.get_snapshot()
		_check(not bool(ship.call("attach_crew_role_authority", wrong).get("accepted", false))
			and ship.call("get_crew_role_authority") == null and wrong.get_snapshot() == before,
			"wrong Titan roster " + changed_field + " refuses without mutation")
	var authority := CrewSeatRoleAuthority.new(1)
	_check(bool(ship.call("register_crew_seat_roster", authority).accepted) and bool(ship.call("attach_crew_role_authority", authority).accepted)
		and (authority.get_snapshot().seats as Array).size() == 3,
		"one exact sealed pilot and two-passenger ledger attaches")
	for index in 2:
		var avatar := StringName("fixture_passenger_" + str(index))
		_check(authority.claim(1, 1, avatar, seats[index].get_seat_id(), &"passenger", index + 1).accepted,
			"separate body claims separate chair " + str(index))
		frame.unregister_occupant(players[index], false, &"seat_handoff")
		_check(ship.attach_solo_crew_role_occupant(avatar, seats[index], players[index]).accepted,
			"shared production occupant handoff attaches actual body " + str(index))
		_check(players[index].begin_boarding(seats[index].get_entry_transform(), seats[index].get_seat_anchor(), 0.75, ship),
			"existing Player begins ordinary passenger transition")
	await _frames(50)
	_check(players[0] != players[1] and players[0].is_seated_at(seats[0].get_seat_anchor())
		and players[1].is_seated_at(seats[1].get_seat_anchor()) and frame.get_occupant_count() == 2,
		"two real Players are simultaneously seated and carried at distinct chairs")
	var before := authority.get_snapshot()
	_check(not authority.claim(1, 2, &"duplicate", seats[0].get_seat_id(), &"passenger", 1).accepted
		and not authority.release(1, 1, &"fixture_passenger_0", seats[0].get_seat_id(), 3, 2).accepted
		and not authority.release(1, 1, &"fixture_passenger_0", seats[0].get_seat_id(), 1, 1).accepted
		and authority.get_snapshot() == before, "occupied, stale sequence and stale generation refuse without ledger mutation")
	var metadata := players[0].get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
	_check(not ship.release_solo_crew_role_occupant(&"wrong_avatar", seats[0].get_seat_id(), players[0], 3, 1, authority).accepted
		and not ship.release_solo_crew_role_occupant(&"fixture_passenger_0", seats[1].get_seat_id(), players[0], 3, 1, authority).accepted
		and not ship.release_solo_crew_role_occupant(&"fixture_passenger_0", seats[0].get_seat_id(), players[0], 3, 2, authority).accepted
		and players[0].get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) == metadata and authority.get_snapshot() == before,
		"wrong identity/anchor/generation cannot release body, metadata or current claim")
	_check(not ship.call("detach_crew_role_authority", authority), "occupied authority cannot detach")
	var controls := FixtureCommands.new()
	ship.add_child(controls)
	ship.set_command_source(controls)
	ship.set_piloted(true)
	ship.request_engine_start()
	await _frames(205)
	var origin := ship.global_transform
	controls.throttle = 0.18
	controls.yaw = 0.12
	await _frames(45)
	for index in 2:
		_check(players[index].begin_disembark(seats[index].get_exit_transform(), 0.65, ship), "real moving Player stand transition starts")
	await _frames(45)
	for index in 2:
		var avatar := StringName("fixture_passenger_" + str(index))
		_check(ship.release_solo_crew_role_occupant(avatar, seats[index].get_seat_id(), players[index], index + 3, 1, authority).accepted,
			"normal supported stand releases exact passenger metadata and claim")
		frame.register_occupant(players[index], {"require_inside_bounds": true})
		players[index].set_cabin_containment(ship, TITAN_SCRIPT.CABIN_VOID, seats[index].get_exit_transform())
	await _frames(5)
	_check(players[0].get_cabin_containment_report().get("active", false)
		and players[1].get_cabin_containment_report().get("active", false)
		and players[0].get_cabin_containment_report().get("frame") == ship
		and players[1].get_cabin_containment_report().get("frame") == ship,
		"both actually moving stood passengers retain their in-flight containment")
	_check(players[0].is_on_floor() and players[1].is_on_floor()
		and ship.to_local(players[0].global_position).distance_to(Vector3(-0.9, 0.8, 1.8)) < 0.08
		and ship.to_local(players[1].global_position).distance_to(Vector3(0.9, 0.8, 1.8)) < 0.08,
		"both stood bodies remain supported at own entry while actual Titan translates/rotates")
	for index in 2:
		players[index].set_control_enabled(true)
		var local_target := Vector3(-0.9 if index == 0 else 0.9, 0.8, 0.5)
		_check(await _walk_local_passenger(players[index], ship, local_target), "moving passenger physically walks over one metre with clear supported capsule")
		_check(await _walk_local_passenger(players[index], ship, Vector3(local_target.x, 0.8, 1.8)), "moving passenger physically returns to own chair entry")
		players[index].set_control_enabled(false)
		players[index].clear_cabin_containment()
		frame.unregister_occupant(players[index], false, &"reseat_handoff")
		var avatar := StringName("fixture_passenger_" + str(index))
		_check(authority.claim(1, 1, avatar, seats[index].get_seat_id(), &"passenger", index + 5).accepted
			and ship.attach_solo_crew_role_occupant(avatar, seats[index], players[index]).accepted
			and players[index].begin_boarding(seats[index].get_entry_transform(), seats[index].get_seat_anchor(), 0.75, ship),
			"same body reseats through existing owners on moving Titan")
		await _frames(50)
	_check(ship.global_position.distance_to(origin.origin) > 2 and not ship.global_basis.is_equal_approx(origin.basis)
		and players[0].is_seated_at(seats[0].get_seat_anchor()) and players[1].is_seated_at(seats[1].get_seat_anchor()),
		"real controller translation/rotation carries both reseated passengers without test pose writes")
	controls.throttle = 0
	controls.yaw = 0
	controls.brake = true
	await _frames(120)
	controls.brake = false
	await _frames(95)
	var pilot := preload("res://scenes/player/player.tscn").instantiate() as PlayerController
	pilot.transform = ship.get_boarding_entry_transform()
	root.add_child(pilot)
	pilot.set_control_enabled(false)
	var area := ShipBoardingArea.new()
	area.name = "ShipBoardingArea"
	ship.add_child(area)
	_check(area.try_reserve(pilot) and authority.claim(1, 1, &"fixture_pilot", &"pilot_station", &"pilot", 9).accepted
		and pilot.begin_boarding(ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.75, ship),
		"third actual local Player claims and boards real pilot station")
	frame.unregister_occupant(pilot, false, &"pilot_seat_handoff")
	frame.register_occupant(pilot, {"require_inside_bounds": true})
	ship.set_piloted(true)
	pilot.set_camera_active(false)
	await _frames(50)
	var occupied_before := ship.get_telemetry()
	var claims_before := authority.get_snapshot()
	_check(pilot.is_seated_at(ship.get_pilot_seat_anchor()) and players[0].is_seated_at(seats[0].get_seat_anchor())
		and players[1].is_seated_at(seats[1].get_seat_anchor()) and frame.get_occupant_count() == 3
		and ship.get_camera().current and not ship.preflight_reset_for_reuse(ship.global_transform).accepted
		and ship.get_telemetry() == occupied_before and authority.get_snapshot() == claims_before and area.get_reservation_token() == pilot,
		"three actual occupied roles/camera reject reset before hull, claims or reservations mutate")
	# A supported recovery apron is independent of the destroyed moving hull.
	var recovery_deck := StaticBody3D.new()
	recovery_deck.collision_layer = PhysicsLayers.WORLD
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(12, 1, 12)
	collision.shape = floor_shape
	collision.position = Vector3(-50, -0.5, 0)
	recovery_deck.add_child(collision)
	root.add_child(recovery_deck)
	var recovery := Transform3D(Basis.IDENTITY, Vector3(-50, 0, 0))
	var recover := func(_position: Vector3, _velocity: Vector3) -> void: ship.call("recover_destroyed_local_occupants", recovery)
	ship.destroyed.connect(recover)
	controls.throttle = 0.18
	controls.yaw = 0.12
	ship.request_engine_start()
	await _frames(210)
	var death_pose := ship.global_transform
	_check(ship.velocity.length() > 0.1 and pilot.is_seated() and players[0].is_seated() and players[1].is_seated(),
		"all three actual claimed bodies are aboard moving Titan before terminal production damage")
	ship.apply_damage(220)
	controls.throttle = 0
	controls.yaw = 0
	await _frames(8)
	_check(ship.is_destroyed() and not ship.is_piloted() and not ship.get_camera().current
		and not area.is_reserved() and frame.get_occupant_count() == 0
		and (authority.get_snapshot().assignments as Array).is_empty() and ship.call("get_crew_role_authority") == null,
		"terminal production damage releases all three claims, helm camera and frame bodies")
	var all_recovered := true
	for actor: PlayerController in [pilot, players[0], players[1]]:
		all_recovered = all_recovered and not actor.is_seated() and actor.is_control_enabled() and actor.is_on_floor() \
			and not actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and not actor.get_cabin_containment_report().active \
			and actor.global_position.distance_to(recovery.origin) < 2
	_check(all_recovered, "all three local Players recover as supported on-foot bodies with cleared containment/metadata")
	var generation_after := int(ship.get("_crew_generation"))
	ship.call("recover_destroyed_local_occupants", recovery)
	_check(int(ship.get("_crew_generation")) == generation_after
		and not ship.call("attach_crew_role_authority", authority).accepted
		and not ship.attach_solo_crew_role_occupant(&"fixture_passenger_0", seats[0], players[0]).accepted,
		"duplicate loss is inert and old role/body requests cannot reacquire dead Titan")
	var proof := ship.preflight_reset_for_reuse(death_pose)
	# A real occupant appearing after preflight invalidates commit atomically.
	var late_body := Node3D.new()
	root.add_child(late_body)
	late_body.global_position = ship.to_global(Vector3(0, 0.8, 0))
	frame.register_occupant(late_body, {"require_inside_bounds": true})
	var dead_before := ship.get_telemetry()
	var stale_commit := ship.commit_reset_for_reuse(proof)
	_check(proof.accepted and not stale_commit.accepted and ship.get_telemetry() == dead_before
		and frame.is_occupant_registered(late_body) and area.get_reservation_token() == null,
		"current receipt with newly occupied frame refuses before any reset mutation")
	frame.unregister_occupant(late_body, false, &"fixture_cleanup")
	late_body.queue_free()
	_check(ship.reset_for_reuse(death_pose).accepted and not ship.is_destroyed()
		and not ship.call("attach_crew_role_authority", authority).accepted,
		"empty current reset restores hull while old-generation roster remains rejected")
	var fresh_authority := CrewSeatRoleAuthority.new(1)
	_check(ship.call("register_crew_seat_roster", fresh_authority).accepted
		and ship.call("attach_crew_role_authority", fresh_authority).accepted
		and int(fresh_authority.get_snapshot().seats[0].seat_generation) == generation_after,
		"regenerated chairs publish one fresh generation through existing role authority")
	ship.destroyed.disconnect(recover)
	for index in 2:
		players[index].queue_free()
	pilot.queue_free()
	recovery_deck.queue_free()
	area.queue_free()
	_check(ship.call("detach_crew_role_authority", fresh_authority), "empty fixture ledger detaches cleanly")
	controls.queue_free()
	await _frames(3)


func _walk_local_passenger(player: PlayerController, ship: HeroShip, target: Vector3) -> bool:
	var report := {"frames": 0, "supported": 0, "clear": 0, "ship_contacts": 0}
	var reached := false
	for tick in 180:
		var offset := ship.to_global(target) - player.global_position
		offset = offset.slide(ship.global_basis.y)
		if offset.length() < 0.035:
			reached = true
			break
		var direction := (player.get_node("%CameraYaw") as Node3D).global_basis.inverse() * offset.normalized()
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		var strength := 0.4 if offset.length() < 0.8 else 1.0
		Input.action_press(&"move_right" if direction.x > 0 else &"move_left", absf(direction.x) * strength)
		Input.action_press(&"move_back" if direction.z > 0 else &"move_forward", absf(direction.z) * strength)
		await _frames(1)
		_observe_walk_frame(player, ship, report)
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	await _frames(12)
	print("TITAN_PASSENGER_WALK: local=", ship.to_local(player.global_position), " target=", target, " report=", report)
	return reached and report.frames > 10 and report.supported == report.frames and report.clear == report.frames
