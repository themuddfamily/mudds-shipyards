extends SceneTree

const SCENE_PATH := "res://scenes/world/planets/ember_moon.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const EXPECTED_ASSERTIONS := 56
const INTEGRATION_AUTHORITY_KEYS := [
	"streaming", "game_flow", "gameplay", "landing_decision", "ship_movement",
	"player_movement", "world_generation", "terrain_generation",
	"collision_generation", "origin_shift", "save", "network", "reward",
	"audio", "camera", "lighting",
]

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := ResourceLoader.load(SCENE_PATH) as PackedScene
	_check(packed != null, "the reserved Ember Moon path loads as a PackedScene")
	var scene := packed.instantiate() as EmberMoonAuthoredScene if packed != null else null
	_check(scene != null, "the scene instantiates as the typed authored runtime component")
	if scene == null:
		_finish()
		return
	root.add_child(scene)
	await process_frame
	await physics_frame
	_test_identity_and_audit(scene)
	_test_geometry_and_markers(scene)
	_test_surface_material_hierarchy(scene)
	_test_collision(scene)
	await _test_embodied_surface_traversal(scene)
	_test_lod_seam(scene)
	await _test_detachment_and_structured_reds(packed, scene)
	scene.queue_free()
	await process_frame
	_finish()


func _test_identity_and_audit(scene: EmberMoonAuthoredScene) -> void:
	var audit := scene.audit()
	if not bool(audit.valid):
		print("EMBER_MOON_AUTHORED_SCENE_AUDIT_ERRORS: %s" % [audit.errors])
	_check(audit.valid and (audit.errors as Array).is_empty(), "the exact static authored scene audits green")
	_check(
		scene.get_world_id() == &"ember_moon"
			and scene.get_body_id() == &"ember_body"
			and scene.get_region_id() == &"ember_caldera",
		"runtime identity exactly matches the authored definition join",
	)
	var snapshot := scene.get_snapshot()
	_check(
		snapshot.coordinate_contract.scene_root_reference == &"body_center"
			and snapshot.coordinate_contract.body_radius_m == 120_000.0
			and snapshot.coordinate_contract.body_visual_radius_m == 119_999.0
			and snapshot.coordinate_contract.body_visual_inset_m == 1.0,
		"the physical datum remains 120 km while the noncolliding silhouette is explicitly inset",
	)
	_check(
		(audit.owned_capabilities as Dictionary) == {
			"presentation_geometry": true,
			"static_world_collision": true,
			"authored_surface_landmarks": true,
			"authored_surface_route": true,
		},
		"audit owns only bounded presentation, landmark, route, and static collision capabilities",
	)
	_check(_exact_all_false(audit.integration_authority, INTEGRATION_AUTHORITY_KEYS), "all runtime integration authority remains exactly false")
	_check(not scene.is_processing() and not scene.is_physics_processing(), "the authored scene has no automatic process loop")
	_check(
		audit.performance.node_count == 64
			and audit.performance.mesh_instances == 21
			and audit.performance.multi_mesh_instances == 3
			and audit.performance.multi_mesh_copies == 13
			and audit.performance.static_bodies == 7
			and audit.performance.collision_shapes == 19
			and audit.performance.triangle_count <= 8192,
		"live topology and primitive triangles stay inside the exact bounded budget",
	)
	_check(_forbidden_node_count(scene) == 0, "the scene owns no camera, light, audio, navigation, actor, area, particle, or animation node")


func _test_geometry_and_markers(scene: EmberMoonAuthoredScene) -> void:
	var landing_root := scene.get_node(^"LandingRegion") as Node3D
	var body := scene.get_node(^"BodyVisual") as MeshInstance3D
	var floor := scene.get_node(^"LandingRegion/CalderaFloor") as MeshInstance3D
	var rim := scene.get_node(^"LandingRegion/CalderaRim") as MeshInstance3D
	_check(landing_root.transform == Transform3D(Basis.IDENTITY, Vector3(0.0, 120_000.0, 0.0)), "landing geometry remains under the exact +Y body-local frame")
	_check(
		(body.mesh as SphereMesh).radius == 119_999.0
			and (floor.mesh as CylinderMesh).top_radius == 256.0
			and (rim.mesh as TorusMesh).inner_radius == 240.0
			and (rim.mesh as TorusMesh).outer_radius == 280.0,
		"body silhouette and bounded caldera proxy retain exact authored radii",
	)
	var markers := scene.get_body_local_marker_transforms()
	_check(markers.size() == 4, "exactly four detached landing marker transforms are published")
	_check((markers.caldera_pad as Transform3D).origin == Vector3(0.0, 120_000.0, 0.0), "pad marker composes to the sea-level body-local point")
	_check((markers.caldera_approach as Transform3D).origin == Vector3(0.0, 120_060.0, 300.0), "approach marker composes through the landing-region frame")
	_check((markers.caldera_pad_egress as Transform3D).origin == Vector3(18.0, 120_000.0, 0.0), "egress marker composes through the landing-region frame")
	_check((markers.caldera_staging_gate as Transform3D).origin == Vector3(42.0, 120_000.0, 0.0), "staging marker composes through the landing-region frame")
	markers[&"caldera_pad"] = Transform3D.IDENTITY
	_check((scene.get_body_local_marker_transforms().caldera_pad as Transform3D).origin == Vector3(0.0, 120_000.0, 0.0), "returned marker dictionaries are detached")
	var snapshot := scene.get_snapshot()
	var landmark_ids := PackedStringArray()
	for landmark_id: Variant in snapshot.surface_content.landmark_ids:
		landmark_ids.append(str(landmark_id))
	landmark_ids.sort()
	_check(
		snapshot.surface_content.content_class == &"NEW"
			and snapshot.surface_content.status == &"modern_interpretation"
			and snapshot.surface_content.route_id == &"ember_caldera_pad_to_staging"
			and is_equal_approx(float(snapshot.surface_content.route_width_m), 4.0)
			and snapshot.surface_content.route_points_region_local_m == [
				Vector3(0.0, 0.0, 0.0),
				Vector3(18.0, 0.0, 0.0),
				Vector3(42.0, 0.0, 0.0),
			],
		"surface snapshot publishes the exact bounded pad-to-egress-to-staging route",
	)
	_check(
		landmark_ids == PackedStringArray([
			"ember_derelict_survey_gantry",
			"ember_pad_guidance_port",
			"ember_pad_guidance_starboard",
			"ember_sample_rack",
			"ember_staging_relay",
			"ember_survey_service_bunker",
		]),
		"surface snapshot publishes the exact stable modern landmark roster",
	)
	var surface_markers := scene.get_surface_landmark_marker_transforms()
	_check(
		surface_markers.size() == 5
			and (surface_markers.ember_pad_guidance_threshold as Transform3D).origin == Vector3(14.0, 120_000.0, 0.0)
			and (surface_markers.ember_sample_rack_access as Transform3D).origin == Vector3(28.0, 120_000.0, -4.8)
			and (surface_markers.ember_staging_relay_access as Transform3D).origin == Vector3(42.0, 120_000.0, 4.4)
			and (surface_markers.ember_derelict_survey_gantry_access as Transform3D).origin == Vector3(34.0, 120_000.0, -7.0)
			and (surface_markers.ember_survey_service_bunker_access as Transform3D).origin == Vector3(-17.5, 120_000.0, -17.5),
		"five stable access markers compose through the body-local landing frame",
	)
	surface_markers.clear()
	_check(
		scene.get_surface_landmark_marker_transforms().size() == 5,
		"returned surface-landmark marker dictionaries are detached",
	)
	var route_visual := scene.get_node(^"LandingRegion/SurfaceLandmarks/EgressRouteVisual") as MeshInstance3D
	var route_mesh := route_visual.mesh as BoxMesh if route_visual != null else null
	_check(
		route_visual != null and route_mesh != null
			and route_visual.position == Vector3(28.0, 0.01, 0.0)
			and route_mesh.size == Vector3(28.0, 0.02, 4.0),
		"the surface stripe touches the pad edge at x=14 and reaches staging at x=42 without a visual gap",
	)
	var gantry := scene.get_node(^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry") as StaticBody3D
	var port_pylon := gantry.get_node_or_null(^"PortPylonVisual") as MeshInstance3D if gantry != null else null
	var dead_sensor := gantry.get_node_or_null(^"DeadSensorVisual") as MeshInstance3D if gantry != null else null
	_check(
		gantry != null and gantry.position == Vector3(34.0, 0.0, 0.0)
			and port_pylon != null and (port_pylon.mesh as BoxMesh).size == Vector3(1.2, 7.2, 1.4)
			and dead_sensor != null and is_equal_approx(dead_sensor.position.y, 10.95)
			and is_equal_approx(float(snapshot.geometry.derelict_gantry_height_m), 11.175)
			and is_equal_approx(float(snapshot.geometry.derelict_gantry_span_m), 11.8),
		"the broken survey gantry carries an eleven-metre flight and on-foot silhouette over the return leg",
	)
	_check(
		gantry != null
			and StringName(gantry.get_meta("landmark_id", &"")) == &"ember_derelict_survey_gantry"
			and StringName(gantry.get_meta("content_class", &"")) == &"NEW"
			and StringName(gantry.get_meta("status", &"")) == &"modern_interpretation"
			and not bool(gantry.get_meta("historical_geometry_authenticated", true))
			and not str(gantry.get_meta("evidence_note", "")).is_empty(),
		"the derelict is explicitly a modern interpretation with no historical-geometry claim",
	)
	var bunker := scene.get_node(^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker") as StaticBody3D
	var bunker_shell := bunker.get_node_or_null(^"ShellVisual") as MeshInstance3D if bunker != null else null
	var bunker_door := bunker.get_node_or_null(^"DoorVisual") as MeshInstance3D if bunker != null else null
	_check(
		bunker != null and bunker.position == Vector3(-24.0, 0.0, -24.0)
			and bunker_shell != null and (bunker_shell.mesh as BoxMesh).size == Vector3(7.4, 2.8, 5.6)
			and bunker_door != null and (bunker_door.mesh as BoxMesh).size == Vector3(0.3, 2.1, 2.2)
			and snapshot.geometry.survey_bunker_footprint_m == Vector2(9.0, 7.0)
			and is_equal_approx(float(snapshot.geometry.survey_bunker_height_m), 4.75)
			and float(snapshot.geometry.survey_bunker_minimum_pad_clearance_m) >= 2.3,
		"the low survey bunker is a distinct on-foot landmark outside the landing-pad footprint",
	)
	_check(
		bunker != null
			and StringName(bunker.get_meta("landmark_id", &"")) == &"ember_survey_service_bunker"
			and StringName(bunker.get_meta("content_class", &"")) == &"NEW"
			and StringName(bunker.get_meta("status", &"")) == &"modern_interpretation"
			and not bool(bunker.get_meta("historical_geometry_authenticated", true))
			and not str(bunker.get_meta("evidence_note", "")).is_empty(),
		"the service bunker is explicitly modern authored content with no historical-geometry claim",
	)
	var cues := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/LandingApproachCues"
	) as MultiMeshInstance3D
	var guide_batch := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/PadGuideVisuals"
	) as MultiMeshInstance3D
	var guide_multi := guide_batch.multimesh if guide_batch != null else null
	var guide_mesh := guide_multi.mesh as BoxMesh if guide_multi != null else null
	var guide_material := guide_batch.material_override as StandardMaterial3D \
		if guide_batch != null else null
	var guide_transforms: Array = guide_batch.get_meta("authored_transforms", []) as Array \
		if guide_batch != null else []
	var cue_batch := cues.multimesh if cues != null else null
	var cue_mesh := cue_batch.mesh as BoxMesh if cue_batch != null else null
	var authored_transforms: Array = cues.get_meta("authored_transforms", []) as Array \
		if cues != null else []
	var cue_family_exact := cues != null and cues.get_child_count() == 0 \
		and cue_batch != null and cue_batch.instance_count == 8 \
		and cue_mesh != null and cue_mesh.size == Vector3(0.72, 0.03, 4.0) \
		and guide_mesh != null and cue_mesh.material == guide_mesh.material \
		and authored_transforms.size() == 8 \
		and StringName(cues.get_meta("content_class", &"")) == &"NEW" \
		and StringName(cues.get_meta("status", &"")) == &"modern_interpretation"
	for index in 4:
		var left := authored_transforms[index * 2] as Transform3D
		var right := authored_transforms[index * 2 + 1] as Transform3D
		cue_family_exact = cue_family_exact \
			and is_equal_approx(left.origin.x, -1.4) \
			and is_equal_approx(right.origin.x, 1.4) \
			and is_equal_approx(left.origin.z, 21.4 + float(index) * 7.0) \
			and left.origin == Vector3(-right.origin.x, right.origin.y, right.origin.z)
	_check(
		cue_family_exact,
		"four paired geometric chevrons share the guide material in one collision-free batch outside the touchdown pad",
	)
	_check(
		guide_batch != null and guide_batch.get_child_count() == 0 \
			and guide_multi != null and guide_multi.instance_count == 2 \
			and guide_mesh != null and guide_mesh.size == Vector3(0.5, 1.8, 0.5) \
			and guide_mesh.material == guide_batch.material_override \
			and guide_material != null \
			and guide_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			and guide_material.albedo_color.is_equal_approx(Color("71d9da")) \
			and guide_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and guide_batch.gi_mode == GeometryInstance3D.GI_MODE_DISABLED \
			and guide_batch.layers == 1 \
			and not guide_batch.ignore_occlusion_culling \
			and is_zero_approx(guide_batch.extra_cull_margin) \
			and is_zero_approx(guide_batch.visibility_range_begin) \
			and is_zero_approx(guide_batch.visibility_range_end) \
			and is_zero_approx(guide_batch.visibility_range_begin_margin) \
			and is_zero_approx(guide_batch.visibility_range_end_margin) \
			and guide_batch.visibility_range_fade_mode \
				== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED \
			and guide_multi.custom_aabb.is_equal_approx(AABB(
				Vector3(14.55, 0.0, -5.25), Vector3(0.5, 1.8, 10.5)
			)) \
			and guide_transforms == [
				Transform3D(Basis.IDENTITY, Vector3(14.8, 0.9, -5.0)),
				Transform3D(Basis.IDENTITY, Vector3(14.8, 0.9, 5.0)),
			] \
			and scene.get_node(^"LandingRegion/SurfaceLandmarks/PadGuidancePort") is StaticBody3D \
			and scene.get_node(^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard") is StaticBody3D,
		"paired pad-guide renderers share one bounded batch while both semantic solid landmarks remain",
	)
	var orbital_cue := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/OrbitalLandingDatumCue"
	) as MultiMeshInstance3D
	var orbital_batch := orbital_cue.multimesh if orbital_cue != null else null
	var orbital_mesh := orbital_batch.mesh as BoxMesh if orbital_batch != null else null
	var orbital_transforms: Array = orbital_cue.get_meta("authored_transforms", []) as Array \
		if orbital_cue != null else []
	var orbital_exact := orbital_cue != null and orbital_cue.get_child_count() == 0 \
		and orbital_batch != null and orbital_batch.instance_count == 3 \
		and orbital_mesh != null and orbital_mesh.size == Vector3.ONE \
		and orbital_mesh.material == route_visual.material_override \
		and orbital_transforms.size() == 3 \
		and StringName(orbital_cue.get_meta("approach_marker_id", &"")) == &"caldera_approach" \
		and StringName(orbital_cue.get_meta("landing_marker_id", &"")) == &"caldera_pad"
	if orbital_transforms.size() == 3:
		var port_arm := orbital_transforms[0] as Transform3D
		var starboard_arm := orbital_transforms[1] as Transform3D
		var threshold := orbital_transforms[2] as Transform3D
		orbital_exact = orbital_exact \
			and port_arm.origin == Vector3(-55.0, 3.0, 135.0) \
			and starboard_arm.origin == Vector3(55.0, 3.0, 135.0) \
			and threshold.origin == Vector3(0.0, 3.0, 62.0) \
			and port_arm.basis.z.normalized().z > 0.8 \
			and starboard_arm.basis.z.normalized().z > 0.8 \
			and port_arm.basis.z.normalized().x < 0.0 \
			and starboard_arm.basis.z.normalized().x > 0.0
	_check(
		orbital_exact \
			and snapshot.geometry.orbital_landing_navigation_direction == Vector3(0.0, 0.0, -1.0) \
			and float(snapshot.geometry.orbital_landing_cue_maximum_radius_m) < 280.0,
		"one non-emissive open-arrow batch ties low-orbit caldera readability to the exact approach-to-pad datum inside the rim",
	)


func _test_surface_material_hierarchy(scene: EmberMoonAuthoredScene) -> void:
	var snapshot := scene.get_snapshot().surface_material_hierarchy as Dictionary
	var floor := scene.get_node(^"LandingRegion/CalderaFloor") as MeshInstance3D
	var pad := scene.get_node(^"LandingRegion/PadVisual") as MeshInstance3D
	var route := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/EgressRouteVisual"
	) as MeshInstance3D
	var gantry := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry/PortPylonVisual"
	) as MeshInstance3D
	var bunker_door := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker/DoorVisual"
	) as MeshInstance3D
	var floor_material := floor.material_override as StandardMaterial3D
	var pad_material := pad.material_override as StandardMaterial3D
	var route_material := route.material_override as StandardMaterial3D
	var gantry_material := gantry.material_override as StandardMaterial3D
	var service_material := bunker_door.material_override as StandardMaterial3D
	var panel_path := "res://assets/materials/procedural-panel-triplanar-albedo-v2.png"
	_check(
		snapshot.basalt == {"triplanar": false, "metallic": 0.0, "roughness": 1.0}
			and snapshot.grip.finish == &"walked_deck"
			and snapshot.metal.finish == &"structural_alloy"
			and snapshot.service.finish == &"painted_metal"
			and floor_material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
			and floor_material.albedo_texture == null
			and is_zero_approx(floor_material.metallic)
			and is_equal_approx(floor_material.roughness, 1.0)
			and pad_material.albedo_texture.resource_path == panel_path
			and pad_material.uv1_world_triplanar
			and pad_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.55)
			and route_material.uv1_scale == pad_material.uv1_scale
			and is_equal_approx(route_material.clearcoat_roughness, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS)
			and gantry_material.albedo_texture.resource_path == panel_path
			and gantry_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
			and is_equal_approx(gantry_material.metallic, 0.68)
			and service_material.albedo_texture.resource_path == panel_path
			and service_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.36)
			and is_equal_approx(service_material.clearcoat, StationSurfaceKit.PAINTED_CLEARCOAT),
		"the pad-to-egress-to-bunker route has distinct basalt, walked grip, structural metal, and painted service responses",
	)


func _test_collision(scene: EmberMoonAuthoredScene) -> void:
	var body := scene.get_node(^"LandingRegion/WalkablePatch") as StaticBody3D
	var collision := scene.get_node(^"LandingRegion/WalkablePatch/CollisionShape3D") as CollisionShape3D
	_check(
		body.position == Vector3(0.0, -0.25, 0.0)
			and body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER
			and body.collision_mask == PhysicsLayers.WORLD_BODY_MASK
			and (collision.shape as BoxShape3D).size == Vector3(96.0, 0.5, 96.0),
		"one exact World-layer box places its top at the landing tangent plane",
	)
	var space := scene.get_world_3d().direct_space_state
	var hit_pad := _ray_hit(space, Vector3(0.0, 120_002.0, 0.0))
	var hit_egress := _ray_hit(space, Vector3(18.0, 120_002.0, 0.0))
	var hit_staging := _ray_hit(space, Vector3(42.0, 120_002.0, 0.0))
	var outside := _ray_hit(space, Vector3(49.0, 120_002.0, 0.0))
	_check(not hit_pad.is_empty() and hit_pad.collider == body, "the pad point is collision-supported")
	_check(not hit_egress.is_empty() and hit_egress.collider == body, "the egress point is collision-supported")
	_check(not hit_staging.is_empty() and hit_staging.collider == body, "the staging point is collision-supported")
	_check(outside.is_empty(), "collision fails closed immediately beyond the authored +/-48m patch")
	var landmark_paths := [
		^"LandingRegion/SurfaceLandmarks/PadGuidancePort",
		^"LandingRegion/SurfaceLandmarks/PadGuidanceStarboard",
		^"LandingRegion/SurfaceLandmarks/SampleRack",
		^"LandingRegion/SurfaceLandmarks/StagingRelay",
		^"LandingRegion/SurfaceLandmarks/DerelictSurveyGantry",
		^"LandingRegion/SurfaceLandmarks/SurveyServiceBunker",
	]
	var solid_centres := [
		Vector3(14.8, 120_003.0, -5.0),
		Vector3(14.8, 120_003.0, 5.0),
		Vector3(28.0, 120_003.0, -7.0),
		Vector3(42.0, 120_005.0, 7.0),
		Vector3(34.0, 120_009.0, -5.2),
		Vector3(-24.0, 120_006.0, -24.0),
	]
	var all_solids_collide := true
	for index in landmark_paths.size():
		var expected_body := scene.get_node(landmark_paths[index]) as StaticBody3D
		var hit := _ray_hit(space, solid_centres[index])
		all_solids_collide = all_solids_collide \
			and expected_body != null and not hit.is_empty() \
			and hit.collider == expected_body
	_check(all_solids_collide, "every visually solid guide, rack, relay, gantry, and bunker owns matching World collision")
	var corridor_clear := true
	for x in [14.8, 28.0, 34.0, 42.0]:
		var route_hit := _ray_hit(space, Vector3(x, 120_002.0, 0.0))
		corridor_clear = corridor_clear \
			and not route_hit.is_empty() and route_hit.collider == body
	_check(corridor_clear, "negative-space probes hit only the walkable patch through every landmark station")
	var collision_snapshot := scene.get_snapshot().collision as Dictionary
	_check(
		int(collision_snapshot.landmark_static_body_count) == 6
			and int(collision_snapshot.solid_landmark_collision_shape_count) == 18
			and is_equal_approx(float(collision_snapshot.route_clear_half_width_m), 2.0),
		"surface collision snapshot freezes six landmark bodies and eighteen solid shapes",
	)


func _test_embodied_surface_traversal(scene: EmberMoonAuthoredScene) -> void:
	# Exercise the body-local authoring through the explicit local-origin seam.
	# CharacterBody contact at an unre-based 120 km coordinate is intentionally
	# outside this static component's authority and is covered by the separate
	# planetary coordinate-frame contracts.
	scene.position = Vector3(0.0, -120_000.0, 0.0)
	await physics_frame
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	player.set_camera_active(false)
	Input.action_release(&"jump")
	Input.action_release(&"sprint_boost")
	Input.action_release(&"move_forward")
	var route_basis := Basis.looking_at(Vector3.RIGHT, Vector3.UP)
	player.teleport_to(Transform3D(
		route_basis,
		Vector3(0.0, 0.05, 0.0),
	))
	for _settle in 12:
		await physics_frame
	var start := player.global_position
	var reached_egress := false
	var reached_staging := false
	var maximum_lateral_offset := 0.0
	var maximum_surface_offset := 0.0
	var jump_was_pressed := false
	Input.action_press(&"move_forward")
	for _frame in 540:
		await physics_frame
		var local := player.global_position
		maximum_lateral_offset = maxf(maximum_lateral_offset, absf(local.z))
		maximum_surface_offset = maxf(maximum_surface_offset, absf(local.y))
		jump_was_pressed = jump_was_pressed or Input.is_action_pressed(&"jump")
		reached_egress = reached_egress or local.x >= 18.0
		if local.x >= 41.5:
			reached_staging = true
			break
	Input.action_release(&"move_forward")
	await physics_frame
	var final_local := player.global_position
	_check(
		start.x >= -0.1 and start.x <= 0.1 and absf(start.z) <= 0.1 \
			and player.is_on_floor(),
		"the production Player settles physically at the authored pad start",
	)
	_check(reached_egress, "continuous production locomotion crosses the exact pad-egress marker")
	_check(
		reached_staging and final_local.x >= 41.5 and final_local.x < 48.0,
		"the same no-teleport walk reaches staging before the bounded patch edge",
	)
	_check(
		not jump_was_pressed and maximum_surface_offset <= 0.1,
		"pad-to-staging traversal uses no jump and remains on the tangent collision surface",
	)
	_check(
		maximum_lateral_offset <= 0.2,
		"landmark collision preserves the straight four-metre negative-space corridor",
	)
	player.queue_free()
	await process_frame
	scene.position = Vector3.ZERO
	await physics_frame


func _test_lod_seam(scene: EmberMoonAuthoredScene) -> void:
	var ring_zero := scene.evaluate_terrain_lod_hint(256.0, false)
	var ring_one := scene.evaluate_terrain_lod_hint(256.001, false)
	_check(ring_zero.accepted and ring_zero.render_ring_index == 0 and ring_one.render_ring_index == 1, "LOD hint keeps the first inclusive near-to-far boundary")
	var collision_edge := scene.evaluate_terrain_lod_hint(1500.0, true)
	var collision_outside := scene.evaluate_terrain_lod_hint(1500.001, true)
	_check(collision_edge.collision_participates and not collision_outside.collision_participates, "terrain collision hint preserves the exact inclusive 1500m boundary")
	var far_edge := scene.evaluate_terrain_lod_hint(18_432.0, false)
	var beyond := scene.evaluate_terrain_lod_hint(18_432.001, false)
	_check(far_edge.render_ring_index == 4 and beyond.accepted and not beyond.render_participates, "outermost ring is inclusive and farther distances do not participate")


func _test_detachment_and_structured_reds(packed: PackedScene, scene: EmberMoonAuthoredScene) -> void:
	var audit := scene.audit()
	(audit.snapshot.marker_transforms_body_local as Dictionary).clear()
	(audit.integration_authority as Dictionary)["streaming"] = true
	_check(
		scene.audit().valid
			and scene.get_body_local_marker_transforms().size() == 4
			and not bool(scene.audit().integration_authority.streaming),
		"nested audit mutation cannot alter later reports or live authored state",
	)
	var drifted := packed.instantiate() as EmberMoonAuthoredScene
	root.add_child(drifted)
	await process_frame
	(drifted.get_node(^"LandingRegion/Markers/PadEgress") as Marker3D).position.x = 19.0
	var drift_report := drifted.audit()
	_check(
		not drift_report.valid
			and (drift_report.error_codes as PackedStringArray).has("marker_transform_mismatch"),
		"marker drift produces a structured red code",
	)
	(drifted.get_node(^"LandingRegion/WalkablePatch") as StaticBody3D).collision_layer = 0
	var collision_report := drifted.audit()
	_check((collision_report.error_codes as PackedStringArray).has("walkable_body_drift"), "collision authority drift produces a structured red code")
	(drifted.get_node(^"LandingRegion/SurfaceLandmarks/SampleRack") as StaticBody3D).set_meta(
		"landmark_id", &"wrong_sample_rack",
	)
	var roster_report := drifted.audit()
	_check(
		(roster_report.error_codes as PackedStringArray).has("surface_landmark_identity_drift"),
		"surface landmark identity drift produces a structured red code",
	)
	(drifted.get_node(^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadCollision") as CollisionShape3D).disabled = true
	var solid_report := drifted.audit()
	_check(
		(solid_report.error_codes as PackedStringArray).has("landmark_collision_shape_drift"),
		"a missing visual-solid collision recipe produces a structured red code",
	)
	(drifted.get_node(^"LandingRegion/SurfaceLandmarks/EgressRouteVisual") as MeshInstance3D).set_meta(
		"route_id", &"wrong_route",
	)
	var route_report := drifted.audit()
	_check(
		(route_report.error_codes as PackedStringArray).has("surface_route_identity_drift"),
		"surface route identity drift produces a structured red code",
	)
	var drifted_cues := drifted.get_node(
		^"LandingRegion/SurfaceLandmarks/LandingApproachCues"
	) as MultiMeshInstance3D
	var drifted_transforms := drifted_cues.get_meta("authored_transforms", []) as Array
	drifted_transforms[0] = Transform3D.IDENTITY
	drifted_cues.set_meta("authored_transforms", drifted_transforms)
	_check(
		(drifted.audit().error_codes as PackedStringArray).has("landing_approach_cue_drift"),
		"approach-chevron transform drift produces a structured red code",
	)
	var drifted_orbital := drifted.get_node(
		^"LandingRegion/SurfaceLandmarks/OrbitalLandingDatumCue"
	) as MultiMeshInstance3D
	var drifted_orbital_transforms := drifted_orbital.get_meta("authored_transforms", []) as Array
	drifted_orbital_transforms[0] = Transform3D.IDENTITY
	drifted_orbital.set_meta("authored_transforms", drifted_orbital_transforms)
	_check(
		(drifted.audit().error_codes as PackedStringArray).has("orbital_landing_datum_cue_drift"),
		"orbital landing-datum transform drift produces a structured red code",
	)
	drifted.queue_free()
	await process_frame


func _ray_hit(space: PhysicsDirectSpaceState3D, origin: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + Vector3(0.0, -4.0, 0.0),
		PhysicsLayers.WORLD,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


func _forbidden_node_count(scene: Node) -> int:
	var count := 0
	for node in scene.find_children("*", "Node", true, false):
		if node is Camera3D or node is WorldEnvironment or node is Light3D \
				or node is Area3D or node is NavigationRegion3D \
				or node is AudioStreamPlayer or node is AudioStreamPlayer3D \
				or node is GPUParticles3D or node is CPUParticles3D \
				or node is AnimationPlayer or node is CharacterBody3D \
				or node is RigidBody3D:
			count += 1
	return count


func _exact_all_false(candidate: Dictionary, keys: Array) -> bool:
	if candidate.size() != keys.size():
		return false
	for key in keys:
		if not candidate.has(key) or not candidate[key] is bool or bool(candidate[key]):
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
	print("EMBER_MOON_AUTHORED_SCENE_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("EMBER_MOON_AUTHORED_SCENE_TEST_OK")
		quit(0)
		return
	print("EMBER_MOON_AUTHORED_SCENE_TEST_FAILURES: %s" % _failures)
	quit(1)
