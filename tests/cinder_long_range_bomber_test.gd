extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var bomber := Bomber.new()
	root.add_child(bomber)
	await process_frame
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
	var fairing_mesh := fairing.mesh as BoxMesh if fairing != null else null
	var hull_mesh := hull.mesh as BoxMesh if hull != null else null
	var cockpit_floor_mesh := cockpit_floor.mesh if cockpit_floor != null else null
	_check(
		fairing != null
		and fairing_mesh != null
		and fairing.position.is_equal_approx(CinderLongRangeBomber.COCKPIT_SUPPORT_FAIRING_POSITION)
		and fairing_mesh.size.is_equal_approx(CinderLongRangeBomber.COCKPIT_SUPPORT_FAIRING_SIZE),
		"the bomber builds the exact closed cockpit support fairing"
	)
	var hull_top := hull.position.y + hull_mesh.size.y * 0.5 \
			if hull != null and hull_mesh != null else INF
	var fairing_bottom := fairing.position.y - fairing_mesh.size.y * 0.5 \
			if fairing != null and fairing_mesh != null else INF
	var fairing_top := fairing.position.y + fairing_mesh.size.y * 0.5 \
			if fairing != null and fairing_mesh != null else -INF
	var cockpit_floor_bottom := cockpit_floor.position.y + cockpit_floor.get_aabb().position.y \
			if cockpit_floor != null and cockpit_floor_mesh != null else -INF
	var hull_overlap := hull_top - fairing_bottom
	var cockpit_overlap := fairing_top - cockpit_floor_bottom
	_check(
		absf(hull_overlap - 0.02) <= 0.0001
		and absf(cockpit_overlap - 0.02) <= 0.0001,
		"the closed fairing seats 20 mm into both hull and cockpit floor (%.4f m / %.4f m)" % [
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
