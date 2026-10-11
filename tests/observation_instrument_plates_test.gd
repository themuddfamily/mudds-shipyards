extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/observation_logistics_spur.tscn")
var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var module := MODULE_SCENE.instantiate() as ObservationLogisticsSpur
	root.add_child(module)
	await process_frame
	var batch := module.get_node_or_null(^"Structure/Dressing/ObservationInstrumentPlates") as MeshInstance3D
	_check(batch != null, "production Observation creates its instrument plates")
	if batch != null:
		var mesh := batch.mesh as ArrayMesh
		_check(mesh != null and mesh.get_surface_count() == 1, "three plates share one mesh surface")
		if mesh != null and mesh.get_surface_count() == 1:
			var arrays := mesh.surface_get_arrays(0)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			_check(vertices.size() == 18, "three quads cost six triangles")
			for index in ObservationLogisticsSpur.OBSERVATION_LENS_POSITIONS.size():
				var centre: Vector3 = ObservationLogisticsSpur.OBSERVATION_LENS_POSITIONS[index]
				var correct := vertices.size() == 18 and uvs.size() == 18 and normals.size() == 18
				if correct:
					for offset in 6:
						var vertex_index := index * 6 + offset
						var position := vertices[vertex_index]
						correct = correct and is_equal_approx(position.x, centre.x + 0.0195) \
							and absf(position.y - centre.y) <= 0.1201 and absf(position.z - centre.z) <= 0.4501 \
							and normals[vertex_index].is_equal_approx(Vector3.RIGHT) \
							and uvs[vertex_index].y > index * 0.25 and uvs[vertex_index].y < (index + 1) * 0.25
				_check(correct, "plate %d faces inward on its original lens and samples a distinct atlas row" % (index + 1))
		var material := batch.material_override as StandardMaterial3D
		_check(material != null and material.albedo_texture == ObservationLogisticsSpur.OBSERVATION_INSTRUMENT_ATLAS \
			and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and not material.emission_enabled,
			"one unshaded, non-emissive atlas material keeps headings readable without glow")
		_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and batch.gi_mode == GeometryInstance3D.GI_MODE_DISABLED and batch.get_child_count() == 0 \
			and not batch.is_processing(), "static plates add no lights, collision, animation or child nodes")
		_check(batch.get_meta("headings") == ["SECTOR VIEW", "RANGE DISPLAY", "LOGISTICS"], "three distinct instrument identities")
	var atlas: Texture2D = ObservationLogisticsSpur.OBSERVATION_INSTRUMENT_ATLAS
	_check(atlas != null and atlas.get_size() == Vector2(512.0, 512.0), "loaded instrument atlas retains its 512 by 512 layout in source and packages")
	var image := atlas.get_image() if atlas != null else null
	var distinct_rows := image != null and image.get_width() == 512 and image.get_height() == 512
	if distinct_rows:
		var first := image.get_region(Rect2i(0, 0, 512, 128)).get_data()
		var second := image.get_region(Rect2i(0, 128, 512, 128)).get_data()
		var third := image.get_region(Rect2i(0, 256, 512, 128)).get_data()
		distinct_rows = first != second and first != third and second != third
	_check(distinct_rows, "loaded texture contains three distinct instrument plates at the sampled UV rows")
	var contract := module.get_visual_resource_contract()
	_check(bool(contract.observation_lens_identities_exact) and bool(contract.observation_console_identities_exact),
		"original console collision and lens/console batch identity remain unchanged")
	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OBSERVATION_INSTRUMENT_PLATES_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("OBSERVATION_INSTRUMENT_PLATES_TEST_FAILED: ", "; ".join(_failures))
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)
