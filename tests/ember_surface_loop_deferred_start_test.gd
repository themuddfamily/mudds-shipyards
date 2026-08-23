extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _reward(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"caller_reward"}

func _run() -> void:
	var main := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(main)
	var host := main.get_node(^"EmberSurfaceLoopHost") as EmberSurfaceLoopHost
	var binding := main.get_node(^"EmberSurfaceLoopProductionBinding") as EmberSurfaceLoopProductionBinding
	main.active_ship.set_piloted(true)
	var pending := main.begin_ember_surface_journey(
		host, main.activity_director, Callable(self, &"_reward"), 1
	)
	var duplicate := main.begin_ember_surface_journey(
		host, main.activity_director, Callable(self, &"_reward"), 2
	)
	var cancelled := main.cancel_ember_surface_journey()
	var valid: bool = pending.accepted \
			and pending.reason == &"ember_surface_journey_pending_stream" \
			and duplicate.accepted \
			and duplicate.reason == &"ember_surface_journey_pending_stream" \
			and cancelled.accepted \
			and not bool(host.get_snapshot().get("attached", false)) \
			and not bool(binding.get_snapshot().get("configured", false))
	main.free()
	await process_frame
	if not valid:
		push_error("deferred Ember start contract failed: %s / %s / %s" % [pending, duplicate, cancelled])
		quit(1)
		return
	print("EMBER_SURFACE_LOOP_DEFERRED_START_TEST_OK: pending/cancel fenced before stream activation")
	quit(0)
