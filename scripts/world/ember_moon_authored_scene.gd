class_name EmberMoonAuthoredScene
extends Node3D

## Body-centred production content for the bounded Ember Moon vertical slice.
## It loads copied definition data, builds one landing-initialized terrain
## clipmap, accepts thresholded caller focus updates, validates its authored and
## generated nodes, and exposes terrain-LOD hints. The world coordinator still
## owns placement, streaming and retirement.

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
## The streamed production moon now carries the same bounded terrain renderer
## already proven by the Aurora witness. The complete 600 m approach corridor
## remains level, the authored caldera floor fills the 256 m visual opening, and
## the existing 96 m patch remains sole collision support inside its exact edge.
const TERRAIN_RENDER_RESOLUTION := 65
const TERRAIN_SEED := 20_260_830
const TERRAIN_FLATTEN_RADIUS_M := 750.0
const TERRAIN_VISUAL_CLEARANCE_RADIUS_M := CALDERA_FLOOR_RADIUS_M
const TERRAIN_COLLISION_CLEARANCE_RADIUS_M := WALKABLE_PATCH_SIZE_M.x * 0.5
const TERRAIN_MATERIAL_TINT := Color("bd704f")
const TERRAIN_RING_COUNT := 5
const TERRAIN_RENDER_VERTEX_COUNT := 21_125
const TERRAIN_FOCUS_RECENTER_DISTANCE_M := 192.0
## The five-ring renderer remains bounded to 18.432 km around its committed
## focus. Beyond the landing-relative ring envelope, one reusable body-local
## collision disc follows authenticated focus rebuilds. It does not bridge back
## to the caldera or create a global collider: exactly one 1.5 km relief-matched
## patch exists, and the fixed landing collision remains untouched.
const TERRAIN_RENDER_MAXIMUM_DISTANCE_M := 18_432.0
const TERRAIN_ACTOR_COLLISION_RADIUS_M := 1_500.0
const TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS := 32
const TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS := 128
const TERRAIN_ACTOR_COLLISION_VERTEX_COUNT := (
	1 + TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS
		* TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS
)
const TERRAIN_ACTOR_COLLISION_TRIANGLE_COUNT := (
	TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS
		+ (TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS - 1)
			* TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS * 2
)
# The fixed landing surface uses 32,768 triangles / 16,640 unique vertices.
# The mutually exclusive renderer corridor is capped at 8,320 triangles; a
# conservative three unique vertices per triangle freezes its vertex ceiling.
# The actor disc is smaller (8,064 triangles / 4,097 vertices).
const TERRAIN_COLLISION_VERTEX_CEILING := 41_600
const TERRAIN_COLLISION_TRIANGLE_CEILING := 41_088
const TERRAIN_ACTIVE_NODE_CEILING := 84
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
## Five broad, low-profile survey chevrons turn the previously uniform egress
## strip into a readable Ember route at gameplay distance. Three chevrons
## continue along the strip, while the chevrons at the rack and relay
## turn toward their existing off-spine access markers. They sit directly on
## the supported route surface and remain presentation-only so they cannot snag
## a low-gravity walk or jump. All ten bars draw in one passive MultiMesh.
const ROUTE_SPINE_CENTRES_X_M := [18.0, 23.5, 29.0, 34.5, 40.0]
const ROUTE_SPINE_SAMPLE_TURN_INDEX := 2
const ROUTE_SPINE_RELAY_TURN_INDEX := 4
const ROUTE_SPINE_SAMPLE_DIRECTION := Vector3(0.0, 0.0, -1.0)
const ROUTE_SPINE_RELAY_DIRECTION := Vector3(0.0, 0.0, 1.0)
const ROUTE_SPINE_INSTANCE_COUNT := 10
const ROUTE_SPINE_ARM_WIDTH_M := 0.34
const ROUTE_SPINE_ARM_HEIGHT_M := 0.025
const ROUTE_SPINE_HALF_SPAN_M := 1.35
const ROUTE_SPINE_TIP_OFFSET_M := 1.0
const ROUTE_SPINE_TAIL_OFFSET_M := 1.15
const ROUTE_SPINE_Y_M := 0.0325
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
const SAMPLE_RACK_ACCESS_POSITION_M := Vector3(28.0, 0.0, -4.8)
## The rack used to disappear into the caldera as a one-metre-high dark box.
## One passive pair of orthogonal open diamonds now gives it a broad,
## colour-independent identity from both the walked route and rack access
## without changing the solid rack, its access point, collision, activity
## lifecycle, lighting, or navigation authority.
const SAMPLE_RACK_VANE_INSTANCE_COUNT := 9
const SAMPLE_RACK_VANE_HALF_WIDTH_M := 1.5
const SAMPLE_RACK_VANE_HALF_HEIGHT_M := 1.3
const SAMPLE_RACK_VANE_CENTRE_Y_M := 2.6
const SAMPLE_RACK_VANE_BAR_THICKNESS_M := 0.22
const SAMPLE_RACK_VANE_DEPTH_M := 0.16
const SAMPLE_RACK_VANE_POST_HEIGHT_M := 1.3
const SAMPLE_RACK_VANE_GAMEPLAY_READABILITY_DISTANCE_M := 36.0
const SAMPLE_RACK_VANE_BATCH_BOUNDS := AABB(
	Vector3(-1.62, 0.0, -1.62),
	Vector3(3.24, 4.02, 3.24),
)
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
const GANTRY_PYLON_INSTANCE_COUNT := 2
const GANTRY_PYLON_BATCH_BOUNDS := AABB(
	Vector3(-0.6, -0.05, -6.2),
	Vector3(1.2, 7.3, 12.4),
)
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
## A high, orthogonal survey crown gives the existing derelict a broad profile
## along both the orbital approach (+/-Z) and walked pad route (+/-X). The six
## oxide members retain exact World collision on the existing gantry body, so
## a production-gravity jump or ship contact cannot pass through solid-looking
## reachable geometry. The route clearance and gameplay authority stay below.
const GANTRY_CROWN_INSTANCE_COUNT := 6
const GANTRY_CROWN_CENTRE_M := Vector3(0.0, 11.4, -1.9)
const GANTRY_CROWN_CROSS_SPAN_M := 9.0
const GANTRY_CROWN_BAR_THICKNESS_M := 0.7
const GANTRY_CROWN_FIN_HEIGHT_M := 4.2
const GANTRY_CROWN_FIN_OFFSET_M := 4.15
const GANTRY_CROWN_MAXIMUM_HEIGHT_M := 15.25
const GANTRY_CROWN_MINIMUM_CLEARANCE_M := 11.05
const GANTRY_CROWN_BATCH_BOUNDS := AABB(
	Vector3(-4.5, 11.05, -6.4),
	Vector3(9.0, 4.2, 9.0),
)
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
const BUNKER_SERVICE_ALCOVE_ID: StringName = &"ember_bunker_service_alcove"
const BUNKER_SERVICE_ALCOVE_WIDTH_M := 2.4
const BUNKER_SERVICE_ALCOVE_HEIGHT_M := 2.6
const BUNKER_VENT_RADIUS_M := 0.28
const BUNKER_VENT_HEIGHT_M := 1.1
const BUNKER_PORT_VENT_POSITION_M := Vector3(-2.0, 4.2, -1.6)
const BUNKER_STARBOARD_VENT_POSITION_M := Vector3(-2.0, 4.2, 1.6)
const BUNKER_VENT_INSTANCE_COUNT := 2
const BUNKER_VENT_BATCH_BOUNDS := AABB(
	Vector3(-2.28, 3.65, -1.88),
	Vector3(0.56, 1.1, 3.76),
)
const BUNKER_ACCESS_POSITION_M := Vector3(-17.5, 0.0, -17.5)
const BUNKER_MIN_PAD_CLEARANCE_M := 2.3
const BUNKER_MIN_ROUTE_CLEARANCE_M := 18.3

const BODY_COLOR := Color("552817")
const FLOOR_COLOR := Color("292421")
const RIM_COLOR := Color("713a25")
const PAD_COLOR := Color("a85f32")
## High-value ochre keeps the continuous egress strip and its shared landing
## cue batches legible against both the dark caldera floor and oxidised pad.
## It remains a fully lit, non-emissive surface under the airless-sun owner.
const ROUTE_COLOR := Color("f0b35e")
const GUIDE_COLOR := Color("71d9da")
const EQUIPMENT_COLOR := Color("4f4942")
const RELAY_COLOR := Color("e1a458")
const DERELICT_ALLOY_COLOR := Color("353a38")
## Existing interaction-facing accents are deliberately brighter than the
## surrounding oxidised alloy. They distinguish the elevated gantry head and
## bunker access face at landing/on-foot distance without adding an emissive
## cue, light, motion, or another rendered primitive.
const DERELICT_OXIDE_COLOR := Color("c66a3d")
const BUNKER_SHELL_COLOR := Color("6f5946")
const BUNKER_DOOR_COLOR := Color("d99253")

# The terrain stays mineral and fully rough. Manufactured surfaces reuse the
# registered production panel maps at role-specific metric scales, so the broad
# pad, narrow grip route, structural salvage and bunker service paint no longer
# collapse into the same flat primitive response under the airless sun.
const PANEL_ALBEDO_PATH := StationSurfaceKit.PANEL_ALBEDO_PATH
const PANEL_NORMAL_PATH := StationSurfaceKit.PANEL_NORMAL_PATH
const PANEL_ROUGHNESS_PATH := StationSurfaceKit.PANEL_ROUGHNESS_PATH
const GRIP_PANEL_SCALE := 0.55
const METAL_PANEL_SCALE := 0.30
const SERVICE_PANEL_SCALE := 0.36
const GRIP_METALLIC := 0.32
const METAL_METALLIC := 0.68
const OXIDE_METALLIC := 0.18
const SERVICE_METALLIC := 0.28
const GRIP_ROUGHNESS := 0.86
const METAL_ROUGHNESS := 0.78
const OXIDE_ROUGHNESS := 0.92
const SERVICE_ROUGHNESS := 0.72

const EXPECTED_NODE_COUNT := 83
const EXPECTED_MESH_INSTANCE_COUNT := 22
const EXPECTED_MULTI_MESH_INSTANCE_COUNT := 8
const EXPECTED_MULTI_MESH_COPY_COUNT := 42
const EXPECTED_RENDER_SUBMISSION_COUNT := 30
const EXPECTED_STATIC_BODY_COUNT := 9
const EXPECTED_COLLISION_SHAPE_COUNT := 27
const MAXIMUM_TRIANGLE_COUNT := 60_000
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
var _terrain_clipmap: PlanetaryTerrainClipmapRenderer
var _actor_collision_body: StaticBody3D
var _actor_collision_shape: CollisionShape3D
var _actor_collision_report: Dictionary = {}
var _initialized := false


static func get_survey_interaction_definition() -> Dictionary:
	var bunker_door_ground_m := BUNKER_ROOT_POSITION_M + Basis(
		Vector3.UP, BUNKER_YAW_RADIANS
	) * Vector3(BUNKER_DOOR_POSITION_M.x, 0.0, BUNKER_DOOR_POSITION_M.z)
	return {
		"interaction_id": &"ember_bunker_gantry_survey",
		"world_id": WORLD_ID,
		"position_body_local_m": BUNKER_ACCESS_POSITION_M + Vector3.UP * BODY_RADIUS_M,
		"completion_response_id": BUNKER_SERVICE_ALCOVE_ID,
		"bunker_door_ground_body_local_m": bunker_door_ground_m + Vector3.UP * BODY_RADIUS_M,
		"service_alcove_width_m": BUNKER_SERVICE_ALCOVE_WIDTH_M,
		"service_alcove_height_m": BUNKER_SERVICE_ALCOVE_HEIGHT_M,
		"landmark_ids": PackedStringArray([
			"ember_survey_service_bunker", "ember_derelict_survey_gantry",
		]),
		"historical_claim": false,
		"status": &"modern_interpretation",
	}.duplicate(true)


## Pure interaction placement over the existing rack access marker. The
## runtime binding adds only a proximity Area and text marker; the authored
## rack mesh, collision, and transform remain unchanged.
static func get_sample_rack_interaction_definition() -> Dictionary:
	return {
		"checkpoint_id": &"ember_sample_rack_analysis_log",
		"interaction_id": &"ember_sample_rack_analysis",
		"world_id": WORLD_ID,
		"position_body_local_m": SAMPLE_RACK_ACCESS_POSITION_M \
			+ Vector3.UP * BODY_RADIUS_M,
		"completion_response_id": &"ember_sample_rack_analysis_marker",
		"landmark_ids": PackedStringArray(["ember_sample_rack"]),
		"historical_claim": false,
		"status": &"modern_interpretation",
	}.duplicate(true)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_configure_surface_material_hierarchy()
	_configure_sample_rack_identity_vane()
	_configure_surface_route_spine()
	_configure_gantry_pylon_visuals()
	_configure_gantry_navigation_crown()
	_configure_bunker_vent_visuals()
	_configure_landing_approach_cues()
	_configure_orbital_landing_datum_cue()
	_configure_pad_guide_visuals()
	_initialize_contract()
	_configure_actor_collision_owner()
	_configure_terrain_clipmap()


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


func get_terrain_clipmap_snapshot() -> Dictionary:
	var result := (
		_terrain_clipmap.get_snapshot()
		if _terrain_clipmap != null
		else {"configured": false, "ring_count": 0}
	).duplicate(true)
	var actor_collision := _actor_collision_report.duplicate(true)
	var renderer_collision_triangles := int(result.get(
		"collision_triangle_count", 0
	))
	var renderer_collision_vertices := int(result.get(
		"collision_vertex_count", 0
	))
	result["actor_collision"] = actor_collision
	result["scene_collision_triangle_count"] = (
		renderer_collision_triangles
			+ int(actor_collision.get("triangle_count", 0))
	)
	result["scene_collision_vertex_count"] = (
		renderer_collision_vertices
			+ int(actor_collision.get("vertex_count", 0))
	)
	result["scene_collision_triangle_ceiling"] = (
		TERRAIN_COLLISION_TRIANGLE_CEILING
	)
	result["scene_collision_vertex_ceiling"] = TERRAIN_COLLISION_VERTEX_CEILING
	result["scene_active_node_ceiling"] = TERRAIN_ACTIVE_NODE_CEILING
	return result.duplicate(true)


func get_terrain_clipmap_generation() -> int:
	return _terrain_clipmap.get_generation() if _terrain_clipmap != null else 0


## Caller-driven production focus update. The caller supplies an authenticated
## body-local actor position and the renderer generation it observed. Small
## movements retain the committed meshes; crossing the bounded threshold
## atomically recentres the visible clipmap and its bounded focus corridor. The
## renderer keeps the authored landing collision fixed at the caldera seam.
func update_terrain_focus(
	focus_body_local_m: Vector3,
	expected_terrain_generation: int,
) -> Dictionary:
	if not _initialized or _terrain_clipmap == null:
		return {
			"accepted": false,
			"reason": &"terrain_clipmap_unavailable",
		}.duplicate(true)
	if expected_terrain_generation != _terrain_clipmap.get_generation():
		return {
			"accepted": false,
			"reason": &"stale_terrain_generation",
		}.duplicate(true)
	if not focus_body_local_m.is_finite() or focus_body_local_m.is_zero_approx():
		return {
			"accepted": false,
			"reason": &"invalid_terrain_focus",
		}.duplicate(true)
	var previous_direction := _terrain_clipmap.get_focus_radial_up()
	if previous_direction.is_zero_approx():
		return {
			"accepted": false,
			"reason": &"terrain_focus_unavailable",
		}.duplicate(true)
	var focus_direction := focus_body_local_m.normalized()
	var focus_distance_m := _surface_distance_m(
		previous_direction,
		focus_direction,
	)
	if focus_distance_m < TERRAIN_FOCUS_RECENTER_DISTANCE_M:
		return {
			"accepted": true,
			"reason": &"terrain_focus_retained",
			"rebuilt": false,
			"generation": _terrain_clipmap.get_generation(),
			"revision": _terrain_clipmap.get_revision(),
			"distance_from_committed_focus_m": focus_distance_m,
			"recenter_distance_m": TERRAIN_FOCUS_RECENTER_DISTANCE_M,
		}.duplicate(true)
	var landing_distance_m := _surface_distance_m(Vector3.UP, focus_direction)
	var staged_actor_collision := _stage_actor_collision_support(
		focus_direction,
		landing_distance_m,
	)
	if not bool(staged_actor_collision.get("accepted", false)):
		return {
			"accepted": false,
			"reason": staged_actor_collision.get(
				"reason", &"actor_collision_build_failed"
			),
			"rebuilt": false,
		}.duplicate(true)
	var rebuilt := _terrain_clipmap.rebuild(
		focus_direction * BODY_RADIUS_M,
		expected_terrain_generation,
	)
	if not bool(rebuilt.get("accepted", false)):
		return {
			"accepted": false,
			"reason": rebuilt.get("reason", &"terrain_rebuild_rejected"),
			"rebuilt": false,
		}.duplicate(true)
	_commit_actor_collision_support(staged_actor_collision)
	return {
		"accepted": true,
		"reason": &"terrain_focus_recentered",
		"rebuilt": true,
		"generation": _terrain_clipmap.get_generation(),
		"revision": _terrain_clipmap.get_revision(),
		"distance_from_previous_focus_m": focus_distance_m,
		"recenter_distance_m": TERRAIN_FOCUS_RECENTER_DISTANCE_M,
		"focus_body_local_m": focus_direction * BODY_RADIUS_M,
		"actor_collision_active": bool(
			_actor_collision_report.get("active", false)
		),
		"actor_collision_reason": _actor_collision_report.get("reason", &""),
	}.duplicate(true)


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
		"surface_material_hierarchy": _surface_material_hierarchy_snapshot(),
		"geometry": {
			"caldera_floor_radius_m": CALDERA_FLOOR_RADIUS_M,
			"caldera_rim_inner_radius_m": CALDERA_RIM_INNER_RADIUS_M,
			"caldera_rim_outer_radius_m": CALDERA_RIM_OUTER_RADIUS_M,
			"pad_visual_size_m": PAD_VISUAL_SIZE_M,
			"surface_route_visual_size_m": SURFACE_ROUTE_VISUAL_SIZE_M,
			"surface_route_spine_chevron_count": ROUTE_SPINE_CENTRES_X_M.size(),
			"surface_route_turn_cue_count": 2,
			"surface_route_turn_destinations": PackedStringArray([
				"ember_sample_rack_access", "ember_staging_relay_access",
			]),
			"surface_route_spine_maximum_height_m": ROUTE_SPINE_Y_M
				+ ROUTE_SPINE_ARM_HEIGHT_M * 0.5,
			"pad_guide_size_m": PAD_GUIDE_SIZE_M,
			"approach_cue_bar_size_m": APPROACH_CUE_BAR_SIZE_M,
			"approach_cue_centres_z_m": APPROACH_CUE_CENTRE_Z_M.duplicate(),
			"approach_cue_instance_count": APPROACH_CUE_INSTANCE_COUNT,
			"orbital_landing_cue_instance_count": ORBITAL_CUE_INSTANCE_COUNT,
			"orbital_landing_cue_maximum_radius_m": ORBITAL_CUE_MAXIMUM_RADIUS_M,
			"orbital_landing_navigation_direction": Vector3(0.0, 0.0, -1.0),
			"sample_rack_size_m": SAMPLE_RACK_SIZE_M,
			"sample_rack_identity_vane": {
				"silhouette": &"crossed_open_diamonds_over_low_rack",
				"instance_count": SAMPLE_RACK_VANE_INSTANCE_COUNT,
				"maximum_height_region_local_m": SAMPLE_RACK_POSITION_M.y
					+ SAMPLE_RACK_VANE_CENTRE_Y_M + SAMPLE_RACK_VANE_HALF_HEIGHT_M,
				"gameplay_readability_distance_m": SAMPLE_RACK_VANE_GAMEPLAY_READABILITY_DISTANCE_M,
				"color_independent": true,
				"collision_changed": false,
			},
			"relay_base_size_m": RELAY_BASE_SIZE_M,
			"relay_mast_radius_m": RELAY_MAST_RADIUS_M,
			"relay_mast_height_m": RELAY_MAST_HEIGHT_M,
			"relay_head_size_m": RELAY_HEAD_SIZE_M,
			"derelict_gantry_position_m": GANTRY_ROOT_POSITION_M,
			"derelict_gantry_height_m": GANTRY_CROWN_MAXIMUM_HEIGHT_M,
			"derelict_gantry_span_m": GANTRY_STARBOARD_PYLON_POSITION_M.z
				- GANTRY_PORT_PYLON_POSITION_M.z + GANTRY_PYLON_SIZE_M.z,
			"derelict_gantry_navigation_crown_cross_span_m": GANTRY_CROWN_CROSS_SPAN_M,
			"derelict_gantry_navigation_crown_minimum_clearance_m": GANTRY_CROWN_MINIMUM_CLEARANCE_M,
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
			"solid_landmark_collision_shape_count": 24,
			"route_clear_half_width_m": SURFACE_ROUTE_WIDTH_M * 0.5,
		},
		"terrain_lod_policy": lod_snapshot,
		"terrain_clipmap": get_terrain_clipmap_snapshot(),
		"terrain_focus": {
			"caller_driven": true,
			"recenter_distance_m": TERRAIN_FOCUS_RECENTER_DISTANCE_M,
			"collision_focus": &"fixed_landing_plus_bounded_actor_patch",
			"renderer_envelope_m": TERRAIN_RENDER_MAXIMUM_DISTANCE_M,
			"actor_support_radius_m": TERRAIN_ACTOR_COLLISION_RADIUS_M,
		},
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
	_validate_terrain_clipmap(errors)
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


func _configure_terrain_clipmap() -> void:
	_terrain_clipmap = get_node_or_null(^"TerrainClipmap") \
		as PlanetaryTerrainClipmapRenderer
	if _terrain_clipmap == null or _terrain_profile == null:
		push_error("Ember terrain clipmap contract is unavailable")
		return
	var configured := _terrain_clipmap.configure(
		_terrain_profile,
		TERRAIN_RENDER_RESOLUTION,
		TERRAIN_SEED,
		Vector3.UP * BODY_RADIUS_M,
		TERRAIN_FLATTEN_RADIUS_M,
		TERRAIN_VISUAL_CLEARANCE_RADIUS_M,
		TERRAIN_COLLISION_CLEARANCE_RADIUS_M,
		TERRAIN_MATERIAL_TINT,
	)
	var rebuilt := (
		_terrain_clipmap.rebuild(
			Vector3.UP * BODY_RADIUS_M,
			_terrain_clipmap.get_generation(),
		)
		if bool(configured.get("accepted", false))
		else {"accepted": false, "reason": configured.get("reason", &"configure_failed")}
	)
	if not bool(rebuilt.get("accepted", false)):
		push_error(
			"Ember terrain clipmap failed: %s"
			% String(rebuilt.get("reason", &"unknown"))
		)


func _configure_actor_collision_owner() -> void:
	_actor_collision_body = StaticBody3D.new()
	_actor_collision_body.name = &"TerrainActorCollision"
	_actor_collision_body.collision_layer = WORLD_LAYER
	_actor_collision_body.collision_mask = 0
	_actor_collision_body.set_meta(&"common_origin_owner", true)
	_actor_collision_body.set_meta(&"generated_planetary_terrain", true)
	_actor_collision_shape = CollisionShape3D.new()
	_actor_collision_shape.name = &"TerrainActorCollisionSurface"
	_actor_collision_shape.disabled = true
	_actor_collision_body.add_child(_actor_collision_shape)
	add_child(_actor_collision_body)
	_actor_collision_report = _inactive_actor_collision_report(
		&"focus_inside_renderer_envelope"
	)


func _stage_actor_collision_support(
		focus_up: Vector3,
		landing_distance_m: float,
	) -> Dictionary:
	if landing_distance_m <= TERRAIN_RENDER_MAXIMUM_DISTANCE_M:
		return {
			"accepted": true,
			"report": _inactive_actor_collision_report(
				&"focus_inside_renderer_envelope"
			),
		}.duplicate(true)
	if _terrain_clipmap == null:
		return {"accepted": false, "reason": &"terrain_clipmap_unavailable"}
	var tangent_right := _terrain_tangent_right(focus_up)
	var tangent_back := tangent_right.cross(focus_up).normalized()
	if tangent_right.is_zero_approx() or tangent_back.is_zero_approx():
		return {"accepted": false, "reason": &"actor_collision_basis_invalid"}
	var vertices := PackedVector3Array()
	vertices.append(_actor_collision_vertex(
		focus_up, tangent_right, tangent_back, Vector2.ZERO
	))
	for radial_index in range(1, TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS + 1):
		var radius_m := (
			TERRAIN_ACTOR_COLLISION_RADIUS_M * float(radial_index)
				/ float(TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS)
		)
		for angular_index in TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS:
			var angle := (
				TAU * float(angular_index)
					/ float(TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS)
			)
			vertices.append(_actor_collision_vertex(
				focus_up,
				tangent_right,
				tangent_back,
				Vector2(cos(angle), sin(angle)) * radius_m,
			))
	if vertices.size() != TERRAIN_ACTOR_COLLISION_VERTEX_COUNT:
		return {"accepted": false, "reason": &"actor_collision_vertex_budget_drift"}
	var faces := PackedVector3Array()
	for angular_index in TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS:
		var next_angular := (
			(angular_index + 1) % TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS
		)
		_append_actor_collision_triangle(
			faces, vertices, 0, 1 + angular_index, 1 + next_angular
		)
	for radial_index in range(1, TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS):
		var inner_start := (
			1 + (radial_index - 1) * TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS
		)
		var outer_start := (
			inner_start + TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS
		)
		for angular_index in TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS:
			var next_angular := (
				(angular_index + 1) % TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS
			)
			_append_actor_collision_triangle(
				faces,
				vertices,
				inner_start + angular_index,
				outer_start + angular_index,
				outer_start + next_angular,
			)
			_append_actor_collision_triangle(
				faces,
				vertices,
				inner_start + angular_index,
				outer_start + next_angular,
				inner_start + next_angular,
			)
	var triangle_count := faces.size() / 3
	if triangle_count != TERRAIN_ACTOR_COLLISION_TRIANGLE_COUNT:
		return {"accepted": false, "reason": &"actor_collision_triangle_budget_drift"}
	# Follow the actor with a local collision origin as well as local coverage.
	# Retaining body-centred vertices here defeats the common-origin rebase.
	var collision_origin := focus_up * BODY_RADIUS_M
	for index in faces.size():
		faces[index] -= collision_origin
	var collision_shape := ConcavePolygonShape3D.new()
	collision_shape.set_faces(faces)
	collision_shape.backface_collision = false
	return {
		"accepted": true,
		"shape": collision_shape,
		"report": {
			"active": true,
			"reason": &"actor_collision_patch_built",
			"focus_radial_up": focus_up,
			"landing_surface_distance_m": landing_distance_m,
			"activation_distance_m": TERRAIN_RENDER_MAXIMUM_DISTANCE_M,
			"maximum_landing_surface_distance_m": PI * BODY_RADIUS_M,
			"support_radius_m": TERRAIN_ACTOR_COLLISION_RADIUS_M,
			"radial_segments": TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS,
			"angular_segments": TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS,
			"vertex_count": vertices.size(),
			"triangle_count": triangle_count,
			"topology": &"single_actor_following_relief_disc",
			"common_origin": true,
			"outward_clockwise_winding": true,
		}.duplicate(true),
	}.duplicate(true)


func _commit_actor_collision_support(staged: Dictionary) -> void:
	if _actor_collision_shape == null:
		return
	var report := staged.get("report", {}) as Dictionary
	if not bool(report.get("active", false)):
		_actor_collision_shape.disabled = true
		_actor_collision_body.position = Vector3.ZERO
		_actor_collision_report = report.duplicate(true)
		return
	var shape := staged.get("shape") as ConcavePolygonShape3D
	if shape == null:
		return
	_actor_collision_body.position = (report.focus_radial_up as Vector3) * BODY_RADIUS_M
	_actor_collision_shape.shape = shape
	_actor_collision_shape.disabled = false
	_actor_collision_report = report.duplicate(true)


func _inactive_actor_collision_report(reason: StringName) -> Dictionary:
	return {
		"active": false,
		"reason": reason,
		"focus_radial_up": Vector3.ZERO,
		"landing_surface_distance_m": 0.0,
		"activation_distance_m": TERRAIN_RENDER_MAXIMUM_DISTANCE_M,
		"maximum_landing_surface_distance_m": PI * BODY_RADIUS_M,
		"support_radius_m": TERRAIN_ACTOR_COLLISION_RADIUS_M,
		"radial_segments": TERRAIN_ACTOR_COLLISION_RADIAL_SEGMENTS,
		"angular_segments": TERRAIN_ACTOR_COLLISION_ANGULAR_SEGMENTS,
		"vertex_count": 0,
		"triangle_count": 0,
		"topology": &"single_actor_following_relief_disc",
		"common_origin": true,
		"outward_clockwise_winding": true,
	}.duplicate(true)


func _actor_collision_vertex(
		focus_up: Vector3,
		tangent_right: Vector3,
		tangent_back: Vector3,
		tangent_offset_m: Vector2,
	) -> Vector3:
	var tangent_point := (
		focus_up * BODY_RADIUS_M
			+ tangent_right * tangent_offset_m.x
			+ tangent_back * tangent_offset_m.y
	)
	var direction := tangent_point.normalized()
	var sample := _terrain_clipmap.sample_height(direction)
	return direction * (
		BODY_RADIUS_M + float(sample.get("height_m", 0.0))
	)


static func _append_actor_collision_triangle(
		faces: PackedVector3Array,
		vertices: PackedVector3Array,
		a: int,
		b: int,
		c: int,
	) -> void:
	var va := vertices[a]
	var vb := vertices[b]
	var vc := vertices[c]
	var mathematical_normal := (vb - va).cross(vc - va)
	var outward := (va + vb + vc).normalized()
	faces.append(va)
	if mathematical_normal.dot(outward) > 0.0:
		faces.append(vc)
		faces.append(vb)
	else:
		faces.append(vb)
		faces.append(vc)


static func _terrain_tangent_right(up: Vector3) -> Vector3:
	var reference := Vector3.FORWARD
	if absf(reference.dot(up)) > 0.95:
		reference = Vector3.RIGHT
	return reference.cross(up).normalized()


func _configure_surface_material_hierarchy() -> void:
	_configure_basalt_material(_material_at(^"BodyVisual"))
	_configure_basalt_material(_material_at(^"LandingRegion/CalderaFloor"))
	_configure_basalt_material(_material_at(^"LandingRegion/CalderaRim"))
	_configure_panel_material(
		_material_at(^"LandingRegion/PadVisual"),
		GRIP_PANEL_SCALE, GRIP_METALLIC, GRIP_ROUGHNESS,
		StationSurfaceKit.PanelFinish.WALKED_DECK,
	)
	_configure_panel_material(
		_material_at(^"LandingRegion/SurfaceLandmarks/EgressRouteVisual"),
		GRIP_PANEL_SCALE, GRIP_METALLIC, GRIP_ROUGHNESS,
		StationSurfaceKit.PanelFinish.WALKED_DECK,
	)
	_configure_non_emissive_accent_material(
		_material_at(^"LandingRegion/SurfaceLandmarks/EgressRouteVisual"),
		ROUTE_COLOR,
	)
	for path: NodePath in [
		^"LandingRegion/SurfaceLandmarks/SampleRack/RackVisual",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseVisual",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/MastVisual",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortPylonVisual",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/BaseVisual",
	]:
		_configure_panel_material(
			_material_at(path), METAL_PANEL_SCALE, METAL_METALLIC, METAL_ROUGHNESS,
			StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
		)
	_configure_panel_material(
		_material_at(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorVisual"),
		METAL_PANEL_SCALE, OXIDE_METALLIC, OXIDE_ROUGHNESS,
		StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
	)
	for path: NodePath in [
		^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadVisual",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/ShellVisual",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorVisual",
	]:
		_configure_panel_material(
			_material_at(path), SERVICE_PANEL_SCALE, SERVICE_METALLIC, SERVICE_ROUGHNESS,
			StationSurfaceKit.PanelFinish.PAINTED_METAL,
		)
	_configure_non_emissive_accent_material(
		_material_at(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorVisual"),
		DERELICT_OXIDE_COLOR,
	)
	_configure_non_emissive_accent_material(
		_material_at(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorVisual"),
		BUNKER_DOOR_COLOR,
	)


func _material_at(path: NodePath) -> StandardMaterial3D:
	var instance := get_node_or_null(path) as MeshInstance3D
	return instance.material_override as StandardMaterial3D if instance != null else null


static func _configure_basalt_material(material: StandardMaterial3D) -> void:
	if material == null:
		return
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.metallic = 0.0
	material.roughness = 1.0


static func _configure_panel_material(
		material: StandardMaterial3D,
		uv_scale: float,
		metallic: float,
		roughness: float,
		finish: StationSurfaceKit.PanelFinish,
	) -> void:
	if material == null:
		return
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if StationSurfaceKit.apply_panel_triplanar(material, uv_scale, finish):
		material.metallic = metallic
		material.roughness = roughness


## Accent colour is applied only to existing authored surfaces. The material
## remains fully lit and non-emissive, so the airless sun evaluation continues
## to own all illumination and accessibility cadence.
static func _configure_non_emissive_accent_material(
		material: StandardMaterial3D, accent_color: Color,
	) -> void:
	if material == null:
		return
	material.albedo_color = accent_color
	material.emission_enabled = false


static func _surface_material_is_exact(
		material: StandardMaterial3D,
		color: Color,
		role: StringName,
	) -> bool:
	if material == null \
			or material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
			or not material.albedo_color.is_equal_approx(color):
		return false
	if role == &"basalt":
		return is_zero_approx(material.metallic) \
			and is_equal_approx(material.roughness, 1.0) \
			and material.albedo_texture == null \
			and not material.normal_enabled \
			and not material.uv1_triplanar
	var expected_scale := GRIP_PANEL_SCALE if role == &"grip" else (
		SERVICE_PANEL_SCALE if role == &"service" else METAL_PANEL_SCALE
	)
	var expected_metallic := GRIP_METALLIC if role == &"grip" else (
		SERVICE_METALLIC if role == &"service" else (
			OXIDE_METALLIC if role == &"oxide" else METAL_METALLIC
		)
	)
	var expected_roughness := GRIP_ROUGHNESS if role == &"grip" else (
		SERVICE_ROUGHNESS if role == &"service" else (
			OXIDE_ROUGHNESS if role == &"oxide" else METAL_ROUGHNESS
		)
	)
	var expected_clearcoat := StationSurfaceKit.WALKED_CLEARCOAT \
		if role == &"grip" else (
			StationSurfaceKit.PAINTED_CLEARCOAT if role == &"service" \
			else StationSurfaceKit.STRUCTURAL_CLEARCOAT
		)
	var expected_clearcoat_roughness := StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS \
		if role == &"grip" else (
			StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS if role == &"service" \
			else StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS
		)
	return material.albedo_texture != null \
		and material.albedo_texture.resource_path == PANEL_ALBEDO_PATH \
		and material.normal_enabled and material.normal_texture != null \
		and material.normal_texture.resource_path == PANEL_NORMAL_PATH \
		and is_equal_approx(material.normal_scale, StationSurfaceKit.PANEL_NORMAL_SCALE) \
		and material.roughness_texture != null \
		and material.roughness_texture.resource_path == PANEL_ROUGHNESS_PATH \
		and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED \
		and material.uv1_triplanar and material.uv1_world_triplanar \
		and is_equal_approx(material.uv1_triplanar_sharpness, StationSurfaceKit.PANEL_TRIPLANAR_SHARPNESS) \
		and material.uv1_scale.is_equal_approx(Vector3.ONE * expected_scale) \
		and material.texture_repeat \
		and is_equal_approx(material.metallic, expected_metallic) \
		and is_equal_approx(material.roughness, expected_roughness) \
		and material.clearcoat_enabled \
		and is_equal_approx(material.clearcoat, expected_clearcoat) \
		and is_equal_approx(material.clearcoat_roughness, expected_clearcoat_roughness)


static func _surface_material_hierarchy_snapshot() -> Dictionary:
	return {
		"basalt": {"triplanar": false, "metallic": 0.0, "roughness": 1.0},
		"grip": {"triplanar": true, "uv_scale": GRIP_PANEL_SCALE, "finish": &"walked_deck"},
		"metal": {"triplanar": true, "uv_scale": METAL_PANEL_SCALE, "finish": &"structural_alloy"},
		"service": {"triplanar": true, "uv_scale": SERVICE_PANEL_SCALE, "finish": &"painted_metal"},
		"panel_maps": PackedStringArray([
			PANEL_ALBEDO_PATH, PANEL_NORMAL_PATH, PANEL_ROUGHNESS_PATH,
		]),
	}.duplicate(true)


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


func _validate_terrain_clipmap(errors: Array[Dictionary]) -> void:
	if _terrain_clipmap == null:
		_append_error(
			errors, &"terrain_clipmap_missing", &"TerrainClipmap",
			"production Ember must own its bounded terrain renderer",
		)
		return
	var terrain_audit := _terrain_clipmap.audit()
	var snapshot := terrain_audit.get("snapshot", {}) as Dictionary
	var expected_collision_ring_count := (
		2 if bool(snapshot.get("dynamic_collision_active", false)) else 1
	)
	var scene_snapshot := get_terrain_clipmap_snapshot()
	var actor_collision := scene_snapshot.get("actor_collision", {}) as Dictionary
	if (
		not bool(terrain_audit.get("valid", false))
		or StringName(snapshot.get("profile_id", &"")) != TERRAIN_PROFILE_ID
		or int(snapshot.get("ring_count", 0)) != TERRAIN_RING_COUNT
		or int(snapshot.get("render_vertex_count", 0)) != TERRAIN_RENDER_VERTEX_COUNT
		or int(snapshot.get("collision_ring_count", 0))
			!= expected_collision_ring_count
		or not (snapshot.get(
			"collision_focus_radial_up", Vector3.ZERO
		) as Vector3).is_equal_approx(Vector3.UP)
		or not is_equal_approx(
			float(snapshot.get("flatten_radius_m", -1.0)),
			TERRAIN_FLATTEN_RADIUS_M,
		)
		or not is_equal_approx(
			float(snapshot.get("visual_clearance_radius_m", -1.0)),
			TERRAIN_VISUAL_CLEARANCE_RADIUS_M,
		)
		or not is_equal_approx(
			float(snapshot.get("collision_clearance_radius_m", -1.0)),
			TERRAIN_COLLISION_CLEARANCE_RADIUS_M,
		)
		or not (snapshot.get("material_tint", Color.BLACK) as Color)
			.is_equal_approx(TERRAIN_MATERIAL_TINT)
	):
		_append_error(
			errors, &"terrain_clipmap_invalid", &"TerrainClipmap",
			"production Ember terrain roster, landing clearance, or basalt tint drifted",
		)
	if bool(snapshot.get("dynamic_collision_active", false)) \
			and bool(actor_collision.get("active", false)):
		_append_error(
			errors, &"terrain_collision_overlap", &"TerrainActorCollision",
			"landing corridor and actor-following patch must remain mutually exclusive",
		)
	if int(scene_snapshot.get("scene_collision_triangle_count", -1)) \
			> TERRAIN_COLLISION_TRIANGLE_CEILING \
			or int(scene_snapshot.get("scene_collision_vertex_count", -1)) \
				> TERRAIN_COLLISION_VERTEX_CEILING:
		_append_error(
			errors, &"terrain_collision_budget_exceeded", &"TerrainActorCollision",
			"combined fixed, corridor, and actor collision exceeded its hard ceiling",
		)


func _validate_topology(errors: Array[Dictionary]) -> void:
	var expected := {
		^"BodyVisual": "MeshInstance3D",
		^"TerrainClipmap": "Node3D",
		^"TerrainActorCollision": "StaticBody3D",
		^"TerrainActorCollision/TerrainActorCollisionSurface": "CollisionShape3D",
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
		^"LandingRegion/SurfaceLandmarks/RouteSpineVisuals": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack/RackVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack/IdentityVaneVisuals": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SampleRack/CollisionShape3D": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/MastVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/MastCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortPylonCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardPylonCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/GantryPylonVisuals": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortBeamVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortBeamCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardBeamVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/StarboardBeamCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/SensorBoomVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/SensorBoomCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownVisuals": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownCrossXCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownCrossZCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownPositiveXFinCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownNegativeXFinCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownPositiveZFinCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/NavigationCrownNegativeZFinCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker": "StaticBody3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/BaseVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/BaseCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/ShellVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/ShellCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/RoofVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/RoofCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorVisual": "MeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorCollision": "CollisionShape3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/BunkerVentVisuals": "MultiMeshInstance3D",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/PortVentCollision": "CollisionShape3D",
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
	var dynamic_collision_active := bool(
		get_terrain_clipmap_snapshot().get("dynamic_collision_active", false)
	)
	var generated_collision_delta := 1 if dynamic_collision_active else 0
	if _count_nodes() != EXPECTED_NODE_COUNT + generated_collision_delta:
		_append_error(errors, &"node_roster_drift", &"scene", "authored scene exact node roster drifted")
	var landing_root := get_node_or_null(^"LandingRegion")
	var walkable := get_node_or_null(^"LandingRegion/WalkablePatch")
	var markers := get_node_or_null(^"LandingRegion/Markers")
	var landmarks := get_node_or_null(^"LandingRegion/SurfaceLandmarks")
	var route_markers := get_node_or_null(^"LandingRegion/SurfaceLandmarks/RouteMarkers")
	var relay := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay")
	var gantry := get_node_or_null(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry")
	var bunker := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker")
	var terrain_root := get_node_or_null(^"TerrainClipmap")
	var committed_terrain := get_node_or_null(^"TerrainClipmap/CommittedTerrain")
	var terrain_visuals := get_node_or_null(
		^"TerrainClipmap/CommittedTerrain/TerrainVisuals"
	)
	var terrain_collision := get_node_or_null(
		^"TerrainClipmap/CommittedTerrain/TerrainCollision"
	)
	var actor_collision := get_node_or_null(^"TerrainActorCollision") \
		as StaticBody3D
	if get_child_count() != 4 \
			or terrain_root == null or terrain_root.get_child_count() != 1 \
			or committed_terrain == null or committed_terrain.get_child_count() != 2 \
			or terrain_visuals == null or terrain_visuals.get_child_count() != TERRAIN_RING_COUNT \
			or terrain_collision == null \
			or terrain_collision.get_child_count() \
				!= 1 + generated_collision_delta \
			or actor_collision == null \
			or actor_collision.get_child_count() != 1 \
			or landing_root == null or landing_root.get_child_count() != 6 \
			or walkable == null or walkable.get_child_count() != 1 \
			or markers == null or markers.get_child_count() != 4 \
			or landmarks == null or landmarks.get_child_count() != 12 \
			or route_markers == null or route_markers.get_child_count() != 5 \
			or relay == null or relay.get_child_count() != 6 \
			or gantry == null or gantry.get_child_count() != 18 \
			or bunker == null or bunker.get_child_count() != 11:
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
	var route_spine := get_node_or_null(^"LandingRegion/SurfaceLandmarks/RouteSpineVisuals") as MultiMeshInstance3D
	var approach_cues := get_node_or_null(^"LandingRegion/SurfaceLandmarks/LandingApproachCues") as MultiMeshInstance3D
	var orbital_cue := get_node_or_null(^"LandingRegion/SurfaceLandmarks/OrbitalLandingDatumCue") as MultiMeshInstance3D
	var pad_guides := get_node_or_null(^"LandingRegion/SurfaceLandmarks/PadGuideVisuals") as MultiMeshInstance3D
	var rack := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SampleRack/RackVisual") as MeshInstance3D
	var rack_vane := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/SampleRack/IdentityVaneVisuals"
	) as MultiMeshInstance3D
	var relay_base := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay/BaseVisual") as MeshInstance3D
	var relay_mast := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay/MastVisual") as MeshInstance3D
	var relay_head := get_node_or_null(^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadVisual") as MeshInstance3D
	var gantry := get_node_or_null(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry") as StaticBody3D
	var gantry_pylons := gantry.get_node_or_null(^"GantryPylonVisuals") as MultiMeshInstance3D \
		if gantry != null else null
	var route_spine_accent := gantry.get_node_or_null(^"DeadSensorVisual") as MeshInstance3D \
		if gantry != null else null
	var bunker := get_node_or_null(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker") as StaticBody3D
	var body_mesh := body.mesh as SphereMesh if body != null else null
	var floor_mesh := floor.mesh as CylinderMesh if floor != null else null
	var rim_mesh := rim.mesh as TorusMesh if rim != null else null
	var pad_mesh := pad.mesh as BoxMesh if pad != null else null
	var route_mesh := route.mesh as BoxMesh if route != null else null
	var rack_mesh := rack.mesh as BoxMesh if rack != null else null
	var relay_base_mesh := relay_base.mesh as BoxMesh if relay_base != null else null
	var relay_mast_mesh := relay_mast.mesh as CylinderMesh if relay_mast != null else null
	var relay_head_mesh := relay_head.mesh as PrismMesh if relay_head != null else null
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
	if not _surface_route_spine_is_exact(route_spine, route_spine_accent):
		_append_error(errors, &"surface_route_spine_drift", &"RouteSpineVisuals", "passive route-and-turn survey spine drifted")
	if not _landing_approach_cues_are_exact(approach_cues, pad_guides):
		_append_error(errors, &"landing_approach_cue_drift", &"LandingApproachCues", "batched final-approach chevrons drifted from their bounded passive recipe")
	if not _orbital_landing_datum_cue_is_exact(orbital_cue, route):
		_append_error(errors, &"orbital_landing_datum_cue_drift", &"OrbitalLandingDatumCue", "orbital landing-side arrow drifted from the exact approach-to-pad datum")
	if not _pad_guide_visuals_are_exact(pad_guides):
		_append_error(errors, &"pad_guidance_visual_drift", &"PadGuidance", "paired solid pad guidance recipe drifted")
	if rack_mesh == null or rack_mesh.size != SAMPLE_RACK_SIZE_M:
		_append_error(errors, &"sample_rack_visual_drift", &"SampleRack", "low solid sample-rack recipe drifted")
	if not _sample_rack_identity_vane_is_exact(rack_vane, route_spine_accent):
		_append_error(errors, &"sample_rack_identity_vane_drift", &"SampleRack", "passive sample-rack diamond identity drifted")
	if relay_base_mesh == null or relay_base_mesh.size != RELAY_BASE_SIZE_M \
			or relay_mast_mesh == null \
			or not is_equal_approx(relay_mast_mesh.top_radius, RELAY_MAST_RADIUS_M) \
			or not is_equal_approx(relay_mast_mesh.bottom_radius, RELAY_MAST_RADIUS_M) \
			or relay_mast_mesh.height != RELAY_MAST_HEIGHT_M \
			or relay_mast_mesh.radial_segments != 12 \
			or relay_head_mesh == null or relay_head_mesh.size != RELAY_HEAD_SIZE_M \
			or int(relay_head_mesh.get_faces().size() / 3) != 8:
		_append_error(errors, &"staging_relay_visual_drift", &"StagingRelay", "solid staging-relay recipe drifted")
	if not _derelict_gantry_geometry_is_exact(gantry):
		_append_error(errors, &"derelict_gantry_visual_drift", &"DerelictSurveyGantry", "derelict survey-gantry silhouette or passive material recipe drifted")
	if not _survey_bunker_geometry_is_exact(bunker):
		_append_error(errors, &"survey_bunker_visual_drift", &"SurveyServiceBunker", "survey service-bunker silhouette or passive material recipe drifted")
	var material_specs := {
		body: {"color": BODY_COLOR, "role": &"basalt"},
		floor: {"color": FLOOR_COLOR, "role": &"basalt"},
		rim: {"color": RIM_COLOR, "role": &"basalt"},
		pad: {"color": PAD_COLOR, "role": &"grip"},
		route: {"color": ROUTE_COLOR, "role": &"grip"},
		rack: {"color": EQUIPMENT_COLOR, "role": &"metal"},
		relay_base: {"color": EQUIPMENT_COLOR, "role": &"metal"},
		relay_mast: {"color": EQUIPMENT_COLOR, "role": &"metal"},
		relay_head: {"color": RELAY_COLOR, "role": &"service"},
	}
	if gantry != null:
		for node_name in [&"PortBeamVisual", &"StarboardBeamVisual", &"SensorBoomVisual"]:
			material_specs[gantry.get_node_or_null(NodePath(node_name)) as MeshInstance3D] = {"color": DERELICT_ALLOY_COLOR, "role": &"metal"}
		material_specs[gantry.get_node_or_null(^"DeadSensorVisual") as MeshInstance3D] = {"color": DERELICT_OXIDE_COLOR, "role": &"oxide"}
	if bunker != null:
		for node_name in [&"BaseVisual", &"RoofVisual"]:
			material_specs[bunker.get_node_or_null(NodePath(node_name)) as MeshInstance3D] = {"color": DERELICT_ALLOY_COLOR, "role": &"metal"}
		material_specs[bunker.get_node_or_null(^"ShellVisual") as MeshInstance3D] = {"color": BUNKER_SHELL_COLOR, "role": &"service"}
		material_specs[bunker.get_node_or_null(^"DoorVisual") as MeshInstance3D] = {"color": BUNKER_DOOR_COLOR, "role": &"service"}
	for instance: MeshInstance3D in material_specs:
		var material := instance.material_override as StandardMaterial3D if instance != null else null
		var spec := material_specs[instance] as Dictionary
		if not _surface_material_is_exact(material, spec.color, spec.role) \
				or instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				or instance.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
			_append_error(errors, &"visual_material_drift", &"materials", "airless surface material hierarchy or passive renderer contract drifted")
			break
	var vent_batch := bunker.get_node_or_null(^"BunkerVentVisuals") as MultiMeshInstance3D \
		if bunker != null else null
	var vent_material := vent_batch.material_override as StandardMaterial3D \
		if vent_batch != null else null
	if not _surface_material_is_exact(vent_material, DERELICT_ALLOY_COLOR, &"metal"):
		_append_error(errors, &"visual_material_drift", &"BunkerVentVisuals", "batched bunker vents lost the structural-alloy surface role")
	var crown := gantry.get_node_or_null(^"NavigationCrownVisuals") as MultiMeshInstance3D \
		if gantry != null else null
	var crown_material := crown.material_override as StandardMaterial3D if crown != null else null
	if not _surface_material_is_exact(crown_material, DERELICT_OXIDE_COLOR, &"oxide"):
		_append_error(errors, &"visual_material_drift", &"NavigationCrownVisuals", "survey crown lost the existing oxide landmark role")
	var pylon_material := gantry_pylons.material_override as StandardMaterial3D \
		if gantry_pylons != null else null
	if not _surface_material_is_exact(pylon_material, DERELICT_ALLOY_COLOR, &"metal"):
		_append_error(errors, &"visual_material_drift", &"GantryPylonVisuals", "batched gantry pylons lost the structural-alloy surface role")
	var rack_vane_material := rack_vane.material_override as StandardMaterial3D \
		if rack_vane != null else null
	if not _surface_material_is_exact(
		rack_vane_material, DERELICT_OXIDE_COLOR, &"oxide"
	):
		_append_error(errors, &"visual_material_drift", &"IdentityVaneVisuals", "sample-rack vane lost the existing oxide landmark role")


func _derelict_gantry_geometry_is_exact(gantry: StaticBody3D) -> bool:
	if gantry == null or gantry.position != GANTRY_ROOT_POSITION_M:
		return false
	return _gantry_pylon_visuals_are_exact(
		gantry.get_node_or_null(^"GantryPylonVisuals") as MultiMeshInstance3D
	) \
		and _box_visual_is_exact(gantry, &"PortBeamVisual", GANTRY_BEAM_SIZE_M, GANTRY_PORT_BEAM_POSITION_M, GANTRY_PORT_BEAM_TILT_RADIANS) \
		and _box_visual_is_exact(gantry, &"StarboardBeamVisual", GANTRY_BEAM_SIZE_M, GANTRY_STARBOARD_BEAM_POSITION_M, GANTRY_STARBOARD_BEAM_TILT_RADIANS) \
		and _cylinder_visual_is_exact(gantry, &"SensorBoomVisual", GANTRY_BOOM_RADIUS_M, GANTRY_BOOM_HEIGHT_M, GANTRY_BOOM_POSITION_M, GANTRY_BOOM_TILT_RADIANS) \
		and _box_visual_is_exact(gantry, &"DeadSensorVisual", GANTRY_SENSOR_SIZE_M, GANTRY_SENSOR_POSITION_M, GANTRY_SENSOR_TILT_RADIANS) \
		and _gantry_navigation_crown_is_exact(gantry.get_node_or_null(^"NavigationCrownVisuals") as MultiMeshInstance3D)


func _survey_bunker_geometry_is_exact(bunker: StaticBody3D) -> bool:
	if bunker == null or bunker.position != BUNKER_ROOT_POSITION_M \
			or not bunker.rotation.is_equal_approx(Vector3(0.0, BUNKER_YAW_RADIANS, 0.0)):
		return false
	return _box_visual_is_exact(bunker, &"BaseVisual", BUNKER_BASE_SIZE_M, BUNKER_BASE_POSITION_M, 0.0) \
		and _box_visual_is_exact(bunker, &"ShellVisual", BUNKER_SHELL_SIZE_M, BUNKER_SHELL_POSITION_M, 0.0) \
		and _box_visual_is_exact(bunker, &"RoofVisual", BUNKER_ROOF_SIZE_M, BUNKER_ROOF_POSITION_M, 0.0) \
		and _box_visual_is_exact(bunker, &"DoorVisual", BUNKER_DOOR_SIZE_M, BUNKER_DOOR_POSITION_M, 0.0) \
		and _bunker_vent_visuals_are_exact(
			bunker.get_node_or_null(^"BunkerVentVisuals") as MultiMeshInstance3D
		)


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
	var actor_body := get_node_or_null(^"TerrainActorCollision") \
		as StaticBody3D
	var actor_collision := get_node_or_null(
		^"TerrainActorCollision/TerrainActorCollisionSurface"
	) as CollisionShape3D
	var actor_active := bool(_actor_collision_report.get("active", false))
	var actor_shape := actor_collision.shape as ConcavePolygonShape3D \
		if actor_collision != null else null
	var actor_faces := actor_shape.get_faces() \
		if actor_shape != null else PackedVector3Array()
	var actor_contract_valid := (
		actor_body != null
			and actor_body.basis == Basis.IDENTITY
			and actor_body.position == (
				(_actor_collision_report.get("focus_radial_up", Vector3.ZERO) as Vector3) * BODY_RADIUS_M
				if actor_active else Vector3.ZERO
			)
			and actor_body.collision_layer == WORLD_LAYER
			and actor_body.collision_mask == 0
			and bool(actor_body.get_meta(&"common_origin_owner", false))
			and bool(actor_body.get_meta(&"generated_planetary_terrain", false))
			and actor_collision != null
			and actor_collision.transform == Transform3D.IDENTITY
			and actor_collision.disabled != actor_active
			and int(_actor_collision_report.get("triangle_count", -1))
				== (
					TERRAIN_ACTOR_COLLISION_TRIANGLE_COUNT
					if actor_active else 0
				)
			and int(_actor_collision_report.get("vertex_count", -1))
				== (
					TERRAIN_ACTOR_COLLISION_VERTEX_COUNT
					if actor_active else 0
				)
	)
	if actor_active:
		actor_contract_valid = actor_contract_valid \
			and actor_shape != null \
			and not actor_shape.backface_collision \
			and actor_faces.size() \
				== TERRAIN_ACTOR_COLLISION_TRIANGLE_COUNT * 3 \
			and float(_actor_collision_report.get(
				"landing_surface_distance_m", 0.0
			)) > TERRAIN_RENDER_MAXIMUM_DISTANCE_M \
			and _actor_collision_winding_is_outward(actor_faces, actor_body.position)
	if not actor_contract_valid:
		_append_error(
			errors, &"actor_collision_support_drift", &"TerrainActorCollision",
			"single common-origin actor collision patch drifted from its bounded contract",
		)
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


static func _actor_collision_winding_is_outward(
		faces: PackedVector3Array, origin: Vector3,
	) -> bool:
	if faces.size() != TERRAIN_ACTOR_COLLISION_TRIANGLE_COUNT * 3:
		return false
	for face_index in range(0, faces.size(), 3):
		var a := faces[face_index] + origin
		var b := faces[face_index + 1] + origin
		var c := faces[face_index + 2] + origin
		var mathematical_normal := (b - a).cross(c - a)
		var outward := (a + b + c).normalized()
		if mathematical_normal.is_zero_approx() \
				or mathematical_normal.dot(outward) >= 0.0:
			return false
	return true


func _derelict_gantry_collision_is_exact(gantry: StaticBody3D) -> bool:
	if gantry == null:
		return false
	var exact := _box_collision_is_exact(gantry, &"PortPylonCollision", GANTRY_PYLON_SIZE_M, GANTRY_PORT_PYLON_POSITION_M, GANTRY_PYLON_LEAN_RADIANS) \
		and _box_collision_is_exact(gantry, &"StarboardPylonCollision", GANTRY_PYLON_SIZE_M, GANTRY_STARBOARD_PYLON_POSITION_M, -GANTRY_PYLON_LEAN_RADIANS) \
		and _box_collision_is_exact(gantry, &"PortBeamCollision", GANTRY_BEAM_SIZE_M, GANTRY_PORT_BEAM_POSITION_M, GANTRY_PORT_BEAM_TILT_RADIANS) \
		and _box_collision_is_exact(gantry, &"StarboardBeamCollision", GANTRY_BEAM_SIZE_M, GANTRY_STARBOARD_BEAM_POSITION_M, GANTRY_STARBOARD_BEAM_TILT_RADIANS) \
		and _cylinder_collision_is_exact(gantry, &"SensorBoomCollision", GANTRY_BOOM_RADIUS_M, GANTRY_BOOM_HEIGHT_M, GANTRY_BOOM_POSITION_M, GANTRY_BOOM_TILT_RADIANS) \
		and _box_collision_is_exact(gantry, &"DeadSensorCollision", GANTRY_SENSOR_SIZE_M, GANTRY_SENSOR_POSITION_M, GANTRY_SENSOR_TILT_RADIANS)
	for spec: Dictionary in _gantry_navigation_crown_collision_specs():
		exact = exact and _box_collision_is_exact(
			gantry, spec.name, spec.size, spec.position, 0.0
		)
	return exact


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
				or node is Timer \
				or node is Area3D or node is NavigationRegion3D \
				or node is AudioStreamPlayer or node is AudioStreamPlayer3D \
				or node is GPUParticles3D or node is CPUParticles3D \
				or node is AnimationPlayer or node is CharacterBody3D \
				or node is RigidBody3D:
			_append_error(errors, &"forbidden_runtime_node", StringName(node.name), "scene gained adjacent runtime authority")
		if node.is_processing() or node.is_physics_processing():
			_append_error(errors, &"automatic_process_loop", StringName(node.name), "static scene must not own process or physics callbacks")


func _configure_sample_rack_identity_vane() -> void:
	var rack := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/SampleRack"
	) as StaticBody3D
	var oxide_accent := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorVisual"
	) as MeshInstance3D
	if rack == null or oxide_accent == null or oxide_accent.material_override == null:
		return
	var unit_bar := BoxMesh.new()
	unit_bar.size = Vector3.ONE
	unit_bar.material = oxide_accent.material_override
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = unit_bar
	multi.instance_count = SAMPLE_RACK_VANE_INSTANCE_COUNT
	var transforms := _sample_rack_identity_vane_transforms()
	multi.buffer = _encode_multi_mesh_transforms(transforms)
	multi.custom_aabb = SAMPLE_RACK_VANE_BATCH_BOUNDS
	var vane := MultiMeshInstance3D.new()
	vane.name = &"IdentityVaneVisuals"
	vane.multimesh = multi
	vane.material_override = oxide_accent.material_override
	vane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vane.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	vane.set_meta("authored_transforms", transforms.duplicate())
	vane.set_meta("landmark_id", &"ember_sample_rack")
	vane.set_meta("silhouette", &"crossed_open_diamonds_over_low_rack")
	vane.set_meta("readable_axes", PackedStringArray([
		"walked_route_x", "rack_access_z",
	]))
	vane.set_meta(
		"gameplay_readability_distance_m",
		SAMPLE_RACK_VANE_GAMEPLAY_READABILITY_DISTANCE_M,
	)
	vane.set_meta("color_independent", true)
	vane.set_meta("content_class", &"NEW")
	vane.set_meta("status", &"modern_interpretation")
	vane.set_meta("collision_role", &"passive_noninteractive_identity_vane")
	rack.add_child(vane)


func _sample_rack_identity_vane_is_exact(
		vane: MultiMeshInstance3D,
		oxide_accent: MeshInstance3D,
	) -> bool:
	if vane == null or oxide_accent == null or vane.multimesh == null \
			or vane.get_child_count() != 0 \
			or vane.transform != Transform3D.IDENTITY \
			or vane.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or vane.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or StringName(vane.get_meta("landmark_id", &"")) != &"ember_sample_rack" \
			or StringName(vane.get_meta("silhouette", &"")) != &"crossed_open_diamonds_over_low_rack" \
			or vane.get_meta("readable_axes", PackedStringArray()) \
				!= PackedStringArray(["walked_route_x", "rack_access_z"]) \
			or float(vane.get_meta("gameplay_readability_distance_m", 0.0)) \
				!= SAMPLE_RACK_VANE_GAMEPLAY_READABILITY_DISTANCE_M \
			or not bool(vane.get_meta("color_independent", false)) \
			or StringName(vane.get_meta("content_class", &"")) != &"NEW" \
			or StringName(vane.get_meta("status", &"")) != &"modern_interpretation" \
			or StringName(vane.get_meta("collision_role", &"")) \
				!= &"passive_noninteractive_identity_vane":
		return false
	var multi := vane.multimesh
	var unit_bar := multi.mesh as BoxMesh
	if multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.instance_count != SAMPLE_RACK_VANE_INSTANCE_COUNT \
			or multi.visible_instance_count not in [-1, SAMPLE_RACK_VANE_INSTANCE_COUNT] \
			or not multi.custom_aabb.is_equal_approx(SAMPLE_RACK_VANE_BATCH_BOUNDS) \
			or unit_bar == null or unit_bar.size != Vector3.ONE \
			or unit_bar.material != oxide_accent.material_override \
			or vane.material_override != oxide_accent.material_override:
		return false
	var expected := _sample_rack_identity_vane_transforms()
	var authored: Variant = vane.get_meta("authored_transforms", [])
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(
					expected[index]
				):
			return false
	return _multi_mesh_live_transforms_are_exact(multi, expected)


static func _sample_rack_identity_vane_transforms() -> Array[Transform3D]:
	var left_x := Vector3(-SAMPLE_RACK_VANE_HALF_WIDTH_M, SAMPLE_RACK_VANE_CENTRE_Y_M, 0.0)
	var left_z := Vector3(0.0, SAMPLE_RACK_VANE_CENTRE_Y_M, -SAMPLE_RACK_VANE_HALF_WIDTH_M)
	var top := Vector3(0.0, SAMPLE_RACK_VANE_CENTRE_Y_M + SAMPLE_RACK_VANE_HALF_HEIGHT_M, 0.0)
	var right_x := Vector3(SAMPLE_RACK_VANE_HALF_WIDTH_M, SAMPLE_RACK_VANE_CENTRE_Y_M, 0.0)
	var right_z := Vector3(0.0, SAMPLE_RACK_VANE_CENTRE_Y_M, SAMPLE_RACK_VANE_HALF_WIDTH_M)
	var bottom := Vector3(0.0, SAMPLE_RACK_VANE_CENTRE_Y_M - SAMPLE_RACK_VANE_HALF_HEIGHT_M, 0.0)
	return [
		_vane_bar_between(left_x, top, Vector3.FORWARD),
		_vane_bar_between(top, right_x, Vector3.FORWARD),
		_vane_bar_between(right_x, bottom, Vector3.FORWARD),
		_vane_bar_between(bottom, left_x, Vector3.FORWARD),
		_vane_bar_between(left_z, top, Vector3.RIGHT),
		_vane_bar_between(top, right_z, Vector3.RIGHT),
		_vane_bar_between(right_z, bottom, Vector3.RIGHT),
		_vane_bar_between(bottom, left_z, Vector3.RIGHT),
		Transform3D(
			Basis().scaled(Vector3(
				SAMPLE_RACK_VANE_BAR_THICKNESS_M,
				SAMPLE_RACK_VANE_POST_HEIGHT_M,
				SAMPLE_RACK_VANE_DEPTH_M,
			)),
			Vector3(0.0, SAMPLE_RACK_VANE_POST_HEIGHT_M * 0.5, 0.0),
		),
	]


static func _vane_bar_between(
		start: Vector3,
		finish: Vector3,
		plane_normal: Vector3,
	) -> Transform3D:
	var direction := (finish - start).normalized()
	var in_plane_normal := plane_normal.cross(direction).normalized()
	return Transform3D(
		Basis(
			direction * start.distance_to(finish),
			in_plane_normal * SAMPLE_RACK_VANE_BAR_THICKNESS_M,
			plane_normal * SAMPLE_RACK_VANE_DEPTH_M,
		),
		(start + finish) * 0.5,
	)


func _configure_gantry_pylon_visuals() -> void:
	var gantry := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry"
	) as StaticBody3D
	var port := gantry.get_node_or_null(^"PortPylonVisual") as MeshInstance3D \
		if gantry != null else null
	var starboard := gantry.get_node_or_null(^"StarboardPylonVisual") as MeshInstance3D \
		if gantry != null else null
	if gantry == null or port == null or starboard == null \
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
	var transforms: Array[Transform3D] = [port.transform, starboard.transform]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = port.mesh
	multi.instance_count = GANTRY_PYLON_INSTANCE_COUNT
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	multi.custom_aabb = GANTRY_PYLON_BATCH_BOUNDS
	var batch := MultiMeshInstance3D.new()
	batch.name = &"GantryPylonVisuals"
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
	batch.set_meta("source_visual_ids", PackedStringArray([
		"PortPylonVisual", "StarboardPylonVisual",
	]))
	gantry.add_child(batch)
	port.free()
	starboard.free()


func _gantry_pylon_visuals_are_exact(batch: MultiMeshInstance3D) -> bool:
	if batch == null or batch.multimesh == null \
			or batch.transform != Transform3D.IDENTITY \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or batch.layers != 1 or batch.ignore_occlusion_culling \
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
	if multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.instance_count != GANTRY_PYLON_INSTANCE_COUNT \
			or multi.visible_instance_count not in [-1, GANTRY_PYLON_INSTANCE_COUNT] \
			or not multi.custom_aabb.is_equal_approx(GANTRY_PYLON_BATCH_BOUNDS) \
			or mesh == null or mesh.size != GANTRY_PYLON_SIZE_M \
			or batch.material_override == null:
		return false
	var expected: Array[Transform3D] = [
		Transform3D(Basis.from_euler(Vector3(GANTRY_PYLON_LEAN_RADIANS, 0.0, 0.0)), GANTRY_PORT_PYLON_POSITION_M),
		Transform3D(Basis.from_euler(Vector3(-GANTRY_PYLON_LEAN_RADIANS, 0.0, 0.0)), GANTRY_STARBOARD_PYLON_POSITION_M),
	]
	var authored: Variant = batch.get_meta("authored_transforms", [])
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return batch.get_meta("source_visual_ids", PackedStringArray()) == PackedStringArray([
		"PortPylonVisual", "StarboardPylonVisual",
	])


func _configure_gantry_navigation_crown() -> void:
	var gantry := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry"
	) as StaticBody3D
	var sensor := gantry.get_node_or_null(^"DeadSensorVisual") as MeshInstance3D \
		if gantry != null else null
	if gantry == null or sensor == null or sensor.material_override == null:
		return
	var unit_bar := BoxMesh.new()
	unit_bar.size = Vector3.ONE
	unit_bar.material = sensor.material_override
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = unit_bar
	multi.instance_count = GANTRY_CROWN_INSTANCE_COUNT
	var transforms := _gantry_navigation_crown_transforms()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	multi.custom_aabb = GANTRY_CROWN_BATCH_BOUNDS
	var crown := MultiMeshInstance3D.new()
	crown.name = &"NavigationCrownVisuals"
	crown.multimesh = multi
	crown.material_override = sensor.material_override
	crown.cast_shadow = sensor.cast_shadow
	crown.gi_mode = sensor.gi_mode
	crown.layers = sensor.layers
	crown.ignore_occlusion_culling = sensor.ignore_occlusion_culling
	crown.set_meta("authored_transforms", transforms.duplicate())
	crown.set_meta("content_class", &"NEW")
	crown.set_meta("status", &"modern_interpretation")
	crown.set_meta("solid_visual_collision", true)
	crown.set_meta("readable_axes", PackedStringArray(["flight_z", "walked_route_x"]))
	gantry.add_child(crown)
	for spec: Dictionary in _gantry_navigation_crown_collision_specs():
		var shape := BoxShape3D.new()
		shape.size = spec.size
		var collision := CollisionShape3D.new()
		collision.name = spec.name
		collision.position = spec.position
		collision.shape = shape
		gantry.add_child(collision)


func _gantry_navigation_crown_is_exact(crown: MultiMeshInstance3D) -> bool:
	if crown == null or crown.multimesh == null \
			or crown.transform != Transform3D.IDENTITY \
			or crown.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or crown.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or crown.layers != 1 or crown.ignore_occlusion_culling \
			or crown.get_child_count() != 0 \
			or StringName(crown.get_meta("content_class", &"")) != &"NEW" \
			or StringName(crown.get_meta("status", &"")) != &"modern_interpretation" \
			or not bool(crown.get_meta("solid_visual_collision", false)) \
			or crown.get_meta("readable_axes", PackedStringArray()) \
				!= PackedStringArray(["flight_z", "walked_route_x"]):
		return false
	var multi := crown.multimesh
	var unit_bar := multi.mesh as BoxMesh
	if multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.instance_count != GANTRY_CROWN_INSTANCE_COUNT \
			or multi.visible_instance_count not in [-1, GANTRY_CROWN_INSTANCE_COUNT] \
			or not multi.custom_aabb.is_equal_approx(GANTRY_CROWN_BATCH_BOUNDS) \
			or unit_bar == null or unit_bar.size != Vector3.ONE \
			or unit_bar.material != crown.material_override:
		return false
	var expected := _gantry_navigation_crown_transforms()
	var authored: Variant = crown.get_meta("authored_transforms", [])
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


static func _gantry_navigation_crown_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = [
		Transform3D(
			Basis().scaled(Vector3(
				GANTRY_CROWN_CROSS_SPAN_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
			)),
			GANTRY_CROWN_CENTRE_M,
		),
		Transform3D(
			Basis().scaled(Vector3(
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_CROSS_SPAN_M,
			)),
			GANTRY_CROWN_CENTRE_M,
		),
	]
	for offset: Vector3 in [
		Vector3(GANTRY_CROWN_FIN_OFFSET_M, 0.0, 0.0),
		Vector3(-GANTRY_CROWN_FIN_OFFSET_M, 0.0, 0.0),
		Vector3(0.0, 0.0, GANTRY_CROWN_FIN_OFFSET_M),
		Vector3(0.0, 0.0, -GANTRY_CROWN_FIN_OFFSET_M),
	]:
		transforms.append(Transform3D(
			Basis().scaled(Vector3(
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_FIN_HEIGHT_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
			)),
			GANTRY_CROWN_CENTRE_M + offset
				+ Vector3.UP * (GANTRY_CROWN_FIN_HEIGHT_M * 0.5 - GANTRY_CROWN_BAR_THICKNESS_M * 0.5),
		))
	return transforms


static func _gantry_navigation_crown_collision_specs() -> Array[Dictionary]:
	var fin_position_y := GANTRY_CROWN_CENTRE_M.y \
		+ GANTRY_CROWN_FIN_HEIGHT_M * 0.5 - GANTRY_CROWN_BAR_THICKNESS_M * 0.5
	return [
		{
			"name": &"NavigationCrownCrossXCollision",
			"size": Vector3(
				GANTRY_CROWN_CROSS_SPAN_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
			),
			"position": GANTRY_CROWN_CENTRE_M,
		},
		{
			"name": &"NavigationCrownCrossZCollision",
			"size": Vector3(
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_BAR_THICKNESS_M,
				GANTRY_CROWN_CROSS_SPAN_M,
			),
			"position": GANTRY_CROWN_CENTRE_M,
		},
		{
			"name": &"NavigationCrownPositiveXFinCollision",
			"size": Vector3(GANTRY_CROWN_BAR_THICKNESS_M, GANTRY_CROWN_FIN_HEIGHT_M, GANTRY_CROWN_BAR_THICKNESS_M),
			"position": Vector3(GANTRY_CROWN_FIN_OFFSET_M, fin_position_y, GANTRY_CROWN_CENTRE_M.z),
		},
		{
			"name": &"NavigationCrownNegativeXFinCollision",
			"size": Vector3(GANTRY_CROWN_BAR_THICKNESS_M, GANTRY_CROWN_FIN_HEIGHT_M, GANTRY_CROWN_BAR_THICKNESS_M),
			"position": Vector3(-GANTRY_CROWN_FIN_OFFSET_M, fin_position_y, GANTRY_CROWN_CENTRE_M.z),
		},
		{
			"name": &"NavigationCrownPositiveZFinCollision",
			"size": Vector3(GANTRY_CROWN_BAR_THICKNESS_M, GANTRY_CROWN_FIN_HEIGHT_M, GANTRY_CROWN_BAR_THICKNESS_M),
			"position": Vector3(0.0, fin_position_y, GANTRY_CROWN_CENTRE_M.z + GANTRY_CROWN_FIN_OFFSET_M),
		},
		{
			"name": &"NavigationCrownNegativeZFinCollision",
			"size": Vector3(GANTRY_CROWN_BAR_THICKNESS_M, GANTRY_CROWN_FIN_HEIGHT_M, GANTRY_CROWN_BAR_THICKNESS_M),
			"position": Vector3(0.0, fin_position_y, GANTRY_CROWN_CENTRE_M.z - GANTRY_CROWN_FIN_OFFSET_M),
		},
	]


func _configure_bunker_vent_visuals() -> void:
	var bunker := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker"
	) as StaticBody3D
	var port := bunker.get_node_or_null(^"PortVentVisual") as MeshInstance3D \
		if bunker != null else null
	var starboard := bunker.get_node_or_null(^"StarboardVentVisual") as MeshInstance3D \
		if bunker != null else null
	if bunker == null or port == null or starboard == null \
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
	var transforms: Array[Transform3D] = [port.transform, starboard.transform]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = port.mesh
	multi.instance_count = BUNKER_VENT_INSTANCE_COUNT
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	multi.custom_aabb = BUNKER_VENT_BATCH_BOUNDS
	var batch := MultiMeshInstance3D.new()
	batch.name = &"BunkerVentVisuals"
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
	batch.set_meta("source_visual_ids", PackedStringArray([
		"PortVentVisual", "StarboardVentVisual",
	]))
	bunker.add_child(batch)
	port.free()
	starboard.free()


func _bunker_vent_visuals_are_exact(batch: MultiMeshInstance3D) -> bool:
	if batch == null or batch.multimesh == null \
			or batch.transform != Transform3D.IDENTITY \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or batch.layers != 1 or batch.ignore_occlusion_culling \
			or not is_zero_approx(batch.extra_cull_margin) \
			or not is_zero_approx(batch.visibility_range_begin) \
			or not is_zero_approx(batch.visibility_range_end) \
			or not is_zero_approx(batch.visibility_range_begin_margin) \
			or not is_zero_approx(batch.visibility_range_end_margin) \
			or batch.visibility_range_fade_mode \
				!= GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
		return false
	var multi := batch.multimesh
	var mesh := multi.mesh as CylinderMesh
	if multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.instance_count != BUNKER_VENT_INSTANCE_COUNT \
			or multi.visible_instance_count not in [-1, BUNKER_VENT_INSTANCE_COUNT] \
			or not multi.custom_aabb.is_equal_approx(BUNKER_VENT_BATCH_BOUNDS) \
			or mesh == null \
			or not is_equal_approx(mesh.top_radius, BUNKER_VENT_RADIUS_M) \
			or not is_equal_approx(mesh.bottom_radius, BUNKER_VENT_RADIUS_M) \
			or not is_equal_approx(mesh.height, BUNKER_VENT_HEIGHT_M) \
			or mesh.radial_segments != 12 \
			or batch.material_override == null:
		return false
	var expected: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, BUNKER_PORT_VENT_POSITION_M),
		Transform3D(Basis.IDENTITY, BUNKER_STARBOARD_VENT_POSITION_M),
	]
	var authored: Variant = batch.get_meta("authored_transforms", [])
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return batch.get_meta("source_visual_ids", PackedStringArray()) == PackedStringArray([
		"PortVentVisual", "StarboardVentVisual",
	])


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


func _configure_surface_route_spine() -> void:
	var landmarks := get_node_or_null(^"LandingRegion/SurfaceLandmarks") as Node3D
	var oxide_accent := get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/DeadSensorVisual"
	) as MeshInstance3D
	if landmarks == null or oxide_accent == null or oxide_accent.material_override == null:
		return
	var unit_bar := BoxMesh.new()
	unit_bar.size = Vector3.ONE
	unit_bar.material = oxide_accent.material_override
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = unit_bar
	multi.instance_count = ROUTE_SPINE_INSTANCE_COUNT
	var transforms := _surface_route_spine_transforms()
	multi.buffer = _encode_multi_mesh_transforms(transforms)
	# Freeze the exact transformed unit-box union. This follows the two rotated
	# destination chevrons as well as the forward spine, preventing Forward+
	# from culling a turn arm against a stale x-only batch bound.
	multi.custom_aabb = _surface_route_spine_batch_bounds(transforms)
	var spine := MultiMeshInstance3D.new()
	spine.name = &"RouteSpineVisuals"
	spine.multimesh = multi
	spine.material_override = oxide_accent.material_override
	spine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spine.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	spine.set_meta("authored_transforms", transforms.duplicate())
	spine.set_meta("route_id", SURFACE_ROUTE_ID)
	spine.set_meta("destination_marker_id", &"caldera_staging_gate")
	spine.set_meta("turn_destination_marker_ids", PackedStringArray([
		"ember_sample_rack_access", "ember_staging_relay_access",
	]))
	spine.set_meta("content_class", &"NEW")
	spine.set_meta("status", &"modern_interpretation")
	spine.set_meta("collision_role", &"flush_supported_decal_geometry")
	landmarks.add_child(spine)


func _surface_route_spine_is_exact(
		spine: MultiMeshInstance3D,
		oxide_accent: MeshInstance3D,
	) -> bool:
	if spine == null or oxide_accent == null or spine.multimesh == null \
			or spine.get_child_count() != 0 \
			or spine.transform != Transform3D.IDENTITY \
			or spine.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or spine.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or StringName(spine.get_meta("route_id", &"")) != SURFACE_ROUTE_ID \
			or StringName(spine.get_meta("destination_marker_id", &"")) != &"caldera_staging_gate" \
			or spine.get_meta("turn_destination_marker_ids", PackedStringArray()) \
				!= PackedStringArray(["ember_sample_rack_access", "ember_staging_relay_access"]) \
			or StringName(spine.get_meta("content_class", &"")) != &"NEW" \
			or StringName(spine.get_meta("status", &"")) != &"modern_interpretation" \
			or StringName(spine.get_meta("collision_role", &"")) != &"flush_supported_decal_geometry":
		return false
	var multi := spine.multimesh
	var unit_bar := multi.mesh as BoxMesh
	if multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.instance_count != ROUTE_SPINE_INSTANCE_COUNT \
			or multi.visible_instance_count not in [-1, ROUTE_SPINE_INSTANCE_COUNT] \
			or unit_bar == null or unit_bar.size != Vector3.ONE \
			or unit_bar.material != oxide_accent.material_override \
			or spine.material_override != oxide_accent.material_override:
		return false
	var expected := _surface_route_spine_transforms()
	if not multi.custom_aabb.is_equal_approx(
		_surface_route_spine_batch_bounds(expected)
	):
		return false
	var authored: Variant = spine.get_meta("authored_transforms", [])
	if not authored is Array or (authored as Array).size() != expected.size():
		return false
	for index in expected.size():
		if not (authored as Array)[index] is Transform3D \
				or not ((authored as Array)[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return _multi_mesh_live_transforms_are_exact(multi, expected)


static func _multi_mesh_live_transforms_are_exact(
		multi: MultiMesh,
		expected: Array[Transform3D],
	) -> bool:
	# The Dummy headless renderer exposes no live instances, so verify the exact
	# upload buffer there. With a real renderer, audit each live instance that the
	# player build consumes; set_instance_transform() drift must turn this red.
	if RenderingServer.get_video_adapter_name().is_empty():
		return multi.buffer == _encode_multi_mesh_transforms(expected)
	for index in expected.size():
		if not multi.get_instance_transform(index).is_equal_approx(expected[index]):
			return false
	return true


static func _encode_multi_mesh_transforms(
		transforms: Array[Transform3D],
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


static func _surface_route_spine_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for index in ROUTE_SPINE_CENTRES_X_M.size():
		var centre := Vector3(ROUTE_SPINE_CENTRES_X_M[index], ROUTE_SPINE_Y_M, 0.0)
		var direction := Vector3.RIGHT
		if index == ROUTE_SPINE_SAMPLE_TURN_INDEX:
			direction = ROUTE_SPINE_SAMPLE_DIRECTION
		elif index == ROUTE_SPINE_RELAY_TURN_INDEX:
			direction = ROUTE_SPINE_RELAY_DIRECTION
		var lateral := Vector3(-direction.z, 0.0, direction.x)
		var tip := centre + direction * ROUTE_SPINE_TIP_OFFSET_M
		transforms.append(_bar_between(
			centre - direction * ROUTE_SPINE_TAIL_OFFSET_M - lateral * ROUTE_SPINE_HALF_SPAN_M,
			tip,
			ROUTE_SPINE_ARM_WIDTH_M,
			ROUTE_SPINE_ARM_HEIGHT_M,
		))
		transforms.append(_bar_between(
			centre - direction * ROUTE_SPINE_TAIL_OFFSET_M + lateral * ROUTE_SPINE_HALF_SPAN_M,
			tip,
			ROUTE_SPINE_ARM_WIDTH_M,
			ROUTE_SPINE_ARM_HEIGHT_M,
		))
	return transforms


static func _surface_route_spine_batch_bounds(
		transforms: Array[Transform3D],
	) -> AABB:
	if transforms.is_empty():
		return AABB()
	var unit_box := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var bounds := (transforms[0] * unit_box).abs()
	for index in range(1, transforms.size()):
		bounds = bounds.merge((transforms[index] * unit_box).abs())
	return bounds


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
	if int(census.get("node_count", -1)) > TERRAIN_ACTIVE_NODE_CEILING:
		_append_error(errors, &"node_budget_exceeded", &"node_count", "active terrain node count exceeds the bounded ceiling")


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
		"render_submissions": meshes + multi_meshes,
		"static_bodies": static_bodies,
		"collision_shapes": collision_shapes,
		"triangle_count": triangles,
	}.duplicate(true)


func _performance_budget() -> Dictionary:
	var dynamic_collision_delta := (
		1
		if _terrain_clipmap != null and bool(
			_terrain_clipmap.get_snapshot().get("dynamic_collision_active", false)
		)
		else 0
	)
	return {
		"node_count": EXPECTED_NODE_COUNT + dynamic_collision_delta,
		"mesh_instances": EXPECTED_MESH_INSTANCE_COUNT,
		"multi_mesh_instances": EXPECTED_MULTI_MESH_INSTANCE_COUNT,
		"multi_mesh_copies": EXPECTED_MULTI_MESH_COPY_COUNT,
		"render_submissions": EXPECTED_RENDER_SUBMISSION_COUNT,
		"static_bodies": EXPECTED_STATIC_BODY_COUNT,
		"collision_shapes": (
			EXPECTED_COLLISION_SHAPE_COUNT + dynamic_collision_delta
		),
	}.duplicate(true)


func _surface_distance_m(a: Vector3, b: Vector3) -> float:
	var chord := clampf(a.distance_to(b), 0.0, 2.0)
	return 2.0 * asin(chord * 0.5) * BODY_RADIUS_M


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
			return Transform3D(Basis.IDENTITY, SAMPLE_RACK_ACCESS_POSITION_M)
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
		"notes": "Original Ember Moon bounded spherical terrain, static landing collision, traversable surface route, and modern landmarks including a derelict gantry and survey service bunker; no historical geometry claim.",
	}.duplicate(true)


func _owned_capabilities() -> Dictionary:
	return {
		"presentation_geometry": true,
		"static_world_collision": true,
		"generated_spherical_terrain": true,
		"generated_terrain_collision": true,
		"authored_surface_landmarks": true,
		"authored_surface_route": true,
	}.duplicate(true)


func _integration_authority() -> Dictionary:
	var result := {}
	for key in INTEGRATION_AUTHORITY_KEYS:
		result[key] = false
	result["terrain_generation"] = true
	result["collision_generation"] = true
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
