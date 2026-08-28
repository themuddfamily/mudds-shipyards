class_name PilotSkinnedPresentation
extends Node3D

## Visual-only adapter for the original Blender-authored skinned pilot.
##
## The imported GLB owns deformation and visual pose clips only. CharacterBody3D
## collision, traversal, cameras, input, interaction, boarding and seat-following
## remain native gameplay authority in PlayerController.

const SCHEMA_VERSION := 2
const ASSET_PATH := "res://assets/models/pilot/pilot_motion_v2.glb"
const SOURCE_PATH := "res://art_source/pilot/pilot_motion_v2.blend"
const MANIFEST_PATH := "res://assets/models/pilot/pilot_motion_v2_asset_manifest.json"
## Re-frozen when the placeholder procedural pose tables were replaced with
## authored motion and the pinned Blender 4.0.2 generator was re-run.
##
## Reason: correcting the leg signs fixed a defect but left the clips as pose
## lerps between a handful of keys. Boarding folded a standing man in half on
## the spot; the walk and run were symmetric scissors whose arms swung with the
## same-side leg; idle's only travel was a 0.8 mm pelvis nudge, and that nudge
## was horizontal. All nine clips are now sampled from authored timing curves.
##
##   GLB            b869688643a78ba1... -> b2d0c05e29c5ab03...
##   .blend         e7001460e6223b8f... -> aa0700ece03c76cd...
##   resource graph dc7167a7e66a36ad... -> f9f0b788a140656c...
##
## CHANGED: every animation curve; per-clip imported track count 17 -> 23, as
## the cycles now key the whole spine, both clavicles, both hands and a real
## pelvis translation instead of leaving them at rest.
## The amber harness release is intentionally a separate rigid mesh attached to
## spine_02 at runtime. Windows Forward+ intermittently expanded triangles from
## its former joined skinned surface into the reported screen-sized red panes;
## rigid single-bone detail has no reason to enter the GPU skinning buffer.
const EXPECTED_ASSET_SHA256 := "457c783ba0c27ef21531ce17c15d62d486bfa7216a0b8a120d09f0b046af4099"
const EXPECTED_SOURCE_SHA256 := "612840e09b44342f06c596b162dda4e67bb711713ff0bf20a34babf36326a1a6"
const EXPECTED_SOURCE_CONTENT_SHA256 := "5f89c5b26fad25fe9c59e47f1838bcaa536bee27a510401a5c87e8bc8d0e4ceb"
const EXPECTED_MESH_RESOURCE_PATH := ASSET_PATH + "::ArrayMesh_38ank"
const EXPECTED_RIGID_HARNESS_MESH_RESOURCE_PATH := ASSET_PATH + "::ArrayMesh_dfldj"
const EXPECTED_SKIN_RESOURCE_PATH := ASSET_PATH + "::Skin_l0rqn"
const EXPECTED_MATERIAL_RESOURCE_PATHS := [
	ASSET_PATH + "::StandardMaterial3D_jwsbr",
	ASSET_PATH + "::StandardMaterial3D_opf7r",
	ASSET_PATH + "::StandardMaterial3D_ox1kl",
	ASSET_PATH + "::StandardMaterial3D_w3v3p",
	ASSET_PATH + "::StandardMaterial3D_2f858",
	ASSET_PATH + "::StandardMaterial3D_s2leb",
	ASSET_PATH + "::StandardMaterial3D_uftr0",
	ASSET_PATH + "::StandardMaterial3D_des0f",
]
const EXPECTED_ANIMATION_RESOURCE_PATHS := {
	&"RESET": ASSET_PATH + "::Animation_78yge",
	&"airborne": ASSET_PATH + "::Animation_ptm1b",
	&"boarding": ASSET_PATH + "::Animation_5fek6",
	&"disembark_recovery": ASSET_PATH + "::Animation_bp0df",
	&"idle": ASSET_PATH + "::Animation_iusdu",
	&"jump": ASSET_PATH + "::Animation_yxp60",
	&"run": ASSET_PATH + "::Animation_hq1nq",
	&"seated_control": ASSET_PATH + "::Animation_3a2f5",
	&"walk": ASSET_PATH + "::Animation_at33j",
}

const EXPECTED_NODE_PATHS := {
	"PilotMotionImport": "Node3D",
	"PilotMotionImport/PilotArt": "Node3D",
	"PilotMotionImport/PilotArt/PilotRig": "Node3D",
	"PilotMotionImport/PilotArt/PilotRig/PilotSkeleton": "Skeleton3D",
	"PilotMotionImport/PilotArt/PilotRig/PilotSkeleton/PilotSuit": "MeshInstance3D",
	"PilotMotionImport/PilotArt/PilotRig/PilotSkeleton/HarnessReleaseAttachment": "BoneAttachment3D",
	"PilotMotionImport/PilotArt/PilotRig/PilotSkeleton/HarnessReleaseAttachment/HarnessRelease": "MeshInstance3D",
	"PilotMotionImport/PilotAnimationPlayer": "AnimationPlayer",
}

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
## Semantic mesh evidence (visor, chest plate and face status light) establishes
## that the raw imported suit looks along local +Z. PlayerController applies the
## mount-only PI yaw that converts this to its canonical local -Z travel/seat
## forward without altering the Blender resource or animation playback.
const IMPORTED_VISUAL_FORWARD_AXIS := Vector3.BACK
const PLAYER_CANONICAL_FORWARD_AXIS := Vector3.FORWARD
## The imported ankle joint is 0.15 m above the authored flat boot sole. The
## gameplay owner supplies a support point and its own movement-up direction;
## this presentation converts that detached observation back into an ankle
## target without querying physics or moving the Player root.
const FOOT_SOLE_CLEARANCE_M := 0.15
const FOOT_PLACEMENT_MAX_CORRECTION_M := 0.10
const FOOT_PLACEMENT_CONTACT_LIMIT_M := 0.08
const FOOT_PLACEMENT_MOTION_STATES := [&"idle", &"walk", &"run"]
const FOOT_CHAIN_BONES := {
	&"l": [&"thigh_l", &"calf_l", &"foot_l"],
	&"r": [&"thigh_r", &"calf_r", &"foot_r"],
}
## 22 bone rotation tracks plus one pelvis position track. The import drops
## immutable tracks, so this is exactly the set of bones the authored clips
## actually move: everything but `root`, which stays invariant by contract
## because this asset never owns traversal or yaw.
const EXPECTED_CLIP_TRACK_COUNTS := {
	&"RESET": 23,
	&"idle": 23,
	&"walk": 23,
	&"run": 23,
	&"jump": 23,
	&"airborne": 23,
	&"boarding": 23,
	&"seated_control": 23,
	&"disembark_recovery": 23,
}
## Godot's platform glTF decoders can differ below one micro-unit when they
## normalize derived normals and tangents. Geometry, UVs, indices, skinning and
## authored animation data remain exact; only these unit-direction channels use
## a portable precision when the untouched source graph is first identified.
## The captured live integrity contract still hashes the full runtime arrays.
const SOURCE_DIRECTION_PRECISION := 0.000001
## Render layer reserved for "this avatar's own body, as seen by the observer
## riding it". Nothing else in the project uses a render layer other than 1, and
## every camera in the project keeps Godot's default all-layers cull mask, so a
## suit parked here is still drawn by every other camera in the scene -- the
## ship's chase camera, a second occupant's camera, and every capture harness.
## Only the one camera that has deliberately cleared this bit stops seeing it.
##
## This is the ONLY sanctioned mutation of the suit's render state, and it is
## sanctioned precisely because it is per-observer: hiding the pilot by
## `visible`, `transparency` or `cast_shadow` would remove him for everyone, and
## is exactly what the integrity contract below exists to catch.
const LOCAL_OBSERVER_CULL_LAYER := 20
const LOCAL_OBSERVER_CULL_MASK := 1 << (LOCAL_OBSERVER_CULL_LAYER - 1)

const FORBIDDEN_AUTHORITY_TYPES := [
	"CollisionObject3D",
	"CollisionShape3D",
	"Area3D",
	"Camera3D",
	"AudioStreamPlayer3D",
	"NavigationRegion3D",
	"NavigationAgent3D",
]

var _import_root: Node3D
var _visual_root: Node3D
var _rig_root: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _harness_release_attachment: BoneAttachment3D
var _harness_release: MeshInstance3D
var _skinned_meshes: Array[MeshInstance3D] = []
var _built := false
var _local_observer_culled := false
var _integrity_contract: Dictionary = {}
var _canonical_resource_contract: Dictionary = {}
var _foot_placement_attachment_generation := 0
var _foot_placement_attached := false
var _last_foot_placement_physics_frame := -1
var _foot_placement_snapshot: Dictionary = {}


func _enter_tree() -> void:
	_foot_placement_attachment_generation += 1
	_foot_placement_attached = true
	_last_foot_placement_physics_frame = -1
	_foot_placement_snapshot = _empty_foot_placement_snapshot(&"attached")


func _exit_tree() -> void:
	_foot_placement_attached = false
	_last_foot_placement_physics_frame = -1
	_foot_placement_snapshot = _empty_foot_placement_snapshot(&"detached")


func _ready() -> void:
	_build_once()


func _build_once() -> void:
	if _built:
		return
	_built = true
	# Ignore the global ResourceLoader cache deeply. Imported GLB subresources
	# are shared by default, so accepting a cached scene would let an earlier
	# instance's in-place mutation become a later instance's trusted baseline.
	var packed := ResourceLoader.load(
		ASSET_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	if packed == null:
		push_error("Unable to load the Blender-authored pilot asset")
		return
	# CACHE_MODE_IGNORE_DEEP gives this adapter a fresh imported scene and fresh
	# subresources without stripping their direct-GLB resource paths. Capture the
	# untouched source graph before the one permitted normalization below, so one
	# live pilot can neither poison a later instance's baseline nor mutate another
	# player's deformation library.
	_import_root = packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node3D
	if _import_root == null:
		push_error("Unable to instantiate the Blender-authored pilot asset")
		return
	_import_root.name = "PilotMotionImport"
	add_child(_import_root)
	_visual_root = _import_root.get_node_or_null("PilotArt") as Node3D
	if _visual_root == null:
		_visual_root = _import_root.find_child("PilotArt", true, false) as Node3D
	if _visual_root != null:
		_rig_root = _visual_root.get_node_or_null("PilotRig") as Node3D
	if _rig_root != null:
		_skeleton = _rig_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null and _rig_root != null:
		_skeleton = _rig_root.find_child("PilotSkeleton", true, false) as Skeleton3D
	_animation_player = _import_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_capture_source_resource_contract()
	_normalize_runtime_names()
	_attach_rigid_harness_release()
	_collect_skinned_meshes()
	_capture_integrity_contract()


func _capture_source_resource_contract() -> void:
	_canonical_resource_contract.clear()
	if _import_root == null or _animation_player == null:
		return
	var source_meshes := _import_root.find_children("*", "MeshInstance3D", true, false)
	if source_meshes.size() != 2:
		return
	var suit := _import_root.find_child("PilotSuit", true, false) as MeshInstance3D
	var harness_release := _import_root.find_child("HarnessRelease", true, false) as MeshInstance3D
	if (
		suit == null or suit.mesh == null or suit.skin == null
		or harness_release == null or harness_release.mesh == null
		or harness_release.skin != null
		or not harness_release.skeleton.is_empty()
	):
		return
	var material_paths := PackedStringArray()
	var material_signatures := []
	for surface_index in suit.mesh.get_surface_count():
		var material := suit.mesh.surface_get_material(surface_index)
		material_paths.append(material.resource_path if material != null else "")
		material_signatures.append({
			"path": material.resource_path if material != null else "",
			"name": material.resource_name if material != null else "",
			"signature": _resource_signature(material),
		})
	var harness_material := harness_release.get_active_material(0)
	material_paths.append(
		harness_material.resource_path if harness_material != null else ""
	)
	material_signatures.append({
		"path": harness_material.resource_path if harness_material != null else "",
		"name": harness_material.resource_name if harness_material != null else "",
		"signature": _resource_signature(harness_material),
	})
	var animation_paths := {}
	var animation_signatures := []
	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		animation_paths[animation_name] = animation.resource_path if animation != null else ""
		animation_signatures.append({
			"name": animation_name,
			"path": animation.resource_path if animation != null else "",
			"signature": _animation_signature(animation) if animation != null else "",
		})
	var source_signature_payload := {
		"nodes": _source_node_contract(),
		"mesh_path": suit.mesh.resource_path,
		"mesh_signature": _mesh_signature(suit.mesh, true),
		"rigid_harness_mesh_path": harness_release.mesh.resource_path,
		"rigid_harness_mesh_signature": _mesh_signature(harness_release.mesh, true),
		"skin_path": suit.skin.resource_path,
		"skin_signature": _variant_sha256(&"pilot_skin_v2", _skin_contract(suit.skin)),
		"materials": material_signatures,
		"animations": animation_signatures,
	}
	_canonical_resource_contract = {
		"source_asset_path": ASSET_PATH,
		"asset_sha256": (
			FileAccess.get_sha256(ASSET_PATH)
			if FileAccess.file_exists(ASSET_PATH) else ""
		),
		"mesh_source_path": suit.mesh.resource_path,
		"skin_source_path": suit.skin.resource_path,
		"rigid_harness_mesh_source_path": harness_release.mesh.resource_path,
		"material_source_paths": material_paths,
		"animation_source_paths": animation_paths,
		"source_content_signature": _variant_sha256(
			&"pilot_source_resource_graph_v2",
			source_signature_payload
		),
	}


func _attach_rigid_harness_release() -> void:
	_harness_release = null
	_harness_release_attachment = null
	if _visual_root == null or _skeleton == null:
		return
	var source := _visual_root.get_node_or_null("HarnessRelease") as MeshInstance3D
	var spine_index := _skeleton.find_bone("spine_02")
	if (
		source == null or source.mesh == null or source.skin != null
		or not source.skeleton.is_empty() or spine_index < 0
	):
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "HarnessReleaseAttachment"
	attachment.bone_name = "spine_02"
	attachment.use_external_skeleton = false
	_skeleton.add_child(attachment)
	_skeleton.force_update_all_bone_transforms()
	# Preserve the authored rest-space placement while transferring ownership to
	# the live bone. Only this rigid node follows spine_02; its vertices never
	# enter a Skin or skeletal surface again.
	source.reparent(attachment, true)
	_harness_release_attachment = attachment
	_harness_release = source


func _source_node_contract() -> Array:
	var contract := []
	if _import_root == null:
		return contract
	var nodes: Array[Node] = [_import_root]
	for descendant in _import_root.find_children("*", "", true, false):
		if _is_engine_compat_simulator(descendant):
			continue
		nodes.append(descendant)
	for node in nodes:
		var script: Script = node.get_script() as Script
		var entry: Dictionary = {
			"path": String(_import_root.get_path_to(node)),
			"name": String(node.name),
			"class": node.get_class(),
			"process_mode": node.process_mode,
			"script_present": script != null,
			"script_path": script.resource_path if script != null else "",
		}
		if node is Node3D:
			var node_3d := node as Node3D
			entry["transform"] = node_3d.transform
			entry["top_level"] = node_3d.top_level
			entry["visible"] = node_3d.visible
			entry["visibility_parent"] = node_3d.visibility_parent
		if node is Skeleton3D:
			var skeleton := node as Skeleton3D
			entry["motion_scale"] = skeleton.motion_scale
			entry["show_rest_only"] = skeleton.show_rest_only
			entry["modifier_callback"] = skeleton.modifier_callback_mode_process
			entry["animate_physical_bones"] = skeleton.animate_physical_bones
			entry["bone_rest_contract"] = _skeleton_rest_contract(skeleton)
		elif node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			entry["mesh_path"] = (
				mesh_instance.mesh.resource_path if mesh_instance.mesh != null else ""
			)
			entry["skin_path"] = (
				mesh_instance.skin.resource_path if mesh_instance.skin != null else ""
			)
			entry["skeleton_path"] = mesh_instance.skeleton
			entry["layers"] = mesh_instance.layers
			entry["cast_shadow"] = mesh_instance.cast_shadow
			entry["transparency"] = mesh_instance.transparency
			entry["sorting_offset"] = mesh_instance.sorting_offset
			entry["sorting_use_aabb_center"] = mesh_instance.sorting_use_aabb_center
			entry["extra_cull_margin"] = mesh_instance.extra_cull_margin
			entry["custom_aabb"] = mesh_instance.custom_aabb
			entry["lod_bias"] = mesh_instance.lod_bias
			entry["ignore_occlusion_culling"] = mesh_instance.ignore_occlusion_culling
			entry["visibility_range_begin"] = mesh_instance.visibility_range_begin
			entry["visibility_range_begin_margin"] = mesh_instance.visibility_range_begin_margin
			entry["visibility_range_end"] = mesh_instance.visibility_range_end
			entry["visibility_range_end_margin"] = mesh_instance.visibility_range_end_margin
			entry["visibility_range_fade_mode"] = mesh_instance.visibility_range_fade_mode
		elif node is AnimationPlayer:
			var player := node as AnimationPlayer
			entry["root_node"] = player.root_node
			entry["root_motion_track"] = player.root_motion_track
			entry["root_motion_local"] = player.root_motion_local
			entry["deterministic"] = player.deterministic
			entry["callback_process"] = player.callback_mode_process
			entry["callback_method"] = player.callback_mode_method
			entry["callback_discrete"] = player.callback_mode_discrete
			entry["active"] = player.active
		contract.append(entry)
	return contract


func _normalize_runtime_names() -> void:
	if _animation_player != null:
		_animation_player.name = "PilotAnimationPlayer"
		_animation_player.callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		)
	# Godot names a glTF armature node Skeleton3D regardless of Blender's
	# armature-data name. Publish the source contract at runtime and retarget the
	# imported track paths in place; no animations are allocated or copied.
	if _skeleton == null or _skeleton.name == &"PilotSkeleton":
		return
	var former_name := String(_skeleton.name)
	_skeleton.name = "PilotSkeleton"
	if _animation_player == null:
		return
	for clip_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(clip_name)
		if animation == null:
			continue
		for track_index in animation.get_track_count():
			var old_path := String(animation.track_get_path(track_index))
			var old_token := "/%s:" % former_name
			if old_path.contains(old_token):
				animation.track_set_path(
					track_index,
					NodePath(old_path.replace(old_token, "/PilotSkeleton:"))
				)


func _collect_skinned_meshes() -> void:
	_skinned_meshes.clear()
	if _visual_root == null or _skeleton == null:
		return
	for candidate in _visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var linked_skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton)
		if mesh_instance.skin != null and linked_skeleton == _skeleton:
			_skinned_meshes.append(mesh_instance)


func _capture_integrity_contract() -> void:
	_integrity_contract.clear()
	if (
		_import_root == null
		or _visual_root == null
		or _rig_root == null
		or _skeleton == null
		or _animation_player == null
		or _harness_release_attachment == null
		or _harness_release == null
		or _skinned_meshes.size() != 1
	):
		return
	var suit := _skinned_meshes[0]
	if suit.mesh == null or suit.skin == null:
		return
	var node_contract := {}
	for relative_path in EXPECTED_NODE_PATHS:
		var node := get_node_or_null(NodePath(relative_path))
		if node == null:
			return
		node_contract[relative_path] = {
			"class": node.get_class(),
			"instance_id": node.get_instance_id(),
			"parent_id": (
				node.get_parent().get_instance_id()
				if node.get_parent() != null else 0
			),
			"transform": node.transform if node is Node3D else Transform3D.IDENTITY,
			"top_level": (node as Node3D).top_level if node is Node3D else false,
			"visible": (node as Node3D).visible if node is Node3D else true,
			"visibility_parent": (
				(node as Node3D).visibility_parent if node is Node3D else NodePath()
			),
			"script_id": (
				node.get_script().get_instance_id()
				if node.get_script() != null else 0
			),
			"process_mode": node.process_mode,
		}
	var rest_contract := []
	for bone_index in _skeleton.get_bone_count():
		rest_contract.append({
			"name": _skeleton.get_bone_name(bone_index),
			"parent": _skeleton.get_bone_parent(bone_index),
			"rest": _skeleton.get_bone_rest(bone_index),
			"enabled": _skeleton.is_bone_enabled(bone_index),
		})
	var bind_contract := []
	for bind_index in suit.skin.get_bind_count():
		bind_contract.append({
			"bone": suit.skin.get_bind_bone(bind_index),
			"name": suit.skin.get_bind_name(bind_index),
			"pose": suit.skin.get_bind_pose(bind_index),
		})
	var material_contract := []
	for surface_index in suit.mesh.get_surface_count():
		var material := suit.get_active_material(surface_index)
		material_contract.append({
			"instance_id": material.get_instance_id() if material != null else 0,
			"path": material.resource_path if material != null else "",
			"name": material.resource_name if material != null else "",
			"signature": _resource_signature(material),
		})
	var animation_contract := {}
	for clip_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(clip_name)
		animation_contract[clip_name] = {
			"instance_id": animation.get_instance_id(),
			"path": animation.resource_path,
			"signature": _animation_signature(animation),
		}
	_integrity_contract = {
		"node_contract": node_contract,
		"mesh_instance_id": suit.mesh.get_instance_id(),
		"mesh_path": suit.mesh.resource_path,
		"mesh_signature": _mesh_signature(suit.mesh),
		"suit_skeleton_path": suit.skeleton,
		"suit_material_override_id": (
			suit.material_override.get_instance_id()
			if suit.material_override != null else 0
		),
		"suit_material_overlay_id": (
			suit.material_overlay.get_instance_id()
			if suit.material_overlay != null else 0
		),
		"suit_layers": suit.layers,
		"suit_cast_shadow": suit.cast_shadow,
		"suit_transparency": suit.transparency,
		"suit_sorting_offset": suit.sorting_offset,
		"suit_sorting_use_aabb_center": suit.sorting_use_aabb_center,
		"suit_extra_cull_margin": suit.extra_cull_margin,
		"suit_custom_aabb": suit.custom_aabb,
		"suit_lod_bias": suit.lod_bias,
		"suit_ignore_occlusion_culling": suit.ignore_occlusion_culling,
		"suit_visibility_parent": suit.visibility_parent,
		"suit_visibility_range_begin": suit.visibility_range_begin,
		"suit_visibility_range_begin_margin": suit.visibility_range_begin_margin,
		"suit_visibility_range_end": suit.visibility_range_end,
		"suit_visibility_range_end_margin": suit.visibility_range_end_margin,
		"suit_visibility_range_fade_mode": suit.visibility_range_fade_mode,
		"skin_instance_id": suit.skin.get_instance_id(),
		"skin_path": suit.skin.resource_path,
		"bind_contract": bind_contract,
		"rest_contract": rest_contract,
		"skeleton_show_rest_only": _skeleton.show_rest_only,
		"skeleton_motion_scale": _skeleton.motion_scale,
		"skeleton_animate_physical_bones": _skeleton.animate_physical_bones,
		"skeleton_modifier_callback": _skeleton.modifier_callback_mode_process,
		"material_contract": material_contract,
		"harness_mesh_instance_id": _harness_release.mesh.get_instance_id(),
		"harness_mesh_path": _harness_release.mesh.resource_path,
		"harness_mesh_signature": _mesh_signature(_harness_release.mesh),
		"harness_material_instance_id": (
			_harness_release.get_active_material(0).get_instance_id()
			if _harness_release.get_active_material(0) != null else 0
		),
		"harness_material_path": (
			_harness_release.get_active_material(0).resource_path
			if _harness_release.get_active_material(0) != null else ""
		),
		"harness_material_signature": _resource_signature(
			_harness_release.get_active_material(0)
		),
		"harness_layers": _harness_release.layers,
		"harness_cast_shadow": _harness_release.cast_shadow,
		"harness_bone_name": _harness_release_attachment.bone_name,
		"harness_external_skeleton": _harness_release_attachment.use_external_skeleton,
		"animation_library_id": (
			_animation_player.get_animation_library(&"").get_instance_id()
			if _animation_player.get_animation_library(&"") != null else 0
		),
		"animation_root_node": _animation_player.root_node,
		"animation_root_motion_track": _animation_player.root_motion_track,
		"animation_root_motion_local": _animation_player.root_motion_local,
		"animation_deterministic": _animation_player.deterministic,
		"animation_callback_process": _animation_player.callback_mode_process,
		"animation_callback_method": _animation_player.callback_mode_method,
		"animation_callback_discrete": _animation_player.callback_mode_discrete,
		"animation_active": _animation_player.active,
		"animation_contract": animation_contract,
		"asset_sha256": (
			FileAccess.get_sha256(ASSET_PATH)
			if FileAccess.file_exists(ASSET_PATH) else ""
		),
		"source_sha256": (
			FileAccess.get_sha256(SOURCE_PATH)
			if FileAccess.file_exists(SOURCE_PATH) else ""
		),
	}


func _append_integrity_errors(errors: PackedStringArray) -> void:
	if _integrity_contract.is_empty():
		errors.append("immutable pilot integrity contract was not captured")
		return
	# Export packs contain Godot's imported scene plus its remap rather than the
	# raw .glb/.blend authoring files. Direct source hashes are therefore an
	# editor/development assertion; exported builds retain the manifest and the
	# exact live resource/content contract below.
	if FileAccess.file_exists(ASSET_PATH) and FileAccess.file_exists(SOURCE_PATH):
		if FileAccess.get_sha256(ASSET_PATH) != str(_integrity_contract.get("asset_sha256", "")):
			errors.append("checked-in pilot GLB changed after contract capture")
		if (
			FileAccess.get_sha256(ASSET_PATH) != EXPECTED_ASSET_SHA256
			or FileAccess.get_sha256(SOURCE_PATH) != EXPECTED_SOURCE_SHA256
		):
			errors.append("pilot Blender source or runtime GLB hash drift")
	var manifest := _read_manifest()
	if (
		str(manifest.get("glb_sha256", "")) != EXPECTED_ASSET_SHA256
		or str(manifest.get("blend_sha256", "")) != EXPECTED_SOURCE_SHA256
	):
		errors.append("pilot asset manifest hash contract drift")
	var source_animation_paths := _canonical_resource_contract.get(
		"animation_source_paths", {}
	) as Dictionary
	var source_material_paths := _canonical_resource_contract.get(
		"material_source_paths", PackedStringArray()
	) as PackedStringArray
	if (
		str(_canonical_resource_contract.get("source_asset_path", "")) != ASSET_PATH
		or str(_canonical_resource_contract.get("mesh_source_path", ""))
			!= EXPECTED_MESH_RESOURCE_PATH
		or str(_canonical_resource_contract.get("skin_source_path", ""))
			!= EXPECTED_SKIN_RESOURCE_PATH
		or str(_canonical_resource_contract.get("rigid_harness_mesh_source_path", ""))
			!= EXPECTED_RIGID_HARNESS_MESH_RESOURCE_PATH
		or source_material_paths != PackedStringArray(EXPECTED_MATERIAL_RESOURCE_PATHS)
		or source_animation_paths != EXPECTED_ANIMATION_RESOURCE_PATHS
	):
		errors.append("pilot source subresource provenance contract drift")
	if (
		str(_canonical_resource_contract.get("source_content_signature", ""))
			!= EXPECTED_SOURCE_CONTENT_SHA256
	):
		errors.append("pilot pre-normalization source content signature drift")
	if FileAccess.file_exists(ASSET_PATH) and (
		str(_canonical_resource_contract.get("asset_sha256", ""))
			!= EXPECTED_ASSET_SHA256
	):
		errors.append("pilot source GLB hash was not canonical before normalization")
	if name != &"PilotSkinnedPresentation":
		errors.append("pilot presentation wrapper identity drift")
	var expected_nodes := _integrity_contract.get("node_contract", {}) as Dictionary
	for relative_path in EXPECTED_NODE_PATHS:
		var node := get_node_or_null(NodePath(relative_path))
		var expected := expected_nodes.get(relative_path, {}) as Dictionary
		if node == null:
			errors.append("required runtime node is missing or detached: %s" % relative_path)
			continue
		if (
			node.get_class() != str(expected.get("class", ""))
			or node.get_instance_id() != int(expected.get("instance_id", 0))
			or node.get_parent() == null
			or node.get_parent().get_instance_id() != int(expected.get("parent_id", 0))
		):
			errors.append("runtime node identity or parent drift: %s" % relative_path)
		if (
			(node.get_script().get_instance_id() if node.get_script() != null else 0)
				!= int(expected.get("script_id", 0))
			or node.process_mode != int(expected.get("process_mode", -1))
		):
			errors.append("runtime node script or process-mode drift: %s" % relative_path)
		if node is Node3D:
			var node_3d := node as Node3D
			if (
				not (node_3d is BoneAttachment3D)
				and not node_3d.transform.is_equal_approx(
					expected.get("transform", Transform3D.IDENTITY)
				)
			):
				errors.append("runtime node transform drift: %s" % relative_path)
			if node_3d.top_level != bool(expected.get("top_level", false)):
				errors.append("runtime node top-level drift: %s" % relative_path)
			if (
				node_3d.visible != bool(expected.get("visible", false))
				or node_3d.visibility_parent
					!= expected.get("visibility_parent", NodePath("__missing__"))
			):
				errors.append("runtime node visibility contract drift: %s" % relative_path)
	var observed_paths := {}
	for node in find_children("*", "", true, false):
		if _is_engine_compat_simulator(node):
			continue
		observed_paths[String(get_path_to(node))] = node.get_class()
	if observed_paths != EXPECTED_NODE_PATHS:
		errors.append("authored pilot runtime node roster drift")
	var simulators := find_children("*", "PhysicalBoneSimulator3D", true, false)
	if (
		simulators.size() != 1
		or not _is_engine_compat_simulator(simulators[0])
		or simulators[0].get_script() != null
		or simulators[0].process_mode != Node.PROCESS_MODE_INHERIT
		or (simulators[0] as PhysicalBoneSimulator3D).is_simulating_physics()
		or not find_children("*", "PhysicalBone3D", true, false).is_empty()
	):
		errors.append("engine pilot compatibility simulator contract drift")
	if not visible or not is_visible_in_tree():
		errors.append("pilot presentation wrapper is hidden")
	for required_visual in [_import_root, _visual_root, _rig_root, _skeleton]:
		if is_instance_valid(required_visual) and (
			not required_visual.visible
			or not required_visual.is_visible_in_tree()
		):
			errors.append("required pilot visual hierarchy is hidden: %s" % required_visual.name)

	var suit := get_node_or_null(
		"PilotMotionImport/PilotArt/PilotRig/PilotSkeleton/PilotSuit"
	) as MeshInstance3D
	if suit == null:
		return
	if not suit.visible or not suit.is_visible_in_tree():
		errors.append("PilotSuit is hidden")
	if suit.mesh == null or (
		suit.mesh.get_instance_id() != int(_integrity_contract.get("mesh_instance_id", 0))
		or suit.mesh.resource_path != str(_integrity_contract.get("mesh_path", ""))
		or _mesh_signature(suit.mesh) != str(_integrity_contract.get("mesh_signature", ""))
	):
		errors.append("PilotSuit mesh resource or content drift")
	if (
		suit.skeleton != _integrity_contract.get("suit_skeleton_path", NodePath())
		or suit.get_node_or_null(suit.skeleton) != _skeleton
		or (suit.material_override.get_instance_id() if suit.material_override != null else 0)
			!= int(_integrity_contract.get("suit_material_override_id", 0))
		or (suit.material_overlay.get_instance_id() if suit.material_overlay != null else 0)
			!= int(_integrity_contract.get("suit_material_overlay_id", 0))
		or suit.layers != get_expected_suit_render_layers()
		or suit.cast_shadow != int(_integrity_contract.get("suit_cast_shadow", 0))
		or not is_equal_approx(
			suit.transparency,
			float(_integrity_contract.get("suit_transparency", -1.0))
		)
		or not is_equal_approx(
			suit.sorting_offset,
			float(_integrity_contract.get("suit_sorting_offset", INF))
		)
		or suit.sorting_use_aabb_center
			!= bool(_integrity_contract.get("suit_sorting_use_aabb_center", false))
		or not is_equal_approx(
			suit.extra_cull_margin,
			float(_integrity_contract.get("suit_extra_cull_margin", INF))
		)
		or not suit.custom_aabb.is_equal_approx(
			_integrity_contract.get("suit_custom_aabb", AABB(Vector3.ZERO, Vector3(INF, INF, INF)))
		)
		or not is_equal_approx(
			suit.lod_bias,
			float(_integrity_contract.get("suit_lod_bias", INF))
		)
		or suit.ignore_occlusion_culling
			!= bool(_integrity_contract.get("suit_ignore_occlusion_culling", true))
		or suit.visibility_parent
			!= _integrity_contract.get("suit_visibility_parent", NodePath("__missing__"))
		or not is_equal_approx(
			suit.visibility_range_begin,
			float(_integrity_contract.get("suit_visibility_range_begin", -1.0))
		)
		or not is_equal_approx(
			suit.visibility_range_begin_margin,
			float(_integrity_contract.get("suit_visibility_range_begin_margin", -1.0))
		)
		or not is_equal_approx(
			suit.visibility_range_end,
			float(_integrity_contract.get("suit_visibility_range_end", -1.0))
		)
		or not is_equal_approx(
			suit.visibility_range_end_margin,
			float(_integrity_contract.get("suit_visibility_range_end_margin", -1.0))
		)
		or suit.visibility_range_fade_mode
			!= int(_integrity_contract.get("suit_visibility_range_fade_mode", -1))
	):
		errors.append("PilotSuit deformation target or render-state drift")
	if suit.skin == null or (
		suit.skin.get_instance_id() != int(_integrity_contract.get("skin_instance_id", 0))
		or suit.skin.resource_path != str(_integrity_contract.get("skin_path", ""))
		or _skin_contract(suit.skin) != _integrity_contract.get("bind_contract", [])
	):
		errors.append("PilotSuit Skin resource or bind contract drift")
	if is_instance_valid(_skeleton) and _skeleton_rest_contract(_skeleton) != _integrity_contract.get("rest_contract", []):
		errors.append("PilotSkeleton rest or topology contract drift")
	if is_instance_valid(_skeleton) and _has_effective_bone_pose_override(_skeleton):
		errors.append("PilotSkeleton contains a persistent global-pose override")
	if is_instance_valid(_skeleton) and (
		_skeleton.show_rest_only
			!= bool(_integrity_contract.get("skeleton_show_rest_only", true))
		or not is_equal_approx(
			_skeleton.motion_scale,
			float(_integrity_contract.get("skeleton_motion_scale", -1.0))
		)
		or _skeleton.animate_physical_bones
			!= bool(_integrity_contract.get("skeleton_animate_physical_bones", false))
		or _skeleton.modifier_callback_mode_process
			!= int(_integrity_contract.get("skeleton_modifier_callback", -1))
	):
		errors.append("PilotSkeleton deformation processing drift")
	if suit.mesh != null:
		var expected_materials := _integrity_contract.get("material_contract", []) as Array
		if suit.mesh.get_surface_count() != expected_materials.size():
			errors.append("PilotSuit material surface roster drift")
		else:
			for surface_index in suit.mesh.get_surface_count():
				var material := suit.get_active_material(surface_index)
				var expected_material := expected_materials[surface_index] as Dictionary
				if (
					material == null
					or material.get_instance_id() != int(expected_material.get("instance_id", 0))
					or material.resource_path != str(expected_material.get("path", ""))
					or material.resource_name != str(expected_material.get("name", ""))
					or _resource_signature(material) != str(expected_material.get("signature", ""))
				):
					errors.append("PilotSuit active material drift at surface %d" % surface_index)

	var harness_material := (
		_harness_release.get_active_material(0)
		if is_instance_valid(_harness_release) else null
	)
	if (
		not is_instance_valid(_harness_release_attachment)
		or _harness_release_attachment.get_parent() != _skeleton
		or _harness_release_attachment.bone_name
			!= StringName(_integrity_contract.get("harness_bone_name", &""))
		or _harness_release_attachment.use_external_skeleton
			!= bool(_integrity_contract.get("harness_external_skeleton", true))
		or not is_instance_valid(_harness_release)
		or _harness_release.get_parent() != _harness_release_attachment
		or _harness_release.skin != null
		or not _harness_release.skeleton.is_empty()
		or _harness_release.mesh == null
		or _harness_release.mesh.get_instance_id()
			!= int(_integrity_contract.get("harness_mesh_instance_id", 0))
		or _harness_release.mesh.resource_path
			!= str(_integrity_contract.get("harness_mesh_path", ""))
		or _mesh_signature(_harness_release.mesh)
			!= str(_integrity_contract.get("harness_mesh_signature", ""))
		or harness_material == null
		or harness_material.get_instance_id()
			!= int(_integrity_contract.get("harness_material_instance_id", 0))
		or harness_material.resource_path
			!= str(_integrity_contract.get("harness_material_path", ""))
		or _resource_signature(harness_material)
			!= str(_integrity_contract.get("harness_material_signature", ""))
		or _harness_release.layers != get_expected_suit_render_layers()
		or _harness_release.cast_shadow
			!= int(_integrity_contract.get("harness_cast_shadow", 0))
	):
		errors.append("rigid harness-release attachment contract drift")

	var animation_players := find_children("*", "AnimationPlayer", true, false)
	if animation_players.size() != 1 or animation_players[0] != _animation_player:
		errors.append("pilot must own exactly one imported AnimationPlayer")
	if not is_instance_valid(_animation_player):
		return
	if (
		_animation_player.root_node
			!= _integrity_contract.get("animation_root_node", NodePath())
		or _animation_player.root_motion_track
			!= _integrity_contract.get("animation_root_motion_track", NodePath("__missing__"))
		or _animation_player.root_motion_local
			!= bool(_integrity_contract.get("animation_root_motion_local", true))
		or _animation_player.deterministic
			!= bool(_integrity_contract.get("animation_deterministic", true))
		or _animation_player.callback_mode_process
			!= int(_integrity_contract.get("animation_callback_process", -1))
		or _animation_player.callback_mode_method
			!= int(_integrity_contract.get("animation_callback_method", -1))
		or _animation_player.callback_mode_discrete
			!= int(_integrity_contract.get("animation_callback_discrete", -1))
		or _animation_player.active
			!= bool(_integrity_contract.get("animation_active", false))
	):
		errors.append("imported AnimationPlayer sampling contract drift")
	var library := _animation_player.get_animation_library(&"")
	if library == null or library.get_instance_id() != int(_integrity_contract.get("animation_library_id", 0)):
		errors.append("imported AnimationLibrary identity drift")
	var expected_animations := _integrity_contract.get("animation_contract", {}) as Dictionary
	if _animation_player.get_animation_list().size() != expected_animations.size():
		errors.append("imported animation roster drift")
	for clip_name in expected_animations:
		var animation := _animation_player.get_animation(clip_name)
		var expected_animation := expected_animations[clip_name] as Dictionary
		if (
			animation == null
			or animation.get_instance_id() != int(expected_animation.get("instance_id", 0))
			or animation.resource_path != str(expected_animation.get("path", ""))
			or _animation_signature(animation) != str(expected_animation.get("signature", ""))
		):
			errors.append("imported animation resource or track drift: %s" % clip_name)


func _is_engine_compat_simulator(node: Node) -> bool:
	if not is_instance_valid(_skeleton):
		return false
	var runtime_name := String(node.name)
	const GENERATED_PREFIX := "@PhysicalBoneSimulator3D@"
	return (
		node is PhysicalBoneSimulator3D
		and node.get_parent() == _skeleton
		and runtime_name.begins_with(GENERATED_PREFIX)
		and runtime_name.trim_prefix(GENERATED_PREFIX).is_valid_int()
		and _skeleton.get_children(true).has(node)
		and not _skeleton.get_children(false).has(node)
	)


func _read_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _skeleton_rest_contract(skeleton: Skeleton3D) -> Array:
	var result := []
	for bone_index in skeleton.get_bone_count():
		result.append({
			"name": skeleton.get_bone_name(bone_index),
			"parent": skeleton.get_bone_parent(bone_index),
			"rest": skeleton.get_bone_rest(bone_index),
			"enabled": skeleton.is_bone_enabled(bone_index),
		})
	return result


func _has_effective_bone_pose_override(skeleton: Skeleton3D) -> bool:
	skeleton.force_update_all_bone_transforms()
	var expected_global_poses := _expected_global_bone_poses(skeleton)
	for bone_index in skeleton.get_bone_count():
		if not skeleton.get_bone_global_pose(bone_index).is_equal_approx(
			expected_global_poses[bone_index]
		):
			return true
	# Godot exposes an override's transform but not its blend amount. An active
	# persistent override can exactly equal the current animated pose and thus arm
	# a future freeze while the comparison above is still equal. Perturb the root
	# pose once, compare the complete hierarchy, and synchronously restore it. An
	# inactive cleared override follows the root; an active skeleton-space override
	# does not. No sampled pose is retained or included in the immutable contract.
	if skeleton.get_bone_count() > 0:
		var root_index := 0
		for bone_index in skeleton.get_bone_count():
			if skeleton.get_bone_parent(bone_index) < 0:
				root_index = bone_index
				break
		var original_root_pose := skeleton.get_bone_pose(root_index)
		var probe_root_pose := original_root_pose
		probe_root_pose.origin += Vector3(0.173, -0.119, 0.137)
		skeleton.set_bone_pose(root_index, probe_root_pose)
		skeleton.force_update_all_bone_transforms()
		var probe_expected := _expected_global_bone_poses(skeleton)
		var override_is_active := false
		for bone_index in skeleton.get_bone_count():
			if not skeleton.get_bone_global_pose(bone_index).is_equal_approx(
				probe_expected[bone_index]
			):
				override_is_active = true
				break
		skeleton.set_bone_pose(root_index, original_root_pose)
		skeleton.force_update_all_bone_transforms()
		if override_is_active:
			return true
	return false


func _expected_global_bone_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone_index in skeleton.get_bone_count():
		var parent_index := skeleton.get_bone_parent(bone_index)
		var local_pose := skeleton.get_bone_pose(bone_index)
		result.append(
			result[parent_index] * local_pose
			if parent_index >= 0 else local_pose
		)
	return result


func _skin_contract(skin: Skin) -> Array:
	var result := []
	for bind_index in skin.get_bind_count():
		result.append({
			"bone": skin.get_bind_bone(bind_index),
			"name": skin.get_bind_name(bind_index),
			"pose": skin.get_bind_pose(bind_index),
		})
	return result


func _resource_signature(resource: Resource) -> String:
	if resource == null:
		return ""
	var properties := {}
	for property in resource.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		if property_name in [&"resource_path", &"resource_name", &"resource_local_to_scene"]:
			continue
		var value: Variant = resource.get(property_name)
		if value is Resource:
			var child_resource := value as Resource
			properties[property_name] = {
				"class": child_resource.get_class(),
				"path": child_resource.resource_path,
				"name": child_resource.resource_name,
			}
		else:
			properties[property_name] = value
	return _variant_sha256(&"pilot_resource_v2", properties)


func _mesh_signature(mesh: Mesh, portable_source: bool = false) -> String:
	var content := [{
		"aabb": mesh.get_aabb(),
		"custom_aabb": mesh.custom_aabb,
	}]
	for surface_index in mesh.get_surface_count():
		var server_surface := RenderingServer.mesh_get_surface(
			mesh.get_rid(),
			surface_index
		) as Dictionary
		content.append({
			"primitive": mesh.surface_get_primitive_type(surface_index),
			"format": mesh.surface_get_format(surface_index),
			"arrays": (
				_canonical_source_surface_arrays(mesh.surface_get_arrays(surface_index))
				if portable_source else mesh.surface_get_arrays(surface_index)
			),
			"lods": server_surface.get("lods", {}),
		})
	var blend_shapes := []
	for blend_shape_index in mesh.get_blend_shape_count():
		blend_shapes.append({
			"name": mesh.get_blend_shape_name(blend_shape_index),
			"arrays": mesh.surface_get_blend_shape_arrays(blend_shape_index),
		})
	content.append({
		"blend_shape_mode": mesh.get_blend_shape_mode(),
		"blend_shapes": blend_shapes,
		"shadow_mesh_present": (
			mesh is ArrayMesh and (mesh as ArrayMesh).shadow_mesh != null
		),
		"shadow_mesh_path": (
			(mesh as ArrayMesh).shadow_mesh.resource_path
			if mesh is ArrayMesh and (mesh as ArrayMesh).shadow_mesh != null else ""
		),
	})
	var signature_domain: StringName = (
		&"pilot_source_mesh_v2" if portable_source else &"pilot_mesh_v2"
	)
	return _variant_sha256(signature_domain, content)


func _canonical_source_surface_arrays(surface_arrays: Array) -> Array:
	var canonical := surface_arrays.duplicate(true)
	var normals := canonical[Mesh.ARRAY_NORMAL] as PackedVector3Array
	for normal_index in normals.size():
		var normal := normals[normal_index]
		normals[normal_index] = Vector3(
			_canonical_source_direction(normal.x),
			_canonical_source_direction(normal.y),
			_canonical_source_direction(normal.z)
		)
	canonical[Mesh.ARRAY_NORMAL] = normals
	var tangents := canonical[Mesh.ARRAY_TANGENT] as PackedFloat32Array
	for tangent_index in tangents.size():
		tangents[tangent_index] = _canonical_source_direction(tangents[tangent_index])
	canonical[Mesh.ARRAY_TANGENT] = tangents
	return canonical


func _canonical_source_direction(value: float) -> float:
	var canonical := snappedf(value, SOURCE_DIRECTION_PRECISION)
	return 0.0 if canonical == 0.0 else canonical


func _animation_signature(animation: Animation) -> String:
	var content := {
		"length": animation.length,
		"loop_mode": animation.loop_mode,
		"step": animation.step,
		"tracks": [],
	}
	for track_index in animation.get_track_count():
		var track := {
			"type": animation.track_get_type(track_index),
			"path": animation.track_get_path(track_index),
			"imported": animation.track_is_imported(track_index),
			"enabled": animation.track_is_enabled(track_index),
			"interpolation": animation.track_get_interpolation_type(track_index),
			"loop_wrap": animation.track_get_interpolation_loop_wrap(track_index),
			"keys": [],
		}
		for key_index in animation.track_get_key_count(track_index):
			track.keys.append({
				"time": animation.track_get_key_time(track_index, key_index),
				"transition": animation.track_get_key_transition(track_index, key_index),
				"value": animation.track_get_key_value(track_index, key_index),
			})
		content.tracks.append(track)
	return _variant_sha256(&"pilot_animation_v2", content)


func _variant_sha256(domain: StringName, value: Variant) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hashing.update(var_to_bytes([domain, value]))
	return hashing.finish().hex_encode()


func get_asset_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	_append_integrity_errors(errors)
	if _import_root == null or not is_instance_valid(_import_root):
		errors.append("imported pilot container is missing")
	if _visual_root == null or not is_instance_valid(_visual_root):
		errors.append("PilotArt root is missing")
	if not is_instance_valid(_rig_root) or _rig_root.name != &"PilotRig":
		errors.append("PilotRig root is missing")
	if not is_instance_valid(_skeleton) or _skeleton.name != &"PilotSkeleton":
		errors.append("PilotSkeleton runtime root is missing")
	if not is_instance_valid(_animation_player) or _animation_player.name != &"PilotAnimationPlayer":
		errors.append("PilotAnimationPlayer is missing")

	if not transform.is_equal_approx(Transform3D.IDENTITY) or top_level:
		errors.append("presentation adapter transform is not identity")
	for source_node in [_visual_root, _rig_root, _skeleton]:
		if is_instance_valid(source_node) and not source_node.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("imported hierarchy transform is not identity: %s" % source_node.name)

	var observed_bones := PackedStringArray()
	if is_instance_valid(_skeleton):
		for bone_index in _skeleton.get_bone_count():
			observed_bones.append(String(_skeleton.get_bone_name(bone_index)))
		if _skeleton.get_bone_count() != REQUIRED_BONE_PARENTS.size():
			errors.append("skeleton does not contain the exact authored bone set")
		for bone_name: StringName in REQUIRED_BONE_PARENTS:
			var bone_index := _skeleton.find_bone(String(bone_name))
			if bone_index < 0:
				errors.append("required bone is missing: %s" % bone_name)
				continue
			var expected_parent := REQUIRED_BONE_PARENTS[bone_name] as StringName
			var actual_parent_index := _skeleton.get_bone_parent(bone_index)
			var actual_parent: StringName = (
				_skeleton.get_bone_name(actual_parent_index)
				if actual_parent_index >= 0 else &""
			)
			if actual_parent != expected_parent:
				errors.append("bone parent drift: %s" % bone_name)

	var imported_track_count := 0
	var root_motion := _audit_root_motion()
	if is_instance_valid(_animation_player):
		if (
			_animation_player.callback_mode_process
			!= AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		):
			errors.append("imported motion is not configured for deterministic manual sampling")
		var animation_names := _animation_player.get_animation_list()
		if animation_names.size() != REQUIRED_CLIP_DURATIONS.size():
			errors.append("animation player does not contain the exact nine-clip library")
		for clip_name: StringName in REQUIRED_CLIP_DURATIONS:
			if not _animation_player.has_animation(clip_name):
				errors.append("required imported clip is missing: %s" % clip_name)
				continue
			var animation := _animation_player.get_animation(clip_name)
			var expected_duration := float(REQUIRED_CLIP_DURATIONS[clip_name])
			if absf(animation.length - expected_duration) > 0.002:
				errors.append("authored clip duration drift: %s" % clip_name)
			var expected_loop := LOOPING_CLIPS.has(clip_name)
			var actual_loop := animation.loop_mode != Animation.LOOP_NONE
			if actual_loop != expected_loop:
				errors.append("authored clip loop contract drift: %s" % clip_name)
			if animation.get_track_count() == 0:
				errors.append("authored clip has no deformation tracks: %s" % clip_name)
			if animation.get_track_count() != int(EXPECTED_CLIP_TRACK_COUNTS[clip_name]):
				errors.append("authored clip track roster drift: %s" % clip_name)
			for track_index in animation.get_track_count():
				var track_path := animation.track_get_path(track_index)
				var animation_root := _animation_player.get_node_or_null(
					NodePath(_animation_player.root_node)
				)
				var track_target := animation_root.get_node_or_null(
					NodePath(track_path.get_concatenated_names())
				) if animation_root != null else null
				var bone_name := (
					String(track_path.get_subname(0))
					if track_path.get_subname_count() == 1 else ""
				)
				if (
					not is_instance_valid(_skeleton)
					or track_target != _skeleton
					or _skeleton.find_bone(bone_name) < 0
					or animation.track_get_type(track_index) not in [
						Animation.TYPE_POSITION_3D,
						Animation.TYPE_ROTATION_3D,
						Animation.TYPE_SCALE_3D,
					]
				):
					errors.append("clip contains a non-skeleton or unknown-bone track: %s" % clip_name)
					break
				if animation.track_is_imported(track_index):
					imported_track_count += 1
				else:
					errors.append("clip contains a runtime-generated track: %s" % clip_name)
					break
		if _animation_player.get_animation_library_list() != [&""]:
			errors.append("imported clips are not exposed through one default library")
	if float(root_motion.horizontal_metres) > 0.0001:
		errors.append("root bone contains forbidden horizontal motion")
	if float(root_motion.yaw_radians) > 0.0001:
		errors.append("root bone contains forbidden yaw motion")

	if _skinned_meshes.size() != 1:
		errors.append("pilot must publish exactly one joined skinned mesh")
	var weighted_bone_count := 0
	var material_roles := PackedStringArray()
	for mesh_instance in _skinned_meshes:
		if not is_instance_valid(mesh_instance):
			continue
		if mesh_instance.skin != null:
			weighted_bone_count = maxi(weighted_bone_count, mesh_instance.skin.get_bind_count())
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var surface_material := mesh_instance.get_active_material(surface_index)
				if surface_material != null and not material_roles.has(surface_material.resource_name):
					material_roles.append(surface_material.resource_name)
	if is_instance_valid(_harness_release):
		var harness_material := _harness_release.get_active_material(0)
		if harness_material != null and not material_roles.has(harness_material.resource_name):
			material_roles.append(harness_material.resource_name)
	if weighted_bone_count != REQUIRED_BONE_PARENTS.size():
		errors.append("skin does not bind the exact authored skeleton")
	if material_roles.size() != 8:
		errors.append("pilot presentation does not preserve the exact eight-role material separation")

	var forbidden_count := 0
	for type_name in FORBIDDEN_AUTHORITY_TYPES:
		forbidden_count += find_children("*", type_name, true, false).size()
	if forbidden_count != 0:
		errors.append("imported pilot subtree contains gameplay-authority nodes")
	var bounds := _calculate_bind_bounds()
	if bounds.size.y < 1.85 or bounds.size.y > 2.0:
		errors.append("pilot bind silhouette is outside the practical architecture envelope")
	if absf(bounds.position.y) > 0.002:
		errors.append("pilot boot soles do not meet the authored ground plane")
	var source_material_paths := PackedStringArray(
		_canonical_resource_contract.get("material_source_paths", PackedStringArray())
	)
	var source_animation_paths := (
		_canonical_resource_contract.get("animation_source_paths", {}) as Dictionary
	).duplicate(true)

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"version": &"blender_skinned_v2",
		"authorship": &"original_script_assisted_blender",
		"motion_capture": false,
		"runtime_clip_generation": false,
		"asset_path": ASSET_PATH,
		"source_path": SOURCE_PATH,
		"source_asset_path": str(
			_canonical_resource_contract.get("source_asset_path", "")
		),
		"source_mesh_resource_path": str(
			_canonical_resource_contract.get("mesh_source_path", "")
		),
		"source_skin_resource_path": str(
			_canonical_resource_contract.get("skin_source_path", "")
		),
		"source_rigid_harness_mesh_resource_path": str(
			_canonical_resource_contract.get("rigid_harness_mesh_source_path", "")
		),
		"source_material_resource_paths": source_material_paths,
		"source_animation_resource_paths": source_animation_paths,
		"source_content_signature": str(
			_canonical_resource_contract.get("source_content_signature", "")
		),
		"resource_cache_isolated": not _canonical_resource_contract.is_empty(),
		"gameplay_authority": false,
		"visual_root": _visual_root,
		"skeleton": _skeleton,
		"animation_player": _animation_player,
		"bone_count": observed_bones.size(),
		"bone_names": observed_bones,
		"clip_count": REQUIRED_CLIP_DURATIONS.size(),
		"imported_track_count": imported_track_count,
		"skinned_mesh_count": _skinned_meshes.size(),
		"rigid_harness_mesh_count": 1 if is_instance_valid(_harness_release) else 0,
		"weighted_bone_count": weighted_bone_count,
		"material_roles": material_roles,
		"material_role_count": material_roles.size(),
		"bind_bounds": bounds,
		"ground_contact_y_bind": bounds.position.y,
		"root_motion_horizontal_m": root_motion.horizontal_metres,
		"root_motion_yaw_rad": root_motion.yaw_radians,
		"imported_visual_forward_axis": IMPORTED_VISUAL_FORWARD_AXIS,
		"player_canonical_forward_axis": PLAYER_CANONICAL_FORWARD_AXIS,
		"visual_forward_direction": get_visual_forward_direction(),
		"forbidden_authority_node_count": forbidden_count,
		"identity_transform": transform.is_equal_approx(Transform3D.IDENTITY),
		"integrity_contract_captured": not _integrity_contract.is_empty(),
	}


func _audit_root_motion() -> Dictionary:
	var maximum_horizontal := 0.0
	var maximum_yaw := 0.0
	if not is_instance_valid(_animation_player):
		return {"horizontal_metres": maximum_horizontal, "yaw_radians": maximum_yaw}
	for clip_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(clip_name)
		if animation == null:
			continue
		for track_index in animation.get_track_count():
			var track_path := animation.track_get_path(track_index)
			if track_path.get_subname_count() == 0 or track_path.get_subname(0) != &"root":
				continue
			for key_index in animation.track_get_key_count(track_index):
				var value: Variant = animation.track_get_key_value(track_index, key_index)
				if value is Vector3 and animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
					var translation := value as Vector3
					maximum_horizontal = maxf(
						maximum_horizontal,
						Vector2(translation.x, translation.z).length()
					)
				elif value is Quaternion and animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
					maximum_yaw = maxf(maximum_yaw, absf((value as Quaternion).get_euler().y))
	return {"horizontal_metres": maximum_horizontal, "yaw_radians": maximum_yaw}


func _calculate_bind_bounds() -> AABB:
	var has_bounds := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	if not is_instance_valid(_visual_root) or not _visual_root.is_inside_tree():
		return AABB()
	var to_visual := _visual_root.global_transform.affine_inverse()
	for mesh_instance in _skinned_meshes:
		if not is_instance_valid(mesh_instance) or not mesh_instance.is_inside_tree():
			continue
		var transform_to_visual := to_visual * mesh_instance.global_transform
		for corner in _aabb_corners(mesh_instance.get_aabb()):
			var point := transform_to_visual * corner
			if not has_bounds:
				minimum = point
				maximum = point
				has_bounds = true
			else:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum) if has_bounds else AABB()


func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				corners.append(Vector3(x, y, z))
	return corners


## Moves the skinned suit onto [constant LOCAL_OBSERVER_CULL_LAYER] so a single
## camera can stop drawing it, and back to its captured layers when released.
##
## This exists for the on-foot first-person view: the observer riding this body
## must not be shown the inside of its own skull, while every other observer --
## a second occupant, the craft's chase camera, a capture harness -- must keep
## seeing the pilot walk, run and idle exactly as authored. Per-observer culling
## is the only mechanism that can express that; `visible` cannot.
##
## Deformation, clip playback, materials, shadow casting and the whole node
## roster are untouched. The suit keeps casting its shadow while culled, so a
## first-person player still sees his own shadow on the deck.
func set_local_observer_culled(culled: bool) -> bool:
	var suit := get_node_or_null(
		"PilotMotionImport/PilotArt/PilotRig/PilotSkeleton/PilotSuit"
	) as MeshInstance3D
	if (
		suit == null or not is_instance_valid(_harness_release)
		or _integrity_contract.is_empty()
	):
		return false
	_local_observer_culled = culled
	suit.layers = get_expected_suit_render_layers()
	_harness_release.layers = get_expected_suit_render_layers()
	return true


func is_local_observer_culled() -> bool:
	return _local_observer_culled


## Render layers the suit is contractually required to be on right now. This is
## the captured value except while [method set_local_observer_culled] is engaged,
## which is the single declared exception. Any other layer value is still drift.
func get_expected_suit_render_layers() -> int:
	if _local_observer_culled:
		return LOCAL_OBSERVER_CULL_MASK
	return int(_integrity_contract.get("suit_layers", 0))


func get_animation_player() -> AnimationPlayer:
	return _animation_player if is_instance_valid(_animation_player) else null


func get_skeleton() -> Skeleton3D:
	return _skeleton if is_instance_valid(_skeleton) else null


## Returns only the current animated ankle origins. Physics ownership remains
## outside this subtree; the caller may use these points to sample support once
## and return detached finite observations through [method apply_foot_placement].
func get_animated_foot_anchors() -> Dictionary:
	if not _foot_placement_attached or not is_instance_valid(_skeleton):
		return {}
	_skeleton.force_update_all_bone_transforms()
	var result := {}
	for side: StringName in FOOT_CHAIN_BONES:
		var foot_name: StringName = FOOT_CHAIN_BONES[side][2]
		var foot_index := _skeleton.find_bone(foot_name)
		if foot_index < 0:
			return {}
		var ankle_local := _skeleton.get_bone_global_pose(foot_index).origin
		result[side] = _skeleton.global_transform * ankle_local
	return result.duplicate(true)


func get_foot_placement_attachment_generation() -> int:
	return _foot_placement_attachment_generation


func get_foot_placement_snapshot() -> Dictionary:
	return _foot_placement_snapshot.duplicate(true)


## Applies one caller-physics sample after the imported AnimationPlayer has
## advanced. The operation changes only the current thigh/calf/foot bone poses;
## it creates no modifier nodes, edits no animation resource, and has no body,
## collision, input, camera, traversal, or timing authority.
func apply_foot_placement(sample: Variant, expected_attachment_generation: int) -> Dictionary:
	if (
		not _foot_placement_attached
		or not is_inside_tree()
		or expected_attachment_generation != _foot_placement_attachment_generation
		or not sample is Dictionary
		or not is_instance_valid(_skeleton)
	):
		return _foot_placement_result(false, &"stale_foot_placement_attachment")
	var observation := sample as Dictionary
	var physics_frame := int(observation.get("physics_frame", -1))
	var motion_state := StringName(observation.get("motion_state", &""))
	var movement_up: Variant = observation.get("movement_up", Vector3.ZERO)
	var feet: Variant = observation.get("feet", {})
	if (
		physics_frame < 0
		or physics_frame <= _last_foot_placement_physics_frame
		or not movement_up is Vector3
		or not (movement_up as Vector3).is_finite()
		or (movement_up as Vector3).is_zero_approx()
		or not feet is Dictionary
	):
		return _foot_placement_result(false, &"invalid_foot_placement_sample")
	_last_foot_placement_physics_frame = physics_frame
	if motion_state not in FOOT_PLACEMENT_MOTION_STATES:
		_foot_placement_snapshot = _empty_foot_placement_snapshot(
			&"motion_state_inactive", physics_frame, motion_state
		)
		return _foot_placement_result(true, &"foot_placement_inactive")
	var normalized_up := (movement_up as Vector3).normalized()
	var corrected_feet := {}
	for side: StringName in FOOT_CHAIN_BONES:
		var support: Variant = (feet as Dictionary).get(side, {})
		if not support is Dictionary:
			corrected_feet[side] = _inactive_foot_record(&"support_missing")
			continue
		corrected_feet[side] = _apply_foot_chain(
			side, support as Dictionary, normalized_up
		)
	var any_foot_active := false
	for record: Variant in corrected_feet.values():
		if record is Dictionary and bool((record as Dictionary).get("active", false)):
			any_foot_active = true
			break
	_foot_placement_snapshot = {
		"active": any_foot_active,
		"attached": true,
		"attachment_generation": _foot_placement_attachment_generation,
		"physics_frame": physics_frame,
		"motion_state": motion_state,
		"feet": corrected_feet.duplicate(true),
		"modifier_node_count": find_children("*", "SkeletonModifier3D", true, false).size(),
	}.duplicate(true)
	return _foot_placement_result(true, &"foot_placement_applied")


func clear_foot_placement(expected_attachment_generation: int, reason: StringName) -> Dictionary:
	if (
		not _foot_placement_attached
		or expected_attachment_generation != _foot_placement_attachment_generation
	):
		return _foot_placement_result(false, &"stale_foot_placement_attachment")
	_foot_placement_snapshot = _empty_foot_placement_snapshot(reason)
	return _foot_placement_result(true, &"foot_placement_cleared")


func _apply_foot_chain(
		side: StringName, support: Dictionary, movement_up_world: Vector3
	) -> Dictionary:
	var support_position: Variant = support.get("position", Vector3.INF)
	var support_normal: Variant = support.get("normal", Vector3.ZERO)
	if (
		not support_position is Vector3
		or not (support_position as Vector3).is_finite()
		or not support_normal is Vector3
		or not (support_normal as Vector3).is_finite()
		or (support_normal as Vector3).is_zero_approx()
	):
		return _inactive_foot_record(&"support_invalid")
	var chain: Array = FOOT_CHAIN_BONES[side]
	var thigh_index := _skeleton.find_bone(chain[0])
	var calf_index := _skeleton.find_bone(chain[1])
	var foot_index := _skeleton.find_bone(chain[2])
	if thigh_index < 0 or calf_index < 0 or foot_index < 0:
		return _inactive_foot_record(&"bone_missing")
	_skeleton.force_update_all_bone_transforms()
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var up_local := (_skeleton.global_basis.inverse() * movement_up_world).normalized()
	var support_local := to_skeleton * (support_position as Vector3)
	var thigh_pose := _skeleton.get_bone_global_pose(thigh_index)
	var calf_pose := _skeleton.get_bone_global_pose(calf_index)
	var foot_pose := _skeleton.get_bone_global_pose(foot_index)
	var hip := thigh_pose.origin
	var knee := calf_pose.origin
	var ankle := foot_pose.origin
	var sole := ankle - up_local * FOOT_SOLE_CLEARANCE_M
	var requested_correction := (support_local - sole).dot(up_local)
	if absf(requested_correction) > FOOT_PLACEMENT_CONTACT_LIMIT_M:
		return {
			"active": false,
			"reason": &"foot_not_in_contact_phase",
			"requested_correction_m": requested_correction,
		}.duplicate(true)
	var correction := clampf(
		requested_correction,
		-FOOT_PLACEMENT_MAX_CORRECTION_M,
		FOOT_PLACEMENT_MAX_CORRECTION_M
	)
	var target_ankle := ankle + up_local * correction
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(ankle)
	var target_delta := target_ankle - hip
	var target_distance := target_delta.length()
	if (
		upper_length <= 0.001
		or lower_length <= 0.001
		or target_distance <= 0.001
	):
		return _inactive_foot_record(&"degenerate_leg_chain")
	var minimum_reach := absf(upper_length - lower_length) + 0.0005
	var maximum_reach := upper_length + lower_length - 0.0005
	var solved_distance := clampf(target_distance, minimum_reach, maximum_reach)
	var target_direction := target_delta / target_distance
	var solved_ankle := hip + target_direction * solved_distance
	var along := (
		upper_length * upper_length - lower_length * lower_length
		+ solved_distance * solved_distance
	) / (2.0 * solved_distance)
	var bend_height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var bend_direction := knee - (hip + target_direction * (knee - hip).dot(target_direction))
	if bend_direction.length_squared() <= 0.000001:
		bend_direction = IMPORTED_VISUAL_FORWARD_AXIS - (
			target_direction * IMPORTED_VISUAL_FORWARD_AXIS.dot(target_direction)
		)
	if bend_direction.length_squared() <= 0.000001:
		bend_direction = target_direction.cross(Vector3.RIGHT)
	bend_direction = bend_direction.normalized()
	var solved_knee := hip + target_direction * along + bend_direction * bend_height
	var original_foot_basis := foot_pose.basis
	var thigh_from := (knee - hip).normalized()
	var thigh_to := (solved_knee - hip).normalized()
	thigh_pose.basis = Basis(Quaternion(thigh_from, thigh_to)) * thigh_pose.basis
	_skeleton.set_bone_global_pose(thigh_index, thigh_pose)
	_skeleton.force_update_all_bone_transforms()
	calf_pose = _skeleton.get_bone_global_pose(calf_index)
	foot_pose = _skeleton.get_bone_global_pose(foot_index)
	var calf_from := (foot_pose.origin - calf_pose.origin).normalized()
	var calf_to := (solved_ankle - calf_pose.origin).normalized()
	calf_pose.basis = Basis(Quaternion(calf_from, calf_to)) * calf_pose.basis
	_skeleton.set_bone_global_pose(calf_index, calf_pose)
	_skeleton.force_update_all_bone_transforms()
	foot_pose = _skeleton.get_bone_global_pose(foot_index)
	# Keep the foot joint exactly where the solved calf placed it. Translating the
	# child foot bone to `target_ankle` independently can improve the sole-to-floor
	# number while physically separating the boot from the ankle whenever the
	# requested target lies beyond the two-bone chain's reachable limit. Preserve
	# only the animated foot orientation; the leg chain remains continuous.
	var chain_ankle := foot_pose.origin
	foot_pose.basis = original_foot_basis
	_skeleton.set_bone_global_pose(foot_index, foot_pose)
	_skeleton.force_update_all_bone_transforms()
	var corrected_ankle := _skeleton.get_bone_global_pose(foot_index).origin
	var corrected_sole := corrected_ankle - up_local * FOOT_SOLE_CLEARANCE_M
	var sole_error := absf((support_local - corrected_sole).dot(up_local))
	var ankle_chain_error := corrected_ankle.distance_to(chain_ankle)
	return {
		"active": true,
		"reason": &"support_corrected",
		"requested_correction_m": requested_correction,
		"applied_correction_m": correction,
		"sole_error_m": sole_error,
		"ankle_chain_error_m": ankle_chain_error,
		"support_position": support_position,
		"support_normal": (support_normal as Vector3).normalized(),
		"ankle_position": _skeleton.global_transform * corrected_ankle,
		"sole_position": _skeleton.global_transform * corrected_sole,
	}.duplicate(true)


func _inactive_foot_record(reason: StringName) -> Dictionary:
	return {"active": false, "reason": reason}.duplicate(true)


func _empty_foot_placement_snapshot(
		reason: StringName,
		physics_frame: int = -1,
		motion_state: StringName = &""
	) -> Dictionary:
	return {
		"active": false,
		"attached": _foot_placement_attached,
		"attachment_generation": _foot_placement_attachment_generation,
		"physics_frame": physics_frame,
		"motion_state": motion_state,
		"reason": reason,
		"feet": {},
		"modifier_node_count": find_children("*", "SkeletonModifier3D", true, false).size(),
	}.duplicate(true)


func _foot_placement_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"foot_placement": get_foot_placement_snapshot(),
	}.duplicate(true)


func get_visual_root() -> Node3D:
	return _visual_root if is_instance_valid(_visual_root) else null


## World-space semantic face direction of the raw imported suit. This is +Z in
## PilotArt local space; its Player-owned BodyPivot mount supplies the PI offset.
func get_visual_forward_direction() -> Vector3:
	if not is_instance_valid(_visual_root):
		return Vector3.ZERO
	return (_visual_root.global_basis * IMPORTED_VISUAL_FORWARD_AXIS).normalized()
