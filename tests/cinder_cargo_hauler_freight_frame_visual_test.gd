extends SceneTree

## Focused component proof and gameplay-distance capture for the Cinder cargo
## hauler's presentation-only external load frame.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const RESOLUTION := Vector2i(1280, 720)

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	root.size = RESOLUTION
	var stage := Node3D.new()
	root.add_child(stage)
	_build_capture_environment(stage)

	var craft := Hauler.new() as CinderCargoHauler
	stage.add_child(craft)
	await process_frame
	craft.set_process(false)
	craft.set_physics_process(false)

	var batch := craft.get_node_or_null(
		^"CinderCargoVisual/CargoFrameRibBatch"
	) as MultiMeshInstance3D
	var multi := batch.multimesh if batch != null else null
	var mesh := multi.mesh as BoxMesh if multi != null else null
	_check(
		batch != null
			and multi != null
			and multi.instance_count == 8
			and mesh != null
			and mesh.size.is_equal_approx(Hauler.CARGO_FRAME_RIB_SIZE)
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"one eight-piece freight-frame batch is present on the production hauler"
	)
	_check(
		batch != null
			and batch.get_meta(&"presentation_only", false)
			and batch.get_meta(&"color_independent", false)
			and batch.get_meta(&"silhouette_role", &"") == &"cargo_load_frame"
			and not batch.get_meta(&"animated", true)
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
			and batch.find_children("*", "Light3D", true, false).is_empty(),
		"the repeated shape cue adds no collision, light, animation, or authority"
	)

	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
			if batch != null else []
	var port_count := 0
	var starboard_count := 0
	var bounded := transforms.size() == 8 and mesh != null
	var aperture_clear := bounded
	for transform_variant in transforms:
		var transform := transform_variant as Transform3D
		port_count += 1 if transform.origin.x < 0.0 else 0
		starboard_count += 1 if transform.origin.x > 0.0 else 0
		bounded = bounded \
			and absf(transform.origin.x) + mesh.size.x * 0.5 <= 3.40 \
			and transform.origin.y - mesh.size.y * 0.5 >= -1.16 \
			and transform.origin.y + mesh.size.y * 0.5 <= 1.57 \
			and absf(transform.origin.z) + mesh.size.z * 0.5 <= 6.0
		aperture_clear = aperture_clear \
			and (transform.origin.x > 0.0 \
				or absf(transform.origin.z) - mesh.size.z * 0.5 >= 2.30)
	_check(
		bounded and aperture_clear and port_count == 4 and starboard_count == 4,
		"the mirrored ribs stay inside the exact shell and clear the port aperture"
	)

	# A rib is 2.4 m tall: at the authored 24 m review distance and a 60-degree
	# vertical field of view it occupies over 62 pixels on a 720-line viewport.
	var projected_height_px := Hauler.CARGO_FRAME_RIB_SIZE.y * RESOLUTION.y \
			/ (2.0 * 24.0 * tan(deg_to_rad(60.0) * 0.5))
	_check(
		projected_height_px >= 60.0,
		"the repeated freight frame resolves at normal gameplay distance"
	)
	_check(
		craft.get_boarding_marker().position.is_equal_approx(Vector3(-3.4, -1.1, 0.0))
			and craft.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and bool(craft.get_landing_collision_report().get("valid", false))
			and not bool(craft.get_audit_report().get("cargo_transfer_authority", true))
			and not bool(craft.get_audit_report().get("network_authority", true))
			and craft.get_meta(&"evidence_status", &"") == &"NEW",
		"boarding, cargo seams, collision, authority, and NEW status remain unchanged"
	)

	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 100.0
	camera.position = Vector3(-16.0, 7.0, 21.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.25, 0.4), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	for _frame in 6:
		await process_frame
	var output_dir := "res://artifacts/cinder_cargo_hauler_freight_frame"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var capture_path := "%s/gameplay_distance_port_aft.png" % output_dir
	var save_error := ERR_UNAVAILABLE
	if DisplayServer.get_name() != "headless":
		var viewport_texture := root.get_texture()
		var image := viewport_texture.get_image() if viewport_texture != null else null
		if image != null:
			save_error = image.save_png(ProjectSettings.globalize_path(capture_path))
	# Dummy/headless rendering intentionally has no viewport texture. The same
	# focused test writes the review image when run through a real renderer.
	_check(
		save_error == OK or DisplayServer.get_name() == "headless",
		"the gameplay-distance freight-frame capture saves when rendering is available"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_cargo_hauler_freight_frame_visual_test (%d assertions)" % _assertions)
		if save_error == OK:
			print("CINDER_CARGO_HAULER_FREIGHT_FRAME_CAPTURE %s" % capture_path)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _build_capture_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("698096")
	environment.ambient_light_energy = 0.44
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe1b8")
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("5dd9e2")
	rim.light_energy = 0.72
	rim.rotation_degrees = Vector3(-12.0, -145.0, 0.0)
	stage.add_child(rim)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
