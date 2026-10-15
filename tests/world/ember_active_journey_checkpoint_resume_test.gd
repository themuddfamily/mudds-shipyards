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
	var attached := true
	var phase_id: StringName = &"on_foot"
	var player_instance_id := 101
	var session := RefCounted.new()
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_travel_session_observation_source() -> Object: return session
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": attached,
			"generation": generation,
			"attachment_generation": attachment_generation,
			"phase_id": phase_id,
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": player_instance_id,
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
var _deny_reward := false
var _reward_receipts: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var actor := Node3D.new()
	root.add_child(actor)
	var first_store = StoreScript.new(STORE_PATH, filesystem)
	_check(bool(first_store.load().accepted), "first normal user-data store loads")
	var first_host := FakeHost.new()
	first_host.player_instance_id = actor.get_instance_id()
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
	var bunker_interaction := first_binding.get_node(
		^"OwnedSurveyBunkerInteraction"
	)
	var sample_rack_interaction := first_binding.get_node(
		^"OwnedSampleRackInteraction"
	)
	var bunker_completed := bunker_interaction.call(
		&"submit_interaction", actor, 31, 6
	) as Dictionary
	var sample_completed := sample_rack_interaction.call(
		&"submit_interaction", actor, 31, 6,
		int(first_route.get("activity_generation", -1))
	) as Dictionary
	var optional_capture := first_binding.call(
		&"capture_interrupted_relay_survey_optional_progress"
	) as Dictionary
	_check(
		bool(bunker_completed.get("accepted", false))
			and bool(sample_completed.get("accepted", false))
			and bool(optional_capture.get("accepted", false))
			and int((first_binding.get_snapshot().relay_survey.optional_progress \
				as Dictionary).completed_count) == 2,
		"both optional survey interactions are consumed before the save",
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
		"optional_progress": optional_capture.get("optional_progress", {}),
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
	var failed_filesystem := MemoryFilesystem.new()
	failed_filesystem.files = filesystem.files.duplicate(true)
	var stale_filesystem := MemoryFilesystem.new()
	stale_filesystem.files = filesystem.files.duplicate(true)
	first_flow.free()
	first_binding.queue_free()
	first_director.queue_free()
	await process_frame

	var failed_store = StoreScript.new(STORE_PATH, failed_filesystem)
	var failed_host := FakeHost.new()
	failed_host.attachment_generation = 7
	failed_host.player_instance_id = actor.get_instance_id()
	var failed_director := DirectorScript.new()
	root.add_child(failed_director)
	var failed_binding := BindingScript.new()
	root.add_child(failed_binding)
	_check(
		bool(failed_binding.configure(
			failed_host, failed_director, Callable(self, "_reward_sink"), 31
		).accepted),
		"failed-start fixture creates a fresh production composition",
	)
	var failed_flow := LifecycleFlow.new()
	failed_flow.restore_frame = _frame()
	_check(
		failed_flow.configure_runtime_settings_persistence(failed_store)
			and bool(failed_flow.bind_ember_relay_survey_persistence(
				failed_binding
			).accepted)
			and bool(failed_flow._restore_ember_surface_persistence_for_admission().accepted),
		"failed-start fixture passively stages the same saved receipt",
	)
	var conflicting_start := failed_director.start_activity(&"ember_beacon_survey")
	var rejected_resume := failed_binding.start_relay_survey()
	_check(
		bool(conflicting_start.accepted)
			and not bool(rejected_resume.accepted)
			and failed_store.get_snapshot().has("ember_relay_survey_completion")
			and int(failed_store.get_generation()) == 1
			and _reward_calls == 0,
		"a rejected ActivityDirector adoption leaves the exact receipt retryable",
	)
	failed_flow.free()
	failed_binding.queue_free()
	failed_director.queue_free()
	await process_frame

	var stale_store = StoreScript.new(STORE_PATH, stale_filesystem)
	var stale_host := FakeHost.new()
	stale_host.attachment_generation = 7
	stale_host.player_instance_id = actor.get_instance_id()
	var stale_director := DirectorScript.new()
	root.add_child(stale_director)
	var stale_binding := BindingScript.new()
	root.add_child(stale_binding)
	_check(
		bool(stale_binding.configure(
			stale_host, stale_director, Callable(self, "_reward_sink"), 31
		).accepted),
		"stale-retirement fixture creates a fresh production composition",
	)
	var stale_flow := LifecycleFlow.new()
	stale_flow.restore_frame = _frame()
	_check(
		stale_flow.configure_runtime_settings_persistence(stale_store)
			and bool(stale_flow.bind_ember_relay_survey_persistence(
				stale_binding
			).accepted)
			and bool(stale_flow._restore_ember_surface_persistence_for_admission().accepted),
		"stale-retirement fixture stages the observed store generation",
	)
	var concurrent_payload := stale_store.get_snapshot()
	concurrent_payload["foreign"] = {"retained": true}
	_check(
		bool(stale_store.commit(
			concurrent_payload, stale_store.get_generation(), "concurrent-write"
		).accepted),
		"an unrelated atomic write advances the store before retirement",
	)
	var staged_retirement: Dictionary = stale_flow.get_ember_interrupted_journey_persistence_report().restore_status.retirement_request
	var strict_stale: Dictionary = stale_binding.retire_interrupted_relay_survey_journey(
		int(staged_retirement.expected_store_generation), str(staged_retirement.expected_receipt_sha256),
		str(staged_retirement.commit_id))
	_check(not strict_stale.accepted and strict_stale.reason == &"survey_active_journey_store_generation_stale"
		and stale_store.get_generation() == 2 and stale_store.get_snapshot().foreign.retained
		and stale_store.get_snapshot().has("ember_relay_survey_completion"),
		"the strict owner API still refuses an old generation without changing the receipt or latest foreign payload")
	var owner: RefCounted = stale_binding.get("_relay_survey_persistence")
	var original_record: Dictionary = stale_store.get_snapshot().ember_relay_survey_completion.duplicate(true)
	var replacement: Dictionary = original_record.duplicate(true)
	var replacement_journey: Dictionary = replacement.completion
	replacement_journey["session_id"] = "ember_expedition_replaced"
	replacement_journey.detached_session["session_id"] = "ember_expedition_replaced"
	var adapter := PlanetaryReturnPersistenceAdapter.new()
	replacement_journey["receipt_sha256"] = adapter.call("_digest", {
		"detached_session": replacement_journey.detached_session,
		"route_identity": replacement_journey.route_identity,
		"optional_progress": replacement_journey.optional_progress})
	replacement["receipt_sha256"] = owner.call("_digest", replacement_journey)
	var changed_payload: Dictionary = stale_store.get_snapshot()
	changed_payload["ember_relay_survey_completion"] = replacement
	_check(stale_store.commit(changed_payload, stale_store.get_generation(), "replace-receipt").accepted
		and owner.call("validate_interrupted_journey_record", replacement).accepted,
		"the replacement receipt is valid and hash-consistent before the original observation fence rejects it")
	var replacement_bytes: PackedByteArray = stale_filesystem.files[STORE_PATH].duplicate()
	var replacement_refresh: Dictionary = owner.call("load_interrupted_journey", str(staged_retirement.expected_receipt_sha256))
	_check(not replacement_refresh.accepted and replacement_refresh.reason == &"survey_active_journey_receipt_mismatch"
		and stale_filesystem.files[STORE_PATH] == replacement_bytes,
		"refresh rejects a different valid receipt without retiring or rewriting it")
	var malformed: Dictionary = original_record.duplicate(true)
	malformed.completion.detached_session.checkpoint["physics_tick"] = "invalid"
	malformed.completion["receipt_sha256"] = adapter.call("_digest", {
		"detached_session": malformed.completion.detached_session,
		"route_identity": malformed.completion.route_identity,
		"optional_progress": malformed.completion.optional_progress})
	malformed["receipt_sha256"] = owner.call("_digest", malformed.completion)
	changed_payload = stale_store.get_snapshot()
	changed_payload["ember_relay_survey_completion"] = malformed
	_check(stale_store.commit(changed_payload, stale_store.get_generation(), "malformed-receipt").accepted,
		"the malformed checkpoint fixture is a real hash-consistent atomic document")
	var malformed_bytes: PackedByteArray = stale_filesystem.files[STORE_PATH].duplicate()
	var malformed_refresh: Dictionary = owner.call("load_interrupted_journey", str(staged_retirement.expected_receipt_sha256))
	_check(not malformed_refresh.accepted and stale_filesystem.files[STORE_PATH] == malformed_bytes,
		"refresh validates the full detached snapshot and refuses malformed checkpoint data without mutation")
	changed_payload = stale_store.get_snapshot()
	changed_payload["ember_relay_survey_completion"] = original_record
	_check(stale_store.commit(changed_payload, stale_store.get_generation(), "restore-original-receipt").accepted,
		"the original receipt can be restored while retaining the latest unrelated payload")
	var generation_before_start: int = stale_store.get_generation()
	var stale_resume := stale_binding.start_relay_survey()
	var stale_runtime := (
		stale_binding.get_snapshot().adapter.activity_reward as Dictionary
	)
	_check(
		bool(stale_resume.accepted)
			and stale_resume.reason == &"activity_sequence_resumed"
			and (stale_resume.persistence_retirement as Dictionary).accepted
			and int(stale_resume.persistence_refresh.store_generation) == generation_before_start
			and stale_runtime.state == &"active"
			and not stale_store.get_snapshot().has("ember_relay_survey_completion")
			and stale_store.get_generation() == generation_before_start + 1
			and stale_store.get_commit_metadata().id == "ember-active-journey-retire-%010d" % (generation_before_start + 1)
			and stale_store.get_snapshot().foreign.retained
			and int(stale_director.get_activity_snapshot(&"ember_beacon_survey").generation) == int(first_route.activity_generation)
			and int(stale_director.get_activity_snapshot(&"ember_beacon_survey").next_checkpoint_index) == 1
			and _reward_calls == 0,
		"normal Start refreshes the same receipt after unrelated commits, adopts the original checkpoint, and retires once with the current generation",
	)
	stale_flow.free()
	stale_binding.queue_free()
	stale_director.queue_free()
	await process_frame

	var second_store = StoreScript.new(STORE_PATH, filesystem)
	var second_host := FakeHost.new()
	second_host.attachment_generation = 7
	second_host.player_instance_id = actor.get_instance_id()
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
			and second_store.get_snapshot().has("ember_relay_survey_completion")
			and int(second_store.get_generation()) == 1
			and _reward_calls == 0,
		"admission stages passively and keeps the receipt until activity authority accepts",
	)

	var resumed := second_binding.start_relay_survey()
	var director_route := second_director.get_activity_snapshot(
		&"ember_beacon_survey"
	)
	var resumed_route := (
		second_binding.get_snapshot().relay_survey.mandatory_route as Dictionary
	)
	var resumed_snapshot := second_binding.get_snapshot()
	var resumed_optional := (
		resumed_snapshot.relay_survey.optional_checkpoints as Dictionary
	)
	var resumed_bunker := resumed_optional.get(
		&"ember_bunker_gantry_log", {}
	) as Dictionary
	var resumed_rack := resumed_optional.get(
		&"ember_sample_rack_analysis_log", {}
	) as Dictionary
	_check(
		bool(resumed.accepted)
			and resumed.reason == &"activity_sequence_resumed"
			and bool((resumed.get(
				"persistence_retirement", {}
			) as Dictionary).get("accepted", false))
			and int(director_route.generation) == int(first_route.activity_generation)
			and int(director_route.next_checkpoint_index) == 1
			and int(resumed_route.next_checkpoint_index) == 1
			and resumed_route.next_objective_id == &"ember_return_beacon"
			and not second_store.get_snapshot().has("ember_relay_survey_completion")
			and int(second_store.get_generation()) == 2,
		"the normal survey-start seam restores the exact director checkpoint and objective",
	)
	var bunker_replay := second_binding.get_node(
		^"OwnedSurveyBunkerInteraction"
	).call(&"submit_interaction", actor, 31, 7) as Dictionary
	var rack_replay := second_binding.get_node(
		^"OwnedSampleRackInteraction"
	).call(
		&"submit_interaction", actor, 31, 7,
		int(first_route.get("activity_generation", -1))
	) as Dictionary
	_check(
		bool(resumed_bunker.get("completed", false))
			and not bool(resumed_bunker.get("eligible", true))
			and bool(resumed_rack.get("completed", false))
			and not bool(resumed_rack.get("eligible", true))
			and int((resumed_snapshot.relay_survey.optional_progress \
				as Dictionary).completed_count) == 2
			and not bool(bunker_replay.get("accepted", false))
			and bunker_replay.reason == &"survey_interaction_already_completed"
			and not bool(rack_replay.get("accepted", false))
			and rack_replay.reason == &"sample_rack_already_completed"
			and _reward_calls == 0,
		"save-relaunch-resume retains both optional completions as ineligible without replay",
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
	var completed_route := (second_binding.get_snapshot().relay_survey.mandatory_route as Dictionary).duplicate(true)
	var completed_optional := second_binding.capture_interrupted_relay_survey_optional_progress()
	second_flow.set("_ember_surface_journey_active", true)
	second_flow.save_evidence = {
		"accepted": true, "frame": second_flow.restore_frame,
		"host": {"generation": 31, "attachment_generation": 7,
			"coordinate_frame_generation": 1, "physics_advance_count": 1440,
			"phase_id": &"on_foot"},
		"route": completed_route, "optional_progress": completed_optional.optional_progress,
		"coordinate": {"orbital_coordinate": orbital.coordinate,
			"surface_tangent_position": tangent},
	}
	var completed_saved := second_flow.save_interrupted_ember_journey()
	_check(bool(completed_saved.accepted) and completed_saved.binding_reason == &"active_journey_saved",
		"the normal save boundary retains completed unpaid route and both optional observations")
	await _test_completed_unpaid_resume(actor, completed_route, completed_optional.optional_progress,
		second_director, filesystem)
	second_flow.free()
	second_binding.queue_free()
	second_director.queue_free()
	await process_frame

	var fresh_host := FakeHost.new()
	fresh_host.player_instance_id = actor.get_instance_id()
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
	actor.queue_free()
	await process_frame

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_ACTIVE_JOURNEY_CHECKPOINT_RESUME_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _test_completed_unpaid_resume(
		actor: Node3D, completed_route: Dictionary, optional_progress: Dictionary,
		completed_director: ActivityDirector, filesystem: MemoryFilesystem
	) -> void:
	var facade := EmberSurfaceRelaySurveyActivity.new()
	# The archive crosses JSON, so accept integral JSON numbers but never coerced
	# booleans, strings, fractional values or nonfinite progress.
	var route: Dictionary = JSON.parse_string(JSON.stringify(completed_route))
	var malformed: Array[Dictionary] = []
	for field in ["activity_generation", "checkpoint_count", "next_checkpoint_index"]:
		for value in [true, "2", 1.5, NAN, INF, -1, 2147483648]:
			var changed := route.duplicate(true)
			changed[field] = value
			malformed.append(changed)
	for value in [false, "true", 1]:
		var changed := route.duplicate(true)
		changed["complete"] = value
		malformed.append(changed)
	var forged_authority := route.duplicate(true)
	forged_authority["authority"] = {"navigation": false, "movement": false, "reward": true}
	malformed.append(forged_authority)
	var old_objective := route.duplicate(true)
	old_objective["next_objective_id"] = "ember_return_beacon"
	malformed.append(old_objective)
	_check(bool(facade.validate_completed_mandatory_route_resume(route).accepted)
		and not bool(facade.validate_mandatory_route_resume(route).accepted),
		"completed unpaid route has a separate strict admission and never broadens ACTIVE resume")
	var conflicting_runtime := PlanetaryActivityRewardRuntime.new()
	conflicting_runtime.bind(completed_director, Callable(self, "_reward_sink"))
	var completed_state := completed_director.capture_activity_persistence_state(&"ember_beacon_survey")
	var retained_director := completed_director.get_activity_snapshot(&"ember_beacon_survey")
	_check(not bool(conflicting_runtime.resume_completed_activity(
		&"ember_beacon_survey", completed_state, 31, 8).accepted)
		and completed_director.get_activity_snapshot(&"ember_beacon_survey") == retained_director
		and conflicting_runtime.get_snapshot().state == &"ready",
		"completed adoption cannot overwrite an existing earned Director route")
	var retry_filesystem := MemoryFilesystem.new()
	retry_filesystem.files = filesystem.files.duplicate(true)
	var retry_store = StoreScript.new(STORE_PATH, retry_filesystem)
	_check(bool(retry_store.load().accepted), "completed optional retry reloads the actual primary document")
	var persistence := EmberRelaySurveyPersistenceBinding.new()
	var configured := persistence.configure(retry_store, &"ember_relay_survey_completion")
	var declined := persistence.plan_decline(retry_store.get_snapshot())
	_check(bool(configured.accepted) and bool(declined.accepted)
		and bool(retry_store.commit(declined.payload, retry_store.get_generation(), "decline-completed-optionals").accepted)
		and not retry_store.get_snapshot().has("ember_relay_survey_completion")
		and bool(persistence.load_declined_completion().accepted),
		"the persistence owner archives the real completed document before a fresh visit")
	var host := FakeHost.new()
	host.generation = 1
	host.attachment_generation = 1
	host.player_instance_id = actor.get_instance_id()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	_check(bool(binding.configure(host, director, Callable(self, "_reward_sink"), 1).accepted),
		"completed retry binds a fresh ordinary Host and Director composition")
	var flow := LifecycleFlow.new()
	_check(flow.configure_runtime_settings_persistence(retry_store)
		and bool(flow.bind_ember_relay_survey_persistence(binding).accepted),
		"fresh completed retry binds the ordinary persistence consumer")
	var adapter := binding.get("_adapter") as PlanetarySurfaceActivityRewardAdapter
	var before_adapter := adapter.get_snapshot()
	var before_director := director.get_activity_snapshot(&"ember_beacon_survey")
	var rejected_all := true
	for candidate in malformed:
		rejected_all = rejected_all and not bool(facade.resume_completed_mandatory_route(adapter, candidate).accepted)
	host.attached = false
	var detached := facade.resume_completed_mandatory_route(adapter, route)
	host.attached = true
	host.phase_id = &"inside_cabin"
	var not_on_foot := facade.resume_completed_mandatory_route(adapter, route)
	host.phase_id = &"on_foot"
	host.generation = 0
	var invalid_generation := facade.resume_completed_mandatory_route(adapter, route)
	host.generation = 1
	_check(rejected_all and not bool(detached.accepted) and not bool(not_on_foot.accepted)
		and not bool(invalid_generation.accepted) and adapter.get_snapshot() == before_adapter
		and director.get_activity_snapshot(&"ember_beacon_survey") == before_director,
		"malformed completion and unavailable or stale Host leave route, runtime and sequence untouched")
	var signals: Array[StringName] = []
	director.activity_started.connect(func(_id: StringName, _generation: int) -> void: signals.append(&"started"))
	director.activity_checkpoint_reached.connect(func(_id: StringName, _index: int, _generation: int) -> void: signals.append(&"checkpoint"))
	director.activity_completed.connect(func(_id: StringName, _generation: int) -> void: signals.append(&"completed"))
	var bunker := binding.get_node(^"OwnedSurveyBunkerInteraction")
	var rack := binding.get_node(^"OwnedSampleRackInteraction")
	bunker.connect(&"survey_completed", func(_receipt: Dictionary) -> void: signals.append(&"bunker"))
	rack.connect(&"sample_rack_completed", func(_receipt: Dictionary) -> void: signals.append(&"rack"))
	var reward_calls_before := _reward_calls
	var admitted := flow._restore_ember_surface_persistence_for_admission()
	_check(bool(admitted.accepted) and admitted.persistence_kind == &"declined_completion"
		and not bool(admitted.location_resumed)
		and director.get_activity_snapshot(&"ember_beacon_survey").is_empty(),
		"fresh admission stages the completed archive without adopting old position, session or route")
	var resumed := binding.start_relay_survey()
	var pending: Dictionary = adapter.get_activity_reward_snapshot().pending_reward.duplicate(true)
	_check(bool(resumed.accepted) and adapter.get_activity_reward_snapshot().state == &"awaiting_reward"
		and int(pending.activity_generation) == int(route.activity_generation)
		and int(pending.run_generation) == 1 and int(pending.attachment_generation) == 1
		and signals.is_empty() and _reward_calls == reward_calls_before
		and bool(binding.get_snapshot().relay_survey.mandatory_route.complete),
		"Director adopts completed progress without replay and rebuilds only current-generation unpaid handoff")
	var restored_picture := binding.get_snapshot()
	var saved_checkpoints := optional_progress.checkpoints as Dictionary
	_check(bool(resumed.get("optional_progress_restore", {}).get("accepted", false))
		and int(restored_picture.relay_survey.optional_progress.completed_count) == 2
		and bool(restored_picture.survey_interaction.completed)
		and bool(restored_picture.sample_rack_interaction.completed)
		and restored_picture.survey_interaction.last_receipt == saved_checkpoints.ember_bunker_gantry_log.receipt
		and restored_picture.sample_rack_interaction.last_receipt == saved_checkpoints.ember_sample_rack_analysis_log.receipt
		and not bool(restored_picture.relay_survey.optional_checkpoints.ember_bunker_gantry_log.eligible)
		and not bool(restored_picture.relay_survey.optional_checkpoints.ember_sample_rack_analysis_log.eligible),
		"fresh Host with smaller counters restores both real markers and exact passive optional provenance")
	var bunker_replay: Dictionary = bunker.call(&"submit_interaction", actor, 1, 1)
	var rack_replay: Dictionary = rack.call(&"submit_interaction", actor, 1, 1, int(route.activity_generation))
	_check(not bool(bunker_replay.accepted) and not bool(rack_replay.accepted)
		and signals.is_empty() and _reward_calls == reward_calls_before,
		"restored physical optional markers refuse interaction replay without signals or rewards")
	host.generation = 2
	var stale_commit := facade.commit_reward(adapter)
	host.generation = 1
	_deny_reward = true
	var refused := facade.commit_reward(adapter)
	_deny_reward = false
	_check(not bool(stale_commit.accepted) and not bool(refused.accepted)
		and adapter.get_activity_reward_snapshot().state == &"awaiting_reward"
		and adapter.get_activity_reward_snapshot().pending_reward == pending
		and _reward_calls == reward_calls_before + 1,
		"stale Host cannot pay and an ordinary denied reward sink retains exact unpaid debt")
	var paid := binding.commit_relay_survey_reward()
	var repeated := binding.commit_relay_survey_reward()
	_check(bool(paid.accepted) and not bool(repeated.accepted)
		and adapter.get_activity_reward_snapshot().state == &"completed"
		and adapter.get_activity_reward_snapshot().pending_reward.is_empty()
		and _reward_calls == reward_calls_before + 2 and _reward_receipts.back() == pending
		and signals.is_empty(),
		"ordinary commit retries completed debt once, then refuses duplicate payment without historical signals")
	var terminal := persistence.load()
	_check(bool(paid.get("persistence", {}).get("accepted", false)) and bool(terminal.accepted)
		and bool(terminal.completion.optional_checkpoint.completed)
		and int(terminal.completion.optional_checkpoint.source_run_generation) == 31
		and int(terminal.completion.optional_checkpoint.source_attachment_generation) == 6
		and not bool(terminal.reward_replay_allowed),
		"the real terminal save and reload retain the old optional observation after fresh-visit reward commitment")
	flow.free()
	binding.queue_free()
	director.queue_free()
	await process_frame


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


func _reward_sink(receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	_reward_receipts.append(receipt.duplicate(true))
	if _deny_reward:
		return {"accepted": false, "reason": &"test_reward_write_refused"}
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
