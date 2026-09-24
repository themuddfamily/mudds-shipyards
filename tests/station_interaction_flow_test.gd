extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DOOR_SCENE := preload("res://scenes/world/components/station_door.tscn")
const SEEN_STORE := preload("res://scripts/settings/tutorial_prompt_seen_store.gd")

## Extra simulated physics frames allowed on top of the exact number the door's
## own `motion_duration` requires. This is a frame count, never a wall-clock
## grace, so the budget is identical on an idle and on a saturated machine.
const DOOR_MOTION_FRAME_GRACE := 12

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_start_shift_currentness()
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()

	var player := game.get_node("Player") as PlayerController
	var door := DOOR_SCENE.instantiate() as StationDoor
	door.name = "IntegrationDoor"
	door.motion_duration = 0.08
	door.interaction_label = "AFT OPERATIONS"
	game.add_child(door)

	var player_transform: Transform3D = game.world.get_player_spawn()
	player.teleport_to(player_transform)
	door.global_position = player_transform.origin + Vector3(0.0, 0.0, -2.0)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame

	_check(
		game.station_interaction_candidate == door,
		"facing a nearby station door selects it through the shared interaction area"
	)
	_check(not game._near_ship, "station interaction does not fabricate a boarding candidate")
	game.call("_on_interact_requested")
	_check(
		door.get_state() == StationDoor.DoorState.OPENING,
		"the same embodied interact request starts the physical station door"
	)
	# `StationDoor` advances its panel in `_physics_process`, so the only clock that
	# measures its motion is the physics clock. A `SceneTree` timer counts smoothed
	# idle delta instead, and the two diverge under parallel load: Godot drops
	# physics steps to avoid a spiral of death while idle time keeps accumulating,
	# so a 0.15 s idle timer can fire before 0.08 s of simulated motion has been
	# stepped. Wait on the door's real completion with a budget counted in physics
	# frames, which is the same number of frames however busy the box is.
	var opened := await _wait_for_physics_frames(
		func() -> bool: return door.is_open() and not door.is_portal_blocked(),
		_door_motion_frame_budget(door)
	)
	_check(
		opened,
		"the started door completes its motion inside its own physics-frame budget"
	)
	_check(door.is_open() and not door.is_portal_blocked(), "door interaction reaches a traversable physical opening")

	# Facing is part of the interaction contract; proximity alone must not make a
	# station control behind the player consume E.
	var away_transform: Transform3D = player_transform
	away_transform.basis = Basis(Vector3.UP, PI)
	player.teleport_to(away_transform)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(
		game.station_interaction_candidate == null,
		"a nearby station door behind the camera does not consume interaction"
	)

	await _test_production_station_seat(game, player)
	await _test_activity_board_console(game, player)

	# A remote door must not disturb the established physical ship interaction.
	var arrow := game.get_node("ArrowReconShip") as HeroShip
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position()))
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(game.station_interaction_candidate == null, "remote station controls leave ship prompts clear")
	_check(game.boarding_candidate == arrow, "ship boarding still wins at its own physical interaction point")

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_production_station_seat(game: GameFlow, player: PlayerController) -> void:
	var habitat := game.world.find_child("HabitatSpine", true, false) as HabitatSpine
	var chair := (
		habitat.find_child("CommonChair01", true, false) as Node3D
		if habitat != null else null
	)
	var seat := (
		chair.get_node_or_null("StationSeatInteraction") as StationSeat
		if chair != null else null
	)
	_check(seat != null, "the pictured common-room chair owns a reusable station-seat interaction")
	if seat == null:
		return

	player.teleport_to(seat.get_entry_transform())
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(
		game.station_interaction_candidate == seat,
		"facing the pictured chair selects its sit prompt through ordinary station interaction"
	)
	game.call("_on_interact_requested")
	var sat := await _wait_for_physics_frames(
		func() -> bool: return player.is_station_seated(),
		60
	)
	_check(sat, "the embodied interaction reaches the chair's live seated anchor")
	_check(
		player.is_seated() and player.is_control_enabled() and player.get_camera().current,
		"sitting suspends locomotion while retaining the player camera and look controls"
	)
	_check(
		seat.is_reserved_for(player) and not seat.is_available(),
		"an occupied chair withdraws itself from competing interaction discovery"
	)
	game.call("_on_interact_requested")
	var stood := await _wait_for_physics_frames(
		func() -> bool: return player.is_control_enabled() and seat.is_available(),
		60
	)
	_check(stood, "a second embodied interaction stands up onto the authored clear floor pose")
	_check(
		player.is_control_enabled() and seat.is_available() and not seat.is_reserved_for(player),
		"standing restores locomotion and releases the chair for reuse"
	)


func _test_activity_board_console(game: GameFlow, player: PlayerController) -> void:
	var console := game.world.call(&"get_activity_board_console") as Area3D
	var hud := game.hud as GameHUD
	_check(console != null, "Aft Operations ConsoleBay02 exposes one physical Activity Board interaction")
	if console == null or hud == null:
		return
	# Keep this physical-route check independent of a developer's user:// save.
	game._tutorial_prompt_seen_store = SEEN_STORE.new()
	var selection_before := game.get_activity_integration_report()
	var console_connections := console.get_signal_connection_list(&"open_requested")
	var approach := console.global_position + Vector3(0.0, 0.0, -1.05)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), approach))
	# A physics press can reach the board before the idle pass paints its hint.
	# It may open the page, but cannot consume guidance the player did not see.
	await physics_frame
	game.call(&"_refresh_interaction_targets")
	console.call(&"interact", player)
	_check(
		(hud.get("_activity_selection_page") as Control).visible
		and not game.has_seen_activity_tutorial(GameFlow.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"an open request before the board hint renders does not mark it seen"
	)
	hud.set_paused(false)
	await physics_frame
	await physics_frame
	# process_frame resumes before node _process callbacks. Cross a completed
	# idle pass so the ordinary prompt refresh sees the new physics overlaps.
	await process_frame
	await process_frame
	_check(
		game.station_interaction_candidate == console
		and "ACTIVITY BOARD" in str(console.call(&"get_interaction_prompt")),
		"facing the physical console selects its shared on-foot prompt"
	)
	var prompt := hud.get("_interaction_label") as Label
	_check(
		prompt != null and "CHOOSE A SORTIE OR REVIEW RETURNS" in prompt.text
		and prompt.text.begins_with("[ %s ]" % hud.get_action_prompt(&"interact"))
		and not game.has_seen_activity_tutorial(GameFlow.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"physical approach shows the keyboard-bound tutorial without marking it seen"
	)
	hud.call(&"_on_controller_glyph_family_selected", 2)
	await process_frame
	await process_frame
	_check(
		prompt.text.begins_with("[ %s ]" % hud.get_action_prompt(&"interact"))
		and "CHOOSE A SORTIE OR REVIEW RETURNS" in prompt.text,
		"the live board hint follows the selected controller glyph"
	)
	var default_profile: InputBindingProfile = hud.get("_input_binding_profile").duplicate_profile()
	var remapped_profile := default_profile.duplicate_profile()
	remapped_profile.set_bindings(&"interact", [{
		"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB,
	}])
	hud.set_settings_snapshot({"input_binding_profile": remapped_profile.to_dictionary()})
	var glyph_presenter: Variant = hud.get("_runtime_input_glyph_presenter")
	glyph_presenter.set_device_family(&"keyboard")
	await process_frame
	await process_frame
	_check(
		prompt.text.begins_with("[ Tab ]")
		and "CHOOSE A SORTIE OR REVIEW RETURNS" in prompt.text,
		"a remapped keyboard interact binding redraws the same live board hint"
	)
	hud.set_settings_snapshot({"input_binding_profile": default_profile.to_dictionary()})
	player.teleport_to(game.world.get_player_spawn())
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(
		not "CHOOSE A SORTIE" in prompt.text
		and not game.has_seen_activity_tutorial(GameFlow.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"leaving board range clears the hint without consuming it"
	)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), approach))
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	var competing_door := game.get_node("IntegrationDoor") as StationDoor
	var prior_door_position := competing_door.global_position
	competing_door.global_position = (
		player.get_interaction_origin() + player.get_interaction_direction() * 0.4
	)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(
		game.station_interaction_candidate == competing_door
		and not "CHOOSE A SORTIE" in prompt.text,
		"a higher-priority nearby interaction clears the board guidance"
	)
	console.emit_signal(&"open_requested", player)
	_check(
		not (hud.get("_pause") as Control).visible
		and not game.has_seen_activity_tutorial(GameFlow.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"a displaced board signal cannot open the page or consume its tutorial"
	)
	competing_door.global_position = prior_door_position
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(game.station_interaction_candidate == console, "leaving the competing control restores the board candidate")
	game.runtime_settings.show_tutorials = false
	await process_frame
	await process_frame
	_check(not "CHOOSE A SORTIE" in prompt.text, "the tutorial setting suppresses board guidance")
	game.call(&"_on_interact_requested")
	var pause_overlay := hud.get("_pause") as Control
	var activity_page := hud.get("_activity_selection_page") as Control
	_check(
		pause_overlay != null and pause_overlay.visible
		and activity_page != null and activity_page.visible
		and not game.has_seen_activity_tutorial(GameFlow.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"opening while tutorials are disabled does not consume guidance the player never saw"
	)
	hud.set_paused(false)
	game.runtime_settings.show_tutorials = true
	await process_frame
	await process_frame
	_check("CHOOSE A SORTIE" in prompt.text, "re-enabling tutorials restores unconsumed guidance")
	game.call(&"_on_interact_requested")
	_check(
		pause_overlay != null and pause_overlay.visible
		and activity_page != null and activity_page.visible,
		"one embodied interaction pauses and focuses the existing Activity Board page"
	)
	_check(
		game.has_seen_activity_tutorial(GameFlow.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"the tutorial is marked seen only after the Activity Board actually opens"
	)
	var selection_after := game.get_activity_integration_report()
	_check(
		selection_before.get("selected_activity_kind", &"") == selection_after.get("selected_activity_kind", &"")
		and selection_before.get("active_activity_id", &"") == selection_after.get("active_activity_id", &"")
		and selection_before.get("active_generation", -1) == selection_after.get("active_generation", -2),
		"opening the console changes no selection, start, generation, or reward authority"
	)
	hud.set_paused(false)
	await process_frame
	await process_frame
	_check(
		not "CHOOSE A SORTIE" in prompt.text,
		"the ordinary board interaction remains after the one-time hint is consumed"
	)
	var combat_authority := game.get_combat_authority()
	var combat_resolver := game.get_combat_resolver()
	var startup_roster := game.get_live_combat_source_roster_audit()
	_check(
		is_instance_valid(combat_authority)
		and is_instance_valid(combat_resolver)
		and bool(startup_roster.get("valid", false))
		and int(startup_roster.get("actual_source_count", -1)) == 12
		and int(startup_roster.get("expected_source_count", -1)) == 12
		and int(startup_roster.get("expected_station_defense_source_count", -1)) == 3,
		"startup owns the exact player, range, station-defense, and retained heavy-picket source roster"
	)
	var authority_instance_id := combat_authority.get_instance_id()
	var resolver_instance_id := combat_resolver.get_instance_id()
	root.remove_child(game)
	await process_frame
	_check(
		combat_resolver.get_registered_source_count() == 0,
		"Main detach retires every live source registration while retaining combat identity"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var rebound_console := game.world.call(&"get_activity_board_console") as Area3D
	var rebound_roster := game.get_live_combat_source_roster_audit()
	_check(
		rebound_console == console
		and rebound_console.get_signal_connection_list(&"open_requested").size()
		== console_connections.size(),
		"Main detach/reentry retains one console and one GameFlow signal binding"
	)
	_check(
		game.get_combat_authority().get_instance_id() == authority_instance_id
		and game.get_combat_resolver().get_instance_id() == resolver_instance_id
		and bool(rebound_roster.get("valid", false))
		and int(rebound_roster.get("actual_source_count", -1)) == 12
		and int(rebound_roster.get("expected_source_count", -1)) == 12
		and int(rebound_roster.get("expected_station_defense_source_count", -1)) == 3
		and int(
			(rebound_roster.get("station_defense_sources", {}) as Dictionary)
				.get("exact_registration_count", -1)
		) == 4,
		"retained Main restores twelve exact source identities once on the same combat authority and resolver"
	)


func _test_start_shift_currentness() -> void:
	var detached_game := MAIN_SCENE.instantiate() as GameFlow
	detached_game.name = "DetachedStartShiftGame"
	root.add_child(detached_game)
	await process_frame
	await physics_frame
	var detached_before := _start_shift_snapshot(detached_game)
	root.remove_child(detached_game)
	detached_game.start_shift()
	_check(
		not detached_game.is_inside_tree()
			and _start_shift_snapshot(detached_game) == detached_before,
		"a detached GameFlow rejects direct start-shift mutation atomically"
	)
	root.add_child(detached_game)
	await process_frame
	detached_game.start_shift()
	_check(
		detached_game.is_inside_tree()
			and detached_game.phase == GameFlow.Phase.APPROACH_SHIP
			and (detached_game.player as PlayerController).is_control_enabled()
			and (detached_game.player as PlayerController).get_camera().current,
		"a fresh live GameFlow re-entry accepts its current start-shift request"
	)
	detached_game.queue_free()
	await process_frame
	await process_frame

	var queued_game := MAIN_SCENE.instantiate() as GameFlow
	queued_game.name = "QueuedStartShiftGame"
	root.add_child(queued_game)
	await process_frame
	await physics_frame
	var queued_before := _start_shift_snapshot(queued_game)
	queued_game.queue_free()
	queued_game.start_shift()
	_check(
		queued_game.is_inside_tree()
			and queued_game.is_queued_for_deletion()
			and _start_shift_snapshot(queued_game) == queued_before,
		"a queued GameFlow rejects direct start-shift mutation atomically"
	)
	await process_frame
	await process_frame
	_check(not is_instance_valid(queued_game), "the queued GameFlow fixture frees normally")


func _start_shift_snapshot(game: GameFlow) -> Dictionary:
	var player := game.player as PlayerController
	var hud := game.hud as CanvasLayer
	var audio := game.audio as AudioDirector
	var objective := hud.get("_objective_label") as Label
	var objective_kicker := hud.get("_objective_kicker") as Label
	var toast_title := hud.get("_toast_title") as Label
	var toast_detail := hud.get("_toast_detail") as Label
	var toast_panel := hud.get("_toast_panel") as PanelContainer
	return {
		"phase": game.phase,
		"player_control_enabled": player.is_control_enabled(),
		"player_camera_current": player.get_camera().current,
		"hud_mode": hud.get("_state_mode"),
		"objective": objective.text if objective != null else "",
		"objective_kicker": objective_kicker.text if objective_kicker != null else "",
		"toast_title": toast_title.text if toast_title != null else "",
		"toast_detail": toast_detail.text if toast_detail != null else "",
		"toast_visible": toast_panel.visible if toast_panel != null else false,
		"toast_serial": hud.get("_toast_serial"),
		"audio_on_foot_volume_db": audio.get("_desired_ambience_volume_db"),
	}.duplicate(true)


## Exactly the number of physics steps `door.motion_duration` needs at the
## project's configured tick rate, plus a fixed frame grace. Derived from the
## door's own export so shortening or lengthening the motion keeps the budget
## honest instead of silently gaining slack.
func _door_motion_frame_budget(door: StationDoor) -> int:
	var required := int(ceil(door.motion_duration * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + DOOR_MOTION_FRAME_GRACE


## Waits for `predicate` on the physics clock. Returns `false` once the budget of
## simulated frames is spent, so a stalled condition still fails the suite rather
## than hanging, but a merely slow machine is never mistaken for a broken door.
func _wait_for_physics_frames(predicate: Callable, maximum_frames: int) -> bool:
	if bool(predicate.call()):
		return true
	for _frame in maximum_frames:
		await physics_frame
		if bool(predicate.call()):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_INTERACTION_FLOW_TEST_OK")
		quit(0)
	else:
		print("STATION_INTERACTION_FLOW_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
