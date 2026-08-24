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
			Vector3(1.45, 1.5, 3.4),
			PackedStringArray(["PortDorsalBastion", "StarboardDorsalBastion"]),
			&"heavy_gunship_dorsal_bastions",
			Color("243f5b"),
			false
		)
		_check_batch(
			visual.get_node_or_null(^"DorsalBastionCrownBatch") as MultiMeshInstance3D,
			Vector3(1.08, 0.12, 2.55),
			PackedStringArray(["PortDorsalBastionCrown", "StarboardDorsalBastionCrown"]),
			&"heavy_gunship_orientation_crowns",
			Color("e2a63c"),
			true
		)

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
