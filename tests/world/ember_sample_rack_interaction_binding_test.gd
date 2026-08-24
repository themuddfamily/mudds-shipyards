extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_sample_rack_interaction_binding.gd"
)
const AuthoredSceneScript := preload(
	"res://scripts/world/ember_moon_authored_scene.gd"
)

class FakeHost:
	var generation := 44
	var attachment_generation := 1
	var player_instance_id := 0
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_snapshot() -> Dictionary:
		return {
			"attached": true,
			"phase_id": &"on_foot",
			"identities": {"player_instance_id": player_instance_id},
		}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var foreign_actor := Node3D.new()
	root.add_child(foreign_actor)
	var host := FakeHost.new()
	host.player_instance_id = actor.get_instance_id()
	var binding := BindingScript.new() as Area3D
	root.add_child(binding)
	await process_frame
	var configured: Dictionary = binding.call(
		&"configure", host,
		AuthoredSceneScript.get_sample_rack_interaction_definition()
	)
	var dormant := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(configured.accepted) and not bool(dormant.active)
			and int(dormant.physical.collision_layer) == 0
			and not bool(dormant.physical.marker_visible)
			and dormant.position_body_local_m == Vector3(28.0, 120000.0, -4.8),
		"the existing rack-access transform stays dormant before survey activation"
	)

	var activated: Dictionary = binding.call(
		&"activate_for_activity_generation", 1
	)
	var ready := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(activated.accepted) and bool(ready.active)
			and ready.prompt == "[ E ]  ANALYSE SAMPLE RACK"
			and int(ready.physical.collision_layer) == 8
			and bool(ready.physical.marker_visible)
			and ready.physical.marker_kind == &"label_3d"
			and not bool(ready.authority.route)
			and not bool(ready.authority.reward)
			and not bool(ready.authority.solid_geometry),
		"activation exposes only a passive proximity prompt and text marker"
	)

	var stale: Dictionary = binding.call(
		&"submit_interaction", actor, 44, 1, 0
	)
	var foreign: Dictionary = binding.call(
		&"submit_interaction", foreign_actor, 44, 1, 1
	)
	var completed: Dictionary = binding.call(
		&"submit_interaction", actor, 44, 1, 1
	)
	var duplicate: Dictionary = binding.call(
		&"submit_interaction", actor, 44, 1, 1
	)
	var complete := binding.call(&"get_snapshot") as Dictionary
	var receipt := complete.last_receipt as Dictionary
	_check(
		not bool(stale.accepted) and not bool(foreign.accepted)
			and bool(completed.accepted) and not bool(duplicate.accepted)
			and complete.prompt == "[ COMPLETE ]  SAMPLE RACK ANALYSED"
			and complete.physical.marker_text == "SAMPLE RACK\nANALYSIS COMPLETE"
			and receipt.checkpoint_id == &"ember_sample_rack_analysis_log"
			and receipt.interaction_id == &"ember_sample_rack_analysis"
			and receipt.world_id == &"ember_moon"
			and int(receipt.host_generation) == 44
			and int(receipt.attachment_generation) == 1
			and int(receipt.activity_generation) == 1
			and not bool(receipt.activity_started)
			and not bool(receipt.reward_granted)
			and not bool(receipt.historical_claim)
			and receipt.completion_response_id \
				== &"ember_sample_rack_analysis_marker",
		"only the current actor and three live generations produce the bounded receipt"
	)

	var saved := binding.call(&"get_persistence_snapshot") as Dictionary
	var detached: Dictionary = binding.call(&"detach")
	var hidden := binding.call(&"get_snapshot") as Dictionary
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter", 2)
	var retained := binding.call(&"get_snapshot") as Dictionary
	var restored: Dictionary = binding.call(&"restore_persistence_snapshot", saved)
	_check(
		bool(detached.accepted) and not bool(hidden.physical.marker_visible)
			and bool(reentered.accepted) and bool(retained.completed)
			and bool(retained.physical.marker_visible) and bool(restored.accepted),
		"same-session detach hides the point and re-entry retains completion"
	)

	var next_generation: Dictionary = binding.call(
		&"activate_for_activity_generation", 2
	)
	var reset := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(next_generation.accepted) and not bool(reset.completed)
			and int(reset.activity_generation) == 2
			and reset.prompt == "[ E ]  ANALYSE SAMPLE RACK",
		"a genuinely newer survey generation resets the sample analysis"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SAMPLE_RACK_INTERACTION_BINDING_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
