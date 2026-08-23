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
	var player_instance_id: int
	func _init(value: int, player_id: int) -> void:
		generation = value
		player_instance_id = player_id
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": &"on_foot",
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": player_instance_id,
			},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0
var _interaction_signals := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://ember-optional-roundtrip.json", filesystem)
	_check(bool(store.load().accepted), "the real user-data store loads")
	_check(
		bool(store.commit({"foreign": {"retained": 73}}, 0, "seed-foreign").accepted),
		"foreign user data is present before the terminal receipt"
	)

	var first := await _make_surface(101, store)
	var first_binding := first.binding as Node
	var first_flow := first.flow as GameFlow
	var first_actor := first.actor as Node3D
	var first_interaction := first_binding.get_node("OwnedSurveyBunkerInteraction")
	first_interaction.connect(&"survey_completed", _on_survey_completed)
	var bound := first_flow.bind_ember_relay_survey_persistence(first_binding)
	var started := first_binding.call(&"start_relay_survey") as Dictionary
	var logged := first_interaction.call(
		&"submit_interaction", first_actor, 101, 1
	) as Dictionary
	var relay := first_binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	) as Dictionary
	var returned := first_binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	) as Dictionary
	var committed := first_binding.call(&"commit_relay_survey_reward") as Dictionary
	var stored_completion := (
		(store.get_snapshot().ember_relay_survey_completion as Dictionary).completion \
		as Dictionary
	)
	_check(
		bool(bound.accepted) and bool(started.accepted) and bool(logged.accepted)
			and bool(relay.accepted) and bool(returned.accepted)
			and bool(committed.accepted)
			and bool((committed.persistence as Dictionary).accepted)
			and bool((stored_completion.optional_checkpoint as Dictionary).completed)
			and int((store.get_snapshot().foreign as Dictionary).retained) == 73
			and int(store.get_generation()) == 2
			and _reward_calls == 1 and _interaction_signals == 1,
		"accepted optional log is atomically sealed into the terminal reward receipt"
	)
	_cleanup_surface(first)
	await process_frame

	var second := await _make_surface(102, store)
	var second_binding := second.binding as Node
	var second_flow := second.flow as GameFlow
	var second_actor := second.actor as Node3D
	var second_host := second.host as FakeHost
	var second_interaction := second_binding.get_node("OwnedSurveyBunkerInteraction")
	second_interaction.connect(&"survey_completed", _on_survey_completed)
	var rebound := second_flow.bind_ember_relay_survey_persistence(second_binding)
	var restored := second_flow.restore_ember_relay_survey_persistence()
	var restored_snapshot := second_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(rebound.accepted) and bool(restored.accepted)
			and not bool(restored.reward_replay_allowed)
			and restored_snapshot.adapter.activity_reward.state == &"ready"
			and bool(restored_snapshot.survey_interaction.completed)
			and bool(restored_snapshot.survey_interaction.completion_response.revealed)
			and bool(restored_snapshot.survey_interaction.completion_response.collision_enabled)
			and restored_snapshot.survey_interaction.wayfinding.state \
				== &"service_entry_lintel"
			and restored_snapshot.relay_survey_presentation.hud.progress_text \
				== "OPTIONAL BUNKER LOG  1 / 1"
			and _reward_calls == 1 and _interaction_signals == 1,
		"GameFlow reload restores the completed alcove and lintel as presentation only"
	)
	var replayed_interaction := second_interaction.call(
		&"submit_interaction", second_actor, 102, 1
	) as Dictionary
	var replayed_reward := second_binding.call(&"commit_relay_survey_reward") as Dictionary
	_check(
		not bool(replayed_interaction.accepted)
			and replayed_interaction.reason == &"survey_interaction_already_completed"
			and not bool(replayed_reward.accepted)
			and _reward_calls == 1 and _interaction_signals == 1
			and int(store.get_generation()) == 2,
		"restored presentation cannot replay the interaction, reward, or store write"
	)

	var detached := second_binding.call(&"detach") as Dictionary
	var hidden := second_binding.call(&"get_snapshot") as Dictionary
	second_host.attachment_generation = 2
	var reentered := second_binding.call(&"reenter") as Dictionary
	var revisited := second_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached.accepted)
			and not bool(hidden.survey_interaction.completion_response.revealed)
			and not bool(hidden.survey_interaction.completion_response.collision_enabled)
			and bool(reentered.accepted)
			and bool(revisited.survey_interaction.completion_response.revealed)
			and bool(revisited.survey_interaction.completion_response.collision_enabled)
			and revisited.survey_interaction.wayfinding.state == &"service_entry_lintel",
		"detach hides collision and same receipt re-entry restores the physical response"
	)
	var fresh_run := second_binding.call(&"start_relay_survey") as Dictionary
	var incomplete := second_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(fresh_run.accepted)
			and not bool(incomplete.relay_survey_persistence.restored)
			and not bool(incomplete.relay_survey.optional_checkpoint.completed)
			and incomplete.relay_survey_presentation.hud.progress_text \
				== "OPTIONAL BUNKER LOG  0 / 1"
			and bool(incomplete.survey_interaction.completed)
			and int(store.get_generation()) == 2,
		"a newer incomplete run clears run-scoped optional progress without rewriting save"
	)
	_cleanup_surface(second)
	await process_frame

	var third := await _make_surface(103, store)
	var third_binding := third.binding as Node
	var third_flow := third.flow as GameFlow
	third_flow.bind_ember_relay_survey_persistence(third_binding)
	var stable_restore := third_flow.restore_ember_relay_survey_persistence()
	var stable := third_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(stable_restore.accepted)
			and bool(stable.survey_interaction.completion_response.revealed)
			and stable.relay_survey_presentation.hud.progress_text \
				== "OPTIONAL BUNKER LOG  1 / 1"
			and _reward_calls == 1 and _interaction_signals == 1
			and int((store.get_snapshot().foreign as Dictionary).retained) == 73,
		"reload discards incomplete progress and retains the last terminal optional receipt"
	)
	_cleanup_surface(third)
	await process_frame

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_RELAY_SURVEY_OPTIONAL_GAMEFLOW_ROUNDTRIP_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _make_surface(generation: int, store: RefCounted) -> Dictionary:
	var actor := Node3D.new()
	root.add_child(actor)
	var host := FakeHost.new(generation, actor.get_instance_id())
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame
	var configured := binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), generation
	) as Dictionary
	var flow := GameFlowScript.new() as GameFlow
	_check(
		bool(configured.accepted) and flow.configure_runtime_settings_persistence(store),
		"fresh production surface and GameFlow share the caller-owned store"
	)
	return {
		"actor": actor, "host": host, "director": director,
		"binding": binding, "flow": flow,
	}


func _cleanup_surface(surface: Dictionary) -> void:
	(surface.binding as Node).queue_free()
	(surface.director as Node).queue_free()
	(surface.actor as Node).queue_free()
	(surface.flow as GameFlow).free()


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"game_flow_reward_committed"}


func _on_survey_completed(_receipt: Dictionary) -> void:
	_interaction_signals += 1


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
