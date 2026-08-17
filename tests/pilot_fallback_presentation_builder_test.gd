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

	var audit := builder.get_abdomen_seal_visual_allocation_audit(fixture)
	_check(
		bool(audit.get("valid", false)),
		"fallback abdomen-seal allocation audit is green: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("generated_visual_node_count", 0)) == 79
		and int(audit.get("baseline_generated_visual_node_count", 0)) == 79
		and int(audit.get("generated_visual_node_delta", 99)) == 0
		and int(audit.get("drawn_copy_count", 0)) == 79
		and int(audit.get("drawn_copy_delta", 99)) == 0
		and int(audit.get("mesh_resource_identity_count", 0)) == 77
		and int(audit.get("baseline_mesh_resource_identity_count", 0)) == 79
		and int(audit.get("mesh_resource_identity_delta", 0)) == -2,
		"79 generated nodes and copies retain 77 meshes instead of 79"
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
	var detached := builder.get_abdomen_seal_visual_allocation_audit(fixture)
	_check(
		bool(detached.get("valid", false))
		and (detached.get("behavior_rows", []) as Array).size() == 3
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
	var identity_red := builder.get_abdomen_seal_visual_allocation_audit(fixture)
	_check(
		not bool(identity_red.get("valid", true))
		and int(identity_red.get("mesh_resource_identity_count", 0)) == 78
		and int(identity_red.get("abdomen_seal_mesh_resource_identity_count", 0)) == 2
		and _has_error(identity_red, "abdomen_seal_mesh_identity_drift:AbdomenSeal02")
		and _has_error(identity_red, "abdomen_seal_mesh_identity_count_drift"),
		"structured red: duplicating one identical seal invalidates retained mesh identity"
	)
	third.mesh = shared_mesh

	third.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var renderer_red := builder.get_abdomen_seal_visual_allocation_audit(fixture)
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
	var collision_red := builder.get_abdomen_seal_visual_allocation_audit(fixture)
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
	var semantic_red := builder.get_abdomen_seal_visual_allocation_audit(fixture)
	_check(
		not bool(semantic_red.get("valid", true))
		and _has_error(semantic_red, "abdomen_seal_semantic_metadata_drift:AbdomenSeal02")
		and _has_error(semantic_red, "abdomen_seal_semantic_metadata_count_drift"),
		"structured red: sharing cannot erase the named seal's construction semantics"
	)
	third.set_meta(&"construction_role", &"flexible")
	_check(
		bool(builder.get_abdomen_seal_visual_allocation_audit(fixture).get("valid", false)),
		"all renderer, collision, lifecycle, and semantic mutations restore green"
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
