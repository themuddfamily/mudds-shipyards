extends SceneTree

const ValidatorScript := preload("res://scripts/world/planetary_world_composition_validator.gd")
const WorldScript := preload("res://scripts/world/definitions/planetary_world_definition.gd")
const AtmosphereScript := preload("res://scripts/world/definitions/planetary_atmosphere_profile.gd")
const TerrainScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	_test_valid_vertical_slice_and_detached_report()
	_test_reference_presence_and_identity_mismatches()
	_test_exact_scale_and_envelope_mismatches()
	_test_anchor_radial_mismatches()
	_test_airless_composition()
	_finish()


func _test_valid_vertical_slice_and_detached_report() -> void:
	var validator := ValidatorScript.new() as PlanetaryWorldCompositionValidator
	var world := _world(true)
	var atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	var report := validator.validate_composition(world, atmosphere, terrain)
	_check(bool(report.valid) and (report.errors as Array).is_empty(), "the shared 120 km atmospheric vertical-slice fixture composes green")
	_check(
		report.radius_datum == &"body_center_to_sea_level"
			and report.anchor_frame == &"body_centered_scene_root"
			and float(report.body_radius_meters) == 120_000.0
			and float(report.atmosphere_outer_radius_meters) == 140_000.0,
		"composition publishes one exact radius datum, centre frame, and atmosphere shell",
	)
	var authority := report.authority as Dictionary
	var all_zero := _dictionary_has_exact_keys(authority, COMMON_AUTHORITY_KEYS)
	for key in COMMON_AUTHORITY_KEYS:
		all_zero = all_zero and authority[key] is bool and not bool(authority[key])
	_check(all_zero, "composition owns zero renderer, gameplay, lifecycle, persistence, or generation authority")
	((report.evidence as Dictionary).terrain as Dictionary)["status"] = &"tampered"
	(report.errors as Array).append({"code": &"tampered"})
	(report.surface_radius_bounds_meters as Dictionary)["minimum"] = -1.0
	var fresh := validator.audit(world, atmosphere, terrain)
	_check(
		fresh.valid
			and ((fresh.evidence as Dictionary).terrain as Dictionary).status == &"modern_interpretation"
			and float((fresh.surface_radius_bounds_meters as Dictionary).minimum) == 117_500.0,
		"nested audit mutation cannot alter resources or a later detached result",
	)


func _test_reference_presence_and_identity_mismatches() -> void:
	var validator := ValidatorScript.new() as PlanetaryWorldCompositionValidator
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	var atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	_check(_has_code(validator.validate_composition(null, atmosphere, terrain), &"missing_world_definition"), "missing world input returns a structured red code")
	_check(_has_code(validator.validate_composition(_world(true), atmosphere, null), &"missing_terrain_profile"), "missing mandatory terrain returns a structured red code")
	_check(_has_code(validator.validate_composition(_world(true), null, terrain), &"missing_atmosphere_profile"), "atmospheric world without a resolved atmosphere fails red")
	var wrong_atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	wrong_atmosphere.profile_id = &"wrong_atmosphere"
	_check(_has_code(validator.validate_composition(_world(true), wrong_atmosphere, terrain), &"atmosphere_profile_id_mismatch"), "world atmosphere ID must equal the resolved profile ID")
	var wrong_terrain := TerrainScript.new() as PlanetaryTerrainProfile
	wrong_terrain.profile_id = &"wrong_terrain"
	_check(_has_code(validator.validate_composition(_world(true), atmosphere, wrong_terrain), &"terrain_profile_id_mismatch"), "world terrain ID must equal the resolved profile ID")
	var invalid_terrain := TerrainScript.new() as PlanetaryTerrainProfile
	invalid_terrain.profile_id = &"9terrain"
	_check(_has_code(validator.validate_composition(_world(true), atmosphere, invalid_terrain), &"invalid_terrain_profile"), "resolved profiles share the world reference grammar and reject leading digits")


func _test_exact_scale_and_envelope_mismatches() -> void:
	var validator := ValidatorScript.new() as PlanetaryWorldCompositionValidator
	var atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	var terrain_radius_mismatch := TerrainScript.new() as PlanetaryTerrainProfile
	terrain_radius_mismatch.reference_planet_radius_meters += 0.001
	_check(_has_code(validator.validate_composition(_world(true), atmosphere, terrain_radius_mismatch), &"terrain_radius_mismatch"), "terrain radius equality is exact rather than approximate")
	var atmosphere_radius_mismatch := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	atmosphere_radius_mismatch.planet_radius_m -= 1.0
	_check(_has_code(validator.validate_composition(_world(true), atmosphere_radius_mismatch, terrain), &"atmosphere_radius_mismatch"), "atmosphere radius must equal the shared sea-level radius")
	var shallow_atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	shallow_atmosphere.atmosphere_top_altitude_m = 8_000.0
	shallow_atmosphere.entry_effect_start_altitude_m = 7_000.0
	shallow_atmosphere.entry_effect_full_altitude_m = 4_000.0
	shallow_atmosphere.cloud_top_altitude_m = 6_000.0
	_check(
		shallow_atmosphere.is_definition_valid()
			and _has_code(validator.validate_composition(_world(true), shallow_atmosphere, terrain), &"terrain_exceeds_atmosphere"),
		"an individually valid atmosphere fails composition when terrain peaks cross its shell",
	)


func _test_anchor_radial_mismatches() -> void:
	var validator := ValidatorScript.new() as PlanetaryWorldCompositionValidator
	var atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	var off_center := _world(true)
	off_center.scene_anchor.origin = Vector3(1.0, 0.0, 0.0)
	_check(_has_code(validator.validate_composition(off_center, atmosphere, terrain), &"scene_anchor_not_body_center"), "scene frame must originate at the body centre")
	var buried_surface := _world(true)
	buried_surface.surface_anchor.origin = Vector3(0.0, 117_499.0, 0.0)
	_check(_has_code(validator.validate_composition(buried_surface, atmosphere, terrain), &"surface_anchor_outside_terrain"), "surface handoff must lie inside the terrain elevation envelope")
	var surface_above_terrain := _world(true)
	surface_above_terrain.surface_anchor.origin = Vector3(0.0, 128_501.0, 0.0)
	_check(_has_code(validator.validate_composition(surface_above_terrain, atmosphere, terrain), &"surface_anchor_outside_terrain"), "surface handoff above the maximum terrain radius fails red")
	var low_orbit := _world(true)
	low_orbit.orbital_anchor.origin = Vector3(0.0, 139_999.0, 0.0)
	_check(_has_code(validator.validate_composition(low_orbit, atmosphere, terrain), &"orbital_anchor_below_outer_shell"), "orbital handoff must clear the atmosphere outer shell")
	var navigation_beyond_orbit := _world(true)
	navigation_beyond_orbit.navigation_anchor.origin = Vector3(0.0, 141_000.0, 0.0)
	_check(_has_code(validator.validate_composition(navigation_beyond_orbit, atmosphere, terrain), &"navigation_anchor_outside_handoff_span"), "navigation handoff stays between terrain and orbit")
	var navigation_below_terrain := _world(true)
	navigation_below_terrain.navigation_anchor.origin = Vector3(0.0, 117_499.0, 0.0)
	_check(_has_code(validator.validate_composition(navigation_below_terrain, atmosphere, terrain), &"navigation_anchor_outside_handoff_span"), "navigation handoff below the minimum terrain radius fails red")

	var minimum_boundaries := _world(true)
	minimum_boundaries.surface_anchor.origin = Vector3(0.0, 117_500.0, 0.0)
	minimum_boundaries.navigation_anchor.origin = Vector3(0.0, 117_500.0, 0.0)
	var maximum_boundaries := _world(true)
	maximum_boundaries.surface_anchor.origin = Vector3(0.0, 128_500.0, 0.0)
	maximum_boundaries.navigation_anchor.origin = maximum_boundaries.orbital_anchor.origin
	_check(
		validator.validate_composition(minimum_boundaries, atmosphere, terrain).valid
			and validator.validate_composition(maximum_boundaries, atmosphere, terrain).valid,
		"surface and navigation radial bounds are inclusive at their exact endpoints",
	)


func _test_airless_composition() -> void:
	var validator := ValidatorScript.new() as PlanetaryWorldCompositionValidator
	var world := _world(false)
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	_check(validator.validate_composition(world, null, terrain).valid, "airless world composes with no atmosphere profile")
	var atmosphere := AtmosphereScript.new() as PlanetaryAtmosphereProfile
	_check(_has_code(validator.validate_composition(world, atmosphere, terrain), &"unexpected_atmosphere_profile"), "airless world rejects an atmosphere profile even when that profile is valid")
	var low_airless_orbit := _world(false)
	low_airless_orbit.orbital_anchor.origin = Vector3(0.0, 125_000.0, 0.0)
	_check(_has_code(validator.validate_composition(low_airless_orbit, null, terrain), &"orbital_anchor_below_outer_shell"), "an airless orbit above sea level still fails below the maximum terrain shell")
	var boundary_airless_orbit := _world(false)
	boundary_airless_orbit.orbital_anchor.origin = Vector3(0.0, 128_500.0, 0.0)
	boundary_airless_orbit.navigation_anchor.origin = Vector3(0.0, 128_500.0, 0.0)
	_check(validator.validate_composition(boundary_airless_orbit, null, terrain).valid, "an airless orbital and navigation handoff may sit exactly on the terrain shell")


func _world(atmospheric: bool) -> PlanetaryWorldDefinition:
	var world := WorldScript.new() as PlanetaryWorldDefinition
	world.world_id = &"vertical_slice_world"
	world.display_name = "Vertical Slice World"
	world.sector_id = &"planetary_test_sector"
	world.content_note = "Invented composition fixture; no production destination is claimed."
	world.scene_path = "res://scenes/world/planets/vertical_slice_world.tscn"
	world.scene_anchor_id = &"vertical_slice_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"vertical_slice_navigation"
	world.navigation_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 130_000.0, 0.0))
	world.orbital_anchor_id = &"vertical_slice_orbit"
	world.orbital_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 140_000.0, 0.0))
	world.surface_anchor_id = &"vertical_slice_surface"
	world.surface_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 120_000.0, 0.0))
	world.body_radius_metres = 120_000.0
	world.has_atmosphere = atmospheric
	world.atmosphere_definition_id = &"temperate_game_scale" if atmospheric else &""
	world.terrain_definition_id = &"default_planetary_terrain"
	world.landing_region_ids = PackedStringArray(["vertical_slice_landing_region"])
	world.evidence_status = WorldScript.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Invented composition fixture."
	return world


func _has_code(report: Dictionary, code: StringName) -> bool:
	return (report.get("error_codes", PackedStringArray()) as PackedStringArray).has(str(code))


func _dictionary_has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("PLANETARY_WORLD_COMPOSITION_VALIDATOR_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_WORLD_COMPOSITION_VALIDATOR_TEST_OK")
		quit(0)
		return
	print("PLANETARY_WORLD_COMPOSITION_VALIDATOR_TEST_FAILURES: %s" % _failures)
	quit(1)
