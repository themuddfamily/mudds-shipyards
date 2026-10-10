extends SceneTree

## Focused production round trip for the active GameFlow-owned patrol. It uses
## the real Main, PatrolActivity, ActivityDirector, and atomic UserDataStore,
## while keeping every byte in one injected in-memory filesystem.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const PLATFORM_ROUTE := preload("res://assets/activities/cinder_reach_platform_patrol_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const SessionPersistence := preload(
	"res://scripts/persistence/cinder_patrol_session_persistence.gd"
)
const NearbyActivitySessionAdapter := preload(
	"res://scripts/persistence/nearby_sector_activity_session_adapter.gd"
)

const STORE_PATH := "memory://cinder-patrol-session.json"
const CORRUPT_STORE_PATH := "memory://corrupt-cinder-patrol-session.json"
const SLOT: StringName = &"cinder_patrol_session"


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}
	var reject_writes := false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_writes:
			return ERR_UNAVAILABLE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


## Real disk: reject a receipt write, then freeze after the live patrol's
## terminal record publishes. Frozen teardown cannot repair the profile.
class InterruptedPatrolRewardFilesystem extends UserDataFilesystem:
	var stopped := false
	var reward_rejected := false
	var terminal_staged := false
	var interrupt_rewards := true
	var stage_reward_before_refusal := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if stopped:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if interrupt_rewards and document is Dictionary and str((document.get("commit", {}) as Dictionary).get("id", "")).begins_with("game-flow-reward-"):
			if stage_reward_before_refusal:
				var staged := super.write_bytes_and_flush(path, bytes)
				if staged != OK:
					return staged
			reward_rejected = true
			stopped = terminal_staged
			return ERR_UNAVAILABLE
		if document is Dictionary and path.ends_with(".tmp"):
			var slot: Dictionary = (document.get("payload", {}) as Dictionary).get("cinder_patrol_session", {})
			if slot.get("activities") is Array and not slot.activities.is_empty():
				terminal_staged = int((slot.activities[0] as Dictionary).get("state", -1)) == PatrolActivity.State.COMPLETED
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if stopped else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		if stopped:
			return ERR_UNAVAILABLE
		var result := super.rename_path(from_path, to_path)
		if result == OK and from_path.ends_with(".tmp") and terminal_staged and reward_rejected and interrupt_rewards:
			stopped = true
		return result


class RejectingPatrolFilesystem extends UserDataFilesystem:
	var reject_writes := false
	var rejected_writes := 0

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_writes:
			rejected_writes += 1
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--backup-recovery"):
		await _test_platform_patrol_fallback_refusal()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--genuine-write-recovery"):
		await _test_genuine_write_recovery()
		await _test_reset_branch_choice_recovery()
		_finish()
		return
	var filesystem := MemoryFilesystem.new()
	var first_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	first_store.load()
	first_store.commit(
		{"foreign": {"pilot_callsign": "MUDDS"}},
		first_store.get_generation(),
		"seed-patrol-session-foreign-data"
	)
	var first := await _make_game(first_store)
	if first == null:
		_finish()
		return
	first.set_physics_process(false)
	var selected := first.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var craft := first.get_flyable_ships()[1] as HeroShip
	first.active_ship = craft
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var started := first.request_activity_start(ROUTE.activity_id)
	craft.global_position = Vector3.ZERO
	first.call("_physics_process", 0.5)
	craft.global_position = ROUTE.get_checkpoint_position(0)
	first.call("_physics_process", 0.75)
	var before := first.get_active_activity_snapshot()
	var saved := first.save_cinder_patrol_session()
	var stored_generation := first_store.get_generation()
	_check(
		bool(selected.get("accepted", false))
			and bool(started.get("accepted", false))
			and bool(saved.get("accepted", false))
			and before.get("state_id", &"") == &"active"
			and before.get("phase_id", &"") == &"dwell"
			and int(before.get("next_checkpoint_index", -1)) == 0
			and is_equal_approx(float(before.get("current_time_seconds", -1.0)), 1.25)
			and is_equal_approx(float(before.get("dwell_elapsed_seconds", -1.0)), 0.75),
		"normal GameFlow selection saves the exact active patrol clock and dwell"
	)
	var first_payload := first_store.get_snapshot()
	_check(
		(first_payload.get(String(SLOT), {}) as Dictionary)
			.get("schema_version", 0) == NearbyActivitySessionAdapter.SCHEMA_VERSION
			and ((first_payload.get("foreign", {}) as Dictionary)
				.get("pilot_callsign", "") == "MUDDS")
			and first.get_cinder_patrol_session_persistence_report()
				.get("shares_runtime_settings_store", false),
		"the patrol codec merges into GameFlow's one existing atomic store"
	)
	await _retire_game(first)

	var second_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	var second := await _make_game(second_store)
	if second == null:
		_finish()
		return
	second.set_physics_process(false)
	var restored := second.get_active_activity_snapshot()
	var integration := second.get_activity_integration_report()
	var report := second.get_cinder_patrol_session_persistence_report()
	var patrol := integration.get("patrol_activity") as PatrolActivity
	_check(
		bool((report.get("restore_status", {}) as Dictionary).get("accepted", false))
			and integration.get("selected_activity_kind", &"")
				== GameFlow.ACTIVITY_KIND_PATROL
			and int(integration.get("attached_route_owner_count", 0)) == 1
			and restored.get("state_id", &"") == &"active"
			and restored.get("phase_id", &"") == &"dwell"
			and int(restored.get("session_generation", -1))
				== int(before.get("session_generation", -2))
			and is_equal_approx(
				float(restored.get("current_time_seconds", -1.0)),
				float(before.get("current_time_seconds", -2.0))
			)
			and is_equal_approx(
				float(restored.get("dwell_elapsed_seconds", -1.0)),
				float(before.get("dwell_elapsed_seconds", -2.0))
			)
			and int(restored.get("patrol_actor_instance_id", -1)) == 0,
		"a fresh GameFlow startup adopts the same active route and patrol authority"
	)

	var lifecycle_counts := {
		"started": 0,
		"checkpoint": 0,
		"completed": 0,
		"failed": 0,
		"reset": 0,
	}
	patrol.patrol_started.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.started = int(lifecycle_counts.started) + 1
	)
	patrol.checkpoint_dwell_completed.connect(
		func(_snapshot: Dictionary, _checkpoint: int) -> void:
			lifecycle_counts.checkpoint = int(lifecycle_counts.checkpoint) + 1
	)
	patrol.patrol_completed.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.completed = int(lifecycle_counts.completed) + 1
	)
	patrol.patrol_failed.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.failed = int(lifecycle_counts.failed) + 1
	)
	patrol.patrol_reset.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.reset = int(lifecycle_counts.reset) + 1
	)
	var restored_state := patrol.capture_persistence_state()
	var restore_again := patrol.restore_persistence_state(
		second.get_activity_director(), restored_state, patrol.get_generation()
	)
	_check(
		not bool(restore_again.get("accepted", true))
			and restore_again.get("reason", &"") == &"patrol_already_live"
			and patrol.capture_persistence_state() == restored_state
			and lifecycle_counts == {
				"started": 0, "checkpoint": 0, "completed": 0,
				"failed": 0, "reset": 0,
			},
		"restore is startup-only and replays no historical lifecycle signal"
	)

	var restored_craft := second.get_flyable_ships()[1] as HeroShip
	restored_craft.global_position = ROUTE.get_checkpoint_position(0)
	second.active_ship = restored_craft
	second.set("_piloting", true)
	second.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	second.call("_physics_process", 5.0)
	var unrelated_phase := second.get_active_activity_snapshot()
	second.phase = GameFlow.Phase.FREE_FLIGHT
	second.set("_piloting", false)
	second.call("_physics_process", 5.0)
	var not_piloting := second.get_active_activity_snapshot()
	second.set("_piloting", true)
	second.active_ship = null
	second.call("_physics_process", 5.0)
	var no_ship := second.get_active_activity_snapshot()
	_check(
		is_equal_approx(float(unrelated_phase.get("current_time_seconds", -1.0)), 1.25)
			and unrelated_phase == not_piloting
			and not_piloting == no_ship
			and lifecycle_counts == {
				"started": 0, "checkpoint": 0, "completed": 0,
				"failed": 0, "reset": 0,
			},
		"restored patrol time and dwell freeze outside piloted FREE_FLIGHT"
	)

	second.active_ship = restored_craft
	second.call("_physics_process", 0.25)
	var resumed := second.get_active_activity_snapshot()
	_check(
		is_equal_approx(float(resumed.get("current_time_seconds", -1.0)), 1.5)
			and is_equal_approx(float(resumed.get("dwell_elapsed_seconds", -1.0)), 1.0)
			and int(resumed.get("patrol_actor_instance_id", 0))
				== restored_craft.get_instance_id()
			and lifecycle_counts == {
				"started": 0, "checkpoint": 0, "completed": 0,
				"failed": 0, "reset": 0,
			},
		"the next valid production ship sample binds once and resumes exact dwell"
	)

	var adapter := SessionPersistence.new() as CinderPatrolSessionPersistence
	adapter.configure(second_store, SLOT)
	var exact_live := adapter.save_state(
		patrol.capture_persistence_state(),
		patrol,
		second.get_activity_director(),
		"exact-live-cinder-patrol-session"
	)
	restored_craft.global_position = ROUTE.get_checkpoint_position(1)
	second.call("_physics_process", 0.25)
	var interrupted_state := patrol.capture_persistence_state()
	var interrupted_saved := second.save_cinder_patrol_session()
	var valid_interruption_record := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	restored_craft.global_position = ROUTE.get_checkpoint_position(0)
	second.call("_physics_process", 0.25)
	var resumed_dwell_saved := second.save_cinder_patrol_session()
	var after_interruption := patrol.capture_persistence_state()
	var persisted_after_interruption := _stored_patrol_state(second_store)
	_check(
		bool(exact_live.get("accepted", false))
			and bool(interrupted_saved.get("accepted", false))
			and int(interrupted_state.get("dwell_checkpoint_index", -1)) == 0
			and interrupted_state.get("checkpoint_occupied", true) == false
			and float(interrupted_state.get("dwell_elapsed_seconds", -1.0)) == 0.0
			and bool(adapter.validate_record(
				valid_interruption_record,
				patrol,
				second.get_activity_director()
			).get("accepted", false))
			and bool(resumed_dwell_saved.get("accepted", false))
			and is_equal_approx(
				float(after_interruption.get("dwell_elapsed_seconds", -1.0)), 0.25
			)
			and persisted_after_interruption == _canonical(after_interruption),
		"interrupted zero dwell and its next in-volume increment remain exact live saves"
	)

	var live_state := patrol.capture_persistence_state()
	var malformed := live_state.duplicate(true)
	malformed["forged_extra_key"] = true
	var forged_clock := live_state.duplicate(true)
	forged_clock.elapsed_seconds = float(forged_clock.elapsed_seconds) + 0.125
	forged_clock.dwell_elapsed_seconds = (
		float(forged_clock.dwell_elapsed_seconds) + 0.125
	)
	var forged_forward_checkpoint := live_state.duplicate(true)
	forged_forward_checkpoint.next_checkpoint_index = 1
	forged_forward_checkpoint.completed_checkpoint_count = 1
	forged_forward_checkpoint.dwell_checkpoint_index = PatrolActivity.ANY_CHECKPOINT
	forged_forward_checkpoint.dwell_elapsed_seconds = 0.0
	forged_forward_checkpoint.checkpoint_occupied = false
	(forged_forward_checkpoint.activity_state as Dictionary).next_checkpoint_index = 1
	var forged_generation := live_state.duplicate(true)
	forged_generation.generation = int(forged_generation.generation) + 4
	forged_generation.activity_generation = int(forged_generation.activity_generation) + 4
	(forged_generation.activity_state as Dictionary).generation = int(
		forged_generation.activity_generation
	)
	var forged_terminal := live_state.duplicate(true)
	forged_terminal.terminal_reason = "forged_failure"
	var forged_states: Array[Dictionary] = [
		malformed,
		forged_clock,
		forged_forward_checkpoint,
		forged_generation,
		forged_terminal,
	]
	var generation_before_rejection := second_store.get_generation()
	var signals_before_rejection := lifecycle_counts.duplicate(true)
	var rejected: Array[Dictionary] = []
	for case_index in forged_states.size():
		rejected.append(adapter.save_state(
			forged_states[case_index],
			patrol,
			second.get_activity_director(),
			"rejected-cinder-patrol-session-%d" % case_index
		))
	var corrupt_record := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	((corrupt_record.activities as Array)[0] as Dictionary).reward_granted = true
	var corrupt_validation := adapter.validate_record(
		corrupt_record, patrol, second.get_activity_director()
	)
	var wrapper_mismatch := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	((wrapper_mismatch.activities as Array)[0] as Dictionary).generation = (
		int(((wrapper_mismatch.activities as Array)[0] as Dictionary).generation) + 1
	)
	var wrapper_validation := adapter.validate_record(
		wrapper_mismatch, patrol, second.get_activity_director()
	)
	_check(
		not bool(rejected[0].get("accepted", true))
			and rejected[0].get("reason", &"") == &"patrol_session_payload_corrupt"
			and not bool(rejected[1].get("accepted", true))
			and rejected[1].get("reason", &"") == &"patrol_session_not_live_capture"
			and not bool(rejected[2].get("accepted", true))
			and rejected[2].get("reason", &"") == &"patrol_session_not_live_capture"
			and not bool(rejected[3].get("accepted", true))
			and rejected[3].get("reason", &"") == &"patrol_session_not_live_capture"
			and not bool(rejected[4].get("accepted", true))
			and rejected[4].get("reason", &"") == &"patrol_session_payload_corrupt"
			and not bool(corrupt_validation.get("accepted", true))
			and corrupt_validation.get("reason", &"") == &"patrol_session_payload_corrupt"
			and not bool(wrapper_validation.get("accepted", true))
			and wrapper_validation.get("reason", &"") == &"patrol_session_payload_corrupt",
		"malformed, forged, forward, generation, terminal, and record corruption are fenced"
	)
	_check(
		second_store.get_generation() == generation_before_rejection
			and lifecycle_counts == signals_before_rejection,
		"every rejected persistence ingress writes no bytes and emits no lifecycle signal"
	)

	var valid_record := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	await _check_startup_record_dwell_fences(filesystem, valid_record)
	await _retire_game(second)
	var corrupt_store := Store.new(CORRUPT_STORE_PATH, filesystem) as UserDataStore
	corrupt_store.load()
	var startup_corruption := valid_record.duplicate(true)
	var startup_activity := (startup_corruption.activities as Array)[0] as Dictionary
	(startup_activity.progress as Dictionary).patrol_state = {"forged": true}
	corrupt_store.commit(
		{String(SLOT): startup_corruption, "foreign": {"pilot_callsign": "MUDDS"}},
		corrupt_store.get_generation(),
		"seed-valid-envelope-corrupt-patrol-record"
	)
	var corrupt_slot_before := (
		corrupt_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	var corrupt_game := await _make_game(corrupt_store)
	if corrupt_game != null:
		var corrupt_report := corrupt_game.get_cinder_patrol_session_persistence_report()
		var corrupt_integration := corrupt_game.get_activity_integration_report()
		_check(
			not bool((corrupt_report.get("restore_status", {}) as Dictionary)
				.get("accepted", true))
				and (corrupt_report.get("restore_status", {}) as Dictionary)
					.get("reason", &"") == &"patrol_session_payload_corrupt"
				and corrupt_integration.get("selected_activity_kind", &"")
					== GameFlow.ACTIVITY_KIND_TIMED_RACE
				and int((corrupt_integration.get("patrol_activity") as PatrolActivity)
					.get_generation()) == 0
				and corrupt_store.get_snapshot().get(String(SLOT), {})
					== corrupt_slot_before,
			"startup corruption neither adopts patrol authority nor rewrites its slot"
		)
		await _retire_game(corrupt_game)

	_check(
		second_store.get_generation() > stored_generation,
		"normal resume and exact saves advance only UserDataStore's commit generation"
	)
	await _test_terminal_patrol_reward_restart()
	await _test_terminal_save_failure_and_legacy()
	await _test_genuine_write_recovery()
	await _test_reset_branch_choice_recovery()
	for race_boundary in [&"paid", &"reset", &"legacy"]:
		await _test_mixed_race_patrol_restart(race_boundary)
	_finish()


func _check_startup_record_dwell_fences(
	filesystem: MemoryFilesystem,
	valid_record: Dictionary
	) -> void:
	var unoccupied_positive := valid_record.duplicate(true)
	var unoccupied_state := _record_patrol_state(unoccupied_positive)
	unoccupied_state.checkpoint_occupied = false

	var dwell_above_elapsed := valid_record.duplicate(true)
	var above_elapsed_state := _record_patrol_state(dwell_above_elapsed)
	above_elapsed_state.elapsed_seconds = (
		float(above_elapsed_state.dwell_elapsed_seconds) * 0.5
	)

	var dwell_at_threshold := valid_record.duplicate(true)
	var threshold_state := _record_patrol_state(dwell_at_threshold)
	threshold_state.dwell_elapsed_seconds = float(
		threshold_state.configured_dwell_seconds
	)
	threshold_state.elapsed_seconds = maxf(
		float(threshold_state.elapsed_seconds),
		float(threshold_state.dwell_elapsed_seconds)
	)

	var zero_configured_dwell := valid_record.duplicate(true)
	var zero_configured_state := _record_patrol_state(zero_configured_dwell)
	zero_configured_state.configured_dwell_seconds = 0.0
	zero_configured_state.dwell_elapsed_seconds = 0.0
	zero_configured_state.checkpoint_occupied = true

	var nonfinite_dwell := valid_record.duplicate(true)
	_record_patrol_state(nonfinite_dwell).dwell_elapsed_seconds = NAN
	var nonfinite_elapsed := valid_record.duplicate(true)
	_record_patrol_state(nonfinite_elapsed).elapsed_seconds = INF

	var cases: Array[Dictionary] = [
		{
			"label": "unoccupied positive dwell",
			"record": unoccupied_positive,
			"configured_dwell_seconds": 2.0,
			"storable": true,
		},
		{
			"label": "dwell beyond total elapsed",
			"record": dwell_above_elapsed,
			"configured_dwell_seconds": 2.0,
			"storable": true,
		},
		{
			"label": "completion-threshold dwell",
			"record": dwell_at_threshold,
			"configured_dwell_seconds": 2.0,
			"storable": true,
		},
		{
			"label": "zero-configured active dwell",
			"record": zero_configured_dwell,
			"configured_dwell_seconds": 0.0,
			"storable": true,
		},
		{
			"label": "non-finite dwell",
			"record": nonfinite_dwell,
			"configured_dwell_seconds": 2.0,
			"storable": false,
		},
		{
			"label": "non-finite total elapsed",
			"record": nonfinite_elapsed,
			"configured_dwell_seconds": 2.0,
			"storable": false,
		},
	]
	for case_index in cases.size():
		var test_case := cases[case_index]
		var path := "memory://corrupt-patrol-dwell-%d.json" % case_index
		var store := Store.new(path, filesystem) as UserDataStore
		store.load()
		var record := test_case.record as Dictionary
		var seeded := store.commit(
			{String(SLOT): record, "foreign": {"pilot_callsign": "MUDDS"}},
			store.get_generation(),
			"seed-corrupt-patrol-dwell-%d" % case_index
		)
		var storable := bool(test_case.storable)
		_check(
			bool(seeded.get("accepted", false)) == storable,
			"%s reaches only its intended startup boundary" % str(test_case.label)
		)

		var director := ActivityDirector.new()
		director.name = "CorruptPatrolDirector%d" % case_index
		director.register_definition(ROUTE)
		root.add_child(director)
		var candidate_patrol := PatrolActivity.new(
			ROUTE, float(test_case.configured_dwell_seconds)
		)
		var signal_counts := {"patrol": 0, "director": 0}
		_connect_rejection_signal_counts(candidate_patrol, director, signal_counts)
		var patrol_before := candidate_patrol.get_presentation_snapshot()
		var director_before := director.get_activity_snapshot(ROUTE.activity_id)
		var generation_before := store.get_generation()
		var payload_before := store.get_snapshot()
		var startup_adapter := SessionPersistence.new() as CinderPatrolSessionPersistence
		startup_adapter.configure(store, SLOT)
		var rejected := (
			startup_adapter.load(candidate_patrol, director)
			if storable
			else startup_adapter.validate_record(record, candidate_patrol, director)
		)
		if bool(rejected.get("accepted", false)):
			candidate_patrol.restore_persistence_state(
				director,
				rejected.get("patrol_state", {}),
				candidate_patrol.get_generation()
			)
		_check(
			not bool(rejected.get("accepted", true))
				and rejected.get("reason", &"") == &"patrol_session_payload_corrupt"
				and store.get_generation() == generation_before
				and store.get_snapshot() == payload_before
				and signal_counts == {"patrol": 0, "director": 0}
				and candidate_patrol.get_presentation_snapshot() == patrol_before
				and director.get_activity_snapshot(ROUTE.activity_id) == director_before,
			"%s is rejected without write, signal, or state adoption" % str(
				test_case.label
			)
		)
		director.queue_free()
		await process_frame


func _connect_rejection_signal_counts(
	patrol: PatrolActivity,
	director: ActivityDirector,
	counts: Dictionary
	) -> void:
	patrol.patrol_started.connect(
		func(_snapshot: Dictionary) -> void: counts.patrol = int(counts.patrol) + 1
	)
	patrol.checkpoint_arrived.connect(
		func(_snapshot: Dictionary, _checkpoint: int) -> void:
			counts.patrol = int(counts.patrol) + 1
	)
	patrol.checkpoint_dwell_completed.connect(
		func(_snapshot: Dictionary, _checkpoint: int) -> void:
			counts.patrol = int(counts.patrol) + 1
	)
	patrol.patrol_completed.connect(
		func(_snapshot: Dictionary) -> void: counts.patrol = int(counts.patrol) + 1
	)
	patrol.patrol_failed.connect(
		func(_snapshot: Dictionary) -> void: counts.patrol = int(counts.patrol) + 1
	)
	patrol.patrol_aborted.connect(
		func(_snapshot: Dictionary) -> void: counts.patrol = int(counts.patrol) + 1
	)
	patrol.patrol_reset.connect(
		func(_snapshot: Dictionary) -> void: counts.patrol = int(counts.patrol) + 1
	)
	patrol.presentation_changed.connect(
		func(_snapshot: Dictionary) -> void: counts.patrol = int(counts.patrol) + 1
	)
	director.activity_started.connect(
		func(_activity_id: StringName, _generation: int) -> void:
			counts.director = int(counts.director) + 1
	)
	director.activity_checkpoint_reached.connect(
		func(_activity_id: StringName, _checkpoint: int, _generation: int) -> void:
			counts.director = int(counts.director) + 1
	)
	director.activity_completed.connect(
		func(_activity_id: StringName, _generation: int) -> void:
			counts.director = int(counts.director) + 1
	)
	director.activity_failed.connect(
		func(_activity_id: StringName, _reason: StringName, _generation: int) -> void:
			counts.director = int(counts.director) + 1
	)
	director.activity_reset.connect(
		func(_activity_id: StringName, _generation: int) -> void:
			counts.director = int(counts.director) + 1
	)


func _test_platform_patrol_fallback_refusal() -> void:
	var path := "user://platform_patrol_fallback_source_%d.json" % Time.get_ticks_usec()
	var filesystem := InterruptedPatrolRewardFilesystem.new()
	var store := Store.new(path, filesystem) as UserDataStore
	var game := await _make_game(store)
	if game == null:
		return
	game.set_physics_process(false)
	var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var patrol := game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	var button := game.get_node("HUD").find_child("PlatformSweepPatrolBranchButton", true, false) as Button
	_check(button != null and not button.disabled, "real Main exposes the ordinary Platform Patrol branch choice")
	if button == null or button.disabled:
		await _retire_game(game)
		return
	button.pressed.emit()
	game.active_ship = game.get_flyable_ships()[1]
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var started := game.request_activity_start(PLATFORM_ROUTE.activity_id)
	game.active_ship.global_position = PLATFORM_ROUTE.get_checkpoint_position(0)
	game.call("_physics_process", 0.0)
	game.call("_physics_process", patrol.dwell_seconds)
	var active := FileAccess.get_file_as_bytes(path)
	_check(bool(selected.get("accepted", false)) and bool(started.get("accepted", false))
		and patrol.get_state() == PatrolActivity.State.ACTIVE
		and patrol.get_selected_branch_id() == PatrolActivity.BRANCH_PLATFORM_SWEEP
		and int(_stored_patrol_state(store).get("next_checkpoint_index", -1)) == 1,
		"actual Main earns and saves Platform Patrol ACTIVE progress through its first dwell")
	for checkpoint in range(1, PLATFORM_ROUTE.get_checkpoint_count()):
		game.active_ship.global_position = PLATFORM_ROUTE.get_checkpoint_position(checkpoint)
		game.call("_physics_process", 0.0)
		game.call("_physics_process", patrol.dwell_seconds)
	var unpaid := FileAccess.get_file_as_bytes(path)
	_check(patrol.get_state() == PatrolActivity.State.COMPLETED and filesystem.reward_rejected
		and filesystem.stopped and _patrol_receipts(game) == 0,
		"the same genuine Platform Patrol saves its terminal debt before payment is interrupted")
	filesystem.interrupt_rewards = false
	filesystem.stopped = false
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	var paid := FileAccess.get_file_as_bytes(path)
	_check(_patrol_receipts(game) == 1 and bool(store.get_snapshot().cinder_patrol_session.activities[0].reward_granted),
		"ordinary retained debt retry publishes one real Platform Patrol receipt with its paid acknowledgement")
	await _retire_game(game)
	for kind: String in ["active", "unpaid"]:
		var fallback := active if kind == "active" else unpaid
		var older: Dictionary = JSON.parse_string(fallback.get_string_from_utf8()).payload.cinder_patrol_session.activities[0]
		var newer: Dictionary = JSON.parse_string(paid.get_string_from_utf8()).payload.cinder_patrol_session.activities[0]
		_check(int(older.state) == (PatrolActivity.State.ACTIVE if kind == "active" else PatrolActivity.State.COMPLETED)
			and not older.reward_granted and newer.reward_granted and int(older.generation) == int(newer.generation)
			and str(older.activity_id) == String(PLATFORM_ROUTE.activity_id),
			"fallback retains genuinely authored older Platform %s and newer paid documents" % kind)
		var recovery_path := "user://platform_patrol_fallback_%s_%d.json" % [kind, Time.get_ticks_usec()]
		var writer := FileAccess.open(recovery_path + ".paid-witness", FileAccess.WRITE)
		writer.store_buffer(paid)
		writer.close()
		writer = FileAccess.open(recovery_path, FileAccess.WRITE)
		writer.store_string("corrupt newer paid Platform Patrol primary")
		writer.close()
		writer = FileAccess.open(recovery_path + ".bak", FileAccess.WRITE)
		writer.store_buffer(fallback)
		writer.close()
		var preflight := Store.new(recovery_path) as UserDataStore
		_check(bool(preflight.load().get("accepted", false)) and preflight.get_loaded_source() == &"backup",
			"the actual store selects the genuine Platform fallback and quarantines the corrupt primary")
		var artifacts := _patrol_fallback_artifacts(recovery_path)
		_check(artifacts.get(".recovery") == "corrupt newer paid Platform Patrol primary".to_utf8_buffer(),
			"the actual recovery preserves the original Platform corruption witness")
		for attempt in 2:
			store = Store.new(recovery_path)
			game = await _make_game(store)
			if game == null:
				return
			game.set_physics_process(false)
			patrol = game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
			var before := _canonical(patrol.capture_persistence_state())
			var restore := game.get_cinder_patrol_session_persistence_report().restore_status as Dictionary
			print("PLATFORM_PATROL_FALLBACK_STARTUP ", {"kind": kind, "attempt": attempt, "patrol": before,
				"public_activity": game.get_active_activity_snapshot(), "restore": restore,
				"receipts": _patrol_receipts(game), "source": store.get_loaded_source()})
			_check(patrol.get_state() == PatrolActivity.State.IDLE and patrol.get_generation() == 0
				and int(before.get("next_checkpoint_index", -1)) == 0
				and float(before.get("elapsed_seconds", -1.0)) == 0.0
				and not bool(restore.get("accepted", true)) and _patrol_receipts(game) == 0
				and (game.get("_owed_game_flow_activity_rewards") as Array).is_empty(),
				"fresh Main refuses backup-derived Platform progress and earned debt")
			started = game.request_activity_start(PLATFORM_ROUTE.activity_id)
			var reset := game.reset_active_activity()
			var saved := game.save_cinder_patrol_session()
			game.call("_retry_owed_game_flow_activity_rewards")
			print("PLATFORM_PATROL_FALLBACK_ACTIONS ", {"start": started, "reset": reset, "save": saved,
				"patrol": patrol.capture_persistence_state(), "source": store.get_loaded_source()})
			_check(not bool(started.get("accepted", true)) and not reset
				and _canonical(patrol.capture_persistence_state()) == before and _patrol_receipts(game) == 0
				and store.get_loaded_source() == &"backup" and _patrol_fallback_artifacts(recovery_path) == artifacts,
				"ordinary Platform Start, Reset, save and owed retry preserve untrusted fallback artifacts")
			var authority := game.get("_game_flow_reward_authority") as GameFlowRewardAuthority
			var payment := authority.commit({"activity_id": GameFlowRewardAuthority.PLATFORM_PATROL_ACTIVITY_ID,
				"activity_generation": int(older.generation), "reward_id": GameFlowRewardAuthority.PATROL_REWARD_ID,
				"reward_authority": false, "granted": false})
			print("PLATFORM_PATROL_FALLBACK_PAYMENT ", {"kind": kind, "attempt": attempt, "payment": payment,
				"receipts": _patrol_receipts(game), "source": store.get_loaded_source()})
			_check(not bool(payment.get("accepted", true)) and _patrol_receipts(game) == 0
				and store.get_loaded_source() == &"backup" and _patrol_fallback_artifacts(recovery_path) == artifacts,
				"the production reward authority refuses the exact backup-derived Platform completion request")
			await _retire_game(game)
			_check(_patrol_fallback_artifacts(recovery_path) == artifacts,
				"Platform owner teardown preserves the backup, paid witness and quarantine across recreation")


func _patrol_fallback_artifacts(path: String) -> Dictionary:
	var snapshot := _patrol_disk_snapshot(path)
	snapshot[".paid-witness"] = FileAccess.get_file_as_bytes(path + ".paid-witness")
	return snapshot


func _test_terminal_patrol_reward_restart() -> void:
	var path := "user://patrol_reward_interruption_%d.json" % Time.get_ticks_usec()
	var filesystem := InterruptedPatrolRewardFilesystem.new()
	var first := await _make_game(Store.new(path, filesystem))
	first.set_physics_process(false)
	first.call("_on_settings_save_requested")
	var selected := first.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var craft := first.get_flyable_ships()[1] as HeroShip
	first.active_ship = craft
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var started := first.request_activity_start(ROUTE.activity_id)
	var patrol := first.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	for checkpoint in ROUTE.get_checkpoint_count():
		craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
		first.call("_physics_process", 0.0)
		first.call("_physics_process", patrol.dwell_seconds)
	_check(bool(selected.accepted) and bool(started.accepted)
		and first.get_active_activity_snapshot().get("state_id") == &"completed"
		and filesystem.reward_rejected and filesystem.stopped and _patrol_receipts(first) == 0,
		"a real patrol completes with rejected reward publication and frozen real files")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var saved_patrol := (document.payload.cinder_patrol_session.activities[0] as Dictionary)
	_check(int(saved_patrol.state) == PatrolActivity.State.COMPLETED,
		"the interrupted profile contains its live completed patrol on disk")
	await _retire_game(first)
	var retry_filesystem := InterruptedPatrolRewardFilesystem.new()
	var second_store := Store.new(path, retry_filesystem) as UserDataStore
	var second := await _make_game(second_store)
	_check(second.get_active_activity_snapshot().get("state_id") == &"completed"
		and _patrol_receipts(second) == 0 and retry_filesystem.reward_rejected,
		"fresh Main retries the completed patrol while receipt writes still fail")
	var blocked_start := second.request_activity_start(ROUTE.activity_id)
	_check(not second.reset_active_activity() and not bool(blocked_start.accepted)
		and blocked_start.reason == &"patrol_reward_pending",
		"reset and automatic repeat preserve an unpaid completed patrol")
	retry_filesystem.interrupt_rewards = false
	retry_filesystem.stopped = false
	second.call("_retry_owed_game_flow_activity_rewards")
	var acknowledgement := (second_store.get_snapshot().cinder_patrol_session.activities[0] as Dictionary)
	_check(_patrol_receipts(second) == 1 and acknowledgement.reward_requested and acknowledgement.reward_granted,
		"the existing retry atomically publishes patrol receipt and acknowledgement")
	second.save_cinder_patrol_session()
	_check(bool((second_store.get_snapshot().cinder_patrol_session.activities[0] as Dictionary).reward_granted),
		"ordinary completed patrol saves retain the paid acknowledgement")
	_complete_unrelated_convoy(second)
	_check(_patrol_receipts(second) == 1 and _total_receipts(second) == 2,
		"a completed convoy model becomes the latest receipt after patrol payment")
	await _retire_game(second)
	var staged_filesystem := InterruptedPatrolRewardFilesystem.new()
	staged_filesystem.interrupt_rewards = false
	var third_store := Store.new(path, staged_filesystem) as UserDataStore
	var third := await _make_game(third_store)
	var paid_snapshot := third.get_active_activity_snapshot()
	third.call("_on_patrol_completed", paid_snapshot)
	_check(paid_snapshot.get("state_id") == &"completed" and _patrol_receipts(third) == 1 and _total_receipts(third) == 2,
		"fresh Main and a repeated completion never repay patrol after an unrelated receipt")
	third.set_physics_process(false)
	third.active_ship = third.get_flyable_ships()[1]
	third.set("_piloting", true)
	third.phase = GameFlow.Phase.FREE_FLIGHT
	var repeated := third.request_activity_start(ROUTE.activity_id)
	var fresh_marker := (third_store.get_snapshot().cinder_patrol_session.activities[0] as Dictionary)
	_check(bool(repeated.accepted) and not fresh_marker.reward_requested and not fresh_marker.reward_granted,
		"automatic repeat starts a fresh patrol without the old acknowledgement")
	staged_filesystem.stage_reward_before_refusal = true
	var third_patrol := third.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	for checkpoint in ROUTE.get_checkpoint_count():
		third.active_ship.global_position = ROUTE.get_checkpoint_position(checkpoint)
		third.call("_physics_process", 0.0)
		staged_filesystem.interrupt_rewards = checkpoint == ROUTE.get_checkpoint_count() - 1
		third.call("_physics_process", third_patrol.dwell_seconds)
	_check(_patrol_receipts(third) == 1 and FileAccess.file_exists(path + ".tmp"),
		"interrupted patrol publication stages its real receipt and acknowledgement together")
	staged_filesystem.interrupt_rewards = false
	staged_filesystem.stopped = false
	third.call("_on_settings_save_requested")
	third.call("_retry_owed_game_flow_activity_rewards")
	var stale := third.call("_commit_game_flow_activity_reward", {
		"activity_id": &"cinder_relay_patrol", "activity_generation": int(paid_snapshot.generation),
		"reward_id": &"return_patrol_log_to_shipyard", "reward_authority": false, "granted": false,
	}) as Dictionary
	_check(_patrol_receipts(third) == 2 and _total_receipts(third) == 3
		and not bool(stale.accepted) and stale.reason == &"reward_generation_mismatch",
		"staged patrol recovery grants once and rejects the old completion generation")
	_check(third.reset_active_activity(),
		"recovering a staged paid patrol receipt resolves its owed retry and permits reset")
	await _retire_game(third)


func _test_terminal_save_failure_and_legacy() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := Store.new("memory://patrol-terminal-save-failure.json", filesystem) as UserDataStore
	var game := await _make_game(store)
	game.set_physics_process(false)
	var selected := game.select_patrol_branch(PatrolActivity.BRANCH_PLATFORM_SWEEP)
	var route := preload("res://assets/activities/cinder_reach_platform_patrol_route.tres")
	game.active_ship = game.get_flyable_ships()[1]
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var started := game.request_activity_start(route.activity_id)
	var patrol := game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	for checkpoint in route.get_checkpoint_count():
		game.active_ship.global_position = route.get_checkpoint_position(checkpoint)
		game.call("_physics_process", 0.0)
		# Keep the penultimate progress and final dwell-entry proof durable.
		filesystem.reject_writes = checkpoint == route.get_checkpoint_count() - 1
		game.call("_physics_process", patrol.dwell_seconds)
	_check(bool(selected.accepted) and bool(started.accepted)
		and game.get_active_activity_snapshot().get("state_id") == &"completed"
		and _patrol_receipts(game) == 0
		and game.get_activity_reward_report().get("last_result", {}).get("reason") == &"reward_terminal_save_rejected",
		"failed final terminal save leaves the live platform patrol unpaid and retryable")
	filesystem.reject_writes = false
	game.call("_retry_owed_game_flow_activity_rewards")
	var wrong_branch := game.call("_commit_game_flow_activity_reward", {
		"activity_id": &"cinder_relay_patrol", "activity_generation": patrol.get_generation(),
		"reward_id": &"return_patrol_log_to_shipyard", "reward_authority": false, "granted": false,
	}) as Dictionary
	_check(_patrol_receipts(game) == 1 and not bool(wrong_branch.accepted)
		and wrong_branch.reason == &"reward_terminal_handoff_invalid",
		"the proven terminal retry pays platform once and rejects the relay reward binding")
	# Explicit historical wire compatibility: derive the full record from the
	# actual completed model, then represent its pre-marker false/false flags.
	var legacy_payload := store.get_snapshot()
	legacy_payload.cinder_patrol_session.activities[0].reward_requested = false
	legacy_payload.cinder_patrol_session.activities[0].reward_granted = false
	var legacy_saved := store.commit(legacy_payload, store.get_generation(), "legacy-patrol-wire-fixture")
	game.save_cinder_patrol_session()
	_check(bool(legacy_saved.accepted)
		and not bool(store.get_snapshot().cinder_patrol_session.activities[0].reward_requested),
		"same-generation saves preserve explicitly ambiguous legacy patrol flags")
	await _retire_game(game)
	var fresh := await _make_game(Store.new("memory://patrol-terminal-save-failure.json", filesystem))
	fresh.call("_on_patrol_completed", fresh.get_active_activity_snapshot())
	_check(_patrol_receipts(fresh) == 1
		and fresh.get_active_activity_snapshot().get("state_id") == &"completed"
		and not fresh.call("_has_pending_cinder_patrol_reward"),
		"legacy false/false patrol restores without inferred debt or newly minted credit")
	await _retire_game(fresh)


func _prepare_physical_patrol(game: GameFlow) -> PatrolActivity:
	game.set_physics_process(false)
	game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	game.active_ship = game.get_flyable_ships()[1]
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	return game.get_activity_integration_report().get("patrol_activity") as PatrolActivity


func _fly_patrol_checkpoint(game: GameFlow, checkpoint: int) -> void:
	var patrol := game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	game.active_ship.global_position = ROUTE.get_checkpoint_position(checkpoint)
	game.call("_physics_process", 0.0)
	game.call("_physics_process", patrol.dwell_seconds)


func _patrol_disk_snapshot(path: String) -> Dictionary:
	var snapshot := {}
	for suffix in ["", ".tmp", ".bak", ".recovery", ".bak.1", ".bak.2", ".bak.3"]:
		var file_path: String = path + suffix
		snapshot[suffix] = FileAccess.get_file_as_bytes(file_path) if FileAccess.file_exists(file_path) else null
	return snapshot


func _test_genuine_write_recovery() -> void:
	var path := "user://patrol_genuine_write_recovery_%d.json" % Time.get_ticks_usec()
	var filesystem := RejectingPatrolFilesystem.new()
	var store := Store.new(path, filesystem) as UserDataStore
	store.load()
	store.commit({"foreign_patrol_recovery": {"callsign": "MUDDS", "value": 17}}, store.get_generation(), "seed-real-patrol-foreign-data")
	var game := await _make_game(store)
	var patrol := _prepare_physical_patrol(game)
	_check(bool(game.request_activity_start(ROUTE.activity_id).accepted), "physical paid baseline starts")
	for checkpoint in ROUTE.get_checkpoint_count():
		_fly_patrol_checkpoint(game, checkpoint)
	_check(_patrol_receipts(game) == 1 and game.reset_active_activity(), "paid patrol accepts its durable IDLE reset")
	var durable := _patrol_disk_snapshot(path)
	filesystem.reject_writes = true
	_check(bool(game.request_activity_start(ROUTE.activity_id).accepted), "ordinary next patrol starts while ALL writes fail")
	for checkpoint in ROUTE.get_checkpoint_count():
		_fly_patrol_checkpoint(game, checkpoint)
	_check(game.get_active_activity_snapshot().state_id == &"completed" and _patrol_receipts(game) == 1
		and filesystem.rejected_writes > 0 and _patrol_disk_snapshot(path) == durable,
		"physical next completion keeps durable paid-reset boundary during complete write outage")
	filesystem.reject_writes = false
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(_patrol_receipts(game) == 2 and _stored_patrol_state(store).state == PatrolActivity.State.COMPLETED
		and _canonical(store.get_snapshot().get("foreign_patrol_recovery", {}) as Dictionary) == _canonical({"callsign": "MUDDS", "value": 17}),
		"ordinary owed retry bridges unsaved start and checkpoint writes and pays exactly once")
	await _retire_game(game)
	path = "user://patrol_active_write_recovery_%d.json" % Time.get_ticks_usec()
	filesystem = RejectingPatrolFilesystem.new()
	store = Store.new(path, filesystem) as UserDataStore
	game = await _make_game(store)
	patrol = _prepare_physical_patrol(game)
	# An accepted early ACTIVE save must also bridge multiple lost checkpoint writes.
	_check(bool(game.request_activity_start(ROUTE.activity_id).accepted), "early ACTIVE recovery run starts")
	_fly_patrol_checkpoint(game, 0)
	_check(bool(game.save_cinder_patrol_session().accepted), "early ACTIVE capture is accepted")
	filesystem.reject_writes = true
	for checkpoint in range(1, ROUTE.get_checkpoint_count() - 1):
		_fly_patrol_checkpoint(game, checkpoint)
	filesystem.reject_writes = false
	_check(bool(game.save_cinder_patrol_session().accepted), "ordinary ACTIVE save bridges multiple rejected progress writes")
	var active := _canonical(patrol.capture_persistence_state())
	await _retire_game(game)
	game = await _make_game(Store.new(path, filesystem))
	patrol = _prepare_physical_patrol(game)
	_check(_canonical(patrol.capture_persistence_state()) == active, "fresh Main restores exact recovered ACTIVE route and clock")
	filesystem.reject_writes = true
	_fly_patrol_checkpoint(game, ROUTE.get_checkpoint_count() - 1)
	_check(_patrol_receipts(game) == 0 and patrol.get_state() == PatrolActivity.State.COMPLETED, "recovered ACTIVE run physically completes while terminal writes fail")
	filesystem.reject_writes = false
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(_patrol_receipts(game) == 1, "recovered ACTIVE patrol ordinary terminal retry pays once")
	await _retire_game(game)
	# Both genuine failure and an ACTIVE abort/reset must remain transactional.
	for terminal in [&"failure", &"active", &"abort", &"unsaved_failure"]:
		var reset_path := "user://patrol_rejected_reset_%s_%d.json" % [terminal, Time.get_ticks_usec()]
		var reset_filesystem := RejectingPatrolFilesystem.new()
		var reset_store := Store.new(reset_path, reset_filesystem) as UserDataStore
		var reset_game := await _make_game(reset_store)
		var reset_patrol := _prepare_physical_patrol(reset_game)
		var previous_receipts := 0
		if terminal == &"unsaved_failure":
			reset_game.request_activity_start(ROUTE.activity_id)
			for checkpoint in ROUTE.get_checkpoint_count():
				_fly_patrol_checkpoint(reset_game, checkpoint)
			_check(_patrol_receipts(reset_game) == 1 and reset_game.reset_active_activity(), "unsaved-failure fixture retains a paid IDLE boundary")
			previous_receipts = 1
			reset_filesystem.reject_writes = true
		reset_game.request_activity_start(ROUTE.activity_id)
		_fly_patrol_checkpoint(reset_game, 0)
		if terminal in [&"failure", &"unsaved_failure"]:
			reset_game.fail_active_activity(&"genuine_patrol_failure")
		elif terminal == &"abort":
			reset_patrol.abort(&"genuine_patrol_abort", reset_patrol.get_generation())
		var before := _canonical(reset_patrol.capture_persistence_state())
		var route_before := reset_game.activity_director.get_activity_snapshot(ROUTE.activity_id)
		var bytes_before := _patrol_disk_snapshot(reset_path)
		var counts := {"reset": 0, "route_reset": 0}
		reset_patrol.patrol_reset.connect(func(_snapshot: Dictionary) -> void: counts.reset += 1)
		reset_game.activity_director.activity_reset.connect(func(_id: StringName, _generation: int) -> void: counts.route_reset += 1)
		reset_filesystem.reject_writes = true
		_check(not reset_game.reset_active_activity() and _canonical(reset_patrol.capture_persistence_state()) == before
			and reset_game.activity_director.get_activity_snapshot(ROUTE.activity_id) == route_before
			and counts.reset == 0 and counts.route_reset == 0 and _patrol_disk_snapshot(reset_path) == bytes_before,
			"rejected %s reset preserves both owners, events and actual disk" % terminal)
		reset_filesystem.reject_writes = false
		_check(reset_game.reset_active_activity() and counts.reset == 1 and counts.route_reset == 1,
			"recovered %s reset publishes once after accepting its transaction" % terminal)
		var reset_state := _canonical(reset_patrol.capture_persistence_state())
		await _retire_game(reset_game)
		reset_game = await _make_game(Store.new(reset_path, reset_filesystem))
		reset_patrol = _prepare_physical_patrol(reset_game)
		_check(_canonical(reset_patrol.capture_persistence_state()) == reset_state,
			"fresh Main restores the accepted %s IDLE reset" % terminal)
		reset_game.request_activity_start(ROUTE.activity_id)
		for checkpoint in ROUTE.get_checkpoint_count():
			_fly_patrol_checkpoint(reset_game, checkpoint)
		_check(_patrol_receipts(reset_game) == previous_receipts + 1, "next physical patrol after %s reset pays once" % terminal)
		await _retire_game(reset_game)


func _test_reset_branch_choice_recovery() -> void:
	var path := "user://patrol_reset_branch_choice_%d.json" % Time.get_ticks_usec()
	var filesystem := RejectingPatrolFilesystem.new()
	var store := Store.new(path, filesystem) as UserDataStore
	var game := await _make_game(store)
	var patrol := _prepare_physical_patrol(game)
	game.request_activity_start(ROUTE.activity_id)
	for checkpoint in ROUTE.get_checkpoint_count():
		_fly_patrol_checkpoint(game, checkpoint)
	_check(_patrol_receipts(game) == 1 and game.reset_active_activity(),
		"a genuine paid relay patrol saves its explicit IDLE reset before another branch choice")
	await _retire_game(game)
	store = Store.new(path, filesystem)
	game = await _make_game(store)
	game.set_physics_process(false)
	patrol = game.get_activity_integration_report().patrol_activity as PatrolActivity
	var hud := game.get_node("HUD") as GameHUD
	var button := hud.find_child("PlatformSweepPatrolBranchButton", true, false) as Button
	_check(game.get_active_activity_snapshot().state_id == &"idle" and not button.disabled,
		"fresh Main's saved IDLE patrol exposes the ordinary alternate branch button")
	var before := _canonical(patrol.capture_persistence_state())
	var disk_before := _patrol_disk_snapshot(path)
	var callback_count := {"saves": 0}
	for choice in [
		{"branch": &"", "generation": patrol.get_generation(), "reason": &"unsupported_patrol_branch"},
		{"branch": &"unknown", "generation": patrol.get_generation(), "reason": &"unsupported_patrol_branch"},
		{"branch": PatrolActivity.BRANCH_RELAY_SWEEP, "generation": patrol.get_generation(), "reason": &"already_selected"},
		{"branch": PatrolActivity.BRANCH_PLATFORM_SWEEP, "generation": patrol.get_generation() - 1, "reason": &"stale_generation"},
	]:
		var refused := patrol.select_branch_with_persistence(choice.branch, choice.generation,
			func(_candidate: PatrolActivity, _director: ActivityDirector) -> Dictionary:
				callback_count.saves += 1
				return {"accepted": false}
		)
		_check(refused.reason == choice.reason and callback_count.saves == 0
			and _canonical(patrol.capture_persistence_state()) == before
			and _patrol_disk_snapshot(path) == disk_before and _patrol_receipts(game) == 1,
			"%s branch choice invokes no save and preserves the genuine reset, disk and reward" % choice.reason)
	var route := preload("res://assets/activities/cinder_reach_platform_patrol_route.tres")
	var target_before := game.activity_director.get_activity_snapshot(route.activity_id)
	var changes := {"published": 0}
	patrol.presentation_changed.connect(func(_snapshot: Dictionary) -> void: changes.published += 1)
	filesystem.reject_writes = true
	button.pressed.emit()
	_check(_canonical(patrol.capture_persistence_state()) == before
		and _patrol_disk_snapshot(path) == disk_before and filesystem.rejected_writes > 0
		and game.activity_director.get_activity_snapshot(route.activity_id) == target_before
		and changes.published == 0
		and _patrol_receipts(game) == 1,
		"rejected ordinary branch-choice save preserves the prior owner, saved reset and paid receipt")
	filesystem.reject_writes = false
	button.pressed.emit()
	var chosen := patrol.get_selected_branch_id() == PatrolActivity.BRANCH_PLATFORM_SWEEP
	_check(chosen and bool(game.get_cinder_patrol_session_persistence_report().last_save_status.accepted)
		and patrol.get_generation() == int(before.generation) and changes.published == 1
		and int(game.get_activity_integration_report().attached_route_owner_count) == 1
		and _patrol_receipts(game) == 1,
		"ordinary alternate branch retry saves the genuine IDLE generation without repaying it")
	await _retire_game(game)
	if not chosen:
		return
	game = await _make_game(Store.new(path, filesystem))
	game.set_physics_process(false)
	patrol = game.get_activity_integration_report().patrol_activity as PatrolActivity
	_check(patrol.get_selected_branch_id() == PatrolActivity.BRANCH_PLATFORM_SWEEP
		and game.get_active_activity_snapshot().state_id == &"idle" and _patrol_receipts(game) == 1,
		"fresh Main restores the accepted alternate patrol branch and the earlier genuine credit")
	game.active_ship = game.get_flyable_ships()[1]
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	_check(bool(game.request_activity_start(route.activity_id).accepted),
		"the recovered alternate branch starts through the ordinary production action")
	for checkpoint in route.get_checkpoint_count():
		game.active_ship.global_position = route.get_checkpoint_position(checkpoint)
		game.call("_physics_process", 0.0)
		filesystem.reject_writes = checkpoint == route.get_checkpoint_count() - 1
		game.call("_physics_process", patrol.dwell_seconds)
	_check(patrol.get_state() == PatrolActivity.State.COMPLETED and _patrol_receipts(game) == 1,
		"the next legitimate alternate patrol retains unpaid completion through rejected terminal writes")
	filesystem.reject_writes = false
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(_patrol_receipts(game) == 2, "alternate patrol terminal retry pays its new genuine generation once")
	await _retire_game(game)
	game = await _make_game(Store.new(path, filesystem))
	_check(game.get_active_activity_snapshot().state_id == &"completed" and _patrol_receipts(game) == 2,
		"fresh Main retains both paid patrol generations without a duplicate receipt")
	_check(game.reset_active_activity(), "the alternate patrol accepts its explicit paid reset")
	hud = game.get_node("HUD") as GameHUD
	button = hud.find_child("RelaySweepPatrolBranchButton", true, false) as Button
	button.pressed.emit()
	_check(game.patrol_activity.get_selected_branch_id() == PatrolActivity.BRANCH_RELAY_SWEEP
		and game.patrol_activity.get_generation() == int(before.generation) + 2 and _patrol_receipts(game) == 2,
		"ordinary branch choice can return to the old route at the later genuine reset generation")
	await _retire_game(game)
	game = await _make_game(Store.new(path, filesystem))
	_check(game.patrol_activity.get_selected_branch_id() == PatrolActivity.BRANCH_RELAY_SWEEP
		and game.get_active_activity_snapshot().state_id == &"idle" and _patrol_receipts(game) == 2,
		"fresh Main preserves the repeat branch choice without manufacturing entitlement")
	await _retire_game(game)


func _test_mixed_race_patrol_restart(race_boundary: StringName) -> void:
	var path := "user://mixed_patrol_reward_%s_%d.json" % [race_boundary, Time.get_ticks_usec()]
	var filesystem := InterruptedPatrolRewardFilesystem.new()
	filesystem.interrupt_rewards = false
	var store := Store.new(path, filesystem) as UserDataStore
	var first := await _make_game(store)
	first.set_physics_process(false)
	first.call("_on_settings_save_requested")
	# Earlier race boundary is a real completed typed session, codec and authority
	# on this same disk store; the subsequent patrol uses live Main and craft.
	var director := ActivityDirector.new()
	root.add_child(director)
	director.register_definition(ROUTE)
	var race := CinderTimedRaceSession.new(
		GameFlow.CINDER_RACE_LAPS, GameFlow.CINDER_RACE_COUNTDOWN_SECONDS,
		GameFlow.CINDER_RACE_TIMEOUT_SECONDS
	)
	race.attach(director, 0)
	race.start(0)
	race.advance_physics(2.0, race.get_session_generation())
	race.advance_physics(1.0, race.get_session_generation())
	race.advance_physics(0.25, race.get_session_generation())
	for checkpoint in ROUTE.get_checkpoint_count():
		race.submit_position(ROUTE.get_checkpoint_position(checkpoint), race.get_session_generation())
	var race_persistence := CinderRaceSessionPersistence.new()
	race_persistence.configure(store, &"cinder_timed_race_session")
	var race_saved := race_persistence.save(race, director, "mixed-terminal-race")
	var paid := first.call("_commit_game_flow_activity_reward", {
		"activity_id": ROUTE.activity_id, "activity_generation": race.get_session_generation(),
		"reward_id": &"return_race_record_to_shipyard", "reward_authority": false, "granted": false,
	}) as Dictionary
	if race_boundary == &"reset":
		race.reset(race.get_session_generation())
		race_saved = race_persistence.save(race, director, "mixed-reset-paid-race")
	elif race_boundary == &"legacy":
		# Labelled historical wire fixture, preserving the real terminal capture.
		var legacy_payload := store.get_snapshot()
		legacy_payload.cinder_timed_race_session.activities[0].reward_requested = false
		legacy_payload.cinder_timed_race_session.activities[0].reward_granted = false
		race_saved = store.commit(legacy_payload, store.get_generation(), "mixed-legacy-race-wire-fixture")
	var compatible_race := race_persistence.load(first.cinder_race_session, first.get_activity_director())
	_check(bool(compatible_race.get("accepted", false)),
		"mixed %s race record is admitted by Main's exact configured session" % race_boundary)
	var old_race_record: Dictionary = store.get_snapshot().cinder_timed_race_session.duplicate(true)
	_check(bool(race_saved.accepted) and bool(paid.accepted),
		"mixed %s profile retains a real earlier race boundary" % race_boundary)
	race.close(race.get_session_generation())
	director.free()
	var selected := first.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	first.active_ship = first.get_flyable_ships()[1]
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var started := first.request_activity_start(ROUTE.activity_id)
	var patrol := first.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	filesystem.interrupt_rewards = true
	for checkpoint in ROUTE.get_checkpoint_count():
		first.active_ship.global_position = ROUTE.get_checkpoint_position(checkpoint)
		first.call("_physics_process", 0.0)
		first.call("_physics_process", patrol.dwell_seconds)
	_check(bool(selected.accepted) and bool(started.accepted) and filesystem.stopped
		and filesystem.reward_rejected and _patrol_receipts(first) == 0,
		"mixed %s profile freezes a genuine completed unpaid Main patrol" % race_boundary)
	await _retire_game(first)
	var retry_filesystem := InterruptedPatrolRewardFilesystem.new()
	var fresh_store := Store.new(path, retry_filesystem) as UserDataStore
	var fresh := await _make_game(fresh_store)
	var report := fresh.get_activity_integration_report()
	_check(fresh.get_cinder_race_session_persistence_report().get("restore_status", {}).get("reason")
		== &"pending_patrol_session_has_priority",
		"mixed %s startup explicitly prioritizes pending patrol over its valid race" % race_boundary)
	_check(report.selected_activity_kind == GameFlow.ACTIVITY_KIND_PATROL
		and int(report.attached_route_owner_count) == 1
		and fresh.get_active_activity_snapshot().get("state_id") == &"completed"
		and _patrol_receipts(fresh) == 0 and retry_filesystem.reward_rejected
		and not fresh.reset_active_activity(),
		"mixed %s fresh Main adopts one pending patrol owner and preserves failed retry" % race_boundary)
	retry_filesystem.interrupt_rewards = false
	retry_filesystem.stopped = false
	fresh.call("_retry_owed_game_flow_activity_rewards")
	_check(_patrol_receipts(fresh) == 1 and _total_receipts(fresh) == 2
		and fresh_store.get_snapshot().cinder_timed_race_session == old_race_record,
		"mixed %s recovery acknowledges only patrol and retains the earlier race record" % race_boundary)
	fresh.set_physics_process(false)
	fresh.active_ship = fresh.get_flyable_ships()[1]
	fresh.set("_piloting", true)
	fresh.phase = GameFlow.Phase.FREE_FLIGHT
	var paid_patrol_snapshot := fresh.get_active_activity_snapshot()
	var retired_patrol := fresh.patrol_activity
	var retired_completion: Callable = retired_patrol.patrol_completed.get_connections()[0].callable
	var patrol_reset := fresh.reset_active_activity()
	var retired_route := fresh.get_activity_director().get("_activities").get(ROUTE.activity_id) as CheckpointRouteActivity
	var retired_source_id := retired_route.get_instance_id()
	var hud := fresh.get_node("HUD") as GameHUD
	var choices := hud.get_activity_selection_report()
	_check(not bool(choices.buttons[GameFlow.ACTIVITY_KIND_TIMED_RACE].disabled)
		and not bool(choices.buttons[GameFlow.ACTIVITY_KIND_CARGO_DELIVERY].disabled)
		and not bool(choices.buttons[GameFlow.ACTIVITY_KIND_CONVOY_ESCORT].disabled),
		"the production HUD enables all four choices after an explicit family reset")
	var race_button := hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_TIMED_RACE) as Button
	race_button.pressed.emit()
	var switched := {"accepted": fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_TIMED_RACE}
	_check(patrol_reset and bool(switched.accepted)
		and fresh.cinder_race_session.get_session_generation() == int(old_race_record.activities[0].generation)
		and int(fresh.get_activity_integration_report().attached_route_owner_count) == 1,
		"mixed %s reset activates the exact saved race generation with one owner" % race_boundary)
	if race_boundary != &"reset":
		var cargo_locked := fresh.select_activity_kind(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY)
		_check(not bool(cargo_locked.accepted) and cargo_locked.reason == &"selection_locked",
			"adopting a terminal target keeps choices locked until its own explicit reset")
	if race_boundary != &"reset":
		if race_boundary == &"legacy":
			fresh.call("_on_cinder_session_completed", fresh.get_active_activity_snapshot())
			_check(_total_receipts(fresh) == 2,
				"adopting a legacy race result confers no inferred reward entitlement")
		_check(fresh.reset_active_activity(), "the adopted terminal race uses its ordinary reset before starting")
	var race_started := fresh.request_activity_start(ROUTE.activity_id)
	fresh.call("_physics_process", GameFlow.CINDER_RACE_COUNTDOWN_SECONDS)
	var new_generation := fresh.cinder_race_session.get_session_generation()
	var forwarded_checkpoints := {"count": 0}
	fresh.get_activity_director().activity_checkpoint_reached.connect(
		func(_id: StringName, _checkpoint: int, _generation: int) -> void:
			forwarded_checkpoints.count = int(forwarded_checkpoints.count) + 1
	)
	var last_result: Dictionary = fresh.get_activity_reward_report().last_result
	var old_start := retired_route.start()
	var old_step := retired_route.submit_position(ROUTE.get_checkpoint_position(0), old_start)
	retired_completion.call_deferred(paid_patrol_snapshot)
	await process_frame
	var stale_retirement := fresh.get_activity_director().retire_inactive_activity(
		ROUTE.activity_id, new_generation, retired_source_id
	)
	var active_retirement := fresh.get_activity_director().retire_inactive_activity(
		ROUTE.activity_id, new_generation,
		fresh.get_activity_director().get_activity_instance_id(ROUTE.activity_id)
	)
	_check(bool(race_started.accepted) and old_start == new_generation and bool(old_step.accepted)
		and int(forwarded_checkpoints.count) == 0
		and int(fresh.get_active_activity_snapshot().next_checkpoint_index) == 0
		and not bool(stale_retirement.accepted) and stale_retirement.reason == &"stale_route_instance"
		and not bool(active_retirement.accepted) and active_retirement.reason == &"route_still_active"
		and fresh.get_activity_reward_report().last_result == last_result
		and not bool(retired_patrol.submit_position(ROUTE.get_checkpoint_position(0), retired_patrol.get_generation()).accepted),
		"retired same-generation route events, callbacks and retirement cannot mutate the adopted race")
	for checkpoint in ROUTE.get_checkpoint_count():
		fresh.active_ship.global_position = ROUTE.get_checkpoint_position(checkpoint)
		fresh.call("_physics_process", 0.25)
	_check(fresh.get_active_activity_snapshot().get("state_id") == &"completed"
		and _total_receipts(fresh) == 3
		and int(fresh.get_activity_reward_report().authority.record.reward_counts.return_race_record_to_shipyard) == 2,
		"mixed %s activated race completes through Main and saves its own new receipt" % race_boundary)
	await _check_adopted_family_reentry(fresh)
	fresh.active_ship = fresh.get_flyable_ships()[1]
	fresh.set("_piloting", true)
	fresh.phase = GameFlow.Phase.FREE_FLIGHT
	var terminal_switch := fresh.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	_check(not bool(terminal_switch.accepted) and terminal_switch.reason == &"selection_locked",
		"a completed family stays locked until the player explicitly resets it")
	var race_reset := fresh.reset_active_activity()
	var switched_back := fresh.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var restored_patrol_generation := fresh.patrol_activity.get_generation()
	var repeated := fresh.request_activity_start(ROUTE.activity_id)
	var fresh_patrol := fresh.patrol_activity
	for checkpoint in ROUTE.get_checkpoint_count():
		fresh.active_ship.global_position = ROUTE.get_checkpoint_position(checkpoint)
		fresh.call("_physics_process", 0.0)
		fresh.call("_physics_process", fresh_patrol.dwell_seconds)
	_check(race_reset and bool(switched_back.accepted) and restored_patrol_generation == int(paid_patrol_snapshot.generation) + 1
		and bool(repeated.accepted) and fresh_patrol.get_generation() > restored_patrol_generation
		and _patrol_receipts(fresh) == 2 and _total_receipts(fresh) == 4
		and int(fresh.get_activity_integration_report().attached_route_owner_count) == 1,
		"mixed %s can switch back to the saved patrol and complete its genuine next generation" % race_boundary)
	await _check_adopted_family_reentry(fresh)
	await _retire_game(fresh)


func _check_adopted_family_reentry(game: GameFlow) -> void:
	var before := game.get_active_activity_snapshot()
	var kind := StringName(game.get_activity_integration_report().selected_activity_kind)
	var owner: RefCounted = game.cinder_race_session if kind == GameFlow.ACTIVITY_KIND_TIMED_RACE else game.patrol_activity
	var director := game.get_activity_director()
	var receipts := _total_receipts(game)
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	var after := game.get_active_activity_snapshot()
	var current_owner: RefCounted = game.cinder_race_session if kind == GameFlow.ACTIVITY_KIND_TIMED_RACE else game.patrol_activity
	_check(current_owner == owner and game.get_activity_director() == director
		and int(after.session_generation) == int(before.session_generation)
		and after.state_id == before.state_id
		and is_equal_approx(float(after.current_time_seconds), float(before.current_time_seconds))
		and int(game.get_activity_integration_report().attached_route_owner_count) == 1
		and _total_receipts(game) == receipts,
		"newly adopted %s keeps its owner, generation, result and receipt through Main re-entry" % kind)


func _complete_unrelated_convoy(game: GameFlow, reject_reward: bool = false) -> void:
	# Bounded typed-host/codec handoff, not a streamed combat journey. The actual
	# movement owner publishes its terminal before the ordinary reward callback.
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	var persistence := CinderConvoySessionPersistence.new()
	persistence.configure(store, &"cinder_convoy_session")
	var convoy := CinderConvoyEscortHost.new()
	root.add_child(convoy)
	var filesystem := store.get("_filesystem") as UserDataFilesystem
	if reject_reward:
		filesystem.set("reject_writes", false)
	convoy.convoy_safely_arrived.connect(func(snapshot: Dictionary) -> void:
		var saved := persistence.save(convoy, &"torrent", "unit-live-convoy-terminal")
		_check(bool(saved.get("accepted", false)), "the genuine convoy terminal is durable before its reward handoff")
		if reject_reward:
			filesystem.set("reject_writes", true)
		game.call("_on_cinder_convoy_safely_arrived", snapshot)
	)
	convoy.start(convoy.get_generation())
	var budget := 60
	while budget > 0 and convoy.get_snapshot().activity.state_id == &"active":
		convoy.advance_physics(0.25, convoy.get_snapshot().entity_position as Vector3, convoy.get_generation())
		if convoy.get_snapshot().activity.state_id == &"active":
			persistence.save(convoy, &"torrent", "unit-live-convoy-progress-%d" % budget)
		budget -= 1
	_check(budget > 0 and convoy.get_snapshot().activity.state_id == &"completed",
		"the unrelated receipt comes from an exact completed convoy host and codec")
	if not reject_reward:
		var retired := persistence.retire(convoy, "unit-convoy-explicit-retirement")
		_check(bool(retired.get("accepted", false)), "the paid model fixture explicitly retires its convoy slot")
	convoy.free()


func _total_receipts(game: GameFlow) -> int:
	return int((game.get_activity_reward_report().get("authority", {}) as Dictionary).get("record", {}).get("total_receipts", 0))


func _patrol_receipts(game: GameFlow) -> int:
	var authority := game.get_activity_reward_report().get("authority", {}) as Dictionary
	var record := authority.get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get("return_patrol_log_to_shipyard", 0))


func _record_patrol_state(record: Dictionary) -> Dictionary:
	return (((record.activities as Array)[0] as Dictionary).progress as Dictionary) \
		.patrol_state as Dictionary


func _stored_patrol_state(store: UserDataStore) -> Dictionary:
	var record := store.get_snapshot().get(String(SLOT), {}) as Dictionary
	var activities := record.get("activities", []) as Array
	if activities.size() != 1 or not activities[0] is Dictionary:
		return {}
	var progress := (activities[0] as Dictionary).get("progress", {}) as Dictionary
	return (progress.get("patrol_state", {}) as Dictionary).duplicate(true)


func _canonical(state: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(JSON.stringify(state))
	return (decoded as Dictionary).duplicate(true) if decoded is Dictionary else {}


func _make_game(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null or not game.configure_runtime_settings_persistence(store):
		_check(false, "the isolated GameFlow accepts its one injected atomic store")
		return null
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	return game


func _retire_game(game: GameFlow) -> void:
	game.set("_piloting", false)
	game.queue_free()
	for _frame in 3:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("CINDER_PATROL_SESSION_SAVE_RESTORE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
