## test-matrix-display: input-only
extends "res://tests/network/jovian_network_engineer_route_test.gd"

## NET-JOVIAN-PASSENGER component regression, not NET-JOVIAN-BOARD qualification.
## Reuses the independent Main/ENet/OS-exit harness. Only each exterior approach
## is staged; real cabin movement and Interact drive the authenticated body.
## The inherited look helper dispatches mouse events to Player._unhandled_input;
## this component fixture does not qualify viewport mouse routing.
## No pilot flight, two-client ordinary-spawn route, or hardware claim is made.
var _component_deadline := 0


func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var args := super._peer_arguments(role, display)
	var script_index := args.find("--script") + 1
	args[script_index] = args[script_index].get_base_dir().path_join("jovian_network_passenger_seat_test.gd")
	var renderer := args.find("--rendering-method")
	if renderer >= 0:
		args[renderer] = "--rendering-driver"
		args[renderer + 1] = "dummy"
	return args


func _orchestrate() -> void:
	await super._orchestrate()
	if _failures.is_empty():
		print("JOVIAN_NETWORK_PASSENGER_SEAT_OK checks=%d" % _checks)


func _host() -> void:
	_component_deadline = Time.get_ticks_msec() + 110000
	_player.set_control_enabled(false)
	if not _require(_game.host_network_session(_port).accepted, "component host starts production ENet"):
		return
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if not _require(owner != null and owner == _game._network_engineer_binding.authority, "Jovian retains exactly its existing engineer/passenger roster"):
		return
	_write("host.ready", {})
	if not await _wait_file("client.approached", 45.0):
		return
	var client := _read("client.approached")
	var peer := int(client.peer_id)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var seat := _craft.get_copilot_seat_anchor().get_node("SoloPassengerSeatInteraction") as ShipCrewSeat
	if not await _boundary(func(): return body != null and body.is_on_floor() and seat in body.get_nearby_interactables(),
		5.0, "actual admitted supported body overlaps authored passenger discovery"):
		return
	var generation := int(simulation.get_body_record(avatar).entity_generation)
	var record := {"body": body, "owner_peer_id": peer, "entity_id": avatar, "entity_generation": generation,
		"craft": _craft, "frame": _craft.get_moving_interior_component()}
	var foreign := PlayerController.new()
	var wrong := record.duplicate()
	wrong.body = foreign
	_require(not _game._network_engineer_binding.claim(wrong, seat).accepted, "unregistered body cannot claim physical passenger chair")
	foreign.free()
	wrong = record.duplicate()
	wrong.owner_peer_id = 1
	_require(not _game._network_engineer_binding.claim(wrong, seat).accepted, "unadmitted owner cannot claim remote passenger chair")
	wrong = record.duplicate()
	wrong.entity_generation = generation + 1
	_require(not _game._network_engineer_binding.claim(wrong, seat).accepted, "stale entity generation cannot claim passenger chair")
	wrong = record.duplicate()
	wrong.entity_id = &"foreign_passenger"
	_require(not _game._network_engineer_binding.claim(wrong, seat).accepted, "foreign avatar cannot borrow the admitted body")
	if not _require(owner.get_assignment(peer, avatar).is_empty(), "refused claims leave the shared roster empty"):
		return
	_write("host.allow_sit", {})
	if not await _wait_file("client.seated", 12.0):
		return
	var assignment := owner.get_assignment(peer, avatar)
	if not _require(body.is_seated_at(_craft.get_copilot_seat_anchor()) and simulation.get_body_crew_seat(avatar) == seat \
		and assignment.get("role") == &"passenger" and assignment.get("seat_id") == JovianLightFreighter.COPILOT_SEAT_ID \
		and int(assignment.get("seat_generation", 0)) > 0 and int(assignment.get("claim_sequence", 0)) > 0,
		"one ordinary press confirms exact passenger chair and real host body"):
		return
	var claim := int(assignment.claim_sequence)
	await _ticks(12)
	if not _require(owner.get_assignment(peer, avatar) == assignment and _craft.get_crew_role_authority() == owner,
		"neutral movement packets retain one claim on the same roster"):
		return
	_write("host.seat_checked", {})
	if not await _wait_file("client.stood", 10.0):
		return
	if not await _boundary(func(): return not body.is_seated() and body.is_on_floor() and owner.get_assignment(peer, avatar).is_empty(),
		5.0, "normal stand releases exact passenger role and restores supported host body"):
		return
	_write("host.stand_checked", {})
	if not await _wait_file("client.reseated", 10.0):
		return
	if not _require(body.is_seated_at(_craft.get_copilot_seat_anchor()) and int(owner.get_assignment(peer, avatar).get("claim_sequence", 0)) > claim,
		"normal reseat obtains a fresh claim through the retained physical body"):
		return
	if not _require(_game.network_session.rotate_session_migration().accepted, "real migration rotates while passenger is physically seated"):
		return
	if not await _boundary(func(): return owner.get_assignment(peer, avatar).is_empty() and not body.is_seated() and body.is_on_floor(),
		8.0, "migration releases passenger and restores supported same-body standing"):
		return
	_write("host.migrated", {})
	if not await _wait_file("client.disconnect_seated", 16.0):
		return
	if not _require(body.is_seated_at(_craft.get_copilot_seat_anchor()) and not owner.get_assignment(peer, avatar).is_empty() \
		and simulation.get_body(avatar) == body and int(simulation.get_body_record(avatar).entity_generation) == generation,
		"post-migration authenticated rebind seats the same body before disconnect"):
		return
	_write("host.disconnect_ready", {})
	if not await _wait_file("client.disconnected", 8.0):
		return
	if not await _boundary(func(): return simulation.get_body(avatar) == null and owner.get_assignment(peer, avatar).is_empty(),
		5.0, "disconnect retires occupied passenger chair and actual remote body"):
		return
	_write("host.disconnected_checked", {})
	# A new actual Main/session admission exercises destruction separately from
	# the preceding occupied disconnect; no test-created body or chair claim.
	if not await _wait_file("client.death_seated", 30.0):
		return
	var death_peer := int(_read("client.death_seated").peer_id)
	var death_avatar := GameFlow.network_client_boarding_avatar_id(death_peer)
	var death_body := simulation.get_body(death_avatar)
	if not _require(not owner.get_assignment(death_peer, death_avatar).is_empty() \
		and death_body != null and death_body.is_seated_at(_craft.get_copilot_seat_anchor()), "fresh admitted body occupies passenger chair at destruction"):
		return
	_craft.apply_damage(_craft.maximum_hull + 1.0, _craft.global_position, Vector3.UP)
	if not await _boundary(func(): return _craft.is_destroyed() and owner.get_assignment(death_peer, death_avatar).is_empty(),
		5.0, "actual hull destruction releases occupied passenger role"):
		return
	_write("host.destroyed_checked", {})
	if not await _wait_file("client.death_recovered", 10.0):
		return
	_game.shutdown_network_session(&"passenger_component_host_done")
	_require(_craft.get_crew_role_authority() == null and owner.get_snapshot().get("assignments", []).is_empty(),
		"teardown detaches the one empty Jovian roster")


func _client() -> void:
	_component_deadline = Time.get_ticks_msec() + 110000
	if not await _join_and_approach():
		return
	_write("client.approached", {"peer_id": _game.network_session.multiplayer.get_unique_id()})
	if not await _wait_file("host.allow_sit", 8.0) or not await _sit():
		return
	_write("client.seated", {})
	if not await _wait_file("host.seat_checked", 8.0):
		return
	await _press(&"interact")
	if not await _boundary(func(): return not _player.is_seated() and not _game._transition_busy and _player.is_on_floor() and _player.is_control_enabled(),
		8.0, "normal passenger stand receives host release and supported client controls"):
		return
	_write("client.stood", {})
	if not await _wait_file("host.stand_checked", 8.0) or not await _sit():
		return
	_write("client.reseated", {})
	if not await _wait_file("host.migrated", 12.0):
		return
	if not await _boundary(func(): return not _player.is_seated() and not _game._transition_busy and _player.is_on_floor() \
		and _player.is_control_enabled() and _authenticated() and _game.get_network_remote_body_intent_source() != null \
		and _game.get_network_remote_body_intent_source().is_bound() \
		and bool(_game.get_network_remote_body_intent_source().get_audit().get("opening_confirmed", false)),
		10.0, "migration rebind restores authenticated client body and controls") or not await _sit():
		return
	_write("client.disconnect_seated", {})
	if not await _wait_file("host.disconnect_ready", 8.0):
		return
	_game.shutdown_network_session(&"passenger_component_occupied_disconnect")
	if not _require(not _player.is_seated() and _player.is_control_enabled(), "occupied disconnect restores local playable body"):
		return
	_write("client.disconnected", {})
	if not await _wait_file("host.disconnected_checked", 8.0):
		return
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	_game = Main.instantiate() as GameFlow
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("JovianLightFreighter")
	_player = _game.get_node("Player") as PlayerController
	_game.start_shift() # Explicit component setup for the separate death case.
	await _ticks(3)
	if not await _join_and_approach() or not await _sit():
		return
	_write("client.death_seated", {"peer_id": _game.network_session.multiplayer.get_unique_id()})
	if not await _wait_file("host.destroyed_checked", 8.0):
		return
	if not await _boundary(func(): return not _player.is_seated() and _player.is_control_enabled() and not _game._transition_busy,
		8.0, "destroyed passenger chair cannot retain seated client controls"):
		return
	_write("client.death_recovered", {})


func _join_and_approach() -> bool:
	if not _require(_game.join_network_session("127.0.0.1", _port).accepted, "component client joins real session") \
		or not await _boundary(_authenticated, 15.0, "client receives current authenticated peer/generation offer"):
		return false
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(10)
	await _press(&"interact")
	if not await _boundary(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN \
		and _game.get_network_remote_body_intent_source() != null and not _game._transition_busy \
		and _game.get_network_remote_body_intent_source().is_bound() \
		and bool(_game.get_network_remote_body_intent_source().get_audit().get("opening_confirmed", false)) \
		and _player.is_control_enabled() and _player.is_on_floor(), 12.0, "normal hatch admits production walking body from staged component approach"):
		return false
	await _walk(_craft.to_local(_craft.get_passenger_station_role_contract().entry_transform.origin))
	await _look(_craft.get_copilot_seat_anchor().global_position + _craft.global_basis.y.normalized() * 1.2)
	return await _boundary(func(): return _player.is_on_floor() and _game.station_interaction_candidate is ShipCrewSeat \
		and (_game.station_interaction_candidate as ShipCrewSeat).get_seat_anchor() == _craft.get_copilot_seat_anchor(),
		5.0, "ordinary supported cabin walk discovers exact authored passenger chair")


func _sit() -> bool:
	await _look(_craft.get_copilot_seat_anchor().global_position + _craft.global_basis.y.normalized() * 1.2)
	await _press(&"interact")
	if not await _boundary(func(): return _player.is_seated_at(_craft.get_copilot_seat_anchor()) and not _game._transition_busy,
		8.0, "ordinary passenger Interact sits only after actual host confirmation"):
		return false
	var view := _game.network_session.get_passenger_replica_snapshot()
	return _require(bool(view.get("seated", false)) and view.get("ship_id") == _craft.get_ship_id() \
		and (view.get("assignment", {}) as Dictionary).get("seat_id") == JovianLightFreighter.COPILOT_SEAT_ID \
		and _game._network_local_role_presentation().local_role == &"passenger" \
		and _player.is_station_seated() and _player.is_control_enabled() and not _craft.is_piloted() \
		and _craft.get_crew_role_authority() == null and _game._network_engineer_source == null,
		"confirmed passenger replica gives honest role UI and usable controls without helm or second authority")


func _authenticated() -> bool:
	var session := _game.network_session
	var admission := session.get_server_offer().get("admission", {}) as Dictionary
	var peer := admission.get("peer", {}) as Dictionary
	return session.is_session_active() and bool(admission.get("accepted", false)) \
		and int(peer.get("peer_id", 0)) == session.multiplayer.get_unique_id() and int(peer.get("peer_generation", 0)) > 0


func _require(condition: bool, description: String) -> bool:
	_check(condition, description)
	if not condition:
		_write("abort", {"role": _role, "description": description})
	return condition


func _boundary(predicate: Callable, seconds: float, description: String) -> bool:
	return _require(await _until(predicate, seconds), description)


func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		if FileAccess.file_exists(_directory.path_join("abort")) or (_component_deadline > 0 and Time.get_ticks_msec() >= _component_deadline):
			return false
		await _ticks(1)
	return false


func _wait_file(name: String, seconds: float) -> bool:
	# Gameplay aborts promptly; owned process exit still gets its actual receipt.
	if name.ends_with(".done") or name.ends_with(".exit"):
		var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
		while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(_directory.path_join(name)):
			await _ticks(1)
		var received := FileAccess.file_exists(_directory.path_join(name))
		_check(received, "owned completion/exit receipt arrives: " + name)
		return received
	return await _boundary(func(): return FileAccess.file_exists(_directory.path_join(name)), seconds, "peer boundary arrives: " + name)
