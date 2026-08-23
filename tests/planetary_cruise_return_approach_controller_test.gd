extends SceneTree

const ControllerType := preload(
	"res://scripts/control/planetary_cruise_physical_controller.gd"
)
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")
const FRAME_GENERATION := 7

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 100.0)
	ship.set_piloted(true)
	await physics_frame

	var controller := ControllerType.new() as PlanetaryCruisePhysicalController
	stage.add_child(controller)
	_check(
		bool(controller.bind_ship(
			ship, FRAME_GENERATION, controller.get_generation()
		).get("accepted", false)),
		"the sole physical cruise controller binds the active craft",
	)
	var target: Variant = _target_for(ship, 1)
	var armed := controller.arm_return_approach(
		target, FRAME_GENERATION, controller.get_generation()
	)
	var armed_state := armed.get("final_approach", {}) as Dictionary
	var fleet_proof := (
		(armed_state.get("target", {}) as Dictionary)
			.get("fleet_corridor_proof", {}) as Dictionary
	)
	_check(
		bool(armed.get("accepted", false))
			and armed_state.get("state_id") == &"armed"
			and armed_state.get("approach_kind") == ControllerType.RETURN_APPROACH_KIND
			and bool(fleet_proof.get("accepted", false))
			and (fleet_proof.get("fleet_ids", []) as Array).size() == 5,
		"one typed target freezes all five hulls inside the 750 km corridor",
	)
	var stale_abort := controller.abort_return_approach(
		&"stale_attempt", 2, controller.get_generation()
	)
	_check(
		not bool(stale_abort.get("accepted", true))
			and stale_abort.get("reason") == &"return_approach_generation_mismatch",
		"a stale target generation cannot abort the armed return",
	)
	var near_mismatch: Vector3 = target.home_target_world_transform.origin \
		+ Vector3(0.00001, 0.0, 0.0)
	_check(
		controller.evaluate_and_submit(
			near_mismatch, false, FRAME_GENERATION, controller.get_generation()
		).get("reason") == &"return_approach_home_target_mismatch",
		"evaluation accepts only the caller-supplied exact home target",
	)

	var completion_reentry: Array[Dictionary] = [{}]
	controller.return_approach_completed.connect(func(_receipt: Dictionary) -> void:
		completion_reentry[0] = controller.evaluate_and_submit(
			target.home_target_world_transform.origin,
			false,
			FRAME_GENERATION,
			controller.get_generation(),
		)
	)
	var before := ship.global_transform
	var completed := controller.evaluate_and_submit(
		target.home_target_world_transform.origin,
		false,
		FRAME_GENERATION,
		controller.get_generation(),
	)
	var receipt := completed.get("completion_receipt", {}) as Dictionary
	var measurement := receipt.get("measurement", {}) as Dictionary
	_check(
		bool(completed.get("accepted", false))
			and completed.get("reason") == &"return_approach_completed"
			and receipt.get("target_id") == ControllerType.RETURN_APPROACH_TARGET_ID
			and int(receipt.get("target_generation", 0)) == 1
			and (receipt.get("target", {}) as Dictionary).get("home_target_id") \
				== &"mudds_shipyards_home",
		"the bounded brake-complete shell produces a typed terminal receipt",
	)
	_check(
		bool(measurement.get("inside_brake_complete_shell", false))
			and bool(measurement.get("full_hull_inside_return_corridor", false))
			and bool(measurement.get("all_five_craft_corridor_proven", false))
			and float(measurement.get("speed_mps", INF)) <= 12.0
			and float(measurement.get("distance_to_home_m", INF)) == 100.0,
		"completion measures shell, live hull, fleet proof, speed, and distance",
	)
	_check(
		ship.global_transform.is_equal_approx(before)
			and (ship.get_planetary_cruise_attachment_report()
				.get("pending_envelope", {}) as Dictionary).is_empty(),
		"terminal measurement performs no teleport or parallel movement command",
	)
	_check(
		not bool(completion_reentry[0].get("accepted", true))
			and completion_reentry[0].get("reason") == &"reentrant_call",
		"completion signal dispatch fences synchronous return re-entry",
	)

	var released := controller.disengage(controller.get_generation(), false)
	var rebound := controller.bind_ship(
		ship, FRAME_GENERATION, controller.get_generation()
	) if bool(released.get("accepted", false)) else {}
	target = _target_for(ship, 2)
	var rearmed := controller.arm_return_approach(
		target, FRAME_GENERATION, controller.get_generation()
	) if bool(rebound.get("accepted", false)) else {}
	_check(
		bool(released.get("accepted", false))
			and bool(rebound.get("accepted", false))
			and bool(rearmed.get("accepted", false))
			and ((rearmed.get("final_approach", {}) as Dictionary)
				.get("target_generation", 0)) == 2,
		"completion-detach-rebind admits one fresh fenced return generation",
	)

	stage.queue_free()
	await process_frame
	_finish()


func _target_for(ship: HeroShip, generation: int) -> Variant:
	var collision_report := ship.get_landing_collision_report()
	var live_bounds := collision_report.get("local_bounds", AABB()) as AABB
	var target := ControllerType.ReturnApproachTarget.new()
	target.target_generation = generation
	target.coordinate_frame_generation = FRAME_GENERATION
	target.home_target_id = &"mudds_shipyards_home"
	target.home_target_world_transform = Transform3D.IDENTITY
	target.corridor_half_extents_m = Vector3(100.0, 100.0, 750_000.0)
	target.brake_shell_min_distance_m = 50.0
	target.brake_shell_max_distance_m = 150.0
	target.maximum_speed_mps = 12.0
	target.maximum_attitude_degrees = 12.0
	target.hull_margin_m = 0.05
	target.active_ship_id = ship.get_ship_id()
	target.collision_bounds = live_bounds
	target.fleet_collision_bounds = {
		&"torrent_provisional": live_bounds,
		&"arrow_provisional": AABB(Vector3(-8.0, -3.0, -14.0), Vector3(16.0, 6.0, 28.0)),
		&"jovian_provisional": AABB(Vector3(-15.0, -6.0, -24.0), Vector3(30.0, 12.0, 48.0)),
		&"zenith_b7_observed": AABB(Vector3(-7.0, -3.0, -13.0), Vector3(14.0, 6.0, 26.0)),
		&"halyard_new_design": AABB(Vector3(-18.0, -8.0, -30.0), Vector3(36.0, 16.0, 60.0)),
	}
	return target


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("PLANETARY_CRUISE_RETURN_APPROACH_CONTROLLER_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_CRUISE_RETURN_APPROACH_CONTROLLER_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print("PLANETARY_CRUISE_RETURN_APPROACH_CONTROLLER_TEST_FAILED: %d/%d" % [
		_failures.size(), _checks,
	])
	quit(1)
