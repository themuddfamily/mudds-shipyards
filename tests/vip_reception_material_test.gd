extends SceneTree

const SUITE_SCENE := preload("res://scenes/world/modules/vip_reception_suite.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := SUITE_SCENE.instantiate() as VipReceptionSuite
	root.add_child(suite)
	await process_frame

	_check_finish(
		suite, ^"Structure/Threshold/ThresholdFloor", Color("d8d1c5"), 0.16, 0.46,
		0.16, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS,
		"pearl deck"
	)
	_check_finish(
		suite, ^"Structure/Reception/WellStepEntry", Color("c3bbae"), 0.22, 0.38,
		0.14, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS,
		"pearl well grip"
	)
	_check_finish(
		suite, ^"Structure/Reception/PortWallForward", Color("e6e0d5"), 0.26, 0.30,
		0.12, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS,
		"pearl pressure shell"
	)
	_check_finish(
		suite, ^"Structure/Reception/PortPilaster01", Color("c3bbae"), 0.22, 0.38,
		0.14, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS,
		"deep-pearl pilaster"
	)
	_check_finish(
		suite, ^"Structure/CantileverFrame/KeelGirderPort", Color("222a30"), 0.44, 0.34,
		0.30, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS,
		"graphite keel"
	)
	_check_finish(
		suite, ^"Structure/Threshold/ThresholdStoneInlay", Color("2b3136"), 0.30, 0.22,
		0.26, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS,
		"stone threshold inlay"
	)
	_check_finish(
		suite, ^"Structure/Fitout/ServeryBody", Color("161c22"), 0.58, 0.18,
		0.20, StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS,
		"lacquered servery"
	)
	_check_finish(
		suite, ^"Structure/Threshold/ThresholdThread", Color("c08a4c"), 0.95, 0.16,
		0.40, StationSurfaceKit.TRIM_CLEARCOAT, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS,
		"bronze route thread"
	)
	_check_finish(
		suite, ^"Structure/CantileverFrame/CollarJambPort", Color("a5763f"), 0.90, 0.28,
		0.40, StationSurfaceKit.TRIM_CLEARCOAT, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS,
		"bronze collar"
	)

	var red_mesh := suite.get_node_or_null(
		^"Structure/Threshold/PlinthLegendRule"
	) as MeshInstance3D
	var red := red_mesh.material_override as StandardMaterial3D if red_mesh != null else null
	_check(
		red != null
		and red.albedo_color.is_equal_approx(Color("d84d47"))
		and is_equal_approx(red.metallic, 0.2)
		and is_equal_approx(red.roughness, 0.39)
		and red.emission_enabled
		and red.emission.is_equal_approx(Color("a9252c"))
		and is_equal_approx(red.emission_energy_multiplier, 1.05)
		and red.albedo_texture == null,
		"the suite's exact emissive landmark red remains outside the panel hierarchy"
	)
	_check(
		bool(suite.get_audit_report().valid) and bool(suite.get_render_batch_contract().exact_counts),
		"material hierarchy leaves suite validation and render budgets exact"
	)

	suite.queue_free()
	await process_frame
	_finish()


func _check_finish(
		suite: VipReceptionSuite,
		path: NodePath,
		color: Color,
		metallic: float,
		roughness: float,
		scale: float,
		clearcoat: float,
		clearcoat_roughness: float,
		role: String
	) -> void:
	var node := suite.get_node_or_null(path) as Node3D
	var mesh := node as MeshInstance3D
	if mesh == null and node != null:
		mesh = node.get_node_or_null(^"Mesh") as MeshInstance3D
	var material := mesh.material_override as StandardMaterial3D if mesh != null else null
	_check(
		material != null
		and material.albedo_color.is_equal_approx(color)
		and is_equal_approx(material.metallic, metallic)
		and is_equal_approx(material.roughness, roughness)
		and material.albedo_texture != null
		and material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH
		and material.normal_enabled
		and material.normal_texture != null
		and material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH
		and is_equal_approx(material.normal_scale, StationSurfaceKit.PANEL_NORMAL_SCALE)
		and material.roughness_texture != null
		and material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH
		and material.uv1_world_triplanar
		and material.uv1_scale.is_equal_approx(Vector3.ONE * scale)
		and material.clearcoat_enabled
		and is_equal_approx(material.clearcoat, clearcoat)
		and is_equal_approx(material.clearcoat_roughness, clearcoat_roughness),
		"%s keeps its exact authored PBR values and assigned StationSurfaceKit finish" % role
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("VIP_RECEPTION_MATERIAL_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("VIP_RECEPTION_MATERIAL_TEST_OK")
		quit(0)
	else:
		print("VIP_RECEPTION_MATERIAL_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
