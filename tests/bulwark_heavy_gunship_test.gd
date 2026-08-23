extends SceneTree

const Ship := preload("res://scripts/ships/bulwark_heavy_gunship.gd")

var _checks := 0
var _failures := 0
var _root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_root = Node3D.new()
	_root.name = "BulwarkHeavyGunshipTestRoot"
	root.add_child(_root)
	var ship := Ship.new() as HeroShip
	_check(ship != null, "Bulwark component instantiates without a berth or world scene")
	if ship == null:
		_finish()
		return
	_root.add_child(ship)
	await process_frame
	await physics_frame
	await physics_frame

	_test_definition_and_evidence(ship)
	_test_physical_crew_contract(ship)
	_test_collision_and_authority_audit(ship)
	_test_base_lifecycle(ship)
	_finish()


func _test_definition_and_evidence(ship: HeroShip) -> void:
	var definition := ship.get_ship_definition()
	_check(definition != null and definition.is_definition_valid(), "Bulwark owns a valid ShipDefinition")
	if definition == null:
		return
	_check(definition.get_ship_id() == &"bulwark_heavy_gunship", "definition exposes a stable Bulwark ID")
	_check(definition.get_role() == "Heavy gunship", "definition declares the heavy gunship role")
	_check(definition.evidence_status == ShipDefinition.EvidenceStatus.NEW, "definition uses EvidenceStatus.NEW")
	_check(definition.get_evidence_status_id() == &"new", "definition publishes the new evidence status")
	_check(definition.evidence_references.is_empty(), "new design has no historical evidence references")
	_check(not definition.is_historical_claim(), "new design does not make a historical claim")
	_check("no historical" in definition.evidence_notes, "definition explicitly limits historical claims")
	var evidence: Dictionary = ship.call("get_bulwark_evidence_report")
	_check(str(evidence.get("evidence_scope", "")) == "original_modern_design", "evidence scope is original modern design")
	_check(not bool(evidence.get("authenticated_geometry", true)), "evidence report denies authenticated geometry")
	_check(not bool(evidence.get("historical_claim", true)), "evidence report denies historical claims")
	_check((evidence.get("creator_supported", PackedStringArray()) as PackedStringArray).is_empty(), "evidence report has no creator-supported facts")
	_check((evidence.get("modern_original", PackedStringArray()) as PackedStringArray).size() >= 3, "evidence report inventories original design choices")


func _test_physical_crew_contract(ship: HeroShip) -> void:
	var pilot := ship.get_pilot_seat_anchor()
	_check(pilot != null and pilot.get_meta("crew_role", &"") == &"pilot", "inherited physical cockpit seat remains the pilot role")
	_check(pilot != null and pilot.get_meta("seat_type", &"") == &"physical", "pilot seat is a physical ship-local anchor")
	var boarding := ship.get_node_or_null("BoardingPoint") as Marker3D
	_check(boarding != null and boarding.position.is_finite(), "boarding point is a finite ship-local marker")
	var boarding_area := ship.get_node_or_null("BulwarkBoardingArea") as Area3D
	_check(boarding_area != null and boarding_area.get_child_count() == 1 and boarding_area.get_child(0) is CollisionShape3D, "boarding interaction has a physical volume")
	var contract: Dictionary = ship.call("get_gunner_station_role_contract")
	_check(contract.get("role", &"") == &"gunner", "gunner station publishes the gunner role")
	_check(contract.get("seat_type", &"") == &"physical", "gunner role uses a physical seat anchor")
	_check(contract.get("seat") == ship.call("get_gunner_station_anchor"), "gunner contract returns its stable anchor")
	_check(contract.get("authority_owner", &"") == &"HeroShip.weapon_request", "gunner contract delegates weapon authority to HeroShip")
	_check(bool(contract.get("visual_only_weapon_fit", false)), "gunner geometry cannot become a second combat authority")


func _test_collision_and_authority_audit(ship: HeroShip) -> void:
	var visual := ship.get_node_or_null("BulwarkHeavyGunshipVisual") as Node3D
	_check(visual != null and visual.get_node_or_null("ArmoredCentralSlab") is MeshInstance3D, "armored central slab is a real visual mesh")
	_check(visual != null and visual.get_node_or_null("PortArmoredShoulder") is MeshInstance3D, "port armored shoulder differentiates the silhouette")
	_check(visual != null and visual.get_node_or_null("StarboardArmoredShoulder") is MeshInstance3D, "starboard armored shoulder differentiates the silhouette")
	_test_identity_band_batch(visual)
	var audit: Dictionary = ship.call("get_bulwark_audit_report")
	_check(bool(audit.get("valid", false)), "fully constructed Bulwark passes its public audit")
	_check(int(audit.get("collision_shape_count", 0)) >= 3, "audit sees the armored collision envelope")
	_check(audit.get("silhouette_role", &"") == &"armored_broad_shoulders", "audit records the differentiated armored silhouette")
	_check(audit.get("color_role", &"") == &"slate_blue_amber", "audit records the differentiated color role")
	_check(audit.get("combat_authority", &"") == &"HeroShip", "audit preserves one combat authority")
	_check(audit.get("lifecycle_authority", &"") == &"HeroShip", "audit preserves one lifecycle authority")
	_check(not bool(audit.get("world_or_berth_registered", true)), "component remains unregistered with world and berth")
	_check(not bool(ship.get_meta("authenticated_historical_silhouette", true)), "root metadata denies historical silhouette authentication")


func _test_identity_band_batch(visual: Node3D) -> void:
	var batch := visual.get_node_or_null("IdentityBandBatch") as MultiMeshInstance3D \
		if visual != null else null
	var multi := batch.multimesh if batch != null else null
	_check(
		multi != null
		and multi.transform_format == MultiMesh.TRANSFORM_3D
		and multi.instance_count == 2
		and multi.visible_instance_count == -1
		and multi.mesh != null
		and multi.mesh.get_surface_count() == 1,
		"two amber identity-band copies retain one bounded renderer submission"
	)
	if multi == null:
		return
	var transforms: Array = batch.get_meta(&"authored_instance_transforms", []) as Array
	var names := batch.get_meta(&"authored_visual_names", PackedStringArray()) as PackedStringArray
	_check(
		transforms == [
			Transform3D(Basis.IDENTITY, Vector3(-4.18, 1.55, -0.2)),
			Transform3D(Basis.IDENTITY, Vector3(4.18, 1.55, -0.2)),
		]
		and names == PackedStringArray(["PortIdentityBand", "StarboardIdentityBand"]),
		"identity-band authored transforms and inspection names remain exact"
	)
	var material := multi.mesh.surface_get_material(0) as StandardMaterial3D
	var mesh_bounds := multi.mesh.get_aabb()
	var first_transform: Transform3D = transforms[0] as Transform3D
	var second_transform: Transform3D = transforms[1] as Transform3D
	var expected_bounds: AABB = (first_transform * mesh_bounds).abs().merge(
		(second_transform * mesh_bounds).abs()
	)
	_check(
		material != null
		and material.albedo_color.is_equal_approx(Color("e2a63c"))
		and is_equal_approx(material.metallic, 0.52)
		and is_equal_approx(material.roughness, 0.31)
		and mesh_bounds.size.is_equal_approx(Vector3(0.16, 1.25, 3.2))
		and multi.custom_aabb.is_equal_approx(expected_bounds)
		and batch.material_override == null
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"identity-band mesh, material, culling bounds/layer, and shadow behavior remain exact"
	)
	_check(
		visual.get_node_or_null("PortIdentityBand") == null
		and visual.get_node_or_null("StarboardIdentityBand") == null,
		"legacy identity-band renderer submissions are removed"
	)
	print("BULWARK_IDENTITY_BAND_BATCH: visible_copies 2->2 submissions 2->1")


func _test_base_lifecycle(ship: HeroShip) -> void:
	var first_reset := ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, 6.0)))
	_check(bool(first_reset.get("accepted", false)), "Bulwark accepts the inherited exactly-once reuse transaction")
	_check(ship.global_position.is_equal_approx(Vector3(4.0, 2.0, 6.0)), "inherited reuse lifecycle applies the spawn transform")
	var second_reset := ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(8.0, 2.0, 6.0)))
	_check(bool(second_reset.get("accepted", false)), "a later reuse transaction remains independently accepted")
	_check(ship.global_position.is_equal_approx(Vector3(8.0, 2.0, 6.0)), "later reuse does not retain stale placement state")


func _finish() -> void:
	print("BULWARK_HEAVY_GUNSHIP: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
