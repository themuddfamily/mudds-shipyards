extends SceneTree

const BindingType := preload(
	"res://scripts/control/planetary_cruise_production_binding.gd"
)
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var bootstrap := EmberMoonStreamingBootstrap.new()
	bootstrap.name = "EmberMoonStreamingBootstrap"
	stage.add_child(bootstrap)
	var binding := BindingType.new() as PlanetaryCruiseProductionBinding
	binding.name = "PlanetaryCruiseProductionBinding"
	stage.add_child(binding)
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	ship.ship_definition = TORRENT_DEFINITION
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 100.0)
	ship.set_piloted(true)
	await process_frame
	await physics_frame
	await process_frame

	var frame := bootstrap.get_coordinate_frame_for_session()
	_check(
		frame != null and bool(binding.audit().get("valid", false)),
		"the caller-driven production binding activates with its sole controller",
	)
	var engage := binding.request_engage(
		ship, frame.get_generation(), &"", binding.get_generation()
	)
	var return_target := _return_target(ship)
	var armed := binding.request_return_approach(
		return_target, frame.get_generation(), binding.get_generation()
	) if bool(engage.get("accepted", false)) else {}
	_check(
		bool(engage.get("accepted", false))
			and bool(armed.get("accepted", false))
			and armed.get("reason") == &"return_approach_armed",
		"engagement arms the exact caller-owned home target once",
	)

	var completion_reentry: Array[Dictionary] = [{}]
	binding.return_approach_completed.connect(func(receipt: Dictionary) -> void:
		completion_reentry[0] = binding.consume_return_approach_completion(
			int(receipt.get("target_generation", 0)), binding.get_generation()
		)
	)
	var completed := binding.physics_tick_from_caller_sample(
		1, _sample(ship), ship, frame.get_generation(), false, &""
	)
	_check(
		bool(completed.get("accepted", false))
			and completed.get("reason") == &"return_approach_handoff_ready"
			and completed.get("home_target_id") == &"mudds_shipyards_home"
			and not bool(binding.get_snapshot().get("engagement_requested", true))
			and int(ship.get_planetary_cruise_attachment_report()
				.get("controller_instance_id", -1)) == 0,
		"terminal receipt releases the sole mover binding without teleport or reparent",
	)
	_check(
		not bool(completion_reentry[0].get("accepted", true))
			and completion_reentry[0].get("reason") == &"reentrant_call",
		"terminal signal dispatch fences synchronous completion consumption",
	)
	_check(
		binding.consume_return_approach_completion(
			2, binding.get_generation()
		).get("reason") == &"return_approach_generation_mismatch",
		"a stale consumer cannot claim another return generation",
	)
	var consumed := binding.consume_return_approach_completion(
		1, binding.get_generation()
	)
	var replayed := binding.consume_return_approach_completion(
		1, binding.get_generation()
	)
	_check(
		bool(consumed.get("accepted", false))
			and consumed.get("reason") == &"return_approach_handoff_ready"
			and replayed.get("reason") == &"return_approach_completion_replayed",
		"the terminal receipt is generation-fenced and consumable exactly once",
	)

	var reengaged := binding.request_engage(
		ship, frame.get_generation(), &"", binding.get_generation()
	)
	var rebase := frame.request_rebase(
		Vector3(12_000.0, 0.0, 0.0), frame.get_generation()
	)
	var committed := frame.commit_rebase(
		int((rebase.get("request", {}) as Dictionary).get("request_id", 0)),
		frame.get_generation(),
	)
	var stale_arm := binding.request_return_approach(
		return_target, 1, binding.get_generation()
	)
	_check(
		bool(reengaged.get("accepted", false))
			and bool(committed.get("accepted", false))
			and not bool(stale_arm.get("accepted", true))
			and stale_arm.get("reason") == &"coordinate_frame_generation_mismatch",
		"the request boundary rejects a bound generation after the live frame rebases",
	)
	var detached := binding.request_disengage(binding.get_generation(), false)
	var current_engage := binding.request_engage(
		ship, frame.get_generation(), &"", binding.get_generation()
	) if bool(detached.get("accepted", false)) else {}
	var current_arm := binding.request_return_approach(
		return_target, frame.get_generation(), binding.get_generation()
	) if bool(current_engage.get("accepted", false)) else {}
	var second_rebase := frame.request_rebase(
		Vector3(24_000.0, 0.0, 0.0), frame.get_generation()
	)
	var second_commit := frame.commit_rebase(
		int((second_rebase.get("request", {}) as Dictionary)
			.get("request_id", 0)),
		frame.get_generation(),
	)
	var retired := binding.physics_tick_from_caller_sample(
		2, _sample(ship), ship, frame.get_generation(), false, &""
	)
	_check(
		bool(detached.get("accepted", false))
			and bool(current_engage.get("accepted", false))
			and bool(current_arm.get("accepted", false))
			and bool(second_commit.get("accepted", false))
			and not bool(retired.get("accepted", true))
			and retired.get("reason") == &"return_approach_rebase_aborted"
			and not bool(binding.get_snapshot().get("engagement_requested", true))
			and int(ship.get_planetary_cruise_attachment_report()
				.get("controller_instance_id", -1)) == 0,
		"post-rebase cadence retires the stale attachment before any new envelope",
	)

	stage.queue_free()
	await process_frame
	_finish()


func _return_target(ship: HeroShip) -> Dictionary:
	var bounds := (ship.get_landing_collision_report()
		.get("local_bounds", AABB())) as AABB
	return {
		"home_target_id": &"mudds_shipyards_home",
		"home_target_world_transform": Transform3D.IDENTITY,
		"corridor_half_extents_m": Vector3(100.0, 100.0, 750_000.0),
		"brake_shell_min_distance_m": 50.0,
		"brake_shell_max_distance_m": 150.0,
		"maximum_speed_mps": 12.0,
		"maximum_attitude_degrees": 12.0,
		"hull_margin_m": 0.05,
		"fleet_collision_bounds": {
			&"torrent_provisional": bounds,
			&"arrow_provisional": AABB(Vector3(-8.0, -3.0, -14.0), Vector3(16.0, 6.0, 28.0)),
			&"jovian_provisional": AABB(Vector3(-15.0, -6.0, -24.0), Vector3(30.0, 12.0, 48.0)),
			&"zenith_b7_observed": AABB(Vector3(-7.0, -3.0, -13.0), Vector3(14.0, 6.0, 26.0)),
			&"halyard_new_design": AABB(Vector3(-18.0, -8.0, -30.0), Vector3(36.0, 16.0, 60.0)),
		},
	}.duplicate(true)


func _sample(ship: HeroShip) -> Dictionary:
	return {
		"available": true,
		"position": ship.global_position,
		"actor_kind": &"ship",
		"actor_instance_id": ship.get_instance_id(),
	}.duplicate(true)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("PLANETARY_CRUISE_RETURN_APPROACH_BINDING_TEST: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_CRUISE_RETURN_APPROACH_BINDING_TEST_OK: %d assertions" % _checks)
		quit(0)
		return
	print("PLANETARY_CRUISE_RETURN_APPROACH_BINDING_TEST_FAILED: %d/%d" % [
		_failures.size(), _checks,
	])
	quit(1)
