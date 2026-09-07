extends SceneTree

const CRAFT := preload("res://scenes/ships/halyard_crew_transport.tscn")
var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var craft := CRAFT.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	var actor := Node3D.new()
	root.add_child(actor)
	var other := Node3D.new()
	root.add_child(other)
	for side in ["Port", "Starboard"]:
		var bunk := craft.get_node("WalkableInterior/AftSystemsBay/" + side + "SleepingBerth/ShipBunkInteraction") as ShipBunk
		_check(bunk != null and bunk.get_ship() == craft, side + " physical berth resolves its ship")
		if bunk == null:
			continue
		_check(bunk.is_available() and bunk.get_interaction_prompt().contains("SLEEP"), "empty berth offers sleep")
		var rest_local := craft.global_transform.affine_inverse() * bunk.get_seat_anchor().global_transform
		_check(rest_local.basis.y.is_equal_approx(Vector3.BACK), "sleeping body lies horizontally along mattress")
		_check(is_equal_approx(rest_local.origin.y, 1.32) and is_equal_approx(rest_local.origin.z, 5.70), "feet start at mattress foot end")
		var wake_local := craft.global_transform.affine_inverse() * bunk.get_exit_transform()
		_check(absf(wake_local.origin.x) < 0.5 and is_equal_approx(wake_local.origin.y, 0.52), "wake pose stands in the clear central aisle")
		_check(bunk.try_reserve(actor) and not bunk.try_reserve(other), "one sleeper exclusively reserves berth")
		_check(bunk.finish_transition(actor) and bunk.get_seated_prompt().contains("WAKE UP"), "resting berth offers waking")
		craft.position += Vector3(30.0, 10.0, -20.0)
		craft.rotate_y(0.4)
		_check((craft.global_transform.affine_inverse() * bunk.get_seat_anchor().global_transform).is_equal_approx(rest_local), "resting pose follows translated and rotated ship")
		_check((craft.global_transform.affine_inverse() * bunk.get_exit_transform()).is_equal_approx(wake_local), "wake pose follows translated and rotated ship")
		_check(bunk.begin_release(actor) and bunk.release(actor) and bunk.is_available(), "waking frees berth for reuse")
		_check(not bunk.interact(actor), "generic interaction cannot bypass the sleep coordinator")
	craft.queue_free()
	actor.queue_free()
	other.queue_free()
	await process_frame
	print("HALYARD_SLEEPING_BERTH_TEST_OK" if _failures == 0 else "HALYARD_SLEEPING_BERTH_TEST_FAILED")
	quit(1 if _failures else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
