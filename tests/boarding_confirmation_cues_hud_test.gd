extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const CompositionType := preload("res://scripts/ui/boarding_confirmation_hud_composition.gd")
const CAPTURE_DIR := "user://screenshots/boarding_confirmation_states"

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []
var _captured_pixels: Array[PackedByteArray] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
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
	var expected_shapes := PackedStringArray(["[>]", "[+]", "[=]", "[>>]", "[#]", "[<<]", "[!]"])
	for index in states.size():
		var state := states[index]
		var applied := composition.apply_snapshot(state)
		_check(bool(applied.get("accepted", false)), "reachable %s snapshot renders" % state.state)
		await process_frame
		await _capture_if_requested(hud, "%02d_%s" % [index + 1, state.state], expected_shapes[index])
	var rejected_facts := composition.apply_snapshot({"state": &"seated", "craft_name": "Torrent"})
	_check(not bool(rejected_facts.get("accepted", false)) and rejected_facts.reason == &"seat_not_observed", "unobserved seated claim is fenced")
	composition.detach()


func _capture_if_requested(hud: Object, name: String, shape: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var panel := hud.find_child("RuntimeStatusPanel", true, false) as PanelContainer
	var visible_text := ""
	if panel != null:
		for candidate in panel.find_children("*", "Label", true, false):
			var label := candidate as Label
			if label != null and label.text.begins_with(shape):
				visible_text = label.text
				break
	_check(panel != null and panel.visible and not visible_text.is_empty(), "retained card visibly names %s with shape %s" % [name, shape])
	_check(panel != null and panel.size == Vector2(396.0, 112.0), "retained card preserves settled 396x112 bounds for %s" % name)
	var image := root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "boarding capture uses exact 1280x720 HUD viewport for %s" % name)
	var pixels := image.get_data()
	for previous in _captured_pixels:
		_check(pixels != previous, "boarding state %s is visibly distinct from prior states" % name)
	_captured_pixels.append(pixels)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_check(image.save_png(CAPTURE_DIR.path_join("%s.png" % name)) == OK, "Forward+ boarding capture saves %s" % name)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
