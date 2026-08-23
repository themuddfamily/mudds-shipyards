extends SceneTree

const DRESSING_SCENE := preload("res://scenes/world/components/station_structural_service_dressing.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dressing := DRESSING_SCENE.instantiate() as StationStructuralServiceDressing
	_check(dressing != null, "typed structural service dressing scene instantiates")
	if dressing == null:
		_finish()
		return
	_check(
		dressing.configure(
			14.0,
			StationStructuralServiceDressing.StructuralProfile.STANDARD,
			StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_X
		),
		"valid length, profile, and mount-plane orientation configure before build"
	)
	_check(
		not dressing.configure(
			3.0,
			StationStructuralServiceDressing.StructuralProfile.STANDARD,
			StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_X
		),
		"configuration rejects a segment shorter than the bounded footprint range"
	)
	root.add_child(dressing)
	await process_frame

	var audit := dressing.get_audit_report()
	_check(bool(audit["valid"]), "default high-quality instance passes structural, evidence, and budget audit")
	_check(audit["component_id"] == &"station-structural-service-dressing", "component publishes a stable typed identifier")
	_check(audit["evidence_status"] == &"modern_interpretation", "component is explicitly modern interpretation")
	_check(bool(dressing.get_meta("presentation_only", false)), "root metadata marks all dressing presentation-only")
	_check(bool(dressing.get_meta("provisional", false)), "root metadata preserves provisional status")
	_check(not bool(dressing.get_meta("authenticated_original_geometry", true)), "root makes no authenticated original-geometry claim")

	var evidence := audit["evidence"] as Dictionary
	_check(not bool(evidence["authenticated_original_geometry"]), "evidence report rejects recovered structural geometry")
	_check(not bool(evidence["authenticated_original_placement"]), "evidence report rejects recovered placement")
	_check((evidence["modern_interpretations"] as PackedStringArray).size() >= 5, "audit inventories unsupported modern detail")

	var integration := dressing.get_integration_contract()
	_check(integration["mount_type"] == &"planar_attachment_surface_center", "root is the centre of a generic planar attachment surface")
	_check(integration["attachment_surface_normal_local"] == Vector3.BACK, "canonical local +Z points away from the attachment surface")
	_check(integration["segment_axis_local"] == Vector3.RIGHT, "canonical segment follows mount-local X")
	_check(integration["crossface_axis_local"] == Vector3.DOWN, "canonical cross-face direction is mount-local negative Y")
	_check(bool(integration["supports_underdeck_mount"]) and bool(integration["supports_outer_wall_mount"]), "contract supports under-deck and outer-wall root transforms")
	_check(not bool(integration["assumes_world_up"]), "integration contract does not assume a top deck or world-up mount")
	_check(not bool(integration["widens_walkable_surface"]) and not bool(integration["fills_station_void"]), "dressing cannot widen a deck or fill station negative space")
	_check(integration["collision_policy"] == &"presentation_only_collision_free", "integration contract promises collision-free presentation")
	var margin_roles := integration["compatible_margin_roles"] as PackedStringArray
	for role in ["central_berth_outer_edge", "aft_junction_underdeck", "habitat_outer_edge", "freight_margin"]:
		_check(role in margin_roles, "integration contract includes %s" % role)

	var footprint := integration["local_footprint"] as AABB
	_check(footprint.position.is_equal_approx(Vector3(-7.0, -1.13, 0.0)), "standard 14 m footprint begins at the exact bounded mount-relative minimum")
	_check(footprint.size.is_equal_approx(Vector3(14.0, 1.13, 0.86)), "standard 14 m footprint publishes exact tangent, cross-face, and outward extents")
	_check(footprint.position.z >= 0.0, "no visual envelope penetrates behind the attachment surface")
	_check(dressing.get_mount_anchor().transform.is_equal_approx(Transform3D.IDENTITY), "mount anchor remains exactly at the component root")
	_check(dressing.get_mount_transform().is_equal_approx(dressing.global_transform), "root and mount-anchor transforms agree")
	_check(dressing.get_dressing_center_anchor().position.z > 0.0, "dressing centre lies outward from the attachment surface")

	var node_contract := audit["node_contract"] as Dictionary
	for key: String in node_contract:
		_check(dressing.get_node_or_null(node_contract[key] as NodePath) != null, "stable audit node resolves: %s" % key)

	var features := audit["features"] as Dictionary
	_check(int(features["structural_posts"]) == 5, "five posts divide the keel into four structural bays")
	_check(int(features["cross_braces"]) == 8, "four bays expose a complete paired X-brace pattern")
	_check(int(features["conduits"]) == 3 and int(features["conduit_clamps"]) == 4, "three constrained conduits use four visible clamp frames")
	_check(int(features["radiator_backplates"]) == 1 and int(features["radiator_vents"]) == 6, "one radiator bank exposes six restrained vent blades")
	_check(int(features["task_strips"]) == 2, "two restrained task strips remain non-textual service cues")
	_check(int(features["task_lights"]) == 1, "one bounded task light is present")

	var performance := dressing.get_performance_audit()
	var counts := performance["counts"] as Dictionary
	print("STATION_STRUCTURAL_DRESSING_PERFORMANCE: ", performance)
	_check(bool(performance["within_budget"]), "maximum-detail component remains within every explicit budget")
	_check(
		int(counts["mesh_instances"]) == 10
		and int(counts["multimesh_batches"]) == 6
		and int(counts["geometry_submissions"]) == 16
		and int(counts["visible_primitives"]) == 41,
		"high quality preserves 41 visible copies through 16 renderer submissions"
	)
	var clamp_batch := dressing.get_node_or_null(
		^"PresentationRoot/ServiceDetailRoot/ConduitClampBatch"
	) as MultiMeshInstance3D
	var clamp_audit := dressing.get_conduit_clamp_batch_audit()
	var expected_clamp_positions := [
		Vector3(-3.276, -0.3672, 0.156),
		Vector3(-1.092, -0.3672, 0.156),
		Vector3(1.092, -0.3672, 0.156),
		Vector3(3.276, -0.3672, 0.156),
	]
	var exact_clamp_anchors := true
	for clamp_index in expected_clamp_positions.size():
		var clamp_anchor := dressing.get_node_or_null(NodePath(
			"PresentationRoot/ServiceDetailRoot/ConduitClamp%02d" % (clamp_index + 1)
		)) as Marker3D
		exact_clamp_anchors = exact_clamp_anchors and (
			clamp_anchor != null
			and clamp_anchor.position.is_equal_approx(expected_clamp_positions[clamp_index])
			and clamp_anchor.get_child_count() == 0
		)
	_check(
		bool(clamp_audit["valid"])
		and int(clamp_audit["baseline_renderer_nodes"]) == 4
		and int(clamp_audit["renderer_nodes"]) == 1
		and int(clamp_audit["drawn_copies"]) == 4
		and clamp_batch != null
		and clamp_batch.multimesh.mesh.get_aabb().size.is_equal_approx(
			Vector3(0.0588, 0.3024, 0.0812)
		)
		and exact_clamp_anchors
		and dressing.find_children("ConduitClamp*", "MeshInstance3D", true, false).is_empty(),
		"four named conduit clamps retain exact geometry and transforms through one inert visual batch"
	)
	if clamp_batch != null and clamp_batch.multimesh != null:
		var original_clamp_buffer := clamp_batch.multimesh.buffer.duplicate()
		var drifted_clamp_buffer := original_clamp_buffer.duplicate()
		drifted_clamp_buffer[3] += 0.25
		clamp_batch.multimesh.buffer = drifted_clamp_buffer
		_check(
			not bool(dressing.get_conduit_clamp_batch_audit()["valid"]),
			"structured red: conduit-clamp renderer-buffer drift fails the batch audit"
		)
		clamp_batch.multimesh.buffer = original_clamp_buffer
		_check(
			bool(dressing.get_conduit_clamp_batch_audit()["valid"]),
			"restoring the exact conduit-clamp buffer repairs the batch audit"
		)
	var post_batch := dressing.get_node_or_null(
		^"PresentationRoot/StructuralCoreRoot/KeelPostBatch"
	) as MultiMeshInstance3D
	var post_audit := dressing.get_keel_post_batch_audit()
	var expected_post_positions := [
		Vector3(-6.86, -0.5435, 0.4524),
		Vector3(-3.43, -0.5435, 0.4524),
		Vector3(0.0, -0.5435, 0.4524),
		Vector3(3.43, -0.5435, 0.4524),
		Vector3(6.86, -0.5435, 0.4524),
	]
	var exact_post_anchors := true
	for post_index in expected_post_positions.size():
		var post_anchor := dressing.get_node_or_null(NodePath(
			"PresentationRoot/StructuralCoreRoot/KeelPost%02d" % (post_index + 1)
		)) as Marker3D
		exact_post_anchors = exact_post_anchors and (
			post_anchor != null
			and post_anchor.position.is_equal_approx(expected_post_positions[post_index])
			and post_anchor.get_child_count() == 0
		)
	_check(
		bool(post_audit["valid"])
		and int(post_audit["baseline_renderer_nodes"]) == 5
		and int(post_audit["renderer_nodes"]) == 1
		and int(post_audit["drawn_copies"]) == 5
		and post_batch != null
		and post_batch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(0.14, 0.709, 0.14))
		and exact_post_anchors
		and dressing.find_children("KeelPost*", "MeshInstance3D", true, false).is_empty(),
		"five named keel posts retain exact geometry and transforms through one inert visual batch"
	)
	if post_batch != null and post_batch.multimesh != null:
		var original_post_buffer := post_batch.multimesh.buffer.duplicate()
		var drifted_post_buffer := original_post_buffer.duplicate()
		drifted_post_buffer[3] += 0.25
		post_batch.multimesh.buffer = drifted_post_buffer
		_check(
			not bool(dressing.get_keel_post_batch_audit()["valid"]),
			"structured red: keel-post renderer-buffer drift fails the batch audit"
		)
		post_batch.multimesh.buffer = original_post_buffer
		_check(
			bool(dressing.get_keel_post_batch_audit()["valid"]),
			"restoring the exact keel-post buffer repairs the batch audit"
		)
	var brace_batch := dressing.get_node_or_null(
		^"PresentationRoot/StructuralCoreRoot/CrossBraceBatch"
	) as MultiMeshInstance3D
	var expected_brace_transforms: Array[Transform3D] = []
	var first_x := -7.0 + 0.14
	var last_x := 7.0 - 0.14
	var top_y := -0.14 * 1.35
	var lower_y := -1.08 + 0.14 * 1.3
	var brace_z := 0.78 * 0.58
	var brace_height := 0.0
	var stable_brace_anchors := true
	for bay_index in 4:
		var bay_start := lerpf(first_x, last_x, float(bay_index) / 4.0)
		var bay_end := lerpf(first_x, last_x, float(bay_index + 1) / 4.0)
		var endpoints := [
			[Vector3(bay_start, lower_y, brace_z), Vector3(bay_end, top_y, brace_z)],
			[Vector3(bay_start, top_y, brace_z), Vector3(bay_end, lower_y, brace_z)],
		]
		for brace_side in 2:
			var from := endpoints[brace_side][0] as Vector3
			var to := endpoints[brace_side][1] as Vector3
			var direction := to - from
			brace_height = direction.length()
			var expected_transform := Transform3D(
				Basis(Quaternion(Vector3.UP, direction.normalized())),
				(from + to) * 0.5
			)
			expected_brace_transforms.append(expected_transform)
			var anchor := dressing.get_node_or_null(NodePath(
				"PresentationRoot/StructuralCoreRoot/CrossBrace%s%02d"
				% ["A" if brace_side == 0 else "B", bay_index + 1]
			)) as Marker3D
			stable_brace_anchors = stable_brace_anchors and (
				anchor != null
				and anchor.transform.is_equal_approx(expected_transform)
				and anchor.get_child_count() == 0
				and anchor.get_script() == null
				and anchor.get_groups().is_empty()
			)
	var authored_brace_transforms := (
		brace_batch.get_meta("authored_instance_transforms", []) as Array
		if brace_batch != null else []
	)
	var exact_brace_transforms := authored_brace_transforms.size() == expected_brace_transforms.size()
	for brace_index in mini(authored_brace_transforms.size(), expected_brace_transforms.size()):
		exact_brace_transforms = exact_brace_transforms and (
			authored_brace_transforms[brace_index] is Transform3D
			and (authored_brace_transforms[brace_index] as Transform3D).is_equal_approx(
				expected_brace_transforms[brace_index]
			)
		)
	_check(
		brace_batch != null
		and brace_batch.multimesh != null
		and brace_batch.multimesh.instance_count == 8
		and brace_batch.multimesh.visible_instance_count == 8
		and brace_batch.multimesh.mesh.get_aabb().size.is_equal_approx(
			Vector3(0.084, brace_height, 0.084)
		)
		and exact_brace_transforms
		and stable_brace_anchors
		and brace_batch.get_child_count() == 0
		and dressing.find_children("CrossBrace?*", "MeshInstance3D", true, false).is_empty(),
		"eight stable cross-brace paths retain exact geometry and transforms through one inert visual batch"
	)
	_check(
		int(counts["mesh_instances"]) == 27 - 8 - 5 - 4
		and int(counts["multimesh_batches"]) == 3 + 1 + 1 + 1
		and int(counts["geometry_submissions"]) == 30 - 7 - 4 - 3,
		"cross-brace family records 8 -> 1 renderer submissions with all eight copies preserved"
	)
	if brace_batch != null and brace_batch.multimesh != null:
		var original_brace_buffer := brace_batch.multimesh.buffer.duplicate()
		var drifted_brace_buffer := original_brace_buffer.duplicate()
		drifted_brace_buffer[3] += 0.25
		brace_batch.multimesh.buffer = drifted_brace_buffer
		_check(
			not bool(dressing.get_audit_report()["valid"]),
			"structured red: cross-brace renderer-buffer drift fails the component audit"
		)
		brace_batch.multimesh.buffer = original_brace_buffer
		_check(
			bool(dressing.get_audit_report()["valid"]),
			"restoring the exact cross-brace renderer buffer repairs the component audit"
		)
		var original_brace_transform := brace_batch.transform
		brace_batch.position += Vector3(0.25, 0.0, 0.0)
		_check(
			not bool(dressing.get_audit_report()["valid"]),
			"structured red: cross-brace batch-root drift fails the component audit"
		)
		brace_batch.transform = original_brace_transform
		_check(
			bool(dressing.get_audit_report()["valid"]),
			"restoring the identity cross-brace batch root repairs the component audit"
		)
	var task_batch := dressing.get_node_or_null(^"PresentationRoot/HighDetailRoot/TaskStripBatch") as MultiMeshInstance3D
	var task_anchor_01 := dressing.get_node_or_null(^"PresentationRoot/HighDetailRoot/TaskStrip01") as Marker3D
	var task_anchor_02 := dressing.get_node_or_null(^"PresentationRoot/HighDetailRoot/TaskStrip02") as Marker3D
	_check(
		task_batch != null
		and task_batch.multimesh != null
		and task_batch.multimesh.instance_count == 2
		and task_batch.multimesh.visible_instance_count == 2
		and task_anchor_01 != null
		and task_anchor_02 != null
		and not task_anchor_01.position.is_equal_approx(task_anchor_02.position),
		"two stable task-strip anchors retain distinct authored positions under one visual batch"
	)
	var vent_batch_audit := dressing.get_radiator_vent_batch_audit()
	print("STATION_STRUCTURAL_RADIATOR_VENT_BATCH: ", vent_batch_audit)
	_check(
		bool(vent_batch_audit["valid"])
		and int(vent_batch_audit["baseline_renderer_nodes"]) == 6
		and int(vent_batch_audit["renderer_nodes"]) == 1
		and int(vent_batch_audit["baseline_geometry_submissions"]) == 6
		and int(vent_batch_audit["geometry_submissions"]) == 1
		and int(vent_batch_audit["baseline_mesh_resource_count"]) == 1
		and int(vent_batch_audit["mesh_resource_count"]) == 1
		and int(vent_batch_audit["baseline_drawn_copies"]) == 6
		and int(vent_batch_audit["drawn_copies"]) == 6
		and bool(vent_batch_audit["exact_transforms_preserved"])
		and not bool(vent_batch_audit["collision_authority"])
		and not bool(vent_batch_audit["interaction_authority"]),
		"six exact radiator blades use one inert renderer batch and one unchanged mesh resource"
	)
	var vent_batch := dressing.get_node(
		"PresentationRoot/ServiceDetailRoot/RadiatorVentBlades"
	) as MultiMeshInstance3D
	var expected_vent_transforms: Array[Transform3D] = []
	for expected_x in [1.832857, 2.275714, 2.718571, 3.161429, 3.604286, 4.047143]:
		expected_vent_transforms.append(Transform3D(
			Basis.IDENTITY, Vector3(float(expected_x), -0.6156, 0.792)
		))
	var authored_vent_transforms := vent_batch.get_meta("authored_instance_transforms", []) as Array
	var exact_vent_transforms := authored_vent_transforms.size() == expected_vent_transforms.size()
	for vent_index in expected_vent_transforms.size():
		exact_vent_transforms = exact_vent_transforms and (
			authored_vent_transforms[vent_index] is Transform3D
			and (authored_vent_transforms[vent_index] as Transform3D).is_equal_approx(
				expected_vent_transforms[vent_index]
			)
		)
	_check(
		vent_batch != null
		and vent_batch.multimesh != null
		and vent_batch.multimesh.instance_count == 6
		and exact_vent_transforms
		and vent_batch.multimesh.mesh.get_aabb().size.is_equal_approx(
			Vector3(0.075, 0.425088, 0.045)
		)
		and vent_batch.material_override == clamp_batch.material_override
		and vent_batch.get_child_count() == 0
		and dressing.find_children("RadiatorVentBlade*", "MeshInstance3D", true, false).is_empty(),
		"batch replaces only the six legacy renderer nodes without changing their copies or material"
	)
	var authored_vent_buffer := vent_batch.multimesh.buffer.duplicate()
	var drifted_vent_buffer := authored_vent_buffer.duplicate()
	drifted_vent_buffer[3] = 99.0
	vent_batch.multimesh.buffer = drifted_vent_buffer
	var vent_red := dressing.get_radiator_vent_batch_audit()
	_check(
		not bool(vent_red["valid"])
		and _has_error(vent_red, "radiator_vent_transform_buffer_drift"),
		"structured red: radiator batch rejects transformed-copy drift"
	)
	vent_batch.multimesh.buffer = authored_vent_buffer
	_check(bool(dressing.get_radiator_vent_batch_audit()["valid"]), "restoring the exact blade buffer repairs the batch contract")
	_check(int(counts["lights"]) == 1 and int(counts["visible_lights"]) == 1, "high quality uses exactly one visible bounded light")
	_check(int(counts["shadow_casting_lights"]) == 0, "task light never enables shadows")
	_check(int(counts["collision_nodes"]) == 0, "component contains no body, area, shape, or collision polygon")
	_check(int(counts["audio_nodes"]) == 0 and int(counts["reflection_probes"]) == 0, "component contains no audio or reflection probes")
	_check(int(counts["particle_emitters"]) == 0 and int(counts["animation_players"]) == 0, "component contains no particles or movers")
	_check(int(counts["text_nodes"]) == 0, "component contains no text, label, or signage geometry")
	_check(not bool(performance["process_enabled"]) and not bool(performance["physics_process_enabled"]), "static dressing performs no per-frame processing")
	_check(not bool(performance["per_frame_allocation"]) and not bool(performance["quality_changes_allocate"]), "audit explicitly rejects per-frame and quality-toggle allocation")
	_check(not bool(performance["runtime_rebuild_allowed"]), "built instances cannot reallocate geometry through runtime configuration")

	var task_light := dressing.get_node("PresentationRoot/HighDetailRoot/RestrainedTaskLight") as OmniLight3D
	_check(task_light != null and not task_light.shadow_enabled, "physical task light is present and non-shadowing")
	_check(task_light != null and task_light.light_energy <= 0.25 and task_light.omni_range <= 2.6, "task light energy and influence stay tightly bounded")
	_check(_subtree_has_only_allowed_static_nodes(dressing), "runtime subtree contains only static visual, marker, and light node types")

	# Mirrors the exact four resident ShipyardWorld dressings without involving
	# ShipyardWorld ownership: their 24 visible fasteners keep their paths and
	# per-instance material overrides while one session-retained mesh is shared.
	var sharing_root := Node3D.new()
	sharing_root.name = "FasciaFastenerSharingFixture"
	root.add_child(sharing_root)
	var sharing_specs := [
		["CentralBerthOuterFascia", 20.0, StationStructuralServiceDressing.StructuralProfile.STANDARD],
		["AftOperationsOuterFascia", 6.0, StationStructuralServiceDressing.StructuralProfile.LIGHT],
		["HabitatOuterServiceDressing", 12.0, StationStructuralServiceDressing.StructuralProfile.STANDARD],
		["FreightRackServiceDressing", 20.0, StationStructuralServiceDressing.StructuralProfile.LIGHT],
	]
	var sharing_mesh_ids: Dictionary = {}
	var sharing_rows := 0
	var sharing_instances: Array[StationStructuralServiceDressing] = []
	for spec in sharing_specs:
		var sharing_dressing := DRESSING_SCENE.instantiate() as StationStructuralServiceDressing
		sharing_dressing.name = String(spec[0])
		_check(
			sharing_dressing.configure(
				float(spec[1]), int(spec[2]),
				StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_X
			),
			"resident fascia-sharing fixture configures %s" % spec[0]
		)
		sharing_root.add_child(sharing_dressing)
		sharing_instances.append(sharing_dressing)
	await process_frame
	for sharing_dressing in sharing_instances:
		var fastener_audit := sharing_dressing.get_fascia_fastener_resource_audit()
		_check(
			bool(fastener_audit.get("valid", false))
			and int(fastener_audit.get("copy_count", 0)) == 6
			and int(fastener_audit.get("mesh_resource_identity_count", 0)) == 1
			and int(fastener_audit.get("baseline_mesh_resource_identity_count", 0)) == 6
			and int(fastener_audit.get("mesh_resource_identity_delta", 0)) == -5
			and bool(fastener_audit.get("session_retained_immutable_mesh", false))
			and bool(fastener_audit.get("batched", false))
			and int(fastener_audit.get("baseline_geometry_submissions", 0)) == 6
			and int(fastener_audit.get("geometry_submissions", 0)) == 1
			and not bool(fastener_audit.get("collision_authority", true))
			and not bool(fastener_audit.get("lifecycle_authority", true)),
			"%s retains one exact inert fascia-fastener mesh" % sharing_dressing.name
		)
		for fastener in sharing_dressing.find_children("FasciaFastener??", "Marker3D", true, false):
			var batch := sharing_dressing.get_node(^"PresentationRoot/HighDetailRoot/FasciaFastenerBatch") as MultiMeshInstance3D
			sharing_mesh_ids[batch.multimesh.mesh.get_instance_id()] = true
			sharing_rows += 1
	_check(
		sharing_rows == 24 and sharing_mesh_ids.size() == 1,
		"four resident dressings retain 24 fascia copies through one immutable mesh"
	)
	var sharing_fastener_batch := sharing_instances[3].get_node(
		"PresentationRoot/HighDetailRoot/FasciaFastenerBatch"
	) as MultiMeshInstance3D
	var shared_fastener_mesh := sharing_fastener_batch.multimesh.mesh
	sharing_fastener_batch.multimesh.mesh = shared_fastener_mesh.duplicate() as ArrayMesh
	var sharing_red := sharing_instances[3].get_fascia_fastener_resource_audit()
	_check(
		not bool(sharing_red.get("valid", true))
		and int(sharing_red.get("mesh_resource_identity_count", 0)) == 2
		and _has_error(sharing_red, "fascia_fastener_mesh_identity_drift")
		and _has_error(sharing_red, "fascia_fastener_mesh_identity_count_drift"),
		"structured red: one duplicated resident fastener breaks the shared identity contract"
	)
	sharing_fastener_batch.multimesh.mesh = shared_fastener_mesh
	_check(
		bool(sharing_instances[3].get_fascia_fastener_resource_audit().get("valid", false)),
		"restoring the fastener mesh repairs the shared-resource contract"
	)
	sharing_root.queue_free()
	await process_frame

	# Quality changes reveal already-built subtrees; they never rebuild geometry.
	var high_node_count := int(counts["node_count"])
	_check(dressing.set_quality_level(StationStructuralServiceDressing.DetailQuality.MEDIUM), "quality API accepts medium")
	performance = dressing.get_performance_audit()
	counts = performance["counts"] as Dictionary
	_check(int(counts["mesh_instances"]) == 10 and int(counts["visible_primitives"]) == 33, "medium quality keeps 10 allocated meshes plus six batches and exposes 33 copies")
	_check(int(counts["visible_lights"]) == 0, "medium quality hides the high-tier task light")
	_check(int(counts["node_count"]) == high_node_count, "medium quality performs no structural allocation")
	_check(dressing.set_quality_level(StationStructuralServiceDressing.DetailQuality.LOW), "quality API accepts low")
	performance = dressing.get_performance_audit()
	counts = performance["counts"] as Dictionary
	_check(int(counts["visible_primitives"]) == 16 and int(counts["node_count"]) == high_node_count, "low quality retains only the 16-mesh structural silhouette without reallocating")
	_check(not dressing.set_quality_level(99) and dressing.get_quality_level() == StationStructuralServiceDressing.DetailQuality.LOW, "invalid quality is rejected without changing state")

	dressing.set_dressing_enabled(false)
	_check(not dressing.is_dressing_enabled(), "visibility API disables the dressing")
	performance = dressing.get_performance_audit()
	counts = performance["counts"] as Dictionary
	_check(int(counts["visible_primitives"]) == 0 and int(counts["visible_lights"]) == 0, "disabled dressing exposes no primitives or lights")
	dressing.set_dressing_enabled(false)
	_check(not dressing.is_dressing_enabled(), "repeated disable is idempotent")
	dressing.set_dressing_enabled(true)
	_check(dressing.is_dressing_enabled(), "visibility API re-enables the prebuilt dressing")
	_check(int((dressing.get_performance_audit()["counts"] as Dictionary)["visible_primitives"]) == 16, "reenable restores the selected low tier")
	_check(dressing.set_quality_level(StationStructuralServiceDressing.DetailQuality.HIGH), "quality API restores high detail")

	var configuration_before := dressing.get_configuration()
	_check(
		not dressing.configure(
			20.0,
			StationStructuralServiceDressing.StructuralProfile.DEEP,
			StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y
		),
		"live component rejects a geometry rebuild"
	)
	_check(dressing.get_configuration() == configuration_before, "rejected runtime configuration leaves the immutable build unchanged")

	# Exported authoring properties remain writable by Godot, so exercise the
	# adversarial path that bypasses configure(). Published geometry contracts
	# must stay pinned to what was actually built, while the audit fails closed.
	var built_footprint_before := dressing.get_local_footprint()
	var built_integration_before := dressing.get_integration_contract()
	var built_mesh_corner_aabb_before := _subtree_mesh_corner_aabb(dressing)
	dressing.segment_length = 24.0
	_check(_audit_rejects_live_structural_divergence(dressing), "audit rejects a valid post-build segment-length write by itself")
	dressing.segment_length = float(configuration_before["segment_length"])
	dressing.structural_profile = StationStructuralServiceDressing.StructuralProfile.DEEP
	_check(_audit_rejects_live_structural_divergence(dressing), "audit rejects a valid post-build structural-profile write by itself")
	dressing.structural_profile = int(configuration_before["structural_profile"])
	dressing.segment_orientation = StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y
	_check(_audit_rejects_live_structural_divergence(dressing), "audit rejects a valid post-build segment-orientation write by itself")
	dressing.segment_orientation = int(configuration_before["segment_orientation"])
	dressing.segment_length = 24.0
	dressing.structural_profile = StationStructuralServiceDressing.StructuralProfile.DEEP
	dressing.segment_orientation = StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y
	var divergent_configuration := dressing.get_configuration()
	var divergent_integration := dressing.get_integration_contract()
	var divergent_audit := dressing.get_audit_report()
	_check(divergent_configuration == configuration_before, "post-build export writes cannot rewrite the published build configuration")
	_check(dressing.get_local_footprint() == built_footprint_before, "post-build export writes cannot rewrite the published local footprint")
	_check(
		divergent_integration["local_footprint"] == built_integration_before["local_footprint"]
		and divergent_integration["local_min"] == built_integration_before["local_min"]
		and divergent_integration["local_max"] == built_integration_before["local_max"]
		and divergent_integration["local_size"] == built_integration_before["local_size"],
		"post-build export writes cannot rewrite integration envelope fields"
	)
	_check(
		divergent_integration["segment_axis_local"] == built_integration_before["segment_axis_local"]
		and divergent_integration["crossface_axis_local"] == built_integration_before["crossface_axis_local"]
		and divergent_integration["outward_axis_local"] == built_integration_before["outward_axis_local"],
		"post-build orientation writes cannot rotate published integration axes"
	)
	_check(
		_subtree_mesh_corner_aabb(dressing) == built_mesh_corner_aabb_before,
		"post-build export writes leave the exact transformed mesh-corner AABB unchanged"
	)
	_check(not bool(divergent_audit["valid"]), "live authoring divergence makes the structural audit invalid")
	_check(
		"live structural authoring configuration diverges from immutable build snapshot"
		in (divergent_audit["errors"] as PackedStringArray),
		"audit names the immutable-build divergence instead of failing open"
	)
	_check(divergent_audit["configuration"] == configuration_before, "invalid divergence audit still reports the immutable built configuration")
	_check(
		(divergent_audit["integration"] as Dictionary)["local_footprint"] == built_footprint_before,
		"invalid divergence audit still reports the immutable built envelope"
	)
	var divergent_node_count := int(((divergent_audit["performance"] as Dictionary)["counts"] as Dictionary)["node_count"])
	_check(dressing.set_quality_level(StationStructuralServiceDressing.DetailQuality.LOW), "quality switching remains available during authoring divergence")
	_check(
		int((dressing.get_performance_audit()["counts"] as Dictionary)["visible_primitives"]) == 16,
		"divergent authoring state can still select the prebuilt low-quality tier"
	)
	_check(dressing.set_quality_level(StationStructuralServiceDressing.DetailQuality.HIGH), "quality switching restores high detail during authoring divergence")
	_check(
		int((dressing.get_performance_audit()["counts"] as Dictionary)["node_count"]) == divergent_node_count,
		"quality switching during divergence allocates no replacement geometry"
	)
	dressing.segment_length = float(configuration_before["segment_length"])
	dressing.structural_profile = int(configuration_before["structural_profile"])
	dressing.segment_orientation = int(configuration_before["segment_orientation"])
	_check(bool(dressing.get_audit_report()["valid"]), "restoring authored structural values reconciles the immutable build audit")

	# Audit trees are recursively detached from future calls and component state.
	var detached_audit := dressing.audit()
	((detached_audit["performance"] as Dictionary)["counts"] as Dictionary).clear()
	(detached_audit["integration"] as Dictionary).clear()
	(detached_audit["evidence"] as Dictionary).clear()
	(detached_audit["node_contract"] as Dictionary).clear()
	var fresh_audit := dressing.audit()
	_check(int(((fresh_audit["performance"] as Dictionary)["counts"] as Dictionary)["mesh_instances"]) == 10, "deep-copy audit protects nested performance counts")
	_check(not (fresh_audit["integration"] as Dictionary).is_empty(), "deep-copy audit protects integration state")
	_check(not (fresh_audit["evidence"] as Dictionary).is_empty(), "deep-copy audit protects evidence state")
	_check(not (fresh_audit["node_contract"] as Dictionary).is_empty(), "deep-copy audit protects semantic node paths")

	# A quarter-turned deep profile keeps +Z as the attachment normal. The caller's
	# arbitrary root basis demonstrates an underside mount without world-up logic.
	var turned := DRESSING_SCENE.instantiate() as StationStructuralServiceDressing
	_check(turned != null, "second typed instance supports independent configuration")
	if turned != null:
		_check(
			turned.configure(
				20.0,
				StationStructuralServiceDressing.StructuralProfile.DEEP,
				StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y
			),
			"deep profile configures along the second mount-plane axis"
		)
		turned.initial_quality = StationStructuralServiceDressing.DetailQuality.MEDIUM
		turned.position = Vector3(30.0, 7.0, -18.0)
		turned.basis = Basis(Vector3.RIGHT, PI * 0.5)
		root.add_child(turned)
		await process_frame
		var turned_audit := turned.get_audit_report()
		_check(bool(turned_audit["valid"]), "arbitrarily oriented deep profile passes its complete audit")
		var turned_integration := turned_audit["integration"] as Dictionary
		_check((turned_integration["segment_axis_local"] as Vector3).is_equal_approx(Vector3.UP), "quarter-turn maps the segment tangent to mount-local Y")
		_check((turned_integration["crossface_axis_local"] as Vector3).is_equal_approx(Vector3.RIGHT), "quarter-turn keeps the cross-face span within the attachment plane")
		_check((turned_integration["outward_axis_local"] as Vector3).is_equal_approx(Vector3.BACK), "quarter-turn preserves mount-local +Z as the surface normal")
		var turned_footprint := turned_integration["local_footprint"] as AABB
		_check(turned_footprint.position.is_equal_approx(Vector3(0.0, -10.0, 0.0)), "turned 20 m profile publishes exact mount-relative minimum")
		_check(turned_footprint.size.is_equal_approx(Vector3(1.39, 20.0, 1.10)), "turned deep footprint swaps tangent and cross-face extents without changing outward depth")
		var turned_counts := (turned_audit["performance"] as Dictionary)["counts"] as Dictionary
		_check(int(turned_counts["visible_primitives"]) == 33 and int(turned_counts["visible_lights"]) == 0, "turned medium instance preserves the quality budget")
		_check(turned.get_mount_transform().is_equal_approx(turned.global_transform), "arbitrary root transform remains the authoritative attachment transform")

	# Exercise the complete immutable configuration matrix, including the light
	# profile, without relying on any world-up orientation or production scene.
	var profiles: Array[int] = [
		StationStructuralServiceDressing.StructuralProfile.LIGHT,
		StationStructuralServiceDressing.StructuralProfile.STANDARD,
		StationStructuralServiceDressing.StructuralProfile.DEEP,
	]
	var orientations: Array[int] = [
		StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_X,
		StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y,
	]
	var expected_extents := {
		StationStructuralServiceDressing.StructuralProfile.LIGHT: Vector2(0.87, 0.66),
		StationStructuralServiceDressing.StructuralProfile.STANDARD: Vector2(1.13, 0.86),
		StationStructuralServiceDressing.StructuralProfile.DEEP: Vector2(1.39, 1.10),
	}
	var expected_mesh_extents := {
		StationStructuralServiceDressing.StructuralProfile.LIGHT: Vector2(0.8145, 0.6145),
		StationStructuralServiceDressing.StructuralProfile.STANDARD: Vector2(1.073, 0.8145),
		StationStructuralServiceDressing.StructuralProfile.DEEP: Vector2(1.3315, 1.0545),
	}
	for profile_value: int in profiles:
		for orientation_value: int in orientations:
			var matrix_instance := DRESSING_SCENE.instantiate() as StationStructuralServiceDressing
			_check(matrix_instance != null, "configuration matrix instance is typed")
			if matrix_instance == null:
				continue
			_check(
				matrix_instance.configure(8.0, profile_value, orientation_value),
				"profile %d orientation %d configures off-tree" % [profile_value, orientation_value]
			)
			matrix_instance.initial_quality = StationStructuralServiceDressing.DetailQuality.LOW
			root.add_child(matrix_instance)
			await process_frame
			var matrix_audit := matrix_instance.get_audit_report()
			_check(bool(matrix_audit["valid"]), "profile %d orientation %d passes full audit" % [profile_value, orientation_value])
			var matrix_footprint := matrix_instance.get_local_footprint()
			var profile_extents := expected_extents[profile_value] as Vector2
			var expected_footprint := AABB(
				Vector3(0.0, -4.0, 0.0),
				Vector3(profile_extents.x, 8.0, profile_extents.y)
			) if orientation_value == StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y else AABB(
				Vector3(-4.0, -profile_extents.x, 0.0),
				Vector3(8.0, profile_extents.x, profile_extents.y)
			)
			_check(matrix_footprint.is_equal_approx(expected_footprint), "profile %d orientation %d publishes its exact local mount envelope" % [profile_value, orientation_value])
			var mesh_extents := expected_mesh_extents[profile_value] as Vector2
			var expected_mesh_aabb := AABB(
				Vector3(0.0, -4.0, 0.0),
				Vector3(mesh_extents.x, 8.0, mesh_extents.y)
			) if orientation_value == StationStructuralServiceDressing.SegmentOrientation.ALONG_MOUNT_Y else AABB(
				Vector3(-4.0, -mesh_extents.x, 0.0),
				Vector3(8.0, mesh_extents.x, mesh_extents.y)
			)
			_check(
				_subtree_mesh_corner_aabb(matrix_instance).is_equal_approx(expected_mesh_aabb),
				"profile %d orientation %d has the exact expected transformed mesh-corner AABB"
				% [profile_value, orientation_value]
			)
			_check(
				_subtree_meshes_fit_footprint(matrix_instance, matrix_footprint),
				"profile %d orientation %d keeps every generated mesh on the outward side and inside its published footprint"
				% [profile_value, orientation_value]
			)
			var matrix_counts := (matrix_audit["performance"] as Dictionary)["counts"] as Dictionary
			_check(int(matrix_counts["visible_primitives"]) == 16 and int(matrix_counts["visible_lights"]) == 0, "profile %d orientation %d respects the low-quality budget" % [profile_value, orientation_value])
			var matrix_reference: WeakRef = weakref(matrix_instance)
			matrix_instance.queue_free()
			await process_frame
			await process_frame
			_check(matrix_reference.get_ref() == null, "profile %d orientation %d cleans up without retention" % [profile_value, orientation_value])

	# No mover or allocator appears after idle frames.
	var stable_node_count := int((dressing.get_performance_audit()["counts"] as Dictionary)["node_count"])
	var stable_center_transform := dressing.get_dressing_center_anchor().transform
	for _frame in 4:
		await process_frame
	_check(int((dressing.get_performance_audit()["counts"] as Dictionary)["node_count"]) == stable_node_count, "idle frames allocate no nodes")
	_check(dressing.get_dressing_center_anchor().transform.is_equal_approx(stable_center_transform), "idle frames cannot move static dressing")

	var fascia := dressing.get_node("PresentationRoot/StructuralCoreRoot/UpperFascia") as MeshInstance3D
	# The structural members are now chamfered ArrayMesh surfaces rather than raw
	# BoxMesh primitives, so the drift and winding mutations below rewrite the
	# same mesh resource in place through its surface arrays instead of through
	# BoxMesh.size and PrimitiveMesh.flip_faces. Both remain exact in-place
	# mutations of the identical resource instance the component built, which is
	# what the audit is being asked to reject.
	var fascia_mesh := fascia.mesh as ArrayMesh
	_check(fascia_mesh != null and fascia_mesh.get_surface_count() == 1, "structural fascia is a single-surface chamfered generated mesh")
	var original_fascia_surfaces: Variant = fascia_mesh.get("_surfaces")
	var original_fascia_arrays := fascia_mesh.surface_get_arrays(0)
	var shrunken_arrays := original_fascia_arrays.duplicate(true)
	var shrunken_vertices := shrunken_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	for vertex_index in shrunken_vertices.size():
		shrunken_vertices[vertex_index] = shrunken_vertices[vertex_index] * 0.001
	shrunken_arrays[Mesh.ARRAY_VERTEX] = shrunken_vertices
	_rewrite_only_surface(fascia_mesh, shrunken_arrays)
	_check(not bool(dressing.get_audit_report().valid), "audit rejects in-place structural mesh geometry drift")
	fascia_mesh.set("_surfaces", original_fascia_surfaces)
	var fascia_material := fascia.material_override as StandardMaterial3D
	var original_cull_mode := fascia_material.cull_mode
	fascia_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_check(not bool(dressing.get_audit_report().valid), "audit rejects in-place structural material drift")
	fascia_material.cull_mode = original_cull_mode
	var original_layers := fascia.layers
	fascia.layers = 0
	_check(not bool(dressing.get_audit_report().valid), "audit rejects a generated mesh removed from all render layers")
	fascia.layers = original_layers
	var reversed_arrays := original_fascia_arrays.duplicate(true)
	var forward_vertices := original_fascia_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var reversed_vertices := PackedVector3Array()
	reversed_vertices.resize(forward_vertices.size())
	for triangle_index in forward_vertices.size() / 3:
		reversed_vertices[triangle_index * 3] = forward_vertices[triangle_index * 3 + 2]
		reversed_vertices[triangle_index * 3 + 1] = forward_vertices[triangle_index * 3 + 1]
		reversed_vertices[triangle_index * 3 + 2] = forward_vertices[triangle_index * 3]
	reversed_arrays[Mesh.ARRAY_VERTEX] = reversed_vertices
	_rewrite_only_surface(fascia_mesh, reversed_arrays)
	_check(not bool(dressing.get_audit_report().valid), "audit rejects reversed generated mesh winding")
	fascia_mesh.set("_surfaces", original_fascia_surfaces)
	var original_cull_mask := task_light.light_cull_mask
	task_light.light_cull_mask = 0
	_check(not bool(dressing.get_audit_report().valid), "audit rejects a bounded task light removed from all render layers")
	task_light.light_cull_mask = original_cull_mask
	_check(bool(dressing.get_audit_report().valid), "restoring structural resources and task light restores the complete audit")

	var lifecycle_before := _presentation_snapshot(dressing)
	root.remove_child(dressing)
	dressing.set_dressing_enabled(false)
	var detached_quality := dressing.set_quality_level(
		StationStructuralServiceDressing.DetailQuality.LOW
	)
	_check(
		not dressing.is_inside_tree()
			and not detached_quality
			and _presentation_snapshot(dressing) == lifecycle_before,
		"detached direct dressing profile mutators leave retained presentation atomic"
	)
	root.add_child(dressing)
	dressing.set_dressing_enabled(false)
	var reentered_low := dressing.set_quality_level(
		StationStructuralServiceDressing.DetailQuality.LOW
	)
	var low_reentry := _presentation_snapshot(dressing)
	_check(
		dressing.is_inside_tree()
			and reentered_low
			and not bool(low_reentry.get("enabled", true))
			and int(low_reentry.get("quality", -1)) \
				== StationStructuralServiceDressing.DetailQuality.LOW
			and not bool(low_reentry.get("presentation_visible", true))
			and not bool(low_reentry.get("service_visible", true))
			and not bool(low_reentry.get("high_visible", true))
			and int(low_reentry.get("visible_primitives", -1)) == 0
			and int(low_reentry.get("visible_lights", -1)) == 0,
		"readded dressing accepts fresh live disable and low-detail presentation control"
	)
	dressing.set_dressing_enabled(true)
	var reentered_high := dressing.set_quality_level(
		StationStructuralServiceDressing.DetailQuality.HIGH
	)
	_check(
		reentered_high and _presentation_snapshot(dressing) == lifecycle_before,
		"fresh live re-entry restores the exact high-detail presentation contract"
	)

	var queued_before := _presentation_snapshot(dressing)
	dressing.queue_free()
	dressing.set_dressing_enabled(false)
	var queued_quality := dressing.set_quality_level(
		StationStructuralServiceDressing.DetailQuality.LOW
	)
	_check(
		dressing.is_inside_tree()
			and dressing.is_queued_for_deletion()
			and not queued_quality
			and _presentation_snapshot(dressing) == queued_before,
		"queued direct dressing profile mutators leave retained presentation atomic"
	)

	var dressing_reference: WeakRef = weakref(dressing)
	var turned_reference: WeakRef = weakref(turned) if turned != null else null
	if turned != null:
		turned.queue_free()
	dressing.queue_free()
	await process_frame
	await process_frame
	_check(dressing_reference.get_ref() == null, "primary dressing instance cleans up without retention")
	_check(turned_reference == null or turned_reference.get_ref() == null, "turned dressing instance cleans up without retention")
	_finish()


func _subtree_has_only_allowed_static_nodes(node: Node) -> bool:
	if not (
		node is StationStructuralServiceDressing
		or node is Node3D
		or node is Marker3D
		or node is MeshInstance3D
		or node is OmniLight3D
	):
		return false
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		return false
	if node is AnimationPlayer or node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		return false
	for child in node.get_children():
		if not _subtree_has_only_allowed_static_nodes(child):
			return false
	return true


func _presentation_snapshot(dressing: StationStructuralServiceDressing) -> Dictionary:
	var presentation_root := dressing.get_node_or_null(^"PresentationRoot") as Node3D
	var service_root := dressing.get_node_or_null(
		^"PresentationRoot/ServiceDetailRoot"
	) as Node3D
	var high_root := dressing.get_node_or_null(
		^"PresentationRoot/HighDetailRoot"
	) as Node3D
	var counts := dressing.get_performance_audit().get("counts", {}) as Dictionary
	return {
		"enabled": dressing.is_dressing_enabled(),
		"quality": dressing.get_quality_level(),
		"presentation_visible": presentation_root.visible if presentation_root != null else false,
		"service_visible": service_root.visible if service_root != null else false,
		"high_visible": high_root.visible if high_root != null else false,
		"visible_primitives": int(counts.get("visible_primitives", -1)),
		"visible_lights": int(counts.get("visible_lights", -1)),
	}.duplicate(true)


func _subtree_meshes_fit_footprint(
	dressing: StationStructuralServiceDressing,
	footprint: AABB
) -> bool:
	var inverse := dressing.global_transform.affine_inverse()
	var padded := footprint.grow(0.002)
	for candidate in dressing.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_aabb := _transform_aabb(
			inverse * mesh_instance.global_transform,
			mesh_instance.mesh.get_aabb()
		)
		if not padded.encloses(local_aabb):
			return false
	for candidate in dressing.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			return false
		var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
		if authored_transforms.size() != batch.multimesh.instance_count:
			return false
		for instance_index in authored_transforms.size():
			var local_aabb := _transform_aabb(
				inverse * batch.global_transform * (authored_transforms[instance_index] as Transform3D),
				batch.multimesh.mesh.get_aabb()
			)
			if not padded.encloses(local_aabb):
				return false
	return true


func _audit_rejects_live_structural_divergence(
		dressing: StationStructuralServiceDressing
	) -> bool:
	var audit_report := dressing.get_audit_report()
	return (
		not bool(audit_report["valid"])
		and "live structural authoring configuration diverges from immutable build snapshot"
		in (audit_report["errors"] as PackedStringArray)
	)


func _has_error(audit: Dictionary, expected: String) -> bool:
	return (audit.get("errors", PackedStringArray()) as PackedStringArray).has(expected)


## Rewrites the one surface of a generated mesh in place, on the same resource
## instance the component built, so the audit sees drift rather than a swapped
## resource. Restoring goes back through the saved `_surfaces` snapshot instead
## of this helper: an arrays round trip is not byte-identical to the committed
## surface, so re-adding the original arrays would leave a permanently drifted
## fingerprint and the later restore assertion would never be able to pass.
func _rewrite_only_surface(mesh: ArrayMesh, arrays: Array) -> void:
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _subtree_mesh_corner_aabb(dressing: StationStructuralServiceDressing) -> AABB:
	var inverse := dressing.global_transform.affine_inverse()
	var combined := AABB()
	var has_corner := false
	for candidate in dressing.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var mesh_to_component := inverse * mesh_instance.global_transform
		var mesh_aabb := mesh_instance.mesh.get_aabb()
		for x_index in 2:
			for y_index in 2:
				for z_index in 2:
					var corner := mesh_aabb.position + Vector3(
						mesh_aabb.size.x * float(x_index),
						mesh_aabb.size.y * float(y_index),
						mesh_aabb.size.z * float(z_index)
					)
					var transformed_corner := mesh_to_component * corner
					if not has_corner:
						combined = AABB(transformed_corner, Vector3.ZERO)
						has_corner = true
					else:
						combined = combined.expand(transformed_corner)
	for candidate in dressing.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var mesh_aabb := batch.multimesh.mesh.get_aabb()
		var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
		for instance_index in authored_transforms.size():
			var mesh_to_component := (
				inverse * batch.global_transform * (authored_transforms[instance_index] as Transform3D)
			)
			for x_index in 2:
				for y_index in 2:
					for z_index in 2:
						var corner := mesh_aabb.position + Vector3(
							mesh_aabb.size.x * float(x_index),
							mesh_aabb.size.y * float(y_index),
							mesh_aabb.size.z * float(z_index)
						)
						var transformed_corner := mesh_to_component * corner
						if not has_corner:
							combined = AABB(transformed_corner, Vector3.ZERO)
							has_corner = true
						else:
							combined = combined.expand(transformed_corner)
	return combined


func _transform_aabb(transform_value: Transform3D, bounds: AABB) -> AABB:
	var first := transform_value * bounds.position
	var transformed := AABB(first, Vector3.ZERO)
	for x_index in 2:
		for y_index in 2:
			for z_index in 2:
				var corner := bounds.position + Vector3(
					bounds.size.x * float(x_index),
					bounds.size.y * float(y_index),
					bounds.size.z * float(z_index)
				)
				transformed = transformed.expand(transform_value * corner)
	return transformed


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_STRUCTURAL_SERVICE_DRESSING_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_STRUCTURAL_SERVICE_DRESSING_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
