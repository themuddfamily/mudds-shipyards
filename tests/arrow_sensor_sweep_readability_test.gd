extends SceneTree

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	root.add_child(arrow)
	arrow.set_physics_process(false)
	await process_frame

	var sweep := arrow.get_sensor_mast()
	_check(sweep != null, "Arrow builds its recon sensor sweep")
	if sweep != null:
		var authored_position := sweep.position
		sweep.rotation = Vector3.ZERO
		arrow.set("_elapsed_arrow", 0.0)
		arrow.call("_update_arrow_presentation", 0.5)
		_check(
			is_equal_approx(
				sweep.rotation.y,
				ArrowReconShip.SENSOR_SWEEP_YAW_RATE * 0.5
			),
			"sensor head retains its steady horizontal survey rotation"
		)

		arrow.set(
			"_elapsed_arrow",
			PI / (2.0 * ArrowReconShip.SENSOR_SWEEP_PITCH_RATE)
		)
		arrow.call("_update_arrow_presentation", 0.0)
		_check(
			is_equal_approx(
				sweep.rotation.x,
				ArrowReconShip.SENSOR_SWEEP_PITCH_AMPLITUDE
			),
			"sensor head reaches the restrained positive survey pitch"
		)

		arrow.set(
			"_elapsed_arrow",
			3.0 * PI / (2.0 * ArrowReconShip.SENSOR_SWEEP_PITCH_RATE)
		)
		arrow.call("_update_arrow_presentation", 0.0)
		_check(
			is_equal_approx(
				sweep.rotation.x,
				-ArrowReconShip.SENSOR_SWEEP_PITCH_AMPLITUDE
			),
			"sensor head completes the matching negative survey pitch"
		)
		_check(
			sweep.position == authored_position
			and ArrowReconShip.SENSOR_SWEEP_PITCH_AMPLITUDE <= deg_to_rad(6.0)
			and bool(sweep.get_meta("visual_only", false))
			and not bool(sweep.get_meta("gameplay_authority", true))
			and sweep.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"readability motion stays bounded on the visual-only, collision-free assembly"
		)

	arrow.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ARROW_SENSOR_SWEEP_READABILITY_TEST_OK")
		quit(0)
	else:
		print("ARROW_SENSOR_SWEEP_READABILITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
