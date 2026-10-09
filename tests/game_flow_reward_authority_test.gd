extends SceneTree

const AuthorityScript := preload("res://scripts/game/game_flow_reward_authority.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")


class MemoryFilesystem extends FilesystemScript:
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
			return ERR_CANT_CREATE
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

	var missing_handoff := authority.commit(_request(
		AuthorityScript.RACE_ACTIVITY_ID, 1, AuthorityScript.RACE_REWARD_ID
	))
	_check(not bool(missing_handoff.accepted) and missing_handoff.reason == &"reward_terminal_handoff_invalid",
		"a race request without its durable terminal handoff grants nothing")

	# Build the terminal handoff through its live route/session and exact codec.
	var director := ActivityDirector.new()
	root.add_child(director)
	director.register_definition(CinderTimedRaceSession.ROUTE)
	var session := CinderTimedRaceSession.new()
	session.attach(director, 0)
	session.start(0)
	session.advance_physics(2.0, session.get_session_generation())
	session.advance_physics(1.0, session.get_session_generation())
	session.advance_physics(0.25, session.get_session_generation())
	for checkpoint in CinderTimedRaceSession.ROUTE.get_checkpoint_count():
		session.submit_position(CinderTimedRaceSession.ROUTE.get_checkpoint_position(checkpoint), session.get_session_generation())
	var persistence := CinderRaceSessionPersistence.new()
	persistence.configure(store, &"cinder_timed_race_session")
	_check(bool(persistence.save(session, director, "unit-terminal-race").accepted)
		and session.get_presentation_snapshot().get("state_id") == &"completed",
		"the race reward requires a real completed session saved by its existing codec")
	session.close(session.get_session_generation())
	director.free()

	var race_request := _request(
		&"cinder_reach_checkpoint_route",
		1,
		&"return_race_record_to_shipyard"
	)
	var race := authority.commit(race_request)
	if not bool(race.accepted):
		_check(false, "the live terminal handoff is eligible (%s)" % race.reason)
		push_error(_failures[-1])
		quit(1)
		return
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

	var missing_patrol := authority.commit(_request(
		AuthorityScript.PATROL_ACTIVITY_ID, 1, AuthorityScript.PATROL_REWARD_ID
	))
	_check(not bool(missing_patrol.accepted) and missing_patrol.reason == &"reward_terminal_handoff_invalid",
		"a patrol request without a durable terminal handoff grants nothing")
	var patrol_director := ActivityDirector.new()
	root.add_child(patrol_director)
	patrol_director.register_definition(CinderTimedRaceSession.ROUTE)
	var patrol_owner := PatrolActivity.new(CinderTimedRaceSession.ROUTE, 1.0)
	patrol_owner.attach(patrol_director, 0)
	patrol_owner.start(0)
	for checkpoint in CinderTimedRaceSession.ROUTE.get_checkpoint_count():
		var position := CinderTimedRaceSession.ROUTE.get_checkpoint_position(checkpoint)
		patrol_owner.submit_position(position, patrol_owner.get_generation())
		patrol_owner.advance_physics(1.0, position, patrol_owner.get_generation())
	var patrol_persistence := CinderPatrolSessionPersistence.new()
	patrol_persistence.configure(store, &"cinder_patrol_session")
	_check(bool(patrol_persistence.save(patrol_owner, patrol_director, "unit-terminal-patrol").accepted),
		"a real patrol model supplies its completed durable handoff")
	patrol_owner.close(patrol_owner.get_generation())
	patrol_director.free()

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
	_check(_save_actual_scan_completion(store), "the actual scan owner checkpoints its legitimate terminal before payment")
	var scan := authority.commit(_request(
		&"cinder_derelict_structure_scan",
		1,
		&"derelict_material_sample"
	))
	var after_scan := store.get_snapshot().game_flow_reward_store as Dictionary
	_check(
		bool(scan.accepted)
			and int((scan.receipt as Dictionary).receipt_id) == 5
			and (scan.receipt as Dictionary).reward_label \
				== "Derelict material sample recorded"
			and int(after_scan.total_receipts) == 5
			and int((after_scan.reward_counts as Dictionary).derelict_material_sample) == 1,
		"the completed production derelict scan records one shared material-sample receipt"
	)
	_check(_save_actual_beacon_completion(store), "the actual ordered beacon owner saves its legitimate terminal before reward handoff")
	var beacon := authority.commit(_request(
		&"cinder_debris_beacon_traversal",
		1,
		&"debris_route_navigation_data"
	))
	var after_beacon := store.get_snapshot().game_flow_reward_store as Dictionary
	_check(
		bool(beacon.accepted)
			and int((beacon.receipt as Dictionary).receipt_id) == 6
			and (beacon.receipt as Dictionary).reward_label \
				== "Debris navigation data recorded"
			and int(after_beacon.total_receipts) == 6
			and int((after_beacon.reward_counts as Dictionary).debris_route_navigation_data) == 1,
		"the completed production beacon run records one shared navigation-data receipt"
	)
	_check(_save_actual_jovian_completion(store), "a genuine Main-compatible typed transfer owns the Jovian durable terminal handoff")
	var jovian_cargo := authority.commit(_request(
		&"jovian_fabrication_kit_delivery",
		1,
		&"return_fabrication_kits_to_shipyard"
	))
	var after_jovian_cargo := (
		store.get_snapshot().game_flow_reward_store as Dictionary
	)
	_check(
		bool(jovian_cargo.accepted)
			and int((jovian_cargo.receipt as Dictionary).receipt_id) == 7
			and int(after_jovian_cargo.total_receipts) == 7
			and int(
				(after_jovian_cargo.reward_counts as Dictionary)
					.return_fabrication_kits_to_shipyard
			) == 1,
		"the existing Jovian delivery establishes the shared fabrication-kit reward counter"
	)
	var cinder_cargo := authority.commit(_request(
		&"cinder_kit_cargo_run",
		1,
		&"return_fabrication_kits_to_shipyard"
	))
	var after_cinder_cargo := (
		store.get_snapshot().game_flow_reward_store as Dictionary
	)
	var restarted_cargo_authority := AuthorityScript.new() as GameFlowRewardAuthority
	restarted_cargo_authority.configure(store)
	var paid_cargo_retry := restarted_cargo_authority.commit(_request(AuthorityScript.CARGO_ACTIVITY_ID, 1, AuthorityScript.CARGO_REWARD_ID))
	_check(not bool(paid_cargo_retry.accepted) and paid_cargo_retry.reason == &"reward_generation_already_committed"
		and store.get_snapshot().jovian_cargo_session.activities[0].reward_granted,
		"the typed paid Jovian acknowledgement prevents duplicate credit after an unrelated Cinder receipt becomes latest")
	_check(
		bool(cinder_cargo.accepted)
			and int((cinder_cargo.receipt as Dictionary).receipt_id) == 8
			and int(after_cinder_cargo.total_receipts) == 8
			and int(
				(after_cinder_cargo.reward_counts as Dictionary)
					.return_fabrication_kits_to_shipyard
			) == 2,
		"the embodied Cinder supply run shares the fabrication-kit return receipt authority"
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
			and int(restored_record.total_receipts) == 8
			and int((restored_record.last_receipt as Dictionary).receipt_id) == 8
			and (restored_record.last_receipt as Dictionary).activity_id \
				== "cinder_kit_cargo_run"
			and not bool(restored.currency_authority)
			and not bool(restored.inventory_authority),
		"reload retains the receipt summary without inventing currency or inventory authority"
	)

	var torpedo_run := restored_authority.commit(_request(
		&"shipyard_torpedo_run",
		1,
		&"return_torpedo_run_credit"
	))
	var torpedo_as_breach := restored_authority.commit(_request(
		&"shipyard_torpedo_run",
		2,
		&"return_heavy_breach_credit"
	))
	var torpedo_duplicate := restored_authority.commit(_request(
		&"shipyard_torpedo_run",
		1,
		&"return_torpedo_run_credit"
	))
	var after_torpedo_run := reloaded_store.get_snapshot().game_flow_reward_store as Dictionary
	_check(
		bool(torpedo_run.accepted)
			and (torpedo_run.receipt as Dictionary).reward_label \
				== "Torpedo Run credit logged"
			and (torpedo_run.receipt as Dictionary).reward_id == "return_torpedo_run_credit"
			and int((after_torpedo_run.reward_counts as Dictionary).return_torpedo_run_credit) == 1
			and int((after_torpedo_run.reward_counts as Dictionary).return_heavy_breach_credit) == 1,
		"a cleared Torpedo Run files its own receipt after reload without touching the Heavy Breach counter"
	)
	_check(
		not bool(torpedo_as_breach.accepted)
			and torpedo_as_breach.reason == &"reward_contract_mismatch"
			and not bool(torpedo_duplicate.accepted)
			and torpedo_duplicate.reason == &"reward_generation_already_committed",
		"Torpedo Run cannot claim Heavy Breach credit or pay one generation twice"
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

	# Aurora discovery rewards remain one-time even if a visit save lags behind
	# the reward write, while a failed write leaves the same adapter retryable.
	var aurora_fs := MemoryFilesystem.new()
	var aurora_store := StoreScript.new("memory://aurora-rewards.json", aurora_fs)
	aurora_store.load()
	var aurora_authority := AuthorityScript.new()
	aurora_authority.configure(aurora_store)
	var adapter := NearbyActivityRewardAdapter.new()
	adapter.configure(Callable(aurora_authority, &"commit"), AuthorityScript.AURORA_SURVEY_ACTIVITY_ID, AuthorityScript.AURORA_SURVEY_REWARD_ID)
	var completed := {"activity_id": AuthorityScript.AURORA_SURVEY_ACTIVITY_ID,
		"generation": 1, "state_id": &"completed", "outcome": &"cleared"}
	aurora_fs.reject_writes = true
	_check(not bool(adapter.consume(completed, 1).get("accepted", true)), "a failed Aurora reward write rejects the adapter handoff")
	aurora_fs.reject_writes = false
	_check(bool(adapter.consume(completed, 1).get("accepted", false)), "the same completed survey can retry after a failed reward write")
	var durable_generation := aurora_store.get_generation()
	var restarted_authority := AuthorityScript.new()
	restarted_authority.configure(aurora_store)
	var duplicate_aurora := restarted_authority.commit(_request(AuthorityScript.AURORA_SURVEY_ACTIVITY_ID, 900, AuthorityScript.AURORA_SURVEY_REWARD_ID))
	_check(not bool(duplicate_aurora.get("accepted", true)) and duplicate_aurora.get("reason") == &"reward_already_recorded"
		and aurora_store.get_generation() == durable_generation,
		"fresh authority rejects a second Aurora discovery using durable counts, regardless of activity generation")

	for failure in _failures:
		push_error(failure)
	print("GAME_FLOW_REWARD_AUTHORITY_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _save_actual_jovian_completion(store: UserDataStore) -> bool:
	var transfer := CargoTransferAuthority.new()
	root.add_child(transfer)
	var source := Node.new()
	var destination := Node.new()
	root.add_child(source)
	root.add_child(destination)
	var item := CargoItemDefinition.new()
	item.item_id = GameFlow.CARGO_DELIVERY_ITEM_ID
	item.display_name = GameFlow.CARGO_DELIVERY_ITEM_DISPLAY_NAME
	item.unit_capacity = 1
	transfer.register_item(item)
	var registered_source := transfer.register_entity(source, &"jovian_provisional", GameFlow.CARGO_DELIVERY_SOURCE_MANIFEST_ID,
		GameFlow.CARGO_DELIVERY_SOURCE_CAPACITY, {GameFlow.CARGO_DELIVERY_ITEM_ID: GameFlow.CARGO_DELIVERY_SOURCE_INITIAL_QUANTITY})
	var registered_destination := transfer.register_entity(destination, &"jovian_freight_berth", GameFlow.CARGO_DELIVERY_DESTINATION_MANIFEST_ID,
		GameFlow.CARGO_DELIVERY_DESTINATION_CAPACITY)
	var contract := CargoDeliveryContract.new(GameFlow.CARGO_DELIVERY_ACTIVITY_ID, registered_source.handle, registered_destination.handle,
		GameFlow.CARGO_DELIVERY_ITEM_ID, GameFlow.CARGO_DELIVERY_QUANTITY, GameFlow.CARGO_DELIVERY_PHASES, GameFlow.CARGO_DELIVERY_DEADLINE_SECONDS)
	var activity := CargoDeliveryActivity.new(transfer, contract)
	activity.start(0)
	for phase: StringName in GameFlow.CARGO_DELIVERY_PHASES:
		activity.submit_phase(phase, activity.get_generation())
	var delivered := activity.submit_transfer(activity.get_generation())
	var persistence := JovianCargoSessionPersistence.new()
	persistence.configure(store)
	var saved := persistence.save(activity, transfer, "unit-jovian-terminal")
	source.free()
	destination.free()
	transfer.free()
	return bool(delivered.accepted) and bool(saved.accepted)


func _save_actual_beacon_completion(store: UserDataStore) -> bool:
	var beacon := CinderBeaconTraversalActivity.new()
	beacon.start(CinderBeaconTraversalActivity.BEACONS[0])
	for index in CinderBeaconTraversalActivity.BEACONS.size():
		beacon.submit_beacon(index, CinderBeaconTraversalActivity.BEACONS[index])
	var record := NearbySectorActivitySessionAdapter.new().capture({"beacon_traversal": beacon.get_snapshot()})
	(record.activities[0] as Dictionary).reward_requested = true
	var payload := store.get_snapshot()
	payload["cinder_beacon_session"] = JSON.parse_string(JSON.stringify(record))
	return bool(store.commit(payload, store.get_generation(), "unit-live-beacon-terminal").get("accepted", false))


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


func _save_actual_scan_completion(store: UserDataStore) -> bool:
	var scan := CinderAbandonedStructureScanActivity.new()
	if not scan.start(scan.APPROACH_ANCHOR).accepted or not scan.advance_physics(scan.SCAN_SECONDS).accepted:
		return false
	var record := NearbySectorActivitySessionAdapter.new().capture({"structure_scan": scan.get_persistence_snapshot()})
	record.activities[0].reward_requested = true
	if not store.load().accepted:
		return false
	var payload := store.get_snapshot()
	payload["cinder_structure_scan_session"] = JSON.parse_string(JSON.stringify(record))
	return bool(store.commit(payload, store.get_generation(), "unit-real-scan-completion").accepted)
