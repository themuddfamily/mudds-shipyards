class_name EmberSurfaceHazardZonePresentation
extends Node3D

## Presentation-only perimeter for one authored Ember surface hazard.
## Caller observations select semantic state; this node owns no actor sampling,
## damage, movement, recovery, reward, HUD, or lifecycle authority.

var _configured := false
var _attached := false
var _hazard_id: StringName = &""
var _display_name := ""
var _anchor := Vector3.ZERO
var _radius_m := 0.0
var _state: StringName = &"clear"
var _recovery_landmark_id: StringName = &""
var _recovery_target := Vector3.ZERO
var _recovery_path_start := Vector3.ZERO
var _recovery_direction := Vector3.ZERO
var _active_recovery_generation := 0
var _retired_recovery_generation := 0
var _ring: MeshInstance3D
var _beacon: MeshInstance3D
var _material: StandardMaterial3D
var _recovery_cue_root: Node3D
var _recovery_cue_material: StandardMaterial3D

const RECOVERY_CUE_DASH_COUNT := 4
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const BEACON_HALF_HEIGHT_M := 1.2
const SAFE_BEACON_SCALE := Vector3(1.35, 0.24, 1.35)
const WARNING_BEACON_SCALE := Vector3.ONE
const RECOVERY_BEACON_SCALE := Vector3(0.72, 1.35, 0.72)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_ring = MeshInstance3D.new()
	_ring.name = "OwnedHazardPerimeter"
	_ring.material_override = _material
	add_child(_ring)
	_beacon = MeshInstance3D.new()
	_beacon.name = "OwnedHazardBeacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.18
	beacon_mesh.bottom_radius = 0.45
	beacon_mesh.height = 2.4
	_beacon.mesh = beacon_mesh
	_beacon.position = Vector3(0.0, 1.2, 0.0)
	_beacon.material_override = _material
	add_child(_beacon)
	_recovery_cue_material = StandardMaterial3D.new()
	_recovery_cue_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_recovery_cue_material.emission_enabled = true
	_recovery_cue_material.albedo_color = Color(0.92, 0.96, 1.0, 1.0)
	_recovery_cue_material.emission = Color(0.72, 0.88, 1.0)
	_recovery_cue_material.emission_energy_multiplier = 1.8
	_recovery_cue_root = Node3D.new()
	_recovery_cue_root.name = "OwnedStaticRecoveryDirectionCue"
	add_child(_recovery_cue_root)
	_set_visible(false)


func configure(hazard: Variant, radius_m: float) -> Dictionary:
	if _configured or not hazard is Dictionary or not is_finite(radius_m) \
			or radius_m <= 0.0:
		return {"accepted": false, "reason": &"invalid_hazard_zone_configuration"}
	var record := hazard as Dictionary
	var hazard_id := StringName(record.get("id", &""))
	var display_name := String(record.get("display_name", ""))
	var anchor: Variant = record.get("position_body_local_m", Vector3.INF)
	if hazard_id.is_empty() or display_name.is_empty() or not anchor is Vector3 \
			or not (anchor as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_hazard_zone_configuration"}
	_hazard_id = hazard_id
	_display_name = display_name
	_anchor = anchor as Vector3
	_radius_m = radius_m
	position = _anchor
	var perimeter := TorusMesh.new()
	perimeter.inner_radius = maxf(0.1, radius_m - 0.28)
	perimeter.outer_radius = radius_m
	_ring.mesh = perimeter
	_configured = true
	_attached = true
	_apply_state(&"clear")
	return {"accepted": true, "reason": &"hazard_zone_configured"}


func configure_recovery_target(landmark: Variant) -> Dictionary:
	if not _configured or not landmark is Dictionary or not _recovery_landmark_id.is_empty():
		return {"accepted": false, "reason": &"invalid_recovery_target_configuration"}
	var record := landmark as Dictionary
	var landmark_id := StringName(record.get("id", &""))
	var target: Variant = record.get("position_body_local_m", Vector3.INF)
	if landmark_id.is_empty() or not target is Vector3 or not (target as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_recovery_target_configuration"}
	var target_position := target as Vector3
	var target_offset := target_position - _anchor
	if target_offset.is_zero_approx():
		return {"accepted": false, "reason": &"invalid_recovery_target_configuration"}
	var path_start := _anchor + target_offset.normalized() * _radius_m
	var path := target_position - path_start
	if path.is_zero_approx():
		return {"accepted": false, "reason": &"invalid_recovery_target_configuration"}
	_recovery_landmark_id = landmark_id
	_recovery_target = target_position
	_recovery_path_start = path_start
	_recovery_direction = path.normalized()
	_build_recovery_cue(path.length())
	_set_recovery_cue_visible(false)
	return {"accepted": true, "reason": &"recovery_target_configured"}


func apply_status(status: Variant) -> Dictionary:
	if not _configured or not status is Dictionary:
		return {"accepted": false, "reason": &"invalid_hazard_zone_status"}
	var semantic := status as Dictionary
	if StringName(semantic.get("hazard_id", &"")) != _hazard_id:
		return {"accepted": false, "reason": &"hazard_zone_identity_mismatch"}
	var state := StringName(semantic.get("state", &""))
	if state not in [&"clear", &"warning", &"recovery_required"]:
		return {"accepted": false, "reason": &"invalid_hazard_zone_status"}
	var recovery_value: Variant = semantic.get("recovery_request", {})
	if not recovery_value is Dictionary:
		return {"accepted": false, "reason": &"invalid_hazard_recovery_generation"}
	var recovery := recovery_value as Dictionary
	var generation_value: Variant = recovery.get("generation", 0)
	if not generation_value is int or int(generation_value) < 0 \
			or int(generation_value) > MAX_SAFE_INTEGER:
		return {"accepted": false, "reason": &"invalid_hazard_recovery_generation"}
	var recovery_generation := int(generation_value)
	if state == &"recovery_required" and recovery_generation > 0:
		if recovery_generation <= _retired_recovery_generation \
				or recovery_generation < _active_recovery_generation:
			return {"accepted": false, "reason": &"stale_hazard_recovery_generation"}
		_active_recovery_generation = recovery_generation
	elif state == &"clear":
		if recovery_generation > 0 and _active_recovery_generation > 0 \
				and recovery_generation < _active_recovery_generation:
			return {"accepted": false, "reason": &"stale_hazard_recovery_generation"}
		_retire_active_recovery()
	elif _active_recovery_generation > 0 \
			and (recovery_generation == 0 \
			or recovery_generation <= _active_recovery_generation):
		return {"accepted": false, "reason": &"stale_hazard_recovery_generation"}
	_apply_state(state)
	return {"accepted": true, "reason": &"hazard_zone_status_applied"}


func detach() -> Dictionary:
	if not _configured or not _attached:
		return {"accepted": false, "reason": &"hazard_zone_not_attached"}
	_attached = false
	_retire_active_recovery()
	_state = &"clear"
	_set_visible(false)
	return {"accepted": true, "reason": &"hazard_zone_detached"}


func reenter() -> Dictionary:
	if not _configured or _attached:
		return {"accepted": false, "reason": &"hazard_zone_reentry_unavailable"}
	_attached = true
	_apply_state(&"clear")
	return {"accepted": true, "reason": &"hazard_zone_reentered"}


func get_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"attached": _attached,
		"hazard_id": _hazard_id,
		"display_name": _display_name,
		"anchor_body_local_m": _anchor,
		"radius_m": _radius_m,
		"state": _state,
		"state_shape": _state_shape(_state),
		"visible": _attached and _ring != null and _ring.visible,
		"recovery_cue": {
			"configured": not _recovery_landmark_id.is_empty(),
			"visible": _recovery_cue_root != null and _recovery_cue_root.visible,
			"target_landmark_id": _recovery_landmark_id,
			"path_start_body_local_m": _recovery_path_start,
			"target_body_local_m": _recovery_target,
			"direction_unit": _recovery_direction,
			"dash_count": RECOVERY_CUE_DASH_COUNT,
			"color_independent_shape": &"progressive_width_dashes",
			"static": true,
			"active_generation": _active_recovery_generation,
			"retired_generation": _retired_recovery_generation,
			"authority": {
				"navigation": false, "movement": false, "recovery": false,
				"health": false, "reward": false, "lifecycle": false,
			},
		},
		"authority": {
			"damage": false, "health": false, "movement": false,
			"recovery": false, "reward": false, "hud": false,
			"lifecycle": false,
		},
	}.duplicate(true)


func _apply_state(state: StringName) -> void:
	_state = state
	var beacon_scale := SAFE_BEACON_SCALE
	if _material != null:
		match state:
			&"recovery_required":
				_material.albedo_color = Color(1.0, 0.12, 0.04, 0.72)
				_material.emission = Color(1.0, 0.05, 0.01)
				_material.emission_energy_multiplier = 2.4
				beacon_scale = RECOVERY_BEACON_SCALE
			&"warning":
				_material.albedo_color = Color(1.0, 0.42, 0.04, 0.58)
				_material.emission = Color(1.0, 0.24, 0.02)
				_material.emission_energy_multiplier = 1.45
				beacon_scale = WARNING_BEACON_SCALE
			_:
				_material.albedo_color = Color(1.0, 0.62, 0.08, 0.34)
				_material.emission = Color(0.9, 0.32, 0.03)
				_material.emission_energy_multiplier = 0.65
	if _beacon != null:
		# Keep the authored cone rooted on the surface while its silhouette changes.
		# Safe is a low landing-pad marker, warning is an upright cone, and recovery
		# is a narrow spire backed by the directional dashes. This stays legible
		# without color or flashing and reuses the two existing hazard renderers.
		_beacon.scale = beacon_scale
		_beacon.position.y = BEACON_HALF_HEIGHT_M * beacon_scale.y
	_set_visible(_attached)
	_set_recovery_cue_visible(_attached and state == &"recovery_required")


func _state_shape(state: StringName) -> StringName:
	match state:
		&"recovery_required":
			return &"tall_spire_with_direction_dashes"
		&"warning":
			return &"upright_cone"
		_:
			return &"low_broad_safe_marker"


func _set_visible(value: bool) -> void:
	if _ring != null:
		_ring.visible = value
	if _beacon != null:
		_beacon.visible = value
	if not value:
		_set_recovery_cue_visible(false)


func _build_recovery_cue(path_length_m: float) -> void:
	var local_start := _recovery_path_start - _anchor
	var local_target := _recovery_target - _anchor
	var dash_length := minf(0.75, path_length_m / float(RECOVERY_CUE_DASH_COUNT + 1))
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3.ONE
	var dash_instances := MultiMesh.new()
	dash_instances.transform_format = MultiMesh.TRANSFORM_3D
	dash_instances.mesh = dash_mesh
	dash_instances.instance_count = RECOVERY_CUE_DASH_COUNT
	dash_instances.visible_instance_count = -1
	var direction_basis := Basis.looking_at(_recovery_direction, Vector3.UP)
	var dash_transforms: Array[Transform3D] = []
	var cue_bounds := AABB()
	for index in RECOVERY_CUE_DASH_COUNT:
		# Increasing widths form a directional silhouette even without color.
		var dash_basis := direction_basis
		dash_basis.x *= 0.22 + float(index) * 0.18
		dash_basis.y *= 0.08
		dash_basis.z *= dash_length
		var progress := float(index + 1) / float(RECOVERY_CUE_DASH_COUNT + 1)
		var dash_position := local_start.lerp(local_target, progress) + Vector3.UP * 0.16
		var dash_transform := Transform3D(dash_basis, dash_position)
		dash_transforms.append(dash_transform)
		var dash_bounds := (dash_transform * dash_mesh.get_aabb()).abs()
		cue_bounds = dash_bounds if index == 0 else cue_bounds.merge(dash_bounds)
	dash_instances.buffer = _encode_multimesh_transforms(dash_transforms)
	dash_instances.custom_aabb = cue_bounds
	var dash_batch := MultiMeshInstance3D.new()
	dash_batch.name = "RecoveryDirectionDashBatch"
	dash_batch.multimesh = dash_instances
	dash_batch.material_override = _recovery_cue_material
	_recovery_cue_root.add_child(dash_batch)


func _encode_multimesh_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _set_recovery_cue_visible(value: bool) -> void:
	if _recovery_cue_root != null:
		_recovery_cue_root.visible = value and not _recovery_landmark_id.is_empty()


func _retire_active_recovery() -> void:
	_retired_recovery_generation = maxi(
		_retired_recovery_generation, _active_recovery_generation
	)
	_active_recovery_generation = 0
