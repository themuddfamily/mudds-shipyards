extends SceneTree

## Production integration for the drivable yard tow tractor.
##
## Everything here runs through `res://scenes/main.tscn` and real input actions:
## the player walks up, presses E, drives with W/A/S/D, brakes, and presses E
## again. No direct `_board_tow_tractor()` call, no node-name selection, and no
## synthetic seat handoff participates.
##
## The suite has four jobs:
##
## 1. Prove the walk-up / board / drive / exit loop works in the shipped scene.
## 2. Prove the tractor took no craft authority: the five-berth fleet roster, the
##    guided Torrent activity and the range contacts are all untouched by it.
## 3. Prove the player cannot be stranded — including the case where the tractor
##    ends up off the station with the driver aboard.
## 4. Prove the vehicle survives a whole-`Main` detach and re-entry without
##    duplicating itself or leaving an occupant behind.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const FRAME_BUDGET_GRACE := 30
const PHASE_SETTLE_SECONDS := 0.1
const TRANSITION_SECONDS := 0.24

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "the production scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var opponent := game.get_node("RangeOpponent") as CharacterBody3D
	var original_game_id := game.get_instance_id()
	var original_player_id := player.get_instance_id()

	var tractor := game.get_tow_tractor()
	_check(tractor != null, "the production world ships exactly one drivable tow tractor")
	if tractor == null:
		await _clean_up(game)
		_finish()
		return
	var tractor_instances := world.find_children("*", "TowTractor", true, false)
	_check(tractor_instances.size() == 1, "the world holds one tractor instance, not a duplicate pair")
	_check(
		world.find_children("TowCab", "", true, false).is_empty()
		and world.find_children("TowWheel*", "", true, false).is_empty(),
		"the static tow-tractor prop boxes and wheels are gone, replaced by the vehicle"
	)

	# --- Group 1: the tractor holds no craft authority -----------------------
	var fleet := game.get_flyable_ships()
	_check(fleet.size() == 5, "the fleet registry still holds exactly five flyable craft")
	for registered in fleet:
		_check(
			registered.get_instance_id() != tractor.get_instance_id(),
			"%s is a craft; the tractor is not among the registered fleet" % registered.name
		)
	var tractor_node: Node = tractor
	_check(tractor_node is not HeroShip, "the tractor is not a HeroShip")
	_check(
		not tractor.has_method(&"get_home_berth_id"),
		"the tractor claims no home berth"
	)
	var berth_occupants: Dictionary = {}
	for berth_id in [
		&"central_berth", &"arrow_recon_berth", &"jovian_freight_berth", &"zenith_fleet_dock_berth"
	]:
		var berth := world.get_berth_node(berth_id)
		_check(berth != null and berth.get_occupant() != tractor, "%s is not leased to the tractor" % berth_id)
		berth_occupants[berth_id] = berth.get_occupant() if berth != null else null

	# --- Group 2: the spawn is not compromised -------------------------------
	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.04
	game.disembarking_motion_time = 0.04
	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "the shift begins on foot with the guide pending")

	var spawn := world.get_player_spawn()
	player.teleport_to(spawn)
	await _advance(4)
	_check(
		player.is_on_floor(),
		"the player still spawns standing on the deck with the tractor in the world"
	)
	var station := tractor.get_driver_station()
	_check(
		spawn.origin.distance_to(station.global_position) > 6.0,
		"the tractor's driver step is well clear of the spawn point"
	)
	_check(
		not player.get_nearby_interactables().has(station),
		"the tractor does not intercept the first interact prompt the player sees"
	)
	# Real E at the spawn must do nothing at all, which is the strongest form of
	# that claim: the prompt is not merely hidden, the seat is not reachable.
	await _press(&"interact", 2)
	await _advance(6)
	_check(
		not game.is_driving_tow_tractor() and game.phase == GameFlow.Phase.APPROACH_SHIP,
		"pressing interact at the spawn does not board the tractor"
	)
	# The player is not trapped against the tractor: they can walk off the spawn.
	var walk_start := player.global_position
	await _press(&"move_forward", 24)
	_check(
		player.global_position.distance_to(walk_start) > 1.0,
		"the player can walk away from the spawn point"
	)

	# --- Group 3: walk up, board, drive, exit --------------------------------
	_walk_to(player, tractor)
	var prompt_ready := await _wait_until(
		func() -> bool: return game.station_interaction_candidate == station,
		PHASE_SETTLE_SECONDS
	)
	_check(prompt_ready, "walking up to the tractor selects its driver step inside its frame budget")
	_check(
		tractor.get_interaction_prompt().begins_with("[ E ]"),
		"the driver step offers a one-key prompt"
	)
	_check(
		game.boarding_candidate == null,
		"the tractor never appears as a spacecraft boarding candidate"
	)

	await _press(&"interact", 1)
	var boarded := await _wait_until(
		func() -> bool: return game.is_driving_tow_tractor(),
		TRANSITION_SECONDS
	)
	_check(boarded, "a real interact press seats the player in the tractor inside its frame budget")
	_check(player.is_seated(), "the same visible character occupies the driver seat")
	_check(tractor.is_driven(), "the tractor takes its driver")
	_check(
		tractor.get_camera().current and not player.get_camera().current,
		"boarding hands the live camera to the tractor's chase rig"
	)
	_check(not tractor.is_boardable(), "an occupied tractor closes its seat to anyone else")
	_check(
		not station.is_available(),
		"the occupied driver step leaves physics discovery so it cannot mask another prompt"
	)
	_check(
		game.get_active_ship() != null and not game.get_active_ship().is_piloted(),
		"driving the tractor never makes a spacecraft piloted"
	)
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "driving the tractor does not consume a flight phase")

	var drive_start := tractor.global_position
	Input.action_press(&"move_forward")
	await _advance(70)
	_check(
		tractor.get_drive_speed() > 5.0,
		"a real held W accelerates the tractor across the deck"
	)
	_check(
		tractor.global_position.distance_to(drive_start) > 5.0,
		"the tractor covers real station deck"
	)
	_check(
		player.global_position.distance_to(tractor.get_driver_seat_anchor().global_position) < 0.01,
		"the driver rides the moving tractor instead of being left behind"
	)
	_check(
		tractor.is_on_floor() and not tractor.has_reported_recovery(),
		"driving across the deck raises no recovery"
	)

	var heading_before := -tractor.global_basis.z
	await _press(&"move_left", 30)
	Input.action_release(&"move_forward")
	_check(
		heading_before.angle_to(-tractor.global_basis.z) > deg_to_rad(15.0),
		"a real held A steers the tractor"
	)

	await _press(&"brake", 70)
	_check(is_zero_approx(tractor.get_drive_speed()), "a real held brake stops the tractor")
	_check(tractor.can_release_driver(), "a stopped tractor releases its driver")

	await _press(&"interact", 1)
	var exited := await _wait_until(
		func() -> bool: return not game.is_driving_tow_tractor(),
		TRANSITION_SECONDS
	)
	_check(exited, "a real interact press dismounts the driver inside its frame budget")
	_check(
		not player.is_seated() and player.is_control_enabled(),
		"the dismount returns the same character to on-foot control"
	)
	_check(
		player.global_position.distance_to(tractor.global_position) < 5.0
		and player.global_position.y > TowTractor.RECOVERY_FLOOR_Y,
		"the driver steps off beside the tractor, on real deck"
	)
	await _advance(8)
	_check(player.is_on_floor(), "the dismounted player is standing on the deck")
	_check(tractor.is_boardable(), "the tractor is immediately available again")
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP,
		"the pending guided Torrent objective is restored after the drive"
	)

	# --- Group 4: the guided activity is untouched ---------------------------
	_check(game.destroyed_targets == 0, "driving the tractor destroys no range contacts")
	_check(not game.is_guided_activity_complete(), "driving the tractor does not complete the guided test")
	_check(not bool(opponent.call("is_active")), "the range defender stays dormant throughout")
	_check(torrent.is_boardable(), "the Torrent remains available after the drive")
	_check(game.get_flyable_ships().size() == 5, "the fleet roster is unchanged by the drive")
	for berth_id: Variant in berth_occupants:
		var berth := world.get_berth_node(berth_id as StringName)
		_check(
			berth != null and berth.get_occupant() == berth_occupants[berth_id],
			"%s keeps its original occupant across the drive" % berth_id
		)

	# --- Group 5: the player cannot be stranded ------------------------------
	# Red witness first: an equivalent span of driving *on* the deck must leave the
	# driver seated and un-recalled, so the recovery below is not an always-on
	# recall that would pass whatever the vehicle did.
	_walk_to(player, tractor)
	await _wait_until(
		func() -> bool: return game.station_interaction_candidate == station,
		PHASE_SETTLE_SECONDS
	)
	await _press(&"interact", 1)
	var reboarded := await _wait_until(
		func() -> bool: return game.is_driving_tow_tractor(),
		TRANSITION_SECONDS
	)
	_check(reboarded, "the tractor can be boarded a second time inside its frame budget")
	Input.action_press(&"move_forward")
	await _advance(140)
	Input.action_release(&"move_forward")
	_check(
		game.is_driving_tow_tractor() and player.is_seated(),
		"red witness: driving on the deck keeps the driver seated"
	)
	_check(
		not tractor.has_reported_recovery()
		and player.global_position.distance_to(spawn.origin) > 1.0,
		"red witness: driving on the deck never recalls the player to the spawn"
	)

	# Green: the tractor leaves the station with the driver aboard. However it got
	# there — a missed edge, changed geometry, a launch off a ramp — the driver
	# comes back. This is the P0 soft-lock the whole safety design exists for.
	tractor.global_position = spawn.origin + Vector3(0.0, TowTractor.RECOVERY_FLOOR_Y - 40.0, 0.0)
	tractor.velocity = Vector3.ZERO
	var recovered := await _wait_until(
		func() -> bool: return not game.is_driving_tow_tractor(),
		1.0
	)
	_check(recovered, "a tractor lost off the station recalls its driver inside its frame budget")
	_check(
		not player.is_seated() and player.is_control_enabled(),
		"the recalled driver is a controllable on-foot character again"
	)
	_check(
		player.global_position.distance_to(spawn.origin) < 1.0,
		"the recalled driver is standing at the on-foot spawn"
	)
	_check(
		player.global_position.y > TowTractor.RECOVERY_FLOOR_Y,
		"the recalled driver is above the recovery floor, not still falling"
	)
	_check(
		game.get_last_tractor_recovery_reason() == &"fell_below_station",
		"the coordinator records which of the two safety guards recalled the driver"
	)
	_check(game.get_instance_id() == original_game_id, "recovery preserves the same session instance")
	_check(game.get_instance_id() == original_game_id and player.get_instance_id() == original_player_id,
		"recovery preserves the same player instance rather than respawning a new one")
	var home := tractor.get_home_transform().origin
	var parked := tractor.global_position
	# The authored spot is a metre above the finished deck so the vehicle settles
	# onto whatever height the deck actually is, so compare the parking *place*
	# and let gravity own the last few centimetres.
	_check(
		Vector2(parked.x, parked.z).distance_to(Vector2(home.x, home.z)) < 0.05
		and parked.y <= home.y + 0.01
		and parked.y > home.y - 1.0,
		"the lost tractor is returned to its authored parking spot"
	)
	await _advance(20)
	_check(player.is_on_floor(), "the recalled player settles onto the deck")
	_check(
		tractor.is_on_floor() and not tractor.has_reported_recovery(),
		"the returned tractor is standing on the deck with its recovery report re-armed"
	)
	_check(tractor.is_boardable(), "the recovered tractor can be driven again")
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP and game.get_flyable_ships().size() == 5,
		"recovery leaves the guided objective and the fleet roster exactly as they were"
	)

	# The player can still reach a spacecraft afterwards, which is what "not
	# stranded" has to mean in a game whose objective is a flight test.
	player.teleport_to(Transform3D(Basis.IDENTITY, torrent.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	var torrent_selected := await _wait_until(
		func() -> bool: return game.boarding_candidate == torrent,
		PHASE_SETTLE_SECONDS
	)
	_check(torrent_selected, "the recovered player can still select the guided Torrent")

	# --- Group 6: whole-Main detach and re-entry -----------------------------
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	_check(
		world.find_children("*", "TowTractor", true, false).size() == 1,
		"a whole-Main detach and re-entry does not duplicate the tractor"
	)
	_check(
		game.get_tow_tractor() == tractor,
		"the re-entered session re-binds the same tractor instance"
	)
	_check(
		not game.is_driving_tow_tractor() and not player.is_seated(),
		"the re-entered session leaves no stranded occupant aboard"
	)
	_walk_to(player, tractor)
	await _wait_until(
		func() -> bool: return game.station_interaction_candidate == station,
		PHASE_SETTLE_SECONDS
	)
	await _press(&"interact", 1)
	var post_reentry_board := await _wait_until(
		func() -> bool: return game.is_driving_tow_tractor(),
		TRANSITION_SECONDS
	)
	_check(post_reentry_board, "the tractor is still drivable after a whole-Main detach and re-entry")
	await _press(&"brake", 40)
	await _press(&"interact", 1)
	var post_reentry_exit := await _wait_until(
		func() -> bool: return not game.is_driving_tow_tractor(),
		TRANSITION_SECONDS
	)
	_check(post_reentry_exit, "the post-re-entry drive can also be left")
	_check(player.is_control_enabled(), "the session ends with a controllable on-foot player")

	await _clean_up(game)
	_finish()


## Puts the player where a walking pilot ends up when they come to use the
## tractor, looking at it, which is what the interaction facing test measures.
func _walk_to(player: PlayerController, tractor: TowTractor) -> void:
	var approach := tractor.get_boarding_position()
	var offset := tractor.global_position - approach
	offset.y = 0.0
	player.teleport_to(Transform3D(Basis.looking_at(offset, Vector3.UP), approach))


func _advance(frames: int) -> void:
	for _frame in maxi(1, frames):
		await physics_frame
		await process_frame


func _press(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
		await process_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


## Physics frames a nominal duration is worth at the configured tick rate, plus a
## fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for `predicate` on the simulation clock rather than the wall clock. The
## boarding chain, the drive integration and the recovery net are all advanced by
## the engine loops; a `SceneTree` timer counts a different, smoothed clock that
## diverges from them under load in both directions.
func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var budget := _frame_budget(nominal_seconds)
	var frames := 0
	while not bool(predicate.call()):
		if frames >= budget:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _clean_up(game: Node) -> void:
	for action in [
		&"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"brake", &"jump"
	]:
		Input.action_release(action)
	await _release_combat_audio_before_main_teardown(game)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
	if combat_audio == null:
		return
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var audio_player := candidate as AudioStreamPlayer3D
		audio_player.stop()
		audio_player.stream_paused = false
		audio_player.stream = null
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TOW_TRACTOR_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("TOW_TRACTOR_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
