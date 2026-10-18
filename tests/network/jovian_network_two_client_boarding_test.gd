## test-matrix-display: input-only
extends "res://tests/network/halyard_network_passenger_route_test.gd"

## NET-JOVIAN-BOARD: one non-playing Main server, two independent Main clients.
## Client actors, poses, candidates and seat claims remain production-owned.
## The inherited coordinator owns private Xvfb peers and actual OS exit receipts.
const WALK_ACTIONS := [&"move_forward", &"move_back", &"move_left", &"move_right"]
const STATION_APPROACH := [
	Vector3(0.0, 0.0, 13.5), Vector3(-35.0, 0.0, 13.5),
	Vector3(-35.0, 0.0, 22.0), Vector3(-48.0, 0.0, 22.0),
	Vector3(-48.0, 0.38, 24.0), Vector3(-49.0, 0.38, 26.0),
	Vector3(-51.5, 0.38, 26.0), Vector3(-53.0, 0.38, 27.5),
	Vector3(-53.0, 0.38, 33.5), Vector3(-53.0, 0.38, 40.0),
	Vector3(-42.0, 0.38, 40.0),
]
var _walking_identity: Dictionary = {}
var _initial_player_id := 0
var _initial_peer_id := 0
var _initial_peer_generation := 0
var _first_failure_captured := false
const FAILURE_CAPTURE_GRACE_MSEC := 2000


func _peer_profile() -> Dictionary:
	return {"client_roles": ["client", "client_b"],
		"script": "res://tests/network/jovian_network_two_client_boarding_test.gd",
		"private_environment": true, "total_seconds": 300.0, "abort_exit_grace_seconds": 10.0}


func _print_peer_success() -> void:
	# Inherited caller invokes this only after every actual OS exit is zero and
	# every recorded actor PID is absent. No peer prints this suite marker.
	print("JOVIAN_NETWORK_TWO_CLIENT_BOARDING_OK checks=%d" % _checks)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		await _orchestrate()
		return
	_role = args[0]
	_directory = args[1]
	_port = int(args[2])
	_profile_deadline = Time.get_ticks_msec() + 300000
	_write(_role + ".script_ready", {"pid": OS.get_process_id(), "display": OS.get_environment("DISPLAY"),
		"data": OS.get_environment("XDG_DATA_HOME"), "config": OS.get_environment("XDG_CONFIG_HOME"),
		"cache": OS.get_environment("XDG_CACHE_HOME"), "runtime": OS.get_environment("XDG_RUNTIME_DIR"),
		"state": OS.get_environment("XDG_STATE_HOME"), "tmp": OS.get_environment("TMPDIR"),
		"wayland_display": OS.get_environment("WAYLAND_DISPLAY")})
	_game = Main.instantiate() as GameFlow
	_store_path = "user://jovian-boarding-peer.json"
	var store := UserDataStore.new(_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("JovianLightFreighter") as JovianLightFreighter
	_player = _game.get_node("Player") as PlayerController
	_initial_player_id = _player.get_instance_id()
	_write(_role + ".main_ready", {"pid": OS.get_process_id(), "player_id": str(_initial_player_id)})
	if _require(_game.hud is GameHUD and _game.phase == GameFlow.Phase.INTRO,
		"actual fresh Main starts at ordinary intro with its real HUD and player"):
		if _role == "host":
			await _host()
		else:
			await _client()
	await _retain_failure_before_teardown()
	# This cleanup always runs, including the first failed gameplay boundary.
	for action in WALK_ACTIONS + [&"interact", &"sprint_boost", &"ui_accept", &"fire"]:
		_action(action, false)
		Input.action_release(action)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	_game.shutdown_network_session(&"jovian_ordinary_boarding_done")
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	DirAccess.remove_absolute(_store_path)
	_write(_role + ".done", {"checks": _checks, "failures": _failures, "pid": OS.get_process_id()})
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _host() -> void:
	if not _require(_game.host_network_session(_port).accepted,
		"non-playing server starts existing production ENet session"):
		return
	if not _require(_game.phase == GameFlow.Phase.INTRO and not _player.is_seated()
		and not _player.is_control_enabled(), "server remains non-playing without a third crew claim"):
		return
	_write("host.ready", {"pid": OS.get_process_id(), "ship_id": str(_craft.get_ship_id())})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".main_ready", 60.0) or not await _wait_file(role + ".admitted", 20.0):
			return
	var first := _read("client.admitted")
	var second := _read("client_b.admitted")
	var first_peer := int(first.peer_id)
	var second_peer := int(second.peer_id)
	if not _require(first_peer > 1 and second_peer > 1 and first_peer != second_peer
		and int(first.pid) != int(second.pid) and int(first.pid) != OS.get_process_id()
		and int(second.pid) != OS.get_process_id() and _peer_generation(first_peer) == int(first.peer_generation)
		and _peer_generation(second_peer) == int(second.peer_generation)
		and _game.network_session.get_admitted_peer_ids().size() == 2,
		"same server authenticates two independent remote peer/generation identities"):
		return
	if not await _wait_file("client.cabin", 60.0):
		return
	if not _observe_supported_cabin("client", first_peer):
		return
	_write("host.client_body", {})
	if not await _wait_file("client.seated", 20.0):
		return
	if not await _boundary(func(): return _pilot_is_current(first_peer), 8.0,
		"server confirms first peer's exact pilot lease and authored physical seat publication"):
		return
	_write("host.pilot_seated", {})
	if not await _wait_file("client_b.cabin", 60.0):
		return
	if not _observe_supported_cabin("client_b", second_peer):
		return
	_write("host.client_b_body", {})
	if not await _wait_file("client_b.seated", 20.0):
		return
	if not await _boundary(func(): return _passenger_is_current(second_peer) and _pilot_is_current(first_peer),
		8.0, "same Jovian retains distinct confirmed pilot and physical passenger seats"):
		return
	var pilot := _publication(GameFlow.network_client_boarding_avatar_id(first_peer))
	var passenger := _publication(GameFlow.network_client_boarding_avatar_id(second_peer))
	var pilot_wire := pilot.get("wire", {}) as Dictionary
	var passenger_wire := passenger.get("wire", {}) as Dictionary
	if not _require(pilot.get("occupant") == _craft.get_pilot_seat_anchor()
		and passenger.get("occupant") != pilot.get("occupant")
		and passenger.get("ship") == _craft and pilot.get("ship") == _craft
		and int(pilot_wire.get("entity_generation", 0)) > 0 and int(passenger_wire.get("entity_generation", 0)) > 0
		and int(pilot_wire.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED
		and int(passenger_wire.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED
		and _peer_generation(first_peer) == int(first.peer_generation)
		and _peer_generation(second_peer) == int(second.peer_generation)
		and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated(),
		"authoritative generations, distinct seat entities and original remote identities remain current together"):
		return
	_write("host.seats_confirmed", {"pilot_peer": first_peer, "passenger_peer": second_peer,
		"pilot_entity_generation": int(pilot_wire.entity_generation),
		"passenger_entity_generation": int(passenger_wire.entity_generation), "ship_id": str(_craft.get_ship_id())})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".retained", 12.0):
			return
	if not _require(_pilot_is_current(first_peer) and _passenger_is_current(second_peer),
		"both normal-control client confirmations retain authoritative distinct seats"):
		return
	_write("host.release", {})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".leaving", 12.0):
			return
	_write("host.leaving", {})


func _client() -> void:
	if not await _button("IntroServerBrowserButton"):
		return
	(_game.hud.get("_server_browser_address") as LineEdit).text = "127.0.0.1"
	(_game.hud.get("_server_browser_port") as LineEdit).text = str(_port)
	(_game.hud.get("_server_browser_player_name") as LineEdit).text = "Jovian " + _role
	if not await _button("ServerBrowserManualJoinButton") or not await _boundary(_authenticated,
		20.0, "ordinary real HUD Manual Join authenticates this independent client"):
		return
	_initial_peer_id = _game.network_session.multiplayer.get_unique_id()
	var admitted := (_game.network_session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	_initial_peer_generation = int(admitted.get("peer_generation", 0))
	_write(_role + ".admitted", {"pid": OS.get_process_id(), "peer_id": _initial_peer_id,
		"peer_generation": _initial_peer_generation, "player_id": str(_initial_player_id)})
	if not await _button("ServerBrowserBackButton") or not await _button("IntroBeginShiftButton"):
		return
	if not await _boundary(func(): return (_game.phase == GameFlow.Phase.APPROACH_SHIP
		and _player.is_control_enabled() and _player.is_on_floor()), 5.0,
		"ordinary Begin Shift starts supported authored station spawn"):
		return
	var dismiss := _game.hud.find_child("RuntimeStatusDismissButton", true, false) as Button
	if dismiss != null and dismiss.is_visible_in_tree() and not dismiss.disabled:
		if not await _activate(dismiss):
			return
	var spawn: Transform3D = _game.world.get_player_spawn()
	if not _require(_player.global_position.distance_to(spawn.origin) < 0.8
		and _player.get_instance_id() == _initial_player_id, "same real Player begins at normal authored spawn"):
		return
	for target: Vector3 in STATION_APPROACH:
		if not await _walk_to(target, false):
			return
	var boarding := _craft.get_boarding_position()
	for target: Vector3 in [Vector3(-42.0, 0.38, boarding.z), boarding]:
		if not await _walk_to(target, false):
			return
	_write(_role + ".approached", {"position": str(_player.global_position)})
	if _role == "client_b" and not await _wait_file("host.pilot_seated", 60.0):
		return
	await _look(_craft.get_boarding_position() + Vector3.UP * 1.2)
	await _press(&"interact")
	if not await _boundary(_supported_cabin, 12.0,
		"ordinary hatch Interact admits supported production walking body and confirmed input stream"):
		return
	var source := _game.get_network_remote_body_intent_source()
	_walking_identity = {"peer_id": _initial_peer_id, "entity_id": str(source.get_entity_id()),
		"entity_generation": source.get_entity_generation(), "player_id": str(_initial_player_id)}
	_write(_role + ".cabin", _walking_identity)
	if not await _wait_file("host." + _role + "_body", 8.0):
		return
	if _role == "client":
		# This is the ship's authored standing approach, also used when a pilot
		# leaves the chair. It is a walking goal, never an assigned actor pose.
		if not await _walk_to((_craft as JovianLightFreighter).get_cabin_stand_transform().origin, true):
			return
		if not _require((_player.global_position - _craft.get_pilot_seat_anchor().global_position).slide(_craft.global_basis.y.normalized()).length()
			<= GameFlow.NETWORK_PILOT_SEAT_SWAP_REACH, "authored cabin standing approach reaches actual pilot chair before Interact"):
			return
		await _look(_craft.get_pilot_seat_anchor().global_position + _craft.global_basis.y.normalized() * 1.2)
		await _press(&"interact")
		if not await _boundary(_local_pilot_is_current, 12.0,
			"normal cockpit Interact confirms pilot seat through existing atomic authority swap"):
			return
	else:
		var contract := (_craft as JovianLightFreighter).get_passenger_station_role_contract()
		if not await _walk_to((contract.entry_transform as Transform3D).origin, true):
			return
		await _look((_craft as JovianLightFreighter).get_copilot_seat_anchor().global_position + _craft.global_basis.y.normalized() * 1.2)
		if not await _boundary(func(): return (_game.station_interaction_candidate is ShipCrewSeat
			and (_game.station_interaction_candidate as ShipCrewSeat).get_seat_anchor() == (_craft as JovianLightFreighter).get_copilot_seat_anchor()),
			5.0, "ordinary aim and cabin walk discover exact authored passenger chair"):
			return
		await _press(&"interact")
		if not await _boundary(_local_passenger_is_current, 8.0,
			"normal passenger chair Interact physically seats same Player after host confirmation"):
			return
	_write(_role + ".seated", _walking_identity)
	if not await _wait_file("host.seats_confirmed", 60.0):
		return
	var both := _read("host.seats_confirmed")
	if not _require(_same_identity() and _player.get_instance_id() == _initial_player_id
		and (_local_pilot_is_current() if _role == "client" else _local_passenger_is_current())
		and str(both.get("ship_id", "")) == str(_craft.get_ship_id())
		and int(both.get("pilot_peer", 0)) != int(both.get("passenger_peer", 0)),
		"same authenticated Player retains confirmed seat, honest ownership UI and normal controls beside other client"):
		return
	_write(_role + ".retained", {})
	if not await _wait_file("host.release", 12.0):
		return
	_write(_role + ".leaving", {})
	await _wait_file("host.leaving", 12.0)


func _observe_supported_cabin(role: String, peer: int) -> bool:
	var receipt := _read(role + ".cabin")
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var record := simulation.get_body_record(avatar)
	return _require(body != null and body.is_on_floor() and not body.is_seated()
		and int(record.get("owner_peer_id", 0)) == peer
		and int(record.get("entity_generation", 0)) == int(receipt.get("entity_generation", -1))
		and str(receipt.get("entity_id", "")) == str(avatar)
		and body.get_cabin_containment_report().get("frame") == _craft,
		"server observes supported real remote body with same admitted peer/entity generation: " + role)


func _publication(avatar: StringName) -> Dictionary:
	return (_game.get("_network_moving_interior_records") as Dictionary).get(avatar, {})


func _pilot_is_current(peer: int) -> bool:
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var publication := _publication(avatar)
	var wire := publication.get("wire", {}) as Dictionary
	var initial := _read("client.cabin")
	var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.get_ship_id(), {}) as Dictionary
	var occupancy := false
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == peer and held.get("avatar_id") == avatar \
			and held.get("ship_id") == _craft.get_ship_id() and held.get("role") == &"pilot" \
			and held.get("seat_id") == StringName("%s_pilot" % _craft.get_ship_id()):
			occupancy = true
	return occupancy and _craft.is_remote_piloted() and int(remote.get("peer_id", 0)) == peer \
		and publication.get("occupant") == _craft.get_pilot_seat_anchor() and bool(publication.get("seated", false)) \
		and int(publication.get("remote_pilot_peer_id", 0)) == peer and int(publication.get("owner_peer_id", 0)) == peer \
		and wire.get("entity_id") == avatar and int(wire.get("entity_generation", 0)) == int(initial.get("entity_generation", -1)) \
		and int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED \
		and int(publication.get("published_tick", -1)) > 0


func _passenger_is_current(peer: int) -> bool:
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if body == null or owner == null:
		return false
	var assignment: Dictionary = owner.get_assignment(peer, avatar)
	var seat := simulation.get_body_crew_seat(avatar)
	var identity := _read("client_b.cabin")
	var publication := _publication(avatar)
	return body.is_seated_at((_craft as JovianLightFreighter).get_copilot_seat_anchor()) \
		and seat != null and seat.get_seat_anchor() == (_craft as JovianLightFreighter).get_copilot_seat_anchor() \
		and assignment.get("role") == &"passenger" and assignment.get("seat_id") == JovianLightFreighter.COPILOT_SEAT_ID \
		and int(assignment.get("seat_generation", 0)) > 0 and int(assignment.get("claim_sequence", 0)) > 0 \
		and int(simulation.get_body_record(avatar).get("entity_generation", 0)) == int(identity.get("entity_generation", -1)) \
		and publication.get("occupant") == body and int(publication.get("owner_peer_id", 0)) == peer \
		and int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED \
		and int(publication.get("published_tick", -1)) > 0


func _local_pilot_is_current() -> bool:
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	var source := _craft.get_local_input_source()
	return _same_identity() and not _game.get("_transition_busy") and _player.is_seated_at(_craft.get_pilot_seat_anchor()) \
		and bool(_game.get("_piloting")) and claim.get("role") == &"pilot" and claim.get("ship_id") == _craft.get_ship_id() \
		and claim.get("avatar_id") == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and _hud_role_is_current(&"pilot") and source != null \
		and source.is_enabled_owner() and source.get_authority_peer_id() == _initial_peer_id


func _local_passenger_is_current() -> bool:
	var view := _game.network_session.get_passenger_replica_snapshot()
	var assignment := view.get("assignment", {}) as Dictionary
	return _same_identity() and not _game.get("_transition_busy") \
		and _player.is_seated_at((_craft as JovianLightFreighter).get_copilot_seat_anchor()) \
		and _player.is_station_seated() and _player.is_control_enabled() and not bool(_game.get("_piloting")) \
		and bool(view.get("seated", false)) and view.get("ship_id") == _craft.get_ship_id() \
		and assignment.get("seat_id") == JovianLightFreighter.COPILOT_SEAT_ID \
		and int(assignment.get("seat_generation", 0)) > 0 and int(assignment.get("claim_sequence", 0)) > 0 \
		and _hud_role_is_current(&"passenger") and _objective_text().contains("PASSENGER ABOARD") \
		and _craft.get_crew_role_authority() == null and _game.get("_network_engineer_source") == null


func _hud_role_is_current(role: StringName) -> bool:
	# Read the actual HUD presenter's consumed snapshot, not a freshly computed
	# GameFlow role. Rendering/pixel visibility is outside this input-only suite.
	var presenter := _game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
	var snapshot := presenter.get_snapshot()
	return snapshot.get("local_role") == role and str(snapshot.get("ownership_text", "")) == str(role).to_upper() \
		and str(snapshot.get("controlled_craft", "")) == _craft.get_display_name()


func _supported_cabin() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and not _game.get("_transition_busy") \
		and _player.is_control_enabled() and _player.is_on_floor() and source != null and source.is_bound() \
		and bool(source.get_audit().get("opening_confirmed", false))


func _authenticated() -> bool:
	var session := _game.network_session
	if not is_instance_valid(session) or not session.is_session_active():
		return false
	var offer := session.get_server_offer()
	var admission := offer.get("admission", {}) as Dictionary
	var peer := admission.get("peer", {}) as Dictionary
	var transport := offer.get("transport", {}) as Dictionary
	var epoch := (offer.get("migration", {}) as Dictionary).get("epoch", {}) as Dictionary
	var current := session.get_migration_snapshot()
	var identity := session.multiplayer.get_unique_id()
	if not bool(admission.get("accepted", false)) or identity <= 1 or int(peer.get("peer_id", 0)) != identity \
		or int(peer.get("peer_generation", 0)) <= 0 or int(transport.get("peer_id", 0)) != identity \
		or int(transport.get("peer_generation", 0)) != int(peer.get("peer_generation", 0)) \
		or str(transport.get("auth_token", "")).is_empty():
		return false
	for key in ["package_generation", "session_generation", "migration_generation"]:
		if int(epoch.get(key, 0)) <= 0 or epoch.get(key) != current.get(key):
			return false
	return true


func _same_identity() -> bool:
	var peer := ((_game.network_session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary)
	return _authenticated() and _game.network_session.multiplayer.get_unique_id() == _initial_peer_id \
		and int(peer.get("peer_generation", 0)) == _initial_peer_generation


func _peer_generation(peer_id: int) -> int:
	for peer: Dictionary in (_game.network_session.get_snapshot().get("lifecycle", {}) as Dictionary).get("peers", []):
		if int(peer.get("peer_id", 0)) == peer_id:
			return int(peer.get("peer_generation", 0))
	return 0


func _walk_to(target: Vector3, cabin: bool) -> bool:
	await _look(target + Vector3.UP * 1.4)
	var deadline := Time.get_ticks_msec() + 15000
	var settled := 0
	while Time.get_ticks_msec() < deadline and not _aborted():
		var delta := (target - _player.global_position).slide(Vector3.UP)
		var authoritative_delta := delta
		var current := true
		if cabin:
			var source := _game.get_network_remote_body_intent_source()
			current = source != null and source.is_bound() and source.get_entity_id() == StringName(_walking_identity.entity_id) \
				and source.get_entity_generation() == int(_walking_identity.entity_generation)
			if current:
				var latest := _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id())
				current = int(latest.get("entity_generation", 0)) == source.get_entity_generation() \
					and latest.get("parent_frame_id") == StringName("frame_%s" % _craft.get_ship_id())
				var pose := latest.get("frame_local_transform", Transform3D.IDENTITY) as Transform3D
				authoritative_delta = (target - _craft.to_global(pose.origin)).slide(Vector3.UP)
		if delta.length() <= 0.30 and current and authoritative_delta.length() <= 0.30:
			_release_walk()
			await _ticks(1)
			settled = settled + 1 if _player.is_on_floor() and _player.velocity.slide(Vector3.UP).length() < 0.1 else 0
			if settled >= 15:
				print("JOVIAN_ORDINARY_WAYPOINT: role=", _role, " target=", target, " actual=", _player.global_position)
				return _require(absf(target.y - _player.global_position.y) < 0.8 and _same_identity()
					and _player.get_instance_id() == _initial_player_id, "ordinary supported continuous walk reaches goal: " + str(target))
			continue
		settled = 0
		if cabin and current:
			delta = (delta + authoritative_delta) * 0.5
		var forward := (-_player.get_camera().global_basis.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var axis := Vector2(delta.normalized().dot(right), -delta.normalized().dot(forward))
		axis *= clampf(delta.length() / 1.5, 0.35, 1.0)
		for action in WALK_ACTIONS:
			_action(action, false)
		_action(&"move_left" if axis.x < 0.0 else &"move_right", true, absf(axis.x))
		_action(&"move_forward" if axis.y < 0.0 else &"move_back", true, absf(axis.y))
		await _ticks(1)
	_release_walk()
	print("JOVIAN_ORDINARY_WALK_STOP: role=", _role, " target=", target, " actual=", _player.global_position,
		" floor=", _player.is_on_floor(), " velocity=", _player.velocity, " phase=", _game.phase)
	return _require(false, "ordinary walk reaches supported goal within existing bounded route: " + str(target))


func _release_walk() -> void:
	for action in WALK_ACTIONS:
		_action(action, false)


func _look(target: Vector3) -> void:
	for _index in 4:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			Input.parse_input_event(click)
			await _ticks(1)
			click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = false
			Input.parse_input_event(click)
		var desired := _player.global_basis.inverse() * (target - _player.get_interaction_origin()).normalized()
		var current := _player.global_basis.inverse() * _player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _player.invert_mouse_y else -1.0)) / _player.mouse_sensitivity
		Input.parse_input_event(event)
		await _ticks(1)


func _action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)


func _press(action: StringName) -> void:
	_action(action, true)
	await _ticks(2)
	_action(action, false)
	await _ticks(3)


## Reused real-HUD focus/ui_accept pattern from the live browser integration.
func _button(node_name: String) -> bool:
	if not await _boundary(func():
		var button := _game.hud.find_child(node_name, true, false) as Button
		return button != null and button.is_visible_in_tree() and not button.disabled,
		5.0, "visible enabled HUD action: " + node_name):
		return false
	return await _activate(_game.hud.find_child(node_name, true, false) as Button)


func _activate(button: Button) -> bool:
	root.grab_focus()
	button.grab_focus()
	await process_frame
	if not _require(root.gui_get_focus_owner() == button, "actual HUD button receives keyboard/controller focus"):
		return false
	var activated := [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	_action(&"ui_accept", true)
	await process_frame
	_action(&"ui_accept", false)
	await process_frame
	return await _boundary(func(): return activated[0], 5.0, "focused ui_accept activates real HUD Button")


func _require(condition: bool, description: String) -> bool:
	_check(condition, description)
	if not condition and not _role.is_empty() and not _first_failure_captured:
		_first_failure_captured = true
		# mkdir is exclusive across the three processes; an exists-then-write
		# check would let a cascading peer replace the original shared abort.
		var first_abort: bool = DirAccess.make_dir_absolute(_directory.path_join("abort-owner")) == OK
		_write(_role + ".first_failure", _failure_snapshot(description))
		if first_abort:
			_write("abort", {"role": _role, "description": description,
				"snapshot": _role + ".first_failure"})
	return condition


func _retain_failure_before_teardown() -> void:
	if _failures.is_empty():
		return
	# Failure-only observation barrier: A keeps its connection alive until the
	# host has captured the lease/publication, before shutdown can retire them.
	# This is inside the profile's existing 10s actual-exit grace, and ignores
	# gameplay abort/deadline. It never changes a route or success-path wait.
	var deadline: int = Time.get_ticks_msec() + FAILURE_CAPTURE_GRACE_MSEC
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_directory.path_join("host.first_failure")) \
			and FileAccess.file_exists(_directory.path_join("client.first_failure")) \
			and FileAccess.file_exists(_directory.path_join("client_b.first_failure")):
			return
		await _ticks(1)
	_write(_role + ".failure_capture_grace_elapsed", {"host_captured": FileAccess.file_exists(_directory.path_join("host.first_failure")),
		"client_captured": FileAccess.file_exists(_directory.path_join("client.first_failure")),
		"client_b_captured": FileAccess.file_exists(_directory.path_join("client_b.first_failure"))})


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot: Dictionary = {"role": _role, "description": description, "pid": OS.get_process_id(),
		"wall": Time.get_unix_time_from_system(), "ticks": Engine.get_physics_frames(),
		"profile_deadline_reached": _profile_deadline > 0 and Time.get_ticks_msec() >= _profile_deadline,
		"shared_abort_at_capture": _primitive_fields(_read("abort"), ["role", "description", "snapshot"])}
	if not is_instance_valid(_game) or not is_instance_valid(_craft) or not is_instance_valid(_player):
		snapshot["missing_fact"] = "Main, craft or Player is unavailable before failure capture"
		return snapshot
	# All observations below read retained fields or proven-pure getters.
	# In particular, get_local_input_source()/get_command_source() ensure a
	# producer, and get_pilot_seat_anchor() can build the ship: never call them.
	snapshot["local_pilot"] = _local_pilot_failure_state()
	if _role == "host":
		snapshot["host_pilot"] = _host_pilot_failure_state()
	return snapshot


func _primitive_fields(record: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key: String in keys:
		if record.has(key) and typeof(record[key]) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			result[key] = record[key]
	return result


func _node_identity(node: Node) -> Dictionary:
	if not is_instance_valid(node):
		return {"valid": false}
	return {"valid": true, "instance_id": str(node.get_instance_id()), "path": str(node.get_path())}


func _producer_state(source: ShipCommandSource) -> Dictionary:
	if not is_instance_valid(source):
		return {"present": false}
	# ShipCommandSource ownership getters only read enabled, the override, the
	# MultiplayerAPI identity and Node authority; none samples/resets input.
	var script: Script = source.get_script() as Script
	return {"present": true, "identity": _node_identity(source),
		"type": script.resource_path if script != null else source.get_class(),
		"is_local_input_source": source is LocalShipInputSource, "enabled": source.enabled,
		"local_peer_id": source.get_local_peer_id(), "authority_peer_id": source.get_authority_peer_id(),
		"enabled_owner": source.is_enabled_owner()}


func _local_pilot_failure_state() -> Dictionary:
	var claim: Dictionary = _game.get("_network_client_boarding_claim") as Dictionary
	var anchor: Node3D = _craft.get("_pilot_seat_anchor") as Node3D
	var seat: Node3D = _player.get("_seat_anchor") as Node3D
	var source: ShipCommandSource = _craft.get("_default_local_command_source") as ShipCommandSource
	var active_source: ShipCommandSource = _craft.get("_command_source") as ShipCommandSource
	var producer: Dictionary = _producer_state(source)
	var hud: Dictionary = {}
	if is_instance_valid(_game.hud):
		var presenter: NetworkSessionStatusPresenter = _game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
		if presenter != null:
			# get_snapshot() only duplicates the presenter's already consumed map.
			hud = presenter.get_snapshot()
	var auth: Dictionary = _authentication_failure_state()
	var conditions: Dictionary = {"same_identity": bool(auth.get("same_identity", false)),
		"transition_idle": not bool(_game.get("_transition_busy")),
		"player_seated_at_pilot_anchor": _player.is_seated_at(anchor),
		"piloting": bool(_game.get("_piloting")), "claim_role_pilot": claim.get("role") == &"pilot",
		"claim_ship_matches": claim.get("ship_id") == _craft.ship_id,
		"claim_avatar_matches": claim.get("avatar_id") == GameFlow.network_client_boarding_avatar_id(_initial_peer_id),
		"hud_role_pilot": hud.get("local_role") == &"pilot",
		"hud_ownership_pilot": str(hud.get("ownership_text", "")) == "PILOT",
		"hud_controlled_craft_matches": str(hud.get("controlled_craft", "")) == _craft.display_name,
		"source_present": source != null, "source_enabled_owner": bool(producer.get("enabled_owner", false)),
		"source_authority_matches": source != null and int(producer.get("authority_peer_id", 0)) == _initial_peer_id}
	return {"conditions": conditions, "predicate_current": _all_conditions(conditions), "authentication": auth,
		"phase": _game.phase, "transition_busy": bool(_game.get("_transition_busy")), "piloting": bool(_game.get("_piloting")),
		"player": _node_identity(_player), "initial_player_id": str(_initial_player_id),
		"same_player_instance": _player.get_instance_id() == _initial_player_id,
		"embodiment_state": int(_player.get("_embodiment_state")), "seated": _player.is_seated(),
		"station_seated": _player.is_station_seated(), "control_enabled": _player.is_control_enabled(),
		"actual_seat_anchor": _node_identity(seat), "pilot_seat_anchor": _node_identity(anchor),
		"transition_elapsed": float(_player.get("_transition_elapsed")), "transition_duration": float(_player.get("_transition_duration")),
		"claim": _primitive_fields(claim, ["ship_id", "seat_id", "role", "avatar_id", "peer_id", "peer_generation", "seat_generation", "claim_sequence"]),
		"claim_avatar_present": claim.has("avatar_id"),
		"consumed_hud": _primitive_fields(hud, ["local_role", "ownership_text", "controlled_craft"]),
		"local_producer": producer, "active_producer": _producer_state(active_source),
		"local_producer_is_active": source != null and source == active_source}


func _authentication_failure_state() -> Dictionary:
	var session: NetworkEnetSessionAdapter = _game.network_session
	if not is_instance_valid(session):
		return {"same_identity": false, "missing_fact": "network_session is unavailable"}
	# The offer getter is a detached copy; migration's getter only builds and
	# duplicates a map. Select fields explicitly so auth tokens never serialize.
	var offer: Dictionary = session.get_server_offer()
	var admission: Dictionary = offer.get("admission", {}) as Dictionary
	var peer: Dictionary = admission.get("peer", {}) as Dictionary
	var transport: Dictionary = offer.get("transport", {}) as Dictionary
	var epoch: Dictionary = (offer.get("migration", {}) as Dictionary).get("epoch", {}) as Dictionary
	var current: Dictionary = session.get_migration_snapshot()
	var identity: int = session.multiplayer.get_unique_id()
	var conditions: Dictionary = {"session_active": session.is_session_active(),
		"admission_accepted": bool(admission.get("accepted", false)), "peer_id_remote": identity > 1,
		"admission_peer_matches": int(peer.get("peer_id", 0)) == identity,
		"admission_generation_positive": int(peer.get("peer_generation", 0)) > 0,
		"transport_peer_matches": int(transport.get("peer_id", 0)) == identity,
		"transport_generation_matches": int(transport.get("peer_generation", 0)) == int(peer.get("peer_generation", 0)),
		"transport_token_present": not str(transport.get("auth_token", "")).is_empty()}
	for key: String in ["package_generation", "session_generation", "migration_generation"]:
		conditions[key + "_positive_current"] = int(epoch.get(key, 0)) > 0 and epoch.get(key) == current.get(key)
	var authenticated: bool = _all_conditions(conditions)
	conditions["peer_id_initial_matches"] = identity == _initial_peer_id
	conditions["peer_generation_initial_matches"] = int(peer.get("peer_generation", 0)) == _initial_peer_generation
	return {"conditions": conditions, "authenticated": authenticated, "same_identity": _all_conditions(conditions),
		"local_peer_id": identity, "initial_peer_id": _initial_peer_id, "initial_peer_generation": _initial_peer_generation,
		"admitted_peer": _primitive_fields(peer, ["peer_id", "peer_generation"]),
		"transport": _primitive_fields(transport, ["peer_id", "peer_generation"]),
		"offered_epoch": _primitive_fields(epoch, ["package_generation", "session_generation", "migration_generation"]),
		"current_epoch": _primitive_fields(current, ["package_generation", "session_generation", "migration_generation"])}


func _all_conditions(conditions: Dictionary) -> bool:
	for value: bool in conditions.values():
		if not value:
			return false
	return true


func _host_pilot_failure_state() -> Dictionary:
	var admitted: Dictionary = _read("client.admitted")
	var peer: int = int(admitted.get("peer_id", 0))
	var avatar: StringName = GameFlow.network_client_boarding_avatar_id(peer)
	var initial: Dictionary = _read("client.cabin")
	var publication: Dictionary = _publication(avatar)
	var wire: Dictionary = publication.get("wire", {}) as Dictionary
	var anchor: Node3D = _craft.get("_pilot_seat_anchor") as Node3D
	var remote: Dictionary = (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
	var occupancies: Array = []
	var occupancy: bool = false
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == peer:
			occupancies.append(_primitive_fields(held, ["peer_id", "avatar_id", "ship_id", "ship_generation", "frame_id", "frame_generation", "role", "seat_id", "seat_generation", "claim_sequence"]))
			if held.get("avatar_id") == avatar and held.get("ship_id") == _craft.ship_id \
				and held.get("role") == &"pilot" and held.get("seat_id") == StringName("%s_pilot" % _craft.ship_id):
				occupancy = true
	var conditions: Dictionary = {"exact_pilot_occupancy": occupancy, "craft_remote_piloted": _craft.is_remote_piloted(),
		"remote_peer_matches": int(remote.get("peer_id", 0)) == peer,
		"publication_occupant_is_pilot_anchor": publication.get("occupant") == anchor,
		"publication_seated": bool(publication.get("seated", false)),
		"publication_remote_peer_matches": int(publication.get("remote_pilot_peer_id", 0)) == peer,
		"publication_owner_matches": int(publication.get("owner_peer_id", 0)) == peer,
		"wire_entity_matches": wire.get("entity_id") == avatar,
		"wire_generation_matches": int(wire.get("entity_generation", 0)) == int(initial.get("entity_generation", -1)),
		"published_state_seated": int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED,
		"published_tick_positive": int(publication.get("published_tick", -1)) > 0}
	return {"conditions": conditions, "predicate_current": _all_conditions(conditions),
		"admitted_peer": _primitive_fields(admitted, ["peer_id", "peer_generation"]),
		"current_peer_generation": int((_game.network_session.get("_peer_generations") as Dictionary).get(peer, 0)),
		"walking_identity": _primitive_fields(initial, ["peer_id", "entity_id", "entity_generation", "player_id"]),
		"pilot_occupancies": occupancies, "remote_binding_peer": int(remote.get("peer_id", 0)),
		"remote_binding_craft": _node_identity(remote.get("craft") as Node),
		"remote_producer": _producer_state(remote.get("source") as ShipCommandSource),
		"craft_piloted": bool(_craft.get("_piloted")), "craft_remote_piloted": bool(_craft.get("_remote_piloted")),
		"publication": _primitive_fields(publication, ["entity_id", "generation", "frame_id", "owner_peer_id", "seated", "remote_pilot_peer_id", "server_simulated", "registered", "published_state", "published_tick", "seen_tick"]),
		"publication_occupant": _node_identity(publication.get("occupant") as Node),
		"wire": _primitive_fields(wire, ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state", "server_tick", "sequence"])}


func _boundary(predicate: Callable, seconds: float, description: String) -> bool:
	return _require(await _until(predicate, seconds), description)


func _aborted() -> bool:
	return FileAccess.file_exists(_directory.path_join("abort")) \
		or (_profile_deadline > 0 and Time.get_ticks_msec() >= _profile_deadline)


func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		if (_profile_deadline > 0 or not _role.is_empty()) and _aborted():
			return false
		await _ticks(1)
	return false


func _wait_file(name: String, seconds: float) -> bool:
	# Exit receipts are independent of gameplay aborts and .done receipts.
	if name.ends_with(".exit"):
		var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
		while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(_directory.path_join(name)):
			await _ticks(1)
		return _require(FileAccess.file_exists(_directory.path_join(name)), "actual owned OS exit receipt: " + name)
	return await _boundary(func(): return FileAccess.file_exists(_directory.path_join(name)), seconds,
		"peer boundary arrives: " + name)
