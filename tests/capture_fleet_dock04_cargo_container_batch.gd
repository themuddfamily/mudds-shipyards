extends SceneTree

## One HUD-free Forward+ gameplay-distance witness for Dock 04 after its three
## immutable cargo-container copies move into one renderer batch. The complete
## FleetExpansionBerths component, real Cinder hauler, route, fascia, markers,
## service lights, and attachment API are used; only camera and neutral review
## lighting belong to this harness.

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const OUTPUT_PATH := "/tmp/mudds-fleet-dock04-cargo-container-batch.png"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = true
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "FleetDock04CargoBatchWitness"
	root.add_child(stage)
	_build_environment(stage)
	_build_lighting(stage)

	var berths := Berths.new() as FleetExpansionBerths
	stage.add_child(berths)
	var hauler := Hauler.new() as CinderCargoHauler
	stage.add_child(hauler)
	await process_frame
	hauler.set_process(false)
	hauler.set_physics_process(false)
	var attached := berths.attach_craft(&"dock_04_cargo", hauler, &"cinder_cargo_hauler")
	await process_frame

	var batch := berths.get_node_or_null(
		^"dock_04_cargo/ServicePresentation/CargoContainerBatch"
	) as MultiMeshInstance3D
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh as BoxMesh if multimesh != null else null
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var material := batch.material_override as StandardMaterial3D if batch != null else null
	_check(
		batch != null and multimesh != null and mesh != null
		and multimesh.instance_count == 3 and transforms.size() == 3
		and mesh.size.is_equal_approx(Vector3(7.0, 3.6, 7.0))
		and material != null and material.albedo_color.is_equal_approx(Color("2f5966"))
		and is_equal_approx(material.metallic, 0.58) and not material.emission_enabled,
		"all three teal painted-metal container copies retain their exact shared visual recipe"
	)
	var spacing_exact := transforms.size() == 3
	if spacing_exact:
		for index in transforms.size():
			var expected := Transform3D(
				Basis.IDENTITY, Vector3(18.0, 1.8, -10.0 + 10.0 * float(index))
			)
			spacing_exact = spacing_exact and (
				transforms[index] as Transform3D
			).is_equal_approx(expected)
	_check(spacing_exact, "the three containers retain their ten-metre apron spacing")

	var route := berths.get_node_or_null(
		^"AccessCirculation/CargoBoardingLeg"
	) as StaticBody3D
	var fascia := berths.get_node_or_null(^"dock_04_cargo/PadSign") as Label3D
	var audit := berths.get_audit_report()
	var service_audit := audit.get("service_presentation", {}) as Dictionary
	var cargo_report := (service_audit.get("pads", {}) as Dictionary).get(
		&"dock_04_cargo", {}
	) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and bool(cargo_report.get("landing_clear", false))
		and bool(cargo_report.get("approach_clear", false))
		and route != null and route.get_node_or_null(^"Collision") is CollisionShape3D
		and fascia != null and "OCCUPIED" in fascia.text,
		"the batched apron remains clear of the craft, approach, collision-backed route, and occupied fascia"
	)
	_check(
		bool(attached.get("accepted", false))
		and hauler.global_position.is_equal_approx(
			attached.get("landing_anchor", Vector3.INF) as Vector3
		)
		and int(audit.get("renderer_nodes", -1)) == 24
		and int(audit.get("collision_shapes", -1)) == 6,
		"the real hauler remains attached at Dock 04 while the component holds 24 renderers and six route shapes"
	)

	var camera := Camera3D.new()
	camera.name = "Dock04CargoGameplayDistanceCamera"
	camera.near = 0.08
	camera.far = 180.0
	camera.fov = 50.0
	stage.add_child(camera)
	camera.position = Vector3(31.0, 22.0, 31.0)
	camera.look_at_from_position(camera.position, Vector3(-6.5, 2.6, -7.0), Vector3.UP)
	camera.current = true
	for _frame in 14:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"gameplay-distance Dock 04 frame renders at 1600x900"
	)
	if image != null and not image.is_empty():
		_check(image.save_png(OUTPUT_PATH) == OK, "Forward+ Dock 04 frame saves successfully")
		print("FLEET_DOCK04_CARGO_CONTAINER_BATCH_CAPTURE: ", OUTPUT_PATH)

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FLEET_DOCK04_CARGO_CONTAINER_BATCH_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7595a4")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.glow_bloom = 0.04
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.5
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	key.light_color = Color("ffe0b8")
	key.light_energy = 1.45
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-26.0, 142.0, 0.0)
	fill.light_color = Color("69d8e1")
	fill.light_energy = 0.62
	fill.shadow_enabled = false
	stage.add_child(fill)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
