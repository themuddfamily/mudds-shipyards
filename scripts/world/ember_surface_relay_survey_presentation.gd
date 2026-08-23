class_name EmberSurfaceRelaySurveyPresentation
extends Node3D

## Presentation-only active survey objective. Activity/reward/navigation owners
## remain external; this target consumes detached adapter state and never pulses.

const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)
var _relay_marker: MeshInstance3D
var _return_marker: MeshInstance3D
var _state: StringName = &"idle"

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_relay_marker = _make_marker(&"OwnedRelaySurveyMarker", RELAY_ANCHOR, Color(0.2, 0.7, 1.0, 1.0))
	_return_marker = _make_marker(&"OwnedReturnSurveyMarker", RETURN_ANCHOR, Color(1.0, 0.55, 0.15, 1.0))
	add_child(_relay_marker)
	add_child(_return_marker)

func apply_activity_snapshot(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return {"accepted": false, "reason": &"invalid_survey_snapshot"}
	var activity := snapshot as Dictionary
	var state := StringName(activity.get("state", &"idle"))
	if state not in [&"idle", &"ready", &"active", &"awaiting_reward", &"completed", &"failed", &"detached"]:
		return {"accepted": false, "reason": &"invalid_survey_state"}
	_state = state
	_relay_marker.visible = state in [&"active", &"awaiting_reward"]
	_return_marker.visible = state in [&"awaiting_reward", &"completed"]
	return {"accepted": true, "reason": &"survey_presentation_applied", "state": _state}

func detach() -> Dictionary:
	_relay_marker.visible = false
	_return_marker.visible = false
	return {"accepted": true, "reason": &"survey_presentation_detached"}

func reenter(snapshot: Variant) -> Dictionary:
	return apply_activity_snapshot(snapshot)

func get_snapshot() -> Dictionary:
	return {"state": _state, "relay_anchor": RELAY_ANCHOR, "return_anchor": RETURN_ANCHOR, "relay_visible": _relay_marker.visible if _relay_marker != null else false, "return_visible": _return_marker.visible if _return_marker != null else false, "authority": {"activity": false, "reward": false, "navigation": false, "collision": false, "flash_pulse": false}}.duplicate(true)

func _make_marker(marker_name: StringName, anchor: Vector3, color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	marker.mesh = mesh
	marker.position = anchor
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	marker.material_override = material
	marker.visible = false
	return marker
