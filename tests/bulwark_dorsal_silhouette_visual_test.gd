extends SceneTree

## Focused component gate for the Bulwark's presentation-only gameplay-distance
## silhouette polish. It intentionally does not exercise combat, crew commands,
## flight handling, boarding lifecycle, damage, repair, or world integration.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ship := BULWARK_SCENE.instantiate() as BulwarkHeavyGunship
	root.add_child(ship)
	await process_frame
	await physics_frame

	var visual := ship.get_node_or_null(^"BulwarkHeavyGunshipVisual") as Node3D
	_check(visual != null, "production Bulwark constructs its authored visual root")
	if visual != null:
		_check_batch(
			visual.get_node_or_null(^"DorsalBastionBatch") as MultiMeshInstance3D,
			Vector3(1.8, 0.82, 4.15),
			PackedStringArray(["PortDorsalBastion", "StarboardDorsalBastion"]),
			&"heavy_gunship_dorsal_bastions",
			Color("304f68"),
			false
		)
		_check_batch(
			visual.get_node_or_null(^"DorsalBastionCrownBatch") as MultiMeshInstance3D,
			Vector3(0.14, 0.026, 1.9),
			PackedStringArray(["PortDorsalBastionCrown", "StarboardDorsalBastionCrown"]),
			&"heavy_gunship_orientation_crowns",
			Color("957c4f"),
			true
		)

		for shell_name in ["ArmoredCentralSlab", "ArmoredNose", "CenterlineArmorSpine", "GunnerRearSplinterShield"]:
			_check_profile(visual.get_node_or_null(shell_name) as MeshInstance3D, shell_name)

		_check_nose_installation(visual)
		_check_gunner_surround(ship, visual)

		for batch_name in ["ArmoredShoulderBatch", "DorsalBastionBatch", "GunPodHousingBatch"]:
			var batch := visual.get_node_or_null(batch_name) as MultiMeshInstance3D
			_check_mesh(batch.multimesh.mesh if batch != null else null, batch_name)

	var definition := ship.get_ship_definition()
	_check(
		definition != null
		and definition.evidence_status == ShipDefinition.EvidenceStatus.NEW
		and definition.evidence_references.is_empty(),
		"silhouette polish preserves Bulwark's original-modern EvidenceStatus.NEW claim"
	)
	_check(
		ship.get_node_or_null(^"BulwarkHullCollision") is CollisionShape3D
		and ship.get_node_or_null(^"BulwarkShoulderCollision") is CollisionShape3D
		and ship.get_node_or_null(^"BulwarkChinCollision") is CollisionShape3D
		and ship.get_node_or_null(^"BulwarkBoardingArea") is Area3D,
		"the existing collision and boarding nodes remain intact"
	)

	ship.queue_free()
	await process_frame
	_finish()


func _check_gunner_surround(ship: BulwarkHeavyGunship, visual: Node3D) -> void:
	var surround := visual.get_node_or_null("GunnerRearSplinterShield") as MeshInstance3D
	if surround == null:
		_check(false, "gunner crew surround exists")
		return
	_check(visual.get_node_or_null("GunnerOutboardCoaming") == null
		and surround.mesh.get_surface_count() == 1 and surround.get_child_count() == 0,
		"rear shield and outboard coaming share one static armor surface")
	var vertices: PackedVector3Array = surround.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(_surround_blocks(vertices, Vector3(2.35, 2.2, 0.55), Vector3(3.6, 2.2, 0.55))
		and _surround_blocks(vertices, Vector3(2.35, 2.2, 0.55), Vector3(2.35, 2.2, 1.9)),
		"the fitted casting shields the seated gunner on its outboard and rear faces")
	# These paths cross the newly authored surface only: a cosmetic wall must
	# not suggest a closed route where gameplay still admits the crew member.
	_check(not _surround_blocks(vertices, Vector3(1.4, 1.95, 0.55), Vector3(2.35, 1.95, 0.55))
		and not _surround_blocks(vertices, Vector3(2.35, 2.1, -1.8), Vector3(2.35, 2.1, 0.55)),
		"inboard seat entry and forward engineer approach remain open")
	var anchor := ship.get_gunner_station_anchor()
	var station := anchor.get_parent() as Node3D
	var eye := ship.to_local(anchor.to_global(Vector3(0, 0.65, 0.18)))
	var gunner_display := station.get_node("GunnerStatusReadout") as Label3D
	var engineer_display := station.get_node("EngineerRepairReadout") as Label3D
	var clear := true
	for offset in [Vector3.ZERO, Vector3(-0.48, -0.16, 0), Vector3(0.48, -0.16, 0),
		Vector3(-0.48, 0.16, 0), Vector3(0.48, 0.16, 0)]:
		clear = clear and not _surround_blocks(vertices, eye,
			ship.to_local(gunner_display.to_global(offset)))
		clear = clear and not _surround_blocks(vertices, Vector3(2.35, 2.6, -2.4),
			ship.to_local(engineer_display.to_global(offset)))
	_check(clear, "both physical readout faces remain clear at their center and corners")
	_check(anchor.position.is_equal_approx(Vector3(0, 0.4, 0))
		and station.position.is_equal_approx(Vector3(2.35, 1.55, 0.55)),
		"the public physical seat and station anchors retain their exact placement")
	# Horizontal probes below each existing deck crown prove the armor foot
	# reaches into supporting hull, rather than stopping above it as a plate.
	_check(_surround_blocks(vertices, Vector3(2.35, 1.45, 0.9), Vector3(2.35, 1.45, 1.9))
		and _surround_blocks(vertices, Vector3(2.7, 1.6, 0.1), Vector3(3.6, 1.6, 0.1)),
		"the rear and outboard armor roots overlap the slab and shoulder deck heights")


func _surround_blocks(vertices: PackedVector3Array, from: Vector3, to: Vector3) -> bool:
	for triangle in range(0, vertices.size(), 3):
		if Geometry3D.segment_intersects_triangle(from, to,
			vertices[triangle], vertices[triangle + 1], vertices[triangle + 2]) is Vector3:
			return true
	return false


func _check_nose_installation(visual: Node3D) -> void:
	var shell := visual.get_node_or_null("ArmoredNose") as MeshInstance3D
	var bay := visual.get_node_or_null("NoseAvionicsBay") as Node3D
	_check(bay != null, "avionics assembly has a common sloped service mount")
	if shell == null or bay == null:
		return
	# A downward ray through the center must hit the lowered shell floor, not
	# an intact glacis hidden under cosmetic panels.
	var vertices: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var floor_height := -INF
	for triangle in range(0, vertices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(0, 3, -4.3), Vector3.DOWN,
			vertices[triangle], vertices[triangle + 1], vertices[triangle + 2])
		if hit is Vector3:
			floor_height = maxf(floor_height, hit.y)
	_check(is_equal_approx(floor_height, 0.95 + (1.1 / 2.15) * 0.55 - 0.16),
		"nose shell contains a real 0.16 m service recess below its original glacis")
	for part in ["ServicePocketLiner", "AvionicsCartridge"]:
		_check_profile(bay.get_node_or_null(part) as MeshInstance3D, part)
	for spec in [["ArmoredServiceCoverBatch", 2], ["CaptiveRetainerBatch", 4], ["AvionicsCoolingRibBatch", 6]]:
		var batch := bay.get_node_or_null(spec[0]) as MultiMeshInstance3D
		_check(batch != null and batch.multimesh.instance_count == spec[1],
			"%s retains one renderer for repeated hardware" % spec[0])
		if batch != null:
			_check_mesh(batch.multimesh.mesh, spec[0])
	_check(bay.find_children("*", "CollisionObject3D", true, false).is_empty()
		and bay.position.z < -3.0, "service hardware stays forward of crew access with no new collision authority")


func _check_batch(
		batch: MultiMeshInstance3D,
		expected_size: Vector3,
		expected_names: PackedStringArray,
		expected_role: StringName,
		expected_color: Color,
		expect_emission: bool
) -> void:
	var multi := batch.multimesh if batch != null else null
	var mesh := multi.mesh if multi != null else null
	var material := mesh.surface_get_material(0) as StandardMaterial3D \
		if mesh != null and mesh.get_surface_count() == 1 else null
	var transforms: Array = batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var local_bounds := multi.custom_aabb if multi != null else AABB()
	var inert := batch != null \
		and batch.get_child_count() == 0 \
		and batch.get_script() == null \
		and batch.get_groups().is_empty() \
		and bool(batch.get_meta(&"presentation_only", false)) \
		and bool(batch.get_meta(&"gameplay_distance_cue", false)) \
		and not bool(batch.get_meta(&"gameplay_authority", true))
	_check(
		multi != null
		and multi.transform_format == MultiMesh.TRANSFORM_3D
		and multi.instance_count == 2
		and multi.visible_instance_count == -1
		and mesh != null
		and mesh.get_aabb().size.is_equal_approx(expected_size)
		and material != null
		and material.albedo_color.is_equal_approx(expected_color)
		and (not expect_emission or material.emission_enabled)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.get_meta(&"authored_visual_names", PackedStringArray()) == expected_names
		and batch.get_meta(&"silhouette_role", &"") == expected_role
		and transforms.size() == 2
		# Both batches remain inside the pre-existing 11.6 x 5.8 m shoulder
		# collision footprint in the axes that determine berth clearance.
		and local_bounds.size.x <= 11.6
		and local_bounds.size.z <= 5.8
		and inert,
		"%s is a bounded two-copy inert presentation batch" % expected_role
	)


func _check_profile(instance: MeshInstance3D, label: String) -> void:
	_check_mesh(instance.mesh if instance != null else null, label)


func _check_mesh(mesh: Mesh, label: String) -> void:
	var valid := mesh is ArrayMesh
	if valid:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for triangle in range(0, vertices.size(), 3):
			var geometric_normal := (vertices[triangle + 2] - vertices[triangle]).cross(vertices[triangle + 1] - vertices[triangle]).normalized()
			var uv_a := uv[triangle + 1] - uv[triangle]
			var uv_b := uv[triangle + 2] - uv[triangle]
			valid = valid and absf(uv_a.cross(uv_b)) > 0.000001
			for corner in 3:
				valid = valid and normals[triangle + corner].is_finite() and geometric_normal.dot(normals[triangle + corner]) > 0.5
	_check(valid, "%s has outward-facing shaded triangles and usable side/cap UVs" % label)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("BULWARK_DORSAL_SILHOUETTE_VISUAL_TEST_OK assertions=%d" % _assertions)
		quit(0)
	else:
		print("BULWARK_DORSAL_SILHOUETTE_VISUAL_TEST_FAILED failures=%d" % _failures.size())
		quit(1)
