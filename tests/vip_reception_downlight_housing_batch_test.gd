extends SceneTree

const SUITE_SCENE := preload("res://scenes/world/modules/vip_reception_suite.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := SUITE_SCENE.instantiate() as VipReceptionSuite
	root.add_child(suite)
	await process_frame

	var render := suite.get_render_batch_contract()
	var batch := suite.get_node_or_null(
		^"Structure/Lighting/PerimeterDownlightHousings"
	) as MultiMeshInstance3D
	var anchor := suite.get_node_or_null(
		^"Structure/Lighting/DownlightPortForwardHousing"
	) as MeshInstance3D
	var practicals := suite.find_children("*", "OmniLight3D", true, false)
	_check(
		batch != null
		and batch.multimesh != null
		and int(render.pre_downlight_housing_geometry_submissions) == 230
		and int(render.geometry_submissions) == 227
		and int(render.perimeter_downlight_housing_copies) == 4
		and int(render.perimeter_downlight_housing_baseline_submissions) == 4
		and int(render.perimeter_downlight_housing_submissions) == 1
		and int(render.perimeter_downlight_housing_geometry_submissions_removed) == 3
		and int(render.perimeter_downlight_housing_renderer_buffer_floats) == 48
		and bool(render.perimeter_downlight_housing_renderer_buffer_matches_authored)
		and bool(render.perimeter_downlight_housing_bounds_match_authored)
		and bool(render.perimeter_downlight_housing_visual_contract_matches)
		and bool(render.exact_counts),
		"four exact downlight housings render through one submission"
	)
	_check(
		anchor != null
		and not anchor.visible
		and anchor.transform.is_equal_approx(
			(render.authored_perimeter_downlight_housing_transforms as Array)[0]
		)
		and anchor.material_override == batch.material_override
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and practicals.size() == VipReceptionSuite.PRACTICAL_LIGHT_COUNT,
		"named bronze anchors, transforms, shadow policy and practical lights remain intact"
	)

	var bronze := batch.material_override
	batch.material_override = StandardMaterial3D.new()
	var drifted := suite.get_render_batch_contract()
	_check(
		not bool(drifted.perimeter_downlight_housing_visual_contract_matches)
		and suite.get_validation_errors().has(
			"VIP perimeter-downlight-housing visual contract drifted"
		),
		"housing material drift fails the suite contract closed"
	)
	batch.material_override = bronze
	_check(bool(suite.audit().valid), "restoring the bronze batch returns the suite audit green")

	suite.queue_free()
	await process_frame
	if _failures.is_empty():
		print("VIP_RECEPTION_DOWNLIGHT_HOUSING_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("VIP_RECEPTION_DOWNLIGHT_HOUSING_BATCH_TEST_FAILED: ", _failures)
	quit(1)


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)
