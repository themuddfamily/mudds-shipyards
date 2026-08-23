class_name NetworkSnapshotLifecycleAdapter
extends RefCounted

## Concrete session seam for the authoritative snapshot synchronizer.
##
## `NetworkDisconnectLifecycle` remains the owner of admission, peer
## generations, seat claims, ship ownership, and disconnect cleanup. This
## adapter feeds those committed session records into
## `NetworkAuthoritativeSnapshot` beside caller-supplied movement, projectile,
## damage/respawn, and landing records. It owns no RPC, node, physics, health,
## or berth state.

const Lifecycle := preload("res://scripts/network/network_disconnect_lifecycle.gd")
const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_snapshot_lifecycle_adapter_v1"

var _authority_peer_id := 1
var _lifecycle
var _snapshot
var _last_snapshot_event_sequence := -1
var _snapshot_needs_publish := true
var _ownership_record_revision := 0
var _boarding_record_revision := 0
var _ownership_record_cache: Dictionary = {}
var _boarding_record_cache: Dictionary = {}
var _ownership_transition_states: Dictionary = {}
var _boarding_transition_states: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_protocol_version: int = 1,
	p_package_generation: int = 1,
	p_session_generation: int = 1,
	p_max_updates_per_tick: int = 16
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_lifecycle = Lifecycle.new(
		_authority_peer_id,
		p_protocol_version,
		p_package_generation,
		p_session_generation,
		p_max_updates_per_tick
	)
	_snapshot = Snapshot.new(_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


static func create_hello(
	p_peer_id: int,
	p_peer_generation: int,
	p_protocol_version: int,
	p_package_generation: int,
	p_session_generation: int,
	p_schema_version: int = 1
) -> Dictionary:
	return Lifecycle.create_hello(
		p_peer_id,
		p_peer_generation,
		p_protocol_version,
		p_package_generation,
		p_session_generation,
		p_schema_version
	)


func admit_peer(source_peer_id: int, wire: Dictionary) -> Dictionary:
	return _remember(_lifecycle.admit_peer(source_peer_id, wire))


func register_ship(
	source_peer_id: int,
	ship_id: StringName,
	ship_generation: int,
	owner_peer_id: int = 0
) -> Dictionary:
	return _remember(_lifecycle.register_ship(
		source_peer_id, ship_id, ship_generation, owner_peer_id
	))


func register_seat(
	source_peer_id: int,
	seat_id: StringName,
	vessel_id: StringName,
	role: StringName,
	frame_id: StringName = &"",
	seat_generation: int = 1
) -> Dictionary:
	return _remember(_lifecycle.register_seat(
		source_peer_id, seat_id, vessel_id, role, frame_id, seat_generation
	))


func claim_ship(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	ship_id: StringName,
	ship_generation: int,
	request_sequence: int
) -> Dictionary:
	return _remember(_lifecycle.claim_ship(
		source_peer_id,
		peer_id,
		peer_generation,
		ship_id,
		ship_generation,
		request_sequence
	))


func claim_seat(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	avatar_id: StringName,
	seat_id: StringName,
	role: StringName,
	request_sequence: int
) -> Dictionary:
	return _remember(_lifecycle.claim_seat(
		source_peer_id,
		peer_id,
		peer_generation,
		avatar_id,
		seat_id,
		role,
		request_sequence
	))


## Publishes session-owned ship/seat records together with movement,
## projectile, respawn, and landing records from the other server authorities.
func publish_authority_snapshot(
	source_peer_id: int,
	server_tick: int,
	movement: Array,
	projectiles: Array,
	respawn: Array,
	landing: Array = [],
	ownership_override: Variant = null,
	boarding_override: Variant = null
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var lifecycle_snapshot: Dictionary = _lifecycle.get_snapshot()
	var lifecycle_event_sequence := int(lifecycle_snapshot.get("event_sequence", 0))
	var next_event_sequence := maxi(
		lifecycle_event_sequence,
		_last_snapshot_event_sequence + 1
	)
	var ownership_cache_before := _ownership_record_cache.duplicate(true)
	var boarding_cache_before := _boarding_record_cache.duplicate(true)
	var ownership_revision_before := _ownership_record_revision
	var boarding_revision_before := _boarding_record_revision
	var ownership: Array = ownership_override as Array if ownership_override is Array \
		else _ownership_records(lifecycle_snapshot, server_tick)
	var boarding: Array = boarding_override as Array if boarding_override is Array \
		else _boarding_records(lifecycle_snapshot, server_tick)
	var published: Dictionary = _snapshot.publish(
		_authority_peer_id,
		server_tick,
		next_event_sequence,
		movement,
		ownership,
		projectiles,
		boarding,
		respawn,
		landing
	)
	if bool(published.get("accepted", false)):
		_last_snapshot_event_sequence = next_event_sequence
		_snapshot_needs_publish = false
		published["lifecycle_event_sequence"] = lifecycle_event_sequence
		published["session_generation"] = _session_generation(lifecycle_snapshot)
	else:
		_ownership_record_cache = ownership_cache_before
		_boarding_record_cache = boarding_cache_before
		_ownership_record_revision = ownership_revision_before
		_boarding_record_revision = boarding_revision_before
	return _remember(published)


## Replica adapters use the synchronizer's authenticated server boundary. The
## lifecycle remains available to the real transport adapter for peer admission
## and disconnect; this method only applies the detached gameplay packet.
func apply_replica_snapshot(source_peer_id: int, packet: Dictionary) -> Dictionary:
	var applied: Dictionary = _snapshot.apply_replica(source_peer_id, packet)
	return _remember(applied)


func disconnect_peer(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int
) -> Dictionary:
	var before: Dictionary = _lifecycle.get_snapshot()
	var disconnected_ship_ids: Array = []
	for ship_variant in ((before.get("ships", {}) as Dictionary).get("ships", []) as Array):
		var ship := ship_variant as Dictionary
		if int(ship.get("owner_peer_id", 0)) == peer_id:
			disconnected_ship_ids.append(StringName(ship.get("ship_id", &"")))
	var disconnected_seat_ids: Array = []
	for assignment_variant in ((before.get("seats", {}) as Dictionary).get("assignments", []) as Array):
		var assignment := assignment_variant as Dictionary
		if int(assignment.get("occupant_peer_id", 0)) == peer_id:
			disconnected_seat_ids.append(StringName(assignment.get("seat_id", &"")))
	var disconnected: Dictionary = _lifecycle.disconnect_peer(
		source_peer_id, peer_id, peer_generation
	)
	if bool(disconnected.get("accepted", false)):
		for ship_id_variant in disconnected_ship_ids:
			_ownership_transition_states[StringName(ship_id_variant)] = &"disconnected"
		for seat_id_variant in disconnected_seat_ids:
			_boarding_transition_states[StringName(seat_id_variant)] = &"disconnected"
		_snapshot_needs_publish = true
		disconnected["snapshot_requires_publish"] = true
	return _remember(disconnected)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"lifecycle": _lifecycle.get_snapshot(),
		"authoritative": _snapshot.get_snapshot(),
		"snapshot_needs_publish": _snapshot_needs_publish,
	}.duplicate(true)


func get_authoritative_snapshot() -> Dictionary:
	return _snapshot.get_snapshot()


func get_peer(peer_id: int) -> Dictionary:
	return _lifecycle.get_peer(peer_id)


func audit() -> Dictionary:
	var lifecycle_audit: Dictionary = _lifecycle.audit()
	var snapshot_audit: Dictionary = _snapshot.audit()
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"session_coordinator_policy": lifecycle_audit.get("policy_version", &""),
		"snapshot_policy": snapshot_audit.get("policy_version", &""),
		"server_owns_peer_lifecycle": true,
		"server_owns_snapshot_publication": true,
		"disconnect_requires_snapshot_refresh": true,
		"client_can_publish_snapshot": false,
		"snapshot_needs_publish": _snapshot_needs_publish,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _ownership_records(lifecycle_snapshot: Dictionary, server_tick: int) -> Array:
	var ships_state: Dictionary = lifecycle_snapshot.get("ships", {}) as Dictionary
	var records: Array = []
	for ship_variant in ships_state.get("ships", []) as Array:
		var ship := (ship_variant as Dictionary).duplicate(true)
		var ship_id := StringName(ship.get("ship_id", &""))
		var owner_peer_id := int(ship.get("owner_peer_id", 0))
		ship["owner_peer_generation"] = _peer_generation(lifecycle_snapshot, owner_peer_id)
		ship["state"] = _ownership_transition_states.get(
			ship_id, &"owned" if owner_peer_id > 0 else &"released"
		)
		var cached := _ownership_record_cache.get(ship_id, {}) as Dictionary
		if cached.is_empty() or not _same_without_snapshot_meta(
			ship, cached, [&"ownership_revision", &"ownership_server_tick"]
		):
			_ownership_record_revision += 1
			ship["ownership_revision"] = _ownership_record_revision
			ship["ownership_server_tick"] = server_tick
			_ownership_record_cache[ship_id] = ship.duplicate(true)
		else:
			ship = cached.duplicate(true)
		records.append(ship)
	return records


func _boarding_records(lifecycle_snapshot: Dictionary, server_tick: int) -> Array:
	var seats_state: Dictionary = lifecycle_snapshot.get("seats", {}) as Dictionary
	var assignments_by_seat: Dictionary = {}
	for assignment_variant in seats_state.get("assignments", []) as Array:
		var assignment := assignment_variant as Dictionary
		assignments_by_seat[StringName(assignment.get("seat_id", &""))] = assignment
	var ship_generations: Dictionary = {}
	for ship_variant in ((lifecycle_snapshot.get("ships", {}) as Dictionary).get("ships", []) as Array):
		var ship := ship_variant as Dictionary
		ship_generations[StringName(ship.get("ship_id", &""))] = int(ship.get("ship_generation", 0))
	var records: Array = []
	for seat_variant in seats_state.get("seats", []) as Array:
		var seat := seat_variant as Dictionary
		var seat_id := StringName(seat.get("seat_id", &""))
		var assignment := assignments_by_seat.get(seat_id, {}) as Dictionary
		var occupant_peer_id := int(assignment.get("occupant_peer_id", 0))
		var record := {
			"seat_id": seat_id,
			"seat_generation": int(seat.get("seat_generation", 0)),
			"occupant_peer_id": occupant_peer_id,
			"occupant_peer_generation": _peer_generation(lifecycle_snapshot, occupant_peer_id),
			"avatar_id": StringName(assignment.get("avatar_id", &"")),
			"vessel_id": StringName(seat.get("vessel_id", &"")),
			"ship_generation": int(ship_generations.get(seat.get("vessel_id", &""), 0)),
			"role": StringName(seat.get("role", &"")),
			"state": _boarding_transition_states.get(
				seat_id, &"boarded" if occupant_peer_id > 0 else &"released"
			),
		}
		var cached := _boarding_record_cache.get(seat_id, {}) as Dictionary
		if cached.is_empty() or not _same_without_snapshot_meta(
			record, cached, [&"boarding_revision", &"boarding_server_tick"]
		):
			_boarding_record_revision += 1
			record["boarding_revision"] = _boarding_record_revision
			record["boarding_server_tick"] = server_tick
			_boarding_record_cache[seat_id] = record.duplicate(true)
		else:
			record = cached.duplicate(true)
		records.append(record)
	return records


func _peer_generation(lifecycle_snapshot: Dictionary, peer_id: int) -> int:
	if peer_id <= 0:
		return 0
	for peer_variant in lifecycle_snapshot.get("peers", []) as Array:
		var peer := peer_variant as Dictionary
		if int(peer.get("peer_id", 0)) == peer_id:
			return int(peer.get("peer_generation", 0))
	return 0


func _same_without_snapshot_meta(
	left: Dictionary, right: Dictionary, metadata_fields: Array
) -> bool:
	var clean_left := left.duplicate(true)
	var clean_right := right.duplicate(true)
	for field_variant in metadata_fields:
		clean_left.erase(field_variant)
		clean_right.erase(field_variant)
	return clean_left == clean_right


func _session_generation(lifecycle_snapshot: Dictionary) -> int:
	var session: Dictionary = lifecycle_snapshot.get("session", {}) as Dictionary
	return int(session.get("session_generation", 0))


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"accepted": accepted,
		"status": status,
		"authority_peer_id": _authority_peer_id,
	}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
