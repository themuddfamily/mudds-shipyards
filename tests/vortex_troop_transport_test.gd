extends SceneTree

## Actual standalone production ship/controller. No Main, test dependencies,
## pose/velocity/time mutation after setup, or physical-access qualification.
const VORTEX := preload("res://scenes/ships/vortex_troop_transport.tscn")
const DEFINITION := preload("res://assets/ships/vortex_provisional.tres")
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
]
const VALUES := {"maximum_speed": 68.0, "boost_speed": 88.0,
	"thrust_acceleration": 20.0, "brake_acceleration": 29.0,
	"passive_drag": 1.85, "throttle_response": 5.5, "boost_multiplier": 1.2,
	"yaw_speed_degrees": 39.0, "roll_speed_degrees": 47.0,
	"flight_assist_strength": 3.6, "visual_bank_degrees": 3.0,
	"maximum_mouse_turn_degrees": 9.0, "engine_start_time": 3.6,
	"weapon_cooldown": 0.62, "maximum_hull": 230.0, "landing_maximum_speed": 10.0}
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
	if not _check(DEFINITION.ship_id == &"vortex_provisional"
		and DEFINITION.display_name == "Vortex-class Troop Transport candidate"
		and DEFINITION.role_name == "Troop transport"
		and DEFINITION.evidence_status == ShipDefinition.EvidenceStatus.PROVISIONAL,
		"exact provisional identity"):
		return
	if not _check(DEFINITION.compatibility_tags == PackedStringArray(["medium_craft", "troop_transport", "vortex_transport"])
		and DEFINITION.get_entry_descriptor() == {"noun": "stern hatch", "open_verb": "open", "close_verb": "seal", "boarding_verb": "board"}
		and DEFINITION.audio_profile_id == &"heavy_quad_freighter"
		and "A3 supports" in DEFINITION.evidence_notes and "B4 corroborates a label string only" in DEFINITION.evidence_notes
		and "original modern" in DEFINITION.evidence_notes and "UNKNOWN" in DEFINITION.evidence_notes,
		"approved entry/audio/tags and honest source boundary"):
		return
	var profiles := {}
	var registered: Array = []
	for definition: ShipDefinition in FLEET:
		profiles[definition.ship_id] = Registry._profile(definition)
		if Registry.get_supported_ship_ids().has(definition.ship_id):
			registered.append(definition)
	if not _check(Registry.audit_definitions(registered).valid, "unchanged registered fleet audit"):
		return
	profiles[DEFINITION.ship_id] = Registry._profile(DEFINITION)
	var errors := PackedStringArray()
	Registry._validate_pairwise_separation(profiles, errors)
	Registry._validate_non_dominance(profiles, errors)
	Registry._validate_signatures(profiles, errors)
	print("VORTEX_COMBINED_FLEET: count=", profiles.size(), " errors=", errors)
	if not _check(errors.is_empty() and profiles.size() == 11, "all current profiles plus Vortex retain14 axes/non-dominance/extrema"):
		return
	var ship := VORTEX.instantiate() as HeroShip
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
		and not ship.call("_uses_inherited_primary_weapon"), "standalone scope has no Main/access/cargo/passenger/combat grants"):
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
	await _frames(210)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "3.6s spool still STARTING after3.5s"):
		return
	await _frames(7)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_ONLINE, "actual inherited spool ONLINE after3.6s"):
		return
	var start := ship.global_transform
	commands.throttle = 1
	await _frames(120)
	var speed := ship.velocity.length()
	print("VORTEX_THRUST: speed=", speed, " displacement=", ship.position - start.origin)
	if not _check(speed > 30 and speed < 38 and ship.position.z < start.origin.z - 25
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
	print("VORTEX_BRAKE: before=", before_brake, " after0.5s=", ship.velocity.length())
	if not _check(ship.velocity.length() < before_brake - 10 and ship.velocity.length() > 0, "actual brake reduces motion"):
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
	await _frames(210)
	if not _check(ship.get("_engine_state") == HeroShip.ENGINE_STARTING, "automatic wake still respects3.6s"):
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
	print("VORTEX_TROOP_TRANSPORT_TEST_OK: ", _checks, " checks")
	quit(0)


func _test_geometry(ship: HeroShip) -> bool:
	var envelope := AABB()
	var first := true
	var sections := 0
	for child in ship.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if not _check(collision.shape is ConvexPolygonShape3D and not collision.disabled, "finite enabled convex section " + collision.name):
			return false
		var shape := collision.shape as ConvexPolygonShape3D
		var mesh := ship.get_node("VortexOriginalShell/" + String(collision.name).trim_suffix("Collision")) as MeshInstance3D
		var points := shape.points
		var faces := mesh.mesh.get_faces()
		for point in points:
			if not _check(point.is_finite() and _has_point(faces, point), "collision vertex on editable mesh " + collision.name):
				return false
		for point in faces:
			if not _check(_has_point(points, point), "mesh vertex on actual collision " + collision.name):
				return false
		var bounds: AABB = collision.transform * shape.get_debug_mesh().get_aabb()
		envelope = bounds if first else envelope.merge(bounds)
		first = false
		sections += 1
	if not _check(sections >= 15 and envelope.position.is_equal_approx(Vector3(-5, 0, -10))
		and envelope.size.is_equal_approx(Vector3(10, 5, 20)), "actual authored10x20x5 hull/collision envelope"):
		return false
	var cabin := PhysicsShapeQueryParameters3D.new()
	var clearance := BoxShape3D.new()
	clearance.size = Vector3(4.398, 2.598, 14.998)
	cabin.shape = clearance
	cabin.transform.origin = Vector3(0, 2.3, 0)
	cabin.collision_mask = PhysicsLayers.SHIP
	cabin.margin = 0
	if not _check(ship.get_world_3d().direct_space_state.intersect_shape(cabin).is_empty(), "reserved cabin has no full-box collider"):
		return false
	var eye := ship.get_node("VortexOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	query.shape = sphere
	query.transform = eye.global_transform
	query.collision_mask = PhysicsLayers.SHIP
	if not _check(ship.get_pilot_seat_anchor().position.is_equal_approx(Vector3(0, 1.45, -6.5))
		and eye.global_transform.is_finite() and ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "exact pilot anchor and clear finite cockpit camera"):
		return false
	print("VORTEX_GEOMETRY: sections=", sections, " bounds=", envelope)
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
		push_error("VORTEX_FAIL: " + label)
		quit(1)
	return false
