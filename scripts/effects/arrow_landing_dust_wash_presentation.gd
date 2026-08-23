class_name ArrowLandingDustWashPresentation
extends Node3D

## Bounded, ship-local renderer for Ember's powered airless descent. Caller
## observations select visibility only; this component has no process callback,
## collision, movement, damage, atmosphere, or landing authority.

const COMPONENT_ID: StringName = &"arrow-landing-dust-wash-presentation"
const MAX_VISIBLE_ALTITUDE_M := 350.0
const FULL_WASH_ALTITUDE_M := 45.0
const MIN_DESCENT_SPEED_MPS := 2.0
const FULL_DESCENT_SPEED_MPS := 32.0
const MAX_VISUAL_INTENSITY := 0.72
const REDUCED_FLASH_SCALE := 0.45
const REDUCED_MOTION_SCALE := 0.82

var _dust: CPUParticles3D
var _dust_material: StandardMaterial3D
var _thruster_material: StandardMaterial3D
var _thrusters: Array[MeshInstance3D] = []
var _intensity := 0.0
var _observation_count := 0
var _last_reason: StringName = &"not_presented"
var _reduced_flash := false
var _reduced_motion := false


func _ready() -> void:
	_build_visuals()
	_apply_intensity(0.0)


func _exit_tree() -> void:
	_apply_intensity(0.0)


func present_observation(
		altitude_m: float, vertical_speed_mps: float, airless: bool,
		reduced_flash: bool, reduced_motion: bool
	) -> Dictionary:
	if not is_finite(altitude_m) or not is_finite(vertical_speed_mps) \
			or altitude_m < 0.0:
		return _result(false, &"invalid_observation")
	_reduced_flash = reduced_flash
	_reduced_motion = reduced_motion
	var reason: StringName = &"low_altitude_descent"
	var candidate := 0.0
	if not airless:
		reason = &"atmospheric_branch_zero"
	elif altitude_m >= MAX_VISIBLE_ALTITUDE_M:
		reason = &"high_altitude_zero"
	elif vertical_speed_mps >= -MIN_DESCENT_SPEED_MPS:
		reason = &"climb_or_level_zero"
	else:
		var altitude_factor := clampf(
			(MAX_VISIBLE_ALTITUDE_M - altitude_m) \
				/ (MAX_VISIBLE_ALTITUDE_M - FULL_WASH_ALTITUDE_M),
			0.0, 1.0,
		)
		var descent_factor := clampf(
			(-vertical_speed_mps - MIN_DESCENT_SPEED_MPS) \
				/ (FULL_DESCENT_SPEED_MPS - MIN_DESCENT_SPEED_MPS),
			0.0, 1.0,
		)
		candidate = altitude_factor * descent_factor * MAX_VISUAL_INTENSITY
		if reduced_flash:
			candidate *= REDUCED_FLASH_SCALE
		if reduced_motion:
			candidate *= REDUCED_MOTION_SCALE
	_apply_intensity(candidate)
	_observation_count += 1
	_last_reason = reason
	return _result(true, reason)


func clear(reason: StringName = &"cleared") -> Dictionary:
	_apply_intensity(0.0)
	_last_reason = reason
	return _result(true, reason)


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"intensity": _intensity,
		"visible": _intensity > 0.0,
		"dust_emitting": _dust != null and _dust.emitting,
		"thruster_visible_count": _visible_thruster_count(),
		"observation_count": _observation_count,
		"last_reason": _last_reason,
		"reduced_flash": _reduced_flash,
		"reduced_motion": _reduced_motion,
		"steady_emission": _dust != null and is_zero_approx(_dust.randomness),
		"ship_local": true,
		"presentation_only": true,
		"collision_authority": false,
		"physics_authority": false,
		"movement_authority": false,
		"damage_authority": false,
		"atmosphere_authority": false,
		"landing_authority": false,
	}.duplicate(true)


func _build_visuals() -> void:
	if _dust != null:
		return
	_thruster_material = StandardMaterial3D.new()
	_thruster_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_thruster_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_thruster_material.albedo_color = Color(0.48, 0.9, 1.0, 0.0)
	_thruster_material.emission_enabled = true
	_thruster_material.emission = Color(0.2, 0.72, 1.0)
	_thruster_material.emission_energy_multiplier = 2.2
	for index in 2:
		var thruster := MeshInstance3D.new()
		thruster.name = "PortLandingThruster" if index == 0 \
			else "StarboardLandingThruster"
		thruster.position = Vector3(-0.92 if index == 0 else 0.92, -0.76, 2.2)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.08
		cone.bottom_radius = 0.28
		cone.height = 1.25
		cone.radial_segments = 12
		cone.rings = 1
		cone.material = _thruster_material
		thruster.mesh = cone
		thruster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(thruster)
		_thrusters.append(thruster)

	_dust_material = StandardMaterial3D.new()
	_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_dust_material.albedo_color = Color(0.48, 0.31, 0.19, 0.7)
	var dust_quad := QuadMesh.new()
	dust_quad.size = Vector2(0.7, 0.7)
	dust_quad.material = _dust_material
	_dust = CPUParticles3D.new()
	_dust.name = "ShipLocalDustWash"
	_dust.position = Vector3(0.0, -1.28, 1.25)
	_dust.amount = 24
	_dust.lifetime = 0.72
	_dust.local_coords = true
	_dust.direction = Vector3.DOWN
	_dust.spread = 78.0
	_dust.gravity = Vector3.ZERO
	_dust.initial_velocity_min = 1.4
	_dust.initial_velocity_max = 3.1
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 1.2
	_dust.randomness = 0.0
	_dust.visibility_aabb = AABB(Vector3(-8.0, -4.0, -8.0), Vector3(16.0, 8.0, 16.0))
	_dust.mesh = dust_quad
	add_child(_dust)


func _apply_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, MAX_VISUAL_INTENSITY)
	if _dust != null:
		_dust.emitting = _intensity > 0.0 and is_inside_tree()
		_dust.amount = maxi(1, roundi(6.0 + 18.0 * _intensity / MAX_VISUAL_INTENSITY))
		_dust.color = Color(1.0, 1.0, 1.0, _intensity)
		# A fixed emission stream avoids flashing/flicker in both accessibility
		# modes; reduced settings additionally lower the bounded intensity.
		_dust.randomness = 0.0
	for thruster in _thrusters:
		thruster.visible = _intensity > 0.0
		thruster.scale = Vector3(1.0, 0.25 + _intensity, 1.0)
	if _thruster_material != null:
		var color := _thruster_material.albedo_color
		color.a = _intensity * 0.82
		_thruster_material.albedo_color = color


func _visible_thruster_count() -> int:
	var count := 0
	for thruster in _thrusters:
		if thruster.visible:
			count += 1
	return count


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
	}.duplicate(true)
