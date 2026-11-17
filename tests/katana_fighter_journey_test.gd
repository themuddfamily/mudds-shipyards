extends SceneTree

## Default: standalone foundation. --access: physical Player port access.
## No Main integration, combat or comparative handling qualification.
## One initial ship/source/player setup; real commands thereafter.
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
	if "--access" in OS.get_cmdline_user_args():
		await _run_access()
		return
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
	if not _check(ship.home_berth_id == &"" and ship.has_node("ShipBoardingArea")
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
		if collision.shape is BoxShape3D:
			var seat := ship.get_node("KatanaOriginalShell/PilotFixture/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
			if not _check((seat.mesh as BoxMesh).size == (collision.shape as BoxShape3D).size and seat.position == collision.position, "physical seat furniture matches visible shape"):
				return false
			continue
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
	if not _check(sections == 20 and envelope.position.is_equal_approx(Vector3(-5.5, 0, -6))
		and envelope.size.is_equal_approx(Vector3(11, 3.8, 12)), "actual authored11x12x3.8 hull/collision envelope"):
		return false
	for i in shapes.size():
		for j in range(i + 1, shapes.size()):
			if _convex_sections_separated(ship, shapes[i], shapes[j]):
				continue
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
	clearance.size = Vector3(1.218, 2.898, 4.498)
	cabin.shape = clearance
	cabin.transform.origin = ship.to_global(Vector3(-0.89, 2.05, 0.25))
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
		_release_inputs()
		Input.action_release("interact")
		Input.action_release("jump")
		Input.action_release("sprint_boost")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		quit(1)
	return false


# A small standalone coordinator composes the same public Player/seat APIs as
# GameFlow. It is deliberately not Main/fleet acceptance.
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


func _run_access() -> void:
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
	_access_ship = KATANA.instantiate()
	fixture.add_child(_access_ship)
	_access_commands = FixtureCommands.new()
	_access_ship.add_child(_access_commands)
	_access_ship.set_command_source(_access_commands)
	_access_player = PLAYER.instantiate()
	_access_player.transform = Transform3D(Basis.IDENTITY,Vector3(-8,0,0))
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
	await _walk_to(Vector3(-8,0,0))
	for cycle in 2:
		await _walk_to(Vector3(-6.6,0,1.6))
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
		await _walk_to(Vector3(-6.6,0,0))
		await _walk_to(Vector3(-0.9,0.6,0))
		if _failed:
			return
		await _interact_edge()
		await _frames(110)
		if not _check(_claim_count == cycle + 1 and _access_player.is_seated_at(_access_ship.get_pilot_seat_anchor()) and _access_area.get_reservation_token() == _access_player and _access_ship.is_piloted() and not _access_ship.is_canopy_open(), "actual exclusive Player seating and normal sealed handoff"):
			return
		var foreign := RefCounted.new()
		if not _check(not _access_area.try_reserve(foreign) and not _access_area.release_reservation(foreign) and _access_area.get_reservation_token() == _access_player, "foreign/duplicate claim cannot steal current seat"):
			return
		var eye := _access_ship.get_node("KatanaOriginalShell/PilotFixture/CockpitCamera") as Camera3D
		if not _check(_access_player.global_position.distance_to(_access_ship.get_pilot_seat_anchor().global_position) < 0.001 and eye.position == Vector3(0,2.31,-1.25) and eye.current, "actual seated anchor and active exact cockpit eye"):
			return
		_access_ship.request_engine_start()
		await _frames(132)
		if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "ordinary sealed start retains 2.3s clock"):
			return
		await _frames(7)
		if not _check(_access_ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "real startup completes after 2.3s"):
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
		await _walk_to(Vector3(-6.6,0,0))
		await _walk_to(Vector3(-6.6,0,1.6))
		await _interact_edge()
		await _frames(26)
		if not _check(not _access_ship.is_canopy_open(), "outside physical Interact seals access again"):
			return
		await _walk_to(Vector3(-8,0,0))
	# Final real-command airborne/OFFLINE negative follows the complete two
	# positive cycles, avoiding any actor/hull reset to set up another case.
	await _walk_to(Vector3(-6.6,0,1.6))
	await _interact_edge()
	await _frames(26)
	await _walk_to(Vector3(-6.6,0,0))
	await _walk_to(Vector3(-0.9,0.6,0))
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
	print("KATANA_FIGHTER_ACCESS_TEST_OK: checks=",_checks," walking_ticks=",_walking_audits," claims=",_claim_count," releases=",_release_count," pending_restore_ticks=",_pending_restore_ticks," transformed=", "--transformed" in OS.get_cmdline_user_args())
	quit(0)


func _on_access_interact() -> void:
	if _access_busy or _failed:
		return
	var local := _access_ship.to_local(_access_player.global_position)
	if local.distance_to(Vector3(-0.9,0.6,0)) < 0.16 and _access_player.get_nearby_interactables().has(_access_area):
		if not _access_area.try_reserve(_access_player):
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
	if not _access_player.begin_disembark(_access_ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-0.9,0.6,0)),0.9,_access_ship):
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


func _trajectory_contract() -> bool:
	var leaves: Array = _access_ship.get("_access_leaves")
	var envelope := AABB(Vector3(-6,0,-6),Vector3(11.5,5.8,12))
	for leaf in leaves:
		for i in leaf.closed.size():
			for fraction in [0.0,0.125,0.25,0.5,0.6,0.75,0.8,0.875,0.9,1.0]:
				var trajectory: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,fraction)
				var point: Vector3 = trajectory[i]
				if not _check(point.x >= envelope.position.x - 0.00001 and point.x <= envelope.end.x + 0.00001 and point.y >= -0.00001 and point.y <= 5.80001 and absf(point.z) <= 6.00001,"complete affine trajectory bounded leaf=" + leaf.mesh.name + " point=" + str(point) + " fraction=" + str(fraction)):
					return false
	print("KATANA_ACCESS_TRAJECTORY: all endpoints and critical fractions bounded; corresponding vertices translate rigidly, complete segment lies in convex envelope")
	return true


func _convex_sections_separated(ship: HeroShip, first: CollisionShape3D, second: CollisionShape3D) -> bool:
	var a := (first.shape as ConvexPolygonShape3D).points
	var b := (second.shape as ConvexPolygonShape3D).points
	for collision in [first,second]:
		var mesh := ship.get_node("KatanaOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
		var faces := mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var normal := (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
			if normal.is_zero_approx():
				continue
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for point in a:
				amin = minf(amin,normal.dot(first.transform*point))
				amax = maxf(amax,normal.dot(first.transform*point))
			for point in b:
				bmin = minf(bmin,normal.dot(second.transform*point))
				bmax = maxf(bmax,normal.dot(second.transform*point))
			if amax <= bmin + 0.00001 or bmax <= amin + 0.00001:
				return true
	return false


func _audit_animated_geometry() -> bool:
	for leaf in _access_ship.get("_access_leaves"):
		var expected: PackedVector3Array = _access_ship.call("_access_leaf_points",leaf,float(_access_ship.get("_access_fraction")))
		var points: PackedVector3Array = leaf.collision.shape.points
		# Inspect the actual render buffer, not get_faces() derived triangle data.
		var vertices: PackedVector3Array = leaf.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if not _check((leaf.mesh.global_transform as Transform3D).is_equal_approx(leaf.collision.global_transform),"actual moving visual/collider global poses agree " + leaf.mesh.name):
			return false
		for point in expected:
			if not (_has_point(points,point) and _has_point(vertices,point) and point.x >= -6.00001 and point.x <= 5.50001 and point.y >= -0.00001 and point.y <= 5.80001 and absf(point.z) <= 6.00001):
				var closest_collision := Vector3(INF,INF,INF)
				var closest_vertex := Vector3(INF,INF,INF)
				for candidate in points:
					if point.distance_squared_to(candidate) < point.distance_squared_to(closest_collision): closest_collision = candidate
				for candidate in vertices:
					if point.distance_squared_to(candidate) < point.distance_squared_to(closest_vertex): closest_vertex = candidate
				print("KATANA_ANIMATED_GEOMETRY_OPERANDS: ", {
					"leaf": leaf.mesh.name, "access_fraction": _access_ship.get("_access_fraction"), "expected_point": point,
					"actual_collision_point": closest_collision, "actual_render_vertex": closest_vertex,
					"collision_distance": point.distance_to(closest_collision), "render_distance": point.distance_to(closest_vertex)})
			if not _check(_has_point(points,point) and _has_point(vertices,point) and point.x >= -6.00001 and point.x <= 5.50001 and point.y >= -0.00001 and point.y <= 5.80001 and absf(point.z) <= 6.00001,"actual animated visible/collider leaf matches bounded trajectory " + leaf.mesh.name):
				return false
		for point in vertices:
			if not _check(_has_point(expected,point),"visible animated vertex belongs to actual collision " + leaf.mesh.name):
				return false
	if float(_access_ship.get("_access_fraction")) > 0.999 and not _access_ship.call("is_access_motion_active"):
		var query := PhysicsShapeQueryParameters3D.new()
		var clearance := BoxShape3D.new()
		clearance.size = Vector3(0.12,2.3,2.0)
		query.shape = clearance
		query.transform = _access_ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-1.5,1.751,0))
		query.collision_mask = PhysicsLayers.SHIP
		query.margin = 0
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual deployed aperture >=2m wide x2.3m high"):
			return false
		clearance.size = Vector3(1.2,2.3,4.48)
		query.transform = _access_ship.global_transform * Transform3D(Basis.IDENTITY,Vector3(-0.89,1.751,0.25))
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual supported1.2m aisle beside physical chair"):
			return false
	if _access_player.is_seated():
		var query := PhysicsShapeQueryParameters3D.new()
		var eye := SphereShape3D.new()
		eye.radius = 0.1
		query.shape = eye
		query.transform = (_access_ship.get_node("KatanaOriginalShell/PilotFixture/CockpitCamera") as Camera3D).global_transform
		query.collision_mask = PhysicsLayers.SHIP
		if not _check(_access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual seated eye remains clear through canopy motion"):
			return false
	return true
