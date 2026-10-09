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
		"reward_requested": bool((payload[slot_key].activities[0] as Dictionary).reward_requested),
		"reward_granted": bool((payload[slot_key].activities[0] as Dictionary).reward_granted),
	}.duplicate(true)


func save(
	session: CinderTimedRaceSession,
	director: ActivityDirector,
	commit_id: String,
	reset_source: CinderTimedRaceSession = null
	) -> Dictionary:
	if session == null:
		return _result(false, &"race_session_save_invalid")
	return save_state(
		session.capture_persistence_state(), session, director, commit_id, reset_source
	)


## This remains public for the focused corruption contract, but it is not a
## caller-authored state ingress: only the canonical JSON representation of the
## exact live authority capture may proceed to transition validation or bytes.
func save_state(
	state: Dictionary,
	session: CinderTimedRaceSession,
	director: ActivityDirector,
	commit_id: String,
	reset_source: CinderTimedRaceSession = null
	) -> Dictionary:
	if not _configured() or session == null or not is_instance_valid(director) \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"race_session_save_invalid")
	var canonical_state := _canonical_state(state)
	var canonical_live_state := _canonical_state(
		session.capture_persistence_state()
	)
	if canonical_state.is_empty() or canonical_live_state.is_empty():
		return _result(false, &"race_session_save_invalid")
	var record := _record(canonical_state)
	var validated := validate_record(record, session, director)
	if not bool(validated.get("accepted", false)):
		return validated
	if canonical_state != canonical_live_state:
		return _result(false, &"race_session_not_live_capture")
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
		var existing_activity := (payload[slot_key].activities[0] as Dictionary)
		var candidate_activity := (record.activities[0] as Dictionary)
		if int(existing_activity.generation) == int(candidate_activity.generation):
			# Preserve the durable terminal handoff and its atomic receipt ack.
			# Legacy false/false completions remain ambiguous and are not re-paid.
			if int(existing_activity.state) == TimedCheckpointRace.State.COMPLETED:
				candidate_activity.reward_requested = existing_activity.reward_requested
				candidate_activity.reward_granted = existing_activity.reward_granted
		var existing_record := _decode_record(payload[slot_key] as Dictionary)
		if int(candidate_activity.generation) > int(existing_activity.generation) \
				and bool(existing_activity.reward_requested) and not bool(existing_activity.reward_granted):
			return _result(false, &"race_session_reward_pending")
		var transition := _validate_transition(
			existing_record.session_state as Dictionary, canonical_state, session, director, reset_source
		)
		if not bool(transition.get("accepted", false)):
			return transition
		if transition.get("reason", &"") == &"race_session_unchanged":
			session.acknowledge_persisted_capture(canonical_state)
			return {
				"accepted": true,
				"reason": &"race_session_unchanged",
				"generation": _store.get_generation(),
			}.duplicate(true)
	payload[slot_key] = record
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	if bool(committed.get("accepted", false)):
		session.acknowledge_persisted_capture(canonical_state)
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
			or activity_record.get("reward_requested") is not bool \
			or activity_record.get("reward_granted") is not bool \
			or not activity_record.get("progress") is Dictionary:
		return _result(false, &"race_session_payload_corrupt")
	if bool(activity_record.reward_granted) and not bool(activity_record.reward_requested):
		return _result(false, &"race_session_payload_corrupt")
	if (bool(activity_record.reward_requested) or bool(activity_record.reward_granted)) \
			and int(activity_record.state) != TimedCheckpointRace.State.COMPLETED:
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


func _validate_transition(existing: Dictionary, candidate: Dictionary, session: CinderTimedRaceSession,
		director: ActivityDirector, reset_source: CinderTimedRaceSession) -> Dictionary:
	var existing_generation := int(existing.get("session_generation", -1))
	var candidate_generation := int(candidate.get("session_generation", -1))
	if candidate_generation < existing_generation:
		return _result(false, &"stale_race_session")
	if candidate_generation > existing_generation:
		if candidate_generation == existing_generation + 2 \
				and int(candidate.race_state.state) == TimedCheckpointRace.State.IDLE \
				and reset_source != null and reset_source.owns_staged_persistence_reset(session, director):
			var source := _canonical_state(reset_source.capture_persistence_state())
			var validated := reset_source.validate_persistence_state(source, director)
			if bool(validated.get("accepted", false)) \
					and int(source.race_state.state) in [TimedCheckpointRace.State.COUNTDOWN, TimedCheckpointRace.State.ACTIVE, TimedCheckpointRace.State.FAILED] \
					and _live_start_is_proven(existing, source, reset_source) \
					and _same_results(source.race_state, candidate.race_state):
				return _result(true, &"race_session_unsaved_run_reset")
		if candidate_generation != existing_generation + 1:
			return _result(false, &"unproven_race_session_generation")
		return _validate_next_generation_transition(existing, candidate, session)
	if existing == candidate:
		return _result(true, &"race_session_unchanged")
	var existing_race := existing.race_state as Dictionary
	var candidate_race := candidate.race_state as Dictionary
	var existing_state := int(existing_race.get("state", -1))
	var candidate_state := int(candidate_race.get("state", -1))
	if float(candidate_race.get("race_elapsed_seconds", -1.0)) \
			< float(existing_race.get("race_elapsed_seconds", 0.0)) \
			or float(candidate_race.get("penalty_seconds", -1.0)) \
			< float(existing_race.get("penalty_seconds", 0.0)):
		return _result(false, &"stale_race_session")
	if existing_state in [TimedCheckpointRace.State.COUNTDOWN, TimedCheckpointRace.State.ACTIVE] \
			and candidate_state == TimedCheckpointRace.State.COMPLETED \
			and _canonical_state(session.get_acknowledged_persistence_state()) == existing \
			and _completion_results_follow(existing_race, candidate_race):
		# Both current terminal authorities and the exact live capture have already
		# been validated. The retained acknowledgement identifies this actual run's
		# saved boundary even when its later ordered gate writes were rejected.
		return _result(true, &"race_session_unsaved_completion_recovered")
	match existing_state:
		TimedCheckpointRace.State.COUNTDOWN:
			if candidate_state == TimedCheckpointRace.State.COUNTDOWN:
				if float(candidate_race.countdown_remaining_seconds) \
						> float(existing_race.countdown_remaining_seconds) \
						or not _same_results(existing_race, candidate_race):
					return _result(false, &"stale_race_session")
				return _result(true, &"race_session_countdown_advanced")
			if candidate_state == TimedCheckpointRace.State.ACTIVE \
					and _active_progress_ordinal(candidate_race) == 0 \
					and _same_results(existing_race, candidate_race):
				return _result(true, &"race_session_activated")
			if candidate_state == TimedCheckpointRace.State.FAILED \
					and _same_checkpoint(existing_race, candidate_race) \
					and _same_results(existing_race, candidate_race):
				return _result(true, &"race_session_failed")
		TimedCheckpointRace.State.ACTIVE:
			if candidate_state == TimedCheckpointRace.State.ACTIVE:
				var progress_delta := (
					_active_progress_ordinal(candidate_race)
					- _active_progress_ordinal(existing_race)
				)
				if progress_delta < 0 or progress_delta > 1 \
						or not _same_results(existing_race, candidate_race):
					return _result(false, &"unproven_race_session_progress")
				return _result(true, &"race_session_advanced")
			if candidate_state == TimedCheckpointRace.State.COMPLETED:
				var checkpoint_count := CinderTimedRaceSession.ROUTE.get_checkpoint_count()
				var total_progress := int(existing_race.get("lap_count", 0)) * checkpoint_count
				if _active_progress_ordinal(existing_race) != total_progress - 1:
					return _result(false, &"unproven_race_session_completion")
				return _result(true, &"race_session_completed")
			if candidate_state == TimedCheckpointRace.State.FAILED \
					and _same_checkpoint(existing_race, candidate_race) \
					and _same_results(existing_race, candidate_race):
				return _result(true, &"race_session_failed")
	return _result(false, &"unproven_race_session_transition")


func _validate_next_generation_transition(
	existing: Dictionary,
	candidate: Dictionary,
	session: CinderTimedRaceSession
	) -> Dictionary:
	var existing_race := existing.race_state as Dictionary
	var candidate_race := candidate.race_state as Dictionary
	var candidate_state := int(candidate_race.get("state", -1))
	if _live_start_is_proven(existing, candidate, session):
		return _result(true, &"race_session_unsaved_run_recovered")
	if candidate_state not in [
		TimedCheckpointRace.State.IDLE,
		TimedCheckpointRace.State.COUNTDOWN,
	] or not _same_results(existing_race, candidate_race):
		return _result(false, &"unproven_race_session_generation")
	if candidate_state == TimedCheckpointRace.State.COUNTDOWN \
			and not is_equal_approx(
				float(candidate_race.get("countdown_remaining_seconds", -1.0)),
				float(candidate.get("configured_countdown_seconds", -2.0))
			):
		return _result(false, &"unproven_race_session_generation")
	return _result(true, &"new_race_session_generation")


func _live_start_is_proven(existing: Dictionary, candidate: Dictionary, session: CinderTimedRaceSession) -> bool:
	if int(existing.race_state.state) != TimedCheckpointRace.State.IDLE \
			or int(candidate.session_generation) != int(existing.session_generation) + 1 \
			or _canonical_state(session.get_persistence_start_state()) != existing:
		return false
	var before := existing.race_state as Dictionary
	var after := candidate.race_state as Dictionary
	if int(after.state) in [TimedCheckpointRace.State.COUNTDOWN, TimedCheckpointRace.State.ACTIVE, TimedCheckpointRace.State.FAILED]:
		return _same_results(before, after)
	if int(after.state) != TimedCheckpointRace.State.COMPLETED:
		return false
	# The existing typed validators already prove both terminal route states and
	# last == elapsed + penalty. Preserve the actual prior best-result boundary.
	return _completion_results_follow(before, after)


func _completion_results_follow(before: Dictionary, after: Dictionary) -> bool:
	var last := float(after.race_elapsed_seconds) + float(after.penalty_seconds)
	var previous_best := float(before.best_time_seconds)
	var best := last if previous_best < 0.0 else minf(previous_best, last)
	return is_equal_approx(float(after.last_time_seconds), last) and is_equal_approx(float(after.best_time_seconds), best)


func _active_progress_ordinal(race: Dictionary) -> int:
	return (
		int(race.get("current_lap", 0))
		* CinderTimedRaceSession.ROUTE.get_checkpoint_count()
		+ int(race.get("next_checkpoint_index", 0))
	)


func _same_checkpoint(left: Dictionary, right: Dictionary) -> bool:
	return (
		int(left.get("current_lap", -1)) == int(right.get("current_lap", -2))
		and int(left.get("next_checkpoint_index", -1))
		== int(right.get("next_checkpoint_index", -2))
	)


func _same_results(left: Dictionary, right: Dictionary) -> bool:
	return (
		is_equal_approx(
			float(left.get("last_time_seconds", -1.0)),
			float(right.get("last_time_seconds", -2.0))
		)
		and is_equal_approx(
			float(left.get("best_time_seconds", -1.0)),
			float(right.get("best_time_seconds", -2.0))
		)
	)


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
	# A terminal result explicitly owes a receipt until the reward owner marks
	# granted in the same atomic commit that publishes that receipt.
	activity.reward_requested = int(activity.state) == TimedCheckpointRace.State.COMPLETED
	var progress := activity.progress as Dictionary
	progress.activity_id = str(progress.activity_id)
	return record.duplicate(true)


func _decode_record(record: Dictionary) -> Dictionary:
	var activity := (record.get("activities", []) as Array)[0] as Dictionary
	var progress := activity.get("progress", {}) as Dictionary
	return {
		"session_state": (progress.get("session_state", {}) as Dictionary).duplicate(true),
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
	result.merge(details, true)
	return result
