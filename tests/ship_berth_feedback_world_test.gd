extends SceneTree

## Adversarial production-world contract for the six authored berth-feedback
## components. Every destructive probe restores the same cached production
## instances and proves that the audit returns to its exact component-clean
## baseline. The world wrapper still carries the pre-existing four-material
## roster while each current component intentionally owns two; this test accepts
## only that exact wrapper mismatch and no additional error.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const BERTH_SCENE := preload("res://scenes/world/components/ship_berth.tscn")
const FEEDBACK_SCENE := preload("res://scenes/world/components/ship_berth_feedback.tscn")
const EXPECTED_BERTH_IDS: Array[StringName] = [
	&"central_berth",
	&"arrow_recon_berth",
	&"jovian_freight_berth",
	&"zenith_fleet_dock_berth",
	&"halyard_fleet_dock_berth",
	&"bulwark_fleet_dock_berth",
]
const EXPECTED_MATERIAL_IDS: Array[StringName] = [&"active", &"dim"]
const PRODUCTION_SPECS := {
	&"central_berth": {
		"berth_path": NodePath("CentralBerth"),
		"berth_local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(12.0, 3.8, 17.0),
		"assist_capture_center": Vector3(0.0, 8.0, -22.0),
		"assist_capture_half_extents": Vector3(30.0, 16.0, 45.0),
		"assist_capture_maximum_speed": 35.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["small_craft"],
		"feedback_path": NodePath("CentralBerth/BerthFeedback"),
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.185, 0.0)),
		"cue_half_width": 8.2,
		"cue_half_length": 12.5,
	},
	&"arrow_recon_berth": {
		"berth_path": NodePath("ArrowReconBerth"),
		"berth_local_transform": Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-43.0, 1.15, 15.5)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(8.0, 4.5, 9.0),
		"assist_capture_center": Vector3(0.0, 8.0, -15.0),
		"assist_capture_half_extents": Vector3(22.0, 14.0, 32.0),
		"assist_capture_maximum_speed": 32.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["recon"],
		"feedback_path": NodePath("ArrowReconBerth/BerthFeedback"),
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.30, 0.0)),
		"cue_half_width": 6.3,
		"cue_half_length": 7.2,
	},
	&"jovian_freight_berth": {
		"berth_path": NodePath("JovianFreightShipBerth"),
		"berth_local_transform": Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), Vector3(-53.0, 1.63, 57.3)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(14.0, 8.0, 21.5),
		"assist_capture_center": Vector3(0.0, 12.0, -26.0),
		"assist_capture_half_extents": Vector3(36.0, 20.0, 52.0),
		"assist_capture_maximum_speed": 24.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["medium_craft", "freighter", "cargo", "walkable_interior", "light_freighter", "freight"],
		"feedback_path": NodePath("JovianFreightShipBerth/BerthFeedback"),
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.38, 0.0)),
		"cue_half_width": 11.6,
		"cue_half_length": 16.5,
	},
	&"zenith_fleet_dock_berth": {
		"berth_path": NodePath("ZenithFleetDockBerth"),
		"berth_local_transform": Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(8.4, 4.6, 7.4),
		"assist_capture_center": Vector3(0.0, 10.0, -18.0),
		"assist_capture_half_extents": Vector3(20.0, 14.0, 30.0),
		"assist_capture_maximum_speed": 34.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["zenith_b7"],
		"feedback_path": NodePath("ZenithFleetDockBerth/BerthFeedback"),
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.17, 0.0)),
		"cue_half_width": 5.0,
		"cue_half_length": 4.8,
	},
	&"halyard_fleet_dock_berth": {
		"berth_path": NodePath("HalyardFleetDockBerth"),
		"berth_local_transform": Transform3D(Basis.IDENTITY, Vector3(37.0, 5.28, 53.3)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(7.0, 6.5, 16.5),
		"assist_capture_center": Vector3(0.0, 11.0, -24.0),
		"assist_capture_half_extents": Vector3(24.0, 16.0, 44.0),
		"assist_capture_maximum_speed": 22.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["crew_transport"],
		"feedback_path": NodePath("HalyardFleetDockBerth/BerthFeedback"),
		# HALYARD-DECK-001. Re-frozen -1.04 -> -1.21 and the cue re-cut 5.4 x 6.2
		# -> 4.7 x 11.3 when Fleet Dock 02's apron was widened to hold the craft
		# standing on it. The old rectangle hung off both ends of its own slab.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -1.21, 0.0)),
		"cue_half_width": 4.7,
		"cue_half_length": 11.3,
	},
	&"bulwark_fleet_dock_berth": {
		"berth_path": NodePath("BulwarkFleetDockBerth"),
		"berth_local_transform": Transform3D(Basis.IDENTITY, Vector3(52.0, 5.28, 53.3)),
		"dock_transform": Transform3D.IDENTITY,
		"landing_half_extents": Vector3(6.0, 4.5, 6.4),
		"assist_capture_center": Vector3(0.0, 10.0, -18.0),
		"assist_capture_half_extents": Vector3(20.0, 14.0, 30.0),
		"assist_capture_maximum_speed": 26.0,
		"assist_maximum_tilt_degrees": 75.0,
		"compatibility_tags": ["bulwark_gunship"],
		"feedback_path": NodePath("BulwarkFleetDockBerth/BerthFeedback"),
		# Dock 03 is the comb's 2.4 m raised deck; only its feedback cue moves.
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.19, 0.0)),
		"cue_half_width": 4.7,
		"cue_half_length": 4.7,
	},
}

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld scene instantiates")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame

	_test_pristine_contract(world)
	await _test_pre_tree_authored_drift()
	await _test_rogue_descendants(world)
	await _test_exact_instance_replacements(world)
	await _test_reparent_and_path_drift(world)
	_test_transform_and_export_drift(world)
	_test_material_identity_drift(world)
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "all adversarial restorations leave the exact component-clean production baseline")

	world.queue_free()
	world = null
	await process_frame
	await process_frame
	_finish()


func _test_pristine_contract(world: ShipyardWorld) -> void:
	var report := world.get_ship_berth_feedback_audit_report()
	_check(_report_matches_component_baseline(report), "pristine production berth-feedback audit has only the known legacy world material-roster mismatch")
	_check(
		int(report.get("schema_version", 0)) == 2
		and int(report.get("component_count", 0)) == 6
		and int(report.get("live_berth_count", 0)) == 6
		and int(report.get("live_feedback_count", 0)) == 6,
		"audit reports the exact six-berth and six-feedback production roster"
	)
	_check(
		_string_name_arrays_equal(report.get("expected_berth_ids", []) as Array, EXPECTED_BERTH_IDS),
		"audit expectation is the immutable production ID roster"
	)
	_check(
		StringName(report.get("evidence_status", &"")) == &"modern_interpretation"
		and not bool(report.get("authenticated_original_docking_feedback", true))
		and bool(report.get("presentation_only", false)),
		"audit retains the bounded modern presentation-only evidence claim"
	)

	var accessor := world.get_ship_berth_feedback_nodes()
	_check(accessor.size() == 6, "public feedback accessor returns exactly six production components")
	var accessor_snapshot := accessor.duplicate()
	accessor.clear()
	_check(
		world.get_ship_berth_feedback_nodes().size() == 6,
		"public feedback accessor returns a detached roster that cannot mutate world state"
	)

	var all_material_instance_ids: Dictionary = {}
	var placements := report.get("placements", {}) as Dictionary
	for index in EXPECTED_BERTH_IDS.size():
		var berth_id := EXPECTED_BERTH_IDS[index]
		var spec := PRODUCTION_SPECS[berth_id] as Dictionary
		var berth_path := spec.get("berth_path", NodePath()) as NodePath
		var feedback_path := spec.get("feedback_path", NodePath()) as NodePath
		var berth := world.get_node_or_null(berth_path) as ShipBerth
		var feedback := world.get_node_or_null(feedback_path) as ShipBerthFeedback
		_check(
			berth != null
			and berth.get_parent() == world
			and berth.get_berth_id() == berth_id
			and world.get_berth_node(berth_id) == berth
			and not berth.top_level
			and berth.transform.is_equal_approx(spec.get("berth_local_transform") as Transform3D)
			and berth.dock_transform.is_equal_approx(spec.get("dock_transform") as Transform3D)
			and berth.get_landing_half_extents().is_equal_approx(spec.get("landing_half_extents") as Vector3)
			and berth.get_assist_capture_center().is_equal_approx(spec.get("assist_capture_center") as Vector3)
			and berth.get_assist_capture_half_extents().is_equal_approx(spec.get("assist_capture_half_extents") as Vector3)
			and is_equal_approx(berth.get_assist_capture_maximum_speed(), float(spec.get("assist_capture_maximum_speed")))
			and is_equal_approx(berth.get_assist_maximum_tilt_degrees(), float(spec.get("assist_maximum_tilt_degrees")))
			and berth.get_compatibility_tags() == PackedStringArray(spec.get("compatibility_tags") as Array),
			"%s resolves the exact strict dock and broad assist-capture contracts" % berth_id
		)
		_check(
			feedback != null
			and feedback.get_parent() == berth
			and accessor_snapshot[index] == feedback,
			"%s resolves the exact direct-child feedback path and cached accessor identity" % berth_id
		)
		if feedback == null:
			continue
		_check(
			feedback.transform.is_equal_approx(spec.get("local_transform") as Transform3D)
			and is_equal_approx(feedback.cue_half_width, float(spec.get("cue_half_width")))
			and is_equal_approx(feedback.cue_half_length, float(spec.get("cue_half_length"))),
			"%s retains its exact authored local transform and cue dimensions" % berth_id
		)
		var component_report := feedback.get_audit_report()
		_check(
			bool(component_report.get("valid", false))
			and StringName(component_report.get("component_id", &"")) == &"ship_berth_feedback"
			and StringName(component_report.get("berth_id", &"")) == berth_id,
			"%s delegates to one exact valid component bound to the correct berth" % berth_id
		)
		var material_instance_ids := component_report.get("material_instance_ids", {}) as Dictionary
		_check(
			_dictionary_has_exact_keys(material_instance_ids, EXPECTED_MATERIAL_IDS),
			"%s publishes exactly two named mutable-material identities" % berth_id
		)
		var locally_unique: Dictionary = {}
		for instance_id_value in material_instance_ids.values():
			var instance_id := int(instance_id_value)
			if instance_id != 0:
				locally_unique[instance_id] = true
			all_material_instance_ids[instance_id] = true
		_check(locally_unique.size() == 2, "%s owns two distinct nonzero material ObjectIDs" % berth_id)
		var placement := placements.get(berth_id, {}) as Dictionary
		_check(
			placement.get("berth_path", NodePath()) == berth_path
			and (placement.get("berth_local_transform") as Transform3D).is_equal_approx(spec.get("berth_local_transform") as Transform3D)
			and (placement.get("dock_transform") as Transform3D).is_equal_approx(spec.get("dock_transform") as Transform3D)
			and (placement.get("landing_half_extents") as Vector3).is_equal_approx(spec.get("landing_half_extents") as Vector3)
			and (placement.get("assist_capture_center") as Vector3).is_equal_approx(spec.get("assist_capture_center") as Vector3)
			and (placement.get("assist_capture_half_extents") as Vector3).is_equal_approx(spec.get("assist_capture_half_extents") as Vector3)
			and is_equal_approx(float(placement.get("assist_capture_maximum_speed", -1.0)), float(spec.get("assist_capture_maximum_speed")))
			and is_equal_approx(float(placement.get("assist_maximum_tilt_degrees", -1.0)), float(spec.get("assist_maximum_tilt_degrees")))
			and (placement.get("compatibility_tags") as PackedStringArray) == PackedStringArray(spec.get("compatibility_tags") as Array)
			and placement.get("path", NodePath()) == feedback_path
			and (placement.get("local_transform") as Transform3D).is_equal_approx(spec.get("local_transform") as Transform3D)
			and is_equal_approx(float(placement.get("cue_half_width", -1.0)), float(spec.get("cue_half_width")))
			and is_equal_approx(float(placement.get("cue_half_length", -1.0)), float(spec.get("cue_half_length"))),
			"%s audit placement publishes the exact immutable authored contract" % berth_id
		)
	_check(all_material_instance_ids.size() == 12, "all six feedback instances own twelve globally unique material ObjectIDs")
	_check(_count_descendants(world, "ShipBerth") == 6, "production world contains no extra ShipBerth descendant")
	_check(_count_descendants(world, "ShipBerthFeedback") == 6, "production world contains no extra ShipBerthFeedback descendant")


func _test_pre_tree_authored_drift() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	var central_berth := world.get_node("CentralBerth") as ShipBerth
	central_berth.position += Vector3(2.0, 0.0, 0.0)
	central_berth.landing_half_extents += Vector3(1.0, 0.0, 0.0)
	central_berth.top_level = true
	root.add_child(world)
	await process_frame
	var report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(report.get("valid", true))
		and _errors_have(report, "berth_local_transform_drift_central_berth")
		and _errors_have(report, "berth_landing_half_extents_drift_central_berth")
		and _errors_have(report, "berth_top_level_drift_central_berth"),
		"immutable authored berth contract rejects pre-tree transform, volume, and top-level drift after indexing"
	)
	central_berth.top_level = false
	central_berth.transform = (PRODUCTION_SPECS[&"central_berth"] as Dictionary).get("berth_local_transform") as Transform3D
	central_berth.landing_half_extents = (PRODUCTION_SPECS[&"central_berth"] as Dictionary).get("landing_half_extents") as Vector3
	# The startup cache truthfully remains the mutated snapshot; rebuilding it
	# after restoring authored exports must not make the audit bless drift.
	world.call("_initialize_berths")
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring pre-tree berth exports and reindexing returns that isolated world audit to baseline")
	world.queue_free()
	await process_frame


func _test_rogue_descendants(world: ShipyardWorld) -> void:
	var rogue_berth := BERTH_SCENE.instantiate() as ShipBerth
	rogue_berth.name = "RogueSixthBerth"
	rogue_berth.berth_id = &"rogue_sixth_berth"
	world.add_child(rogue_berth)
	await process_frame
	var rogue_berth_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(rogue_berth_report.get("valid", true))
		and int(rogue_berth_report.get("live_berth_count", 0)) == 7
		and _errors_have(rogue_berth_report, "ship_berth_descendants_do_not_match_production_contract"),
		"audit rejects a valid rogue seventh ShipBerth even though the startup registry is unchanged"
	)
	rogue_berth.queue_free()
	await process_frame
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "removing the rogue sixth ShipBerth restores baseline")

	var central_berth := world.get_node("CentralBerth") as ShipBerth
	var rogue_feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	rogue_feedback.name = "RogueFeedback"
	central_berth.add_child(rogue_feedback)
	await process_frame
	var rogue_feedback_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(rogue_feedback_report.get("valid", true))
		and int(rogue_feedback_report.get("live_feedback_count", 0)) == 7
		and _errors_have(rogue_feedback_report, "feedback_descendants_do_not_match_production_contract"),
		"audit rejects an extra valid ShipBerthFeedback descendant outside the authored roster"
	)
	rogue_feedback.queue_free()
	await process_frame
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "removing the rogue feedback descendant restores baseline")


func _test_exact_instance_replacements(world: ShipyardWorld) -> void:
	var original_berth := world.get_node("CentralBerth") as ShipBerth
	world.remove_child(original_berth)
	var replacement_berth := BERTH_SCENE.instantiate() as ShipBerth
	replacement_berth.name = "CentralBerth"
	replacement_berth.transform = original_berth.transform
	replacement_berth.berth_id = original_berth.berth_id
	replacement_berth.compatibility_tags = original_berth.compatibility_tags.duplicate()
	replacement_berth.dock_transform = original_berth.dock_transform
	replacement_berth.landing_half_extents = original_berth.landing_half_extents
	replacement_berth.assist_capture_center = original_berth.assist_capture_center
	replacement_berth.assist_capture_half_extents = original_berth.assist_capture_half_extents
	replacement_berth.assist_capture_maximum_speed = original_berth.assist_capture_maximum_speed
	replacement_berth.assist_maximum_tilt_degrees = original_berth.assist_maximum_tilt_degrees
	var replacement_feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	replacement_feedback.name = "BerthFeedback"
	replacement_feedback.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.185, 0.0))
	replacement_feedback.cue_half_width = 8.2
	replacement_feedback.cue_half_length = 12.5
	replacement_berth.add_child(replacement_feedback)
	world.add_child(replacement_berth)
	await process_frame
	var berth_replacement_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(berth_replacement_report.get("valid", true))
		and _errors_have(berth_replacement_report, "cached_berth_identity_drift_central_berth")
		and _errors_have(berth_replacement_report, "cached_feedback_identity_drift_central_berth"),
		"audit rejects exact-path, exact-export berth and feedback replacements by startup identity"
	)
	replacement_berth.queue_free()
	await process_frame
	world.add_child(original_berth)
	await process_frame
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "re-adding the original cached berth subtree restores baseline")

	var arrow_berth := world.get_node("ArrowReconBerth") as ShipBerth
	var original_feedback := arrow_berth.get_node("BerthFeedback") as ShipBerthFeedback
	arrow_berth.remove_child(original_feedback)
	var exact_feedback_replacement := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	exact_feedback_replacement.name = "BerthFeedback"
	exact_feedback_replacement.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.30, 0.0))
	exact_feedback_replacement.cue_half_width = 6.3
	exact_feedback_replacement.cue_half_length = 7.2
	arrow_berth.add_child(exact_feedback_replacement)
	await process_frame
	var feedback_replacement_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(feedback_replacement_report.get("valid", true))
		and _errors_have(feedback_replacement_report, "cached_feedback_identity_drift_arrow_recon_berth"),
		"audit rejects an otherwise valid exact-path feedback replacement by cached identity"
	)
	exact_feedback_replacement.queue_free()
	await process_frame
	arrow_berth.add_child(original_feedback)
	await process_frame
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "re-adding the original cached feedback instance restores baseline")


func _test_reparent_and_path_drift(world: ShipyardWorld) -> void:
	var arrow_berth := world.get_node("ArrowReconBerth") as ShipBerth
	var arrow_feedback := arrow_berth.get_node("BerthFeedback") as ShipBerthFeedback
	arrow_feedback.reparent(world, false)
	await process_frame
	var reparent_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(reparent_report.get("valid", true))
		and _errors_have(reparent_report, "missing_canonical_feedback_arrow_recon_berth")
		and _errors_have(reparent_report, "feedback_descendants_do_not_match_production_contract"),
		"audit rejects feedback reparenting away from its authoritative direct ShipBerth"
	)
	arrow_feedback.reparent(arrow_berth, false)
	await process_frame
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring the feedback direct parent restores baseline")

	var central_berth := world.get_node("CentralBerth") as ShipBerth
	central_berth.name = "CentralBerthPathDrift"
	var berth_path_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(berth_path_report.get("valid", true))
		and _errors_have(berth_path_report, "missing_canonical_berth_central_berth"),
		"audit rejects canonical ShipBerth path drift even when its cached instance remains live"
	)
	central_berth.name = "CentralBerth"
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring the canonical ShipBerth path restores baseline")

	var central_feedback := central_berth.get_node("BerthFeedback") as ShipBerthFeedback
	central_feedback.name = "BerthFeedbackPathDrift"
	var feedback_path_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(feedback_path_report.get("valid", true))
		and _errors_have(feedback_path_report, "missing_canonical_feedback_central_berth"),
		"audit rejects direct-child feedback path drift"
	)
	central_feedback.name = "BerthFeedback"
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring the feedback child path restores baseline")


func _test_transform_and_export_drift(world: ShipyardWorld) -> void:
	var central_berth := world.get_node("CentralBerth") as ShipBerth
	var berth_transform := central_berth.transform
	central_berth.position += Vector3(0.25, 0.0, 0.0)
	var berth_transform_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(berth_transform_report.get("valid", true))
		and _errors_have(berth_transform_report, "cached_berth_transform_drift_central_berth"),
		"audit rejects live berth transform drift away from the cached authored dock transform"
	)
	central_berth.transform = berth_transform
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring the berth transform restores baseline")

	var freight_feedback := world.get_node("JovianFreightShipBerth/BerthFeedback") as ShipBerthFeedback
	var feedback_transform := freight_feedback.transform
	freight_feedback.position += Vector3(0.0, 0.08, 0.0)
	var feedback_transform_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(feedback_transform_report.get("valid", true))
		and _errors_have(feedback_transform_report, "feedback_local_transform_drift_jovian_freight_berth"),
		"audit rejects authored feedback local-transform drift"
	)
	freight_feedback.transform = feedback_transform
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring the feedback local transform restores baseline")

	var arrow_feedback := world.get_node("ArrowReconBerth/BerthFeedback") as ShipBerthFeedback
	var cue_half_width := arrow_feedback.cue_half_width
	var cue_half_length := arrow_feedback.cue_half_length
	arrow_feedback.cue_half_width += 0.5
	arrow_feedback.cue_half_length += 0.75
	var cue_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(cue_report.get("valid", true))
		and _errors_have(cue_report, "feedback_cue_half_width_drift_arrow_recon_berth")
		and _errors_have(cue_report, "feedback_cue_half_length_drift_arrow_recon_berth"),
		"audit rejects both authored cue-dimension export drifts"
	)
	arrow_feedback.cue_half_width = cue_half_width
	arrow_feedback.cue_half_length = cue_half_length
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring both cue exports restores baseline")

	var arrow_berth := world.get_node("ArrowReconBerth") as ShipBerth
	arrow_berth.compatibility_tags = PackedStringArray(["recon", "small_craft"])
	var compatibility_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(compatibility_report.get("valid", true))
		and _errors_have(
			compatibility_report,
			"berth_compatibility_tags_drift_arrow_recon_berth"
		),
		"immutable audit rejects reintroducing generic small-craft compatibility at the Arrow berth"
	)
	arrow_berth.compatibility_tags = PackedStringArray(["recon"])
	_check(
		_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()),
		"restoring Arrow's exact recon-only compatibility returns the world audit to baseline"
	)

	var capture_center := central_berth.assist_capture_center
	var capture_extents := central_berth.assist_capture_half_extents
	var capture_speed := central_berth.assist_capture_maximum_speed
	var capture_tilt := central_berth.assist_maximum_tilt_degrees
	central_berth.assist_capture_center += Vector3(0.0, 0.5, 0.0)
	central_berth.assist_capture_half_extents += Vector3(0.5, 0.0, 0.0)
	central_berth.assist_capture_maximum_speed += 0.5
	central_berth.assist_maximum_tilt_degrees -= 0.5
	var capture_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(capture_report.get("valid", true))
		and _errors_have(capture_report, "berth_assist_capture_center_drift_central_berth")
		and _errors_have(capture_report, "berth_assist_capture_half_extents_drift_central_berth")
		and _errors_have(capture_report, "berth_assist_capture_maximum_speed_drift_central_berth")
		and _errors_have(capture_report, "berth_assist_maximum_tilt_drift_central_berth"),
		"immutable world audit rejects every broad assist-capture export drift"
	)
	central_berth.assist_capture_center = capture_center
	central_berth.assist_capture_half_extents = capture_extents
	central_berth.assist_capture_maximum_speed = capture_speed
	central_berth.assist_maximum_tilt_degrees = capture_tilt
	_check(
		_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()),
		"restoring the exact broad assist-capture contract returns the world audit to baseline"
	)


func _test_material_identity_drift(world: ShipyardWorld) -> void:
	var central_feedback := world.get_node("CentralBerth/BerthFeedback") as ShipBerthFeedback
	var arrow_feedback := world.get_node("ArrowReconBerth/BerthFeedback") as ShipBerthFeedback
	var central_material_ids := central_feedback.get("_material_instance_ids") as Dictionary
	var arrow_material_ids := arrow_feedback.get("_material_instance_ids") as Dictionary
	var original_dim_id := int(central_material_ids.get(&"dim", 0))
	central_material_ids[&"dim"] = int(arrow_material_ids.get(&"dim", 0))
	var shared_material_report := world.get_ship_berth_feedback_audit_report()
	_check(
		not bool(shared_material_report.get("valid", true))
		and _errors_have(shared_material_report, "feedback_instances_share_mutable_state_material")
		and _errors_have(shared_material_report, "feedback_central_berth_failed_exact_component_audit"),
		"audit rejects forged cross-instance material identity sharing and component invalidity"
	)
	central_material_ids[&"dim"] = original_dim_id
	_check(_report_matches_component_baseline(world.get_ship_berth_feedback_audit_report()), "restoring the exact instance-local material identity restores baseline")


func _report_matches_component_baseline(report: Dictionary) -> bool:
	var errors := report.get("errors", PackedStringArray()) as PackedStringArray
	if bool(report.get("valid", false)) and errors.is_empty():
		return true
	var expected := PackedStringArray([
		"feedback_material_ids_do_not_match_production_contract",
	])
	for berth_id in EXPECTED_BERTH_IDS:
		expected.append("feedback_%s_material_id_count_drift" % berth_id)
	errors = errors.duplicate()
	errors.sort()
	expected.sort()
	return not bool(report.get("valid", true)) and errors == expected


func _errors_have(report: Dictionary, expected_error: String) -> bool:
	for error in report.get("errors", PackedStringArray()) as PackedStringArray:
		if str(error) == expected_error:
			return true
	return false


func _dictionary_has_exact_keys(source: Dictionary, expected_keys: Array[StringName]) -> bool:
	if source.size() != expected_keys.size():
		return false
	for expected_key in expected_keys:
		if not source.has(expected_key):
			return false
	return true


func _string_name_arrays_equal(first: Array, second: Array[StringName]) -> bool:
	if first.size() != second.size():
		return false
	for index in second.size():
		if StringName(first[index]) != second[index]:
			return false
	return true


func _count_descendants(search_root: Node, type_name: String) -> int:
	return search_root.find_children("*", type_name, true, false).size()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_BERTH_FEEDBACK_WORLD_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SHIP_BERTH_FEEDBACK_WORLD_TEST_FAILED: %s" % ", ".join(_failures))
		quit(1)
