extends SceneTree

## One gameplay-distance Forward+ frame of the production Aft operations roof.
## The standalone module keeps station activity and its articulated service arm
## outside the framing so all five pressure ribs can be reviewed unobstructed.

const MODULE_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const DEFAULT_OUTPUT := "/tmp/mudds-aft-pressure-rib-forward-plus.png"
const CAMERA_POSITION := Vector3(-5.5, 9.2, 2.5)
const CAMERA_TARGET := Vector3(5.6, 5.2, 13.2)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus":
		push_error("AFT_PRESSURE_RIB_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return

	root.size = Vector2i(1600, 1000)
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = false
	var stage := Node3D.new()
	stage.name = "AftPressureRibForwardWitness"
	root.add_child(stage)
	_build_environment(stage)
	_build_lighting(stage)

	var module := MODULE_SCENE.instantiate() as AftJunctionStack
	stage.add_child(module)
	await process_frame
	await physics_frame

	var camera := Camera3D.new()
	camera.name = "GameplayDistanceRoofCamera"
	camera.position = CAMERA_POSITION
	camera.fov = 50.0
	camera.near = 0.08
	camera.far = 180.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)

	var envelope := module.get_node_or_null(
		^"Structure/OperationsRoom/VisualPressureEnvelope"
	) as Node3D
	var valid := envelope != null
	var renderer_nodes := 0
	var visible_copies := 0
	var surface_submissions := 0
	var material_ids := {}
	var every_copy_in_frustum := true
	if envelope != null:
		for segment_index in AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT:
			var batch := envelope.get_node_or_null(
				NodePath("PressureRibSegmentBatch%02d" % segment_index)
			) as MultiMeshInstance3D
			var multimesh := batch.multimesh if batch != null else null
			var mesh := multimesh.mesh if multimesh != null else null
			valid = valid and batch != null and multimesh != null and mesh != null
			if batch == null or multimesh == null or mesh == null:
				continue
			renderer_nodes += 1
			visible_copies += multimesh.visible_instance_count
			surface_submissions += mesh.get_surface_count()
			if batch.material_override != null:
				material_ids[batch.material_override.get_instance_id()] = true
			var expected_bounds := _bounds_for_buffer(mesh.get_aabb(), multimesh.buffer)
			valid = valid \
				and multimesh.instance_count == AftJunctionStack.PRESSURE_RIB_COPY_COUNT \
				and multimesh.visible_instance_count == AftJunctionStack.PRESSURE_RIB_COPY_COUNT \
				and multimesh.custom_aabb.is_equal_approx(expected_bounds) \
				and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				and batch.visible
			for copy_index in multimesh.instance_count:
				every_copy_in_frustum = every_copy_in_frustum and camera.is_position_in_frustum(
					multimesh.get_instance_transform(copy_index).origin
				)

	var material: StandardMaterial3D = null
	if envelope != null:
		var first_batch := envelope.get_node_or_null(
			^"PressureRibSegmentBatch00"
		) as MultiMeshInstance3D
		material = first_batch.material_override as StandardMaterial3D if first_batch != null else null
	valid = valid \
		and renderer_nodes == AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT \
		and visible_copies == AftJunctionStack.PRESSURE_RIB_VISIBLE_COPY_COUNT \
		and surface_submissions == AftJunctionStack.PRESSURE_RIB_SEGMENT_COUNT \
		and material_ids.size() == 1 \
		and material != null \
		and material.albedo_color.is_equal_approx(Color("cbd0ce")) \
		and every_copy_in_frustum \
		and stage.find_child("ArticulatedServiceArm", true, false) == null

	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output := OS.get_environment("KETH_AFT_PRESSURE_RIB_CAPTURE")
	if output.is_empty():
		output = DEFAULT_OUTPUT
	var save_error := ERR_CANT_CREATE
	if image != null and not image.is_empty():
		save_error = image.save_png(ProjectSettings.globalize_path(output))
	valid = valid and save_error == OK and image != null and not image.is_empty()

	print(
		(
			"AFT_PRESSURE_RIB_CAPTURE: renderer=%s adapter=%s distance=%.3f "
			+ "rib_planes=%d copies=%d renderers=%d submissions=%d material_ids=%d "
			+ "shadow_casting=on culling=all_in_frustum service_arm=absent output=%s passed=%s"
		)
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name(),
			CAMERA_POSITION.distance_to(CAMERA_TARGET),
			AftJunctionStack.PRESSURE_RIB_COPY_COUNT,
			visible_copies,
			renderer_nodes,
			surface_submissions,
			material_ids.size(),
			ProjectSettings.globalize_path(output),
			valid,
		]
	)
	if not valid:
		push_error("AFT_PRESSURE_RIB_CAPTURE_FAILED: production roof contract or render drifted")
	stage.queue_free()
	await process_frame
	quit(0 if valid else 1)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061117")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6eaab4")
	environment.ambient_light_energy = 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.30
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.5
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, -34.0, 0.0)
	key.light_color = Color("d9f2ef")
	key.light_energy = 1.15
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
	rim.light_color = Color("e4a56c")
	rim.light_energy = 0.52
	rim.shadow_enabled = false
	stage.add_child(rim)


func _bounds_for_buffer(mesh_bounds: AABB, buffer: PackedFloat32Array) -> AABB:
	var result := AABB()
	var copy_count := buffer.size() / 12
	for index in copy_count:
		var offset := index * 12
		var transform_value := Transform3D(
			Basis(
				Vector3(buffer[offset + 0], buffer[offset + 4], buffer[offset + 8]),
				Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
				Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])
			),
			Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
		)
		var piece := (transform_value * mesh_bounds).abs()
		result = piece if index == 0 else result.merge(piece)
	return result
