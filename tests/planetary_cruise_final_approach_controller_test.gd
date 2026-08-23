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

	stage.queue_free()
	await process_frame
	_finish()


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
