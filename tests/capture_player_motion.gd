extends SceneTree

## Native rendered-evidence harness for the production PlayerController motion.
##
## The production player mounts one Blender-authored PilotSkinnedPresentation.
## Its imported AnimationPlayer/Skeleton3D deform the visible joined PilotSuit,
## while PlayerController remains the CharacterBody, input, traversal, boarding,
## seat-following, and collision authority. This fixture contributes only a real
## floor, contextual seat geometry, lighting, and an evidence camera. It never
## seeks, duplicates, replaces, or mutates the imported animation resources.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "KETH_CAPTURE_PLAYER_MOTION_PARSE_ONLY"
const OUTPUT_DIR := "res://artifacts/player_motion"
const PILOT_GLTF_PATH := "res://assets/models/pilot/pilot_motion_v2.glb"
const PILOT_BLEND_PATH := "res://art_source/pilot/pilot_motion_v2.blend"
const PILOT_MANIFEST_PATH := "res://assets/models/pilot/pilot_motion_v2_asset_manifest.json"
const PILOT_GENERATOR_PATH := "res://tools/blender/generate_pilot_motion_v2.py"
const PILOT_WRAPPER_PATH := NodePath("VisualRoot/BodyPivot/PilotSkinnedPresentation")
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const CAPTURE_FILES := [
	"01_idle.png",
	"02_walk_contact_a.png",
	"03_walk_contact_b.png",
	"04_run.png",
	"05_jump_ascent.png",
	"06_airborne_descent.png",
	"07_boarding_transition.png",
	"08_seated_control.png",
	"09_disembark_recovery.png",
]
const REQUIRED_CLIPS := [
	"RESET",
	"idle",
	"walk",
	"run",
	"jump",
	"airborne",
	"boarding",
	"seated_control",
	"disembark_recovery",
]
const REQUIRED_CLIP_DURATIONS := {
	&"RESET": 0.001,
	&"idle": 2.4,
	&"walk": 0.8,
	&"run": 0.56,
	&"jump": 0.42,
	&"airborne": 0.9,
	&"boarding": 1.1,
	&"seated_control": 2.4,
	&"disembark_recovery": 0.9,
}
const LOOPING_CLIPS := [&"idle", &"walk", &"run", &"airborne", &"seated_control"]
const REQUIRED_BONE_PARENTS := {
	&"root": &"",
	&"pelvis": &"root",
	&"spine_01": &"pelvis",
	&"spine_02": &"spine_01",
	&"chest": &"spine_02",
	&"neck": &"chest",
	&"head": &"neck",
	&"clavicle_l": &"chest",
	&"upper_arm_l": &"clavicle_l",
	&"forearm_l": &"upper_arm_l",
	&"hand_l": &"forearm_l",
	&"clavicle_r": &"chest",
	&"upper_arm_r": &"clavicle_r",
	&"forearm_r": &"upper_arm_r",
	&"hand_r": &"forearm_r",
	&"thigh_l": &"pelvis",
	&"calf_l": &"thigh_l",
	&"foot_l": &"calf_l",
	&"toe_l": &"foot_l",
	&"thigh_r": &"pelvis",
	&"calf_r": &"thigh_r",
	&"foot_r": &"calf_r",
	&"toe_r": &"foot_r",
}
const REQUIRED_MATERIAL_ROLES := [
	"PressureTextile",
	"CeramicArmor",
	"GraphiteArmor",
	"JointRubber",
	"HarnessWebbing",
	"VisorGlazing",
	"CyanStatusLight",
	"AmberStatusLight",
]
const WITNESS_BONES := [
	&"root", &"pelvis", &"chest", &"head",
	&"forearm_l", &"hand_l", &"forearm_r", &"hand_r",
	&"thigh_l", &"calf_l", &"foot_l",
	&"thigh_r", &"calf_r", &"foot_r",
]
const MINIMUM_PNG_BYTES := 150_000
const MINIMUM_LUMINANCE_RANGE := 0.08
const MINIMUM_LUMINANCE_VARIANCE := 0.0003
const MINIMUM_PAIR_MEAN_DIFFERENCE := 0.00012
const MINIMUM_PAIR_CHANGED_FRACTION := 0.0015
const PIXEL_CHANGE_THRESHOLD := 0.018
const MOTION_TIMEOUT_PHYSICS_FRAMES := 240
const LOCOMOTION_ORIGIN := Vector3(-4.0, 0.0, 1.8)
const STATION_ORIGIN := Vector3(8.0, 0.0, 0.45)

var _failures: Array[String] = []
var _warnings: Array[String] = []
var _captured_images: Dictionary = {}
var _semantic_frames: Array[Dictionary] = []
var _resource_snapshot: Dictionary = {}
var _stage: Node3D
var _player: PlayerController
var _motion_player: AnimationPlayer
var _motion_library: AnimationLibrary
var _camera: Camera3D
var _seat_anchor: Marker3D
var _pilot_presentation: PilotSkinnedPresentation
var _pilot_visual_root: Node3D
var _pilot_rig: Node3D
var _pilot_skeleton: Skeleton3D
var _pilot_suit: MeshInstance3D
var _bone_indices: Dictionary = {}
var _boarding_events := 0
var _disembarking_events := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("PLAYER_MOTION_CAPTURE_PARSE_OK")
		quit(0)
		return

	_configure_native_capture()
	_release_motion_actions()
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_check(
		directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
		"player-motion output directory is available"
	)

	_stage = Node3D.new()
	_stage.name = "PlayerMotionForwardCapture"
	root.add_child(_stage)
	_build_environment()
	_build_ground_fixture()
	_build_pilot_station()
	_build_lighting()

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_check(_player != null, "production player.tscn instantiates as PlayerController")
	if _player == null:
		_finish()
		return
	_stage.add_child(_player)
	_player.boarding_completed.connect(func() -> void: _boarding_events += 1)
	_player.disembarking_completed.connect(func() -> void: _disembarking_events += 1)
	await process_frame
	await physics_frame
	_player.set_camera_active(false)
	_player.set_control_enabled(true)
	_player.teleport_to(Transform3D(Basis.IDENTITY, LOCOMOTION_ORIGIN))

	_pilot_presentation = _player.get_node_or_null(PILOT_WRAPPER_PATH) as PilotSkinnedPresentation
	_pilot_visual_root = (
		_pilot_presentation.get_visual_root() if _pilot_presentation != null else null
	)
	_pilot_rig = (
		_pilot_visual_root.get_node_or_null("PilotRig") as Node3D
		if _pilot_visual_root != null else null
	)
	_pilot_skeleton = (
		_pilot_presentation.get_skeleton() if _pilot_presentation != null else null
	)
	var suit_candidates := (
		_pilot_visual_root.find_children("PilotSuit", "MeshInstance3D", true, false)
		if _pilot_visual_root != null else []
	)
	_pilot_suit = suit_candidates[0] as MeshInstance3D if suit_candidates.size() == 1 else null
	_motion_player = _player.get_motion_animation_player()
	_motion_library = _motion_player.get_animation_library(&"") if _motion_player != null else null
	_cache_bone_indices()
	_validate_authored_motion_contract()
	_resource_snapshot = _snapshot_persistent_resources()

	_camera = Camera3D.new()
	_camera.name = "PlayerMotionEvidenceCamera"
	_camera.near = 0.06
	_camera.far = 300.0
	_stage.add_child(_camera)
	_camera.current = true
	_check(
		_stage.find_children("*", "CanvasLayer", true, false).is_empty()
		and _stage.find_child("HUD", true, false) == null,
		"isolated evidence stage is HUD-free"
	)

	await _wait_physics_frames(8)
	_check(_player.is_on_floor(), "production CharacterBody settles on the real collision floor")
	_frame_character(_player.global_position, 50.0)
	await _capture_semantic_frame(
		CAPTURE_FILES[0],
		&"idle",
		{"grounded": true, "speed_band": "still", "station_clear": true}
	)

	Input.action_press(&"move_forward")
	var reached_walk := await _wait_for_motion_state(&"walk")
	_check(reached_walk, "ordinary production input reaches authored walk")
	# Sample contact A at the end of the first natural loop so the controller's
	# normal locomotion crossfade has fully yielded to the imported walk cycle.
	var contact_a_ready := await _wait_for_clip_phase(&"walk", 0.76, 0.035)
	_check(contact_a_ready, "walk naturally advances to the imported contact-A phase")
	var contact_a_left := _get_bone_pose_rotation(&"thigh_l")
	var contact_a_right := _get_bone_pose_rotation(&"thigh_r")
	_frame_character(_player.global_position, 50.0)
	await _capture_semantic_frame(
		CAPTURE_FILES[1],
		&"walk",
		{"grounded": true, "contact": "A", "natural_phase_target_seconds": 0.76, "travel_facing": true}
	)

	var contact_b_ready := await _wait_for_clip_phase(&"walk", 0.44, 0.035)
	_check(contact_b_ready, "walk naturally advances to the imported contact-B phase")
	var contact_b_left := _get_bone_pose_rotation(&"thigh_l")
	var contact_b_right := _get_bone_pose_rotation(&"thigh_r")
	_check(
		contact_a_left.angle_to(contact_b_left) > 0.65
		and contact_a_right.angle_to(contact_b_right) > 0.65,
		"walk contacts alternate both imported thigh bones without direct clip seeking"
	)
	_frame_character(_player.global_position, 50.0)
	await _capture_semantic_frame(
		CAPTURE_FILES[2],
		&"walk",
		{"grounded": true, "contact": "B", "natural_phase_target_seconds": 0.44, "travel_facing": true}
	)

	Input.action_press(&"sprint_boost")
	var reached_run := await _wait_for_motion_state(&"run")
	_check(reached_run, "sprint input reaches the distinct authored run state")
	var run_phase_ready := await _wait_for_clip_phase(&"run", 0.28, 0.07)
	_check(run_phase_ready, "run naturally advances to a readable long-stride phase")
	_frame_character(_player.global_position, 51.0)
	await _capture_semantic_frame(
		CAPTURE_FILES[3], &"run", {"grounded": true, "speed_band": "sprint", "travel_facing": true}
	)

	Input.action_release(&"sprint_boost")
	Input.action_release(&"move_forward")
	var returned_idle := await _wait_for_motion_state(&"idle")
	_check(returned_idle and _player.is_on_floor(), "locomotion decelerates to grounded idle")
	Input.action_press(&"jump")
	await physics_frame
	await process_frame
	Input.action_release(&"jump")
	var reached_jump := await _wait_for_motion_state(&"jump")
	_check(reached_jump, "physical jump input reaches authored ascent")
	var ascent_ready := await _wait_for_upward_speed_between(3.5, 5.0)
	_check(ascent_ready, "jump capture occurs during positive physical ascent")
	_frame_character(_player.global_position, 49.0, Vector3(0.0, 0.12, 0.0))
	await _capture_semantic_frame(
		CAPTURE_FILES[4],
		&"jump",
		{"grounded": false, "vertical_motion": "ascending_clear", "minimum_root_height_m": 0.55}
	)

	var reached_airborne := await _wait_for_motion_state(&"airborne")
	_check(reached_airborne, "physical descent selects authored airborne hold")
	var descent_ready := await _wait_for_upward_speed_between(-4.0, -2.0)
	_check(descent_ready, "airborne capture occurs during negative physical descent")
	_frame_character(_player.global_position, 49.0, Vector3(0.0, 0.12, 0.0))
	await _capture_semantic_frame(
		CAPTURE_FILES[5],
		&"airborne",
		{"grounded": false, "vertical_motion": "descending_midair", "minimum_root_height_m": 0.65}
	)

	var landed_idle := await _wait_for_grounded_idle()
	_check(landed_idle, "jump lifecycle lands through the production CharacterBody state machine")
	_player.set_control_enabled(false)
	var lifecycle_origin := Transform3D(
		Basis(Vector3.UP, deg_to_rad(-18.0)),
		STATION_ORIGIN + Vector3(4.15, 0.0, 0.62)
	)
	_player.teleport_to(lifecycle_origin)
	await _wait_physics_frames(3)
	var boarding_entry := Transform3D(
		Basis(Vector3.UP, deg_to_rad(-34.0)),
		STATION_ORIGIN + Vector3(1.72, 0.28, 0.16)
	)
	_check(
		_player.begin_boarding(boarding_entry, _seat_anchor, 1.5),
		"public physical boarding API accepts the live station seat"
	)
	var boarding_ready := await _wait_for_motion_state(&"boarding")
	boarding_ready = boarding_ready and await _wait_for_clip_phase(&"boarding", 0.25, 0.045)
	_check(
		boarding_ready and not _player.is_seated()
		and _player.global_position.y <= 0.5
		and _player.global_position.distance_to(_seat_anchor.global_position) >= 1.4
		and _player.global_position.distance_to(_seat_anchor.global_position) <= 4.2,
		"boarding frame is an early, low step-in connected to the live station"
	)
	_frame_boarding_transition()
	await _capture_semantic_frame(
		CAPTURE_FILES[6],
		&"boarding",
		{
			"embodiment": "BOARDING",
			"collision_suspended": true,
			"transition_read": "early_low_step_in",
			"maximum_root_height_m": 0.5,
		}
	)

	var seated_ready := await _wait_for_seated()
	_check(seated_ready and _boarding_events == 1, "boarding completes exactly once at the live seat")
	var seated_phase_ready := await _wait_for_clip_phase(&"seated_control", 0.6, 0.11)
	_check(seated_phase_ready, "seated control advances through the persistent authored clip")
	_frame_lifecycle_station(48.0)
	await _capture_semantic_frame(
		CAPTURE_FILES[7],
		&"seated_control",
		{"embodiment": "SEATED", "seat_anchor_error_m": _player.global_position.distance_to(_seat_anchor.global_position)}
	)

	var exit_transform := Transform3D(
		Basis(Vector3.UP, deg_to_rad(22.0)),
		STATION_ORIGIN + Vector3(4.2, 0.0, 0.92)
	)
	_check(
		_player.begin_disembark(exit_transform, 1.35),
		"public physical disembark API accepts the grounded recovery target"
	)
	var disembark_ready := await _wait_for_motion_state(&"disembark_recovery")
	disembark_ready = disembark_ready and await _wait_for_clip_phase(&"disembark_recovery", 0.55, 0.05)
	_check(
		disembark_ready and not _player.is_seated()
		and _player.global_position.x >= STATION_ORIGIN.x + 1.9
		and _player.global_position.x <= exit_transform.origin.x - 0.45,
		"disembark frame is clear of the console and visibly progressing along the exit path"
	)
	_frame_disembark_recovery()
	await _capture_semantic_frame(
		CAPTURE_FILES[8],
		&"disembark_recovery",
		{
			"embodiment": "DISEMBARKING",
			"collision_suspended": true,
			"console_clear_side": true,
		}
	)

	var recovered := await _wait_for_disembark_recovery(exit_transform)
	_check(recovered, "disembark restores grounded on-foot collision and authored idle")
	_check(_boarding_events == 1 and _disembarking_events == 1, "physical lifecycle emits each completion exactly once")
	_validate_persistent_resources()
	_validate_capture_set()
	_write_evidence_manifest()
	_finish()


func _configure_native_capture() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	var display_name := DisplayServer.get_name()
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	_check(display_name == "X11", "capture uses a native X11 display")
	_check(root.size == CAPTURE_RESOLUTION, "native root viewport accepts exact 2560x1440 output")
	print(
		"PLAYER_MOTION_RENDERER: method=%s adapter=%s display=%s requested=%dx%d"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			display_name,
			CAPTURE_RESOLUTION.x,
			CAPTURE_RESOLUTION.y,
		]
	)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "PlayerMotionEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("061522")
	sky_material.sky_horizon_color = Color("315363")
	sky_material.ground_bottom_color = Color("03070b")
	sky_material.ground_horizon_color = Color("24343b")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.44
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9bb9bd")
	environment.ambient_light_energy = 0.43
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.glow_bloom = 0.035
	environment.ssao_enabled = true
	environment.ssao_radius = 1.45
	environment.ssao_intensity = 2.0
	environment.ssil_enabled = true
	environment.ssil_radius = 2.1
	environment.ssil_intensity = 0.65
	world_environment.environment = environment
	_stage.add_child(world_environment)


func _build_ground_fixture() -> void:
	var floor := StaticBody3D.new()
	floor.name = "PlayerMotionRealGround"
	floor.collision_layer = 1
	floor.collision_mask = 0
	_stage.add_child(floor)
	var floor_material := _material(Color("182a31"), 0.54, 0.42)
	var floor_mesh := _box_mesh_node(
		"GroundDeck", Vector3(0.0, -0.16, -18.0), Vector3(64.0, 0.32, 76.0), floor_material
	)
	floor.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(64.0, 0.32, 76.0)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(0.0, -0.16, -18.0)
	floor.add_child(floor_collision)

	var stripe_material := _material(Color("d29431"), 0.18, 0.55, Color("6d3d0d"), 0.32)
	for stripe_x in [-2.1, 2.1]:
		_stage.add_child(_box_mesh_node(
			"DeckStripe", Vector3(stripe_x, 0.012, -4.5), Vector3(0.09, 0.024, 23.0), stripe_material
		))
	for rung_z in range(-12, 7, 2):
		_stage.add_child(_box_mesh_node(
			"DeckRung", Vector3(0.0, 0.014, float(rung_z)), Vector3(4.3, 0.026, 0.055), stripe_material
		))

	var rear_wall_material := _material(Color("102029"), 0.62, 0.36)
	_stage.add_child(_box_mesh_node(
		"MotionBackdrop", Vector3(0.0, 3.5, 5.8), Vector3(30.0, 7.0, 0.35), rear_wall_material
	))
	var cyan_material := _material(Color("2a9ca2"), 0.25, 0.38, Color("2a9ca2"), 1.1)
	for marker_x in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		_stage.add_child(_box_mesh_node(
			"BackdropMarker", Vector3(marker_x, 2.6, 5.58), Vector3(0.07, 3.8, 0.04), cyan_material
		))


func _build_pilot_station() -> void:
	var station := Node3D.new()
	station.name = "PhysicalPilotStation"
	station.position = STATION_ORIGIN
	_stage.add_child(station)
	var structure_material := _material(Color("263942"), 0.7, 0.31)
	var cushion_material := _material(Color("08171c"), 0.12, 0.84)
	var amber_material := _material(Color("d39732"), 0.25, 0.4, Color("74410f"), 0.42)
	station.add_child(_box_mesh_node(
		"StationPlinth", Vector3(0.0, 0.12, 0.15), Vector3(2.7, 0.24, 2.65), structure_material
	))
	station.add_child(_box_mesh_node(
		"SeatPan", Vector3(0.0, 0.69, 0.35), Vector3(0.82, 0.2, 0.82), cushion_material
	))
	station.add_child(_box_mesh_node(
		"SeatBack", Vector3(0.0, 1.13, 0.72), Vector3(0.9, 1.05, 0.18), cushion_material,
		Vector3(deg_to_rad(10.0), 0.0, 0.0)
	))
	for side in [-1.0, 1.0]:
		station.add_child(_box_mesh_node(
			"SideConsole", Vector3(side * 0.74, 0.78, -0.05), Vector3(0.34, 0.56, 1.4), structure_material
		))
		station.add_child(_box_mesh_node(
			"ConsoleLight", Vector3(side * 0.74, 1.075, -0.28), Vector3(0.18, 0.035, 0.42), amber_material
		))
	station.add_child(_box_mesh_node(
		"InstrumentPanel", Vector3(0.0, 1.19, -0.86), Vector3(1.55, 0.62, 0.14), structure_material,
		Vector3(deg_to_rad(-10.0), 0.0, 0.0)
	))
	station.add_child(_box_mesh_node(
		"InstrumentDisplay", Vector3(0.0, 1.2, -0.944), Vector3(0.92, 0.34, 0.035), amber_material,
		Vector3(deg_to_rad(-10.0), 0.0, 0.0)
	))
	_seat_anchor = Marker3D.new()
	_seat_anchor.name = "LivePilotSeatAnchor"
	# PlayerController's root is a feet-frame; the authored seated legs place the
	# pelvis 0.72 m above it, matching the capture station's seat pan.
	_seat_anchor.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.34))
	station.add_child(_seat_anchor)


func _build_lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "PlayerMotionKey"
	key.rotation_degrees = Vector3(-42.0, -31.0, 0.0)
	key.light_color = Color("f1e8d5")
	key.light_energy = 1.45
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 45.0
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.name = "PlayerMotionRim"
	rim.rotation_degrees = Vector3(-24.0, 147.0, 0.0)
	rim.light_color = Color("62c9d4")
	rim.light_energy = 0.74
	_stage.add_child(rim)
	var fill := OmniLight3D.new()
	fill.name = "PlayerMotionFill"
	fill.position = Vector3(-4.5, 4.8, -3.0)
	fill.light_color = Color("6db1c5")
	fill.light_energy = 2.2
	fill.omni_range = 18.0
	fill.shadow_enabled = false
	_stage.add_child(fill)


func _validate_authored_motion_contract() -> void:
	_check(_player is CharacterBody3D, "production PlayerController remains the CharacterBody3D authority")
	_check(
		_pilot_presentation != null
		and _pilot_presentation.name == &"PilotSkinnedPresentation"
		and _player.get_node_or_null(PILOT_WRAPPER_PATH) == _pilot_presentation,
		"production player mounts the exact PilotSkinnedPresentation wrapper"
	)
	_check(
		_pilot_presentation != null
		and _pilot_presentation.transform.is_equal_approx(Transform3D.IDENTITY),
		"imported pilot wrapper retains its identity mounting transform"
	)
	_check(_motion_player != null, "production player exposes its imported PilotAnimationPlayer")
	_check(_motion_library != null, "imported PilotAnimationPlayer owns one default library")
	_validate_exact_rig_and_skin()
	if _motion_player == null or _motion_library == null or _pilot_presentation == null:
		return
	var asset_audit := _pilot_presentation.get_asset_audit_report()
	_check(bool(asset_audit.get("valid", false)), "mounted Blender pilot passes its complete asset audit")
	if not bool(asset_audit.get("valid", false)):
		print("PLAYER_MOTION_PILOT_AUDIT_ERRORS: ", asset_audit.get("errors", []))
	_check(
		str(asset_audit.get("asset_path", "")) == PILOT_GLTF_PATH
		and str(asset_audit.get("source_path", "")) == PILOT_BLEND_PATH,
		"wrapper identifies the exact runtime GLB and editable Blender source"
	)
	_check(
		int(asset_audit.get("forbidden_authority_node_count", -1)) == 0
		and not bool(asset_audit.get("gameplay_authority", true)),
		"imported subtree contains no gameplay-authority nodes"
	)
	var audit := _player.get_pilot_motion_audit()
	_check(
		audit.get("version", &"") == &"blender_skinned_motion_v2"
		and audit.get("authorship", &"") == &"original_script_assisted_blender",
		"motion audit identifies the exact Blender-skinned v2 authored set"
	)
	_check(
		not bool(audit.get("motion_capture", true))
		and not bool(audit.get("runtime_clip_generation", true))
		and bool(audit.get("manual_physics_sampling", false))
		and bool(audit.get("asset_valid", false))
		and int(audit.get("bone_count", 0)) == REQUIRED_BONE_PARENTS.size(),
		"audit confirms imported deformation, exact rig size, and manual physics sampling"
	)
	_check(
		_motion_player.callback_mode_process
			== AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"imported AnimationPlayer remains in deterministic manual mode"
	)
	_check(
		_motion_player == _pilot_presentation.get_animation_player()
		and _motion_player.name == &"PilotAnimationPlayer"
		and _motion_player.is_ancestor_of(_pilot_skeleton) == false,
		"controller samples the wrapper's persistent sibling PilotAnimationPlayer"
	)
	_check(
		_motion_player.get_animation_library_list() == [&""],
		"all imported clips remain in one unqualified default AnimationLibrary"
	)
	var actual_clips: Array[StringName] = _motion_library.get_animation_list()
	var exact_clips := actual_clips.size() == REQUIRED_CLIPS.size()
	for required_clip in REQUIRED_CLIPS:
		exact_clips = exact_clips and _motion_library.has_animation(required_clip)
	_check(exact_clips, "imported library contains exactly the required nine motion clips")
	_check(int(audit.get("clip_count", 0)) == REQUIRED_CLIPS.size(), "motion audit reports exactly nine clips")
	var imported_track_count := 0
	for clip_name in REQUIRED_CLIPS:
		var animation := _motion_library.get_animation(clip_name)
		_check(animation != null, "%s imported Animation resource is present" % clip_name)
		if animation == null:
			continue
		_check(
			animation.resource_path.begins_with(PILOT_GLTF_PATH + "::"),
			"%s retains direct GLB subresource provenance" % clip_name
		)
		_check(
			absf(animation.length - float(REQUIRED_CLIP_DURATIONS[clip_name])) <= 0.002,
			"%s retains its exact imported duration" % clip_name
		)
		_check(
			(animation.loop_mode != Animation.LOOP_NONE) == LOOPING_CLIPS.has(clip_name),
			"%s retains its exact loop/one-shot mode" % clip_name
		)
		_check(animation.get_track_count() > 0, "%s retains persistent bone deformation tracks" % clip_name)
		var tracks_are_imported := true
		for track_index in animation.get_track_count():
			tracks_are_imported = tracks_are_imported and animation.track_is_imported(track_index)
			if animation.track_is_imported(track_index):
				imported_track_count += 1
		_check(tracks_are_imported, "%s contains only Blender-imported source tracks" % clip_name)
	_check(
		imported_track_count >= 120
		and imported_track_count == int(audit.get("imported_track_count", -1)),
		"complete mounted library retains substantial audited multi-bone track coverage"
	)
	var presentation_audit := _player.get_pilot_presentation_audit()
	_check(
		presentation_audit.get("motion_version", &"") == audit.get("version", &"")
		and presentation_audit.get("motion_authorship", &"") == audit.get("authorship", &"")
		and presentation_audit.get("version", &"") == &"blender_skinned_v2"
		and not bool(presentation_audit.get("motion_capture", true))
		and int(presentation_audit.get("visible_part_count", 0)) == 2,
		"presentation and motion audits agree on the visible imported contract"
	)
	_validate_asset_manifest_provenance()


func _validate_exact_rig_and_skin() -> void:
	_check(
		_pilot_visual_root != null and _pilot_visual_root.name == &"PilotArt",
		"wrapper exposes the stable PilotArt visual root"
	)
	_check(
		_pilot_rig != null and _pilot_rig.name == &"PilotRig"
		and _pilot_rig.get_parent() == _pilot_visual_root,
		"PilotArt owns the exact PilotRig hierarchy"
	)
	_check(
		_pilot_skeleton != null and _pilot_skeleton.name == &"PilotSkeleton"
		and _pilot_skeleton.get_parent() == _pilot_rig,
		"wrapper exposes the exact PilotSkeleton direct child"
	)
	if _pilot_skeleton != null:
		_check(
			_pilot_skeleton.get_bone_count() == REQUIRED_BONE_PARENTS.size(),
			"mounted skeleton contains exactly the 23 required bones"
		)
		for bone_name: StringName in REQUIRED_BONE_PARENTS:
			var bone_index := _pilot_skeleton.find_bone(String(bone_name))
			var expected_parent := REQUIRED_BONE_PARENTS[bone_name] as StringName
			var actual_parent := &""
			if bone_index >= 0:
				var parent_index := _pilot_skeleton.get_bone_parent(bone_index)
				actual_parent = (
					_pilot_skeleton.get_bone_name(parent_index) if parent_index >= 0 else &""
				)
			_check(
				bone_index >= 0 and actual_parent == expected_parent,
				"%s retains its exact imported parent" % bone_name
			)
	var all_visual_meshes := (
		_pilot_visual_root.find_children("*", "MeshInstance3D", true, false)
		if _pilot_visual_root != null else []
	)
	var harness_release := (
		_pilot_visual_root.find_child("HarnessRelease", true, false) as MeshInstance3D
		if _pilot_visual_root != null else null
	)
	_check(
		all_visual_meshes.size() == 2 and _pilot_suit != null
		and harness_release != null,
		"PilotArt exposes one skinned suit and one rigid harness light"
	)
	if _pilot_suit == null:
		return
	_check(_pilot_suit.name == &"PilotSuit", "joined skinned mesh retains the semantic PilotSuit name")
	_check(_pilot_suit.mesh is ArrayMesh, "PilotSuit uses the imported authored ArrayMesh")
	_check(
		_pilot_suit.skin != null
		and _pilot_suit.skin.get_bind_count() == REQUIRED_BONE_PARENTS.size(),
		"PilotSuit Skin binds the exact 23-bone skeleton"
	)
	_check(
		_pilot_suit.get_node_or_null(_pilot_suit.skeleton) == _pilot_skeleton,
		"PilotSuit resolves its live PilotSkeleton deformation target"
	)
	_check(
		_pilot_suit.mesh != null
		and _pilot_suit.mesh.resource_path.begins_with(PILOT_GLTF_PATH + "::")
		and _pilot_suit.skin.resource_path.begins_with(PILOT_GLTF_PATH + "::"),
		"PilotSuit ArrayMesh and Skin retain direct GLB subresource provenance"
	)
	var role_names := PackedStringArray()
	if _pilot_suit.mesh != null:
		_check(_pilot_suit.mesh.get_surface_count() == 7, "PilotSuit excludes the rigid amber status-light surface")
		for surface_index in _pilot_suit.mesh.get_surface_count():
			var active_material := _pilot_suit.get_active_material(surface_index)
			if active_material != null:
				role_names.append(active_material.resource_name)
	if harness_release != null and harness_release.get_active_material(0) != null:
		role_names.append(harness_release.get_active_material(0).resource_name)
	var exact_roles := role_names.size() == REQUIRED_MATERIAL_ROLES.size()
	for required_role in REQUIRED_MATERIAL_ROLES:
		exact_roles = exact_roles and role_names.has(required_role)
	_check(exact_roles, "pilot presentation preserves the exact eight-role imported material separation")
	_check(
		_player.get_pilot_visual_parts().size() == 2
		and _player.get_pilot_visual_parts().has(_pilot_suit)
		and _player.get_pilot_visual_parts().has(harness_release)
		and _player.get_pilot_visual_root() == _pilot_visual_root,
		"PlayerController publishes the imported suit and rigid harness light"
	)
	_check(
		harness_release != null
		and harness_release.get_parent() is BoneAttachment3D
		and (harness_release.get_parent() as BoneAttachment3D).bone_name == &"spine_02"
		and harness_release.skin == null
		and harness_release.skeleton.is_empty(),
		"HarnessRelease remains outside skeletal vertex deformation"
	)
	var body_pivot := _player.get_node_or_null("VisualRoot/BodyPivot") as Node3D
	var visible_mesh_count := 0
	if body_pivot != null:
		for candidate in body_pivot.find_children("*", "MeshInstance3D", true, false):
			if (candidate as MeshInstance3D).is_visible_in_tree():
				visible_mesh_count += 1
	_check(visible_mesh_count == 2, "legacy proxy meshes remain inert while the two imported pilot meshes stay visible")


func _validate_asset_manifest_provenance() -> void:
	var manifest := _read_json(PILOT_MANIFEST_PATH)
	_check(
		int(manifest.get("schema_version", 0)) == 2
		and str(manifest.get("asset_id", "")) == "keth.pilot.motion.v2",
		"checked-in pilot manifest publishes the exact stable v2 asset identity"
	)
	_check(
		str(manifest.get("authorship", "")) == "original_script_assisted_blender"
		and not bool(manifest.get("motion_capture", true))
		and not bool(manifest.get("runtime_generation", true)),
		"manifest preserves honest Blender authorship and rejects mocap/runtime synthesis"
	)
	_check(
		str(manifest.get("glb_sha256", "")) == FileAccess.get_sha256(PILOT_GLTF_PATH)
		and str(manifest.get("blend_sha256", "")) == FileAccess.get_sha256(PILOT_BLEND_PATH)
		and str(manifest.get("generator_sha256", "")) == FileAccess.get_sha256(PILOT_GENERATOR_PATH),
		"manifest pins the exact runtime GLB, editable Blender source, and offline generator hashes"
	)
	var coordinates := manifest.get("coordinate_contract", {}) as Dictionary
	_check(
		str(coordinates.get("imported_visual_forward_axis", "")) == "+Z"
		and str(coordinates.get("mounted_player_forward_axis", "")).begins_with("-Z"),
		"manifest records the raw +Z face and mounted Player -Z compensation"
	)
	var actions := manifest.get("actions", []) as Array
	var exact_actions := actions.size() == REQUIRED_CLIPS.size()
	for clip_name in REQUIRED_CLIPS:
		var matching := actions.filter(func(action: Variant) -> bool:
			return action is Dictionary and str((action as Dictionary).get("runtime", "")) == String(clip_name)
		)
		exact_actions = exact_actions and matching.size() == 1
	_check(exact_actions, "manifest records one source action for every required runtime clip")


func _snapshot_persistent_resources() -> Dictionary:
	var animations: Dictionary = {}
	var paths: Dictionary = {}
	var track_counts: Dictionary = {}
	if _motion_library != null:
		for clip_name in REQUIRED_CLIPS:
			var animation := _motion_library.get_animation(clip_name)
			if animation != null:
				animations[clip_name] = animation.get_instance_id()
				paths[clip_name] = animation.resource_path
				track_counts[clip_name] = animation.get_track_count()
	var material_ids: Array[int] = []
	var material_paths: Array[String] = []
	var material_roles: Array[String] = []
	if _pilot_suit != null and _pilot_suit.mesh != null:
		for surface_index in _pilot_suit.mesh.get_surface_count():
			var material := _pilot_suit.get_active_material(surface_index)
			material_ids.append(material.get_instance_id() if material != null else 0)
			material_paths.append(material.resource_path if material != null else "")
			material_roles.append(material.resource_name if material != null else "")
	return {
		"player_id": _player.get_instance_id() if _player != null else 0,
		"presentation_id": _pilot_presentation.get_instance_id() if _pilot_presentation != null else 0,
		"visual_root_id": _pilot_visual_root.get_instance_id() if _pilot_visual_root != null else 0,
		"rig_id": _pilot_rig.get_instance_id() if _pilot_rig != null else 0,
		"skeleton_id": _pilot_skeleton.get_instance_id() if _pilot_skeleton != null else 0,
		"suit_id": _pilot_suit.get_instance_id() if _pilot_suit != null else 0,
		"mesh_id": _pilot_suit.mesh.get_instance_id() if _pilot_suit != null and _pilot_suit.mesh != null else 0,
		"mesh_path": _pilot_suit.mesh.resource_path if _pilot_suit != null and _pilot_suit.mesh != null else "",
		"skin_id": _pilot_suit.skin.get_instance_id() if _pilot_suit != null and _pilot_suit.skin != null else 0,
		"skin_path": _pilot_suit.skin.resource_path if _pilot_suit != null and _pilot_suit.skin != null else "",
		"material_ids": material_ids,
		"material_paths": material_paths,
		"material_roles": material_roles,
		"animation_player_id": _motion_player.get_instance_id() if _motion_player != null else 0,
		"library_id": _motion_library.get_instance_id() if _motion_library != null else 0,
		"animation_ids": animations,
		"animation_paths": paths,
		"animation_track_counts": track_counts,
	}


func _validate_persistent_resources() -> void:
	var final_snapshot := _snapshot_persistent_resources()
	_check(
		final_snapshot == _resource_snapshot,
		"player, wrapper, rig, Skeleton, PilotSuit, Skin, materials, library, and clips retain exact ObjectIDs across the full loop"
	)
	_check(
		_player.get_motion_animation_player() == _motion_player
		and _pilot_presentation.get_animation_player() == _motion_player
		and _pilot_presentation.get_skeleton() == _pilot_skeleton
		and _motion_player.get_animation_library(&"") == _motion_library,
		"full lifecycle still references the original imported AnimationPlayer, Skeleton, and library"
	)


func _wait_for_motion_state(expected_state: StringName, timeout_frames: int = MOTION_TIMEOUT_PHYSICS_FRAMES) -> bool:
	for _frame_index in timeout_frames:
		if _player.get_authored_motion_state() == expected_state:
			return true
		await physics_frame
	return _player.get_authored_motion_state() == expected_state


func _wait_for_clip_phase(expected_state: StringName, target_phase: float, tolerance: float) -> bool:
	for _frame_index in MOTION_TIMEOUT_PHYSICS_FRAMES:
		if _player.get_authored_motion_state() == expected_state:
			var animation_name := StringName(_motion_player.current_animation)
			if animation_name == expected_state:
				var length := _motion_player.current_animation_length
				var phase := _motion_player.current_animation_position
				var difference := absf(phase - target_phase)
				if target_phase <= tolerance and length > 0.0:
					difference = minf(difference, absf(length - phase))
				if difference <= tolerance:
					return true
		await physics_frame
	return false


func _cache_bone_indices() -> void:
	_bone_indices.clear()
	if _pilot_skeleton == null:
		return
	for bone_name: StringName in REQUIRED_BONE_PARENTS:
		_bone_indices[bone_name] = _pilot_skeleton.find_bone(String(bone_name))


func _get_bone_pose_rotation(bone_name: StringName) -> Quaternion:
	if _pilot_skeleton == null:
		return Quaternion.IDENTITY
	var bone_index := int(_bone_indices.get(bone_name, -1))
	return (
		_pilot_skeleton.get_bone_pose_rotation(bone_index)
		if bone_index >= 0 else Quaternion.IDENTITY
	)


func _get_bone_global_pose(bone_name: StringName) -> Transform3D:
	if _pilot_skeleton == null:
		return Transform3D.IDENTITY
	var bone_index := int(_bone_indices.get(bone_name, -1))
	return (
		_pilot_skeleton.get_bone_global_pose(bone_index)
		if bone_index >= 0 else Transform3D.IDENTITY
	)


func _wait_for_upward_speed_between(minimum: float, maximum: float) -> bool:
	for _frame_index in MOTION_TIMEOUT_PHYSICS_FRAMES:
		var upward_speed := _player.velocity.dot(_player.up_direction.normalized())
		if upward_speed >= minimum and upward_speed <= maximum:
			return true
		await physics_frame
	return false


func _wait_for_grounded_idle() -> bool:
	for _frame_index in MOTION_TIMEOUT_PHYSICS_FRAMES:
		if _player.is_on_floor() and _player.get_authored_motion_state() == &"idle":
			return true
		await physics_frame
	return false


func _wait_for_seated() -> bool:
	for _frame_index in MOTION_TIMEOUT_PHYSICS_FRAMES:
		if _player.is_seated() and _player.get_authored_motion_state() == &"seated_control":
			return true
		await physics_frame
	return false


func _wait_for_disembark_recovery(exit_transform: Transform3D) -> bool:
	for _frame_index in MOTION_TIMEOUT_PHYSICS_FRAMES:
		var collision := _player.get_node_or_null("PlayerCollision") as CollisionShape3D
		if (
			not _player.is_seated()
			and _player.get_authored_motion_state() == &"idle"
			and _player.global_position.distance_to(exit_transform.origin) <= 0.002
			and collision != null
			and not collision.disabled
			and _player.collision_layer != 0
		):
			return true
		await physics_frame
	return false


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in frame_count:
		await physics_frame


func _frame_character(focus_origin: Vector3, field_of_view: float, focus_offset: Vector3 = Vector3.ZERO) -> void:
	var focus := focus_origin + Vector3(0.0, 1.02, 0.0) + focus_offset
	_camera.global_position = focus_origin + Vector3(3.85, 2.25, -5.45) + focus_offset
	_camera.fov = field_of_view
	_camera.look_at(focus, Vector3.UP)
	_camera.current = true


func _frame_lifecycle_station(field_of_view: float) -> void:
	_camera.global_position = STATION_ORIGIN + Vector3(5.35, 2.75, -6.1)
	_camera.fov = field_of_view
	_camera.look_at(STATION_ORIGIN + Vector3(0.2, 1.0, 0.0), Vector3.UP)
	_camera.current = true


func _frame_boarding_transition() -> void:
	_camera.global_position = STATION_ORIGIN + Vector3(5.9, 2.25, -5.5)
	_camera.fov = 52.0
	_camera.look_at(STATION_ORIGIN + Vector3(1.55, 0.95, 0.22), Vector3.UP)
	_camera.current = true


func _frame_disembark_recovery() -> void:
	_camera.global_position = STATION_ORIGIN + Vector3(6.35, 2.35, -5.9)
	_camera.fov = 52.0
	_camera.look_at(STATION_ORIGIN + Vector3(2.35, 0.95, 0.48), Vector3.UP)
	_camera.current = true


func _capture_semantic_frame(file_name: String, expected_state: StringName, markers: Dictionary) -> void:
	var actual_state := _player.get_authored_motion_state()
	var current_clip := StringName(_motion_player.current_animation) if _motion_player != null else &""
	var bone_pose_witness := _capture_bone_pose_witness()
	_check(actual_state == expected_state, "%s has semantic motion state %s" % [file_name, expected_state])
	_check(current_clip == expected_state, "%s visibly samples persistent clip %s" % [file_name, expected_state])
	_validate_semantic_markers(file_name, expected_state, markers, bone_pose_witness)
	# GPU readback and PNG encoding can span several physics ticks under llvmpipe.
	# Freeze only after the production state machine reaches the requested pose;
	# the controller's manual AnimationPlayer then preserves that exact evidence
	# sample without direct seeking or any resource mutation.
	var was_physics_processing := _player.is_physics_processing()
	_player.set_physics_process(false)
	await _settle_render(2)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced an empty viewport image" % file_name)
		_player.set_physics_process(was_physics_processing)
		return
	var actual_size := Vector2i(image.get_width(), image.get_height())
	_check(actual_size == CAPTURE_RESOLUTION, "%s is exactly 2560x1440" % file_name)
	var statistics := _sample_luminance_statistics(image)
	var luminance_range := float(statistics.get("range", 0.0))
	var variance := float(statistics.get("variance", 0.0))
	_check(luminance_range >= MINIMUM_LUMINANCE_RANGE, "%s is nonblank (range %.5f)" % [file_name, luminance_range])
	_check(variance >= MINIMUM_LUMINANCE_VARIANCE, "%s contains tonal detail (variance %.6f)" % [file_name, variance])
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saves successfully" % file_name)
	if save_error != OK:
		_player.set_physics_process(was_physics_processing)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var byte_count := file.get_length() if file != null else 0
	_check(byte_count >= MINIMUM_PNG_BYTES, "%s contains substantive rendered detail (%d bytes)" % [file_name, byte_count])
	var semantic_record := _semantic_record(file_name, expected_state, markers, bone_pose_witness)
	semantic_record["png_bytes"] = byte_count
	semantic_record["luminance_range"] = snappedf(luminance_range, 0.000001)
	semantic_record["luminance_variance"] = snappedf(variance, 0.000001)
	semantic_record["sha256"] = FileAccess.get_sha256(ProjectSettings.globalize_path(path))
	_semantic_frames.append(semantic_record)
	_captured_images[file_name] = image
	print(
		"PLAYER_MOTION_CAPTURED: %s state=%s clip=%s phase=%.4f velocity=%s %dx%d %d bytes"
		% [
			ProjectSettings.globalize_path(path),
			expected_state,
			current_clip,
			_motion_player.current_animation_position,
			_player.velocity,
			actual_size.x,
			actual_size.y,
			byte_count,
		]
	)
	_player.set_physics_process(was_physics_processing)


func _validate_semantic_markers(
		file_name: String,
		expected_state: StringName,
		markers: Dictionary,
		bone_pose_witness: Dictionary
	) -> void:
	_check(
		bone_pose_witness.size() == WITNESS_BONES.size(),
		"%s records every required live Skeleton3D bone witness" % file_name
	)
	var root_pose := _pilot_skeleton.get_bone_pose(int(_bone_indices.get(&"root", -1)))
	var root_yaw := root_pose.basis.get_rotation_quaternion().get_euler().y
	_check(
		Vector2(root_pose.origin.x, root_pose.origin.z).length() <= 0.0001
		and absf(root_yaw) <= 0.0001,
		"%s leaves horizontal translation and yaw on PlayerController authority" % file_name
	)
	_check(
		_maximum_witness_pose_angle() >= 0.05,
		"%s contains observable imported multi-bone deformation" % file_name
	)
	var grounded_expected: Variant = markers.get("grounded")
	if grounded_expected is bool:
		_check(_player.is_on_floor() == bool(grounded_expected), "%s grounded marker matches physics" % file_name)
	var upward_speed := _player.velocity.dot(_player.up_direction.normalized())
	match str(markers.get("vertical_motion", "")):
		"ascending_clear":
			_check(
				upward_speed >= 3.5 and upward_speed <= 5.0,
				"%s has clear mid-ascent velocity (%.3f m/s)" % [file_name, upward_speed]
			)
		"descending_midair":
			_check(
				upward_speed >= -4.0 and upward_speed <= -2.0,
				"%s has controlled midair descent velocity (%.3f m/s)" % [file_name, upward_speed]
			)
	match str(markers.get("speed_band", "")):
		"still":
			_check(_horizontal_speed() <= 0.15, "%s has idle horizontal speed" % file_name)
		"sprint":
			_check(_horizontal_speed() > _player.walk_speed * 1.08, "%s has production run-speed motion" % file_name)
	if bool(markers.get("travel_facing", false)):
		var movement_up := _player.up_direction.normalized()
		var travel := _player.velocity.slide(movement_up).normalized()
		var visible_forward := (
			_player.get_pilot_visual_forward_direction().slide(movement_up).normalized()
		)
		_check(
			not travel.is_zero_approx()
			and not visible_forward.is_zero_approx()
			and visible_forward.dot(travel) >= 0.995,
			"%s visibly faces its unchanged physical travel direction" % file_name
		)
	match str(markers.get("contact", "")):
		"A":
			_check(
				_get_bone_pose_rotation(&"thigh_l").angle_to(
					_get_bone_pose_rotation(&"thigh_r")
				) >= 0.35,
				"%s preserves an opposed imported contact-A thigh pose" % file_name
			)
		"B":
			_check(
				_get_bone_pose_rotation(&"thigh_l").angle_to(
					_get_bone_pose_rotation(&"thigh_r")
				) >= 0.35,
				"%s preserves an opposed imported contact-B thigh pose" % file_name
			)
	if markers.has("minimum_root_height_m"):
		_check(
			_player.global_position.y >= float(markers.get("minimum_root_height_m", 0.0)),
			"%s has readable physical ground clearance" % file_name
		)
	if bool(markers.get("station_clear", false)):
		_check(
			_player.global_position.distance_to(_seat_anchor.global_position) >= 8.0,
			"%s is spatially isolated from the pilot console" % file_name
		)
	if markers.has("maximum_root_height_m"):
		_check(
			_player.global_position.y <= float(markers.get("maximum_root_height_m", INF)),
			"%s remains a low, connected step-in rather than a floating transfer" % file_name
		)
	if bool(markers.get("console_clear_side", false)):
		_check(
			_player.global_position.x >= STATION_ORIGIN.x + 1.9,
			"%s is on the camera-visible side of the station console" % file_name
		)
	if markers.has("collision_suspended"):
		var collision := _player.get_node_or_null("PlayerCollision") as CollisionShape3D
		_check(
			_player.collision_layer == 0 and _player.collision_mask == 0
			and collision != null and collision.disabled,
			"%s lifecycle marker has physically suspended embodied collision" % file_name
		)
	if expected_state == &"seated_control":
		_check(_player.is_seated(), "%s is in the public seated lifecycle state" % file_name)
		_check(
			_player.global_position.distance_to(_seat_anchor.global_position) <= 0.002,
			"%s follows the exact live seat anchor" % file_name
		)
		_check(
			_get_bone_pose_rotation(&"forearm_l").angle_to(Quaternion.IDENTITY) >= 0.6
			and _get_bone_pose_rotation(&"forearm_r").angle_to(Quaternion.IDENTITY) >= 0.6,
			"%s articulates both imported forearm bones toward cockpit controls" % file_name
		)
	if expected_state == &"boarding":
		_check(
			_get_bone_pose_rotation(&"thigh_l").angle_to(Quaternion.IDENTITY) >= 0.25
			and _get_bone_pose_rotation(&"thigh_r").angle_to(Quaternion.IDENTITY) >= 0.25,
			"%s visibly folds both skinned legs during the physical step-in" % file_name
		)
	if expected_state == &"disembark_recovery":
		_check(
			_get_bone_pose_rotation(&"thigh_l").angle_to(Quaternion.IDENTITY) >= 0.15
			or _get_bone_pose_rotation(&"thigh_r").angle_to(Quaternion.IDENTITY) >= 0.15,
			"%s retains authored recovery articulation while the CharacterBody exits" % file_name
		)


func _semantic_record(
		file_name: String,
		expected_state: StringName,
		markers: Dictionary,
		bone_pose_witness: Dictionary
	) -> Dictionary:
	var presentation_audit := _player.get_pilot_presentation_audit()
	var collision := _player.get_node_or_null("PlayerCollision") as CollisionShape3D
	return {
		"file": file_name,
		"state": String(expected_state),
		"clip": _motion_player.current_animation,
		"clip_phase_seconds": snappedf(_motion_player.current_animation_position, 0.0001),
		"clip_length_seconds": snappedf(_motion_player.current_animation_length, 0.0001),
		"animation_player_id": _motion_player.get_instance_id(),
		"animation_resource_id": _motion_library.get_animation(expected_state).get_instance_id(),
		"grounded": _player.is_on_floor(),
		"horizontal_speed_mps": snappedf(_horizontal_speed(), 0.0001),
		"upward_speed_mps": snappedf(_player.velocity.dot(_player.up_direction.normalized()), 0.0001),
		"player_position": _vector3_array(_player.global_position),
		"bone_pose_witness": bone_pose_witness,
		"bone_pose_envelope": _bone_pose_envelope_dictionary(),
		"bind_bounds_not_pose_evidence": _aabb_dictionary(
			presentation_audit.get("bind_bounds", AABB()) as AABB
		),
		"presentation_id": _pilot_presentation.get_instance_id(),
		"skeleton_id": _pilot_skeleton.get_instance_id(),
		"suit_id": _pilot_suit.get_instance_id(),
		"skin_id": _pilot_suit.skin.get_instance_id(),
		"embodiment_state": int(presentation_audit.get("embodiment_state", -1)),
		"collision_layer": _player.collision_layer,
		"collision_mask": _player.collision_mask,
		"collision_disabled": collision.disabled if collision != null else true,
		"markers": markers.duplicate(true),
	}


func _capture_bone_pose_witness() -> Dictionary:
	var witness := {}
	if _pilot_skeleton == null:
		return witness
	for bone_name: StringName in WITNESS_BONES:
		var bone_index := int(_bone_indices.get(bone_name, -1))
		if bone_index < 0:
			continue
		var pose_rotation := _pilot_skeleton.get_bone_pose_rotation(bone_index)
		var global_pose := _pilot_skeleton.get_bone_global_pose(bone_index)
		witness[String(bone_name)] = {
			"pose_rotation_xyzw": _quaternion_array(pose_rotation),
			"global_position": _vector3_array(global_pose.origin),
			"global_rotation_xyzw": _quaternion_array(
				global_pose.basis.orthonormalized().get_rotation_quaternion()
			),
		}
	return witness


func _maximum_witness_pose_angle() -> float:
	var maximum_angle := 0.0
	for bone_name: StringName in WITNESS_BONES:
		if bone_name == &"root":
			continue
		maximum_angle = maxf(
			maximum_angle,
			_get_bone_pose_rotation(bone_name).angle_to(Quaternion.IDENTITY)
		)
	return maximum_angle


func _bone_pose_envelope_dictionary() -> Dictionary:
	var has_point := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	for bone_name: StringName in WITNESS_BONES:
		var bone_index := int(_bone_indices.get(bone_name, -1))
		if bone_index < 0:
			continue
		var point := _pilot_skeleton.get_bone_global_pose(bone_index).origin
		if not has_point:
			minimum = point
			maximum = point
			has_point = true
		else:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return _aabb_dictionary(AABB(minimum, maximum - minimum) if has_point else AABB())


func _horizontal_speed() -> float:
	var movement_up := _player.up_direction.normalized()
	return (_player.velocity - movement_up * _player.velocity.dot(movement_up)).length()


func _sample_luminance_statistics(image: Image) -> Dictionary:
	var darkest := 1.0
	var brightest := 0.0
	var total := 0.0
	var total_squared := 0.0
	var sample_count := 0
	for sample_y in 45:
		var y := roundi(float(sample_y) / 44.0 * float(image.get_height() - 1))
		for sample_x in 80:
			var x := roundi(float(sample_x) / 79.0 * float(image.get_width() - 1))
			var luminance := image.get_pixel(x, y).get_luminance()
			darkest = minf(darkest, luminance)
			brightest = maxf(brightest, luminance)
			total += luminance
			total_squared += luminance * luminance
			sample_count += 1
	var mean := total / float(sample_count)
	var variance := maxf(0.0, total_squared / float(sample_count) - mean * mean)
	return {"range": brightest - darkest, "mean": mean, "variance": variance}


func _validate_capture_set() -> void:
	for file_name in CAPTURE_FILES:
		_check(_captured_images.has(file_name), "required motion frame exists: %s" % file_name)
		_check(FileAccess.file_exists("%s/%s" % [OUTPUT_DIR, file_name]), "required PNG is present: %s" % file_name)
	_check(_semantic_frames.size() == CAPTURE_FILES.size(), "every PNG has one semantic state record")
	var required_pairs := [
		[CAPTURE_FILES[1], CAPTURE_FILES[2], "alternating walk contacts", 0.65],
		[CAPTURE_FILES[2], CAPTURE_FILES[3], "walk versus sprint stride", 0.08],
		[CAPTURE_FILES[4], CAPTURE_FILES[5], "ascent versus descent", 0.08],
		[CAPTURE_FILES[6], CAPTURE_FILES[7], "boarding versus seated", 0.08],
		[CAPTURE_FILES[7], CAPTURE_FILES[8], "seated versus recovery", 0.08],
	]
	for pair: Array in required_pairs:
		var first_name := str(pair[0])
		var second_name := str(pair[1])
		if not _captured_images.has(first_name) or not _captured_images.has(second_name):
			continue
		var comparison := _compare_images(
			_captured_images[first_name] as Image,
			_captured_images[second_name] as Image
		)
		var mean_difference := float(comparison.get("mean_difference", 0.0))
		var changed_fraction := float(comparison.get("changed_fraction", 0.0))
		_check(
			mean_difference >= MINIMUM_PAIR_MEAN_DIFFERENCE
			and changed_fraction >= MINIMUM_PAIR_CHANGED_FRACTION,
			"%s visibly vary (mean %.6f, changed %.4f)"
			% [str(pair[2]), mean_difference, changed_fraction]
		)
		var first_record := _semantic_record_for_file(first_name)
		var second_record := _semantic_record_for_file(second_name)
		var maximum_bone_delta := _maximum_recorded_bone_rotation_delta(
			first_record.get("bone_pose_witness", {}) as Dictionary,
			second_record.get("bone_pose_witness", {}) as Dictionary
		)
		_check(
			maximum_bone_delta >= float(pair[3]),
			"%s have distinct live Skeleton3D witnesses (maximum %.4f rad)"
			% [str(pair[2]), maximum_bone_delta]
		)


func _semantic_record_for_file(file_name: String) -> Dictionary:
	for record: Dictionary in _semantic_frames:
		if str(record.get("file", "")) == file_name:
			return record
	return {}


func _maximum_recorded_bone_rotation_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum_delta := 0.0
	for bone_name: StringName in WITNESS_BONES:
		var first_record := first.get(String(bone_name), {}) as Dictionary
		var second_record := second.get(String(bone_name), {}) as Dictionary
		var first_values := first_record.get("pose_rotation_xyzw", []) as Array
		var second_values := second_record.get("pose_rotation_xyzw", []) as Array
		if first_values.size() != 4 or second_values.size() != 4:
			continue
		var first_rotation := Quaternion(
			float(first_values[0]), float(first_values[1]),
			float(first_values[2]), float(first_values[3])
		).normalized()
		var second_rotation := Quaternion(
			float(second_values[0]), float(second_values[1]),
			float(second_values[2]), float(second_values[3])
		).normalized()
		maximum_delta = maxf(maximum_delta, first_rotation.angle_to(second_rotation))
	return maximum_delta


func _compare_images(first: Image, second: Image) -> Dictionary:
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for sample_y in 72:
		var y := roundi(float(sample_y) / 71.0 * float(first.get_height() - 1))
		for sample_x in 128:
			var x := roundi(float(sample_x) / 127.0 * float(first.get_width() - 1))
			var first_pixel := first.get_pixel(x, y)
			var second_pixel := second.get_pixel(x, y)
			var difference := (
				absf(first_pixel.r - second_pixel.r)
				+ absf(first_pixel.g - second_pixel.g)
				+ absf(first_pixel.b - second_pixel.b)
			) / 3.0
			total_difference += difference
			if difference >= PIXEL_CHANGE_THRESHOLD:
				changed_pixels += 1
			sample_count += 1
	return {
		"mean_difference": total_difference / float(sample_count),
		"changed_fraction": float(changed_pixels) / float(sample_count),
	}


func _write_evidence_manifest() -> void:
	var resource_ids: Dictionary = _resource_snapshot.get("animation_ids", {})
	var resource_paths: Dictionary = _resource_snapshot.get("animation_paths", {})
	var clip_records: Array[Dictionary] = []
	for clip_name in REQUIRED_CLIPS:
		var animation := _motion_library.get_animation(clip_name)
		var all_tracks_imported := animation != null and animation.get_track_count() > 0
		if animation != null:
			for track_index in animation.get_track_count():
				all_tracks_imported = all_tracks_imported and animation.track_is_imported(track_index)
		clip_records.append({
			"name": clip_name,
			"object_id": resource_ids.get(clip_name, 0),
			"resource_path": resource_paths.get(clip_name, ""),
			"length_seconds": animation.length if animation != null else 0.0,
			"expected_length_seconds": REQUIRED_CLIP_DURATIONS[clip_name],
			"track_count": animation.get_track_count() if animation != null else 0,
			"loop_mode": int(animation.loop_mode) if animation != null else -1,
			"expected_looping": LOOPING_CLIPS.has(clip_name),
			"all_tracks_imported": all_tracks_imported,
		})
	var manifest := {
		"schema": "player_motion_rendered_evidence_v2",
		"capture_resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"renderer": String(RenderingServer.get_current_rendering_method()),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"hud_free": true,
		"player_scene": "res://scenes/player/player.tscn",
		"player_scene_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://scenes/player/player.tscn")),
		"player_controller": "res://scripts/player/player_controller.gd",
		"player_controller_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://scripts/player/player_controller.gd")),
		"pilot_wrapper_scene": "res://scenes/player/pilot_skinned_presentation.tscn",
		"pilot_wrapper_scene_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://scenes/player/pilot_skinned_presentation.tscn")),
		"pilot_wrapper_script": "res://scenes/player/pilot_skinned_presentation.gd",
		"pilot_wrapper_script_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://scenes/player/pilot_skinned_presentation.gd")),
		"pilot_runtime_glb": PILOT_GLTF_PATH,
		"pilot_runtime_glb_sha256": FileAccess.get_sha256(PILOT_GLTF_PATH),
		"pilot_editable_blend": PILOT_BLEND_PATH,
		"pilot_editable_blend_sha256": FileAccess.get_sha256(PILOT_BLEND_PATH),
		"pilot_asset_manifest": PILOT_MANIFEST_PATH,
		"pilot_asset_manifest_sha256": FileAccess.get_sha256(PILOT_MANIFEST_PATH),
		"pilot_generator_sha256": FileAccess.get_sha256(PILOT_GENERATOR_PATH),
		"capture_harness": "res://tests/capture_player_motion.gd",
		"capture_harness_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://tests/capture_player_motion.gd")),
		"motion_version": "blender_skinned_motion_v2",
		"presentation_version": "blender_skinned_v2",
		"authorship": "original_script_assisted_blender",
		"motion_capture": false,
		"runtime_clip_generation": false,
		"manual_physics_sampling": true,
		"imported_visual_forward_axis": "+Z",
		"mounted_player_forward_axis": "-Z after BodyPivot PI yaw offset",
		"direct_glb_subresource_provenance": true,
		"semantic_pose_evidence": "live Skeleton3D bone local rotations and global transforms sampled during natural controller playback",
		"static_mesh_aabb_used_as_pose_proof": false,
		"persistent_ids_unchanged": _snapshot_persistent_resources() == _resource_snapshot,
		"player_object_id": _resource_snapshot.get("player_id", 0),
		"presentation_object_id": _resource_snapshot.get("presentation_id", 0),
		"visual_root_object_id": _resource_snapshot.get("visual_root_id", 0),
		"rig_object_id": _resource_snapshot.get("rig_id", 0),
		"skeleton_object_id": _resource_snapshot.get("skeleton_id", 0),
		"pilot_suit_object_id": _resource_snapshot.get("suit_id", 0),
		"pilot_suit_mesh_object_id": _resource_snapshot.get("mesh_id", 0),
		"pilot_skin_object_id": _resource_snapshot.get("skin_id", 0),
		"pilot_material_object_ids": _resource_snapshot.get("material_ids", []),
		"pilot_material_roles": _resource_snapshot.get("material_roles", []),
		"animation_player_object_id": _resource_snapshot.get("animation_player_id", 0),
		"animation_library_object_id": _resource_snapshot.get("library_id", 0),
		"clips": clip_records,
		"frames": _semantic_frames,
		"completion_events": {
			"boarding": _boarding_events,
			"disembarking": _disembarking_events,
		},
		"evidence_limits": [
			"These staged frames prove the production controller selected and naturally advanced the recorded imported clips in one deterministic capture run; they do not prove every interpolation sample is artistically final.",
			"Bone witnesses prove live Skeleton3D articulation and in-place root authority but do not reconstruct the GPU-skinned surface envelope or prove absence of every possible clipping angle.",
			"X11 Forward+ llvmpipe output is not evidence of native Windows rendering, native-GPU performance, controller ergonomics, multiplayer replication, or an uninterrupted human playthrough.",
			"Automated luminance and image-difference gates do not replace human animation, silhouette, or historical-fidelity sign-off.",
		],
		"warnings": _warnings,
	}
	var manifest_path := "%s/evidence_manifest.json" % OUTPUT_DIR
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	_check(manifest_file != null, "evidence manifest opens for writing")
	if manifest_file == null:
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	manifest_file.close()
	_check(FileAccess.file_exists(manifest_path), "source-current semantic evidence manifest is present")
	print("PLAYER_MOTION_MANIFEST: %s" % ProjectSettings.globalize_path(manifest_path))


func _vector3_array(value: Vector3) -> Array[float]:
	return [snappedf(value.x, 0.0001), snappedf(value.y, 0.0001), snappedf(value.z, 0.0001)]


func _quaternion_array(value: Quaternion) -> Array[float]:
	return [
		snappedf(value.x, 0.0001),
		snappedf(value.y, 0.0001),
		snappedf(value.z, 0.0001),
		snappedf(value.w, 0.0001),
	]


func _aabb_dictionary(value: AABB) -> Dictionary:
	return {"position": _vector3_array(value.position), "size": _vector3_array(value.size)}


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _material(
		albedo: Color,
		metallic: float,
		roughness: float,
		emission: Color = Color(0.0, 0.0, 0.0, 1.0),
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _box_mesh_node(
		part_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = mesh
	return instance


func _settle_render(frame_count: int) -> void:
	for _frame_index in frame_count:
		await process_frame


func _release_motion_actions() -> void:
	for action_name in [&"move_forward", &"sprint_boost", &"jump"]:
		Input.action_release(action_name)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PLAYER_MOTION_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("PLAYER_MOTION_FAIL: " + description)


func _finish() -> void:
	_release_motion_actions()
	if _failures.is_empty():
		print(
			"PLAYER_MOTION_CAPTURE_OK: %d HUD-free native X11 Forward+ frames at 2560x1440"
			% _semantic_frames.size()
		)
		quit(0)
	else:
		push_error("PLAYER_MOTION_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)
