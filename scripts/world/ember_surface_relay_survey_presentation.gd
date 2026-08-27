class_name EmberSurfaceRelaySurveyPresentation
extends Node3D

## Presentation-only Ember survey route cues. The authored pad guide posts,
## sample rack, relay and route remain the physical context; these safe
## objective renderers consume detached adapter state and never pulse. A
## preallocated diamond seal appears inside the return ring only after the
## existing reward authority has committed the survey receipt.

const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)
const APPROACH_SCALE := Vector3(1.35, 0.55, 1.35)
const ACTIVE_SCALE := Vector3.ONE
## Keep each static state legible by silhouette at the normal pulled-back
## on-foot camera distance. The pending return is a tall oval, route lock is a
## broad empty ring, and reward confirmation contracts around a clearly inset
## diamond.
const CHECKPOINT_ONE_RING_SCALE := Vector3(0.78, 1.48, 0.78)
const ROUTE_COMPLETE_RING_SCALE := Vector3(1.52, 1.52, 1.52)
const REWARD_CONFIRMED_RING_SCALE := Vector3(1.05, 1.05, 1.05)
const REWARD_CONFIRMED_SEAL_SCALE := Vector3(0.94, 0.94, 0.94)
const PAD_AVAILABLE_TILT_RADIANS := 0.34
const PAD_AVAILABLE_SCALE := Vector3(1.0, 1.28, 1.0)
const PAD_COMPLETE_TILT_RADIANS := PI * 0.5
const RELAY_COLOR := Color(0.2, 0.7, 1.0, 1.0)
const RETURN_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const COMPLETION_COLOR := Color(0.95, 0.82, 0.25, 1.0)
const EMISSION_ENERGY := 0.55
const SURVEY_ACTIVITY_ID: StringName = &"ember_beacon_survey"
const SURVEY_REWARD_ID: StringName = &"ember_beacon_data"
const REWARD_STORE_ID: StringName = &"game_flow_reward_store"
const REWARD_AUTHORITY_ID: StringName = &"game_flow_reward_authority"
const MARKER_SHADER_SOURCE := """
shader_type spatial;
render_mode unshaded;

instance uniform vec4 marker_emission : source_color = vec4(1.0);
uniform float emission_energy = 0.55;

void fragment() {
	// Keep the authored state colour present under bright surface lighting while
	// retaining the existing reduced-flash emission ceiling.
	ALBEDO = marker_emission.rgb * 0.55;
	EMISSION = marker_emission.rgb * emission_energy;
}
"""

var _relay_marker: MeshInstance3D
var _return_marker: MeshInstance3D
var _completion_seal: MeshInstance3D
var _marker_material: ShaderMaterial
var _pad_guides_ref: WeakRef
var _pad_guide_neutral_transforms: Array[Transform3D] = []
var _pad_guide_applied_transforms: Array[Transform3D] = []
var _loaded_scene_instance_id := 0
var _state: StringName = &"idle"
var _cue_mode: StringName = &"hidden"
var _optional_checkpoint: Dictionary = {}
var _mandatory_route: Dictionary = {}
var _attached := true
var _activity_generation := -1
var _committed_reward: Dictionary = {}

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_marker_material = _make_marker_material()
	_relay_marker = _make_relay_marker()
	_return_marker = _make_return_marker()
	_completion_seal = _make_completion_seal()
	add_child(_relay_marker)
	add_child(_return_marker)
	add_child(_completion_seal)
	_apply_state(&"idle")


func bind_landing_pad_guides(
		guides: Variant, loaded_scene_instance_id: int
	) -> Dictionary:
	if not guides is MultiMeshInstance3D or loaded_scene_instance_id <= 0:
		return {"accepted": false, "reason": &"landing_pad_guides_unavailable"}
	var batch := guides as MultiMeshInstance3D
	var authored: Variant = batch.get_meta("authored_transforms", [])
	if batch.name != &"PadGuideVisuals" or batch.multimesh == null \
			or batch.multimesh.instance_count != 2 or not authored is Array \
			or (authored as Array).size() != 2:
		return {"accepted": false, "reason": &"invalid_landing_pad_guides"}
	var neutral: Array[Transform3D] = []
	for transform in authored as Array:
		if not transform is Transform3D:
			return {"accepted": false, "reason": &"invalid_landing_pad_guides"}
		neutral.append(transform as Transform3D)
	_pad_guides_ref = weakref(batch)
	_pad_guide_neutral_transforms = neutral
	_loaded_scene_instance_id = loaded_scene_instance_id
	_apply_landing_pad_state()
	return {
		"accepted": true,
		"reason": &"landing_pad_guides_bound",
		"loaded_scene_instance_id": _loaded_scene_instance_id,
		"guide_instance_id": batch.get_instance_id(),
	}

func apply_activity_snapshot(
		snapshot: Variant,
		optional_checkpoint: Variant = {},
		mandatory_route: Variant = {},
		committed_reward: Variant = {}
	) -> Dictionary:
	if not snapshot is Dictionary:
		return {"accepted": false, "reason": &"invalid_survey_snapshot"}
	var activity := snapshot as Dictionary
	var state := StringName(activity.get("state", &"idle"))
	if state not in [&"idle", &"ready", &"active", &"awaiting_reward", &"completed", &"failed", &"detached"]:
		return {"accepted": false, "reason": &"invalid_survey_state"}
	if not optional_checkpoint is Dictionary:
		return {"accepted": false, "reason": &"invalid_optional_checkpoint_snapshot"}
	if not mandatory_route is Dictionary:
		return {"accepted": false, "reason": &"invalid_mandatory_route_snapshot"}
	if not committed_reward is Dictionary:
		return {"accepted": false, "reason": &"invalid_reward_completion_receipt"}
	var checkpoint := optional_checkpoint as Dictionary
	if not checkpoint.is_empty() and (
			StringName(checkpoint.get("checkpoint_id", &"")) != &"ember_bunker_gantry_log" \
			or StringName(checkpoint.get("status", &"")) not in [&"inactive", &"available", &"completed"] \
			or checkpoint.get("completed") is not bool
	):
		return {"accepted": false, "reason": &"invalid_optional_checkpoint_snapshot"}
	var route := mandatory_route as Dictionary
	if not route.is_empty() and (
			StringName(route.get("activity_id", &"")) != &"ember_beacon_survey" \
			or int(route.get("activity_generation", -1)) < 1 \
			or int(route.get("checkpoint_count", -1)) != 2 \
			or int(route.get("next_checkpoint_index", -1)) < 0 \
			or int(route.get("next_checkpoint_index", -1)) > 2
	):
		return {"accepted": false, "reason": &"invalid_mandatory_route_snapshot"}
	var reward := committed_reward as Dictionary
	var reward_rejection := _reward_completion_receipt_rejection(activity, reward)
	if not reward_rejection.is_empty():
		return {"accepted": false, "reason": reward_rejection}
	_state = state
	_activity_generation = int(activity.get("activity_generation", -1))
	_optional_checkpoint = checkpoint.duplicate(true)
	_mandatory_route = route.duplicate(true)
	_committed_reward = reward.duplicate(true) if state == &"completed" else {}
	_attached = true
	_apply_state(state)
	return {"accepted": true, "reason": &"survey_presentation_applied", "state": _state}

func detach() -> Dictionary:
	_attached = false
	_relay_marker.visible = false
	_return_marker.visible = false
	_completion_seal.visible = false
	_apply_pad_guide_transforms(_pad_guide_neutral_transforms)
	_cue_mode = &"hidden"
	return {"accepted": true, "reason": &"survey_presentation_detached"}

func reenter(snapshot: Variant) -> Dictionary:
	return apply_activity_snapshot(snapshot)

func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"attached": _attached,
		"cue_mode": _cue_mode,
		"relay_anchor": RELAY_ANCHOR,
		"return_anchor": RETURN_ANCHOR,
		"relay_visible": _relay_marker.visible if _relay_marker != null else false,
		"return_visible": _return_marker.visible if _return_marker != null else false,
		"completion_visible": _completion_seal.visible if _completion_seal != null else false,
		"relay_silhouette": &"directional_pyramid",
		"return_silhouette": &"return_ring",
		"completion_silhouette": &"diamond_reward_seal",
		"route_direction": _route_direction_snapshot(),
		"mandatory_checkpoint_progress": _mandatory_checkpoint_progress_snapshot(),
		"landing_pad_survey_status": _landing_pad_survey_status_snapshot(),
		"completion_response": _completion_response_snapshot(),
		"reward_confirmation_persistent": true,
		"reward_receipt_verified": not _committed_reward.is_empty(),
		"hud": _checkpoint_hud_snapshot(),
		"reduced_flash_safe": true,
		"renderer_budget": {
			"mesh_instances": 3,
			"maximum_visible_submissions": 2,
			"materials": 1,
			"lights": 0,
			"runtime_node_allocations_after_ready": 0,
		},
		"authority": {
			"activity": false,
			"reward": false,
			"navigation": false,
			"collision": false,
			"flash_pulse": false,
		},
	}.duplicate(true)

func _apply_state(state: StringName) -> void:
	_relay_marker.position = RELAY_ANCHOR
	_relay_marker.scale = ACTIVE_SCALE
	_relay_marker.rotation = Vector3.ZERO
	_return_marker.scale = Vector3.ONE
	_completion_seal.scale = Vector3.ONE
	_relay_marker.visible = state in [&"ready", &"active"]
	_return_marker.visible = state in [&"awaiting_reward", &"completed"]
	_completion_seal.visible = state == &"completed"
	if state == &"ready":
		# A broad downward pointer reads as an approach gate from the pad route.
		_relay_marker.scale = APPROACH_SCALE
		_relay_marker.rotation = Vector3(0.0, 0.0, PI)
		_cue_mode = &"approach_relay"
	elif state == &"active":
		var next_index := int(_mandatory_route.get("next_checkpoint_index", 0))
		if next_index == 1:
			_return_marker.visible = true
			_return_marker.scale = CHECKPOINT_ONE_RING_SCALE
		if _return_direction_is_current():
			_relay_marker.position = RELAY_ANCHOR if next_index == 0 else RETURN_ANCHOR
			_relay_marker.scale = APPROACH_SCALE
			_relay_marker.rotation = Vector3(0.0, 0.0, PI)
			_cue_mode = &"bunker_return_to_relay" if next_index == 0 \
				else &"bunker_return_to_return"
		else:
			# Once the relay is accepted, its pyramid yields to the return ring.
			_relay_marker.visible = next_index == 0
			_cue_mode = &"active_relay" if next_index == 0 \
				else &"mandatory_return_checkpoint"
	elif state == &"awaiting_reward":
		# The existing ring expands as a static, shape-only route lock witness.
		_return_marker.scale = ROUTE_COMPLETE_RING_SCALE
		_cue_mode = &"return"
	elif state == &"completed":
		# The ring remains as the return landmark while its static diamond core
		# confirms that the authoritative reward handoff succeeded.
		_return_marker.scale = REWARD_CONFIRMED_RING_SCALE
		_completion_seal.scale = REWARD_CONFIRMED_SEAL_SCALE
		_cue_mode = &"reward_confirmed"
	else:
		_cue_mode = &"hidden"
	_apply_landing_pad_state()


func _apply_landing_pad_state() -> void:
	var transforms: Array[Transform3D] = _pad_guide_neutral_transforms.duplicate()
	if transforms.size() != 2:
		return
	if _attached and _state == &"ready":
		var port_available: Transform3D = transforms[0]
		port_available.basis = Basis(Vector3.RIGHT, PAD_AVAILABLE_TILT_RADIANS).scaled(
			PAD_AVAILABLE_SCALE
		)
		transforms[0] = port_available
		var starboard_available: Transform3D = transforms[1]
		starboard_available.basis = Basis(Vector3.RIGHT, -PAD_AVAILABLE_TILT_RADIANS).scaled(
			PAD_AVAILABLE_SCALE
		)
		transforms[1] = starboard_available
	elif _attached and _state in [&"awaiting_reward", &"completed"]:
		var port_complete: Transform3D = transforms[0]
		port_complete.basis = Basis(Vector3.RIGHT, PAD_COMPLETE_TILT_RADIANS)
		transforms[0] = port_complete
		var starboard_complete: Transform3D = transforms[1]
		starboard_complete.basis = Basis(Vector3.RIGHT, -PAD_COMPLETE_TILT_RADIANS)
		transforms[1] = starboard_complete
	_apply_pad_guide_transforms(transforms)


func _apply_pad_guide_transforms(transforms: Array[Transform3D]) -> void:
	var guides := _resolve_pad_guides()
	if guides == null or guides.multimesh == null or transforms.size() != 2:
		return
	for index in transforms.size():
		guides.multimesh.set_instance_transform(index, transforms[index])
	_pad_guide_applied_transforms = transforms.duplicate()
	# RenderingServer readback can return identity in headless mode. Retain the
	# exact applied recipe beside the authored baseline for detached inspection.
	guides.set_meta("survey_presentation_transforms", transforms.duplicate())


func _resolve_pad_guides() -> MultiMeshInstance3D:
	if _pad_guides_ref == null:
		return null
	var candidate: Variant = _pad_guides_ref.get_ref()
	if not is_instance_valid(candidate) or not candidate is MultiMeshInstance3D:
		return null
	return candidate as MultiMeshInstance3D


func _landing_pad_survey_status_snapshot() -> Dictionary:
	var guides := _resolve_pad_guides()
	var status: StringName = &"neutral"
	var silhouette: StringName = &"upright_pair"
	if _attached and _state == &"ready":
		status = &"survey_available"
		silhouette = &"inward_canted_tall_pair"
	elif _attached and _state == &"active":
		status = &"survey_in_progress"
	elif _attached and _state in [&"awaiting_reward", &"completed"]:
		status = &"completed_return"
		silhouette = &"lowered_horizontal_pair"
	elif not _attached:
		status = &"detached"
	return {
		"visible": _attached and guides != null,
		"state": status,
		"silhouette": silhouette,
		"color_independent": true,
		"reused_node": &"PadGuideVisuals",
		"loaded_scene_instance_id": _loaded_scene_instance_id,
		"guide_instance_id": guides.get_instance_id() if guides != null else 0,
		"instance_count": 2 if guides != null else 0,
		"transforms": _pad_guide_applied_transforms.duplicate(),
		"incremental_budget": {
			"nodes": 0, "multimeshes": 0, "mesh_instances": 0,
			"materials": 0, "triangles": 0,
		},
		"authority": {
			"activity": false, "checkpoint": false, "reward": false,
			"navigation": false, "movement": false, "collision": false,
		},
	}.duplicate(true)


func _return_direction_is_current() -> bool:
	if not bool(_optional_checkpoint.get("completed", false)):
		return false
	var next_index := int(_mandatory_route.get("next_checkpoint_index", -1))
	return next_index in [0, 1] \
		and int(_mandatory_route.get("activity_generation", -1)) \
			== int(_optional_checkpoint.get("activity_generation", -2))


func _route_direction_snapshot() -> Dictionary:
	var active := _attached and _state == &"active" and _return_direction_is_current()
	var next_index := int(_mandatory_route.get("next_checkpoint_index", -1))
	var target_id: StringName = &""
	var target_anchor := Vector3.ZERO
	if active and next_index == 0:
		target_id = &"ember_relay_tower"
		target_anchor = RELAY_ANCHOR
	elif active and next_index == 1:
		target_id = &"ember_return_beacon"
		target_anchor = RETURN_ANCHOR
	return {
		"active": active,
		"mode": _cue_mode if active else &"hidden",
		"target_id": target_id,
		"target_anchor": target_anchor,
		"next_checkpoint_index": next_index,
		"activity_generation": int(_mandatory_route.get("activity_generation", -1)),
		"silhouette": &"broad_downward_pyramid",
		"color_independent": true,
		"reused_marker": &"OwnedRelaySurveyMarker",
		"incremental_budget": {
			"nodes": 0, "mesh_instances": 0, "materials": 0,
			"triangles": 0, "maximum_visible_submissions": 1,
		},
		"authority": {"navigation": false, "movement": false, "reward": false},
	}.duplicate(true)


func _mandatory_checkpoint_progress_snapshot() -> Dictionary:
	var next_index := int(_mandatory_route.get("next_checkpoint_index", -1))
	var retained_count := clampi(next_index, 0, 2) if next_index >= 0 else 0
	var visible := _attached and _state in [
		&"active", &"awaiting_reward", &"completed",
	]
	var progress_state: StringName = &"hidden"
	var silhouette: StringName = &"none"
	if visible and _state == &"active" and next_index == 0:
		progress_state = &"relay_checkpoint_pending"
		silhouette = &"single_directional_pyramid"
	elif visible and _state == &"active" and next_index == 1:
		progress_state = &"relay_reached_return_pending"
		silhouette = &"vertical_oval_return_ring"
	elif visible and _state == &"awaiting_reward":
		progress_state = &"mandatory_route_complete"
		silhouette = &"expanded_return_ring"
	elif visible and _state == &"completed":
		progress_state = &"reward_confirmed"
		silhouette = &"return_ring_and_diamond"
	return {
		"visible": visible,
		"state": progress_state,
		"completed_checkpoint_count": retained_count,
		"checkpoint_count": 2,
		"progress_text": "%d / 2 MANDATORY" % retained_count,
		"next_checkpoint_index": next_index,
		"activity_generation": int(_mandatory_route.get("activity_generation", -1)),
		"silhouette": silhouette,
		"color_independent": true,
		"relay_marker_visible": _relay_marker.visible if _relay_marker != null else false,
		"return_marker_visible": _return_marker.visible if _return_marker != null else false,
		"return_marker_scale": _return_marker.scale if _return_marker != null else Vector3.ONE,
		"optional_pointer_preserved": _return_direction_is_current(),
		"incremental_budget": {
			"nodes": 0, "mesh_instances": 0, "materials": 0,
			"triangles": 0, "maximum_visible_submissions": 2,
		},
		"authority": {
			"activity": false, "reward": false, "navigation": false,
			"movement": false, "checkpoint": false,
		},
	}.duplicate(true)


func _completion_response_snapshot() -> Dictionary:
	var visible := _attached and _state in [&"awaiting_reward", &"completed"]
	var response_state: StringName = &"hidden"
	var status_text := ""
	var silhouette: StringName = &"none"
	if visible and _state == &"awaiting_reward":
		response_state = &"route_complete_pending_reward"
		status_text = "Survey route locked — return data ready"
		silhouette = &"expanded_return_ring"
	elif visible and _state == &"completed":
		response_state = &"reward_confirmed"
		status_text = "Survey data accepted"
		silhouette = &"ring_and_inset_diamond"
	return {
		"visible": visible,
		"state": response_state,
		"status_text": status_text,
		"anchor": RETURN_ANCHOR,
		"activity_generation": _activity_generation,
		"route_complete": _state in [&"awaiting_reward", &"completed"],
		"reward_committed": _state == &"completed",
		"reward_id": _committed_reward.get("reward_id", &""),
		"receipt_verified": not _committed_reward.is_empty(),
		"silhouette": silhouette,
		"color_independent": true,
		"ring_scale": _return_marker.scale if _return_marker != null else Vector3.ONE,
		"seal_scale": _completion_seal.scale if _completion_seal != null else Vector3.ONE,
		"reused_nodes": PackedStringArray([
			"OwnedReturnSurveyMarker", "OwnedRewardCompletionSeal",
		]),
		"incremental_budget": {
			"nodes": 0, "mesh_instances": 0, "materials": 0,
			"triangles": 0, "lights": 0,
		},
		"authority": {
			"activity": false, "reward": false, "movement": false,
			"navigation": false, "audio": false,
		},
	}.duplicate(true)


func _reward_completion_receipt_rejection(
		activity: Dictionary, receipt: Dictionary
	) -> StringName:
	var state := StringName(activity.get("state", &"idle"))
	if state != &"completed":
		return &"unexpected_reward_completion_receipt" if not receipt.is_empty() else &""
	var authority_result := receipt.get("authority_result", {}) as Dictionary
	if receipt.is_empty() \
			or StringName(activity.get("activity_id", &"")) != SURVEY_ACTIVITY_ID \
			or StringName(receipt.get("world_id", &"")) != &"ember_moon" \
			or StringName(receipt.get("activity_id", &"")) != SURVEY_ACTIVITY_ID \
			or StringName(receipt.get("reward_id", &"")) != SURVEY_REWARD_ID \
			or StringName(receipt.get("reward_store_id", &"")) != REWARD_STORE_ID \
			or StringName(receipt.get("reward_authority_id", &"")) != REWARD_AUTHORITY_ID \
			or int(receipt.get("activity_generation", -1)) < 1 \
			or int(receipt.get("activity_generation", -2)) != int(activity.get("activity_generation", -1)) \
			or int(receipt.get("run_generation", -1)) < 1 \
			or int(receipt.get("attachment_generation", -1)) < 1 \
			or not bool(authority_result.get("accepted", false)):
		return &"invalid_reward_completion_receipt"
	return &""


func _checkpoint_hud_snapshot() -> Dictionary:
	var completed := bool(_optional_checkpoint.get("completed", false))
	var activity_visible := _state in [&"active", &"awaiting_reward", &"completed"]
	return {
		"visible": _attached and activity_visible and not _optional_checkpoint.is_empty(),
		"title": "RELAY SURVEY — OPTIONAL CHECKPOINT",
		"progress_text": _optional_checkpoint.get(
			"progress_text", "OPTIONAL BUNKER LOG  0 / 1"
		),
		"status_text": _optional_checkpoint.get(
			"status_text", "Optional log inactive"
		),
		"checkpoint_id": _optional_checkpoint.get("checkpoint_id", &""),
		"completed": completed,
		"optional": true,
		"color_independent": true,
		"historical_claim": false,
		"interpretation_status": &"modern_interpretation",
		"authority": {"activity": false, "reward": false, "hud_core": false},
	}.duplicate(true)


func _make_relay_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = &"OwnedRelaySurveyMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 2.0
	mesh.height = 7.2
	mesh.radial_segments = 4
	marker.mesh = mesh
	marker.position = RELAY_ANCHOR
	marker.material_override = _marker_material
	marker.set_instance_shader_parameter(&"marker_emission", RELAY_COLOR)
	marker.visible = false
	return marker


func _make_return_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = &"OwnedReturnSurveyMarker"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 2.4
	mesh.outer_radius = 3.5
	mesh.rings = 20
	mesh.ring_segments = 6
	marker.mesh = mesh
	marker.position = RETURN_ANCHOR
	marker.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	marker.material_override = _marker_material
	marker.set_instance_shader_parameter(&"marker_emission", RETURN_COLOR)
	marker.visible = false
	return marker


func _make_completion_seal() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = &"OwnedRewardCompletionSeal"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.4, 3.4, 0.55)
	marker.mesh = mesh
	marker.position = RETURN_ANCHOR
	marker.rotation = Vector3(0.0, 0.0, PI * 0.25)
	marker.material_override = _marker_material
	marker.set_instance_shader_parameter(&"marker_emission", COMPLETION_COLOR)
	marker.visible = false
	return marker


func _make_marker_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = MARKER_SHADER_SOURCE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"emission_energy", EMISSION_ENERGY)
	return material
