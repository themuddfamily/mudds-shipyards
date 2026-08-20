class_name AuroraTemperateAuthoredScene
extends Node3D

const WORLD_PATH := "res://assets/world/planets/aurora_temperate_world.tres"
const TERRAIN_PATH := "res://assets/world/planets/aurora_temperate_terrain.tres"
const LANDING_PATH := "res://assets/world/planets/aurora_foundation_landing.tres"
const BODY_RADIUS_M := 120000.0

func _ready() -> void:
	set_process(false)
	set_physics_process(false)

func audit() -> Dictionary:
	var errors := PackedStringArray()
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var landing := load(LANDING_PATH) as PlanetaryLandingRegionDefinition
	if world == null or terrain == null or landing == null or not world.is_definition_valid() or not terrain.is_profile_valid() or not landing.is_definition_valid():
		errors.append("resource_contract_invalid")
	if world != null and world.scene_path != scene_file_path:
		errors.append("world_scene_path_drift")
	if get_node_or_null("BodyVisual") == null or get_node_or_null("LandingRegion/WalkablePatch/CollisionShape3D") == null or get_node_or_null("AuroraAtmosphereComposition") == null:
		errors.append("required_node_missing")
	var region := get_node_or_null("LandingRegion") as Node3D
	if region == null or region.position != Vector3.UP * BODY_RADIUS_M or region.basis != Basis.IDENTITY:
		errors.append("landing_transform_drift")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	return {"valid": errors.is_empty(), "errors": errors, "authority": {"renderer": true, "gameplay": false, "streaming": false, "physics": false, "world_generation": false, "terrain_generation": false, "collision_generation": false, "origin_shift": false, "save": false, "network": false, "audio": false, "camera": false}}.duplicate(true)
