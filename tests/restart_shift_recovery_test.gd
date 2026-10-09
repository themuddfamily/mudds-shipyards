extends SceneTree
## test-matrix-timeout-seconds: 600
## Drives the production boot scene through the two ways a running shift can be
## replaced in one process, and checks what the next title screen says about it.
##
## - RESTART SHIFT is the player's explicit choice. Nothing crashed, so the
##   reloaded title must not offer crash recovery, and safe-start must not count
##   a quick restart as a failed launch.
## - A reload that never closed the session is what a crash looks like to the
##   next start. The composed recovery receipt must be one the HUD accepts, so
##   the recovery card is actually shown.

const BOOT := preload("res://scenes/boot.tscn")
const SUCCESS_MARKER := "RESTART_SHIFT_RECOVERY_TEST_OK"
const FAILURE_MARKER := "RESTART_SHIFT_RECOVERY_TEST_FAILED"

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	change_scene_to_packed(BOOT)
	var game := await _await_main(null)
	_check(game != null, "the boot scene composes Main")
	if game == null:
		_finish()
		return
	_check(game.get_recovery_available_snapshot().is_empty(),
		"a first launch on fresh data offers no crash recovery")
	game.start_shift()
	for _i in range(10):
		await physics_frame

	# --- RESTART SHIFT inside safe-start's stability window -----------------
	game.hud.emit_signal(&"restart_requested")
	var restarted := await _await_main(game)
	_check(restarted != null, "RESTART SHIFT composes a fresh Main")
	if restarted == null:
		_finish()
		return
	var recovery := restarted.get_recovery_available_snapshot()
	_check(recovery.is_empty(),
		"a restarted shift is not reported as an unfinished session (%s)" % recovery)
	_check(not bool(restarted.hud.get_session_recovery_notice_snapshot().get("active", true)),
		"the restarted title shows no session recovery card")
	var safe_start := (
		restarted.get_safe_start_recovery_report().get("policy_snapshot", {}) as Dictionary
	)
	_check(int(safe_start.get("consecutive_failure_count", -1)) == 0,
		"safe-start does not count a restart as a failed launch (%s)"
			% safe_start.get("consecutive_failure_count", "missing"))
	_check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,
		"the restarted title leaves the cursor free")

	# --- a reload that never closed the session -----------------------------
	restarted.start_shift()
	for _i in range(10):
		await physics_frame
	reload_current_scene()
	var recovered := await _await_main(restarted)
	_check(recovered != null, "an unclosed reload composes a fresh Main")
	if recovered == null:
		_finish()
		return
	_check(not recovered.get_recovery_available_snapshot().is_empty(),
		"an unclosed session is offered for recovery")
	var notice := recovered.hud.get_session_recovery_notice_snapshot() as Dictionary
	_check(bool(notice.get("active", false)),
		"the HUD shows the session recovery card (%s)"
			% recovered.get("_session_recovery_hud_status"))

	# --- BEGIN SHIFT with the choice still open -----------------------------
	# The player presses BEGIN SHIFT on the title without answering the card.
	var begin := _begin_shift_button(recovered)
	_check(begin != null and begin.is_visible_in_tree() and not begin.disabled,
		"BEGIN SHIFT stays available while the recovery choice is open")
	if begin == null:
		_finish()
		return
	begin.pressed.emit()
	for _i in range(90):
		await process_frame
		if recovered.phase != GameFlow.Phase.INTRO:
			break
	for _i in range(4):
		await process_frame
	var status := recovered.get("_session_recovery_hud_status") as Dictionary
	_check(recovered.phase == GameFlow.Phase.APPROACH_SHIP, "BEGIN SHIFT starts the shift")
	_check(
		bool(status.get("accepted", false))
			and StringName(status.get("choice", &"")) == &"normal_start"
			and StringName(status.get("source", &"")) == &"begin_shift"
			and recovered.get_recovery_available_snapshot().is_empty(),
		"BEGIN SHIFT answers the open choice as Resume Last Save (%s)" % status
	)
	_check(not bool(recovered.hud.get_session_recovery_notice_snapshot().get("active", true))
		and not (recovered.hud.get("_recovery_prompt_panel") as Control).visible,
		"the recovery card does not stay over gameplay")
	for _i in range(2):
		await physics_frame
	var player := recovered.get_node("Player") as PlayerController
	var torrent := recovered.get_node("TorrentInterceptor") as HeroShip
	var context := recovered.get("_solo_safe_recovery_context") as Dictionary
	_check(player.is_control_enabled() and not player.is_seated()
		and player.collision_layer == PhysicsLayers.PLAYER_BODY_LAYER
		and context.get("mode") == "on_foot"
		and context.get("craft_id") == String(torrent.get_ship_id())
		and recovered.call("_find_boarding_candidate") == torrent,
		"on-foot Resume restores an awake usable Player within the saved Torrent boarding reach")
	_check(
		recovered.get("_first_sortie_tutorial_active_step") == &"board"
			and (recovered.hud.get("_runtime_status_panel") as Control).visible
			and (recovered.hud.get("_runtime_status_title") as Label).text == "Board Torrent-class Interceptor",
		"Resume shows the boarding tutorial beside the safely restored Torrent"
	)
	_finish()


func _begin_shift_button(main: Node) -> Button:
	for button: Button in main.find_children("*", "Button", true, false):
		if button.text.begins_with("BEGIN SHIFT"):
			return button
	return null


func _await_main(previous: GameFlow) -> GameFlow:
	for _i in range(3000):
		await process_frame
		var scene := current_scene
		if scene == null or not scene.has_method(&"get_main"):
			continue
		var main := scene.call(&"get_main") as GameFlow
		if main != null and main != previous and main.is_inside_tree() \
				and bool(main.get("_initialized")):
			for _j in range(4):
				await process_frame
			return main
	return null


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if ok:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("%s (%d assertions)" % [SUCCESS_MARKER, _assertions])
		quit(0)
		return
	print("%s (%d failures)" % [FAILURE_MARKER, _failures.size()])
	for failure in _failures:
		print("  - ", failure)
	quit(1)
