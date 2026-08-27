class_name CinderRaceSessionPersistence
extends RefCounted

## Strict codec and namespace merger for the existing Cinder race authorities.
## CinderTimedRaceSession, TimedCheckpointRace and ActivityDirector still own
## every live generation, clock and gate. UserDataStore remains the only byte
## and transaction authority; this object owns neither a clock nor live state.
## The existing NearbySectorActivitySessionAdapter owns the versioned record
## schema and already explicitly supports the Cinder checkpoint-route ID.

var _store: UserDataStore
var _slot_id: StringName = &""
var _codec: NearbySectorActivitySessionAdapter


func configure(store: UserDataStore, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty():
		return _result(false, &"race_session_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	_codec = NearbySectorActivitySessionAdapter.new()
	return _result(true, &"race_session_persistence_configured")


func load(
	session: CinderTimedRaceSession,
	director: ActivityDirector
	) -> Dictionary:
	if not _configured() or session == null or not is_instance_valid(director):
		return _result(false, &"race_session_persistence_unavailable")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"race_session_not_found")
	var validated := validate_record(payload.get(slot_key), session, director)
	if not bool(validated.get("accepted", false)):
		return validated
	var decoded := _decode_record(payload[slot_key] as Dictionary)
	return {
		"accepted": true,
		"reason": &"race_session_loaded",
		"store_generation": _store.get_generation(),
		"session_state": (decoded.session_state as Dictionary).duplicate(true),
	}.duplicate(true)


func save(
	session: CinderTimedRaceSession,
	director: ActivityDirector,
	commit_id: String
	) -> Dictionary:
	if session == null:
		return _result(false, &"race_session_save_invalid")
	return save_state(
		session.capture_persistence_state(), session, director, commit_id
	)


## Public only so the authority owner and focused corruption test can exercise
## the same validation boundary. Production passes the session's exact capture.
func save_state(
	state: Dictionary,
	session: CinderTimedRaceSession,
	director: ActivityDirector,
	commit_id: String
	) -> Dictionary:
	if not _configured() or session == null or not is_instance_valid(director) \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"race_session_save_invalid")
	var record := _record(state)
	var validated := validate_record(record, session, director)
	if not bool(validated.get("accepted", false)):
		return validated
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	if loaded.get("reason", &"") == &"primary_invalid_backup_loaded":
		return _result(false, &"race_session_store_recovery_required")
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if payload.has(slot_key):
		var existing_validation := validate_record(
			payload.get(slot_key), session, director
		)
		if not bool(existing_validation.get("accepted", false)):
			return existing_validation
		var existing_record := _decode_record(payload[slot_key] as Dictionary)
		var transition := _validate_transition(
			existing_record.session_state as Dictionary, state
		)
		if not bool(transition.get("accepted", false)):
			return transition
		if transition.get("reason", &"") == &"race_session_unchanged":
			return {
				"accepted": true,
				"reason": &"race_session_unchanged",
				"generation": _store.get_generation(),
			}.duplicate(true)
	payload[slot_key] = record
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	committed["binding_reason"] = (
		&"race_session_saved"
		if bool(committed.get("accepted", false)) else &"store_rejected"
	)
	return committed


func validate_record(
	candidate: Variant,
	session: CinderTimedRaceSession,
	director: ActivityDirector
	) -> Dictionary:
	if not candidate is Dictionary or session == null or not is_instance_valid(director):
		return _result(false, &"race_session_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 2 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) \
			!= NearbySectorActivitySessionAdapter.SCHEMA_VERSION \
			or not record.get("activities") is Array \
			or (record.activities as Array).size() != 1:
		return _result(false, &"race_session_payload_corrupt")
	var activity: Variant = (record.activities as Array)[0]
	if not activity is Dictionary:
		return _result(false, &"race_session_payload_corrupt")
	var activity_record := activity as Dictionary
	if activity_record.size() != 6 \
			or str(activity_record.get("activity_id", "")) \
			!= str(CinderTimedRaceSession.ROUTE.activity_id) \
			or not _integral(activity_record.get("generation")) \
			or not _integral(activity_record.get("state")) \
			or activity_record.get("reward_requested") != false \
			or activity_record.get("reward_granted") != false \
			or not activity_record.get("progress") is Dictionary:
		return _result(false, &"race_session_payload_corrupt")
	var progress := activity_record.progress as Dictionary
	if progress.size() != 4 \
			or str(progress.get("activity_id", "")) \
			!= str(CinderTimedRaceSession.ROUTE.activity_id) \
			or not _integral(progress.get("generation")) \
			or not _integral(progress.get("state")) \
			or not progress.get("session_state") is Dictionary \
			or int(progress.generation) != int(activity_record.generation) \
			or int(progress.state) != int(activity_record.state):
		return _result(false, &"race_session_payload_corrupt")
	var validated := session.validate_persistence_state(
		progress.session_state, director
	)
	if not bool(validated.get("accepted", false)):
		return _result(false, &"race_session_payload_corrupt", {
			"payload_reason": validated.get("reason", &"invalid_session_state"),
		})
	return _result(true, &"race_session_payload_valid")


func get_store_generation() -> int:
	return _store.get_generation() if _configured() else -1


func _validate_transition(existing: Dictionary, candidate: Dictionary) -> Dictionary:
	var existing_generation := int(existing.get("session_generation", -1))
	var candidate_generation := int(candidate.get("session_generation", -1))
	if candidate_generation < existing_generation:
		return _result(false, &"stale_race_session")
	if candidate_generation > existing_generation:
		return _result(true, &"new_race_session_generation")
	if existing == candidate:
		return _result(true, &"race_session_unchanged")
	var existing_race := existing.race_state as Dictionary
	var candidate_race := candidate.race_state as Dictionary
	var existing_state := int(existing_race.get("state", -1))
	var candidate_state := int(candidate_race.get("state", -1))
	if _state_rank(candidate_state) < _state_rank(existing_state):
		return _result(false, &"stale_race_session")
	if _state_rank(candidate_state) == _state_rank(existing_state) \
			and candidate_state != existing_state:
		return _result(false, &"conflicting_race_session_terminal")
	if existing_state == TimedCheckpointRace.State.COUNTDOWN \
			and candidate_state == TimedCheckpointRace.State.COUNTDOWN \
			and float(candidate_race.get("countdown_remaining_seconds", 0.0)) \
			> float(existing_race.get("countdown_remaining_seconds", 0.0)):
		return _result(false, &"stale_race_session")
	if float(candidate_race.get("race_elapsed_seconds", -1.0)) \
			< float(existing_race.get("race_elapsed_seconds", 0.0)) \
			or float(candidate_race.get("penalty_seconds", -1.0)) \
			< float(existing_race.get("penalty_seconds", 0.0)):
		return _result(false, &"stale_race_session")
	if existing_state == TimedCheckpointRace.State.ACTIVE \
			and candidate_state == TimedCheckpointRace.State.ACTIVE:
		var existing_lap := int(existing_race.get("current_lap", -1))
		var candidate_lap := int(candidate_race.get("current_lap", -1))
		var existing_checkpoint := int(existing_race.get("next_checkpoint_index", -1))
		var candidate_checkpoint := int(candidate_race.get("next_checkpoint_index", -1))
		if candidate_lap < existing_lap or (
			candidate_lap == existing_lap and candidate_checkpoint < existing_checkpoint
		):
			return _result(false, &"stale_race_session")
	return _result(true, &"race_session_advanced")


func _state_rank(state: int) -> int:
	match state:
		TimedCheckpointRace.State.IDLE:
			return 0
		TimedCheckpointRace.State.COUNTDOWN:
			return 1
		TimedCheckpointRace.State.ACTIVE:
			return 2
		TimedCheckpointRace.State.COMPLETED, TimedCheckpointRace.State.FAILED:
			return 3
	return -1


func _record(state: Dictionary) -> Dictionary:
	var race_state := state.get("race_state", {}) as Dictionary
	var record := _codec.capture({
		"race": {
			"activity_id": CinderTimedRaceSession.ROUTE.activity_id,
			"generation": int(state.get("session_generation", 0)),
			"state": int(race_state.get("state", TimedCheckpointRace.State.IDLE)),
			"session_state": state.duplicate(true),
		},
	})
	# The existing session codec is also used detached from JSON and therefore
	# retains StringName identities. UserDataStore's established wire contract is
	# stricter; canonicalize only those two copies before the atomic merge.
	var activity := (record.activities as Array)[0] as Dictionary
	activity.activity_id = str(activity.activity_id)
	var progress := activity.progress as Dictionary
	progress.activity_id = str(progress.activity_id)
	return record.duplicate(true)


func _decode_record(record: Dictionary) -> Dictionary:
	var activity := (record.get("activities", []) as Array)[0] as Dictionary
	var progress := activity.get("progress", {}) as Dictionary
	return {
		"session_state": (progress.get("session_state", {}) as Dictionary).duplicate(true),
	}.duplicate(true)


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(
	accepted: bool,
	reason: StringName,
	details: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	result.merge(details, true)
	return result
