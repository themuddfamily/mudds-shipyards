extends SceneTree

## Default: standalone foundation. --access: physical Player port access.
## --main: real Boot/Begin Shift, two sorties, third claim and full reverse route.
## --main --combat: the complete ordinary route plus current-pilot combat/heat/audio.
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
	preload("res://assets/ships/predator_provisional.tres"),
	preload("res://assets/ships/dynamic_provisional.tres"),
	preload("res://assets/ships/utopia_provisional.tres"),
	preload("res://assets/ships/salyut_provisional.tres"),
]
const VALUES := {"maximum_speed": 88.0, "boost_speed": 114.0, "thrust_acceleration": 38.0, "brake_acceleration": 64.0, "passive_drag": 2.4, "throttle_response": 11.0, "boost_multiplier": 1.35, "yaw_speed_degrees": 58.0, "roll_speed_degrees": 98.0, "flight_assist_strength": 5.2, "visual_bank_degrees": 11.0, "maximum_mouse_turn_degrees": 17.0, "engine_start_time": 2.3, "weapon_cooldown": 0.38, "maximum_hull": 145.0, "landing_maximum_speed": 15.0}
var _checks := 0
var _failed := false


class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var brake := false
	var boost := false
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0

	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "brake": brake, "boost": boost, "yaw": yaw, "pitch": pitch, "roll": roll}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--main" in OS.get_cmdline_user_args():
		await _run_main()
		return
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
	if not _check(registered.size() == 7 and Registry.audit_definitions(registered).valid, "exact seven current registered fleet contracts audit"):
		return
	profiles[DEFINITION.ship_id] = Registry._profile(DEFINITION)
	var errors := PackedStringArray()
	Registry._validate_pairwise_separation(profiles, errors)
	Registry._validate_non_dominance(profiles, errors)
	Registry._validate_signatures(profiles, errors)
	print("KATANA_COMBINED_FLEET: count=", profiles.size(), " errors=", errors)
	if not _check(errors.is_empty() and profiles.size() == 17, "all sixteen existing definitions plus Katana retain14 axes/non-dominance/extrema"):
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
	if not await _test_measured_handling(): return
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
		if _main_active: _main_release_inputs()
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
		var camera := _access_ship.get_node("KatanaOriginalShell/PilotFixture/CockpitCamera") as Camera3D
		# Direct-space queries read the published physics snapshot. Compose the
		# unchanged actual local eye into that same root snapshot, including
		# flight/access motion; this never writes actor, hull or camera state.
		var server_root: Transform3D = PhysicsServer3D.body_get_state(_access_ship.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
		var eye_local: Transform3D = _access_ship.global_transform.affine_inverse()*camera.global_transform
		query.transform = server_root*eye_local
		query.collision_mask = (PhysicsLayers.WORLD | PhysicsLayers.SHIP) if _main_active else PhysicsLayers.SHIP
		query.margin = 0
		if not _check(eye_local.origin.is_equal_approx(Vector3(0,2.31,-1.25)) and _access_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"actual seated eye remains clear through canopy motion and flight"):
			return false
	return true


## Ordinary Main integration profile; all original standalone profiles remain.
var _main_started_ms := 0
const BOOT := preload("res://scenes/boot.tscn")
const MAIN_STATION_ROUTE := [
	Vector3(8,0,11), Vector3(8,0,13.5), Vector3(35,0,13.5),
	Vector3(35,0,15.5), Vector3(39,0,15.5), Vector3(47,0,15.5),
	# Return through the accepted Predator aisle around the Habitat connector
	# side rail; preserve the frozen node endpoints without crossing that rail.
	Vector3(39,0,15.5), Vector3(39,0,8.5),
	Vector3(47,0,8.5), Vector3(47,0,7), Vector3(47,0,-8),
	Vector3(64,0,-8), Vector3(64,0,-22), Vector3(64,0,-30), Vector3(65.4,0,-28.4),
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
var _main_combat_records: Array[Dictionary] = []
var _main_stale_probed := false
var _main_heat_probe := false
var _main_heat_ticks: Array[Dictionary] = []
var _main_audio_start := false
var _main_audio_flight := false
var _main_audio_offline := false
var _main_rig: ShipAudioRig
var _main_rig_cues: Array[Dictionary] = []
var _main_fire_cues: Array[Dictionary] = []
var _main_claims := 0
var _main_releases := 0

class MainCompletedPlayerTick:
	extends Node
	signal completed_tick
	var suite: SceneTree
	func _physics_process(_delta: float) -> void:
		suite.call("_main_audit_completed_tick")
		suite.call("_main_observe_heat_tick")
		completed_tick.emit()


func _run_main() -> void:
	_main_started_ms = Time.get_ticks_msec()
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
	_main_ship = _main_game.get_node("KatanaFighter") as HeroShip
	# Reuse the access fixture's actual animated render/collider audit only;
	# no standalone access coordinator is installed in this mode.
	_access_ship = _main_ship
	_access_player = _main_player
	_main_ship.engine_state_changed.connect(func(state: StringName): _main_engine_edges.append({"state":state,"tick":Engine.get_physics_frames(),"remaining":_main_ship.get("_engine_timer")}))
	_main_ship.projectile_fired.connect(func(_origin: Vector3,_direction: Vector3): _main_projectiles += 1)
	_main_game.get_combat_authority().authoritative_shot_submitted.connect(func(request: Variant,result: Dictionary):
		if request.source_entity == _main_ship:
			_main_combat_records.append({"request":request,"result":result.duplicate(true),"tick":Engine.get_physics_frames(),"heat":_main_ship.get("_weapon_heat")})
			_main_shots += 1
			_main_bad_shot = _main_bad_shot or not bool(result.get("accepted",false)) or request.source_id != 1114 or request.weapon_id != GameFlow.ARROW_COMBAT_WEAPON_ID or request.range != 480 or request.damage != 24 or _main_ship.to_local(request.origin).distance_to(Vector3(0,1,-6.2)) > 0.0001)
	_main_rig = _main_ship.get_ship_audio_rig()
	_main_rig.cue_requested.connect(func(cue: StringName,intensity: float,queued: bool):
		_main_rig_cues.append({"cue":cue,"intensity":intensity,"queued":queued,"tick":Engine.get_physics_frames(),"engine":_main_ship.get_telemetry().engine_state}))
	_main_game.get_combat_audio_presentation().cue_started.connect(func(cue: StringName,_voice: StringName,position: Vector3,source: int):
		if source == _main_ship.get_instance_id():
			_main_fire_cues.append({"cue":cue,"position":position,"source":source,"tick":Engine.get_physics_frames()}))
	if not _main_check(_main_rig.get_parent() == _main_ship and _main_rig.get_profile_id() == &"standard_fighter" and not _main_rig.is_engine_running(),"actual Katana standard_fighter rig is bound to same offline ship"): return
	var identity := _main_player.get_instance_id()
	var spawn := _main_player.global_position
	var world := _main_game.world
	var berth := world.get_berth_node(&"katana_home_berth") as ShipBerth
	var dock := berth.get_dock_transform()
	if not _main_check(_main_game.phase == GameFlow.Phase.APPROACH_SHIP and _main_player.is_control_enabled() and _main_player.global_position.distance_to(world.get_player_spawn().origin) < 0.25 and _main_game.get_flyable_ships().size() == 15 and world.get_berth_ids().size() == 15 and berth.get_occupant() == _main_ship and berth.get_reservation_owner() == _main_ship and _main_ship.global_transform.is_equal_approx(dock),"actual normal Main spawn, fifteen flyables and exact occupied Katana home"): return
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
	var profile := _main_game.get_combat_authority().get_weapon_profile(_main_ship,GameFlow.ARROW_COMBAT_WEAPON_ID)
	if not _main_check(profiles.size() == 1 and profiles.has(GameFlow.ARROW_COMBAT_WEAPON_ID) and profile == profiles[GameFlow.ARROW_COMBAT_WEAPON_ID] and profile.get("range") == 480 and profile.get("damage") == 24 and is_equal_approx(_main_ship.weapon_cooldown,0.38) and _main_game.get_combat_authority().get_source_id(_main_ship) == 1114 and (_main_ship.get_node("AuthoritativeDamageable") as LifecycleDamageableAdapter).get_target_entity() == _main_ship and not _main_ship.has_node("MovingInteriorFrame") and not _main_ship.supports_in_flight_cabin_access() and not _main_ship.has_method("get_passenger_station_role_contract"),"actual unique Katana source1114 binds only unchanged24/480/.38 pilot pulse and no cabin frame; no travelling cabin grant"): return
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
		if sortie == 0 and "--combat" in OS.get_cmdline_user_args() and not await _main_stale_combat_refusal(): return
		if not await _main_sortie_home(sortie,identity,area,berth,dock): return
		if not await _main_walk_out(sortie): return
	# A fresh physical third claim proves that the second exit did not strand
	# the body, reservation, camera, input bank or the generic reboard fence.
	if not await _main_board_from_port(2,identity,area): return
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
	if "--combat" in OS.get_cmdline_user_args() and not _main_audio_complete(): return
	if not _main_check(not _main_bad_shot and _main_shots >= 2 and _main_projectiles == _main_shots,"both usable flights emit only real center-muzzle approved pulse with unique source"): return
	await _main_quit_normally()


func _main_board_from_port(sortie: int, identity: int, area: ShipBoardingArea) -> bool:
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"normal look discovers reachable physical port control"): return false
	await _main_tap(&"interact")
	_main_ship.request_engine_start() # Negative moving/open startup probe only.
	if not _main_check(StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"moving access refuses engine start"): return false
	await _main_frames(80)
	_main_ship.request_engine_start()
	if not _main_check(_main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,"full open access refuses startup"): return false
	var generation := _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(not area.is_reserved() and _main_game._transition_generation == generation,"open access outside actual helm still refuses direct boarding"): return false
	for point in [Vector3(-6.6,0,0),Vector3(-0.9,0.6,0)]:
		if not await _main_walk_to(_main_ship.to_global(point),30+sortie,true): return false
	if not _main_check(_main_ship.can_board_from_landed_approach(_main_player),"same full actual Player walks continuously up ramp to fixed supported stand"): return false
	if not _main_check(area.try_reserve(_main_game) and area.try_reserve(_main_game) and not area.try_reserve(_main_player) and not area.release_reservation(_main_player) and area.get_reservation_token() == _main_game,"foreign/duplicate seat requests preserve current temporary claimant"): return false
	if _main_stale_probed and "--combat" in OS.get_cmdline_user_args() and not _main_unseated_combat_refusal(&"foreign"): return false
	await _main_tap(&"interact")
	if not _main_check(not _main_game._piloting and area.get_reservation_token() == _main_game,"foreign-held helm refuses ordinary Interact"): return false
	if not _main_check(area.release_reservation(_main_game) and not area.release_reservation(_main_game),"temporary foreign claim retires once and stale release refuses"): return false
	await _main_aim(_main_ship.get_pilot_seat_anchor().global_position)
	await _main_tap(&"interact")
	for frame in 240:
		if _main_game._piloting and not _main_game._transition_busy: break
		await _main_frames(1)
	if not _main_check(_main_game.active_ship == _main_ship and _main_game._piloting and not _main_game._transition_busy and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _main_player and _main_player.get_instance_id() == identity and not _main_ship.is_canopy_open() and _main_ship.get_camera().current,"actual ordinary E claims seat/camera/input and fully seals Katana sortie="+str(sortie)): return false
	_main_claims += 1
	generation = _main_game._transition_generation
	_main_game._board_ship(_main_ship)
	if not _main_check(_main_game._transition_generation == generation and area.get_reservation_token() == _main_player,"duplicate seated direct boarding cannot replace current transaction"): return false
	var eye := _main_ship.get_node("KatanaOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	if not _main_check(eye.position == Vector3(0,2.31,-1.25) and _main_ship.get_pilot_seat_anchor().position == Vector3(0,0.55,-1) and _main_game.hud._active_ship_name == "KATANA-CLASS FIGHTER CANDIDATE" and _main_game.hud._active_ship_role == "FIGHTER","actual adopted pilot/eye poses and bound candidate HUD identity"): return false
	return true


func _main_sortie_home(sortie: int, identity: int, area: ShipBoardingArea, berth: ShipBerth, dock: Transform3D) -> bool:
	_main_engine_edges.clear()
	Input.action_press(&"move_forward")
	for frame in 500:
		if not bool(_main_ship.get_telemetry().landed) and not _main_ship.get("_departure_lift_active"): break
		await _main_frames(1)
	_main_release_inputs()
	if not _main_check(_main_engine_edges.size() == 2 and _main_engine_edges[0].state == HeroShip.ENGINE_STARTING and _main_engine_edges[1].state == HeroShip.ENGINE_ONLINE and is_equal_approx(float(_main_engine_edges[0].remaining),2.3) and int(_main_engine_edges[1].tick)-int(_main_engine_edges[0].tick) >= 137 and int(_main_engine_edges[1].tick)-int(_main_engine_edges[0].tick) <= 139 and StringName(_main_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE,"actual inherited2.3s startup edges/ticks="+str(_main_engine_edges)): return false
	if not _main_check((_main_ship.global_position-dock.origin).dot(dock.basis.y) >= 3.99 and berth.get_occupant() == null and berth.get_reservation_owner() == null,"actual4m departure lift releases exact own occupied lease"): return false
	await _main_tap(&"interact")
	if not _main_check(_main_game._piloting and _main_player.is_seated_at(_main_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _main_player and not _main_game._transition_busy,"active airborne pilot exit refuses"): return false
	var target := dock*Vector3(0,8,-18)
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
		if frame%180 == 0: print("KATANA_MAIN_FLIGHT: sortie=",sortie," frame=",frame," local=",dock.affine_inverse()*_main_ship.global_position," speed=",_main_ship.velocity.length())
	_main_release_inputs()
	if not _main_check(arrived and turned and _main_game.phase == GameFlow.Phase.FREE_FLIGHT and (dock.affine_inverse()*_main_ship.global_position).distance_to(Vector3(0,8,-18)) <= 0.6 and _main_ship.velocity.length() <= 0.5 and not berth.contains_oriented_bounds(_main_ship.global_transform,_main_ship.get_landing_collision_report().local_bounds),"actual ordinary pitch/throttle/brake flight reaches finite own-home acquisition endpoint"): return false
	if sortie == 0 and "--combat" in OS.get_cmdline_user_args() and not await _main_actual_combat(): return false
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
	if not _main_check(bool(capture.get("assist_capture_accepted",false)) and StringName(capture.get("selected_berth_id",&"")) == &"katana_home_berth","normal capture selects exact own compatible home"): return false
	await _main_tap(&"landing_assist")
	for frame in 600:
		if _main_game.phase == GameFlow.Phase.SHUT_DOWN: break
		await _main_frames(1)
	var landing := _main_ship.get_landing_contract_report()
	if not _main_check(_main_game.phase == GameFlow.Phase.SHUT_DOWN and berth.get_occupant() == _main_ship and berth.get_reservation_owner() == _main_ship and _main_ship.global_position.distance_to(dock.origin) <= 0.05 and _main_ship.velocity.length() <= 0.05 and _main_ship.global_basis.is_equal_approx(dock.basis) and landing.strict_dock_acceptance and landing.contract_accepted and _main_game._ship_owns_exact_occupied_berth(_main_ship,&"katana_home_berth") and berth.contains_oriented_bounds(_main_ship.global_transform,_main_ship.get_landing_collision_report().local_bounds),"normal L restores complete strict hull at exact own dock and current occupied lease"): return false
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
	if not _main_check(not _main_game._piloting and not _main_ship.is_piloted() and not _main_player.is_seated() and _main_player.get_instance_id() == identity and _main_player.is_control_enabled() and _main_player.is_on_floor() and (_main_player.get_node("%PlayerCamera") as Camera3D).current and not _main_ship.get_camera().current and _main_player.collision_layer == _main_layer and _main_player.collision_mask == _main_mask and not (_main_player.get_node("PlayerCollision") as CollisionShape3D).disabled and not area.is_reserved() and _main_game._boarding_area == null and _main_ship.is_canopy_open() and not _main_ship.call("is_access_motion_active") and _main_ship.to_local(_main_player.global_position).distance_to(Vector3(-0.9,0.6,0)) < 0.05 and not bool(_main_player.get_cabin_containment_report().get("active",false)),"normal supported seated-open/inside release restores exact stand, walking body/control/camera and retires claim"): return false
	_main_releases += 1
	if "--combat" in OS.get_cmdline_user_args() and not _main_unseated_combat_refusal(&"released"): return false
	return _main_check(not area.release_reservation(_main_player),"stale released pilot claim cannot act")


func _main_walk_out(sortie: int) -> bool:
	for point in [Vector3(-6.6,0,0),Vector3(-8,0,0),Vector3(-8,0,1.6),Vector3(-6.6,0,1.6)]:
		if not await _main_walk_to(_main_ship.to_global(point),70+sortie,true): return false
	if not _main_check(_main_game._reboard_blocked_ship == null,"physical corridor walk naturally clears unchanged7m reboard fence"): return false
	var hatch := _main_ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	await _main_aim(hatch.global_position)
	if not _main_check(_main_game.station_interaction_candidate == hatch,"standing Player rediscovers actual outside port control"): return false
	await _main_tap(&"interact")
	await _main_frames(80)
	return _main_check(not _main_ship.is_canopy_open() and _main_player.is_on_floor(),"same Player physically walks out port ramp, reaches apron and seals outside full sweep")


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
	print("KATANA_MAIN_ROUTE_LEG: ",leg," target=",target," actual=",_main_player.global_position," reached=",reached)
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
		push_error("KATANA_MAIN_FAIL: "+message)
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
	print("KATANA_MAIN_USER_DATA_DIR: ",OS.get_user_data_dir())
	print("KATANA_FIGHTER_MAIN_TEST_OK",": claims=",_main_claims," releases=",_main_releases," walking_ticks=",_main_ticks," actual_pulse_shots=",_main_shots," elapsed_ms=",Time.get_ticks_msec()-_main_started_ms)
	await _main_key(KEY_ENTER)
	for frame in 120: await process_frame
	_main_check(false,"normal Main Quit did not terminate actual OS process")


func _test_measured_handling() -> bool:
	# One separated placement per real production controller. Thereafter only
	# command sources act: no pose, velocity, clock or handling-value writes.
	var craft: Array[HeroShip] = [KATANA.instantiate() as HeroShip,
		preload("res://scenes/ships/torrent_interceptor.tscn").instantiate() as HeroShip,
		preload("res://scenes/ships/arrow_recon_ship.tscn").instantiate() as HeroShip,
		CinderLightInterceptor.new(),
		preload("res://scenes/ships/zenith_interceptor.tscn").instantiate() as HeroShip]
	var definitions: Array[ShipDefinition] = [DEFINITION,
		preload("res://assets/ships/torrent_provisional.tres"),
		preload("res://assets/ships/arrow_provisional.tres"),
		preload("res://assets/ships/cinder_light_interceptor_new_design.tres"),
		preload("res://assets/ships/zenith_b7_observed.tres")]
	var sources: Array[FixtureCommands] = []
	for index in craft.size():
		craft[index].ship_definition = definitions[index]
		craft[index].position = Vector3(index*2000,500,0)
		root.add_child(craft[index])
		var source := FixtureCommands.new()
		source.brake = true
		craft[index].add_child(source)
		craft[index].set_command_source(source)
		craft[index].set_piloted(true)
		craft[index].request_engine_start()
		sources.append(source)
	await _frames(180)
	for index in craft.size():
		if not _check(craft[index].get_ship_id() == definitions[index].ship_id
			and craft[index].get("_engine_state") == HeroShip.ENGINE_ONLINE,
			"matched fixture uses actual canonical online controller "+str(craft[index].get_ship_id())): return false
		sources[index].brake = false
	var stable := 0
	for tick in 600:
		var matched := true
		for index in craft.size():
			var speed := craft[index].velocity.length()
			# Feedback controls ordinary thrust to balance actual measured speed.
			sources[index].throttle = clampf((craft[index].passive_drag+4.0*(30.0-speed))/craft[index].thrust_acceleration,0,1)
			matched = matched and absf(speed-30.0) <= 0.001
		stable = stable+1 if matched else 0
		if stable >= 12: break
		await _frames(1)
	if not _check(stable >= 12,"all five actual controllers attain common30m/s through normal throttle feedback"): return false
	var origins: Array[Vector3] = []
	var starts: Array[float] = []
	var stopped: Array[Dictionary] = []
	var brake_tick := Engine.get_physics_frames()
	for index in craft.size():
		origins.append(craft[index].global_position)
		starts.append(craft[index].velocity.length())
		stopped.append({})
		sources[index].throttle = 0
		sources[index].brake = true
	for tick in 180:
		await _frames(1)
		var complete := true
		for index in craft.size():
			if stopped[index].is_empty() and craft[index].velocity.length() <= 0.0001:
				stopped[index] = {"id":craft[index].get_ship_id(),"start_tick":brake_tick,
					"start_speed":starts[index],"stop_tick":Engine.get_physics_frames(),
					"distance":craft[index].global_position.distance_to(origins[index]),
					"seconds":float(Engine.get_physics_frames()-brake_tick)/Engine.physics_ticks_per_second,
					"end_speed":craft[index].velocity.length()}
			complete = complete and not stopped[index].is_empty()
		if complete: break
	for index in craft.size():
		print("KATANA_MATCHED_BRAKING: ",stopped[index])
		if not _check(not stopped[index].is_empty() and absf(starts[index]-30.0) <= 0.01,
			"actual matched start and complete stopping measurement "+str(craft[index].get_ship_id())): return false
		if index > 0 and not _check(float(stopped[0].distance) < float(stopped[index].distance)
			and int(stopped[0].stop_tick) < int(stopped[index].stop_tick),
			"Katana actual stopping distance/time beats "+str(craft[index].get_ship_id())): return false
	var attitudes: Array[Quaternion] = []
	var yaw_tick := Engine.get_physics_frames()
	for index in craft.size():
		attitudes.append(craft[index].global_basis.get_rotation_quaternion())
		sources[index].yaw = 1
	await _frames(60)
	var angles: Array[float] = []
	for index in craft.size():
		angles.append(attitudes[index].angle_to(craft[index].global_basis.get_rotation_quaternion()))
		sources[index].yaw = 0
		print("KATANA_MATCHED_YAW: id=",craft[index].get_ship_id()," start_tick=",yaw_tick," end_tick=",Engine.get_physics_frames()," radians=",angles[index])
		if index > 0 and not _check(angles[0] > 0 and angles[0] < angles[index],
			"equal actual yaw command/time leaves Katana slower than "+str(craft[index].get_ship_id())): return false
	for source in sources:
		source.brake = false
		source.throttle = 1
		source.boost = true
	await _frames(480)
	var ceilings: Array[float] = []
	for item in craft: ceilings.append(item.velocity.length())
	await _frames(120)
	for index in craft.size():
		var actual := craft[index].velocity.length()
		print("KATANA_MATCHED_BOOST: id=",craft[index].get_ship_id()," tick=",Engine.get_physics_frames()," prior_speed=",ceilings[index]," speed=",actual)
		if not _check(absf(actual-ceilings[index]) < 0.01 and absf(actual-craft[index].boost_speed) < 0.01,
			"real held full boost reaches stable canonical ceiling "+str(craft[index].get_ship_id())): return false
		if index > 0 and not _check(craft[0].velocity.length() < actual,
			"actual Katana full boost remains lower than "+str(craft[index].get_ship_id())): return false
	for index in craft.size():
		sources[index].throttle = 0
		sources[index].boost = false
		sources[index].brake = true
	await _frames(180)
	for item in craft:
		item.set_piloted(false)
		item.queue_free()
	await _frames(3)
	return true


func _main_new_combat_target(position: Vector3, index: int) -> StaticBody3D:
	var world := _main_game.world
	world.call("_create_target",world,index,world.to_local(position))
	_main_game.get_combat_authority().attach_range_targets(world)
	return world.get_node("TargetDrone%02d" % index) as StaticBody3D


func _main_retire_combat_target(target: StaticBody3D) -> void:
	var targets: Array = _main_game.world.get("_targets")
	targets.erase(target)
	target.queue_free()


func _main_stale_combat_refusal() -> bool:
	# Deliberately precedes every new Katana API call: exact old Main reaches a
	# real registered resolution and fails this damage/ownership assertion.
	var origin := _main_ship.to_global(Vector3(0,1,-6.2))
	var target := _main_new_combat_target(origin+Vector3.UP*30,8001)
	await _main_frames(2)
	var before := _main_shots
	var health := float(target.get_meta("health"))
	var state := [_main_ship.get("_weapon_timer"),_main_ship.get("_weapon_heat")]
	_main_game._on_projectile_fired(origin,(target.global_position-origin).normalized(),_main_ship)
	var result: Dictionary = _main_game.get("_last_player_shot_result")
	print("KATANA_STALE_CALLBACK: source=",_main_game.get_combat_authority().get_source_id(_main_ship)," result=",result," shot_delta=",_main_shots-before," health_before=",health," health_after=",target.get_meta("health"))
	if not _main_check(_main_shots == before and not bool(result.get("accepted",false))
		and float(target.get_meta("health")) == health
		and [_main_ship.get("_weapon_timer"),_main_ship.get("_weapon_heat")] == state,
		"stale callback without synchronous pilot emission cannot resolve or damage actual production target"): return false
	_main_stale_probed = true
	_main_retire_combat_target(target)
	await _main_frames(2)
	return true


func _main_unseated_combat_refusal(label: StringName) -> bool:
	var state := [_main_ship.get("_weapon_timer"),_main_ship.get("_weapon_heat"),_main_shots,_main_projectiles]
	_main_ship.call("_fire_weapon")
	_main_ship.call("_fire_weapon_with_aim",_main_ship.global_position,Vector3.FORWARD)
	_main_game._on_projectile_fired(_main_ship.to_global(Vector3(0,1,-6.2)),Vector3.FORWARD,_main_ship)
	return _main_check(not _main_player.is_seated() and not _main_ship.is_piloted()
		and not bool(_main_ship.call("get_primary_pilot_claim_is_current"))
		and _main_ship.get_weapon_fire_status().get("reason") == &"primary_pilot_required"
		and [_main_ship.get("_weapon_timer"),_main_ship.get("_weapon_heat"),_main_shots,_main_projectiles] == state,
		"ordinary "+String(label)+" unseated pilot cannot emit, resolve, consume heat or cooldown")


func _main_pulse_once() -> Dictionary:
	var count := _main_combat_records.size()
	Input.action_press(&"fire")
	await _main_observer.completed_tick
	await _main_observer.completed_tick
	Input.action_release(&"fire")
	if not _main_check(_main_combat_records.size() == count+1,"one ordinary pilot trigger resolves exactly once"): return {}
	return _main_combat_records.back()


func _main_actual_combat() -> bool:
	Input.action_press(&"brake")
	await _main_frames(90)
	if not _main_check(bool(_main_ship.call("get_primary_pilot_claim_is_current")),"real current pilot retains physical reservation and exact seated anchor before combat"): return false
	var state := [_main_ship.get("_weapon_timer"),_main_ship.get("_weapon_heat"),_main_shots,_main_projectiles]
	_main_ship.call("_fire_weapon_with_aim",_main_ship.global_position,Vector3.FORWARD)
	if not _main_check([_main_ship.get("_weapon_timer"),_main_ship.get("_weapon_heat"),_main_shots,_main_projectiles] == state,"explicit crew aim cannot consume Katana pilot heat, cooldown or damage"): return false
	var camera := _main_ship.get_camera()
	var direction := camera.project_ray_normal(camera.get_viewport().get_visible_rect().size*0.5).normalized()
	var target := _main_new_combat_target(camera.global_position+direction*40,8002)
	var damageable := target.get_node("AuthoritativeDamageable") as RangeTargetDamageableAdapter
	var hits: Array[float] = []
	damageable.damage_applied.connect(func(amount: float,_health: float,_maximum: float,_position: Vector3,_normal: Vector3,_context: Dictionary): hits.append(amount))
	await _main_frames(2)
	var health := damageable.get_health()
	var replay := func(origin: Vector3,aim: Vector3):
		_main_ship.call("_fire_weapon")
		_main_game._on_projectile_fired(origin,aim,_main_ship)
	_main_ship.projectile_fired.connect(replay)
	var event := await _main_pulse_once()
	_main_ship.projectile_fired.disconnect(replay)
	if _failed: return false
	var result: Dictionary = event.result
	if not _main_check(bool(result.get("damaged",false)) and result.get("target_entity") == target
		and float(result.get("applied_damage",0)) == 24 and damageable.get_health() == health-24
		and hits == [24.0] and float(_main_ship.get("_weapon_heat")) > 0
		and not bool((_main_game.get("_last_player_shot_result") as Dictionary).get("accepted",false)),
		"real center pulse source1114 damages production target once; same synchronous callback cannot duplicate health mutation"): return false
	await _main_frames(25)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PhysicsLayers.WORLD
	blocker.collision_mask = 0
	blocker.position = camera.global_position+direction*15
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE*6
	shape.shape = box
	blocker.add_child(shape)
	root.add_child(blocker)
	await _main_frames(2)
	event = await _main_pulse_once()
	if _failed: return false
	if not _main_check(event.result.get("status") == &"world_blocked" and damageable.get_health() == health-24 and hits.size() == 1,"physical world obstruction preserves actual production target health"): return false
	blocker.queue_free()
	_main_retire_combat_target(target)
	await _main_frames(25)
	# The shared resolver sees a physical friendly behind the source hull. Its
	# own collision tree is excluded; the friendly body blocks without damage.
	var friendly := StaticBody3D.new()
	friendly.collision_layer = PhysicsLayers.TARGET
	friendly.collision_mask = 0
	friendly.position = camera.global_position+direction*25
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3
	collision.shape = sphere
	friendly.add_child(collision)
	var friendly_health := Damageable.new()
	friendly_health.faction_id = GameFlow.PLAYER_FACTION
	friendly.add_child(friendly_health)
	root.add_child(friendly)
	await _main_frames(2)
	event = await _main_pulse_once()
	if _failed: return false
	if not _main_check(event.result.get("status") == &"friendly_fire_blocked" and friendly_health.get_health() == 100,"actual pilot friendly hit blocks without changing friendly health"): return false
	var resolver := _main_game.get_combat_resolver()
	var self_health := float(_main_ship.get_telemetry().hull)
	var inside := _main_ship.to_global(Vector3(0,3.5,0))
	var request := ShotRequest.new(_main_ship,1114,GameFlow.PLAYER_FACTION,GameFlow.ARROW_COMBAT_WEAPON_ID,
		resolver.get_last_sequence(_main_ship,1114)+1,inside,(friendly.global_position-inside).normalized(),480,24)
	result = resolver.resolve_hitscan(request)
	if not _main_check(result.get("status") == &"friendly_fire_blocked" and result.get("collider") == friendly
		and float(_main_ship.get_telemetry().hull) == self_health and friendly_health.get_health() == 100,
		"registered Katana compound self collision is excluded while friendly policy preserves both real health owners"): return false
	friendly.queue_free()
	await _main_frames(90)
	event = await _main_pulse_once()
	if _failed: return false
	if not _main_check(not bool(event.result.get("hit",false)) and not bool(event.result.get("damaged",false)),"ordinary pilot empty-space miss has no target damage"): return false
	await _main_frames(90)
	var first := _main_combat_records.size()
	_main_heat_ticks.clear()
	_main_heat_probe = true
	Input.action_press(&"fire")
	for frame in 240:
		await _main_observer.completed_tick
		if bool(_main_ship.get_telemetry().weapon_overheated): break
	if not _main_check(bool(_main_ship.get_telemetry().weapon_overheated),"held actual Katana fire reaches inherited heat lockout"): return false
	var burst := _main_combat_records.slice(first)
	var exact := burst.size() >= 2 and is_equal_approx(float(burst[0].heat),0.28)
	for index in range(1,burst.size()):
		var interval := int(burst[index].tick)-int(burst[index-1].tick)
		exact = exact and interval == 23
		exact = exact and absf(float(burst[index].heat)-minf(1.0,float(burst[index-1].heat)+0.28-0.50*interval/60.0)) < 0.0001
	var count := _main_combat_records.size()
	# Observe the producer's actual emission tick and the completed physics
	# state, rather than a later render/process poll which can skip ticks.
	var locked_tick := int(burst.back().tick)
	for frame in 90:
		if _main_combat_records.size() > count: break
		await _main_observer.completed_tick
	Input.action_release(&"fire")
	_main_heat_probe = false
	if not _main_check(_main_combat_records.size() == count+1,"held fire resumes once after actual heat recovery"): return false
	var resumed: Dictionary = _main_combat_records.back()
	var lockout_ticks := int(resumed.tick)-locked_tick
	for sample in _main_heat_ticks:
		if int(sample.tick) >= locked_tick and bool(sample.overheated):
			exact = exact and int(sample.shots) == count
	for index in range(1,_main_heat_ticks.size()):
		var previous: Dictionary = _main_heat_ticks[index-1]
		var sample: Dictionary = _main_heat_ticks[index]
		if int(sample.shots) == int(previous.shots) and bool(previous.overheated) and bool(sample.overheated):
			exact = exact and int(sample.tick) == int(previous.tick)+1
			exact = exact and absf(float(previous.heat)-float(sample.heat)-0.50/60.0) < 0.0001
	exact = exact and lockout_ticks >= 60 and lockout_ticks <= 61
	exact = exact and absf(float(resumed.heat)-0.28-0.35) < 0.0001
	print("KATANA_ACTUAL_COMBAT: burst=",burst," lockout_ticks=",lockout_ticks," resumed_heat=",resumed.heat," completed_physics_samples=",_main_heat_ticks.size())
	if not _main_check(exact,"actual .38 cadence preserves .28/shot, .50/s cooling, 1s lockout and .35 recovery"): return false
	if not _main_check(bool(resumed.result.get("accepted",false)),"current actual pilot resumes usable pulse after normal recovery"): return false
	await _main_frames(25)
	event = await _main_pulse_once()
	if _failed: return false
	if not _main_check(bool(event.result.get("accepted",false)),"fresh ordinary trigger remains usable after recovered held fire"): return false
	Input.action_release(&"brake")
	return true


func _main_observe_heat_tick() -> void:
	if not is_instance_valid(_main_ship): return
	if _main_heat_probe:
		_main_heat_ticks.append({"tick":Engine.get_physics_frames(),
			"overheated":_main_ship.get("_weapon_overheated"),
			"heat":_main_ship.get("_weapon_heat"),"shots":_main_combat_records.size()})
	if not is_instance_valid(_main_rig): return
	var audio := _main_rig.get_state_snapshot()
	var engine := StringName(_main_ship.get_telemetry().engine_state)
	_main_audio_start = _main_audio_start or (engine == HeroShip.ENGINE_STARTING and not bool(audio.engine_running))
	_main_audio_flight = _main_audio_flight or (engine == HeroShip.ENGINE_ONLINE and bool(audio.engine_running)
		and float(audio.throttle) > 0.05 and _main_ship.velocity.length() > 0.05)
	_main_audio_offline = _main_audio_offline or (_main_shots > 0 and engine == HeroShip.ENGINE_OFFLINE
		and not bool(audio.engine_running) and is_zero_approx(float(audio.throttle)))


func _main_audio_complete() -> bool:
	var startup := 0
	var stop := 0
	for edge in _main_rig_cues:
		if edge.cue == ShipAudioRig.CUE_STARTUP: startup += 1
		if edge.cue == ShipAudioRig.CUE_STOP: stop += 1
	var fire := 0
	for cue in _main_fire_cues:
		if cue.cue != CombatAudioPresentation.CUE_PLAYER_FIRE: continue
		var matched := false
		for event in _main_combat_records:
			var request: ShotRequest = event.request
			if int(event.tick) == int(cue.tick) and request.origin.is_equal_approx(cue.position):
				matched = true
		if not _main_check(matched and int(cue.source) == _main_ship.get_instance_id(),
			"actual fire audio cue uses exact current Katana shot source, position and tick"): return false
		fire += 1
	print("KATANA_ACTUAL_AUDIO: rig=",_main_rig.get_instance_id()," profile=",_main_rig.get_profile_id(),
		" start=",_main_audio_start," flight=",_main_audio_flight," offline=",_main_audio_offline,
		" startup_cues=",startup," stop_cues=",stop," fire_cues=",fire," actual_shots=",_main_shots)
	return _main_check(_main_rig == _main_ship.get_ship_audio_rig() and _main_rig.get_parent() == _main_ship
		and _main_rig.get_profile_id() == &"standard_fighter" and _main_audio_start and _main_audio_flight
		and _main_audio_offline and startup >= 2 and stop >= 2 and fire == _main_shots,
		"same actual standard_fighter rig follows start/flight/offline and production shot audio follows every current pulse")
