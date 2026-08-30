extends SceneTree

const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload(
	"res://scripts/persistence/user_data_filesystem.gd"
)

const STORE_PATH := "memory://ember-active-checkpoint-resume.json"


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
	var generation := 31
	var attachment_generation := 6
	var session := RefCounted.new()
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_travel_session_observation_source() -> Object: return session
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": true,
			"generation": generation,
			"attachment_generation": attachment_generation,
			"phase_id": &"on_foot",
			"identities": {
				"world_id": &"ember_moon", "player_instance_id": 101,
			},
		}


class LifecycleFlow extends GameFlowScript:
	var save_evidence: Dictionary = {}
	var restore_frame: RefCounted
	func _collect_ember_interrupted_journey_save_evidence() -> Dictionary:
		return save_evidence.duplicate(true)
	func _get_ember_interrupted_journey_restore_frame() -> Object:
		return restore_frame


var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var first_store = StoreScript.new(STORE_PATH, filesystem)
	_check(bool(first_store.load().accepted), "first normal user-data store loads")
	var first_host := FakeHost.new()
	var first_director := DirectorScript.new()
	root.add_child(first_director)
	var first_binding := BindingScript.new()
	root.add_child(first_binding)
	_check(
		bool(first_binding.configure(
			first_host, first_director, Callable(self, "_reward_sink"), 31
		).accepted),
		"first production Ember surface composition is live",
	)
	var first_flow := LifecycleFlow.new()
	_check(
		first_flow.configure_runtime_settings_persistence(first_store)
			and bool(first_flow.bind_ember_relay_survey_persistence(
				first_binding
			).accepted),
		"first GameFlow binds the production Ember persistence surface",
	)
	var started := first_binding.start_relay_survey()
	var relay_reached := first_binding.submit_relay_survey_position(
		Vector3(180.0, 120009.0, -44.0)
	)
	var first_route := (
		first_binding.get_snapshot().relay_survey.mandatory_route as Dictionary
	).duplicate(true)
	_check(
		bool(started.accepted) and bool(relay_reached.accepted)
			and int(first_route.next_checkpoint_index) == 1
			and first_route.next_objective_id == &"ember_return_beacon",
		"the live ActivityDirector advances to the return-beacon objective",
	)

	var frame = _frame()
	var tangent := Vector3(24.0, 8.0, -13.0)
	var body_local: Dictionary = frame.surface_tangent_to_body_local(tangent, 1)
	var orbital: Dictionary = frame.body_local_to_orbital_position(
		body_local.position as Vector3, 1
	)
	first_flow.set("_ember_surface_journey_active", true)
	first_flow.save_evidence = {
		"accepted": true,
		"frame": frame,
		"host": {
			"generation": 31,
			"attachment_generation": 6,
			"coordinate_frame_generation": 1,
			"physics_advance_count": 1440,
			"phase_id": &"on_foot",
		},
		"route": first_route,
		"coordinate": {
			"orbital_coordinate": orbital.coordinate,
			"surface_tangent_position": tangent,
		},
	}
	var saved := first_flow.save_interrupted_ember_journey()
	_check(
		bool(saved.accepted) and saved.binding_reason == &"active_journey_saved",
		"the normal save boundary persists the interrupted checkpoint identity",
	)
	first_flow.free()
	first_binding.queue_free()
	first_director.queue_free()
	await process_frame

	var second_store = StoreScript.new(STORE_PATH, filesystem)
	var second_host := FakeHost.new()
	second_host.attachment_generation = 7
	var second_director := DirectorScript.new()
	root.add_child(second_director)
	var second_binding := BindingScript.new()
	root.add_child(second_binding)
	_check(
		bool(second_binding.configure(
			second_host, second_director, Callable(self, "_reward_sink"), 31
		).accepted),
		"relaunch creates a fresh production surface composition",
	)
	var second_flow := LifecycleFlow.new()
	second_flow.restore_frame = _frame()
	_check(
		second_flow.configure_runtime_settings_persistence(second_store)
			and bool(second_flow.bind_ember_relay_survey_persistence(
				second_binding
			).accepted),
		"relaunched GameFlow binds the same save slot",
	)
	var admitted := second_flow._restore_ember_surface_persistence_for_admission()
	var staged := admitted.get("checkpoint_resume", {}) as Dictionary
	_check(
		bool(admitted.accepted)
			and admitted.reason == &"ember_active_journey_passively_adopted"
			and bool(staged.get("accepted", false))
			and staged.reason == &"relay_survey_resume_staged"
			and second_director.get_activity_snapshot(&"ember_beacon_survey").is_empty()
			and _reward_calls == 0,
		"admission stages the receipt passively without touching activity or reward authority",
	)

	var resumed := second_binding.start_relay_survey()
	var director_route := second_director.get_activity_snapshot(
		&"ember_beacon_survey"
	)
	var resumed_route := (
		second_binding.get_snapshot().relay_survey.mandatory_route as Dictionary
	)
	_check(
		bool(resumed.accepted)
			and resumed.reason == &"activity_sequence_resumed"
			and int(director_route.generation) == int(first_route.activity_generation)
			and int(director_route.next_checkpoint_index) == 1
			and int(resumed_route.next_checkpoint_index) == 1
			and resumed_route.next_objective_id == &"ember_return_beacon",
		"the normal survey-start seam restores the exact director checkpoint and objective",
	)
	_check(
		_reward_calls == 0
			and (second_binding.get_snapshot().adapter.activity_reward as Dictionary).state
				== &"active",
		"resume neither grants nor reconstructs a reward",
	)
	var completed := second_binding.submit_relay_survey_position(
		Vector3(540.0, 120030.0, -210.0)
	)
	_check(
		bool(completed.accepted)
			and int(completed.next_checkpoint_index) == 2
			and (completed.runtime as Dictionary).state == &"awaiting_reward"
			and _reward_calls == 0,
		"fresh player evidence completes the remaining checkpoint without auto-committing reward",
	)
	second_flow.free()
	second_binding.queue_free()
	second_director.queue_free()
	await process_frame

	var fresh_host := FakeHost.new()
	var fresh_director := DirectorScript.new()
	root.add_child(fresh_director)
	var fresh_binding := BindingScript.new()
	root.add_child(fresh_binding)
	_check(
		bool(fresh_binding.configure(
			fresh_host, fresh_director, Callable(self, "_reward_sink"), 31
		).accepted)
			and bool(fresh_binding.start_relay_survey().accepted)
			and int(fresh_director.get_activity_snapshot(
				&"ember_beacon_survey"
			).next_checkpoint_index) == 0,
		"a new game still starts the Beacon Survey at its first checkpoint",
	)
	fresh_binding.queue_free()
	fresh_director.queue_free()
	await process_frame

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_ACTIVE_JOURNEY_CHECKPOINT_RESUME_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _frame():
	var frame = FrameScript.new()
	var origin := {
		"schema_version": FrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": &"nearby_sector",
		"cell_x": 55,
		"cell_y": -18,
		"cell_z": 4,
		"offset_meters": Vector3.ZERO,
	}
	var configured: Dictionary = frame.configure(
		&"ember_moon", 1_000.0, &"nearby_sector", 10_000.0,
		origin, Vector3.BACK, Vector3.UP, 5_000.0, origin
	)
	if not bool(configured.accepted):
		_failures.append("frame fixture failed: %s" % configured)
	return frame


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
