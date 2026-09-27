extends SceneTree
## Standalone contract for Rime's authored scene: its resources compose, its
## terrain and atmosphere stand up, its landmarks match the landing declaration,
## every exploration node is placed in the authored region frame (and a node
## that escapes it is caught), and its streamed cost stays Aurora-sized.

const WorldCompositionValidatorScript := preload("res://scripts/world/planetary_world_composition_validator.gd")
const LandingCompositionValidatorScript := preload("res://scripts/world/planetary_landing_composition_validator.gd")
const CoordinateFrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const SCENE := preload("res://scenes/world/planets/rime_glacial_world.tscn")
const WORLD := preload("res://assets/world/planets/rime_glacial_world.tres")
const ATMOSPHERE := preload("res://assets/world/planets/rime_glacial_atmosphere.tres")
const TERRAIN := preload("res://assets/world/planets/rime_glacial_terrain.tres")
const LANDING := preload("res://assets/world/planets/rime_icefall_landing.tres")
const AURORA_ATMOSPHERE := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")
const EXPECTED_ASSERTIONS := 13

var failures := PackedStringArray()
var assertions := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var scene := SCENE.instantiate() as RimeGlacialAuthoredScene
	root.add_child(scene)
	await process_frame
	await physics_frame
	check(WORLD.is_definition_valid() and ATMOSPHERE.is_definition_valid()
		and TERRAIN.is_profile_valid() and LANDING.is_definition_valid()
		and WORLD.scene_path == scene.scene_file_path,
		"Rime world, atmosphere, terrain, landing and scene path are exact")
	var world_report := WorldCompositionValidatorScript.new().validate_composition(WORLD, ATMOSPHERE, TERRAIN)
	check(world_report.valid and world_report.world_id == &"rime_glacial_world"
		and world_report.atmosphere_profile_id == &"rime_glacial_atmosphere"
		and world_report.terrain_profile_id == &"rime_glacial_terrain",
		"Rime's atmosphere resolves through the exact world composition contract")
	var frame := CoordinateFrameScript.new() as PlanetaryCoordinateFrame
	var origin := {"schema_version": CoordinateFrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": &"rime_icefall_system", "cell_x": 0, "cell_y": 0, "cell_z": 0,
		"offset_meters": Vector3.ZERO}
	var configured := frame.configure(LANDING.body_id, WORLD.body_radius_metres,
		&"rime_icefall_system", 1000000.0, origin, Vector3.UP, Vector3.FORWARD, 10000.0, origin)
	var landing_report := LandingCompositionValidatorScript.new().validate_composition(
		WORLD, TERRAIN, frame.get_snapshot(), LANDING)
	check(configured.accepted and landing_report.valid,
		"Rime's icefall landing resolves through its configured +Y coordinate frame")
	# Rime is not Aurora recoloured: its air is thinner, lower, hazier and colder.
	check(ATMOSPHERE.reference_density_kg_m3 < AURORA_ATMOSPHERE.reference_density_kg_m3
		and ATMOSPHERE.fog_end_distance_m < AURORA_ATMOSPHERE.fog_end_distance_m
		and ATMOSPHERE.cloud_base_altitude_m < AURORA_ATMOSPHERE.cloud_base_altitude_m
		and ATMOSPHERE.cloud_coverage_unitless > AURORA_ATMOSPHERE.cloud_coverage_unitless
		and ATMOSPHERE.wind_velocity_mps.length() > AURORA_ATMOSPHERE.wind_velocity_mps.length(),
		"Rime's atmosphere profile is a distinct cold, thin, hazy one")
	var terrain_snapshot := scene.get_terrain_clipmap_snapshot()
	check(terrain_snapshot.get("profile_id") == &"rime_glacial_terrain"
		and int(terrain_snapshot.get("ring_count", 0)) == 5
		and int(terrain_snapshot.get("collision_ring_count", 0)) == 1
		and bool((scene.audit().get("terrain_clipmap", {}) as Dictionary).get("valid", false)),
		"Rime instantiates its five-ring terrain with relief collision")
	var environments := scene.find_children("*", "WorldEnvironment", true, false)
	var audit := scene.audit()
	check(environments.size() == 1
		and environments[0] == scene.get_node("RimeAtmosphereComposition/WorldEnvironment")
		and not scene.is_processing() and bool(audit.valid),
		"the composition is the one WorldEnvironment owner and the full audit passes (%s)"
			% ", ".join(audit.get("errors", PackedStringArray())))
	var region := scene.get_node("LandingRegion") as Node3D
	var anchors_exact := true
	for index in RimeGlacialAuthoredScene.SURVEY_ANCHOR_NAMES.size():
		var anchor := scene.find_child(RimeGlacialAuthoredScene.SURVEY_ANCHOR_NAMES[index], true, false) as Node3D
		anchors_exact = anchors_exact and anchor != null \
			and region.to_local(anchor.global_position).distance_to(
				RimeGlacialAuthoredScene.SURVEY_ANCHOR_POSITIONS[index]) < 0.01 \
			and region.is_ancestor_of(anchor)
	check(anchors_exact, "all three survey anchors stand at their region-local landmark readings")
	var surface := audit.get("surface_content", {}) as Dictionary
	var landmarks := surface.get("landmark_positions_region_local_m", {}) as Dictionary
	check(landmarks.size() >= 5 and landmarks.get(&"rime_drill_rig") == Vector3(-54, 0, -46)
		and landmarks.get(&"rime_serac_field") == Vector3(-8, 0, -68)
		and landmarks.get(&"rime_strain_gauge") == Vector3(30, 0, -62)
		and scene.get_node_or_null(^"LandingRegion/GlacierExploration/IceCoreDrillRig") != null
		and scene.get_node_or_null(^"LandingRegion/GlacierExploration/SeracField") != null
		and scene.get_node_or_null(^"LandingRegion/GlacierExploration/PressureRidge") != null
		and scene.get_node_or_null(^"LandingRegion/GlacierExploration/RouteBeaconLamps") != null,
		"three navigable landmarks and the lit route are declared and standing")
	var grounded := true
	var space := scene.get_world_3d().direct_space_state
	for index in RimeGlacialAuthoredScene.SURVEY_ANCHOR_NAMES.size():
		var anchor := scene.find_child(RimeGlacialAuthoredScene.SURVEY_ANCHOR_NAMES[index], true, false) as Node3D
		var ray := PhysicsRayQueryParameters3D.create(
			anchor.global_position + Vector3.UP * 3.0, anchor.global_position - Vector3.UP * 5.0, 1)
		var hit := space.intersect_ray(ray)
		grounded = grounded and not hit.is_empty() \
			and absf((hit.position as Vector3).y - anchor.global_position.y) < 1.0
	check(grounded, "every survey anchor stands on real walkable collision")
	var shelter := scene.get_heat_shelter_global_position()
	var rig_anchor := scene.find_child("SurveyDrillRig", true, false) as Node3D
	check(shelter.is_finite() and shelter.distance_to(rig_anchor.global_position)
			< RimeGlacialAuthoredScene.HEAT_SHELTER_RADIUS_M,
		"the drill-rig checkpoint is inside the heated hut's warmth")
	var cost := scene.get_streamed_cost()
	check(int(cost.node_count) <= RimeGlacialAuthoredScene.NODE_BUDGET
		and int(cost.authored_light_count) <= RimeGlacialAuthoredScene.LIGHT_BUDGET
		and int(cost.authored_shadowed_light_count) == 0
		and int(cost.authored_triangle_count) + int(cost.terrain_render_triangle_count) <= 80_000,
		"the streamed generation stays Aurora-sized (%s)" % str(cost))

	# A whole-scene translation (what a common-world rebase applies to the root)
	# carries every placement with the region: none is top-level or in a plain
	# Node's frame.
	var before := scene.get_region_local_placements()
	scene.global_position += Vector3(9_000.0, -4_000.0, 7_500.0)
	await physics_frame
	var after := scene.get_region_local_placements()
	var carried := before.size() == after.size() and before.size() > 50
	for key: String in before:
		carried = carried and after.has(key) \
			and (before[key] as Vector3).distance_to(after[key] as Vector3) < 0.05
	check(carried and bool(scene.audit().valid),
		"a root translation carries all %d exploration placements with the region" % before.size())
	# The class of bug the Ember sweep found: a node under a plain Node sits in
	# neither authored frame. The audit must catch it.
	var plain := Node.new()
	plain.name = "PlainComposition"
	scene.get_node("LandingRegion/GlacierExploration").add_child(plain)
	var stray := Marker3D.new()
	stray.name = "StrayCue"
	stray.position = Vector3(0.0, 120_010.0, 0.0)
	plain.add_child(stray)
	var errors := scene.audit().get("errors", PackedStringArray()) as PackedStringArray
	var caught := false
	for error in errors:
		caught = caught or error.begins_with("region_placement_escaped")
	check(caught, "a cue parented under a plain Node is reported as escaping the region frame")
	plain.queue_free()

	print("RIME_GLACIAL_AUTHORED_SCENE_ASSERTIONS: %d" % assertions)
	if assertions != EXPECTED_ASSERTIONS:
		failures.append("assertion_count")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("RIME_GLACIAL_AUTHORED_SCENE_TEST_OK")
		quit(0)
		return
	print("RIME_GLACIAL_AUTHORED_SCENE_TEST_FAILED: %s" % ", ".join(failures))
	quit(1)


func check(value: bool, label: String) -> void:
	assertions += 1
	if value:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		push_error("FAIL: %s" % label)
