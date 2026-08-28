extends SceneTree

const AuthorityScript := preload("res://scripts/game/game_flow_reward_authority.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")


class MemoryFilesystem extends FilesystemScript:
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
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://game-flow-rewards.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic user-data store loads")
	_check(
		bool(store.commit(
			{"foreign": {"pilot_callsign": "MUDDS"}}, 0, "seed-foreign-data"
		).accepted),
		"foreign user data exists before reward configuration"
	)
	var authority := AuthorityScript.new() as GameFlowRewardAuthority
	_check(
		bool(authority.configure(store).accepted),
		"the production reward authority adopts the already-loaded store"
	)

	var race_request := _request(
		&"cinder_reach_checkpoint_route",
		1,
		&"return_race_record_to_shipyard"
	)
	var race := authority.commit(race_request)
	var after_race := store.get_snapshot()
	var race_record := after_race.get("game_flow_reward_store", {}) as Dictionary
	var race_receipt := race.get("receipt", {}) as Dictionary
	_check(
		bool(race.accepted)
			and bool(race.granted)
			and int(race_receipt.receipt_id) == 1
			and race_receipt.activity_id == "cinder_reach_checkpoint_route"
			and race_receipt.reward_id == "return_race_record_to_shipyard"
			and bool(race_receipt.granted)
			and not bool(race_receipt.replay_allowed),
		"a real race completion becomes one granted, non-replayable Shipyard receipt"
	)
	_check(
		(after_race.foreign as Dictionary).pilot_callsign == "MUDDS"
			and int(race_record.total_receipts) == 1
			and int((race_record.reward_counts as Dictionary).return_race_record_to_shipyard) == 1,
		"the reward namespace merges with foreign user data and increments its exact counter"
	)

	var generation_after_race := store.get_generation()
	var duplicate := authority.commit(race_request)
	var forged := race_request.duplicate(true)
	forged["reward_id"] = &"return_convoy_credit_to_shipyard"
	var mismatch := authority.commit(forged)
	_check(
		not bool(duplicate.accepted)
			and duplicate.reason == &"reward_generation_already_committed"
			and not bool(mismatch.accepted)
			and mismatch.reason == &"reward_contract_mismatch"
			and store.get_generation() == generation_after_race,
		"duplicate and mismatched handoffs fail without advancing persistent state"
	)

	var patrol := authority.commit(_request(
		&"cinder_relay_patrol",
		1,
		&"return_patrol_log_to_shipyard"
	))
	var after_patrol := store.get_snapshot().game_flow_reward_store as Dictionary
	_check(
		bool(patrol.accepted)
			and int((patrol.receipt as Dictionary).receipt_id) == 2
			and int(after_patrol.total_receipts) == 2
			and int((after_patrol.reward_counts as Dictionary).return_patrol_log_to_shipyard) == 1,
		"an independent activity generation advances the shared receipt sequence once"
	)
	var heavy_breach := authority.commit(_request(
		&"shipyard_heavy_breach",
		1,
		&"return_heavy_breach_credit"
	))
	var after_heavy_breach := store.get_snapshot().game_flow_reward_store as Dictionary
	_check(
		bool(heavy_breach.accepted)
			and int((heavy_breach.receipt as Dictionary).receipt_id) == 3
			and (heavy_breach.receipt as Dictionary).reward_label \
				== "Heavy Breach credit logged"
			and int(after_heavy_breach.total_receipts) == 3
			and int((after_heavy_breach.reward_counts as Dictionary).return_heavy_breach_credit) == 1,
		"a cleared Heavy Breach generation joins the same persisted receipt sequence"
	)
	var generation_before_ember := store.get_generation()
	var evidence_free_ember := authority.commit(_request(
		&"ember_beacon_survey", 1, &"ember_beacon_data"
	))
	var forged_ember_request := _ember_request(1, 7, 3)
	forged_ember_request["production_commit_id"] = "ember-relay-survey:forged"
	var forged_ember := authority.commit(forged_ember_request)
	_check(
		not bool(evidence_free_ember.accepted)
			and evidence_free_ember.reason == &"reward_request_invalid"
			and not bool(forged_ember.accepted)
			and forged_ember.reason == &"reward_request_invalid"
			and store.get_generation() == generation_before_ember,
		"evidence-free and forged Ember requests cannot reach the shared store"
	)
	var ember := authority.commit(_ember_request(1, 7, 3))
	var after_ember := store.get_snapshot().game_flow_reward_store as Dictionary
	_check(
		bool(ember.accepted)
			and int((ember.receipt as Dictionary).receipt_id) == 4
			and (ember.receipt as Dictionary).reward_label == "Survey data accepted"
			and int(after_ember.total_receipts) == 4
			and int((after_ember.reward_counts as Dictionary).ember_beacon_data) == 1,
		"the typed Ember relay completion joins the same persisted receipt sequence"
	)

	var reloaded_store := StoreScript.new(
		"memory://game-flow-rewards.json", filesystem
	)
	_check(bool(reloaded_store.load().accepted), "the committed user-data file reloads")
	var restored_authority := AuthorityScript.new() as GameFlowRewardAuthority
	var restored_configuration := restored_authority.configure(reloaded_store)
	var restored := restored_authority.get_snapshot()
	var restored_record := restored.get("record", {}) as Dictionary
	_check(
		bool(restored_configuration.accepted)
			and bool(restored.configured)
			and int(restored_record.total_receipts) == 4
			and int((restored_record.last_receipt as Dictionary).receipt_id) == 4
			and not bool(restored.currency_authority)
			and not bool(restored.inventory_authority),
		"reload retains the receipt summary without inventing currency or inventory authority"
	)

	var corrupt_filesystem := MemoryFilesystem.new()
	var corrupt_store := StoreScript.new(
		"memory://corrupt-game-flow-rewards.json", corrupt_filesystem
	)
	corrupt_store.load()
	corrupt_store.commit(
		{"game_flow_reward_store": {"schema_version": 99}},
		0,
		"seed-corrupt-reward"
	)
	var corrupt_authority := AuthorityScript.new() as GameFlowRewardAuthority
	var corrupt_configuration := corrupt_authority.configure(corrupt_store)
	_check(
		not bool(corrupt_configuration.accepted)
			and corrupt_configuration.reason == &"reward_store_payload_corrupt",
		"a corrupt reward namespace fails closed instead of being overwritten"
	)

	for failure in _failures:
		push_error(failure)
	print("GAME_FLOW_REWARD_AUTHORITY_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _request(
	activity_id: StringName,
	activity_generation: int,
	reward_id: StringName
	) -> Dictionary:
	return {
		"activity_id": activity_id,
		"activity_generation": activity_generation,
		"reward_id": reward_id,
		"reward_authority": false,
		"granted": false,
	}.duplicate(true)


func _ember_request(
	activity_generation: int,
	run_generation: int,
	attachment_generation: int,
	) -> Dictionary:
	return {
		"world_id": &"ember_moon",
		"activity_id": &"ember_beacon_survey",
		"objective_id": &"survey_beacon_network",
		"activity_generation": activity_generation,
		"reward_id": &"ember_beacon_data",
		"reward_store_id": &"game_flow_reward_store",
		"reward_authority_id": &"game_flow_reward_authority",
		"return_target_id": &"mudds_shipyards",
		"recovery_id": &"return_to_landed_ship",
		"run_generation": run_generation,
		"attachment_generation": attachment_generation,
		"production_commit_id": "ember-relay-survey:%d:%d" % [
			run_generation, activity_generation,
		],
		"production_evidence": {
			"owner_generation": 6,
			"host_instance_id": 10,
			"host_generation": run_generation,
			"host_attachment_generation": attachment_generation,
			"session_instance_id": 11,
			"actor_kind": &"player",
			"actor_instance_id": 12,
			"craft_instance_id": 13,
			"caller_serial": 14,
			"physics_frame": 15,
			"activity_generation": activity_generation,
			"completion_attachment_generation": attachment_generation,
		}.duplicate(true),
	}.duplicate(true)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
