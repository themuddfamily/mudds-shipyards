extends SceneTree

## Production checkpoint/reward transactions on real disk, with independent
## fresh Main owners. Approach samples are positioned; this is not a flight journey.
const Main := preload("res://scenes/main.tscn")
const Scan := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")
const RecoveryFixture := preload("res://tests/game_flow_session_recovery_hud_integration_test.gd")

class FaultFilesystem extends UserDataFilesystem:
	var reject_rewards := true
	var reject_all := false
	var reject_discovery := false
	var refused_discovery := false
	var freeze_on_reward := false
	var refused_reward := false
	var fail_published_reward_sync := false
	var _reward_just_published := false
	var refused_write_attempts := 0

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_all:
			refused_write_attempts += 1
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_discovery and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("cinder-scan-discovery-"):
			refused_discovery = true
			return ERR_UNAVAILABLE
		if reject_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			refused_reward = true
			if freeze_on_reward:
				reject_all = true
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if reject_all else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		if reject_all:
			return ERR_UNAVAILABLE
		var reward := false
		if from_path.ends_with(".tmp"):
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(from_path))
			reward = document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-")
		var result := super.rename_path(from_path, to_path)
		if result == OK and reward:
			_reward_just_published = true
		return result

	func sync_directory(path: String) -> Error:
		if _reward_just_published and fail_published_reward_sync:
			fail_published_reward_sync = false
			_reward_just_published = false
			return ERR_UNAVAILABLE
		return super.sync_directory(path)

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Bounded backup recovery coverage owns the same original route deadlines;
	# the default suite keeps all of its existing recovery coverage unchanged.
	if OS.get_cmdline_user_args().has("--scan-backup-trust-only"):
		await _backup_trust_reproduction()
		_finish()
		return
	await _progress_recovery()
	await _start_fresh_active()
	await _legacy_discovery_compatibility()
	var path := "user://scan_durable_%d.json" % Time.get_ticks_usec()
	var first_fs := FaultFilesystem.new()
	first_fs.freeze_on_reward = true
	var first := await _game(path, first_fs)
	await _board(first)
	var binding := await _binding(first)
	first.call("_on_settings_save_requested")
	var settings_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings
	await _complete(first, binding)
	var completed := binding.get_activity_snapshot(&"structure_scan")
	var generation := int(completed.generation)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var terminal: Dictionary = document.payload.get("cinder_structure_scan_session", {})
	_check(first_fs.refused_reward and completed.state_id == &"complete" and _receipts(first) == 0,
		"the actual production timed scan completes while the real reward write is rejected")
	_check(not terminal.is_empty() and CinderAbandonedStructureScanActivity.validate_persistence_record(terminal).accepted
		and terminal.activities[0].reward_requested and not terminal.activities[0].reward_granted,
		"the successful checkpoint leaves a valid unpaid terminal on real disk before reward publication")
	await _dispose(first)
	var second_fs := FaultFilesystem.new()
	var second := await _game(path, second_fs)
	var second_binding := await _binding(second)
	var restored := second_binding.get_activity_snapshot(&"structure_scan")
	_check(restored.state_id == &"complete" and int(restored.generation) == generation
		and restored.elapsed_seconds == Scan.SCAN_SECONDS and restored.reward_pending and _receipts(second) == 0,
		"fresh Main restores the exact genuine unpaid completion and visible pending handoff")
	var unpaid_store: UserDataStore = second.get("_runtime_settings_user_data_store")
	var unpaid_before: Dictionary = unpaid_store.get_snapshot()
	var unpaid_choice: Dictionary = await _press_start_fresh(second)
	_check(unpaid_choice.get("accepted", false)
		and unpaid_store.get_snapshot().cinder_structure_scan_session == unpaid_before.cinder_structure_scan_session
		and second_binding.get_activity_snapshot(&"structure_scan").state_id == &"complete"
		and _receipts(second) == 0,
		"actual Start Fresh preserves the genuine completed-unpaid scan for its ordinary retry")
	_button(second, 3).emit_signal("pressed")
	if _button(second, 3).text == "CONFIRM RESET":
		_button(second, 3).emit_signal("pressed")
	_button(second, 2).emit_signal("pressed")
	_check(second_binding.get_activity_snapshot(&"structure_scan").state_id == &"complete"
		and second_fs.refused_reward and _receipts(second) == 0,
		"ordinary Reset cannot erase recovered debt and Start retries it while storage refuses")
	second_fs.reject_rewards = false
	_button(second, 2).emit_signal("pressed")
	var paid := second_binding.get_activity_snapshot(&"structure_scan")
	_check(paid.reward_requested and paid.reward_committed and not paid.reward_pending and _receipts(second) == 1,
		"ordinary Start commits one receipt and the terminal payment acknowledgement atomically")
	await _dispose(second)
	var third := await _game(path, UserDataFilesystem.new())
	var third_binding := await _binding(third)
	var paid_restore := third_binding.get_activity_snapshot(&"structure_scan")
	_check(paid_restore.reward_requested and paid_restore.reward_committed and paid_restore.discovery_persisted and _receipts(third) == 1,
		"another fresh Main restores paid completion with legacy discovery presentation and without a second entitlement")
	var paid_store: UserDataStore = third.get("_runtime_settings_user_data_store")
	var paid_before: Dictionary = paid_store.get_snapshot()
	var paid_choice: Dictionary = await _press_start_fresh(third)
	_check(paid_choice.get("accepted", false) and paid_store.get_snapshot() == paid_before
		and third_binding.get_activity_snapshot(&"structure_scan").discovery_persisted
		and _receipts(third) == 1,
		"actual Start Fresh leaves the paid scan, discovery and reward ledger unchanged")
	var duplicate := third_binding.request_structure_scan_reward()
	_check(not duplicate.accepted and _receipts(third) == 1, "the recovered paid scan terminal never pays twice")
	_check(JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings == settings_before,
		"scan recovery, checkpoints and first payment preserve the actual earlier disk settings namespace")
	_button(third, 3).emit_signal("pressed")
	_check(third_binding.get_activity_snapshot(&"structure_scan").state_id == &"reset" and _receipts(third) == 1,
		"ordinary paid Reset persists its genuine reset boundary before Main exits")
	await _dispose(third)
	var fourth := await _game(path, UserDataFilesystem.new())
	var fourth_binding := await _binding(fourth)
	var reset_restore := fourth_binding.get_activity_snapshot(&"structure_scan")
	_check(reset_restore.state_id == &"reset" and int(reset_restore.generation) == generation
		and reset_restore.elapsed_seconds == 0.0 and not reset_restore.reward_requested and _receipts(fourth) == 1,
		"fresh Main restores the exact paid-reset generation without inheriting an owed terminal")
	# Boot's existing safe-start owner can legitimately persist its recommended
	# graphics after repeated unclean lifetimes. Scan transactions must preserve
	# the actual namespace handed to them after that existing owner has run.
	var settings_next_baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings
	var cold_changes: Dictionary = {}
	for key in settings_before.values:
		if settings_before.values[key] != settings_next_baseline.values[key]:
			cold_changes[key] = {"before": settings_before.values[key], "after": settings_next_baseline.values[key]}
	print("SCAN_COLD_START_SETTINGS_CHANGE: ", JSON.stringify(cold_changes))
	await _board(fourth)
	await _complete(fourth, fourth_binding)
	var next_paid := fourth_binding.get_activity_snapshot(&"structure_scan")
	_check(next_paid.state_id == &"complete" and int(next_paid.generation) == generation + 1
		and next_paid.reward_committed and _receipts(fourth) == 2,
		"ordinary Start after fresh reset completes and pays the distinct next generation once")
	var stale: Dictionary = fourth.call("_commit_game_flow_activity_reward", {
		"activity_id": Scan.ACTIVITY_ID, "activity_generation": generation,
		"reward_id": Scan.REWARD_ID, "reward_authority": false, "granted": false,
	})
	_check(not stale.accepted and stale.reason == &"reward_generation_mismatch" and _receipts(fourth) == 2,
		"the existing reward owner rejects the earlier completion against the next saved generation")
	var fourth_store: UserDataStore = fourth.get("_runtime_settings_user_data_store")
	_check(fourth_store.get_snapshot().runtime_settings == settings_next_baseline
		and JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings == settings_next_baseline,
		"scan checkpoints and receipts preserve the actual pretransaction disk settings namespace")
	await _dispose(fourth)
	var fifth := await _game(path, UserDataFilesystem.new())
	var fifth_binding := await _binding(fifth)
	var next_restore := fifth_binding.get_activity_snapshot(&"structure_scan")
	var next_duplicate := fifth_binding.request_structure_scan_reward()
	_check(next_restore.state_id == &"complete" and int(next_restore.generation) == generation + 1
		and next_restore.reward_committed and not next_duplicate.accepted and _receipts(fifth) == 2,
		"another fresh Main restores the next paid generation and refuses its duplicate handoff")
	await _dispose(fifth)
	await _published_payment_retry()
	await _all_writes_failed()
	await _unsupported_record(path)
	_finish()

func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("GAME_FLOW_SCAN_DURABLE_RECOVERY_TEST_OK: %d assertions" % _checks)
	quit(0 if _failures.is_empty() else 1)

## One real paid scan leaves its unpaid predecessor in the atomic backup when
## discovery publication is refused. Both probes use those genuine documents;
## no progress, reward acknowledgement or ledger is fabricated in the fixture.
func _backup_trust_reproduction() -> void:
	var path := "user://scan_backup_trust_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	fault.reject_discovery = true
	var retained := await _game(path, fault)
	await _board(retained)
	var binding := await _binding(retained)
	await _complete(retained, binding)
	var paid_bytes := FileAccess.get_file_as_bytes(path)
	var unpaid_bytes := FileAccess.get_file_as_bytes(path + ".bak")
	var paid_document: Variant = JSON.parse_string(paid_bytes.get_string_from_utf8())
	var unpaid_document: Variant = JSON.parse_string(unpaid_bytes.get_string_from_utf8())
	print("SCAN_BACKUP_FIXTURE_COMPLETION: ", retained.get_activity_reward_report())
	var documents_valid := paid_document is Dictionary and unpaid_document is Dictionary
	_check(documents_valid, "actual timed scan and payment publish readable primary and predecessor documents")
	if not documents_valid:
		await _dispose(retained)
		return
	var paid_record: Dictionary = paid_document.payload.get("cinder_structure_scan_session", {})
	var unpaid_record: Dictionary = unpaid_document.payload.get("cinder_structure_scan_session", {})
	var live := binding.get_activity_snapshot(&"structure_scan")
	print("SCAN_BACKUP_GENUINE_FIXTURE: ", {"live": live,
		"reward": retained.get_activity_reward_report().last_cinder_structure_scan_result,
		"paid_record": paid_record, "unpaid_record": unpaid_record})
	var valid: bool = (
		bool(Scan.validate_persistence_record(paid_record).accepted)
		and bool(Scan.validate_persistence_record(unpaid_record).accepted)
	)
	_check(valid, "backup trust fixture contains actual valid paid and unpaid timed-scan documents")
	if not valid:
		await _dispose(retained)
		return
	var paid_entry: Dictionary = paid_record.activities[0]
	var unpaid_entry: Dictionary = unpaid_record.activities[0]
	var generation := int(paid_entry.generation)
	_check(fault.refused_discovery and paid_entry.reward_granted and unpaid_entry.reward_requested
		and not unpaid_entry.reward_granted and int(unpaid_entry.generation) == generation
		and int(paid_document.payload.game_flow_reward_store.total_receipts) == 1
		and int((unpaid_document.payload.get("game_flow_reward_store", {}) as Dictionary).get("total_receipts", 0)) == 0
		and live.reward_committed and live.persistence_retry_available,
		"real payment followed by refused discovery leaves its genuine unpaid predecessor without a receipt")
	var corrupt := "corrupt newer paid Cinder scan primary".to_utf8_buffer()
	var staged := (
		_write_scan_fixture(path + ".paid-witness", paid_bytes)
		and _write_scan_fixture(path, corrupt)
	)
	_check(staged, "retained scan probe preserves the real paid witness and corrupts only its primary")
	if not staged:
		await _dispose(retained)
		return
	var preflight := UserDataStore.new(path)
	var selected := preflight.load()
	print("SCAN_BACKUP_PREFLIGHT: ", selected)
	_check(selected.accepted and preflight.get_loaded_source() == &"backup",
		"existing store selects the genuine unpaid fallback and quarantines the corrupt newer primary")
	var artifacts := _scan_recovery_artifacts(path)
	_check(artifacts.get(path + ".recovery") == corrupt,
		"scan backup diagnosis retains the exact corrupt-primary recovery witness")
	var before := binding.capture_structure_scan_session()
	fault.reject_discovery = false
	_button(retained, 2).emit_signal("pressed")
	_button(retained, 2).emit_signal("pressed")
	var retry := retained.get_activity_reward_report().last_cinder_structure_scan_result as Dictionary
	var shared: UserDataStore = retained.get("_runtime_settings_user_data_store")
	print("SCAN_BACKUP_RETAINED_START: ", {"last_reward_report": retry,
		"action_feedback": (retained.hud.get("_nearby_activity_feedback") as Label).text,
		"source": shared.get_loaded_source(), "store_generation": shared.get_generation(),
		"payload": shared.get_snapshot(), "scan": binding.get_activity_snapshot(&"structure_scan")})
	_check(not retry.get("discovery_persisted", false) and binding.capture_structure_scan_session() == before
		and binding.get_activity_snapshot(&"structure_scan").persistence_retry_available
		and shared.get_loaded_source() == &"backup" and _scan_recovery_artifacts(path) == artifacts,
		"ordinary retained Start cannot republish an older unpaid envelope through pending discovery retry")
	await _dispose(retained)
	_check(_scan_recovery_artifacts(path) == artifacts,
		"retained scan teardown preserves fallback, paid witness and quarantine for explicit repair")

	# This separate path starts from the same immutable genuine documents, so a
	# pre-fix retained retry cannot contaminate the fresh-owner authority probe.
	path += "_fresh"
	staged = (
		_write_scan_fixture(path + ".paid-witness", paid_bytes)
		and _write_scan_fixture(path, corrupt)
		and _write_scan_fixture(path + ".bak", unpaid_bytes)
	)
	_check(staged, "fresh scan probe retains the same genuine unpaid and newer paid documents")
	if not staged:
		return
	preflight = UserDataStore.new(path)
	selected = preflight.load()
	_check(selected.accepted and preflight.get_loaded_source() == &"backup",
		"fresh scan probe selects the older unpaid fallback through the actual store")
	artifacts = _scan_recovery_artifacts(path)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	var captured := fresh_binding.capture_structure_scan_session()
	var ready: Dictionary = fresh.call("_ensure_cinder_scan_session", fresh_binding)
	print("SCAN_BACKUP_FRESH_BIND: ", {"ready": ready, "captured": captured,
		"presentation": fresh_binding.get_activity_snapshot(&"structure_scan"),
		"discovery": fresh_binding.get_cinder_scan_discovery_persistence_snapshot()})
	var fresh_entry: Dictionary = captured.activities[0]
	_check(not ready.get("accepted", false) and ready.get("reason") == &"scan_session_store_recovery_required"
		and int(fresh_entry.generation) == 0 and int(fresh_entry.state) == Scan.State.IDLE,
		"fresh Main cannot adopt backup-derived scan progress, generation or unpaid entitlement")
	var receipts := _receipts(fresh)
	_button(fresh, 2).emit_signal("pressed")
	_button(fresh, 3).emit_signal("pressed")
	_check(fresh_binding.capture_structure_scan_session() == captured
		and _receipts(fresh) == receipts and _scan_recovery_artifacts(path) == artifacts,
		"ordinary fresh Start and Reset preserve the untrusted scan state and recovery artifacts")
	var authority: GameFlowRewardAuthority = fresh.get("_game_flow_reward_authority")
	var payment := authority.commit({"activity_id": Scan.ACTIVITY_ID,
		"activity_generation": generation, "reward_id": Scan.REWARD_ID,
		"reward_authority": false, "granted": false})
	var payment_retry := authority.commit({"activity_id": Scan.ACTIVITY_ID,
		"activity_generation": generation, "reward_id": Scan.REWARD_ID,
		"reward_authority": false, "granted": false})
	shared = fresh.get("_runtime_settings_user_data_store")
	print("SCAN_BACKUP_DIRECT_PAYMENT: ", {"payment": payment, "retry": payment_retry, "source": shared.get_loaded_source(),
		"payload": shared.get_snapshot(), "captured": fresh_binding.capture_structure_scan_session()})
	_check(not payment.accepted and payment.reason == &"reward_store_recovery_required"
		and not payment_retry.accepted and payment_retry.reason == &"reward_store_recovery_required"
		and _receipts(fresh) == receipts and shared.get_loaded_source() == &"backup"
		and fresh_binding.capture_structure_scan_session() == captured and _scan_recovery_artifacts(path) == artifacts,
		"actual scan authority refuses payment from the genuine unpaid fallback without publishing it")
	await _dispose(fresh)
	_check(_scan_recovery_artifacts(path) == artifacts,
		"fresh scan teardown preserves unpaid fallback and paid evidence for explicit repair")


func _write_scan_fixture(path: String, bytes: PackedByteArray) -> bool:
	var writer := FileAccess.open(path, FileAccess.WRITE)
	if writer == null:
		return false
	writer.store_buffer(bytes)
	writer.close()
	return true


func _scan_recovery_artifacts(path: String) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".bak.1", ".bak.2", ".bak.3", ".recovery", ".tmp", ".paid-witness"]:
		if FileAccess.file_exists(path + suffix):
			result[path + suffix] = FileAccess.get_file_as_bytes(path + suffix)
	return result


func _start_fresh_active() -> void:
	# Independent profile: the original Resume control below keeps its exact
	# original save and replay behavior. Only approach samples are staged.
	var path := "user://scan_start_fresh_%d.json" % Time.get_ticks_usec()
	var first := await _game(path, UserDataFilesystem.new())
	await _board(first)
	var binding := await _binding(first)
	first.active_ship.global_position = first.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(first, 2).pressed.emit()
	first.call("_advance_cinder_structure_scan", 1.5, first.call("_capture_cinder_actor_sample"))
	var progress: Dictionary = binding.get_activity_snapshot(&"structure_scan")
	_check(progress.state_id == &"active" and is_equal_approx(progress.elapsed_seconds, 1.5),
		"Start Fresh fixture earns its incomplete scan through ordinary HUD Start and production samples")
	var active_document := FileAccess.get_file_as_bytes(path)
	if progress.state_id != &"active":
		await _dispose(first)
		return
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	var fresh := await _game(path, fault)
	# These are independent cold owners sharing durable storage, not a shared
	# physical session. The retained writer must not supply the fresh floor.
	var floor_query := PhysicsRayQueryParameters3D.create(
		fresh.player.global_position + Vector3.UP,
		fresh.player.global_position - Vector3.UP * 3.0, 1)
	floor_query.collide_with_bodies = true
	floor_query.collide_with_areas = false
	var floor_hit := fresh.player.get_world_3d().direct_space_state.intersect_ray(floor_query)
	var floor_collider := floor_hit.get("collider") as Node
	_check(first.get_world_3d().space != fresh.get_world_3d().space
		and is_instance_valid(floor_collider) and fresh.is_ancestor_of(floor_collider),
		"overlapping retained and cold scan owners have independent worlds and the fresh player hits its own authored floor")
	var live := await _binding(fresh)
	var store: UserDataStore = fresh.get("_runtime_settings_user_data_store")
	var restored: Dictionary = live.get_activity_snapshot(&"structure_scan")
	_check(restored.state_id == &"active" and int(restored.generation) == int(progress.generation)
		and is_equal_approx(restored.elapsed_seconds, 1.5),
		"the actual cold owner restores the active scan before the Start Fresh decision")
	var button := _offer_start_fresh(fresh)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		await _dispose(fresh)
		await _dispose(first)
		return
	var snapshot: Dictionary = store.get_snapshot()
	var bytes := FileAccess.get_file_as_bytes(path)
	var generation := store.get_generation()
	var notice: Dictionary = fresh.hud.get_session_recovery_notice_snapshot()
	fault.reject_all = true
	button.pressed.emit()
	var failed: Dictionary = fresh.get("_session_recovery_hud_status")
	fault.reject_all = false
	var deadline := Time.get_ticks_msec() + 2_000
	while is_instance_valid(button) and button.disabled and Time.get_ticks_msec() < deadline:
		await process_frame
		await physics_frame
	var retry_notice: Dictionary = fresh.hud.get_session_recovery_notice_snapshot()
	var rearmed: bool = is_instance_valid(button) and not button.disabled and button.is_visible_in_tree() \
		and bool(retry_notice.get("active", false)) \
		and retry_notice.get("recovery_token") == notice.get("recovery_token") \
		and retry_notice.get("recovery_generation") == notice.get("recovery_generation")
	_check(not failed.get("accepted", false) and rearmed
		and store.get_generation() == generation and store.get_snapshot() == snapshot
		and FileAccess.get_file_as_bytes(path) == bytes
		and live.get_activity_snapshot(&"structure_scan") == restored,
		"refused actual Start Fresh leaves the same usable notice, live scan and exact durable progress")
	if not rearmed:
		await _dispose(fresh)
		await _dispose(first)
		return
	button.pressed.emit()
	await process_frame
	var choice: Dictionary = fresh.get("_session_recovery_hud_status")
	var reset: Dictionary = live.get_activity_snapshot(&"structure_scan")
	_check(choice.get("accepted", false) and reset.state_id == &"reset"
		and int(reset.generation) == int(progress.generation) and reset.elapsed_seconds == 0.0
		and not reset.reward_requested and _receipts(fresh) == 0
		and fresh.get_recovery_available_snapshot().is_empty(),
		"explicit same-button retry durably resets incomplete scan and consumes the recovery choice")
	var retained_payload: Dictionary = store.get_snapshot()
	for key: String in snapshot:
		if key != "cinder_structure_scan_session":
			_check(retained_payload.get(key) == snapshot[key], "scan abandonment preserves unrelated saved namespace: %s" % key)
	var reset_bytes := FileAccess.get_file_as_bytes(path)
	var stale_save: Dictionary = first.call("_save_cinder_scan_session", binding)
	_check(not stale_save.get("accepted", false)
		and binding.get_activity_snapshot(&"structure_scan").state_id == &"active"
		and live.get_activity_snapshot(&"structure_scan").state_id == &"reset"
		and FileAccess.get_file_as_bytes(path) == reset_bytes,
		"the retained old scan writer cannot resurrect same-generation ACTIVE progress over durable RESET")
	await _dispose(first)
	await _dispose(fresh)
	var second := await _game(path, UserDataFilesystem.new())
	var second_binding := await _binding(second)
	var second_reset: Dictionary = second_binding.get_activity_snapshot(&"structure_scan")
	_check(second_reset.state_id == &"reset" and second_reset.elapsed_seconds == 0.0
		and int(second_reset.generation) == int(progress.generation) and _receipts(second) == 0,
		"the first later cold Main cannot resurrect the declined scan timer")
	await _dispose(second)
	var third := await _game(path, UserDataFilesystem.new())
	var third_binding := await _binding(third)
	var third_reset: Dictionary = third_binding.get_activity_snapshot(&"structure_scan")
	_check(third_reset.state_id == &"reset" and third_reset.elapsed_seconds == 0.0
		and int(third_reset.generation) == int(progress.generation),
		"a second later cold Main still observes the durable reset boundary")
	await _board(third)
	third.active_ship.global_position = third.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(third, 2).pressed.emit()
	var next: Dictionary = third_binding.get_activity_snapshot(&"structure_scan")
	_check(next.state_id == &"active" and next.elapsed_seconds == 0.0
		and int(next.generation) == int(progress.generation) + 1 and _receipts(third) == 0,
		"ordinary Start admits exactly the next generation without inheriting declined progress or reward")
	await _dispose(third)
	await _start_fresh_without_binding(active_document, int(progress.generation))


func _start_fresh_without_binding(active_document: PackedByteArray, scan_generation: int) -> void:
	# Copy the genuine earlier ACTIVE disk image, including its checksum. This
	# branch exercises the title decision before Cinder has streamed any owner.
	var path := "user://scan_unloaded_start_fresh_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "the unloaded-world fixture opens its independent real-profile image")
	if file == null:
		return
	file.store_buffer(active_document)
	file.flush()
	file.close()
	var store := UserDataStore.new(path)
	var loaded: Dictionary = store.load()
	var bare := GameFlow.new()
	var authority := GameFlowRewardAuthority.new()
	var configured: Dictionary = authority.configure(store)
	var ready: bool = bool(loaded.get("accepted", false)) and bool(configured.get("accepted", false)) \
		and bare.configure_runtime_settings_persistence(store)
	bare.set("_game_flow_reward_authority", authority)
	_check(ready and bare.call("_get_nearby_activity_binding") == null,
		"the real stored ACTIVE scan is available to a bare recovery owner with no streamed binding")
	if not ready:
		bare.free()
		return
	var before: Dictionary = store.get_snapshot()
	var declined: Dictionary = bare.call("_decline_interrupted_planetary_visits")
	var after: Dictionary = store.get_snapshot()
	var record: Dictionary = after.get("cinder_structure_scan_session", {})
	_check(declined.get("accepted", false) and not record.is_empty()
		and int(record.activities[0].state) == Scan.State.RESET
		and int(record.activities[0].generation) == scan_generation
		and float(record.activities[0].progress.elapsed_seconds) == 0.0,
		"decline persists the same-generation RESET even when no nearby scan binding exists")
	for key: String in before:
		if key != "cinder_structure_scan_session":
			_check(after.get(key) == before[key], "unloaded scan decline preserves unrelated saved namespace: %s" % key)
	bare.free()
	var later := await _game(path, UserDataFilesystem.new())
	var binding := await _binding(later)
	var restored: Dictionary = binding.get_activity_snapshot(&"structure_scan")
	_check(restored.state_id == &"reset" and restored.elapsed_seconds == 0.0
		and int(restored.generation) == scan_generation and _receipts(later) == 0,
		"later actual Main streaming restores RESET instead of resurrecting the unloaded-world scan")
	await _dispose(later)


func _offer_start_fresh(game: GameFlow) -> Button:
	var bridge := RecoveryFixture.RecoveryBridgeProbe.new()
	bridge.install(701, 9)
	game.set("_session_diagnostics_bridge", bridge)
	game.call("_publish_recovery_choice_to_hud")
	var buttons: Dictionary = game.hud.get("_session_recovery_action_buttons")
	var button := buttons.get(&"discard") as Button
	_check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,
		"the actual Main HUD offers a visible enabled fenced Start Fresh button")
	return button


func _press_start_fresh(game: GameFlow) -> Dictionary:
	var button := _offer_start_fresh(game)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return {"accepted": false, "reason": &"fixture_recovery_choice_unavailable"}
	button.pressed.emit()
	await process_frame
	return game.get("_session_recovery_hud_status") as Dictionary


func _progress_recovery() -> void:
	var path := "user://scan_progress_%d.json" % Time.get_ticks_usec()
	var filesystem := FaultFilesystem.new()
	filesystem.reject_rewards = false
	var first := await _game(path, filesystem)
	await _board(first)
	var binding := await _binding(first)
	first.active_ship.global_position = first.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(first, 2).emit_signal("pressed")
	first.call("_advance_cinder_structure_scan", 0.5, first.call("_capture_cinder_actor_sample"))
	var saved_before_refusal := _scan_recovery_artifacts(path)
	filesystem.reject_all = true
	for _sample in 6:
		first.call("_advance_cinder_structure_scan", 0.125, first.call("_capture_cinder_actor_sample"))
	_check(filesystem.refused_write_attempts == 1 and _scan_recovery_artifacts(path) == saved_before_refusal
		and is_equal_approx(binding.get_activity_snapshot(&"structure_scan").elapsed_seconds, 1.25)
		and _receipts(first) == 0,
		"failed periodic scan checkpoints keep the half-second retry cadence, live progress and unchanged disk without payment")
	filesystem.reject_all = false
	first.call("_advance_cinder_structure_scan", 0.125, first.call("_capture_cinder_actor_sample"))
	_check(_scan_recovery_artifacts(path) == saved_before_refusal,
		"recovered storage waits for the next ordinary checkpoint interval without a per-tick retry")
	first.call("_advance_cinder_structure_scan", 0.125, first.call("_capture_cinder_actor_sample"))
	var progress := binding.get_activity_snapshot(&"structure_scan")
	_check(progress.state_id == &"active" and is_equal_approx(progress.elapsed_seconds, 1.5), "ordinary HUD Start and actual production sample accrue genuine scan progress")
	await _dispose(first)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	var restored := fresh_binding.get_activity_snapshot(&"structure_scan")
	_check(restored.state_id == &"active" and restored.generation == progress.generation and is_equal_approx(restored.elapsed_seconds, 1.5), "fresh Main restores the exact saved scan generation and accrued time")
	var foreign := await _game(path, UserDataFilesystem.new())
	var foreign_binding := await _binding(foreign)
	await _board(foreign)
	foreign.active_ship.global_position = foreign.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	foreign.call("_advance_cinder_structure_scan", Scan.SCAN_SECONDS-1.5, foreign.call("_capture_cinder_actor_sample"))
	var old_save: Dictionary = fresh.call("_save_cinder_scan_session", fresh_binding)
	_check(not old_save.accepted and _receipts(foreign) == 1, "an earlier Main cannot overwrite the later owner's paid completion with its saved active progress")
	await _dispose(foreign)
	await _dispose(fresh)


func _legacy_discovery_compatibility() -> void:
	var path := "user://scan_legacy_discovery_%d.json" % Time.get_ticks_usec()
	var paid := await _game(path, UserDataFilesystem.new())
	await _board(paid)
	var paid_binding := await _binding(paid)
	await _complete(paid, paid_binding)
	_check(_receipts(paid) == 1 and paid_binding.get_activity_snapshot(&"structure_scan").discovery_persisted,
		"existing production discovery and shared reward owners publish a genuine paid scan")
	await _dispose(paid)
	# A historical save predates the new progress namespace. Preserve the real
	# discovery/ledger produced above and omit only that newer namespace.
	var store := UserDataStore.new(path)
	store.load()
	var payload := store.get_snapshot()
	payload.erase("cinder_structure_scan_session")
	_check(store.commit(payload, store.get_generation(), "unit-legacy-scan-save-layout").accepted,
		"the real legacy-format disk fixture retains its discovery and paid ledger")
	var legacy := await _game(path, UserDataFilesystem.new())
	var binding := await _binding(legacy)
	var presentation := binding.get_activity_snapshot(&"structure_scan")
	var authority_state: Dictionary = binding.capture_structure_scan_session().activities[0]
	_check(presentation.discovery_persisted and presentation.state_id == &"complete"
		and authority_state.state == Scan.State.IDLE and authority_state.generation == 0
		and _receipts(legacy) == 1,
		"legacy paid discovery restores presentation while scan authority stays idle without owed entitlement")
	await _board(legacy)
	await _complete(legacy, binding)
	_check(_receipts(legacy) == 2 and binding.get_activity_snapshot(&"structure_scan").reward_committed,
		"ordinary Start completes a genuine new scan from a legacy save and pays that distinct run once")
	await _dispose(legacy)


func _published_payment_retry() -> void:
	var path := "user://scan_published_payment_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	fault.reject_rewards = false
	fault.fail_published_reward_sync = true
	var game := await _game(path, fault)
	await _board(game)
	var binding := await _binding(game)
	await _complete(game, binding)
	var live := binding.get_activity_snapshot(&"structure_scan")
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload
	var failed: Dictionary = game.get_activity_reward_report().last_cinder_structure_scan_result
	_check(not live.reward_requested and published.cinder_structure_scan_session.activities[0].reward_granted
		and int(published.game_flow_reward_store.total_receipts) == 1
		and failed.authority_result.store_result.reason == "published_directory_sync_failed"
		and failed.authority_result.store_result.published,
		"a real postpublication sync failure leaves a paid disk receipt while the live owner reports refusal")
	_button(game, 2).emit_signal("pressed")
	var reconciled := binding.get_activity_snapshot(&"structure_scan")
	var store: UserDataStore = game.get("_runtime_settings_user_data_store")
	_check(reconciled.reward_requested and reconciled.reward_committed and _receipts(game) == 1
		and store.get_snapshot().cinder_structure_scan_session.activities[0].reward_granted,
		"ordinary Start reconciles the exact published payment without downgrading its acknowledgement or paying twice")
	_button(game, 3).emit_signal("pressed")
	game.active_ship.global_position = game.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"structure_scan").generation == int(live.generation) + 1 and _receipts(game) == 1,
		"the reconciled payment permits an ordinary new generation with one durable receipt")
	await _dispose(game)
	var fresh := await _game(path, UserDataFilesystem.new())
	await _binding(fresh)
	_check(_receipts(fresh) == 1, "fresh Main after the sync failure still loads exactly one material-sample payment")
	await _dispose(fresh)

func _all_writes_failed() -> void:
	var path := "user://scan_unsaved_%d.json" % Time.get_ticks_usec()
	var fault := FaultFilesystem.new()
	var first := await _game(path, fault)
	await _board(first)
	var binding := await _binding(first)
	fault.reject_all = true
	await _complete(first, binding)
	_check(binding.get_activity_snapshot(&"structure_scan").state_id == &"complete" and _receipts(first) == 0,
		"when every write fails the live owner retains completion but grants no reward")
	await _dispose(first)
	var fresh := await _game(path, UserDataFilesystem.new())
	var fresh_binding := await _binding(fresh)
	_check(fresh_binding.get_activity_snapshot(&"structure_scan").state_id == &"idle" and _receipts(fresh) == 0,
		"without a valid durable terminal fresh Main safely offers a new scan and no entitlement")
	# API-reachable pending-choice boundary: normal Begin Shift consumes the
	# notice, so this deliberately republishes the existing recovery fixture's
	# fenced notice before advancing the actual live scan to completion.
	await _board(fresh)
	fresh.active_ship.global_position = fresh.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(fresh, 2).pressed.emit()
	fresh.call("_advance_cinder_structure_scan", 1.5, fresh.call("_capture_cinder_actor_sample"))
	var store: UserDataStore = fresh.get("_runtime_settings_user_data_store")
	var active: Dictionary = store.get_snapshot().get("cinder_structure_scan_session", {})
	_check(not active.is_empty() and int(active.activities[0].state) == Scan.State.SCANNING,
		"the terminal-save refusal case has a genuine persisted incomplete scan first")
	if active.is_empty() or int(active.activities[0].state) != Scan.State.SCANNING:
		await _dispose(fresh)
		return
	var button := _offer_start_fresh(fresh)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		await _dispose(fresh)
		return
	var notice: Dictionary = fresh.hud.get_session_recovery_notice_snapshot()
	var original_filesystem: RefCounted = store.get("_filesystem")
	var terminal_fault := FaultFilesystem.new()
	terminal_fault.reject_all = true
	store.set("_filesystem", terminal_fault)
	await _complete(fresh, fresh_binding)
	store.set("_filesystem", original_filesystem)
	var completed: Dictionary = fresh_binding.get_activity_snapshot(&"structure_scan")
	var before: Dictionary = store.get_snapshot()
	var bytes := FileAccess.get_file_as_bytes(path)
	var generation := store.get_generation()
	_check(completed.state_id == &"complete" and not completed.reward_requested
		and before.cinder_structure_scan_session == active and _receipts(fresh) == 0,
		"failed terminal publication leaves earned live completion ahead of the saved ACTIVE checkpoint")
	button.pressed.emit()
	var refusal: Dictionary = fresh.get("_session_recovery_hud_status")
	var deadline := Time.get_ticks_msec() + 2_000
	while is_instance_valid(button) and button.disabled and Time.get_ticks_msec() < deadline:
		await process_frame
		await physics_frame
	var retry_notice: Dictionary = fresh.hud.get_session_recovery_notice_snapshot()
	var rearmed: bool = is_instance_valid(button) and not button.disabled and button.is_visible_in_tree() \
		and bool(retry_notice.get("active", false)) \
		and retry_notice.get("recovery_token") == notice.get("recovery_token") \
		and retry_notice.get("recovery_generation") == notice.get("recovery_generation")
	_check(not refusal.get("accepted", false) and rearmed
		and fresh_binding.get_activity_snapshot(&"structure_scan").state_id == &"complete"
		and int(fresh_binding.get_activity_snapshot(&"structure_scan").generation) == int(completed.generation)
		and store.get_snapshot() == before and store.get_generation() == generation
		and FileAccess.get_file_as_bytes(path) == bytes and _receipts(fresh) == 0,
		"Start Fresh refuses before RESET when a failed terminal save left newer earned live work")
	if not rearmed:
		await _dispose(fresh)
		return
	_button(fresh, 2).pressed.emit()
	var paid: Dictionary = fresh_binding.get_activity_snapshot(&"structure_scan")
	_check(paid.state_id == &"complete" and paid.reward_committed and paid.discovery_persisted
		and _receipts(fresh) == 1,
		"ordinary scan Start retries the retained completion and durably pays once after writes recover")
	var paid_payload: Dictionary = store.get_snapshot()
	button.pressed.emit()
	await process_frame
	var accepted: Dictionary = fresh.get("_session_recovery_hud_status")
	_check(accepted.get("accepted", false) and fresh.get_recovery_available_snapshot().is_empty()
		and store.get_snapshot() == paid_payload and _receipts(fresh) == 1,
		"the same Start Fresh choice accepts after terminal retry without changing completed payment or discovery")
	await _dispose(fresh)

func _unsupported_record(path: String) -> void:
	var store := UserDataStore.new(path)
	store.load()
	var payload := store.get_snapshot()
	payload.cinder_structure_scan_session.schema_version = 2
	store.commit(payload, store.get_generation(), "unit-unsupported-scan-record")
	var unsupported := JSON.parse_string(JSON.stringify(payload.cinder_structure_scan_session)) as Dictionary
	var fresh := await _game(path, UserDataFilesystem.new())
	await _binding(fresh)
	_button(fresh, 2).emit_signal("pressed")
	_button(fresh, 3).emit_signal("pressed")
	_check(fresh.get("_runtime_settings_user_data_store").get_snapshot().cinder_structure_scan_session == unsupported,
		"unsupported saved scan data remains unchanged through ordinary Start and Reset")
	_check(fresh.call("_get_nearby_activity_binding").get_activity_snapshot(&"structure_scan").generation == 0
		and _receipts(fresh) == 2, "unsupported state creates neither a recovered generation nor reward entitlement")
	await _dispose(fresh)

func _game(path: String, filesystem: UserDataFilesystem) -> GameFlow:
	var started := Time.get_ticks_usec()
	var physics_started := Engine.get_physics_frames()
	var game := Main.instantiate() as GameFlow
	var instantiated := Time.get_ticks_usec()
	game.configure_runtime_settings_persistence(UserDataStore.new(path, filesystem), path + ".legacy.cfg")
	var viewport := SubViewport.new()
	viewport.name = "ScanOwnerWorld"
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.add_child(game)
	var attached := Time.get_ticks_usec()
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	print("SCAN_FRESH_MAIN_TIMING: ", {
		"fixture": path.get_file(),
		"instantiate_ms": (instantiated - started) / 1000.0,
		"attach_ready_ms": (attached - instantiated) / 1000.0,
		"settle_ms": (Time.get_ticks_usec() - attached) / 1000.0,
		"physics_frames": Engine.get_physics_frames() - physics_started,
	})
	return game

func _board(game: GameFlow) -> void:
	game.set_physics_process(true)
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.02
	game.start_shift()
	var craft := game.get_guided_ship()
	game.player.global_position = craft.get_boarding_position()
	game.call("_board_ship", craft)
	for _tick in 300:
		if craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()):
			break
		await physics_frame
	_check(craft.is_piloted() and game.player.is_seated_at(craft.get_pilot_seat_anchor()), "actual production boarding supplies the scan fixture's pilot owner")
	game.set_physics_process(false)

func _binding(game: GameFlow) -> NearbySectorActivityBinding:
	game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	var binding: NearbySectorActivityBinding
	for _frame in 180:
		binding = game.call("_get_nearby_activity_binding") as NearbySectorActivityBinding
		if is_instance_valid(binding):
			break
		await process_frame
	_check(is_instance_valid(binding), "the real Cinder streaming owner supplies the scan binding")
	game.call("_sync_activity_hud")
	return binding

func _complete(game: GameFlow, binding: NearbySectorActivityBinding) -> void:
	var craft := game.active_ship
	craft.global_position = game.call("_cinder_authored_frame_to_world", Scan.APPROACH_ANCHOR)
	_button(game, 2).emit_signal("pressed")
	_check(binding.get_activity_snapshot(&"structure_scan").state_id == &"active", "ordinary HUD Start admits the actual authored scan approach")
	for _tick in int(Scan.SCAN_SECONDS * 60):
		game.call("_advance_cinder_structure_scan", 1.0 / 60.0, game.call("_capture_cinder_actor_sample"))
	_check(binding.get_activity_snapshot(&"structure_scan").elapsed_seconds == Scan.SCAN_SECONDS,
		"ordinary 1/60 scan samples normalize the genuine completed timer to its durable terminal")

func _button(game: GameFlow, index: int) -> Button:
	for row in (game.hud.get("_nearby_activity_rows") as VBoxContainer).get_children():
		if "cinder_derelict_structure_scan" in str(row.name):
			return row.get_child(index) as Button
	return null

func _dispose(game: GameFlow) -> void:
	var viewport := game.get_parent() as SubViewport
	var owned_nodes: Array[WeakRef] = [weakref(game)]
	if is_instance_valid(viewport):
		owned_nodes.append(weakref(viewport))
	for node: Node in game.find_children("*", "", true, false):
		owned_nodes.append(weakref(node))
	game.queue_free()
	await process_frame
	if is_instance_valid(viewport):
		viewport.queue_free()
	await process_frame
	var surviving_nodes := 0
	for reference: WeakRef in owned_nodes:
		surviving_nodes += int(is_instance_valid(reference.get_ref()))
	_check(surviving_nodes == 0,
		"disposing a scan owner retires its Main, private viewport and every owned node")

func _receipts(game: GameFlow) -> int:
	return int(game.get_activity_reward_report().authority.record.total_receipts)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("PASS: ", message)
	else:
		_failures.append("FAIL: " + message)
		printerr("FAIL: ", message)
