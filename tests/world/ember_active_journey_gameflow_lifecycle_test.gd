extends SceneTree

const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const ContractScript := preload("res://scripts/world/planetary_save_session_contract.gd")
const PersistenceScript := preload(
	"res://scripts/persistence/ember_relay_survey_persistence_binding.gd"
)
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

const STORE_PATH := "memory://ember-active-gameflow.json"
const SLOT: StringName = &"ember_relay_survey_completion"


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


var _assertions := 0
var _failures := PackedStringArray()


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

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_ACTIVE_JOURNEY_GAMEFLOW_LIFECYCLE_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


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
