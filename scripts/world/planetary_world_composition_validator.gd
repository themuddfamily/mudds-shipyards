class_name PlanetaryWorldCompositionValidator
extends RefCounted

## Pure validation boundary joining one planetary world definition to its
## resolved atmosphere and terrain profiles. It retains no references and owns
## no runtime system; every result contains detached value data only.

const SCHEMA_VERSION := 1
const RADIUS_DATUM: StringName = &"body_center_to_sea_level"
const ANCHOR_FRAME: StringName = &"body_centered_scene_root"


func validate_composition(
	world: PlanetaryWorldDefinition,
	atmosphere: PlanetaryAtmosphereProfile,
	terrain: PlanetaryTerrainProfile
) -> Dictionary:
	var errors: Array[Dictionary] = []
	if world == null:
		_append_error(errors, &"missing_world_definition", &"world", "a planetary world definition is required")
	if terrain == null:
		_append_error(errors, &"missing_terrain_profile", &"terrain", "a resolved terrain profile is required")
	if world != null and not world.is_definition_valid():
		_append_error(errors, &"invalid_world_definition", &"world", "the planetary world definition is invalid")
	if terrain != null and not terrain.is_profile_valid():
		_append_error(errors, &"invalid_terrain_profile", &"terrain", "the resolved terrain profile is invalid")
	if atmosphere != null and not atmosphere.is_definition_valid():
		_append_error(errors, &"invalid_atmosphere_profile", &"atmosphere", "the resolved atmosphere profile is invalid")

	if world != null:
		_validate_atmosphere_binding(errors, world, atmosphere)
		if terrain != null:
			_validate_terrain_binding(errors, world, terrain)
		if terrain != null and (atmosphere == null or atmosphere.is_definition_valid()):
			_validate_scale_and_anchors(errors, world, atmosphere, terrain)

	var error_codes := PackedStringArray()
	for error in errors:
		error_codes.append(str(error.get("code", &"unknown_error")))
	var result := {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"error_codes": error_codes,
		"world_id": world.world_id if world != null else &"",
		"atmosphere_profile_id": atmosphere.profile_id if atmosphere != null else &"",
		"terrain_profile_id": terrain.profile_id if terrain != null else &"",
		"radius_datum": RADIUS_DATUM,
		"anchor_frame": ANCHOR_FRAME,
		"body_radius_meters": world.get_body_radius_meters() if world != null else 0.0,
		"surface_radius_bounds_meters": _surface_radius_bounds(world, terrain),
		"atmosphere_outer_radius_meters": (
			world.get_body_radius_meters() + atmosphere.get_atmosphere_top_altitude_meters()
			if world != null and atmosphere != null else 0.0
		),
		"evidence": _evidence_snapshot(world, atmosphere, terrain),
		"authority": get_authority_report(),
	}
	return result.duplicate(true)


func audit(
	world: PlanetaryWorldDefinition,
	atmosphere: PlanetaryAtmosphereProfile,
	terrain: PlanetaryTerrainProfile
) -> Dictionary:
	return validate_composition(world, atmosphere, terrain).duplicate(true)


func get_authority_report() -> Dictionary:
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


func _validate_atmosphere_binding(
	errors: Array[Dictionary],
	world: PlanetaryWorldDefinition,
	atmosphere: PlanetaryAtmosphereProfile
) -> void:
	if world.has_atmosphere:
		if atmosphere == null:
			_append_error(errors, &"missing_atmosphere_profile", &"atmosphere", "an atmospheric world requires its resolved atmosphere profile")
			return
		if world.atmosphere_definition_id != atmosphere.profile_id:
			_append_error(errors, &"atmosphere_profile_id_mismatch", &"atmosphere_definition_id", "the world atmosphere definition ID must equal the resolved profile ID")
	else:
		if atmosphere != null:
			_append_error(errors, &"unexpected_atmosphere_profile", &"atmosphere", "an airless world must not resolve an atmosphere profile")


func _validate_terrain_binding(
	errors: Array[Dictionary],
	world: PlanetaryWorldDefinition,
	terrain: PlanetaryTerrainProfile
) -> void:
	if world.terrain_definition_id != terrain.profile_id:
		_append_error(errors, &"terrain_profile_id_mismatch", &"terrain_definition_id", "the world terrain definition ID must equal the resolved profile ID")


func _validate_scale_and_anchors(
	errors: Array[Dictionary],
	world: PlanetaryWorldDefinition,
	atmosphere: PlanetaryAtmosphereProfile,
	terrain: PlanetaryTerrainProfile
) -> void:
	var body_radius := world.get_body_radius_meters()
	if body_radius != terrain.get_planet_radius_meters():
		_append_error(errors, &"terrain_radius_mismatch", &"body_radius_metres", "world and terrain sea-level radii must be exactly equal")
	if world.has_atmosphere and atmosphere != null:
		if body_radius != atmosphere.get_planet_radius_meters():
			_append_error(errors, &"atmosphere_radius_mismatch", &"body_radius_metres", "world and atmosphere sea-level radii must be exactly equal")
		if terrain.get_maximum_elevation_meters() > atmosphere.get_atmosphere_top_altitude_meters():
			_append_error(errors, &"terrain_exceeds_atmosphere", &"maximum_elevation_meters", "maximum terrain elevation must not exceed the atmosphere top altitude")

	if not world.scene_anchor.origin.is_equal_approx(Vector3.ZERO):
		_append_error(errors, &"scene_anchor_not_body_center", &"scene_anchor", "the scene anchor origin must coincide with the body-centred scene root")
	var minimum_surface_radius := body_radius + terrain.get_minimum_elevation_meters()
	var maximum_surface_radius := body_radius + terrain.get_maximum_elevation_meters()
	var surface_radius := world.surface_anchor.origin.length()
	if surface_radius < minimum_surface_radius or surface_radius > maximum_surface_radius:
		_append_error(errors, &"surface_anchor_outside_terrain", &"surface_anchor", "surface anchor radius must lie inside the terrain elevation envelope")
	var orbital_minimum_radius := maximum_surface_radius
	if world.has_atmosphere and atmosphere != null:
		orbital_minimum_radius = maxf(
			orbital_minimum_radius,
			body_radius + atmosphere.get_atmosphere_top_altitude_meters()
		)
	var orbital_radius := world.orbital_anchor.origin.length()
	if orbital_radius < orbital_minimum_radius:
		_append_error(errors, &"orbital_anchor_below_outer_shell", &"orbital_anchor", "orbital anchor must be at or beyond the terrain and atmosphere outer shells")
	var navigation_radius := world.navigation_anchor.origin.length()
	if navigation_radius < minimum_surface_radius or navigation_radius > orbital_radius:
		_append_error(errors, &"navigation_anchor_outside_handoff_span", &"navigation_anchor", "navigation anchor radius must lie between the lowest terrain surface and orbital handoff")


func _surface_radius_bounds(
	world: PlanetaryWorldDefinition,
	terrain: PlanetaryTerrainProfile
) -> Dictionary:
	if world == null or terrain == null:
		return {}
	return {
		"minimum": world.get_body_radius_meters() + terrain.get_minimum_elevation_meters(),
		"maximum": world.get_body_radius_meters() + terrain.get_maximum_elevation_meters(),
	}.duplicate(true)


func _evidence_snapshot(
	world: PlanetaryWorldDefinition,
	atmosphere: PlanetaryAtmosphereProfile,
	terrain: PlanetaryTerrainProfile
) -> Dictionary:
	return {
		"world": (world.audit().get("evidence", {}) as Dictionary).duplicate(true) if world != null else {},
		"atmosphere": (atmosphere.audit().get("evidence", {}) as Dictionary).duplicate(true) if atmosphere != null else {},
		"terrain": (terrain.audit().get("evidence", {}) as Dictionary).duplicate(true) if terrain != null else {},
	}.duplicate(true)


static func _append_error(
	errors: Array[Dictionary],
	code: StringName,
	field: StringName,
	message: String
) -> void:
	errors.append({"code": code, "field": field, "message": message})
