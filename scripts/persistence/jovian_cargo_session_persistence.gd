class_name JovianCargoSessionPersistence
extends RefCounted

## One Main-owned Jovian delivery session. Inventory and lifecycle adoption
## remain inside the typed cargo owners; UserDataStore owns every byte commit.
const SLOT_ID: StringName = &"jovian_cargo_session"
const ACTIVITY_ID: StringName = &"jovian_fabrication_kit_delivery"
const INITIAL_QUANTITY := 6
var _store: UserDataStore
var _codec := NearbySectorActivitySessionAdapter.new()

func configure(store: UserDataStore) -> void:
	_store = store

func capture(activity: CargoDeliveryActivity, authority: CargoTransferAuthority) -> Dictionary:
	return {"activity_state": activity.capture_persistence_state(), "authority_state": authority.to_dictionary()}

func validate_record(candidate: Variant, activity: CargoDeliveryActivity, authority: CargoTransferAuthority) -> Dictionary:
	if not candidate is Dictionary or candidate.size() != 2 or candidate.get("schema_version") != NearbySectorActivitySessionAdapter.SCHEMA_VERSION \
			or not candidate.get("activities") is Array or candidate.activities.size() != 1:
		return _result(false, &"invalid_jovian_session")
	var row: Variant = candidate.activities[0]
	if not row is Dictionary or row.size() != 6 or str(row.get("activity_id", "")) != str(ACTIVITY_ID) \
			or not _integer(row.get("generation")) or not _integer(row.get("state")) \
			or row.get("reward_requested") is not bool or row.get("reward_granted") is not bool \
			or not row.get("progress") is Dictionary:
		return _result(false, &"invalid_jovian_session")
	var progress := row.progress as Dictionary
	var state: Variant = progress.get("cargo_session_state")
	if progress.size() != 4 or str(progress.get("activity_id", "")) != str(ACTIVITY_ID) \
			or not _integer(progress.get("generation")) or not _integer(progress.get("state")) \
			or not state is Dictionary or state.size() != 2 or not state.get("activity_state") is Dictionary \
			or not state.get("authority_state") is Dictionary:
		return _result(false, &"invalid_jovian_session")
	var saved := state.activity_state as Dictionary
	var inventory := authority.validate_delivery_persistence_state(state.authority_state, activity.get_snapshot().contract, INITIAL_QUANTITY)
	if not bool(inventory.get("accepted", false)):
		return inventory
	var lifecycle := activity.validate_persistence_state(saved, state.authority_state)
	if not bool(lifecycle.get("accepted", false)):
		return lifecycle
	if row.generation != saved.generation or row.state != saved.state or progress.generation != saved.generation or progress.state != saved.state \
			or (row.reward_granted and not row.reward_requested) \
			or ((row.reward_requested or row.reward_granted) and int(saved.state) != CargoDeliveryActivity.State.COMPLETED):
		return _result(false, &"invalid_jovian_session")
	return _result(true, &"jovian_session_valid")

func load(activity: CargoDeliveryActivity, authority: CargoTransferAuthority) -> Dictionary:
	if _store == null:
		return _result(false, &"jovian_persistence_unavailable")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	var row: Variant = _store.get_snapshot().get(String(SLOT_ID))
	if row == null:
		return _result(false, &"jovian_session_not_found")
	var validated := validate_record(row, activity, authority)
	if not bool(validated.get("accepted", false)):
		return validated
	return {"accepted": true, "reason": &"jovian_session_loaded", "session_state": row.activities[0].progress.cargo_session_state.duplicate(true),
		"reward_requested": row.activities[0].reward_requested, "reward_granted": row.activities[0].reward_granted}

func save(activity: CargoDeliveryActivity, authority: CargoTransferAuthority, commit_id: String) -> Dictionary:
	if _store == null or activity.get_generation() < 1:
		return _result(_store != null, &"jovian_session_not_started")
	var state := JSON.parse_string(JSON.stringify(capture(activity, authority))) as Dictionary
	var record := JSON.parse_string(JSON.stringify(_codec.capture({"cargo": {"activity_id": String(ACTIVITY_ID), "generation": activity.get_generation(),
		"state": activity.get_state(), "cargo_session_state": state}}))) as Dictionary
	var row := record.activities[0] as Dictionary
	row.reward_requested = activity.get_state() == CargoDeliveryActivity.State.COMPLETED
	var validated := validate_record(record, activity, authority)
	if not bool(validated.get("accepted", false)):
		return validated
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	if loaded.get("reason") == &"primary_invalid_backup_loaded":
		return _result(false, &"jovian_store_recovery_required")
	var payload := _store.get_snapshot()
	if payload.has(String(SLOT_ID)):
		var old_record := payload[String(SLOT_ID)] as Dictionary
		validated = validate_record(old_record, activity, authority)
		if not bool(validated.get("accepted", false)):
			return validated
		var old := old_record.activities[0] as Dictionary
		var previous := old.progress.cargo_session_state as Dictionary
		var before := previous.activity_state as Dictionary
		var after := state.activity_state as Dictionary
		if int(after.generation) == int(before.generation):
			row.reward_requested = old.reward_requested if int(before.state) == CargoDeliveryActivity.State.COMPLETED else row.reward_requested
			row.reward_granted = old.reward_granted
			if int(after.next_phase_index) < int(before.next_phase_index) or float(after.elapsed_seconds) < float(before.elapsed_seconds) \
					or (int(before.state) != CargoDeliveryActivity.State.ACTIVE and int(after.state) != int(before.state)) \
					or (int(before.state) == CargoDeliveryActivity.State.ACTIVE and int(after.state) == CargoDeliveryActivity.State.IDLE):
				return _result(false, &"stale_jovian_session")
		elif int(after.generation) == int(before.generation) + 1:
			var reset: bool = int(after.state) == CargoDeliveryActivity.State.IDLE and int(before.state) != CargoDeliveryActivity.State.IDLE \
				and (int(before.state) != CargoDeliveryActivity.State.COMPLETED or (old.reward_requested and old.reward_granted))
			var start: bool = int(before.state) == CargoDeliveryActivity.State.IDLE and int(after.state) == CargoDeliveryActivity.State.ACTIVE
			if not reset and not start:
				return _result(false, &"unproven_jovian_generation")
		else:
			return _result(false, &"unproven_jovian_generation")
		var old_ledger := previous.authority_state.committed_transfers as Array
		var new_ledger := state.authority_state.committed_transfers as Array
		for entry: Dictionary in old_ledger:
			if str(entry.transfer_id).begins_with(str(ACTIVITY_ID) + "_g") and not new_ledger.has(entry):
				return _result(false, &"stale_jovian_inventory")
		if JSON.stringify(old_record) == JSON.stringify(record):
			return _result(true, &"jovian_session_unchanged")
	elif activity.get_state() == CargoDeliveryActivity.State.IDLE:
		return _result(false, &"unproven_jovian_reset")
	payload[String(SLOT_ID)] = record
	return _store.commit(payload, _store.get_generation(), commit_id)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and absf(float(value)) <= CargoTransferAuthority.MAX_SAFE_INTEGER
