extends SceneTree
## test-matrix-timeout-seconds: 600
## A resumed Aurora or Rime visit spends its first seconds streaming the world
## back in. The interrupted-visit receipt is retired as soon as that resume is
## admitted, so a player who quits (or restarts the shift) while the world is
## still streaming must have the visit recorded again on the way out; otherwise
## the next launch starts them back at Mudds and their survey progress is gone.
##
## Each world is exercised through the production store and whole-`Main`
## lifecycle: seed a receipt, boot a `Main` that begins resuming it, leave that
## `Main` while it is still `restoring`, and check that the next `Main` resumes
## the same visit with the same survey progress.

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "SURFACE_VISIT_QUIT_DURING_RESUME_TEST_OK"
const FAILURE_MARKER := "SURFACE_VISIT_QUIT_DURING_RESUME_TEST_FAILED"

var _failures: Array[String] = []
var _assertions := 0


class RejectWritesFilesystem extends UserDataFilesystem:
	var attempts := 0

	func write_bytes_and_flush(_path: String, _bytes: PackedByteArray) -> Error:
		attempts += 1
		return ERR_CANT_CREATE


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _exercise(&"aurora", "_aurora_expedition", "_aurora_expedition_persistence_binding",
		&"get_aurora_interrupted_visit_status")
	await _exercise(&"rime", "_rime_expedition", "_rime_expedition_persistence_binding",
		&"get_rime_interrupted_visit_status")
	await _exercise_start_fresh(&"aurora", "_aurora_expedition", "_aurora_expedition_persistence_binding")
	await _exercise_start_fresh(&"rime", "_rime_expedition", "_rime_expedition_persistence_binding")
	await _exercise_declined_completion_retry()
	_test_pending_shared_decline()
	_finish()


func _exercise(
		world_id: StringName, owner_property: String, binding_property: String,
		status_method: StringName,
	) -> void:
	# --- seed a settled on-foot visit through the production binding --------
	var seed_game := await _boot(false)
	var craft := seed_game.get_node_or_null("HalyardCrewTransport") as HeroShip
	_check(craft != null, "%s: the production Main composes the Halyard" % world_id)
	if craft == null:
		await _shut_down(seed_game)
		return
	var berth_id := String(craft.get_home_berth_id())
	var binding: RefCounted = seed_game.get(binding_property)
	_check(binding != null, "%s: the visit persistence binding is configured" % world_id)
	if binding == null:
		await _shut_down(seed_game)
		return
	var survey_script: GDScript = (seed_game.get(owner_property) as RefCounted).get(
		"survey"
	).get_script()
	var progress := {
		"schema_version": 1,
		"activity_id": String(survey_script.get_script_constant_map().get("ACTIVITY_ID", "")),
		"state": CheckpointRouteActivity.State.ACTIVE,
		"generation": 1,
		"next_checkpoint_index": 1,
		"failure_reason": "",
	}
	var seeded := binding.call(&"save_interrupted_visit", {
		"visit_state": "surface",
		"craft_home_berth_id": berth_id,
		"on_foot": true,
		"survey": progress,
	}, "%s-quit-during-resume-seed" % world_id) as Dictionary
	_check(bool(seeded.get("accepted", false)),
		"%s: a settled on-foot visit is recorded (%s)" % [world_id, seeded.get("reason", "")])
	await _shut_down(seed_game)

	# --- begin the resume, then leave while the world is still streaming ----
	# Headless streaming of an already-cached world can finish within a frame,
	# so the quit is taken in the same frame BEGIN SHIFT admitted the resume.
	var resuming_game := await _boot(true, false)
	var resuming: RefCounted = resuming_game.get(owner_property)
	var first := (resuming_game.call(status_method) as Dictionary).get("restore", {}) as Dictionary
	_check(bool(first.get("accepted", false)),
		"%s: the first relaunch admits the resume (%s)" % [world_id, first.get("reason", "")])
	_check(StringName(resuming.get("state")) == &"restoring",
		"%s: the first relaunch is still streaming the world when the pilot quits (%s)"
			% [world_id, resuming.get("state")])
	await _shut_down(resuming_game)

	# --- the next launch must still hand the visit back ----------------------
	var resumed_game := await _boot(true)
	var resumed: RefCounted = resumed_game.get(owner_property)
	var second := (resumed_game.call(status_method) as Dictionary).get("restore", {}) as Dictionary
	_check(bool(second.get("accepted", false)),
		"%s: quitting mid-resume keeps the visit for the next launch (%s)"
			% [world_id, second.get("reason", "")])
	var survey: RefCounted = resumed.get("survey")
	_check(int((survey.call(&"capture") as Dictionary).get("next_checkpoint_index", -1)) == 1,
		"%s: the survey progress carried into the resume is intact" % world_id)
	# Leave nothing behind for the next world's section.
	resumed.call(&"cancel")
	await _shut_down(resumed_game)
	var cleanup_game := await _boot(false)
	var cleanup_binding: RefCounted = cleanup_game.get(binding_property)
	var leftover := cleanup_binding.call(&"load_interrupted_visit") as Dictionary
	if bool(leftover.get("accepted", false)):
		cleanup_binding.call(&"retire_interrupted_visit",
			int(leftover.get("store_generation", -1)),
			str(leftover.get("receipt_sha256", "")),
			"%s-quit-during-resume-cleanup" % world_id)
	await _shut_down(cleanup_game)


## Start Fresh declines the saved location, not observations or earned debt.
## The second cold Main distinguishes a durable decline from a one-boot flag.
func _exercise_start_fresh(world_id: StringName, owner_property: String, binding_property: String) -> void:
	var seed := await _boot(false)
	var craft := seed.get_node_or_null("HalyardCrewTransport") as HeroShip
	var binding: RefCounted = seed.get(binding_property)
	var store := seed.get("_runtime_settings_user_data_store") as UserDataStore
	var owner: RefCounted = seed.get(owner_property)
	_check(craft != null and binding != null and store != null and owner != null,
		"%s: Start Fresh uses the production visit, craft and atomic store" % world_id)
	if craft == null or binding == null or store == null or owner == null:
		await _shut_down(seed)
		return
	var survey_script: GDScript = owner.get("survey").get_script()
	# Aurora covers interrupted observations; Rime covers completed/unpaid data
	# and heat. These are saved fixture inputs, not a claimed travelled survey.
	var progress := {
		"schema_version": 1,
		"activity_id": String(survey_script.get_script_constant_map().get("ACTIVITY_ID", "")),
		"state": CheckpointRouteActivity.State.COMPLETED if world_id == &"rime" else CheckpointRouteActivity.State.ACTIVE,
		"generation": 3,
		"next_checkpoint_index": 2 if world_id == &"rime" else 1,
		"failure_reason": "",
	}
	if world_id == &"rime":
		progress["heat_s"] = 63.25
	var seeded := binding.call(&"save_interrupted_visit", {
		"visit_state": "surface", "craft_home_berth_id": String(craft.get_home_berth_id()),
		"on_foot": true, "survey": progress,
	}, "%s-start-fresh-seed" % world_id) as Dictionary
	_check(bool(seeded.get("accepted", false)), "%s: real visit data is saved before interruption" % world_id)
	if not bool(seeded.get("accepted", false)):
		await _shut_down(seed)
		return
	var slot := String((binding.call(&"get_snapshot") as Dictionary).slot_id)
	var saved_record := (store.get_snapshot()[slot] as Dictionary).duplicate(true)
	var invalid_archive := store.get_snapshot()
	invalid_archive[String(binding.call(&"get_declined_slot_id"))] = {"corrupt": true}
	var invalid_before := invalid_archive.duplicate(true)
	var invalid_plan: Dictionary = binding.call(&"plan_decline", invalid_archive, false)
	_check(not bool(invalid_plan.get("accepted", false)) and invalid_archive == invalid_before,
		"%s: malformed passive data refuses decline without modifying either record" % world_id)
	if world_id == &"rime":
		var pending_archive := saved_record.duplicate(true)
		pending_archive.visit.on_foot = false
		pending_archive.receipt_sha256 = RimeExpeditionPersistenceBinding._digest(pending_archive.visit)
		var collision := store.get_snapshot()
		collision[String(binding.call(&"get_declined_slot_id"))] = pending_archive
		var collision_before := collision.duplicate(true)
		var collision_plan: Dictionary = binding.call(&"plan_decline", collision, false)
		_check(not bool(collision_plan.get("accepted", false)) and collision == collision_before,
			"Rime: a different unpaid completed archive refuses replacement without losing either record")
	# Both world slots exist at the failed transaction boundary. Neither may be
	# partly declined when the one real UserDataStore write is rejected.
	var other_binding: RefCounted = seed.get("_rime_expedition_persistence_binding" if world_id == &"aurora" else "_aurora_expedition_persistence_binding")
	var other_owner: RefCounted = seed.get("_rime_expedition" if world_id == &"aurora" else "_aurora_expedition")
	var other_script: GDScript = other_owner.get("survey").get_script()
	var other_progress := {"schema_version": 1,
		"activity_id": String(other_script.get_script_constant_map().get("ACTIVITY_ID", "")),
		"state": CheckpointRouteActivity.State.ACTIVE, "generation": 3,
		"next_checkpoint_index": 0, "failure_reason": ""}
	var other_saved: Dictionary = other_binding.call(&"save_interrupted_visit", {
		"visit_state": "surface", "craft_home_berth_id": String(craft.get_home_berth_id()),
		"on_foot": true, "survey": other_progress,
	}, "%s-start-fresh-other-world" % world_id)
	_check(bool(other_saved.get("accepted", false)), "%s: both world receipts exist at the atomic decline boundary" % world_id)
	var payload := store.get_snapshot()
	var shared := {"craft_home_berth_id": String(craft.get_home_berth_id()),
		"survey": progress.duplicate(true) if world_id == &"aurora" else other_progress.duplicate(true)}
	var durable_shared := JSON.parse_string(JSON.stringify(shared, "", true, true)) as Dictionary
	payload[GameFlow.AURORA_SHARED_SURVEY_SLOT] = shared
	var unrelated := {"world": String(world_id), "note": "preserve-unrelated-save"}
	payload["surface_start_fresh_unrelated"] = unrelated
	var witnessed := store.commit(payload, store.get_generation(), "%s-start-fresh-unrelated" % world_id)
	_check(bool(witnessed.get("accepted", false)), "%s: unrelated saved data is committed" % world_id)
	var settings := seed.runtime_settings.to_user_data_payload()
	var reward := seed.get_activity_reward_report().get("authority", {}).get("record", {}) as Dictionary
	reward = reward.duplicate(true)
	await _shut_down(seed)

	var fresh := await _boot(false)
	var recovery := fresh.get_recovery_available_snapshot()
	var fresh_button := _find_button(fresh.hud, "Start Fresh")
	_check(not recovery.is_empty() and fresh_button != null and fresh_button.is_visible_in_tree() and not fresh_button.disabled,
		"%s: the real recovery card offers usable Start Fresh" % world_id)
	if recovery.is_empty() or fresh_button == null or not fresh_button.is_visible_in_tree() or fresh_button.disabled:
		await _shut_down(fresh)
		return
	var fresh_store := fresh.get("_runtime_settings_user_data_store") as UserDataStore
	var before_stale := fresh_store.get_snapshot()
	var stale: Dictionary = fresh.call(&"_handle_hud_session_recovery_choice", &"discard",
		int(recovery.session_id), int(recovery.startup_generation) + 1)
	_check(not bool(stale.get("accepted", false)) and fresh_store.get_snapshot() == before_stale
		and not fresh.get_recovery_available_snapshot().is_empty(),
		"%s: stale Start Fresh cannot decline saved progress or consume the choice" % world_id)
	var original_filesystem: RefCounted = fresh_store.get("_filesystem")
	var rejecting := RejectWritesFilesystem.new()
	var generation := fresh_store.get_generation()
	var saved_bytes := FileAccess.get_file_as_bytes(RuntimeSettingsStoreAdapter.DEFAULT_STORE_PATH)
	fresh.set("_aurora_shared_survey_checkpoint", shared.duplicate(true))
	fresh.set("_aurora_shared_survey_checkpoint_pending", true)
	fresh_store.set("_filesystem", rejecting)
	fresh_button.pressed.emit()
	var failed := fresh.get("_session_recovery_hud_status") as Dictionary
	fresh_store.set("_filesystem", original_filesystem)
	var retry_deadline := Time.get_ticks_msec() + 2_000
	while fresh_button.disabled and Time.get_ticks_msec() < retry_deadline:
		await process_frame
		await physics_frame
	var retry_notice: Dictionary = fresh.hud.get_session_recovery_notice_snapshot()
	var retry_ready := fresh_button == _find_button(fresh.hud, "Start Fresh") \
		and fresh_button.is_visible_in_tree() and not fresh_button.disabled \
		and bool(retry_notice.get("active", false)) and not bool(retry_notice.get("choice_latched", true)) \
		and int(retry_notice.get("recovery_token", 0)) == int(recovery.session_id) \
		and int(retry_notice.get("recovery_generation", 0)) == int(recovery.startup_generation)
	_check(retry_ready, "%s: refused actual Start Fresh rearms the SAME visible button and recovery fence" % world_id)
	_check(not bool(failed.get("accepted", false)) and rejecting.attempts == 1
		and fresh_store.get_generation() == generation and fresh_store.get_snapshot() == before_stale
		and FileAccess.get_file_as_bytes(RuntimeSettingsStoreAdapter.DEFAULT_STORE_PATH) == saved_bytes
		and not fresh.get_recovery_available_snapshot().is_empty()
		and bool(fresh.get("_aurora_shared_survey_checkpoint_pending"))
		and fresh.get("_aurora_shared_survey_checkpoint") == shared,
		"%s: rejected atomic decline preserves BOTH visits, shared pending writer, disk and recovery choice" % world_id)
	if not retry_ready:
		await _shut_down(fresh)
		return
	fresh_button.pressed.emit()
	await process_frame
	var choice := fresh.get("_session_recovery_hud_status") as Dictionary
	_check(bool(choice.get("accepted", false)) and choice.get("choice") == &"discard",
		"%s: the actual Start Fresh button reaches its production consumer" % world_id)
	_check(not fresh_store.get_snapshot().has(String(GameFlow.AURORA_EXPEDITION_PERSISTENCE_SLOT))
		and not fresh_store.get_snapshot().has(String(GameFlow.RIME_EXPEDITION_PERSISTENCE_SLOT))
		and not fresh_store.get_snapshot().has(GameFlow.AURORA_SHARED_SURVEY_SLOT)
		and fresh_store.get_snapshot().get(GameFlow.AURORA_DECLINED_SHARED_SURVEY_SLOT) == durable_shared
		and not bool(fresh.get("_aurora_shared_survey_checkpoint_pending"))
		and (fresh.get("_aurora_shared_survey_checkpoint") as Dictionary).is_empty(),
		"%s: accepted decline moves both locations and shared checkpoint without a later flush backdoor" % world_id)
	_check(_saved_record_retained(fresh_store.get_snapshot(), saved_record),
		"%s: declining location preserves exact observations, heat and unpaid terminal data" % world_id)
	var begin := _find_button(fresh, "BEGIN SHIFT")
	_check(begin != null and begin.is_visible_in_tree() and not begin.disabled,
		"%s: Begin Shift remains usable after Start Fresh" % world_id)
	if begin == null:
		await _shut_down(fresh)
		return
	begin.pressed.emit()
	# Free-running headless process frames can precede the intro's real fade.
	# Observe the actual phase boundary while advancing both ordinary loops.
	var begin_deadline := Time.get_ticks_msec() + 5_000
	while fresh.phase == GameFlow.Phase.INTRO and Time.get_ticks_msec() < begin_deadline:
		await process_frame
		await physics_frame
	_check(fresh.phase != GameFlow.Phase.INTRO, "%s: the actual Begin Shift fade reaches gameplay" % world_id)
	if fresh.phase == GameFlow.Phase.INTRO:
		await _shut_down(fresh)
		return
	for _frame in 12:
		await process_frame
		await physics_frame
	_check(_usable_mudds(fresh, owner_property),
		"%s: Start Fresh begins on foot at Mudds without automatically restoring the visit" % world_id)
	_check(fresh.runtime_settings.to_user_data_payload() == settings
		and fresh_store.get_snapshot().get("surface_start_fresh_unrelated") == unrelated
		and fresh.get_activity_reward_report().get("authority", {}).get("record", {}) == reward,
		"%s: Start Fresh keeps settings, unrelated data and reward authority unchanged" % world_id)
	fresh.mark_orderly_shutdown()
	await _shut_down(fresh)

	var later := await _boot(true)
	for _frame in 12:
		await process_frame
		await physics_frame
	var later_store := later.get("_runtime_settings_user_data_store") as UserDataStore
	_check(_usable_mudds(later, owner_property),
		"%s: a later ordinary boot does not resurrect the declined planetary location" % world_id)
	_check(_saved_record_retained(later_store.get_snapshot(), saved_record)
		and later.runtime_settings.to_user_data_payload() == settings
		and later_store.get_snapshot().get("surface_start_fresh_unrelated") == unrelated
		and later.get_activity_reward_report().get("authority", {}).get("record", {}) == reward,
		"%s: passive visit progress and unrelated earned state survive the next cold Main" % world_id)
	(later.get(owner_property) as RefCounted).call(&"cancel")
	later.mark_orderly_shutdown()
	await _shut_down(later)


## Staged arrival through the same existing production recovery admission as
## this fixture's Resume controls; this does not qualify outbound travel. Once
## admitted, only ordinary held walking input and E reach the actual gauge.
func _exercise_declined_completion_retry() -> void:
	var game := await _boot(true)
	var owner: RefCounted = game.get("_rime_expedition")
	var survey: RefCounted = owner.get("survey")
	var binding: RefCounted = game.get("_rime_expedition_persistence_binding")
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	var craft := game.get_node("HalyardCrewTransport") as HeroShip
	var archive_key := String(binding.call(&"get_declined_slot_id"))
	var archive := (store.get_snapshot().get(archive_key, {}) as Dictionary).duplicate(true)
	_check(not archive.is_empty() and owner.get("state") == &"idle",
		"declined completion stays passive at Mudds until a new current admission")
	var admitted: Dictionary = owner.call(&"restore_interrupted_visit", {
		"visit_state": "surface", "craft_home_berth_id": String(craft.get_home_berth_id()),
		"on_foot": true, "survey": {},
	})
	_check(bool(admitted.get("accepted", false)), "fresh staged Rime admission uses the real registered craft and coordinator")
	var deadline := Time.get_ticks_msec() + 30_000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		await physics_frame
		if bool(owner.call(&"settled_surface_is_current")) and game.player.is_on_floor() \
				and int((survey.call(&"snapshot") as Dictionary).get("state", -1)) == CheckpointRouteActivity.State.COMPLETED:
			break
	var ready := bool(owner.call(&"settled_surface_is_current")) and game.player.is_on_floor()
	var progress := survey.call(&"snapshot") as Dictionary
	_check(ready and int(progress.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED \
		and int(progress.get("generation", -1)) == 3 and not bool(survey.call(&"reward_recorded")) \
		and is_equal_approx(float((survey.call(&"get_heat_snapshot") as Dictionary).heat_s), 120.0),
		"only a real current surface admits unpaid completion; the new trip does not inherit old heat")
	if not ready or int(progress.get("state", -1)) != CheckpointRouteActivity.State.COMPLETED:
		owner.call(&"cancel")
		await _shut_down(game)
		return
	# A normal outbound/current-visit save must not overwrite the passive debt.
	var saved := game.save_interrupted_rime_visit()
	_check(bool(saved.get("accepted", false)) and store.get_snapshot().get(archive_key) == archive,
		"a newer active visit save leaves the declined unpaid obligation intact")
	var region := (owner.get("_surface") as Node3D).get_node("LandingRegion") as Node3D
	var reached := await _walk_to_gauge(game, region)
	_check(reached, "ordinary held movement reaches the actual Rime gauge on supported ground")
	if not reached:
		owner.call(&"cancel")
		await _shut_down(game)
		return
	var original_filesystem: RefCounted = store.get("_filesystem")
	var rejecting := RejectWritesFilesystem.new()
	store.set("_filesystem", rejecting)
	await _press_interact()
	store.set("_filesystem", original_filesystem)
	_check(rejecting.attempts > 0 and not bool(survey.call(&"reward_recorded")) \
		and store.get_snapshot().get(archive_key) == archive \
		and int((survey.call(&"snapshot") as Dictionary).get("state", -1)) == CheckpointRouteActivity.State.COMPLETED,
		"ordinary gauge interaction with a rejected reward write retains completion and passive debt")
	await _press_interact()
	_check(bool(survey.call(&"reward_recorded")), "ordinary gauge retry commits the declined completion reward")
	var paid := (game.get_activity_reward_report().get("authority", {}).get("record", {}) as Dictionary).duplicate(true)
	await _press_interact()
	_check(game.get_activity_reward_report().get("authority", {}).get("record", {}) == paid \
		and int((paid.get("reward_counts", {}) as Dictionary).get("rime_ice_core_record", 0)) == 1 \
		and not bool(game.get_declined_surface_survey_completion(&"rime_glacial_world").get("accepted", false)),
		"paid authority suppresses old passive completion and repeated interaction pays only once")
	owner.call(&"cancel")
	game.mark_orderly_shutdown()
	await _shut_down(game)


func _walk_to_gauge(game: GameFlow, region: Node3D) -> bool:
	for point in [Vector3(-7, 0, -17), Vector3(8, 0, -20), Vector3(20, 0, -40), Vector3(29, 0, -61)]:
		var reached := false
		# Same held-input region-local route and 0.7 m arrival used by the existing
		# Rime visit fixture; no Player placement occurs after admission.
		for _tick in 1400:
			var target := region.to_global(point)
			var offset := target - game.player.global_position
			offset.y = 0.0
			if offset.length() < 0.7:
				reached = true
				break
			var direction := game.player.global_basis.inverse() * (target - game.player.global_position)
			(game.player.get_node("CameraRig/CameraYaw") as Node3D).rotation.y = atan2(-direction.x, -direction.z)
			Input.action_press(&"move_forward")
			await physics_frame
			await process_frame
		Input.action_release(&"move_forward")
		for _tick in 8:
			await physics_frame
			await process_frame
		if not reached:
			return false
	return game.player.is_on_floor()


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


## Transaction-only cases use an explicitly injected real atomic store. These
## validated fixture inputs do not claim live survey observations or travel.
func _test_pending_shared_decline() -> void:
	var store := UserDataStore.new("user://pending_shared_decline_test.json")
	store.load()
	var initial := store.commit({"unrelated": "keep"}, store.get_generation(), "pending-decline-initialize")
	_check(bool(initial.get("accepted", false)), "pending-writer fixture initializes a real primary store")
	var game := GameFlow.new()
	_check(game.configure_runtime_settings_persistence(store), "pending-writer fixture injects its isolated store before startup")
	game.bind_aurora_expedition_persistence()
	game.bind_rime_expedition_persistence()
	var active := {"craft_home_berth_id": "crew_port_01", "survey": {
		"schema_version": 1, "activity_id": "aurora_coastal_observation",
		"state": CheckpointRouteActivity.State.ACTIVE, "generation": 7,
		"next_checkpoint_index": 1, "failure_reason": ""}}
	var completed := active.duplicate(true)
	completed.survey.state = CheckpointRouteActivity.State.COMPLETED
	completed.survey.next_checkpoint_index = 2
	# Expected disk records use the exact full-precision JSON number types;
	# keep the live pending producer inputs integer-bearing below.
	var durable_completed := JSON.parse_string(JSON.stringify(completed, "", true, true)) as Dictionary
	var payload := store.get_snapshot()
	payload[GameFlow.AURORA_SHARED_SURVEY_SLOT] = active
	_check(bool(store.commit(payload, store.get_generation(), "pending-decline-active").get("accepted", false)),
		"an older ACTIVE shared checkpoint is committed before its completion write fails")
	game.set("_aurora_shared_survey_checkpoint", completed.duplicate(true))
	game.set("_aurora_shared_survey_checkpoint_pending", true)
	var declined: Dictionary = game.call(&"_decline_interrupted_planetary_visits")
	_check(bool(declined.get("accepted", false))
		and store.get_snapshot().get(GameFlow.AURORA_DECLINED_SHARED_SURVEY_SLOT) == durable_completed
		and not store.get_snapshot().has(GameFlow.AURORA_SHARED_SURVEY_SLOT)
		and not bool(game.get("_aurora_shared_survey_checkpoint_pending")),
		"decline atomically preserves the newer pending COMPLETED observation instead of losing it to stored ACTIVE")
	var identical_payload := store.get_snapshot()
	identical_payload[GameFlow.AURORA_SHARED_SURVEY_SLOT] = completed.duplicate(true)
	_check(bool(store.commit(identical_payload, store.get_generation(), "pending-decline-identical-completion").get("accepted", false)),
		"an identical completed shared checkpoint reloads with durable FLOAT number types")
	game.set("_aurora_shared_survey_checkpoint", completed.duplicate(true))
	game.set("_aurora_shared_survey_checkpoint_pending", true)
	var identical: Dictionary = game.call(&"_decline_interrupted_planetary_visits")
	_check(bool(identical.get("accepted", false))
		and store.get_snapshot().get(GameFlow.AURORA_DECLINED_SHARED_SURVEY_SLOT) == durable_completed
		and not store.get_snapshot().has(GameFlow.AURORA_SHARED_SURVEY_SLOT)
		and not bool(game.get("_aurora_shared_survey_checkpoint_pending")),
		"identical live INT and persisted FLOAT completion is not a false unpaid-debt conflict")
	# Reset only this private transaction fixture to exercise no persisted slots.
	_check(bool(store.commit({"unrelated": "keep"}, store.get_generation(), "pending-decline-empty-fixture").get("accepted", false)),
		"the private pending-only fixture has no persisted planetary slot")
	game.set("_aurora_shared_survey_checkpoint", completed.duplicate(true))
	game.set("_aurora_shared_survey_checkpoint_pending", true)
	var pending_only: Dictionary = game.call(&"_decline_interrupted_planetary_visits")
	_check(bool(pending_only.get("accepted", false))
		and store.get_snapshot().get(GameFlow.AURORA_DECLINED_SHARED_SURVEY_SLOT) == durable_completed
		and not store.get_snapshot().has(GameFlow.AURORA_SHARED_SURVEY_SLOT)
		and not bool(game.get("_aurora_shared_survey_checkpoint_pending")),
		"a pending-only completion is durably archived and its writer retired without recreating an active slot")
	game.set("_aurora_shared_survey_checkpoint", {})
	game.set("_aurora_shared_survey_checkpoint_pending", true)
	var empty_retirement: Dictionary = game.call(&"_decline_interrupted_planetary_visits")
	_check(bool(empty_retirement.get("accepted", false))
		and store.get_snapshot().get(GameFlow.AURORA_DECLINED_SHARED_SURVEY_SLOT) == durable_completed
		and not bool(game.get("_aurora_shared_survey_checkpoint_pending")),
		"an empty pending retirement never erases archived unpaid completion")
	var conflicting := completed.duplicate(true)
	conflicting.survey.generation = 8
	game.set("_aurora_shared_survey_checkpoint", conflicting)
	game.set("_aurora_shared_survey_checkpoint_pending", true)
	var before := store.get_snapshot()
	var generation := store.get_generation()
	var refused: Dictionary = game.call(&"_decline_interrupted_planetary_visits")
	_check(not bool(refused.get("accepted", false)) and store.get_snapshot() == before
		and store.get_generation() == generation and bool(game.get("_aurora_shared_survey_checkpoint_pending"))
		and game.get("_aurora_shared_survey_checkpoint") == conflicting,
		"conflicting unpaid pending completion refuses atomically and keeps both obligations")
	game.set("_aurora_shared_survey_checkpoint", {})
	game.set("_aurora_shared_survey_checkpoint_pending", false)
	var visit_binding: RefCounted = game.get("_aurora_expedition_persistence_binding")
	var visit_saved: Dictionary = visit_binding.call(&"save_interrupted_visit", {
		"visit_state": "surface", "craft_home_berth_id": "crew_port_01", "on_foot": true,
		"survey": conflicting.survey,
	}, "pending-decline-conflicting-visit")
	_check(bool(visit_saved.get("accepted", false)), "the second validated unpaid visit fixture is saved")
	before = store.get_snapshot()
	generation = store.get_generation()
	var cross_refused: Dictionary = game.call(&"_decline_interrupted_planetary_visits")
	_check(not bool(cross_refused.get("accepted", false)) \
		and cross_refused.get("reason") == &"declined_survey_completion_conflict" \
		and store.get_snapshot() == before and store.get_generation() == generation,
		"contradictory unpaid Aurora visit/shared completions refuse BEFORE archiving or consuming the choice")
	game.free()


func _find_button(node: Node, prefix: String) -> Button:
	for button: Button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null


func _usable_mudds(game: GameFlow, owner_property: String) -> bool:
	var owner: RefCounted = game.get(owner_property)
	return owner.get("state") == &"idle" and game.world.visible \
		and game.phase == GameFlow.Phase.APPROACH_SHIP and game.player.is_control_enabled() \
		and game.player.is_on_floor() and not game.player.is_seated() and not game.player.is_sleeping()


func _saved_record_retained(payload: Dictionary, saved: Dictionary) -> bool:
	# The original validated record may be parked in a passive namespace, but
	# its data must remain available without granting an automatic world resume.
	return payload.values().has(saved)


func _boot(start: bool, settle := true) -> GameFlow:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	if start:
		game.start_shift()
		if settle:
			await process_frame
			await physics_frame
	return game


func _shut_down(game: GameFlow) -> void:
	game.queue_free()
	for _i in range(6):
		await process_frame
		await physics_frame


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if ok:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("%s (%d assertions)" % [SUCCESS_MARKER, _assertions])
		quit(0)
		return
	print("%s (%d failures)" % [FAILURE_MARKER, _failures.size()])
	for failure in _failures:
		print("  - ", failure)
	quit(1)
