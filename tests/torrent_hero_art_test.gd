extends SceneTree

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

const HERO_ATLAS_PATHS := {
	"albedo": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png",
	"normal": "res://assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png",
	"roughness": "res://assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png",
	"orm": "res://assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png",
	"emissive": "res://assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png",
}
const FLAT_STUDY_FRAGMENT := "torrent-hero-flat-albedo-study"
const HERO_MATERIAL_ROLE_ORDER := [
	"stepped_side_trim_atlas",
	"warm_ivory",
	"restrained_graphite",
]
const HERO_MATERIAL_ROLE_MEMBERS := [
	[
		"PortLowerSidePlane", "PortUpperSidePlane",
		"StarboardLowerSidePlane", "StarboardUpperSidePlane",
	],
	[
		"PointedNose", "CentralPressureKeel", "RaisedSpine", "BlockyAftBody",
		"PortAftRail", "StarboardAftRail", "AftCrossbar",
	],
	["PortAftCircularHousing", "StarboardAftCircularHousing"],
]
const HERO_MATERIAL_ROLE_NODE_COUNTS := [8, 14, 4]

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "TorrentHeroArtTestRoot"
	root.add_child(_test_root)
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_check(torrent != null, "Torrent scene instantiates as HeroShip")
	if torrent == null:
		_finish()
		return
	_test_root.add_child(torrent)
	await process_frame
	await physics_frame
	_test_construction_audit(torrent)
	_test_airframe_and_surface_materials(torrent)
	_test_authored_material_roles(torrent)
	_test_propulsion_and_hardware(torrent)
	await _test_cockpit_canopy_and_contracts(torrent)
	await _test_variant_seams()
	torrent.queue_free()
	await process_frame
	_test_root.queue_free()
	await process_frame
	_finish()


func _test_construction_audit(torrent: HeroShip) -> void:
	var audit := torrent.get_torrent_art_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "constructed Torrent passes its focused art audit")
	_check(int(audit.schema_version) == 4, "art audit exposes the Blender-close-art v4 schema")
	_check(str(audit.identity_lock) == "dated_2011" and str(audit.historical_revision) == "2011", "art audit source-locks this presentation specifically to the dated 2011 Torrent")
	_check(str(audit.reconstruction_status) == "partial" and str(audit["2009_continuity"]) == "unproved", "art audit keeps reconstruction detail partial and 2009 continuity unproved")
	_check(str(audit.geometry_status) == "source_aligned_partial" and not bool(audit.authenticated_geometry), "art audit makes no unsupported authenticated-geometry claim")
	var fallback := audit.get("far_fallback_reconstruction", {}) as Dictionary
	var close_art := audit.get("close_presentation", {}) as Dictionary
	_check(bool(fallback.get("valid", false)), "art audit retains one independently valid dated-2011 far/fallback macroform")
	_check(bool(close_art.get("valid", false)) and int(close_art.get("lod0_triangle_count", 0)) >= 45000 and int(close_art.get("near_surface_count", 999)) <= 32, "art audit requires dense Blender close geometry within its draw-surface budget")
	_check(int(fallback.get("engine_assembly_count", 0)) == 2 and int(fallback.get("landing_gear_assembly_count", 0)) == 3, "fallback audit retains twin engines and tricycle gear")
	_check(int(fallback.get("rcs_cluster_count", 0)) == 4 and int(fallback.get("service_panel_count", 0)) >= 4, "fallback audit inventories RCS clusters and service access panels")
	_check(int(fallback.get("mapped_hull_material_count", 0)) == 2, "both fallback hull material families keep their registered maps")


func _test_airframe_and_surface_materials(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	_check(visual != null and visual.name == &"TorrentVisual", "Torrent keeps its stable visual-root seam")
	_check(str(visual.get_meta("geometry_status", "")) == "source_aligned_partial", "visual root records source-aligned partial geometry status")
	_check(str(visual.get_meta("identity_lock", "")) == "dated_2011", "visual root carries the dated-2011 identity lock")
	_check(not bool(visual.get_meta("authenticated_historical_silhouette", true)) and not bool(visual.get_meta("authenticated_exact_geometry", true)), "visual root denies authenticated silhouette and exact-geometry claims")
	var authored_root := visual.get_node_or_null("LegacyFarPresentation/TorrentAuthoredMacroform") as Node3D
	var dated_form := authored_root.get_node_or_null("Dated2011Form") as Node3D if authored_root != null else null
	var lod0 := dated_form.get_node_or_null("MacroformLOD0") as Node3D if dated_form != null else null
	var modern_systems := visual.get_node_or_null("LegacyFarPresentation/ModernSystems") as Node3D
	_check(authored_root != null and authored_root.get_parent() == visual.get_node_or_null("LegacyFarPresentation"), "source-aligned macroform is one checked-in authored far/fallback instance")
	_check(dated_form != null and lod0 != null, "authored presentation keeps its dedicated Dated2011Form and primary LOD hierarchy")
	_check(modern_systems != null and modern_systems.get_parent() == visual.get_node_or_null("LegacyFarPresentation"), "unsupported fallback detail has a separate ModernSystems hierarchy")
	if dated_form != null:
		_check(str(dated_form.get_meta("evidence_status", "")) == "source_aligned_partial" and bool(dated_form.get_meta("historically_supported", false)), "dated form is explicitly bounded to source-aligned broad features")
	if modern_systems != null:
		_check(str(modern_systems.get_meta("evidence_status", "")) == "modern_interpretation" and not bool(modern_systems.get_meta("historically_supported", true)), "modern systems cannot masquerade as recovered historical detail")

	var pointed_nose := lod0.get_node_or_null("PointedNose") as MeshInstance3D if lod0 != null else null
	_check(pointed_nose != null and pointed_nose.mesh is ArrayMesh, "dated macroform begins with an imported authored pointed mesh")
	if pointed_nose != null:
		_check(pointed_nose.mesh.resource_path.ends_with("torrent_macroform_lod0_pointed_nose.obj"), "pointed nose resolves to its checked-in authored OBJ rather than runtime geometry")
		_check(str(pointed_nose.get_meta("silhouette_role", "")) == "pointed_nose", "pointed loft publishes its source-safe silhouette role")

	var plane_names: Array[String] = [
		"PortLowerSidePlane",
		"PortUpperSidePlane",
		"StarboardLowerSidePlane",
		"StarboardUpperSidePlane",
	]
	var side_planes := lod0.find_children("*SidePlane", "MeshInstance3D", false, false) if lod0 != null else []
	_check(side_planes.size() == 4, "dated macroform has exactly four stepped side-plane tiers")
	for plane_name: String in plane_names:
		var plane := lod0.get_node_or_null(NodePath(plane_name)) as MeshInstance3D if lod0 != null else null
		_check(plane != null and plane.mesh is ArrayMesh, "%s is an authored sealed planform" % plane_name)
		if plane != null:
			_check(plane.mesh.resource_path.ends_with("torrent_macroform_lod0_%s.obj" % plane_name.to_snake_case()), "%s uses its checked-in imported semantic mesh" % plane_name)
			_check(bool(plane.get_meta("stepped_edge", false)) and str(plane.get_meta("silhouette_role", "")) == "stepped_side_plane", "%s records the observed stepped-plane role" % plane_name)
			_check(plane.get_aabb().size.y >= 0.2, "%s retains meaningful authored tier thickness" % plane_name)

	for side_name: String in ["Port", "Starboard"]:
		var rail := lod0.get_node_or_null(NodePath(side_name + "AftRail")) as MeshInstance3D if lod0 != null else null
		var housing := lod0.get_node_or_null(NodePath(side_name + "AftCircularHousing")) as MeshInstance3D if lod0 != null else null
		_check(rail != null and rail.mesh is ArrayMesh, "%s dated aft rail is one imported authored upright assembly" % side_name)
		_check(housing != null and housing.mesh is ArrayMesh and bool(housing.get_meta("circular_form", false)), "%s dated aft housing preserves the paired round-form landmark" % side_name)
		if rail != null:
			_check(str(rail.get_meta("silhouette_role", "")) == "upright_aft_rail", "%s aft rail carries its source-safe silhouette role" % side_name)
		if housing != null:
			_check(bool(housing.get_meta("historical_function_unresolved", false)) and str(housing.get_meta("modern_interpretation", "")) == "engine", "%s round housing separates observed form from modern engine function" % side_name)
	var aft_crossbar := lod0.get_node_or_null("AftCrossbar") as MeshInstance3D if lod0 != null else null
	_check(aft_crossbar != null, "paired aft rails retain an inferred crossbar for the U-like rear read")
	if aft_crossbar != null:
		_check(
			str(aft_crossbar.get_meta("evidence_status", "")) == "inferred_reconstruction"
			and not bool(aft_crossbar.get_meta("historically_supported", true)),
			"aft crossbar is not overclaimed as directly source-observed geometry"
		)

	var materials := torrent.get_variant_materials()
	for material_name in [&"ivory", &"light"]:
		var hull_material := materials.get(material_name) as StandardMaterial3D
		_check(hull_material != null and hull_material.albedo_texture != null, "%s retains the Torrent hull albedo" % material_name)
		_check(hull_material != null and hull_material.normal_enabled and hull_material.normal_texture != null, "%s uses the Torrent-derived normal map" % material_name)
		_check(hull_material != null and is_equal_approx(hull_material.normal_scale, 0.32), "%s keeps the surface normal relief subtle" % material_name)
		_check(hull_material != null and hull_material.roughness_texture != null, "%s uses the Torrent-derived roughness map" % material_name)


func _test_propulsion_and_hardware(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	var modern_systems := visual.get_node_or_null("LegacyFarPresentation/ModernSystems") as Node3D
	var engines := modern_systems.find_children("*EngineAssembly", "Node3D", true, false) if modern_systems != null else []
	_check(engines.size() == 2, "Torrent has exactly two named engine assemblies")
	for engine_node in engines:
		var engine := engine_node as Node3D
		_check(str(engine.get_meta("interpretation_status", "")) == "modern" and not bool(engine.get_meta("historically_supported", true)), "%s labels its engine function as modern interpretation" % engine.name)
		_check(bool(engine.get_meta("recessed_engine_interior", false)), "%s identifies a recessed mechanical interior" % engine.name)
		_check(not bool(engine.get_meta("exposed_emissive_disc", true)), "%s explicitly rejects the glowing-disc treatment" % engine.name)
		_check(engine.get_node_or_null("ForwardMountCollar") is MeshInstance3D and engine.get_node_or_null("EngineCollar") is MeshInstance3D, "%s has structural mount and aft collars" % engine.name)
		_check(engine.get_node_or_null("EngineNozzle") is MeshInstance3D and engine.get_node_or_null("NozzleThermalLip") is MeshInstance3D, "%s has a divergent nozzle and thermal lip" % engine.name)
		_check(engine.find_children("TurbineStatorVane*", "MeshInstance3D", false, false).size() == 8, "%s has eight visible stator vanes" % engine.name)
		var core := engine.get_node_or_null("EngineCore") as MeshInstance3D
		var plume := engine.get_node_or_null("EnginePlume") as MeshInstance3D
		_check(core != null and not _material_emits(core.mesh.surface_get_material(0)), "%s mechanical core is non-emissive" % engine.name)
		_check(plume != null and not plume.visible, "%s keeps its separate plume hidden while offline" % engine.name)
	var gear := modern_systems.find_children("*GearAssembly", "Node3D", true, false) if modern_systems != null else []
	_check(gear.size() == 3, "Torrent exposes two main and one nose gear assembly")
	for gear_node in gear:
		var assembly := gear_node as Node3D
		_check(bool(assembly.get_meta("articulated_visual_only", false)) and bool(assembly.get_meta("parked_configuration", false)), "%s labels its articulated parked presentation honestly" % assembly.name)
		_check(assembly.find_children("*Strut", "MeshInstance3D", false, false).size() >= 1, "%s has a load-bearing strut" % assembly.name)
		_check(assembly.find_children("*Brace", "MeshInstance3D", false, false).size() >= 1, "%s has triangulating brace hardware" % assembly.name)
	var docking_receiver := modern_systems.get_node_or_null("VentralDockingReceiver") as Node3D if modern_systems != null else null
	_check(docking_receiver != null and docking_receiver.get_parent() == modern_systems, "ventral docking receiver lives under ModernSystems")
	_check(docking_receiver != null and docking_receiver.get_node_or_null("DockingCaptureRing") is MeshInstance3D, "ventral docking receiver has a physical capture ring")
	_check(docking_receiver != null and docking_receiver.find_children("CaptureJaw*", "MeshInstance3D", false, false).size() == 4, "docking receiver exposes four capture jaws")
	_check(modern_systems != null and modern_systems.find_children("*RCSCluster", "Node3D", true, false).size() == 4, "four presentation-only RCS clusters are visible")
	_check(modern_systems != null and modern_systems.find_children("*DorsalVentBank", "Node3D", true, false).size() == 2, "paired louvred vent banks service the aft fuselage")


func _test_authored_material_roles(torrent: HeroShip) -> void:
	var authored_root := torrent.find_child("TorrentAuthoredMacroform", true, false) as Node3D
	_check(authored_root != null, "Torrent integrates the authored macroform presentation")
	if authored_root == null:
		return

	_check(authored_root.has_method("get_torrent_authored_asset_audit_report"), "authored macroform publishes its material and provenance audit")
	var material_contract: Dictionary = {}
	if authored_root.has_method("get_torrent_authored_asset_audit_report"):
		var authored_audit := authored_root.call("get_torrent_authored_asset_audit_report") as Dictionary
		material_contract = authored_audit.get("material_contract", {}) as Dictionary
		_check(bool(authored_audit.get("valid", false)), "authored macroform audit accepts its exact three-role material contract")
		_check(material_contract.get("material_role_order", []) == HERO_MATERIAL_ROLE_ORDER, "authored audit publishes the exact ordered material roles")
		_check(material_contract.get("material_role_members", []) == HERO_MATERIAL_ROLE_MEMBERS, "authored audit binds each semantic component to its exact material role")
		_check(str(material_contract.get("albedo", "")) == str(HERO_ATLAS_PATHS.albedo), "authored audit registers the exact runtime trim albedo")
		_check(str(material_contract.get("normal", "")) == str(HERO_ATLAS_PATHS.normal), "authored audit registers the exact runtime trim normal")
		_check(str(material_contract.get("roughness", "")) == str(HERO_ATLAS_PATHS.roughness), "authored audit registers the exact runtime trim roughness")
		_check(str(material_contract.get("orm", "")) == str(HERO_ATLAS_PATHS.orm), "authored audit registers the exact packed ORM artifact")
		_check(str(material_contract.get("emissive", "")) == str(HERO_ATLAS_PATHS.emissive), "authored audit registers the exact sparse-cyan emissive mask")
		_check(bool(material_contract.get("non_triplanar", false)) and bool(material_contract.get("non_seamless", false)), "authored audit classifies the trim as a non-triplanar non-seamless UV atlas")
		_check(str(material_contract.get("production_usage", "")) == "selected_stepped_side_planes_only", "authored audit limits the proxy atlas to selected stepped side planes")
		_check(not bool(material_contract.get("final_hand_authored_pbr", true)), "authored audit does not mislabel the image-derived proxy atlas as final hand-authored PBR")
		_check(not bool(material_contract.get("flat_study_bound", true)), "authored audit confirms that the unverified flat study is not bound")

	var semantic_meshes := authored_root.find_children("*", "MeshInstance3D", true, false)
	_check(semantic_meshes.size() == 26, "authored macroform exposes the exact 13-component roster at both LODs")
	var role_material_ids: Array[Dictionary] = [{}, {}, {}]
	var role_node_counts := [0, 0, 0]
	var flat_study_bound := false
	for semantic_node: Node in semantic_meshes:
		var semantic_mesh := semantic_node as MeshInstance3D
		var material := semantic_mesh.material_override as StandardMaterial3D
		_check(material != null, "%s has its registered authored material role" % semantic_mesh.name)
		if material == null:
			continue
		var role_index := _hero_material_role_index(str(semantic_mesh.name))
		_check(role_index >= 0, "%s belongs to one declared authored material role" % semantic_mesh.name)
		if role_index < 0:
			continue
		role_node_counts[role_index] = int(role_node_counts[role_index]) + 1
		role_material_ids[role_index][material.get_instance_id()] = true
		flat_study_bound = flat_study_bound or _material_uses_path_fragment(material, FLAT_STUDY_FRAGMENT)
		_check(not material.uv1_triplanar and not material.texture_repeat, "%s uses explicit non-repeating UV policy" % semantic_mesh.name)
		match role_index:
			0:
				_check(_texture_path(material.albedo_texture) == str(HERO_ATLAS_PATHS.albedo), "%s uses the exact 1024 runtime trim albedo" % semantic_mesh.name)
				_check(material.normal_enabled and _texture_path(material.normal_texture) == str(HERO_ATLAS_PATHS.normal), "%s uses the registered runtime normal" % semantic_mesh.name)
				_check(_texture_path(material.roughness_texture) == str(HERO_ATLAS_PATHS.roughness) and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED, "%s reads roughness from the standalone registered red channel" % semantic_mesh.name)
				_check(material.emission_enabled and _texture_path(material.emission_texture) == str(HERO_ATLAS_PATHS.emissive), "%s enables the bounded sparse-cyan runtime emission texture" % semantic_mesh.name)
			1:
				_check(
					material.albedo_color == Color(0.9, 0.88, 0.78, 1.0)
					and is_equal_approx(material.metallic, 0.08)
					and is_equal_approx(material.roughness, 0.58)
					and _material_has_no_texture_inputs(material),
					"%s uses the exact clean warm-ivory hull response" % semantic_mesh.name
				)
			2:
				_check(
					material.albedo_color == Color(0.035, 0.055, 0.06, 1.0)
					and is_equal_approx(material.metallic, 0.28)
					and is_equal_approx(material.roughness, 0.42)
					and _material_has_no_texture_inputs(material),
					"%s uses the exact restrained-graphite housing response" % semantic_mesh.name
				)
	for role_index in HERO_MATERIAL_ROLE_ORDER.size():
		_check(int(role_node_counts[role_index]) == int(HERO_MATERIAL_ROLE_NODE_COUNTS[role_index]), "%s covers its exact two-LOD node count" % HERO_MATERIAL_ROLE_ORDER[role_index])
		_check(role_material_ids[role_index].size() == 1, "%s shares exactly one stable embedded material identity" % HERO_MATERIAL_ROLE_ORDER[role_index])
	var all_material_ids: Dictionary = {}
	for ids: Dictionary in role_material_ids:
		for material_id: Variant in ids:
			all_material_ids[material_id] = true
	_check(all_material_ids.size() == 3, "the authored macroform uses exactly three distinct stable material identities")
	_check(not flat_study_bound, "the unverified flat material study is not bound anywhere on the authored macroform")


func _hero_material_role_index(component_name: String) -> int:
	for role_index in HERO_MATERIAL_ROLE_MEMBERS.size():
		if component_name in HERO_MATERIAL_ROLE_MEMBERS[role_index]:
			return role_index
	return -1


func _material_has_no_texture_inputs(material: StandardMaterial3D) -> bool:
	return (
		material.albedo_texture == null
		and material.metallic_texture == null
		and material.roughness_texture == null
		and not material.normal_enabled
		and material.normal_texture == null
		and not material.ao_enabled
		and material.ao_texture == null
		and not material.emission_enabled
		and material.emission_texture == null
	)


func _texture_path(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else ""


func _material_uses_path_fragment(material: StandardMaterial3D, fragment: String) -> bool:
	for texture: Texture2D in [
		material.albedo_texture,
		material.normal_texture,
		material.roughness_texture,
		material.emission_texture,
		material.ao_texture,
		material.metallic_texture,
	]:
		if texture != null and fragment in texture.resource_path:
			return true
	return false


func _test_cockpit_canopy_and_contracts(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := visual.get_node_or_null("CanopyHinge") as Node3D
	var presentation := visual.get_node_or_null("TorrentHeroPresentation") as TorrentHeroPresentation
	_check(cockpit != null and canopy != null, "functional cockpit and canopy remain in the Torrent hierarchy")
	var blender_cockpit := visual.find_child("CockpitArt", true, false) as Node3D
	var blender_canopy := presentation.get_canopy_pivot() if presentation != null else null
	var legacy_cockpit := cockpit.get_node_or_null("LegacyCockpitArt") as Node3D
	var legacy_canopy := canopy.get_node_or_null("LegacyCanopyArt") as Node3D
	_check(blender_cockpit != null and blender_cockpit.visible, "one Blender cockpit presentation remains active inside its audited import hierarchy")
	_check(legacy_cockpit != null and not legacy_cockpit.visible, "legacy cockpit meshes remain a hidden fallback instead of double-rendering")
	_check(legacy_canopy != null and not legacy_canopy.visible, "legacy canopy cage remains a hidden fallback")
	_check(blender_cockpit != null and blender_cockpit.get_node_or_null("CrimsonSeatPan") is MeshInstance3D, "authored close cockpit retains the recognisable red seat")
	_check(blender_cockpit != null and blender_cockpit.get_node_or_null("PrimaryDisplay") is MeshInstance3D, "authored close cockpit owns the primary display")
	var art_manifest := _read_json("res://assets/models/torrent/hero/torrent_hero_asset_manifest.json")
	var art_batching := art_manifest.get("runtime_static_batching", {}) as Dictionary
	var cockpit_batches := (art_batching.get("batch_member_map", {}) as Dictionary).get(
		"CockpitArt", {}
	) as Dictionary
	var canopy_batches := (art_batching.get("batch_member_map", {}) as Dictionary).get(
		"CanopyPivot", {}
	) as Dictionary
	_check(
		blender_cockpit != null
		and _batch_members_contain(cockpit_batches, "ControlStick")
		and _batch_members_contain(cockpit_batches, "ThrottleLever"),
		"authored close cockpit retains both flight controls through export-only batching"
	)
	_check(
		blender_canopy != null
		and blender_canopy.get_node_or_null("CanopyGlass") is MeshInstance3D
		and _batch_members_contain(canopy_batches, "PortCanopySill")
		and _batch_members_contain(canopy_batches, "StarboardCanopySill"),
		"imported canopy hierarchy retains the protected glass and paired source sills"
	)
	var anchor_before := torrent.get_pilot_seat_anchor().global_transform
	var entry_before := torrent.get_boarding_entry_transform()
	var boarding_before := torrent.get_boarding_position()
	var exit_before := torrent.get_exit_transform()
	var left_muzzle_before := (torrent.get_node("LeftMuzzle") as Marker3D).transform
	var right_muzzle_before := (torrent.get_node("RightMuzzle") as Marker3D).transform
	var hull_shape := (torrent.get_node("HullCollision") as CollisionShape3D).shape as BoxShape3D
	var wing_shape := (torrent.get_node("WingCollision") as CollisionShape3D).shape as BoxShape3D
	var upper_shape := (torrent.get_node("UpperSilhouetteCollision") as CollisionShape3D).shape as BoxShape3D
	var exact_collision_roster := true
	for collision_name in [
		"HullCollision", "WingCollision", "UpperSilhouetteCollision",
		"PortAftPropulsionCollision", "StarboardAftPropulsionCollision",
		"LowerGearCollision", "NoseGearCollision",
	]:
		exact_collision_roster = exact_collision_roster and torrent.get_node_or_null(collision_name) is CollisionShape3D
	_check(
		exact_collision_roster
		and hull_shape.size.is_equal_approx(Vector3(4.6, 2.35, 9.0))
		and wing_shape.size.is_equal_approx(Vector3(7.2, 1.5, 6.3))
		and upper_shape.size.is_equal_approx(Vector3(4.75, 1.75, 6.0))
		and (torrent.get_node("UpperSilhouetteCollision") as CollisionShape3D).position.is_equal_approx(Vector3(0.0, 2.85, 0.85)),
		"modern close art uses the exact bounded seven-shape body, propulsion, and gear collision envelopes"
	)
	torrent.set_canopy_open(true, 0.0)
	_check(torrent.is_canopy_open() and canopy.rotation.x > 0.8 and blender_canopy != null and blender_canopy.rotation.x > 0.8, "functional canopy motion drives the complete imported canopy about the authored hinge")
	torrent.set_canopy_open(false, 0.0)
	_check(not torrent.is_canopy_open() and absf(canopy.rotation.x) < 0.01 and blender_canopy != null and absf(blender_canopy.rotation.x) < 0.01, "canopy reseals atomically without rebuilding functional nodes")
	_check(torrent.get_pilot_seat_anchor().global_transform.is_equal_approx(anchor_before), "pilot seat anchor transform is preserved")
	_check(torrent.get_boarding_entry_transform().is_equal_approx(entry_before), "boarding-entry transform is preserved")
	_check(torrent.get_boarding_position().is_equal_approx(boarding_before) and torrent.get_exit_transform().is_equal_approx(exit_before), "boarding and exit marker transforms are preserved")
	_check((torrent.get_node("LeftMuzzle") as Marker3D).transform.is_equal_approx(left_muzzle_before) and (torrent.get_node("RightMuzzle") as Marker3D).transform.is_equal_approx(right_muzzle_before), "weapon marker transforms are preserved")


func _test_variant_seams() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_test_root.add_child(arrow)
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	_check(arrow.get_arrow_visual_root() != null and arrow.get_arrow_visual_root().name == &"ArrowReconVisual", "Arrow still replaces the enhanced Torrent presentation")
	_check(arrow.get_node_or_null("TorrentVisual") == null and arrow.get_node_or_null("ArrowHullCollision") is CollisionShape3D, "Arrow replacement seam does not retain Torrent exterior or collision")
	_check(jovian.get_jovian_visual_root() != null and jovian.get_jovian_visual_root().name == &"JovianFreighterVisual", "Jovian still replaces the enhanced Torrent presentation")
	_check(jovian.get_node_or_null("TorrentVisual") == null and jovian.get_node_or_null("CargoDeckCollision") is CollisionShape3D, "Jovian replacement seam retains its dedicated collision/interior")
	_check(arrow.get_pilot_seat_anchor() != null and jovian.get_pilot_seat_anchor() != null, "both subclasses retain inherited cockpit anchor APIs")
	arrow.queue_free()
	jovian.queue_free()
	await process_frame


func _material_emits(material: Material) -> bool:
	return material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled


func _batch_members_contain(batches: Dictionary, member_name: String) -> bool:
	for members_value: Variant in batches.values():
		if members_value is Array and (members_value as Array).has(member_name):
			return true
	return false


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_HERO_ART_TEST_OK")
		quit(0)
	else:
		print("TORRENT_HERO_ART_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
