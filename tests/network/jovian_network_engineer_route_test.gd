## test-matrix-display: input-only
extends SceneTree

## Two owned OS peers load actual Main. Only the exterior hatch is staged;
## cabin walk, physical chair, selection, repair and standing use Player input.
const Main := preload("res://scenes/main.tscn")
var _checks := 0
var _failures: Array[String] = []
var _directory := ""
var _role := ""
var _game: GameFlow
var _craft: Variant
var _halyard := false
var _player: PlayerController
var _port := 0
var _store_path := ""
var _package_under_test := ""
var _halyard_panel_progress_seen := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_halyard = _halyard or "--halyard-engineer" in args
	args.erase("--halyard-engineer")
	var package_index := args.find("--package-under-test")
	if package_index >= 0 and package_index + 1 < args.size():
		_package_under_test = args[package_index + 1]
		args.remove_at(package_index + 1)
		args.remove_at(package_index)
	if not _package_under_test.is_empty():
		_check(FileAccess.file_exists("res://project.binary"), "engineer process loads requested package without source game fallback")
		if not _failures.is_empty():
			quit(1)
			return
		print("ENGINEER_PACKAGE_LOADED: pid=%d package=%s" % [OS.get_process_id(), _package_under_test])
	if args.size() < 3:
		await _orchestrate()
		return
	_role = args[0]
	_directory = args[1]
	_port = int(args[2])
	_write(_role + ".script_ready", {})
	_game = Main.instantiate() as GameFlow
	_store_path = "user://engineer-peer-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("HalyardCrewTransport" if _halyard else "JovianLightFreighter")
	_player = _game.get_node("Player") as PlayerController
	_game.start_shift()
	await _ticks(3)
	_write(_role + ".main_ready", {})
	if _role == "host":
		await _host()
	else:
		await _client()
	for action in [&"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"fire", &"camera_distance_out"]:
		Input.action_release(action)
	_game.shutdown_network_session(&"engineer_test_done")
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	DirAccess.remove_absolute(_store_path)
	_write(_role + ".done", {"checks": _checks, "failures": _failures})
	for failure in _failures:
		push_error(failure)
	print("JOVIAN_NETWORK_ENGINEER_%s: %d checks, %d failures" % [_role.to_upper(), _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _orchestrate() -> void:
	var receipt_root := OS.get_environment("TMPDIR")
	if receipt_root.is_empty():
		receipt_root = OS.get_user_data_dir()
	_directory = receipt_root.path_join("mudds-engineer-peers-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_directory)
	_port = 26000 + OS.get_process_id() % 15000
	var host_args := _peer_arguments("host", PackedStringArray(["--headless"]))
	var host := _spawn_peer("host", host_args)
	_check(host > 0, "owned independent host starts")
	await _wait_file("host.ready", 60.0)
	var client_args := _peer_arguments("client", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-method", "gl_compatibility"]))
	var client := _spawn_peer("client", client_args)
	_check(client > 0, "owned independent client starts")
	await _wait_file("client.done", 120.0)
	await _wait_file("host.done", 20.0)
	for role in ["host", "client"]:
		var result := _read(role + ".done")
		_check(not result.is_empty() and (result.get("failures", []) as Array).is_empty(), "%s ordinary production route passes" % role)
		if not result.is_empty():
			_checks += int(result.get("checks", 0))
	for role in ["host", "client"]:
		await _wait_file(role + ".exit", 10.0)
		_check(FileAccess.get_file_as_string(_directory.path_join(role + ".exit")).strip_edges() == "0", "%s OS process exits zero" % role)
		var child_path := _directory.path_join(role + ".pid")
		if not FileAccess.file_exists(_directory.path_join(role + ".exit")) and FileAccess.file_exists(child_path):
			var child := int(FileAccess.get_file_as_string(child_path))
			if child > 0 and OS.is_process_running(child):
				OS.kill(child)
	for pid in [host, client]:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	for failure in _failures:
		push_error(failure)
	print("ENGINEER_PEER_ARTIFACTS: ", _directory)
	print("JOVIAN_NETWORK_ENGINEER_ROUTE: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var parent := OS.get_cmdline_args()
	var path := ProjectSettings.globalize_path("res://")
	var path_index := parent.find("--path")
	if path_index >= 0 and path_index + 1 < parent.size():
		path = parent[path_index + 1]
	elif path.is_empty():
		path = DirAccess.open(".").get_current_dir()
	var script := "res://tests/network/jovian_network_engineer_route_test.gd"
	if not _package_under_test.is_empty():
		# Tests are excluded from export. Only this fixture is external;
		# res:// production Main and dependencies come from the selected pack.
		var script_index := parent.find("--script")
		if script_index >= 0 and script_index + 1 < parent.size():
			script = parent[script_index + 1]
		if script.begins_with("res://"):
			script = path.path_join(script.trim_prefix("res://"))
	var args := display.duplicate()
	args.append_array(["--audio-driver", "Dummy", "--path", path])
	if not _package_under_test.is_empty():
		args.append_array(["--main-pack", _package_under_test])
	args.append_array(["--script", script, "--", role, _directory, str(_port)])
	if _halyard:
		args.append("--halyard-engineer")
	if not _package_under_test.is_empty():
		args.append_array(["--package-under-test", _package_under_test])
	print("ENGINEER_PEER_LAUNCH: ", role, " ", args)
	return args

func _spawn_peer(role: String, args: PackedStringArray) -> int:
	# The wrapper waits for our child and records its actual OS exit status.
	# Positional arguments keep executable/path text out of shell evaluation.
	var command := '\"$@\" & child=$!; printf \"%s\" \"$child\" > \"$0.pid\"; wait \"$child\"; status=$?; printf \"%s\" \"$status\" > \"$0.exit\"; exit \"$status\"'
	var wrapper := PackedStringArray(["-c", command, _directory.path_join(role), OS.get_executable_path()])
	wrapper.append_array(args)
	return OS.create_process("/bin/sh", wrapper)

func _host() -> void:
	_player.set_control_enabled(false)
	_check(_game.host_network_session(_port).accepted, "production host starts without raising default capacity")
	# Actual immediate publication advances its own clock without advancing
	# boarding. Keep the honest divergence beyond the unchanged body window.
	for _index in GameFlow.NETWORK_REMOTE_BODY_MAX_TICK_BEHIND + 64:
		_game.call("_publish_network_moving_interior_state", _craft, false)
	print("ENGINEER_CLOCK_PUBLICATION: moving=%d boarding=%d" % [int(_game.get_network_moving_interior_publication_audit().server_tick), _game.network_session.get_boarding_server_tick()])
	_write("host.ready", {})
	if not await _wait_file("client.seated", 60.0):
		print("ENGINEER_HOST_BODY_DEBUG: ", _game.get_network_remote_body_audit(), " movement=", _game.network_session.get_movement_authority_audit())
		return
	var simulation := _game.get_network_remote_body_simulation()
	var peers := _game.network_session.get_admitted_peer_ids()
	var movement_tick := _game.network_session.get_movement_server_tick()
	var boarding_tick := _game.network_session.get_boarding_server_tick()
	print("ENGINEER_LEDGER_CLOCKS: movement=%d boarding=%d difference=%d" % [movement_tick, boarding_tick, movement_tick - boarding_tick])
	_check(peers.size() == 1 and movement_tick - boarding_tick > GameFlow.NETWORK_REMOTE_BODY_MAX_TICK_BEHIND, "one actual separate client moves and claims engineer while ledger clocks exceed unchanged movement window")
	if peers.is_empty():
		return
	var peer := int(peers[0])
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var body := simulation.get_body(avatar)
	var authority: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	var assignment := authority.get_assignment(peer, avatar)
	_check(body != null and body.is_seated_at(_craft.get_engineer_seat_anchor()), "host production body physically occupies engineer anchor")
	_check(assignment.get("role") == &"engineer", "actual host role owner claims engineer chair")
	_check(not _craft.is_piloted() and not body.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META), "remote engineer owns no pilot helm or local host tag")
	if _halyard:
		var binding: NetworkJovianEngineerBinding = _game.get("_network_engineer_binding")
		_check(binding.passenger.authority == authority and binding.passenger.engineer.authority == authority, "Halyard engineer provider borrows exact single passenger roster")
	var model: ShipComponentDamage = _craft.get_component_damage()
	for index in [1, 4]:
		_craft.apply_damage(_craft.maximum_hull * 0.15, _craft.to_global((model.get_component_states()[index] as Dictionary).local_position))
	_write("host.damage", {"crew_panel": _craft.refresh_crew_status_display() if _halyard else {}})
	if not await _wait_file("client.repair_selected", 10.0):
		return
	# Component selection and its replica handoff may outlast light damage's
	# passive berth recovery. Stage fresh real damage at the positive FIRE
	# boundary, as the solo route does, so this assertion measures a kit commit.
	_craft.apply_damage(_craft.maximum_hull * 0.35, _craft.to_global((model.get_component_states()[4] as Dictionary).local_position))
	var before := model.get_component_integrity(&"engine_bay")
	_check(before < 1.0, "fresh real host damage leaves engine bay eligible for finite repair")
	_write("host.repair_ready", {
		"server_tick": _game.network_session.get_boarding_server_tick(),
		"component_generation": int(_craft.get_engineer_gameplay_state().component_generation),
		"seat_generation": int(assignment.seat_generation), "claim_sequence": int(assignment.claim_sequence),
		"migration_generation": int(_game.network_session.get_migration_snapshot().migration_generation),
	})
	if not await _wait_file("client.repaired", 35.0):
		return
	var repair: Dictionary = _craft.get_engineer_repair_state()
	print("ENGINEER_HOST_REPAIR: wall=", Time.get_unix_time_from_system(), " state=", repair)
	_check(repair.get("reason") == &"repair_committed" and int(repair.resource_units) == 5
		and int(((repair.get("receipt", {}) as Dictionary).get("operation", {}) as Dictionary).get("repaired_components", 0)) == 1,
		"finite host repair commits one actual component and spends exactly one kit")
	_check(model.get_component_integrity(&"engine_bay") > before, "host actual engine integrity improves through ordinary client FIRE")
	if _halyard:
		# A destroyed sibling provider must not tombstone this craft's occupied
		# engineer replica. Real damage drives the existing destruction seam.
		var sibling := _game.get_node("JovianLightFreighter") as JovianLightFreighter
		sibling.apply_damage(sibling.maximum_hull + 1.0, sibling.global_position, Vector3.UP)
		_check(sibling.is_destroyed() and body.is_seated_at(_craft.get_engineer_seat_anchor()), "real sibling hull loss preserves current Halyard engineer body")
	_write("host.repair_checked", {})
	if not await _wait_file("client.stood", 20.0):
		return
	_check(authority.get_assignment(peer, avatar).is_empty() and not bool(_craft.get_engineer_repair_state().active), "standing releases real role and active repair authority")
	_check(body.is_on_floor() and not body.is_seated(), "host stood body remains supported and usable")
	_write("host.stand_checked", {})
	if not await _wait_file("client.reseated", 20.0):
		return
	var new_assignment := authority.get_assignment(peer, avatar)
	_check(not new_assignment.is_empty() and body.is_seated_at(_craft.get_engineer_seat_anchor())
		and int(new_assignment.get("claim_sequence", 0)) > int(assignment.get("claim_sequence", 0)), "reseating creates distinct authoritative occupancy identity")
	_write("host.reseat_checked", {})
	if not await _wait_file("client.negatives", 20.0):
		return
	_check(int(_craft.get_engineer_repair_state().resource_units) == 5 and not bool(_craft.get_engineer_repair_state().active), "forged, stale and malformed actual client requests cannot spend a kit")
	_write("host.negatives_checked", {})
	if not await _wait_file("client.migration_sit", 20.0):
		return
	_check(await _until(func(): return simulation.get_body_record(avatar).get("seat_state") == &"sitting", 8.0), "ordinary third chair press reaches host sitting transition")
	_check(_game.network_session.rotate_session_migration().accepted, "host migration rotates during real sitting transition")
	await _ticks(35)
	print("ENGINEER_MIGRATION_BODY: wall=", Time.get_unix_time_from_system(),
		" cached_body_valid=", is_instance_valid(body), " current_body_valid=", is_instance_valid(simulation.get_body(avatar)),
		" epochs=", _game.network_session.get_migration_snapshot(),
		" body_record=", simulation.get_body_record(avatar))
	if not is_instance_valid(body):
		_check(false, "migration cancels pending chair ownership without later resurrection")
		_check(false, "migration recovery restores retained body cabin containment")
		return
	_check(authority.get_assignment(peer, avatar).is_empty() and not body.is_seated(), "migration cancels pending chair ownership without later resurrection")
	_check(body.get_cabin_containment_report().active and body.get_cabin_containment_report().frame == _craft, "migration recovery restores retained body cabin containment")
	_write("host.migration_checked", {})
	if not await _wait_file("client.disconnected", 20.0):
		return
	await _ticks(15)
	_check(authority.get_assignment(peer, avatar).is_empty() and simulation.get_body(avatar) == null, "disconnect retires body, chair claim and repair selection")
	_check((_craft.get_engineer_gameplay_state().selection as Dictionary).is_empty(), "disconnect clears component selection")
	if _halyard:
		var provider: NetworkJovianEngineerBinding = _game._network_engineer_binding.passenger.engineer
		_check(provider._request_sequences.is_empty() and provider._request_peers.is_empty() and provider._errors.is_empty(), "actual Halyard peer loss retires engineer request and error cursors")
	_game.shutdown_network_session(&"engineer_host_done")
	_check(_craft.get_crew_role_authority() == null, "session stop detaches exact empty authority for solo reuse")

func _client() -> void:
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "production client joins")
	await _ticks(100)
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + _craft.global_basis.y.normalized() * 0.05))
	await _ticks(10)
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null, 12.0), "ordinary hatch Interact admits actual walking body")
	root.grab_focus()
	var body_ready := await _until(func(): return not bool(_game.get("_transition_busy")) and _player.is_control_enabled() and _player.is_on_floor(), 8.0)
	if body_ready:
		var body_source := _game.get_network_remote_body_intent_source()
		var prior_retries := int(body_source.get_audit().opening_retries)
		# Retain the actual admitted body and open a legitimate new source
		# stream with the missing-relationship clock that stranded it before.
		_game.bind_network_remote_body(body_source.get_entity_id(), body_source.get_entity_generation())
		var missing_clock := body_source.advance(_game.network_session.multiplayer.get_unique_id(), {"move_axis": Vector2.ZERO}, -1)
		_game.network_session.send_movement_intent(missing_clock)
		body_ready = await _until(func(): return int(body_source.get_audit().opening_retries) > prior_retries and bool(body_source.get_audit().opening_confirmed), 5.0)
		print("ENGINEER_OPENING_RECOVERY: ", body_source.get_audit())
	_check(body_ready and not bool(_game.get("_transition_busy")) and _player.is_control_enabled() and _player.is_on_floor(), "ordinary hatch finishes supported and actual refused opening recovers before walking")
	await _walk(_craft.to_local(_craft.get_engineer_station_role_contract().entry_transform.origin))
	_check(_player.is_on_floor(), "ordinary cabin walk reaches chair supported")
	await _look(_craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
	print("ENGINEER_APPROACH: local=", _craft.to_local(_player.global_position), " look=", _player.get_look_yaw(), " nearby=", _player.get_nearby_interactables(), " candidate=", _game.station_interaction_candidate)
	await _press(&"interact")
	if not await _until(func(): return _player.is_seated_at(_craft.get_engineer_seat_anchor()), 8.0):
		_check(false, "ordinary chair Interact receives host confirmation and seats local player")
		print("ENGINEER_CHAIR_DEBUG phase=", _game.phase, " pose=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " view=", _game.network_session.get_engineer_replica_snapshot())
		return
	_check(true, "ordinary chair Interact receives host confirmation and seats local player")
	var source: LocalShipInputSource = _craft.get_local_input_source()
	# Headless deterministic focus exercises the production transformed source.
	source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_write("client.seated", {})
	if not await _wait_file("host.damage", 10.0):
		return
	_check(await _until(func(): return not (_game.network_session.get_engineer_replica_snapshot().get("gameplay", {}) as Dictionary).get("selection", {}).is_empty() and (not _halyard or _halyard_roster_matches_host_view()), 8.0), "actual damaged host components reach automatic ordinary selection")
	var initial := _game.network_session.get_engineer_replica_snapshot()
	if _halyard:
		var host_panel := _read("host.damage").get("crew_panel", {}) as Dictionary
		var panel: Dictionary = _craft.get_crew_status_display().get_display_snapshot()
		_check(not host_panel.is_empty()
			and panel.get("role_states", {}) == host_panel.get("role_states", {})
			and panel.get("pilot_ready") == host_panel.get("pilot_ready")
			and panel.get("optional_crew_count") == host_panel.get("optional_crew_count")
			and _craft.get_crew_status_display().get_readout_text().contains("E [ACTIVE]"),
			"actual host pilot/engineer occupancy and departure facts reach the seated client's physical roster")
	print("ENGINEER_SELECTION_VIEW: ", initial, " source=", source.get_authority_peer_id(), " enabled=", source.is_enabled_owner(), " sampling=", source.call(&"_is_input_sampling_active"), " transition=", _game.get("_transition_busy"))
	var old_claim := int((initial.assignment as Dictionary).claim_sequence)
	await _press(source.camera_distance_out_action)
	_check(await _until(func(): return StringName(((_game.network_session.get_engineer_replica_snapshot().get("gameplay", {}) as Dictionary).get("selection", {}) as Dictionary).get("component_id", &"")) == &"engine_bay", 8.0), "ordinary remappable selector chooses engine bay on host")
	# Exercise the same berth-tick handoff that can consume light initial
	# damage, before the host refreshes the finite-kit acceptance target.
	await _ticks(32)
	_write("client.repair_selected", {})
	if not await _wait_file("host.repair_ready", 10.0):
		return
	# FIRE admission reads the production replica, not the host's file marker.
	# Wait for this damage in the current occupancy; an older damaged snapshot
	# cannot establish that the fresh acceptance target reached the client.
	var ready := _read("host.repair_ready")
	var target_ready := await _until(func(): return _repair_target_replica_ready(ready), 8.0)
	_check(target_ready, "fresh selected engine bay damage reaches current production replica before FIRE")
	if not target_ready:
		return
	var repair_view := _game.network_session.get_engineer_replica_snapshot()
	print("ENGINEER_REPAIR_TARGET_READY: marker=", ready, " replica_tick=", repair_view.server_tick,
		" revision=", repair_view.revision, " integrity=", (repair_view.components as Dictionary).get(&"engine_bay"))
	var local_repair: Dictionary = {}
	var local_components: Dictionary = {}
	if _halyard:
		local_repair = _craft.get_engineer_repair_state()
		local_components = _craft.get_component_damage().get_component_report()
	await _press(source.fire_action)
	_check(await _until(func():
		if _halyard:
			_observe_halyard_repair_panel_progress()
		var spent := int(((_game.network_session.get_engineer_replica_snapshot().get("gameplay", {}) as Dictionary).get("repair", {}) as Dictionary).get("resource_units", 6)) == 5
		return spent and (not _halyard or _halyard_panel_completed()), 8.0), "ordinary transformed FIRE completes finite repair with replicated stock")
	if _halyard:
		_check(_halyard_panel_progress_seen, "actual received host repair progress reaches the physical Halyard cabin panel during ordinary FIRE")
		_check(_halyard_panel_completed(), "actual host completion and five remaining kits reach the physical Halyard cabin panel")
	print("ENGINEER_CLIENT_REPAIR: wall=", Time.get_unix_time_from_system(), " view=", _game.network_session.get_engineer_replica_snapshot(), " body_source=", _game.get_network_remote_body_intent_source().get_audit())
	_check(_craft.get_crew_role_authority() == null, "client has no component-repair or role authority")
	_write("client.repaired", {})
	if not await _wait_file("host.repair_checked", 10.0):
		return
	if _halyard:
		await _ticks(20)
		var retained := _game.network_session.get_engineer_replica_snapshot()
		_check(retained.get("ship_id") == _craft.get_ship_id() and retained.get("seated", false)
			and int((retained.get("assignment", {}) as Dictionary).get("claim_sequence", 0)) == old_claim,
			"destroyed Jovian cannot overwrite occupied Halyard engineer replica")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and not bool(_game.get("_transition_busy")), 8.0), "ordinary stand completes host-authorized exit")
	await _ticks(20)
	_check(_player.is_on_floor() and _player.is_control_enabled(), "stood client is supported and controls remain enabled")
	_check(source.get_authority_peer_id() == 1, "standing restores borrowed transformed input owner")
	if _halyard:
		var walking_view := _game.network_session.get_engineer_replica_snapshot()
		_check(walking_view.get("ship_id") == _craft.get_ship_id()
			and not bool(walking_view.get("seated", true))
			and (walking_view.get("assignment", {}) as Dictionary).is_empty()
			and int(((walking_view.get("gameplay", {}) as Dictionary).get("repair", {}) as Dictionary).get("resource_units", 0)) == 5,
			"actual host standing replica retains spent repair stock without an engineer assignment")
		_craft.refresh_crew_status_display()
		_check(_craft.get_crew_status_display().get_readout_text().contains("KITS 5/6"), "standing and local cabin refresh retain host kit stock on the physical panel")
		_check(_halyard_roster_matches_host_view()
			and _craft.get_crew_status_display().get_readout_text().contains("E [OPEN]"),
			"actual host engineer release reaches the walking physical roster and survives local refresh")
		_check(_craft.get_engineer_repair_state() == local_repair
			and _craft.get_component_damage().get_component_report() == local_components,
			"received host repair and standing presentation leave client repair authority and component ledger unchanged")
	_write("client.stood", {})
	if not await _wait_file("host.stand_checked", 10.0):
		return
	await _look(_craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	var reseated := await _until(func(): return _player.is_seated_at(_craft.get_engineer_seat_anchor()), 8.0)
	_check(reseated, "ordinary reseat succeeds without fake occupancy")
	if not reseated:
		print("ENGINEER_RESEAT_DEBUG: view=", _game.network_session.get_engineer_replica_snapshot(), " candidate=", _game.station_interaction_candidate, " body=", _game.get_network_remote_body_audit())
		return
	_write("client.reseated", {})
	if not await _wait_file("host.reseat_checked", 10.0):
		return
	var view := _game.network_session.get_engineer_replica_snapshot()
	var payload := {
		"avatar_id": StringName((view.assignment as Dictionary).avatar_id), "entity_generation": int(view.entity_generation),
		"seat_generation": int((view.assignment as Dictionary).seat_generation), "claim_sequence": old_claim,
		"component_generation": int((view.gameplay as Dictionary).component_generation), "component_id": &"engine_bay", "repair": 0.2,
		"request_sequence": 10000, "binding_generation": int(view.binding_generation), "migration_generation": int(view.migration_generation),
		"server_tick": _game.network_session.get_boarding_server_tick_estimate(),
	}
	# Each independent refusal uses the live clock; earlier RPC waits must
	# not turn identity/replay checks into the separate expiry check below.
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"engineer_not_seated", 5.0), "delayed prior-chair request is refused after reseating")
	payload.claim_sequence = int((view.assignment as Dictionary).claim_sequence)
	payload.entity_generation += 1
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_engineer_intent(payload)
	await _ticks(20)
	_check(_game.network_session.get_engineer_replica_snapshot().get("error") == &"engineer_not_seated", "stale body generation is refused through actual secure RPC")
	payload.entity_generation -= 1
	payload.request_sequence += 1
	payload.component_generation += 1
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"stale_component_generation", 5.0), "retired component generation cannot start repair")
	payload.component_generation -= 1
	payload.request_sequence += 1
	payload.component_id = &"foreign_component"
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"foreign_component", 5.0), "foreign target cannot spend host kits")
	payload.component_id = &"engine_bay"
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"stale_engineer_sequence", 5.0), "replayed accepted request cursor cannot start work")
	payload.request_sequence += 1
	payload.binding_generation += 1
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"stale_engineer_generation", 5.0), "retired binding generation cannot start repair")
	payload.binding_generation -= 1
	payload.server_tick = 0
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"stale_engineer_tick", 5.0), "expired authoritative tick cannot start repair")
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	payload.component_id = []
	_game.network_session.send_engineer_intent(payload)
	_check(await _until(func(): return _game.network_session.get_engineer_replica_snapshot().get("error") == &"invalid_engineer_identity", 5.0), "malformed component identity fails closed without a script error")
	_write("client.negatives", {})
	if not await _wait_file("host.negatives_checked", 10.0):
		return
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and not bool(_game.get("_transition_busy")), 8.0), "client leaves second occupancy before migration")
	await _ticks(20)
	await _look(_craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
	_write("client.migration_sit", {})
	await _press(&"interact")
	if not await _wait_file("host.migration_checked", 12.0):
		return
	_game.shutdown_network_session(&"engineer_client_disconnect")
	_check(not _player.is_seated() and _player.is_control_enabled(), "disconnect leaves local player awake with controls")
	if _halyard:
		var stopped_panel: String = _craft.get_crew_status_display().get_readout_text()
		_check(stopped_panel.contains("IDLE // REPAIR READY") and stopped_panel.contains("KITS 6/6"),
			"actual client session stop restores local Halyard repair presentation and unspent local stock")
		_check(stopped_panel.contains("ROSTER [DETACHED]")
			and not bool(_craft.get_crew_status_display().get_display_snapshot().get("pilot_ready", true)),
			"actual session stop retires host crew readiness and restores the client's detached local roster")
	_write("client.disconnected", {})

func _observe_halyard_repair_panel_progress() -> void:
	var view := _game.network_session.get_engineer_replica_snapshot()
	var repair := (view.get("gameplay", {}) as Dictionary).get("repair", {}) as Dictionary
	var progress := float(repair.get("progress", 0.0))
	if view.get("ship_id") != _craft.get_ship_id() or repair.get("status") != &"repairing" or progress <= 0.0:
		return
	var text: String = _craft.get_crew_status_display().get_readout_text()
	if text.contains("REPAIRING") and text.contains("%d%%" % roundi(progress * 100.0)):
		_halyard_panel_progress_seen = true

func _halyard_panel_completed() -> bool:
	var view := _game.network_session.get_engineer_replica_snapshot()
	var repair := (view.get("gameplay", {}) as Dictionary).get("repair", {}) as Dictionary
	var text: String = _craft.get_crew_status_display().get_readout_text()
	return view.get("ship_id") == _craft.get_ship_id() and repair.get("status") == &"completed" \
		and int(repair.get("resource_units", 0)) == 5 \
		and text.contains("COMPLETED") and text.contains("KITS 5/6") \
		and _halyard_roster_matches_host_view()


func _halyard_roster_matches_host_view() -> bool:
	var view := _game.network_session.get_engineer_replica_snapshot()
	var crew := (view.get("gameplay", {}) as Dictionary).get("crew_status", {}) as Dictionary
	var panel: Dictionary = _craft.get_crew_status_display().get_display_snapshot()
	if view.get("ship_id") != _craft.get_ship_id() or not bool(crew.get("authority_attached", false)) \
			or not bool(panel.get("roster_linked", false)):
		return false
	var occupancy := crew.get("role_occupancy", {}) as Dictionary
	var roles := panel.get("role_states", {}) as Dictionary
	for role in [&"pilot", &"gunner", &"engineer", &"passenger"]:
		var host_occupied := not (occupancy.get(role, []) as Array).is_empty()
		if bool((roles.get(role, {}) as Dictionary).get("occupied", false)) != host_occupied:
			return false
	var departure := crew.get("departure_readiness", {}) as Dictionary
	var routing := crew.get("power_routing", {}) as Dictionary
	var channel := StringName((routing.get("engineer", {}) as Dictionary).get("channel", &"none"))
	var route_tokens := {&"mobility_multiplier": "[MOBILITY]", &"fire_multiplier": "[FIRE]", &"targeting_multiplier": "[TARGET]"}
	return bool(panel.get("pilot_ready", false)) == (bool(departure.get("ready", false)) and bool(departure.get("pilot_present", false))) \
		and int(panel.get("optional_crew_count", -1)) == int(departure.get("optional_crew_count", 0)) \
		and panel.get("engineer_route") == route_tokens.get(channel, "[NONE]")

func _repair_target_replica_ready(ready: Dictionary) -> bool:
	var view := _game.network_session.get_engineer_replica_snapshot()
	var gameplay := view.get("gameplay", {}) as Dictionary
	var selection := gameplay.get("selection", {}) as Dictionary
	var assignment := view.get("assignment", {}) as Dictionary
	return not ready.is_empty() and bool(view.get("seated", false)) \
		and int(view.get("server_tick", -1)) > int(ready.server_tick) \
		and int(view.get("migration_generation", 0)) == int(ready.migration_generation) \
		and int(assignment.get("seat_generation", 0)) == int(ready.seat_generation) \
		and int(assignment.get("claim_sequence", 0)) == int(ready.claim_sequence) \
		and int(gameplay.get("component_generation", 0)) == int(ready.component_generation) \
		and int(selection.get("component_generation", 0)) == int(ready.component_generation) \
		and StringName(selection.get("component_id", &"")) == &"engine_bay" \
		and float((view.get("components", {}) as Dictionary).get(&"engine_bay", 1.0)) < 1.0 \
		and int((gameplay.get("repair", {}) as Dictionary).get("resource_units", 0)) == 6

func _walk(target_local: Vector3) -> void:
	var target: Vector3 = _craft.to_global(target_local)
	print("ENGINEER_WALK_START: local=", _craft.to_local(_player.global_position), " target=", target_local)
	for _index in 100:
		var delta := target - _player.global_position
		delta = delta.slide(_craft.global_basis.y.normalized())
		if delta.length() < 1.0:
			break
		var forward := (-_player.get_camera().global_basis.z).slide(_craft.global_basis.y.normalized()).normalized()
		var right := forward.cross(_craft.global_basis.y.normalized()).normalized()
		var direction := delta.normalized()
		var axis := Vector2(direction.dot(right), -direction.dot(forward))
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		Input.action_press(&"move_left" if axis.x < 0.0 else &"move_right", absf(axis.x))
		Input.action_press(&"move_forward" if axis.y < 0.0 else &"move_back", absf(axis.y))
		await _ticks(1)
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	await _ticks(15)

func _look(target: Vector3) -> void:
	for _index in 4:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			_player._unhandled_input(click)
		var desired := _player.global_basis.inverse() * (target - _player.get_camera().global_position).normalized()
		var current := _player.global_basis.inverse() * _player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _player.invert_mouse_y else -1.0)) / _player.mouse_sensitivity
		_player._unhandled_input(event)
		await _ticks(1)

func _press(action: StringName) -> void:
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(3)

func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await _ticks(1)
	return false

func _ticks(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame

func _wait_file(name: String, seconds: float) -> bool:
	var result := await _until(func(): return FileAccess.file_exists(_directory.path_join(name)), seconds)
	_check(result, "peer boundary arrives: " + name)
	return result

func _write(name: String, data: Dictionary) -> void:
	var target := _directory.path_join(name)
	var temporary := target + ".tmp-" + str(OS.get_process_id())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_check(false, "peer receipt temporary file opens: " + name)
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, target) != OK:
		_check(false, "complete peer receipt publishes atomically: " + name)
		return
	print("ENGINEER_PEER_BOUNDARY: ", _role, " ", name, " wall=", Time.get_unix_time_from_system(), " ticks=", Engine.get_physics_frames())

func _read(name: String) -> Dictionary:
	if not FileAccess.file_exists(_directory.path_join(name)):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(_directory.path_join(name))) as Dictionary

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
