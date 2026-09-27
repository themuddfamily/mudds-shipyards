extends SceneTree
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

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "RIME_VISIT_LOOP_TEST_OK"
const FAILURE_MARKER := "RIME_VISIT_LOOP_TEST_FAILED"
const DESTINATION_ID: StringName = &"rime_glacial_world"
const AURORA_DESTINATION_ID: StringName = &"aurora_temperate_world"
const SurveyType := preload("res://scripts/activities/rime_ice_core_survey.gd")

var _failures: Array[String] = []
var _assertions := 0
var _outbound_fixture_ready := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := await _boot()
	var craft := await _board_halyard(game)
	if craft == null:
		await _finish(game)
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
		await _finish(game)
		return
	await _press_destination(game)
	var aurora_row := _row(game, AURORA_DESTINATION_ID)
	_check(
		owner.is_active() and not bool(aurora_row.get("action_enabled", true)),
		"while Rime's visit holds the shared surface-visit lane, Aurora's row is refused"
	)
	await _wait_state(owner, &"landed", 6000)
	if owner.state != &"landed":
		print("RIME VISIT DIAG: ", owner.get_visit_snapshot())
	_check(owner.state == &"landed", "the visit reaches a landed craft at Rime")
	if owner.state != &"landed":
		await _finish(game)
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
		await _finish(game)
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
	await _press_interact()
	_check(int(survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE
			and is_equal_approx(float(survey.heat_fraction()), 1.0),
		"the beacon starts a fresh survey with a full heater")
	var first_save := game.save_interrupted_rime_visit() as Dictionary
	_check(bool(first_save.get("accepted", false)), "survey progress commits an interrupted-visit record")

	if not await _checked_walk(game, owner, [Vector3(-40, 0, -28), Vector3(-52, 0, -42), Vector3(-54, 0, -45.5)],
			"held walking follows the orange beacons to the drill rig"):
		await _finish(game)
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

	# --- interrupt: whole-Main re-entry ----------------------------------------
	var saved := game.save_interrupted_rime_visit() as Dictionary
	_check(bool(saved.get("accepted", false)), "an in-progress Rime visit commits its record")
	await _shut_down(game)

	var resumed_game := await _boot()
	var resumed: RefCounted = resumed_game.get("_rime_expedition")
	var restore := (resumed_game.get_rime_interrupted_visit_status() as Dictionary).get("restore", {}) as Dictionary
	_check(bool(restore.get("accepted", false)),
		"a fresh Main resumes the interrupted Rime visit (%s)" % restore.get("reason", ""))
	if not bool(restore.get("accepted", false)):
		await _finish(resumed_game)
		return
	await _wait_state(resumed, &"surface", 6000)
	_check(resumed.is_active() and resumed.state == &"surface"
			and is_instance_valid(resumed_game.rime_streaming_bootstrap.get_loaded_instance()),
		"the pilot comes back standing on the streamed Rime, not quietly at Mudds")
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
	var resumed_survey: RefCounted = resumed.get("survey")
	_check(int(resumed_survey.snapshot().get("next_checkpoint_index", -1)) == 1
			and int(resumed_survey.snapshot().get("state", -1)) == CheckpointRouteActivity.State.ACTIVE,
		"whole-Main re-entry retains exactly the first reading")
	if not await _checked_walk(resumed_game, resumed, [Vector3(-7, 0, -17), Vector3(8, 0, -20), Vector3(20, 0, -40), Vector3(29, 0, -61)],
			"held walking follows the cyan path out to the ridge strain gauge"):
		await _finish(resumed_game)
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
		await _finish(resumed_game)
		return
	_check(await _walk_to_boarding_area(resumed_game, resumed_craft),
		"the explorer reaches the craft's boarding area")
	await _press_interact()
	await _wait_state(resumed, &"landed", 600)
	_check(resumed.state == &"landed" and resumed_game.player.is_seated()
			and resumed_game.active_ship == resumed_craft,
		"a real interact re-boards the same physical craft")
	if resumed.state != &"landed":
		await _finish(resumed_game)
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
		await _finish(resumed_game)
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
	await _finish(resumed_game)


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


func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions])
	quit(0 if _failures.is_empty() else 1)
