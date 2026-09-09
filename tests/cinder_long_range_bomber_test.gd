extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var bomber := Bomber.new()
	root.add_child(bomber)
	await process_frame
	_test_recessed_exhaust(bomber)
	_test_service_cassettes(bomber)
	var audit := bomber.get_audit_report()
	var definition := bomber.get_ship_definition()
	_check(bool(audit.get("valid", false)), "the bomber builds a valid collision and payload contract")
	_check(
		definition != null
		and definition.is_definition_valid()
		and definition.get_ship_id() == &"cinder_long_range_bomber"
		and is_equal_approx(bomber.maximum_speed, definition.maximum_speed)
		and is_equal_approx(bomber.engine_start_time, definition.engine_start_time)
		and is_equal_approx(bomber.maximum_hull, definition.maximum_hull),
		"the live bomber consumes its authored 72 m/s, 3.6 s startup, and 240-hull profile"
	)
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the bomber makes no historical claim")
	_check(bomber.get_cockpit_seat_anchor() != null and bomber.get_boarding_marker() != null, "the bomber exposes physical cockpit and boarding anchors")
	_check(bomber.get_payload_hardpoints().size() == 4, "the bomber exposes four caller-owned payload hardpoints")
	_check(bool(bomber is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("ordnance_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or ordnance authority")
	var visual := bomber.get_variant_visual_root()
	var hull := visual.get_node_or_null(^"LongRangeHull") as MeshInstance3D
	var fairing := visual.get_node_or_null(^"CockpitSupportFairing") as MeshInstance3D
	var cockpit_floor := visual.get_node_or_null(^"CockpitInterior/CockpitFloor") as MeshInstance3D
	var fairing_mesh := fairing.mesh as ArrayMesh if fairing != null else null
	var hull_mesh := hull.mesh as ArrayMesh if hull != null else null
	var cockpit_floor_mesh := cockpit_floor.mesh if cockpit_floor != null else null
	_check(
		fairing != null
		and fairing_mesh != null
		and fairing.position.is_equal_approx(CinderLongRangeBomber.COCKPIT_SUPPORT_FAIRING_POSITION)
		and fairing_mesh.get_aabb().size.is_equal_approx(Vector3(3.9, 1.416, 6.8)),
		"the bomber builds the exact closed cockpit support fairing"
	)
	var hull_top := hull.position.y + hull_mesh.get_aabb().size.y * 0.5 \
			if hull != null and hull_mesh != null else INF
	var fairing_bottom := fairing.position.y + fairing_mesh.get_aabb().position.y \
			if fairing != null and fairing_mesh != null else INF
	var fairing_top := fairing.position.y + fairing_mesh.get_aabb().end.y \
			if fairing != null and fairing_mesh != null else -INF
	var cockpit_floor_bottom := cockpit_floor.position.y + cockpit_floor.get_aabb().position.y \
			if cockpit_floor != null and cockpit_floor_mesh != null else -INF
	var hull_overlap := hull_top - fairing_bottom
	var cockpit_overlap := fairing_top - cockpit_floor_bottom
	_check(
		hull_overlap > 0.02
		and absf(cockpit_overlap - 0.02) <= 0.0001,
		"the continuous shoulder enters the hull and seats 20 mm into the cockpit floor (%.4f m / %.4f m)" % [
			hull_overlap, cockpit_overlap
		]
	)
	_check(
		fairing != null
		and hull != null
		and fairing_mesh != null
		and fairing.visible
		and fairing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and fairing.material_override == hull.material_override
		and not fairing_mesh.resource_local_to_scene
		and fairing.get_child_count() == 0
		and fairing.get_script() == null
		and fairing.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the fairing is one shared hull-material renderer with no collision or gameplay authority"
	)
	var sensor_audit := bomber.get_sensor_resource_sharing_audit()
	_check(
		bool(sensor_audit.get("valid", false))
		and bool(sensor_audit.get("chase_retains_sensor", false))
		and bool(sensor_audit.get("cockpit_omits_sensor", false)),
		"the fairing leaves the exterior sensor and cockpit/chase layer split unchanged"
	)
	bomber.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_long_range_bomber_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _test_recessed_exhaust(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	var port := visual.get_node("PortGuideVanes") as MultiMeshInstance3D
	var starboard := visual.get_node("StarboardGuideVanes") as MultiMeshInstance3D
	var hub := visual.get_node("PortThrustPlug") as MeshInstance3D
	var lip := visual.get_node("PortNozzleLip") as MeshInstance3D
	var annulus := visual.get_node("PortCombustorAnnulus") as MeshInstance3D
	var bell := visual.get_node("PortExhaustBell") as MeshInstance3D
	var opposite_bell := visual.get_node("StarboardExhaustBell") as MeshInstance3D
	_check(port.multimesh.mesh is ArrayMesh and port.multimesh.instance_count == 12
		and port.multimesh.mesh == starboard.multimesh.mesh and bell.mesh == opposite_bell.mesh,
		"formed bells and twelve curved stator vanes retain immutable mesh sharing across paired engines")
	var vane_bounds := port.transform * port.multimesh.mesh.get_aabb()
	var hub_bounds := hub.transform * hub.mesh.get_aabb()
	_check(vane_bounds.end.z < lip.position.z and hub_bounds.end.z < lip.position.z
		and vane_bounds.size.z > port.scale.z * 0.2,
		"thick stator airfoils and the turned hub remain recessed inside the open bell")
	_check(not (annulus.material_override as StandardMaterial3D).emission_enabled
		and not (hub.material_override as StandardMaterial3D).emission_enabled
		and port.get_script() == null and hub.get_script() == null,
		"unpowered machinery has a passive metallic finish and adds no engine-state controller")


func _test_service_cassettes(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	for tag in ["ThermalService", "RamScoop/Scoop"]:
		var port := visual.get_node("Port" + tag + "Frame") as MeshInstance3D
		var starboard := visual.get_node("Starboard" + tag + "Frame") as MeshInstance3D
		var vanes := visual.get_node("Port" + tag + "Vanes") as MeshInstance3D
		var opposite_vanes := visual.get_node("Starboard" + tag + "Vanes") as MeshInstance3D
		var backing := visual.get_node("Port" + tag + "Recess") as MeshInstance3D
		_check(port.mesh is ArrayMesh and vanes.mesh is ArrayMesh
			and port.mesh == starboard.mesh and vanes.mesh == opposite_vanes.mesh
			and backing.mesh == (visual.get_node("Starboard" + tag + "Recess") as MeshInstance3D).mesh,
			"paired %s cassettes share their three immutable renderer stocks" % tag)
		_check(vanes.mesh.get_faces().size() == 960 and port.mesh.get_faces().size() > 36
			and port.material_override != null and vanes.material_override != null
			and port.get_script() == null and port.get_child_count() == 0,
			"%s has five closed curved vanes and a continuous frame without gameplay nodes" % tag)
		var foot := visual.global_transform.affine_inverse() * port.global_transform * port.mesh.get_aabb()
		_check(foot.position.y < 1.18 and foot.end.y > 1.18
			and foot.position.z > -2.8 and foot.end.z < 3.8,
			"%s frame foot seats into the shoulder crown clear of nose optics and payload lanes" % tag)
	_check(visual.find_children("*Louver*", "MeshInstance3D", true, false).is_empty()
		and visual.find_children("*ThermalServiceRim*", "MeshInstance3D", true, false).is_empty(),
		"service grilles replace the former stacked bars and separate rails")
