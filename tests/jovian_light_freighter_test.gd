extends SceneTree

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "JovianLightFreighterTestRoot"
	root.add_child(_test_root)
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(jovian != null, "Jovian scene instantiates as JovianLightFreighter")
	if jovian == null:
		_finish()
		return
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	await physics_frame

	_test_definition_and_evidence(jovian)
	_test_defensive_weapon_visual(jovian)
	_test_load_mark_render_allocation(jovian)
	_test_dorsal_cargo_rib_joint_allocation(jovian)
	_test_shoulder_rail_joint_allocation(jovian)
	_test_cargo_frame_joint_allocation(jovian)
	_test_passenger_seat_mesh_allocation(jovian)
	_test_passenger_cabin_light_strip_allocation(jovian)
	await _test_scale_handling_and_presentation(jovian)
	_test_connected_interior_contract(jovian)
	_test_collision_access_and_cameras(jovian)
	_test_secured_freight_is_solid(jovian)
	await _test_physical_player_traversal(jovian)
	await _test_engine_weapon_damage_and_reuse(jovian)
	await _test_cleanup(jovian)
	_finish()


func _test_definition_and_evidence(jovian: JovianLightFreighter) -> void:
	var definition := jovian.get_ship_definition()
	_check(definition != null and definition.is_definition_valid(), "Jovian owns a valid ShipDefinition")
	if definition == null:
		return
	_check(definition.get_ship_id() == &"jovian_provisional", "definition exposes stable candidate ID")
	_check(definition.get_display_name() == "Jovian-class Light Freighter candidate", "display name cannot imply authenticated geometry")
	_check(definition.get_role() == "Light freighter", "creator-supported role is preserved")
	_check(definition.get_evidence_status_id() == &"provisional" and not definition.is_authenticated(), "definition explicitly remains provisional")
	_check(definition.evidence_references.size() >= 3, "definition cites roster, register, and regeneration label")
	_check("name and light-freighter role" in definition.evidence_notes, "definition limits supported facts to name and role")
	_check("no historical name-to-model mapping" in definition.evidence_notes, "definition denies unsupported visual mapping")
	for tag in ["medium_craft", "light_freighter", "freight", "cargo"]:
		_check(definition.compatibility_tags.has(tag), "definition declares %s berth compatibility" % tag)
	_check(jovian.get_home_berth_id() == &"jovian_freight_berth", "ship publishes the freight berth ID")
	_check(jovian.get_combat_source_id() == 1103, "ship publishes the stable Jovian combat source ID")
	var clearance := jovian.get_berth_clearance_report()
	_check(str(clearance.home_berth_id) == "jovian_freight_berth" and bool(clearance.provisional), "berth clearance report is stable and explicitly provisional")
	_check((clearance.ramp_local_direction as Vector3) == Vector3.LEFT, "berth contract exposes the port-ramp approach direction")
	var evidence := jovian.get_jovian_evidence_report()
	_check(str(evidence.evidence_scope) == "name_and_role_only", "craft audit narrowly scopes its evidence")
	_check(not bool(evidence.authenticated_geometry), "craft audit denies authenticated geometry")
	_check((evidence.creator_supported as PackedStringArray).size() == 2, "audit lists exactly two creator-supported fact categories")
	_check((evidence.modern_provisional as PackedStringArray).size() >= 5, "audit inventories provisional design categories")
	var audit := jovian.get_jovian_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "constructed Jovian passes its public audit")
	_check(str(audit.weapon_class) == "freighter_defensive_pulse" and int(audit.engine_count) == 4, "audit exposes restrained weapons and quad-engine layout")
	_check(bool(jovian.get_meta("jovian_light_freighter_candidate", false)), "root metadata identifies a candidate")
	_check(not bool(jovian.get_meta("authenticated_historical_silhouette", true)), "root metadata cannot imply historical silhouette authentication")
	_check(str(jovian.get_meta("weapon_visual_status", "")) == "modern_provisional", "root metadata explicitly scopes the weapon visual as modern provisional")
	_check(not bool(jovian.get_meta("authenticated_historical_weapon", true)), "root metadata denies an authenticated historical weapon claim")


func _test_defensive_weapon_visual(jovian: JovianLightFreighter) -> void:
	var report := jovian.get_defensive_weapon_visual_report()
	var paths := report.get("component_paths", PackedStringArray()) as PackedStringArray
	_check(
		bool(report.get("valid", false))
		and str(report.get("interpretation_status", "")) == "modern_provisional"
		and str(report.get("weapon_role", "")) == "freighter_defensive"
		and not bool(report.get("authenticated_historical_weapon", true))
		and bool(report.get("visual_only", false)),
		"twin defensive fit is explicitly modern provisional, unauthenticated, and visual-only"
	)
	_check(
		int(report.get("turret_count", 0)) == 2
		and int(report.get("components_per_turret", 0)) == 7
		and paths.size() == 14,
		"defensive weapon roster contains two complete seven-part mounts"
	)
	var visual := jovian.get_jovian_visual_root()
	var expected_suffixes := PackedStringArray([
		"DefensiveTurretBase",
		"DefensiveTurretRotationCollar",
		"DefensiveTurretReceiver",
		"DefensiveTurretBarrelShroud",
		"DefensivePulseBarrel",
		"DefensiveTurretMuzzleCollar",
		"DefensiveTurretMuzzleLens",
	])
	for prefix in ["Port", "Starboard"]:
		for suffix in expected_suffixes:
			var component := visual.get_node_or_null(NodePath(prefix + suffix)) as MeshInstance3D
			_check(
				component != null
				and str(component.get_meta("interpretation_status", "")) == "modern_provisional"
				and str(component.get_meta("weapon_role", "")) == "freighter_defensive"
				and not bool(component.get_meta("authenticated_historical_weapon", true))
				and bool(component.get_meta("visual_only", false))
				and component.get_child_count() == 0,
				"%s %s is a metadata-scoped presentation-only detail" % [prefix, suffix]
			)
	var left_muzzle := jovian.get_node(^"LeftMuzzle") as Marker3D
	var right_muzzle := jovian.get_node(^"RightMuzzle") as Marker3D
	var port_lens := visual.get_node(^"PortDefensiveTurretMuzzleLens") as MeshInstance3D
	var starboard_lens := visual.get_node(^"StarboardDefensiveTurretMuzzleLens") as MeshInstance3D
	_check(
		left_muzzle.position.is_equal_approx(Vector3(-5.15, 3.76, -6.95))
		and right_muzzle.position.is_equal_approx(Vector3(5.15, 3.76, -6.95))
		and left_muzzle.get_parent() == jovian and right_muzzle.get_parent() == jovian,
		"fixed inherited muzzle markers retain their ship-root positions and authority"
	)
	_check(
		port_lens.position.x == left_muzzle.position.x
		and port_lens.position.y == left_muzzle.position.y
		and is_equal_approx(port_lens.position.z - 0.03, left_muzzle.position.z)
		and starboard_lens.position.x == right_muzzle.position.x
		and starboard_lens.position.y == right_muzzle.position.y
		and is_equal_approx(starboard_lens.position.z - 0.03, right_muzzle.position.z),
		"both muzzle-lens forward faces align exactly with the unchanged firing plane"
	)
	for prefix in ["Port", "Starboard"]:
		var base_mesh := (visual.get_node(NodePath(prefix + "DefensiveTurretBase")) as MeshInstance3D).mesh
		var barrel_mesh := (visual.get_node(NodePath(prefix + "DefensivePulseBarrel")) as MeshInstance3D).mesh
		var receiver_mesh := (visual.get_node(NodePath(prefix + "DefensiveTurretReceiver")) as MeshInstance3D).mesh
		var shroud_mesh := (visual.get_node(NodePath(prefix + "DefensiveTurretBarrelShroud")) as MeshInstance3D).mesh
		_check(
			base_mesh.get_aabb().size.is_equal_approx(Vector3(1.36, 0.38, 1.36))
			and barrel_mesh.get_aabb().size.is_equal_approx(Vector3(0.38, 1.55, 0.38))
			and receiver_mesh.get_aabb().size.is_equal_approx(Vector3(0.76, 0.48, 0.7))
			and shroud_mesh.get_aabb().size.is_equal_approx(Vector3(0.56, 0.46, 0.72)),
			"%s defensive mount keeps the frozen freighter-scale base, barrel, receiver, and shroud dimensions" % prefix
		)


func _test_load_mark_render_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_load_mark_render_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	var visual := jovian.get_node_or_null(^"JovianFreighterVisual") as Node3D
	var batch := visual.get_node_or_null(^"LoadMarkBatch") as MultiMeshInstance3D if visual != null else null
	_check(
		bool(audit.get("valid", false))
			and int(legacy.get("renderer_nodes", 0)) == 6
			and int(legacy.get("submissions", 0)) == 6
			and int(current.get("renderer_nodes", 0)) == 1
			and int(current.get("submissions", 0)) == 1
			and int(current.get("copies", 0)) == 6
			and int(delta.get("renderer_nodes", 0)) == -5
			and int(delta.get("submissions", 0)) == -5,
		"six exterior amber load marks batch from six renderer nodes/submissions to one without losing a visible copy"
	)
	_check(
		batch != null and batch.multimesh != null
			and batch.multimesh.instance_count == JovianLightFreighter.LOAD_MARK_COPY_COUNT
			and batch.get_child_count() == 0
			and bool(batch.get_meta("visual_detail_only", false)),
		"load-mark batch remains childless visual-only presentation"
	)
	if batch == null or batch.multimesh == null:
		return
	var transforms := audit.get("authored_transforms", []) as Array
	_check(
		transforms.size() == 6
			and (transforms[0] as Transform3D).origin.is_equal_approx(Vector3(-7.88, 1.15, -1.3))
			and (transforms[5] as Transform3D).origin.is_equal_approx(Vector3(7.88, 1.15, 0.9)),
		"batched load marks retain the frozen port-to-starboard authored transform roster"
	)
	var original_buffer := batch.multimesh.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.1
	batch.multimesh.buffer = mutated_buffer
	_check(
		not bool(jovian.get_load_mark_render_audit().get("valid", true)),
		"RED: mutating a live load-mark transform buffer fails the render allocation audit"
	)
	batch.multimesh.buffer = original_buffer
	_check(
		bool(jovian.get_load_mark_render_audit().get("valid", false)),
		"restoring the load-mark transform buffer returns the render allocation audit green"
	)


func _test_passenger_seat_mesh_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_passenger_seat_mesh_allocation_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and int(current.get("nodes", 0)) == 18
		and int(current.get("copies", 0)) == 18
		and int(current.get("submissions", 0)) == 18
		and int(current.get("mesh_resource_allocations", 0)) == 3
		and int(legacy.get("mesh_resource_allocations", 0)) == 18
		and int(delta.get("mesh_resource_allocations", 0)) == -15
		and not bool(audit.get("batched", true))
		and not bool(audit.get("collision_authority", true)),
		"six passenger seats retain 18 rounded visual copies/submissions while exact mesh allocations fall 18 -> 3"
	)


	var cabin := jovian.get_node(^"WalkableInterior/PassengerCabin") as Node3D
	var port_base := cabin.get_node(^"PortPassengerSeat00/SeatBase") as MeshInstance3D
	var starboard_base := cabin.get_node(^"StarboardPassengerSeat02/SeatBase") as MeshInstance3D
	var port_back := cabin.get_node(^"PortPassengerSeat00/SeatBack") as MeshInstance3D
	var starboard_back := cabin.get_node(^"StarboardPassengerSeat02/SeatBack") as MeshInstance3D
	var port_harness := cabin.get_node(^"PortPassengerSeat00/Harness") as MeshInstance3D
	var starboard_harness := cabin.get_node(^"StarboardPassengerSeat02/Harness") as MeshInstance3D
	_check(
		port_base.mesh == starboard_base.mesh
		and port_back.mesh == starboard_back.mesh
		and port_harness.mesh == starboard_harness.mesh
		and port_base.mesh != port_back.mesh and port_back.mesh != port_harness.mesh
		and cabin.get_node(^"PortPassengerSeat00/PassengerAnchor") is Marker3D
		and cabin.get_node(^"StarboardPassengerSeat02/PassengerAnchor") is Marker3D,
		"seat family sharing preserves exact named visual paths and independent passenger anchors"
	)
	var retained := starboard_base.mesh
	starboard_base.mesh = (retained as ArrayMesh).duplicate() as ArrayMesh
	_check(
		not bool(jovian.get_passenger_seat_mesh_allocation_audit().get("valid", true))
		and _has_error(jovian.get_passenger_seat_mesh_allocation_audit(), "passenger_seat_recipe_or_authority_drift:StarboardPassengerSeat02/SeatBase"),
		"RED: one private passenger-seat mesh fails the exact shared-resource audit"
	)
	starboard_base.mesh = retained
	_check(
		bool(jovian.get_passenger_seat_mesh_allocation_audit().get("valid", false)),
		"restoring the shared passenger-seat mesh returns the Jovian audit green"
	)


func _test_passenger_cabin_light_strip_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_passenger_cabin_light_strip_allocation_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and int(current.get("nodes", 0)) == 2
		and int(current.get("copies", 0)) == 2
		and int(current.get("submissions", 0)) == 2
		and int(current.get("mesh_resource_allocations", 0)) == 1
		and int(legacy.get("mesh_resource_allocations", 0)) == 2
		and int(delta.get("mesh_resource_allocations", 0)) == -1
		and not bool(audit.get("batched", true))
		and not bool(audit.get("collision_authority", true)),
		"two passenger-cabin light strips retain their nodes/copies/submissions while one rounded mesh replaces two"
	)
	var cabin := jovian.get_node(^"WalkableInterior/PassengerCabin") as Node3D
	var port_strip := _passenger_cabin_light_strip_at(cabin, -3.23)
	var starboard_strip := _passenger_cabin_light_strip_at(cabin, 3.23)
	_check(
		port_strip != null and starboard_strip != null,
		"the frozen port/starboard direct-child transforms resolve both cabin light strips"
	)
	if port_strip == null or starboard_strip == null:
		return
	_check(
		port_strip.mesh == starboard_strip.mesh
		and port_strip.mesh is ArrayMesh
		and (port_strip.mesh as ArrayMesh).surface_get_material(0) != null
		and port_strip.position.is_equal_approx(Vector3(-3.23, 3.46, -5.25))
		and starboard_strip.position.is_equal_approx(Vector3(3.23, 3.46, -5.25))
		and port_strip.get_child_count() == 0 and starboard_strip.get_child_count() == 0,
		"cabin light-strip sharing preserves the inherited rounded recipe and both authored paths/transforms"
	)
	var retained := starboard_strip.mesh
	starboard_strip.mesh = (retained as ArrayMesh).duplicate() as ArrayMesh
	_check(
		not bool(jovian.get_passenger_cabin_light_strip_allocation_audit().get("valid", true))
		and _has_error(jovian.get_passenger_cabin_light_strip_allocation_audit(), "passenger_cabin_light_strip_recipe_or_authority_drift:Starboard"),
		"RED: a private passenger-cabin light-strip mesh fails the exact shared-resource audit"
	)
	starboard_strip.mesh = retained
	_check(
		bool(jovian.get_passenger_cabin_light_strip_allocation_audit().get("valid", false)),
		"restoring the shared passenger-cabin light-strip mesh returns the Jovian audit green"
	)


func _passenger_cabin_light_strip_at(cabin: Node3D, x: float) -> MeshInstance3D:
	for child in cabin.get_children():
		if (
			child is MeshInstance3D
			and is_equal_approx((child as MeshInstance3D).position.x, x)
			and is_equal_approx((child as MeshInstance3D).position.y, 3.46)
			and is_equal_approx((child as MeshInstance3D).position.z, -5.25)
		):
			return child as MeshInstance3D
	return null


func _test_dorsal_cargo_rib_joint_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	if not bool(audit.get("valid", false)):
		print("JOVIAN_DORSAL_RIB_ALLOCATION_ERRORS: ", audit.get("errors", PackedStringArray()))
	_check(
		bool(audit.get("valid", false)),
		"Jovian dorsal-rib joint allocation audit is green"
	)
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		legacy == {
			"geometry_nodes": 25,
			"named_nodes": 25,
			"drawn_copies": 25,
			"geometry_submissions": 25,
			"mesh_resource_allocations": 25,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and current == {
			"geometry_nodes": 25,
			"named_nodes": 25,
			"drawn_copies": 25,
			"geometry_submissions": 25,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and delta == {
			"geometry_nodes": 0,
			"drawn_copies": 0,
			"geometry_submissions": 0,
			"mesh_resource_allocations": -24,
			"material_resource_allocations": 0,
		},
		"25 named nodes/copies/submissions retain one mesh instead of 25"
	)
	_check(
		int(audit.get("descendant_node_count", -1)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("interaction_area_count", -1)) == 0
		and int(audit.get("marker_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("grouped_node_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"shared joints retain renderer submissions and zero semantic, collision, interaction, evidence, or lifecycle authority"
	)

	(current as Dictionary)["geometry_nodes"] = -1
	(audit.get("behavior_rows", []) as Array).clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller_mutation")
	var detached := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		int((detached.get("current", {}) as Dictionary).get("geometry_nodes", 0)) == 25
		and (detached.get("behavior_rows", []) as Array).size() == 25
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has(
			"caller_mutation"
		),
		"dorsal-rib allocation evidence is deeply detached"
	)

	var visual := jovian.get_jovian_visual_root()
	var first_rib := visual.get_node(^"DorsalCargoRib00") as Node3D
	var last_rib := visual.get_node(^"DorsalCargoRib04") as Node3D
	var first_joint := first_rib.get_node(^"CurveJoint") as MeshInstance3D
	var last_joint: MeshInstance3D = null
	for child in last_rib.get_children():
		var candidate := child as MeshInstance3D
		if candidate != null and candidate.mesh is SphereMesh:
			last_joint = candidate
	var shared_mesh := first_joint.mesh as SphereMesh
	_check(
		shared_mesh != null and last_joint != null and last_joint.mesh == shared_mesh,
		"all five ribs resolve their 25 joints through one exact SphereMesh"
	)

	last_joint.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_red := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int((identity_red.get("current", {}) as Dictionary).get(
			"mesh_resource_allocations", 0
		)) == 2
		and _has_error_prefix(identity_red, "dorsal_rib_joint_mesh_identity_drift:")
		and _has_error(identity_red, "dorsal_rib_joint_mesh_resource_count_drift"),
		"structured red: one private exact-looking joint mesh invalidates shared identity"
	)
	last_joint.mesh = shared_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings - 1
	var recipe_red := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and _has_error_prefix(recipe_red, "dorsal_rib_joint_mesh_recipe_drift:"),
		"structured red: shared sphere recipe drift is visible through the live family"
	)
	shared_mesh.rings = original_rings

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueRibInteractionAuthority"
	rogue_area.set_meta(&"evidence_status", &"unregistered")
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.name = "RogueRibCollision"
	rogue_shape.shape = SphereShape3D.new()
	rogue_area.add_child(rogue_shape)
	last_joint.add_child(rogue_area)
	var authority_red := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("descendant_node_count", 0)) == 2
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and int(authority_red.get("interaction_area_count", 0)) == 1
		and int(authority_red.get("metadata_entry_count", 0)) == 1
		and _has_error(authority_red, "dorsal_rib_joint_gained_children")
		and _has_error(
			authority_red,
			"dorsal_rib_joint_gained_collision_or_interaction_authority"
		)
		and _has_error(authority_red, "dorsal_rib_joint_gained_evidence_metadata"),
		"structured red: collision, interaction, or evidence authority cannot hide under a shared joint"
	)
	last_joint.remove_child(rogue_area)
	rogue_area.free()
	_check(
		bool(jovian.get_dorsal_cargo_rib_joint_allocation_audit().get("valid", false))
		and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"identity, recipe, and authority mutations restore the component audit to green"
	)


func _test_shoulder_rail_joint_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_shoulder_rail_joint_allocation_audit()
	if not bool(audit.get("valid", false)):
		print("JOVIAN_SHOULDER_RAIL_ALLOCATION_ERRORS: ", audit.get(
			"errors", PackedStringArray()
		))
	_check(bool(audit.get("valid", false)), "Jovian shoulder-rail joint allocation audit is green")
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		legacy == {
			"geometry_nodes": 7,
			"named_nodes": 7,
			"drawn_copies": 7,
			"geometry_submissions": 7,
			"mesh_resource_allocations": 7,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and current == {
			"geometry_nodes": 7,
			"named_nodes": 7,
			"drawn_copies": 7,
			"geometry_submissions": 7,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and delta == {
			"geometry_nodes": 0,
			"drawn_copies": 0,
			"geometry_submissions": 0,
			"mesh_resource_allocations": -6,
			"material_resource_allocations": 0,
		},
		"seven named nodes/copies/submissions retain one mesh instead of seven"
	)
	_check(
		int(audit.get("descendant_node_count", -1)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("interaction_area_count", -1)) == 0
		and int(audit.get("marker_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("grouped_node_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"shared shoulder joints retain renderer submissions and zero authority"
	)

	(current as Dictionary)["geometry_nodes"] = -1
	(audit.get("behavior_rows", []) as Array).clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller_mutation")
	var detached := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		int((detached.get("current", {}) as Dictionary).get("geometry_nodes", 0)) == 7
		and (detached.get("behavior_rows", []) as Array).size() == 7
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has(
			"caller_mutation"
		),
		"shoulder-rail allocation evidence is deeply detached"
	)

	var visual := jovian.get_jovian_visual_root()
	var first_rail := visual.get_node(^"PortForwardShoulderRail") as Node3D
	var last_rail := visual.get_node(^"StarboardShoulderRail") as Node3D
	var first_joint := first_rail.get_node(^"CurveJoint") as MeshInstance3D
	var last_joint: MeshInstance3D = null
	for child in last_rail.get_children():
		var candidate := child as MeshInstance3D
		if candidate != null and candidate.mesh is SphereMesh:
			last_joint = candidate
	var shared_mesh := first_joint.mesh as SphereMesh
	_check(
		shared_mesh != null and last_joint != null and last_joint.mesh == shared_mesh,
		"all three shoulder rails resolve seven joints through one exact SphereMesh"
	)

	last_joint.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int((identity_red.get("current", {}) as Dictionary).get(
			"mesh_resource_allocations", 0
		)) == 2
		and _has_error_prefix(identity_red, "shoulder_rail_joint_mesh_identity_drift:")
		and _has_error(identity_red, "shoulder_rail_joint_mesh_resource_count_drift"),
		"structured red: one private exact-looking shoulder mesh invalidates shared identity"
	)
	last_joint.mesh = shared_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings - 1
	var recipe_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and _has_error_prefix(recipe_red, "shoulder_rail_joint_mesh_recipe_drift:"),
		"structured red: shared shoulder sphere recipe drift is visible"
	)
	shared_mesh.rings = original_rings

	var original_layers := last_joint.layers
	last_joint.layers = 2
	var renderer_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(renderer_red.get("valid", true))
		and _has_error_prefix(renderer_red, "shoulder_rail_joint_renderer_recipe_drift:"),
		"structured red: shoulder renderer-state drift is visible"
	)
	last_joint.layers = original_layers

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueShoulderRailInteractionAuthority"
	rogue_area.set_meta(&"evidence_status", &"unregistered")
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.name = "RogueShoulderRailCollision"
	rogue_shape.shape = SphereShape3D.new()
	rogue_area.add_child(rogue_shape)
	last_joint.add_child(rogue_area)
	var authority_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("descendant_node_count", 0)) == 2
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and int(authority_red.get("interaction_area_count", 0)) == 1
		and int(authority_red.get("metadata_entry_count", 0)) == 1
		and _has_error(authority_red, "shoulder_rail_joint_gained_children")
		and _has_error(
			authority_red,
			"shoulder_rail_joint_gained_collision_or_interaction_authority"
		)
		and _has_error(authority_red, "shoulder_rail_joint_gained_evidence_metadata"),
		"structured red: authority cannot hide under a shared shoulder joint"
	)
	last_joint.remove_child(rogue_area)
	rogue_area.free()
	_check(
		bool(jovian.get_shoulder_rail_joint_allocation_audit().get("valid", false))
		and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"shoulder identity, recipe, renderer, and authority mutations restore to green"
	)


func _test_cargo_frame_joint_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_cargo_frame_joint_allocation_audit()
	if not bool(audit.get("valid", false)):
		print("JOVIAN_CARGO_FRAME_ALLOCATION_ERRORS: ", audit.get(
			"errors", PackedStringArray()
		))
	_check(bool(audit.get("valid", false)), "Jovian cargo-frame joint allocation audit is green")
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		legacy == {
			"geometry_nodes": 20,
			"named_nodes": 20,
			"drawn_copies": 20,
			"geometry_submissions": 20,
			"mesh_resource_allocations": 20,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and current == {
			"geometry_nodes": 20,
			"named_nodes": 20,
			"drawn_copies": 20,
			"geometry_submissions": 20,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and delta == {
			"geometry_nodes": 0,
			"drawn_copies": 0,
			"geometry_submissions": 0,
			"mesh_resource_allocations": -19,
			"material_resource_allocations": 0,
		},
		"20 named moving-interior joints retain one mesh instead of 20"
	)
	_check(
		bool(audit.get("moving_interior_attached", false))
		and int(audit.get("descendant_node_count", -1)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("interaction_area_count", -1)) == 0
		and int(audit.get("marker_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("grouped_node_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"shared cargo-frame joints stay attached to the moving interior with unchanged submissions and zero authority"
	)

	(current as Dictionary)["geometry_nodes"] = -1
	(audit.get("behavior_rows", []) as Array).clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller_mutation")
	var detached := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		int((detached.get("current", {}) as Dictionary).get("geometry_nodes", 0)) == 20
		and (detached.get("behavior_rows", []) as Array).size() == 20
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has(
			"caller_mutation"
		),
		"cargo-frame allocation evidence is deeply detached"
	)

	var cargo_bay := jovian.get_node(^"WalkableInterior/CargoBay") as Node3D
	var first_frame := cargo_bay.get_node(^"CargoFrame00") as Node3D
	var last_frame := cargo_bay.get_node(^"CargoFrame03") as Node3D
	var first_joint := first_frame.get_node(^"CurveJoint") as MeshInstance3D
	var last_joint: MeshInstance3D = null
	for child in last_frame.get_children():
		var candidate := child as MeshInstance3D
		if candidate != null and candidate.mesh is SphereMesh:
			last_joint = candidate
	var shared_mesh := first_joint.mesh as SphereMesh
	_check(
		shared_mesh != null and last_joint != null and last_joint.mesh == shared_mesh,
		"all four cargo frames resolve their 20 joints through one exact SphereMesh"
	)

	last_joint.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int((identity_red.get("current", {}) as Dictionary).get(
			"mesh_resource_allocations", 0
		)) == 2
		and _has_error_prefix(identity_red, "cargo_frame_joint_mesh_identity_drift:")
		and _has_error(identity_red, "cargo_frame_joint_mesh_resource_count_drift"),
		"structured red: one private exact-looking cargo-frame mesh invalidates shared identity"
	)
	last_joint.mesh = shared_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings - 1
	var recipe_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and _has_error_prefix(recipe_red, "cargo_frame_joint_mesh_recipe_drift:"),
		"structured red: shared cargo-frame sphere recipe drift is visible"
	)
	shared_mesh.rings = original_rings

	var original_layers := last_joint.layers
	last_joint.layers = 2
	var renderer_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(renderer_red.get("valid", true))
		and _has_error_prefix(renderer_red, "cargo_frame_joint_renderer_recipe_drift:"),
		"structured red: cargo-frame renderer-state drift is visible"
	)
	last_joint.layers = original_layers

	var interior := jovian.get_interior_root()
	cargo_bay.reparent(jovian, false)
	var moving_interior_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(moving_interior_red.get("valid", true))
		and not bool(moving_interior_red.get("moving_interior_attached", true))
		and _has_error(
			moving_interior_red,
			"cargo_frame_moving_interior_attachment_drift"
		),
		"structured red: cargo frames cannot detach from the physical moving interior"
	)
	cargo_bay.reparent(interior, false)

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueCargoFrameInteractionAuthority"
	rogue_area.set_meta(&"evidence_status", &"unregistered")
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.name = "RogueCargoFrameCollision"
	rogue_shape.shape = SphereShape3D.new()
	rogue_area.add_child(rogue_shape)
	last_joint.add_child(rogue_area)
	var authority_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("descendant_node_count", 0)) == 2
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and int(authority_red.get("interaction_area_count", 0)) == 1
		and int(authority_red.get("metadata_entry_count", 0)) == 1
		and _has_error(authority_red, "cargo_frame_joint_gained_children")
		and _has_error(
			authority_red,
			"cargo_frame_joint_gained_collision_or_interaction_authority"
		)
		and _has_error(authority_red, "cargo_frame_joint_gained_evidence_metadata"),
		"structured red: authority cannot hide under a shared cargo-frame joint"
	)
	last_joint.remove_child(rogue_area)
	rogue_area.free()
	_check(
		bool(jovian.get_cargo_frame_joint_allocation_audit().get("valid", false))
		and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"cargo-frame identity, recipe, renderer, and authority mutations restore to green"
	)


func _test_scale_handling_and_presentation(jovian: JovianLightFreighter) -> void:
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	_test_root.add_child(torrent)
	_test_root.add_child(arrow)
	await process_frame
	var visual := jovian.get_jovian_visual_root()
	_check(visual != null and visual.name == "JovianFreighterVisual", "variant owns a dedicated Jovian visual root")
	_check(jovian.get_node_or_null("TorrentVisual") == null, "no inherited Torrent exterior hierarchy remains")
	_check(str(visual.get_meta("geometry_status", "")) == "provisional", "visual root publishes provisional geometry status")
	var flight_deck := visual.get_node_or_null("ForwardFlightDeck") as MeshInstance3D
	var shoulder := visual.get_node_or_null("PortCargoShoulder") as MeshInstance3D
	_check(flight_deck != null and flight_deck.mesh is ArrayMesh and flight_deck.mesh.get_faces().size() > 650, "flight deck is a dense smooth loft")
	_check(shoulder != null and shoulder.mesh is ArrayMesh and shoulder.mesh.get_faces().size() > 500, "split port cargo shoulder is a dense smooth loft")
	if flight_deck != null and flight_deck.mesh != null:
		var faces := flight_deck.mesh.get_faces()
		var first_side_normal := (faces[1] - faces[0]).cross(faces[2] - faces[0]).normalized()
		var first_side_center := (faces[0] + faces[1] + faces[2]) / 3.0
		_check(
			first_side_normal.dot(Vector3(first_side_center.x, first_side_center.y, 0.0)) > 0.0,
			"flight-deck loft side faces point outward instead of exposing a hollow shell"
		)
	_check(visual.get_node_or_null("PortRadiator") is MeshInstance3D and visual.get_node_or_null("StarboardRadiator") is MeshInstance3D, "paired radiator planforms distinguish the utility silhouette")
	var canopy := visual.get_node_or_null("CanopyHinge") as Node3D
	var port_hinge_mount := visual.get_node_or_null("PortCanopyHingeMount") as MeshInstance3D
	var starboard_hinge_mount := visual.get_node_or_null("StarboardCanopyHingeMount") as MeshInstance3D
	_check(
		canopy != null and port_hinge_mount != null and starboard_hinge_mount != null
		and port_hinge_mount.position.x < starboard_hinge_mount.position.x,
		"freighter retains both explicitly named inherited canopy hinge mounts"
	)
	_check(
		canopy != null
		and canopy.get_node_or_null("PortCanopyLowerRail") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyLowerRail") is MeshInstance3D
		and canopy.get_node_or_null("PortCanopyNoseFrame") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyNoseFrame") is MeshInstance3D,
		"freighter retains and restyles both named canopy sides"
	)

	var maximum_x := 0.0
	var maximum_z := 0.0
	for child in jovian.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var collision := child as CollisionShape3D
			var size := (collision.shape as BoxShape3D).size
			maximum_x = maxf(maximum_x, absf(collision.position.x) + size.x * 0.5)
			maximum_z = maxf(maximum_z, absf(collision.position.z) + size.z * 0.5)
	_check(maximum_x * 2.0 > 15.0 and maximum_z * 2.0 > 27.0, "collision envelope is materially larger than both small craft")
	_check(jovian.maximum_speed < torrent.maximum_speed and jovian.maximum_speed < arrow.maximum_speed, "freighter top speed is lower than both small craft")
	_check(jovian.thrust_acceleration < torrent.thrust_acceleration and jovian.thrust_acceleration < arrow.thrust_acceleration, "freighter acceleration is lower than both small craft")
	_check(jovian.yaw_speed_degrees < torrent.yaw_speed_degrees and jovian.yaw_speed_degrees < arrow.yaw_speed_degrees, "freighter yaw is slower than both small craft")
	_check(jovian.roll_speed_degrees < torrent.roll_speed_degrees and jovian.roll_speed_degrees < arrow.roll_speed_degrees, "freighter roll is slower than both small craft")
	_check(jovian.maximum_hull > torrent.maximum_hull * 2.0 and jovian.maximum_hull > arrow.maximum_hull * 2.0, "freighter has substantially greater hull durability")
	torrent.queue_free()
	arrow.queue_free()
	await process_frame


func _test_connected_interior_contract(jovian: JovianLightFreighter) -> void:
	var interior := jovian.get_interior_root()
	var cargo := jovian.get_cargo_bay_root()
	var passenger := jovian.get_passenger_cabin_root()
	_check(interior != null and interior.get_parent() == jovian, "interior is a direct child of the unbanked physical ship frame")
	_check(cargo != null and cargo.get_parent() == interior, "cargo bay is part of the physical interior")
	_check(passenger != null and passenger.get_parent() == interior, "passenger cabin is part of the same interior")
	_check(jovian.get_pilot_seat_anchor().get_parent().get_parent() == interior, "pilot cockpit is part of the same unbanked interior frame")
	_check(cargo.get_node_or_null("CargoDeck") is MeshInstance3D, "cargo bay exposes a visible deck")
	_check(passenger.get_node_or_null("PassengerDeck") is MeshInstance3D, "passenger cabin exposes a visible deck")
	_check(jovian.get_node_or_null("WalkableInterior/CockpitConnectorDeck") is MeshInstance3D, "same-level connector reaches the cockpit")
	_check(jovian.get_cargo_hardpoints().size() == 4, "four stable cargo hardpoints are exposed")
	_check(jovian.get_passenger_seat_anchors().size() == 6, "six stable passenger anchors are exposed")
	for hardpoint in jovian.get_cargo_hardpoints():
		_check(hardpoint.is_ancestor_of(hardpoint) == false and jovian.is_ancestor_of(hardpoint), "%s remains ship-owned" % hardpoint.name)
	for anchor in jovian.get_passenger_seat_anchors():
		_check(jovian.is_ancestor_of(anchor) and anchor.has_meta("seat_id"), "%s is a typed ship-owned seat anchor" % anchor.get_parent().name)

	var access := jovian.get_interior_access_marker()
	var deck := jovian.get_interior_deck_marker()
	_check(access != null and deck != null and jovian.is_ancestor_of(access) and jovian.is_ancestor_of(deck), "entry markers remain attached to the ship")
	_check(access.position.x < deck.position.x - 4.5 and absf(access.position.z - deck.position.z) < 0.01, "ramp threshold connects directly to the cargo deck")
	_check(jovian.get_interior_exit_transform().origin.distance_to(jovian.global_position) > 10.4, "interior exit clears the large hull")
	var bounds := jovian.get_interior_bounds()
	_check(bounds.size.x > 11.0 and bounds.size.y > 4.0 and bounds.size.z > 17.0, "ship publishes a useful local interior AABB")
	_check(bounds.has_point(deck.position) and bounds.has_point(Vector3.ZERO + Vector3(0, 1, -5)), "bounds include cargo and passenger walkable positions")
	_check(jovian.get_interior_frame() == jovian, "rigid interior frame is the physical ship root")
	var coordinator := jovian.get_moving_interior_component()
	_check(coordinator != null and coordinator.get_parent() == jovian, "typed moving-interior coordinator is a direct child")
	_check(coordinator.get_moving_frame() == jovian and coordinator.get_interior_bounds() == bounds, "coordinator uses the exact ship frame and bounds")
	var report := jovian.get_walkable_interior_report()
	_check(not bool(report.detached_interior) and bool(report.physical_deck_collision), "interior report rejects a detached set and confirms deck collision")
	_check(bool(report.moving_occupant_compensation), "interior report confirms moving-occupant compensation")
	_check((report.connected_spaces as PackedStringArray) == PackedStringArray(["exterior_ramp", "cargo_bay", "passenger_cabin", "pilot_cockpit"]), "interior report exposes the complete route in order")
	_check(not bool(report.historically_authenticated_layout), "interior report cannot authenticate the invented layout")


func _test_collision_access_and_cameras(jovian: JovianLightFreighter) -> void:
	_check(jovian.collision_layer == PhysicsLayers.SHIP_BODY_LAYER and jovian.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "Jovian uses canonical ship collision")
	for collision_name in ["CargoDeckCollision", "PassengerDeckCollision", "CockpitDeckCollision", "PortCargoRampCollision"]:
		_check(jovian.get_node_or_null(collision_name) is CollisionShape3D, "%s is a physical collider" % collision_name)
	# There must be no monolithic port collision across the ramp aperture.
	_check(jovian.get_node_or_null("PortShoulderCollision") == null, "port shoulder collision is split around the cargo opening")
	var ray_parameters := PhysicsRayQueryParameters3D.create(
		jovian.to_global(Vector3(-5.25, 2.0, 3.2)),
		jovian.to_global(Vector3(0.0, 2.0, 3.2)),
		PhysicsLayers.SHIP_BODY_LAYER
	)
	var clear_route := jovian.get_world_3d().direct_space_state.intersect_ray(ray_parameters)
	_check(clear_route.is_empty(), "cargo aperture to central aisle is not blocked by another body")
	var boarding_area := jovian.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(boarding_area != null and boarding_area.get_ship() == jovian and boarding_area.is_available(), "pilot boarding area resolves the freighter generically")
	_check("FLIGHT DECK" in boarding_area.get_prompt(), "pilot prompt is distinct from cargo-ramp access")
	_check(jovian.get_boarding_position().distance_to(jovian.get_interior_access_marker().global_position) > 7.0, "pilot hatch and cargo entrance are separate physical routes")
	var seat := jovian.get_pilot_seat_anchor()
	_check(seat != null and seat.global_position.distance_to(jovian.get_boarding_entry_transform().origin) < 3.0, "pilot hatch retains a short physical seat transition")
	_check(seat.global_position.z < jovian.get_passenger_cabin_root().global_position.z - 6.0, "pilot seat is forward of the passenger cabin")
	jovian.set_piloted(true)
	_check(jovian.get_camera() != null and jovian.get_camera().name == "ShipCamera", "large craft activates chase camera")
	jovian.set_cockpit_view(true)
	_check(jovian.get_camera().name == "CockpitCamera" and jovian.get_camera().get_parent().name == "CockpitInterior", "cockpit view remains inside physical flight deck")
	jovian.set_cockpit_view(false)
	jovian.set_piloted(false)


## The hold's secured freight is solid.
##
## It was presentation-only for as long as the cargo bay was scenery a chase
## camera flew past. Once a crew member could leave the seat and walk it, a crate
## you walk through — and a chase boom pushed inside a container, which is what
## `artifacts/cabin_04_walking_the_hold.png` shows — became the same
## "solid-looking volume with no collision" defect the station sweep closed
## everywhere else.
##
## Measured both ways on purpose. Freight that is solid but has swallowed the
## aisle is a worse defect than freight you can walk through, because it strands a
## crew member in a pressurised hull: the same probe that requires the crates to
## stop a capsule requires the central lane and the ramp-to-cabin diagonal to
## stay open. `_test_physical_player_traversal` below then walks that lane for
## real.
const CARGO_AISLE_PROBE_POINTS: Array[Vector3] = [
	Vector3(0.0, 1.4, -1.5),
	Vector3(0.0, 1.4, 1.0),
	Vector3(0.0, 1.4, 3.2),
	Vector3(0.0, 1.4, 5.5),
	Vector3(0.0, 1.4, 8.0),
	# The ramp aperture and the diagonal from it to the forward passage.
	Vector3(-4.6, 1.4, 3.2),
	Vector3(-2.6, 1.4, 3.2),
	Vector3(-1.4, 1.4, 0.0),
]


func _test_secured_freight_is_solid(jovian: JovianLightFreighter) -> void:
	var space := jovian.get_world_3d().direct_space_state
	var drawn_units: Array[MeshInstance3D] = []
	for candidate in jovian.find_children("CargoContainer*", "MeshInstance3D", true, false):
		drawn_units.append(candidate as MeshInstance3D)
	for candidate in jovian.find_children("CargoPallet*", "MeshInstance3D", true, false):
		drawn_units.append(candidate as MeshInstance3D)
	_check(
		drawn_units.size() == JovianLightFreighter.CARGO_UNIT_ANCHORS.size() * 2,
		"the hold draws a pallet and a container at each of its %d tie-down stations (%d meshes)"
			% [JovianLightFreighter.CARGO_UNIT_ANCHORS.size(), drawn_units.size()]
	)

	# Every drawn crate volume must stop a probe placed inside it. The probe is a
	# box at half the drawn unit's own size, centred on the drawn mesh: half-size
	# so a 0.22 m pallet is tested without the probe reaching down through it into
	# the cargo deck 0.28 m below, which is what a fixed-size capsule does and is
	# why the first version of the structured red below could not go red.
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = PhysicsLayers.SHIP_BODY_LAYER
	var permeable := PackedStringArray()
	for unit in drawn_units:
		var bounds := (unit.global_transform * unit.get_aabb()).abs()
		query.shape = _inner_probe(bounds)
		query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
		var hit := false
		for result in space.intersect_shape(query, 4):
			if (result["collider"] as Node) == jovian:
				hit = true
		if not hit:
			permeable.append("%s at %s" % [unit.name, str(bounds.get_center())])
	print("PERMEABLE_FREIGHT: ", permeable)
	_check(
		permeable.is_empty(),
		"every drawn cargo unit in the hold is solid to the ship's own collision"
	)

	var blocked_aisle := PackedStringArray()
	# The production avatar's own capsule, standing on the cargo deck.
	var aisle_capsule := CapsuleShape3D.new()
	aisle_capsule.radius = 0.38
	aisle_capsule.height = 1.8
	query.shape = aisle_capsule
	for point in CARGO_AISLE_PROBE_POINTS:
		query.transform = Transform3D(Basis.IDENTITY, jovian.to_global(point))
		for result in space.intersect_shape(query, 4):
			if (result["collider"] as Node) == jovian:
				blocked_aisle.append(str(point))
				break
	print("BLOCKED_CARGO_AISLE: ", blocked_aisle)
	_check(
		blocked_aisle.is_empty(),
		"making the freight solid left the central lane and the ramp-to-cabin diagonal open"
	)

	# Structured red: drop the colliders and the permeability check must fire.
	var disabled: Array[CollisionShape3D] = []
	for child in jovian.get_children():
		var shape := child as CollisionShape3D
		if shape == null or not shape.name.begins_with("Cargo"):
			continue
		if not (shape.name.contains("Pallet") or shape.name.contains("Container")):
			continue
		shape.disabled = true
		disabled.append(shape)
	_check(disabled.size() == drawn_units.size(), "each drawn cargo unit has its own named collider")
	var still_solid := 0
	for unit in drawn_units:
		var bounds := (unit.global_transform * unit.get_aabb()).abs()
		query.shape = _inner_probe(bounds)
		query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
		for result in space.intersect_shape(query, 4):
			if (result["collider"] as Node) == jovian:
				still_solid += 1
				break
	_check(
		still_solid == 0,
		"disabling the freight colliders returns the hold to walk-through crates (%d still solid)"
			% still_solid
	)
	for shape in disabled:
		shape.disabled = false


## A box at half the given volume's size, centred in it: entirely inside the
## drawn unit, so a hit can only come from that unit's own collider.
func _inner_probe(bounds: AABB) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = bounds.size * 0.5
	return shape


func _test_physical_player_traversal(jovian: JovianLightFreighter) -> void:
	# A real PlayerController walks from the exterior landing deck, up the ship's
	# sloped collider, through the open aperture, and into the passenger cabin.
	var landing_deck := StaticBody3D.new()
	landing_deck.name = "JovianTraversalLandingDeck"
	landing_deck.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	landing_deck.collision_mask = PhysicsLayers.NONE
	_test_root.add_child(landing_deck)
	var deck_collision := CollisionShape3D.new()
	deck_collision.position = Vector3(0.0, -1.35, 0.0)
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(45.0, 0.2, 45.0)
	deck_collision.shape = deck_shape
	landing_deck.add_child(deck_collision)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	player.set_camera_active(false)
	var camera_yaw := player.get_node("CameraRig/CameraYaw") as Node3D
	player.teleport_to(Transform3D(Basis.IDENTITY, jovian.to_global(Vector3(-10.7, -1.24, 3.2))))
	camera_yaw.rotation.y = 0.0
	for index in 10:
		await physics_frame
	_check(player.is_on_floor(), "real player begins grounded beside the deployed ramp")

	Input.action_press("move_right")
	for index in 118:
		await physics_frame
	Input.action_release("move_right")
	var cargo_local := jovian.to_local(player.global_position)
	_check(cargo_local.x > -3.2 and absf(cargo_local.z - 3.2) < 1.2, "real player walks up the ramp and through its collision-clear aperture")
	_check(player.is_on_floor(), "real player remains grounded on the ship-owned cargo deck")
	_check(jovian.get_moving_interior_component().is_occupant_registered(player), "cargo entry registers the real player with the moving frame")

	Input.action_press("move_forward")
	for index in 90:
		await physics_frame
	Input.action_release("move_forward")
	var cabin_local := jovian.to_local(player.global_position)
	_check(cabin_local.z < -3.35 and absf(cabin_local.x) < 1.45, "real player follows the central aisle into the connected passenger cabin")
	_check(player.is_on_floor(), "real player stays grounded across the cargo-to-passenger threshold")
	_check(jovian.get_interior_bounds().has_point(cabin_local), "passenger traversal remains within published ship-local bounds")

	player.queue_free()
	landing_deck.queue_free()
	await process_frame
	await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_forward")


func _test_engine_weapon_damage_and_reuse(jovian: JovianLightFreighter) -> void:
	var fired: Array[Dictionary] = []
	jovian.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		fired.append({"origin": origin, "direction": direction})
	)
	jovian.engine_start_time = 0.03
	jovian.weapon_cooldown = 0.03
	jovian.set_piloted(true)
	jovian.request_engine_start()
	for index in 7:
		await physics_frame
	_check(str(jovian.get_telemetry().engine_state) == "ONLINE", "freighter completes inherited engine startup")
	var visible_plumes := 0
	for node in jovian.get_jovian_visual_root().find_children("*EnginePlume", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).visible:
			visible_plumes += 1
	_check(visible_plumes == 4, "all four engine plumes activate online")
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(fired.size() == 1, "defensive pulse fires through inherited weapon lifecycle")
	if not fired.is_empty():
		_check((fired[0].direction as Vector3).dot(-jovian.global_basis.z) > 0.8, "pulse follows visible nose direction")

	var coordinator := jovian.get_moving_interior_component()
	var occupant := CharacterBody3D.new()
	occupant.name = "InteriorLifecycleOccupant"
	_test_root.add_child(occupant)
	occupant.global_position = jovian.to_global(Vector3.ZERO + Vector3(0.0, 1.0, 2.0))
	var registration := coordinator.register_occupant(occupant, {"require_inside_bounds": true})
	_check(bool(registration.registered), "physical occupant registers inside the ship-local bounds")
	jovian.set_piloted(false)
	jovian.request_engine_stop()
	jovian.apply_damage(jovian.maximum_hull + 1.0, jovian.global_position, Vector3.UP)
	await physics_frame
	_check(jovian.is_destroyed() and coordinator.get_occupant_count() == 0, "destruction releases moving-interior occupants")
	var volume := jovian.get_node_or_null("WalkableInterior/InteriorOccupantVolume") as Area3D
	_check(volume != null and not volume.monitoring, "destroyed ship disables automatic interior registration")
	var reset_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(-18.0)), Vector3(20.0, 4.0, 16.0))
	jovian.reset_for_reuse(reset_transform)
	await physics_frame
	await physics_frame
	_check(not jovian.is_destroyed() and jovian.is_boardable(), "same freighter instance resets for reuse")
	_check(jovian.global_transform.origin.is_equal_approx(reset_transform.origin), "reuse snaps to requested berth transform")
	_check(volume.monitoring and coordinator.get_moving_frame() == jovian, "reuse restores interior registration volume and frame")
	_check(jovian.get_interior_root().visible and jovian.get_cargo_hardpoints().size() == 4, "connected interior survives reuse")
	occupant.queue_free()
	await process_frame


func _test_cleanup(jovian: JovianLightFreighter) -> void:
	var ship_reference: WeakRef = weakref(jovian)
	var interior_reference: WeakRef = weakref(jovian.get_interior_root())
	var coordinator_reference: WeakRef = weakref(jovian.get_moving_interior_component())
	jovian.queue_free()
	jovian = null
	await process_frame
	await physics_frame
	await process_frame
	_check(ship_reference.get_ref() == null, "Jovian root cleans up")
	_check(interior_reference.get_ref() == null, "connected interior cleans up with ship")
	_check(coordinator_reference.get_ref() == null, "moving-interior coordinator cleans up with ship")
	_test_root.queue_free()
	await process_frame


func _has_error(audit: Dictionary, expected: String) -> bool:
	return (audit.get("errors", PackedStringArray()) as PackedStringArray).has(expected)


func _has_error_prefix(audit: Dictionary, expected_prefix: String) -> bool:
	for error in audit.get("errors", PackedStringArray()) as PackedStringArray:
		if error.begins_with(expected_prefix):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	Input.action_release("fire")
	if _failures.is_empty():
		print("JOVIAN_LIGHT_FREIGHTER_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_LIGHT_FREIGHTER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
