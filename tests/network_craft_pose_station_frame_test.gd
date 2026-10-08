extends SceneTree

## Production Main peers in independent processes. Craft pose, hull and shared
## component presentation cross the existing authenticated snapshot channel.
const MAIN := preload("res://scenes/main.tscn")
const Pose := preload("res://scripts/network/network_remote_craft_pose_stream.gd")
const TIMEOUT := 60.0
var _game: GameFlow
var _craft: HeroShip
var _role := "host"
var _directory := ""
var _port := 0
var _package_under_test := ""
var _children: Array[int] = []
var _failures: Array[String] = []
var _assertions := 0

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
		_check(FileAccess.file_exists("res://project.binary"), "every process loads the requested package")
	if args.size() == 3:
		_role = args[0]
		_port = int(args[1])
		_directory = args[2]
	else:
		_directory = OS.get_user_data_dir().path_join("craft-hull-test-%d" % OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(_directory)
	_game = MAIN.instantiate() as GameFlow
	_check(_game.configure_runtime_settings_persistence(
		UserDataStore.new(_directory + "/" + _role + "-save.json"), _directory + "/" + _role + "-legacy.cfg"),
		"each production peer uses private saves")
	root.add_child(_game)
	await process_frame
	await physics_frame
	_game.start_shift()
	await process_frame
	await physics_frame
	_game.set_physics_process(false)
	_game.set_process(false)
	for ship: HeroShip in _game.ships:
		ship.set_physics_process(false)
	_craft = _game.active_ship
	var offset: Vector3 = {"host": Vector3(-31, -4, -48), "client": Vector3(22, 3, 17), "late": Vector3(-5, 2, 91)}[_role]
	for child in _game.get_children():
		if child is Node3D and (child == _game.world or child is HeroShip or child is PlayerController):
			(child as Node3D).global_position += offset
	if _role == "host":
		await _host()
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
		print("NETWORK_CRAFT_POSE_STATION_FRAME_TEST_OK: %d host assertions" % _assertions if _role == "host" \
			else "NETWORK_CRAFT_HULL_PEER_COMPLETE %s: %d assertions" % [_role, _assertions])
		_mark("finished")
		quit(0)
	else:
		print("NETWORK_CRAFT_HULL_TEST_FAILED %s: %s" % [_role, "; ".join(_failures)])
		_mark("failed")
		quit(1)

func _host() -> void:
	# A pristine hull may already have committed section damage when hosting
	# begins. Its very first observation must publish without a pilot or hit.
	var component_only := _game.ships[1] as HeroShip
	component_only.get_component_damage().record_damage(component_only.maximum_hull * 0.5)
	var initial_entries := Pose.new().build_host_entries({}, 0, [component_only], 1)
	_check(initial_entries.size() == 1 and int(initial_entries[0].entity_generation) == 1
		and is_equal_approx(float(initial_entries[0].hull_presentation.health), component_only.maximum_hull),
		"first unpiloted observation publishes existing component-only damage in its original life")
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve ephemeral loopback port")
	_port = probe.get_local_port()
	probe.stop()
	_check(_game.host_network_session(_port, 3).get("accepted", false), "production Main hosts")
	_spawn("client")
	if not await _wait_marker("client", "ready"):
		return
	_craft.global_position += Vector3(0, 30, 0)
	_game._piloting = true
	_write("pose", _craft.global_position - _game._network_station_frame_origin())
	if not await _wait_marker("client", "pose"):
		return
	_craft.apply_damage(_craft.maximum_hull * 0.5)
	_write("wounded", _craft.get_network_damage_presentation_snapshot())
	if not await _wait_marker("client", "wounded"):
		return
	_game._piloting = false
	_craft.apply_damage(_craft.maximum_hull + 1.0)
	if not await _wait_marker("client", "dead"):
		return
	_game._network_boarding_server_tick += Pose.COAST_TICKS + Pose.STALE_SAMPLE_TICKS
	_game._physics_process(1.0 / 60.0)
	_check(_game._network_craft_pose_stream.is_host_tracking(_craft.get_ship_id()), "terminal hull remains published beyond the old coast window")
	_spawn("late")
	if not await _wait_marker("late", "dead"):
		return
	# Use the production berth-regeneration owner after its real deadline ages.
	_game._update_pending_regeneration(0.0)
	_check(not _craft.is_destroyed() and int(_craft.get_component_damage().get_ledger_generation()) == 2,
		"production berth transaction regenerates the same craft and advances its component life once")
	_write("regenerated", _craft.global_position - _game._network_station_frame_origin())
	if not await _wait_marker("client", "regenerated") or not await _wait_marker("late", "regenerated"):
		return
	_game._network_boarding_server_tick += Pose.COAST_TICKS + Pose.STALE_SAMPLE_TICKS
	if not await _wait_marker("client", "coasted") or not await _wait_marker("late", "coasted"):
		return
	_check(not _game._network_craft_pose_stream.is_host_tracking(_craft.get_ship_id()), "alive reused craft leaves the publisher after coasting")
	_craft.get_component_damage().record_damage(_craft.maximum_hull * 0.5)
	if not await _wait_marker("client", "component") or not await _wait_marker("late", "component"):
		return
	_game._network_boarding_server_tick += Pose.COAST_TICKS + Pose.STALE_SAMPLE_TICKS
	if not await _wait_marker("client", "component-held") or not await _wait_marker("late", "component-held"):
		return
	_craft.apply_damage(_craft.maximum_hull * 0.5)
	if not await _wait_marker("client", "reopened") or not await _wait_marker("late", "reopened"):
		return
	_game._network_boarding_server_tick += Pose.COAST_TICKS + Pose.STALE_SAMPLE_TICKS
	if not await _wait_marker("client", "held") or not await _wait_marker("late", "held"):
		return
	_check(await _wait_marker("client", "finished") and await _wait_marker("late", "finished"), "both independent clients complete retained recovery")
	for pid in _children:
		_check(await _wait(func() -> bool: return not OS.is_process_running(pid)), "independent client exits")

func _client() -> void:
	_craft.apply_damage(_craft.maximum_hull * 0.2)
	var solo := _craft.get_network_damage_presentation_snapshot()
	var source := _craft.get_damage_presentation()
	var source_power := source.get_engine_power_multiplier()
	var source_visibility := _craft.get_variant_visual_root().visible
	var source_layer := _craft.collision_layer
	var source_mask := _craft.collision_mask
	_check(_game.join_network_session("127.0.0.1", _port).get("accepted", false), "production independent client joins")
	_check(await _wait(func() -> bool: return not _game.get_network_session().get_server_offer().is_empty()), "client admitted")
	_mark("ready")
	if _role == "client":
		_check(await _wait(func() -> bool: return _game._network_craft_pose_stream.has_samples(_craft.get_ship_id())), "host pose reaches the client")
		_check(await _wait(func() -> bool: return (_craft.global_position - _game._network_station_frame_origin()).distance_to(_read("pose") as Vector3) < 0.5),
			"client draws the held host craft in its own station frame")
		_mark("pose")
		_check(await _wait(func() -> bool: return is_equal_approx(float(_craft.get_network_damage_presentation_audit().state.get("health", -1)), _craft.maximum_hull * 0.5)),
			"committed host hull damage grades the remote rig")
		var rig := _craft.get_network_damage_presentation_audit().rig as HeroDamagePresentation
		var expected := _read("wounded") as Dictionary
		_check(rig.get_health_ratio() == 0.5 and _craft.get_network_damage_presentation_audit().state.components == expected.components,
			"the shared rig presents the exact host component roster and wounded hull")
		_check(_craft.get_network_damage_presentation_snapshot() == solo and source.get_engine_power_multiplier() == source_power,
			"remote display leaves local hull, components and flight multiplier untouched")
		_game._piloting = true
		_game._advance_network_craft_pose_replica(1.0 / 60.0)
		_check((_craft.get_network_damage_presentation_audit().state as Dictionary).is_empty()
			and source.visible and _craft.get_network_damage_presentation_snapshot() == solo,
			"local-authority flight eligibility restores its source and refuses remote damage display")
		_game._piloting = false
		_check(await _wait(func() -> bool: return not (_craft.get_network_damage_presentation_audit().state as Dictionary).is_empty()),
			"returning to observer eligibility resumes only the retained display rig")
		_mark("wounded")
	_check(await _wait(func() -> bool: return bool(_craft.get_network_damage_presentation_audit().state.get("destroyed", false))), "host hull loss reaches the client")
	var dead := _game._network_craft_pose_stream.latest_sample(_craft.get_ship_id())
	var dead_rig := _craft.get_network_damage_presentation_audit().rig as HeroDamagePresentation
	_check(not _craft.get_variant_visual_root().visible and _craft.collision_layer == 0 and _craft.collision_mask == 0
		and dead_rig.get_status() == &"destroyed", "destroyed remote hull and its ghost collision are absent")
	_check(int(_craft.get_network_damage_presentation_audit().destruction_cues) == (1 if _role == "client" else 0),
		"current destruction occurs once and late dead adoption replays no burst")
	var stale := dead.duplicate(true)
	stale.destroyed = false
	stale.hull_presentation.health = _craft.maximum_hull
	stale.pose_tick = int(stale.pose_tick) + 100
	stale.entity_id = Pose.pose_entity_id(_craft.get_ship_id())
	stale.owner_peer_id = 1
	stale.mode = Pose.MODE
	_game._network_craft_pose_stream.consume_movement_section([stale])
	_check(bool(_game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()).destroyed), "same-life healthy replay cannot resurrect the terminal hull")
	_game.runtime_settings.reduced_flash = true
	_game._apply_combat_effect_reduced_flash()
	_check(dead_rig.is_reduced_flash_enabled(), "copied rig follows reduced flash during a paused interval")
	_mark("dead")
	_check(await _wait(func() -> bool: return int(_craft.get_network_damage_presentation_audit().state.get("generation", 0)) == 2 \
		and not bool(_craft.get_network_damage_presentation_audit().state.get("destroyed", true))), "new host life reopens the same retained client hull")
	_check(_craft.get_variant_visual_root().visible and _craft.collision_layer == source_layer and _craft.collision_mask == source_mask
		and is_equal_approx(dead_rig.get_health_ratio(), 1.0) and dead_rig.get_component_effect_ids().is_empty()
		and dead_rig == _craft.get_network_damage_presentation_audit().rig,
		"regeneration restores hull/collision and clears old damage using the same display rig")
	_check(await _wait(func() -> bool: return (_craft.global_position - _game._network_station_frame_origin()).distance_to(_read("regenerated") as Vector3) < 0.5),
		"regenerated craft reaches its host-owned berth in station coordinates")
	var generation_before := _game._network_craft_pose_stream.latest_sample(_craft.get_ship_id())
	dead.pose_tick = int(generation_before.pose_tick) + 100
	dead.entity_id = Pose.pose_entity_id(_craft.get_ship_id())
	dead.owner_peer_id = 1
	dead.mode = Pose.MODE
	var epoch := generation_before.duplicate(true)
	epoch.entity_id = Pose.pose_entity_id(_craft.get_ship_id())
	epoch.owner_peer_id = 1
	epoch.mode = Pose.MODE
	epoch.craft_epoch = int(epoch.craft_epoch) + 1
	epoch.pose_tick = int(epoch.pose_tick) + 100
	_game._network_craft_pose_stream.consume_movement_section([dead, epoch])
	_check(_game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()) == generation_before,
		"prior terminal life and another session epoch cannot replace regenerated state")
	_mark("regenerated")
	_check(await _wait(func() -> bool: return (_craft.get_network_damage_presentation_audit().state as Dictionary).is_empty()), "alive coast expiry clears the temporary hull display")
	_check(source.visible and _craft.get_variant_visual_root().visible == source_visibility
		and _craft.get_network_damage_presentation_snapshot() == solo, "coast expiry restores exact retained source presentation and damage")
	_mark("coasted")
	_check(await _wait(func() -> bool: return is_equal_approx(float(_craft.get_network_damage_presentation_audit().state.get("health", -1)), _craft.maximum_hull) \
		and not dead_rig.get_component_effect_ids().is_empty()), "host component-only damage projects while hull remains full")
	_mark("component")
	_check(await _wait(func() -> bool: return _game._network_craft_pose_stream.get_clock() - float(_game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()).pose_tick) > Pose.STALE_SAMPLE_TICKS),
		"component-only damage outlives its pose coast")
	_check(not dead_rig.get_component_effect_ids().is_empty(), "non-nominal component sections remain visible with full hull after coast")
	_mark("component-held")
	_check(await _wait(func() -> bool: return is_equal_approx(float(_craft.get_network_damage_presentation_audit().state.get("health", -1)), _craft.maximum_hull * 0.5)),
		"fresh committed damage reopens presentation after coast without a new life")
	_mark("reopened")
	_check(await _wait(func() -> bool: return _game._network_craft_pose_stream.get_clock() - float(_game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()).pose_tick) > Pose.STALE_SAMPLE_TICKS),
		"parked damaged craft passes the stale pose window")
	_check(is_equal_approx(float(_craft.get_network_damage_presentation_audit().state.get("health", -1)), _craft.maximum_hull * 0.5),
		"committed parked damage remains displayed beyond pose coast expiry")
	_mark("held")
	if _role == "late":
		root.remove_child(_game)
		root.add_child(_game)
		await process_frame
		await process_frame
	else:
		_game.shutdown_network_session(&"test_disconnect")
	_check((_craft.get_network_damage_presentation_audit().state as Dictionary).is_empty() and source.visible
		and _craft.get_variant_visual_root().visible == source_visibility and _craft.collision_layer == source_layer
		and _craft.collision_mask == source_mask and _craft.get_network_damage_presentation_snapshot() == solo,
		"disconnect and whole-Main reentry restore exact solo hull/components/collision/visibility")

func _spawn(role: String) -> void:
	var previous_xdg := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", _directory + "/" + role + "-xdg")
	var args := PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", _directory + "/" + role + ".log", "--script", "res://tests/network_craft_pose_station_frame_test.gd"])
	if not _package_under_test.is_empty():
		args.append_array(PackedStringArray(["--main-pack", _package_under_test]))
	args.append_array(PackedStringArray(["--", role, str(_port), _directory]))
	if not _package_under_test.is_empty():
		args.append_array(PackedStringArray(["--package-under-test", _package_under_test]))
	var pid := OS.create_process(OS.get_executable_path(), args)
	OS.set_environment("XDG_DATA_HOME", previous_xdg)
	_check(pid > 0, "spawn independent %s" % role)
	_children.append(pid)

func _wait(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + int(TIMEOUT * 1000)
	while Time.get_ticks_msec() < deadline:
		if _role == "host":
			_game._physics_process(1.0 / 60.0)
		else:
			_game._advance_network_craft_pose_replica(1.0 / 60.0)
		if predicate.call():
			return true
		await process_frame
	return predicate.call()

func _wait_marker(role: String, stage: String) -> bool:
	var result := await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/" + role + "-" + stage) \
		or FileAccess.file_exists(_directory + "/" + role + "-failed"))
	result = result and not FileAccess.file_exists(_directory + "/" + role + "-failed")
	_check(result, "%s reaches %s" % [role, stage])
	return result

func _write(stage: String, value: Variant) -> void:
	var file := FileAccess.open(_directory + "/" + stage, FileAccess.WRITE)
	file.store_var(value)
	file.close()

func _read(stage: String) -> Variant:
	var file := FileAccess.open(_directory + "/" + stage, FileAccess.READ)
	return file.get_var() if file != null else null

func _mark(stage: String) -> void:
	var file := FileAccess.open(_directory + "/" + _role + "-" + stage, FileAccess.WRITE)
	file.store_string("ok")
	file.close()

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
