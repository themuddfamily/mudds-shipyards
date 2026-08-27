extends SceneTree

## Focused production round trip for the active GameFlow-owned Emberline
## escort. It uses Main's real host, streaming seam, and one injected atomic
## store while proving startup freeze/rebind and hostile payload rejection.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const SessionPersistence := preload(
	"res://scripts/persistence/cinder_convoy_session_persistence.gd"
)
const NearbyActivitySessionAdapter := preload(
	"res://scripts/persistence/nearby_sector_activity_session_adapter.gd"
)

const STORE_PATH := "memory://cinder-convoy-session.json"
const CORRUPT_STORE_PATH := "memory://corrupt-cinder-convoy-session.json"
const SLOT: StringName = &"cinder_convoy_session"


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}

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


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var first_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	first_store.load()
	first_store.commit(
		{"foreign": {"pilot_callsign": "MUDDS"}},
		first_store.get_generation(),
		"seed-convoy-session-foreign-data"
	)
	var first := await _make_game(first_store)
	if first == null:
		_finish()
		return
	first.set_physics_process(false)
	var selected := first.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var craft := first.get_flyable_ships()[1] as HeroShip
	craft.set_piloted(true)
	first.active_ship = craft
	first.set("_piloting", true)
	first.set("_sortie_departed_berth", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	first.call("_physics_process", 0.1)
	_check(
		await _wait_until(
			func() -> bool:
				return is_instance_valid(
					(first.get("cinder_streaming_bootstrap") as CinderStreamingBootstrap)
						.get_loaded_instance()
				),
			20
		),
		"the production Cinder generation loads before convoy activation"
	)
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	first.call("_physics_process", 0.25)
	var host := first.get("cinder_convoy_host") as CinderConvoyEscortHost
	for _step in 4:
		craft.global_position = (
			host.get_snapshot().entity_position as Vector3
		) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
	var saved := first.save_cinder_convoy_session()
	var before_host := host.capture_persistence_state()
	var before := first.get_active_activity_snapshot()
	var stored_record := (
		first_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	var stored_generation := first_store.get_generation()
	_check(
		bool(selected.get("accepted", false)) and bool(saved.get("accepted", false))
			and before.get("state_id", &"") == &"active"
			and float(before.get("movement_distance", 0.0)) > 0.0
			and float(before.get("current_time_seconds", 0.0)) > 0.0
			and int(before.get("session_generation", 0)) == 1,
		"normal production play saves the exact active movement and activity clocks"
	)
	_check(
		stored_record.get("schema_version", 0)
			== NearbyActivitySessionAdapter.SCHEMA_VERSION
			and ((first_store.get_snapshot().foreign as Dictionary).pilot_callsign
				== "MUDDS")
			and bool(first.get_cinder_convoy_session_persistence_report()
				.get("shares_runtime_settings_store", false))
			and not first_store.get_snapshot().has("cinder_convoy_safe_arrival"),
		"the active record merges into the existing store without arrival history"
	)
	await _retire_game(first)

	var second_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	var second := await _make_game(second_store)
	if second == null:
		_finish()
		return
	second.set_physics_process(false)
	var restored_host := second.get("cinder_convoy_host") as CinderConvoyEscortHost
	var restored := second.get_active_activity_snapshot()
	var restore_report := second.get_cinder_convoy_session_persistence_report()
	_check(
		bool((restore_report.restore_status as Dictionary).get("accepted", false))
			and bool(restore_report.runtime_rebind_pending)
			and restored.get("state_id", &"") == &"active"
			and _canonical(restored_host.capture_persistence_state())
				== _canonical(before_host)
			and second.get_activity_integration_report().selected_activity_kind
				== GameFlow.ACTIVITY_KIND_CONVOY_ESCORT
			and (second.get_cinder_race_session_persistence_report().restore_status
				as Dictionary).get("reason", &"") == &"convoy_session_already_restored"
			and (second.get_cinder_patrol_session_persistence_report().restore_status
				as Dictionary).get("reason", &"") == &"convoy_session_already_restored",
		"fresh startup adopts one exact convoy owner before Race or Patrol"
	)

	var signal_counts := {
		"started": 0,
		"advanced": 0,
		"arrived": 0,
		"failed": 0,
		"reset": 0,
		"presentation": 0,
	}
	_connect_host_signal_counts(restored_host, signal_counts)
	var frozen := restored_host.capture_persistence_state()
	var restored_craft := second.get_flyable_ships()[1] as HeroShip
	restored_craft.set_piloted(true)
	second.active_ship = restored_craft
	second.set("_piloting", true)
	second.set("_sortie_departed_berth", true)
	second.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	second.call("_physics_process", 5.0)
	second.phase = GameFlow.Phase.FREE_FLIGHT
	second.set("_piloting", false)
	second.call("_physics_process", 5.0)
	second.set("_piloting", true)
	second.active_ship = second.get_flyable_ships()[0] as HeroShip
	(second.active_ship as HeroShip).set_piloted(true)
	second.call("_physics_process", 5.0)
	_check(
		restored_host.capture_persistence_state() == frozen
			and signal_counts == {
				"started": 0, "advanced": 0, "arrived": 0,
				"failed": 0, "reset": 0, "presentation": 0,
			},
		"restored progress freezes outside the saved current-ship FREE_FLIGHT context"
	)

	restored_craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	second.active_ship = restored_craft
	for _attempt in 20:
		second.call("_physics_process", 0.25)
		if not bool(second.get_cinder_convoy_session_persistence_report()
				.get("runtime_rebind_pending", true)):
			break
		await process_frame
	var resumed := restored_host.capture_persistence_state()
	_check(
		not bool(second.get_cinder_convoy_session_persistence_report()
			.get("runtime_rebind_pending", true))
			and float(resumed.get("movement_distance", -1.0))
			> float(frozen.get("movement_distance", -1.0))
			and float((resumed.activity_state as Dictionary).elapsed_seconds)
			> float((frozen.activity_state as Dictionary).elapsed_seconds)
			and int(signal_counts.started) == 0
			and int(signal_counts.failed) == 0,
		"the matching current craft and Cinder generation rebind once and resume"
	)

	var adapter := SessionPersistence.new() as CinderConvoySessionPersistence
	adapter.configure(second_store, SLOT)
	second.save_cinder_convoy_session()
	var live_session := _stored_session_state(second_store)
	var exact_live := adapter.save_state(
		live_session,
		restored_host,
		restored_craft.get_ship_id(),
		"exact-live-cinder-convoy-session"
	)
	var generation_before_rejection := second_store.get_generation()
	var signals_before_rejection := signal_counts.duplicate(true)
	var forged_cases: Array[Dictionary] = []
	var forged_route := live_session.duplicate(true)
	(forged_route.host_state as Dictionary).activity_id = "forged_route"
	forged_cases.append(forged_route)
	var forged_progress := live_session.duplicate(true)
	(forged_progress.host_state as Dictionary).movement_distance = (
		float((forged_progress.host_state as Dictionary).movement_distance) + 5.0
	)
	forged_cases.append(forged_progress)
	var stale := live_session.duplicate(true)
	(stale.host_state as Dictionary).physics_tick_count = maxi(
		0, int((stale.host_state as Dictionary).physics_tick_count) - 1
	)
	forged_cases.append(stale)
	var terminal := live_session.duplicate(true)
	var terminal_activity := (
		(terminal.host_state as Dictionary).activity_state as Dictionary
	)
	terminal_activity.state = ConvoyEscortActivity.State.COMPLETED
	terminal_activity.terminal_result = ConvoyEscortActivity.TerminalResult.SAFELY_ARRIVED
	terminal_activity.terminal_reason = "safely_arrived"
	forged_cases.append(terminal)
	var forged_reward := live_session.duplicate(true)
	(forged_reward.host_state as Dictionary).reward_granted = true
	forged_cases.append(forged_reward)
	var rejected: Array[Dictionary] = []
	for case_index in forged_cases.size():
		rejected.append(adapter.save_state(
			forged_cases[case_index],
			restored_host,
			restored_craft.get_ship_id(),
			"rejected-cinder-convoy-session-%d" % case_index
		))
	_check(
		bool(exact_live.get("accepted", false))
			and rejected.all(func(result: Dictionary) -> bool:
				return not bool(result.get("accepted", true)))
			and second_store.get_generation() == generation_before_rejection
			and signal_counts == signals_before_rejection,
		"forged route/progress/stale/terminal/reward states write and signal nothing"
	)

	var budget := 60
	while (restored_host.get_snapshot().activity as Dictionary).state_id == &"active" \
			and budget > 0:
		restored_craft.global_position = (
			restored_host.get_snapshot().entity_position as Vector3
		) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		second.call("_physics_process", 0.25)
		budget -= 1
	var completed := second.get_active_activity_snapshot()
	var duplicate := restored_host.advance_physics(
		0.25,
		restored_host.get_snapshot().entity_position as Vector3,
		restored_host.get_generation()
	)
	_check(
		budget > 0 and completed.get("state_id", &"") == &"completed"
			and int(signal_counts.arrived) == 1
			and not bool(duplicate.get("accepted", true))
			and int(signal_counts.arrived) == 1
			and not second_store.get_snapshot().has(String(SLOT))
			and not second_store.get_snapshot().has("cinder_convoy_safe_arrival"),
		"restored progress arrives once, retires only its live slot, and grants nothing"
	)
	await _retire_game(second)

	var corrupt_store := Store.new(CORRUPT_STORE_PATH, filesystem) as UserDataStore
	corrupt_store.load()
	var corrupt_record := stored_record.duplicate(true)
	var corrupt_activity := (corrupt_record.activities as Array)[0] as Dictionary
	var corrupt_progress := corrupt_activity.progress as Dictionary
	(corrupt_progress.convoy_session_state as Dictionary).phase_id = "arrived"
	corrupt_store.commit(
		{String(SLOT): corrupt_record, "foreign": {"pilot_callsign": "MUDDS"}},
		corrupt_store.get_generation(),
		"seed-corrupt-convoy-session"
	)
	var corrupt_slot_before := (
		corrupt_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	var corrupt_game := await _make_game(corrupt_store)
	if corrupt_game != null:
		corrupt_game.set_physics_process(false)
		var corrupt_host := corrupt_game.get("cinder_convoy_host") as CinderConvoyEscortHost
		var corrupt_report := corrupt_game.get_cinder_convoy_session_persistence_report()
		_check(
			not bool((corrupt_report.restore_status as Dictionary).get("accepted", true))
				and (corrupt_report.restore_status as Dictionary).get("reason", &"")
				== &"convoy_session_payload_corrupt"
				and int((corrupt_host.get_snapshot().activity as Dictionary).generation) == 0
				and (corrupt_host.get_snapshot().activity as Dictionary).state_id == &"idle"
				and corrupt_store.get_snapshot().get(String(SLOT), {})
				== corrupt_slot_before
				and (corrupt_store.get_snapshot().foreign as Dictionary).pilot_callsign
				== "MUDDS",
			"corrupt startup state is neither adopted nor rewritten"
		)
		await _retire_game(corrupt_game)

	_finish()


func _connect_host_signal_counts(
		host: CinderConvoyEscortHost,
		counts: Dictionary
	) -> void:
	host.convoy_started.connect(
		func(_snapshot: Dictionary) -> void: counts.started = int(counts.started) + 1
	)
	host.convoy_advanced.connect(
		func(_snapshot: Dictionary) -> void: counts.advanced = int(counts.advanced) + 1
	)
	host.convoy_safely_arrived.connect(
		func(_snapshot: Dictionary) -> void: counts.arrived = int(counts.arrived) + 1
	)
	host.convoy_failed.connect(
		func(_snapshot: Dictionary) -> void: counts.failed = int(counts.failed) + 1
	)
	host.convoy_reset.connect(
		func(_snapshot: Dictionary) -> void: counts.reset = int(counts.reset) + 1
	)
	host.presentation_changed.connect(
		func(_snapshot: Dictionary) -> void:
			counts.presentation = int(counts.presentation) + 1
	)


func _stored_session_state(store: UserDataStore) -> Dictionary:
	var record := store.get_snapshot().get(String(SLOT), {}) as Dictionary
	var activities := record.get("activities", []) as Array
	if activities.size() != 1 or not activities[0] is Dictionary:
		return {}
	var progress := (activities[0] as Dictionary).get("progress", {}) as Dictionary
	return (
		progress.get("convoy_session_state", {}) as Dictionary
	).duplicate(true)


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


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("CINDER_CONVOY_SESSION_SAVE_RESTORE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
