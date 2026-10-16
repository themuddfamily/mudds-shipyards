extends SceneTree

const Presenter := preload("res://scripts/ui/first_sortie_tutorial_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var board := presenter.present_snapshot({"step_id": &"board", "generation": 4, "revision": 1, "input_family": &"controller", "glyphs": {&"interact": "X"}})
	_check(board.title == "Board the Torrent" and board.prompt.contains("Torrent interceptor") and board.prompt.contains("X"), "controller board prompt names the Torrent and resolves glyph")
	_check(board.actions.size() == 3 and board.actions[2].focusable, "tutorial actions are controller-focusable")
	_check(
		board.color_independent
		and board.prompt.contains("PROGRESS // STEP 2 OF 7")
		and board.prompt.contains("NEXT ACTION // BOARD TORRENT // INTERACT")
		and board.prompt.contains("RECOVERY // OUT OF RANGE"),
		"board prompt exposes textual progress, next action, and recovery"
	)
	var board_redraw := presenter.present_snapshot({"step_id": &"board", "generation": 4, "revision": 1, "input_family": &"keyboard", "glyphs": {&"interact": "Tab"}})
	_check(board_redraw.accepted and board_redraw.prompt.contains("Tab"), "same-step glyph redraw preserves authoritative progress")
	var launch := presenter.present_snapshot({
		"step_id": &"launch", "generation": 4, "revision": 2,
		"glyphs": {
			&"move_forward": "W", &"move_left": "A", &"move_right": "D",
			&"pitch_up": "Up", &"pitch_down": "Down",
		},
	})
	_check(
		launch.title == "Throttle and steer"
		and launch.prompt.contains("Hold W for throttle")
		and launch.prompt.contains("A/D")
		and launch.prompt.contains("Up/Down")
		and launch.prompt.contains("THROTTLE UP // STEER CLEAR OF BAY")
		and launch.revision == 2,
		"launch prompt teaches mapped throttle, yaw, and pitch controls"
	)
	var conflicting := presenter.present_snapshot({"step_id": &"fire", "generation": 4, "revision": 2})
	_check(not conflicting.accepted and conflicting.reason == &"conflicting_revision", "one authoritative revision cannot identify two different steps")
	var fire := presenter.present_snapshot({"step_id": &"fire", "generation": 4, "revision": 3, "input_family": &"keyboard", "glyphs": {&"fire": "LMB"}})
	_check(fire.title == "Fire at range targets" and fire.prompt.contains("marked RANGE TARGET") and fire.prompt.contains("LMB") and fire.prompt.contains("REACQUIRE THE MARKED RANGE TARGET"), "range-target prompt resolves glyph and recovery")
	var landing := presenter.present_snapshot({
		"step_id": &"return_land", "generation": 4, "revision": 4,
		"input_family": &"controller",
		"glyphs": {&"landing_assist": "Y", &"brake": "LT"},
	})
	_check(
		landing.prompt.contains("Hold LT")
		and landing.prompt.contains("then press Y")
		and landing.prompt.find("Follow the return vector") < landing.prompt.find("then press Y")
		and landing.prompt.contains("available compatible berth approach")
		and landing.prompt.contains("Level the craft")
		and landing.prompt.contains("Wait for automatic docking to finish")
		and landing.recovery == "ASSIST REFUSED // CHECK APPROACH, SPEED AND ATTITUDE; RETRY",
		"controller return help teaches capture conditions before mapped assist and the refused-request retry",
	)
	var keyboard_landing := presenter.present_snapshot({
		"step_id": &"return_land", "generation": 4, "revision": 4,
		"input_family": &"keyboard",
		"glyphs": {&"landing_assist": "Enter", &"brake": "Space"},
	})
	_check(
		keyboard_landing.accepted
		and keyboard_landing.prompt.contains("Hold Space")
		and keyboard_landing.prompt.contains("then press Enter")
		and keyboard_landing.prompt.contains("available compatible berth approach")
		and keyboard_landing.prompt.contains("Level the craft")
		and keyboard_landing.prompt.contains("Wait for automatic docking to finish"),
		"keyboard return help resolves remapped controls without changing the approach sequence",
	)
	var accessible := presenter.present_snapshot({"step_id": &"return_land", "generation": 4, "revision": 5, "accessible": true})
	_check(
		accessible.prompt == accessible.accessible_prompt
		and accessible.prompt.contains("available compatible berth approach")
		and accessible.prompt.contains("Brake to slow down. Level the craft, then use the landing assist control")
		and accessible.prompt.contains("Wait for automatic docking to finish")
		and accessible.prompt.contains("FOLLOW RETURN VECTOR")
		and accessible.prompt.contains("CHECK APPROACH, SPEED AND ATTITUDE; RETRY")
		and not accessible.prompt.contains("{"),
		"accessible return help teaches the same capture conditions, docking wait and retry without glyphs",
	)
	var stale_revision := presenter.present_snapshot({"step_id": &"board", "generation": 4, "revision": 4})
	_check(not stale_revision.accepted and stale_revision.reason == &"stale_revision" and presenter.get_snapshot().step_id == &"return_land", "older step cannot replace newer authoritative progress")
	var stale_generation := presenter.present_snapshot({"step_id": &"exit", "generation": 3, "revision": 9})
	_check(not stale_generation.accepted and stale_generation.reason == &"stale_generation", "older sortie generation is fenced")
	var dismiss := presenter.request(&"dismiss")
	_check(
		dismiss.accepted
		and dismiss.completion_intent.generation == 4
		and dismiss.completion_intent.revision == 5
		and dismiss.completion_intent.persist
		and not dismiss.tutorial_progress_authority
		and not dismiss.gameplay_authority
		and not dismiss.input_authority
		and not dismiss.timer_authority
		and not dismiss.process_authority,
		"dismiss returns a caller-owned fenced intent without progression or runtime authority"
	)
	var actor_loss := presenter.present_snapshot({"step_id": &"exit", "generation": 4, "revision": 6, "actor_attached": false})
	_check(not actor_loss.accepted and actor_loss.reason == &"actor_unavailable" and presenter.get_snapshot().is_empty() and not presenter.request(&"repeat").accepted, "actor loss clears retained prompt and actions")
	var reused := presenter.present_snapshot({"step_id": &"board", "generation": 0, "revision": 1})
	_check(reused.accepted and reused.generation == 0, "cleared presenter can be reused for a new tutorial source")
	var contextual := presenter.present_snapshot({
		"step_id": &"board", "generation": 0, "revision": 2,
		"craft_display_name": "Jovian-class Light Freighter candidate",
		"input_family": &"keyboard", "glyphs": {&"interact": "E"},
	})
	_check(
		contextual.accepted
		and contextual.title == "Board Jovian-class Light Freighter"
		and contextual.prompt.contains(
			"Press E to board Jovian-class Light Freighter."
		)
		and contextual.next_action == "BOARD SELECTED CRAFT // INTERACT"
		and contextual.craft_display_name == "Jovian-class Light Freighter"
		and contextual.contextual_craft,
		"boarding prompt names the selected free-sortie craft instead of the Torrent",
	)
	var invalid_context := presenter.present_snapshot({
		"step_id": &"board", "generation": 0, "revision": 3,
		"craft_display_name": "Jovian\nspoof",
	})
	_check(
		not invalid_context.accepted
		and invalid_context.reason == &"invalid_craft_context"
		and presenter.get_snapshot().revision == 2,
		"invalid dynamic craft copy cannot replace the retained prompt",
	)
	var detached := presenter.detach(&"session_lost")
	_check(not detached.attached and detached.reason == &"session_lost" and presenter.get_snapshot().is_empty(), "session detach clears retained source and fence")
	var disabled := presenter.present_snapshot({"step_id": &"board", "generation": 1, "revision": 1, "show_tutorials": false})
	_check(not disabled.accepted and disabled.reason == &"tutorials_disabled" and not disabled.has("completion_intent"), "disabled tutorial policy hides prompts without completion")
	var invalid := presenter.present_snapshot({"step_id": &"combat", "generation": 1, "revision": 1})
	_check(not invalid.accepted, "unknown tutorial step fails closed")
	_test_exit_shutdown_guidance()
	_test_fire_target_context()
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_fire_target_context() -> void:
	var presenter := Presenter.new()
	var range_prompt := presenter.present_snapshot({"step_id": &"fire", "generation": 2, "revision": 1})
	_check(range_prompt.fire_target == &"range_targets" and range_prompt.title == "Fire at range targets",
		"legacy fire snapshots retain range-target guidance")
	var live := presenter.present_snapshot({
		"step_id": &"fire", "generation": 2, "revision": 2,
		"fire_target": &"live_interceptor", "glyphs": {&"fire": "LMB"},
	})
	_check(live.accepted and live.title == "Engage the live interceptor"
		and live.prompt.contains("LMB") and live.next_action == "TRACK LIVE INTERCEPTOR // FIRE"
		and live.recovery.contains("LIVE RANGE-DEFENCE INTERCEPTOR") and not live.prompt.contains("RANGE TARGET"),
		"authoritative live-contact context replaces obsolete range-target instruction and recovery")
	var conflicting := presenter.present_snapshot({
		"step_id": &"fire", "generation": 2, "revision": 2, "fire_target": &"range_targets",
	})
	_check(not conflicting.accepted and conflicting.reason == &"conflicting_revision"
		and presenter.get_snapshot().fire_target == &"live_interceptor",
		"one revision cannot switch the accepted combat target")
	for invalid: Variant in [&"unknown", 1, {}, null]:
		var rejected := presenter.present_snapshot({
			"step_id": &"fire", "generation": 2, "revision": 3, "fire_target": invalid,
		})
		_check(not rejected.accepted and rejected.reason == &"invalid_fire_target"
			and presenter.get_snapshot() == live, "invalid target identity/type retains the accepted prompt")
	var redraw := presenter.present_snapshot({
		"step_id": &"fire", "generation": 2, "revision": 2,
		"fire_target": &"live_interceptor", "glyphs": {&"fire": "R2"},
	})
	_check(redraw.accepted and redraw.prompt.contains("R2") and not redraw.prompt.contains("LMB")
		and redraw.completion_intent == live.completion_intent, "live-target remap redraw preserves the progress fence")
	var accessible := presenter.present_snapshot({
		"step_id": &"fire", "generation": 2, "revision": 2,
		"fire_target": &"live_interceptor", "accessible": true,
	})
	_check(accessible.accepted and accessible.prompt == accessible.accessible_prompt
		and accessible.prompt.contains("live range-defence interceptor") and not accessible.prompt.contains("{"),
		"accessible live-contact guidance remains glyph-free")
	var landing := presenter.present_snapshot({"step_id": &"return_land", "generation": 2, "revision": 3})
	_check(landing.accepted and landing.fire_target.is_empty() and not landing.prompt.contains("INTERCEPTOR"),
		"combat context does not leak into the next tutorial step")
	presenter.detach()
	var reused := presenter.present_snapshot({"step_id": &"fire", "generation": 0, "revision": 0})
	_check(reused.accepted and reused.fire_target == &"range_targets", "detached presenter cannot inherit an earlier live contact")


func _test_exit_shutdown_guidance() -> void:
	# A held brake is propulsion demand even at zero speed, and GameFlow refuses
	# to exit while the engine is online. The preceding landing step teaches
	# holding that brake, so exit must explicitly teach releasing it and waiting.
	var presenter := Presenter.new()
	for family: StringName in [&"controller", &"keyboard"]:
		var brake := "LT" if family == &"controller" else "Space"
		var interact := "X" if family == &"controller" else "Tab"
		var exit := presenter.present_snapshot({
			"step_id": &"exit", "generation": 1, "revision": 6,
			"input_family": family,
			"glyphs": {&"brake": brake, &"interact": interact},
		})
		var release := "Release %s and all flight controls." % brake
		var wait := "Wait for propulsion to shut down automatically"
		var action := "then press %s to exit." % interact
		_check(
			exit.accepted and exit.prompt.contains(release)
			and exit.prompt.contains(wait) and exit.prompt.contains(action)
			and exit.prompt.find(release) < exit.prompt.find(wait)
			and exit.prompt.find(wait) < exit.prompt.find(action)
			and not exit.prompt.contains("{"),
			"%s exit teaches mapped brake release and automatic shutdown before interaction" % family,
		)
		_check(
			exit.next_action.contains("WAIT FOR PROPULSION OFFLINE")
			and exit.recovery.contains("RELEASE BRAKE AND FLIGHT CONTROLS")
			and exit.recovery.contains("WAIT FOR PROPULSION OFFLINE, THEN INTERACT AGAIN")
			and exit.completion_intent.revision == 6,
			"%s exit recovery explains the stopped-but-online block without changing progress" % family,
		)
	var accessible := presenter.present_snapshot({
		"step_id": &"exit", "generation": 1, "revision": 6, "accessible": true,
	})
	_check(
		accessible.accepted and accessible.prompt == accessible.accessible_prompt
		and accessible.prompt.contains("Release the brake and all flight controls.")
		and accessible.prompt.contains("Wait for propulsion to shut down automatically, then use the interact control to exit.")
		and not accessible.prompt.contains("{"),
		"accessible exit teaches the same release, shutdown and interaction sequence",
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
