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
	_finish()


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
