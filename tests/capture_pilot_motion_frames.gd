extends SceneTree

## Rendered evidence harness for the authored pilot motion library.
##
## Motion cannot be judged from assertions. This fixture loads the shipped GLB
## directly, seeks every clip across an even sample of its own duration, and
## renders each sample from two fixed cameras into one contact sheet per clip.
## The profile camera is the important one: every sagittal defect this asset has
## had - hips swinging rearward, knees folding forwards, a pelvis that slides
## sideways instead of lifting - is only legible from a strict side view.
##
## It is a capture tool, not a test: it asserts nothing and is deliberately
## named without the _test suffix so the release matrix never collects it.
##
##   xvfb-run -a godot --path . --script tests/capture_pilot_motion_frames.gd

const GLB_PATH := "res://assets/models/pilot/pilot_motion_v2.glb"
const OUTPUT_DIR := "res://artifacts/pilot_motion_frames"

const TILE := Vector2i(400, 600)
const COLUMNS := 9
## 30 degrees of vertical field at 4.4 m frames 2.36 m of height around the
## pilot's waist: it holds a standing silhouette, a seated one and the pelvis
## rise through boarding without ever re-framing between clips, so heights are
## directly comparable from tile to tile.
const CAMERA_FOV := 30.0

## Raw imported suit looks along its own local +Z, so +Z is the pilot's front.
## The profile camera stands off his left side looking across him.
const CAMERAS := {
	"profile": {"position": Vector3(4.4, 0.95, 0.10), "target": Vector3(0.0, 0.95, 0.10)},
	"threequarter": {"position": Vector3(3.0, 1.30, 3.2), "target": Vector3(0.0, 0.95, 0.0)},
}

## Clips that end or begin in the seat get a reference cockpit drawn behind
## them. It is scenery for this fixture only - no ship scene is loaded and no
## gameplay authority is involved - but boarding cannot be judged without it:
## a man climbing into nothing just looks like a man levitating.
##
## Placement follows the shipped seat contract rather than taste. PilotSeatAnchor
## is a feet-frame marker at the cushion minus 0.72 m, and the PlayerController
## puts its own root on that marker, so with this fixture's root at the origin
## the cushion is at exactly y = 0.72 and the sill the pilot steps onto is one
## step below it.
const SEAT_CLIPS := [&"boarding", &"seated_control", &"disembark_recovery"]
const SEAT_CUSHION_HEIGHT := 0.72

const CLIP_SAMPLES := {
	&"idle": 9,
	&"walk": 9,
	&"run": 9,
	&"jump": 9,
	&"airborne": 9,
	&"boarding": 18,
	&"seated_control": 9,
	&"disembark_recovery": 18,
}

var _pilot: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _camera: Camera3D
var _cockpit: Node3D
var _written: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TILE
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	root.transparent_bg = false

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_absolute)

	var stage := Node3D.new()
	stage.name = "PilotMotionFrameStage"
	root.add_child(stage)
	_build_environment(stage)
	_build_reference_cockpit(stage)

	var packed: PackedScene = ResourceLoader.load(
		GLB_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	if packed == null:
		print("PILOT_MOTION_FRAMES_FAIL: the pilot GLB did not load")
		quit(1)
		return
	_pilot = packed.instantiate() as Node3D
	stage.add_child(_pilot)
	await process_frame

	_skeleton = _first_of_class(_pilot, "Skeleton3D") as Skeleton3D
	_animation_player = _first_of_class(_pilot, "AnimationPlayer") as AnimationPlayer
	if _skeleton == null or _animation_player == null:
		print("PILOT_MOTION_FRAMES_FAIL: the pilot GLB exposes no rig or motion library")
		quit(1)
		return
	_animation_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)

	_camera = Camera3D.new()
	_camera.near = 0.05
	_camera.far = 60.0
	_camera.fov = CAMERA_FOV
	stage.add_child(_camera)
	_camera.current = true

	print("PILOT_MOTION_FRAMES_RENDERER: method=%s display=%s size=%dx%d" % [
		RenderingServer.get_current_rendering_method(),
		DisplayServer.get_name(),
		root.size.x,
		root.size.y,
	])

	_report_ground_contact()

	for view_name: String in CAMERAS:
		var setup: Dictionary = CAMERAS[view_name]
		_camera.global_transform = Transform3D(
			Basis.IDENTITY, setup["position"] as Vector3
		).looking_at(setup["target"] as Vector3, Vector3.UP)
		for clip_name: StringName in CLIP_SAMPLES:
			_cockpit.visible = SEAT_CLIPS.has(clip_name)
			await _capture_clip_sheet(view_name, clip_name, int(CLIP_SAMPLES[clip_name]))

	for path in _written:
		print("PILOT_MOTION_FRAMES_WROTE: ", path)
	print("PILOT_MOTION_FRAMES_OK: %d sheets" % _written.size())
	quit(0)


func _capture_clip_sheet(view_name: String, clip_name: StringName, samples: int) -> void:
	var animation := _animation_player.get_animation(clip_name)
	if animation == null:
		return
	var duration := animation.length
	var rows := int(ceil(float(samples) / float(COLUMNS)))
	var columns: int = mini(samples, COLUMNS)
	var sheet := Image.create(TILE.x * columns, TILE.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.05, 0.055, 0.065))

	for sample in samples:
		# Loop clips repeat their first pose at the end, so sampling the closed
		# interval would duplicate it; one-shots need their true final frame.
		var span := float(samples) if animation.loop_mode != Animation.LOOP_NONE else float(samples - 1)
		var time := duration * float(sample) / maxf(span, 1.0)
		_animation_player.play(clip_name)
		_animation_player.seek(time, true)
		_animation_player.advance(0.0)
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, TILE),
			Vector2i((sample % COLUMNS) * TILE.x, (sample / COLUMNS) * TILE.y)
		)

	var file_name := "%s_%s.png" % [String(clip_name), view_name]
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	sheet.save_png(absolute)
	_written.append(file_name)


func _build_reference_cockpit(stage: Node3D) -> void:
	_cockpit = Node3D.new()
	_cockpit.name = "ReferenceCockpit"
	stage.add_child(_cockpit)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.20, 0.23, 0.28)
	shell.roughness = 0.72
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.34, 0.30, 0.22)
	trim.roughness = 0.85
	# position, size, material - the pilot faces +Z, so the seat back is behind
	# him at negative Z and the pedals and sill are ahead at positive Z.
	for piece in [
		[Vector3(0.0, SEAT_CUSHION_HEIGHT - 0.05, 0.10), Vector3(0.56, 0.10, 0.56), shell],
		[Vector3(0.0, SEAT_CUSHION_HEIGHT + 0.42, -0.22), Vector3(0.56, 0.86, 0.12), shell],
		[Vector3(-0.36, SEAT_CUSHION_HEIGHT + 0.14, 0.06), Vector3(0.10, 0.10, 0.46), trim],
		[Vector3(0.36, SEAT_CUSHION_HEIGHT + 0.14, 0.06), Vector3(0.10, 0.10, 0.46), trim],
		# The sill he steps onto, and the cockpit floor his boots end up on.
		[Vector3(0.0, 0.20, 0.62), Vector3(0.90, 0.40, 0.26), shell],
		[Vector3(0.0, 0.36, 0.30), Vector3(0.90, 0.08, 0.40), shell],
		# Cutaway: only the far coaming is drawn. Both cameras stand on +X, and
		# a near-side coaming is a wall across the lens - the pilot climbs in
		# behind it and nothing can be judged.
		[Vector3(-0.52, 1.06, 0.30), Vector3(0.14, 0.60, 0.90), shell],
		# The grab handle the reaching hand is authored towards, so it is
		# visible whether the hand actually arrives anywhere near it.
		[Vector3(-0.52, 1.62, 0.16), Vector3(0.16, 0.10, 0.34), trim],
	]:
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece[1] as Vector3
		block.mesh = box
		block.material_override = piece[2] as StandardMaterial3D
		_cockpit.add_child(block)
		block.position = piece[0] as Vector3
	_cockpit.visible = false


## Where the boot soles actually are, clip by clip.
##
## A still cannot show a sole floating two centimetres over the floor or
## disappearing through it, and that is the single most common way an in-place
## locomotion cycle with no foot IK reads as wrong. Each witness is a bind-pose
## sole corner carried by the bone that owns it: the deformation for a fully
## weighted vertex is pose_global * rest_global.inverse(), so applying that to
## the bind point lands exactly where the skinned sole lands.
const SOLE_WITNESSES := {
	"heel": {"bone": "foot_%s", "point": Vector3(0.0, 0.0, -0.085)},
	"ball": {"bone": "foot_%s", "point": Vector3(0.0, 0.0, 0.16)},
	"toe": {"bone": "toe_%s", "point": Vector3(0.0, 0.0, 0.29)},
}


func _report_ground_contact() -> void:
	for clip_name: StringName in CLIP_SAMPLES:
		var animation := _animation_player.get_animation(clip_name)
		if animation == null:
			continue
		var lowest := INF
		var lowest_time := 0.0
		var highest_minimum := -INF
		var highest_minimum_time := 0.0
		var steps := 60
		for step in steps + 1:
			var time := animation.length * float(step) / float(steps)
			_animation_player.play(clip_name)
			_animation_player.seek(time, true)
			_animation_player.advance(0.0)
			var frame_minimum := INF
			for side in ["l", "r"]:
				for witness_name: String in SOLE_WITNESSES:
					var witness: Dictionary = SOLE_WITNESSES[witness_name]
					var height := _sole_height(
						(witness["bone"] as String) % side,
						side,
						witness["point"] as Vector3
					)
					frame_minimum = minf(frame_minimum, height)
			if frame_minimum < lowest:
				lowest = frame_minimum
				lowest_time = time
			if frame_minimum > highest_minimum:
				highest_minimum = frame_minimum
				highest_minimum_time = time
		print(
			"PILOT_MOTION_FRAMES_GROUND: %-20s lowest_sole=%+.4f m at %.2fs  highest_lowest_sole=%+.4f m at %.2fs"
			% [clip_name, lowest, lowest_time, highest_minimum, highest_minimum_time]
		)


func _sole_height(bone_name: String, side: String, point: Vector3) -> float:
	var index := _skeleton.find_bone(bone_name)
	if index < 0:
		return INF
	var bind := point
	bind.x = 0.14 if side == "r" else -0.14
	var deformation := (
		_skeleton.get_bone_global_pose(index)
		* _skeleton.get_bone_global_rest(index).affine_inverse()
	)
	return (_skeleton.global_transform * deformation * bind).y


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.062, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.47, 0.56)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_energy = 2.1
	key.light_color = Color(1.0, 0.97, 0.92)
	stage.add_child(key)
	key.global_transform = Transform3D(Basis.IDENTITY, Vector3(3.0, 5.0, 4.0)).looking_at(
		Vector3(0.0, 1.0, 0.0), Vector3.UP
	)

	# A rim from behind separates the dark suit from the dark background so the
	# silhouette - which is what motion is actually read from - stays legible.
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.5
	rim.light_color = Color(0.55, 0.72, 1.0)
	rim.shadow_enabled = false
	stage.add_child(rim)
	rim.global_transform = Transform3D(Basis.IDENTITY, Vector3(-3.5, 2.6, -3.4)).looking_at(
		Vector3(0.0, 1.1, 0.0), Vector3.UP
	)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 14.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.16, 0.17, 0.19)
	floor_material.roughness = 0.95
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)

	# A metre grid of markers on the floor behind the pilot: with no horizontal
	# root motion these are the fixed reference that makes pelvis lift, foot
	# slide and stride length readable between frames of a contact sheet.
	for step in range(-3, 4):
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 1.9, 0.02)
		post.mesh = box
		var post_material := StandardMaterial3D.new()
		post_material.albedo_color = Color(0.26, 0.29, 0.34)
		post.material_override = post_material
		stage.add_child(post)
		post.global_position = Vector3(0.0, 0.95, float(step) * 0.5 - 2.6)


func _first_of_class(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _first_of_class(child, type_name)
		if found != null:
			return found
	return null
