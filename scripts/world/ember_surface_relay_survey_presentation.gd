class_name EmberSurfaceRelaySurveyPresentation
extends Node3D

## Presentation-only Ember survey route cues. The authored pad guide posts,
## sample rack, relay and route remain the physical context; these two safe
## objective renderers consume detached adapter state and never pulse.

const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)
const APPROACH_SCALE := Vector3(1.35, 0.55, 1.35)
const ACTIVE_SCALE := Vector3.ONE
const RELAY_COLOR := Color(0.2, 0.7, 1.0, 1.0)
const RETURN_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const EMISSION_ENERGY := 0.55

var _relay_marker: MeshInstance3D
var _return_marker: MeshInstance3D
var _state: StringName = &"idle"
var _cue_mode: StringName = &"hidden"

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_relay_marker = _make_relay_marker()
	_return_marker = _make_return_marker()
	add_child(_relay_marker)
	add_child(_return_marker)
	_apply_state(&"idle")

func apply_activity_snapshot(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return {"accepted": false, "reason": &"invalid_survey_snapshot"}
	var activity := snapshot as Dictionary
	var state := StringName(activity.get("state", &"idle"))
	if state not in [&"idle", &"ready", &"active", &"awaiting_reward", &"completed", &"failed", &"detached"]:
		return {"accepted": false, "reason": &"invalid_survey_state"}
	_state = state
	_apply_state(state)
	return {"accepted": true, "reason": &"survey_presentation_applied", "state": _state}

func detach() -> Dictionary:
	_relay_marker.visible = false
	_return_marker.visible = false
	_cue_mode = &"hidden"
	return {"accepted": true, "reason": &"survey_presentation_detached"}

func reenter(snapshot: Variant) -> Dictionary:
	return apply_activity_snapshot(snapshot)

func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"cue_mode": _cue_mode,
		"relay_anchor": RELAY_ANCHOR,
		"return_anchor": RETURN_ANCHOR,
		"relay_visible": _relay_marker.visible if _relay_marker != null else false,
		"return_visible": _return_marker.visible if _return_marker != null else false,
		"relay_silhouette": &"directional_pyramid",
		"return_silhouette": &"return_ring",
		"reduced_flash_safe": true,
		"renderer_budget": {
			"mesh_instances": 2,
			"maximum_visible_submissions": 1,
			"materials": 2,
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
	_relay_marker.visible = state in [&"ready", &"active"]
	_return_marker.visible = state in [&"awaiting_reward", &"completed"]
	if state == &"ready":
		# A broad downward pointer reads as an approach gate from the pad route.
		_relay_marker.scale = APPROACH_SCALE
		_relay_marker.rotation = Vector3(0.0, 0.0, PI)
		_cue_mode = &"approach_relay"
	elif state == &"active":
		# The same preallocated mesh becomes an upright next-landmark pointer.
		_relay_marker.scale = ACTIVE_SCALE
		_relay_marker.rotation = Vector3.ZERO
		_cue_mode = &"active_relay"
	elif state in [&"awaiting_reward", &"completed"]:
		_cue_mode = &"return"
	else:
		_cue_mode = &"hidden"


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


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = EMISSION_ENERGY
	return material
