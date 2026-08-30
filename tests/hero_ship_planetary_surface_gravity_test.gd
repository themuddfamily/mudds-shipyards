extends SceneTree

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const ShipCommandType := preload("res://scripts/control/ship_command.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture := Node3D.new()
	fixture.name = "PlanetarySurfaceGravityFixture"
	root.add_child(fixture)
	var source := Node.new()
	source.name = "SurfaceGravitySource"
	fixture.add_child(source)
	var cruise_controller := Node.new()
	cruise_controller.name = "CruiseController"
	fixture.add_child(cruise_controller)
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	fixture.add_child(ship)
	ship.set_physics_process(false)
	ship.global_position = Vector3(1000.0, 1000.0, 1000.0)
	ship.set("_landed", false)
	await process_frame

	var attached := ship.attach_planetary_surface_gravity(
		source.get_instance_id(), 7
	)
	var report := ship.get_planetary_surface_gravity_report()
	_check(
		bool(attached.get("accepted", false))
			and bool(report.get("attached", false))
			and int(report.get("source_instance_id", 0)) == source.get_instance_id()
			and int(report.get("source_generation", 0)) == 7
			and bool(report.get("body_owns_velocity", false))
			and bool(report.get("body_owns_move_and_slide", false)),
		"one live source attaches without receiving ship movement authority",
	)

	var forged := ship.submit_planetary_surface_gravity_sample(
		cruise_controller.get_instance_id(), 7, 1, Vector3.DOWN * 9.8
	)
	var invalid := ship.submit_planetary_surface_gravity_sample(
		source.get_instance_id(), 7, 1, Vector3(NAN, 0.0, 0.0)
	)
	_check(
		forged.get("reason") == &"source_identity_mismatch"
			and invalid.get("reason") == &"gravity_vector_out_of_bounds"
			and int(ship.get_planetary_surface_gravity_report().get(
				"last_sequence", -1
			)) == 0,
		"forged identity and non-finite gravity reject without advancing the stream",
	)

	var gravity := Vector3(-10.0, 0.0, 0.0)
	var queued := ship.submit_planetary_surface_gravity_sample(
		source.get_instance_id(), 7, 1, gravity
	)
	ship.velocity = Vector3.ZERO
	ship.call(&"_update_flight", 0.1, ShipCommandType.neutral(), false)
	report = ship.get_planetary_surface_gravity_report()
	_check(
		bool(queued.get("accepted", false))
			and ship.velocity.is_equal_approx(Vector3(-1.0, 0.0, 0.0))
			and int(report.get("pending_sequence", -1)) == 0
			and int(report.get("last_applied_sequence", 0)) == 1
			and int(report.get("application_count", 0)) == 1,
		"HeroShip consumes one gravity sample inside its existing flight integration",
	)

	ship.velocity = Vector3.ZERO
	ship.call(&"_update_flight", 0.1, ShipCommandType.neutral(), false)
	_check(
		ship.velocity == Vector3.ZERO
			and int(ship.get_planetary_surface_gravity_report().get(
				"application_count", 0
			)) == 1,
		"a consumed sample cannot apply again on a later ship tick",
	)

	var replay := ship.submit_planetary_surface_gravity_sample(
		source.get_instance_id(), 7, 1, gravity
	)
	var skipped := ship.submit_planetary_surface_gravity_sample(
		source.get_instance_id(), 7, 3, gravity
	)
	_check(
		replay.get("reason") == &"sequence_mismatch"
			and skipped.get("reason") == &"sequence_mismatch",
		"replayed and skipped gravity sequences fail closed",
	)

	var hover_queued := ship.submit_planetary_surface_gravity_sample(
		source.get_instance_id(), 7, 2, gravity
	)
	var radial_up := Vector3.RIGHT
	var alignment_before := ship.global_basis.y.dot(radial_up)
	ship.velocity = Vector3.ZERO
	ship.call(&"_update_flight", 0.1, ShipCommandType.from_dictionary({
		"schema_version": ShipCommandType.SCHEMA_VERSION,
		"sequence": 1,
		"timestamp_usec": 0,
		"stream_id": 1,
		"hover": true,
	}), false)
	_check(
		bool(hover_queued.get("accepted", false))
			and absf(ship.velocity.dot(radial_up)) <= 0.00001
			and ship.global_basis.y.dot(radial_up) > alignment_before,
		"hover cancels radial speed and turns ship-up toward arbitrary planetary up",
	)

	var cruise_generation := int(
		ship.get_planetary_cruise_attachment_report().ship_attachment_generation
	)
	var cruise_blocked := ship.attach_planetary_cruise_controller(
		cruise_controller.get_instance_id(), cruise_generation
	)
	_check(
		cruise_blocked.get("reason") == &"surface_gravity_active",
		"surface gravity and planetary cruise cannot own overlapping integration modes",
	)

	var detached := ship.detach_planetary_surface_gravity(
		source.get_instance_id(), 7
	)
	var cruise_attached := ship.attach_planetary_cruise_controller(
		cruise_controller.get_instance_id(), cruise_generation
	)
	var gravity_blocked := ship.attach_planetary_surface_gravity(
		source.get_instance_id(), 8
	)
	_check(
		bool(detached.get("accepted", false))
			and bool(cruise_attached.get("accepted", false))
			and gravity_blocked.get("reason") == &"planetary_cruise_active",
		"the reciprocal cruise exclusion and explicit gravity handback are enforced",
	)
	ship.disengage_planetary_cruise(
		cruise_controller.get_instance_id(), cruise_generation, false
	)

	var lifecycle_attached := ship.attach_planetary_surface_gravity(
		source.get_instance_id(), 9
	)
	fixture.remove_child(ship)
	_check(
		bool(lifecycle_attached.get("accepted", false))
			and not bool(ship.get_planetary_surface_gravity_report().get(
				"attached", true
			))
			and ship.get_planetary_surface_gravity_report().get("reason") \
				== &"ship_detached",
		"tree detachment retires pending planetary gravity before re-entry",
	)
	ship.queue_free()
	fixture.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS hero_ship_planetary_surface_gravity_test (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("hero_ship_planetary_surface_gravity_test: " + failure)
	quit(1)
