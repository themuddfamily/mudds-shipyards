extends SceneTree

const WorldCompositionValidatorScript := preload("res://scripts/world/planetary_world_composition_validator.gd")
const LandingCompositionValidatorScript := preload("res://scripts/world/planetary_landing_composition_validator.gd")
const CoordinateFrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")
const WORLD := preload("res://assets/world/planets/aurora_temperate_world.tres")
const ATMOSPHERE := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")
const TERRAIN := preload("res://assets/world/planets/aurora_temperate_terrain.tres")
const LANDING := preload("res://assets/world/planets/aurora_foundation_landing.tres")
const EXPECTED_ASSERTIONS := 8
var failures := PackedStringArray()
var assertions := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene := SCENE.instantiate() as AuroraTemperateAuthoredScene
	root.add_child(scene)
	await process_frame
	check(WORLD.is_definition_valid() and ATMOSPHERE.is_definition_valid() and TERRAIN.is_profile_valid() and LANDING.is_definition_valid() and WORLD.scene_path == scene.scene_file_path, "Aurora world, atmosphere, terrain, landing, and scene path are exact")
	var world_report := WorldCompositionValidatorScript.new().validate_composition(WORLD, ATMOSPHERE, TERRAIN)
	check(world_report.valid and world_report.world_id == &"aurora_temperate_world" and world_report.atmosphere_profile_id == &"aurora_temperate_atmosphere" and world_report.terrain_profile_id == &"aurora_temperate_terrain" and world_report.radius_datum == &"body_center_to_sea_level", "Aurora atmosphere resolves through the exact world composition contract")
	var frame := CoordinateFrameScript.new() as PlanetaryCoordinateFrame
	var origin := _orbital_origin()
	var configured := frame.configure(LANDING.body_id, WORLD.body_radius_metres, &"aurora_foundation_system", 1000000.0, origin, Vector3.UP, Vector3.FORWARD, 10000.0, origin)
	var landing_report := LandingCompositionValidatorScript.new().validate_composition(WORLD, TERRAIN, frame.get_snapshot(), LANDING)
	check(configured.accepted and landing_report.valid and landing_report.world_id == WORLD.world_id and landing_report.body_id == LANDING.body_id and landing_report.region_id == LANDING.region_id, "Aurora landing resolves through its configured +Y coordinate frame")
	check(scene.get_node("LandingRegion").position == Vector3.UP * 120000.0 and scene.get_node("LandingRegion/WalkablePatch").collision_layer == 1 and scene.get_node("LandingRegion/WalkablePatch").collision_mask == 0, "bounded +Y landing patch has World-only collision")
	var environments := scene.find_children("*", "WorldEnvironment", true, false)
	check(environments.size() == 1 and environments[0] == scene.get_node("AuroraAtmosphereComposition/WorldEnvironment") and not scene.is_processing() and bool(scene.audit().valid), "composition remains the exactly-one WorldEnvironment owner and scene has no cadence")
	check(scene.get_node("LandingRegion/Markers/ApproachEntry").position == Vector3(0,60,300) and scene.get_node("LandingRegion/Markers/AuroraEgress").position == Vector3(18,0,0), "scene markers match the bounded landing declaration")
	var audit := scene.audit()
	var surface_content := audit.get("surface_content", {}) as Dictionary
	check(surface_content.get("route_id") == &"aurora_pad_to_staging" and surface_content.get("route_points_region_local_m") == PackedVector3Array([Vector3.ZERO, Vector3(18,0,0), Vector3(42,0,0)]) and (surface_content.get("landmark_positions_region_local_m", {}) as Dictionary).get(&"aurora_staging") == Vector3(42,0,0) and not bool(surface_content.get("traversable", true)) and not bool(surface_content.get("route_authority", true)) and not bool((audit.get("authority", {}) as Dictionary).get("surface_route", true)), "Aurora publishes only the exact detached pad-to-staging route and landmark data")
	(scene.get_node("LandingRegion/Markers/AuroraStaging") as Marker3D).position.x += 1.0
	check(not bool(scene.audit().valid) and (scene.audit().get("errors", PackedStringArray()) as PackedStringArray).has("surface_route_marker_drift"), "route landmark mutation fails the detached audit closed")
	print("AURORA_TEMPERATE_AUTHORED_SCENE_ASSERTIONS: %d" % assertions)
	if assertions != EXPECTED_ASSERTIONS: failures.append("assertion_count")
	if failures.is_empty(): print("AURORA_TEMPERATE_AUTHORED_SCENE_TEST_OK"); quit(0); return
	print("AURORA_TEMPERATE_AUTHORED_SCENE_TEST_FAILED: %s" % ", ".join(failures)); quit(1)
func check(value: bool, label: String) -> void:
	assertions += 1
	if value: print("PASS: %s" % label)
	else: failures.append(label); push_error("FAIL: %s" % label)

func _orbital_origin() -> Dictionary:
	return {"schema_version": CoordinateFrameScript.COORDINATE_SCHEMA_VERSION, "frame_id": &"aurora_foundation_system", "cell_x": 0, "cell_y": 0, "cell_z": 0, "offset_meters": Vector3.ZERO}
