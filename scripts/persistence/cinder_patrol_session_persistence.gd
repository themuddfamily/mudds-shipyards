class_name CinderPatrolSessionPersistence
extends RefCounted

## Strict exact-live codec for the existing Cinder PatrolActivity and its
## ActivityDirector route. UserDataStore remains the sole byte/transaction
## authority; this adapter owns no clock, route, actor, reward, or generation.

var _store: UserDataStore
var _slot_id: StringName = &""
var _codec: NearbySectorActivitySessionAdapter


func configure(store: UserDataStore, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty():
		return _result(false, &"patrol_session_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	_codec = NearbySectorActivitySessionAdapter.new()
	return _result(true, &"patrol_session_persistence_configured")


func load(patrol: PatrolActivity, director: ActivityDirector) -> Dictionary:
	if not _configured() or patrol == null or not is_instance_valid(director):
		return _result(false, &"patrol_session_persistence_unavailable")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"patrol_session_not_found")
	var validated := validate_record(payload.get(slot_key), patrol, director)
	if not bool(validated.get("accepted", false)):
		return validated
	var decoded := _decode_record(payload[slot_key] as Dictionary)
	return {
		"accepted": true,
		"reason": &"patrol_session_loaded",
		"store_generation": _store.get_generation(),
		"patrol_state": (decoded.patrol_state as Dictionary).duplicate(true),
	}.duplicate(true)


func save(
	patrol: PatrolActivity,
	director: ActivityDirector,
	commit_id: String
	) -> Dictionary:
	if patrol == null:
		return _result(false, &"patrol_session_save_invalid")
	return save_state(
		patrol.capture_persistence_state(), patrol, director, commit_id
	)


## Public only for focused corruption checks. The canonical input must be byte-
## equivalent to a fresh live authority capture before it can reach storage.
func save_state(
	state: Dictionary,
	patrol: PatrolActivity,
	director: ActivityDirector,
	commit_id: String
	) -> Dictionary:
	if not _configured() or patrol == null or not is_instance_valid(director) \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"patrol_session_save_invalid")
	var canonical_state := _canonical_state(state)
	var canonical_live_state := _canonical_state(patrol.capture_persistence_state())
	if canonical_state.is_empty() or canonical_live_state.is_empty():
		return _result(false, &"patrol_session_save_invalid")
	var record := _record(canonical_state)
	var validated := validate_record(record, patrol, director)
	if not bool(validated.get("accepted", false)):
		return validated
	if canonical_state != canonical_live_state:
		return _result(false, &"patrol_session_not_live_capture")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	if loaded.get("reason", &"") == &"primary_invalid_backup_loaded":
		return _result(false, &"patrol_session_store_recovery_required")
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if payload.has(slot_key):
		var existing_validation := validate_record(
			payload.get(slot_key), patrol, director
		)
		if not bool(existing_validation.get("accepted", false)):
			return existing_validation
		var existing := _decode_record(payload[slot_key] as Dictionary)
		var transition := _validate_transition(
			existing.patrol_state as Dictionary, canonical_state
		)
		if not bool(transition.get("accepted", false)):
			return transition
		if transition.get("reason", &"") == &"patrol_session_unchanged":
			return {
				"accepted": true,
				"reason": &"patrol_session_unchanged",
				"generation": _store.get_generation(),
			}.duplicate(true)
	payload[slot_key] = record
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	committed["binding_reason"] = (
		&"patrol_session_saved"
		if bool(committed.get("accepted", false)) else &"store_rejected"
	)
	return committed


func validate_record(
	candidate: Variant,
	patrol: PatrolActivity,
	director: ActivityDirector
	) -> Dictionary:
	if not candidate is Dictionary or patrol == null or patrol.definition == null \
			or not is_instance_valid(director):
		return _result(false, &"patrol_session_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 2 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) \
			!= NearbySectorActivitySessionAdapter.SCHEMA_VERSION \
			or not record.get("activities") is Array \
			or (record.activities as Array).size() != 1:
		return _result(false, &"patrol_session_payload_corrupt")
	var raw_activity: Variant = (record.activities as Array)[0]
	if not raw_activity is Dictionary:
		return _result(false, &"patrol_session_payload_corrupt")
	var activity := raw_activity as Dictionary
	var saved_activity_id := str(activity.get("activity_id", ""))
	if activity.size() != 6 \
			or activity.get("activity_id") is not String \
			or not NearbySectorActivitySessionAdapter.SUPPORTED_ACTIVITY_IDS.has(
				StringName(saved_activity_id)
			) \
			or not _integral(activity.get("generation")) \
			or not _integral(activity.get("state")) \
			or activity.get("reward_requested") is not bool \
			or bool(activity.get("reward_requested", true)) \
			or activity.get("reward_granted") is not bool \
			or bool(activity.get("reward_granted", true)) \
			or not activity.get("progress") is Dictionary:
		return _result(false, &"patrol_session_payload_corrupt")
	var progress := activity.progress as Dictionary
	if progress.size() != 4 \
			or progress.get("activity_id") is not String \
			or str(progress.get("activity_id", "")) != saved_activity_id \
			or not _integral(progress.get("generation")) \
			or not _integral(progress.get("state")) \
			or not progress.get("patrol_state") is Dictionary \
			or int(progress.generation) != int(activity.generation) \
			or int(progress.state) != int(activity.state):
		return _result(false, &"patrol_session_payload_corrupt")
	var patrol_state := progress.patrol_state as Dictionary
	if str(patrol_state.get("activity_id", "")) != saved_activity_id \
			or int(progress.generation) != int(patrol_state.get("generation", -1)) \
			or int(progress.state) != int(patrol_state.get("state", -1)):
		return _result(false, &"patrol_session_payload_corrupt")
	var validated := patrol.validate_persistence_state(
		patrol_state, director
	)
	if not bool(validated.get("accepted", false)):
		return _result(false, &"patrol_session_payload_corrupt", {
			"payload_reason": validated.get("reason", &"invalid_patrol_state"),
		})
	return _result(true, &"patrol_session_payload_valid")


func get_store_generation() -> int:
	return _store.get_generation() if _configured() else -1


func _validate_transition(existing: Dictionary, candidate: Dictionary) -> Dictionary:
	var existing_generation := int(existing.get("generation", -1))
	var candidate_generation := int(candidate.get("generation", -1))
	if candidate_generation < existing_generation:
		return _result(false, &"stale_patrol_session")
	if candidate_generation > existing_generation:
		if candidate_generation != existing_generation + 1:
			return _result(false, &"unproven_patrol_generation")
		return _validate_next_generation(existing, candidate)
	if existing == candidate:
		return _result(true, &"patrol_session_unchanged")
	var existing_state := int(existing.get("state", -1))
	var candidate_state := int(candidate.get("state", -1))
	var existing_progress := int(existing.get("completed_checkpoint_count", -1))
	var candidate_progress := int(candidate.get("completed_checkpoint_count", -1))
	if float(candidate.get("elapsed_seconds", -1.0)) \
			< float(existing.get("elapsed_seconds", 0.0)) \
			or candidate_progress < existing_progress:
		return _result(false, &"stale_patrol_session")
	if existing_state == PatrolActivity.State.ACTIVE:
		if candidate_state == PatrolActivity.State.ACTIVE:
			var progress_delta := candidate_progress - existing_progress
			if progress_delta < 0 or progress_delta > 1 \
					or not _same_last_duration(existing, candidate):
				return _result(false, &"unproven_patrol_progress")
			if progress_delta == 1:
				if int(existing.get("dwell_checkpoint_index", -1)) != existing_progress \
						or int(candidate.get("dwell_checkpoint_index", -2)) \
						!= PatrolActivity.ANY_CHECKPOINT:
					return _result(false, &"unproven_patrol_checkpoint")
				return _result(true, &"patrol_checkpoint_completed")
			return _validate_same_checkpoint_dwell(existing, candidate)
		if candidate_state == PatrolActivity.State.COMPLETED:
			if existing_progress != patrol_checkpoint_count() - 1 \
					or candidate_progress != patrol_checkpoint_count() \
					or int(existing.get("dwell_checkpoint_index", -1)) \
					!= existing_progress:
				return _result(false, &"unproven_patrol_completion")
			return _result(true, &"patrol_session_completed")
		if candidate_state in [PatrolActivity.State.FAILED, PatrolActivity.State.ABORTED]:
			if candidate_progress != existing_progress \
					or not _same_last_duration(existing, candidate):
				return _result(false, &"unproven_patrol_terminal")
			return _result(true, &"patrol_session_terminal")
	return _result(false, &"unproven_patrol_transition")


func _validate_same_checkpoint_dwell(
	existing: Dictionary,
	candidate: Dictionary
	) -> Dictionary:
	var existing_dwell := int(existing.get("dwell_checkpoint_index", -1))
	var candidate_dwell := int(candidate.get("dwell_checkpoint_index", -1))
	var checkpoint := int(existing.get("completed_checkpoint_count", -1))
	if existing_dwell == PatrolActivity.ANY_CHECKPOINT:
		if candidate_dwell not in [PatrolActivity.ANY_CHECKPOINT, checkpoint]:
			return _result(false, &"unproven_patrol_dwell")
		return _result(true, &"patrol_dwell_started" if candidate_dwell == checkpoint else &"patrol_time_advanced")
	if candidate_dwell != existing_dwell:
		return _result(false, &"unproven_patrol_dwell")
	var existing_elapsed := float(existing.get("dwell_elapsed_seconds", -1.0))
	var candidate_elapsed := float(candidate.get("dwell_elapsed_seconds", -1.0))
	if candidate_elapsed >= existing_elapsed:
		return _result(true, &"patrol_dwell_advanced")
	# Leaving the occupied checkpoint legitimately cancels continuous dwell; no
	# other backwards transition is admitted.
	if bool(existing.get("checkpoint_occupied", false)) \
			and not bool(candidate.get("checkpoint_occupied", true)) \
			and is_zero_approx(candidate_elapsed):
		return _result(true, &"patrol_dwell_interrupted")
	return _result(false, &"stale_patrol_dwell")


func _validate_next_generation(existing: Dictionary, candidate: Dictionary) -> Dictionary:
	var candidate_state := int(candidate.get("state", -1))
	if candidate_state == PatrolActivity.State.IDLE:
		if int(candidate.get("completed_checkpoint_count", -1)) != 0 \
				or not is_zero_approx(float(candidate.get("elapsed_seconds", -1.0))):
			return _result(false, &"unproven_patrol_generation")
		return _result(true, &"patrol_session_reset")
	if int(existing.get("state", -1)) == PatrolActivity.State.IDLE \
			and candidate_state == PatrolActivity.State.ACTIVE \
			and int(candidate.get("completed_checkpoint_count", -1)) == 0 \
			and int(candidate.get("dwell_checkpoint_index", -2)) \
			== PatrolActivity.ANY_CHECKPOINT \
			and is_zero_approx(float(candidate.get("elapsed_seconds", -1.0))):
		return _result(true, &"new_patrol_session_generation")
	return _result(false, &"unproven_patrol_generation")


func _same_last_duration(left: Dictionary, right: Dictionary) -> bool:
	return is_equal_approx(
		float(left.get("last_duration_seconds", -1.0)),
		float(right.get("last_duration_seconds", -2.0))
	)


func patrol_checkpoint_count() -> int:
	# Both typed Cinder activities intentionally reuse this authored route.
	return CinderTimedRaceSession.ROUTE.get_checkpoint_count()


func _record(state: Dictionary) -> Dictionary:
	var record := _codec.capture({
		"patrol": {
			"activity_id": str(state.get("activity_id", "")),
			"generation": int(state.get("generation", 0)),
			"state": int(state.get("state", PatrolActivity.State.IDLE)),
			"patrol_state": state.duplicate(true),
		},
	})
	var activity := (record.activities as Array)[0] as Dictionary
	activity.activity_id = str(activity.activity_id)
	var progress := activity.progress as Dictionary
	progress.activity_id = str(progress.activity_id)
	return record.duplicate(true)


func _decode_record(record: Dictionary) -> Dictionary:
	var activity := (record.get("activities", []) as Array)[0] as Dictionary
	var progress := activity.get("progress", {}) as Dictionary
	return {
		"patrol_state": (progress.get("patrol_state", {}) as Dictionary).duplicate(true),
	}.duplicate(true)


func _canonical_state(state: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(JSON.stringify(state))
	return (decoded as Dictionary).duplicate(true) if decoded is Dictionary else {}


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
	result.merge(details.duplicate(true), true)
	return result
