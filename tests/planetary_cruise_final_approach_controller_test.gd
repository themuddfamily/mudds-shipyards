extends SceneTree

const ControllerType := preload(
	"res://scripts/control/planetary_cruise_physical_controller.gd"
)
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const FRAME_GENERATION := 7

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 100.0, 0.0)
	ship.set_piloted(true)
	await physics_frame

	var controller := ControllerType.new() as PlanetaryCruisePhysicalController
	stage.add_child(controller)
	var bound := controller.bind_ship(
		ship, FRAME_GENERATION, controller.get_generation()
	)
	_check(bool(bound.get("accepted", false)), "controller binds the live HeroShip")

	var collision_report: Dictionary = ship.get_landing_collision_report()
	var target := ControllerType.FinalApproachTarget.new()
	target.target_generation = 1
	target.coordinate_frame_generation = FRAME_GENERATION
	target.location_generation = 3
	target.landing_root_instance_id = stage.get_instance_id()
	target.corridor_id = &"caldera_approach"
	target.target_pad_id = &"caldera_pad"
	target.target_world_transform = ship.global_transform
	target.corridor_half_extents_m = Vector3(45.0, 60.0, 300.0)
	target.entry_position_half_extents_m = Vector3(42.0, 25.0, 75.0)
	target.maximum_speed_mps = 12.0
	target.maximum_attitude_degrees = 12.0
	target.hull_margin_m = 0.05
	target.collision_bounds = collision_report.get("local_bounds", AABB()) as AABB
	var armed := controller.arm_final_approach(
		target, FRAME_GENERATION, controller.get_generation()
	)
	_check(
		bool(armed.get("accepted", false))
			and (armed.get("final_approach", {}) as Dictionary).get("state_id") == &"armed",
		"typed current-generation target arms exactly once",
	)
	var stale_abort := controller.abort_final_approach(
		&"stale_attempt", 2, controller.get_generation()
	)
	_check(
		not bool(stale_abort.get("accepted", true))
			and stale_abort.get("reason") == &"final_approach_generation_mismatch",
		"stale target generation cannot mutate the armed lifecycle",
	)

	# A short canonical destination produces the existing long-leg brake-shell
	# decision. The same call activates the armed retarget, measures the exact
	# accepted corridor, and returns a typed completion without moving the ship.
	var before := ship.global_transform
	var completed := controller.evaluate_and_submit(
		ship.global_position + Vector3.FORWARD * 30_000.0,
		false,
		FRAME_GENERATION,
		controller.get_generation(),
	)
	var receipt := completed.get("completion_receipt", {}) as Dictionary
	_check(
		bool(completed.get("accepted", false))
			and completed.get("reason") == &"final_approach_completed"
			and receipt.get("target_id") == &"FINAL_APPROACH"
			and int(receipt.get("target_generation", 0)) == 1,
		"brake shell switches to FINAL_APPROACH and emits its fenced receipt",
	)
	var measurement := receipt.get("measurement", {}) as Dictionary
	_check(
		float(measurement.get("speed_mps", INF)) <= 12.0
			and float(measurement.get("attitude_degrees", INF)) <= 12.0
			and bool(measurement.get("root_inside_entry_volume", false))
			and bool(measurement.get("full_hull_inside_authored_corridor", false)),
		"completion freezes the exact accepted position, hull, speed, and attitude",
	)
	_check(
		ship.global_transform.is_equal_approx(before)
			and (ship.get_planetary_cruise_attachment_report()
				.get("pending_envelope", {}) as Dictionary).is_empty(),
		"completion itself performs no teleport, transform write, or extra command",
	)
	var snapshot := controller.get_snapshot().get("final_approach", {}) as Dictionary
	_check(
		snapshot.get("state_id") == &"completed"
			and not (snapshot.get("last_completion_receipt", {}) as Dictionary).is_empty(),
		"controller retains a detached completion receipt for the binding handoff",
	)
	var released := controller.disengage(controller.get_generation(), false)
	var detached_final := controller.get_snapshot().get("final_approach", {}) as Dictionary
	_check(
		bool(released.get("accepted", false))
			and detached_final.get("state_id") == &"none"
			and int(detached_final.get("target_generation", -1)) == 0
			and (detached_final.get("last_completion_receipt", {}) as Dictionary).is_empty(),
		"completed release clears terminal target state and the controller-local receipt",
	)
	var rebound := controller.bind_ship(
		ship, FRAME_GENERATION, controller.get_generation()
	)
	target.target_generation = 2
	var rearmed := controller.arm_final_approach(
		target, FRAME_GENERATION, controller.get_generation()
	) if bool(rebound.get("accepted", false)) else {}
	_check(
		bool(rebound.get("accepted", false))
			and bool(rearmed.get("accepted", false))
			and ((rearmed.get("final_approach", {}) as Dictionary)
				.get("state_id", &"")) == &"armed",
		"complete-detach-rebind admits one fresh generation-fenced target",
	)
	ship.global_position = target.target_world_transform.origin + Vector3(8.0, 30.0, 80.0)
	var converging := controller.evaluate_and_submit(
		ship.global_position + Vector3.FORWARD * 30_000.0,
		false,
		FRAME_GENERATION,
		controller.get_generation(),
	)
	var converging_measurement := converging.get(
		"final_approach_measurement", {}
	) as Dictionary
	_check(
		bool(converging.get("accepted", false))
			and converging.get("reason") == &"envelope_submitted"
			and converging_measurement.get("position_offset_entry_local_m") is Vector3
			and (converging_measurement.position_offset_entry_local_m as Vector3)
				.is_equal_approx(Vector3(8.0, 30.0, 80.0))
			and float(converging_measurement.get("attitude_degrees", INF)) == 0.0,
		"converging receipt emits the already-computed entry-local offset and attitude",
	)

	var source_generation := controller.get_generation()
	var before_rebase := controller.get_snapshot().get("final_approach", {}) as Dictionary
	var source_target := (before_rebase.get("target", {}) as Dictionary).get(
		"target_world_transform", Transform3D.IDENTITY) as Transform3D
	var delta := Vector3(20.0, 0.0, -10.0)
	var carried := controller.rebind_coordinate_frame(ship, FRAME_GENERATION + 1, source_generation, delta)
	var after_rebase := controller.get_snapshot().get("final_approach", {}) as Dictionary
	var moved_target := (after_rebase.get("target", {}) as Dictionary).get(
		"target_world_transform", Transform3D.IDENTITY) as Transform3D
	_check(bool(carried.get("accepted", false)) and moved_target.origin == source_target.origin + delta
		and int(controller.get_snapshot().get("coordinate_frame_generation", 0)) == FRAME_GENERATION + 1
		and (ship.get_planetary_cruise_attachment_report().get("pending_envelope", {}) as Dictionary).is_empty(),
		"rebase atomically translates target, advances frame and drops old pending command")
	var replay := controller.rebind_coordinate_frame(ship, FRAME_GENERATION + 1, source_generation, delta)
	_check(not bool(replay.get("accepted", true))
		and controller.get_snapshot().get("final_approach", {}) == after_rebase,
		"replayed rebase cannot translate the target twice")
	var stale_envelope := converging.get("envelope", {}) as Dictionary
	_check(not bool(ship.submit_planetary_cruise_envelope(stale_envelope).get("accepted", true)),
		"ship refuses the retired-frame approach envelope")
	var rejected := controller.rebind_coordinate_frame(ship, FRAME_GENERATION + 3, controller.get_generation(), delta)
	_check(not bool(rejected.get("accepted", true))
		and controller.get_snapshot().get("final_approach", {}) == after_rebase,
		"failed frame rebind leaves approach target unchanged")
	stage.queue_free()
	await process_frame
	await _test_physical_approach()
	await _test_routed_approach()
	_finish()


func _test_physical_approach() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 100.0, 1_000.0)
	ship.set_piloted(true)
	await physics_frame
	var controller := ControllerType.new() as PlanetaryCruisePhysicalController
	stage.add_child(controller)
	controller.bind_ship(ship, FRAME_GENERATION, controller.get_generation())
	var ordinary := controller.evaluate_and_submit(
		ship.global_position + Vector3.FORWARD * 1_000_000.0,
		false, FRAME_GENERATION, controller.get_generation()
	)
	var forged_profile := (ordinary.get("envelope", {}) as Dictionary).duplicate(true)
	forged_profile.sequence += 1
	forged_profile.observation["final_approach"] = true
	_check(ship.submit_planetary_cruise_envelope(forged_profile).get("reason") \
		== &"final_approach_authority_mismatch", "ordinary cruise cannot opt into final approach")
	var target := ControllerType.FinalApproachTarget.new()
	target.target_generation = 1
	target.coordinate_frame_generation = FRAME_GENERATION
	target.location_generation = 3
	target.landing_root_instance_id = stage.get_instance_id()
	target.corridor_id = &"caldera_approach"
	target.target_pad_id = &"caldera_pad"
	target.target_world_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 100.0, 0.0))
	target.corridor_half_extents_m = Vector3(45.0, 60.0, 300.0)
	target.entry_position_half_extents_m = Vector3(42.0, 25.0, 75.0)
	target.maximum_speed_mps = 12.0
	target.maximum_attitude_degrees = 12.0
	target.hull_margin_m = 0.05
	target.collision_bounds = ship.get_landing_collision_report().get("local_bounds", AABB())
	controller.arm_final_approach(target, FRAME_GENERATION, controller.get_generation())
	controller.evaluate_and_submit(target.target_world_transform.origin, false, FRAME_GENERATION, controller.get_generation())
	var start := ship.global_position
	var completion: Dictionary = {}
	var last: Dictionary = {}
	var safe_commands := true
	for tick in 2_000:
		await physics_frame
		last = controller.evaluate_and_submit(
			target.target_world_transform.origin, false, FRAME_GENERATION, controller.get_generation()
		)
		if last.get("reason") == &"final_approach_completed":
			completion = last.get("completion_receipt", {})
			break
		if not bool(last.get("accepted", false)):
			break
		var envelope := last.get("envelope", {}) as Dictionary
		safe_commands = safe_commands and bool(envelope.get("clearance_full_hull", false)) \
			and bool(envelope.get("clearance_verified", false)) \
			and not bool(envelope.get("obstacle_detected", true)) \
			and bool(envelope.get("desired_participation", false))
		if tick == 0:
			var forged := envelope.duplicate(true)
			forged.sequence += 1
			forged.observation.distance_to_destination_meters += 1.0
			_check(ship.submit_planetary_cruise_envelope(forged).get("reason") \
				== &"final_approach_authority_mismatch", "ship rejects a profile aimed away from the active entry")
	_check(not completion.is_empty(), "resting craft physically reaches final approach: %s" % last.get("reason"))
	_check(safe_commands and start.distance_to(ship.global_position) > 900.0,
		"full-hull proved approach moves production Torrent over 900 m without staging")
	var measurement := completion.get("measurement", {}) as Dictionary
	_check(float(measurement.get("speed_mps", INF)) <= 12.0 \
		and bool(measurement.get("full_hull_inside_authored_corridor", false)),
		"moving approach ends at admitted hull clearance and handoff speed")
	# After its target is completed, even the last otherwise valid envelope
	# cannot reclaim the short-leg profile.
	var retired := last.get("envelope", {}) as Dictionary
	if retired.is_empty():
		retired = controller.get_snapshot().get("last_envelope", {})
	retired.sequence += 1
	_check(ship.submit_planetary_cruise_envelope(retired).get("reason") == &"final_approach_authority_mismatch",
		"completed target cannot re-authorize an old approach envelope")
	stage.queue_free()
	await process_frame


func _test_routed_approach() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 500.0, 320.0)
	ship.set_piloted(true)
	await physics_frame
	var controller := ControllerType.new() as PlanetaryCruisePhysicalController
	stage.add_child(controller)
	controller.bind_ship(ship, FRAME_GENERATION, controller.get_generation())
	var target := ControllerType.FinalApproachTarget.new()
	target.target_generation = 1
	target.coordinate_frame_generation = FRAME_GENERATION
	target.location_generation = 3
	target.landing_root_instance_id = stage.get_instance_id()
	target.corridor_id = &"caldera_approach"
	target.target_pad_id = &"caldera_pad"
	target.target_world_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 100.0, 0.0))
	target.corridor_half_extents_m = Vector3(45.0, 60.0, 300.0)
	target.entry_position_half_extents_m = Vector3(42.0, 25.0, 75.0)
	target.maximum_speed_mps = 12.0
	target.maximum_attitude_degrees = 12.0
	target.hull_margin_m = 0.05
	target.collision_bounds = ship.get_landing_collision_report().get("local_bounds", AABB())
	target.lead_in_height_m = 400.0
	controller.arm_final_approach(target, FRAME_GENERATION, controller.get_generation())
	var ceiling := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 0.3, 50.0)
	shape.shape = box
	ceiling.add_child(shape)
	stage.add_child(ceiling)
	ceiling.global_position = Vector3(0.0, 504.4, 310.0)
	controller.evaluate_and_submit(ship.global_position + Vector3.FORWARD * 30_000.0,
		false, FRAME_GENERATION, controller.get_generation())
	var frame := FRAME_GENERATION
	var blocked_ticks := 0
	var translated := false
	var maximum_turn := 0.0
	var turned_down := false
	var last_basis := ship.global_basis
	var last_physics_tick := Engine.get_physics_frames()
	var completion: Dictionary = {}
	var last: Dictionary = {}
	for tick in 4_000:
		await physics_frame
		var elapsed_ticks := maxi(1, Engine.get_physics_frames() - last_physics_tick)
		maximum_turn = maxf(maximum_turn, rad_to_deg(
			Quaternion(last_basis.orthonormalized()).angle_to(Quaternion(ship.global_basis.orthonormalized()))) / elapsed_ticks)
		last_physics_tick = Engine.get_physics_frames()
		last_basis = ship.global_basis
		turned_down = turned_down or (-ship.global_basis.z).dot(Vector3.DOWN) > 0.99
		var attachment := ship.get_planetary_cruise_attachment_report()
		if attachment.get("reason", &"") == &"approach_turn_obstructed":
			blocked_ticks += 1
			if blocked_ticks == 10:
				_check(ship.velocity.is_zero_approx(), "route turn holds still against a blocking rotation pose")
				var old_envelope := attachment.get("last_envelope", {}) as Dictionary
				var turn := controller.get_final_approach_turn_target(old_envelope)
				var turn_basis := turn.get("target_basis", Basis.IDENTITY) as Basis
				_check(turn_basis.x.dot(target.target_world_transform.basis.x) > 0.99
					and rad_to_deg(Quaternion(target.target_world_transform.basis).angle_to(Quaternion(turn_basis))) <= 90.1,
					"vertical descent preserves corridor right axis with a 90 degree pitch instead of inversion")
				var before_destination := controller._final_approach_policy_destination()
				var delta := Vector3(15.0, -20.0, 30.0)
				ship.global_position += delta
				ceiling.global_position += delta
				var rebound := controller.rebind_coordinate_frame(ship, frame + 1, controller.get_generation(), delta)
				frame += 1
				translated = bool(rebound.get("accepted", false)) \
					and controller._final_approach_policy_destination().is_equal_approx(before_destination + delta)
				_check(controller.get_final_approach_turn_target(old_envelope).is_empty(),
					"old frame envelope cannot authorize a route orientation")
				ceiling.queue_free()
		last = controller.evaluate_and_submit(
			target.target_world_transform.origin, false, frame, controller.get_generation())
		if last.get("reason") == &"final_approach_completed":
			completion = last.get("completion_receipt", {})
			break
		if not bool(last.get("accepted", false)):
			break
	_check(blocked_ticks >= 10 and translated, "routed approach retains obstacle hold and atomically translates its active waypoint")
	_check(turned_down and maximum_turn <= 1.05,
		"production physics performs the 90 degree route turn at no more than 60 degrees per second")
	_check(not completion.is_empty(), "routed descent turns back and reaches the typed entry: %s / %s" % [last.get("reason"), ship.get_planetary_cruise_attachment_report().get("reason")])
	# Ascending to the high leg preserves the same authored right axis.
	ship.set_physics_process(false)
	controller.disengage(controller.get_generation(), false)
	ship.global_transform = Transform3D(Basis.IDENTITY,
		target.target_world_transform * Vector3(0.0, target.lead_in_height_m - 20.0, target.corridor_half_extents_m.z))
	ship.velocity = Vector3.ZERO
	controller.bind_ship(ship, frame, controller.get_generation())
	target.target_generation += 1
	controller.arm_final_approach(target, frame, controller.get_generation())
	var ascending := controller.evaluate_and_submit(ship.global_position + Vector3.FORWARD * 30_000.0,
		false, frame, controller.get_generation())
	var ascending_turn := controller.get_final_approach_turn_target(ascending.get("envelope", {}))
	var ascending_basis := ascending_turn.get("target_basis", Basis.IDENTITY) as Basis
	_check(ascending_basis.x.dot(target.target_world_transform.basis.x) > 0.99
		and (-ascending_basis.z).dot(Vector3.UP) > 0.99
		and rad_to_deg(Quaternion.IDENTITY.angle_to(Quaternion(ascending_basis))) <= 90.1,
		"vertical ascent also preserves corridor right axis with a 90 degree pitch")
	# A lateral impulse during the next turn must use normal collision accounting.
	ship.set_physics_process(false)
	controller.disengage(controller.get_generation(), false)
	ship.global_transform = Transform3D(Basis.IDENTITY,
		target.target_world_transform * Vector3(0.0, target.lead_in_height_m, target.corridor_half_extents_m.z))
	ship.velocity = Vector3.ZERO
	controller.bind_ship(ship, frame, controller.get_generation())
	target.target_generation += 1
	controller.arm_final_approach(target, frame, controller.get_generation())
	controller.evaluate_and_submit(ship.global_position + Vector3.FORWARD * 30_000.0,
		false, frame, controller.get_generation())
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.5, 30.0, 30.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	stage.add_child(wall)
	wall.global_position = ship.global_position + Vector3(6.0, 0.0, 0.0)
	await physics_frame
	ship.velocity = Vector3(200.0, 0.0, 0.0)
	controller.evaluate_and_submit(target.target_world_transform.origin, false, frame, controller.get_generation())
	ship._physics_process(1.0 / 60.0)
	var collision_state := ship.get_planetary_cruise_attachment_report()
	_check(collision_state.get("reason") == &"physical_collision"
		and float(ship.get("_impact_cooldown_remaining")) > 0.0,
		"turn braking applies impact damage and retires cruise on a real side collision")
	stage.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("PLANETARY_CRUISE_FINAL_APPROACH_CONTROLLER_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_CRUISE_FINAL_APPROACH_CONTROLLER_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print("PLANETARY_CRUISE_FINAL_APPROACH_CONTROLLER_TEST_FAILED: %d/%d" % [
		_failures.size(), _checks,
	])
	quit(1)
