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
	_test_tow_handoff_rail(module)
	_test_berth_specification(module)
	await _test_physical_walkable_surfaces(module)
	await _test_ship_envelope_is_structurally_clear(module)
	await _test_service_door_lifecycle(module)
	await _test_animated_equipment(module)
	await _test_direct_world_berth_lifecycle(module)
	_test_materials_signage_and_detail(module)
	_test_floor_label_orientation(module)
	_test_transfer_lane_label_orientation(module)
	_test_handling_infrastructure(module)
	_test_recessed_lashing_ring_profile(module)
	_test_lashing_ring_visual_allocation(module)
	_test_catwalk_ladder_hoop_visual_allocation(module)
	_test_catwalk_ladder_rung_batch(module)
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


## The solid FreightApproachGantry exposed that the old east rail crossed the
## only declared tow handoff. Its south span guarded sub-capsule coplanar seams,
## not a fall edge, so the rail and its above-deck support now begin at z=2.20.
## Freeze the one-sided correction without weakening the opposite exposed edge.
func _test_tow_handoff_rail(module: JovianFreightBerth) -> void:
	var east_rail: StaticBody3D
	var west_rail: StaticBody3D
	for candidate in module.find_children("ApproachRail*", "StaticBody3D", true, false):
		var rail := candidate as StaticBody3D
		if rail.position.x > 0.0:
			east_rail = rail
		else:
			west_rail = rail
	_check(east_rail != null and west_rail != null, "both connection-lattice edge rails resolve")
	if east_rail == null or west_rail == null:
		return
	var east_shape := east_rail.get_node_or_null(^"Collision") as CollisionShape3D
	var west_shape := west_rail.get_node_or_null(^"Collision") as CollisionShape3D
	var east_cylinder := east_shape.shape as CylinderShape3D if east_shape != null else null
	var west_cylinder := west_shape.shape as CylinderShape3D if west_shape != null else null
	_check(
		east_rail.position.is_equal_approx(Vector3(3.45, 1.12, 5.25))
		and east_cylinder != null and is_equal_approx(east_cylinder.height, 6.1),
		"east rail refreezes centre 3.35 -> 5.25 and length 9.9 -> 6.1 so world span 27.20..31.00 becomes 31.00..37.10"
	)
	_check(
		west_rail.position.is_equal_approx(Vector3(-3.45, 1.12, 2.1))
		and west_cylinder != null and is_equal_approx(west_cylinder.height, 12.5),
		"opposite exposed-edge rail remains unchanged"
	)
	var east_support_at_new_edge := false
	var stale_support_in_tow_lane := false
	var retained_lattice_leg := false
	for candidate in module.find_children("RailPost*", "StaticBody3D", true, false):
		var post := candidate as StaticBody3D
		if is_equal_approx(post.position.x, 3.45):
			east_support_at_new_edge = east_support_at_new_edge or is_equal_approx(post.position.z, 2.2)
			stale_support_in_tow_lane = stale_support_in_tow_lane or is_equal_approx(post.position.z, 0.2)
	for candidate in module.find_children("LatticePost*", "StaticBody3D", true, false):
		var leg := candidate as StaticBody3D
		retained_lattice_leg = retained_lattice_leg or (
			is_equal_approx(leg.position.x, 3.45) and is_equal_approx(leg.position.z, 0.2)
		)
	_check(
		east_support_at_new_edge and not stale_support_in_tow_lane and retained_lattice_leg,
		"only the +X above-deck RailPost moves local z 0.20 -> 2.20; its below-deck LatticePost stays structural"
	)


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

	# Regression for the reported service-room floor z-fight. This is the F3 hit
	# location converted to module-local space; the ceramic finish must be the
	# first surface hit and must remain seated just above the structural shelf.
	var room_floor_hit := await _ray_local(
		module,
		Vector3(18.352, 1.5, 27.813),
		Vector3(18.352, -1.0, 27.813)
	)
	var room_floor_collider := room_floor_hit.get("collider") as Node
	_check(
		room_floor_collider != null and room_floor_collider.name == "RoomFloor",
		"service-room finish owns the visible floor plane above its structural shelf"
	)
	_check(
		not room_floor_hit.is_empty()
		and is_equal_approx(
			module.to_local(room_floor_hit.position).y,
			JovianFreightBerth.ROOM_FLOOR_FINISH_SEAT
		),
		"service-room finish keeps the station anti-z-fight seat"
	)

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
	var parent := module.get_parent()
	parent.remove_child(module)
	var detached_before := _freight_mutator_snapshot(module)
	module.set_equipment_animation_enabled(true)
	module.set_module_enabled(false)
	module.advance_equipment_simulation(2.0)
	var detached_after := _freight_mutator_snapshot(module)
	_check(
		not module.is_inside_tree() and detached_after == detached_before,
		"a detached freight berth rejects animation, clock, and module mutations atomically"
	)
	parent.add_child(module)
	await process_frame
	module.set_module_enabled(false)
	var live_disabled := module.get_lifecycle_contract()
	module.set_module_enabled(true)
	var live_enabled := module.get_lifecycle_contract()
	_check(
		not bool(live_disabled.enabled)
			and bool(live_disabled.visible_matches_enabled)
			and bool(live_disabled.collision_matches_enabled)
			and bool(live_enabled.enabled)
			and bool(live_enabled.visible_matches_enabled)
			and bool(live_enabled.collision_matches_enabled),
		"the reattached freight berth accepts fresh module lifecycle mutations"
	)
	module.set_equipment_animation_enabled(true)
	var reattached_before := module.get_equipment_state()
	module.advance_equipment_simulation(2.0)
	_check(
		float(module.get_equipment_state().elapsed) > float(reattached_before.elapsed),
		"the same freight berth accepts a fresh crane advance after re-entry"
	)
	module.set_equipment_animation_enabled(true)
	_check(module.is_equipment_animation_enabled(), "equipment can resume for live presentation")
	await _test_queued_equipment_currentness()


func _test_queued_equipment_currentness() -> void:
	var queued_module := MODULE_SCENE.instantiate() as JovianFreightBerth
	_check(queued_module != null, "queued freight lifecycle fixture instantiates")
	if queued_module == null:
		return
	_test_root.add_child(queued_module)
	await process_frame
	await physics_frame
	var queued_before := _freight_mutator_snapshot(queued_module)
	queued_module.queue_free()
	queued_module.set_equipment_animation_enabled(false)
	queued_module.set_module_enabled(false)
	queued_module.advance_equipment_simulation(2.0)
	var queued_after := _freight_mutator_snapshot(queued_module)
	_check(
		queued_module.is_inside_tree()
			and queued_module.is_queued_for_deletion()
			and queued_after == queued_before,
		"a queued freight berth rejects animation, clock, and module mutations atomically"
	)
	await process_frame


func _freight_mutator_snapshot(module: JovianFreightBerth) -> Dictionary:
	return {
		"equipment": module.get_equipment_state(),
		"animation_enabled": module.is_equipment_animation_enabled(),
		"module_enabled": module.is_module_enabled(),
		"processing": module.is_processing(),
		"lifecycle": module.get_lifecycle_contract(),
		"collision": module.get_collision_contract(),
	}.duplicate(true)


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
	_test_manufactured_material_hierarchy(module)
	_check(visual != null and visual.mesh is ArrayMesh, "load-bearing deck renders custom chamfered geometry")
	_check(module.find_children("*", "CylinderMesh", true, false).is_empty(), "scene does not mistake resources for nodes")
	_check(module.find_children("*", "MeshInstance3D", true, false).size() >= 150, "module has a high-detail rendered assembly rather than a generic blockout")


func _test_manufactured_material_hierarchy(module: JovianFreightBerth) -> void:
	var materials := module.get("_materials") as Dictionary
	var specs := [
		["ceramic_floor", Color("b8c2be"), 0.22, 0.54, JovianFreightBerth.WALKED_PANEL_SURFACE_SCALE, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS],
		["deck", Color("29434d"), 0.62, 0.47, JovianFreightBerth.WALKED_PANEL_SURFACE_SCALE, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS],
		["deck_grip", Color("1b2c32"), 0.36, 0.73, JovianFreightBerth.WALKED_PANEL_SURFACE_SCALE, StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS],
		["steel_blue", Color("315868"), 0.68, 0.28, JovianFreightBerth.PANEL_SURFACE_SCALE, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS],
		["graphite", Color("172329"), 0.55, 0.48, JovianFreightBerth.PANEL_SURFACE_SCALE, StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS],
		["deep_blue", Color("102d3b"), 0.52, 0.43, JovianFreightBerth.PANEL_SURFACE_SCALE, StationSurfaceKit.TRIM_CLEARCOAT, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS],
		["ceramic", Color("d6dedb"), 0.32, 0.34, JovianFreightBerth.PANEL_SURFACE_SCALE, StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS],
		["ceramic_warm", Color("b8c2be"), 0.30, 0.39, JovianFreightBerth.PANEL_SURFACE_SCALE, StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS],
		["orange", Color("e79338"), 0.24, 0.54, JovianFreightBerth.PANEL_SURFACE_SCALE, StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS],
	]
	var exact := true
	for spec in specs:
		var material := materials.get(spec[0]) as StandardMaterial3D
		exact = exact and material != null
		if material == null:
			continue
		exact = exact \
			and material.albedo_color.is_equal_approx(spec[1] as Color) \
			and is_equal_approx(material.metallic, float(spec[2])) \
			and is_equal_approx(material.roughness, float(spec[3])) \
			and material.albedo_texture != null \
			and material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH \
			and material.normal_enabled \
			and material.normal_texture != null \
			and material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH \
			and material.roughness_texture != null \
			and material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH \
			and material.uv1_triplanar \
			and material.uv1_world_triplanar \
			and material.uv1_scale.is_equal_approx(Vector3.ONE * float(spec[4])) \
			and material.clearcoat_enabled \
			and is_equal_approx(material.clearcoat, float(spec[5])) \
			and is_equal_approx(material.clearcoat_roughness, float(spec[6]))
	_check(exact, "apron deck, grip, frame, trim, and service surfaces retain their hues under distinct StationSurfaceKit finishes")


## The berth extends from the station connection toward local +Z. A player
## approaching the freight apron along that primary outbound route therefore
## needs the floor legend's glyph-up axis to point +Z while its face stays +Y.
func _test_floor_label_orientation(module: JovianFreightBerth) -> void:
	var matching_labels: Array[Label3D] = []
	for candidate in module.find_children("*", "Label3D", true, false):
		var label := candidate as Label3D
		if label != null and label.text == "BERTH F-01":
			matching_labels.append(label)
	_check(matching_labels.size() == 1, "exactly one BERTH F-01 floor legend is present")
	if matching_labels.size() != 1:
		return
	var berth_label := matching_labels[0]
	var basis := berth_label.transform.basis
	_check(
		berth_label.position.is_equal_approx(Vector3(0.0, 0.14, 9.8))
		and berth_label.font_size == 32
		and is_equal_approx(berth_label.pixel_size, 0.46 / 32.0)
		and berth_label.modulate.is_equal_approx(Color("ffb45b")),
		"BERTH F-01 preserves its authored position, physical size, and amber colour"
	)
	_check(basis.z.is_equal_approx(Vector3.UP), "BERTH F-01 remains painted face-up on the floor plane")
	_check(basis.y.is_equal_approx(Vector3.BACK), "BERTH F-01 glyph-up follows the documented local +Z outbound reader direction")
	_check(is_equal_approx(basis.determinant(), 1.0), "BERTH F-01 rotation remains a proper orientation with determinant +1")
	_check(berth_label.find_children("*", "CollisionObject3D", true, false).is_empty(), "BERTH F-01 remains presentation-only and collision-free")


## The transfer-lane legend is read while travelling from cargo transfer toward
## the service threshold. Derive that direction from the live route contract so
## this test follows the route if its authored markers move or the module rotates.
func _test_transfer_lane_label_orientation(module: JovianFreightBerth) -> void:
	var matching_labels: Array[Label3D] = []
	for candidate in module.find_children("*", "Label3D", true, false):
		var label := candidate as Label3D
		if label != null and label.text == "KEEP TRANSFER LANE CLEAR":
			matching_labels.append(label)
	_check(matching_labels.size() == 1, "exactly one KEEP TRANSFER LANE CLEAR floor legend is present")
	if matching_labels.size() != 1:
		return
	var transfer_label := matching_labels[0]
	var route_direction := (
		module.get_route_transform(&"service-threshold").origin
		- module.get_route_transform(&"cargo-transfer").origin
	).normalized()
	var basis := transfer_label.global_transform.basis.orthonormalized()
	_check(
		transfer_label.position.is_equal_approx(Vector3(12.7, 0.13, 29.0))
		and transfer_label.font_size == 32
		and is_equal_approx(transfer_label.pixel_size, 0.3 / 32.0)
		and transfer_label.modulate.is_equal_approx(Color("ffb45b")),
		"KEEP TRANSFER LANE CLEAR preserves its authored position, physical size, and amber colour"
	)
	_check(basis.z.is_equal_approx(module.global_basis.y.normalized()), "KEEP TRANSFER LANE CLEAR remains painted face-up on the floor plane")
	_check(basis.y.is_equal_approx(route_direction), "KEEP TRANSFER LANE CLEAR glyph-up follows cargo-transfer to service-threshold")
	_check(is_equal_approx(basis.determinant(), 1.0), "KEEP TRANSFER LANE CLEAR rotation remains a proper orientation with determinant +1")
	_check(transfer_label.find_children("*", "CollisionObject3D", true, false).is_empty(), "KEEP TRANSFER LANE CLEAR remains presentation-only and collision-free")
	var old_angle_basis := Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, deg_to_rad(90.0)))
	var old_angle_glyph_up := (module.global_basis * old_angle_basis).orthonormalized().y
	_check(not old_angle_glyph_up.is_equal_approx(route_direction), "the old +90-degree transfer-lane label mutation remains red")


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


func _test_catwalk_ladder_hoop_visual_allocation(
		module: JovianFreightBerth
	) -> void:
	var audit := module.get_catwalk_ladder_hoop_visual_allocation_audit()
	if not bool(audit.valid):
		print("JOVIAN_CATWALK_LADDER_HOOP_ERRORS: ", audit.errors)
	print(
		(
			"JOVIAN_CATWALK_LADDER_HOOPS: nodes %d->%d submissions %d->%d "
			+ "mesh_resources %d->%d copies %d->%d"
		) % [
			int(audit.legacy.renderer_nodes),
			int(audit.current.renderer_nodes),
			int(audit.legacy.surface_submissions),
			int(audit.current.surface_submissions),
			int(audit.legacy.mesh_resource_allocations),
			int(audit.current.mesh_resource_allocations),
			int(audit.legacy.drawn_copies),
			int(audit.current.drawn_copies),
		]
	)
	_check(
		bool(audit.valid)
		and audit.legacy == {
			"renderer_nodes": 4,
			"anchor_nodes": 4,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 4,
			"material_resource_allocations": 1,
		}
		and audit.current == {
			"renderer_nodes": 1,
			"anchor_nodes": 4,
			"drawn_copies": 4,
			"surface_submissions": 1,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		}
		and audit.reductions == {
			"renderer_nodes": 3,
			"anchor_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 3,
			"mesh_resource_allocations": 3,
			"material_resource_allocations": 0,
		}
		and bool(audit.batched)
		and not bool(audit.renderer_values_changed),
		"four visual-only ladder hoops retain stable anchors and copies while visible renderers, submissions, and TorusMesh allocations fall 4 -> 1"
	)
	var paths := audit.node_paths as PackedStringArray
	var transforms := audit.authored_transforms as Array
	var batch := (
		module.get_node_or_null(NodePath(str(audit.batch_path))) as MultiMeshInstance3D
		if not str(audit.batch_path).is_empty() else null
	)
	var shared_mesh := (
		batch.multimesh.mesh as TorusMesh
		if batch != null and batch.multimesh != null else null
	)
	var exact := batch != null and paths.size() == 4 and transforms.size() == 4
	for index in mini(transforms.size(), paths.size()):
		var expected := Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(90.0))),
			Vector3(-14.62, 3.0 + float(index) * 3.0, 28.05)
		)
		var anchor := module.get_node_or_null(NodePath(paths[index])) as MeshInstance3D
		exact = (
			exact
			and (transforms[index] as Transform3D).is_equal_approx(expected)
			and anchor != null
			and anchor.transform.is_equal_approx(expected)
			and not anchor.visible
			and anchor.mesh == shared_mesh
			and anchor.material_override == batch.material_override
			and anchor.layers == batch.layers
			and anchor.cast_shadow == batch.cast_shadow
			and anchor.get_child_count() == 0
			and anchor.get_script() == null
			and anchor.get_meta_list().is_empty()
		)
	var access := module.get_node_or_null(^"GantryAccess") as Node3D
	_check(
		exact
		and shared_mesh != null
		and batch.multimesh.instance_count == 4
		and batch.material_override != null
		and batch.layers == 1
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.get_child_count() == 0
		and access.find_children(
			"CatwalkLadderHoop*", "MeshInstance3D", false, false
		).size() == 4
		and is_equal_approx(
			shared_mesh.inner_radius,
			JovianFreightBerth.CATWALK_LADDER_HOOP_INNER_RADIUS
		)
		and is_equal_approx(
			shared_mesh.outer_radius,
			JovianFreightBerth.CATWALK_LADDER_HOOP_OUTER_RADIUS
		)
		and audit.authored_tessellation == Vector2i(48, 12)
		and audit.live_tessellation == Vector2i(
			shared_mesh.rings, shared_mesh.ring_segments
		)
		and access.find_children(
			"CatwalkLadderStringer*", "StaticBody3D", false, false
		).size() == 2
		and access.find_children(
			"CatwalkLadderRung*", "MeshInstance3D", false, false
		).size() == 12,
		"hoop batch preserves exact transforms, mesh, material, layers, culling/shadows, physical stringers and rung readability"
	)
	_check(
		int(audit.collision_authority_count) == 0
		and not bool(audit.interaction_authority_added)
		and not bool(audit.route_authority_added)
		and not bool(audit.evidence_authority_added)
		and not bool(audit.lifecycle_authority_added)
		and module.get_route_ids().size() == 7,
		"resource sharing adds no authority and preserves the route/evidence boundary"
	)
	(audit.current as Dictionary)["mesh_resource_allocations"] = -1
	(audit.authored_transforms as Array).clear()
	var detached := module.get_catwalk_ladder_hoop_visual_allocation_audit()
	_check(
		int(detached.current.mesh_resource_allocations) == 1
		and (detached.authored_transforms as Array).size() == 4,
		"ladder-hoop batch allocation, path and transform snapshot is deeply detached"
	)
	var baseline_errors := module.get_validation_errors()
	var original_mesh := batch.multimesh.mesh
	batch.multimesh.mesh = shared_mesh.duplicate() as Mesh
	var identity_red := module.get_catwalk_ladder_hoop_visual_allocation_audit()
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has(
			"catwalk_ladder_hoop_batch_payload_drift"
		)
		and module.get_validation_errors().has(
			"module component counts exceed the declared quality budget"
		),
		"RED private hoop batch mesh turns both the local and module validators red"
	)
	batch.multimesh.mesh = original_mesh
	_check(
		bool(module.get_catwalk_ladder_hoop_visual_allocation_audit().valid)
		and module.get_validation_errors() == baseline_errors,
		"restoring the hoop batch mesh returns the pre-mutation validator state"
	)


func _test_catwalk_ladder_rung_batch(module: JovianFreightBerth) -> void:
	var access := module.get_node_or_null(^"GantryAccess") as Node3D
	var batch := access.get_node_or_null(^"CatwalkLadderRungs") as MultiMeshInstance3D if access != null else null
	_check(
		access != null and batch != null and batch.multimesh != null,
		"twelve named gantry ladder rungs resolve through one visual-only MultiMesh"
	)
	if access == null or batch == null or batch.multimesh == null:
		return
	var material_reference := (
		access.get_node(^"CatwalkLadderRung01") as MeshInstance3D
	).material_override
	var exact_anchors := true
	for index in JovianFreightBerth.CATWALK_LADDER_RUNG_COPY_COUNT:
		var rung := access.get_node_or_null(
			NodePath("CatwalkLadderRung%02d" % (index + 1))
		) as MeshInstance3D
		var expected := Transform3D(
			Basis.IDENTITY,
			Vector3(-14.62, 0.6 + float(index), JovianFreightBerth.CATWALK_CENTER_Z + 0.05)
		)
		exact_anchors = (
			exact_anchors
			and rung != null
			and rung.transform.is_equal_approx(expected)
			and not rung.visible
			and rung.mesh != null
			and rung.mesh.get_aabb().size.is_equal_approx(
				JovianFreightBerth.CATWALK_LADDER_RUNG_SIZE
			)
			and rung.material_override == material_reference
			and rung.get_child_count() == 0
		)
	_check(
		exact_anchors,
		"all twelve stable rung paths retain exact transforms, mesh extent and ceramic material"
	)
	var audit := module.get_catwalk_ladder_rung_batch_contract()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "fresh rung batch passes its local audit")
	_check(
		audit.legacy == {
			"renderer_submissions": 12,
			"visible_copies": 12,
			"anchor_nodes": 12,
		}
		and audit.current == {
			"renderer_submissions": 1,
			"visible_copies": 12,
			"anchor_nodes": 12,
		}
		and audit.reductions == {
			"renderer_submissions": 11,
			"visible_copies": 0,
			"anchor_nodes": 0,
		},
		"ladder rung submissions measure 12 -> 1 while copies and stable anchors remain twelve"
	)
	_check(
		batch.multimesh.instance_count == 12
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
			JovianFreightBerth.CATWALK_LADDER_RUNG_SIZE
		)
		and batch.material_override == material_reference
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and not bool(audit.collision_authority)
		and not bool(audit.route_authority)
		and not bool(audit.interaction_authority),
		"batch preserves the visual recipe and owns no collision, route or interaction authority"
	)
	(audit.authored_transforms as Array)[0] = Transform3D.IDENTITY
	_check(
		not ((module.get_catwalk_ladder_rung_batch_contract().authored_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"rung allocation evidence is deeply detached"
	)
	var original_material := batch.material_override
	batch.material_override = null
	_check(
		not bool(module.get_catwalk_ladder_rung_batch_contract().valid)
		and not bool(module.get_performance_contract().within_budget),
		"RED: losing the exact rung material turns both local and module performance audits red"
	)
	batch.material_override = original_material
	_check(
		bool(module.get_catwalk_ladder_rung_batch_contract().valid)
		and bool(module.get_performance_contract().within_budget),
		"restoring the exact rung material returns both audits to green"
	)


func _test_recessed_lashing_ring_profile(module: JovianFreightBerth) -> void:
	var rings: Array[MeshInstance3D] = []
	for candidate in module.find_children("*", "MeshInstance3D", true, false):
		var instance := candidate as MeshInstance3D
		if StringName(instance.get_meta(
			JovianFreightBerth.LASHING_RING_FAMILY_META, &""
		)) == JovianFreightBerth.LASHING_RING_FAMILY_ID:
			rings.append(instance)
	_check(
		rings.size() == JovianFreightBerth.LASHING_RING_COPY_COUNT,
		"the explicit family tag selects exactly eight recessed freight lashing rings"
	)
	var expected: Dictionary = {}
	var expected_names := PackedStringArray()
	var expected_paths := PackedStringArray()
	for side in [-1.0, 1.0]:
		var side_tag := "Port" if side < 0.0 else "Starboard"
		for index in 4:
			var ring_name := "LashingRing%s%02d" % [side_tag, index + 1]
			var ring_path := "HandlingZones/%s" % ring_name
			expected_names.append(ring_name)
			expected_paths.append(ring_path)
			expected[ring_name] = {
				"path": ring_path,
				"transform": Transform3D(
					Basis.IDENTITY,
					Vector3(side * 10.6, 0.075, 16.0 + float(index) * 8.0)
				),
			}
	expected_names.sort()
	expected_paths.sort()
	var observed_names := PackedStringArray()
	var observed_paths := PackedStringArray()
	var snapshots: Dictionary = {}
	var resource_ids: Dictionary = {}
	var baseline_triangles := 0
	for ring in rings:
		observed_names.append(str(ring.name))
		observed_paths.append(str(module.get_path_to(ring)))
		var mesh := ring.mesh as TorusMesh
		if mesh == null:
			continue
		var baseline := mesh.duplicate() as TorusMesh
		TorusGeometryBudget.apply(baseline, 1.0)
		baseline_triangles += TorusGeometryBudget.triangles_of(baseline)
		resource_ids[mesh.get_instance_id()] = true
		snapshots[ring.get_instance_id()] = {
			"transform": ring.transform,
			"material": ring.material_override,
			"aabb": mesh.get_aabb(),
			"mesh_id": mesh.get_instance_id(),
		}
	var renderer_before := _renderer_census(module)
	var collision_before := module.get_collision_contract()
	var authority_before := module.get_authority_contract()
	var allocation_before_budget := module.get_lashing_ring_visual_allocation_audit()
	_check(
		bool(allocation_before_budget.get("valid", false))
		and not bool(allocation_before_budget.get("normalised", true)),
		"shared lashing-ring allocation is valid at its exact authored tessellation before the production budget sweep"
	)
	var report := TorusGeometryBudget.normalise_tree(module)
	var exact := rings.size() == 8 and resource_ids.size() == 1
	var profile_triangles := 0
	var expected_aabb := AABB(Vector3(-0.24, -0.04, -0.24), Vector3(0.48, 0.08, 0.48))
	var cardinal_extrema: Array[Vector3] = [
		Vector3(0.24, 0.0, 0.0), Vector3(-0.24, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.24), Vector3(0.0, 0.0, -0.24),
		Vector3(0.16, 0.0, 0.0), Vector3(-0.16, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.16), Vector3(0.0, 0.0, -0.16),
		Vector3(0.20, 0.04, 0.0), Vector3(0.20, -0.04, 0.0),
		Vector3(-0.20, 0.04, 0.0), Vector3(-0.20, -0.04, 0.0),
		Vector3(0.0, 0.04, 0.20), Vector3(0.0, -0.04, 0.20),
		Vector3(0.0, 0.04, -0.20), Vector3(0.0, -0.04, -0.20),
	]
	var cardinal_extrema_exact := cardinal_extrema.size() == 16
	for ring in rings:
		var mesh := ring.mesh as TorusMesh
		var snapshot := snapshots.get(ring.get_instance_id(), {}) as Dictionary
		var ring_name := str(ring.name)
		var expected_entry := expected.get(ring_name, {}) as Dictionary
		exact = exact \
			and mesh != null \
			and not expected_entry.is_empty() \
			and str(module.get_path_to(ring)) == str(expected_entry.get("path", "")) \
			and ring.transform.is_equal_approx(
				expected_entry.get("transform", Transform3D.IDENTITY) as Transform3D
			) \
			and ring.transform.is_equal_approx(snapshot.get("transform", Transform3D.IDENTITY)) \
			and ring.material_override == snapshot.get("material") \
			and mesh.get_instance_id() == int(snapshot.get("mesh_id", 0)) \
			and mesh.get_aabb().is_equal_approx(snapshot.get("aabb", AABB())) \
			and mesh.get_aabb().is_equal_approx(expected_aabb) \
			and is_equal_approx(mesh.inner_radius, 0.16) \
			and is_equal_approx(mesh.outer_radius, 0.24) \
			and mesh.rings == 32 \
			and mesh.ring_segments \
				== TorusGeometryBudget.FREIGHT_RECESSED_LASHING_RING_SEGMENTS \
			and mesh.get_surface_count() == 1 \
			and ring.get_child_count() == 0 \
			and StringName(ring.get_meta(TorusGeometryBudget.PROFILE_META, &"")) \
				== TorusGeometryBudget.PROFILE_FREIGHT_RECESSED_LASHING_RING
		if mesh != null:
			profile_triangles += TorusGeometryBudget.triangles_of(mesh)
			for extremum in cardinal_extrema:
				cardinal_extrema_exact = cardinal_extrema_exact \
					and _mesh_contains_vertex(mesh, extremum)
	observed_names.sort()
	observed_paths.sort()
	_check(
		exact
		and observed_names == expected_names
		and observed_paths == expected_paths
		and baseline_triangles == 6144
		and profile_triangles == 4096,
		"profile keeps the exact eight-path/name bijection, transforms, shared resource, materials, surfaces, radii and AABBs while cutting only 6144 -> 4096 tube triangles"
	)
	_check(
		cardinal_extrema_exact,
		"every profiled ring retains all 16 inner, outer and tube cardinal extrema"
	)
	var profile_report := (report.get("profiles", {}) as Dictionary).get(
		TorusGeometryBudget.PROFILE_FREIGHT_RECESSED_LASHING_RING, {}
	) as Dictionary
	_check(
		int(profile_report.get("resources", 0)) == 1
		and int(profile_report.get("instances", 0)) == 8
		and int(profile_report.get("surfaces", 0)) == 8
		and int(profile_report.get("triangles_baseline", 0)) == 6144
		and int(profile_report.get("triangles_after", 0)) == 4096,
		"profile report derives the exact one-resource/eight-instance/eight-surface family after sharing"
	)
	_check(
		renderer_before == {
			"descendant_nodes": 900,
			"mesh_instance_nodes": 402,
			"multimesh_nodes": 11,
			"surfaces": 383,
			"visible_copies": 442,
		}
		and _renderer_census(module) == renderer_before,
		"lashing-ring batching leaves 900 descendants, 383 submissions, and 442 visible copies"
	)
	_check(
		module.get_collision_contract() == collision_before
		and module.get_authority_contract() == authority_before,
		"tube tessellation cannot change collision, interaction, lifecycle, or authority"
	)


func _test_lashing_ring_visual_allocation(module: JovianFreightBerth) -> void:
	var audit := module.get_lashing_ring_visual_allocation_audit()
	_check(
		bool(audit.get("valid", false)) and bool(audit.get("normalised", false)),
		"lashing-ring retained-resource allocation audit is valid after the production torus budget: %s"
			% [audit.get("errors", [])]
	)
	_check(
		int(audit.get("node_count_before", 0)) == 8
		and int(audit.get("node_count_after", 0)) == 8
		and int(audit.get("node_delta", 99)) == 0
		and int(audit.get("drawn_copy_count_before", 0)) == 8
		and int(audit.get("drawn_copy_count_after", 0)) == 8
		and int(audit.get("drawn_copy_delta", 99)) == 0
		and int(audit.get("structural_submission_count_before", 0)) == 8
		and int(audit.get("structural_submission_count_after", 0)) == 1
		and int(audit.get("structural_submission_delta", 99)) == -7,
		"eight named anchors preserve eight visible copies through one structural submission"
	)
	_check(
		int(audit.get("mesh_resource_identity_count_before", 0)) == 8
		and int(audit.get("mesh_resource_identity_count_after", 0)) == 1
		and int(audit.get("mesh_resource_identity_delta", 0)) == -7
		and int(audit.get("material_resource_identity_count_before", 0)) == 1
		and int(audit.get("material_resource_identity_count_after", 0)) == 1
		and int(audit.get("material_resource_identity_delta", 99)) == 0
		and int(audit.get("retained_visual_resource_identity_count_before", 0)) == 9
		and int(audit.get("retained_visual_resource_identity_count_after", 0)) == 2
		and int(audit.get("retained_visual_resource_identity_delta", 0)) == -7,
		"only retained ring mesh identities fall from eight to one, for nine -> two visual resources"
	)
	var mesh_recipe := audit.get("mesh_recipe", {}) as Dictionary
	_check(
		is_equal_approx(float(mesh_recipe.get("inner_radius", -1.0)), 0.16)
		and is_equal_approx(float(mesh_recipe.get("outer_radius", -1.0)), 0.24)
		and int(mesh_recipe.get("authored_rings", 0)) == 48
		and int(mesh_recipe.get("authored_ring_segments", 0)) == 12
		and int(mesh_recipe.get("rings", 0)) == 32
		and int(mesh_recipe.get("ring_segments", 0)) == 8
		and int(mesh_recipe.get("surface_count", 0)) == 1
		and (mesh_recipe.get("aabb", AABB()) as AABB).is_equal_approx(
			AABB(Vector3(-0.24, -0.04, -0.24), Vector3(0.48, 0.08, 0.48))
		),
		"the shared mesh retains exact authored/budgeted tessellation, radii, surface and AABB"
	)
	_check(
		int(audit.get("family_node_count", 0)) == 8
		and int(audit.get("child_node_count", -1)) == 0
		and int(audit.get("authority_node_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("unexpected_metadata_entry_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and bool(audit.get("batched", false))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("gpu_draw_call_claimed", true))
		and not bool(audit.get("vram_claimed", true))
		and not bool(audit.get("whole_scene_budget_claimed", true)),
		"shared stock remains childless, authority-free, batched and claim-bounded"
	)

	var rows := audit.get("behavior_rows", []) as Array
	(rows[0] as Dictionary)["material"] = &"mutation"
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("mutation")
	var detached := module.get_lashing_ring_visual_allocation_audit()
	_check(
		bool(detached.get("valid", false))
		and StringName(((detached.get("behavior_rows", []) as Array)[0] as Dictionary).get(
			"material", &""
		)) == &"ceramic"
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has("mutation"),
		"lashing-ring allocation snapshots are deeply detached"
	)

	var rings: Array[MeshInstance3D] = []
	for row in detached.get("behavior_rows", []) as Array:
		rings.append(module.get_node(NodePath(str((row as Dictionary).get("path", "")))) as MeshInstance3D)
	var shared_mesh := rings[0].mesh as TorusMesh
	var shared_resources := true
	for ring in rings:
		shared_resources = shared_resources \
			and ring.mesh == shared_mesh \
			and ring.material_override == rings[0].material_override
	_check(shared_resources, "all eight retained named ring nodes share the exact mesh and ceramic material")

	shared_mesh.outer_radius = 0.25
	var recipe_mutation := module.get_lashing_ring_visual_allocation_audit()
	var recipe_error := (recipe_mutation.get("errors", PackedStringArray()) as PackedStringArray).has(
		"lashing_ring_mesh_recipe_drift"
	)
	_check(
		not bool(recipe_mutation.get("valid", true)) and recipe_error,
		"mutating the shared torus recipe reaches every copy and turns the audit red"
	)
	shared_mesh.outer_radius = 0.24

	var second_original_mesh := rings[1].mesh
	rings[1].mesh = shared_mesh.duplicate()
	var identity_mutation := module.get_lashing_ring_visual_allocation_audit()
	var identity_errors := identity_mutation.get("errors", PackedStringArray()) as PackedStringArray
	_check(
		not bool(identity_mutation.get("valid", true))
		and identity_errors.has(
			"lashing_ring_mesh_identity_not_shared:HandlingZones/LashingRingPort02"
		)
		and identity_errors.has("lashing_ring_mesh_identity_count_drift"),
		"an exact-looking private ring mesh turns both identity witnesses red"
	)
	rings[1].mesh = second_original_mesh

	var original_transform := rings[0].transform
	rings[0].position.x += 0.1
	var transform_mutation := module.get_lashing_ring_visual_allocation_audit()
	_check(
		not bool(transform_mutation.get("valid", true))
		and (transform_mutation.get("errors", PackedStringArray()) as PackedStringArray).has(
			"lashing_ring_visual_transform_or_visibility_drift:HandlingZones/LashingRingPort01"
		),
		"moving one retained semantic path turns the exact transform witness red"
	)
	rings[0].transform = original_transform

	var rogue_authority := Area3D.new()
	rings[0].add_child(rogue_authority)
	var authority_mutation := module.get_lashing_ring_visual_allocation_audit()
	_check(
		not bool(authority_mutation.get("valid", true))
		and (authority_mutation.get("errors", PackedStringArray()) as PackedStringArray).has(
			"lashing_ring_stock_gained_authority_or_lifecycle"
		),
		"authority below visual ring stock turns the audit red"
	)
	rings[0].remove_child(rogue_authority)
	rogue_authority.free()
	_check(
		bool(module.get_lashing_ring_visual_allocation_audit().get("valid", false)),
		"restoring recipe, identity, transform and authority mutations returns the audit green"
	)


func _mesh_contains_vertex(mesh: Mesh, expected: Vector3) -> bool:
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		for vertex in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if vertex.is_equal_approx(expected):
				return true
	return false


func _renderer_census(module: Node) -> Dictionary:
	var meshes := module.find_children("*", "MeshInstance3D", true, false)
	var batches := module.find_children("*", "MultiMeshInstance3D", true, false)
	var surfaces := 0
	var visible_copies := 0
	for candidate in meshes:
		var instance := candidate as MeshInstance3D
		var mesh := instance.mesh
		if mesh != null and instance.is_visible_in_tree():
			surfaces += mesh.get_surface_count()
			visible_copies += 1
	for candidate in batches:
		var multi := (candidate as MultiMeshInstance3D).multimesh
		if multi == null or multi.mesh == null:
			continue
		surfaces += multi.mesh.get_surface_count()
		var copies := multi.visible_instance_count
		visible_copies += multi.instance_count if copies < 0 else copies
	return {
		"descendant_nodes": module.find_children("*", "", true, false).size(),
		"mesh_instance_nodes": meshes.size(),
		"multimesh_nodes": batches.size(),
		"surfaces": surfaces,
		"visible_copies": visible_copies,
	}


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
			"key": str(mesh_instance.get_instance_id()),
			"label": str(module.get_path_to(mesh_instance)),
			"box": (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs(),
		})
	# MultiMesh copies are still drawn surfaces and must not disappear from this
	# all-geometry seating promise merely because repeated visual stock is batched.
	# The authored transform roster is the same headless-safe authority used by
	# the module's batch audit; renderer-buffer readback is unreliable headless.
	for candidate in module.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null or not batch.is_visible_in_tree():
			continue
		var transforms := batch.get_meta("authored_instance_transforms", []) as Array
		for instance_index in transforms.size():
			var instance_transform := transforms[instance_index] as Transform3D
			drawn.append({
				"node": batch,
				"key": "%d:%d" % [batch.get_instance_id(), instance_index],
				"label": "%s#%02d" % [module.get_path_to(batch), instance_index + 1],
				"box": (
					batch.global_transform
					* instance_transform
					* batch.multimesh.mesh.get_aabb()
				).abs(),
			})
	var floating := PackedStringArray()
	for entry in drawn:
		var piece := entry["node"] as Node3D
		var box := (entry["box"] as AABB).grow(SEAT_TOLERANCE)
		var seated := false
		for other_entry in drawn:
			var other := other_entry["node"] as Node3D
			if entry.key == other_entry.key \
				or other == piece \
				or piece.is_ancestor_of(other) \
				or other.is_ancestor_of(piece):
				continue
			if box.intersects(other_entry["box"] as AABB):
				seated = true
				break
		if not seated:
			floating.append("%s @ %s" % [entry.label, str(box.get_center())])
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
