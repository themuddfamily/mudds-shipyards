extends SceneTree

## Controller-only, production-scene proof of an Ember expedition.
##
## Every player decision is a synthetic joypad event parsed through the real
## `Input` singleton: X starts the shift, the left stick walks, X boards, A plus
## the left stick lift off, Start opens pause, the D-pad walks the pause page
## and Destination Board, A accepts, B backs out, X takes and abandons an errand
## at its trailhead, the pause-row cruise action abandons the expedition, and X
## reboards for the Host's own takeoff home. No keyboard or mouse event and no
## gameplay method stands in for a press.
##
## Staging is exactly `ember_repeat_visit_landing_test.gd`'s: production has no
## owner that flies the craft the 8,000 km from the yard or the last 10 km into
## the corridor, so the craft is held at the navigation anchor until the real
## cruise binding activates its final approach, then placed once at the authored
## corridor entry. The pilot is likewise placed next to a trailhead and back next
## to the craft instead of being steered across the caldera. Every prompt the
## player reads on the way must name controller inputs, never a keyboard key.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://controller-only-planetary-expedition.json"

const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const AXIS_RIGHT_X := 2
const AXIS_RIGHT_Y := 3
const AXIS_LEFT_TRIGGER := 4
const AXIS_RIGHT_TRIGGER := 5

const BUTTON_A := 0
const BUTTON_B := 1
const BUTTON_X := 2
const BUTTON_START := 6
const BUTTON_DPAD_UP := 11
const BUTTON_DPAD_DOWN := 12
const BUTTON_DPAD_LEFT := 13

const CRAFT_ID: StringName = &"arrow_provisional"
const FRAME_BUDGET_GRACE := 30
const ORBIT_STANDOFF_M := 500.0
const ORBIT_HOLD_SPEED_MPS := 8.0
const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 240
const ORBIT_STAGE_TICK_BUDGET := 420
const HANDOFF_TICK_BUDGET := 600
const LANDING_TICK_BUDGET := 1500
const DISEMBARK_TICK_BUDGET := 600
const TRAILHEAD_TICK_BUDGET := 120
const REBOARD_TICK_BUDGET := 600
const ABANDON_TICK_BUDGET := 2400
## Keyboard-authored tokens a pad-only player must never be shown.
const KEYBOARD_TOKENS: Array[String] = [
	"[ E ]", "[ L ]", "[ L /", "ESC:", "Esc →", "W/S", "press L",
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
			isolated_store, "memory://controller-only-planetary-expedition-legacy.cfg"
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
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06

	var hud := game.hud
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	_check(
		hud != null and player != null and host != null and cruise != null,
		"production Main composes the HUD, pilot, Ember host and cruise binding"
	)
	if hud == null or player == null or host == null or cruise == null:
		await _tear_down(game)
		_finish()
		return
	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 1, 4.0)
	var craft: HeroShip = null
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == CRAFT_ID:
			craft = candidate
	_check(craft != null, "the yard offers the Arrow for the Ember expedition")
	if craft == null:
		await _tear_down(game)
		_finish()
		return

	# --- Shift start and boarding -------------------------------------------
	await _tap_joy(BUTTON_X)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.APPROACH_SHIP, 1.0
		),
		"controller X starts the shift from the title card"
	)
	# The guided first sortie is not the subject here; open free flight exactly
	# as the repeat-visit suite does so the departed craft can take a route.
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE

	var boarded := await _walk_and_board(game, player, craft)
	_check(boarded, "left stick walks to the Arrow and controller X boards it")
	if not boarded:
		await _tear_down(game)
		_finish()
		return
	var launched := await _launch(game)
	_check(launched, "controller A and the left stick lift the Arrow into free flight")
	game.set("_active_activity_id", &"")
	var aurora: Object = game.get("_aurora_expedition")
	if aurora != null and bool(aurora.call(&"is_active")):
		aurora.call(&"cancel")
	game.call("_sync_planetary_cruise_hud")

	# --- Pause, Destination Board and the cruise row ------------------------
	var pause := hud.get("_pause") as Control
	var destinations_button := pause.find_child(
		"PlanetaryDestinationOpenButton", true, false
	) as Button
	var cruise_button := pause.find_child(
		"PlanetaryCruiseToggleButton", true, false
	) as Button
	var destination_page := hud.get("_planetary_destination_page") as Control
	await _tap_joy(BUTTON_START)
	_check(pause.visible and paused, "controller Start pauses the flight")
	var reached_destinations := await _dpad_down_to(destinations_button, 6)
	_check(reached_destinations, "the D-pad reaches the Destination Board button")
	await _tap_joy(BUTTON_A)
	var ember_action := pause.find_child(
		"PlanetaryDestinationAction_ember_moon", true, false
	) as Button
	_check(
		destination_page.visible and ember_action != null
			and root.gui_get_focus_owner() == ember_action,
		"controller A opens the Destination Board focused on Ember"
	)
	await _tap_joy(BUTTON_B)
	_check(
		not destination_page.visible and pause.visible
			and root.gui_get_focus_owner() == destinations_button,
		"controller B returns from the board to the pause page"
	)
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(
		root.gui_get_focus_owner() == cruise_button
			and not cruise_button.disabled
			and cruise_button.text.ends_with("ENGAGE"),
		"one D-pad press reaches an enabled EMBER CRUISE // ENGAGE row"
	)
	await _tap_joy(BUTTON_A)
	var admitted := (
		not (game.get("_pending_ember_surface_request") as Dictionary).is_empty()
		or bool(game.get("_ember_surface_journey_active"))
	)
	_check(admitted, "controller A on the cruise row admits the Ember expedition")
	await _tap_joy(BUTTON_START)
	_check(not pause.visible and not paused, "controller Start resumes the flight")
	if not admitted:
		await _tear_down(game)
		_finish()
		return

	# --- Staged cruise, real descent and landing ----------------------------
	var activated := await _stage_orbital_approach(game, craft, cruise)
	_check(activated, "the real cruise binding activates the Ember final approach")
	var handed_off := activated and await _stage_corridor_entry(game, craft, host)
	_check(handed_off, "the final approach hands off to the surface Host")
	var landed := handed_off and await _advance_to_phase(
		host, EmberSurfaceLoopHost.Phase.LANDED, LANDING_TICK_BUDGET
	)
	_check(landed, "the Arrow lands on the caldera pad")
	_check_controller_prompt(hud, "landed prompt")
	var on_foot := landed and await _advance_to_phase(
		host, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, DISEMBARK_TICK_BUDGET
	)
	_check(
		on_foot and not player.is_seated() and player.is_control_enabled(),
		"the pilot disembarks onto the Ember surface"
	)
	if not on_foot:
		await _tear_down(game)
		_finish()
		return

	# --- Outbound route: the errands open once the pilot is out on foot ----
	# The Host only reaches ON_FOOT after the pilot has crossed the authored
	# egress and staging anchors; the caldera trailheads and their errands are
	# offered from that phase, never from the pad (d88409c8f).
	var crossed := await _cross_outbound_route(player, host)
	_check(crossed, "the pilot crosses the caldera's outbound route onto foot")

	# --- Errand trailhead: take it, then abandon it, with X ----------------
	var trailhead := _available_trailhead(game)
	_check(trailhead != null, "a caldera errand trailhead is offered on the surface")
	if trailhead != null:
		# Stand one metre east of the trailhead, facing it.
		player.teleport_to(Transform3D(
			Basis.looking_at(Vector3.LEFT, Vector3.UP),
			trailhead.global_position + Vector3(1.0, 0.3, 0.0)
		))
		var at_trailhead := await _wait_for(
			func() -> bool: return game.station_interaction_candidate == trailhead,
			TRAILHEAD_TICK_BUDGET
		)
		_check(at_trailhead, "standing at the trailhead makes it the interaction candidate")
		await _settle(4)
		_check_controller_prompt(hud, "trailhead prompt")
		var interaction_text := _interaction_text(hud)
		_check(
			interaction_text.begins_with("[ %s ]" % hud.get_action_prompt(&"interact"))
				and interaction_text.contains("BEGIN"),
			"the trailhead prompt shows the live controller interact glyph (%s)"
				% interaction_text
		)
		await _tap_joy(BUTTON_X)
		await _settle(6)
		_check(
			StringName(trailhead.get_snapshot().get("offer_state", &"")) == &"active",
			"controller X takes the caldera errand"
		)
		await _settle(2)
		_check(
			_interaction_text(hud).contains("ABANDON"),
			"the active errand offers its abandon prompt (%s)" % _interaction_text(hud)
		)
		_check_controller_prompt(hud, "errand abandon prompt")
		await _tap_joy(BUTTON_X)
		await _settle(6)
		_check(
			StringName(trailhead.get_snapshot().get("offer_state", &"")) != &"active",
			"a second controller X abandons the errand"
		)

	# --- Abandon the expedition from the pause-row cruise action ----------
	await _tap_joy(BUTTON_START)
	_check(pause.visible, "controller Start opens pause on the surface")
	var reached_row := await _dpad_down_to(cruise_button, 8)
	_check(
		reached_row and not cruise_button.disabled,
		"the D-pad reaches the enabled cruise row from the surface"
	)
	var toast_title := hud.get("_toast_title") as Label
	await _tap_joy(BUTTON_A)
	_check(
		toast_title != null and toast_title.text == "EMBER CRUISE",
		"controller A on the cruise row abandons the expedition (%s)"
			% (toast_title.text if toast_title != null else "")
	)
	await _tap_joy(BUTTON_START)
	_check(not pause.visible and not paused, "controller Start resumes on the surface")

	# --- Reboard and the Host's own takeoff home ----------------------------
	var reboarded := await _reboard(game, player, host, craft)
	_check(reboarded, "left stick and controller X reboard the craft at the caldera")
	var released := reboarded and await _advance_until_abandon_commits(game, host)
	_check(
		released and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and not bool(game.get("_ember_surface_journey_active")),
		"the abandoned expedition returns the pilot home through the Host's takeoff"
	)
	_check(
		player.is_seated() and game.get_active_ship() == craft,
		"the returning pilot is still seated in the same Arrow"
	)

	await _tear_down(game)
	_finish()


# ---------------------------------------------------------------- steps ----


func _walk_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(-approach, Vector3.UP),
		boarding + up * 0.05 + approach * 6.0
	))
	player.set_control_enabled(true)
	await _settle(4)
	var arrived := await _stick_walk_until(
		func() -> bool: return game.boarding_candidate == craft,
		LOCOMOTION_TICK_BUDGET
	)
	if not arrived:
		return false
	_check_controller_prompt(game.hud, "boarding prompt")
	for _attempt in 3:
		await _tap_joy(BUTTON_X)
		if await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 2.0
		):
			break
	return game.phase == GameFlow.Phase.START_ENGINES


func _launch(game: GameFlow) -> bool:
	_set_joy_button(BUTTON_A, true)
	_set_joy_axis(AXIS_LEFT_Y, -1.0)
	var ticks := 0
	while game.phase != GameFlow.Phase.FREE_FLIGHT and ticks < DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	var airborne := game.phase == GameFlow.Phase.FREE_FLIGHT
	await _settle(24)
	_release_joypad()
	await _settle(4)
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


## Stands the pilot on each authored route anchor in order and waits for the
## Host's own route observation to accept it, ending in its ON_FOOT phase.
func _cross_outbound_route(player: PlayerController, host: EmberSurfaceLoopHost) -> bool:
	for anchor_key in ["egress_anchor", "staging_anchor"]:
		var route := host.get_return_status_snapshot().get("surface_route", {}) as Dictionary
		var anchor := route.get(anchor_key, Vector3.INF) as Vector3
		if not anchor.is_finite():
			return false
		player.teleport_to(Transform3D(player.global_basis, anchor + Vector3.UP * 0.3))
		var accepted := await _wait_for(
			func() -> bool:
				if anchor_key == "staging_anchor":
					return host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT
				return bool((host.get_snapshot().get("surface_route", {}) as Dictionary)
					.get("outbound_complete", false)),
			TRAILHEAD_TICK_BUDGET
		)
		if not accepted:
			return false
	return host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT


## The walkable floor directly below `point`, where a teleported pilot keeps
## their footing instead of dropping onto it.
func _ground_below(player: PlayerController, point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 2.0, point + Vector3.DOWN * 4.0, PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", Vector3.INF) as Vector3


func _available_trailhead(game: GameFlow) -> Area3D:
	for node in game.find_children("*", "EmberCalderaExpeditionInteractionBinding", true, false):
		var trailhead := node as Area3D
		if trailhead == null:
			continue
		var snapshot := trailhead.call(&"get_snapshot") as Dictionary
		if StringName(snapshot.get("offer_state", &"")) == &"available" \
				and bool(snapshot.get("pressable", false)):
			return trailhead
	return null


func _reboard(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
	) -> bool:
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not is_instance_valid(area):
		return false
	# Stand on the real ground three metres outboard of the boarding
	# point, facing the craft. The Host fails the visit the first tick the pilot
	# is not supported, so the placement must land on the floor, not above it.
	var boarding := craft.get_boarding_position()
	var outward := boarding - craft.global_position
	outward.y = 0.0
	outward = outward.normalized()
	var stand := _ground_below(player, boarding + outward * 3.0)
	if not stand.is_finite():
		return false
	player.teleport_to(Transform3D(Basis.looking_at(-outward, Vector3.UP), stand))
	await _settle(4)
	if not (area in player.get_nearby_interactables()):
		if not await _stick_walk_until(
			func() -> bool: return area in player.get_nearby_interactables(), 120
		):
			return false
	_check_controller_prompt(game.hud, "reboarding prompt")
	for _press in 12:
		await _tap_joy(BUTTON_X)
		await _settle(6)
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


# ------------------------------------------------------------- prompts ----


func _interaction_text(hud: GameHUD) -> String:
	var label := hud.get("_interaction_label") as Label
	return label.text if label != null else ""


## A visible prompt read while a gamepad is the prompt device names no key.
func _check_controller_prompt(hud: GameHUD, step: String) -> void:
	var family := StringName(hud.get_input_binding_report().get(
		"preferred_device_family", &""
	))
	var text := _interaction_text(hud)
	var leaked := PackedStringArray()
	for token in KEYBOARD_TOKENS:
		if text.contains(token):
			leaked.append(token)
	_check(
		InputGlyphResolver.GAMEPAD_FAMILIES.has(family) and leaked.is_empty(),
		"%s is presented for the controller (%s: %s)" % [step, family, text]
	)


# ---------------------------------------------------------------- input ----


func _dpad_down_to(target: Control, max_presses: int) -> bool:
	for _press in max_presses:
		if root.gui_get_focus_owner() == target:
			return true
		await _tap_joy(BUTTON_DPAD_DOWN)
	return root.gui_get_focus_owner() == target


func _stick_walk_until(predicate: Callable, tick_budget: int) -> bool:
	_set_joy_axis(AXIS_LEFT_Y, -1.0)
	var ticks := 0
	while not bool(predicate.call()) and ticks < tick_budget:
		await physics_frame
		ticks += 1
	_set_joy_axis(AXIS_LEFT_Y, 0.0)
	await _settle(4)
	return bool(predicate.call())


func _tap_joy(button_index: int) -> void:
	_set_joy_button(button_index, true)
	await physics_frame
	await process_frame
	_set_joy_button(button_index, false)
	await physics_frame
	await process_frame


func _set_joy_axis(axis_index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis_index
	event.axis_value = clampf(value, -1.0, 1.0)
	Input.parse_input_event(event)


func _set_joy_button(button_index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_joypad() -> void:
	for axis in [
		AXIS_LEFT_X, AXIS_LEFT_Y, AXIS_RIGHT_X, AXIS_RIGHT_Y,
		AXIS_LEFT_TRIGGER, AXIS_RIGHT_TRIGGER,
	]:
		_set_joy_axis(axis, 0.0)
	for button in [
		BUTTON_A, BUTTON_B, BUTTON_X, BUTTON_START,
		BUTTON_DPAD_UP, BUTTON_DPAD_DOWN, BUTTON_DPAD_LEFT,
	]:
		_set_joy_button(button, false)


func _settle(ticks: int) -> void:
	for _tick in ticks:
		await physics_frame
		await process_frame


func _wait_for(predicate: Callable, tick_budget: int) -> bool:
	for _index in tick_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _tear_down(game: Node) -> void:
	_release_joypad()
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	for _teardown_frame in 12:
		await process_frame
		await physics_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("CONTROLLER_ONLY_PLANETARY_EXPEDITION_TEST: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("CONTROLLER_ONLY_PLANETARY_EXPEDITION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("CONTROLLER_ONLY_PLANETARY_EXPEDITION_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
