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
##    the prompt device. Default keyboard copy remains unchanged, while rebound
##    desktop landing, thrust and pause controls refresh retained prompts and objectives.
## 3. Tractor boarding help follows remapped movement, brake aliases and exit,
##    including missing bindings and retained objective refresh on device changes.

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
	await _test_keyboard_landing_binding_prompts(hud)
	await _test_keyboard_navigation_binding_prompts(hud)
	await _test_tractor_binding_prompts(hud)
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
	# Navigate again before the refresh's deferred queue can drain. The old
	# restore captured the site button and undid this newer choice of Back.
	await _tap_key(KEY_UP)
	var site := hud.find_child("PlanetaryDestinationAction_relay_site", true, false) as Button
	var ember := hud.find_child("PlanetaryDestinationAction_ember_moon", true, false) as Button
	_check(root.gui_get_focus_owner() == site, "keyboard Up selects the briefing row")
	(refreshed.destinations[0] as Dictionary).travel_summary = "Second authored travel briefing."
	_check(hud.set_planetary_destination_snapshot(refreshed), "a second catalog refresh is accepted")
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == back,
		"refresh cannot undo controller navigation received before the deferred queue drains")

	await _tap_key(KEY_UP)
	var disabled := refreshed.duplicate(true)
	(disabled.sector_sites[0] as Dictionary).action_enabled = false
	disabled.available_sector_site_ids = PackedStringArray()
	_check(hud.set_planetary_destination_snapshot(disabled), "the focused briefing action can become unavailable")
	await process_frame
	_check(root.gui_get_focus_owner() == ember and site.disabled,
		"a disabled focused action falls back to the first enabled destination")

	_check(hud.set_planetary_destination_snapshot(refreshed), "the briefing action becomes available again")
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == site, "controller navigation returns to the available briefing")
	var removed := refreshed.duplicate(true)
	removed.sector_sites = []
	removed.sector_site_count = 0
	removed.available_sector_site_ids = PackedStringArray()
	_check(hud.set_planetary_destination_snapshot(removed), "the focused briefing row can leave the catalog")
	await process_frame
	_check(root.gui_get_focus_owner() == ember,
		"a removed focused action falls back to the first enabled destination")
	await _tap_joy(BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == back, "Back remains reachable after row removal")
	await _tap_joy(BUTTON_A)
	var page := hud.get("_planetary_destination_page") as Control
	var main_page := hud.get("_pause_main_page") as Control
	var destinations := hud.find_child("PlanetaryDestinationOpenButton", true, false) as Button
	_check(
		main_page.visible and not page.visible
			and root.gui_get_focus_owner() == destinations,
		"controller A after refresh activates the chosen Back action"
	)
	_check(hud.set_planetary_destination_snapshot(refreshed), "the hidden board accepts a later refresh")
	await process_frame
	_check(root.gui_get_focus_owner() == destinations,
		"a hidden board refresh leaves the current pause-page focus alone")
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


func _test_keyboard_landing_binding_prompts(hud: GameHUD) -> void:
	var interaction := hud.get("_interaction_label") as Label
	var objective := hud.get("_objective_label") as Label
	var toast_detail := hud.get("_toast_detail") as Label
	var original: InputBindingProfile = hud.get("_input_binding_profile").duplicate_profile()
	var profile := original.duplicate_profile()
	var gamepad_bindings: Array[Dictionary] = []
	for binding: Dictionary in original.get_bindings(&"landing_assist"):
		if binding.device == &"gamepad":
			gamepad_bindings.append(binding)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_F
	keyboard.pressed = true
	root.push_input(keyboard)
	await process_frame
	hud.set_interaction(LANDING_ASSIST_PROMPT)
	hud.set_objective("Return to Mudds, then press L to dock.", "RETURN")
	var rebound: Array[Dictionary] = gamepad_bindings.duplicate(true)
	rebound.append({"device": &"keyboard", "type": &"key", "physical_keycode": KEY_T})
	profile.set_bindings(&"landing_assist", rebound)
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check(
		interaction.text == "[ T ]  ENGAGE LANDING ASSIST"
			and objective.text == "Return to Mudds, then press T to dock.",
		"a landing remap refreshes retained flight interaction and objective without caller republication"
	)
	hud.set_interaction(AURORA_LANDED_PROMPT)
	hud.toast("Aurora landing", AURORA_LANDING_TOAST)
	_check(
		interaction.text == "[ T ]  LAND AT AURORA PAD  //  ESC: RETURN TO MUDDS"
			and toast_detail.text.ends_with("press T"),
		"planetary landing and toast copy use the desktop binding without changing pause guidance"
	)
	for key_and_label: Array in [[KEY_K, "K"], [KEY_CTRL, "Ctrl"]]:
		rebound[-1].physical_keycode = key_and_label[0]
		profile.set_bindings(&"landing_assist", rebound)
		hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
		_check(
			interaction.text.begins_with("[ %s ]" % key_and_label[1])
				and objective.text == "Return to Mudds, then press %s to dock." % key_and_label[1],
			"later snapshots refresh retained landing copy, including an individually bound modifier key"
		)
	hud._on_controller_glyph_family_selected(1)
	var controller_landing := hud.get_action_prompt(&"landing_assist")
	_check(
		interaction.text.begins_with("[ %s ]" % controller_landing)
			and not interaction.text.contains("ESC:"),
		"desktop remaps preserve the existing gamepad landing and pause prompts"
	)
	hud._on_controller_glyph_family_selected(0)
	root.push_input(keyboard)
	await process_frame
	_check(interaction.text.begins_with("[ Ctrl ]"), "returning to keyboard refreshes retained planetary copy")
	profile.set_bindings(&"interact", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB}])
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	hud.set_interaction("[ E ]  ACCESS DESTINATION BOARD")
	_check(interaction.text == "[ Tab ]  ACCESS DESTINATION BOARD", "Interact remapping remains independent of landing copy")
	hud.set_interaction(AURORA_LANDED_PROMPT)
	for bindings: Array in [[], gamepad_bindings]:
		profile.set_bindings(&"landing_assist", bindings)
		hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
		_check(
			interaction.text.begins_with("[ Unbound Input ]")
				and objective.text == "Return to Mudds, then press Unbound Input to dock.",
			"missing desktop landing bindings never advertise L or a controller-only fallback"
		)
	profile.set_bindings(&"landing_assist", [{"device": &"mouse", "type": &"mouse_button", "button_index": MOUSE_BUTTON_MIDDLE}])
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check(interaction.text.begins_with("[ Middle Mouse ]"), "desktop landing copy resolves an actual mouse binding")
	hud.set_interaction("press Left Stick // press Lander // PILOT L")
	_check(interaction.text == "press Left Stick // press Lander // PILOT L", "landing replacement leaves unrelated words intact")
	hud.set_interaction(LANDING_ASSIST_PROMPT)
	hud.set_settings_snapshot({"input_binding_profile": original.to_dictionary()})
	_check(
		interaction.text == LANDING_ASSIST_PROMPT
			and objective.text == "Return to Mudds, then press L to dock.",
		"restoring authored bindings restores exact default keyboard copy on retained surfaces"
	)


func _test_keyboard_navigation_binding_prompts(hud: GameHUD) -> void:
	var interaction := hud.get("_interaction_label") as Label
	var objective := hud.get("_objective_label") as Label
	var original: InputBindingProfile = hud.get("_input_binding_profile").duplicate_profile()
	var profile := original.duplicate_profile()
	var thrust_and_return := THRUST_PROMPT + "  //  ESC: RETURN TO MUDDS"
	hud.set_interaction(thrust_and_return)
	hud.set_objective(AURORA_LANDED_OBJECTIVE, "AURORA EXPEDITION")
	for action_and_key: Array in [
		[&"move_forward", KEY_I], [&"move_back", KEY_K], [&"pause", KEY_F8],
	]:
		var bindings: Array[Dictionary] = []
		for binding: Dictionary in original.get_bindings(action_and_key[0]):
			if binding.device == &"gamepad":
				bindings.append(binding)
		bindings.append({"device": &"keyboard", "type": &"key", "physical_keycode": action_and_key[1]})
		profile.set_bindings(action_and_key[0], bindings)
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check(
		interaction.text == "[ I / K ]  APPLY THRUST  //  F8: RETURN TO MUDDS"
			and objective.text == "Explore Aurora, or open F8 → Destination Board to return to Mudds",
		"desktop thrust and pause remaps refresh retained interaction/objective copy together"
	)
	hud.set_interaction(AURORA_LANDED_PROMPT)
	_check(
		interaction.text == "[ L ]  LAND AT AURORA PAD  //  F8: RETURN TO MUDDS",
		"remapped planetary pause guidance preserves unchanged authored landing copy"
	)
	hud._on_controller_glyph_family_selected(1)
	var controller_pause := hud.get_action_prompt(&"pause")
	_check(
		interaction.text.ends_with("%s: RETURN TO MUDDS" % controller_pause)
			and objective.text.contains("%s → Destination Board" % controller_pause),
		"a device switch still renders controller pause guidance from the retained source"
	)
	hud.set_interaction(thrust_and_return)
	var movement_actions: Array[StringName] = [&"move_forward", &"move_back"]
	_check(
		interaction.text.begins_with("[ %s ]" % hud.call("_action_prompts", movement_actions)),
		"desktop movement remaps leave the controller thrust glyph unchanged"
	)
	hud._on_controller_glyph_family_selected(0)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_F
	keyboard.pressed = true
	root.push_input(keyboard)
	await process_frame
	_check(
		interaction.text == "[ I / K ]  APPLY THRUST  //  F8: RETURN TO MUDDS"
			and objective.text.contains("F8 → Destination Board"),
		"returning to keyboard refreshes retained thrust and pause remaps"
	)
	var pause_bindings := profile.get_bindings(&"pause")
	pause_bindings[-1].physical_keycode = KEY_F9
	profile.set_bindings(&"pause", pause_bindings)
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check(
		interaction.text.ends_with("F9: RETURN TO MUDDS")
			and objective.text.contains("F9 → Destination Board"),
		"a later pause snapshot refreshes both retained surfaces without republication"
	)
	profile.set_bindings(&"move_forward", [])
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check(interaction.text.begins_with("[ Unbound Input / K ]"), "a missing forward binding remains explicit beside the bound back direction")
	for action: StringName in [&"move_back", &"pause"]:
		var gamepad_only: Array[Dictionary] = []
		for binding: Dictionary in original.get_bindings(action):
			if binding.device == &"gamepad":
				gamepad_only.append(binding)
		profile.set_bindings(action, gamepad_only)
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check(
		interaction.text == "[ Unbound Input ]  APPLY THRUST  //  Unbound Input: RETURN TO MUDDS"
			and objective.text.contains("Unbound Input → Destination Board"),
		"unbound desktop thrust/pause never advertises authored keys or controller-only fallbacks"
	)
	hud.set_settings_snapshot({"input_binding_profile": original.to_dictionary()})
	_check(
		interaction.text == thrust_and_return and objective.text == AURORA_LANDED_OBJECTIVE,
		"restoring defaults restores exact authored thrust/pause copy on both retained surfaces"
	)


## The production boarding flow passes these exact strings to the HUD. Exercise
## the common presenter here without changing tractor input or boarding authority.
func _test_tractor_binding_prompts(hud: GameHUD) -> void:
	var source_objective := "Drive the tow tractor anywhere on the deck — press E to hop out"
	var source_toast := "W / S drive  •  A / D steer  •  SPACE brake  •  E to hop out"
	var objective := hud.get("_objective_label") as Label
	var toast_detail := hud.get("_toast_detail") as Label
	var original: InputBindingProfile = hud.get("_input_binding_profile").duplicate_profile()
	var defaults: InputBindingProfile = hud.get("_input_binding_defaults").duplicate_profile()
	var profile := defaults.duplicate_profile()
	_apply_compatible_tractor_profile(hud, defaults)
	hud.set_objective(source_objective, "TOW TRACTOR")
	hud.toast("Tow tractor running", source_toast)
	_check(objective.text == source_objective and toast_detail.text == source_toast,
		"default desktop tractor boarding copy remains exact")
	for action_and_key: Array in [
		[&"move_forward", KEY_I], [&"move_back", KEY_K],
		[&"move_left", KEY_J], [&"move_right", KEY_O],
		[&"brake", KEY_B], [&"jump", KEY_N], [&"interact", KEY_T],
	]:
		var bindings: Array[Dictionary] = []
		for binding: Dictionary in defaults.get_bindings(action_and_key[0]):
			if binding.device == &"gamepad":
				bindings.append(binding)
		bindings.append({"device": &"keyboard", "type": &"key", "physical_keycode": action_and_key[1]})
		profile.set_bindings(action_and_key[0], bindings)
	_apply_compatible_tractor_profile(hud, profile)
	hud.toast("Tow tractor running", source_toast)
	_check(objective.text.ends_with("press T to hop out")
		and toast_detail.text == "I / K drive  •  J / O steer  •  B / N brake  •  T to hop out",
		"tractor movement, brake aliases and exit help use their actual rebound desktop controls")
	profile.set_bindings(&"brake", [])
	_apply_compatible_tractor_profile(hud, profile)
	hud.toast("Tow tractor running", source_toast)
	_check(toast_detail.text.contains("N brake") and not toast_detail.text.contains("Unbound Input"),
		"a bound jump alias can brake without advertising the missing brake alias")
	profile.set_bindings(&"brake", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_B}])
	profile.set_bindings(&"jump", [])
	_apply_compatible_tractor_profile(hud, profile)
	hud.toast("Tow tractor running", source_toast)
	_check(toast_detail.text.contains("B brake") and not toast_detail.text.contains("Unbound Input"),
		"a bound brake action remains sufficient when jump is unbound")
	profile.set_bindings(&"brake", [])
	profile.set_bindings(&"move_forward", [])
	profile.set_bindings(&"interact", [])
	_apply_compatible_tractor_profile(hud, profile)
	hud.toast("Tow tractor running", source_toast)
	_check(objective.text.ends_with("press Unbound Input to hop out")
		and toast_detail.text == "Unbound Input / K drive  •  J / O steer  •  Unbound Input brake  •  Unbound Input to hop out",
		"missing required directions, both brake aliases and exit never advertise obsolete keys")
	profile.set_bindings(&"interact", [{"device": &"mouse", "type": &"mouse_button", "button_index": MOUSE_BUTTON_MIDDLE}])
	_apply_compatible_tractor_profile(hud, profile)
	_check(objective.text.ends_with("press Middle Mouse to hop out"),
		"a mouse exit remap refreshes the retained tractor objective")
	_apply_compatible_tractor_profile(hud, defaults)
	hud._on_controller_glyph_family_selected(1)
	hud.toast("Tow tractor running", source_toast)
	var exit_glyph := hud.get_action_prompt(&"interact")
	_check(objective.text.ends_with("press %s to hop out" % exit_glyph)
		and not toast_detail.text.contains("W / S drive")
		and not toast_detail.text.contains("A / D steer")
		and not toast_detail.text.contains("SPACE brake")
		and toast_detail.text.ends_with("%s to hop out" % exit_glyph),
		"switching devices refreshes the retained objective and new toast with controller inputs")
	profile = defaults.duplicate_profile()
	for action_and_key: Array in [[&"interact", KEY_T], [&"brake", KEY_B], [&"jump", KEY_N]]:
		profile.set_bindings(action_and_key[0], [{"device": &"keyboard", "type": &"key", "physical_keycode": action_and_key[1]}])
	_apply_compatible_tractor_profile(hud, profile)
	hud.toast("Tow tractor running", source_toast)
	_check(objective.text.ends_with("press Unbound Input to hop out")
		and toast_detail.text.contains("Unbound Input brake")
		and toast_detail.text.ends_with("Unbound Input to hop out"),
		"controller-only missing bindings do not fall back onto desktop keys")
	hud._on_controller_glyph_family_selected(0)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_F
	keyboard.pressed = true
	root.push_input(keyboard)
	await process_frame
	_check(objective.text.ends_with("press T to hop out"),
		"returning to desktop refreshes the retained objective without caller republication")
	_apply_compatible_tractor_profile(hud, defaults)
	hud.toast("Tow tractor running", source_toast)
	_check(objective.text == source_objective and toast_detail.text == source_toast,
		"restoring defaults restores exact authored tractor copy")
	hud.toast("Unrelated text", "E engine • SPACE station • W / S sensor • A / D dish")
	_check(toast_detail.text == "E engine • SPACE station • W / S sensor • A / D dish",
		"contextual tractor tokens leave unrelated letters and words intact")
	_apply_compatible_tractor_profile(hud, original)


## Never let a rejected fixture silently leave the HUD exercising old bindings.
func _apply_compatible_tractor_profile(hud: GameHUD, profile: InputBindingProfile) -> void:
	var service: InputRebindService = hud.get("_input_rebind_service")
	var compatible := service.is_profile_compatible_with_defaults(profile)
	_check(compatible, "tractor fixture is compatible with the complete authored action inventory")
	if not compatible:
		return
	hud.set_settings_snapshot({"input_binding_profile": profile.to_dictionary()})
	_check((hud.get("_input_binding_profile") as InputBindingProfile).to_dictionary() == profile.to_dictionary(),
		"the HUD accepts the intended tractor fixture before presentation assertions")


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
