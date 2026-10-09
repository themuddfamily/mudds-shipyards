class_name NetworkRemoteBodyIntentSource
extends RefCounted

## Client-side producer of the on-foot intent stream for a server-owned body.
##
## The owner of a remote body does not publish where it is; it publishes what
## it *wants*, at a fixed cadence, and the server simulates the answer. This
## object owns that cadence and nothing else: it samples the local input it is
## handed, latches the edge-triggered requests (jump, interact) that fall
## between two sends so none is lost, frames every packet with the entity
## generation and one stream id, and stamps it with the client's best estimate
## of the authority's tick.
##
## ## The tick stamp
##
## `NetworkMovementAuthority` accepts a packet only inside a bounded window
## around its own tick, and rejects a stamp that does not advance within a
## stream. A client has no clock of the server's, but it does have the newest
## `server_tick` its session adapter released on the moving-interior
## relationship stream — which, now that the authority publishes a simulated
## body to its owner too, it receives for as long as it has a body aboard. The
## estimate is that tick plus the local physics ticks elapsed since it was
## observed, so it trails the authority by one-way latency and never runs
## ahead of it unless the server itself stalls. `client_tick` is then the
## larger of the estimate and the previous stamp plus one, so a stream stays
## strictly ordered through a delivery stall as well.
##
## ## Prediction bookkeeping
##
## The owning client keeps simulating its own `PlayerController` on the same
## input, which is its prediction. `record_local_pose()` remembers where that
## body was at each stamp, and `reconcile()` compares the server's published
## pose at a tick with the local pose at the same stamp: same physics, same
## input, same tick, so a divergence above the tolerance is a genuine
## disagreement and not latency. Deliberately no input replay — the caller
## snaps and moves on. That is the cheap, bounded prediction the moving-
## interior latency notes ask for; anything more is a rollback system.

const Intent := preload("res://scripts/network/network_movement_intent.gd")

## Sends per physics tick: one packet every four 60 Hz ticks is 15 Hz, well
## under the adapter's per-peer secure-packet ceiling with room for every other
## intent stream the same peer speaks.
const DEFAULT_CADENCE_TICKS := 4
const MAX_POSE_HISTORY := 128
const DEFAULT_CORRECTION_TOLERANCE_METRES := 0.5

var _entity_id: StringName = &""
var _entity_generation := 0
var _stream_id := 0
var _sequence := -1
var _cadence_ticks := DEFAULT_CADENCE_TICKS
var _ticks_since_send := 0
var _last_client_tick := -1
var _observed_server_tick := -1
var _ticks_since_observation := 0
var _jump_latched := false
var _interact_latched := false
var _interaction_request_id := 0
var _pose_history: Dictionary = {}
var _pose_order: Array = []
var _sent := 0
var _corrections := 0
var _worst_divergence := 0.0
var _opening_confirmed := false
var _opening_tick := -1
var _opening_peer := 0
var _opening_jump := false
var _opening_retries := 0
var _opening_retry_clock := -1
var _movement_clock_received := false


func _init(p_cadence_ticks: int = DEFAULT_CADENCE_TICKS) -> void:
	_cadence_ticks = clampi(p_cadence_ticks, 1, 60)


## Binds the stream to one body. `stream_id` is a source lifecycle boundary
## for the authority: a client that rebinds after a reconnect opens a new
## stream so its sequence may legitimately restart at zero.
func bind(entity_id: StringName, entity_generation: int, stream_id: int = -1) -> Dictionary:
	if String(entity_id).is_empty() or entity_generation <= 0:
		return _result(false, &"invalid_body_identity")
	_entity_id = entity_id
	_entity_generation = entity_generation
	_stream_id = stream_id if stream_id >= 0 else _stream_id + 1
	_sequence = -1
	_clear_opening()
	_ticks_since_send = _cadence_ticks
	_last_client_tick = -1
	_jump_latched = false
	_interact_latched = false
	_pose_history.clear()
	_pose_order.clear()
	return _result(true, &"bound", {
		"entity_id": _entity_id, "entity_generation": _entity_generation, "stream_id": _stream_id,
	})


func unbind() -> Dictionary:
	_clear_opening()
	_jump_latched = false
	_interact_latched = false
	_entity_id = &""
	_entity_generation = 0
	_pose_history.clear()
	_pose_order.clear()
	return _result(true, &"unbound")


func is_bound() -> bool:
	return not String(_entity_id).is_empty()


func get_entity_id() -> StringName:
	return _entity_id


func get_entity_generation() -> int:
	return _entity_generation


## Latches an edge-triggered request so it survives until the next send.
func request_jump() -> void:
	_jump_latched = true


func request_interaction() -> void:
	_interact_latched = true


## One local physics tick. Returns the wire dictionary to send when a send is
## due this tick, or an empty dictionary otherwise. `sample` carries
## `move_axis` (Vector2, the same convention as `Input.get_vector`), `look_yaw`
## and `look_pitch` (radians), and the held `run` / `crouch` booleans.
## `observed_server_tick` is the adapter's newest released relationship tick,
## or -1 while nothing has arrived yet.
func advance(peer_id: int, sample: Dictionary, observed_server_tick: int) -> Dictionary:
	if not is_bound() or peer_id <= 0:
		return {}
	if _opening_retry_clock >= 0:
		_observed_server_tick = maxi(_observed_server_tick, _opening_retry_clock)
		_ticks_since_observation = 0
	elif observed_server_tick >= 0 and observed_server_tick > _observed_server_tick:
		_observed_server_tick = observed_server_tick
		_ticks_since_observation = 0
	else:
		_ticks_since_observation += 1
	_ticks_since_send += 1
	if _ticks_since_send < _cadence_ticks:
		return {}
	_ticks_since_send = 0
	var estimate := estimated_server_tick()
	_opening_retry_clock = -1
	var client_tick := maxi(estimate, _last_client_tick + 1)
	_sequence += 1
	_last_client_tick = client_tick
	var interact := _interact_latched
	if interact:
		_interaction_request_id += 1
	var jump := _jump_latched
	_jump_latched = false
	_interact_latched = false
	_sent += 1
	if not _opening_confirmed:
		_opening_jump = _opening_jump or jump
		if _sequence == 0:
			_opening_tick = client_tick
			_opening_peer = peer_id
	var move_axis: Vector2 = sample.get("move_axis", Vector2.ZERO)
	if not move_axis.is_finite():
		move_axis = Vector2.ZERO
	var intent = Intent.create(
		peer_id, _entity_id, _entity_generation, _stream_id, _sequence, client_tick,
		move_axis.limit_length(1.0), false, &"", false,
		float(sample.get("look_yaw", 0.0)), float(sample.get("look_pitch", 0.0)),
		bool(sample.get("run", false)), bool(sample.get("crouch", false)),
		jump, _interaction_request_id
	)
	return intent.to_dictionary()


## Only the adapter's authenticated authority reply reaches this seam. A
## rejected opening has not committed a stream or its edge requests on the
## host. Restamp that exact stream at zero; never rewind an established one.
func accept_opening_result(peer_id: int, result: Dictionary) -> Dictionary:
	if not is_bound() or _opening_confirmed or _opening_tick < 0:
		return _result(false, &"ignored_opening_result")
	for field in ["recipient_peer_id", "entity_generation", "stream_id", "sequence", "client_tick", "server_tick"]:
		if not result.get(field) is int or int(result[field]) < 0 or int(result[field]) > 9007199254740991:
			return _result(false, &"invalid_opening_result")
	if not result.get("accepted") is bool or not (result.get("entity_id") is String or result.get("entity_id") is StringName) \
			or not (result.get("status") is String or result.get("status") is StringName):
		return _result(false, &"invalid_opening_result")
	if peer_id != _opening_peer or int(result.recipient_peer_id) != peer_id \
			or StringName(result.entity_id) != _entity_id or int(result.entity_generation) != _entity_generation \
			or int(result.stream_id) != _stream_id or int(result.sequence) != 0 \
			or int(result.client_tick) != _opening_tick:
		return _result(false, &"ignored_opening_result")
	if bool(result.accepted) and result.status == &"accepted":
		_anchor_movement_clock(int(result.server_tick))
		_opening_confirmed = true
		_opening_jump = false
		return _result(true, &"opening_confirmed")
	if bool(result.accepted) or result.status not in [&"client_tick_too_old", &"client_tick_too_far_ahead"]:
		return _result(false, &"ignored_opening_result")
	_sequence = -1
	# No host timestamp was accepted for this opening. Its clock may be
	# corrected backwards as well as forwards without replaying host work.
	_anchor_movement_clock(int(result.server_tick))
	_last_client_tick = _observed_server_tick - 1
	_opening_retry_clock = _observed_server_tick
	_ticks_since_send = _cadence_ticks
	_jump_latched = _jump_latched or _opening_jump
	_opening_jump = false
	_opening_tick = -1
	_pose_history.clear()
	_pose_order.clear()
	_opening_retries += 1
	return _result(true, &"opening_retry_queued")


func has_authoritative_movement_clock() -> bool:
	return _movement_clock_received


## Called only for an actual authoritative movement relationship. Boarding
## may seed an unknown opening, but it never establishes this clock's trust.
func observe_movement_clock(server_tick: int) -> void:
	if is_bound() and server_tick >= 0:
		_anchor_movement_clock(server_tick)


func _anchor_movement_clock(server_tick: int) -> void:
	# An exact first receipt replaces the provisional bootstrap clock. Once
	# trusted, movement observations and receipts share one monotonic domain.
	if not _movement_clock_received or server_tick > _observed_server_tick:
		_observed_server_tick = server_tick
		_ticks_since_observation = 0
	_movement_clock_received = true


func _clear_opening() -> void:
	_movement_clock_received = false
	_observed_server_tick = -1
	_ticks_since_observation = 0
	_opening_retry_clock = -1
	_opening_confirmed = false
	_opening_tick = -1
	_opening_peer = 0
	_opening_jump = false


## The client's estimate of the authority's current tick, or -1 before any
## relationship has been observed. See the class note.
func estimated_server_tick() -> int:
	if _observed_server_tick < 0:
		return maxi(0, _last_client_tick + 1)
	return _observed_server_tick + _ticks_since_observation


func get_last_client_tick() -> int:
	return _last_client_tick


func get_interaction_request_id() -> int:
	return _interaction_request_id


## Remembers where the locally predicted body was at one stamp, in the moving
## frame's own coordinates. Bounded ring: the oldest entry is dropped first.
func record_local_pose(client_tick: int, frame_local_transform: Transform3D) -> void:
	if client_tick < 0:
		return
	if not _pose_history.has(client_tick):
		_pose_order.append(client_tick)
	_pose_history[client_tick] = frame_local_transform
	while _pose_order.size() > MAX_POSE_HISTORY:
		var oldest: int = int(_pose_order.pop_front())
		_pose_history.erase(oldest)


## Compares the server's published frame-local pose at `server_tick` with the
## local pose recorded at the same stamp. `correct` is true when the caller
## should snap its predicted body to `server_transform`. With no local pose on
## record for that tick nothing can be compared and nothing is corrected.
func reconcile(
	server_tick: int,
	server_transform: Transform3D,
	tolerance_metres: float = DEFAULT_CORRECTION_TOLERANCE_METRES
) -> Dictionary:
	if not _pose_history.has(server_tick):
		return {"correct": false, "status": &"no_local_pose", "error_m": 0.0}
	var local: Transform3D = _pose_history[server_tick]
	var error := local.origin.distance_to(server_transform.origin)
	_worst_divergence = maxf(_worst_divergence, error)
	# Everything at or before this tick has been judged; a later arrival for an
	# older tick is stale by the stream's own ordering rule.
	var kept: Array = []
	for tick_variant in _pose_order:
		if int(tick_variant) <= server_tick:
			_pose_history.erase(tick_variant)
		else:
			kept.append(tick_variant)
	_pose_order = kept
	if error > tolerance_metres:
		_corrections += 1
		return {"correct": true, "status": &"corrected", "error_m": error}
	return {"correct": false, "status": &"within_tolerance", "error_m": error}


func get_audit() -> Dictionary:
	return {
		"bound": is_bound(),
		"entity_id": _entity_id,
		"entity_generation": _entity_generation,
		"stream_id": _stream_id,
		"sequence": _sequence,
		"cadence_ticks": _cadence_ticks,
		"sent": _sent,
		"opening_confirmed": _opening_confirmed,
		"movement_clock_received": _movement_clock_received,
		"opening_retries": _opening_retries,
		"last_client_tick": _last_client_tick,
		"observed_server_tick": _observed_server_tick,
		"estimated_server_tick": estimated_server_tick(),
		"interaction_request_id": _interaction_request_id,
		"pose_history": _pose_history.size(),
		"corrections": _corrections,
		"worst_divergence_m": _worst_divergence,
		"owns_movement_authority": false,
	}


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
