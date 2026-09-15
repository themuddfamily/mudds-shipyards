class_name NetworkMovementAuthority
extends RefCounted

## Server-side validation and delivery boundary for on-foot movement/boarding.
##
## This contract does not move a CharacterBody3D and does not reserve a seat.
## It verifies peer/entity ownership, lifecycle generations, stream ordering,
## tick windows, and on-foot versus seated action rules, then releases at most
## one detached intent per authoritative physics tick to the production
## movement and boarding owners.

const Intent := preload("res://scripts/network/network_movement_intent.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_movement_authority_v1"
const DEFAULT_MAX_TICK_BEHIND := 6
const DEFAULT_MAX_TICK_AHEAD := 2
const MAX_PENDING_PER_ENTITY := 8

## Avatar modes. `seated` is the mode a server-owned body is put into the
## moment it claims a seat or a bunk, and `on_foot` again when it stands: while
## seated, a walking or boarding intent is refused *here*, by name and counted,
## rather than reaching a body that would have to ignore it. `pilot` is the
## remote ship command seam's mode and, for on-foot actions, is treated as on
## foot.
const MODE_ON_FOOT: StringName = &"on_foot"
const MODE_SEATED: StringName = &"seated"
const MODE_PILOT: StringName = &"pilot"
const MODES := [MODE_ON_FOOT, MODE_SEATED, MODE_PILOT]

## The named reasons an intent is refused for its avatar's mode.
const REFUSAL_MOVEMENT_WHILE_SEATED: StringName = &"movement_while_seated"
const REFUSAL_BOARD_WHILE_SEATED: StringName = &"board_while_seated"
const REFUSAL_DISEMBARK_WHILE_ON_FOOT: StringName = &"disembark_while_on_foot"

var _authority_peer_id := 1
var _max_tick_behind := DEFAULT_MAX_TICK_BEHIND
var _max_tick_ahead := DEFAULT_MAX_TICK_AHEAD
var _server_tick := 0
var _event_sequence := 0
var _avatars: Dictionary = {}
var _last_result: Dictionary = {}
## Every refused intent by status, and every mode refusal by its named reason,
## so a client that keeps walking while its body is seated shows up in the
## audit as a count rather than as silence.
var _intent_refusals: Dictionary = {}
var _mode_refusals: Dictionary = {}
var _mode_changes := 0


func _init(
	p_authority_peer_id: int = 1,
	p_max_tick_behind: int = DEFAULT_MAX_TICK_BEHIND,
	p_max_tick_ahead: int = DEFAULT_MAX_TICK_AHEAD
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_tick_behind = maxi(0, p_max_tick_behind)
	_max_tick_ahead = maxi(0, p_max_tick_ahead)
	_last_result = _result(false, &"uninitialized")


## Widens or narrows the client-tick acceptance window. A remote body's owner
## stamps its intents with the newest server tick it has *observed* on the
## relationship stream plus the local ticks since, so under a 350 ms profile a
## perfectly honest stamp trails the authority by twenty-odd ticks. The window
## is still a bound: a stamp older than `behind` or newer than `ahead` is
## rejected, and ordering within a stream is enforced separately.
func configure_tick_window(source_peer_id: int, max_tick_behind: int, max_tick_ahead: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if max_tick_behind < 0 or max_tick_ahead < 0 \
			or max_tick_behind > 600 or max_tick_ahead > 60:
		return _remember(_result(false, &"invalid_tick_window"))
	_max_tick_behind = max_tick_behind
	_max_tick_ahead = max_tick_ahead
	return _remember(_result(true, &"tick_window_configured", {
		"max_tick_behind": _max_tick_behind, "max_tick_ahead": _max_tick_ahead,
	}))


## Retires every avatar one peer owns. A departed peer's body goes with it, so
## its pending intents and stream cursor must not survive to drive a body
## registered later under the same entity id.
func release_peer(source_peer_id: int, peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var released: Array = []
	for entity_variant in _avatars.keys():
		var avatar := _avatars[entity_variant] as Dictionary
		if int(avatar.owner_peer_id) != peer_id:
			continue
		released.append({
			"entity_id": StringName(entity_variant),
			"entity_generation": int(avatar.entity_generation),
		})
		_avatars.erase(entity_variant)
	if not released.is_empty():
		_event_sequence += 1
	return _remember(_result(true, &"peer_released", {"released": released}))


func get_avatar_ids() -> Array:
	return _avatars.keys()


## Registration is a server lifecycle operation. `mode` is supplied by the
## existing seat/Player authority; this ledger never creates a seat itself.
func register_avatar(
	source_peer_id: int,
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	mode: StringName = &"on_foot"
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if owner_peer_id <= 0 or not _valid_entity_id(entity_id) or entity_generation <= 0:
		return _remember(_result(false, &"invalid_avatar_identity"))
	if not MODES.has(mode):
		return _remember(_result(false, &"invalid_avatar_mode"))
	if _avatars.has(entity_id):
		return _remember(_result(false, &"duplicate_avatar"))
	_avatars[entity_id] = {
		"owner_peer_id": owner_peer_id,
		"entity_generation": entity_generation,
		"mode": mode,
		"stream_id": -1,
		"last_sequence": -1,
		"last_client_tick": -1,
		"last_consumed_server_tick": -1,
		"last_accepted_server_tick": -1,
		"pending": [],
	}
	_event_sequence += 1
	return _remember(_result(true, &"registered", {"entity_id": entity_id}))


func retire_avatar(source_peer_id: int, entity_id: StringName, entity_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _avatars.has(entity_id):
		return _remember(_result(false, &"unknown_avatar"))
	var avatar := _avatars[entity_id] as Dictionary
	if int(avatar.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_avatar_generation"))
	_avatars.erase(entity_id)
	_event_sequence += 1
	return _remember(_result(true, &"retired"))


func set_server_tick(source_peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	_server_tick = server_tick
	return _remember(_result(true, &"server_tick_advanced", {"server_tick": _server_tick}))


## Changes the movement mode only after the real Player/seat authority commits
## a physical boarding or disembark result.
func set_avatar_mode(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	mode: StringName
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _avatars.has(entity_id):
		return _remember(_result(false, &"unknown_avatar"))
	var avatar := _avatars[entity_id] as Dictionary
	if int(avatar.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_avatar_generation"))
	if not MODES.has(mode):
		return _remember(_result(false, &"invalid_avatar_mode"))
	var previous := StringName(avatar.mode)
	avatar.mode = mode
	if previous != mode:
		_mode_changes += 1
		_event_sequence += 1
	return _remember(_result(true, &"mode_updated", {
		"mode": mode, "previous_mode": previous, "entity_id": entity_id,
	}))


## `source_peer_id` is the transport sender. It must match the peer ID in the
## packet, while the server remains the only component that commits delivery.
func accept_intent(source_peer_id: int, wire: Dictionary) -> Dictionary:
	var intent = Intent.from_dictionary(wire)
	if not intent.is_valid():
		return _refuse(&"invalid_intent", {"errors": intent.get_validation_errors()})
	if source_peer_id != intent.get_peer_id():
		return _refuse(&"spoofed_peer")
	if not _avatars.has(intent.get_entity_id()):
		return _refuse(&"unknown_avatar")
	var avatar := _avatars[intent.get_entity_id()] as Dictionary
	if int(avatar.owner_peer_id) != source_peer_id:
		return _refuse(&"not_avatar_owner")
	if int(avatar.entity_generation) != intent.get_entity_generation():
		return _refuse(&"stale_avatar_generation")
	if intent.get_client_tick() < _server_tick - _max_tick_behind:
		return _refuse(&"client_tick_too_old")
	if intent.get_client_tick() > _server_tick + _max_tick_ahead:
		return _refuse(&"client_tick_too_far_ahead")
	var stream_id: int = intent.get_stream_id()
	var last_stream := int(avatar.stream_id)
	if stream_id < last_stream:
		return _refuse(&"stale_stream")
	if stream_id == last_stream:
		if intent.get_sequence() <= int(avatar.last_sequence):
			return _refuse(&"stale_sequence")
		if intent.get_client_tick() <= int(avatar.last_client_tick):
			return _refuse(&"stale_client_tick")
	else:
		# A new stream is a source lifecycle boundary; sequence zero is valid.
		if intent.get_sequence() != 0:
			return _refuse(&"new_stream_must_start_at_zero")
	var mode_refusal := _mode_refusal(avatar, intent)
	if mode_refusal != &"":
		_mode_refusals[mode_refusal] = int(_mode_refusals.get(mode_refusal, 0)) + 1
		return _refuse(&"action_not_allowed_in_mode", {
			"mode": StringName(avatar.mode),
			"reason": mode_refusal,
			"entity_id": intent.get_entity_id(),
		})
	var pending := avatar.pending as Array
	if pending.size() >= MAX_PENDING_PER_ENTITY:
		return _refuse(&"intent_queue_full")
	pending.append(intent.to_dictionary())
	avatar.stream_id = stream_id
	avatar.last_sequence = intent.get_sequence()
	avatar.last_client_tick = intent.get_client_tick()
	avatar.last_accepted_server_tick = _server_tick
	_event_sequence += 1
	return _remember(_result(true, &"accepted", {
		"entity_id": intent.get_entity_id(),
		"sequence": intent.get_sequence(),
		"event_sequence": _event_sequence,
	}))


## Delivers at most one accepted intent per entity and server physics tick.
func consume_for_tick(
	entity_id: StringName,
	entity_generation: int,
	server_tick: int
) -> Dictionary:
	if not _avatars.has(entity_id):
		return _result(false, &"unknown_avatar")
	var avatar := _avatars[entity_id] as Dictionary
	if int(avatar.entity_generation) != entity_generation:
		return _result(false, &"stale_avatar_generation")
	if server_tick < int(avatar.last_consumed_server_tick):
		return _result(false, &"stale_consume_tick")
	if server_tick == int(avatar.last_consumed_server_tick):
		return _result(false, &"already_consumed_tick")
	avatar.last_consumed_server_tick = server_tick
	var pending := avatar.pending as Array
	if pending.is_empty():
		return _result(false, &"no_intent", {"server_tick": server_tick})
	var first := pending[0] as Dictionary
	var intent = Intent.from_dictionary(first)
	if intent.get_client_tick() > server_tick:
		return _result(false, &"intent_not_due", {"server_tick": server_tick})
	pending.pop_front()
	return _result(true, &"delivered", {
		"server_tick": server_tick,
		"intent": intent.to_dictionary(),
	})


func get_avatar_snapshot(entity_id: StringName) -> Dictionary:
	if not _avatars.has(entity_id):
		return {}
	var avatar := _avatars[entity_id] as Dictionary
	return {
		"entity_id": entity_id,
		"owner_peer_id": avatar.owner_peer_id,
		"entity_generation": avatar.entity_generation,
		"mode": avatar.mode,
		"stream_id": avatar.stream_id,
		"last_sequence": avatar.last_sequence,
		"last_client_tick": avatar.last_client_tick,
		"last_accepted_server_tick": int(avatar.get("last_accepted_server_tick", -1)),
		"last_consumed_server_tick": int(avatar.get("last_consumed_server_tick", -1)),
		"pending_count": (avatar.pending as Array).size(),
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_intent_validation": true,
		"server_owns_delivery_order": true,
		"server_owns_movement_truth": false,
		"server_owns_boarding_physics": false,
		"server_owns_seat_reservation": false,
		"client_can_mutate_state": false,
		"registered_avatar_count": _avatars.size(),
		"seated_avatar_count": _count_avatars_in_mode(MODE_SEATED),
		"mode_changes": _mode_changes,
		"intent_refusals": _intent_refusals.duplicate(true),
		"mode_refusals": _mode_refusals.duplicate(true),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


## The named reason an intent is refused for its avatar's current mode, or an
## empty name when the mode allows it. A seated avatar may look around, ask to
## interact and ask to disembark; it may not walk and may not board again. An
## avatar on foot may not disembark from a seat it is not in.
func _mode_refusal(avatar: Dictionary, intent) -> StringName:
	var seated := StringName(avatar.mode) == MODE_SEATED
	if seated and not intent.is_neutral_movement():
		return REFUSAL_MOVEMENT_WHILE_SEATED
	if seated and intent.has_board_request():
		return REFUSAL_BOARD_WHILE_SEATED
	if not seated and intent.has_disembark_request():
		return REFUSAL_DISEMBARK_WHILE_ON_FOOT
	return &""


func _count_avatars_in_mode(mode: StringName) -> int:
	var count := 0
	for avatar_variant in _avatars.values():
		if StringName((avatar_variant as Dictionary).mode) == mode:
			count += 1
	return count


func _refuse(status: StringName, payload: Dictionary = {}) -> Dictionary:
	_intent_refusals[status] = int(_intent_refusals.get(status, 0)) + 1
	return _remember(_result(false, status, payload))


func _valid_entity_id(entity_id: StringName) -> bool:
	var text := str(entity_id)
	if text.is_empty() or text.length() > 64:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"accepted": accepted,
		"status": status,
		"event_sequence": _event_sequence,
	}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
