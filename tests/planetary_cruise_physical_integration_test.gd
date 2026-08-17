extends SceneTree

const ShipCommandSourceType := preload(
	"res://scripts/control/ship_command_source.gd"
)
const ControllerType := preload(
	"res://scripts/control/planetary_cruise_physical_controller.gd"
)
const TORRENT_SCENE := preload(
	"res://scenes/ships/torrent_interceptor.tscn"
)
const FRAME_GENERATION := 7
const DESTINATION_DISTANCE_METERS := 8_000_000.0

var _failures: Array[String] = []
var _checks := 0


class NeutralCommandSource:
	extends ShipCommandSourceType

	var controls: Dictionary = {}
	var sample_count := 0

	func _sample_controls() -> Dictionary:
		sample_count += 1
		return controls.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "PlanetaryCruisePhysicalHarness"
	root.add_child(stage)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.name = "CruiseTorrent"
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 100.0, 0.0)
	var command_source := NeutralCommandSource.new()
	command_source.name = "NeutralCommandSource"
	stage.add_child(command_source)
	ship.set_command_source(command_source)
	ship.set_piloted(true)
	await physics_frame
	await process_frame

	var controller := ControllerType.new() as PlanetaryCruisePhysicalController
	controller.name = "PlanetaryCruisePhysicalController"
	stage.add_child(controller)
	var audit := controller.audit()
	_check(bool(audit.get("valid", false)), "controller composes the valid pure policy")
	_check(
		bool(audit.get("caller_driven", false))
		and not bool(audit.get("has_process_loop", true))
		and audit.get("movement_owner") == &"hero_ship",
		"controller is caller-driven and names HeroShip as movement owner"
	)
	_check(_has_exact_zero_common_authority(audit), "controller common authority is exactly zero")
	var capabilities: Dictionary = audit.get("adjacent_capabilities", {})
	_check(
		bool(capabilities.get("collision_query_request", false))
		and bool(capabilities.get("intent_submission", false))
		and not bool(capabilities.get("velocity_write", true))
		and not bool(capabilities.get("move_and_slide", true))
		and not bool(capabilities.get("transform_write", true)),
		"controller owns proof requests and intent submission but no physical mutation"
	)

	var reentry_receipt := [{}]
	controller.binding_changed.connect(func(_snapshot: Dictionary) -> void:
		reentry_receipt[0] = controller.bind_ship(
			ship,
			FRAME_GENERATION,
			controller.get_generation()
		)
	)
	var bind_generation := controller.get_generation()
	var bind_receipt := controller.bind_ship(
		ship,
		FRAME_GENERATION,
		bind_generation
	)
	_check(bool(bind_receipt.get("accepted", false)), "controller binds one real HeroShip lifecycle")
	_check(
		not bool((reentry_receipt[0] as Dictionary).get("accepted", true))
		and (reentry_receipt[0] as Dictionary).get("reason") == &"reentrant_call",
		"binding signal rejects synchronous mutation reentry after state commit"
	)
	var ship_binding := ship.get_planetary_cruise_attachment_report()
	_check(
		int(ship_binding.get("controller_instance_id", 0)) == controller.get_instance_id()
		and int(ship_binding.get("ship_attachment_generation", 0)) > 0,
		"HeroShip freezes controller identity and attachment generation"
	)

	var destination := ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS
	# HeroShip local forward is -Z, equal to Vector3.FORWARD in Godot.
	var evaluation_reentry := [{}]
	controller.evaluation_committed.connect(func(_snapshot: Dictionary) -> void:
		evaluation_reentry[0] = controller.evaluate_and_submit(
			destination,
			false,
			FRAME_GENERATION,
			bind_generation
		)
	)
	var combat_position := ship.global_position
	var combat_result := controller.evaluate_and_submit(
		destination,
		true,
		FRAME_GENERATION,
		bind_generation
	)
	_check(
		bool(combat_result.get("accepted", false))
		and (combat_result.get("policy", {}) as Dictionary).get("reason") \
			== &"combat_active"
		and not bool((combat_result.get("policy", {}) as Dictionary)
			.get("desired_cruise_participation", true)),
		"caller-supplied combat authority closes cruise participation"
	)
	_check(
		not bool((evaluation_reentry[0] as Dictionary).get("accepted", true))
		and (evaluation_reentry[0] as Dictionary).get("reason") == &"reentrant_call",
		"evaluation signal rejects synchronous controller mutation reentry"
	)
	await physics_frame
	await process_frame
	_check(
		ship.global_position.is_equal_approx(combat_position)
		and ship.get_planetary_cruise_attachment_report().state \
			== HeroShip.PLANETARY_CRUISE_STATE_INACTIVE,
		"combat-gated envelope produces no physical movement"
	)
	controller.queue_free()
	await process_frame
	controller = _bind_new_controller(stage, ship, FRAME_GENERATION)
	bind_generation = controller.get_generation()
	ship_binding = ship.get_planetary_cruise_attachment_report()
	destination = ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS
	var forged_proof := ship.build_planetary_cruise_clearance_proof(
		Vector3.FORWARD,
		DESTINATION_DISTANCE_METERS,
		FRAME_GENERATION,
		int(ship_binding.get("ship_attachment_generation", 0)),
		controller.get_instance_id()
	)
	var valid_candidate := _envelope_from_proof(
		ship,
		controller,
		forged_proof,
		false,
		1
	)
	var forgery_baseline := ship.get_planetary_cruise_attachment_report()
	var speed_forgery := valid_candidate.duplicate(true)
	speed_forgery["desired_speed_meters_per_second"] = 100_000.0
	_check(
		ship.submit_planetary_cruise_envelope(speed_forgery).get("reason") \
			== &"policy_result_mismatch",
		"HeroShip rejects an out-of-policy forged cruise speed"
	)
	var acceleration_forgery := valid_candidate.duplicate(true)
	acceleration_forgery["acceleration_hint_meters_per_second_squared"] = 10_000.0
	_check(
		ship.submit_planetary_cruise_envelope(acceleration_forgery).get("reason") \
			== &"policy_result_mismatch",
		"HeroShip rejects an out-of-policy forged acceleration"
	)
	var braking_forgery := valid_candidate.duplicate(true)
	braking_forgery["braking_requested"] = true
	braking_forgery["braking_acceleration_hint_meters_per_second_squared"] = 750.0
	_check(
		ship.submit_planetary_cruise_envelope(braking_forgery).get("reason") \
			== &"policy_result_mismatch",
		"HeroShip rejects braking fields that do not match the pure policy result"
	)
	var proof_forgery := valid_candidate.duplicate(true)
	proof_forgery["clearance_full_hull"] = false
	_check(
		ship.submit_planetary_cruise_envelope(proof_forgery).get("reason") \
			== &"clearance_proof_flags_mismatch",
		"HeroShip rejects asserted proof flags that differ from its minted capability"
	)
	_check(
		ship.get_planetary_cruise_attachment_report() == forgery_baseline,
		"all forged-envelope rejections preserve byte-equivalent ship cruise state"
	)
	ship.velocity = Vector3.FORWARD \
		* (PlanetaryCruisePolicy.TARGET_CRUISE_SPEED_METERS_PER_SECOND + 100.0)
	var overspeed_before := ship.velocity.length()
	var overspeed_result := controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	var overspeed_policy: Dictionary = overspeed_result.get("policy", {})
	_check(
		bool(overspeed_result.get("accepted", false))
		and float(overspeed_policy.get(
			"acceleration_hint_meters_per_second_squared", 0.0
		)) == -PlanetaryCruisePolicy.BRAKING_HINT_METERS_PER_SECOND_SQUARED
		and bool(overspeed_policy.get("braking_requested", false)),
		"legitimate overspeed policy envelope is accepted as brake-to-target"
	)
	await physics_frame
	await process_frame
	var overspeed_state := ship.get_planetary_cruise_attachment_report()
	_check(
		overspeed_state.state == HeroShip.PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED,
		"overspeed physics enters braking_to_speed (actual %s/%s)" % [
			overspeed_state.state,
			overspeed_state.reason,
		]
	)
	_check(
		absf(
			ship.velocity.length()
			- (
				overspeed_before \
				- PlanetaryCruisePolicy.BRAKING_HINT_METERS_PER_SECOND_SQUARED \
					* ship.get_physics_process_delta_time()
			)
		) <= 0.02,
		"HeroShip applies exact bounded overspeed braking (actual %.6f, before %.6f, dt %.9f)" % [
			ship.velocity.length(),
			overspeed_before,
			ship.get_physics_process_delta_time(),
		]
	)
	ship.velocity = Vector3.ZERO
	_check(
		bool(controller.disengage(bind_generation, false).get("accepted", false)),
		"overspeed mode can be explicitly retired without a parallel movement path"
	)
	controller.queue_free()
	await process_frame
	controller = _bind_new_controller(stage, ship, FRAME_GENERATION)
	bind_generation = controller.get_generation()
	ship_binding = ship.get_planetary_cruise_attachment_report()
	destination = ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS
	var superseded_position := ship.global_position
	var superseded_result := controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	_check(bool(superseded_result.get("accepted", false)), "proof A queues before supersession witness")
	var malformed_newest_proof := ship.build_planetary_cruise_clearance_proof(
		Vector3.ZERO,
		DESTINATION_DISTANCE_METERS,
		FRAME_GENERATION,
		int(ship_binding.get("ship_attachment_generation", 0)),
		controller.get_instance_id()
	)
	_check(
		not bool(malformed_newest_proof.get("accepted", true))
		and malformed_newest_proof.get("reason") == &"direction_not_normalized",
		"newest malformed proof request is rejected explicitly"
	)
	await physics_frame
	await process_frame
	_check(
		ship.global_position.is_equal_approx(superseded_position)
		and ship.velocity.is_zero_approx()
		and ship.get_planetary_cruise_attachment_report().state \
			== HeroShip.PLANETARY_CRUISE_STATE_INACTIVE,
		"proof B request tombstones queued envelope A before HeroShip physics"
	)
	var pre_submit_position := ship.global_position
	var pre_submit_velocity := ship.velocity
	var pre_submit_basis := ship.global_basis
	var clear_result := controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	_check(bool(clear_result.get("accepted", false)), "clear eight-megametre route submits an envelope")
	var clear_proof: Dictionary = clear_result.get("proof", {})
	var landing_collision := ship.get_landing_collision_report()
	_check(
		bool(clear_proof.get("clearance_verified", false))
		and bool(clear_proof.get("clearance_full_hull", false))
		and not bool(clear_proof.get("obstacle_detected", true))
		and int(clear_proof.get("enabled_shape_count", 0)) \
			== int(landing_collision.get("shape_count", -1))
		and int(clear_proof.get("queried_shape_count", 0)) \
			== int(landing_collision.get("shape_count", -1)),
		"clearance proof queries every enabled direct HeroShip hull shape"
	)
	_check(
		is_equal_approx(
			float(clear_proof.get("verified_clearance_meters", 0.0)),
			PlanetaryCruisePhysicalController.CLEARANCE_PROOF_HORIZON_METERS
		)
		and int(clear_proof.get("coordinate_frame_generation", 0)) == FRAME_GENERATION
		and (clear_proof.get("fixed_orientation_basis", Basis()) as Basis).is_equal_approx(
			pre_submit_basis
		),
		"clear proof freezes exact distance, current frame generation, and physical basis"
	)
	_check(
		ship.global_position.is_equal_approx(pre_submit_position)
		and ship.velocity.is_equal_approx(pre_submit_velocity),
		"policy evaluation and envelope queueing do not move or accelerate the ship"
	)
	var detached_result := clear_result.duplicate(true)
	(detached_result.get("proof", {}) as Dictionary)["enabled_shape_count"] = -99
	_check(
		int((controller.get_snapshot().get("last_result", {}) as Dictionary)
			.get("proof", {}).get("enabled_shape_count", 0)) > 0,
		"controller snapshots are deeply detached"
	)

	await physics_frame

	await process_frame
	var physics_delta := ship.get_physics_process_delta_time()
	var first_speed := ship.velocity.length()
	_check(
		first_speed > 0.0
		and first_speed <= PlanetaryCruisePolicy.ACCELERATION_HINT_METERS_PER_SECOND_SQUARED \
			* physics_delta + 0.01,
		"HeroShip bounds first-tick cruise acceleration by the policy hint"
	)
	_check(
		ship.global_basis.is_equal_approx(pre_submit_basis)
		and ship.global_position.z < pre_submit_position.z,
		"HeroShip preserves orientation and performs the physical move itself"
	)
	_check(
		StringName(ship.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE,
		"fresh physical cruise demand wakes the existing automatic engine path"
	)
	var explicit_speed := ship.velocity.length()
	var explicit_receipt := controller.disengage(bind_generation, true)
	_check(
		bool(explicit_receipt.get("accepted", false))
		and explicit_receipt.get("reason") == &"braking"
		and ship.get_planetary_cruise_attachment_report().state \
			== HeroShip.PLANETARY_CRUISE_STATE_BRAKING,
		"explicit disengage commits HeroShip-owned braking and retires the controller"
	)
	await physics_frame
	await process_frame
	var explicit_expected_speed := maxf(
		explicit_speed
			- PlanetaryCruisePolicy.BRAKING_HINT_METERS_PER_SECOND_SQUARED \
				* physics_delta,
		0.0
	)
	_check(
		absf(ship.velocity.length() - explicit_expected_speed) <= 0.02
		and ship.get_planetary_cruise_attachment_report().state \
			== HeroShip.PLANETARY_CRUISE_STATE_INACTIVE,
		"explicit disengage uses the exact bounded brake and clamps without reversal"
	)
	controller.queue_free()
	await process_frame
	controller = _bind_new_controller(stage, ship, FRAME_GENERATION)
	bind_generation = controller.get_generation()
	destination = ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS
	var resumed_result := controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	_check(bool(resumed_result.get("accepted", false)), "fresh binding re-engages after completed braking")
	await physics_frame
	await process_frame
	for _cadence_step in 3:
		controller.evaluate_and_submit(
			destination,
			false,
			FRAME_GENERATION,
			bind_generation
		)
		await physics_frame
		await process_frame
	var missing_cadence_speed := ship.velocity.length()
	await physics_frame
	await process_frame
	var missing_cadence_report := ship.get_planetary_cruise_attachment_report()
	_check(
		missing_cadence_report.get("state") == HeroShip.PLANETARY_CRUISE_STATE_BRAKING
		and missing_cadence_report.get("reason") == &"fresh_envelope_missing"
		and absf(
			ship.velocity.length()
			- maxf(
				missing_cadence_speed \
					- PlanetaryCruisePolicy.BRAKING_HINT_METERS_PER_SECOND_SQUARED \
						* physics_delta,
				0.0
			)
		) <= 0.02,
		"missing proof cadence fails closed into the exact bounded brake"
	)
	while ship.velocity.length() > 0.0:
		await physics_frame
		await process_frame
	controller.queue_free()
	await process_frame
	controller = _bind_new_controller(stage, ship, FRAME_GENERATION)
	bind_generation = controller.get_generation()
	destination = ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS
	controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	await physics_frame
	await process_frame

	# A high, narrow blocker intersects the upper-silhouette collider but not the
	# lower main hull. Detecting it demonstrates that the proof is not a chosen-
	# shape or centre-ray shortcut.
	var upper_blocker := _make_blocker(
		"UpperHullOnlyBlocker",
		Vector3(1.0, 0.2, 20.0),
		ship.global_position + Vector3(0.0, 3.55, -100.0)
	)
	(upper_blocker.get_child(0) as CollisionShape3D).disabled = true
	stage.add_child(upper_blocker)
	# Keep the active cadence current while the newly added physics body enters
	# the broadphase; that tick still uses the pre-insertion clear proof.
	controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	(upper_blocker.get_child(0) as CollisionShape3D).disabled = false
	await physics_frame
	await process_frame
	var obstructed_result := controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		bind_generation
	)
	var obstructed_policy: Dictionary = obstructed_result.get("policy", {})
	var obstructed_proof: Dictionary = obstructed_result.get("proof", {})
	_check(
		bool(obstructed_result.get("accepted", false))
		and bool(obstructed_proof.get("obstacle_detected", false))
		and obstructed_policy.get("reason") == &"obstacle_detected",
		"non-leading obstruction result accepted=%s reason=%s proof_obstacle=%s clearance=%.3f policy=%s" % [
			obstructed_result.get("accepted"),
			obstructed_result.get("reason"),
			obstructed_proof.get("obstacle_detected"),
			float(obstructed_proof.get("verified_clearance_meters", -1.0)),
			obstructed_policy.get("reason"),
		]
	)
	var speed_before_brake := ship.velocity.length()
	await physics_frame
	await process_frame
	var speed_after_brake := ship.velocity.length()
	_check(
		speed_after_brake <= speed_before_brake
		and speed_after_brake >= 0.0
		and speed_before_brake - speed_after_brake \
			<= PlanetaryCruisePolicy.BRAKING_HINT_METERS_PER_SECOND_SQUARED \
				* physics_delta + 0.02,
		"obstacle brake actual %.6f -> %.6f state=%s/%s" % [
			speed_before_brake,
			speed_after_brake,
			ship.get_planetary_cruise_attachment_report().state,
			ship.get_planetary_cruise_attachment_report().reason,
		]
	)
	upper_blocker.queue_free()
	await physics_frame
	await process_frame

	# A fresh lifecycle proves closed initial-overlap semantics without submitting
	# a forged policy observation.
	controller.queue_free()
	await process_frame
	var overlap_controller := _bind_new_controller(stage, ship, FRAME_GENERATION)
	var overlap_generation := overlap_controller.get_generation()
	# Keep the CharacterBody solver from depenetrating the deliberate fixture
	# during the synchronization frame; the proof itself remains a live World3D
	# query against the real enabled HeroShip shapes.
	ship.set_physics_process(false)
	var overlap_blocker := _make_blocker(
		"PortPropulsionInitialOverlap",
		Vector3(0.4, 0.4, 0.4),
		ship.global_position + ship.global_basis * Vector3(-2.5, 1.1, 3.25)
	)
	stage.add_child(overlap_blocker)
	await physics_frame
	await process_frame
	var overlap_report := ship.build_planetary_cruise_clearance_proof(
		Vector3.FORWARD,
		DESTINATION_DISTANCE_METERS,
		FRAME_GENERATION,
		int(ship.get_planetary_cruise_attachment_report().ship_attachment_generation),
		overlap_controller.get_instance_id()
	)
	_check(
		bool(overlap_report.get("accepted", false))
		and bool(overlap_report.get("obstacle_detected", false))
		and is_zero_approx(float(overlap_report.get("verified_clearance_meters", -1.0))),
		"initial-overlap proof accepted=%s reason=%s obstacle=%s clearance=%.6f" % [
			overlap_report.get("accepted"),
			overlap_report.get("reason"),
			overlap_report.get("obstacle_detected"),
			float(overlap_report.get("verified_clearance_meters", -1.0)),
		]
	)
	overlap_blocker.queue_free()
	await physics_frame
	await process_frame
	ship.set_physics_process(true)
	_check(
		not bool(overlap_controller.evaluate_and_submit(
			destination,
			false,
			FRAME_GENERATION + 1,
			overlap_generation
		).get("accepted", true)),
		"controller rejects a coordinate generation different from its binding"
	)

	# Prove immediate post-move collision retirement: the envelope sees a clear
	# route, then the harness inserts a body before HeroShip's next physics step.
	var collision_result := overlap_controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		overlap_generation
	)
	_check(bool(collision_result.get("accepted", false)), "fresh clear intent queues before collision witness")
	ship.velocity = Vector3.FORWARD * 20.0
	var collision_wall := _make_blocker(
		"LateCollisionWall",
		Vector3(20.0, 20.0, 0.5),
		ship.global_position + Vector3(0.0, 0.0, -5.0)
	)
	stage.add_child(collision_wall)
	await physics_frame
	await process_frame
	var collision_state := ship.get_planetary_cruise_attachment_report()
	_check(
		collision_state.get("state") == HeroShip.PLANETARY_CRUISE_STATE_INACTIVE
		and collision_state.get("reason") == &"physical_collision",
		"actual CharacterBody collision retires cruise in the same HeroShip tick"
	)
	collision_wall.queue_free()
	await physics_frame
	await process_frame

	# Pilot, landing, destruction, reset, and tree lifecycle boundaries all
	# tombstone a previously valid envelope.
	overlap_controller.queue_free()
	await process_frame
	ship.velocity = Vector3.ZERO
	var lifecycle_controller := _bind_new_controller(stage, ship, FRAME_GENERATION)
	var lifecycle_generation := lifecycle_controller.get_generation()
	var lifecycle_result := lifecycle_controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		lifecycle_generation
	)
	var stale_envelope: Dictionary = lifecycle_result.get("envelope", {}).duplicate(true)
	var before_unpilot_generation := int(
		ship.get_planetary_cruise_attachment_report().ship_attachment_generation
	)
	ship.set_piloted(false)
	var after_unpilot_generation := int(
		ship.get_planetary_cruise_attachment_report().ship_attachment_generation
	)
	_check(after_unpilot_generation > before_unpilot_generation, "unpilot advances cruise lifecycle generation")
	_check(
		ship.submit_planetary_cruise_envelope(stale_envelope).get("reason") \
			== &"attachment_generation_mismatch",
		"pre-unpilot envelope cannot regain physical authority"
	)
	ship.set_piloted(true)
	lifecycle_controller.queue_free()
	await process_frame
	var landing_controller := _bind_new_controller(stage, ship, FRAME_GENERATION)
	var landing_generation := landing_controller.get_generation()
	var landing_result := landing_controller.evaluate_and_submit(
		destination,
		false,
		FRAME_GENERATION,
		landing_generation
	)
	await physics_frame
	await process_frame
	ship.velocity = Vector3.ZERO
	_check(
		ship.request_landing(Transform3D(ship.global_basis, ship.global_position)),
		"real HeroShip accepts a local landing request for the lifecycle gate"
	)
	_check(
		ship.get_planetary_cruise_attachment_report().state \
			== HeroShip.PLANETARY_CRUISE_STATE_INACTIVE
		and ship.submit_planetary_cruise_envelope(
			landing_result.get("envelope", {})
		).get("reason") == &"attachment_generation_mismatch",
		"landing start retires cruise and rejects its prior envelope"
	)
	ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(0.0, 100.0, 0.0)))
	var reset_generation := int(
		ship.get_planetary_cruise_attachment_report().ship_attachment_generation
	)
	_check(reset_generation > after_unpilot_generation, "reuse reset advances the cruise lifecycle")
	ship.set_piloted(true)
	landing_controller.queue_free()
	await process_frame
	var destruction_controller := _bind_new_controller(stage, ship, FRAME_GENERATION)
	var destruction_result := destruction_controller.evaluate_and_submit(
		ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS,
		false,
		FRAME_GENERATION,
		destruction_controller.get_generation()
	)
	ship.apply_damage(ship.maximum_hull * 2.0)
	_check(
		ship.is_destroyed()
		and ship.get_planetary_cruise_attachment_report().reason == &"ship_destroyed"
		and ship.submit_planetary_cruise_envelope(
			destruction_result.get("envelope", {})
		).get("reason") == &"attachment_generation_mismatch",
		"destruction terminalizes physical cruise before emitting ship destruction"
	)

	await process_frame
	ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(0.0, 100.0, 0.0)))
	ship.set_piloted(true)
	destruction_controller.queue_free()
	await process_frame
	var detach_controller := _bind_new_controller(stage, ship, FRAME_GENERATION)
	var detach_generation := detach_controller.get_generation()
	var before_detach_attachment := int(
		ship.get_planetary_cruise_attachment_report().ship_attachment_generation
	)
	stage.remove_child(ship)
	var detached_report := ship.get_planetary_cruise_attachment_report()
	_check(
		not bool(detached_report.get("inside_tree", true))
		and int(detached_report.get("ship_attachment_generation", 0)) \
			> before_detach_attachment,
		"ship detach freezes physics and tombstones the attached controller"
	)
	stage.add_child(ship)
	await physics_frame
	await process_frame
	_check(
		not bool(detach_controller.evaluate_and_submit(
			ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS,
			false,
			FRAME_GENERATION,
			detach_generation
		).get("accepted", true)),
		"whole-tree re-entry requires a fresh attachment and clearance proof"
	)

	# Ordinary command flight remains the default after all cruise state is gone.
	detach_controller.queue_free()
	await process_frame
	ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(0.0, 100.0, 0.0)))
	ship.set_piloted(true)
	var manual_controller := _bind_new_controller(stage, ship, FRAME_GENERATION)
	var manual_result := manual_controller.evaluate_and_submit(
		ship.global_position + Vector3.FORWARD * DESTINATION_DISTANCE_METERS,
		false,
		FRAME_GENERATION,
		manual_controller.get_generation()
	)
	_check(bool(manual_result.get("accepted", false)), "manual takeover witness starts with a valid cruise envelope")
	command_source.controls = {
		"throttle": 1.0,
		"yaw": 0.0,
		"pitch": 0.0,
		"roll": 0.0,
		"look_yaw_delta": 0.0,
		"look_pitch_delta": 0.0,
	}
	var standard_start := ship.global_position
	await physics_frame
	await process_frame
	var standard_report := ship.get_planetary_cruise_attachment_report()
	_check(
		ship.velocity.length() > 0.0,
		"manual takeover produces ordinary velocity (actual %.6f)" % ship.velocity.length()
	)
	_check(
		ship.velocity.length() <= ship.thrust_acceleration * physics_delta + 0.02,
		"manual takeover remains within ordinary thrust bound (actual %.6f)" % ship.velocity.length()
	)
	_check(
		ship.global_position.z < standard_start.z,
		"manual takeover moves along the visible standard-flight nose (%.6f -> %.6f)" % [
			standard_start.z,
			ship.global_position.z,
		]
	)
	_check(
		standard_report.get("state") == HeroShip.PLANETARY_CRUISE_STATE_INACTIVE
		and standard_report.get("reason") == &"manual_flight_command"
		and int(standard_report.get("controller_instance_id", -1)) == 0,
		"manual flight retires pending cruise (actual %s/%s/controller %d)" % [
			standard_report.get("state"),
			standard_report.get("reason"),
			int(standard_report.get("controller_instance_id", -1)),
		]
	)

	stage.queue_free()
	await process_frame
	_finish()


func _envelope_from_proof(
	ship: HeroShip,
	controller: PlanetaryCruisePhysicalController,
	proof: Dictionary,
	combat_active: bool,
	sequence: int
) -> Dictionary:
	var frame_generation := int(proof.get("coordinate_frame_generation", 0))
	var observation := {
		"distance_to_destination_meters": float(
			proof.get("sweep_distance_meters", 0.0)
		),
		"ship_speed_meters_per_second": float(
			proof.get("ship_speed_meters_per_second", 0.0)
		),
		"closing_speed_meters_per_second": float(
			proof.get("closing_speed_meters_per_second", 0.0)
		),
		"alignment_basis": StringName(proof.get("alignment_basis", &"")),
		"alignment_dot": float(proof.get("alignment_dot", 0.0)),
		"coordinate_frame_generation": frame_generation,
		"verified_clearance_meters": float(
			proof.get("verified_clearance_meters", 0.0)
		),
		"clearance_sweep_distance_meters": float(
			proof.get("sweep_distance_meters", 0.0)
		),
		"clearance_proof_generation": frame_generation,
		"clearance_sweep_basis": PlanetaryCruisePolicy.CLEARANCE_SWEEP_BASIS,
		"clearance_full_hull": bool(proof.get("clearance_full_hull", false)),
		"clearance_verified": bool(proof.get("clearance_verified", false)),
		"obstacle_detected": bool(proof.get("obstacle_detected", false)),
		"currently_participating": bool(
			proof.get("currently_participating", false)
		),
		"piloted": ship.is_piloted(),
		"destroyed": ship.is_destroyed(),
		"landing_active": ship.is_landing_active(),
		"combat_active": combat_active,
	}.duplicate(true)
	var policy_result := PlanetaryCruisePolicy.new().evaluate(
		observation,
		frame_generation
	)
	return {
		"schema_version": HeroShip.PLANETARY_CRUISE_ENVELOPE_SCHEMA_VERSION,
		"ship_instance_id": ship.get_instance_id(),
		"ship_attachment_generation": int(
			proof.get("ship_attachment_generation", 0)
		),
		"controller_instance_id": controller.get_instance_id(),
		"controller_generation": controller.get_generation(),
		"sequence": sequence,
		"coordinate_frame_generation": frame_generation,
		"destination_direction_world": proof.get("direction_world", Vector3.ZERO),
		"desired_participation": bool(
			policy_result.get("desired_cruise_participation", false)
		),
		"desired_speed_meters_per_second": float(
			policy_result.get("desired_speed_meters_per_second", 0.0)
		),
		"acceleration_hint_meters_per_second_squared": float(
			policy_result.get(
				"acceleration_hint_meters_per_second_squared", 0.0
			)
		),
		"braking_requested": bool(
			policy_result.get("braking_requested", false)
		),
		"braking_acceleration_hint_meters_per_second_squared": float(
			policy_result.get(
				"braking_acceleration_hint_meters_per_second_squared", 0.0
			)
		),
		"policy_reason": StringName(policy_result.get("reason", &"")),
		"observation": observation.duplicate(true),
		"clearance_proof_sequence": int(proof.get("proof_sequence", 0)),
		"clearance_proof_generation": frame_generation,
		"clearance_full_hull": bool(proof.get("clearance_full_hull", false)),
		"clearance_verified": bool(proof.get("clearance_verified", false)),
		"obstacle_detected": bool(proof.get("obstacle_detected", false)),
	}.duplicate(true)


func _bind_new_controller(
	stage: Node3D,
	ship: HeroShip,
	frame_generation: int
) -> PlanetaryCruisePhysicalController:
	var controller := ControllerType.new() as PlanetaryCruisePhysicalController
	controller.name = "CruiseController%d" % controller.get_instance_id()
	stage.add_child(controller)
	var receipt := controller.bind_ship(
		ship,
		frame_generation,
		controller.get_generation()
	)
	_check(bool(receipt.get("accepted", false)), "fresh controller binds current ship lifecycle")
	return controller


func _make_blocker(
	blocker_name: String,
	size: Vector3,
	world_position: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = blocker_name
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = PhysicsLayers.NONE
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % blocker_name
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	body.position = world_position
	return body


func _has_exact_zero_common_authority(audit: Dictionary) -> bool:
	const KEYS := [
		"renderer", "gameplay", "streaming", "save", "network", "physics",
		"world_generation", "terrain_generation", "collision_generation",
		"origin_shift", "weather_clock", "audio",
	]
	var authority: Dictionary = audit.get("common_authority", {})
	if authority.size() != KEYS.size():
		return false
	for key in KEYS:
		if not authority.has(key) or not authority[key] is bool or bool(authority[key]):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("PLANETARY_CRUISE_PHYSICAL_INTEGRATION_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_CRUISE_PHYSICAL_INTEGRATION_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print(
		"PLANETARY_CRUISE_PHYSICAL_INTEGRATION_TEST_FAILED: %d/%d assertions" % [
			_failures.size(),
			_checks,
		]
	)
	quit(1)
