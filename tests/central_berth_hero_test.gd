extends SceneTree

## Focused construction and integration audit for the provisional central
## Torrent berth. Presentation detail must never become landing/path collision.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DECK_ALBEDO_PATH := "res://assets/materials/shipyard-deck-albedo-v1.png"
const DECK_NORMAL_PATH := "res://assets/materials/shipyard-deck-normal-v1.png"
const DECK_ROUGHNESS_PATH := "res://assets/materials/shipyard-deck-roughness-v1.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	_check(world != null and torrent != null, "production world and Torrent are live")
	if world == null or torrent == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_test_audit_and_evidence(world)
	_test_berth_contracts(world, torrent)
	_test_structure_and_material_scope(world)
	_test_clamp_alignment_and_service_clearance(world, torrent)
	_test_lighting_and_probe(world)
	_test_floor_routes_and_launch_volume(world, torrent)

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_audit_and_evidence(world: ShipyardWorld) -> void:
	_check(world.has_method("get_central_berth_audit_report"), "world exposes the central hero-cell audit")
	var audit := world.get_central_berth_audit_report()
	_check(bool(audit.get("valid", false)), "central hero-cell audit is valid: %s" % [audit.get("errors", [])])
	_check(str(audit.get("module_id", "")) == "central-berth-hero-cell", "audit has a stable module ID")
	_check(str(audit.get("berth_id", "")) == "central_berth", "audit retains the authoritative berth ID")
	_check(str(audit.get("ship_id", "")) == "torrent_provisional", "audit retains the provisional Torrent identity")

	var evidence := audit.get("evidence", {}) as Dictionary
	_check(
		str(evidence.get("evidence_status", "")) == "creator_roster_supported_modern_interpretation"
		and bool(evidence.get("source_bounded", false)),
		"evidence boundary records supported identity and bounded interpretation"
	)
	_check(
		not bool(evidence.get("authenticated_original_geometry", true))
		and not bool(evidence.get("authenticated_berth_layout", true)),
		"audit never authenticates modern geometry or berth layout"
	)
	_check(
		(evidence.get("creator_supported", PackedStringArray()) as PackedStringArray).size() == 2
		and (evidence.get("modern_provisional", PackedStringArray()) as PackedStringArray).size() >= 7,
		"audit narrowly separates creator-supported facts from provisional design"
	)

	var expected_counts := audit.get("expected_feature_counts", {}) as Dictionary
	var feature_counts := audit.get("feature_counts", {}) as Dictionary
	_check(feature_counts == expected_counts, "feature inventory is complete and deliberately bounded")
	var authored_audit := audit.get("authored_asset_audit", {}) as Dictionary
	_check(
		bool(audit.get("authored_presentation", false))
		and bool(audit.get("authored_asset_valid", false))
		and bool(authored_audit.get("valid", false)),
		"world delegates presentation integrity to the Blender-authored berth audit"
	)
	_check(
		str(authored_audit.get("authorship", "")) == "original_script_assisted_blender"
		and int(authored_audit.get("semantic_root_count", 0)) == 5
		and int(authored_audit.get("material_role_count", 0)) == 5,
		"authored platform retains five semantic layers and five material roles"
	)
	_check(
		int(authored_audit.get("runtime_mesh_count", 0)) == 8
		and int(authored_audit.get("runtime_surface_count", 0)) == 8
		and int(authored_audit.get("runtime_triangle_count", 0)) == 11_508,
		"111 editable components remain batched to eight runtime draws and 11,508 triangles"
	)
	_check(
		not bool(authored_audit.get("gameplay_authority", true))
		and not bool(authored_audit.get("collision_authority", true))
		and not bool(authored_audit.get("walking_surface_authority", true))
		and int(authored_audit.get("forbidden_authority_node_count", -1)) == 0,
		"authored platform remains strictly visual and authority-free"
	)
	_check(
		str((audit.get("deck_pbr", {}) as Dictionary).get("scope", "")) == "operational_walking_surface_only"
		and str((audit.get("deck_pbr", {}) as Dictionary).get("texture_coordinate", "")) == "UV0/TEXCOORD_0"
		and not bool((audit.get("deck_pbr", {}) as Dictionary).get("triplanar", true)),
		"PBR audit explicitly limits the deck maps to walking surfaces"
	)

	# Public reports must not provide a mutation path back into world state.
	(evidence.get("modern_provisional", PackedStringArray()) as PackedStringArray).append("mutation")
	evidence["content_note"] = "mutation"
	feature_counts[&"docking_clamp"] = 99
	var clean_audit := world.get_central_berth_audit_report()
	var clean_evidence := clean_audit.get("evidence", {}) as Dictionary
	_check(
		"mutation" not in (clean_evidence.get("modern_provisional", PackedStringArray()) as PackedStringArray)
		and str(clean_evidence.get("content_note", "")) != "mutation"
		and int((clean_audit.get("feature_counts", {}) as Dictionary).get(&"docking_clamp", 0)) == 3,
		"nested audit data is deeply detached"
	)

	var pad := world.get_node_or_null("LandingPad") as Node3D
	_check(
		pad != null
		and bool(pad.get_meta("torrent_berth_candidate", false))
		and str(pad.get_meta("geometry_status", "")) == "provisional"
		and not bool(pad.get_meta("authenticated_original_geometry", true)),
		"runtime hero-cell metadata preserves candidate/provisional status"
	)


func _test_berth_contracts(world: ShipyardWorld, torrent: HeroShip) -> void:
	var berth_ids := world.get_berth_ids()
	_check(
		berth_ids.size() == 4
		and berth_ids.has(&"arrow_recon_berth")
		and berth_ids.has(&"central_berth")
		and berth_ids.has(&"jovian_freight_berth")
		and berth_ids.has(&"zenith_fleet_dock_berth"),
		"exactly the four production berth IDs remain registered"
	)
	var central_transform := world.get_berth_transform(&"central_berth")
	var arrow_transform := world.get_berth_transform(&"arrow_recon_berth")
	var jovian_transform := world.get_berth_transform(&"jovian_freight_berth")
	var zenith_transform := world.get_berth_transform(&"zenith_fleet_dock_berth")
	_check(
		central_transform.is_equal_approx(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0))),
		"central berth transform remains exact"
	)
	_check(
		arrow_transform.is_equal_approx(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-43.0, 1.15, 15.5))),
		"Arrow berth transform remains exact"
	)
	_check(
		jovian_transform.is_equal_approx(Transform3D(Basis(Vector3.UP, PI), Vector3(-53.0, 1.63, 57.3))),
		"Jovian berth transform remains exact"
	)
	_check(
		zenith_transform.is_equal_approx(Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3))),
		"Zenith fleet-dock berth transform remains exact"
	)
	var central_berth := world.get_berth_node(&"central_berth")
	_check(
		central_berth != null
		and central_berth.get_landing_half_extents().is_equal_approx(Vector3(12.0, 3.8, 17.0))
		and central_berth.get_compatibility_tags() == PackedStringArray(["small_craft"]),
		"central landing envelope and compatibility contract remain unchanged"
	)
	_check(
		central_berth != null
		and central_berth.get_reservation_owner() == torrent
		and central_berth.get_occupant() == torrent
		and central_berth.get_reserved_ship_id() == &"torrent_provisional",
		"Torrent retains the authoritative occupied central-berth lease"
	)
	_check(torrent.global_transform.is_equal_approx(central_transform), "parked Torrent root still matches the berth transform")

	var hero_body := world.get_node_or_null("ExposedDockLattice/HeroBerthNode") as StaticBody3D
	var launch_body := world.get_node_or_null("OpenLaunchSpine/LaunchArmDeck") as StaticBody3D
	# RUNWAY-SEAM-001. Re-frozen from centre (0.0, -0.62, -10.0) size
	# (27.0, 1.2, 30.0) to centre (0.0, -0.62, -8.625) size (25.5, 1.2, 32.75).
	# Two separate corrections, both measured against the authored shell this body
	# already renders nothing of:
	#   z: +2.75 m, taking over the strip of floor the walkway gave up when it was
	#      pulled back to the shell's own z = 7.75 edge instead of running 2.75 m
	#      underneath it. The top plane, y = -0.020, is unchanged, so the physical
	#      surface a player stands on across the seam is unchanged.
	#   x: 27.0 -> 25.5 m, the shell's own width. The extra 0.75 m per side was a
	#      standable ledge the renderer never drew.
	_check(_box_body_matches(hero_body, Vector3(0.0, -0.62, -8.625), Vector3(25.5, 1.2, 32.75)), "HeroBerthNode collider and transform remain unchanged")
	var hidden_legacy_mesh := hero_body.get_node_or_null("Mesh") as MeshInstance3D if hero_body != null else null
	_check(
		hidden_legacy_mesh != null
		and not hidden_legacy_mesh.visible
		and bool(hidden_legacy_mesh.get_meta("hidden_by_authored_central_berth", false)),
		"legacy physical berth slab retains collision but no longer double-renders"
	)
	# Re-frozen from centre (0.0, -0.36, -48.0) size (21.5, 0.72, 40.0) to centre
	# (0.0, -0.36, -47.875) size (21.5, 0.72, 40.25): the arm's rendered aft edge
	# now reaches the authored shell at z = -27.75 instead of stopping at -28.0 and
	# leaving the transition block's 0.095 m top plane exposed with nothing drawn
	# on it. Width, top plane and the forward end at z = -68.0 are unchanged.
	_check(_box_body_matches(launch_body, Vector3(0.0, -0.36, -47.875), Vector3(21.5, 0.72, 40.25)), "LaunchArmDeck collider and transform remain unchanged")
	var transition := world.get_node_or_null("OpenLaunchSpine/CentralBerthLaunchTransitionCollision") as StaticBody3D
	# Re-frozen from centre (0.0, -0.5625, -26.5) size (25.5, 1.315, 3.0) to centre
	# (0.0, -0.5625, -26.375) size (25.5, 1.315, 2.75). It carries the shell's
	# y = 0.095 top plane, so it now starts where the shell starts; the 0.25 m it
	# gave up is carried by the launch arm deck above.
	_check(
		_box_body_matches(transition, Vector3(0.0, -0.5625, -26.375), Vector3(25.5, 1.315, 2.75))
		and transition.get_node_or_null("Mesh") == null
		and bool(transition.get_meta("authored_surface_support", false)),
		"collision-only transition supports the authored berth-to-launch seam"
	)


func _test_structure_and_material_scope(world: ShipyardWorld) -> void:
	var pad := world.get_node("LandingPad") as Node3D
	var presentation := world.get_central_berth_hero_presentation()
	var deck_root := presentation.get_semantic_root(&"deck_panels") if presentation != null else null
	var deck_material := presentation.get_runtime_material(&"DeckComposite") if presentation != null else null
	_check(
		presentation != null
		and presentation.get_parent() == pad
		and presentation.transform.is_equal_approx(Transform3D.IDENTITY)
		and pad.get_node_or_null("PadInset") == null
		and pad.get_node_or_null("HeroBerthStructure") == null,
		"identity-mounted authored shell replaces both legacy procedural presentation nodes"
	)
	_check(
		deck_material != null
		and deck_material.albedo_texture != null
		and deck_material.albedo_texture.resource_path == DECK_ALBEDO_PATH,
		"operational pad skin uses the shipyard deck albedo"
	)
	_check(
		deck_material != null
		and deck_material.normal_enabled
		and deck_material.normal_texture != null
		and deck_material.normal_texture.resource_path == DECK_NORMAL_PATH
		and is_equal_approx(deck_material.normal_scale, 0.42),
		"operational pad skin uses the bounded normal map"
	)
	_check(
		deck_material != null
		and deck_material.roughness_texture != null
		and deck_material.roughness_texture.resource_path == DECK_ROUGHNESS_PATH
		and deck_material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
		and not deck_material.uv1_triplanar,
		"authored deck uses roughness and UV0 rather than procedural triplanar mapping"
	)
	var deck_uv0_is_meaningful := false
	if deck_root != null:
		for candidate in deck_root.find_children("*", "MeshInstance3D", true, false):
			var mesh := (candidate as MeshInstance3D).mesh
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var uv_value: Variant = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			if uv_value is PackedVector2Array and (uv_value as PackedVector2Array).size() >= 3:
				var uv := uv_value as PackedVector2Array
				deck_uv0_is_meaningful = (
					uv[0].distance_to(uv[1]) > 0.0001
					or uv[1].distance_to(uv[2]) > 0.0001
				)
	_check(deck_uv0_is_meaningful, "authored deck batch contains non-collapsed UV0 coordinates")

	var mapped_meshes: Array[MeshInstance3D] = []
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material != null and material.albedo_texture != null \
				and material.albedo_texture.resource_path == DECK_ALBEDO_PATH:
			mapped_meshes.append(mesh_instance)
	_check(
		mapped_meshes.size() == 1
		and presentation != null
		and presentation.is_ancestor_of(mapped_meshes[0])
		and str(mapped_meshes[0].get_meta("central_berth_material_role", "")) == "DeckComposite",
		"shipyard deck maps do not leak onto fascia, trusses, pressure/service objects, signs, or the moon"
	)
	_check(
		presentation != null
		and presentation.get_semantic_root(&"edge_fascia") != null
		and presentation.get_semantic_root(&"primary_structure") != null
		and presentation.get_semantic_root(&"secondary_structure") != null
		and presentation.get_semantic_root(&"service_channels") != null,
		"authored fascia, primary structure, secondary structure, and service channels remain distinct"
	)
	_check(presentation != null and not _contains_collision(presentation), "authored berth shell adds no hidden gameplay collision")


func _test_clamp_alignment_and_service_clearance(world: ShipyardWorld, torrent: HeroShip) -> void:
	var pad := world.get_node("LandingPad") as Node3D
	var hardware := pad.get_node("TorrentDockingHardware") as Node3D
	var clamps := _features(pad, &"docking_clamp")
	_check(clamps.size() == 3, "exactly three visible docking clamps are installed")

	var actual_feet := {}
	var nose_foot := torrent.find_child("NoseFoot", true, false) as MeshInstance3D
	if nose_foot != null:
		actual_feet[&"nose"] = nose_foot.global_position
	for candidate in torrent.find_children("LandingFoot", "MeshInstance3D", true, false):
		var foot := candidate as MeshInstance3D
		actual_feet[&"port_main" if foot.global_position.x < 0.0 else &"starboard_main"] = foot.global_position
	_check(actual_feet.size() == 3, "live Torrent exposes its three physical gear-contact visuals")

	var all_aligned := clamps.size() == 3 and actual_feet.size() == 3
	for clamp in clamps:
		var contact_id := StringName(clamp.get_meta("gear_contact_id", &""))
		var foot_position: Vector3 = actual_feet.get(contact_id, Vector3.INF)
		var planar_error := Vector2(clamp.global_position.x, clamp.global_position.z).distance_to(Vector2(foot_position.x, foot_position.z))
		all_aligned = all_aligned \
			and planar_error <= 0.02 \
			and clamp.global_position.y < foot_position.y - 0.2 \
			and not _contains_collision(clamp)
	_check(all_aligned, "clamps align to all three live Torrent contacts while staying retracted and non-colliding")
	_check(hardware != null and not _contains_collision(hardware), "complete docking-hardware presentation is collision-free")

	var housings := _features(pad, &"umbilical_housing")
	var hoses := _features(pad, &"parked_umbilical_hose")
	var utilities_safe := housings.size() == 3 and hoses.size() == 3
	for housing in housings:
		utilities_safe = utilities_safe and housing.global_position.x > 9.5 and not _contains_collision(housing)
	for hose in hoses:
		utilities_safe = utilities_safe \
			and bool(hose.get_meta("parked", false)) \
			and float(hose.get_meta("maximum_world_height", 99.0)) < 0.5 \
			and not _contains_collision(hose)
	_check(utilities_safe, "power/data/fuel housings and hoses remain parked outside the craft lane")

	var cabinet := _features(pad, &"service_cabinet")
	var pedestal := _features(pad, &"control_pedestal")
	_check(cabinet.size() == 1 and cabinet[0].global_position.x > 9.5 and not _contains_collision(cabinet[0]), "service cabinet stays on the safe starboard edge")
	_check(
		pedestal.size() == 1
		and float(pedestal[0].get_meta("hand_scale_height", 0.0)) <= 1.2
		and pedestal[0].global_position.x > 8.0
		and not _contains_collision(pedestal[0]),
		"control pedestal is hand-scale and outside the flight/boarding lanes"
	)
	_check(
		_features(pad, &"cable_trench").size() == 2
		and _features(pad, &"drain").size() == 4
		and _features(pad, &"work_detail").size() == 6,
		"trenches, drains, and flush work detail remain deliberately restrained"
	)


func _test_lighting_and_probe(world: ShipyardWorld) -> void:
	var pad := world.get_node("LandingPad") as Node3D
	var fixtures := _features(pad, &"recessed_fixture")
	var fixtures_integrated := fixtures.size() == 8
	for fixture in fixtures:
		fixtures_integrated = fixtures_integrated \
			and bool(fixture.get_meta("recessed_below_surface", false)) \
			and fixture.find_children("*", "OmniLight3D", true, false).size() == 1 \
			and fixture.find_children("*", "SphereMesh", true, false).is_empty() \
			and not _contains_sphere_mesh(fixture)
	_check(fixtures_integrated, "eight recessed non-bead berth fixtures provide localized edge light")

	var central_beads := 0
	for lens in pad.find_children("GuideLens", "MeshInstance3D", true, false):
		if absf((lens as MeshInstance3D).global_position.x) < 20.0:
			central_beads += 1
	_check(central_beads == 0, "legacy bead-like guide lenses are absent from the central berth")

	var probes := _features(pad, &"reflection_probe")
	var probe := probes[0] as ReflectionProbe if probes.size() == 1 else null
	_check(
		probe != null
		and probe.update_mode == ReflectionProbe.UPDATE_ONCE
		and probe.size.is_equal_approx(Vector3(26.0, 9.0, 34.0))
		and probe.box_projection
		and probe.enable_shadows,
		"one bounded update-once reflection probe serves the hero cell"
	)
	var fill := world.get_node_or_null("LandingPadFill") as OmniLight3D
	_check(
		fill != null
		and fill.light_energy <= 0.55
		and fill.omni_range <= 14.0
		and bool(fill.get_meta("restrained_hero_fill", false)),
		"broad cyan fill is reduced and range-bounded"
	)
	var work_lights := _nodes_with_meta(world, "central_berth_key_light", true, "SpotLight3D")
	var key_light := world.get_node_or_null("SpaceKeyLight") as DirectionalLight3D
	_check(work_lights.size() == 2 and (work_lights[0] as SpotLight3D).shadow_enabled and (work_lights[1] as SpotLight3D).shadow_enabled, "paired neutral work lights retain local shadows")
	_check(key_light != null and key_light.shadow_enabled, "directional key and navigation shadow hierarchy remain intact")
	_check(
		pad.get_node_or_null("Centreline") != null
		and pad.get_node_or_null("OuterPadRing") != null
		and pad.get_node_or_null("InnerPadRing") != null
		and _nodes_with_meta(pad, "navigation_role", &"launch_vector_chevron", "MeshInstance3D").size() == 12,
		"centreline, rings, and launch-vector navigation cues are preserved"
	)
	_test_world_lighting_rig(world)


## Freezes the world-level lighting rig.
##
## Every light budget in this project was module-scoped, so the rig hung
## directly off ShipyardWorld and nothing counted it. That gap is closed here
## rather than left open: an unbudgeted rig is exactly where per-frame cost
## accumulates unnoticed.
##
## Re-frozen in the open. Directional 2 -> 3, spot 6 -> 8, omni 1 -> 1, total
## 9 -> 12; shadow casters 7 -> 8. The three additions and their reasons:
##
## - `DeckBounceFill`, a shadowless upward directional. Every downward-facing
##   surface on the station previously received ambient and nothing else,
##   because the key comes from above and the counter-fill comes from behind and
##   level. Parked hull undersides, catwalk soffits and gear bays sat at one
##   value with no gradient across them.
## - `FreightApproachMastSpot`, shadowed, over the approach gantry work zone.
## - `FleetDockMastSpot`, shadowless, over the Zenith berth. The Fleet Dock comb
##   has no light nodes at all by its own frozen contract, so that berth had no
##   local light of any kind.
##
## Only the freight mast adds a shadow map. Frame cost was not measured: this
## machine renders through llvmpipe and any number produced here would be
## meaningless.
func _test_world_lighting_rig(world: ShipyardWorld) -> void:
	var directional := 0
	var spot := 0
	var omni := 0
	var shadow_casters := 0
	var rig_masts: Array[SpotLight3D] = []
	for child in world.get_children():
		if child is DirectionalLight3D:
			directional += 1
		elif child is SpotLight3D:
			spot += 1
			rig_masts.append(child as SpotLight3D)
		elif child is OmniLight3D:
			omni += 1
		else:
			continue
		if (child as Light3D).shadow_enabled:
			shadow_casters += 1
	_check(
		directional == 3 and spot == 8 and omni == 1 and shadow_casters == 8,
		"world lighting rig is exactly three directional, eight spot and one omni light with eight shadow casters"
	)

	var bounce := world.get_node_or_null("DeckBounceFill") as DirectionalLight3D
	_check(
		bounce != null
		and bool(bounce.get_meta("diffuse_bounce_fill", false))
		and not bounce.shadow_enabled
		and is_zero_approx(bounce.light_specular)
		and (-bounce.global_transform.basis.z).y > 0.5,
		"deck bounce points upward, casts no shadow and contributes no specular"
	)

	# The reason the masts were widened, stated as a property rather than as the
	# number that satisfies it today. A 39 degree cone from y = 9.0 laid a 7.3 m
	# pool, so the mast nearest the Arrow berth stopped short of the berth and the
	# parked craft sat outside its own light. Every deck mast must lay a pool at
	# least 9.5 m across the deck plane, and its range must reach the far edge of
	# that pool rather than clipping it short.
	var masts_reach := not rig_masts.is_empty()
	for mast in rig_masts:
		var height := mast.global_position.y
		var pool_radius := height * tan(deg_to_rad(mast.spot_angle))
		masts_reach = masts_reach \
			and height > 0.0 \
			and pool_radius >= 9.5 \
			and mast.spot_range >= sqrt(height * height + pool_radius * pool_radius)
	_check(masts_reach, "every deck mast lays at least a 9.5 m deck pool and its range reaches that pool's edge")


func _test_floor_routes_and_launch_volume(world: ShipyardWorld, torrent: HeroShip) -> void:
	var space := world.get_world_3d().direct_space_state
	var route_samples := [
		Vector3(-8.5, 0.2, 11.0),
		Vector3(-8.0, 0.2, 7.0),
		Vector3(-7.0, 0.2, 3.0),
		Vector3(-5.0, 0.2, -2.0),
		Vector3(-3.2, 0.2, -9.35),
		Vector3(-7.6, 0.2, -9.25),
		Vector3(0.0, 0.2, -25.25),
		Vector3(0.0, 0.2, -26.5),
		Vector3(0.0, 0.2, -27.75),
	]
	var route_supported := true
	var route_clear := true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	for sample: Vector3 in route_samples:
		var ray := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * 2.2, sample + Vector3.DOWN * 3.0, PhysicsLayers.WORLD)
		route_supported = route_supported and not space.intersect_ray(ray).is_empty()
		var capsule_query := PhysicsShapeQueryParameters3D.new()
		capsule_query.shape = capsule
		capsule_query.transform = Transform3D(Basis.IDENTITY, Vector3(sample.x, 1.15, sample.z))
		capsule_query.collision_mask = PhysicsLayers.WORLD
		route_clear = route_clear and space.intersect_shape(capsule_query, 8).is_empty()
	_check(route_supported, "spawn, boarding, exit, and authored berth-to-launch seam retain continuous deck support")
	_check(route_clear, "spawn-to-boarding and port exit player capsules remain unobstructed")

	var launch_clear := true
	var berth_transform := world.get_berth_transform(&"central_berth")
	for travel_distance in [0.0, 4.0, 8.0, 16.0, 28.0]:
		var staged_root := berth_transform.translated_local(Vector3(0.0, 0.0, -travel_distance))
		for collision_candidate in torrent.get_children():
			if not collision_candidate is CollisionShape3D:
				continue
			var collision := collision_candidate as CollisionShape3D
			if collision.disabled or collision.shape == null:
				continue
			var shape_query := PhysicsShapeQueryParameters3D.new()
			shape_query.shape = collision.shape
			shape_query.transform = staged_root * collision.transform
			shape_query.collision_mask = PhysicsLayers.WORLD
			launch_clear = launch_clear and space.intersect_shape(shape_query, 16).is_empty()
	_check(launch_clear, "all canonical Torrent hull, propulsion, and gear envelopes have a clear low-altitude takeoff path")


func _features(root_node: Node, feature_id: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in root_node.find_children("*", "", true, false):
		if StringName(candidate.get_meta("central_berth_feature", &"")) == feature_id:
			result.append(candidate)
	return result


func _nodes_with_meta(root_node: Node, key: StringName, value: Variant, type_name: String = "") -> Array[Node]:
	var result: Array[Node] = []
	for candidate in root_node.find_children("*", type_name, true, false):
		if candidate.has_meta(key) and candidate.get_meta(key) == value:
			result.append(candidate)
	return result


func _contains_collision(root_node: Node) -> bool:
	if root_node is CollisionObject3D or root_node is CollisionShape3D:
		return true
	return not root_node.find_children("*", "CollisionObject3D", true, false).is_empty() \
		or not root_node.find_children("*", "CollisionShape3D", true, false).is_empty()


func _contains_sphere_mesh(root_node: Node) -> bool:
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		if (candidate as MeshInstance3D).mesh is SphereMesh:
			return true
	return false


func _box_body_matches(body: StaticBody3D, expected_position: Vector3, expected_size: Vector3) -> bool:
	if body == null or not body.position.is_equal_approx(expected_position):
		return false
	var collision := body.get_node_or_null("Collision") as CollisionShape3D
	return collision != null \
		and collision.shape is BoxShape3D \
		and (collision.shape as BoxShape3D).size.is_equal_approx(expected_size) \
		and body.collision_layer == PhysicsLayers.WORLD


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CENTRAL_BERTH_HERO_TEST_OK")
		quit(0)
	else:
		print("CENTRAL_BERTH_HERO_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
