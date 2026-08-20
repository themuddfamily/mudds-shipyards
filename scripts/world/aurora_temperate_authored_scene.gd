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
const SURFACE_ROUTE_ID := &"aurora_pad_to_staging"
const SURFACE_ROUTE_EGRESS_ID := &"aurora_egress"
const SURFACE_ROUTE_STAGING_ID := &"aurora_staging"
const SURFACE_LANDMARK_MARKER_PATHS := {
	&"aurora_pad": ^"LandingRegion/Markers/AuroraPad",
	&"aurora_egress": ^"LandingRegion/Markers/AuroraEgress",
	&"aurora_staging": ^"LandingRegion/Markers/AuroraStaging",
}

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
	_validate_surface_route(errors, landing)
	var environments := find_children("*", "WorldEnvironment", true, false)
	if environments.size() != 1 or environments[0] != get_node_or_null("AuroraAtmosphereComposition/WorldEnvironment"):
		errors.append("world_environment_census_drift")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	return {"valid": errors.is_empty(), "errors": errors, "world_composition": world_composition, "landing_composition": landing_composition, "surface_content": _surface_content_snapshot(landing), "authority": {"renderer": true, "gameplay": false, "streaming": false, "physics": false, "world_generation": false, "terrain_generation": false, "collision_generation": false, "origin_shift": false, "save": false, "network": false, "audio": false, "camera": false, "surface_route": false}}.duplicate(true)


func _validate_surface_route(errors: PackedStringArray, landing: PlanetaryLandingRegionDefinition) -> void:
	if landing == null:
		errors.append("surface_route_resource_missing")
		return
	var anchors := landing.get_surface_route_anchor_snapshot()
	var pads := landing.get_touchdown_pad_snapshot()
	if anchors.size() != 2 or pads.size() != 1 \
			or StringName((pads[0] as Dictionary).get("pad_id", &"")) != &"aurora_pad" \
			or StringName((pads[0] as Dictionary).get("egress_anchor_id", &"")) != SURFACE_ROUTE_EGRESS_ID:
		errors.append("surface_route_resource_drift")
		return
	var expected_positions := {
		&"aurora_pad": (pads[0] as Dictionary).get("transform_region_local_m", Transform3D.IDENTITY).origin,
		SURFACE_ROUTE_EGRESS_ID: Vector3(18.0, 0.0, 0.0),
		SURFACE_ROUTE_STAGING_ID: Vector3(42.0, 0.0, 0.0),
	}
	for index in anchors.size():
		var anchor := anchors[index] as Dictionary
		var anchor_id := StringName(anchor.get("anchor_id", &""))
		var expected_id := SURFACE_ROUTE_EGRESS_ID if index == 0 else SURFACE_ROUTE_STAGING_ID
		if anchor_id != expected_id \
				or anchor.get("position_region_local_m", Vector3.INF) != expected_positions.get(anchor_id, Vector3.INF):
			errors.append("surface_route_resource_drift")
			return
	for landmark_id: StringName in SURFACE_LANDMARK_MARKER_PATHS:
		var marker := get_node_or_null(SURFACE_LANDMARK_MARKER_PATHS[landmark_id]) as Marker3D
		if marker == null or marker.position != expected_positions[landmark_id]:
			errors.append("surface_route_marker_drift")
			return


func _surface_content_snapshot(landing: PlanetaryLandingRegionDefinition) -> Dictionary:
	var route_points := PackedVector3Array()
	var landmark_positions := {}
	if landing != null:
		var pads := landing.get_touchdown_pad_snapshot()
		if pads.size() == 1:
			route_points.append(((pads[0] as Dictionary).get("transform_region_local_m", Transform3D.IDENTITY) as Transform3D).origin)
		for anchor in landing.get_surface_route_anchor_snapshot():
			var record := anchor as Dictionary
			var anchor_id := StringName(record.get("anchor_id", &""))
			var position := record.get("position_region_local_m", Vector3.INF) as Vector3
			if anchor_id == SURFACE_ROUTE_EGRESS_ID or anchor_id == SURFACE_ROUTE_STAGING_ID:
				route_points.append(position)
				landmark_positions[anchor_id] = position
		if not route_points.is_empty():
			landmark_positions[&"aurora_pad"] = route_points[0]
	return {
		"content_class": &"NEW",
		"status": &"modern_interpretation",
		"route_id": SURFACE_ROUTE_ID,
		"route_points_region_local_m": route_points,
		"landmark_marker_paths": SURFACE_LANDMARK_MARKER_PATHS.duplicate(true),
		"landmark_positions_region_local_m": landmark_positions,
		"traversable": false,
		"route_authority": false,
	}.duplicate(true)


func _orbital_origin() -> Dictionary:
	return {
		"schema_version": PlanetaryCoordinateFrame.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": 0,
		"cell_y": 0,
		"cell_z": 0,
		"offset_meters": Vector3.ZERO,
	}
