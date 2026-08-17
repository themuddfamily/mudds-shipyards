extends SceneTree

const WorldValidatorScript := preload("res://scripts/world/planetary_world_composition_validator.gd")
const LandingValidatorScript := preload("res://scripts/world/planetary_landing_composition_validator.gd")
const CoordinateFrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")

const WORLD_PATH := "res://assets/world/planets/ember_moon_world.tres"
const TERRAIN_PATH := "res://assets/world/planets/ember_basalt_terrain.tres"
const REGION_PATH := "res://assets/world/planets/ember_caldera_landing_region.tres"
const RESERVED_SCENE_PATH := "res://scenes/world/planets/ember_moon.tscn"
const EVIDENCE_REFERENCE := "res://docs/EMBER_MOON_AUTHORED_DEFINITIONS.md"
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const EXPECTED_ASSERTIONS := 19

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	_test_authored_resources_load_and_validate()
	_test_airless_world_and_landing_composition()
	_test_detachment_and_resource_round_trip()
	_finish()


func _test_authored_resources_load_and_validate() -> void:
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var region := load(REGION_PATH) as PlanetaryLandingRegionDefinition
	_check(world != null and world.is_definition_valid(), "the authored Ember world resource loads and validates")
	_check(terrain != null and terrain.is_profile_valid(), "the authored Ember terrain resource loads and validates")
	_check(region != null and region.is_definition_valid(), "the authored Ember landing resource loads and validates")
	_check(
		world.world_id == &"ember_moon"
			and world.sector_id == &"nearby_sector"
			and world.terrain_definition_id == &"ember_basalt_terrain"
			and world.landing_region_ids == PackedStringArray(["ember_caldera"]),
		"world identity resolves exactly one terrain and one landing region",
	)
	_check(
		not world.has_atmosphere and world.atmosphere_definition_id.is_empty(),
		"Ember Moon is explicitly airless with no atmosphere logical reference",
	)
	_check(
		world.body_radius_metres == 120_000.0
			and terrain.reference_planet_radius_meters == 120_000.0
			and region.body_radius_m == 120_000.0
			and terrain.minimum_elevation_meters == -2_500.0
			and terrain.maximum_elevation_meters == 8_500.0,
		"all authored resources share the exact sea-level datum and terrain envelope",
	)
	_check(
		world.surface_anchor.origin == Vector3(0.0, 120_000.0, 0.0)
			and world.navigation_anchor.origin == Vector3(0.0, 130_000.0, 0.0)
			and world.orbital_anchor.origin == Vector3(0.0, 140_000.0, 0.0)
			and region.body_local_center_m == Vector3(0.0, 120_000.0, 0.0)
			and region.body_local_basis.y == Vector3.UP,
		"body-centred handoffs and the sole landing basis use the authored +Y radial line",
	)
	_check(
		world.evidence_references == PackedStringArray([EVIDENCE_REFERENCE])
			and terrain.evidence_references == PackedStringArray([EVIDENCE_REFERENCE])
			and region.evidence_references == PackedStringArray([EVIDENCE_REFERENCE]),
		"all definitions identify the same standalone modern-design evidence record",
	)
	_check(
		_all_boolean_values_false(world.audit().authority)
			and _all_boolean_values_false(terrain.audit().authority)
			and _all_boolean_values_false(region.audit().authority),
		"the authored definitions grant no renderer, generation, streaming, landing, or gameplay authority",
	)
	_check(
		world.scene_path == RESERVED_SCENE_PATH and not ResourceLoader.exists(RESERVED_SCENE_PATH),
		"the future scene path is reserved but no scene is placed or loadable in this slice",
	)


func _test_airless_world_and_landing_composition() -> void:
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var region := load(REGION_PATH) as PlanetaryLandingRegionDefinition
	var world_report := WorldValidatorScript.new().validate_composition(world, null, terrain)
	_check(
		world_report.valid
			and world_report.atmosphere_profile_id == &""
			and world_report.atmosphere_outer_radius_meters == 0.0
			and (world_report.errors as Array).is_empty(),
		"the authored world and terrain compose green only through the airless branch",
	)
	var atmospheric_result := WorldValidatorScript.new().validate_composition(
		world, PlanetaryAtmosphereProfile.new(), terrain,
	)
	_check(
		(atmospheric_result.error_codes as PackedStringArray).has("unexpected_atmosphere_profile"),
		"the authored airless world rejects even an otherwise valid atmosphere profile",
	)
	_check(_has_exact_zero_authority(world_report.authority), "world composition retains the exact zero-authority roster")

	var frame := CoordinateFrameScript.new() as PlanetaryCoordinateFrame
	var origin := _orbital_coordinate(0, 0, 0, Vector3.ZERO)
	var configured := frame.configure(
		&"ember_body", 120_000.0, &"ember_system", 1_000_000.0,
		origin, Vector3.UP, Vector3.FORWARD, 10_000.0, origin,
	)
	var landing_report := LandingValidatorScript.new().validate_composition(
		world, terrain, frame.get_snapshot(), region,
	)
	_check(
		configured.accepted and landing_report.valid
			and landing_report.world_id == &"ember_moon"
			and landing_report.body_id == &"ember_body"
			and landing_report.region_id == &"ember_caldera",
		"the sole region joins the world, terrain, and a configured detached coordinate frame",
	)
	_check(_has_exact_zero_authority(landing_report.authority), "landing composition retains the exact zero-authority roster")


func _test_detachment_and_resource_round_trip() -> void:
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var region := load(REGION_PATH) as PlanetaryLandingRegionDefinition
	var report := WorldValidatorScript.new().validate_composition(world, null, terrain)
	(report.surface_radius_bounds_meters as Dictionary)["maximum"] = -1.0
	(report.evidence as Dictionary)["terrain"] = {"status": &"tampered"}
	var fresh := WorldValidatorScript.new().validate_composition(world, null, terrain)
	_check(
		fresh.valid
			and float(fresh.surface_radius_bounds_meters.maximum) == 128_500.0
			and (fresh.evidence.terrain as Dictionary).status == &"modern_interpretation",
		"composition reports are detached from authored resources and later validations",
	)

	var round_trip_world := _round_trip(world, "ember_moon_world") as PlanetaryWorldDefinition
	var round_trip_terrain := _round_trip(terrain, "ember_basalt_terrain") as PlanetaryTerrainProfile
	var round_trip_region := _round_trip(region, "ember_caldera_landing_region") as PlanetaryLandingRegionDefinition
	_check(
		round_trip_world != null and round_trip_terrain != null and round_trip_region != null,
		"all three authored definitions survive Resource serialization",
	)
	_check(
		round_trip_world.world_id == &"ember_moon"
			and round_trip_world.landing_region_ids == PackedStringArray(["ember_caldera"])
			and round_trip_terrain.profile_id == &"ember_basalt_terrain"
			and round_trip_region.body_id == &"ember_body"
			and round_trip_region.body_local_basis.y == Vector3.UP,
		"round trips preserve exact identity, roster, datum ownership, and radial basis",
	)


func _round_trip(resource: Resource, stem: String) -> Resource:
	var path := "user://%s_round_trip.tres" % stem
	var save_error := ResourceSaver.save(resource.duplicate(true), path)
	if save_error != OK:
		_failures.append("failed to save %s: %s" % [stem, error_string(save_error)])
		return null
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			_failures.append("failed to remove %s round trip: %s" % [stem, error_string(remove_error)])
	return loaded


func _orbital_coordinate(cell_x: int, cell_y: int, cell_z: int, offset: Vector3) -> Dictionary:
	return {
		"schema_version": CoordinateFrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": &"ember_system",
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset,
	}


func _has_exact_zero_authority(authority: Dictionary) -> bool:
	if authority.size() != COMMON_AUTHORITY_KEYS.size():
		return false
	for key in COMMON_AUTHORITY_KEYS:
		if not authority.has(key) or not authority[key] is bool or bool(authority[key]):
			return false
	return true


func _all_boolean_values_false(authority: Dictionary) -> bool:
	if authority.is_empty():
		return false
	for value in authority.values():
		if not value is bool or bool(value):
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
	_check(_assertions == EXPECTED_ASSERTIONS - 1, "the focused assertion roster remains exact")
	print("EMBER_MOON_AUTHORED_DEFINITIONS_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("EMBER_MOON_AUTHORED_DEFINITIONS_TEST_OK")
		quit(0)
		return
	print("EMBER_MOON_AUTHORED_DEFINITIONS_TEST_FAILURES: %s" % _failures)
	quit(1)
