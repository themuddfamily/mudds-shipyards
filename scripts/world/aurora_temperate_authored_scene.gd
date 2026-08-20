class_name AuroraTemperateAuthoredScene
extends Node3D

const WORLD_PATH := "res://assets/world/planets/aurora_temperate_world.tres"
const ATMOSPHERE_PATH := "res://assets/world/planets/aurora_temperate_atmosphere.tres"
const TERRAIN_PATH := "res://assets/world/planets/aurora_temperate_terrain.tres"
const LANDING_PATH := "res://assets/world/planets/aurora_foundation_landing.tres"
const BODY_RADIUS_M := 120000.0
const ORBITAL_FRAME_ID := &"aurora_foundation_system"
const ORBITAL_CELL_SIZE_M := 1000000.0
const ORIGIN_SHIFT_THRESHOLD_M := 10000.0

func _ready() -> void:
	set_process(false)
	set_physics_process(false)

func audit() -> Dictionary:
	var errors := PackedStringArray()
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var atmosphere := load(ATMOSPHERE_PATH) as PlanetaryAtmosphereProfile
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var landing := load(LANDING_PATH) as PlanetaryLandingRegionDefinition
	if world == null or atmosphere == null or terrain == null or landing == null or not world.is_definition_valid() or not atmosphere.is_definition_valid() or not terrain.is_profile_valid() or not landing.is_definition_valid():
		errors.append("resource_contract_invalid")
	if world != null and world.scene_path != scene_file_path:
		errors.append("world_scene_path_drift")
	var world_composition := PlanetaryWorldCompositionValidator.new().validate_composition(
		world, atmosphere, terrain,
	)
	if not bool(world_composition.get("valid", false)):
		errors.append("world_composition_invalid")

	var coordinate_frame := PlanetaryCoordinateFrame.new()
	var frame_configuration := {"accepted": false}
	if world != null and landing != null:
		var origin := _orbital_origin()
		frame_configuration = coordinate_frame.configure(
			landing.body_id, world.body_radius_metres, ORBITAL_FRAME_ID,
			ORBITAL_CELL_SIZE_M, origin, Vector3.UP, Vector3.FORWARD,
			ORIGIN_SHIFT_THRESHOLD_M, origin,
		)
	var landing_composition := PlanetaryLandingCompositionValidator.new().validate_composition(
		world, terrain, coordinate_frame.get_snapshot(), landing,
	)
	if not bool(frame_configuration.get("accepted", false)) or not bool(landing_composition.get("valid", false)):
		errors.append("landing_composition_invalid")

	if get_node_or_null("BodyVisual") == null or get_node_or_null("LandingRegion/WalkablePatch/CollisionShape3D") == null or get_node_or_null("AuroraAtmosphereComposition") == null:
		errors.append("required_node_missing")
	var region := get_node_or_null("LandingRegion") as Node3D
	if region == null or region.position != Vector3.UP * BODY_RADIUS_M or region.basis != Basis.IDENTITY:
		errors.append("landing_transform_drift")
	var environments := find_children("*", "WorldEnvironment", true, false)
	if environments.size() != 1 or environments[0] != get_node_or_null("AuroraAtmosphereComposition/WorldEnvironment"):
		errors.append("world_environment_census_drift")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	return {"valid": errors.is_empty(), "errors": errors, "world_composition": world_composition, "landing_composition": landing_composition, "authority": {"renderer": true, "gameplay": false, "streaming": false, "physics": false, "world_generation": false, "terrain_generation": false, "collision_generation": false, "origin_shift": false, "save": false, "network": false, "audio": false, "camera": false}}.duplicate(true)


func _orbital_origin() -> Dictionary:
	return {
		"schema_version": PlanetaryCoordinateFrame.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": 0,
		"cell_y": 0,
		"cell_z": 0,
		"offset_meters": Vector3.ZERO,
	}
