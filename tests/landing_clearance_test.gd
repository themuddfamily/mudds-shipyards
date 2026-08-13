extends SceneTree

const BERTH_SCRIPT := preload("res://scripts/world/ship_berth.gd")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_oriented_berth_acceptance()
	await _test_production_fleet_collision_envelopes()
	await _test_strict_assist_lifecycle()
	await _test_landing_authority_invalidation()
	await _test_active_landing_lifecycle_teardown()
	await _test_aligned_support_contact()
	await _test_rotational_obstruction_stall()
	await _test_destruction_audio_ordering()
	_finish()


func _test_oriented_berth_acceptance() -> void:
	var stage := Node3D.new()
	stage.name = "OrientedBerthStage"
	root.add_child(stage)
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = &"test_oriented_berth"
	berth.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(37.0)), Vector3(8.0, 3.0, -6.0))
	berth.dock_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), Vector3(0.5, 0.2, -0.75))
	berth.landing_half_extents = Vector3(4.0, 2.5, 7.0)
	stage.add_child(berth)
	await process_frame

	var hull := AABB(Vector3(-1.0, -0.5, -2.0), Vector3(2.0, 1.0, 4.0))
	var dock := berth.get_dock_transform()
	_check(berth.contains_oriented_bounds(dock, hull, 0.05), "complete oriented hull fits at the composed dock transform")
	var safe_candidate := dock * Transform3D(Basis.IDENTITY, Vector3(1.5, 0.0, 1.0))
	_check(berth.contains_oriented_bounds(safe_candidate, hull, 0.05), "complete hull fits at a safe approach offset")
	var root_only_candidate := dock * Transform3D(Basis.IDENTITY, Vector3(3.5, 0.0, 0.0))
	_check(berth.contains(root_only_candidate.origin), "legacy point containment sees a root inside the berth")
	_check(not berth.contains_oriented_bounds(root_only_candidate, hull, 0.05), "oriented containment rejects a root-inside craft whose hull crosses the berth edge")

	var accepted := berth.evaluate_landing_candidate(safe_candidate, hull, Vector3(0.0, 0.0, -4.0), 10.0)
	_check(bool(accepted.valid), "slow aligned full-hull approach passes dock-contract acceptance")
	_check(bool(accepted.approach_hull_inside) and bool(accepted.docked_hull_fits), "acceptance separately attests approach and docked hull clearance")
	_check(
		int(accepted.schema_version) == 2
		and bool(accepted.contract_accepted)
		and bool(accepted.strict_dock_acceptance)
		and not bool(accepted.continuous_swept_clearance_proved)
		and accepted.berth_id == &"test_oriented_berth",
		"acceptance report has honest schema-v2 dock scope and berth identity"
	)

	var fast := berth.evaluate_landing_candidate(safe_candidate, hull, Vector3(0.0, 0.0, -10.1), 10.0)
	_check(not bool(fast.valid) and _has_error(fast.errors, "speed"), "approach above the configured speed limit is rejected")
	var wrong_heading_transform := dock * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3.ZERO)
	var wrong_heading := berth.evaluate_landing_candidate(wrong_heading_transform, hull, Vector3.ZERO, 10.0)
	_check(not bool(wrong_heading.valid) and _has_error(wrong_heading.errors, "heading"), "sideways approach is rejected before assist takes authority")
	var inverted_transform := dock * Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO)
	var inverted := berth.evaluate_landing_candidate(inverted_transform, hull, Vector3.ZERO, 10.0)
	_check(not bool(inverted.valid) and _has_error(inverted.errors, "attitude"), "inverted approach is rejected before assist takes authority")
	var outside_candidate := dock * Transform3D(Basis.IDENTITY, Vector3(4.05, 0.0, 0.0))
	var outside := berth.evaluate_landing_candidate(outside_candidate, hull, Vector3.ZERO, 10.0)
	_check(not bool(outside.valid) and _has_error(outside.errors, "ship_root"), "candidate audit fails red once the approach root leaves the landing volume")
	var root_only := berth.evaluate_landing_candidate(root_only_candidate, hull, Vector3.ZERO, 10.0)
	_check(bool(root_only.valid) and not bool(root_only.approach_hull_inside), "root-inside approach may engage while the report honestly exposes its current hull overhang")

	berth.landing_half_extents = Vector3(0.75, 2.5, 7.0)
	var too_small := berth.evaluate_landing_candidate(dock, hull, Vector3.ZERO, 10.0)
	_check(not bool(too_small.valid) and _has_error(too_small.errors, "docked_hull"), "berth that cannot contain the final hull is rejected")
	stage.queue_free()
	await process_frame
	await process_frame


func _test_production_fleet_collision_envelopes() -> void:
	var fixtures := [
		{
			"name": "Torrent",
			"scene": TORRENT_SCENE,
			"half": Vector3(12.0, 3.8, 17.0),
			"minimum_shapes": 2,
		},
		{
			"name": "Arrow",
			"scene": ARROW_SCENE,
			"half": Vector3(8.0, 4.5, 9.0),
			"minimum_shapes": 2,
		},
		{
			"name": "Jovian",
			"scene": JOVIAN_SCENE,
			"half": Vector3(14.0, 8.0, 21.5),
			"minimum_shapes": 4,
		},
	]
	for fixture in fixtures:
		var stage := Node3D.new()
		stage.name = "%sClearanceStage" % fixture.name
		root.add_child(stage)
		var berth := BERTH_SCRIPT.new() as ShipBerth
		berth.berth_id = StringName("%s_clearance_berth" % str(fixture.name).to_lower())
		berth.landing_half_extents = fixture.half
		berth.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(23.0)), Vector3(30.0, 12.0, -20.0))
		stage.add_child(berth)
		var ship := (fixture.scene as PackedScene).instantiate() as HeroShip
		stage.add_child(ship)
		await process_frame
		var report := ship.get_landing_collision_report()
		_check(bool(report.valid), "%s derives a valid root-collision landing envelope" % fixture.name)
		_check(int(report.shape_count) >= int(fixture.minimum_shapes), "%s envelope includes its production collision shapes" % fixture.name)
		var bounds := report.local_bounds as AABB
		_check(bounds.size.x > 0.5 and bounds.size.y > 0.5 and bounds.size.z > 0.5, "%s collision envelope is three-dimensional" % fixture.name)
		ship.global_transform = berth.get_dock_transform()
		var acceptance := berth.evaluate_landing_candidate(ship.global_transform, bounds, Vector3.ZERO, ship.landing_maximum_speed)
		_check(bool(acceptance.valid), "%s complete collision envelope fits its production berth dimensions" % fixture.name)
		var half := fixture.half as Vector3
		ship.global_transform = berth.get_dock_transform() * Transform3D(Basis.IDENTITY, Vector3(half.x - 0.01, 0.0, 0.0))
		_check(berth.contains(ship.global_position), "%s root can be staged just inside a berth boundary" % fixture.name)
		_check(not berth.contains_oriented_bounds(ship.global_transform, bounds, 0.05), "%s full hull prevents root-only boundary acceptance" % fixture.name)
		stage.queue_free()
		await process_frame
		await process_frame


func _test_strict_assist_lifecycle() -> void:
	var stage := Node3D.new()
	stage.name = "StrictLandingLifecycleStage"
	root.add_child(stage)
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = &"strict_lifecycle_berth"
	berth.landing_half_extents = Vector3(12.0, 3.8, 17.0)
	berth.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-31.0)), Vector3(-25.0, 9.0, 18.0))
	stage.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	ship.global_transform = berth.get_dock_transform()
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame
	_check(ship.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE, "strict landing fixture reaches online engine state")
	var signal_counts := {"completed": 0}
	var aborted_reasons := PackedStringArray()
	ship.landing_completed.connect(func() -> void: signal_counts.completed = int(signal_counts.completed) + 1)
	ship.landing_aborted.connect(func(reason: StringName) -> void: aborted_reasons.append(reason))
	var reservation_token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(not reservation_token.is_empty(), "dock-contract fixture obtains an authoritative berth lease")
	_check(ship.request_berth_landing(berth), "leased berth landing accepts an aligned complete hull")
	_check(ship.is_landing_active(), "accepted dock contract visibly owns the active assist state")
	await physics_frame
	await physics_frame
	_check(not ship.is_landing_active() and bool(ship.get_telemetry().landed), "dock assist reaches a physically docked state")
	_check(int(signal_counts.completed) == 1, "dock assist emits landing completion exactly once")
	_check(berth.get_occupant() == ship, "completion converts the snapshotted lease to occupancy before signaling")
	var completed_report := ship.get_landing_contract_report()
	_check(
		bool(completed_report.contract_accepted) and bool(completed_report.strict_dock_acceptance),
		"completed landing retains canonical dock-contract acceptance evidence"
	)
	_check(completed_report.berth_id == &"strict_lifecycle_berth", "completed landing retains authoritative berth identity")
	_check(
		completed_report.dock_transform_snapshot == berth.get_dock_transform()
		and completed_report.reserved_ship_id == ship.get_ship_definition().ship_id
		and bool(completed_report.reservation_token_bound),
		"completed report retains its accepted dock transform and lease identity"
	)

	ship.global_transform = berth.get_dock_transform() * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	ship.velocity = Vector3.ZERO
	_check(ship.request_berth_landing(berth), "dock assist can start a subsequent valid approach")
	ship.call("_update_landing", 24.1)
	_check(not ship.is_landing_active() and not bool(ship.get_telemetry().landed), "timed-out assist fails safely without claiming a landing")
	_check(aborted_reasons.size() == 1 and aborted_reasons[0] == &"assist_timeout", "assist timeout emits an auditable abort reason once")
	_check(ship.get_telemetry().landing_abort_reason == &"assist_timeout", "telemetry retains the last landing abort reason")
	stage.queue_free()
	await process_frame
	await process_frame


func _test_landing_authority_invalidation() -> void:
	var stage := Node3D.new()
	stage.name = "LandingAuthorityInvalidationStage"
	root.add_child(stage)
	var first_parent := Node3D.new()
	first_parent.name = "FirstBerthParent"
	stage.add_child(first_parent)
	var second_parent := Node3D.new()
	second_parent.name = "SecondBerthParent"
	stage.add_child(second_parent)
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = &"authority_invalidation_berth"
	berth.landing_half_extents = Vector3(12.0, 3.8, 17.0)
	berth.position = Vector3(36.0, 7.0, -12.0)
	first_parent.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame

	var token := berth.try_reserve(ship, ship.get_ship_definition())
	ship.global_transform = berth.get_dock_transform() * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	_check(not token.is_empty() and ship.request_berth_landing(berth), "moved-berth fixture begins with a bound lease")
	berth.position.x += 0.5
	ship.call("_update_landing", 0.01)
	_check(
		not ship.is_landing_active() and ship.get_telemetry().landing_abort_reason == &"berth_changed",
		"assist aborts berth_changed when the accepted dock transform moves"
	)
	berth.position.x -= 0.5
	_check(not berth.is_reserved(), "moved-berth abort releases the exact snapshotted lease")

	token = berth.try_reserve(ship, ship.get_ship_definition())
	ship.global_transform = berth.get_dock_transform() * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	_check(not token.is_empty() and ship.request_berth_landing(berth), "reparented-berth fixture begins with a bound lease")
	berth.reparent(second_parent, true)
	ship.call("_update_landing", 0.01)
	_check(
		not ship.is_landing_active() and ship.get_telemetry().landing_abort_reason == &"berth_changed",
		"assist aborts berth_changed when the same world-space berth is reparented"
	)
	_check(not berth.is_reserved(), "reparented-berth abort releases the exact snapshotted lease")
	berth.reparent(first_parent, true)

	token = berth.try_reserve(ship, ship.get_ship_definition())
	ship.global_transform = berth.get_dock_transform() * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	_check(not token.is_empty() and ship.request_berth_landing(berth), "released-lease fixture begins with exact token authority")
	_check(berth.release(ship, token), "accepted lease can be adversarially released mid-assist")
	ship.call("_update_landing", 0.01)
	_check(
		not ship.is_landing_active() and ship.get_telemetry().landing_abort_reason == &"reservation_lost",
		"assist aborts reservation_lost before motion after its token is released"
	)
	stage.queue_free()
	await process_frame
	await process_frame


func _test_active_landing_lifecycle_teardown() -> void:
	var destruction_fixture := await _new_active_landing_fixture(
		"LandingDestructionTeardownStage",
		&"landing_destruction_teardown_berth"
	)
	var destruction_stage := destruction_fixture.stage as Node3D
	var destruction_berth := destruction_fixture.berth as ShipBerth
	var destruction_ship := destruction_fixture.ship as HeroShip
	var destruction_reasons := PackedStringArray()
	destruction_ship.landing_aborted.connect(
		func(reason: StringName) -> void: destruction_reasons.append(reason)
	)
	destruction_ship.apply_damage(
		destruction_ship.maximum_hull + 1.0,
		destruction_ship.global_position,
		Vector3.UP
	)
	var destroyed_report := destruction_ship.get_landing_contract_report()
	_check(
		destruction_ship.is_destroyed() and not destruction_ship.is_landing_active(),
		"mid-assist destruction terminates landing authority"
	)
	_check(
		destruction_berth.get_reservation_owner() == null
		and destruction_berth.get_occupant() == null,
		"mid-assist destruction releases the exact pending berth lease"
	)
	_check(
		destruction_reasons == PackedStringArray([&"ship_destroyed"])
		and destruction_ship.get_telemetry().landing_abort_reason == &"ship_destroyed",
		"mid-assist destruction emits one coherent terminal abort reason"
	)
	_check(
		not bool(destroyed_report.contract_accepted)
		and (destroyed_report.berth_id as StringName).is_empty()
		and not bool(destroyed_report.reservation_identity_snapshotted)
		and not bool(destroyed_report.reservation_token_bound),
		"destruction clears every canonical landing acceptance and lease key"
	)
	destruction_ship.apply_damage(
		destruction_ship.maximum_hull + 1.0,
		destruction_ship.global_position,
		Vector3.UP
	)
	_check(
		destruction_reasons.size() == 1 and not destruction_berth.is_reserved(),
		"repeated destruction is idempotent and cannot release or abort twice"
	)
	destruction_stage.queue_free()
	await process_frame
	await process_frame

	var reset_fixture := await _new_active_landing_fixture(
		"LandingResetTeardownStage",
		&"landing_reset_teardown_berth"
	)
	var reset_stage := reset_fixture.stage as Node3D
	var reset_berth := reset_fixture.berth as ShipBerth
	var reset_ship := reset_fixture.ship as HeroShip
	var reset_reasons := PackedStringArray()
	reset_ship.landing_aborted.connect(
		func(reason: StringName) -> void: reset_reasons.append(reason)
	)
	var reset_transform := reset_berth.get_dock_transform()
	reset_ship.reset_for_reuse(reset_transform)
	var reset_telemetry := reset_ship.get_telemetry()
	var reset_report := reset_ship.get_landing_contract_report()
	_check(
		not reset_ship.is_landing_active()
		and bool(reset_telemetry.landed)
		and reset_ship.global_transform.is_equal_approx(reset_transform),
		"mid-assist reset preserves the fresh parked reuse state without landing authority"
	)
	_check(
		reset_berth.get_reservation_owner() == null and reset_berth.get_occupant() == null,
		"mid-assist reset releases the exact pending berth lease"
	)
	_check(
		reset_reasons == PackedStringArray([&"reset_for_reuse"])
		and reset_telemetry.landing_abort_reason == &"",
		"mid-assist reset emits one terminal abort before restoring fresh telemetry"
	)
	_check(
		not bool(reset_telemetry.landing_dock_accepted)
		and not bool(reset_report.active)
		and not bool(reset_report.contract_accepted)
		and not bool(reset_report.strict_dock_acceptance)
		and (reset_report.berth_id as StringName).is_empty()
		and not bool(reset_report.reservation_identity_snapshotted)
		and not bool(reset_report.reservation_token_bound)
		and (reset_report.acceptance as Dictionary).is_empty(),
		"reset cannot present its parked state as an accepted recent landing"
	)
	reset_ship.reset_for_reuse(reset_transform)
	_check(
		reset_reasons.size() == 1 and not reset_berth.is_reserved(),
		"repeated reset is idempotent and cannot release or abort twice"
	)
	reset_stage.queue_free()
	await process_frame
	await process_frame


func _new_active_landing_fixture(stage_name: String, berth_id: StringName) -> Dictionary:
	var stage := Node3D.new()
	stage.name = stage_name
	root.add_child(stage)
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = berth_id
	berth.landing_half_extents = Vector3(12.0, 3.8, 17.0)
	berth.position = Vector3(31.0, 8.0, 14.0)
	stage.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame
	ship.global_transform = berth.get_dock_transform() * Transform3D(
		Basis.IDENTITY,
		Vector3(0.0, 0.0, 2.0)
	)
	ship.velocity = Vector3.ZERO
	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(
		not token.is_empty() and ship.request_berth_landing(berth),
		"%s begins with an active exact-token landing lease" % stage_name
	)
	_check(
		ship.is_landing_active()
		and berth.get_reservation_owner() == ship
		and berth.get_occupant() == null,
		"%s owns pending reservation authority before teardown" % stage_name
	)
	return {"stage": stage, "berth": berth, "ship": ship}


func _test_rotational_obstruction_stall() -> void:
	var stage := Node3D.new()
	stage.name = "RotationalObstructionStage"
	root.add_child(stage)
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = &"rotational_obstruction_berth"
	berth.landing_half_extents = Vector3(12.0, 3.8, 17.0)
	berth.position = Vector3(-42.0, 8.0, -16.0)
	stage.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	var dock := berth.get_dock_transform()
	ship.global_transform = dock * Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), Vector3.ZERO)
	var wall := _static_box(
		stage,
		"RotationSweepWall",
		dock * Vector3(3.5, 0.62, 3.0),
		Vector3(0.24, 0.24, 0.24)
	)
	await physics_frame
	_check(
		not bool(ship.call("_is_landing_pose_obstructed", ship.global_transform))
		and bool(ship.call("_is_landing_pose_obstructed", dock)),
		"wall fixture is clear at the current pose but blocks the dock rotation"
	)
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame
	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(not token.is_empty() and ship.request_berth_landing(berth), "obstructed rotation begins from an otherwise accepted dock contract")
	var basis_before := ship.global_basis
	ship.call("_update_landing", 4.1)
	_check(
		not ship.is_landing_active()
		and ship.get_telemetry().landing_abort_reason == &"approach_obstructed",
		"blocked next pose reaches the bounded obstruction stall abort"
	)
	_check(ship.global_basis.is_equal_approx(basis_before), "obstruction guard prevents direct rotation through the wall")
	_check(berth.get_occupant() == null, "obstructed assist cannot claim berth occupancy")
	_check(not berth.is_reserved(), "obstruction abort releases its still-pending lease")
	wall.queue_free()
	stage.queue_free()
	await process_frame
	await process_frame


func _test_aligned_support_contact() -> void:
	var stage := Node3D.new()
	stage.name = "AlignedSupportContactStage"
	root.add_child(stage)
	var berth := BERTH_SCRIPT.new() as ShipBerth
	berth.berth_id = &"aligned_support_contact_berth"
	berth.landing_half_extents = Vector3(12.0, 3.8, 17.0)
	berth.position = Vector3(44.0, 9.0, 22.0)
	stage.add_child(berth)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	var dock := berth.get_dock_transform()
	# Derive the support height from the complete current collision envelope. A
	# 5 mm overlap models ordinary deck contact without pinning stale gear bounds.
	var collision_bounds := ship.get_landing_collision_report().get("local_bounds", AABB()) as AABB
	var deck_half_height := 0.1
	var deck_center_y := collision_bounds.position.y - deck_half_height + 0.005
	_static_box(
		stage,
		"AlignedLandingDeck",
		dock.origin + Vector3(0.0, deck_center_y, 0.0),
		Vector3(10.0, 0.2, 10.0)
	)
	ship.global_transform = dock
	await physics_frame
	_check(
		bool(ship.call("_is_landing_pose_obstructed", dock)),
		"focused aligned fixture exposes intentional deck contact to the pose query"
	)
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame
	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(not token.is_empty() and ship.request_berth_landing(berth), "aligned deck contact retains an otherwise valid dock contract")
	ship.call("_update_landing", 0.01)
	_check(
		not ship.is_landing_active()
		and bool(ship.get_telemetry().landed)
		and ship.global_transform.is_equal_approx(dock),
		"already-aligned support contact completes instead of becoming a rotation obstruction"
	)
	_check(berth.get_occupant() == ship, "aligned support completion occupies its exact snapshotted lease")
	stage.queue_free()
	await process_frame
	await process_frame


func _test_destruction_audio_ordering() -> void:
	var stage := Node3D.new()
	stage.name = "DestructionAudioOrderingStage"
	root.add_child(stage)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	await process_frame
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	await physics_frame
	await physics_frame
	var rig := ship.get_ship_audio_rig()
	ship.apply_damage(ship.maximum_hull + 1.0, ship.global_position, Vector3.UP)
	var audio_state := rig.get_state_snapshot()
	_check(
		not bool(audio_state.engine_running) and audio_state.last_cue_id == &"destruction",
		"lethal damage silences the engine without replacing the final destruction cue"
	)
	stage.queue_free()
	await process_frame
	await process_frame


func _static_box(
	parent: Node3D,
	node_name: String,
	world_position: Vector3,
	size: Vector3
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


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
		print("LANDING_CLEARANCE_TEST_OK")
		quit(0)
	else:
		print("LANDING_CLEARANCE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
