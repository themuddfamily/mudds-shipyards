extends SceneTree
## Drives one complete Aurora visit through a real composed `Main`, and then
## does to it the three things that break a world which is only half-wired: it
## interrupts the visit with a whole-`Main` re-entry, it departs and checks that
## nothing of Aurora is left behind, and it abandons a visit from the surface
## and checks that neither the pilot nor the craft is stranded.
##
## Everything here is the production path. The destination is chosen from the
## real Destination Board, the craft is boarded and re-boarded with a real
## `interact` at a real `ShipBoardingArea`, the touchdown goes through a real
## `ShipBerth` lease and `HeroShip.request_berth_landing()`, the walking is
## real movement on the authored world's own collision, and the interrupted
## visit is carried across the two `Main`s by the same `UserDataStore` the game
## ships with.

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "AURORA_VISIT_LOOP_TEST_OK"
const FAILURE_MARKER := "AURORA_VISIT_LOOP_TEST_FAILED"
const DESTINATION_ID: StringName = &"aurora_temperate_world"

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := await _boot()
	var craft := await _board_halyard(game)
	if craft == null:
		await _finish(game)
		return
	var owner: RefCounted = game.get("_aurora_expedition")
	var home_position := craft.global_position
	var home_berth_id := craft.get_home_berth_id()

	# --- admit, arrive, land -------------------------------------------------
	var row := _row(game)
	_check(
		bool(row.get("route_available", false))
			and bool(row.get("action_enabled", false)),
		"Aurora is listed and selectable on the Destination Board (%s)"
			% row.get("status_text", "")
	)
	_check(
		float(row.get("orbital_distance_meters", 0.0)) == 12_000_000.0,
		"the board reads Aurora's distance from its own absolute orbital datum"
	)
	if not bool(row.get("action_enabled", false)):
		await _finish(game)
		return
	_press_destination(game)
	await _wait_state(owner, &"landed", 4000)
	_check(owner.state == &"landed", "the visit reaches a landed craft at Aurora")
	if owner.state != &"landed":
		await _finish(game)
		return

	var surface := owner.get("_surface") as Node3D
	var berth := owner.get("_berth") as ShipBerth
	_check(
		is_instance_valid(surface) and surface is AuroraTemperateAuthoredScene
			and craft.global_position.distance_to(home_position) > 10_000.0,
		"the authored Aurora world is standing and the craft is really there"
	)
	_check(
		is_instance_valid(berth) and berth.get_occupant() == craft
			and not String(owner.get("_surface_token")).is_empty()
			and bool(craft.get_telemetry().get("landed", false))
			and craft.get_landing_contract_report().get("phase")
				== HeroShip.LANDING_PHASE_DOCKED,
		"touchdown holds a real berth lease and a real docked landing contract"
	)
	_check(
		is_instance_valid(surface)
			and berth.get_parent() == surface.get_node_or_null(^"LandingRegion"),
		"the landing berth stands on the authored landing region, not on Main"
	)

	# Aurora is not a reskin of Ember: it has weather in front of the camera and
	# a bounded terrain generator under the pilot's feet, and neither exists on
	# an airless body.
	var environment := game.get_viewport().world_3d.environment
	_check(
		environment != null and environment.fog_enabled,
		"arriving hands the viewport Aurora's own atmospheric environment"
	)
	var clipmap := (surface.get_terrain_clipmap_snapshot()
		if is_instance_valid(surface) else {}) as Dictionary
	_check(
		int(clipmap.get("ring_count", 0)) == 5
			and int(clipmap.get("collision_ring_count", 0)) == 1,
		"the visited world brought its five committed terrain rings with it"
	)
	_check(
		is_instance_valid(surface) and surface.get_node_or_null(
			^"LandingRegion/CoastalExploration/CoastalLookoutSign"
		) != null,
		"the surface reads as a coast, not a caldera"
	)

	# --- disembark and walk the patch ---------------------------------------
	await _press_interact()
	await _wait_state(owner, &"surface", 400)
	for _i in range(30):
		await physics_frame
	_check(
		owner.state == &"surface" and not game.player.is_seated()
			and game.player.is_control_enabled() and game.player.is_on_floor(),
		"disembarking puts a controllable explorer onto Aurora's ground"
	)
	var disembark_position := game.player.global_position
	_check(
		await _walk_away(game.player, craft, 2.5),
		"the explorer walks the authored patch on real terrain collision"
	)
	_check(
		game.player.global_position.distance_to(disembark_position) > 1.0
			and game.player.is_on_floor(),
		"the walk is physical ground movement, not a teleport"
	)

	# --- interrupt: save and whole-Main re-entry -----------------------------
	var saved := game.save_interrupted_aurora_visit() as Dictionary
	_check(
		bool(saved.get("accepted", false)),
		"an in-progress visit commits an interrupted-visit record (%s)"
			% saved.get("reason", "")
	)
	await _shut_down(game)

	var resumed_game := await _boot()
	var resumed: RefCounted = resumed_game.get("_aurora_expedition")
	var status := resumed_game.get_aurora_interrupted_visit_status() as Dictionary
	var restore := status.get("restore", {}) as Dictionary
	_check(
		bool(restore.get("accepted", false)),
		"a fresh Main resumes the interrupted visit (%s)"
			% restore.get("reason", "")
	)
	_check(
		resumed.is_active() and resumed.state == &"surface",
		"the pilot comes back standing on Aurora, not quietly back at Mudds"
	)
	var resumed_craft := resumed.get("_ship") as HeroShip
	var resumed_berth := resumed.get("_berth") as ShipBerth
	_check(
		is_instance_valid(resumed_craft)
			and resumed_craft.get_home_berth_id() == home_berth_id,
		"the resumed visit uses the same craft the pilot flew out in"
	)
	_check(
		is_instance_valid(resumed_berth)
			and resumed_berth.get_occupant() == resumed_craft
			and not String(resumed.get("_surface_token")).is_empty(),
		"the resumed craft holds a real berth lease on Aurora's pad again"
	)
	for _i in range(60):
		await physics_frame
	_check(
		not resumed_game.player.is_seated()
			and resumed_game.player.is_control_enabled()
			and resumed_game.player.is_on_floor(),
		"the resumed explorer has usable controls and physical support"
	)
	var retire := restore.get("retire", {}) as Dictionary
	_check(
		bool(retire.get("accepted", false)),
		"the interrupted-visit receipt is retired once the resume is accepted (%s/%s)"
			% [retire.get("reason", ""), retire.get("binding_reason", "")]
	)

	# --- re-board and return -------------------------------------------------
	_check(
		await _walk_to_boarding_area(resumed_game, resumed_craft),
		"the explorer walks back to the craft's boarding area"
	)
	await _press_interact()
	await _wait_state(resumed, &"landed", 600)
	_check(
		resumed.state == &"landed" and resumed_game.player.is_seated()
			and resumed_game._piloting
			and resumed_game.active_ship == resumed_craft,
		"a real interact re-boards the same physical craft"
	)
	if resumed.state != &"landed":
		await _finish(resumed_game)
		return
	_press_destination(resumed_game)
	await _wait_state(resumed, &"idle", 4000)
	_check(
		resumed.state == &"idle"
			and bool(resumed_craft.get_telemetry().get("landed", false)),
		"the return leg docks the craft back at the yard"
	)
	_check(
		resumed_game.world.visible
			and not is_instance_valid(resumed.get("_surface"))
			and _aurora_node_count(resumed_game) == 0,
		"departure leaves no Aurora nodes and restores the station presentation"
	)
	_check(
		_store_has_aurora_record(resumed_game) == false,
		"a completed visit leaves no interrupted-visit record behind"
	)

	# --- abandon from the surface -------------------------------------------
	resumed_game.call(&"_sync_planetary_cruise_hud")
	_press_destination(resumed_game)
	await _wait_state(resumed, &"landed", 4000)
	if resumed.state != &"landed":
		_check(false, "a further visit can be admitted for the abandon case")
		await _finish(resumed_game)
		return
	resumed_game.call(&"_try_exit_ship")
	await _wait_state(resumed, &"surface", 600)
	_check(resumed.state == &"surface", "the abandon case starts from the surface")
	resumed.cancel()
	for _i in range(40):
		await physics_frame
	_check(
		resumed.state == &"idle" and not resumed_game._piloting
			and not resumed_game._transition_busy
			and not resumed_game.player.is_seated()
			and resumed_game.player.is_control_enabled()
			and resumed_game.player.global_position.distance_to(home_position)
				< 40.0,
		"abandoning returns a controllable explorer to the yard, not a stranded one"
	)
	_check(
		bool(resumed_craft.get_telemetry().get("landed", false))
			and (resumed_craft.get_node("ShipBoardingArea") as ShipBoardingArea
				).get_reservation_token() == null,
		"abandoning leaves the craft docked at home with no held reservation"
	)
	_check(
		_aurora_node_count(resumed_game) == 0,
		"abandoning removes Aurora as cleanly as a completed departure"
	)
	await _finish(resumed_game)


# --- harness -----------------------------------------------------------------


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
	game.player.teleport_to(Transform3D(
		craft.global_basis,
		craft.get_boarding_position() + craft.global_basis.y * 0.01
	))
	for _i in range(6):
		await physics_frame
		await process_frame
	await _press_interact()
	for _i in range(300):
		await physics_frame
		if game._piloting:
			break
	_check(
		game._piloting and game.player.is_seated() and game.active_ship == craft,
		"an ordinary boarding takes the Halyard's pilot seat"
	)
	return craft if game._piloting else null


func _row(game: GameFlow) -> Dictionary:
	var snapshot := game.get_planetary_destination_catalog_snapshot() as Dictionary
	for row: Dictionary in snapshot.get("destinations", []):
		if row.get("destination_id") == DESTINATION_ID:
			return row
	return {}


func _press_destination(game: GameFlow) -> void:
	game.call(&"_sync_planetary_cruise_hud")
	game.hud.open_planetary_destination_board()
	var button := game.hud.find_child(
		"PlanetaryDestinationAction_%s" % DESTINATION_ID, true, false
	) as Button
	_check(
		button != null and not button.disabled,
		"Aurora's board action is visible and enabled"
	)
	if button != null and not button.disabled:
		button.pressed.emit()


## Counts everything of Aurora still parented under Main. A streamed world that
## departs cleanly leaves exactly zero.
func _aurora_node_count(game: GameFlow) -> int:
	var count := 0
	for candidate in game.find_children("*", "Node3D", true, false):
		if candidate is AuroraTemperateAuthoredScene:
			count += 1
	return count


func _store_has_aurora_record(game: GameFlow) -> bool:
	var store: Object = game.get("_runtime_settings_user_data_store")
	if store == null:
		return false
	var loaded := store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return false
	return (loaded.get("payload", {}) as Dictionary).has(
		String(GameFlow.AURORA_EXPEDITION_PERSISTENCE_SLOT)
	)


func _wait_state(owner: RefCounted, target: StringName, frames: int) -> void:
	for _i in range(frames):
		await physics_frame
		if owner.get("state") == target:
			return
	print("WAIT ENDED: ", owner.get("state"), " wanted ", target)


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


func _look_toward(player: PlayerController, target: Vector3) -> void:
	var direction := player.global_basis.inverse() * (
		target - player.global_position
	)
	(player.get_node("CameraRig/CameraYaw") as Node3D).rotation.y = atan2(
		-direction.x, -direction.z
	)


## Walks directly away from the craft along the pad, which is the one direction
## guaranteed to be authored walkable ground rather than the ship's own hull.
func _walk_away(
		player: PlayerController, craft: HeroShip, metres: float
	) -> bool:
	var start := player.global_position
	var away := (start - craft.global_position)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = craft.global_basis.x
	var target := start + away.normalized() * metres
	_look_toward(player, target)
	for _i in range(360):
		if player.global_position.distance_to(target) < 0.4:
			break
		_look_toward(player, target)
		Input.action_press(&"move_forward")
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _i in range(8):
		await physics_frame
		await process_frame
	return player.is_on_floor()


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
	print("%s: %d assertions" % [
		SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions,
	])
	quit(0 if _failures.is_empty() else 1)
