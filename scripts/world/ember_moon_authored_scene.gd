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

const BODY_COLOR := Color("552817")
const FLOOR_COLOR := Color("292421")
const RIM_COLOR := Color("713a25")
const PAD_COLOR := Color("a85f32")

const EXPECTED_NODE_COUNT := 13
const EXPECTED_MESH_INSTANCE_COUNT := 4
const EXPECTED_STATIC_BODY_COUNT := 1
const EXPECTED_COLLISION_SHAPE_COUNT := 1
const MAXIMUM_TRIANGLE_COUNT := 8192
const WORLD_LAYER := PhysicsLayers.WORLD_BODY_LAYER
const WORLD_MASK := PhysicsLayers.WORLD_BODY_MASK

const MARKER_NODE_PATHS := {
	&"caldera_pad": ^"LandingRegion/Markers/CalderaPad",
	&"caldera_approach": ^"LandingRegion/Markers/ApproachEntry",
	&"caldera_pad_egress": ^"LandingRegion/Markers/PadEgress",
	&"caldera_staging_gate": ^"LandingRegion/Markers/StagingGate",
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
		"geometry": {
			"caldera_floor_radius_m": CALDERA_FLOOR_RADIUS_M,
			"caldera_rim_inner_radius_m": CALDERA_RIM_INNER_RADIUS_M,
			"caldera_rim_outer_radius_m": CALDERA_RIM_OUTER_RADIUS_M,
			"pad_visual_size_m": PAD_VISUAL_SIZE_M,
		},
		"collision": {
			"shape": &"box",
			"size_m": WALKABLE_PATCH_SIZE_M,
			"position_region_local_m": WALKABLE_PATCH_POSITION_REGION_LOCAL_M,
			"top_surface_region_local_y_m": 0.0,
			"layer": WORLD_LAYER,
			"mask": WORLD_MASK,
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
	}
	for path: NodePath in expected:
		var node := get_node_or_null(path)
		if node == null or not node.is_class(expected[path]):
			_append_error(errors, &"missing_or_wrong_node", StringName(str(path)), "required authored node is missing or has the wrong type")
	if _count_nodes() != EXPECTED_NODE_COUNT:
		_append_error(errors, &"node_roster_drift", &"scene", "authored scene must contain exactly thirteen nodes")
	var landing_root := get_node_or_null(^"LandingRegion")
	var walkable := get_node_or_null(^"LandingRegion/WalkablePatch")
	var markers := get_node_or_null(^"LandingRegion/Markers")
	if get_child_count() != 2 \
			or landing_root == null or landing_root.get_child_count() != 5 \
			or walkable == null or walkable.get_child_count() != 1 \
			or markers == null or markers.get_child_count() != 4:
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
	var body_mesh := body.mesh as SphereMesh if body != null else null
	var floor_mesh := floor.mesh as CylinderMesh if floor != null else null
	var rim_mesh := rim.mesh as TorusMesh if rim != null else null
	var pad_mesh := pad.mesh as BoxMesh if pad != null else null
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
	var material_specs := {
		body: BODY_COLOR,
		floor: FLOOR_COLOR,
		rim: RIM_COLOR,
		pad: PAD_COLOR,
	}
	for instance: MeshInstance3D in material_specs:
		var material := instance.material_override as StandardMaterial3D if instance != null else null
		if material == null \
				or material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
				or not material.albedo_color.is_equal_approx(material_specs[instance]) \
				or instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				or instance.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
			_append_error(errors, &"visual_material_drift", &"materials", "original unshaded material or passive renderer contract drifted")
			break


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


func _validate_performance(errors: Array[Dictionary], census: Dictionary) -> void:
	var budget := _performance_budget()
	for key: String in budget:
		if int(census.get(key, -1)) != int(budget[key]):
			_append_error(errors, &"performance_roster_drift", StringName(key), "exact authored performance roster drifted")
	if int(census.get("triangle_count", -1)) > MAXIMUM_TRIANGLE_COUNT:
		_append_error(errors, &"triangle_budget_exceeded", &"triangle_count", "primitive triangle count exceeds the bounded ceiling")


func _performance_census() -> Dictionary:
	var meshes := 0
	var static_bodies := 0
	var collision_shapes := 0
	var triangles := 0
	for node in _all_nodes():
		if node is MeshInstance3D:
			meshes += 1
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				triangles += mesh.get_faces().size() / 3
		elif node is StaticBody3D:
			static_bodies += 1
		elif node is CollisionShape3D:
			collision_shapes += 1
	return {
		"node_count": _count_nodes(),
		"mesh_instances": meshes,
		"static_bodies": static_bodies,
		"collision_shapes": collision_shapes,
		"triangle_count": triangles,
	}.duplicate(true)


func _performance_budget() -> Dictionary:
	return {
		"node_count": EXPECTED_NODE_COUNT,
		"mesh_instances": EXPECTED_MESH_INSTANCE_COUNT,
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
		"notes": "Original Ember Moon visual proxy and bounded static pad collision; no historical or production-placement claim.",
	}.duplicate(true)


func _owned_capabilities() -> Dictionary:
	return {
		"presentation_geometry": true,
		"static_world_collision": true,
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
