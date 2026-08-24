extends SceneTree

## Focused production contract for the hand-authored nearby sector cluster.
##
## The cluster is the first content the player can fly *to*, and the two things
## that can quietly ruin it are invisible to a node-existence check: geometry
## wound inside out, and a rock scattered into the lane the pilot is being told
## to fly down. Both are measured here against the real world scene, not a
## fixture. The production world starts without this streamed component, so the
## component-local fixture instantiates the same real PackedScene directly. So is
## the boundary the cluster must not cross — it grants nothing, adds no range
## targets, and never reaches back toward the station.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const BEACON_TRAVERSAL_ACTIVITY := preload(
	"res://scripts/world/cinder_beacon_traversal_activity.gd"
)
const ENGINE_CALIBRATION_MESHES := ["BoxMesh", "CylinderMesh", "SphereMesh"]
const EXPECTED_COMPONENT_ID: StringName = &"nearby-sector-cluster"
const EXPECTED_EVIDENCE_STATUS: StringName = &"modern_interpretation"
## Nothing the cluster builds may come nearer the station than this. The launch
## corridor, the landing approach and the whole target range live well inside it;
## the range's furthest drone is 165 m out.
const STATION_EXCLUSION_RADIUS := 200.0

## The cluster's placement contract, frozen here rather than read back off the
## component. Reading `NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS` to check
## the scatter against the keep-clear sphere measures nothing: shrinking the
## constant would move the rule and the ruler together and the suite would stay
## green while rocks filled the approach lane. These numbers are the contract, and
## `_test_frozen_contract` is what notices when the component walks away from it.
const EXPECTED_PLATFORM_ANCHOR := Vector3(60.0, -70.0, -700.0)
const EXPECTED_PLATFORM_KEEP_CLEAR := 105.0
const EXPECTED_LANE_RADIUS := 30.0
const EXPECTED_LANE_LENGTH := 200.0
const EXPECTED_LANE_CENTER_Y := 4.0
const EXPECTED_BEACON_COUNT := 4
const EXPECTED_BOULDER_COUNT := 16
const EXPECTED_DEBRIS_CHIP_COUNT := 520
const EXPECTED_GATE_WIDTH := 28.0
const EXPECTED_GATE_HEIGHT := 23.0
const EXPECTED_GATE_NEAR_Z := 95.0
const EXPECTED_GATE_FAR_Z := 77.0
const EXPECTED_MINING_ACTIVITY_ID: StringName = &"cinder_platform_mining_run"
const EXPECTED_MINING_APPROACH_ANCHOR := Vector3(60.0, -66.0, -605.0)
const EXPECTED_MINING_APPROACH_LOCAL := Vector3(0.0, 4.0, 95.0)
const EXPECTED_MINING_PRESENTATION_LOCAL_BOUNDS := AABB(
	Vector3(-50.0, -1.0, -13.0), Vector3(67.0, 55.0, 34.0)
)
const EXPECTED_MINING_PRESENTATION_MESH_NODES := 6
const EXPECTED_MINING_PRESENTATION_MULTIMESH_NODES := 6
const EXPECTED_MINING_PRESENTATION_RENDERER_NODES := 12
const EXPECTED_MINING_PRESENTATION_VISIBLE_COPIES := 22
const EXPECTED_MINING_PRESENTATION_SUBMISSIONS := 12
const EXPECTED_MINING_PRESENTATION_MESH_RESOURCES := 11
const EXPECTED_MINING_PRESENTATION_LIGHT_NODES := 2
const EXPECTED_MINING_PRESENTATION_DESCENDANTS := 15
const EXPECTED_STRUCTURE_SCAN_ACTIVITY_ID: StringName = &"cinder_derelict_structure_scan"
const EXPECTED_STRUCTURE_SCAN_APPROACH_ANCHOR := Vector3(60.0, -66.0, -680.0)
const EXPECTED_STRUCTURE_SCAN_APPROACH_LOCAL := Vector3(0.0, 4.0, 20.0)
const EXPECTED_STRUCTURE_SCAN_PRESENTATION_LOCAL_BOUNDS := AABB(
	Vector3(-30.0, -4.0, -24.0), Vector3(82.0, 60.0, 40.0)
)
const EXPECTED_STRUCTURE_SCAN_MESH_NODES := 13
const EXPECTED_STRUCTURE_SCAN_LIGHT_NODES := 2
const EXPECTED_STRUCTURE_SCAN_DESCENDANTS := 16
const EXPECTED_BEACON_TRAVERSAL_ACTIVITY_ID: StringName = &"cinder_debris_beacon_traversal"
const EXPECTED_BEACON_TRAVERSAL_CORRIDOR_RADIUS := 42.0
const EXPECTED_TRAVERSAL_DEBRIS_CLUSTERS := 8
const EXPECTED_TRAVERSAL_DEBRIS_COPIES := 520
const EXPECTED_TRAVERSAL_BEACON_MESHES := 44
const EXPECTED_TRAVERSAL_BEACON_LIGHTS := 12
const EXPECTED_TRAVERSAL_BEACON_DESCENDANTS := 60
const EXPECTED_TRAVERSAL_DEBRIS_BOUNDS := AABB(
	Vector3(-84.0, -82.0, -596.0), Vector3(224.0, 102.0, 385.0)
)
const EXPECTED_SPINE_RIB_AABB := AABB(
	Vector3(-6.5, -4.75, -0.8), Vector3(13.0, 9.5, 1.6)
)
const EXPECTED_SPINE_RIB_BATCH_AABB := AABB(
	Vector3(-6.5, -4.75, -24.8), Vector3(13.0, 9.5, 37.6)
)
const EXPECTED_SPINE_RIB_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -24.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -14.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 12.0)),
]
const EXPECTED_SPINE_RIB_FAMILY_ID: StringName = &"nearby-processing-spine-ribs"
const EXPECTED_ARM_COLLAR_AABB := AABB(Vector3(-3.0, -0.7, -3.0), Vector3(6.0, 1.4, 6.0))
const EXPECTED_ARM_COLLAR_BATCH_AABB := AABB(Vector3(-3.0, -28.7, -3.0), Vector3(6.0, 23.4, 6.0))
const EXPECTED_ARM_COLLAR_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(0.0, -6.0, 0.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, -17.0, 0.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, -28.0, 0.0)),
]
const EXPECTED_ARM_COLLAR_ARM_SPECS: Array[Dictionary] = [
	{
		"name": &"ExtractionArmPort",
		"position": Vector3(-12.0, -8.0, -6.0),
		"rotation_degrees": Vector3(-36.0, 0.0, -14.0),
	},
	{
		"name": &"ExtractionArmStarboard",
		"position": Vector3(12.0, -8.0, -6.0),
		"rotation_degrees": Vector3(-36.0, 0.0, 14.0),
	},
]
const EXPECTED_ARM_COLLAR_FAMILY_ID: StringName = &"cinder-extraction-arm-collars"
const EXPECTED_GANTRY_RAIL_AABB := AABB(Vector3(-0.6, -0.6, -9.0), Vector3(1.2, 1.2, 18.0))
const EXPECTED_GANTRY_RAIL_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-15.5, -9.0, 86.0)),
	Transform3D(Basis.IDENTITY, Vector3(-15.5, 17.0, 86.0)),
	Transform3D(Basis.IDENTITY, Vector3(15.5, -9.0, 86.0)),
	Transform3D(Basis.IDENTITY, Vector3(15.5, 17.0, 86.0)),
]
const EXPECTED_GANTRY_RAIL_FAMILY_ID: StringName = &"nearby-gantry-rails"
const EXPECTED_LOCAL_MESH_NODES := 198
const EXPECTED_LOCAL_MULTIMESH_NODES := 17
const EXPECTED_LOCAL_RENDERER_NODES := 215
const EXPECTED_LOCAL_VISIBLE_COPIES := 766
const EXPECTED_LOCAL_SURFACE_SUBMISSIONS := 215
const EXPECTED_LOCAL_TRIANGLES := 126978
const EXPECTED_LOCAL_STATIC_BODIES := 61
const EXPECTED_LOCAL_COLLISION_SHAPES := 62
const EXPECTED_LAMP_LENS_COPY_COUNT := 26
const EXPECTED_LAMP_LENS_RADIUS := 0.45
const EXPECTED_LAMP_LENS_HEIGHT := 0.9
const EXPECTED_LAMP_LENS_RADIAL_SEGMENTS := 12
const EXPECTED_LAMP_LENS_RINGS := 6
const EXPECTED_TORUS_COPY_COUNT := 19
const EXPECTED_TORUS_MESH_RESOURCE_ALLOCATIONS := 12
const EXPECTED_TORUS_RINGS := 40
const EXPECTED_TORUS_RING_SEGMENTS := 14
## The furthest the whole cluster may sit from the station and still be somewhere
## a pilot chooses to go rather than commits an evening to.
const MAXIMUM_TRAVEL_DISTANCE := 760.0

var EXPECTED_MINING_ORE_LIFT_TRANSFORMS: Array[Transform3D] = [
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(23.749494)))
			* Basis.from_scale(Vector3(3.6, 54.626, 4.0)),
		Vector3(-14.0, 27.0, -6.0)
	),
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(26.565052)))
			* Basis.from_scale(Vector3(3.6, 46.957, 4.0)),
		Vector3(-7.5, 23.0, -6.0)
	),
	Transform3D(Basis.from_scale(Vector3(38.0, 3.6, 4.0)), Vector3(-29.0, 50.0, -6.0)),
	Transform3D(Basis.from_scale(Vector3(3.6, 28.0, 4.0)), Vector3(-45.0, 36.0, -6.0)),
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	var twin_cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	_check(
		world != null and cluster != null and twin_cluster != null,
		"the station world and two real nearby-sector component fixtures instantiate"
	)
	if world == null or cluster == null or twin_cluster == null:
		_finish()
		return
	root.add_child(world)
	root.add_child(cluster)
	root.add_child(twin_cluster)
	await process_frame

	_check(
		world.get_nearby_sector_cluster() == null
		and world.get_nearby_sector_cluster_audit_report().get("reason")
			== &"streamed_cluster_unavailable",
		"the production station owns no static Cinder child and reports streamed absence honestly"
	)

	_test_frozen_contract()
	_test_identity_and_authority(world, cluster)
	_test_mining_platform_activity_presentation(cluster)
	_test_structure_scan_activity_presentation(cluster)
	_test_beacon_traversal_presentation(cluster)
	_test_scorched_bay_seam_overlap(cluster)
	_test_processing_spine_rib_batch(cluster)
	_test_extraction_arm_collar_batches(cluster)
	_test_gantry_rail_batch(cluster)
	_test_lamp_lens_mesh_sharing(cluster)
	_test_torus_mesh_sharing(cluster)
	_test_placement_envelope(cluster)
	_test_placement_predicate_rejects_the_lane(cluster)
	_test_winding(cluster)
	_test_collision_boundary(cluster)
	_test_determinism(cluster, twin_cluster)
	await _test_lifecycle(world, cluster)

	# This fixture instantiates the entire station only to verify the range-target
	# boundary. Its fleet expansion builds three caller-owned audio bindings, so
	# release them through their public lifecycle before freeing the fixture.
	var fleet_expansion := world.get_fleet_expansion_production_binding()
	var fleet_fixture_released := fleet_expansion != null
	if fleet_expansion != null:
		for craft_id: StringName in [
			&"cinder_cargo_hauler",
			&"cinder_long_range_bomber",
			&"cinder_light_interceptor",
		]:
			var released := fleet_expansion.detach_craft(craft_id) as Dictionary
			fleet_fixture_released = fleet_fixture_released \
				and bool(released.get("accepted", false))
	_check(
		fleet_fixture_released,
		"the full-world fixture releases its three caller-owned fleet audio bindings"
	)
	twin_cluster.queue_free()
	cluster.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	_finish()


## The published placement rule, held to the numbers this suite measures against.
## Every later scan uses the constants above, so this is the single place a
## deliberate design change has to be declared.
func _test_frozen_contract() -> void:
	_check(
		NearbySectorCluster.PLATFORM_ANCHOR.is_equal_approx(EXPECTED_PLATFORM_ANCHOR),
		"the platform anchor is still the published (60, -70, -700)"
	)
	_check(
		is_equal_approx(NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS, EXPECTED_PLATFORM_KEEP_CLEAR)
		and is_equal_approx(NearbySectorCluster.APPROACH_CORRIDOR_RADIUS, EXPECTED_LANE_RADIUS)
		and is_equal_approx(NearbySectorCluster.APPROACH_CORRIDOR_LENGTH, EXPECTED_LANE_LENGTH)
		and is_equal_approx(NearbySectorCluster.GANTRY_CENTER_Y, EXPECTED_LANE_CENTER_Y),
		"the keep-clear sphere and the approach lane keep their published dimensions"
	)
	_check(
		NearbySectorCluster.ROUTE_BEACON_SPECS.size() == EXPECTED_BEACON_COUNT
		and NearbySectorCluster.BOULDER_COUNT == EXPECTED_BOULDER_COUNT
		and NearbySectorCluster.DEBRIS_CHIP_COUNT == EXPECTED_DEBRIS_CHIP_COUNT,
		"the hand-placed roster is still four beacons, sixteen boulders and one debris shell"
	)
	_check(
		is_equal_approx(NearbySectorCluster.GANTRY_CLEAR_WIDTH, EXPECTED_GATE_WIDTH)
		and is_equal_approx(NearbySectorCluster.GANTRY_CLEAR_HEIGHT, EXPECTED_GATE_HEIGHT)
		and is_equal_approx(NearbySectorCluster.GANTRY_NEAR_Z, EXPECTED_GATE_NEAR_Z)
		and is_equal_approx(NearbySectorCluster.GANTRY_FAR_Z, EXPECTED_GATE_FAR_Z),
		"the dock gate keeps its published aperture and its standoff from the platform"
	)


# --- Identity, evidence and authority ----------------------------------------


func _test_identity_and_authority(world: ShipyardWorld, cluster: NearbySectorCluster) -> void:
	var report := cluster.get_cluster_audit_report()
	_check(
		int(report.get("schema_version", 0)) == 1
		and StringName(report.get("component_id", &"")) == EXPECTED_COMPONENT_ID
		and StringName(report.get("evidence_status", &"")) == EXPECTED_EVIDENCE_STATUS,
		"the cluster publishes its v1 identity as modern interpretation"
	)
	_check(
		bool(report.get("valid", false)) and (report.get("errors", []) as Array).is_empty(),
		"the built cluster reports no placement or budget errors: %s" % [report.get("errors", [])]
	)
	_check(
		not bool(report.get("gameplay_authority", true))
		and not bool(report.get("grants_rewards", true))
		and int(report.get("range_targets_added", -1)) == 0,
		"the cluster declares no gameplay authority and no rewards"
	)
	_check(
		str(report.get("content_note", "")).find("No surviving source") >= 0,
		"the content note states plainly that no source authenticates the sector"
	)

	# The guided mission's objective count is `get_target_count()`. A decorative
	# drone anywhere in the cluster would silently rewrite it, so this is checked
	# against the live world rather than against the component's own claim.
	_check(world.get_target_count() == 4, "the world still owns exactly four range targets")
	var stray_targets := 0
	for candidate in cluster.find_children("*", "Node3D", true, false):
		if bool(candidate.get_meta("is_shipyard_target", false)):
			stray_targets += 1
	_check(stray_targets == 0, "the cluster contributes no range targets of its own")
	var interaction_areas := cluster.find_children("*", "Area3D", true, false)
	var cargo_access := cluster.get_cinder_cargo_access()
	var cargo_terminal := cluster.get_cinder_cargo_destination_terminal()
	_check(
		interaction_areas.size() == 1
		and cargo_access != null
		and cargo_access.get_berth() != null
		and cargo_terminal != null
		and interaction_areas[0] == cargo_terminal,
		"the destination terminal is the only interaction volume and the production berth remains lease-only"
	)

	# Structured red: the returned report is a deep copy, so a caller mutating it
	# cannot reach the component's record of what it built.
	var mutated := cluster.get_cluster_audit_report()
	mutated["valid"] = false
	mutated["gameplay_authority"] = true
	(mutated["errors"] as Array).append("injected")
	var reread := cluster.get_cluster_audit_report()
	_check(
		bool(reread.get("valid", false))
		and not bool(reread.get("gameplay_authority", true))
		and (reread.get("errors", []) as Array).is_empty(),
		"mutating a returned audit copy leaves the component's own report untouched"
	)


# --- Mining-platform presentation binding -----------------------------------


func _test_mining_platform_activity_presentation(cluster: NearbySectorCluster) -> void:
	var audit := cluster.get_mining_platform_presentation_audit()
	var presentation := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"
	) as Node3D
	var approach := presentation.get_node_or_null(^"MiningApproachAnchor") as Marker3D \
		if presentation != null else null
	var bounds := audit.get("presentation_local_bounds", AABB()) as AABB
	var counts := audit.get("counts", {}) as Dictionary
	var budgets := audit.get("budgets", {}) as Dictionary
	var optimization := audit.get("optimization_delta", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and (audit.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and StringName(audit.get("activity_id", &"")) == EXPECTED_MINING_ACTIVITY_ID
		and StringName(audit.get("content_class", &"")) == &"NEW"
		and StringName(audit.get("evidence_status", &"")) == EXPECTED_EVIDENCE_STATUS,
		"the live Cinder activity ID terminates on one valid original-modern platform presentation"
	)
	_check(
		(audit.get("platform_anchor", Vector3.ZERO) as Vector3).is_equal_approx(
			EXPECTED_PLATFORM_ANCHOR
		)
		and (audit.get("approach_anchor", Vector3.ZERO) as Vector3).is_equal_approx(
			EXPECTED_MINING_APPROACH_ANCHOR
		)
		and approach != null
		and approach.position.is_equal_approx(EXPECTED_MINING_APPROACH_LOCAL),
		"the activity's fixed platform and approach anchors bind to the existing platform and dock gate"
	)
	_check(
		presentation != null
		and int(counts.get("mesh_nodes", -1)) == EXPECTED_MINING_PRESENTATION_MESH_NODES
		and int(counts.get("multimesh_nodes", -1)) == EXPECTED_MINING_PRESENTATION_MULTIMESH_NODES
		and int(counts.get("renderer_nodes", -1)) == EXPECTED_MINING_PRESENTATION_RENDERER_NODES
		and int(counts.get("visible_copies", -1)) == EXPECTED_MINING_PRESENTATION_VISIBLE_COPIES
		and int(counts.get("surface_submissions", -1)) == EXPECTED_MINING_PRESENTATION_SUBMISSIONS
		and int(counts.get("mesh_resource_allocations", -1)) == EXPECTED_MINING_PRESENTATION_MESH_RESOURCES
		and int(counts.get("light_nodes", -1)) == EXPECTED_MINING_PRESENTATION_LIGHT_NODES
		and int(counts.get("descendant_nodes", -1)) == EXPECTED_MINING_PRESENTATION_DESCENDANTS
		and int(budgets.get("mesh_nodes", -1)) == EXPECTED_MINING_PRESENTATION_MESH_NODES
		and int(budgets.get("multimesh_nodes", -1)) == EXPECTED_MINING_PRESENTATION_MULTIMESH_NODES
		and int(budgets.get("renderer_nodes", -1)) == EXPECTED_MINING_PRESENTATION_RENDERER_NODES
		and int(budgets.get("visible_copies", -1)) == EXPECTED_MINING_PRESENTATION_VISIBLE_COPIES
		and int(budgets.get("surface_submissions", -1)) == EXPECTED_MINING_PRESENTATION_SUBMISSIONS
		and int(budgets.get("mesh_resource_allocations", -1)) == EXPECTED_MINING_PRESENTATION_MESH_RESOURCES
		and int(budgets.get("light_nodes", -1)) == EXPECTED_MINING_PRESENTATION_LIGHT_NODES
		and int(budgets.get("descendant_nodes", -1)) == EXPECTED_MINING_PRESENTATION_DESCENDANTS,
		"six exact batches preserve 22 copies in 12 renderers/submissions, 11 mesh resources, and 15 descendants"
	)
	_check(
		int(optimization.get("renderer_nodes_before", -1)) == 22
		and int(optimization.get("renderer_nodes_after", -1)) == 12
		and int(optimization.get("surface_submissions_before", -1)) == 22
		and int(optimization.get("surface_submissions_after", -1)) == 12
		and int(optimization.get("descendant_nodes_before", -1)) == 25
		and int(optimization.get("descendant_nodes_after", -1)) == 15
		and int(optimization.get("mesh_resource_allocations_before", -1)) == 11
		and int(optimization.get("mesh_resource_allocations_after", -1)) == 11
		and int(optimization.get("visible_copies_before", -1)) == 22
		and int(optimization.get("visible_copies_after", -1)) == 22,
		"the frozen optimization delta is 22 -> 12 submissions/renderers and 25 -> 15 nodes with resources/copies unchanged"
	)
	var batch_specs := {
		"MiningHeadframeLegs": {
			"family": &"mining-headframe-legs", "mesh_aabb": AABB(Vector3(-1.5, -11.0, -1.5), Vector3(3.0, 22.0, 3.0)),
			"material": "mining_structure", "transforms": [
				Transform3D(Basis.IDENTITY, Vector3(-12.0, 20.0, -4.0)),
				Transform3D(Basis.IDENTITY, Vector3(12.0, 20.0, -4.0)),
			],
		},
		"MiningHeadframeBraces": {
			"family": &"mining-headframe-braces", "mesh_aabb": AABB(Vector3(-7.5, -0.6, -1.0), Vector3(15.0, 1.2, 2.0)),
			"material": "mining_trim", "transforms": [
				Transform3D(Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(-48.0))), Vector3(-6.2, 23.0, -4.0)),
				Transform3D(Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(48.0))), Vector3(6.2, 23.0, -4.0)),
			],
		},
		"MiningFeedChutes": {
			"family": &"mining-feed-chutes", "mesh_aabb": AABB(Vector3(-1.5, -6.5, -1.5), Vector3(3.0, 13.0, 3.0)),
			"material": "mining_service", "transforms": [
				Transform3D(Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(-24.0))), Vector3(-7.0, 11.0, -2.0)),
				Transform3D(Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(24.0))), Vector3(7.0, 11.0, -2.0)),
			],
		},
		"MiningOreLiftPick": {
			"family": &"cinder-mining-ore-lift-pick", "mesh_aabb": AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE),
			"material": "mining_trim", "transforms": EXPECTED_MINING_ORE_LIFT_TRANSFORMS,
		},
		"MiningOreBufferBins": {
			"family": &"mining-ore-buffer-bins", "mesh_aabb": AABB(Vector3(-3.2, -3.5, -3.2), Vector3(6.4, 7.0, 6.4)),
			"material": "mining_service", "transforms": [
				Transform3D(Basis.IDENTITY, Vector3(-8.0, 4.0, 11.0)),
				Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, 11.0)),
				Transform3D(Basis.IDENTITY, Vector3(8.0, 4.0, 11.0)),
			],
		},
		"MiningOreBufferBands": {
			"family": &"mining-ore-buffer-bands", "mesh_aabb": AABB(Vector3(-3.3, -0.4, -3.3), Vector3(6.6, 0.8, 6.6)),
			"material": "mining_trim", "transforms": [
				Transform3D(Basis.IDENTITY, Vector3(-8.0, 4.0, 11.0)),
				Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, 11.0)),
				Transform3D(Basis.IDENTITY, Vector3(8.0, 4.0, 11.0)),
			],
		},
	}
	var batch_contracts_match := true
	var batch_mesh_ids := {}
	for batch_name in batch_specs:
		var spec := batch_specs[batch_name] as Dictionary
		var batch := presentation.get_node_or_null(NodePath(batch_name)) as MultiMeshInstance3D
		var transforms := spec["transforms"] as Array
		batch_contracts_match = batch_contracts_match and batch != null and batch.multimesh != null
		if batch == null or batch.multimesh == null:
			continue
		batch_mesh_ids[batch.multimesh.mesh.get_instance_id()] = true
		batch_contracts_match = batch_contracts_match \
			and batch.multimesh.instance_count == transforms.size() \
			and batch.multimesh.buffer == _encode_multimesh_transforms(transforms) \
			and (batch.get_meta(&"authored_instance_transforms", []) as Array) == transforms \
			and StringName(batch.get_meta(&"visual_batch_family_id", &"")) == spec["family"] \
			and bool(batch.get_meta(&"presentation_only", false)) \
			and batch.multimesh.mesh.get_aabb().is_equal_approx(spec["mesh_aabb"] as AABB) \
			and batch.material_override == cluster._materials[spec["material"]]
	_check(
		batch_contracts_match and batch_mesh_ids.size() == 6,
		"the six batches retain every frozen transform/material/mesh recipe with six exact shared resources"
	)
	_check(
		EXPECTED_MINING_PRESENTATION_LOCAL_BOUNDS.encloses(bounds)
		and bounds.size.x >= 28.0 and bounds.size.y >= 32.0
		and bounds.get_center().z < EXPECTED_MINING_APPROACH_LOCAL.z
		and bool(audit.get("approach_readable", false))
		and presentation.get_node_or_null(^"MiningHeadframeLegs") != null
		and presentation.get_node_or_null(^"OreSeparatorHopper") != null
		and presentation.get_node_or_null(^"MiningOreBufferBins") != null
		and presentation.get_node_or_null(^"Sign_ORE_EXTRACTION") != null,
		"the dock approach reads as a wide headframe, central hopper, three ore bins, and signed destination"
	)
	var port_light := presentation.get_node_or_null(^"MiningCrownLampPort") as OmniLight3D \
		if presentation != null else null
	var starboard_light := presentation.get_node_or_null(^"MiningCrownLampStarboard") as OmniLight3D \
		if presentation != null else null
	_check(
		port_light != null and starboard_light != null
		and not port_light.shadow_enabled and not starboard_light.shadow_enabled
		and absf(port_light.position.x - starboard_light.position.x) >= 24.0,
		"two shadowless crown practicals bracket the silhouette for approach recognition"
	)
	_check(
		not bool(audit.get("activity_authority", true))
		and not bool(audit.get("interaction_authority", true))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("reward_authority", true))
		and presentation.find_children("*", "CollisionObject3D", true, false).is_empty()
		and presentation.find_children("*", "CollisionShape3D", true, false).is_empty()
		and presentation.find_children("*", "Area3D", true, false).is_empty(),
		"the silhouette stays presentation-only with no collision, interaction, progress, or reward authority"
	)
	var detached := cluster.get_mining_platform_presentation_audit()
	detached["activity_authority"] = true
	(detached["errors"] as PackedStringArray).append("injected")
	_check(
		bool(cluster.get_mining_platform_presentation_audit().valid),
		"the mining presentation audit is detached from caller mutation"
	)
	if approach == null:
		return
	approach.position.z += 1.0
	var anchor_drift := cluster.get_mining_platform_presentation_audit()
	_check(
		not bool(anchor_drift.valid)
		and (anchor_drift.errors as PackedStringArray).has("mining_approach_marker_drift"),
		"moving the presentation marker away from the fixed dock gate is structured red"
	)
	approach.position = EXPECTED_MINING_APPROACH_LOCAL
	_check(
		bool(cluster.get_mining_platform_presentation_audit().valid),
		"restoring the fixed approach marker returns the presentation audit green"
	)
	print(
		"CINDER_MINING_PRESENTATION: renderers=%d copies=%d submissions=%d resources=%d descendants=%d bounds=%s" % [
			int(counts.get("renderer_nodes", -1)), int(counts.get("visible_copies", -1)),
			int(counts.get("surface_submissions", -1)), int(counts.get("mesh_resource_allocations", -1)),
			int(counts.get("descendant_nodes", -1)), str(bounds),
		]
	)


func _test_structure_scan_activity_presentation(cluster: NearbySectorCluster) -> void:
	var audit := cluster.get_structure_scan_presentation_audit()
	var presentation := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation"
	) as Node3D
	var approach := presentation.get_node_or_null(^"StructureScanApproachAnchor") as Marker3D \
		if presentation != null else null
	var bounds := audit.get("presentation_local_bounds", AABB()) as AABB
	var counts := audit.get("counts", {}) as Dictionary
	var budgets := audit.get("budgets", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and (audit.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and StringName(audit.get("activity_id", &"")) == EXPECTED_STRUCTURE_SCAN_ACTIVITY_ID
		and StringName(audit.get("content_class", &"")) == &"NEW"
		and StringName(audit.get("evidence_status", &"")) == EXPECTED_EVIDENCE_STATUS,
		"the abandoned-structure activity ID terminates on one valid original-modern derelict presentation"
	)
	_check(
		(audit.get("structure_anchor", Vector3.ZERO) as Vector3).is_equal_approx(
			EXPECTED_PLATFORM_ANCHOR
		)
		and (audit.get("approach_anchor", Vector3.ZERO) as Vector3).is_equal_approx(
			EXPECTED_STRUCTURE_SCAN_APPROACH_ANCHOR
		)
		and approach != null
		and approach.position.is_equal_approx(EXPECTED_STRUCTURE_SCAN_APPROACH_LOCAL),
		"the fixed scan anchors bind to the existing platform and its twenty-metre approach point"
	)
	_check(
		presentation != null
		and int(counts.get("mesh_nodes", -1)) == EXPECTED_STRUCTURE_SCAN_MESH_NODES
		and int(counts.get("light_nodes", -1)) == EXPECTED_STRUCTURE_SCAN_LIGHT_NODES
		and int(counts.get("descendant_nodes", -1)) == EXPECTED_STRUCTURE_SCAN_DESCENDANTS
		and int(budgets.get("mesh_nodes", -1)) == EXPECTED_STRUCTURE_SCAN_MESH_NODES
		and int(budgets.get("light_nodes", -1)) == EXPECTED_STRUCTURE_SCAN_LIGHT_NODES
		and int(budgets.get("descendant_nodes", -1)) == EXPECTED_STRUCTURE_SCAN_DESCENDANTS,
		"the derelict silhouette freezes at 13 meshes, 2 lights, and 16 descendants"
	)
	_check(
		EXPECTED_STRUCTURE_SCAN_PRESENTATION_LOCAL_BOUNDS.encloses(bounds)
		and bounds.size.x >= 44.0 and bounds.size.y >= 30.0
		and bounds.get_center().z < EXPECTED_STRUCTURE_SCAN_APPROACH_LOCAL.z
		and float(audit.get("world_outer_distance", INF)) < 760.0
		and is_equal_approx(
			float(audit.get("maximum_content_distance", 0.0)),
			NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE
		)
		and bool(audit.get("approach_readable", false))
		and presentation.get_node_or_null(^"ScanStructureRuinBatch") != null
		and presentation.get_node_or_null(^"SurveyPylonStarboard") != null
		and presentation.get_node_or_null(^"FracturedHeaderPort") != null
		and presentation.get_node_or_null(^"DeadArrayReceiver") != null
		and presentation.get_node_or_null(^"StructureScanSurveyFork") != null
		and presentation.get_node_or_null(^"Sign_DERELICT_SCAN") != null,
		"the scan approach reads as a teal survey fork, fractured datum, dead receiver, and signed derelict"
	)
	var port_light := presentation.get_node_or_null(^"DerelictDatumLampPort") as OmniLight3D \
		if presentation != null else null
	var starboard_light := presentation.get_node_or_null(^"DerelictDatumLampStarboard") as OmniLight3D \
		if presentation != null else null
	_check(
		port_light != null and starboard_light != null
		and not port_light.shadow_enabled and not starboard_light.shadow_enabled
		and absf(port_light.position.x - starboard_light.position.x) >= 44.0,
		"two low-energy shadowless datum lights bracket the abandoned silhouette"
	)
	_check(
		not bool(audit.get("scan_authority", true))
		and not bool(audit.get("interaction_authority", true))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("reward_authority", true))
		and presentation.find_children("*", "CollisionObject3D", true, false).is_empty()
		and presentation.find_children("*", "CollisionShape3D", true, false).is_empty()
		and presentation.find_children("*", "Area3D", true, false).is_empty(),
		"the derelict datum owns no scan, trigger, collision, progress, or reward authority"
	)
	var detached := cluster.get_structure_scan_presentation_audit()
	detached["scan_authority"] = true
	(detached["errors"] as PackedStringArray).append("injected")
	_check(
		bool(cluster.get_structure_scan_presentation_audit().valid),
		"the structure-scan presentation audit is detached from caller mutation"
	)
	if approach == null:
		return
	approach.position.x += 1.0
	var anchor_drift := cluster.get_structure_scan_presentation_audit()
	_check(
		not bool(anchor_drift.valid)
		and (anchor_drift.errors as PackedStringArray).has(
			"structure_scan_approach_marker_drift"
		),
		"moving the scan marker away from its fixed approach point is structured red"
	)
	approach.position = EXPECTED_STRUCTURE_SCAN_APPROACH_LOCAL
	_check(
		bool(cluster.get_structure_scan_presentation_audit().valid),
		"restoring the fixed scan marker returns the derelict audit green"
	)
	print(
		"CINDER_STRUCTURE_SCAN_PRESENTATION: meshes=%d lights=%d descendants=%d bounds=%s" % [
			int(counts.get("mesh_nodes", -1)), int(counts.get("light_nodes", -1)),
			int(counts.get("descendant_nodes", -1)), str(bounds),
		]
	)


func _test_beacon_traversal_presentation(cluster: NearbySectorCluster) -> void:
	var audit := cluster.get_beacon_traversal_presentation_audit()
	var counts := audit.get("counts", {}) as Dictionary
	var budgets := audit.get("budgets", {}) as Dictionary
	var positions := audit.get("beacon_positions", []) as Array
	var chips := cluster.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	_check(
		bool(audit.get("valid", false))
		and (audit.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and StringName(audit.get("activity_id", &"")) == EXPECTED_BEACON_TRAVERSAL_ACTIVITY_ID
		and StringName(audit.get("content_class", &"")) == &"NEW"
		and StringName(audit.get("evidence_status", &"")) == EXPECTED_EVIDENCE_STATUS,
		"the ordered beacon activity terminates on one valid original-modern corridor presentation"
	)
	var order_matches := positions.size() == BEACON_TRAVERSAL_ACTIVITY.BEACONS.size()
	for index in mini(positions.size(), BEACON_TRAVERSAL_ACTIVITY.BEACONS.size()):
		order_matches = order_matches and (positions[index] as Vector3).is_equal_approx(
			BEACON_TRAVERSAL_ACTIVITY.BEACONS[index]
		)
		var beacon := cluster.get_node_or_null(
			NodePath("RouteBeacons/RouteBeacon%s" % ["Alpha", "Bravo", "Charlie", "Delta"][index])
		) as Node3D
		order_matches = order_matches and beacon != null \
			and int(beacon.get_meta(&"traversal_order_index", -1)) == index \
			and StringName(beacon.get_meta(&"activity_id", &"")) \
				== EXPECTED_BEACON_TRAVERSAL_ACTIVITY_ID
	_check(order_matches, "the visual Alpha-to-Delta order exactly matches the activity's frozen beacon order")
	_check(
		counts == budgets
		and int(counts.get("beacon_meshes", -1)) == EXPECTED_TRAVERSAL_BEACON_MESHES
		and int(counts.get("beacon_lights", -1)) == EXPECTED_TRAVERSAL_BEACON_LIGHTS
		and int(counts.get("beacon_descendants", -1)) == EXPECTED_TRAVERSAL_BEACON_DESCENDANTS
		and int(counts.get("debris_batches", -1)) == 1
		and int(counts.get("debris_copies", -1)) == EXPECTED_TRAVERSAL_DEBRIS_COPIES
		and int(counts.get("debris_clusters", -1)) == EXPECTED_TRAVERSAL_DEBRIS_CLUSTERS,
		"four guide silhouettes and eight debris clusters stay within 44 meshes, 12 lights, 60 nodes, and one 520-copy batch"
	)
	var cluster_counts := audit.get("cluster_counts", PackedInt32Array()) as PackedInt32Array
	var clusters_balanced := cluster_counts.size() == EXPECTED_TRAVERSAL_DEBRIS_CLUSTERS
	for count in cluster_counts:
		clusters_balanced = clusters_balanced \
			and count == EXPECTED_TRAVERSAL_DEBRIS_COPIES / EXPECTED_TRAVERSAL_DEBRIS_CLUSTERS
	_check(
		clusters_balanced
		and chips != null and chips.multimesh != null
		and chips.custom_aabb.is_equal_approx(EXPECTED_TRAVERSAL_DEBRIS_BOUNDS)
		and bool(chips.get_meta(&"presentation_only", false))
		and StringName(chips.get_meta(&"activity_id", &"")) \
			== EXPECTED_BEACON_TRAVERSAL_ACTIVITY_ID,
		"the one presentation-only batch distributes exactly 65 chips into each authored flank cluster"
	)
	_check(
		is_equal_approx(
			float(audit.get("corridor_radius", 0.0)),
			EXPECTED_BEACON_TRAVERSAL_CORRIDOR_RADIUS
		)
		and float(audit.get("minimum_chip_clearance", 0.0)) \
			>= EXPECTED_BEACON_TRAVERSAL_CORRIDOR_RADIUS
		and float(audit.get("minimum_boulder_clearance", 0.0)) \
			>= EXPECTED_BEACON_TRAVERSAL_CORRIDOR_RADIUS
		and float(audit.get("maximum_leg_length", INF)) <= 140.0
		and bool(audit.get("approach_readable", false)),
		"every visual chip and conservative boulder collider clears the frozen 42 m ordered corridor"
	)
	var middle_of_bravo_charlie := (
		BEACON_TRAVERSAL_ACTIVITY.BEACONS[1] + BEACON_TRAVERSAL_ACTIVITY.BEACONS[2]
	) * 0.5
	_check(
		not bool(cluster.call(
			"_is_placeable_boulder_offset", middle_of_bravo_charlie - EXPECTED_PLATFORM_ANCHOR
		)),
		"the real boulder placement predicate rejects the middle of an ordered traversal leg"
	)
	var route_root := cluster.get_node_or_null(^"RouteBeacons") as Node3D
	_check(
		route_root != null
		and chips != null
		and route_root.find_children("*", "CollisionObject3D", true, false).is_empty()
		and route_root.find_children("*", "CollisionShape3D", true, false).is_empty()
		and chips.find_children("*", "CollisionObject3D", true, false).is_empty()
		and not bool(audit.get("activity_authority", true))
		and not bool(audit.get("order_authority", true))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("reward_authority", true)),
		"the corridor guides and debris own no collision, traversal order, progress, or reward authority"
	)
	var detached := cluster.get_beacon_traversal_presentation_audit()
	detached["order_authority"] = true
	(detached["errors"] as PackedStringArray).append("injected")
	_check(
		bool(cluster.get_beacon_traversal_presentation_audit().valid),
		"the beacon traversal presentation audit is detached from caller mutation"
	)
	if chips == null or chips.multimesh == null:
		return
	var original_positions := chips.get_meta(
		&"authored_instance_positions", PackedVector3Array()
	) as PackedVector3Array
	var drifted_positions := original_positions.duplicate()
	drifted_positions[0] = middle_of_bravo_charlie
	chips.set_meta(&"authored_instance_positions", drifted_positions)
	var corridor_drift := cluster.get_beacon_traversal_presentation_audit()
	_check(
		not bool(corridor_drift.valid)
		and (corridor_drift.errors as PackedStringArray).has(
			"beacon_traversal_debris_entered_safe_corridor"
		),
		"moving one visual chip into an ordered leg is structured corridor red"
	)
	chips.set_meta(&"authored_instance_positions", original_positions)
	_check(
		bool(cluster.get_beacon_traversal_presentation_audit().valid),
		"restoring the flank-cluster transform returns the traversal audit green"
	)
	print(
		"CINDER_BEACON_CORRIDOR: radius=%.2f chip_clearance=%.2f boulder_clearance=%.2f clusters=%s" % [
			float(audit.get("corridor_radius", 0.0)),
			float(audit.get("minimum_chip_clearance", 0.0)),
			float(audit.get("minimum_boulder_clearance", 0.0)), str(cluster_counts),
		]
	)


# The four charred plates are visual-only, but their overlap with the solid
# spine is what prevents the platform's damage read from splitting into a thin
# bright seam when it resolves at approach distance.
func _test_scorched_bay_seam_overlap(cluster: NearbySectorCluster) -> void:
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var bays: Array[MeshInstance3D] = []
	if platform != null:
		for child in platform.get_children():
			var bay := child as MeshInstance3D
			if bay != null \
				and bay.material_override == cluster._materials["char"] \
				and is_equal_approx(absf(bay.position.x), 4.62) \
				and bay.position.z in [-18.0, 6.0]:
				bays.append(bay)
	var overlap_is_seam_safe := bays.size() == 4
	for bay in bays:
		var inner_edge := absf(bay.position.x) \
			- NearbySectorCluster.SCORCHED_BAY_SIZE.x * 0.5
		overlap_is_seam_safe = overlap_is_seam_safe \
			and bay.mesh != null \
			and bay.get_parent() == platform \
			and inner_edge <= NearbySectorCluster.SPINE_SIZE.x * 0.5 - 0.20
	_check(
		overlap_is_seam_safe,
		"four collision-free scorched bay plates overlap the spine by at least 0.20 m to hide the approach-distance seam"
	)


# --- Bounded renderer batch --------------------------------------------------


func _test_processing_spine_rib_batch(cluster: NearbySectorCluster) -> void:
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var batch := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/ProcessingSpineRibs"
	) as MultiMeshInstance3D
	_check(platform != null and batch != null, "the processing spine exposes one named rib batch")
	if platform == null or batch == null or batch.multimesh == null:
		return

	var multimesh := batch.multimesh
	_check(
		multimesh.transform_format == MultiMesh.TRANSFORM_3D
		and multimesh.instance_count == EXPECTED_SPINE_RIB_TRANSFORMS.size()
		and multimesh.visible_instance_count == -1,
		"the batch draws all four authored 3D rib copies"
	)


	_check(
		multimesh.buffer == _encode_multimesh_transforms(EXPECTED_SPINE_RIB_TRANSFORMS),
		"the 48-float renderer buffer preserves the exact four original local transforms"
	)

	var authored_transforms := batch.get_meta(&"authored_instance_transforms", []) as Array
	var authored_roster_matches := authored_transforms.size() == EXPECTED_SPINE_RIB_TRANSFORMS.size()
	if authored_roster_matches:
		for transform_index in EXPECTED_SPINE_RIB_TRANSFORMS.size():
			if not (authored_transforms[transform_index] as Transform3D).is_equal_approx(
				EXPECTED_SPINE_RIB_TRANSFORMS[transform_index]
			):
				authored_roster_matches = false
				break
	_check(
		bool(batch.get_meta(&"visual_detail_only", false))
		and StringName(batch.get_meta(&"visual_batch_family_id", &"")) == EXPECTED_SPINE_RIB_FAMILY_ID
		and authored_roster_matches,
		"the batch identifies only this visual-detail family and retains its detached authored roster"
	)

	var rib_mesh := multimesh.mesh
	_check(
		rib_mesh != null
		and rib_mesh.get_aabb().is_equal_approx(EXPECTED_SPINE_RIB_AABB)
		and multimesh.custom_aabb.is_equal_approx(EXPECTED_SPINE_RIB_BATCH_AABB),
		"the individual rib and four-copy batch retain their exact local AABBs"
	)
	var triangles_per_copy := _mesh_triangle_count(rib_mesh)
	_check(
		triangles_per_copy == 108
		and triangles_per_copy * multimesh.instance_count == 432,
		"four visible rib copies retain 108 triangles each and 432 triangles total"
	)

	var steel_reference := platform.get_node_or_null(^"DrumCollarUpper") as GeometryInstance3D \
		if platform != null else null
	_check(
		steel_reference != null
		and batch.material_override == steel_reference.material_override,
		"the batched ribs retain the platform's exact shared steel material identity"
	)
	var legacy_ribs := 0
	for child in platform.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_aabb().is_equal_approx(
			EXPECTED_SPINE_RIB_AABB
		):
			for expected_transform in EXPECTED_SPINE_RIB_TRANSFORMS:
				if mesh_instance.transform.is_equal_approx(expected_transform):
					legacy_ribs += 1
	_check(
		legacy_ribs == 0
		and batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"no legacy rib renderer or collision node remains beside the one visual-only batch"
	)

	var geometry := _local_geometry_counts(cluster)
	print("CINDER_CLUSTER_GEOMETRY: %s" % [geometry])
	_check(
		int(geometry["mesh_nodes"]) == EXPECTED_LOCAL_MESH_NODES
		and int(geometry["multimesh_nodes"]) == EXPECTED_LOCAL_MULTIMESH_NODES
		and int(geometry["renderer_nodes"]) == EXPECTED_LOCAL_RENDERER_NODES,
		"NearbySectorCluster owns 198 Mesh + 17 MultiMesh renderers with all three activity landmarks"
	)
	_check(
		int(geometry["visible_copies"]) == EXPECTED_LOCAL_VISIBLE_COPIES
		and int(geometry["surface_submissions"]) == EXPECTED_LOCAL_SURFACE_SUBMISSIONS
		and int(geometry["triangles"]) == EXPECTED_LOCAL_TRIANGLES,
		"the local census freezes 766 copies, 126978 triangles, and 215 submissions"
	)
	_check(
		int(geometry["static_bodies"]) == EXPECTED_LOCAL_STATIC_BODIES
		and int(geometry["collision_shapes"]) == EXPECTED_LOCAL_COLLISION_SHAPES,
		"production composition retains 61 static bodies and the terminal's one interaction shape"
	)


func _test_extraction_arm_collar_batches(cluster: NearbySectorCluster) -> void:
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var steel_reference := platform.get_node_or_null(^"DrumCollarUpper") as MeshInstance3D \
		if platform != null else null
	var batch := platform.get_node_or_null(^"ExtractionArmCollars") as MultiMeshInstance3D \
		if platform != null else null
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var names := batch.get_meta(&"authored_instance_names", PackedStringArray()) \
		as PackedStringArray if batch != null else PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	var expected_names := PackedStringArray()
	var arms_valid := platform != null
	for spec in EXPECTED_ARM_COLLAR_ARM_SPECS:
		var arm_name := spec["name"] as StringName
		var arm := platform.get_node_or_null(NodePath(arm_name)) as Node3D if platform != null else null
		var expected_rotation := spec["rotation_degrees"] as Vector3
		var expected_arm_transform := Transform3D(
			Basis.from_euler(Vector3(
				deg_to_rad(expected_rotation.x),
				deg_to_rad(expected_rotation.y),
				deg_to_rad(expected_rotation.z)
			)),
			spec["position"] as Vector3
		)
		arms_valid = arms_valid and arm != null \
			and arm.transform.is_equal_approx(expected_arm_transform) \
			and arm.get_node_or_null(^"ArmSpar") is StaticBody3D \
			and arm.get_node_or_null(^"DrillHead") is StaticBody3D
		for collar_transform in EXPECTED_ARM_COLLAR_TRANSFORMS:
			expected_transforms.append(expected_arm_transform * collar_transform)
			expected_names.append("%s/ArmCollar" % arm_name)
	_check(
		arms_valid and batch != null and batch.multimesh != null \
			and batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D \
			and batch.multimesh.instance_count == 6 \
			and batch.multimesh.visible_instance_count == -1 \
			and batch.multimesh.buffer == _encode_multimesh_transforms(expected_transforms) \
			and batch.multimesh.mesh != null \
			and batch.multimesh.mesh.get_aabb().is_equal_approx(EXPECTED_ARM_COLLAR_AABB) \
			and batch.custom_aabb.is_equal_approx(
				_transformed_mesh_bounds(batch.multimesh.mesh.get_aabb(), expected_transforms)
			) \
			and batch.material_override == steel_reference.material_override \
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and bool(batch.get_meta(&"visual_detail_only", false)) \
			and StringName(batch.get_meta(&"visual_batch_family_id", &"")) == EXPECTED_ARM_COLLAR_FAMILY_ID \
			and transforms == expected_transforms \
			and names == expected_names \
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty() \
			and batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"six named, collision-free arm-collar copies retain their exact arm-local transforms and steel material through one bounded submission"
	)


func _test_gantry_rail_batch(cluster: NearbySectorCluster) -> void:
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var batch := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/GantryRails"
	) as MultiMeshInstance3D
	_check(platform != null and batch != null, "the gantry exposes one named rail batch")
	if platform == null or batch == null or batch.multimesh == null:
		return
	var multimesh := batch.multimesh
	_check(
		multimesh.transform_format == MultiMesh.TRANSFORM_3D
		and multimesh.instance_count == EXPECTED_GANTRY_RAIL_TRANSFORMS.size()
		and multimesh.visible_instance_count == -1
		and multimesh.buffer == _encode_multimesh_transforms(EXPECTED_GANTRY_RAIL_TRANSFORMS),
		"the one gantry batch preserves all four authored rail transforms"
	)
	var authored_transforms := batch.get_meta(&"authored_instance_transforms", []) as Array
	_check(
		bool(batch.get_meta(&"visual_detail_only", false))
		and StringName(batch.get_meta(&"visual_batch_family_id", &"")) == EXPECTED_GANTRY_RAIL_FAMILY_ID
		and authored_transforms == EXPECTED_GANTRY_RAIL_TRANSFORMS
		and multimesh.mesh != null
		and multimesh.mesh.get_aabb().is_equal_approx(EXPECTED_GANTRY_RAIL_AABB)
		and batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the rail batch stays visual-only, collision-free, and keeps the exact rail recipe"
	)
	var legacy_rails := 0
	for child in platform.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name == &"GantryRail":
			legacy_rails += 1
	_check(legacy_rails == 0, "no legacy gantry rail renderer remains beside the batch")


func _test_lamp_lens_mesh_sharing(cluster: NearbySectorCluster) -> void:
	var audit := cluster.get_lamp_lens_allocation_audit()
	var first_lens := cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconAlpha/HomeLampLens"
	) as MeshInstance3D
	var second_lens := cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconAlpha/OutboundLampLens"
	) as MeshInstance3D
	var shared_mesh := first_lens.mesh as SphereMesh if first_lens != null else null
	_check(
		bool(audit.valid)
		and int(audit.copy_count) == EXPECTED_LAMP_LENS_COPY_COUNT
		and int(audit.mesh_resource_allocations) == 1
		and first_lens != null and second_lens != null
		and second_lens.mesh == shared_mesh
		and first_lens.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and second_lens.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and is_equal_approx(shared_mesh.radius, EXPECTED_LAMP_LENS_RADIUS)
		and is_equal_approx(shared_mesh.height, EXPECTED_LAMP_LENS_HEIGHT)
		and shared_mesh.radial_segments == EXPECTED_LAMP_LENS_RADIAL_SEGMENTS
		and shared_mesh.rings == EXPECTED_LAMP_LENS_RINGS,
		"all 26 named presentation-only lamp lenses share one exact immutable sphere mesh"
	)
	if shared_mesh == null or second_lens == null:
		return
	var original_mesh := second_lens.mesh
	second_lens.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_drift := cluster.get_lamp_lens_allocation_audit()
	_check(
		not bool(identity_drift.valid)
		and (identity_drift.errors as PackedStringArray).has(
			"lamp_lens_retained_private_mesh"
		)
		and (identity_drift.errors as PackedStringArray).has(
			"lamp_lens_mesh_identity_drift"
		),
		"a private lamp-lens mesh copy is structured red without changing any path or light"
	)
	second_lens.mesh = original_mesh
	_check(
		bool(cluster.get_lamp_lens_allocation_audit().valid),
		"restoring the shared lamp-lens identity returns the allocation audit green"
	)


func _test_torus_mesh_sharing(cluster: NearbySectorCluster) -> void:
	var signal_alpha := cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconAlpha/SignalRing"
	) as MeshInstance3D
	var signal_bravo := cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconBravo/SignalRing"
	) as MeshInstance3D
	var trim_alpha := cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconAlpha/TrimRing"
	) as MeshInstance3D
	var trim_bravo := cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconBravo/TrimRing"
	) as MeshInstance3D
	var upper_collar := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/DrumCollarUpper"
	) as MeshInstance3D
	var lower_collar := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/DrumCollarLower"
	) as MeshInstance3D
	var audit := cluster.get_torus_allocation_audit()
	_check(
		bool(audit.valid)
		and int(audit.copy_count) == EXPECTED_TORUS_COPY_COUNT
		and int(audit.mesh_resource_allocations) == EXPECTED_TORUS_MESH_RESOURCE_ALLOCATIONS
		and signal_alpha != null and signal_bravo != null
		and trim_alpha != null and trim_bravo != null
		and upper_collar != null and lower_collar != null
		and signal_alpha.mesh == signal_bravo.mesh
		and trim_alpha.mesh == trim_bravo.mesh
		and upper_collar.mesh == lower_collar.mesh
		and signal_alpha.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and trim_alpha.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and upper_collar.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"nineteen named non-colliding tori retain their paths while twelve exact recipes share resources"
	)
	if signal_alpha == null or signal_bravo == null:
		return
	var original_mesh := signal_bravo.mesh
	signal_bravo.mesh = (original_mesh as TorusMesh).duplicate() as TorusMesh
	var identity_drift := cluster.get_torus_allocation_audit()
	_check(
		not bool(identity_drift.valid)
		and (identity_drift.errors as PackedStringArray).has("torus_shared_family_identity_drift")
		and (identity_drift.errors as PackedStringArray).has("torus_mesh_allocation_count_drift"),
		"a private route-ring mesh is a structured allocation and family-identity red"
	)
	signal_bravo.mesh = original_mesh
	var shared_mesh := signal_alpha.mesh as TorusMesh
	shared_mesh.rings = EXPECTED_TORUS_RINGS - 1
	var recipe_drift := cluster.get_torus_allocation_audit()
	_check(
		not bool(recipe_drift.valid)
		and (recipe_drift.errors as PackedStringArray).has("torus_mesh_recipe_drift"),
		"an authored torus tessellation change is a structured recipe red"
	)
	shared_mesh.rings = EXPECTED_TORUS_RINGS
	_check(
		bool(cluster.get_torus_allocation_audit().valid),
		"restoring route-ring identity and tessellation returns the allocation audit green"
	)
	var before_normalise := cluster.get_torus_allocation_audit()
	TorusGeometryBudget.normalise_tree(cluster)
	var after_normalise := cluster.get_torus_allocation_audit()
	_check(
		bool(before_normalise.valid)
		and bool(after_normalise.valid)
		and int(after_normalise.copy_count) == EXPECTED_TORUS_COPY_COUNT
		and int(after_normalise.mesh_resource_allocations) == EXPECTED_TORUS_MESH_RESOURCE_ALLOCATIONS
		and signal_alpha.mesh == signal_bravo.mesh
		and trim_alpha.mesh == trim_bravo.mesh
		and upper_collar.mesh == lower_collar.mesh,
		"TorusGeometryBudget preserves shared resource identity and the nineteen-copy/twelve-allocation census"
	)
	var exact_recipe_mesh := cluster._shared_torus_mesh(5.0, 5.6)
	var near_recipe_mesh := cluster._shared_torus_mesh(5.00005, 5.6)
	_check(
		exact_recipe_mesh != near_recipe_mesh,
		"a near-equal but nonidentical radius is a non-sharing red rather than rounded into the signal-ring resource"
	)
	cluster._torus_mesh_cache.erase(cluster._torus_recipe_key(5.00005, 5.6))
	_check(
		bool(cluster.get_torus_allocation_audit().valid),
		"removing the isolated near-equal probe restores the component's frozen torus allocation census"
	)


func _local_geometry_counts(cluster: NearbySectorCluster) -> Dictionary:
	var mesh_nodes := cluster.find_children("*", "MeshInstance3D", true, false)
	var multimesh_nodes := cluster.find_children("*", "MultiMeshInstance3D", true, false)
	var visible_copies := mesh_nodes.size()
	var surface_submissions := 0
	var triangles := 0
	for candidate in mesh_nodes:
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh == null:
			continue
		surface_submissions += mesh.get_surface_count()
		triangles += _mesh_triangle_count(mesh)
	for candidate in multimesh_nodes:
		var multimesh := (candidate as MultiMeshInstance3D).multimesh
		if multimesh == null or multimesh.mesh == null:
			continue
		var copy_count := multimesh.visible_instance_count
		if copy_count < 0:
			copy_count = multimesh.instance_count
		visible_copies += copy_count
		surface_submissions += multimesh.mesh.get_surface_count()
		triangles += _mesh_triangle_count(multimesh.mesh) * copy_count
	return {
		"mesh_nodes": mesh_nodes.size(),
		"multimesh_nodes": multimesh_nodes.size(),
		"renderer_nodes": mesh_nodes.size() + multimesh_nodes.size(),
		"visible_copies": visible_copies,
		"surface_submissions": surface_submissions,
		"triangles": triangles,
		"static_bodies": cluster.find_children("*", "StaticBody3D", true, false).size(),
		"collision_shapes": cluster.find_children("*", "CollisionShape3D", true, false).size(),
	}


func _mesh_triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var triangles := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return triangles


func _encode_multimesh_transforms(transforms: Array) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value: Transform3D = transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _transformed_mesh_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	for transform_value in transforms:
		var piece := (transform_value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


# --- Placement ----------------------------------------------------------------


func _test_placement_envelope(cluster: NearbySectorCluster) -> void:
	var platform_distance := cluster.get_platform_distance()
	_check(
		platform_distance > STATION_EXCLUSION_RADIUS
		and platform_distance < MAXIMUM_TRAVEL_DISTANCE,
		"the platform sits %.0f m out, inside the published travel envelope" % platform_distance
	)
	var cruise_seconds := cluster.get_cruise_travel_seconds()
	_check(
		cruise_seconds > 4.0 and cruise_seconds < 15.0,
		"a cruise transit is %.1f s: a decision to leave, not a chore" % cruise_seconds
	)

	# Nothing may crowd the station. Measured on every live body in the cluster,
	# not on the published anchors, so a stray beacon or boulder is caught.
	var nearest := INF
	var nearest_name := ""
	for candidate in cluster.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if not (node is StaticBody3D or node is MeshInstance3D or node is Light3D):
			continue
		var distance := node.global_position.length()
		if distance < nearest:
			nearest = distance
			nearest_name = str(node.name)
	_check(
		nearest >= STATION_EXCLUSION_RADIUS,
		"the nearest cluster body (%s) is %.0f m out, clear of the corridor and range"
		% [nearest_name, nearest]
	)

	var beacons := cluster.get_route_beacon_positions()
	_check(beacons.size() == EXPECTED_BEACON_COUNT, "the route is exactly four hand-placed beacons")
	var previous_distance := 0.0
	var ordered := true
	var spacing_ok := true
	for beacon in beacons:
		var distance := beacon.length()
		if distance <= previous_distance:
			ordered = false
		if previous_distance > 0.0 and distance - previous_distance > 200.0:
			spacing_ok = false
		previous_distance = distance
	_check(ordered, "the beacon chain runs monotonically outward from the station")
	_check(spacing_ok, "no leg of the chain leaves the pilot without a landmark")

	# The approach lane and the platform keep-clear sphere are what make the
	# destination reachable at speed regardless of the scatter seed.
	var boulders := cluster.get_boulder_offsets()
	var lane_intrusions := 0
	var keep_clear_intrusions := 0
	for offset in boulders:
		if offset.length() < EXPECTED_PLATFORM_KEEP_CLEAR:
			keep_clear_intrusions += 1
		if _is_inside_lane(offset):
			lane_intrusions += 1
	_check(
		boulders.size() == EXPECTED_BOULDER_COUNT,
		"the field placed its full complement of %d boulders" % EXPECTED_BOULDER_COUNT
	)
	_check(keep_clear_intrusions == 0, "no boulder stands inside the platform keep-clear sphere")
	_check(lane_intrusions == 0, "no boulder stands inside the approach lane")

	# The gate the lane leads to has to actually be open, and wide enough that a
	# 7 m interceptor is threading a structure rather than scraping one.
	var gate_center := cluster.get_dock_gate_center()
	_check(
		gate_center.distance_to(EXPECTED_PLATFORM_ANCHOR) < EXPECTED_LANE_LENGTH
		and EXPECTED_GATE_WIDTH >= 20.0
		and EXPECTED_GATE_HEIGHT >= 16.0,
		"the dock gate stands on the lane with a %.0f x %.0f m clear aperture"
		% [EXPECTED_GATE_WIDTH, EXPECTED_GATE_HEIGHT]
	)
	# Nothing solid may sit in the middle of the lane past the gate's far frame.
	# The gate's own members ring the aperture and stay outside this core.
	var lane_blockers := 0
	for candidate in cluster.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var offset := body.global_position - EXPECTED_PLATFORM_ANCHOR
		if offset.z <= EXPECTED_GATE_FAR_Z or offset.z >= EXPECTED_LANE_LENGTH:
			continue
		if Vector2(offset.x, offset.y - EXPECTED_LANE_CENTER_Y).length() < 10.0:
			lane_blockers += 1
	_check(lane_blockers == 0, "nothing solid stands in the middle of the gate aperture or the lane")


## Structured red for the placement rule: the predicate that keeps the lane and
## the platform clear must actively reject offsets inside them, not merely have
## produced a clean scatter by luck of the seed.
func _test_placement_predicate_rejects_the_lane(cluster: NearbySectorCluster) -> void:
	var inside_keep_clear := Vector3(0.0, 0.0, EXPECTED_PLATFORM_KEEP_CLEAR - 5.0)
	var inside_lane := Vector3(
		0.0,
		EXPECTED_LANE_CENTER_Y,
		EXPECTED_PLATFORM_KEEP_CLEAR + 20.0
	)
	var on_a_beacon := (
		(cluster.get_route_beacon_positions()[EXPECTED_BEACON_COUNT - 1]) - EXPECTED_PLATFORM_ANCHOR
	)

	_check(
		not bool(cluster.call("_is_placeable_boulder_offset", inside_keep_clear)),
		"a boulder offset inside the platform keep-clear sphere is rejected"
	)
	_check(
		not bool(cluster.call("_is_placeable_boulder_offset", inside_lane)),
		"a boulder offset inside the approach lane is rejected"
	)
	_check(
		not bool(cluster.call("_is_placeable_boulder_offset", on_a_beacon)),
		"a boulder offset on top of a route beacon is rejected"
	)
	# The predicate has to still say yes somewhere, or "rejects everything" would
	# read as a pass. A ring behind the platform, outside the keep-clear sphere and
	# outside the lane, is scanned rather than one hand-picked point, because a
	# single point can land inside the separation radius of a placed boulder.
	var accepted := 0
	for step in 36:
		var angle := TAU * float(step) / 36.0
		var probe := Vector3(cos(angle), 0.0, sin(angle)) * 150.0
		if bool(cluster.call("_is_placeable_boulder_offset", probe)):
			accepted += 1
	_check(
		accepted > 0,
		"open field outside the lane still accepts boulders (%d of 36 ring probes)" % accepted
	)


## Whether a platform-relative offset lies inside the approach lane, measured
## against this suite's frozen lane dimensions.
func _is_inside_lane(offset: Vector3) -> bool:
	if offset.z <= 0.0 or offset.z >= EXPECTED_LANE_LENGTH:
		return false
	return Vector2(offset.x, offset.y - EXPECTED_LANE_CENTER_Y).length() < EXPECTED_LANE_RADIUS


# --- Winding ------------------------------------------------------------------


## Every surface the cluster builds has to face outward. The kit's box builder is
## already guarded, but this component drives it at a bevel proportion nothing
## else uses (0.30 of the shortest side, on 20-64 m stock), so the built tree is
## measured rather than the builder trusted.
func _test_winding(cluster: NearbySectorCluster) -> void:
	var expected_sign := _calibrate()
	_check(expected_sign != 0, "engine primitives agree on one front-face winding convention")
	if expected_sign == 0:
		return

	var meshes: Dictionary = {}
	for candidate in cluster.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			meshes[mesh.get_instance_id()] = mesh
	for candidate in cluster.find_children("*", "MultiMeshInstance3D", true, false):
		var multimesh := (candidate as MultiMeshInstance3D).multimesh
		if multimesh != null and multimesh.mesh is ArrayMesh:
			meshes[multimesh.mesh.get_instance_id()] = multimesh.mesh
	_check(
		meshes.size() >= 12,
		"the cluster's built tree offers %d distinct procedural meshes to measure" % meshes.size()
	)

	var backwards_meshes := 0
	var measured_triangles := 0
	var sample: ArrayMesh = null
	for id: int in meshes:
		var mesh := meshes[id] as ArrayMesh
		if sample == null:
			sample = mesh
		var report := _score(mesh)
		var triangles := int(report["triangles"])
		var agreeing := int(report["agreeing"])
		measured_triangles += triangles
		var backwards := agreeing if expected_sign == -1 else triangles - agreeing
		if triangles == 0 or backwards > 0:
			backwards_meshes += 1
	_check(
		backwards_meshes == 0 and measured_triangles > 0,
		"all %d cluster meshes wind every one of their %d triangles outward"
		% [meshes.size(), measured_triangles]
	)

	# Structured red: a deliberately reversed copy of a real cluster mesh must
	# read as fully backwards, or the measurement above proves nothing.
	if sample != null:
		var reversed_report := _score(_reverse(sample))
		var reversed_triangles := int(reversed_report["triangles"])
		var reversed_agreeing := int(reversed_report["agreeing"])
		var reversed_backwards := (
			reversed_agreeing if expected_sign == -1 else reversed_triangles - reversed_agreeing
		)
		_check(
			reversed_triangles > 0 and reversed_backwards == reversed_triangles,
			"a reversed copy of a cluster mesh is detected as fully backwards (%d/%d)"
			% [reversed_backwards, reversed_triangles]
		)


func _calibrate() -> int:
	var signs: Dictionary = {}
	for mesh_class in ENGINE_CALIBRATION_MESHES:
		var mesh := ClassDB.instantiate(mesh_class) as Mesh
		if mesh == null:
			continue
		var report := _score(mesh)
		var triangles := int(report["triangles"])
		var agreeing := int(report["agreeing"])
		if triangles == 0:
			continue
		if agreeing == 0:
			signs[-1] = true
		elif agreeing == triangles:
			signs[1] = true
		else:
			signs[0] = true
	if signs.size() != 1 or signs.has(0):
		return 0
	return -1 if signs.has(-1) else 1


func _reverse(source: ArrayMesh) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var reversed_verts := PackedVector3Array()
	var reversed_norms := PackedVector3Array()
	var index := 0
	while index + 2 < verts.size():
		reversed_verts.append(verts[index])
		reversed_verts.append(verts[index + 2])
		reversed_verts.append(verts[index + 1])
		reversed_norms.append(norms[index])
		reversed_norms.append(norms[index + 2])
		reversed_norms.append(norms[index + 1])
		index += 3
	var reversed_arrays: Array = []
	reversed_arrays.resize(Mesh.ARRAY_MAX)
	reversed_arrays[Mesh.ARRAY_VERTEX] = reversed_verts
	reversed_arrays[Mesh.ARRAY_NORMAL] = reversed_norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reversed_arrays)
	return mesh


func _score(mesh: Mesh) -> Dictionary:
	var triangles := 0
	var agreeing := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_NORMAL] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		var count := idx.size() if idx.size() > 0 else verts.size()
		var cursor := 0
		while cursor + 2 < count:
			var a_i := idx[cursor] if idx.size() > 0 else cursor
			var b_i := idx[cursor + 1] if idx.size() > 0 else cursor + 1
			var c_i := idx[cursor + 2] if idx.size() > 0 else cursor + 2
			cursor += 3
			var geometric := (verts[b_i] - verts[a_i]).cross(verts[c_i] - verts[a_i])
			if geometric.length() < 1e-9:
				continue
			var shading := norms[a_i] + norms[b_i] + norms[c_i]
			if shading.length() < 1e-6:
				continue
			triangles += 1
			if geometric.normalized().dot(shading.normalized()) > 0.0:
				agreeing += 1
	return {"triangles": triangles, "agreeing": agreeing}


# --- Collision ----------------------------------------------------------------


func _test_collision_boundary(cluster: NearbySectorCluster) -> void:
	var bodies := cluster.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() > 20, "the cluster's solid structures are real bodies (%d)" % bodies.size())
	var wrong_layer := 0
	var wrong_mask := 0
	var shapeless := 0
	for candidate in bodies:
		var body := candidate as StaticBody3D
		if body.collision_layer != PhysicsLayers.WORLD:
			wrong_layer += 1
		if body.collision_mask != 0:
			wrong_mask += 1
		if body.find_children("*", "CollisionShape3D", false, false).is_empty():
			shapeless += 1
	_check(wrong_layer == 0, "every cluster body sits on the same World layer the station uses")
	_check(wrong_mask == 0, "no cluster body queries other layers")
	_check(shapeless == 0, "every cluster body carries its own collision shape")

	# Structured red: the same predicate must reject a body built on the wrong
	# layer, so a clean scan above is a measurement and not a tautology.
	var rogue := StaticBody3D.new()
	rogue.collision_layer = PhysicsLayers.TARGET
	rogue.collision_mask = PhysicsLayers.WORLD
	_check(
		rogue.collision_layer != PhysicsLayers.WORLD and rogue.collision_mask != 0,
		"a body on the target layer with a live mask is distinguishable from a cluster body"
	)
	rogue.free()

	# The beacon chain is the one thing that must *not* be solid: it stands in the
	# lane the pilot is told to follow.
	var beacon_root := cluster.get_node_or_null(^"RouteBeacons") as Node3D
	_check(
		beacon_root != null
		and beacon_root.find_children("*", "StaticBody3D", true, false).is_empty(),
		"the route beacons are presentation only and cannot be collided with"
	)


# --- Determinism and lifecycle -----------------------------------------------


func _test_determinism(cluster: NearbySectorCluster, twin: NearbySectorCluster) -> void:
	var first := cluster.get_boulder_offsets()
	var second := twin.get_boulder_offsets()
	var identical := first.size() == second.size()
	if identical:
		for index in first.size():
			if not first[index].is_equal_approx(second[index]):
				identical = false
				break
	_check(identical, "two independent builds scatter the same field from the same fixed seed")

	var chips_a := cluster.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	var chips_b := twin.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	_check(chips_a != null and chips_b != null, "both builds carry the instanced debris shell")
	if chips_a == null or chips_b == null:
		return
	_check(
		chips_a.multimesh.instance_count == EXPECTED_DEBRIS_CHIP_COUNT
		and chips_b.multimesh.instance_count == EXPECTED_DEBRIS_CHIP_COUNT,
		"the debris shell carries its exact declared instance count"
	)
	var transforms_match := true
	var colors_match := true
	for index in [0, 137, 419, EXPECTED_DEBRIS_CHIP_COUNT - 1]:
		if not chips_a.multimesh.get_instance_transform(index).is_equal_approx(
			chips_b.multimesh.get_instance_transform(index)
		):
			transforms_match = false
		if not chips_a.multimesh.get_instance_color(index).is_equal_approx(
			chips_b.multimesh.get_instance_color(index)
		):
			colors_match = false
	_check(transforms_match and colors_match, "the debris shell is instanced identically every build")

	# Determinism is meaningless if the two builds are the same object.
	_check(
		cluster.get_instance_id() != twin.get_instance_id(),
		"the two compared clusters are genuinely separate instances"
	)


func _test_lifecycle(world: ShipyardWorld, cluster: NearbySectorCluster) -> void:
	_check(
		cluster.is_cluster_enabled() and cluster.visible and cluster.is_processing(),
		"the cluster starts enabled, visible and animating"
	)
	var body_count := cluster.find_children("*", "StaticBody3D", true, false).size()
	var shape_count := cluster.find_children("*", "CollisionShape3D", true, false).size()

	cluster.set_cluster_enabled(false)
	await process_frame
	_check(
		not cluster.visible and not cluster.is_processing(),
		"disabling the cluster stops every animated element and hides it"
	)
	cluster.set_cluster_enabled(true)
	await process_frame
	_check(
		cluster.visible and cluster.is_processing(),
		"re-enabling restores visibility and animation without rebuilding"
	)

	for quality in [
		NearbySectorCluster.DetailQuality.LOW,
		NearbySectorCluster.DetailQuality.MEDIUM,
		NearbySectorCluster.DetailQuality.HIGH,
	]:
		cluster.set_detail_quality(quality)
		var chips := cluster.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
		_check(
			chips != null
			and chips.visible == (quality >= NearbySectorCluster.DetailQuality.MEDIUM),
			"quality %d shows the fine debris shell only above the lowest profile" % quality
		)
		_check(
			cluster.find_children("*", "StaticBody3D", true, false).size() == body_count
			and cluster.find_children("*", "CollisionShape3D", true, false).size() == shape_count,
			"quality %d leaves the flyable shape of the sector untouched" % quality
		)
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.HIGH)

	# Whole-world detach and re-entry, the way `Main` streams the shipyard.
	var parent := cluster.get_parent()
	var report_before := cluster.get_cluster_audit_report()
	var detached_chips := cluster.get_node_or_null(
		^"DebrisField/DebrisChips"
	) as MultiMeshInstance3D
	var detached_snapshot := {
		"enabled": cluster.is_cluster_enabled(),
		"visible": cluster.visible,
		"detail_quality": cluster.get_detail_quality(),
		"chips_visible": detached_chips.visible if detached_chips != null else false,
	}
	parent.remove_child(cluster)
	await process_frame
	cluster.set_cluster_enabled(false)
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.LOW)
	_check(
		not cluster.is_inside_tree()
		and {
				"enabled": cluster.is_cluster_enabled(),
				"visible": cluster.visible,
				"detail_quality": cluster.get_detail_quality(),
				"chips_visible": detached_chips.visible if detached_chips != null else false,
			} == detached_snapshot,
		"detached direct profile mutators leave Cinder presentation and detail state atomic",
	)
	parent.add_child(cluster)
	var reentered_processing := cluster.is_processing()
	# Re-entry schedules its lifecycle restoration on idle. A caller may still
	# choose the retained profile in the same turn; the deferred work must not
	# restore the pre-detach value over that newer choice.
	cluster.set_cluster_enabled(false)
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.LOW)
	await process_frame
	_check(
		cluster.is_inside_tree()
		and reentered_processing
		and not cluster.is_cluster_enabled()
		and not cluster.visible
		and not cluster.is_processing()
		and cluster.get_detail_quality() == NearbySectorCluster.DetailQuality.LOW
		and detached_chips != null
		and not detached_chips.visible,
		"fresh live profile controls survive the deferred re-entry restoration"
	)
	_check(
		cluster.get_cluster_audit_report() == report_before
		and cluster.get_boulder_offsets().size() == EXPECTED_BOULDER_COUNT,
		"the post-reentry profile change retains the original built field"
	)

	cluster.set_cluster_enabled(true)
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.HIGH)
	await process_frame
	_check(
		cluster.is_inside_tree()
		and cluster.visible
		and cluster.is_processing()
		and cluster.get_detail_quality() == NearbySectorCluster.DetailQuality.HIGH
		and detached_chips != null
		and detached_chips.visible,
		"fresh live re-entry controls restore animation and fine debris presentation"
	)
	_check(
		cluster.get_cluster_audit_report() == report_before
		and cluster.get_boulder_offsets().size() == EXPECTED_BOULDER_COUNT,
		"re-entry keeps the identical built field rather than scattering a second one"
	)
	_check(
		world.get_nearby_sector_cluster() == null
		and world.get_nearby_sector_cluster_audit_report().get("reason")
			== &"streamed_cluster_unavailable",
		"a component-local re-entry cannot create a stale ShipyardWorld streaming reference"
	)

	# A re-entry restore is deferred. A streamed cluster may be selected for
	# deferred deletion in that same turn, while it still reports in-tree; its
	# queued lifecycle must not rewrite presentation or processing ownership.
	parent.remove_child(cluster)
	await process_frame
	parent.add_child(cluster)
	var queued_restore_snapshot := {
		"enabled": cluster.is_cluster_enabled(),
		"visible": cluster.visible,
		"processing": cluster.is_processing(),
		"detail_quality": cluster.get_detail_quality(),
		"chips_visible": detached_chips.visible if detached_chips != null else false,
	}
	cluster.queue_free()
	cluster.set_cluster_enabled(false)
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.LOW)
	cluster.call("_restore_cluster_enabled_after_reentry")
	_check(
		cluster.is_queued_for_deletion()
		and {
			"enabled": cluster.is_cluster_enabled(),
			"visible": cluster.visible,
			"processing": cluster.is_processing(),
			"detail_quality": cluster.get_detail_quality(),
			"chips_visible": detached_chips.visible if detached_chips != null else false,
		} == queued_restore_snapshot,
		"queued direct profile mutation and re-entry restoration leave Cinder presentation inert"
	)


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("NEARBY_SECTOR_CLUSTER_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("NEARBY_SECTOR_CLUSTER_TEST_OK")
		quit(0)
	else:
		print("NEARBY_SECTOR_CLUSTER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
