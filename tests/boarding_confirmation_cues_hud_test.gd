extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const Registry := preload("res://scripts/ships/fleet_role_registry.gd")
const PresenterType := preload("res://scripts/ui/boarding_confirmation_hud_presenter.gd")
const CompositionType := preload("res://scripts/ui/boarding_confirmation_hud_composition.gd")
const DEFINITION_PATHS := [
	"torrent_provisional", "arrow_provisional", "jovian_provisional",
	"zenith_b7_observed", "halyard_new_design", "cinder_cargo_hauler_new_design",
	"cinder_long_range_bomber_new_design", "cinder_light_interceptor_new_design",
	"bulwark_new_design",
]
const CAPTURE_DIR := "user://screenshots/boarding_confirmation_states"

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []
var _captured_card_pixels: Array[PackedByteArray] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await _run_production_capture()
		return
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	# Begin through the real HUD transition so the retained card has a visible
	# production canvas for the Forward+ state captures.
	# Settle the existing intro immediately before measuring live HUD layout.
	hud.set_reduced_motion(true)
	hud.call(&"_begin")
	_check(await _wait_until(func() -> bool:
		var live_hud := hud.get("_hud") as Control
		return live_hud != null and live_hud.is_visible_in_tree(), 30),
		"real intro callback exposes the live HUD before layout checks")
	# The production HUD start path captures the cursor. Automation must not
	# hold a pointer grab, and on the shared display the graphical matrix runs
	# on a retained grab makes a concurrent suite's own capture report
	# "NO GRAB". Nothing below reads the cursor, so release it immediately.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_captions_enabled(true)
	hud.bind_caption_event_submitter(Callable(self, &"_capture_request"))
	_check(hud.present_semantic_audio_cue(&"boarding_confirmed", &"boarding", 0.3, Vector3.ZERO), "boarding cue reaches captions")
	_check(hud.present_semantic_audio_cue(&"disembark_confirmed", &"boarding", 0.3, Vector3.ZERO), "disembark cue reaches captions")
	_check(_requests.size() == 2, "both confirmation cues produce requests")
	_check(str(_requests[0].text).contains("Boarding confirmed"), "boarding label is concise")
	_check(str(_requests[1].text).contains("Disembark confirmed"), "disembark label is concise")
	hud.set_captions_enabled(false)
	_check(not hud.present_semantic_audio_cue(&"boarding_confirmed", &"boarding", 0.3, Vector3.ZERO), "caption preference gates confirmations")
	await _check_boarding_status_card(hud)
	await _check_fleet_choice_readability(hud)
	_check_choice_negatives()
	_check_bomber_negatives()
	hud.queue_free()
	await process_frame
	if _failures.is_empty() and ("--capture-light-choice" in OS.get_cmdline_user_args() or "--capture-bomber-choice" in OS.get_cmdline_user_args()):
		# The opt-in images extend this complete suite; they never replace it.
		await _run_choice_capture()
		return
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_CUES_HUD_TEST_OK (%d assertions)" % _assertions)
		_release_inputs()
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	_release_inputs()
	quit(1)


func _run_production_capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var hud := game.hud as GameHUD
	hud.set_reduced_motion(true)
	var start_event := InputEventAction.new()
	start_event.action = &"interact"
	start_event.pressed = true
	hud._unhandled_input(start_event)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.APPROACH_SHIP, 30),
		"production title starts the real shift",
	)
	var intro := hud.get("_intro") as Control
	var live_hud := hud.get("_hud") as Control
	var brand := hud.find_child("BrandBlock", true, false) as Control
	var objective := hud.find_child("ObjectivePanel", true, false) as Control
	_check(
		intro != null and not intro.visible and live_hud != null and live_hud.visible
		and brand != null and brand.is_visible_in_tree()
		and objective != null and objective.is_visible_in_tree(),
		"capture rejects title-screen or hidden-HUD frames",
	)
	var composition := CompositionType.new()
	_check(bool(composition.attach(hud).get("accepted", false)), "capture attaches through the public retained-card API")
	var states: Array[Dictionary] = [
		{"state": &"approach", "craft_name": "Torrent", "generation": 1},
		{"state": &"available", "craft_name": "Torrent", "generation": 2},
		{"state": &"reserved", "craft_name": "Torrent", "generation": 3, "reservation_retained": true},
		{"state": &"boarding", "craft_name": "Torrent", "generation": 4, "reservation_retained": true, "transition_busy": true},
		{"state": &"seated", "craft_name": "Torrent", "generation": 5, "player_seated": true},
		{"state": &"disembarking", "craft_name": "Torrent", "generation": 6, "player_seated": true, "transition_busy": true},
		{"state": &"rejected", "craft_name": "Torrent", "generation": 7, "reason": &"seat_reserved"},
	]
	for index in states.size():
		var snapshot := states[index]
		var applied := composition.apply_snapshot(snapshot)
		_check(bool(applied.get("accepted", false)), "capture drives reachable %s through the public composition" % snapshot.state)
		var view := ((composition.get_snapshot().adapter as Dictionary).view as Dictionary)
		await _capture_if_requested(hud, "%02d_%s" % [index + 1, snapshot.state], view)
	composition.detach()
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_CAPTURE_OK")
		_release_inputs()
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	_release_inputs()
	quit(1)


func _capture_request(request: Dictionary) -> bool:
	_requests.append(request.duplicate(true))
	return true


func _check_boarding_status_card(hud: Object) -> void:
	var composition := CompositionType.new()
	_check(bool(composition.attach(hud).get("accepted", false)), "boarding card composition attaches to existing HUD card")
	var states: Array[Dictionary] = [
		{"state": &"approach", "craft_name": "Torrent", "generation": 1},
		{"state": &"available", "craft_name": "Torrent", "generation": 2},
		{"state": &"reserved", "craft_name": "Torrent", "generation": 3, "reservation_retained": true},
		{"state": &"boarding", "craft_name": "Torrent", "generation": 4, "reservation_retained": true, "transition_busy": true},
		{"state": &"seated", "craft_name": "Torrent", "generation": 5, "player_seated": true},
		{"state": &"disembarking", "craft_name": "Torrent", "generation": 6, "player_seated": true, "transition_busy": true},
		{"state": &"rejected", "craft_name": "Torrent", "generation": 7, "reason": &"seat_reserved"},
	]
	for index in states.size():
		var state := states[index]
		var applied := composition.apply_snapshot(state)
		_check(bool(applied.get("accepted", false)), "reachable %s snapshot renders" % state.state)
	var rejected_facts := composition.apply_snapshot({"state": &"seated", "craft_name": "Torrent"})
	_check(not bool(rejected_facts.get("accepted", false)) and rejected_facts.reason == &"seat_not_observed", "unobserved seated claim is fenced")
	composition.detach()


func _check_fleet_choice_readability(hud: Object) -> void:
	var composition := CompositionType.new()
	_check(bool(composition.attach(hud).get("accepted", false)), "fleet choice uses the production retained card")
	root.content_scale_size = Vector2i.ZERO
	for viewport in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport
		for scale_value in [0.75, 1.0, 1.6]:
			hud.set_ui_scale(scale_value)
			for definition_name in DEFINITION_PATHS:
				var definition := load("res://assets/ships/%s.tres" % definition_name) as ShipDefinition
				var facts := _definition_facts(definition)
				for choice_state in ([&"available", &"approach"] if definition.get_ship_id() in [&"cinder_light_interceptor", &"cinder_long_range_bomber"] else [&"available"]):
					composition.apply_snapshot({"state": choice_state, "craft_name": definition.get_display_name(), "definition_facts": facts})
					for frame in 3:
						await process_frame
					var view := (composition.get_snapshot().adapter as Dictionary).view as Dictionary
					var expected := "%s | %.0f M/S BASE | MAX HULL %.0f" % [definition.get_role().to_upper(), definition.maximum_speed, definition.maximum_hull]
					var is_light := definition.get_ship_id() == &"cinder_light_interceptor"
					var is_bomber := definition.get_ship_id() == &"cinder_long_range_bomber"
					var is_choice := is_light or is_bomber
					_check((str(view.message).contains("\n" + expected + "\n") if is_choice else str(view.message).ends_with(expected)) and str(view.message).contains("PRESS INTERACT TO BOARD" if choice_state == &"available" else "LOOK FOR THE BOARDING PROMPT"), "rated facts and ordinary Interact survive for %s at %s / %.2f" % [definition_name, viewport, scale_value])
					_check(str(view.message).contains("FAST RESPONSE // HIGH DRAG WHEN COASTING") == is_light, "only Light gains the registry trade-off at %s / %.2f" % [viewport, scale_value])
					if is_light:
						_check(view.title == _expected_light_title(choice_state) and view.message == _expected_light_message(choice_state)
							and view.get("light_choice_ship_id") == &"cinder_light_interceptor", "complete Light identity, instruction, facts and trade-off retain their exact layout")
					_check(str(view.message).contains("TOUGH HULL & BRAKES // SLOW TURN / FIRE") == is_bomber, "only Bomber gains its approved trade-off")
					if is_bomber:
						_check(view.title == _expected_bomber_title(choice_state) and view.message == _expected_bomber_message(choice_state) and view.get("bomber_choice_ship_id") == &"cinder_long_range_bomber", "complete Bomber identity, instruction, facts and trade-off retain exact layout")
					var name_upper := definition.get_display_name().to_upper()
					if "CANDIDATE" in name_upper:
						_check("CANDIDATE" in str(view.message), "candidate identity remains visible for %s" % definition_name)
					if "RECONSTRUCTION" in name_upper:
						_check("RECONSTRUCTION" in str(view.message) and ("B5" if definition_name == "torrent_provisional" else "B7") in str(view.message), "source reconstruction identity remains visible for %s" % definition_name)
					var panel := hud.find_child("RuntimeStatusPanel", true, false) as Control
					var title := hud.get("_runtime_status_title") as Label
					var detail := hud.get("_runtime_status_detail") as Label
					var scroll := hud.find_child("RuntimeStatusBodyScroll", true, false) as ScrollContainer
					_check(title.get_theme_font_size("font_size") == 16 and detail.get_theme_font_size("font_size") == 11, "normal production fonts survive every viewport/scale cell")
					var title_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
					_check(title.text == str(view.title) and title_width <= title.size.x, "complete title fits without ellipsis for %s %s at %s / %.2f (text %.0f, width %.0f)" % [definition_name, choice_state, viewport, scale_value, title_width, title.size.x])
					_check(panel.get_global_rect().encloses(title.get_global_rect()) and panel.get_global_rect().encloses(scroll.get_global_rect())
						and title.get_global_rect().end.y <= scroll.get_global_rect().position.y, "title and body stay inside the card without overlap for %s %s at %s / %.2f" % [definition_name, choice_state, viewport, scale_value])
					_check(detail.text == ("%s | STATE // %s %s" if is_choice else "%s\nSTATE // %s %s") % [view.message, view.shape, str(view.state).to_upper()], "complete instruction, facts, shape and observed state reach the real body for %s %s" % [definition_name, choice_state])
					_check(detail.size.y <= scroll.size.y + 1.0, "complete choice and state fit without scrolling for %s at %s / %.2f (body %.0f, viewport %.0f)" % [definition_name, viewport, scale_value, detail.size.y, scroll.size.y])
					_check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(panel.get_global_rect()), "choice card stays inside viewport for %s at %s / %.2f" % [definition_name, viewport, scale_value])

					if choice_state == &"available" and "--capture-choice" in OS.get_cmdline_user_args() and scale_value == 1.0 \
							and viewport == Vector2i(1280, 720) and definition_name in ["torrent_provisional", "zenith_b7_observed"]:
						_check(DisplayServer.get_name() == "X11", "choice capture uses an isolated X11 renderer")
						await RenderingServer.frame_post_draw
						DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
						_check(root.get_texture().get_image().save_png(CAPTURE_DIR.path_join("choice_%s.png" % definition_name)) == OK, "choice capture saves %s" % definition_name)
	composition.apply_snapshot({"state": &"available", "craft_name": "CRAFT"})
	var fallback := (composition.get_snapshot().adapter as Dictionary).view as Dictionary
	_check(not str(fallback.message).contains("MAX HULL") and str(fallback.message).contains("PRESS INTERACT"), "missing definition keeps the ordinary boarding prompt")
	composition.apply_snapshot({"state": &"reserved", "craft_name": "CRAFT", "reservation_retained": true, "definition_facts": {"role": "TEST", "maximum_speed": 99, "maximum_hull": 99}})
	var reserved := (composition.get_snapshot().adapter as Dictionary).view as Dictionary
	_check(str(reserved.message).contains("ENTRY ROUTE RESERVED") and not str(reserved.message).contains("MAX HULL"), "reservation instruction retains its exclusive transition reading")
	composition.detach()


func _capture_if_requested(hud: Object, name: String, view: Dictionary) -> void:
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var panel := hud.find_child("RuntimeStatusPanel", true, false) as PanelContainer
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	var expected_detail := "%s\nSTATE // %s %s" % [view.message, view.shape, str(view.state).to_upper()]
	_check(
		panel != null and panel.visible
		and panel.get_global_rect() == Rect2(Vector2(462.0, 204.0), Vector2(396.0, 112.0)),
		"retained card preserves the exact settled 396x112 rect for %s" % name,
	)
	_check(
		title != null and title.text == str(view.title)
		and detail != null and detail.text == expected_detail,
		"settled frame contains the complete exact title, message, shape, and state for %s" % name,
	)
	var chrome := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
	_check(
		chrome != null and chrome.bg_color == Color("0c1724")
		and chrome.border_width_left == 1 and chrome.border_width_top == 1
		and chrome.border_width_right == 1 and chrome.border_width_bottom == 1,
		"retained card preserves exact production fill and one-pixel chrome for %s" % name,
	)
	var image := root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "boarding capture uses exact 1280x720 HUD viewport for %s" % name)
	var card_rect := Rect2i(panel.get_global_rect())
	var pixels := image.get_region(card_rect).get_data()
	_check(not pixels.is_empty(), "boarding state %s has rendered pixels inside the exact card ROI" % name)
	for previous in _captured_card_pixels:
		_check(pixels != previous, "boarding state %s differs from prior states inside the card ROI" % name)
	_captured_card_pixels.append(pixels)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_check(image.save_png(CAPTURE_DIR.path_join("%s.png" % name)) == OK, "Forward+ boarding capture saves %s" % name)


func _wait_until(predicate: Callable, frame_budget: int) -> bool:
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await process_frame
		await physics_frame
	return bool(predicate.call())


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


func _definition_facts(definition: ShipDefinition) -> Dictionary:
	var facts := {"role": definition.get_role(), "maximum_speed": definition.maximum_speed, "maximum_hull": definition.maximum_hull}
	var choice := Registry.get_boarding_choice_facts(definition)
	if not choice.is_empty():
		facts["role_choice"] = choice
	return facts


func _check_choice_negatives() -> void:
	var presenter := PresenterType.new()
	var definition := load("res://assets/ships/cinder_light_interceptor_new_design.tres") as ShipDefinition
	var facts := _definition_facts(definition)
	var original := facts.duplicate(true)
	for state in [&"approach", &"available"]:
		var view := presenter.present({"state": state, "craft_name": definition.get_display_name(), "definition_facts": facts})
		_check(view.title == _expected_light_title(state) and view.message == _expected_light_message(state)
			and view.get("light_choice_ship_id") == &"cinder_light_interceptor", "Light %s receives the complete exact choice layout" % state)
	_check(facts == original, "presenter never mutates its detached input facts")
	var named_role := facts.duplicate(true)
	named_role.role = &"Light interceptor"
	for state in [&"approach", &"available"]:
		var string_view := presenter.present({"state": state, "craft_name": definition.get_display_name(), "definition_facts": facts})
		var named_view := presenter.present({"state": state, "craft_name": definition.get_display_name(), "definition_facts": named_role})
		_check(named_view == string_view, "StringName role preserves the complete existing String reading for %s" % state)
	for malformed in [null, [], "LIGHT", 42, {"role": []}, {"role": "Light interceptor", "maximum_speed": "102", "maximum_hull": 110}, {"role": "Light interceptor", "maximum_speed": INF, "maximum_hull": 110}, {"role": "Light interceptor", "maximum_speed": 102, "maximum_hull": NAN}]:
		var view := presenter.present({"state": &"available", "craft_name": "Cinder Light Interceptor", "definition_facts": malformed})
		_check(not view.has("light_choice_ship_id") and str(view.message) == "CINDER LIGHT INTERCEPTOR // PRESS INTERACT TO BOARD", "malformed definition facts safely retain the ordinary prompt")
	var bad_choices: Array = [null, [], "FAST RESPONSE", {}, {"advantage": "FAST RESPONSE", "weakness": "HIGH DRAG WHEN COASTING"}]
	for patch in [
		{"ship_id": &"arrow_provisional"}, {"role_id": &"wrong"},
		{"source_axes": []}, {"source_axes": {"advantage": &"maximum_hull", "weakness": &"passive_drag"}},
		{"maximum_speed": 94.0}, {"passive_drag": 0.0}, {"passive_drag": INF},
		{"advantage": []}, {"weakness": ""}, {"weakness": "WRONG\nLINE"},
	]:
		var bad := facts.role_choice.duplicate(true) as Dictionary
		bad.merge(patch, true)
		bad_choices.append(bad)
	for bad in bad_choices:
		var bad_facts := facts.duplicate(true)
		bad_facts.role_choice = bad
		var view := presenter.present({"state": &"available", "craft_name": definition.get_display_name(), "definition_facts": bad_facts})
		_check(not view.has("light_choice_ship_id") and not (str(view.title) + str(view.message)).contains("FAST RESPONSE") and str(view.message).ends_with("LIGHT INTERCEPTOR | 102 M/S BASE | MAX HULL 110"), "malformed role choice cannot suppress ordinary rated facts or invent a trade-off")
	var arrow := load("res://assets/ships/arrow_provisional.tres") as ShipDefinition
	var arrow_facts := _definition_facts(arrow)
	arrow_facts.role_choice = facts.role_choice
	var unrelated := presenter.present({"state": &"available", "craft_name": arrow.get_display_name(), "definition_facts": arrow_facts})
	_check(not unrelated.has("light_choice_ship_id") and not (str(unrelated.title) + str(unrelated.message)).contains("FAST RESPONSE"), "Light trade-off cannot bleed into an unrelated role")
	for state in [&"reserved", &"boarding", &"seated", &"disembarking", &"rejected"]:
		var view := presenter.present({"state": state, "craft_name": definition.get_display_name(), "definition_facts": facts,
			"reservation_retained": true, "transition_busy": true, "player_seated": true})
		var baseline := presenter.present({"state": state, "craft_name": definition.get_display_name(),
			"reservation_retained": true, "transition_busy": true, "player_seated": true})
		_check(view == baseline, "Light %s ignores choice facts and retains the complete original view" % state)


## Explicit component capture: real HUD/composition and live resource facts,
## no Main scene, staged flight, camera recipe or required capture-set change.
func _run_choice_capture() -> void:
	print("CHOICE_CAPTURE_SETUP: HUD component only; production HUD/composition, selected current definition and detached registry facts; no Main 3D or ordinary access proof")
	var output_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	_check(output_dir.is_absolute_path() and output_dir.begins_with("/"), "choice capture requires an explicit absolute --output-dir")
	_check(DisplayServer.get_name() == "X11", "choice capture requires private X11")
	_check(RenderingServer.get_current_rendering_method() == "forward_plus", "choice capture uses Forward+")
	if not _failures.is_empty():
		_finish_choice_capture()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_reduced_motion(true)
	hud.call(&"_begin")
	_check(await _wait_until(func() -> bool:
		var live := hud.get("_hud") as Control
		return live != null and live.is_visible_in_tree(), 30), "choice component exposes the real HUD")
	_release_inputs()
	hud.set_ui_scale(1.0)
	var composition := CompositionType.new()
	_check(bool(composition.attach(hud).get("accepted", false)), "choice capture attaches the public retained composition")
	var capture_bomber := "--capture-bomber-choice" in OS.get_cmdline_user_args()
	var definition := load("res://assets/ships/%s_new_design.tres" % ("cinder_long_range_bomber" if capture_bomber else "cinder_light_interceptor")) as ShipDefinition
	var facts := _definition_facts(definition)
	var expected_title := _expected_bomber_title(&"available") if capture_bomber else _expected_light_title(&"available")
	var expected_message := _expected_bomber_message(&"available") if capture_bomber else "FAST RESPONSE // HIGH DRAG WHEN COASTING\nLIGHT INTERCEPTOR | 102 M/S BASE | MAX HULL 110\nPRESS INTERACT TO BOARD"
	for viewport in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		# Reset both viewport and content policy for each native-size image.
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		root.content_scale_factor = 1.0
		root.size = viewport
		hud.set_ui_scale(1.0)
		var applied := composition.apply_snapshot({"state": &"available", "craft_name": definition.get_display_name(), "definition_facts": facts})
		_check(bool(applied.get("accepted", false)), "native-size selected choice reaches the retained card")
		for frame in (8 if capture_bomber else 4):
			await process_frame
			if capture_bomber:
				await RenderingServer.frame_post_draw
		if not capture_bomber:
			await RenderingServer.frame_post_draw
		var view := (composition.get_snapshot().adapter as Dictionary).view as Dictionary
		var panel := hud.find_child("RuntimeStatusPanel", true, false) as Control
		var title := hud.get("_runtime_status_title") as Label
		var detail := hud.get("_runtime_status_detail") as Label
		var scroll := hud.find_child("RuntimeStatusBodyScroll", true, false) as ScrollContainer
		_check(view.title == expected_title and view.message == expected_message and view.state == &"available", "choice view has exact title, instruction, source facts and trade-off")
		_check(title.text == expected_title and detail.text == expected_message + " | STATE // [+] AVAILABLE", "native frame contains every exact choice/state string")
		_check(title.get_theme_font_size("font_size") == 16 and detail.get_theme_font_size("font_size") == 11, "choice retains normal production fonts at UI scale 1")
		_check(panel.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(viewport)).encloses(panel.get_global_rect())
			and panel.get_global_rect() == HudType.compute_runtime_status_panel_rect(Vector2(viewport), hud.get_safe_area_insets(), 1.0), "choice card remains inside the production safe bounds")
		_check(panel.get_global_rect().encloses(title.get_global_rect()) and panel.get_global_rect().encloses(scroll.get_global_rect())
			and title.get_global_rect().end.y <= scroll.get_global_rect().position.y, "title and choice body stay inside card without overlap")
		_check(detail.size.y <= scroll.size.y + 1.0 and detail.size.x <= scroll.size.x + 1.0
			and detail.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0,
			"complete instruction, trade-off, facts and state fit without scrolling or cropping")
		var title_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_check(title_width <= title.size.x, "complete choice title fits without ellipsis")
		var image := root.get_texture().get_image()
		_check(image.get_size() == viewport and Vector2i(root.get_visible_rect().size) == viewport, "rendered choice image and native viewport have exact requested dimensions")
		_check(not image.get_region(Rect2i(panel.get_global_rect())).get_data().is_empty(), "choice card contains rendered pixels")
		if _failures.is_empty():
			_check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "choice output directory is available")
			_check(image.save_png(output_dir.path_join(("choice_cinder_bomber_%dx%d.png" if capture_bomber else "choice_cinder_light_%dx%d.png") % [viewport.x, viewport.y])) == OK, "choice PNG saves at exact %dx%d" % [viewport.x, viewport.y])
	composition.detach()
	hud.queue_free()
	await process_frame
	_finish_choice_capture()


func _finish_choice_capture() -> void:
	_release_inputs()
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_CUES_HUD_TEST_OK (%d assertions; HUD-only choice capture)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _release_inputs() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _expected_light_title(state: StringName) -> String:
	return "[>] MOVE TO CINDER LIGHT INTERCEPTOR" if state == &"approach" else "[+] CINDER LIGHT INTERCEPTOR"


func _expected_light_message(state: StringName) -> String:
	return "FAST RESPONSE // HIGH DRAG WHEN COASTING\nLIGHT INTERCEPTOR | 102 M/S BASE | MAX HULL 110\n" + ("LOOK FOR THE BOARDING PROMPT" if state == &"approach" else "PRESS INTERACT TO BOARD")


func _expected_bomber_title(state: StringName) -> String:
	return "[>] MOVE TO CINDER LONG-RANGE BOMBER" if state == &"approach" else "[+] CINDER LONG-RANGE BOMBER"


func _expected_bomber_message(state: StringName) -> String:
	return "TOUGH HULL & BRAKES // SLOW TURN / FIRE\nLONG-RANGE BOMBER | 72 M/S BASE | MAX HULL 240\n" + ("LOOK FOR THE BOARDING PROMPT" if state == &"approach" else "PRESS INTERACT TO BOARD")


func _check_bomber_negatives() -> void:
	var presenter := PresenterType.new()
	var definition := load("res://assets/ships/cinder_long_range_bomber_new_design.tres") as ShipDefinition
	var facts := _definition_facts(definition)
	var original := facts.duplicate(true)
	for state in [&"approach", &"available"]:
		var view := presenter.present({"state": state, "craft_name": definition.get_display_name(), "definition_facts": facts})
		_check(view.title == _expected_bomber_title(state) and view.message == _expected_bomber_message(state) and view.get("bomber_choice_ship_id") == &"cinder_long_range_bomber", "Bomber exact %s choice is sourced" % state)
	var bad_choices: Array = [null, [], "BOMBER", {}, {"advantage": "TOUGH HULL & BRAKES"}]
	for patch in [{"ship_id": &"cinder_light_interceptor"}, {"role_id": &"wrong"}, {"ship_id": []}, {"role_id": []}, {"source_axes": []}, {"source_axes": {"advantage": 28, "weakness": []}}, {"source_axes": {"advantage": [[], &"brake_acceleration"], "weakness": [&"yaw_speed_degrees", &"roll_speed_degrees", &"weapon_cooldown"]}}, {"advantage": []}, {"weakness": []}, {"advantage": "FAKE"}, {"weakness": "WRONG\nLINE"}]:
		var bad := facts.role_choice.duplicate(true) as Dictionary
		bad.merge(patch, true)
		bad_choices.append(bad)
	for axis in ["maximum_speed", "maximum_hull", "brake_acceleration", "yaw_speed_degrees", "roll_speed_degrees", "weapon_cooldown"]:
		for invalid in [0.0, INF, NAN, "28", 999.0]:
			var bad := facts.role_choice.duplicate(true) as Dictionary
			bad[axis] = invalid
			bad_choices.append(bad)
	for bad in bad_choices:
		var bad_facts := facts.duplicate(true)
		bad_facts.role_choice = bad
		var view := presenter.present({"state": &"available", "craft_name": definition.get_display_name(), "definition_facts": bad_facts})
		_check(not view.has("bomber_choice_ship_id") and not str(view.message).contains("TOUGH HULL") and str(view.message).ends_with("LONG-RANGE BOMBER | 72 M/S BASE | MAX HULL 240"), "malformed Bomber choice preserves ordinary rated facts without a fabricated trade-off")
	for role in ["Light interceptor", "Reconnaissance ship"]:
		var foreign := facts.duplicate(true)
		foreign.role = role
		var view := presenter.present({"state": &"available", "craft_name": "FOREIGN", "definition_facts": foreign})
		_check(not view.has("bomber_choice_ship_id") and not str(view.message).contains("TOUGH HULL"), "Bomber facts cannot bleed into foreign roles")
	for state in [&"reserved", &"boarding", &"seated", &"disembarking", &"rejected"]:
		var snapshot := {"state": state, "craft_name": definition.get_display_name(), "reservation_retained": true, "transition_busy": true, "player_seated": true}
		var baseline := presenter.present(snapshot)
		snapshot.definition_facts = facts
		_check(presenter.present(snapshot) == baseline, "Bomber %s retains the complete original transition view" % state)
	for patch in [{"maximum_speed": 73.0}, {"maximum_hull": 241.0}]:
		var mismatched := facts.duplicate(true)
		mismatched.merge(patch, true)
		var view := presenter.present({"state": &"available", "craft_name": definition.get_display_name(), "definition_facts": mismatched})
		_check(not view.has("bomber_choice_ship_id") and not str(view.message).contains("TOUGH HULL") and str(view.message).contains("MAX HULL"), "Bomber source/rated mismatch retains ordinary facts without a trade-off")
	for malformed in [null, [], "BOMBER", 42, {"role": []}, {"role": "Long-range bomber", "maximum_speed": "72", "maximum_hull": 240}, {"role": "Long-range bomber", "maximum_speed": INF, "maximum_hull": 240}, {"role": "Long-range bomber", "maximum_speed": 72, "maximum_hull": NAN}]:
		var view := presenter.present({"state": &"available", "craft_name": definition.get_display_name(), "definition_facts": malformed})
		_check(not view.has("bomber_choice_ship_id") and str(view.message) == "CINDER LONG-RANGE BOMBER // PRESS INTERACT TO BOARD", "malformed Bomber definition safely preserves ordinary prompt")
	for state in [&"reserved", &"boarding", &"seated", &"disembarking", &"rejected"]:
		var view := presenter.present({"state": state, "craft_name": definition.get_display_name(), "definition_facts": facts,
			"reservation_retained": true, "transition_busy": true, "player_seated": true})
		var baseline := presenter.present({"state": state, "craft_name": definition.get_display_name(),
			"reservation_retained": true, "transition_busy": true, "player_seated": true})
		_check(view == baseline, "Bomber %s ignores choice facts and retains complete original view" % state)
	_check(facts == original, "Bomber detached input facts remain unchanged")
