class_name EmberMoonAuthoredScene
extends Node3D

## Static, body-centred visual and collision witness for the bounded Ember Moon
## vertical slice. It loads copied definition data, validates its own authored
## nodes, and exposes pure terrain-LOD hints. It never places or streams itself.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"ember-moon-authored-scene"
const WORLD_ID: StringName = &"ember_moon"
const BODY_ID: StringName = &"ember_body"
const REGION_ID: StringName = &"ember_caldera"
const TERRAIN_PROFILE_ID: StringName = &"ember_basalt_terrain"
const WORLD_PATH := "res://assets/world/planets/ember_moon_world.tres"
const TERRAIN_PATH := "res://assets/world/planets/ember_basalt_terrain.tres"
const REGION_PATH := "res://assets/world/planets/ember_caldera_landing_region.tres"
const SCENE_PATH := "res://scenes/world/planets/ember_moon.tscn"
const EVIDENCE_PATH := "res://docs/EMBER_MOON_AUTHORED_SCENE.md"

const BODY_RADIUS_M := 120_000.0
const BODY_VISUAL_RADIUS_M := 119_999.0
const BODY_VISUAL_INSET_M := BODY_RADIUS_M - BODY_VISUAL_RADIUS_M
const CALDERA_FLOOR_RADIUS_M := 256.0
const CALDERA_RIM_INNER_RADIUS_M := 240.0
const CALDERA_RIM_OUTER_RADIUS_M := 280.0
const WALKABLE_PATCH_SIZE_M := Vector3(96.0, 0.5, 96.0)
const WALKABLE_PATCH_POSITION_REGION_LOCAL_M := Vector3(0.0, -0.25, 0.0)
const PAD_VISUAL_SIZE_M := Vector3(28.0, 0.04, 32.0)
const PAD_VISUAL_POSITION_REGION_LOCAL_M := Vector3(0.0, 0.02, 0.0)
const SURFACE_ROUTE_ID: StringName = &"ember_caldera_pad_to_staging"
const SURFACE_ROUTE_WIDTH_M := 4.0
const SURFACE_ROUTE_VISUAL_SIZE_M := Vector3(28.0, 0.02, SURFACE_ROUTE_WIDTH_M)
const SURFACE_ROUTE_VISUAL_POSITION_M := Vector3(28.0, 0.01, 0.0)
const SURFACE_ROUTE_POINTS_M := [
	Vector3(0.0, 0.0, 0.0),
	Vector3(18.0, 0.0, 0.0),
	Vector3(42.0, 0.0, 0.0),
]
const PAD_GUIDE_SIZE_M := Vector3(0.5, 1.8, 0.5)
const PORT_PAD_GUIDE_POSITION_M := Vector3(14.8, 0.9, -5.0)
const STARBOARD_PAD_GUIDE_POSITION_M := Vector3(14.8, 0.9, 5.0)
const PAD_GUIDE_INSTANCE_COUNT := 2
const PAD_GUIDE_BATCH_BOUNDS := AABB(
	Vector3(14.55, 0.0, -5.25),
	Vector3(0.5, 1.8, 10.5),
)
const APPROACH_CUE_BAR_SIZE_M := Vector3(0.72, 0.03, 4.0)
const APPROACH_CUE_CENTRE_Z_M := [20.0, 27.0, 34.0, 41.0]
const APPROACH_CUE_INSTANCE_COUNT := 8
const APPROACH_CUE_Y_M := 0.035
const ORBITAL_CUE_INSTANCE_COUNT := 3
const ORBITAL_CUE_TIP_M := Vector3(0.0, 3.0, 50.0)
const ORBITAL_CUE_PORT_END_M := Vector3(-110.0, 3.0, 220.0)
const ORBITAL_CUE_STARBOARD_END_M := Vector3(110.0, 3.0, 220.0)
const ORBITAL_CUE_THRESHOLD_SIZE_M := Vector3(90.0, 3.0, 8.0)
const ORBITAL_CUE_ARM_WIDTH_M := 8.0
const ORBITAL_CUE_MAXIMUM_RADIUS_M := 252.0
const SAMPLE_RACK_SIZE_M := Vector3(4.0, 1.0, 1.4)
const SAMPLE_RACK_POSITION_M := Vector3(28.0, 0.5, -7.0)
const RELAY_ROOT_POSITION_M := Vector3(42.0, 0.0, 7.0)
const RELAY_BASE_SIZE_M := Vector3(2.4, 0.35, 2.4)
const RELAY_BASE_POSITION_M := Vector3(0.0, 0.175, 0.0)
const RELAY_MAST_RADIUS_M := 0.18
const RELAY_MAST_HEIGHT_M := 3.0
const RELAY_MAST_POSITION_M := Vector3(0.0, 1.675, 0.0)
const RELAY_HEAD_SIZE_M := Vector3(0.9, 0.45, 0.9)
const RELAY_HEAD_POSITION_M := Vector3(0.0, 3.25, 0.0)
const GANTRY_ROOT_POSITION_M := Vector3(34.0, 0.0, 0.0)
const GANTRY_PYLON_SIZE_M := Vector3(1.2, 7.2, 1.4)
const GANTRY_PORT_PYLON_POSITION_M := Vector3(0.0, 3.6, -5.2)
const GANTRY_STARBOARD_PYLON_POSITION_M := Vector3(0.0, 3.6, 5.2)
const GANTRY_PYLON_LEAN_RADIANS := 0.08
const GANTRY_BEAM_SIZE_M := Vector3(1.2, 0.8, 4.8)
const GANTRY_PORT_BEAM_POSITION_M := Vector3(0.0, 7.0, -2.7)
const GANTRY_STARBOARD_BEAM_POSITION_M := Vector3(0.0, 6.65, 2.7)
const GANTRY_PORT_BEAM_TILT_RADIANS := 0.06
const GANTRY_STARBOARD_BEAM_TILT_RADIANS := -0.14
const GANTRY_BOOM_RADIUS_M := 0.25
const GANTRY_BOOM_HEIGHT_M := 4.0
const GANTRY_BOOM_POSITION_M := Vector3(0.0, 9.0, -1.9)
const GANTRY_BOOM_TILT_RADIANS := 0.18
const GANTRY_SENSOR_SIZE_M := Vector3(2.6, 0.45, 1.2)
const GANTRY_SENSOR_POSITION_M := Vector3(0.36, 10.95, -1.9)
const GANTRY_SENSOR_TILT_RADIANS := -0.12
const GANTRY_ACCESS_POSITION_M := Vector3(34.0, 0.0, -7.0)
const GANTRY_PYLON_MIN_ROUTE_CLEARANCE_M := 4.2
const BUNKER_ROOT_POSITION_M := Vector3(-24.0, 0.0, -24.0)
const BUNKER_YAW_RADIANS := -PI * 0.25
const BUNKER_BASE_SIZE_M := Vector3(9.0, 0.4, 7.0)
const BUNKER_BASE_POSITION_M := Vector3(0.0, 0.2, 0.0)
const BUNKER_SHELL_SIZE_M := Vector3(7.4, 2.8, 5.6)
const BUNKER_SHELL_POSITION_M := Vector3(0.0, 1.75, 0.0)
const BUNKER_ROOF_SIZE_M := Vector3(8.4, 0.5, 6.6)
const BUNKER_ROOF_POSITION_M := Vector3(0.0, 3.4, 0.0)
const BUNKER_DOOR_SIZE_M := Vector3(0.3, 2.1, 2.2)
const BUNKER_DOOR_POSITION_M := Vector3(3.82, 1.55, 0.0)
const BUNKER_VENT_RADIUS_M := 0.28
const BUNKER_VENT_HEIGHT_M := 1.1
const BUNKER_PORT_VENT_POSITION_M := Vector3(-2.0, 4.2, -1.6)
const BUNKER_STARBOARD_VENT_POSITION_M := Vector3(-2.0, 4.2, 1.6)
const BUNKER_ACCESS_POSITION_M := Vector3(-17.5, 0.0, -17.5)
const BUNKER_MIN_PAD_CLEARANCE_M := 2.3
const BUNKER_MIN_ROUTE_CLEARANCE_M := 18.3

const BODY_COLOR := Color("552817")
const FLOOR_COLOR := Color("292421")
const RIM_COLOR := Color("713a25")
const PAD_COLOR := Color("a85f32")
const ROUTE_COLOR := Color("d28245")
const GUIDE_COLOR := Color("71d9da")
const EQUIPMENT_COLOR := Color("4f4942")
const RELAY_COLOR := Color("e1a458")
const DERELICT_ALLOY_COLOR := Color("353a38")
const DERELICT_OXIDE_COLOR := Color("8c462c")
const BUNKER_SHELL_COLOR := Color("6f5946")
const BUNKER_DOOR_COLOR := Color("bd7547")

const EXPECTED_NODE_COUNT := 64
const EXPECTED_MESH_INSTANCE_COUNT := 21
const EXPECTED_MULTI_MESH_INSTANCE_COUNT := 3
const EXPECTED_MULTI_MESH_COPY_COUNT := 13
const EXPECTED_STATIC_BODY_COUNT := 7
const EXPECTED_COLLISION_SHAPE_COUNT := 19
const MAXIMUM_TRIANGLE_COUNT := 8192
const WORLD_LAYER := PhysicsLayers.WORLD_BODY_LAYER
const WORLD_MASK := PhysicsLayers.WORLD_BODY_MASK

const MARKER_NODE_PATHS := {
	&"caldera_pad": ^"LandingRegion/Markers/CalderaPad",
	&"caldera_approach": ^"LandingRegion/Markers/ApproachEntry",
	&"caldera_pad_egress": ^"LandingRegion/Markers/PadEgress",
	&"caldera_staging_gate": ^"LandingRegion/Markers/StagingGate",
}
const SURFACE_LANDMARK_NODE_PATHS := {
	&"ember_pad_guidance_port": ^"LandingRegion/SurfaceLandmarks/PadGuidancePort",
	&"ember_pad_guidance_starboard": ^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard",
	&"ember_sample_rack": ^"LandingRegion/SurfaceLandmarks/SampleRack",
	&"ember_staging_relay": ^"LandingRegion/SurfaceLandmarks/StagingRelay",
	&"ember_derelict_survey_gantry": ^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry",
	&"ember_survey_service_bunker": ^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker",
}
const SURFACE_MARKER_NODE_PATHS := {
	&"ember_pad_guidance_threshold": ^"LandingRegion/SurfaceLandmarks/RouteMarkers/PadGuidanceThreshold",
	&"ember_sample_rack_access": ^"LandingRegion/SurfaceLandmarks/RouteMarkers/SampleRackAccess",
	&"ember_staging_relay_access": ^"LandingRegion/SurfaceLandmarks/RouteMarkers/StagingRelayAccess",
	&"ember_derelict_survey_gantry_access": ^"LandingRegion/SurfaceLandmarks/RouteMarkers/DerelictSurveyGantryAccess",
	&"ember_survey_service_bunker_access": ^"LandingRegion/SurfaceLandmarks/RouteMarkers/SurveyServiceBunkerAccess",
}
const INTEGRATION_AUTHORITY_KEYS := [
	"streaming", "game_flow", "gameplay", "landing_decision", "ship_movement",
	"player_movement", "world_generation", "terrain_generation",
	"collision_generation", "origin_shift", "save", "network", "reward",
	"audio", "camera", "lighting",
]

var _world_definition: PlanetaryWorldDefinition
var _terrain_profile: PlanetaryTerrainProfile
var _landing_region: PlanetaryLandingRegionDefinition
var _terrain_lod_policy: PlanetaryTerrainLodPolicy
var _initialized := false


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_configure_landing_approach_cues()
	_configure_orbital_landing_datum_cue()
	_configure_pad_guide_visuals()
	_initialize_contract()


func get_world_id() -> StringName:
	return WORLD_ID


func get_body_id() -> StringName:
	return BODY_ID


func get_region_id() -> StringName:
	return REGION_ID


## Detached body-local transforms keyed by authored marker identity.
func get_body_local_marker_transforms() -> Dictionary:
	var result := {}
	var landing_root := get_node_or_null(^"LandingRegion") as Node3D
	if landing_root == null:
		return result
	for marker_id: StringName in MARKER_NODE_PATHS:
		var marker := get_node_or_null(MARKER_NODE_PATHS[marker_id]) as Marker3D
		if marker != null:
			result[marker_id] = landing_root.transform * marker.transform
	return result.duplicate(true)


## Detached body-local transforms for the bounded surface-content access points.
## These are presentation/route references only, never navigation authority.
func get_surface_landmark_marker_transforms() -> Dictionary:
	var result := {}
	var landing_root := get_node_or_null(^"LandingRegion") as Node3D
	if landing_root == null:
		return result
	for marker_id: StringName in SURFACE_MARKER_NODE_PATHS:
		var marker := get_node_or_null(SURFACE_MARKER_NODE_PATHS[marker_id]) as Marker3D
		if marker != null:
			result[marker_id] = landing_root.transform * marker.transform
	return result.duplicate(true)


## Pure selection seam. The returned policy hint never changes scene state.
func evaluate_terrain_lod_hint(
		camera_to_surface_distance_meters: Variant,
		collision_needed: Variant
	) -> Dictionary:
	if not _initialized or _terrain_lod_policy == null:
		return {
			"accepted": false,
			"reason": &"scene_contract_not_initialized",
		}.duplicate(true)
	return _terrain_lod_policy.evaluate(
		camera_to_surface_distance_meters,
		collision_needed,
	).duplicate(true)


func get_snapshot() -> Dictionary:
	var lod_snapshot := _terrain_lod_policy.get_snapshot() \
		if _terrain_lod_policy != null else {}
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"initialized": _initialized,
		"identity": {
			"world_id": WORLD_ID,
			"body_id": BODY_ID,
			"region_id": REGION_ID,
			"terrain_profile_id": TERRAIN_PROFILE_ID,
		},
		"resource_paths": {
			"world": WORLD_PATH,
			"terrain": TERRAIN_PATH,
			"landing_region": REGION_PATH,
			"scene": SCENE_PATH,
		},
		"coordinate_contract": {
			"scene_root_reference": &"body_center",
			"body_radius_m": BODY_RADIUS_M,
			"body_visual_radius_m": BODY_VISUAL_RADIUS_M,
			"body_visual_inset_m": BODY_VISUAL_INSET_M,
			"landing_region_transform_body_local": _expected_landing_region_transform(),
			"standard_float_spacing_at_landing_m": 0.0078125,
		},
		"marker_transforms_body_local": get_body_local_marker_transforms(),
		"surface_content": {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"route_id": SURFACE_ROUTE_ID,
			"route_width_m": SURFACE_ROUTE_WIDTH_M,
			"route_points_region_local_m": SURFACE_ROUTE_POINTS_M.duplicate(),
			"landmark_ids": SURFACE_LANDMARK_NODE_PATHS.keys(),
			"marker_transforms_body_local": get_surface_landmark_marker_transforms(),
		},
		"geometry": {
			"caldera_floor_radius_m": CALDERA_FLOOR_RADIUS_M,
			"caldera_rim_inner_radius_m": CALDERA_RIM_INNER_RADIUS_M,
			"caldera_rim_outer_radius_m": CALDERA_RIM_OUTER_RADIUS_M,
			"pad_visual_size_m": PAD_VISUAL_SIZE_M,
			"surface_route_visual_size_m": SURFACE_ROUTE_VISUAL_SIZE_M,
			"pad_guide_size_m": PAD_GUIDE_SIZE_M,
			"approach_cue_bar_size_m": APPROACH_CUE_BAR_SIZE_M,
			"approach_cue_centres_z_m": APPROACH_CUE_CENTRE_Z_M.duplicate(),
			"approach_cue_instance_count": APPROACH_CUE_INSTANCE_COUNT,
			"orbital_landing_cue_instance_count": ORBITAL_CUE_INSTANCE_COUNT,
			"orbital_landing_cue_maximum_radius_m": ORBITAL_CUE_MAXIMUM_RADIUS_M,
			"orbital_landing_navigation_direction": Vector3(0.0, 0.0, -1.0),
			"sample_rack_size_m": SAMPLE_RACK_SIZE_M,
			"relay_base_size_m": RELAY_BASE_SIZE_M,
			"relay_mast_radius_m": RELAY_MAST_RADIUS_M,
			"relay_mast_height_m": RELAY_MAST_HEIGHT_M,
			"relay_head_size_m": RELAY_HEAD_SIZE_M,
			"derelict_gantry_position_m": GANTRY_ROOT_POSITION_M,
			"derelict_gantry_height_m": GANTRY_SENSOR_POSITION_M.y + GANTRY_SENSOR_SIZE_M.y * 0.5,
			"derelict_gantry_span_m": GANTRY_STARBOARD_PYLON_POSITION_M.z
				- GANTRY_PORT_PYLON_POSITION_M.z + GANTRY_PYLON_SIZE_M.z,
			"survey_bunker_position_m": BUNKER_ROOT_POSITION_M,
			"survey_bunker_footprint_m": Vector2(BUNKER_BASE_SIZE_M.x, BUNKER_BASE_SIZE_M.z),
			"survey_bunker_height_m": BUNKER_PORT_VENT_POSITION_M.y + BUNKER_VENT_HEIGHT_M * 0.5,
			"survey_bunker_minimum_pad_clearance_m": BUNKER_MIN_PAD_CLEARANCE_M,
		},
		"collision": {
			"shape": &"box",
			"size_m": WALKABLE_PATCH_SIZE_M,
			"position_region_local_m": WALKABLE_PATCH_POSITION_REGION_LOCAL_M,
			"top_surface_region_local_y_m": 0.0,
			"layer": WORLD_LAYER,
			"mask": WORLD_MASK,
			"landmark_static_body_count": 6,
			"solid_landmark_collision_shape_count": 18,
			"route_clear_half_width_m": SURFACE_ROUTE_WIDTH_M * 0.5,
		},
		"terrain_lod_policy": lod_snapshot,
		"evidence": _evidence_report(),
		"owned_capabilities": _owned_capabilities(),
		"integration_authority": _integration_authority(),
		"performance_budget": _performance_budget(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors: Array[Dictionary] = []
	if not _initialized:
		_append_error(errors, &"scene_contract_not_initialized", &"scene", "scene contract did not initialize")
	_validate_resource_join(errors)
	_validate_topology(errors)
	_validate_transforms(errors)
	_validate_geometry(errors)
	_validate_collision(errors)
	_validate_surface_content(errors)
	_validate_forbidden_nodes(errors)
	var performance := _performance_census()
	_validate_performance(errors, performance)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"error_codes": _error_codes(errors),
		"snapshot": get_snapshot(),
		"performance": performance,
		"evidence": _evidence_report(),
		"owned_capabilities": _owned_capabilities(),
		"integration_authority": _integration_authority(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _initialize_contract() -> void:
	var loaded_world := ResourceLoader.load(WORLD_PATH) as PlanetaryWorldDefinition
	var loaded_terrain := ResourceLoader.load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var loaded_region := ResourceLoader.load(REGION_PATH) as PlanetaryLandingRegionDefinition
	_world_definition = loaded_world.duplicate(true) as PlanetaryWorldDefinition \
		if loaded_world != null else null
	_terrain_profile = loaded_terrain.duplicate(true) as PlanetaryTerrainProfile \
		if loaded_terrain != null else null
	_landing_region = loaded_region.duplicate(true) as PlanetaryLandingRegionDefinition \
		if loaded_region != null else null
	_terrain_lod_policy = PlanetaryTerrainLodPolicy.new()
	if _terrain_profile != null:
		_terrain_lod_policy.configure(_terrain_profile)
	_initialized = true


func _validate_resource_join(errors: Array[Dictionary]) -> void:
	if _world_definition == null or not _world_definition.is_definition_valid():
		_append_error(errors, &"invalid_world_definition", &"world", "copied Ember world definition is missing or invalid")
		return
	if _terrain_profile == null or not _terrain_profile.is_profile_valid():
		_append_error(errors, &"invalid_terrain_profile", &"terrain", "copied Ember terrain profile is missing or invalid")
		return
	if _landing_region == null or not _landing_region.is_definition_valid():
		_append_error(errors, &"invalid_landing_region", &"landing_region", "copied Ember landing region is missing or invalid")
		return
	var composition := PlanetaryWorldCompositionValidator.new().validate_composition(
		_world_definition, null, _terrain_profile,
	)
	if not bool(composition.get("valid", false)):
		_append_error(errors, &"invalid_airless_composition", &"world", "Ember world and terrain do not compose through the airless branch")
	if _world_definition.world_id != WORLD_ID \
			or _world_definition.scene_path != SCENE_PATH \
			or _world_definition.terrain_definition_id != TERRAIN_PROFILE_ID \
			or _world_definition.landing_region_ids != PackedStringArray([str(REGION_ID)]) \
			or _world_definition.has_atmosphere \
			or not _world_definition.atmosphere_definition_id.is_empty():
		_append_error(errors, &"world_identity_drift", &"world", "world identity, references, or airless branch drifted")
	if _terrain_profile.profile_id != TERRAIN_PROFILE_ID \
			or _terrain_profile.reference_planet_radius_meters != BODY_RADIUS_M \
			or _terrain_profile.minimum_elevation_meters != -2500.0 \
			or _terrain_profile.maximum_elevation_meters != 8500.0:
		_append_error(errors, &"terrain_datum_drift", &"terrain", "terrain identity or exact radial datum drifted")
	if _landing_region.world_id != WORLD_ID \
			or _landing_region.body_id != BODY_ID \
			or _landing_region.region_id != REGION_ID \
			or _landing_region.body_radius_m != BODY_RADIUS_M \
			or _landing_region.minimum_elevation_m != -2500.0 \
			or _landing_region.maximum_elevation_m != 8500.0:
		_append_error(errors, &"landing_identity_drift", &"landing_region", "landing identity or exact radial datum drifted")
	if _terrain_lod_policy == null or not bool(_terrain_lod_policy.audit().get("valid", false)):
		_append_error(errors, &"invalid_terrain_lod_policy", &"terrain_lod", "copied terrain profile did not configure the pure LOD policy")


func _validate_topology(errors: Array[Dictionary]) -> void:
	var expected := {
		^"BodyVisual": "MeshInstance3D",
		^"LandingRegion": "Node3D",
		^"LandingRegion/CalderaFloor": "MeshInstance3D",
		^"LandingRegion/CalderaRim": "MeshInstance3D",
		^"LandingRegion/PadVisual": "MeshInstance3D",
		^"LandingRegion/WalkablePatch": "StaticBody3D",
		^"LandingRegion/WalkablePatch/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/Markers": "Node3D",
		^"LandingRegion/Markers/CalderaPad": "Marker3D",
		^"LandingRegion/Markers/ApproachEntry": "Marker3D",
		^"LandingRegion/Markers/PadEgress": "Marker3D",
		^"LandingRegion/Markers/StagingGate": "Marker3D",
		^"LandingRegion/SurfaceLandmarks": "Node3D",
		^"LandingRegion/SurfaceLandmarks/LandingApproachCues": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/OrbitalLandingDatumCue": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/PadGuideVisuals": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/EgressRouteVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack/RackVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/MastVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/MastCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortPylonVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortPylonCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardPylonVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardPylonCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortBeamVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortBeamCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardBeamVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardBeamCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/SensorBoomVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/SensorBoomCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/BaseVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/BaseCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/ShellVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/ShellCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/RoofVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/RoofCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/PortVentVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/PortVentCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/StarboardVentVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/StarboardVentCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/RouteMarkers": "Node3D",
		^"LandingRegion/SurfaceLandmarks/RouteMarkers/PadGuidanceThreshold": "Marker3D",
		^"LandingRegion/SurfaceLandmarks/RouteMarkers/SampleRackAccess": "Marker3D",
		^"LandingRegion/SurfaceLandmarks/RouteMarkers/StagingRelayAccess": "Marker3D",
		^"LandingRegion/SurfaceLandmarks/RouteMarkers/DerelictSurveyGantryAccess": "Marker3D",
		^"LandingRegion/SurfaceLandmarks/RouteMarkers/SurveyServiceBunkerAccess": "Marker3D",
	}
	for path: NodePath in expected:
		var node := get_node_or_null(path)
		if node == null or not node.is_class(expected[path]):
			_append_error(errors, &"missing_or_wrong_node", StringName(str(path)), "required authored node is missing or has the wrong type")
	if _count_nodes() != EXPECTED_NODE_COUNT:
		_append_error(errors, &"node_roster_drift", &"scene", "authored scene must contain exactly thirty-six nodes")
	var landing_root := get_node_or_null(^"LandingRegion")
	var walkable := get_node_or_null(^"LandingRegion/WalkablePatch")
	var markers := get_node_or_null(^"LandingRegion/Markers")
	var landmarks := get_node_or_null(^"LandingRegion/SurfaceLandmarks")
	var route_markers := get_node_or_null(^"LandingRegion/SurfaceLandmarks/RouteMarkers")
	var relay := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay")
	var gantry := get_node_or_null(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry")
	var bunker := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker")
	if get_child_count() != 2 \
			or landing_root == null or landing_root.get_child_count() != 6 \
			or walkable == null or walkable.get_child_count() != 1 \
			or markers == null or markers.get_child_count() != 4 \
			or landmarks == null or landmarks.get_child_count() != 11 \
			or route_markers == null or route_markers.get_child_count() != 5 \
			or relay == null or relay.get_child_count() != 6 \
			or gantry == null or gantry.get_child_count() != 12 \
			or bunker == null or bunker.get_child_count() != 12:
		_append_error(errors, &"ownership_tree_drift", &"scene", "exact static ownership tree drifted")


func _validate_transforms(errors: Array[Dictionary]) -> void:
	var landing_root := get_node_or_null(^"LandingRegion") as Node3D
	if landing_root == null or landing_root.transform != _expected_landing_region_transform():
		_append_error(errors, &"landing_region_transform_mismatch", &"LandingRegion", "landing root must equal the authored body-local region frame")
	for marker_id: StringName in MARKER_NODE_PATHS:
		var marker := get_node_or_null(MARKER_NODE_PATHS[marker_id]) as Marker3D
		var expected := _expected_marker_transform(marker_id)
		if marker == null or marker.transform != expected:
			_append_error(errors, &"marker_transform_mismatch", marker_id, "marker transform diverged from the landing definition")


func _validate_geometry(errors: Array[Dictionary]) -> void:
	var body := get_node_or_null(^"BodyVisual") as MeshInstance3D
	var floor := get_node_or_null(^"LandingRegion/CalderaFloor") as MeshInstance3D
	var rim := get_node_or_null(^"LandingRegion/CalderaRim") as MeshInstance3D
	var pad := get_node_or_null(^"LandingRegion/PadVisual") as MeshInstance3D
	var route := get_node_or_null(^"LandingRegion/SurfaceLandmarks/EgressRouteVisual") as MeshInstance3D
	var approach_cues := get_node_or_null(^"LandingRegion/SurfaceLandmarks/LandingApproachCues") as MultiMeshInstance3D
	var orbital_cue := get_node_or_null(^"LandingRegion/SurfaceLandmarks/OrbitalLandingDatumCue") as MultiMeshInstance3D
	var pad_guides := get_node_or_null(^"LandingRegion/SurfaceLandmarks/PadGuideVisuals") as MultiMeshInstance3D
	var rack := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SampleRack/RackVisual") as MeshInstance3D
	var relay_base := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseVisual") as MeshInstance3D
	var relay_mast := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay/MastVisual") as MeshInstance3D
	var relay_head := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadVisual") as MeshInstance3D
	var gantry := get_node_or_null(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry") as StaticBody3D
	var bunker := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker") as StaticBody3D
	var body_mesh := body.mesh as SphereMesh if body != null else null
	var floor_mesh := floor.mesh as CylinderMesh if floor != null else null
	var rim_mesh := rim.mesh as TorusMesh if rim != null else null
	var pad_mesh := pad.mesh as BoxMesh if pad != null else null
	var route_mesh := route.mesh as BoxMesh if route != null else null
	var rack_mesh := rack.mesh as BoxMesh if rack != null else null
	var relay_base_mesh := relay_base.mesh as BoxMesh if relay_base != null else null
	var relay_mast_mesh := relay_mast.mesh as CylinderMesh if relay_mast != null else null
	var relay_head_mesh := relay_head.mesh as BoxMesh if relay_head != null else null
	if body_mesh == null or body_mesh.radius != BODY_VISUAL_RADIUS_M \
			or body_mesh.height != BODY_VISUAL_RADIUS_M * 2.0 \
			or body_mesh.radial_segments != 64 or body_mesh.rings != 32 \
			or body == null or body.transform != Transform3D.IDENTITY:
		_append_error(errors, &"body_visual_drift", &"BodyVisual", "noncolliding inset body silhouette drifted")
	if floor_mesh == null or floor_mesh.top_radius != CALDERA_FLOOR_RADIUS_M \
			or floor_mesh.bottom_radius != CALDERA_FLOOR_RADIUS_M \
			or floor_mesh.height != 2.0 or floor_mesh.radial_segments != 64 \
			or floor == null or floor.position != Vector3(0.0, -1.0, 0.0):
		_append_error(errors, &"caldera_floor_drift", &"CalderaFloor", "bounded caldera floor proxy drifted")
	if rim_mesh == null or rim_mesh.inner_radius != CALDERA_RIM_INNER_RADIUS_M \
			or rim_mesh.outer_radius != CALDERA_RIM_OUTER_RADIUS_M \
			or rim_mesh.rings != 64 or rim_mesh.ring_segments != 8 \
			or rim == null or rim.transform != Transform3D.IDENTITY:
		_append_error(errors, &"caldera_rim_drift", &"CalderaRim", "bounded caldera rim proxy drifted")
	if pad_mesh == null or pad_mesh.size != PAD_VISUAL_SIZE_M \
			or pad == null or pad.position != PAD_VISUAL_POSITION_REGION_LOCAL_M:
		_append_error(errors, &"pad_visual_drift", &"PadVisual", "authored pad visual drifted")
	if route_mesh == null or route_mesh.size != SURFACE_ROUTE_VISUAL_SIZE_M \
			or route == null or route.position != SURFACE_ROUTE_VISUAL_POSITION_M:
		_append_error(errors, &"surface_route_visual_drift", &"EgressRouteVisual", "continuous pad-to-staging route visual drifted")
	if not _landing_approach_cues_are_exact(approach_cues, pad_guides):
		_append_error(errors, &"landing_approach_cue_drift", &"LandingApproachCues", "batched final-approach chevrons drifted from their bounded passive recipe")
	if not _orbital_landing_datum_cue_is_exact(orbital_cue, route):
		_append_error(errors, &"orbital_landing_datum_cue_drift", &"OrbitalLandingDatumCue", "orbital landing-side arrow drifted from the exact approach-to-pad datum")
	if not _pad_guide_visuals_are_exact(pad_guides):
		_append_error(errors, &"pad_guidance_visual_drift", &"PadGuidance", "paired solid pad guidance recipe drifted")
	if rack_mesh == null or rack_mesh.size != SAMPLE_RACK_SIZE_M:
		_append_error(errors, &"sample_rack_visual_drift", &"SampleRack", "low solid sample-rack recipe drifted")
	if relay_base_mesh == null or relay_base_mesh.size != RELAY_BASE_SIZE_M \
			or relay_mast_mesh == null \
			or not is_equal_approx(relay_mast_mesh.top_radius, RELAY_MAST_RADIUS_M) \
			or not is_equal_approx(relay_mast_mesh.bottom_radius, RELAY_MAST_RADIUS_M) \
			or relay_mast_mesh.height != RELAY_MAST_HEIGHT_M \
			or relay_mast_mesh.radial_segments != 12 \
			or relay_head_mesh == null or relay_head_mesh.size != RELAY_HEAD_SIZE_M:
		_append_error(errors, &"staging_relay_visual_drift", &"StagingRelay", "solid staging-relay recipe drifted")
	if not _derelict_gantry_geometry_is_exact(gantry):
		_append_error(errors, &"derelict_gantry_visual_drift", &"DerelictSurveyGantry", "derelict survey-gantry silhouette or passive material recipe drifted")
	if not _survey_bunker_geometry_is_exact(bunker):
		_append_error(errors, &"survey_bunker_visual_drift", &"SurveyServiceBunker", "survey service-bunker silhouette or passive material recipe drifted")
	var material_specs := {
		body: BODY_COLOR,
		floor: FLOOR_COLOR,
		rim: RIM_COLOR,
		pad: PAD_COLOR,
		route: ROUTE_COLOR,
		rack: EQUIPMENT_COLOR,
		relay_base: EQUIPMENT_COLOR,
		relay_mast: EQUIPMENT_COLOR,
		relay_head: RELAY_COLOR,
	}
	if gantry != null:
		for node_name in [&"PortPylonVisual", &"StarboardPylonVisual", &"PortBeamVisual", &"StarboardBeamVisual", &"SensorBoomVisual"]:
			material_specs[gantry.get_node_or_null(NodePath(node_name)) as MeshInstance3D] = DERELICT_ALLOY_COLOR
		material_specs[gantry.get_node_or_null(^"DeadSensorVisual") as MeshInstance3D] = DERELICT_OXIDE_COLOR
	if bunker != null:
		for node_name in [&"BaseVisual", &"RoofVisual", &"PortVentVisual", &"StarboardVentVisual"]:
			material_specs[bunker.get_node_or_null(NodePath(node_name)) as MeshInstance3D] = DERELICT_ALLOY_COLOR
		material_specs[bunker.get_node_or_null(^"ShellVisual") as MeshInstance3D] = BUNKER_SHELL_COLOR
		material_specs[bunker.get_node_or_null(^"DoorVisual") as MeshInstance3D] = BUNKER_DOOR_COLOR
	for instance: MeshInstance3D in material_specs:
		var material := instance.material_override as StandardMaterial3D if instance != null else null
		if material == null \
				or material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
				or not material.albedo_color.is_equal_approx(material_specs[instance]) \
				or instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				or instance.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
			_append_error(errors, &"visual_material_drift", &"materials", "original unshaded material or passive renderer contract drifted")
			break


func _derelict_gantry_geometry_is_exact(gantry: StaticBody3D) -> bool:
	if gantry == null or gantry.position != GANTRY_ROOT_POSITION_M:
		return false
	return _box_visual_is_exact(gantry, &"PortPylonVisual", GANTRY_PYLON_SIZE_M, GANTRY_PORT_PYLON_POSITION_M, GANTRY_PYLON_LEAN_RADIANS) \
		and _box_visual_is_exact(gantry, &"StarboardPylonVisual", GANTRY_PYLON_SIZE_M, GANTRY_STARBOARD_PYLON_POSITION_M, -GANTRY_PYLON_LEAN_RADIANS) \
		and _box_visual_is_exact(gantry, &"PortBeamVisual", GANTRY_BEAM_SIZE_M, GANTRY_PORT_BEAM_POSITION_M, GANTRY_PORT_BEAM_TILT_RADIANS) \
		and _box_visual_is_exact(gantry, &"StarboardBeamVisual", GANTRY_BEAM_SIZE_M, GANTRY_STARBOARD_BEAM_POSITION_M, GANTRY_STARBOARD_BEAM_TILT_RADIANS) \
		and _cylinder_visual_is_exact(gantry, &"SensorBoomVisual", GANTRY_BOOM_RADIUS_M, GANTRY_BOOM_HEIGHT_M, GANTRY_BOOM_POSITION_M, GANTRY_BOOM_TILT_RADIANS) \
		and _box_visual_is_exact(gantry, &"DeadSensorVisual", GANTRY_SENSOR_SIZE_M, GANTRY_SENSOR_POSITION_M, GANTRY_SENSOR_TILT_RADIANS)


func _survey_bunker_geometry_is_exact(bunker: StaticBody3D) -> bool:
	if bunker == null or bunker.position != BUNKER_ROOT_POSITION_M \
			or not bunker.rotation.is_equal_approx(Vector3(0.0, BUNKER_YAW_RADIANS, 0.0)):
		return false
	return _box_visual_is_exact(bunker, &"BaseVisual", BUNKER_BASE_SIZE_M, BUNKER_BASE_POSITION_M, 0.0) \
		and _box_visual_is_exact(bunker, &"ShellVisual", BUNKER_SHELL_SIZE_M, BUNKER_SHELL_POSITION_M, 0.0) \
		and _box_visual_is_exact(bunker, &"RoofVisual", BUNKER_ROOF_SIZE_M, BUNKER_ROOF_POSITION_M, 0.0) \
		and _box_visual_is_exact(bunker, &"DoorVisual", BUNKER_DOOR_SIZE_M, BUNKER_DOOR_POSITION_M, 0.0) \
		and _cylinder_visual_is_exact(bunker, &"PortVentVisual", BUNKER_VENT_RADIUS_M, BUNKER_VENT_HEIGHT_M, BUNKER_PORT_VENT_POSITION_M, 0.0) \
		and _cylinder_visual_is_exact(bunker, &"StarboardVentVisual", BUNKER_VENT_RADIUS_M, BUNKER_VENT_HEIGHT_M, BUNKER_STARBOARD_VENT_POSITION_M, 0.0)


func _box_visual_is_exact(
		parent: Node,
		child_name: StringName,
		size: Vector3,
		position: Vector3,
		rotation_x: float,
	) -> bool:
	var visual := parent.get_node_or_null(NodePath(child_name)) as MeshInstance3D
	var mesh := visual.mesh as BoxMesh if visual != null else null
	return visual != null and mesh != null and mesh.size == size \
		and visual.position == position \
		and visual.rotation.is_equal_approx(Vector3(rotation_x, 0.0, 0.0))


func _cylinder_visual_is_exact(
		parent: Node,
		child_name: StringName,
		radius: float,
		height: float,
		position: Vector3,
		rotation_z: float,
	) -> bool:
	var visual := parent.get_node_or_null(NodePath(child_name)) as MeshInstance3D
	var mesh := visual.mesh as CylinderMesh if visual != null else null
	return visual != null and mesh != null \
		and is_equal_approx(mesh.top_radius, radius) \
		and is_equal_approx(mesh.bottom_radius, radius) \
		and is_equal_approx(mesh.height, height) and mesh.radial_segments == 12 \
		and visual.position == position \
		and visual.rotation.is_equal_approx(Vector3(0.0, 0.0, rotation_z))


func _validate_collision(errors: Array[Dictionary]) -> void:
	var body := get_node_or_null(^"LandingRegion/WalkablePatch") as StaticBody3D
	var collision := get_node_or_null(^"LandingRegion/WalkablePatch/CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null
	if body == null or body.position != WALKABLE_PATCH_POSITION_REGION_LOCAL_M \
			or body.collision_layer != WORLD_LAYER or body.collision_mask != WORLD_MASK:
		_append_error(errors, &"walkable_body_drift", &"WalkablePatch", "bounded static World collision body drifted")
	if collision == null or collision.transform != Transform3D.IDENTITY \
			or collision.disabled or shape == null or shape.size != WALKABLE_PATCH_SIZE_M:
		_append_error(errors, &"walkable_shape_drift", &"CollisionShape3D", "single bounded walkable box drifted")
	var body_specs := {
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort": PORT_PAD_GUIDE_POSITION_M,
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard": STARBOARD_PAD_GUIDE_POSITION_M,
		^"LandingRegion/SurfaceLandmarks/SampleRack": SAMPLE_RACK_POSITION_M,
		^"LandingRegion/SurfaceLandmarks/StagingRelay": RELAY_ROOT_POSITION_M,
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry": GANTRY_ROOT_POSITION_M,
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker": BUNKER_ROOT_POSITION_M,
	}
	for body_path: NodePath in body_specs:
		var landmark_body := get_node_or_null(body_path) as StaticBody3D
		if landmark_body == null or landmark_body.position != body_specs[body_path] \
				or landmark_body.collision_layer != WORLD_LAYER \
				or landmark_body.collision_mask != WORLD_MASK:
			_append_error(errors, &"landmark_collision_body_drift", StringName(str(body_path)), "solid landmark body transform or World collision contract drifted")
	var shape_specs := {
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort/CollisionShape3D": {"type": &"box", "size": PAD_GUIDE_SIZE_M, "position": Vector3.ZERO},
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard/CollisionShape3D": {"type": &"box", "size": PAD_GUIDE_SIZE_M, "position": Vector3.ZERO},
		^"LandingRegion/SurfaceLandmarks/SampleRack/CollisionShape3D": {"type": &"box", "size": SAMPLE_RACK_SIZE_M, "position": Vector3.ZERO},
		^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseCollision": {"type": &"box", "size": RELAY_BASE_SIZE_M, "position": RELAY_BASE_POSITION_M},
		^"LandingRegion/SurfaceLandmarks/StagingRelay/MastCollision": {"type": &"cylinder", "radius": RELAY_MAST_RADIUS_M, "height": RELAY_MAST_HEIGHT_M, "position": RELAY_MAST_POSITION_M},
		^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadCollision": {"type": &"box", "size": RELAY_HEAD_SIZE_M, "position": RELAY_HEAD_POSITION_M},
	}
	for shape_path: NodePath in shape_specs:
		var landmark_shape := get_node_or_null(shape_path) as CollisionShape3D
		var spec := shape_specs[shape_path] as Dictionary
		var valid_shape: bool = landmark_shape != null and not landmark_shape.disabled \
			and landmark_shape.position == spec.position
		if valid_shape and spec.type == &"box":
			var box := landmark_shape.shape as BoxShape3D
			valid_shape = box != null and box.size == spec.size
		elif valid_shape and spec.type == &"cylinder":
			var cylinder := landmark_shape.shape as CylinderShape3D
			valid_shape = cylinder != null \
				and is_equal_approx(cylinder.radius, float(spec.radius)) \
				and cylinder.height == float(spec.height)
		if not valid_shape:
			_append_error(errors, &"landmark_collision_shape_drift", StringName(str(shape_path)), "visual-solid landmark collision recipe drifted")
	var gantry := get_node_or_null(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry") as StaticBody3D
	if not _derelict_gantry_collision_is_exact(gantry):
		_append_error(errors, &"derelict_gantry_collision_drift", &"DerelictSurveyGantry", "derelict gantry visual-solid collision recipe drifted")
	var bunker := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker") as StaticBody3D
	if not _survey_bunker_collision_is_exact(bunker):
		_append_error(errors, &"survey_bunker_collision_drift", &"SurveyServiceBunker", "survey bunker visual-solid collision recipe drifted")


func _derelict_gantry_collision_is_exact(gantry: StaticBody3D) -> bool:
	if gantry == null:
		return false
	return _box_collision_is_exact(gantry, &"PortPylonCollision", GANTRY_PYLON_SIZE_M, GANTRY_PORT_PYLON_POSITION_M, GANTRY_PYLON_LEAN_RADIANS) \
		and _box_collision_is_exact(gantry, &"StarboardPylonCollision", GANTRY_PYLON_SIZE_M, GANTRY_STARBOARD_PYLON_POSITION_M, -GANTRY_PYLON_LEAN_RADIANS) \
		and _box_collision_is_exact(gantry, &"PortBeamCollision", GANTRY_BEAM_SIZE_M, GANTRY_PORT_BEAM_POSITION_M, GANTRY_PORT_BEAM_TILT_RADIANS) \
		and _box_collision_is_exact(gantry, &"StarboardBeamCollision", GANTRY_BEAM_SIZE_M, GANTRY_STARBOARD_BEAM_POSITION_M, GANTRY_STARBOARD_BEAM_TILT_RADIANS) \
		and _cylinder_collision_is_exact(gantry, &"SensorBoomCollision", GANTRY_BOOM_RADIUS_M, GANTRY_BOOM_HEIGHT_M, GANTRY_BOOM_POSITION_M, GANTRY_BOOM_TILT_RADIANS) \
		and _box_collision_is_exact(gantry, &"DeadSensorCollision", GANTRY_SENSOR_SIZE_M, GANTRY_SENSOR_POSITION_M, GANTRY_SENSOR_TILT_RADIANS)


func _survey_bunker_collision_is_exact(bunker: StaticBody3D) -> bool:
	if bunker == null:
		return false
	return _box_collision_is_exact(bunker, &"BaseCollision", BUNKER_BASE_SIZE_M, BUNKER_BASE_POSITION_M, 0.0) \
		and _box_collision_is_exact(bunker, &"ShellCollision", BUNKER_SHELL_SIZE_M, BUNKER_SHELL_POSITION_M, 0.0) \
		and _box_collision_is_exact(bunker, &"RoofCollision", BUNKER_ROOF_SIZE_M, BUNKER_ROOF_POSITION_M, 0.0) \
		and _box_collision_is_exact(bunker, &"DoorCollision", BUNKER_DOOR_SIZE_M, BUNKER_DOOR_POSITION_M, 0.0) \
		and _cylinder_collision_is_exact(bunker, &"PortVentCollision", BUNKER_VENT_RADIUS_M, BUNKER_VENT_HEIGHT_M, BUNKER_PORT_VENT_POSITION_M, 0.0) \
		and _cylinder_collision_is_exact(bunker, &"StarboardVentCollision", BUNKER_VENT_RADIUS_M, BUNKER_VENT_HEIGHT_M, BUNKER_STARBOARD_VENT_POSITION_M, 0.0)


func _box_collision_is_exact(parent: Node, child_name: StringName, size: Vector3, position: Vector3, rotation_x: float) -> bool:
	var collision := parent.get_node_or_null(NodePath(child_name)) as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null
	return collision != null and not collision.disabled and shape != null and shape.size == size \
		and collision.position == position \
		and collision.rotation.is_equal_approx(Vector3(rotation_x, 0.0, 0.0))


func _cylinder_collision_is_exact(parent: Node, child_name: StringName, radius: float, height: float, position: Vector3, rotation_z: float) -> bool:
	var collision := parent.get_node_or_null(NodePath(child_name)) as CollisionShape3D
	var shape := collision.shape as CylinderShape3D if collision != null else null
	return collision != null and not collision.disabled and shape != null \
		and is_equal_approx(shape.radius, radius) and is_equal_approx(shape.height, height) \
		and collision.position == position \
		and collision.rotation.is_equal_approx(Vector3(0.0, 0.0, rotation_z))


func _validate_surface_content(errors: Array[Dictionary]) -> void:
	var route := get_node_or_null(^"LandingRegion/SurfaceLandmarks/EgressRouteVisual") as MeshInstance3D
	if route == null \
			or StringName(route.get_meta("route_id", &"")) != SURFACE_ROUTE_ID \
			or StringName(route.get_meta("content_class", &"")) != &"NEW" \
			or StringName(route.get_meta("status", &"")) != &"modern_interpretation":
		_append_error(errors, &"surface_route_identity_drift", SURFACE_ROUTE_ID, "surface route identity/evidence metadata drifted")
	for landmark_id: StringName in SURFACE_LANDMARK_NODE_PATHS:
		var landmark := get_node_or_null(SURFACE_LANDMARK_NODE_PATHS[landmark_id]) as StaticBody3D
		if landmark == null \
				or StringName(landmark.get_meta("landmark_id", &"")) != landmark_id \
				or StringName(landmark.get_meta("content_class", &"")) != &"NEW" \
				or StringName(landmark.get_meta("status", &"")) != &"modern_interpretation" \
				or not bool(landmark.get_meta("solid_visual_collision", false)):
			_append_error(errors, &"surface_landmark_identity_drift", landmark_id, "stable landmark identity/evidence/collision metadata drifted")
	var gantry := get_node_or_null(SURFACE_LANDMARK_NODE_PATHS[&"ember_derelict_survey_gantry"]) as StaticBody3D
	if gantry == null \
			or bool(gantry.get_meta("historical_geometry_authenticated", true)) \
			or str(gantry.get_meta("evidence_note", "")).is_empty():
		_append_error(errors, &"derelict_gantry_evidence_drift", &"ember_derelict_survey_gantry", "modern derelict interpretation must not claim historical geometry")
	var bunker := get_node_or_null(SURFACE_LANDMARK_NODE_PATHS[&"ember_survey_service_bunker"]) as StaticBody3D
	if bunker == null \
			or bool(bunker.get_meta("historical_geometry_authenticated", true)) \
			or str(bunker.get_meta("evidence_note", "")).is_empty():
		_append_error(errors, &"survey_bunker_evidence_drift", &"ember_survey_service_bunker", "modern survey bunker interpretation must not claim historical geometry")
	for marker_id: StringName in SURFACE_MARKER_NODE_PATHS:
		var marker := get_node_or_null(SURFACE_MARKER_NODE_PATHS[marker_id]) as Marker3D
		if marker == null \
				or marker.transform != _expected_surface_marker_transform(marker_id) \
				or StringName(marker.get_meta("marker_id", &"")) != marker_id:
			_append_error(errors, &"surface_marker_drift", marker_id, "stable surface landmark marker drifted")
	for point: Vector3 in SURFACE_ROUTE_POINTS_M:
		if absf(point.x) > WALKABLE_PATCH_SIZE_M.x * 0.5 \
				or absf(point.z) + SURFACE_ROUTE_WIDTH_M * 0.5 > WALKABLE_PATCH_SIZE_M.z * 0.5 \
				or not is_zero_approx(point.y):
			_append_error(errors, &"surface_route_outside_patch", SURFACE_ROUTE_ID, "route centreline or clear width leaves the bounded collision patch")
			break
	# The nearest solid edge is a pad guide at |z|=4.75 m. Keeping every solid
	# beyond the 2 m route half-width plus the production player's 0.38 m capsule
	# radius makes the straight pad->egress->staging corridor honest.
	var solid_clearances := PackedFloat32Array([
		absf(PORT_PAD_GUIDE_POSITION_M.z) - PAD_GUIDE_SIZE_M.z * 0.5,
		absf(STARBOARD_PAD_GUIDE_POSITION_M.z) - PAD_GUIDE_SIZE_M.z * 0.5,
		absf(SAMPLE_RACK_POSITION_M.z) - SAMPLE_RACK_SIZE_M.z * 0.5,
		absf(RELAY_ROOT_POSITION_M.z) - RELAY_BASE_SIZE_M.z * 0.5,
		GANTRY_PYLON_MIN_ROUTE_CLEARANCE_M,
		BUNKER_MIN_ROUTE_CLEARANCE_M,
	])
	for clearance: float in solid_clearances:
		if clearance <= SURFACE_ROUTE_WIDTH_M * 0.5 + 0.38:
			_append_error(errors, &"surface_route_obstructed", SURFACE_ROUTE_ID, "solid landmark intrudes into production Player clearance")
			break
	var rotated_base_half_extent := (BUNKER_BASE_SIZE_M.x + BUNKER_BASE_SIZE_M.z) * 0.5 * sqrt(0.5)
	if BUNKER_ROOT_POSITION_M.z + rotated_base_half_extent \
			> -PAD_VISUAL_SIZE_M.z * 0.5 - BUNKER_MIN_PAD_CLEARANCE_M:
		_append_error(errors, &"survey_bunker_pad_clearance_drift", &"ember_survey_service_bunker", "survey bunker must remain outside the landing-pad footprint and clearance")


func _validate_forbidden_nodes(errors: Array[Dictionary]) -> void:
	for node in _all_nodes():
		if node is Camera3D or node is WorldEnvironment or node is Light3D \
				or node is Area3D or node is NavigationRegion3D \
				or node is AudioStreamPlayer or node is AudioStreamPlayer3D \
				or node is GPUParticles3D or node is CPUParticles3D \
				or node is AnimationPlayer or node is CharacterBody3D \
				or node is RigidBody3D:
			_append_error(errors, &"forbidden_runtime_node", StringName(node.name), "scene gained adjacent runtime authority")
		if node.is_processing() or node.is_physics_processing():
			_append_error(errors, &"automatic_process_loop", StringName(node.name), "static scene must not own process or physics callbacks")


func _configure_landing_approach_cues() -> void:
	var cues := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/LandingApproachCues"
	) as MultiMeshInstance3D
	var guide := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort/GuideVisual"
	) as MeshInstance3D
	if cues == null or guide == null:
		return
	var bar := BoxMesh.new()
	bar.size = APPROACH_CUE_BAR_SIZE_M
	bar.material = guide.material_override
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.instance_count = APPROACH_CUE_INSTANCE_COUNT
	batch.mesh = bar
	var transforms := _approach_cue_transforms()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	cues.multimesh = batch
	# Headless RenderingServer readback exposes identity transforms even though
	# Forward+ draws the buffer. Retain the exact CPU-authored roster for audit.
	cues.set_meta("authored_transforms", transforms.duplicate())


func _landing_approach_cues_are_exact(
		cues: MultiMeshInstance3D,
		pad_guides: MultiMeshInstance3D,
	) -> bool:
	if cues == null or pad_guides == null or pad_guides.multimesh == null \
			or cues.multimesh == null \
			or cues.transform != Transform3D.IDENTITY \
			or cues.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or cues.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or StringName(cues.get_meta("content_class", &"")) != &"NEW" \
			or StringName(cues.get_meta("status", &"")) != &"modern_interpretation":
		return false
	var batch := cues.multimesh
	var bar := batch.mesh as BoxMesh
	var guide_mesh := pad_guides.multimesh.mesh as BoxMesh
	if batch.transform_format != MultiMesh.TRANSFORM_3D \
			or batch.instance_count != APPROACH_CUE_INSTANCE_COUNT \
			or batch.visible_instance_count not in [-1, APPROACH_CUE_INSTANCE_COUNT] \
			or bar == null or bar.size != APPROACH_CUE_BAR_SIZE_M \
			or guide_mesh == null or bar.material != guide_mesh.material:
		return false
	var authored: Variant = cues.get_meta("authored_transforms", [])
	var expected := _approach_cue_transforms()
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _configure_pad_guide_visuals() -> void:
	var landmarks := get_node_or_null(^"LandingRegion/SurfaceLandmarks") as Node3D
	var port := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort/GuideVisual"
	) as MeshInstance3D
	var starboard := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard/GuideVisual"
	) as MeshInstance3D
	if landmarks == null or port == null or starboard == null \
			or port.mesh == null or port.mesh != starboard.mesh \
			or port.material_override != starboard.material_override \
			or port.cast_shadow != starboard.cast_shadow \
			or port.layers != starboard.layers \
			or port.ignore_occlusion_culling != starboard.ignore_occlusion_culling \
			or port.gi_mode != starboard.gi_mode \
			or port.extra_cull_margin != starboard.extra_cull_margin \
			or port.visibility_range_begin != starboard.visibility_range_begin \
			or port.visibility_range_end != starboard.visibility_range_end \
			or port.visibility_range_begin_margin != starboard.visibility_range_begin_margin \
			or port.visibility_range_end_margin != starboard.visibility_range_end_margin \
			or port.visibility_range_fade_mode != starboard.visibility_range_fade_mode:
		return
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, PORT_PAD_GUIDE_POSITION_M),
		Transform3D(Basis.IDENTITY, STARBOARD_PAD_GUIDE_POSITION_M),
	]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = port.mesh
	multi.instance_count = PAD_GUIDE_INSTANCE_COUNT
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	multi.custom_aabb = PAD_GUIDE_BATCH_BOUNDS
	var batch := MultiMeshInstance3D.new()
	batch.name = &"PadGuideVisuals"
	batch.multimesh = multi
	batch.material_override = port.material_override
	batch.cast_shadow = port.cast_shadow
	batch.gi_mode = port.gi_mode
	batch.extra_cull_margin = port.extra_cull_margin
	batch.visibility_range_begin = port.visibility_range_begin
	batch.visibility_range_end = port.visibility_range_end
	batch.visibility_range_begin_margin = port.visibility_range_begin_margin
	batch.visibility_range_end_margin = port.visibility_range_end_margin
	batch.visibility_range_fade_mode = port.visibility_range_fade_mode
	batch.layers = port.layers
	batch.ignore_occlusion_culling = port.ignore_occlusion_culling
	batch.sorting_offset = port.sorting_offset
	batch.sorting_use_aabb_center = port.sorting_use_aabb_center
	batch.set_meta("authored_transforms", transforms.duplicate())
	batch.set_meta("source_landmark_ids", PackedStringArray([
		"ember_pad_guidance_port",
		"ember_pad_guidance_starboard",
	]))
	landmarks.add_child(batch)
	port.free()
	starboard.free()


func _pad_guide_visuals_are_exact(batch: MultiMeshInstance3D) -> bool:
	if batch == null or batch.multimesh == null \
			or batch.transform != Transform3D.IDENTITY \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or batch.layers != 1 \
			or batch.ignore_occlusion_culling \
			or not is_zero_approx(batch.extra_cull_margin) \
			or not is_zero_approx(batch.visibility_range_begin) \
			or not is_zero_approx(batch.visibility_range_end) \
			or not is_zero_approx(batch.visibility_range_begin_margin) \
			or not is_zero_approx(batch.visibility_range_end_margin) \
			or batch.visibility_range_fade_mode \
				!= GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
		return false
	var multi := batch.multimesh
	var mesh := multi.mesh as BoxMesh
	var material := batch.material_override as StandardMaterial3D
	if multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.instance_count != PAD_GUIDE_INSTANCE_COUNT \
			or multi.visible_instance_count not in [-1, PAD_GUIDE_INSTANCE_COUNT] \
			or not multi.custom_aabb.is_equal_approx(PAD_GUIDE_BATCH_BOUNDS) \
			or mesh == null or mesh.size != PAD_GUIDE_SIZE_M \
			or mesh.material != batch.material_override \
			or material == null \
			or material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
			or not material.albedo_color.is_equal_approx(GUIDE_COLOR):
		return false
	var expected: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, PORT_PAD_GUIDE_POSITION_M),
		Transform3D(Basis.IDENTITY, STARBOARD_PAD_GUIDE_POSITION_M),
	]
	var authored: Variant = batch.get_meta("authored_transforms", [])
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return batch.get_meta("source_landmark_ids", PackedStringArray()) == PackedStringArray([
		"ember_pad_guidance_port",
		"ember_pad_guidance_starboard",
	])


static func _approach_cue_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for centre_z: float in APPROACH_CUE_CENTRE_Z_M:
		# Each pair meets at its -Z tip and opens toward the 300 m approach
		# marker. The silhouette therefore points unambiguously toward touchdown.
		transforms.append(Transform3D(
			Basis(Vector3.UP, -PI * 0.25),
			Vector3(-1.4, APPROACH_CUE_Y_M, centre_z + 1.4),
		))
		transforms.append(Transform3D(
			Basis(Vector3.UP, PI * 0.25),
			Vector3(1.4, APPROACH_CUE_Y_M, centre_z + 1.4),
		))
	return transforms


func _configure_orbital_landing_datum_cue() -> void:
	var cue := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/OrbitalLandingDatumCue"
	) as MultiMeshInstance3D
	var route := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/EgressRouteVisual"
	) as MeshInstance3D
	if cue == null or route == null:
		return
	var unit_bar := BoxMesh.new()
	unit_bar.size = Vector3.ONE
	unit_bar.material = route.material_override
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = unit_bar
	batch.instance_count = ORBITAL_CUE_INSTANCE_COUNT
	var transforms := _orbital_landing_cue_transforms()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	cue.multimesh = batch
	cue.set_meta("authored_transforms", transforms.duplicate())


func _orbital_landing_datum_cue_is_exact(
		cue: MultiMeshInstance3D,
		route: MeshInstance3D,
	) -> bool:
	if cue == null or route == null or cue.multimesh == null \
			or cue.transform != Transform3D.IDENTITY \
			or cue.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or cue.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or StringName(cue.get_meta("content_class", &"")) != &"NEW" \
			or StringName(cue.get_meta("status", &"")) != &"modern_interpretation" \
			or StringName(cue.get_meta("approach_marker_id", &"")) != &"caldera_approach" \
			or StringName(cue.get_meta("landing_marker_id", &"")) != &"caldera_pad":
		return false
	var batch := cue.multimesh
	var unit_bar := batch.mesh as BoxMesh
	if batch.transform_format != MultiMesh.TRANSFORM_3D \
			or batch.instance_count != ORBITAL_CUE_INSTANCE_COUNT \
			or batch.visible_instance_count not in [-1, ORBITAL_CUE_INSTANCE_COUNT] \
			or unit_bar == null or unit_bar.size != Vector3.ONE \
			or unit_bar.material != route.material_override:
		return false
	var authored: Variant = cue.get_meta("authored_transforms", [])
	var expected := _orbital_landing_cue_transforms()
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	var approach := _expected_marker_transform(&"caldera_approach").origin
	var landing := _expected_marker_transform(&"caldera_pad").origin
	var horizontal_direction := Vector3(
		landing.x - approach.x, 0.0, landing.z - approach.z
	).normalized()
	return horizontal_direction.is_equal_approx(Vector3(0.0, 0.0, -1.0))


static func _orbital_landing_cue_transforms() -> Array[Transform3D]:
	return [
		_bar_between(ORBITAL_CUE_TIP_M, ORBITAL_CUE_PORT_END_M, ORBITAL_CUE_ARM_WIDTH_M, 3.0),
		_bar_between(ORBITAL_CUE_TIP_M, ORBITAL_CUE_STARBOARD_END_M, ORBITAL_CUE_ARM_WIDTH_M, 3.0),
		Transform3D(
			Basis().scaled(ORBITAL_CUE_THRESHOLD_SIZE_M),
			Vector3(0.0, 3.0, 62.0),
		),
	]


static func _bar_between(
		start: Vector3,
		finish: Vector3,
		width: float,
		height: float,
	) -> Transform3D:
	var direction := (finish - start).normalized()
	var lateral := Vector3(direction.z, 0.0, -direction.x).normalized()
	var length := start.distance_to(finish)
	return Transform3D(
		Basis(lateral * width, Vector3.UP * height, direction * length),
		(start + finish) * 0.5,
	)


func _validate_performance(errors: Array[Dictionary], census: Dictionary) -> void:
	var budget := _performance_budget()
	for key: String in budget:
		if int(census.get(key, -1)) != int(budget[key]):
			_append_error(errors, &"performance_roster_drift", StringName(key), "exact authored performance roster drifted")
	if int(census.get("triangle_count", -1)) > MAXIMUM_TRIANGLE_COUNT:
		_append_error(errors, &"triangle_budget_exceeded", &"triangle_count", "primitive triangle count exceeds the bounded ceiling")


func _performance_census() -> Dictionary:
	var meshes := 0
	var multi_meshes := 0
	var multi_mesh_copies := 0
	var static_bodies := 0
	var collision_shapes := 0
	var triangles := 0
	for node in _all_nodes():
		if node is MeshInstance3D:
			meshes += 1
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				triangles += mesh.get_faces().size() / 3
		elif node is MultiMeshInstance3D:
			multi_meshes += 1
			var batch := (node as MultiMeshInstance3D).multimesh
			if batch != null:
				multi_mesh_copies += batch.instance_count
				if batch.mesh != null:
					triangles += batch.mesh.get_faces().size() / 3 * batch.instance_count
		elif node is StaticBody3D:
			static_bodies += 1
		elif node is CollisionShape3D:
			collision_shapes += 1
	return {
		"node_count": _count_nodes(),
		"mesh_instances": meshes,
		"multi_mesh_instances": multi_meshes,
		"multi_mesh_copies": multi_mesh_copies,
		"static_bodies": static_bodies,
		"collision_shapes": collision_shapes,
		"triangle_count": triangles,
	}.duplicate(true)


func _performance_budget() -> Dictionary:
	return {
		"node_count": EXPECTED_NODE_COUNT,
		"mesh_instances": EXPECTED_MESH_INSTANCE_COUNT,
		"multi_mesh_instances": EXPECTED_MULTI_MESH_INSTANCE_COUNT,
		"multi_mesh_copies": EXPECTED_MULTI_MESH_COPY_COUNT,
		"static_bodies": EXPECTED_STATIC_BODY_COUNT,
		"collision_shapes": EXPECTED_COLLISION_SHAPE_COUNT,
	}.duplicate(true)


func _expected_landing_region_transform() -> Transform3D:
	if _landing_region != null:
		return Transform3D(
			_landing_region.body_local_basis,
			_landing_region.body_local_center_m,
		)
	return Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_M, 0.0))


func _expected_marker_transform(marker_id: StringName) -> Transform3D:
	if _landing_region == null:
		return Transform3D.IDENTITY
	match marker_id:
		&"caldera_pad":
			return _landing_region.touchdown_pad_transforms_region_local_m[0]
		&"caldera_approach":
			return _landing_region.approach_corridor_transforms_region_local_m[0]
		&"caldera_pad_egress":
			return Transform3D(Basis.IDENTITY, _landing_region.surface_route_anchor_positions_region_local_m[0])
		&"caldera_staging_gate":
			return Transform3D(Basis.IDENTITY, _landing_region.surface_route_anchor_positions_region_local_m[1])
		_:
			return Transform3D.IDENTITY


static func _expected_surface_marker_transform(marker_id: StringName) -> Transform3D:
	match marker_id:
		&"ember_pad_guidance_threshold":
			return Transform3D(Basis.IDENTITY, Vector3(14.0, 0.0, 0.0))
		&"ember_sample_rack_access":
			return Transform3D(Basis.IDENTITY, Vector3(28.0, 0.0, -4.8))
		&"ember_staging_relay_access":
			return Transform3D(Basis.IDENTITY, Vector3(42.0, 0.0, 4.4))
		&"ember_derelict_survey_gantry_access":
			return Transform3D(Basis.IDENTITY, GANTRY_ACCESS_POSITION_M)
		&"ember_survey_service_bunker_access":
			return Transform3D(Basis.IDENTITY, BUNKER_ACCESS_POSITION_M)
		_:
			return Transform3D.IDENTITY


func _evidence_report() -> Dictionary:
	return {
		"content_class": &"NEW",
		"status": &"modern_interpretation",
		"scope": &"bounded_authored_planetary_scene",
		"references": PackedStringArray([EVIDENCE_PATH]),
		"historical_claim": false,
		"authenticated": false,
		"space_backdrop_palette_inspiration_only": true,
		"space_backdrop_physical_reuse": false,
		"notes": "Original Ember Moon visual proxy, bounded static pad collision, traversable surface route, and modern landmarks including a derelict gantry and survey service bunker; no historical or production-placement claim.",
	}.duplicate(true)


func _owned_capabilities() -> Dictionary:
	return {
		"presentation_geometry": true,
		"static_world_collision": true,
		"authored_surface_landmarks": true,
		"authored_surface_route": true,
	}.duplicate(true)


func _integration_authority() -> Dictionary:
	var result := {}
	for key in INTEGRATION_AUTHORITY_KEYS:
		result[key] = false
	return result.duplicate(true)


func _all_nodes() -> Array[Node]:
	var result: Array[Node] = [self]
	for node in find_children("*", "Node", true, false):
		result.append(node)
	return result


func _count_nodes() -> int:
	return _all_nodes().size()


static func _append_error(
		errors: Array[Dictionary],
		code: StringName,
		field: StringName,
		message: String
	) -> void:
	errors.append({"code": code, "field": field, "message": message})


static func _error_codes(errors: Array[Dictionary]) -> PackedStringArray:
	var result := PackedStringArray()
	for error in errors:
		result.append(str(error.get("code", &"unknown_error")))
	return result
