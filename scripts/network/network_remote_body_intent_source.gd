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
## pose at a tick with the local pose at the same stamp, interpolating between
## retained samples when the authority clock skips a local sampling stamp.
## This judges a historical disagreement without comparing a delayed server
## position directly with the current body. The correction is the error at that stamp,
## applied to the current pose so movement after the stamp survives. Newer
## history receives the same translation to avoid applying that error twice.
## This remains bounded prediction bookkeeping without input replay.

const Intent := preload("res://scripts/network/network_movement_intent.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

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
var _last_interaction_physics_frame := -1
var _interaction_request_id := 0
## A replacement stream retires every pre-bind edge, including an intent
## accepted but never consumed before its old body was released. Keep the
## lifetime counter so genuinely fresh presses still use absolute new ids.
var _interaction_bind_baseline := 0
var _pose_history: Dictionary = {}
var _pose_order: Array = []
var _pose_frame_instance_id := 0
var _last_pose_tick := -1
var _last_judged_tick := -1
var _last_observed_pose_tick := -1
var _pending_authoritative_pose: Dictionary = {}
var _sent := 0
var _corrections := 0
var _worst_divergence := 0.0
var _last_correction: Dictionary = {}
var _opening_confirmed := false
var _opening_tick := -1
var _opening_peer := 0
var _opening_jump := false
var _opening_retries := 0
var _opening_retry_clock := -1
var _movement_clock_received := false
var _sent_clock_stamps: Dictionary = {}
var _clock_refusal_sequence := -1
var _clock_refusal_server_tick := -1
var _clock_recoveries := 0


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
	_interaction_bind_baseline = _interaction_request_id
	_clear_opening()
	_ticks_since_send = _cadence_ticks
	_last_client_tick = -1
	_jump_latched = false
	_interact_latched = false
	_last_interaction_physics_frame = -1
	_pose_history.clear()
	_pose_order.clear()
	_pose_frame_instance_id = 0
	_last_pose_tick = -1
	_last_judged_tick = -1
	_last_observed_pose_tick = -1
	_pending_authoritative_pose.clear()
	_last_correction.clear()
	return _result(true, &"bound", {
		"entity_id": _entity_id, "entity_generation": _entity_generation, "stream_id": _stream_id,
	})


func unbind() -> Dictionary:
	_clear_opening()
	_jump_latched = false
	_interact_latched = false
	_last_interaction_physics_frame = -1
	_entity_id = &""
	_entity_generation = 0
	_pose_history.clear()
	_pose_order.clear()
	_pose_frame_instance_id = 0
	_last_pose_tick = -1
	_last_judged_tick = -1
	_last_observed_pose_tick = -1
	_pending_authoritative_pose.clear()
	_last_correction.clear()
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
	# GameFlow samples the edge before the Player emits its interaction signal.
	# A cadence send between those consumers must not turn one press into two
	# host toggles. Requests in a later physics frame remain independent edges.
	var physics_frame := Engine.get_physics_frames()
	if physics_frame == _last_interaction_physics_frame:
		return
	_last_interaction_physics_frame = physics_frame
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
	_sent_clock_stamps[_sequence] = client_tick
	_sent_clock_stamps.erase(_sequence - 32)
	var interact := _interact_latched
	if interact:
		_interaction_request_id += 1
	var wire_interaction_id: int = _interaction_request_id if _interaction_request_id > _interaction_bind_baseline else 0
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
		jump, wire_interaction_id
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
	_pose_frame_instance_id = 0
	_last_pose_tick = -1
	_last_judged_tick = -1
	_last_observed_pose_tick = -1
	_pending_authoritative_pose.clear()
	_last_correction.clear()
	_opening_retries += 1
	return _result(true, &"opening_retry_queued")


func has_authoritative_movement_clock() -> bool:
	return _movement_clock_received


## Only the adapter's authenticated current body-ledger refusal reaches here.
## Discard rejected speculative stamps, never commands or accepted host work.
func accept_clock_refusal(peer_id: int, result: Dictionary) -> Dictionary:
	if not is_bound() or not _opening_confirmed:
		return _result(false, &"ignored_clock_refusal")
	for field in ["recipient_peer_id", "entity_generation", "stream_id", "sequence", "client_tick", "server_tick", "accepted_sequence", "accepted_client_tick"]:
		if not result.get(field) is int or int(result[field]) < 0 or int(result[field]) > 9007199254740991:
			return _result(false, &"invalid_clock_refusal")
	var sequence := int(result.sequence)
	if not result.get("accepted") is bool or result.accepted or result.get("status") != &"client_tick_too_far_ahead" \
			or peer_id != _opening_peer or int(result.recipient_peer_id) != peer_id \
			or result.get("entity_id") != _entity_id or int(result.entity_generation) != _entity_generation \
			or int(result.stream_id) != _stream_id or sequence <= _clock_refusal_sequence \
			or not _sent_clock_stamps.has(sequence) or int(result.client_tick) != int(_sent_clock_stamps[sequence]) \
			or int(result.server_tick) < _clock_refusal_server_tick \
			or int(result.accepted_sequence) >= sequence or int(result.accepted_client_tick) >= int(result.client_tick):
		return _result(false, &"ignored_clock_refusal")
	_clock_refusal_sequence = sequence
	_clock_refusal_server_tick = int(result.server_tick)
	_anchor_movement_clock(int(result.server_tick))
	_ticks_since_observation = 0
	_last_client_tick = maxi(int(result.accepted_client_tick), _observed_server_tick - 1)
	for sent_sequence in _sent_clock_stamps.keys():
		if int(sent_sequence) <= sequence:
			_sent_clock_stamps.erase(sent_sequence)
	clear_pose_history()
	# A rejected speculative pose stamp is not an authority judgment. Let
	# repaired-clock samples enter immediately without reopening judged ticks.
	_last_pose_tick = _last_judged_tick
	_clock_recoveries += 1
	# The next normal cadence samples live input. Edge latches, interaction
	# highwater, stream identity and sequence ordering remain unchanged.
	return _result(true, &"clock_repaired")


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
	_sent_clock_stamps.clear()
	_clock_refusal_sequence = -1
	_clock_refusal_server_tick = -1
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


## The wire yaw remains relative to the authoritative Player's CameraYaw
## parent. A host-only seat/stand can turn that body's root while the local
## prediction keeps its old root. Express the unchanged local camera heading
## against the authenticated walking root, without rotating either actor.
## Both bases are in the SAME retained cabin frame, so hull motion/rebases
## cancel. CameraRig has no authored rotation in the production Player scene.
func map_body_look_yaw(local_body_in_frame: Basis, local_yaw: float,
		relationship: Dictionary, frame_id: StringName, frame_generation: int = 1) -> Dictionary:
	if not is_bound() or relationship.get("entity_id") != _entity_id \
			or int(relationship.get("entity_generation", 0)) != _entity_generation \
			or relationship.get("parent_frame_id") != frame_id \
			or int(relationship.get("parent_frame_generation", 0)) != frame_generation \
			or int(relationship.get("occupancy_state", -1)) != Relationship.STATE_WALKING \
			or int(relationship.get("server_tick", -1)) < maxi(0, _last_observed_pose_tick):
		return _result(false, &"walking_relationship_not_current")
	var transform_variant: Variant = relationship.get("frame_local_transform")
	if not transform_variant is Transform3D or not local_body_in_frame.is_finite() \
			or not is_finite(local_yaw) or is_zero_approx(local_body_in_frame.determinant()):
		return _result(false, &"walking_basis_unavailable")
	var authoritative: Transform3D = transform_variant
	if not authoritative.basis.is_finite() or is_zero_approx(authoritative.basis.determinant()):
		return _result(false, &"walking_basis_unavailable")
	var predicted_heading := -(local_body_in_frame.orthonormalized() * Basis(Vector3.UP, local_yaw)).z
	var body_heading := authoritative.basis.orthonormalized().inverse() * predicted_heading
	if Vector2(body_heading.x, body_heading.z).is_zero_approx():
		return _result(false, &"walking_basis_unavailable")
	return _result(true, &"body_local_yaw", {"look_yaw": atan2(-body_heading.x, -body_heading.z)})


## Retires samples across a physical boarding/seat/frame boundary while keeping
## the stream's tick fences. Opening/rebinding resets those fences separately.
func clear_pose_history() -> void:
	_pose_history.clear()
	_pose_order.clear()
	_pose_frame_instance_id = 0
	_pending_authoritative_pose.clear()


## Remembers the measured predicted pose at one physics clock stamp, in the
## frame's own coordinates. Bounded ring: the oldest entry is dropped first.
func record_local_pose(client_tick: int, frame_local_transform: Transform3D, frame_instance_id: int = 0) -> void:
	if frame_instance_id != _pose_frame_instance_id:
		clear_pose_history()
		_pose_frame_instance_id = frame_instance_id
	if client_tick < 0 or client_tick <= _last_pose_tick:
		return
	_last_pose_tick = client_tick
	_pose_order.append(client_tick)
	_pose_history[client_tick] = frame_local_transform
	while _pose_order.size() > MAX_POSE_HISTORY:
		var oldest: int = int(_pose_order.pop_front())
		_pose_history.erase(oldest)


## Compares the server's published frame-local pose at `server_tick` with the
## local pose recorded at the same stamp. `correct` is true when the caller
## should translate its CURRENT predicted body by `correction_delta`, in frame
## coordinates. The authoritative pose describes the judged historical tick,
## not the current body. Publication and intent sends have independent cadence
## phases, and an observed clock can advance by several ticks. An unsampled
## tick is therefore interpolated only between retained samples no further
## apart than one intent cadence. Larger clock gaps stay unjudged;
## outside that history nothing is compared or corrected. One actual future
## authority observation waits for local history even if newer ticks arrive.
## Observation ordering and successful judgment use separate monotonic fences.
func reconcile(
	server_tick: int,
	server_transform: Transform3D,
	tolerance_metres: float = DEFAULT_CORRECTION_TOLERANCE_METRES
) -> Dictionary:
	if server_tick < _last_observed_pose_tick:
		return {"correct": false, "status": &"no_local_pose", "error_m": 0.0}
	_last_observed_pose_tick = server_tick
	# An authority observation can arrive ahead of the locally simulated stamp.
	# Retain one actual observation until its historical pose becomes available:
	# replacing it with each newer future tick would starve judgment forever.
	var judged_tick := server_tick
	var judged_transform := server_transform
	if not _pending_authoritative_pose.is_empty():
		var pending_tick := int(_pending_authoritative_pose.server_tick)
		if _historical_pose(pending_tick).is_empty():
			if pending_tick > _last_pose_tick:
				return {"correct": false, "status": &"no_local_pose", "error_m": 0.0}
			# The clock skipped this stamp beyond the existing interpolation bound,
			# or its history expired. Never manufacture a pose to judge it.
			_pending_authoritative_pose.clear()
		else:
			judged_tick = pending_tick
			judged_transform = _pending_authoritative_pose.transform
			_pending_authoritative_pose.clear()
			if server_tick > judged_tick:
				_pending_authoritative_pose = {"server_tick": server_tick, "transform": server_transform}
	server_tick = judged_tick
	server_transform = judged_transform
	if server_tick <= _last_judged_tick:
		return {"correct": false, "status": &"no_local_pose", "error_m": 0.0}
	var sample := _historical_pose(server_tick)
	if sample.is_empty():
		if server_tick > _last_pose_tick and not _pose_history.is_empty():
			_pending_authoritative_pose = {"server_tick": server_tick, "transform": server_transform}
		return {"correct": false, "status": &"no_local_pose", "error_m": 0.0}
	var local: Transform3D = sample.pose
	_last_judged_tick = server_tick
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
		var correction_delta := server_transform.origin - local.origin
		# These samples describe movement after the judged tick. Translate them
		# with the live body so the next judgment does not repeat this error.
		for tick_variant in _pose_order:
			var newer: Transform3D = _pose_history[tick_variant]
			newer.origin += correction_delta
			_pose_history[tick_variant] = newer
		_corrections += 1
		_last_correction = {"server_tick": server_tick, "predicted_position": local.origin, "authoritative_position": server_transform.origin, "correction_delta": correction_delta}
		return {"correct": true, "status": &"corrected", "error_m": error, "correction_delta": correction_delta}
	return {"correct": false, "status": &"within_tolerance", "error_m": error}


func _historical_pose(server_tick: int) -> Dictionary:
	if _pose_history.has(server_tick):
		return {"pose": _pose_history[server_tick]}
	var before_tick := -1
	var after_tick := -1
	for tick_variant in _pose_order:
		var tick := int(tick_variant)
		if tick < server_tick and tick > before_tick:
			before_tick = tick
		elif tick > server_tick and (after_tick < 0 or tick < after_tick):
			after_tick = tick
	if before_tick < 0 or after_tick < 0 or after_tick - before_tick > _cadence_ticks:
		return {}
	var before: Transform3D = _pose_history[before_tick]
	var after: Transform3D = _pose_history[after_tick]
	var weight := float(server_tick - before_tick) / float(after_tick - before_tick)
	return {"pose": before.interpolate_with(after, weight)}


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
		"clock_recoveries": _clock_recoveries,
		"last_client_tick": _last_client_tick,
		"observed_server_tick": _observed_server_tick,
		"estimated_server_tick": estimated_server_tick(),
		"interaction_request_id": _interaction_request_id,
		"pose_history": _pose_history.size(),
		"last_observed_pose_tick": _last_observed_pose_tick,
		"last_judged_tick": _last_judged_tick,
		"pending_pose_tick": int(_pending_authoritative_pose.get("server_tick", -1)),
		"corrections": _corrections,
		"worst_divergence_m": _worst_divergence,
		"last_correction": _last_correction.duplicate(),
		"owns_movement_authority": false,
	}


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
