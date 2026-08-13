extends SceneTree

const LiveCombatAuthorityScript := preload("res://scripts/combat/live_combat_authority.gd")

const SOURCE_ID := 7401
const WEAPON_ID: StringName = &"reentry_probe"
const FACTION_ID: StringName = &"test_faction"
const WEAPON_PROFILES := {
	WEAPON_ID: {
		"range": 20.0,
		"damage": 5.0,
		"origin_tolerance": 2.0,
	}
}

var _failures: Array[String] = []
var _assertions := 0
var _captured_request: ShotRequest


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var streamed_main := Node3D.new()
	streamed_main.name = "CombatReentryMain"
	root.add_child(streamed_main)

	var authority := LiveCombatAuthorityScript.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	streamed_main.add_child(authority)
	var source := Node3D.new()
	source.name = "PersistentSource"
	streamed_main.add_child(source)
	authority.authoritative_shot_submitted.connect(_on_shot_submitted)
	await process_frame
	await physics_frame

	_check(
		authority.register_source(source, SOURCE_ID, FACTION_ID, WEAPON_PROFILES),
		"live authority registers the source before streaming"
	)
	var first := authority.submit_hitscan(
		source, WEAPON_ID, source.global_position, Vector3.UP
	)
	var captured_before_exit := _captured_request
	_check(
		first.get("status") == &"miss"
		and bool(first.get("accepted", false))
		and captured_before_exit != null
		and captured_before_exit.sequence == 0,
		"first authoritative shot captures sequence zero"
	)

	root.remove_child(streamed_main)
	await process_frame
	_check(
		authority.get_source_id(source) == 0
		and authority.get_resolver().get_registered_source_count() == 0,
		"temporary Main exit removes every live source registration"
	)
	_check(
		authority.get_last_submitted_sequence(source) == 0
		and authority.get_resolver().get_last_sequence(null, SOURCE_ID) == 0,
		"temporary Main exit retains the source cursor and replay high-water mark"
	)

	root.add_child(streamed_main)
	await process_frame
	await physics_frame
	_check(
		authority.register_source(source, SOURCE_ID, FACTION_ID, WEAPON_PROFILES),
		"the same physical source re-registers after Main re-entry"
	)
	var replay := authority.get_resolver().resolve_hitscan(captured_before_exit)
	_check(
		replay.get("status") == &"duplicate_sequence"
		and not bool(replay.get("accepted", true)),
		"captured pre-exit request is rejected after Main re-entry"
	)
	var next := authority.submit_hitscan(
		source, WEAPON_ID, source.global_position, Vector3.UP
	)
	_check(
		bool(next.get("accepted", false))
		and int(next.get("last_sequence", -1)) == 1
		and authority.get_last_submitted_sequence(source) == 1,
		"same-instance source resumes at the next sequence after re-entry"
	)

	authority.forget_source(source, SOURCE_ID)
	_check(
		authority.get_source_id(source) == 0
		and authority.get_last_submitted_sequence(source) == -1
		and authority.get_resolver().get_last_sequence(null, SOURCE_ID) == -1
		and authority.get_resolver().get_registered_source_count() == 0
		and authority.get_resolver().get_tracked_source_count() == 0,
		"explicit forget erases registration, authority cursor, and resolver ledger"
	)
	_check(
		authority.register_source(source, SOURCE_ID, FACTION_ID, WEAPON_PROFILES),
		"explicitly forgotten source can start a deliberate fresh epoch"
	)
	var fresh := authority.submit_hitscan(
		source, WEAPON_ID, source.global_position, Vector3.UP
	)
	_check(
		bool(fresh.get("accepted", false))
		and int(fresh.get("last_sequence", -1)) == 0,
		"fresh epoch restarts at sequence zero only after explicit forget"
	)

	source.queue_free()
	await process_frame
	await process_frame
	_check(
		authority.get_resolver().get_registered_source_count() == 0
		and authority.get_resolver().get_tracked_source_count() == 0
		and (authority.get("_next_sequence_by_instance") as Dictionary).is_empty(),
		"genuinely freed source leaves no registration or stale replay history"
	)

	streamed_main.queue_free()
	await process_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"combat re-entry fixture releases every node"
	)
	_finish()


func _on_shot_submitted(request: ShotRequest, _result: Dictionary) -> void:
	_captured_request = request


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_REENTRY_REPLAY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("COMBAT_REENTRY_REPLAY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
