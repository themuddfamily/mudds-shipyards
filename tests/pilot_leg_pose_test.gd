extends SceneTree

## Anatomical direction guard for the pilot's authored leg poses.
##
## The seated, boarding and disembark clips once swung the whole leg chain
## rearward: 78 degrees of hip HYPEREXTENSION with the knee folding forwards,
## so the seated pilot's thighs stuck straight out behind his back and his
## boots hung behind the seat. It read to players as legs breaking to get in.
##
## The cause was a sign convention, not a transform: every bone in this rig is
## built in the sagittal plane with roll 0, so a positive local-X key is a
## rotation about world +X. That tips an up-pointing bone (the spine) towards
## the face but swings a down-pointing bone (the leg chain) away from it. The
## pose tables are authored in the legacy Godot fallback rig's convention,
## where positive means "towards the face" for the legs too, so the leg chain
## needs its sagittal sign inverted on the way into bone-local euler. See
## SAGITTAL_SIGN_INVERTED_BONES in tools/blender/generate_pilot_motion_v2.py.
##
## These checks measure the shipped GLB's live deformed skeleton directly, in
## the raw imported frame, so they cannot be satisfied by a compensating yaw,
## mirror or negation applied further downstream: a mount-level flip moves the
## hip and the knee together and leaves every quantity here unchanged.

const GLB_PATH := "res://assets/models/pilot/pilot_motion_v2.glb"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

## The raw imported suit looks along its own local +Z; the Player mount, not
## this asset, supplies the half turn to the canonical -Z. Every measurement
## below is taken in this raw frame on purpose.
const IMPORTED_FACE_AXIS := Vector3.BACK

const CLIP_DURATIONS := {
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
## Clips that put the pilot into, or take him out of, the seat. Across all of
## these the knee must stay in front of the hip; he never reaches the seat by
## passing his thigh behind himself.
const SEAT_TRANSITION_CLIPS := [
	&"boarding", &"seated_control", &"disembark_recovery",
]
const SAMPLES_PER_CLIP := 17

## Knee flexion is measured as the sagittal cross product of the thigh and
## shin directions about world +X. A knee may straighten to zero but must
## never go negative, which is the shin swinging forward past the thigh.
const KNEE_FLEXION_FLOOR := -0.02
## Slack for the rest pose, where the thigh hangs vertically and the knee sits
## a fraction of a millimetre either side of the hip.
const SEAT_TRANSITION_KNEE_BEHIND_HIP_SLACK := -0.01
## A seated thigh is close to level, so the knee leads the hip by most of the
## 0.37 m thigh. Measured 0.362 m; held well clear of a rest-pose 0.0.
const SEATED_KNEE_AHEAD_OF_HIP_MINIMUM := 0.25
## A seated shin hangs under the knee rather than reaching back under the seat.
const SEATED_ANKLE_BELOW_KNEE_MINIMUM := 0.25
## Legacy fallback rig: one rigid leg node pointing -Y with forward at -Z, so
## its seated key is positive about X. The two authorities must agree that the
## seated knee goes forwards; their disagreement is what produced the defect.
const LEGACY_SEATED_LEG_ROTATION_X_MINIMUM := 0.5

var _failures: Array[String] = []
var _assertions := 0
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(GLB_PATH)
	_check(scene != null, "the imported pilot GLB loads")
	if scene == null:
		_finish()
		return
	var pilot: Node3D = scene.instantiate()
	root.add_child(pilot)
	await process_frame

	_skeleton = _first_of_class(pilot, "Skeleton3D") as Skeleton3D
	_animation_player = _first_of_class(pilot, "AnimationPlayer") as AnimationPlayer
	_check(_skeleton != null, "the imported pilot exposes its deformation skeleton")
	_check(_animation_player != null, "the imported pilot exposes its authored motion library")
	if _skeleton == null or _animation_player == null:
		pilot.queue_free()
		_finish()
		return
	_animation_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)

	_test_knee_never_folds_forwards()
	_test_seat_transition_keeps_the_knee_ahead_of_the_hip()
	_test_seated_pose_reads_as_sitting()
	_test_legacy_fallback_agrees_on_seated_direction()

	pilot.queue_free()
	await process_frame
	_finish()


## No clip, at any moment, may bend a knee the wrong way.
func _test_knee_never_folds_forwards() -> void:
	for clip_name in CLIP_DURATIONS:
		var worst := INF
		var worst_time := 0.0
		var worst_side := ""
		for sample in SAMPLES_PER_CLIP:
			var time := _sample_time(clip_name, sample)
			_pose_at(clip_name, time)
			for side in ["l", "r"]:
				var flexion := _knee_flexion(side)
				if flexion < worst:
					worst = flexion
					worst_time = time
					worst_side = side
		_check(
			worst >= KNEE_FLEXION_FLOOR,
			(
				"clip %s never folds a knee forwards (worst %.4f on %s at %.3fs)"
				% [clip_name, worst, worst_side, worst_time]
			)
		)


## Getting into and out of the seat is a forward movement throughout. This is
## the transition the player described, not just the pose it settles on.
func _test_seat_transition_keeps_the_knee_ahead_of_the_hip() -> void:
	for clip_name in SEAT_TRANSITION_CLIPS:
		var worst := INF
		var worst_time := 0.0
		var worst_side := ""
		for sample in SAMPLES_PER_CLIP:
			var time := _sample_time(clip_name, sample)
			_pose_at(clip_name, time)
			for side in ["l", "r"]:
				var lead := _knee_lead_over_hip(side)
				if lead < worst:
					worst = lead
					worst_time = time
					worst_side = side
		_check(
			worst >= SEAT_TRANSITION_KNEE_BEHIND_HIP_SLACK,
			(
				"clip %s never swings a knee behind its hip (worst %+.4f m on %s at %.3fs)"
				% [clip_name, worst, worst_side, worst_time]
			)
		)


## The settled seated pose, and the last frame of boarding that reaches it,
## must read as a pilot sitting: thigh forward and near level, shin down under
## the knee, boot ahead of the hip on the pedals.
func _test_seated_pose_reads_as_sitting() -> void:
	for probe in [
		{"clip": &"seated_control", "time": 0.0},
		{"clip": &"seated_control", "time": 0.6},
		{"clip": &"seated_control", "time": 1.2},
		{"clip": &"boarding", "time": 1.1},
	]:
		var clip_name: StringName = probe["clip"]
		var time: float = probe["time"]
		_pose_at(clip_name, time)
		for side in ["l", "r"]:
			var hip := _joint("thigh_" + side)
			var knee := _joint("calf_" + side)
			var ankle := _joint("foot_" + side)
			var toe := _joint("toe_" + side)
			var label := "%s at %.2fs (%s)" % [clip_name, time, side]
			_check(
				(knee - hip).dot(IMPORTED_FACE_AXIS) >= SEATED_KNEE_AHEAD_OF_HIP_MINIMUM,
				"seated %s carries the knee forward of the hip" % label
			)
			_check(
				knee.y - ankle.y >= SEATED_ANKLE_BELOW_KNEE_MINIMUM,
				"seated %s hangs the shin below the knee" % label
			)
			_check(
				(ankle - hip).dot(IMPORTED_FACE_AXIS) > 0.0,
				"seated %s puts the boot ahead of the hip" % label
			)
			_check(
				(toe - ankle).dot(IMPORTED_FACE_AXIS) > 0.0,
				"seated %s points the toe forward, not back under the seat" % label
			)


## The legacy scene-authored fallback drives one rigid leg node whose forward
## is -Z, so its seated key reads positive where the Blender leg bone reads
## negative. Both must still put the knee in front of the hip.
func _test_legacy_fallback_agrees_on_seated_direction() -> void:
	var scene: PackedScene = load(PLAYER_SCENE_PATH)
	_check(scene != null, "the legacy fallback player scene loads")
	if scene == null:
		return
	var state := scene.get_state()
	var library: AnimationLibrary = null
	for node_index in state.get_node_count():
		for property_index in state.get_node_property_count(node_index):
			var value: Variant = state.get_node_property_value(node_index, property_index)
			if value is AnimationLibrary:
				library = value
				break
			# AnimationPlayer stores its libraries in a name -> library map.
			if value is Dictionary:
				for entry: Variant in (value as Dictionary).values():
					if entry is AnimationLibrary:
						library = entry
						break
			if library != null:
				break
		if library != null:
			break
	_check(library != null, "the legacy fallback carries its authored motion library")
	if library == null:
		return
	var seated: Animation = library.get_animation(&"seated_control")
	_check(seated != null, "the legacy fallback authors a seated clip")
	if seated == null:
		return
	for leg_path in [
		NodePath("VisualRoot/BodyPivot/LeftLeg:rotation"),
		NodePath("VisualRoot/BodyPivot/RightLeg:rotation"),
	]:
		var track := seated.find_track(leg_path, Animation.TYPE_VALUE)
		_check(track >= 0, "legacy seated clip drives %s" % leg_path)
		if track < 0:
			continue
		var worst := INF
		for key in seated.track_get_key_count(track):
			var value: Vector3 = seated.track_get_key_value(track, key)
			worst = minf(worst, value.x)
		_check(
			worst >= LEGACY_SEATED_LEG_ROTATION_X_MINIMUM,
			(
				"legacy seated %s swings the leg forward, agreeing with the rig (worst %.3f)"
				% [leg_path, worst]
			)
		)


func _sample_time(clip_name: StringName, sample: int) -> float:
	var duration: float = CLIP_DURATIONS[clip_name]
	if SAMPLES_PER_CLIP <= 1:
		return 0.0
	return duration * float(sample) / float(SAMPLES_PER_CLIP - 1)


func _pose_at(clip_name: StringName, time: float) -> void:
	_animation_player.play(clip_name)
	_animation_player.seek(time, true)
	_animation_player.advance(0.0)


## World-space origin of a bone's head, in the raw imported frame.
func _joint(bone_name: String) -> Vector3:
	var index := _skeleton.find_bone(bone_name)
	if index < 0:
		return Vector3.ZERO
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(index)).origin


## Sagittal knee flexion about world +X. Positive is the shin rotating rearward
## relative to the thigh, which is the only direction a knee bends.
func _knee_flexion(side: String) -> float:
	var hip := _joint("thigh_" + side)
	var knee := _joint("calf_" + side)
	var ankle := _joint("foot_" + side)
	var thigh_direction := (knee - hip).normalized()
	var shin_direction := (ankle - knee).normalized()
	return thigh_direction.cross(shin_direction).x


## How far the knee leads the hip along the pilot's own face direction.
func _knee_lead_over_hip(side: String) -> float:
	return (_joint("calf_" + side) - _joint("thigh_" + side)).dot(IMPORTED_FACE_AXIS)


func _first_of_class(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _first_of_class(child, type_name)
		if found != null:
			return found
	return null


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PILOT_LEG_POSE_TEST_OK: %d assertions" % _assertions)
		quit()
		return
	for failure in _failures:
		print("PILOT_LEG_POSE_TEST_FAIL: ", failure)
	quit(1)
