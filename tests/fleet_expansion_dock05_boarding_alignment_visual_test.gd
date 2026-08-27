extends SceneTree

## Focused Forward+ proof for Dock 05's final on-foot boarding alignment cue.
## The full FleetExpansionBerths component renders from a normal eye-height
## approach; only the review environment and camera belong to this harness.

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const OUTPUT_PATH := "/tmp/mudds-fleet-dock05-boarding-alignment.png"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)

var _assertions := 0
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
		"the review uses a live Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "Dock05BoardingAlignmentWitness"
	root.add_child(stage)
	_build_environment(stage)
	_build_lighting(stage)

	var berths := Berths.new()
	stage.add_child(berths)
	await process_frame

	var route_treatment := berths.get_node_or_null(
		^"AccessCirculation/BerthRouteEdgeTreatment"
	) as MeshInstance3D
	var alignment_boxes := route_treatment.get_meta(
		&"dock05_boarding_alignment_boxes", []
	) as Array if route_treatment != null else []
	_check(
		route_treatment != null and route_treatment.mesh is ArrayMesh
			and route_treatment.mesh.get_surface_count() == 1
			and alignment_boxes == Berths.DOCK05_BOARDING_ALIGNMENT_BOXES
			and int(route_treatment.get_meta(&"batched_box_count", -1))
				== Berths.EXPECTED_WAYFINDING_BOXES,
		"three exact Dock 05 ladder bars stay in the existing one-surface route batch"
	)

	var bounded := alignment_boxes.size() == 3
	var previous_z := -INF
	for spec in alignment_boxes:
		var centre := (spec as Dictionary).get("centre", Vector3.INF) as Vector3
		var size := (spec as Dictionary).get("size", Vector3.INF) as Vector3
		bounded = bounded and is_equal_approx(centre.x, 30.2) \
			and centre.z > -23.3 and centre.z < -18.35 \
			and centre.z > previous_z \
			and size.is_equal_approx(Vector3(0.72, 0.07, 0.10)) \
			and centre.x - size.x * 0.5 >= 29.7 \
			and centre.x + size.x * 0.5 <= 30.7
		previous_z = centre.z
	_check(
		bounded,
		"the alignment ladder advances toward the bomber fascia inside the one-metre bridge"
	)

	var landing_before := Vector3(34.0, 4.0, -18.0)
	var approach_before := Vector3(34.0, 0.0, 12.0)
	var contract: Dictionary = berths.get_landing_contract(&"dock_05_bomber")
	var audit: Dictionary = berths.get_audit_report()
	_check(
		bool(contract.get("accepted", false))
			and (contract.get("landing_anchor", Vector3.INF) as Vector3)
				.is_equal_approx(landing_before)
			and (contract.get("approach_anchor", Vector3.INF) as Vector3)
				.is_equal_approx(approach_before)
			and not bool(contract.get("ship_authority", true))
			and not bool(contract.get("berth_lease_authority", true))
			and bool(audit.get("valid", false))
			and int(audit.get("renderer_nodes", -1)) == 24
			and int(audit.get("guide_lights", -1)) == 5
			and int(audit.get("collision_shapes", -1)) == 6,
		"landing, approach, authority, renderer, light, and collision contracts remain unchanged"
	)

	var camera := Camera3D.new()
	camera.name = "Dock05BoardingSideEgressCamera"
	camera.near = 0.08
	camera.far = 120.0
	camera.fov = 55.0
	stage.add_child(camera)
	camera.position = Vector3(30.2, 1.65, -13.2)
	camera.look_at_from_position(
		camera.position, Vector3(30.2, -0.05, -19.6), Vector3.UP
	)
	camera.current = true
	for _frame in 14:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"the eye-height Dock 05 approach renders at 1600x900"
	)
	if image != null and not image.is_empty():
		_check(
			image.save_png(OUTPUT_PATH) == OK,
			"the Forward+ Dock 05 gameplay-distance frame saves"
		)
		print("FLEET_DOCK05_BOARDING_ALIGNMENT_CAPTURE: ", OUTPUT_PATH)

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"PASS fleet_expansion_dock05_boarding_alignment_visual_test (%d assertions)"
			% _assertions
		)
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
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.24
	environment.glow_bloom = 0.03
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.3
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_color = Color("ffe0b8")
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24.0, 146.0, 0.0)
	fill.light_color = Color("69d8e1")
	fill.light_energy = 0.66
	fill.shadow_enabled = false
	stage.add_child(fill)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
