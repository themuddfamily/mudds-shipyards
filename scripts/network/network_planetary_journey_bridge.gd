extends RefCounted
## Session-owned physical Ember journey and bounded Aurora/Rime arrivals. Absolute
## focus crosses the wire; each machine retains its own local coordinate-frame generation and origin owner.
## Clients observe streaming only. Pilot, ship movement and saves stay on host.

const WORLD_ID := &"ember_moon"
const AURORA_WORLD_ID := &"aurora_temperate_world"
const RIME_WORLD_ID := &"rime_glacial_world"
const ARRIVAL_OWNERS := {
	AURORA_WORLD_ID: &"_aurora_expedition",
	RIME_WORLD_ID: &"_rime_expedition",
}
const WORLD_PAIRS := {
	WORLD_ID: [&"ember_streaming_bootstrap", &"ember_streaming_binding"],
	AURORA_WORLD_ID: [&"aurora_streaming_bootstrap", &"aurora_streaming_binding"],
	RIME_WORLD_ID: [&"rime_streaming_bootstrap", &"rime_streaming_binding"],
}
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
var _craft_instance_id := 0
var _pilot_source_ref: WeakRef
var _client_observer_admitted := false

func _init(flow: Node) -> void:
	_flow = flow

func begin(world_id: StringName = WORLD_ID) -> Dictionary:
	if not _state.is_empty():
		return {"accepted": false, "reason": &"shared_journey_active"}
	if not WORLD_PAIRS.has(world_id):
		return {"accepted": false, "reason": &"shared_world_unavailable"}
	var gate: StringName = _flow._planetary_cruise_gate_reason()
	if not gate.is_empty() or not _flow._shared_planetary_host_eligible():
		return {"accepted": false, "reason": gate if not gate.is_empty() else &"network_session_active"}
	if ARRIVAL_OWNERS.has(world_id) and not _arrival_owner(world_id).request(true):
		return {"accepted": false, "reason": _arrival_reason(world_id, "admission_refused")}
	_craft_instance_id = _flow.active_ship.get_instance_id()
	_pilot_source_ref = weakref(_flow.active_ship.get_command_source())
	_epoch += 1
	_ready_peers.clear()
	_prepare_deadline = Time.get_ticks_msec() + PREPARE_TIMEOUT_MSEC
	_state = {"journey_epoch": _epoch, "world_id": world_id,
		"ship_id": _flow.active_ship.get_ship_id(), "phase": &"preparing"}
	_publish(true)
	return {"accepted": true, "reason": &"shared_journey_preparing"}

func is_active() -> bool:
	return not _state.is_empty()

func get_world_id() -> StringName:
	return StringName(_state.get("world_id", &""))

func get_ship_id() -> StringName:
	return StringName(_state.get("ship_id", &""))

func owns_current_return_pilot(ship: HeroShip) -> bool:
	var source: Object = _pilot_source_ref.get_ref() if _pilot_source_ref != null else null
	return is_active() and get_world_id() == WORLD_ID and not is_preparing() \
		and is_instance_valid(ship) and ship.get_instance_id() == _craft_instance_id \
		and is_instance_valid(source) and ship.get_command_source() == source


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
	if is_surface_arrival():
		_before_surface_arrival_tick()
		return
	_flow._planetary_journey.finish_shared_ember_surface_handback()
	var has_surface: bool = _flow._planetary_journey.shared_ember_surface_was_admitted()
	var surface_current: bool = _flow._planetary_journey.shared_ember_surface_is_current()
	var handback_pending: bool = _flow._planetary_journey.shared_ember_surface_handback_pending()
	var abandon_handback_pending: bool = _flow._planetary_journey.shared_ember_abandon_handback_pending()
	var has_return: bool = _flow._planetary_journey.shared_ember_abandon_return_was_admitted()
	var return_current: bool = _flow._planetary_journey.shared_ember_abandon_return_is_current()
	if (has_return and not return_current) or (not has_return and (
		(has_surface and not surface_current and not handback_pending and not abandon_handback_pending)
		or (not has_surface and not _flow._shared_planetary_host_eligible()))):
		cancel(&"pilot_ownership_lost")
		return
	if not is_preparing():
		return
	if Time.get_ticks_msec() >= _prepare_deadline:
		cancel(&"shared_journey_readiness_timeout")
		return
	var frame: PlanetaryCoordinateFrame = _bootstrap().get_coordinate_frame_for_session()
	if int(_state.get("origin_revision", -1)) != frame.get_generation():
		_ready_peers.clear()
		_publish(true)
	for peer in _flow.network_session.get_admitted_peer_ids():
		if int(_ready_peers.get(peer, -1)) != int(_state.get("origin_revision", -2)):
			return
	var result: Dictionary = _flow.planetary_cruise_binding.request_engage(
		_flow.active_ship, frame.get_generation(), _flow._planetary_cruise_gate_reason(),
		_flow.planetary_cruise_binding.get_generation(), true)
	if not bool(result.get("accepted", false)):
		cancel(StringName(result.get("reason", &"shared_engage_rejected")))
		return
	var landing: Dictionary = _flow._planetary_journey.begin_shared_ember_landing()
	if not bool(landing.get("accepted", false)):
		cancel(StringName(landing.get("reason", &"shared_landing_rejected")))
		return
	_state["phase"] = &"cruising"
	_publish(true)

func after_world_tick() -> void:
	if not is_active():
		return
	if _flow.network_session.is_server():
		if is_surface_arrival():
			_after_surface_arrival_tick()
			return
		_ticks += 1
		if _ticks % PUBLICATION_TICKS == 0:
			_publish(false)
		var landing: Dictionary = _flow._planetary_journey.get_shared_ember_landing_snapshot()
		var return_current: bool = _flow._planetary_journey.shared_ember_abandon_return_is_current()
		if not is_preparing() and landing.is_empty() and not return_current:
			cancel(&"shared_landing_owner_retired")
			return
		var next_phase: StringName = StringName(_state.get("phase", &""))
		var cruise: Dictionary = _flow.planetary_cruise_binding.get_snapshot()
		if return_current:
			next_phase = &"returning"
		elif bool(_flow._planetary_journey.get("_shared_ember_surface_finished")) \
				or _flow._planetary_journey.shared_ember_surface_handback_pending():
			next_phase = &"returning"
		elif _flow._planetary_journey.shared_ember_surface_is_current():
			next_phase = &"landed" if bool(_flow.active_ship.get_telemetry().get("landed", false)) else &"returning"
		elif bool(landing.get("landed", false)):
			next_phase = &"landed"
		elif bool(landing.get("handoff_ready", false)):
			next_phase = &"approaching"
		elif next_phase == &"cruising" and not bool(cruise.get("engagement_requested", false)):
			# Controller cessation alone is not evidence of orbital arrival.
			next_phase = &"cruise_stopped"
		elif next_phase == &"cruise_stopped" and bool(cruise.get("engagement_requested", false)) \
				and _flow._shared_planetary_host_eligible() \
				and _flow._planetary_journey._ember_outbound_transit_wanted() \
				and _state.get("ship_id") == _flow.active_ship.get_ship_id() \
				and int(cruise.get("engaged_ship_instance_id", 0)) == _flow.active_ship.get_instance_id() \
				and int(cruise.get("bound_coordinate_frame_generation", -1)) \
					== int(cruise.get("current_coordinate_frame_generation", -2)):
			# The retained outbound owner may resume after a real binding pause.
			# Publish that current physical engagement under the same journey epoch.
			next_phase = &"cruising"
		if next_phase != _state.get("phase"):
			_state["phase"] = next_phase
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
	if is_surface_arrival():
		var craft: HeroShip = _flow._find_flyable_ship_by_id(StringName(_state.ship_id))
		if not is_instance_valid(craft) or craft.get_instance_id() != _craft_instance_id:
			return
	var binding: Dictionary = _binding().get_snapshot()
	if not bool((binding.get("last_tick_result", {}) as Dictionary).get("accepted", false)):
		return
	if int(binding.get("bound_coordinate_frame_generation", -1)) != int(binding.get("current_coordinate_frame_generation", -2)):
		return
	var preview: Dictionary = _binding().preview_origin_rebase(int(binding.current_coordinate_frame_generation))
	if not bool(preview.get("accepted", false)) or bool(preview.get("rebase_required", false)):
		return
	var streaming := binding.get("last_streaming_result", {}) as Dictionary
	if streaming.get("action", &"") == &"load" and not is_instance_valid(_bootstrap().get_loaded_instance()):
		return
	var origin_revision := int(_state.get("origin_revision", -1))
	_readiness_retry_ticks = PUBLICATION_TICKS
	var queued: Dictionary = _flow.network_session.send_planetary_journey_ready({"journey_epoch": int(_state.journey_epoch),
		"origin_revision": origin_revision, "world_id": _state.world_id, "ship_id": _state.ship_id})
	if bool(queued.get("accepted", false)):
		_last_ack_origin = origin_revision
		_client_rebases = int(binding.get("external_rebase_commit_count", 0))

func client_actor_sample(local_sample: Dictionary) -> Dictionary:
	if not is_active() or _flow.network_session.is_server():
		return local_sample
	if _flow._network_client_ember_passenger_surface_is_current():
		# A confirmed exterior passenger remains a participant. Origin previews
		# describe the actual same local body, never a host-supplied pose.
		return {"available": true, "position": _flow.player.global_position,
			"actor_kind": &"player", "actor_instance_id": _flow.player.get_instance_id()}
	var craft: Node3D = _flow._find_flyable_ship_by_id(StringName(_state.get("ship_id", &"")))
	# An observer still at Mudds retains its own nearby origin. Aboard peers
	# observe the host craft; its absolute focus remains canonical across each
	# machine's independent local-origin transaction.
	if is_surface_arrival() and (not is_instance_valid(craft) or craft.get_instance_id() != _craft_instance_id):
		return local_sample
	if not _flow._network_client_boarding_holds(craft):
		return local_sample
	# Origin previews must describe the actual local interpolated actor. A
	# newer host-focus packet cannot stand in for this replica's real pose.
	return {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}

func consume_state(packet: Dictionary) -> void:
	if _flow.network_session.is_server():
		return
	var epoch := int(packet.get("journey_epoch", 0))
	if epoch < _epoch or epoch <= 0 or not WORLD_PAIRS.has(packet.get("world_id")):
		return
	if epoch == _epoch and not _state.is_empty() and (packet.get("world_id") != _state.get("world_id") \
			or packet.get("ship_id") != _state.get("ship_id")):
		return
	if packet.get("phase") == &"retired":
		if epoch == _epoch and not _state.is_empty() \
				and packet.get("ship_id") == _state.get("ship_id"):
			_flow._consume_network_ember_passenger_retirement(epoch, StringName(packet.ship_id))
		_retire_client_observer()
		_epoch = epoch
		_state.clear()
		return
	# A terminal epoch cannot be revived by delayed focus or boarding traffic.
	if epoch == _epoch and _state.is_empty():
		return
	if packet.get("phase") not in [&"preparing", &"cruising", &"cruise_stopped", &"approaching", &"landed", &"returning"]:
		return
	var bootstrap := _world_member(StringName(packet.world_id), 0) as PlanetaryStreamingBootstrap
	if not is_instance_valid(bootstrap):
		return
	var frame := bootstrap.get_coordinate_frame_for_session()
	if not bool(frame.validate_orbital_coordinate(packet.get("absolute_focus", {})).get("accepted", false)) \
			or _flow._find_flyable_ship_by_id(StringName(packet.get("ship_id", &""))) == null:
		return
	if epoch > _epoch:
		_retire_client_observer()
		_last_ack_origin = -1
		if ARRIVAL_OWNERS.has(packet.world_id):
			var craft: HeroShip = _flow._find_flyable_ship_by_id(StringName(packet.ship_id))
			var admitted: Dictionary = _flow._planetary_journey.admit_aurora_visit(craft, false, StringName(packet.world_id))
			if not bool(admitted.get("accepted", false)):
				return
			_client_observer_admitted = true
			_craft_instance_id = craft.get_instance_id()
	_epoch = epoch
	_state = packet.duplicate(true)

func consume_ready(peer_id: int, payload: Dictionary) -> void:
	if not is_active() or not _flow.network_session.is_server():
		return
	if int(payload.get("journey_epoch", -1)) != int(_state.journey_epoch) \
			or int(payload.get("origin_revision", -1)) != int(_state.get("origin_revision", -2)) \
			or payload.get("world_id") != _state.world_id or payload.get("ship_id") != _state.ship_id:
		return
	if not _flow.network_session.get_admitted_peer_ids().has(peer_id):
		return
	_ready_peers[peer_id] = int(payload.origin_revision)

func peer_admitted(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	if is_active() and _flow.network_session.is_server():
		_publish(true, peer_id)

func cancel(reason: StringName) -> Dictionary:
	if is_active() and _flow.network_session.is_server():
		_flow._planetary_journey.retire_shared_ember_abandon_return(reason)
		if is_surface_arrival():
			if _arrival_owner(get_world_id()).state == &"landed" and reason == &"player_cancelled":
				_flow.hud.toast("Shared %s arrival" % _arrival_owner(get_world_id()).profile.display_name, ("Crew can walk Aurora's landing pad and reboard; shared return to Mudds is not available" if get_world_id() == &"aurora_temperate_world" else "Surface exploration and return are not available for this shared arrival"), 3.0)
				return {"accepted": false, "reason": _arrival_reason(get_world_id(), "return_unavailable")}
			_arrival_owner(get_world_id()).cancel()
		elif _flow._planetary_journey.shared_ember_surface_was_admitted():
			if reason == &"player_cancelled":
				return _flow._planetary_journey.abandon_ember_surface_journey(reason)
			_flow._planetary_journey.retire_shared_ember_surface(reason)
		var landing: Dictionary = {} if is_surface_arrival() else _flow._planetary_journey.get_shared_ember_landing_snapshot()
		if not landing.is_empty():
			var cancelled: Dictionary = _flow._planetary_journey.cancel_ember_surface_journey()
			if not bool(cancelled.get("accepted", false)) and reason == &"player_cancelled":
				return cancelled
		_flow.planetary_cruise_binding.request_disengage(_flow.planetary_cruise_binding.get_generation(), true)
		_state["phase"] = &"retired"
		_state["retirement_reason"] = reason
		_publish(true)
	_retire_client_observer()
	_state.clear()
	_ready_peers.clear()
	_last_ack_origin = -1
	return {"accepted": true, "reason": reason}

func detach() -> void:
	_flow._planetary_journey.retire_shared_ember_abandon_return(&"network_session_retired")
	if is_surface_arrival() and _flow._network_session_mode == &"server" \
			and _arrival_owner(get_world_id()).is_active():
		_arrival_owner(get_world_id()).cancel()
	_retire_client_observer()
	_flow._planetary_journey.retire_shared_ember_surface(&"network_session_retired")
	# Withdraw an outbound request before its physical Host starts. A running
	# landing remains owned by that Host and retains its ordinary berth lease.
	if not _flow._planetary_journey.get_shared_ember_landing_snapshot().is_empty():
		_flow._planetary_journey.cancel_ember_surface_journey()
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
	var frame: PlanetaryCoordinateFrame = _bootstrap().get_coordinate_frame_for_session()
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


func is_surface_arrival() -> bool:
	return ARRIVAL_OWNERS.has(get_world_id())


func _arrival_owner(world_id: StringName) -> RefCounted:
	return _flow.get(ARRIVAL_OWNERS[world_id]) as RefCounted


func _arrival_reason(world_id: StringName, suffix: String) -> StringName:
	return StringName("shared_%s_%s" % [_arrival_owner(world_id).profile.reason_prefix, suffix])


func _world_member(world_id: StringName, index: int) -> Node:
	var pair: Array = WORLD_PAIRS.get(world_id, [])
	return _flow.get(pair[index]) as Node if pair.size() == 2 else null


func _bootstrap() -> PlanetaryStreamingBootstrap:
	return _world_member(StringName(_state.get("world_id", WORLD_ID)), 0) as PlanetaryStreamingBootstrap


func _binding() -> PlanetaryStreamingProductionBinding:
	return _world_member(StringName(_state.get("world_id", WORLD_ID)), 1) as PlanetaryStreamingProductionBinding


func _retire_client_observer() -> void:
	if _client_observer_admitted:
		_flow._planetary_journey.retire_aurora_visit()
	_client_observer_admitted = false


func _surface_arrival_host_is_current() -> bool:
	var craft: HeroShip = _flow.active_ship
	return is_instance_valid(craft) and craft.is_inside_tree() and not craft.is_queued_for_deletion() \
		and not craft.is_destroyed() and craft.get_instance_id() == _craft_instance_id \
		and craft.get_ship_id() == _state.get("ship_id") \
		and _arrival_owner(get_world_id()).get_craft() == craft \
		and _flow._planetary_journey.is_aurora_visit_active() \
		and _flow._planetary_journey.get_visit_world_id() == get_world_id() \
		and ((_flow._shared_planetary_host_eligible() and _pilot_source_ref != null \
			and _pilot_source_ref.get_ref() == craft.get_command_source()) \
			or _arrival_owner(get_world_id()).shared_arrival_cabin_owner_is_current())


func _before_surface_arrival_tick() -> void:
	if not _surface_arrival_host_is_current():
		cancel(&"pilot_ownership_lost")
		return
	if not is_preparing():
		return
	if Time.get_ticks_msec() >= _prepare_deadline:
		cancel(&"shared_journey_readiness_timeout")
		return
	var frame := _bootstrap().get_coordinate_frame_for_session()
	if int(_state.get("origin_revision", -1)) != frame.get_generation():
		_ready_peers.clear()
		_publish(true)
	for peer in _flow.network_session.get_admitted_peer_ids():
		if int(_ready_peers.get(peer, -1)) != int(_state.get("origin_revision", -2)):
			return
	# The world's existing coordinator rechecks its real pilot/combat/origin
	# gates; transport readiness never grants a ship movement capability.
	var engaged: Dictionary = _flow._planetary_journey.engage_aurora_cruise(_flow.active_ship, true)
	if not bool(engaged.get("accepted", false)):
		cancel(StringName(engaged.get("reason", &"shared_engage_rejected")))
		return
	_state["phase"] = &"cruising"
	_publish(true)


func _after_surface_arrival_tick() -> void:
	if not _arrival_owner(get_world_id()).is_active():
		cancel(&"shared_landing_owner_retired")
		return
	_ticks += 1
	var next_phase := StringName(_state.get("phase", &""))
	match _arrival_owner(get_world_id()).state:
		&"corridor", &"landing":
			next_phase = &"approaching"
		&"landed":
			next_phase = &"landed"
		&"outbound":
			if not is_preparing():
				next_phase = &"cruising" if bool(_flow.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)) else &"cruise_stopped"
	if next_phase != _state.get("phase"):
		_state["phase"] = next_phase
		_publish(true)
	elif _ticks % PUBLICATION_TICKS == 0:
		_publish(false)
