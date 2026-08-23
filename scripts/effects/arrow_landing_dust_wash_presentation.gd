class_name ArrowLandingDustWashPresentation
extends Node3D

## Bounded, ship-local renderer for Ember's powered airless final approach.
## Caller-owned support, clearance, and descent observations drive presentation
## only; this component has no process callback or gameplay authority.

const COMPONENT_ID: StringName = &"arrow-landing-dust-wash-presentation"
const MAX_VISIBLE_ALTITUDE_M := 350.0
const FULL_WASH_ALTITUDE_M := 45.0
const MIN_DESCENT_SPEED_MPS := 2.0
const FULL_DESCENT_SPEED_MPS := 32.0
const MAX_VISUAL_INTENSITY := 0.72
const REDUCED_FLASH_SCALE := 0.45
const MAX_DUST_SCALE_DELTA := 0.6
const REDUCED_MOTION_DUST_SCALE_DELTA := 0.22
const MAX_THRUSTER_SCALE_DELTA := 0.45
const REDUCED_MOTION_THRUSTER_SCALE_DELTA := 0.15
const THRUSTER_OPACITY_SCALE := 0.82

var _dust: CPUParticles3D
var _dust_material: StandardMaterial3D
var _thruster_material: StandardMaterial3D
var _thrusters: Array[MeshInstance3D] = []
var _intensity := 0.0
var _support_clearance_factor := 0.0
var _descent_factor := 0.0
var _presentation_load := 0.0
var _dust_opacity := 0.0
var _dust_scale := 1.0
var _thruster_opacity := 0.0
var _thruster_scale := 1.0
var _landing_supported := false
var _footprint_lateral_scale := 1.0
var _footprint_longitudinal_scale := 1.0
var _observation_count := 0
var _last_reason: StringName = &"not_presented"
var _reduced_flash := false
var _reduced_motion := false


func _ready() -> void:
	_build_visuals()
	_reset_visuals()


func _exit_tree() -> void:
	_reset_visuals()


## Optional pre-tree footprint configuration for larger HeroShip variants.
## Arrow never calls this seam, so its authored positions remain exact.
func configure_footprint(
		lateral_scale: float, longitudinal_scale: float
	) -> Dictionary:
	if is_inside_tree() or _dust != null:
		return _result(false, &"footprint_already_built")
	if not is_finite(lateral_scale) or not is_finite(longitudinal_scale) \
			or lateral_scale < 0.75 or lateral_scale > 2.5 \
			or longitudinal_scale < 0.75 or longitudinal_scale > 3.0:
		return _result(false, &"invalid_footprint")
	_footprint_lateral_scale = lateral_scale
	_footprint_longitudinal_scale = longitudinal_scale
	return _result(true, &"footprint_configured")


func present_observation(
		altitude_m: float, vertical_speed_mps: float, airless: bool,
		landing_supported: bool, reduced_flash: bool, reduced_motion: bool
	) -> Dictionary:
	if not is_finite(altitude_m) or not is_finite(vertical_speed_mps) \
			or altitude_m < 0.0:
		return _result(false, &"invalid_observation")
	_reduced_flash = reduced_flash
	_reduced_motion = reduced_motion
	_landing_supported = landing_supported
	var reason: StringName = &"low_altitude_descent"
	var clearance_factor := 0.0
	var descent_factor := 0.0
	if not airless:
		reason = &"atmospheric_branch_zero"
	elif not landing_supported:
		reason = &"landing_support_unavailable"
	elif altitude_m >= MAX_VISIBLE_ALTITUDE_M:
		reason = &"high_altitude_zero"
	elif vertical_speed_mps >= -MIN_DESCENT_SPEED_MPS:
		reason = &"climb_or_level_zero"
	else:
		clearance_factor = clampf(
			(MAX_VISIBLE_ALTITUDE_M - altitude_m) \
				/ (MAX_VISIBLE_ALTITUDE_M - FULL_WASH_ALTITUDE_M),
			0.0, 1.0,
		)
		descent_factor = clampf(
			(-vertical_speed_mps - MIN_DESCENT_SPEED_MPS) \
				/ (FULL_DESCENT_SPEED_MPS - MIN_DESCENT_SPEED_MPS),
			0.0, 1.0,
		)
	_apply_load(clearance_factor, descent_factor, reduced_flash, reduced_motion)
	_observation_count += 1
	_last_reason = reason
	return _result(true, reason)


func clear(reason: StringName = &"cleared") -> Dictionary:
	_reset_visuals()
	_last_reason = reason
	return _result(true, reason)


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"intensity": _intensity,
		"support_clearance_factor": _support_clearance_factor,
		"descent_factor": _descent_factor,
		"presentation_load": _presentation_load,
		"dust_opacity": _dust_opacity,
		"dust_scale": _dust_scale,
		"thruster_opacity": _thruster_opacity,
		"thruster_scale": _thruster_scale,
		"landing_supported": _landing_supported,
		"footprint_lateral_scale": _footprint_lateral_scale,
		"footprint_longitudinal_scale": _footprint_longitudinal_scale,
		"visible": _intensity > 0.0,
		"dust_emitting": _dust != null and _dust.emitting,
		"thruster_visible_count": _visible_thruster_count(),
		"observation_count": _observation_count,
		"last_reason": _last_reason,
		"reduced_flash": _reduced_flash,
		"reduced_motion": _reduced_motion,
		"steady_emission": _dust != null and is_zero_approx(_dust.randomness),
		"continuous_clearance_descent_response": true,
		"effect_bounds": {
			"max_dust_opacity": MAX_VISUAL_INTENSITY,
			"reduced_flash_max_dust_opacity": (
				MAX_VISUAL_INTENSITY * REDUCED_FLASH_SCALE
			),
			"min_scale": 1.0,
			"max_dust_scale": 1.0 + MAX_DUST_SCALE_DELTA,
			"reduced_motion_max_dust_scale": (
				1.0 + REDUCED_MOTION_DUST_SCALE_DELTA
			),
			"max_thruster_scale": 1.0 + MAX_THRUSTER_SCALE_DELTA,
			"reduced_motion_max_thruster_scale": (
				1.0 + REDUCED_MOTION_THRUSTER_SCALE_DELTA
			),
		}.duplicate(true),
		"node_budget": {
			"total_nodes": 4,
			"particle_nodes": 1,
			"mesh_nodes": 2,
			"process_loops": 0,
		}.duplicate(true),
		"resource_budget": {
			"mesh_resources": 3,
			"material_resources": 2,
		}.duplicate(true),
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
		thruster.position = Vector3(
			(-0.92 if index == 0 else 0.92) * _footprint_lateral_scale,
			-0.76,
			1.25 + 0.95 * _footprint_longitudinal_scale,
		)
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


func _apply_load(
		clearance_factor: float, descent_factor: float,
		reduced_flash: bool, reduced_motion: bool
	) -> void:
	_support_clearance_factor = clampf(clearance_factor, 0.0, 1.0)
	_descent_factor = clampf(descent_factor, 0.0, 1.0)
	_presentation_load = _support_clearance_factor * _descent_factor
	var opacity_cap := MAX_VISUAL_INTENSITY * (
		REDUCED_FLASH_SCALE if reduced_flash else 1.0
	)
	var dust_scale_delta := REDUCED_MOTION_DUST_SCALE_DELTA \
		if reduced_motion else MAX_DUST_SCALE_DELTA
	var thruster_scale_delta := REDUCED_MOTION_THRUSTER_SCALE_DELTA \
		if reduced_motion else MAX_THRUSTER_SCALE_DELTA
	_dust_opacity = _presentation_load * opacity_cap
	_dust_scale = 1.0 + _presentation_load * dust_scale_delta
	_thruster_opacity = _dust_opacity * THRUSTER_OPACITY_SCALE
	_thruster_scale = 1.0 + _presentation_load * thruster_scale_delta
	_intensity = _dust_opacity
	if _dust != null:
		_dust.emitting = _intensity > 0.0 and is_inside_tree()
		_dust.amount = maxi(1, roundi(6.0 + 18.0 * _presentation_load))
		_dust.color = Color(1.0, 1.0, 1.0, _dust_opacity)
		_dust.scale = Vector3(
			_dust_scale * _footprint_lateral_scale,
			_dust_scale,
			_dust_scale * _footprint_longitudinal_scale,
		)
		# A fixed stream avoids flicker; accessibility settings only lower the
		# bounded opacity or geometry expansion computed above.
		_dust.randomness = 0.0
	for thruster in _thrusters:
		thruster.visible = _intensity > 0.0
		thruster.scale = Vector3(1.0, _thruster_scale, 1.0)
	if _thruster_material != null:
		var color := _thruster_material.albedo_color
		color.a = _thruster_opacity
		_thruster_material.albedo_color = color


func _reset_visuals() -> void:
	_reduced_flash = false
	_reduced_motion = false
	_landing_supported = false
	_apply_load(0.0, 0.0, false, false)


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
