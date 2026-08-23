extends SceneTree

const AdapterScript := preload("res://scripts/world/planetary_surface_activity_reward_adapter.gd")
const RuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const ActivityDefinitionScript := preload("res://scripts/activities/activity_definition.gd")
const LocationScript := preload("res://scripts/world/definitions/world_location_definition.gd")

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
