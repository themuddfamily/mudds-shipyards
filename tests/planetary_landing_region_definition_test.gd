extends SceneTree

const DefinitionScript := preload(
	"res://scripts/world/definitions/planetary_landing_region_definition.gd"
)

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	_run()


func _run() -> void:
	_test_valid_identity_frame_and_geometry()
	_test_stable_identity_and_frame_bounds()
	_test_body_radius_and_surface_envelope()
	_test_approach_and_touchdown_integrity()
	_test_tags_limits_egress_and_evidence()
	_test_detached_snapshot_audit_and_zero_authority()
	_finish()


func _test_valid_identity_frame_and_geometry() -> void:
	var definition := DefinitionScript.new()
	var audit := definition.audit()
	var snapshot := audit.get("snapshot", {}) as Dictionary
	var identity := snapshot.get("identity", {}) as Dictionary
	var envelope := snapshot.get("body_surface_envelope", {}) as Dictionary
	var frame := snapshot.get("body_local_frame", {}) as Dictionary
	var corridors := snapshot.get("approach_corridors", []) as Array
	var pads := snapshot.get("touchdown_pads", []) as Array
	var anchors := snapshot.get("surface_route_anchors", []) as Array
	_check(definition is Resource, "landing-region definition is a reusable Resource")
	_check(definition.is_definition_valid(), "the complete default body-local contract validates")
	_check(
		identity.get("world_id") == &"example_planetary_world"
			and identity.get("body_id") == &"example_primary_body"
			and identity.get("region_id") == &"example_landing_region",
		"world, body, and region identity are independently stable"
	)
	_check(
		frame.get("center_m") == Vector3(0.0, 120000.0, 0.0)
			and frame.get("basis") == Basis.IDENTITY
			and frame.get("coordinate_origin") == &"body_center_scene_root"
			and frame.get("surface_normal_axis") == &"positive_y",
		"body-centred scene-root position and right-handed tangent basis are explicit"
	)
	_check(
		envelope.get("datum") == &"sea_level"
			and float(envelope.get("body_radius_m", -1.0)) == 120000.0
			and float(envelope.get("minimum_surface_radius_m", -1.0)) == 117500.0
			and float(envelope.get("maximum_surface_radius_m", -1.0)) == 128500.0
			and float(envelope.get("region_center_radius_m", -1.0)) == 120000.0,
		"sea-level radius and elevation envelope resolve the canonical 120 km centre"
	)
	var corridor := corridors[0] as Dictionary
	var pad := pads[0] as Dictionary
	_check(
		corridor.get("corridor_id") == &"primary_approach"
			and corridor.get("target_pad_id") == &"pad_alpha"
			and corridor.get("half_extents_m") == Vector3(45.0, 60.0, 300.0)
			and corridor.get("volume_shape") == &"oriented_box"
			and corridor.get("inbound_axis") == &"negative_z",
		"the approach volume has exact body-frame-relative geometry and target"
	)
	_check(
		pad.get("pad_id") == &"pad_alpha"
			and pad.get("size_m") == Vector2(28.0, 32.0)
			and pad.get("egress_anchor_id") == &"pad_alpha_egress",
		"touchdown geometry maps to one named on-foot egress"
	)
	_check(
		anchors.size() == 2
			and (anchors[0] as Dictionary).get("anchor_id") == &"pad_alpha_egress"
			and (anchors[1] as Dictionary).get("anchor_id") == &"surface_staging_gate",
		"surface-route anchors retain declared deterministic order"
	)
	_check(audit.get("unit_system") == &"game_scale_si_body_local", "the audit freezes body-local SI units")


func _test_stable_identity_and_frame_bounds() -> void:
	for field_name in [&"world_id", &"body_id", &"region_id"]:
		var invalid_id := DefinitionScript.new()
		invalid_id.set(field_name, &"Invalid ID")
		_check(
			not invalid_id.is_definition_valid()
				and _has_error(invalid_id.get_validation_errors(), String(field_name)),
			"%s rejects unstable identity" % field_name
		)
	var leading_digit_id := DefinitionScript.new()
	leading_digit_id.region_id = &"1_invalid_region"
	_check(
		not leading_digit_id.is_definition_valid()
			and _has_error(
				leading_digit_id.get_validation_errors(),
				"start with a lowercase letter"
			),
		"every stable ID requires a lowercase letter in its first position"
	)
	var non_finite_center := DefinitionScript.new()
	non_finite_center.body_local_center_m = Vector3(NAN, 0.0, 0.0)
	_check(not non_finite_center.is_definition_valid(), "non-finite body-local centre fails closed")
	var unbounded_center := DefinitionScript.new()
	unbounded_center.body_local_center_m = Vector3(
		DefinitionScript.MAX_BODY_LOCAL_COORDINATE_M * 2.0,
		0.0,
		0.0
	)
	_check(not unbounded_center.is_definition_valid(), "body-local centre obeys its hard coordinate bound")
	var scaled_basis := DefinitionScript.new()
	scaled_basis.body_local_basis = Basis.from_scale(Vector3(1.0, 2.0, 1.0))
	_check(not scaled_basis.is_definition_valid(), "region basis rejects scale and non-orthonormal axes")
	var reflected_basis := DefinitionScript.new()
	reflected_basis.body_local_basis = Basis(Vector3.LEFT, Vector3.UP, Vector3.BACK)
	_check(not reflected_basis.is_definition_valid(), "region basis rejects a reflected frame")
	var non_finite_basis := DefinitionScript.new()
	non_finite_basis.body_local_basis = Basis(Vector3(NAN, 0.0, 0.0), Vector3.UP, Vector3.BACK)
	_check(not non_finite_basis.is_definition_valid(), "region basis rejects non-finite axes")
	var sideways_basis := DefinitionScript.new()
	sideways_basis.body_local_basis = Basis(Vector3.RIGHT, deg_to_rad(90.0))
	_check(
		not bool(sideways_basis.audit().valid)
			and _has_error(sideways_basis.get_validation_errors(), "align outward"),
		"structured-red: a sideways region-frame +Y fails radial-normal alignment"
	)
	var inward_basis := DefinitionScript.new()
	inward_basis.body_local_basis = Basis(Vector3.RIGHT, deg_to_rad(180.0))
	_check(
		not bool(inward_basis.audit().valid)
			and _has_error(inward_basis.get_validation_errors(), "align outward"),
		"structured-red: an inward region-frame +Y fails radial-normal alignment"
	)
	var yawed_basis := DefinitionScript.new()
	yawed_basis.body_local_basis = Basis(Vector3.UP, deg_to_rad(37.0))
	_check(
		yawed_basis.is_definition_valid(),
		"arbitrary yaw around the outward radial normal preserves a valid region frame"
	)


func _test_body_radius_and_surface_envelope() -> void:
	var lower_edge := DefinitionScript.new()
	lower_edge.body_local_center_m = Vector3(0.0, 117500.0, 0.0)
	var upper_edge := DefinitionScript.new()
	upper_edge.body_local_center_m = Vector3(0.0, 128500.0, 0.0)
	_check(
		lower_edge.is_definition_valid() and upper_edge.is_definition_valid(),
		"both inclusive radial surface-envelope endpoints validate"
	)
	var radial_red := DefinitionScript.new()
	radial_red.body_local_center_m = Vector3(0.0, 117499.0, 0.0)
	_check(
		not bool(radial_red.audit().valid)
			and _has_error(radial_red.get_validation_errors(), "radial length"),
		"structured-red: a region centre below radius plus minimum elevation fails closed"
	)
	var upper_radial_red := DefinitionScript.new()
	upper_radial_red.body_local_center_m = Vector3(0.0, 128501.0, 0.0)
	_check(
		not upper_radial_red.is_definition_valid()
			and _has_error(upper_radial_red.get_validation_errors(), "radial length"),
		"a region centre above radius plus maximum elevation fails closed"
	)
	var radius_red := DefinitionScript.new()
	radius_red.body_radius_m = 200000.0
	_check(
		not bool(radius_red.audit().valid)
			and _has_error(radius_red.get_validation_errors(), "radial length"),
		"structured-red: changing the declared body radius without relocating the centre fails closed"
	)
	var non_finite := DefinitionScript.new()
	non_finite.body_radius_m = NAN
	non_finite.minimum_elevation_m = -INF
	non_finite.maximum_elevation_m = INF
	var finite_errors := non_finite.get_validation_errors()
	_check(
		_has_error(finite_errors, "body_radius_m")
			and _has_error(finite_errors, "minimum_elevation_m")
			and _has_error(finite_errors, "maximum_elevation_m"),
		"radius and elevation datum fields reject non-finite values"
	)
	var inverted := DefinitionScript.new()
	inverted.minimum_elevation_m = inverted.maximum_elevation_m
	_check(
		_has_error(
			inverted.get_validation_errors(),
			"minimum_elevation_m must be below"
		),
		"surface elevation endpoints are strictly ordered"
	)
	var collapsed := DefinitionScript.new()
	collapsed.body_radius_m = 1000.0
	collapsed.minimum_elevation_m = -1000.0
	collapsed.maximum_elevation_m = 10.0
	_check(
		_has_error(collapsed.get_validation_errors(), "must remain positive"),
		"minimum surface radius cannot collapse through the body centre"
	)


func _test_approach_and_touchdown_integrity() -> void:
	var mismatched_corridors := DefinitionScript.new()
	mismatched_corridors.approach_corridor_half_extents_m = PackedVector3Array()
	_check(
		_has_error(mismatched_corridors.get_validation_errors(), "typed arrays"),
		"corridor typed-array count mismatch fails closed"
	)
	var duplicate_corridor := DefinitionScript.new()
	duplicate_corridor.approach_corridor_ids = PackedStringArray(["primary_approach", "primary_approach"])
	duplicate_corridor.approach_corridor_transforms_region_local_m = [
		Transform3D.IDENTITY,
		Transform3D.IDENTITY,
	]
	duplicate_corridor.approach_corridor_half_extents_m = PackedVector3Array([
		Vector3.ONE,
		Vector3.ONE,
	])
	duplicate_corridor.approach_corridor_target_pad_ids = PackedStringArray(["pad_alpha", "pad_alpha"])
	_check(_has_error(duplicate_corridor.get_validation_errors(), "duplicated"), "corridor IDs are unique")
	var unknown_target := DefinitionScript.new()
	unknown_target.approach_corridor_target_pad_ids = PackedStringArray(["missing_pad"])
	_check(_has_error(unknown_target.get_validation_errors(), "unknown touchdown pad"), "corridors cannot target missing pads")
	var unserved_pad := _two_pad_definition()
	_check(_has_error(unserved_pad.get_validation_errors(), "requires at least one approach"), "every touchdown pad requires an approach")
	var invalid_volume := DefinitionScript.new()
	invalid_volume.approach_corridor_half_extents_m = PackedVector3Array([Vector3(45.0, NAN, 300.0)])
	_check(not invalid_volume.is_definition_valid(), "approach volume extents must be finite")
	invalid_volume = DefinitionScript.new()
	invalid_volume.approach_corridor_half_extents_m = PackedVector3Array([Vector3(45.0, 4.0, 300.0)])
	_check(_has_error(invalid_volume.get_validation_errors(), "vertical clearance"), "approach volume height covers minimum clearance")
	var pitched_volume := DefinitionScript.new()
	pitched_volume.approach_corridor_transforms_region_local_m = [
		Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(5.0)),
			Vector3(0.0, 60.0, 300.0)
		),
	]
	pitched_volume.approach_corridor_half_extents_m = PackedVector3Array([Vector3(45.0, 4.0, 300.0)])
	_check(
		pitched_volume.is_definition_valid(),
		"oriented-box vertical clearance uses its projected region-frame height"
	)
	var invalid_transform := DefinitionScript.new()
	invalid_transform.approach_corridor_transforms_region_local_m = [
		Transform3D(Basis.IDENTITY, Vector3(INF, 0.0, 0.0)),
	]
	_check(not invalid_transform.is_definition_valid(), "corridor transforms reject non-finite positions")
	var scaled_pad := DefinitionScript.new()
	scaled_pad.touchdown_pad_transforms_region_local_m = [
		Transform3D(Basis.from_scale(Vector3(2.0, 1.0, 1.0)), Vector3.ZERO),
	]
	_check(not scaled_pad.is_definition_valid(), "touchdown pad transforms reject scale")
	var invalid_pad_size := DefinitionScript.new()
	invalid_pad_size.touchdown_pad_sizes_m = PackedVector2Array([Vector2(0.0, 32.0)])
	_check(not invalid_pad_size.is_definition_valid(), "touchdown pad dimensions are finite and positive")
	var steep_pad := DefinitionScript.new()
	steep_pad.touchdown_pad_transforms_region_local_m = [
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(9.0)), Vector3.ZERO),
	]
	_check(
		_has_error(steep_pad.get_validation_errors(), "maximum surface slope"),
		"touchdown pad normal cannot exceed the declared surface-slope limit"
	)
	var mismatched_pads := DefinitionScript.new()
	mismatched_pads.touchdown_pad_egress_anchor_ids = PackedStringArray()
	_check(_has_error(mismatched_pads.get_validation_errors(), "typed arrays"), "pad typed-array count mismatch fails closed")


func _test_tags_limits_egress_and_evidence() -> void:
	var no_tags := DefinitionScript.new()
	no_tags.compatible_ship_tags = PackedStringArray()
	_check(not no_tags.is_definition_valid(), "at least one compatible ship tag is required")
	var duplicate_tags := DefinitionScript.new()
	duplicate_tags.compatible_ship_tags = PackedStringArray(["small_craft", "small_craft"])
	_check(_has_error(duplicate_tags.get_validation_errors(), "duplicated"), "compatible ship tags are unique")
	var invalid_tag := DefinitionScript.new()
	invalid_tag.compatible_ship_tags = PackedStringArray(["Small Craft"])
	_check(not invalid_tag.is_definition_valid(), "compatible ship tags use stable IDs")

	var scalar_mutations: Array[Dictionary] = [
		{"field": &"maximum_surface_slope_degrees", "value": NAN},
		{"field": &"maximum_surface_slope_degrees", "value": DefinitionScript.MAX_SURFACE_SLOPE_DEGREES + 0.01},
		{"field": &"maximum_surface_roughness_m", "value": INF},
		{"field": &"maximum_surface_roughness_m", "value": -0.01},
		{"field": &"minimum_vertical_clearance_m", "value": 0.0},
		{"field": &"minimum_approach_altitude_m", "value": -0.01},
		{"field": &"maximum_approach_altitude_m", "value": DefinitionScript.MAX_APPROACH_ALTITUDE_M + 1.0},
		{"field": &"minimum_on_foot_egress_width_m", "value": DefinitionScript.MIN_ON_FOOT_EGRESS_WIDTH_M - 0.01},
	]
	for mutation in scalar_mutations:
		var candidate := DefinitionScript.new()
		candidate.set(StringName(mutation.field), mutation.value)
		_check(not candidate.is_definition_valid(), "finite bounded limit rejects %s" % mutation.field)
	var inverted_altitude := DefinitionScript.new()
	inverted_altitude.minimum_approach_altitude_m = inverted_altitude.maximum_approach_altitude_m
	_check(_has_error(inverted_altitude.get_validation_errors(), "must be below"), "approach altitude endpoints are strictly ordered")

	var mismatched_anchors := DefinitionScript.new()
	mismatched_anchors.surface_route_anchor_positions_region_local_m = PackedVector3Array()
	_check(_has_error(mismatched_anchors.get_validation_errors(), "identical counts"), "surface anchor IDs and points remain atomic")
	var duplicate_anchor := DefinitionScript.new()
	duplicate_anchor.surface_route_anchor_ids = PackedStringArray(["pad_alpha_egress", "pad_alpha_egress"])
	_check(_has_error(duplicate_anchor.get_validation_errors(), "duplicated"), "surface-route anchor IDs are unique")
	var missing_egress := DefinitionScript.new()
	missing_egress.touchdown_pad_egress_anchor_ids = PackedStringArray(["unknown_egress"])
	_check(_has_error(missing_egress.get_validation_errors(), "not a named surface-route anchor"), "every pad egress names a published surface anchor")
	var non_finite_anchor := DefinitionScript.new()
	non_finite_anchor.surface_route_anchor_positions_region_local_m[0] = Vector3(0.0, NAN, 0.0)
	_check(not non_finite_anchor.is_definition_valid(), "surface-route anchor positions must be finite")
	var invalid_evidence := DefinitionScript.new()
	invalid_evidence.evidence_notes = " padded "
	invalid_evidence.evidence_references = PackedStringArray(["source_a", "source_a"])
	_check(
		_has_error(invalid_evidence.get_validation_errors(), "evidence_notes")
			and _has_error(invalid_evidence.get_validation_errors(), "duplicated"),
		"evidence notes and references reject padding and duplicates"
	)
	var oversized_evidence := DefinitionScript.new()
	oversized_evidence.evidence_references = PackedStringArray()
	for index in DefinitionScript.MAX_EVIDENCE_REFERENCE_COUNT + 1:
		oversized_evidence.evidence_references.append("source_%d" % index)
	_check(
		_has_error(oversized_evidence.get_validation_errors(), "count exceeds"),
		"evidence reference count has an exact ceiling"
	)


func _test_detached_snapshot_audit_and_zero_authority() -> void:
	var definition := DefinitionScript.new()
	var snapshot := definition.get_snapshot()
	var identity := snapshot.get("identity", {}) as Dictionary
	var envelope := snapshot.get("body_surface_envelope", {}) as Dictionary
	var corridors := snapshot.get("approach_corridors", []) as Array
	var pads := snapshot.get("touchdown_pads", []) as Array
	var anchors := snapshot.get("surface_route_anchors", []) as Array
	var constraints := snapshot.get("constraints", {}) as Dictionary
	identity["world_id"] = &"caller_mutated"
	envelope["body_radius_m"] = -1.0
	(corridors[0] as Dictionary)["target_pad_id"] = &"caller_mutated"
	(pads[0] as Dictionary)["egress_anchor_id"] = &"caller_mutated"
	(anchors[0] as Dictionary)["anchor_id"] = &"caller_mutated"
	(constraints.get("compatible_ship_tags") as PackedStringArray)[0] = "caller_mutated"
	var fresh := definition.get_snapshot()
	_check(
		(fresh.get("identity", {}) as Dictionary).get("world_id") == &"example_planetary_world"
			and float((fresh.get("body_surface_envelope", {}) as Dictionary).get("body_radius_m", -1.0)) == 120000.0
			and ((fresh.get("approach_corridors", []) as Array)[0] as Dictionary).get("target_pad_id") == &"pad_alpha"
			and ((fresh.get("touchdown_pads", []) as Array)[0] as Dictionary).get("egress_anchor_id") == &"pad_alpha_egress"
			and ((fresh.get("surface_route_anchors", []) as Array)[0] as Dictionary).get("anchor_id") == &"pad_alpha_egress"
			and ((fresh.get("constraints", {}) as Dictionary).get("compatible_ship_tags") as PackedStringArray)[0] == "small_craft",
		"snapshot identity, radius datum, record arrays, and packed tag arrays are deeply detached"
	)
	var audit := definition.get_audit_report()
	var audit_snapshot := audit.get("snapshot", {}) as Dictionary
	(audit_snapshot.get("identity", {}) as Dictionary)["region_id"] = &"audit_mutated"
	(audit.get("errors") as PackedStringArray).append("audit_mutated")
	var fresh_audit := definition.get_audit_report()
	_check(
		bool(fresh_audit.get("valid", false))
			and ((fresh_audit.get("snapshot", {}) as Dictionary).get("identity", {}) as Dictionary).get("region_id") == &"example_landing_region"
			and (fresh_audit.get("errors") as PackedStringArray).is_empty(),
		"audit and nested snapshot are detached across calls"
	)
	var evidence := fresh_audit.get("evidence", {}) as Dictionary
	_check(
		evidence.get("content_class") == &"NEW"
			and evidence.get("status") == &"modern_interpretation"
			and evidence.get("scope") == &"body_local_landing_region_contract"
			and not bool(evidence.get("historical_claim", true))
			and not bool(evidence.get("authenticated", true))
			and not bool(evidence.get("manual_review_required", true))
			and (evidence.get("references") as PackedStringArray).is_empty(),
		"audit evidence uses the common nested shape and denies historical claims"
	)
	var authority := fresh_audit.get("authority", {}) as Dictionary
	_check(
		authority == {
			"landing_motion": false,
			"berth": false,
			"lease": false,
			"terrain": false,
			"gameplay": false,
			"reward": false,
			"streaming": false,
			"save": false,
			"renderer": false,
			"network": false,
			"ship": false,
			"surface_route": false,
		},
		"audit freezes every adjacent runtime authority to false"
	)
	_check(
		not definition.has_method("_process")
			and not definition.has_method("_physics_process")
			and not definition.has_method("land")
			and not definition.has_method("reserve")
			and not definition.has_method("save"),
		"the Resource exposes no runtime, landing, reservation, or persistence seam"
	)


func _two_pad_definition() -> Resource:
	var definition := DefinitionScript.new()
	definition.touchdown_pad_ids = PackedStringArray(["pad_alpha", "pad_beta"])
	definition.touchdown_pad_transforms_region_local_m = [
		Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY, Vector3(60.0, 0.0, 0.0)),
	]
	definition.touchdown_pad_sizes_m = PackedVector2Array([
		Vector2(28.0, 32.0),
		Vector2(24.0, 28.0),
	])
	definition.touchdown_pad_egress_anchor_ids = PackedStringArray([
		"pad_alpha_egress",
		"surface_staging_gate",
	])
	return definition


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("PLANETARY_LANDING_REGION_DEFINITION_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_LANDING_REGION_DEFINITION_TEST_OK")
		quit(0)
		return
	print("PLANETARY_LANDING_REGION_DEFINITION_TEST_FAILURES: %s" % _failures)
	quit(1)
