extends SceneTree

## A repeat Ember visit lands.
##
## One retained production `Main` admits two expeditions in a row, the Arrow and
## then the Torrent — the rotation `ember_loop_soak_evidence.gd` runs — and each
## flies its caldera descent through the descent's own committed common-world
## rebase to a completed landing, a held caldera lease and the on-foot phase.
##
## The second visit used to abort `berth_changed` from inside that rebase: the
## live berth re-derives its dock transform through its parent chain, and at the
## 10 km magnitudes the caldera drop handles float32 rounds that chain 0.391 mm
## away from the Torrent's translated dock snapshot, past the 0.1 mm exact
## guard (the Arrow's rounds 0.078 mm, inside it). The Host then observed the
## released lease as `berth_lease_lost` and the coordinator turned it into the
## safe abandon, so every even soak cycle ended without a landing.
##
## Staging is exactly the soak's: production has no owner that flies the craft
## the 8,000 km from the yard or the last 10 km into the corridor, so the craft
## is held at the navigation anchor until the real cruise binding activates its
## final approach, then placed once at the authored corridor entry. Every metre
## of the descent, the landing, the disembark and the abandon is production.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-repeat-visit-landing.json"

const CRAFT_ROTATION: Array[StringName] = [&"arrow_provisional", &"torrent_provisional"]
## What "on the caldera floor" means for every authored cue the Ember surface
## composition owns. See `ember_landing_region_test.gd` for the full reasoning;
## the short version is that each cue is placed from a body-local or
## region-local reading under a composition that is a plain `Node`, so a
## reading used straight as a node position stands in neither frame. This is
## the Main-composed measurement of the same family, taken after the descent's
## own committed common-world rebase.
const SURFACE_CUE_MAX_HEIGHT_M := 64.0
const SURFACE_CUE_MAX_RANGE_M := 1500.0
## The orbital approach datum is authored 140 km from the moon's centre --
## 20 km above the caldera -- and genuinely belongs in the body frame.
const ORBITAL_DATUM_NODE: StringName = &"OwnedOrbitalApproachRing"
const ORBITAL_DATUM_ALTITUDE_M := 20_000.0
const FRAME_BUDGET_GRACE := 30
const ORBIT_STANDOFF_M := 500.0
const ORBIT_HOLD_SPEED_MPS := 8.0
const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 240
const ORBIT_STAGE_TICK_BUDGET := 420
const HANDOFF_TICK_BUDGET := 600
const LANDING_TICK_BUDGET := 1500
const DISEMBARK_TICK_BUDGET := 600
const REBOARD_TICK_BUDGET := 600
const ABANDON_TICK_BUDGET := 2400
const FLIGHT_CONTROL_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist",
]
const ON_FOOT_ACTIONS: Array[StringName] = [
	&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint_boost", &"jump",
]

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
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

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


var _failures: Array[String] = []
var _assertions := 0
var _reward_receipts := 0
var _baseline_streamed_nodes := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null:
		_finish()
		return
	var isolated_store := Store.new(ISOLATED_STORE_PATH, MemoryFilesystem.new())
	_check(
		game.configure_runtime_settings_persistence(
			isolated_store, "memory://ember-repeat-visit-landing-legacy.cfg"
		),
		"an isolated settings store is injected before startup"
	)
	root.add_child(game)
	for _boot_frame in 240:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	_check(bool(game.get("_initialized")), "production Main reaches its initialized state")
	game.set("_initialized", true)
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06

	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	var owner := game.common_world_origin_rebase_owner as CommonWorldOriginRebaseOwner
	_check(
		player != null and host != null and berth != null and cruise != null and owner != null,
		"production Main composes the Ember host, berth, cruise binding and origin owner"
	)
	if player == null or host == null or berth == null or cruise == null or owner == null:
		await _tear_down(game)
		_finish()
		return
	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 9, 4.0)
	var rotation: Array[HeroShip] = []
	for ship_id in CRAFT_ROTATION:
		for craft: HeroShip in game.get_flyable_ships():
			if craft.get_ship_id() == ship_id:
				rotation.append(craft)
	_check(
		rotation.size() == CRAFT_ROTATION.size(),
		"the yard offers the Arrow and the Torrent for the Ember trip (%d)" % rotation.size()
	)
	if rotation.size() != CRAFT_ROTATION.size():
		await _tear_down(game)
		_finish()
		return

	game.start_shift()
	await process_frame
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE

	var host_id := host.get_instance_id()
	for visit in rotation.size():
		var landed := await _visit(game, player, host, berth, cruise, owner, rotation[visit], visit)
		if not landed:
			break
	_check(
		is_instance_valid(host) and host.get_instance_id() == host_id
			and game.ember_surface_loop_host == host,
		"both expeditions ran on the same retained Host"
	)
	_check(_reward_receipts == 0, "no reward was granted by either abandoned visit")

	await _tear_down(game)
	_finish()


## One expedition: board, launch, admit, stage the approach, hand off, descend
## through the committed rebase, land, disembark, then leave through the
## production abandon so the retained `Main` admits the next one.
func _visit(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		berth: EmberSurfaceBerth,
		cruise: PlanetaryCruiseProductionBinding,
		owner: CommonWorldOriginRebaseOwner,
		craft: HeroShip,
		visit: int,
	) -> bool:
	var label := "visit %d (%s)" % [visit + 1, craft.get_ship_id()]
	await _await_free_on_foot(game, player)
	if _baseline_streamed_nodes == 0:
		_baseline_streamed_nodes = _streamed_node_count(game)
	var boarded := await _walk_and_board(game, player, craft)
	_check(boarded, "%s boards at the yard with real locomotion and one interact press" % label)
	if not boarded:
		await _recover(game, player)
		return false
	var launched := await _launch(game)
	_check(launched, "%s launches off its yard pad into free flight" % label)
	game.set("_active_activity_id", &"")
	var aurora: Object = game.get("_aurora_expedition")
	if aurora != null and bool(aurora.call(&"is_active")):
		aurora.call(&"cancel")
	var begun := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_on_reward"), visit + 1
	)
	_check(
		bool(begun.get("accepted", false)),
		"%s is admitted by the retained coordinator (%s)" % [label, begun.get("reason", &"?")]
	)
	if not bool(begun.get("accepted", false)):
		await _recover(game, player)
		return false

	var activated := await _stage_orbital_approach(game, craft, cruise)
	_check(
		activated,
		"%s streams Ember, commits the arrival rebase and activates the real final approach" % label
	)
	if not activated:
		await _abort_journey(game, player)
		return false
	var handed_off := await _stage_corridor_entry(game, craft, host)
	_check(handed_off, "%s hands the completed final approach off to the surface Host" % label)
	if not handed_off:
		await _abort_journey(game, player)
		return false

	var transactions_before := int(owner.get_snapshot().get("transaction_count", 0))
	var landed := await _advance_to_phase(host, EmberSurfaceLoopHost.Phase.LANDED, LANDING_TICK_BUDGET)
	var transactions_after := int(owner.get_snapshot().get("transaction_count", 0))
	var abort_reason := StringName(craft.get_telemetry().get("landing_abort_reason", &"?"))
	var host_result := StringName(
		(host.get_snapshot().get("last_result", {}) as Dictionary).get("reason", &"?")
	)
	_check(
		landed,
		"%s lands on the caldera pad through its own descent (phase %d, abort %s, host %s)"
			% [label, host.get_phase(), abort_reason, host_result]
	)
	if not landed:
		await _abort_journey(game, player)
		return false
	_check(
		transactions_after == transactions_before + 1,
		"%s committed exactly one common-world rebase during its descent (%d -> %d)"
			% [label, transactions_before, transactions_after]
	)
	var contract := craft.get_landing_contract_report()
	var acceptance := contract.get("acceptance", {}) as Dictionary
	var dock_snapshot := acceptance.get("dock_transform_snapshot", Transform3D.IDENTITY) as Transform3D
	_check(
		abort_reason.is_empty()
			and host_result != &"berth_lease_lost"
			and bool(craft.get_telemetry().get("landed", false))
			and bool(contract.get("strict_dock_acceptance", false))
			and berth.get_occupant() == craft
			and not berth.get_reservation_token(craft).is_empty()
			and dock_snapshot.origin.distance_to(berth.get_dock_transform().origin)
				<= HeroShip.LANDING_TRANSFORM_EPSILON,
		"%s holds its caldera lease with strict dock acceptance and a dock snapshot exact on the live berth after the rebase"
			% label
	)

	var on_foot := await _advance_to_phase(
		host, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, DISEMBARK_TICK_BUDGET
	)
	_check(
		on_foot
			and not player.is_seated()
			and player.is_control_enabled()
			and not berth.get_reservation_token(craft).is_empty()
			and bool(game.get("_ember_surface_journey_active")),
		"%s disembarks onto the Ember surface with the craft still leased on the pad (phase %d)"
			% [label, host.get_phase()]
	)
	_check_authored_interaction_points_are_reachable(game, host, player, label)

	# Leave through the production exit: the abandon lifts the survey gate, the
	# pilot re-boards with a real interact press, the Host's own takeoff carries
	# the abandon until it commits off the pad.
	var abandoned := game.abandon_ember_surface_journey(&"repeat_visit_landing_test")
	_check(
		bool(abandoned.get("accepted", false)),
		"%s abandon is admitted from the surface (%s)" % [label, abandoned.get("reason", &"?")]
	)
	for _settle in 12:
		await physics_frame
		await process_frame
	var boarded_home := await _reboard_after_abandon(player, host, craft)
	_check(boarded_home, "%s re-boards at the caldera through the lifted gate" % label)
	var released := await _advance_until_abandon_commits(game, host)
	_check(
		released
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and bool(host.get_snapshot().get("attached", false))
			and StringName(host.get_snapshot().get("terminal_reason", &"?")).is_empty(),
		"%s abandon commits off the pad and leaves the retained Host idle and attached" % label
	)
	await _reset_for_next_visit(game, player, host, craft)
	return landed and on_foot


## The Main-composed reach check. Both authored interaction points are placed
## by the live composition under this retained `Main`, so this measures where
## they actually stand relative to the streamed caldera the pilot walked out
## onto -- the reading that has to survive the descent's own committed
## common-world rebase, and the one nothing used to take.
func _check_authored_interaction_points_are_reachable(
		game: GameFlow, host: EmberSurfaceLoopHost, player: PlayerController,
		label: String
	) -> void:
	var composition := game.get_node_or_null(
		^"EmberPlanetarySurfaceProductionBinding"
	) as Node
	var scene := instance_from_id(host.get_loaded_scene_instance_id()) as Node
	var region: Node3D = null
	if scene != null:
		region = scene.get_node_or_null(^"LandingRegion") as Node3D
	if composition == null or region == null:
		_check(false, "%s composes its authored interaction points under Main" % label)
		return
	for probe: Dictionary in [
		{
			"node": "OwnedSampleRackInteraction", "name": "sample rack",
			"authored": Vector3(28.0, 0.0, -4.8),
		},
		{
			"node": "OwnedSurveyBunkerInteraction", "name": "survey bunker",
			"authored": Vector3(-17.5, 0.0, -17.5),
		},
	]:
		var point := composition.get_node_or_null(
			NodePath(str(probe.node))
		) as Area3D
		if point == null:
			_check(false, "%s composes the %s interaction point" % [label, probe.name])
			continue
		var placed := region.to_local(point.global_position)
		var authored := probe.authored as Vector3
		var walk := player.global_position.distance_to(point.global_position)
		_check(
			placed.distance_to(authored) <= 1.0
				and walk <= EmberMoonAuthoredScene.CALDERA_FLOOR_RADIUS_M,
			"%s keeps the %s point on the caldera floor, %.1f m from the disembarked pilot: region-local %s, authored %s"
				% [label, probe.name, walk, placed, authored]
		)
	_check_surface_cues_stand_on_the_caldera_floor(composition, region, label)


## The Main-composed whole-family measurement: everything this composition puts
## in the world that the pilot can see or touch stands on the caldera floor
## they walked out onto. The two presses above have a reachability contract;
## the route cues, practicals, beacons, hazard perimeter and water surface have
## none, which is why all of them were 120 km up and nothing said so.
func _check_surface_cues_stand_on_the_caldera_floor(
		composition: Node, region: Node3D, label: String
	) -> void:
	var offenders := PackedStringArray()
	var measured := 0
	var orbital_datum_local := Vector3.INF
	var stack: Array[Node] = [composition]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var spatial := node as Node3D
		# Anything the composition places itself has to stand in an authored
		# frame of its own rather than inherit the composition's, which is a
		# plain `Node` and therefore whatever frame it happens to hang under.
		# This catches the same defect at any magnitude, including the small
		# offsets a bounded distance cannot separate from an authored height.
		if spatial != null and node.get_parent() == composition \
				and not spatial.top_level:
			offenders.append("%s is not anchored to an authored frame" % [node.name])
		if node.name == ORBITAL_DATUM_NODE and node.get_parent() == composition:
			orbital_datum_local = region.to_local(spatial.global_position)
			continue
		for child in node.get_children():
			stack.append(child)
		if spatial == null or not (
			spatial is VisualInstance3D or spatial is CollisionShape3D
				or spatial is CollisionObject3D
		):
			continue
		measured += 1
		var placed := region.to_local(spatial.global_position)
		if absf(placed.y) > SURFACE_CUE_MAX_HEIGHT_M \
				or Vector2(placed.x, placed.z).length() > SURFACE_CUE_MAX_RANGE_M:
			offenders.append("%s at region-local %s" % [
				composition.get_path_to(spatial), placed,
			])
	_check(
		measured >= 20 and offenders.is_empty(),
		"%s stands every authored surface cue on the caldera floor (%d measured): %s"
			% [label, measured, offenders]
	)
	_check(
		absf(orbital_datum_local.y - ORBITAL_DATUM_ALTITUDE_M) <= 1.0
			and Vector2(orbital_datum_local.x, orbital_datum_local.z).length() <= 1.0,
		"%s keeps the orbital approach datum on its body-frame anchor 20 km over the caldera: region-local %s"
			% [label, orbital_datum_local]
	)


# ------------------------------------------------------------- staging ----


func _walk_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(-approach, Vector3.UP),
		boarding + up * 0.05 + approach * 6.0
	))
	player.set_control_enabled(true)
	for _stage_tick in 4:
		await physics_frame
		await process_frame
	var arrived := await _walk_until(
		&"move_forward",
		func() -> bool: return game.boarding_candidate == craft,
		LOCOMOTION_TICK_BUDGET
	)
	if not arrived:
		player.teleport_to(Transform3D(player.global_basis, boarding + up * 0.05))
		arrived = await _wait_until(
			func() -> bool: return game.boarding_candidate == craft, 2.0
		)
	if not arrived:
		return false
	for _attempt in 3:
		await _press_live_action(&"interact", 1)
		if await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 2.0
		):
			break
	return game.phase == GameFlow.Phase.START_ENGINES


func _launch(game: GameFlow) -> bool:
	_release_all_actions()
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	var ticks := 0
	while game.phase != GameFlow.Phase.FREE_FLIGHT and ticks < DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	var airborne := game.phase == GameFlow.Phase.FREE_FLIGHT
	for _leg_tick in 24:
		await physics_frame
		await process_frame
	Input.action_release(&"hover")
	Input.action_release(&"move_forward")
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return airborne


func _stage_orbital_approach(
		game: GameFlow,
		craft: HeroShip,
		cruise: PlanetaryCruiseProductionBinding,
	) -> bool:
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get(
		"canonical_destination_orbital", {}
	) as Dictionary
	for _index in ORBIT_STAGE_TICK_BUDGET:
		var decoded := frame.orbital_to_world_streaming_position(
			canonical, frame.get_generation()
		)
		var navigation := decoded.get("position", Vector3.INF) as Vector3
		if navigation.is_finite():
			craft.global_position = navigation + Vector3.BACK * ORBIT_STANDOFF_M
			craft.global_basis = Basis.IDENTITY
			craft.velocity = (
				navigation - craft.global_position
			).normalized() * ORBIT_HOLD_SPEED_MPS
		await physics_frame
		var controller := (cruise.get_snapshot().get("controller", {}) as Dictionary)
		var approach := controller.get("final_approach", {}) as Dictionary
		if StringName(approach.get("state_id", &"")) == &"final_approach":
			return true
	return false


func _stage_corridor_entry(
		game: GameFlow,
		craft: HeroShip,
		host: EmberSurfaceLoopHost,
	) -> bool:
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return false
	var region := loaded.get_node_or_null(^"LandingRegion") as Node3D
	if not is_instance_valid(region):
		return false
	var corridor := (
		(host.get_snapshot().get("approach_entry", {}) as Dictionary)
			.get("envelope", {}) as Dictionary
	).get("corridor_transform_region_local_m", Transform3D.IDENTITY) as Transform3D
	craft.global_transform = region.global_transform * corridor
	craft.velocity = Vector3.ZERO
	for _index in HANDOFF_TICK_BUDGET:
		await physics_frame
		await process_frame
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		if host.get_phase() > EmberSurfaceLoopHost.Phase.IDLE:
			return true
	return false


func _advance_to_phase(host: EmberSurfaceLoopHost, phase: int, tick_budget: int) -> bool:
	for _index in tick_budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await physics_frame
		await process_frame
	return host.get_phase() == phase


func _reboard_after_abandon(
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
	) -> bool:
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not is_instance_valid(area):
		return false
	if not (area in player.get_nearby_interactables()):
		if not await _walk_until(
			&"move_forward",
			func() -> bool: return area in player.get_nearby_interactables(),
			120
		):
			return false
	for _press in 12:
		await _press_live_action(&"interact", 1)
		for _settle in 6:
			await physics_frame
			await process_frame
		if host.get_phase() >= EmberSurfaceLoopHost.Phase.BOARDING \
				and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED:
			break
	return await _wait_for(
		func() -> bool: return player.is_seated() and host.get_phase() in [
			EmberSurfaceLoopHost.Phase.REBOARDED,
			EmberSurfaceLoopHost.Phase.TAKEOFF,
			EmberSurfaceLoopHost.Phase.ASCENT,
			EmberSurfaceLoopHost.Phase.ORBIT_RETURN,
			EmberSurfaceLoopHost.Phase.IDLE,
		],
		REBOARD_TICK_BUDGET
	)


func _advance_until_abandon_commits(game: GameFlow, host: EmberSurfaceLoopHost) -> bool:
	for _index in ABANDON_TICK_BUDGET:
		if host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
				and not bool(game.get("_ember_surface_journey_active")):
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await physics_frame
		await process_frame
	return host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
		and not bool(game.get("_ember_surface_journey_active"))


# ---------------------------------------------------------------- reset ----


func _abort_journey(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	game.abandon_ember_surface_journey(&"repeat_visit_landing_test_aborted")
	for _settle in 8:
		await physics_frame
		await process_frame
	await _reset_for_next_visit(
		game, player, game.ember_surface_loop_host as EmberSurfaceLoopHost,
		game.get_active_ship()
	)


## The staged 8,000 km flight home, as in the soak: the expedition itself was
## ended by the production abandon; only the craft and pilot are placed back.
func _reset_for_next_visit(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
	) -> void:
	_release_all_actions()
	if is_instance_valid(host) and host.is_attached() \
			and host.get_phase() != EmberSurfaceLoopHost.Phase.IDLE:
		game.abandon_ember_surface_journey(&"repeat_visit_landing_test_reset")
		for _abandon_tick in 12:
			await physics_frame
			await process_frame
			if host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE:
				break
	game.disengage_planetary_cruise(false)
	for _settle in 6:
		await physics_frame
		await process_frame
	if is_instance_valid(craft):
		var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
		if is_instance_valid(area) and area.get_reservation_token() != null:
			area.release_reservation(area.get_reservation_token())
	await _recover(game, player)
	var surface_berth := game.ember_surface_berth as EmberSurfaceBerth
	if is_instance_valid(surface_berth) and is_instance_valid(craft):
		var token := surface_berth.get_reservation_token(craft)
		if not token.is_empty():
			surface_berth.release(craft, token)
		for _release_tick in 6:
			await physics_frame
			await process_frame
	for _rebind_tick in 240:
		await physics_frame
		await process_frame
		if _streamed_node_count(game) <= _baseline_streamed_nodes:
			break
	for _settle_tick in 24:
		await physics_frame
		await process_frame


func _recover(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var craft := game.get_active_ship()
	for fleet_craft in game.get_flyable_ships():
		if is_instance_valid(fleet_craft) and not fleet_craft.is_piloted():
			fleet_craft.request_engine_stop(false)
	if is_instance_valid(craft):
		craft.set_piloted(false)
		craft.request_engine_stop(false)
		craft.velocity = Vector3.ZERO
		if is_instance_valid(world):
			var berth := world.get_berth_node(craft.get_home_berth_id())
			if is_instance_valid(berth):
				craft.global_transform = berth.get_dock_transform()
	game.set("_piloting", false)
	game.set("_transition_busy", false)
	game.set("_sortie_departed_berth", false)
	if is_instance_valid(world):
		player.force_recovery_to_on_foot(world.get_player_spawn())
	player.set_control_enabled(true)
	game.phase = GameFlow.Phase.COMPLETE
	await _await_free_on_foot(game, player)


func _await_free_on_foot(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	await _wait_until(
		func() -> bool: return (
			not bool(game.get("_transition_busy"))
			and not player.is_seated()
			and player.is_control_enabled()
		),
		4.0
	)


func _streamed_node_count(game: GameFlow) -> int:
	if not is_instance_valid(game.ember_streaming_bootstrap):
		return 0
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return 0
	var count := 0
	var pending: Array[Node] = [loaded]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		count += 1
		for child in node.get_children():
			pending.append(child)
	return count


# ---------------------------------------------------------------- input ----


func _walk_until(action: StringName, predicate: Callable, tick_budget: int) -> bool:
	Input.action_press(action)
	var ticks := 0
	while not bool(predicate.call()) and ticks < tick_budget:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _wait_for(predicate: Callable, tick_budget: int) -> bool:
	for _index in tick_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


func _release_all_actions() -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	for action: StringName in ON_FOOT_ACTIONS:
		Input.action_release(action)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _tear_down(game: Node) -> void:
	_release_all_actions()
	game.queue_free()
	for _teardown_frame in 12:
		await process_frame
		await physics_frame


func _on_reward(_receipt: Dictionary) -> Dictionary:
	_reward_receipts += 1
	return {"accepted": true, "reason": &"ember_repeat_visit_landing_reward"}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(description)
	push_error("EMBER_REPEAT_VISIT_LANDING_TEST: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_REPEAT_VISIT_LANDING_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("EMBER_REPEAT_VISIT_LANDING_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
