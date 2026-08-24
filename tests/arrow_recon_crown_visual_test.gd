extends SceneTree

## Focused presentation contract for the Arrow's modern provisional recon crown.
## The check stays intentionally local: it proves combat-distance readability,
## renderer identity, and the absence of gameplay authority without exercising
## the Arrow's already-covered flight, combat, boarding, or evidence suites.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	root.add_child(arrow)
	await process_frame
	await physics_frame

	var sweep := arrow.get_sensor_mast()
	var snapshot := arrow.get_recon_crown_snapshot()
	var primary := arrow.get_node_or_null(
		snapshot.get("primary_path", NodePath()) as NodePath
	) as MeshInstance3D
	var secondary := arrow.get_node_or_null(
		snapshot.get("secondary_path", NodePath()) as NodePath
	) as MeshInstance3D
	var hub := arrow.get_node_or_null(
		snapshot.get("hub_path", NodePath()) as NodePath
	) as MeshInstance3D
	var materials := arrow.get_variant_materials()

	_check(
		sweep != null and primary != null and secondary != null and hub != null
			and primary.get_parent() == sweep
			and secondary.get_parent() == sweep
			and hub.get_parent() == sweep
			and primary.name == &"PassiveArrayRing"
			and secondary.name == &"OrthogonalPassiveAperture"
			and hub.name == &"PassiveApertureHub",
		"the production Arrow carries one named dual-axis aperture and central hub on its animated survey head"
	)
	_check(
		primary.mesh is TorusMesh and secondary.mesh is TorusMesh
			and hub.mesh is SphereMesh
			and is_equal_approx(
				float(snapshot.get("primary_inner_radius", 0.0)),
				ArrowReconShip.RECON_CROWN_PRIMARY_INNER_RADIUS
			)
			and is_equal_approx(
				float(snapshot.get("primary_outer_radius", 0.0)),
				ArrowReconShip.RECON_CROWN_PRIMARY_OUTER_RADIUS
			)
			and is_equal_approx(
				float(snapshot.get("secondary_inner_radius", 0.0)),
				ArrowReconShip.RECON_CROWN_SECONDARY_INNER_RADIUS
			)
			and is_equal_approx(
				float(snapshot.get("secondary_outer_radius", 0.0)),
				ArrowReconShip.RECON_CROWN_SECONDARY_OUTER_RADIUS
			)
			and is_equal_approx(
				float(snapshot.get("hub_radius", 0.0)),
				ArrowReconShip.RECON_CROWN_HUB_RADIUS
			)
			and primary.mesh.surface_get_material(0) == materials.sensor
			and secondary.mesh.surface_get_material(0) == materials.sensor
			and hub.mesh.surface_get_material(0) == materials.graphite,
		"the sensor crown uses the exact cyan apertures and matte graphite hub that carry its recon read"
	)

	# At the Arrow's maximum normal chase distance, a conservative 720-line
	# viewport and 72-degree vertical field of view still resolve the primary
	# crown at roughly thirty pixels rather than a sub-pixel decorative glint.
	var projected_diameter_px := (
		ArrowReconShip.RECON_CROWN_PRIMARY_OUTER_RADIUS * 2.0 * 720.0
		/ (2.0 * arrow.maximum_chase_camera_distance * tan(deg_to_rad(72.0) * 0.5))
	)
	_check(
		projected_diameter_px
			>= ArrowReconShip.RECON_CROWN_MAX_CHASE_PROJECTED_DIAMETER_PX
			and not primary.transform.is_equal_approx(secondary.transform)
			and (snapshot.get("secondary_rotation", Vector3.ZERO) as Vector3).is_equal_approx(
				Vector3(
					deg_to_rad(ArrowReconShip.RECON_CROWN_SECONDARY_ROTATION_DEGREES.x),
					deg_to_rad(ArrowReconShip.RECON_CROWN_SECONDARY_ROTATION_DEGREES.y),
					deg_to_rad(ArrowReconShip.RECON_CROWN_SECONDARY_ROTATION_DEGREES.z)
				)
			),
		"orthogonal apertures keep the recon crown readable from chase and flank views at gameplay distance"
	)

	var crown_renderers: Array[MeshInstance3D] = [primary, secondary, hub]
	var presentation_only := true
	for renderer in crown_renderers:
		presentation_only = presentation_only \
			and bool(renderer.get_meta("visual_only", false)) \
			and not bool(renderer.get_meta("gameplay_authority", true)) \
			and renderer.get_meta("geometry_status", &"") == &"provisional" \
			and not bool(renderer.get_meta(
				"authenticated_historical_silhouette", true
			)) \
			and renderer.get_script() == null \
			and renderer.get_child_count() == 0
	_check(
		presentation_only
			and snapshot.get("presentation_status", &"") == &"modern_provisional"
			and snapshot.get("evidence_status", &"") == &"provisional"
			and snapshot.get("name_to_model_status", &"") == &"unknown"
			and bool(snapshot.get("visual_only", false))
			and not bool(snapshot.get("gameplay_authority", true))
			and int(snapshot.get("renderer_nodes", -1)) == 3
			and int(snapshot.get("geometry_submissions", -1)) == 3
			and int(snapshot.get("collision_shapes", -1)) == 0
			and int(snapshot.get("lights", -1)) == 0
			and int(snapshot.get("timers", -1)) == 0
			and int(snapshot.get("sensor_queries", -1)) == 0,
		"the crown remains explicitly provisional visual dressing with no collision, light, timer, query, or gameplay authority"
	)
	_check(
		bool(arrow.get_arrow_visual_performance_report().get("valid", false))
			and bool(arrow.get_arrow_audit_report().get("valid", false))
			and arrow.get_ship_definition().get_evidence_status_id() == &"provisional"
			and not arrow.get_ship_definition().is_authenticated(),
		"the polished Arrow preserves its bounded visual census and unauthenticated evidence contract"
	)

	arrow.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ARROW_RECON_CROWN_VISUAL_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("ARROW_RECON_CROWN_VISUAL_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
