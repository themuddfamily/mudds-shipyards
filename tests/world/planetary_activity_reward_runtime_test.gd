extends SceneTree

const RuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const ManifestScript := preload("res://scripts/world/planetary_objective_reward_recovery_contract.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const ActivityDefinitionScript := preload("res://scripts/activities/activity_definition.gd")
const LocationScript := preload("res://scripts/world/definitions/world_location_definition.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0
var _last_reward := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_activity_to_reward_commit()
	await _test_stale_and_reentry_fences()
	_finish()


func _test_activity_to_reward_commit() -> void:
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	_check(
		runtime.bind(director, Callable(self, "_accept_reward")).accepted,
		"runtime binds the existing activity director and reward callback"
	)
	_check(runtime.begin_visit(1, 1).accepted, "visit begins with explicit generations")
	var started := runtime.start_activity(&"ember_beacon_survey", 1, 1)
	var activity_generation := int(started.runtime.activity_generation)
	_check(
		started.accepted and activity_generation == 1
			and started.runtime.state == &"active",
		"authored planetary activity starts through the existing director"
	)
	_check(
		not runtime.submit_position(Vector3.ZERO, activity_generation, 2, 1).accepted,
		"stale run completion input is rejected"
	)
	_check(
		runtime.submit_position(Vector3.ZERO, activity_generation, 1, 1).accepted,
		"the first authored checkpoint is accepted"
	)
	var completed := runtime.submit_position(
		Vector3(10.0, 0.0, 0.0), activity_generation, 1, 1
	)
	_check(
		completed.accepted and completed.runtime.state == &"awaiting_reward"
			and completed.runtime.pending_reward.reward_id == &"ember_beacon_data",
		"activity completion creates one detached reward receipt"
	)
	var committed := runtime.commit_reward(&"ember_beacon_survey", activity_generation, 1, 1)
	_check(
		committed.accepted and committed.reason == &"reward_committed"
			and committed.runtime.state == &"completed"
			and _reward_calls == 1
			and _last_reward.reward_store_id == &"game_flow_reward_store",
		"completion commits exactly one reward through the injected existing authority"
	)
	_check(
		runtime.commit_reward(&"ember_beacon_survey", activity_generation, 1, 1).reason
			== &"reward_not_pending",
		"completed reward cannot be replayed"
	)
	var audit := runtime.audit()
	_check(
		audit.valid and audit.production_wiring
			and not audit.owns_reward_store and not audit.owns_save_authority,
		"audit exposes production wiring without a second store or save authority"
	)
	director.queue_free()
	await process_frame


func _test_stale_and_reentry_fences() -> void:
	var director := _director_with_activity()
	var runtime := RuntimeScript.new()
	runtime.bind(director, Callable(self, "_accept_reward"))
	runtime.begin_visit(4, 1)
	var started := runtime.start_activity(&"ember_beacon_survey", 4, 1)
	var generation := int(started.runtime.activity_generation)
	runtime.submit_position(Vector3.ZERO, generation, 4, 1)
	runtime.submit_position(Vector3(10.0, 0.0, 0.0), generation, 4, 1)
	_check(runtime.detach(4, 1).accepted, "pending reward can detach without being lost")
	var pending: Dictionary = runtime.get_snapshot().pending_reward
	_check(
		runtime.commit_reward(&"ember_beacon_survey", generation, 4, 1).reason
			== &"detached",
		"detached runtime rejects stale reward commits"
	)
	_check(runtime.begin_visit(4, 1).reason == &"stale_attachment_generation", "re-entry rejects the old attachment")
	_check(runtime.begin_visit(4, 2).accepted, "re-entry adopts a newer attachment generation")
	_check(
		runtime.get_snapshot().pending_reward == pending
			and runtime.get_snapshot().state == &"awaiting_reward",
		"re-entry retains the detached pending reward receipt"
	)
	_check(
		runtime.commit_reward(&"other_activity", generation, 4, 2).reason
			== &"reward_completion_identity_mismatch",
		"re-entry cannot substitute another activity reward"
	)
	var committed := runtime.commit_reward(&"ember_beacon_survey", generation, 4, 2)
	_check(committed.accepted and _reward_calls == 2, "re-entered receipt commits once")
	director.queue_free()
	await process_frame


func _director_with_activity() -> ActivityDirector:
	var location := LocationScript.new()
	location.location_id = &"ember_caldera"
	location.display_name = "Ember Caldera"
	location.sector_id = &"ember_moon"
	location.anchor_source_id = &"caldera_relay"
	location.content_note = "Focused runtime fixture."
	var definition := ActivityDefinitionScript.new()
	definition.activity_id = &"ember_beacon_survey"
	definition.display_name = "Ember Beacon Survey"
	definition.content_note = "Focused runtime fixture."
	definition.location = location
	definition.checkpoint_positions = PackedVector3Array([
		Vector3.ZERO, Vector3(10.0, 0.0, 0.0),
	])
	var director := DirectorScript.new() as ActivityDirector
	director.register_definition(definition)
	root.add_child(director)
	return director


func _accept_reward(receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	_last_reward = receipt.duplicate(true)
	return {"accepted": true, "reason": &"game_flow_reward_accepted"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_ACTIVITY_REWARD_RUNTIME_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("PLANETARY_ACTIVITY_REWARD_RUNTIME_TEST_FAIL: " + "; ".join(_failures))
	quit(1)
