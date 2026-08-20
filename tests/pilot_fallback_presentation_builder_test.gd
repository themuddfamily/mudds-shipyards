extends SceneTree

const BuilderScript := preload(
	"res://scripts/player/pilot_fallback_presentation_builder.gd"
)

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := Node3D.new()
	fixture.name = "PilotFallbackPresentationFixture"
	root.add_child(fixture)
	var body := _pivot(fixture, "BodyPivot")
	var left_arm := _pivot(fixture, "LeftArmPivot")
	var right_arm := _pivot(fixture, "RightArmPivot")
	var left_leg := _pivot(fixture, "LeftLegPivot")
	var right_leg := _pivot(fixture, "RightLegPivot")
	var builder := BuilderScript.new() as PilotFallbackPresentationBuilder
	builder.create_materials()
	builder.build(body, left_arm, right_arm, left_leg, right_leg)
	await process_frame

	var audit := builder.get_visual_allocation_audit(fixture)
	_check(
		bool(audit.get("valid", false)),
		"fallback shared-visual allocation audit is green: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("generated_visual_node_count", 0)) == 79
		and int(audit.get("baseline_generated_visual_node_count", 0)) == 79
		and int(audit.get("generated_visual_node_delta", 99)) == 0
		and int(audit.get("drawn_copy_count", 0)) == 79
		and int(audit.get("drawn_copy_delta", 99)) == 0
		and int(audit.get("mesh_resource_identity_count", 0)) == 65
		and int(audit.get("baseline_mesh_resource_identity_count", 0)) == 79
		and int(audit.get("mesh_resource_identity_delta", 0)) == -14,
		"79 generated nodes and copies retain 65 meshes instead of 79"
	)
	_check(
		int(audit.get("abdomen_seal_copy_count", 0)) == 3
		and int(audit.get("abdomen_seal_mesh_resource_identity_count", 0)) == 1
		and int(audit.get("baseline_abdomen_seal_mesh_resource_identity_count", 0)) == 3
		and int(audit.get("abdomen_seal_mesh_resource_identity_delta", 0)) == -2
		and int(audit.get("material_resource_identity_count", 0)) == 12
		and int(audit.get("material_resource_identity_delta", 99)) == 0,
		"the exact three-seal family shares one torus and preserves all 12 materials"
	)
	_check(
		int(audit.get("chest_fastener_copy_count", 0)) == 4
		and int(audit.get("chest_fastener_mesh_resource_identity_count", 0)) == 1
		and int(audit.get("baseline_chest_fastener_mesh_resource_identity_count", 0)) == 4
		and int(audit.get("chest_fastener_mesh_resource_identity_delta", 0)) == -3
		and (audit.get("chest_fastener_rows", []) as Array).size() == 4,
		"the four exact chest fasteners share one cylinder without changing their paths"
	)
	_check(
		int(audit.get("arm_copy_count", 0)) == 18
		and int(audit.get("arm_mesh_resource_identity_count", 0)) == 9
		and int(audit.get("baseline_arm_mesh_resource_identity_count", 0)) == 18
		and int(audit.get("arm_mesh_resource_identity_delta", 0)) == -9
		and _arm_rows_are_exact(audit.get("arm_family_rows", []) as Array),
		"nine mirrored arm recipes retain one mesh per exact bilateral family"
	)
	_check(
		int(audit.get("structural_surface_submission_count", 0)) == 79
		and int(audit.get("structural_surface_submission_delta", 99)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("navigation_region_count", -1)) == 0
		and int(audit.get("abdomen_seal_child_count", -1)) == 0
		and int(audit.get("abdomen_seal_script_count", -1)) == 0
		and int(audit.get("abdomen_seal_group_count", -1)) == 0
		and int(audit.get("abdomen_seal_processing_count", -1)) == 0
		and int(audit.get("abdomen_seal_metadata_entry_count", -1)) == 9
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"renderer surfaces and semantic metadata stay exact without collision or lifecycle authority"
	)

	var rows := audit.get("behavior_rows", []) as Array
	rows.clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("mutation")
	var detached := builder.get_visual_allocation_audit(fixture)
	_check(
		bool(detached.get("valid", false))
		and (detached.get("behavior_rows", []) as Array).size() == 3
		and (detached.get("chest_fastener_rows", []) as Array).size() == 4
		and (detached.get("arm_family_rows", []) as Array).size() == 9
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has("mutation"),
		"fallback allocation evidence is deeply detached"
	)

	var core := body.get_node(^"RefinedPilotCore") as Node3D
	var first := core.get_node(^"AbdomenSeal00") as MeshInstance3D
	var third := core.get_node(^"AbdomenSeal02") as MeshInstance3D
	var shared_mesh := first.mesh
	_check(
		(core.get_node(^"AbdomenSeal01") as MeshInstance3D).mesh == shared_mesh
		and third.mesh == shared_mesh,
		"all three named abdomen seals reference the same exact torus"
	)
	third.mesh = shared_mesh.duplicate() as Mesh
	var identity_red := builder.get_visual_allocation_audit(fixture)
	_check(
		not bool(identity_red.get("valid", true))
		and int(identity_red.get("mesh_resource_identity_count", 0)) == 66
		and int(identity_red.get("abdomen_seal_mesh_resource_identity_count", 0)) == 2
		and _has_error(identity_red, "abdomen_seal_mesh_identity_drift:AbdomenSeal02")
		and _has_error(identity_red, "abdomen_seal_mesh_identity_count_drift"),
		"structured red: duplicating one identical seal invalidates retained mesh identity"
	)
	third.mesh = shared_mesh

	third.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var renderer_red := builder.get_visual_allocation_audit(fixture)
	_check(
		not bool(renderer_red.get("valid", true))
		and _has_error(renderer_red, "abdomen_seal_renderer_recipe_drift:AbdomenSeal02"),
		"structured red: shadow drift invalidates the exact seal renderer recipe"
	)
	third.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var rogue_area := Area3D.new()
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.shape = BoxShape3D.new()
	rogue_area.add_child(rogue_shape)
	third.add_child(rogue_area)
	var collision_red := builder.get_visual_allocation_audit(fixture)
	_check(
		not bool(collision_red.get("valid", true))
		and int(collision_red.get("collision_object_count", 0)) == 1
		and int(collision_red.get("collision_shape_count", 0)) == 1
		and _has_error(collision_red, "pilot_fallback_visuals_gained_collision_or_navigation_authority")
		and _has_error(collision_red, "abdomen_seal_visuals_gained_lifecycle_authority"),
		"structured red: collision authority cannot hide under a shared seal visual"
	)
	third.remove_child(rogue_area)
	rogue_area.free()

	third.remove_meta(&"construction_role")
	var semantic_red := builder.get_visual_allocation_audit(fixture)
	_check(
		not bool(semantic_red.get("valid", true))
		and _has_error(semantic_red, "abdomen_seal_semantic_metadata_drift:AbdomenSeal02")
		and _has_error(semantic_red, "abdomen_seal_semantic_metadata_count_drift"),
		"structured red: sharing cannot erase the named seal's construction semantics"
	)
	third.set_meta(&"construction_role", &"flexible")
	_check(
		bool(builder.get_visual_allocation_audit(fixture).get("valid", false)),
		"all renderer, collision, lifecycle, and semantic mutations restore green"
	)

	var chest_fastener_l_low := core.get_node(^"ChestFastenerLLow") as MeshInstance3D
	var chest_fastener_r_high := core.get_node(^"ChestFastenerRHigh") as MeshInstance3D
	var shared_fastener_mesh := chest_fastener_l_low.mesh
	_check(
		(core.get_node(^"ChestFastenerLHigh") as MeshInstance3D).mesh == shared_fastener_mesh
		and (core.get_node(^"ChestFastenerRLow") as MeshInstance3D).mesh == shared_fastener_mesh
		and chest_fastener_r_high.mesh == shared_fastener_mesh,
		"all four named chest fasteners reference one exact rubber cylinder"
	)
	chest_fastener_r_high.mesh = shared_fastener_mesh.duplicate() as Mesh
	var chest_identity_red := builder.get_visual_allocation_audit(fixture)
	_check(
		not bool(chest_identity_red.get("valid", true))
		and int(chest_identity_red.get("mesh_resource_identity_count", 0)) == 66
		and int(chest_identity_red.get("chest_fastener_mesh_resource_identity_count", 0)) == 2
		and _has_error(chest_identity_red, "chest_fastener_mesh_identity_drift:ChestFastenerRHigh")
		and _has_error(chest_identity_red, "chest_fastener_mesh_identity_count_drift"),
		"structured red: duplicating one chest fastener invalidates its exact family"
	)
	chest_fastener_r_high.mesh = shared_fastener_mesh

	var left_forearm := left_arm.get_node(^"ForearmL") as MeshInstance3D
	var right_forearm := right_arm.get_node(^"ForearmR") as MeshInstance3D
	var shared_forearm_mesh := left_forearm.mesh
	_check(
		right_forearm.mesh == shared_forearm_mesh,
		"the mirrored forearms retain one exact hard-armour cylinder"
	)
	right_forearm.mesh = shared_forearm_mesh.duplicate() as Mesh
	var arm_identity_red := builder.get_visual_allocation_audit(fixture)
	_check(
		not bool(arm_identity_red.get("valid", true))
		and int(arm_identity_red.get("mesh_resource_identity_count", 0)) == 66
		and int(arm_identity_red.get("arm_mesh_resource_identity_count", 0)) == 10
		and _has_error(arm_identity_red, "Forearm_mesh_identity_drift:ForearmR")
		and _has_error(arm_identity_red, "arm_mesh_identity_count_drift"),
		"structured red: one mirrored-arm duplicate invalidates the family and total"
	)
	right_forearm.mesh = shared_forearm_mesh
	_check(
		bool(builder.get_visual_allocation_audit(fixture).get("valid", false)),
		"chest-fastener and mirrored-arm identity repairs restore green"
	)

	fixture.queue_free()
	await process_frame
	_finish()


func _pivot(parent: Node3D, pivot_name: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	parent.add_child(pivot)
	return pivot


func _has_error(audit: Dictionary, expected: String) -> bool:
	return (audit.get("errors", PackedStringArray()) as PackedStringArray).has(expected)


func _arm_rows_are_exact(rows: Array) -> bool:
	if rows.size() != 9:
		return false
	for family_row in rows:
		if not (family_row is Dictionary):
			return false
		var typed_row := family_row as Dictionary
		if (
			int(typed_row.get("copy_count", 0)) != 2
			or int(typed_row.get("mesh_resource_identity_count", 0)) != 1
			or int(typed_row.get("baseline_mesh_resource_identity_count", 0)) != 2
			or int(typed_row.get("mesh_resource_identity_delta", 0)) != -1
			or (typed_row.get("rows", []) as Array).size() != 2
		):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	print("PILOT_FALLBACK_PRESENTATION_BUILDER_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("PILOT_FALLBACK_PRESENTATION_BUILDER_TEST_OK")
		quit(0)
		return
	print("PILOT_FALLBACK_PRESENTATION_BUILDER_TEST_FAILURES: ", _failures)
	quit(1)
