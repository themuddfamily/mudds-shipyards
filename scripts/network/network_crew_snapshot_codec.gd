class_name NetworkCrewSnapshotCodec
extends RefCounted

## Deterministic detached wire codec for multicrew role and command state.
## JSON is used only as a bounded value encoding; no Nodes or object references
## are accepted or emitted.

const SCHEMA_VERSION := 1
const MAX_ENTRIES := 64
const MAX_BYTES := 4096
const MAX_ID_LENGTH := 64
const ROLE_FIELDS := ["peer_id", "peer_generation", "avatar_id", "seat_id", "seat_generation", "role", "ship_id", "ship_generation", "request_sequence", "migration_generation"]
const COMMAND_FIELDS := ["peer_id", "peer_generation", "avatar_id", "seat_id", "seat_generation", "role", "action", "ship_id", "ship_generation", "request_sequence", "server_tick", "migration_generation", "payload"]


func encode(role_snapshot: Dictionary, command_snapshot: Dictionary, receipts: Array = []) -> Dictionary:
	var roles := role_snapshot.get("roles", {}) as Dictionary
	if roles.size() > MAX_ENTRIES or receipts.size() > MAX_ENTRIES:
		return _result(false, &"entry_limit_exceeded")
	var normalized_roles: Array = []
	for key_variant in roles.keys():
		var record := roles[key_variant] as Dictionary
		var checked := _normalize_record(record, ROLE_FIELDS)
		if not bool(checked.get("accepted", false)):
			return checked
		normalized_roles.append(checked.record)
	normalized_roles.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _stream_key(left) < _stream_key(right)
	)
	var normalized_receipts: Array = []
	for receipt_variant in receipts:
		var receipt := receipt_variant.get("receipt", receipt_variant) as Dictionary if receipt_variant is Dictionary else {}
		var checked := _normalize_record(receipt, COMMAND_FIELDS)
		if not bool(checked.get("accepted", false)):
			return checked
		normalized_receipts.append(checked.record)
	normalized_receipts.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _stream_key(left) < _stream_key(right)
	)
	var document := {
		"schema_version": SCHEMA_VERSION,
		"migration_generation": int(role_snapshot.get("migration_generation", command_snapshot.get("migration_generation", 0))),
		"role_event_sequence": int(role_snapshot.get("event_sequence", 0)),
		"command_event_sequence": int(command_snapshot.get("event_sequence", 0)),
		"roles": normalized_roles,
		"commands": normalized_receipts,
	}
	var encoded := JSON.stringify(document, "", false).to_utf8_buffer()
	if encoded.size() > MAX_BYTES:
		return _result(false, &"byte_limit_exceeded")
	return _result(true, &"encoded", {"bytes": encoded, "entry_count": normalized_roles.size() + normalized_receipts.size()})


func decode(encoded: PackedByteArray) -> Dictionary:
	if encoded.is_empty() or encoded.size() > MAX_BYTES:
		return _result(false, &"invalid_byte_budget")
	var parsed = JSON.parse_string(encoded.get_string_from_utf8())
	if not parsed is Dictionary:
		return _result(false, &"malformed_snapshot")
	var document := parsed as Dictionary
	var allowed := ["schema_version", "migration_generation", "role_event_sequence", "command_event_sequence", "roles", "commands"]
	for key in document.keys():
		if not allowed.has(str(key)):
			return _result(false, &"unknown_snapshot_field")
	if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
		return _result(false, &"unknown_schema_version")
	var roles := document.get("roles", []) as Array
	var commands := document.get("commands", []) as Array
	if roles.size() > MAX_ENTRIES or commands.size() > MAX_ENTRIES:
		return _result(false, &"entry_limit_exceeded")
	for record in roles:
		var checked := _normalize_record(record as Dictionary, ROLE_FIELDS)
		if not bool(checked.get("accepted", false)):
			return checked
	for record in commands:
		var checked := _normalize_record(record as Dictionary, COMMAND_FIELDS)
		if not bool(checked.get("accepted", false)):
			return checked
	return _result(true, &"decoded", {"snapshot": document.duplicate(true)})


func _normalize_record(record: Dictionary, fields: Array) -> Dictionary:
	if record == null or record.is_empty():
		return _result(false, &"malformed_record")
	for key in record.keys():
		if not fields.has(str(key)):
			return _result(false, &"unknown_record_field")
	for field in fields:
		if not record.has(field):
			return _result(false, &"missing_record_field")
	for field in ["avatar_id", "seat_id", "role", "ship_id"]:
		var value := str(record.get(field, ""))
		if value.is_empty() or value.length() > MAX_ID_LENGTH:
			return _result(false, &"invalid_record_identity")
	for field in ["peer_id", "peer_generation", "seat_generation", "ship_generation", "request_sequence", "migration_generation"]:
		if int(record.get(field, 0)) <= 0:
			return _result(false, &"invalid_record_generation")
	return _result(true, &"valid_record", {"record": record.duplicate(true)})


func _stream_key(record: Dictionary) -> String:
	return "%d:%s:%s" % [int(record.get("peer_id", 0)), str(record.get("avatar_id", "")), str(record.get("action", record.get("role", "")))]


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
