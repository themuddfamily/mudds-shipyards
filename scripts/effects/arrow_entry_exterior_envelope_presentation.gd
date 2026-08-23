class_name ArrowEntryExteriorEnvelopePresentation
extends Node3D

## Ship-local chase-camera repeater for Arrow's retained entry envelope.
## The caller supplies the already-presented cockpit envelope; this component
## only renders its bounded segment count and never samples or owns gameplay.

const COMPONENT_ID: StringName = &"arrow-entry-exterior-envelope-presentation"
const SEGMENT_COUNT := 5
const RECOVERY_HOLD_OBSERVATIONS := 90
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const ATMOSPHERIC_COLOR := Color(1.0, 0.28, 0.055, 0.9)
const AIRLESS_COLOR := Color(0.35, 0.9, 1.0, 0.86)
const RECOVERY_COLOR := Color(0.7, 1.0, 0.9, 0.88)

var _segments: MultiMeshInstance3D
var _recovery_ring: MeshInstance3D
var _marker: Label3D
var _segment_material: StandardMaterial3D
var _recovery_material: StandardMaterial3D
var _generation := 0
var _last_observation_serial := -1
var _observation_count := 0
var _visible_segment_count := 0
var _visual_intensity_scale := 0.0
var _recovery_samples_remaining := 0
var _last_snapshot: Dictionary = {}


func _ready() -> void:
	if _generation == 0:
		_generation = 1
	_build_visuals()
	_clear_visuals(&"ready")
	set_meta("presentation_only", true)
	set_meta("chase_camera_repeater", true)


func _exit_tree() -> void:
	_clear_visuals(&"detached")
	_last_observation_serial = -1
	_recovery_samples_remaining = 0
	if _generation < MAX_SAFE_GENERATION:
		_generation += 1


func present_envelope(
		cockpit_snapshot: Dictionary, branch_id: StringName,
		reduced_flash: bool, reduced_motion: bool, observation_serial: int,
		expected_generation: int
	) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if observation_serial < 1 or observation_serial > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_observation_serial")
	if _last_observation_serial >= 0 \
			and observation_serial != _last_observation_serial + 1:
		return _result(
			false,
			&"observation_serial_replayed" \
				if observation_serial <= _last_observation_serial \
				else &"observation_serial_skipped",
		)
	if branch_id not in [&"atmospheric", &"airless"]:
		return _result(false, &"invalid_branch")
	var gauge := cockpit_snapshot.get("envelope_gauge", {}) as Dictionary
	if int(gauge.get("segment_count", -1)) != SEGMENT_COUNT:
		return _result(false, &"cockpit_envelope_contract_missing")
	var level := int(gauge.get("filled_segments", -1))
	if level < 0 or level > SEGMENT_COUNT:
		return _result(false, &"cockpit_envelope_out_of_bounds")
	if bool(gauge.get("recovery", false)):
		_recovery_samples_remaining = RECOVERY_HOLD_OBSERVATIONS
	elif level >= 3:
		_recovery_samples_remaining = 0
	var recovery := _recovery_samples_remaining > 0 and level < 3
	_apply_visuals(level, recovery, branch_id, reduced_flash)
	if _recovery_samples_remaining > 0:
		_recovery_samples_remaining -= 1
	_last_observation_serial = observation_serial
	_observation_count += 1
	_last_snapshot = {
		"branch_id": branch_id,
		"visible": visible,
		"visible_segment_count": _visible_segment_count,
		"visual_intensity_scale": _visual_intensity_scale,
		"segment_count": SEGMENT_COUNT,
		"bounded": _visible_segment_count >= 0 \
			and _visible_segment_count <= SEGMENT_COUNT,
		"recovery": recovery,
		"recovery_samples_remaining": _recovery_samples_remaining,
		"marker_text": _marker.text,
		"recovery_ring_visible": _recovery_ring.visible,
		"reduced_flash": reduced_flash,
		"reduced_motion": reduced_motion,
		"steady": true,
		"color_independent": true,
	}.duplicate(true)
	return _result(true, &"exterior_envelope_presented")


func clear(reason: StringName, expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_clear_visuals(reason)
	_last_observation_serial = -1
	_recovery_samples_remaining = 0
	_generation += 1
	return _result(true, reason)


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	var snapshot := {
		"component_id": COMPONENT_ID,
		"generation": _generation,
		"last_observation_serial": _last_observation_serial,
		"observation_count": _observation_count,
		"visible": visible,
		"visible_segment_count": _visible_segment_count,
		"visual_intensity_scale": _visual_intensity_scale,
		"segment_count": SEGMENT_COUNT,
		"node_budget": {
			"total_nodes": 4,
			"renderer_nodes": 2,
			"label_nodes": 1,
			"particle_nodes": 0,
			"light_nodes": 0,
			"process_loops": 0,
		}.duplicate(true),
		"resource_budget": {
			"mesh_resources": 2,
			"material_resources": 2,
			"multimesh_resources": 1,
		}.duplicate(true),
		"ship_local": true,
		"chase_camera_repeater": true,
		"presentation_only": true,
		"collision_authority": false,
		"physics_authority": false,
		"movement_authority": false,
		"damage_authority": false,
		"atmosphere_authority": false,
		"landing_authority": false,
		"audio_authority": false,
	}
	for key: Variant in _last_snapshot:
		snapshot[key] = _last_snapshot[key]
	return snapshot.duplicate(true)


func _build_visuals() -> void:
	if _segments != null:
		return
	_segment_material = _material(ATMOSPHERIC_COLOR)
	var segment_mesh := BoxMesh.new()
	segment_mesh.size = Vector3(0.38, 1.25, 0.22)
	segment_mesh.material = _segment_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = SEGMENT_COUNT
	multimesh.visible_instance_count = 0
	multimesh.mesh = segment_mesh
	var offsets := PackedFloat32Array([0.0, -1.05, 1.05, -2.1, 2.1])
	for index in SEGMENT_COUNT:
		var lateral := offsets[index]
		multimesh.set_instance_transform(
			index,
			Transform3D(
				Basis.from_euler(Vector3(0.0, 0.0, lateral * -0.08)),
				Vector3(lateral, 4.25 - absf(lateral) * 0.16, 4.75),
			)
		)
	_segments = MultiMeshInstance3D.new()
	_segments.name = "EnvelopeSegments"
	_segments.multimesh = multimesh
	_segments.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_segments.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_segments)

	_recovery_material = _material(RECOVERY_COLOR)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.88
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	ring_mesh.material = _recovery_material
	_recovery_ring = MeshInstance3D.new()
	_recovery_ring.name = "RecoveryRing"
	_recovery_ring.position = Vector3(0.0, 2.35, 4.65)
	_recovery_ring.rotation_degrees.x = 90.0
	_recovery_ring.scale = Vector3(3.15, 1.0, 1.55)
	_recovery_ring.mesh = ring_mesh
	_recovery_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_recovery_ring.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_recovery_ring)

	_marker = Label3D.new()
	_marker.name = "EnvelopeMarker"
	_marker.position = Vector3(0.0, 5.35, 4.65)
	_marker.font_size = 48
	_marker.pixel_size = 0.012
	_marker.outline_size = 9
	_marker.outline_modulate = Color("07111d")
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	add_child(_marker)


func _apply_visuals(
		level: int, recovery: bool, branch_id: StringName, reduced_flash: bool
	) -> void:
	_visible_segment_count = clampi(level, 0, SEGMENT_COUNT)
	_segments.multimesh.visible_instance_count = _visible_segment_count
	_recovery_ring.visible = recovery
	visible = _visible_segment_count > 0 or recovery
	var base_color := ATMOSPHERIC_COLOR \
		if branch_id == &"atmospheric" else AIRLESS_COLOR
	var alpha_scale := 0.58 if reduced_flash else 1.0
	_visual_intensity_scale = alpha_scale
	var segment_color := base_color
	segment_color.a *= alpha_scale
	_segment_material.albedo_color = segment_color
	_segment_material.emission = Color(base_color.r, base_color.g, base_color.b)
	_segment_material.emission_energy_multiplier = 1.15 if reduced_flash else 2.6
	var recovery_color := RECOVERY_COLOR
	recovery_color.a *= alpha_scale
	_recovery_material.albedo_color = recovery_color
	_recovery_material.emission_energy_multiplier = 0.9 if reduced_flash else 1.8
	_marker.modulate = recovery_color if recovery else segment_color
	if recovery:
		_marker.text = "ENTRY RECOVER %d/%d" % [_visible_segment_count, SEGMENT_COUNT]
	elif branch_id == &"atmospheric":
		_marker.text = "ATM ENTRY %d/%d" % [_visible_segment_count, SEGMENT_COUNT]
	else:
		_marker.text = "AIRLESS SINK %d/%d" % [_visible_segment_count, SEGMENT_COUNT]
	_marker.visible = visible


func _clear_visuals(reason: StringName) -> void:
	_visible_segment_count = 0
	_visual_intensity_scale = 0.0
	visible = false
	if _segments != null:
		_segments.multimesh.visible_instance_count = 0
	if _recovery_ring != null:
		_recovery_ring.visible = false
	if _marker != null:
		_marker.visible = false
		_marker.text = ""
	_last_snapshot = {
		"visible": false,
		"visible_segment_count": 0,
		"visual_intensity_scale": 0.0,
		"segment_count": SEGMENT_COUNT,
		"bounded": true,
		"recovery": false,
		"recovery_samples_remaining": 0,
		"marker_text": "",
		"recovery_ring_visible": false,
		"steady": true,
		"color_independent": true,
		"reason": reason,
	}.duplicate(true)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.0
	return material


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"snapshot": get_snapshot(),
		"presentation_only": true,
		"physics_authority": false,
		"movement_authority": false,
		"damage_authority": false,
		"landing_authority": false,
		"audio_authority": false,
	}.duplicate(true)
