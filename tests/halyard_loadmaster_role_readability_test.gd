extends SceneTree

## Focused presentation contract for the first port-row Halyard loadmaster seat.
## The plaque must read from an ordinary cabin-aisle distance by text and shape,
## while leaving the existing seat, moving frame, collision, lights, and evidence
## classification untouched.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var anchor := craft.get_loadmaster_station_anchor()
	var sign := craft.get_node_or_null(^"LoadmasterStationSign") as Label3D
	var panel := craft.get_node_or_null(^"LoadmasterStationWayfindingPanel") as MeshInstance3D
	var role_key := craft.get_node_or_null(^"LoadmasterStationRoleKey") as MeshInstance3D
	_check(
		anchor != null and sign != null and panel != null and role_key != null,
		"the existing port-row loadmaster seat carries one complete wayfinding plaque"
	)
	_check(
		sign != null
			and sign.text.begins_with("LOADMASTER // CARGO")
			and sign.text.contains("[STANDBY]")
			and sign.font_size == 56
			and is_equal_approx(sign.pixel_size, 0.0024)
			and sign.outline_size >= 10
			and not sign.no_depth_test
			and not sign.double_sided
			and not sign.fixed_size,
		"the role name reads at 4.5 m without bleeding through the pressure hull"
	)
	_check(
		panel != null
			and panel.mesh != null
			and panel.mesh.get_aabb().size.is_equal_approx(
				HalyardCrewTransport.LOADMASTER_WAYFINDING_PANEL_SIZE
			)
			and panel.get_meta("color_independent", false),
		"the dark backing silhouette separates the lettering from the working cabin"
	)
	_check(
		role_key != null
			and role_key.mesh != null
			and role_key.mesh.get_aabb().size.is_equal_approx(
				HalyardCrewTransport.LOADMASTER_WAYFINDING_ROLE_KEY_SIZE
			)
			and role_key.get_meta("shape_role", &"") == &"full_height_port_bar",
		"a full-height port bar identifies the station without relying on colour"
	)
	var snapshot := craft.get_loadmaster_station_display_snapshot()
	_check(
		snapshot.get("wayfinding_role", &"") == &"loadmaster"
			and is_equal_approx(
				float(snapshot.get("readability_distance_m", 0.0)),
				HalyardCrewTransport.LOADMASTER_WAYFINDING_READABILITY_DISTANCE_M
			)
			and bool(snapshot.get("color_independent", false))
			and bool(snapshot.get("presentation_only", false)),
		"the detached snapshot publishes only the measured presentation contract"
	)
	if anchor != null and panel != null:
		var expected := anchor.global_position + anchor.global_basis.orthonormalized() \
				* HalyardCrewTransport.LOADMASTER_WAYFINDING_LOCAL_OFFSET
		_check(
			panel.global_position.distance_to(expected) < 0.002,
			"the plaque stays directly above the real loadmaster seat-back"
		)
	_check(
		(panel.find_children("*", "CollisionShape3D", true, false).is_empty() if panel != null else false)
			and (role_key.find_children("*", "CollisionShape3D", true, false).is_empty() if role_key != null else false)
			and craft.find_children("LoadmasterStation*", "Light3D", true, false).is_empty(),
		"the readability treatment adds no collision or light"
	)
	_check(
		craft.get_halyard_render_allocation_report().get("exact_counts", false)
			and craft.get_in_flight_cabin_report().get("supported", false)
			and craft.get_meta("evidence_status", &"") == &"modern_interpretation",
		"the authored render budget, moving interior, and original-design evidence status remain intact"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_LOADMASTER_ROLE_READABILITY_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
