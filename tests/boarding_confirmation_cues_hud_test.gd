extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const CompositionType := preload("res://scripts/ui/boarding_confirmation_hud_composition.gd")
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
	hud.call(&"_begin")
	await process_frame
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
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_CUES_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
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
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
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
