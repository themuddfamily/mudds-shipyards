extends SceneTree

## Real production Main instances in independent processes, using an ephemeral
## ENet port. Host-owned Emberline flights cross the existing GameFlow dispatcher.
const MAIN := preload("res://scenes/main.tscn")
const Replicator := preload("res://scripts/network/network_remote_projectile_replicator.gd")
const Actors := preload("res://scripts/network/network_emberline_actor_presenter.gd")
const PicketActors := preload("res://scripts/network/network_picket_actor_presenter.gd")
const Fragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")
const SnapshotCodec := preload("res://scripts/network/network_snapshot_delta_codec.gd")
const PEER_TIMEOUT := 45.0
var _game: GameFlow
var _failures: Array[String] = []
var _assertions := 0
var _children: Array[int] = []
var _directory := ""
var _role := "host"
var _port := 0
var _package_under_test := ""
var _picket: StandoffPicketOpponent
var _snapshot_budget_checked := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	var package_index := args.find("--package-under-test")
	if package_index >= 0 and package_index + 1 < args.size():
		_package_under_test = args[package_index + 1]
		args.remove_at(package_index + 1)
		args.remove_at(package_index)
	if not _package_under_test.is_empty():
		_check(FileAccess.file_exists("res://project.binary"), "process loads the embedded package rather than source")
	if args.size() == 3:
		_role = args[0]
		_port = int(args[1])
		_directory = args[2]
	else:
		_directory = OS.get_user_data_dir().path_join("emberline-bolt-test-%d" % OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(_directory)
	_game = MAIN.instantiate() as GameFlow
	_check(_game.configure_runtime_settings_persistence(
		UserDataStore.new(_directory + "/" + _role + "-save.json"),
		_directory + "/" + _role + "-legacy.cfg"), "each process injects its own fresh save")
	root.add_child(_game)
	await process_frame
	await physics_frame
	_game.start_shift()
	await process_frame
	await physics_frame
	_game.set_physics_process(false)
	# Independent rebases: projectiles must remain in the shared station frame.
	_game.world.global_position = {"host": Vector3(-31, -4, -48), "client": Vector3(22, 3, 17), "late": Vector3(-5, 2, 91), "dead": Vector3(7, -2, 32)}[_role]
	if _role == "host":
		await _host()
	elif _role == "dead":
		await _dead_client()
	else:
		await _client()
	if _game.get_network_session() != null and _game.get_network_session().is_session_active():
		_game.shutdown_network_session(&"test_complete")
	_game.queue_free()
	await process_frame
	await process_frame
	for pid in _children:
		if OS.is_process_running(pid):
			OS.kill(pid)
	if _failures.is_empty():
		if _role == "host":
			print("NETWORK_EMBERLINE_BOLT_TEST_OK: %d host assertions" % _assertions)
		else:
			print("NETWORK_EMBERLINE_PEER_COMPLETE %s: %d assertions" % [_role, _assertions])
		_mark("finished")
		quit(0)
	else:
		print("NETWORK_EMBERLINE_BOLT_TEST_FAILED %s: %s" % [_role, "; ".join(_failures)])
		_mark("failed")
		quit(1)

func _host() -> void:
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve ephemeral loopback port")
	_port = probe.get_local_port()
	probe.stop()
	_check(_game.host_network_session(_port, 3).get("accepted", false), "production Main hosts ENet")
	_check(not (_game.multiplayer as SceneMultiplayer).server_relay, "authoritative session disables engine client-to-client relays")
	_check(not _game._piloting, "host publishes the convoy while on foot")
	_check(_game._build_network_picket_actor_entries().is_empty(), "initial dormant picket publishes no first-life tombstone")
	_picket = _stage_picket()
	_game.get_network_session().snapshot_published.connect(func(packet: Dictionary) -> void:
		var rows: Array = (packet.get("sections", {}) as Dictionary).get("movement", [])
		if not _snapshot_budget_checked and rows.any(func(row): return row.get("mode") == PicketActors.MODE) \
				and rows.any(func(row): return row.get("mode") == Actors.MODE and bool(row.get("present", false))) \
				and not ((packet.get("sections", {}) as Dictionary).get("projectiles", []) as Array).is_empty():
			_snapshot_budget_checked = true
			var envelope := SnapshotCodec.new().encode(packet, true)
			var fragments := Fragmenter.new().fragment(envelope, 1, int(packet.get("revision", 0)))
			_check(Marshalls.variant_to_base64(envelope).to_utf8_buffer().size() <= Fragmenter.MAX_PACKET_BYTES
				and not fragments.is_empty() and fragments.size() <= Fragmenter.MAX_FRAGMENTS
				and rows.size() <= NetworkAuthoritativeSnapshot.MAX_ENTRIES_PER_SECTION,
				"actual combined host snapshot including picket stays inside original packet and row budgets"))
	_game._advance_network_remote_projectiles()
	var replicator := _game.get_network_remote_projectile_replicator()
	var threat := _game.cinder_convoy_threat
	var pool := threat.get_bolt_pool()
	_check(replicator != null and replicator.is_observing(pool), "production host observes Emberline before its first launch")
	if replicator == null or not replicator.is_observing(pool):
		return
	_spawn("client")
	if not await _wait_marker("client", "ready"):
		return
	_check(_game.cinder_convoy_host.start(_game.cinder_convoy_host.get_generation()).get("accepted", false), "production convoy begins")
	var generation := _game.cinder_convoy_host.get_generation()
	_check(threat.start(generation), "production threat opens its authoritative generation")
	(threat.get_attacker().get_node("Damageable") as Damageable).apply_damage(10.0)
	(threat.get_node("EmberlineTenderHurtbox/Damageable") as Damageable).apply_damage(10.0)
	threat.advance(3.01, generation)
	_check(pool.get_active_bolt_count() == 1 and replicator.get_active_flight_count() == 1,
		"first real raider shot is published synchronously once")
	if not await _wait_marker("client", "first"):
		return
	# Advance on the convoy's caller clock, then hold still while the late peer
	# boots: late joins must use this live pose, never wall-clock muzzle travel.
	pool.set_physics_process(false)
	pool.call(&"step", 0.1)
	var flown := pool.get_active_bolt_records()[0]
	var file := FileAccess.open(_directory + "/late-position", FileAccess.WRITE)
	file.store_var(flown.position - _game._network_station_frame_origin())
	file.close()
	_spawn("late")
	if not await _wait_marker("late", "first"):
		return
	(threat.get_attacker().get_node("Damageable") as Damageable).apply_damage(100.0)
	_picket.apply_damage(_picket.get_maximum_health() + 1.0)
	_check(pool.get_active_bolt_count() == 0 and replicator.get_active_flight_count() == 0,
		"raider destruction retires its host flight once")
	if not await _wait_marker("client", "retired") or not await _wait_marker("late", "retired"):
		return
	_spawn("dead")
	if not await _wait_marker("dead", "finished"):
		return
	threat.retire(generation)
	_game.cinder_convoy_host.report_convoy_lost(generation)
	_check(_game.cinder_convoy_host.reset(generation).get("accepted", false)
		and _game.cinder_convoy_host.get_generation() == generation + 1, "replacement reset advances its actual activity generation")
	# Activity reset and start each advance their production generation. Publish
	# the pending reset before starting, then compare bolts to the exact owner.
	if not await _wait_marker("client", "pending") or not await _wait_marker("late", "pending"):
		return
	_check(_game.cinder_convoy_host.start(generation + 1).get("accepted", false), "actual replacement convoy starts")
	var replacement_generation := _game.cinder_convoy_host.get_generation()
	var generation_file := FileAccess.open(_directory + "/replacement-generation", FileAccess.WRITE)
	generation_file.store_var(replacement_generation)
	generation_file.close()
	_check(threat.start(replacement_generation), "replacement threat generation can fire")
	_check(bool(_picket.activate(Transform3D(Basis.IDENTITY,
		_game._network_station_frame_origin() + Vector3(1010, 0, 0))).get("accepted", false)), "real picket replacement advances its activation")
	_picket.set_target(_game.get_node("ShipyardWorld/ExteriorTargetRange/TargetDrone01"))
	_picket._update_presentation(0.0)
	_game._advance_network_remote_projectiles()
	threat.advance(3.01, replacement_generation)
	if not await _wait_marker("client", "second") or not await _wait_marker("late", "second"):
		return
	var attacker := threat.get_attacker()
	threat.remove_child(attacker)
	_game.remove_child(_picket)
	if not await _wait_marker("client", "missing") or not await _wait_marker("late", "missing"):
		attacker.free()
		return
	attacker.free()
	_picket.free()
	threat.retire(replacement_generation)
	if not await _wait_marker("client", "finished") or not await _wait_marker("late", "finished"):
		return
	_check(int(replicator.get_audit().publish_failures) == 0, "all launches and terminals use the existing publisher")
	_check(_snapshot_budget_checked, "actual combined live actor and projectile baseline was measured inside unchanged budgets")
	for pid in _children:
		var deadline := Time.get_ticks_msec() + 4000
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not OS.is_process_running(pid), "independent client exits cleanly")

func _client() -> void:
	_picket = _stage_picket()
	var solo_picket_state := _picket.get_network_actor_presentation_snapshot()
	var solo_picket_pose := _picket.global_transform
	var solo_picket_charge := _picket.get_lance_charge_snapshot()
	var solo_picket_collision := Vector2i(_picket.collision_layer, _picket.collision_mask)
	var solo_picket_visible := _picket.visible
	var solo_picket_target := _picket.get("_target") as Node3D
	var audio_before_join := int(_game.combat_audio.get_state_snapshot().cue_count)
	_check(_game.cinder_convoy_host.start(_game.cinder_convoy_host.get_generation()).get("accepted", false), "client fixture begins a retained solo convoy")
	var solo_generation := _game.cinder_convoy_host.get_generation()
	_check(_game.cinder_convoy_threat.start(solo_generation), "retained solo threat begins")
	_game.cinder_convoy_host.visible = true
	var solo_health := 0.0 if _role == "late" else 17.0
	(_game.cinder_convoy_threat.get_attacker().get_node("Damageable") as Damageable).apply_damage(35.0 - solo_health)
	(_game.cinder_convoy_threat.get_node("EmberlineTenderHurtbox/Damageable") as Damageable).apply_damage(15.0)
	_check(_game.join_network_session("127.0.0.1", _port).get("accepted", false), "production client joins")
	var records: Array[Dictionary] = []
	_game.get_network_session().projectile_replica_packet.connect(func(packet: Dictionary, result: Dictionary) -> void:
		var projectile := packet.get("projectile", {}) as Dictionary
		if StringName(projectile.get("source_entity_id", &"")) == &"emberline-raider" and bool(result.get("accepted", false)):
			records.append(packet.duplicate(true)))
	_check(await _wait(func() -> bool: return not _game.get_network_session().get_server_offer().is_empty()), "client admitted")
	_check(await _wait(func() -> bool: return _game._network_picket_actor_presenter != null \
		and bool(_game._network_picket_actor_presenter.get_snapshot().actor.get("present", false)))
		and int(_game.combat_audio.get_state_snapshot().cue_count) == audio_before_join,
		"current and late actor first admission stays quiet without duplicate charge or weapon audio")
	var retained_convoy := _game.cinder_convoy_host.get_snapshot()
	_game._physics_process(1.0 / 60.0)
	_check(_game.cinder_convoy_host.get_snapshot() == retained_convoy and not _game.cinder_convoy_host.visible,
		"actual client physics preserves its suspended solo convoy and hides its tender")
	# These are production entry points that would otherwise permit a second
	# local convoy actor/bolt ledger on a client.
	_check(not bool(_game._start_cinder_convoy(Vector3.ZERO).get("accepted", true)), "client cannot start local combat convoy")
	_mark("ready")
	if not await _wait(func() -> bool: return not records.is_empty()):
		_check(false, "host travelling bolt reaches independent client")
		return
	var first := records[0].projectile as Dictionary
	var descriptor := first.get(Replicator.RECORD_KEY, {}) as Dictionary
	_check(StringName(descriptor.get("kind", &"")) == &"emberline_raider_bolt", "Emberline record retains its red weapon identity")
	var replicator := _game.get_network_remote_projectile_replicator()
	_check(replicator != null and int(replicator.get_audit().presented) == 1, "client draws the first shot once")
	if replicator == null:
		return
	var visual := (replicator.get("_visuals") as Dictionary).get(first.projectile_id, {}) as Dictionary
	_check(replicator.get_visual_position(first.projectile_id).distance_to(
		(first.position as Vector3) + _game._network_station_frame_origin()) < 6.0,
		"client visual is restored into its independent station origin")
	_check(not visual.is_empty() and ((visual.body as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("ff3b2a")), "client bolt core uses production Emberline red")
	_check(_game.cinder_convoy_threat.get_bolt_pool().get_active_bolt_count() == 0
		and not bool(replicator.get_audit().owns_combat_authority), "client presentation creates no combat flight")
	var actor_presenter := _game._network_emberline_actor_presenter
	_check(await _wait(func() -> bool: return actor_presenter != null \
		and bool((actor_presenter.get_snapshot().actors as Dictionary).get(Actors.RAIDER_ID, {}).get("present", false))),
		"authenticated actor snapshot reaches the independent peer")
	var remote_raider := actor_presenter.get_visual(Actors.RAIDER_ID)
	var remote_tender := actor_presenter.get_visual(Actors.TENDER_ID)
	_check(remote_raider != null and remote_raider.visible and remote_tender != null and remote_tender.visible,
		"host tender and raider are visible beside their replicated bolt on the independent client")
	var actor_snapshot := actor_presenter.get_snapshot()
	var picket_presenter := _game._network_picket_actor_presenter
	_check(await _wait(func() -> bool: return picket_presenter != null \
		and bool(picket_presenter.get_snapshot().actor.get("present", false))), "current and late peer receive actual host picket actor")
	var remote_picket := picket_presenter.get_visual()
	var picket_record := picket_presenter.get_snapshot().actor as Dictionary
	var expected_file := FileAccess.open(_directory + "/picket-state", FileAccess.READ)
	var expected_picket: Dictionary = expected_file.get_var()
	expected_file.close()
	_check(picket_record.cues == expected_picket.cues and picket_record.charge_active == expected_picket.charge_active
		and picket_record.posture == expected_picket.posture
		and remote_picket.global_position.is_equal_approx((picket_record.position as Vector3) + _game._network_station_frame_origin())
		and remote_picket.global_basis.is_equal_approx(Basis(picket_record.rotation as Quaternion)),
		"real current and held late baseline reproduce committed host charge, posture and independent-origin pose")
	var committed_cues := true
	for index in PicketActors.CUE_COUNT:
		var cue_visual := picket_presenter.get_cue_visual(index)
		committed_cues = committed_cues and is_instance_valid(cue_visual) \
			and cue_visual.transform == picket_record.cues[index][0] and cue_visual.visible == picket_record.cues[index][1]
	_check(committed_cues, "all nine actual replica cue nodes carry the committed host transforms and visibility")
	var visual_only := remote_picket.get_script() == null
	for node: Node in remote_picket.find_children("*", "Node", true, false):
		visual_only = visual_only and node.get_script() == null and node.process_mode == Node.PROCESS_MODE_DISABLED
	_check(visual_only and remote_picket.find_children("*", "Node", true, false).size() < PicketActors.MAX_VISUAL_NODES,
		"bounded retained visual copy contains no scripted or processing actor")
	_check(remote_picket.visible and remote_picket.find_children("*", "CollisionObject3D", true, false).is_empty()
		and remote_picket.find_children("*", "CollisionShape3D", true, false).is_empty()
		and remote_picket.find_children("*", "Damageable", true, false).is_empty()
		and remote_picket.find_children("*", "Light3D", true, false).is_empty()
		and not _picket.visible and not _picket.is_combat_source_registered()
		and _picket.get_lance_charge_snapshot() == solo_picket_charge
		and _picket.global_transform == solo_picket_pose,
		"picket replica carries no simulation authority and preserves the hidden frozen solo actor")
	var cue_count := int(_game.combat_audio.get_state_snapshot().cue_count)
	picket_presenter.consume_movement_section([picket_record], _game._network_station_frame_origin())
	_check(int(_game.combat_audio.get_state_snapshot().cue_count) == cue_count,
		"picket actor adoption and restatement dispatch no weapon audio")
	var raider_record := (actor_snapshot.actors as Dictionary).get(Actors.RAIDER_ID, {}) as Dictionary
	var tender_record := (actor_snapshot.actors as Dictionary).get(Actors.TENDER_ID, {}) as Dictionary
	_check(is_equal_approx(float(raider_record.get("health", 0)), 25.0)
		and is_equal_approx(float(tender_record.get("health", 0)), 65.0)
		and remote_raider.global_position.is_equal_approx((raider_record.position as Vector3) + _game._network_station_frame_origin())
		and remote_tender.global_position.is_equal_approx((tender_record.position as Vector3) + _game._network_station_frame_origin()),
		"current and late peers share committed actor health and station-frame poses")
	var hull := remote_raider.get_node("RaiderHull") as MeshInstance3D
	var retained_mesh := hull.mesh.get_instance_id()
	var retained_material := hull.material_override.get_instance_id()
	_check(not (hull.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("dd5c4d"))
		and remote_raider.find_children("*", "CollisionObject3D", true, false).is_empty()
		and remote_tender.find_children("*", "CollisionShape3D", true, false).is_empty()
		and remote_raider.find_children("*", "Damageable", true, false).is_empty()
		and not _game.cinder_convoy_host.visible
		and is_equal_approx(float(_game.cinder_convoy_threat.get_snapshot().attacker_health), solo_health),
		"steady damaged-hull copies carry no collision or health authority and preserve the solo actors")
	_check(int(actor_snapshot.destruction_cues) == 0, "current and late actor adoption replays no destruction cue")
	if _role == "late":
		var file := FileAccess.open(_directory + "/late-position", FileAccess.READ)
		var expected: Vector3 = file.get_var()
		file.close()
		_check((first.position as Vector3).is_equal_approx(expected), "late join uses exact paused pool pose in shared coordinates")
		_check(not bool(descriptor.get("launch", true)), "late join does not replay a launch cue")
	else:
		_check(bool(descriptor.get("launch", false)), "current peer receives the live launch")
	_mark("first")
	if not await _wait(func() -> bool: return int(replicator.get_audit().terminals) >= 1):
		_check(false, "raider destruction terminal reaches client")
		return
	_check(replicator.get_drawn_projectile_ids().is_empty() and int(replicator.get_audit().bursts) == 0, "destroyed source clears bolt without false impact")
	_check(await _wait(func() -> bool: return bool((actor_presenter.get_snapshot().actors as Dictionary).get(Actors.RAIDER_ID, {}).get("destroyed", false))),
		"host raider neutralization reaches the actor replica")
	_check(not remote_raider.visible and remote_tender.visible
		and int(actor_presenter.get_snapshot().destruction_cues) == 1,
		"neutralized raider disappears once while the surviving tender remains visible")
	var neutralized_before := actor_presenter.get_snapshot()
	_check(await _wait(func() -> bool: return bool(picket_presenter.get_snapshot().actor.get("destroyed", false)))
		and not remote_picket.visible, "host picket destruction hides its real client visual")
	_check_picket_replays(picket_presenter, picket_record)
	var hidden_healthy := ((neutralized_before.actors as Dictionary)[Actors.RAIDER_ID] as Dictionary).duplicate(true)
	hidden_healthy.health = 35.0
	hidden_healthy.destroyed = false
	hidden_healthy.pose_tick = int(hidden_healthy.pose_tick) + 100
	var revive := hidden_healthy.duplicate(true)
	revive.present = true
	revive.pose_tick = int(revive.pose_tick) + 1
	actor_presenter.consume_movement_section([hidden_healthy, revive], _game._network_station_frame_origin())
	_check(actor_presenter.get_snapshot() == neutralized_before and not remote_raider.visible,
		"neutralization stays terminal through a hidden healthy row and same-generation resurrection")
	var replay := records[0].duplicate(true)
	var admission := _game.get_network_session()._apply_projectile_replica_snapshot(replay)
	_check(not bool(admission.get("accepted", true)), "retired flight rejects stale launch replay")
	_game.runtime_settings.reduced_flash = true
	_game._apply_opponent_weapon_heat_presentation_profile()
	_mark("retired")
	_check(await _wait(func() -> bool: return int(actor_presenter.get_snapshot().generation) == int(first.source_generation) + 1),
		"reset-before-threat snapshot admits the pending next generation")
	var pending := (actor_presenter.get_snapshot().actors as Dictionary)[Actors.RAIDER_ID] as Dictionary
	_check(not bool(pending.present) and not bool(pending.destroyed) and not bool(pending.retired)
		and is_equal_approx(float(pending.health), 35.0), "pending retry cannot inherit the old neutralized health or terminal fence")
	_mark("pending")
	if not await _wait(func() -> bool: return int(replicator.get_audit().presented) == 2):
		_check(false, "replacement generation reaches client")
		return
	var second: Dictionary = {}
	for packet in records:
		if not bool(packet.get("terminal", false)) and packet.projectile.projectile_id != first.projectile_id:
			second = packet.projectile
	var generation_file := FileAccess.open(_directory + "/replacement-generation", FileAccess.READ)
	var expected_generation := int(generation_file.get_var())
	generation_file.close()
	_check(not second.is_empty() and int(second.source_generation) == expected_generation
		and expected_generation > int(first.source_generation), "new flight uses the exact actual convoy generation after reset and start")
	_check(await _wait(func() -> bool: return int(actor_presenter.get_snapshot().generation) == int(second.get("source_generation", -1)) \
		and remote_raider.visible), "replacement generation replaces the retired actor presentation")
	_check(await _wait(func() -> bool: return picket_presenter.get_snapshot().generation > int(picket_record.entity_generation) \
		and remote_picket.visible), "new actual picket activation replaces its terminal prior life")
	var picket_mesh := picket_presenter.get_cue_visual(0) as MeshInstance3D
	var cue_ready: bool = is_instance_valid(picket_mesh) and picket_mesh.mesh != null \
		and picket_mesh.mesh.get_surface_count() > 0
	# The authored emitter material lives on its mesh surface; the network copy
	# retains a per-surface override rather than a whole-instance override.
	var picket_material := picket_mesh.get_active_material(0) as StandardMaterial3D if cue_ready else null
	var mesh_id := picket_mesh.mesh.get_instance_id() if cue_ready else 0
	var material_id := picket_material.get_instance_id() if picket_material != null else 0
	_game.runtime_settings.reduced_flash = true
	_game._apply_opponent_weapon_heat_presentation_profile()
	var live_ready: bool = is_instance_valid(picket_mesh) and picket_mesh.mesh != null \
		and picket_mesh.mesh.get_surface_count() > 0
	var live_material := picket_mesh.get_active_material(0) as StandardMaterial3D if live_ready else null
	_check(cue_ready and live_ready and live_material != null and live_material.emission_energy_multiplier <= 1.0
		and picket_mesh.mesh.get_instance_id() == mesh_id and live_material.get_instance_id() == material_id,
		"public accessibility update retains the real live picket cue mesh/material and changes emission without new allocations")
	_check(hull.mesh.get_instance_id() == retained_mesh and hull.material_override.get_instance_id() == retained_material
		and bool(actor_presenter.get_snapshot().reduced_flash)
		and (hull.material_override as StandardMaterial3D).emission_energy_multiplier <= 1.0,
		"actor copies retain their allocations and reduced flash uses steady lower emission")
	if not second.is_empty():
		var second_visual := (replicator.get("_visuals") as Dictionary)[second.projectile_id] as Dictionary
		_check(is_equal_approx(((second_visual.trail as MeshInstance3D).mesh as CylinderMesh).height, 3.6)
			and is_equal_approx(((second_visual.body as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier, 1.75),
			"reduced flash shortens Emberline trail and lowers emission")
	_mark("second")
	_check(await _wait(func() -> bool: return not remote_raider.visible and remote_tender.visible),
		"unavailable source removes its actor without removing the surviving tender")
	_check(int(actor_presenter.get_snapshot().destruction_cues) == 1, "stream removal does not fabricate a destruction cue")
	_check_stale_actor_records(actor_presenter, actor_snapshot)
	_mark("missing")
	_check(await _wait(func() -> bool: return bool(picket_presenter.get_snapshot().actor.get("retired", false)))
		and not remote_picket.visible, "removed picket retires independently of the surviving convoy tender")
	_check_picket_replays(picket_presenter, picket_record)
	_check(await _wait(func() -> bool: return int(replicator.get_audit().terminals) == 2), "convoy retirement reaches client once")
	_check(replicator.get_drawn_projectile_ids().is_empty() and int(replicator.get_audit().published) == 0,
		"convoy retirement leaves no visual and client publishes no combat")
	_check(await _wait(func() -> bool: return not remote_raider.visible and not remote_tender.visible),
		"generation retirement removes both host actor copies")
	if _role == "late":
		root.remove_child(_game)
		root.add_child(_game)
		await process_frame
		await process_frame
	else:
		_game.shutdown_network_session(&"test_disconnect")
	_check(replicator.get_drawn_projectile_ids().is_empty() and int(replicator.get_audit().observed_pools) == 0,
		"production disconnect clears retained projectile presentation")
	_check((actor_presenter.get_snapshot().actors as Dictionary).is_empty()
		and not remote_raider.visible and not remote_tender.visible and _game.cinder_convoy_host.visible,
		"disconnect retires remote actors and restores retained solo tender visibility")
	_check(picket_presenter.get_snapshot().actor.is_empty() and not remote_picket.visible
		and _picket.visible == solo_picket_visible
		and Vector2i(_picket.collision_layer, _picket.collision_mask) == solo_picket_collision
		and _picket.global_transform == solo_picket_pose and _picket.get("_target") == solo_picket_target
		and _picket.get_lance_charge_snapshot() == solo_picket_charge
		and _picket.get_network_actor_presentation_snapshot() == solo_picket_state
		and bool(_picket.get("_reduced_flash")), "disconnect clears host copy before exact solo picket state and current accessibility restore")
	var resumed := _game.cinder_convoy_threat.get_snapshot()
	_check(bool(resumed.active) and int(resumed.generation) == solo_generation
		and is_equal_approx(float(resumed.attacker_health), solo_health)
		and is_equal_approx(float(resumed.tender_health), 60.0)
		and bool(resumed.attacker_alive) == (solo_health > 0.0),
		"disconnect resumes exact solo threat health without reviving neutralized raider")

func _dead_client() -> void:
	_check(_game.join_network_session("127.0.0.1", _port).get("accepted", false), "late dead peer joins production host")
	_check(await _wait(func() -> bool: return _game._network_emberline_actor_presenter != null \
		and bool((_game._network_emberline_actor_presenter.get_snapshot().actors as Dictionary).get(Actors.RAIDER_ID, {}).get("destroyed", false))),
		"already-neutralized raider reaches the late peer")
	var presenter := _game._network_emberline_actor_presenter
	_check(not presenter.get_visual(Actors.RAIDER_ID).visible and presenter.get_visual(Actors.TENDER_ID).visible
		and int(presenter.get_snapshot().destruction_cues) == 0
		and (_game.get_network_remote_projectile_replicator() == null
			or _game.get_network_remote_projectile_replicator().get_drawn_projectile_ids().is_empty()),
		"late neutralization adopts surviving tender without destruction or launch replay")
	_check(await _wait(func() -> bool: return _game._network_picket_actor_presenter != null \
		and bool(_game._network_picket_actor_presenter.get_snapshot().actor.get("destroyed", false)))
		and not _game._network_picket_actor_presenter.get_visual().visible,
		"late terminal baseline cannot revive a destroyed host picket")


func _stage_picket() -> StandoffPicketOpponent:
	var picket := _game.get_node("StandoffPicket") as StandoffPicketOpponent
	var target := _game.get_node("ShipyardWorld/ExteriorTargetRange/TargetDrone01") as Node3D
	target.set_physics_process(false)
	target.set_process(false)
	var origin := _game._network_station_frame_origin() + Vector3(1000, 0, 0)
	target.global_position = origin + Vector3(0, 0, -180)
	picket.escort_enabled = false
	_check(bool(picket.activate(Transform3D(Basis.IDENTITY, origin)).get("accepted", false)), "actual picket activation stages authored actor")
	picket.set_target(target)
	picket.set_physics_process(false)
	picket.set_process(false)
	picket._physics_process(picket.initial_arming_delay + 0.01)
	picket._update_presentation(0.0)
	_check(bool(picket.get_lance_charge_snapshot().active)
		and bool(picket.get_standoff_intent_cue_snapshot().active)
		and bool(picket.get_posture_cue_snapshot().active), "actual picket physics arms and commits its charge, aim and movement cues")
	if _role == "host":
		var file := FileAccess.open(_directory + "/picket-state", FileAccess.WRITE)
		file.store_var(picket.get_network_actor_presentation_snapshot())
		file.close()
	return picket


func _check_picket_replays(presenter: PicketActors, old: Dictionary) -> void:
	var before: Dictionary = presenter.get_snapshot()
	var current := (before.actor as Dictionary).duplicate(true)
	var previous := old.duplicate(true)
	previous.pose_tick = int(current.pose_tick) + 100
	var epoch := current.duplicate(true)
	epoch.actor_epoch = int(epoch.actor_epoch) + 1
	epoch.pose_tick = int(epoch.pose_tick) + 100
	var revive := current.duplicate(true)
	revive.health = float(revive.maximum_health)
	revive.destroyed = false
	revive.retired = false
	revive.available = true
	revive.present = true
	revive.pose_tick = int(revive.pose_tick) + 100
	var malformed := current.duplicate(true)
	malformed.cues[0][0] = Transform3D(Basis.IDENTITY, Vector3(INF, 0, 0))
	malformed.pose_tick = int(malformed.pose_tick) + 100
	var actor_origin := _game._network_station_frame_origin()
	var convoy_before := _game._network_emberline_actor_presenter.get_snapshot()
	var audio_before := int(_game.combat_audio.get_state_snapshot().cue_count)
	presenter.consume_movement_section([previous, epoch, revive, malformed, current], actor_origin)
	_check(presenter.get_snapshot() == before and not presenter.get_visual().visible
		and _game._network_emberline_actor_presenter.get_snapshot() == convoy_before
		and int(_game.combat_audio.get_state_snapshot().cue_count) == audio_before,
		"stale epoch/life/tick, malformed cue and same-life resurrection reject atomically without convoy or audio mutation")

func _check_stale_actor_records(presenter: NetworkEmberlineActorPresenter, old_snapshot: Dictionary) -> void:
	var before := presenter.get_snapshot()
	var current := ((before.actors as Dictionary)[Actors.RAIDER_ID] as Dictionary).duplicate(true)
	var prior := ((old_snapshot.actors as Dictionary)[Actors.RAIDER_ID] as Dictionary).duplicate(true)
	prior.pose_tick = int(current.pose_tick) + 100
	var epoch := current.duplicate(true)
	epoch.convoy_epoch = int(epoch.convoy_epoch) + 1
	epoch.pose_tick = int(epoch.pose_tick) + 100
	var resurrect := current.duplicate(true)
	resurrect.present = true
	resurrect.available = true
	resurrect.retired = false
	resurrect.pose_tick = int(resurrect.pose_tick) + 100
	presenter.consume_movement_section([prior, epoch, resurrect, current], _game._network_station_frame_origin())
	_check(presenter.get_snapshot() == before and not presenter.get_visual(Actors.RAIDER_ID).visible,
		"prior generation, other epoch, retired resurrection and duplicate pose cannot replay actors")

func _spawn(role: String) -> void:
	var parent_args := OS.get_cmdline_args()
	var project_path := ProjectSettings.globalize_path("res://")
	var path_index := parent_args.find("--path")
	if path_index >= 0 and path_index + 1 < parent_args.size():
		project_path = parent_args[path_index + 1]
	elif project_path.is_empty():
		project_path = DirAccess.open(".").get_current_dir()
	var previous_xdg := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", _directory + "/" + role + "-xdg")
	var engine_args := PackedStringArray([
		"--headless", "--audio-driver", "Dummy", "--path", project_path,
		"--log-file", _directory + "/" + role + ".log", "--script", "res://tests/network_emberline_bolt_test.gd"])
	# Godot consumes --main-pack before exposing engine arguments. Carry the
	# explicitly supplied package probe path, then verify project.binary in
	# every process so a child cannot silently fall back to source.
	if not _package_under_test.is_empty():
		engine_args.append_array(PackedStringArray(["--main-pack", _package_under_test]))
	engine_args.append_array(PackedStringArray(["--", role, str(_port), _directory]))
	if not _package_under_test.is_empty():
		engine_args.append_array(PackedStringArray(["--package-under-test", _package_under_test]))
	var pid := OS.create_process(OS.get_executable_path(), engine_args)
	OS.set_environment("XDG_DATA_HOME", previous_xdg)
	_check(pid > 0, "spawn independent %s process" % role)
	_children.append(pid)

func _wait_marker(role: String, stage: String) -> bool:
	var arrived := await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/" + role + "-" + stage) \
		or FileAccess.file_exists(_directory + "/" + role + "-failed"))
	var passed := arrived and not FileAccess.file_exists(_directory + "/" + role + "-failed")
	_check(passed, "%s reaches %s" % [role, stage])
	return passed

func _wait(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + int(PEER_TIMEOUT * 1000)
	while Time.get_ticks_msec() < deadline:
		if _role == "host" and _game != null:
			_game._physics_process(1.0 / 60.0)
		if predicate.call():
			return true
		await process_frame
	return predicate.call()

func _mark(stage: String) -> void:
	var file := FileAccess.open(_directory + "/" + _role + "-" + stage, FileAccess.WRITE)
	if file != null:
		file.store_string("ok")
		file.close()

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
