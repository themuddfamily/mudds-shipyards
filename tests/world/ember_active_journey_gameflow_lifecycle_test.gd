extends SceneTree

const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const ContractScript := preload("res://scripts/world/planetary_save_session_contract.gd")
const PersistenceScript := preload(
	"res://scripts/persistence/ember_relay_survey_persistence_binding.gd"
)
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")
const SurfaceBindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RecoveryBridgeScript := preload("res://scripts/diagnostics/session_diagnostic_lifecycle_bridge.gd")
const RewardAuthorityScript := preload("res://scripts/game/game_flow_reward_authority.gd")
const RewardWrapperScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

const STORE_PATH := "memory://ember-active-gameflow.json"
const SLOT: StringName = &"ember_relay_survey_completion"


class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	var reject_writes := false
	var writes_until_refusal := -1
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
		if reject_writes or writes_until_refusal == 0:
			return ERR_CANT_CREATE
		if writes_until_refusal > 0:
			writes_until_refusal -= 1
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


class PersistenceForwarder extends RefCounted:
	var persistence: RefCounted
	var save_calls := 0
	var terminal_load_calls := 0
	var active_load_calls := 0
	var retire_calls := 0
	var stage_calls := 0

	func configure_relay_survey_persistence(
		store: RefCounted, slot_id: StringName
	) -> Dictionary:
		persistence = PersistenceScript.new() as RefCounted
		return persistence.call(&"configure", store, slot_id) as Dictionary

	func save_interrupted_relay_survey_journey(
		session_contract: Object, route: Variant, commit_id: String
	) -> Dictionary:
		save_calls += 1
		return persistence.call(
			&"save_interrupted_journey", session_contract, route, commit_id
		) as Dictionary

	func restore_relay_survey_persistence() -> Dictionary:
		terminal_load_calls += 1
		return persistence.call(&"load") as Dictionary

	func load_interrupted_relay_survey_journey() -> Dictionary:
		active_load_calls += 1
		return persistence.call(&"load_interrupted_journey") as Dictionary

	func retire_interrupted_relay_survey_journey(
		expected_generation: int, digest: String, commit_id: String
	) -> Dictionary:
		retire_calls += 1
		return persistence.call(
			&"retire_interrupted_journey",
			expected_generation,
			digest,
			commit_id
		) as Dictionary

	func stage_interrupted_relay_survey_resume(
		route_identity: Variant, retirement_request: Variant
	) -> Dictionary:
		stage_calls += 1
		return {
			"accepted": route_identity is Dictionary \
				and retirement_request is Dictionary,
			"reason": &"relay_survey_resume_staged",
			"receipt_retirement_deferred": true,
		}


class TerminalForwarder extends RefCounted:
	func configure_relay_survey_persistence(
		_store: RefCounted, _slot_id: StringName
	) -> Dictionary:
		return {"accepted": true, "reason": &"survey_persistence_configured"}

	func restore_relay_survey_persistence() -> Dictionary:
		return {
			"accepted": true,
			"reason": &"survey_completion_restored",
			"completion": {"activity_id": &"ember_beacon_survey"},
			"reward_replay_allowed": false,
		}


class LifecycleFlow extends GameFlowScript:
	var save_evidence: Dictionary = {}
	var restore_frame: RefCounted

	func _collect_ember_interrupted_journey_save_evidence() -> Dictionary:
		return save_evidence.duplicate(true)

	func _get_ember_interrupted_journey_restore_frame() -> Object:
		return restore_frame


class RecoveryChoiceBridge extends RecoveryBridgeScript:
	var receipt := {"session_id": 51, "startup_generation": 4}
	func _init() -> void: super(null, null, null)
	func get_recovery_available_snapshot() -> Dictionary: return receipt.duplicate(true)
	func discard_recovery() -> Dictionary:
		receipt.clear()
		return {"accepted": true, "reason": &"recovery_discarded"}


class SurfaceHost extends EmberSurfaceLoopHost:
	var session := RefCounted.new()
	var actor_id := 0
	var craft_id := 0
	var run_generation := 31
	var attachment := 7
	var staged_phase := EmberSurfaceLoopHost.Phase.ON_FOOT
	func get_generation() -> int: return run_generation
	func get_attachment_generation() -> int: return attachment
	func get_phase() -> int: return staged_phase
	func get_travel_session_observation_source() -> Object: return session
	func get_return_status_snapshot() -> Dictionary: return get_snapshot()
	func get_snapshot() -> Dictionary:
		var phase_id: StringName = &"on_foot"
		if staged_phase == EmberSurfaceLoopHost.Phase.LANDED:
			phase_id = &"landed"
		elif staged_phase == EmberSurfaceLoopHost.Phase.IDLE:
			phase_id = &"idle"
		return {"host_id": &"ember_surface_loop", "attached": true,
			"generation": run_generation, "attachment_generation": attachment,
			"phase_id": phase_id,
			"identities": {"world_id": &"ember_moon",
				"player_instance_id": actor_id, "ship_instance_id": craft_id}}


var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var first_store = StoreScript.new(STORE_PATH, filesystem)
	_check(bool(first_store.load().accepted), "the normal Main store loads")
	_check(
		bool(first_store.commit({"foreign": {"retained": 91}}, 0, "seed").accepted),
		"unrelated user data exists before the Ember save boundary",
	)
	var first_binding := PersistenceForwarder.new()
	var first_flow := LifecycleFlow.new()
	_check(
		first_flow.configure_runtime_settings_persistence(first_store)
			and bool(first_flow.bind_ember_relay_survey_persistence(first_binding).accepted),
		"GameFlow and Ember use the same caller-owned store",
	)
	first_flow.set("_ember_surface_journey_active", true)
	var frame = _frame()
	var tangent := Vector3(24.0, 8.0, -13.0)
	var body_local: Dictionary = frame.surface_tangent_to_body_local(tangent, 1)
	var orbital: Dictionary = frame.body_local_to_orbital_position(
		body_local.position as Vector3, 1
	)
	first_flow.save_evidence = {
		"accepted": true,
		"reason": &"ember_active_journey_evidence_ready",
		"frame": frame,
		"host": {
			"generation": 31,
			"attachment_generation": 6,
			"coordinate_frame_generation": 1,
			"physics_advance_count": 1440,
			"phase_id": &"on_foot",
		},
		"route": _route(),
		"coordinate": {
			"orbital_coordinate": orbital.coordinate,
			"surface_tangent_position": tangent,
		},
	}
	var saved := first_flow.save_interrupted_ember_journey()
	_check(
		bool(saved.get("accepted", false))
			and saved.binding_reason == &"active_journey_saved"
			and first_binding.save_calls == 1
			and int(first_store.get_generation()) == 2
			and int((first_store.get_snapshot().foreign as Dictionary).retained) == 91,
		"the normal GameFlow save boundary atomically stores one detached journey",
	)
	var allocation := first_flow._get_ember_cold_visit_recovery_generations()
	_check(allocation.get("accepted", false) and allocation.generations == {
		"run_generation": 1, "attachment_generation": 6}
		and int(first_store.get_generation()) == 2 and first_binding.active_load_calls == 0,
		"cold allocation validates the existing legacy receipt without consuming it or its store generation")
	for value: Variant in [1, 1.0, 7, 7.0]:
		_check(GameFlowScript._ember_cold_recovery_generation_is_valid(value),
			"cold saved counters preserve integral JSON numeric values")
	for value: Variant in [null, true, "7", 0, -1, 7.5, NAN, INF, PlanetaryTravelSession.MAX_SAFE_GENERATION]:
		_check(not GameFlowScript._ember_cold_recovery_generation_is_valid(value),
			"cold saved counters refuse malformed or exhausted values before integer conversion")
	# Hash-consistent malformed optional counters reach the actual GameFlow
	# inspector; typed Session arguments alone would hide coercion defects.
	for saved_run: Variant in [7.0, "7", 7.5, true, 0, PlanetaryTravelSession.MAX_SAFE_GENERATION]:
		var payload := first_store.get_snapshot()
		var record := payload[String(SLOT)] as Dictionary
		var journey := record.completion as Dictionary
		journey["optional_progress"] = {"source_run_generation": saved_run,
			"source_attachment_generation": 6.0}
		journey["receipt_sha256"] = PlanetaryReturnPersistenceAdapter.new().call("_digest", {
			"detached_session": journey.detached_session, "route_identity": journey.route_identity,
			"optional_progress": journey.optional_progress})
		record["receipt_sha256"] = PersistenceScript.new().call("_digest", journey)
		var isolated := StoreScript.new("memory://cold-counter-check.json", MemoryFilesystem.new())
		isolated.load()
		_check(isolated.commit(payload, 0, "counter-inspection").accepted,
			"the malformed-counter fixture uses a real atomic store commit")
		var inspecting_flow := LifecycleFlow.new()
		inspecting_flow.configure_runtime_settings_persistence(isolated)
		var inspected := inspecting_flow._get_ember_cold_visit_recovery_generations()
		_check(inspected.get("accepted", false) == (saved_run is float and saved_run == 7.0),
			"the actual store inspector accepts integral JSON epochs and refuses hash-consistent malformed sources")
		_check(isolated.get_generation() == 1,
			"counter inspection never mutates the persisted receipt")
		inspecting_flow.free()
	first_flow.free()
	# Independent disk image: the original Resume assertions below still consume
	# exactly the same interrupted receipt through their unchanged admission seam.
	await _exercise_start_fresh(filesystem.files.duplicate(true))

	var second_store = StoreScript.new(STORE_PATH, filesystem)
	var second_binding := PersistenceForwarder.new()
	var second_flow := LifecycleFlow.new()
	_check(
		second_flow.configure_runtime_settings_persistence(second_store)
			and bool(second_flow.bind_ember_relay_survey_persistence(second_binding).accepted),
		"a relaunched Main binds the same production persistence slot",
	)
	# A fresh process can use a newer origin and a different local surface basis.
	# The saved absolute point, rather than its old tangent coordinates, survives.
	var current_frame: PlanetaryCoordinateFrame = _frame(Vector3.RIGHT)
	second_flow.restore_frame = current_frame
	var rebase: Dictionary = current_frame.request_rebase(Vector3(5_000.0, 0, 0), 1)
	_check(rebase.accepted and current_frame.commit_rebase(int(rebase.request.request_id), 1).accepted,
		"the fresh recovery frame advances its real origin generation")
	var saved_boundary := (first_store.get_snapshot()[String(SLOT)] as Dictionary).completion.detached_session as Dictionary
	var strict_contract := ContractScript.new(&"ember_moon", current_frame)
	_check(strict_contract.restore_detached_snapshot(saved_boundary, 7, 2).reason == &"surface_checkpoint_generation_mismatch",
		"direct restore continues to reject the old surface frame generation")
	var saved_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var admission_restore := second_flow._restore_ember_surface_persistence_for_admission()
	var recovery := admission_restore.get("recovery", {}) as Dictionary
	var contract := admission_restore.get("contract", {}) as Dictionary
	var route := admission_restore.get("route_identity", {}) as Dictionary
	var authority := admission_restore.get("authority", {}) as Dictionary
	var checkpoint_resume := admission_restore.get("checkpoint_resume", {}) as Dictionary
	var restored_checkpoint := contract.get("checkpoint", {}) as Dictionary
	var current_tangent: Array = restored_checkpoint.get("surface_tangent_meters", [])
	var restored_position := {"accepted": false}
	if current_tangent.size() == 3:
		restored_position = current_frame.surface_tangent_to_body_local(
			Vector3(current_tangent[0], current_tangent[1], current_tangent[2]), 2)
	_check(restored_position.accepted and (restored_position.position as Vector3).is_equal_approx(body_local.position as Vector3)
		and current_tangent != [float(tangent.x), float(tangent.y), float(tangent.z)]
		and int(contract.frame_generation) == 2 and int(restored_checkpoint.frame_generation) == 2
		and restored_checkpoint.orbital_coordinate == saved_boundary.checkpoint.orbital_coordinate
		and int(contract.checkpoint_generation) == int(saved_boundary.checkpoint_generation)
		and int(contract.physics_tick) == int(saved_boundary.physics_tick)
		and restored_checkpoint.payload == saved_boundary.checkpoint.payload
		and filesystem.files[STORE_PATH] == saved_bytes,
		"passive recovery reexpresses the same absolute checkpoint in the current basis while preserving progress and the original receipt bytes")
	_check(
		bool(admission_restore.get("accepted", false))
			and admission_restore.reason == &"ember_active_journey_passively_adopted"
			and admission_restore.persistence_kind == &"interrupted_journey"
			and recovery.session_id == &"ember_expedition_0000000031_0000000044"
			and recovery.phase_id == &"surface"
			and recovery.journey_phase_id == &"on_foot"
			and contract.state == "active"
			and int(contract.attachment_generation) == 7
			and int(route.next_checkpoint_index) == 1
			and route.next_objective_id == "ember_return_beacon"
			and bool(checkpoint_resume.get("accepted", false))
			and bool(checkpoint_resume.get(
				"receipt_retirement_deferred", false
			)),
		"normal admission adopts the exact session, phase, and mandatory route passively",
	)
	_check(
		second_binding.terminal_load_calls == 1
			and second_binding.active_load_calls == 1
			and second_binding.retire_calls == 0
			and second_binding.stage_calls == 1
			and authority.size() == 5
			and not bool(authority.movement)
			and not bool(authority.actor)
			and not bool(authority.activity)
			and not bool(authority.reward)
			and not bool(authority.berth),
		"the slot marker selects one passive load/retire path with zero gameplay authority",
	)
	var report := second_flow.get_ember_interrupted_journey_persistence_report()
	_check(
		bool(report.adopted)
			and bool(report.restore_attempted)
			and report.restore_status == admission_restore
			and bool(report.restore_status.checkpoint_resume.get("accepted", false))
			and int(second_store.get_generation()) == 2
			and second_store.get_snapshot().has(String(SLOT))
			and int((second_store.get_snapshot().foreign as Dictionary).retained) == 91,
		"passive admission exposes its complete staging result and retains the slot until activity resumes",
	)
	var replay := second_flow._restore_ember_surface_persistence_for_admission()
	_check(
		not bool(replay.get("accepted", false))
			and replay.reason == &"ember_active_journey_restore_already_attempted"
			and second_binding.active_load_calls == 1
			and second_binding.retire_calls == 0
			and second_binding.stage_calls == 1,
		"a later admission cannot replay the staged route before retirement",
	)
	second_flow.free()

	var terminal_flow := LifecycleFlow.new()
	var terminal_binding := TerminalForwarder.new()
	_check(
		terminal_flow.configure_runtime_settings_persistence(second_store)
			and bool(terminal_flow.bind_ember_relay_survey_persistence(
				terminal_binding
			).accepted),
		"a terminal-only fixture binds through the unchanged admission seam",
	)
	var terminal_restore := terminal_flow._restore_ember_surface_persistence_for_admission()
	_check(
		bool(terminal_restore.accepted)
			and terminal_restore.reason == &"survey_completion_restored"
			and not terminal_restore.has("persistence_kind")
			and not bool(terminal_restore.reward_replay_allowed),
		"terminal completion keeps its existing result shape and cannot enter active recovery",
	)
	terminal_flow.free()
	await _exercise_paid_start_fresh()
	await _exercise_completed_debt()
	await _exercise_active_payment()
	await _exercise_explicit_abandon()

	for failure in _failures:
		push_error(failure)
	var result_marker: String = "EMBER_ACTIVE_JOURNEY_GAMEFLOW_LIFECYCLE_TEST_OK" \
		if _failures.is_empty() else "EMBER_ACTIVE_JOURNEY_GAMEFLOW_LIFECYCLE_TEST_FAILED"
	print(
		"%s: %d assertions" % [result_marker, _assertions]
	)
	quit(0 if _failures.is_empty() else 1)


func _exercise_start_fresh(saved_files: Dictionary) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = saved_files
	var store := StoreScript.new(STORE_PATH, filesystem)
	var loaded: Dictionary = store.load()
	_check(loaded.accepted, "Start Fresh observes the loaded primary store, as production startup does")
	if not loaded.accepted:
		return
	var choice_flow := LifecycleFlow.new()
	var forwarder := PersistenceForwarder.new()
	_check(choice_flow.configure_runtime_settings_persistence(store)
		and choice_flow.bind_ember_relay_survey_persistence(forwarder).accepted,
		"Start Fresh binds the real saved Ember record before activity admission")
	choice_flow.bind_aurora_expedition_persistence()
	choice_flow.bind_rime_expedition_persistence()
	var before: Dictionary = store.get_snapshot()
	var bridge := RecoveryChoiceBridge.new()
	choice_flow.set("_session_diagnostics_bridge", bridge)
	var choice: Dictionary = choice_flow._handle_hud_session_recovery_choice(&"discard", 51, 4)
	_check(choice.accepted and bridge.get_recovery_available_snapshot().is_empty(),
		"the actual fenced Start Fresh choice succeeds before a later Ember admission")
	_check(store.get_snapshot().get("foreign") == before.get("foreign"),
		"Start Fresh preserves unrelated durable data")
	choice_flow.free()
	if not choice.accepted:
		return
	var cold_store := StoreScript.new(STORE_PATH, filesystem)
	var surface := await _make_surface(cold_store)
	var flow: GameFlow = surface.flow
	var binding: Node = surface.binding
	var admission: Dictionary = flow._restore_ember_surface_persistence_for_admission()
	_check(not flow.get_ember_interrupted_journey_persistence_report().adopted
		and not admission.get("checkpoint_resume", {}).get("accepted", false),
		"a cold admission after Start Fresh does not adopt or stage the declined incomplete survey")
	var started: Dictionary = binding.call(&"start_relay_survey")
	var route: Dictionary = (binding.call(&"get_snapshot") as Dictionary).relay_survey.mandatory_route
	_check(started.accepted and int(route.next_checkpoint_index) == 0
		and route.next_objective_id == &"ember_relay_tower" and _reward_calls == 0,
		"ordinary survey start after Start Fresh begins at the first beacon without a reward")
	await _retire_surface(surface)
	var second_cold := await _make_surface(StoreScript.new(STORE_PATH, filesystem))
	var second_admission: Dictionary = (second_cold.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
	_check(not (second_cold.flow as GameFlow).get_ember_interrupted_journey_persistence_report().adopted
		and not second_admission.get("checkpoint_resume", {}).get("accepted", false),
		"another cold boot still ignores the archived incomplete route")
	await _retire_surface(second_cold)


func _exercise_paid_start_fresh() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new(STORE_PATH, filesystem)
	store.load()
	var surface := await _make_surface(store)
	var binding: Node = surface.binding
	var started: Dictionary = binding.call(&"start_relay_survey")
	var relay: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0))
	var returned: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0))
	var paid: Dictionary = binding.call(&"commit_relay_survey_reward")
	_check(started.accepted and relay.accepted and returned.accepted and paid.accepted
		and paid.persistence.accepted and _reward_calls == 1,
		"the paid control earns and persists a real terminal survey receipt")
	if not paid.get("accepted", false) or not paid.get("persistence", {}).get("accepted", false):
		await _retire_surface(surface)
		return
	var before: Dictionary = store.get_snapshot()
	var flow: GameFlow = surface.flow
	flow.set("_session_diagnostics_bridge", RecoveryChoiceBridge.new())
	var choice: Dictionary = flow._handle_hud_session_recovery_choice(&"discard", 51, 4)
	_check(choice.accepted and store.get_snapshot() == before,
		"Start Fresh leaves the already-paid Ember terminal receipt unchanged")
	await _retire_surface(surface)
	var cold := await _make_surface(StoreScript.new(STORE_PATH, filesystem))
	var restored: Dictionary = (cold.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
	_check(restored.accepted and restored.reason == &"survey_completion_restored"
		and not restored.reward_replay_allowed and _reward_calls == 1,
		"cold paid-receipt admission remains readable without replaying a reward")
	await _retire_surface(cold)


func _exercise_completed_debt() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new(STORE_PATH, filesystem)
	# A genuinely earlier paid survey must not act as a global one-shot guard
	# against this repeatable activity's later completed obligation.
	var prior := await _make_surface(store, true, 1, 1)
	var prior_binding: Node = prior.binding
	prior_binding.call(&"start_relay_survey")
	prior_binding.call(&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0))
	prior_binding.call(&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0))
	var prior_payment := await _pay_surface(prior)
	_check(prior_payment.is_empty() and int(store.get_snapshot().game_flow_reward_store.reward_counts.ember_beacon_data) == 1,
		"an earlier actual evidenced Ember payment exists before the new debt (result: %s)" % prior_payment)
	await _retire_surface(prior)
	if not prior_payment.is_empty():
		return
	var earned := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true, 1, 1)
	store = (earned.flow as GameFlow).get("_runtime_settings_user_data_store")
	var binding: Node = earned.binding
	var started: Dictionary = binding.call(&"start_relay_survey")
	var relay: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0))
	var returned: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0))
	_check(started.accepted and relay.accepted and returned.accepted
		and (binding.call(&"get_activity_reward_snapshot") as Dictionary).state == &"awaiting_reward",
		"real new route observations create completed unpaid work without invoking payment")
	if not started.accepted or not relay.accepted or not returned.accepted:
		await _retire_surface(earned)
		return
	var saved := _save_surface_progress(earned)
	_check(saved.accepted and store.get_snapshot().has(String(SLOT)),
		"ordinary interrupted-journey save persists the actual completed unpaid route")
	if not saved.accepted or not store.get_snapshot().has(String(SLOT)):
		await _retire_surface(earned)
		return
	var flow: GameFlow = earned.flow
	var bridge := RecoveryChoiceBridge.new()
	flow.set("_session_diagnostics_bridge", bridge)
	var before: Dictionary = store.get_snapshot()
	var generation: int = store.get_generation()
	filesystem.reject_writes = true
	var refused: Dictionary = flow._handle_hud_session_recovery_choice(&"discard", 51, 4)
	filesystem.reject_writes = false
	_check(not refused.accepted and not bridge.get_recovery_available_snapshot().is_empty()
		and store.get_generation() == generation and store.get_snapshot() == before,
		"a rejected Start Fresh write retains the actual notice, complete debt and ledger")
	var retry: Dictionary = flow._handle_hud_session_recovery_choice(&"discard", 51, 4)
	var archive := String(SLOT) + "_declined"
	_check(retry.accepted and bridge.get_recovery_available_snapshot().is_empty()
		and not store.get_snapshot().has(String(SLOT)) and store.get_snapshot().has(archive),
		"retry of the same actual choice atomically archives completed debt")
	if not retry.accepted or not store.get_snapshot().has(archive):
		await _retire_surface(earned)
		return
	var archived: Dictionary = store.get_snapshot()[archive]
	var disk_before: Dictionary = store.get_snapshot()
	# Two individually valid receipts with the same activity generation but a
	# different detached physical checkpoint are distinct obligations.
	var conflict: Dictionary = archived.duplicate(true)
	conflict.completion.detached_session.checkpoint.payload["fixture_conflict"] = "different checkpoint"
	var persistence := PersistenceScript.new()
	persistence.configure(store, SLOT)
	var conflicting_evidence := {
		"detached_session": conflict.completion.detached_session,
		"route_identity": conflict.completion.route_identity}
	if conflict.completion.has("optional_progress"):
		conflicting_evidence["optional_progress"] = conflict.completion.optional_progress
	conflict.completion.receipt_sha256 = PlanetaryReturnPersistenceAdapter.new().call("_digest", conflicting_evidence)
	conflict.receipt_sha256 = persistence.call("_digest", conflict.completion)
	var conflict_payload := disk_before.duplicate(true)
	conflict_payload[String(SLOT)] = conflict
	_check(persistence.validate_interrupted_journey_record(conflict).accepted,
		"the same-generation conflict is a valid distinct saved receipt")
	var collision: Dictionary = persistence.plan_decline(conflict_payload)
	_check(not collision.accepted and store.get_snapshot() == disk_before,
		"a distinct same-generation completed obligation cannot replace archived debt")
	await _retire_surface(earned)
	var cold := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true, 1, 1)
	store = (cold.flow as GameFlow).get("_runtime_settings_user_data_store")
	var admission: Dictionary = (cold.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
	_check(admission.accepted and admission.persistence_kind == &"declined_completion"
		and not admission.location_resumed
		and not (cold.flow as GameFlow).get_ember_interrupted_journey_persistence_report().adopted,
		"cold new arrival stages only completed observations, without restoring the declined location or contract")
	if not admission.accepted:
		await _retire_surface(cold)
		return
	var adopted: Dictionary = (cold.binding as Node).call(&"start_relay_survey")
	var runtime: Dictionary = (cold.binding as Node).call(&"get_activity_reward_snapshot")
	_check(adopted.accepted and runtime.state == &"awaiting_reward"
		and store.get_snapshot()[archive] == archived
		and int(store.get_snapshot().game_flow_reward_store.reward_counts.ember_beacon_data) == 1,
		"new run-one attachment-one start restores awaiting reward without retiring or paying the archived completion")
	if not adopted.accepted or runtime.state != &"awaiting_reward":
		await _retire_surface(cold)
		return
	var unpaid: Dictionary = store.get_snapshot()
	var resaved: Dictionary = _save_surface_progress(cold)
	_check(resaved.accepted and store.get_snapshot() == unpaid,
		"an ordinary shutdown save retains the exact original completed receipt after fresh admission")
	generation = store.get_generation()
	filesystem.reject_writes = true
	var rejected_payment := await _pay_surface(cold)
	filesystem.reject_writes = false
	_check(not rejected_payment.is_empty() and store.get_snapshot() == unpaid
		and store.get_generation() == generation
		and (cold.binding.call(&"get_activity_reward_snapshot") as Dictionary).state == &"awaiting_reward",
		"real evidenced payment rejection preserves archive, ledger and retryable completion")
	# Permit exactly the reward CAS, then reject the later best-effort terminal
	# presentation save: this is the crash window between those durable writes.
	filesystem.writes_until_refusal = 1
	var interrupted_payment := await _pay_surface(cold)
	filesystem.writes_until_refusal = -1
	var paid_payload: Dictionary = store.get_snapshot()
	_check(interrupted_payment == &"relay_reward_persistence_commit_rejected"
		and not paid_payload.has(archive) and not paid_payload.has(String(SLOT))
		and int(paid_payload.game_flow_reward_store.reward_counts.ember_beacon_data) == 2,
		"the reward CAS removes debt and increments the existing ledger even if terminal save then fails")
	await _retire_surface(cold)
	var after_crash := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true, 1, 1)
	var after_store: RefCounted = (after_crash.flow as GameFlow).get("_runtime_settings_user_data_store")
	var no_debt: Dictionary = (after_crash.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
	var fresh: Dictionary = after_crash.binding.call(&"start_relay_survey")
	_check(no_debt.get("persistence_kind", &"") != &"declined_completion" and fresh.accepted
		and (after_crash.binding.call(&"get_activity_reward_snapshot") as Dictionary).state == &"active"
		and int(after_store.get_snapshot().game_flow_reward_store.reward_counts.ember_beacon_data) == 2,
		"cold boot after payment but before terminal save cannot replay the already-paid debt")
	await _retire_surface(after_crash)


func _exercise_active_payment() -> void:
	var filesystem := MemoryFilesystem.new()
	var surface := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
	var binding: Node = surface.binding
	var store: RefCounted = (surface.flow as GameFlow).get("_runtime_settings_user_data_store")
	var started: Dictionary = binding.call(&"start_relay_survey")
	var relay: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0))
	var saved: Dictionary = _save_surface_progress(surface)
	_check(started.accepted and relay.accepted and saved.accepted
		and store.get_snapshot().has(String(SLOT))
		and not store.get_snapshot()[String(SLOT)].completion.route_identity.complete,
		"the last ordinary autosave can contain an incomplete route before its remaining observation")
	if not started.accepted or not relay.accepted or not saved.accepted or not store.get_snapshot().has(String(SLOT)):
		await _retire_surface(surface)
		return
	var returned: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0))
	filesystem.writes_until_refusal = 1
	var payment: StringName = await _pay_surface(surface)
	filesystem.writes_until_refusal = -1
	_check(returned.accepted and payment == &"relay_reward_persistence_commit_rejected"
		and not store.get_snapshot().has(String(SLOT))
		and int(store.get_snapshot().game_flow_reward_store.reward_counts.ember_beacon_data) == 1,
		"the actual reward CAS clears its same-generation incomplete autosave before a failed terminal save")
	await _retire_surface(surface)
	var cold := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
	var admission: Dictionary = (cold.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
	_check(not (cold.flow as GameFlow).get_ember_interrupted_journey_persistence_report().adopted
		and not admission.get("checkpoint_resume", {}).get("accepted", false),
		"a cold admission cannot replay the stale incomplete autosave of an already-paid survey")
	await _retire_surface(cold)


func _exercise_explicit_abandon() -> void:
	# Memory persistence and staged Host admission keep this focused on the real
	# GameFlow/coordinator/Host abandon boundary, rather than flying the approach.
	# The route, save, passive cold admission and runtime abort are production.
	for completed: bool in [false, true]:
		var filesystem := MemoryFilesystem.new()
		var store := StoreScript.new(STORE_PATH, filesystem)
		store.load()
		store.commit({"foreign": {"retained": 91}}, 0, "abandon-seed")
		var source := await _make_surface(store, true)
		var binding: Node = source.binding
		var started: Dictionary = binding.call(&"start_relay_survey")
		var relay: Dictionary = binding.call(&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0))
		var returned := {"accepted": true}
		if completed:
			returned = binding.call(&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0))
		var saved := _save_surface_progress(source)
		_check(started.accepted and relay.accepted and returned.accepted and saved.accepted,
			"explicit-abandon fixture saves actual incomplete or completed Director progress")
		if not saved.get("accepted", false):
			await _retire_surface(source)
			continue
		var saved_files: Dictionary = filesystem.files.duplicate(true)
		await _retire_surface(source)
		var cold := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
		var flow: GameFlow = cold.flow
		store = flow.get("_runtime_settings_user_data_store")
		var admission: Dictionary = flow._restore_ember_surface_persistence_for_admission()
		_check(admission.accepted and admission.get("checkpoint_resume", {}).get("accepted", false)
			and store.get_snapshot().has(String(SLOT)),
			"the existing saved receipt is staged before survey resume and remains durable")
		_stage_explicit_abandon(cold)
		var abandoned: Dictionary = flow.abandon_ember_surface_journey(&"player_abandoned")
		_check(abandoned.accepted and cold.host.get_abandon_snapshot().requested,
			"actual GameFlow and Host admit explicit abandon while landed before survey resume")
		_check(not store.get_snapshot().has(String(SLOT))
			and store.get_snapshot().foreign.retained == 91,
			"accepted explicit abandon removes the resumable slot and preserves unrelated data")
		await _retire_surface(cold)
		var next := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
		var next_admission: Dictionary = (next.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
		var next_start: Dictionary = next.binding.call(&"start_relay_survey")
		var next_route: Dictionary = next.binding.get_snapshot().relay_survey.mandatory_route
		_check(not (next.flow as GameFlow).get_ember_interrupted_journey_persistence_report().adopted,
			"a fresh Main never passively adopts the explicitly abandoned location or session")
		if completed:
			_check(next_admission.get("persistence_kind") == &"declined_completion"
				and not next_admission.get("location_resumed", true) and next_start.accepted
				and next.binding.get_activity_reward_snapshot().state == &"awaiting_reward"
				and store.get_snapshot().has(String(SLOT) + "_declined"),
				"explicit abandon preserves completed earned debt through its existing declined owner")
		else:
			_check(not next_admission.get("checkpoint_resume", {}).get("accepted", false)
				and next_start.accepted and int(next_route.next_checkpoint_index) == 0,
				"a fresh Main after explicit abandon starts the survey at its first observation")
		await _retire_surface(next)
		if not completed:
			await _exercise_approach_abandon(saved_files)
			await _exercise_explicit_abandon_failures(saved_files)
			await _exercise_retired_receipt_abandon(saved_files)


func _stage_explicit_abandon(surface: Dictionary, phase := EmberSurfaceLoopHost.Phase.LANDED) -> void:
	var host: SurfaceHost = surface.host
	host.staged_phase = phase
	# The actual Host's guards and abandon() run unchanged against these tokens.
	host.set("_phase", phase)
	host.set("_attached", true)
	host.set("_generation", host.run_generation)
	host.set("_attachment_generation", host.attachment)
	var flow: GameFlow = surface.flow
	flow.ember_surface_loop_host = host
	flow.ember_surface_loop_production_binding = surface.wrapper
	flow.set("_ember_surface_journey_active", true)


func _exercise_approach_abandon(saved_files: Dictionary) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = saved_files.duplicate(true)
	var surface := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
	var flow: GameFlow = surface.flow
	var store: RefCounted = flow.get("_runtime_settings_user_data_store")
	var admission: Dictionary = flow._restore_ember_surface_persistence_for_admission()
	_check(admission.accepted and admission.get("checkpoint_resume", {}).get("accepted", false)
		and store.get_snapshot().has(String(SLOT)),
		"approach-abandon control stages the saved ACTIVE checkpoint before Host start")
	if not admission.get("accepted", false):
		await _retire_surface(surface)
		return
	# Only the admitted coordinator and idle Host are staged here. No physical
	# cruise or flight is simulated; the public abandon takes the real cancel branch.
	_stage_explicit_abandon(surface, EmberSurfaceLoopHost.Phase.IDLE)
	var abandoned: Dictionary = flow.abandon_ember_surface_journey(&"player_abandoned")
	_check(abandoned.accepted and abandoned.reason == &"ember_surface_request_cancelled"
		and not flow.get("_ember_surface_journey_active"),
		"explicit abandon before Host start uses the existing approach cancellation")
	_check(not store.get_snapshot().has(String(SLOT)) and store.get_snapshot().foreign.retained == 91,
		"accepted approach abandon removes the resumable slot and preserves unrelated data")
	_check(surface.wrapper.get_planetary_surface_snapshot().is_empty()
		and surface.binding.is_queued_for_deletion(),
		"accepted approach abandon retires the staged composition in the retained Main")
	# Stage the next composition in the same Main/Director, using the normal
	# production configuration, persistence admission and survey-start seams.
	var fresh_binding := SurfaceBindingScript.new()
	root.add_child(fresh_binding)
	surface.host.staged_phase = EmberSurfaceLoopHost.Phase.ON_FOOT
	surface.host.set("_phase", EmberSurfaceLoopHost.Phase.ON_FOOT)
	var configured: Dictionary = fresh_binding.configure(surface.host, surface.director,
		Callable(surface.wrapper, "_commit_relay_reward_through_authority"), surface.host.run_generation)
	var bound: Dictionary = flow.bind_ember_relay_survey_persistence(fresh_binding)
	var current_admission: Dictionary = flow._restore_ember_surface_persistence_for_admission()
	var current_start: Dictionary = fresh_binding.start_relay_survey()
	_check(configured.accepted and bound.accepted and current_start.accepted
		and not current_admission.get("checkpoint_resume", {}).get("accepted", false)
		and int(fresh_binding.get_snapshot().relay_survey.mandatory_route.next_checkpoint_index) == 0,
		"the retained Main admits a fresh composition and starts at the first observation")
	surface.binding = fresh_binding
	surface.wrapper.set("_planetary_composition", fresh_binding)
	await _retire_surface(surface)
	var next := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
	var next_admission: Dictionary = (next.flow as GameFlow)._restore_ember_surface_persistence_for_admission()
	var started: Dictionary = next.binding.call(&"start_relay_survey")
	var route: Dictionary = next.binding.get_snapshot().relay_survey.mandatory_route
	_check(not (next.flow as GameFlow).get_ember_interrupted_journey_persistence_report().adopted
		and not next_admission.get("checkpoint_resume", {}).get("accepted", false)
		and started.accepted and int(route.next_checkpoint_index) == 0,
		"a fresh Main after approach abandon starts at the first observation without passive adoption")
	await _retire_surface(next)


func _exercise_explicit_abandon_failures(saved_files: Dictionary) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = saved_files.duplicate(true)
	var surface := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
	var flow: GameFlow = surface.flow
	var store: RefCounted = flow.get("_runtime_settings_user_data_store")
	var admission: Dictionary = flow._restore_ember_surface_persistence_for_admission()
	var resumed: Dictionary = surface.binding.call(&"start_relay_survey")
	# Exercise a newly saved live checkpoint separately from the receipt already
	# retired by resume. This calls the existing save seam; it is not an autosave.
	var saved := _save_surface_progress(surface)
	_check(admission.accepted and resumed.accepted and saved.accepted
		and store.get_snapshot().has(String(SLOT)),
		"failure control explicitly saves a new checkpoint after successful resume")
	_stage_explicit_abandon(surface, EmberSurfaceLoopHost.Phase.ON_FOOT)
	var before: Dictionary = store.get_snapshot()
	var bytes: PackedByteArray = filesystem.files[STORE_PATH].duplicate()
	var generation: int = store.get_generation()
	var runtime: Dictionary = surface.binding.get_activity_reward_snapshot()
	filesystem.reject_writes = true
	var refused: Dictionary = flow.abandon_ember_surface_journey(&"player_abandoned")
	filesystem.reject_writes = false
	_check(not refused.accepted and filesystem.files[STORE_PATH] == bytes
		and store.get_snapshot() == before and store.get_generation() == generation
		and not surface.host.get_abandon_snapshot().requested
		and not flow.get("_planetary_journey").get("_ember_surface_abandon_pending")
		and surface.binding.get_activity_reward_snapshot() == runtime,
		"failed explicit-abandon persistence leaves primary bytes and the live visit unchanged")
	# The public getter alone cannot authorize discarding a receipt: the actual
	# Host refuses this stale internal generation before any abandon mutation.
	surface.host.set("_generation", surface.host.run_generation - 1)
	var stale: Dictionary = flow.abandon_ember_surface_journey(&"player_abandoned")
	_check(not stale.accepted and filesystem.files[STORE_PATH] == bytes
		and store.get_snapshot() == before and store.get_generation() == generation,
		"a stale Host rejection cannot discard the saved checkpoint")
	await _retire_surface(surface)


func _exercise_retired_receipt_abandon(saved_files: Dictionary) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = saved_files.duplicate(true)
	var surface := await _make_surface(StoreScript.new(STORE_PATH, filesystem), true)
	var flow: GameFlow = surface.flow
	var store: RefCounted = flow.get("_runtime_settings_user_data_store")
	var admission: Dictionary = flow._restore_ember_surface_persistence_for_admission()
	var resumed: Dictionary = surface.binding.call(&"start_relay_survey")
	_check(admission.accepted and resumed.accepted and not store.get_snapshot().has(String(SLOT)),
		"the already-resumed control really retires its original saved receipt")
	_stage_explicit_abandon(surface, EmberSurfaceLoopHost.Phase.ON_FOOT)
	var bytes: PackedByteArray = filesystem.files[STORE_PATH].duplicate()
	var generation: int = store.get_generation()
	var abandoned: Dictionary = flow.abandon_ember_surface_journey(&"player_abandoned")
	_check(abandoned.accepted and filesystem.files[STORE_PATH] == bytes
		and store.get_generation() == generation
		and surface.binding.get_activity_reward_snapshot().state == &"failed",
		"abandon after successful receipt retirement aborts the runtime without another durable write")
	await _retire_surface(surface)


func _save_surface_progress(surface: Dictionary) -> Dictionary:
	var flow = surface.flow
	var route: Dictionary = surface.binding.get_snapshot().relay_survey.mandatory_route
	var frame: RefCounted = _frame()
	var tangent := Vector3(24.0, 8.0, -13.0)
	var body_local: Dictionary = frame.surface_tangent_to_body_local(tangent, 1)
	var orbital: Dictionary = frame.body_local_to_orbital_position(body_local.position, 1)
	flow.set("_ember_surface_journey_active", true)
	flow.save_evidence = {"accepted": true, "frame": frame,
		"host": {"generation": surface.host.get_generation(), "attachment_generation": surface.host.get_attachment_generation(),
			"coordinate_frame_generation": 1, "physics_advance_count": 1440, "phase_id": &"on_foot"},
		"route": route, "coordinate": {"orbital_coordinate": orbital.coordinate,
			"surface_tangent_position": tangent}}
	return flow.save_interrupted_ember_journey()


func _pay_surface(surface: Dictionary) -> StringName:
	await physics_frame
	var frame := int(Engine.get_physics_frames())
	var wrapper: Node = surface.wrapper
	wrapper.set("_last_consumed_caller_serial", 9)
	wrapper.set("_last_consumed_physics_frame", frame)
	var envelope := {"actor_sample": {"actor_kind": &"player",
		"actor_instance_id": surface.actor.get_instance_id()},
		"host_generation": surface.host.get_generation(), "host_attachment_generation": surface.host.get_attachment_generation(),
		"caller_serial": 9, "physics_frame": frame}
	var runtime: Dictionary = surface.binding.get_activity_reward_snapshot()
	return wrapper.call(&"_commit_pending_relay_reward", envelope, runtime)


func _make_surface(store: RefCounted, real_rewards := false, run_generation := 31, attachment := 7) -> Dictionary:
	_check(store.load().accepted, "the surface fixture loads its actual durable store")
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := SurfaceBindingScript.new()
	root.add_child(binding)
	var host := SurfaceHost.new()
	host.run_generation = run_generation
	host.attachment = attachment
	root.add_child(host)
	var authority: RefCounted = null
	var wrapper: Node = null
	var actor: Node = null
	var craft: Node = null
	var sink := Callable(self, "_reward_sink")
	if real_rewards:
		authority = RewardAuthorityScript.new()
		_check(authority.configure(store).accepted, "the debt fixture configures the real GameFlow reward authority")
		actor = Node.new()
		craft = Node.new()
		root.add_child(actor)
		root.add_child(craft)
		host.actor_id = actor.get_instance_id()
		host.craft_id = craft.get_instance_id()
		wrapper = RewardWrapperScript.new()
		root.add_child(wrapper)
		# Same bounded owner setup as the existing relay-survey API fixture;
		# actual production evidence construction/validation remains unmodified.
		wrapper.set("_configured", true)
		wrapper.set("_generation", 6)
		wrapper.set("_state", EmberSurfaceLoopProductionBinding.State.RUNNING)
		wrapper.set("_host", host)
		wrapper.set("_host_instance_id", host.get_instance_id())
		wrapper.set("_player_instance_id", host.actor_id)
		wrapper.set("_ship_instance_id", host.craft_id)
		wrapper.set("_planetary_composition", binding)
		wrapper.set("_relay_survey_persistence_store", store)
		wrapper.set("_relay_survey_persistence_slot", SLOT)
		wrapper.set("_planetary_reward_authority", Callable(authority, "commit"))
		sink = Callable(wrapper, "_commit_relay_reward_through_authority")
	var configured: Dictionary = binding.configure(host, director, sink, run_generation)
	var flow := LifecycleFlow.new()
	flow.restore_frame = _frame()
	_check(configured.accepted and flow.configure_runtime_settings_persistence(store)
		and flow.bind_ember_relay_survey_persistence(binding).accepted,
		"the cold fixture uses the real surface binding, Director and persistence consumer")
	flow.bind_aurora_expedition_persistence()
	flow.bind_rime_expedition_persistence()
	if real_rewards:
		flow.set("_game_flow_reward_authority", authority)
	return {"flow": flow, "binding": binding, "director": director, "host": host,
		"authority": authority, "wrapper": wrapper, "actor": actor, "craft": craft}


func _retire_surface(surface: Dictionary) -> void:
	(surface.flow as GameFlow).free()
	(surface.binding as Node).queue_free()
	(surface.director as Node).queue_free()
	(surface.host as Node).queue_free()
	for key: String in ["wrapper", "actor", "craft"]:
		if is_instance_valid(surface.get(key)):
			(surface[key] as Node).queue_free()
	await process_frame


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"game_flow_reward_committed"}


func _frame(surface_reference: Vector3 = Vector3.BACK):
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
		origin, surface_reference, Vector3.UP, 5_000.0, origin
	)
	if not bool(configured.accepted):
		_failures.append("frame fixture failed: %s" % configured)
	return frame


func _route() -> Dictionary:
	return {
		"source": &"activity_director_checkpoint_result",
		"activity_id": &"ember_beacon_survey",
		"activity_generation": 44,
		"next_checkpoint_index": 1,
		"checkpoint_count": 2,
		"next_objective_id": &"ember_return_beacon",
		"complete": false,
		"authority": {"navigation": false, "movement": false, "reward": false},
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
