extends SceneTree

## Real production Main instances in independent processes, using an ephemeral
## ENet port. Host-owned Emberline flights cross the existing GameFlow dispatcher.
const MAIN := preload("res://scenes/main.tscn")
const Replicator := preload("res://scripts/network/network_remote_projectile_replicator.gd")
const Actors := preload("res://scripts/network/network_emberline_actor_presenter.gd")
const PEER_TIMEOUT := 45.0
var _game: GameFlow
var _failures: Array[String] = []
var _assertions := 0
var _children: Array[int] = []
var _directory := ""
var _role := "host"
var _port := 0
var _package_under_test := ""

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
	_game._advance_network_remote_projectiles()
	threat.advance(3.01, replacement_generation)
	if not await _wait_marker("client", "second") or not await _wait_marker("late", "second"):
		return
	var attacker := threat.get_attacker()
	threat.remove_child(attacker)
	if not await _wait_marker("client", "missing") or not await _wait_marker("late", "missing"):
		attacker.free()
		return
	attacker.free()
	threat.retire(replacement_generation)
	if not await _wait_marker("client", "finished") or not await _wait_marker("late", "finished"):
		return
	_check(int(replicator.get_audit().publish_failures) == 0, "all launches and terminals use the existing publisher")
	for pid in _children:
		var deadline := Time.get_ticks_msec() + 4000
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not OS.is_process_running(pid), "independent client exits cleanly")

func _client() -> void:
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
