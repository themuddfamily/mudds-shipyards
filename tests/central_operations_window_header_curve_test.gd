extends SceneTree

## Focused production contract for the curved structural cap above Dock
## Operations' glazed frontage. The treatment is visual geometry only: the
## physical roof envelope and all approach-facing control-room authority stay
## at their existing production transforms.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const EXPECTED_HEADER_AABB := AABB(
	Vector3(-6.0, -0.275, -4.0),
	Vector3(12.0, 0.55, 8.0)
)
const SIGN_FASCIA_MARGIN_M := 0.05

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates for the central control-room header")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame

	var upper := world.get_node_or_null(^"UpperOperations") as Node3D
	var header := upper.get_node_or_null(^"OperationsPodRoof") as StaticBody3D if upper != null else null
	var visual := header.get_node_or_null(^"Mesh") as MeshInstance3D if header != null else null
	var collision := header.get_node_or_null(^"Collision") as CollisionShape3D if header != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	var ivory_reference := upper.get_node_or_null(^"LandingRail/Mesh") as MeshInstance3D if upper != null else null
	_check(
		header != null
		and header.position.is_equal_approx(Vector3(43.0, 5.9, 27.0))
		and header.get_child_count() == 2
		and visual != null
		and collision != null,
		"the named production roof keeps its exact transform and render/collision hierarchy"
	)
	_check(
		visual != null
		and visual.mesh is ArrayMesh
		and visual.mesh.resource_name == "central_operations_window_capsule_header_v1"
		and visual.mesh.get_surface_count() == 1
		and visual.mesh.get_faces().size() / 3 == 72
		and visual.mesh.get_aabb().is_equal_approx(EXPECTED_HEADER_AABB)
		and ivory_reference != null
		and visual.material_override == ivory_reference.material_override,
		"the ivory 12 m control-room cap is one bounded 72-triangle capsule instead of the 108-triangle shallow box"
	)
	_check(
		header != null
		and StringName(header.get_meta("geometry_profile", &"")) == &"central_operations_window_capsule_header"
		and StringName(header.get_meta("evidence_status", &"")) == &"modern_interpretation"
		and not bool(header.get_meta("historical_form_identified", true))
		and not bool(header.get_meta("authenticated_original_geometry", true))
		and is_equal_approx(float(header.get_meta("end_radius_m", 0.0)), 0.275)
		and int(header.get_meta("curve_segments_per_end", 0)) == 8,
		"header publishes its curve recipe and honest modern-interpretation boundary"
	)
	_check(
		shape != null
		and shape.size.is_equal_approx(Vector3(12.0, 0.55, 8.0))
		and header.collision_layer == PhysicsLayers.WORLD
		and header.collision_mask == PhysicsLayers.NONE,
		"the curved render retains the exact production roof collider and collision layers"
	)
	_check(
		visual != null and _mesh_normals_follow_winding(visual.mesh),
		"caps, rim and curved ends retain outward front-face winding"
	)

	var fascia := upper.get_node_or_null(^"OperationsPodFascia") as StaticBody3D if upper != null else null
	var sign := upper.get_node_or_null(^"Sign_DOCK_OPERATIONS") as MeshInstance3D if upper != null else null
	var fascia_visual := fascia.get_node_or_null(^"Mesh") as MeshInstance3D if fascia != null else null
	var text_mesh := sign.mesh as TextMesh if sign != null else null
	var threshold := upper.get_node_or_null(^"OperationsPodThreshold") as StaticBody3D if upper != null else null
	_check(
		fascia != null and fascia.position.is_equal_approx(Vector3(43.0, 5.35, 22.9))
		and sign != null and sign.position.is_equal_approx(Vector3(43.0, 5.15, 22.68))
		and sign.rotation_degrees.is_equal_approx(Vector3(0.0, 180.0, 0.0))
		and threshold != null
		and bool(threshold.get_meta("station_doorway", false))
		and is_equal_approx(float(threshold.get_meta("open_bay_center_x", 0.0)), 43.0)
		and is_equal_approx(float(threshold.get_meta("open_bay_clear_width", 0.0)), 3.34),
		"lower fascia, readable room sign and published doorway clearance remain exact"
	)
	var fascia_bounds := (
		fascia.transform * fascia_visual.transform * fascia_visual.mesh.get_aabb()
		if fascia_visual != null else AABB()
	)
	var glyph_bounds := sign.transform * text_mesh.get_aabb() if text_mesh != null else AABB()
	_check(
		text_mesh != null
		and text_mesh.text == "DOCK OPS // TRAFFIC"
		and sign.scale.is_equal_approx(Vector3.ONE * 0.84)
		and glyph_bounds.position.x >= fascia_bounds.position.x + SIGN_FASCIA_MARGIN_M
		and glyph_bounds.end.x <= fascia_bounds.end.x - SIGN_FASCIA_MARGIN_M
		and glyph_bounds.position.y >= fascia_bounds.position.y + SIGN_FASCIA_MARGIN_M
		and glyph_bounds.end.y <= fascia_bounds.end.y - SIGN_FASCIA_MARGIN_M,
		"the exact traffic-workspace identity uses real glyph bounds and stays inside the existing fascia with margin"
	)

	var glazing_exact := true
	for pane_spec in [
		["OperationsWindow", Vector3(39.35, 3.0, 22.8), Vector3(3.9, 4.7, 0.08)],
		["OperationsWindow03", Vector3(46.65, 3.0, 22.8), Vector3(3.9, 4.7, 0.08)],
	]:
		var pane := upper.get_node_or_null(NodePath(pane_spec[0] as String)) as MeshInstance3D
		var barrier := pane.get_node_or_null(^"PressureBarrier") as StaticBody3D if pane != null else null
		var pane_collision := barrier.get_node_or_null(^"Collision") as CollisionShape3D if barrier != null else null
		var pane_shape := pane_collision.shape as BoxShape3D if pane_collision != null else null
		glazing_exact = glazing_exact \
			and pane != null \
			and pane.position.is_equal_approx(pane_spec[1] as Vector3) \
			and pane.mesh.get_aabb().size.is_equal_approx(pane_spec[2] as Vector3) \
			and pane_shape != null \
			and pane_shape.size.is_equal_approx(pane_spec[2] as Vector3)
	_check(glazing_exact, "both pressure windows retain exact visible and physical envelopes")

	var central_berth := world.get_node_or_null(^"CentralBerth") as ShipBerth
	_check(
		central_berth != null
		and world.get_ship_spawn().is_equal_approx(central_berth.get_dock_transform()),
		"central berth and ship-spawn authority remain aligned"
	)

	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var doorway_query := PhysicsRayQueryParameters3D.create(
		Vector3(43.0, 2.0, 22.2),
		Vector3(43.0, 2.0, 23.4),
		PhysicsLayers.WORLD
	)
	_check(
		space.intersect_ray(doorway_query).is_empty(),
		"the production central control-room doorway remains physically open"
	)

	world.queue_free()
	for frame in 3:
		await process_frame
		await physics_frame
	_finish()


func _mesh_normals_follow_winding(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() != 1:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	if vertices.size() < 3 or vertices.size() != normals.size() or vertices.size() % 3 != 0:
		return false
	for index in range(0, vertices.size(), 3):
		var geometric := (vertices[index + 1] - vertices[index]).cross(
			vertices[index + 2] - vertices[index]
		).normalized()
		var declared := (
			normals[index] + normals[index + 1] + normals[index + 2]
		).normalized()
		if geometric.dot(declared) < 0.99:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CENTRAL_OPERATIONS_WINDOW_HEADER_CURVE_TEST_OK")
		quit(0)
	else:
		push_error("%d central operations window header assertion(s) failed" % _failures.size())
		quit(1)
