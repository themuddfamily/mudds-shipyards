class_name PlanetarySurfaceGravityPolicy
extends RefCounted

## Pure, deterministic radial-gravity and surface-orientation policy.
##
## Configuration composes one valid world definition, terrain profile, and
## body-local coordinate frame, then freezes detached scalar/value data only.
## Sampling is an explicit caller operation. It never moves a Node, integrates
## physics, generates collision, chooses a landing, rebases an origin, advances
## a clock, streams content, renders, saves, or owns network state.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_surface_gravity_v1"
const EQUATION_VERSION: StringName = &"inverse_square_from_sea_level_v1"
const RADIUS_DATUM: StringName = &"body_center_to_sea_level"
const SAMPLE_FRAME: StringName = &"planetary_body_local"
const TANGENT_AXES: StringName = &"x_east_y_up_z_south"

const MIN_REFERENCE_GRAVITY_MPS2 := 0.001
const MAX_REFERENCE_GRAVITY_MPS2 := 1000.0
const CENTER_BOUNDARY_RADIUS_METERS := 0.000001
const MAX_SAMPLE_RADIUS_METERS := 1_000_000_000.0
const MIN_TANGENT_AXIS_LENGTH := 0.000001

const _COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _configured := false
var _world_id: StringName = &""
var _body_id: StringName = &""
var _terrain_profile_id: StringName = &""
var _source_world_schema_version := 0
var _source_terrain_schema_version := 0
var _source_coordinate_frame_schema_version := 0
var _source_coordinate_frame_generation := 0
var _body_radius_meters := 0.0
var _minimum_elevation_meters := 0.0
var _maximum_elevation_meters := 0.0
var _minimum_surface_radius_meters := 0.0
var _maximum_surface_radius_meters := 0.0
var _reference_surface_gravity_mps2 := 0.0
var _tangent_north_seed_body_local := Vector3.ZERO
var _source_evidence: Dictionary = {}


## Freezes one exact body-centred sea-level datum. A rejected configuration is
## retryable; a successful policy is immutable and retains no source objects.
func configure(
	world: PlanetaryWorldDefinition,
	terrain: PlanetaryTerrainProfile,
	coordinate_frame: PlanetaryCoordinateFrame,
	reference_surface_gravity_mps2: float
) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if world == null:
		return _result(false, &"missing_world_definition")
	if terrain == null:
		return _result(false, &"missing_terrain_profile")
	if coordinate_frame == null:
		return _result(false, &"missing_coordinate_frame")

	var world_audit := world.audit()
	if not world.is_definition_valid() \
		or not bool(world_audit.get("valid", false)) \
		or not _has_exact_zero_authority(
			world_audit.get("authority", {}) as Dictionary
		):
		return _result(false, &"invalid_world_definition")
	var terrain_audit := terrain.audit()
	if not terrain.is_profile_valid() \
		or not bool(terrain_audit.get("valid", false)) \
		or not _has_exact_zero_authority(
			terrain_audit.get("authority", {}) as Dictionary
		):
		return _result(false, &"invalid_terrain_profile")
	var frame_audit := coordinate_frame.audit()
	if not coordinate_frame.is_configured() \
		or not bool(frame_audit.get("valid", false)) \
		or not _all_boolean_values_are_false(
			frame_audit.get("authority", {}) as Dictionary
		):
		return _result(false, &"invalid_coordinate_frame")
	if not is_finite(reference_surface_gravity_mps2) \
		or reference_surface_gravity_mps2 < MIN_REFERENCE_GRAVITY_MPS2 \
		or reference_surface_gravity_mps2 > MAX_REFERENCE_GRAVITY_MPS2:
		return _result(false, &"invalid_reference_surface_gravity")

	var frame_snapshot := coordinate_frame.get_snapshot()
	if not _frame_snapshot_has_required_body_datum(frame_snapshot):
		return _result(false, &"invalid_coordinate_frame_snapshot")
	if world.terrain_definition_id != terrain.profile_id:
		return _result(false, &"terrain_profile_id_mismatch")
	var world_radius := world.get_body_radius_meters()
	var terrain_radius := terrain.get_planet_radius_meters()
	var frame_radius := float(frame_snapshot.get("body_radius_meters", 0.0))
	if world_radius != terrain_radius or world_radius != frame_radius:
		return _result(false, &"body_radius_mismatch")

	var minimum_elevation := terrain.get_minimum_elevation_meters()
	var maximum_elevation := terrain.get_maximum_elevation_meters()
	var minimum_surface_radius := world_radius + minimum_elevation
	var maximum_surface_radius := world_radius + maximum_elevation
	if not is_finite(minimum_surface_radius) \
		or not is_finite(maximum_surface_radius) \
		or minimum_surface_radius <= CENTER_BOUNDARY_RADIUS_METERS \
		or maximum_surface_radius <= minimum_surface_radius \
		or maximum_surface_radius > MAX_SAMPLE_RADIUS_METERS:
		return _result(false, &"invalid_surface_shell")
	var north_seed := frame_snapshot.get(
		"surface_north_direction", Vector3.ZERO
	) as Vector3
	if not north_seed.is_finite() \
		or north_seed.length() < MIN_TANGENT_AXIS_LENGTH:
		return _result(false, &"invalid_tangent_north_seed")

	_configured = true
	_world_id = world.world_id
	_body_id = frame_snapshot.get("body_id", &"") as StringName
	_terrain_profile_id = terrain.profile_id
	_source_world_schema_version = int(
		world_audit.get("schema_version", 0)
	)
	_source_terrain_schema_version = int(
		terrain_audit.get("schema_version", 0)
	)
	_source_coordinate_frame_schema_version = int(
		frame_snapshot.get("schema_version", 0)
	)
	_source_coordinate_frame_generation = int(
		frame_snapshot.get("generation", 0)
	)
	_body_radius_meters = world_radius
	_minimum_elevation_meters = minimum_elevation
	_maximum_elevation_meters = maximum_elevation
	_minimum_surface_radius_meters = minimum_surface_radius
	_maximum_surface_radius_meters = maximum_surface_radius
	_reference_surface_gravity_mps2 = reference_surface_gravity_mps2
	_tangent_north_seed_body_local = north_seed.normalized()
	_source_evidence = {
		"world": (
			world_audit.get("evidence", {}) as Dictionary
		).duplicate(true),
		"terrain": (
			terrain_audit.get("evidence", {}) as Dictionary
		).duplicate(true),
	}.duplicate(true)
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Samples one explicit body-local position. The minimum terrain radius is an
## inclusive surface-domain boundary; positions below it reject because this
## foundation does not invent an interior-density gravity model. Positions at
## and above that shell use inverse-square falloff from the sea-level datum.
func sample(body_local_position_meters: Vector3) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not body_local_position_meters.is_finite():
		return _result(false, &"nonfinite_body_local_position")
	var radius_meters := body_local_position_meters.length()
	if not is_finite(radius_meters) \
		or radius_meters > MAX_SAMPLE_RADIUS_METERS:
		return _result(false, &"body_local_position_out_of_bounds")
	if radius_meters <= CENTER_BOUNDARY_RADIUS_METERS:
		return _result(false, &"radial_up_undefined_at_center")
	if radius_meters < _minimum_surface_radius_meters:
		return _result(false, &"below_minimum_surface_shell")

	var radial_up := body_local_position_meters / radius_meters
	var tangent := _tangent_hints(radial_up)
	if tangent.is_empty():
		return _result(false, &"tangent_orientation_unavailable")
	var radius_ratio := _body_radius_meters / radius_meters
	var gravity_magnitude := _reference_surface_gravity_mps2 \
		* radius_ratio * radius_ratio
	var gravity_vector := -radial_up * gravity_magnitude
	var altitude_meters := radius_meters - _body_radius_meters
	if not is_finite(gravity_magnitude) or gravity_magnitude <= 0.0 \
		or not gravity_vector.is_finite() or not is_finite(altitude_meters):
		return _result(false, &"sample_out_of_bounds")

	var at_minimum := radius_meters == _minimum_surface_radius_meters
	var at_sea_level := radius_meters == _body_radius_meters
	var at_maximum := radius_meters == _maximum_surface_radius_meters
	var within_terrain_envelope := (
		radius_meters >= _minimum_surface_radius_meters
		and radius_meters <= _maximum_surface_radius_meters
	)
	var shell_state: StringName = &"above_terrain_shell"
	if at_minimum:
		shell_state = &"minimum_surface_boundary"
	elif at_sea_level:
		shell_state = &"sea_level_boundary"
	elif at_maximum:
		shell_state = &"maximum_surface_boundary"
	elif within_terrain_envelope:
		shell_state = &"within_terrain_envelope"

	return _result(true, &"sampled", {
		"sample_schema_version": SCHEMA_VERSION,
		"sample_frame": SAMPLE_FRAME,
		"body_local_position_meters": body_local_position_meters,
		"radius_meters": radius_meters,
		"altitude_meters": altitude_meters,
		"radial_up": radial_up,
		"gravity_vector_mps2": gravity_vector,
		"gravity_magnitude_mps2": gravity_magnitude,
		"tangent_basis_body_local": tangent.get("basis", Basis.IDENTITY),
		"tangent_east": tangent.get("east", Vector3.ZERO),
		"tangent_north": tangent.get("north", Vector3.ZERO),
		"tangent_south": tangent.get("south", Vector3.ZERO),
		"tangent_fallback_used": bool(tangent.get("fallback_used", false)),
		"shell": {
			"state": shell_state,
			"within_terrain_envelope": within_terrain_envelope,
			"above_terrain_envelope": (
				radius_meters > _maximum_surface_radius_meters
			),
			"at_minimum_surface_radius": at_minimum,
			"at_sea_level_radius": at_sea_level,
			"at_maximum_surface_radius": at_maximum,
			"minimum_surface_clearance_meters": (
				radius_meters - _minimum_surface_radius_meters
			),
			"maximum_surface_clearance_meters": (
				radius_meters - _maximum_surface_radius_meters
			),
		},
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"configured": _configured,
		"world_id": _world_id,
		"body_id": _body_id,
		"terrain_profile_id": _terrain_profile_id,
		"source_world_schema_version": _source_world_schema_version,
		"source_terrain_schema_version": _source_terrain_schema_version,
		"source_coordinate_frame_schema_version": (
			_source_coordinate_frame_schema_version
		),
		"source_coordinate_frame_generation": (
			_source_coordinate_frame_generation
		),
		"radius_datum": RADIUS_DATUM,
		"sample_frame": SAMPLE_FRAME,
		"tangent_axes": TANGENT_AXES,
		"body_radius_meters": _body_radius_meters,
		"minimum_elevation_meters": _minimum_elevation_meters,
		"maximum_elevation_meters": _maximum_elevation_meters,
		"minimum_surface_radius_meters": _minimum_surface_radius_meters,
		"maximum_surface_radius_meters": _maximum_surface_radius_meters,
		"reference_surface_gravity_mps2": (
			_reference_surface_gravity_mps2
		),
		"tangent_north_seed_body_local": _tangent_north_seed_body_local,
		"source_evidence": _source_evidence.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("surface gravity policy is not configured")
	elif not _frozen_contract_is_valid():
		errors.append("frozen surface gravity contract is invalid")
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"equation_version": EQUATION_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"boundary_policy": {
			"nonfinite_position": &"reject",
			"center_radius_meters": CENTER_BOUNDARY_RADIUS_METERS,
			"at_or_inside_center": &"reject_radial_up_undefined",
			"below_minimum_surface_shell": &"reject_no_interior_model",
			"minimum_surface_shell": &"inclusive",
			"sea_level_shell": &"inclusive_named_boundary",
			"maximum_surface_shell": &"inclusive",
			"above_maximum_surface_shell": &"inverse_square_continues",
			"maximum_sample_radius_meters": MAX_SAMPLE_RADIUS_METERS,
		},
		"orientation_policy": {
			"axes": TANGENT_AXES,
			"north": &"frozen_north_seed_projected_to_local_tangent",
			"degenerate_projection": &"deterministic_least_aligned_axis",
		},
		"purity": {
			"delta_input": false,
			"clock_input": false,
			"retains_source_objects": false,
			"mutates_policy_during_sample": false,
		},
		"authority": _zero_authority(),
		"adjacent_authority": {
			"node_movement": false,
			"physics_integration": false,
			"collision": false,
			"origin_rebase": false,
			"landing_decision": false,
			"renderer": false,
			"clock": false,
			"streaming": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func get_authority_report() -> Dictionary:
	return _zero_authority()


func _tangent_hints(radial_up: Vector3) -> Dictionary:
	var north_projection := _tangent_north_seed_body_local \
		- radial_up * _tangent_north_seed_body_local.dot(radial_up)
	var fallback_used := false
	if north_projection.length() < MIN_TANGENT_AXIS_LENGTH:
		fallback_used = true
		var fallback_seed := _least_aligned_axis(radial_up)
		north_projection = fallback_seed \
			- radial_up * fallback_seed.dot(radial_up)
	if not north_projection.is_finite() \
		or north_projection.length() < MIN_TANGENT_AXIS_LENGTH:
		return {}
	var north := north_projection.normalized()
	var east := north.cross(radial_up).normalized()
	var south := -north
	var basis := Basis(east, radial_up, south)
	if not basis.is_finite() or not basis.is_orthonormal() \
		or basis.determinant() <= 0.0:
		return {}
	return {
		"basis": basis,
		"east": east,
		"north": north,
		"south": south,
		"fallback_used": fallback_used,
	}


static func _least_aligned_axis(direction: Vector3) -> Vector3:
	var candidates: Array[Vector3] = [
		Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
	]
	var selected: Vector3 = candidates[0]
	var selected_alignment := absf(direction.dot(selected))
	for index in range(1, candidates.size()):
		var alignment := absf(direction.dot(candidates[index]))
		if alignment < selected_alignment:
			selected = candidates[index]
			selected_alignment = alignment
	return selected


func _frozen_contract_is_valid() -> bool:
	return not _world_id.is_empty() \
		and not _body_id.is_empty() \
		and not _terrain_profile_id.is_empty() \
		and _source_world_schema_version == PlanetaryWorldDefinition.SCHEMA_VERSION \
		and _source_terrain_schema_version == PlanetaryTerrainProfile.SCHEMA_VERSION \
		and _source_coordinate_frame_schema_version \
			== PlanetaryCoordinateFrame.SCHEMA_VERSION \
		and _source_coordinate_frame_generation >= 1 \
		and is_finite(_body_radius_meters) \
		and _body_radius_meters >= PlanetaryTerrainProfile.MIN_PLANET_RADIUS_METERS \
		and _body_radius_meters <= PlanetaryTerrainProfile.MAX_PLANET_RADIUS_METERS \
		and is_finite(_minimum_surface_radius_meters) \
		and _minimum_surface_radius_meters > CENTER_BOUNDARY_RADIUS_METERS \
		and is_finite(_maximum_surface_radius_meters) \
		and _maximum_surface_radius_meters > _minimum_surface_radius_meters \
		and _maximum_surface_radius_meters <= MAX_SAMPLE_RADIUS_METERS \
		and _minimum_surface_radius_meters \
			== _body_radius_meters + _minimum_elevation_meters \
		and _maximum_surface_radius_meters \
			== _body_radius_meters + _maximum_elevation_meters \
		and is_finite(_reference_surface_gravity_mps2) \
		and _reference_surface_gravity_mps2 >= MIN_REFERENCE_GRAVITY_MPS2 \
		and _reference_surface_gravity_mps2 <= MAX_REFERENCE_GRAVITY_MPS2 \
		and _tangent_north_seed_body_local.is_finite() \
		and _tangent_north_seed_body_local.is_normalized()


static func _frame_snapshot_has_required_body_datum(
	snapshot: Dictionary
) -> bool:
	return snapshot.get("schema_version") is int \
		and int(snapshot.get("schema_version", 0)) \
			== PlanetaryCoordinateFrame.SCHEMA_VERSION \
		and snapshot.get("configured") is bool \
		and bool(snapshot.get("configured", false)) \
		and snapshot.get("body_id") is StringName \
		and not (snapshot.get("body_id", &"") as StringName).is_empty() \
		and snapshot.get("body_radius_meters") is float \
		and is_finite(float(snapshot.get("body_radius_meters", 0.0))) \
		and snapshot.get("surface_north_direction") is Vector3 \
		and (snapshot.get("surface_north_direction") as Vector3).is_finite() \
		and snapshot.get("generation") is int \
		and int(snapshot.get("generation", 0)) >= 1


static func _has_exact_zero_authority(authority: Dictionary) -> bool:
	if authority.size() != _COMMON_AUTHORITY_KEYS.size():
		return false
	for key in _COMMON_AUTHORITY_KEYS:
		if not authority.has(key) or not authority[key] is bool \
			or bool(authority[key]):
			return false
	return true


static func _all_boolean_values_are_false(authority: Dictionary) -> bool:
	if authority.is_empty():
		return false
	for value: Variant in authority.values():
		if not value is bool or bool(value):
			return false
	return true


static func _zero_authority() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"save": false,
		"network": false,
		"physics": false,
		"world_generation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"origin_shift": false,
		"weather_clock": false,
		"audio": false,
	}.duplicate(true)


func _result(
	accepted: bool,
	reason: StringName,
	details: Dictionary = {}
) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"world_id": _world_id,
		"body_id": _body_id,
		"terrain_profile_id": _terrain_profile_id,
		"policy_version": POLICY_VERSION,
	}
	result.merge(details, true)
	return result.duplicate(true)
