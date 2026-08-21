extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PRESENTATION_SCENE := preload("res://scenes/player/pilot_skinned_presentation.tscn")
const GLB_PATH := "res://assets/models/pilot/pilot_motion_v2.glb"
const BLEND_PATH := "res://art_source/pilot/pilot_motion_v2.blend"

const EXPECTED_BONE_PARENTS := {
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

const EXPECTED_DURATIONS := {
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
const EXPECTED_MATERIAL_ROLES := [
	"AmberStatusLight",
	"CeramicArmor",
	"CyanStatusLight",
	"GraphiteArmor",
	"HarnessWebbing",
	"JointRubber",
	"PressureTextile",
	"VisorGlazing",
]
const FORBIDDEN_AUTHORITY_TYPES := [
	"CollisionObject3D",
	"CollisionShape3D",
	"Area3D",
	"Camera3D",
	"AudioStreamPlayer3D",
	"NavigationRegion3D",
	"NavigationAgent3D",
]
const LEGACY_FALLBACK_MESH_COUNT := 23

var _failures: Array[String] = []
var _assertions := 0
var _boarding_events := 0
var _disembarking_events := 0
var _motion_resource_ids: Dictionary = {}
var _animation_player_id := 0
var _skeleton_id := 0
var _suit_id := 0
var _mesh_resource_id := 0
var _skin_resource_id := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var fixture := Node3D.new()
	fixture.name = "PilotVisualTestWorld"
	root.add_child(fixture)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	_check(player != null, "production player scene instantiates as PlayerController")
	if player == null:
		_finish()
		return
	fixture.add_child(player)
	_check(
		bool(player.get_pilot_presentation_audit().get("valid", false))
		and player.get_motion_animation_player()
			== (player.get_node("VisualRoot/BodyPivot/PilotSkinnedPresentation") as PilotSkinnedPresentation).get_animation_player(),
		"Player ready atomically selects the valid imported presentation without a fallback frame"
	)
	player.set_physics_process(false)
	player.set_process(false)
	player.boarding_completed.connect(func() -> void: _boarding_events += 1)
	player.disembarking_completed.connect(func() -> void: _disembarking_events += 1)
	await process_frame

	_test_preserved_character_contract(player)
	var presentation := _test_integrated_presentation_contract(player)
	if presentation != null:
		_test_exact_imported_rig_and_skin(player, presentation)
		_test_imported_motion_library(player, presentation)
		_test_skeleton_pose_witnesses(player, presentation)
		await _test_motion_authority_intrusion_recovery(player, presentation)
	await _test_authored_locomotion_state_machine(player, fixture)
	await _test_standing_and_seated_lifecycle(player, fixture)
	await _test_periodic_integrity_fallback(fixture)
	await _test_destructive_motion_fallback(fixture)
	await _test_preready_legacy_poison_fails_closed(fixture)

	fixture.queue_free()
	await process_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"pilot fixture cleans up without orphan presentation nodes"
	)
	_finish()


func _test_preserved_character_contract(player: PlayerController) -> void:
	_check(player is CharacterBody3D, "pilot retains the CharacterBody3D gameplay root")
	var collision := player.get_node_or_null("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D if collision != null else null
	_check(capsule != null, "pilot retains the production capsule collision")
	if capsule != null:
		_check(is_equal_approx(capsule.radius, 0.38), "skinned presentation preserves capsule radius")
		_check(is_equal_approx(capsule.height, 1.94), "skinned presentation preserves capsule height")
	_check(
		collision != null and collision.position.is_equal_approx(Vector3(0.0, 0.97, 0.0)),
		"capsule remains grounded through the CharacterBody authority"
	)

	var body := player.get_node_or_null("VisualRoot/BodyPivot") as Node3D
	_check(body != null and body.position.is_zero_approx(), "BodyPivot remains the canonical visual-yaw mount")
	_check(
		body != null and absf(absf(wrapf(body.rotation.y, -PI, PI)) - PI) <= 0.001,
		"valid imported presentation starts at the canonical PI mount compensation"
	)
	_check(
		player.get_camera() != null
			and player.get_node_or_null("CameraRig/CameraYaw/CameraPitch/SpringArm3D") is SpringArm3D,
		"third-person camera rig remains available outside the visual asset"
	)
	var interaction_area := player.get_node_or_null("InteractionArea") as Area3D
	_check(interaction_area != null, "walk-up interaction authority remains on the Player root")
	_check(
		interaction_area != null
			and interaction_area.get_child_count() > 0
			and interaction_area.get_child(0) is CollisionShape3D,
		"interaction volume remains a native gameplay collision"
	)


func _test_integrated_presentation_contract(
	player: PlayerController
	) -> PilotSkinnedPresentation:
	var body := player.get_node_or_null("VisualRoot/BodyPivot") as Node3D
	var presentation := (
		body.get_node_or_null("PilotSkinnedPresentation") as PilotSkinnedPresentation
		if body != null else null
	)
	_check(
		presentation != null and presentation.get_parent() == body,
		"production BodyPivot owns the exact PilotSkinnedPresentation wrapper"
	)
	if presentation == null:
		return null

	var audit := player.get_pilot_presentation_audit()
	_check(bool(audit.get("valid", false)), "integrated Blender pilot passes audit schema 2")
	if not bool(audit.get("valid", false)):
		print("PILOT_PRESENTATION_AUDIT_ERRORS: ", audit.get("errors", []))
	_check(int(audit.get("schema_version", 0)) == 2, "integrated audit publishes schema version 2")
	_check(audit.get("version") == &"blender_skinned_v2", "audit identifies the Blender-skinned v2 presentation")
	_check(audit.get("authorship") == &"original_script_assisted_blender", "audit reports honest original Blender authorship")
	_check(not bool(audit.get("motion_capture", true)), "integrated pilot makes no motion-capture claim")
	_check(not bool(audit.get("runtime_clip_generation", true)), "integrated pilot does not synthesize runtime clips")
	_check(not bool(audit.get("gameplay_authority", true)), "imported presentation explicitly owns no gameplay authority")
	_check(int(audit.get("forbidden_authority_node_count", -1)) == 0, "audit finds no imported gameplay-authority nodes")
	_check(bool(audit.get("identity_transform", false)), "presentation wrapper retains its identity mount")
	_check(str(audit.get("asset_path", "")) == GLB_PATH, "audit identifies the exact runtime GLB")
	_check(
		str(audit.get("source_asset_path", "")) == GLB_PATH,
		"audit pins the untouched GLB source graph"
	)
	_check(
		str(audit.get("source_mesh_resource_path", "")).begins_with(GLB_PATH + "::"),
		"audit pins the imported PilotSuit mesh provenance"
	)
	_check(
		str(audit.get("source_skin_resource_path", "")).begins_with(GLB_PATH + "::"),
		"audit pins the imported Skin provenance"
	)
	_check(
		str(audit.get("source_rigid_harness_mesh_resource_path", "")).begins_with(
			GLB_PATH + "::"
		),
		"audit pins the unskinned HarnessRelease mesh provenance"
	)
	_check(
		bool(audit.get("resource_cache_isolated", false))
			and not str(audit.get("source_content_signature", "")).is_empty(),
		"audit binds isolated runtime resources to a signed canonical GLB graph"
	)
	_check(str(audit.get("source_path", "")) == BLEND_PATH, "audit identifies the editable Blender source")
	_check(int(audit.get("bone_count", 0)) == 23, "audit observes the complete 23-bone armature")
	_check(int(audit.get("skinned_mesh_count", 0)) == 1, "audit observes one joined skinned suit")
	_check(int(audit.get("rigid_harness_mesh_count", 0)) == 1, "audit observes one rigid harness light")
	_check(int(audit.get("weighted_bone_count", 0)) == 23, "audit observes all 23 skin bindings")
	_check(int(audit.get("material_role_count", 0)) == 8, "audit observes exactly eight imported material roles")
	_check(absf(float(audit.get("root_motion_horizontal_m", 1.0))) <= 0.0001, "imported motion leaves horizontal traversal to CharacterBody")
	_check(absf(float(audit.get("root_motion_yaw_rad", 1.0))) <= 0.0001, "imported motion leaves yaw to CharacterBody and BodyPivot")
	var bounds := audit.get("bind_bounds", AABB()) as AABB
	_check(bounds.size.y >= 1.90 and bounds.size.y <= 1.96, "bind silhouette remains a practical roughly 1.95 metre pilot")
	_check(absf(bounds.position.y) <= 0.002, "authored boot soles meet the standing ground plane")

	var visual_root := presentation.get_visual_root()
	_check(
		visual_root != null
			and visual_root == player.get_pilot_visual_root()
			and visual_root.name == &"PilotArt"
			and presentation.is_ancestor_of(visual_root),
		"Player API resolves the wrapper-owned PilotArt root without a proxy"
	)
	var forbidden_count := 0
	for type_name in FORBIDDEN_AUTHORITY_TYPES:
		forbidden_count += presentation.find_children("*", type_name, true, false).size()
	_check(forbidden_count == 0, "live wrapper subtree contains no collision, interaction, camera, audio, or navigation authority")

	var visible_meshes: Array[MeshInstance3D] = []
	var hidden_legacy_meshes := 0
	var exposed_legacy_meshes := 0
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if presentation.is_ancestor_of(mesh):
			if mesh.is_visible_in_tree():
				visible_meshes.append(mesh)
			continue
		if mesh.is_visible_in_tree():
			exposed_legacy_meshes += 1
		else:
			hidden_legacy_meshes += 1
	_check(
		visible_meshes.size() == 2,
		"one skinned suit and one rigid harness light are the sole visible pilot presentation"
	)
	_check(
		hidden_legacy_meshes == LEGACY_FALLBACK_MESH_COUNT and exposed_legacy_meshes == 0,
		"all 23 procedural/blockout fallback meshes remain present and hidden"
	)

	var active_animation_player := player.get_motion_animation_player()
	var legacy_animation_player := player.get_node_or_null("MotionAnimationPlayer") as AnimationPlayer
	_check(
		active_animation_player == presentation.get_animation_player()
			and presentation.is_ancestor_of(active_animation_player),
		"the imported PilotAnimationPlayer is the one visible deformation authority"
	)
	_check(
		legacy_animation_player != null
			and legacy_animation_player != active_animation_player
			and not legacy_animation_player.is_playing(),
		"legacy pivot AnimationPlayer remains inert rather than double-driving the suit"
	)
	return presentation


func _test_exact_imported_rig_and_skin(
	player: PlayerController,
	presentation: PilotSkinnedPresentation
	) -> void:
	var visual_root := presentation.get_visual_root()
	var skeleton := presentation.get_skeleton()
	_check(visual_root != null and visual_root.get_node_or_null("PilotRig") != null, "PilotArt owns the stable PilotRig hierarchy")
	_check(
		skeleton != null
			and skeleton.name == &"PilotSkeleton"
			and skeleton.get_parent() != null
			and skeleton.get_parent().name == &"PilotRig"
			and presentation.is_ancestor_of(skeleton),
		"wrapper resolves the exact PilotRig/PilotSkeleton ancestry"
	)
	if skeleton == null or visual_root == null:
		return
	_skeleton_id = skeleton.get_instance_id()
	_check(skeleton.get_bone_count() == EXPECTED_BONE_PARENTS.size(), "armature contains exactly the 23 required deformation bones")
	for bone_name: StringName in EXPECTED_BONE_PARENTS:
		var bone_index := skeleton.find_bone(String(bone_name))
		_check(bone_index >= 0, "%s bone is present" % bone_name)
		if bone_index < 0:
			continue
		var parent_index := skeleton.get_bone_parent(bone_index)
		var parent_name: StringName = skeleton.get_bone_name(parent_index) if parent_index >= 0 else &""
		_check(parent_name == EXPECTED_BONE_PARENTS[bone_name], "%s has the exact authored parent" % bone_name)

	var meshes := visual_root.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 2, "PilotArt contains one skinned suit and one rigid harness light")
	var suit := visual_root.find_child("PilotSuit", true, false) as MeshInstance3D
	var harness_release := visual_root.find_child("HarnessRelease", true, false) as MeshInstance3D
	if suit == null or harness_release == null:
		return
	_suit_id = suit.get_instance_id()
	_check(suit.name == &"PilotSuit", "joined mesh retains its exact PilotSuit identity")
	_check(suit.mesh is ArrayMesh, "PilotSuit uses imported ArrayMesh geometry rather than primitive proxies")
	_check(suit.skin is Skin, "PilotSuit owns an imported Skin resource")
	if suit.mesh == null or suit.skin == null:
		return
	_mesh_resource_id = suit.mesh.get_instance_id()
	_skin_resource_id = suit.skin.get_instance_id()
	_check(suit.skin.get_bind_count() == 23, "PilotSuit skin binds the complete 23-bone armature")
	_check(suit.get_node_or_null(suit.skeleton) == skeleton, "PilotSuit resolves its exact live PilotSkeleton target")
	_check(suit.mesh.get_surface_count() == 7, "PilotSuit excludes the rigid amber status-light surface")
	_check(suit.mesh.resource_path.begins_with(GLB_PATH + "::"), "PilotSuit ArrayMesh resource originates in the checked-in GLB")
	_check(suit.skin.resource_path.begins_with(GLB_PATH + "::"), "PilotSuit Skin resource originates in the checked-in GLB")

	var material_roles := PackedStringArray()
	var materials_from_glb := true
	for surface_index in suit.mesh.get_surface_count():
		var material := suit.get_active_material(surface_index)
		if material != null:
			material_roles.append(material.resource_name)
			materials_from_glb = materials_from_glb and material.resource_path.begins_with(GLB_PATH + "::")
	var harness_material := harness_release.get_active_material(0)
	if harness_material != null:
		material_roles.append(harness_material.resource_name)
		materials_from_glb = (
			materials_from_glb
			and harness_material.resource_path.begins_with(GLB_PATH + "::")
		)
	material_roles.sort()
	var expected_roles := PackedStringArray(EXPECTED_MATERIAL_ROLES)
	expected_roles.sort()
	_check(material_roles == expected_roles, "eight exact construction material roles survive the GLB boundary")
	_check(materials_from_glb, "every active pilot material resource originates in the checked-in GLB")
	_check(
		harness_release.get_parent() is BoneAttachment3D
		and (harness_release.get_parent() as BoneAttachment3D).bone_name == &"spine_02"
		and harness_release.skin == null
		and harness_release.skeleton.is_empty(),
		"HarnessRelease bypasses GPU skinning as a rigid spine_02 attachment"
	)
	_check(player.get_pilot_visual_parts().size() == 2, "Player API exposes the suit and rigid harness light")


func _test_imported_motion_library(
	player: PlayerController,
	presentation: PilotSkinnedPresentation
	) -> void:
	var motion_player := player.get_motion_animation_player()
	var skeleton := presentation.get_skeleton()
	var motion_audit := player.get_pilot_motion_audit()
	_check(
		motion_player != null and motion_player.name == &"PilotAnimationPlayer",
		"production Player exposes the imported PilotAnimationPlayer"
	)
	if motion_player == null or skeleton == null:
		return
	_animation_player_id = motion_player.get_instance_id()
	_check(
		motion_player.callback_mode_process
			== AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"imported motion advances deterministically with the controller physics tick"
	)
	_check(
		motion_audit.get("version") == &"blender_skinned_motion_v2"
			and motion_audit.get("authorship") == &"original_script_assisted_blender"
			and not bool(motion_audit.get("motion_capture", true)),
		"motion audit identifies original Blender-authored, non-mocap work"
	)
	_check(
		not bool(motion_audit.get("runtime_clip_generation", true))
			and bool(motion_audit.get("manual_physics_sampling", false))
			and bool(motion_audit.get("asset_valid", false)),
		"motion library is persistent imported data accepted by the asset audit"
	)
	_check(motion_player.get_animation_library_list() == [&""], "nine clips live in one unqualified default AnimationLibrary")
	var library := motion_player.get_animation_library(&"")
	_check(library != null and library.get_animation_list().size() == 9, "default library contains exactly the nine required clips")
	if library == null:
		return

	var imported_track_count := 0
	var animation_root := motion_player.get_node_or_null(NodePath(motion_player.root_node))
	for clip_name: StringName in EXPECTED_DURATIONS:
		var animation := library.get_animation(clip_name)
		_check(animation != null, "%s imported clip is present" % clip_name)
		if animation == null:
			continue
		_motion_resource_ids[clip_name] = animation.get_instance_id()
		_check(
			animation.resource_path.begins_with(GLB_PATH + "::"),
			"%s animation resource originates in the checked-in GLB" % clip_name
		)
		_check(
			absf(animation.length - float(EXPECTED_DURATIONS[clip_name])) <= 0.002,
			"%s retains its exact imported duration" % clip_name
		)
		_check(
			(animation.loop_mode != Animation.LOOP_NONE) == LOOPING_CLIPS.has(clip_name),
			"%s retains its exact loop/one-shot contract" % clip_name
		)
		_check(animation.get_track_count() > 0, "%s contains persistent bone deformation tracks" % clip_name)
		var exact_bone_tracks := true
		for track_index in animation.get_track_count():
			var track_path := animation.track_get_path(track_index)
			var track_target := (
				animation_root.get_node_or_null(NodePath(track_path.get_concatenated_names()))
				if animation_root != null else null
			)
			var bone_name := String(track_path.get_subname(0)) if track_path.get_subname_count() == 1 else ""
			var track_type := animation.track_get_type(track_index)
			exact_bone_tracks = (
				exact_bone_tracks
					and animation.track_is_imported(track_index)
					and track_target == skeleton
					and skeleton.find_bone(bone_name) >= 0
					and track_type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
			)
			if animation.track_is_imported(track_index):
				imported_track_count += 1
		_check(exact_bone_tracks, "%s contains only imported PilotSkeleton bone tracks" % clip_name)
	_check(imported_track_count >= 120, "complete library carries substantial imported multi-bone coverage")
	_check(
		int(presentation.get_asset_audit_report().get("imported_track_count", 0)) == imported_track_count,
		"schema-2 audit independently counts every imported bone track"
	)


func _test_skeleton_pose_witnesses(
	player: PlayerController,
	presentation: PilotSkinnedPresentation
	) -> void:
	var motion_player := player.get_motion_animation_player()
	var skeleton := presentation.get_skeleton()
	if motion_player == null or skeleton == null:
		return
	var left_thigh := skeleton.find_bone("thigh_l")
	var right_thigh := skeleton.find_bone("thigh_r")
	var left_forearm := skeleton.find_bone("forearm_l")
	var right_forearm := skeleton.find_bone("forearm_r")
	var root_bone := skeleton.find_bone("root")
	player.teleport_to(player.global_transform)
	var idle_left_thigh := skeleton.get_bone_pose_rotation(left_thigh)
	var idle_right_thigh := skeleton.get_bone_pose_rotation(right_thigh)
	var idle_left_forearm := skeleton.get_bone_pose_rotation(left_forearm)
	var idle_right_forearm := skeleton.get_bone_pose_rotation(right_forearm)

	motion_player.play(&"walk")
	motion_player.seek(0.0, true, true)
	var walk_left_a := skeleton.get_bone_pose_rotation(left_thigh)
	var walk_right_a := skeleton.get_bone_pose_rotation(right_thigh)
	var root_a := skeleton.get_bone_pose(root_bone)
	motion_player.seek(0.4, true, true)
	var walk_left_b := skeleton.get_bone_pose_rotation(left_thigh)
	var walk_right_b := skeleton.get_bone_pose_rotation(right_thigh)
	var root_b := skeleton.get_bone_pose(root_bone)
	_check(walk_left_a.angle_to(walk_left_b) > 0.7, "walk visibly deforms the left skinned leg through alternating contacts")
	_check(walk_right_a.angle_to(walk_right_b) > 0.7, "walk visibly deforms the right skinned leg through alternating contacts")
	_check(root_a.is_equal_approx(root_b), "walk never displaces or yaws the skeleton root")

	motion_player.play(&"run")
	motion_player.seek(0.0, true, true)
	var run_left_a := skeleton.get_bone_pose_rotation(left_thigh)
	motion_player.seek(0.28, true, true)
	var run_left_b := skeleton.get_bone_pose_rotation(left_thigh)
	_check(
		run_left_a.angle_to(run_left_b) > walk_left_a.angle_to(walk_left_b) + 0.25,
		"run has a distinctly longer authored skinned stride than walk"
	)

	motion_player.play(&"jump")
	motion_player.seek(0.42, true, true)
	var jump_left := skeleton.get_bone_pose_rotation(left_thigh)
	var jump_right := skeleton.get_bone_pose_rotation(right_thigh)
	_check(
		jump_left.angle_to(jump_right) > 0.55
			and jump_left.angle_to(Quaternion.IDENTITY) > 0.35
			and jump_right.angle_to(Quaternion.IDENTITY) > 0.20,
		"jump resolves to a visibly asymmetric authored airborne leg silhouette"
	)

	motion_player.play(&"boarding")
	motion_player.seek(1.1, true, true)
	var boarding_left_thigh := skeleton.get_bone_pose_rotation(left_thigh)
	var boarding_right_thigh := skeleton.get_bone_pose_rotation(right_thigh)
	_check(
		boarding_left_thigh.angle_to(Quaternion.IDENTITY) > 1.1
			and boarding_right_thigh.angle_to(Quaternion.IDENTITY) > 1.1,
		"boarding ends by deforming both legs into the compact authored seated pose"
	)

	motion_player.play(&"seated_control")
	motion_player.seek(0.6, true, true)
	var seated_left_thigh := skeleton.get_bone_pose_rotation(left_thigh)
	var seated_left_forearm := skeleton.get_bone_pose_rotation(left_forearm)
	var seated_right_forearm := skeleton.get_bone_pose_rotation(right_forearm)
	_check(
		seated_left_thigh.angle_to(Quaternion.IDENTITY) > 1.1
			and seated_left_forearm.angle_to(Quaternion.IDENTITY) > 0.7
			and seated_right_forearm.angle_to(Quaternion.IDENTITY) > 0.7,
		"seated control keeps knees folded and both skinned hands articulated toward controls"
	)

	player.teleport_to(player.global_transform)
	_check(player.get_authored_motion_state() == &"idle", "direct reset returns controller motion authority to imported idle")
	_check(
		skeleton.get_bone_pose_rotation(left_thigh).angle_to(idle_left_thigh) <= 0.0001
			and skeleton.get_bone_pose_rotation(right_thigh).angle_to(idle_right_thigh) <= 0.0001
			and skeleton.get_bone_pose_rotation(left_forearm).angle_to(idle_left_forearm) <= 0.0001
			and skeleton.get_bone_pose_rotation(right_forearm).angle_to(idle_right_forearm) <= 0.0001,
		"idle frame zero restores sampled skinned limbs to the exact authored idle pose"
	)


func _test_authored_locomotion_state_machine(player: PlayerController, fixture: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "ImportedMotionFloor"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 0.5, 20.0)
	floor_collision.position.y = -0.25
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	fixture.add_child(floor_body)

	player.teleport_to(Transform3D.IDENTITY)
	player.set_control_enabled(true)
	player.set_physics_process(true)
	await _wait_physics_frames(5)
	_check(player.get_authored_motion_state() == &"idle", "grounded state machine begins in imported idle")
	await _test_travel_facing_matrix(player, fixture)

	Input.action_press("move_forward")
	await _wait_physics_frames(12)
	_check(player.get_authored_motion_state() == &"walk", "ordinary grounded input selects the imported walk cycle")
	Input.action_press("sprint_boost")
	await _wait_physics_frames(8)
	_check(player.get_authored_motion_state() == &"run", "sprint input selects the distinct imported run cycle")
	Input.action_release("sprint_boost")
	Input.action_release("move_forward")
	await _wait_physics_frames(14)
	_check(player.get_authored_motion_state() == &"idle", "ground deceleration blends back to imported idle")

	Input.action_press("jump")
	await physics_frame
	await process_frame
	Input.action_release("jump")
	_check(player.get_authored_motion_state() == &"jump", "positive launch velocity selects the imported jump clip")
	var observed_airborne := false
	for _air_frame in 60:
		await physics_frame
		if player.get_authored_motion_state() == &"airborne":
			observed_airborne = true
			break
	_check(observed_airborne, "descent switches from jump to the imported airborne hold")
	await _wait_physics_frames(55)
	_check(player.get_authored_motion_state() == &"idle", "landing returns airborne motion to imported idle")

	player.set_physics_process(false)
	player.teleport_to(Transform3D.IDENTITY)
	floor_body.queue_free()
	await process_frame


func _test_travel_facing_matrix(player: PlayerController, fixture: Node3D) -> void:
	var camera_yaw := player.get_node("CameraRig/CameraYaw") as Node3D
	var presentation := (
		player.get_node("VisualRoot/BodyPivot/PilotSkinnedPresentation")
		as PilotSkinnedPresentation
	)
	var player_id := player.get_instance_id()
	var presentation_id := presentation.get_instance_id()
	var cases: Array[Dictionary] = [
		{"label": "W", "yaw_degrees": 0.0, "input": Vector2(0.0, -1.0), "actions": [&"move_forward"]},
		{"label": "A", "yaw_degrees": 0.0, "input": Vector2(-1.0, 0.0), "actions": [&"move_left"]},
		{"label": "S", "yaw_degrees": 0.0, "input": Vector2(0.0, 1.0), "actions": [&"move_back"]},
		{"label": "D", "yaw_degrees": 0.0, "input": Vector2(1.0, 0.0), "actions": [&"move_right"]},
		{"label": "W+D", "yaw_degrees": 0.0, "input": Vector2(1.0, -1.0), "actions": [&"move_forward", &"move_right"]},
		{"label": "W+A @ 73 degrees", "yaw_degrees": 73.0, "input": Vector2(-1.0, -1.0), "actions": [&"move_forward", &"move_left"]},
		{"label": "S+D @ 73 degrees", "yaw_degrees": 73.0, "input": Vector2(1.0, 1.0), "actions": [&"move_back", &"move_right"]},
		{"label": "W @ -137 degrees", "yaw_degrees": -137.0, "input": Vector2(0.0, -1.0), "actions": [&"move_forward"]},
		{"label": "D @ -137 degrees", "yaw_degrees": -137.0, "input": Vector2(1.0, 0.0), "actions": [&"move_right"]},
	]
	for movement_case in cases:
		player.teleport_to(Transform3D.IDENTITY)
		camera_yaw.rotation.y = deg_to_rad(float(movement_case.get("yaw_degrees", 0.0)))
		await _wait_physics_frames(4)
		var actions := movement_case.get("actions", []) as Array
		for action_value: Variant in actions:
			Input.action_press(StringName(action_value))
		await _wait_physics_frames(30)
		var movement_up := player.up_direction.normalized()
		var horizontal_velocity := player.velocity.slide(movement_up)
		var camera_forward := (-camera_yaw.global_basis.z).slide(movement_up).normalized()
		var camera_right := camera_forward.cross(movement_up).normalized()
		var input_vector := movement_case.get("input", Vector2.ZERO) as Vector2
		var expected_direction := (
			camera_right * input_vector.x + camera_forward * -input_vector.y
		).normalized()
		var visual_forward := (
			player.get_pilot_visual_forward_direction().slide(movement_up).normalized()
		)
		var label := str(movement_case.get("label", "movement"))
		_check(
			horizontal_velocity.length() > 5.0
			and horizontal_velocity.normalized().dot(expected_direction) >= 0.995,
			"%s preserves camera-relative physical movement direction" % label
		)
		_check(
			not visual_forward.is_zero_approx()
			and visual_forward.dot(horizontal_velocity.normalized()) >= 0.995,
			"%s turns the imported pilot's semantic face into actual travel" % label
		)
		for action_value: Variant in actions:
			Input.action_release(StringName(action_value))
		await _wait_physics_frames(16)

	var facing_before_orbit := player.get_pilot_visual_forward_direction().normalized()
	camera_yaw.rotation.y = wrapf(camera_yaw.rotation.y + deg_to_rad(119.0), -PI, PI)
	await _wait_physics_frames(5)
	_check(
		player.get_pilot_visual_forward_direction().normalized().dot(facing_before_orbit) >= 0.999,
		"camera orbit without movement cannot flip the settled visible facing"
	)

	player.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(41.0)), Vector3.ZERO))
	var expected_reentry_forward := -player.global_basis.z.normalized()
	fixture.remove_child(player)
	await process_frame
	fixture.add_child(player)
	await process_frame
	await _wait_physics_frames(3)
	_check(
		player.get_instance_id() == player_id
		and presentation.get_instance_id() == presentation_id
		and player.get_pilot_visual_forward_direction().normalized().dot(expected_reentry_forward) >= 0.999,
		"whole-Player detach/re-entry preserves identity and the compensated canonical face"
	)
	camera_yaw.rotation.y = 0.0
	player.teleport_to(Transform3D.IDENTITY)
	await _wait_physics_frames(4)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in frame_count:
		await physics_frame


func _test_standing_and_seated_lifecycle(player: PlayerController, fixture: Node3D) -> void:
	var standing_layer := player.collision_layer
	var standing_mask := player.collision_mask
	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var body := player.get_node("VisualRoot/BodyPivot") as Node3D
	var presentation := body.get_node("PilotSkinnedPresentation") as PilotSkinnedPresentation
	var skeleton := presentation.get_skeleton()
	var suit := presentation.get_visual_root().find_child("PilotSuit", true, false) as MeshInstance3D
	var seat := Marker3D.new()
	seat.name = "PilotSeatAnchor"
	seat.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(31.0)), Vector3(3.0, 1.2, -2.0))
	fixture.add_child(seat)

	_check(player.begin_boarding(Transform3D.IDENTITY, seat, 0.0), "zero-duration production boarding API accepts the live seat")
	await process_frame
	await physics_frame
	_check(player.is_seated(), "pilot reaches the existing seated lifecycle state")
	_check(player.get_authored_motion_state() == &"seated_control", "zero-duration boarding resolves directly to imported seated control")
	_check(player.global_transform.is_equal_approx(seat.global_transform), "seated CharacterBody follows the exact live seat anchor")
	_check(player.collision_layer == 0 and player.collision_mask == 0 and collision.disabled, "seating disables embodied CharacterBody collision")
	if skeleton != null:
		var left_thigh := skeleton.find_bone("thigh_l")
		var left_forearm := skeleton.find_bone("forearm_l")
		_check(
			skeleton.get_bone_pose_rotation(left_thigh).angle_to(Quaternion.IDENTITY) > 1.1
				and skeleton.get_bone_pose_rotation(left_forearm).angle_to(Quaternion.IDENTITY) > 0.7,
			"live zero-duration seat state immediately samples the compact skinned control pose"
		)
	_check(
		int(player.get_pilot_presentation_audit().get("embodiment_state", -1))
			== PlayerController.EmbodimentState.SEATED,
		"presentation audit follows the live seated state"
	)
	_check(_boarding_events == 1, "boarding completion lifecycle signal remains exactly once")

	var exit_transform := Transform3D(Basis.IDENTITY, Vector3(-2.0, 0.0, 4.0))
	_check(player.begin_disembark(exit_transform, 0.0), "existing disembark API accepts the skinned pilot")
	await process_frame
	await physics_frame
	_check(not player.is_seated() and player.global_transform.is_equal_approx(exit_transform), "disembark restores the same Player root on foot")
	_check(player.get_authored_motion_state() == &"idle", "zero-duration disembark resolves directly to imported idle recovery")
	_check(player.collision_layer == standing_layer and player.collision_mask == standing_mask and not collision.disabled, "disembark restores standing collision authority")
	_check(_disembarking_events == 1, "disembark completion lifecycle signal remains exactly once")

	player.set_control_enabled(true)
	_check(player.is_control_enabled(), "ordinary on-foot control can resume after visual lifecycle")
	_check(player.begin_boarding(exit_transform, seat, 1.0), "animated boarding can begin after reuse")
	_check(player.get_authored_motion_state() == &"boarding", "animated reentry selects the imported boarding clip")
	_check(not player.begin_boarding(exit_transform, seat, 1.0), "boarding cannot re-enter while its imported transition is active")
	var recovery_transform := Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, -3.0))
	player.force_recovery_to_on_foot(recovery_transform)
	await process_frame
	await physics_frame
	_check(not player.is_seated() and player.global_transform.is_equal_approx(recovery_transform), "destructive lifecycle recovery restores one coherent standing pilot")
	_check(player.collision_layer == standing_layer and not collision.disabled, "recovery restores the preserved capsule collision")
	_check(player.get_authored_motion_state() == &"idle", "interrupted boarding atomically resets imported motion to idle")

	_check(player.begin_boarding(recovery_transform, seat, 0.0), "recovered imported state can enter the same live seat again")
	await process_frame
	await physics_frame
	var second_recovery := Transform3D(Basis.IDENTITY, Vector3(9.0, 0.0, -1.5))
	_check(player.begin_disembark(second_recovery, 1.0), "animated disembark can begin after imported reentry")
	_check(player.get_authored_motion_state() == &"disembark_recovery", "animated exit selects the imported disembark recovery clip")
	_check(not player.begin_disembark(second_recovery, 1.0), "disembark cannot re-enter while its imported recovery is active")
	player.force_recovery_to_on_foot(second_recovery)
	await process_frame
	await physics_frame
	_check(player.global_transform.is_equal_approx(second_recovery) and player.get_authored_motion_state() == &"idle", "interrupted disembark restores imported idle at the recovery point")
	_check(player.collision_layer == standing_layer and not collision.disabled, "disembark interruption restores embodied collision")

	var yaw_floor := StaticBody3D.new()
	yaw_floor.name = "SidewaysBoardingFloor"
	var yaw_floor_collision := CollisionShape3D.new()
	var yaw_floor_shape := BoxShape3D.new()
	yaw_floor_shape.size = Vector3(40.0, 0.5, 40.0)
	yaw_floor_collision.position.y = -0.25
	yaw_floor_collision.shape = yaw_floor_shape
	yaw_floor.add_child(yaw_floor_collision)
	fixture.add_child(yaw_floor)
	player.set_control_enabled(true)
	player.set_physics_process(true)
	await _wait_physics_frames(3)
	Input.action_press("move_right")
	await _wait_physics_frames(16)
	_check(
		player.get_authored_motion_state() == &"walk"
			and absf(wrapf(body.rotation.y, -PI, PI)) > deg_to_rad(70.0),
		"real sideways locomotion establishes a deliberately non-canonical visual yaw"
	)
	var animated_start := player.global_transform
	var animated_entry := Transform3D(
		Basis(Vector3.UP, deg_to_rad(-14.0)),
		animated_start.origin.lerp(seat.global_position, 0.45) + Vector3.UP * 0.3
	)
	_check(player.begin_boarding(animated_entry, seat, 0.24), "public animated boarding accepts the sideways locomotion pose")
	Input.action_release("move_right")
	_check(
		player.get_authored_motion_state() == &"boarding"
		and player.get_pilot_visual_forward_direction().dot(-player.global_basis.z) >= 0.999,
		"boarding immediately releases locomotion yaw into canonical seat-facing"
	)
	await _wait_physics_frames(5)
	_check(
		player.global_position.distance_to(animated_start.origin) > 0.1
			and player.global_position.distance_to(seat.global_position) > 0.1,
		"canonical presentation yaw does not replace animated CharacterBody traversal"
	)
	await _wait_physics_frames(20)
	await process_frame
	_check(
		player.is_seated() and player.global_transform.is_equal_approx(seat.global_transform),
		"sideways animated boarding completes at the exact live seat transform"
	)
	_check(
		player.get_pilot_visual_forward_direction().dot(-player.global_basis.z) >= 0.999,
		"seated imported pilot faces the live seat frame after sideways locomotion"
	)

	var animated_exit := Transform3D(
		Basis(Vector3.UP, deg_to_rad(-22.0)),
		Vector3(-4.0, 0.0, 3.0)
	)
	_check(player.begin_disembark(animated_exit, 0.2), "sideways-boarding pilot retains the public animated exit path")
	await _wait_physics_frames(18)
	await process_frame
	_check(
		player.global_transform.is_equal_approx(animated_exit)
			and player.get_authored_motion_state() == &"idle"
			and player.get_pilot_visual_forward_direction().dot(-player.global_basis.z) >= 0.999,
		"animated exit restores canonical on-foot facing and imported idle recovery"
	)
	_check(player.collision_layer == standing_layer and not collision.disabled, "animated exit restores physical standing collision")
	player.set_physics_process(false)
	yaw_floor.queue_free()
	await process_frame

	var stable_player := player.get_motion_animation_player()
	var stable_library := stable_player.get_animation_library(&"")
	var resources_are_stable := stable_library != null
	for clip_name in _motion_resource_ids:
		resources_are_stable = (
			resources_are_stable
				and stable_library.get_animation(clip_name).get_instance_id()
					== int(_motion_resource_ids[clip_name])
		)
	_check(resources_are_stable, "boarding, recovery, and reentry reuse the same imported animation resources")
	_check(
		stable_player.get_instance_id() == _animation_player_id
			and presentation.get_skeleton().get_instance_id() == _skeleton_id
			and suit.get_instance_id() == _suit_id
			and suit.mesh.get_instance_id() == _mesh_resource_id
			and suit.skin.get_instance_id() == _skin_resource_id,
		"full seat lifecycle preserves one AnimationPlayer, Skeleton, PilotSuit, ArrayMesh, and Skin identity"
	)

	stable_player.play(&"idle")
	stable_player.seek(stable_player.get_animation(&"idle").length, true, true)
	stable_player.pause()
	_check(
		not bool(player.get_pilot_motion_audit().get("valid", true)),
		"a stopped looping imported clip fails the Player motion audit even at its end position"
	)
	player.set_physics_process(true)
	await process_frame
	await _wait_physics_frames(2)
	player.set_physics_process(false)
	_check(
		stable_player.is_playing()
		and stable_player.assigned_animation == player.get_authored_motion_state()
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"the next controller physics tick repairs a stopped looping motion driver"
	)
	stable_player.speed_scale = 0.0
	_check(
		not bool(player.get_pilot_motion_audit().get("valid", true)),
		"a zero-speed imported motion driver fails closed while its clip remains assigned"
	)
	player.set_physics_process(true)
	await process_frame
	await _wait_physics_frames(2)
	player.set_physics_process(false)
	_check(
		stable_player.speed_scale > 0.0
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"the next controller physics tick restores the cached positive playback rate"
	)


func _test_motion_authority_intrusion_recovery(
	player: PlayerController,
	presentation: PilotSkinnedPresentation
) -> void:
	var imported := presentation.get_animation_player()
	var skeleton := presentation.get_skeleton()
	var legacy := player.get_node("MotionAnimationPlayer") as AnimationPlayer
	var sibling := AnimationPlayer.new()
	sibling.name = "InjectedPilotAnimationAuthority"
	var injected_library := AnimationLibrary.new()
	var injected_clip := Animation.new()
	injected_clip.length = 1.0
	injected_clip.add_track(Animation.TYPE_VALUE)
	injected_clip.track_set_path(
		0,
		NodePath(
			"VisualRoot/BodyPivot/PilotSkinnedPresentation/PilotMotionImport/"
			+ "PilotArt/PilotRig/PilotSkeleton:pelvis"
		)
	)
	injected_clip.track_insert_key(0, 0.0, Vector3(100.0, 100.0, 100.0))
	injected_library.add_animation(&"intrusion", injected_clip)
	sibling.add_animation_library(&"", injected_library)
	player.add_child(sibling)
	sibling.play(&"intrusion")
	_check(
		not bool(player.get_pilot_motion_audit().get("valid", true)),
		"an injected sibling AnimationPlayer fails the exact Player authority roster"
	)
	player.call("_physics_process", 0.016)
	_check(
		player.get_motion_animation_player() == imported
		and not sibling.is_inside_tree()
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"the next controller tick quarantines a sibling animation authority without abandoning the valid imported driver"
	)
	await process_frame
	var left_thigh := skeleton.find_bone("thigh_l")
	var idle_thigh := skeleton.get_bone_pose_rotation(left_thigh)
	var injected_tree := AnimationTree.new()
	injected_tree.name = "InjectedPilotAnimationTree"
	var injected_tree_root := AnimationNodeAnimation.new()
	injected_tree_root.animation = &"walk"
	injected_tree.tree_root = injected_tree_root
	player.add_child(injected_tree)
	injected_tree.anim_player = NodePath(
		"../VisualRoot/BodyPivot/PilotSkinnedPresentation/PilotMotionImport/"
		+ "PilotAnimationPlayer"
	)
	injected_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	injected_tree.active = true
	injected_tree.advance(0.2)
	var tree_poisoned_thigh := skeleton.get_bone_pose_rotation(left_thigh)
	_check(
		tree_poisoned_thigh.angle_to(idle_thigh) > 0.2
		and not bool(player.get_pilot_motion_audit().get("valid", true)),
		"an injected AnimationTree deforms the rig but fails the exact mixer roster"
	)
	_check(
		player.validate_pilot_motion_authority()
		and not injected_tree.is_inside_tree()
		and not injected_tree.active
		and skeleton.get_bone_pose_rotation(left_thigh).angle_to(tree_poisoned_thigh) > 0.2
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"the public fence quarantines a foreign mixer and immediately restores the cached imported pose"
	)
	await process_frame

	var legacy_library := legacy.get_animation_library(&"")
	var injected_legacy := Animation.new()
	injected_legacy.length = 1.0
	injected_legacy.add_track(Animation.TYPE_VALUE)
	injected_legacy.track_set_path(0, NodePath("VisualRoot/BodyPivot:rotation:x"))
	injected_legacy.track_insert_key(0, 0.0, 1.2)
	legacy_library.add_animation(&"injected_legacy", injected_legacy)
	legacy.active = true
	legacy.play(&"injected_legacy")
	_check(
		not bool(player.get_pilot_motion_audit().get("valid", true)),
		"an injected legacy-pivot clip fails the immutable recovery-library contract"
	)
	legacy.stop()
	legacy.active = false
	legacy_library.remove_animation(&"injected_legacy")
	player.call("_physics_process", 0.016)
	_check(
		player.get_motion_animation_player() == imported
		and not legacy.active
		and not legacy.is_playing(),
		"the imported authority immediately makes a contaminated inactive legacy driver inert"
	)
	_check(
		player.validate_pilot_motion_authority()
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"restoring the trusted legacy library returns the complete Player motion audit to green"
	)
	legacy.root_node = NodePath(".")
	legacy.root_motion_track = NodePath("VisualRoot:position")
	legacy.root_motion_local = not legacy.root_motion_local
	legacy.deterministic = false
	legacy.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	legacy.process_mode = Node.PROCESS_MODE_ALWAYS
	_check(
		not bool(player.get_pilot_motion_audit().get("valid", true)),
		"legacy recovery sampling and root authority drift fail the Player motion audit"
	)
	player.call("_physics_process", 0.016)
	_check(
		player.get_motion_animation_player() == imported
		and legacy.root_node == NodePath("..")
		and legacy.root_motion_track.is_empty()
		and not legacy.root_motion_local
		and not legacy.deterministic
		and legacy.callback_mode_process
			== AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		and legacy.process_mode == Node.PROCESS_MODE_INHERIT
		and not legacy.active,
		"the imported authority restores the exact inactive legacy AnimationPlayer sampling contract"
	)
	var injected_script := GDScript.new()
	injected_script.source_code = (
		"extends AnimationPlayer\n"
		+ "func _process(_delta: float) -> void:\n"
		+ "\tvar skeleton := get_node_or_null('../VisualRoot/BodyPivot/"
		+ "PilotSkinnedPresentation/PilotMotionImport/PilotArt/PilotRig/"
		+ "PilotSkeleton')\n"
		+ "\tif skeleton != null:\n"
		+ "\t\tvar index: int = int(skeleton.call('find_bone', 'pelvis'))\n"
		+ "\t\tif index >= 0:\n"
		+ "\t\t\tskeleton.set_bone_pose_rotation(index, Quaternion(Vector3.FORWARD, 1.234))\n"
	)
	_check(injected_script.reload() == OK, "legacy authority injection fixture compiles")
	var pelvis := skeleton.find_bone("pelvis")
	var clean_pelvis_rotation := skeleton.get_bone_pose_rotation(pelvis)
	legacy.set_script(injected_script)
	legacy.process_mode = Node.PROCESS_MODE_ALWAYS
	legacy.call("_process", 0.0)
	_check(
		skeleton.get_bone_pose_rotation(pelvis).angle_to(clean_pelvis_rotation) > 1.0
		and not bool(player.get_pilot_motion_audit().get("valid", true)),
		"a scripted inactive legacy AnimationPlayer visibly poisons the pelvis and fails the exact node contract"
	)
	_check(
		player.validate_pilot_motion_authority()
		and legacy.get_script() == null
		and legacy.process_mode == Node.PROCESS_MODE_INHERIT
		and player.get_motion_animation_player() == imported
		and skeleton.get_bone_pose_rotation(pelvis).angle_to(clean_pelvis_rotation) <= 0.0001
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"the public fence strips executable legacy contamination and restores the pose before returning green"
	)
	var stable_legacy_library := legacy.get_animation_library(&"")
	var stable_legacy_idle := stable_legacy_library.get_animation(&"idle")
	var stable_update_mode := stable_legacy_idle.value_track_get_update_mode(0)
	stable_legacy_idle.value_track_set_update_mode(
		0,
		Animation.UPDATE_DISCRETE
		if stable_update_mode != Animation.UPDATE_DISCRETE else Animation.UPDATE_CONTINUOUS
	)
	_check(
		not bool(player.get_pilot_motion_audit().get("legacy_library_trusted", true))
		and player.validate_pilot_motion_authority()
		and legacy.get_animation(&"idle").value_track_get_update_mode(0) == stable_update_mode,
		"legacy recovery trust pins behaviorally relevant update modes and restores drift"
	)
	imported.speed_scale = 0.0
	var zero_rate_repaired := player.validate_pilot_motion_authority()
	imported.play(&"walk")
	imported.seek(0.2, true, true)
	var wrong_clip_repaired := player.validate_pilot_motion_authority()
	imported.pause()
	var paused_loop_repaired := player.validate_pilot_motion_authority()
	_check(
		zero_rate_repaired
		and wrong_clip_repaired
		and paused_loop_repaired
		and imported.speed_scale > 0.0
		and imported.assigned_animation == player.get_authored_motion_state()
		and imported.is_playing()
		and bool(player.get_pilot_motion_audit().get("valid", false)),
		"the public fence synchronously repairs zero rate, wrong clips, and stopped loops"
	)
	var legacy_backpack := player.get_node("VisualRoot/BodyPivot/Backpack") as MeshInstance3D
	legacy_backpack.visible = true
	_check(
		player.validate_pilot_motion_authority()
		and not legacy_backpack.visible
		and player.get_motion_animation_player() == imported,
		"the imported authority fence hides an exposed fallback mesh without double-render"
	)


func _test_periodic_integrity_fallback(fixture: Node3D) -> void:
	var periodic_player := PLAYER_SCENE.instantiate() as PlayerController
	fixture.add_child(periodic_player)
	periodic_player.set_physics_process(false)
	periodic_player.set_process(false)
	var body := periodic_player.get_node("VisualRoot/BodyPivot") as Node3D
	var presentation := body.get_node("PilotSkinnedPresentation") as PilotSkinnedPresentation
	var imported := presentation.get_animation_player()
	var suit := presentation.get_visual_root().find_child(
		"PilotSuit", true, false
	) as MeshInstance3D
	var material := suit.get_active_material(0) as StandardMaterial3D
	material.albedo_color.a = 0.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for _step in 13:
		periodic_player.call("_physics_process", 0.016)
	var visible_generated := 0
	var hidden_blockout := 0
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if bool(mesh.get_meta(&"pilot_generated", false)) and mesh.visible:
			visible_generated += 1
		elif not bool(mesh.get_meta(&"pilot_generated", false)) and not mesh.visible:
			hidden_blockout += 1
	_check(
		periodic_player.get_motion_animation_player()
			== periodic_player.get_node("MotionAnimationPlayer")
		and not imported.active
		and presentation.get_parent() == null
		and bool(periodic_player.get_pilot_motion_audit().get("fallback_active", false))
		and visible_generated > 0
		and hidden_blockout == LEGACY_FALLBACK_MESH_COUNT,
		"the bounded automatic integrity probe terminally rejects mutated imported content and exposes only the generated fallback"
	)
	_check(
		absf(wrapf(body.rotation.y, -PI, PI)) <= 0.001,
		"legacy fallback removes the imported PI mount compensation"
	)
	periodic_player.queue_free()
	await process_frame


func _test_destructive_motion_fallback(fixture: Node3D) -> void:
	var fallback_player := PLAYER_SCENE.instantiate() as PlayerController
	fixture.add_child(fallback_player)
	fallback_player.set_physics_process(false)
	fallback_player.set_process(false)
	var body := fallback_player.get_node("VisualRoot/BodyPivot") as Node3D
	var presentation := body.get_node("PilotSkinnedPresentation") as PilotSkinnedPresentation
	var imported := presentation.get_animation_player()
	var legacy := fallback_player.get_node("MotionAnimationPlayer") as AnimationPlayer
	var injected_camera := Camera3D.new()
	injected_camera.name = "InjectedPilotCamera"
	presentation.add_child(injected_camera)
	injected_camera.current = true
	var injected_area := Area3D.new()
	injected_area.name = "InjectedPilotArea"
	injected_area.collision_layer = 16
	injected_area.collision_mask = 16
	injected_area.monitoring = true
	injected_area.monitorable = true
	var injected_shape := CollisionShape3D.new()
	injected_shape.shape = SphereShape3D.new()
	injected_area.add_child(injected_shape)
	presentation.add_child(injected_area)
	presentation.get_visual_root().position.x = 0.25
	_check(
		not bool(fallback_player.get_pilot_presentation_audit().get("valid", true)),
		"post-ready imported hierarchy corruption is detected before fallback selection"
	)
	_check(
		fallback_player.validate_pilot_motion_authority(),
		"the public integrity fence selects a safe fallback after destructive imported corruption"
	)
	var imported_visible := 0
	var fallback_visible := 0
	var fallback_generated_total := 0
	var fallback_blockout_visible := 0
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if bool(mesh.get_meta(&"pilot_generated", false)):
			fallback_generated_total += 1
		elif mesh.visible:
			fallback_blockout_visible += 1
		if not mesh.is_visible_in_tree():
			continue
		if presentation.is_ancestor_of(mesh):
			imported_visible += 1
		else:
			fallback_visible += 1
	_check(
		fallback_player.get_motion_animation_player() == legacy
		and legacy.active
		and not imported.active
		and imported_visible == 0
		and fallback_visible == fallback_generated_total
		and fallback_generated_total > 0
		and fallback_blockout_visible == 0
		and not injected_camera.current
		and injected_camera.process_mode == Node.PROCESS_MODE_DISABLED
		and not injected_area.monitoring
		and not injected_area.monitorable
		and injected_area.collision_layer == 0
		and injected_area.collision_mask == 0
		and injected_shape.disabled,
		"fallback selection is exclusive: rejected skinned art is hidden and only the refined recovery suit remains visible"
	)
	fallback_player.call("_activate_skinned_pilot_presentation")
	var repeated_imported_visible := 0
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if presentation.is_ancestor_of(mesh) and mesh.is_visible_in_tree():
			repeated_imported_visible += 1
	_check(
		fallback_player.get_motion_animation_player() == legacy
		and repeated_imported_visible == 0,
		"repeated rejected activation is idempotent and cannot double-render imported and fallback pilots"
	)
	var replacement := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	replacement.name = "PilotSkinnedPresentation"
	body.add_child(replacement)
	await process_frame
	var replacement_imported := replacement.get_animation_player()
	fallback_player.set("_pilot_presentation", replacement)
	fallback_player.call("_activate_skinned_pilot_presentation")
	_check(
		fallback_player.get_motion_animation_player() == legacy
		and not replacement_imported.active
		and replacement.get_parent() == null
		and bool(fallback_player.get_pilot_motion_audit().get(
			"imported_presentation_rejected", false
		)),
		"immutable-contract rejection is terminal and cannot reaccept a replacement wrapper"
	)

	var seat := Marker3D.new()
	fixture.add_child(seat)
	fallback_player.begin_boarding(Transform3D.IDENTITY, seat, 0.0)
	legacy.play(&"walk")
	legacy.seek(0.2, true, true)
	legacy.pause()
	fallback_player.call("_physics_process", 0.016)
	_check(
		legacy.assigned_animation == &"seated_control" and legacy.is_playing(),
		"fallback mode repairs a paused wrong clip to the current seated lifecycle state"
	)

	fallback_player.call("_physics_process", 0.016)
	_check(
		fallback_player.get_motion_animation_player() == legacy
		and legacy.active
		and fallback_player.get_pilot_visual_root() == null,
		"queued disposal of rejected wrappers preserves the live fallback driver"
	)
	legacy.free()
	_check(
		not fallback_player.validate_pilot_motion_authority()
		and fallback_player.get_motion_animation_player() == null,
		"freeing the final legacy recovery driver fails closed without invalid-instance access"
	)
	seat.queue_free()
	fallback_player.queue_free()
	await process_frame

	var freed_mount_player := PLAYER_SCENE.instantiate() as PlayerController
	fixture.add_child(freed_mount_player)
	freed_mount_player.set_physics_process(false)
	freed_mount_player.set_process(false)
	await process_frame
	var freed_body := freed_mount_player.get_node("VisualRoot/BodyPivot") as Node3D
	freed_body.free()
	_check(
		not freed_mount_player.validate_pilot_motion_authority()
		and freed_mount_player.get_motion_animation_player() == null
		and freed_mount_player.get_pilot_visual_root() == null,
		"freeing the BodyPivot mount fails closed without invalid-instance access"
	)
	freed_mount_player.queue_free()
	await process_frame


func _test_preready_legacy_poison_fails_closed(fixture: Node3D) -> void:
	var source_instance := PLAYER_SCENE.instantiate() as PlayerController
	var source_player := source_instance.get_node("MotionAnimationPlayer") as AnimationPlayer
	var source_idle := source_player.get_animation(&"idle")
	var original_path := source_idle.track_get_path(0)
	var original_values := []
	for key_index in source_idle.track_get_key_count(0):
		original_values.append(source_idle.track_get_key_value(0, key_index))
	source_idle.track_set_path(0, NodePath(".:position:x"))
	for key_index in source_idle.track_get_key_count(0):
		source_idle.track_set_key_value(0, key_index, 100.0)
	source_instance.free()

	var victim := PLAYER_SCENE.instantiate() as PlayerController
	var before := victim.position
	fixture.add_child(victim)
	victim.set_physics_process(false)
	victim.set_process(false)
	await process_frame
	_check(
		victim.position.is_equal_approx(before)
		and victim.get_motion_animation_player() == null
		and not victim.validate_pilot_motion_authority()
		and victim.position.is_equal_approx(before),
		"pre-ready shared legacy-library poisoning is rejected before it can move the Player root"
	)
	source_idle.track_set_path(0, original_path)
	for key_index in source_idle.track_get_key_count(0):
		source_idle.track_set_key_value(0, key_index, original_values[key_index])
	victim.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PILOT_VISUAL_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("PILOT_VISUAL_TEST_FAILED: %s" % ", ".join(_failures))
		quit(1)
