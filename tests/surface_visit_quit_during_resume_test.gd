extends SceneTree
## test-matrix-timeout-seconds: 600
## A resumed Aurora or Rime visit spends its first seconds streaming the world
## back in. The interrupted-visit receipt is retired as soon as that resume is
## admitted, so a player who quits (or restarts the shift) while the world is
## still streaming must have the visit recorded again on the way out; otherwise
## the next launch starts them back at Mudds and their survey progress is gone.
##
## Each world is exercised through the production store and whole-`Main`
## lifecycle: seed a receipt, boot a `Main` that begins resuming it, leave that
## `Main` while it is still `restoring`, and check that the next `Main` resumes
## the same visit with the same survey progress.

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "SURFACE_VISIT_QUIT_DURING_RESUME_TEST_OK"
const FAILURE_MARKER := "SURFACE_VISIT_QUIT_DURING_RESUME_TEST_FAILED"

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _exercise(&"aurora", "_aurora_expedition", "_aurora_expedition_persistence_binding",
		&"get_aurora_interrupted_visit_status")
	await _exercise(&"rime", "_rime_expedition", "_rime_expedition_persistence_binding",
		&"get_rime_interrupted_visit_status")
	_finish()


func _exercise(
		world_id: StringName, owner_property: String, binding_property: String,
		status_method: StringName,
	) -> void:
	# --- seed a settled on-foot visit through the production binding --------
	var seed_game := await _boot(false)
	var craft := seed_game.get_node_or_null("HalyardCrewTransport") as HeroShip
	_check(craft != null, "%s: the production Main composes the Halyard" % world_id)
	if craft == null:
		await _shut_down(seed_game)
		return
	var berth_id := String(craft.get_home_berth_id())
	var binding: RefCounted = seed_game.get(binding_property)
	_check(binding != null, "%s: the visit persistence binding is configured" % world_id)
	if binding == null:
		await _shut_down(seed_game)
		return
	var survey_script: GDScript = (seed_game.get(owner_property) as RefCounted).get(
		"survey"
	).get_script()
	var progress := {
		"schema_version": 1,
		"activity_id": String(survey_script.get_script_constant_map().get("ACTIVITY_ID", "")),
		"state": CheckpointRouteActivity.State.ACTIVE,
		"generation": 1,
		"next_checkpoint_index": 1,
		"failure_reason": "",
	}
	var seeded := binding.call(&"save_interrupted_visit", {
		"visit_state": "surface",
		"craft_home_berth_id": berth_id,
		"on_foot": true,
		"survey": progress,
	}, "%s-quit-during-resume-seed" % world_id) as Dictionary
	_check(bool(seeded.get("accepted", false)),
		"%s: a settled on-foot visit is recorded (%s)" % [world_id, seeded.get("reason", "")])
	await _shut_down(seed_game)

	# --- begin the resume, then leave while the world is still streaming ----
	# Headless streaming of an already-cached world can finish within a frame,
	# so the quit is taken in the same frame BEGIN SHIFT admitted the resume.
	var resuming_game := await _boot(true, false)
	var resuming: RefCounted = resuming_game.get(owner_property)
	var first := (resuming_game.call(status_method) as Dictionary).get("restore", {}) as Dictionary
	_check(bool(first.get("accepted", false)),
		"%s: the first relaunch admits the resume (%s)" % [world_id, first.get("reason", "")])
	_check(StringName(resuming.get("state")) == &"restoring",
		"%s: the first relaunch is still streaming the world when the pilot quits (%s)"
			% [world_id, resuming.get("state")])
	await _shut_down(resuming_game)

	# --- the next launch must still hand the visit back ----------------------
	var resumed_game := await _boot(true)
	var resumed: RefCounted = resumed_game.get(owner_property)
	var second := (resumed_game.call(status_method) as Dictionary).get("restore", {}) as Dictionary
	_check(bool(second.get("accepted", false)),
		"%s: quitting mid-resume keeps the visit for the next launch (%s)"
			% [world_id, second.get("reason", "")])
	var survey: RefCounted = resumed.get("survey")
	_check(int((survey.call(&"capture") as Dictionary).get("next_checkpoint_index", -1)) == 1,
		"%s: the survey progress carried into the resume is intact" % world_id)
	# Leave nothing behind for the next world's section.
	resumed.call(&"cancel")
	await _shut_down(resumed_game)
	var cleanup_game := await _boot(false)
	var cleanup_binding: RefCounted = cleanup_game.get(binding_property)
	var leftover := cleanup_binding.call(&"load_interrupted_visit") as Dictionary
	if bool(leftover.get("accepted", false)):
		cleanup_binding.call(&"retire_interrupted_visit",
			int(leftover.get("store_generation", -1)),
			str(leftover.get("receipt_sha256", "")),
			"%s-quit-during-resume-cleanup" % world_id)
	await _shut_down(cleanup_game)


func _boot(start: bool, settle := true) -> GameFlow:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	if start:
		game.start_shift()
		if settle:
			await process_frame
			await physics_frame
	return game


func _shut_down(game: GameFlow) -> void:
	game.queue_free()
	for _i in range(6):
		await process_frame
		await physics_frame


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
