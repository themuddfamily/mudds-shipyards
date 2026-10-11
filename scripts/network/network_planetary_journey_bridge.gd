extends RefCounted
## Session-owned Ember orbit cruise. Absolute focus crosses the wire; each
## machine retains its own local coordinate-frame generation and origin owner.
## Clients observe streaming only. Pilot, ship movement and saves stay on host.

const WORLD_ID := &"ember_moon"
const PREPARE_TIMEOUT_MSEC := 10000
const PUBLICATION_TICKS := 6
var _flow: Node
var _epoch := 0
var _state: Dictionary = {}
var _ready_peers: Dictionary = {}
var _prepare_deadline := 0
var _ticks := 0
var _last_ack_origin := -1
var _readiness_retry_ticks := 0
var _client_rebases := 0

func _init(flow: Node) -> void:
	_flow = flow

func begin() -> Dictionary:
	if not _state.is_empty():
		return {"accepted": false, "reason": &"shared_journey_active"}
	var gate: StringName = _flow._planetary_cruise_gate_reason()
	if not gate.is_empty() or not _flow._shared_planetary_host_eligible():
		return {"accepted": false, "reason": gate if not gate.is_empty() else &"network_session_active"}
	_epoch += 1
	_ready_peers.clear()
	_prepare_deadline = Time.get_ticks_msec() + PREPARE_TIMEOUT_MSEC
	_state = {"journey_epoch": _epoch, "world_id": WORLD_ID,
		"ship_id": _flow.active_ship.get_ship_id(), "phase": &"preparing"}
	_publish(true)
	return {"accepted": true, "reason": &"shared_journey_preparing"}

func is_active() -> bool:
	return not _state.is_empty()

func is_preparing() -> bool:
	return _state.get("phase", &"") == &"preparing"

func get_snapshot() -> Dictionary:
	var snapshot := _state.duplicate(true)
	snapshot["ready_peers"] = _ready_peers.keys()
	snapshot["ready_origin_revisions"] = _ready_peers.duplicate(true)
	snapshot["client_rebases"] = _client_rebases
	return snapshot

func before_world_tick() -> void:
	if not is_active() or not _flow.network_session.is_server():
		return
	if not _flow._shared_planetary_host_eligible():
		cancel(&"pilot_ownership_lost")
		return
	if not is_preparing():
		return
	if Time.get_ticks_msec() >= _prepare_deadline:
		cancel(&"shared_journey_readiness_timeout")
		return
	var frame: PlanetaryCoordinateFrame = _flow.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if int(_state.get("origin_revision", -1)) != frame.get_generation():
		_ready_peers.clear()
		_publish(true)
	for peer in _flow.network_session.get_admitted_peer_ids():
		if int(_ready_peers.get(peer, -1)) != int(_state.get("origin_revision", -2)):
			return
	var result: Dictionary = _flow.planetary_cruise_binding.request_engage(
		_flow.active_ship, frame.get_generation(), _flow._planetary_cruise_gate_reason(),
		_flow.planetary_cruise_binding.get_generation())
	if not bool(result.get("accepted", false)):
		cancel(StringName(result.get("reason", &"shared_engage_rejected")))
		return
	_state["phase"] = &"cruising"
	_publish(true)

func after_world_tick() -> void:
	if not is_active():
		return
	if _flow.network_session.is_server():
		_ticks += 1
		if _ticks % PUBLICATION_TICKS == 0:
			_publish(false)
		if _state.get("phase") == &"cruising" and not bool(_flow.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)):
			# Controller cessation alone is not evidence of orbital arrival.
			_state["phase"] = &"cruise_stopped"
			_publish(true)
		return
	# Reliable delivery cannot guarantee application admission: the shared
	# secure-packet budget may reject an acknowledgement. Preparation retries
	# the same fenced tuple on the existing publication cadence until the host
	# leaves preparation or its bounded deadline retires the journey.
	if not is_preparing():
		return
	_readiness_retry_ticks = maxi(0, _readiness_retry_ticks - 1)
	if _readiness_retry_ticks > 0:
		return
	var binding: Dictionary = _flow.ember_streaming_binding.get_snapshot()
	if not bool((binding.get("last_tick_result", {}) as Dictionary).get("accepted", false)):
		return
	if int(binding.get("bound_coordinate_frame_generation", -1)) != int(binding.get("current_coordinate_frame_generation", -2)):
		return
	var preview: Dictionary = _flow.ember_streaming_binding.preview_origin_rebase(int(binding.current_coordinate_frame_generation))
	if not bool(preview.get("accepted", false)) or bool(preview.get("rebase_required", false)):
		return
	var streaming := binding.get("last_streaming_result", {}) as Dictionary
	if streaming.get("action", &"") == &"load" and not is_instance_valid(_flow.ember_streaming_bootstrap.get_loaded_instance()):
		return
	var origin_revision := int(_state.get("origin_revision", -1))
	_readiness_retry_ticks = PUBLICATION_TICKS
	var queued: Dictionary = _flow.network_session.send_planetary_journey_ready({"journey_epoch": int(_state.journey_epoch),
		"origin_revision": origin_revision, "world_id": WORLD_ID, "ship_id": _state.ship_id})
	if bool(queued.get("accepted", false)):
		_last_ack_origin = origin_revision
		_client_rebases = int(binding.get("external_rebase_commit_count", 0))

func client_actor_sample(local_sample: Dictionary) -> Dictionary:
	if not is_active() or _flow.network_session.is_server():
		return local_sample
	var craft: Node3D = _flow._find_flyable_ship_by_id(StringName(_state.get("ship_id", &"")))
	# An observer still at Mudds retains its own nearby origin. Aboard peers
	# observe the host craft; its absolute focus remains canonical across each
	# machine's independent local-origin transaction.
	if not _flow._network_client_boarding_holds(craft):
		return local_sample
	# Origin previews must describe the actual local interpolated actor. A
	# newer host-focus packet cannot stand in for this replica's real pose.
	return {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}

func consume_state(packet: Dictionary) -> void:
	if _flow.network_session.is_server():
		return
	var epoch := int(packet.get("journey_epoch", 0))
	if epoch < _epoch or epoch <= 0 or packet.get("world_id") != WORLD_ID:
		return
	if packet.get("phase") == &"retired":
		_epoch = epoch
		_state.clear()
		return
	if packet.get("phase") not in [&"preparing", &"cruising", &"cruise_stopped"]:
		return
	var frame: PlanetaryCoordinateFrame = _flow.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if not bool(frame.validate_orbital_coordinate(packet.get("absolute_focus", {})).get("accepted", false)) \
			or _flow._find_flyable_ship_by_id(StringName(packet.get("ship_id", &""))) == null:
		return
	if epoch > _epoch:
		_last_ack_origin = -1
	_epoch = epoch
	_state = packet.duplicate(true)

func consume_ready(peer_id: int, payload: Dictionary) -> void:
	if not is_active() or not _flow.network_session.is_server():
		return
	if int(payload.get("journey_epoch", -1)) != int(_state.journey_epoch) \
			or int(payload.get("origin_revision", -1)) != int(_state.get("origin_revision", -2)) \
			or payload.get("world_id") != WORLD_ID or payload.get("ship_id") != _state.ship_id:
		return
	_ready_peers[peer_id] = int(payload.origin_revision)

func peer_admitted(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	if is_active() and _flow.network_session.is_server():
		_publish(true, peer_id)

func cancel(reason: StringName) -> Dictionary:
	if is_active() and _flow.network_session.is_server():
		_flow.planetary_cruise_binding.request_disengage(_flow.planetary_cruise_binding.get_generation(), true)
		_state["phase"] = &"retired"
		_state["retirement_reason"] = reason
		_publish(true)
	_state.clear()
	_ready_peers.clear()
	_last_ack_origin = -1
	return {"accepted": true, "reason": reason}

func detach() -> void:
	# Session state cannot survive into another adapter, even when that adapter
	# begins its sequence at one again. No shared visit is saved by this bridge.
	if is_active() and is_instance_valid(_flow.planetary_cruise_binding):
		_flow.planetary_cruise_binding.request_disengage(_flow.planetary_cruise_binding.get_generation(), true)
	_state.clear()
	_ready_peers.clear()
	_epoch = 0
	_last_ack_origin = -1

func _publish(reliable: bool, recipient: int = 0) -> void:
	if _state.get("phase") == &"retired":
		# A removed or destroyed craft cannot suppress retirement. Its last
		# validated absolute focus is passive metadata in this tombstone.
		_flow.network_session.publish_planetary_journey_state(_state, true, recipient)
		return
	var frame: PlanetaryCoordinateFrame = _flow.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var craft: Node3D = _flow._find_flyable_ship_by_id(StringName(_state.ship_id))
	if not is_instance_valid(craft):
		return
	var focus := frame.world_streaming_to_orbital_position(craft.global_position, frame.get_generation())
	if not bool(focus.get("accepted", false)):
		return
	_state["absolute_focus"] = focus.coordinate
	if int(_state.get("origin_revision", -1)) != frame.get_generation():
		_ready_peers.clear()
	_state["origin_revision"] = frame.get_generation()
	_flow.network_session.publish_planetary_journey_state(_state, reliable, recipient)
