extends SceneTree

## Focused renderer regression for the Halyard's four visual landing pads.
## Collision and boarding authority remain separate production nodes; this
## verifies the immutable batch, contact footprint, connected shoe/strut fit,
## and shared component stocks without freezing unrelated ship construction.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame

	var visual := craft.get_halyard_visual_root()
	var batch := visual.get_node_or_null(^"LandingGearFootBatch") as MultiMeshInstance3D \
		if visual != null else null
	_check(batch != null and batch.multimesh != null, "one renderer owns all four Halyard landing pads")
	if batch != null and batch.multimesh != null:
		var expected_transforms: Array[Transform3D] = []
		var expected_names := PackedStringArray()
		for side in [-1.0, 1.0]:
			for leg_z in [-5.20, 4.80]:
				var leg_name := ("Port" if side < 0.0 else "Starboard") \
					+ ("Forward" if leg_z < 0.0 else "Aft")
				expected_transforms.append(Transform3D(
					Basis.IDENTITY,
					Vector3(side * 2.08, -0.98, leg_z)
				))
				expected_names.append(leg_name + "GearFoot")
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		var transforms_match := authored.size() == expected_transforms.size()
		for index in mini(authored.size(), expected_transforms.size()):
			transforms_match = transforms_match \
				and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
		_check(
			batch.multimesh.instance_count == HalyardCrewTransport.LANDING_GEAR_FOOT_COPY_COUNT
				and batch.multimesh.visible_instance_count == -1
				and batch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(1.20, 0.39, 1.65))
				and is_equal_approx(batch.multimesh.mesh.get_aabb().position.y, -0.10)
				and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
				and transforms_match
				and batch.material_override == craft.get_variant_materials().get("structure"),
			"the formed pads preserve their plan extents, sole contact and four authored transforms"
		)
		_check(
			visual.find_children("*GearFoot", "MeshInstance3D", true, false).is_empty()
				and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
				and craft.get_node_or_null(^"LandingGearCollision") is CollisionShape3D,
			"the visual batch is collision-free while the production gear collider remains authoritative"
		)

		var collider := craft.get_node(^"LandingGearCollision") as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		_check(shape.size.is_equal_approx(Vector3(5.0, 0.70, 12.0))
			and is_equal_approx(collider.position.y - shape.size.y * 0.5, -1.08)
			and not collider.disabled, "physical gear dimensions and contact plane remain unchanged")
		var struts := visual.find_children("*GearStrut", "MeshInstance3D", true, false)
		var shared_stock: Mesh = null
		var fit := struts.size() == 4
		for strut: MeshInstance3D in struts:
			if shared_stock == null:
				shared_stock = strut.mesh
			fit = fit and strut.mesh == shared_stock and strut.mesh.get_surface_count() == 1
			fit = fit and strut.material_override == craft.get_variant_materials().get("dark")
			var lower := strut.transform * Vector3(0, -0.44, 0)
			var pad_origin := Vector3(signf(strut.position.x) * 2.08, -0.98, strut.position.z)
			var local := lower - pad_origin
			# Lower strut centre enters the raised shoe, inside even its smallest
			# upper profile. The sole itself still ends on the original contact.
			fit = fit and absf(local.x) < 0.23 and absf(local.z) < 0.23
			fit = fit and local.y > 0.10 and local.y < 0.29
		_check(fit, "four shared formed struts enter their pad shoes without a floating gap")
		_check(batch.multimesh.mesh.get_surface_count() == 1
			and batch.multimesh.instance_count == 4 and struts.size() == 4,
			"formed pads and struts retain five total visual submissions and two shared stocks")
		var foot_mesh := batch.multimesh.mesh
		var upper_vertices := 0
		for vertex: Vector3 in foot_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if vertex.y > 0.10001:
				upper_vertices += 1
				fit = fit and absf(vertex.x) <= 0.30001 and absf(vertex.z) <= 0.28001
		_check(fit and upper_vertices > 0, "raised shoe stays within strut space and does not expand boarding clearance")
		print("GEAR_COST: nodes=6 submissions=6 materials=3 stocks=3; foot_vertices=",
			foot_mesh.surface_get_array_len(0), " strut_vertices=", shared_stock.surface_get_array_len(0))

	craft.queue_free()
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
		print("HALYARD_LANDING_GEAR_FOOT_BATCH_TEST_PASSED: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("HALYARD_LANDING_GEAR_FOOT_BATCH_TEST_FAILED: %d/%d assertions failed: %s" % [
			_failures.size(), _assertions, "; ".join(_failures)
		])
		quit(1)
