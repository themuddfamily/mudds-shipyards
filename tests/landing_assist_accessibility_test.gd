extends SceneTree

## Focused accessibility and authority coverage for the broad landing-assist
## capture contract. Acquisition is forgiving; physical docking remains exact.

const BERTH_SCRIPT := preload("res://scripts/world/ship_berth.gd")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_broad_capture_boundaries()
	await _test_staged_nose_first_return()
	await _test_capture_authority_mutation()
	_finish()


func _test_broad_capture_boundaries() -> void:
	var stage := Node3D.new()
	stage.name = "BroadCaptureBoundaryStage"
	root.add_child(stage)
	var berth := _configured_berth(&"broad_capture_boundary_berth")
	berth.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(37.0)),
		Vector3(80.0, 24.0, -60.0)
	)
	stage.add_child(berth)
	await process_frame

	var hull := AABB(Vector3(-3.0, -1.0, -6.0), Vector3(6.0, 2.0, 12.0))
	var dock := berth.get_dock_transform()
	var capture := berth.get_assist_capture_transform()
	var broad_attitude := (
		dock.basis
		* Basis(Vector3.UP, PI)
		* Basis(Vector3.RIGHT, deg_to_rad(60.0))
	).orthonormalized()
	var broad_transform := Transform3D(
		broad_attitude,
		capture * Vector3(28.0, 7.0, -18.0)
	)
	var accepted := berth.evaluate_assist_capture_candidate(
		broad_transform,
		hull,
		Vector3(0.0, 0.0, 35.0),
		20.0
	)
	_check(bool(accepted.valid), "off-axis high capture accepts 60-degree tilt and a natural 180-degree yaw")
	_check(
		bool(accepted.heading_unrestricted)
		and float(accepted.heading_error_degrees) > 90.0
		and is_equal_approx(float(accepted.effective_maximum_speed), 35.0)
		and is_equal_approx(float(accepted.legacy_ship_maximum_speed), 20.0),
		"capture report honestly records unrestricted yaw and the widened berth speed authority"
	)
	_check(
		bool(accepted.docked_hull_fits)
		and bool(accepted.strict_dock_acceptance)
		and (accepted.capture_half_extents as Vector3).is_equal_approx(Vector3(30.0, 16.0, 45.0)),
		"broad acquisition still attests the exact final hull and publishes its capture volume"
	)
	var old_strict := berth.evaluate_landing_candidate(
		broad_transform,
		hull,
		Vector3.ZERO,
		20.0
	)
	_check(
		not bool(old_strict.valid),
		"legacy narrow candidate evaluation remains separate from production broad capture"
	)

	var boundary_transform := Transform3D(dock.basis, capture * Vector3(30.0, 16.0, 45.0))
	var boundary := berth.evaluate_assist_capture_candidate(
		boundary_transform,
		hull,
		Vector3.ZERO,
		20.0
	)
	_check(bool(boundary.valid), "assist root exactly on the inclusive capture boundary is accepted")
	var outside_transform := Transform3D(dock.basis, capture * Vector3(30.01, 0.0, 0.0))
	var outside := berth.evaluate_assist_capture_candidate(
		outside_transform,
		hull,
		Vector3.ZERO,
		20.0
	)
	_check(
		not bool(outside.valid) and _has_error(outside.errors, "outside_assist_capture"),
		"capture root just beyond the wide volume is rejected"
	)

	var speed_boundary := berth.evaluate_assist_capture_candidate(
		Transform3D(dock.basis, capture.origin),
		hull,
		Vector3(35.0, 0.0, 0.0),
		20.0
	)
	var too_fast := berth.evaluate_assist_capture_candidate(
		Transform3D(dock.basis, capture.origin),
		hull,
		Vector3(35.01, 0.0, 0.0),
		20.0
	)
	_check(bool(speed_boundary.valid), "berth capture speed boundary is inclusive")
	_check(
		not bool(too_fast.valid) and _has_error(too_fast.errors, "speed"),
		"speed just above the widened berth cap is rejected"
	)

	var tilt_boundary_basis := (
		dock.basis * Basis(Vector3.RIGHT, deg_to_rad(75.0))
	).orthonormalized()
	var tilt_boundary := berth.evaluate_assist_capture_candidate(
		Transform3D(tilt_boundary_basis, capture.origin),
		hull,
		Vector3.ZERO,
		20.0
	)
	var excessive_tilt_basis := (
		dock.basis * Basis(Vector3.RIGHT, deg_to_rad(75.1))
	).orthonormalized()
	var excessive_tilt := berth.evaluate_assist_capture_candidate(
		Transform3D(excessive_tilt_basis, capture.origin),
		hull,
		Vector3.ZERO,
		20.0
	)
	var inverted_basis := (dock.basis * Basis(Vector3.RIGHT, PI)).orthonormalized()
	var inverted := berth.evaluate_assist_capture_candidate(
		Transform3D(inverted_basis, capture.origin),
		hull,
		Vector3.ZERO,
		20.0
	)
	_check(bool(tilt_boundary.valid), "assist accepts the full configured 75-degree tilt boundary")
	_check(
		not bool(excessive_tilt.valid) and _has_error(excessive_tilt.errors, "attitude"),
		"assist rejects tilt immediately beyond 75 degrees"
	)
	_check(
		not bool(inverted.valid) and _has_error(inverted.errors, "attitude"),
		"assist always rejects an inverted capture"
	)

	berth.landing_half_extents = Vector3(2.0, 1.0, 3.0)
	var undersized := berth.evaluate_assist_capture_candidate(
		Transform3D(dock.basis, capture.origin),
		hull,
		Vector3.ZERO,
		20.0
	)
	_check(
		not bool(undersized.valid) and _has_error(undersized.errors, "docked_hull"),
		"wide capture cannot weaken final full-hull docking clearance"
	)
	stage.queue_free()
	await process_frame
	await process_frame


func _test_staged_nose_first_return() -> void:
	var stage := Node3D.new()
	stage.name = "StagedNoseFirstReturnStage"
	root.add_child(stage)
	var berth := _configured_berth(&"staged_nose_first_return_berth")
	berth.position = Vector3(-90.0, 30.0, 70.0)
	stage.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame

	var dock := berth.get_dock_transform()
	var approach_basis := (
		dock.basis
		* Basis(Vector3.UP, PI)
		* Basis(Vector3.RIGHT, deg_to_rad(55.0))
	).orthonormalized()
	ship.global_transform = Transform3D(
		approach_basis,
		dock * Vector3(28.0, 15.0, -40.0)
	)
	ship.velocity = dock.basis * Vector3(0.0, 0.0, 30.0)
	_check(
		not ship.request_landing(dock),
		"same off-axis return remains outside the legacy narrow range/speed gate"
	)
	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(not token.is_empty(), "wide-return fixture obtains its exact authoritative berth lease")
	_check(
		ship.request_berth_landing(berth),
		"production assist accepts a fast, high, off-axis, 180-degree nose-first return"
	)
	var initial_report := ship.get_landing_contract_report()
	_check(
		initial_report.phase == &"brake"
		and bool(initial_report.contract_accepted)
		and bool(initial_report.strict_dock_acceptance)
		and is_equal_approx(float(initial_report.timeout_seconds), 24.0)
		and is_equal_approx(float(initial_report.stall_timeout_seconds), 4.0),
		"accepted contract starts with bounded braking and reports the expanded timing budget"
	)

	var observed_phases := PackedStringArray([initial_report.phase as StringName])
	for _step in 1500:
		if not ship.is_landing_active():
			break
		ship.call("_update_landing", 1.0 / 60.0)
		var phase := ship.get_telemetry().landing_phase as StringName
		if not observed_phases.has(phase):
			observed_phases.append(phase)
	_check(
		observed_phases.has(&"brake")
		and observed_phases.has(&"move_to_staging")
		and observed_phases.has(&"align")
		and observed_phases.has(&"final_approach")
		and observed_phases.has(&"docked"),
		"wide return visibly executes brake, staging, alignment, final approach, and dock phases"
	)
	_check(
		not ship.is_landing_active()
		and bool(ship.get_telemetry().landed)
		and ship.get_telemetry().landing_phase == &"docked",
		"staged assist completes within its bounded production window"
	)
	_check(
		ship.global_transform.is_equal_approx(dock)
		and ship.velocity.is_equal_approx(Vector3.ZERO),
		"completion retains the exact dock origin, full basis, and zero velocity"
	)
	_check(
		berth.get_occupant() == ship
		and berth.get_reservation_owner() == ship
		and berth.get_reservation_token(ship) == token,
		"completion converts the same opaque reservation into occupancy"
	)
	stage.queue_free()
	await process_frame
	await process_frame


func _test_capture_authority_mutation() -> void:
	var stage := Node3D.new()
	stage.name = "CaptureAuthorityMutationStage"
	root.add_child(stage)
	var berth := _configured_berth(&"capture_authority_mutation_berth")
	berth.position = Vector3(120.0, 20.0, 90.0)
	stage.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame
	ship.global_transform = Transform3D(
		berth.get_dock_transform().basis,
		berth.get_assist_capture_transform().origin
	)
	ship.velocity = Vector3.ZERO
	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(
		not token.is_empty() and ship.request_berth_landing(berth),
		"capture-mutation fixture begins with a snapshotted wide-assist contract"
	)
	berth.assist_capture_half_extents.x += 1.0
	ship.call("_update_landing", 0.01)
	_check(
		not ship.is_landing_active()
		and ship.get_telemetry().landing_abort_reason == &"berth_changed",
		"mid-assist capture-volume mutation invalidates motion authority"
	)
	_check(
		not berth.is_reserved() and berth.get_occupant() == null,
		"capture mutation abort releases the exact pending lease without occupancy"
	)
	stage.queue_free()
	await process_frame
	await process_frame


func _configured_berth(berth_id: StringName) -> ShipBerth:
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = berth_id
	berth.landing_half_extents = Vector3(12.0, 3.8, 17.0)
	berth.assist_capture_center = Vector3(0.0, 8.0, -22.0)
	berth.assist_capture_half_extents = Vector3(30.0, 16.0, 45.0)
	berth.assist_capture_maximum_speed = 35.0
	berth.assist_maximum_tilt_degrees = 75.0
	return berth


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("LANDING_ASSIST_ACCESSIBILITY_TEST_OK")
		quit(0)
	else:
		print("LANDING_ASSIST_ACCESSIBILITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
