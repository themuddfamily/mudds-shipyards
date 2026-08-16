extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")
const BERTH_SCENE := preload("res://scenes/world/components/ship_berth.tscn")
const JOVIAN_DEFINITION := preload("res://assets/ships/jovian_provisional.tres")
const WORLD_LAYER := PhysicsLayers.WORLD
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. A frame count, never a wall-clock grace: the door advances in
## `_physics_process`, and only a frame budget measures the same amount of panel
## motion on a loaded box as on an idle one.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "JovianFreightBerthTestRoot"
	root.add_child(_test_root)
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	_check(module != null, "freight berth scene instantiates as JovianFreightBerth")
	if module == null:
		_finish()
		return
	module.position = Vector3(17.0, 2.5, -31.0)
	module.rotation_degrees.y = 23.0
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_identity_evidence_and_audits(module)
	_test_anchor_routes_and_room_contract(module)
	_test_berth_specification(module)
	await _test_physical_walkable_surfaces(module)
	await _test_ship_envelope_is_structurally_clear(module)
	await _test_service_door_lifecycle(module)
	_test_animated_equipment(module)
	await _test_direct_world_berth_lifecycle(module)
	_test_materials_signage_and_detail(module)
	_test_handling_infrastructure(module)
	_test_nothing_drawn_floats(module)
	await _test_handling_fixtures_are_solid(module)
	_test_collision_contract(module)
	await _test_cleanup(module)
	_finish()


func _test_identity_evidence_and_audits(module: JovianFreightBerth) -> void:
	_check(module.get_module_id() == &"jovian-freight-berth", "module exposes a stable identity")
	_check(module.get_ship_class_id() == &"jovian_provisional", "target craft identity remains explicitly provisional")
	_check(module.get_ship_class_name() == "Jovian-class Light Freighter", "creator-supported exact class name is exposed")
	_check(bool(module.get_meta("station_module", false)), "root metadata identifies a station module")
	_check(bool(module.get_meta("source_bounded", false)), "module identifies itself as source-bounded")
	_check(bool(module.get_meta("creator_supported_identity", false)), "root distinguishes supported identity from design")
	_check(not bool(module.get_meta("authenticated_original_geometry", true)), "root rejects authenticated geometry")
	_check(module.is_in_group("station_modules") and module.is_in_group("freight_berth_modules"), "module participates in both discovery groups")

	var evidence := module.get_evidence_metadata()
	_check(int(evidence.schema_version) == JovianFreightBerth.SCHEMA_VERSION, "evidence has a stable schema")
	_check(str(evidence.evidence_status) == "creator_roster_supported_modern_interpretation", "evidence uses the bounded status")
	_check(bool(evidence.creator_supported_identity) and bool(evidence.creator_supported_role), "name and role support are explicit")
	_check(not bool(evidence.authenticated_original_geometry) and not bool(evidence.authenticated_berth_layout), "geometry and berth are never authenticated")
	_check((evidence.references as PackedStringArray).size() >= 5, "evidence supplies creator, recording, and station references")
	_check(
		"ties no visible craft to it" in str(evidence.content_note)
		and "name-to-model mapping is unknown" in str(evidence.content_note)
		and not ("labelled Paradox" in str(evidence.content_note)),
		"evidence note blocks the B4 name-to-model inference without asserting an unregistered observation"
	)
	_check("all explicitly provisional" in str(evidence.content_note), "evidence note bounds every authored berth feature")
	var unknowns := evidence.explicit_unknowns as PackedStringArray
	_check(unknowns.size() >= 3 and "authoritative Jovian name-to-model mapping" in unknowns[0], "unknown model mapping remains explicit")
	var refs := evidence.references as PackedStringArray
	refs.append("mutation")
	_check(not (module.get_evidence_metadata().references as PackedStringArray).has("mutation"), "evidence arrays are detached")

	var typed := module.get_typed_audit_report()
	_check(typed is JovianFreightBerthAudit, "module publishes a strongly typed audit snapshot")
	_check(typed.valid and typed.errors.is_empty(), "constructed module passes typed validation")
	_check(typed.creator_supported_identity and not typed.authenticated_original_geometry, "typed audit preserves the epistemic boundary")
	_check(typed.berth_id == &"jovian_freight_berth" and typed.berth_valid, "typed audit includes the production berth contract")
	_check(typed.cargo_unit_count >= 8 and typed.service_detail_count >= 12, "typed audit exposes substantial cargo and service detail")
	_check(typed.animated_equipment_count >= 3, "typed audit exposes articulated equipment roots")
	typed.errors.append("mutation")
	typed.footprint["local_min"] = Vector3.ZERO
	var typed_again := module.get_typed_audit_report()
	_check(not typed_again.errors.has("mutation") and typed_again.footprint.local_min != Vector3.ZERO, "typed reports are detached from module state")
	var audit := module.get_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "dictionary compatibility audit also validates")
	(audit.evidence as Dictionary)["content_note"] = "mutation"
	_check(str(module.get_audit_report().evidence.content_note) != "mutation", "nested dictionary audit data is detached")


func _test_anchor_routes_and_room_contract(module: JovianFreightBerth) -> void:
	_check(module.get_module_anchor().global_transform.is_equal_approx(module.global_transform), "module origin is the exact connection transform")
	var expected_routes := PackedStringArray([
		"approach",
		"apron-threshold",
		"boarding-staging",
		"cargo-transfer",
		"service-threshold",
		"service-room",
		"cargo-rack",
	])
	for route_id in expected_routes:
		_check(module.has_route_marker(StringName(route_id)), "route marker is exposed: %s" % route_id)
		var marker := module.get_route_marker(StringName(route_id))
		_check(marker != null and bool(marker.get_meta("station_route_marker", false)), "route marker has semantic metadata: %s" % route_id)
	_check(module.get_route_ids().size() == expected_routes.size(), "route registry has no implicit entries")
	_check(module.get_route_marker(&"missing-route") == null, "unknown route has no fallback")

	var footprint := module.get_integration_footprint()
	_check((footprint.local_min as Vector3).is_equal_approx(Vector3(-23.0, -3.4, -4.8)), "footprint publishes the exact connection-side minimum")
	_check((footprint.local_max as Vector3).is_equal_approx(Vector3(23.0, 14.2, 51.5)), "footprint publishes the full crane and apron maximum")
	_check((footprint.local_size as Vector3).is_equal_approx(Vector3(46.0, 17.6, 56.3)), "footprint size is complete and finite")
	_check((footprint.module_extends_local as Vector3).is_equal_approx(Vector3.BACK), "module declares local +Z as its outward direction")
	_check((footprint.recommended_world_transform as Transform3D).is_equal_approx(module.get_recommended_world_transform()), "footprint repeats the stable integration recommendation")
	_check(module.get_recommended_world_transform().origin.is_equal_approx(Vector3(-53.0, 0.38, 28.8)), "recommended current-world anchor is exact")

	var clearance := module.get_clearance_profile()
	_check(float(clearance.connection_clear_width) >= 5.8, "connection is much broader than the player capsule")
	_check(float(clearance.service_door_clear_width) >= 3.1, "service door supports freight and player passage")
	_check(float(clearance.minimum_head_clearance) >= 4.1, "published head clearance is generous")
	_check(float(clearance.cargo_transfer_clear_width) >= 3.4, "cargo transfer lane is independently declared")

	var room := module.get_service_room_volume()
	var centre := (room.world_transform as Transform3D).origin
	_check(room.room_id == &"freight-control" and room.room_class == &"freight-service-room", "service room has stable semantic identity")
	_check(module.contains_service_room(centre), "service-room centre is contained")
	_check(module.contains_service_room(module.get_route_transform(&"service-room").origin), "service route terminates inside the room")
	_check(not module.contains_service_room(module.get_route_transform(&"boarding-staging").origin), "boarding apron is not misreported as interior")


func _test_berth_specification(module: JovianFreightBerth) -> void:
	var marker := module.get_berth_marker()
	_check(marker != null and bool(marker.get_meta("station_berth_marker", false)), "module exposes a semantic dock marker")
	_check(bool(marker.get_meta("required_direct_world_berth", false)), "marker states the direct-world registry requirement")
	_check(marker.global_transform.is_equal_approx(module.get_berth_transform()), "marker and public dock transform are exact")
	var expected_local := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.25, 28.5))
	_check(module.get_berth_transform().is_equal_approx(module.global_transform * expected_local), "dock preserves full module rotation and position")
	var spec := module.get_berth_specification()
	_check(spec.berth_id == &"jovian_freight_berth", "specification uses the production stable berth ID")
	_check(bool(spec.must_be_direct_world_child) and spec.required_world_parent == &"ShipyardWorld", "specification rejects nested production lease authority")
	_check((spec.dock_transform as Transform3D).is_equal_approx(marker.global_transform), "specification exports the exact marker transform")
	_check((spec.landing_half_extents as Vector3).is_equal_approx(Vector3(14.0, 8.0, 21.5)), "landing volume fits the larger craft")
	var tags := spec.compatibility_tags as PackedStringArray
	for required_tag in ["medium_craft", "freighter", "cargo", "walkable_interior"]:
		_check(tags.has(required_tag), "berth accepts the actual Jovian compatibility tag: %s" % required_tag)
	for descriptive_tag in ["light_freighter", "freight"]:
		_check(tags.has(descriptive_tag), "berth publishes role-specific compatibility: %s" % descriptive_tag)

	var envelope := module.get_ship_clearance_envelope()
	_check((envelope.full_size as Vector3).is_equal_approx(Vector3(23.0, 10.0, 35.0)), "protected structural envelope is exact")
	_check((envelope.declared_flight_size as Vector3).is_equal_approx(Vector3(17.0, 7.1, 27.5)), "audit records the current flight hull size")
	_check((envelope.declared_deployed_size as Vector3).x >= 19.2, "envelope accounts for the deployed cargo ramp")
	_check(not bool(envelope.authenticated_dimensions), "all craft dimensions remain provisional")
	_check(is_equal_approx(float(envelope.deck_contact_root_offset), -1.25), "dock root aligns hull contact to the apron")
	_check(is_equal_approx(float(envelope.interior_deck_root_offset), 0.55), "dock root records moving-interior deck alignment")


func _test_physical_walkable_surfaces(module: JovianFreightBerth) -> void:
	var centreline_samples := PackedVector3Array([
		Vector3(0, 1.5, -4.2),
		Vector3(0, 1.5, -2.0),
		Vector3(0, 1.5, 2.0),
		Vector3(0, 1.5, 6.5),
		Vector3(0, 1.5, 9.0),
		Vector3(0, 1.5, 13.5),
		Vector3(0, 1.5, 18.5),
		Vector3(0, 1.5, 23.5),
		Vector3(0, 1.5, 28.5),
		Vector3(0, 1.5, 33.5),
		Vector3(0, 1.5, 38.5),
		Vector3(0, 1.5, 43.5),
		Vector3(0, 1.5, 47.5),
	])
	var every_supported := true
	var every_surface_flush := true
	for sample in centreline_samples:
		var hit := await _ray_local(module, sample, Vector3(sample.x, -1.0, sample.z))
		if hit.is_empty():
			every_supported = false
		else:
			every_surface_flush = every_surface_flush and absf(module.to_local(hit.position).y) <= 0.025
	_check(every_supported, "connection and all segmented apron leaves provide continuous floor support")
	_check(every_surface_flush, "connection and apron meet at one physical deck elevation")

	var side_samples := PackedVector3Array([
		Vector3(-18.7, 1.5, 18.0),
		Vector3(-18.7, 1.5, 28.0),
		Vector3(-18.7, 1.5, 40.0),
		Vector3(12.8, 1.5, 29.0),
		Vector3(15.1, 1.5, 29.0),
		Vector3(17.6, 1.5, 29.0),
		Vector3(19.2, 1.5, 29.0),
	])
	var every_side_supported := true
	for sample in side_samples:
		if (await _ray_local(module, sample, Vector3(sample.x, -1.0, sample.z))).is_empty():
			every_side_supported = false
	_check(every_side_supported, "cargo rack and service-room routes are physically supported")

	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var route_clear := true
	for sample in [Vector3(0, 1.08, -3.4), Vector3(0, 1.08, 3.0), Vector3(0, 1.08, 8.5), Vector3(10.4, 1.08, 29.0), Vector3(12.6, 1.08, 29.0), Vector3(14.6, 1.08, 29.0)]:
		if not (await _intersect_shape_local(module, capsule, Transform3D(Basis.IDENTITY, sample), 32)).is_empty():
			route_clear = false
	_check(route_clear, "player capsule clears approach and cargo-transfer centreline")


func _test_ship_envelope_is_structurally_clear(module: JovianFreightBerth) -> void:
	var envelope := module.get_ship_clearance_envelope()
	var shape := BoxShape3D.new()
	shape.size = (envelope.half_extents as Vector3) * 2.0
	var hits := await _intersect_shape_world(module, shape, envelope.world_transform as Transform3D, 128)
	var only_floor_support := true
	var floor_support_count := 0
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider != null and str(collider.name).begins_with("ApronDeck"):
			floor_support_count += 1
		else:
			only_floor_support = false
	_check(only_floor_support and floor_support_count >= 2, "protected parked-ship envelope meets only its load-bearing apron floor")
	var centre := (envelope.world_transform as Transform3D).origin
	_check(module.contains_ship_clearance(centre), "protected envelope contains its centre")
	_check(module.contains_ship_clearance((envelope.world_transform as Transform3D) * Vector3(11.49, 4.99, 17.49)), "protected envelope includes its declared interior boundary")
	_check(not module.contains_ship_clearance((envelope.world_transform as Transform3D) * Vector3(11.51, 0, 0)), "protected envelope rejects points beyond its width")

	# The ship's bottom is allowed to meet, but never penetrate, the real apron.
	var dock := module.get_berth_transform()
	var deck_hit := await _ray_world(module, dock.origin + Vector3.UP * 0.2, dock.origin + Vector3.DOWN * 2.0)
	_check(not deck_hit.is_empty(), "dock root sits above a real load-bearing apron")
	if not deck_hit.is_empty():
		_check(absf(module.to_local(deck_hit.position).y) <= 0.025, "parked hull contact offset lands exactly on deck elevation")

	var motion := module.get_equipment_motion_contract()
	_check(float(motion.minimum_vertical_separation) >= 0.55, "animated hook always clears the protected ship top")
	_check(float(motion.trolley_travel_min) >= -7.2 and float(motion.trolley_travel_max) <= 7.2, "trolley travel stays between the collision-backed gantry legs")
	_check(bool(motion.motion_is_presentation_only), "equipment motion cannot mutate berth authority")


func _test_service_door_lifecycle(module: JovianFreightBerth) -> void:
	var door := module.get_service_access()
	_check(door != null, "freight control exposes a reusable StationDoor")
	if door == null:
		return
	_check(door.collision_layer == PhysicsLayers.INTERACTABLE and door.collision_mask == 0, "door follows canonical interaction collision")
	_check(not door.locked and not door.deferred_access and door.can_interact(module), "supported service room begins operable")
	_check(str(door.get_meta("evidence_status")) == "creator_roster_supported_modern_interpretation", "door retains module evidence status")
	_check("FREIGHT CONTROL" in door.get_interaction_prompt(), "door prompt names its diegetic room")
	_check(door.is_portal_blocked(), "closed service door owns a physical pressure barrier")
	_check(not (await _ray_through_door(door)).is_empty(), "closed service threshold blocks a real ray")

	_check(door.interact(module), "service door accepts opening interaction")
	_check(door.get_state() == StationDoor.DoorState.OPENING, "service door enters deterministic opening state")
	_check(not (await _ray_through_door(door)).is_empty(), "portal remains blocked during motion")
	var service_door_opened := await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(service_door_opened, "service door completes its opening motion inside its physics-frame budget")
	_check(door.is_open() and not door.is_portal_blocked(), "fully open service access clears its physical portal")
	_check((await _ray_through_door(door)).is_empty(), "open threshold is unobstructed")

	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var threshold := door.to_global(Vector3(0, 1.08, 0))
	_check((await _intersect_shape_world(module, capsule, Transform3D(Basis.IDENTITY, threshold), 32)).is_empty(), "production player capsule clears the open door")
	_check(door.interact(module), "service door accepts repeatable close")
	var service_door_closed := await _wait_for_door_state(door, StationDoor.DoorState.CLOSED, 1.5)
	_check(service_door_closed, "service door completes its closing motion inside its physics-frame budget")
	_check(door.is_portal_blocked(), "closed lifecycle restores the pressure barrier")


func _test_animated_equipment(module: JovianFreightBerth) -> void:
	_check(module.get_animated_equipment_count() >= 3, "crane, trolley, and hoist are independently addressable")
	module.set_equipment_animation_enabled(false)
	_check(not module.is_equipment_animation_enabled(), "equipment animation can be paused deterministically")
	var before := module.get_equipment_state()
	module.advance_equipment_simulation(8.25)
	var after := module.get_equipment_state()
	_check(float(after.elapsed) > float(before.elapsed), "manual simulation advances equipment time")
	_check(not (after.trolley_local_position as Vector3).is_equal_approx(before.trolley_local_position as Vector3), "gantry trolley physically changes local position")
	_check(absf((after.trolley_local_position as Vector3).x) <= 7.2, "animated trolley respects its published travel")
	var hook_local := after.hook_local_position as Vector3
	var hook_lowest_y := (after.trolley_local_position as Vector3).y + hook_local.y - 0.66
	_check(hook_lowest_y >= 10.75 and hook_lowest_y <= 11.25, "animated hoist respects its published visual clearance limits")
	module.set_equipment_animation_enabled(true)
	_check(module.is_equipment_animation_enabled(), "equipment can resume for live presentation")


func _test_direct_world_berth_lifecycle(module: JovianFreightBerth) -> void:
	var spec := module.get_berth_specification()
	var berth := BERTH_SCENE.instantiate() as ShipBerth
	berth.name = "DirectWorldJovianFreightBerth"
	berth.berth_id = spec.berth_id
	berth.compatibility_tags = (spec.compatibility_tags as PackedStringArray).duplicate()
	berth.landing_half_extents = spec.landing_half_extents
	_test_root.add_child(berth)
	berth.global_transform = spec.dock_transform
	await process_frame
	await physics_frame
	_check(berth.get_parent() == _test_root, "production lease fixture is a direct world-level child, not nested in the module")
	_check(berth.get_dock_transform().is_equal_approx(module.get_berth_transform()), "direct ShipBerth exactly matches the module marker")
	_check(berth.get_validation_errors().is_empty(), "direct ShipBerth validates")
	_check(berth.can_accept(JOVIAN_DEFINITION), "production Jovian definition matches the published freight tags")

	var requester := Node3D.new()
	requester.name = "JovianLeaseRequester"
	_test_root.add_child(requester)
	var token := berth.try_reserve(requester, JOVIAN_DEFINITION)
	_check(not token.is_empty(), "Jovian can reserve its direct berth")
	_check(berth.occupy(requester, token), "Jovian lease converts to physical occupancy")
	_check(berth.get_occupant() == requester and berth.get_reserved_ship_id() == &"jovian_provisional", "occupied berth retains craft identity")
	_check(not berth.release(requester, &"stale"), "stale token cannot release freight occupancy")
	_check(berth.release(requester, token), "authoritative lease releases cleanly")
	_check(not berth.is_reserved() and not berth.is_occupied(), "release clears both freight claims")
	requester.queue_free()
	berth.queue_free()
	await process_frame
	await process_frame


func _test_materials_signage_and_detail(module: JovianFreightBerth) -> void:
	_check(module.get_cargo_unit_count() == 8, "module contains eight independently tagged physical cargo units")
	_check(module.get_service_detail_count() >= 12, "service room and dock expose substantial operational detail")
	var cargo := module.find_children("CargoUnit*", "StaticBody3D", true, false)
	_check(cargo.size() == 8, "eight cargo bodies exist in the physical scene tree")
	var all_cargo_tagged := true
	for candidate in cargo:
		all_cargo_tagged = all_cargo_tagged and bool(candidate.get_meta("station_cargo_unit", false)) \
			and not str(candidate.get_meta("cargo_unit_id", "")).is_empty()
	_check(all_cargo_tagged, "each cargo body has stable semantic identity")
	_check(module.find_children("FreightSign*", "Label3D", true, false).size() >= 4, "freight node, berth, service, and safety signage are present")
	_check(module.find_children("DockGuideLight*", "OmniLight3D", true, false).size() >= 12, "apron uses dense readable guide lighting")
	_check(module.find_children("ApronWorkLight*", "SpotLight3D", true, false).size() == 2, "gantry provides two shadowed work lights")
	_check(module.find_children("ObservationPane*", "MeshInstance3D", true, false).size() == 5, "service room has a five-pane observation band")
	var panel := module.find_child("ApronDeck01", true, false) as StaticBody3D
	var visual := panel.get_node_or_null("Mesh") as MeshInstance3D if panel != null else null
	var material := visual.material_override as StandardMaterial3D if visual != null else null
	_check(material != null and material.albedo_texture != null and material.uv1_triplanar, "main deck uses project PBR panel texture with triplanar mapping")
	_check(visual != null and visual.mesh is ArrayMesh, "load-bearing deck renders custom chamfered geometry")
	_check(module.find_children("*", "CylinderMesh", true, false).is_empty(), "scene does not mistake resources for nodes")
	_check(module.find_children("*", "MeshInstance3D", true, false).size() >= 150, "module has a high-detail rendered assembly rather than a generic blockout")


## The freight-handling infrastructure a berth this size has to own before it
## reads as the busiest working part of the yard rather than a parking slab.
func _test_handling_infrastructure(module: JovianFreightBerth) -> void:
	_check(
		module.get_handling_fixture_count() >= JovianFreightBerth.HANDLING_FIXTURE_TARGET,
		"berth owns at least %d collision-backed handling fixtures (%d)"
			% [JovianFreightBerth.HANDLING_FIXTURE_TARGET, module.get_handling_fixture_count()]
	)
	var classes := module.get_handling_fixture_classes()
	print("FREIGHT_HANDLING_FIXTURES: ", module.get_handling_fixture_count(), " ", classes)
	# The roster has to span the whole job, not sixty copies of one bollard.
	for required_class in [
		&"approach-portal-mast",
		&"envelope-bollard",
		&"staged-pallet",
		&"staged-crate",
		&"rack-deck",
		&"rack-stored-crate",
		&"stores-locker",
		&"gas-bottle",
		&"boarding-step",
		&"boarding-platform",
		&"gantry-catwalk",
		&"catwalk-ladder-stringer",
		&"crane-control-cab",
		&"manifest-kiosk",
	]:
		_check(
			int(classes.get(required_class, 0)) > 0,
			"handling roster covers the %s class" % required_class
		)
	classes[&"envelope-bollard"] = 999
	_check(
		int(module.get_handling_fixture_classes().get(&"envelope-bollard", 0)) != 999,
		"the handling fixture class breakdown is detached from module state"
	)

	# Godot renames same-named siblings, so a set built under one shared name can
	# only ever be resolved as one node by name. Every fixture set this pass builds
	# is named per station side and index; these are the sets a name-driven audit
	# has to be able to see whole.
	for prefix in ["EnvelopeBollardPort", "EnvelopeBollardStarboard", "LashingRingPort", "LashingRingStarboard"]:
		_check(
			module.find_children("%s*" % prefix, "", true, false).size() >= 4,
			"the %s set is addressable per station position, not collapsed under one name" % prefix
		)
	_check(module.find_children("BoardingStep*", "StaticBody3D", true, false).size() == 7, "the boarding flight has seven independently addressable steps")
	_check(module.find_children("StoresLocker0*", "StaticBody3D", true, false).size() == 5, "the stores bank has five independently addressable lockers")
	_check(module.find_children("CatwalkLadderRung*", "MeshInstance3D", true, false).size() == 12, "the gantry ladder is fully rungged")

	var typed := module.get_typed_audit_report()
	_check(
		typed.handling_fixture_count == module.get_handling_fixture_count()
		and not typed.handling_fixture_classes.is_empty(),
		"typed audit publishes the handling roster and its class breakdown"
	)
	typed.handling_fixture_classes["mutation"] = 1
	_check(
		not module.get_typed_audit_report().handling_fixture_classes.has("mutation"),
		"typed handling roster is detached"
	)


## The berth-wide "nothing floats" sweep.
##
## The standing complaint this exists for is "random objects floating in the air
## and it ruins the experience", and the rosters that answer it elsewhere in the
## suite are hand-listed paths. This module is generated, so a path roster can
## only ever cover what someone remembered to add. Instead every drawn mesh the
## module builds must share volume with, or come within `SEAT_TOLERANCE` of, some
## other drawn mesh that is not its own ancestor or descendant.
##
## Ray-against-collision cannot answer this class here: most of what hangs off
## this module - guide lenses, sign boards, catwalk rails, the crane cab - hangs
## off structure that is drawn but not collidable, and in open space that ray
## falls forever. Measured live before the fix, the module floated 39 pieces:
## eighteen dock guide lenses at 0.120 - 0.220 m, twelve dock guide strips at
## 0.073, the dock centreline at 0.068, both service-room utility trunks at 0.100
## (touching neither floor nor roof), both trolley rails 0.050 under the header
## they run on, three status bars and the six cabinet indicator strips standing
## clear of the panels they read from.
const SEAT_TOLERANCE := 0.002


func _test_nothing_drawn_floats(module: JovianFreightBerth) -> void:
	var floating := _floating_meshes(module)
	print("FLOATING_FREIGHT_MESHES: ", floating)
	_check(
		floating.is_empty(),
		"every drawn surface in the freight berth bears on other drawn geometry instead of hanging in space"
	)

	# Structured red, on the exact shape of the defect this module was repaired for
	# today: a crate stacked on the crate below it. The port bay's top staged crate
	# bears 0.010 m into the crate under it and carries nothing, so lifting it is
	# the cleanest single mutation available. 0.100 m is deliberately close to the
	# size of the hovers actually reported - thirteen pieces at 0.020 - 0.090 m, and
	# the eight rack crates at 0.040 - 0.070 - so the guard is proven to bite at
	# roughly the scale of the real defect rather than only at an absurd one.
	#
	# The mutation is asserted by name as well as by count. This sweep compares
	# axis-aligned bounds, and the module under test is deliberately placed at a
	# 23 degree yaw, which inflates every box: a lifted piece can pick up a
	# spurious neighbour metres away and read as seated. Naming the piece is what
	# makes the red a statement about this crate rather than about the roster.
	var crate := module.find_child("StagedCrateUpperPort", true, false) as Node3D
	if crate == null:
		_check(false, "the structured-red fixture resolves")
		return
	var seated := crate.transform
	crate.position.y += 0.1
	var mutated := _floating_meshes(module)
	var named := false
	for entry in mutated:
		named = named or entry.contains("StagedCrateUpperPort")
	_check(
		named,
		"lifting the seated staged crate 0.10 m off the crate below it turns the sweep red (%s)"
			% ", ".join(mutated)
	)
	crate.transform = seated
	_check(_floating_meshes(module).is_empty(), "restoring the fixture returns the sweep to green")


func _floating_meshes(module: JovianFreightBerth) -> PackedStringArray:
	var drawn: Array[Dictionary] = []
	for candidate in module.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		drawn.append({
			"node": mesh_instance,
			"box": (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs(),
		})
	var floating := PackedStringArray()
	for entry in drawn:
		var piece := entry["node"] as MeshInstance3D
		var box := (entry["box"] as AABB).grow(SEAT_TOLERANCE)
		var seated := false
		for other_entry in drawn:
			var other := other_entry["node"] as MeshInstance3D
			if other == piece or piece.is_ancestor_of(other) or other.is_ancestor_of(piece):
				continue
			if box.intersects(other_entry["box"] as AABB):
				seated = true
				break
		if not seated:
			floating.append("%s @ %s" % [module.get_path_to(piece), str(box.get_center())])
	return floating


## The other half of the same promise: solid-looking apparatus a player can reach
## has to actually stop them. A freight berth is where a tow tractor gets driven,
## so every registered handling fixture is shape-cast and must answer.
func _test_handling_fixtures_are_solid(module: JovianFreightBerth) -> void:
	var permeable := PackedStringArray()
	for candidate in module.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if not bool(body.get_meta("station_handling_fixture", false)):
			continue
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			permeable.append("%s <no shape>" % body.name)
			continue
		for shape_node in shapes:
			var collision := shape_node as CollisionShape3D
			if collision.disabled or collision.shape == null:
				permeable.append("%s <disabled>" % body.name)
	var registered := 0
	for fixture in module.find_children("*", "StaticBody3D", true, false):
		if bool((fixture as StaticBody3D).get_meta("station_handling_fixture", false)):
			registered += 1
	_check(
		registered == module.get_handling_fixture_count(),
		"every published handling fixture is a real static body in the tree (%d of %d)"
			% [registered, module.get_handling_fixture_count()]
	)
	_check(permeable.is_empty(), "no handling fixture is a solid-looking mesh a player passes through: %s" % ", ".join(permeable))

	# The one place this module is allowed to be empty is the protected hull
	# volume, and nothing the handling pass added may creep into it.
	var envelope := module.get_ship_clearance_envelope()
	var shape := BoxShape3D.new()
	shape.size = (envelope.half_extents as Vector3) * 2.0
	var intruders := PackedStringArray()
	for hit in await _intersect_shape_world(module, shape, envelope.world_transform as Transform3D, 256):
		var collider := hit.get("collider") as Node
		if collider != null and not str(collider.name).begins_with("ApronDeck"):
			intruders.append(str(collider.name))
	_check(intruders.is_empty(), "no handling fixture stands inside the parked craft's protected volume: %s" % ", ".join(intruders))


func _test_collision_contract(module: JovianFreightBerth) -> void:
	var bodies := module.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() >= 100, "module contains extensive collision-backed architecture and infrastructure")
	var canonical := true
	var all_shaped := true
	for candidate in bodies:
		var body := candidate as StaticBody3D
		var valid_layer := body.collision_layer == WORLD_LAYER
		if body.name == "PortalBlocker":
			valid_layer = body.collision_layer == WORLD_LAYER or body.collision_layer == 0
		canonical = canonical and valid_layer and body.collision_mask == 0
		if body.find_children("*", "CollisionShape3D", true, false).is_empty():
			all_shaped = false
	_check(canonical, "all static collision follows canonical World layer/mask")
	_check(all_shaped, "every static body owns at least one real collision shape")
	_check(module.get_service_access().collision_layer == PhysicsLayers.INTERACTABLE, "only StationDoor discovery uses Interactable layer")


func _test_cleanup(module: JovianFreightBerth) -> void:
	var module_ref: WeakRef = weakref(module)
	var door_ref: WeakRef = weakref(module.get_service_access())
	var cargo_ref: WeakRef = weakref(module.find_child("CargoUnit01", true, false))
	var trolley_ref: WeakRef = weakref(module.find_child("AnimatedTrolley", true, false))
	module.queue_free()
	module = null
	await process_frame
	await physics_frame
	await process_frame
	_check(module_ref.get_ref() == null, "module root cleans up without a retained instance")
	_check(door_ref.get_ref() == null and cargo_ref.get_ref() == null and trolley_ref.get_ref() == null, "door, cargo, and animated equipment clean up with the module")
	_test_root.queue_free()
	await process_frame


func _ray_local(module: JovianFreightBerth, local_from: Vector3, local_to: Vector3) -> Dictionary:
	return await _ray_world(module, module.to_global(local_from), module.to_global(local_to))


func _ray_world(module: JovianFreightBerth, world_from: Vector3, world_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(world_from, world_to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _ray_through_door(door: StationDoor) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(
		door.to_global(Vector3(0, 1.7, -1.7)),
		door.to_global(Vector3(0, 1.7, 1.7)),
		WORLD_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return door.get_world_3d().direct_space_state.intersect_ray(query)


func _intersect_shape_local(module: JovianFreightBerth, shape: Shape3D, local_transform: Transform3D, max_results: int) -> Array[Dictionary]:
	return await _intersect_shape_world(module, shape, module.global_transform * local_transform, max_results)


func _intersect_shape_world(module: JovianFreightBerth, shape: Shape3D, world_transform: Transform3D, max_results: int) -> Array[Dictionary]:
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = world_transform
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_shape(query, max_results)


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus a fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for a door to reach `expected_state` on the physics clock, which is the
## clock `StationDoor` actually advances its panel on.
##
## The budget deliberately counts physics steps rather than wall-clock seconds. A
## `SceneTree` timer counts Godot's smoothed idle delta, and under load the engine
## drops physics steps rather than letting the simulation spiral, so the timer runs
## out while the panel has been stepped only part of the way. The wait then
## returned silently and the caller asserted on a door caught mid-travel — a false
## failure, not a defect. Counting frames gives the door the same amount of
## simulation however busy the box is, and still fails a genuinely stuck door
## because the budget remains finite.
##
## Returns whether the state was actually reached so callers can assert on it
## rather than assume it.
func _wait_for_door_state(door: StationDoor, expected_state: int, travel_seconds: float) -> bool:
	var frame_budget := _frame_budget(travel_seconds)
	var frames := 0
	while is_instance_valid(door) and door.get_state() != expected_state:
		if frames >= frame_budget:
			break
		await physics_frame
		frames += 1
	await process_frame
	return is_instance_valid(door) and door.get_state() == expected_state


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_FREIGHT_BERTH_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
