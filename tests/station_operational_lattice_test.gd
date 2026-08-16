extends SceneTree

## Adversarial shared-world contract for the bounded Phase-3 operational lattice.
## This suite deliberately checks the live production hierarchy, physics space,
## lifecycle, audio resources, and aggregate budgets rather than isolated scenes.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")
const AMBIENCE_SCENE := preload("res://scenes/audio/station_machinery_ambience.tscn")
const DRESSING_SCENE := preload("res://scenes/world/components/station_structural_service_dressing.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD
const MOTION_EPSILON := 0.0002
const MINIMUM_BERTH_GAP := 0.15
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. A frame count, never a wall-clock grace: the door advances in
## `_physics_process`, and only a frame budget measures the same amount of panel
## motion on a loaded box as on an idle one.
const FRAME_BUDGET_GRACE := 30

const ACTIVITY_SPECS := {
	&"CentralTowServiceActivity": {
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(6.8, 0.0, 14.0)),
		"profile": &"full", "seed": 1103,
		"render_aabb": AABB(Vector3(2.3, 0.0, 8.6), Vector3(9.0, 7.25, 11.3)),
		"service_aabb": AABB(Vector3(1.8, -0.9, 8.1), Vector3(10.0, 7.6, 11.8)),
	},
	&"AftOperationsActivity": {
		"transform": Transform3D(Basis(Vector3.UP, PI), Vector3(5.8, 4.99, 61.2)),
		"profile": &"service_arm", "seed": 2207,
		"render_aabb": AABB(Vector3(3.4, 4.99, 59.45), Vector3(4.8, 5.45, 3.5)),
		"service_aabb": AABB(Vector3(3.05, 4.69, 59.3), Vector3(5.2, 5.2, 3.8)),
	},
	&"HabitatServicePatrol": {
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(59.15, 4.88, 15.5)),
		"profile": &"drone_patrol", "seed": 3301,
		"render_aabb": AABB(Vector3(55.6, 4.88, 10.95), Vector3(7.1, 2.4, 9.1)),
		"service_aabb": AABB(Vector3(54.95, 4.63, 10.5), Vector3(8.4, 3.2, 10.0)),
	},
	&"FreightApproachGantry": {
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-53.0, 0.38, 29.7)),
		"profile": &"gantry", "seed": 4409,
		"render_aabb": AABB(Vector3(-56.6, 0.38, 24.3), Vector3(7.2, 7.25, 10.8)),
		"service_aabb": AABB(Vector3(-57.1, -0.52, 23.8), Vector3(8.2, 7.6, 11.8)),
	},
	# Station-life placements added by the Phase-3 expansion. Same contract as the
	# four original rails: exact transform, exact seed, exact published render and
	# service envelopes, and no collision anywhere in the subtree.
	# Re-sited by the long-cargo pass. The old placement ran the rail along world
	# Z with its far end inside `JunctionPortalPost`; it now runs along world X
	# across the open middle of the same deck. Same profile, same seed, same
	# geometry — only the transform moved, and it moved because a solid gateway
	# leg was standing in the run.
	&"CentralCargoTransferLine": {
		"transform": Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.0, 17.9)),
		"profile": &"cargo_line", "seed": 5507,
		"render_aabb": AABB(Vector3(-10.85, 0.0, 15.25), Vector3(9.7, 2.98, 5.3)),
		"service_aabb": AABB(Vector3(-11.1, -0.3, 14.9), Vector3(10.2, 3.6, 6.0)),
	},
	# Two 21.6 m runs, one per branch arm, each spanning from an outer berth node
	# to the central junction deck.
	&"PortBranchCargoLine": {
		"transform": Transform3D(Basis.IDENTITY, Vector3(-22.0, 0.0, 16.75)),
		"profile": &"cargo_line_long", "seed": 9931,
		"render_aabb": AABB(Vector3(-33.4, 0.0, 14.95), Vector3(22.8, 3.0, 3.6)),
		"service_aabb": AABB(Vector3(-33.7, -0.3, 14.8), Vector3(23.4, 3.6, 3.9)),
	},
	&"StarboardBranchCargoLine": {
		"transform": Transform3D(Basis.IDENTITY, Vector3(23.3, 0.0, 16.75)),
		"profile": &"cargo_line_long", "seed": 10739,
		"render_aabb": AABB(Vector3(11.9, 0.0, 14.95), Vector3(22.8, 3.0, 3.6)),
		"service_aabb": AABB(Vector3(11.6, -0.3, 14.8), Vector3(23.4, 3.6, 3.9)),
	},
	&"AftCrewWorkPost": {
		"transform": Transform3D(Basis.IDENTITY, Vector3(-7.0, 4.2, 65.0)),
		"profile": &"crew_workpost", "seed": 6607,
		"render_aabb": AABB(Vector3(-9.85, 4.2, 63.05), Vector3(5.7, 2.6, 3.9)),
		"service_aabb": AABB(Vector3(-10.0, 4.0, 62.8), Vector3(6.0, 3.0, 4.4)),
	},
	&"HabitatSkywatchPost": {
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(73.0, 5.08, 19.0)),
		"profile": &"observatory", "seed": 7703,
		"render_aabb": AABB(Vector3(70.65, 5.08, 16.65), Vector3(4.7, 3.75, 4.7)),
		"service_aabb": AABB(Vector3(70.5, 4.98, 16.5), Vector3(5.0, 4.8, 5.0)),
	},
	&"FreightApproachSignage": {
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-41.0, 6.18, 29.0)),
		"profile": &"signage_pylon", "seed": 8821,
		"render_aabb": AABB(Vector3(-42.5, 6.18, 27.2), Vector3(3.0, 4.5, 3.6)),
		"service_aabb": AABB(Vector3(-42.8, 5.88, 27.0), Vector3(3.6, 5.0, 4.0)),
	},
}

const AMBIENCE_SPECS := {
	&"central-berth-utilities": {"position": Vector3(10.65, 1.8, -19.25), "seed": 4831, "frequency": 44.0, "maximum": 26.0, "reference": 4.0},
	&"aft-operations-service-wall": {"position": Vector3(10.0, 2.35, 60.55), "seed": 7759, "frequency": 52.0, "maximum": 24.0, "reference": 3.5},
	&"habitat-environmental-main": {"position": Vector3(59.15, 3.2, 20.95), "seed": 9127, "frequency": 39.0, "maximum": 22.0, "reference": 3.0},
	&"freight-control-machinery": {"position": Vector3(-33.75, 2.58, 57.8), "seed": 12203, "frequency": 61.0, "maximum": 28.0, "reference": 4.0},
}

const DRESSING_SPECS := {
	&"CentralBerthOuterFascia": {"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(13.5, -0.02, -10.0)), "length": 20.0, "profile": &"standard"},
	&"AftOperationsOuterFascia": {"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(10.86, 4.6, 60.55)), "length": 6.0, "profile": &"light"},
	&"HabitatOuterServiceDressing": {"transform": Transform3D(Basis.IDENTITY, Vector3(59.15, 4.45, 21.94)), "length": 12.0, "profile": &"standard"},
	&"FreightRackServiceDressing": {"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-75.34, 0.38, 56.8)), "length": 20.0, "profile": &"light"},
}

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_pre_tree_lifecycle()

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "complete production main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null, "production main scene owns the shared ShipyardWorld")
	if world == null:
		await _cleanup(game)
		_finish()
		return
	var activities := world.get_station_operations_activities()
	var ambience_nodes := world.get_station_machinery_ambience_nodes()
	var dressings := world.get_station_structural_service_dressings()
	for activity in activities:
		activity.set_activity_paused(true)

	_test_discovery_audit_and_exact_roster(world, activities, ambience_nodes, dressings)
	_test_exact_envelopes_and_berth_gaps(world, activities)
	await _test_activity_mount_support(world, activities)
	await _test_aft_routes_and_negative_space(world)
	await _test_habitat_routes_and_negative_space(world)
	await _test_freight_routes_and_ship_clearance(world)
	await _test_open_launch_spine(world)
	_test_presentation_only_subtrees(activities, ambience_nodes, dressings)
	_test_deterministic_motion(activities)
	_test_audio_contract(ambience_nodes)
	_test_structural_contract(world, dressings)
	await _test_world_lifecycle(world, activities, ambience_nodes, dressings)
	await _test_freed_emitter_callback_safety()
	_test_world_audit_detects_placement_mutation(world, activities, dressings)
	_test_world_audit_detects_roster_and_configuration_mutation(world, activities, ambience_nodes, dressings)
	await _test_world_audit_detects_live_hierarchy_drift(world, activities, ambience_nodes, dressings)
	await _test_child_detach_readd_lifecycle(world, activities, ambience_nodes)
	await _test_replaced_emitter_hook_rebinding()
	await _test_detach_readd_lifecycle(game, world)

	activities = world.get_station_operations_activities()
	ambience_nodes = world.get_station_machinery_ambience_nodes()
	dressings = world.get_station_structural_service_dressings()
	var lifetime_references := _capture_lifetime_references(world, activities, ambience_nodes, dressings)
	activities.clear()
	ambience_nodes.clear()
	dressings.clear()
	world = null
	await _cleanup(game)
	game = null
	_check(_all_released(lifetime_references), "shared-world teardown releases every operational root, mover, and audio voice")
	_finish()


func _test_pre_tree_lifecycle() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "ShipyardWorld can be configured before tree entry")
	if world == null:
		return
	world.set_station_activity_enabled(false)
	root.add_child(world)
	await process_frame
	await physics_frame
	var activities := world.get_station_operations_activities()
	var ambience_nodes := world.get_station_machinery_ambience_nodes()
	_check(not world.is_station_activity_enabled(), "pre-tree disabled lifecycle flag survives initial construction")
	_check(activities.size() == 10 and ambience_nodes.size() == 4, "pre-tree lifecycle still constructs the complete 10/4 operational roster")
	var disabled_children := true
	for activity in activities:
		disabled_children = disabled_children and not activity.is_activity_enabled() and not activity.is_processing() and not bool(activity.get_activity_state().visible)
	for ambience in ambience_nodes:
		disabled_children = disabled_children and not ambience.is_ambience_enabled() and _players_stopped_and_detached(ambience)
	_check(disabled_children, "pre-tree disable reaches every activity and ambience child on first ready")
	_check(not world.get_jovian_freight_berth().is_equipment_animation_enabled(), "pre-tree disable reaches existing freight equipment")
	var collision := world.get_station_activity_collision_audit_report()
	var collision_root := world.get_node_or_null(^"OperationalLattice/ActivityCollision") as Node3D
	var disabled_body := (
		collision_root.get_node_or_null(^"CentralTowServiceActivitySolids") as StaticBody3D
		if collision_root != null else null
	)
	_check(
		bool(collision.valid) and int(collision.body_count) == 7
		and int(collision.shape_count) == 63 and int(collision.active_body_count) == 0,
		"pre-tree disable builds the exact 7-body/63-shape solid roster with zero active bodies"
	)
	_check(
		disabled_body != null and not (await _physics_query_finds_body(world, disabled_body)),
		"pre-tree disabled activity solids never enter the live World physics space"
	)
	world.queue_free()
	world = null
	activities.clear()
	ambience_nodes.clear()
	await process_frame
	await physics_frame
	await process_frame

	# Repeat through the frame-yielding boot path. The callback observes every
	# completed build stage, so a starts-enabled collision body cannot flash on
	# between the collision stage and the later lifecycle-restore stage.
	var staged := WORLD_SCENE.instantiate() as ShipyardWorld
	staged.set_station_activity_enabled(false)
	staged.prepare_staged_construction()
	root.add_child(staged)
	var staged_saw_active := [false]
	await staged.run_staged_construction(func(_label: String) -> void:
		var staged_root := staged.get_node_or_null(^"OperationalLattice/ActivityCollision") as Node3D
		if staged_root == null:
			return
		for candidate in staged_root.find_children("*", "StaticBody3D", false, false):
			if (candidate as StaticBody3D).collision_layer != PhysicsLayers.NONE:
				staged_saw_active[0] = true
	)
	await physics_frame
	var staged_collision := staged.get_station_activity_collision_audit_report()
	_check(
		not bool(staged_saw_active[0]) and bool(staged_collision.valid)
		and int(staged_collision.body_count) == 7
		and int(staged_collision.shape_count) == 63
		and int(staged_collision.active_body_count) == 0,
		"staged pre-tree disable never exposes collision and finishes at exact 7/63 active=0"
	)
	staged.queue_free()
	await process_frame
	await physics_frame

	var staged_toggle := WORLD_SCENE.instantiate() as ShipyardWorld
	staged_toggle.prepare_staged_construction()
	root.add_child(staged_toggle)
	var toggled_after_staffing := [false]
	var toggle_saw_active := [false]
	await staged_toggle.run_staged_construction(func(label: String) -> void:
		if label == "Staffing the operations lattice":
			staged_toggle.set_station_activity_enabled(false)
			toggled_after_staffing[0] = true
		var staged_root := staged_toggle.get_node_or_null(^"OperationalLattice/ActivityCollision") as Node3D
		if staged_root == null:
			return
		for candidate in staged_root.find_children("*", "StaticBody3D", false, false):
			if (candidate as StaticBody3D).collision_layer != PhysicsLayers.NONE:
				toggle_saw_active[0] = true
	)
	await physics_frame
	var toggled_collision := staged_toggle.get_station_activity_collision_audit_report()
	_check(
		bool(toggled_after_staffing[0]) and not bool(toggle_saw_active[0])
		and bool(toggled_collision.valid)
		and int(toggled_collision.active_body_count) == 0,
		"staged true-to-false toggle after Staffing reaches live pre-index activities and never flashes a solid body"
	)
	staged_toggle.queue_free()
	await process_frame
	await physics_frame


func _test_discovery_audit_and_exact_roster(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience],
	dressings: Array[StationStructuralServiceDressing]
) -> void:
	_check(activities.size() == 10 and ambience_nodes.size() == 4 and dressings.size() == 4, "production OperationalLattice exposes exactly 10 activities, 4 ambience emitters, and 4 dressings")
	var activity_group: Array[Node] = []
	for candidate in get_nodes_in_group(&"station_operations_activity"):
		if candidate is Node and world.is_ancestor_of(candidate as Node):
			activity_group.append(candidate as Node)
	var ambience_group: Array[Node] = []
	for candidate in get_nodes_in_group(&"station_machinery_ambience"):
		if candidate is Node and world.is_ancestor_of(candidate as Node):
			ambience_group.append(candidate as Node)
	_check(_node_sets_match(activities, activity_group), "activity accessor and stable discovery group expose exactly the same four roots")
	_check(_node_sets_match(ambience_nodes, ambience_group), "ambience accessor and stable discovery group expose exactly the same four roots")

	var activities_by_name := _nodes_by_name(activities)
	for activity_name: StringName in ACTIVITY_SPECS:
		var activity := activities_by_name.get(activity_name) as StationOperationsActivity
		var spec := ACTIVITY_SPECS[activity_name] as Dictionary
		_check(activity != null, "exact integrated activity exists: %s" % activity_name)
		if activity == null:
			continue
		_check(activity.get_parent().name == "Activities" and activity.get_parent().get_parent().name == "OperationalLattice", "%s is world-owned by the stable OperationalLattice hierarchy" % activity_name)
		_check(activity.global_transform.is_equal_approx(spec.transform as Transform3D), "%s retains its exact audited world transform" % activity_name)
		_check(activity.get_activity_profile_id() == spec.profile and activity.variation_seed == int(spec.seed), "%s locks its role-specific profile and deterministic seed" % activity_name)
		_check(bool(activity.get_audit_report().valid), "%s passes its complete reusable component audit" % activity_name)

	var ambience_by_id := _ambience_by_id(ambience_nodes)
	for emitter_id: StringName in AMBIENCE_SPECS:
		var ambience := ambience_by_id.get(emitter_id) as StationMachineryAmbience
		var spec := AMBIENCE_SPECS[emitter_id] as Dictionary
		_check(ambience != null, "exact integrated ambience emitter exists: %s" % emitter_id)
		if ambience == null:
			continue
		_check(ambience.global_position.is_equal_approx(spec.position as Vector3), "%s retains its exact acoustic origin" % emitter_id)
		_check(ambience.synthesis_seed == int(spec.seed) and is_equal_approx(ambience.base_frequency_hz, float(spec.frequency)), "%s locks deterministic synthesis seed and base frequency" % emitter_id)

	var dressing_by_name := _nodes_by_name(dressings)
	for dressing_name: StringName in DRESSING_SPECS:
		var dressing := dressing_by_name.get(dressing_name) as StationStructuralServiceDressing
		var spec := DRESSING_SPECS[dressing_name] as Dictionary
		_check(dressing != null, "exact integrated structural dressing exists: %s" % dressing_name)
		if dressing == null:
			continue
		var configuration := dressing.get_configuration()
		_check(dressing.global_transform.is_equal_approx(spec.transform as Transform3D), "%s retains its exact safe planar mount" % dressing_name)
		_check(is_equal_approx(float(configuration.segment_length), float(spec.length)) and configuration.structural_profile_name == spec.profile, "%s locks its bounded length and structural profile" % dressing_name)

	var report := world.get_operational_lattice_audit_report()
	_check(bool(report.valid) and (report.errors as PackedStringArray).is_empty(), "integrated operational-lattice audit is valid without suppressed errors")
	var evidence := report.evidence as Dictionary
	_check(report.evidence_status == &"modern_interpretation" and bool(evidence.source_bounded), "world audit keeps the operational pass explicitly source-bounded modern interpretation")
	_check(not bool(evidence.authenticated_original_geometry) and not bool(evidence.authenticated_original_placement) and not bool(evidence.authenticated_original_layout) and not bool(evidence.authenticated_original_audio), "world audit makes no authenticated original geometry, placement, layout, or audio claim")
	var placements := report.placements as Dictionary
	_check((placements.activities as Dictionary).size() == 10 and (placements.ambience as Dictionary).size() == 4 and (placements.structural_dressing as Dictionary).size() == 4, "audit publishes all exact placements instead of only aggregate counts")
	for activity_name: StringName in ACTIVITY_SPECS:
		var placement := (placements.activities as Dictionary).get(activity_name, {}) as Dictionary
		_check(int(placement.get("variation_seed", -1)) == int((ACTIVITY_SPECS[activity_name] as Dictionary).seed), "activity audit records deterministic seed: %s" % activity_name)
	for emitter_id: StringName in AMBIENCE_SPECS:
		var placement := (placements.ambience as Dictionary).get(emitter_id, {}) as Dictionary
		_check(int(placement.get("synthesis_seed", -1)) == int((AMBIENCE_SPECS[emitter_id] as Dictionary).seed) and placement.get("synthesis", {}) is Dictionary, "ambience audit records seed and synthesis provenance: %s" % emitter_id)
	var detached := world.get_operational_lattice_audit_report()
	(detached.performance as Dictionary).clear()
	_check(not (world.get_operational_lattice_audit_report().performance as Dictionary).is_empty(), "world operational audit is deeply detached from callers")


func _test_exact_envelopes_and_berth_gaps(world: ShipyardWorld, activities: Array[StationOperationsActivity]) -> void:
	var activities_by_name := _nodes_by_name(activities)
	var service_aabbs: Array[AABB] = []
	for activity_name: StringName in ACTIVITY_SPECS:
		var activity := activities_by_name.get(activity_name) as StationOperationsActivity
		if activity == null:
			continue
		var spec := ACTIVITY_SPECS[activity_name] as Dictionary
		var contract := activity.get_integration_contract()
		var render_aabb := _transformed_local_aabb(activity.global_transform, contract.local_min, contract.local_max)
		var service_half := contract.service_zone_half_extents as Vector3
		var service_aabb := _transformed_local_aabb(contract.service_zone_transform as Transform3D, -service_half, service_half)
		service_aabbs.append(service_aabb)
		_check(_aabb_approx(render_aabb, spec.render_aabb as AABB), "%s render envelope matches the exact audited world bounds" % activity_name)
		_check(_aabb_approx(service_aabb, spec.service_aabb as AABB), "%s service envelope matches the exact audited world bounds" % activity_name)
		_check(_all_mesh_corners_inside(activity, render_aabb, 0.025), "%s moving/rendered meshes stay inside the published footprint" % activity_name)

	var berth_aabbs: Array[AABB] = []
	for berth_id in world.get_berth_ids():
		var berth := world.get_berth_node(berth_id)
		var half := berth.get_landing_half_extents()
		berth_aabbs.append(_transformed_local_aabb(berth.get_dock_transform(), -half, half))
	var all_berth_gaps_safe := true
	var smallest_gap := INF
	for service_aabb in service_aabbs:
		for berth_aabb in berth_aabbs:
			if _aabbs_overlap(service_aabb, berth_aabb, 0.0):
				all_berth_gaps_safe = false
			else:
				smallest_gap = minf(smallest_gap, _aabb_separation(service_aabb, berth_aabb))
	_check(all_berth_gaps_safe and smallest_gap >= MINIMUM_BERTH_GAP - 0.001, "all activity service envelopes leave every live berth clear by at least 0.15 m (minimum %.3f m)" % smallest_gap)
	var roots_separated := true
	for first_index in activities.size():
		for second_index in range(first_index + 1, activities.size()):
			roots_separated = roots_separated and activities[first_index].global_position.distance_to(activities[second_index].global_position) >= 12.0
	_check(roots_separated, "all eight activity roots retain the recommended 12 m sparse-lattice spacing")


func _test_activity_mount_support(world: ShipyardWorld, activities: Array[StationOperationsActivity]) -> void:
	var by_name := _nodes_by_name(activities)
	var probes := {
		&"CentralTowServiceActivity": [
			[Vector3(4.08, 0.25, 9.7), Vector3(4.08, -0.6, 9.7), [&"CentralJunction"]],
			[Vector3(9.52, 0.25, 9.7), Vector3(9.52, -0.6, 9.7), [&"CentralJunction"]],
			[Vector3(4.08, 0.25, 18.3), Vector3(4.08, -0.6, 18.3), [&"CentralJunction"]],
			[Vector3(9.52, 0.25, 18.3), Vector3(9.52, -0.6, 18.3), [&"CentralJunction"]],
		],
		&"AftOperationsActivity": [
			[Vector3(5.8, 5.24, 61.2), Vector3(5.8, 4.39, 61.2), [&"OperationsCeiling"]],
		],
		&"HabitatServicePatrol": [
			[Vector3(55.9, 5.13, 11.4), Vector3(55.9, 4.25, 11.4), [&"HabitatCeiling"]],
			[Vector3(62.4, 5.13, 11.4), Vector3(62.4, 4.25, 11.4), [&"HabitatCeiling"]],
			[Vector3(55.9, 5.13, 19.6), Vector3(55.9, 4.25, 19.6), [&"HabitatCeiling"]],
			[Vector3(62.4, 5.13, 19.6), Vector3(62.4, 4.25, 19.6), [&"HabitatCeiling"]],
		],
		&"FreightApproachGantry": [
			[Vector3(-55.72, 0.63, 25.4), Vector3(-55.72, -0.22, 25.4), [&"ConnectionDeckA"]],
			# Two decks meet here and their top faces are coincident, so which one
			# a downward ray reports is broad-phase registration order rather than
			# anything about the station. Both are audited supports at the same
			# plane; the height check above is what proves the foot is seated.
			[Vector3(-50.28, 0.63, 25.4), Vector3(-50.28, -0.22, 25.4), [&"ConnectionDeckA", &"ConnectionHandoffDeck"]],
			[Vector3(-55.72, 0.63, 34.0), Vector3(-55.72, -0.22, 34.0), [&"ConnectionDeckC"]],
			[Vector3(-50.28, 0.63, 34.0), Vector3(-50.28, -0.22, 34.0), [&"ConnectionDeckC"]],
		],
		# Station-life mount feet. Each probe is a safety-beacon foot of the new
		# placement, so what is checked is the actual outermost thing the
		# component seats on the deck rather than a convenient interior point.
		&"CentralCargoTransferLine": [
			[Vector3(-10.55, 0.25, 15.6), Vector3(-10.55, -0.6, 15.6), [&"CentralJunction"]],
			[Vector3(-1.45, 0.25, 15.6), Vector3(-1.45, -0.6, 15.6), [&"CentralJunction"]],
			[Vector3(-10.55, 0.25, 20.2), Vector3(-10.55, -0.6, 20.2), [&"CentralJunction"]],
			[Vector3(-1.45, 0.25, 20.2), Vector3(-1.45, -0.6, 20.2), [&"CentralJunction"]],
		],
		# The long runs bridge two decks each, so their four feet deliberately do
		# not all land on the same body: the outboard pair stands on the branch
		# arm and the inboard pair on the central junction deck.
		&"PortBranchCargoLine": [
			[Vector3(-33.05, 0.25, 15.3), Vector3(-33.05, -0.6, 15.3), [&"PortBranchArm"]],
			[Vector3(-10.95, 0.25, 15.3), Vector3(-10.95, -0.6, 15.3), [&"CentralJunction"]],
			[Vector3(-33.05, 0.25, 18.2), Vector3(-33.05, -0.6, 18.2), [&"PortBranchArm"]],
			[Vector3(-10.95, 0.25, 18.2), Vector3(-10.95, -0.6, 18.2), [&"CentralJunction"]],
		],
		&"StarboardBranchCargoLine": [
			[Vector3(12.25, 0.25, 15.3), Vector3(12.25, -0.6, 15.3), [&"CentralJunction"]],
			[Vector3(34.35, 0.25, 15.3), Vector3(34.35, -0.6, 15.3), [&"StarboardBranchArm"]],
			[Vector3(12.25, 0.25, 18.2), Vector3(12.25, -0.6, 18.2), [&"CentralJunction"]],
			[Vector3(34.35, 0.25, 18.2), Vector3(34.35, -0.6, 18.2), [&"StarboardBranchArm"]],
		],
		&"AftCrewWorkPost": [
			[Vector3(-9.4, 4.45, 63.4), Vector3(-9.4, 3.6, 63.4), [&"UpperFloor"]],
			[Vector3(-4.6, 4.45, 63.4), Vector3(-4.6, 3.6, 63.4), [&"UpperFloor"]],
			[Vector3(-9.4, 4.45, 66.6), Vector3(-9.4, 3.6, 66.6), [&"UpperFloor"]],
			[Vector3(-4.6, 4.45, 66.6), Vector3(-4.6, 3.6, 66.6), [&"UpperFloor"]],
		],
		&"HabitatSkywatchPost": [
			[Vector3(71.0, 5.33, 17.0), Vector3(71.0, 4.48, 17.0), [&"CommonCeiling"]],
			[Vector3(75.0, 5.33, 17.0), Vector3(75.0, 4.48, 17.0), [&"CommonCeiling"]],
			[Vector3(71.0, 5.33, 21.0), Vector3(71.0, 4.48, 21.0), [&"CommonCeiling"]],
			[Vector3(75.0, 5.33, 21.0), Vector3(75.0, 4.48, 21.0), [&"CommonCeiling"]],
		],
		&"FreightApproachSignage": [
			[Vector3(-42.2, 6.43, 27.5), Vector3(-42.2, 5.58, 27.5), [&"RegistryPodRoof"]],
			[Vector3(-39.8, 6.43, 27.5), Vector3(-39.8, 5.58, 27.5), [&"RegistryPodRoof"]],
			[Vector3(-42.2, 6.43, 30.5), Vector3(-42.2, 5.58, 30.5), [&"RegistryPodRoof"]],
			[Vector3(-39.8, 6.43, 30.5), Vector3(-39.8, 5.58, 30.5), [&"RegistryPodRoof"]],
		],
	}
	for activity_name: StringName in probes:
		_check(by_name.has(activity_name), "support probes resolve activity: %s" % activity_name)
		var all_supported := true
		var hit_names := PackedStringArray()
		for probe in probes[activity_name]:
			var hit := await _ray(world, probe[0], probe[1])
			var collider := hit.get("collider") as Node
			var hit_name := StringName(collider.name) if collider != null else &""
			hit_names.append(str(hit_name))
			# Every probe starts 0.25 m above its activity's mount plane, so the
			# plane itself is recoverable from the probe and does not need its own
			# table. Checking it makes this audit strictly stronger than the name
			# comparison alone: a foot that finds the right body at the wrong
			# height is now a failure too.
			var expected_plane: float = (probe[0] as Vector3).y - 0.25
			var seated: bool = (
				not hit.is_empty()
				and absf((hit.position as Vector3).y - expected_plane) <= 0.03
			)
			all_supported = all_supported and seated and (probe[2] as Array).has(hit_name)
		_check(all_supported, "%s mount feet hit only their exact audited support bodies: %s" % [activity_name, hit_names])


func _test_aft_routes_and_negative_space(world: ShipyardWorld) -> void:
	var aft := world.get_node("AftJunctionStack") as AftJunctionStack
	var support_x := [0.0, 24.0, 32.0, 39.0, 43.5, 47.7, 50.0]
	var supported := true
	for z_value in support_x:
		supported = supported and not (await _ray(world, Vector3(0, 2, z_value), Vector3(0, -2, z_value))).is_empty()
	_check(supported, "Aft published lower approach/junction route retains continuous support")
	var portal := await _ray(world, Vector3(0, 1.2, 20.5), Vector3(0, 1.2, 24.5))
	_check(portal.is_empty(), "Aft forward handoff remains an unobstructed shared-world portal")
	var stairs_supported := true
	var stairs_clear := true
	for sample in aft.get_stair_surface_samples():
		stairs_supported = stairs_supported and not (await _ray_local(aft, sample + Vector3.UP * 0.55, sample - Vector3.UP * 0.5)).is_empty()
		stairs_clear = stairs_clear and (await _ray_local(aft, sample + Vector3.UP * 0.24, sample + Vector3.UP * 2.7)).is_empty()
	_check(stairs_supported and stairs_clear, "all 15 Aft stair intervals retain support and published headroom")
	var negative_clear := true
	for probe in [
		[Vector3(-9, 8, 6), Vector3(-9, -4, 6)],
		[Vector3(8.5, 8, 5.8), Vector3(8.5, -4, 5.8)],
		[Vector3(0, 0.3, 7.2), Vector3(0, 12, 7.2)],
		[Vector3(-7.8, 4.5, 16), Vector3(-7.8, 13, 16)],
	]:
		negative_clear = negative_clear and (await _ray_local(aft, probe[0], probe[1])).is_empty()
	_check(negative_clear, "Aft west/east voids and both open-sky sightlines remain genuine negative space")


func _test_habitat_routes_and_negative_space(world: ShipyardWorld) -> void:
	var habitat := world.get_habitat_spine()
	var door := habitat.get_main_access()
	if not door.is_open():
		_check(door.interact(habitat), "Habitat real pressure door accepts opening for route probes")
		var route_door_opened := await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
		_check(route_door_opened, "Habitat pressure door opens fully inside its physics-frame budget before the route probes")
	var support_samples := PackedVector3Array([
		Vector3(14, 1.5, 15.5), Vector3(25, 1.5, 15.5), Vector3(37, 1.5, 15.5),
		Vector3(43, 1.5, 15.5), Vector3(46, 1.5, 15.5), Vector3(48.8, 1.5, 15.5),
		Vector3(50.2, 1.5, 15.5), Vector3(52, 1.5, 15.5), Vector3(56, 1.5, 15.5), Vector3(60, 1.5, 15.5),
	])
	var support_clear := true
	for sample in support_samples:
		var hit := await _ray(world, sample, Vector3(sample.x, -1.5, sample.z))
		support_clear = support_clear and not hit.is_empty() and absf(float(hit.position.y)) <= 0.035
	_check(support_clear, "shared starboard-to-Habitat route retains continuous flush floor support")
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var route_samples := PackedVector3Array([
		Vector3(0, 1.08, -3.2), Vector3(0, 1.08, -0.75), Vector3(0, 1.08, 1.55), Vector3(0, 1.08, 5),
		Vector3(0, 1.08, 10), Vector3(0, 1.08, 16.5), Vector3(0, 1.08, 19), Vector3(-2, 1.08, 21.3),
		Vector3(-2, 1.08, 23.2), Vector3(0, 1.08, 24.2),
	])
	var capsules_clear := true
	for sample in route_samples:
		capsules_clear = capsules_clear and (await _intersect_shape(world, capsule, Transform3D(Basis.IDENTITY, habitat.to_global(sample)), 24)).is_empty()
	_check(capsules_clear, "production player capsule clears the complete published Habitat route")
	var headroom_clear := true
	for x_value in [43.0, 47.5, 50.5, 55.0, 60.0]:
		headroom_clear = headroom_clear and (await _ray(world, Vector3(x_value, 0.2, 15.5), Vector3(x_value, 4.0, 15.5))).is_empty()
	_check(headroom_clear, "Habitat shared approach and corridor retain four-metre headroom")
	var negative_clear := true
	var operational_root := world.get_node("OperationalLattice")
	for sample in habitat.get_negative_space_samples():
		var hit := await _ray_local(habitat, sample + Vector3.UP * 7, sample - Vector3.UP * 4)
		var collider := hit.get("collider") as Node
		# Two samples can meet the pre-existing shared starboard deck outside the
		# isolated Habitat footprint. The invariant for this pass is that no new
		# operational component introduces a collider into any published void ray.
		negative_clear = negative_clear and (collider == null or not operational_root.is_ancestor_of(collider))
	_check(negative_clear, "all four published Habitat negative-space samples gain no operational-lattice collider")


func _test_freight_routes_and_ship_clearance(world: ShipyardWorld) -> void:
	var freight := world.get_jovian_freight_berth()
	var supported := true
	for z_value in [-4.2, -2.0, 2.0, 6.5, 9.0, 13.5, 18.5, 23.5, 28.5, 33.5, 38.5, 43.5, 47.5]:
		supported = supported and not (await _ray_local(freight, Vector3(0, 1.5, z_value), Vector3(0, -1, z_value))).is_empty()
	for sample in [Vector3(-18.7, 1.5, 18), Vector3(-18.7, 1.5, 28), Vector3(-18.7, 1.5, 40), Vector3(12.8, 1.5, 29), Vector3(15.1, 1.5, 29), Vector3(17.6, 1.5, 29), Vector3(19.2, 1.5, 29)]:
		supported = supported and not (await _ray_local(freight, sample, Vector3(sample.x, -1, sample.z))).is_empty()
	_check(supported, "Freight centreline, cargo rack, and service-room routes retain physical support")
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var route_samples := [Vector3(0, 1.08, -3.4), Vector3(0, 1.08, 3), Vector3(0, 1.08, 8.5), Vector3(10.4, 1.08, 29), Vector3(12.6, 1.08, 29), Vector3(14.6, 1.08, 29)]
	var route_clear := true
	var headroom_clear := true
	for sample in route_samples:
		route_clear = route_clear and (await _intersect_shape(world, capsule, Transform3D(Basis.IDENTITY, freight.to_global(sample)), 32)).is_empty()
		headroom_clear = headroom_clear and (await _ray_local(freight, Vector3(sample.x, 0.2, sample.z), Vector3(sample.x, 4.1, sample.z))).is_empty()
	_check(route_clear and headroom_clear, "Freight published lanes retain player-capsule clearance and 4.1 m headroom")
	_check((await _ray_local(freight, Vector3(0, 3, 49.5), Vector3(0, 3, 55))).is_empty(), "Freight outbound endpoint remains open negative space")
	var envelope := freight.get_ship_clearance_envelope()
	var shape := BoxShape3D.new()
	shape.size = (envelope.half_extents as Vector3) * 2
	var hits := await _intersect_shape(world, shape, envelope.world_transform as Transform3D, 128)
	var only_floor := not hits.is_empty()
	for hit in hits:
		var collider := hit.get("collider") as Node
		only_floor = only_floor and collider != null and str(collider.name).begins_with("ApronDeck")
	_check(only_floor, "protected freight ship envelope meets only authoritative apron floor bodies")


func _test_open_launch_spine(world: ShipyardWorld) -> void:
	var crossing_clear := true
	var headroom_clear := true
	for z_value in [-34.0, -46.0, -58.0]:
		crossing_clear = crossing_clear and (await _ray(world, Vector3(-9.5, 1.2, z_value), Vector3(9.5, 1.2, z_value))).is_empty()
		headroom_clear = headroom_clear and (await _ray(world, Vector3(0, 0.2, z_value), Vector3(0, 10, z_value))).is_empty()
	_check(crossing_clear and headroom_clear, "launch spine retains full 19 m cross-width clearance and ten-metre open headroom")
	var launch_body := world.find_child("LaunchArmDeck", true, false) as StaticBody3D
	var launch_aabb := _static_body_world_aabb(launch_body)
	# RUNWAY-SEAM-001. Re-frozen from AABB(-10.75, -0.72, -68) size (21.5, 0.72, 40)
	# to size (21.5, 0.72, 40.25): the arm's aft edge moves from z = -28.00 to
	# z = -27.75 so it meets the authored central-berth shell's own edge instead of
	# stopping short of it and leaving the collision-only transition block's
	# 0.095 m top plane standing there with nothing drawn on it. Width, top plane
	# and the forward end at z = -68.0 are all unchanged, so the protected launch
	# volume asserted immediately below is unchanged.
	_check(_aabb_approx(launch_aabb, AABB(Vector3(-10.75, -0.72, -68), Vector3(21.5, 0.72, 40.25))), "LaunchArmDeck physical footprint remains exactly unchanged")
	var protected_launch := AABB(Vector3(-10.75, 0, -68), Vector3(21.5, 12, 40))
	var operations_clear := true
	for activity in world.get_station_operations_activities():
		var contract := activity.get_integration_contract()
		var half := contract.service_zone_half_extents as Vector3
		var service_aabb := _transformed_local_aabb(contract.service_zone_transform, -half, half)
		operations_clear = operations_clear and not _aabbs_overlap(protected_launch, service_aabb, 0.0)
	_check(operations_clear, "no operational activity or service envelope intrudes on the protected launch volume")


func _test_presentation_only_subtrees(
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience],
	dressings: Array[StationStructuralServiceDressing]
) -> void:
	for activity in activities:
		_check(not _subtree_has_forbidden_physics(activity), "%s contains no collider, body, area, or physics mover" % activity.name)
		_check(_count_type(activity, "Light3D") == 0 and _count_type(activity, "GPUParticles3D") == 0 and _count_type(activity, "CPUParticles3D") == 0 and _count_type(activity, "AudioStreamPlayer3D") == 0, "%s adds no lights, particles, or audio voices" % activity.name)
	for ambience in ambience_nodes:
		_check(not _subtree_has_forbidden_physics(ambience), "%s audio subtree cannot alter physics" % ambience.get_emitter_id())
	for dressing in dressings:
		_check(not _subtree_has_forbidden_physics(dressing), "%s structural dressing contains no collider, body, area, or mover" % dressing.name)
		_check(_static_dressing_types_allowed(dressing), "%s contains only static visual, marker, and bounded non-shadow light nodes" % dressing.name)


func _test_deterministic_motion(activities: Array[StationOperationsActivity]) -> void:
	for activity in activities:
		activity.set_activity_enabled(true)
		activity.set_activity_paused(true)
		var reference_states := {}
		for rate in [30, 60, 120]:
			activity.reset_activity_time()
			activity.set_activity_paused(false)
			for _step in roundi(6.0 * float(rate)):
				activity.advance_activity_simulation(1.0 / float(rate))
			activity.set_activity_paused(true)
			reference_states[rate] = activity.get_activity_state()
		activity.set_activity_time(6.0)
		var absolute := activity.get_activity_state()
		var subdivisions_match := true
		for rate in [30, 60, 120]:
			subdivisions_match = subdivisions_match and _activity_states_match(reference_states[rate], absolute)
		_check(subdivisions_match, "%s motion is identical at deterministic 30/60/120 Hz and absolute time" % activity.name)

		var stable := activity.get_activity_state()
		_check(not activity.advance_activity_simulation(1.0) and _activity_states_match(stable, activity.get_activity_state()), "%s pause blocks manual and process advancement" % activity.name)
		activity.set_activity_enabled(false)
		activity.set_activity_paused(false)
		_check(not activity.advance_activity_simulation(1.0) and not activity.is_processing(), "%s disable blocks advancement even when unpaused" % activity.name)
		activity.set_activity_time(4.0)
		activity.reset_activity_time()
		_check(is_zero_approx(activity.get_activity_time()) and not bool(activity.get_activity_state().visible) and not activity.is_processing(), "%s reset while disabled restores exact zero-time pose without presentation work" % activity.name)
		_check(not activity.set_activity_time(-0.01) and not activity.set_activity_time(NAN) and not activity.set_activity_time(INF), "%s rejects negative and non-finite absolute time" % activity.name)
		_check(not activity.advance_activity_simulation(-0.01) and not activity.advance_activity_simulation(NAN) and not activity.advance_activity_simulation(INF), "%s rejects invalid simulation deltas" % activity.name)
		activity.set_activity_enabled(true)
		activity.set_activity_paused(true)


func _test_audio_contract(ambience_nodes: Array[StationMachineryAmbience]) -> void:
	_check(AudioServer.get_bus_index(&"Ambience") >= 0, "Ambience audio bus exists in the production mix")
	var emitter_ids := {}
	var total_voices := 0
	var total_bytes := 0
	var total_budget := 0
	for ambience in ambience_nodes:
		var emitter_id := ambience.get_emitter_id()
		emitter_ids[emitter_id] = true
		var spec := AMBIENCE_SPECS.get(emitter_id, {}) as Dictionary
		var audit := ambience.get_audit_report()
		var synthesis := audit.synthesis as Dictionary
		var performance := audit.performance as Dictionary
		var players := ambience.find_children("*", "AudioStreamPlayer3D", true, false)
		_check(bool(audit.valid) and players.size() == 2, "%s passes audit with exactly two positional voices" % emitter_id)
		var spatially_bounded := true
		for candidate in players:
			var player := candidate as AudioStreamPlayer3D
			spatially_bounded = spatially_bounded and player.bus == &"Ambience" and player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and is_equal_approx(player.max_distance, float(spec.maximum)) and is_equal_approx(player.unit_size, float(spec.reference)) and player.max_distance > player.unit_size and player.max_distance <= 120.0 and is_equal_approx(player.panning_strength, 1.0) and player.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED and not player.emission_angle_enabled and player.max_polyphony == 1 and player.area_mask == 0
		_check(spatially_bounded, "%s routes both voices through exact bounded inverse-distance spatial settings" % emitter_id)
		var fingerprints := synthesis.fingerprints_sha256 as Dictionary
		_check(int(synthesis.sample_rate) == 16000 and int(synthesis.channel_count) == 1 and synthesis.sample_format == &"signed_pcm_16_bit" and str(fingerprints.get(&"loop", "")).length() == 64 and str(fingerprints.get(&"servo", "")).length() == 64 and str(fingerprints.get(&"latch", "")).length() == 64, "%s retains deterministic 16 kHz mono PCM and complete fingerprints" % emitter_id)
		total_voices += int(performance.maximum_simultaneous_voices)
		total_bytes += int(performance.resident_sample_bytes)
		total_budget += int(performance.resident_byte_budget)
	_check(emitter_ids.size() == 4 and total_voices == 8 and total_bytes <= total_budget and total_budget == 524288, "four unique emitters stay inside the aggregate eight-voice / 512 KiB budget")


func _test_structural_contract(world: ShipyardWorld, dressings: Array[StationStructuralServiceDressing]) -> void:
	var total_nodes := 0
	var total_meshes := 0
	var total_lights := 0
	for dressing in dressings:
		var audit := dressing.get_audit_report()
		var integration := audit.integration as Dictionary
		var performance := audit.performance as Dictionary
		var counts := performance.counts as Dictionary
		_check(bool(audit.valid) and bool(performance.static_component) and not bool(performance.process_enabled) and not bool(performance.physics_process_enabled), "%s is audited static presentation with no per-frame callbacks" % dressing.name)
		_check(integration.collision_policy == &"presentation_only_collision_free" and not bool(integration.widens_walkable_surface) and not bool(integration.fills_station_void) and is_zero_approx(float(integration.maximum_attachment_surface_penetration)), "%s cannot widen decks, fill voids, or penetrate its attachment surface" % dressing.name)
		var local_footprint := integration.local_footprint as AABB
		_check(local_footprint.position.z >= -0.001 and local_footprint.size.x > 0 and local_footprint.size.y > 0 and local_footprint.size.z > 0, "%s publishes a finite outward-only planar footprint" % dressing.name)
		total_nodes += int(counts.node_count)
		total_meshes += int(counts.mesh_instances)
		total_lights += int(counts.visible_lights)
	_check(total_nodes <= 224 and total_meshes == 164 and total_lights == 4, "four dressings remain within 224 nodes / 164 meshes / four bounded lights")
	world.apply_visual_quality(0)
	var low_forwarded := true
	for dressing in dressings:
		low_forwarded = low_forwarded and dressing.get_quality_level() == StationStructuralServiceDressing.DetailQuality.LOW and int((dressing.get_performance_audit().counts as Dictionary).visible_primitives) == 16
	_check(low_forwarded, "world Low quality forwards to all dressings without geometry rebuild")
	world.apply_visual_quality(2)
	var high_forwarded := true
	for dressing in dressings:
		high_forwarded = high_forwarded and dressing.get_quality_level() == StationStructuralServiceDressing.DetailQuality.HIGH and int((dressing.get_performance_audit().counts as Dictionary).visible_primitives) == 41
	_check(high_forwarded, "world High quality restores all prebuilt structural detail")


func _test_world_lifecycle(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience],
	dressings: Array[StationStructuralServiceDressing]
) -> void:
	var activity_times := {}
	var generations := {}
	for index in activities.size():
		activities[index].set_activity_time(2.0 + float(index))
		activities[index].set_activity_paused(false)
		activity_times[activities[index]] = activities[index].get_activity_time()
	for ambience in ambience_nodes:
		generations[ambience] = int(ambience.get_synthesis_report().generation_count)
	var collision_root := world.get_node(^"OperationalLattice/ActivityCollision") as Node3D
	var central_solids := collision_root.get_node(^"CentralTowServiceActivitySolids") as StaticBody3D
	world.set_station_activity_enabled(false)
	world.set_station_activity_enabled(false)
	await physics_frame
	var all_disabled := not world.is_station_activity_enabled() and not world.get_jovian_freight_berth().is_equipment_animation_enabled()
	for activity in activities:
		all_disabled = all_disabled and not activity.is_activity_enabled() and not activity.is_processing() and not bool(activity.get_activity_state().visible) and is_equal_approx(activity.get_activity_time(), float(activity_times[activity]))
	for ambience in ambience_nodes:
		all_disabled = all_disabled and not ambience.is_ambience_enabled() and _players_stopped_and_detached(ambience)
	for dressing in dressings:
		all_disabled = all_disabled and dressing.is_dressing_enabled()
	var disabled_collision := world.get_station_activity_collision_audit_report()
	_check(
		all_disabled and bool(disabled_collision.valid)
		and int(disabled_collision.active_body_count) == 0,
		"world disable is idempotent, stops movers/audio and all seven sibling solid bodies, preserves clocks, and leaves static silhouette visible"
	)
	_check(
		not (await _physics_query_finds_body(world, central_solids)),
		"global disable removes an exact activity body from World physics"
	)
	world.set_station_activity_enabled(true)
	world.set_station_activity_enabled(true)
	await physics_frame
	var all_enabled := world.is_station_activity_enabled() and world.get_jovian_freight_berth().is_equipment_animation_enabled()
	for activity in activities:
		all_enabled = all_enabled and activity.is_activity_enabled() and activity.is_processing()
	for ambience in ambience_nodes:
		all_enabled = all_enabled and ambience.is_ambience_enabled() and int(ambience.get_synthesis_report().generation_count) == int(generations[ambience])
	var enabled_collision := world.get_station_activity_collision_audit_report()
	_check(
		all_enabled and bool(enabled_collision.valid)
		and int(enabled_collision.active_body_count) == 7,
		"world re-enable is idempotent and resumes activity/audio plus all seven solid bodies without resynthesis churn"
	)
	_check(
		await _physics_query_finds_body(world, central_solids),
		"global re-enable restores the exact activity body to World physics"
	)
	for activity in activities:
		activity.set_activity_paused(true)
	await process_frame


func _test_freed_emitter_callback_safety() -> void:
	# Isolate this destructive callback probe from the main world's 4/4/4 roster.
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await physics_frame
	var ambience_nodes := world.get_station_machinery_ambience_nodes()
	var target: StationMachineryAmbience
	for ambience in ambience_nodes:
		if ambience.get_emitter_id() == &"aft-operations-service-wall":
			target = ambience
			break
	_check(target != null, "freed-emitter callback probe resolves Aft ambience")
	if target == null:
		return
	var target_reference: WeakRef = weakref(target)
	target.queue_free()
	target = null
	ambience_nodes.clear()
	await process_frame
	await process_frame
	_check(target_reference.get_ref() == null, "Aft ambience emitter frees without being retained by door callbacks")
	var door := (world.get_node("AftJunctionStack") as AftJunctionStack).get_operations_entrance()
	var accepted := door.interact(world)
	await process_frame
	_check(accepted and is_instance_valid(door), "door state callback safely ignores a freed positional emitter")
	world.queue_free()
	world = null
	await process_frame
	await physics_frame
	await process_frame


func _test_world_audit_detects_placement_mutation(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	dressings: Array[StationStructuralServiceDressing]
) -> void:
	var activity := activities[0]
	var activity_transform := activity.global_transform
	activity.global_position += Vector3(100, 0, 0)
	var moved_activity_report := world.get_operational_lattice_audit_report()
	_check(not bool(moved_activity_report.valid) and _errors_contain(moved_activity_report.errors, "diverged from its audited placement/profile/seed"), "world audit fails red when an activity placement drifts")
	activity.global_transform = activity_transform
	var dressing := dressings[0]
	var dressing_transform := dressing.global_transform
	dressing.global_position += Vector3(100, 0, 0)
	var moved_dressing_report := world.get_operational_lattice_audit_report()
	_check(not bool(moved_dressing_report.valid) and _errors_contain(moved_dressing_report.errors, "diverged from its audited placement/profile/length"), "world audit fails red when a structural mount drifts")
	dressing.global_transform = dressing_transform
	_check(bool(world.get_operational_lattice_audit_report().valid), "restoring adversarial placement mutations restores the valid integrated audit")


func _test_world_audit_detects_roster_and_configuration_mutation(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience],
	dressings: Array[StationStructuralServiceDressing]
) -> void:
	var central_activity: StationOperationsActivity
	var freight_activity: StationOperationsActivity
	for activity in activities:
		if activity.name == "CentralTowServiceActivity":
			central_activity = activity
		elif activity.name == "FreightApproachGantry":
			freight_activity = activity
	_check(central_activity != null and freight_activity != null, "roster mutation probe resolves Central and Freight activity roots")
	if central_activity != null and freight_activity != null:
		var freight_name := freight_activity.name
		freight_activity.name = central_activity.name
		var duplicate_activity_report := world.get_operational_lattice_audit_report()
		_check(not bool(duplicate_activity_report.valid) and (_errors_contain(duplicate_activity_report.errors, "duplicate station activity name") or _errors_contain(duplicate_activity_report.errors, "exact production name") or _errors_contain(duplicate_activity_report.errors, "unknown station activity placement")), "world audit fails red when a duplicate activity replaces one exact production role instead of hiding the roster loss")
		freight_activity.name = freight_name

	var central_dressing: StationStructuralServiceDressing
	for dressing in dressings:
		if dressing.name == "CentralBerthOuterFascia":
			central_dressing = dressing
			break
	_check(central_dressing != null, "configuration mutation probe resolves Central structural dressing")
	if central_dressing != null:
		var original_orientation := central_dressing.segment_orientation
		central_dressing.segment_orientation = StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y
		var mutated_dressing_report := world.get_operational_lattice_audit_report()
		_check(not bool(mutated_dressing_report.valid) and _errors_contain(mutated_dressing_report.errors, "failed its component audit"), "world audit fails red when live structural exports diverge from immutable built geometry")
		central_dressing.segment_orientation = original_orientation

	var central_ambience: StationMachineryAmbience
	for ambience in ambience_nodes:
		if ambience.get_emitter_id() == &"central-berth-utilities":
			central_ambience = ambience
			break
	_check(central_ambience != null, "configuration mutation probe resolves Central machinery ambience")
	if central_ambience != null:
		var original_seed := central_ambience.synthesis_seed
		central_ambience.synthesis_seed = original_seed + 17
		var mutated_audio_report := world.get_operational_lattice_audit_report()
		_check(not bool(mutated_audio_report.valid) and _errors_contain(mutated_audio_report.errors, "failed its component audit"), "world audit fails red when live audio exports diverge from resident synthesis")
		central_ambience.synthesis_seed = original_seed
	_check(bool(world.get_operational_lattice_audit_report().valid), "restoring roster and configuration mutations restores the valid integrated audit")


func _test_world_audit_detects_live_hierarchy_drift(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience],
	dressings: Array[StationStructuralServiceDressing]
) -> void:
	var activity := activities[0]
	var activity_parent := activity.get_parent()
	activity_parent.remove_child(activity)
	var detached_activity_report := world.get_operational_lattice_audit_report()
	_check(
		not bool(detached_activity_report.valid)
		and _errors_contain(detached_activity_report.errors, "activity registry does not match the live world hierarchy"),
		"world audit fails red while a cached activity is detached from the live hierarchy"
	)
	activity_parent.add_child(activity)
	await process_frame
	activity.set_activity_paused(true)
	_check(bool(world.get_operational_lattice_audit_report().valid), "re-adding the same activity restores live-registry equality")

	var ambience := ambience_nodes[0]
	var ambience_parent := ambience.get_parent()
	ambience_parent.remove_child(ambience)
	var detached_ambience_report := world.get_operational_lattice_audit_report()
	_check(
		not bool(detached_ambience_report.valid)
		and _errors_contain(detached_ambience_report.errors, "ambience registry does not match the live world hierarchy"),
		"world audit fails red while a cached ambience emitter is detached from the live hierarchy"
	)
	ambience_parent.add_child(ambience)
	await process_frame
	await physics_frame
	_check(bool(world.get_operational_lattice_audit_report().valid), "re-adding the same ambience emitter restores resources and live-registry equality")

	var dressing := dressings[0]
	var dressing_parent := dressing.get_parent()
	dressing_parent.remove_child(dressing)
	var detached_dressing_report := world.get_operational_lattice_audit_report()
	_check(
		not bool(detached_dressing_report.valid)
		and _errors_contain(detached_dressing_report.errors, "structural dressing registry does not match the live world hierarchy"),
		"world audit fails red while a cached structural dressing is detached from the live hierarchy"
	)
	dressing_parent.add_child(dressing)
	await process_frame
	_check(bool(world.get_operational_lattice_audit_report().valid), "re-adding the same structural dressing restores live-registry equality")

	var rogue_activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	rogue_activity.name = "UnindexedActivityProbe"
	activity_parent.add_child(rogue_activity)
	await process_frame
	var added_activity_report := world.get_operational_lattice_audit_report()
	_check(
		not bool(added_activity_report.valid)
		and _errors_contain(added_activity_report.errors, "activity registry does not match the live world hierarchy"),
		"world audit fails red for an added live activity that was never indexed"
	)
	rogue_activity.queue_free()
	await process_frame

	var rogue_ambience := AMBIENCE_SCENE.instantiate() as StationMachineryAmbience
	rogue_ambience.name = "UnindexedAmbienceProbe"
	ambience_parent.add_child(rogue_ambience)
	await process_frame
	var added_ambience_report := world.get_operational_lattice_audit_report()
	_check(
		not bool(added_ambience_report.valid)
		and _errors_contain(added_ambience_report.errors, "ambience registry does not match the live world hierarchy"),
		"world audit fails red for an added live ambience emitter that was never indexed"
	)
	rogue_ambience.queue_free()
	await process_frame

	var rogue_dressing := DRESSING_SCENE.instantiate() as StationStructuralServiceDressing
	rogue_dressing.name = "UnindexedDressingProbe"
	dressing_parent.add_child(rogue_dressing)
	await process_frame
	var added_dressing_report := world.get_operational_lattice_audit_report()
	_check(
		not bool(added_dressing_report.valid)
		and _errors_contain(added_dressing_report.errors, "structural dressing registry does not match the live world hierarchy"),
		"world audit fails red for an added live structural dressing that was never indexed"
	)
	rogue_dressing.queue_free()
	await process_frame
	_check(bool(world.get_operational_lattice_audit_report().valid), "removing all unindexed hierarchy probes restores the exact valid world audit")


func _test_child_detach_readd_lifecycle(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience]
) -> void:
	var activity := activities[0]
	activity.set_activity_enabled(true)
	activity.set_activity_paused(false)
	var collision_root := world.get_node(^"OperationalLattice/ActivityCollision") as Node3D
	var solid_body := collision_root.get_node(
		NodePath("%sSolids" % activity.name)
	) as StaticBody3D
	var solid_body_id := solid_body.get_instance_id()
	var original_transform := activity.transform
	var original_body_point := _first_shape_world_center(solid_body)
	_check(
		await _physics_query_finds_body(world, solid_body),
		"independent activity lifecycle starts with its exact sibling body in physics"
	)
	var activity_parent := activity.get_parent()
	activity_parent.remove_child(activity)
	await process_frame
	await physics_frame
	_check(
		solid_body.collision_layer == PhysicsLayers.NONE
		and not (await _physics_query_finds_body(world, solid_body)),
		"independently detached activity leaves its surviving sibling body disabled and absent from physics"
	)
	var detached_moved := Transform3D(
		Basis(Vector3.UP, deg_to_rad(13.0)) * original_transform.basis,
		original_transform.origin + Vector3(9.0, 0.0, 4.0)
	)
	activity.transform = detached_moved
	await process_frame
	await physics_frame
	_check(
		solid_body.get_instance_id() == solid_body_id
		and solid_body.collision_layer == PhysicsLayers.NONE
		and not (await _physics_query_finds_body(world, solid_body)),
		"moving an independently detached source cannot publish or replace its surviving sibling body"
	)
	activity_parent.add_child(activity)
	await process_frame
	await physics_frame
	_check(
		activity.is_activity_enabled() and activity.is_activity_advancing()
		and activity.is_processing() and bool(activity.get_audit_report().valid)
		and solid_body.get_instance_id() == solid_body_id
		and solid_body.collision_layer == WORLD_LAYER
		and solid_body.global_transform.is_equal_approx(activity.global_transform)
		and not (await _physics_query_finds_body_at(world, solid_body, original_body_point))
		and await _physics_query_finds_body(world, solid_body),
		"independently detached moved activity restores the same exact sibling body at its new pose and clears the old point"
	)

	# Enabled movement follows immediately, then disabled movement proves pose and
	# layer are independent lifecycle dimensions. Rotation is included so the
	# test cannot pass on origin-only synchronisation.
	var enabled_moved := Transform3D(
		Basis(Vector3.UP, deg_to_rad(7.0)) * original_transform.basis,
		original_transform.origin + Vector3(0.0, 0.0, 2.0)
	)
	var enabled_old_body_point := _first_shape_world_center(solid_body)
	activity.transform = enabled_moved
	await process_frame
	await physics_frame
	_check(
		solid_body.global_transform.is_equal_approx(activity.global_transform)
		and not (await _physics_query_finds_body_at(world, solid_body, enabled_old_body_point))
		and await _physics_query_finds_body(world, solid_body),
		"enabled activity translation/rotation moves the exact sibling physics body old-to-new"
	)
	activity.set_activity_enabled(false)
	var disabled_moved := Transform3D(
		Basis(Vector3.UP, deg_to_rad(-11.0)) * original_transform.basis,
		original_transform.origin + Vector3(0.0, 0.0, 2.5)
	)
	activity.transform = disabled_moved
	await process_frame
	await physics_frame
	var disabled_collision := world.get_station_activity_collision_audit_report()
	_check(
		solid_body.get_instance_id() == solid_body_id
		and solid_body.collision_layer == PhysicsLayers.NONE
		and solid_body.global_transform.is_equal_approx(activity.global_transform)
		and bool(disabled_collision.valid)
		and not (await _physics_query_finds_body(world, solid_body)),
		"disabled activity movement keeps the same body pose-synchronised, audited, and absent from physics"
	)
	activity.set_activity_enabled(true)
	await physics_frame
	_check(
		solid_body.get_instance_id() == solid_body_id
		and solid_body.collision_layer == WORLD_LAYER
		and await _physics_query_finds_body(world, solid_body),
		"re-enabling a moved activity restores the same body at its new exact pose"
	)
	activity.transform = original_transform
	await process_frame
	await physics_frame

	# A live node in another owner must not retain authority over this world's
	# surviving sibling body. Restore it to the canonical Activities container and
	# require that the same instance, rather than a replacement, becomes physical.
	var foreign_root := Node3D.new()
	foreign_root.name = "ForeignActivityOwnerProbe"
	root.add_child(foreign_root)
	activity_parent.remove_child(activity)
	foreign_root.add_child(activity)
	activity.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-17.0)) * original_transform.basis,
		original_transform.origin + Vector3(-7.0, 0.0, 6.0)
	)
	await process_frame
	await physics_frame
	_check(
		activity.is_inside_tree()
		and solid_body.get_instance_id() == solid_body_id
		and solid_body.collision_layer == PhysicsLayers.NONE
		and not (await _physics_query_finds_body(world, solid_body)),
		"reparenting a declaring activity into another live owner leaves the old world's sibling body fail-closed"
	)
	foreign_root.remove_child(activity)
	activity_parent.add_child(activity)
	await process_frame
	await physics_frame
	_check(
		solid_body.get_instance_id() == solid_body_id
		and solid_body.collision_layer == WORLD_LAYER
		and solid_body.global_transform.is_equal_approx(activity.global_transform)
		and await _physics_query_finds_body(world, solid_body),
		"returning the declaring activity to its canonical owner reuses and resynchronises the exact sibling body"
	)
	activity.transform = original_transform
	await process_frame
	await physics_frame
	foreign_root.queue_free()
	await process_frame
	activity.set_activity_paused(true)

	var ambience := ambience_nodes[0]
	ambience.set_ambience_enabled(true)
	var ambience_parent := ambience.get_parent()
	ambience_parent.remove_child(ambience)
	await process_frame
	ambience_parent.add_child(ambience)
	await process_frame
	await physics_frame
	var synthesis := ambience.get_synthesis_report()
	_check(ambience.is_ambience_enabled() and bool(synthesis.resources_ready) and int(synthesis.resident_sample_bytes) > 0 and bool(ambience.get_audit_report().valid), "independently detached ambience preserves desired state and restores deterministic resources")
	world.call("_index_operational_lattice_components")
	world.call("_connect_operational_lattice_audio")
	_check(bool(world.get_operational_lattice_audit_report().valid), "world reindex after independent child lifecycle restores exact registry and live door hooks")


func _test_replaced_emitter_hook_rebinding() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await physics_frame
	var original: StationMachineryAmbience
	for ambience in world.get_station_machinery_ambience_nodes():
		if ambience.get_emitter_id() == &"aft-operations-service-wall":
			original = ambience
			break
	_check(original != null, "emitter replacement probe resolves original Aft ambience")
	if original == null:
		world.queue_free()
		return
	var parent := original.get_parent()
	var original_name := original.name
	var original_position := original.position
	var original_seed := original.synthesis_seed
	var original_frequency := original.base_frequency_hz
	var original_maximum := original.maximum_distance
	var original_reference := original.reference_distance
	parent.remove_child(original)
	original.queue_free()
	await process_frame
	var replacement := preload("res://scenes/audio/station_machinery_ambience.tscn").instantiate() as StationMachineryAmbience
	replacement.name = original_name
	replacement.position = original_position
	replacement.emitter_id = &"aft-operations-service-wall"
	replacement.synthesis_seed = original_seed
	replacement.base_frequency_hz = original_frequency
	replacement.maximum_distance = original_maximum
	replacement.reference_distance = original_reference
	parent.add_child(replacement)
	await process_frame
	world.call("_index_operational_lattice_components")
	world.call("_connect_operational_lattice_audio")
	var report := world.get_operational_lattice_audit_report()
	_check(bool(report.valid) and int((report.lifecycle as Dictionary).door_audio_hook_count) == 3, "replacing an ambience emitter reconnects all three door hooks to the current live roster")
	var door := (world.get_node("AftJunctionStack") as AftJunctionStack).get_operations_entrance()
	_check(door.interact(world), "door remains operable after ambience replacement and stale-hook cleanup")
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await physics_frame
	await process_frame


func _test_detach_readd_lifecycle(game: Node, world: ShipyardWorld) -> void:
	world.set_station_activity_enabled(true)
	for activity in world.get_station_operations_activities():
		activity.set_activity_paused(false)
	var collision_root := world.get_node(^"OperationalLattice/ActivityCollision") as Node3D
	var central_activity := world.get_node(
		^"OperationalLattice/Activities/CentralTowServiceActivity"
	) as StationOperationsActivity
	var central_solids := collision_root.get_node(
		^"CentralTowServiceActivitySolids"
	) as StaticBody3D
	var central_body_id := central_solids.get_instance_id()
	var original_central_transform := central_activity.transform
	var collision_body_ids := PackedInt64Array()
	for candidate in collision_root.find_children("*", "StaticBody3D", false, false):
		collision_body_ids.append((candidate as StaticBody3D).get_instance_id())
	collision_body_ids.sort()
	var original_world_transform := world.transform
	var original_parent := world.get_parent()
	original_parent.remove_child(world)
	await process_frame
	_check(
		not world.is_inside_tree() and central_solids.collision_layer == PhysicsLayers.NONE,
		"built world detaches cleanly and its surviving activity solids are disabled before streaming"
	)
	world.transform = Transform3D(
		original_world_transform.basis,
		original_world_transform.origin + Vector3(3.0, 0.0, 1.5)
	)
	original_parent.add_child(world)
	# Descendant `_enter_tree` signals run before the sibling collision root is
	# live. They must leave every body NONE until the world's deferred restore has
	# a complete hierarchy and can publish one authoritative resync.
	_check(
		central_solids.collision_layer == PhysicsLayers.NONE,
		"whole-world re-entry exposes no stale old-pose activity collider before deferred resynchronisation"
	)
	await process_frame
	await process_frame
	await physics_frame
	var activities := world.get_station_operations_activities()
	var ambience_nodes := world.get_station_machinery_ambience_nodes()
	var restored := world.is_station_activity_enabled() and activities.size() == 10 and ambience_nodes.size() == 4
	for activity in activities:
		restored = restored and activity.is_activity_enabled() and activity.is_processing()
	for ambience in ambience_nodes:
		var synthesis := ambience.get_synthesis_report()
		restored = restored and ambience.is_ambience_enabled() and bool(synthesis.resources_ready) and int(synthesis.resident_sample_bytes) > 0
	var restored_collision := world.get_station_activity_collision_audit_report()
	var restored_body_ids := PackedInt64Array()
	for candidate in collision_root.find_children("*", "StaticBody3D", false, false):
		restored_body_ids.append((candidate as StaticBody3D).get_instance_id())
	restored_body_ids.sort()
	_check(
		restored and bool(restored_collision.valid)
		and int(restored_collision.active_body_count) == 7
		and restored_body_ids == collision_body_ids
		and central_solids.global_transform.is_equal_approx(central_activity.global_transform)
		and await _physics_query_finds_body(world, central_solids),
		"moved whole-world re-entry restores all processing plus the same seven bodies at their new exact poses"
	)
	_check(world.get_parent() == game, "re-added ShipyardWorld returns to its production parent")
	world.transform = original_world_transform
	await process_frame
	await physics_frame
	_check(
		central_solids.global_transform.is_equal_approx(central_activity.global_transform)
		and bool(world.get_operational_lattice_audit_report().valid),
		"restoring the streamed world pose restores the complete frozen placement audit"
	)

	# Desired global disablement must compose with streaming. Move a declaring
	# source relative to its sibling collision root while the whole world is out
	# of tree, then require re-entry to resynchronise the same body without ever
	# publishing it to physics.
	world.set_station_activity_enabled(false)
	await process_frame
	await physics_frame
	original_parent.remove_child(world)
	central_activity.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(9.0)) * original_central_transform.basis,
		original_central_transform.origin + Vector3(4.0, 0.0, -3.0)
	)
	original_parent.add_child(world)
	_check(
		central_solids.collision_layer == PhysicsLayers.NONE,
		"globally disabled whole-world re-entry exposes no activity collider before deferred resynchronisation"
	)
	await process_frame
	await process_frame
	await physics_frame
	var disabled_reentry := world.get_station_activity_collision_audit_report()
	_check(
		not world.is_station_activity_enabled()
		and bool(disabled_reentry.valid)
		and int(disabled_reentry.active_body_count) == 0
		and central_solids.get_instance_id() == central_body_id
		and central_solids.collision_layer == PhysicsLayers.NONE
		and central_solids.global_transform.is_equal_approx(central_activity.global_transform)
		and not (await _physics_query_finds_body(world, central_solids)),
		"globally disabled detach/move/re-entry keeps all seven resynchronised activity bodies out of physics"
	)
	world.set_station_activity_enabled(true)
	await process_frame
	await physics_frame
	var enabled_reentry := world.get_station_activity_collision_audit_report()
	_check(
		bool(enabled_reentry.valid)
		and int(enabled_reentry.active_body_count) == 7
		and central_solids.collision_layer == WORLD_LAYER
		and await _physics_query_finds_body(world, central_solids),
		"re-enabling after disabled streaming restores all seven exact activity bodies"
	)
	central_activity.transform = original_central_transform
	await process_frame
	await physics_frame
	_check(
		bool(world.get_operational_lattice_audit_report().valid),
		"disabled streaming probe restores the frozen operational placement audit"
	)


func _activity_states_match(first: Dictionary, second: Dictionary) -> bool:
	if absf(float(first.elapsed) - float(second.elapsed)) > MOTION_EPSILON:
		return false
	if first.activity_profile != second.activity_profile or first.activity_profile_id != second.activity_profile_id:
		return false
	for key in ["gantry_carriage_position", "gantry_tool_position", "service_arm_shoulder_rotation", "service_arm_elbow_rotation"]:
		if not (first[key] as Vector3).is_equal_approx(second[key] as Vector3):
			if (first[key] as Vector3).distance_to(second[key] as Vector3) > MOTION_EPSILON:
				return false
	var first_drones := first.drones as Array
	var second_drones := second.drones as Array
	if first_drones.size() != second_drones.size():
		return false
	for index in first_drones.size():
		if ((first_drones[index] as Dictionary).position as Vector3).distance_to((second_drones[index] as Dictionary).position as Vector3) > MOTION_EPSILON:
			return false
		if ((first_drones[index] as Dictionary).rotation as Vector3).distance_to((second_drones[index] as Dictionary).rotation as Vector3) > MOTION_EPSILON:
			return false
	return first.beacon_pattern == second.beacon_pattern


func _all_mesh_corners_inside(component: Node3D, world_envelope: AABB, margin: float) -> bool:
	var expanded := world_envelope.grow(margin)
	for candidate in component.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for corner_index in 8:
			var corner := bounds.position + Vector3(bounds.size.x if corner_index & 1 else 0, bounds.size.y if corner_index & 2 else 0, bounds.size.z if corner_index & 4 else 0)
			if not expanded.has_point(mesh_instance.to_global(corner)):
				return false
	return true


func _nodes_by_name(nodes: Array) -> Dictionary:
	var result := {}
	for node in nodes:
		if node is Node:
			result[StringName((node as Node).name)] = node
	return result


func _ambience_by_id(nodes: Array[StationMachineryAmbience]) -> Dictionary:
	var result := {}
	for ambience in nodes:
		result[ambience.get_emitter_id()] = ambience
	return result


func _node_sets_match(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for candidate in first:
		if not second.has(candidate):
			return false
	return true


func _subtree_nodes(root_node: Node) -> Array[Node]:
	var result: Array[Node] = [root_node]
	for candidate in root_node.find_children("*", "", true, false):
		result.append(candidate as Node)
	return result


func _subtree_has_forbidden_physics(root_node: Node) -> bool:
	for candidate in _subtree_nodes(root_node):
		if candidate is CollisionObject3D or candidate is CollisionShape3D or candidate is CollisionPolygon3D or candidate is RigidBody3D or candidate is AnimatableBody3D or candidate is CharacterBody3D or candidate is Area3D or candidate is AnimationPlayer:
			return true
	return false


func _static_dressing_types_allowed(dressing: StationStructuralServiceDressing) -> bool:
	for candidate in _subtree_nodes(dressing):
		if not (candidate is Node3D or candidate is Marker3D or candidate is MeshInstance3D or candidate is OmniLight3D):
			return false
		if candidate is Light3D and (candidate as Light3D).shadow_enabled:
			return false
	return not dressing.is_processing() and not dressing.is_physics_processing()


func _count_type(root_node: Node, type_name: String) -> int:
	return root_node.find_children("*", type_name, true, false).size() + (1 if root_node.is_class(type_name) else 0)


func _players_stopped_and_detached(ambience: StationMachineryAmbience) -> bool:
	for candidate in ambience.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		if player.playing or player.stream != null:
			return false
	return true


func _transformed_local_aabb(transform_value: Transform3D, local_min: Vector3, local_max: Vector3) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x_value in [local_min.x, local_max.x]:
		for y_value in [local_min.y, local_max.y]:
			for z_value in [local_min.z, local_max.z]:
				var point := transform_value * Vector3(x_value, y_value, z_value)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _aabbs_overlap(first: AABB, second: AABB, epsilon: float) -> bool:
	return minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x) > epsilon and minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y) > epsilon and minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z) > epsilon


func _aabb_separation(first: AABB, second: AABB) -> float:
	var dx := maxf(0.0, maxf(first.position.x - second.end.x, second.position.x - first.end.x))
	var dy := maxf(0.0, maxf(first.position.y - second.end.y, second.position.y - first.end.y))
	var dz := maxf(0.0, maxf(first.position.z - second.end.z, second.position.z - first.end.z))
	return Vector3(dx, dy, dz).length()


func _aabb_approx(first: AABB, second: AABB, epsilon: float = 0.015) -> bool:
	return first.position.distance_to(second.position) <= epsilon and first.size.distance_to(second.size) <= epsilon


func _static_body_world_aabb(body: StaticBody3D) -> AABB:
	if body == null:
		return AABB()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found := false
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.disabled or collision.shape == null:
			continue
		var extents := Vector3.ZERO
		if collision.shape is BoxShape3D:
			extents = (collision.shape as BoxShape3D).size * 0.5
		else:
			continue
		var bounds := _transformed_local_aabb(collision.global_transform, -extents, extents)
		minimum = minimum.min(bounds.position)
		maximum = maximum.max(bounds.end)
		found = true
	return AABB(minimum, maximum - minimum) if found else AABB()


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _ray_local(module: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	return await _ray(module, module.to_global(from), module.to_global(to))


func _intersect_shape(world: Node3D, shape: Shape3D, transform_value: Transform3D, max_results: int = 24) -> Array[Dictionary]:
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform_value
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_shape(query, max_results)


func _first_shape_world_center(body: StaticBody3D) -> Vector3:
	if body == null:
		return Vector3.INF
	for candidate in body.find_children("*", "CollisionShape3D", false, false):
		var collision := candidate as CollisionShape3D
		if collision.shape != null and not collision.disabled:
			return collision.global_position
	return Vector3.INF


func _physics_query_finds_body(world: Node3D, body: StaticBody3D) -> bool:
	return await _physics_query_finds_body_at(
		world, body, _first_shape_world_center(body)
	)


func _physics_query_finds_body_at(
		world: Node3D,
		body: StaticBody3D,
		point: Vector3
	) -> bool:
	if body == null or not point.is_finite():
		return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.04
	for hit in await _intersect_shape(
		world, sphere, Transform3D(Basis.IDENTITY, point), 64
	):
		if hit.get("collider") == body:
			return true
	return false


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus a fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for a door to reach `expected_state` on the physics clock, which is the
## clock `StationDoor` actually advances its panel on.
##
## The budget deliberately counts physics steps rather than wall-clock seconds. A
## `Time.get_ticks_msec()` deadline measures the monotonic clock, and under load
## Godot drops physics steps rather than letting the simulation spiral, so the
## wall clock reaches the deadline while the panel has been stepped only part of
## the way. The wait then returned silently and the caller probed a threshold that
## was still physically blocked — a false failure, not a defect. Counting frames
## gives the door the same amount of simulation however busy the box is, and still
## fails a genuinely stuck door because the budget remains finite.
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


func _errors_contain(errors: Variant, fragment: String) -> bool:
	for error in errors as PackedStringArray:
		if fragment in str(error):
			return true
	return false


func _capture_lifetime_references(
	world: ShipyardWorld,
	activities: Array[StationOperationsActivity],
	ambience_nodes: Array[StationMachineryAmbience],
	dressings: Array[StationStructuralServiceDressing]
) -> Array[WeakRef]:
	var references: Array[WeakRef] = [weakref(world)]
	var collision_root := world.get_node_or_null(
		^"OperationalLattice/ActivityCollision"
	) as Node3D
	if collision_root != null:
		references.append(weakref(collision_root))
		for body_candidate in collision_root.find_children(
			"*", "StaticBody3D", true, false
		):
			var body := body_candidate as StaticBody3D
			references.append(weakref(body))
			for shape_candidate in body.find_children(
				"*", "CollisionShape3D", true, false
			):
				references.append(weakref(shape_candidate))
	for activity in activities:
		references.append(weakref(activity))
		var mover := activity.find_child("Animated*", true, false)
		if mover != null:
			references.append(weakref(mover))
	for ambience in ambience_nodes:
		references.append(weakref(ambience))
		for player in ambience.find_children("*", "AudioStreamPlayer3D", true, false):
			references.append(weakref(player))
	for dressing in dressings:
		references.append(weakref(dressing))
	return references


func _all_released(references: Array[WeakRef]) -> bool:
	for reference in references:
		if reference.get_ref() != null:
			return false
	return true


func _cleanup(game: Node) -> void:
	for action in [&"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost"]:
		Input.action_release(action)
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_OPERATIONAL_LATTICE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_OPERATIONAL_LATTICE_TEST_FAILED: %d/%d assertions failed: %s" % [_failures.size(), _assertions, "; ".join(_failures)])
		quit(1)
