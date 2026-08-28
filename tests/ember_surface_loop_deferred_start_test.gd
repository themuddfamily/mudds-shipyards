extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _reward(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"caller_reward"}

func _run() -> void:
	var main := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(main)
	# This test drives the retained cruise binding explicitly. Disable Main's
	# autonomous caller before the first physics frame so its monotonic tick
	# cannot race the two samples below.
	main.set_physics_process(false)
	var host := main.get_node(^"EmberSurfaceLoopHost") as EmberSurfaceLoopHost
	var binding := main.get_node(^"EmberSurfaceLoopProductionBinding") as EmberSurfaceLoopProductionBinding
	await process_frame
	main.active_ship.set_piloted(true)
	main.set("_piloting", true)
	main.set("_sortie_departed_berth", true)
	main.phase = GameFlow.Phase.FREE_FLIGHT
	var pending := main.begin_ember_surface_journey(
		host, main.activity_director, Callable(self, &"_reward"), 1
	)
	var duplicate := main.begin_ember_surface_journey(
		host, main.activity_director, Callable(self, &"_reward"), 2
	)
	var cruise_snapshot: Dictionary = main.planetary_cruise_binding.get_snapshot()
	var frame_generation := int(cruise_snapshot.get("current_coordinate_frame_generation", 0))
	var first_caller_tick := int(cruise_snapshot.get("last_caller_tick", 0)) + 1
	var far_sample := {
		"actor_instance_id": main.active_ship.get_instance_id(),
		"actor_kind": &"ship",
		"available": true,
		"position": main.active_ship.global_position,
	}
	var far_tick: Dictionary = main.planetary_cruise_binding.physics_tick_from_caller_sample(
		first_caller_tick, far_sample, main.active_ship, frame_generation, false, &""
	)
	var destination_result: Dictionary = main.ember_streaming_bootstrap \
			.get_coordinate_frame_for_session().orbital_to_world_streaming_position(
				cruise_snapshot.get("canonical_destination_orbital", {}), frame_generation
			)
	var near_sample := far_sample.duplicate(true)
	near_sample["position"] = destination_result.get("position", Vector3.INF)
	var near_tick: Dictionary = main.planetary_cruise_binding.physics_tick_from_caller_sample(
		first_caller_tick + 1, near_sample, main.active_ship, frame_generation, false, &""
	)
	var engaged_before_cancel := bool(
		main.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)
	)
	var cancelled := main.cancel_ember_surface_journey()
	var valid: bool = pending.accepted \
			and pending.reason == &"ember_surface_journey_pending_stream" \
			and engaged_before_cancel \
			and bool(far_tick.get("accepted", false)) \
			and bool(near_tick.get("accepted", false)) \
			and duplicate.accepted \
			and duplicate.reason == &"ember_surface_journey_pending_stream" \
			and cancelled.accepted \
			and not bool(binding.get_snapshot().get("configured", false))
	# Let the production fleet's already-started two-frame assembly settle before
	# destroying Main; it is orthogonal to this manually driven cruise check.
	await process_frame
	await process_frame
	main.free()
	await process_frame
	if not valid:
		push_error("deferred Ember start contract failed: %s / %s / %s" % [pending, far_tick, near_tick])
		quit(1)
		return
	print("EMBER_SURFACE_LOOP_DEFERRED_START_TEST_OK: pending/cancel fenced before stream activation")
	quit(0)
