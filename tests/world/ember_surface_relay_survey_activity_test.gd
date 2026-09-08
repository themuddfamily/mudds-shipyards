extends SceneTree

const ActivityScript := preload("res://scripts/world/ember_surface_relay_survey_activity.gd")
const AdapterScript := preload("res://scripts/world/planetary_surface_activity_reward_adapter.gd")
const RuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const DefinitionScript := preload("res://scripts/activities/activity_definition.gd")
const LocationScript := preload("res://scripts/world/definitions/world_location_definition.gd")

class CountingHost:
	var snapshot_count := 0
	var attachment_generation := 2
	func get_generation() -> int: return 7
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"},
		}

class SnapshotOnlyAdapter:
	var source: Object
	func _init(adapter: Object) -> void: source = adapter
	func get_snapshot() -> Dictionary: return source.get_snapshot()

var _failures := PackedStringArray()


class FakeAdapter:
	var sequence: Array = []
	var discoveries: Array = []
	var positions: Array = []
	func start_activity_sequence(ids: Array) -> Dictionary:
		sequence = ids.duplicate()
		return {"accepted": true, "reason": &"sequence_started"}
	func submit_activity_landmark_discovery(id: StringName, position: Vector3) -> Dictionary:
		discoveries.append({"id": id, "position": position})
		return {"accepted": true, "reason": &"landmark_discovered"}
	func submit_activity_position(position: Vector3) -> Dictionary:
		positions.append(position)
		return {"accepted": true, "reason": &"position_accepted"}
	func commit_activity_reward() -> Dictionary:
		return {"accepted": true, "reason": &"reward_committed"}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var adapter := FakeAdapter.new()
	var activity := ActivityScript.new()
	var started := activity.begin(adapter)
	var discovered := activity.submit_landmark(adapter, activity.START_LANDMARK_ID, Vector3(180.0, 120009.0, -44.0))
	var positioned := activity.submit_position(adapter, Vector3(200.0, 120010.0, -45.0))
	var committed := activity.commit_reward(adapter)
	var snapshot := activity.get_snapshot()
	if not started.accepted or adapter.sequence != [activity.ACTIVITY_ID] or not discovered.accepted \
			or not positioned.accepted or not committed.accepted or snapshot.authority.reward:
		push_error("relay survey activity facade failed")
		quit(1)
		return
	_test_focused_checkpoint_observations()
	if not _failures.is_empty():
		push_error("relay survey observations failed: " + "; ".join(_failures))
		quit(1)
		return
	print("EMBER_SURFACE_RELAY_SURVEY_ACTIVITY_TEST_OK: adapter-owned handoff; focused/legacy lifecycle parity and zero Host diagnostic reads")
	quit(0)


func _test_focused_checkpoint_observations() -> void:
	var host := CountingHost.new()
	var director := DirectorScript.new()
	var location := LocationScript.new()
	location.location_id = &"ember_caldera"
	location.display_name = "Ember Caldera"
	location.sector_id = &"ember_moon"
	location.anchor_source_id = &"caldera_relay"
	location.content_note = "Focused relay observation fixture."
	var definition := DefinitionScript.new()
	definition.activity_id = ActivityScript.ACTIVITY_ID
	definition.display_name = "Ember Beacon Survey"
	definition.content_note = "Focused relay observation fixture."
	definition.location = location
	definition.checkpoint_positions = PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)])
	director.register_definition(definition)
	root.add_child(director)
	var adapter := AdapterScript.new()
	var runtime := RuntimeScript.new()
	_check(adapter.bind(host, runtime, director, func(_receipt: Dictionary) -> Dictionary:
		return {"accepted": true, "reason": &"reward_accepted"}
	).accepted, "real adapter binds")
	var focused := ActivityScript.new()
	var legacy := ActivityScript.new()
	var snapshot_only := SnapshotOnlyAdapter.new(adapter)
	_check_views(focused, legacy, adapter, snapshot_only, host, "ready")
	_check(adapter.begin_activity(ActivityScript.ACTIVITY_ID).accepted, "activity starts")
	_check_views(focused, legacy, adapter, snapshot_only, host, "active")
	for interaction in [ActivityScript.OPTIONAL_INTERACTION_ID, ActivityScript.SAMPLE_RACK_INTERACTION_ID]:
		var receipt := {
			"interaction_id": interaction, "world_id": &"ember_moon",
			"activity_started": false, "reward_granted": false, "historical_claim": false,
			"host_generation": 7, "attachment_generation": 2,
			"activity_generation": runtime.get_snapshot().activity_generation,
			"checkpoint_id": ActivityScript.SAMPLE_RACK_CHECKPOINT_ID,
			"completion_response_id": ActivityScript.SAMPLE_RACK_RESPONSE_ID,
		}
		var before := host.snapshot_count
		var result := focused.submit_optional_checkpoint(adapter, receipt)
		_check(result.accepted and host.snapshot_count == before, "checkpoint admission avoids Host diagnostics")
		_check(result == legacy.submit_optional_checkpoint(snapshot_only, receipt), "checkpoint result preserves legacy output")
		_check_views(focused, legacy, adapter, snapshot_only, host, String(interaction))
	adapter.detach()
	_check_views(focused, legacy, adapter, snapshot_only, host, "detached")
	host.attachment_generation += 1
	_check(adapter.reenter().accepted, "activity reenters")
	adapter.submit_activity_position(Vector3.ZERO)
	adapter.submit_activity_position(Vector3(10, 0, 0))
	_check_views(focused, legacy, adapter, snapshot_only, host, "awaiting reward")
	_check(adapter.commit_activity_reward().accepted, "reward commits")
	_check_views(focused, legacy, adapter, snapshot_only, host, "completed")
	host.attachment_generation += 1
	_check(adapter.repeat_activity(ActivityScript.ACTIVITY_ID).accepted, "activity repeats")
	_check_views(focused, legacy, adapter, snapshot_only, host, "repeated")
	_check(focused.get_snapshot(adapter).optional_progress.completed_count == 0, "fresh generation clears both optional receipts")
	director.free()


func _check_views(focused: RefCounted, legacy: RefCounted, adapter: Object,
		snapshot_only: Object, host: Object, stage: String) -> void:
	var before: int = host.snapshot_count
	var actual: Dictionary = focused.get_snapshot(adapter)
	_check(host.snapshot_count == before, stage + " reads no Host diagnostics")
	var expected: Dictionary = legacy.get_snapshot(snapshot_only)
	_check(host.snapshot_count == before + 1, stage + " legacy adapter is observed once")
	_check(actual == expected, stage + " preserves every public snapshot field")
	actual.optional_checkpoint.authority.route = true
	actual.optional_progress.completed_count = 99
	_check(focused.get_snapshot(adapter) == expected, stage + " snapshot remains detached")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
