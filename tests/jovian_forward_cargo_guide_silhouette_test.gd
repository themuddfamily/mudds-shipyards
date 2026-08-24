extends SceneTree

## Focused visual/component proof for the Jovian's modern-provisional forward
## cargo guides. This renders the ordinary chase presentation, verifies the
## guide remains a readable freight/orientation cue, and freezes its strict
## presentation-only/evidence boundary without exercising unrelated systems.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const CAPTURE_PATH := "user://jovian_forward_cargo_guide_silhouette.png"

var _assertions := 0
var _failures := PackedStringArray()


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("06131d")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("7894a4")
	environment_resource.ambient_light_energy = 0.42
	environment_resource.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = environment_resource
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.light_color = Color("ffe7c7")
	key.light_energy = 2.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28.0, 150.0, 0.0)
	fill.light_color = Color("6cb4d1")
	fill.light_energy = 0.65
	world.add_child(fill)

	var freighter := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	world.add_child(freighter)
	await process_frame
	await physics_frame
	await process_frame

	var report := freighter.get_forward_cargo_guide_visual_report()
	var guide := freighter.get_jovian_visual_root().get_node(
		NodePath(JovianLightFreighter.FORWARD_CARGO_GUIDE_NAME)
	) as MeshInstance3D
	var bounds := report.get("local_bounds", AABB()) as AABB
	_check(
		bool(report.get("valid", false))
			and str(report.get("orientation_axis", "")) == "forward_negative_z"
			and str(report.get("cargo_role_cue", "")) == "forward_freight_index"
			and str(report.get("interpretation_status", "")) == "modern_provisional"
			and not bool(report.get("authenticated_historical_silhouette", true)),
		"the mirrored guide explicitly reads forward/freight while remaining modern provisional"
	)
	_check(
		guide != null
			and guide.get_child_count() == 0
			and int(report.get("renderer_nodes", 0)) == 1
			and int(report.get("surface_count", 0)) == 2
			and not guide.is_processing()
			and not guide.is_physics_processing()
			and guide.find_children("*", "CollisionObject3D", true, false).is_empty()
			and guide.find_children("*", "CollisionShape3D", true, false).is_empty()
			and guide.find_children("*", "Light3D", true, false).is_empty(),
		"one childless two-surface renderer adds no processing, collision, lighting, or authority"
	)
	_check(
		is_zero_approx(bounds.get_center().x)
			and bounds.size.x >= 16.3
			and bounds.position.z <= -11.3
			and bounds.end.z >= -2.81
			and _aabb_encloses(JovianLightFreighter.PARKED_RENDER_BOUNDS, bounds),
		"the symmetric freight forks create a broad forward silhouette inside the frozen parked envelope"
	)
	var evidence := freighter.get_jovian_evidence_report()
	var interior := freighter.get_walkable_interior_report()
	_check(
		not bool(evidence.get("authenticated_geometry", true))
			and str(evidence.get("evidence_scope", "")) == "name_and_role_only"
			and int(interior.get("cargo_hardpoint_count", 0)) == 4
			and int(interior.get("passenger_seat_count", 0)) == 6
			and bool(freighter.get_jovian_audit_report().get("valid", false)),
		"the cue preserves evidence, cargo, passenger, and full production-audit contracts"
	)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 11.5, 30.0)
	camera.fov = 50.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.2, -0.8), Vector3.UP)
	camera.current = true
	await _frames(5)
	var port_tip := freighter.to_global(Vector3(-8.18, 4.62, -11.35))
	var starboard_tip := freighter.to_global(Vector3(8.18, 4.62, -11.35))
	var port_screen := camera.unproject_position(port_tip)
	var starboard_screen := camera.unproject_position(starboard_tip)
	_check(
		not camera.is_position_behind(port_tip)
			and not camera.is_position_behind(starboard_tip)
			and port_screen.x >= 0.0
			and starboard_screen.x <= float(viewport.size.x)
			and absf(starboard_screen.x - port_screen.x) >= 180.0,
		"both forward cargo-guide tips remain widely separated in the normal gameplay-distance chase frame"
	)

	var image := viewport.get_texture().get_image()
	var save_error := image.save_png(CAPTURE_PATH) if image != null else ERR_CANT_CREATE
	_check(
		image != null
			and not image.is_empty()
			and image.get_width() == 960
			and image.get_height() == 540
			and save_error == OK
			and FileAccess.get_file_as_bytes(CAPTURE_PATH).size() > 16_384,
		"the focused Forward+ chase capture is substantive at 960x540"
	)
	print("CAPTURED: %s" % ProjectSettings.globalize_path(CAPTURE_PATH))

	viewport.queue_free()
	await process_frame
	_finish()


func _aabb_encloses(outer: AABB, inner: AABB) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.position.z >= outer.position.z
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
		and inner.end.z <= outer.end.z
	)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_FORWARD_CARGO_GUIDE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
