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
	var snapshot_count := 0
	var observation_count := 0
	var phase_id := &"on_foot"
	var attached := true
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return _observation()
	func _observation() -> Dictionary:
		return {
			"attached": attached,
			"phase_id": phase_id,
			"identities": {"player_instance_id": player_instance_id},
		}

class ObservedHost:
	extends FakeHost
	func get_return_status_snapshot() -> Dictionary:
		observation_count += 1
		return _observation()

class FakeActivityAuthority:
	var observation_count := 0
	var active := true
	var active_generation := 1
	var accept_submissions := true
	var admitted_receipts: Array[Dictionary] = []
	func is_current(expected_activity_generation: int) -> bool:
		observation_count += 1
		return active and expected_activity_generation == active_generation
	func submit(receipt: Dictionary) -> Dictionary:
		if not accept_submissions:
			return {"accepted": false, "reason": &"optional_checkpoint_rejected"}
		admitted_receipts.append(receipt.duplicate(true))
		return {"accepted": true, "reason": &"optional_checkpoint_completed"}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy_views := await _exercise(FakeHost.new())
	var narrow_views := await _exercise(ObservedHost.new())
	_check(legacy_views == narrow_views, "focused and legacy Host observations preserve every interaction report")
	for failure in _failures:
		push_error(failure)
	print("EMBER_SAMPLE_RACK_INTERACTION_BINDING_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _exercise(host: FakeHost) -> Array:
	var views: Array = []
	var actor := Node3D.new()
	root.add_child(actor)
	var foreign_actor := Node3D.new()
	root.add_child(foreign_actor)
	host.player_instance_id = actor.get_instance_id()
	var authority := FakeActivityAuthority.new()
	var binding := BindingScript.new() as Area3D
	root.add_child(binding)
	await process_frame
	var configured: Dictionary = binding.call(
		&"configure", host,
		AuthoredSceneScript.get_sample_rack_interaction_definition(),
		Callable(authority, "is_current"), Callable(authority, "submit")
	)
	var dormant := _observe(binding, host, authority, views)
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
	var ready := _observe(binding, host, authority, views)
	var marker := binding.get_node(^"SampleRackAnalysisMarker") as Label3D
	_check(
		bool(activated.accepted) and bool(ready.active)
			and ready.prompt == "[ E ]  ANALYSE SAMPLE RACK"
			and int(ready.physical.collision_layer) == 8
			and bool(ready.physical.marker_visible)
			and ready.physical.marker_kind == &"label_3d"
			and marker.position == Vector3(0.0, 1.8, 0.0)
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
	var complete := _observe(binding, host, authority, views)
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

	var detached: Dictionary = binding.call(&"detach")
	var hidden := _observe(binding, host, authority, views)
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter", 2)
	var retained := _observe(binding, host, authority, views)
	_check(
		bool(detached.accepted) and not bool(hidden.physical.marker_visible)
			and bool(reentered.accepted) and bool(retained.completed)
			and bool(retained.physical.marker_visible)
			and not binding.has_method(&"get_persistence_snapshot")
			and not binding.has_method(&"restore_persistence_snapshot"),
		"same-session re-entry retains completion without a serialized contract"
	)

	authority.active_generation = 2
	var next_generation: Dictionary = binding.call(
		&"activate_for_activity_generation", 2
	)
	var reset := _observe(binding, host, authority, views)
	_check(
		bool(next_generation.accepted) and not bool(reset.completed)
			and int(reset.activity_generation) == 2
			and reset.prompt == "[ E ]  ANALYSE SAMPLE RACK",
		"a genuinely newer survey generation resets the sample analysis"
	)

	authority.accept_submissions = false
	var rejected: Dictionary = binding.call(
		&"submit_interaction", actor, 44, 2, 2
	)
	var after_rejection := _observe(binding, host, authority, views)
	authority.active = false
	var late_after_failure: Dictionary = binding.call(
		&"submit_interaction", actor, 44, 2, 2
	)
	var inactive := _observe(binding, host, authority, views)
	authority.active_generation = 3
	var inactive_activation: Dictionary = binding.call(
		&"activate_for_activity_generation", 3
	)
	authority.active = true
	authority.accept_submissions = true
	var reactivated: Dictionary = binding.call(
		&"activate_for_activity_generation", 3
	)
	var fresh := _observe(binding, host, authority, views)
	_check(
		not bool(rejected.accepted) and bool(after_rejection.active)
			and not bool(after_rejection.completed)
			and after_rejection.prompt == "[ E ]  ANALYSE SAMPLE RACK"
			and not bool(late_after_failure.accepted)
			and not bool(inactive.active)
			and not bool(inactive.physical.marker_visible)
			and not bool(inactive.completed)
			and not bool(inactive_activation.accepted)
			and bool(reactivated.accepted) and bool(fresh.active)
			and int(fresh.activity_generation) == 3,
		"rejection and terminal activity state never manufacture local completion"
	)

	var calls_before := authority.observation_count
	host.phase_id = &"reboarded"
	var off_foot := _observe(binding, host, authority, views)
	_check(not off_foot.active and off_foot.prompt.is_empty()
		and off_foot.physical.collision_layer == 0 and not off_foot.physical.marker_visible
		and authority.observation_count == calls_before,
		"fresh Host phase change hides prompt, marker and collision before reading activity")
	host.phase_id = &"on_foot"
	host.generation += 1
	_check(not _observe(binding, host, authority, views).active,
		"fresh Host generation change invalidates the next report")
	host.generation -= 1
	host.attached = false
	_check(not _observe(binding, host, authority, views).active,
		"fresh Host detach invalidates the next report")
	host.attached = true
	host.player_instance_id = foreign_actor.get_instance_id()
	_check(not binding.can_interact(actor), "actor authentication reads the current Host identity")
	binding.queue_free()
	actor.queue_free()
	foreign_actor.queue_free()
	await process_frame
	return views


func _observe(binding: Object, host: FakeHost, authority: FakeActivityAuthority, views: Array) -> Dictionary:
	var full_before := host.snapshot_count
	var narrow_before := host.observation_count
	var activity_before := authority.observation_count
	var snapshot: Dictionary = binding.get_snapshot()
	var expected_host_reads := 1 if snapshot.attached else 0
	_check(host.snapshot_count - full_before + host.observation_count - narrow_before == expected_host_reads,
		"one interaction report samples Host authority at most once")
	_check(authority.observation_count - activity_before <= 1,
		"one interaction report samples activity authority at most once")
	if host is ObservedHost:
		_check(host.snapshot_count == full_before, "focused interaction report builds no Host diagnostics")
	views.append(snapshot.duplicate(true))
	return snapshot


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
