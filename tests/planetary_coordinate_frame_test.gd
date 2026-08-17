extends SceneTree

const CoordinateFrame := preload("res://scripts/world/planetary_coordinate_frame.gd")

const BODY_ID: StringName = &"foundation_planet"
const ORBITAL_FRAME_ID: StringName = &"foundation_system"
const BODY_RADIUS_METERS := 1000.0
const ORBITAL_CELL_SIZE_METERS := 10_000.0
const HUGE_CELL_X := CoordinateFrame.MAX_SAFE_INTEGER - 100
const HUGE_CELL_Y := -CoordinateFrame.MAX_SAFE_INTEGER + 100
const HUGE_CELL_Z := 12_345
const SURFACE_REFERENCE_DIRECTION := Vector3.BACK
const SURFACE_NORTH_HINT := Vector3.UP
const ORIGIN_SHIFT_THRESHOLD_METERS := 5000.0
const EXPECTED_ASSERTIONS := 25

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_strict_configuration_and_coordinate_schema()
	_test_coordinate_conversions_precision_and_codec()
	_test_generation_safe_rebase_lifecycle()
	_test_detached_snapshot_audit_and_authority()
	_finish()


func _test_strict_configuration_and_coordinate_schema() -> void:
	var frame := CoordinateFrame.new() as PlanetaryCoordinateFrame
	_check(
		not bool(frame.audit().valid)
			and frame.audit().errors == PackedStringArray([
				"coordinate frame is not configured"
			]),
		"an unconfigured frame fails its audit closed"
	)
	var malformed_missing := _body_center_coordinate()
	malformed_missing.erase("cell_z")
	var malformed_extra := _body_center_coordinate()
	malformed_extra["authority"] = true
	var malformed_float_cell := _body_center_coordinate()
	malformed_float_cell["cell_x"] = float(HUGE_CELL_X)
	var malformed_frame := _body_center_coordinate()
	malformed_frame["frame_id"] = &"different_system"
	var noncanonical_offset := _body_center_coordinate()
	noncanonical_offset["offset_meters"] = Vector3(
		ORBITAL_CELL_SIZE_METERS * 0.5, 0, 0
	)
	var nonfinite_origin := _initial_origin_coordinate()
	nonfinite_origin["offset_meters"] = Vector3(NAN, 0, 0)
	var invalid_attempts := [
		_configure(frame, &"Bad ID"),
		_configure(frame, BODY_ID, NAN),
		_configure(
			frame, BODY_ID, CoordinateFrame.MAX_BODY_RADIUS_METERS + 1.0
		),
		_configure(frame, BODY_ID, BODY_RADIUS_METERS, 0.0),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			CoordinateFrame.MAX_ORBITAL_CELL_SIZE_METERS + 1.0
		),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			ORBITAL_CELL_SIZE_METERS, {}, INF
		),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			ORBITAL_CELL_SIZE_METERS, malformed_missing
		),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			ORBITAL_CELL_SIZE_METERS, malformed_extra
		),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			ORBITAL_CELL_SIZE_METERS, malformed_float_cell
		),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			ORBITAL_CELL_SIZE_METERS, malformed_frame
		),
		_configure(
			frame, BODY_ID, BODY_RADIUS_METERS,
			ORBITAL_CELL_SIZE_METERS, noncanonical_offset
		),
		frame.configure(
			BODY_ID,
			BODY_RADIUS_METERS,
			ORBITAL_FRAME_ID,
			ORBITAL_CELL_SIZE_METERS,
			_body_center_coordinate(),
			SURFACE_REFERENCE_DIRECTION,
			SURFACE_NORTH_HINT,
			ORIGIN_SHIFT_THRESHOLD_METERS,
			nonfinite_origin
		),
		frame.configure(
			BODY_ID,
			BODY_RADIUS_METERS,
			ORBITAL_FRAME_ID,
			ORBITAL_CELL_SIZE_METERS,
			_body_center_coordinate(),
			SURFACE_REFERENCE_DIRECTION,
			SURFACE_REFERENCE_DIRECTION,
			ORIGIN_SHIFT_THRESHOLD_METERS,
			_initial_origin_coordinate()
		),
	]
	var expected_reasons := [
		&"invalid_body_id",
		&"invalid_body_radius",
		&"invalid_body_radius",
		&"invalid_orbital_cell_size",
		&"invalid_orbital_cell_size",
		&"invalid_origin_shift_threshold",
		&"invalid_body_center_coordinate",
		&"invalid_body_center_coordinate",
		&"invalid_body_center_coordinate",
		&"invalid_body_center_coordinate",
		&"invalid_body_center_coordinate",
		&"invalid_streaming_origin_coordinate",
		&"degenerate_surface_north_hint",
	]
	var invalid_contracts_rejected := invalid_attempts.size() == expected_reasons.size()
	for index in invalid_attempts.size():
		var attempt := invalid_attempts[index] as Dictionary
		invalid_contracts_rejected = invalid_contracts_rejected \
			and not bool(attempt.get("accepted", true)) \
			and attempt.get("reason") == expected_reasons[index]
	_check(
		invalid_contracts_rejected and not frame.is_configured(),
		"invalid identity, finite bounds, schema, cell type, frame, offset, and tangent contracts reject without drift"
	)

	var configured := _configure(frame)
	var snapshot := frame.get_snapshot()
	_check(
		bool(configured.accepted)
			and configured.reason == &"configured"
			and frame.is_configured()
			and frame.get_generation() == 1
			and snapshot.body_id == BODY_ID
			and snapshot.orbital_frame_id == ORBITAL_FRAME_ID
			and is_equal_approx(float(snapshot.meters_per_world_unit), 1.0),
		"a strict metre-scale frame configures exactly once at generation one"
	)
	var before_reconfigure := frame.get_snapshot()
	var reconfigured := _configure(frame)
	_check(
		not bool(reconfigured.accepted)
			and reconfigured.reason == &"already_configured"
			and frame.get_snapshot() == before_reconfigure,
		"an established body/orbital frame cannot be reconfigured in place"
	)

	var negative_half := _body_center_coordinate()
	negative_half["offset_meters"] = Vector3(
		-ORBITAL_CELL_SIZE_METERS * 0.5, 0, 0
	)
	var positive_half := negative_half.duplicate(true)
	positive_half["offset_meters"] = Vector3(
		ORBITAL_CELL_SIZE_METERS * 0.5, 0, 0
	)
	var maximum_cells := _body_center_coordinate()
	maximum_cells["cell_x"] = CoordinateFrame.MAX_SAFE_INTEGER
	maximum_cells["cell_y"] = -CoordinateFrame.MAX_SAFE_INTEGER
	var exhausted_cell := maximum_cells.duplicate(true)
	exhausted_cell["cell_x"] = CoordinateFrame.MAX_SAFE_INTEGER + 1
	var accepted_edge := frame.validate_orbital_coordinate(negative_half)
	var accepted_safe_cells := frame.validate_orbital_coordinate(maximum_cells)
	var rejected_half := frame.validate_orbital_coordinate(positive_half)
	var rejected_exhaustion := frame.validate_orbital_coordinate(exhausted_cell)
	_check(
		bool(accepted_edge.accepted)
			and bool(accepted_safe_cells.accepted)
			and rejected_half.reason == &"coordinate_offset_not_canonical"
			and rejected_exhaustion.reason == &"coordinate_cells_out_of_bounds",
		"orbital cells enforce safe integers and canonical half-open metre offsets"
	)
	var detached_coordinate := accepted_edge.coordinate as Dictionary
	detached_coordinate["cell_x"] = 0
	_check(
		int(frame.validate_orbital_coordinate(negative_half).coordinate.cell_x) \
			== HUGE_CELL_X,
		"validated orbital coordinate results are detached from caller mutation"
	)


func _test_coordinate_conversions_precision_and_codec() -> void:
	var frame := _configured_frame()
	var generation := frame.get_generation()
	# At the +Z reference, +X is east, +Y tangent is radial +Z, and
	# +Z tangent is south (-planetary north/-Y).
	var tangent_position := Vector3(25.0, 40.0, -70.0)
	var to_body := frame.surface_tangent_to_body_local(
		tangent_position, generation
	)
	var body_local := to_body.get("position", Vector3.INF) as Vector3
	var expected_body_local := Vector3(25.0, 70.0, 1040.0)
	_check(
		bool(to_body.accepted)
			and to_body.source_frame == CoordinateFrame.FRAME_SURFACE_TANGENT
			and to_body.target_frame == CoordinateFrame.FRAME_BODY_LOCAL
			and body_local.is_equal_approx(expected_body_local),
		"surface tangent +X east, +Y up, and +Z south convert through the frozen reference basis"
	)
	var tangent_round_trip := frame.body_local_to_surface_tangent(
		body_local, generation
	)
	_check(
		bool(tangent_round_trip.accepted)
			and (tangent_round_trip.position as Vector3).is_equal_approx(
				tangent_position
			),
		"surface tangent and body-local conversion round-trip deterministically"
	)

	var orbital := frame.body_local_to_orbital_position(body_local, generation)
	var orbital_coordinate := orbital.coordinate as Dictionary
	var world := frame.orbital_to_world_streaming_position(
		orbital_coordinate, generation
	)
	var expected_world := Vector3(1000.0, 0.0, 0.0) + body_local
	_check(
		bool(orbital.accepted)
			and int(orbital_coordinate.cell_x) == HUGE_CELL_X
			and int(orbital_coordinate.cell_y) == HUGE_CELL_Y
			and bool(world.accepted)
			and (world.position as Vector3).is_equal_approx(expected_world),
		"integer-cell subtraction preserves local metres beside huge safe orbital cell identities"
	)
	var body_round_trip := frame.orbital_to_body_local_position(
		orbital_coordinate, generation
	)
	var orbital_round_trip := frame.world_streaming_to_orbital_position(
		expected_world, generation
	)
	_check(
		(body_round_trip.position as Vector3).is_equal_approx(body_local)
			and orbital_round_trip.coordinate == orbital_coordinate,
		"orbital/body-local and streaming/orbital transforms cross canonical cells reversibly"
	)

	var altitude := frame.body_local_altitude_meters(body_local, generation)
	var radial_altitude := body_local.length() - BODY_RADIUS_METERS
	_check(
		bool(altitude.accepted)
			and is_equal_approx(float(altitude.altitude_meters), radial_altitude)
			and not is_equal_approx(
				float(altitude.altitude_meters), tangent_position.y
			),
		"altitude is radial distance minus mean radius, not tangent Y away from the reference"
	)

	var encoded := frame.encode_body_local_position(body_local, generation)
	var encoded_again := frame.encode_body_local_position(body_local, generation)
	var decoded := frame.decode_world_streaming_position(
		expected_world, generation
	)
	_check(
		bool(encoded.accepted)
			and encoded.coordinate == encoded_again.coordinate
			and decoded.reason == &"decoded"
			and _coordinates_approximately_equal(
				encoded.coordinate as Dictionary,
				decoded.coordinate as Dictionary
			),
		"canonical encode/decode is deterministic and preserves all coordinate views"
	)

	var fine_body_local := Vector3(0.125, -0.375, BODY_RADIUS_METERS + 0.0625)
	var fine_encoded := frame.encode_body_local_position(
		fine_body_local, generation
	)
	var fine_decoded := frame.decode_world_streaming_position(
		fine_encoded.coordinate.world_streaming_position as Vector3,
		generation
	)
	_check(
		_coordinates_approximately_equal(
			fine_encoded.coordinate as Dictionary,
			fine_decoded.coordinate as Dictionary
		),
		"sub-metre offsets survive round-trip next to near-maximum orbital cell IDs"
	)

	var invalid_coordinate := frame.encode_body_local_position(
		Vector3(INF, 0, 0), generation
	)
	var far_orbital := orbital_coordinate.duplicate(true)
	far_orbital["cell_z"] = int(far_orbital.cell_z) + 200_000
	var bounded_overflow := frame.orbital_to_world_streaming_position(
		far_orbital, generation
	)
	_check(
		invalid_coordinate.reason == &"invalid_coordinate"
			and bounded_overflow.reason == &"coordinate_out_of_bounds",
		"non-finite local input and far cell deltas fail before unsafe float composition"
	)


func _test_generation_safe_rebase_lifecycle() -> void:
	var frame := _configured_frame()
	var generation := frame.get_generation()
	var inside := frame.evaluate_origin_shift(
		Vector3(ORIGIN_SHIFT_THRESHOLD_METERS - 0.001, 0, 0), generation
	)
	var exact := frame.evaluate_origin_shift(
		Vector3(ORIGIN_SHIFT_THRESHOLD_METERS, 0, 0), generation
	)
	var rejected := frame.request_rebase(
		Vector3(ORIGIN_SHIFT_THRESHOLD_METERS - 0.001, 0, 0), generation
	)
	_check(
		bool(inside.accepted) and not bool(inside.rebase_required)
			and bool(exact.rebase_required)
			and rejected.reason == &"origin_shift_below_threshold"
			and frame.get_snapshot().pending_rebase.is_empty(),
		"the origin threshold is inclusive and below-threshold requests do not mutate state"
	)

	var focus := Vector3(6000.0, 200.0, -50.0)
	var expected_target := frame.world_streaming_to_orbital_position(
		focus, generation
	).coordinate as Dictionary
	var before_request := frame.get_snapshot()
	var requested := frame.request_rebase(focus, generation)
	var request := requested.request as Dictionary
	var request_id := int(request.request_id)
	var pending_snapshot := frame.get_snapshot()
	_check(
		bool(requested.accepted)
			and int(request.source_generation) == 1
			and int(request.target_generation) == 2
			and request.source_origin_orbital_coordinate \
				== _initial_origin_coordinate()
			and request.target_origin_orbital_coordinate == expected_target
			and request.world_translation_delta == -focus
			and int(pending_snapshot.rebase_request_count) == 1,
		"a request freezes one generation-stamped canonical target and translation delta"
	)
	(request.target_origin_orbital_coordinate as Dictionary)["cell_x"] = 0
	(pending_snapshot.pending_rebase as Dictionary)["world_translation_delta"] \
		= Vector3.INF
	_check(
		frame.get_snapshot().pending_rebase.target_origin_orbital_coordinate \
			== expected_target,
		"caller mutation of request and snapshot dictionaries cannot alter pending authority"
	)
	var duplicate := frame.request_rebase(focus, generation)
	var wrong_id := frame.commit_rebase(request_id + 1, generation)
	var wrong_generation := frame.commit_rebase(request_id, generation + 1)
	_check(
		duplicate.reason == &"rebase_already_pending"
			and wrong_id.reason == &"stale_rebase_request"
			and wrong_generation.reason == &"stale_generation"
			and frame.get_generation() == generation
			and frame.get_snapshot().world_streaming_origin_orbital_coordinate \
				== before_request.world_streaming_origin_orbital_coordinate,
		"duplicates, wrong request IDs, and wrong generations reject without origin drift"
	)

	var body_point := Vector3(10.0, 20.0, 1010.0)
	var encoded_before := frame.encode_body_local_position(body_point, generation)
	var absolute_orbital := (
		encoded_before.coordinate as Dictionary
	).orbital_coordinate as Dictionary
	var world_before := (
		encoded_before.coordinate as Dictionary
	).world_streaming_position as Vector3
	var committed := frame.commit_rebase(request_id, generation)
	var world_after := (
		frame.encode_body_local_position(
			body_point, frame.get_generation()
		).coordinate as Dictionary
	).world_streaming_position as Vector3
	var absolute_after_rebase := frame.orbital_to_body_local_position(
		absolute_orbital, frame.get_generation()
	)
	_check(
		bool(committed.accepted)
			and frame.get_generation() == 2
			and committed.rebase.world_translation_delta == -focus
			and world_after.is_equal_approx(world_before - focus)
			and (absolute_after_rebase.position as Vector3).is_equal_approx(
				body_point
			)
			and frame.get_snapshot().pending_rebase.is_empty(),
		"commit advances one local generation while the absolute orbital coordinate remains stable"
	)
	var stale_conversion := frame.encode_body_local_position(body_point, generation)
	var stale_commit := frame.commit_rebase(request_id, generation)
	_check(
		stale_conversion.reason == &"stale_generation"
			and stale_commit.reason == &"stale_generation",
		"pre-rebase local conversions and duplicate commits are stale after generation advance"
	)

	var second_generation := frame.get_generation()
	var second_request := frame.request_rebase(
		Vector3(0, ORIGIN_SHIFT_THRESHOLD_METERS, 0), second_generation
	)
	var second_id := int(second_request.request.request_id)
	var stale_cancel := frame.cancel_rebase(second_id + 1, second_generation)
	var cancelled := frame.cancel_rebase(second_id, second_generation)
	_check(
		stale_cancel.reason == &"stale_rebase_request"
			and bool(cancelled.accepted)
			and frame.get_generation() == second_generation
			and frame.get_snapshot().pending_rebase.is_empty()
			and int(frame.get_snapshot().rebase_cancel_count) == 1,
		"only the matching request can cancel and cancellation preserves generation"
	)

	var edge_frame := CoordinateFrame.new() as PlanetaryCoordinateFrame
	var edge_coordinate := _orbital_coordinate(
		CoordinateFrame.MAX_SAFE_INTEGER, 0, 0, Vector3.ZERO
	)
	var edge_configured := edge_frame.configure(
		&"edge_planet",
		BODY_RADIUS_METERS,
		ORBITAL_FRAME_ID,
		ORBITAL_CELL_SIZE_METERS,
		edge_coordinate,
		SURFACE_REFERENCE_DIRECTION,
		SURFACE_NORTH_HINT,
		ORIGIN_SHIFT_THRESHOLD_METERS,
		edge_coordinate
	)
	var edge_before := edge_frame.get_snapshot()
	var exhausted := edge_frame.request_rebase(
		Vector3(ORIGIN_SHIFT_THRESHOLD_METERS, 0, 0),
		edge_frame.get_generation()
	)
	_check(
		bool(edge_configured.accepted)
			and exhausted.reason == &"orbital_cell_exhausted"
			and edge_frame.get_snapshot() == edge_before,
		"a finite target beyond the safe orbital-cell boundary fails atomically"
	)


func _test_detached_snapshot_audit_and_authority() -> void:
	var caller_body_center := _body_center_coordinate()
	var caller_origin := _initial_origin_coordinate()
	var input_frame := CoordinateFrame.new() as PlanetaryCoordinateFrame
	var input_configured := input_frame.configure(
		BODY_ID,
		BODY_RADIUS_METERS,
		ORBITAL_FRAME_ID,
		ORBITAL_CELL_SIZE_METERS,
		caller_body_center,
		SURFACE_REFERENCE_DIRECTION,
		SURFACE_NORTH_HINT,
		ORIGIN_SHIFT_THRESHOLD_METERS,
		caller_origin
	)
	caller_body_center["cell_x"] = 0
	caller_origin["offset_meters"] = Vector3.INF
	_check(
		bool(input_configured.accepted)
			and int(input_frame.get_snapshot().body_center_orbital_coordinate.cell_x) \
				== HUGE_CELL_X
			and input_frame.get_snapshot().world_streaming_origin_orbital_coordinate \
				== _initial_origin_coordinate(),
		"configuration retains detached immutable copies of caller orbital coordinates"
	)

	var frame := _configured_frame()
	var request := frame.request_rebase(
		Vector3(ORIGIN_SHIFT_THRESHOLD_METERS, 0, 0), frame.get_generation()
	)
	var snapshot := frame.get_snapshot()
	var audit := frame.audit()
	(snapshot.pending_rebase as Dictionary)["source_generation"] = -99
	(snapshot.body_center_orbital_coordinate as Dictionary)["cell_x"] = 0
	(audit.snapshot as Dictionary)["body_id"] = &"forged"
	(audit.authority as Dictionary)["physics"] = true
	_check(
		bool(frame.audit().valid)
			and int(frame.get_snapshot().pending_rebase.source_generation) == 1
			and int(frame.get_snapshot().body_center_orbital_coordinate.cell_x) \
				== HUGE_CELL_X
			and frame.get_snapshot().body_id == BODY_ID
			and not bool(frame.audit().authority.physics),
		"snapshots, coordinates, pending requests, and audits are deeply detached"
	)
	var authority := frame.audit().authority as Dictionary
	var no_forbidden_authority := true
	for key: String in authority:
		no_forbidden_authority = no_forbidden_authority \
			and not bool(authority[key])
	_check(
		bool(request.accepted)
			and frame is RefCounted
			and no_forbidden_authority
			and frame.audit().coordinate_policy.units == &"metres"
			and frame.audit().coordinate_policy.orbital_encoding \
				== &"safe_integer_cells_plus_half_open_offsets",
		"the pure policy owns no automatic process, movement, renderer, physics, streaming, gameplay, save, or network authority"
	)


func _configured_frame() -> PlanetaryCoordinateFrame:
	var frame := CoordinateFrame.new() as PlanetaryCoordinateFrame
	var configured := _configure(frame)
	if not bool(configured.get("accepted", false)):
		_failures.append("fixture configuration failed: %s" % configured)
	return frame


func _configure(
		frame: PlanetaryCoordinateFrame,
		body_id: StringName = BODY_ID,
		body_radius_meters: float = BODY_RADIUS_METERS,
		cell_size_meters: float = ORBITAL_CELL_SIZE_METERS,
		body_center: Dictionary = {},
		origin_shift_threshold_meters: float = ORIGIN_SHIFT_THRESHOLD_METERS
	) -> Dictionary:
	var resolved_body_center := body_center \
		if not body_center.is_empty() else _body_center_coordinate()
	return frame.configure(
		body_id,
		body_radius_meters,
		ORBITAL_FRAME_ID,
		cell_size_meters,
		resolved_body_center,
		SURFACE_REFERENCE_DIRECTION,
		SURFACE_NORTH_HINT,
		origin_shift_threshold_meters,
		_initial_origin_coordinate()
	)


func _body_center_coordinate() -> Dictionary:
	return _orbital_coordinate(
		HUGE_CELL_X,
		HUGE_CELL_Y,
		HUGE_CELL_Z,
		Vector3(0.125, -0.25, 0.5)
	)


func _initial_origin_coordinate() -> Dictionary:
	return _orbital_coordinate(
		HUGE_CELL_X,
		HUGE_CELL_Y,
		HUGE_CELL_Z,
		Vector3(-999.875, -0.25, 0.5)
	)


func _orbital_coordinate(
		cell_x: int,
		cell_y: int,
		cell_z: int,
		offset_meters: Vector3
	) -> Dictionary:
	return {
		"schema_version": CoordinateFrame.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset_meters,
	}


func _coordinates_approximately_equal(left: Dictionary, right: Dictionary) -> bool:
	return left.schema_version == right.schema_version \
		and left.body_id == right.body_id \
		and left.frame_generation == right.frame_generation \
		and (left.planetary_body_local_position as Vector3).is_equal_approx(
			right.planetary_body_local_position as Vector3
		) \
		and (left.surface_tangent_position as Vector3).is_equal_approx(
			right.surface_tangent_position as Vector3
		) \
		and is_equal_approx(
			float(left.altitude_meters), float(right.altitude_meters)
		) \
		and left.orbital_coordinate == right.orbital_coordinate \
		and (left.world_streaming_position as Vector3).is_equal_approx(
			right.world_streaming_position as Vector3
		)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion harness expected %d checks but ran %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_COORDINATE_FRAME_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"PLANETARY_COORDINATE_FRAME_TEST_FAILED: %d / %d assertions failed" \
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
