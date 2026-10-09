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
var _previous_measured_snapshot: Dictionary = {}

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
	var offset: Vector3 = {"host": Vector3(-31, -4, -48), "client": Vector3(22, 3, 17), "late": Vector3(-5, 2, 91), "operation-late": Vector3(8, -2, 64), "fleet-late": Vector3(-20, -6, 37)}[_role]
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
	_assert_retained_fleet_envelope()
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve ephemeral loopback port")
	_port = probe.get_local_port()
	probe.stop()
	_game._ensure_lan_discovery().discovery_port = 0
	_check(_game.host_network_session(_port, 3).get("accepted", false), "production Main hosts")
	# Seed the existing publisher's bounded past-pilot roster without changing
	# any craft or boarding authority, then let its real coast owner expire.
	var previously_observed: Dictionary = {}
	for ship: HeroShip in _game.ships:
		previously_observed[ship.get_ship_id()] = {"craft": ship, "peer_id": 1}
	_game._network_craft_pose_stream.build_host_entries(previously_observed, 0, _game.ships,
		maxi(1, _game._network_hud_session_epoch), _game._network_station_frame_origin())
	_game._network_boarding_server_tick = Pose.COAST_TICKS + 3
	_spawn("client")
	if not await _wait_marker("client", "ready"):
		return
	_craft.global_position += Vector3(0, 30, 0)
	_game._piloting = true
	_write("pose", _craft.global_position - _game._network_station_frame_origin())
	if not await _wait_marker("client", "pose"):
		return
	_game._piloting = false
	_craft.request_engine_start()
	_write("starting", true)
	if not await _wait_marker("client", "starting"):
		return
	_craft.get_component_damage().record_damage(_craft.maximum_hull * 0.5)
	_craft._sync_engine_visuals_immediately()
	_write("starting-grade", _craft.get_network_damage_presentation_snapshot().components)
	if not await _wait_marker("client", "starting-grade"):
		return
	_craft._update_engine(_craft.engine_start_time + 0.01)
	_write("engine-witness", true)
	if not await _wait_marker("client", "engine-witness"):
		return
	_assert_snapshot_envelope("running engine")
	var second := _game.get_node("HalyardCrewTransport") as HeroShip
	second.request_engine_start()
	second._update_engine(second.engine_start_time + 0.01)
	second.apply_damage(second.maximum_hull * 0.45)
	second._sync_engine_visuals_immediately()
	_assert_snapshot_envelope("two operated and damaged craft")
	_spawn("operation-late")
	if not await _wait_marker("operation-late", "engine-witness"):
		return
	_check(_craft.request_landing(_craft.global_transform), "host landing owner accepts held touchdown")
	for _i in 180:
		if not _craft.is_landing_active():
			break
		_craft._update_landing(0.1)
	_craft.request_engine_stop(false)
	_craft.set_canopy_open(true, 0.0)
	_write("dock-witness", true)
	if not await _wait_marker("client", "dock-witness") or not await _wait_marker("operation-late", "dock-witness"):
		return
	_game._network_boarding_server_tick += Pose.COAST_TICKS + Pose.STALE_SAMPLE_TICKS
	_write("operation-coast", true)
	if not await _wait_marker("client", "operation-coast") or not await _wait_marker("operation-late", "finished"):
		return
	_assert_snapshot_envelope("settled dock")
	var before_rebase := _game._build_network_craft_pose_entries()
	var shift := Vector3(41, -7, 29)
	for child in _game.get_children():
		if child is Node3D and (child == _game.world or child is HeroShip or child is PlayerController):
			(child as Node3D).global_position += shift
	var after_rebase := _game._build_network_craft_pose_entries()
	var before_stream := Pose.new()
	var after_stream := Pose.new()
	before_stream.bind_replica_craft_presentations(_game.ships)
	after_stream.bind_replica_craft_presentations(_game.ships)
	var stable := before_stream.consume_movement_section(before_rebase) == _game.ships.size() \
		and after_stream.consume_movement_section(after_rebase) == _game.ships.size()
	for ship: HeroShip in _game.ships:
		var prior := before_stream.latest_sample(ship.get_ship_id())
		var rebased := after_stream.latest_sample(ship.get_ship_id())
		stable = stable and not prior.is_empty() and not rebased.is_empty()
		if prior.is_empty() or rebased.is_empty():
			continue
		stable = stable and (prior.position as Vector3).distance_to(rebased.position as Vector3) < 0.001
		prior.erase("position")
		rebased.erase("position")
		stable = stable and prior == rebased
	_check(stable, "all-nine settled station-frame facts survive whole-world rebase within millimeter float precision")
	_game._piloting = true
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
	var fleet: Dictionary = {}
	for index in _game.ships.size():
		var ship := _game.ships[index] as HeroShip
		ship.request_engine_start()
		ship._update_engine(ship.engine_start_time + 0.01)
		ship.apply_damage(ship.maximum_hull * (0.12 + float(index) * 0.025))
		ship._sync_engine_visuals_immediately()
		fleet[ship.get_ship_id()] = {"hull": ship.get_network_damage_presentation_snapshot(),
			"operation": ship.get_network_operation_presentation_snapshot()}
	_write("fleet", fleet)
	_assert_snapshot_envelope("nine operated craft with varied committed parked damage")
	_spawn("fleet-late")
	if not await _wait_marker("client", "fleet") or not await _wait_marker("late", "fleet") \
			or not await _wait_marker("fleet-late", "finished"):
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
	var solo_engine: Variant = _craft.get("_engine_state")
	var solo_landed := bool(_craft.get("_landed"))
	var solo_docked := bool(_craft.get("_docked_latch"))
	var solo_canopy := bool(_craft.get("_canopy_open"))
	_craft._sync_engine_visuals_immediately()
	var source_renderers := _craft.get_network_operation_presentation_snapshot()
	_check(_game.join_network_session("127.0.0.1", _port).get("accepted", false), "production independent client joins")
	_check(await _wait(func() -> bool: return not _game.get_network_session().get_server_offer().is_empty()), "client admitted")
	_check(await _wait(func() -> bool: return _game._network_craft_pose_stream.get_tracked_ship_ids().size() == _game.ships.size()),
		"real full peer snapshot admits the complete retained nine-craft roster")
	_mark("ready")
	if _role == "fleet-late":
		await _assert_fleet_presentation()
		_check(_craft.get("_engine_state") == solo_engine and _craft.get_network_damage_presentation_snapshot() == solo,
			"varied late fleet adoption remains visual and keeps solo authority")
		return
	if _role == "operation-late":
		_check(await _wait(func() -> bool: return bool((_craft.get("_engine_glows") as Array)[0].visible)),
			"late live peer quietly adopts the running host engine")
		_check(_craft.get("_engine_state") == solo_engine and _craft.get("_docked_latch") == solo_docked,
			"late engine adoption keeps source operation authority")
		_mark("engine-witness")
		_check(await _wait(func() -> bool: return (_craft.get("_canopy_pivot") as Node3D).rotation.x > 0.1),
			"late peer follows host touchdown canopy and engine stop")
		_mark("dock-witness")
		await _assert_parked_operation(solo_engine, solo_landed, solo_docked, solo_canopy)
		_game.shutdown_network_session(&"operation_peer_complete")
		_check((_craft.get_network_operation_presentation_audit().state as Dictionary).is_empty()
			and _craft.get_network_operation_presentation_snapshot().renderers == source_renderers.renderers,
			"live late disconnect restores source renderer transforms/material grades/lights")
		return
	if _role == "client":
		_check(await _wait(func() -> bool: return _game._network_craft_pose_stream.has_samples(_craft.get_ship_id())), "host pose reaches the client")
		_check(await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/pose") and (_craft.global_position - _game._network_station_frame_origin()).distance_to(_read("pose") as Vector3) < 0.5),
			"client draws the held host craft in its own station frame")
		_mark("pose")
		_check(await _wait(func() -> bool: return _craft.get_network_operation_presentation_audit().state.get("engine") == HeroShip.ENGINE_STARTING),
			"real host STARTING engine phase reaches current observer")
		_game.runtime_settings.reduced_flash = true
		_game._apply_combat_effect_reduced_flash()
		var starting := _craft.get_network_operation_presentation_audit().state as Dictionary
		_mark("starting")
		_check(await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/starting-grade") \
			and _craft.get_network_operation_presentation_audit().state.get("grade", []).back() == _read("starting-grade")),
			"reduced-flash STARTING latch rebases on committed host component grade")
		_check(_craft.get_network_operation_presentation_audit().state.engine == HeroShip.ENGINE_STARTING
			and starting.grade != _craft.get_network_operation_presentation_audit().state.grade,
			"grade transition retains spool phase without source engine change")
		_mark("starting-grade")
		_check(await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/engine-witness")), "host engine transition is committed")
		_check(await _wait(func() -> bool: return bool((_craft.get("_engine_glows") as Array)[0].visible)),
			"online host exhaust is visible on the independent observer")
		_mark("engine-witness")
		_check(await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/dock-witness")), "host touchdown and stop are committed")
		_check(await _wait(func() -> bool: return (_craft.get("_canopy_pivot") as Node3D).rotation.x > 0.1),
			"docked host canopy pose reaches the independent observer")
		_mark("dock-witness")
		await _assert_parked_operation(solo_engine, solo_landed, solo_docked, solo_canopy)
		_mark("operation-coast")
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
			and source.visible and _craft.get_network_damage_presentation_snapshot() == solo
			and (_craft.get_network_operation_presentation_audit().state as Dictionary).is_empty(),
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
	await _assert_fleet_presentation()
	_mark("fleet")
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
	await process_frame
	_check((_craft.get_network_operation_presentation_audit().state as Dictionary).is_empty()
		and _craft.get("_engine_state") == solo_engine and bool(_craft.get("_landed")) == solo_landed
		and bool(_craft.get("_docked_latch")) == solo_docked and bool(_craft.get("_canopy_open")) == solo_canopy
		and _craft.get_network_operation_presentation_snapshot().renderers == source_renderers.renderers,
		"session/reentry fences deferred operation callbacks and restores exact retained source renderers/owners")


func _assert_fleet_presentation() -> void:
	_check(await _wait(func() -> bool:
		if not FileAccess.file_exists(_directory + "/fleet"):
			return false
		var value: Variant = _read("fleet")
		if not value is Dictionary:
			return false
		var fleet: Dictionary = value
		for ship: HeroShip in _game.ships:
			var expected: Dictionary = fleet[ship.get_ship_id()]
			var hull := ship.get_network_damage_presentation_audit().state as Dictionary
			var operation := ship.get_network_operation_presentation_audit().state as Dictionary
			if hull.get("health", -1.0) != expected.hull.health or hull.get("components", []) != expected.hull.components \
					or operation.get("engine") != expected.operation.engine:
				return false
		return true), "current/late full peers present exact all-nine operated hull/component/engine facts")


func _assert_parked_operation(engine: Variant, landed: bool, docked: bool, canopy: bool) -> void:
	_check(await _wait(func() -> bool: return FileAccess.file_exists(_directory + "/operation-coast") \
		and not bool(_game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()).get("pose_active", true))),
		"settled operation row survives host-on-foot motion coast")
	var operation := _craft.get_network_operation_presentation_audit().state as Dictionary
	_check(operation.get("engine") == HeroShip.ENGINE_OFFLINE and bool(operation.get("docked", false))
		and bool(operation.get("landed", false)) and not bool((_craft.get("_engine_glows") as Array)[0].visible)
		and (_craft.get("_canopy_pivot") as Node3D).rotation.x > 0.1,
		"parked dock canopy/readout and stopped exhaust remain coherent after pose expiry")
	_check(_craft.get("_engine_state") == engine and bool(_craft.get("_landed")) == landed
		and bool(_craft.get("_docked_latch")) == docked and bool(_craft.get("_canopy_open")) == canopy,
		"remote landing/dock facts never write source engine/landing/canopy authority")
	var stream := _game._network_craft_pose_stream
	var sample := stream.latest_sample(_craft.get_ship_id())
	var pose := _craft.global_transform
	stream.advance_replica([_craft], null, null, 0.0, 1.0 / 60.0)
	_craft.global_position += Vector3(0.5, 0.0, 0.0)
	var displaced := _craft.global_transform
	stream.advance_replica([_craft], null, null, 0.0, 1.0 / 60.0)
	_check(_craft.global_transform == displaced and int(stream.latest_sample(_craft.get_ship_id()).pose_tick) == int(sample.pose_tick),
		"operation-only updates cannot freshen or repeatedly apply the frozen settled pose")
	_craft.global_transform = pose


func _assert_retained_fleet_envelope() -> void:
	var stream := Pose.new()
	var pilots: Dictionary = {}
	for ship: HeroShip in _game.ships:
		pilots[ship.get_ship_id()] = {"craft": ship, "peer_id": 1}
	stream.build_host_entries(pilots, 0, _game.ships, 1, _game._network_station_frame_origin())
	var entries := stream.build_host_entries({}, Pose.COAST_TICKS + 3, _game.ships, 1, _game._network_station_frame_origin())
	var wire := Pose.pack_display_facts(entries)
	var consumer := Pose.new()
	consumer.bind_replica_craft_presentations(_game.ships)
	_check(consumer.consume_movement_section(wire) == _game.ships.size(),
		"all supported real craft retained display rows decode through the owning pose validators")
	var definition_probe := _game.get_node("HalyardCrewTransport") as HeroShip
	var retained_definition := definition_probe.ship_definition
	definition_probe.set_network_damage_presentation_enabled(true)
	definition_probe.apply_network_operation_presentation(consumer.latest_sample(definition_probe.get_ship_id()))
	_check(not (definition_probe.get_network_operation_presentation_audit().core_materials as Dictionary).is_empty(),
		"copied variant core materials have instance ownership")
	definition_probe.ship_definition = retained_definition.duplicate(true) as ShipDefinition
	consumer.ensure_replica_craft_presentations(_game.ships)
	_check(not consumer.has_samples(definition_probe.get_ship_id()) and consumer.get_tracked_ship_ids().size() == _game.ships.size() - 1
		and (definition_probe.get_network_operation_presentation_audit().state as Dictionary).is_empty()
		and (definition_probe.get_network_operation_presentation_audit().core_materials as Dictionary).is_empty(),
		"definition replacement retires only affected decoded history and private renderer resources")
	definition_probe.ship_definition = retained_definition
	definition_probe.set_network_damage_presentation_enabled(false)
	consumer.ensure_replica_craft_presentations(_game.ships)
	_check(consumer.consume_movement_section(wire) == 1, "restored authored shape admits fresh facts after cache retirement")
	var size := Marshalls.variant_to_base64(wire).to_utf8_buffer().size()
	_check(size < 8000, "retained nine-craft display baseline stays bounded (%d movement bytes)" % size)
	var corrupt := (wire[0] as Dictionary).duplicate(true)
	corrupt.display_facts = PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])
	var malformed := (wire[0] as Dictionary).duplicate(true)
	malformed.display_size = var_to_bytes([false]).size()
	malformed.display_facts = var_to_bytes([false]).compress(FileAccess.COMPRESSION_ZSTD)
	var mismatch := (wire[0] as Dictionary).duplicate(true)
	mismatch.entity_generation = int(mismatch.entity_generation) + 1
	var duplicate := (wire[0] as Dictionary).duplicate(true)
	var duplicate_facts: Array = bytes_to_var(duplicate.display_facts.decompress(int(duplicate.display_size), FileAccess.COMPRESSION_ZSTD))
	duplicate_facts[1] = duplicate_facts[0]
	duplicate.display_size = var_to_bytes(duplicate_facts).size()
	duplicate.display_facts = var_to_bytes(duplicate_facts).compress(FileAccess.COMPRESSION_ZSTD)
	var wrong_identity := (wire[0] as Dictionary).duplicate(true)
	wrong_identity.entity_id = &"unrelated-pose"
	var inflated := (wire[0] as Dictionary).duplicate(true)
	inflated.display_size = Pose.MAX_DISPLAY_INFLATED_BYTES + 1
	var shape_mismatch := (wire[0] as Dictionary).duplicate(true)
	var mismatched_facts: Array = bytes_to_var(shape_mismatch.display_facts.decompress(int(shape_mismatch.display_size), FileAccess.COMPRESSION_ZSTD))
	mismatched_facts[0][8][4] = int(mismatched_facts[0][8][4]) + 1
	shape_mismatch.display_size = var_to_bytes(mismatched_facts).size()
	shape_mismatch.display_facts = var_to_bytes(mismatched_facts).compress(FileAccess.COMPRESSION_ZSTD)
	var rejected := true
	for probe: Dictionary in [corrupt, malformed, mismatch, duplicate, wrong_identity, inflated, shape_mismatch]:
		var receiver := Pose.new()
		receiver.bind_replica_craft_presentations(_game.ships)
		rejected = rejected and receiver.consume_movement_section([probe]) == 0
	_check(rejected, "individual corrupt/malformed/identity/duplicate/size/life/shape probes refuse display facts")

func _assert_snapshot_envelope(label: String) -> void:
	var snapshot: Dictionary = {}
	for _attempt in 3:
		_game._physics_process(1.0 / 60.0)
		snapshot = _game.get_network_session().get_authoritative_snapshot()
		var pose_count := 0
		for row: Dictionary in snapshot.sections[&"movement"]:
			pose_count += 1 if StringName(row.get("mode", &"")) == Pose.MODE else 0
		if pose_count == _game.ships.size():
			break
	_check((snapshot.sections[&"movement"] as Array).size() >= _game.ships.size(),
		"envelope measure uses an actual nine-craft publication tick")
	var codec := NetworkSnapshotDeltaCodec.new()
	var full := codec.encode(snapshot, true)
	var full_size := Marshalls.variant_to_base64(full).to_utf8_buffer().size()
	var delta_codec := NetworkSnapshotDeltaCodec.new()
	var previous := _previous_measured_snapshot if not _previous_measured_snapshot.is_empty() else snapshot
	var baseline := delta_codec.encode(previous, true)
	var delta := delta_codec.encode(snapshot)
	var delta_size := Marshalls.variant_to_base64(delta).to_utf8_buffer().size()
	var receiver := NetworkSnapshotDeltaCodec.new()
	var accepted_baseline := receiver.decode(baseline)
	var accepted_delta := receiver.decode(delta)
	var accepted_full := NetworkSnapshotDeltaCodec.new().decode(full)
	_check(full_size <= NetworkSnapshotFragmenter.MAX_PACKET_BYTES
		and not NetworkSnapshotFragmenter.new().fragment(full, 1, int(snapshot.revision)).is_empty()
		and delta_size <= NetworkSnapshotFragmenter.MAX_PACKET_BYTES
		and not NetworkSnapshotFragmenter.new().fragment(delta, 2, int(snapshot.revision)).is_empty()
		and bool(accepted_baseline.get("accepted", false)) and bool(accepted_delta.get("accepted", false))
		and accepted_delta.get("packet", {}) == snapshot and bool(accepted_full.get("accepted", false))
		and accepted_full.get("packet", {}) == snapshot,
		"%s actual current/late full and live-delta envelopes preserve exact facts within unchanged ceiling (%d bytes; delta %d)" % [label, full_size, delta_size])
	_previous_measured_snapshot = snapshot.duplicate(true)

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
	var args := PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", project_path,
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
			for _tick in 3:
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
	var path := _directory + "/" + stage
	# Peers poll the final path. Publish only after the complete serialized
	# witness is closed, using a private file on the same filesystem.
	var pending_path := path + ".%d.pending" % OS.get_process_id()
	var file := FileAccess.open(pending_path, FileAccess.WRITE)
	if file == null:
		_check(false, "open private %s witness" % stage)
		return
	file.store_var(value)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(pending_path, path)
	if error != OK:
		DirAccess.remove_absolute(pending_path)
		_check(false, "publish complete %s witness" % stage)

func _read(stage: String) -> Variant:
	var file := FileAccess.open(_directory + "/" + stage, FileAccess.READ)
	if file == null:
		return null
	# store_var already writes a four-byte payload length. Do not decode an
	# absent or incomplete witness while a peer is polling for publication.
	var size := file.get_length()
	if size < 8 or file.get_32() != size - 4:
		file.close()
		return null
	file.seek(0)
	var value: Variant = file.get_var()
	file.close()
	return value

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
