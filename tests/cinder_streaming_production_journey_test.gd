extends SceneTree

## Focused production composition journey for the physics-driven Main binding.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://cinder-streaming-production-settings.json"

var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--cargo-walking-recall"):
		await _run_cargo_walking_recall()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--cargo-landing"):
		await _run_cargo_landing()
		_finish()
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with the Cinder streaming composition")
	if game == null:
		_finish()
		return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store,
			"memory://cinder-streaming-production-legacy.cfg"
		),
		"production journey injects isolated settings before Main startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var player := game.get_node_or_null(^"Player") as PlayerController
	var ship := game.get_guided_ship()
	_check(
		binding != null and bootstrap != null and player != null and ship != null,
		"Main exposes one binding, bootstrap, production Player, and guided ship"
	)
	if binding == null or bootstrap == null or player == null or ship == null:
		await _cleanup(game)
		_finish()
		return

	await _test_composition_startup_and_player_tracking(game, binding, bootstrap, player)
	await _test_ship_outbound_missing_actor_and_reentry(game, binding, bootstrap, player, ship)
	await _cleanup(game)
	await _test_deferred_quality_sync_currentness()
	await _test_queued_binding_boundaries()
	_finish()


## Focused staged floor/recall integration, not an ordinary flight proof. The
## real streaming tick builds Cinder, Player physics establishes real support,
## then Main's actual presentation process decides whether to recall it.
func _run_cargo_walking_recall() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(game.configure_runtime_settings_persistence(store,
		"memory://cinder-walking-recall-legacy.cfg"), "walking recall isolates Main persistence")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var player := game.get_node(^"Player") as PlayerController
	var world := game.get_node(^"ShipyardWorld") as ShipyardWorld
	var binding := game.get_node(^"CinderStreamingProductionBinding") as CinderStreamingProductionBinding
	var bootstrap := game.get_node(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	var ship := _cargo_landing_ship(game, &"jovian_provisional")
	game.runtime_settings.graphics_profile = RuntimeSettings.GraphicsProfile.LOW
	world.apply_visual_quality(NearbySectorCluster.DetailQuality.LOW)
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = LOCATION.get_anchor_position() + Vector3(0.0, 0.0, 499.9)
	var previous_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, previous_tick)
	await _wait_for_cluster(bootstrap)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	_check(cluster != null, "walking recall loads real Cinder through actual actor tracking")
	if cluster == null:
		await _cleanup(game)
		return
	var access := cluster.get_cinder_cargo_access()
	var structure := access.get_node(^"Structure")
	var deck := access.to_global(CinderCargoAccess.BERTH_EXIT_LOCAL)
	var terminal_floor := access.to_global(CinderCargoAccess.DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL)
	# Keep the actual docked hull beside the exit: the native floor-flag
	# transient occurs during ordinary walking beside this physical Jovian.
	game.call(&"_release_ship_berth", ship)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	_cargo_landing_stage_capture(ship, access.get_berth())
	game.call(&"_try_request_landing")
	var landing_deadline := Time.get_ticks_msec() + 120000
	while ship.is_landing_active() and Time.get_ticks_msec() < landing_deadline:
		await physics_frame
		await process_frame
	var dock_report := ship.get_landing_contract_report()
	var docked: bool = (bool(ship.get_telemetry().get("landed", false))
		and bool(dock_report.get("strict_dock_acceptance", false))
		and access.get_berth().get_occupant() == ship
		and game.phase == GameFlow.Phase.SHUT_DOWN)
	_check(docked, "walking recall fixture docks the real Jovian through normal GameFlow landing and actual physics")
	if not docked:
		await _cleanup(game)
		return
	ship.set_piloted(false)
	game.set("_piloting", false)
	game.phase = GameFlow.Phase.APPROACH_SHIP
	var player_id := player.get_instance_id()
	for point: Vector3 in [deck, terminal_floor]:
		var settled: bool = await _cargo_recall_stage_player(game, player, point, true)
		var support := _cargo_recall_support(player, access)
		_check(settled and player.is_on_floor() and is_instance_valid(support)
			and structure.is_ancestor_of(support) and world.to_local(player.global_position).y < -24.0,
			"actual original Player physics establishes current Cinder Structure floor below yard recall boundary")
		if not settled or not is_instance_valid(support) or not structure.is_ancestor_of(support):
			await _cleanup(game)
			return
		game.set_process(true)
		await process_frame
		await process_frame
		var retained: bool = (player.get_instance_id() == player_id
			and player.global_position.distance_to(point) < 0.20 and player.is_on_floor())
		print("CINDER_CARGO_WALKING_RECALL: ", {"expected_floor": point,
			"actual": player.global_position, "support": str(support.get_path()), "retained": retained})
		_check(retained, "actual Main process preserves supported walking on the current Cinder cargo floor")
		if not retained:
			await _cleanup(game)
			return

	await _cargo_recall_stage_player(game, player, deck, true)
	game.set_process(true)
	var walking: Dictionary = await _cargo_recall_walk_route(access, player)
	print("CINDER_CARGO_WALKING_TRANSIENT: ", walking)
	_check(bool(walking.get("reached", false)) and bool(walking.get("supported_floor_transient", false)),
		"actual Main preserves the complete Cinder out-and-back walk with transient floor flag and fresh current support")
	if not bool(walking.get("reached", false)) or not bool(walking.get("supported_floor_transient", false)):
		await _cleanup(game)
		return

	# A supported actor outside this Main is not the current local Player.
	game.set_process(false)
	var player_owner := player.owner
	player.reparent(root)
	_check(not bool(game.call(&"_is_player_supported_by_current_cinder_access")),
		"a detached Player cannot inherit the current Cinder support exemption")
	player.reparent(game)
	player.owner = player_owner

	# Real current geometry still exists while reparented, but it belongs to no
	# current streamed access and must not suppress the existing fall backstop.
	await _cargo_recall_stage_player(game, player, deck, true)
	var access_parent := access.get_parent()
	access.reparent(game)
	game.set_process(true)
	await process_frame
	await process_frame
	_check(player.global_position.distance_to(world.get_player_spawn().origin) < 0.20,
		"physically supported reparented access cannot suppress yard safety recall")
	access.reparent(access_parent)

	await _cargo_recall_stage_player(game, player, deck + Vector3(0.0, -8.0, 0.0), false)
	_check(not player.is_on_floor(), "unsupported Cinder fall fixture has no actual floor")
	game.set_process(true)
	await process_frame
	await process_frame
	_check(player.global_position.distance_to(world.get_player_spawn().origin) < 0.20,
		"a real unsupported fall below current Cinder still recalls to the yard")

	await _cargo_recall_stage_player(game, player, deck, true)
	game.set_physics_process(false)
	ship.global_position = LOCATION.get_anchor_position() + Vector3(0.0, 0.0, 650.1)
	for _tick in 31:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, _ship_sample(ship))
	_check(bootstrap.get_loaded_instance() == null,
		"production fade and unload retire the supported floor's current attachment")
	game.set_process(true)
	await process_frame
	await process_frame
	_check(player.global_position.distance_to(world.get_player_spawn().origin) < 0.20,
		"queued or unloaded Cinder floor cannot retain the support exemption")
	game.set_physics_process(true)

	await _cargo_recall_stage_player(game, player, world.to_global(Vector3(0.0, -25.0, 0.0)), false)
	game.set_process(true)
	await process_frame
	await process_frame
	_check(player.global_position.distance_to(world.get_player_spawn().origin) < 0.20,
		"original below-yard unsupported station fall still recalls")
	await _cleanup(game)


## Same production movement actions as the access walking fixture, dispatched
## as real input events. The docked hull, Player and recall guard keep ticking;
## no pose, velocity, floor flag or authority is written during the segment.
func _cargo_recall_walk_route(access: CinderCargoAccess, player: PlayerController) -> Dictionary:
	# A marker at a tread boundary shares the capsule's arrival footprint with
	# the next authored step. Admit only one actual solver step plus its margin.
	var arrival_height := float(player.get_step_up_assist_audit().get("max_step_height", 0.0)) + player.safe_margin
	var local_points := access.get_route_local_points()
	var targets: Array[Vector3] = []
	for point: Vector3 in local_points:
		targets.append(access.to_global(point))
	for index in range(local_points.size() - 1, -1, -1):
		targets.append(access.to_global(local_points[index]))
	var structure := access.get_node(^"Structure")
	var yaw := player.get_node(^"%CameraYaw") as Node3D
	var transient := false
	var maximum_step := 0.0
	var previous := player.global_position
	var previous_tick := Engine.get_physics_frames()
	var first_transient: Dictionary = {}
	var visited: Array[Dictionary] = []
	var failure: Dictionary = {}
	for index in targets.size():
		var target := targets[index]
		var reached := false
		for _frame in 210:
			var remaining_offset := (target - player.global_position).slide(Vector3.UP)
			var distance := remaining_offset.length()
			var speed := player.velocity.slide(Vector3.UP).length()
			var commanded := player.sprint_speed if distance > 3.0 else player.walk_speed
			var stopping := speed * speed / (2.0 * player.ground_deceleration) \
				+ maxf(speed, commanded) / 60.0 + 0.10
			var moving: bool = distance > 0.30 and (speed <= 0.35 or distance > stopping)
			var desired := remaining_offset.normalized() if moving else Vector3.ZERO
			var forward := (-yaw.global_basis.z).slide(Vector3.UP).normalized()
			var right := forward.cross(Vector3.UP).normalized()
			var sideways := desired.dot(right)
			var ahead := desired.dot(forward)
			_cargo_recall_walk_action(&"move_left", maxf(-sideways, 0.0))
			_cargo_recall_walk_action(&"move_right", maxf(sideways, 0.0))
			_cargo_recall_walk_action(&"move_back", maxf(-ahead, 0.0))
			_cargo_recall_walk_action(&"move_forward", maxf(ahead, 0.0))
			_cargo_recall_walk_action(&"sprint_boost", 1.0 if moving and distance > 3.0 else 0.0)
			Input.flush_buffered_events()
			await physics_frame
			await process_frame
			var step := player.global_position.distance_to(previous)
			maximum_step = maxf(maximum_step, step)
			var elapsed_ticks := maxi(1, Engine.get_physics_frames() - previous_tick)
			previous_tick = Engine.get_physics_frames()
			var motion: Dictionary = player.get_step_up_assist_audit().get("completed_motion", {})
			var support := _cargo_recall_support(player, access)
			var supported: bool = is_instance_valid(support) and structure.is_ancestor_of(support)
			var sample := {"direction": "outbound" if index < local_points.size() else "reverse",
				"index": index if index < local_points.size() else targets.size() - 1 - index,
				"target": target, "actual": player.global_position, "step": step,
				"floor": player.is_on_floor(), "support": str(support.get_path()) if is_instance_valid(support) else "",
				"completed_motion": motion}
			if step > 9.2 * float(elapsed_ticks) / 60.0 * 1.25 + 0.02:
				var event: Dictionary = motion.get("step_up", {})
				var bounds: Dictionary = event.get("bounds", {})
				var offset := player.global_position - previous
				var intended: Vector3 = event.get("intended", Vector3.ZERO)
				var completed_step: bool = (not event.is_empty()
					and int(event.get("frame", -1)) == int(motion.get("frame", -2))
					and Engine.get_physics_frames() - int(event.get("frame", -3)) in [0, 1]
					and int(event.get("player_id", 0)) == player.get_instance_id()
					and event.get("start") == motion.get("start") and motion.get("start") == previous
					and event.get("landing") == motion.get("end") and motion.get("end") == player.global_position
					and offset.y > 0.0 and offset.y <= 0.301
					and offset.slide(Vector3.UP).length() <= float(bounds.get("probe_reach", 0.0)) + float(bounds.get("min_advance", 0.0))
					and offset.slide(Vector3.UP).dot(intended) > 0.0)
				if not completed_step:
					failure = sample
					failure["reason"] = &"motion_limit_without_completed_step"
					break
			if not supported:
				var excluded: Array[RID] = [player.get_rid()]
				var berth := access.get_berth()
				var occupant := berth.get_occupant() as HeroShip
				if is_instance_valid(occupant) and occupant.is_inside_tree() and not occupant.is_queued_for_deletion() \
						and player.get_parent().is_ancestor_of(occupant) and berth.get_reservation_owner() == occupant:
					excluded.append(occupant.get_rid())
				var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.2,
					player.global_position - Vector3.UP * player.floor_snap_length,
					player.collision_mask & PhysicsLayers.WORLD, excluded)
				var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
				var collider := hit.get("collider") as Node
				var normal: Vector3 = hit.get("normal", Vector3.ZERO)
				var hit_position: Vector3 = hit.get("position", Vector3.INF)
				sample["center_floor_ray"] = {"mask": ray.collision_mask, "downward_reach": player.floor_snap_length,
					"collider": str(collider.get_path()) if is_instance_valid(collider) else "",
					"under_current_structure": is_instance_valid(collider) and structure.is_ancestor_of(collider),
					"normal": normal, "position": hit_position,
					"root_gap": player.global_position.y - hit_position.y,
					"walkable": normal.dot(Vector3.UP) >= cos(player.floor_max_angle)}
				failure = sample
				failure["reason"] = &"current_walkable_support_lost"
				break
			previous = player.global_position
			if not player.is_on_floor():
				transient = true
				if first_transient.is_empty():
					first_transient = {"frame": Engine.get_physics_frames(), "position": player.global_position,
						"support": str(support.get_path()), "velocity": player.velocity}
			if (target - player.global_position).slide(Vector3.UP).length() <= 0.30 \
					and absf(target.y - player.global_position.y) <= arrival_height \
					and player.velocity.slide(Vector3.UP).length() <= 0.35:
				reached = true
				visited.append(sample)
				break
			if _frame == 209:
				failure = sample
				failure["reason"] = &"waypoint_deadline"
		for action: StringName in [&"move_left", &"move_right", &"move_back", &"move_forward", &"sprint_boost"]:
			_cargo_recall_walk_action(action, 0.0)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame
		if not reached:
			break
		# The neutral release above is another real completed physics tick;
		# keep the next step event adjacent to its actual starting body pose.
		previous = player.global_position
		previous_tick = Engine.get_physics_frames()
	return {"reached": visited.size() == targets.size(), "supported_floor_transient": transient,
		"first_transient": first_transient, "visited": visited, "failure": failure,
		"actual": player.global_position, "maximum_step": maximum_step}


func _cargo_recall_walk_action(action: StringName, strength: float) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.02
	event.strength = strength if event.pressed else 0.0
	Input.parse_input_event(event)


func _cargo_recall_stage_player(game: GameFlow, player: PlayerController,
	point: Vector3, require_floor: bool) -> bool:
	game.set_process(false)
	player.teleport_to(Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.03))
	player.set_control_enabled(true)
	for _tick in (30 if require_floor else 3):
		await physics_frame
		await process_frame
		if require_floor and player.is_on_floor():
			return true
	return not require_floor


func _cargo_recall_support(player: PlayerController, access: CinderCargoAccess) -> Node:
	var excluded: Array[RID] = []
	var berth := access.get_berth()
	var occupant := berth.get_occupant() as HeroShip
	if is_instance_valid(occupant) and occupant.is_inside_tree() \
			and not occupant.is_queued_for_deletion() and player.get_parent().is_ancestor_of(occupant) \
			and berth.get_reservation_owner() == occupant:
		excluded.append(occupant.get_rid())
	var structure := access.get_node(^"Structure")
	for contact: Dictionary in player.get_floor_support_contacts(excluded):
		var collider := contact.get("collider") as Node
		if is_instance_valid(collider) and structure.is_ancestor_of(collider):
			return collider
	return null


## Focused Main regression, not an ordinary outbound journey: only the initial
## flight/capture context is staged. Landing admission, leases and every motion
## after the one request belong to GameFlow, HeroShip and ShipBerth.
func _run_cargo_landing() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(game.configure_runtime_settings_persistence(store,
		"memory://cinder-cargo-landing-legacy.cfg"), "cargo landing isolates Main persistence")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var binding := game.get_node_or_null(^"CinderStreamingProductionBinding") as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	var jovian := _cargo_landing_ship(game, &"jovian_provisional")
	var torrent := game.get_guided_ship()
	_check(binding != null and bootstrap != null and jovian != null and torrent != null,
		"cargo landing uses production Main, streaming binding and original craft")
	if binding == null or bootstrap == null or jovian == null or torrent == null:
		await _cleanup(game)
		return
	var home_id := jovian.get_home_berth_id()
	var home_report := game.call(&"_get_landing_assist_report_for_ship", jovian) as Dictionary
	_check(home_report.get("selected_berth_id") == home_id,
		"resident home berth selection remains available before streaming")
	game.runtime_settings.graphics_profile = RuntimeSettings.GraphicsProfile.LOW
	game.world.apply_visual_quality(NearbySectorCluster.DetailQuality.LOW)
	game.call(&"_release_ship_berth", jovian)
	game.active_ship = jovian
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	jovian.set_piloted(true)
	jovian.set("_landed", false)
	jovian.global_position = LOCATION.get_anchor_position() + Vector3(0.0, 0.0, 499.9)
	var before_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_tick)
	await _wait_for_cluster(bootstrap)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	_check(cluster != null, "actual GameFlow actor-tracking physics loads Cinder")
	if cluster == null:
		await _cleanup(game)
		return
	var access := cluster.get_cinder_cargo_access()
	var berth := access.get_berth()
	var berth_id := berth.get_berth_id()
	_cargo_landing_stage_capture(jovian, berth)
	var capture := _cargo_landing_capture(jovian, berth)
	_check(berth.is_inside_tree() and not berth.is_queued_for_deletion()
		and berth_id == &"cinder_cargo_jovian_berth"
		and berth.get_reservation_owner() == null and berth.get_occupant() == null
		and berth.can_accept(jovian.get_ship_definition(), jovian)
		and bool(capture.get("assist_capture_accepted", false)),
		"live unreserved streamed cargo berth accepts actual Jovian full-hull capture")
	var preview_before := berth.audit()
	var preview := game.call(&"_get_landing_assist_report_for_ship", jovian) as Dictionary
	var selected: bool = (preview.get("selected_berth_id") == berth_id
		and bool(preview.get("assist_capture_accepted", false)))
	print("CINDER_CARGO_LANDING_PREVIEW: ", {"direct_capture": capture, "game_flow": preview})
	_check(selected, "GameFlow landing preview selects the current streamed Cinder cargo berth")
	# Stop at the causal baseline failure; no request or further fixture changes
	# can hide missing discovery behind a direct berth reservation.
	if not selected:
		await _cleanup(game)
		return
	_check(game.call(&"_resolve_berth_node", berth_id) == berth,
		"GameFlow resolves the exact current cargo berth")
	_check(preview_before == berth.audit()
		and bool(preview.get("preview_non_mutating", false)),
		"cargo preview preserves physical reservation and occupancy")

	# Compatibility and out-of-volume refusal use the original physical owner.
	var torrent_pose := torrent.global_transform
	torrent.global_transform = jovian.global_transform
	var incompatible := game.call(&"_get_landing_assist_report_for_ship", torrent) as Dictionary
	_check(not berth.can_accept(torrent.get_ship_definition(), torrent)
		and incompatible.get("selected_berth_id", &"") != berth_id,
		"incompatible Torrent cannot acquire the cargo berth")
	var hulk_berth := cluster.get_station_hulk_berth()
	torrent.global_transform = hulk_berth.get_assist_capture_transform()
	var hulk_report := game.call(&"_get_landing_assist_report_for_ship", torrent) as Dictionary
	_check(hulk_report.get("selected_berth_id") == hulk_berth.get_berth_id()
		and game.call(&"_resolve_berth_node", hulk_berth.get_berth_id()) == hulk_berth,
		"existing streamed HULK selection and exact resolver remain intact")
	torrent.global_transform = torrent_pose
	jovian.global_position += Vector3(100.0, 0.0, 0.0)
	var outside := game.call(&"_get_landing_assist_report_for_ship", jovian) as Dictionary
	_check(not bool(_cargo_landing_capture(jovian, berth).get("assist_capture_accepted", true))
		and outside.get("selected_berth_id", &"") != berth_id,
		"out-of-capture Jovian receives no cargo landing selection")
	_cargo_landing_stage_capture(jovian, berth)
	var hauler := _cargo_landing_ship(game, &"cinder_cargo_hauler")
	_check(hauler != null, "production compatible Hauler is present for exclusive lease refusal")
	if hauler == null:
		await _cleanup(game)
		return
	# Only a negative availability fixture: GameFlow owns this competing lease;
	# the positive landing below never calls try_reserve or occupy directly.
	var busy_reserved := bool(game.call(&"_reserve_berth_for_ship", hauler, berth_id, false))
	var busy := game.call(&"_get_landing_assist_report_for_ship", jovian) as Dictionary
	_check(busy_reserved and berth.get_reservation_owner() == hauler
		and busy.get("selected_berth_id", &"") != berth_id,
		"another current craft's exclusive cargo lease refuses Jovian preview")
	game.call(&"_release_ship_berth", hauler)

	var berth_parent := berth.get_parent()
	berth.reparent(game)
	_check(game.call(&"_resolve_berth_node", berth_id) == null
		and (game.call(&"_get_landing_assist_report_for_ship", jovian) as Dictionary).get(
			"selected_berth_id", &"") != berth_id,
		"a live cargo berth moved outside its current access cannot be resolved or selected")
	berth.reparent(berth_parent)
	var old_cluster_id := cluster.get_instance_id()
	var old_berth_ref: WeakRef = weakref(berth)
	# Reuse the existing exact caller-tick fade/retirement fixture. The normal
	# initial load above and the new generation below still use real tracking.
	game.set_physics_process(false)
	jovian.global_position = LOCATION.get_anchor_position() + Vector3(0.0, 0.0, 650.1)
	for _tick in 31:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, _ship_sample(jovian))
	_check(bootstrap.get_loaded_instance() == null
		and game.call(&"_resolve_berth_node", berth_id) == null,
		"retired queued Cinder generation cannot resolve its cargo berth")
	game.set_physics_process(true)
	await process_frame
	await process_frame
	_check(old_berth_ref.get_ref() == null, "unload frees the old cargo berth")
	jovian.global_position = LOCATION.get_anchor_position() + Vector3(0.0, 0.0, 499.9)
	before_tick = int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_tick)
	await _wait_for_cluster(bootstrap)
	cluster = bootstrap.get_loaded_instance() as NearbySectorCluster
	_check(cluster != null and cluster.get_instance_id() != old_cluster_id,
		"actual tracking loads one replacement Cinder generation")
	if cluster == null:
		await _cleanup(game)
		return
	berth = cluster.get_cinder_cargo_access().get_berth()
	_cargo_landing_stage_capture(jovian, berth)
	preview = game.call(&"_get_landing_assist_report_for_ship", jovian) as Dictionary
	_check(game.call(&"_resolve_berth_node", berth_id) == berth
		and preview.get("selected_berth_id") == berth_id
		and bool(preview.get("assist_capture_accepted", false)),
		"replacement generation resolves and selects only its new current cargo berth")
	if not _failures.is_empty():
		await _cleanup(game)
		return

	print("CINDER_CARGO_LANDING_REQUEST: staged flight/capture only; no pose, velocity or lease writes follow")
	game.call(&"_try_request_landing")
	_check(jovian.is_landing_active() and bool(game.get("_landing_request_active"))
		and game.get("_active_landing_berth_id") == berth_id
		and berth.get_reservation_owner() == jovian,
		"normal GameFlow request ingress reserves the cargo berth and starts physical assist")
	var deadline := Time.get_ticks_msec() + 120000
	while jovian.is_landing_active() and Time.get_ticks_msec() < deadline:
		await physics_frame
		await process_frame
	var landed := jovian.get_landing_contract_report()
	var tokens := game.get("_berth_tokens") as Dictionary
	var ids := game.get("_reserved_berth_ids") as Dictionary
	var token := StringName(tokens.get(jovian.get_instance_id(), &""))
	_check(game.phase == GameFlow.Phase.SHUT_DOWN
		and bool(jovian.get_telemetry().get("landed", false))
		and bool(landed.get("contract_accepted", false))
		and bool(landed.get("strict_dock_acceptance", false))
		and landed.get("berth_id") == berth_id
		and ids.get(jovian.get_instance_id()) == berth_id
		and not token.is_empty() and berth.has_valid_lease(jovian, token, jovian.get_ship_id())
		and berth.get_occupant() == jovian and berth.get_reservation_owner() == jovian
		and jovian.get_home_berth_id() == home_id,
		"actual physics commits strict cargo dock, exact GameFlow token and occupied lease without changing home")
	print("CINDER_CARGO_LANDING_FINAL: ", landed)
	await _cleanup(game)


func _cargo_landing_ship(game: GameFlow, ship_id: StringName) -> HeroShip:
	for craft: HeroShip in game.ships:
		if craft.get_ship_id() == ship_id:
			return craft
	return null


func _cargo_landing_stage_capture(ship: HeroShip, berth: ShipBerth) -> void:
	var dock := berth.get_dock_transform()
	ship.global_transform = Transform3D(dock.basis, dock.origin + Vector3.UP * 3.0)
	ship.velocity = Vector3.ZERO
	ship.set("_landed", false)


func _cargo_landing_capture(ship: HeroShip, berth: ShipBerth) -> Dictionary:
	var collision := ship.get_landing_collision_report()
	return berth.evaluate_assist_capture_candidate(ship.global_transform,
		collision.get("local_bounds", AABB()) as AABB, ship.velocity, ship.landing_maximum_speed)


func _test_composition_startup_and_player_tracking(
	game: GameFlow,
	binding: CinderStreamingProductionBinding,
	bootstrap: CinderStreamingBootstrap,
	player: PlayerController
	) -> void:
	var report := binding.audit()
	var snapshot := report.get("snapshot", {}) as Dictionary
	var bootstrap_snapshot := snapshot.get("bootstrap", {}) as Dictionary
	var coordinator_snapshot := bootstrap_snapshot.get("coordinator", {}) as Dictionary
	_check(
		bool(report.get("valid", false))
		and int(report.get("binding_count", -1)) == 1
		and int(report.get("bootstrap_count", -1)) == 1
		and int(report.get("coordinator_count", -1)) == 1
		and int(report.get("distance_policy_count", -1)) == 1
		and game.find_children(
			"*", "CinderStreamingProductionBinding", true, false
		).size() == 1,
		"production Main owns exactly one binding, bootstrap, coordinator, and distance policy"
	)
	_check(
		bool(snapshot.get("activated", false))
		and bool(snapshot.get("caller_sample_mode", false))
		and not bool(snapshot.get("provider_bound", true))
		and int(snapshot.get("provider_generation", -1)) == 0
		and not bool(snapshot.get("physics_processing", true))
		and report.get("position_provider_policy")
			== &"caller_supplied_piloted_active_ship_else_live_player"
		and report.get("update_authority")
			== &"one_physics_tick_from_caller_sample",
		"one caller-supplied GameFlow sample drives the existing policy only from physics"
	)
	var provider_generation := int(snapshot.get("provider_generation", -1))
	_check(
		not binding.set_position_provider(Callable(self, &"_forged_position_sample"))
		and int(binding.get_snapshot().get("provider_generation", -2))
			== provider_generation,
		"caller-sampled production mode cannot gain a competing provider"
	)
	_check(
		bootstrap.get_loaded_instance() == null
		and game.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and int(coordinator_snapshot.get("load_request_count", -1)) == 0
		and snapshot.get("last_actor_kind") == &"player"
		and int(snapshot.get("last_actor_instance_id", 0)) == player.get_instance_id(),
		"station start tracks Player with zero resident or streamed Cinder instances"
	)
	_check(
		not bool(report.get("activity_authority", true))
		and not bool(report.get("gameplay_authority", true))
		and not bool(report.get("combat_authority", true))
		and not bool(report.get("reward_authority", true))
		and not bool(report.get("ship_authority", true))
		and not bool(report.get("berth_authority", true))
		and not bool(report.get("save_authority", true))
		and not bool(report.get("network_authority", true))
		and not bool(report.get("runtime_settings_authority", true))
		and not bool(report.get("staged_startup_authority", true)),
		"the binding consumes caller cadence and owns no gameplay, settings, startup, or persistence authority"
	)
	var safe_start := game.get_safe_start_recovery_report()
	_check(
		int(safe_start.get("policy_count", -1)) == 1
		and int(safe_start.get("policy_instance_id", 0)) != 0
		and game.runtime_settings != null,
		"existing SafeStart and RuntimeSettings compositions remain singular after binding activation"
	)
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var route_report := world.get_station_route_registry_report() if world != null else {}
	_check(
		world != null
		and bool(route_report.get("valid", false))
		and world.get_station_service_agents().size() == 7,
		"station-owned route definitions and all seven couriers remain live without resident Cinder geometry"
	)
	var before_tick := binding.get_snapshot()
	await physics_frame
	await process_frame
	var after_tick := binding.get_snapshot()
	_check(
		int(after_tick.get("physics_tick_count", -1))
			> int(before_tick.get("physics_tick_count", -1))
		and int(after_tick.get("policy_update_index", -1))
			- int(after_tick.get("initial_policy_update_index", -1))
			== int(after_tick.get("physics_tick_count", -2))
		and bool(binding.audit().get("valid", false)),
		"policy update count remains exactly equal to binding-owned physics ticks"
	)
	var mutable := binding.get_snapshot()
	(mutable.get("last_tick_result", {}) as Dictionary)["reason"] = &"forged"
	(mutable.get("bootstrap", {}) as Dictionary).clear()
	var detached := binding.get_snapshot()
	_check(
		not (detached.get("bootstrap", {}) as Dictionary).is_empty()
		and (detached.get("last_tick_result", {}) as Dictionary).get("reason")
			!= &"forged",
		"binding snapshots are deeply detached from caller mutation"
	)


func _test_ship_outbound_missing_actor_and_reentry(
	game: GameFlow,
	binding: CinderStreamingProductionBinding,
	bootstrap: CinderStreamingBootstrap,
	player: PlayerController,
	ship: HeroShip
	) -> void:
	var anchor := LOCATION.get_anchor_position()
	var toward_station := (Vector3.ZERO - anchor).normalized()
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	if world != null:
		game.runtime_settings.graphics_profile = RuntimeSettings.GraphicsProfile.LOW
		world.apply_visual_quality(NearbySectorCluster.DetailQuality.LOW)
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * 499.9
	var before_outbound_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_outbound_tick)
	var outbound := binding.get_snapshot()
	var outbound_result := outbound.get("last_tick_result", {}) as Dictionary
	var outbound_transition := _first_transition(outbound_result)
	if outbound_transition.is_empty():
		outbound_transition = _last_policy_outcome(bootstrap)
	_check(
		outbound.get("last_actor_kind") == &"ship"
		and int(outbound.get("last_actor_instance_id", 0)) == ship.get_instance_id()
		and outbound_transition.get("action") == &"load"
		and outbound_transition.get("reason") == &"load_requested"
		and is_equal_approx(float(outbound_transition.get("distance", -1.0)), 499.9),
		"the piloted production ship requests Cinder once on the outbound physics tick"
	)
	await _wait_for_cluster(bootstrap)
	var cluster := bootstrap.get_loaded_instance()
	await _wait_for_quality_sync(binding, cluster.get_instance_id())
	var cluster_ref: WeakRef = weakref(cluster)
	var loaded_snapshot := bootstrap.get_snapshot()
	var loaded_coordinator := loaded_snapshot.get("coordinator", {}) as Dictionary
	var coordinator := bootstrap.get_node_or_null(
		^"WorldStreamingCoordinator"
	) as WorldStreamingCoordinator
	var policy := bootstrap.get_node_or_null(
		^"WorldStreamingDistancePolicy"
	) as WorldStreamingDistancePolicy
	var streamed_cluster_count := bootstrap.find_children(
		"*", "NearbySectorCluster", true, false
	).size()
	print(
		"CINDER_PRODUCTION_LOADED: generation=",
		outbound_transition.get("generation", -1),
		" requests=", loaded_coordinator.get("load_request_count", -1),
		" owned=", loaded_coordinator.get("owned_instance_count", -1)
	)
	print(
		"CINDER_PRODUCTION_PRESENTATION: synced=",
		binding.get_snapshot().get("quality_synced_instance_id", 0),
		" cluster=", cluster.get_instance_id(),
		" quality=", cluster.get_detail_quality(),
		" whole_count=", game.find_children("*", "NearbySectorCluster", true, false).size()
	)
	_check(
		cluster is NearbySectorCluster
		and cluster.transform == Transform3D.IDENTITY
		and cluster.get_parent() == coordinator
		and world != null
		and world.get_nearby_sector_cluster() == cluster
		and bool(world.get_nearby_sector_cluster_audit_report().get("valid", false))
		and int(cluster.get_meta(&"world_location_generation", -1))
			== int(outbound_transition.get("generation", -2))
		and int(loaded_coordinator.get("load_request_count", -1)) == 1
		and int(loaded_coordinator.get("owned_instance_count", -1)) == 1
		and streamed_cluster_count == 1
		and game.find_children("*", "NearbySectorCluster", true, false).size() == 1
		and int(binding.get_snapshot().get("quality_synced_instance_id", 0))
			== cluster.get_instance_id()
		and cluster.get_detail_quality() == NearbySectorCluster.DetailQuality.LOW
		and (cluster.get_node_or_null(
			^"RouteBeacons/RouteBeaconAlpha/SignalRing"
		) as MeshInstance3D).mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
		and not (cluster.get_node_or_null(
			^"DebrisField/DebrisChips"
		) as MultiMeshInstance3D).visible,
		"the sole real zero-origin Cinder cluster commits once and receives the retained quality"
	)

	# No actor is a fail-closed tracking loss, not an unload decision. The Player
	# is detached without freeing it and the ship relinquishes its pilot flag.
	ship.set_piloted(false)
	var player_owner := player.owner
	var player_index := player.get_index()
	player.owner = null
	game.remove_child(player)
	var before_missing_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_missing_tick)
	var missing := binding.get_snapshot()
	var missing_policy := (
		(missing.get("bootstrap", {}) as Dictionary).get("distance_policy", {})
		as Dictionary
	)
	_check(
		missing.get("last_sample_reason") == &"no_tracked_production_actor"
		and (missing.get("last_tick_result", {}) as Dictionary).get("reason")
			== &"tracking_unavailable"
		and not bool(missing_policy.get("tracking_available", true))
		and bootstrap.get_loaded_instance() == cluster,
		"missing production actors clear tracking, tick once, and preserve the loaded cluster"
	)
	game.add_child(player)
	game.move_child(player, player_index)
	player.owner = player_owner

	ship.set_piloted(true)
	ship.global_position = anchor
	var before_recovered_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_recovered_tick)
	_check(
		binding.get_snapshot().get("last_actor_kind") == &"ship"
		and bootstrap.get_loaded_instance() == cluster,
		"restoring the production actor resumes tracking without a duplicate load"
	)

	var binding_id := binding.get_instance_id()
	var bootstrap_id := bootstrap.get_instance_id()
	var coordinator_id := coordinator.get_instance_id()
	var policy_id := policy.get_instance_id()
	var cluster_id := cluster.get_instance_id()
	var cluster_generation := int(cluster.get_meta(&"world_location_generation", -1))
	var ticks_before_detach := int(binding.get_snapshot().get("physics_tick_count", -1))
	var safe_start_before := game.get_safe_start_recovery_report()
	var settings_id := game.runtime_settings.get_instance_id()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		int(binding.get_snapshot().get("physics_tick_count", -2)) == ticks_before_detach
		and not bool(binding.get_snapshot().get("physics_processing", true))
		and bootstrap.get_loaded_instance() == cluster,
		"whole-Main detach pauses sampling and retains the loaded instance"
	)
	parent.add_child(game)
	await _wait_for_binding_tick(binding, ticks_before_detach)
	await process_frame
	var reentered_safe_start := game.get_safe_start_recovery_report()
	_check(
		binding.get_instance_id() == binding_id
		and bootstrap.get_instance_id() == bootstrap_id
		and coordinator.get_instance_id() == coordinator_id
		and policy.get_instance_id() == policy_id
		and bootstrap.get_loaded_instance() == cluster
		and cluster.get_instance_id() == cluster_id
		and game.find_children("*", "NearbySectorCluster", true, false).size() == 1
		and world.get_nearby_sector_cluster() == cluster
		and int(reentered_safe_start.get("policy_instance_id", 0))
			== int(safe_start_before.get("policy_instance_id", -1))
		and game.runtime_settings.get_instance_id() == settings_id
		and bool(binding.audit().get("valid", false)),
		"whole-Main re-entry preserves streaming, SafeStart, and RuntimeSettings identities without duplicates"
	)

	# Freeze GameFlow's automatic caller tick so the presentation lifecycle can
	# be proven at exact 60 Hz samples without idle/render timing influencing it.
	game.set_physics_process(false)
	ship.global_position = anchor + toward_station * 650.1
	var outside_sample := _ship_sample(ship)
	var holds_before := int(binding.get_snapshot().get(
		"presentation_unload_hold_count", -1
	))
	binding.physics_tick_from_caller_sample(1.0 / 60.0, outside_sample)
	var first_outside := cluster.get_streaming_transition_snapshot() as Dictionary
	var held_policy := (
		bootstrap.get_snapshot().get("distance_policy", {}) as Dictionary
	)
	var held_locations := held_policy.get("locations", []) as Array
	var held_policy_distance := float(
		(held_locations[0] as Dictionary).get("distance", 1000.0)
	) if not held_locations.is_empty() else 1000.0
	_check(
		bootstrap.get_loaded_instance() == cluster
		and first_outside.get("phase") == &"fading_out"
		and float(first_outside.get("opacity", -1.0)) < 1.0
		and float(first_outside.get("opacity", -1.0)) > 0.0
		and int(binding.get_snapshot().get("presentation_unload_hold_count", -1))
			== holds_before + 1
		and held_policy_distance < 650.0
		and is_equal_approx(held_policy_distance, 649.5)
		and is_equal_approx(
			float(binding.get_snapshot().get(
				"presentation_unload_hold_distance_meters", -1.0
			)), 649.5
		),
		"a non-axis-aligned >650m sample is held safely inside the boundary while fading"
	)
	for _tick_index in 29:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, outside_sample)
	var fade_complete := cluster.get_streaming_transition_snapshot() as Dictionary
	var held_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		bootstrap.get_loaded_instance() == cluster
		and fade_complete.get("phase") == &"fade_out_complete"
		and is_zero_approx(float(fade_complete.get("opacity", -1.0)))
		and not bool(fade_complete.get("retire_ready", true))
		and int(held_coordinator.get("unload_count", -1)) == 0,
		"exactly 0.5 caller-physics seconds reaches hidden while generation ownership is retained"
	)
	var returning := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, outside_sample
	)
	var return_transition := _first_transition(returning)
	print("CINDER_PRODUCTION_RETURN_TRANSITION: ", return_transition)
	_check(
		return_transition.get("action") == &"unload"
		and return_transition.get("reason") == &"unloaded"
		and bootstrap.get_loaded_instance() == null
		and int((bootstrap.get_snapshot().get("coordinator", {}) as Dictionary).get(
			"unload_count", -1
		)) == 1,
		"the subsequent still-outside tick retires through the unchanged coordinator policy"
	)
	game.set_physics_process(true)
	await process_frame
	await process_frame
	_check(
		cluster_ref.get_ref() == null
		and bootstrap.find_children(
			"*", "NearbySectorCluster", true, false
		).is_empty()
		and game.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and world.get_nearby_sector_cluster() == null
		and world.get_nearby_sector_cluster_audit_report().get("reason")
			== &"streamed_cluster_unavailable",
		"unload frees the only Cinder generation and leaves no stale world reference"
	)
	ship.set_piloted(false)
	player.global_position = Vector3.ZERO
	var before_station_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_station_tick)
	var final_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	_check(
		binding.get_snapshot().get("last_actor_kind") == &"player"
		and int(final_coordinator.get("load_request_count", -1)) == 1
		and int(final_coordinator.get("unload_count", -1)) == 1
		and bootstrap.get_loaded_instance() == null
		and bool(binding.audit().get("valid", false)),
		"station return tracks Player again with one load, one unload, and no hysteresis thrash"
	)

	# A second complete production generation proves that the nullable world
	# accessor and presentation forwarding do not retain the retired instance.
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * 499.9
	var before_second_load_tick := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _wait_for_binding_tick(binding, before_second_load_tick)
	await _wait_for_cluster(bootstrap)
	# The load is deferred. Read the retained policy outcome after the cluster
	# wait, so a fast headless physics tick cannot leave this assertion holding
	# the preceding station/no-op observation.
	var second_load_outcome := _last_policy_outcome(bootstrap)
	var second_cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	await _wait_for_quality_sync(binding, second_cluster.get_instance_id())
	var second_cluster_ref: WeakRef = weakref(second_cluster)
	var second_generation := int(second_cluster.get_meta(&"world_location_generation", -1))
	var second_coordinator := bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	var second_generation_checks := {
		"load_action": second_load_outcome.get("action") == &"load",
		"load_reason": second_load_outcome.get("reason") == &"load_requested",
		"new_instance": second_cluster.get_instance_id() != cluster_id,
		"generation": second_generation == cluster_generation + 2,
		"coordinator_parent": second_cluster.get_parent() == coordinator,
		"identity_transform": second_cluster.transform == Transform3D.IDENTITY,
		"world_lookup": world.get_nearby_sector_cluster() == second_cluster,
		"single_cluster": game.find_children(
			"*", "NearbySectorCluster", true, false
		).size() == 1,
		"load_request_count": int(second_coordinator.get("load_request_count", -1)) == 2,
		"owned_instance_count": int(second_coordinator.get("owned_instance_count", -1)) == 1,
		"retained_quality": second_cluster.get_detail_quality()
			== NearbySectorCluster.DetailQuality.LOW,
		"quality_sync_count": int(binding.get_snapshot().get("quality_sync_count", -1)) == 2,
		"quality_sync_identity": int(binding.get_snapshot().get(
			"quality_synced_instance_id", 0
		)) == second_cluster.get_instance_id(),
		"torus_normalized": (second_cluster.get_node_or_null(
			^"RouteBeacons/RouteBeaconAlpha/SignalRing"
		) as MeshInstance3D).mesh.has_meta(TorusGeometryBudget.AUTHORED_META),
	}
	var second_generation_valid := true
	for check_value in second_generation_checks.values():
		second_generation_valid = second_generation_valid and bool(check_value)
	if not second_generation_valid:
		print("CINDER_PRODUCTION_SECOND_GENERATION_RED: ", second_generation_checks)
	_check(
		second_generation_valid,
		"a second outbound trip commits one new tombstone-safe generation with retained presentation"
	)
	game.set_physics_process(false)
	ship.global_position = anchor + toward_station * 650.1
	var second_outside_sample := _ship_sample(ship)
	for _tick_index in 30:
		binding.physics_tick_from_caller_sample(1.0 / 60.0, second_outside_sample)
	_check(
		bootstrap.get_loaded_instance() == second_cluster
		and (second_cluster.get_streaming_transition_snapshot() as Dictionary).get("phase")
			== &"fade_out_complete",
		"the second generation also reaches hidden before retirement"
	)
	var second_unload_result := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, second_outside_sample
	)
	var second_unload_outcome := _first_transition(second_unload_result)
	game.set_physics_process(true)
	await process_frame
	await process_frame
	var final_snapshot := bootstrap.get_snapshot()
	var final_coordinator_after_retry := final_snapshot.get("coordinator", {}) as Dictionary
	_check(
		second_unload_outcome.get("action") == &"unload"
		and second_unload_outcome.get("reason") == &"unloaded"
		and bootstrap.get_loaded_instance() == null
		and second_cluster_ref.get_ref() == null
		and game.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and int(final_coordinator_after_retry.get("load_request_count", -1)) == 2
		and int(final_coordinator_after_retry.get("unload_count", -1)) == 2
		and bool(binding.audit().get("valid", false)),
		"the second generation unloads cleanly with no stale instance or duplicate request"
	)


func _wait_for_binding_tick(
	binding: CinderStreamingProductionBinding,
	previous_tick_count: int
	) -> void:
	for _frame in 30:
		await process_frame
		if int(binding.get_snapshot().get("physics_tick_count", -1)) > previous_tick_count:
			return


func _wait_for_cluster(bootstrap: CinderStreamingBootstrap) -> void:
	for _frame in 30:
		if bootstrap.get_loaded_instance() != null:
			return
		await process_frame


func _wait_for_quality_sync(
	binding: CinderStreamingProductionBinding,
	instance_id: int
	) -> void:
	for _frame in 30:
		if int(binding.get_snapshot().get("quality_synced_instance_id", 0)) == instance_id:
			return
		await process_frame


func _first_transition(result: Dictionary) -> Dictionary:
	var transitions := result.get("transitions", []) as Array
	return transitions[0] as Dictionary if not transitions.is_empty() else {}


func _last_policy_outcome(bootstrap: CinderStreamingBootstrap) -> Dictionary:
	var snapshot := bootstrap.get_snapshot()
	var policy := snapshot.get("distance_policy", {}) as Dictionary
	var locations := policy.get("locations", []) as Array
	if locations.is_empty():
		return {}
	return (locations[0] as Dictionary).get("last_outcome", {}) as Dictionary


func _forged_position_sample() -> Dictionary:
	return {
		"available": true,
		"position": LOCATION.get_anchor_position(),
		"actor_kind": &"forged",
		"actor_instance_id": -1,
	}


func _ship_sample(ship: HeroShip) -> Dictionary:
	return {
		"available": true,
		"position": ship.global_position,
		"actor_kind": &"ship",
		"actor_instance_id": ship.get_instance_id(),
	}


func _test_queued_binding_boundaries() -> void:
	var activation_game := MAIN_SCENE.instantiate() as GameFlow
	var activation_store := Store.new(
		"memory://cinder-queued-activation-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		activation_game.configure_runtime_settings_persistence(
			activation_store, "memory://cinder-queued-activation-legacy.cfg"
		),
		"queued activation fixture injects isolated settings before Main startup"
	)
	root.add_child(activation_game)
	var activation_binding := activation_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	if activation_binding != null:
		activation_binding.queue_free()
		activation_binding.call("_activate_scene_binding")
	var activation_snapshot := activation_binding.get_snapshot() if activation_binding != null else {}
	_check(
		activation_binding != null
		and activation_binding.is_queued_for_deletion()
		and not bool(activation_snapshot.get("activated", true))
		and int(activation_snapshot.get("bootstrap_instance_id", -1)) == 0
		and not bool(activation_snapshot.get("provider_bound", true))
		and int(activation_snapshot.get("physics_tick_count", -1)) == 0,
		"queued deferred binding activation remains inert before bootstrap/provider ownership"
	)
	activation_game.queue_free()
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(activation_game),
		"queued activation fixture frees before any deferred binding activation can run"
	)

	var tick_game := MAIN_SCENE.instantiate() as GameFlow
	var tick_store := Store.new(
		"memory://cinder-queued-tick-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		tick_game.configure_runtime_settings_persistence(
			tick_store, "memory://cinder-queued-tick-legacy.cfg"
		),
		"queued tick fixture injects isolated settings before Main startup"
	)
	root.add_child(tick_game)
	await process_frame
	await physics_frame
	await process_frame
	var tick_binding := tick_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var tick_player := tick_game.get_node_or_null(^"Player") as PlayerController
	var before_tick := tick_binding.get_snapshot() if tick_binding != null else {}
	var queued_sample := {
		"available": true,
		"position": tick_player.global_position if tick_player != null else Vector3.ZERO,
		"actor_kind": &"player",
		"actor_instance_id": tick_player.get_instance_id() if tick_player != null else 0,
	}
	if tick_binding != null:
		tick_binding.queue_free()
	var queued_tick := (
		tick_binding.physics_tick_from_caller_sample(
			0.25, queued_sample
		)
		if tick_binding != null else {}
	)
	_check(
		tick_binding != null
		and tick_binding.is_queued_for_deletion()
		and not bool(queued_tick.get("accepted", true))
		and queued_tick.get("reason", &"") == &"binding_unavailable"
		and tick_binding.get_snapshot() == before_tick,
		"queued direct caller tick rejects before streaming counters, policy, or tracking mutate"
	)
	tick_game.queue_free()
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(tick_game),
		"queued tick fixture frees without a late streaming update"
	)


func _test_deferred_quality_sync_currentness() -> void:
	var detached_game := MAIN_SCENE.instantiate() as GameFlow
	var detached_store := Store.new(
		"memory://cinder-detached-quality-sync-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		detached_game.configure_runtime_settings_persistence(
			detached_store, "memory://cinder-detached-quality-sync-legacy.cfg"
		),
		"detached quality-sync fixture injects isolated settings before Main startup"
	)
	root.add_child(detached_game)
	await process_frame
	await physics_frame
	await process_frame
	var detached_binding := detached_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var detached_bootstrap := detached_game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var detached_ship := detached_game.get_guided_ship()
	_check(
		detached_binding != null and detached_bootstrap != null and detached_ship != null,
		"detached quality-sync fixture resolves the live production binding, bootstrap, and ship"
	)
	if detached_binding == null or detached_bootstrap == null or detached_ship == null:
		await _cleanup(detached_game)
		return
	detached_game.set_physics_process(false)
	detached_ship.set_piloted(true)
	detached_ship.global_position = LOCATION.get_anchor_position() + Vector3.FORWARD * 499.9
	var detached_load := detached_binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _ship_sample(detached_ship)
	)
	var detached_before := _quality_sync_snapshot(detached_binding)
	_check(
		bool(detached_load.get("accepted", false))
			and bool(detached_before.get("pending", false)),
		"a real outbound load schedules one deferred retained-quality completion"
	)
	var binding_parent := detached_binding.get_parent()
	if binding_parent != null:
		binding_parent.remove_child(detached_binding)
	detached_binding.call(
		"_complete_deferred_presentation_sync",
		int(detached_before.get("deferred_generation", -1))
	)
	_check(
		not detached_binding.is_inside_tree()
			and _quality_sync_snapshot(detached_binding) == detached_before,
		"a detached deferred quality completion preserves its retained pending and sync state atomically"
	)
	if binding_parent != null:
		binding_parent.add_child(detached_binding)
	await _wait_for_cluster(detached_bootstrap)
	var detached_cluster := detached_bootstrap.get_loaded_instance() as NearbySectorCluster
	if detached_cluster != null:
		await _wait_for_quality_sync(detached_binding, detached_cluster.get_instance_id())
	var detached_after := _quality_sync_snapshot(detached_binding)
	_check(
		detached_cluster != null
			and not bool(detached_after.get("pending", true))
			and int(detached_after.get("sync_count", -1))
				== int(detached_before.get("sync_count", -2)) + 1
			and int(detached_after.get("synced_instance_id", 0)) == detached_cluster.get_instance_id(),
		"a re-entered binding completes one fresh current-generation quality synchronization"
	)
	await _cleanup(detached_game)

	var queued_game := MAIN_SCENE.instantiate() as GameFlow
	var queued_store := Store.new(
		"memory://cinder-queued-quality-sync-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		queued_game.configure_runtime_settings_persistence(
			queued_store, "memory://cinder-queued-quality-sync-legacy.cfg"
		),
		"queued quality-sync fixture injects isolated settings before Main startup"
	)
	root.add_child(queued_game)
	await process_frame
	await physics_frame
	await process_frame
	var queued_binding := queued_game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var queued_ship := queued_game.get_guided_ship()
	if queued_binding != null and queued_ship != null:
		queued_game.set_physics_process(false)
		queued_ship.set_piloted(true)
		queued_ship.global_position = LOCATION.get_anchor_position() + Vector3.FORWARD * 499.9
		queued_binding.physics_tick_from_caller_sample(1.0 / 60.0, _ship_sample(queued_ship))
	var queued_before := _quality_sync_snapshot(queued_binding)
	if queued_binding != null:
		queued_binding.queue_free()
		queued_binding.call(
			"_complete_deferred_presentation_sync",
			int(queued_before.get("deferred_generation", -1))
		)
	_check(
		queued_binding != null
			and queued_binding.is_queued_for_deletion()
			and bool(queued_before.get("pending", false))
			and _quality_sync_snapshot(queued_binding) == queued_before,
		"a queued deferred quality completion preserves pending and quality state before disposal"
	)
	await _cleanup(queued_game)


func _quality_sync_snapshot(binding: CinderStreamingProductionBinding) -> Dictionary:
	if binding == null:
		return {}
	var snapshot := binding.get_snapshot()
	return {
		"pending": bool(snapshot.get("deferred_quality_sync_pending", false)),
		"deferred_generation": int(snapshot.get("deferred_quality_sync_generation", -1)),
		"sync_count": int(snapshot.get("quality_sync_count", -1)),
		"synced_instance_id": int(snapshot.get("quality_synced_instance_id", 0)),
	}.duplicate(true)


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	print("CINDER_STREAMING_PRODUCTION_JOURNEY_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_STREAMING_PRODUCTION_JOURNEY_TEST_OK")
		quit(0)
	else:
		print("CINDER_STREAMING_PRODUCTION_JOURNEY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
