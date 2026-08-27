extends SceneTree

## Focused on-foot proof and Forward+ review capture for the lower-junction to
## stair handoff. Set AFT_HANDOFF_BASELINE=1 only to record the pre-change frame.

const MODULE_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const RESOLUTION := Vector2i(1280, 720)
const CAPTURE_ROOT := "res://artifacts/aft_junction_stair_handoff"

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	root.size = RESOLUTION
	var stage := Node3D.new()
	stage.name = "AftJunctionStairHandoffReview"
	root.add_child(stage)
	_build_environment(stage)

	var module := MODULE_SCENE.instantiate() as AftJunctionStack
	stage.add_child(module)
	await process_frame
	module.set_process(false)
	module.set_physics_process(false)

	var baseline_only := OS.get_environment("AFT_HANDOFF_BASELINE") == "1"
	var cue := module.get_node_or_null(
		^"Structure/Circulation/StairHandoffCue"
	) as Node3D
	if not baseline_only:
		_check(cue != null, "the production stair handoff owns one bounded cue hierarchy")
		if cue != null:
			var plate := cue.get_node_or_null(^"BackingPlate") as MeshInstance3D
			var label := cue.get_node_or_null(^"Sign_UPPER_OPERATIONS") as MeshInstance3D
			var label_mesh := label.mesh as TextMesh if label != null else null
			var renderers := cue.find_children("*", "MeshInstance3D", true, false)
			var collision := cue.find_children("*", "CollisionObject3D", true, false)
			var shapes := cue.find_children("*", "CollisionShape3D", true, false)
			var lights := cue.find_children("*", "Light3D", true, false)
			var authority_free := cue.get_script() == null \
				and not cue.is_processing() and not cue.is_physics_processing() \
				and collision.is_empty() and shapes.is_empty() and lights.is_empty()
			var all_non_emissive := true
			for raw_renderer in renderers:
				var renderer := raw_renderer as MeshInstance3D
				var material := renderer.material_override as StandardMaterial3D
				if material == null and renderer.mesh != null:
					material = renderer.mesh.surface_get_material(0) as StandardMaterial3D
				all_non_emissive = all_non_emissive \
					and material != null and not material.emission_enabled
			_check(
				plate != null and label_mesh != null and label_mesh.text == "UPPER OPERATIONS" \
					and renderers.size() == 7 and authority_free and all_non_emissive,
				"the seven-leaf cue is labelled, static, collision-free, light-free, and non-emissive"
			)
			var lane_min_x := -5.7 - AftJunctionStack.STAIR_CLEAR_WIDTH * 0.5
			var lane_max_x := -5.7 + AftJunctionStack.STAIR_CLEAR_WIDTH * 0.5
			var left_post := cue.get_node_or_null(^"PortMount") as MeshInstance3D
			var right_post := cue.get_node_or_null(^"StarboardMount") as MeshInstance3D
			var plate_size := plate.mesh.get_aabb().size if plate != null else Vector3.ZERO
			_check(
				left_post != null and right_post != null \
					and cue.position.x + left_post.position.x < lane_min_x \
					and cue.position.x + right_post.position.x > lane_max_x \
					and plate.position.y - plate_size.y * 0.5 >= 2.0 \
					and cue.position.distance_to(Vector3(-5.7, 0.0, 3.0)) <= 0.01,
				"mounts stay outside the 2.8 m stair lane and the sign leaves two metres clear"
			)
			var projected_width_px := plate_size.x * RESOLUTION.x \
				/ (2.0 * 8.7 * tan(deg_to_rad(58.0) * 0.5))
			_check(projected_width_px >= 170.0, "the cue resolves clearly from the lower junction")

	var approach_before := module.get_route_transform(&"approach")
	var lower_before := module.get_route_transform(&"lower-junction")
	var base_before := module.get_route_transform(&"stair-base")
	var top_before := module.get_route_transform(&"stair-top")
	_check(
		approach_before.origin.is_equal_approx(Vector3(0.0, 0.15, -1.7)) \
			and lower_before.origin.is_equal_approx(Vector3(0.0, 0.15, 7.2)) \
			and base_before.origin.is_equal_approx(Vector3(-5.7, 0.15, 3.0)) \
			and top_before.origin.is_equal_approx(Vector3(-5.7, 4.35, 12.8)),
		"the published approach, junction, stair-base, and stair-top route transforms remain exact"
	)
	if not baseline_only:
		_check(
			module.get_validation_errors().is_empty(),
			"the unchanged production module contract remains green with the visual cue"
		)

	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 100.0
	camera.position = Vector3(1.25, 1.65, 8.0)
	camera.look_at_from_position(camera.position, Vector3(-5.65, 1.45, 3.15), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	for _frame in 8:
		await process_frame

	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus",
		"the review frame uses Forward+"
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	var suffix := "baseline" if baseline_only else "with_handoff_cue"
	var capture_path := "%s/gameplay_distance_%s.png" % [CAPTURE_ROOT, suffix]
	var texture := root.get_texture()
	var image := texture.get_image() if texture != null else null
	var save_error := image.save_png(ProjectSettings.globalize_path(capture_path)) \
		if image != null else ERR_UNAVAILABLE
	_check(save_error == OK, "the 1280x720 gameplay-distance capture saves")

	module.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS aft_junction_stair_handoff_visual_test (%d assertions)" % _assertions)
		print("AFT_JUNCTION_STAIR_HANDOFF_CAPTURE %s" % capture_path)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _build_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("71889d")
	environment.ambient_light_energy = 0.38
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe4c4")
	key.light_energy = 1.7
	key.rotation_degrees = Vector3(-48.0, 24.0, 0.0)
	stage.add_child(key)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
