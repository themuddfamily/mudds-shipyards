extends SceneTree

const AdapterScript := preload("res://scripts/world/planetary_surface_activity_reward_adapter.gd")
const RuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const ActivityDefinitionScript := preload("res://scripts/activities/activity_definition.gd")
const LocationScript := preload("res://scripts/world/definitions/world_location_definition.gd")
const NavigationScript := preload("res://scripts/world/planetary_surface_navigation_runtime.gd")
const NavigationContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const HazardScript := preload("res://scripts/world/planetary_surface_hazard_runtime.gd")
const WaterScript := preload("res://scripts/world/planetary_water_contact_runtime.gd")
const WaterContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")
const LandmarkScript := preload("res://scripts/world/planetary_activity_landmark_runtime.gd")
const LandmarkContractScript := preload("res://scripts/world/planetary_activity_landmark_cluster_contract.gd")

class FakeHost:
	var generation := 7
	var attachment_generation := 2
	var phase_id: StringName = &"on_foot"
	var attached := true

	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": attached,
			"phase_id": phase_id,
			"identities": {"world_id": &"ember_moon"},
		}

	func get_generation() -> int:
		return generation

	func get_attachment_generation() -> int:
		return attachment_generation

	func get_phase() -> int:
		return 8


var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_real_host_identity_bind()
	await _test_host_activity_reward_path()
	await _test_detached_reward_recovery()
	await _test_failed_activity_requires_fresh_reentry()
	await _test_completed_activity_repeat()
	await _test_ordered_activity_sequence()
	await _test_sequence_failure_recovery()
	await _test_surface_route_admits_activity_sequence()
	await _test_surface_hazard_interrupts_and_recovers_route()
	await _test_surface_session_restore_fences_reentry()
	await _test_surface_origin_rebase_preserves_absolute_identity()
	await _test_surface_water_recovery_preserves_route()
	await _test_landmark_discovery_admits_activity_once()
	_finish()


func _test_real_host_identity_bind() -> void:
	var host := HostScript.new()
	root.add_child(host)
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var bound := adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	_check(
		bound.accepted and adapter.get_snapshot().host.host_id == &"ember_surface_loop"
			and adapter.audit().host_mutations == 0,
		"the adapter accepts the real Ember host public identity without mutating it"
	)
	_check(
		adapter.begin_activity(&"ember_beacon_survey").reason == &"host_not_attached",
		"an unbound real Host cannot begin a surface activity"
	)
	host.queue_free()
	director.queue_free()
	await process_frame


func _test_host_activity_reward_path() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	_check(
		adapter.bind(host, runtime, director, Callable(self, "_accept_reward")).accepted,
		"the clean adapter binds the Host contract, ActivityDirector, and reward callback"
	)
	var started := adapter.begin_activity(&"ember_beacon_survey")
	_check(
		started.accepted and started.adapter.state == &"active"
			and started.adapter.activity_reward.state == &"active",
		"the on-foot Host phase starts the authored activity"
	)
	_check(
		adapter.submit_activity_position(Vector3.ZERO).accepted,
		"the adapter forwards the first surface position to ActivityDirector"
	)
	var completed := adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	_check(
		completed.accepted and completed.adapter.activity_reward.state == &"awaiting_reward",
		"the existing Host phase gates a completed activity reward receipt"
	)
	var reward := adapter.commit_activity_reward()
	_check(
		reward.accepted and reward.adapter.state == &"completed"
			and _reward_calls == 1,
		"the adapter delivers exactly one reward callback without owning the store"
	)
	_check(
		adapter.commit_activity_reward().reason == &"adapter_activity_not_active",
		"a completed adapter rejects reward replay"
	)
	director.queue_free()
	await process_frame


func _test_detached_reward_recovery() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.begin_activity(&"ember_beacon_survey")
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	_check(
		adapter.detach().accepted,
		"completed surface work can detach while its reward receipt remains pending"
	)
	host.attachment_generation = 3
	var recovered := adapter.recover_pending_reward()
	_check(
		recovered.accepted
			and recovered.reason == &"reward_committed"
			and recovered.adapter.state == &"completed"
			and _reward_calls == 2,
		"returning on a fresh host attachment recovers and commits the preserved reward once"
	)
	director.queue_free()
	await process_frame


func _test_failed_activity_requires_fresh_reentry() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.begin_activity(&"ember_beacon_survey")
	var aborted := adapter.abort_activity(&"surface_route_lost")
	_check(
		aborted.accepted and aborted.adapter.state == &"failed"
			and aborted.adapter.activity_reward.failure_reason == &"surface_route_lost",
		"an active surface activity records a bounded failure without issuing a reward"
	)
	_check(
		adapter.retry_activity(&"ember_beacon_survey").reason
			== &"stale_attachment_generation",
		"failed activity cannot retry on the retired surface attachment"
	)
	host.attachment_generation = 4
	var retried := adapter.retry_activity(&"ember_beacon_survey")
	_check(
		retried.accepted and retried.adapter.state == &"active"
			and retried.adapter.activity_reward.activity_generation == 2,
		"a fresh surface attachment starts a new fenced activity generation"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	_check(adapter.commit_activity_reward().accepted and _reward_calls == 3, "retried activity can complete and reward normally")
	director.queue_free()
	await process_frame


func _test_completed_activity_repeat() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.begin_activity(&"ember_beacon_survey")
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	_check(
		adapter.repeat_activity(&"ember_beacon_survey").reason == &"stale_attachment_generation",
		"a completed reward cycle cannot repeat on the same host attachment"
	)
	host.attachment_generation = 5
	var repeated := adapter.repeat_activity(&"ember_beacon_survey")
	_check(
		repeated.accepted and repeated.reason == &"activity_repeated"
			and repeated.adapter.activity_reward.activity_generation == 2,
		"a fresh attachment starts a new repeatable activity generation"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	_check(
		adapter.commit_activity_reward().accepted and _reward_calls == 5,
		"the repeated activity earns a second reward through the same authority"
	)
	director.queue_free()
	await process_frame


func _test_ordered_activity_sequence() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	var sequence := [&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName]
	var started := adapter.start_activity_sequence(sequence)
	_check(
		started.accepted and started.reason == &"activity_sequence_started"
			and started.adapter.activity_sequence.index == 0,
		"ordered surface landmarks start at the first authored activity"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	_check(
		adapter.advance_activity_sequence(&"wrong_relay").reason == &"activity_landmark_mismatch",
		"the next landmark rejects an unrelated authored anchor"
	)
	_check(
		adapter.advance_activity_sequence(&"ridge_relay").reason == &"stale_attachment_generation",
		"the next landmark cannot advance on the completed attachment"
	)
	host.attachment_generation = 6
	var advanced := adapter.advance_activity_sequence(&"wrong_relay")
	_check(
		advanced.reason == &"activity_landmark_mismatch",
		"a fresh attachment still requires the correct next landmark"
	)
	advanced = adapter.advance_activity_sequence(&"ridge_relay")
	_check(
		advanced.accepted and advanced.reason == &"activity_sequence_advanced"
			and advanced.adapter.activity_reward.activity_id == &"ember_caldera_patrol"
			and advanced.adapter.activity_sequence.index == 1,
		"a fresh attachment advances to the next authoritative landmark"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	_check(
		adapter.advance_activity_sequence(&"ridge_relay").reason == &"activity_sequence_complete"
			and _reward_calls == 7,
		"the ordered sequence closes after each landmark earns its own reward"
	)
	director.queue_free()
	await process_frame


func _test_sequence_failure_recovery() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.start_activity_sequence([
		&"ember_beacon_survey", &"ember_caldera_patrol",
	] as Array[StringName])
	adapter.submit_activity_position(Vector3.ZERO)
	_check(
		adapter.abort_activity(&"surface_route_lost").accepted,
		"a failed first landmark enters recovery without creating a reward"
	)
	host.attachment_generation = 8
	var retried := adapter.retry_activity(&"ember_beacon_survey")
	_check(
		retried.accepted and retried.reason == &"activity_sequence_retried"
			and retried.adapter.activity_sequence.index == 0,
		"mid-sequence retry preserves the current landmark index"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	host.attachment_generation = 9
	var advanced := adapter.advance_activity_sequence(&"ridge_relay")
	_check(
		advanced.accepted and advanced.adapter.activity_sequence.index == 1,
		"recovered first landmark advances normally to the next landmark"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	_check(
		_reward_calls == 9,
		"failed work issues no reward while recovered sequence issues one per completed landmark"
	)
	director.queue_free()
	await process_frame


func _test_surface_route_admits_activity_sequence() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var navigation := NavigationScript.new()
	navigation.configure(NavigationContractScript.new())
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	var started := adapter.start_surface_activity_sequence(
		[&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName],
		navigation,
		{"surface_staging_gate": &"ridge_relay"}
	)
	_check(
		started.accepted and started.adapter.surface_route.state == &"active",
		"surface route and ordered activity sequence start as one fenced visit"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	_check(
		adapter.submit_surface_route_landmark(
			&"surface_staging_gate", Vector3(100.0, 120000.0, 0.0)
		).reason == &"landmark_out_of_range",
		"route evidence rejects an out-of-range landmark without advancing activity"
	)
	host.attachment_generation = 3
	var advanced := adapter.submit_surface_route_landmark(
		&"surface_staging_gate", Vector3(42.0, 120000.0, 0.0)
	)
	_check(
		advanced.accepted and advanced.reason == &"activity_sequence_advanced"
			and advanced.adapter.activity_sequence.index == 1,
		"reaching the authored route landmark admits the mapped next activity"
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	_check(
		adapter.submit_surface_route_landmark(
			&"caldera_overlook", Vector3(420.0, 120025.0, -180.0)
		).reason == &"route_completed",
		"the final authored route landmark closes the already rewarded sequence"
	)
	director.queue_free()
	await process_frame


func _test_surface_hazard_interrupts_and_recovers_route() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var navigation := NavigationScript.new()
	var hazard := HazardScript.new()
	navigation.configure(NavigationContractScript.new())
	hazard.configure(NavigationContractScript.new())
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.bind_surface_hazard(hazard)
	adapter.start_surface_activity_sequence(
		[&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName],
		navigation,
		{"surface_staging_gate": &"ridge_relay"}
	)
	var reward_before := _reward_calls
	var exposure := adapter.submit_surface_hazard_exposure(
		&"caldera_thermal_vent", Vector3(58.0, 120000.0, -4.0), 1.0, 8.0
	)
	_check(
		exposure.accepted and exposure.reason == &"surface_hazard_recovery_required"
			and exposure.adapter.state == &"failed"
			and exposure.adapter.surface_route.state == &"interrupted"
			and _reward_calls == reward_before,
		"severe authored exposure interrupts activity and route without issuing a reward"
	)
	host.attachment_generation = 3
	var recovered := adapter.recover_surface_hazard(Vector3(58.0, 120000.0, -4.0))
	_check(
		recovered.accepted and recovered.reason == &"surface_hazard_recovered"
			and recovered.adapter.surface_route.state == &"active"
			and recovered.adapter.surface_route.waypoint_index == 0
			and _reward_calls == reward_before,
		"fresh re-entry resumes the current waypoint and does not duplicate rewards"
	)
	director.queue_free()
	await process_frame


func _test_surface_session_restore_fences_reentry() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var navigation := NavigationScript.new()
	var hazard := HazardScript.new()
	navigation.configure(NavigationContractScript.new())
	hazard.configure(NavigationContractScript.new())
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.bind_surface_hazard(hazard)
	adapter.start_surface_activity_sequence(
		[&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName],
		navigation,
		{"surface_staging_gate": &"ridge_relay"}
	)
	hazard.submit_exposure(
		&"caldera_thermal_vent", Vector3(58.0, 120000.0, -4.0), 1.0, 8.0
	)
	var saved := adapter.get_session_snapshot()
	var restored_host := FakeHost.new()
	restored_host.attachment_generation = 4
	var restored_director := _director_with_activity()
	var restored_adapter := AdapterScript.new()
	var restored_runtime := RuntimeScript.new()
	var restored_navigation := NavigationScript.new()
	var restored_hazard := HazardScript.new()
	restored_navigation.configure(NavigationContractScript.new())
	restored_hazard.configure(NavigationContractScript.new())
	restored_adapter.bind(
		restored_host, restored_runtime, restored_director,
		Callable(self, "_accept_reward")
	)
	var restored := restored_adapter.restore_session_snapshot(
		saved, restored_navigation, restored_hazard
	)
	_check(
		restored.accepted and restored.reason == &"surface_session_restored"
			and restored.adapter.state == &"failed"
			and restored.adapter.activity_sequence.index == 0
			and restored.adapter.surface_route.state == &"interrupted"
			and is_equal_approx(
				float(restored.adapter.surface_hazard.exposure[&"caldera_thermal_vent"]),
				0.8
			),
		"new attachment restores route sequence and hazard exposure as recoverable state"
	)
	restored_host.attachment_generation = 2
	_check(
		restored_adapter.restore_session_snapshot(
			saved, restored_navigation, restored_hazard
		).reason == &"stale_session_snapshot",
		"same or older attachment cannot replay a detached surface session"
	)
	director.queue_free()
	restored_director.queue_free()
	await process_frame


func _test_surface_origin_rebase_preserves_absolute_identity() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var navigation := NavigationScript.new()
	var hazard := HazardScript.new()
	navigation.configure(NavigationContractScript.new())
	hazard.configure(NavigationContractScript.new())
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.bind_surface_hazard(hazard)
	adapter.start_surface_activity_sequence(
		[&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName],
		navigation,
		{"surface_staging_gate": &"ridge_relay"}
	)
	var before := adapter.get_session_snapshot()
	var receipt := {
		"accepted": true,
		"source_generation": 0,
		"target_generation": 1,
		"target_location_generation": 2,
	}
	var accepted := adapter.accept_origin_rebase(receipt)
	var after := adapter.get_session_snapshot()
	_check(
		accepted.accepted and accepted.reason == &"origin_rebase_accepted"
			and after.surface_route.next_landmark_id == before.surface_route.next_landmark_id
			and after.surface_hazard.hazard_ids == before.surface_hazard.hazard_ids
			and after.coordinate_frame_generation == 1
			and after.location_generation == 2,
		"accepted origin receipt updates frame metadata without changing route or hazard identity"
	)
	_check(
		adapter.accept_origin_rebase(receipt).reason == &"origin_generation_not_advanced",
		"the same origin receipt cannot be replayed"
	)
	director.queue_free()
	await process_frame


func _test_surface_water_recovery_preserves_route() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var navigation := NavigationScript.new()
	var water := WaterScript.new()
	navigation.configure(NavigationContractScript.new())
	water.configure(WaterContractScript.new())
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.bind_surface_water(water)
	adapter.start_surface_activity_sequence(
		[&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName],
		navigation,
		{"surface_staging_gate": &"ridge_relay"}
	)
	water.enter_water(Vector3(180.0, 120000.0, -240.0), 2)
	var safe := adapter.submit_surface_water_contact(
		Vector3(180.0, 120000.0, -240.0), 2.0, Vector3(1.0, 0.0, 0.0), 0.1
	)
	_check(
		safe.accepted and safe.reason == &"water_contact_sampled"
			and safe.adapter.surface_route.state == &"active",
		"safe water contact leaves route progress active"
	)
	var unsafe := adapter.submit_surface_water_contact(
		Vector3(180.0, 120000.0, -240.0), 20.0, Vector3(2.0, 0.0, 0.0), 0.1
	)
	_check(
		unsafe.accepted and unsafe.reason == &"shoreline_recovery_required"
			and unsafe.water.recovery_request.recovery_id == &"return_to_landed_ship"
			and unsafe.adapter.state == &"failed"
			and unsafe.adapter.surface_route.state == &"interrupted",
		"unsafe water contact interrupts route and emits authored shoreline recovery"
	)
	water.detach()
	host.attachment_generation = 3
	var recovered := adapter.recover_surface_water(
		Vector3(180.0, 120000.0, -240.0), 3
	)
	_check(
		recovered.accepted and recovered.reason == &"shoreline_recovered"
			and recovered.adapter.surface_route.state == &"active"
			and recovered.adapter.surface_route.waypoint_index == 0,
		"new water attachment resumes the current waypoint without replaying progress"
	)
	director.queue_free()
	await process_frame


func _test_landmark_discovery_admits_activity_once() -> void:
	var host := FakeHost.new()
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	var adapter := AdapterScript.new()
	var navigation := NavigationScript.new()
	var landmarks := LandmarkScript.new()
	navigation.configure(NavigationContractScript.new())
	landmarks.configure(LandmarkContractScript.new())
	landmarks.begin_activity_sequence([
		&"ember_beacon_survey", &"ember_kit_cargo_run",
	] as Array[StringName])
	adapter.bind(host, runtime, director, Callable(self, "_accept_reward"))
	adapter.bind_activity_landmarks(landmarks)
	adapter.start_surface_activity_sequence(
		[&"ember_beacon_survey", &"ember_caldera_patrol"] as Array[StringName],
		navigation,
		{"surface_staging_gate": &"ridge_relay"}
	)
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10.0, 0.0, 0.0))
	adapter.commit_activity_reward()
	host.attachment_generation = 3
	var admitted := adapter.submit_activity_landmark_discovery(
		&"ember_caldera_pad", Vector3(18.0, 0.0, 0.0),
		{"ember_caldera_pad": &"ridge_relay"}
	)
	_check(
		admitted.accepted and admitted.reason == &"landmark_activity_admitted"
			and admitted.adapter.activity_sequence.index == 1
			and admitted.adapter.activity_landmarks.sequence_index == 1,
		"discovered authored landmark admits exactly the next activity and persists its index"
	)
	_check(
		adapter.submit_activity_landmark_discovery(
			&"ember_caldera_pad", Vector3(18.0, 0.0, 0.0),
			{"ember_caldera_pad": &"ridge_relay"}
		).reason == &"landmark_order_mismatch",
		"the same discovery receipt cannot replay the activity admission"
	)
	director.queue_free()
	await process_frame


func _director_with_activity() -> ActivityDirector:
	var location := LocationScript.new()
	location.location_id = &"ember_caldera"
	location.display_name = "Ember Caldera"
	location.sector_id = &"ember_moon"
	location.anchor_source_id = &"caldera_relay"
	location.content_note = "Focused adapter fixture."
	var definition := ActivityDefinitionScript.new()
	definition.activity_id = &"ember_beacon_survey"
	definition.display_name = "Ember Beacon Survey"
	definition.content_note = "Focused adapter fixture."
	definition.location = location
	definition.checkpoint_positions = PackedVector3Array([
		Vector3.ZERO, Vector3(10.0, 0.0, 0.0),
	])
	var director := DirectorScript.new() as ActivityDirector
	director.register_definition(definition)
	var second_location := LocationScript.new()
	second_location.location_id = &"ember_ridge"
	second_location.display_name = "Ember Ridge"
	second_location.sector_id = &"ember_moon"
	second_location.anchor_source_id = &"ridge_relay"
	second_location.content_note = "Focused sequence fixture."
	var second_definition := ActivityDefinitionScript.new()
	second_definition.activity_id = &"ember_caldera_patrol"
	second_definition.display_name = "Ember Caldera Patrol"
	second_definition.content_note = "Focused sequence fixture."
	second_definition.location = second_location
	second_definition.checkpoint_positions = PackedVector3Array([
		Vector3.ZERO, Vector3(10.0, 0.0, 0.0),
	])
	director.register_definition(second_definition)
	root.add_child(director)
	return director


func _accept_reward(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"game_flow_reward_accepted"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_SURFACE_ACTIVITY_REWARD_ADAPTER_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("PLANETARY_SURFACE_ACTIVITY_REWARD_ADAPTER_TEST_FAIL: " + "; ".join(_failures))
	quit(1)
