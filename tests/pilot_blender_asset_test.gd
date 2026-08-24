extends SceneTree

const PRESENTATION_SCENE := preload("res://scenes/player/pilot_skinned_presentation.tscn")
const MANIFEST_PATH := "res://assets/models/pilot/pilot_motion_v2_asset_manifest.json"
const GENERATOR_PATH := "res://tools/blender/generate_pilot_motion_v2.py"
const GLB_PATH := "res://assets/models/pilot/pilot_motion_v2.glb"
const BLEND_PATH := "res://art_source/pilot/pilot_motion_v2.blend"

const EXPECTED_PARENTS := {
	&"root": &"", &"pelvis": &"root", &"spine_01": &"pelvis",
	&"spine_02": &"spine_01", &"chest": &"spine_02", &"neck": &"chest",
	&"head": &"neck", &"clavicle_l": &"chest", &"upper_arm_l": &"clavicle_l",
	&"forearm_l": &"upper_arm_l", &"hand_l": &"forearm_l",
	&"clavicle_r": &"chest", &"upper_arm_r": &"clavicle_r",
	&"forearm_r": &"upper_arm_r", &"hand_r": &"forearm_r",
	&"thigh_l": &"pelvis", &"calf_l": &"thigh_l", &"foot_l": &"calf_l",
	&"toe_l": &"foot_l", &"thigh_r": &"pelvis", &"calf_r": &"thigh_r",
	&"foot_r": &"calf_r", &"toe_r": &"foot_r",
}
const EXPECTED_DURATIONS := {
	&"RESET": .001, &"idle": 2.4, &"walk": .8, &"run": .56,
	&"jump": .42, &"airborne": .9, &"boarding": 1.1,
	&"seated_control": 2.4, &"disembark_recovery": .9,
}
const LOOPING := [&"idle", &"walk", &"run", &"airborne", &"seated_control"]
## Re-frozen when the procedural placeholder pose tables were replaced with
## authored motion. Every animation curve changed and the per-clip imported
## track count went 17 -> 23; the mesh, rig, bind bounds, bone tree, skin,
## materials, clip roster and clip durations did not.
## The rigid harness-light split changes the source graph without changing the
## armature or the nine authored clips.
const SOURCE_CONTENT_SIGNATURE := "5f89c5b26fad25fe9c59e47f1838bcaa536bee27a510401a5c87e8bc8d0e4ceb"

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_child_count := root.get_child_count()
	var presentation := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	_check(presentation != null, "skinned pilot wrapper instantiates with its public class")
	if presentation == null:
		_finish()
		return
	root.add_child(presentation)
	await process_frame

	_test_runtime_boundary(presentation)
	_test_cross_platform_source_signature(presentation)
	_test_exact_rig_and_skin(presentation)
	_test_imported_motion_library(presentation)
	_test_authored_deformation(presentation)
	await _test_integrity_fail_closed(presentation)
	_test_manifest()

	presentation.queue_free()
	await process_frame
	await process_frame
	_check(root.get_child_count() == original_child_count, "pilot presentation cleans up without orphan runtime nodes")
	_finish()


func _test_runtime_boundary(presentation: PilotSkinnedPresentation) -> void:
	var audit := presentation.get_asset_audit_report()
	_check(bool(audit.get("valid", false)), "Blender pilot passes its complete runtime audit")
	if not bool(audit.get("valid", false)):
		print("PILOT_AUDIT_ERRORS: ", audit.get("errors", []))
	_check(int(audit.get("schema_version", 0)) == 2, "runtime audit preserves schema v2")
	_check(bool(audit.get("integrity_contract_captured", false)), "runtime captured its exact immutable pilot contract")
	_check(audit.get("version") == &"blender_skinned_v2", "runtime identifies the skinned v2 presentation")
	_check(audit.get("authorship") == &"original_script_assisted_blender", "asset reports honest original Blender authorship")
	_check(not bool(audit.get("motion_capture", true)), "asset makes no motion-capture claim")
	_check(not bool(audit.get("runtime_clip_generation", true)), "runtime does not synthesize replacement animation clips")
	_check(not bool(audit.get("gameplay_authority", true)), "imported subtree explicitly owns no gameplay authority")
	_check(int(audit.get("forbidden_authority_node_count", -1)) == 0, "import contains no collision, camera, interaction, audio, or navigation authority")
	_check(bool(audit.get("identity_transform", false)), "wrapper publishes an identity mounting transform")
	_check(str(audit.get("asset_path", "")) == GLB_PATH, "audit identifies the exact runtime GLB")
	_check(str(audit.get("source_path", "")) == BLEND_PATH, "audit identifies the editable Blender source")
	_check(str(audit.get("source_asset_path", "")) == GLB_PATH, "audit pins the untouched source asset before runtime normalization")
	_check(str(audit.get("source_content_signature", "")) == SOURCE_CONTENT_SIGNATURE, "audit pins the complete pre-normalization GLB resource graph")
	_check(bool(audit.get("resource_cache_isolated", false)), "wrapper publishes deep ResourceLoader cache isolation")
	_check(
		str(audit.get("source_mesh_resource_path", "")).begins_with(GLB_PATH + "::")
		and str(audit.get("source_skin_resource_path", "")).begins_with(GLB_PATH + "::"),
		"audit preserves exact direct-GLB Mesh and Skin provenance"
	)
	var source_material_paths := audit.get("source_material_resource_paths", PackedStringArray()) as PackedStringArray
	var all_material_paths_are_direct := source_material_paths.size() == 8
	for path in source_material_paths:
		all_material_paths_are_direct = (
			all_material_paths_are_direct and path.begins_with(GLB_PATH + "::")
		)
	_check(
		all_material_paths_are_direct,
		"audit preserves direct-GLB provenance for all eight materials"
	)
	var source_animation_paths := audit.get("source_animation_resource_paths", {}) as Dictionary
	var all_animation_paths_are_direct := source_animation_paths.size() == EXPECTED_DURATIONS.size()
	for path in source_animation_paths.values():
		all_animation_paths_are_direct = (
			all_animation_paths_are_direct
			and str(path).begins_with(GLB_PATH + "::")
		)
	_check(
		all_animation_paths_are_direct,
		"audit preserves direct-GLB provenance for all nine authored clips"
	)
	_check(absf(float(audit.get("root_motion_horizontal_m", 1.0))) <= .0001, "all imported motion remains horizontally in place")
	_check(absf(float(audit.get("root_motion_yaw_rad", 1.0))) <= .0001, "all imported motion leaves player yaw to gameplay authority")
	_check(
		audit.get("imported_visual_forward_axis", Vector3.ZERO) == Vector3.BACK
		and audit.get("player_canonical_forward_axis", Vector3.ZERO) == Vector3.FORWARD,
		"audit distinguishes the raw +Z semantic face from Player's compensated -Z forward"
	)
	var bounds := audit.get("bind_bounds") as AABB
	_check(bounds.size.y >= 1.90 and bounds.size.y <= 1.96, "bind silhouette remains a practical roughly 1.95 metre pilot")
	_check(absf(bounds.position.y) <= .002, "flat boot soles meet the Godot Y=0 ground plane")
	_check(bounds.size.x < 1.16 and bounds.size.z < .56, "standing suit keeps a restrained human cockpit envelope")


func _test_cross_platform_source_signature(
	presentation: PilotSkinnedPresentation
) -> void:
	var decoder_a: Array = []
	decoder_a.resize(Mesh.ARRAY_MAX)
	decoder_a[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(1.0, 2.0, 3.0)])
	decoder_a[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3(0.1234562, -0.7654322, 0.0000002),
	])
	decoder_a[Mesh.ARRAY_TANGENT] = PackedFloat32Array([
		0.1234562, -0.7654322, 0.0000002, 1.0,
	])
	var decoder_b := decoder_a.duplicate(true)
	decoder_b[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3(0.1234564, -0.7654324, -0.0000002),
	])
	decoder_b[Mesh.ARRAY_TANGENT] = PackedFloat32Array([
		0.1234564, -0.7654324, -0.0000002, 1.0,
	])
	var canonical_a: Array = presentation.call(
		"_canonical_source_surface_arrays", decoder_a
	)
	var canonical_b: Array = presentation.call(
		"_canonical_source_surface_arrays", decoder_b
	)
	_check(
		canonical_a == canonical_b,
		"source signature canonicalizes only sub-micro platform normal/tangent variance"
	)

	var meaningful_direction_drift := decoder_a.duplicate(true)
	meaningful_direction_drift[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3(0.1234562, -0.7654322, 0.0000022),
	])
	_check(
		canonical_a != presentation.call(
			"_canonical_source_surface_arrays", meaningful_direction_drift
		),
		"source signature preserves near-zero derived-direction drift above one micro-unit"
	)

	var geometry_drift := decoder_a.duplicate(true)
	geometry_drift[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(1.001, 2.0, 3.0),
	])
	_check(
		canonical_a != presentation.call(
			"_canonical_source_surface_arrays", geometry_drift
		),
		"source signature keeps authored geometry exact"
	)


func _test_exact_rig_and_skin(presentation: PilotSkinnedPresentation) -> void:
	var visual_root := presentation.get_visual_root()
	var skeleton := presentation.get_skeleton()
	_check(visual_root != null and visual_root.name == &"PilotArt", "wrapper exposes the stable PilotArt root")
	_check(visual_root != null and visual_root.get_node_or_null("PilotRig") != null, "PilotArt owns the stable PilotRig hierarchy")
	_check(skeleton != null and skeleton.name == &"PilotSkeleton", "wrapper exposes the normalized PilotSkeleton root")
	if skeleton == null:
		return
	_check(skeleton.get_parent().name == &"PilotRig", "PilotSkeleton is a direct child of PilotRig")
	_check(skeleton.get_bone_count() == EXPECTED_PARENTS.size(), "armature contains exactly the 23 required deformation bones")
	for bone_name: StringName in EXPECTED_PARENTS:
		var bone_index := skeleton.find_bone(String(bone_name))
		_check(bone_index >= 0, "%s bone is present" % bone_name)
		if bone_index < 0:
			continue
		var parent_index := skeleton.get_bone_parent(bone_index)
		var parent_name: StringName = skeleton.get_bone_name(parent_index) if parent_index >= 0 else &""
		_check(parent_name == EXPECTED_PARENTS[bone_name], "%s has the exact authored parent" % bone_name)

	var meshes := visual_root.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 2, "source exports one skinned suit plus one rigid harness light")
	var suit := visual_root.find_child("PilotSuit", true, false) as MeshInstance3D
	var harness_release := visual_root.find_child("HarnessRelease", true, false) as MeshInstance3D
	if suit == null or harness_release == null:
		return
	_check(suit.name == &"PilotSuit", "joined mesh retains its semantic PilotSuit name")
	_check(suit.mesh is ArrayMesh, "runtime suit is imported authored geometry rather than a PrimitiveMesh proxy")
	_check(suit.skin != null and suit.skin.get_bind_count() == 23, "PilotSuit is genuinely skinned to every required bone")
	_check(suit.get_node_or_null(suit.skeleton) == skeleton, "PilotSuit resolves its live PilotSkeleton deformation target")
	_check(suit.mesh.get_surface_count() == 7, "skinned suit excludes the rigid amber status-light surface")
	_check(
		harness_release.get_parent() is BoneAttachment3D
		and (harness_release.get_parent() as BoneAttachment3D).bone_name == &"spine_02"
		and harness_release.skin == null
		and harness_release.skeleton.is_empty()
		and harness_release.mesh != null
		and harness_release.mesh.get_surface_count() == 1,
		"HarnessRelease is one unskinned rigid mesh attached to spine_02"
	)
	var harness_arrays := harness_release.mesh.surface_get_arrays(0)
	var harness_bones: Variant = harness_arrays[Mesh.ARRAY_BONES]
	var harness_weights: Variant = harness_arrays[Mesh.ARRAY_WEIGHTS]
	_check(
		(harness_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 216
		and (harness_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == 324
		and (harness_bones == null or (harness_bones is PackedInt32Array and harness_bones.is_empty()))
		and (harness_weights == null or (harness_weights is PackedFloat32Array and harness_weights.is_empty())),
		"HarnessRelease render submission contains no skeletal vertex channels"
	)
	var role_names := PackedStringArray()
	for surface_index in suit.mesh.get_surface_count():
		var role := suit.get_active_material(surface_index)
		if role != null:
			role_names.append(role.resource_name)
	var harness_role := harness_release.get_active_material(0)
	if harness_role != null:
		role_names.append(harness_role.resource_name)
	for required_role in [
		"PressureTextile", "CeramicArmor", "GraphiteArmor", "JointRubber",
		"HarnessWebbing", "VisorGlazing", "CyanStatusLight", "AmberStatusLight",
	]:
		_check(role_names.has(required_role), "%s material role survives the GLB boundary" % required_role)
	var visor_bounds := _surface_bounds_for_role(suit.mesh, &"VisorGlazing")
	var face_light_bounds := _surface_bounds_for_role(suit.mesh, &"CyanStatusLight")
	_check(
		visor_bounds.has_volume() and visor_bounds.position.z >= 0.16
		and face_light_bounds.has_volume() and face_light_bounds.position.z >= 0.21,
		"raw GLB visor and face status light prove semantic imported forward is +Z"
	)


func _test_imported_motion_library(presentation: PilotSkinnedPresentation) -> void:
	var player := presentation.get_animation_player()
	_check(player != null and player.name == &"PilotAnimationPlayer", "wrapper exposes one stable imported PilotAnimationPlayer")
	if player == null:
		return
	_check(
		player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"imported deformation is advanced deterministically by controller physics"
	)
	_check(player.get_animation_library_list() == [&""], "nine clips live in one unqualified default AnimationLibrary")
	_check(player.get_animation_list().size() == EXPECTED_DURATIONS.size(), "import exposes exactly the required nine motion clips")
	var imported_tracks := 0
	for clip_name: StringName in EXPECTED_DURATIONS:
		_check(player.has_animation(clip_name), "%s is callable by its unqualified controller-facing name" % clip_name)
		if not player.has_animation(clip_name):
			continue
		var clip := player.get_animation(clip_name)
		_check(absf(clip.length - float(EXPECTED_DURATIONS[clip_name])) <= .002, "%s retains its exact authored duration" % clip_name)
		_check((clip.loop_mode != Animation.LOOP_NONE) == LOOPING.has(clip_name), "%s retains its authored loop/one-shot contract" % clip_name)
		_check(clip.get_track_count() > 0, "%s contains persistent deformation data" % clip_name)
		var all_imported := true
		for track_index in clip.get_track_count():
			all_imported = all_imported and clip.track_is_imported(track_index)
			if clip.track_is_imported(track_index):
				imported_tracks += 1
		_check(all_imported, "%s tracks remain imported Blender source data" % clip_name)
	_check(imported_tracks >= 120, "complete library carries substantial authored multi-bone track coverage")
	_check(int(presentation.get_asset_audit_report().get("imported_track_count", 0)) == imported_tracks, "runtime audit independently counts every imported track")


func _test_authored_deformation(presentation: PilotSkinnedPresentation) -> void:
	var player := presentation.get_animation_player()
	var skeleton := presentation.get_skeleton()
	if player == null or skeleton == null:
		return
	var left_thigh := skeleton.find_bone("thigh_l")
	var right_thigh := skeleton.find_bone("thigh_r")
	var left_forearm := skeleton.find_bone("forearm_l")
	var root_bone := skeleton.find_bone("root")

	player.play(&"walk")
	player.seek(0.0, true, true)
	var walk_left_a := skeleton.get_bone_pose_rotation(left_thigh)
	var walk_right_a := skeleton.get_bone_pose_rotation(right_thigh)
	var root_a := skeleton.get_bone_pose(root_bone)
	player.seek(.4, true, true)
	var walk_left_b := skeleton.get_bone_pose_rotation(left_thigh)
	var walk_right_b := skeleton.get_bone_pose_rotation(right_thigh)
	var root_b := skeleton.get_bone_pose(root_bone)
	_check(walk_left_a.angle_to(walk_left_b) > .7, "walk deforms the left skinned leg through alternating contacts")
	_check(walk_right_a.angle_to(walk_right_b) > .7, "walk deforms the right skinned leg through alternating contacts")
	_check(root_a.is_equal_approx(root_b), "walk deformation never displaces or yaws the root bone")

	player.play(&"run")
	player.seek(0.0, true, true)
	var run_stride_a := skeleton.get_bone_pose_rotation(left_thigh)
	player.seek(.28, true, true)
	var run_stride_b := skeleton.get_bone_pose_rotation(left_thigh)
	_check(
		run_stride_a.angle_to(run_stride_b) > walk_left_a.angle_to(walk_left_b) + .25,
		"run authors a distinct longer skinned stride"
	)
	player.play(&"seated_control")
	player.seek(.6, true, true)
	var seated_forearm := skeleton.get_bone_pose_rotation(left_forearm)
	_check(seated_forearm.angle_to(Quaternion.IDENTITY) > .7, "seated control visibly articulates the skinned hands toward controls")
	player.play(&"boarding")
	player.seek(1.1, true, true)
	_check(skeleton.get_bone_pose_rotation(left_thigh).angle_to(Quaternion.IDENTITY) > 1.1, "boarding ends in a compact authored seated thigh pose")
	_check(skeleton.get_bone_pose_rotation(right_thigh).angle_to(Quaternion.IDENTITY) > 1.1, "boarding deforms both legs rather than moving a rigid avatar")
	player.stop()


func _test_integrity_fail_closed(presentation: PilotSkinnedPresentation) -> void:
	_check(
		bool(presentation.get_asset_audit_report().get("valid", false)),
		"ordinary live bone-pose sampling remains valid under the immutable contract"
	)
	var import_root := presentation.get_node("PilotMotionImport") as Node3D
	var visual_root := presentation.get_visual_root()
	var rig_root := visual_root.get_node("PilotRig") as Node3D
	var skeleton := presentation.get_skeleton()
	var suit := visual_root.find_child("PilotSuit", true, false) as MeshInstance3D
	var animation_player := presentation.get_animation_player()
	var library := animation_player.get_animation_library(&"")

	presentation.top_level = true
	_expect_integrity_rejection(presentation, "wrapper top-level drift fails closed")
	presentation.top_level = false
	presentation.visible = false
	_expect_integrity_rejection(presentation, "hidden wrapper fails closed")
	presentation.visible = true

	var import_transform := import_root.transform
	import_root.position += Vector3(100.0, 0.0, 0.0)
	_expect_integrity_rejection(presentation, "translated GLB import container fails closed")
	import_root.transform = import_transform
	var visual_transform := visual_root.transform
	visual_root.top_level = true
	_expect_integrity_rejection(presentation, "top-level PilotArt fails closed")
	visual_root.top_level = false
	visual_root.visible = false
	_expect_integrity_rejection(presentation, "hidden PilotArt fails closed")
	visual_root.visible = true
	var original_visual_visibility_parent := visual_root.visibility_parent
	var visibility_dependency := MeshInstance3D.new()
	visibility_dependency.name = "IntegrityVisibilityDependency"
	presentation.add_child(visibility_dependency)
	visual_root.visibility_parent = visual_root.get_path_to(visibility_dependency)
	_expect_integrity_rejection(presentation, "external PilotArt visibility-parent dependency fails closed")
	visual_root.visibility_parent = original_visual_visibility_parent
	presentation.remove_child(visibility_dependency)
	visibility_dependency.free()

	visual_root.reparent(presentation, false)
	_expect_integrity_rejection(presentation, "detached PilotArt hierarchy fails closed")
	visual_root.reparent(import_root, false)
	visual_root.transform = visual_transform
	skeleton.reparent(visual_root, false)
	_expect_integrity_rejection(presentation, "reparented PilotSkeleton fails closed")
	skeleton.reparent(rig_root, false)

	var suit_transform := suit.transform
	suit.position += Vector3(100.0, 0.0, 0.0)
	_expect_integrity_rejection(presentation, "translated PilotSuit fails closed")
	suit.transform = suit_transform
	suit.visible = false
	_expect_integrity_rejection(presentation, "hidden PilotSuit fails closed")
	suit.visible = true
	var original_skeleton_path := suit.skeleton
	suit.skeleton = NodePath()
	_expect_integrity_rejection(presentation, "detached Skin deformation target fails closed")
	suit.skeleton = original_skeleton_path
	var original_transparency := suit.transparency
	suit.transparency = 1.0
	_expect_integrity_rejection(presentation, "fully transparent PilotSuit render state fails closed")
	suit.transparency = original_transparency
	var original_visibility_end := suit.visibility_range_end
	suit.visibility_range_end = 0.01
	_expect_integrity_rejection(presentation, "restrictive PilotSuit visibility range fails closed")
	suit.visibility_range_end = original_visibility_end

	var original_mesh := suit.mesh
	suit.mesh = original_mesh.duplicate()
	_expect_integrity_rejection(presentation, "substituted ArrayMesh resource fails closed")
	suit.mesh = original_mesh
	var original_mesh_custom_aabb: AABB = original_mesh.custom_aabb
	original_mesh.custom_aabb = AABB(
		Vector3(1_000_000.0, 0.0, 1_000_000.0),
		Vector3(0.1, 1.9, 0.1)
	)
	_expect_integrity_rejection(presentation, "ArrayMesh culling-AABB drift fails closed")
	original_mesh.custom_aabb = original_mesh_custom_aabb
	var original_shadow_mesh: ArrayMesh = original_mesh.shadow_mesh
	var injected_shadow_mesh := ArrayMesh.new()
	injected_shadow_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		BoxMesh.new().get_mesh_arrays()
	)
	original_mesh.shadow_mesh = injected_shadow_mesh
	_expect_integrity_rejection(presentation, "ArrayMesh shadow-geometry injection fails closed")
	original_mesh.shadow_mesh = original_shadow_mesh
	var original_surface_material := original_mesh.surface_get_material(0)
	var replacement_surface_material := StandardMaterial3D.new()
	replacement_surface_material.resource_name = "InjectedSurfaceMaterial"
	original_mesh.surface_set_material(0, replacement_surface_material)
	_expect_integrity_rejection(presentation, "in-place ArrayMesh surface material drift fails closed")
	original_mesh.surface_set_material(0, original_surface_material)

	var original_skin := suit.skin
	suit.skin = original_skin.duplicate()
	_expect_integrity_rejection(presentation, "substituted Skin resource fails closed")
	suit.skin = original_skin
	var original_bind_pose := original_skin.get_bind_pose(0)
	var mutated_bind_pose := original_bind_pose
	mutated_bind_pose.origin += Vector3(100.0, 100.0, 100.0)
	original_skin.set_bind_pose(0, mutated_bind_pose)
	_expect_integrity_rejection(presentation, "in-place Skin bind-pose drift fails closed")
	original_skin.set_bind_pose(0, original_bind_pose)

	var pelvis_index := skeleton.find_bone("pelvis")
	var original_pelvis_rest := skeleton.get_bone_rest(pelvis_index)
	var mutated_pelvis_rest := original_pelvis_rest
	mutated_pelvis_rest.origin += Vector3(100.0, 100.0, 100.0)
	skeleton.set_bone_rest(pelvis_index, mutated_pelvis_rest)
	_expect_integrity_rejection(presentation, "in-place Skeleton rest drift fails closed")
	skeleton.set_bone_rest(pelvis_index, original_pelvis_rest)
	var original_show_rest := skeleton.show_rest_only
	skeleton.show_rest_only = true
	_expect_integrity_rejection(presentation, "Skeleton rest-only deformation freeze fails closed")
	skeleton.show_rest_only = original_show_rest
	var original_motion_scale := skeleton.motion_scale
	skeleton.motion_scale = 0.01
	_expect_integrity_rejection(presentation, "near-zero Skeleton motion scale fails closed")
	skeleton.motion_scale = original_motion_scale
	var original_bone_enabled := skeleton.is_bone_enabled(pelvis_index)
	skeleton.set_bone_enabled(pelvis_index, false)
	_expect_integrity_rejection(presentation, "disabled deformation bone fails closed")
	skeleton.set_bone_enabled(pelvis_index, original_bone_enabled)
	var injected_pose_override := skeleton.get_bone_global_pose_no_override(pelvis_index)
	injected_pose_override.origin += Vector3(100.0, 100.0, 100.0)
	skeleton.set_bone_global_pose_override(pelvis_index, injected_pose_override, 1.0, true)
	_expect_integrity_rejection(presentation, "persistent Skeleton pose override fails closed")
	skeleton.clear_bones_global_pose_override()
	skeleton.force_update_all_bone_transforms()
	var exact_current_override := skeleton.get_bone_global_pose(pelvis_index)
	skeleton.set_bone_global_pose_override(pelvis_index, exact_current_override, 1.0, true)
	_expect_integrity_rejection(
		presentation,
		"exact-current persistent Skeleton pose override fails closed before pose drift"
	)
	skeleton.clear_bones_global_pose_override()
	var sentinel_override := skeleton.get_bone_global_pose_override(pelvis_index)
	skeleton.set_bone_global_pose_override(pelvis_index, sentinel_override, 1.0, true)
	_expect_integrity_rejection(
		presentation,
		"identity-sentinel Skeleton pose override amount fails closed"
	)
	skeleton.clear_bones_global_pose_override()

	var active_material := suit.get_active_material(0) as StandardMaterial3D
	var original_albedo := active_material.albedo_color
	var original_material_transparency := active_material.transparency
	active_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	active_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_expect_integrity_rejection(presentation, "in-place transparent material drift fails closed")
	active_material.albedo_color = original_albedo
	active_material.transparency = original_material_transparency

	var original_callback_mode := animation_player.callback_mode_process
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_expect_integrity_rejection(presentation, "automatic AnimationPlayer sampling drift fails closed")
	animation_player.callback_mode_process = original_callback_mode
	var original_animation_active := animation_player.active
	animation_player.active = false
	_expect_integrity_rejection(presentation, "disabled imported AnimationMixer fails closed")
	animation_player.active = original_animation_active
	var original_root_motion_track := animation_player.root_motion_track
	animation_player.root_motion_track = animation_player.get_animation(&"walk").track_get_path(0)
	_expect_integrity_rejection(presentation, "AnimationPlayer root-motion suppression fails closed")
	animation_player.root_motion_track = original_root_motion_track
	var original_deterministic := animation_player.deterministic
	animation_player.deterministic = not original_deterministic
	_expect_integrity_rejection(presentation, "AnimationPlayer deterministic-sampling drift fails closed")
	animation_player.deterministic = original_deterministic
	var original_discrete_mode := animation_player.callback_mode_discrete
	animation_player.callback_mode_discrete = AnimationMixer.ANIMATION_CALLBACK_MODE_DISCRETE_FORCE_CONTINUOUS
	_expect_integrity_rejection(presentation, "AnimationPlayer discrete-sampling drift fails closed")
	animation_player.callback_mode_discrete = original_discrete_mode
	var walk := animation_player.get_animation(&"walk")
	var original_walk_path := walk.track_get_path(0)
	var animation_root := animation_player.get_node(NodePath(animation_player.root_node))
	var presentation_path := animation_root.get_path_to(presentation)
	walk.track_set_path(0, NodePath("%s:position" % presentation_path))
	_expect_integrity_rejection(presentation, "animation track retargeted to gameplay root fails closed")
	walk.track_set_path(0, original_walk_path)
	var original_seated := library.get_animation(&"seated_control")
	var idle := library.get_animation(&"idle")
	library.remove_animation(&"seated_control")
	library.add_animation(&"seated_control", idle)
	_expect_integrity_rejection(presentation, "seated-control alias to idle fails closed")
	library.remove_animation(&"seated_control")
	library.add_animation(&"seated_control", original_seated)

	var duplicate_animation_player := animation_player.duplicate() as AnimationPlayer
	duplicate_animation_player.name = "InjectedAnimationPlayer"
	import_root.add_child(duplicate_animation_player)
	_expect_integrity_rejection(presentation, "second animation authority fails closed")
	import_root.remove_child(duplicate_animation_player)
	duplicate_animation_player.free()
	var injected_authority := Area3D.new()
	injected_authority.name = "InjectedInteractionAuthority"
	presentation.add_child(injected_authority)
	_expect_integrity_rejection(presentation, "wrapper-level gameplay authority injection fails closed")
	presentation.remove_child(injected_authority)
	injected_authority.free()
	var injected_script := GDScript.new()
	injected_script.source_code = "extends Node3D\nfunc _physics_process(_delta): pass\n"
	_check(injected_script.reload() == OK, "adversarial imported-node script compiles")
	import_root.set_script(injected_script)
	_expect_integrity_rejection(presentation, "script injected into imported hierarchy fails closed")
	import_root.set_script(null)

	var compatibility_simulators := presentation.find_children(
		"*", "PhysicalBoneSimulator3D", true, false
	)
	_check(
		compatibility_simulators.size() == 1,
		"pilot owns exactly one engine-internal compatibility simulator"
	)
	if compatibility_simulators.size() == 1:
		var compatibility_simulator := (
			compatibility_simulators[0] as PhysicalBoneSimulator3D
		)
		var compatibility_process_mode := compatibility_simulator.process_mode
		var injected_simulator_script := GDScript.new()
		injected_simulator_script.source_code = (
			"extends PhysicalBoneSimulator3D\n"
			+ "func _process(_delta: float) -> void:\n"
			+ "\tpass\n"
		)
		_check(
			injected_simulator_script.reload() == OK,
			"engine compatibility simulator injection fixture compiles"
		)
		compatibility_simulator.set_script(injected_simulator_script)
		compatibility_simulator.process_mode = Node.PROCESS_MODE_ALWAYS
		_expect_integrity_rejection(
			presentation,
			"script or process authority injected into the internal simulator fails closed"
		)
		compatibility_simulator.set_script(null)
		compatibility_simulator.process_mode = compatibility_process_mode

	visual_root.reparent(presentation, false)
	var substitute_visual := Node3D.new()
	substitute_visual.name = "PilotArt"
	import_root.add_child(substitute_visual)
	_expect_integrity_rejection(presentation, "same-name PilotArt substitution fails closed")
	import_root.remove_child(substitute_visual)
	substitute_visual.free()
	visual_root.reparent(import_root, false)
	visual_root.transform = visual_transform

	_check(
		bool(presentation.get_asset_audit_report().get("valid", false)),
		"restoring every adversarial mutation restores the exact pilot contract"
	)

	var independent_host := Node3D.new()
	independent_host.name = "IndependentPilotHost"
	root.add_child(independent_host)
	var independent := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	independent_host.add_child(independent)
	await process_frame
	var independent_suit := (
		independent.get_visual_root().find_child("PilotSuit", true, false)
		as MeshInstance3D
	)
	_check(
		bool(independent.get_asset_audit_report().get("valid", false)),
		"independent wrapper is canonical before isolation mutation"
	)
	_check(
		independent_suit.mesh != suit.mesh
		and independent_suit.skin != suit.skin
		and independent.get_animation_player().get_animation(&"walk") != walk
		and independent_suit.get_active_material(0) != active_material,
		"each wrapper localizes mesh, Skin, animation, and material resources"
	)
	var local_walk_path := walk.track_get_path(0)
	walk.track_set_path(0, NodePath("PilotArt/PilotRig/PilotSkeleton:not_a_bone"))
	_expect_integrity_rejection(presentation, "first instance detects its localized animation mutation")
	_check(
		bool(independent.get_asset_audit_report().get("valid", false)),
		"one pilot's animation mutation cannot poison another live instance"
	)
	walk.track_set_path(0, local_walk_path)
	independent_host.queue_free()
	await process_frame

	var later_host := Node3D.new()
	later_host.name = "LaterPilotHost"
	root.add_child(later_host)
	var poisoned_path := walk.track_get_path(0)
	walk.track_set_path(0, NodePath("PilotArt/PilotRig/PilotSkeleton:not_a_bone"))
	var later := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	later_host.add_child(later)
	await process_frame
	_check(
		bool(later.get_asset_audit_report().get("valid", false))
		and str(later.get_asset_audit_report().get("source_content_signature", ""))
			== SOURCE_CONTENT_SIGNATURE,
		"mutating an earlier pilot cannot poison a later wrapper's source baseline"
	)
	walk.track_set_path(0, poisoned_path)
	later_host.queue_free()
	await process_frame

	var destructive := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	root.add_child(destructive)
	await process_frame
	destructive.get_visual_root().free()
	_check(
		not bool(destructive.get_asset_audit_report().get("valid", true)),
		"freed PilotArt subtree is rejected without crashing the audit"
	)
	destructive.get_animation_player().free()
	_check(
		destructive.get_visual_root() == null
		and destructive.get_skeleton() == null
		and destructive.get_animation_player() == null,
		"public wrapper getters null-normalize every freed cached pilot reference"
	)
	destructive.queue_free()
	await process_frame


func _expect_integrity_rejection(
	presentation: PilotSkinnedPresentation,
	description: String
	) -> void:
	var audit := presentation.get_asset_audit_report()
	_check(not bool(audit.get("valid", true)), description)
	if bool(audit.get("valid", true)):
		print("PILOT_INTEGRITY_FAIL_OPEN: ", description, " report=", audit)


func _test_manifest() -> void:
	var manifest := _read_json(MANIFEST_PATH)
	_check(not manifest.is_empty() and int(manifest.get("schema_version", 0)) == 2, "checked-in pilot manifest parses with stable schema v2")
	_check(str(manifest.get("asset_id", "")) == "keth.pilot.motion.v2", "manifest publishes one stable pilot asset ID")
	_check(str(manifest.get("blender_version", "")) == "4.0.2", "manifest pins the actual Blender 4.0.2 authoring tool")
	_check(str(manifest.get("authorship", "")) == "original_script_assisted_blender", "manifest preserves honest provenance")
	_check(not bool(manifest.get("motion_capture", true)) and not bool(manifest.get("runtime_generation", true)), "manifest makes no mocap or runtime-generation claim")
	_check(
		int(manifest.get("bone_count", 0)) == 23
		and int(manifest.get("skinned_mesh_count", 0)) == 1
		and int(manifest.get("rigid_bone_attachment_mesh_count", 0)) == 1,
		"manifest pins the exact armature, skin, and rigid harness topology"
	)
	_check(int(manifest.get("source_part_count", 0)) >= 50, "editable source records a detailed multi-part suit construction")
	_check(int(manifest.get("mesh_vertices_exported_evaluated", 0)) >= 7000, "authored suit carries substantial close-range vertex detail")
	_check(int(manifest.get("mesh_triangles_exported_evaluated", 0)) >= 14000, "authored suit carries substantial close-range triangle detail")
	_check(
		int(manifest.get("rigid_mesh_vertices_exported_evaluated", 0)) == 56
		and int(manifest.get("rigid_mesh_triangles_exported_evaluated", 0)) == 108,
		"rigid harness lamp stays a bounded rounded box without skinned pole triangles"
	)
	_check((manifest.get("actions", []) as Array).size() == 9, "manifest records the complete nine-action source library")
	_check(str(manifest.get("glb_sha256", "")) == FileAccess.get_sha256(GLB_PATH), "manifest pins the exact runtime GLB hash")
	_check(str(manifest.get("blend_sha256", "")) == FileAccess.get_sha256(BLEND_PATH), "manifest pins the exact editable Blender source hash")
	_check(
		str(manifest.get("generator_sha256", "")) == FileAccess.get_sha256(GENERATOR_PATH),
		"manifest pins the exact offline pilot generator without changing GLB or Blend bytes"
	)
	var coordinates := manifest.get("coordinate_contract", {}) as Dictionary
	_check(
		str(coordinates.get("imported_visual_forward_axis", "")) == "+Z"
		and str(coordinates.get("mounted_player_forward_axis", "")).begins_with("-Z"),
		"manifest truthfully distinguishes imported mesh and mounted Player forward axes"
	)


func _surface_bounds_for_role(mesh: Mesh, material_role: StringName) -> AABB:
	if mesh == null:
		return AABB()
	for surface_index in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface_index)
		if material == null or StringName(material.resource_name) != material_role:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			return AABB()
		var bounds := AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			bounds = bounds.expand(vertex)
		return bounds
	return AABB()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PILOT_BLENDER_ASSET_TEST_OK: %d assertions" % _assertions)
		quit()
	else:
		print("PILOT_BLENDER_ASSET_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
