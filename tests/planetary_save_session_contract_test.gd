extends SceneTree

const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const ContractScript := preload("res://scripts/world/planetary_save_session_contract.gd")

const BODY_ID: StringName = &"ember_moon"
const ORBITAL_FRAME_ID: StringName = &"nearby_sector"
const BODY_RADIUS_METERS := 1_000.0
const CELL_SIZE_METERS := 10_000.0
const SHIFT_THRESHOLD_METERS := 5_000.0
const HUGE_CELL_X := FrameScript.MAX_SAFE_INTEGER - 100
const HUGE_CELL_Y := -FrameScript.MAX_SAFE_INTEGER + 100
const HUGE_CELL_Z := 12_345

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_session_identity()
	_test_checkpoint_validation_and_detachment()
	_test_orbit_reentry_across_origin_generation()
	_test_surface_reentry_generation_fence()
	_test_snapshot_codec_and_audit()
	_finish()


func _test_configuration_and_session_identity() -> void:
	var unconfigured = ContractScript.new()
	_check(
		not unconfigured.is_configuration_valid()
			and unconfigured.begin_session(&"visit_one", 1, 1).reason
			== &"invalid_configuration",
		"missing frame configuration fails closed before session mutation"
	)
	var contract = _contract()
	_check(
		contract.is_configuration_valid()
			and contract.get_snapshot().state == "idle"
			and contract.begin_session(&"Visit-One", 1, 1).reason
			== &"session_id_invalid",
		"stable lowercase session identifiers are enforced"
	)
	var started: Dictionary = contract.begin_session(&"visit_one", 1, 1)
	_check(
		bool(started.accepted)
			and started.reason == &"started"
			and contract.get_snapshot().state == "active"
			and contract.begin_session(&"second_visit", 1, 1).reason
			== &"session_already_started",
		"one attachment generation starts exactly one active visit"
	)
	_check(
		contract.save_orbit_checkpoint(2, 1, 1, _origin_coordinate(), {}).reason
			== &"stale_attachment_generation"
			and contract.save_orbit_checkpoint(1, 2, 1, _origin_coordinate(), {}).reason
			== &"stale_frame_generation",
		"stale attachment and coordinate generations reject before checkpoint mutation"
	)


func _test_checkpoint_validation_and_detachment() -> void:
	var contract = _contract()
	contract.begin_session(&"visit_one", 1, 1)
	var payload := {"objective": "survey", "cargo": {"units": 4}}
	var saved: Dictionary = contract.save_orbit_checkpoint(
		1, 1, 120, _origin_coordinate(), payload
	)
	_check(
		bool(saved.accepted)
			and saved.reason == &"checkpointed"
			and int(contract.get_snapshot().checkpoint_generation) == 1
			and int(contract.get_snapshot().physics_tick) == 120,
		"an orbit checkpoint records a monotonic tick and canonical absolute coordinate"
	)
	payload.cargo.units = 999
	var snapshot: Dictionary = contract.get_snapshot()
	_check(
		int(snapshot.checkpoint.payload.cargo.units) == 4
			and snapshot.checkpoint.surface_tangent_meters.is_empty()
			and snapshot.checkpoint.orbital_coordinate.offset_meters is Array,
		"checkpoint payload and encoded coordinates are detached and JSON-safe"
	)
	_check(
		contract.save_orbit_checkpoint(
			1, 1, 119, _origin_coordinate(), {}
		).reason == &"physics_tick_regressed"
			and contract.save_orbit_checkpoint(
				1, 1, 121, _origin_coordinate(), {"bad": Vector3.ONE}
			).reason == &"payload_invalid",
		"checkpoint ticks cannot regress and non-JSON payload values are rejected"
	)
	var detached: Dictionary = contract.detach_session(1, 1)
	_check(
		bool(detached.accepted)
			and contract.get_snapshot().state == "detached"
			and contract.close_session(1, 1).reason == &"session_not_active",
		"detaching freezes the hand-off and prevents post-detach writes"
	)


func _test_orbit_reentry_across_origin_generation() -> void:
	var source_frame := _frame()
	var source = ContractScript.new(BODY_ID, source_frame)
	source.begin_session(&"orbit_return", 1, 1)
	source.save_orbit_checkpoint(1, 1, 42, _origin_coordinate(), {"route": "alpha"})
	source.detach_session(1, 1)
	var detached_snapshot := source.get_snapshot()
	var reentry_frame := _frame()
	var rebase := reentry_frame.request_rebase(
		Vector3(SHIFT_THRESHOLD_METERS, 0.0, 0.0), 1
	)
	_check(
		bool(rebase.accepted)
			and bool(reentry_frame.commit_rebase(int(rebase.request.request_id), 1).accepted)
			and reentry_frame.get_generation() == 2,
		"the receiving frame can advance its origin generation before re-entry"
	)
	var receiving = ContractScript.new(BODY_ID, reentry_frame)
	var restored := receiving.restore_detached_snapshot(
		detached_snapshot, 2, 2
	)
	_check(
		bool(restored.accepted)
			and restored.reason == &"reentered"
			and bool(restored.origin_generation_changed)
			and receiving.get_snapshot().state == "active"
			and receiving.get_snapshot().checkpoint.orbital_coordinate
			== detached_snapshot.checkpoint.orbital_coordinate,
		"absolute orbit checkpoints re-enter after an origin-generation change"
	)
	_check(
		receiving.close_session(2, 2).reason == &"closed"
			and receiving.get_snapshot().state == "closed",
		"a re-entered visit closes only with its new attachment and frame generations"
	)


func _test_surface_reentry_generation_fence() -> void:
	var source_frame := _frame()
	var source = ContractScript.new(BODY_ID, source_frame)
	source.begin_session(&"surface_return", 1, 1)
	var tangent := Vector3(12.0, 8.0, -6.0)
	var body_local := source_frame.surface_tangent_to_body_local(tangent, 1)
	var orbital := source_frame.body_local_to_orbital_position(
		body_local.position as Vector3, 1
	)
	var saved := source.save_surface_checkpoint(
		1, 1, 10, orbital.coordinate as Dictionary, tangent, {"landing": "north_ridge"}
	)
	source.detach_session(1, 1)
	var new_frame := _frame()
	var request := new_frame.request_rebase(Vector3(SHIFT_THRESHOLD_METERS, 0.0, 0.0), 1)
	new_frame.commit_rebase(int(request.request.request_id), 1)
	var changed = ContractScript.new(BODY_ID, new_frame)
	_check(
		bool(saved.accepted)
			and changed.restore_detached_snapshot(source.get_snapshot(), 2, 2).reason
			== &"surface_checkpoint_generation_mismatch",
		"surface tangent checkpoints fail closed when restored across a frame generation"
	)
	var exact_frame := _frame()
	var exact = ContractScript.new(BODY_ID, exact_frame)
	var exact_restore := exact.restore_detached_snapshot(source.get_snapshot(), 2, 1)
	_check(
		bool(exact_restore.accepted)
			and not bool(exact_restore.origin_generation_changed)
			and exact.get_snapshot().checkpoint.surface_tangent_meters == [12.0, 8.0, -6.0],
		"surface tangent checkpoints re-enter only at their captured generation"
	)


func _test_snapshot_codec_and_audit() -> void:
	var contract = _contract()
	var initial: Dictionary = contract.get_snapshot()
	var decoded := ContractScript.decode_snapshot(initial)
	var forged: Dictionary = initial.duplicate(true)
	forged.extra = true
	var invalid := ContractScript.decode_snapshot(forged)
	_check(
		bool(decoded.accepted)
			and decoded.reason == &"valid"
			and not bool(invalid.accepted)
			and invalid.reason == &"snapshot_fields_invalid",
		"the snapshot codec accepts its exact idle schema and rejects extra fields"
	)
	var audit: Dictionary = contract.audit()
	var authority := audit.authority as Dictionary
	var authority_clear := true
	for key: String in authority:
		authority_clear = authority_clear and not bool(authority[key])
	_check(
		bool(audit.valid)
			and bool(audit.uses_absolute_orbital_coordinates)
			and bool(audit.surface_checkpoint_requires_exact_frame_generation)
			and authority_clear,
		"audit exposes coordinate policy and no filesystem, scene, physics, or clock authority"
	)


func _contract():
	return ContractScript.new(BODY_ID, _frame())


func _frame() -> PlanetaryCoordinateFrame:
	var frame := FrameScript.new() as PlanetaryCoordinateFrame
	var result := frame.configure(
		BODY_ID,
		BODY_RADIUS_METERS,
		ORBITAL_FRAME_ID,
		CELL_SIZE_METERS,
		_origin_coordinate(),
		Vector3.BACK,
		Vector3.UP,
		SHIFT_THRESHOLD_METERS,
		_origin_coordinate()
	)
	if not bool(result.accepted):
		_failures.append("frame fixture failed: %s" % result)
	return frame


func _origin_coordinate() -> Dictionary:
	return {
		"schema_version": FrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": HUGE_CELL_X,
		"cell_y": HUGE_CELL_Y,
		"cell_z": HUGE_CELL_Z,
		"offset_meters": Vector3.ZERO,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_SAVE_SESSION_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"PLANETARY_SAVE_SESSION_CONTRACT_TEST_FAILED: %d / %d assertions failed"
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
