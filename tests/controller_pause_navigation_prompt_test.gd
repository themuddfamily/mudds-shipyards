extends SceneTree

## HUD-level controller-only proof for the planetary expedition UI surfaces.
##
## 1. The Destination Board is opened, traversed and left with pad events only:
##    D-pad down walks every enabled world row, the enabled sector-site row and
##    Back; controller B returns to the pause page on the Destination Board
##    button; B on the main pause page does not resume (so it cannot leak into
##    flight as a barrel roll); Start still closes the overlay.
## 2. Keyboard-authored expedition copy ("[ L ]", "ESC:", "Esc →", "press L",
##    "[ W/S / LEFT STICK ]") shows the live controller glyph while a gamepad is
##    the prompt device, and is left byte-for-byte unchanged for keyboard.

const HudType := preload("res://scripts/ui/hud.gd")

const BUTTON_A := 0
const BUTTON_B := 1
const BUTTON_BACK := 4
const BUTTON_START := 6
const BUTTON_DPAD_DOWN := 12

const AURORA_LANDED_PROMPT := "[ L ]  LAND AT AURORA PAD  //  ESC: RETURN TO MUDDS"
const AURORA_LANDED_OBJECTIVE := (
	"Explore Aurora, or open Esc → Destination Board to return to Mudds"
)
const AURORA_LANDING_TOAST := "Approach the pad slowly from above, then press L"
const THRUST_PROMPT := "[ W/S / LEFT STICK ]  APPLY THRUST"
const LANDING_ASSIST_PROMPT := "[ L / D-PAD LEFT ]  ENGAGE LANDING ASSIST"

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	await _test_intro_server_browser_controller_back(hud)
	hud.set("_started", true)
	await _test_destination_board_controller_path(hud)
	await _test_destination_board_refresh_keeps_back_focus(hud)
	await _test_server_browser_escape_steps_back(hud)
	await _test_controls_overlay_toggle_keeps_pause_focus(hud)
	await _test_controller_prompt_glyphs(hud)
	hud.set_paused(false)
	paused = false
	hud.queue_free()
	await process_frame
	_finish()


func _test_destination_board_controller_path(hud: GameHUD) -> void:
	_check(
		hud.set_planetary_destination_snapshot(_destination_snapshot()),
		"the HUD accepts a catalog snapshot with two worlds and one reachable sector site"
	)
	_check(hud.open_planetary_destination_board(), "the Destination Board opens as a pause page")
	await process_frame
	var ember := hud.find_child("PlanetaryDestinationAction_ember_moon", true, false) as Button
	var site := hud.find_child("PlanetaryDestinationAction_relay_site", true, false) as Button
	var back := hud.find_child("PlanetaryDestinationBackButton", true, false) as Button
	_check(
		ember != null and site != null and back != null,
		"the board renders the Ember action, the site briefing action and Back"
	)
	if ember == null or site == null or back == null:
		return
	_check(root.gui_get_focus_owner() == ember, "opening the board focuses the first enabled world")
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(
		root.gui_get_focus_owner() == site,
		"D-pad down reaches the sector-site row instead of skipping to Back"
	)
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == back, "D-pad down then reaches Back")
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == back, "Back is the end of the chain, not a focus escape")

	var page := hud.get("_planetary_destination_page") as Control
	var main_page := hud.get("_pause_main_page") as Control
	var pause := hud.get("_pause") as Control
	await _tap_joy(BUTTON_B)
	var destinations := hud.find_child("PlanetaryDestinationOpenButton", true, false) as Button
	_check(
		pause.visible and main_page.visible and not page.visible
			and root.gui_get_focus_owner() == destinations,
		"controller B returns from the board to the pause page on the Destination Board button"
	)
	await _tap_joy(BUTTON_B)
	_check(
		pause.visible and main_page.visible and paused,
		"controller B on the main pause page does not resume the game"
	)
	await _tap_joy(BUTTON_A)
	_check(
		page.visible and root.gui_get_focus_owner() == ember,
		"controller A on the Destination Board button reopens the board on Ember"
	)
	await _tap_joy(BUTTON_START)
	_check(main_page.visible and pause.visible, "Start still steps back from the board")
	await _tap_joy(BUTTON_START)
	_check(not pause.visible and not paused, "Start still closes the pause overlay")


## A changed catalog can arrive while the controller player is leaving the board.
func _test_destination_board_refresh_keeps_back_focus(hud: GameHUD) -> void:
	_check(hud.open_planetary_destination_board(), "the Destination Board reopens for catalog refresh")
	await process_frame
	await _tap_joy(BUTTON_DPAD_DOWN)
	await _tap_joy(BUTTON_DPAD_DOWN)
	var back := hud.find_child("PlanetaryDestinationBackButton", true, false) as Button
	_check(root.gui_get_focus_owner() == back, "controller navigation chooses Back before refresh")
	var refreshed := _destination_snapshot()
	(refreshed.destinations[0] as Dictionary).travel_summary = "Updated authored travel briefing."
	_check(hud.set_planetary_destination_snapshot(refreshed), "the live catalog refresh is accepted")
	await process_frame
	await process_frame
	_check(
		root.gui_get_focus_owner() == back,
		"catalog refresh preserves Back instead of moving controller focus onto travel"
	)
	await _tap_joy(BUTTON_A)
	var page := hud.get("_planetary_destination_page") as Control
	var main_page := hud.get("_pause_main_page") as Control
	var destinations := hud.find_child("PlanetaryDestinationOpenButton", true, false) as Button
	_check(
		main_page.visible and not page.visible
			and root.gui_get_focus_owner() == destinations,
		"controller A after refresh activates the chosen Back action"
	)
	hud.set_paused(false)
	paused = false
	await process_frame


## 3. Controller B leaves the Server Browser opened from the startup menu, as it
##    leaves every other overlay page; before the fix only Start/Esc closed it.
func _test_intro_server_browser_controller_back(hud: GameHUD) -> void:
	var pause := hud.get("_pause") as Control
	var intro_browser := hud.find_child("IntroServerBrowserButton", true, false) as Button
	_check(hud.open_intro_server_browser(), "the startup menu opens the Server Browser")
	await process_frame
	await _tap_joy(BUTTON_B)
	_check(
		not hud.is_intro_server_browser_open() and not pause.visible
			and root.gui_get_focus_owner() == intro_browser,
		"controller B closes the startup Server Browser back to its menu button"
	)


## 4. Keyboard Esc on the pause Server Browser steps back to the pause page like
##    every other sub-page, instead of resuming flight from inside the browser.
func _test_server_browser_escape_steps_back(hud: GameHUD) -> void:
	var pause := hud.get("_pause") as Control
	var main_page := hud.get("_pause_main_page") as Control
	var browser_page := hud.get("_server_browser_page") as Control
	hud.set_paused(true)
	await process_frame
	var browser_button := hud.find_child("ServerBrowserButton", true, false) as Button
	browser_button.emit_signal(&"pressed")
	await process_frame
	_check(browser_page.visible, "the pause Server Browser opens")
	await _tap_key(KEY_ESCAPE)
	_check(
		pause.visible and paused and main_page.visible and not browser_page.visible
			and root.gui_get_focus_owner() == browser_button,
		"Esc on the pause Server Browser returns to the pause page without resuming"
	)
	hud.set_paused(false)
	paused = false
	await process_frame


## 5. The controls overlay (F1 / pad Back) sits under the pause dimmer, so its
##    toggle must not take controller focus off the pause menu.
func _test_controls_overlay_toggle_keeps_pause_focus(hud: GameHUD) -> void:
	(hud.get("_hud") as Control).visible = true
	var help := hud.get("_help_panel") as Control
	help.visible = false
	hud.set_paused(true)
	await process_frame
	var resume := hud.find_child("ResumeButton", true, false) as Button
	await _tap_joy(BUTTON_BACK)
	_check(
		not help.visible and root.gui_get_focus_owner() == resume,
		"pad Back while paused leaves focus on Resume instead of the covered overlay"
	)
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(
		root.gui_get_focus_owner() != null and hud.get("_pause_main_page").is_ancestor_of(
			root.gui_get_focus_owner()
		),
		"D-pad navigation still moves within the pause menu afterwards"
	)
	hud.set_paused(false)
	paused = false
	await process_frame
	await _tap_joy(BUTTON_BACK)
	_check(help.visible, "pad Back still toggles the controls overlay in flight")
	await _tap_joy(BUTTON_BACK)
	_check(not help.visible, "pad Back closes the controls overlay again in flight")


func _test_controller_prompt_glyphs(hud: GameHUD) -> void:
	var interaction := hud.get("_interaction_label") as Label
	var objective := hud.get("_objective_label") as Label
	var toast_detail := hud.get("_toast_detail") as Label
	hud._on_controller_glyph_family_selected(0)
	# Keyboard family: authored copy is untouched.
	var restore_keyboard := InputEventKey.new()
	restore_keyboard.physical_keycode = KEY_F
	restore_keyboard.pressed = true
	root.push_input(restore_keyboard)
	await process_frame
	hud.set_interaction(AURORA_LANDED_PROMPT)
	hud.set_objective(AURORA_LANDED_OBJECTIVE, "AURORA EXPEDITION")
	hud.toast("Aurora landing", AURORA_LANDING_TOAST)
	_check(
		interaction.text == AURORA_LANDED_PROMPT
			and objective.text == AURORA_LANDED_OBJECTIVE
			and toast_detail.text == AURORA_LANDING_TOAST,
		"keyboard prompts keep their exact authored copy"
	)
	hud.set_interaction(THRUST_PROMPT)
	_check(interaction.text == THRUST_PROMPT, "keyboard thrust prompt is unchanged")

	# Gamepad family: the same copy now names controller inputs, and the retained
	# interaction/objective copy re-renders on the device switch itself.
	hud.set_interaction(AURORA_LANDED_PROMPT)
	hud._on_controller_glyph_family_selected(1)
	var landing := str(hud.get_action_prompt(&"landing_assist"))
	var pause_glyph := str(hud.get_action_prompt(&"pause"))
	_check(
		not interaction.text.contains("[ L ]")
			and not interaction.text.contains("ESC:")
			and interaction.text.contains("[ %s ]" % landing)
			and interaction.text.contains("%s: RETURN TO MUDDS" % pause_glyph)
			and not objective.text.contains("Esc →")
			and objective.text.contains("%s → Destination Board" % pause_glyph),
		"a device switch re-renders the retained Aurora prompt and objective with controller glyphs (%s | %s)"
			% [interaction.text, objective.text]
	)
	hud.toast("Aurora landing", AURORA_LANDING_TOAST)
	_check(
		not toast_detail.text.ends_with("press L")
			and toast_detail.text.ends_with("press %s" % landing),
		"the Aurora landing toast names the controller landing input"
	)
	hud.set_interaction(THRUST_PROMPT)
	_check(
		not interaction.text.contains("W/S")
			and interaction.text.ends_with("APPLY THRUST"),
		"the thrust prompt shows the controller stick glyph (%s)" % interaction.text
	)
	hud.set_interaction(LANDING_ASSIST_PROMPT)
	_check(
		interaction.text == "[ %s ]  ENGAGE LANDING ASSIST" % landing,
		"the landing-assist prompt shows only the controller binding (%s)" % interaction.text
	)
	hud.set_interaction("[ E ]  BEGIN CALDERA RIM SURVEY")
	_check(
		not interaction.text.begins_with("[ E ]")
			and interaction.text.contains("BEGIN CALDERA RIM SURVEY"),
		"errand trailhead prompts keep the live controller interact glyph"
	)
	hud._on_controller_glyph_family_selected(0)


func _destination_snapshot() -> Dictionary:
	var ember := _row(
		&"ember_moon", "Ember Moon", true, true, &"ember_route", "ENGAGE CRUISE"
	)
	var authored := _row(
		&"cinder_reach", "Cinder Reach", false, false, &"", "ROUTE UNAVAILABLE"
	)
	var site := _row(
		&"relay_site", "Relay Site", true, true, &"relay_site_route", "SHOW BRIEFING"
	)
	return {
		"schema_version": GameHUD.PLANETARY_DESTINATION_SCHEMA_VERSION,
		"catalog_id": GameHUD.PLANETARY_DESTINATION_CATALOG_ID,
		"destination_count": 2,
		"available_destination_ids": PackedStringArray(["ember_moon"]),
		"destinations": [ember, authored],
		"sector_site_count": 1,
		"available_sector_site_ids": PackedStringArray(["relay_site"]),
		"sector_sites": [site],
		"authority": {"travel": false, "route": false},
	}


func _row(
	destination_id: StringName,
	display_name: String,
	route_available: bool,
	action_enabled: bool,
	route_id: StringName,
	action_text: String,
) -> Dictionary:
	return {
		"destination_id": destination_id,
		"display_name": display_name,
		"sector_id": &"mudds_sector",
		"environment_id": &"airless",
		"environment_text": "AIRLESS",
		"evidence_status": &"authored",
		"route_id": route_id,
		"route_available": route_available,
		"orbital_distance_meters": 8000000.0,
		"distance_text": "8,000 KM",
		"travel_summary": "Authored test row.",
		"status_id": &"ready" if action_enabled else &"unavailable",
		"status_text": "READY" if action_enabled else "UNAVAILABLE",
		"action_enabled": action_enabled,
		"engagement_requested": false,
		"action_text": action_text,
		"presentation_only": true,
	}


func _tap_joy(button_index: int) -> void:
	var pressed_event := InputEventJoypadButton.new()
	pressed_event.button_index = button_index
	pressed_event.pressed = true
	root.push_input(pressed_event)
	await process_frame
	var released_event := InputEventJoypadButton.new()
	released_event.button_index = button_index
	released_event.pressed = false
	root.push_input(released_event)
	await process_frame


func _tap_key(keycode: Key) -> void:
	var pressed_event := InputEventKey.new()
	pressed_event.physical_keycode = keycode
	pressed_event.keycode = keycode
	pressed_event.pressed = true
	root.push_input(pressed_event)
	await process_frame
	var released_event := InputEventKey.new()
	released_event.physical_keycode = keycode
	released_event.keycode = keycode
	released_event.pressed = false
	root.push_input(released_event)
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("CONTROLLER_PAUSE_NAVIGATION_PROMPT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
