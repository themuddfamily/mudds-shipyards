extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/habitat_spine.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var habitat := MODULE_SCENE.instantiate() as HabitatSpine
	root.add_child(habitat)
	await process_frame

	var mess := habitat.get_node_or_null(
		^"Structure/ObservationCommon/CommonMess"
	) as Node3D
	var batch := mess.get_node_or_null(^"MessTrestleFeet") as MultiMeshInstance3D \
		if mess != null else null
	_check(
		batch != null
			and batch.multimesh != null
			and batch.multimesh.instance_count
				== HabitatSpine.MESS_TRESTLE_FOOT_COPY_COUNT
			and batch.multimesh.visible_instance_count == -1
			and batch.multimesh.mesh != null
			and batch.multimesh.mesh.get_surface_count() == 1,
		"two mess-trestle feet remain two visible copies in one renderer submission"
	)

	if batch != null and batch.multimesh != null:
		var expected: Array[Transform3D] = [
			Transform3D(Basis.IDENTITY, Vector3(5.55, 0.035, 22.45)),
			Transform3D(Basis.IDENTITY, Vector3(5.55, 0.035, 24.15)),
		]
		var actual := batch.get_meta(&"authored_instance_transforms", []) as Array
		_check(
			_transforms_match(actual, expected)
				and batch.multimesh.buffer == _encode(expected)
				and batch.multimesh.custom_aabb.is_equal_approx(
					_transformed_bounds(batch.multimesh.mesh.get_aabb(), expected)
				)
				and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
					Vector3(0.92, 0.07, 0.20)
				),
			"the batch preserves both exact poses, box extent, buffer, and culling union"
		)
		var graphite := batch.material_override as StandardMaterial3D
		_check(
			graphite != null
				and graphite.albedo_color.is_equal_approx(Color("172226"))
				and is_equal_approx(graphite.metallic, 0.48)
				and is_equal_approx(graphite.roughness, 0.46)
				and batch.cast_shadow
					== GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and batch.layers == 1
				and batch.visible
				and batch.get_child_count() == 0
				and batch.get_script() == null
				and bool(batch.get_meta(&"visual_detail_only", false))
				and StringName(batch.get_meta(&"authored_source_name", &""))
					== &"MessTrestleFoot",
			"graphite finish, shadows, visibility and presentation-only identity remain exact"
		)

	var legacy_feet := mess.find_children("MessTrestleFoot*", "MeshInstance3D", false, false) \
		if mess != null else []
	var trestles: Array[StaticBody3D] = []
	if mess != null:
		for child in mess.get_children():
			var body := child as StaticBody3D
			if body != null and is_equal_approx(body.position.x, 5.55) \
					and is_equal_approx(body.position.y, 0.36) \
					and (is_equal_approx(body.position.z, 22.45) \
						or is_equal_approx(body.position.z, 24.15)):
				trestles.append(body)
	var collision_shapes := 0
	for trestle in trestles:
		collision_shapes += (trestle as StaticBody3D).find_children(
			"*", "CollisionShape3D", true, false
		).size()
	_check(
		legacy_feet.is_empty() and trestles.size() == 2 and collision_shapes == 2,
		"only cosmetic feet are batched while both collidable trestles remain ordinary bodies"
	)

	var render := habitat.get_render_allocation_report()
	var audit := habitat.get_audit_report()
	_check(
		bool(render.exact_counts)
			and int(render.descendant_nodes) == 1855
			and int(render.mesh_instances) == 1192
			and int(render.multimesh_batches) == 32
			and int(render.multimesh_resources) == 31
			and int(render.drawn_copies) == 1385
			and int(render.geometry_submissions) == 1215
			and bool(audit.valid),
		"Habitat stays allocation-green at 2->1 foot renderers and 1216->1215 submissions"
	)

	habitat.queue_free()
	await process_frame
	_check(not is_instance_valid(habitat), "Habitat and its new batch leave the lifecycle cleanly")
	_finish()


func _transforms_match(actual: Array, expected: Array[Transform3D]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if not (actual[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _encode(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _transformed_bounds(bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	for index in transforms.size():
		var transformed := (transforms[index] * bounds).abs()
		result = transformed if index == 0 else result.merge(transformed)
	return result


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"HABITAT_MESS_TRESTLE_FEET: renderers 2->1 submissions 2->1 copies 2->2 collision +0 authority +0"
		)
		print("PASS habitat_mess_trestle_foot_batch_test (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
