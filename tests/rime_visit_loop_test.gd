extends "res://tests/ember_transit_movement_soak.gd"
## test-matrix-timeout-seconds: 900
## Drives one complete Rime visit through a real composed `Main`, modelled on
## the Aurora production visit loop: the destination is chosen from the real
## Destination Board, the craft cruises out through the shared cruise lane with
## committed common-world origin rebases, touches down through a real
## `ShipBerth` lease on the streamed scene, the pilot disembarks and walks the
## icefall on real collision, runs the optional ice-core survey (including its
## recoverable cold-exposure failure), survives a whole-`Main` re-entry,
## completes the survey through the reward authority exactly once, re-boards,
## queues the return, and finally abandons a visit from the surface and checks
## nothing of Rime is left behind.
## --rime-completed-return instead drives the full ordinary physical round trip
## and disk reward in a fresh private profile; the bounded default stays intact.

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "RIME_VISIT_LOOP_TEST_OK"
const FAILURE_MARKER := "RIME_VISIT_LOOP_TEST_FAILED"
const DESTINATION_ID: StringName = &"rime_glacial_world"
const AURORA_DESTINATION_ID: StringName = &"aurora_temperate_world"
const SurveyType := preload("res://scripts/activities/rime_ice_core_survey.gd")

var _assertions := 0
var _outbound_fixture_ready := false

const CANONICAL_STORE_PATH := "user://rime-canonical-completed-journey.json"
# Retain the shared atmospheric visit and existing Aurora physical-soak caps.
const CANONICAL_OUTBOUND_TICKS := 48_000
const CANONICAL_RETURN_TICKS := 72_000

var _surface_sampler: SurfaceSampler
var _canonical_reward: Dictionary = {}
var _canonical_activity_generation := -1


class RimeLegSampler extends LegSampler:
	var player_id := 0
	var craft_id := 0
	var identity_failures := 0
	var hull_failures := 0

	func _sample(game: GameFlow) -> void:
		super._sample(game)
		if not is_instance_valid(game.player) or not is_instance_valid(game.active_ship):
			identity_failures += 1
			return
		identity_failures += int(game.player.get_instance_id() != player_id
			or game.active_ship.get_instance_id() != craft_id)
		var telemetry := game.active_ship.get_telemetry() as Dictionary
		hull_failures += int(not is_equal_approx(float(telemetry.get("hull", 0.0)),
			float(telemetry.get("maximum_hull", -1.0))))


class SurfaceSampler extends Node:
	var game: GameFlow
	var visit: RefCounted
	var player_id := 0
	var craft_id := 0
	var samples := 0
	var max_frame_gap := 0
	var max_planar_step_m := 0.0
	var ownership_failures := 0
	var _last_frame := -1
	var _last_position := Vector3.INF
	var _translation := Vector3.ZERO

	func _ready() -> void:
		process_physics_priority = 1000
		player_id = game.player.get_instance_id()
		craft_id = visit.get_craft().get_instance_id()
		_last_position = game.player.global_position
		game.common_world_origin_rebase_owner.rebase_committed.connect(_on_rebase)

	func _exit_tree() -> void:
		game.common_world_origin_rebase_owner.rebase_committed.disconnect(_on_rebase)

	func _on_rebase(receipt: Dictionary) -> void:
		_translation += receipt.get("world_translation_delta", Vector3.ZERO) as Vector3

	func _physics_process(_delta: float) -> void:
		var player := game.player as PlayerController
		var craft := visit.get_craft() as HeroShip
		if not is_instance_valid(player) or not is_instance_valid(craft):
			ownership_failures += 1
			return
		var frame := Engine.get_physics_frames()
		if _last_frame >= 0:
			max_frame_gap = maxi(max_frame_gap, frame - _last_frame)
		max_planar_step_m = maxf(max_planar_step_m,
			(player.global_position - (_last_position + _translation)).slide(player.up_direction).length())
		ownership_failures += int(player.get_instance_id() != player_id or craft.get_instance_id() != craft_id
			or visit.state != &"surface" or player.is_seated() or craft.is_piloted()
			or not player.is_control_enabled() or game._transition_busy
			or process_physics_priority <= player.process_physics_priority)
		_last_position = player.global_position
		_last_frame = frame
		_translation = Vector3.ZERO
		samples += 1


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--rime-shared-completed-return" in OS.get_cmdline_user_args() or "--rime-shared-reboard-diagnostic" in OS.get_cmdline_user_args():
		await _run_shared_return()
	elif "--rime-completed-return" in OS.get_cmdline_user_args():
		await _run_canonical()
	else:
		await _run_bounded()


## Opt-in shared RETURN leg. Initial Rime arrival/cabin positioning is staged;
## every step after exterior admission, takeoff, home cruise and docking is real.
var _shared_crew_sequence := 0


class SharedReturnSampler extends RimeLegSampler:
	var body_ref: WeakRef
	var body_id := 0
	var crew_failures := 0
	var maximum_cabin_step := 0.0
	var previous_cabin_position := Vector3.INF

	func _sample(game: GameFlow) -> void:
		super._sample(game)
		var candidate: Variant = body_ref.get_ref() if body_ref != null else null
		if not is_instance_valid(candidate):
			crew_failures += 1
			return
		var body := candidate as PlayerController
		var craft := game.active_ship as HeroShip
		if not is_instance_valid(craft):
			crew_failures += 1
			return
		var frame := craft.get_moving_interior_component() as MovingInteriorFrame
		crew_failures += int(body.get_instance_id() != body_id or not body.is_cabin_containment_active()
			or not is_instance_valid(frame) or not frame.is_occupant_registered(body))
		var local := craft.to_local(body.global_position)
		if previous_cabin_position.is_finite():
			maximum_cabin_step = maxf(maximum_cabin_step, local.distance_to(previous_cabin_position))
		previous_cabin_position = local


func _shared_wait(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await physics_frame
		await process_frame
	return predicate.call() == true


func _shared_board_request(game: GameFlow, adapter: Node, craft: HeroShip, sequence: int, action: StringName) -> Dictionary:
	var peer: int = adapter.multiplayer.get_unique_id()
	return NetworkBoardingIntent.create(peer, GameFlow.network_client_boarding_avatar_id(peer), craft.get_ship_id(),
		1, StringName("frame_%s" % craft.get_ship_id()), 1, GameFlow.network_cabin_berth_seat_id(craft.get_ship_id(), 1),
		1, GameFlow.NETWORK_CABIN_BERTH_ROLE, sequence, game.network_session.get_boarding_server_tick(), action).to_dictionary()


func _shared_walk(game: GameFlow, adapter: Node, body: PlayerController, target: Vector3, leg: StringName = &"home_cabin") -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < deadline and is_instance_valid(body):
		var tick := Engine.get_physics_frames()
		game.network_session.set_movement_server_tick(tick)
		if tick % 4 == 0:
			var offset := (target - body.global_position).slide(body.up_direction)
			var moving := offset.length() > 0.7
			# Wire yaw is local to the authoritative body's camera parent, just
			# as production map_body_look_yaw maps a predicted heading to it.
			var camera_parent := body.get_node("CameraRig") as Node3D
			var local_heading := camera_parent.global_basis.orthonormalized().inverse() * offset
			var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
			adapter.send_movement_intent(NetworkMovementIntent.create(adapter.multiplayer.get_unique_id(), identity.entity_id,
				int(identity.entity_generation), 1001, _shared_crew_sequence, tick, Vector2(0, -1) if moving else Vector2.ZERO,
				false, &"", false, atan2(-local_heading.x, -local_heading.z)).to_dictionary())
			_shared_crew_sequence += 1
		game.get_network_remote_body_simulation().advance(tick)
		await physics_frame
		if is_instance_valid(body) and (body.global_position - target).slide(body.up_direction).length() <= 0.7 and body.is_on_floor():
			return true
	var valid := is_instance_valid(body)
	var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body) if valid else {}
	print("RIME_SHARED_WALK_FAILED: leg=", leg, " target=", target, " body_valid=", valid,
		" pose=", body.global_transform if valid else Transform3D.IDENTITY, " velocity=", body.velocity if valid else Vector3.ZERO,
		" planar_distance=", (target - body.global_position).slide(body.up_direction).length() if valid else INF,
		" vertical_distance=", (target - body.global_position).dot(body.up_direction) if valid else INF,
		" yaw=", body.get_look_yaw() if valid else NAN, " admission=", game._network_ember_passenger_surface_is_current(StringName(identity.get("entity_id", &""))) if valid else false,
		" floor=", body.is_on_floor() if valid else false, " local=", game.active_ship.to_local(body.global_position) if valid else Vector3.INF,
		" camera_parent_basis=", (body.get_node("CameraRig") as Node3D).global_basis if valid else Basis.IDENTITY,
		" record=", game.get_network_remote_body_simulation().get_body_record(StringName(identity.get("entity_id", &""))),
		" movement=", game.network_session.get_movement_avatar_snapshot(StringName(identity.get("entity_id", &""))),
		" audit=", game.network_session.get_movement_authority_audit())
	return false


func _run_shared_return() -> void:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	set_multiplayer(SceneMultiplayer.new(), game.get_path())
	await process_frame
	await physics_frame
	game.start_shift()
	game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var craft := game.get_node("HalyardCrewTransport") as HeroShip
	var home := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	home.release(craft, home.get_reservation_token(craft))
	game._reserved_berth_ids.erase(craft.get_instance_id())
	game._berth_tokens.erase(craft.get_instance_id())
	craft.global_transform = home.get_assist_capture_transform()
	game.player.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position()))
	game._board_ship(craft)
	var pilot_ready := await _shared_wait(func(): return game._piloting and game.player.is_seated_at(craft.get_pilot_seat_anchor()) and not game._transition_busy, 12.0)
	_check(pilot_ready, "shared return stages the actual occupied Halyard host pilot")
	var socket := UDPServer.new()
	socket.listen(0, "127.0.0.1")
	var port := socket.get_local_port()
	socket.stop()
	game._ensure_lan_discovery().discovery_port = 0
	var hosted := game.host_network_session(port, 2)
	_check(bool(hosted.get("accepted", false)), "shared return owns a real authoritative host session")
	var branch := SubViewport.new()
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var adapter := preload("res://scripts/network/network_enet_session_adapter.gd").new()
	adapter.name = String(GameFlow.NETWORK_SESSION_NODE_NAME)
	branch.add_child(adapter)
	adapter.join("127.0.0.1", port)
	var admitted := await _shared_wait(func(): return not adapter.get_server_offer().is_empty(), 10.0)
	_check(admitted, "shared return admits independent authenticated ENet crew")
	if admitted:
		adapter.send_boarding_intent(_shared_board_request(game, adapter, craft, 1, NetworkBoardingIntent.ACTION_BOARD))
	var avatar := GameFlow.network_client_boarding_avatar_id(adapter.multiplayer.get_unique_id())
	var boarded := admitted and await _shared_wait(func(): return game.get_network_remote_body_simulation() != null and game.get_network_remote_body_simulation().has_body(avatar), 12.0)
	_check(boarded, "shared return retains the actual confirmed cabin crew body")
	if boarded and pilot_ready:
		await _drive_shared_return(game, adapter, craft, home, avatar)
	_release_all_actions()
	adapter.shutdown()
	game.shutdown_network_session(&"shared_rime_return_fixture_done")
	branch.queue_free()
	await _tear_down(game)
	_finish()


func _drive_shared_return(game: GameFlow, adapter: Node, craft: HeroShip, home: ShipBerth, avatar: StringName) -> void:
	game.set_physics_process(false)
	var owner := game._rime_expedition
	var bootstrap := game.rime_streaming_bootstrap
	var binding := game.rime_streaming_binding
	var station_environment := game.get_viewport().world_3d.environment
	var station_visible := game.world.visible
	var selected := game._planetary_journey.admit_aurora_visit(craft, false, DESTINATION_ID)
	_check(bool(selected.get("accepted", false)), "shared return selects Rime's actual visit lane")
	if not bool(selected.get("accepted", false)):
		return
	craft.global_position = bootstrap.global_position + Vector3(0, 120030, 30)
	var sample := {"available": true, "position": craft.global_position, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id()}
	binding.physics_tick_from_caller_sample(0.0, sample)
	_check(bool(game.common_world_origin_rebase_owner.consume_rebase_preview(binding.preview_origin_rebase(bootstrap.get_coordinate_frame_for_session().get_generation()), sample).get("accepted", false)), "staged Rime arrival uses the actual common origin owner")
	var loaded := await _shared_wait(func(): return is_instance_valid(bootstrap.get_loaded_instance()), 10.0)
	_check(loaded, "shared return loads Rime's real production scene")
	if not loaded:
		return
	var scene := bootstrap.get_loaded_instance()
	var region := scene.get_node("LandingRegion") as Node3D
	owner._ship = craft
	owner._home = home
	owner._surface = scene
	owner._station_environment = station_environment
	owner._station_visible = station_visible
	owner._shared_arrival = true
	owner.state = &"landing"
	owner.survey.attach(scene)
	owner._lease_surface_berth(region)
	var berth := owner._berth as ShipBerth
	craft.global_transform = berth.get_assist_capture_transform()
	craft.velocity = Vector3.ZERO
	craft.request_berth_landing(berth)
	var docked := await _shared_wait(func(): return berth.get_occupant() == craft and not craft.is_landing_active(), 15.0)
	_check(docked, "shared return starts on Rime's actual occupied physical lease")
	if not docked:
		return
	owner.physics_tick(0.0)
	var bridge := game._network_planetary_journey
	bridge._epoch = 1
	bridge._craft_instance_id = craft.get_instance_id()
	bridge._pilot_source_ref = weakref(craft.get_command_source())
	bridge._state = {"journey_epoch": 1, "world_id": DESTINATION_ID, "ship_id": craft.get_ship_id(), "phase": &"landed"}
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var simulation := game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var body_id := body.get_instance_id()
	var hatch := craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	# Last actor placement is before exterior admission, at the actual hatch.
	body.teleport_to(Transform3D(Basis.IDENTITY, hatch.global_position - Vector3.UP * 0.7))
	for tick in 12:
		await physics_frame
	adapter.send_boarding_intent(_shared_board_request(game, adapter, craft, 2, NetworkBoardingIntent.ACTION_DISEMBARK))
	var exterior := await _shared_wait(func(): return simulation.is_surface_walking(avatar), 5.0)
	_check(exterior, "shared return crew exits by its authenticated ordinary hatch request")
	if not exterior:
		return
	_check(not owner.request(), "exterior Rime crew cannot be carried home before reboarding")
	var walked := await _shared_walk(game, adapter, body, region.to_global(Vector3(-8, 0, -8)), &"pad_outbound")
	for marker_name in [^"WalkableInterior/InteriorAccessMarker", ^"WalkableInterior/InteriorDeckMarker"]:
		var marker := craft.get_node(marker_name) as Marker3D
		walked = walked and await _shared_walk(game, adapter, body, marker.global_position, StringName(marker.name))
	_check(walked, "same admitted Rime crew walks ordinary intents out and back through the real hatch")
	if not walked:
		return
	# Stop through fresh accepted neutral inputs, preserving the real stream.
	for settle in 12:
		var tick := Engine.get_physics_frames()
		game.network_session.set_movement_server_tick(tick)
		if tick % 4 == 0:
			var identity := NetworkRemoteBodySimulation.get_remote_body_identity(body)
			adapter.send_movement_intent(NetworkMovementIntent.create(adapter.multiplayer.get_unique_id(), identity.entity_id,
				int(identity.entity_generation), 1001, _shared_crew_sequence, tick).to_dictionary())
			_shared_crew_sequence += 1
		game.get_network_remote_body_simulation().advance(tick)
		await physics_frame
	adapter.send_boarding_intent(_shared_board_request(game, adapter, craft, 3, NetworkBoardingIntent.ACTION_BOARD_ANY))
	var reboarded := await _shared_wait(func(): return is_instance_valid(body) and not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active(), 5.0)
	_check(reboarded and simulation.get_body(avatar) == body, "actual authenticated reboard retains the same crew body for home travel")
	if not reboarded:
		return
	if "--rime-shared-reboard-diagnostic" in OS.get_cmdline_user_args():
		print("RIME_SHARED_REBOARD_DIAGNOSTIC_COMPLETE: return_travel=NOT_RUN")
		return
	var reward_before := (game.get("_game_flow_reward_authority") as RefCounted).call(&"get_snapshot") as Dictionary
	var sampler := SharedReturnSampler.new()
	sampler.player_id = game.player.get_instance_id()
	sampler.craft_id = craft.get_instance_id()
	sampler.body_ref = weakref(body)
	sampler.body_id = body_id
	sampler.start_physics_sampling(self, game, &"shared_rime_return", false)
	_physics_samplers.append(sampler)
	game.set_physics_process(true)
	_check(_press_rime_canonical_destination(game) and owner.state == &"return_cruise", "actual Rime Destination Board queues the authenticated shared home return")
	if owner.state != &"return_cruise" or not await _clear_rime_canonical_surface(game, craft, owner):
		await sampler.stop_physics_sampling()
		return
	for tick in CANONICAL_RETURN_TICKS:
		await physics_frame
		await process_frame
		if tick % 1200 == 0:
			print("RIME_SHARED_RETURN tick=", tick, " distance_m=", sampler.distance_flown_m, " rebases=", sampler.rebase_count, " state=", owner.state)
		if not owner.is_active() or craft.is_destroyed():
			break
	var receipt := game._planetary_journey.get_aurora_visit_snapshot()
	var handed_off := bool(receipt.get("return_handoff_ready", false)) and not owner.is_active() and bridge._home_approach
	_check(handed_off and sampler.distance_flown_m > 9_800_000.0 and sampler.rebase_count > 900,
		"real shared Rime cruise crosses 9.8Mm and900 rebases before its typed home handoff")
	_check(sampler.crew_failures == 0 and is_instance_valid(body) and sampler.maximum_cabin_step <= body.walk_speed / float(Engine.physics_ticks_per_second) + 0.01
		and simulation.get_body(avatar) == body and body.get_instance_id() == body_id,
		"every shared return tick preserves the same confirmed crew body and ordinary cabin continuity")
	if handed_off:
		_check(await _fly_home_berth(game, sampler), "ordinary controls dock at the original home berth, disembark and walk on supported yard ground")
		_check(not bridge.is_active() and bridge._home_return_context.is_empty() and home.get_occupant() == craft
			and simulation.get_body(avatar) == body and body.get_instance_id() == body_id,
			"accepted home docking retires the shared journey without moving or replacing the retained crew")
		if is_instance_valid(body) and simulation.get_body(avatar) == body:
			await _shared_home_crew_exit(game, adapter, craft, home, body, avatar)
	_check_rime_leg(sampler, "shared return and ordinary home docking")
	_check((game.get("_game_flow_reward_authority") as RefCounted).call(&"get_snapshot") == reward_before and not owner.survey.reward_recorded(),
		"shared Rime return grants no unsupported survey reward or duplicate reward")


func _shared_home_crew_exit(game: GameFlow, adapter: Node, craft: HeroShip, home: ShipBerth,
		body: PlayerController, avatar: StringName) -> void:
	var simulation := game.get_network_remote_body_simulation()
	var frame := craft.get_moving_interior_component() as MovingInteriorFrame
	var applied_before := int(simulation.get_body_record(avatar).get("intents_applied", 0))
	var start := body.global_position
	var marker := craft.call(&"get_interior_deck_marker") as Marker3D
	var walked := is_instance_valid(marker) and await _shared_walk(game, adapter, body,
		marker.global_position + craft.global_basis.x * 1.75 + craft.global_basis.z * 1.8, &"home_cabin_fresh_input")
	walked = walked and is_instance_valid(marker) and await _shared_walk(game, adapter, body, marker.global_position, &"home_hatch")
	_check(walked and is_instance_valid(body) and body.global_position.distance_to(start) > 0.25
		and int(simulation.get_body_record(avatar).get("intents_applied", 0)) > applied_before
		and game._network_ember_passenger_at_hatch(body, craft, false),
		"retained home crew accepts fresh ordinary movement and physically walks to the actual hatch")
	if not walked or not is_instance_valid(body):
		return
	_check(home.get_occupant() == craft and game._ship_owns_exact_occupied_berth(craft, home.get_berth_id()),
		"ordinary crew exit still owns the exact accepted physical home lease")
	adapter.send_boarding_intent(_shared_board_request(game, adapter, craft, 4, NetworkBoardingIntent.ACTION_DISEMBARK))
	var released := await _shared_wait(func(): return not simulation.has_body(avatar), 5.0)
	print("RIME_HOME_CREW_EXIT: ", adapter.get_boarding_intent_result_replica())
	var result: Dictionary = adapter.get_boarding_intent_result_replica()
	var held := false
	for occupancy: Dictionary in game.network_session.get_boarding_snapshot().get("occupancies", []):
		held = held or occupancy.get("avatar_id") == avatar
	var frame_holds := false
	for occupant: Node3D in frame.get_registered_occupants():
		frame_holds = frame_holds or NetworkRemoteBodySimulation.get_remote_body_identity(occupant).get("entity_id") == avatar
	_check(released and bool(result.get("accepted", false)) and result.get("status") == &"disembarked"
		and not held and not frame_holds and game.network_session.get_movement_avatar_snapshot(avatar).is_empty(),
		"fresh authenticated home hatch exit releases only its cabin body, seat, frame and old movement stream")
	# This independent Adapter has no local GameFlow ground avatar. It proves
	# ordinary owned cabin release, not client-side walking on the yard ground.


## Opt-in long route. The only actor placement is the disclosed initial yard
## on-foot approach in _walk_and_board; every subsequent leg uses live controls.
## The default below retains its bounded arrival, interruption and abandon cases.
func _run_canonical() -> void:
	if OS.get_environment("KETH_EMBER_PHYSICAL_RETURN") == "1" \
			or OS.get_environment("KETH_RETURN_ARRIVAL_DIAGNOSTIC") == "1":
		_check(false, "canonical Rime runs independently of Ember abandon and local-arrival modes")
		_finish()
		return
	var filesystem := UserDataFilesystem.new()
	var fresh := true
	for suffix in ["", ".tmp", ".bak", ".bak.1", ".bak.2", ".bak.3"]:
		fresh = fresh and not filesystem.file_exists(CANONICAL_STORE_PATH + suffix)
	_check(fresh, "canonical Rime requires a fresh private disk-backed profile")
	if not fresh:
		_finish()
		return
	var game := MAIN.instantiate() as GameFlow
	var store := Store.new(CANONICAL_STORE_PATH, filesystem)
	game.configure_runtime_settings_persistence(store, "user://rime-canonical-completed-legacy.cfg")
	root.add_child(game)
	for _tick in 240:
		await physics_frame
		await process_frame
		if bool(game.get("_initialized")) and game.get_flyable_ships().size() >= 9:
			break
	_check(bool(game.get("_initialized")) and game.get_flyable_ships().size() >= 9,
		"canonical Rime waits for genuine production initialization")
	if not bool(game.get("_initialized")) or game.get_flyable_ships().size() < 9:
		await _end_canonical(game)
		return
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	game.start_shift()
	await process_frame
	var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	_check(bool(selected.get("accepted", false)), "the production activity selector leaves the timed race idle")
	var craft: HeroShip
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == &"arrow_provisional":
			craft = candidate
	var visit: RefCounted = game.get("_rime_expedition")
	_check(craft != null and visit != null, "production Main composes Arrow and the Rime visit owner")
	if craft == null or visit == null or not bool(selected.get("accepted", false)):
		await _end_canonical(game)
		return
	var player := game.player as PlayerController
	var player_id := player.get_instance_id()
	var craft_id := craft.get_instance_id()
	var home_berth_id := craft.get_home_berth_id()
	await _await_free_on_foot(game, player)
	print("RIME_CANONICAL_INITIAL_FIXTURE: on-foot yard approach six metres outside Arrow's boarding area")
	var boarded := await _walk_and_board(game, player, craft, true)
	_check(boarded, "ordinary yard walking and interact board Arrow without manufacturing tutorial completion")
	if not boarded:
		await _end_canonical(game)
		return
	var outbound := _start_rime_leg(game, &"rime_outbound")
	var departed := await _launch_completed(game, craft)
	_check(departed, "ordinary held controls physically depart the registered yard berth")
	var cleared: bool = departed and await _clear_completed_departure_hulk(game, craft)
	_check(cleared, "ordinary climbing controls clear the real departure hulk")
	var aligned: bool = cleared and await _align_rime_canonical(game, craft)
	_check(aligned, "ordinary steering and braking align the craft with Rime's absolute navigation anchor")
	if not aligned or not _press_rime_canonical_destination(game):
		await _end_canonical(game)
		return
	_check(visit.state in [&"outbound", &"corridor"] and visit.is_active(),
		"the actual Destination Board admits the canonical Rime outbound")
	for tick in CANONICAL_OUTBOUND_TICKS:
		await physics_frame
		await process_frame
		if visit.state == &"landing":
			outbound.physics_phase = &"landing"
		if tick % 1200 == 0:
			print("RIME_CANONICAL_OUTBOUND tick=", tick, " state=", visit.state,
				" distance=", outbound.distance_flown_m, " rebases=", outbound.rebase_count)
		if visit.state == &"landed" or not visit.is_active() or craft.is_destroyed():
			break
	await outbound.stop_physics_sampling()
	var surface := visit.get("_surface") as Node3D
	var berth := visit.get("_berth") as ShipBerth
	var snapshot := visit.get_visit_snapshot() as Dictionary
	var journey := snapshot.get("journey", {}) as Dictionary
	var landed: bool = visit.state == &"landed" and is_instance_valid(surface) \
		and surface == game.rime_streaming_bootstrap.get_loaded_instance() \
		and is_instance_valid(berth) and berth.get_occupant() == craft \
		and bool(craft.get_telemetry().get("landed", false)) \
		and craft.get_landing_contract_report().get("phase") == HeroShip.LANDING_PHASE_DOCKED
	_check(landed and outbound.distance_flown_m > 9_800_000.0 and outbound.rebase_count > 900,
		"unstaged outbound covers Rime's full ten-million-metre route and genuinely docks")
	_check(bool(journey.get("final_approach_handoff_ready", false))
		and int(snapshot.get("staging_events", -1)) == 0,
		"Rime touchdown follows the real final-approach receipt with zero expedition actor placements")
	_check_rime_leg(outbound, "outbound")
	_check(outbound.max_landing_step_m <= craft.maximum_speed / float(Engine.physics_ticks_per_second) + 0.01,
		"each physical Rime touchdown step stays within ordinary craft speed")
	if not landed or not _failures.is_empty():
		print("RIME_CANONICAL_REJECTED outbound=", snapshot)
		await _end_canonical(game)
		return
	await _press_interact()
	await _wait_state(visit, &"surface", 400)
	for _tick in 30:
		await physics_frame
	_check(visit.state == &"surface" and player.is_control_enabled() and player.is_on_floor()
		and not player.is_seated() and not craft.is_piloted(),
		"ordinary disembarking reaches supported Rime ice with live on-foot control")
	if visit.state != &"surface" or not player.is_on_floor() or not player.is_control_enabled():
		await _end_canonical(game)
		return
	_surface_sampler = SurfaceSampler.new()
	_surface_sampler.game = game
	_surface_sampler.visit = visit
	game.add_child(_surface_sampler)
	var survey: RefCounted = visit.get("survey")
	if not await _canonical_walk(game, visit,
			[Vector3(-7, 0, -17), Vector3(-18, 0, -16), Vector3(-23, 0, -16)],
			"ordinary walking reaches the Rime survey beacon"):
		await _end_canonical(game)
		return
	_check(String(survey.prompt()).contains("START"), "the real beacon offers START")
	await _press_interact()
	var progress := survey.snapshot() as Dictionary
	_canonical_activity_generation = int(progress.get("generation", -1))
	_check(int(progress.get("state", -1)) == CheckpointRouteActivity.State.ACTIVE
		and _canonical_activity_generation > 0 and not survey.reward_recorded(),
		"ordinary E starts a new unpaid Rime survey through ActivityDirector")
	if not _failures.is_empty() or not await _canonical_walk(game, visit,
			[Vector3(-40, 0, -28), Vector3(-52, 0, -42), Vector3(-54, 0, -45.5)],
			"ordinary walking reaches the heated drill rig"):
		await _end_canonical(game)
		return
	_check(String(survey.prompt()).contains("EXTRACT") and bool(survey.get_heat_snapshot().get("warm", false)),
		"the real heated drill rig offers EXTRACT without injecting heater time")
	await _press_interact()
	_check(int(survey.snapshot().get("next_checkpoint_index", -1)) == 1
		and int(survey.snapshot().get("generation", -1)) == _canonical_activity_generation,
		"ordinary E records the actual core extraction in the original survey generation")
	await _press_interact()
	_check(int(survey.snapshot().get("next_checkpoint_index", -1)) == 1 and not survey.reward_recorded(),
		"repeated extraction cannot satisfy the ridge objective or grant a reward")
	if not _failures.is_empty() or not await _canonical_walk(game, visit,
			[Vector3(-40, 0, -28), Vector3(-7, 0, -17), Vector3(8, 0, -20),
			Vector3(20, 0, -40), Vector3(29, 0, -61)],
			"ordinary walking follows the cyan route to the strain gauge"):
		await _end_canonical(game)
		return
	_check(String(survey.prompt()).contains("STRAIN"), "the real ridge offers the strain reading")
	await _press_interact()
	progress = survey.snapshot() as Dictionary
	_check(int(progress.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED
		and int(progress.get("next_checkpoint_index", -1)) == 2
		and int(progress.get("generation", -1)) == _canonical_activity_generation
		and survey.reward_recorded() and int(survey.get_heat_snapshot().get("failures", -1)) == 0,
		"ordinary E completes both real Rime objectives before natural heat depletion")
	var authority: RefCounted = game.get("_game_flow_reward_authority")
	_canonical_reward = (authority.call(&"get_snapshot") as Dictionary).get("record", {}) as Dictionary
	_check_canonical_disk_reward("at genuine survey completion")
	var reward_generation := store.get_generation()
	await _press_interact()
	_check(store.get_generation() == reward_generation
		and ((authority.call(&"get_snapshot") as Dictionary).get("record", {}) as Dictionary) == _canonical_reward,
		"repeated completed interaction cannot write or reward again")
	if not _failures.is_empty() or not await _canonical_walk(game, visit,
			[Vector3(20, 0, -40), Vector3(8, 0, -20), Vector3(-7, 0, -17)],
			"ordinary walking returns to Rime's pad"):
		await _end_canonical(game)
		return
	var boarding_area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var reached := await _canonical_walk_target(game, craft.get_boarding_position, 720,
		func() -> bool: return boarding_area in player.get_nearby_interactables())
	_check(reached and player.is_on_floor(), "ordinary walking reaches Arrow's actual surface boarding area")
	_check(_surface_sampler.samples > 0 and _surface_sampler.max_frame_gap <= 1
		and _surface_sampler.ownership_failures == 0
		and _surface_sampler.max_planar_step_m <= player.walk_speed / float(Engine.physics_ticks_per_second) + 0.01,
		"every surface physics tick preserves actor identity, on-foot control and ordinary walking continuity")
	var surface_samples := _surface_sampler.samples
	_stop_surface_sampler()
	if not reached or not _failures.is_empty():
		await _end_canonical(game)
		return
	await _press_interact()
	await _wait_state(visit, &"landed", 600)
	_check(visit.state == &"landed" and player.is_seated_at(craft.get_pilot_seat_anchor())
		and craft.is_piloted() and boarding_area.get_reservation_token() == player,
		"ordinary E genuinely reboards the same craft on Rime")
	if visit.state != &"landed" or not player.is_seated():
		await _end_canonical(game)
		return
	var returning := _start_rime_leg(game, &"rime_return")
	var pose := craft.global_transform
	var velocity := craft.velocity
	var queued := _press_rime_canonical_destination(game)
	_check(queued and visit.state == &"return_cruise"
		and game._planetary_journey.is_return_departure_pending()
		and craft.global_transform == pose and craft.velocity == velocity and berth.get_occupant() == craft,
		"the actual return action queues manual departure while preserving the occupied surface lease")
	if not queued or visit.state != &"return_cruise" or not await _clear_rime_canonical_surface(game, craft, visit):
		await _end_canonical(game)
		return
	for tick in CANONICAL_RETURN_TICKS:
		await physics_frame
		await process_frame
		if tick % 1200 == 0:
			print("RIME_CANONICAL_RETURN tick=", tick, " state=", visit.state,
				" distance=", returning.distance_flown_m, " rebases=", returning.rebase_count)
		if not visit.is_active() or craft.is_destroyed():
			var terminal_return := game._planetary_journey.get_aurora_visit_snapshot() as Dictionary
			if craft.is_destroyed() or not bool(terminal_return.get("return_handoff_ready", false)):
				_print_rime_return_rejection(game, craft, visit, returning, tick)
			break
	# This shared surface-visit API selects Rime through its actual world_id.
	var returned := game._planetary_journey.get_aurora_visit_snapshot() as Dictionary
	var handed_off: bool = bool(returned.get("return_handoff_ready", false)) and not visit.is_active() \
		and game.phase == GameFlow.Phase.FREE_FLIGHT and game.active_ship == craft \
		and player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted() \
		and not bool(craft.get_telemetry().get("landed", true))
	_check(handed_off and returning.distance_flown_m > 9_800_000.0 and returning.rebase_count > 900,
		"the full physical home cruise hands the original seated actors to ordinary manual flight")
	_check(not bool(game._planetary_journey.get("_planetary_return_physical_arrival_required"))
		and not bool(game._planetary_journey.get("_ember_abandon_return_active")),
		"Rime return uses its actual typed lane without borrowing Ember completion or abandon state")
	if handed_off:
		_check(await _fly_home_berth(game, returning),
			"ordinary pilot controls reach the original home berth, dock, disembark and walk on yard ground")
	_check_rime_leg(returning, "return and home docking")
	var home := game.world.get_berth_node(home_berth_id) as ShipBerth
	var home_token := home.get_reservation_token(craft)
	_check(game.player.get_instance_id() == player_id and craft.get_instance_id() == craft_id
		and game.active_ship == craft and home.get_occupant() == craft and not home_token.is_empty()
		and home_token == StringName((game.get("_berth_tokens") as Dictionary).get(craft_id, &""))
		and bool(craft.get_telemetry().get("landed", false)) and not craft.is_piloted()
		and not player.is_seated() and player.is_on_floor() and player.is_control_enabled()
		and not is_instance_valid(game.rime_streaming_bootstrap.get_loaded_instance())
		and int(visit.get_visit_snapshot().get("staging_events", -1)) == 0,
		"home arrival retains the exact actors and registered lease, unloads Rime and leaves a supported walking pilot")
	_check_canonical_disk_reward("after the real home walking exit", true)
	print("RIME_CANONICAL_JOURNEY outbound_m=", outbound.distance_flown_m,
		" return_m=", returning.distance_flown_m, " outbound_rebases=", outbound.rebase_count,
		" return_rebases=", returning.rebase_count, " surface_samples=", surface_samples)
	await _end_canonical(game)


func _print_rime_return_rejection(
		game: GameFlow, craft: HeroShip, visit: RefCounted, sampler: RimeLegSampler, tick: int
	) -> void:
	var surface := game.rime_streaming_bootstrap.get_loaded_instance() as Node3D
	var region := surface.get_node_or_null(^"LandingRegion") as Node3D if is_instance_valid(surface) else null
	var held_actions: Array[StringName] = []
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		if Input.is_action_pressed(action):
			held_actions.append(action)
	print("RIME_CANONICAL_RETURN_REJECTED ", {
		"observation": tick, "physics_frame": Engine.get_physics_frames(),
		"visit": visit.get_visit_snapshot(),
		"current_gate": game._planetary_journey.call(&"_aurora_cruise_gate_reason"),
		"current_cruise": game.planetary_cruise_binding.get_snapshot(),
		"attachment": craft.get_planetary_cruise_attachment_report(),
		"telemetry": craft.get_telemetry(), "craft_pose": craft.global_transform,
		"craft_velocity": craft.velocity, "player_pose": game.player.global_transform,
		"ship_region_local": region.to_local(craft.global_position) if is_instance_valid(region) else Vector3.INF,
		"phase": game.phase, "piloting": game._piloting, "seated": game.player.is_seated(),
		"manual_intent": craft.has_manual_flight_intent(), "held_actions": held_actions,
		"return_distance_m": sampler.distance_flown_m, "return_rebases": sampler.rebase_count,
	})


func _start_rime_leg(game: GameFlow, phase_name: StringName) -> RimeLegSampler:
	var sampler := RimeLegSampler.new()
	sampler.player_id = game.player.get_instance_id()
	sampler.craft_id = game.active_ship.get_instance_id()
	# Both callers have already observed Rime's real occupied pilot seat. Ember's
	# optional wait-for-seat predicate is not part of this planet's admission.
	sampler.start_physics_sampling(self, game, phase_name, false)
	_physics_samplers.append(sampler)
	return sampler


func _check_rime_leg(sampler: RimeLegSampler, label: String) -> void:
	_check(sampler.physics_samples > 0 and sampler.max_physics_frame_gap <= 1
		and sampler.max_ship_step_m <= TICK_STEP_LIMIT_M and sampler.max_player_step_m <= TICK_STEP_LIMIT_M
		and sampler.max_speed_mps <= CRUISE_SPEED_LIMIT_MPS + 0.001
		and sampler.occupancy_failures == 0 and sampler.identity_failures == 0 and sampler.hull_failures == 0,
		"each %s physics tick preserves full hull, exact actors, occupied pilot authority and cruise continuity" % label)


func _press_rime_canonical_destination(game: GameFlow) -> bool:
	game.call(&"_sync_planetary_cruise_hud")
	game.hud.open_planetary_destination_board()
	var button := game.hud.find_child("PlanetaryDestinationAction_%s" % DESTINATION_ID, true, false) as Button
	var enabled: bool = button != null and button.is_visible_in_tree() and not button.disabled
	_check(enabled, "Rime's actual Destination Board action is visible and enabled")
	if enabled:
		button.pressed.emit()
	return enabled


## The same existing 240-observation steering/braking policy, resolved against
## Rime's real absolute coordinate frame rather than Ember's navigation binding.
func _align_rime_canonical(game: GameFlow, craft: HeroShip) -> bool:
	var player := game.player as PlayerController
	var area := craft.get_node(^"ShipBoardingArea") as ShipBoardingArea
	var frame := game.rime_streaming_bootstrap.get_coordinate_frame_for_session()
	var navigation := game.rime_streaming_bootstrap.get_navigation_destination() as Dictionary
	var encoded := frame.body_local_to_orbital_position(
		navigation.get("body_local_position_meters"), frame.get_generation())
	var canonical := encoded.get("coordinate", {}) as Dictionary
	var aligned := false
	var nose_alignment := -1.0
	var motion_alignment := -1.0
	for _tick in DEPARTURE_TICK_BUDGET:
		_release_flight_controls(craft)
		var decoded := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
		var target := decoded.get("position", Vector3.INF) as Vector3
		var offset := target - craft.global_position
		if not target.is_finite() or not offset.is_finite() or offset.length_squared() <= 0.0 \
				or craft.is_destroyed() or not craft.is_piloted() \
				or not player.is_seated_at(craft.get_pilot_seat_anchor()) \
				or area.get_reservation_token() != player or bool(craft.get_telemetry().get("landed", true)):
			break
		var direction := offset.normalized()
		var local := craft.global_basis.inverse() * direction
		var yaw := atan2(local.x, -local.z)
		var pitch := atan2(local.y, Vector2(local.x, local.z).length())
		_set_signed_action(&"move_right", &"move_left", yaw * 3.0)
		_set_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
		Input.action_press(&"brake")
		await physics_frame
		await process_frame
		nose_alignment = (-craft.global_basis.z.normalized()).dot(direction)
		motion_alignment = craft.velocity.normalized().dot(direction) if craft.velocity.length() > 0.0 else nose_alignment
		aligned = nose_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT \
			and motion_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT
		if aligned:
			break
	_release_all_actions()
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	# Recheck after releasing the actual commands, before asking for admission.
	var decoded := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
	var target := decoded.get("position", Vector3.INF) as Vector3
	if target.is_finite() and (target - craft.global_position).length_squared() > 0.0:
		var direction := (target - craft.global_position).normalized()
		nose_alignment = (-craft.global_basis.z.normalized()).dot(direction)
		motion_alignment = craft.velocity.normalized().dot(direction) if craft.velocity.length() > 0.0 else nose_alignment
		aligned = aligned and nose_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT \
			and motion_alignment >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT
	else:
		aligned = false
	aligned = aligned and not craft.is_destroyed() and craft.is_piloted() \
		and player.is_seated_at(craft.get_pilot_seat_anchor()) and area.get_reservation_token() == player \
		and not bool(craft.get_telemetry().get("landed", true))
	if not aligned:
		print("RIME_CANONICAL_ALIGNMENT_REJECTED alignment=", {"position": craft.global_position,
			"velocity": craft.velocity, "nose_alignment": nose_alignment,
			"motion_alignment": motion_alignment, "required_alignment": PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT})
	return aligned



func _canonical_walk(game: GameFlow, visit: RefCounted, points: Array, label: String) -> bool:
	var region := (visit.get("_surface") as Node3D).get_node("LandingRegion") as Node3D
	for point: Vector3 in points:
		var target := func() -> Vector3: return region.to_global(point)
		var arrived := func() -> bool:
			return (region.to_global(point) - game.player.global_position).slide(game.player.up_direction).length() < 0.7
		if not await _canonical_walk_target(game, target, 1400, arrived):
			print("RIME_CANONICAL_WALK_REJECTED player=", region.to_local(game.player.global_position),
				" target=", point, " floor=", game.player.is_on_floor(), " survey=", visit.survey.snapshot())
			_check(false, label)
			return false
	_check(game.player.is_on_floor(), label)
	return game.player.is_on_floor()


## Resolve live camera-relative action axes, the same basis used by Player's
## production movement. No camera, player or surface transform is assigned.
func _canonical_walk_target(game: GameFlow, target: Callable, budget: int, arrived: Callable) -> bool:
	var player := game.player as PlayerController
	var camera_yaw := player.get_node("CameraRig/CameraYaw") as Node3D
	for _tick in budget:
		if bool(arrived.call()):
			break
		if player.is_seated() or not player.is_control_enabled() or game._transition_busy:
			break
		var offset := ((target.call() as Vector3) - player.global_position).slide(player.up_direction)
		var forward := (-camera_yaw.global_basis.z).slide(player.up_direction).normalized()
		if forward.is_zero_approx():
			forward = (-player.global_basis.z).slide(player.up_direction).normalized()
		var right := forward.cross(player.up_direction).normalized()
		var direction := offset.normalized()
		_set_signed_action(&"move_right", &"move_left", direction.dot(right))
		_set_signed_action(&"move_forward", &"move_back", direction.dot(forward))
		await physics_frame
		await process_frame
	_release_all_actions()
	for _tick in 8:
		await physics_frame
		await process_frame
	return bool(arrived.call()) and player.is_on_floor() and player.is_control_enabled()


func _clear_rime_canonical_surface(game: GameFlow, craft: HeroShip, visit: RefCounted) -> bool:
	var pad_basis := craft.global_basis
	var direction := (pad_basis.y * 0.85 - pad_basis.z * 0.5).normalized()
	var height := 0.0
	Input.action_press(&"move_forward")
	# Same physical atmospheric departure budget and clearance as Aurora's soak.
	for _tick in 1800:
		var local := craft.global_basis.inverse() * direction
		_set_signed_action(&"move_right", &"move_left", atan2(local.x, -local.z) * 3.0)
		_set_signed_action(&"pitch_up", &"pitch_down", atan2(local.y, Vector2(local.x, local.z).length()) * 3.0)
		await physics_frame
		await process_frame
		var origin: Vector3 = visit.call(&"_landing_region_origin")
		height = (craft.global_position - origin).dot(pad_basis.y)
		if height >= 1200.0 or craft.is_destroyed() or not craft.is_piloted():
			break
	_release_all_actions()
	var cleared: bool = height >= 1200.0 and not bool(craft.get_telemetry().get("landed", true))
	_check(cleared, "ordinary pilot controls physically clear Rime before home cruise")
	if not cleared:
		print("RIME_CANONICAL_DEPARTURE_REJECTED height=", height, " visit=", visit.get_visit_snapshot())
	return cleared


func _check_canonical_disk_reward(label: String, retired: bool = false) -> void:
	# An independent read-only store decodes the actual atomic document. It does
	# not reuse the live authority's cached slot or write the saved profile.
	var reader := Store.new(CANONICAL_STORE_PATH, UserDataFilesystem.new())
	var loaded := reader.load_read_only() as Dictionary
	var payload := loaded.get("payload", {}) as Dictionary
	var record := payload.get(String(GameFlowRewardAuthority.SLOT_ID), {}) as Dictionary
	var receipt := record.get("last_receipt", {}) as Dictionary
	var validator := GameFlowRewardAuthority.new()
	# UserDataStore exposes parsed JSON numbers as floats; the live authority
	# retains its integer receipt fields. Compare the complete original record
	# in that same wire representation, keeping the live idempotence check intact.
	var expected_wire := JSON.parse_string(JSON.stringify(_canonical_reward, "", true, true)) as Dictionary
	_check(bool(loaded.get("accepted", false)) and loaded.get("source") == &"primary"
		and bool(validator.validate_record(record).get("accepted", false)) and record == expected_wire
		and int(record.get("total_receipts", -1)) == 1
		and int((record.get("reward_counts", {}) as Dictionary).get(String(SurveyType.REWARD_ID), 0)) == 1
		and StringName(receipt.get("activity_id", &"")) == SurveyType.ACTIVITY_ID
		and StringName(receipt.get("reward_id", &"")) == SurveyType.REWARD_ID
		and int(receipt.get("activity_generation", -1)) == _canonical_activity_generation
		and bool(receipt.get("granted", false)) and not bool(receipt.get("replay_allowed", true))
		and (not retired or not payload.has(String(GameFlow.RIME_EXPEDITION_PERSISTENCE_SLOT))),
		"independently decoded disk retains exactly the original paid Rime receipt %s" % label)


func _stop_surface_sampler() -> void:
	if is_instance_valid(_surface_sampler):
		_surface_sampler.get_parent().remove_child(_surface_sampler)
		_surface_sampler.free()
	_surface_sampler = null


func _end_canonical(game: GameFlow) -> void:
	_stop_surface_sampler()
	await _tear_down(game)
	if not _canonical_reward.is_empty():
		_check_canonical_disk_reward("after Main teardown")
	_finish()


func _finish() -> void:
	_release_all_actions()
	print("%s: %d assertions" % [SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions])
	quit(0 if _failures.is_empty() else 1)


func _run_bounded() -> void:
	var game := await _boot()
	var craft := await _board_halyard(game)
	if craft == null:
		await _finish_bounded(game)
		return
	var owner: RefCounted = game.get("_rime_expedition")
	var home_berth_id := craft.get_home_berth_id()

	# --- the board lists Rime; admit, cruise, land ----------------------------
	await _prepare_bounded_outbound(game)
	var row := _row(game, DESTINATION_ID)
	_check(
		bool(row.get("route_available", false)) and bool(row.get("action_enabled", false))
			and row.get("environment_id") == &"atmospheric",
		"Rime is listed and selectable on the Destination Board (%s)" % row.get("status_text", "")
	)
	_check(
		float(row.get("orbital_distance_meters", 0.0)) == 10_000_000.0,
		"the board reads Rime's distance from its own absolute orbital datum"
	)
	if not bool(row.get("action_enabled", false)):
		await _finish_bounded(game)
		return
	await _press_destination(game)
	var aurora_row := _row(game, AURORA_DESTINATION_ID)
	_check(
		owner.is_active() and not bool(aurora_row.get("action_enabled", true)),
		"while Rime's visit holds the shared surface-visit lane, Aurora's row is refused"
	)
	var outbound_row := _row(game, DESTINATION_ID)
	_check(owner.state in [&"outbound", &"corridor"]
			and str(outbound_row.get("action_text", "")) == "ABANDON APPROACH",
		"mid-cruise the Rime button names the abandon it performs, not a return (%s)"
			% outbound_row.get("action_text", ""))
	await _wait_state(owner, &"landed", 6000)
	if owner.state != &"landed":
		print("RIME VISIT DIAG: ", owner.get_visit_snapshot())
	_check(owner.state == &"landed", "the visit reaches a landed craft at Rime")
	if owner.state != &"landed":
		await _finish_bounded(game)
		return

	var surface := owner.get("_surface") as Node3D
	var berth := owner.get("_berth") as ShipBerth
	var visit := owner.get_visit_snapshot() as Dictionary
	var journey := visit.get("journey", {}) as Dictionary
	_check(
		is_instance_valid(surface) and surface is RimeGlacialAuthoredScene
			and surface == game.rime_streaming_bootstrap.get_loaded_instance()
			and craft.global_position.distance_to(game.world.global_position) > 9_000_000.0,
		"the streamed Rime world is standing and the craft is really there"
	)
	_check(
		journey.get("world_id") == RimeGlacialStreamingBootstrap.WORLD_ID
			and int(journey.get("rebase_commit_count", 0)) >= 1
			and game.common_world_origin_rebase_owner.get_snapshot().get("last_world_id", &"")
				== RimeGlacialStreamingBootstrap.WORLD_ID,
		"the way out commits real common-world origin rebases, named for Rime (%d)"
			% int(journey.get("rebase_commit_count", 0))
	)
	_check(
		bool(journey.get("final_approach_handoff_ready", false))
			and (journey.get("final_approach_completion_receipt", {}) as Dictionary).get("reason", &"")
				== &"final_approach_handoff_ready"
			and int(visit.get("staging_events", -1)) == 0,
		"the descent is a completed production final approach with zero actor placements"
	)
	_check(
		is_instance_valid(berth) and berth.get_occupant() == craft
			and berth.get_parent() == surface.get_node_or_null(^"LandingRegion")
			and bool(craft.get_telemetry().get("landed", false))
			and craft.get_landing_contract_report().get("phase") == HeroShip.LANDING_PHASE_DOCKED,
		"touchdown holds a real berth lease on Rime's authored landing region"
	)
	var environment := game.get_viewport().world_3d.environment
	_check(
		environment != null and environment.fog_enabled
			and environment == game.rime_streaming_bootstrap.get_scene_environment(),
		"arriving hands the viewport Rime's own hazy atmosphere"
	)
	# Anchoring in the production path: nothing floats 120 km above the ice.
	var region := surface.get_node("LandingRegion") as Node3D
	var anchored := true
	for index in RimeGlacialAuthoredScene.SURVEY_ANCHOR_NAMES.size():
		var anchor := surface.find_child(RimeGlacialAuthoredScene.SURVEY_ANCHOR_NAMES[index], true, false) as Node3D
		anchored = anchored and anchor != null \
			and region.to_local(anchor.global_position).distance_to(
				RimeGlacialAuthoredScene.SURVEY_ANCHOR_POSITIONS[index]) < 0.05 \
			and anchor.global_position.distance_to(region.global_position) < 140.0
	_check(anchored and bool(surface.audit().valid),
		"after the rebased journey every landmark anchor still stands on the icefall")

	# --- disembark, walk, survey ----------------------------------------------
	await _press_interact()
	await _wait_state(owner, &"surface", 400)
	for _i in range(30):
		await physics_frame
	_check(
		owner.state == &"surface" and not game.player.is_seated()
			and game.player.is_control_enabled() and game.player.is_on_floor(),
		"disembarking puts a controllable explorer onto Rime's ice"
	)
	var survey: RefCounted = owner.get("survey")
	_check(not survey.interact() and survey.snapshot().is_empty(),
		"the pad cannot start or satisfy the ice-core survey")
	if not await _checked_walk(game, owner, [Vector3(-7, 0, -17), Vector3(-18, 0, -16), Vector3(-23, 0, -16)],
			"held walking reaches the survey beacon"):
		await _finish_bounded(game)
		return
	_check(String(survey.prompt()).contains("START"), "the beacon offers the ice-core survey")
	await _press_interact()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE,
		"E at the beacon starts the optional survey")

	# Recoverable failure: the cold runs the suit heater out.
	var lease_before: StringName = owner.get("_surface_token")
	var pose_before := game.player.global_transform
	_check(not bool(survey.get_heat_snapshot().get("warm", true)),
		"the beacon is out in the cold, away from the craft and the hut")
	survey.physics_tick(SurveyType.HEAT_CAPACITY_S + 1.0)
	var failed := survey.snapshot() as Dictionary
	_check(
		int(failed.get("state", -1)) == CheckpointRouteActivity.State.FAILED
			and StringName(failed.get("failure_reason", &"")) == SurveyType.FAILURE_HEAT_DEPLETED
			and owner.get("_surface_token") == lease_before
			and game.player.global_position.distance_to(pose_before.origin) < 0.15
			and game.player.is_control_enabled() and not survey.reward_recorded(),
		"an exhausted suit heater fails the survey without moving, hurting or stranding anyone"
	)
	_check(String(survey.objective()).contains("restart"), "the HUD objective explains how to recover")
	var press_frame := Engine.get_physics_frames()
	await _press_interact()
	# The restart refills the heater; the physics ticks the press helper then
	# spends out in the cold (more under load) are correctly drained.
	var cold_ticks := Engine.get_physics_frames() - press_frame
	var restarted_heat := survey.get_heat_snapshot() as Dictionary
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE
			and int(restarted_heat.get("failures", 0)) == 1
			and float(restarted_heat.get("heat_s", 0.0))
				>= SurveyType.HEAT_CAPACITY_S
					- float(cold_ticks) / float(Engine.physics_ticks_per_second) - 0.0001,
		"the beacon starts a fresh survey with a full heater (%s)" % restarted_heat)
	var first_save := game.save_interrupted_rime_visit() as Dictionary
	_check(bool(first_save.get("accepted", false)), "survey progress commits an interrupted-visit record")

	if not await _checked_walk(game, owner, [Vector3(-40, 0, -28), Vector3(-52, 0, -42), Vector3(-54, 0, -45.5)],
			"held walking follows the orange beacons to the drill rig"):
		await _finish_bounded(game)
		return
	_check(bool(survey.get_heat_snapshot().get("warm", false)) and String(survey.prompt()).contains("EXTRACT"),
		"the drill rig sits in the heated hut's warmth and offers the core extraction")
	await _press_interact()
	_check(int(survey.snapshot().get("next_checkpoint_index", -1)) == 1,
		"E at the drill rig records the first reading")
	await _press_interact()
	_check(int(survey.snapshot().get("next_checkpoint_index", -1)) == 1 and not survey.reward_recorded(),
		"repeating the drill rig cannot record the ridge or grant a reward")
	var latest := game._rime_expedition_persistence_binding.load_interrupted_visit() as Dictionary
	_check(int(((latest.get("visit", {}) as Dictionary).get("survey", {}) as Dictionary).get(
			"next_checkpoint_index", -1)) == 1,
		"the store returns the latest checkpoint, not the earlier start save")

	# Saving away from warmth must retain the spent heater along with readings.
	if not await _checked_walk(game, owner, [Vector3(-40, 0, -28)],
			"the explorer leaves the heated hut before interrupting the survey"):
		await _finish_bounded(game)
		return
	_check(not bool(survey.get_heat_snapshot().get("warm", true)),
		"the interrupted survey is outside both heat sources")
	survey.physics_tick(70.0)
	var saved_heat := float(survey.get_heat_snapshot().get("heat_s", 0.0))
	_check(saved_heat > 0.0 and saved_heat < SurveyType.HEAT_CAPACITY_S * 0.5,
		"the survey has a spent but live heater before saving (%s)" % saved_heat)

	# --- interrupt: whole-Main re-entry ----------------------------------------
	var saved := game.save_interrupted_rime_visit() as Dictionary
	_check(bool(saved.get("accepted", false)), "an in-progress Rime visit commits its record")
	var heat_record := game._rime_expedition_persistence_binding.load_interrupted_visit() as Dictionary
	var heat_progress := (heat_record.get("visit", {}) as Dictionary).get("survey", {}) as Dictionary
	_check(is_equal_approx(float(heat_progress.get("heat_s", -1.0)), saved_heat),
		"the atomic visit store carries the actual heater budget (%s)" % heat_progress)
	await _shut_down(game)

	var resumed_game := await _boot()
	var resumed: RefCounted = resumed_game.get("_rime_expedition")
	var restore := (resumed_game.get_rime_interrupted_visit_status() as Dictionary).get("restore", {}) as Dictionary
	_check(bool(restore.get("accepted", false)),
		"a fresh Main resumes the interrupted Rime visit (%s)" % restore.get("reason", ""))
	if not bool(restore.get("accepted", false)):
		await _finish_bounded(resumed_game)
		return
	await _wait_state(resumed, &"surface", 6000)
	_check(resumed.is_active() and resumed.state == &"surface"
			and is_instance_valid(resumed_game.rime_streaming_bootstrap.get_loaded_instance()),
		"the pilot comes back standing on the streamed Rime, not quietly at Mudds")
	var resumed_survey: RefCounted = resumed.get("survey")
	var restored_heat := float(resumed_survey.get_heat_snapshot().get("heat_s", -1.0))
	# At most a few frames of ordinary warmth can run beside the resumed craft.
	_check(absf(restored_heat - saved_heat) < 2.0,
		"whole-Main re-entry preserves spent heat instead of refilling (%s -> %s)" % [saved_heat, restored_heat])
	var resumed_craft := resumed.get("_ship") as HeroShip
	var resumed_berth := resumed.get("_berth") as ShipBerth
	_check(is_instance_valid(resumed_craft) and resumed_craft.get_home_berth_id() == home_berth_id
			and is_instance_valid(resumed_berth) and resumed_berth.get_occupant() == resumed_craft,
		"the resumed visit holds a real lease for the same craft")
	for _i in range(60):
		await physics_frame
	_check(bool((restore.get("retire", {}) as Dictionary).get("accepted", false))
			and not resumed_game.player.is_seated() and resumed_game.player.is_on_floor(),
		"the receipt is retired and the resumed explorer stands on the ice")
	_check(int(resumed_survey.snapshot().get("next_checkpoint_index", -1)) == 1
			and int(resumed_survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE,
		"whole-Main re-entry retains exactly the first reading")
	if not await _checked_walk(resumed_game, resumed, [Vector3(-7, 0, -17), Vector3(8, 0, -20), Vector3(20, 0, -40), Vector3(29, 0, -61)],
			"held walking follows the cyan path out to the ridge strain gauge"):
		await _finish_bounded(resumed_game)
		return
	_check(String(resumed_survey.prompt()).contains("STRAIN"), "the gauge offers the strain reading")
	await _press_interact()
	_check(resumed_survey.reward_recorded() and int(resumed_survey.snapshot().get("next_checkpoint_index", -1)) == 2,
		"E at the gauge completes the survey and records its reward")
	var authority: RefCounted = resumed_game.get("_game_flow_reward_authority")
	var counts := ((authority.call(&"get_snapshot") as Dictionary).get("record", {}) as Dictionary).get("reward_counts", {}) as Dictionary
	_check(int(counts.get(String(SurveyType.REWARD_ID), 0)) == 1,
		"the reward authority holds exactly one Rime ice-core record")
	var store: RefCounted = resumed_game.get("_runtime_settings_user_data_store")
	var reward_generation := int(store.call(&"get_generation"))
	await _press_interact()
	_check(int(store.call(&"get_generation")) == reward_generation,
		"repeating the completed reading cannot write or reward again")

	# --- walk back, re-board, return --------------------------------------------
	if not await _checked_walk(resumed_game, resumed, [Vector3(20, 0, -40), Vector3(8, 0, -20), Vector3(-7, 0, -17)],
			"the explorer walks the return path to the pad"):
		await _finish_bounded(resumed_game)
		return
	_check(await _walk_to_boarding_area(resumed_game, resumed_craft),
		"the explorer reaches the craft's boarding area")
	await _press_interact()
	await _wait_state(resumed, &"landed", 600)
	_check(resumed.state == &"landed" and resumed_game.player.is_seated()
			and resumed_game.active_ship == resumed_craft,
		"a real interact re-boards the same physical craft")
	if resumed.state != &"landed":
		await _finish_bounded(resumed_game)
		return
	var return_pose := resumed_craft.global_transform
	await _press_destination(resumed_game)
	for _tick in 20:
		await physics_frame
		await process_frame
	_check(resumed.state == &"return_cruise"
			and resumed_game._planetary_journey.is_return_departure_pending()
			and resumed_craft.global_transform == return_pose,
		"return queues real manual departure without moving the occupied craft")
	var queued_row := _row(resumed_game, DESTINATION_ID)
	_check(str(queued_row.get("action_text", "")) == "RETURNING TO MUDDS",
		"a seated pilot on a queued return is not told the return needs the seat (%s)"
			% queued_row.get("action_text", ""))
	# The pause menu's cruise toggle withdraws a queued return. Still sitting on
	# the leased pad, that must leave the visit landed, not end it on Rime.
	var resumed_lease: StringName = resumed.get("_surface_token")
	resumed_game.call(&"_sync_planetary_cruise_hud")
	resumed_game.hud.call(&"_request_planetary_cruise_toggle")
	for _tick in 20:
		await physics_frame
		await process_frame
	_check(resumed.state == &"landed" and resumed.get("_surface_token") == resumed_lease
			and resumed_berth.get_occupant() == resumed_craft
			and resumed_game.player.is_seated()
			and resumed_game._planetary_journey.is_aurora_visit_active()
			and not resumed_game._planetary_journey.is_return_departure_pending()
			and bool(resumed.runtime_state().get("action_enabled", false)),
		"withdrawing a queued return on the pad keeps the landed visit and its lease (%s)"
			% resumed.state)
	await _press_destination(resumed_game)
	for _tick in 20:
		await physics_frame
		await process_frame
	_check(resumed.state == &"return_cruise"
			and resumed_game._planetary_journey.is_return_departure_pending(),
		"the return can be queued again after it was withdrawn")
	resumed.cancel()
	_check(resumed.state == &"idle" and resumed_game.player.is_seated()
			and not _store_has_rime_record(resumed_game),
		"cancelling the return keeps the pilot seated and leaves no interrupted-visit record")

	# --- abandon from the surface ------------------------------------------------
	resumed_game.call(&"_sync_planetary_cruise_hud")
	await _press_destination(resumed_game)
	await _wait_state(resumed, &"landed", 6000)
	if resumed.state != &"landed":
		_check(false, "a further Rime visit can be admitted for the abandon case")
		await _finish_bounded(resumed_game)
		return
	resumed_game.call(&"_try_exit_ship")
	await _wait_state(resumed, &"surface", 600)
	resumed.cancel()
	for _i in range(40):
		await physics_frame
	for _i in range(1200):
		if resumed.state == &"idle":
			break
		await physics_frame
	for _i in range(4):
		await process_frame
	_check(resumed.state == &"idle" and not resumed_game.player.is_seated()
			and resumed_game.player.is_control_enabled()
			and resumed_game.player.global_position.distance_to(
				resumed_game.world.get_player_spawn().origin) < 400.0,
		"abandoning returns a controllable explorer to the yard")
	_check(_rime_node_count(resumed_game) == 0
			and not resumed_game._planetary_journey.is_aurora_visit_active(),
		"abandoning unloads Rime and frees the shared surface-visit lane")
	await _finish_bounded(resumed_game)


# --- harness (the Aurora visit loop's, pointed at Rime) --------------------------


func _boot() -> GameFlow:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.01
	game.start_shift()
	await process_frame
	await physics_frame
	return game


func _shut_down(game: GameFlow) -> void:
	game.queue_free()
	for _i in range(6):
		await process_frame
		await physics_frame


func _board_halyard(game: GameFlow) -> HeroShip:
	var craft := game.get_node_or_null("HalyardCrewTransport") as HeroShip
	if craft == null:
		_check(false, "the production Main composes the Halyard crew transport")
		return null
	game.player.teleport_to(Transform3D(craft.global_basis,
		craft.get_boarding_position() + craft.global_basis.y * 0.01))
	for _i in range(6):
		await physics_frame
		await process_frame
	await _press_interact()
	for _i in range(300):
		await physics_frame
		if game._piloting:
			break
	_check(game._piloting and game.player.is_seated() and game.active_ship == craft,
		"an ordinary boarding takes the Halyard's pilot seat")
	return craft if game._piloting else null


func _row(game: GameFlow, destination_id: StringName) -> Dictionary:
	var snapshot := game.get_planetary_destination_catalog_snapshot() as Dictionary
	for row: Dictionary in snapshot.get("destinations", []):
		if row.get("destination_id") == destination_id:
			return row
	return {}


## Explicit bounded-test setup, as in the Aurora loop: real boarding and a held
## departure precede one distance placement 70 km short of Rime's navigation
## anchor; the expedition itself then makes zero placements.
func _prepare_bounded_outbound(game: GameFlow) -> void:
	var owner: RefCounted = game.get("_rime_expedition")
	if owner.is_active() or _outbound_fixture_ready:
		return
	var craft := game.active_ship as HeroShip
	if bool(craft.get_telemetry().get("landed", true)):
		_check(not bool(owner.runtime_state().get("action_enabled", true)),
			"parked Rime action asks the pilot to physically depart first")
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		for _i in 180:
			await physics_frame
		Input.action_release(&"hover")
		Input.action_release(&"move_forward")
		for _i in 4:
			await physics_frame
			await process_frame
	var activity := game.cinder_race_session.get_presentation_snapshot()
	if bool(activity.get("running", false)):
		game.cinder_race_session.fail(&"arrival_fixture_activity_ended",
			game.cinder_race_session.get_session_generation())
	var bootstrap := game.rime_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(
		bootstrap.get_navigation_destination().get("body_local_position_meters"), frame.get_generation())
	var anchor := frame.orbital_to_world_streaming_position(
		encoded.get("coordinate"), frame.get_generation()).get("position", Vector3.INF) as Vector3
	craft.global_transform = Transform3D(Basis.IDENTITY, anchor + Vector3.BACK * 70_000.0)
	craft.velocity = Vector3.ZERO
	craft.reset_physics_interpolation()
	for _i in 2:
		await physics_frame
		await process_frame
	_outbound_fixture_ready = true


func _press_destination(game: GameFlow) -> void:
	await _prepare_bounded_outbound(game)
	game.call(&"_sync_planetary_cruise_hud")
	game.hud.open_planetary_destination_board()
	var button := game.hud.find_child("PlanetaryDestinationAction_%s" % DESTINATION_ID, true, false) as Button
	_check(button != null and not button.disabled, "Rime's board action is visible and enabled")
	if button != null and not button.disabled:
		button.pressed.emit()
	_outbound_fixture_ready = false


func _rime_node_count(game: GameFlow) -> int:
	var count := 0
	for candidate in game.find_children("*", "Node3D", true, false):
		if candidate is RimeGlacialAuthoredScene:
			count += 1
	return count


func _store_has_rime_record(game: GameFlow) -> bool:
	var store: Object = game.get("_runtime_settings_user_data_store")
	if store == null:
		return false
	var loaded := store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return false
	return (loaded.get("payload", {}) as Dictionary).has(String(GameFlow.RIME_EXPEDITION_PERSISTENCE_SLOT))


func _wait_state(owner: RefCounted, target: StringName, frames: int) -> void:
	for _i in frames:
		await physics_frame
		if owner.state == target:
			break
	if owner.state != target:
		print("WAIT ENDED: ", owner.state, " wanted ", target, " snapshot=", owner.get_visit_snapshot())


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


func _look_toward(player: PlayerController, target: Vector3) -> void:
	var direction := player.global_basis.inverse() * (target - player.global_position)
	(player.get_node("CameraRig/CameraYaw") as Node3D).rotation.y = atan2(-direction.x, -direction.z)


func _walk_to_boarding_area(game: GameFlow, craft: HeroShip) -> bool:
	var area := craft.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	if area == null:
		return false
	var target := craft.get_boarding_position()
	for _i in range(720):
		if area in game.player.get_nearby_interactables():
			break
		_look_toward(game.player, target)
		Input.action_press(&"move_forward")
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _i in range(8):
		await physics_frame
		await process_frame
	return area in game.player.get_nearby_interactables()


func _checked_walk(game: GameFlow, owner: RefCounted, points: Array, label: String) -> bool:
	var reached := await _walk_route(game, owner, points)
	_check(reached, label)
	return reached


## Region-local targets resolved afresh every tick so a common origin shift
## cannot leave them behind. Only held input moves the explorer.
func _walk_route(game: GameFlow, owner: RefCounted, points: Array) -> bool:
	var region := (owner.get("_surface") as Node3D).get_node("LandingRegion") as Node3D
	for point: Vector3 in points:
		var arrived := false
		for _tick in 1400:
			var target := region.to_global(point)
			var delta := target - game.player.global_position
			delta.y = 0
			if delta.length() < 0.7:
				arrived = true
				break
			_look_toward(game.player, target)
			Input.action_press(&"move_forward")
			await physics_frame
			await process_frame
		Input.action_release(&"move_forward")
		for _tick in 8:
			await physics_frame
			await process_frame
		if not arrived:
			print("RIME_WALK_BLOCKED player=", region.to_local(game.player.global_position),
				" target=", point, " floor=", game.player.is_on_floor())
			return false
	return game.player.is_on_floor()


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)


func _finish_bounded(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions])
	quit(0 if _failures.is_empty() else 1)
