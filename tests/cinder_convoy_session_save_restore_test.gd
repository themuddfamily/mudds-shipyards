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
const RADIUS_STORE_PATH := "memory://cinder-convoy-radius-session.json"
const CENTERED_STORE_PATH := "memory://cinder-convoy-centered-session.json"
const THREAT_STORE_PATH := "memory://cinder-convoy-threat-session.json"
const LEGACY_THREAT_STORE_PATH := "memory://cinder-convoy-legacy-threat-session.json"
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


## Real disk refusal at the production reward write, with teardown frozen.
class InterruptedConvoyRewardFilesystem extends UserDataFilesystem:
	var stopped := false
	var reward_rejected := false
	var interrupt_rewards := true
	var stage_reward_before_refusal := false
	var reject_terminal_saves := false
	var terminal_rejected := false

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
			stopped = true
			return ERR_UNAVAILABLE
		if reject_terminal_saves and document is Dictionary:
			var activities: Array = ((document.get("payload", {}) as Dictionary).get(String(SLOT), {}) as Dictionary).get("activities", [])
			if activities.size() == 1 and int((activities[0] as Dictionary).get("state", -1)) == ConvoyEscortActivity.State.COMPLETED:
				terminal_rejected = true
				return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if stopped else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		return ERR_UNAVAILABLE if stopped else super.rename_path(from_path, to_path)


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var stage_index := args.find("--in-world-interruption-stage")
	if stage_index >= 0:
		if stage_index + 1 >= args.size() or args[stage_index + 1] not in ["arm", "resume"]:
			push_error("Invalid in-world interruption fixture stage")
			quit(2)
			return
		await _run_os_interruption_stage(args[stage_index + 1])
		return
	var filesystem := MemoryFilesystem.new()
	await _exercise_checkpoint_radius_and_corruption_contract(filesystem)
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
		"exact-live-cinder-convoy-session",
		second.cinder_convoy_threat
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
			"rejected-cinder-convoy-session-%d" % case_index,
			second.cinder_convoy_threat
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
			and bool((second_store.get_snapshot().get(String(SLOT), {}).get("activities", [{}])[0] as Dictionary).get("reward_granted", false))
			and _convoy_receipts(second) == 1
			and not second_store.get_snapshot().has("cinder_convoy_safe_arrival"),
		"restored progress arrives once and atomically acknowledges its retained convoy slot"
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

	await _exercise_threat_save_restore(filesystem)
	var paid_profile := await _test_terminal_convoy_reward_restart()
	await _test_interrupted_convoy_lifecycle(paid_profile)
	await _test_failed_convoy_reset_restart(paid_profile)
	_finish()


## Driven only by the existing release harness's two owned OS processes.
## Setup uses the same production Main/escort/interception fixture as this suite;
## this is not normal-controls, pilot-seat or native-hardware qualification.
func _run_os_interruption_stage(stage: String) -> void:
	var store := Store.new(RuntimeSettingsStoreAdapter.DEFAULT_STORE_PATH) as UserDataStore
	var game := await _make_game(store)
	game.set_physics_process(false)
	if stage == "arm":
		game.call("_on_settings_save_requested")
		var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
		var craft := await _prepare_interrupted_convoy(game, 1)
		var first_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var first_arrival := await _finish_interrupted_convoy(game, craft)
		var reset := game.reset_active_activity()
		craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
		var next_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		for _tick in 4:
			craft.global_position = (game.cinder_convoy_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		var saved := game.save_cinder_convoy_session()
		var boundary := _stored_session_state(store)
		_check(bool(selected.accepted) and bool(first_start.accepted) and first_arrival and reset
			and bool(next_start.accepted) and bool(saved.accepted) and _convoy_receipts(game) == 1
			and game.get_active_activity_snapshot().state_id == &"active"
			and float(boundary.host_state.movement_distance) > 0.0
			and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
			and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state,
			"the actual second in-world convoy and first paid receipt reach their durable boundary")
		if not _failures.is_empty():
			await _retire_game(game)
			quit(1)
			return
		var ready := {"boundary": boundary, "receipts": _convoy_receipts(game),
			"runtime_observation": _interruption_runtime_observation(game)}
		# No orderly exit or further gameplay/save mutation before the harness kill.
		paused = true
		print("IN_WORLD_INTERRUPTION_READY: " + JSON.stringify(ready))
		return
	var boundary := _stored_session_state(store)
	var observations := _interruption_runtime_observation(game)
	var recovery := game.get_recovery_available_snapshot()
	var record := game.get_session_recovery_diagnostic_snapshot()
	var crash_events := 0
	for event: Dictionary in record.get("events", []):
		if event.get("event_code") == "crash_detected":
			crash_events += 1
	_check(bool(game.get_cinder_convoy_session_persistence_report().restore_status.get("accepted", false))
		and game.get_active_activity_snapshot().state_id == &"active"
		and _canonical(game.cinder_convoy_host.capture_persistence_state()) == boundary.host_state
		and _canonical(game.cinder_convoy_threat.capture_persistence_state()) == boundary.threat_state
		and not recovery.is_empty() and recovery.get("state") == "running" and crash_events == 1,
		"a fresh OS process adopts the exact durable convoy and records its genuine interrupted session once")
	var before_receipts := _convoy_receipts(game)
	var craft_index := -1
	var ships := game.get_flyable_ships()
	for index in ships.size():
		if ships[index].get_ship_id() == StringName(boundary.escort_ship_id):
			craft_index = index
	_check(craft_index >= 0, "the durable escort identity resolves to its actual shipped craft")
	var arrived := false
	if craft_index >= 0 and _failures.is_empty():
		var craft := await _prepare_interrupted_convoy(game, craft_index)
		arrived = await _finish_interrupted_convoy(game, craft)
	game.call("_retry_owed_game_flow_activity_rewards")
	game.call("_retry_owed_game_flow_activity_rewards")
	_check(arrived and _convoy_receipts(game) == before_receipts + 1
		and game.get_active_activity_snapshot().state_id == &"completed"
		and bool(store.get_snapshot()[String(SLOT)].activities[0].reward_granted),
		"physical continuation after OS interruption pays the distinct convoy once despite repeated retry")
	var closed := game.mark_orderly_shutdown()
	_check(bool(closed.get("accepted", false)), "the recovered process closes both existing recovery marker owners")
	var outcome := {"boundary": boundary, "receipts_before": before_receipts,
		"receipts_after": _convoy_receipts(game), "crash_events": crash_events,
		"runtime_observation": observations, "assertions": _assertions}
	await _retire_game(game)
	if _failures.is_empty():
		print("IN_WORLD_RECOVERY_OK: " + JSON.stringify(outcome))
		quit(0)
	else:
		print("IN_WORLD_RECOVERY_FAILED")
		quit(1)


func _interruption_runtime_observation(game: GameFlow) -> Dictionary:
	return {"phase": int(game.phase), "piloting": bool(game.get("_piloting")),
		"craft_id": String(game.active_ship.get_ship_id()), "craft_piloted": game.active_ship.is_piloted(),
		"player_seated": bool(game.player.call("is_seated")),
		"craft_position": [game.active_ship.global_position.x, game.active_ship.global_position.y, game.active_ship.global_position.z]}


func _test_terminal_convoy_reward_restart() -> String:
	var path := "user://convoy_reward_interruption_%d.json" % Time.get_ticks_usec()
	var filesystem := InterruptedConvoyRewardFilesystem.new()
	var first_store := Store.new(path, filesystem) as UserDataStore
	var first := await _make_game(first_store)
	first.set_physics_process(false)
	first.call("_on_settings_save_requested")
	var selected := first.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var craft := first.get_flyable_ships()[1] as HeroShip
	craft.set_piloted(true)
	first.active_ship = craft
	first.set("_piloting", true)
	first.set("_sortie_departed_berth", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	first.call("_physics_process", 0.1)
	var streamed := await _wait_until(
		func() -> bool:
			return is_instance_valid(first.cinder_streaming_bootstrap.get_loaded_instance()), 20)
	var started := first.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var host := first.cinder_convoy_host as CinderConvoyEscortHost
	for _tick in 14:
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
		await physics_frame
	var attacker := first.cinder_convoy_threat.get_attacker()
	craft.global_position = attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var intercepted := first.get_combat_authority().submit_hitscan(
		craft, GameFlow.RANGE_WEAPON_ID, craft.global_position,
		attacker.global_position - craft.global_position)
	var budget := 60
	while budget > 0 and host.get_snapshot().activity.state_id == &"active":
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
		budget -= 1
	_check(bool(selected.accepted) and streamed and bool(started.accepted)
		and bool(intercepted.get("destroyed", false)) and budget > 0
		and host.get_snapshot().activity.state_id == &"completed"
		and filesystem.reward_rejected and filesystem.stopped and _convoy_receipts(first) == 0,
		"real Main convoy arrives after ordinary raider interception with rejected reward and frozen disk")
	var disk_store := Store.new(path) as UserDataStore
	disk_store.load()
	var record := disk_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	var activities := record.get("activities", []) as Array
	_check(activities.size() == 1 and int((activities[0] as Dictionary).get("state", -1)) == ConvoyEscortActivity.State.COMPLETED,
		"interrupted real files retain the actual completed convoy owner")
	await _retire_game(first)
	var retry_filesystem := InterruptedConvoyRewardFilesystem.new()
	var second_store := Store.new(path, retry_filesystem) as UserDataStore
	var second := await _make_game(second_store)
	_check(second.get_active_activity_snapshot().get("state_id") == &"completed"
		and _convoy_receipts(second) == 0 and retry_filesystem.reward_rejected
		and not bool(second.cinder_convoy_threat.get_snapshot().get("active", true))
		and not bool(second.get("_cinder_convoy_runtime_rebind_pending")),
		"fresh Main restores its durable unpaid convoy without restarting combat")
	var blocked_start := second.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(not second.reset_active_activity() and not bool(blocked_start.accepted)
		and blocked_start.reason == &"convoy_reward_pending",
		"failed reward retry keeps the arrived owner and blocks reset or start")
	second.active_ship = second.get_flyable_ships()[0] as HeroShip
	retry_filesystem.interrupt_rewards = false
	retry_filesystem.stopped = false
	second.call("_retry_owed_game_flow_activity_rewards")
	var acknowledged := (second_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary)
	_check(_convoy_receipts(second) == 1 and acknowledged.reward_requested and acknowledged.reward_granted,
		"retry from a different craft publishes the original escort receipt and matching acknowledgement")
	second.save_cinder_convoy_session()
	_check(bool(second_store.get_snapshot()[String(SLOT)].activities[0].reward_granted),
		"same-generation terminal save preserves the durable paid marker")
	_complete_unrelated_race(second)
	_check(_convoy_receipts(second) == 1 and _total_receipts(second) == 2,
		"a genuine race handoff becomes the latest receipt after convoy acknowledgement")
	await _retire_game(second)
	var third_filesystem := InterruptedConvoyRewardFilesystem.new()
	third_filesystem.interrupt_rewards = false
	var third_store := Store.new(path, third_filesystem) as UserDataStore
	var third := await _make_game(third_store)
	third.call("_on_cinder_convoy_safely_arrived", third.cinder_convoy_host.get_snapshot())
	_check(third.cinder_convoy_host.get_generation() == 1,
		"paid terminal restore retains the exact convoy generation")
	_check(_convoy_receipts(third) == 1 and _total_receipts(third) == 2 and third.get_active_activity_snapshot().get("state_id") == &"completed",
		"paid terminal restart and repeated handoff cannot pay a second receipt")
	var replacement_craft := third.get_flyable_ships()[1] as HeroShip
	replacement_craft.set_piloted(true)
	third.active_ship = replacement_craft
	third.set("_piloting", true)
	third.set("_sortie_departed_berth", true)
	third.phase = GameFlow.Phase.FREE_FLIGHT
	replacement_craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	third.call("_physics_process", 0.1)
	var streamed_again := await _wait_until(func() -> bool:
		return is_instance_valid(third.cinder_streaming_bootstrap.get_loaded_instance()), 20)
	var repeat := third.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(streamed_again and not bool(repeat.accepted) and repeat.reason == &"reset_required",
		"a paid terminal public start retains the existing explicit reset requirement")
	var original_host := third.cinder_convoy_host
	var original_state := original_host.capture_persistence_state()
	var original_payload := third_store.get_snapshot()
	var failed_reset_signals := _new_signal_counts()
	_connect_host_signal_counts(original_host, failed_reset_signals)
	third_filesystem.stopped = true
	_check(not third.reset_active_activity() and third.cinder_convoy_host.get_snapshot().activity.state_id == &"completed"
		and third.cinder_convoy_host.get_generation() == 1
		and third.cinder_convoy_host == original_host and original_host.capture_persistence_state() == original_state
		and third_store.get_snapshot() == original_payload and _signal_total(failed_reset_signals) == 0,
		"rejected staged reset preserves exact completed owner, fields, disk, and outward signals")
	third_filesystem.stopped = false
	var reset := third.reset_active_activity()
	var restarted := third.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(reset and bool(restarted.accepted) and third.cinder_convoy_host.get_generation() > 1
		and not bool((third_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary).reward_requested)
		and not bool((third_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary).reward_granted),
		"successful explicit reset starts a new exact generation without inherited acknowledgement")
	var new_host := third.cinder_convoy_host as CinderConvoyEscortHost
	# Ordinary interception preserves the production threat contract in this run.
	for _tick in 14:
		replacement_craft.global_position = (new_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		third.call("_physics_process", 0.25)
		await physics_frame
	var new_attacker := third.cinder_convoy_threat.get_attacker()
	replacement_craft.global_position = new_attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var new_intercept := third.get_combat_authority().submit_hitscan(replacement_craft,
		GameFlow.RANGE_WEAPON_ID, replacement_craft.global_position, new_attacker.global_position - replacement_craft.global_position)
	_check(bool(new_intercept.get("destroyed", false)), "the next convoy also neutralizes its own real raider")
	third_filesystem.reject_terminal_saves = true
	budget = 60
	while budget > 0 and new_host.get_snapshot().activity.state_id == &"active":
		replacement_craft.global_position = (new_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		third.call("_physics_process", 0.25)
		budget -= 1
	_check(budget > 0 and new_host.get_snapshot().activity.state_id == &"completed"
		and third_filesystem.terminal_rejected and _convoy_receipts(third) == 1
		and third.get_activity_reward_report().get("last_result", {}).get("reason") == &"reward_terminal_save_rejected",
		"the new live convoy's rejected final terminal save grants no reward")
	third_filesystem.reject_terminal_saves = false
	third_filesystem.interrupt_rewards = true
	third_filesystem.stage_reward_before_refusal = true
	third.call("_retry_owed_game_flow_activity_rewards")
	var staged_generation := new_host.get_generation()
	_check(third_filesystem.reward_rejected and third_filesystem.stopped and _convoy_receipts(third) == 1,
		"same-owner retry saves its captured threat and stages the actual acknowledgement before refusal")
	await _retire_game(third)
	var fourth_store := Store.new(path) as UserDataStore
	var fourth := await _make_game(fourth_store)
	var actual_paid_terminal := (fourth_store.get_snapshot()[String(SLOT)] as Dictionary).duplicate(true)
	fourth.call("_on_cinder_convoy_safely_arrived", fourth.cinder_convoy_host.get_snapshot())
	_check(_convoy_receipts(fourth) == 2 and _total_receipts(fourth) == 3
		and fourth.cinder_convoy_host.get_generation() == staged_generation
		and not bool(fourth.cinder_convoy_threat.get_snapshot().get("active", true))
		and fourth.reset_active_activity(),
		"existing store recovery resolves a staged paid generation once and unblocks reset")
	var idle_generation := fourth.cinder_convoy_host.get_generation()
	_check(fourth.get_active_activity_snapshot().get("state_id") == &"idle"
		and int((fourth_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary).generation) == idle_generation
		and int((fourth_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary).state) == ConvoyEscortActivity.State.IDLE,
		"accepted reset publishes the exact real IDLE owner and generation durably")
	await _retire_game(fourth)
	var fifth_store := Store.new(path) as UserDataStore
	var fifth := await _make_game(fifth_store)
	_check(fifth.get_active_activity_snapshot().get("state_id") == &"idle"
		and fifth.cinder_convoy_host.get_generation() == idle_generation
		and not bool(fifth.cinder_convoy_threat.get_snapshot().get("active", true))
		and not bool(fifth.get("_cinder_convoy_runtime_rebind_pending"))
		and not fifth.reset_active_activity(),
		"fresh Main retains the accepted IDLE generation inertly and refuses a redundant reset")
	var fresh_craft := fifth.get_flyable_ships()[0] as HeroShip
	fresh_craft.set_piloted(true)
	fifth.active_ship = fresh_craft
	fifth.set("_piloting", true)
	fifth.set("_sortie_departed_berth", true)
	fifth.phase = GameFlow.Phase.FREE_FLIGHT
	fresh_craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	fifth.call("_physics_process", 0.1)
	var fresh_stream := await _wait_until(func() -> bool:
		return is_instance_valid(fifth.cinder_streaming_bootstrap.get_loaded_instance()), 20)
	fresh_craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var fresh_start := fifth.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var active_record := (fifth_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary)
	_check(fresh_stream and bool(fresh_start.accepted) and fifth.cinder_convoy_host.get_generation() == idle_generation + 1
		and int(active_record.generation) == idle_generation + 1 and not bool(active_record.reward_requested)
		and str((active_record.progress.convoy_session_state as Dictionary).escort_ship_id) == String(fresh_craft.get_ship_id()),
		"real start after saved reset uses the next typed generation and the newly piloted craft")
	fifth.call("_on_cinder_convoy_safely_arrived", {"activity": {"generation": staged_generation}})
	_check(_convoy_receipts(fifth) == 2 and fifth.cinder_convoy_host.get_snapshot().activity.state_id == &"active",
		"an old completion handoff cannot mutate or pay the new active convoy")
	var final_host := fifth.cinder_convoy_host as CinderConvoyEscortHost
	for _tick in 14:
		fresh_craft.global_position = (final_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		fifth.call("_physics_process", 0.25)
		await physics_frame
	var final_attacker := fifth.cinder_convoy_threat.get_attacker()
	fresh_craft.global_position = final_attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var final_intercept := fifth.get_combat_authority().submit_hitscan(fresh_craft,
		GameFlow.RANGE_WEAPON_ID, fresh_craft.global_position, final_attacker.global_position - fresh_craft.global_position)
	budget = 60
	while budget > 0 and final_host.get_snapshot().activity.state_id == &"active":
		fresh_craft.global_position = (final_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		fifth.call("_physics_process", 0.25)
		budget -= 1
	_check(bool(final_intercept.get("destroyed", false)) and budget > 0
		and final_host.get_snapshot().activity.state_id == &"completed"
		and _convoy_receipts(fifth) == 3 and _total_receipts(fifth) == 4,
		"the genuine next convoy after reset and restart arrives and earns one distinct new credit")
	actual_paid_terminal = (fifth_store.get_snapshot()[String(SLOT)] as Dictionary).duplicate(true)
	await _retire_game(fifth)
	# Labelled legacy wire compatibility derives solely from the genuine terminal.
	var legacy_path := path + "_legacy"
	var legacy_store := Store.new(legacy_path) as UserDataStore
	legacy_store.load()
	var legacy_payload := fifth_store.get_snapshot()
	var legacy_record := actual_paid_terminal.duplicate(true)
	legacy_record.activities[0].reward_requested = false
	legacy_record.activities[0].reward_granted = false
	legacy_payload[String(SLOT)] = legacy_record
	var legacy_saved := legacy_store.commit(legacy_payload, legacy_store.get_generation(), "legacy-convoy-wire-fixture")
	var legacy := await _make_game(Store.new(legacy_path))
	legacy.call("_on_cinder_convoy_safely_arrived", legacy.cinder_convoy_host.get_snapshot())
	_check(bool(legacy_saved.accepted) and legacy.get_active_activity_snapshot().get("state_id") == &"completed"
		and _convoy_receipts(legacy) == 3 and not bool(legacy.call("_has_pending_cinder_convoy_reward"))
		and not bool((legacy_store.get_snapshot()[String(SLOT)].activities[0] as Dictionary).reward_requested),
		"legacy false/false terminal remains explicitly ambiguous and receives no inferred credit")
	await _retire_game(legacy)
	return path


func _test_interrupted_convoy_lifecycle(paid_path: String) -> void:
	# Every case begins with bytes from the genuinely paid Main convoy above.
	var paid_bytes := FileAccess.get_file_as_bytes(paid_path)
	for case_id: String in ["missed_complete", "missed_failed", "missed_abort", "progress_complete", "progress_failed"]:
		var path := "user://convoy-interrupted-%s.json" % case_id
		var filesystem := InterruptedConvoyRewardFilesystem.new()
		filesystem.interrupt_rewards = false
		filesystem.write_bytes_and_flush(path, paid_bytes)
		var store := Store.new(path, filesystem) as UserDataStore
		var game := await _make_game(store)
		game.set_physics_process(false)
		var craft := await _prepare_interrupted_convoy(game, 1)
		var reset := game.reset_active_activity()
		var idle_state := game.cinder_convoy_host.capture_persistence_state()
		var old_receipts := _convoy_receipts(game)
		var missed_start := case_id.begins_with("missed_")
		filesystem.stopped = missed_start
		var started := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var host := game.cinder_convoy_host
		for _tick in 2:
			craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			game.call("_physics_process", 0.25)
		var early := game.save_cinder_convoy_session()
		_check(reset and bool(started.accepted) and host.get_generation() == int(idle_state.activity_state.generation) + 1
			and (not bool(early.accepted) if missed_start else bool(early.accepted)),
			"%s uses a genuine new convoy after a durably saved paid reset" % case_id)
		filesystem.stopped = true
		if case_id.ends_with("complete"):
			var arrived := await _finish_interrupted_convoy(game, craft)
			_check(arrived and _convoy_receipts(game) == old_receipts,
				"%s physically arrives with writes blocked and no premature reward" % case_id)
			if missed_start:
				var terminal := host.capture_persistence_state()
				var candidate := CinderConvoyEscortHost.new()
				candidate.visible = false
				root.add_child(candidate)
				var adopted := candidate.restore_persistence_state(terminal, 0)
				var staged := candidate.reset(candidate.get_generation())
				var codec := SessionPersistence.new()
				codec.configure(store, SLOT)
				var refused := codec.save(candidate, game.call("_cinder_convoy_persistence_ship_id"),
					"unowned-convoy-reset", null, host)
				_check(bool(adopted.accepted) and bool(staged.accepted) and not bool(refused.accepted)
					and refused.reason == &"unproven_convoy_generation" and host.capture_persistence_state() == terminal
					and not game.reset_active_activity() and _convoy_receipts(game) == old_receipts,
					"an unowned typed reset scratch cannot replace the actual unpaid missed-start arrival")
				candidate.free()
			filesystem.stopped = false
			game.call("_retry_owed_game_flow_activity_rewards")
			var status := game.save_cinder_convoy_session()
			_check(bool(status.accepted) and _convoy_receipts(game) == old_receipts + 1,
				"%s ordinary retry publishes actual arrival and pays once (%s)" % [case_id, status.get("reason", "")])
			game.call("_retry_owed_game_flow_activity_rewards")
			_check(_convoy_receipts(game) == old_receipts + 1, "repeated %s retry cannot duplicate credit" % case_id)
		else:
			if case_id.ends_with("failed"):
				_check(game.fail_active_activity(&"returned_to_shipyard"), "%s uses the real public convoy loss producer" % case_id)
			else:
				var bolt_budget := 20
				while bolt_budget > 0 and int(game.cinder_convoy_threat.get_snapshot().bolts_in_flight) == 0:
					craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
					game.call("_physics_process", 0.25)
					await physics_frame
					bolt_budget -= 1
				_check(bolt_budget > 0, "missed-start ACTIVE abort retains genuine inflight combat bolts")
			var original := host.capture_persistence_state()
			var threat := game.cinder_convoy_threat.get_snapshot()
			var bytes := _convoy_disk_bytes(path)
			var signals := _new_signal_counts()
			_connect_host_signal_counts(host, signals)
			if case_id.ends_with("abort"):
				var witness := {"reference": null, "owned": false}
				var discarded := host.reset_with_persistence(host.get_generation(),
					func(candidate: CinderConvoyEscortHost) -> Dictionary:
						witness.reference = weakref(candidate)
						witness.owned = host.is_staged_persistence_reset(candidate)
						return game.call("_save_cinder_convoy_reset_candidate", candidate))
				_check(not bool(discarded.accepted) and bool(witness.owned)
					and (witness.reference as WeakRef).get_ref() == null and not host.is_staged_persistence_reset(null),
					"a discarded actual convoy reset scratch loses its exact transient owner fence")
			_check(not game.reset_active_activity() and game.cinder_convoy_host == host
				and host.capture_persistence_state() == original and game.cinder_convoy_threat.get_snapshot() == threat
				and _convoy_disk_bytes(path) == bytes and _signal_total(signals) == 0,
				"%s rejected reset preserves owner, threat, bolts, events and every store file" % case_id)
			filesystem.stopped = false
			var accepted := game.reset_active_activity()
			_check(accepted and host.get_generation() == int(original.activity_state.generation) + 1
				and host.get_snapshot().activity.state_id == &"idle" and _convoy_receipts(game) == old_receipts,
				"%s recovered ordinary reset durably retains its actual new generation" % case_id)
			var expected := host.capture_persistence_state()
			await _retire_game(game)
			if not accepted:
				continue
			game = await _make_game(Store.new(path))
			game.set_physics_process(false)
			_check(game.cinder_convoy_host.capture_persistence_state() == expected,
				"fresh Main keeps %s accepted IDLE generation and entity epoch" % case_id)
			craft = await _prepare_interrupted_convoy(game, 0 if case_id.ends_with("abort") else 1)
			var next_start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
			var arrived := await _finish_interrupted_convoy(game, craft)
			_check(bool(next_start.accepted) and arrived and _convoy_receipts(game) == old_receipts + 1,
				"%s reset/restart allows its next genuine same or other craft escort to earn one new credit" % case_id)
		await _retire_game(game)


func _prepare_interrupted_convoy(game: GameFlow, craft_index: int) -> HeroShip:
	var craft := game.get_flyable_ships()[craft_index] as HeroShip
	craft.set_piloted(true)
	game.active_ship = craft
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	game.call("_physics_process", 0.1)
	await _wait_until(func() -> bool:
		return is_instance_valid(game.cinder_streaming_bootstrap.get_loaded_instance()), 20)
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	return craft


func _finish_interrupted_convoy(game: GameFlow, craft: HeroShip) -> bool:
	var host := game.cinder_convoy_host
	for _tick in 14:
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		await physics_frame
	var attacker := game.cinder_convoy_threat.get_attacker()
	if not is_instance_valid(attacker):
		return false
	craft.global_position = attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var intercepted := game.get_combat_authority().submit_hitscan(craft, GameFlow.RANGE_WEAPON_ID,
		craft.global_position, attacker.global_position - craft.global_position)
	var budget := 60
	while budget > 0 and host.get_snapshot().activity.state_id == &"active":
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		budget -= 1
	return bool(intercepted.get("destroyed", false)) and budget > 0 and host.get_snapshot().activity.state_id == &"completed"


func _convoy_disk_bytes(path: String) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".tmp", ".bak", ".bak.1", ".bak.2", ".bak.3"]:
		result[suffix] = FileAccess.get_file_as_bytes(path + suffix) if FileAccess.file_exists(path + suffix) else null
	return result


func _test_failed_convoy_reset_restart(path: String) -> void:
	var filesystem := InterruptedConvoyRewardFilesystem.new()
	filesystem.interrupt_rewards = false
	var store := Store.new(path, filesystem) as UserDataStore
	var first := await _make_game(store)
	first.set_physics_process(false)
	var craft := first.get_flyable_ships()[1] as HeroShip
	craft.set_piloted(true)
	first.active_ship = craft
	first.set("_piloting", true)
	first.set("_sortie_departed_berth", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	first.call("_physics_process", 0.1)
	var streamed := await _wait_until(func() -> bool:
		return is_instance_valid(first.cinder_streaming_bootstrap.get_loaded_instance()), 20)
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var previous_generation := first.cinder_convoy_host.get_generation()
	var paid_reset := first.reset_active_activity()
	var started := first.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	for _tick in 2:
		craft.global_position = (first.cinder_convoy_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
	# The existing public failure seam reports the current tender lost, as on
	# pilot departure/return. It does not author a state or activity generation.
	var failed := first.fail_active_activity(&"returned_to_shipyard")
	var failed_generation := first.cinder_convoy_host.get_generation()
	var failed_epoch := int(first.cinder_convoy_host.get_snapshot().entity_generation)
	var failed_snapshot := first.cinder_convoy_host.get_snapshot().activity as Dictionary
	_check(streamed and paid_reset and bool(started.accepted) and failed
		and failed_generation > previous_generation and _convoy_receipts(first) == 3
		and failed_snapshot.state_id == &"failed"
		and int(failed_snapshot.terminal_result) == ConvoyEscortActivity.TerminalResult.CONVOY_LOST,
		"after an actual paid convoy, the next live Main run ends through its ordinary loss authority without reward")
	var original_host := first.cinder_convoy_host
	var original_state := original_host.capture_persistence_state()
	var original_payload := store.get_snapshot()
	var reset_signals := _new_signal_counts()
	_connect_host_signal_counts(original_host, reset_signals)
	filesystem.stopped = true
	_check(not first.reset_active_activity() and first.cinder_convoy_host == original_host
		and original_host.capture_persistence_state() == original_state
		and store.get_snapshot() == original_payload and _signal_total(reset_signals) == 0,
		"a rejected failed-run reset preserves the exact live owner, fields, disk, and events")
	filesystem.stopped = false
	var reset := first.reset_active_activity()
	var idle_generation := first.cinder_convoy_host.get_generation()
	_check(reset and first.cinder_convoy_host.get_snapshot().activity.state_id == &"idle"
		and idle_generation == failed_generation + 1,
		"ordinary failed-run reset is accepted and derives its next typed generation")
	var reset_record := store.get_snapshot().get(String(SLOT), {}) as Dictionary
	var activities := reset_record.get("activities", []) as Array
	_check(activities.size() == 1 and int((activities[0] as Dictionary).get("state", -1)) == ConvoyEscortActivity.State.IDLE
		and int((activities[0] as Dictionary).get("generation", -1)) == idle_generation,
		"accepted failed-run reset retains its exact IDLE generation on real disk")
	await _retire_game(first)
	var fresh := await _make_game(Store.new(path, filesystem))
	fresh.set_physics_process(false)
	var adopted: bool = fresh.get_active_activity_snapshot().get("state_id") == &"idle" \
		and fresh.cinder_convoy_host.get_generation() == idle_generation \
		and int(fresh.cinder_convoy_host.get_snapshot().entity_generation) == failed_epoch
	_check(adopted and _convoy_receipts(fresh) == 3
		and not bool(fresh.cinder_convoy_threat.get_snapshot().get("active", true)),
		"fresh Main adopts the failed-run reset IDLE generation and entity epoch without combat or inferred debt")
	if adopted:
		var next_craft := fresh.get_flyable_ships()[1] as HeroShip
		next_craft.set_piloted(true)
		fresh.active_ship = next_craft
		fresh.set("_piloting", true)
		fresh.set("_sortie_departed_berth", true)
		fresh.phase = GameFlow.Phase.FREE_FLIGHT
		next_craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
		fresh.call("_physics_process", 0.1)
		var stream_ready := await _wait_until(func() -> bool:
			return is_instance_valid(fresh.cinder_streaming_bootstrap.get_loaded_instance()), 20)
		next_craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
		var next_start := fresh.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
		var host := fresh.cinder_convoy_host as CinderConvoyEscortHost
		for _tick in 14:
			next_craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			fresh.call("_physics_process", 0.25)
			await physics_frame
		var attacker := fresh.cinder_convoy_threat.get_attacker()
		next_craft.global_position = attacker.global_position + Vector3(0.0, 0.0, 12.0)
		await physics_frame
		var intercepted := fresh.get_combat_authority().submit_hitscan(next_craft,
			GameFlow.RANGE_WEAPON_ID, next_craft.global_position, attacker.global_position - next_craft.global_position)
		var budget := 60
		while budget > 0 and host.get_snapshot().activity.state_id == &"active":
			next_craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
			fresh.call("_physics_process", 0.25)
			budget -= 1
		_check(stream_ready and bool(next_start.accepted) and bool(intercepted.get("destroyed", false))
			and budget > 0 and host.get_snapshot().activity.state_id == &"completed"
			and host.get_generation() == idle_generation + 1
			and int(host.get_snapshot().entity_generation) == failed_epoch + 1
			and _convoy_receipts(fresh) == 4,
			"the genuine next convoy after failed reset and restart keeps its new identity and earns exactly one credit")
	else:
		_check(false, "the next genuine convoy cannot recover its saved failed-reset identity")
	if adopted:
		await _exercise_abort_actor_and_combat_reset(fresh, path, filesystem)
	else:
		await _retire_game(fresh)
	await _exercise_failed_clock_witnesses()


func _exercise_abort_actor_and_combat_reset(game: GameFlow, path: String, filesystem: InterruptedConvoyRewardFilesystem) -> void:
	game.active_ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var paid_reset := game.reset_active_activity()
	var start := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var host := game.cinder_convoy_host as CinderConvoyEscortHost
	var active_generation := host.get_generation()
	var epoch := int(host.get_snapshot().entity_generation)
	var bolt_budget := 20
	while bolt_budget > 0 and int(game.cinder_convoy_threat.get_snapshot().bolts_in_flight) == 0:
		game.active_ship.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		game.call("_physics_process", 0.25)
		await physics_frame
		bolt_budget -= 1
	var active_state := host.capture_persistence_state()
	var active_threat := game.cinder_convoy_threat.get_snapshot()
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	var payload := store.get_snapshot()
	var signals := _new_signal_counts()
	_connect_host_signal_counts(host, signals)
	filesystem.stopped = true
	_check(not game.reset_active_activity() and game.cinder_convoy_host == host
		and host.capture_persistence_state() == active_state
		and store.get_snapshot() == payload and _signal_total(signals) == 0
		and bolt_budget > 0 and int(active_threat.bolts_in_flight) > 0
		and game.cinder_convoy_threat.get_snapshot() == active_threat,
		"a refused ACTIVE-abort reset write preserves its exact owner, state, disk, events, threat, and real bolts")
	filesystem.stopped = false
	# A normal public reset of a running convoy is the production abort surface.
	# The actual reset candidate is committed before this owner publishes IDLE.
	var aborted := game.reset_active_activity()
	var reset_generation := host.get_generation()
	_check(paid_reset and bool(start.accepted) and aborted
		and active_state.activity_state.state == ConvoyEscortActivity.State.ACTIVE
		and reset_generation == active_generation + 1
		and int(host.get_snapshot().entity_generation) == epoch and _convoy_receipts(game) == 4
		and not bool(game.cinder_convoy_threat.get_snapshot().active)
		and int(game.cinder_convoy_threat.get_snapshot().bolts_in_flight) == 0,
		"ordinary ACTIVE convoy abort/reset persists IDLE with a new model generation and unchanged entity epoch")
	game.active_ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var resumed := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(bool(resumed.accepted) and host.get_generation() == reset_generation + 1
		and bool(game.cinder_convoy_threat.get_snapshot().active)
		and int(game.cinder_convoy_threat.get_snapshot().generation) == host.get_generation(),
		"accepted ACTIVE abort immediately permits a genuine same-process new convoy and threat")
	var resumed_loss := game.fail_active_activity(&"returned_to_shipyard")
	var resumed_reset := game.reset_active_activity()
	_check(resumed_loss and resumed_reset and host.get_snapshot().activity.state_id == &"idle"
		and not bool(game.cinder_convoy_threat.get_snapshot().active) and _convoy_receipts(game) == 4,
		"the new same-process convoy uses ordinary loss/reset without inherited debt")
	reset_generation = host.get_generation()
	epoch = int(host.get_snapshot().entity_generation)
	await _retire_game(game)
	var fresh := await _make_game(Store.new(path))
	fresh.set_physics_process(false)
	_check(fresh.cinder_convoy_host.get_generation() == reset_generation
		and fresh.get_active_activity_snapshot().state_id == &"idle"
		and int(fresh.cinder_convoy_host.get_snapshot().entity_generation) == epoch,
		"fresh Main retains the accepted ACTIVE-abort reset identity")
	var craft := await _prepare_convoy_craft(fresh)
	var actor_start := fresh.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	host = fresh.cinder_convoy_host
	craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
	fresh.call("_physics_process", 0.25)
	var retained_position := host.capture_persistence_state().entity_position as Dictionary
	host.get_entity_presentation_root().free()
	fresh.call("_physics_process", 0.25)
	var actor_failed := host.capture_persistence_state()
	var actor_record := (fresh.get("_runtime_settings_user_data_store") as UserDataStore).get_snapshot().get(String(SLOT), {}) as Dictionary
	_check(bool(actor_start.accepted) and actor_failed.activity_state.state == ConvoyEscortActivity.State.FAILED
		and actor_failed.entity_position == retained_position
		and not is_instance_valid(host.get_entity_presentation_root())
		and actor_record.activities.size() == 1 and int(actor_record.activities[0].state) == ConvoyEscortActivity.State.FAILED,
		"actual tender actor removal persists loss from its retained last position without respawning")
	var actor_generation := host.get_generation()
	var actor_reset := fresh.reset_active_activity()
	_check(actor_reset and host.get_generation() == actor_generation + 1
		and is_instance_valid(host.get_entity_presentation_root()) and host.get_snapshot().activity.state_id == &"idle",
		"only a committed ordinary actor-loss reset recreates the tender and retains generation")
	var combat_start := fresh.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var budget := 100
	while budget > 0 and host.get_snapshot().activity.state_id == &"active":
		craft.global_position = (host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		fresh.call("_physics_process", 0.25)
		await physics_frame
		budget -= 1
	var threat := fresh.cinder_convoy_threat.capture_persistence_state()
	var combat_record := (fresh.get("_runtime_settings_user_data_store") as UserDataStore).get_snapshot().get(String(SLOT), {}) as Dictionary
	_check(bool(combat_start.accepted) and budget > 0 and host.get_snapshot().activity.state_id == &"failed"
		and float(threat.tender_health) == 0.0 and int(threat.shots_fired) > 0
		and combat_record.activities.size() == 1 and int(combat_record.activities[0].state) == ConvoyEscortActivity.State.FAILED
		and float(combat_record.activities[0].progress.convoy_session_state.threat_state.tender_health) == 0.0,
		"actual hostile bolts destroy the tender and persist its unmodified zero-health terminal threat")
	var combat_generation := host.get_generation()
	var combat_epoch := int(host.get_snapshot().entity_generation)
	await _retire_game(fresh)
	var final_game := await _make_game(Store.new(path))
	final_game.set_physics_process(false)
	_check(final_game.cinder_convoy_host.get_generation() == combat_generation
		and final_game.get_active_activity_snapshot().state_id == &"failed"
		and not bool(final_game.cinder_convoy_threat.get_snapshot().active) and _convoy_receipts(final_game) == 4,
		"fresh Main restores actual combat loss inertly with no reward entitlement")
	var combat_reset := final_game.reset_active_activity()
	var combat_idle_generation := final_game.cinder_convoy_host.get_generation()
	await _retire_game(final_game)
	var next_game := await _make_game(Store.new(path))
	next_game.set_physics_process(false)
	_check(combat_reset and next_game.get_active_activity_snapshot().state_id == &"idle"
		and next_game.cinder_convoy_host.get_generation() == combat_idle_generation
		and combat_idle_generation == combat_generation + 1
		and int(next_game.cinder_convoy_host.get_snapshot().entity_generation) == combat_epoch,
		"combat-loss reset survives another fresh Main with exact IDLE generation and epoch")
	var next_craft := await _prepare_convoy_craft(next_game)
	var next_start := next_game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var next_host := next_game.cinder_convoy_host as CinderConvoyEscortHost
	for _tick in 14:
		next_craft.global_position = (next_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		next_game.call("_physics_process", 0.25)
		await physics_frame
	var attacker := next_game.cinder_convoy_threat.get_attacker()
	next_craft.global_position = attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var intercepted := next_game.get_combat_authority().submit_hitscan(next_craft,
		GameFlow.RANGE_WEAPON_ID, next_craft.global_position, attacker.global_position - next_craft.global_position)
	budget = 60
	while budget > 0 and next_host.get_snapshot().activity.state_id == &"active":
		next_craft.global_position = (next_host.get_snapshot().entity_position as Vector3) + GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		next_game.call("_physics_process", 0.25)
		budget -= 1
	_check(bool(next_start.accepted) and bool(intercepted.get("destroyed", false)) and budget > 0
		and next_host.get_snapshot().activity.state_id == &"completed"
		and next_host.get_generation() == combat_idle_generation + 1
		and int(next_host.get_snapshot().entity_generation) == combat_epoch + 1
		and _convoy_receipts(next_game) == 5,
		"after combat-loss reset and fresh Main the actual next convoy earns its fifth distinct credit")
	await _retire_game(next_game)


func _prepare_convoy_craft(game: GameFlow) -> HeroShip:
	var craft := game.get_flyable_ships()[1] as HeroShip
	craft.set_piloted(true)
	game.active_ship = craft
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	game.call("_physics_process", 0.1)
	await _wait_until(func() -> bool:
		return is_instance_valid(game.cinder_streaming_bootstrap.get_loaded_instance()), 20)
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	return craft


func _exercise_failed_clock_witnesses() -> void:
	for scenario in ["reported", "separation", "timeout", "separation_after_tick", "timeout_after_tick"]:
		var host := CinderConvoyEscortHost.new()
		root.add_child(host)
		host.start(0)
		var generation := host.get_generation()
		if scenario.ends_with("after_tick"):
			host.advance_physics(0.25, CinderConvoyEscortHost.ROUTE.get_checkpoint_position(0), generation)
		if scenario == "reported":
			host.report_convoy_lost(generation)
		elif scenario.begins_with("separation"):
			host.advance_physics(301.0, Vector3(10000.0, 0.0, 0.0), generation)
		else:
			host.advance_physics(301.0, (host.get_snapshot().entity_position as Vector3), generation)
		var state := host.capture_persistence_state()
		var validated := host.validate_persistence_state(state)
		var restored := CinderConvoyEscortHost.new()
		root.add_child(restored)
		var adopted := restored.restore_persistence_state(state, 0)
		_check(bool(validated.accepted) and bool(adopted.accepted)
			and restored.capture_persistence_state() == state,
			"exact actual terminal sample/clock witness restores without mutation: %s" % scenario)
		restored.free()
		host.free()


func _total_receipts(game: GameFlow) -> int:
	return int((game.get_activity_reward_report().get("authority", {}) as Dictionary).get("record", {}).get("total_receipts", 0))


func _complete_unrelated_race(game: GameFlow) -> void:
	# Main-compatible actual typed race + codec handoff, bounded model scope.
	var director := ActivityDirector.new()
	root.add_child(director)
	director.register_definition(CinderTimedRaceSession.ROUTE)
	var race := CinderTimedRaceSession.new(GameFlow.CINDER_RACE_LAPS,
		GameFlow.CINDER_RACE_COUNTDOWN_SECONDS, GameFlow.CINDER_RACE_TIMEOUT_SECONDS)
	race.attach(director, 0)
	race.start(0)
	race.advance_physics(2.0, race.get_session_generation())
	race.advance_physics(1.0, race.get_session_generation())
	race.advance_physics(0.25, race.get_session_generation())
	for checkpoint in CinderTimedRaceSession.ROUTE.get_checkpoint_count():
		race.submit_position(CinderTimedRaceSession.ROUTE.get_checkpoint_position(checkpoint), race.get_session_generation())
	var persistence := CinderRaceSessionPersistence.new()
	persistence.configure(game.get("_runtime_settings_user_data_store") as UserDataStore, &"cinder_timed_race_session")
	var saved := persistence.save(race, director, "convoy-unrelated-live-race")
	game.call("_on_cinder_session_completed", race.get_presentation_snapshot())
	_check(bool(saved.accepted) and int(race.get_presentation_snapshot().get("state", -1)) == TimedCheckpointRace.State.COMPLETED,
		"the unrelated receipt is produced by the actual Main-compatible race terminal and codec")
	race.close(race.get_session_generation())
	director.free()


func _convoy_receipts(game: GameFlow) -> int:
	var authority := game.get_activity_reward_report().get("authority", {}) as Dictionary
	var record := authority.get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get("return_convoy_credit_to_shipyard", 0))


func _exercise_threat_save_restore(filesystem: MemoryFilesystem) -> void:
	var store := Store.new(THREAT_STORE_PATH, filesystem) as UserDataStore
	store.load()
	var first := await _make_game(store)
	if first == null:
		return
	first.set_physics_process(false)
	first.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var craft := first.get_flyable_ships()[1] as HeroShip
	craft.set_piloted(true)
	first.active_ship = craft
	first.set("_piloting", true)
	first.set("_sortie_departed_berth", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	first.call("_physics_process", 0.1)
	await _wait_until(
		func() -> bool:
			return is_instance_valid(
				(first.cinder_streaming_bootstrap as CinderStreamingBootstrap).get_loaded_instance()
			),
		20
	)
	var started := first.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var host := first.cinder_convoy_host as CinderConvoyEscortHost
	_check(
		bool(started.get("accepted", false))
		and int(_stored_session_state(store).get("schema_version", 0))
		== SessionPersistence.SESSION_SCHEMA_VERSION,
		"accepted convoy start saves the armed threat before the next physics tick"
	)
	for _tick in 14:
		craft.global_position = (host.get_snapshot().get("entity_position") as Vector3) \
			+ GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
		await physics_frame
	var threat := first.cinder_convoy_threat as CinderConvoyThreat
	var wounded := threat.get_snapshot()
	var auto_saved_wound: float = float(
		(_stored_session_state(store).get("threat_state", {}) as Dictionary).get("tender_health", 75.0)
	)
	var attacker := threat.get_attacker()
	craft.global_position = attacker.global_position + Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var intercepted := first.get_combat_authority().submit_hitscan(
		craft, GameFlow.RANGE_WEAPON_ID, craft.global_position,
		attacker.global_position - craft.global_position
	)
	var neutralized := threat.get_snapshot()
	var auto_saved_neutralization: bool = bool(
		(_stored_session_state(store).get("threat_state", {}) as Dictionary).get("attacker_neutralized", false)
	)
	var saved := first.save_cinder_convoy_session()
	_check(
		bool(started.get("accepted", false))
		and float(wounded.get("tender_health", 75.0)) < 75.0
		and is_equal_approx(float(auto_saved_wound), float(wounded.get("tender_health", 0.0)))
		and bool(intercepted.get("destroyed", false))
		and is_zero_approx(float(neutralized.get("attacker_health", 35.0)))
		and bool(auto_saved_neutralization)
		and bool(saved.get("accepted", false)),
		"live tender damage and raider neutralization are saved in the existing session slot"
	)
	var saved_state := _stored_session_state(store)
	var saved_threat := saved_state.get("threat_state", {}) as Dictionary
	_check(
		int(saved_state.get("schema_version", 0)) == SessionPersistence.SESSION_SCHEMA_VERSION
		and is_equal_approx(float(saved_threat.get("tender_health", 0.0)), float(neutralized.get("tender_health", -1.0)))
		and bool(saved_threat.get("attacker_neutralized", false)),
		"saved session carries generation-bound tender hull, raider death, and attack clock"
	)
	var legacy_payload := store.get_snapshot().duplicate(true)
	var legacy_record := legacy_payload[String(SLOT)] as Dictionary
	var legacy_activity := (legacy_record.activities as Array)[0] as Dictionary
	var legacy_progress := legacy_activity.progress as Dictionary
	var legacy_state := legacy_progress.convoy_session_state as Dictionary
	legacy_state.erase("threat_state")
	legacy_state.schema_version = 1
	var legacy_store := Store.new(LEGACY_THREAT_STORE_PATH, filesystem) as UserDataStore
	legacy_store.load()
	legacy_store.commit(legacy_payload, legacy_store.get_generation(), "legacy-convoy-threat-fixture")
	await _retire_game(first)

	var restored_store := Store.new(THREAT_STORE_PATH, filesystem) as UserDataStore
	var second := await _make_game(restored_store)
	if second != null:
		var restored_threat := second.cinder_convoy_threat.get_snapshot()
		_check(
			bool((second.get_cinder_convoy_session_persistence_report().restore_status as Dictionary).get("accepted", false))
			and is_equal_approx(float(restored_threat.get("tender_health", 0.0)), float(neutralized.get("tender_health", -1.0)))
			and is_zero_approx(float(restored_threat.get("attacker_health", 35.0)))
			and is_equal_approx(float(second.cinder_convoy_threat.capture_persistence_state().get("attack_clock", INF)), float(saved_threat.get("attack_clock", -INF)))
			and second.get_combat_authority().get_source_id(second.cinder_convoy_threat.get_attacker()) == 0,
			"fresh Main restores the wounded tender and neutralized raider without a new source"
		)
		await _retire_game(second)

	var legacy := await _make_game(legacy_store)
	if legacy != null:
		var legacy_threat := legacy.cinder_convoy_threat.get_snapshot()
		_check(
			bool((legacy.get_cinder_convoy_session_persistence_report().restore_status as Dictionary).get("accepted", false))
			and is_equal_approx(float(legacy_threat.get("tender_health", 0.0)), 75.0)
			and is_equal_approx(float(legacy_threat.get("attacker_health", 0.0)), 35.0),
			"existing schema-one active saves migrate to a fresh escort threat"
		)
		await _retire_game(legacy)


func _exercise_checkpoint_radius_and_corruption_contract(
		filesystem: MemoryFilesystem
	) -> void:
	var store := Store.new(RADIUS_STORE_PATH, filesystem) as UserDataStore
	store.load()
	var host := CinderConvoyEscortHost.new()
	root.add_child(host)
	await process_frame
	var live_signals := _new_signal_counts()
	_connect_host_signal_counts(host, live_signals)
	var started := host.start(host.get_generation())
	var adapter := SessionPersistence.new() as CinderConvoySessionPersistence
	adapter.configure(store, SLOT)
	var zero_tick_state := host.capture_persistence_state()
	var zero_tick_save := adapter.save(
		host, &"torrent", "radius-live-zero-tick"
	)
	_check(
		bool(started.get("accepted", false))
			and bool(zero_tick_save.get("accepted", false))
			and int(zero_tick_state.physics_tick_count) == 0
			and int(zero_tick_state.sample_publication_count) == 0
			and not bool(zero_tick_state.has_escort_sample),
		"the exact live unsampled start state saves with every runtime clock at zero"
	)

	# Regression for the rejected 1 mm replay alias. A real radius-only turn just
	# 0.5 mm before checkpoint 1 followed by one metre on the next leg has the
	# same coarse replay position as a centered witness, but both categories now
	# publish exactly twice per tick. Raising both ledgers from 4 to 5 must fail
	# independently of positional tolerance.
	var threshold_host := CinderConvoyEscortHost.new()
	root.add_child(threshold_host)
	await process_frame
	var threshold_started := threshold_host.start(threshold_host.get_generation())
	var threshold_checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(1)
	var threshold_turn := _advance_host_travel(
		threshold_host,
		(threshold_host.get_snapshot().entity_position as Vector3).distance_to(
			threshold_checkpoint
		) - 0.0005
	)
	var threshold_turn_state := threshold_host.capture_persistence_state()
	var threshold_after := _advance_host_travel(threshold_host, 1.0)
	var threshold_state := threshold_host.capture_persistence_state()
	var threshold_forged := threshold_state.duplicate(true)
	threshold_forged.sample_publication_count = 5
	(threshold_forged.activity_state as Dictionary).sample_count = 5
	var threshold_validation := threshold_host.validate_persistence_state(
		threshold_state
	)
	var threshold_forged_validation := threshold_host.validate_persistence_state(
		threshold_forged
	)
	_check(
		bool(threshold_started.get("accepted", false))
			and bool(threshold_turn.get("accepted", false))
			and bool(threshold_after.get("accepted", false))
			and _decoded_position(threshold_turn_state.entity_position).distance_to(
				threshold_checkpoint
			) > CinderConvoyEscortHost.ROUTE_CENTER_REACH_TOLERANCE
			and _decoded_position(threshold_turn_state.entity_position).distance_to(
				threshold_checkpoint
			) < CinderConvoyEscortHost.ROUTE_REPLAY_POSITION_TOLERANCE
			and int(threshold_state.physics_tick_count) == 2
			and int(threshold_state.sample_publication_count) == 4
			and int((threshold_state.activity_state as Dictionary).sample_count) == 4
			and int(threshold_state.next_route_index) == 2
			and bool(threshold_validation.get("accepted", false))
			and not bool(threshold_forged_validation.get("accepted", true)),
		"the 0.5 mm radius-only replay cannot forge both publication ledgers 4 to 5"
	)

	# A caller tick whose commanded travel crosses two checkpoint radii may
	# publish only its first transition and must retain the surplus. The next
	# transition consumes the next closing publication; rewriting the aggregate
	# as one tick and its otherwise exact two samples cannot collapse them.
	var multi_host := CinderConvoyEscortHost.new()
	root.add_child(multi_host)
	await process_frame
	var multi_started := multi_host.start(multi_host.get_generation())
	var first_checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(1)
	var second_checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(2)
	var multi_first := _advance_host_travel(
		multi_host,
		(multi_host.get_snapshot().entity_position as Vector3).distance_to(first_checkpoint)
		+ first_checkpoint.distance_to(second_checkpoint)
		- CinderConvoyEscortHost.ROUTE.checkpoint_radius * 0.5
	)
	var multi_first_state := multi_host.capture_persistence_state()
	var multi_second := _advance_host_travel(multi_host, 0.01)
	var multi_state := multi_host.capture_persistence_state()
	var multi_transition_forged := multi_state.duplicate(true)
	multi_transition_forged.physics_tick_count = 1
	multi_transition_forged.sample_publication_count = 2
	(multi_transition_forged.activity_state as Dictionary).sample_count = 2
	var multi_validation := multi_host.validate_persistence_state(multi_state)
	var multi_forged_validation := multi_host.validate_persistence_state(
		multi_transition_forged
	)
	_check(
		bool(multi_started.get("accepted", false))
			and bool(multi_first.get("accepted", false))
			and int(multi_first_state.physics_tick_count) == 1
			and int(multi_first_state.next_route_index) == 2
			and float(multi_first_state.movement_backlog) > 0.0
			and bool(multi_second.get("accepted", false))
			and int(multi_state.physics_tick_count) == 2
			and int(multi_state.sample_publication_count) == 4
			and int(multi_state.next_route_index) == 3
			and bool(multi_validation.get("accepted", false))
			and not bool(multi_forged_validation.get("accepted", true)),
		"two ordered route transitions cannot collapse into one physics tick"
	)

	# Once two centered closing transitions have consumed two caller ticks, even
	# 0.5 mm of positive movement along the following leg consumes a third. The
	# position tolerance may accept its geometric witness, but rewriting both
	# publication ledgers from 6 to 4 must not erase that third physics tick.
	var following_host := CinderConvoyEscortHost.new()
	root.add_child(following_host)
	await process_frame
	var following_started := following_host.start(following_host.get_generation())
	var following_first_center := _advance_host_travel(
		following_host,
		(following_host.get_snapshot().entity_position as Vector3).distance_to(
			first_checkpoint
		)
	)
	var following_second_center := _advance_host_travel(
		following_host,
		(following_host.get_snapshot().entity_position as Vector3).distance_to(
			second_checkpoint
		)
	)
	var following_motion := _advance_host_travel(following_host, 0.0005)
	var following_state := following_host.capture_persistence_state()
	var following_forged := following_state.duplicate(true)
	following_forged.physics_tick_count = 2
	following_forged.sample_publication_count = 4
	(following_forged.activity_state as Dictionary).sample_count = 4
	var following_validation := following_host.validate_persistence_state(
		following_state
	)
	var following_forged_validation := following_host.validate_persistence_state(
		following_forged
	)
	_check(
		bool(following_started.get("accepted", false))
			and bool(following_first_center.get("accepted", false))
			and bool(following_second_center.get("accepted", false))
			and bool(following_motion.get("accepted", false))
			and int(following_state.physics_tick_count) == 3
			and int(following_state.sample_publication_count) == 6
			and int((following_state.activity_state as Dictionary).sample_count) == 6
			and int(following_state.next_route_index) == 3
			and _decoded_position(following_state.entity_position).distance_to(
				second_checkpoint
			) > 0.0
			and _decoded_position(following_state.entity_position).distance_to(
				second_checkpoint
			) < CinderConvoyEscortHost.ROUTE_REPLAY_POSITION_TOLERANCE
			and bool(following_validation.get("accepted", false))
			and not bool(following_forged_validation.get("accepted", true)),
		"0.5 mm following movement cannot collapse a three-tick history to two"
	)

	var live_saves: Array[Dictionary] = []
	var checkpoint_states: Array[Dictionary] = []
	var first_motion := _advance_host_travel(host, 1.0)
	live_saves.append(adapter.save(host, &"torrent", "radius-live-after-checkpoint-0"))
	for checkpoint_index in [1, 2]:
		var checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(
			checkpoint_index
		)
		var before_travel := (
			(host.get_snapshot().entity_position as Vector3).distance_to(checkpoint)
			- CinderConvoyEscortHost.ROUTE.checkpoint_radius - 0.25
		)
		var before_advance := _advance_host_travel(host, before_travel)
		var before_state := host.capture_persistence_state()
		live_saves.append(adapter.save(
			host, &"torrent", "radius-live-before-checkpoint-%d" % checkpoint_index
		))
		var into_radius := (
			(host.get_snapshot().entity_position as Vector3).distance_to(checkpoint)
			- CinderConvoyEscortHost.ROUTE.checkpoint_radius
		)
		var boundary_advance := _advance_host_travel(host, into_radius)
		if int(host.get_snapshot().next_route_index) == checkpoint_index:
			boundary_advance = _advance_host_travel(host, 0.01)
		var inside_state := host.capture_persistence_state()
		checkpoint_states.append(inside_state.duplicate(true))
		live_saves.append(adapter.save(
			host, &"torrent", "radius-live-inside-checkpoint-%d" % checkpoint_index
		))
		var after_advance := _advance_host_travel(host, 1.0)
		var after_state := host.capture_persistence_state()
		live_saves.append(adapter.save(
			host, &"torrent", "radius-live-after-checkpoint-%d" % checkpoint_index
		))
		_check(
			bool(before_advance.get("accepted", false))
				and bool(boundary_advance.get("accepted", false))
				and bool(after_advance.get("accepted", false))
				and int(before_state.next_route_index) == checkpoint_index
				and (_decoded_position(inside_state.entity_position)
					.distance_to(checkpoint)
					<= CinderConvoyEscortHost.ROUTE.checkpoint_radius)
				and int(inside_state.next_route_index) == checkpoint_index + 1
				and int(after_state.next_route_index) == checkpoint_index + 1
				and _decoded_position(after_state.entity_position).distance_to(
					_decoded_position(inside_state.entity_position)
				) > 0.0,
			"checkpoint %d saves immediately before, inside, and after its inclusive 4 m radius"
				% checkpoint_index
		)
	_check(
		bool(first_motion.get("accepted", false))
			and live_saves.all(func(result: Dictionary) -> bool:
				return bool(result.get("accepted", false))),
		"every exact live radius transition and shortcut movement state is accepted"
	)

	# Centered and radius-only turns now share one deterministic closing sample.
	# Exercise both intermediate centers and the active far-escort final center so
	# neither geometric category can change the exact two-publications-per-tick
	# ledger or collapse more than one ordered transition into a caller tick.
	var centered_store := Store.new(CENTERED_STORE_PATH, filesystem) as UserDataStore
	centered_store.load()
	var centered_host := CinderConvoyEscortHost.new()
	root.add_child(centered_host)
	await process_frame
	var centered_started := centered_host.start(centered_host.get_generation())
	var centered_adapter := SessionPersistence.new() as CinderConvoySessionPersistence
	centered_adapter.configure(centered_store, SLOT)
	var centered_advances: Array[Dictionary] = []
	var centered_saves: Array[Dictionary] = []
	for checkpoint_index in [1, 2]:
		var checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(
			checkpoint_index
		)
		centered_advances.append(_advance_host_travel(
			centered_host,
			(centered_host.get_snapshot().entity_position as Vector3).distance_to(
				checkpoint
			) - CinderConvoyEscortHost.ROUTE_CENTER_REACH_TOLERANCE * 0.5
		))
		var centered_state := centered_host.capture_persistence_state()
		centered_saves.append(centered_adapter.save(
			centered_host,
			&"torrent",
			"centered-checkpoint-%d" % checkpoint_index
		))
		_check(
			_decoded_position(centered_state.entity_position).is_equal_approx(checkpoint)
				and int(centered_state.next_route_index) == checkpoint_index + 1
			and int(centered_state.sample_publication_count)
			== int(centered_state.physics_tick_count) * 2,
			"checkpoint %d center hit uses the deterministic closing publication"
				% checkpoint_index
		)
	var centered_final_checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(3)
	var centered_final_advance := _advance_host_travel(
		centered_host,
		(centered_host.get_snapshot().entity_position as Vector3).distance_to(
			centered_final_checkpoint
		) - CinderConvoyEscortHost.ROUTE_CENTER_REACH_TOLERANCE * 0.5
	)
	var centered_final_state := centered_host.capture_persistence_state()
	var centered_final_save := centered_adapter.save(
		centered_host, &"torrent", "centered-final-checkpoint"
	)
	centered_saves.append(centered_final_save)
	var centered_restore_host := CinderConvoyEscortHost.new()
	root.add_child(centered_restore_host)
	await process_frame
	var centered_restore_signals := _new_signal_counts()
	_connect_host_signal_counts(centered_restore_host, centered_restore_signals)
	var centered_loaded := centered_adapter.load(centered_restore_host)
	var centered_restored := centered_restore_host.restore_persistence_state(
		(centered_loaded.get("session_state", {}) as Dictionary).get("host_state", {}),
		centered_restore_host.get_generation()
	) if bool(centered_loaded.get("accepted", false)) else {"accepted": false}
	_check(
		bool(centered_started.get("accepted", false))
			and centered_advances.all(func(result: Dictionary) -> bool:
				return bool(result.get("accepted", false)))
			and centered_saves.all(func(result: Dictionary) -> bool:
				return bool(result.get("accepted", false)))
			and bool(centered_final_advance.get("accepted", false))
			and int(centered_final_state.next_route_index) == 3
			and _decoded_position(centered_final_state.entity_position).is_equal_approx(
				centered_final_checkpoint
			)
			and int(centered_final_state.sample_publication_count)
			== int(centered_final_state.physics_tick_count) * 2
			and bool(centered_restored.get("accepted", false))
			and _canonical(centered_restore_host.capture_persistence_state())
			== _canonical(centered_final_state)
			and _signal_total(centered_restore_signals) == 0,
		"centered intermediate and final states save, then final-center state restores signal-free"
	)

	var final_checkpoint := CinderConvoyEscortHost.ROUTE.get_checkpoint_position(3)
	var final_before_travel := (
		(host.get_snapshot().entity_position as Vector3).distance_to(final_checkpoint)
		- CinderConvoyEscortHost.ROUTE.checkpoint_radius - 0.25
	)
	var final_before := _advance_host_travel(host, final_before_travel)
	var final_before_save := adapter.save(
		host, &"torrent", "radius-live-before-final-checkpoint"
	)
	var final_into_radius := (
		(host.get_snapshot().entity_position as Vector3).distance_to(final_checkpoint)
		- CinderConvoyEscortHost.ROUTE.checkpoint_radius + 0.001
	)
	var far_escort := (host.get_snapshot().entity_position as Vector3) + Vector3(100.0, 0.0, 0.0)
	var final_inside := host.advance_physics(
		final_into_radius / float(host.get_snapshot().movement_speed),
		far_escort,
		host.get_generation()
	)
	var final_inside_state := host.capture_persistence_state()
	var final_inside_save := adapter.save(
		host, &"torrent", "radius-live-inside-final-checkpoint"
	)
	_check(
		bool(final_before.get("accepted", false))
			and bool(final_before_save.get("accepted", false))
			and bool(final_inside.get("accepted", false))
			and bool(final_inside_save.get("accepted", false))
			and int(final_inside_state.next_route_index) == 3
			and _decoded_position(final_inside_state.entity_position).distance_to(
				final_checkpoint
			) <= CinderConvoyEscortHost.ROUTE.checkpoint_radius
			and float((final_inside_state.activity_state as Dictionary).escort_distance)
			> float((final_inside_state.activity_state as Dictionary)
				.configured_escort_proximity_radius),
		"the active final-leg waiting state saves before and inside the same inclusive radius"
	)

	var live_session := _stored_session_state(store)
	var corrupt_sessions: Array[Dictionary] = []
	var threshold_count_corruption := live_session.duplicate(true)
	threshold_count_corruption.host_state = threshold_forged.duplicate(true)
	corrupt_sessions.append(threshold_count_corruption)
	var collapsed_transition_corruption := live_session.duplicate(true)
	collapsed_transition_corruption.host_state = multi_transition_forged.duplicate(true)
	corrupt_sessions.append(collapsed_transition_corruption)
	var collapsed_following_corruption := live_session.duplicate(true)
	collapsed_following_corruption.host_state = following_forged.duplicate(true)
	corrupt_sessions.append(collapsed_following_corruption)
	var wrong_nested_convoy := live_session.duplicate(true)
	(((wrong_nested_convoy.host_state as Dictionary).activity_state) as Dictionary).convoy_id = (
		"forged_supply_tender"
	)
	corrupt_sessions.append(wrong_nested_convoy)
	var forged_host_route := live_session.duplicate(true)
	(forged_host_route.host_state as Dictionary).route_resource_path = (
		"res://assets/activities/forged_convoy_route.tres"
	)
	corrupt_sessions.append(forged_host_route)
	var forged_activity_route := live_session.duplicate(true)
	(((forged_activity_route.host_state as Dictionary).activity_state) as Dictionary).activity_id = (
		"forged_convoy_activity"
	)
	corrupt_sessions.append(forged_activity_route)
	var forged_terminal := live_session.duplicate(true)
	var forged_terminal_activity := (
		(forged_terminal.host_state as Dictionary).activity_state as Dictionary
	)
	forged_terminal_activity.state = ConvoyEscortActivity.State.COMPLETED
	forged_terminal_activity.terminal_result = (
		ConvoyEscortActivity.TerminalResult.SAFELY_ARRIVED
	)
	forged_terminal_activity.terminal_reason = "safely_arrived"
	corrupt_sessions.append(forged_terminal)
	var separation_after_elapsed := live_session.duplicate(true)
	var separation_activity := (
		(separation_after_elapsed.host_state as Dictionary).activity_state as Dictionary
	)
	separation_activity.separation_elapsed_seconds = (
		float(separation_activity.elapsed_seconds) + 0.25
	)
	corrupt_sessions.append(separation_after_elapsed)
	var forged_movement := live_session.duplicate(true)
	(forged_movement.host_state as Dictionary).movement_distance = (
		float((forged_movement.host_state as Dictionary).movement_distance) + 1.0
	)
	corrupt_sessions.append(forged_movement)
	var forged_publications := live_session.duplicate(true)
	var forged_publication_host := forged_publications.host_state as Dictionary
	forged_publication_host.sample_publication_count = (
		int(forged_publication_host.physics_tick_count) * 2 - 1
	)
	(forged_publication_host.activity_state as Dictionary).sample_count = (
		forged_publication_host.sample_publication_count
	)
	corrupt_sessions.append(forged_publications)
	var non_numeric_movement := live_session.duplicate(true)
	(non_numeric_movement.host_state as Dictionary).movement_distance = "not-a-number"
	corrupt_sessions.append(non_numeric_movement)

	for positive_field in ["elapsed_seconds", "separation_elapsed_seconds"]:
		var forged_zero_tick := live_session.duplicate(true)
		forged_zero_tick.host_state = zero_tick_state.duplicate(true)
		((forged_zero_tick.host_state as Dictionary).activity_state as Dictionary)[
			positive_field
		] = 0.25
		if positive_field == "separation_elapsed_seconds":
			((forged_zero_tick.host_state as Dictionary).activity_state as Dictionary).elapsed_seconds = 0.25
		corrupt_sessions.append(forged_zero_tick)
	var zero_tick_movement := live_session.duplicate(true)
	zero_tick_movement.host_state = zero_tick_state.duplicate(true)
	(zero_tick_movement.host_state as Dictionary).movement_distance = 0.25
	corrupt_sessions.append(zero_tick_movement)
	var zero_tick_samples := live_session.duplicate(true)
	zero_tick_samples.host_state = zero_tick_state.duplicate(true)
	(zero_tick_samples.host_state as Dictionary).sample_publication_count = 1
	((zero_tick_samples.host_state as Dictionary).activity_state as Dictionary).sample_count = 1
	corrupt_sessions.append(zero_tick_samples)

	var first_shortcut := checkpoint_states[0].duplicate(true)
	var forged_shortcut_publication := live_session.duplicate(true)
	forged_shortcut_publication.host_state = first_shortcut.duplicate(true)
	var forged_shortcut_host := forged_shortcut_publication.host_state as Dictionary
	forged_shortcut_host.sample_publication_count = (
		int(forged_shortcut_host.sample_publication_count) + 1
	)
	(forged_shortcut_host.activity_state as Dictionary).sample_count = (
		forged_shortcut_host.sample_publication_count
	)
	corrupt_sessions.append(forged_shortcut_publication)
	for forged_index in [1, 3]:
		var forged_progress := live_session.duplicate(true)
		forged_progress.host_state = first_shortcut.duplicate(true)
		(forged_progress.host_state as Dictionary).next_route_index = forged_index
		((forged_progress.host_state as Dictionary).activity_state as Dictionary).next_leg_index = (
			forged_index
		)
		corrupt_sessions.append(forged_progress)

	var store_generation_before := store.get_generation()
	var store_snapshot_before := store.get_snapshot()
	var live_signals_before := live_signals.duplicate(true)
	var save_rejections: Array[Dictionary] = []
	for case_index in corrupt_sessions.size():
		save_rejections.append(adapter.save_state(
			corrupt_sessions[case_index],
			host,
			&"torrent",
			"radius-corruption-rejected-%d" % case_index
		))

	var pristine := CinderConvoyEscortHost.new()
	root.add_child(pristine)
	await process_frame
	var pristine_signals := _new_signal_counts()
	_connect_host_signal_counts(pristine, pristine_signals)
	var pristine_before := pristine.capture_persistence_state()
	var adoption_rejections: Array[Dictionary] = []
	for corrupt_session in corrupt_sessions:
		adoption_rejections.append(pristine.restore_persistence_state(
			corrupt_session.host_state,
			pristine.get_generation()
		))
	var non_finite_host_state := final_inside_state.duplicate(true)
	non_finite_host_state.movement_distance = NAN
	adoption_rejections.append(pristine.restore_persistence_state(
		non_finite_host_state,
		pristine.get_generation()
	))
	_check(
		save_rejections.all(func(result: Dictionary) -> bool:
				return not bool(result.get("accepted", true)))
			and adoption_rejections.all(func(result: Dictionary) -> bool:
				return not bool(result.get("accepted", true)))
			and store.get_generation() == store_generation_before
			and store.get_snapshot() == store_snapshot_before
			and live_signals == live_signals_before
			and pristine.capture_persistence_state() == pristine_before
			and _signal_total(pristine_signals) == 0,
		"identity, terminal, route, clock, movement, tick, sample, and finite corruptions write, signal, and adopt nothing"
	)

	var restore_adapter := SessionPersistence.new() as CinderConvoySessionPersistence
	restore_adapter.configure(store, SLOT)
	var loaded := restore_adapter.load(pristine)
	var restored := pristine.restore_persistence_state(
		(loaded.get("session_state", {}) as Dictionary).get("host_state", {}),
		pristine.get_generation()
	) if bool(loaded.get("accepted", false)) else {"accepted": false}
	_check(
		bool(loaded.get("accepted", false))
			and bool(restored.get("accepted", false))
			and _canonical(pristine.capture_persistence_state())
			== _canonical(final_inside_state)
			and store.get_generation() == store_generation_before
			and _signal_total(pristine_signals) == 0,
		"the final exact live shortcut state round-trips into a pristine host without signals or store mutation"
	)
	var opening := centered_restore_host.advance_physics(0.25,
		centered_restore_host.get_snapshot().entity_position as Vector3, centered_restore_host.get_generation())
	var opening_state := centered_restore_host.capture_persistence_state()
	var opening_saved := centered_adapter.save(centered_restore_host, &"torrent", "actual-opening-arrival")
	var terminal_host := CinderConvoyEscortHost.new()
	root.add_child(terminal_host)
	var terminal_signals := _new_signal_counts()
	_connect_host_signal_counts(terminal_host, terminal_signals)
	var terminal_loaded := centered_adapter.load(terminal_host)
	var terminal_restored := terminal_host.restore_persistence_state(
		(terminal_loaded.get("session_state", {}) as Dictionary).get("host_state", {}), terminal_host.get_generation())
	_check(bool(opening.accepted) and bool(opening_saved.accepted) and bool(terminal_restored.accepted)
		and int(opening_state.sample_publication_count) == int(opening_state.physics_tick_count) * 2 + 1
		and _canonical(terminal_host.capture_persistence_state()) == _canonical(opening_state)
		and _signal_total(terminal_signals) == 0,
		"actual final waiting-point escort return restores its opening-sample safe terminal without replay")
	var bad_terminal := opening_state.duplicate(true)
	bad_terminal.sample_publication_count = int(bad_terminal.sample_publication_count) + 1
	bad_terminal.activity_state.sample_count = bad_terminal.sample_publication_count
	_check(not bool(terminal_host.validate_persistence_state(bad_terminal).get("accepted", true)),
		"terminal admission rejects publications beyond the actual opening or closing boundary")
	terminal_host.queue_free()
	host.queue_free()
	threshold_host.queue_free()
	multi_host.queue_free()
	following_host.queue_free()
	pristine.queue_free()
	centered_host.queue_free()
	centered_restore_host.queue_free()
	for _frame in 3:
		await process_frame


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


func _new_signal_counts() -> Dictionary:
	return {
		"started": 0,
		"advanced": 0,
		"arrived": 0,
		"failed": 0,
		"reset": 0,
		"presentation": 0,
	}


func _signal_total(counts: Dictionary) -> int:
	return int(counts.started) + int(counts.advanced) + int(counts.arrived) \
		+ int(counts.failed) + int(counts.reset) + int(counts.presentation)


func _advance_host_travel(
		host: CinderConvoyEscortHost,
		travel_distance: float
	) -> Dictionary:
	if travel_distance <= 0.0:
		return {"accepted": false, "reason": &"invalid_test_travel"}
	var snapshot := host.get_snapshot()
	return host.advance_physics(
		travel_distance / float(snapshot.movement_speed),
		snapshot.entity_position as Vector3,
		host.get_generation()
	)


func _decoded_position(encoded: Dictionary) -> Vector3:
	return Vector3(float(encoded.x), float(encoded.y), float(encoded.z))


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
