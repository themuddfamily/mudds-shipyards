## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_yaw_test.gd"

## HELM-YAW-HANDBACK: the complete accepted ordinary route and both yaw turns
## precede one normal pilot Interact and a short, real cabin walk. The host owns
## the transition/walk deadlines; files authorize input and carry observations.
## No test assigns a pose, engine state, claim, command source or authority.
var _handback_stage := "yaw"
var _handback_start: Dictionary = {}
var _handback_local: Dictionary = {}
var _handback_authorized := false
var _handback_completed := false
var _handback_session_id := 0
var _handback_craft_id := 0
var _handback_ship_source: ShipCommandSource
var _handback_capture := Callable()
var _handback_walk_start: Dictionary = {}
var _handback_sent_after_release := -1


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_pilot_handback_test.gd"
	return profile


func _print_peer_success() -> void:
	# The inherited coordinator calls this only after all three actual OS exits0.
	print("JOVIAN_NETWORK_PILOT_HANDBACK_OK checks=%d" % _checks)


func _host_scenario() -> bool:
	var result := await super._host_scenario()
	if result:
		result = await _host_handback()
	_release_handback_actions()
	return result


func _client_scenario() -> bool:
	var result := await super._client_scenario()
	if result:
		result = await _client_handback()
	_release_handback_actions()
	return result


func _release_handback_actions() -> void:
	for action in WALK_ACTIONS + [&"interact"]:
		_action(action, false)
		Input.action_release(action)


func _handback_initialize() -> void:
	_handback_session_id = _game.network_session.get_instance_id()
	_handback_craft_id = _craft.get_instance_id()
	_handback_ship_source = _craft.get("_default_local_command_source") as ShipCommandSource


func _host_handback() -> bool:
	_handback_initialize()
	_handback_stage = "host.offline"
	var initial := _host_flight_manifest()
	_handback_start = {"ownership": initial.ownership, "copilot": initial.client_b,
		"pilot_seat": initial.client.seat, "pilot_wire": initial.client.wire,
		"pose_tick": int(_game.get("_network_boarding_server_tick")),
		"ship_source_id": str(_handback_ship_source.get_instance_id()),
		"ship_source_stream": _handback_ship_source.get_stream_id(),
		"retiring_source_id": str(_flight_source.get_instance_id())}
	if not _require(_host_flight_current() and _handback_ship_source is LocalShipInputSource,
		"handback starts after unchanged departure/yaw with exact ship-owned fallback and original crew identities"):
		return false
	# Neutral automatic engine idle is production's 1.5s policy. Wait up to8s;
	# neither this test nor a client forces an engine state or simulation phase.
	if not await _handback_wait(func(): return _host_flight_current() and _handback_host_offline(), 8.0,
		"host naturally idles OFFLINE on a valid neutral delivered helm after both yaw turns"):
		return false
	_handback_start["pose_tick"] = int(_game.get("_network_boarding_server_tick"))
	_write("host.handback_prepare", _handback_start)
	if not await _handback_wait(func():
		return _host_flight_current() and _handback_host_offline() \
			and _flight_files_ready(".handback_ready"), 8.0,
		"both unchanged seated clients consume advanced host OFFLINE poses before pilot exit authorization"):
		return false
	_handback_stage = "host.role_transition"
	_handback_start["release_tick"] = int(_game.get("_network_boarding_server_tick"))
	_handback_start["release_publication_tick"] = int(_handback_publication().get("published_tick", -1))
	_handback_start["nose"] = _vector_values(-_craft.global_basis.z.normalized())
	_handback_start["up"] = _vector_values(_craft.global_basis.y.normalized())
	_handback_start["position"] = _vector_values(_station_position())
	_handback_authorized = true
	var transition_deadline := Time.get_ticks_msec() + 8000
	_write("host.handback_go", _handback_start)
	if not await _handback_wait(func(): return _handback_host_current(),
		_handback_remaining(transition_deadline),
		"ordinary pilot Interact atomically releases helm into a live supported cabin berth with owner0/generation+1 inside8s"):
		return false
	_write("host.handback_body", _handback_receipt())
	if not await _handback_wait(func(): return _handback_host_current() and _flight_files_ready(".handback_cabin"),
		_handback_remaining(transition_deadline),
		"both clients consume released ownership and former pilot shows honest PASSENGER HUD within the same8s handback budget"):
		return false
	_handback_stage = "host.cabin_walk"
	var body := _handback_host_body()
	_handback_walk_start = {"local_position": _vector_values(_craft.to_local(body.global_position)),
		"published_tick": int(_handback_publication().get("published_tick", -1)),
		"pose_tick": int(_game.get("_network_boarding_server_tick"))}
	var walk_deadline := Time.get_ticks_msec() + 15000
	_write("host.handback_walk", _handback_walk_start)
	if not await _handback_wait(func():
		var publication := _handback_publication()
		return _handback_host_current() and _handback_host_walk_distance() >= 0.6 \
			and int(publication.get("published_tick", -1)) > int(_handback_walk_start.published_tick) \
			and _flight_file_exists("client.handback_walked"), _handback_remaining(walk_deadline),
		"same authenticated former pilot actually walks>=0.6m on host and client with fresh walking publication inside15s"):
		return false
	_write("host.handback_walked", _handback_receipt())
	if not await _handback_wait(func(): return _handback_host_current() and _flight_files_ready(".handback_verified"),
		_handback_remaining(walk_deadline),
		"both actual clients retain released ownership and original co-pilot while former pilot is supported after real cabin walk"):
		return false
	_handback_completed = true
	_handback_stage = "retained"
	_write("host.handback_complete", _handback_receipt())
	return true


func _client_handback() -> bool:
	_handback_initialize()
	_handback_stage = _role + ".offline"
	_handback_local = {"manifest": _local_flight_manifest(),
		"source_stream": _handback_ship_source.get_stream_id() if is_instance_valid(_handback_ship_source) else -1}
	if _role == "client":
		var saved := (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) as Dictionary
		_handback_local["saved_authority"] = int(saved.get("authority", -1))
		var audit := _game.get_network_client_boarding_audit()
		_handback_local["release_requests"] = int(audit.get("helm_release_requests", 0))
		_handback_local["releases"] = int(audit.get("helm_releases", 0))
		_handback_capture = saved.get("capture", Callable())
		if not _require(saved.get("source") == _flight_source and _handback_capture.is_valid()
			and _flight_source.command_produced.is_connected(_handback_capture),
			"original pilot retains actual production capture callback and saved source authority before release"):
			return false
	if not await _handback_wait(func(): return _flight_file_exists("host.handback_prepare") and _local_flight_current(), 8.0,
		"host reaches natural neutral OFFLINE after unchanged yaw route"):
		return false
	_handback_start = _read("host.handback_prepare")
	if not await _handback_wait(func():
		return _local_flight_current() and _handback_client_pose_after(int(_handback_start.pose_tick), int(_flight_start.pilot_peer)) \
			and _handback_ownership_matches(int(_flight_start.pilot_peer), 0), 8.0,
		"actual seated client consumes advanced OFFLINE operation pose and received current pilot ownership before exit"):
		return false
	_write(_role + ".handback_ready", _handback_receipt())
	if not await _handback_wait(func(): return _flight_file_exists("host.handback_go") and _local_flight_current(), 8.0,
		"host authorizes only original pilot Interact after both clients consumed OFFLINE"):
		return false
	_handback_start = _read("host.handback_go")
	_handback_authorized = true
	_handback_stage = _role + ".role_transition"
	var transition_deadline := Time.get_ticks_msec() + 8000
	if _role == "client":
		await _press(&"interact")
	if not await _handback_wait(func():
		return _handback_local_current(false) and _flight_file_exists("host.handback_body"),
		_handback_remaining(transition_deadline),
		"original Player consumes atomic berth handback, released authority and current host walking-body publication inside8s"):
		return false
	if not await _handback_wait(func(): return _handback_local_current(true), _handback_remaining(transition_deadline),
		"actual consumed HUD shows PASSENGER for confirmed cabin berth, with original craft name and no retained PILOT/OBSERVER role"):
		return false
	if _role == "client":
		_handback_sent_after_release = int(_game.get("_network_remote_helm_sent"))
	_write(_role + ".handback_cabin", _handback_receipt())
	if not await _handback_wait(func(): return _flight_file_exists("host.handback_walk") and _handback_local_current(true), 8.0,
		"host authorizes finite ordinary cabin movement after both clients verify handback"):
		return false
	_handback_stage = _role + ".cabin_walk"
	_handback_walk_start = _read("host.handback_walk")
	var local_start := _craft.to_local(_player.global_position)
	var walk_deadline := Time.get_ticks_msec() + 15000
	if _role == "client":
		_action(&"move_back", true)
		if not await _handback_wait(func():
			var source := _game.get_network_remote_body_intent_source()
			var relationship := _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id())
			var pose: Transform3D = relationship.get("frame_local_transform", Transform3D.IDENTITY)
			return _handback_local_current(true) \
				and (_craft.to_local(_player.global_position) - local_start).slide(Vector3.UP).length() >= 0.6 \
				and (pose.origin - _vector_from(_handback_walk_start.local_position)).slide(Vector3.UP).length() >= 0.6 \
				and int(relationship.get("server_tick", -1)) > int(_handback_walk_start.published_tick),
			_handback_remaining(walk_deadline),
			"ordinary move_back moves original local Player and its fresh received authoritative walking pose>=0.6m inside15s"):
			return false
		_action(&"move_back", false)
		Input.action_release(&"move_back")
		_write("client.handback_walked", _handback_receipt())
	if not await _handback_wait(func(): return _handback_local_current(true) and _flight_file_exists("host.handback_walked"),
		_handback_remaining(walk_deadline), "host confirms actual supported walking body moved>=0.6m without stale helm motion"):
		return false
	_write(_role + ".handback_verified", _handback_receipt())
	if not await _handback_wait(func(): return _handback_local_current(true) and _flight_file_exists("host.handback_complete"),
		_handback_remaining(walk_deadline), "host confirms supported former pilot and untouched original co-pilot after walk"):
		return false
	_handback_completed = true
	_handback_stage = "retained"
	return true


func _handback_remaining(deadline: int) -> float:
	return maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0)


func _handback_wait(predicate: Callable, seconds: float, description: String) -> bool:
	# _flight_wait/_yaw_wait freeze the retired pilot/source and cannot cross a
	# legitimate role change. This wait retains the original global abort/300s.
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _aborted():
		if not _require(_handback_shared_current(),
			"same session/craft/authenticated Players and exact original co-pilot remain current throughout " + _handback_stage):
			return false
		if _handback_stage.ends_with(".cabin_walk"):
			if not _require(_handback_host_current() if _role == "host" else _handback_local_current(true),
				"released neutral helm, live supported cabin body and honest original crew roles persist throughout actual walking"):
				return false
		if bool(predicate.call()):
			return _require(true, description)
		await _ticks(1)
	return _require(false, description)


func _handback_shared_current() -> bool:
	if not is_instance_valid(_game.network_session) or _game.network_session.get_instance_id() != _handback_session_id \
		or _craft.get_instance_id() != _handback_craft_id or not _game.network_session.is_session_active():
		return false
	if _role == "host":
		var identities := _host_flight_manifest()
		return _peer_generation(int(_flight_start.pilot_peer)) == int(_flight_manifest.client.peer_generation) \
			and identities.client_b == _handback_start.copilot \
			and _passenger_is_current(int(_flight_start.passenger_peer)) and _host_passenger_follows_anchor(true) \
			and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled()
	if not _same_identity() or _player.get_instance_id() != _initial_player_id:
		return false
	if _role == "client_b":
		return _local_passenger_is_current() and _local_flight_manifest() == _handback_local.manifest \
			and _body_follows_anchor(_player, _flight_anchor, true) \
			and _craft.get("_default_local_command_source") == _handback_ship_source
	return true


func _handback_host_offline() -> bool:
	var command := _craft.get_last_ship_command()
	return str(_craft.get_telemetry().get("engine_state", "")).to_upper() == "OFFLINE" \
		and command != null and command.is_valid() and command.is_neutral() and _craft.velocity.length() <= 0.5


func _handback_ownership() -> Dictionary:
	if _role == "host":
		return _game.network_session.get_owned_ship(_craft.ship_id)
	# get_owned_ship() is server-only. Read the canonical records actually
	# received by this client's authoritative snapshot consumer.
	var sections := _game.network_session.get_authoritative_snapshot().get("sections", {}) as Dictionary
	for record: Dictionary in sections.get("ownership", []):
		if record.get("ship_id") == _craft.ship_id:
			return record
	return {}


func _handback_ownership_matches(owner: int, generation_delta: int) -> bool:
	var ownership := _handback_ownership()
	var initial := _handback_start.get("ownership", {}) as Dictionary
	return not ownership.is_empty() and ownership.get("ship_id") == _craft.ship_id \
		and int(ownership.get("ship_generation", -1)) == int(initial.get("ship_generation", -2)) \
		and int(ownership.get("owner_peer_id", -1)) == owner \
		and int(ownership.get("ownership_generation", -1)) == int(initial.get("ownership_generation", -2)) + generation_delta


func _handback_client_pose_after(tick: int, owner: int) -> bool:
	var sample := _flight_pose_sample()
	var operation := sample.get("operation_presentation", {}) as Dictionary
	# A coast row retains the former pilot transport lineage for600ticks; a
	# settled row uses authority1. Neither grants the canonical ship lease.
	var lineage := int(sample.get("pilot_peer_id", -1))
	var released_lineage := lineage == int(_flight_start.pilot_peer) \
		or (not bool(sample.get("pose_active", true)) and lineage == 1)
	return int(sample.get("pose_tick", -1)) > tick and (released_lineage if owner < 0 else lineage == owner) \
		and operation.get("engine") == HeroShip.ENGINE_OFFLINE


func _handback_claim() -> Dictionary:
	if _role != "host":
		return _game.get("_network_client_boarding_claim") as Dictionary
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == int(_flight_start.pilot_peer) \
			and held.get("avatar_id") == GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer)):
			return held
	return {}


func _handback_claim_current(claim: Dictionary) -> bool:
	var old := _handback_start.get("pilot_seat", {}) as Dictionary
	var valid_berth := false
	for index in GameFlow.NETWORK_CABIN_BERTH_COUNT:
		valid_berth = valid_berth or claim.get("seat_id") == GameFlow.network_cabin_berth_seat_id(_craft.ship_id, index + 1)
	if not valid_berth or claim.get("ship_id") != _craft.ship_id or claim.get("role") != &"passenger":
		return false
	# The client retains only the confirmed ship/seat/role. Its release audit
	# below verifies the callback and request completion; authoritative sequence
	# advancement and seat generation belong to the host's actual occupancy.
	if _role != "host":
		return true
	return int(claim.get("seat_generation", 0)) > 0 \
		and int(claim.get("claim_sequence", -1)) > int(old.get("claim_sequence", -1))


func _handback_publication() -> Dictionary:
	return _publication(GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer)))


func _handback_host_body() -> PlayerController:
	return _game.get_network_remote_body_simulation().get_body(
		GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer))) as PlayerController


func _handback_body_supported(body: PlayerController) -> bool:
	if not is_instance_valid(body) or body.is_seated() or not body.is_on_floor():
		return false
	var containment := body.get_cabin_containment_report()
	var frame := _craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	return containment.get("frame") == _craft and bool(containment.get("active", false)) \
		and bool(containment.get("contained", false)) and is_instance_valid(frame) and frame.is_occupant_registered(body)


func _handback_host_current() -> bool:
	var source_retired := not is_instance_valid(_flight_source) or not _flight_source.is_enabled_owner()
	var publication := _handback_publication()
	var wire := publication.get("wire", {}) as Dictionary
	var body := _handback_host_body()
	var avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer))
	var record := _game.get_network_remote_body_simulation().get_body_record(avatar)
	var old_wire := _handback_start.get("pilot_wire", {}) as Dictionary
	return _handback_shared_current() and _handback_authorized and _handback_claim_current(_handback_claim()) \
		and _handback_ownership_matches(0, 1) and source_retired \
		and not (_game.get("_network_remote_pilots") as Dictionary).has(_craft.ship_id) \
		and _craft.get("_command_source") == _handback_ship_source and _handback_ship_source.get_parent() == _craft \
		and str(_handback_ship_source.get_instance_id()) == str(_handback_start.ship_source_id) \
		and _handback_ship_source.get_stream_id() > int(_handback_start.ship_source_stream) \
		and not _craft.is_piloted() and not _craft.is_remote_piloted() and _handback_host_offline() \
		and absf(_yaw_heading_change(_handback_start)) <= 0.5 \
		and _station_position().distance_to(_vector_from(_handback_start.position)) <= 0.5 \
		and _handback_body_supported(body) and record.get("seat_state") == &"standing" and record.get("avatar_mode") == &"on_foot" \
		and int(record.get("owner_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and publication.get("occupant") == body and not bool(publication.get("seated", true)) \
		and int(publication.get("owner_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and wire.get("entity_id") == avatar \
		and int(wire.get("entity_generation", 0)) == int(record.get("entity_generation", -1)) \
		and wire.get("parent_frame_id") == old_wire.get("parent_frame_id") \
		and int(wire.get("parent_frame_generation", 0)) == int(old_wire.get("parent_frame_generation", -1)) \
		and int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING \
		and int(wire.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING \
		and int(publication.get("published_tick", -1)) > int(_handback_start.release_publication_tick)


func _handback_local_current(require_hud: bool) -> bool:
	if not _handback_shared_current() or not _handback_ownership_matches(0, 1) \
		or not _handback_client_pose_after(int(_handback_start.release_tick), -1):
		return false
	if _role == "client_b":
		return true
	var source := _game.get_network_remote_body_intent_source()
	if source == null or not source.is_bound():
		return false
	var relationship := _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id())
	var old_wire := _handback_start.get("pilot_wire", {}) as Dictionary
	var saved := _game.get("_network_client_helm_input_sources") as Dictionary
	var audit := _game.get_network_client_boarding_audit()
	var command := _craft.get_last_ship_command()
	return _supported_cabin() and _handback_body_supported(_player) and not _player.is_station_seated() \
		and not bool(_game.get("_piloting")) and _game.get("_cabin_ship") == _craft \
		and not _craft.is_piloted() and not _craft.is_remote_piloted() and command != null and command.is_neutral() \
		and not bool(audit.get("request_pending", true)) \
		and int(audit.get("helm_release_requests", -1)) == int(_handback_local.release_requests) + 1 \
		and int(audit.get("helm_releases", -1)) == int(_handback_local.releases) + 1 \
		and _handback_claim_current(_handback_claim()) \
		and _craft.get("_default_local_command_source") == _handback_ship_source \
		and _craft.get("_command_source") == _handback_ship_source \
		and _handback_ship_source == _flight_source \
		and _handback_ship_source.get_authority_peer_id() == int(_handback_local.saved_authority) \
		and _handback_ship_source.get_stream_id() > int(_handback_local.source_stream) \
		and not _handback_ship_source.command_produced.is_connected(_handback_capture) \
		and not saved.has(_craft.get_instance_id()) and (_game.get("_network_remote_helm") as Dictionary).is_empty() \
		and (_handback_sent_after_release < 0 or int(_game.get("_network_remote_helm_sent")) == _handback_sent_after_release) \
		and source.get_entity_id() == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and int(relationship.get("entity_generation", 0)) == source.get_entity_generation() \
		and relationship.get("parent_frame_id") == old_wire.get("parent_frame_id") \
		and int(relationship.get("parent_frame_generation", 0)) == int(old_wire.get("parent_frame_generation", -1)) \
		and int(relationship.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING \
		and int(relationship.get("server_tick", -1)) > int(_handback_start.release_publication_tick) \
		and (not require_hud or _hud_role_is_current(&"passenger"))


func _handback_host_walk_distance() -> float:
	var body := _handback_host_body()
	if not is_instance_valid(body):
		return -1.0
	return (_craft.to_local(body.global_position) - _vector_from(_handback_walk_start.local_position)).slide(Vector3.UP).length()


func _pilot_is_current(peer: int) -> bool:
	# The inherited final retained-client barrier runs after _host_scenario().
	# Only a fully qualified authorized handback changes its expected role; the
	# original route/yaw still calls the original exact pilot predicate. Re-read
	# the actual current cabin claim/body, retired source and owner0/gen+1 here.
	if _handback_completed and _role == "host":
		return peer == int(_flight_start.pilot_peer) and _handback_host_current()
	return super._pilot_is_current(peer)


func _handback_receipt() -> Dictionary:
	var receipt := {"stage": _handback_stage, "ownership": _handback_ownership(),
		"claim": _primitive_fields(_handback_claim(), ["ship_id", "ship_generation", "peer_id", "avatar_id", "role", "seat_id", "seat_generation", "claim_sequence"]),
		"pose_tick": int(_game.get("_network_boarding_server_tick")),
		"player": _node_identity(_player), "craft": _node_identity(_craft),
		"source": _producer_state(_handback_ship_source), "helm_capture": _game.get("_network_remote_helm"),
		"helm_sent": int(_game.get("_network_remote_helm_sent")), "phase": _game.phase}
	if _role == "host":
		var publication := _handback_publication()
		var body := _handback_host_body()
		receipt["body"] = _node_identity(body)
		receipt["body_record"] = _game.get_network_remote_body_simulation().get_body_record(
			GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer)))
		receipt["wire"] = publication.get("wire", {})
		receipt["publication"] = _primitive_fields(publication, ["published_tick", "published_state", "owner_peer_id", "seated"])
		receipt["body_supported"] = _handback_body_supported(body)
		receipt["body_local_position"] = _vector_values(_craft.to_local(body.global_position)) if is_instance_valid(body) else []
		receipt["remote_source_retired"] = not is_instance_valid(_flight_source) or not _flight_source.is_enabled_owner()
		receipt["host_command"] = _craft.get_last_ship_command().to_dictionary() if _craft.get_last_ship_command() != null else {}
		receipt["engine_state"] = str(_craft.get_telemetry().get("engine_state", ""))
	else:
		var presenter := _game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
		receipt["hud"] = _primitive_fields(presenter.get_snapshot(), ["local_role", "ownership_text", "controlled_craft"])
		receipt["consumed_pose"] = _primitive_fields(_flight_pose_sample(), ["ship_id", "pose_tick", "pilot_peer_id", "operation_tick", "pose_active"])
		receipt["consumed_operation"] = _primitive_fields(_flight_pose_sample().get("operation_presentation", {}) as Dictionary, ["engine", "landed", "docked"])
		receipt["player_supported"] = _handback_body_supported(_player)
		receipt["player_local_position"] = _vector_values(_craft.to_local(_player.global_position))
		receipt["boarding_audit"] = _game.get_network_client_boarding_audit()
		receipt["saved_helm_source_present"] = (_game.get("_network_client_helm_input_sources") as Dictionary).has(_craft.get_instance_id())
		receipt["capture_callback_connected"] = is_instance_valid(_handback_ship_source) and _handback_capture.is_valid() \
			and _handback_ship_source.command_produced.is_connected(_handback_capture)
	return receipt


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	var handback := {"stage": _handback_stage, "start": _handback_start,
		"local": _handback_local, "authorized": _handback_authorized, "completed": _handback_completed,
		"walk_start": _handback_walk_start, "interact": Input.is_action_pressed(&"interact"),
		"move_back": Input.is_action_pressed(&"move_back")}
	if not _handback_start.is_empty() and is_instance_valid(_game) and is_instance_valid(_craft):
		handback["actual"] = _handback_receipt()
	snapshot["handback"] = handback
	return snapshot
