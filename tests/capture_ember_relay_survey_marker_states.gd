extends SceneTree

## Focused Forward+ witness of the three static Ember relay-survey silhouettes
## from a pulled-back on-foot distance. Reduced-flash uses the exact same
## geometry/material path: only the output filename changes.

const Presentation := preload(
	"res://scripts/world/ember_surface_relay_survey_presentation.gd"
)
const OUTPUT_DIR := "/tmp/mudds-wave32-relay-marker-visual/artifacts/relay_marker_states"
const CAPTURE_SIZE := Vector2i(1600, 900)
const STATE_ANCHORS := [
	Vector3(-7.0, 3.7, 0.0), Vector3(0.0, 3.7, 0.0), Vector3(7.0, 3.7, 0.0),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	root.use_taa = true
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ renderer",
	)
	var world := Node3D.new()
	world.name = "EmberRelaySurveyMarkerStateCapture"
	root.add_child(world)
	_add_environment(world)
	_add_ground(world)

	var relay := _add_state(world, 0, &"active")
	var returning := _add_state(world, 1, &"awaiting_reward")
	var completed := _add_state(world, 2, &"completed")
	_add_label(world, STATE_ANCHORS[0], "RELAY")
	_add_label(world, STATE_ANCHORS[1], "RETURN")
	_add_label(world, STATE_ANCHORS[2], "COMPLETE")

	var relay_marker := relay.get_node(^"OwnedRelaySurveyMarker") as MeshInstance3D
	var return_marker := returning.get_node(^"OwnedReturnSurveyMarker") as MeshInstance3D
	var completed_ring := completed.get_node(^"OwnedReturnSurveyMarker") as MeshInstance3D
	var completed_seal := completed.get_node(^"OwnedRewardCompletionSeal") as MeshInstance3D
	_check(relay_marker.visible and not (relay.get_node(^"OwnedReturnSurveyMarker") as MeshInstance3D).visible,
		"relay state is a single directional pyramid")
	_check(return_marker.visible and not (returning.get_node(^"OwnedRewardCompletionSeal") as MeshInstance3D).visible,
		"return state is an empty expanded ring")
	_check(completed_ring.visible and completed_seal.visible,
		"completion state combines the contracted ring and inset diamond")
	_check(
		(relay_marker.mesh as CylinderMesh).height > 3.0 * (relay_marker.mesh as CylinderMesh).bottom_radius
			and return_marker.scale.x > completed_ring.scale.x
			and completed_seal.scale.x < completed_ring.scale.x,
		"state proportions remain independently readable without colour",
	)
	_check(
		relay.get_child_count() == 3 and returning.get_child_count() == 3
			and completed.get_child_count() == 3
			and world.find_children("*", "Light3D", true, false).size() == 1
			and not relay.is_processing() and not relay.is_physics_processing(),
		"presentation retains three nodes, no owned lights, and no processing",
	)

	var camera := Camera3D.new()
	camera.name = "OnFootSurveyCamera"
	camera.position = Vector3(0.0, 7.0, 18.5)
	camera.near = 0.08
	camera.far = 80.0
	camera.fov = 60.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 3.7, 0.0), Vector3.UP)
	camera.current = true
	for anchor in STATE_ANCHORS:
		_check(camera.is_position_in_frustum(anchor + Vector3.UP * 2.0),
			"on-foot framing includes marker at %s" % anchor)
	for _frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"stable marker-state frame renders at 1600x900")
	_check(_image_has_visible_content(image), "capture contains rendered marker geometry")
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		var reduced_flash := "--reduced-flash" in OS.get_cmdline_user_args()
		var output_path := OUTPUT_DIR.path_join(
			"reduced_flash_forward_plus.png" if reduced_flash else "normal_forward_plus.png"
		)
		_check(image.save_png(output_path) == OK, "Forward+ marker-state capture saves")
		print("EMBER_RELAY_MARKER_STATE_CAPTURE: ", output_path)
	world.queue_free()
	await process_frame
	_finish()


func _add_state(world: Node3D, index: int, state: StringName) -> Node3D:
	var presentation := Presentation.new() as Node3D
	presentation.name = "SurveyState%d" % index
	world.add_child(presentation)
	var activity := {
		"activity_id": &"ember_beacon_survey",
		"activity_generation": 4,
		"state": state,
	}
	var route := {
		"activity_id": &"ember_beacon_survey",
		"activity_generation": 4,
		"checkpoint_count": 2,
		"next_checkpoint_index": 0 if state == &"active" else 2,
	}
	var reward := {}
	if state == &"completed":
		reward = {
			"world_id": &"ember_moon", "activity_id": &"ember_beacon_survey",
			"reward_id": &"ember_beacon_data", "reward_store_id": &"game_flow_reward_store",
			"reward_authority_id": &"game_flow_reward_authority",
			"activity_generation": 4, "run_generation": 2, "attachment_generation": 3,
			"authority_result": {"accepted": true},
		}
	var result: Dictionary = presentation.call(&"apply_activity_snapshot", activity, {}, route, reward)
	_check(bool(result.get("accepted", false)), "%s marker state applies" % state)
	var source_anchor := Presentation.RELAY_ANCHOR if state == &"active" else Presentation.RETURN_ANCHOR
	presentation.position = STATE_ANCHORS[index] - source_anchor
	return presentation


func _add_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070b12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("738096")
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.30
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	sun.light_color = Color("ffd0a0")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	world.add_child(sun)


func _add_ground(world: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(27.0, 14.0)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("202936")
	material.metallic = 0.45
	material.roughness = 0.68
	ground.material_override = material
	world.add_child(ground)


func _add_label(world: Node3D, anchor: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = anchor + Vector3(0.0, 5.5, 0.0)
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color("dcecff")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _image_has_visible_content(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var thumbnail := image.duplicate()
	thumbnail.resize(20, 12, Image.INTERPOLATE_BILINEAR)
	for y in thumbnail.get_height():
		for x in thumbnail.get_width():
			var color: Color = thumbnail.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.12:
				return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_RELAY_MARKER_STATE_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_RELAY_MARKER_STATE_CAPTURE_FAILED: %s" % failure)
	quit(1)
