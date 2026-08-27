class_name CinderConvoySessionPersistence
extends RefCounted

## Strict exact-live codec for the existing production convoy host and its
## embedded ConvoyEscortActivity. UserDataStore remains the sole byte and
## transaction authority; this adapter owns no route, clock, entity, arrival,
## reward, ship, streaming, or gameplay lifecycle.

const SESSION_SCHEMA_VERSION := 1
const ACTIVITY_KIND := "convoy_escort"
const PHASE_ID := "escort"
const STREAM_LOCATION_ID := "cinder_reach"

var _store: UserDataStore
var _slot_id: StringName = &""
var _codec: NearbySectorActivitySessionAdapter


func configure(store: UserDataStore, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty():
		return _result(false, &"convoy_session_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	_codec = NearbySectorActivitySessionAdapter.new()
	return _result(true, &"convoy_session_persistence_configured")


func load(host: CinderConvoyEscortHost) -> Dictionary:
	if not _configured() or not is_instance_valid(host):
		return _result(false, &"convoy_session_persistence_unavailable")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"convoy_session_not_found")
	var validated := validate_record(payload.get(slot_key), host)
	if not bool(validated.get("accepted", false)):
		return validated
	var decoded := _decode_record(payload[slot_key] as Dictionary)
	return {
		"accepted": true,
		"reason": &"convoy_session_loaded",
		"store_generation": _store.get_generation(),
		"session_state": (decoded.session_state as Dictionary).duplicate(true),
	}.duplicate(true)


func save(
		host: CinderConvoyEscortHost,
		escort_ship_id: StringName,
		commit_id: String
	) -> Dictionary:
	if not is_instance_valid(host):
		return _result(false, &"convoy_session_save_invalid")
	return save_state(
		_capture_session_state(host, escort_ship_id),
		host,
		escort_ship_id,
		commit_id
	)


## Public only for the focused corruption contract. A caller-authored value
## must be byte-equivalent to a fresh capture from both live authorities.
func save_state(
		state: Dictionary,
		host: CinderConvoyEscortHost,
		escort_ship_id: StringName,
		commit_id: String
	) -> Dictionary:
	if not _configured() or not is_instance_valid(host) \
			or not _stable_ship_id(str(escort_ship_id)) \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"convoy_session_save_invalid")
	var canonical_state := _canonical_state(state)
	var canonical_live_state := _canonical_state(
		_capture_session_state(host, escort_ship_id)
	)
	if canonical_state.is_empty() or canonical_live_state.is_empty():
		return _result(false, &"convoy_session_save_invalid")
	var record := _record(canonical_state)
	var validated := validate_record(record, host)
	if not bool(validated.get("accepted", false)):
		return validated
	if canonical_state != canonical_live_state:
		return _result(false, &"convoy_session_not_live_capture")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	if loaded.get("reason", &"") == &"primary_invalid_backup_loaded":
		return _result(false, &"convoy_session_store_recovery_required")
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if payload.has(slot_key):
		var existing_validation := validate_record(payload.get(slot_key), host)
		if not bool(existing_validation.get("accepted", false)):
			return existing_validation
		var existing := _decode_record(payload[slot_key] as Dictionary)
		var transition := _validate_transition(
			existing.session_state as Dictionary, canonical_state
		)
		if not bool(transition.get("accepted", false)):
			return transition
		if transition.get("reason", &"") == &"convoy_session_unchanged":
			return {
				"accepted": true,
				"reason": &"convoy_session_unchanged",
				"generation": _store.get_generation(),
			}.duplicate(true)
	payload[slot_key] = record
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	committed["binding_reason"] = (
		&"convoy_session_saved"
		if bool(committed.get("accepted", false)) else &"store_rejected"
	)
	return committed


## Terminal convoy state is never serialized or restored. This separate
## accepted transaction retires the last active record without inspecting or
## changing the independent safe-arrival history namespace.
func retire(host: CinderConvoyEscortHost, commit_id: String) -> Dictionary:
	if not _configured() or not is_instance_valid(host) \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"convoy_session_retire_invalid")
	var loaded := _store.load()
	if not bool(loaded.get("accepted", false)):
		return loaded
	if loaded.get("reason", &"") == &"primary_invalid_backup_loaded":
		return _result(false, &"convoy_session_store_recovery_required")
	var payload := _store.get_snapshot()
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return {
			"accepted": true,
			"reason": &"convoy_session_not_found",
			"generation": _store.get_generation(),
		}.duplicate(true)
	var validated := validate_record(payload.get(slot_key), host)
	if not bool(validated.get("accepted", false)):
		return validated
	payload.erase(slot_key)
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	committed["binding_reason"] = (
		&"convoy_session_retired"
		if bool(committed.get("accepted", false)) else &"store_rejected"
	)
	return committed


func validate_record(candidate: Variant, host: CinderConvoyEscortHost) -> Dictionary:
	if not candidate is Dictionary or not is_instance_valid(host):
		return _result(false, &"convoy_session_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 2 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) \
			!= NearbySectorActivitySessionAdapter.SCHEMA_VERSION \
			or not record.get("activities") is Array \
			or (record.activities as Array).size() != 1:
		return _result(false, &"convoy_session_payload_corrupt")
	var raw_activity: Variant = (record.activities as Array)[0]
	if not raw_activity is Dictionary:
		return _result(false, &"convoy_session_payload_corrupt")
	var activity := raw_activity as Dictionary
	if activity.size() != 6 \
			or activity.get("activity_id") is not String \
			or str(activity.get("activity_id", "")) \
			!= str(CinderConvoyEscortHost.ROUTE.activity_id) \
			or not _integral(activity.get("generation")) \
			or int(activity.get("state", -1)) != ConvoyEscortActivity.State.ACTIVE \
			or activity.get("reward_requested") is not bool \
			or bool(activity.get("reward_requested", true)) \
			or activity.get("reward_granted") is not bool \
			or bool(activity.get("reward_granted", true)) \
			or not activity.get("progress") is Dictionary:
		return _result(false, &"convoy_session_payload_corrupt")
	var progress := activity.progress as Dictionary
	if progress.size() != 4 \
			or progress.get("activity_id") is not String \
			or str(progress.get("activity_id", "")) \
			!= str(CinderConvoyEscortHost.ROUTE.activity_id) \
			or not _integral(progress.get("generation")) \
			or int(progress.get("state", -1)) != ConvoyEscortActivity.State.ACTIVE \
			or not progress.get("convoy_session_state") is Dictionary \
			or int(progress.generation) != int(activity.generation):
		return _result(false, &"convoy_session_payload_corrupt")
	var session_state := progress.convoy_session_state as Dictionary
	var session_validation := validate_session_state(session_state, host)
	if not bool(session_validation.get("accepted", false)):
		return _result(false, &"convoy_session_payload_corrupt", {
			"payload_reason": session_validation.get("reason", &"invalid_convoy_session"),
		})
	var host_state := session_state.host_state as Dictionary
	var activity_state := host_state.activity_state as Dictionary
	if int(progress.generation) != int(activity_state.get("generation", -1)):
		return _result(false, &"convoy_session_payload_corrupt")
	return _result(true, &"convoy_session_payload_valid")


func validate_session_state(
		candidate: Variant,
		host: CinderConvoyEscortHost
	) -> Dictionary:
	if not candidate is Dictionary or not is_instance_valid(host):
		return _result(false, &"malformed_convoy_session_state")
	var state := candidate as Dictionary
	if state.size() != 7 \
			or not _integral(state.get("schema_version")) \
			or int(state.get("schema_version", 0)) != SESSION_SCHEMA_VERSION \
			or str(state.get("activity_kind", "")) != ACTIVITY_KIND \
			or str(state.get("activity_id", "")) \
			!= str(CinderConvoyEscortHost.ROUTE.activity_id) \
			or str(state.get("phase_id", "")) != PHASE_ID \
			or not state.get("escort_ship_id") is String \
			or not _stable_ship_id(str(state.escort_ship_id)) \
			or str(state.get("stream_location_id", "")) != STREAM_LOCATION_ID \
			or not state.get("host_state") is Dictionary:
		return _result(false, &"malformed_convoy_session_state")
	var host_validation := host.validate_persistence_state(state.host_state)
	if not bool(host_validation.get("accepted", false)):
		return host_validation
	return _result(true, &"convoy_session_state_valid")


func get_store_generation() -> int:
	return _store.get_generation() if _configured() else -1


func _capture_session_state(
		host: CinderConvoyEscortHost,
		escort_ship_id: StringName
	) -> Dictionary:
	return {
		"schema_version": SESSION_SCHEMA_VERSION,
		"activity_kind": ACTIVITY_KIND,
		"activity_id": String(CinderConvoyEscortHost.ROUTE.activity_id),
		"phase_id": PHASE_ID,
		"escort_ship_id": String(escort_ship_id),
		"stream_location_id": STREAM_LOCATION_ID,
		"host_state": host.capture_persistence_state(),
	}.duplicate(true)


func _record(state: Dictionary) -> Dictionary:
	var host_state := state.get("host_state", {}) as Dictionary
	var activity_state := host_state.get("activity_state", {}) as Dictionary
	var record := _codec.capture({
		"host": {
			"activity": {
				"activity_id": str(state.get("activity_id", "")),
				"generation": int(activity_state.get("generation", 0)),
				"state": int(activity_state.get("state", ConvoyEscortActivity.State.IDLE)),
				"convoy_session_state": state.duplicate(true),
			},
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
		"session_state": (
			progress.get("convoy_session_state", {}) as Dictionary
		).duplicate(true),
	}.duplicate(true)


func _validate_transition(existing: Dictionary, candidate: Dictionary) -> Dictionary:
	if existing == candidate:
		return _result(true, &"convoy_session_unchanged")
	if str(existing.get("escort_ship_id", "")) != str(candidate.get("escort_ship_id", "")):
		return _result(false, &"convoy_session_ship_identity_changed")
	var old_host := existing.host_state as Dictionary
	var new_host := candidate.host_state as Dictionary
	var old_activity := old_host.activity_state as Dictionary
	var new_activity := new_host.activity_state as Dictionary
	var old_generation := int(old_activity.get("generation", -1))
	var new_generation := int(new_activity.get("generation", -1))
	if new_generation < old_generation:
		return _result(false, &"stale_convoy_session")
	if new_generation != old_generation:
		return _result(false, &"unproven_convoy_generation")
	if int(new_host.get("entity_generation", -1)) \
			!= int(old_host.get("entity_generation", -2)) \
			or int(new_host.get("next_route_index", -1)) \
			< int(old_host.get("next_route_index", 0)) \
			or float(new_host.get("movement_distance", -1.0)) \
			< float(old_host.get("movement_distance", 0.0)) \
			or int(new_host.get("physics_tick_count", -1)) \
			< int(old_host.get("physics_tick_count", 0)) \
			or int(new_host.get("sample_publication_count", -1)) \
			< int(old_host.get("sample_publication_count", 0)) \
			or float(new_activity.get("elapsed_seconds", -1.0)) \
			< float(old_activity.get("elapsed_seconds", 0.0)):
		return _result(false, &"stale_convoy_session")
	var old_separation := float(old_activity.get("separation_elapsed_seconds", 0.0))
	var new_separation := float(new_activity.get("separation_elapsed_seconds", 0.0))
	if new_separation < old_separation:
		if not is_zero_approx(new_separation) \
				or float(new_activity.get("escort_distance", INF)) \
				> float(new_activity.get("configured_escort_proximity_radius", -1.0)):
			return _result(false, &"stale_convoy_separation")
	return _result(true, &"convoy_session_advanced")


func _canonical_state(state: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(JSON.stringify(state))
	return (decoded as Dictionary).duplicate(true) if decoded is Dictionary else {}


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _stable_ship_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128 or value != value.strip_edges():
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	result.merge(details.duplicate(true), true)
	return result
