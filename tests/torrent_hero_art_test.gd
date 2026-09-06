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
	_test_render_allocations(torrent)
	await _test_cockpit_canopy_and_contracts(torrent)
	await _test_detached_presentation_adapter_reentry(torrent)
	await _test_stale_presentation_adapter_recovery(torrent)
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
	_check(
		str(audit.identity_lock) == "b5_observed_name_to_model"
		and str(audit.historical_revision) == "unverified"
		and str(audit.source_upload_date) == "2011-06-29"
		and str(audit.recording_date_status) == "unknown"
		and str(audit.game_build_revision_status) == "unknown",
		"art audit separates the B5-observed identity from unknown recording/build provenance"
	)
	_check(str(audit.reconstruction_status) == "partial" and str(audit["2009_continuity"]) == "unproved", "art audit keeps reconstruction detail partial and 2009 continuity unproved")
	_check(str(audit.geometry_status) == "source_aligned_partial" and not bool(audit.authenticated_geometry), "art audit makes no unsupported authenticated-geometry claim")
	var fallback := audit.get("far_fallback_reconstruction", {}) as Dictionary
	var close_art := audit.get("close_presentation", {}) as Dictionary
	_check(bool(fallback.get("valid", false)), "art audit retains one independently valid B5-observed far/fallback macroform")
	_check(bool(close_art.get("valid", false)) and int(close_art.get("lod0_triangle_count", 0)) >= 45000 and int(close_art.get("near_surface_count", 999)) <= 32, "art audit requires dense Blender close geometry within its draw-surface budget")
	_check(int(fallback.get("engine_assembly_count", 0)) == 2 and int(fallback.get("landing_gear_assembly_count", 0)) == 3, "fallback audit retains twin engines and tricycle gear")
	_check(int(fallback.get("rcs_cluster_count", 0)) == 4 and int(fallback.get("service_panel_count", 0)) >= 4, "fallback audit inventories RCS clusters and service access panels")
	_check(int(fallback.get("mapped_hull_material_count", 0)) == 2, "both fallback hull material families keep their registered maps")
	var render_allocations := fallback.get("render_allocations", {}) as Dictionary
	_check(bool(render_allocations.get("valid", false)) and bool(render_allocations.get("exact_counts", false)), "fallback audit includes a clean component-local render-allocation contract")


func _test_airframe_and_surface_materials(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	_check(visual != null and visual.name == &"TorrentVisual", "Torrent keeps its stable visual-root seam")
	_check(str(visual.get_meta("geometry_status", "")) == "source_aligned_partial", "visual root records source-aligned partial geometry status")
	_check(str(visual.get_meta("identity_lock", "")) == "b5_observed_name_to_model", "visual root carries the B5-observed identity lock")
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
	_check(pointed_nose != null and pointed_nose.mesh is ArrayMesh, "B5-observed macroform begins with an imported authored pointed mesh")
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
	_check(side_planes.size() == 4, "B5-observed macroform has exactly four stepped side-plane tiers")
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
	var jaws := docking_receiver.find_children("CaptureJaw*", "MeshInstance3D", false, false) if docking_receiver != null else []
	var shared_jaw_mesh: Mesh = null
	var jaw_contract_matches := jaws.size() == HeroShip.TORRENT_CAPTURE_JAW_COPY_COUNT
	for jaw_index in HeroShip.TORRENT_CAPTURE_JAW_COPY_COUNT:
		var jaw := docking_receiver.get_node_or_null("CaptureJaw%02d" % jaw_index) as MeshInstance3D if docking_receiver != null else null
		var jaw_angle := TAU * float(jaw_index) / 4.0
		jaw_contract_matches = jaw_contract_matches and (
			jaw != null
			and jaw.position.is_equal_approx(Vector3(cos(jaw_angle) * 0.46, -0.08, sin(jaw_angle) * 0.46))
			and jaw.rotation.is_equal_approx(Vector3(0.0, -jaw_angle, 0.0))
			and jaw.material_override == null
			and jaw.mesh != null
			and jaw.mesh.get_surface_count() == 1
			and jaw.mesh.surface_get_material(0) == torrent.get_variant_materials().get("gold")
		)
		if shared_jaw_mesh == null and jaw != null:
			shared_jaw_mesh = jaw.mesh
		elif jaw != null:
			jaw_contract_matches = jaw_contract_matches and jaw.mesh == shared_jaw_mesh
	_check(jaw_contract_matches, "four capture jaws retain their authored paths/transforms and share one gold rounded-box mesh")
	_check(modern_systems != null and modern_systems.find_children("*RCSCluster", "Node3D", true, false).size() == 4, "four presentation-only RCS clusters are visible")
	_check(modern_systems != null and modern_systems.find_children("*DorsalVentBank", "Node3D", true, false).size() == 2, "paired louvred vent banks service the aft fuselage")
	_test_compact_pulse_cannons(torrent, modern_systems)


func _test_compact_pulse_cannons(torrent: HeroShip, modern_systems: Node3D) -> void:
	var weapons := modern_systems.get_node_or_null("Weapons") as Node3D if modern_systems != null else null
	_check(
		weapons != null
		and str(weapons.get_meta("weapon_class", "")) == "compact_twin_pulse_cannon"
		and str(weapons.get_meta("mount_scale", "")) == "interceptor_light",
		"Torrent carries one interceptor-scale compact twin pulse-cannon battery"
	)
	if weapons == null:
		return
	var source_core := torrent.get_variant_visual_root().find_child("SourceCore", true, false)
	_check(
		weapons.get_parent() == modern_systems
		and (source_core == null or not source_core.is_ancestor_of(weapons))
		and str(weapons.get_meta("evidence_status", "")) == "modern_interpretation"
		and not bool(weapons.get_meta("historically_supported", true)),
		"unsupported weapon geometry remains modern presentation outside SourceCore"
	)
	_check(
		weapons.find_children("*GunRail", "MeshInstance3D", false, false).size() == 2
		and weapons.find_children("*PulseCannon", "MeshInstance3D", false, false).size() == 2
		and weapons.find_children("*CannonShroud", "MeshInstance3D", false, false).size() == 2
		and weapons.find_children("*MuzzleCollar", "MeshInstance3D", false, false).size() == 2
		and weapons.find_children("*MuzzleLens", "MeshInstance3D", false, false).size() == 2,
		"compact battery has two complete rail, cannon, shroud, collar and muzzle-lens sets"
	)
	for side_name: String in ["Port", "Starboard"]:
		var marker_name := "LeftMuzzle" if side_name == "Port" else "RightMuzzle"
		var marker := torrent.get_node_or_null(marker_name) as Marker3D
		var rail := weapons.get_node_or_null(side_name + "GunRail") as MeshInstance3D
		var cannon := weapons.get_node_or_null(side_name + "PulseCannon") as MeshInstance3D
		var shroud := weapons.get_node_or_null(side_name + "CannonShroud") as MeshInstance3D
		var collar := weapons.get_node_or_null(side_name + "MuzzleCollar") as MeshInstance3D
		var lens := weapons.get_node_or_null(side_name + "MuzzleLens") as MeshInstance3D
		var complete := marker != null and rail != null and cannon != null and shroud != null and collar != null and lens != null
		_check(complete, "%s compact pulse-cannon detail resolves by stable semantic names" % side_name)
		if not complete:
			continue
		_check(
			is_equal_approx(rail.position.x, marker.position.x)
			and is_equal_approx(cannon.position.x, marker.position.x)
			and is_equal_approx(shroud.position.x, marker.position.x)
			and is_equal_approx(collar.position.x, marker.position.x)
			and is_equal_approx(lens.position.x, marker.position.x)
			and is_equal_approx(lens.position.y, marker.position.y)
			and marker.position.z < lens.position.z
			and lens.position.z - marker.position.z < 0.03,
			"%s cannon is coaxial with its unchanged functional muzzle marker" % side_name
		)
		_check(
			shroud.mesh.get_aabb().size.x < 0.4
			and collar.mesh.get_aabb().size.x < shroud.mesh.get_aabb().size.x
			and lens.mesh.get_aabb().size.x < cannon.mesh.get_aabb().size.x
			and cannon.mesh.get_aabb().size.y < rail.mesh.get_aabb().size.z,
			"%s weapon shroud, collar and lens retain a compact interceptor-relative profile" % side_name
		)
		for weapon_part in [rail, cannon, shroud, collar, lens]:
			_check(
				bool(weapon_part.get_meta("presentation_only", false))
				and str(weapon_part.get_meta("weapon_class", "")) == "compact_pulse_cannon"
				and str(weapon_part.get_meta("mount_scale", "")) == "interceptor_light"
				and str(weapon_part.get_meta("evidence_status", "")) == "modern_interpretation"
				and not bool(weapon_part.get_meta("historically_supported", true)),
				"%s is explicitly bounded as modern interceptor weapon presentation" % weapon_part.name
			)


func _test_render_allocations(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	var modern := visual.get_node_or_null("LegacyFarPresentation/ModernSystems") as Node3D if visual != null else null
	_check(modern != null, "Torrent retains its modern fallback root for local render auditing")
	if modern == null:
		return
	var expected_transforms: Array[Transform3D] = []
	var louver_basis := Basis.from_euler(Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	for louver_index in HeroShip.TORRENT_VENT_LOUVERS_PER_BANK:
		expected_transforms.append(Transform3D(
			louver_basis,
			Vector3(0.0, 0.055, -0.43 + float(louver_index) * 0.17)
		))
	var expected_names := PackedStringArray([
		"VentLouver00", "VentLouver01", "VentLouver02",
		"VentLouver03", "VentLouver04", "VentLouver05",
	])
	var batches: Array[MultiMeshInstance3D] = []
	var shared_mesh: Mesh = null
	for side_name: String in ["Port", "Starboard"]:
		var bank := modern.get_node_or_null(side_name + "DorsalVentBank") as Node3D
		var batch := bank.get_node_or_null("VentLouvers") as MultiMeshInstance3D if bank != null else null
		_check(bank != null and batch != null and batch.multimesh != null, "%s vent bank retains one bank-local louvre batch" % side_name)
		if batch == null or batch.multimesh == null:
			continue
		batches.append(batch)
		var multi := batch.multimesh
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		var transforms_match := authored.size() == expected_transforms.size()
		for index in mini(authored.size(), expected_transforms.size()):
			transforms_match = transforms_match and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
		_check(
			multi.instance_count == HeroShip.TORRENT_VENT_LOUVERS_PER_BANK
			and multi.visible_instance_count == HeroShip.TORRENT_VENT_LOUVERS_PER_BANK
			and transforms_match
			and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names,
			"%s batch preserves all six authored louvre copies, transforms, order and visual names" % side_name
		)
		_check(
			multi.mesh != null
			and multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.54, 0.045, 0.065))
			and multi.mesh.get_surface_count() == 1
			and multi.mesh.surface_get_material(0) == torrent.get_variant_materials().get("dark")
			and batch.material_override == null
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1,
			"%s batch preserves louvre extent, surface material identity, shadows and render layer" % side_name
		)
		_check(
			batch.get_child_count() == 0
			and batch.get_script() == null
			and batch.get_groups().is_empty()
			and bool(batch.get_meta("visual_detail_only", false))
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
			and batch.find_children("*", "Area3D", true, false).is_empty(),
			"%s batch remains childless, visual-only, non-colliding and without authority" % side_name
		)
		if shared_mesh == null:
			shared_mesh = multi.mesh
		else:
			_check(multi.mesh == shared_mesh, "both bank-local batches share one immutable louvre mesh")
	_check(
		batches.size() == 2
		and modern.find_children("VentLouver*", "MeshInstance3D", true, false).is_empty(),
		"only the twelve generic louvre leaves retire; both named bank roots remain"
	)

	var expected_rcs_names := PackedStringArray(["ThrusterPort00", "ThrusterPort01"])
	var rcs_batches: Array[MultiMeshInstance3D] = []
	var rcs_shared_mesh: Mesh = null
	for side_name: String in ["Port", "Starboard"]:
		var side := -1.0 if side_name == "Port" else 1.0
		var expected_rcs_transforms: Array[Transform3D] = []
		var port_basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(90.0)))
		for port_index in HeroShip.TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER:
			expected_rcs_transforms.append(Transform3D(
				port_basis,
				Vector3(side * 0.28, 0.07 - float(port_index) * 0.15, -0.1 + float(port_index) * 0.2)
			))
		for station_name: String in ["Forward", "Aft"]:
			var cluster := modern.get_node_or_null(side_name + station_name + "RCSCluster") as Node3D
			var batch := cluster.get_node_or_null("ThrusterPorts") as MultiMeshInstance3D if cluster != null else null
			_check(cluster != null and batch != null and batch.multimesh != null, "%s %s RCS cluster retains its local port batch" % [side_name, station_name])
			if batch == null or batch.multimesh == null:
				continue
			rcs_batches.append(batch)
			var authored := batch.get_meta("authored_instance_transforms", []) as Array
			var transforms_match := authored.size() == expected_rcs_transforms.size()
			for index in mini(authored.size(), expected_rcs_transforms.size()):
				transforms_match = transforms_match and (authored[index] as Transform3D).is_equal_approx(expected_rcs_transforms[index])
			_check(
				batch.get_parent() == cluster
				and batch.multimesh.instance_count == HeroShip.TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER
				and batch.multimesh.visible_instance_count == HeroShip.TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER
				and transforms_match
				and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_rcs_names
				and batch.multimesh.mesh.get_surface_count() == 1
				and batch.multimesh.mesh.surface_get_material(0) == torrent.get_variant_materials().get("thermal")
				and batch.material_override == null
				and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and batch.layers == 1
				and batch.get_child_count() == 0
				and bool(batch.get_meta("visual_detail_only", false))
				and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"%s %s RCS batch preserves its exact visual copies, material and presentation-only boundary" % [side_name, station_name]
			)
			if rcs_shared_mesh == null:
				rcs_shared_mesh = batch.multimesh.mesh
			else:
				_check(batch.multimesh.mesh == rcs_shared_mesh, "all RCS port batches share one immutable thermal mesh")
	_check(
		rcs_batches.size() == 4
		and modern.find_children("ThrusterPort*", "MeshInstance3D", true, false).is_empty(),
		"only eight generic RCS port leaves retire; all four cluster roots remain"
	)

	var service_panel_mesh: Mesh = null
	for side_name: String in ["Port", "Starboard"]:
		var side := -1.0 if side_name == "Port" else 1.0
		var panel := modern.get_node_or_null(
			side_name + "FuselageServicePanel"
		) as MeshInstance3D
		_check(
			panel != null
			and panel.position.is_equal_approx(Vector3(side * 1.62, 1.79, -2.55))
			and panel.rotation.is_equal_approx(
				Vector3(0.0, 0.0, side * deg_to_rad(-5.0))
			)
			and panel.mesh != null
			and panel.mesh.get_aabb().size.is_equal_approx(Vector3(0.72, 0.055, 1.08))
			and panel.mesh.get_surface_count() == 1
			and panel.mesh.surface_get_material(0) == torrent.get_variant_materials().panel
			and panel.material_override == null
			and panel.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and panel.layers == 1
			and panel.get_child_count() == 0
			and panel.get_script() == null,
			"%s service cover retains its exact transform, panel material, shadows and childless visual boundary" % side_name
		)
		if panel == null:
			continue
		if service_panel_mesh == null:
			service_panel_mesh = panel.mesh
		else:
			_check(
				panel.mesh == service_panel_mesh,
				"paired fuselage service covers share one immutable mesh"
			)

	var report := torrent.get_torrent_render_allocation_report()
	var component := report.get("component", {}) as Dictionary
	var fallback := report.get("modern_fallback", {}) as Dictionary
	_check(
		int(component.get("descendant_nodes", -1)) == 295
		and int(component.get("mesh_instances", -1)) == 233
		and int(component.get("multimesh_batches", -1)) == 6,
		"Torrent-local renderer census batches eight RCS ports while retaining named clusters"
	)
	_check(
		int(component.get("drawn_copies", -1)) == 253
		and int(component.get("geometry_submissions", -1)) == 239
		and int(component.get("unique_mesh_resources", -1)) == 208
		and int(component.get("unique_material_resources", -1)) == 37,
		"service-panel sharing removes one mesh allocation while preserving all visible copies and submissions"
	)
	_check(
		int(fallback.get("descendant_nodes", -1)) == 109
		and int(fallback.get("mesh_instances", -1)) == 87
		and int(fallback.get("multimesh_batches", -1)) == 6
		and int(fallback.get("drawn_copies", -1)) == 107
		and int(fallback.get("geometry_submissions", -1)) == 93,
		"modern-fallback census batches only the eight visual RCS port copies"
	)
	_check(
		int(report.get("vent_louver_batches", -1)) == 2
		and int(report.get("vent_louver_copies", -1)) == 12
		and int(report.get("vent_louver_shared_mesh_resources", -1)) == 1
		and int(report.get("renderer_buffer_floats", -1)) == 144
		and bool(report.get("renderer_buffer_matches_authored", false))
		and bool(report.get("bounds_match_authored", false))
		and bool(report.get("mesh_material_matches_authored", false))
		and bool(report.get("batch_contract_matches", false))
		and int(report.get("capture_jaw_copies", -1)) == 4
		and int(report.get("capture_jaw_shared_mesh_resources", -1)) == 1
		and bool(report.get("capture_jaw_contract_matches", false))
		and int(report.get("rcs_thruster_port_batches", -1)) == 4
		and int(report.get("rcs_thruster_port_copies", -1)) == 8
		and int(report.get("rcs_thruster_port_shared_mesh_resources", -1)) == 1
		and bool(report.get("rcs_thruster_port_contract_matches", false))
		and int(report.get("fuselage_service_panel_copies", -1)) == 2
		and int(report.get("fuselage_service_panel_shared_mesh_resources", -1)) == 1
		and bool(report.get("fuselage_service_panel_contract_matches", false))
		and bool(report.get("exact_counts", false)),
		"louvre, capture-jaw, RCS-port and service-panel families preserve their visual contracts with immutable shared resources"
	)

	var detached := report.get("authored_bank_transforms", []) as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((torrent.get_torrent_render_allocation_report().authored_bank_transforms as Array)[0] as Transform3D).is_equal_approx(Transform3D.IDENTITY),
		"render report returns a detached authored-transform roster"
	)
	if batches.is_empty():
		return
	var multi := batches[0].multimesh
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		(torrent.get_torrent_reconstruction_audit_report().errors as PackedStringArray).has(
			"Torrent dorsal vent-louver renderer buffer drifted from its authored transforms"
		),
		"RED: mutating one live louvre transform is rejected by the Torrent audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		(torrent.get_torrent_reconstruction_audit_report().errors as PackedStringArray).has(
			"Torrent dorsal vent-louver culling bounds drifted from its authored copies"
		),
		"RED: mutating one bank's explicit culling union is rejected by the Torrent audit"
	)
	multi.custom_aabb = original_bounds
	var docking_receiver := modern.get_node_or_null("VentralDockingReceiver") as Node3D
	var capture_jaw := docking_receiver.get_node_or_null("CaptureJaw00") as MeshInstance3D if docking_receiver != null else null
	var original_jaw_mesh := capture_jaw.mesh if capture_jaw != null else null
	if capture_jaw != null:
		capture_jaw.mesh = SphereMesh.new()
	_check(
		(torrent.get_torrent_reconstruction_audit_report().errors as PackedStringArray).has(
			"Torrent capture-jaw mesh-sharing contract drifted"
		),
		"RED: replacing one capture jaw mesh is rejected by the Torrent allocation audit"
	)
	if capture_jaw != null:
		capture_jaw.mesh = original_jaw_mesh
	_check(
		bool(torrent.get_torrent_reconstruction_audit_report().valid),
		"restoring the exact batch payload and capture-jaw mesh restores a clean Torrent reconstruction audit"
	)


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
	var readout := cockpit.get_node_or_null("FlightDataReadout") as Label3D
	var screen := blender_cockpit.get_node_or_null("PrimaryDisplay") as MeshInstance3D
	await process_frame
	var text_on_screen := readout != null and screen != null
	if text_on_screen:
		var screen_bounds := screen.get_aabb()
		for corner in 8:
			var point := screen.to_local(readout.to_global(readout.get_aabb().get_endpoint(corner)))
			text_on_screen = text_on_screen \
				and point.x >= screen_bounds.position.x and point.x <= screen_bounds.end.x \
				and point.y >= screen_bounds.position.y and point.y <= screen_bounds.end.y \
				and point.z > screen_bounds.end.z and point.z < screen_bounds.end.z + 0.01
	_check(text_on_screen, "live three-line telemetry fits on the imported physical screen face")
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
	var imported_glass := blender_canopy.get_node_or_null("CanopyGlass") as MeshInstance3D \
		if blender_canopy != null else null
	var imported_glass_material := imported_glass.material_override as StandardMaterial3D \
		if imported_glass != null else null
	var cockpit_camera := cockpit.get_node_or_null("CockpitCamera") as Camera3D \
		if cockpit != null else null
	var chase_camera := torrent.get_camera()
	_check(
		TorrentHeroPresentation.EXTERIOR_CANOPY_VISUAL_LAYER_MASK == (1 << 17)
			and imported_glass_material != null
			and imported_glass_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
			and imported_glass != null
			and imported_glass.layers == TorrentHeroPresentation.EXTERIOR_CANOPY_VISUAL_LAYER_MASK
			and cockpit_camera != null
			and (cockpit_camera.cull_mask & TorrentHeroPresentation.EXTERIOR_CANOPY_VISUAL_LAYER_MASK) == 0
			and chase_camera != null
			and (chase_camera.cull_mask & TorrentHeroPresentation.EXTERIOR_CANOPY_VISUAL_LAYER_MASK) != 0
			and (cockpit_camera.cull_mask ^ chase_camera.cull_mask)
				== TorrentHeroPresentation.EXTERIOR_CANOPY_VISUAL_LAYER_MASK,
		"imported glazing remains exterior-visible while the cockpit omits only its globally dedicated layer 18"
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


func _test_stale_presentation_adapter_recovery(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	var adapter := visual.get_node_or_null("TorrentHeroPresentation") as TorrentHeroPresentation if visual != null else null
	var legacy_far := visual.get_node_or_null("LegacyFarPresentation") as Node3D if visual != null else null
	var legacy_cockpit := visual.get_node_or_null("CockpitInterior/LegacyCockpitArt") as Node3D if visual != null else null
	var legacy_canopy := visual.get_node_or_null("CanopyHinge/LegacyCanopyArt") as Node3D if visual != null else null
	var readout := visual.get_node_or_null("CockpitInterior/FlightDataReadout") as Label3D if visual != null else null
	var practical := visual.get_node_or_null("CockpitInterior/CockpitPracticalLight") as SpotLight3D if visual != null else null
	_check(adapter != null and legacy_far != null and legacy_cockpit != null and legacy_canopy != null and readout != null and practical != null, "stale-adapter fixture resolves the live close adapter and every retained fallback overlay")
	if adapter == null or legacy_far == null or legacy_cockpit == null \
			or legacy_canopy == null or readout == null or practical == null:
		return
	adapter.queue_free()
	torrent.set_canopy_open(true, 0.0)
	_check(
		adapter.is_queued_for_deletion()
		and legacy_far.visible and legacy_cockpit.visible and legacy_canopy.visible
		and readout.visible and practical.visible,
		"queued Torrent adapter clears the cache before canopy sync and restores fallback overlay visibility"
	)
	await process_frame
	await physics_frame
	torrent.set_canopy_open(false, 0.0)
	_check(
		not is_instance_valid(adapter)
		and visual.get_node_or_null("TorrentHeroPresentation") == null
		and legacy_far.visible and legacy_cockpit.visible and legacy_canopy.visible
		and readout.visible and practical.visible,
		"freed Torrent adapter leaves frame, canopy, and overlay sync paths on the visible fallback without stale calls"
	)


func _test_detached_presentation_adapter_reentry(torrent: HeroShip) -> void:
	var visual := torrent.get_variant_visual_root()
	var adapter := visual.get_node_or_null("TorrentHeroPresentation") as TorrentHeroPresentation if visual != null else null
	var imported_canopy := adapter.get_canopy_pivot() if adapter != null else null
	var legacy_far := visual.get_node_or_null("LegacyFarPresentation") as Node3D if visual != null else null
	var legacy_cockpit := visual.get_node_or_null("CockpitInterior/LegacyCockpitArt") as Node3D if visual != null else null
	var legacy_canopy := visual.get_node_or_null("CanopyHinge/LegacyCanopyArt") as Node3D if visual != null else null
	var readout := visual.get_node_or_null("CockpitInterior/FlightDataReadout") as Label3D if visual != null else null
	var practical := visual.get_node_or_null("CockpitInterior/CockpitPracticalLight") as SpotLight3D if visual != null else null
	_check(adapter != null and imported_canopy != null and legacy_far != null and legacy_cockpit != null and legacy_canopy != null and readout != null and practical != null, "detached-adapter fixture resolves the retained close adapter and fallback overlays")
	if adapter == null or imported_canopy == null or legacy_far == null \
			or legacy_cockpit == null or legacy_canopy == null or readout == null or practical == null:
		return
	torrent.set_canopy_open(false, 0.0)
	_test_root.remove_child(torrent)
	await process_frame
	var reset := torrent.reset_for_reuse(Transform3D.IDENTITY)
	torrent.set_canopy_open(true, 0.0)
	_check(
		not torrent.is_inside_tree()
		and not bool(reset.get("accepted", true))
		and reset.get("reason") == &"ship_detached"
		and is_instance_valid(adapter) and adapter.get_parent() == visual and not adapter.is_inside_tree()
		and not legacy_far.visible and not legacy_cockpit.visible and not legacy_canopy.visible
		and readout.visible and practical.visible,
		"detached reset rejects before mutation while canopy sync preserves the valid retained adapter"
	)
	_test_root.add_child(torrent)
	await process_frame
	await physics_frame
	torrent.set_canopy_open(true, 0.0)
	var reopened := imported_canopy.rotation.x > 0.8
	torrent.set_canopy_open(false, 0.0)
	var audit := torrent.get_torrent_art_audit_report()
	_check(
		adapter.is_inside_tree()
		and visual.get_node_or_null("TorrentHeroPresentation") == adapter
		and reopened and absf(imported_canopy.rotation.x) < 0.01
		and adapter.get_active_lod() == 0
		and not legacy_far.visible and not legacy_cockpit.visible and not legacy_canopy.visible
		and readout.visible and practical.visible
		and bool(audit.get("valid", false)),
		"re-entry retains cached close presentation, restores canopy and close overlays, and passes the Torrent art audit"
	)


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
