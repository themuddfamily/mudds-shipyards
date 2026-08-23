extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BindingScript.new()
	var invalid_actor := binding.advance_from_caller_sample(
		1, 1.0 / 60.0, &"player", 11, 22, Vector3.ZERO,
		Vector3.ZERO, false, false, false, {}, 1, 1, 0
	)
	var invalid_craft := binding.advance_from_caller_sample(
		1, 1.0 / 60.0, &"ship", 11, 22, Vector3.ZERO,
		Vector3.ZERO, false, false, false, {}, 1, 1, 0
	)
	var snapshot := binding.get_snapshot()
	binding.free()
	await process_frame
	var valid: bool = not invalid_actor.accepted \
			and invalid_actor.reason == &"caller_sample_craft_mismatch" \
			and not invalid_craft.accepted \
			and invalid_craft.reason == &"caller_sample_actor_mismatch" \
			and snapshot.pending_envelope.is_empty()
	if not valid:
		push_error("Ember caller sample API failed closed")
		quit(1)
		return
	print("EMBER_CALLER_SAMPLE_API_TEST_OK: identity-gated detached caller envelope")
	quit(0)
