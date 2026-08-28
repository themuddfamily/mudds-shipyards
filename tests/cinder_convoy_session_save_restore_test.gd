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
