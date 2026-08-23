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
const RELAY_COLOR := Color(0.2, 0.7, 1.0, 1.0)
const RETURN_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const COMPLETION_COLOR := Color(0.95, 0.82, 0.25, 1.0)
const EMISSION_ENERGY := 0.55

var _relay_marker: MeshInstance3D
var _return_marker: MeshInstance3D
var _completion_seal: MeshInstance3D
var _state: StringName = &"idle"
var _cue_mode: StringName = &"hidden"
var _optional_checkpoint: Dictionary = {}
var _mandatory_route: Dictionary = {}
var _attached := true

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_relay_marker = _make_relay_marker()
	_return_marker = _make_return_marker()
	_completion_seal = _make_completion_seal()
	add_child(_relay_marker)
	add_child(_return_marker)
	add_child(_completion_seal)
	_apply_state(&"idle")

func apply_activity_snapshot(
		snapshot: Variant,
		optional_checkpoint: Variant = {},
		mandatory_route: Variant = {}
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
	_state = state
	_optional_checkpoint = checkpoint.duplicate(true)
	_mandatory_route = route.duplicate(true)
	_attached = true
	_apply_state(state)
	return {"accepted": true, "reason": &"survey_presentation_applied", "state": _state}

func detach() -> Dictionary:
	_attached = false
	_relay_marker.visible = false
	_return_marker.visible = false
	_completion_seal.visible = false
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
		"reward_confirmation_persistent": true,
		"hud": _checkpoint_hud_snapshot(),
		"reduced_flash_safe": true,
		"renderer_budget": {
			"mesh_instances": 3,
			"maximum_visible_submissions": 2,
			"materials": 3,
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
	_relay_marker.visible = state in [&"ready", &"active"]
	_return_marker.visible = state in [&"awaiting_reward", &"completed"]
	_completion_seal.visible = state == &"completed"
	if state == &"ready":
		# A broad downward pointer reads as an approach gate from the pad route.
		_relay_marker.scale = APPROACH_SCALE
		_relay_marker.rotation = Vector3(0.0, 0.0, PI)
		_cue_mode = &"approach_relay"
	elif state == &"active":
		if _return_direction_is_current():
			var next_index := int(_mandatory_route.get("next_checkpoint_index", -1))
			_relay_marker.position = RELAY_ANCHOR if next_index == 0 else RETURN_ANCHOR
			_relay_marker.scale = APPROACH_SCALE
			_relay_marker.rotation = Vector3(0.0, 0.0, PI)
			_cue_mode = &"bunker_return_to_relay" if next_index == 0 \
				else &"bunker_return_to_return"
		else:
			# The same preallocated mesh remains the standard route pointer.
			_relay_marker.scale = ACTIVE_SCALE
			_relay_marker.rotation = Vector3.ZERO
			_cue_mode = &"active_relay"
	elif state == &"awaiting_reward":
		_cue_mode = &"return"
	elif state == &"completed":
		# The ring remains as the return landmark while its static diamond core
		# confirms that the authoritative reward handoff succeeded.
		_cue_mode = &"reward_confirmed"
	else:
		_cue_mode = &"hidden"


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
	mesh.bottom_radius = 2.2
	mesh.height = 6.0
	mesh.radial_segments = 4
	marker.mesh = mesh
	marker.position = RELAY_ANCHOR
	marker.material_override = _make_material(RELAY_COLOR)
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
	marker.material_override = _make_material(RETURN_COLOR)
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
	marker.material_override = _make_material(COMPLETION_COLOR)
	marker.visible = false
	return marker


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = EMISSION_ENERGY
	return material
