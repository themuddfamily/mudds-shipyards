extends SceneTree

## Focused production journey for the streamed Cinder cargo berth/access module.
## The cluster must compose its real access scene and destination terminal; this
## test adds only the Jovian and Player actors needed to exercise the route.

const ACCESS_SCENE := preload("res://scenes/world/components/cinder_cargo_access.tscn")
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const DESTINATION_SCENE := preload("res://scenes/world/modules/cargo_destination_terminal.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const JOVIAN_DEFINITION := preload("res://assets/ships/jovian_provisional.tres")
const JOVIAN_SCRIPT := preload("res://scripts/ships/jovian_light_freighter.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const EXPECTED_APPROACH_WORLD := Vector3(60.0, -65.35, -684.9)
const PLAYER_ROUTE_TOLERANCE := 0.62
const MAX_CONSECUTIVE_AIRBORNE_FRAMES := 24

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		call_deferred("_capture_forward_plus_frame")
	else:
		call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "CinderCargoAccessTestStage"
	root.add_child(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	await process_frame
	await physics_frame
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	_check(platform != null, "live Cinder extraction-platform anchor resolves")
	if platform == null:
		stage.queue_free()
		await process_frame
		_finish()
		return

	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	_check(
		access != null and terminal != null
		and access.scene_file_path == "res://scenes/world/components/cinder_cargo_access.tscn"
		and terminal.scene_file_path == "res://scenes/world/modules/cargo_destination_terminal.tscn"
		and access.get_parent() == platform and terminal.get_parent() == platform,
		"streamed production cluster places the existing access and real destination terminal under its fixed platform anchor"
	)
	if access == null or terminal == null:
		stage.queue_free()
		await process_frame
		_finish()
		return
	var terminal_state := terminal.get_state_snapshot()
	var existing_cargo_authorities := cluster.find_children(
		"*", "CargoTransferAuthority", true, false
	)
	_check(
		bool(terminal_state.bound)
		and bool(terminal_state.ready)
		and StringName(terminal_state.state_id) == &"ready"
		and existing_cargo_authorities.size() == 1
		and existing_cargo_authorities[0].name == &"CinderCargoTransferAuthority"
		and existing_cargo_authorities[0].get_parent() == cluster.get_node(^"ActivityBinding"),
		"physical terminal delegates to the cluster's one existing cargo authority"
	)
	var cluster_audit := cluster.get_cluster_audit_report()
	_check(bool(cluster_audit.valid), "cargo access placement remains inside the production cluster audit budget")

	_test_identity_placement_budget_and_authority(access, terminal)
	var fit := await _test_jovian_fit_capture_and_sweep(stage, access)
	var ship := fit.get("ship") as HeroShip
	var lease_token := StringName(fit.get("lease_token", &""))
	if ship != null and not lease_token.is_empty():
		await _test_gameflow_compatible_landing_and_egress(access, ship, lease_token)
		_test_live_cargo_binding(cluster, access, terminal, ship, lease_token)
		await _test_embodied_bidirectional_route(cluster, access, terminal, ship, lease_token)
		await _test_detach_reentry(platform, access, ship, lease_token)
	else:
		_check(false, "Jovian fixture reaches lifecycle and embodied-access phases")

	_release_actions()
	stage.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_live_cargo_binding(
		cluster: NearbySectorCluster,
		access: CinderCargoAccess,
		terminal: CargoTransferTerminal,
		ship: HeroShip,
		lease_token: StringName
	) -> void:
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var authority := binding.get_cargo_transfer_authority()
	var source_handle := binding.get_cargo_source_handle()
	var destination_handle := binding.get_cargo_destination_handle()
	var source_manifest := authority.get_manifest_snapshot(source_handle)
	var destination_manifest := authority.get_manifest_snapshot(destination_handle)
	var binding_snapshot := binding.get_snapshot()
	_check(
		int(binding_snapshot.cargo_binding.source_entity_instance_id) == ship.get_instance_id()
		and StringName(source_handle.entity_id) == ship.get_ship_id()
		and StringName(source_handle.manifest_id) == &"cinder_jovian_source_manifest"
		and StringName(destination_handle.entity_id) == terminal.terminal_id
		and StringName(destination_handle.manifest_id) == terminal.manifest_id
		and int(source_manifest.used_capacity) == 2
		and int(destination_manifest.used_capacity) == 0
		and bool(source_manifest.attached) and bool(destination_manifest.attached)
		and bool(binding_snapshot.cargo_binding.terminal_ready),
		"landed live Jovian and physical destination terminal publish the exact source/destination manifests owned by one authority"
	)
	var terminal_before_stale := terminal.get_state_snapshot()
	_check(
		terminal.bind_authority(authority, destination_handle, 0).reason \
			== &"stale_terminal_generation"
		and terminal.get_state_snapshot() == terminal_before_stale,
		"stale terminal generation cannot replace or mutate the live destination binding"
	)
	_check(
		not access.get_berth().release(ship, &"stale-cinder-berth-lease")
		and access.get_berth().get_occupant() == ship
		and access.get_berth().get_reservation_token(ship) == lease_token,
		"stale berth lease cannot release the landed Jovian or disturb its live cargo source"
	)


func _test_identity_placement_budget_and_authority(
		access: CinderCargoAccess,
		terminal: CargoTransferTerminal
	) -> void:
	var snapshot := access.get_placement_snapshot()
	var audit := access.audit()
	_check(
		StringName(audit.content_status) == &"NEW"
		and StringName(audit.evidence_status) == &"modern_interpretation"
		and not bool(audit.historically_supported),
		"module is explicitly NEW modern_interpretation, never historical evidence"
	)
	_check(
		(snapshot.recommended_cluster_transform as Transform3D).is_equal_approx(
			CinderCargoAccess.RECOMMENDED_CLUSTER_TRANSFORM
		)
		and (snapshot.extraction_platform_local_transform as Transform3D)
		.is_equal_approx(Transform3D.IDENTITY)
		and (snapshot.destination_terminal_root_local as Transform3D)
		.is_equal_approx(CinderCargoAccess.DESTINATION_TERMINAL_ROOT_LOCAL),
		"placement contract publishes exact reusable cluster, platform, and terminal slots"
	)
	_check(
		(snapshot.destination_terminal_player_approach_world as Vector3)
		.is_equal_approx(EXPECTED_APPROACH_WORLD),
		"terminal Player-root floor handoff is exactly cluster/world (60,-65.35,-684.9)"
	)
	var terminal_slot := terminal.get_placement_slot_snapshot()
	var live_approach := terminal.get_node_or_null(^"PlayerApproach") as Marker3D
	var access_approach := access.get_route_marker(
		&"destination_terminal_player_approach"
	)
	_check(
		StringName(snapshot.terminal_slot_id) == StringName(terminal_slot.slot_id)
		and StringName(snapshot.terminal_slot_id)
		== &"station_cargo_destination_terminal_slot"
		and terminal.transform.is_equal_approx(
			snapshot.destination_terminal_root_local as Transform3D
		)
		and live_approach != null
		and access_approach != null
		and live_approach.global_transform.is_equal_approx(
			access_approach.global_transform
		),
		"actual destination fixture slot, root transform, and live PlayerApproach exactly match the module contract"
	)
	var approach_support := access.get_node_or_null(
		^"Structure/TerminalApproachPlatform"
	) as StaticBody3D
	var approach_collision := (
		approach_support.get_node_or_null(^"Collision") as CollisionShape3D
		if approach_support != null else null
	)
	var approach_shape := (
		approach_collision.shape as BoxShape3D
		if approach_collision != null else null
	)
	_check(
		approach_support != null
		and approach_support.collision_layer == PhysicsLayers.WORLD_BODY_LAYER
		and approach_support.collision_mask == PhysicsLayers.WORLD_BODY_MASK
		and approach_collision != null
		and not approach_collision.disabled
		and approach_shape != null
		and approach_shape.size.is_equal_approx(Vector3(2.4, 0.24, 2.4))
		and is_equal_approx(
			approach_support.global_position.y + approach_shape.size.y * 0.5,
			live_approach.global_position.y
		)
		and live_approach.position.is_equal_approx(
			CargoTransferTerminal.APPROACH_ORIGIN
		),
		"live terminal PlayerApproach rests exactly on the raised collision-backed Player-root platform"
	)
	var route := access.get_route_snapshot()
	_check(
		route.size() == 5
		and StringName(route[0].route_id) == &"berth_exit"
		and StringName(route[-1].route_id) == &"destination_terminal_player_approach"
		and ((route[-1].world_transform as Transform3D).origin).is_equal_approx(
			EXPECTED_APPROACH_WORLD
		),
		"bounded five-marker connector path publishes stable IDs and exact world transforms"
	)
	_check(
		not bool(snapshot.requires_world_owner)
		and bool(snapshot.production_route_claim)
		and not bool(snapshot.station_registry_claim)
		and bool(snapshot.streaming_ownership_claim),
		"live slots report their cluster-owned production route and streaming composition"
	)
	_check(
		bool(audit.budget_exact)
		and (audit.actual_budget as Dictionary) == CinderCargoAccess.LOCAL_BUDGET,
		"component-local nodes and submissions equal the checked-in exact budget"
	)
	var route_cue_allocation := access.get_route_cue_visual_allocation_audit()
	print("CINDER_CARGO_ROUTE_CUE_BATCH: ", route_cue_allocation)
	_check(
		bool(route_cue_allocation.valid)
		and (route_cue_allocation.legacy as Dictionary) == {
			"nodes": 5,
			"visible_copies": 5,
			"renderer_submissions": 5,
			"mesh_resource_allocations": 5,
			"material_resource_allocations": 2,
		}
		and (route_cue_allocation.before as Dictionary) == {
			"nodes": 5,
			"visible_copies": 5,
			"renderer_submissions": 5,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 2,
		}
		and (route_cue_allocation.current as Dictionary) == {
			"nodes": 2,
			"visible_copies": 8,
			"renderer_submissions": 2,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 2,
		}
		and int(route_cue_allocation.mesh_resource_allocation_delta) == 0
		and int(route_cue_allocation.renderer_submission_delta) == -3
		and int(route_cue_allocation.node_delta) == -3,
		"route cues and identity fascia batch eight exact copies into two material-preserving renderer nodes"
	)
	var static_box_allocation := access.get_static_box_visual_allocation_audit()
	_check(
		bool(static_box_allocation.valid)
		and int(static_box_allocation.view_count) == 21
		and int(static_box_allocation.mesh_resource_allocations) == 16
		and int(static_box_allocation.collision_resource_allocations) == 21
		and (static_box_allocation.legacy as Dictionary) == {
			"mesh_resource_allocations": 21,
			"collision_resource_allocations": 21,
		}
		and (static_box_allocation.current as Dictionary) == {
			"mesh_resource_allocations": 16,
			"collision_resource_allocations": 21,
		}
		and int(static_box_allocation.mesh_resource_allocation_delta) == -5,
		"five exact static-box visual pairs share 21->16 meshes while all 21 collision shapes remain private"
	)
	var stair_port := access.get_node_or_null(^"Rails/StairRailPort") as StaticBody3D
	var stair_starboard := access.get_node_or_null(^"Rails/StairRailStarboard") as StaticBody3D
	var stair_port_view := stair_port.get_node_or_null(^"Mesh") as MeshInstance3D if stair_port != null else null
	var stair_starboard_view := stair_starboard.get_node_or_null(^"Mesh") as MeshInstance3D if stair_starboard != null else null
	var stair_port_collision := stair_port.get_node_or_null(^"Collision") as CollisionShape3D if stair_port != null else null
	var stair_starboard_collision := stair_starboard.get_node_or_null(^"Collision") as CollisionShape3D if stair_starboard != null else null
	_check(
		stair_port_view != null and stair_starboard_view != null
		and stair_port_collision != null and stair_starboard_collision != null
		and stair_port_view.mesh == stair_starboard_view.mesh
		and stair_port_collision.shape != stair_starboard_collision.shape,
		"a shared visual rail mesh never aliases the two collision-shape resources"
	)
	if stair_port_view != null and stair_starboard_view != null:
		var original_mesh := stair_starboard_view.mesh
		stair_starboard_view.mesh = original_mesh.duplicate() as BoxMesh
		var split_resource_red := access.get_static_box_visual_allocation_audit()
		stair_starboard_view.mesh = original_mesh
		_check(
			not bool(split_resource_red.valid)
			and _has_error(split_resource_red.errors, "static_box_shared_family_identity_drift")
			and _has_error(split_resource_red.errors, "static_box_mesh_resource_count_drift")
			and bool(access.get_static_box_visual_allocation_audit().valid),
			"structured-red: splitting one paired static visual mesh fails identity without changing collision ownership"
		)
	_check(
		route_cue_allocation.authored_node_names
			== PackedStringArray(["RouteCue1", "RouteCue2", "RouteCue3", "RouteCue4", "RouteCue5"])
		and route_cue_allocation.batch_node_names
			== PackedStringArray(["RouteCueCyanBatch", "RouteCueHazardBatch"])
		and route_cue_allocation.authored_transforms == route_cue_allocation.live_transforms
		and (route_cue_allocation.mesh_size as Vector3).is_equal_approx(Vector3(0.42, 0.08, 0.42))
		and bool(route_cue_allocation.visual_only)
		and bool(route_cue_allocation.childless)
		and bool(route_cue_allocation.batched),
		"allocation audit retains the five-copy transform roster and exact renderer recipe in two batches"
	)
	var route_cue_cyan := access.get_node_or_null(
		^"VisualRouteCues/RouteCueCyanBatch"
	) as MultiMeshInstance3D
	var shared_route_cue_mesh := (
		route_cue_cyan.multimesh.mesh
		if route_cue_cyan != null and route_cue_cyan.multimesh != null else null
	)
	if route_cue_cyan != null and shared_route_cue_mesh != null:
		route_cue_cyan.multimesh.mesh = shared_route_cue_mesh.duplicate() as Mesh
	var split_resource_red := access.get_route_cue_visual_allocation_audit()
	if route_cue_cyan != null:
		route_cue_cyan.multimesh.mesh = shared_route_cue_mesh
	_check(
		not bool(split_resource_red.valid)
		and _has_error(
			split_resource_red.errors,
			"route_cue_mesh_resource_count_drift"
		)
		and bool(access.get_route_cue_visual_allocation_audit().valid),
		"structured-red: splitting one byte-identical route-cue mesh resource fails allocation identity and restores cleanly"
	)
	var route_cue_hazard := access.get_node_or_null(
		^"VisualRouteCues/RouteCueHazardBatch"
	) as MultiMeshInstance3D
	_check(
		route_cue_cyan != null and route_cue_hazard != null
		and route_cue_cyan.multimesh.instance_count == 4
		and route_cue_hazard.multimesh.instance_count == 4
		and route_cue_cyan.multimesh.mesh == route_cue_hazard.multimesh.mesh
		and route_cue_cyan.material_override != route_cue_hazard.material_override
		and access.find_children("RouteCue*", "MeshInstance3D", true, false).is_empty()
		and access.get_node(^"VisualRouteCues").find_children(
			"*", "CollisionObject3D", true, false
		).is_empty(),
		"two inert material batches preserve five floor cues plus three fascia copies without collision nodes"
	)
	var authored_cyan_buffer := route_cue_cyan.multimesh.buffer.duplicate()
	var drifted_cyan_buffer := authored_cyan_buffer.duplicate()
	drifted_cyan_buffer[3] = 99.0
	route_cue_cyan.multimesh.buffer = drifted_cyan_buffer
	var transform_buffer_red := access.get_route_cue_visual_allocation_audit()
	_check(
		not bool(transform_buffer_red.valid)
		and _has_error(
			transform_buffer_red.errors,
			"route_cue_transform_buffer_drift_RouteCueCyanBatch"
		),
		"structured-red: route-cue batching rejects one transformed-copy buffer drift"
	)
	route_cue_cyan.multimesh.buffer = authored_cyan_buffer
	_check(
		bool(access.get_route_cue_visual_allocation_audit().valid),
		"restoring the exact route-cue transform buffer repairs the batch contract"
	)
	var identity := access.get_route_identity_visual_audit()
	var identity_label := access.get_node_or_null(
		^"VisualRouteCues/CargoAccessLabel"
	) as Label3D
	var identity_transforms := identity.get("authored_transforms", []) as Array
	var identity_header := (
		identity_label.text.get_slice("\n", 0) if identity_label != null else ""
	)
	var displayed_right := (
		identity_label.global_transform.basis.x.normalized()
		if identity_label != null else Vector3.ZERO
	)
	var displayed_left := -displayed_right
	var delivery_direction := (
		access.get_route_marker(&"destination_terminal_player_approach").global_position
		- identity_label.global_position
	).normalized() if identity_label != null else Vector3.ZERO
	var pickup_direction := (
		access.get_route_marker(&"berth_exit").global_position
		- identity_label.global_position
	).normalized() if identity_label != null else Vector3.ZERO
	_check(
		bool(identity.valid)
		and bool(identity.supported)
		and bool(identity.non_coplanar)
		and bool(identity.material_reused)
		and int(identity.copy_count) == 3
		and int(identity.incremental_renderer_submissions) == 0
		and int(identity.collision_nodes) == 0
		and identity_label != null
		and identity_header == "< CINDER CARGO TERMINAL | JOVIAN BERTH >"
		and CinderCargoAccess.ROUTE_IDENTITY_HEADER == identity_header
		and delivery_direction.dot(displayed_left) > 0.5
		and delivery_direction.dot(displayed_right) < -0.5
		and pickup_direction.dot(displayed_right) > 0.5
		and pickup_direction.dot(displayed_left) < -0.5
		and identity_label.text.contains("CINDER CARGO — ")
		and identity_transforms.size() == 3
		and ((identity_transforms[0] as Transform3D).basis.get_scale()
		* CinderCargoAccess.ROUTE_CUE_SIZE)
		.is_equal_approx(Vector3(0.14, 0.72, 0.14))
		and ((identity_transforms[2] as Transform3D).basis.get_scale()
		* CinderCargoAccess.ROUTE_CUE_SIZE)
		.is_equal_approx(Vector3(7.4, 1.12, 0.14)),
		"label-basis projection maps the named terminal to displayed-left and the named Jovian berth to displayed-right with no new submission or material"
	)
	var identity_buffer := route_cue_cyan.multimesh.buffer.duplicate()
	var identity_buffer_red := identity_buffer.duplicate()
	identity_buffer_red[39] += 0.2
	route_cue_cyan.multimesh.buffer = identity_buffer_red
	var identity_red := access.get_route_identity_visual_audit()
	route_cue_cyan.multimesh.buffer = identity_buffer
	_check(
		not bool(identity_red.valid)
		and _has_error(
			identity_red.errors,
			"cargo_route_identity_host_batch_drift"
		)
		and bool(access.get_route_identity_visual_audit().valid),
		"structured-red: moving a fascia copy breaks its supported identity roster and restores cleanly"
	)
	var surface_ids := PackedStringArray()
	var surface_census_valid := true
	for body_node in access.find_children("*", "StaticBody3D", true, false):
		var body := body_node as StaticBody3D
		if bool(body.get_meta("walkable_surface", false)):
			var surface_id := StringName(body.get_meta("walkable_surface_id", &""))
			surface_census_valid = (
				surface_census_valid
				and not surface_id.is_empty()
				and not surface_ids.has(surface_id)
				and body.get_meta("walkable_surface_kind", &"") == &"level"
				and body.get_meta("walkable_surface_owner", &"")
				== CinderCargoAccess.COMPONENT_ID
			)
			surface_ids.append(surface_id)
		else:
			surface_census_valid = (
				surface_census_valid
				and not body.has_meta("walkable_surface_id")
				and not body.has_meta("walkable_surface_kind")
				and not body.has_meta("walkable_surface_owner")
			)
	_check(
		surface_census_valid
		and surface_ids.size() == CinderCargoAccess.WALKABLE_SURFACE_COUNT,
		"only eleven usable horizontal bodies publish unique IDs with kind level and component owner; barriers publish no census identity"
	)
	var expected_tops := [
		{"name": "LandingDeck", "top": 2.9},
		{"name": "ConnectorStep1", "top": 3.2},
		{"name": "ConnectorStep2", "top": 3.5},
		{"name": "ConnectorStep3", "top": 3.8},
		{"name": "TerminalApproachStep1", "top": 4.05},
		{"name": "TerminalApproachStep2", "top": 4.30},
		{"name": "TerminalApproachStep3", "top": 4.55},
		{"name": "TerminalApproachPlatform", "top": 4.65},
	]
	var exact_step_tops := true
	var previous_top := 2.9
	for step_spec in expected_tops:
		var body_name := String(step_spec.name)
		var step_body := access.get_node_or_null(
			NodePath("Structure/%s" % body_name)
		) as StaticBody3D
		var collision := (
			step_body.get_node_or_null(^"Collision") as CollisionShape3D
			if step_body != null else null
		)
		var shape := collision.shape as BoxShape3D if collision != null else null
		var actual_top := (
			step_body.position.y + shape.size.y * 0.5
			if step_body != null and shape != null else -INF
		)
		exact_step_tops = exact_step_tops and is_equal_approx(
			actual_top, float(step_spec.top)
		)
		if body_name != "LandingDeck":
			exact_step_tops = exact_step_tops and actual_top - previous_top <= 0.3001
			previous_top = actual_top
	_check(
		exact_step_tops,
		"collision-backed route tops are exactly 2.9 -> 3.2 -> 3.5 -> 3.8 -> 4.05 -> 4.30 -> 4.55 -> 4.65 with no rise above 0.30 m"
	)
	_check(bool(access.audit().valid), "canonical raised-platform height and collision audit is green")
	var canonical_support_y := approach_support.position.y
	approach_support.position.y += 0.1
	var height_red := access.audit()
	approach_support.position.y = canonical_support_y
	_check(
		not bool(height_red.valid)
		and _has_error(height_red.errors, "terminal_approach_platform_top"),
		"structured-red: a raised-platform height mutation fails the exact top audit"
	)
	approach_collision.disabled = true
	var collision_red := access.audit()
	approach_collision.disabled = false
	_check(
		not bool(collision_red.valid)
		and _has_error(
			collision_red.errors,
			"terminal_approach_platform_collision_disabled"
		),
		"structured-red: disabling the raised-platform BoxShape fails closed"
	)
	_check(bool(access.audit().valid), "restoring both structured-red mutations restores the canonical audit")
	_check(
		not bool(audit.cargo_authority)
		and not bool(audit.inventory_authority)
		and not bool(audit.reward_authority)
		and not bool(audit.combat_authority)
		and not bool(audit.activity_authority)
		and not bool(audit.save_authority)
		and not bool(audit.network_authority)
		and not bool(audit.ship_control_authority)
		and not bool(audit.landing_motion_authority)
		and bool(audit.owns_physical_berth_lease),
		"module owns only the real physical berth lease, with zero cargo, inventory, reward, combat, activity, save, network, ship-control, or landing-motion authority"
	)
	var authored_nodes := access.find_children("*", "Node", true, false)
	var all_tagged: bool = access.get_meta("evidence_status", &"") == &"modern_interpretation"
	for node in authored_nodes:
		all_tagged = all_tagged and node.get_meta("evidence_status", &"") == &"modern_interpretation"
	_check(all_tagged, "every authored descendant retains the modern-interpretation evidence boundary")


func _test_jovian_fit_capture_and_sweep(
		stage: Node3D,
		access: CinderCargoAccess
	) -> Dictionary:
	var berth := access.get_berth()
	_check(
		berth != null
		and berth.get_berth_id() == CinderCargoAccess.BERTH_ID
		and berth.get_compatibility_tags() == PackedStringArray(["light_freighter"])
		and berth.is_compatible_with(JOVIAN_DEFINITION),
		"one real ShipBerth accepts the live Jovian light-freighter definition"
	)
	if berth == null:
		return {}
	var ship := JOVIAN_SCENE.instantiate() as HeroShip
	stage.add_child(ship)
	await process_frame
	await physics_frame
	var collision_report := ship.get_landing_collision_report()
	var hull_bounds := collision_report.get("local_bounds", AABB()) as AABB
	var dock := berth.get_dock_transform()
	_check(
		bool(collision_report.valid)
		and JOVIAN_SCRIPT.FLIGHT_COLLISION_BOUNDS.encloses(hull_bounds)
		and berth.contains_oriented_bounds(dock, hull_bounds, 0.05),
		"exact live Jovian collision hull is inside its public envelope and has strict 0.05 m final-fit acceptance"
	)
	var strict := berth.evaluate_landing_candidate(
		dock, hull_bounds, Vector3.ZERO, ship.landing_maximum_speed
	)
	var capture := berth.get_assist_capture_transform()
	var broad := berth.evaluate_assist_capture_candidate(
		capture, hull_bounds, Vector3.ZERO, ship.landing_maximum_speed
	)
	_check(
		bool(strict.valid)
		and bool(broad.valid)
		and bool(broad.strict_dock_acceptance)
		and capture.is_equal_approx(berth.get_assist_staging_transform()),
		"exact dock, broad capture, and staging transforms all retain strict final acceptance"
	)
	var samples := access.get_approach_sample_transforms(17)
	_check(
		samples.size() == 17
		and samples[0].is_equal_approx(capture)
		and samples[-1].is_equal_approx(dock),
		"bounded swept-approach samples run from the exact capture pose to exact final pose"
	)
	var landing_deck := access.get_node_or_null(^"Structure/LandingDeck") as StaticBody3D
	var sweep := _cast_conservative_hull_sweep(
		access,
		hull_bounds,
		capture,
		dock,
		[landing_deck.get_rid()] if landing_deck != null else []
	)
	_check(
		bool(sweep.clear) and float(sweep.safe_fraction) >= 0.999,
		"conservative Jovian hull sweep is clear through the live platform to exact final contact, excluding only its landing deck"
	)
	var final_clear := _query_conservative_hull(
		access,
		hull_bounds,
		dock,
		[landing_deck.get_rid()] if landing_deck != null else []
	)
	_check(
		final_clear.is_empty(),
		"final Jovian hull clears platform, terminal connector, rails, and route geometry apart from its intentional landing deck"
	)
	ship.global_transform = capture
	ship.velocity = Vector3.ZERO
	var lease_token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(not lease_token.is_empty(), "Jovian obtains the berth's opaque exclusive lease")
	return {"ship": ship, "lease_token": lease_token}


func _test_gameflow_compatible_landing_and_egress(
		access: CinderCargoAccess,
		ship: HeroShip,
		lease_token: StringName
	) -> void:
	var berth := access.get_berth()
	var dock := berth.get_dock_transform()
	_check(
		ship.global_transform.is_equal_approx(berth.get_assist_capture_transform()),
		"landing fixture begins at the exact public assist-capture transform"
	)
	_check(ship.request_berth_landing(berth), "public leased HeroShip berth-landing entry point accepts the Jovian from exact capture")
	var landing_frames := await _await_public_landing(ship, 1200)
	var telemetry := ship.get_telemetry()
	var contract := ship.get_landing_contract_report()
	_check(
		landing_frames > 0
		and landing_frames < 1200
		and not ship.is_landing_active()
		and bool(telemetry.landed)
		and telemetry.landing_phase == &"docked"
		and StringName(telemetry.landing_abort_reason).is_empty()
		and berth.get_occupant() == ship
		and berth.get_reservation_token(ship) == lease_token,
		"normal GameFlow-consumed landed telemetry and exact berth occupancy complete"
	)
	_check(
		bool(contract.contract_accepted)
		and bool(contract.strict_dock_acceptance)
		and StringName(contract.berth_id) == CinderCargoAccess.BERTH_ID
		and (contract.dock_transform_snapshot as Transform3D).is_equal_approx(dock),
		"completed landing preserves strict acceptance, berth identity, and dock snapshot"
	)
	var exit_marker := access.get_node_or_null(^"RouteMarkers/BerthExit") as Marker3D
	_check(
		exit_marker != null
		and ship.get_exit_transform().is_equal_approx(exit_marker.global_transform)
		and (access.global_transform.affine_inverse() * ship.get_exit_transform())
		.is_equal_approx(
			CinderCargoAccess.BERTH_EXIT_LOCAL_TRANSFORM
		),
		"landed HeroShip egress freezes the connector BerthExit origin and full basis"
	)


func _test_embodied_bidirectional_route(
		cluster: NearbySectorCluster,
		access: CinderCargoAccess,
		terminal: CargoTransferTerminal,
		ship: HeroShip,
		lease_token: StringName
	) -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	player.set_camera_active(false)
	player.set_control_enabled(true)
	_release_actions()
	player.teleport_to(Transform3D(
		Basis.looking_at((access.global_basis * Vector3.BACK).normalized(), Vector3.UP),
		ship.get_exit_transform().origin
	))
	for _settle in 10:
		await physics_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var authority := binding.get_cargo_transfer_authority()
	var attachment_generation := access.get_attachment_generation()
	var wrong_craft := Node3D.new()
	root.add_child(wrong_craft)
	_check(
		access.authorize_disembarked_terminal_actor(
			player, wrong_craft, lease_token, attachment_generation
		).reason == &"stale_berth_lease"
		and access.authorize_disembarked_terminal_actor(
			player, ship, lease_token, attachment_generation
		).accepted
		and access.validate_terminal_actor(
			player, wrong_craft, attachment_generation
		).reason == &"wrong_terminal_craft",
		"only the disembarked actor and exact occupied Jovian lease authorize the terminal route"
	)
	wrong_craft.queue_free()
	var source_handle := binding.get_cargo_source_handle()
	var destination_handle := binding.get_cargo_destination_handle()
	var source_before := authority.get_quantity(source_handle, &"cinder_supply_crates")
	var destination_before := authority.get_quantity(destination_handle, &"cinder_supply_crates")
	var abort_start := binding.start_cargo_run()
	var abort_generation := int(abort_start.generation)
	var aborted := binding.abort_cargo_run(abort_generation)
	var reset_abort := binding.reset_cargo_run()
	_check(
		abort_start.accepted and aborted.accepted and reset_abort.accepted
		and authority.get_quantity(source_handle, &"cinder_supply_crates") == source_before
		and authority.get_quantity(destination_handle, &"cinder_supply_crates") == destination_before,
		"abort then reset preserves exact source/destination conservation without refilling either manifest"
	)
	var active := binding.start_cargo_run()
	var cargo_generation := int(active.generation)
	var ordered_phases := [&"load_crate", &"clear_gate", &"dock_platform"]
	var phases_accepted := bool(active.accepted)
	for phase_id: StringName in ordered_phases:
		phases_accepted = phases_accepted and bool(binding.submit_cargo_phase(phase_id).accepted)
	var reward_calls := {"count": 0, "request": {}}
	var reward_configured := binding.configure_cargo_reward_handoff(
		func(request: Dictionary) -> Dictionary:
			reward_calls.count = int(reward_calls.count) + 1
			reward_calls.request = request.duplicate(true)
			return {"accepted": true, "reason": &"test_store_accepted"}
	)
	var out_of_range := terminal.get_interaction_snapshot(
		player.global_position, terminal.get_terminal_generation()
	)
	var stale_terminal := terminal.get_interaction_snapshot(
		player.global_position, terminal.get_terminal_generation() - 1
	)
	_check(
		phases_accepted and reward_configured.accepted
		and out_of_range.reason == &"out_of_range"
		and stale_terminal.reason == &"stale_terminal_generation"
		and not terminal.interact(player),
		"terminal rejects out-of-range and stale-generation requests before cargo mutation"
	)
	var outbound_local := PackedVector3Array([
		Vector3(CinderCargoAccess.BERTH_ROUTE_X, 2.9, 13.75),
		Vector3(CinderCargoAccess.BERTH_ROUTE_X, 3.8, 17.8),
		Vector3(-14.15, 3.8, 18.0),
		Vector3(-4.0, 3.8, 18.0),
		Vector3(-2.4, 3.8, 16.7),
		Vector3(-1.6, 4.05, 16.166667),
		Vector3(-0.8, 4.30, 15.633333),
		CinderCargoAccess.DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL,
	])
	var outbound := await _walk_route(access, player, outbound_local)
	print("CINDER_CARGO_PUBLIC_OUTBOUND: ", outbound)
	var outbound_final := access.to_local(player.global_position)
	_check(
		bool(outbound.reached)
		and int(outbound.maximum_consecutive_airborne_frames)
		<= MAX_CONSECUTIVE_AIRBORNE_FRAMES
		and float(outbound.minimum_local_y) >= 2.82
		and absf(outbound_final.y - 4.65) <= 0.01,
		"production Player walks berth exit to live terminal PlayerApproach with a bounded airborne run and no jump"
	)
	var wrong_actor := Node3D.new()
	root.add_child(wrong_actor)
	wrong_actor.global_position = player.global_position
	var wrong_interaction := terminal.interact(wrong_actor)
	var wrong_result := binding.get_last_cargo_terminal_request()
	wrong_actor.queue_free()
	var committed := terminal.interact(player)
	var committed_result := binding.get_last_cargo_terminal_request()
	var receipt := committed_result.get("receipt", {}) as Dictionary
	var completed_cargo := binding.get_snapshot().cargo as Dictionary
	_check(
		wrong_interaction and wrong_result.reason == &"wrong_terminal_actor"
		and committed and committed_result.accepted
		and committed_result.reason == &"cargo_terminal_delivery_committed"
		and receipt == (completed_cargo.accepted_receipt as Dictionary)
		and int(receipt.source_quantity_after) == source_before - 1
		and int(receipt.destination_quantity_after) == destination_before + 1
		and authority.get_quantity(source_handle, &"cinder_supply_crates") == source_before - 1
		and authority.get_quantity(destination_handle, &"cinder_supply_crates") == destination_before + 1,
		"embodied terminal request commits once and CargoDeliveryActivity retains the authority's exact receipt"
	)
	var replay_interaction := terminal.interact(player)
	var replay_result := binding.get_last_cargo_terminal_request()
	var ledger_after_replay := authority.to_dictionary().committed_transfers as Array
	var reward := binding.request_cargo_reward(cargo_generation)
	var reward_replay := binding.request_cargo_reward(cargo_generation)
	var reset_completed := binding.reset_cargo_run()
	_check(
		replay_interaction and not bool(replay_result.accepted)
		and replay_result.reason == &"not_active"
		and ledger_after_replay.size() == 1
		and reward.accepted and reward.reason == &"reward_request_committed"
		and not bool(reward_replay.accepted) and reward_replay.reason == &"reward_already_consumed"
		and int(reward_calls.count) == 1
		and StringName((reward_calls.request as Dictionary).activity_id) == &"cinder_kit_cargo_run"
		and reset_completed.accepted
		and authority.get_quantity(source_handle, &"cinder_supply_crates") == source_before - 1
		and authority.get_quantity(destination_handle, &"cinder_supply_crates") == destination_before + 1,
		"replay and reward handoff are exactly once; completed reset preserves conservation with no refill"
	)
	var reverse_local := PackedVector3Array([
		Vector3(-0.8, 4.30, 15.633333),
		Vector3(-1.6, 4.05, 16.166667),
		Vector3(-2.4, 3.8, 16.7),
		Vector3(-4.0, 3.8, 18.0),
		Vector3(-14.15, 3.8, 18.0),
		Vector3(CinderCargoAccess.BERTH_ROUTE_X, 3.8, 17.8),
		Vector3(CinderCargoAccess.BERTH_ROUTE_X, 2.9, 13.75),
		Vector3(CinderCargoAccess.BERTH_ROUTE_X, 2.9, 8.2),
	])
	var inbound := await _walk_route(access, player, reverse_local)
	print("CINDER_CARGO_PUBLIC_RETURN: ", inbound)
	_check(
		bool(inbound.reached)
		and int(inbound.maximum_consecutive_airborne_frames)
		<= MAX_CONSECUTIVE_AIRBORNE_FRAMES
		and float(inbound.minimum_local_y) >= 2.82,
		"production Player walks live terminal marker back to berth exit with a bounded airborne run and no jump"
	)
	_check(not Input.is_action_pressed("jump"), "embodied bidirectional proof never asserts the jump action")
	_release_actions()
	player.queue_free()
	await process_frame


func _test_detach_reentry(
		platform: Node3D,
		access: CinderCargoAccess,
		ship: HeroShip,
		lease_token: StringName
	) -> void:
	var cluster := platform.get_parent().get_parent() as NearbySectorCluster
	var streaming_parent := cluster.get_parent()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	var terminal_id := terminal.get_instance_id()
	var terminal_generation := terminal.get_terminal_generation()
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var cargo_authority_id := binding.get_cargo_transfer_authority().get_instance_id()
	var source_handle := binding.get_cargo_source_handle()
	var destination_handle := binding.get_cargo_destination_handle()
	var berth := access.get_berth()
	var berth_id := berth.get_instance_id()
	var old_attachment_generation := access.get_attachment_generation()
	var body_ids: Array[int] = []
	for body in access.find_children("*", "StaticBody3D", true, false):
		body_ids.append(body.get_instance_id())
	var route_batch_ids: Array[int] = []
	for batch_node in access.find_children("RouteCue*Batch", "MultiMeshInstance3D", true, false):
		var batch := batch_node as MultiMeshInstance3D
		route_batch_ids.append(batch.get_instance_id())
	streaming_parent.remove_child(cluster)
	await process_frame
	var detached_snapshot := access.get_attachment_snapshot(old_attachment_generation)
	_check(
		berth.get_occupant() == ship
		and berth.get_reservation_owner() == ship
		and berth.get_reservation_token(ship) == lease_token
		and not bool(detached_snapshot.accepted)
		and detached_snapshot.reason == &"detached"
		and not terminal.is_inside_tree(),
		"whole streamed cluster detach retains the exact lease while access and terminal leave the tree together"
	)
	streaming_parent.add_child(cluster)
	await process_frame
	await physics_frame
	var reentry_body_ids: Array[int] = []
	for body in access.find_children("*", "StaticBody3D", true, false):
		reentry_body_ids.append(body.get_instance_id())
	var reentry_route_batch_ids: Array[int] = []
	for batch_node in access.find_children("RouteCue*Batch", "MultiMeshInstance3D", true, false):
		var batch := batch_node as MultiMeshInstance3D
		reentry_route_batch_ids.append(batch.get_instance_id())
	var stale_snapshot := access.get_attachment_snapshot(old_attachment_generation)
	var current_snapshot := access.get_attachment_snapshot(access.get_attachment_generation())
	_check(
		access.get_build_generation() == 1
		and access.get_attachment_generation() == old_attachment_generation + 1
		and access.get_berth().get_instance_id() == berth_id
		and cluster.get_cinder_cargo_access() == access
		and cluster.get_cinder_cargo_destination_terminal().get_instance_id() == terminal_id
		and terminal.get_terminal_generation() == terminal_generation
		and bool(terminal.get_state_snapshot().ready)
		and binding.get_cargo_transfer_authority().get_instance_id() == cargo_authority_id
		and binding.get_cargo_source_handle() == source_handle
		and binding.get_cargo_destination_handle() == destination_handle
		and int(binding.get_snapshot().cargo_binding.access_attachment_generation) \
			== access.get_attachment_generation()
		and bool(binding.get_cargo_transfer_authority().get_manifest_snapshot(
			destination_handle
		).attached)
		and body_ids == reentry_body_ids
		and route_batch_ids == reentry_route_batch_ids
		and berth.get_occupant() == ship
		and berth.get_reservation_token(ship) == lease_token
		and not bool(stale_snapshot.accepted)
		and stale_snapshot.reason == &"stale_attachment_generation"
		and bool(current_snapshot.accepted)
		and bool(access.audit().budget_exact)
		and bool(access.get_route_cue_visual_allocation_audit().valid),
		"re-entry preserves occupied lease and node identities, advances attachment generation once, rejects stale generation, and does not duplicate geometry"
	)
	_check(
		binding.bind_cargo_access(access, terminal, old_attachment_generation).reason \
			== &"stale_attachment_generation"
		and binding.get_cargo_source_handle() == source_handle
		and binding.get_cargo_destination_handle() == destination_handle,
		"stale streamed berth attachment generation cannot replace either live cargo handle"
	)
	_check(berth.release(ship, lease_token), "re-entered occupied Jovian lease releases through the canonical berth contract")
	var released_binding := binding.get_snapshot()
	var released_presentation := access.get_cargo_presentation_state()
	_check(
		binding.get_cargo_source_handle().is_empty()
		and (released_binding.cargo as Dictionary).is_empty()
		and int(released_binding.cargo_binding.source_entity_instance_id) == 0
		and (released_binding.cargo_binding.source_handle as Dictionary).is_empty()
		and StringName(released_presentation.state_id) == &"unavailable"
		and String(released_presentation.label_text).contains(
			"CINDER CARGO — BERTH REQUIRED"
		),
		"ordinary null berth release synchronously clears source handle, activity, actor, and cargo status"
	)
	# Keep the released craft alive to prove replacement admission does not rely
	# on queue_free or an external manifest-retirement request.
	ship.global_position += Vector3(200.0, 0.0, 0.0)
	var replacement := JOVIAN_SCENE.instantiate() as HeroShip
	root.add_child(replacement)
	await process_frame
	await physics_frame
	var capture := access.get_berth().get_assist_capture_transform()
	replacement.global_transform = Transform3D(
		capture.basis,
		capture * Vector3(4.0, 2.0, -5.0)
	)
	replacement.velocity = Vector3.ZERO
	var token := access.get_berth().try_reserve(replacement, replacement.get_ship_definition())
	_check(
		not token.is_empty()
		and bool(access.get_berth().evaluate_assist_capture_candidate(
			replacement.global_transform,
			replacement.get_landing_collision_report().local_bounds as AABB,
			Vector3.ZERO,
			replacement.landing_maximum_speed
		).valid)
		and replacement.request_berth_landing(access.get_berth()),
		"same re-entered berth publicly accepts a fresh off-centre Jovian capture"
	)
	var off_center_frames := await _await_public_landing(replacement, 1200)
	var replacement_source_handle := binding.get_cargo_source_handle()
	_check(
		off_center_frames > 0
		and off_center_frames < 1200
		and bool(replacement.get_telemetry().landed)
		and StringName(replacement.get_telemetry().landing_abort_reason).is_empty()
		and access.get_berth().get_occupant() == replacement
		and replacement_source_handle != source_handle
		and int(replacement_source_handle.entity_generation) \
			> int(source_handle.entity_generation)
		and int(binding.get_snapshot().cargo_binding.source_entity_instance_id) \
			== replacement.get_instance_id(),
		"off-centre replacement becomes the fresh live source generation and lands with no abort"
	)
	_check(
		access.get_berth().release(replacement, token)
		and binding.get_cargo_source_handle().is_empty()
		and int(binding.get_snapshot().cargo_binding.source_entity_instance_id) == 0
		and StringName(access.get_cargo_presentation_state().state_id) == &"unavailable",
		"replacement release repeats the synchronous source and status clear"
	)
	ship.queue_free()
	replacement.queue_free()
	await process_frame

	# A current attachment generation is not a live ownership capability once the
	# standalone access component is queued, even though SceneTree removal has
	# not reached it yet.
	var queued_attachment_generation := access.get_attachment_generation()
	access.queue_free()
	var queued_snapshot := access.get_attachment_snapshot(queued_attachment_generation)
	_check(
		access.is_queued_for_deletion()
		and not bool(queued_snapshot.accepted)
		and queued_snapshot.reason == &"queued_for_deletion"
		and not queued_snapshot.has("component_instance_id")
		and not queued_snapshot.has("berth_instance_id"),
		"queued Cinder access rejects a current attachment snapshot before publishing berth identity"
	)
	await process_frame
	_check(not is_instance_valid(access), "queued Cinder access snapshot fixture frees cleanly")


func _await_public_landing(ship: HeroShip, maximum_frames: int) -> int:
	for frame_index in maximum_frames:
		await physics_frame
		if not ship.is_landing_active():
			return frame_index + 1
	return maximum_frames


func _cast_conservative_hull_sweep(
		access: CinderCargoAccess,
		bounds: AABB,
		from_ship: Transform3D,
		to_ship: Transform3D,
		exclude: Array
	) -> Dictionary:
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		from_ship.basis,
		from_ship * bounds.get_center()
	)
	query.motion = (to_ship * bounds.get_center()) - query.transform.origin
	query.collision_mask = PhysicsLayers.WORLD_BODY_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclude
	var cast := access.get_world_3d().direct_space_state.cast_motion(query)
	var collision_names := PackedStringArray()
	if cast.size() == 2 and cast[0] < 0.999:
		query.transform.origin += query.motion * cast[1]
		query.motion = Vector3.ZERO
		for hit in access.get_world_3d().direct_space_state.intersect_shape(query, 64):
			var collider := hit.get("collider") as Node
			collision_names.append(str(collider.get_path()) if collider != null else "<unknown>")
	return {
		"clear": cast.size() == 2 and cast[0] >= 0.999,
		"safe_fraction": cast[0] if cast.size() > 0 else 0.0,
		"unsafe_fraction": cast[1] if cast.size() > 1 else 0.0,
		"collision_names": collision_names,
	}


func _query_conservative_hull(
		access: CinderCargoAccess,
		bounds: AABB,
		ship_transform: Transform3D,
		exclude: Array
	) -> Array[Dictionary]:
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		ship_transform.basis,
		ship_transform * bounds.get_center()
	)
	query.collision_mask = PhysicsLayers.WORLD_BODY_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclude
	return access.get_world_3d().direct_space_state.intersect_shape(query, 64)


func _walk_route(
		access: CinderCargoAccess,
		player: PlayerController,
		local_waypoints: PackedVector3Array
	) -> Dictionary:
	var grounded_frames := 0
	var minimum_local_y := INF
	var consecutive_airborne_frames := 0
	var maximum_consecutive_airborne_frames := 0
	for local_waypoint in local_waypoints:
		var target := access.to_global(local_waypoint)
		var horizontal := Vector3(
			target.x - player.global_position.x,
			0.0,
			target.z - player.global_position.z
		)
		if horizontal.length() <= PLAYER_ROUTE_TOLERANCE:
			continue
		var segment_reached := false
		for _frame in 210:
			var desired := Vector3(
				target.x - player.global_position.x,
				0.0,
				target.z - player.global_position.z
			).normalized()
			var forward := (-player.global_basis.z).slide(Vector3.UP).normalized()
			var right := forward.cross(Vector3.UP).normalized()
			_set_movement_axis(&"move_left", &"move_right", desired.dot(right))
			_set_movement_axis(&"move_back", &"move_forward", desired.dot(forward))
			Input.action_press("sprint_boost")
			await physics_frame
			var local_position := access.to_local(player.global_position)
			minimum_local_y = minf(minimum_local_y, local_position.y)
			if player.is_on_floor():
				grounded_frames += 1
				consecutive_airborne_frames = 0
			else:
				consecutive_airborne_frames += 1
				maximum_consecutive_airborne_frames = maxi(
					maximum_consecutive_airborne_frames,
					consecutive_airborne_frames
				)
			var remaining := Vector2(
				target.x - player.global_position.x,
				target.z - player.global_position.z
			).length()
			if remaining <= PLAYER_ROUTE_TOLERANCE:
				segment_reached = true
				break
		_release_actions()
		await physics_frame
		if not segment_reached:
			return {
				"reached": false,
				"failed_waypoint": local_waypoint,
				"final_local": access.to_local(player.global_position),
				"grounded_frames": grounded_frames,
				"minimum_local_y": minimum_local_y,
				"maximum_consecutive_airborne_frames": maximum_consecutive_airborne_frames,
			}
	return {
		"reached": true,
		"grounded_frames": grounded_frames,
		"minimum_local_y": minimum_local_y,
		"maximum_consecutive_airborne_frames": maximum_consecutive_airborne_frames,
	}


func _set_movement_axis(negative_action: StringName, positive_action: StringName, value: float) -> void:
	Input.action_release(negative_action)
	Input.action_release(positive_action)
	if value > 0.02:
		Input.action_press(positive_action, minf(value, 1.0))
	elif value < -0.02:
		Input.action_press(negative_action, minf(-value, 1.0))


func _capture_forward_plus_frame() -> void:
	root.size = Vector2i(1400, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	await process_frame
	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	if access == null or terminal == null:
		print("CINDER_CARGO_ACCESS_CAPTURE_FAILED")
		quit(1)
		return
	var ship := JOVIAN_SCENE.instantiate() as HeroShip
	stage.add_child(ship)
	await process_frame
	ship.global_transform = access.get_berth().get_dock_transform()
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("03080c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91aeb8")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color("d8edf2")
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 58.0
	stage.add_child(camera)
	camera.global_position = access.to_global(Vector3(-48.0, 17.0, 39.0))
	camera.look_at(access.to_global(Vector3(-15.0, 3.3, 11.0)), Vector3.UP)
	for _frame in 10:
		await process_frame
		# HeroShip owns its gameplay camera each process tick. Evidence ownership is
		# deliberately reassigned after that tick so the capture cannot silently
		# become a cockpit/ship-camera frame.
		camera.current = true
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/cinder-cargo-access-forward-plus.png")
	print("CINDER_CARGO_ACCESS_CAPTURE_OK" if error == OK else "CINDER_CARGO_ACCESS_CAPTURE_FAILED")
	quit(0 if error == OK else 1)


func _release_actions() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint_boost", "jump"]:
		Input.action_release(action)


func _has_error(errors_value: PackedStringArray, expected: String) -> bool:
	for error_value in errors_value:
		if String(error_value) == expected:
			return true
	return false


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_ACCESS_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CINDER_CARGO_ACCESS_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
