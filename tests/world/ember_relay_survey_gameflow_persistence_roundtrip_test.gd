extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)

class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK

class FakeHost:
	var generation: int
	var attachment_generation := 1
	func _init(value: int) -> void: generation = value
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": &"on_foot",
			"identities": {"world_id": &"ember_moon"},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://ember-survey-roundtrip.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic user-data store loads")
	_check(
		bool(store.commit({"foreign": {"retained": 41}}, 0, "seed").accepted),
		"a foreign user-data section is seeded before the survey transaction"
	)

	var first := await _make_surface(81, store)
	var first_binding := first.binding as Node
	var first_flow := first.flow as GameFlow
	var bound := first_flow.bind_ember_relay_survey_persistence(first_binding)
	var started := first_binding.call(&"start_relay_survey") as Dictionary
	var relay := first_binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	) as Dictionary
	var returned := first_binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	) as Dictionary
	var committed := first_binding.call(&"commit_relay_survey_reward") as Dictionary
	var first_snapshot := first_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(bound.accepted) and bool(started.accepted) and bool(relay.accepted)
			and bool(returned.accepted) and bool(committed.accepted)
			and bool((committed.persistence as Dictionary).accepted)
			and _reward_calls == 1
			and first_snapshot.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed"
			and int(store.get_generation()) == 2
			and int((store.get_snapshot().foreign as Dictionary).retained) == 41,
		"accepted reward commits once and atomically merges its terminal receipt"
	)
	first_binding.queue_free()
	(first.director as Node).queue_free()
	first_flow.free()
	await process_frame

	var second := await _make_surface(82, store)
	var second_binding := second.binding as Node
	var second_flow := second.flow as GameFlow
	var rebound := second_flow.bind_ember_relay_survey_persistence(second_binding)
	var restored := second_flow.restore_ember_relay_survey_persistence()
	var restored_snapshot := second_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(rebound.accepted) and bool(restored.accepted)
			and not bool(restored.reward_replay_allowed)
			and restored_snapshot.adapter.activity_reward.state == &"ready"
			and bool(restored_snapshot.relay_survey_persistence.restored)
			and restored_snapshot.relay_survey_presentation.state == &"completed"
			and restored_snapshot.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed"
			and restored_snapshot.relay_survey_presentation.mandatory_checkpoint_progress.progress_text \
				== "2 / 2 MANDATORY"
			and _reward_calls == 1,
		"GameFlow reload restores a readable completion without replaying authority"
	)
	var replay_commit := second_binding.call(&"commit_relay_survey_reward") as Dictionary
	var repeated_restore := second_flow.restore_ember_relay_survey_persistence()
	_check(
		not bool(replay_commit.accepted)
			and replay_commit.reason == &"adapter_activity_not_active"
			and not bool(repeated_restore.accepted)
			and repeated_restore.reason == &"survey_persistence_already_restored"
			and _reward_calls == 1 and int(store.get_generation()) == 2,
		"repeat restore and reward commit cannot duplicate the callback or store write"
	)

	var fresh_run := second_binding.call(&"start_relay_survey") as Dictionary
	var incomplete_snapshot := second_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(fresh_run.accepted)
			and not bool(incomplete_snapshot.relay_survey_persistence.restored)
			and incomplete_snapshot.relay_survey_presentation.state == &"active"
			and incomplete_snapshot.relay_survey_presentation.mandatory_checkpoint_progress.progress_text \
				== "0 / 2 MANDATORY"
			and int(store.get_generation()) == 2 and _reward_calls == 1,
		"a new incomplete run is generation-scoped and never overwrites completion"
	)
	second_binding.queue_free()
	(second.director as Node).queue_free()
	second_flow.free()
	await process_frame

	var third := await _make_surface(83, store)
	var third_binding := third.binding as Node
	var third_flow := third.flow as GameFlow
	third_flow.bind_ember_relay_survey_persistence(third_binding)
	var stable_restore := third_flow.restore_ember_relay_survey_persistence()
	var stable_snapshot := third_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(stable_restore.accepted)
			and stable_snapshot.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed"
			and int(store.get_generation()) == 2
			and _reward_calls == 1
			and not bool(stable_snapshot.relay_survey_persistence.authority.save)
			and not bool(stable_snapshot.relay_survey_persistence.authority.reward)
			and not bool(stable_snapshot.relay_survey_persistence.authority.activity),
		"reload discards incomplete progress and returns to the last terminal receipt"
	)
	third_binding.queue_free()
	(third.director as Node).queue_free()
	third_flow.free()
	await process_frame

	for failure in _failures:
		push_error(failure)
	print("EMBER_RELAY_SURVEY_GAMEFLOW_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _make_surface(generation: int, store: RefCounted) -> Dictionary:
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame
	var host := FakeHost.new(generation)
	var configured := binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), generation
	) as Dictionary
	var flow := GameFlowScript.new() as GameFlow
	var injected := flow.configure_runtime_settings_persistence(store)
	_check(
		bool(configured.accepted) and injected,
		"fresh production surface and GameFlow share the caller-owned store"
	)
	return {"binding": binding, "director": director, "flow": flow, "host": host}


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"game_flow_reward_committed"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
