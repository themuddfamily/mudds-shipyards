extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Hauler.new()
	root.add_child(craft)
	await process_frame
	var audit := craft.get_audit_report()
	_check(bool(audit.get("valid", false)), "the original-modern hauler builds a valid collision and anchor contract")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the hauler makes no historical claim")
	_check(craft.get_cockpit_seat_anchor() != null and craft.get_boarding_marker() != null, "the craft exposes physical cockpit and boarding anchors")
	_check(craft.get_cargo_transfer_anchors().size() == 8 and craft.get_cargo_capacity() == 8, "the cargo hold exposes eight stable transfer anchors")
	_check(bool(craft is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("cargo_transfer_authority", true)), "HeroShip owns flight while the component adds no duplicate cargo authority")
	var threshold_posts := craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostBatch") as MultiMeshInstance3D
	var boarding_position := craft.get_boarding_marker().position
	var expected_post_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, boarding_position + Vector3(0.0, 1.02, -0.72)),
		Transform3D(Basis.IDENTITY, boarding_position + Vector3(0.0, 1.02, 0.72)),
	]
	var authored_post_names := PackedStringArray()
	var authored_post_transforms: Array = []
	var post_material: StandardMaterial3D
	if threshold_posts != null:
		authored_post_names = threshold_posts.get_meta(&"authored_visual_names", PackedStringArray()) as PackedStringArray
		authored_post_transforms = threshold_posts.get_meta(&"authored_instance_transforms", []) as Array
		post_material = threshold_posts.material_override as StandardMaterial3D
	_check(
		threshold_posts != null
			and threshold_posts.multimesh.instance_count == 2
			and threshold_posts.multimesh.visible_instance_count == -1
			and threshold_posts.multimesh.mesh is BoxMesh
			and (threshold_posts.multimesh.mesh as BoxMesh).size == Vector3(0.16, 2.05, 0.16)
			and authored_post_names == PackedStringArray(["CargoThresholdPostPort", "CargoThresholdPostStarboard"])
			and authored_post_transforms == expected_post_transforms
			and threshold_posts.get_meta(&"route_id", &"") == Hauler.CABIN_ROUTE_ID
			and bool(threshold_posts.get_meta(&"presentation_only", false))
			and threshold_posts.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and threshold_posts.layers == 1
			and is_zero_approx(threshold_posts.extra_cull_margin)
			and is_zero_approx(threshold_posts.visibility_range_begin)
			and is_zero_approx(threshold_posts.visibility_range_end)
			and post_material != null
			and post_material.albedo_color == Hauler.ACCENT_COLOR
			and is_equal_approx(post_material.metallic, 0.42)
			and is_equal_approx(post_material.roughness, 0.62),
		"two authored threshold-post copies retain exact visual, transform, route, shadow, and semantic identity"
	)
	_check(
		threshold_posts != null
			and threshold_posts.multimesh.mesh.get_surface_count() == 1
			and craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostPort") == null
			and craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostStarboard") == null,
		"threshold posts reduce renderer submissions from two to one without dropping a visible copy"
	)
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_cargo_hauler_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
